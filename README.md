# GodotGames / PocketPuzzle

Godot 4.7.2 Standard / GDScript / Compatibility renderer.
Offline Android prototype, 720 x 1280 portrait viewport.

## Playable prototypes
- **Parcel Sort:** tap three queues to deliver parcels in order. Unmatched parcels
  wait in three slots; matching waiting parcels dispatch automatically.
- **Block Exit:** select a block, then swipe or use the arrow buttons to slide it
  through a gate with the same color and symbol.

Each game has 150 deterministic, solution-checked levels, undo, restart, a paged
level chooser, and locally saved completion progress. All levels are open.
Solve timers, total move/undo counters, per-level high scores, fastest times, and
fewest-move records are saved for up to eight named players on one device.
Open **Rankings** on the collection screen to compare total best scores across
all games or filter to Parcel Sort / Block Exit. Rankings are local to this device.
See [scoring and rankings](PocketPuzzle/docs/scoring.md) for the rules.
The interface uses pastel colors, smiling parcel/block pals, rounded controls,
star badges, and a short victory celebration. See the [visual guide and previews](PocketPuzzle/docs/design.md).
The game works offline without ads, purchases, accounts, or analytics.
Build 0.5 adds **Daily Joy** (one date-selected puzzle per game with personal bests),
guided **Learn** lessons, quiet sound effects, optional vibration, and device-wide
sound/vibration settings. Unfinished regular and daily games resume with their
board, undo history, counters, and active solve time. See the [Daily Joy guide](PocketPuzzle/docs/daily-joy.md).
See the [playtest guide](PocketPuzzle/docs/playtest.md) for controls and comparison tasks.
Build 0.6 adds free **Hint** guidance, optional **Reduced motion**, and high-contrast
**Number symbols**. See [comfort and hints](PocketPuzzle/docs/comfort.md) for behavior
and validation limits.

## Local
The Git repository root is `D:\GodotGames`; the Godot project is `PocketPuzzle/`.
Keep one repository: do not run `git init` in PocketPuzzle.
Open `PocketPuzzle/project.godot` with Godot 4.7.2 Standard and press F5.
The startup scene opens a collection screen with both playable games.
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
    godot --headless --path . --script tests/gameplay.gd
    godot --headless --path . --script tests/records.gd
    godot --headless --path . --script tests/daily_joy.gd
    godot --headless --path . --script tests/comfort.gd
    godot --headless --path . --quit-after 5

Regenerate levels with `python tools/generate_levels.py`, then rerun all test suites.
The generator uses Python's standard library; the game runtime is entirely GDScript.
For optional GPU screenshots at 720 x 1280, run
`godot --path . --script tests/capture.gd`. Captures go in ignored `builds/`.

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
The hosted build, tool downloads, Linux checks, and APK export have passed.
See [validation results](PocketPuzzle/docs/validation.md) for evidence and limits.
Debug APKs are development artifacts, not Google Play release bundles.
CI debug keys are temporary; use a stable private key for persistent installs.

## Device and cloud testing
GitHub Actions is enabled. A debug APK is produced on pushes to main and pull requests.
For a connected Android phone, install and launch from PocketPuzzle:

    adb -s SERIAL install -r builds/PocketPuzzle-debug.apk
    adb -s SERIAL shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -f 0x10200000 -n org.pocketpuzzle.prototype/com.godot.game.GodotAppLauncher

Use the Android SDK's adb executable consistently; running multiple versions can
restart its server. The exported launcher is `GodotAppLauncher`.
For a one-minute Firebase Test Lab Robo test, authenticate Google Cloud CLI and run:

    bash scripts/test-android-cloud.sh YOUR_GOOGLE_CLOUD_PROJECT

The project needs Firebase Test Lab enabled and test/storage permissions. Quotas
and billing apply to the selected project. No Firebase runtime SDK or credentials
are included in the game. Test results remain in the selected Firebase project.

## Account setup still needed
Connect and publish the repository environment in your Codex Cloud account using
the setup command above. This local session cannot publish a Codex Cloud environment.
Before release, select a permanent Android package ID and configure private release
signing and a Play Console account. On an Android device, verify installation,
portrait orientation, readable layout on different aspect ratios, safe areas,
pause/resume, offline startup, and graphics/performance.
No revenue, gameplay, rendering performance, or device compatibility is
established by the initial startup smoke check.
