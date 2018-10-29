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




