local insert = _mod.controller.insert
local mn = _mod.modname

local volume = 0.5
local place = function(itemstack, placer, pointed)
	if pointed.type ~= "node" then return end
	insert(pointed.under, volume)
end

local n = mn..":debug_insert"
minetest.register_craftitem(n, {
	inventory_image = "bubble.png",
	description = "Debug water insert tool",
	on_place = place,
})

