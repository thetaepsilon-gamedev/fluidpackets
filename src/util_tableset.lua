-- utilities for dealing with table sets in general.
-- see node_pos_hash.lua for the rationale for these tables

local i = {}

-- insert items into a table set while checking for collisions first
-- NB partial application of the error message
local insert_set_nocollide_ = function(err_dup)
	return function(target, inset)
		-- check for collisions first
		for k, _ in pairs(inset) do
			if target[k] ~= nil then
				error(err_dup..k)
			end
		end
		-- now insert
		for hash, packet in pairs(inset) do
			target[hash] = packet
		end
	end
end
i.insert_set_nocollide_ = insert_set_nocollide_



return i

