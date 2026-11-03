-- tts: 427c3a
-- Calibration overrides for this house's board scan.
-- All settings and their defaults are in src/lib/house_tile.lua.
HOUSE = {
	gx = 0.001,
	gy = 0.01,
	name_x = -0.19,
	name_width = 3000,
	achievement_x = 1.3,
	achievement_groups = {
		{3, 0.45, 0.065},
		{5, 0.86, 0.065},
		{4, 1.33, 0.065},
	},
}

-- sync:include lib/house_tile.lua
