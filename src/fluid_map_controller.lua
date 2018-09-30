--[[
Fluid map controller object

A single entry point for the following needs:
+ introducing packets into the network from e.g. ABMs
+ triggering a step to happen
+ insert a hashmap of packets when an area becomes loaded.
+ get an iterator for all hash, packet pairs (for saving)

map.insert(pos, volume)
map.step()
map.bulk_load(packetset)
map.iterate()
]]
