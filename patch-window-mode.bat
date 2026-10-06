@echo off
setlocal
set "CHYI_PATCH_BAT=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$content=[IO.File]::ReadAllText($env:CHYI_PATCH_BAT); & ([scriptblock]::Create(($content -split '(?m)^:POWERSHELL_PAYLOAD\r?$',2)[1]))"
exit /b %errorlevel%
:POWERSHELL_PAYLOAD
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Administrator permission is required. Accept the Windows UAC prompt.'
    try {
        $batPath = $env:CHYI_PATCH_BAT
        $literalPath = $batPath.Replace("'", "''")
        $loader = "`$env:CHYI_PATCH_BAT='$literalPath'; `$content=[IO.File]::ReadAllText(`$env:CHYI_PATCH_BAT); & ([scriptblock]::Create((`$content -split '(?m)^:POWERSHELL_PAYLOAD\r?$',2)[1]))"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($loader))
        $child = Start-Process -FilePath "$PSHOME\powershell.exe" -Verb RunAs -WindowStyle Normal -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -Wait -PassThru
        exit $child.ExitCode
    } catch {
        Write-Host ('Unable to obtain administrator permission: ' + $_.Exception.Message)
        Read-Host 'Press Enter to close' | Out-Null
        exit 1
    }
}
$ErrorActionPreference = 'Stop'
$patchExitCode = 0
try {
    $running = @(Get-CimInstance Win32_Process -Filter "Name = 'REDAgent.exe'")
    if ($running.Count -eq 0) { throw 'No running REDAgent.exe found. Start REDAgent.exe first.' }
    if (@($running | Where-Object { -not $_.ExecutablePath }).Count -gt 0) {
        throw 'Cannot read the running program path. Run this BAT as administrator.'
    }
    $paths = @($running | ForEach-Object { $_.ExecutablePath } | Sort-Object -Unique)
    if ($paths.Count -ne 1) {
        Write-Host 'Multiple REDAgent.exe locations found:'
        $paths | ForEach-Object { Write-Host $_ }
        throw 'Keep only the intended REDAgent.exe running, then retry.'
    }
    $target = [System.IO.Path]::GetFullPath($paths[0])
    Write-Host ('Detected program: ' + $target)
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Detected executable no longer exists.' }
    $originalHash = '857143d5ceef5b1efba299ec07103bce570144a4d134ed5ffcb968b1a02054d5'
    $patchedHash = '8c5684604a126684fa7a6d2022a8f0023c08933973c684d2baa7b26862bf5aa2'
    $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -eq $patchedHash) {
        Write-Host 'Already patched. No changes needed.'
        return
    }
    if ($hash -ne $originalHash) { throw 'Unsupported REDAgent.exe version. No changes made.' }
    $bytes = [System.IO.File]::ReadAllBytes($target)
    if ($bytes[0x635e] -ne 0x74 -or $bytes[0x635f] -ne 0x12) {
        throw 'Expected instruction not found. No changes made.'
    }
    Write-Host 'Stopping the detected REDAgent.exe...'
    $matching = @(Get-CimInstance Win32_Process -Filter "Name = 'REDAgent.exe'" | Where-Object {
        if (-not $_.ExecutablePath) {
            throw 'Cannot verify a running REDAgent.exe path. Run this BAT as administrator.'
        }
        [string]::Equals($_.ExecutablePath, $target, [System.StringComparison]::OrdinalIgnoreCase)
    })
    foreach ($proc in $matching) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
        Wait-Process -Id $proc.ProcessId -Timeout 15 -ErrorAction SilentlyContinue
    }
    if (@(Get-CimInstance Win32_Process -Filter "Name = 'REDAgent.exe'" | Where-Object {
        [string]::Equals($_.ExecutablePath, $target, [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0) { throw 'REDAgent.exe restarted automatically. Stop its service before retrying.' }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $originalHash) {
        throw 'File changed while stopping the program. No patch applied.'
    }
    $backup = "$target.bak"
    if (Test-Path -LiteralPath $backup) {
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $originalHash) {
            throw 'Existing backup differs from the original. Preserve or rename it before retrying.'
        }
    } else { Copy-Item -LiteralPath $target -Destination $backup -ErrorAction Stop }
    $bytes[0x635e] = 0xeb
    try {
        [System.IO.File]::WriteAllBytes($target, $bytes)
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $patchedHash) {
            throw 'Patched file verification failed.'
        }
    } catch {
        Copy-Item -LiteralPath $backup -Destination $target -Force
        throw
    }
    Write-Host 'Patch complete. Original saved as REDAgent.exe.bak.'
    Write-Host 'REDAgent.exe is stopped. Start it normally when ready.'
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    $patchExitCode = 1
} finally {
    if ($env:CHYI_PATCH_NO_PAUSE -ne '1') {
        try { Read-Host 'Press Enter to close' | Out-Null } catch { }
    }
}
exit $patchExitCode
