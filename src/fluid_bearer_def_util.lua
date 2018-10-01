--[[
Utilities for building and reading fluid bearer definitions.
]]
local i = {}



--[[
The convention for node definitions for fluid bearers looks somewhat like this:
node_def = {
	tiles = ...	-- usual node stuff
	fluidpackets = {
		-- this may not directly correspond to a liquid node name!
		-- as long as it matches the name the appropriate fluid map uses
		["somemod:liquid"] = bearer_def,
		-- bearer_def structure is defined in fluid_packet_batch.lua

		["somemod:other_liquid"] = ...,
		-- typically speaking there is normally only one liquid type per node.
	}
}

This helper function (note partial application!)
can be used for the value of lookup_definition in a fluid map callback table;
it simply looks for the node definition in minetest.registered_nodes,
then tries to see if the node definition carries a bearer_def for a liquid.
]]
local mk_liquid_lookup = function(lname)
	assert(type(lname) == "string")
	local lookup = function(nname)
		assert(type(nname) == "string")
		local def = minetest.registered_nodes[nname]
		return def and
			def.fluidpackets and
			def.fluidpackets[lname]
	end
	return lookup
end
i.mk_liquid_lookup = mk_liquid_lookup



return i

