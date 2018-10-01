local radius = 0.5
local gravity = vector.new(0, -10, 0)



-- not true sphere volume,
-- but scaled so 1m^3 volume nodes interact with the world better.
-- r = _³/(v * (3/4pi)) normally,
-- however for our purposes just treat it like a cube.
local cbrt = 1 / 3
local radius_of_volume = function(v)
	return (v ^ cbrt) / 2
end



local cubic_cbox = function(r)
	return {-r,-r,-r,r,r,r}
end
local vscale = function(s)
	return {x=s,y=s}
end

local set_bubble_props = function(object, cboxr, vs)
	object:set_properties({
		collisionbox = cubic_cbox(cboxr),
		visual_size = vscale(vs),
	})
end



-- set sizing of object dependent on volume.
local apply_size = function(object, volume)
	local radius = radius_of_volume(volume)

	-- scaling of the visual size to better match the collision box.
	local s = (4 * (2 * radius)) / 3

	return set_bubble_props(object, radius, s)
end



local activate = function(self, staticdata, dtime_s)
	local volume = tonumber(staticdata)
	if volume == nil or volume <= 0 then
		self.object:remove()
		return
	end
	self.staticdata = staticdata

	local ref = self.object
	apply_size(ref, volume)

	ref:set_acceleration(gravity)
end
local t = "bubble.png"





local mn = "waterbubble"
local entname = mn..":bubble"

minetest.register_entity(entname, {
	visual = "sprite",
	textures = {t},
	physical = true,
	collide_with_objects = false,
	hp_max = 1,
	on_activate = activate,
	get_staticdata = function(self)
		return self.staticdata
	end,
})

