#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'HeliumFixDRM.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
# Import functions only. Never execute the installer on the developer's browser.
foreach ($fn in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    . ([scriptblock]::Create($fn.Extent.Text))
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('HeliumFixTests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$script:passed = 0
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message }; $script:passed++ }
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action } catch { Assert ($_.Exception.Message -match $Pattern) "Unexpected error: $_"; return }
    throw "Expected failure: $Pattern"
}
function New-Pe([string]$Path, [uint16]$Machine) {
    $bytes = New-Object byte[] 128
    $bytes[0] = 0x4D; $bytes[1] = 0x5A; $bytes[0x3C] = 64
    $bytes[64] = 0x50; $bytes[65] = 0x45
    [BitConverter]::GetBytes($Machine).CopyTo($bytes, 68)
    [IO.File]::WriteAllBytes($Path, $bytes)
}
try {
    $oldCdm = [pscustomobject]@{ Version = [version]'4.10.3050.0' }
    $newCdm = [pscustomobject]@{ Version = [version]'4.10.3112.0' }
    Assert (Test-CdmUpdateNeeded $oldCdm $newCdm $false) 'A newer CDM must replace an installed CDM.'
    Assert (-not (Test-CdmUpdateNeeded $newCdm $oldCdm $false)) 'Automatic update must not downgrade.'
    Assert (-not (Test-CdmUpdateNeeded $newCdm $newCdm $false)) 'Same version must not create another backup.'
    Assert (Test-CdmUpdateNeeded $null $newCdm $false) 'Missing CDM must be installed.'
    Assert (Test-CdmUpdateNeeded $newCdm $oldCdm $true) 'Force must allow an explicit rollback.'
    $payload = New-Object byte[] 150000
    (New-Object Random(42)).NextBytes($payload)
    $progressEvents = New-Object 'System.Collections.Generic.List[object]'
    function Write-Progress {
        param($Id, $Activity, $Status, $PercentComplete, [switch]$Completed)
        $progressEvents.Add(@{ Percent = $PercentComplete; Status = $Status })
    }
    $downloadInput = New-Object IO.MemoryStream(,$payload)
    $downloadOutput = New-Object IO.MemoryStream
    try {
        Copy-DownloadStream $downloadInput $downloadOutput $payload.Length ([Threading.CancellationToken]::None)
        Assert ([Convert]::ToBase64String($downloadOutput.ToArray()) -eq [Convert]::ToBase64String($payload)) 'Download changed bytes.'
        Assert ($progressEvents[0].Percent -ge 0 -and $progressEvents[$progressEvents.Count - 1].Percent -eq 100) 'Known size progress missing.'
        $progressEvents.Clear()
        $downloadInput.Position = 0
        $downloadOutput.SetLength(0)
        Copy-DownloadStream $downloadInput $downloadOutput -1 ([Threading.CancellationToken]::None)
        Assert ($progressEvents[0].Percent -eq -1 -and $progressEvents[0].Status -match 'MiB') 'Unknown length must show bytes without a made-up percentage.'
        $downloadInput.Position = 0
        Assert-Throws { Copy-DownloadStream $downloadInput $downloadOutput ($payload.Length + 1) ([Threading.CancellationToken]::None) } 'Incomplete Chrome download'
        $downloadInput.Position = 0
        $cancelled = New-Object Threading.CancellationTokenSource
        try {
            $cancelled.Cancel()
            Assert-Throws { Copy-DownloadStream $downloadInput $downloadOutput $payload.Length $cancelled.Token } 'cancel'
        } finally { $cancelled.Dispose() }
    } finally {
        $downloadInput.Dispose()
        $downloadOutput.Dispose()
        Remove-Item Function:\Write-Progress
    }
    $app = Join-Path $testRoot 'Application'
    foreach ($v in @('9.0.0.0', '10.0.0.0')) {
        $dir = New-Item -ItemType Directory -Path (Join-Path $app $v) -Force
        New-Pe (Join-Path $dir.FullName 'chrome.dll') 0x8664
    }
    $resolved = Resolve-HeliumDirectory $app
    Assert ((Split-Path $resolved -Leaf) -eq '10.0.0.0') 'Versions must sort numerically.'
    Assert ((Resolve-HeliumDirectory $resolved) -eq $resolved) 'Explicit version path failed.'
    Assert-Throws { Resolve-HeliumDirectory (Join-Path $testRoot 'missing') } 'Helium not found'
    $pe = Join-Path $testRoot 'test.dll'
    foreach ($case in @(@(0x8664, 'x64'), @(0x014C, 'x86'), @(0xAA64, 'arm64'))) {
        New-Pe $pe $case[0]
        Assert ((Get-PeArchitecture $pe) -eq $case[1]) 'PE architecture mismatch.'
    }
    [IO.File]::WriteAllText($pe, 'not a dll')
    Assert-Throws { Get-PeArchitecture $pe } 'Not a PE'
    New-Pe $pe 0x8664
    Assert-Throws { Assert-GoogleSignature $pe } 'Expected a valid Google'
    $source = Join-Path $testRoot 'Source'
    $platform = New-Item -ItemType Directory -Path (Join-Path $source '_platform_specific\win_x64') -Force
    New-Pe (Join-Path $platform.FullName 'widevinecdm.dll') 0x8664
    [IO.File]::WriteAllText((Join-Path $source 'manifest.json'), '{"version":"1.2.3.4"}')
    Assert-Throws { Get-CdmInfo $source 'x64' } 'Expected a valid Google'
    # Synthetic test binaries are intentionally unsigned. Only the test double bypasses trust.
    function Assert-GoogleSignature([string]$Path) { }
    Assert ((Get-CdmInfo $source 'x64').Version -eq [version]'1.2.3.4') 'Valid manifest failed.'
    New-Pe (Join-Path $platform.FullName 'widevinecdm.dll') 0x014C
    Assert-Throws { Get-CdmInfo $source 'x64' } 'architecture'
    New-Pe (Join-Path $platform.FullName 'widevinecdm.dll') 0x8664
    Install-Cdm $source $resolved 'x64'
    $target = Join-Path $resolved 'WidevineCdm'
    Assert (Test-Path -LiteralPath (Join-Path $target 'manifest.json')) 'Install missing.'
    [IO.File]::WriteAllText((Join-Path $target 'old-marker'), 'previous installation')
    Install-Cdm $source $resolved 'x64'
    $backups = @(Get-ChildItem -LiteralPath $resolved -Directory -Filter 'WidevineCdm.backup-*')
    Assert ($backups.Count -eq 1) 'Expected one backup.'
    Assert (Test-Path -LiteralPath (Join-Path $backups[0].FullName 'old-marker')) 'Backup lost original data.'
    [IO.File]::WriteAllText((Join-Path $target 'rollback-marker'), 'must survive')
    function Move-Item {
        param($LiteralPath, $Destination)
        if ($LiteralPath -like '*WidevineCdm.stage-*') { throw 'Simulated commit failure' }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination
    }
    Assert-Throws { Install-Cdm $source $resolved 'x64' } 'Simulated commit failure'
    Assert (Test-Path -LiteralPath (Join-Path $target 'rollback-marker')) 'Rollback lost original CDM.'
    Remove-Item Function:\Move-Item
    [IO.File]::WriteAllText((Join-Path $source 'manifest.json'), '{"version":"invalid"}')
    Assert-Throws { Install-Cdm $source $resolved 'x64' } 'Invalid CDM version'
    Assert (Test-Path -LiteralPath (Join-Path $target 'rollback-marker')) 'Invalid source changed target.'
    Assert (@(Get-ChildItem -LiteralPath $resolved -Directory -Filter 'WidevineCdm.stage-*').Count -eq 0) 'Stage leak.'
    # Exercise real entry points with a clean fixture, including scriptblock/iex usage.
    $clean = Join-Path $app '9.0.0.0'
    & $scriptPath -HeliumPath $clean -Diagnose
    & $scriptPath -HeliumPath $clean -WhatIf
    & $scriptPath -EnableAutoUpdate -WhatIf
    & ([scriptblock]::Create([IO.File]::ReadAllText($scriptPath))) -EnableAutoUpdate -WhatIf
    & ([scriptblock]::Create([IO.File]::ReadAllText($scriptPath))) -HeliumPath $clean -WhatIf
    Assert (-not (Test-Path -LiteralPath (Join-Path $clean 'WidevineCdm'))) 'Read-only modes wrote a CDM.'
    Assert-Throws { & $scriptPath -Netflix -Diagnose } 'separate action'
    $originalLocalAppData = $env:LOCALAPPDATA
    $originalProgramFiles = $env:ProgramFiles
    $originalProgramFilesX86 = ${env:ProgramFiles(x86)}
    try {
        $env:LOCALAPPDATA = $testRoot
        $env:ProgramFiles = $testRoot
        ${env:ProgramFiles(x86)} = $testRoot
        $taskProbe = @{}
        function New-ScheduledTaskAction { param($Execute, $Argument) $taskProbe.Arguments = $Argument; return @{ Execute = $Execute } }
        function New-ScheduledTaskTrigger { param([switch]$AtLogOn, $User, [switch]$Daily, $At) return @{ Daily = [bool]$Daily } }
        function New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel) $taskProbe.RunLevel = $RunLevel; return @{} }
        function New-ScheduledTaskSettingsSet { param([switch]$StartWhenAvailable, $MultipleInstances, $ExecutionTimeLimit) return @{} }
        function Register-ScheduledTask { param($TaskName, $Action, $Trigger, $Principal, $Settings, $Description, [switch]$Force) $taskProbe.Name = $TaskName; $taskProbe.Triggers = $Trigger.Count }
        function Get-ScheduledTask { param($TaskName, $ErrorAction) return @{ TaskName = $TaskName } }
        function Unregister-ScheduledTask { param($TaskName, $Confirm) $taskProbe.Removed = $TaskName }
        try {
            & ([scriptblock]::Create([IO.File]::ReadAllText($scriptPath))) -EnableAutoUpdate -HeliumPath $clean
            $savedInstaller = Join-Path $testRoot 'HeliumFixDRM\HeliumFixDRM.ps1'
            $savedText = [IO.File]::ReadAllText($savedInstaller)
            Assert ($savedText.Trim() -eq [IO.File]::ReadAllText($scriptPath).Trim()) 'Auto-update did not preserve the full installer from a scriptblock.'
            Assert ($taskProbe.Arguments -match '-LocalOnly -Unattended' -and $taskProbe.Arguments.Contains($app)) 'Task must use local Chrome and detect new Helium version folders.'
            Assert ($taskProbe.RunLevel -eq 'Limited' -and $taskProbe.Triggers -eq 2) 'Task must run without elevation at logon and daily.'
            & $savedInstaller -DisableAutoUpdate
            Assert ($taskProbe.Removed -eq $taskProbe.Name) 'Disable must remove the same per-user task.'
        } finally {
            foreach ($mock in @('New-ScheduledTaskAction','New-ScheduledTaskTrigger','New-ScheduledTaskPrincipal','New-ScheduledTaskSettingsSet','Register-ScheduledTask','Get-ScheduledTask','Unregister-ScheduledTask')) { Remove-Item "Function:\$mock" }
        }
        Assert-Throws { & $scriptPath -Netflix } 'Install or update'
        $edgeDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'Microsoft\Edge\Application') -Force
        $fakeEdge = Join-Path $edgeDir.FullName 'msedge.exe'
        New-Pe $fakeEdge 0x8664
        $launchProbe = @{ Called = $false; Path = ''; Arguments = '' }
        function Start-Process {
            param($FilePath, $ArgumentList)
            $launchProbe.Called = $true
            $launchProbe.Path = $FilePath
            $launchProbe.Arguments = $ArgumentList
        }
        & $scriptPath -Netflix -WhatIf
        Assert (-not $launchProbe.Called) 'WhatIf launched a browser.'
        & $scriptPath -Netflix
        Assert ($launchProbe.Called -and $launchProbe.Path -eq $fakeEdge) 'Netflix did not dispatch to Edge.'
        Assert ($launchProbe.Arguments -eq '--app=https://www.netflix.com/') 'Wrong Netflix arguments.'
        Remove-Item Function:\Start-Process
        $iexDir = New-Item -ItemType Directory -Path (Join-Path $testRoot 'imput\Helium\Application') -Force
        New-Pe (Join-Path $iexDir.FullName 'chrome.dll') 0x8664
        & {
            $WhatIfPreference = $true
            Get-Content -LiteralPath $scriptPath -Raw | Invoke-Expression
        }
        Assert (-not (Test-Path -LiteralPath (Join-Path $iexDir.FullName 'WidevineCdm'))) 'iex WhatIf wrote a CDM.'
    } finally {
        $env:LOCALAPPDATA = $originalLocalAppData
        $env:ProgramFiles = $originalProgramFiles
        ${env:ProgramFiles(x86)} = $originalProgramFilesX86
    }
    Write-Host "PASS: $script:passed assertions; PowerShell $($PSVersionTable.PSVersion)."
} finally {
    $resolvedTest = (Get-Item -LiteralPath $testRoot).FullName
    $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ((Split-Path $resolvedTest -Parent).TrimEnd('\') -eq $tempParent -and (Split-Path $resolvedTest -Leaf) -like 'HeliumFixTests-*') {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $resolvedTest -Recurse -Force
    }
}
