# Aufgabe 7 - Zugangsdaten im Schluesselbund und Passwort-Hash (App)

Hinweis: Das Skript task-brief fand die Aufgabe nicht ("Aufgabe" statt "Task" in den Ueberschriften); Brief direkt aus dem Plan (Zeilen 563-608) gelesen.

## Gebaut
- Frontstage/TimetableSources/CredentialStore.swift: SchulmanagerCredentials, CredentialStore, CredentialStoreError (nur OSStatus, nie Zugangsdaten).
- Frontstage/TimetableSources/KeychainCredentialStore.swift: generic password, Konto "schulmanager-online", AfterFirstUnlockThisDeviceOnly, Synchronizable=false, DataProtectionKeychain=true; save = delete + add.
- Frontstage/TimetableSources/SchulmanagerPasswordHash.swift: PBKDF2-SHA512, 99999 Runden, 512 Byte, Hex.
- Tests: KeychainCredentialStoreTests (2), SchulmanagerPasswordHashTests (2).

## Evidenz
- swift-parse.ps1: 79 Dateien, 0 Syntaxfehler.
- Referenzvektor lokal mit Node crypto.pbkdf2Sync nachgerechnet: Laenge 1024, Praefix f82673fd3caf5e8cb13026c51bd8746d, Suffix ae384c7d9538d1bf999d4da7acd0ff1d - stimmt mit dem Brief ueberein.
- Typen per Lektuere geprueft (CCKeyDerivationPBKDF-Signatur, Swift 6). Kein Build/CI (Windows).

## Abweichungen
- Zusaetzlicher Test hashIsDeterministicAndSaltDependent; CredentialStoreError als Fehlertyp ergaenzt.
- Fehlt kSecAttrAccessible-Pruefung im Test: Vergleich als String-Bridge der CFString-Konstante.

## Offen
- Keychain-Tests brauchen Entitlement keychain-access-groups (in project.yml vorhanden); beim CI-Lauf auf dem Test-Host belegen, ggf. nicht signiert -> errSecMissingEntitlement auf macOS.
