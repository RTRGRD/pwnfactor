<#
.SYNOPSIS
  Portable pre-release security audit harness -- read-only, stack-aware.

.DESCRIPTION
  One command to run a pre-release security battery against ANY app and emit a consolidated
  report. READ-ONLY: never commits, never deploys, never modifies app source. Writes only under
  the output dir (default: .security-audit/<timestamp>/).

  Pipeline (each step degrades gracefully + logs if a tool is missing -- no silent skips):
    1. Static app audit   -- STACK-AWARE. Electron -> electronegativity (OWASP Electron auditor).
                             Other stacks (Tauri/Rust/Go/Python/Node-web) -> the script DETECTS the
                             stack and RECOMMENDS the right tool instead of blindly scanning. The
                             calling agent should surface the recommendation and ask the user.
    2. npm audit drift    -- (Node projects) vs a configurable critical/high baseline
    3. Syft SBOM          -- CycloneDX, MULTI-ECOSYSTEM (npm + pip + cargo + go + nuget + ...)
    4. Grype CVE scan     -- SBOM + optional packaged release dir -- NVD + GitHub Advisory
    5. Secret/credential grep (source tree)
    6. Codex adversarial review (optional, -Codex) -- writes a ready-to-run prompt + best-effort run
    7. Local AV pre-scan GATE (no upload) -- Windows Defender / ClamAV / Authenticode / CAPA
    8. Malware sandbox / reputation -- VirusTotal v3 / Hybrid Analysis / Joe -- RUN #2, gated on step 7
    9. REPORT.md          -- consolidated pass/fail summary

  Sandbox API keys are read from the real environment first, then from -EnvFile -- LOCAL ONLY.

.PARAMETER RepoRoot
  The repo to audit. Default: the current directory. Pass -RepoRoot . from a bundled plugin skill so
  the script audits the user's repo, not the plugin's own folder.

.PARAMETER RunNumber
  1 = baseline source-level sweep (default). 2 = full launch gate (adds release/ Grype scan + the
  local AV pre-scan + sandbox reputation on a shipping binary).

.PARAMETER ProjectName
  Friendly name for the report header. Defaults to the repo-root folder name.

.PARAMETER BinaryPath
  Path to the shipping artifact (.exe / .dmg / .AppImage / binary) for the local AV pre-scan +
  sandbox reputation. Required for the sandbox step (RUN #2).

.PARAMETER ReleaseDir
  Path to the packaged app dir for Grype to scan (e.g. release/win-unpacked). RUN #2.

.PARAMETER StaticTool
  auto (default) = detect the stack and run electronegativity ONLY for Electron, otherwise recommend.
  electronegativity = force the Electron auditor. semgrep = run semgrep (universal). none = skip step 1.

.PARAMETER BaselineCritical / BaselineHigh
  Accepted npm-audit critical/high counts before the step is a BLOCKER. Default 0/0 (strict).
  Raise to accept a documented, tracked set of known-unfixable advisories.

.PARAMETER EnvFile
  Path to a dotenv file holding VT_API_KEY / HA_API_KEY / JOE_API_KEY. Default: .security-audit.env
  at the repo root (gitignore it). Real environment variables take precedence over the file.

.PARAMETER ToolsDir
  Fallback dir to discover grype/syft/codex/capa binaries. Default: ~/.security-audit-tools.

.PARAMETER OutputDir
  Where to write artifacts. Default: <repo>/.security-audit/<timestamp>/.

.PARAMETER ScanPaths
  Override the secret-scan roots. Default: auto (whole repo minus build/vendor/output dirs).

.PARAMETER ExcludeSecretPattern
  Extra regex of project-specific public-by-design tokens to exclude from the secret scan
  (e.g. a public web API key). Applied on top of the built-in example/placeholder filter.

.PARAMETER Codex
  Also fire the Codex adversarial review (optional, slowest step).

.PARAMETER SkipSandbox
  Force-skip the PUBLIC sandbox submission even on RUN #2. (The LOCAL AV pre-scan still runs --
  see -LocalAVOnly.)

.PARAMETER LocalAVOnly
  RUN #2: run the local AV pre-scan (Defender/ClamAV/Authenticode/CAPA) and NEVER upload to any
  public sandbox. Use for a closed-source app you don't want on VirusTotal's public corpus.

.EXAMPLE
  pwsh -File bin/run-security-audit.ps1                       # RUN #1 baseline (source-level)
  pwsh -File bin/run-security-audit.ps1 -Codex                # + adversarial review
  pwsh -File bin/run-security-audit.ps1 -RunNumber 2 -BinaryPath "release/App Setup 1.0.0.exe" -ReleaseDir "release/win-unpacked"
  pwsh -File bin/run-security-audit.ps1 -RunNumber 2 -BinaryPath "dist/App.AppImage" -LocalAVOnly
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [ValidateSet(1,2)][int]$RunNumber = 1,
  [string]$ProjectName = "",
  [string]$BinaryPath = "",
  [string]$ReleaseDir = "",
  [ValidateSet('auto','electronegativity','semgrep','none')][string]$StaticTool = 'auto',
  [int]$BaselineCritical = 0,
  [int]$BaselineHigh = 0,
  [string]$EnvFile = "",
  [string]$ToolsDir = "",
  [string]$OutputDir = "",
  [string[]]$ScanPaths = @(),
  [string]$ExcludeSecretPattern = "",
  [switch]$Codex,
  [switch]$SkipSandbox,
  [switch]$LocalAVOnly
)

$ErrorActionPreference = 'Stop'
# Plugin-aware: -RepoRoot wins; else the current directory (the repo being audited). As a bundled
# plugin skill this script lives in the plugin tree, NOT in the target repo's bin/.
if ($RepoRoot) { $RepoRoot = (Resolve-Path $RepoRoot).Path } else { $RepoRoot = (Get-Location).Path }
Set-Location $RepoRoot
if (-not $ProjectName) { $ProjectName = Split-Path $RepoRoot -Leaf }

# $IsWindows is auto-set in PowerShell 7+. Define it for Windows PowerShell 5.1 too.
if ($null -eq $IsWindows) { $IsWindows = $true }

# ---- audit dir ----------------------------------------------------------------
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $OutputDir) { $OutputDir = Join-Path $RepoRoot '.security-audit' }
$AuditDir = Join-Path $OutputDir $ts
New-Item -ItemType Directory -Force -Path $AuditDir | Out-Null
$Report = Join-Path $AuditDir 'REPORT.md'

# ---- report helpers -----------------------------------------------------------
$script:Blockers = @()
$script:Warnings = @()
function Rpt([string]$line) { Add-Content -Path $Report -Value $line -Encoding utf8 }
function Section([string]$t) { Rpt ""; Rpt "## $t" }
function Note([string]$m) { Write-Host "[sec-audit] $m" -ForegroundColor Cyan }
function Blocker([string]$m){ $script:Blockers += $m; Rpt "- [BLOCKER]: $m" }
function Warn([string]$m)  { $script:Warnings += $m; Rpt "- [WARN] $m" }
function Ok([string]$m)    { Rpt "- [OK] $m" }

Rpt "# $ProjectName security audit -- RUN #$RunNumber -- $ts"
Rpt ""
Rpt "Read-only. Artifacts in ``$AuditDir``. Never commits/deploys."

# ---- tool discovery -----------------------------------------------------------
if (-not $ToolsDir) { $ToolsDir = Join-Path $HOME '.security-audit-tools' }
function Resolve-Tool([string]$name) {
  $onPath = Get-Command $name -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  foreach ($ext in @('', '.exe')) {
    $local = Join-Path $ToolsDir "$name$ext"
    if (Test-Path $local) { return $local }
  }
  return $null
}
$Grype    = Resolve-Tool 'grype'
$Syft     = Resolve-Tool 'syft'
$CodexCli = Resolve-Tool 'codex'
$Semgrep  = Resolve-Tool 'semgrep'

# ---- secret key loader: real env first, then -EnvFile -------------------------
if (-not $EnvFile) { $EnvFile = Join-Path $RepoRoot '.security-audit.env' }
function Get-SecretKey([string]$key) {
  $v = [Environment]::GetEnvironmentVariable($key)
  if ($v) { return $v }
  if ($EnvFile -and (Test-Path $EnvFile)) {
    $line = Select-String -Path $EnvFile -Pattern "^\s*$key\s*=" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($line) { return ($line.Line -replace "^\s*$key\s*=\s*", '').Trim().Trim('"').Trim("'") }
  }
  return $null
}

# ---- stack detection ----------------------------------------------------------
# Returns: @{ Stack=<label>; Tool=<recommended static tool>; Install=<hint> }
function Get-AppStack {
  $pkgPath = Join-Path $RepoRoot 'package.json'
  $deps = @()
  if (Test-Path $pkgPath) {
    try {
      $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
      if ($pkg.dependencies)    { $deps += $pkg.dependencies.PSObject.Properties.Name }
      if ($pkg.devDependencies) { $deps += $pkg.devDependencies.PSObject.Properties.Name }
    } catch {}
  }
  $hasElectron = ($deps -contains 'electron') -or (Test-Path (Join-Path $RepoRoot 'dist-electron'))
  $hasTauri    = (Test-Path (Join-Path $RepoRoot 'src-tauri')) -or ($deps -contains '@tauri-apps/api') -or ($deps -contains '@tauri-apps/cli')

  if ($hasElectron) { return @{ Stack='Electron'; Tool='electronegativity'; Install='npx @doyensec/electronegativity (no install)' } }
  if ($hasTauri)    { return @{ Stack='Tauri (Rust + web)'; Tool='cargo-audit + cargo-geiger (Rust) + semgrep (web); check tauri.conf.json allowlist/CSP'; Install='cargo install cargo-audit cargo-geiger ; pip install semgrep' } }
  if (Test-Path (Join-Path $RepoRoot 'Cargo.toml')) { return @{ Stack='Rust'; Tool='cargo-audit (RUSTSEC) + cargo-geiger (unsafe)'; Install='cargo install cargo-audit cargo-geiger' } }
  if (Test-Path (Join-Path $RepoRoot 'go.mod'))     { return @{ Stack='Go'; Tool='govulncheck + gosec'; Install='go install golang.org/x/vuln/cmd/govulncheck@latest ; go install github.com/securego/gosec/v2/cmd/gosec@latest' } }
  foreach ($py in @('pyproject.toml','requirements.txt','setup.py','Pipfile')) {
    if (Test-Path (Join-Path $RepoRoot $py)) { return @{ Stack='Python'; Tool='pip-audit + bandit'; Install='pip install pip-audit bandit' } }
  }
  if (Test-Path $pkgPath) { return @{ Stack='Node / web'; Tool='semgrep (p/owasp-top-ten, p/javascript) -- npm audit already covers deps'; Install='pip install semgrep  OR  brew install semgrep' } }
  return @{ Stack='Unknown'; Tool='semgrep (p/security-audit) -- universal SAST fallback'; Install='pip install semgrep' }
}

# ================================================================= 1. Static app audit (stack-aware)
Section "1. Static application audit (stack-aware)"
$stack = Get-AppStack
Rpt "- Detected stack: **$($stack.Stack)**"
Rpt "- Recommended static-analysis tool for this stack: $($stack.Tool)"
Rpt "  Install: $($stack.Install)"

function Invoke-Electronegativity {
  $targets = @()
  if (Test-Path 'dist-electron') { $targets += 'dist-electron' }
  if (Test-Path 'dist')          { $targets += 'dist' }
  if (-not $targets) { Warn "No compiled dist-electron/ or dist/ found -- build first for best signal (electronegativity skipped)."; return }
  foreach ($t in $targets) {
    $csv = Join-Path $AuditDir "electronegativity-$t.csv"
    Note "Electronegativity scanning $t ..."
    try {
      & npx --yes '@doyensec/electronegativity' -i $t -o $csv 2>&1 | Out-File (Join-Path $AuditDir "electronegativity-$t.log") -Encoding utf8
      if (Test-Path $csv) {
        $rows = @(Import-Csv $csv)
        $high = @($rows | Where-Object { $_.severity -match 'HIGH' }).Count
        $med  = @($rows | Where-Object { $_.severity -match 'MEDIUM' }).Count
        Rpt "- ${t}: $($rows.Count) findings ($high HIGH, $med MEDIUM) -> electronegativity-${t}.csv"
        if ($high -gt 0) { Warn "${t} has $high HIGH Electronegativity finding(s) -- triage (many are FPs: vendored libs, dev-only localhost loadURL)." }
      }
    } catch { Warn "Electronegativity failed on ${t}: $($_.Exception.Message)" }
  }
}

function Invoke-Semgrep {
  if (-not $Semgrep) { Warn "semgrep not found (install: pip install semgrep). Static SAST step skipped -- run it manually."; return }
  Note "semgrep scanning (p/security-audit) ..."
  $sgOut = Join-Path $AuditDir 'semgrep.json'
  try {
    & $Semgrep --config p/security-audit --json --output $sgOut --error 2>&1 | Out-File (Join-Path $AuditDir 'semgrep.log') -Encoding utf8
    if (Test-Path $sgOut) {
      $sg = Get-Content $sgOut -Raw | ConvertFrom-Json
      $n = @($sg.results).Count
      $err = @($sg.results | Where-Object { $_.extra.severity -eq 'ERROR' }).Count
      Rpt "- semgrep: $n finding(s) ($err high-severity) -> semgrep.json"
      if ($err -gt 0) { Warn "semgrep flagged $err high-severity finding(s) -- triage." }
    }
  } catch { Warn "semgrep failed: $($_.Exception.Message)" }
}

switch ($StaticTool) {
  'electronegativity' { Invoke-Electronegativity }
  'semgrep'           { Invoke-Semgrep }
  'none'              { Rpt "- Static app audit skipped (-StaticTool none)." }
  'auto' {
    if ($stack.Stack -eq 'Electron') { Invoke-Electronegativity }
    else {
      Warn "Static app audit NOT auto-run for a $($stack.Stack) app. AGENT: surface the recommended tool above and ask the user whether to (a) install + run it, (b) run semgrep (-StaticTool semgrep), or (c) skip. electronegativity is Electron-only and was intentionally NOT run."
    }
  }
}

# ================================================================= 2. npm audit drift (Node only)
Section "2. npm audit drift (Node projects)"
if (Test-Path (Join-Path $RepoRoot 'package.json')) {
  try {
    $auditJson = & npm audit --json 2>$null | Out-String
    $a = $auditJson | ConvertFrom-Json
    $v = $a.metadata.vulnerabilities
    $auditJson | Out-File (Join-Path $AuditDir 'npm-audit-root.json') -Encoding utf8
    Rpt "- root: critical=$($v.critical) high=$($v.high) moderate=$($v.moderate) low=$($v.low)  (baseline: <=$BaselineCritical crit / <=$BaselineHigh high)"
    if ($v.critical -gt $BaselineCritical -or $v.high -gt $BaselineHigh) { Blocker "npm audit DRIFT above baseline ($BaselineCritical crit / $BaselineHigh high). Review, then either fix or raise -BaselineCritical/-BaselineHigh with a tracked rationale." }
    else { Ok "root npm audit within accepted baseline" }
  } catch { Warn "npm audit (root) failed: $($_.Exception.Message)" }
  # AUTHORITATIVE shipped-CVE picture: production deps only (drops devDeps + build tooling).
  try {
    $prodJson = & npm audit --omit=dev --json 2>$null | Out-String
    $pv = ($prodJson | ConvertFrom-Json).metadata.vulnerabilities
    $prodJson | Out-File (Join-Path $AuditDir 'npm-audit-prod.json') -Encoding utf8
    Rpt "- SHIPPED (prod-only, AUTHORITATIVE): critical=$($pv.critical) high=$($pv.high) moderate=$($pv.moderate) low=$($pv.low)"
  } catch { Warn "npm audit --omit=dev failed: $($_.Exception.Message)" }
} else { Rpt "- No package.json at repo root -- npm audit N/A (multi-ecosystem CVEs are covered by Syft+Grype below)." }

# ================================================================= 3. Syft SBOM (multi-ecosystem)
Section "3. Syft SBOM (CycloneDX, multi-ecosystem)"
$Sbom = Join-Path $AuditDir 'sbom.cdx.json'
if ($Syft) {
  Note "Syft cataloguing (can take a few minutes on large dependency trees) ..."
  $env:SYFT_CHECK_FOR_APP_UPDATE = 'false'
  try {
    # --source-name/-version avoid the 'no explicit name/version for directory source' SBOM that Grype rejects.
    & $Syft scan "dir:$RepoRoot" --source-name $ProjectName --source-version $ts `
        --exclude './.git/**' --exclude './.security-audit/**' --exclude './release/**' `
        --exclude './dist/**' --exclude './dist-electron/**' --exclude './build/**' --exclude './target/**' `
        -o "cyclonedx-json=$Sbom" 2>&1 | Out-File (Join-Path $AuditDir 'syft.log') -Encoding utf8
    if (Test-Path $Sbom) { $n = (Get-Content $Sbom -Raw | ConvertFrom-Json).components.Count; Ok "SBOM generated: $n components -> sbom.cdx.json" }
  } catch { Warn "Syft failed: $($_.Exception.Message)" }
} else { Warn "Syft not found (install: winget install Anchore.Syft, or drop the binary in $ToolsDir). SBOM step skipped." }

# ================================================================= 4. Grype CVE scan
Section "4. Grype CVE scan (NVD + GitHub Advisory)"
if ($Grype) {
  $env:GRYPE_CHECK_FOR_APP_UPDATE = 'false'
  $scan = if (Test-Path $Sbom) { "sbom:$Sbom" } else { "dir:$RepoRoot" }
  Note "Grype scanning $scan (first run downloads the vuln DB) ..."
  try {
    $gout = Join-Path $AuditDir 'grype.json'
    & $Grype $scan -o "json=$gout" 2>&1 | Out-File (Join-Path $AuditDir 'grype.log') -Encoding utf8
    if (Test-Path $gout) {
      $g = Get-Content $gout -Raw | ConvertFrom-Json
      $crit = @($g.matches | Where-Object { $_.vulnerability.severity -eq 'Critical' }).Count
      $high = @($g.matches | Where-Object { $_.vulnerability.severity -eq 'High' }).Count
      Rpt "- Grype: $($g.matches.Count) matches (Critical=$crit, High=$high) -> grype.json"
      if ($crit -gt 0) { Warn "Grype found $crit Critical CVE(s) -- triage (a repo-dir scan over-reports dev/build tooling; cross-check vs the shipped set)." }
    }
  } catch { Warn "Grype failed: $($_.Exception.Message)" }
  if ($RunNumber -eq 2 -and $ReleaseDir -and (Test-Path $ReleaseDir)) {
    Note "Grype scanning packaged app: $ReleaseDir ..."
    try { & $Grype "dir:$ReleaseDir" -o "json=$(Join-Path $AuditDir 'grype-release.json')" 2>&1 | Out-File (Join-Path $AuditDir 'grype-release.log') -Encoding utf8; Ok "Packaged-app Grype scan captured (note: bundlers often strip versions -> under-reports npm; trust npm audit --omit=dev for that)." }
    catch { Warn "Grype release scan failed" }
  }
} else { Warn "Grype not found (install: winget install Anchore.Grype, or drop the binary in $ToolsDir). CVE scan skipped." }

# ================================================================= 5. Secret grep
Section "5. Secret / credential scan"
$secOut = Join-Path $AuditDir 'secret-scan.txt'
$patterns = @{
  'Private key block'    = 'BEGIN [A-Z ]*PRIVATE KEY'
  'AWS access key'       = 'AKIA[0-9A-Z]{16}'
  'Anthropic key'        = 'sk-ant-[A-Za-z0-9_-]{10,}'
  'OpenAI-style key'     = 'sk-[A-Za-z0-9]{32,}'
  'Google API key'       = 'AIza[0-9A-Za-z_-]{35}'
  'Slack token'          = 'xox[baprs]-[A-Za-z0-9-]{10,}'
  'GitHub token'         = 'gh[pousr]_[A-Za-z0-9]{36,}'
  'Generic assigned'     = '(api[_-]?key|client[_-]?secret|access[_-]?token|password|passwd|bearer)\s*[:=]\s*\S{16,}'
}
if ($ScanPaths -and $ScanPaths.Count -gt 0) { $roots = $ScanPaths } else { $roots = @($RepoRoot) }
$excludeDirs = '[\\/](node_modules|\.git|dist|dist-electron|build|target|vendor|release|\.security-audit|__pycache__)[\\/]'
$scanFiles = Get-ChildItem -Recurse -File -Path $roots -Include *.ts,*.tsx,*.js,*.mjs,*.cjs,*.json,*.ps1,*.sh,*.py,*.rs,*.go,*.java,*.rb,*.env,*.yml,*.yaml,*.html -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch $excludeDirs -and $_.Name -notmatch '^\.?security-audit.*\.env$' }
$baseFilter = '(example|placeholder|YOUR_|<your|dummy|sample|FAKE|test|fixture)'
if ($ExcludeSecretPattern) { $baseFilter = "($baseFilter|$ExcludeSecretPattern)" }
$hits = 0
"# Secret scan $ts" | Out-File $secOut -Encoding utf8
foreach ($k in $patterns.Keys) {
  $m = $scanFiles | Select-String -Pattern $patterns[$k] -ErrorAction SilentlyContinue |
       Where-Object { $_.Line -notmatch $baseFilter }
  if ($m) { $hits += $m.Count; "== $k ($($m.Count)) ==" | Add-Content $secOut; $m | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" } | Add-Content $secOut }
}
if ($hits -eq 0) { Ok "No hardcoded credentials/keys in source (example/placeholder/test values excluded)." }
else { Warn "$hits potential secret hit(s) -- review secret-scan.txt. Public-by-design keys (e.g. a public web/client API key) can be excluded via -ExcludeSecretPattern." }

# ================================================================= 6. Codex adversarial (optional)
Section "6. Codex adversarial review (optional)"
$codexPrompt = @"
Act as an adversarial security reviewer for the $ProjectName codebase at $RepoRoot.
Read the code yourself (do not trust this prompt for facts). Focus on the highest-leverage surfaces:
input handling and validation, authentication/authorization, secret handling, path construction and
traversal, deserialization, command/SQL injection sinks, and any data egress (logs, external APIs,
telemetry). For each finding give: file:line, the threat model under which it is exploitable, severity,
and the minimal fix. Distinguish exploitable findings from defense-in-depth nits.
"@
$codexPromptFile = Join-Path $AuditDir 'codex-prompt.txt'
$codexPrompt | Out-File $codexPromptFile -Encoding utf8
if ($Codex -and $CodexCli) {
  Note "Running Codex adversarial review (cite-paths) ..."
  Rpt "- Codex prompt -> codex-prompt.txt"
  try {
    & $CodexCli exec $codexPrompt 2>&1 | Out-File (Join-Path $AuditDir 'codex-review.txt') -Encoding utf8
    Ok "Codex review captured -> codex-review.txt"
  } catch { Warn "Codex run failed ($($_.Exception.Message)). Prompt saved to codex-prompt.txt -- run it manually." }
} elseif ($Codex) { Warn "Codex requested but CLI not found on PATH. Prompt saved to codex-prompt.txt -- run it manually." }
else { Rpt "- Skipped (pass -Codex to enable). Ready-to-run prompt saved to codex-prompt.txt." }

# ================================================================= 7+8. Local AV pre-scan + sandbox (RUN #2)
Section "7. Local AV pre-scan + malware sandbox / reputation"

function Invoke-LocalPreScan([string]$file) {
  if (-not (Test-Path $file)) { Blocker "BinaryPath '$file' not found."; return $false }
  $clean = $true
  $sha = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
  Rpt "- Target: $(Split-Path $file -Leaf)  SHA256=$sha"
  if ($IsWindows) {
    $sig = Get-AuthenticodeSignature $file
    $signer = if ($sig.SignerCertificate) { ' / ' + $sig.SignerCertificate.Subject } else { '' }
    Rpt "- Signature: $($sig.Status)$signer"
    if ($sig.Status -ne 'Valid') { Warn "Binary not validly signed ($($sig.Status)) -- SIGN before any public sandbox upload to avoid false positives." }
    $mp = @('C:\Program Files\Windows Defender\MpCmdRun.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($mp) {
      Note 'Local: Windows Defender on-demand scan...'
      & $mp -Scan -ScanType 3 -File $file *> (Join-Path $AuditDir 'defender-scan.log')
      if ($LASTEXITCODE -eq 0) { Ok 'Windows Defender: no threats' }
      else { $clean = $false; Blocker "Windows Defender flagged the binary (exit $LASTEXITCODE) -- DO NOT public-submit; see defender-scan.log." }
    } else { Warn 'Windows Defender MpCmdRun not found -- Defender pre-scan skipped.' }
  } else { Rpt "- Non-Windows host: Authenticode + Defender skipped (Windows-only)." }
  # ClamAV (cross-platform; run freshclam first)
  if (Get-Command clamscan -ErrorAction SilentlyContinue) {
    Note 'Local: ClamAV scan...'
    & clamscan --no-summary $file *> (Join-Path $AuditDir 'clamav-scan.log')
    if ($LASTEXITCODE -eq 0) { Ok 'ClamAV: clean' }
    elseif ($LASTEXITCODE -eq 1) { $clean = $false; Blocker 'ClamAV flagged the binary -- DO NOT public-submit; see clamav-scan.log.' }
    else { Warn "ClamAV error (exit $LASTEXITCODE) -- did you run freshclam?" }
  } else { Warn 'ClamAV (clamscan) not installed -- skipped (optional; run freshclam before first scan).' }
  # CAPA optional static PE capability check (Mandiant). NAMES CAPABILITIES, NOT VERDICTS -- expect FPs.
  if (Get-Command capa -ErrorAction SilentlyContinue) {
    Note 'Local: CAPA static analysis...'; & capa -q $file *> (Join-Path $AuditDir 'capa.log'); Ok 'CAPA capabilities -> capa.log (review; rule NAMES are not verdicts).'
  } else { Rpt '- CAPA not installed (optional static PE check) -- skipped.' }
  return $clean
}

function Submit-Sandboxes([string]$file) {
  if (-not (Test-Path $file)) { Blocker "BinaryPath '$file' not found."; return }
  $sha = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
  $sbxDir = Join-Path $AuditDir 'sandbox'; New-Item -ItemType Directory -Force -Path $sbxDir | Out-Null
  # --- VirusTotal v3 (hash lookup; upload if unknown) ---
  $vt = Get-SecretKey 'VT_API_KEY'
  if ($vt) {
    try {
      $r = Invoke-RestMethod -Method Get -Uri "https://www.virustotal.com/api/v3/files/$sha" -Headers @{ 'x-apikey' = $vt } -ErrorAction Stop
      $stats = $r.data.attributes.last_analysis_stats
      $r | ConvertTo-Json -Depth 8 | Out-File (Join-Path $sbxDir 'virustotal.json') -Encoding utf8
      Rpt "- VirusTotal: malicious=$($stats.malicious) suspicious=$($stats.suspicious) of $($stats.malicious + $stats.undetected + $stats.harmless) engines"
      if ($stats.malicious -gt 0) { Warn "VirusTotal flagged $($stats.malicious) engine(s) -- investigate (unsigned/obfuscated binaries trip heuristics)." } else { Ok "VirusTotal: 0 malicious detections" }
    } catch {
      if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Note "VT: hash unknown -- uploading (<=32MB direct)..."
        try {
          $up = Invoke-RestMethod -Method Post -Uri 'https://www.virustotal.com/api/v3/files' -Headers @{ 'x-apikey' = $vt } -Form @{ file = Get-Item $file }
          Rpt "- VirusTotal: uploaded for analysis, id=$($up.data.id). Re-run to read the report."
        } catch { Warn "VT upload failed (file may exceed 32MB -> needs /files/upload_url): $($_.Exception.Message)" }
      } else { Warn "VirusTotal lookup failed: $($_.Exception.Message)" }
    }
  } else { Warn "VT_API_KEY not set (env or .security-audit.env) -- VirusTotal skipped." }
  # --- Hybrid Analysis hash search ---
  $ha = Get-SecretKey 'HA_API_KEY'
  if ($ha) {
    try {
      $r = Invoke-RestMethod -Method Post -Uri 'https://www.hybrid-analysis.com/api/v2/search/hash' -Headers @{ 'api-key' = $ha; 'User-Agent' = 'Falcon Sandbox' } -Body @{ hash = $sha }
      $r | ConvertTo-Json -Depth 8 | Out-File (Join-Path $sbxDir 'hybrid-analysis.json') -Encoding utf8
      if ($r.Count -gt 0) { Ok "Hybrid Analysis: existing report(s) found (verdict in hybrid-analysis.json)" }
      else { Rpt "- Hybrid Analysis: no existing report (submit via /api/v2/submit/file; free keys may be restricted)." }
    } catch { Warn "Hybrid Analysis failed: $($_.Exception.Message)" }
  } else { Warn "HA_API_KEY not set -- Hybrid Analysis skipped." }
  # --- Joe Sandbox Cloud (quota: 5/day -- RC only) ---
  $joe = Get-SecretKey 'JOE_API_KEY'
  if ($joe) {
    try {
      $r = Invoke-RestMethod -Method Post -Uri 'https://jbxcloud.joesecurity.org/api/v2/submission/new' -Form @{ apikey = $joe; 'accept-tac' = '1'; sample = Get-Item $file }
      $r | ConvertTo-Json -Depth 8 | Out-File (Join-Path $sbxDir 'joesandbox.json') -Encoding utf8
      Ok "Joe Sandbox: submitted (submission_id in joesandbox.json). Quota 5/day -- RC builds only."
    } catch { Warn "Joe Sandbox submit failed (quota or restricted key?): $($_.Exception.Message)" }
  } else { Warn "JOE_API_KEY not set -- Joe Sandbox skipped." }
}

# ⚠️ Public sandbox free tiers PUBLISH the uploaded binary (VirusTotal permanently). For a closed-source
# app that's an IP-exposure decision -- use -LocalAVOnly, or VT private / Joe Pro, if that matters.
if ($RunNumber -eq 1) { Rpt "- Skipped on RUN #1 (no shipping build yet). Run RUN #2 with -BinaryPath on the RC binary." }
elseif (-not $BinaryPath) { Warn "RUN #2 but no -BinaryPath given -- local pre-scan + sandbox skipped." }
else {
  Rpt ""
  Rpt "### 7a. Local AV pre-scan gate (no upload)"
  $localClean = Invoke-LocalPreScan $BinaryPath   # ALWAYS runs on RUN #2 (decoupled from -SkipSandbox)
  Rpt ""
  Rpt "### 7b. Public sandbox submission"
  if ($LocalAVOnly) { Rpt "- Skipped (-LocalAVOnly): local pre-scan only, nothing uploaded." }
  elseif ($SkipSandbox) { Rpt "- Skipped (-SkipSandbox): public submission disabled. (Local pre-scan above still ran.)" }
  elseif ($localClean) { Submit-Sandboxes $BinaryPath }
  else { Blocker "Public sandbox upload BLOCKED -- local pre-scan found a detection. Never upload a flagged binary to a public sandbox." }
}

# ================================================================= 9. Summary
Section "8. Summary"
Rpt "- Blockers: $($script:Blockers.Count)"
Rpt "- Warnings: $($script:Warnings.Count)"
Rpt ""
Rpt "Exit non-zero if any blocker. Use RUN #2 as a GATE before a production release."
Note "Report: $Report  (blockers=$($script:Blockers.Count), warnings=$($script:Warnings.Count))"
Write-Host "`n===== $ProjectName security audit RUN #$RunNumber complete =====" -ForegroundColor Green
Write-Host "Report: $Report"
if ($script:Blockers.Count -gt 0) { exit 1 } else { exit 0 }
