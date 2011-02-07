--
--------------------------------------------------------------------------------
--         FILE:  getinfo.lua
--        USAGE:  ./getinfo.lua
--  DESCRIPTION:
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:   (), <>
--      COMPANY:
--      VERSION:  1.0
--      CREATED:  07.02.2011 02:09:01 CET
--     REVISION:  ---
--------------------------------------------------------------------------------
--

-- while debug: --
--require("vardump")

local io = io
local table = table
local string = string
local assert = assert

module("uzful.getinfo")


function interfaces()
	local f = io.popen("ls /sys/class/net", "r")
	local out = assert(f:read("*a"))
	f:close()
	local ret = {}
	for w in string.gfind(out, "%w+") do
		if not ( string.find(w,"lo") or
		 string.find(w, "dummy%d+") )
		 then
			 table.insert(ret, w)
		 end
	end
	return ret
end


function local_cpus()
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


function cpu_count()
    return #local_cpus()
end

-- print "---------------------"
-- print (vardump(get_interfaces()))
-- print "---------------------"
--
-- print (vardump(john_num_cpus()))
-- print "---------------------"

--print (vardump(local_cpus()))


