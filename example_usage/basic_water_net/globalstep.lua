local controller = _mod.controller

minetest.register_globalstep(function(dtime)
	controller.step()
end)

