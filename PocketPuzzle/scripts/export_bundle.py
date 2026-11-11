"""Build a preview AAB, or a release AAB using externally configured signing."""
import argparse
import os
import pathlib
import re
import subprocess
import zipfile

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", action="store_true", help="Debug-signed review bundle; not for Play upload")
    parser.add_argument("--package-id", help="Final application ID, required for a production bundle")
    args = parser.parse_args()
    project = pathlib.Path.cwd()
    if not (project / "project.godot").exists():
        parser.error("Run this command from PocketPuzzle/")
    godot = os.environ.get("GODOT_BINARY", "godot")
    version = subprocess.check_output([godot, "--version"], text=True).strip()
    pin = pathlib.Path(".godot-version").read_text().strip()
    if not version.startswith(pin + ".stable."):
        parser.error("Editor must match .godot-version and installed export templates")
    secret_names = ("GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD")
    if not args.preview:
        if not args.package_id or not re.fullmatch(r"[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,}", args.package_id) or args.package_id == "org.pocketpuzzle.prototype":
            parser.error("Supply your final non-prototype --package-id for a production bundle")
        if any(not os.environ.get(name) for name in secret_names) or not pathlib.Path(os.environ[secret_names[0]]).is_file():
            parser.error("Configure the release keystore path, alias and password through environment variables")
    pathlib.Path("builds").mkdir(exist_ok=True)
    lock = pathlib.Path("builds/.bundle-export.lock")
    preset = pathlib.Path("export_presets.cfg")
    original = preset.read_bytes()
    try:
        with lock.open("x"):
            pass
    except FileExistsError:
        parser.error("A bundle export lock exists; finish the other export first")
    try:
        if not args.preview:
            text = original.decode("utf-8")
            before, options = text.split("[preset.1.options]", 1)
            options = re.sub(r'package/unique_name="[^"]+"', 'package/unique_name="' + args.package_id + '"', options, count=1)
            preset.write_text(before + "[preset.1.options]" + options, encoding="utf-8")
        output = "builds/PocketPuzzle-preview.aab" if args.preview else "builds/PocketPuzzle-release.aab"
        command = [godot, "--headless", "--path", ".", "--install-android-build-template", "--export-debug" if args.preview else "--export-release", "Android Bundle", output, "--quit"]
        environment = os.environ.copy()
        # A persistent Windows Gradle daemon can retain the exporter's pipe.
        environment["GRADLE_OPTS"] = (environment.get("GRADLE_OPTS", "") + " -Dorg.gradle.daemon=false").strip()
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=1200, env=environment)
        log = result.stdout
        for name in secret_names:
            if os.environ.get(name):
                log = log.replace(os.environ[name], "[REDACTED]")
        pathlib.Path("builds/bundle-export.log").write_text(log, encoding="utf-8")
        if result.returncode:
            raise SystemExit("Bundle export failed; inspect builds/bundle-export.log")
        with zipfile.ZipFile(output) as bundle:
            if bundle.testzip() or "BundleConfig.pb" not in bundle.namelist() or "base/manifest/AndroidManifest.xml" not in bundle.namelist():
                raise SystemExit("Export did not produce a valid Android App Bundle archive")
        print(output + (" — debug-signed preview, not for store upload" if args.preview else " — release-signed; review in Play internal testing before production"))
    finally:
        preset.write_bytes(original)
        lock.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
