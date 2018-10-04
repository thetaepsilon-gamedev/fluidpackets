--[[
For reasons discussed in fluid_packet_batch.lua,
We want to discourage access to the world during batch processing;
to achieve this, callbacks are not given a position value
(however they are given an option to return a continutation for this).
However, this means that if a callback wants to access metadata,
we have to perform minetest.get_meta(hidden_pos) for the callbacks.

Following advice from MT devs to avoid excessive redundant API calls,
this code defines a wrapper helper which will call minetest.get_meta() on demand;
so that callbacks can do something like this instead:
local metaref = metatoken()
]]

local i = {}
local curry1_ = function(f)
	return function(v)
		-- pure languages wouldn't have a zero-arg closure,
		-- but in stateful ones this is intentionally to make
		-- a semi-expensive side-effect optional.
		return function()
			return f(v)
		end
	end
end
i.curry1_ = curry1_



local getmeta = minetest.get_meta
local get_meta_ref_token = curry1_(getmeta)	-- function(v), returning closure
i.get_meta_ref_token = get_meta_ref_token



return i

