-- tts: 4f0315
-- Secret Agendas bag: a row of player-color buttons to its right for the
-- Secret Agenda draft.
--   Starting phase (no player remembered: after Cleanup, which calls
--   resetDraft, or on a fresh object): clicking a color deals that player one
--   random card per seated player, plus one extra; the rest stay in the bag.
--   After that, clicking a color moves the Secret Agenda cards still in the
--   last-clicked player's hand to the clicked player. A player keeps their pick
--   by taking it out of their hand before the next click.

local SECRET_AGENDA_TAG = "Secret Agenda"

local COLORS = {"White", "Red", "Yellow", "Green", "Blue"}
-- Text color that stays readable on each button.
local DARK_TEXT = {White = true, Yellow = true}

-- Row layout: first button's x offset from the bag's center, then the gap
-- between buttons. Positive x is the bag's right side.
local FIRST_X = 2.2
local SPACING = 1.3

-- The player who last received cards; kept in the save. nil means the
-- starting phase.
local lastColor = nil

function onLoad(saved)
	if saved ~= nil and saved ~= "" then
		lastColor = JSON.decode(saved).lastColor
	end

	for i, color in ipairs(COLORS) do
		local fn = "click" .. color
		_G[fn] = function(obj, player) passTo(color) end
		self.createButton({
			click_function = fn, function_owner = self,
			label = color, position = {FIRST_X + (i - 1) * SPACING, 0.5, 0},
			tooltip = "Give the Secret Agendas to " .. color .. ".",
			width = 550, height = 300, font_size = 120,
			color = stringColorToRGB(color),
			font_color = DARK_TEXT[color] and {0, 0, 0} or {1, 1, 1},
		})
	end
end

function onSave()
	return JSON.encode({lastColor = lastColor})
end

local function seatedPlayerCount()
	local count = 0
	for _, color in ipairs(getSeatedPlayers()) do
		for _, c in ipairs(COLORS) do
			if c == color then count = count + 1 end
		end
	end
	return count
end

-- Called by the Houses bag's Cleanup button.
function resetDraft()
	lastColor = nil
end

function passTo(color)
	-- Starting phase: deal from the bag.
	if lastColor == nil then
		local players = seatedPlayerCount()
		local cards = players + 1
		if #self.getObjects() <= cards then
			printToAll("Secret Agendas: the bag needs more than " .. cards
				.. " cards to start a draft for " .. players .. " players.", {1, 0.5, 0.5})
			return
		end
		self.shuffle()
		self.deal(cards, color)
		lastColor = color
		return
	end

	if lastColor == color then return end

	local moved = 0
	for _, card in ipairs(Player[lastColor].getHandObjects()) do
		if card.hasTag(SECRET_AGENDA_TAG) then
			card.deal(1, color)
			moved = moved + 1
		end
	end
	if moved == 0 then
		printToAll("Secret Agendas: no Secret Agenda cards in " .. lastColor .. "'s hand to pass.", {1, 0.8, 0.3})
		return
	end
	lastColor = color
end
