-- tts: 20fcee
-- Dilemma Deck bag: a deck dropped on it is broken up and its cards go in one
-- at a time, top card first, so the bag never holds a deck object.

-- Where cards are taken out to on their way in, above the bag's center.
local CARD_LIFT = 3

-- Feed the deck's cards into the bag one after another, waiting for each to
-- spawn before taking the next so they go in in deck order. A deck down to its
-- last card turns into that card (deck.remainder), which goes in last.
local function feedDeck(deck)
	if deck.type == "Card" then
		self.putObject(deck)
		return
	end

	local rest = deck
	deck.takeObject({
		index = 0,
		position = self.getPosition() + Vector(0, CARD_LIFT, 0),
		smooth = false,
		callback_function = function(card)
			self.putObject(card)
			feedDeck(rest)
		end,
	})
	if deck.remainder ~= nil then rest = deck.remainder end
end

-- Keep the deck itself out and put its cards in instead.
function tryObjectEnter(obj)
	if obj.type ~= "Deck" then return true end
	feedDeck(obj)
	return false
end
