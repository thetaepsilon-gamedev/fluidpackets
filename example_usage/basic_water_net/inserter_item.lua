local insert = _mod.controller.insert
local mn = _mod.modname
local vsub = vector.subtract

local volume = 0.5
local direction = vector.new(0, 1, 0)
local place = function(itemstack, placer, pointed)
	if pointed.type ~= "node" then return end
	-- make something up for the direction currently...
	insert(pointed.under, volume, direction)
end

local n = mn..":debug_insert"
minetest.register_craftitem(n, {
	inventory_image = "bubble.png",
	description = "Debug water insert tool",
	on_place = place,
})

