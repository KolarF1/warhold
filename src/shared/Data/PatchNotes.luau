--!strict
-- What changed, newest first, and what is coming (the owner, 2026-11-08: patch notes always on the main menu's right, the
-- roadmap a button in the same panel). Player-facing words: short lines, plain. Add a release at the top of RELEASES
-- with the version tools/publish.py gives it (Data/Version).
local PatchNotes = {}

export type Release = { version: string, date: string, title: string, lines: { string } }

PatchNotes.RELEASES = {
	{
		version = "0.9.10",
		date = "9 Nov 2026",
		title = "Join Us",
		lines = {
			"Join the game's community from the COMMUNITY row on the main menu, or from the Field Guide's credits.",
		},
	},
	{
		version = "0.9.8",
		date = "9 Nov 2026",
		title = "New Home",
		lines = {
			"The game's public source has moved to KolarF1/warhold on GitHub (named in the Field Guide's credits).",
		},
	},
	{
		version = "0.9.7",
		date = "9 Nov 2026",
		title = "Work in Progress",
		lines = {
			"Long and Quick wars are marked WIP: they are still being built and balanced, and may change.",
		},
	},
	{
		version = "0.9.6",
		date = "9 Nov 2026",
		title = "The Deep War",
		lines = {
			"New: Long and Quick wars (WAR on the solo menu). Classic wars are unchanged.",
			"Provinces: hold most of one and it pays taxes, feeds you and has building slots. A Provinces map mode shows them.",
			"Taxes, unrest and revolts, manpower and food. New buildings: Farm, Market, Barracks and Fort.",
			"Rulers with traits who age and die. Each age, three national ideas and a tech to choose.",
			"Wars need a reason. Peace deals: white peace, provinces, tribute or vassalage. Truces after peace.",
			"Armies: fronts today, levies, battles and sieges in the Middle Ages.",
			"Ambitions and prestige. When the clock runs out, the most prestige wins.",
			"Your Realm: the chip under the top bar or the R key.",
		},
	},
	{
		version = "0.9.5",
		date = "9 Nov 2026",
		title = "Home Ground",
		lines = {
			"Nations start in their own country.",
			"Bot players no longer start in Antarctica.",
			"The attack alarm sounds only when someone attacks you, not when a nation you attack fights back.",
			"The match's mode is shown under the top bar.",
			"New pictures: landing craft, and in medieval matches longships for landings, cogs for trade and wagons for carts.",
			"Right-click your own building to pull it down. Nothing is refunded.",
			"War College items no longer clip at the edge.",
		},
	},
	{
		version = "0.9.4",
		date = "9 Nov 2026",
		title = "Banners Fall",
		lines = {
			"Fixed: ships, warheads and trucks were invisible on the map.",
			"Real-world maps no longer have tribes.",
			"A centre-screen announcement when a player, a nation or a whole team falls.",
			"An alarm sounds when a new nation attacks you. Attack markers are larger.",
			"Multiplayer bots: more of them play smart, and at Hard.",
			"No landmarks in Antarctica.",
			"Shop buttons show their price immediately.",
			"Long nation names wrap instead of being cut off. War College subtitle shortened.",
		},
	},
	{
		version = "0.9.3",
		date = "9 Nov 2026",
		title = "Lay of the Land",
		lines = {
			"Hundreds more real nations and peoples on every real map and start date.",
			"Hills and mountains are harder to take. Bastions on high ground defend more.",
			"Antarctica is frozen waste: no building, half the troop cap.",
			"Banners can't be planted near another ruler or a landmark.",
			"The results screen stays until you return to camp. The Hardcore queue shows online.",
			"Medieval matches use medieval names and pictures for buildings, ships and siege shots.",
			"The bell for bad world events plays. The event countdown shows a description on hover.",
			"Shop prices load faster. The camera pans past the edge on narrow maps. Pact text no longer cuts off.",
		},
	},
	{
		version = "0.9.1",
		date = "8 Nov 2026",
		title = "Ages of History",
		lines = {
			"Start a war in 867, 1066, 1187 or 1241, with that year's real realms on every real-world map.",
			"The Middle Ages fight with siege and fire: Greek Fire, the Plague Catapult and the Trebuchet. Nothing flies, and gunpowder comes only in 1241.",
			"Many realms carry a strength from their history, like the Mongols' Horse Lords.",
			"Every country wears its own colours.",
			"Play Online opens the matchmaking screen, with Hardcore in its own queue.",
			"A fallen realm's gold is shared by everyone who took its land.",
			"New icons for Spoils, clearer warhead cards and world events, and many fixes.",
		},
	},
	{
		version = "0.9.0",
		date = "8 Nov 2026",
		title = "The Playtest Patch",
		lines = {
			"The top bar sits up top; the To Arms count, the Crown and world events have their own clean chips.",
			"Strongholds are Cities again, and Lighthouses stand on the coast.",
			"Teams start apart, and the right panel lists them.",
			"Online rivals fight harder.",
		},
	},
} :: { Release }

--- The roadmap: what is being built now, what comes next, what comes later.
PatchNotes.ROADMAP = {
	{
		title = "NOW",
		lines = {
			"Medieval pictures for buildings on the map",
			"Patterns in real materials: marble, bronze, stained glass",
			"Phone play, tested end to end",
		},
	},
	{
		title = "NEXT",
		lines = {
			"More start dates: 1453, 1618 and 1914",
			"New Standards for every age",
			"Sound for every age of the world",
		},
	},
	{
		title = "LATER",
		lines = {
			"Seasons with their own rewards",
			"Clan wars between warbands",
			"New invented worlds",
		},
	},
}

--- The newest release.
function PatchNotes.latest(): Release
	return PatchNotes.RELEASES[1]
end

return PatchNotes
