local mn = minetest.get_current_modname()
local mp = minetest.get_modpath(mn).."/"
local mps = mp.."src/"
_mod = {}

local dofileargs = function(path, ...)
	local f, err = loadfile(path)
	if not f then error("dofileargs: "..err) end
	return f(...)
end

local function subloader(relpath, ...)
	local path = mps..relpath
	return dofileargs(path, subloader, ...)
end



_mod.m = {}
_mod.m.debug = subloader("debug_logging.lua")

_mod.util = {}
_mod.util.math = subloader("math_util.lua")
_mod.util.callbacks = subloader("callback_util.lua")
_mod.util.metatoken = subloader("meta_ref_token.lua")

_mod.hash = subloader("node_pos_hash.lua")
_mod.m.inputcheck = subloader("node_def_input_check.lua")
local m_batch = subloader("fluid_packet_batch.lua")
_mod.m.batch = m_batch
_mod.m.controller = subloader("fluid_map_controller.lua")
_mod.util.bearer_def = subloader("fluid_bearer_def_util.lua")

_mod.m.bearer_helpers = subloader("fluid_bearer_helpers.lua")



local export = subloader("setup_interface.lua")
modtable_register("ds2.minetest.fluidpackets", export)

_mod = nil

