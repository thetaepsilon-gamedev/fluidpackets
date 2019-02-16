--[[
Fluid map controller object

A single entry point for the following needs:
+ introducing packets into the network from e.g. ABMs
+ triggering a step to happen
+ insert a hashmap of packets when an area becomes loaded.
+ get all packets present in a map pushed to a function for saving.

map.insert(pos, volume)
map.step()
map.bulk_load(packetset)
map.iterate(sink  = function(hash, packet) -> bool, false halts loop)
]]

local lib = "com.github.thetaepsilon.minetest.libmthelpers"
local pairs_noref = mtrequire(lib..".iterators.pairs_noref")

local run_packet_batch = _mod.m.batch.run_packet_batch
local __open_runlater_scope = _mod.m.runlater.new

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





-- callback wrapper translation moved here from fluid_packet_batch.lua;
-- this callback wrapping is in the process of going away
-- (i.e. eventually try_insert_volume will be constructed as a closure,
-- retaining references to the callbacks it needs itself).
local try_insert_volume_unwrapped = _mod.m.map_insert.try_insert_volume

local l = "_try_insert_volume()"
local callbacks_ = _mod.util.callbacks.callback_invoke__(defcallbacks, l)
local _try_insert_volume = function(packetmap, ivolume, tpos, callback, indir, enqueue_at)
	local c = callbacks_(callback)
	return try_insert_volume_unwrapped(packetmap, ivolume, tpos, c, indir, enqueue_at)
end






local i = {}
local n = "fluid_map_controller.bulk_load(): "
local err_dup = n.."key collision while bulk loading packet set, key was "
local err_concurrent = "fluid map controller re-entered!? previous entry point was "
local err_concurrent2 = " , trying to be replaced by "
local merge = _mod.util.tableset.insert_set_nocollide_(err_dup)
local dummy = function() end
local construct = function(callbacks)
	-- only run_packet_batch() really knows what this looks like...
	assert(type(callbacks) == "table")

	-- start out with an empty packet map.
	local packetmap = {}
	-- enqueuer accessed by try_insert_volume below.
	-- NB: must use get_scope_with_try_insert below to open runlater scope!
	local __enqueuer, __commit

	-- as things open and close scopes below,
	-- we need to ensure we don't nest them
	-- (that would be undesirable for the same reason we defer to begin with).
	local __locked = nil

	local __try_insert_volume = function(tpos, ivolume, indir)
		assert(ivolume ~= nil)
		return _try_insert_volume(packetmap, ivolume, tpos, callbacks, indir, __enqueuer)
	end
	local __close_scope = function()
		assert(__locked)
		__commit()
		__enqueuer = nil
		__commit = nil
		__locked = nil
	end
	local take_lock = function(owner)
		assert(
			locked == nil,
			err_concurrent .. tostring(__locked) ..
			err_concurrent2 .. tostring(owner))
		__locked = owner or "[unknown]"
	end
	local get_scope_with_try_insert = function(owner)
		-- TODO: this ought to belong in it's own encapsulated class,
		-- so we don't end up tip-toeing around the lock so much
		-- (and so we can't accidentally use the methods)
		take_lock(owner)
		local enqueue, commit = __open_runlater_scope()
		__enqueuer = enqueue
		__commit = commit

		return enqueue, __close_scope, __try_insert_volume
	end

	local i = {}
	i.step = function()
		local enqueue, close_scope, try_insert = get_scope_with_try_insert("step()")

		-- create a list of currently present keys in the map.
		-- the rationale for this is described in fluid_packet_batch.lua.
		local packetkeys = get_key_list(packetmap)

		-- then execute...
		run_packet_batch(packetmap, packetkeys, callbacks, enqueue, try_insert)

		-- ... then:
		-- batch processing complete;
		-- take care of any runlater tasks now
		close_scope()
	end

	-- XXX: would it break things massively if we stretched the scope time,
	-- so that runlater only happens at the next full batch?
	-- this would require a more intelligent system for callbacks though.
	-- (including having to name callbacks and possibly only run once per node...)
	i.insert = function(tpos, ivolume, indir)
		local _, commit, try_insert = get_scope_with_try_insert("insert()")
		local remainder, status = try_insert(tpos, ivolume, indir)
		commit()
	end
	i.iterate = function(sink)
		take_lock("iterate()")	-- oi, stop trying to save mid-batch
		for k, v in pairs(packetmap) do
			if not sink(k, v) then
				-- where are RAII/using scopes when you need them...
				__locked = nil
				return false
			end
		end
		__locked = nil
		return true
	end
	i.bulk_load = function(packetset)
		take_lock("bulk_load()")	-- similar to above
		merge(packetmap, packetset)
		__locked = nil
	end

	return i
end
i.mk = construct



return i

