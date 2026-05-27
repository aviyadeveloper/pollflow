#!/usr/bin/env python3
"""
Quick test script for NewsFetcher with real NewsAPI key from AWS Secrets Manager.
"""

import sys
import json
import boto3
from news_fetcher import NewsFetcher


def get_secret(secret_arn: str, region: str = "eu-west-3") -> str:
    """Fetch secret from AWS Secrets Manager."""
    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_arn)
    return response["SecretString"]


def main():
    print("🔑 Fetching NewsAPI key from AWS Secrets Manager...")

    try:
        # Fetch API key
        secret_arn = "arn:aws:secretsmanager:eu-west-3:058264398399:secret:pollflow/newsapi-key-M9YapA"
        api_key = get_secret(secret_arn)
        print("✅ API key retrieved\n")

        # Initialize fetcher
        fetcher = NewsFetcher(api_key=api_key)

        # Test 1: Fetch diverse articles
        print("📰 Test 1: Fetching 21 diverse articles (3 per category)...")
        articles = fetcher.fetch_diverse_articles(target_count=21)

        print(f"✅ Fetched {len(articles)} articles\n")

        # Show distribution by category
        categories = {}
        for article in articles:
            cat = article.get("category", "unknown")
            categories[cat] = categories.get(cat, 0) + 1

        print("📊 Distribution by category:")
        for cat, count in sorted(categories.items()):
            print(f"  {cat:15s}: {count} articles")

        # Show sample articles
        print("\n📄 Sample articles (first 3):")
        for i, article in enumerate(articles[:3], 1):
            print(f"\n  {i}. {article.get('title', 'No title')}")
            print(f"     Category: {article.get('category', 'unknown')}")
            print(f"     Source: {article.get('source', {}).get('name', 'Unknown')}")
            print(f"     URL: {article.get('url', 'No URL')}")
            desc = article.get("description") or "No description"
            print(
                f"     Description: {desc[:100]}..."
                if len(desc) > 100
                else f"     Description: {desc}"
            )

        # Test 2: Fetch specific category
        print("\n\n📰 Test 2: Fetching 5 technology articles...")
        tech_articles = fetcher.fetch_by_category(category="technology", page_size=5)
        print(f"✅ Fetched {len(tech_articles)} technology articles")

        for i, article in enumerate(tech_articles[:2], 1):
            print(f"\n  {i}. {article.get('title', 'No title')}")

        print("\n✅ All tests passed! NewsFetcher is working correctly.")

    except Exception as e:
        print(f"\n❌ Test failed: {str(e)}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
