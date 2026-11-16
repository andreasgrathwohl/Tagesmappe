"""Gleitendes Zeitfenster je Schlüssel, im Speicher (ein Prozess, siehe ADR-0015).

Jede App legt ihre Begrenzer in ``create_app`` an (``app.state``), nie auf Modulebene.
"""

from collections import defaultdict, deque
from collections.abc import Callable, Sequence
from datetime import datetime, timedelta
from math import ceil


class SlidingWindowLimiter:
    def __init__(self, rules: Sequence[tuple[int, timedelta]], clock: Callable[[], datetime]) -> None:
        self._rules = list(rules)
        self._clock = clock
        self._hits: defaultdict[str, deque[datetime]] = defaultdict(deque)
        self._longest = max((window for _, window in self._rules), default=timedelta(0))

    def _prune(self, key: str, now: datetime) -> deque[datetime]:
        hits = self._hits[key]
        while hits and now - hits[0] >= self._longest:
            hits.popleft()
        if not hits:
            self._hits.pop(key, None)
            return deque()
        return hits

    def _wait(self, key: str, now: datetime) -> int | None:
        hits = self._prune(key, now)
        longest_wait = 0.0
        for limit, window in self._rules:
            inside = [h for h in hits if now - h < window]
            if len(inside) >= limit:
                # Frei wird es, sobald der (limit)-letzte Treffer aus dem Fenster fällt
                release = inside[len(inside) - limit] + window
                longest_wait = max(longest_wait, (release - now).total_seconds())
        return max(1, ceil(longest_wait)) if longest_wait > 0 else None

    def blocked_for(self, key: str) -> int | None:
        return self._wait(key, self._clock())

    def record(self, key: str) -> None:
        now = self._clock()
        self._prune(key, now)
        self._hits[key].append(now)

    def check(self, key: str) -> int | None:
        wait = self._wait(key, self._clock())
        if wait is None:
            self.record(key)
        return wait
