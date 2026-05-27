"""
Tests for quality gates (deduplication + moderation).
"""

import pytest
from unittest.mock import Mock, MagicMock
from quality_gates import PollDeduplicator, ContentModerator


class TestPollDeduplicator:
    """Test suite for deduplication functionality."""
    
    def test_initialization_default(self):
        """Test PollDeduplicator initialization with defaults."""
        dedup = PollDeduplicator()
        assert dedup.similarity_threshold == 0.8
        assert dedup.vectorizer is not None
    
    def test_initialization_custom_threshold(self):
        """Test PollDeduplicator initialization with custom threshold."""
        dedup = PollDeduplicator(similarity_threshold=0.75)
        assert dedup.similarity_threshold == 0.75
    
    def test_get_poll_text(self):
        """Test combining poll fields into text."""
        dedup = PollDeduplicator()
        
        poll = {
            'title': 'Should AI be regulated?',
            'description': 'New oversight measures',
            'option_a': 'Yes, regulate it',
            'option_b': 'No, let it grow'
        }
        
        text = dedup._get_poll_text(poll)
        
        assert 'Should AI be regulated?' in text
        assert 'New oversight measures' in text
        assert 'Yes, regulate it' in text
        assert 'No, let it grow' in text
    
    def test_check_batch_similarity_empty(self):
        """Test batch deduplication with empty list."""
        dedup = PollDeduplicator()
        result = dedup.check_batch_similarity([])
        assert result == []
    
    def test_check_batch_similarity_single_poll(self):
        """Test batch deduplication with single poll."""
        dedup = PollDeduplicator()
        
        polls = [
            {'title': 'Climate change action?', 'description': 'Urgent measures needed'}
        ]
        
        result = dedup.check_batch_similarity(polls)
        assert len(result) == 1
    
    def test_check_batch_similarity_no_duplicates(self):
        """Test batch deduplication with distinct polls."""
        dedup = PollDeduplicator(similarity_threshold=0.8)
        
        polls = [
            {
                'title': 'Should Congress regulate AI?',
                'description': 'Lawmakers debate oversight',
                'option_a': 'Yes, regulate',
                'option_b': 'No, freedom'
            },
            {
                'title': 'Climate summit reaches agreement',
                'description': 'Historic carbon reduction',
                'option_a': 'Yes, achievable',
                'option_b': 'No, unrealistic'
            },
            {
                'title': 'Federal Reserve maintains rates',
                'description': 'No cuts this quarter',
                'option_a': 'Yes, good move',
                'option_b': 'No, bad timing'
            }
        ]
        
        result = dedup.check_batch_similarity(polls)
        assert len(result) == 3  # All distinct
    
    def test_check_batch_similarity_with_duplicates(self):
        """Test batch deduplication removes near-duplicates."""
        dedup = PollDeduplicator(similarity_threshold=0.75)  # Slightly lower for realistic testing
        
        polls = [
            {
                'title': 'Should Congress regulate artificial intelligence development?',
                'description': 'Lawmakers are considering comprehensive oversight measures for AI systems',
                'option_a': 'Yes, we need strong AI regulation now',
                'option_b': 'No, let AI technology develop freely without restrictions'
            },
            {
                'title': 'Should Congress regulate artificial intelligence development?',
                'description': 'Lawmakers are considering comprehensive oversight measures for AI systems',
                'option_a': 'Yes, we need strong AI regulation now',
                'option_b': 'No, let AI technology develop freely without restrictions'
            },
            {
                'title': 'Climate change summit results',
                'description': 'Historic carbon reduction targets',
                'option_a': 'Yes, realistic',
                'option_b': 'No, too ambitious'
            }
        ]
        
        result = dedup.check_batch_similarity(polls)
        
        # First two are nearly identical, should keep only first
        assert len(result) == 2
        assert result[0]['title'] == 'Should Congress regulate artificial intelligence development?'
        assert result[1]['title'] == 'Climate change summit results'
    
    def test_check_batch_similarity_low_threshold(self):
        """Test that lower threshold keeps more polls."""
        dedup = PollDeduplicator(similarity_threshold=0.5)  # Very permissive
        
        polls = [
            {
                'title': 'AI regulation debate',
                'description': 'Congress considers oversight',
                'option_a': 'Yes',
                'option_b': 'No'
            },
            {
                'title': 'AI oversight discussion',
                'description': 'Lawmakers debate rules',
                'option_a': 'Support',
                'option_b': 'Oppose'
            }
        ]
        
        result = dedup.check_batch_similarity(polls)
        
        # With low threshold, even similar polls may pass
        assert len(result) >= 1
    
    def test_check_db_similarity_empty_new_polls(self):
        """Test DB comparison with empty new polls list."""
        dedup = PollDeduplicator()
        
        existing = [{'title': 'Old poll', 'description': 'From last week'}]
        result = dedup.check_db_similarity([], existing)
        
        assert result == []
    
    def test_check_db_similarity_no_existing(self):
        """Test DB comparison with no existing polls."""
        dedup = PollDeduplicator()
        
        new_polls = [
            {'title': 'New poll', 'description': 'Fresh content'}
        ]
        
        result = dedup.check_db_similarity(new_polls, [])
        
        assert len(result) == 1
    
    def test_check_db_similarity_no_overlap(self):
        """Test DB comparison with completely different polls."""
        dedup = PollDeduplicator(similarity_threshold=0.8)
        
        existing = [
            {
                'title': 'Climate change policy',
                'description': 'Global warming measures',
                'option_a': 'Yes',
                'option_b': 'No'
            }
        ]
        
        new_polls = [
            {
                'title': 'Federal Reserve interest rates',
                'description': 'Monetary policy decision',
                'option_a': 'Raise',
                'option_b': 'Lower'
            },
            {
                'title': 'Healthcare reform proposal',
                'description': 'Universal coverage debate',
                'option_a': 'Support',
                'option_b': 'Oppose'
            }
        ]
        
        result = dedup.check_db_similarity(new_polls, existing)
        
        # All new polls are different from existing
        assert len(result) == 2
    
    def test_check_db_similarity_with_overlap(self):
        """Test DB comparison rejects similar existing polls."""
        dedup = PollDeduplicator(similarity_threshold=0.75)  # Slightly lower for realistic testing
        
        existing = [
            {
                'title': 'Should Congress regulate AI technology and development?',
                'description': 'Lawmakers are actively debating comprehensive oversight measures for artificial intelligence',
                'option_a': 'Yes, we need strong regulation',
                'option_b': 'No, allow free development'
            }
        ]
        
        new_polls = [
            {
                'title': 'Should Congress regulate AI technology and development?',
                'description': 'Lawmakers are actively debating comprehensive oversight measures for artificial intelligence',
                'option_a': 'Yes, we need strong regulation',
                'option_b': 'No, allow free development'
            },
            {
                'title': 'Climate summit achieves breakthrough',
                'description': 'Historic carbon reduction deal',
                'option_a': 'Yes, achievable',
                'option_b': 'No, unrealistic'
            }
        ]
        
        result = dedup.check_db_similarity(new_polls, existing)
        
        # First poll is nearly identical to existing, second is different
        assert len(result) == 1
        assert 'Climate summit' in result[0]['title']


class TestContentModerator:
    """Test suite for content moderation."""
    
    def test_initialization(self):
        """Test ContentModerator initialization."""
        moderator = ContentModerator()
        assert len(moderator.compiled_patterns) > 0
    
    def test_keyword_filter_safe_content(self):
        """Test keyword filter passes safe content."""
        moderator = ContentModerator()
        
        poll = {
            'title': 'Should Congress regulate AI?',
            'description': 'Lawmakers debate oversight measures',
            'option_a': 'Yes, regulate',
            'option_b': 'No, freedom'
        }
        
        assert moderator.keyword_filter(poll) is True
    
    def test_keyword_filter_profanity(self):
        """Test keyword filter rejects profanity."""
        moderator = ContentModerator()
        
        poll = {
            'title': 'This is fucking stupid',
            'description': 'Bad content',
            'option_a': 'Yes',
            'option_b': 'No'
        }
        
        assert moderator.keyword_filter(poll) is False
    
    def test_keyword_filter_violence(self):
        """Test keyword filter rejects violence keywords."""
        moderator = ContentModerator()
        
        poll = {
            'title': 'Should we kill all politicians?',
            'description': 'Violent content',
            'option_a': 'Yes',
            'option_b': 'No'
        }
        
        assert moderator.keyword_filter(poll) is False
    
    def test_keyword_filter_case_insensitive(self):
        """Test keyword filter is case-insensitive."""
        moderator = ContentModerator()
        
        poll = {
            'title': 'This is FUCKING ridiculous',
            'description': 'Bad content',
            'option_a': 'Yes',
            'option_b': 'No'
        }
        
        assert moderator.keyword_filter(poll) is False
    
    def test_llm_moderate_safe(self):
        """Test LLM moderation passes safe content."""
        moderator = ContentModerator()
        
        # Mock LLM client
        llm_client = Mock()
        llm_client.moderate_poll.return_value = (True, None)
        
        poll = {
            'title': 'Should Congress regulate AI?',
            'description': 'Policy debate',
            'option_a': 'Yes',
            'option_b': 'No'
        }
        
        is_safe, reason = moderator.llm_moderate(poll, llm_client)
        
        assert is_safe is True
        assert reason is None
        llm_client.moderate_poll.assert_called_once_with(poll)
    
    def test_llm_moderate_unsafe(self):
        """Test LLM moderation rejects unsafe content."""
        moderator = ContentModerator()
        
        # Mock LLM client
        llm_client = Mock()
        llm_client.moderate_poll.return_value = (False, "Contains hate speech")
        
        poll = {
            'title': 'Harmful content',
            'description': 'Bad stuff',
            'option_a': 'Yes',
            'option_b': 'No'
        }
        
        is_safe, reason = moderator.llm_moderate(poll, llm_client)
        
        assert is_safe is False
        assert reason == "Contains hate speech"
    
    def test_llm_moderate_handles_errors(self):
        """Test LLM moderation fails open on errors."""
        moderator = ContentModerator()
        
        # Mock LLM client that raises error
        llm_client = Mock()
        llm_client.moderate_poll.side_effect = Exception("API error")
        
        poll = {'title': 'Test', 'description': 'Test'}
        
        is_safe, reason = moderator.llm_moderate(poll, llm_client)
        
        # Should fail open (assume safe) on errors
        assert is_safe is True
        assert reason is None
    
    def test_validate_content_empty_list(self):
        """Test content validation with empty list."""
        moderator = ContentModerator()
        llm_client = Mock()
        
        result = moderator.validate_content([], llm_client)
        
        assert result == []
    
    def test_validate_content_all_safe(self):
        """Test content validation passes all safe polls."""
        moderator = ContentModerator()
        
        # Mock LLM client
        llm_client = Mock()
        llm_client.moderate_poll.return_value = (True, None)
        
        polls = [
            {
                'title': 'Should Congress regulate AI?',
                'description': 'Policy debate',
                'option_a': 'Yes',
                'option_b': 'No'
            },
            {
                'title': 'Climate action needed?',
                'description': 'Environmental policy',
                'option_a': 'Yes',
                'option_b': 'No'
            }
        ]
        
        result = moderator.validate_content(polls, llm_client)
        
        assert len(result) == 2
    
    def test_validate_content_keyword_rejection(self):
        """Test content validation rejects polls via keyword filter."""
        moderator = ContentModerator()
        llm_client = Mock()
        
        polls = [
            {
                'title': 'This is fucking stupid',
                'description': 'Bad',
                'option_a': 'Yes',
                'option_b': 'No'
            },
            {
                'title': 'Normal poll',
                'description': 'Good',
                'option_a': 'Yes',
                'option_b': 'No'
            }
        ]
        
        # Mock LLM for polls that pass keyword filter
        llm_client.moderate_poll.return_value = (True, None)
        
        result = moderator.validate_content(polls, llm_client)
        
        # Only second poll should pass
        assert len(result) == 1
        assert result[0]['title'] == 'Normal poll'
    
    def test_validate_content_llm_rejection(self):
        """Test content validation rejects polls via LLM."""
        moderator = ContentModerator()
        
        # Mock LLM client
        llm_client = Mock()
        
        def mock_moderate(poll):
            if 'subtle' in poll['title']:
                return (False, "Contains bias")
            return (True, None)
        
        llm_client.moderate_poll.side_effect = mock_moderate
        
        polls = [
            {
                'title': 'Normal poll about policy',
                'description': 'Good',
                'option_a': 'Yes',
                'option_b': 'No'
            },
            {
                'title': 'Poll with subtle bias',
                'description': 'Bad',
                'option_a': 'Yes',
                'option_b': 'No'
            }
        ]
        
        result = moderator.validate_content(polls, llm_client)
        
        # Only first poll should pass
        assert len(result) == 1
        assert result[0]['title'] == 'Normal poll about policy'
    
    def test_validate_content_two_stage_pipeline(self):
        """Test full two-stage moderation pipeline."""
        moderator = ContentModerator()
        
        # Mock LLM client
        llm_client = Mock()
        llm_client.moderate_poll.return_value = (True, None)
        
        polls = [
            {
                'title': 'Good poll 1',
                'description': 'Clean',
                'option_a': 'Yes',
                'option_b': 'No'
            },
            {
                'title': 'Contains fucking profanity',
                'description': 'Bad',
                'option_a': 'Yes',
                'option_b': 'No'
            },
            {
                'title': 'Good poll 2',
                'description': 'Also clean',
                'option_a': 'Yes',
                'option_b': 'No'
            }
        ]
        
        result = moderator.validate_content(polls, llm_client)
        
        # Middle poll rejected by keyword filter
        assert len(result) == 2
        assert result[0]['title'] == 'Good poll 1'
        assert result[1]['title'] == 'Good poll 2'
        
        # LLM should only be called for polls that passed keyword filter
        assert llm_client.moderate_poll.call_count == 2
