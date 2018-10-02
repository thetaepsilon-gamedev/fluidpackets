local clamp = function(x, min, max)
	if x < min then return min end
	if x > max then return max end
	return x
end

local i = {}
i.clamp = clamp



return i

