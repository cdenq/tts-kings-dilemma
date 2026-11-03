-- Shared script for the 12 house tiles (Dukes and Marquises).
-- Each house's file in src/houses sets a HOUSE table with only the values
-- that differ from DEFAULTS below, then includes this file.

toggleSymbol = "\u{2717}"
hideButtonBack = true

thick = 0.12

-- Calibration values; each house overrides what its board scan needs.
local DEFAULTS = {
	gx = 0, gy = 0,         -- global offsets for calibrating against scan error
	name_x = -0.16,         -- x of the house name text field
	name_width = 3400,      -- width of the house name text field
	prestige_gap = 0.062,   -- extra gap after column 5 of the prestige/crave grids
	agenda_gap = 0.78,      -- extra gap after column 4 of the agenda grid
	achievement_x = 1.31,
	achievement1_y = 0.13,  -- the narrative achievement
	-- Remaining achievements, numbered from 2 in order: {count, y, spacing}
	achievement_groups = {
		{3, 0.445, 0.065},
		{4, 0.785, 0.065},
		{3, 1.18, 0.065},
	},
}

H = {}
for k, v in pairs(DEFAULTS) do H[k] = v end
for k, v in pairs(HOUSE or {}) do H[k] = v end
gx, gy = H.gx, H.gy

function initCustomButtons()
	thick = 0.12

	createTextField('Name', 'txt', H.name_x, -0.8)

-- prestige tracker. Potentially worth simplifying the on_click to fill up to clicked square, rather than 1 by 1.
	local dx, dy, p_unit = -2.05, -0.545, 0.069
	for i=0,9 do
		for j=0,11 do
			setupButton(string.format('prestige%d_%d', i, j), "toggleB", dx + i * p_unit + (i > 4 and H.prestige_gap or 0), dy + j * p_unit)
		end
	end

-- crave tracker.
	dy = 0.41
	local number = 0
	for i=0,9 do
		for j=0,5 do
			setupButton('crave' .. number, "toggleB", dx + i * p_unit + (i > 4 and H.prestige_gap or 0), dy + j * p_unit)
			number = number + 1
		end
	end

-- agenda trackers
	dx = -0.63; dy = 0.728
	for i=0,7 do
		for j=0,2 do
			setupButton(string.format('agenda%d_%d', i, j), "toggleB", dx + i * 0.072 + (i > 3 and H.agenda_gap or 0), dy + 0.105 * j)
		end
	end

-- achievement trackers
	dx = H.achievement_x; dy = -0.64
	-- narrative
	setupButton('achievement1', 'toggleB', dx, H.achievement1_y + dy)
	local n = 2
	for _, group in ipairs(H.achievement_groups) do
		local count, y, spacing = group[1], group[2], group[3]
		for j=0,count-1 do
			setupButton('achievement' .. n, 'toggleB', dx, y + dy + j*spacing)
			n = n + 1
		end
	end

end

function initButtonsTable()
	buttons = {}
	inputs = {}
	buttons.count = 0

	buttons.counter = {
	width = 0, height = 0, font = 800,
	ox = 0.08, oz = -0.08, ow = 300, oh = 300
}
buttons.toggleA = {
width = 300, height = 300, font = 400
}
buttons.toggleB = {
width = 300, height = 300, font = 400
}
buttons.txt = {
width = H.name_width, height = 500, font = 350, alignment = 3
}
buttons.editBox = {
width = 3800, height = 3600, font = 250, alignment = 2
}

end

function forceSave()
	local data_to_save = {buttons = {}, inputs = {}}
	for i, v in pairs(buttons) do
		if i ~= "count" then
			if v.label == "\u{2717}" then
				data_to_save.buttons[i] = "u{2717}"
			else
				data_to_save.buttons[i] = v.label
			end
		end
	end
	local inputs = self.getInputs()
	for _, v in pairs(inputs) do
		data_to_save.inputs[v.label] = v.value
	end
	saved_data = JSON.encode_pretty(data_to_save)
	-- saved_data = ""
	self.script_state = saved_data
	return saved_data
end

function onload(saved_data)
	initButtonsTable()
	loaded_data = JSON.decode(saved_data)
	if loaded_data ~= nil then
		for i,v in pairs(loaded_data.buttons) do
			buttons[i] = {label = v}
		end
		for i,v in pairs(loaded_data.inputs) do
			inputs[i] = v
		end
	end
	initCustomButtons()
end


function dud()
end

function clickedToggle(index)
	if buttons[index].label == "" then
		buttons[index].label = "\u{2717}"
	else
		buttons[index].label = ""
	end
	self.editButton(buttons[index])
	forceSave()
end

function createTextField(name, type, x, z)
	local input_parameters = {}
	input_parameters.height = buttons[type].height
	input_parameters.width = buttons[type].width
	input_parameters.font_size = buttons[type].font
	input_parameters.alignment = buttons[type].alignment

	input_parameters.input_function = "editTextField"
	input_parameters.function_owner = self
	input_parameters.label = name
	input_parameters.scale = {0.1, 0.1, 0.1}
	input_parameters.position = {gx + x, thick, gy + z}
	if hideButtonBack then
		input_parameters.color = {1, 1, 1, 0}
		input_parameters.font_color = {0, 0, 0, 100}
	end

	if inputs[name] ~= nil then
		input_parameters.value = inputs[name]
	end
	self.createInput(input_parameters)
end

function editTextField(object, color, text, editing)
	if not editing then
		forceSave()
	end
end

function setupButton(name, type, x, z)
	local button_parameters = {}
	button_parameters.index = buttons.count
	button_parameters.height = buttons[type].height
	button_parameters.width = buttons[type].width
	button_parameters.font_size = buttons[type].font
	if type == "counter" then
		button_parameters.click_function = "dud"
		button_parameters.label = "0"
		createpm(name, type, gx + x, gy + z)
		button_parameters.index = buttons.count
	elseif type == "toggleA" or type == "toggleB" then
		self.setVar("toggleClick_" .. name, function () clickedToggle(name) end)
		button_parameters.click_function = "toggleClick_" .. name
		button_parameters.label = ""
	else
		button_parameters.click_function = "dud"
		button_parameters.label = "0"
	end

	if hideButtonBack then
		button_parameters.color = {1, 1, 1, 0}
		button_parameters.font_color = {0, 0, 0, 100}
	end
	button_parameters.scale = {0.1, 0.1, 0.1}
	button_parameters.position = {gx + x, thick, gy + z}
	button_parameters.function_owner = self

	if buttons[name] ~= nil then
		if buttons[name].label == "u{2717}" then
			button_parameters.label = "\u{2717}"
		else
			button_parameters.label = buttons[name].label
		end

	end

	self.createButton(button_parameters)
	buttons[name] = button_parameters
	buttons.count = buttons.count + 1
end

function createpm(name, type, x, z)
	local button_parameters = {}
	button_parameters.index = buttons.count
	button_parameters.height = buttons[type].oh
	button_parameters.width = buttons[type].ow
	button_parameters.font_size = buttons[type].font * 0.7
	self.setVar("add_" .. name, function (obj, color, alt_click) add(name, 1, alt_click) end)
	button_parameters.click_function = "add_" .. name
	button_parameters.label = "+"
	button_parameters.function_owner = self
	button_parameters.scale = {0.1, 0.1, 0.1}
	if hideButtonBack then
		button_parameters.color = {1, 1, 1, 0}
		button_parameters.font_color = {0, 0, 0, 100}
	end
	button_parameters.position = {x + buttons[type].ox, thick, z + buttons[type].oz}
	self.createButton(button_parameters)
	buttons["p_" .. name] = button_parameters
	buttons.count = buttons.count + 1

	button_parameters.index = buttons.count
	self.setVar("sub_" .. name, function (obj, color, alt_click) add(name, - 1, alt_click) end)
	button_parameters.click_function = "sub_" .. name
	button_parameters.label = "-"
	button_parameters.position = {x - buttons[type].ox, thick, z + buttons[type].oz}
	self.createButton(button_parameters)
	buttons["m_" .. name] = button_parameters
	buttons.count = buttons.count + 1
end

function add(name, amount, alt_click)
	if alt_click then amount = amount * 10 end
	buttons[name].label = tostring(tonumber(buttons[name].label) + amount)
	self.editButton(buttons[name])
	forceSave()
end