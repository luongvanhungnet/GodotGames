# PocketPuzzle 1.0 studio release

Publisher: BoomBatsa. Support: tsabommba@gmail.com.
Public pages: https://boombatsa.win/games/pocketpuzzle/
Privacy: https://boombatsa.win/games/pocketpuzzle/privacy-policy.html
Release application ID: win.boombatsa.pocketpuzzle. Version code 10, name 1.0.0.
Godot/editor/templates remain 4.7.2 Standard, GDScript, Compatibility.

## Player changes

Settings has Help & About with rules, scoring, local ranking explanations,
comfort options, backup guidance, version, credits, support and browser links.
The first 10 regular puzzles in each game have specific authored coaching.
Board data, seeds, scoring and existing unfinished-session compatibility are
preserved. These are design-based clarity improvements; no human feedback
has been supplied and no evidence-based difficulty retuning is claimed.

## Private feedback administration

From PocketPuzzle run:

```
python tools/analyze_playtests.py --admin --out builds/private-admin/playtest-review.csv
python tools/analyze_playtests.py private/path/report1.json private/path/report2.json --admin --out builds/private-admin/playtest-review.csv
```

Open `builds/private-admin/playtest-review.html` locally. Imported notes are
escaped and protected by a no-network content policy. Current-seed aggregate
ratings and suggested reviews are separated from unverified original notes.
Duplicate identical files are ignored. File counts do not establish unique
participants. The empty dashboard explicitly states there is no player evidence.
HTML, CSV and input reports must remain private. Do not copy them into the studio
website. Tools/tests/docs/builds remain excluded from Android exports.

## Signing and reproducibility

Owner-local signing material is outside both repositories at
`%LOCALAPPDATA%/BoomBatsa/PocketPuzzle/signing/`, restricted to the Windows owner
and SYSTEM. `release.json` there contains private credentials: never publish it.
Securely back up that directory outside this computer before depending on it
for future updates. Public certificate fingerprints are safe to publish.

Set GODOT_BINARY to the pinned console executable and JAVA_HOME to a compatible
JDK (local Android Studio JBR 21; CI JDK 17), then run:

```
python scripts/export_local_release.py
```

This creates the release APK, AAB and SHA-256 manifest under ignored builds/.
It invokes export_bundle.py with the owner-local identity. The generic script
also accepts externally managed signing environment variables and --apk.
It restores tracked presets after temporary ID overrides and removes stale
artifacts before export. Debug presets retain the prototype ID for development.

Verify final APK with Android build-tools apksigner verify --verbose --print-certs,
and final AAB using bundletool validate plus jarsigner verification. Publish only
the verified APK and public metadata through the studio's explicit R2 upload.

## Upgrade and remaining publishing work

The signed release installs separately from org.pocketpuzzle.prototype. Transfer
progress using an exported backup and the release's confirmed Restore flow;
do not uninstall the prototype until the restored progress has been checked.

Google Play Console configuration, developer verification, audience/content-rating
and Data safety declarations, Play App Signing, testing tracks and store rollout
remain account work. Keep the same signing identity for subsequent studio APK
updates. If later distributing the same package via Play, plan its app signing
identity so cross-channel updates remain compatible. A prepared signed AAB is
not a Play Store publication. Physical-device checks require a connected phone.

## Recorded verification

- Windows and Linux: all eight Godot suites passed; progression now checks 669 assertions,
  including Help return and the first ten coaching messages in each mode.
- Python: three analyzer tests passed, including malicious-note escaping and
  explicitly empty evidence.
- Native Intel GPU: opening boards and scrollable Help were captured and reviewed.
- APK: apksigner verified v2/v3 signatures, RSA 3072-bit BoomBatsa certificate,
  package win.boombatsa.pocketpuzzle, version code 10/name 1.0.0, min SDK 24,
  target SDK 36, ARMv7/ARM64 and VIBRATE only. No debuggable flag was reported.
- AAB: bundletool 1.18.3 validation and jarsigner verification passed. The Android
  signing certificate is self-signed, as expected for this distribution.
- Website: 12 unit tests passed; the PocketPuzzle browser suite passed on desktop
  Chromium and Pixel 7 layouts both locally and on the deployed custom domain.
- Live studio pages and APK HEAD passed; the complete public APK was downloaded
  and its SHA-256 matched the signature-verified local artifact/public manifest.
- Cloudflare public Worker deployed as bacd844e-0c8f-4ce7-9114-f1b4d4f9b247.
  APK is stored only at the explicit public R2 release key. Private reports and
  signing credentials are absent from the website assets.
- No physical Android phone was connected for this release. Earlier prototype
  device results are historical and do not establish validation of this signed APK.
- No real-player feedback files were supplied; feedback-driven difficulty tuning
  remains pending and the private dashboard states that limitation.
