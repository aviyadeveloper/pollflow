"""
PostgreSQL database client for RDS connection and poll insertion.

Uses AWS Secrets Manager for credentials and psycopg for connection.
"""

import psycopg
import boto3
import json
import os
import logging
import time
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Optional
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


class DatabaseClient:
    """PostgreSQL client for RDS with Secrets Manager integration."""

    def __init__(
        self,
        secret_arn: str,
        region: str = "eu-west-3",
        host: str = None,
        port: int = None,
        dbname: str = None,
    ):
        """
        Initialize database client.

        Args:
            secret_arn: ARN of RDS credentials secret (username/password)
            region: AWS region
            host: Database host (optional, reads from RDS_HOST env if not provided)
            port: Database port (optional, reads from RDS_PORT env if not provided)
            dbname: Database name (optional, reads from RDS_DBNAME env if not provided)
        """
        self.secret_arn = secret_arn
        self.region = region
        self.host = host
        self.port = port
        self.dbname = dbname
        self.conn = None
        self._credentials = None

    def _get_credentials(self) -> Dict:
        """
        Fetch RDS credentials from AWS Secrets Manager.

        Returns:
            Dict with host, port, username, password, dbname

        Raises:
            Exception if credentials cannot be fetched
        """
        if self._credentials:
            return self._credentials

        try:
            logger.info(
                f"Fetching RDS credentials from Secrets Manager: {self.secret_arn}"
            )

            session = boto3.session.Session()
            client = session.client(
                service_name="secretsmanager", region_name=self.region
            )

            response = client.get_secret_value(SecretId=self.secret_arn)

            secret_string = response["SecretString"]
            secret_data = json.loads(secret_string)

            # Build credentials from secret + constructor args + env vars
            credentials = {
                "username": secret_data.get("username"),
                "password": secret_data.get("password"),
                "host": self.host
                or secret_data.get("host")
                or os.environ.get("RDS_HOST"),
                "port": self.port
                or secret_data.get("port")
                or int(os.environ.get("RDS_PORT", 5432)),
                "dbname": self.dbname
                or secret_data.get("dbname")
                or os.environ.get("RDS_DBNAME"),
            }

            # Validate required fields
            required_fields = ["host", "port", "username", "password", "dbname"]
            for field in required_fields:
                if not credentials.get(field):
                    raise ValueError(f"Missing required field in credentials: {field}")

            self._credentials = credentials
            logger.info(
                "RDS credentials retrieved successfully",
                extra={
                    "event": "credentials_retrieved",
                    "has_host": bool(credentials.get("host")),
                },
            )

            return credentials

        except ClientError as e:
            logger.error(
                "Failed to fetch RDS credentials",
                extra={"event": "credentials_fetch_failed", "error": str(e)},
                exc_info=True,
            )
            raise
        except Exception as e:
            logger.error(
                "Unexpected error fetching credentials",
                extra={"event": "credentials_error", "error": str(e)},
                exc_info=True,
            )
            raise

    def connect(self, max_retries: int = 3, retry_delay: int = 2):
        """
        Establish PostgreSQL connection with SSL.

        Args:
            max_retries: Maximum number of connection attempts
            retry_delay: Seconds to wait between retries

        Raises:
            Exception if connection fails after retries
        """
        if self.conn and not self.conn.closed:
            logger.debug(
                "Database connection already established",
                extra={"event": "connection_exists"},
            )
            return

        credentials = self._get_credentials()

        connection_string = (
            f"host={credentials['host']} "
            f"port={credentials['port']} "
            f"dbname={credentials['dbname']} "
            f"user={credentials['username']} "
            f"password={credentials['password']} "
            f"sslmode=require"
        )

        for attempt in range(1, max_retries + 1):
            try:
                logger.info(
                    "Connecting to RDS",
                    extra={
                        "event": "connection_attempt",
                        "attempt": attempt,
                        "max_retries": max_retries,
                    },
                )

                self.conn = psycopg.connect(connection_string)

                logger.info(
                    "Database connection established",
                    extra={"event": "connection_success"},
                )
                return

            except Exception as e:
                logger.error(
                    "Connection attempt failed",
                    extra={
                        "event": "connection_attempt_failed",
                        "attempt": attempt,
                        "error": str(e),
                    },
                )

                if attempt < max_retries:
                    logger.info(
                        "Retrying connection",
                        extra={"event": "connection_retry", "retry_delay": retry_delay},
                    )
                    time.sleep(retry_delay)
                else:
                    logger.error(
                        "All connection attempts failed",
                        extra={
                            "event": "connection_failed",
                            "max_retries": max_retries,
                        },
                    )
                    raise

    def test_connection(self) -> bool:
        """
        Smoke test database connectivity with a simple query.

        This is a lightweight check to fail fast before doing expensive work
        (API calls, poll generation) if the database is unavailable.

        Returns:
            True if connection and query succeed

        Raises:
            Exception if connection or query fails
        """
        try:
            logger.debug(
                "Testing database connectivity",
                extra={"event": "connectivity_test_start"},
            )
            self.connect()

            # Execute simple query to verify connection
            with self.conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                result = cursor.fetchone()

                if result and result[0] == 1:
                    logger.debug(
                        "Database connectivity test passed",
                        extra={"event": "connectivity_test_passed"},
                    )
                    return True
                else:
                    raise Exception("Unexpected result from connectivity test")

        except Exception as e:
            logger.error(
                "Database connectivity test failed",
                extra={"event": "connectivity_test_failed", "error": str(e)},
                exc_info=True,
            )
            raise

    def insert_polls(self, polls: List[Dict]) -> int:
        """
        Batch insert polls into database.

        Uses transaction for atomicity - all or nothing.

        Args:
            polls: List of poll dictionaries with required fields:
                  - title, description, option_a, option_b
                  - poll_category, start_time, end_time, status

        Returns:
            Number of polls successfully inserted

        Raises:
            Exception if insert fails
        """
        if not polls:
            logger.warning(
                "No polls to insert",
                extra={"event": "insert_skip", "reason": "empty_list"},
            )
            return 0

        if not self.conn or self.conn.closed:
            self.connect()

        try:
            with self.conn.cursor() as cur:
                # Begin transaction
                logger.debug(
                    "Inserting polls into database",
                    extra={"event": "insert_start", "poll_count": len(polls)},
                )

                insert_query = """
                    INSERT INTO polls (
                        title, 
                        description, 
                        option_a, 
                        option_b, 
                        poll_category, 
                        start_time, 
                        end_time,
                        status,
                        created_at
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                """

                inserted_count = 0
                for poll in polls:
                    try:
                        cur.execute(
                            insert_query,
                            (
                                poll["title"],
                                poll["description"],
                                poll["option_a"],
                                poll["option_b"],
                                poll.get("poll_category", "general"),
                                poll["start_time"],
                                poll["end_time"],
                                poll.get("status", "pending"),
                                datetime.now(timezone.utc),
                            ),
                        )
                        inserted_count += 1

                    except KeyError as e:
                        logger.error(
                            "Poll missing required field",
                            extra={
                                "event": "poll_validation_error",
                                "field": str(e),
                                "poll": poll,
                            },
                        )
                        raise

                # Commit transaction
                self.conn.commit()

                logger.debug(
                    "Successfully inserted polls",
                    extra={"event": "insert_success", "inserted_count": inserted_count},
                )
                return inserted_count

        except Exception as e:
            # Rollback on error
            if self.conn:
                self.conn.rollback()
            logger.error(
                "Failed to insert polls",
                extra={"event": "insert_failed", "error": str(e)},
                exc_info=True,
            )
            raise

    def get_recent_polls(self, days: int = 7) -> List[Dict]:
        """
        Fetch recent polls for deduplication.

        Args:
            days: How many days back to fetch

        Returns:
            List of poll dictionaries from database
        """
        if not self.conn or self.conn.closed:
            self.connect()

        try:
            cutoff_date = datetime.now(timezone.utc) - timedelta(days=days)

            logger.info(
                f"Fetching polls from last {days} days (since {cutoff_date.isoformat()})"
            )

            with self.conn.cursor() as cur:
                query = """
                    SELECT 
                        title, 
                        description, 
                        option_a, 
                        option_b, 
                        poll_category,
                        start_time,
                        end_time,
                        status
                    FROM polls
                    WHERE created_at >= %s
                    ORDER BY created_at DESC
                """

                cur.execute(query, (cutoff_date,))
                rows = cur.fetchall()

                # Convert to list of dicts
                polls = []
                for row in rows:
                    polls.append(
                        {
                            "title": row[0],
                            "description": row[1],
                            "option_a": row[2],
                            "option_b": row[3],
                            "poll_category": row[4],
                            "start_time": row[5],
                            "end_time": row[6],
                            "status": row[7],
                        }
                    )

                logger.debug(
                    "Fetched recent polls",
                    extra={
                        "event": "fetch_recent_success",
                        "poll_count": len(polls),
                        "days": days,
                    },
                )
                return polls

        except Exception as e:
            logger.error(
                "Failed to fetch recent polls",
                extra={"event": "fetch_recent_failed", "error": str(e)},
                exc_info=True,
            )
            raise

    def close(self):
        """Close database connection."""
        if self.conn and not self.conn.closed:
            self.conn.close()
            logger.info("Database connection closed")

    def __enter__(self):
        """Context manager entry."""
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()
        return False
