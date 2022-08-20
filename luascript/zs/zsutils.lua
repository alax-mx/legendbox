--[[
    utils工具
]]--

require "zsfunction"

local print = xx_log_print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring
local next = next
local rawget = rawget
local rawset = rawset

--[[
    hook lua function
    @param  func_name       要hook的函数名 (完整module.function, 例如: MainGame.Module.Fight.doFight)
    @param  ori_func_name   原备份函数, 可以通过 xx.hook[ori_func_name] 调用原函数
    @param  hook_func       hook后替换的函数, 注意参数列表!

    @example
        ed = {other = {}}
        ed.other.hookme = function (str, int)
            print(str)
            print(tostring(int))
            return "hookme"
        end
        
        local function hook(str, int)
            print("[hook] " .. str)
            print("[hook] " .. tostring(int))
            return xx.hook.ori_hookme(str .. str, int + int)
        end

        xx_hook("ed.other.hookme", "ori_hookme", hook)
]]
function xx_hook(func_name, ori_func_name, hook_func)
    local fields = string.split(func_name, '.')
    local pfield = _G
    local fieldname = ""
    for _, v in pairs(fields) do
        fieldname = v
        field = rawget(pfield, fieldname)
        if type(field) == "function" then
            break
        end
        pfield = field
    end

    xx.hook[ori_func_name] = field
    if not xx.hook[ori_func_name] then
        print(string.format("[hook] lua function '%s' doesnt exist! check field.", func_name))
        return
    end

    rawset(pfield, fieldname, function (...)
        local args = {...}
        local result = false
        xpcall(function ()
            result = hook_func(unpack(args))
        end, xx.hook.xxTraceback)
        return result
    end)
end

-- 往table新增一层metatable
function xx_addmetatable(t, mt)
    if t and type(t) == "table" then
        if mt and type(mt) == "table" then
            local orimt = getmetatable(t)
            if orimt == mt then return end
            setmetatable(mt, orimt)
            setmetatable(t, mt)
        end
    end
end

-- 移除table新增的metatable
function xx_revertmetatable(t)
    if getmetatable(t) then
        local orimt = getmetatable(getmetatable(t))
        setmetatable(t, orimt)
    end
end

-- 执行一段string代码
function xx_dostring(str)
    local result
    xpcall(function ()
        local func = assert(loadstring(str))
        result = func()
    end, xx.hook.xxTraceback)
    return result
end

-- 深拷贝一个table(lua里table是引用传值)
function xx_deepcopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[xx_deepcopy(orig_key)] = xx_deepcopy(orig_value)
        end
        local metatable = getmetatable(orig)
        if metatable then
            setmetatable(copy, xx_deepcopy(metatable))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- 把table转化成string(方便保存然后重新load回来)
function xx_dumptable(root)
    if type(root) == "table" then
        local s = "{ "
        for k,v in pairs(root) do
            if type(k) ~= "number" then
                k = "\"" .. k .. "\""
            end
            s = s .. "[" .. k .. "] = " .. xx_dumptable(v) .. ","
        end
        return s .. "} "
    elseif type(root) == "string" then
        return "\"" .. root .. "\""
    else
        return tostring(root)
    end
end

-- 遍历和打印一个table的所有值, 方便debug
function xx_logtable(root)
    local cache = {[root] = "."}
    local function _dump(t,space,name)
        local temp = {}
        for k,v in pairs(t) do
            local key = tostring(k)
            if cache[v] then
                tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
            elseif type(v) == "table" then
                local new_key = name .. "." .. key
                cache[v] = new_key
                tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
            else
                tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
            end
        end
        return tconcat(temp,"\n"..space)
    end
    print(_dump(root, "",""))
    print("============================")
end
