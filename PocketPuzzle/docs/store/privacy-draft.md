# PocketPuzzle privacy information — publication draft

Complete the publisher identity, support contact, public policy address and
effective date before publishing this document.

PocketPuzzle is an offline puzzle game. The current build does not include ads,
analytics SDKs, purchases, account sign-in, or a server operated by the game.
The app does not automatically send gameplay or personal data to the developer.

The game stores player names, puzzle progress, scores, settings, earned cosmetic
rewards and unfinished games locally on the device. Player names are chosen by
the person using the game and are used for local profiles and rankings.

Playtest feedback is off by default. If enabled, a note is saved only when the
player submits a rating. It contains the puzzle identifier, seed, game version,
estimated difficulty, rating and optional text. No profile name, score, account
identifier, advertising identifier or device identifier is added. Text notes
contain what the person types; avoid entering personal details.

Backups contain all local profiles and game progress in readable JSON, with an
integrity check to detect accidental corruption. They are not encrypted. The
player chooses the destination with the system file picker. Optional playtest
exports are separate and do not include profile data. The game does not send
either file to the developer automatically. A chosen document provider or sharing
app handles exported files under its own privacy practices.

Local playtest notes can be cleared in the game's data tools. Clearing the app's
storage or uninstalling removes locally stored game data and recovery copies.
Files already exported to another location must be deleted there separately.

The Android build requests vibration permission for optional haptic feedback.
System document selection grants access to chosen files without broad storage
permission. The build does not request Internet or advertising-ID permission.

If you independently send an exported file to a support contact, review its
contents first. Do not publish backups containing player names or private notes
on public issue trackers. Publisher support and retention practices for files
received through external support channels must be documented before release.
