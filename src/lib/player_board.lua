-- Player Board: a text field on the gold House banner for the house's name,
-- the three scripting zones over its sections, kept on the board when it
-- moves, and a readout over each section totalling the coins / power in it.
-- The name and the zones are saved with the object, so they survive reloads.
-- Shared by every Player Board; each one's file in src/player_boards just
-- includes this.
--
-- Each board owns its own zones: a zone's memo holds its board's GUID. A copy
-- of a board starts out pointing at the original's zones, finds them owned by
-- another board, and spawns its own (same size) instead.
--
-- For other objects: board.call("getVote") returns
--   {color = "Green", vote = "AYE" | "NAY" | "PASS" | nil, power = 3}
-- color is the board's GM Notes, vote the tag on the card in the card zone,
-- power the Power committed alongside it. The same values sit in the globals
-- boardColor, vote and votePower for getVar, refreshed on every zone change.

-- Local coordinates on the 2400x928 board image (generation/player_board.py): the
-- image height spans z -1..1 (464 px per unit), +z is down. The banner is
-- y 40-160 px, x 0-1720 px (it stops short of the token slots, top right);
-- the field starts a word-gap after the printed "HOUSE" label (~360 px) and
-- ends just inside the band (~1690 px). Input width runs ~1.04 per image px.
-- z sits a little below the band's centre (-0.784), which lines the text up
-- with the label rather than floating above it.
local NAME_POS = {-0.377, 0.1, -0.764}
local NAME_WIDTH, NAME_HEIGHT, NAME_FONT = 1380, 120, 80
local WHITE = {1, 1, 1, 100}
local PLACEHOLDER = {0.45, 0.45, 0.45, 100}
local CLEAR = {0, 0, 0, 0}
local NAME_INPUT = 0   -- the board's only input

-- Section readouts: one line just inside the sections' top edge (y 200 px),
-- each centred on its section. Sections are 864 / 512 / 864 px wide with
-- 40 px gaps, so their centres are 728 px either side of the image centre.
local READOUT_X = {coins = -1.569, card = 0, power = 1.569}
local READOUT_Z = -0.6
local READOUT_FONT = 50
local READOUT_INK = {1, 1, 1}

--[[ What each zone totals: objects carrying the tag, each worth the number in
its GM Notes (1-100). A stack counts every coin in it. The card zone totals
the Power played with the vote card. ]]
TALLY_TAGS = {coins = "Gold", card = "Power", power = "Power"}
VOTE_TAGS = {"AYE", "NAY", "PASS"}

--[[ Zones that follow the board. TTS has no parenting, so each zone's offset
is stored in board-local units and the zone is put back with positionToWorld
whenever the board comes to rest.

CAPTURE holds WORLD positions read off the table, verbatim. To re-capture after
moving a zone by hand, paste the new positions here and push without turning
the board in between: a changed CAPTURE forces a fresh calibration, measured
against the board's rotation at that moment. ]]
CAPTURE = {
	board = {0.00, 1.47, -42.39},
	zones = {
		coins = {-5.31, 2.59, -42.99},
		card = {0.00, 2.59, -42.99},
		power = {5.35, 2.59, -42.99},
	},
}
ZONE_ROLES = {"coins", "card", "power"}

-- Zone GUIDs by role. Leave blank to have calibration find the scripting
-- zone sitting at the CAPTURE position; the GUID it finds is saved.
ZONE_GUIDS = {coins = "", card = "", power = ""}
FIND_TOLERANCE = 0.1   -- world units between a zone and its CAPTURE position

SETTLE_SECONDS = 1.25  -- onObjectDrop fires mid-air; wait for the board to land

--[[ Claiming Moderator: a card tagged MOD placed in the card zone announces
the bid, then waits MOD_CLAIM_SECONDS so the player can change their mind.
Taking the card out of the zone in that window withdraws the bid. If it is
still there afterwards, the claim stands: one 1-Gold coin is minted into the
coins zone, cloned out of the source bag (the original is put back so the bag
keeps its stock, as the Change Converter and Resource Track do), and every MOD
card still in a hand is turned face-down. Once per placement: the card has to
leave the zone before it can claim again, so nudging it in place doesn't. ]]
MOD_TAG = "MOD"
MOD_COIN_VALUE = 1
MOD_CLAIM_SECONDS = 3
MOD_FACE_DOWN = {0, 180, 180}
SOURCE_BAG_GUID = "f0d3ab"
MOD_REST_TIMEOUT = 5   -- seconds to wait for a dropped card to come to rest
-- MOD card GUID -> {timer = Wait id} while the bid is pending, or "claimed".
modBids = {}

houseName = ""
offsets = {}     -- board-local zone positions, by role
zoneGuids = {}   -- resolved zone GUIDs, by role
zoneScales = {}  -- zone sizes by role, for spawning a copy's own zones
signature = nil  -- the CAPTURE these offsets were measured from
settleTimer = nil

-- Read by other objects; see getVote().
boardColor = ""
vote = nil
votePower = 0

function onLoad(saved_data)
	local data = saved_data ~= "" and JSON.decode(saved_data) or {}
	houseName = data.houseName or ""
	zoneScales = data.zoneScales or {}

	if data.signature == captureSignature() and data.offsets then
		offsets, zoneGuids, signature = data.offsets, data.zoneGuids or {}, data.signature
	else
		calibrate()
	end
	for _, role in ipairs(ZONE_ROLES) do
		if ZONE_GUIDS[role] ~= "" then zoneGuids[role] = ZONE_GUIDS[role] end
		claimZone(role)
	end
	repositionZones()

	-- A button with width and height 0 is invisible but keeps its label; a
	-- transparent face would hide the label too. Created in ZONE_ROLES order,
	-- so a role's button index is its position there, less one.
	for _, role in ipairs(ZONE_ROLES) do
		self.createButton({
			click_function = "noop", function_owner = self, label = "",
			position = {READOUT_X[role], 0.1, READOUT_Z}, width = 0, height = 0,
			font_size = READOUT_FONT, font_color = READOUT_INK,
		})
	end
	refreshTallies()

	-- The label is TTS's placeholder, shown while the field is empty. It is drawn
	-- in the font colour, so the font turns grey while there is no name.
	self.createInput({
		input_function = "onNameEdit", function_owner = self,
		value = houseName, label = "House Name", tooltip = "House Name",
		alignment = 2, validation = 1, tab = 1,
		position = NAME_POS, width = NAME_WIDTH, height = NAME_HEIGHT, font_size = NAME_FONT,
		font_color = nameColor(houseName), color = CLEAR,
	})
end

function onSave()
	return JSON.encode({
		houseName = houseName, offsets = offsets, zoneGuids = zoneGuids,
		zoneScales = zoneScales, signature = signature,
	})
end

-- Deleting a board (or bagging it) takes its zones with it; a board taken
-- back out spawns fresh ones.
function onDestroy()
	for _, role in ipairs(ZONE_ROLES) do
		local zone = zoneFor(role)
		if zone and not zone.isDestroyed() then zone.destruct() end
	end
end

function nameColor(name)
	return name == "" and PLACEHOLDER or WHITE
end

--[[ Recolour only once the field loses focus (selected == false). editInput
rebuilds the field from its stored value, so calling it mid-typing -- as the
first letter turns the grey placeholder white -- threw that letter away. ]]
function onNameEdit(_, _, value, selected)
	houseName = value
	if not selected then
		self.editInput({index = NAME_INPUT, value = value, font_color = nameColor(value)})
	end
end

-- A fingerprint of CAPTURE, so editing it forces a fresh calibration.
function captureSignature()
	local parts = {}
	local function add(p)
		for _, v in ipairs(p) do table.insert(parts, string.format("%.3f", v)) end
	end
	add(CAPTURE.board)
	for _, role in ipairs(ZONE_ROLES) do add(CAPTURE.zones[role]) end
	return table.concat(parts, ",")
end

--[[ Measure each zone's offset against the board's current transform.

The offset is taken from CAPTURE's board position, so only the board's
rotation has to match capture time, not its position. positionToLocal folds in
the board's scale and rotation. ]]
function calibrate()
	local origin = self.getPosition()
	local b = CAPTURE.board
	offsets, zoneGuids = {}, {}
	for _, role in ipairs(ZONE_ROLES) do
		local w = CAPTURE.zones[role]
		local p = self.positionToLocal(origin + Vector(w[1] - b[1], w[2] - b[2], w[3] - b[3]))
		offsets[role] = {p.x, p.y, p.z}
		zoneGuids[role] = findZoneAt(Vector(w[1], w[2], w[3]))
	end
	signature = captureSignature()
end

-- GUID of the scripting zone at a world position, or nil.
function findZoneAt(pos)
	for _, obj in ipairs(getObjects()) do
		if obj.type == "Scripting" and (obj.getPosition() - pos):magnitude() <= FIND_TOLERANCE then
			return obj.getGUID()
		end
	end
	return nil
end

function zoneFor(role)
	local guid = zoneGuids[role]
	return guid and getObjectFromGUID(guid) or nil
end

--[[ Make zoneGuids[role] a zone this board owns. An unowned zone (memo blank)
is claimed; one owned by another board -- what a copy inherits from the board
it was copied from -- is left alone and a new zone of the same size spawned on
this board instead. Boards load one at a time, so the first to reach an
unowned zone gets it. ]]
function claimZone(role)
	local me = self.getGUID()
	local zone = zoneFor(role)
	if zone then
		local s = zone.getScale()
		zoneScales[role] = {s.x, s.y, s.z}
		if zone.memo == nil or zone.memo == "" then zone.memo = me end
		if zone.memo == me then return end
	end

	zoneGuids[role] = nil
	if not zoneScales[role] then return end  -- nothing to size it from
	local spawned = spawnObject({
		type = "ScriptingTrigger",
		position = self.positionToWorld(offsets[role]),
		rotation = self.getRotation(),
		scale = zoneScales[role],
		callback_function = function(z) z.memo = me end,
	})
	zoneGuids[role] = spawned.getGUID()
end

function repositionZones()
	local missing = {}
	for _, role in ipairs(ZONE_ROLES) do
		local zone = zoneFor(role)
		if zone then
			zone.setPosition(self.positionToWorld(offsets[role]))
			zone.setRotation(self.getRotation())
		else
			table.insert(missing, role)
		end
	end
	if #missing > 0 then
		printToAll("Player Board: no scripting zone found for " .. table.concat(missing, ", ") ..
			" -- put its GUID in ZONE_GUIDS.", {1, 0.8, 0.3})
	end
end

-- A second drop inside the wait restarts it, so only the resting position counts.
function onObjectDrop(_, obj)
	if obj ~= self then
		if obj.hasTag(MOD_TAG) then onModCardDrop(obj) end
		return
	end
	if settleTimer then Wait.stop(settleTimer) end
	settleTimer = Wait.time(function()
		settleTimer = nil
		if not self.isDestroyed() then repositionZones() end
	end, SETTLE_SECONDS)
end


-- ---------------------------------------------------------------- tallies ---

function noop() end

-- Sum of GM Notes values over every object in the zone carrying `tag`.
function zoneTotal(zone, tag)
	local total = 0
	for _, obj in ipairs(zone.getObjects()) do
		if obj.hasTag(tag) then
			local value = tonumber((obj.getGMNotes():gsub("%s", ""))) or 0
			total = total + value * math.max(1, obj.getQuantity())
		end
	end
	return total
end

function refreshTallies()
	for i, role in ipairs(ZONE_ROLES) do
		local zone, tag = zoneFor(role), TALLY_TAGS[role]
		if zone and tag then
			self.editButton({index = i - 1, label = tostring(zoneTotal(zone, tag))})
		end
	end
	readVote()
end

-- The vote tag on whatever is in the card zone (the first one found), or nil.
function zoneVote(zone)
	for _, obj in ipairs(zone.getObjects()) do
		for _, tag in ipairs(VOTE_TAGS) do
			if obj.hasTag(tag) then return tag end
		end
	end
	return nil
end

function readVote()
	local zone = zoneFor("card")
	boardColor = self.getGMNotes():match("^%s*(.-)%s*$")
	vote = zone and zoneVote(zone) or nil
	votePower = zone and zoneTotal(zone, TALLY_TAGS.card) or 0
end

--[[ The board's vote, read fresh from the table, for other objects:
board.call("getVote"). The GM Notes are re-read on every call, so recolouring
the board takes effect without a reload. ]]
function getVote()
	readVote()
	return {color = boardColor, vote = vote, power = votePower}
end

-- Fires for every zone on the table, so only ours count. A frame of delay
-- lets a leaving object drop out of getObjects() before the zone is re-read.
function onObjectEnterZone(zone, _)
	if isOurZone(zone) then Wait.frames(refreshTallies, 1) end
end

function onObjectLeaveZone(zone, obj)
	if not isOurZone(zone) then return end
	if zone.getGUID() == zoneGuids.card and obj then withdrawBid(obj.getGUID()) end
	Wait.frames(refreshTallies, 1)
end

function isOurZone(zone)
	local guid = zone.getGUID()
	for _, role in ipairs(ZONE_ROLES) do
		if zoneGuids[role] == guid then return true end
	end
	return false
end


-- ------------------------------------------------------- moderator's coin ---

function isInZone(obj, zone)
	for _, z in ipairs(obj.getZones()) do
		if z == zone then return true end
	end
	return false
end

-- Who to name in chat: the board's colour (GM Notes), else the house name.
function claimantName()
	readVote()
	if boardColor ~= "" then return boardColor end
	return houseName ~= "" and houseName or self.getGUID()
end

-- The board's colour as an RGB for chat, white if it isn't a colour name.
function chatColor()
	local ok, c = pcall(function() return Color.fromString(boardColor) end)
	return (ok and c) or {1, 1, 1}
end

function announce(text)
	broadcastToAll(text, chatColor())
end

-- onObjectDrop fires mid-air, so wait for the card to land before checking
-- where it ended up.
function onModCardDrop(card)
	local guid = card.getGUID()
	Wait.condition(function()
		if card.isDestroyed() or modBids[guid] then return end
		local zone = zoneFor("card")
		if zone == nil or not isInZone(card, zone) then return end
		startBid(card)
	end, function() return card.isDestroyed() or card.resting end, MOD_REST_TIMEOUT)
end

function startBid(card)
	local guid = card.getGUID()
	announce(claimantName() .. " wants to be Moderator!")
	modBids[guid] = {timer = Wait.time(function()
		local zone = zoneFor("card")
		if card.isDestroyed() or zone == nil or not isInZone(card, zone) then
			return withdrawBid(guid)
		end
		modBids[guid] = "claimed"
		claimModerator()
	end, MOD_CLAIM_SECONDS)}
end

-- The card left the zone: a pending bid is withdrawn (and announced); a
-- claimed one is just forgotten, so placing the card again bids afresh.
function withdrawBid(guid)
	local bid = modBids[guid]
	modBids[guid] = nil
	if type(bid) == "table" then
		Wait.stop(bid.timer)
		announce(claimantName() .. " no longer wants to be Moderator...")
	end
end

function claimModerator()
	announce(claimantName() .. " claims the Moderator title, receiving 1 Coin! " ..
		"No one else can claim Moderator this round.")
	payModCoin()
	flipHandModCards()
end

-- Every MOD card in anyone's hand goes face-down.
function flipHandModCards()
	for _, hand in ipairs(Hands.getHands()) do
		for _, obj in ipairs(hand.getObjects()) do
			if obj.hasTag(MOD_TAG) then obj.setRotation(MOD_FACE_DOWN) end
		end
	end
end

-- The GUID of a 1-Gold coin in the source bag, or nil.
function findCoinInBag(bag)
	for _, entry in ipairs(bag.getObjects()) do
		local isGold = false
		for _, t in ipairs(entry.tags or {}) do
			if t == TALLY_TAGS.coins then isGold = true end
		end
		if isGold and tonumber(((entry.gm_notes or ""):gsub("%s", ""))) == MOD_COIN_VALUE then
			return entry.guid
		end
	end
	return nil
end

function payModCoin()
	local bag = getObjectFromGUID(SOURCE_BAG_GUID)
	local coins = zoneFor("coins")
	local guid = bag and findCoinInBag(bag)
	if guid == nil or coins == nil then
		printToAll("Player Board: couldn't pay " .. claimantName() .. "'s Moderator coin -- " ..
			(bag == nil and ("source bag " .. SOURCE_BAG_GUID .. " is missing") or
			 coins == nil and "no coins zone" or "no 1-Gold coin in the source bag") .. ".", {1, 0.8, 0.3})
		return
	end

	local target = coins.getPosition() + Vector(0, 1, 0)
	local original = bag.takeObject({guid = guid, smooth = false, position = bag.getPosition() + Vector(0, 3, 0)})
	Wait.condition(function()
		original.clone({position = target, snap_to_grid = false})
		Wait.frames(function() bag.putObject(original) end, 2)
	end, function() return original ~= nil and not original.spawning end)
end
