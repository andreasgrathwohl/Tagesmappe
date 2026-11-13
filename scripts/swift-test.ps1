<#
.SYNOPSIS
  Fuehrt die Tests eines Swift-Pakets (Standard: Packages/FrontstageCore) unter Windows aus.

.DESCRIPTION
  Laedt die Umgebung der Swift-Toolchain (Path, SDKROOT aus den Benutzer-/Systemvariablen) und die
  Entwicklerumgebung von Visual Studio (Linker link.exe, Windows-SDK) und ruft dann `swift test` auf.
  Nur fuer reine Logik-Pakete ohne SwiftUI/SwiftData/UIKit - die App selbst baut nur die CI auf macOS.
  Aendert keine Dateien ausser dem .build-Ordner des Pakets.

  Diese Datei enthaelt bewusst nur ASCII-Zeichen (Windows PowerShell 5.1 liest .ps1 ohne BOM als cp1252).

.EXAMPLE
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\scripts\swift-test.ps1

.EXAMPLE
  .\scripts\swift-test.ps1 -PackagePath Packages\FrontstageCore -Filter LessonKeyTests
#>
param(
    [string]$PackagePath = "Packages\FrontstageCore",
    [string]$Filter = ""
)

$ErrorActionPreference = 'Stop'

Write-Host "swift-test.ps1" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan

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
$swift = Get-Command swift -ErrorAction SilentlyContinue
if (-not $swift) {
    Write-Host "FEHLER: swift.exe nicht im Path gefunden." -ForegroundColor Red
    Write-Host "        Swift-Toolchain installieren (siehe oben) und ein neues Terminal oeffnen." -ForegroundColor Yellow
    exit 1
}
Write-Host "OK  $($swift.Source)" -ForegroundColor Green

# [2/3] Entwicklerumgebung von Visual Studio (link.exe, Windows-SDK)
Write-Host "[2/3] Visual-Studio-Umgebung laden..." -ForegroundColor Cyan
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Host "FEHLER: vswhere.exe nicht gefunden - Visual Studio mit C++-Werkzeugen fehlt." -ForegroundColor Red
    Write-Host "        Voraussetzungen siehe https://www.swift.org/install/windows/" -ForegroundColor Yellow
    exit 1
}
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vsPath) {
    Write-Host "FEHLER: Keine Visual-Studio-Installation mit C++-Werkzeugen (VC.Tools.x86.x64) gefunden." -ForegroundColor Red
    Write-Host "        Komponente im Visual Studio Installer nachinstallieren." -ForegroundColor Yellow
    exit 1
}
$vsPath = @($vsPath)[0]
$devShell = Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Import-Module $devShell
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64" | Out-Null
if (-not (Get-Command link.exe -ErrorAction SilentlyContinue)) {
    Write-Host "FEHLER: link.exe nach dem Laden der Visual-Studio-Umgebung nicht gefunden." -ForegroundColor Red
    Write-Host "        C++-Buildwerkzeuge in $vsPath pruefen." -ForegroundColor Yellow
    exit 1
}
Write-Host "OK  $vsPath" -ForegroundColor Green

# [3/3] Tests
Write-Host "[3/3] swift test --package-path $PackagePath ..." -ForegroundColor Cyan
$resolved = Resolve-Path $PackagePath -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Host "FEHLER: Paketpfad '$PackagePath' existiert nicht." -ForegroundColor Red
    Write-Host "        Vom Wurzelverzeichnis des Repositorys aus starten oder -PackagePath angeben." -ForegroundColor Yellow
    exit 1
}
$swiftArgs = @("test", "--package-path", $resolved.Path)
if ($Filter) { $swiftArgs += @("--filter", $Filter) }
& swift @swiftArgs
$testExit = $LASTEXITCODE

Write-Host ""
Write-Host "===== Zusammenfassung =====" -ForegroundColor Cyan
Write-Host "OK  Swift-Umgebung" -ForegroundColor Green
Write-Host "OK  Visual-Studio-Umgebung" -ForegroundColor Green
if ($testExit -eq 0) {
    Write-Host "OK  swift test (Exit-Code 0)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FEHLER: swift test fehlgeschlagen (Exit-Code $testExit)." -ForegroundColor Red
    Write-Host "        Fehlerausgabe oberhalb lesen; Tests oder Code korrigieren und erneut starten." -ForegroundColor Yellow
    exit 1
}
