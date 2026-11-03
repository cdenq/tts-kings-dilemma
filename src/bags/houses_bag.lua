-- tts: 868f1a
-- Houses bag: a Cleanup button on its right and a Shuffle Resources button on
-- its left. Cleanup sweeps the Dilemma and Trigger Card zones into their bags,
-- puts every Cleanup-tagged piece back where it starts, gathers the Secret
-- Agendas, and deals out the starting coins and Power. Shuffle Resources sets
-- the five resource markers to random sides and reports their sides.

-- In order: influence, wealth, morale, welfare, knowledge.
local MARKERS = {
	{name = "Influence", guid = "29b725"},
	{name = "Wealth",    guid = "c717a0"},
	{name = "Morale",    guid = "0f25a8"},
	{name = "Welfare",   guid = "1ce1ca"},
	{name = "Knowledge", guid = "2071f2"},
}

-- Button x offset from the bag's center. Positive x is the bag's right side
-- and negative x its left.
local BUTTON_X = 2.8

function onLoad()
	self.createButton({
		click_function = "cleanup", function_owner = self,
		label = "Cleanup", position = {BUTTON_X, 0.5, 0},
		tooltip = "Cleans up the game for the next session.",
		width = 900, height = 300, font_size = 150,
	})
	self.createButton({
		click_function = "randomizeMarkers", function_owner = self,
		label = "Shuffle Resources", position = {-BUTTON_X, 0.5, 0},
		tooltip = "Randomly determines the starting side of the 5 resources.",
		width = 1200, height = 300, font_size = 150,
	})
end

-- Pieces Cleanup puts back.
local CLEANUP_TAG = "Cleanup"

-- Vote cards go back into their hand instantly, with no move transition.
local VOTE_CARD_TAGS = {"AYE", "NAY", "PASS", "MOD"}

local function isVoteCard(piece)
	for _, tag in ipairs(VOTE_CARD_TAGS) do
		if piece.hasTag(tag) then return true end
	end
	return false
end

-- Secret Agenda cards are gathered back into their bag rather than laid out.
local SECRET_AGENDA_TAG = "Secret Agenda"
local SECRET_AGENDA_BAG = "4f0315"

-- Starting spot of every piece tagged Cleanup, keyed by GUID and read from a save.
-- Hard-coded on purpose: the pieces move during play, so their live positions
-- are exactly what Cleanup must not trust. Rotation z 180 means flipped.
local HOME = {
	-- Open Agendas, row of (+) then (-)
	{guid = "912b84", pos = {-6.70, 1.50, 21.37}, rot = {0, 180, 0}}, -- Influence Open Agenda (+)
	{guid = "c1b683", pos = {-5.36, 1.50, 21.37}, rot = {0, 180, 0}}, -- Wealth Open Agenda (+)
	{guid = "378b56", pos = {-4.02, 1.49, 21.37}, rot = {0, 180, 0}}, -- Morale Open Agenda (+)
	{guid = "c9e9c5", pos = {-2.67, 1.49, 21.37}, rot = {0, 180, 0}}, -- Welfare Open Agenda (+)
	{guid = "1fc3bc", pos = {-1.33, 1.49, 21.37}, rot = {0, 180, 0}}, -- Knowledge Open Agenda (+)
	{guid = "c0e4f7", pos = {1.33, 1.49, 21.37}, rot = {0, 180, 0}}, -- Influence Open Agenda (-)
	{guid = "173fdb", pos = {2.67, 1.48, 21.37}, rot = {0, 180, 0}}, -- Wealth Open Agenda (-)
	{guid = "7e8950", pos = {4.02, 1.48, 21.37}, rot = {0, 180, 0}}, -- Morale Open Agenda (-)
	{guid = "998483", pos = {5.36, 1.48, 21.37}, rot = {0, 180, 0}}, -- Welfare Open Agenda (-)
	{guid = "849476", pos = {6.70, 1.48, 21.37}, rot = {0, 180, 0}}, -- Knowledge Open Agenda (-)
	-- Tokens, upper row
	{guid = "0de528", pos = {-14.43, 1.56, 16.22}, rot = {0, 180, 0}},
	{guid = "b483bc", pos = {-13.04, 1.56, 16.22}, rot = {0, 180, 0}},
	{guid = "39fa39", pos = {-11.65, 1.56, 16.22}, rot = {0, 180, 0}},
	{guid = "c46c3d", pos = {-10.25, 1.56, 16.22}, rot = {0, 180, 0}},
	{guid = "d87076", pos = {-8.86, 1.56, 16.22}, rot = {0, 180, 0}},
	-- Tokens, lower row
	{guid = "407b0b", pos = {-14.54, 1.56, 14.63}, rot = {0, 180, 0}},
	{guid = "9cbc1b", pos = {-13.13, 1.56, 14.63}, rot = {0, 180, 0}},
	{guid = "1b8efc", pos = {-11.72, 1.56, 14.63}, rot = {0, 180, 0}},
	{guid = "f1ec01", pos = {-10.31, 1.56, 14.63}, rot = {0, 180, 0}},
	{guid = "9a4b13", pos = {-8.90, 1.56, 14.63}, rot = {0, 180, 0}},
	-- Resource markers and the tile beside them
	{guid = "e19593", pos = {-4.82, 2.09, -5.03}, rot = {0, 180, 180}},
	{guid = "29b725", pos = {-2.71, 1.97, -4.85}, rot = {0, 180, 0}}, -- Influence
	{guid = "c717a0", pos = {-1.38, 1.97, -4.88}, rot = {0, 180, 0}}, -- Wealth
	{guid = "0f25a8", pos = {-0.02, 1.97, -4.89}, rot = {0, 180, 0}}, -- Morale
	{guid = "1ce1ca", pos = {1.33, 1.97, -4.87}, rot = {0, 180, 0}}, -- Welfare
	{guid = "2071f2", pos = {2.69, 1.97, -4.85}, rot = {0, 180, 0}}, -- Knowledge
	-- Dilemma outcome tiles (+), unflipped
	{guid = "781563", pos = {-3.22, 1.48, -24.79}, rot = {0, 180, 0}}, -- Influence (+)
	{guid = "0c3bde", pos = {-1.93, 1.48, -24.79}, rot = {0, 180, 0}}, -- Wealth (+)
	{guid = "4e0fc2", pos = {-0.63, 1.48, -24.79}, rot = {0, 180, 0}}, -- Morale (+)
	{guid = "4753ac", pos = {0.67, 1.47, -24.79}, rot = {0, 180, 0}}, -- Welfare (+)
	{guid = "61a6d7", pos = {1.96, 1.47, -24.79}, rot = {0, 180, 0}}, -- Knowledge (+)
	{guid = "be9e90", pos = {3.26, 1.47, -24.79}, rot = {0, 180, 0}}, -- Chronicle Sticker (+)
	-- Dilemma outcome tiles (-), flipped
	{guid = "12fb46", pos = {-3.23, 1.59, -26.17}, rot = {0, 180, 180}}, -- Influence (-)
	{guid = "0cec60", pos = {-1.94, 1.59, -26.17}, rot = {0, 180, 180}}, -- Wealth (-)
	{guid = "904fdc", pos = {-0.64, 1.59, -26.17}, rot = {0, 180, 180}}, -- Morale (-)
	{guid = "ee4ecc", pos = {0.66, 1.59, -26.17}, rot = {0, 180, 180}}, -- Welfare (-)
	{guid = "812dfe", pos = {1.95, 1.59, -26.17}, rot = {0, 180, 180}}, -- Knowledge (-)
	{guid = "a1eb01", pos = {3.26, 1.58, -26.17}, rot = {0, 180, 180}}, -- Chronicle Sticker (-)
	-- Leader and Moderator
	{guid = "f377c8", pos = {-6.00, 1.58, -26.00}, rot = {0, 180, 0}}, -- Moderator
	{guid = "f11d75", pos = {6.00, 1.57, -26.00}, rot = {0, 180, 0}}, -- Leader
	-- Vote cards in the five hands (White, Red, Yellow, Green, Blue), each
	-- NAY, PASS (Mod), PASS (Power), AYE
	{guid = "c936cf", pos = {-50.25, 3.51, -55.88}, rot = {0, 180, 0}}, -- NAY
	{guid = "fada91", pos = {-46.75, 3.61, -55.88}, rot = {0, 180, 0}}, -- PASS (Mod)
	{guid = "e1d42f", pos = {-43.25, 3.71, -55.88}, rot = {0, 180, 0}}, -- PASS (Power)
	{guid = "a5db84", pos = {-39.75, 3.81, -55.88}, rot = {0, 180, 0}}, -- AYE
	{guid = "1aab55", pos = {-27.75, 3.51, -55.88}, rot = {0, 180, 0}}, -- NAY
	{guid = "708848", pos = {-24.25, 3.61, -55.88}, rot = {0, 180, 0}}, -- PASS (Mod)
	{guid = "326c1c", pos = {-20.75, 3.71, -55.88}, rot = {0, 180, 0}}, -- PASS (Power)
	{guid = "a8c85b", pos = {-17.25, 3.81, -55.88}, rot = {0, 180, 0}}, -- AYE
	{guid = "775577", pos = {-5.28, 3.51, -55.83}, rot = {0, 180, 0}}, -- NAY
	{guid = "769226", pos = {-1.79, 3.61, -55.86}, rot = {0, 180, 0}}, -- PASS (Mod)
	{guid = "89c7a3", pos = {1.71, 3.71, -55.90}, rot = {0, 180, 0}}, -- PASS (Power)
	{guid = "59cba4", pos = {5.21, 3.81, -55.93}, rot = {0, 180, 0}}, -- AYE
	{guid = "9296ca", pos = {17.25, 3.51, -55.88}, rot = {0, 180, 0}}, -- NAY
	{guid = "8db5da", pos = {20.75, 3.61, -55.88}, rot = {0, 180, 0}}, -- PASS (Mod)
	{guid = "58d085", pos = {24.25, 3.71, -55.88}, rot = {0, 180, 0}}, -- PASS (Power)
	{guid = "75d97c", pos = {27.75, 3.81, -55.88}, rot = {0, 180, 0}}, -- AYE
	{guid = "961c20", pos = {39.75, 3.51, -55.88}, rot = {0, 180, 0}}, -- NAY
	{guid = "ff8ca6", pos = {43.25, 3.61, -55.88}, rot = {0, 180, 0}}, -- PASS (Mod)
	{guid = "738b58", pos = {46.75, 3.71, -55.88}, rot = {0, 180, 0}}, -- PASS (Power)
	{guid = "3b638a", pos = {50.25, 3.81, -55.88}, rot = {0, 180, 0}}, -- AYE
}

-- Put every Secret Agenda card back in its bag, and wipe the bag's draft
-- memory so its next button click starts a new draft.
local function collectSecretAgendas()
	local bag = getObjectFromGUID(SECRET_AGENDA_BAG)
	if bag == nil then
		printToAll("Cleanup: Secret Agenda bag " .. SECRET_AGENDA_BAG .. " not found.", {1, 0.5, 0.5})
		return
	end
	for _, card in ipairs(getObjectsWithTag(SECRET_AGENDA_TAG)) do
		bag.putObject(card)
	end
	bag.call("resetDraft")
end

-- Zones whose contents Cleanup sweeps into a bag, in this order.
local ZONE_TO_BAG = {
	{zone = "09f286", bag = "97b605"}, -- Dilemma Zone -> Past Dilemmas
	{zone = "f4654b", bag = "20fcee"}, -- Trigger Card Zone -> Dilemma Deck
}

-- Put everything in each zone into its bag. Locked objects (boards, the table)
-- and Cleanup-tagged pieces (which go back to HOME instead) are left alone.
local function sweepZones()
	for _, zb in ipairs(ZONE_TO_BAG) do
		local zone, bag = getObjectFromGUID(zb.zone), getObjectFromGUID(zb.bag)
		if zone == nil or bag == nil then
			printToAll("Cleanup: zone " .. zb.zone .. " or bag " .. zb.bag .. " not found.", {1, 0.5, 0.5})
		else
			for _, obj in ipairs(zone.getObjects()) do
				if obj ~= bag and not obj.getLock() and not obj.hasTag(CLEANUP_TAG) then
					bag.putObject(obj)
				end
			end
		end
	end
end

-- ------------------------------------------------- starting coins / Power ---

-- Player Boards are found by name and asked for their own zones (each board
-- saves its zone GUIDs in zoneGuids; see lib/player_board.lua), so no board
-- GUID is written here. A copied or replaced board is picked up as-is.
local PLAYER_BOARD_NAME = "Player Board"
local BOARD_ZONES = {"coins", "card", "power"}
local GOLD_TAG, POWER_TAG = "Gold", "Power"

-- New pieces are cloned out of the Change bag (as the Change Converter and
-- Resource Track do) and the original put back, so the bag keeps its stock.
local SOURCE_BAG = "f0d3ab"
local BALANCE_ZONE = "0a1f64"

--[[ Starting pieces, as {tag, value, dx, dz}: each piece's spot measured from
the centre of its zone, in world units with the board at rotation y 180 (how
every board sits). Read off a save of the table set up by hand. ]]
local BOARD_COINS = {
	{GOLD_TAG, 5, -2.4, -1.7},
	{GOLD_TAG, 1, -1.4, -1.7},
	{GOLD_TAG, 1, -2.4, -0.7},
	{GOLD_TAG, 1, -1.4, -0.7},
	{GOLD_TAG, 1, -2.4, 0.3},
	{GOLD_TAG, 1, -1.4, 0.3},
}
local BOARD_POWER = {
	{POWER_TAG, 5, 0.8, -0.2},
	{POWER_TAG, 1, 2.2, -0.2},
	{POWER_TAG, 1, 0.8, -1.6},
	{POWER_TAG, 1, 2.2, -1.6},
}
-- The Balance zone isn't turned, so these are plain world offsets.
local BALANCE_START = {
	{POWER_TAG, 1, -1.24, -0.64},
	{POWER_TAG, 1, 0, -0.64},
	{POWER_TAG, 1, 1.24, -0.64},
}
local LAYOUT_ROT_Y = 180
local DROP_HEIGHT = 0.3   -- above the zone's centre, so pieces settle onto the board

local function hasAnyTag(obj, tags)
	for _, t in ipairs(tags) do
		if obj.hasTag(t) then return true end
	end
	return false
end

-- Destroy every piece (or stack) in the zone carrying one of tags.
local function clearZone(zone, tags)
	for _, obj in ipairs(zone.getObjects()) do
		if hasAnyTag(obj, tags) then obj.destruct() end
	end
end

-- World spot for a layout offset, turned with the zone if it has been turned.
local function spotIn(zone, dx, dz, layoutRotY)
	local p = zone.getPosition()
	local a = math.rad(zone.getRotation().y - layoutRotY)
	local x = dx * math.cos(a) + dz * math.sin(a)
	local z = -dx * math.sin(a) + dz * math.cos(a)
	return {p.x + x, p.y + DROP_HEIGHT, p.z + z}
end

local function boardZone(board, role)
	local guids = board.getTable("zoneGuids")
	return guids and guids[role] and getObjectFromGUID(guids[role]) or nil
end

-- The GUID of a piece in the bag with tag and face value (its GM Notes), or nil.
local function findInBag(bag, tag, value)
	for _, entry in ipairs(bag.getObjects()) do
		for _, t in ipairs(entry.tags or {}) do
			if t == tag and tonumber(((entry.gm_notes or ""):gsub("%s", ""))) == value then
				return entry.guid
			end
		end
	end
	return nil
end

--[[ Clone one piece of each kind out of the bag to all its spots. Kinds go
one at a time: takeObject is async, and many at once against one bag drops
pieces. ]]
local function mintAll(bag, kinds, i)
	i = i or 1
	local kind = kinds[i]
	if kind == nil then return end
	local guid = findInBag(bag, kind.tag, kind.value)
	if guid == nil then
		printToAll("Cleanup: no " .. kind.value .. "-" .. kind.tag .. " piece in the Change bag.", {1, 0.8, 0.3})
		return mintAll(bag, kinds, i + 1)
	end
	local original = bag.takeObject({guid = guid, smooth = false, position = bag.getPosition() + Vector(0, 3, 0)})
	Wait.condition(function()
		for _, pos in ipairs(kind.spots) do
			original.clone({position = pos, snap_to_grid = false})
		end
		Wait.frames(function()
			bag.putObject(original)
			Wait.frames(function() mintAll(bag, kinds, i + 1) end, 2)
		end, 2)
	end, function() return original ~= nil and not original.spawning end)
end

--[[ Every Player Board loses all its Gold and Power (in all three zones) and
the Balance its Power; then each board gets 5 1-Gold and a 5-Gold in its
coins zone and 3 1-Power and a 5-Power in its power zone, and the Balance
3 1-Power. ]]
local function resetResources()
	local kinds, byKey = {}, {}
	local function add(tag, value, pos)
		local key = tag .. value
		if not byKey[key] then
			byKey[key] = {tag = tag, value = value, spots = {}}
			table.insert(kinds, byKey[key])
		end
		table.insert(byKey[key].spots, pos)
	end
	local function lay(zone, layout, rotY)
		for _, p in ipairs(layout) do add(p[1], p[2], spotIn(zone, p[3], p[4], rotY)) end
	end

	local boards = 0
	for _, board in ipairs(getObjects()) do
		if board.getName() == PLAYER_BOARD_NAME then
			boards = boards + 1
			for _, role in ipairs(BOARD_ZONES) do
				local zone = boardZone(board, role)
				if zone then clearZone(zone, {GOLD_TAG, POWER_TAG}) end
			end
			local coins, power = boardZone(board, "coins"), boardZone(board, "power")
			if coins then lay(coins, BOARD_COINS, LAYOUT_ROT_Y) end
			if power then lay(power, BOARD_POWER, LAYOUT_ROT_Y) end
			if coins == nil or power == nil then
				printToAll("Cleanup: a Player Board (" .. board.getGMNotes() .. ") has no " ..
					(coins == nil and "coins" or "power") .. " zone; its pieces weren't dealt.", {1, 0.8, 0.3})
			end
		end
	end
	if boards == 0 then
		printToAll("Cleanup: no Player Boards found.", {1, 0.8, 0.3})
	end

	local balance = getObjectFromGUID(BALANCE_ZONE)
	if balance then
		clearZone(balance, {POWER_TAG})
		lay(balance, BALANCE_START, 0)
	else
		printToAll("Cleanup: Balance zone " .. BALANCE_ZONE .. " not found.", {1, 0.5, 0.5})
	end

	local bag = getObjectFromGUID(SOURCE_BAG)
	if bag == nil then
		printToAll("Cleanup: Change bag " .. SOURCE_BAG .. " not found; no coins or Power dealt.", {1, 0.5, 0.5})
		return
	end
	-- A frame for the destroyed pieces to go before new ones land in the zones.
	Wait.frames(function() mintAll(bag, kinds) end, 1)
end

-- Move every Cleanup-tagged piece back to its spot in HOME. Reports tagged pieces
-- with no recorded spot, and recorded pieces not on the table (deleted, or
-- sitting inside a bag), rather than skipping either silently.
function cleanup(obj, color)
	sweepZones()

	local homeOf = {}
	for _, h in ipairs(HOME) do homeOf[h.guid] = h end

	local found, unknown, missing = {}, {}, {}
	for _, piece in ipairs(getObjectsWithTag(CLEANUP_TAG)) do
		local h = homeOf[piece.getGUID()]
		if h == nil then
			table.insert(unknown, piece.getName() ~= "" and piece.getName() or piece.getGUID())
		else
			found[h.guid] = true
			if isVoteCard(piece) then
				piece.setPosition(h.pos)
				piece.setRotation(h.rot)
			else
				piece.setPositionSmooth(h.pos, false, true)
				piece.setRotationSmooth(h.rot, false, true)
			end
		end
	end
	for _, h in ipairs(HOME) do
		if not found[h.guid] then table.insert(missing, h.guid) end
	end

	if #unknown > 0 then
		printToAll("Cleanup: no starting spot for " .. table.concat(unknown, ", "), {1, 0.8, 0.3})
	end
	if #missing > 0 then
		printToAll("Cleanup: not on the table: " .. table.concat(missing, ", "), {1, 0.5, 0.5})
	end

	collectSecretAgendas()
	resetResources()
end

-- How high a marker rises before flipping over.
local LIFT_HEIGHT = 2

local function doneMoving(marker)
	return function() return not marker.isSmoothMoving() end
end

-- Lift the marker, turn it to rot in the air, then set it back down.
-- It's locked meanwhile so gravity doesn't pull it out of the air.
local function flipInAir(marker, rot)
	local pos = marker.getPosition()
	local wasLocked = marker.getLock()
	marker.setLock(true)
	marker.setPositionSmooth({pos.x, pos.y + LIFT_HEIGHT, pos.z}, false, true)
	Wait.condition(function()
		marker.setRotationSmooth(rot, false, true)
		Wait.condition(function()
			marker.setPositionSmooth(pos, false, true)
			Wait.condition(function() marker.setLock(wasLocked) end, doneMoving(marker), 3)
		end, doneMoving(marker), 3)
	end, doneMoving(marker), 3)
end

-- Rotation z near 0 (or 360) is the increasing side; near 180 is decreasing.
local function isIncreasing(z)
	z = z % 360
	return z < 90 or z > 270
end

function randomizeMarkers(obj, color)
	local sides = {}
	for _, m in ipairs(MARKERS) do
		local marker = getObjectFromGUID(m.guid)
		if marker == nil then
			table.insert(sides, m.name .. ": missing (" .. m.guid .. ")")
		else
			-- Set each marker straight to a random side (also squaring up any
			-- tilt), keeping its facing on the table. Only a change of side
			-- gets the lift-and-flip.
			local increasing = math.random() < 0.5
			local rot = marker.getRotation()
			local target = {0, rot.y, increasing and 0 or 180}
			if isIncreasing(rot.z) == increasing then
				marker.setRotationSmooth(target, false, true)
			else
				flipInAir(marker, target)
			end
			table.insert(sides, m.name .. ": " .. (increasing and "increasing" or "decreasing"))
		end
	end
	printToAll(table.concat(sides, ", "), {1, 1, 1})
end
