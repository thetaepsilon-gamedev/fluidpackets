local mn = minetest.get_current_modname()
local mp = minetest.get_modpath(mn).."/"
run_packet_batch = dofile(mp.."src/fluid_packet_batch.lua")

