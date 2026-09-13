# Troubleshooting

[Back to the project](../README.md) · [Full user guide](USAGE.md)

## Start with the diagnostic

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

## Restore a backup

Close Helium. Find the `WidevineCdm.backup-...` folder created during the previous installation, then run your downloaded script with that exact path:

```powershell
.\HeliumFixDRM.ps1 -SourcePath 'C:\path\to\WidevineCdm.backup-example' -Force
```

Replace the example path with your actual backup folder. The backup is validated like any other source. Backups are not removed automatically.

## Installed, but playback fails

1. Restart Helium after installation.
2. Check protected-content permissions at `chrome://settings/content/protectedContent`.
3. Inspect the CDM entry at `chrome://media-internals` and test an encrypted video on the [Bitmovin demo](https://bitmovin.com/demos/drm).
4. Compare the same service and title with up-to-date Chrome or Edge on the same PC.
5. Record the service's error and the relevant player's events in `chrome://media-internals`.

A successful demo does not guarantee every streaming service will accept the browser. A listed CDM also does not prove it was attached to the player. Short unencrypted previews cannot identify the DRM used for the full program.

### Netflix

The investigation behind this project found repeated application-level license errors in Helium, even after matching Chrome's Widevine version. Chrome's successful player used Widevine. These observations do not establish a specific VMP rejection or a working Helium setting to fix the failure.

The installer does not resolve that case. `-Netflix` opens Netflix in a separate Edge or Chrome window instead; it does not change the default browser.

## Report a problem

Use the [bug report form](https://github.com/da0t-exe/Helium-Fix-DRM/issues/new?template=bug_report.yml). Include Windows, PowerShell, Helium, and Widevine versions, the command used, and sanitized error output.

Do not attach raw HAR files, cookies, authorization headers, license payloads, or account tokens. Share only the relevant sanitized messages. Distinguish an installation failure from a service refusing playback.
