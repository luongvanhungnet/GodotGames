# Setup validation

Validated on 2026-11-11 with Godot 4.7.2 Standard
(`4.7.2.stable.official.ed1daf0bf`), GDScript, and Compatibility rendering.

## Automated checks

- Windows: headless editor import, startup smoke test, and startup execution passed.
- Linux: `bash scripts/cloud-setup.sh` passed in Ubuntu under WSL, including
  downloading the pinned engine, import, smoke test, and startup execution.
- [GitHub Actions run 42866716885](https://github.com/luongvanhungnet/GodotGames/actions/runs/42866716885)
  passed on commit `3f5a977`: Linux checks, template installation, signed debug APK
  export, and artifact upload all succeeded.
- Both shell scripts passed `bash -n`; staged changes passed `git diff --check`.
- The project now explicitly enables ETC2/ASTC imports, required by Android export.
  The workflow uses the hosted Android SDK on Ubuntu 24.04.

## Physical phone

OPPO CPH1803, Android 8.1.0, 720 x 1520, Qualcomm Adreno 506:

- Debug APK installed successfully and launched through `GodotAppLauncher`.
- Screenshot inspection confirmed the centered, readable startup message and
  full portrait background without clipping.
- Home followed by a normal launcher intent resumed the same process.
  Startup and resumed screenshots were identical.
- Device logs confirmed Godot 4.7.2 and OpenGL ES 3.2 Compatibility rendering,
  with no app errors in the captured run.
- Manifest inspection confirmed portrait orientation and no Internet permission.
  Device display orientation was portrait. Forcing a landscape setting through
  ADB was rejected by the phone's WRITE_SETTINGS permission policy; manual
  rotation testing remains outstanding.
- The Redmi Note 9 Pro was initially visible but disconnected before installation;
  it was unavailable when rechecked. No result is claimed for that phone.

Local evidence is in ignored `builds/oppo-startup.png`, `builds/oppo-resumed.png`,
and `builds/PocketPuzzle-debug.apk`. The locally tested APK's SHA-256 is
`76e8e079357ed45fc8bde04fc3a1ee91ec67994209924952d8d430ed2b9bbf58`.
CI uses its own debug key, so its APK hash and signing identity differ.

## Firebase Test Lab

An actual Robo run passed in the existing Google Cloud project `puzzlegame-ff279`:

- Matrix: `matrix-285zxjxg833xe`.
- Device: `MediumPhone.arm`, Android 15 / API 35, English, portrait.
- Outcome: **Passed**. Timeout was 60 seconds; Robo completed its test in 18 seconds.
- [Firebase results](https://console.firebase.google.com/project/puzzlegame-ff279/testlab/histories/bh.7bcd12d32e059dcc/matrices/5767252662244603010)
  include device logs and screenshots and require project access.
- Repeat from PocketPuzzle with
  `bash scripts/test-android-cloud.sh YOUR_GOOGLE_CLOUD_PROJECT` after Google Cloud
  CLI authentication. No account credentials are stored in source control.

Test Lab reported its planned shutdown on September 30, 2027; review its
[migration guide](https://docs.cloud.google.com/developer-device-platform/device-run/migrate)
before relying on this service long term.

## Remaining account and device work

- Codex Cloud: the local CLI has no environment creation/publish command, and no
  connected tool exposes that account UI. Create/publish the repository environment
  in the signed-in Codex UI with install command
  `cd PocketPuzzle && bash scripts/cloud-setup.sh`. Linux setup itself is verified.
- Store release: the current preset intentionally uses a prototype package ID and
  debug signing. A Play Console account, final package identity, private release
  key, and a release AAB setup are needed before store publication.
- Reconnect the Redmi for a second physical-device run. Check physical rotation,
  notches/safe areas on additional phones, prolonged use, and performance once
  gameplay exists. The static startup scene does not validate gameplay or sustained
  battery, memory, or frame-time performance.
