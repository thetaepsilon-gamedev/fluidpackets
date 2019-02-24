local null = _mod.util.callbacks.dummies.null
local const = _mod.util.callbacks.dummies.const_

local m_types =
	mtrequire("com.github.thetaepsilon.minetest.libmthelpers.typechecking")

local sign, verify = m_types.create_simple_type()



-- The "super-class" (or rather, super interface) to IBatchRunnerCallbacks.
-- It consists only of packet destruction, escape, and definition lookup.
-- The two missing callbacks (load hint and unload)
-- are handled by some sub-classes of the fluid map controller;
-- those ones are expected to fill in the load and unload callbacks,
-- therefore they only require the first three.

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
	}

	return sign(defcallbacks)
end

i.create_null_instance = create_null_instance

i.is_type = verify

return i

