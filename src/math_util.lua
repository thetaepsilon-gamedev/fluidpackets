local clamp = function(x, min, max)
	if x < min then return min end
	if x > max then return max end
	return x
end

local i = {}
i.clamp = clamp



local isint = function(v) return ((v % 1.0) == 0) end
i.isint = isint



return i

