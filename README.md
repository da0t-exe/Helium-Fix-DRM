# Helium Fix DRM

PowerShell script that restores Widevine DRM playback in [Helium](https://github.com/imputnet/helium) on Windows.

The script downloads the latest Chrome offline installer, extracts `WidevineCdm`, and copies it into Helium's application folder.

> ⚠️ This fix loads the Widevine module into Helium, but some strict streaming services (Netflix, Crunchyroll...) may still refuse playback even with the CDM present — these platforms check browser integrity beyond just the CDM file being there. Works better on less strict services (YouTube, etc.).

## Requirements

- Windows
- [Helium](https://github.com/imputnet/helium) installed under `C:\Program Files\imput\Helium`
- [7-Zip](https://www.7-zip.org/)
- Internet access (to fetch the Chrome installer)
- Permission to write under `C:\Program Files` (run PowerShell as Administrator)

## Quick install (curl-style)

Open **PowerShell as Administrator**, then run directly:

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 | iex
```

This downloads and runs the script in one line, no need to clone the repo.

### With the `-Force` flag (overwrite an existing install)

`irm | iex` doesn't pass arguments directly, so to use `-Force` or `-KeepTemp`, download the script first:

```powershell
irm https://raw.githubusercontent.com/da0t-exe/Helium-Fix-DRM/main/HeliumFixDRM.ps1 -OutFile HeliumFixDRM.ps1
Set-ExecutionPolicy -Scope Process Bypass
.\HeliumFixDRM.ps1 -Force
```

## Manual install (clone the repo)

```powershell
git clone https://github.com/da0t-exe/Helium-Fix-DRM.git
cd Helium-Fix-DRM
Set-ExecutionPolicy -Scope Process Bypass
.\HeliumFixDRM.ps1
```

### Available options

| Option | Effect |
|---|---|
| *(none)* | Installs the CDM only if it doesn't already exist |
| `-Force` | Overwrites an existing CDM |
| `-KeepTemp` | Keeps extracted temp files (debugging) |

Example:
```powershell
.\HeliumFixDRM.ps1 -Force
```

## After running

1. Fully close Helium (make sure no process is still running in the background)
2. Relaunch Helium, or go to `helium://restart/`
3. Check the module is loaded: `helium://components`
4. Test playback on a DRM stream, e.g.: `https://bitmovin.com/demos/drm`

## Troubleshooting

**`Access is denied` when copying**
→ PowerShell isn't running as Administrator. Close the window, relaunch it with "Run as administrator".

**`Error: Helium not found`**
→ Your Helium install isn't under `C:\Program Files\imput\Helium`. Check the real path with:
```powershell
Get-ChildItem "C:\Program Files\imput\Helium\Application" -ErrorAction SilentlyContinue
```
If missing, update the `$HeliumBase` variable at the top of the script to the correct path (often `%LOCALAPPDATA%\imput\Helium\Application` depending on install mode).

**`Error: 7-Zip not found`**
→ Install 7-Zip from [7-zip.org](https://www.7-zip.org/) with default options.

**Widevine stays at `Status: New` or `0.0.0.0` in `helium://components`**
→ This is normal even after a successful install; what matters is that `bitmovin.com/demos/drm` detects "Widevine" instead of "No DRM".

**Some sites (Netflix, Crunchyroll) still refuse playback**
→ Known limitation. These platforms enforce a browser integrity check (Verified Media Path) that simply having the CDM present doesn't satisfy on a non-Google-certified browser. No known client-side fix at this time.

## License

This project is licensed under the [MIT License](LICENSE).
