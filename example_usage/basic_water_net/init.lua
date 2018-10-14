local fluidpackets = modtable("ds2.minetest.fluidpackets")


_mod = {}
local water = "default_water"
_mod.water = water

-- ok, no more of this tree log pipe business...
local mn = minetest.get_current_modname()
_mod.modname = mn
local mp = minetest.get_modpath(mn).."/"
_mod.modpath = mp
_mod.groups = {
	cracky = 2,
	basic_water_net = 1,
}

dofile(mp.."nodes.lua")
dofile(mp.."devices.lua")

local controller = dofile(mp.."water_map.lua")
_mod.controller = controller
dofile(mp.."globalstep.lua")
dofile(mp.."inserter_item.lua")



_mod = nil

