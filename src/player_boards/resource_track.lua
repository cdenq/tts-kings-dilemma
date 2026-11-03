-- tts: ade6bc
-- Resource Track: Draw Next / Draw Random buttons that deal the first or a
-- random card from the Dilemma Deck bag face up onto the dilemma spot; Draw
-- Next then turns into Conclude, which settles the vote and sets the card aside
-- (with an AYE / NAY pair for the Moderator on a tie); the AYE / NAY power
-- totals from every Player Board in the blue / red circles, and the Power on
-- the board in the power zone. Once a vote is settled, the Power in the
-- Balance is shared evenly among the players who passed, and then the Power in
-- every Player Board's card zone goes into the Balance. The button then turns
-- into Clean Up, which files the dilemma card into the first free resolved-card
-- slot and sends the cards in the card zones back to their players' hands.

local DILEMMA_BAG = "20fcee"
local DRAW_POS = {0.00, 1.93, -19.35}
local DRAW_ROT = {0.02, 180.00, 0.08}

-- Where Resolve moves the drawn card, flipped face down; which way it faces
-- shows which side won.
local RESOLVED_POS = {0.00, 3, -19.35}
local RESOLVED_ROT = {AYE = {0, 180, 180}, NAY = {0, 0, 180}}

-- Clean Up files the resolved card into the first empty slot, top to bottom,
-- in this scripting zone, turned a further CLEANUP_TURN degrees about y. With
-- every slot taken, it goes on top of whatever is in the last one.
local CLEANUP_ZONE = "09f286"
local CLEANUP_SLOTS = {
	{-7.91, 1.51, 6.35},
	{-7.95, 1.51, 1.90},
	{-7.99, 1.51, -2.48},
	{-8.05, 1.50, -6.96},
	{-8.04, 1.50, -11.36},
	{-8.09, 1.50, -15.80},
	{-8.08, 1.50, -20.42},
}
local CLEANUP_TURN = -90
-- A card or deck this close (x / z) to a slot is in it; slots are ~4.4 apart.
local SLOT_TOLERANCE = 1.5
-- How high above a slot (or the top of the pile in the last slot) to drop it.
local SLOT_DROP = 0.5

-- Scripting zone over the board's Power pool.
local POWER_ZONE = "0a1f64"
local POWER_TAG = "Power"

-- Paying out the Balance: the pieces already there are handed out where they
-- can be. Only when they can't make the shares exactly are some broken down,
-- smallest first, into new pieces cloned from the Change Converter's source
-- bag, split the way the Change Converter splits them (lib/change_converter.lua).
local SOURCE_BAG = "f0d3ab"
local POWER_DENOMS = {1, 5, 10}
local POWER_BREAKDOWN = {[10] = {[5] = 1, [1] = 5}, [5] = {[1] = 5}}
-- Payout pieces land in a grid centered on each zone, this high off the table.
local PAYOUT = {STEP = 0.9, PER_ROW = 4, DROP_Y = 3}

-- Every object with this name is asked for its vote (see lib/player_board.lua).
local PLAYER_BOARD_NAME = "Player Board"

-- Button spot in the track's own (unscaled) coordinates. The track's top face
-- is at y 0.052, and local z 1.99 lines up with DRAW_POS; x sets it to the side
-- of the drawn card rather than on top of it. Larger z is further down.
local BUTTON_POS = {0.42, 0.06, 1.74}

-- Draw Random, under the main button; shown only in the draw phase.
local DRAW_RANDOM_POS = {0.42, 0.06, 1.81}

-- Moderator tiebreak buttons, in place of Draw / Resolve: AYE over the blue
-- circle, NAY over the red.
local TIE_AYE_POS = {0.42, 0.06, 1.81}
local TIE_NAY_POS = {-0.42, 0.06, 1.81}

-- Vote totals shown over the centers of the red and blue circles, in the same
-- coordinates. Positive x is the blue circle's side.
local RED_TOTAL_POS = {-0.42, 0.06, 2}
local BLUE_TOTAL_POS = {0.42, 0.06, 2}

-- Power-in-the-pool readout, just below Draw Random.
local POWER_TOTAL_POS = {0, 0.06, 2.3}

-- The main button's look in each phase. In "tie" it's hidden and the
-- tiebreak buttons show instead.
local MAIN_LOOK = {
	draw = {label = "Draw Next", color = {0.2, 0.6, 0.2}, tooltip = "Draw the top Dilemma card in the bag."},
	resolve = {label = "Conclude", color = {0.2, 0.6, 0.2}, tooltip = "The side with more Power wins the dilemma."},
	cleanup = {label = "Clean Up", color = {0.2, 0.6, 0.2}, tooltip = "File the dilemma card and return the played cards to hands."},
}
local MAIN_SIZE = {width = 1100, height = 300}
local TIE_SIZE = {width = 600, height = 300}

-- Button indices, in the order onLoad creates them.
local DRAW_BUTTON = 0
local RED_TOTAL_BUTTON = 1
local BLUE_TOTAL_BUTTON = 2
local POWER_TOTAL_BUTTON = 3
local TIE_AYE_BUTTON = 4
local TIE_NAY_BUTTON = 5
local DRAW_RANDOM_BUTTON = 6

-- "draw", "resolve" (a card is out, waiting on the vote), "tie" (waiting
-- on the Moderator), "payout" (sharing out the Balance; no buttons) or
-- "cleanup" (vote settled, waiting on Clean Up), and the card that was drawn.
local phase = "draw"
local drawnGuid = nil
local refreshPending = false

function onLoad(saved)
	if saved ~= nil and saved ~= "" then
		local data = JSON.decode(saved)
		phase = data.phase or "draw"
		-- A payout cut short by a reload can't be picked back up; the vote is
		-- settled, though, so carry on to Clean Up.
		if phase == "payout" then phase = "cleanup" end
		drawnGuid = data.drawnGuid
	end

	-- The track is scaled up a lot; undo that so the buttons are a normal size.
	local s = self.getScale()
	local scale = {1 / s.x, 1 / s.y, 1 / s.z}
	self.createButton({
		click_function = "onMainClick", function_owner = self,
		label = "", position = BUTTON_POS, scale = scale,
		width = 0, height = 0, font_size = 150, font_color = {1, 1, 1},
	})

	-- Labels only: a button with no width or height has no background and
	-- can't be clicked, but still shows its label.
	for _, pos in ipairs({RED_TOTAL_POS, BLUE_TOTAL_POS}) do
		self.createButton({
			click_function = "noop", function_owner = self,
			label = "0", position = pos, scale = scale,
			width = 0, height = 0, font_size = 500,
			font_color = {1, 1, 1},
		})
	end
	self.createButton({
		click_function = "noop", function_owner = self,
		label = "0", position = POWER_TOTAL_POS, scale = scale,
		width = 0, height = 0, font_size = 450,
		font_color = {0, 0, 0},
	})

	-- Tiebreak buttons, hidden (no size, no label) until there's a tie.
	for _, b in ipairs({{"tieAye", TIE_AYE_POS}, {"tieNay", TIE_NAY_POS}}) do
		self.createButton({
			click_function = b[1], function_owner = self,
			label = "", position = b[2], scale = scale,
			width = 0, height = 0, font_size = 150, font_color = {1, 1, 1},
		})
	end

	-- Draw Random, hidden outside the draw phase.
	self.createButton({
		click_function = "drawRandom", function_owner = self,
		label = "", position = DRAW_RANDOM_POS, scale = scale,
		width = 0, height = 0, font_size = 150, font_color = {1, 1, 1},
	})

	setPhase(phase)
	-- Give the Player Boards a moment to load before asking for their votes.
	Wait.frames(refresh, 5)
end

function noop() end

function onSave()
	return JSON.encode({phase = phase, drawnGuid = drawnGuid})
end


-- ------------------------------------------------------------------ draw ---

-- Switch phase and show the buttons that go with it.
function setPhase(p)
	phase = p
	local look = MAIN_LOOK[p]
	if look then
		self.editButton({index = DRAW_BUTTON, label = look.label, color = look.color,
			tooltip = look.tooltip, width = MAIN_SIZE.width, height = MAIN_SIZE.height})
	else
		self.editButton({index = DRAW_BUTTON, label = "", tooltip = "", width = 0, height = 0})
	end

	local tie = p == "tie"
	self.editButton({index = TIE_AYE_BUTTON, label = tie and "AYE" or "", color = {0.2, 0.35, 0.8},
		tooltip = tie and "Moderator: AYE wins." or "",
		width = tie and TIE_SIZE.width or 0, height = tie and TIE_SIZE.height or 0})
	self.editButton({index = TIE_NAY_BUTTON, label = tie and "NAY" or "", color = {0.8, 0.2, 0.2},
		tooltip = tie and "Moderator: NAY wins." or "",
		width = tie and TIE_SIZE.width or 0, height = tie and TIE_SIZE.height or 0})

	local drawing = p == "draw"
	self.editButton({index = DRAW_RANDOM_BUTTON, label = drawing and "Draw Random" or "",
		color = MAIN_LOOK.draw.color,
		tooltip = drawing and "Draw a random Dilemma card from the bag." or "",
		width = drawing and MAIN_SIZE.width or 0, height = drawing and MAIN_SIZE.height or 0})
end

function onMainClick(obj, color)
	if phase == "draw" then draw(function(count) return 0 end)
	elseif phase == "resolve" then resolve()
	elseif phase == "cleanup" then cleanUp() end
end

function drawRandom(obj, color)
	if phase == "draw" then draw(function(count) return math.random(0, count - 1) end) end
end

-- Deal the card at bag position pickIndex(count) onto the dilemma spot; 0 is
-- the first card, the top of the bag. Does nothing if the bag is empty or
-- missing.
function draw(pickIndex)
	local bag = getObjectFromGUID(DILEMMA_BAG)
	if bag == nil then
		printToAll("Draw: the Dilemma Deck bag " .. DILEMMA_BAG .. " is missing.", {1, 0.5, 0.5})
		return
	end
	local count = #bag.getObjects()
	if count == 0 then
		printToAll("Draw: the Dilemma Deck bag is empty.", {1, 0.5, 0.5})
		return
	end

	local card = bag.takeObject({
		index = pickIndex(count),
		position = DRAW_POS, rotation = DRAW_ROT, smooth = false,
	})
	if card == nil then return end
	drawnGuid = card.getGUID()
	setPhase("resolve")
end

-- More Power wins; a tie goes to the Moderator.
function resolve()
	local nay, aye = voteTotals()
	setVoteTotals(nay, aye)
	if aye > nay then
		finishDilemma("AYE")
	elseif nay > aye then
		finishDilemma("NAY")
	else
		broadcastToAll("Moderator tiebreaks!", {1, 1, 1})
		setPhase("tie")
	end
end

function tieAye() if phase == "tie" then finishDilemma("AYE") end end
function tieNay() if phase == "tie" then finishDilemma("NAY") end end

-- Chat color announcing each result: blue for AYE, red for NAY.
local RESULT_COLOR = {AYE = {0.3, 0.5, 1}, NAY = {1, 0.3, 0.3}}

-- Move the drawn card aside, facing the winner's way, share out the Balance,
-- move the card zones' Power into the Balance, and wait for Clean Up.
function finishDilemma(winner)
	broadcastToAll("The Council votes " .. winner .. "!", RESULT_COLOR[winner])
	local card = drawnGuid and getObjectFromGUID(drawnGuid)
	if card == nil then
		printToAll("Conclude: the drawn Dilemma card is missing.", {1, 0.5, 0.5})
	else
		card.setPosition(RESOLVED_POS)
		card.setRotation(RESOLVED_ROT[winner])
	end
	setPhase("payout")
	-- Pay the passers out of the Balance first, then move this vote's Power
	-- into the Balance.
	local passers, names = findPassers()
	payPassers(passers, names, function()
		powerToBalance(function() setPhase("cleanup") end)
	end)
end


-- -------------------------------------------------------------- clean up ---

-- File the resolved dilemma card, send the played cards back to hands, and go
-- back to Draw.
function cleanUp()
	local card = drawnGuid and getObjectFromGUID(drawnGuid)
	if card == nil then
		printToAll("Clean Up: the resolved Dilemma card is missing; not filed.", {1, 0.8, 0.3})
	else
		fileCard(card)
	end
	drawnGuid = nil
	cardsToHands()
	-- Give the returned cards a moment to land in the hands first.
	Wait.time(resetHandCards, HAND_SETTLE_SECONDS)
	setPhase("draw")
end

-- Every card in every hand is set to this rotation after Clean Up, which
-- turns the Pass for Moderator cards flipped by a Moderator claim (see
-- lib/player_board.lua) face-up again.
local HAND_CARD_ROT = {0.00, 180.00, 0.00}
HAND_SETTLE_SECONDS = 0.5

function resetHandCards()
	for _, color in ipairs(Player.getAvailableColors()) do
		local ok, objs = pcall(function() return Player[color].getHandObjects() end)
		for _, obj in ipairs(ok and objs or {}) do
			if obj.type == "Card" then obj.setRotation(HAND_CARD_ROT) end
		end
	end
end

-- The cards and decks in the clean-up zone sitting in slot i (not `except`).
function slotContents(zone, i, except)
	local s = CLEANUP_SLOTS[i]
	local found = {}
	for _, obj in ipairs(zone.getObjects()) do
		if (obj.type == "Card" or obj.type == "Deck") and obj ~= except then
			local p = obj.getPosition()
			local dx, dz = p.x - s[1], p.z - s[3]
			if math.sqrt(dx * dx + dz * dz) <= SLOT_TOLERANCE then table.insert(found, obj) end
		end
	end
	return found
end

-- Put card in the first empty slot, turned CLEANUP_TURN about y; with every
-- slot full, on top of the pile in the last one.
function fileCard(card)
	local zone = getObjectFromGUID(CLEANUP_ZONE)
	if zone == nil then
		printToAll("Clean Up: clean-up zone " .. CLEANUP_ZONE .. " is missing; card not filed.", {1, 0.5, 0.5})
		return
	end

	local pos = nil
	for i, s in ipairs(CLEANUP_SLOTS) do
		if #slotContents(zone, i, card) == 0 then
			pos = {s[1], s[2] + SLOT_DROP, s[3]}
			break
		end
	end
	if pos == nil then
		-- All full: drop it just above the highest thing in the last slot.
		local last = CLEANUP_SLOTS[#CLEANUP_SLOTS]
		local top = last[2]
		for _, obj in ipairs(slotContents(zone, #CLEANUP_SLOTS, card)) do
			local b = obj.getBounds()
			top = math.max(top, b.center.y + b.size.y / 2)
		end
		pos = {last[1], top + SLOT_DROP, last[3]}
	end

	local r = card.getRotation()
	card.setPosition(pos)
	card.setRotation({r.x, r.y + CLEANUP_TURN, r.z})
end


-- ----------------------------------------------------------- card zones ---

-- How long to wait for the Power sent to the Balance to show up in its zone.
local BALANCE_SETTLE_SECONDS = 1

-- Send a card (or deck) to color's hand. Returns false if there's no such hand.
function toHand(obj, color)
	local ok, hand = pcall(function() return Player[color].getHandTransform() end)
	if not ok or hand == nil then return false end
	obj.setPosition(hand.position)
	obj.setRotation(hand.rotation)
	return true
end

--[[ Call fn(obj, color) once for every object in a Player Board's card zone,
with color that board's player (its GM Notes). ]]
function eachInCardZones(fn)
	local seen = {}
	for _, board in ipairs(getObjects()) do
		if board.getName() == PLAYER_BOARD_NAME then
			local zone = zoneOf(board, "card")
			local color = board.getGMNotes():match("^%s*(.-)%s*$")
			for _, obj in ipairs(zone and zone.getObjects() or {}) do
				local guid = obj.getGUID()
				if not seen[guid] then
					seen[guid] = true
					fn(obj, color)
				end
			end
		end
	end
end

-- Send every card in the card zones to its board's player's hand.
function cardsToHands()
	eachInCardZones(function(obj, color)
		if (obj.type == "Card" or obj.type == "Deck") and not toHand(obj, color) then
			printToAll("Clean Up: no hand for '" .. color .. "' (the Player Board's GM Notes); card left on the board.", {1, 0.8, 0.3})
		end
	end)
end

--[[ Move the Power in every card zone into the Balance. done() runs once it
has landed in the Balance zone (or after BALANCE_SETTLE_SECONDS). ]]
function powerToBalance(done)
	local pool = getObjectFromGUID(POWER_ZONE)
	if pool == nil then
		printToAll("Conclude: Balance zone " .. POWER_ZONE .. " is missing; Power left in the card zones.", {1, 0.5, 0.5})
		return done()
	end
	local power, powerTotal = {}, 0
	eachInCardZones(function(obj)
		if obj.hasTag(POWER_TAG) then
			table.insert(power, obj)
			powerTotal = powerTotal + pieceValue(obj) * math.max(1, obj.getQuantity())
		end
	end)
	if #power == 0 then return done() end

	local target = zoneTotal(pool, POWER_TAG) + powerTotal
	for n, obj in ipairs(power) do
		obj.setPosition(payoutSpot(pool.getPosition(), n, #power))
	end
	Wait.condition(done, function() return zoneTotal(pool, POWER_TAG) >= target end,
		BALANCE_SETTLE_SECONDS, done)
end


-- ---------------------------------------------------------------- payout ---

-- Where the nth of count pieces goes: a grid centered on center.
function payoutSpot(center, n, count)
	local cols = math.min(count, PAYOUT.PER_ROW)
	local rows = math.ceil(count / PAYOUT.PER_ROW)
	local col = (n - 1) % PAYOUT.PER_ROW
	local row = math.floor((n - 1) / PAYOUT.PER_ROW)
	return {
		center.x + (col - (cols - 1) / 2) * PAYOUT.STEP,
		PAYOUT.DROP_Y,
		center.z + (row - (rows - 1) / 2) * PAYOUT.STEP,
	}
end

-- The Player Board's zone for role ("coins", "card" or "power"; it keeps its
-- zone GUIDs in zoneGuids), or nil.
function zoneOf(board, role)
	local guids = board.getTable("zoneGuids")
	return guids and guids[role] and getObjectFromGUID(guids[role]) or nil
end

-- Face value of a Power piece (its GM Notes).
function pieceValue(obj)
	return tonumber((obj.getGMNotes():gsub("%s", ""))) or 0
end

-- How many Power pieces of each value are in the zone; a stack counts each piece.
function pieceCounts(zone)
	local counts = {}
	for _, d in ipairs(POWER_DENOMS) do counts[d] = 0 end
	for _, obj in ipairs(zone.getObjects()) do
		local v = obj.hasTag(POWER_TAG) and pieceValue(obj)
		if v and counts[v] then counts[v] = counts[v] + math.max(1, obj.getQuantity()) end
	end
	return counts
end

--[[ Hand each of n players exactly `share` out of counts (value -> pieces).
Returns one {value -> pieces} per player, or nil if the pieces can't do it.
Tries big pieces first; failures are remembered so the search stays small. ]]
function splitShares(counts, n, share)
	local failed = {}
	local function search(i, c10, c5, c1)
		if i > n then return {} end
		local key = i .. ":" .. c10 .. ":" .. c5 .. ":" .. c1
		if failed[key] then return nil end
		for a = math.min(c10, math.floor(share / 10)), 0, -1 do
			for b = math.min(c5, math.floor((share - 10 * a) / 5)), 0, -1 do
				local c = share - 10 * a - 5 * b
				if c <= c1 then
					local rest = search(i + 1, c10 - a, c5 - b, c1 - c)
					if rest then
						table.insert(rest, 1, {[10] = a, [5] = b, [1] = c})
						return rest
					end
				end
			end
		end
		failed[key] = true
		return nil
	end
	return search(1, counts[10], counts[5], counts[1])
end

-- The players whose vote card is PASS: where each one's payout goes (their
-- power zone) and a name for the chat.
function findPassers()
	local passers, names = {}, {}
	for _, board in ipairs(getObjects()) do
		if board.getName() == PLAYER_BOARD_NAME then
			local v = board.call("getVote")
			if v and v.vote == "PASS" then
				local zone = zoneOf(board, "power")
				table.insert(passers, (zone or board).getPosition())
				table.insert(names, v.color ~= "" and v.color or board.getGUID())
			end
		end
	end
	return passers, names
end

--[[ Split the Power in the Balance evenly among the passers (from
findPassers); what doesn't divide evenly stays in the Balance. done() runs
afterwards, whether or not anything was paid. ]]
function payPassers(passers, names, done)
	local pool = getObjectFromGUID(POWER_ZONE)
	if pool == nil then
		printToAll("Payout: Balance zone " .. POWER_ZONE .. " is missing; nothing paid.", {1, 0.5, 0.5})
		return done()
	end

	local total = zoneTotal(pool, POWER_TAG)
	if #passers == 0 or total < #passers then return done() end
	local share = math.floor(total / #passers)
	local remainder = total - share * #passers

	-- Break pieces down, smallest first, until the shares can be made.
	local have = pieceCounts(pool)
	local counts, broken = {}, {}
	for v, k in pairs(have) do counts[v], broken[v] = k, 0 end
	local shares = splitShares(counts, #passers, share)
	while shares == nil do
		local v = (counts[5] > 0 and 5) or (counts[10] > 0 and 10) or nil
		if v == nil then
			printToAll("Payout: the Balance's pieces can't be split; nothing paid.", {1, 0.5, 0.5})
			return done()
		end
		counts[v], broken[v] = counts[v] - 1, broken[v] + 1
		for d, k in pairs(POWER_BREAKDOWN[v]) do counts[d] = counts[d] + k end
		shares = splitShares(counts, #passers, share)
	end

	-- Each share is made from pieces already in the Balance where there are
	-- enough, and new pieces otherwise. New pieces nobody needs go back into
	-- the Balance. Moves and removals run before any new piece lands there.
	local kept, minted = {}, {}
	for _, d in ipairs(POWER_DENOMS) do
		kept[d] = have[d] - broken[d]
		minted[d] = counts[d] - kept[d]
	end
	local steps, mints = {}, {}
	for _, d in ipairs(POWER_DENOMS) do
		for _ = 1, broken[d] do table.insert(steps, {op = "destroy", value = d}) end
	end
	for i, center in ipairs(passers) do
		local pieces = {}
		for j = #POWER_DENOMS, 1, -1 do
			local d = POWER_DENOMS[j]
			for _ = 1, shares[i][d] do table.insert(pieces, d) end
		end
		for n, d in ipairs(pieces) do
			local pos = payoutSpot(center, n, #pieces)
			if kept[d] > 0 then
				kept[d] = kept[d] - 1
				table.insert(steps, {op = "move", value = d, pos = pos})
			else
				minted[d] = minted[d] - 1
				table.insert(mints, {op = "mint", value = d, pos = pos})
			end
		end
	end
	local leftover = {}
	for _, d in ipairs(POWER_DENOMS) do
		for _ = 1, minted[d] do table.insert(leftover, d) end
	end
	for n, d in ipairs(leftover) do
		table.insert(mints, {op = "mint", value = d, pos = payoutSpot(pool.getPosition(), n, #leftover)})
	end
	for _, m in ipairs(mints) do table.insert(steps, m) end

	local bag = nil
	if #mints > 0 then
		bag = getObjectFromGUID(SOURCE_BAG)
		if bag == nil then
			printToAll("Payout: source bag " .. SOURCE_BAG .. " is missing, and the Balance needs change; nothing paid.", {1, 0.5, 0.5})
			return done()
		end
	end

	printToAll(string.format("%s %s %d Power from the Balance%s.",
		table.concat(names, ", "), #passers == 1 and "takes" or "each take", share,
		remainder > 0 and (", " .. remainder .. " stays") or ""), {1, 1, 1})
	runStep(pool, bag, steps, 1, done)
end

-- A Power piece (or stack) of value in the zone, or nil.
function findInZone(zone, value)
	for _, obj in ipairs(zone.getObjects()) do
		if obj.hasTag(POWER_TAG) and pieceValue(obj) == value then return obj end
	end
	return nil
end

-- The GUID of a Power piece worth value in the source bag, or nil.
function findInBag(bag, value)
	for _, entry in ipairs(bag.getObjects()) do
		local isPower = false
		for _, t in ipairs(entry.tags or {}) do
			if t == POWER_TAG then isPower = true end
		end
		if isPower and tonumber(entry.gm_notes) == value then return entry.guid end
	end
	return nil
end

--[[ Carry out the payout one step at a time, re-finding pieces in the Balance
each step so stacks that split or merge along the way don't matter. Steps:
  move    a piece from the Balance to pos
  destroy a piece in the Balance (it's being broken down)
  mint    a new piece at pos, cloned out of the source bag and the original
          put back, so the bag keeps its stock (as the Change Converter does).
One at a time: takeObject is async, and many at once against one bag drops
pieces. ]]
function runStep(pool, bag, steps, i, done)
	if i > #steps then return done() end
	local step = steps[i]
	local function nextStep()
		Wait.frames(function() runStep(pool, bag, steps, i + 1, done) end, 2)
	end

	if step.op == "mint" then
		local guid = findInBag(bag, step.value)
		if guid == nil then
			printToAll("Payout: no " .. step.value .. "-Power piece in the source bag.", {1, 0.8, 0.3})
			return nextStep()
		end
		local original = bag.takeObject({guid = guid, smooth = false, position = bag.getPosition() + Vector(0, 3, 0)})
		Wait.condition(function()
			original.clone({position = step.pos, snap_to_grid = false})
			Wait.frames(function()
				bag.putObject(original)
				nextStep()
			end, 2)
		end, function() return original ~= nil and not original.spawning end)
		return
	end

	local piece = findInZone(pool, step.value)
	if piece == nil then
		printToAll("Payout: no " .. step.value .. "-Power piece left in the Balance.", {1, 0.8, 0.3})
		return nextStep()
	end
	-- From a stack, take just the top piece.
	if piece.getQuantity() > 1 then
		if step.op == "destroy" then
			piece.takeObject({smooth = false, callback_function = function(o) o.destruct() end})
		else
			piece.takeObject({position = step.pos, smooth = false})
		end
	elseif step.op == "destroy" then
		piece.destruct()
	else
		piece.setPosition(step.pos)
	end
	nextStep()
end


-- ---------------------------------------------------------------- totals ---

-- Sum of GM Notes values over every object in the zone carrying `tag`. A stack
-- counts every piece in it. Same counting as the Player Boards.
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

-- Show the vote totals in the red and blue circles.
function setVoteTotals(red, blue)
	self.editButton({index = RED_TOTAL_BUTTON, label = tostring(red)})
	self.editButton({index = BLUE_TOTAL_BUTTON, label = tostring(blue)})
end

-- Power committed to NAY (red) and AYE (blue) across every Player Board.
function voteTotals()
	local nay, aye = 0, 0
	for _, board in ipairs(getObjects()) do
		if board.getName() == PLAYER_BOARD_NAME then
			local v = board.call("getVote")
			if v and v.vote == "NAY" then nay = nay + (v.power or 0) end
			if v and v.vote == "AYE" then aye = aye + (v.power or 0) end
		end
	end
	return nay, aye
end

function refresh()
	refreshPending = false
	setVoteTotals(voteTotals())

	local zone = getObjectFromGUID(POWER_ZONE)
	self.editButton({index = POWER_TOTAL_BUTTON, label = zone and tostring(zoneTotal(zone, POWER_TAG)) or "?"})
end

--[[ Any zone change might be a vote or Power moving, on a Player Board or in
the power pool, so recount everything. The Player Boards re-read their zones a
frame after the event; waiting two frames lets them (and a leaving object) settle
first. Several events in one frame share one recount. ]]
function scheduleRefresh()
	if refreshPending then return end
	refreshPending = true
	Wait.frames(refresh, 2)
end

function onObjectEnterZone(_, _) scheduleRefresh() end
function onObjectLeaveZone(_, _) scheduleRefresh() end
