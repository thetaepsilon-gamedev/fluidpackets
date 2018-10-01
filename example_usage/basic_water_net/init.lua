local fluidpackets = modtable("ds2.minetest.fluidpackets")


_mod = {}
local water = "default_water"
_mod.water = water

-- ok, no more of this tree log pipe business...
local mn = minetest.get_current_modname()
_mod.modname = mn
local mp = minetest.get_modpath(mn).."/"
_mod.modpath = mp
dofile(mp.."nodes.lua")

local controller = dofile(mp.."water_map.lua")
_mod.controller = controller
dofile(mp.."globalstep.lua")
water_net_insert = controller.insert


_mod = nil

