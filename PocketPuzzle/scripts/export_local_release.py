"""Build using owner-local signing metadata; never print or copy private values."""
import hashlib
import json
import os
import pathlib
import subprocess
import sys

def main():
    if not pathlib.Path("project.godot").is_file():
        raise SystemExit("Run from PocketPuzzle/")
    source = pathlib.Path(os.environ["LOCALAPPDATA"]) / "BoomBatsa/PocketPuzzle/signing/release.json"
    data = json.loads(source.read_text())
    env = os.environ.copy()
    env.update(GODOT_ANDROID_KEYSTORE_RELEASE_PATH=data["keystore"],
               GODOT_ANDROID_KEYSTORE_RELEASE_USER=data["alias"],
               GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=data["password"])
    for options in (["--apk"], []):
        subprocess.run([sys.executable, "scripts/export_bundle.py", "--package-id", data["package_id"], *options], env=env, check=True)
    checksums = {name: hashlib.sha256(pathlib.Path("builds", name).read_bytes()).hexdigest()
                 for name in ("PocketPuzzle-release.apk", "PocketPuzzle-release.aab")}
    pathlib.Path("builds/release-sha256.json").write_text(json.dumps(checksums, indent=2) + "\n")
    print("Release artifacts built. Verify APK signature and bundle before publication.")

if __name__ == "__main__":
    main()
