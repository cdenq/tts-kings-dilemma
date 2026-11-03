-- tts: 5fa6fa
-- House tally: the "Average / Max Performance of Each House" sheet drawn by
-- generation/house_stats_card.py. Nothing here is typed in; every few seconds it
-- reads all pages of the Realm Chronicles book and shows, per house, the
-- average and best Coins Count, Power Count, Secret Points, Coins Points, Power
-- Points, Open Points and Total Points, and how many times the house was King
-- (ranked 1st, ties included) with its share of all Kings. Houses are listed in
-- the order they first appear in the book. Total Games counts the pages with at
-- least one total on them.

CHRONICLE = "729397"
REFRESH_SECONDS = 2

-- The chronicle's page layout (see lib/chronicle_book.lua).
CHRONICLE_COLS = 9
RANK_COL, HOUSE_COL, TOTAL_COL = 0, 1, 8
-- coins count, power count, secret, coins, power and open points, total points
STAT_COLS = {2, 3, 4, 5, 6, 7, 8}

ROWS = 5
-- Per row: house, then Avg and Max for each of STAT_COLS, then kings and share.
LABELS_PER_ROW = 2 + 2 * #STAT_COLS + 1

-- Layout is in fractions of the tile, as in lib/chronicle_book.lua: x runs
-- from -1 (left edge) to 1 (right edge), z from -1 (top edge) to 1 (bottom
-- edge). Cell centres come from generation/house_stats_card.py (a 2000 x 950
-- layout): x = layout_x / 1000 - 1, z = layout_y / 475 - 1.
local HOUSE_X, HOUSE_W = -0.827, 0.29  -- name is shrunk to fit HOUSE_W
local AVG_X = {-0.612, -0.402, -0.191, 0.019, 0.23, 0.44, 0.651}
local MAX_X = {-0.509, -0.298, -0.088, 0.123, 0.333, 0.544, 0.754}
local KINGS_X = 0.897
local GAMES_X, GAMES_Z = 0.875, -0.823  -- right of the printed "Total Games"
local ROW_Z, ROW_GAP = -0.152, 0.248

-- Font sizes are fractions of the tile's half-height.
local TEXT = 0.12          -- house names
local STAT_TEXT = 0.085    -- room for "12.3" in a narrow cell
local GAMES_TEXT = 0.15
local KINGS_TEXT, KINGS_Z = 0.13, -0.04
local SHARE_TEXT, SHARE_Z = 0.065, 0.075
local CHAR_W = 0.55        -- rough width of a character, per unit of font size
local HALF_H_PER_HALF_W = 0.475

local TEXT_LIFT = 0.03
local UNITS = 500
local DRAW = 4

local INK = {0.1, 0.08, 0.05, 100}

function onLoad()
	measureTile()
	shown = {}
	for r = 0, ROWS - 1 do
		local z = ROW_Z + r * ROW_GAP
		createLabel(HOUSE_X, z, TEXT)
		for i = 1, #STAT_COLS do
			createLabel(AVG_X[i], z, STAT_TEXT)
			createLabel(MAX_X[i], z, STAT_TEXT)
		end
		createLabel(KINGS_X, z + KINGS_Z, KINGS_TEXT)
		createLabel(KINGS_X, z + SHARE_Z, SHARE_TEXT)
	end
	createLabel(GAMES_X, GAMES_Z, GAMES_TEXT)  -- index ROWS * LABELS_PER_ROW
	refresh()
	Wait.time(refresh, REFRESH_SECONDS, -1)
end

-- Finds the tile's half-width, half-height and top surface in its own space.
function measureTile()
	local size, scale = self.getBoundsNormalized().size, self.getScale()
	tile = {half_w = 1, half_h = 1, top = 0.1}
	if size.x > 0 and size.z > 0 then
		tile.half_w = size.x / scale.x / 2
		tile.half_h = size.z / scale.z / 2
		tile.top = size.y / scale.y
	end
end

-- A button with no size draws only its label, and can't be clicked.
function createLabel(x, z, font_size)
	self.createButton({
		click_function = "noop", function_owner = self, label = "",
		position = {x * tile.half_w, tile.top + TEXT_LIFT, z * tile.half_h},
		width = 0, height = 0,
		font_size = font_size * tile.half_h * UNITS * DRAW,
		scale = {1 / DRAW, 1 / DRAW, 1 / DRAW},
		font_color = INK,
	})
	table.insert(shown, {label = "", font_size = font_size})
end

-- Changes a label only if it differs, so nothing is resent while idle.
function setLabel(index, label, font_size)
	local current = shown[index + 1]
	font_size = font_size or current.font_size
	if current.label == label and current.font_size == font_size then return end
	current.label, current.font_size = label, font_size
	self.editButton({index = index, label = label, font_size = font_size * tile.half_h * UNITS * DRAW})
end

function refresh()
	local chronicle = getObjectFromGUID(CHRONICLE)
	local book = chronicle and chronicle.call("getBook")
	if not book then return end
	local houses, kings, games = tally(book)
	setLabel(ROWS * LABELS_PER_ROW, tostring(games))

	for r = 0, ROWS - 1 do
		local house = houses[r + 1]
		local i = r * LABELS_PER_ROW
		setLabel(i, house and house.name or "", house and houseFontSize(house.name))
		for s = 1, #STAT_COLS do
			local stat = house and house.stats[s]
			local has = stat and stat.count > 0
			setLabel(i + 2 * s - 1, has and string.format("%.1f", stat.sum / stat.count) or "")
			setLabel(i + 2 * s, has and string.format("%g", stat.max) or "")
		end
		setLabel(i + LABELS_PER_ROW - 2, house and tostring(house.kings) or "")
		setLabel(i + LABELS_PER_ROW - 1, house and kings > 0
			and "(" .. math.floor(house.kings / kings * 100 + 0.5) .. "%)" or "")
	end
end

-- Totals every row of every page by house. Returns the houses in order of
-- first appearance, the number of Kings across the whole book, and the number
-- of games (pages with at least one total).
function tally(book)
	local houses, by_key, kings, games = {}, {}, 0, 0
	for _, page in ipairs(book.pages) do
		local played = false
		for r = 0, ROWS - 1 do
			if tonumber(page.cells[r * CHRONICLE_COLS + TOTAL_COL + 1]) then played = true end
		end
		if played then games = games + 1 end
		for r = 0, ROWS - 1 do
			local function cell(c) return page.cells[r * CHRONICLE_COLS + c + 1] or "" end
			local name = cell(HOUSE_COL):match("^%s*(.-)%s*$")
			if name ~= "" then
				local key = name:lower()
				local house = by_key[key]
				if not house then
					house = {name = name, kings = 0, stats = {}}
					for s = 1, #STAT_COLS do house.stats[s] = {sum = 0, count = 0} end
					by_key[key] = house
					table.insert(houses, house)
				end
				for s, c in ipairs(STAT_COLS) do
					local v, stat = tonumber(cell(c)), house.stats[s]
					if v then
						stat.sum, stat.count = stat.sum + v, stat.count + 1
						stat.max = stat.max and math.max(stat.max, v) or v
					end
				end
				if tonumber(cell(RANK_COL)) == 1 then
					house.kings, kings = house.kings + 1, kings + 1
				end
			end
		end
	end
	return houses, kings, games
end

-- Long house names are shrunk to fit their column.
function houseFontSize(name)
	return math.min(TEXT, HOUSE_W / (CHAR_W * #name * HALF_H_PER_HALF_W))
end

function noop() end
