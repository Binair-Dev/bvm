# bVM — Ubuntu Virtual Machines on Android

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge&logo=android)](https://github.com/Binair-Dev/bvm/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Android](https://img.shields.io/badge/Android-10%2B-brightgreen?logo=android)](https://www.android.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.27-02569B?logo=flutter)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?logo=nodedotjs)](https://nodejs.org/)

> Run **multiple Ubuntu VMs** inside Android — no root, no emulator, just pure `proot` power. Comes as a beautiful Flutter app **and** a lightweight Termux CLI.

---

## What is bVM?

**bVM** (short for *Binair Virtual Machine*) turns your Android device into a portable Linux lab. It installs a minimal Ubuntu rootfs via **proot**, then lets you create, delete, and manage **isolated Ubuntu VMs** from a native Flutter UI or a simple Termux command line.

Each VM is a fully independent Ubuntu environment with its own filesystem, packages, and state. Perfect for developers, hackers, students, and homelab enthusiasts who want a real Linux shell in their pocket.

### Two Ways to Use

| | **Flutter App** (Standalone) | **Termux CLI** |
|---|---|---|
| Install | Download APK from Releases | `npm install -g bvm` |
| Setup | One-tap Ubuntu base download | `bvm setup` |
| Create VM | Tap "New VM" | `bvm create <name>` |
| Terminal | Built-in `xterm` emulator | `bvm shell <name>` |
| Manage | List / delete / open terminal | `bvm list / delete` |

---

## Why bVM? — Real-World Use Cases

### 1. 💻 Development on the Go
Write and run Python, Node.js, Go, Rust, or C code directly on your phone. Install compilers, git, VS Code Server, or Neovim and turn your Android device into a pocket IDE.

### 2. 🛡️ Cybersecurity & Pentesting
Run security tools like `nmap`, `nikto`, `hydra`, `sqlmap`, or `metasploit-framework` in an isolated Ubuntu sandbox. Test networks, audit APIs, or practice CTF challenges anywhere.

### 3. 🏠 Homelab & Server Management
Manage remote servers via SSH, run Ansible playbooks, sync dotfiles, or host lightweight services (e.g., a personal wiki, file server, or monitoring dashboard) — all from your mobile.

### 4. 🎓 Learn Linux Risk-Free
Perfect for students and beginners who want to practice bash scripting, system administration, package management (`apt`), and networking without risking their main computer.

### 5. 🧪 Isolated Experimentation
Test suspicious scripts, untrusted software, or breaking changes in a disposable VM. If something goes wrong, just delete the VM and spin up a fresh one in seconds.

### 6. 🗄️ Backend & Database Prototyping
Run local databases (PostgreSQL, MongoDB, Redis), API servers, or message queues inside a VM to prototype and test mobile apps against a real backend stack.

### 7. 🔧 Legacy & Linux-Only Tools
Access tools and libraries that simply don't exist on Android (e.g., `gcc`, `gdb`, `wireshark-cli`, `ffmpeg` with full codecs, `latex`, etc.).

---

## Features

### Flutter App
- **One-Tap Base Setup** — Downloads the official Ubuntu minimal rootfs (~300MB)
- **Multi-VM Manager** — Create as many isolated Ubuntu VMs as your storage allows
- **Built-in Terminal** — Full `xterm-256color` emulator with extra keys toolbar, copy/paste, clickable URLs
- **Foreground Service** — Keeps terminal sessions alive in the background
- **Zero Root Required** — Everything runs inside `proot`, safely and securely
- **Battery & Storage Helpers** — In-app guidance for permissions and optimization

### Termux CLI
- **One-Command Setup** — Installs `proot-distro`, downloads Ubuntu, and prepares the CLI
- **Multi-VM Commands** — `create`, `delete`, `list`, `shell`, `exec`
- **Lightweight** — Written in pure Node.js, no heavy dependencies

---

## Quick Start

### Flutter App

1. Download the latest APK from [Releases](https://github.com/Binair-Dev/bvm/releases)
2. Install it on your Android 10+ device
3. Open the app and tap **Install Ubuntu Base**
4. Tap **+ New VM** to create your first VM
5. Tap the VM card to open the terminal

Or build from source:

```bash
git clone https://github.com/Binair-Dev/bvm.git
cd bvm/flutter_app
flutter pub get
flutter build apk --release
```

### Termux CLI

> **Requires Termux from [F-Droid](https://f-droid.org/packages/com.termux/)** (not the Play Store version).

#### One-liner install

```bash
curl -fsSL https://raw.githubusercontent.com/Binair-Dev/bvm/main/install.sh | bash
```

#### Manual install

```bash
npm install -g bvm
bvm setup
```

#### CLI Usage

```bash
# Download and prepare the Ubuntu base rootfs
bvm setup

# Create a new VM
bvm create devbox

# List all VMs
bvm list

# Open a shell inside a VM
bvm shell devbox

# Run a command inside a VM
bvm exec devbox "apt update && apt install -y python3"

# Delete a VM permanently
bvm delete devbox --yes
```

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **Android** | 10 or higher (API 29+) |
| **Storage** | ~300MB for base rootfs + ~300MB per VM |
| **Architectures** | arm64-v8a, armeabi-v7a, x86_64 |
| **Termux** (CLI only) | From [F-Droid](https://f-droid.org/packages/com.termux/) |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  VM Manager  │  │   Terminal   │  │   Settings   │       │
│  │ (create/list)│  │  (xterm emu) │  │(permissions) │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            │
                 MethodChannel (Kotlin)
                            │
┌─────────────────────────────────────────────────────────────┐
│              BootstrapManager + ProcessManager              │
│              (proot binary + rootfs handling)               │
└─────────────────────────────────────────────────────────────┘
                            │
                         proot
                            │
┌─────────────────────────────────────────────────────────────┐
│              Base Ubuntu Rootfs (ubuntu)                    │
│         (official Ubuntu minimal tar.gz)                    │
└─────────────────────────────────────────────────────────────┘
                            │
                    clone on demand
                            │
┌─────────────────────────────────────────────────────────────┐
│              VM Instances (devbox, homelab, ...)            │
│         (independent copies with full apt access)           │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
bvm/
├── flutter_app/              # Flutter application
│   ├── android/              # Kotlin native layer (proot bridge)
│   ├── lib/                  # Dart UI + providers + services
│   ├── assets/               # Icons & fonts
│   └── pubspec.yaml
├── bin/                      # CLI entrypoints
│   └── bvm                   # Termux CLI
├── lib/                      # CLI source (Node.js)
│   ├── commands.js
│   ├── vm-manager.js
│   └── utils.js
├── install.sh                # One-liner Termux installer
├── package.json              # NPM manifest
└── README.md
```

---

## Development

### Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

### Termux CLI

```bash
npm install
npm link
bvm --help
```

---

## Credits

- **bVM** is a spin-off of the mobile shell architecture originally explored in [Hermes Agent Mobile](https://github.com/Binair-Dev/HermesAgentMobile).
- The `proot` integration and terminal emulator patterns are inspired by [OpenClaw Termux](https://github.com/mithun50/openclaw-termux) by mithun50.
- Ubuntu rootfs images are sourced from [Canonical's official releases](https://cdimage.ubuntu.com/ubuntu-base/).

---

## License

MIT © [Brian Van Bellinghen](mailto:van.bellinghen.brian@gmail.com)
