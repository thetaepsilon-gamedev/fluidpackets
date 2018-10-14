-- stuff for save and restore for a fluid map controller;
-- suspended packets are moved into a table of tables (see below)
-- where they can be periodically synced to disk,
-- and where they can be pulled from when an area becomes re-activated.

local i = {}





-- get the chunk associated with a block position.
local mod = math.fmod
local floor = math.floor
local cid = function(v)
	assert(mod(v, 1.0) == 0)
	return floor(v / 16)
end
local s = ":"
local classify_chunk = function(pos)
	local x = cid(pos.x)
	local y = cid(pos.y)
	local z = cid(pos.z)
	return x..s..y..s..z
end





-- creates a blank chunk table with the requisite __exists sub-table;
-- this sub-table is used to perform fast checks for a given position's presence.
local mk_chunktable = function()
	return {
		__exists = {},
	}
end
i.mk_chunktable = mk_chunktable





-- implement on_packet_unloaded callback for fluid packet batch.
-- when a packet is marked unloaded, figure out which chunk it's in,
-- and then assign it into a sub-table for that chunk.
-- this grouping of packets by their containing chunk is useful later.
-- chunktable is expected to have a __exists sub-table.
local n = "create_table_unload_packet: on_packet_unloaded callback: "
local msg_duplicate = n.."caller violated invariant, packet hash inserted twice: "
local create_table_unload_packet = function(chunktable)
	assert(type(chunktable) == "table")
	local exists = chunktable.__exists
	assert(type(exists) == "table")

	return function(packet, hash)
		local chunkid = classify_chunk(packet)

		-- create a table for this chunk if it doesn't exist.
		local chunkset = chunktable[chunkid]
		if chunkset == nil then
			chunkset = {}
			chunktable[chunkid] = chunkset
		end

		-- unloading a packet twice shouldn't be possible...
		-- just to ensure a bug doesn't clobber an existing suspended packet.
		if chunkset[hash] ~= nil then
			--print("old", dump(chunkset[hash]))
			--print("new", dump(packet))
			error(msg_duplicate..hash)
		end

		chunkset[hash] = packet
		-- update suspended packet existance for use in on_load_hint.
		exists[hash] = true

		-- indicate that we handled the packet so it doesn't get re-inserted,
		-- and to indicate we "consumed" the packet from the packet map.
		return true
	end
end





--[[
implement on_load_hint callback.
By maintaining an existence list above we can implement this quickly;
in the optimum case where either a packet is known to be suspended,
or there simply isn't any packet there at all, we can return nil fast.
Otherwise, pass back the entire chunk's packet set to be re-activated.
Said chunkset gets removed from the main chunk table and existence map,
so subsequent accesses will return to the fast path.
]]
local msg_wtf = "internal inconsistency error: " ..
		"position marked present in __exists but not found in chunk table"
local create_table_load_hint = function(chunktable)
	assert(type(chunktable) == "table")
	local exists = chunktable.__exists
	assert(type(exists) == "table")

	return function(pos, hash)
		if not exists[hash] then
			return nil
		end

		local chunkid = classify_chunk(pos)
		-- if it's present in __exists,
		-- it must have been assigned in the unload callback above.
		local chunkset = chunktable[chunkid]
		assert(chunkset ~= nil, msg_wtf)
		assert(chunkset[hash] ~= nil, msg_wtf)

		-- clear out the __exists entries to avoid tripping the above next time
		for hash, _ in pairs(chunkset) do
			exists[hash] = nil
		end
		-- detach the chunk set and return for merging
		chunktable[chunkid] = nil
		return chunkset
	end
end



-- use the above to implement a secondary load hint for e.g. LBMs;
-- this may be useful as the above callback will only fire
-- when a packet tries to move into a suspended chunk;
-- this LBM trigger can instead load packets in on load
-- (if the on_packet_load_hint doesn't fire first).
-- the bulk_load function should ideally be something like
-- the bulk_load operation from a fluid map controller.
-- ideally, this LBM should be assigned to a node group covering all pipes.
-- returns a function compatible with LBM func signature but only needs pos arg.
local hash = _mod.hash
local create_table_lbm_hint = function(chunktable, bulk_load)
	assert(type(bulk_load) == "function")
	local hashed_hint = create_table_load_hint(chunktable)

	return function(pos, node)	-- node not used, part of LBM signature
		local h = hash(pos)
		local set = hashed_hint(pos, h)
		if set then
			bulk_load(set)
		end
	end
end
i.create_table_lbm_hint = create_table_lbm_hint






-- typically you would probably want to use all of the above together.
-- however, this isn't possible due to dependency ordering:
-- the lbm hint most likely requires a fluid map controller to exist first,
-- which in turn requires the inner set of callbacks first.
-- so first just provide for creating the callbacks given a chunk table.
local create_suspend_callbacks = function(chunktable)
	return {
		on_packet_load_hint = create_table_load_hint(chunktable),
		on_packet_unloaded = create_table_unload_packet(chunktable),
	}
end
i.create_suspend_callbacks = create_suspend_callbacks



return i

