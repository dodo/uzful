--------------------------------------------------------------------------------
-- @author john
-- @copyright 2011 https://github.com/tuxcodejohn
-- @release v3.4-503-g4972a28
--------------------------------------------------------------------------------

--- Table dumping
-- @param data a table
-- @return stringified table
function vardump(data)
	local function rvardump (rdata, erg,indent,key)

		local linePrefix = ""
		if key ~= nil then
			linePrefix = string.format("[%s]",key)
		end

		if(indent == nil) then
			indent = 0
		else
			indent = indent +1
			table.insert(erg,string.rep(" ",indent))
		end

		if type(rdata) == 'table' then
			mTable = getmetatable(rdata)
			if mTable == nil then
				table.insert(erg,linePrefix)
				table.insert(erg ,"(table)")
			else
				table.insert(erg ,"(metatable)")
				rdata = mTable
			end
			table.insert(erg,"\n")
			for tableKey, tableValue in pairs(rdata) do
				rvardump(tableValue, erg,indent,tableKey)
			end
		elseif  type(rdata) == 'function'   or
			type(rdata)	== 'thread' or
			type(rdata)	== 'userdata' or
			rdata		== nil  then

			table.insert(erg,tostring(rdata))
			table.insert(erg,"\n")
		else
			table.insert(erg,string.format("%s(%s)%s",linePrefix,type(rdata),tostring(rdata)))
			table.insert(erg,"\n")
		end
	end

	local erg= {}
	rvardump(data,erg)

	return table.concat(erg)
end

return vardump
