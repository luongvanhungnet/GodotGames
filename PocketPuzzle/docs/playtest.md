# PocketPuzzle playtest build 0.6.0

This build compares two playable 2D puzzle ideas. It is an offline prototype for
testing enjoyment, clarity, and difficulty. Revenue and retention are unmeasured.

## Controls

Choose a game from the collection. The level button opens all 150 levels in pages
of 30. Undo
restores a full move, Restart resets the current puzzle, and Android Back returns
to the collection. Completion, solve records, and the next level are saved locally
for each named player. **Resume** restores the unfinished board, its undo history,
move/undo counters, and active solve time after relaunch. One unfinished regular
attempt and one daily attempt are retained per game and player. Choosing another
regular level replaces that game's pending regular attempt. Uninstalling removes
local progress and settings.

**Learn** opens an interactive, unranked lesson. New players get a lesson when
first opening a regular game. **Daily Joy** chooses one existing puzzle per game
for the local date and stores separate daily personal bests. Settings controls
gentle sound effects and optional vibration. See `daily-joy.md` for details.
Settings also offers reduced motion and numbered matching symbols. **Hint**
highlights a verified next move or suggests undo steps back to a known route.
Hints are free and do not make moves. See `comfort.md` for limits and controls.

Completed levels display a star. Parcel and block pals carry the same identifying
symbols as their deliveries or gates. Pastel colors, smiling characters, and brief
celebrations add feedback while the puzzle rules and score formula stay the same.

### Parcel Sort

The delivery strip requests parcels in order, starting at NOW. Tap anywhere in a
queue to send its top parcel. A matching parcel delivers immediately; any other
parcel occupies a waiting slot. Waiting parcels deliver automatically when their
turn arrives. Three waiting slots are available. A full waiting area can still
accept a matching delivery. If every queue is blocked, undo or restart.

Each parcel has both a color and a symbol. The first level teaches dispatching;
the next levels introduce waiting and automatic delivery. Later levels have four
parcel types. Every parcel must be delivered to finish.

### Block Exit

Tap a block to select it. Swipe at least 24 logical pixels in a direction, or use
the four arrow buttons. Every action moves one grid cell. Entire rectangular
blocks must fit their matching gate before they can leave. Blocks cannot overlap,
rotate, or leave through other boundaries. Deliver every block to finish.

Early levels have few pieces. Later levels introduce rectangular
blocks and four gate types. Both blocks and gates carry matching symbols.

## A practical comparison session

1. Recruit 10–20 people who enjoy casual phone games. Explain that this is a
   prototype; observe only with their consent.
2. Give half the players Parcel Sort first, and the other half Block Exit first.
3. Let each person try levels 1–5 of each game without explaining the rules.
4. Record manually: time to first successful move, requests for help, completed
   levels, restarts, and which game they voluntarily choose for another round.
5. Ask what felt confusing, satisfying, or unfair. Ask which game they would keep.
6. Invite them back the following day. A tiny test is directional feedback, not a
   reliable retention estimate or proof of demand.

Use the findings to revise mechanics and level difficulty before building more
content or spending on marketing. The collection and progress are local features;
the app does not transmit playtest observations.

## Technical validation

- The level generator uses fixed per-level seeds and constructive solutions.
  All 150 Parcel boards and all 150 Block boards are distinct. The original first
  30 levels are preserved. Later Parcel levels add longer, alternating orders.
- `tests/gameplay.gd` checks all 300 solutions against the GDScript rules, parcel
  conservation, waiting capacity, blocked moves, collisions, gate fit, and undo.
- `tests/smoke.gd` loads both games, completes their first levels through the UI
  controller, checks records, rankings, the expanded chooser, and saved completion.
- `tests/records.gd` verifies clock pause/resume, scoring, independent records,
  replay handling, ranking ties, profile isolation, and migration from earlier saves.
- Tests use their own progress files and leave the player's save untouched.
- `tests/capture.gd` captures the collection and first/last boards with a real GPU.

For build 0.2.0 on 2026-11-11, Windows and WSL tests passed (2,850 gameplay checks). GPU captures
confirmed that controls fit a 720 x 1280 viewport. On an OPPO CPH1803 running Android
8.1, actual touch input completed Parcel Sort level 1 in six moves and Block Exit
level 1 in seven moves, including a swipe and arrow buttons. Screenshots confirmed
the result screens and the local completion count advancing to 2 / 60. Captured
app logs showed no errors. Images are in ignored `builds/prototype-*.png`.

Additional phones, long sessions, and player difficulty testing remain necessary.
The earlier startup-only validation is recorded separately in `validation.md`.
