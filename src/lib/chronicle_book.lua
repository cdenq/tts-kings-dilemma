-- Shared script for the Realm Chronicles book: a single tile that pages
-- through any number of game results. Each page has a King, King's House and
-- Date, and 5 rows of scores, typed in by hand except each row's total (the sum
-- of its scores) and rank (its place by total). The layout matches the
-- sheet drawn by generation/scorecard.py, whose headers are printed on the image.
-- Pages are saved with the object, so they survive reloads.

-- Per row: rank, house, coins count, power count, secret points, coins points,
-- power points, open points, total points.
ROWS, COLS = 5, 9
CELLS = ROWS * COLS
RANK, HOUSE, TOTAL = 0, 1, 8  -- rank and total are filled in by scorePage()
SCORE_COLS = {4, 5, 6, 7}     -- the Points columns add up to the total; the Counts don't

-- Pages saved before the Count columns were added had 7 columns per row: rank,
-- house, secret, open, coins, power, total. Each old column's new column:
OLD_COLS = 7
OLD_TO_NEW = {[0] = 0, 1, 4, 7, 5, 6, 8}

-- Inputs and buttons are created in this order, so these are their indices.
KING_INPUT, HOUSE_INPUT, DATE_INPUT, PAGE_INPUT = CELLS, CELLS + 1, CELLS + 2, CELLS + 3
PREV_BUTTON, COUNT_BUTTON, NEXT_BUTTON, DELETE_BUTTON, PAGE_BOX_BUTTON = 0, 1, 2, 3, 4

-- Layout is in fractions of the tile: x runs from -1 (left edge) to 1 (right
-- edge), z from -1 (top edge) to 1 (bottom edge). Widths are fractions of the
-- tile's half-width; heights and font sizes are fractions of its half-height.
-- The cell centres come from generation/scorecard.py (a 2000 x 906 layout):
-- x = layout_x / 1000 - 1, z = layout_y / 453 - 1.

-- Per column: x, width, validation (2 = integer).
local COLUMNS = {
	{-0.937, 0.08, 2},   -- rank
	{-0.648, 0.45, 1},   -- house
	{-0.309, 0.17, 2},   -- coins count
	{-0.110, 0.17, 2},   -- power count
	{0.090, 0.17, 2},    -- secret points
	{0.288, 0.17, 2},    -- coins points
	{0.487, 0.17, 2},    -- power points
	{0.686, 0.17, 2},    -- open points
	{0.885, 0.17, 2},    -- total points
}
local TITLE_Z = -0.819              -- King, King's House and Date
local ROW_Z, ROW_GAP = -0.211, 0.261
local ROW_H, TEXT = 0.2, 0.14       -- field height and font size
local DATE_TEXT = 0.08              -- small enough for 12/12/26
local KINGS_HOUSE_TEXT = 0.072      -- small enough for "Marquise of Dualak"

local NAV_Z = 1.2                   -- page controls, just below the sheet
local NAV_H, NAV_TEXT = 0.26, 0.16
-- Page controls, left to right: x and width of each.
local PREV_X, PREV_W = -0.42, 0.16
local PAGE_X, PAGE_W = -0.22, 0.18  -- the page number field
local COUNT_X, COUNT_W = -0.01, 0.2 -- "of N"
local NEXT_X, NEXT_W = 0.2, 0.16
local DELETE_X, DELETE_W = 0.78, 0.4

-- TTS draws a text field's text near the top of the field, so fields sit this
-- much lower than their cell for the text to line up with the printed labels.
local TEXT_DROP = 0.06

local TEXT_LIFT = 0.03  -- how far text floats above the tile's surface; more
                        -- makes it drift off its cell when seen at an angle
local UNITS = 500       -- button size units per unit of the object's own space
local DRAW = 4          -- everything is drawn this many times too big and
                        -- scaled back down, so text renders sharp

local INK = {0.1, 0.08, 0.05, 100}
local FADED = {0.55, 0.55, 0.55, 100}
local CLEAR = {0, 0, 0, 0}
local PAPER = {0.95, 0.93, 0.88}
local DANGER = {0.6, 0.12, 0.1}

local PREV_LABEL, NEXT_LABEL, ADD_LABEL = "\u{25C4}", "\u{25BA}", "+ \u{25BA}"

-- True while the script writes to inputs, so their callbacks don't save.
loading = false

function onLoad(saved_data)
	book = loadBook(saved_data)
	createAll()
	showPage(book.current)
end

function onSave()
	return JSON.encode(book)
end

function newPage()
	local cells = {}
	for i = 1, CELLS do cells[i] = "" end
	return {king = "", house = "", date = "", cells = cells}
end

-- A new page after `prev`: the same houses in the same rows, and prev's
-- winner (the first row ranked 1) as the King's House.
function followingPage(prev)
	local page = newPage()
	for r = 0, ROWS - 1 do
		local house = prev.cells[r * COLS + HOUSE + 1]
		page.cells[r * COLS + HOUSE + 1] = house
		if page.house == "" and prev.cells[r * COLS + RANK + 1] == "1" then
			page.house = house
		end
	end
	return page
end

function loadBook(saved_data)
	local data = saved_data ~= "" and JSON.decode(saved_data) or nil
	if data and data.pages and #data.pages > 0 then
		data.current = math.floor(tonumber(data.current) or 1)
		local old = data.cols ~= COLS
		for _, page in ipairs(data.pages) do
			page.house = page.house or ""
			if old then page.cells = fromOldCells(page.cells, 1) end
		end
		data.cols = COLS
		return data
	end

	-- A sheet saved by lib/score_sheet.lua (keyed "0", "1", ...) becomes page 1.
	-- Its "cols" is set once it's in the current layout.
	local page = newPage()
	if data then
		if data.cols == tostring(COLS) then
			for i = 1, CELLS do page.cells[i] = data[tostring(i - 1)] or "" end
		else
			page.cells = fromOldCells(data, 0, tostring)
		end
		page.king, page.date = self.getName(), self.getDescription()
	end
	return {current = 1, cols = COLS, pages = {page}}
end

-- Moves a page's cells from the old 7-column layout into the current one; the
-- Count columns start blank. Old cell i is at old[key(i + base)].
function fromOldCells(old, base, key)
	key = key or function(i) return i end
	local cells = newPage().cells
	for r = 0, ROWS - 1 do
		for c = 0, OLD_COLS - 1 do
			cells[r * COLS + OLD_TO_NEW[c] + 1] = old[key(r * OLD_COLS + c + base)] or ""
		end
	end
	return cells
end

-- Read by the house tally (score_sheets/house_stats.lua).
function getBook()
	return book
end

function currentPage()
	return book.pages[book.current]
end

function createAll()
	measureTile()

	-- Buttons first, so their indices match the *_BUTTON constants.
	createButton("prevPage", PREV_LABEL, "Previous page", PREV_X, PREV_W, NAV_TEXT, INK, PAPER)
	createButton("noop", "", "", COUNT_X, COUNT_W, NAV_TEXT, INK, PAPER)
	createButton("nextPage", NEXT_LABEL, "Next page", NEXT_X, NEXT_W, NAV_TEXT, INK, PAPER)
	createButton("deletePage", "Delete page", "Delete this page", DELETE_X, DELETE_W, NAV_TEXT * 0.75, {1, 1, 1}, DANGER)
	-- The page number's box, drawn apart from its field so the field can sit lower
	-- (see TEXT_DROP), and just under it so clicks still reach the field.
	local box = place({click_function = "noop", label = "", color = PAPER}, PAGE_X, NAV_Z, PAGE_W, NAV_H, NAV_TEXT)
	box.position[2] = box.position[2] - 0.01
	self.createButton(box)

	-- Inputs: cells first, so a cell's input index is its index in page.cells, minus 1.
	for r = 0, ROWS - 1 do
		for c = 0, COLS - 1 do
			local i = r * COLS + c
			_G["onCellEdit" .. i] = function(_, _, value, selected) onCellEdit(i, value, selected) end
			local x, width, validation = table.unpack(COLUMNS[c + 1])
			createInput("onCellEdit" .. i, x, ROW_Z + r * ROW_GAP, width, ROW_H, TEXT, validation)
		end
	end
	-- The King field starts just after the "King" printed at its left, and its
	-- text is left-aligned so it reads on from that word.
	createInput("onKingEdit", -0.125, TITLE_Z, 0.99, ROW_H, TEXT, 1, "King", 2)
	createInput("onHouseEdit", 0.49, TITLE_Z, 0.37, ROW_H, KINGS_HOUSE_TEXT, 1, "King's House")
	createInput("onDateEdit", 0.885, TITLE_Z, 0.17, ROW_H, DATE_TEXT, 1, "Date")
	createInput("onPageEdit", PAGE_X, NAV_Z, PAGE_W, NAV_H, NAV_TEXT, 2, "Page number: type one to jump to it")
end

-- Finds the tile's half-width, half-height and top surface in its own space.
function measureTile()
	local size, scale = self.getBoundsNormalized().size, self.getScale()
	tile = {half_w = 1, half_h = 1, top = 0.1}
	if size.x > 0 and size.z > 0 then
		tile.half_w = size.x / scale.x / 2
		tile.half_h = size.z / scale.z / 2
		-- Text below the tile's full thickness is hidden inside it.
		tile.top = size.y / scale.y
	end
end

-- Fills in position and size for a field at x, z (see Layout above).
function place(params, x, z, width, height, font_size)
	params.function_owner = self
	params.position = {x * tile.half_w, tile.top + TEXT_LIFT, z * tile.half_h}
	params.width = width * tile.half_w * UNITS * DRAW
	params.height = height * tile.half_h * UNITS * DRAW
	params.font_size = font_size * tile.half_h * UNITS * DRAW
	params.scale = {1 / DRAW, 1 / DRAW, 1 / DRAW}
	return params
end

-- alignment defaults to 3 (centred); 2 is left.
function createInput(input_function, x, z, width, height, font_size, validation, tooltip, alignment)
	self.createInput(place({
		input_function = input_function, tooltip = tooltip,
		alignment = alignment or 3, validation = validation, tab = 2,
		font_color = INK, color = CLEAR,
	}, x, z + TEXT_DROP, width, height, font_size))
end

function createButton(click_function, label, tooltip, x, width, font_size, font_color, color)
	self.createButton(place({
		click_function = click_function, label = label, tooltip = tooltip,
		font_color = font_color, color = color,
	}, x, NAV_Z, width, NAV_H, font_size))
end

function showPage(n)
	book.current = math.max(1, math.min(n, #book.pages))
	local page = currentPage()
	local last = book.current == #book.pages

	loading = true
	for i = 0, CELLS - 1 do
		self.editInput({index = i, value = page.cells[i + 1]})
	end
	self.editInput({index = KING_INPUT, value = page.king})
	self.editInput({index = HOUSE_INPUT, value = page.house})
	self.editInput({index = DATE_INPUT, value = page.date})
	self.editInput({index = PAGE_INPUT, value = tostring(book.current)})
	loading = false

	self.editButton({index = PREV_BUTTON, font_color = book.current == 1 and FADED or INK})
	self.editButton({index = COUNT_BUTTON, label = "of " .. #book.pages})
	self.editButton({
		index = NEXT_BUTTON,
		label = last and ADD_LABEL or NEXT_LABEL,
		tooltip = last and "Add a new page" or "Next page",
	})
end

-- Edits are saved as they're typed, so the call made when an input loses
-- focus is ignored: it can arrive after the page has already changed.
function onCellEdit(i, value, selected)
	if loading or not selected then return end
	local page = currentPage()
	page.cells[i + 1] = value
	scorePage(page)
end

function setCell(page, r, c, value)
	local i = r * COLS + c
	page.cells[i + 1] = value
	loading = true
	self.editInput({index = i, value = value})
	loading = false
end

-- Sets each row's total to the sum of its scores (blank if it has none), then
-- ranks the rows by total, highest first; ties share a rank.
function scorePage(page)
	local ranked = {}
	for r = 0, ROWS - 1 do
		local total = nil
		for _, c in ipairs(SCORE_COLS) do
			local v = tonumber(page.cells[r * COLS + c + 1])
			if v then total = (total or 0) + v end
		end
		setCell(page, r, TOTAL, total and tostring(total) or "")
		if total then
			table.insert(ranked, {row = r, total = total})
		else
			setCell(page, r, RANK, "")
		end
	end

	table.sort(ranked, function(a, b) return a.total > b.total end)
	local rank, last_total = 0, nil
	for _, entry in ipairs(ranked) do
		if entry.total ~= last_total then
			rank, last_total = rank + 1, entry.total
		end
		setCell(page, entry.row, RANK, tostring(rank))
	end
end

function onKingEdit(_, _, value, selected)
	if loading or not selected then return end
	currentPage().king = value
end

function onHouseEdit(_, _, value, selected)
	if loading or not selected then return end
	currentPage().house = value
end

function onDateEdit(_, _, value, selected)
	if loading or not selected then return end
	currentPage().date = value
end

-- Jumps when Enter is pressed or the box loses focus.
function onPageEdit(_, _, value, selected)
	if loading or (selected and not value:find("\n")) then return end
	local n = tonumber((value:gsub("%s", "")))
	showPage(n and math.floor(n) or book.current)
	return tostring(book.current)
end

function prevPage()
	if book.current > 1 then showPage(book.current - 1) end
end

function nextPage()
	if book.current == #book.pages then
		table.insert(book.pages, followingPage(currentPage()))
	end
	showPage(book.current + 1)
end

function deletePage(_, player_color)
	local n = book.current
	Player[player_color].showConfirmDialog("Delete page " .. n .. " of the chronicle?", function()
		if n > #book.pages then return end
		if #book.pages == 1 then
			book.pages[1] = newPage()
		else
			table.remove(book.pages, n)
		end
		showPage(n)
	end)
end

function noop() end
