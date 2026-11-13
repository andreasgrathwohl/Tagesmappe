# Task 8 Report: Zuordnungen und Stiftnotizen

Built: `Frontstage/Data/DataStore+MaterialLinks.swift` (all interfaces of the brief) and `FrontstageTests/Data/DataStoreMaterialLinkTests.swift` (all brief tests written out, plus links(from:through:) and cancelled-lesson-not-orphaned).
Evidence: app code, cannot build on Windows; verified by careful reading only. No CI run.
Design: all link queries load fully and filter in memory (small sets, avoids #Predicate limits). Moves save first, then mergeDuplicates(); no move without a target saves. No file access.
Deviations: none from real APIs (ParallelLessonFinder, nextLesson, mergeDuplicates, setLessonKey/setReference used as they are). Tests seed the store via addEntry and read keys via lessons(on:).
Concerns: not compiled; AK-22 test relies on Fixture A Thu 1st period 8a Englisch being the next lesson of Di 8a.
