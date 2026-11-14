# Aufgabe 4 – Wochenplan ableiten, Abweichungen erkennen (Kern)

BASE 0225e2d.

Gebaut: `SchulmanagerTimetableDeriver.derive` und `SchulmanagerChangeExtractor.changes` (Kern, TimetableSources/),
nach Algorithmus des Plans. Tests: 9 Deriver-, 6 Extractor-Tests (alle im Plan genannten plus
`cancelledLessonsStayInPlan`, `sharedLessonYieldsOneCancellationPerClass`).

Nachweis: RED (Quellen entfernt: "cannot find SchulmanagerChangeExtractor"), GREEN, volle Kern-Suite 270 Tests bestanden.
Beim ersten GREEN-Lauf war eine Testerwartung falsch (Sortierung nach Variante a vor b); Test korrigiert, nicht der Code.

Abweichungen/Hinweise:
- Der Plan-Heading heisst "Aufgabe 4"; das task-brief-Skript fand sie nicht (verlangt "Task"), Brief direkt aus der Plandatei gelesen.
- Extractor arbeitet je Klasse (gemeinsame Stunden mehrerer Klassen): Unveraenderte (Klasse, Fach)-Paare ergeben keine Abweichung.
- Bei zwei identischen Wochen und vorhandenem A/B-Plan wird weekVariantCount 1 geliefert (wie im Algorithmus), referenceWeekA = existing.
- Annahme: Lehrerplan enthaelt Vertretungen im Format wie dokumentiert (unverifiziert, Q-16).
