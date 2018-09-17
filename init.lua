local mn = minetest.get_current_modname()
local mp = minetest.get_modpath(mn).."/"
local mps = mp.."src/"

local dofileargs = function(path, ...)
	local f, err = loadfile(path)
	if not f then error("dofileargs: "..err) end
	return f(...)
end

local function subloader(relpath, ...)
	local path = mps..relpath
	return dofileargs(path, subloader, ...)
end

run_packet_batch = subloader("fluid_packet_batch.lua")
