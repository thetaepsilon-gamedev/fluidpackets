-- solve sphere radius, given volume.
-- v = (4/3)pi*r³, therefore:
-- v / ((4/3)pi) = r³	; divide both sides
-- r = _³/(v / ((4/3)pi))	; cube root both sides, flip equation around
--   = _³/(v * (3/4pi))	; re-arrange reciprocal fraction
--   = _³/(v * c)	; let c = (3/4pi):
local c = 3 / (4 * math.pi)	-- pre-compute constant
--   = (v * c) ^ 1/3	; nth root equiv. to 1/nth power
--			; this is because we have no math.cbrt()
local cbrt = 1 / 3

local radius_of_sphere = function(v)
	return ((v * c) ^ cbrt)
end

return radius_of_sphere

