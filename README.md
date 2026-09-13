<p align="center">
  <a href="https://helium.computer">
    <img src="https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/eed72d09c6b65fa48f093ccc50e2258a75018028/assets/helium.png" width="96" height="96" alt="Helium browser logo">
  </a>
</p>

<h1 align="center">Helium Fix DRM</h1>

<p align="center">
  <strong>Widevine setup for Helium. One PowerShell command.</strong><br>
  Install, verify, and keep your local module up to date on Windows.
</p>

<p align="center">
  <a href="https://github.com/da0t-exe/Helium-Fix-DRM/actions/workflows/test.yml"><img src="https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/eed72d09c6b65fa48f093ccc50e2258a75018028/assets/tests.png" width="176" height="35" alt="Tests / CI - view live results"></a>
  <img src="https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/eed72d09c6b65fa48f093ccc50e2258a75018028/assets/platform.png" width="176" height="35" alt="Platform: Windows">
  <img src="https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/eed72d09c6b65fa48f093ccc50e2258a75018028/assets/powershell.png" width="176" height="35" alt="PowerShell 5.1 and 7">
  <a href="LICENSE"><img src="https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/eed72d09c6b65fa48f093ccc50e2258a75018028/assets/license.png" width="176" height="35" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> &nbsp; / &nbsp;
  <a href="#automatic-updates">Automatic updates</a> &nbsp; / &nbsp;
  <a href="#reference">Reference</a> &nbsp; / &nbsp;
  <a href="#troubleshooting">Troubleshooting</a>
</p>

---

> [!IMPORTANT]
> **An independent community utility for Helium.** Installing Widevine does not guarantee that a streaming service will accept the browser. The Netflix failure investigated in this project remains unresolved.

## Quick start

**1. Close Helium completely.**

**2. Open PowerShell and paste:**

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 | iex
```

**3. Restart Helium and test encrypted playback.**

The script compares versions and skips unnecessary replacements. Your previous module is backed up when an installation takes place.

<details>
<summary><strong>Requirements and download behavior</strong></summary>

- Windows with PowerShell **5.1 or 7**.
- Helium installed in your user profile, system-wide, or a custom location.
- **Chrome installed**, or **7-Zip and Internet access** for automatic extraction from Google's x64 installer.
- For ARM64/x86, provide a matching local CDM with `-SourcePath`.
- Helium under Program Files may require administrator permissions.

The Google installer is extracted, never executed. If the download has no advertised total size, progress shows received bytes and speed without inventing a percentage.

The command executes the script on `main`. You can [download and inspect it first](#reference), or replace `main` with a commit ID to pin a version.

</details>

## Automatic updates

Keep Chrome installed and up to date. Run this command once to enable local synchronization:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1))) -EnableAutoUpdate
```

The Windows task runs **at sign-in and daily at noon**, while you are signed in. If Helium is open, it waits until a later scheduled run. It also detects new Helium version folders.

**Chrome supplies the updates.** This task copies newer modules available locally; it does not independently download the latest Widevine release. It runs without elevation and is intended for Helium installed in your user profile.

<details>
<summary><strong>Disable updates, find logs, or refresh the task</strong></summary>

Disable the task without removing Widevine:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1))) -DisableAutoUpdate
```

Latest run log: `%LOCALAPPDATA%\HeliumFixDRM\update.log`.

The task uses a locally saved installer. Run the enable command again after a script update to refresh that copy. Include your custom `-HeliumPath` again when refreshing the task.

</details>

## Compatibility

| Component | Status |
| --- | --- |
| PowerShell 5.1 and 7 | Covered by automated tests. |
| Google CDM files | Architecture, manifest, and Authenticode signature checked before installation. |
| Encrypted playback in Helium | Depends on the browser and service; test with the [Bitmovin DRM demo](https://bitmovin.com/demos/drm). |
| Netflix inside Helium | **Not fixed by this project.** Matching Chrome's Widevine version did not resolve the observed license rejection. |
| Netflix in another browser | `-Netflix` opens a separate Edge or Chrome window. |

## Reference

<details>
<summary>Options, verification, and rollback</summary>


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


</details>

## Troubleshooting

<details>
<summary>Installation and automatic updates</summary>


```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1))) -Diagnose
```

This checks the installed files without downloading or installing anything. It does not prove that a service will issue a playback license.

## Installation

| Message or symptom | Next step |
| --- | --- |
| Helium not found | Supply `-HeliumPath` with its Application folder or a portable folder containing `chrome.dll`. |
| Close Helium completely | Exit all Helium windows and its background processes, then run again. The script never closes them for you. |
| No valid local Chrome module | Open or update Chrome. Run without `-LocalOnly` to allow the Google installer fallback. |
| 7-Zip required | Install Chrome with a usable module, install 7-Zip for extraction, or provide `-SourcePath`. |
| Signature or architecture validation failed | Use a fresh official Chrome installation with a matching architecture. Do not bypass validation. |
| Access denied under Program Files | Use an administrator terminal for the manual installation. The automatic task runs without elevation. |
| Already up to date | The selected source is not newer. Update Chrome first, or use `-Force` only for an intentional refresh or rollback. |
| Progress shows no percentage | The server did not announce the total size. Received size and speed are still shown. |

## Automatic updates

Read `%LOCALAPPDATA%\HeliumFixDRM\update.log` for the latest run. In Windows Task Scheduler, find `HeliumWidevine-<user SID>` and check its status.

The task runs while you are signed in, at sign-in and daily at noon. An open Helium browser causes the update to be deferred until another run. Chrome must provide a valid local module; this task does not download a replacement from Google.

After updating the installer, run `-EnableAutoUpdate` again to refresh the task's local script. For a custom installation, include `-HeliumPath` again.


</details>

[Report an issue](https://github.com/da0t-exe/Helium-Fix-DRM/issues/new) with versions, the command, and sanitized error output. Do not upload raw HAR files, cookies, tokens, or license payloads.

<details>
<summary>Development</summary>

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-HeliumFixDRM.ps1
pwsh -NoProfile -File .\tests\Test-HeliumFixDRM.ps1
```

Tests use temporary fixtures and mocks, without modifying your browser or creating a real scheduled task. They do not verify Netflix playback. Keep contributions compatible with both PowerShell versions, preserve signature checks, and describe validation in pull requests.

The custom PNG buttons are static navigation graphics. Click Tests / CI to see live workflow results.

</details>
## Credits and license

Helium and its logo belong to the [Helium project by imput](https://github.com/imputnet/helium). The transparent PNG icon comes from the [official Helium repository](https://github.com/imputnet/helium/blob/24409ea1dd0da4603aa87296f499370dfa4d5849/resources/branding/app_icon/raw.png). This utility is not affiliated with or endorsed by Helium, Google, or Netflix.

The installer code and original custom PNG artwork are licensed under [MIT](LICENSE). The upstream Helium logo is not covered by this repository's MIT license. No Widevine binaries are redistributed here.
