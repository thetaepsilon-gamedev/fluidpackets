--[[
try_insert_volume():
this routine handles the various details of inserting packets into a packet map,
including packet merging, capacity checks and callback invocations where needed.
]]


local mk_debug = _mod.m.debug.mk_debug
local tdebug = mk_debug("try_insert_volume")
local get_node_and_def = _mod.m.bearer_def.get_node_and_def
local hash = _mod.hash



local i = {}

-- tries to insert the given volume at the given position.
-- the current volume in the map and the node's capacity are taken into account;
-- if the total volume would exceed the maximum of the target node,
-- the target is filled to maximum and the remainder set appropriately.
-- returns:
-- * remaining volume.
-- * a string identifier of the reason for any failure,
--	e.g. ENONBEARER if the target node wasn't a fluid bearer.
-- current identifier enums: ENONBEARER, ELIMIT, EWRONGSIDE
-- in the event of failure (apart from ELIMIT), remainder will always be valid,
-- typically the input volume, so simple code can just treat it as a full cond.
-- indir is a MT XYZ vector passed to node callbacks for direction checks.
local defpleb = " (this is an ERROR in a node definition)"
local nocap = "nodedef.fluidpackets.capacity missing or not a number"..defpleb
local min = math.min
local vnew = vector.new
local can_go_in = _mod.m.inputcheck.can_go_in
local try_insert_volume = function(packetmap, ivolume, tpos, callback, indir)
	local node, def = get_node_and_def(tpos, callback)
	local h = hash(tpos)

	if node == nil then
		-- unloaded area? we definitely cannot do anything here at all
		return ivolume, "ENONBEARER"
	elseif def == nil then
		-- check if a callback can handle this situation;
		-- e.g. by allowing fluids to escape into air somehow.
		-- the callback may either indicate a remaining amount, or nil.
		-- nil indicates "can't handle", fall back to error status.
		local r = callback("on_escape", tpos, node, ivolume)
		if r == nil then
			tdebug("can't inject "..ivolume.."m³ @"..h..", not a fluid bearer")
			return ivolume, "ENONBEARER"
		else
			-- ensure the callback can't increase the volume.
			r = min(ivolume, r)
			tdebug("on_escape handled, remainder "..r)
			return r, ""
		end
	end

	-- check acceptance of fluid on this side;
	-- if not, don't do anything.
	if not can_go_in(tpos, node, def, indir) then
		return ivolume, "EWRONGSIDE"
	end
	-- NB: at this point, node and indir should be considered consumed
	node = nil
	indir = nil

	-- otherwise, try to insert volume into pipe device.
	local capacity = def.capacity
	assert(type(capacity) == "number", nocap)

	local tpacket = packetmap[h]
	-- if the packet doesn't exist currently, create it.
	local cvolume
	if tpacket == nil then
		tpacket = vnew(tpos)
		cvolume = 0
		-- write it back to the map now;
		-- at this point, we're going to be modifying it anyway
		tdebug("a packet came into being @"..h)
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

i.try_insert_volume = try_insert_volume



return i

