# PocketPuzzle

Lightweight offline portrait Android puzzle game. Godot 4.7.2 Standard,
GDScript, Compatibility renderer. Pin matching editor and export templates.
The current playtest build contains Parcel Sort and Block Exit, with 150 levels each.

## Rules
- The only Git repository is the repository root; never initialize one in PocketPuzzle/.
- The Godot project, version pin, tests, and scripts live in PocketPuzzle/.
- GitHub Actions workflows live in the root .github/workflows/ directory.
- Keep changes focused and avoid dependencies without a demonstrated need.
- Prefer simple 2D scenes, small assets, and bounded physics/particle workloads.
- Keep puzzle rules separate from presentation; support seeded generation.
- Pure puzzle rules live in PocketPuzzle/game/ and the interface in PocketPuzzle/ui/.
- Level data lives in PocketPuzzle/assets/data/levels.json. Rebuild deterministic
  fixtures from PocketPuzzle with `python tools/generate_levels.py`.
- Do not add accounts, ads, analytics, purchases, or multiplayer unless requested.
- Never commit signing keys or credentials. Commit scenes and .uid files.

## Validation
- Run all project commands from PocketPuzzle/ (`cd PocketPuzzle` from the root).
- Import: godot --headless --path . --editor --import --quit
- Smoke check: godot --headless --path . --script tests/smoke.gd
- Gameplay: godot --headless --path . --script tests/gameplay.gd
- Records: godot --headless --path . --script tests/records.gd
- Daily Joy: godot --headless --path . --script tests/daily_joy.gd
- Comfort and hints: godot --headless --path . --script tests/comfort.gd
- Journey and collections: godot --headless --path . --script tests/journey.gd
- Progression and search: godot --headless --path . --script tests/progression.gd
- Backup and playtest tools: godot --headless --path . --script tests/data_tools.gd
- The gameplay suite replays all 300 solutions and checks undo, collisions, and gates.
- Records tests cover active solve time, scores, local rankings, and save migration.
- Daily Joy tests cover lessons, daily records, settings, validated unfinished
  sessions, backup recovery, profile isolation, and date rollover.
- Journey tests cover unique-completion credit, all sticker and badge thresholds,
  daily reward history, avatar eligibility, migration, and profile isolation.
- Progression tests cover bounded incremental hints, cancellation, difficulty
  estimates, verified reference goals, preserved pending attempts and restart prompts.
- Help & About and opening coaching are covered by progression tests, including
  returning to an unfinished puzzle without losing moves.
- Private feedback dashboards are generated only under ignored builds/ and must
  never be copied to the studio website or committed with player notes.
- Run relevant gameplay tests when gameplay is added.
- Fail tests with nonzero exit status. Report checks that could not run.
- Headless results do not establish rendering quality or device performance.
- Android builds use export_presets.cfg and matching export templates.
- APK artifacts are PocketPuzzle/builds/ relative to the repository root.
