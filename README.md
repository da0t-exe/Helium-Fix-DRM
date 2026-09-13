# Helium Fix DRM

**Install and maintain Widevine in Helium on Windows with PowerShell.**

A simple console interface, download progress, Google signature verification, and backups before replacement.

> This script does not fix the Netflix license rejection observed in Helium or guarantee Netflix compatibility.

## Install or update

Close Helium, open PowerShell, and paste:

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 | iex
```

The script detects Helium and looks for Widevine in Chrome. It installs only when the existing module is missing, invalid, or older. It does not downgrade a valid version without `-Force`.

If Chrome provides no valid module, the script downloads the official Google installer and extracts Widevine with **7-Zip**, without running the installer. Progress shows the percentage, MiB received, and transfer speed. If the server provides no total size, only the received size and speed are shown.

**Requirements:** Windows, PowerShell 5.1 or 7, Helium, and either Chrome installed or 7-Zip with Internet access for automatic x64 extraction. For ARM64/x86, provide a local source with matching architecture. Helium installations in Program Files may require administrator permissions.

## Enable automatic updates

Keep Chrome installed and up to date, then run once:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1))) -EnableAutoUpdate
```

A Windows task checks Chrome's Widevine **at sign-in and daily at noon**, while you are signed in. It copies newer versions into Helium and detects new Helium version folders. If Helium is running, the update is deferred until the next run; the task never closes the browser.

- Chrome downloads its official updates; the task synchronizes files available locally. It does not independently check the latest Widevine release worldwide.
- Without a valid Chrome module, no automatic installation occurs. Run the manual command to use the Google download instead.
- The task runs with your account permissions, without elevation. It is intended for Helium installed in your user profile.
- The script is saved in `%LOCALAPPDATA%\HeliumFixDRM`. The task does not download new script code on each run. Run the enable command again to update this local copy.
- The latest run is logged to `%LOCALAPPDATA%\HeliumFixDRM\update.log`. Task Scheduler shows its status under `HeliumWidevine-<user SID>`.

To disable the task without removing Widevine:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1))) -DisableAutoUpdate
```

## Useful options

Download the script to use its options locally:

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 -OutFile HeliumFixDRM.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\HeliumFixDRM.ps1 -Diagnose
```

`-ExecutionPolicy Bypass` applies only to that process. Remote commands execute the code published on `main`; replace `main` with a commit ID to pin a version.

| Option | Effect |
| --- | --- |
| `-Diagnose` | Verify installed files without changing them. |
| `-SourcePath 'D:\WidevineCdm'` | Install a specific source if newer, without downloading. |
| `-Force` | Reinstall, including an older version for rollback. |
| `-HeliumPath 'D:\Helium\Application'` | Select a custom installation; also supported when enabling automatic updates. |
| `-LocalOnly` | Search local Chrome installations without downloading. |
| `-WhatIf` | Preview the action without installing files or creating a task. |
| `-Verbose` | Show the source path and SHA256 hash. |
| `-KeepTemp` | Keep the installer and extracted files for troubleshooting. |
| `-Netflix` | Open Netflix in a separate Edge or Chrome window. |

Enabling and disabling automatic updates are separate actions. `-Unattended` is intended for the task: it logs the latest run and defers installation if Helium is running.

## Verification and backups

The script checks the CDM's PE architecture, manifest, and Google Authenticode signature. It also verifies the downloaded installer's signature. New files are staged and validated before replacement. The previous version remains in `WidevineCdm.backup-...` and is restored if the final move fails.

Backups are not deleted automatically. To roll back, close Helium and use `-SourcePath` with the backup folder and `-Force`.

After installation, restart Helium and test an encrypted video, such as the [Bitmovin DRM demo](https://bitmovin.com/demos/drm). A CDM entry in `chrome://media-internals` does not prove a service will accept its license request.

## Netflix

During September 2026 testing, Chrome played Netflix with Widevine 4.10.3112.0, while Helium continued to receive license rejections with the same version. This repository provides a CDM installer, not a demonstrated fix for that rejection. It does not modify the service's protection checks.

The `-Netflix` option opens Edge, or Chrome if Edge is unavailable, without changing your default browser.

References: [Helium DRM request](https://github.com/imputnet/helium/issues/116), [Netflix supported browsers](https://help.netflix.com/en/node/30081).

## Development

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-HeliumFixDRM.ps1
pwsh -NoProfile -File .\tests\Test-HeliumFixDRM.ps1
```

Tests cover version selection, prevention of automatic downgrades, backups, rollback, downloads, dry runs, and execution through `iex`. They use synthetic files and do not verify Netflix playback.

## License

[MIT](LICENSE). No Widevine binaries are redistributed in this repository.
