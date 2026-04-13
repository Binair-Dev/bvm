# BVM v0.3.0 — Backup & Restore

**Release Date:** 2026-04-13

## What's New

### 🛡️ VM Backup (Export)
- Export any VM to a `.tar.gz` archive via the VM card menu (⋮ → Backup).
- Live progress dialog with step-by-step status:
  - Calculating size
  - Compressing VM
  - Saving backup file
- Gracefully handles `tar` warnings on Android (special files / symlinks).

### ⬇️ VM Restore (Import)
- Import a previously exported VM from the home screen (⬇️ Import VM button).
- Live progress dialog showing:
  - Reading backup file
  - Extracting VM
- Imported VMs appear automatically in the VM list.

### 🐛 Fixes
- Replaced `ActivityResultContracts` with `startActivityForResult` to fix export/import launcher issues on some Android versions.
- Fixed `MainActivity.kt` imports for better compatibility.

## Download

- `bvm-v0.3.0.apk` (34 MB)

## Installation

1. Uninstall any previous BVM APK.
2. Install `bvm-v0.3.0.apk`.
3. Launch the app and grant storage permissions when prompted.
