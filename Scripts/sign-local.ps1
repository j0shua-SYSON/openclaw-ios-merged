<#
Local iOS (re-)sign via zsign — no Mac/Xcode needed.

Signs an unsigned IPA with a .p12 + .mobileprovision using the bundled Windows
zsign (zsign-windows-x64\zsign.exe). The p12 password is read from the cert
folder's readme.txt, so no secret lives in this script.

Usage:
  .\Scripts\sign-local.ps1                          # signs .tmp\OpenClaw-unsigned.ipa
  .\Scripts\sign-local.ps1 -Ipa path\to\build.ipa
  .\Scripts\sign-local.ps1 -CertDir "D:\certs\MyCert"
#>
param(
  [string]$Ipa = ".tmp\OpenClaw-unsigned.ipa",
  [string]$CertDir = "F:\JOSHUA_1st_2021\projects\chatgpt_deepseek_youtube\VIETNAM AIRLINES JSC",
  [string]$Out
)

$ErrorActionPreference = "Stop"
$root  = Split-Path -Parent $PSScriptRoot
$zsign = Join-Path $root "zsign-windows-x64\zsign.exe"
$tmp   = Join-Path $root ".tmp\zsign_tmp"

if (-not (Test-Path $zsign)) { throw "zsign not found at $zsign" }
$p12  = Get-ChildItem "$CertDir\*.p12" | Select-Object -First 1
$prov = Get-ChildItem "$CertDir\*.mobileprovision" | Select-Object -First 1
if (-not $p12)  { throw "No .p12 in $CertDir" }
if (-not $prov) { throw "No .mobileprovision in $CertDir" }

# Password from readme.txt: the token after "password" (skipping the : / fullwidth ：).
# Matched without the fullwidth colon literal to avoid PS 5.1 script-encoding issues.
$readme = Get-Content "$CertDir\readme.txt" -Raw -Encoding UTF8
if ($readme -match 'password[^A-Za-z0-9]*([A-Za-z0-9][\w.@!#$%^&*+=~-]*)') { $pw = $Matches[1] }
if (-not $pw) { throw "Could not read password from $CertDir\readme.txt" }

if (-not $Out) { $Out = ($Ipa -replace '\.ipa$','') + "-signed.ipa" }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

Write-Output "Signing $Ipa -> $Out  (cert: $($p12.Name))"
& $zsign -k $p12.FullName -p $pw -m $prov.FullName -t $tmp -o $Out $Ipa
if ($LASTEXITCODE -eq 0 -and (Test-Path $Out)) {
  Write-Output ("Signed OK -> {0} ({1:0} MB)" -f $Out, ((Get-Item $Out).Length/1MB))
} else {
  Write-Output "zsign FAILED (exit $LASTEXITCODE)"
}
