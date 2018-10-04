-- check if a node can recieve input in a given direction.
local i = {}



-- the indir callback is documented (see fluid_packet_batch.lua)
-- as returning a boolean; just ensure this by being pedantic about the type.
local msg_badtype =
	"fluid bearer callback indir() must return a boolean value"
local assertbool = function(v)
	assert(type(v) == "boolean", msg_badtype)
	return v
end



local getmeta = _mod.util.metatoken.get_meta_ref_token
local can_go_in = function(tpos, node, bearer_def, indir)
	local indir = bearer_def.indir
	if f == nil then return true end
	local r = f(node, getmeta(tpos), indir)
	local accept = assertbool(r)
	return accept
end
i.can_go_in = can_go_in



return i

