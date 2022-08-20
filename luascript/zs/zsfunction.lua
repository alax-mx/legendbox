
--[[
	string
]]--
-- 按照p字符分割s字符串
string.split = function(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end

-- 去除字符串头尾的空字符
string.trim = function(s)
  return s:match'^%s*(.*%S)' or ''
end

--[[ 
	math
]]--
-- 四舍五入
math.round = function(num)
    return math.floor(num + 0.5)
end

-- 每千位加入逗号分隔符
math.comma = function(num)
    if type(tonumber(num)) ~= "number" then num = 0 end
    local formatted = tostring(num)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

--[[
	io
]]--
-- 检查文件是否存在
io.exists = function(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end

-- 把文件读入到string返回, 文件不存在则返回nil
io.readfile = function(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
    return nil
end

-- 写string到文件
io.writefile = function(path, content)
    local file = io.open(path, "w+")
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end

-- 返回文件相关路径信息 [dirname, filename, basename, extname]
io.pathinfo = function(path)
    local pos = string.len(path)
    local extpos = pos + 1
    while pos > 0 do
        local b = string.byte(path, pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end

    local dirname = string.sub(path, 1, pos)
    local filename = string.sub(path, pos + 1)
    extpos = extpos - pos
    local basename = string.sub(filename, 1, extpos - 1)
    local extname = string.sub(filename, extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end

-- 获取文件大小
io.filesize = function(path)
    local size = false
    local file = io.open(path, "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end