--[[
A convention used in this mod, similar to that used in libmt_node_network,
is to represent sets of packets as a table mapping strings to packet structs:
{
	["(0,8,2)"] = {
		x = 0,
		y = 8,
		z = 2,
		-- additional keys for packet here, such as volume
	},
	...
}
The internal position of a packet is turned into a well-known string when inserted.
This enables fast checking for an existing packet at a given position,
important when carrying out packet merges;
an existing packet will get added to, otherwise a packet is moved or created.

The hash function defined here is the common definition of the string form.
To create a packet set, take a table and some packets to insert,
then for each packet (which are assumed to be at unique positions)
let k = hash(packet), then insert the packet as table[k] = packet.
]]



local isint = _mod.util.math.isint
local hash = function(pos)
	assert(isint(pos.x))
	assert(isint(pos.y))
	assert(isint(pos.z))
	return "("..pos.x..","..pos.y..","..pos.z..")"
end

return hash

