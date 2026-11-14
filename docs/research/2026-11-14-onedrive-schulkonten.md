# Prüfnotiz — OneDrive mit Schulkonten (Q-33, Q-34)

Stand 2026-11-14, Recherche in der Microsoft-Dokumentation. Befunde mit Quelle, keine Entscheidung. Frontstage
nutzt laut ADR-0012 die delegierte Berechtigung `Files.ReadWrite` und den App-Ordner `/me/drive/special/approot`.

## Q-33 — Delta auf dem App-Ordner bei Schul- und Arbeitskonten

Wahrscheinlich ja, aber **nicht belegt** (Zuversicht etwa 60 %).

- „Using app folder in OneDrive and SharePoint“ nennt den App-Ordner ausdrücklich für OneDrive for work or school
  und OneDrive for home: <https://learn.microsoft.com/en-us/graph/onedrive-sharepoint-appfolder>
- „What is an App Folder“ führt `GET /drive/special/approot:/{path}:/delta` als unterstützte Operation, ohne nach
  Kontoart zu unterscheiden: <https://learn.microsoft.com/en-us/onedrive/developer/rest-api/concepts/special-folders-appfolder>
- Die Delta-Referenz zeigt für Arbeitskonten nur Routen am Wurzelordner und schweigt zu `special/approot/delta`:
  <https://learn.microsoft.com/en-us/graph/api/driveitem-delta>
- Eigenheiten bei Arbeitskonten: kein `ctag` im Delta, bei Löschungen fehlen `ctag` und `name`, kein
  `parentReference.path` (über die Id verfolgen); HTTP 410 verlangt eine vollständige Neuaufzählung.

Folge für den Bau: Delta bleibt Beschleunigung, nicht Voraussetzung; der Rückfall „Modellordner auflisten“ aus
ADR-0012 deckt das ab. Prüfung im Schul-Testmandanten (Microsoft-365-Entwicklermandant oder Education-Testkonto).

## Q-34 — Darf die Lehrkraft selbst zustimmen?

Hängt vom Mandanten ab.

- `Files.ReadWrite` (delegiert) braucht laut Berechtigungsreferenz keine Administratorzustimmung:
  <https://learn.microsoft.com/en-us/graph/permissions-reference>
- Mandanten können die Nutzerzustimmung abschalten oder auf verifizierte Herausgeber und als gering eingestufte
  Berechtigungen beschränken; die Einstufung trifft der Administrator selbst:
  <https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/configure-user-consent>,
  <https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/configure-permission-classifications>
- Seit 2025 blockiert Microsofts verwaltete Standardrichtlinie Nutzerzustimmung für breite Berechtigungen wie
  `Files.ReadWrite.All`; ob das schmale `Files.ReadWrite` betroffen ist, ist nicht belegt (nur Drittquellen).
- Ohne Herausgeberverifizierung können Nutzer bei neueren mandantenübergreifenden Apps oft gar nicht zustimmen.
  Verifizierung über das Microsoft AI Cloud Partner Program, kostenlos, braucht eine eigene Domain:
  <https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview>
- `Files.ReadWrite.AppFolder` für Arbeitskonten ist widersprüchlich dokumentiert (Graph-Seite ja,
  Berechtigungsreferenz und ältere Q&A nein).

Folgerungen, die eine Entscheidung brauchen (nicht hier getroffen): Herausgeberverifizierung beantragen; eine
Anleitung für die Schul-IT mit Admin-Zustimmungs-Link
`https://login.microsoftonline.com/{tenant}/adminconsent?client_id={MSAL_CLIENT_ID}`; Zustimmungsfehler
(`AADSTS65001`, `AADSTS90094`) in der App mit Hinweis auf diese Anleitung; im Testmandanten prüfen, ob
`Files.ReadWrite.AppFolder` genügt.
