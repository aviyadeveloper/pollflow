"""
Tests for NewsFetcher class.
"""

import pytest
from unittest.mock import Mock, patch
from news_fetcher import NewsFetcher


class TestNewsFetcher:
    """Test suite for news fetching functionality."""

    def test_initialization(self):
        """Test NewsFetcher initialization."""
        fetcher = NewsFetcher(api_key="test_key")
        assert fetcher.api_key == "test_key"
        assert fetcher.base_url == "https://newsapi.org/v2"
        assert len(fetcher.CATEGORIES) == 7

    @patch("news_fetcher.requests.get")
    def test_fetch_top_headlines_success(self, mock_get):
        """Test fetching top headlines successfully."""
        # Mock successful API response
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "ok",
            "totalResults": 2,
            "articles": [
                {"title": "Article 1", "description": "Desc 1"},
                {"title": "Article 2", "description": "Desc 2"},
            ],
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        fetcher = NewsFetcher(api_key="test_key")
        articles = fetcher.fetch_top_headlines(country="us", page_size=50)

        assert len(articles) == 2
        assert articles[0]["title"] == "Article 1"
        mock_get.assert_called_once()

    @patch("news_fetcher.requests.get")
    def test_fetch_top_headlines_api_error(self, mock_get):
        """Test handling API error response."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "error",
            "message": "API key invalid",
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        fetcher = NewsFetcher(api_key="invalid_key")
        articles = fetcher.fetch_top_headlines()

        assert articles == []

    @patch("news_fetcher.requests.get")
    def test_fetch_by_category_success(self, mock_get):
        """Test fetching by specific category."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "ok",
            "articles": [{"title": "Tech Article", "description": "About AI"}],
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        fetcher = NewsFetcher(api_key="test_key")
        articles = fetcher.fetch_by_category(category="technology", page_size=7)

        assert len(articles) == 1
        assert articles[0]["title"] == "Tech Article"

        # Verify correct parameters were sent
        call_args = mock_get.call_args
        assert call_args[1]["params"]["category"] == "technology"
        assert call_args[1]["params"]["pageSize"] == 7

    def test_fetch_by_category_invalid_category(self):
        """Test error on invalid category."""
        fetcher = NewsFetcher(api_key="test_key")

        with pytest.raises(ValueError, match="Invalid category"):
            fetcher.fetch_by_category(category="invalid_category")

    @patch("news_fetcher.requests.get")
    def test_fetch_diverse_articles_success(self, mock_get):
        """Test fetching diverse articles across categories."""

        # Mock response that returns different articles for each category
        def mock_response_side_effect(*args, **kwargs):
            category = kwargs["params"]["category"]
            mock_resp = Mock()
            mock_resp.json.return_value = {
                "status": "ok",
                "articles": [
                    {
                        "title": f"{category.capitalize()} Article 1",
                        "description": f"About {category}",
                    }
                ],
            }
            mock_resp.raise_for_status = Mock()
            return mock_resp

        mock_get.side_effect = mock_response_side_effect

        fetcher = NewsFetcher(api_key="test_key")
        articles = fetcher.fetch_diverse_articles(target_count=14)  # 2 per category

        # Should fetch from 7 categories
        assert len(articles) >= 7
        assert mock_get.call_count == 7

        # Verify articles have category tags
        assert all("category" in article for article in articles)

    @patch("news_fetcher.requests.get")
    def test_fetch_diverse_articles_deduplication(self, mock_get):
        """Test that duplicate titles are filtered out."""
        # Mock response with duplicate titles
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "ok",
            "articles": [
                {"title": "Duplicate Title", "description": "First"},
                {"title": "Duplicate Title", "description": "Second"},  # Duplicate
                {"title": "Unique Title", "description": "Unique"},
            ],
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        fetcher = NewsFetcher(api_key="test_key")
        articles = fetcher.fetch_diverse_articles(target_count=14)

        # Count unique titles
        titles = [a["title"] for a in articles]
        assert len(titles) == len(set(titles)), "Should not contain duplicate titles"

    @patch("news_fetcher.requests.get")
    def test_fetch_diverse_articles_handles_failures(self, mock_get):
        """Test that failures in some categories don't break entire fetch."""
        call_count = [0]

        def mock_response_side_effect(*args, **kwargs):
            call_count[0] += 1
            # Fail on first two categories, succeed on rest
            if call_count[0] <= 2:
                raise Exception("API error")

            mock_resp = Mock()
            mock_resp.json.return_value = {
                "status": "ok",
                "articles": [
                    {"title": f"Article {call_count[0]}", "description": "Desc"}
                ],
            }
            mock_resp.raise_for_status = Mock()
            return mock_resp

        mock_get.side_effect = mock_response_side_effect

        fetcher = NewsFetcher(api_key="test_key")
        articles = fetcher.fetch_diverse_articles(target_count=14)

        # Should still get articles from successful categories
        assert len(articles) >= 5  # At least 5 categories succeeded
        assert mock_get.call_count == 7  # Tried all categories

    @patch("news_fetcher.requests.get")
    def test_respects_target_count(self, mock_get):
        """Test that fetch_diverse_articles respects target count."""
        mock_response = Mock()
        mock_response.json.return_value = {
            "status": "ok",
            "articles": [
                {"title": f"Article {i}", "description": f"Desc {i}"}
                for i in range(100)  # Return many articles
            ],
        }
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        fetcher = NewsFetcher(api_key="test_key")
        articles = fetcher.fetch_diverse_articles(target_count=50)

        # Should not exceed target
        assert len(articles) <= 50


# Integration test (requires real API key)
@pytest.mark.skip(
    "Requires real NewsAPI key - run manually with: pytest -m integration"
)
def test_real_api_integration():
    """
    Integration test with real NewsAPI.

    To run: NEWSAPI_KEY=your_key pytest tests/test_news_fetcher.py::test_real_api_integration -v
    """
    import os

    api_key = os.getenv("NEWSAPI_KEY")
    if not api_key:
        pytest.skip("NEWSAPI_KEY environment variable not set")

    fetcher = NewsFetcher(api_key=api_key)

    # Test fetch_diverse_articles
    articles = fetcher.fetch_diverse_articles(target_count=21)  # 3 per category

    assert len(articles) > 0, "Should fetch at least some articles"
    assert len(articles) <= 21, "Should not exceed target count"

    # Verify structure
    for article in articles:
        assert "title" in article
        assert "category" in article
        assert article["category"] in NewsFetcher.CATEGORIES

    print(f"\n✅ Successfully fetched {len(articles)} diverse articles")
    print(f"Categories: {set(a['category'] for a in articles)}")
