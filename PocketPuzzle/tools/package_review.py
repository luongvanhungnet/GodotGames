"""Create a review ZIP from an explicit allow-list; never collect saves or keys."""
import pathlib
import struct
import zipfile

def dimensions(path):
    data = path.read_bytes()[:24]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", data[16:24])

def main():
    assets = pathlib.Path("docs/store")
    assert dimensions(assets / "icon-512.png") == (512, 512)
    assert dimensions(assets / "feature-graphic.png") == (1024, 500)
    screenshots = sorted((assets / "screenshots").glob("*.png"))
    assert len(screenshots) == 5 and all(dimensions(path) == (720, 1520) for path in screenshots)
    with zipfile.ZipFile("builds/PocketPuzzle-preview.aab") as bundle:
        assert bundle.testzip() is None and "BundleConfig.pb" in bundle.namelist()
        assert not any("/tests/" in name or "/docs/" in name or name.endswith((".keystore", ".jks")) for name in bundle.namelist())
    files = [pathlib.Path("builds/PocketPuzzle-debug.apk"), pathlib.Path("builds/PocketPuzzle-preview.aab"), pathlib.Path("docs/release-checklist.md"), pathlib.Path("docs/data-tools.md"), *sorted(assets.rglob("*.md")), *sorted(assets.rglob("*.png"))]
    output = pathlib.Path("builds/PocketPuzzle-0.9-review.zip")
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, path.as_posix())
    print(f"Prepared {output}: preview builds, five screenshots, artwork, listing, privacy draft and release checklist. Production signing and Play Console publication are not included.")

if __name__ == "__main__":
    main()
