param(
    [switch]$Force,
    [switch]$KeepTemp
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$HeliumBase = "C:\Program Files\imput\Helium\Application"
$HeliumVersions = Get-ChildItem -Path $HeliumBase -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending
if ($HeliumVersions) {
    $HeliumPath = $HeliumVersions[0].FullName
} else {
    $HeliumPath = $null
}
$HeliumWidevinePath = if ($HeliumPath) { Join-Path $HeliumPath "WidevineCdm" } else { $null }
$TempDir = Join-Path $env:TEMP "HeliumWidevine_$(Get-Random)"
$ExtractPath = Join-Path $TempDir "Extracted"

function Get-7ZipPath {
    $paths = @("7z.exe", "C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe")
    foreach ($p in $paths) {
        if (Get-Command $p -ErrorAction SilentlyContinue) { return (Get-Command $p).Source }
    }
    return $null
}

function Get-LatestChromeInstallerUrl {
    $xmlBody = @"
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0" version="1.3.23.9" shell_version="1.3.21.103" ismachine="1" sessionid="{guid}" installsource="update3web-ondemand" requestid="{guid}">
<os platform="win" version="10.0.26100" arch="x64"/>
<app appid="{8A69D345-D564-463C-AFF1-A69D9E530F96}" ap="x64-stable-statsdef_1" boot="AV2">
<updatecheck/>
</app>
</request>
"@
    $response = Invoke-WebRequest -Uri "https://tools.google.com/service/update2" -Method Post -Body $xmlBody -ContentType "application/xml" -UseBasicParsing
    [xml]$xml = $response.Content

    $urls = $xml.response.app.updatecheck.urls.url
    $manifest = $xml.response.app.updatecheck.manifest
    $fileName = $manifest.actions.action | Where-Object { $_.event -eq "install" } | Select-Object -ExpandProperty run

    $codebase = ($urls | Where-Object { $_.codebase -match '^https://' } | Select-Object -First 1).codebase
    if (-not $codebase) {
        $codebase = $urls[0].codebase
    }

    return @{
        Url = "$codebase$fileName"
        Version = $manifest.version
        FileName = $fileName
    }
}

if (-not $HeliumPath -or -not (Test-Path $HeliumPath)) {
    Write-Host "Error: Helium not found ($HeliumBase)" -ForegroundColor Red
    exit 1
}
if ((Test-Path $HeliumWidevinePath) -and -not $Force) {
    Write-Host "WidevineCdm already exists. Use -Force to overwrite." -ForegroundColor Yellow
    exit 0
}

$7zPath = Get-7ZipPath
if (-not $7zPath) {
    Write-Host "Error: 7-Zip not found. Install from https://www.7-zip.org/" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $TempDir, $ExtractPath -Force | Out-Null
Write-Host "=== Fix Widevine from Chrome offline installer ===" -ForegroundColor Cyan
Write-Host "Helium detected: $HeliumPath" -ForegroundColor Cyan

try {
    Write-Host "Resolving latest Chrome version..." -ForegroundColor Green
    $installerInfo = Get-LatestChromeInstallerUrl
    $ChromeInstallerUrl = $installerInfo.Url
    $ChromeVersion = $installerInfo.Version
    $InstallerPath = Join-Path $TempDir $installerInfo.FileName
    Write-Host "Latest Chrome version: $ChromeVersion" -ForegroundColor Green

    Write-Host "Downloading Chrome offline installer..." -ForegroundColor Green
    Invoke-WebRequest -Uri $ChromeInstallerUrl -OutFile $InstallerPath -UseBasicParsing
    Write-Host "Download complete: $InstallerPath" -ForegroundColor Green

    Write-Host "Extracting installer with 7-Zip..." -ForegroundColor Green
    & $7zPath x $InstallerPath "-o$ExtractPath" -y | Out-Null

    $chrome7z = Get-ChildItem -Path $ExtractPath -Recurse -File -Filter "chrome.7z" | Select-Object -First 1
    $searchPath = $ExtractPath
    if ($chrome7z) {
        $chromeExtractPath = Join-Path $TempDir "ChromeBin"
        Write-Host "Extracting chrome.7z..." -ForegroundColor Green
        & $7zPath x $chrome7z.FullName "-o$chromeExtractPath" -y | Out-Null
        $searchPath = $chromeExtractPath
    }

    $widevineSource = Get-ChildItem -Path $searchPath -Recurse -Directory -Filter "WidevineCdm" | Select-Object -First 1
    if (-not $widevineSource) {
        Write-Host "Error: WidevineCdm not found in extracted files" -ForegroundColor Red
        exit 1
    }

    Write-Host "Copying WidevineCdm to Helium..." -ForegroundColor Green
    if (Test-Path $HeliumWidevinePath) {
        try {
            Remove-Item $HeliumWidevinePath -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Error: Failed to delete existing WidevineCdm. Please close Helium and try again." -ForegroundColor Red
            Write-Host " -> $HeliumWidevinePath" -ForegroundColor Red
            exit 1
        }
    }
    Copy-Item -Path $widevineSource.FullName -Destination $HeliumWidevinePath -Recurse -Force

    Write-Host "`nDone! Restart Helium (or visit helium://restart/) and test playback." -ForegroundColor Green
} finally {
    if (-not $KeepTemp -and (Test-Path $TempDir)) {
        Remove-Item $TempDir -Recurse -Force
        Write-Host "`nTemp files cleaned up." -ForegroundColor Cyan
    } elseif ($KeepTemp) {
        Write-Host "`nTemp files kept: $TempDir" -ForegroundColor Yellow
    }
}
