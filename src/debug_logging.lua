--[[
This code creates logging functions used for tracing execution in other modules.
The debug_enable_sources table determines which of these traces log,
and which simply get a no-op function to silence them.
WARNING: intended for singleplayer development only,
can be VERY verbose with minetest.chat_send_all!
]]



local sa = minetest.chat_send_all
local debug_enable_sources = {
	--["fluid_packet_batch"] = true,
}
-- no settings config at the present time...
local is_debug_enabled = function(name)
	return debug_enable_sources[name]
end



local i = {}
local mk_debug = function(name)
	if not is_debug_enabled(name) then
		return function() end
	end

	local l = "[fluidpackets::"..name.."] "
	return function(msg)
		msg = l..msg
		print(msg)
		sa(msg)
	end
end
i.mk_debug = mk_debug



return i

