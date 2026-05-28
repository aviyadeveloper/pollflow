"""
News API client for fetching diverse news headlines.

Fetches articles across all 7 categories to ensure poll diversity.

Rate Limit Strategy:
- NewsAPI free tier: 100 requests/day
- Current usage: 7 requests per Lambda run (one per category)
- Lambda schedule: Every 2 hours (12 runs/day)
- Total daily requests: 84/day (84% utilization)
- Headroom: 16 requests/day for retries/manual runs
"""

import requests
import logging
from typing import List, Dict

logger = logging.getLogger(__name__)


class NewsFetcher:
    """Client for NewsAPI.org to fetch news headlines."""

    CATEGORIES = [
        "business",
        "entertainment",
        "general",
        "health",
        "science",
        "sports",
        "technology",
    ]

    def __init__(self, api_key: str):
        """
        Initialize news fetcher.

        Args:
            api_key: NewsAPI.org API key
        """
        self.api_key = api_key
        self.base_url = "https://newsapi.org/v2"

    def fetch_top_headlines(
        self, country: str = "us", page_size: int = 50
    ) -> List[Dict]:
        """
        Fetch top headlines across all categories.

        Args:
            country: Country code (default: us)
            page_size: Number of articles to fetch

        Returns:
            List of article dictionaries

        Raises:
            requests.exceptions.RequestException: If API request fails
        """
        url = f"{self.base_url}/top-headlines"
        params = {
            "country": country,
            "pageSize": min(page_size, 100),  # API max is 100
            "apiKey": self.api_key,
        }

        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()

            if data.get("status") != "ok":
                logger.error(
                    "NewsAPI error",
                    extra={
                        "event": "newsapi_error",
                        "error_message": data.get("message", "Unknown error"),
                    },
                )
                return []

            articles = data.get("articles", [])
            logger.debug(
                "Fetched top headlines",
                extra={"event": "headlines_fetched", "article_count": len(articles)},
            )
            return articles

        except requests.exceptions.RequestException as e:
            logger.error(
                "Failed to fetch top headlines",
                extra={"event": "headlines_fetch_failed", "error": str(e)},
                exc_info=True,
            )
            raise

    def fetch_by_category(
        self, category: str, page_size: int = 7, country: str = "us"
    ) -> List[Dict]:
        """
        Fetch headlines for specific category.

        Args:
            category: Category name (business, tech, sports, etc.)
            page_size: Number of articles per category
            country: Country code (default: us)

        Returns:
            List of article dictionaries

        Raises:
            ValueError: If category is invalid
            requests.exceptions.RequestException: If API request fails
        """
        if category not in self.CATEGORIES:
            raise ValueError(
                f"Invalid category '{category}'. "
                f"Must be one of: {', '.join(self.CATEGORIES)}"
            )

        url = f"{self.base_url}/top-headlines"
        params = {
            "country": country,
            "category": category,
            "pageSize": min(page_size, 100),
            "apiKey": self.api_key,
        }

        try:
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()

            if data.get("status") != "ok":
                logger.error(
                    "NewsAPI error for category",
                    extra={
                        "event": "newsapi_category_error",
                        "category": category,
                        "error_message": data.get("message", "Unknown error"),
                    },
                )
                return []

            articles = data.get("articles", [])
            logger.debug(
                "Fetched articles for category",
                extra={
                    "event": "category_articles_fetched",
                    "category": category,
                    "article_count": len(articles),
                },
            )
            return articles

        except requests.exceptions.RequestException as e:
            logger.error(
                "Failed to fetch category",
                extra={
                    "event": "category_fetch_failed",
                    "category": category,
                    "error": str(e),
                },
                exc_info=True,
            )
            raise

    def fetch_diverse_articles(
        self, target_count: int = 50, country: str = "us"
    ) -> List[Dict]:
        """
        Fetch articles across all categories for diversity.

        Distributes requests across 7 categories to ensure balanced coverage.
        Generates ~50 articles to produce 36 final polls after quality gates.

        **Rate Limit Compliance:**
        - Makes 7 API requests per call (one per category)
        - Lambda runs 12 times/day (every 2 hours)
        - Total: 84 requests/day (84% of 100/day free tier limit)

        Args:
            target_count: Target number of articles (~50 for 36 polls)
            country: Country code (default: us)

        Returns:
            List of diverse article dictionaries

        Raises:
            requests.exceptions.RequestException: If API requests fail
        """
        # Calculate articles per category (distribute evenly)
        per_category = max(1, target_count // len(self.CATEGORIES))

        # Add extra to first few categories to reach target
        remainder = target_count % len(self.CATEGORIES)

        all_articles = []
        seen_titles = set()  # Simple deduplication
        api_requests_made = 0

        for i, category in enumerate(self.CATEGORIES):
            # Add extra article to first N categories
            count = per_category + (1 if i < remainder else 0)

            try:
                articles = self.fetch_by_category(
                    category=category, page_size=count, country=country
                )
                api_requests_made += 1  # Count each API call

                # Filter out duplicates by title
                for article in articles:
                    title = article.get("title", "").lower()
                    if title and title not in seen_titles:
                        article["category"] = category  # Tag article with category
                        all_articles.append(article)
                        seen_titles.add(title)

            except Exception as e:
                logger.warning(
                    f"Failed to fetch category '{category}', continuing: {str(e)}"
                )
                continue

        logger.info(
            "Fetched diverse articles",
            extra={
                "event": "diverse_articles_fetched",
                "article_count": len(all_articles),
                "categories": len(self.CATEGORIES),
                "api_requests": api_requests_made,
                "daily_estimate": api_requests_made * 12,  # Lambda runs 12x/day
            },
        )

        return all_articles[:target_count]  # Ensure we don't exceed target
