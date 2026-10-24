## The story notes (BBCode for RichTextLabel). Edit the text here.
extends RefCounted
class_name Notes

const ALL := {
	"dale1": ["Taped to the security monitor", "New guy —\n\nLast shift before they knock this place down. Easy money. A few rules the company won't tell you:\n\n1. If the power goes, the shutters drop and lock. The breaker is in MAINTENANCE, south hall. Somebody keeps pulling the fuses and hiding them in the shops. You'll need three.\n\n2. Don't move the display figures.\n\n3. If one of them is somewhere it wasn't before — keep your FLASHLIGHT on it. Not the hall lights. Not your eyes. The beam. It can't move while the beam is on it. Walk backwards if you have to.\n\n4. Never let it get close in the dark. It jumps.\n\n5. Don't run unless you have to. She hears running.\n\n6. The PA turns itself on. So do the payphones. Answer at your own risk.\n\n— Dale"],
	"lumen": ["Lumen Display Co. — work order", "CUSTOM COMMISSION #0447\nClient: Mr. Arthur Halvorsen\n\nOne (1) full figure, life-cast.\nModel: Miss Iris Halvorsen, age 19.\nFinish: porcelain gloss.\nEyes: none, per client request.\nPlacement: Atrium Window, centered, facing the main doors.\n\n[i]Shop note:[/i] The girl sat for the cast six hours and never once complained. Said she wanted to \"stay here forever, where it's warm and bright.\" Lovely kid."],
	"poster": ["Poster, peeling off the fitting-room door", "MISSING\n\nIRIS HALVORSEN, 19\n\nLast seen November 1st, 1989, at closing time inside the Halvorsen Galleria. Wearing a red dress.\n\nIf you have any information, please call —\n\n[i](the number has been scratched out. Underneath, in lipstick:)[/i]\n[color=#a3141c][font_size=26]SHE NEVER LEFT[/font_size][/color]"],
	"janitor": ["Note on the florist counter", "Counted the figures at close: 31.\nCounted again at open: 32.\n\nThe new one was in here. In the florist. Holding the dead roses like it was waiting for somebody to take her to a dance.\n\nNobody believes me. I'm putting in for days.\n\n— R. Okafor, custodial"],
	"father": ["Letter, tucked inside a book", "To the Board,\n\nYou will not close this mall. Not while I am alive.\n\nMy daughter walked into this building and never walked out, and the police have stopped looking. If she is still inside, then the doors must stay open and the lights must stay on. Play the announcements. Every night.\n\nShe always loved closing time. The empty halls. The music. She used to say the mall was [i]hers[/i] after hours.\n\n— A. Halvorsen, 1991"],
	"dale2": ["Night log, left on the empty pedestal", "2:40 AM.\n\nThe Iris figure is gone from the window again. Just the stand left.\n\nI think I get it now. She doesn't hate us. She's lonely. Every guard who stays past closing — she wants to keep. Make them part of the display.\n\nI'm going to go find her. If I'm not at the desk in the morning, check the windows.\n\n— D."],
	"rule2": ["Taped to the inside of the shutter", "You came back. Good. Listen.\n\nShe's different tonight. The power is on, and she knows the lights now.\n\nWhen the lights are ON, nothing moves. Not her. Not any of them.\n\nWhen they go OUT, she comes. Your beam still holds her in the dark.\n\nDale is in the department store, east end. The grille is open. I don't know who opened it.\n\n— R. Okafor"],
	"dale3": ["Cassette in Dale's shirt pocket (transcribed)", "...if anybody finds this.\n\nI found where she keeps them. The department store. Every one of these figures was a guard once. I recognise the shoes.\n\nShe isn't cruel. She just doesn't want to be alone at closing. Her father kept the doors open for her and she thinks that means somebody has to stay.\n\nI'm so tired. I'm going to stand still for a while. It's warm here. It's bright.\n\nWhoever you are: don't let her see you leave.\n\n[b]Run.[/b]"],
}
const NIGHT1 := ["dale1", "lumen", "poster", "janitor", "father", "dale2"]

const PHONE_LINES := [
	"Hi. Are you the new one? Daddy says nobody is allowed to leave before closing.",
	"You keep pointing that light at me. It's rude. I'm right here, you know. Closer than the phone.",
	"Dale answered too. He's in the window now. He looks so happy. Turn around.",
]
const AMBIENT_PA := [
	"The time is two... thirteen. The time is two... thirteen.",
	"A young lady is waiting for you at the atrium window. She says she has been waiting a long time.",
	"Will the guard on duty please stop looking away.",
	"Lost and found: one security badge. The name on it is Dale.",
	"Closing time is the best time. Everyone gets to stay.",
]
const ENDINGS := {
	"dale": ["CLOSING TIME", ["The shutter groans up. Cold air. Sodium lights humming over an empty parking lot.", "Behind you, the shutter rattles back down on its own.", "At 7:00 AM the demolition foreman does the final walkthrough and counts the display figures for the salvage sheet.", "Thirty-one. Thirty-two. Thirty-three.", "The new one stands in the atrium window, beside the girl in the red dress. It wears a security uniform. The name tag reads DALE.", "Both of them are facing the doors."]],
	"rest": ["CLOSED FOR GOOD", ["You leave her letters on the pedestal: the work order, the poster, her father's letter, the janitor's count, Dale's logs.", "From the doors you look back. She is standing on it again, hands folded, facing the parking lot.", "The music box plays one last slow phrase and stops.", "In the morning the crew finds thirty-two figures and an empty security desk. Someone has taped a card to the pedestal in the atrium window.", "It says CLOSED."]],
	"night2": ["LIGHTS OUT", ["You don't stop running until the parking lot. Dale's cassette is still in your hand.", "At dawn the wrecking ball takes the east wall first. Halvorsen & Co. comes down in one long breath of dust.", "When it clears, the salvage crew counts the figures in the rubble.", "Thirty-four.", "The newest one is holding a flashlight. It's still switched on."]],
}
const INTRO := {
	1: ["October 31st. 2:13 AM.", "The Halvorsen Galleria has been closed for twenty years. In the morning, they tear it down.", "You took the last night shift because it paid double and nothing ever happens here.", "The lights are still on. The music is still playing. Nobody has told the building it's dead.", "Clock in at the security office. Relieve Dale. Easy money."],
	2: ["November 1st. 11:40 PM.", "The demolition was postponed. Something about the wiring: the meter has been running all day, and nobody turned it on.", "Dale's wife has called the security company four times.", "You still have his keys."],
}
