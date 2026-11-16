---
status: accepted
date: 2026-11-16
reversibility: two-way
area: plattform
---

# ADR-0014 — Rückmeldung per E-Mail über das System, ohne eigenen Server

Ergänzt durch ADR-0015 (2026-11-16): Rückmeldungen gehen bevorzugt an einen eigenen Dienst; der hier
festgelegte Weg über Mail, Teilen und Kopieren bleibt als Rückfall gültig.

## Context and Problem Statement

Andreas wünscht am 2026-11-16 eine In-App-Hilfe mit vielen Hilfeknöpfen und eine Möglichkeit, Ideen und
Hinweise zurückzumelden, mit Bildschirmfotos, auf die man zeichnen kann (FR-17 bis FR-17.5). Zu entscheiden
ist, auf welchem Weg eine Rückmeldung samt Bildern zu den Entwicklern gelangt und woher die Hilfeartikel
kommen. Das Produkt betreibt keine eigenen Server (NFR-2); jede Lösung mit Endpunkt, Konto oder Schlüssel
in der App müsste das aufweichen. Die Umkehrkosten sind gering: Der Weg steckt in einem Baustein der App
(Rückmeldung zusammenstellen und übergeben) und berührt weder Datenmodell noch Abgleich.

## Decision Drivers

- Keine Server des Produkts, keine Zugangsschlüssel in der App (NFR-2, NFR-4)
- Bilder mit mehreren Megabyte müssen mitgehen können (FR-17.4)
- Die Lehrkraft soll sehen, was sie verschickt, bevor es das Gerät verlässt (RISK-11)
- Muss im App Store funktionieren, nicht nur in TestFlight
- Hilfe muss im Klassenraum ohne verlässliches Netz lesbar sein (RISK-3)

## Considered Options

- E-Mail über das Mail-Programm des Systems an eine Adresse aus der Build-Einstellung; Teilen-Dialog als Rückfall
- Eigenes Web-Formular bzw. eigener Endpunkt, an den die App sendet
- GitHub-Issues direkt aus der App
- Nur das Feedback von TestFlight
- Bewertungen im App Store

## Decision Outcome

Chosen option: "E-Mail über das Mail-Programm des Systems", because sie ohne Server, Konto und Schlüssel
auskommt, Bilder als Anhang trägt und die Lehrkraft die vollständige Mail vor dem Senden sieht. Andreas hat
die Entscheidungen delegiert; der Controller hat sie am 2026-11-16 getroffen.

Festgelegt:

- **Senden:** am iPad über `MFMailComposeViewController`, am Mac über `NSSharingService` (`composeEmail`) mit
  Empfänger, Betreff, Text und Bildern als Anhang. Die App verschickt nie selbst; sie übergibt nur.
- **Empfangsadresse:** aus der Build-Einstellung `FEEDBACK_EMAIL`, über den Info.plist-Schlüssel
  `FrontstageFeedbackEmail` gelesen – wie `MSAL_CLIENT_ID`. Im Repo steht nur der Platzhalter
  `feedback@example.com`; die echte Adresse kommt in CI aus dem Secret `FEEDBACK_EMAIL` (Q-42). Eine leere,
  unaufgelöste oder Platzhalter-Adresse (`example.com`, `.local`, …) gilt als „keine Adresse“.
- **Rückfall:** Ohne Mail-Konto oder ohne Adresse bietet die App den Teilen-Dialog (Text und Bilder) und
  „Text kopieren“.
- **Entwurf** bleibt bis zum Senden oder Verwerfen nur auf dem Gerät (Ordner der App, nicht im Datenort,
  nicht gesichert); er wird nicht abgeglichen.
- **Hilfeartikel** liegen in der App, nicht online: Texte in `Localizable.xcstrings` (ADR-0009 bleibt
  unverändert), Aufbau (Themen, Gruppen, verwandte Themen) im Kern-Paket. Damit sind sie offline lesbar und
  mit derselben Übersetzungstabelle übersetzbar wie alle anderen Texte (Q-10).

### Consequences

- Nutzen: kein Server, kein Konto, kein Schlüssel; Bilder gehen als Anhang mit; die Lehrkraft sieht und
  kontrolliert die Mail; eine Antwort der Entwickler ist per E-Mail möglich; funktioniert in TestFlight und
  im App Store gleich.
- Kosten (Pflicht):
  - Ohne eingerichtetes Mail-Konto (am Mac ohne Mail-App-Konto, am iPad ohne Konto in „Mail“) bleibt nur
    Teilen oder Kopieren – ein Schritt mehr, und die Adresse muss die Lehrkraft dann selbst eintragen.
  - Rückmeldungen landen in einem Postfach statt in einem Aufgabenverfolger; Sortieren und Zusammenführen
    ist Handarbeit.
  - Die Mail enthält, was die Lehrkraft schreibt und aufnimmt, möglicherweise Schul- und Personendaten
    (RISK-11). Das Postfach der Entwickler wird damit zum Ort personenbezogener Daten – die
    Datenschutzerklärung muss das nennen (Q-42). Das widerspricht NFR-2 nicht, weil nichts automatisch und
    nichts ohne Sicht der Lehrkraft übertragen wird, ist aber eine Pflicht außerhalb der App.
  - Am Mac meldet `NSSharingService` nur die Übergabe an Mail, nicht das tatsächliche Senden; der Entwurf
    wird nach der Übergabe geleert.
  - Hilfeartikel in der Übersetzungstabelle sind lange Werte mit Zeilenumbrüchen; beim Bearbeiten außerhalb
    von Xcode muss man das JSON-Escaping beachten.
  - Neue Hilfe kommt nur mit einem App-Update.

### Revisit if

- Mehr als etwa 20 Rückmeldungen je Woche eingehen und das Postfach unübersichtlich wird (dann ein
  Aufgabenverfolger mit Weiterleitung aus dem Postfach, weiterhin ohne Schlüssel in der App).
- Viele Lehrkräfte kein Mail-Konto auf dem Gerät haben (Rückmeldungen über „Teilen“ dominieren).
- Hilfe zwischen zwei App-Versionen dringend geändert werden muss.

## Pros and Cons of the Options

### E-Mail über das Mail-Programm des Systems

- Vorzug: kein Server, Anhänge, volle Sicht der Lehrkraft, Rückkanal per Antwort.
- Nachteil: braucht ein eingerichtetes Mail-Konto; Postfach statt Aufgabenliste.

### Eigenes Web-Formular bzw. eigener Endpunkt

- Vorzug (verworfen): strukturiert, ohne Mail-Konto, direkte Ablage in einer Aufgabenliste.
- Nachteil: braucht einen Server des Produkts und seinen Betrieb (NFR-2); die App überträgt Daten an einen
  Ort, den die Lehrkraft nicht sieht.

### GitHub-Issues direkt aus der App

- Vorzug (verworfen): Rückmeldungen landen gleich in der Aufgabenliste.
- Nachteil: braucht einen Zugangsschlüssel in der App (auslesbar, missbrauchbar); Issues sind je nach Repo
  öffentlich; Bilder lassen sich über die Schnittstelle nicht einfach anhängen.

### Nur TestFlight-Feedback

- Vorzug (verworfen): eingebaut, mit Bildschirmfoto und Zeichnung, ohne eigenen Code.
- Nachteil: gibt es nur in Testfassungen; nach dem Start im App Store fiele die Rückmeldung weg.

### Bewertungen im App Store

- Vorzug (verworfen): kein eigener Code.
- Nachteil: öffentlich, ohne Bildschirmfotos, ohne Rückfrage; für Hinweise auf Fehler ungeeignet.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-plattform
- Anforderungen: docs/PRD.md FR-17 bis FR-17.5, RISK-11, Q-42
