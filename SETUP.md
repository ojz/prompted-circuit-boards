# Workstation Setup

This project is developed on Windows with KiCad 10. The versions below are a
known-good baseline, not strict pins unless stated otherwise.

## Required tools

1. Install KiCad 10 in `C:\Program Files\KiCad\10.0` and add
   `C:\Program Files\KiCad\10.0\bin` to `PATH`.
2. In KiCad's Plugin and Content Manager, install:
   - [Konnect](https://github.com/mixelpixx/Konnect)
   - Freerouting
   - Fabrication Toolkit
3. Install a Java 25 runtime and add its `bin` directory to `PATH`. The verified
   setup uses the Temurin 25 JRE; a full JDK is not required.
4. Install the global agent skills used by this repository:
   - The skills and agents bundled with Konnect
   - [kicad-happy](https://github.com/aklofas/kicad-happy)

Konnect and Freerouting do not need to be global commands. Konnect is launched
by `.mcp.json`, and Konnect launches the Freerouting JAR through `java`.

## Local configuration

The paths in `.mcp.json` reflect the original Windows workstation. After
cloning on another machine, update its `command` and `KICAD10_3RD_PARTY` values
to that machine's KiCad third-party directory. Keep `konnect.toml` aligned with
the local KiCad installation and API socket location.

For PCB editing, open the board in KiCad and enable:

`Preferences > Plugins > Enable KiCad API`

Schematic editing and `kicad-cli` checks do not require the KiCad GUI.

## Verify the installation

Open a new PowerShell session after changing `PATH`, run:

```powershell
kicad-cli version
java -version
& '<path-to-konnect.exe>' --version
java -jar '<path-to-freerouting.jar>' --help
```

Expected results from the verified setup on 2026-09-07:

```text
KiCad CLI 10.0.3
Temurin JRE 25.0.4.1
Konnect 0.11.0
Freerouting 2.4.1
```

Patch versions may be newer. The important compatibility requirements are
KiCad 10 and a Java runtime supported by the installed Freerouting release.

## Development utilities

The current workstation also has Git, Go, Python, Node.js/npm/NVM, .NET,
ripgrep, CMake, GitHub CLI, GitLab CLI, jq, SQLite, and Bun on `PATH`. These are
useful for development and automation but are not all required to edit and
verify a KiCad module.

Do not commit installed plugins, JARs, fabrication output, or other binaries.
