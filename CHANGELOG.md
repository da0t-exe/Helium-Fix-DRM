# Changelog

Project changes are listed by date. No versioned release has been assigned to these entries.

## 2026-09-13

### Presentation and documentation

- Redesigned the README with the official Helium logo, status badges, quick start, and documentation links.
- Added a user guide, troubleshooting guide, contribution guidelines, and GitHub issue and pull request templates.
- Translated the documentation, console output, and progress messages into English.

### Installer and updates

- Added streamed download progress with received size, transfer speed, and percentage when available.
- Added version comparison to skip unnecessary replacements and prevent automatic downgrades.
- Added optional scheduled synchronization from the local Chrome module at sign-in and daily at noon.
- Added file validation, staged installation, backups, and rollback on final-move failure.
- Added a separate `-Netflix` action for opening Edge or Chrome.
- Added automated tests for Windows PowerShell 5.1 and PowerShell 7.

### Known limitation

- Netflix playback inside Helium remains unresolved, including after matching Chrome's Widevine version.
