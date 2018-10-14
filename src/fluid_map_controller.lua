--[[
Fluid map controller object

A single entry point for the following needs:
+ introducing packets into the network from e.g. ABMs
+ triggering a step to happen
+ insert a hashmap of packets when an area becomes loaded.
+ get an iterator for all hash, packet pairs (for saving)

map.insert(pos, volume)
map.step()
map.bulk_load(packetset)
map.iterate()
]]

local lib = "com.github.thetaepsilon.minetest.libmthelpers"
local pairs_noref = mtrequire(lib..".iterators.pairs_noref")

local run_packet_batch = _mod.m.batch.run_packet_batch
local try_insert_volume = _mod.m.batch.try_insert_volume

-- get a list of keys from a table, used in step() below
local get_key_list = function(t)
	local list = {}
	local index = 0
	for k, _ in pairs(t) do
		index = index + 1
		list[index] = k
	end
	return list
end





local i = {}
local n = "fluid_map_controller.bulk_load(): "
local err_dup = n.."key collision while bulk loading packet set, key was "
local merge = _mod.util.tableset.insert_set_nocollide_(err_dup)
local construct = function(callbacks)
	-- only run_packet_batch() really knows what this looks like...
	assert(type(callbacks) == "table")

	-- start out with an empty packet map.
	local packetmap = {}

	local i = {}
	i.step = function()
		-- create a list of currently present keys in the map.
		-- the rationale for this is described in fluid_packet_batch.lua.
		local packetkeys = get_key_list(packetmap)
		run_packet_batch(packetmap, packetkeys, callbacks)
	end
	i.insert = function(tpos, ivolume, indir)
		try_insert_volume(packetmap, ivolume, tpos, callbacks, indir)
	end
	i.iterate = function()
		return pairs_noref(packetmap)
	end
	i.bulk_load = function(packetset)
		merge(packetmap, packetset)
	end

	return i
end
i.mk = construct



return i

