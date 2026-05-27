"""
OpenRouter LLM client for generating and moderating polls.

Uses Gemma-4-26b-a4b-it model for:
1. Generating poll questions from news headlines
2. Content moderation (detecting offensive/biased content)
"""

from openrouter import OpenRouter
import json
import logging
from pathlib import Path
from typing import Dict, Optional, Tuple

logger = logging.getLogger(__name__)

# Prompt directory
PROMPTS_DIR = Path(__file__).parent / "prompts"


class OpenRouterClient:
    """Client for OpenRouter API using Gemma-4 model."""

    def __init__(self, api_key: str, model: str = "google/gemma-4-26b-a4b-it"):
        """
        Initialize OpenRouter client.

        Args:
            api_key: OpenRouter API key
            model: Model identifier (default: Gemma 4 26B)
        """
        self.model = model
        self.client = OpenRouter(api_key=api_key)

        # Load prompts from files
        self._poll_generation_prompt = self._load_prompt("poll_generation.txt")
        self._poll_generation_user_template = self._load_prompt(
            "poll_generation_user.txt"
        )
        self._moderation_prompt = self._load_prompt("moderation.txt")
        self._moderation_user_template = self._load_prompt("moderation_user.txt")

    @staticmethod
    def _load_prompt(filename: str) -> str:
        """
        Load a prompt from the prompts directory.

        Args:
            filename: Name of the prompt file

        Returns:
            Prompt text

        Raises:
            FileNotFoundError if prompt file doesn't exist
        """
        prompt_path = PROMPTS_DIR / filename
        if not prompt_path.exists():
            raise FileNotFoundError(f"Prompt file not found: {prompt_path}")

        return prompt_path.read_text(encoding="utf-8").strip()

    def _call_api(
        self,
        system_prompt: str,
        user_prompt: str,
        max_tokens: int = 500,
        temperature: float = 0.7,
    ) -> Optional[str]:
        """
        Make API call to OpenRouter using the SDK.

        Args:
            system_prompt: System instructions
            user_prompt: User message
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature (0-1)

        Returns:
            Response text or None if failed
        """
        try:
            response = self.client.chat.send(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                max_tokens=max_tokens,
                temperature=temperature,
            )

            if not response.choices or len(response.choices) == 0:
                logger.error(
                    "No choices in OpenRouter response",
                    extra={"event": "openrouter_no_choices"},
                )
                return None

            content = response.choices[0].message.content
            return content.strip() if content else None

        except Exception as e:
            logger.error(
                "OpenRouter API call failed",
                extra={"event": "openrouter_api_failed", "error": str(e)},
                exc_info=True,
            )
            return None

    def generate_poll(
        self, headline: str, description: str, category: str
    ) -> Optional[Dict]:
        """
        Generate a poll question from a news article.

        Args:
            headline: Article headline
            description: Article description/snippet
            category: Article category (for poll_category field)

        Returns:
            Poll dict with title, description, option_a, option_b, poll_category
            or None if generation fails
        """
        # Build user prompt from template
        desc_text = description or "No description available"
        user_prompt = self._poll_generation_user_template.format(
            headline=headline, description=desc_text, category=category
        )

        # Call API
        response = self._call_api(
            system_prompt=self._poll_generation_prompt,
            user_prompt=user_prompt,
            max_tokens=400,
            temperature=0.7,
        )

        if not response:
            logger.warning(
                "Failed to generate poll for headline",
                extra={"event": "poll_generation_failed", "headline": headline[:50]},
            )
            return None

        # Parse JSON response
        try:
            # Sometimes LLMs wrap JSON in markdown code blocks
            if response.startswith("```"):
                # Extract JSON from code block
                lines = response.split("\n")
                json_lines = [l for l in lines if not l.startswith("```")]
                response = "\n".join(json_lines)

            poll_data = json.loads(response)

            # Validate required fields
            required_fields = ["title", "description", "option_a", "option_b"]
            if not all(field in poll_data for field in required_fields):
                logger.error(
                    "Missing required fields in generated poll",
                    extra={"event": "poll_validation_failed", "poll_data": poll_data},
                )
                return None

            # Add category
            poll_data["poll_category"] = category

            # Validate field lengths
            if len(poll_data["title"]) > 100:
                logger.debug(
                    "Generated title too long, truncating",
                    extra={
                        "event": "title_truncated",
                        "original_length": len(poll_data["title"]),
                    },
                )
                poll_data["title"] = poll_data["title"][:97] + "..."

            if len(poll_data["description"]) > 150:
                logger.debug(
                    "Generated description too long, truncating",
                    extra={
                        "event": "description_truncated",
                        "original_length": len(poll_data["description"]),
                    },
                )
                poll_data["description"] = poll_data["description"][:147] + "..."

            logger.info(
                "Successfully generated poll",
                extra={
                    "event": "poll_generated_success",
                    "poll_title": poll_data["title"][:50],
                    "category": category,
                },
            )
            return poll_data

        except json.JSONDecodeError as e:
            logger.error(
                "Failed to parse poll JSON",
                extra={
                    "event": "poll_json_parse_failed",
                    "error": str(e),
                    "response": response,
                },
                exc_info=True,
            )
            return None
        except Exception as e:
            logger.error(
                "Unexpected error generating poll",
                extra={"event": "poll_generation_error", "error": str(e)},
                exc_info=True,
            )
            return None

    def moderate_poll(self, poll: Dict) -> Tuple[bool, Optional[str]]:
        """
        Use LLM to moderate poll content for offensive/biased content.

        Args:
            poll: Poll dictionary with title, description, options

        Returns:
            Tuple of (is_safe: bool, reason: Optional[str])
        """
        # Build user prompt from template
        user_prompt = self._moderation_user_template.format(
            title=poll.get("title", ""),
            description=poll.get("description", ""),
            option_a=poll.get("option_a", ""),
            option_b=poll.get("option_b", ""),
        )

        # Call API
        response = self._call_api(
            system_prompt=self._moderation_prompt,
            user_prompt=user_prompt,
            max_tokens=200,
            temperature=0.3,  # Lower temperature for more consistent moderation
        )

        if not response:
            # If moderation fails, err on the side of caution
            logger.warning(
                "Moderation API call failed, rejecting poll",
                extra={"event": "moderation_api_failed"},
            )
            return (False, "Moderation check failed")

        # Parse JSON response
        try:
            # Handle markdown code blocks
            if response.startswith("```"):
                lines = response.split("\n")
                json_lines = [l for l in lines if not l.startswith("```")]
                response = "\n".join(json_lines)

            moderation_result = json.loads(response)

            is_safe = moderation_result.get("is_safe", False)
            reason = moderation_result.get("reason")

            if not is_safe:
                logger.info(
                    "Poll rejected by LLM moderation",
                    extra={
                        "event": "moderation_rejected",
                        "reason": reason,
                        "poll_title": poll.get("title", "")[:50],
                    },
                )
            else:
                logger.info(
                    "Poll passed LLM moderation",
                    extra={
                        "event": "moderation_passed",
                        "poll_title": poll.get("title", "")[:50],
                    },
                )

            return (is_safe, reason)

        except json.JSONDecodeError as e:
            logger.error(
                "Failed to parse moderation response",
                extra={
                    "event": "moderation_parse_failed",
                    "error": str(e),
                    "response": response,
                },
                exc_info=True,
            )
            # Fail closed - reject if we can't parse
            return (False, "Moderation parse error")
        except Exception as e:
            logger.error(
                "Unexpected error in moderation",
                extra={"event": "moderation_error", "error": str(e)},
                exc_info=True,
            )
            return (False, "Moderation error")
