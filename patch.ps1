#requires -Version 5.1
<#
Local, narrowly scoped, reversible binary patch for a specific MainViewPlugin.dll.
Requires a matching SHA-256. Does NOT distribute the manufacturer's DLL.
Usage: .\patch.ps1 -DllPath 'C:\path\to\MainViewPlugin.dll'
       .\patch.ps1 -DllPath 'C:\path\to\MainViewPlugin.dll' -Restore
#>
param(
    [Parameter(Mandatory = $true)][string]$DllPath,
    [switch]$Restore
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ExpectedOriginalHash = '5610F35B164599FD9ADB425E80B38CF4BE98BD1CEE21A3EFAA0A1706272AF66A'
$ExpectedPatchedHash  = '9848B2043EEBBB74F58C045C7A0D264A48FD897BFE37A243D2A9AD0C235B9207'
$Changes = @(
    @{ Offset = 0x41B16C; Before = 0xC2; After = 0xD7 },
    @{ Offset = 0x6639B8; Before = 0x25; After = 0x00 }
)

$resolved = [System.IO.Path]::GetFullPath($DllPath)
$backup = "$resolved.bak"
if (-not [System.IO.File]::Exists($resolved)) {
    throw "DLL file not found: $resolved"
}
function Get-Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

if ($Restore) {
    if (-not [System.IO.File]::Exists($backup)) { throw "Backup not found: $backup" }
    if ((Get-Hash $backup) -ne $ExpectedOriginalHash) {
        throw 'Backup hash does not match tested original; refusing to restore.'
    }
    $currentHash = Get-Hash $resolved
    if ($currentHash -notin @($ExpectedOriginalHash, $ExpectedPatchedHash)) {
        throw 'Current file is an unknown version; refusing to overwrite it.'
    }
    $temp = "$resolved.restore.tmp"
    try {
        [System.IO.File]::Copy($backup, $temp, $true)
        [System.IO.File]::Replace($temp, $resolved, $null)
    } finally {
        if ([System.IO.File]::Exists($temp)) { [System.IO.File]::Delete($temp) }
    }
    Write-Host 'Restored original DLL.'
    return
}

$currentHash = Get-Hash $resolved
if ($currentHash -eq $ExpectedPatchedHash) {
    Write-Host 'The two-byte patch is already present. No changes made.'
    return
}
if ($currentHash -ne $ExpectedOriginalHash) {
    throw "Unsupported DLL SHA-256: $currentHash. Expected $ExpectedOriginalHash"
}
if ([System.IO.File]::Exists($backup)) {
    if ((Get-Hash $backup) -ne $ExpectedOriginalHash) {
        throw 'Existing .bak is not the expected original; refusing to overwrite it.'
    }
} else {
    [System.IO.File]::Copy($resolved, $backup)
}

$bytes = [System.IO.File]::ReadAllBytes($resolved)
foreach ($entry in $Changes) {
    if ($bytes[$entry.Offset] -ne $entry.Before) {
        throw ("Unexpected byte at file offset 0x{0:X}" -f $entry.Offset)
    }
    $bytes[$entry.Offset] = [byte]$entry.After
}
$temp = "$resolved.patch.tmp"
try {
    [System.IO.File]::WriteAllBytes($temp, $bytes)
    if ((Get-Hash $temp) -ne $ExpectedPatchedHash) {
        throw 'Patched temporary file failed SHA-256 verification.'
    }
    [System.IO.File]::Replace($temp, $resolved, $null)
} finally {
    if ([System.IO.File]::Exists($temp)) { [System.IO.File]::Delete($temp) }
}
Write-Host 'Patched DLL successfully. Original saved to:' $backup
Write-Host 'Patched file SHA-256:' (Get-Hash $resolved)
