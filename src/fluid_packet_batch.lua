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
-- bearer_def is the value of node_def.fluidpackets in this structure:
--[[
node_def = {
	description = "...",	-- MT node def keys for other things as usual
	...,
	fluidpackets = {
		-- TODO: multiple fluid possibilities?
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

		fixeddir = {
			-- this table expected for dirtype == "fixed".
			input = function(vector) end,
				-- pure function which must answer a boolean,
				-- for a given input vector going into the node.
				-- true/false for "can fluid enter this way"?
			output = xyz,
				-- the one-way output port
		}

		outdir = xyz,
			-- used if dirtype == "facedir_simple".
			-- outgoing offset vector of fluid direction,
			-- which will be rotated relative to param2.
			-- for this form of pipe, all other faces are inputs.
			-- node is assumed to have paramtype2 == facedir.
			-- TODO: stripping param2 of colour bits if needed...
			-- if missing, assumed to be straight up (pre-rotation),
			-- such that the direction corresponds to facedir placement.
	}
	...,
}
]]



-- definition lookup as described above.
-- note, the definition may return nil, especially for ignore nodes.
local get_node_and_def = function(pos)
	local node = minetest.get_node(pos)
	local def = minetest.registered_nodes[node.name]

	-- XXX: I still don't know what to do for multiple fluid types yet...
	return node, def.fluidpackets
end

-- node position hashing in packet map
local isint = function(v) return ((v % 1.0) == 0) end
local hash = function(pos)
	assert(isint(pos.x))
	assert(isint(pos.y))
	assert(isint(pos.z))
	return "("..pos.x..","..pos.y..","..pos.z..")"
end



-- tries to insert the given volume at the given position.
-- the current volume in the map and the node's capacity are taken into account;
-- if the total volume would exceed the maximum of the target node,
-- the target is filled to maximum and the remainder set appropriately.
-- returns:
-- * remaining volume.
-- * a string identifier of the reason for any failure,
--	e.g. ENONBEARER if the target node wasn't a fluid bearer.
-- current identifier enums: ENONBEARER, ELIMIT
-- in the event of failure (apart from ELIMIT), remainder will always be valid,
-- typically the input volume, so simple code can just treat it as a full cond.
local defpleb = " (this is an ERROR in a node definition)"
local nocap = "nodedef.fluidpackets.capacity missing or not a number"..defpleb
local try_insert_volume_mut = function(packetmap, ivolume, tpos)
	local node, def = get_node_and_def(tpos)
	if def == nil then return ivolume, "ENONBEARER" end
	local capacity = def.capacity
	assert(type(capacity) == "number", nocap)

	local h = hash(tpos)
	local tpacket = packetmap[h]
	-- if the packet doesn't exist currently, create it.
	-- here we're allowed to assume tpos is "given" to us, so use that
	local cvolume
	if tpacket == nil then
		tpacket = tpos
		cvolume = 0
		-- write it back to the map now;
		-- at this point, we're going to be modifying it anyway
		packetmap[h] = tpacket
		-- also note shortly we update tpacket.volume
	else
		cvolume = tpacket.volume
	end

	local status = ""
	local remainder
	local total = cvolume + ivolume
	local overshoot = total - capacity
	if overshoot <= 0 then
		-- it can all fit? just set cvolume to that, all good
		cvolume = total
		remainder = 0
	else
		-- some of it can't fit, so take up to the capacity
		cvolume = capacity
		remainder = overshoot
	end

	-- update volume of packet.
	-- note here we're assuming that the packet's volume can only increase,
	-- hence we don't do deletions here;
	-- volumes are only moved *out* by run_packet_batch(),
	-- which also handles removal of empty packets in that case.
	tpacket.volume = cvolume

	return remainder, status
end



local vadd = vector.add



-- directed pipe: move fluid in appropriate direction, if possible.
local run_packet_directed = function(packetmap, packet, node, bearer_def)
	local offset = get_node_offset(node, bearef_def)
	-- remember, packets are valid position tables
	local target = vadd(packet, offset)

	-- try_insert_volume_mut handles air among other things.
	-- note: the "target" vector is assumed possibly consumed by this!
	local remainder = try_insert_volume_mut(packetmap, packet.volume, target)
	-- run_packet_batch will remove any packets that end up with zero volume.
	packet.volume = remainder

	-- no pending action(s) to run for now
	return nil
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
local mk_inject_packet_ = function(packetmap, basepos)
	return function(volume, offset)
		assert(volume > 0, neg)
		-- in order to maintain proper hashing,
		-- the offsets must be whole integers.
		-- also, least one component must be non-zero.
		checkv(offset)
		local target = vadd(basepos, offset)
		return try_insert_volume_mut(packetmap, volume, target)
	end
end

local run_packet_device = function(packetmap, packet, node, bearer_def)
	-- set up the packet injector for this callback
	local inject = mk_inject_packet_(packetmap, packet)

	-- prepare other initial data for the callback.
	-- note volume is enforced by previous steps moving into the ingress buffer,
	-- so we can just pass the current pressure value to the callback.
	local initial = packet.volume
	local meta = minetest.get_meta(packet)
	local remaining, runlater = bearer_def.ingress(node, meta, initial, inject)

	if remaining == nil then remaining = 0 end
	assert(type(remaining) == "number")
	local volume = clamp(remaining, 0, initial)
	packet.volume = volume

	return runlater
end



local badtask1 =
	"a runlater task from a callback wasn't a function or table"..youpleb
local badtask2 =
	"an item in a runlater list from a callback wasn't a function"..youpleb
-- dispatch a runlater tasks list.
-- tasks which want to modify the world must be deferred until after a batch,
-- in order to prevent the kinds of problems discussed for run_packet_batch().
local run_deferred_tasks = function(tasks, positions, length)
	for i = 1, length, 1 do
		local task = tasks[i]
		local pos = positions[i]
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
				error(badtask1..ptrace)
			end
		end
	end
end



-- and now, the main batch running routine.
-- this is provided a list of hashed keys which should be processed;
-- this is fixed at the beginning of the batch instead of using pairs().
-- the reason for this is a) concurrent inserts during pairs() isn't allowed,
-- and b) it prevents a potential instant movement problem;
-- packets created at previously empty positions must wait until the next turn.
local badtype = "unknown node_def.fluidpackets.type enum"..defpleb
local bearer_type = {
	pipe = run_packet_directed,
	device = run_packet_device,
}
local vnew = vector.new
local run_packet_batch = function(packetmap, packetkeys)
	local runlater = {}
	local runlaterpos = {}
	local i = 1
	for i, key in ipairs(packetkeys) do
		local packet = packetmap[key]
		local node, def = get_node_and_def(packet)
		-- packet inside non-bearer? for now, magically vanish it
		if def == nil then
			packet.volume = 0
		else
			-- try to find appropriate case handler
			local handle = bearer_type[def.type]
			if not handle then
				error(badtype)
			end
			-- now invoke sub-type handler...
			local runtasks = handle(
				packetmap, packet, node, def)

			-- ... and save any run-later tasks for later, if any,
			-- noting the position they should be run with.
			if runtasks then
				runlater[i] = runtasks
				-- defensive copy so packet volume can't be interfered with...
				runlaterpos[i] = vnew(packet)
				i = i + 1
			end
		end

		-- if the packet gets completely emptied, remove it.
		-- this gets rid of unnecessary work,
		-- as zero sized packets can't affect volumes.
		-- additionally, it keeps the size of the packet map down.
		if packet.volume == 0 then
			packetmap[key] = nil
		end
	end

	-- batch processing complete;
	-- take care of any runlater tasks now
	run_deferred_tasks(runlater, runlaterpos, i-1)
end



return run_packet_batch

