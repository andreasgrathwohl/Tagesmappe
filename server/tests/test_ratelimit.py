from datetime import UTC, datetime, timedelta

from frontstage_service.ratelimit import SlidingWindowLimiter

RULES = [(10, timedelta(minutes=1)), (30, timedelta(hours=1))]


class Clock:
    def __init__(self):
        self.now = datetime(2026, 1, 1, 12, 0, tzinfo=UTC)

    def __call__(self):
        return self.now


def test_limiter_minute_rule():
    limiter = SlidingWindowLimiter(RULES, Clock())
    assert all(limiter.check("a") is None for _ in range(10))
    wait = limiter.check("a")
    assert wait is not None and wait > 0


def test_limiter_hour_rule_and_window_slides():
    clock = Clock()
    limiter = SlidingWindowLimiter(RULES, clock)
    for _ in range(3):  # 30 Treffer, jeweils 10 pro Minutenfenster
        for _ in range(10):
            assert limiter.check("a") is None
        clock.now += timedelta(minutes=2)
    wait = limiter.check("a")
    assert wait is not None and wait > 0  # Stundenregel greift
    clock.now += timedelta(hours=1)
    assert limiter.check("a") is None  # Fenster ist weitergerutscht


def test_limiter_keys_independent():
    limiter = SlidingWindowLimiter(RULES, Clock())
    for _ in range(10):
        limiter.check("a")
    assert limiter.check("a") is not None
    assert limiter.check("b") is None


def test_limiter_blocked_for_does_not_count():
    limiter = SlidingWindowLimiter([(5, timedelta(minutes=1))], Clock())
    for _ in range(5):
        assert limiter.blocked_for("a") is None
    assert limiter.check("a") is None  # nichts verbraucht
    limiter2 = SlidingWindowLimiter([(5, timedelta(minutes=1))], Clock())
    for _ in range(5):
        limiter2.record("a")
    wait = limiter2.blocked_for("a")
    assert wait is not None and wait > 0
