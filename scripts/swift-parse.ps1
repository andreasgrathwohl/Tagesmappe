<#
.SYNOPSIS
  Prueft alle Swift-Dateien auf Syntaxfehler (swiftc -frontend -parse) - ohne Typpruefung.

.DESCRIPTION
  Laedt die Umgebung der Swift-Toolchain (Path, SDKROOT aus den Benutzer-/Systemvariablen) wie
  swift-test.ps1; die Visual-Studio-Umgebung wird zum Parsen nicht benoetigt. App-Code (SwiftUI,
  SwiftData) laesst sich auf Windows nicht typpruefen, Syntaxfehler findet dieses Skript aber.
  Gibt jede Fehlerzeile mit Pfad relativ zum Repo-Wurzelverzeichnis aus. Exit 1 bei mindestens
  einem Fehler. Aendert keine Dateien.

  Diese Datei enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1 liest .ps1 ohne BOM als cp1252).

.EXAMPLE
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\scripts\swift-parse.ps1

.EXAMPLE
  .\scripts\swift-parse.ps1 -Paths Frontstage\Data
#>
param(
    [string[]]$Paths = @("Frontstage", "FrontstageTests")
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host "swift-parse.ps1" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan

# [1/3] Umgebung der Swift-Toolchain
Write-Host "[1/3] Swift-Umgebung laden..." -ForegroundColor Cyan
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"
$sdkRoot = [System.Environment]::GetEnvironmentVariable("SDKROOT", "User")
if (-not $sdkRoot) { $sdkRoot = [System.Environment]::GetEnvironmentVariable("SDKROOT", "Machine") }
if (-not $sdkRoot) {
    Write-Host "FEHLER: Umgebungsvariable SDKROOT fehlt." -ForegroundColor Red
    Write-Host "        Swift-Toolchain installieren: winget install --id Swift.Toolchain -e --source winget" -ForegroundColor Yellow
    exit 1
}
$env:SDKROOT = $sdkRoot
$swiftc = Get-Command swiftc -ErrorAction SilentlyContinue
if (-not $swiftc) {
    Write-Host "FEHLER: swiftc.exe nicht im Path gefunden." -ForegroundColor Red
    Write-Host "        Swift-Toolchain installieren (siehe oben) und ein neues Terminal oeffnen." -ForegroundColor Yellow
    exit 1
}
Write-Host "OK  $($swiftc.Source)" -ForegroundColor Green

# [2/3] Dateien sammeln
Write-Host "[2/3] Swift-Dateien suchen..." -ForegroundColor Cyan
$files = @()
foreach ($p in $Paths) {
    $full = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $repoRoot $p }
    if (-not (Test-Path $full)) {
        Write-Host "FEHLER: Pfad '$p' existiert nicht." -ForegroundColor Red
        Write-Host "        Vom Repo aus starten oder -Paths mit vorhandenen Ordnern angeben." -ForegroundColor Yellow
        exit 1
    }
    $files += @(Get-ChildItem -Path $full -Recurse -Filter *.swift -File)
}
if ($files.Count -eq 0) {
    Write-Host "FEHLER: Keine *.swift-Dateien unter: $($Paths -join ', ')" -ForegroundColor Red
    Write-Host "        -Paths pruefen." -ForegroundColor Yellow
    exit 1
}
Write-Host "OK  $($files.Count) Dateien" -ForegroundColor Green

# [3/3] Parsen
Write-Host "[3/3] swiftc -frontend -parse ..." -ForegroundColor Cyan
$badFiles = 0
$errorLines = 0
foreach ($f in $files) {
    $rel = $f.FullName
    if ($rel.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $rel.Substring($repoRoot.Length).TrimStart('\', '/')
    }
    # Stderr ohne 2>&1 abfangen: ErrorAction lokal auf Continue, Ausgabe in Datei umleiten.
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $ErrorActionPreference = 'Continue'
        & swiftc -frontend -parse $f.FullName 2> $errFile | Out-Null
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $lines = @(Get-Content -Path $errFile | Where-Object { $_ -match ': error:' })
    } finally {
        $ErrorActionPreference = 'Stop'
        Remove-Item $errFile -ErrorAction SilentlyContinue
    }
    if ($code -ne 0 -or $lines.Count -gt 0) {
        $badFiles++
        if ($lines.Count -eq 0) {
            Write-Host "FEHLER: $rel (swiftc Exit-Code $code, keine Fehlerzeile)" -ForegroundColor Red
            $errorLines++
        }
        foreach ($l in $lines) {
            $shown = $l.Replace($f.FullName, $rel)
            Write-Host "FEHLER: $shown" -ForegroundColor Red
            $errorLines++
        }
    }
}

Write-Host ""
Write-Host "===== Zusammenfassung =====" -ForegroundColor Cyan
Write-Host "OK  Swift-Umgebung" -ForegroundColor Green
Write-Host "OK  $($files.Count) Dateien geprueft" -ForegroundColor Green
if ($badFiles -eq 0) {
    Write-Host "OK  0 Syntaxfehler" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FEHLER: $errorLines Fehlerzeile(n) in $badFiles Datei(en)." -ForegroundColor Red
    Write-Host "        Fehler oberhalb beheben und erneut starten." -ForegroundColor Yellow
    exit 1
}
