--------------------------------------------------------------------------------
-- @author john
-- @copyright 2011 https://github.com/tuxcodejohn
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

getinfo = {}

local io = require('io')

--- Network Interfaces
-- @return list of all network interfaces (without `lo`)
function getinfo.interfaces()
	local f = io.popen("ls /sys/class/net", "r")
	local out = assert(f:read("*a"))
	f:close()
	local ret = {}
	for w in string.gfind(out, "%w+") do
	  	f,emsg,enum = io.open("/sys/class/net/".. w .. "/device" ,"r")
		if (enum ~= 2 ) then
			 table.insert(ret, w)
		 end
	end
	return ret
end

--- CPUs
-- @return list of all cpus
function getinfo.local_cpus()
	local cpu_lines = {}
	local c = ""
	local v = ""
	for line in io.lines("/proc/stat") do
		v= nil
		v, c = string.find(line, "^(cpu%d+)")
		if v then
			table.insert(cpu_lines, string.sub(line,v,c))
		end
	end
	return cpu_lines
end

--- CPU Count
-- @return number of cpus
function getinfo.cpu_count()
    return #getinfo.local_cpus()
end

return getinfo
