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

local m_controller = dofile(mp.."water_map.lua")
_mod.controller = m_controller.controller
dofile(mp.."nodes.lua")
dofile(mp.."devices.lua")


dofile(mp.."globalstep.lua")
dofile(mp.."inserter_item.lua")

local e = {}
e.suspend_table = m_controller.chunktable
e.controller = m_controller.controller
basic_water_net = e


_mod = nil

