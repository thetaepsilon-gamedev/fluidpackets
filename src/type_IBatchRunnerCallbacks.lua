local null = _mod.util.callbacks.dummies.null
local const = _mod.util.callbacks.dummies.const_

local m_types =
	mtrequire("com.github.thetaepsilon.minetest.libmthelpers.typechecking")

local sign, verify = m_types.create_simple_type()



-- Null Object pattern implementation of IBatchRunnerCallbacks.
-- can be used as a "base class" when not all operations are needed;
-- the below will do nothing and the most idempotent thing where possible.
local i = {}
local create_null_instance = function()
	local defcallbacks = {
		-- invoked when a packet *starts a batch* inside a non-bearer.
		-- this usually indicates either a bug or some node changed from under us.
		-- packet will be destroyed upon return.
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
		-- returning nil indicates there was nothing to load
		-- (same as an empty table but less allocations).
		on_packet_load_hint = const(nil),
	}

	return sign(defcallbacks)
end

i.create_null_instance = create_null_instance

i.is_type = verify

return i

