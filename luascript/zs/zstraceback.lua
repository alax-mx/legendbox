--[[
	当lua代码出现错误的时候用来打印堆栈信息
	—— Irvin Pang 2014-09
]]--
local function tracebackex(msg)
	local ret = ""
	for level = 2, 8 do
		local info = debug.getinfo(level, "Sln")
		if not info then break end
		if info.what == "C" then -- C function
			ret = ret .. tostring(level) .. "C function # "
		else -- Lua function
			ret = ret .. string.format(" line %d in function %s |+| ", info.currentline, info.name or "")
		end
	end
	return ret
end

local lastbugtime = os.time() - 1000
local xxTraceback = function(msg)
	if os.time() - lastbugtime < 3 then
		return -- 防止死循环
	end
	lastbugtime = os.time()

	local tracebackinfo = tracebackex()
	
	xx_log_print("----------------- LUA STACK -----------------------------")
	xx_log_print("error: " .. tracebackinfo)
	xx_log_print("----------------- LUA ERROR -----------------------------")
	xx_log_print("error: " .. tostring(msg))
	xx_log_print("-------------------------------------------------------")
end
rawset(xx.hook, "xxTraceback", xxTraceback)
