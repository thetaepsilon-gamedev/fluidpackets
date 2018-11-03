-- T-junction splitter:
-- splits incoming packets in half and attempts to divide them evenly,
-- sending them into two different outputs.

local mn = _mod.modname
local water = _mod.water



-- texture strings
local input = "waternet_input.png"
local output = "waternet_simple_pipe_top.png"
local blank = "waternet_blank.png"

-- default groups
local groups = _mod.groups




local lib = "com.github.thetaepsilon.minetest.libmthelpers"
local mk_vector_set = mtrequire(lib..".facedir").mk_rotated_vector_set

local l = nil
local vec3 = vector.new
local leftset = mk_vector_set(vec3(-1, 0, 0), l)
local rightset = mk_vector_set(vec3(1, 0, 0), l)

local split = function(node, meta, volume, inject)
	local r = node.param2
	local left = leftset(r)
	local right = rightset(r)

	local h = volume / 2
	local lrem, le = inject(h, left)
	local rrem, re = inject(h, right)

	local trem = lrem + rrem
	return trem, nil
end

local markings = "waternet_device_split_markings.png"
local bottom_in = vec3(0, 1, 0)
local sides = { bottom_in }
local fluidpackets = modtable("ds2.minetest.fluidpackets")
local create_rotating_indir = fluidpackets.util.bearer_helpers.create_rotating_indir
local indir = create_rotating_indir(sides)
local tiles = { blank, input, output, output, markings, markings }

local n = mn..":split_junction"
minetest.register_node(n, {
	description = "Splitter T-junction",
	tiles = tiles,
	groups = groups,
	sounds = default.node_sound_metal_defaults(),
	paramtype2 = "facedir",
	on_place = minetest.rotate_node,
	fluidpackets = {
		[water] = {
			type = "device",
			capacity = 0.5,
			ingress = split,
			indir = indir,
		}
	},
})
local tiles = nil





-- a "pipe" which additionally has an ABM associated with it;
-- the ABM injects water into the pipe from nowhere.
-- this is essentially an infinite water source.
local capacity = 1.0
local n = mn .. ":infinite_pipe"
local zero = function(v) return v == 0 end
local internal_only = function(node, getmeta, v)
	return zero(v.x) and zero(v.y) and zero(v.z)
end
minetest.register_node(n, {
	description = "Infinite spring pipe",
	--tiles = tiles,
	fluidpackets = {
		[water] = {
			type = "pipe",
			dirtype = "facedir_simple",
			capacity = capacity,
			indir = internal_only,
		}
	},
	paramtype2 = "facedir",
	groups = groups,
	sounds = default.node_sound_metal_defaults(),
	on_place = minetest.rotate_node,
})
-- controller.insert = function(tpos, ivolume, indir)
local mapctl = _mod.controller
local inside = vec3(0,0,0)
minetest.register_abm({
	label = "Basic water net: infinite spring pipe",
	nodenames = { n },
	interval = 1.0,
	chance = 1.0,
	action = function(pos, node, ...)
		mapctl.insert(pos, 1.0, inside)
	end,
})





-- a device which takes water into an internal supply saved in metadata.
-- there is then an ABM that tries to drain this level into a water node below it.
-- * if node below is water: drains pressure to maintain flow
-- * if air: sets water, also drains
-- * if water, below threshold: remove water node
-- * if non-water: do nothing
local meta_capacity = 1.0
local k = "fluidpacket_spigot_volume"
local spigot_ingress = function(node, getmeta, volume, inject)
	local meta = getmeta()
	local current = meta:get_float(k)

	-- don't update the metadata if we're already full.
	local remainder, updated
	if current < meta_capacity then
		local spare = meta_capacity - current
		if volume < spare then
			remainder = 0
			updated = current + volume
		else
			-- too much to insert, so only take enough to fill up
			remainder = volume - spare
			updated = meta_capacity
		end

		meta:set_float(k, updated)
	end
end

local set_air = { name="air" }
local set_fluid = { name="default:water_source" }
local spigot_drain_abm = function(pos, node, ...)
	local meta = minetest.get_meta(pos)
	-- we only need to look at the node beneath us at this point
	-- yes, I know, mutating variables...
	local bpos = pos
	pos = nil
	bpos.y = bpos.y - 1

	local enough_fluid = (meta:get_float(k) == 1.0)
	local n = minetest.get_node(bpos).name
	local is_fluid = (n == "default:water_source")
	local is_empty = (n == "air")

	-- obstruction in the way, we cannot do anything anyway
	if not (is_fluid or is_empty) then
		return
	end

	-- it's either fluid or air at this point,
	-- so we can safely update it without worrying what it was before.
	local target_node = enough_fluid and set_fluid or set_air
	if enough_fluid then
		-- if we do set a fluid node down, drain meta pressure
		meta:set_float(k, 0)
	end
	minetest.set_node(bpos, target_node)
end
-- only allow input from horizontal sides, i.e. Y component is zero.
local horizontal_only = function(node, getmeta, v)
	return zero(v.y)
end
local n = mn..":spigot"
local tiles = { blank, "waternet_showerhead.png", input, input, input, input }
minetest.register_node(n, {
	description = "Water spigot",
	tiles = tiles,
	groups = groups,
	sounds = default.node_sound_metal_defaults(),
	fluidpackets = {
		[water] = {
			type = "device",
			capacity = 1.0,
			ingress = spigot_ingress,
			indir = horizontal_only,
		}
	},
})
minetest.register_abm({
	label = "Basic water net: spigot update",
	nodenames = { n },
	interval = 1.0,
	chance = 1.0,
	action = spigot_drain_abm,
})
tiles = nil





