#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$HeliumPath,
    [string]$SourcePath,
    [switch]$Force,
    [switch]$KeepTemp,
    [switch]$Diagnose,
    [switch]$Netflix,
    [switch]$EnableAutoUpdate,
    [switch]$DisableAutoUpdate,
    [switch]$LocalOnly,
    [switch]$Unattended
)

$installerContent = $MyInvocation.MyCommand.ScriptBlock.ToString()

function Test-CdmUpdateNeeded($Installed, $Source, [bool]$ForceRefresh) {
    return ($ForceRefresh -or -not $Installed -or $Source.Version -gt $Installed.Version)
}

function Set-CdmAutoUpdate([string]$Content, [string]$CustomHeliumPath, [bool]$Disable) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $taskName = 'HeliumWidevine-' + $identity.User.Value
    if ($Disable) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
        Write-Host 'Automatic updates disabled.' -ForegroundColor Green
        return
    }
    $updateRoot = Join-Path $env:LOCALAPPDATA 'HeliumFixDRM'
    New-Item -ItemType Directory -Path $updateRoot -Force | Out-Null
    $savedScript = Join-Path $updateRoot 'HeliumFixDRM.ps1'
    # Keep the reviewed installer locally; the task never executes a remote script.
    [IO.File]::WriteAllText($savedScript, $Content, (New-Object Text.UTF8Encoding($true)))
    $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $savedScript + '" -LocalOnly -Unattended'
    if ($CustomHeliumPath) {
        # Save the Application root so new Helium version folders are detected.
        $root = Resolve-HeliumDirectory $CustomHeliumPath
        if ((Split-Path $root -Leaf) -match '^\d+\.\d+\.\d+\.\d+$') { $root = Split-Path $root -Parent }
        $arguments += ' -HeliumPath "' + $root.TrimEnd('\') + '"'
    }
    $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments
    $triggers = @((New-ScheduledTaskTrigger -AtLogOn -User $identity.Name), (New-ScheduledTaskTrigger -Daily -At '12:00'))
    $principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Description 'Synchronizes Widevine from Chrome while Helium is closed.' -Force | Out-Null
    Write-Host 'Automatic updates enabled: from Chrome at sign-in and daily at noon.' -ForegroundColor Green
    Write-Host "Log: $updateRoot\update.log"
}

function Get-PeArchitecture([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw "Not a PE file: $Path" }
        $stream.Position = 0x3C
        $offset = $reader.ReadInt32()
        if ($offset -lt 64 -or $offset -gt ($stream.Length - 6)) { throw "Invalid PE header: $Path" }
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x4550) { throw "Invalid PE signature: $Path" }
        switch ($reader.ReadUInt16()) {
            0x8664 { return 'x64' }
            0x014C { return 'x86' }
            0xAA64 { return 'arm64' }
            default { throw "Unsupported PE architecture: $Path" }
        }
    } finally { $reader.Dispose() }
}

function Resolve-HeliumDirectory([string]$Path) {
    $roots = if ($Path) { @($Path) } else {
        @("$env:LOCALAPPDATA\imput\Helium\Application", "$env:ProgramFiles\imput\Helium\Application",
          "${env:ProgramFiles(x86)}\imput\Helium\Application")
    }
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        if (Test-Path -LiteralPath (Join-Path $root 'chrome.dll')) { return (Get-Item -LiteralPath $root).FullName }
        $versions = @(Get-ChildItem -LiteralPath $root -Directory |
            Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'chrome.dll')) } |
            Sort-Object { [version]$_.Name } -Descending)
        if ($versions.Count) { return $versions[0].FullName }
    }
    throw 'Helium not found. Use -HeliumPath with its Application folder or version folder.'
}

function Assert-GoogleSignature([string]$Path) {
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(?:^|,\s*)O=Google (LLC|Inc\.?)(?:,|$)') {
        throw "Expected a valid Google Authenticode signature: $Path (status: $($signature.Status))"
    }
}

function Get-CdmInfo([string]$Path, [string]$Architecture) {
    $manifest = Get-Content -LiteralPath (Join-Path $Path 'manifest.json') -Raw | ConvertFrom-Json
    $dll = Join-Path $Path "_platform_specific\win_$Architecture\widevinecdm.dll"
    if ($manifest.version -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'Invalid CDM version.' }
    if ((Get-PeArchitecture $dll) -ne $Architecture) { throw 'CDM architecture does not match Helium.' }
    Assert-GoogleSignature $dll
    [pscustomobject]@{ Path = $Path; Version = [version]$manifest.version; Dll = $dll; SHA256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash }
}

function Get-LocalChromeCdm([string]$Architecture) {
    $roots = @("$env:LOCALAPPDATA\Google\Chrome\Application", "$env:ProgramFiles\Google\Chrome\Application",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application", "$env:LOCALAPPDATA\Google\Chrome\User Data\WidevineCdm")
    $candidates = foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($version in (Get-ChildItem -LiteralPath $root -Directory)) {
            $candidate = Join-Path $version.FullName 'WidevineCdm'
            if (Test-Path -LiteralPath (Join-Path $version.FullName 'manifest.json')) { $candidate = $version.FullName }
            if (Test-Path -LiteralPath (Join-Path $candidate 'manifest.json')) {
                try { Get-CdmInfo $candidate $Architecture } catch { Write-Verbose $_.Exception.Message }
            }
        }
    }
    $candidates | Sort-Object Version -Descending | Select-Object -First 1
}

function Copy-DownloadStream($InputStream, $OutputStream, [long]$Length, $CancellationToken) {
    $buffer = New-Object byte[] 65536
    [long]$received = 0
    $timer = [Diagnostics.Stopwatch]::StartNew()
    [long]$lastUpdate = -250
    while (($count = $InputStream.ReadAsync($buffer, 0, $buffer.Length, $CancellationToken).GetAwaiter().GetResult()) -gt 0) {
        $OutputStream.Write($buffer, 0, $count)
        $received += $count
        if ($timer.ElapsedMilliseconds - $lastUpdate -ge 200) {
            $speed = $received / 1MB / [Math]::Max($timer.Elapsed.TotalSeconds, 0.001)
            $percent = -1
            $status = '{0:N1} MiB recus | {1:N1} MiB/s' -f ($received / 1MB), $speed
            if ($Length -gt 0) {
                $percent = [int][Math]::Min(99, [Math]::Floor(100.0 * $received / $Length))
                $status = '{0}% | {1:N1} / {2:N1} MiB | {3:N1} MiB/s' -f $percent, ($received / 1MB), ($Length / 1MB), $speed
            }
            Write-Progress -Id 1 -Activity 'Downloading Chrome' -Status $status -PercentComplete $percent
            $lastUpdate = $timer.ElapsedMilliseconds
        }
    }
    if ($Length -ge 0 -and $received -ne $Length) { throw "Incomplete Chrome download: expected $Length bytes, received $received." }
    Write-Progress -Id 1 -Activity 'Downloading Chrome' -Status 'Download complete' -PercentComplete 100
}

function Get-FileWithProgress([uri]$Uri, [string]$Destination) {
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $cancellation = New-Object System.Threading.CancellationTokenSource
    $response = $null
    $inputStream = $null
    $outputStream = $null
    # This deadline includes the streamed body, not just the response headers.
    $cancellation.CancelAfter(300000)
    try {
        Write-Progress -Id 1 -Activity 'Downloading Chrome' -Status 'Connecting to Google...' -PercentComplete -1
        $response = $client.GetAsync($Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancellation.Token).GetAwaiter().GetResult()
        [void]$response.EnsureSuccessStatusCode()
        $length = if ($null -ne $response.Content.Headers.ContentLength) { [long]$response.Content.Headers.ContentLength } else { -1L }
        $inputStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $outputStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
        Copy-DownloadStream $inputStream $outputStream $length $cancellation.Token
    } finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
        $client.Dispose()
        $cancellation.Dispose()
        Write-Progress -Id 1 -Activity 'Downloading Chrome' -Completed
    }
}

function Get-ChromeCdm([string]$TempDirectory, [string]$Architecture) {
    if ($Architecture -ne 'x64') { throw 'Automatic Chrome download supports x64 only. Supply -SourcePath with a matching WidevineCdm folder.' }
    $sevenZip = @('7z.exe', "$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") |
        ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
    if (-not $sevenZip) { throw 'Install Chrome (then run it once) or 7-Zip, or supply -SourcePath. See https://www.7-zip.org/' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $body = '<request protocol="3.0" version="1.3.23.9" ismachine="1"><os platform="win" version="10.0" arch="x64"/><app appid="{8A69D345-D564-463C-AFF1-A69D9E530F96}" ap="x64-stable"><updatecheck/></app></request>'
    [xml]$response = (Invoke-WebRequest 'https://tools.google.com/service/update2' -Method Post -Body $body -ContentType 'application/xml' -UseBasicParsing -TimeoutSec 60).Content
    $update = $response.response.app.updatecheck
    $fileName = [string]($update.manifest.actions.action | Where-Object { $_.event -eq 'install' } | Select-Object -First 1).run
    if (-not $fileName -or $fileName -notmatch '^[a-zA-Z0-9._-]+\.exe$') { throw 'Google returned an invalid installer filename.' }
    $base = @($update.urls.url | Where-Object { $_.codebase -match '^https://' }) | Select-Object -First 1
    $uri = [uri]([string]$base.codebase + $fileName)
    if ($uri.Scheme -ne 'https' -or $uri.DnsSafeHost -notmatch '(^|\.)(google\.com|gvt1\.com|googleapis\.com)$') { throw 'Unexpected Chrome download host.' }
    $installer = Join-Path $TempDirectory $fileName
    Get-FileWithProgress $uri $installer
    Write-Host 'Verifying the Google signature...'
    Assert-GoogleSignature $installer
    Write-Host 'Extracting Widevine...'
    $extracted = Join-Path $TempDirectory 'Extracted'
    & $sevenZip.Source x $installer "-o$extracted" -y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7-Zip failed: $LASTEXITCODE" }
    $archive = Get-ChildItem -LiteralPath $extracted -Recurse -File -Filter chrome.7z | Select-Object -First 1
    if ($archive) {
        $extracted = Join-Path $TempDirectory 'ChromeBin'
        & $sevenZip.Source x $archive.FullName "-o$extracted" -y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "7-Zip failed: $LASTEXITCODE" }
    }
    $source = Get-ChildItem -LiteralPath $extracted -Recurse -Directory -Filter WidevineCdm | Select-Object -First 1
    if (-not $source) { throw 'WidevineCdm is missing from the Chrome installer.' }
    Get-CdmInfo $source.FullName $Architecture
}

function Install-Cdm([string]$Source, [string]$Directory, [string]$Architecture) {
    # Stage and verify before moving the existing installation. Keep the backup.
    $directoryFull = (Get-Item -LiteralPath $Directory).FullName
    $target = Join-Path $directoryFull 'WidevineCdm'
    if ((Get-Item -LiteralPath $directoryFull).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse-point installation directories are not supported.' }
    if ((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'WidevineCdm must not be a reparse point.' }
    $id = [guid]::NewGuid().ToString('N')
    $stage = Join-Path $directoryFull "WidevineCdm.stage-$id"
    $backup = Join-Path $directoryFull "WidevineCdm.backup-$id"
    $moved = $false
    try {
        Copy-Item -LiteralPath $Source -Destination $stage -Recurse
        $verified = Get-CdmInfo $stage $Architecture
        if (Test-Path -LiteralPath $target) {
            Move-Item -LiteralPath $target -Destination $backup
            $moved = $true
        }
        Move-Item -LiteralPath $stage -Destination $target
        if ($moved) { Write-Host "Previous CDM saved at: $backup" }
        Write-Host "Installed Widevine $($verified.Version). Restart Helium and test playback. Netflix compatibility is not verified."
    } catch {
        if ($moved -and -not (Test-Path -LiteralPath $target)) { Move-Item -LiteralPath $backup -Destination $target }
        throw
    } finally {
        if (Test-Path -LiteralPath $stage) {
            $item = Get-Item -LiteralPath $stage
            if ($item.Parent.FullName -eq $directoryFull -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force
            }
        }
    }
}

function Get-NetflixBrowser {
    $paths = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe", "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
    foreach ($path in $paths) { if (Test-Path -LiteralPath $path -PathType Leaf) { return $path } }
    throw 'Install or update Microsoft Edge or Google Chrome for the Netflix option.'
}

# Child scope: irm | iex must not change the caller's error preference or close its shell.
& {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $ErrorActionPreference = 'Stop'
    if ($env:OS -ne 'Windows_NT') { throw 'This script supports Windows only.' }
    if ($EnableAutoUpdate -or $DisableAutoUpdate) {
        if (($EnableAutoUpdate -and $DisableAutoUpdate) -or $Netflix -or $Diagnose -or $SourcePath -or $Force -or $LocalOnly -or $Unattended) { throw 'Auto-update setup is a separate action; do not combine it with installation options.' }
        if ($PSCmdlet.ShouldProcess('Helium Widevine scheduled task', 'Configure automatic updates')) {
            Set-CdmAutoUpdate $installerContent $HeliumPath ([bool]$DisableAutoUpdate)
        }
        return
    }
    $transcribing = $false
    if ($Unattended -and -not $WhatIfPreference) {
        $logRoot = Join-Path $env:LOCALAPPDATA 'HeliumFixDRM'
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
        Start-Transcript -Path (Join-Path $logRoot 'update.log') -Force | Out-Null
        $transcribing = $true
    }
    try {
    Write-Host ''
    Write-Host '  HELIUM | Widevine' -ForegroundColor Cyan
    Write-Host '  Install and update' -ForegroundColor DarkGray
    Write-Host ''
    if ($Netflix) {
        if ($Diagnose -or $SourcePath -or $Force -or $KeepTemp -or $HeliumPath -or $LocalOnly -or $Unattended) { throw '-Netflix is a separate action; do not combine it with installation options.' }
        $browser = Get-NetflixBrowser
        if ($PSCmdlet.ShouldProcess($browser, 'Open Netflix in a separate supported browser window')) {
            Write-Host "Netflix will use $browser. This is not native playback in Helium."
            Start-Process -FilePath $browser -ArgumentList '--app=https://www.netflix.com/'
        }
        return
    }
    $directory = Resolve-HeliumDirectory $HeliumPath
    $architecture = Get-PeArchitecture (Join-Path $directory 'chrome.dll')
    $target = Join-Path $directory 'WidevineCdm'
    Write-Host "Helium: $directory ($architecture)"
    $installed = $null
    if (Test-Path -LiteralPath $target) {
        try { $installed = Get-CdmInfo $target $architecture; Write-Host "CDM files verified: $($installed.Version)" }
        catch { Write-Warning "Existing CDM is invalid: $($_.Exception.Message)" }
    } else { Write-Host 'CDM not found in the application version folder.' }
    if ($Diagnose) {
        Write-Host 'File verification does not prove the CDM is loaded or that Netflix accepts it.'
        Write-Host 'In Helium: chrome://settings/content/protectedContent, chrome://components, chrome://media-internals'
        Write-Host 'Test encrypted playback: https://bitmovin.com/demos/drm'
        Write-Host 'Record the exact Netflix error and compare with up-to-date Edge/Chrome using the same account.'
        Write-Host 'Netflix fallback: run this script with -Netflix (separate Edge/Chrome window).'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($target, 'Install verified Widevine files (backup existing CDM)')) { return }
    $appRoot = if ((Split-Path $directory -Leaf) -match '^\d+\.\d+\.\d+\.\d+$') { Split-Path $directory -Parent } else { $directory }
    $running = @(Get-Process -Name chrome,helium -ErrorAction SilentlyContinue | Where-Object {
        $processPath = $_.Path
        $processPath -and $processPath.StartsWith($appRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
    })
    if ($running.Count) {
        if ($Unattended) { Write-Host 'Helium is running: update deferred until the next run.'; return }
        throw 'Close Helium completely, including background processes, then run again.'
    }
    $tempDirectory = $null
    try {
        if ($SourcePath) { $source = Get-CdmInfo (Resolve-Path -LiteralPath $SourcePath).Path $architecture }
        else { $source = Get-LocalChromeCdm $architecture }
        if (-not $source) {
            if ($LocalOnly) { Write-Host 'No valid Widevine found in Chrome. Open or update Chrome, then run again.'; return }
            $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
            $tempDirectory = Join-Path $tempRoot ('HeliumWidevine-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tempDirectory | Out-Null
            $source = Get-ChromeCdm $tempDirectory $architecture
        }
        Write-Host "Available version: $($source.Version)" -ForegroundColor Cyan
        Write-Verbose "Source: $($source.Path) | SHA256 $($source.SHA256)"
        if (-not (Test-CdmUpdateNeeded $installed $source ([bool]$Force))) {
            Write-Host "Widevine is already up to date ($($installed.Version)) for this source." -ForegroundColor Green
            return
        }
        Write-Host 'Installing with a backup...'
        Install-Cdm $source.Path $directory $architecture
    } finally {
        if ($tempDirectory -and (Test-Path -LiteralPath $tempDirectory)) {
            if ($KeepTemp) { Write-Host "Temporary files: $tempDirectory" }
            else {
                $item = Get-Item -LiteralPath $tempDirectory
                if ($item.Parent.FullName.TrimEnd('\') -eq $tempRoot -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force
                }
            }
        }
    }
    } finally {
        if ($transcribing) { Stop-Transcript | Out-Null }
    }
}
