--[[
Bearer definition lookup:
across different liquid networks, the lookup for a bearer's definition varies;
it may be in the node's definition (but under different keys for other liquids),
or it may be desireable to look it up from a mod's registration table.

This function is a bit of boilerplate for loading nodes and querying bearer defs;
the implementation of the above is provided as a callback
(as specified in fluid_packet_batch.lua).
It was moved here as it is needed in common by two different modules.
]]

local i = {}

-- definition lookup as described above.
-- note, the definition may return nil, especially for ignore nodes.
local get_node_and_def = function(pos, callback)
	local node = minetest.get_node_or_nil(pos)
	-- no point trying to load definition for unloaded areas...
	if not node then return nil, nil end

	local def = callback("lookup_definition", node.name)
	if def ~= nil then
		-- we're expected a table in the form as "fluidpackets" above
		assert(type(def) == "table")
	end

	return node, def
end
i.get_node_and_def = get_node_and_def



return i

