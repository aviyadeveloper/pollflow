"""
Tests for db.py (DatabaseClient).

Mocks AWS Secrets Manager and psycopg for isolated testing.
"""

import pytest
from unittest.mock import Mock, MagicMock, patch, call
from datetime import datetime, timezone, timedelta
from botocore.exceptions import ClientError
from db import DatabaseClient


class TestDatabaseClient:
    """Test suite for DatabaseClient class."""

    def test_initialization(self):
        """Test DatabaseClient initialization."""
        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123",
            region="eu-west-3",
        )

        assert db.secret_arn == "arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        assert db.region == "eu-west-3"
        assert db.conn is None
        assert db._credentials is None

    @patch("db.boto3.session.Session")
    def test_get_credentials_success(self, mock_session):
        """Test successful credentials retrieval from Secrets Manager."""
        # Mock Secrets Manager client
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        credentials = db._get_credentials()

        assert credentials["host"] == "db.example.com"
        assert credentials["port"] == 5432
        assert credentials["username"] == "admin"
        assert credentials["password"] == "secret123"
        assert credentials["dbname"] == "pollflow"

        # Should cache credentials
        assert db._credentials == credentials

    @patch("db.boto3.session.Session")
    def test_get_credentials_cached(self, mock_session):
        """Test that credentials are cached after first fetch."""
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        # First call
        credentials1 = db._get_credentials()
        # Second call - should use cache
        credentials2 = db._get_credentials()

        assert credentials1 == credentials2
        # Secrets Manager should only be called once
        mock_client.get_secret_value.assert_called_once()

    @patch("db.boto3.session.Session")
    def test_get_credentials_missing_field(self, mock_session):
        """Test error when credentials are missing required fields."""
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432}'  # Missing username, password, dbname
        }
        mock_session.return_value.client.return_value = mock_client

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        with pytest.raises(ValueError, match="Missing required field in credentials"):
            db._get_credentials()

    @patch("db.boto3.session.Session")
    def test_get_credentials_client_error(self, mock_session):
        """Test error handling when Secrets Manager fails."""
        mock_client = Mock()
        mock_client.get_secret_value.side_effect = ClientError(
            {
                "Error": {
                    "Code": "ResourceNotFoundException",
                    "Message": "Secret not found",
                }
            },
            "GetSecretValue",
        )
        mock_session.return_value.client.return_value = mock_client

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        with pytest.raises(ClientError):
            db._get_credentials()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_connect_success(self, mock_session, mock_psycopg_connect):
        """Test successful database connection."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()

        assert db.conn == mock_conn
        mock_psycopg_connect.assert_called_once()

        # Verify connection string includes SSL
        call_args = mock_psycopg_connect.call_args[0][0]
        assert "sslmode=require" in call_args
        assert "host=db.example.com" in call_args
        assert "port=5432" in call_args

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_connect_already_connected(self, mock_session, mock_psycopg_connect):
        """Test that connect() skips if already connected."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()
        db.connect()  # Second call

        # Should only connect once
        mock_psycopg_connect.assert_called_once()

    @patch("db.time.sleep")
    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_connect_retry_on_failure(
        self, mock_session, mock_psycopg_connect, mock_sleep
    ):
        """Test connection retry logic."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection - fail twice, succeed third time
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_psycopg_connect.side_effect = [
            Exception("Connection timeout"),
            Exception("Connection timeout"),
            mock_conn,
        ]

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect(max_retries=3, retry_delay=1)

        assert db.conn == mock_conn
        assert mock_psycopg_connect.call_count == 3
        assert mock_sleep.call_count == 2  # Sleeps between retries

    @patch("db.time.sleep")
    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_connect_max_retries_exceeded(
        self, mock_session, mock_psycopg_connect, mock_sleep
    ):
        """Test failure when max retries exceeded."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection - always fail
        mock_psycopg_connect.side_effect = Exception("Connection timeout")

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        with pytest.raises(Exception, match="Connection timeout"):
            db.connect(max_retries=2, retry_delay=0.1)

        assert mock_psycopg_connect.call_count == 2

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_connection_smoke_test_success(self, mock_session, mock_psycopg_connect):
        """Test successful database connectivity smoke test."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection and cursor
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (1,)  # SELECT 1 returns (1,)
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_conn.cursor.return_value.__enter__ = Mock(return_value=mock_cursor)
        mock_conn.cursor.return_value.__exit__ = Mock(return_value=False)
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        result = db.test_connection()

        assert result is True
        mock_cursor.execute.assert_called_once_with("SELECT 1")
        mock_cursor.fetchone.assert_called_once()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_connection_smoke_test_failure(self, mock_session, mock_psycopg_connect):
        """Test database connectivity smoke test failure."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection failure
        mock_psycopg_connect.side_effect = Exception("Connection refused")

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        with pytest.raises(Exception, match="Connection refused"):
            db.test_connection()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_connection_smoke_test_unexpected_result(
        self, mock_session, mock_psycopg_connect
    ):
        """Test database connectivity smoke test with unexpected query result."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection and cursor with unexpected result
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (2,)  # Wrong value
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_conn.cursor.return_value.__enter__ = Mock(return_value=mock_cursor)
        mock_conn.cursor.return_value.__exit__ = Mock(return_value=False)
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        with pytest.raises(Exception, match="Unexpected result from connectivity test"):
            db.test_connection()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_insert_polls_success(self, mock_session, mock_psycopg_connect):
        """Test successful batch poll insertion."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection and cursor
        mock_cursor = MagicMock()
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_conn.__enter__ = Mock(return_value=mock_conn)
        mock_conn.__exit__ = Mock(return_value=False)
        mock_conn.cursor.return_value.__enter__ = Mock(return_value=mock_cursor)
        mock_conn.cursor.return_value.__exit__ = Mock(return_value=False)
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()

        polls = [
            {
                "title": "Should AI be regulated?",
                "description": "Policy debate",
                "option_a": "Yes",
                "option_b": "No",
                "poll_category": "technology",
                "start_time": datetime(2026, 5, 27, 10, 0, 0, tzinfo=timezone.utc),
                "end_time": datetime(2026, 5, 27, 22, 0, 0, tzinfo=timezone.utc),
                "status": "pending",
            },
            {
                "title": "Climate action needed?",
                "description": "Environmental policy",
                "option_a": "Yes",
                "option_b": "No",
                "poll_category": "environment",
                "start_time": datetime(2026, 5, 27, 10, 10, 0, tzinfo=timezone.utc),
                "end_time": datetime(2026, 5, 27, 22, 10, 0, tzinfo=timezone.utc),
                "status": "pending",
            },
        ]

        result = db.insert_polls(polls)

        assert result == 2
        assert mock_cursor.execute.call_count == 2
        mock_conn.commit.assert_called_once()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_insert_polls_empty_list(self, mock_session, mock_psycopg_connect):
        """Test inserting empty poll list."""
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )

        result = db.insert_polls([])

        assert result == 0

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_insert_polls_missing_field(self, mock_session, mock_psycopg_connect):
        """Test error when poll is missing required field."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection
        mock_cursor = MagicMock()
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_conn.cursor.return_value.__enter__ = Mock(return_value=mock_cursor)
        mock_conn.cursor.return_value.__exit__ = Mock(return_value=False)
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()

        polls = [
            {
                "title": "Test poll",
                # Missing description, option_a, option_b, etc.
            }
        ]

        with pytest.raises(KeyError):
            db.insert_polls(polls)

        # Should rollback on error
        mock_conn.rollback.assert_called_once()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_insert_polls_rolls_back_on_error(self, mock_session, mock_psycopg_connect):
        """Test transaction rollback on insertion error."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection with cursor that raises error
        mock_cursor = MagicMock()
        mock_cursor.execute.side_effect = Exception("Database error")
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_conn.cursor.return_value.__enter__ = Mock(return_value=mock_cursor)
        mock_conn.cursor.return_value.__exit__ = Mock(return_value=False)
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()

        polls = [
            {
                "title": "Test",
                "description": "Test",
                "option_a": "Yes",
                "option_b": "No",
                "start_time": datetime.now(timezone.utc),
                "end_time": datetime.now(timezone.utc) + timedelta(hours=12),
            }
        ]

        with pytest.raises(Exception, match="Database error"):
            db.insert_polls(polls)

        mock_conn.rollback.assert_called_once()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_get_recent_polls_success(self, mock_session, mock_psycopg_connect):
        """Test fetching recent polls from database."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection and cursor
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            (
                "AI regulation?",
                "Policy debate",
                "Yes",
                "No",
                "technology",
                datetime(2026, 5, 27, 10, 0, tzinfo=timezone.utc),
                datetime(2026, 5, 27, 22, 0, tzinfo=timezone.utc),
                "active",
            ),
            (
                "Climate action?",
                "Environment",
                "Yes",
                "No",
                "environment",
                datetime(2026, 5, 27, 10, 10, tzinfo=timezone.utc),
                datetime(2026, 5, 27, 22, 10, tzinfo=timezone.utc),
                "active",
            ),
        ]

        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_conn.cursor.return_value.__enter__ = Mock(return_value=mock_cursor)
        mock_conn.cursor.return_value.__exit__ = Mock(return_value=False)
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()

        polls = db.get_recent_polls(days=7)

        assert len(polls) == 2
        assert polls[0]["title"] == "AI regulation?"
        assert polls[0]["poll_category"] == "technology"
        assert polls[1]["title"] == "Climate action?"

        # Verify SQL query was executed
        mock_cursor.execute.assert_called_once()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_get_recent_polls_empty(self, mock_session, mock_psycopg_connect):
        """Test fetching when no recent polls exist."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection and cursor
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = []

        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_conn.cursor.return_value.__enter__ = Mock(return_value=mock_cursor)
        mock_conn.cursor.return_value.__exit__ = Mock(return_value=False)
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()

        polls = db.get_recent_polls(days=7)

        assert polls == []

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_close(self, mock_session, mock_psycopg_connect):
        """Test closing database connection."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_psycopg_connect.return_value = mock_conn

        db = DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        )
        db.connect()
        db.close()

        mock_conn.close.assert_called_once()

    @patch("db.psycopg.connect")
    @patch("db.boto3.session.Session")
    def test_context_manager(self, mock_session, mock_psycopg_connect):
        """Test DatabaseClient as context manager."""
        # Mock credentials
        mock_client = Mock()
        mock_client.get_secret_value.return_value = {
            "SecretString": '{"host": "db.example.com", "port": 5432, "username": "admin", "password": "secret123", "dbname": "pollflow"}'
        }
        mock_session.return_value.client.return_value = mock_client

        # Mock connection
        mock_conn = MagicMock()
        mock_conn.closed = False
        mock_psycopg_connect.return_value = mock_conn

        with DatabaseClient(
            secret_arn="arn:aws:secretsmanager:eu-west-3:123:secret:rds-abc123"
        ) as db:
            assert db.conn == mock_conn

        # Should close connection on exit
        mock_conn.close.assert_called_once()
