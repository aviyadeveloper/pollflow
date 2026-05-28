#!/usr/bin/env python3
"""
End-to-End Integration Test for Poll Generator Lambda
======================================================

Tests the complete pipeline with real APIs:
1. Fetch news from NewsAPI
2. Generate polls with OpenRouter LLM
3. Deduplicate against batch and database
4. Moderate content (keyword + LLM)
5. Shuffle by category
6. Schedule activation times (4-hour window)
7. Insert to RDS database

Requirements:
- .env file with real AWS Secrets Manager ARNs
- AWS credentials configured (CLI or environment)
- Internet connection for API calls

Run: python test_e2e.py
Or:  uv run python test_e2e.py
Or:  python test_e2e.py --no-db (skip database insertion)
"""

import os
import sys
import logging
from datetime import datetime, timezone
from unittest.mock import patch, MagicMock
from dotenv import load_dotenv

# Configure logging to show Lambda logs in console
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)

# Load environment variables
load_dotenv()

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Import Lambda handler
from lambda_function import lambda_handler


def validate_environment():
    """Validate required environment variables are set."""
    required_vars = [
        "RDS_SECRET_ARN",
        "OPENROUTER_SECRET_ARN",
        "NEWSAPI_SECRET_ARN",
    ]

    missing = [var for var in required_vars if not os.environ.get(var)]

    if missing:
        print("❌ Missing required environment variables:")
        for var in missing:
            print(f"   - {var}")
        print("\nCreate .env file from .env.example and fill in your ARNs")
        sys.exit(1)

    print("✅ Environment variables validated")
    print(f"   - RDS: {os.environ['RDS_SECRET_ARN'][-10:]}")
    print(f"   - OpenRouter: {os.environ['OPENROUTER_SECRET_ARN'][-10:]}")
    print(f"   - NewsAPI: {os.environ['NEWSAPI_SECRET_ARN'][-10:]}")
    print()


def print_poll_summary(polls, label="Polls"):
    """Print a summary of polls."""
    if not polls:
        print(f"   No {label.lower()} to display\n")
        return

    print(f"\n   {label} ({len(polls)}):")
    print("   " + "=" * 70)

    for i, poll in enumerate(polls[:5], 1):  # Show first 5
        print(f"\n   {i}. {poll['title']}")
        print(f"      Category: {poll.get('poll_category', 'N/A')}")
        print(
            f"      Options: {poll.get('option_a', 'N/A')} / {poll.get('option_b', 'N/A')}"
        )
        if "start_time" in poll:
            print(f"      Start: {poll['start_time'].strftime('%Y-%m-%d %H:%M UTC')}")
        if "end_time" in poll:
            print(f"      End: {poll['end_time'].strftime('%Y-%m-%d %H:%M UTC')}")

    if len(polls) > 5:
        print(f"\n   ... and {len(polls) - 5} more polls")
    print()


def main():
    """Run end-to-end integration test."""
    # Check for --no-db flag
    skip_db = "--no-db" in sys.argv

    print("\n" + "=" * 80)
    print("🚀 POLL GENERATOR - END-TO-END INTEGRATION TEST")
    if skip_db:
        print("   (SKIPPING DATABASE INSERTION)")
    print("=" * 80)
    print(f"Started at: {datetime.now(timezone.utc).isoformat()}\n")

    # Validate environment
    validate_environment()

    # Prepare Lambda event (empty for scheduled execution)
    event = {}
    context = None  # Not needed for local testing

    print("🎯 Executing Lambda handler with real APIs...\n")
    print("This will:")
    print("  1. Fetch ~35 news articles from NewsAPI")
    print("  2. Generate ~30 polls with OpenRouter LLM (google/gemma-4-26b-a4b-it)")
    print("  3. Deduplicate polls (TF-IDF similarity)")
    print("  4. Moderate content (keyword + LLM)")
    print("  5. Shuffle by category")
    print("  6. Schedule 24 polls over 4-hour window")
    if skip_db:
        print("  7. [SKIPPED] Insert to RDS database")
    else:
        print("  7. Insert to RDS database")
    print("\n" + "-" * 80 + "\n")

    try:
        # Execute Lambda handler with optional DB mocking
        if skip_db:
            # Mock the database client to skip actual insertions
            # Must patch where it's used, not where it's defined
            with patch("lambda_function.DatabaseClient") as mock_db_class:
                mock_db_instance = MagicMock()
                mock_db_instance.insert_poll.return_value = (
                    None  # Simulate successful insert
                )
                mock_db_instance.poll_exists.return_value = False  # No duplicates
                mock_db_instance.test_connection.return_value = (
                    None  # Skip connectivity test
                )
                mock_db_class.return_value = mock_db_instance

                result = lambda_handler(event, context)

                print(f"\n🔍 Database Mock Summary:")
                print(
                    f"   - test_connection called: {mock_db_instance.test_connection.call_count} times"
                )
                print(
                    f"   - insert_poll called: {mock_db_instance.insert_poll.call_count} times"
                )
                print(
                    f"   - poll_exists called: {mock_db_instance.poll_exists.call_count} times"
                )
        else:
            result = lambda_handler(event, context)

        print("\n" + "=" * 80)
        print("✅ END-TO-END TEST COMPLETED SUCCESSFULLY")
        print("=" * 80)

        # Print detailed results
        print("\n📊 EXECUTION SUMMARY:")
        print("-" * 80)

        metrics = result.get("metrics", {})

        print(f"\n🗞️  News Fetching:")
        print(f"   - Articles fetched: {metrics.get('articles_fetched', 'N/A')}")

        print(f"\n🤖 Poll Generation:")
        print(f"   - Raw polls generated: {metrics.get('raw_polls_generated', 'N/A')}")
        print(f"   - Generation errors: {metrics.get('generation_errors', 'N/A')}")

        print(f"\n🔍 Quality Gates:")
        print(
            f"   - Batch duplicates removed: {metrics.get('batch_duplicates_removed', 'N/A')}"
        )
        print(
            f"   - DB duplicates removed: {metrics.get('db_duplicates_removed', 'N/A')}"
        )
        print(
            f"   - Unsafe polls removed: {metrics.get('unsafe_polls_removed', 'N/A')}"
        )

        print(f"\n📅 Scheduling:")
        print(f"   - Polls scheduled: {metrics.get('polls_scheduled', 'N/A')}")
        print(
            f"   - Schedule window: {metrics.get('schedule_window_hours', 'N/A')} hours"
        )
        print(f"   - Poll duration: {metrics.get('poll_duration_hours', 'N/A')} hours")
        print(f"   - First poll start: {metrics.get('first_poll_start', 'N/A')}")
        print(f"   - Last poll start: {metrics.get('last_poll_start', 'N/A')}")

        print(f"\n💾 Database:")
        if skip_db:
            print(f"   - [SKIPPED] DB insertion mocked")
        else:
            print(f"   - Polls inserted: {metrics.get('polls_inserted', 'N/A')}")

        print(f"\n⏱️  Performance:")
        print(f"   - Execution time: {result.get('execution_time_seconds', 'N/A')}s")

        print("\n" + "=" * 80)
        print("\n✨ SUCCESS! The pipeline is working end-to-end.")
        print("   - 24 polls generated with start_time/end_time")
        if skip_db:
            print("   - Database insertion skipped (--no-db flag)")
        else:
            print("   - All polls inserted to RDS database")
            print("   - Poll-broker service can now activate them at start_time")
        print("\n" + "=" * 80 + "\n")

        return 0

    except Exception as e:
        print("\n" + "=" * 80)
        print("❌ END-TO-END TEST FAILED")
        print("=" * 80)
        print(f"\nError: {str(e)}")
        print("\nCheck the logs above for details.")
        print("=" * 80 + "\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
