"""
Poll Scheduler Module

Calculates how many polls are needed and their activation times
to maintain even distribution across a configurable time window.

Business Rules:
- 288 polls per day (12 per hour) = 24/7 operation
- Flexible scheduling: Lambda can run every 2 hours generating 24 polls each
- 1 poll every 5 minutes
- Polls activate at scheduled times (not all at once when generated)
"""

from datetime import datetime, timezone, timedelta
from typing import List
import logging

logger = logging.getLogger(__name__)

# Constants
POLLS_PER_DAY = 288
POLLS_PER_HOUR = 12
MINUTES_BETWEEN_POLLS = 5
DEFAULT_SCHEDULE_WINDOW_HOURS = (
    2  # Default to 2-hour window for breaking news responsiveness
)


class PollScheduler:
    """
    Manages poll scheduling and distribution logic.

    Flexible scheduling: Lambda can run multiple times per day (e.g., every 2 hours)
    generating a batch of polls for the next window. Each poll gets an activation
    timestamp evenly distributed across the scheduling window.

    Example:
        - Lambda runs every 2 hours
        - Each run generates 24 polls
        - Polls distributed evenly over next 2 hours (1 every 5 minutes)
        - Total: 12 runs x 24 polls = 288 polls/day
    """

    def __init__(
        self,
        base_time: datetime = None,
        schedule_window_hours: int = DEFAULT_SCHEDULE_WINDOW_HOURS,
    ):
        """
        Initialize scheduler.

        Args:
            base_time: Reference time for scheduling (defaults to current UTC time)
            schedule_window_hours: Time window in hours for distributing polls (default: 2)
        """
        self.base_time = base_time or datetime.now(timezone.utc)
        self.schedule_window_hours = schedule_window_hours

    def calculate_polls_needed(self) -> int:
        """
        Calculate how many polls are needed for this scheduling window.

        Based on the schedule window and target rate of 12 polls/hour:
        - 2-hour window: 24 polls
        - 4-hour window: 48 polls
        - 24-hour window: 288 polls

        Returns:
            Number of polls to generate
        """
        return POLLS_PER_HOUR * self.schedule_window_hours

    def schedule_polls(self, num_polls: int = None) -> List[datetime]:
        """
        Calculate activation times for polls, evenly distributed across the scheduling window.

        The schedule starts from the next even interval mark after base_time.
        For example (with 10-minute intervals):
        - If base_time is 01:03:45, first poll activates at 01:10:00
        - If base_time is 01:00:00, first poll activates at 01:00:00

        Args:
            num_polls: Number of polls to schedule (defaults to calculate_polls_needed())

        Returns:
            List of datetime objects (UTC) representing activation times

        Example:
            # 2-hour window with 24 polls
            scheduler = PollScheduler(datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc), schedule_window_hours=2)
            times = scheduler.schedule_polls(24)
            # Returns: [01:00:00, 01:05:00, 01:10:00, ..., 02:55:00] (24 times over 2 hours)
        """
        if num_polls is None:
            num_polls = self.calculate_polls_needed()

        if num_polls <= 0:
            logger.warning(
                "Invalid num_polls, returning empty schedule",
                extra={"event": "schedule_invalid_input", "num_polls": num_polls},
            )
            return []

        # Calculate minutes interval between polls based on scheduling window
        total_minutes = self.schedule_window_hours * 60
        interval_minutes = total_minutes // num_polls

        logger.debug(
            "Scheduling polls",
            extra={
                "event": "schedule_start",
                "num_polls": num_polls,
                "window_hours": self.schedule_window_hours,
                "interval_minutes": interval_minutes,
                "base_time": self.base_time.isoformat(),
            },
        )

        # Round base_time up to next even interval
        start_time = self._round_to_next_interval(self.base_time, interval_minutes)

        # Generate activation times
        activation_times = []
        for i in range(num_polls):
            activation_time = start_time + timedelta(minutes=i * interval_minutes)
            activation_times.append(activation_time)

        logger.debug(
            "Generated activation times",
            extra={
                "event": "schedule_complete",
                "activation_count": len(activation_times),
                "first_time": activation_times[0].isoformat(),
                "last_time": activation_times[-1].isoformat(),
            },
        )

        return activation_times

    def _round_to_next_interval(self, dt: datetime, interval_minutes: int) -> datetime:
        """
        Round datetime up to the next even interval.

        Examples (with 5-minute interval):
        - 01:00:00 → 01:00:00 (already on interval)
        - 01:03:45 → 01:05:00
        - 01:10:01 → 01:15:00

        Args:
            dt: Datetime to round
            interval_minutes: Interval in minutes (e.g., 5)

        Returns:
            Rounded datetime
        """
        # Calculate minutes since midnight
        minutes_since_midnight = dt.hour * 60 + dt.minute

        # Check if we're exactly on an interval (with 0 seconds/microseconds)
        is_exact = (
            dt.second == 0
            and dt.microsecond == 0
            and minutes_since_midnight % interval_minutes == 0
        )

        if is_exact:
            # Already on interval, return as-is (just clear seconds/microseconds)
            return dt.replace(second=0, microsecond=0)

        # Round up to next interval
        next_interval_minutes = (
            ((minutes_since_midnight // interval_minutes) + 1) * interval_minutes
        ) % (24 * 60)

        # Handle midnight wrap
        if next_interval_minutes == 0:
            # Wrapped to midnight of next day
            result = dt.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(
                days=1
            )
        else:
            result = dt.replace(
                hour=next_interval_minutes // 60,
                minute=next_interval_minutes % 60,
                second=0,
                microsecond=0,
            )

        return result

    def get_next_poll_time(self) -> datetime:
        """
        Get the next scheduled poll activation time from now.

        Returns:
            Next poll activation time (UTC)
        """
        return self._round_to_next_interval(self.base_time, MINUTES_BETWEEN_POLLS)
