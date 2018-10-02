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





-- a simple device: explodes when water is ingressed into it.
local t = "waternet_explosive.png"
local tiles = {t,t,t,t,t,t}

-- chemists, tell me, how violent would 1m^3 of sodium be in water?
local n = mn..":sodium"
local explode = function(node, meta, volume, inject)
	local force = (volume ^ (1/3)) * 2
	return 0, function(pos)
		tnt.boom(pos, {radius=force,damage_radius=force})
	end
end
if minetest.global_exists("tnt") then
	minetest.register_node(n, {
		description = "Sodium explosive (don't get this wet)",
		tiles = tiles,
		groups = groups,
		sounds = default.node_sound_metal_defaults(),
		fluidpackets = {
			[water] = {
				type = "device",
				capacity = 2.0,
				ingress = explode,
			}
		},
	})
end

