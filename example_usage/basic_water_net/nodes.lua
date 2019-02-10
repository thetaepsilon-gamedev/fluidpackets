local mn = _mod.modname
local n = mn..":basic_pipe"
local water = _mod.water

local tp = "waternet_simple_pipe_"
local t = tp.."top.png"
local s = tp.."side.png"
local b = tp.."bottom.png"
local tiles = { t, b, s, s, s, s }

local groups = _mod.groups

local capacity = 0.5
minetest.register_node(n, {
	description = "Basic test pipe",
	tiles = tiles,
	fluidpackets = {
		[water] = {
			type = "pipe",
			dirtype = "facedir_simple",
			capacity = capacity,
		}
	},
	paramtype2 = "facedir",
	groups = groups,
	sounds = default.node_sound_metal_defaults(),
	on_place = minetest.rotate_node,
})





-- a simple device: explodes when water is ingressed into it.
local t = "waternet_explosive.png"
local tiles = {t,t,t,t,t,t}

-- chemists, tell me, how violent would 1m^3 of sodium be in water?
local n = mn..":sodium"
local explode = function(node, meta, volume, inject)
	local force = (volume ^ (1/3)) * 2
	return 0, function(pos)
		tnt.boom(pos, {radius=force,damage_radius=force})
	end
end
if minetest.global_exists("tnt") then
	minetest.register_node(n, {
		description = "Sodium explosive (don't get this wet)",
		tiles = tiles,
		groups = groups,
		sounds = default.node_sound_metal_defaults(),
		fluidpackets = {
			[water] = {
				type = "device",
				capacity = 2.0,
				ingress = explode,
			}
		},
	})
end



-- only accept input on left and right sides.
local tp = "waternet_merge_pipe_"
local vec3 = vector.new
local sides = {
	vec3(1,  0,  0),
	vec3(-1, 0,  0),
}
local output = "waternet_simple_pipe_top.png"
local top = output
local si = "waternet_input.png"
local sb = tp.."directions.png"
local blank = "waternet_blank.png"
local n = mn..":merge_junction"
local tiles = {top,blank,si,si,sb,sb}

local fluidpackets = modtable("ds2.minetest.fluidpackets")
local create_rotating_indir = fluidpackets.util.bearer_helpers.create_rotating_indir
local indir = create_rotating_indir(sides)

minetest.register_node(n, {
	description = "Input merge pipe",
	tiles = tiles,
	fluidpackets = {
		[water] = {
			type = "pipe",
			capacity = capacity,
			dirtype = "facedir_simple",
			indir = indir,
		},
	},
	paramtype2 = "facedir",
	groups = groups,
	sounds = default.node_sound_metal_defaults(),
	on_place = minetest.rotate_node,
})





-- define a pipe which can be toggled to a sealed state, like a valve.
-- in the sealed state, water can still flow out, but no sides are accepting.
-- the open state just acts like a regular pipe.
-- either can be toggled to the other by right-clicking the node.
local input = "waternet_input.png"
local output = "waternet_simple_pipe_top.png"


local accept_all = function(...) return true end
local reject_all = function(...) return false end

local states = { true, false }
local state_name = function(enabled)
	local tn = enabled and "open" or "closed"
	return mn..":valve_"..tn
end

-- example usage of the packet_arrived hook:
-- yell a message to players reporting the arrived volume.
-- probably not to be enabled in general use due to spam!
local packet_arrived = function(node, volume)
	return function(pos)
		minetest.chat_send_all("# packet arrived at valve: " .. tostring(volume))
	end
end
packet_arrived = nil	-- uncomment at your (chat's) peril!

for _, enabled in ipairs(states) do
	local tn = enabled and "open" or "closed"
	local side = "waternet_valve_"..tn..".png"
	local n = state_name(enabled)
	local tiles = { output, input, side, side, side, side }
	local indir = enabled and accept_all or reject_all

	local opposite = state_name(not enabled)
	local on_rightclick = function(pos, ...)
		minetest.swap_node(pos, {name=opposite})
	end

	minetest.register_node(n, {
		description = "Valve ("..tn..")",
		tiles = tiles,
		fluidpackets = {
			[water] = {
				type = "pipe",
				dirtype = "facedir_simple",
				capacity = 0.5,
				indir = indir,
				packet_arrived = packet_arrived,
			}
		},
		paramtype2 = "facedir",
		groups = groups,
		sounds = default.node_sound_metal_defaults(),
		on_place = minetest.rotate_node,
		on_rightclick = on_rightclick,
	})
end


