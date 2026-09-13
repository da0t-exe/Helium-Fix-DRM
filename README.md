<p align="center">
  <a href="https://helium.computer">
    <img src="https://raw.githubusercontent.com/imputnet/helium/24409ea1dd0da4603aa87296f499370dfa4d5849/resources/branding/product_logo.svg" width="96" height="96" alt="Helium browser logo">
  </a>
</p>

<h1 align="center">Helium Fix DRM</h1>

<p align="center">
  <strong>Widevine setup for Helium. One PowerShell command.</strong><br>
  Install, verify, and keep your local module up to date on Windows.
</p>

<p align="center">
  <a href="https://github.com/da0t-exe/Helium-Fix-DRM/actions/workflows/test.yml"><img src="https://github.com/da0t-exe/Helium-Fix-DRM/actions/workflows/test.yml/badge.svg" alt="PowerShell tests"></a>
  <img src="https://img.shields.io/badge/platform-Windows-3450D1" alt="Platform: Windows">
  <img src="https://img.shields.io/badge/PowerShell-5.1%20%7C%207-3450D1" alt="PowerShell 5.1 and 7">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-3450D1" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> &nbsp; / &nbsp;
  <a href="#automatic-updates">Automatic updates</a> &nbsp; / &nbsp;
  <a href="docs/USAGE.md">Full guide</a> &nbsp; / &nbsp;
  <a href="docs/TROUBLESHOOTING.md">Troubleshooting</a>
</p>

---

> [!IMPORTANT]
> **An independent community utility for Helium.** Installing Widevine does not guarantee that a streaming service will accept the browser. The Netflix failure investigated in this project remains unresolved.

## What you get

| | Feature | What it does |
| :---: | --- | --- |
| 🔎 | Automatic detection | Finds Helium, checks its architecture, and locates Widevine in Chrome. |
| 📦 | Simple installation | Uses a verified local module, or extracts Google's official installer. |
| 📊 | Download progress | Shows percentage, received size, and transfer speed. |
| 🔄 | Optional updates | Synchronizes newer Widevine versions from Chrome at sign-in and daily. |
| 🛟 | Backups and rollback | Validates staged files and keeps the previous module before replacement. |

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

The command executes the script on `main`. You can [download and inspect it first](docs/USAGE.md#useful-options), or replace `main` with a commit ID to pin a version.

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

The task uses a locally saved installer. Run the enable command again after a script update to refresh that copy. See the [full update guide](docs/USAGE.md#enable-automatic-updates) for details.

</details>

## Compatibility

| Component | Status |
| --- | --- |
| PowerShell 5.1 and 7 | Covered by automated tests. |
| Google CDM files | Architecture, manifest, and Authenticode signature checked before installation. |
| Encrypted playback in Helium | Depends on the browser and service; test with the [Bitmovin DRM demo](https://bitmovin.com/demos/drm). |
| Netflix inside Helium | **Not fixed by this project.** Matching Chrome's Widevine version did not resolve the observed license rejection. |
| Netflix in another browser | `-Netflix` opens a separate Edge or Chrome window. |

## Documentation

- [User guide](docs/USAGE.md) — every option, custom paths, updates, and backups.
- [Troubleshooting](docs/TROUBLESHOOTING.md) — installation errors and playback diagnostics.
- [Contributing](CONTRIBUTING.md) — local tests and pull requests.
- [Changelog](CHANGELOG.md) — project changes.

Found an installer issue? [Open a bug report](https://github.com/da0t-exe/Helium-Fix-DRM/issues/new?template=bug_report.yml).

## Credits and license

Helium and its logo belong to the [Helium project by imput](https://github.com/imputnet/helium). The logo above is referenced from its official repository. This utility is not affiliated with or endorsed by Helium, Google, or Netflix.

The installer code is licensed under [MIT](LICENSE). The upstream Helium logo is not covered by this repository's MIT license. No Widevine binaries are redistributed here.
