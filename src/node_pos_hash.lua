local isint = _mod.util.math.isint
local hash = function(pos)
	assert(isint(pos.x))
	assert(isint(pos.y))
	assert(isint(pos.z))
	return "("..pos.x..","..pos.y..","..pos.z..")"
end

return hash

