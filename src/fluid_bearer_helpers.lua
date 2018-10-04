--[[
These functions and utilities are intended to assist in defining fluid bearers.
They provide common case implementations of things like input direction checking
in one place for convenience and to avoid duplication.
]]
local i = {}
local lib = "com.github.thetaepsilon.minetest.libmthelpers"



-- create a indir callback which accepts one or more input directions from a list,
-- appropriately rotating them to line up with a facedir node's param2 value.
-- the resulting callback will do a linear search through this list,
-- so it is advised not to make this list too long!
local mk_vector_set = mtrequire(lib..".facedir").mk_rotated_vector_set
local label = "create_rotating_indir callback"
local mod = math.fmod
local veq = vector.equals
local create_rotating_indir = function(input_list)
	local sets = {}
	for i, vec in ipairs(input_list) do
		sets[i] = mk_vector_set(vec, label)
	end

	return function(node, metatoken, indir)
		-- chop out unneeded bits for things like colorfacedir
		local param2 = mod(node.param2, 32)
		for i, set in ipairs(sets) do
			local rotated = set(param2)
			if veq(rotated, indir) then
				return true
			end
		end
		return false
	end
end
i.create_rotating_indir = create_rotating_indir



return i

