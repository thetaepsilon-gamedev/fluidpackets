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
local vnew = vector.new



-- a small helper for stacks used as the "run later" deferral queue below.
-- runlater tasks consist of a position table with an extra "tasks" member,
-- which can either be a function or a list-like table of the same.
-- any such functions are invoked with that same position as their parameter;
-- they are intended to perform world effects *after* the main batch processing.
-- the rationale for this ordering is explained in the relevant code.
local create_enqueue = function(stack)
	local _enqueue = stack.push
	local push = function(pos, runtasks)
		if runtasks == nil then return end

		-- defensive copy so packet volume can't be interfered with...
		-- (in case a packet is used directly as a position)
		local task = vnew(pos)
		task.tasks = runtasks
		_enqueue(task)
	end

	return push
end



local i = {}





-- these are the default callbacks used for various operations below.
local null = _mod.util.callbacks.dummies.null
local const = _mod.util.callbacks.dummies.const_
local defcallbacks = {
	-- invoked when a packet ends up inside an inappropriate block.
	-- packet will be destroyed upon return.
	-- default: do nothing extra
	on_packet_destroyed = null,
	-- invoked to handle condition of attempting to insert volume
	-- into a node that isn't a bearer.
	-- passed target position, node, and would-be inserted volume;
	-- returns either a remainder of the consumed volume,
	-- or nil to indicate it couldn't be handled.
	on_escape = const(nil),

	-- called to retrieve the pipe definition of a given node, if any.
	-- this is used to allow change in definition format,
	-- including possible support for multiple liquid types in future.
	lookup_definition = nil,

	-- called when a packet is found in an unloaded area:
	-- provided packet and hash.
	-- the callback returns a truth value indicating whether it handled this;
	-- if and only if this is true, the callback may "consume" the packet,
	-- as it will be detached from the packet map.
	-- a false value will leave the packet where it is, unable to move.
	-- the default is to do nothing and leave the packet alone.
	on_packet_unloaded = const(false),

	-- called when a live packet doesn't exist yet at a target position.
	-- this is usually when some volume wants to be inserted there.
	-- if a node is loaded but no packet exists yet there,
	-- this callback is given the opportunity to return a packet set,
	-- which will be merged into the packet map.
	-- this can be used to ensure packets are re-loaded before merges,
	-- however some other mechanism for loading (like LBMs) is advised;
	-- this is simply to work around a weak ordering issue with LBMs.
	-- this function is passed position and hash,
	-- and may either return nil or a packet set.
	-- note that this packet set is not required to include the target pos.
	-- the default is to do nothing here.
	on_packet_load_hint = const(nil),
}





-- load node at position and fetch it's bearer definition, if any
local get_node_and_def = _mod.m.bearer_def.get_node_and_def

-- node position hashing in packet map
local isint = _mod.util.math.isint
local hash = _mod.hash



-- inserting volume into packet map
local try_insert_volume = _mod.m.map_insert.try_insert_volume

-- we have to wrap the callbacks up into function form to call the above;
-- if entered via run_packet_batch(), that function takes care of this.
local l = "run_packet_batch()"
local callbacks_ = _mod.util.callbacks.callback_invoke__(defcallbacks, l)
local try_insert_volume_ext = function(packetmap, ivolume, tpos, callback, indir)
	local c = callbacks_(callback)
	return try_insert_volume(packetmap, ivolume, tpos, c, indir)
end
i.try_insert_volume = try_insert_volume_ext



local vadd = vector.add



-- directed pipe: move fluid in appropriate direction, if possible.
local get_node_offset = subloader("node_def_directed_pipe.lua")
local run_packet_directed = function(packetmap, packet, node, bearer_def, callback, enqueue_current, enqueue_at)
	local offset = get_node_offset(node, bearer_def)
	-- remember, packets are valid position tables
	local target = vadd(packet, offset)

	-- try_insert_volume handles air among other things.
	-- note: the "target" vector is assumed possibly consumed by this!
	local remainder =
		try_insert_volume(
			packetmap, packet.volume, target, callback, offset, enqueue_at)
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
local mk_inject_packet_ = function(packetmap, basepos, callback, enqueue_at)
	return function(volume, offset)
		assert(volume > 0, neg)
		-- in order to maintain proper hashing,
		-- the offsets must be whole integers.
		-- also, least one component must be non-zero.
		checkv(offset)
		local target = vadd(basepos, offset)
		return try_insert_volume(packetmap, volume, target, callback, offset, enqueue_at)
	end
end

local clamp = _mod.util.math.clamp
local getmeta = _mod.util.metatoken.get_meta_ref_token
local run_packet_device = function(packetmap, packet, node, bearer_def, callback, enqueue_current, enqueue_at)
	-- set up the packet injector for this callback
	local inject = mk_inject_packet_(packetmap, packet, callback, enqueue_at)

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



local badtask1 =
	"a runlater task from a callback wasn't a function or table"..youpleb
local badtask2 =
	"an item in a runlater list from a callback wasn't a function"..youpleb
-- dispatch a runlater tasks list.
-- tasks which want to modify the world must be deferred until after a batch,
-- in order to prevent the kinds of problems discussed for run_packet_batch().
local run_deferred_tasks = function(taskstack)
	for i, pos in taskstack.ipairs() do
		-- tasks are stored inside the position table below
		local task = pos.tasks
		-- doubles up as a rudimentary tostring for positions...
		local ptrace = " @"hash(pos)

		local t = type(task)
		if t == "function" then
			-- single task, just run that
			task(pos)
		else
			if t == "table" then
				-- list of tasks, run them all
				local list = task
				for i, task in ipairs(list) do
					local t = type(task)
					assert(t == "function", badtask2..ptrace)
					task(pos)
				end
			else
				error(badtask1..ptrace..", got a "..t)
			end
		end
	end
end





-- handle a single packet when it's starting block is known to be a bearer.
local bearer_type = {
	pipe = run_packet_directed,
	device = run_packet_device,
}
local defpleb = " (this is an ERROR in a node definition)"
local badtype = "unknown node_def.fluidpackets.type enum"..defpleb
local handle_single_packet =
	function(packet, hash, node, def, packetmap, c, enqueue_at)
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
		handle(packetmap, packet, node, def, c, enqueue_current, enqueue_at)
	-- end RIP indent
end





-- handle the case of suspending a packet if it goes out of the loaded world.
-- if this returns nil, the packet is to be "detached"
-- from the packet map and forgotten about -
-- this may be because the packet has been consumed by a callback.
local handle_suspend = function(packet, hash, c)
	debug("packet @"..hash.." fell out of the world")
	-- try to see if a callback wants to handle this case.
	if c("on_packet_unloaded", packet, hash) then
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





-- and now, the main batch running routine.
-- this is provided a list of hashed keys which should be processed;
-- this is fixed at the beginning of the batch instead of using pairs().
-- the reason for this is a) concurrent inserts during pairs() isn't allowed,
-- and b) it prevents a potential instant movement problem;
-- packets created at previously empty positions must wait until the next turn.
local l = "run_packet_batch()"
local callbacks_ = _mod.util.callbacks.callback_invoke__(defcallbacks, l)
local run_packet_batch = function(packetmap, packetkeys, callbacks)
	local c = callbacks_(callbacks)
	local runlater = newstack()
	local enqueue = create_enqueue(runlater)

	for i, key in ipairs(packetkeys) do
		local packet = packetmap[key]
		local hash = key
		local node, def = get_node_and_def(packet, c)

		if node == nil then
			-- packet is inside unloaded area?
			packet = handle_suspend(packet, hash, c)
		elseif def == nil then
			debug("packet @"..hash.." nullified inside a non-bearer")
			c("on_packet_destroyed", packet, hash, node)
			packet.volume = 0
		else
			handle_single_packet(
				packet, hash, node, def, packetmap, c, enqueue)
		end

		-- handle potentially deleting the packet when done,
		-- for e.g. no volume left
		handle_delete(packet, key, packetmap)
	end

	-- batch processing complete;
	-- take care of any runlater tasks now
	run_deferred_tasks(runlater)
end
i.run_packet_batch = run_packet_batch



return i

