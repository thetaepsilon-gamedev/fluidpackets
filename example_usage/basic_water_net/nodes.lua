local mn = _mod.modname
local n = mn..":basic_pipe"
local water = _mod.water

local tp = "waternet_simple_pipe_"
local t = tp.."top.png"
local s = tp.."side.png"
local b = tp.."bottom.png"
local tiles = { t, b, s, s, s, s }

local groups = {
	cracky = 2,
}

minetest.register_node(n, {
	description = "Basic test pipe",
	tiles = tiles,
	fluidpackets = {
		[water] = {
			type = "pipe",
			dirtype = "facedir_simple",
			capacity = 0.5,
		}
	},
	paramtype2 = "facedir",
	groups = groups,
	sounds = default.node_sound_metal_defaults(),
	on_place = minetest.rotate_node,
})

