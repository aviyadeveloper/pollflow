"""
Quality gates for poll deduplication and content moderation.

Two-stage pipeline:
1. Deduplication: TF-IDF vectorization + cosine similarity
   - Intra-batch deduplication
   - Comparison against recent DB polls (last 7 days)

2. Content Moderation:
   - Keyword blacklist filtering
   - LLM-based nuanced moderation
"""

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import re
import logging
from typing import List, Dict, Optional, Tuple

logger = logging.getLogger(__name__)


class PollDeduplicator:
    """Deduplication engine using TF-IDF similarity."""

    def __init__(self, similarity_threshold: float = 0.8):
        """
        Initialize deduplicator.

        Args:
            similarity_threshold: Cosine similarity threshold (0-1)
                                 Higher = stricter (more duplicates caught)
                                 Default 0.8 = very similar content
        """
        self.similarity_threshold = similarity_threshold
        self.vectorizer = TfidfVectorizer(
            lowercase=True,
            stop_words="english",
            max_features=1000,
            ngram_range=(1, 2),  # Unigrams and bigrams for better similarity detection
        )

    def _get_poll_text(self, poll: Dict) -> str:
        """
        Combine poll fields into single text for similarity comparison.

        Args:
            poll: Poll dictionary

        Returns:
            Combined text string
        """
        title = poll.get("title", "")
        description = poll.get("description", "")
        option_a = poll.get("option_a", "")
        option_b = poll.get("option_b", "")

        # Combine all text fields
        return f"{title} {description} {option_a} {option_b}"

    def check_batch_similarity(self, polls: List[Dict]) -> List[Dict]:
        """
        Remove duplicates within the generated batch.

        Compares each poll against all previous polls in batch.
        Uses TF-IDF + cosine similarity to detect near-duplicates.

        Args:
            polls: List of poll dictionaries

        Returns:
            List with intra-batch duplicates removed
        """
        if not polls:
            return []

        if len(polls) == 1:
            return polls

        unique_polls = []
        seen_texts = []

        for poll in polls:
            poll_text = self._get_poll_text(poll)

            if not seen_texts:
                # First poll is always unique
                unique_polls.append(poll)
                seen_texts.append(poll_text)
                continue

            # Compare against all previous polls
            all_texts = seen_texts + [poll_text]

            try:
                # Vectorize all texts
                tfidf_matrix = self.vectorizer.fit_transform(all_texts)

                # Calculate similarity of new poll against all previous
                new_poll_vector = tfidf_matrix[-1]
                previous_vectors = tfidf_matrix[:-1]

                similarities = cosine_similarity(new_poll_vector, previous_vectors)[0]
                max_similarity = np.max(similarities)

                if max_similarity < self.similarity_threshold:
                    # Not similar enough to any existing poll - keep it
                    unique_polls.append(poll)
                    seen_texts.append(poll_text)
                    logger.debug(
                        "Poll kept (unique)",
                        extra={
                            "event": "dedup_kept",
                            "max_similarity": round(max_similarity, 3),
                            "threshold": self.similarity_threshold,
                            "poll_title": poll.get("title", "")[:50],
                        },
                    )
                else:
                    # Too similar to an existing poll - reject
                    logger.info(
                        "Poll rejected as duplicate",
                        extra={
                            "event": "dedup_rejected",
                            "similarity": round(max_similarity, 3),
                            "threshold": self.similarity_threshold,
                            "poll_title": poll.get("title", "")[:50],
                        },
                    )

            except Exception as e:
                # If vectorization fails (e.g., empty text), keep the poll
                logger.warning(
                    "Similarity check failed, keeping poll",
                    extra={"event": "dedup_error", "error": str(e)},
                )
                unique_polls.append(poll)
                seen_texts.append(poll_text)

        logger.debug(
            "Batch deduplication summary",
            extra={
                "event": "batch_dedup_summary",
                "input_polls": len(polls),
                "output_polls": len(unique_polls),
            },
        )
        return unique_polls

    def check_db_similarity(
        self, new_polls: List[Dict], existing: List[Dict]
    ) -> List[Dict]:
        """
        Compare new polls against existing DB polls.

        Removes polls that are too similar to recently published polls.

        Args:
            new_polls: Newly generated polls
            existing: Recent polls from database (last 7 days)

        Returns:
            List with polls similar to DB polls removed
        """
        if not new_polls:
            return []

        if not existing:
            # No existing polls to compare against
            logger.info(
                "No existing polls to check against",
                extra={"event": "db_dedup_skip", "reason": "no_existing_polls"},
            )
            return new_polls

        # Extract texts
        new_texts = [self._get_poll_text(p) for p in new_polls]
        existing_texts = [self._get_poll_text(p) for p in existing]

        all_texts = existing_texts + new_texts

        try:
            # Vectorize all texts
            tfidf_matrix = self.vectorizer.fit_transform(all_texts)

            # Split into existing and new
            num_existing = len(existing_texts)
            existing_vectors = tfidf_matrix[:num_existing]
            new_vectors = tfidf_matrix[num_existing:]

            # Calculate similarities
            similarities = cosine_similarity(new_vectors, existing_vectors)

            # Keep polls that are not too similar to any existing poll
            unique_polls = []
            for i, poll in enumerate(new_polls):
                max_similarity = np.max(similarities[i])

                if max_similarity < self.similarity_threshold:
                    unique_polls.append(poll)
                    logger.debug(
                        "Poll kept (unique from DB)",
                        extra={
                            "event": "db_dedup_kept",
                            "max_similarity": round(max_similarity, 3),
                            "threshold": self.similarity_threshold,
                            "poll_title": poll.get("title", "")[:50],
                        },
                    )
                else:
                    logger.info(
                        "Poll rejected as similar to DB poll",
                        extra={
                            "event": "db_dedup_rejected",
                            "similarity": round(max_similarity, 3),
                            "threshold": self.similarity_threshold,
                            "poll_title": poll.get("title", "")[:50],
                        },
                    )

            logger.debug(
                "DB deduplication summary",
                extra={
                    "event": "db_dedup_summary",
                    "input_polls": len(new_polls),
                    "output_polls": len(unique_polls),
                    "existing_db_polls": len(existing),
                },
            )
            return unique_polls

        except Exception as e:
            logger.error(
                "DB similarity check failed, returning all new polls",
                extra={"event": "db_dedup_failed", "error": str(e)},
                exc_info=True,
            )
            return new_polls


class ContentModerator:
    """Content moderation engine with keyword + LLM filtering."""

    # Regex patterns for offensive content
    # These are basic patterns - LLM moderation provides nuanced filtering
    OFFENSIVE_PATTERNS = [
        r"(fuck|shit|bitch|asshole)",  # Profanity (removed word boundaries for better detection)
        r"\b(kill|murder|terrorist|bomb|attack)\b",  # Violence keywords (very basic)
        r"\b(xxx|porn|nude)\b",  # Explicit content
    ]

    def __init__(self):
        """Initialize content moderator."""
        self.compiled_patterns = [
            re.compile(pattern, re.IGNORECASE) for pattern in self.OFFENSIVE_PATTERNS
        ]

    def keyword_filter(self, poll: Dict) -> bool:
        """
        Quick regex-based offensive content filter.

        First-pass filter to quickly reject obviously inappropriate content
        before expensive LLM moderation.

        Args:
            poll: Poll dictionary

        Returns:
            True if poll passes (safe), False if rejected
        """
        # Combine all poll text
        text_fields = [
            poll.get("title", ""),
            poll.get("description", ""),
            poll.get("option_a", ""),
            poll.get("option_b", ""),
        ]
        combined_text = " ".join(text_fields)

        # Check against patterns
        for pattern in self.compiled_patterns:
            if pattern.search(combined_text):
                logger.info(
                    "Poll rejected by keyword filter",
                    extra={
                        "event": "keyword_filter_rejected",
                        "poll_title": poll.get("title", "")[:50],
                    },
                )
                return False

        logger.info(
            "Poll passed keyword filter",
            extra={
                "event": "keyword_filter_passed",
                "poll_title": poll.get("title", "")[:50],
            },
        )
        return True

    def llm_moderate(self, poll: Dict, llm_client) -> Tuple[bool, Optional[str]]:
        """
        Use LLM for nuanced content moderation.

        Delegates to OpenRouterClient.moderate_poll() which uses LLM
        to detect hate speech, violence, bias, misinformation, etc.

        Args:
            poll: Poll dictionary
            llm_client: OpenRouterClient instance

        Returns:
            Tuple of (is_safe: bool, reason: Optional[str])
        """
        try:
            is_safe, reason = llm_client.moderate_poll(poll)

            if not is_safe:
                logger.info(
                    "Poll rejected by LLM moderation",
                    extra={
                        "event": "llm_moderation_rejected",
                        "poll_title": poll.get("title", "")[:50],
                        "reason": reason,
                    },
                )

            return is_safe, reason

        except Exception as e:
            logger.error(
                "LLM moderation failed, assuming safe",
                extra={"event": "llm_moderation_error", "error": str(e)},
            )
            # Fail open - if moderation fails, allow the poll
            return True, None

    def validate_content(self, polls: List[Dict], llm_client) -> List[Dict]:
        """
        Two-stage moderation pipeline.

        Stage 1: Keyword filter (fast, catches obvious issues)
        Stage 2: LLM moderation (slower, more nuanced)

        Args:
            polls: List of poll dictionaries
            llm_client: OpenRouterClient instance

        Returns:
            List with unsafe content removed
        """
        if not polls:
            return []

        logger.debug(
            "Starting content moderation",
            extra={"event": "moderation_validation_start", "poll_count": len(polls)},
        )

        # Stage 1: Keyword filtering
        keyword_passed = []
        for poll in polls:
            if self.keyword_filter(poll):
                keyword_passed.append(poll)

        logger.info(
            "Keyword filter complete",
            extra={
                "event": "keyword_filter_complete",
                "input_polls": len(polls),
                "output_polls": len(keyword_passed),
                "rejected": len(polls) - len(keyword_passed),
            },
        )

        # Stage 2: LLM moderation
        llm_passed = []
        for i, poll in enumerate(keyword_passed, 1):
            is_safe, reason = self.llm_moderate(poll, llm_client)
            if is_safe:
                llm_passed.append(poll)

        logger.info(
            "LLM moderation complete",
            extra={
                "event": "llm_moderation_complete",
                "input_polls": len(keyword_passed),
                "output_polls": len(llm_passed),
                "rejected": len(keyword_passed) - len(llm_passed),
            },
        )

        logger.info(
            "Total moderation summary",
            extra={
                "event": "moderation_total_summary",
                "input_polls": len(polls),
                "output_polls": len(llm_passed),
                "total_rejected": len(polls) - len(llm_passed),
            },
        )

        return llm_passed
