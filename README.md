# Helium Fix DRM

PowerShell script that restores Widevine DRM playback in [Helium](https://github.com/imputnet/helium) on Windows.

It downloads the latest Chrome offline installer, extracts `WidevineCdm`, and copies it into Helium's application folder.

## Requirements

- Windows
- [Helium](https://github.com/imputnet/helium) installed under `C:\Program Files\imput\Helium`
- [7-Zip](https://www.7-zip.org/)
- Internet access (to fetch the Chrome installer)
- Permission to write under `C:\Program Files` (run PowerShell as Administrator)

## Usage

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\HeliumFixDRM.ps1
```

Overwrite an existing Widevine install:

```powershell
.\HeliumFixDRM.ps1 -Force
```

Keep extracted temp files for debugging:

```powershell
.\HeliumFixDRM.ps1 -KeepTemp
```

Then restart Helium (`helium://restart/`) and test a DRM stream.

Close Helium first if `-Force` needs to replace `WidevineCdm`
