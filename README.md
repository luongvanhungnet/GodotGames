# GodotGames / PocketPuzzle

Godot 4.7.2 Standard / GDScript / Compatibility renderer.
Offline Android prototype, 720 x 1280 portrait viewport.

## Local
The Git repository root is `D:\GodotGames`; the Godot project is `PocketPuzzle/`.
Keep one repository: do not run `git init` in PocketPuzzle.
Open `PocketPuzzle/project.godot` with Godot 4.7.2 Standard and press F5.
The startup scene displays "PocketPuzzle / Setup complete" on a portrait background.
Install matching export templates through Editor > Manage Export Templates.
Android export needs the SDK and a compatible JDK; CI uses JDK 17.
CI pins Android Platform 35 and Build Tools 35.0.1, following the
[Godot 4.7 Android export requirements](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html).
Choose Project > Export > Android > Export Project with debug enabled.
The prototype package name must be replaced before store publication.

## Checks
Run project commands from the project directory:

    cd PocketPuzzle
    godot --headless --path . --editor --import --quit
    godot --headless --path . --script tests/smoke.gd
    godot --headless --path . --quit-after 5

## Codex Cloud
Push this repository to GitHub and connect it in Codex Cloud.
Use `cd PocketPuzzle && bash scripts/cloud-setup.sh` as the environment setup command
from the repository root. The Linux x86_64 environment needs bash, curl, unzip,
and the engine's shared libraries (including libX11, libXcursor, libXinerama,
libXi, libXrandr, libGL, libfontconfig, and libasound2).
In cloud tasks, first `cd PocketPuzzle`; the executable is `.godot/cloud-tools/godot`.
The setup script downloads the pinned Linux engine; allow GitHub downloads.
Cloud setup validates headless operation, not mobile graphics performance.

## GitHub Actions
The Android workflow runs on GitHub-hosted Linux runners, including when
your computer is off. It runs checks and uploads a debug APK artifact.
The workflow is `.github/workflows/android.yml` at the repository root.
Its shell steps run in `PocketPuzzle/`; artifacts come from
`PocketPuzzle/builds/PocketPuzzle-debug.apk`. To export locally from PocketPuzzle:

    godot --headless --path . --export-debug Android builds/PocketPuzzle-debug.apk

Create `builds/` first and configure Android SDK, Java SDK, and debug keystore
paths in Editor Settings > Export > Android. Never commit keystores or credentials.
The first hosted run must validate tool downloads and SDK compatibility.
Update SDK package versions if the pinned Godot export template requires it.
Debug APKs are development artifacts, not Google Play release bundles.
CI debug keys are temporary; use a stable private key for persistent installs.

## Not connected automatically
Enable GitHub Actions for the repository and connect the repository and environment
in your Codex Cloud account. Firebase Test Lab requires your account and project;
Firebase integration and real-device scenarios are not configured.
Before release, select a permanent Android package ID and configure private release
signing and a Play Console account. On an Android device, verify installation,
portrait orientation, readable layout on different aspect ratios, safe areas,
pause/resume, offline startup, and graphics/performance.
No revenue, gameplay, rendering performance, or device compatibility is
established by the initial startup smoke check.
