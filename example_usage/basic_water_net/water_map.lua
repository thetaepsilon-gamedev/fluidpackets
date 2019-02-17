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



-- currently unused no-op load/save
local del = " fell out of the loaded world, deleting"
local unload = function(packet, hash)
	prn("# packet @"..hash.." volume "..packet.volume.."m³"..del)
	return true
end
local load_hint = function(pos, hash)
	prn("# got load hint @"..hash)
	return {}
end



-- somewhere to keep inactive packets...
local m_suspend = fluidpackets.callbacks.suspend
local chunktable = m_suspend.mk_chunktable()
local c_suspend = m_suspend.create_suspend_callbacks(chunktable)





-- create a null object instance of the callbacks,
-- then selectively override the ones we want.
-- this way, we remain compatible in future when more are added.
local c = fluidpackets.types.IBatchRunnerCallbacks.create_null_instance()
c.on_packet_destroyed = destroy
c.on_escape = escape
c.lookup_definition = lookup
c.on_packet_unloaded = c_suspend.on_packet_unloaded
c.on_packet_load_hint = c_suspend.on_packet_load_hint

local controller = fluidpackets.fluid_map_controller.mk(c)
local lbm_hint = m_suspend.create_table_lbm_hint(chunktable, controller.bulk_load)
-- register an LBM so the packet map wakes up again when reloaded
minetest.register_lbm({
	name = "basic_water_net:lbm_packet_load",
	nodenames = { "group:basic_water_net" },
	run_at_every_load = true,
	action = lbm_hint,
})
local i = {}
i.controller = controller
-- let the map be visible for debugging
i.chunktable = chunktable



return i


