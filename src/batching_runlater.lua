local lib = "com.github.thetaepsilon.minetest.libmthelpers"
local newstack = mtrequire(lib..".datastructs.stack").new
local hash = _mod.hash
local vnew = vector.new

-- a function for stacks used as the "run later" deferral queue.
-- runlater tasks consist of a position table with an extra "tasks" member,
-- which can either be a function or a list-like table of the same.
-- any such functions are invoked with that same position as their parameter;
-- they are intended to perform world effects *after* the main batch processing.
-- the rationale for this ordering is explained in fluid_packet_batch.lua


local create_enqueue = function(stack)
	local _enqueue = stack.push
	local push = function(pos, runtasks)
		if runtasks == nil then return end

		-- defensive copy so packet volume can't be interfered with...
		-- (in case a packet is used directly as a position)
		local task = vnew(pos)
		task.tasks = runtasks
		_enqueue(task)
	end

	return push
end





local the_above_is_a_bug =
	" (this is a BUG in a fluidpacket calback returning runlater tasks)"

local badtask1 =
	"a runlater task from a callback wasn't a function or table" ..
	the_above_is_a_bug

local badtask2 =
	"an item in a runlater list from a callback wasn't a function" ..
	the_above_is_a_bug

local run_deferred_tasks = function(taskstack)
	for i, pos in taskstack.ipairs() do
		local task = pos.tasks
		local ptrace = " @"hash(pos)

		local t = type(task)
		if t == "function" then
			-- single task, just run that
			task(pos)
		else
			if t == "table" then
				-- list of tasks, run them all
				local list = task
				for i, task in ipairs(list) do
					local t = type(task)
					assert(t == "function", badtask2..ptrace)
					task(pos)
				end
			else
				error(badtask1..ptrace..", got a "..t)
			end
		end
	end
end




local construct = function()
	local runlater = newstack()
	local enqueue = create_enqueue(runlater)
	local run_deferred = function()
		return run_deferred_tasks(runlater)
	end

	-- this API is expected to be called a lot.
	-- let's not clutter GC with tables that probably won't last long...
	return enqueue, run_deferred
end

return {
	new = construct,
}


