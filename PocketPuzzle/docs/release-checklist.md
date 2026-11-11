# PocketPuzzle 0.9 release preparation

This is a review package, not a published store release. Keep the Godot editor and
export templates pinned to `.godot-version` (4.7.2 Standard, Compatibility).
Run every project command from PocketPuzzle.

## Reproducible artifacts

- Debug phone APK: `godot --headless --path . --export-debug Android builds/PocketPuzzle-debug.apk`
- x86-64 emulator APK: export the `Android Emulator` preset to `builds/PocketPuzzle-emulator.apk`.
- Review AAB: `python scripts/export_bundle.py --preview`.
- Store art: `godot --path . --script tools/capture_store.gd`.
- Private feedback review: `python tools/analyze_playtests.py path/to/report.json --out builds/playtest-review.csv`.
- Check both GDScript and Python suites, including `tests/data_tools.gd` and
  `python -m unittest discover -s tests -p 'test_*.py'`.

Bundle export needs matching `android_source.zip`, an Android SDK with platform 36
and build tools 36.1.0, and a compatible JDK. CI uses JDK 17; the local Gradle build
was also exercised with Android Studio's JBR 21. The script installs the matching
Gradle template, validates the AAB archive, redacts signing values from its log,
and restores the tracked export configuration after a temporary package override.
Gradle is run without a persistent daemon to avoid retained Windows output pipes.

The root `android-bundle.yml` workflow builds a preview when bundle configuration
changes. It can also be dispatched manually. Default previews are debug-signed
with the prototype application ID and cannot be uploaded as production releases.

## Production signing and account work

Run `python scripts/export_bundle.py --package-id your.final.applicationid` only
after configuring these environment variables outside Git:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

For the manual GitHub workflow, configure `ANDROID_RELEASE_KEYSTORE_BASE64`,
`ANDROID_RELEASE_KEY_ALIAS` and `ANDROID_RELEASE_KEY_PASSWORD` as repository
secrets, choose production signing, and supply the final package ID. No release
key is generated or committed by this setup. Back up your signing material
securely and choose the final application ID before creating the store app.

Complete Play Console setup, developer verification, app signing, the store
listing, support details, public privacy-policy URL, Data safety, audience,
content rating, pricing and distribution. Upload to internal testing first,
review pre-launch reports and applicable testing requirements, then decide on
production rollout. No Play Console connection is available in this workspace;
no store upload or account declarations have been performed.

Official references: [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html),
[Play testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334),
[pre-launch reports](https://support.google.com/googleplay/android-developer/answer/9842757).

## Player and device checks

Record device/Android version and actual observations; do not treat a headless
pass as a rendering or performance measurement.

| Check | Evidence to record |
| --- | --- |
| Existing-save upgrade | Names, scores, stickers, settings and pending moves preserved |
| Document export/import | Actual system picker, chosen-file write/read, confirmation cancel, restore and recovery |
| Optional feedback | Off by default, explicit submission, manual export, clearing local primary and backup |
| Interruption | Background, screen lock, process death and native-picker cancellation preserve a run |
| Small screens | Portrait 360 × 640 and tall-phone layouts; scroll all data tools and Settings controls |
| Modern Android | Android 15/16 or newer, gesture navigation and edge-to-edge behavior |
| Cutouts | Real or emulated notch plus status/navigation insets; all controls remain reachable |
| Demanding hints | Seeded later-level detours; observe responsiveness and search fallback |
| Gameplay | Parcel waiting slots, block selection/swipes, undo, restart, daily date rollover |

Difficulty estimates and reference goals still require real-player observations.
The feedback analyzer produces review suggestions, never edits levels or claims
its files represent unique testers. Identical exports are deduplicated; overlapping
exports from one device may still overlap because no user identifier is collected.
Review original notes privately, observe people playing, and update labels/goals
only after sufficient evidence. No real-player feedback is fabricated in tests.

## Recorded validation for 0.9

- All eight GDScript suites passed on Windows and Linux; the Python analyzer tests
  also passed. Backup tests cover integrity, schema and pending-path validation,
  recovery, cancellation, file errors and explicit note deletion.
- OPPO CPH1803, Android 8.1: actual native document export/import, checksum
  verification, restore cancel/confirm, recovery, local feedback opt-in, manual
  export and primary/backup clearing passed. Original device files were restored
  exactly after testing; temporary exported test files were removed.
- Android 16 / API 36 x86-64 emulator, host Intel GPU: startup, an emulated tall
  cutout, puzzle input, background timer pause, process-death resume, native
  document export, 720 × 1280 resizing and scrolling passed.
- Modern Back testing exposed paired notifications in the pinned engine. A tested
  100 ms duplicate-delivery guard prevents one press from navigating twice. See
  [the upstream report](https://github.com/godotengine/godot/issues/123454).
- The emulator's SwiftShader software renderer hit a fragment-uniform shader
  limit; validation used host GPU rendering instead. These runs do not establish
  performance on all modern phones or software renderers.
- The preview AAB was validated with Google bundletool 1.18.3. The manifest requests
  VIBRATE only; no Internet, advertising-ID or broad storage permission was added.
- Store art dimensions and the review ZIP's explicit file allow-list are checked
  by `python tools/package_review.py`. The ZIP excludes private saves and keys.

Play Console upload, Google device-farm/pre-launch reports, production signing,
audience/rating declarations and real-player tuning remain unperformed. Those
need publisher configuration or real participants; the materials above are ready
for review and internal-test preparation.
