"""Review manually supplied playtest exports without uploading or changing levels."""
import argparse
import collections
import csv
import hashlib
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
        if path.stat().st_size > 8388608:
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
            if not isinstance(mode, str) or mode not in catalogue or isinstance(number, bool) or not isinstance(number, (int, float)) or not 0 <= number < len(catalogue[mode]) or int(number) != number or rating not in RATINGS:
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

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="+", type=pathlib.Path)
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
    print(f"Wrote {len(rows)} puzzle reviews; skipped {skipped} invalid/stale items. Counts are files, not unique players. Notes and names are omitted.")

if __name__ == "__main__":
    main()
