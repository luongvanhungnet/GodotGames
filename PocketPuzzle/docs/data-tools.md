# Backups & optional playtest notes — build 0.9.0

Open **Settings → Backups & playtest notes**. Export a backup through the system
document picker, choosing a location outside the app's private data folder.
The file includes every local player, scores, settings, stickers, daily history,
selected avatars and unfinished games with their full undo paths. Keep it private.
Backups contain readable data; the SHA-256 integrity check detects accidental
changes and is not encryption or an authentication system.

Restore opens a chosen backup, checks its size (8 MB maximum), format and checksum,
then validates every profile, record and pending puzzle against the current level
catalogue. Invalid files do not partially replace saves. The confirmation preview
shows player, completion and unfinished-game counts. Cancel or Android Back leaves
the current save unchanged. Confirm replaces all local profiles and settings,
retaining a separate recovery copy under **Recover save from before last restore**.
Ordinary autosaves do not overwrite that recovery copy. Uninstalling or clearing
storage removes it; keep an external backup for longer-term recovery.

Backup files use format version 1 around save version 4. Existing game saves still
migrate normally; raw internal save files are not interchangeable with exported
backup envelopes. A backup cannot silently load an incompatible unfinished puzzle.
Restoring does not import, erase or transmit the separate device-local feedback.

## A note only when you choose

Playtest feedback defaults off. **Rate this puzzle** is available after a win, or
open data tools from Settings during a puzzle. Enable local feedback, optionally
write up to 240 characters, and select Too easy, Too hard, Confusing or Feels right.
No note is created just by enabling the switch or playing. All players on this
device share the optional notes. The latest opinion replaces the previous note
for the same regular puzzle or daily puzzle date; at most 200 notes are retained.

Reports contain puzzle context, seed, rating, typed note, difficulty estimate and
game version. No profile names, scores or identifiers are added. Typed notes can
contain what you enter, so leave out personal details. Export notes separately
using the system picker and share the file yourself only if desired. Nothing is
sent automatically. **Clear notes** asks for confirmation and removes stored notes
from the feedback file and its automatic backup; previously exported copies remain
where you saved them. Switching feedback off stops submissions without deleting
existing notes.

## Review before changing difficulty

From PocketPuzzle, run:

    python tools/analyze_playtests.py report1.json report2.json --out builds/playtest-review.csv

The CSV omits free-text notes and profile data, ignores identical duplicate files
and stale puzzle seeds, and groups ratings per puzzle. Counts represent source
files, not verified unique people. A confusing rating flags rule/hint review;
several consistently easy/hard files flag a difficulty or reference-goal review.
These suggestions do not change level data automatically. Human playtests are
still required before retuning labels and goals.

Android uses its native document picker without adding storage or Internet
permissions. Interactive pages inset for reported display cutouts and system
navigation areas. On smaller displays, Settings and data tools scroll.

Run `godot --headless --path . --script tests/data_tools.gd` and the existing suites.
Release configuration, account work and device-test coverage are recorded in
[the release checklist](release-checklist.md).

The 0.9 device checks include native backup/restore on Android 8.1 and native
document export, cutout padding and small-screen scrolling on an Android 16
emulator. Android Back deliveries are paired within 100 ms to work around the
pinned engine's duplicate notification path; a later deliberate press remains
available.
