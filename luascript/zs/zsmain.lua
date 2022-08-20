--[[
	lua代码入口
	—— Irvin Pang 2014-12
]]--
rawset(_G, "xx", xx or {})
rawset(xx, "hook", xx.hook or {})

-- 必须先加载的两个文件
require "zstraceback"
require "zsutils"

xpcall(function ()
	native_log_print("执行了这里 lua main in")
	local function tryLoadMod()
		xpcall(function ()
			require "zsskipbattle"
			native_log_print("dir = " .. native_get_file_dir())
		end, xx.hook.xxTraceback)
	end

	tryLoadMod()
end, xx.hook.xxTraceback)

