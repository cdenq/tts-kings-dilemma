-- Single-page score sheet, laid out to match generation/scorecard.py. Per row:
-- rank, house, coins count, power count, secret points, coins points, power
-- points, open points, total points. The total (sum of the four Points columns;
-- the Counts aren't added) and rank (place by total) are filled in automatically.
-- Values are saved by input index, as strings "0".."44".

COLS = 9
ROWS = 5
CELLS = ROWS * COLS
RANK, TOTAL = 0, 8
SCORE_COLS = {4, 5, 6, 7}

-- Sheets saved before the Count columns were added had 7 columns per row: rank,
-- house, secret, open, coins, power, total. Each old column's new column:
OLD_COLS = 7
OLD_TO_NEW = {[0] = 0, 1, 4, 7, 5, 6, 8}

-- Per column: x, width, alignment (2 left, 3 centre), validation (2 integer).
local COLUMNS = {
    {-2.08, 100, 3, 2},   -- rank
    {-1.446, 520, 2, 1},  -- house
    {-0.695, 190, 3, 2},  -- coins count
    {-0.253, 190, 3, 2},  -- power count
    {0.189, 190, 3, 2},   -- secret points
    {0.628, 190, 3, 2},   -- coins points
    {1.069, 190, 3, 2},   -- power points
    {1.510, 190, 3, 2},   -- open points
    {1.951, 190, 3, 2},   -- total points
}
local ROW_Z, ROW_GAP = -0.18, 0.265

function onload(saved_data)
    vals = {}
    for i = 0, CELLS - 1 do
        vals[tostring(i)] = ""
    end

    if saved_data ~= "" then
        local data = JSON.decode(saved_data)
        if data.cols == tostring(COLS) then
            for i = 0, CELLS - 1 do vals[tostring(i)] = data[tostring(i)] or "" end
        else
            for r = 0, ROWS - 1 do
                for c = 0, OLD_COLS - 1 do
                    vals[tostring(r * COLS + OLD_TO_NEW[c])] = data[tostring(r * OLD_COLS + c)] or ""
                end
            end
        end
    end

    createAll()
    updateSave()
end

function updateSave()
    for _, input in pairs(self.getInputs()) do
        if input.index < CELLS then
            vals[tostring(input.index)] = tostring(input.value)
        end
    end

    local ranked = {}
    for r = 0, ROWS - 1 do
        local total = nil
        for _, c in ipairs(SCORE_COLS) do
            local v = tonumber(vals[tostring(r * COLS + c)])
            if v then total = (total or 0) + v end
        end
        setCell(r, TOTAL, total and tostring(total) or "")
        if total then
            table.insert(ranked, {row = r, total = total})
        else
            setCell(r, RANK, "")
        end
    end

    -- Highest total first; ties share a rank.
    table.sort(ranked, function(a, b) return a.total > b.total end)
    local rank, last_total = 0, nil
    for _, entry in ipairs(ranked) do
        if entry.total ~= last_total then
            rank, last_total = rank + 1, entry.total
        end
        setCell(entry.row, RANK, tostring(rank))
    end

    vals.cols = tostring(COLS)
    self.script_state = JSON.encode(vals)
end

function setCell(r, c, value)
    local i = r * COLS + c
    vals[tostring(i)] = value
    self.editInput({index = i, value = value})
end

function createAll()
    local f_color = {0, 0, 0, 100}

    -- Inputs are created row by row, so a cell's input index is r * COLS + c.
    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            local x, width, alignment, validation = table.unpack(COLUMNS[c + 1])
            self.createInput({
                value = vals[tostring(r * COLS + c)],
                input_function = "saveInput",
                tooltip = "",
                label = "",
                function_owner = self,
                alignment = alignment,
                tab = 2,
                validation = validation,
                position = {x, 0.1, ROW_Z + r * ROW_GAP},
                width = width,
                height = 130,
                font_size = 80,
                scale = {x = 1, y = 1, z = 1},
                font_color = f_color,
                color = {0, 0, 0, 0},
            })
        end
    end

    -- king
    self.createInput({
        value = self.getName(),
        input_function = "saveName",
        tooltip = "",
        label = "",
        function_owner = self,
        alignment = 2,
        tab = 2,
        position = {-0.3, 0.1, -0.76},
        width = 1150,
        height = 160,
        font_size = 100,
        scale = {x = 1, y = 1, z = 1},
        font_color = f_color,
        color = {0, 0, 0, 0},
    })

    -- date
    self.createInput({
        value = self.getDescription(),
        input_function = "saveDescription",
        tooltip = "",
        label = "",
        function_owner = self,
        alignment = 3,
        tab = 2,
        position = {1.951, 0.1, -0.72},
        width = 200,
        height = 160,
        font_size = 60,
        scale = {x = 1, y = 1, z = 1},
        font_color = f_color,
        color = {0, 0, 0, 0},
    })
end

function removeAll()
    for _, input in pairs(self.getInputs()) do
        self.removeInput(input.index)
    end
    self.setName("")
    self.setDescription("")
end

function reloadAll()
    removeAll()
    createAll()
    updateSave()
end

function saveInput(_obj, _player, value, selected)
    updateSave()
end

function saveName(_obj, _player, value)
    _obj.setName(value)
end

function saveDescription(_obj, _player, value)
    _obj.setDescription(value)
end
