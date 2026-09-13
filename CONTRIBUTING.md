# Contributing

Thanks for helping improve Helium Fix DRM.

## Scope

This project installs and synchronizes verified Widevine files. Changes should preserve signature validation, backups, rollback, explicit browser selection, and compatibility with Windows PowerShell 5.1 and PowerShell 7.

Avoid claims that installing a CDM guarantees compatibility with a streaming service. Do not commit proprietary binaries or private playback traces.

## Local development

Clone the repository and run both test suites:

```powershell
git clone https://github.com/da0t-exe/Helium-Fix-DRM.git
cd Helium-Fix-DRM
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-HeliumFixDRM.ps1
pwsh -NoProfile -File .\tests\Test-HeliumFixDRM.ps1
```

The tests use temporary fixtures and mocked trust checks. They do not install a CDM in your browser or create a real scheduled task. A passing suite does not prove Netflix playback.

Use `-WhatIf` for a preview against a real installation. Test installation changes in an isolated fixture before replacing files in a browser you use.

## Pull requests

- Explain the problem, the resulting behavior, and the validation performed.
- Add a regression test when a behavior change warrants one.
- Update the relevant documentation and changelog.
- Keep user-facing messages and documentation in English.
- Preserve the root `HeliumFixDRM.ps1` entry point used by the published one-line command.

Report reproducible installer problems using the issue form. For service-specific failures, provide sanitized evidence and avoid publishing account data.
