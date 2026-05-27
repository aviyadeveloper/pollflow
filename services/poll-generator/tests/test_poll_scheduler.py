"""
Tests for poll_scheduler.py

Tests the scheduling logic that distributes polls evenly across a configurable time window.
Supports flexible scheduling (e.g., 24 polls over 4 hours, or 144 polls over 24 hours).
"""

import pytest
from datetime import datetime, timezone, timedelta
from poll_scheduler import (
    PollScheduler,
    POLLS_PER_DAY,
    POLLS_PER_HOUR,
    MINUTES_BETWEEN_POLLS,
)


class TestPollScheduler:
    """Test suite for PollScheduler class."""

    def test_initialization_default_time(self):
        """Test scheduler initialization with default time (current UTC)."""
        scheduler = PollScheduler()

        assert scheduler.base_time is not None
        assert scheduler.base_time.tzinfo == timezone.utc

        # Should be within 1 second of now
        now = datetime.now(timezone.utc)
        time_diff = abs((scheduler.base_time - now).total_seconds())
        assert time_diff < 1, "Default base_time should be close to current time"

    def test_initialization_custom_time(self):
        """Test scheduler initialization with custom base time."""
        custom_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=custom_time)

        assert scheduler.base_time == custom_time
        assert scheduler.schedule_window_hours == 2  # Default

    def test_initialization_custom_window(self):
        """Test scheduler initialization with custom schedule window."""
        scheduler = PollScheduler(schedule_window_hours=8)

        assert scheduler.schedule_window_hours == 8

    def test_calculate_polls_needed_4_hour_window(self):
        """Test calculate_polls_needed for 4-hour window."""
        scheduler = PollScheduler(schedule_window_hours=4)

        polls_needed = scheduler.calculate_polls_needed()

        # 4 hours × 12 polls/hour = 48 polls
        assert polls_needed == 48

    def test_calculate_polls_needed_24_hour_window(self):
        """Test calculate_polls_needed for 24-hour window."""
        scheduler = PollScheduler(schedule_window_hours=24)

        polls_needed = scheduler.calculate_polls_needed()

        # 24 hours × 12 polls/hour = 288 polls
        assert polls_needed == POLLS_PER_DAY
        assert polls_needed == 288

    def test_schedule_polls_default_count(self):
        """Test scheduling with default poll count for 2-hour window (24)."""
        base_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=2)

        activation_times = scheduler.schedule_polls()

        assert len(activation_times) == 24  # 2-hour window default
        assert all(isinstance(t, datetime) for t in activation_times)
        assert all(t.tzinfo == timezone.utc for t in activation_times)

    def test_schedule_polls_custom_count(self):
        """Test scheduling with custom poll count."""
        base_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time)

        activation_times = scheduler.schedule_polls(num_polls=72)

        assert len(activation_times) == 72

    def test_schedule_polls_even_distribution(self):
        """Test that polls are evenly distributed across 24-hour window."""
        base_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=24)

        activation_times = scheduler.schedule_polls(288)

        # Check spacing between consecutive polls
        for i in range(len(activation_times) - 1):
            time_diff = activation_times[i + 1] - activation_times[i]
            minutes_diff = time_diff.total_seconds() / 60

            assert minutes_diff == 5, (
                f"Expected 5 minutes between polls, got {minutes_diff} "
                f"between poll {i} and {i + 1}"
            )

    def test_schedule_polls_starts_at_even_interval(self):
        """Test that first poll starts at even 5-minute mark."""
        # Base time is 01:03:45 - should round up to 01:05:00
        base_time = datetime(2026, 5, 27, 1, 3, 45, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=2)

        activation_times = scheduler.schedule_polls(24)

        first_time = activation_times[0]
        assert first_time.minute == 5
        assert first_time.second == 0
        assert first_time.microsecond == 0

    def test_schedule_polls_already_on_interval(self):
        """Test scheduling when base_time is already on even interval."""
        # Base time is exactly 01:00:00 - should start immediately
        base_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=24)

        activation_times = scheduler.schedule_polls(288)

        first_time = activation_times[0]
        assert first_time == base_time

    def test_schedule_polls_spans_24_hours(self):
        """Test that 288 polls span approximately 24 hours."""
        base_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=24)

        activation_times = scheduler.schedule_polls(288)

        first_time = activation_times[0]
        last_time = activation_times[-1]

        # 288 polls × 5 min = 1440 minutes = 24 hours
        # But last poll is at 23:55 (5 minutes before completing full cycle)
        expected_duration = timedelta(minutes=287 * 5)
        actual_duration = last_time - first_time

        assert actual_duration == expected_duration

    def test_schedule_polls_wraps_correctly(self):
        """Test that scheduling wraps correctly across midnight."""
        # Start at 23:00 - should wrap to next day
        base_time = datetime(2026, 5, 27, 23, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=24)

        activation_times = scheduler.schedule_polls(288)

        # First poll at 23:00
        assert activation_times[0].hour == 23
        assert activation_times[0].minute == 0

        # After 12 polls (1 hour), should be at midnight
        twelfth_poll = activation_times[12]
        assert twelfth_poll.hour == 0
        assert twelfth_poll.minute == 0
        assert twelfth_poll.day == 28  # Next day

    def test_schedule_polls_zero_count(self):
        """Test scheduling with zero polls."""
        scheduler = PollScheduler()

        activation_times = scheduler.schedule_polls(num_polls=0)

        assert activation_times == []

    def test_schedule_polls_negative_count(self):
        """Test scheduling with negative poll count."""
        scheduler = PollScheduler()

        activation_times = scheduler.schedule_polls(num_polls=-5)

        assert activation_times == []

    def test_round_to_next_interval_already_aligned(self):
        """Test rounding when already on interval."""
        base_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time)

        rounded = scheduler._round_to_next_interval(base_time, 10)

        assert rounded == base_time

    def test_round_to_next_interval_needs_rounding(self):
        """Test rounding when between intervals."""
        base_time = datetime(2026, 5, 27, 1, 3, 45, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time)

        rounded = scheduler._round_to_next_interval(base_time, 10)

        expected = datetime(2026, 5, 27, 1, 10, 0, tzinfo=timezone.utc)
        assert rounded == expected

    def test_round_to_next_interval_just_past(self):
        """Test rounding when just past an interval."""
        base_time = datetime(2026, 5, 27, 1, 10, 1, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time)

        rounded = scheduler._round_to_next_interval(base_time, 10)

        expected = datetime(2026, 5, 27, 1, 20, 0, tzinfo=timezone.utc)
        assert rounded == expected

    def test_round_to_next_interval_near_midnight(self):
        """Test rounding near midnight wraps to next day."""
        base_time = datetime(2026, 5, 27, 23, 55, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time)

        rounded = scheduler._round_to_next_interval(base_time, 10)

        expected = datetime(2026, 5, 28, 0, 0, 0, tzinfo=timezone.utc)
        assert rounded == expected

    def test_round_to_next_interval_different_intervals(self):
        """Test rounding with different interval sizes."""
        base_time = datetime(2026, 5, 27, 1, 7, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time)

        # 15-minute intervals: 00, 15, 30, 45
        rounded = scheduler._round_to_next_interval(base_time, 15)
        expected = datetime(2026, 5, 27, 1, 15, 0, tzinfo=timezone.utc)
        assert rounded == expected

        # 20-minute intervals: 00, 20, 40
        rounded = scheduler._round_to_next_interval(base_time, 20)
        expected = datetime(2026, 5, 27, 1, 20, 0, tzinfo=timezone.utc)
        assert rounded == expected

    def test_get_next_poll_time(self):
        """Test getting next poll time from now."""
        base_time = datetime(2026, 5, 27, 1, 3, 45, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time)

        next_time = scheduler.get_next_poll_time()

        expected = datetime(2026, 5, 27, 1, 5, 0, tzinfo=timezone.utc)
        assert next_time == expected

    def test_schedule_144_polls_realistic_scenario(self):
        """Integration test: Schedule 288 polls for a full day (24-hour window)."""
        # Lambda runs at 1:00 AM UTC
        lambda_run_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=lambda_run_time, schedule_window_hours=24)

        # Calculate polls needed
        num_polls = scheduler.calculate_polls_needed()
        assert num_polls == 288

        # Schedule activation times
        activation_times = scheduler.schedule_polls(num_polls)

        # Verify count
        assert len(activation_times) == 288

        # Verify first poll (01:00:00)
        assert activation_times[0].hour == 1
        assert activation_times[0].minute == 0

        # Verify last poll (00:55:00 next day)
        assert activation_times[-1].hour == 0
        assert activation_times[-1].minute == 55
        assert activation_times[-1].day == 28

        # Verify even spacing (5 minutes)
        for i in range(len(activation_times) - 1):
            diff = activation_times[i + 1] - activation_times[i]
            assert diff == timedelta(minutes=5)

        # Verify timezone
        assert all(t.tzinfo == timezone.utc for t in activation_times)

    def test_schedule_24_polls_4_hour_window(self):
        """Integration test: Schedule 24 polls over 2-hour window (2-hour cadence)."""
        # Lambda runs at 1:00 AM UTC
        lambda_run_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=lambda_run_time, schedule_window_hours=2)

        # Calculate polls needed for 2-hour window
        num_polls = scheduler.calculate_polls_needed()
        assert num_polls == 24  # 2 hours × 12 polls/hour

        # Schedule activation times
        activation_times = scheduler.schedule_polls(num_polls)

        # Verify count
        assert len(activation_times) == 24

        # Verify first poll (01:00:00)
        assert activation_times[0].hour == 1
        assert activation_times[0].minute == 0

        # Verify last poll (02:55:00 - 1h55m after start)
        assert activation_times[-1].hour == 2
        assert activation_times[-1].minute == 55

        # Verify even spacing (5 minutes)
        for i in range(len(activation_times) - 1):
            diff = activation_times[i + 1] - activation_times[i]
            assert diff == timedelta(minutes=5)

        # Verify total span is 1h55m (23 intervals × 5 minutes)
        total_span = activation_times[-1] - activation_times[0]
        expected_span = timedelta(minutes=23 * 5)
        assert total_span == expected_span

        # Verify timezone
        assert all(t.tzinfo == timezone.utc for t in activation_times)

    def test_schedule_polls_4_hour_window_even_distribution(self):
        """Test that 24 polls are evenly distributed over 4 hours."""
        base_time = datetime(2026, 5, 27, 1, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=4)

        activation_times = scheduler.schedule_polls(48)

        # Verify 5-minute intervals
        for i in range(len(activation_times) - 1):
            time_diff = activation_times[i + 1] - activation_times[i]
            minutes_diff = time_diff.total_seconds() / 60

            assert minutes_diff == 5, (
                f"Expected 5 minutes between polls in 4-hour window, got {minutes_diff} "
                f"between poll {i} and {i + 1}"
            )

    def test_multiple_4_hour_runs_cover_24_hours(self):
        """Test that 12 runs of 2-hour windows cover full day without overlap."""
        run_times = [
            datetime(2026, 5, 27, 0, 0, 0, tzinfo=timezone.utc),  # 00:00-01:55
            datetime(2026, 5, 27, 2, 0, 0, tzinfo=timezone.utc),  # 02:00-03:55
            datetime(2026, 5, 27, 4, 0, 0, tzinfo=timezone.utc),  # 04:00-05:55
            datetime(2026, 5, 27, 6, 0, 0, tzinfo=timezone.utc),  # 06:00-07:55
            datetime(2026, 5, 27, 8, 0, 0, tzinfo=timezone.utc),  # 08:00-09:55
            datetime(2026, 5, 27, 10, 0, 0, tzinfo=timezone.utc),  # 10:00-11:55
            datetime(2026, 5, 27, 12, 0, 0, tzinfo=timezone.utc),  # 12:00-13:55
            datetime(2026, 5, 27, 14, 0, 0, tzinfo=timezone.utc),  # 14:00-15:55
            datetime(2026, 5, 27, 16, 0, 0, tzinfo=timezone.utc),  # 16:00-17:55
            datetime(2026, 5, 27, 18, 0, 0, tzinfo=timezone.utc),  # 18:00-19:55
            datetime(2026, 5, 27, 20, 0, 0, tzinfo=timezone.utc),  # 20:00-21:55
            datetime(2026, 5, 27, 22, 0, 0, tzinfo=timezone.utc),  # 22:00-23:55
        ]

        all_polls = []
        for run_time in run_times:
            scheduler = PollScheduler(base_time=run_time, schedule_window_hours=2)
            polls = scheduler.schedule_polls(24)
            all_polls.extend(polls)

        # Should have 288 total polls (12 runs × 24 polls)
        assert len(all_polls) == 288

        # Verify no gaps (each poll should be 5 minutes apart)
        for i in range(len(all_polls) - 1):
            diff = all_polls[i + 1] - all_polls[i]
            assert diff == timedelta(minutes=5), f"Gap detected at poll {i}"

        # Verify first and last poll span full day minus 5 minutes
        total_span = all_polls[-1] - all_polls[0]
        expected_span = timedelta(minutes=287 * 5)  # 287 intervals
        assert total_span == expected_span

    def test_schedule_different_counts_maintain_distribution(self):
        """Test that different poll counts maintain even distribution."""
        base_time = datetime(2026, 5, 27, 0, 0, 0, tzinfo=timezone.utc)
        scheduler = PollScheduler(base_time=base_time, schedule_window_hours=24)

        # 24 polls over 24 hours = 1 per hour (60 minutes apart)
        times_24 = scheduler.schedule_polls(24)
        for i in range(len(times_24) - 1):
            diff = times_24[i + 1] - times_24[i]
            assert diff == timedelta(minutes=60)

        # 288 polls over 24 hours = 12 per hour (5 minutes apart)
        times_288 = scheduler.schedule_polls(288)
        for i in range(len(times_288) - 1):
            diff = times_288[i + 1] - times_288[i]
            assert diff == timedelta(minutes=5)
