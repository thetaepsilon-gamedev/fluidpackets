-- callback table boilerplate



local ydebug = function(msg)
	msg = "[fluidpackets.callback_util] "..msg
	print(msg)
	minetest.chat_send_all(msg)
end
local ndebug = function() end
local debug = ndebug



local i = {}

-- special case dummy functions that can be used below.
-- they should be self explanatory, use as appropriate.
local dummies = {
	null = function() end,
	id = function(v) return v end,
	idvarargs = function(...) return ... end,
	-- note this is partially applied! use as e.g. callback_func = const_(v)
	const_ = function(v)
		return function(...)
			return v
		end
	end,
}
i.dummies = dummies

-- set up retrieval of callbacks from a caller-supplied table.
-- if the callbacks aren't present, use defaults from a captured table,
-- or throw an error if a default doesn't make sense / isn't provided.
local callback_invoke__ = function(basetable, label)
	local err = label.." required callback missing: "
	local rundefault = function(k, ...)
		local f = basetable[k]
		if f == nil then
			debug("no default found for key "..tostring(k))
			error(err..k)
		end
		return f(...)
	end

	return function(tbl)
		-- the client doesn't have to supply callbacks -
		-- if so, fall back to defaults
		if tbl == nil then
			debug("no client callbacks table passed")
			return rundefault
		else
			debug("client callbacks found")
			return function(k, ...)
				debug("checking key: "..tostring(k))
				local f = tbl[k]
				if f ~= nil then
					debug("callback found")
					return f(...)
				else
					debug("callback not found, defaulting")
					return rundefault(k, ...)
				end
			end
		end
	end
end
i.callback_invoke__ = callback_invoke__




-- retrieve interface member type functions.
-- eliminates some error message boilerplate etc.
local get_interface_member_ = function(caller, typename, argname)
	local object_desc
	if argname then
		object_desc = "argument [" .. typename .. " " .. argname .. "]"
	else
		object_desc = "type " .. typename
	end
	local msg_base =
		caller .. ": member from " .. object_desc ..
		" was not a function: "

	return function(source, member_name)
		local result = source[member_name]
		local t = type(result)
		if t ~= function then
			error(msg_base .. member_name .. " - got type " .. t)
		else
			return result
		end
	end
end
i.get_interface_member_ = get_interface_member_




return i


