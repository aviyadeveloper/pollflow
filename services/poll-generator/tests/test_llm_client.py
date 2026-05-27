"""
Tests for OpenRouterClient class.
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from llm_client import OpenRouterClient


class TestOpenRouterClient:
    """Test suite for LLM client functionality."""

    def test_initialization(self):
        """Test OpenRouterClient initialization."""
        client = OpenRouterClient(api_key="test_key")
        assert client.model == "google/gemma-4-26b-a4b-it"
        assert client.client is not None

    def test_custom_model(self):
        """Test initialization with custom model."""
        client = OpenRouterClient(api_key="test_key", model="custom/model")
        assert client.model == "custom/model"

    @patch("llm_client.OpenRouter")
    def test_generate_poll_success(self, mock_openrouter_class):
        """Test successful poll generation."""
        # Mock the SDK client
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        # Mock successful API response
        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = """{
            "title": "Should governments regulate AI development?",
            "description": "New AI regulations are being debated in Congress.",
            "option_a": "Yes, strict oversight needed",
            "option_b": "No, let innovation thrive"
        }"""
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = client.generate_poll(
            headline="Congress debates AI regulation",
            description="Lawmakers consider new oversight framework",
            category="technology",
        )

        assert poll is not None
        assert poll["title"] == "Should governments regulate AI development?"
        assert poll["option_a"] == "Yes, strict oversight needed"
        assert poll["option_b"] == "No, let innovation thrive"
        assert poll["poll_category"] == "technology"

        # Verify SDK was called correctly
        mock_client.chat.send.assert_called_once()

    @patch("llm_client.OpenRouter")
    def test_generate_poll_with_markdown_wrapper(self, mock_openrouter_class):
        """Test handling of JSON wrapped in markdown code blocks."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = """```json
{
    "title": "Test question?",
    "description": "Test description",
    "option_a": "Option A",
    "option_b": "Option B"
}
```"""
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = client.generate_poll("Test headline", "Test desc", "general")

        assert poll is not None
        assert poll["title"] == "Test question?"

    @patch("llm_client.OpenRouter")
    def test_generate_poll_missing_fields(self, mock_openrouter_class):
        """Test handling of incomplete poll data."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = '{"title": "Only title", "option_a": "A"}'
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = client.generate_poll("Test", "Test", "general")

        assert poll is None  # Should return None for incomplete data

    @patch("llm_client.OpenRouter")
    def test_generate_poll_truncates_long_text(self, mock_openrouter_class):
        """Test that overly long titles/descriptions are truncated."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        long_title = "A" * 250
        long_desc = "B" * 400

        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = f'''{{
            "title": "{long_title}",
            "description": "{long_desc}",
            "option_a": "Yes",
            "option_b": "No"
        }}'''
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = client.generate_poll("Test", "Test", "general")

        assert poll is not None
        assert len(poll["title"]) <= 100
        assert len(poll["description"]) <= 150
        assert poll["title"].endswith("...")

    @patch("llm_client.OpenRouter")
    def test_generate_poll_api_error(self, mock_openrouter_class):
        """Test handling of API errors."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client
        mock_client.chat.send.side_effect = Exception("API Error")

        client = OpenRouterClient(api_key="test_key")
        poll = client.generate_poll("Test", "Test", "general")

        assert poll is None

    @patch("llm_client.OpenRouter")
    def test_generate_poll_invalid_json(self, mock_openrouter_class):
        """Test handling of invalid JSON responses."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = "This is not valid JSON at all!"
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = client.generate_poll("Test", "Test", "general")

        assert poll is None

    @patch("llm_client.OpenRouter")
    def test_moderate_poll_safe(self, mock_openrouter_class):
        """Test moderation approves safe poll."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = '{"is_safe": true, "reason": null}'
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = {
            "title": "Should we invest in renewable energy?",
            "description": "Climate debate continues",
            "option_a": "Yes",
            "option_b": "No",
        }

        is_safe, reason = client.moderate_poll(poll)

        assert is_safe is True
        assert reason is None

    @patch("llm_client.OpenRouter")
    def test_moderate_poll_unsafe(self, mock_openrouter_class):
        """Test moderation rejects unsafe poll."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = '{"is_safe": false, "reason": "Contains hate speech"}'
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = {
            "title": "Offensive question",
            "description": "Bad content",
            "option_a": "A",
            "option_b": "B",
        }

        is_safe, reason = client.moderate_poll(poll)

        assert is_safe is False
        assert reason == "Contains hate speech"

    @patch("llm_client.OpenRouter")
    def test_moderate_poll_api_failure(self, mock_openrouter_class):
        """Test moderation fails closed on API errors."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client
        mock_client.chat.send.side_effect = Exception("API Error")

        client = OpenRouterClient(api_key="test_key")
        poll = {
            "title": "Test",
            "description": "Test",
            "option_a": "A",
            "option_b": "B",
        }

        is_safe, reason = client.moderate_poll(poll)

        # Should fail closed (reject) on errors
        assert is_safe is False
        assert reason is not None

    @patch("llm_client.OpenRouter")
    def test_moderate_poll_invalid_json(self, mock_openrouter_class):
        """Test moderation fails closed on invalid JSON."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        mock_response = Mock()
        mock_message = Mock()
        mock_message.content = "Not valid JSON"
        mock_choice = Mock()
        mock_choice.message = mock_message
        mock_response.choices = [mock_choice]
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = {
            "title": "Test",
            "description": "Test",
            "option_a": "A",
            "option_b": "B",
        }

        is_safe, reason = client.moderate_poll(poll)

        assert is_safe is False

    @patch("llm_client.OpenRouter")
    def test_call_api_handles_empty_choices(self, mock_openrouter_class):
        """Test handling of empty choices array."""
        mock_client = MagicMock()
        mock_openrouter_class.return_value = mock_client

        mock_response = Mock()
        mock_response.choices = []
        mock_client.chat.send.return_value = mock_response

        client = OpenRouterClient(api_key="test_key")
        poll = client.generate_poll("Test", "Test", "general")

        assert poll is None


# Integration test (requires real API key)
@pytest.mark.skip("Requires real OpenRouter key - run manually")
def test_real_api_poll_generation():
    """
    Integration test with real OpenRouter API.

    To run: OPENROUTER_KEY=your_key pytest tests/test_llm_client.py::test_real_api_poll_generation -v
    """
    import os

    api_key = os.getenv("OPENROUTER_KEY")
    if not api_key:
        pytest.skip("OPENROUTER_KEY environment variable not set")

    client = OpenRouterClient(api_key=api_key)

    # Test poll generation
    poll = client.generate_poll(
        headline="Congress debates new AI regulation framework",
        description="Lawmakers consider oversight measures for artificial intelligence development",
        category="technology",
    )

    assert poll is not None, "Failed to generate poll"
    assert "title" in poll
    assert "description" in poll
    assert "option_a" in poll
    assert "option_b" in poll
    assert poll["poll_category"] == "technology"

    print(f"\n✅ Generated poll:")
    print(f"   Title: {poll['title']}")
    print(f"   Options: {poll['option_a']} vs {poll['option_b']}")

    # Test moderation
    is_safe, reason = client.moderate_poll(poll)
    assert is_safe is True, f"Generated poll failed moderation: {reason}"

    print(f"   Moderation: ✅ Safe")


@pytest.mark.skip("Requires real OpenRouter key - run manually")
def test_real_api_moderation():
    """Test moderation with intentionally controversial content."""
    import os

    api_key = os.getenv("OPENROUTER_KEY")
    if not api_key:
        pytest.skip("OPENROUTER_KEY environment variable not set")

    client = OpenRouterClient(api_key=api_key)

    # Test with neutral poll (should pass)
    safe_poll = {
        "title": "Should cities invest more in public transportation?",
        "description": "Debate over urban infrastructure priorities",
        "option_a": "Yes, reduce traffic",
        "option_b": "No, too expensive",
    }

    is_safe, reason = client.moderate_poll(safe_poll)
    print(f"\n✅ Safe poll moderation: {is_safe} (reason: {reason})")
    assert is_safe is True
