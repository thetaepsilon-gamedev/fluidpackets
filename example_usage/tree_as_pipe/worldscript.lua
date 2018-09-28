-- test script used during development to show bits working.
-- copy or symlink this inside a world folder,
-- then use the "worldscript" block mod from here:
-- https://github.com/thetaepsilon-gamedev/mt_devitems_modpack
-- to try this out, make a "pipe" out of trees as they face towards you,
-- making sure to start at 0, 8, 0 as below.



local prn = minetest.chat_send_all

local c = ","
local cf = function(pos)
	return "("..pos.x..c..pos.y..c..pos.z..")"
end
local hash = "(0,8,0)"
local pos = vector.new(0,8,0)
local targetname = "default:tree"
--minetest.set_node(pos, {name=targetname, param2=0})

-- definition hacky hacky...
local insert = {
	fluidpackets = {
		type = "pipe",
		dirtype = "facedir_simple",
		capacity = 1.0,
	},
}
minetest.override_item(targetname, insert)


local packet = pos
packet.volume = 0.9
local p2 = vector.new(0, 9, 0)
p2.volume = 0.8
local packetmap = {
	[hash] = packet,
	["(0,9,0)"] = p2,
}

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
local lookup = function(name)
	local def = minetest.registered_nodes[name]
	return def and def.fluidpackets
end
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



-- just run all present keys, for now...
local run_all = function(packetmap)
	local index = 0
	local packetkeys = {}
	for k, _ in pairs(packetmap) do
		index = index + 1
		packetkeys[index] = k
	end

	return run_packet_batch(packetmap, packetkeys, callbacks)
end



local count = 0
while (next(packetmap) ~= nil) do
	run_all(packetmap)
	count = count + 1
end
prn("# "..count.." iterations completed.")
prn(dump(packetmap))

