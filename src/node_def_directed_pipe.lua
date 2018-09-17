--[[
Logic for handling directed pipe devices:
determine the current out-flow direction based on node information/definition.
]]



-- core logic of facedir_simple pipe type:
-- outdir is rotated according to facedir param2.
-- if it is nil, it is assumed to be a unit upwards vector.
local default_outdir = vector.new(0, 1, 0)
local lib = "com.github.thetaepsilon.minetest.libmthelpers"
local get_rotate = mtrequire(lib..".facedir").get_rotation_function
local rotate_outdir = function(outdir, param2)
	-- TODO: some param2 types have other bits stored in this...
	outdir = outdir or default_outdir
	-- this is technically a table allocation, but that's ok,
	-- as the outdir in this case comes from a node definition,
	-- and therefore should be considered read-only.
	return get_rotate(param2)(outdir)
end

-- then extract relevant info from bearer_def to proceed.
local get_facedir_simple = function(node, bearer_def)
	local outdir = bearer_def.outdir
	local param2 = node.param2
	return rotate_outdir(outdir, param2)
end



local dirtypes = {
	facedir_simple = get_facedir_simple,
}
local n = "get_node_offset(): "
local get_node_offset = function(node, bearer_def)
	-- we assume here that bearer_def.type == "pipe".
	-- therefore here we expect bearer_def.dirtype to be a string
	-- representing enum fluid_dir_type:
	-- * facedir_simple: defer to get_facedir_simple() above
	-- others not yet implemented.
	local t = bearer_def.dirtype
	local handler = dirtypes[t]
	if not t then
		error(n.."unsupported dirtype in definition: "..tostring(t))
	else
		return handler(node, bearer_def)
	end
end



return get_node_offset


