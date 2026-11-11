"""Review manually supplied playtest exports without uploading or changing levels."""
import argparse
import collections
import csv
import hashlib
import html
import json
import pathlib

RATINGS = ("easy", "hard", "confusing", "right")

def analyze(paths, catalogue):
    totals = collections.defaultdict(collections.Counter)
    estimates = {}
    seen = set()
    skipped = 0
    for path in paths:
        path = pathlib.Path(path)
        if not path.is_file() or path.stat().st_size > 8388608:
            skipped += 1
            continue
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest in seen:
            continue
        seen.add(digest)
        try:
            data = json.loads(raw)
            if data.get("format") != "PocketPuzzlePlaytest" or data.get("version") != 1 or not isinstance(data.get("entries"), list):
                raise ValueError("Unsupported report")
        except (ValueError, AttributeError):
            skipped += 1
            continue
        latest = {}
        for entry in data["entries"][-200:]:
            if not isinstance(entry, dict):
                skipped += 1
                continue
            mode, number, rating = entry.get("mode"), entry.get("level"), entry.get("rating")
            if not isinstance(mode, str) or mode not in catalogue or isinstance(number, bool) or not isinstance(number, (int, float)) or not 0 <= number < len(catalogue[mode]) or int(number) != number or not isinstance(rating, str) or rating not in RATINGS:
                skipped += 1
                continue
            number = int(number)
            seed = catalogue[mode][number]["seed"]
            if entry.get("seed") != seed:
                skipped += 1
                continue
            latest[(mode, number, seed)] = entry
        for key, entry in latest.items():
            totals[key][entry["rating"]] += 1
            value = entry.get("difficulty_estimate", "unknown")
            estimates[key] = value if value in ("Gentle", "Tricky", "Challenging") else "unknown"
    rows = []
    for (mode, number, seed), counts in sorted(totals.items()):
        count = sum(counts.values())
        review = "Need more playtest files"
        if counts["confusing"]:
            review = "Review rule clarity and hint guidance"
        elif count >= 3 and counts["hard"] / count >= 0.6:
            review = "Review difficulty estimate and reference goal"
        elif count >= 3 and counts["easy"] / count >= 0.6:
            review = "Review difficulty estimate"
        elif count >= 3:
            review = "Mixed feedback; observe real play"
        rows.append({"game": mode, "level": number + 1, "seed": seed, "source_files": count, **{rating: counts[rating] for rating in RATINGS}, "reported_estimate": estimates[(mode, number, seed)], "review": review})
    return rows, skipped

def write_admin(destination, rows, skipped, paths):
    """Private artifact only. Escape every imported value, including typed notes."""
    notes = []
    seen = set()
    for path in paths:
        if not path.is_file() or path.stat().st_size > 8388608:
            continue
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest in seen:
            continue
        seen.add(digest)
        try:
            data = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(data, dict) or data.get("format") != "PocketPuzzlePlaytest" or data.get("version") != 1 or not isinstance(data.get("entries"), list):
            continue
        for entry in data["entries"][-200:]:
            if isinstance(entry, dict) and isinstance(entry.get("note"), str) and entry["note"].strip():
                notes.append("<li>" + html.escape(str(entry.get("mode", "?"))) + " / raw level index " + html.escape(str(entry.get("level", "?"))) + ": " + html.escape(entry["note"][:240]) + "</li>")
    body = "".join("<tr>" + "".join("<td>" + html.escape(str(row[key])) + "</td>" for key in ("game", "level", "source_files", *RATINGS, "reported_estimate", "review")) + "</tr>" for row in rows)
    document = """<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>PocketPuzzle private admin</title><style>body{background:#f8f5ff;color:#292139;font:17px/1.6 system-ui;margin:32px}table{border-collapse:collapse;width:100%}td,th{padding:12px;border:1px solid #c9bfd7;text-align:left}article{overflow:auto}a{color:#503488}</style><h1>PocketPuzzle private admin</h1><p>Personal offline report. Do not upload this HTML or source feedback to the studio website or GitHub. No network resources or telemetry.</p>"""
    document += f"<p>{len(rows)} puzzles with current-seed feedback; {skipped} invalid or stale items skipped. Counts describe files, not verified unique people.</p>"
    if not rows:
        document += "<p>No real-player evidence loaded. Do not claim feedback-based tuning. Ask volunteers to export notes, place their JSON files in a private folder, then rerun the analyzer.</p>"
    document += "<article><table><thead><tr>" + "".join("<th>" + value + "</th>" for value in ("Game", "Level", "Files", "Easy", "Hard", "Confusing", "Right", "Estimate", "Suggested review")) + "</tr></thead><tbody>" + body + "</tbody></table></article>"
    document += "<h2>Original notes (unverified; may include stale levels)</h2><p>Review privately. Never apply a suggested difficulty change automatically.</p><ul>" + "".join(notes) + "</ul></html>"
    destination.write_text(document, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="*", type=pathlib.Path)
    parser.add_argument("--admin", action="store_true", help="Write a private offline HTML dashboard alongside the CSV")
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("builds/playtest-review.csv"))
    args = parser.parse_args()
    if len(args.reports) > 100:
        parser.error("Review at most 100 exported files at a time")
    catalogue = json.loads(pathlib.Path("assets/data/levels.json").read_text())
    rows, skipped = analyze(args.reports, catalogue)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    fields = ["game", "level", "seed", "source_files", *RATINGS, "reported_estimate", "review"]
    with args.out.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fields)
        writer.writeheader()
        writer.writerows(rows)
    if args.admin:
        write_admin(args.out.with_suffix(".html"), rows, skipped, args.reports)
    print(f"Wrote {len(rows)} puzzle reviews; skipped {skipped} invalid/stale items. Counts are files, not unique players. CSV omits notes and names; any HTML admin report is private.")

if __name__ == "__main__":
    main()
