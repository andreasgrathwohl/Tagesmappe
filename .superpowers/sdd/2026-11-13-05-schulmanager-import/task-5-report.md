# Task 5 (Aufgabe 5) Report

Base c9e436b. Built SourceChangeResolver, ScheduleChangeMerger, ImportApplier (+ AppliedTimetable) in
Packages/FrontstageCore/Sources/FrontstageCore/TimetableSources/, tests in ImportApplyTests.swift (9 tests).

Evidence: RED (ImportApplier etc. not found, compile error), then GREEN 9/9; full core suite 279 tests pass.

Notes / deviations:
- task-brief script found no "Task" headings (plan uses "Aufgabe"); read plan directly.
- Resolver computes the day's lessons with changes: [] and matches period + class + subject (non-substitute).
- ImportApplier keeps existing order, appends added, dedupes equal entries.
- Added 2 extra tests (appliesChangedAndRemoved, cancellationWithoutMatchingLessonIsUnmatched).
