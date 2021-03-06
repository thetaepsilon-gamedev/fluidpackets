local subloader = ...

-- things that can happen to a packet:
-- * packet is in a directed pipe. attempt to shift packet volume.
-- * packet is in air. drop the packet (as an entity?)
-- * packet is in a device (as input). ingress into the device,
--	try to add any created packets to the map.
-- * packet ends up stuck in a node. vanish/forget?

-- the non-fluid transport node cases don't require any particular handling,
-- other than deferring their handling until after the batch,
-- and obviously removing them from the packet map.
-- so therefore we can lump together those as one case;
-- this boils down the case handling to something like the following:
-- * directed pipe
-- * fluid devices
-- * non-fluid-bearing nodes
-- this can be switched on the node def's fluid handling type, if any.



--[[
-- internal format of packets:
{
	-- xyz components for a minetest position
	x = ..., y = ..., z = ...,
	-- volume of the water packet held at this position.
	-- assumed non-zero if this exists;
	-- non-existant entries get cleared from the table.
	volume = ...,
}
]]



-- bearer_def mentioned below is a sub-table of node definition tables.
-- it's position in a node defintion is described in fluid_bearer_def_util.lua
--[[
	bearer_def = {
		type = "...",	-- enum fluid_bearer_type
		ingress = func,	-- type == "device": ingress handler.
			-- read below for how this must work
		dirtype = "...",	-- enum fluid_dir_type
			-- used if type == "pipe",
			-- defines how a pipe node's input/output directions
			-- are determined from the node def or callbacks.

		capacity = "...",	-- numerical volume
			-- the max (input) capacity of this node, in m^3.
			-- for pipes, this is just how much fluid they hold.
			-- for devices, this is the size of the ingress buffer.
			-- XXX: variable capacity dependent on node props,
			-- e.g. machine upgrades?

		outdir = xyz,
			-- used if dirtype == "facedir_simple".
			-- outgoing offset vector of fluid direction,
			-- which will be rotated relative to param2.
			-- for this form of pipe, all other faces are inputs.
			-- node is assumed to have paramtype2 == facedir.
			-- TODO: stripping param2 of colour bits if needed...
			-- if missing, assumed to be straight up (pre-rotation),
			-- such that the direction corresponds to facedir placement.

		indir = function(node, meta, indir) end,
			-- for any bearer type, checks if a given direction
			-- is allowed for input into this node.
			-- note that this vector points inwards towards the node.
			-- must return a boolean value indicating yes/no.
			-- if this function is absent, true is always assumed,
			-- effectively meaning any direction is allowed.
	}
]]



local lib = "com.github.thetaepsilon.minetest.libmthelpers"
local newstack = mtrequire(lib..".datastructs.stack").new

local mk_debug = _mod.m.debug.mk_debug
local debug = mk_debug("fluid_packet_batch")



local i = {}





-- load node at position and fetch it's bearer definition, if any
local get_node_and_def = _mod.m.bearer_def.get_node_and_def

-- node position hashing in packet map
local isint = _mod.util.math.isint
local hash = _mod.hash

local vadd = vector.add





-- directed pipe: move fluid in appropriate direction, if possible.
local get_node_offset = subloader("node_def_directed_pipe.lua")
local run_packet_directed = function(packet, node, bearer_def, enqueue_current, try_insert_volume)
	local offset = get_node_offset(node, bearer_def)
	-- remember, packets are valid position tables
	local target = vadd(packet, offset)

	-- try_insert_volume handles air among other things.
	-- note: the "target" vector is assumed possibly consumed by this!
	local volume = packet.volume
	assert(volume ~= nil)
	local remainder =
		try_insert_volume(
			target, volume, offset)

	-- run_packet_batch will remove any packets that end up with zero volume.
	packet.volume = remainder

	-- no pending action(s) to run for now
end



--[[
-- fluid device: invoke it's callback with the amount of ingress fluid.
-- signature looks like the following:
callback = function(node, meta, volume_in, inject_packet)
-- and must return a remaining buffer fluid volume;
-- this remaining value is clamped to the range 0..volume_in.
-- inject_packet is a function that can be called
-- to insert a fluid packet at an offset to this node:
local inject_packet = function(volume, offset)
-- returning the remaining fluid that could not be inserted if any;
-- this allows a node to react to backlog conditions if desired.

-- note, the callback is not passed a position;
-- to avoid issues with world side effect orderings and such,
-- modifying the world from this callback is *heavily discouraged*.
-- return values:
* adformentioned remaining buffer volume -
	if nil, the buffer volume is simply cleared (e.g. assumed == 0).
* an optional closure taking a single xyz position argument.
	it will be invoked with the node's real world position
	*after* all packets in the batch have been processed,
	and execution order with respect to other nodes is indeterministic.
]]
local youpleb = " (this is a BUG in a fluid packet callback)"
local checkc = function(v, l)
	assert(isint(v), "offset." .. l ..
		" was not an integer number of nodes"..youpleb)
	return v ~= 0
end
local checkv = function(o)
	local x = checkc(o.x, "x")
	local y = checkc(o.y, "y")
	local z = checkc(o.z, "z")
	-- at least one vector component must be ~= 0;
	-- otherwise, the position refers to the initiating node!
	local valid = x or y or z
	assert(valid, "offset vector must be non-zero"..youpleb)
end
local neg = "inject_packet() was called with a non-positive volume"..youpleb
local mk_inject_packet_ = function(basepos, try_insert_volume)
	return function(volume, offset)
		assert(volume > 0, neg)
		-- in order to maintain proper hashing,
		-- the offsets must be whole integers.
		-- also, least one component must be non-zero.
		checkv(offset)
		local target = vadd(basepos, offset)
		return try_insert_volume(target, volume, offset)
	end
end

local clamp = _mod.util.math.clamp
local getmeta = _mod.util.metatoken.get_meta_ref_token
local run_packet_device = function(packet, node, bearer_def, enqueue_current, try_insert_volume)
	-- set up the packet injector for this callback
	local inject = mk_inject_packet_(packet, try_insert_volume)

	-- prepare other initial data for the callback.
	-- note volume is enforced by previous steps moving into the ingress buffer,
	-- so we can just pass the current pressure value to the callback.
	local initial = packet.volume
	local meta = getmeta(packet)
	local remaining, runlater = bearer_def.ingress(node, meta, initial, inject)

	if remaining == nil then remaining = 0 end
	assert(type(remaining) == "number")
	local volume = clamp(remaining, 0, initial)
	packet.volume = volume

	enqueue_current(runlater)
end





-- handle a single packet when it's starting block is known to be a bearer.
local bearer_type = {
	pipe = run_packet_directed,
	device = run_packet_device,
}
local defpleb = " (this is an ERROR in a node definition)"
local badtype = "unknown node_def.fluidpackets.type enum"..defpleb
local handle_single_packet =
	function(packet, hash, node, def, enqueue_at, try_insert_volume)
		-- argh, double indent

		-- try to find approprioate sub-handler for the bearer type.
		local handle = bearer_type[def.type]
		if not handle then
			error(badtype)
		end

		-- enqueue wrapper passed to handlers that remembers the current position.
		local enqueue_current = function(runtasks)
			return enqueue_at(packet, runtasks)
		end

		-- now invoke sub-type handler...
		debug("packet @"..hash.." inside node of type "..def.type)
		handle(packet, node, def, enqueue_current, try_insert_volume)
	-- end RIP indent
end





-- handle the case of suspending a packet if it goes out of the loaded world.
-- if this returns nil, the packet is to be "detached"
-- from the packet map and forgotten about -
-- this may be because the packet has been consumed by a callback.
local handle_suspend = function(packet, hash, on_packet_unloaded)
	debug("packet @"..hash.." fell out of the world")
	-- try to see if a callback wants to handle this case.
	if on_packet_unloaded(packet, hash) then
		-- if it said it could handle it, then detach it;
		-- otherwise leave it be.
		-- this allows the callback to "consume" the packet,
		-- and store it elsewhere having the sole ref. to it.
		packet = nil
	end

	return packet
end






-- handle deleting a packet when it is either suspended or volume set to zero.
-- this gets rid of unnecessary work,
-- as zero sized packets can't affect volumes.
-- additionally, it keeps the size of the packet map down.
local handle_delete = function(packet, key, packetmap)
	local hash = key
	local delete = function(reason)
		debug("packet @"..hash.." "..reason)
		packetmap[key] = nil
	end

	-- if the packet was explicitly set to nil,
	-- it was "detached" and we can no longer touch it.
	if packet == nil then
		delete("packet was marked suspended, removing from map")
		return
	end

	-- delete if the volume shrinks to zero.
	if packet.volume == 0 then
		delete("reached zero and vanished")
	end
end





local checkpacket = function(packet, hash)
	local msg = "packet with hash " .. hash .. " "
	assert(packet ~= nil, msg .. "was nil from internal table")
	assert(packet.volume ~= nil, msg .. "had nil volume")
end





-- and now, the main batch running routine.
-- this is provided a list of hashed keys which should be processed;
-- this is fixed at the beginning of the batch instead of using pairs().
-- the reason for this is a) concurrent inserts during pairs() isn't allowed,
-- and b) it prevents a potential instant movement problem;
-- packets created at previously empty positions must wait until the next turn.
local l = "run_packet_batch()"
local get_member =
	_mod.util.callbacks.get_interface_member_(
		"new_BatchRunner",
		"IBatchRunnerCallbacks")

local get_member2 =
	_mod.util.callbacks.get_interface_member_(
		"new_BatchRunner",
		"INodeDefLookup")

local new_BatchRunner = function(IBatchRunnerCallbacks, INodeDefLookup, packetmap)
	local on_packet_unloaded =
		get_member(IBatchRunnerCallbacks, "on_packet_unloaded")
	local on_packet_destroyed =
		get_member(IBatchRunnerCallbacks, "on_packet_destroyed")

	local get_node_and_def = get_member2(INodeDefLookup, "get_node_and_def")



	local run_packet_batch = function(packetkeys, enqueue_at, try_insert_volume)
		for i, key in ipairs(packetkeys) do
			local packet = packetmap[key]
			local hash = key
			local node, def = get_node_and_def(packet)

			-- some sanity checks on internal structure.
			checkpacket(packet, hash)

			if node == nil then
				-- packet is inside unloaded area?
				packet = handle_suspend(packet, hash, on_packet_unloaded)
			elseif def == nil then
				debug("packet @"..hash.." nullified inside a non-bearer")
				on_packet_destroyed(packet, hash, node)
				packet.volume = 0
			else
				handle_single_packet(
					packet, hash, node, def, enqueue_at, try_insert_volume)
			end

			-- handle potentially deleting the packet when done,
			-- for e.g. no volume left
			handle_delete(packet, key, packetmap)
		end
	end

	local IBatchRunner = {
		run_packet_batch = run_packet_batch,
	}
	return IBatchRunner
end
i.new_BatchRunner = new_BatchRunner



return i

