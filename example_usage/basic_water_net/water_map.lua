local fluidpackets = modtable("ds2.minetest.fluidpackets")
local water = _mod.water

local prn = function() end



local c = ","
local cf = function(pos)
	return "("..pos.x..c..pos.y..c..pos.z..")"
end

local ent = "waterbubble:bubble"
local shove_bubble_at = function(pos, node, vs)
	if node.name == "air" then
		prn("# air, bubble forms")
		minetest.add_entity(pos, ent, vs)
		return 0
	else
		prn("# not air, water hits barrier")
		return nil
	end
end



local destroy = function(packet, hash, node)
	local v = tostring(packet.volume)
	prn("# packet destroyed @"..hash.." volume "..v.."m³")
	shove_bubble_at(packet, node, v)
end
local escape = function(pos, node, volume)
	local v = tostring(volume)
	local hash = cf(pos)
	prn("# packet escaped @"..hash.." volume "..v.."m³")
	return shove_bubble_at(pos, node, v)
end
local lookup = fluidpackets.util.bearer_def.mk_liquid_lookup(water)

local del = " fell out of the loaded world, deleting"
local unload = function(packet, hash)
	prn("# packet @"..hash.." volume "..packet.volume.."m³"..del)
	return true
end





local callbacks = {
	on_packet_destroyed = destroy,
	on_escape = escape,
	lookup_definition = lookup,
	on_packet_unloaded = unload,
}

return fluidpackets.fluid_map_controller.mk(callbacks)

