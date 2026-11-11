extends RefCounted
## Authored coaching, independent of puzzle state and player feedback.
const PARCEL := [
	"Meet the route! Match the next parcel colour at the front of a queue.",
	"A parcel in the way? Send it to one of the three waiting slots.",
	"Waiting parcels deliver themselves when their colour comes next.",
	"Look one step ahead: which queue uncovers the next colour?",
	"Keep a waiting slot free when you can. Undo is always here.",
	"A longer route! Take it one colour at a time; there is no countdown.",
	"Check the route before sending an extra parcel to the waiting area.",
	"Full waiting area? A matching parcel can still go straight to the route.",
	"Try a different queue if you get stuck. Undo keeps your earlier choices.",
	"You know the basics! Hint can suggest a safe next move. Take your time."
]
const BLOCK := [
	"Tap your pal, then use an arrow or swipe toward its matching gate.",
	"Each pal has its own colour gate. Line up with the opening first.",
	"An arrow moves one square. Swipe across the board for the same move.",
	"The wall is solid except at the matching gate. Try lining up first.",
	"Pals cannot pass through each other. Move one aside to open a path.",
	"A bigger pal needs room for its whole shape at the matching gate.",
	"Look for the pal with a clear exit, then make space for the next.",
	"Wrong turn? Undo brings back your last move, including an exited pal.",
	"Match the gate colour and opening. Number symbols in Settings can help.",
	"Plan a little path to the gate. Hint is here whenever you need a nudge."
]

static func text(mode: String, index: int) -> String:
	if index < 0 or index >= 10 or not mode in ["parcel", "block"]:
		return ""
	return PARCEL[index] if mode == "parcel" else BLOCK[index]
