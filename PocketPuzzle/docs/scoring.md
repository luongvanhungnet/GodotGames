# Solve records and local player rankings

Build 0.3.0 has 150 Parcel Sort levels and 150 Block Exit levels. The first 30
of each game are unchanged, so earlier completion saves still refer to the same
puzzles. The chooser has five pages per game. Every level has a checked solution.

## Time and moves

Build 0.6 hints are free. Asking for guidance does not increment moves or undo,
pause the timer, or reduce scores. Following an undo suggestion uses the ordinary
Undo button and its usual penalty. Local rankings include solves made with hints.

The solve timer starts when the level opens and stops on the final winning move.
Thinking time counts. Time spent while the app is in the background or unfocused
does not count. The victory animation is excluded. Restart creates a fresh attempt.
Resuming an unfinished game preserves its active solve time and move/undo counts;
time spent with the app closed or in menus is excluded.
The display uses minutes, seconds, and tenths of a second.

The move counter counts every accepted move in the attempt, including moves later
undone. Invalid moves and selecting blocks do not count. A successful undo has its
own counter and does not erase time or reduce the attempt's move count.

## Score

Completed levels earn:

```
completion = 1000
speed      = max(0, 2000 - floor(active_solve_milliseconds / 100))
efficiency = max(0, 3000 - 40 * accepted_moves - 120 * undos)
score      = completion + speed + efficiency
```

For example, a 15-second solve in six moves with no undo earns 5,610 points.
There is no score for abandoning an unfinished puzzle. A level retains three
independent records: highest score, fastest time, and fewest moves. They may come
from different attempts. The result screen also shows how many times it was solved.

## Players and rankings

Choose **Player** on the collection screen to add or switch between up to eight
named local players. Names are 1–18 characters and must be unique on this device.
The same screen can rename the current player while keeping their data.
Each player has independent progress and records.

**Rankings** sums each player's highest score per level, once. Replaying a level
can improve that score but cannot repeatedly add it to the total. Rankings can
cover all games, Parcel Sort, or Block Exit. Ties use the number of scored levels,
then the sum of each level's fastest time. Equal results share a rank. A player
with no scored wins appears as unranked.

Everything is stored on the device. These are friendly local rankings without a
server, accounts, cross-device synchronization, or authoritative score verification.
Uninstalling the app removes local players and their records.

## Earlier saves

An old completion save becomes Player 1's progress automatically. Historical
completions remain marked as done, and the next-level selection is preserved.
Old versions did not record time or score, so those levels receive scored records
when replayed. The update does not invent historical scores.

In build 0.5, guided lessons are unranked. Daily Joy has the same score formula and
separate per-date personal bests. Daily solves do not add regular completion stars
or points to the regular player rankings. A winning result is saved immediately,
before its celebration animation begins.

## Validation

Windows and WSL checks passed for all 300 level solutions (19,726 gameplay checks),
24 clock/record/ranking checks, and the UI smoke flows. All 300 boards are distinct,
and regenerating from fixed seeds produces identical data. A comparison against
the prior version confirmed that all original 60 levels are unchanged.

The Android update on an OPPO CPH1803 preserved 60 previously completed levels.
A real touch solve recorded 7.9 seconds, seven moves including a replayed move,
one undo, and a 5,521-point high score. Test evidence is stored locally in ignored
`builds/records-device-*.png`. Additional phones remain untested for this update.
