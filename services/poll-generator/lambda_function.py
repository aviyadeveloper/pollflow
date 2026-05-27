"""
Main Lambda handler for AI-powered poll generator.

This function orchestrates:
1. Fetching news articles from NewsAPI
2. Generating poll questions via OpenRouter LLM
3. Quality gates (deduplication + content moderation)
4. Scheduling polls with staggered activation times
5. Inserting polls into RDS PostgreSQL database

Triggered by EventBridge every 4 hours (6 runs/day x 24 polls = 144 polls/day).
"""

import os
import logging
import random
from typing import Dict, Any, List
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from pythonjsonlogger import jsonlogger

from news_fetcher import NewsFetcher
from llm_client import OpenRouterClient
from poll_scheduler import PollScheduler
from quality_gates import PollDeduplicator, ContentModerator
from db import DatabaseClient

# Configure JSON structured logging for observability platforms
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Only configure if no handlers exist (Lambda may have default handlers)
if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
        rename_fields={"levelname": "level", "asctime": "timestamp", "name": "logger"},
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
else:
    # Replace existing formatter with JSON formatter
    for handler in logger.handlers:
        formatter = jsonlogger.JsonFormatter(
            fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
            rename_fields={
                "levelname": "level",
                "asctime": "timestamp",
                "name": "logger",
            },
        )
        handler.setFormatter(formatter)

# Suppress noisy third-party library logs (keep only warnings/errors)
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
logging.getLogger("urllib3").setLevel(logging.WARNING)
logging.getLogger("botocore").setLevel(logging.WARNING)
logging.getLogger("boto3").setLevel(logging.WARNING)


def shuffle_by_category(polls: List[Dict]) -> List[Dict]:
    """
    Shuffle polls to distribute categories evenly (round-robin style).

    Prevents clustering of same categories (e.g., 5 economics polls in a row).
    Instead, distributes them evenly: tech, politics, business, science, tech, ...

    Args:
        polls: List of poll dictionaries with 'poll_category' field

    Returns:
        Shuffled list with categories distributed evenly

    Example:
        Input: [tech, tech, tech, business, business, politics]
        Output: [tech, business, politics, tech, business, tech]
    """
    if not polls:
        return []

    # Group polls by category
    by_category = defaultdict(list)
    for poll in polls:
        category = poll.get("poll_category", "general")
        by_category[category].append(poll)

    # Shuffle within each category for variety
    for category_polls in by_category.values():
        random.shuffle(category_polls)

    # Round-robin distribution across categories
    shuffled = []
    categories = list(by_category.keys())

    while by_category:
        # Iterate through categories in random order each round
        random.shuffle(categories)
        for category in categories:
            if category in by_category and by_category[category]:
                shuffled.append(by_category[category].pop(0))
                # Remove empty categories
                if not by_category[category]:
                    del by_category[category]

    logger.debug(
        "Category shuffle complete",
        extra={
            "event": "shuffle_complete",
            "poll_count": len(shuffled),
            "category_count": len(categories),
        },
    )
    return shuffled


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for poll generation.

    Flow:
    1. Load configuration from environment
    2. Initialize clients (NewsAPI, OpenRouter, Database)
    3. Database connectivity smoke test (fail fast if DB unavailable)
    4. Fetch diverse news articles (~35 for 24 polls target)
    5. Generate polls from articles (~30 raw polls)
    6. Remove intra-batch duplicates
    7. Compare against recent DB polls (last 7 days)
    8. Moderate content (keyword + LLM two-stage filter)
    9. Shuffle by category (round-robin distribution)
    10. Select best polls to reach target (24)
    11. Schedule activation times (4-hour window, 10-min intervals)
    12. Insert to database with status='pending'
    13. Return execution summary with metrics

    Args:
        event: EventBridge scheduled event payload
        context: Lambda context object

    Returns:
        Dict with execution summary and metrics
    """
    start_time = datetime.now(timezone.utc)
    logger.info(
        "Starting poll generator Lambda",
        extra={"event": "lambda_start", "execution_time": start_time.isoformat()},
    )

    try:
        # ============================================================
        # 1. LOAD CONFIGURATION
        # ============================================================
        config = {
            "rds_secret_arn": os.environ["RDS_SECRET_ARN"],
            "openrouter_secret_arn": os.environ["OPENROUTER_SECRET_ARN"],
            "newsapi_secret_arn": os.environ["NEWSAPI_SECRET_ARN"],
            "schedule_window_hours": int(os.environ.get("SCHEDULE_WINDOW_HOURS", "4")),
            "target_polls": int(os.environ.get("TARGET_POLLS_PER_RUN", "24")),
            "article_count": int(os.environ.get("ARTICLE_COUNT", "35")),
            "similarity_threshold": float(
                os.environ.get("SIMILARITY_THRESHOLD", "0.8")
            ),
            "poll_duration_hours": int(os.environ.get("POLL_DURATION_HOURS", "12")),
            "aws_region": os.environ.get("AWS_REGION", "eu-west-3"),
            "llm_model": os.environ.get("LLM_MODEL", "google/gemma-2-9b-it"),
        }

        logger.info(
            "Configuration loaded",
            extra={
                "event": "config_loaded",
                "target_polls": config["target_polls"],
                "schedule_window_hours": config["schedule_window_hours"],
                "article_count": config["article_count"],
                "similarity_threshold": config["similarity_threshold"],
                "llm_model": config["llm_model"],
            },
        )

        # ============================================================
        # 2. INITIALIZE CLIENTS
        # ============================================================
        logger.info(
            "Initializing clients",
            extra={"event": "client_init_start", "phase": "initialization"},
        )

        # Fetch API keys from Secrets Manager
        import boto3
        import json

        secrets_client = boto3.session.Session().client(
            service_name="secretsmanager", region_name=config["aws_region"]
        )

        def parse_secret(secret_string: str) -> str:
            """Parse secret - supports both plain text and JSON formats."""
            try:
                # Try parsing as JSON first (format: {"api_key": "..."})
                parsed = json.loads(secret_string)
                if isinstance(parsed, dict) and "api_key" in parsed:
                    return parsed["api_key"]
                else:
                    logger.warning(
                        "Secret is JSON but missing 'api_key' field, using raw value"
                    )
                    return secret_string
            except json.JSONDecodeError:
                # Plain text format - use directly
                return secret_string.strip()

        # Get NewsAPI key
        newsapi_response = secrets_client.get_secret_value(
            SecretId=config["newsapi_secret_arn"]
        )
        newsapi_key = parse_secret(newsapi_response["SecretString"])

        # Get OpenRouter key
        openrouter_response = secrets_client.get_secret_value(
            SecretId=config["openrouter_secret_arn"]
        )
        openrouter_key = parse_secret(openrouter_response["SecretString"])

        # Initialize clients
        news_fetcher = NewsFetcher(api_key=newsapi_key)
        llm_client = OpenRouterClient(api_key=openrouter_key, model=config["llm_model"])
        deduplicator = PollDeduplicator(
            similarity_threshold=config["similarity_threshold"]
        )
        moderator = ContentModerator()
        scheduler = PollScheduler(schedule_window_hours=config["schedule_window_hours"])

        logger.info(
            "Clients initialized successfully",
            extra={"event": "client_init_complete", "phase": "initialization"},
        )

        # ============================================================
        # 3. DATABASE CONNECTIVITY SMOKE TEST
        # ============================================================
        # Fail fast before doing expensive work (API calls, poll generation)
        # if database is unavailable
        logger.info(
            "Running database connectivity smoke test",
            extra={"event": "db_smoke_test_start", "phase": "initialization"},
        )
        db_client = DatabaseClient(
            secret_arn=config["rds_secret_arn"],
            region=config["aws_region"],
            host=os.environ.get("RDS_HOST"),
            port=int(os.environ.get("RDS_PORT", 5432)),
            dbname=os.environ.get("RDS_DBNAME"),
        )

        try:
            db_client.test_connection()
        except Exception as e:
            logger.error(
                "Database connectivity test failed",
                extra={
                    "event": "db_smoke_test_failed",
                    "phase": "initialization",
                    "error": str(e),
                },
                exc_info=True,
            )
            logger.error(
                "Aborting poll generation to avoid wasting resources",
                extra={"event": "lambda_aborted", "reason": "db_unavailable"},
            )
            return {
                "statusCode": 500,
                "body": f"Database connectivity test failed: {str(e)}",
                "metrics": {"smoke_test_passed": False, "error": str(e)},
            }

        logger.info(
            "Database connectivity test passed",
            extra={"event": "db_smoke_test_passed", "phase": "initialization"},
        )

        # ============================================================
        # 4. FETCH NEWS ARTICLES
        # ============================================================
        logger.info(
            "Fetching news articles",
            extra={
                "event": "article_fetch_start",
                "phase": "article_fetch",
                "target_count": config["article_count"],
            },
        )
        articles = news_fetcher.fetch_diverse_articles(
            target_count=config["article_count"]
        )

        if not articles:
            logger.error(
                "No articles fetched from NewsAPI",
                extra={
                    "event": "article_fetch_failed",
                    "phase": "article_fetch",
                    "articles_fetched": 0,
                },
            )
            return {
                "statusCode": 500,
                "body": "Failed to fetch news articles",
                "metrics": {"articles_fetched": 0},
            }

        logger.info(
            "Articles fetched successfully",
            extra={
                "event": "article_fetch_complete",
                "phase": "article_fetch",
                "articles_fetched": len(articles),
            },
        )

        # ============================================================
        # 5. GENERATE POLLS FROM ARTICLES
        # ============================================================
        logger.info(
            "Starting poll generation",
            extra={
                "event": "poll_generation_start",
                "phase": "poll_generation",
                "article_count": len(articles),
            },
        )
        raw_polls = []
        generation_errors = 0

        for i, article in enumerate(articles, 1):
            try:
                logger.debug(
                    "Generating poll from article",
                    extra={
                        "event": "poll_generate",
                        "phase": "poll_generation",
                        "index": i,
                        "total": len(articles),
                        "headline": article.get("title", "")[:60],
                    },
                )
                poll = llm_client.generate_poll(
                    headline=article.get("title", ""),
                    description=article.get("description", ""),
                    category=article.get("category", "general"),
                )
                if poll:
                    raw_polls.append(poll)
                    logger.debug(
                        "Poll generated",
                        extra={
                            "event": "poll_generated",
                            "phase": "poll_generation",
                            "poll_title": poll["title"][:50],
                        },
                    )
            except Exception as e:
                logger.warning(
                    "Failed to generate poll from article",
                    extra={
                        "event": "poll_generation_error",
                        "phase": "poll_generation",
                        "error": str(e),
                    },
                )
                generation_errors += 1

        logger.info(
            "Poll generation complete",
            extra={
                "event": "poll_generation_complete",
                "phase": "poll_generation",
                "polls_generated": len(raw_polls),
                "generation_errors": generation_errors,
            },
        )

        if not raw_polls:
            logger.error(
                "No polls generated from articles",
                extra={
                    "event": "poll_generation_failed",
                    "phase": "poll_generation",
                    "articles_fetched": len(articles),
                    "polls_generated": 0,
                },
            )
            return {
                "statusCode": 500,
                "body": "Failed to generate any polls",
                "metrics": {"articles_fetched": len(articles), "polls_generated": 0},
            }

        # ============================================================
        # 6. QUALITY GATES: DEDUPLICATION
        # ============================================================
        logger.info(
            "Starting deduplication quality gate",
            extra={
                "event": "deduplication_start",
                "phase": "quality_gates",
                "input_polls": len(raw_polls),
            },
        )

        # Remove intra-batch duplicates
        batch_unique = deduplicator.check_batch_similarity(raw_polls)
        batch_removed = len(raw_polls) - len(batch_unique)
        logger.info(
            "Batch deduplication complete",
            extra={
                "event": "batch_dedup_complete",
                "phase": "quality_gates",
                "input_polls": len(raw_polls),
                "output_polls": len(batch_unique),
                "removed": batch_removed,
            },
        )

        # Compare against recent DB polls (reuse smoke-tested connection)
        db_removed = 0
        try:
            recent_polls = db_client.get_recent_polls(days=7)
            logger.info(
                "Fetched recent polls for comparison",
                extra={
                    "event": "db_dedup_fetch",
                    "phase": "quality_gates",
                    "recent_polls_count": len(recent_polls),
                    "lookback_days": 7,
                },
            )

            db_unique = deduplicator.check_db_similarity(batch_unique, recent_polls)
            db_removed = len(batch_unique) - len(db_unique)
            logger.info(
                "Database deduplication complete",
                extra={
                    "event": "db_dedup_complete",
                    "phase": "quality_gates",
                    "input_polls": len(batch_unique),
                    "output_polls": len(db_unique),
                    "removed": db_removed,
                },
            )

            deduplicated_polls = db_unique
        except Exception as e:
            logger.warning(
                "DB deduplication failed, continuing with batch deduplication only",
                extra={
                    "event": "db_dedup_failed",
                    "phase": "quality_gates",
                    "error": str(e),
                },
            )
            deduplicated_polls = batch_unique

        # ============================================================
        # 7. QUALITY GATES: CONTENT MODERATION
        # ============================================================
        logger.info(
            "Starting content moderation quality gate",
            extra={
                "event": "moderation_start",
                "phase": "quality_gates",
                "input_polls": len(deduplicated_polls),
            },
        )
        moderated_polls = moderator.validate_content(deduplicated_polls, llm_client)
        moderation_removed = len(deduplicated_polls) - len(moderated_polls)
        logger.info(
            "Content moderation complete",
            extra={
                "event": "moderation_complete",
                "phase": "quality_gates",
                "input_polls": len(deduplicated_polls),
                "output_polls": len(moderated_polls),
                "removed": moderation_removed,
            },
        )

        if not moderated_polls:
            logger.error(
                "No polls passed quality gates",
                extra={
                    "event": "quality_gates_failed",
                    "phase": "quality_gates",
                    "articles_fetched": len(articles),
                    "polls_generated": len(raw_polls),
                    "after_deduplication": len(deduplicated_polls),
                    "after_moderation": 0,
                },
            )
            return {
                "statusCode": 500,
                "body": "All polls filtered by quality gates",
                "metrics": {
                    "articles_fetched": len(articles),
                    "polls_generated": len(raw_polls),
                    "after_deduplication": len(deduplicated_polls),
                    "after_moderation": 0,
                },
            }

        # ============================================================
        # 8. SHUFFLE BY CATEGORY
        # ============================================================
        logger.info(
            "Shuffling polls by category",
            extra={
                "event": "shuffle_start",
                "phase": "scheduling",
                "input_polls": len(moderated_polls),
            },
        )
        shuffled_polls = shuffle_by_category(moderated_polls)

        # ============================================================
        # 9. SELECT TARGET NUMBER OF POLLS
        # ============================================================
        target = config["target_polls"]
        selected_polls = (
            shuffled_polls[:target] if len(shuffled_polls) >= target else shuffled_polls
        )

        logger.info(
            "Poll selection complete",
            extra={
                "event": "poll_selection",
                "phase": "scheduling",
                "selected": len(selected_polls),
                "target": target,
                "available": len(shuffled_polls),
            },
        )

        if len(selected_polls) < target:
            logger.warning(
                "Poll count below target",
                extra={
                    "event": "polls_below_target",
                    "phase": "scheduling",
                    "selected": len(selected_polls),
                    "target": target,
                    "shortfall": target - len(selected_polls),
                },
            )

        # ============================================================
        # 10. SCHEDULE START TIMES AND CALCULATE END TIMES
        # ============================================================
        logger.info(
            "Scheduling poll activation times",
            extra={
                "event": "schedule_start",
                "phase": "scheduling",
                "poll_count": len(selected_polls),
                "window_hours": config["schedule_window_hours"],
            },
        )
        start_times = scheduler.schedule_polls(num_polls=len(selected_polls))
        poll_duration = timedelta(hours=config["poll_duration_hours"])

        # Assign start_time, end_time, and status to polls
        for poll, start_time in zip(selected_polls, start_times):
            poll["start_time"] = start_time
            poll["end_time"] = start_time + poll_duration
            poll["status"] = "pending"

        logger.info(
            "Poll scheduling complete",
            extra={
                "event": "schedule_complete",
                "phase": "scheduling",
                "poll_count": len(selected_polls),
                "first_poll_start": start_times[0].isoformat(),
                "last_poll_start": start_times[-1].isoformat(),
                "poll_duration_hours": config["poll_duration_hours"],
            },
        )

        # ============================================================
        # 11. INSERT TO DATABASE
        # ============================================================
        logger.info(
            "Inserting polls to database",
            extra={
                "event": "db_insert_start",
                "phase": "db_operations",
                "poll_count": len(selected_polls),
            },
        )

        try:
            inserted_count = db_client.insert_polls(selected_polls)
            logger.info(
                "Polls inserted successfully",
                extra={
                    "event": "db_insert_complete",
                    "phase": "db_operations",
                    "polls_inserted": inserted_count,
                },
            )
        except Exception as e:
            logger.error(
                "Failed to insert polls to database",
                extra={
                    "event": "db_insert_failed",
                    "phase": "db_operations",
                    "error": str(e),
                },
                exc_info=True,
            )
            return {
                "statusCode": 500,
                "body": f"Database insertion failed: {str(e)}",
                "metrics": {
                    "articles_fetched": len(articles),
                    "polls_generated": len(raw_polls),
                    "polls_ready": len(selected_polls),
                    "polls_inserted": 0,
                    "error": str(e),
                },
            }

        # ============================================================
        # 12. CALCULATE METRICS & RETURN
        # ============================================================
        # Close database connection
        db_client.close()

        end_time = datetime.now(timezone.utc)
        duration = (end_time - start_time).total_seconds()

        metrics = {
            "execution_time_seconds": round(duration, 2),
            "articles_fetched": len(articles),
            "polls_generated": len(raw_polls),
            "generation_errors": generation_errors,
            "batch_duplicates_removed": batch_removed,
            "db_duplicates_removed": db_removed,
            "moderation_removed": moderation_removed,
            "polls_scheduled": len(selected_polls),
            "polls_inserted": inserted_count,
            "schedule_window_hours": config["schedule_window_hours"],
            "poll_duration_hours": config["poll_duration_hours"],
            "first_poll_start": start_times[0].isoformat() if start_times else None,
            "last_poll_start": start_times[-1].isoformat() if start_times else None,
        }

        logger.info(
            "Poll generation completed successfully",
            extra={
                "event": "lambda_complete",
                "phase": "completion",
                "duration_seconds": round(duration, 2),
                "polls_inserted": inserted_count,
            },
        )
        logger.info(
            "Final execution metrics",
            extra={"event": "execution_metrics", "phase": "completion", **metrics},
        )

        return {
            "statusCode": 200,
            "body": f"Successfully generated and inserted {inserted_count} polls",
            "metrics": metrics,
        }

    except Exception as e:
        logger.error(
            "Lambda execution failed",
            extra={
                "event": "lambda_failed",
                "error": str(e),
                "error_type": type(e).__name__,
            },
            exc_info=True,
        )
        return {
            "statusCode": 500,
            "body": f"Lambda execution failed: {str(e)}",
            "error": str(e),
        }


# For local testing
if __name__ == "__main__":
    """
    Local testing entry point.
    
    Usage:
        cp .env.example .env
        # Edit .env with real credentials
        uv run python lambda_function.py
    """
    from dotenv import load_dotenv

    load_dotenv()

    # Mock Lambda context
    class MockContext:
        function_name = "poll-generator-local"
        memory_limit_in_mb = 512
        invoked_function_arn = "arn:aws:lambda:local:test"
        aws_request_id = "local-test-request"

    result = lambda_handler(event={}, context=MockContext())
    print("\n" + "=" * 80)
    print("LAMBDA EXECUTION RESULT:")
    print("=" * 80)
    import json

    print(json.dumps(result, indent=2, default=str))
