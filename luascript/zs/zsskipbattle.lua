local ID_AUTO_WORLD_CHAT = 1001
xx_tipfunc = function()
	-- body
	xpcall(function()
		-- 判断是否开启了自动扫货
		local bauto_private_chat = native_auto_chat()
		if bauto_private_chat == false then
			return
		end

		native_log_print("-----------------start----------------")
		for index = 1, FriendData.GetRecommendCount(), 1 do
			local roleinfo = FriendData.GetRecommendInfo(index)
			local bFlag = FriendData.FriendAdd(roleinfo.mRoleI, defines_pb.EFriend_Friend)
			if bFlag == true then
				native_log_print("添加 ".. roleinfo.mRoleName .. " 成功")
				break
			end
			-- native_log_print("mRoleID = " .. roleinfo.mRoleID .. " mRoleName = " .. roleinfo.mRoleName .. " mLevel = " .. roleinfo.mLevel)
		end
		native_log_print("------------------end-----------------")

		FriendData.FriendRecommend()
	end, xx.hook.xxTraceback)
end

------------------------------------------------------------------------

xx_StoryDialogUI_UpdateDisplay = function(self)
	-- body
	xpcall(function()
		native_log_print("xx_StoryDialogUI_UpdateDisplay in")
		xx.hook.ori_StoryDialogUI_UpdateDisplay(self)
		self:NextDialog()
	end, xx.hook.xxTraceback)
end


local has_huishou_in = false
--初始化背包数据
local xx_huicheng = nil
local xx_suiji = nil
--流程控制
local xx_jiping_ItemData = nil --极品装备
local xx_auto_store = false --存储状态
local xx_auto_storeing = false --存储状态中
local xx_fighting = 0 --攻击状态 
local xx_suiji_count = 0 --记录连续随机次数
local xx_check_start = false	--检查攻击状态定时器
local xx_kasi_schedulerEntry = nil--盟重检测定时器
local xx_kasi_anti_ing = false--盟重检测定时是否开启
local xx_finding_boss = false --找boss状态


--配置开关
local XX_SWITCH_LOG_ID = 1003
local XX_SWITCH_AUTO_HUISHOU_ID = 1004
local XX_SWITCH_AUTO_FIGHT_ID = 1005
local XX_SWITCH_AUTO_XINGZUO_ID = 1006
local XX_SWITCH_AUTO_REDPKG_ID = 1007
local XX_SWITCH_JIPING_STORE_ID = 1008
local XX_SWITCH_FIND_BOSS_ID = 1009
local XX_SWITCH_AUTO_EQUIP_ID = 1010
local XX_SWITCH_AUTO_CONFIG_SKILL = 1011

--总开关
local total_switch = false

-- 暂时写死
local xx_switch_jiping = 6   -- 极品过滤

--目标地图
local xx_auto_huangjindiantang = true
local xx_auto_shenglongdiguo = true

--总开关
local native_get_switch_by_id_hook = function(id)
	if total_switch == true then
		return true
	end

	return native_get_switch_by_id(id)
end

zhuiyi_HUISHOU = function(delay, type)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
        schedulerEntry0 = nil
			local jsonData = {
				subid = 3,
				index = 7,
				act = type,
			}
			releasePrint("INJECT BagProxy huishou ", cjson.encode(jsonData))
			SendTableToServer( global.MsgType.MSG_CS_SUICOMPONENT_SUBMIT, jsonData )
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

zhuiyi_HUISHOU_inline = function(delay, type)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
        schedulerEntry0 = nil
			local jsonData = {
				UserID = "999999999",
				index = 999999999,
				Act = type,
			}
			native_log_print("INJECT BagProxy huishou " .. cjson.encode(jsonData))
			SendTableToServer( global.MsgType.MSG_CS_NPC_TASK_CLICK, jsonData )
			has_huishou_in = false
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

zhuiyi_schedule_SendTableToServer = function(type, delay, data)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
			--releasePrint("INJECT zhuiyi_schedule_SendTableToServer ", cjson.encode(data))
			SendTableToServer(type, data)
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

zhuiyi_schedule_sendNotification = function(type, delay, data)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
			releasePrint("INJECT 自动寻路... ")
			--releasePrint("INJECT zhuiyi_schedule_sendNotification ", cjson.encode(data))
			global.Facade:sendNotification(type, data)
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

zhuiyi_schedule_SendMsg = function(type, delay, data)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
			releasePrint("INJECT zhuiyi_schedule_SendMsg ", cjson.encode(data))
			global.networkCtl:SendMsg(type, 57, data.MakeIndex, 2, 0, data.Name, string.len(data.Name))
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

zhuiyi_schedule_buy = function(type, delay, id)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		releasePrint("INJECT zhuiyi_schedule_buy in ",id)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
			global.networkCtl:SendMsg(type, id, 1, 0, 0, 0, 0)
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

zhuiyi_schedule_sendMsg_com = function(type, delay, npcID, MakeIndex, page, unkn, data, len)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
		--releasePrint("INJECT global.networkCtl:SendMsg type = ".. type .. " npcID = " .. npcID .. " MakeIndex = " .. MakeIndex .. " page = " ..  page .. " unkn = " .. unkn .. " data = " .. data .. " len = " ..len)
		global.networkCtl:SendMsg(type, npcID, MakeIndex, page, unkn, data, len)
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end


--购买物品
xx_buy_samething = function(name)
	--打开商城
	local sendData2 = 
    {
        subid = 100001,
        index = 108,
        act = "@商城",
    }
	zhuiyi_schedule_SendTableToServer(3199, 0.2, sendData2)

	--不确定需不需要这个操作
	zhuiyi_schedule_sendMsg_com(1046, 0.5, 1, 0, 0, 0, 0, 0)
	--购买
	local id = nil
	if name == "随机传送石" then
		id = 2
	end
	if name == "盟重回城石" then
		id = 1
	end

	zhuiyi_schedule_buy(1047, 0.8, id)

	--再点一次打开商城 关闭商城
	zhuiyi_schedule_SendTableToServer(3199, 1, sendData2)
end

xx_get_quick_goods_by_name = function(name)
	if not name then
		return nil
	end
	local itemList = {}
	local QuickUseProxy = global.Facade:retrieveProxy(global.ProxyTable.QuickUseProxy)
	local quickUseData = QuickUseProxy:GetQucikUseData()
	for k,v in pairs(quickUseData) do
		if v.Name == name then
			table.insert(itemList, v)
		end
	end

	if not next(itemList) then
		return nil
	 end
	return itemList
end

xx_get_goods_by_name_all = function(name)
	local _bagProxy = global.Facade:retrieveProxy(global.ProxyTable.Bag)
		local bagdata = _bagProxy:GetItemDataByItemName(name)
		if bagdata == nil then
			bagdata = xx_get_quick_goods_by_name(name)
		end
	return bagdata
end

--自动使用物品 如果没有 会去商店购买 所以不能设置太短时间
xx_safe_use_goods = function(name, delay)
	--releasePrint("INJECT xx_safe_use_goods in ")
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local function callback0(delta)
		-- local _bagProxy = global.Facade:retrieveProxy(global.ProxyTable.Bag)
		-- local bagdata = _bagProxy:GetItemDataByItemName(name)
		-- if bagdata == nil then
		-- 	bagdata = xx_get_quick_goods_by_name(name)
		-- end
		bagdata = xx_get_goods_by_name_all(name)
		if bagdata == nil then
			releasePrint("INJECT 没有该物品 准备购买 " .. name)
			--购买物品
			xx_buy_samething(name)
			return
		end
		--local cjson = require("cjson")
		--releasePrint("INJECT 找到了 " .. cjson.encode(bagdata))
		--releasePrint("INJECT 使用物品 " .. name)
		xx_use_goods(1006, 0.2, bagdata[1])
		scheduler:unscheduleScriptEntry(schedulerEntry0)
	end

	-- local _bagProxy = global.Facade:retrieveProxy(global.ProxyTable.Bag)
	-- local bagdata = _bagProxy:GetItemDataByItemName(name)
	-- if bagdata == nil then
	-- 		bagdata = xx_get_quick_goods_by_name(name)
	-- end
	local bagdata = xx_get_goods_by_name_all(name)
	--如果背包没有这个物品 则延长到3秒
	if bagdata == nil then
		delay = 3
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

xx_use_goods = function(type, delay, data)
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local cjson=require("cjson")
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
			releasePrint("INJECT 使用物品 : ", data.Name )
			--releasePrint("INJECT xx_use_goods ", cjson.encode(data))
			global.networkCtl:SendMsg(type, data.MakeIndex, 1, 0, 0, data.Name, string.len(data.Name))
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end


xx_init_state = function( delay)
	--releasePrint("INJECT xx_init_state in ")
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local function callback0(delta)
		releasePrint("INJECT 初始化状态 ")
		scheduler:unscheduleScriptEntry(schedulerEntry0)
		xx_auto_store = false
		xx_auto_storeing = false
		xx_jiping_ItemData = nil
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end


--开启无怪随机
local schedulerEntryCheck = nil
xx_find_start = function()
	releasePrint("INJECT 开启无怪随机")
	if xx_check_start == true then
		return 
	end
	xx_check_start = true
	local scheduler = cc.Director:getInstance():getScheduler()
	local function callback0(delta)
		--releasePrint("INJECT xx_init_state in ", xx_fighting)
		xx_fighting = xx_fighting + 1

		--找boss状态 随机10次回城 其他状态 3次
		local maxSuijiCount = 3
		if native_get_switch_by_id_hook(XX_SWITCH_FIND_BOSS_ID) == true then
			maxSuijiCount = 10
		end

		if xx_suiji_count >= maxSuijiCount then
			releasePrint("INJECT 连续随机没有怪物 直接回城")
			xx_safe_use_goods("盟重回城石", 1)
			xx_fighting = 0
			xx_suiji_count = 0
			return
		end

		-- 10秒没有攻击 丢随机
		-- 添加无怪随机找boss功能 随机后必须找到boss才会停下来
		if xx_fighting >= 5 then
			releasePrint("INJECT 开始无怪随机")
			xx_safe_use_goods("随机传送石", 1)

			--关闭找boss功能才会直接停下来 不然就等找到boss
			if native_get_switch_by_id_hook(XX_SWITCH_FIND_BOSS_ID) == false then
				xx_fighting = 0
			end

			--开启找boss状态
			if native_get_switch_by_id_hook(XX_SWITCH_FIND_BOSS_ID) == true then
				xx_finding_boss = true
			end

			xx_suiji_count = xx_suiji_count + 1 --记录随机次数
			return
		end
	end
	schedulerEntryCheck =  scheduler:scheduleScriptFunc(callback0, 3, false)
end

--关闭无怪随机
xx_find_end = function()
	releasePrint("INJECT 关闭无怪随机")
	xx_check_start = false
	local scheduler = cc.Director:getInstance():getScheduler()
	xx_fighting = 0
	xx_suiji_count = 0
	xx_finding_boss = false

	scheduler:unscheduleScriptEntry(schedulerEntryCheck)
end

--存储逻辑
xx_strore = function(item)
	releasePrint("INJECT 开始寻址 ... ")
	--移动
	local moveData = 
    {
        x = 323,
        y = 326,
        autoMoveType = global.MMO.AUTO_MOVE_TYPE_SERVER
    }
	zhuiyi_schedule_sendNotification(global.NoticeTable.AutoMoveBegin, 0.4, moveData)
	--npc
	local sendData = 
    {
        UserID = "10038",
        index = 57,
    }
	zhuiyi_schedule_SendTableToServer(1010, 5, sendData)
	--仓库
	local sendData2 = 
    {
        UserID = "10038",
        index = 57,
        Act = "@getback",
    }
	zhuiyi_schedule_SendTableToServer(1011, 5.5, sendData2)

	--存储
	zhuiyi_schedule_SendMsg(global.MsgType.MSG_CS_STORAGE_STORE_REQUEST, 6, item)
	xx_init_state(6.5)
	
	--xx_auto_store = false
	--xx_jiping_ItemData = nil
	--存储完以后回城 开始挂机
	--xx_use_goods(1006, 7, xx_huicheng)
	xx_safe_use_goods("盟重回城石", 7)
end

xx_store_inlime = function(ItemData)
	releasePrint("INJECT 发现极品 满足条件 开始存储")
		xx_auto_store = true    --开始存储极品
		xx_jiping_ItemData = ItemData
	--回城
	--xx_use_goods(1006, 3, xx_huicheng)
	xx_safe_use_goods("盟重回城石", 3)
end


local function GetItemPowerValue(item, param)
   param = param or {}
   local noBase = param and param.noBase or 0
   local noExtra = param and param.noExtra or 0
   local powerValue = 0
   local baseAtt = noBase <= 0
   local extraAtt = noExtra <= 0
   local PlayerPropertyProxy = global.Facade:retrieveProxy(global.ProxyTable.PlayerProperty)
   local myJob = PlayerPropertyProxy:GetRoleJob() or 3
   if not item or next(item) == nil then
      return powerValue
   end
   -- 基础属性
   local ItemConfigProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemConfigProxy)
   local itemAttrs = {}
   local attributeCfg = ItemConfigProxy:GetItemDataByIndex(item.Index)

   local attList = {}
   local attrArray = string.split(attributeCfg.attribute or "", "|")
   for i,v in ipairs(attrArray) do
      if v and v ~= "" and string.len(v) > 0 then
         local vArray = string.split(v or "", "#")
         table.insert(attList,{
            id = vArray[2] and tonumber(vArray[2]) or 3,
            value = vArray[3] and tonumber(vArray[3]) or 0
         })
      end
   end

   local attList = ParseItemBaseAtt(item.attribute)
   local starsAtt = nil
   -- 极品属性
   local exAtt = GetExAttList(item.Values)
   -- 合并极品属性
   if exAtt and next(exAtt) and extraAtt then
      attList = CombineAttList(attList, exAtt)
   end

   local powerSortIndex = nil
   powerValue,powerSortIndex = CalculateAttPowerValue(attList,param.jobPower,param.powerSortIndex)

   local ItemConfigProxy = global.Facade:retrieveProxy( global.ProxyTable.ItemConfigProxy )
   local comparison1,job1 = ItemConfigProxy:GetItemComparison(item.Index)
   local contrast = param.contrastV or 0 --比对装备的属性值
   local comparison = param.comparisonV or comparison1 --比对装备的优先级
   if comparison1 > comparison or (param.powerSortIndex and powerSortIndex > param.powerSortIndex) then --优先级
      powerValue = math.abs(powerValue) + contrast + 1 --自身战力 + 对比装备的战力（ > 对比装备的战力 ） 1(避免等于0的情况)
   elseif comparison1 < comparison then
      powerValue = contrast - math.abs(powerValue) - 1 --对比装备的战力 +  > 自身战力（ < 对比装备的战力 ）1(避免等于0的情况)
   end

   return powerValue,powerSortIndex
end

local function GetMinPowerPosByStdMode(StdMode, param)
   local StdMode = StdMode or 0
   local onEquipMinPower = 0
   local minPowerPos = -1
   local hasEquip = true
   local EquipProxy =  global.Facade:retrieveProxy(global.ProxyTable.Equip)
   local pos = EquipProxy:GetEquipPosByStdModeList(StdMode)
   if not pos or next(pos) == nil then
      print("this StdMode is not a equip")
      return minPowerPos, onEquipMinPower
   end
   for k,v in ipairs(pos) do
      local equipData = EquipProxy:GetEquipDataByPos(v)
      if not equipData then
         minPowerPos = v
         onEquipMinPower = 0
         hasEquip = false
         break
      end
      --releasePrint("INJECT 当前身上装备  " .. equipData.Name)
      --如果身上是首充神器 则不替换
      if equipData.Name == "首充神器" then
      	return minPowerPos, onEquipMinPower
      end

      local equipPower = GetItemPowerValue(equipData, param)
      if onEquipMinPower == 0 or onEquipMinPower > equipPower then
         onEquipMinPower = equipPower
         minPowerPos = v
         if StdMode == 25 then
            break
         end
      end
   end
   return minPowerPos, onEquipMinPower, hasEquip
end

--检查武器是不是首充武器
-- xx_check_ten_pay = function()
-- 	local EquipProxy =  global.Facade:retrieveProxy(global.ProxyTable.Equip)
--     local pos = EquipProxy:GetEquipPosByStdModeList(5)
--     if not pos or next(pos) == nil then
--       releasePrint("this StdMode is not a equip")
--       return false
--    end

--    for k,v in ipairs(pos) do
--       local equipData = EquipProxy:GetEquipDataByPos(v)
--       if not equipData then
--          minPowerPos = v
--          onEquipMinPower = 0
--          hasEquip = false
--          break
--       end

--       if equipData.Name == "首充神器" then
--       	return true
--       end
--    end

--    return false
-- end

xx_anto_equip = function(item)
	--项链不替换 5 武器
	if item.StdMode == 19 or item.StdMode == 20 then
		--releasePrint("INJECT xx_anto_equip 项链不替换")
		return
	end

	local equipIntoPos = -1
	local ItemConfigProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemConfigProxy)
	local comparison = ItemConfigProxy:GetItemComparison(item.Index) 
	local myPower,powerSortIndex
	myPower,powerSortIndex = GetItemPowerValue(item,{jobPower=true})

	--releasePrint("INJECT 发现装备  " .. item.Name .. " 总战力:" .. myPower)

	local EquipProxy =  global.Facade:retrieveProxy(global.ProxyTable.Equip)
	local minPowerPos , onEquipMinPower, hasEquip = GetMinPowerPosByStdMode(item.StdMode,{jobPower=true,contrastV=myPower,comparisonV=comparison,powerSortIndex=powerSortIndex})
	
	if minPowerPos >= 0 and (not hasEquip or onEquipMinPower < myPower) then
		equipIntoPos = minPowerPos
	end

	if equipIntoPos < 0 then
		return
	end

	targetPos = equipIntoPos
	local eventName = global.NoticeTable.TakeOnRequest
	global.Facade:sendNotification(eventName,
    {
        itemData = item,
        pos = targetPos
    })
    releasePrint("INJECT 发现更好的装备 " .. item.Name .. " 旧战力:" .. onEquipMinPower .. " 新战力:" .. myPower)
end

--背包物品增加回调
xx_BagProxy_handle_MSG_SC_BAG_ADD_ITEM = function(self, msg)
	local result = nil
	xpcall(function()
		-- native_log_print("xx_BagProxy_handle_MSG_SC_BAG_ADD_ITEM in")
		result = xx.hook.ori_BagProxy_handle_MSG_SC_BAG_ADD_ITEM(self, msg)
		
		local msgLen = msg:GetDataLength()
		local dataString = msg:GetData():ReadString(msgLen)
		--local cjson=require("cjson")
		--releasePrint("INJECT BagProxy ", cjson.encode(dataString))
		local data = ParseRawMsgToJson(msg)
		local ItemData = self.VOdata:GetItemByMakeIndex(data.makeindex)

		--releasePrint("INJECT BagProxy ", cjson.encode(ItemData))
		
		local ItemName = ItemData.Name
		releasePrint("INJECT 捡到物品 " .. ItemName)

		--设置下攻击状态 不然东西太多会飞走
		if xx_finding_boss == false then
			xx_fighting = 0
		end

		--自动穿装
		local ItemManagerProxy = global.Facade:retrieveProxy(global.ProxyTable.ItemManagerProxy)
		local itemType = ItemManagerProxy:GetItemType(ItemData)
		local Item_Type = ItemManagerProxy:GetItemSettingType()

		if native_get_switch_by_id_hook(XX_SWITCH_AUTO_EQUIP_ID) == true and itemType == Item_Type.Equip then
		--if itemType == Item_Type.Equip then
			xx_anto_equip(ItemData)
		end
		

		--星座打宝
		if ItemName == "星座打宝卷" and native_get_switch_by_id_hook(XX_SWITCH_AUTO_XINGZUO_ID) == true then
			--使用星座打宝
			xx_use_goods(1006, 1, ItemData)
			--进入地图
			local xingzuoDT = {"@白羊散人", "@金牛散人", "@双子散人", "@巨蟹散人", "@狮子散人", "@处女散人", "@天秤散人", "@天蝎散人", "@射手散人", "@摩羯散人", "@水瓶散人", "@双鱼散人"}
			local num = math.random(1,12)
			releasePrint("INJECT 星座打宝准备 -> ", xingzuoDT[num])
			zhuiyi_HUISHOU_inline(3, xingzuoDT[num])
		end

		--吃小红包
		if string.find(ItemName, "红包") ~= nil and native_get_switch_by_id_hook(XX_SWITCH_AUTO_REDPKG_ID) == true then
			--releasePrint("INJECT 使用红包")
			xx_use_goods(1006, 1, ItemData)
		end

		--极品检查
		local jiping = ItemData.Values
		local len = table.getn(jiping)
		for i= 0, len do
			if jiping[i] ~= nil then
				-- 0：物防, 1:魔防，2：攻击, 3：魔法 ，4:道术 ，5:幸运
				if jiping[i].Id ~= 49 then
					local shuxingArray = {"物防","魔防","攻击","魔法","道术","幸运"}
					releasePrint("INJECT 发现极品装备：".. ItemName  .. shuxingArray[jiping[i].Id + 1] .." +", jiping[i].Value)	
				end
			end

			--幸运项链特殊处理
			if jiping[i] ~= nil and jiping[i].Id == 5 then
				if string.find(ItemName, "战神") ~= nil or string.find(ItemName, "圣魔") ~= nil or string.find(ItemName, "真魂") ~= nil or string.find(ItemName, "星王") ~= nil then
					--战神星王项链 幸运+2可以存储
					if jiping[i].Value >= 2 and native_get_switch_by_id_hook(XX_SWITCH_JIPING_STORE_ID) == true then
		   				releasePrint("INJECT 发现极品 满足条件 开始存储")
		   				xx_auto_store = true    --开始存储极品
		   				xx_jiping_ItemData = ItemData
						--回城
						xx_safe_use_goods("盟重回城石", 3)
		   				return
					end
				end 

				--其他项链 +4
				if jiping[i].Value >= 4 and native_get_switch_by_id_hook(XX_SWITCH_JIPING_STORE_ID) == true then
	   				releasePrint("INJECT 发现极品 满足条件 开始存储")
	   				xx_auto_store = true    --开始存储极品
	   				xx_jiping_ItemData = ItemData
					--回城
					xx_safe_use_goods("盟重回城石", 3)
	   				return
				end
			end
			
			--战神以上装备 极品条件 -3
			local jipingChange = xx_switch_jiping
			if jiping[i] ~= nil and string.find(ItemName, "战神") ~= nil and jiping[i].Id == 2 then
				jipingChange = jipingChange - 3
			end

			if jiping[i] ~= nil and string.find(ItemName, "圣魔") ~= nil and jiping[i].Id == 3 then
				jipingChange = jipingChange - 3
			end

			if jiping[i] ~= nil and string.find(ItemName, "真魂") ~= nil and jiping[i].Id == 4 then
				jipingChange = jipingChange - 3
			end


   			if jiping[i] ~= nil and jiping[i].Value >= jipingChange and jiping[i].Value < 100 and native_get_switch_by_id_hook(XX_SWITCH_JIPING_STORE_ID) == true then
   				releasePrint("INJECT 发现极品 满足条件 开始存储")
   				xx_auto_store = true    --开始存储极品
   				xx_jiping_ItemData = ItemData
				--回城
				xx_safe_use_goods("盟重回城石", 3)
   				return
   			end
		end

		--回收
		local itemCount = self.VOdata:GetItemCount()
		native_log_print("背包状态 = " .. itemCount)
		if itemCount > 35 and has_huishou_in == false and native_get_switch_by_id_hook(XX_SWITCH_AUTO_HUISHOU_ID) == true and xx_auto_store == false then
			has_huishou_in = true
			native_log_print("开始回收")
			local scheduler = cc.Director:getInstance():getScheduler()
			zhuiyi_HUISHOU(0.2, "@追忆回收")
			zhuiyi_HUISHOU_inline(0.4, "@装备回收")
			zhuiyi_HUISHOU_inline(0.6, "@一键极品回收")
			zhuiyi_HUISHOU_inline(0.8, "@高级回收")
			zhuiyi_HUISHOU_inline(1, "@一键回收222")--衣服武器
			zhuiyi_HUISHOU_inline(1.2, "@材料回收")
			zhuiyi_HUISHOU_inline(1.4, "@huishou11")--斗笠
			zhuiyi_HUISHOU_inline(1.6, "@huishou22")--勋章
			zhuiyi_HUISHOU_inline(1.8, "@huishou33")--军鼓
			zhuiyi_HUISHOU_inline(2, "@huishou44")--一级血石
			zhuiyi_HUISHOU_inline(2.2, "@huishou55")--二级血石
			--最后的回收要加上状态复位

		end
	end, xx.hook.xxTraceback)
	return result
end

-- xx_BagProxy_handle_MSG_SC_RETURN_BAGDATA = function(self, msg)
-- 	local result = nil
-- 	xpcall(function()
-- 		native_log_print("xx_BagProxy_handle_MSG_SC_BAG_ADD_ITEM in")
-- 		result = xx.hook.ori_BagProxy_handle_MSG_SC_RETURN_BAGDATA(self, msg)

-- 		local data = ParseRawMsgToJson(msg)
--     	local msgLen = msg:GetDataLength()
--     	local dataString = msg:GetData():ReadString(msgLen)

--     	if not data then
--       		return
--    		end

--    		for k,v in ipairs(data) do
-- 	      local changeData = ChangeItemServersSendDatas(v)
-- 		  local cjson=require("cjson")
-- 		  if changeData.Name == "随机传送石" then
-- 		  	xx_suiji = changeData
-- 		  	native_log_print("初始化随机传送石 ： " .. cjson.encode(xx_suiji))
-- 		  end

-- 		  if changeData.Name == "盟重回城石" then
-- 		  	xx_huicheng = changeData
-- 		  	native_log_print("初始化盟重回城石 ： " .. cjson.encode(xx_huicheng))
-- 		  end

-- 		  local cjson=require("cjson")
-- 		  releasePrint("INJECT INIT BAG ", cjson.encode(changeData))
--    		end

-- 	end, xx.hook.xxTraceback)
-- 	return result
-- end

--hook背包构造函数
local isHook_bag = false
xx_BagProxy_new = function()
	-- body
	local result = nil
	xpcall(function()
		native_log_print("xx_BagProxy_new in")
		result = xx.hook.ori_BagProxy_new()
		--背包添加
		xx.hook.ori_BagProxy_handle_MSG_SC_BAG_ADD_ITEM = result.handle_MSG_SC_BAG_ADD_ITEM
		result.handle_MSG_SC_BAG_ADD_ITEM = xx_BagProxy_handle_MSG_SC_BAG_ADD_ITEM
		--背包初始化
		-- xx.hook.ori_BagProxy_handle_MSG_SC_RETURN_BAGDATA = result.handle_MSG_SC_RETURN_BAGDATA
		-- result.handle_MSG_SC_RETURN_BAGDATA = xx_BagProxy_handle_MSG_SC_RETURN_BAGDATA

	end, xx.hook.xxTraceback)
	return result
end

-- xx_Facade_sendNotification = function(self, notificationName, body, type)
-- 	xpcall(function()
-- 		if notificationName == "Layer_Open" then
-- 			native_log_print("xx_Facade_sendNotification notificationName = " .. notificationName .. " data = " .. body.ltype)
-- 			if body.ltype == 1 then
-- 				native_log_print(debug.traceback())
-- 			end
-- 		end
-- 		result = xx.hook.ori_Facade_sendNotification(self, notificationName, body, type)
-- 	end, xx.hook.xxTraceback)
-- end

xx_Facade_new = function(key)
	-- body
	local result = nil
	xpcall(function()
		result = xx.hook.ori_Facade_new(key)
		--xx.hook.ori_Facade_sendNotification = result.sendNotification
		--result.sendNotification = xx_Facade_sendNotification
	end, xx.hook.xxTraceback)
	return result
end


xx_SendTableToServer = function(msgID, tableData)
	xpcall(function()
			if native_get_switch_by_id_hook(XX_SWITCH_LOG_ID) == true then 
				local cjson = require("cjson")
				native_log_print("xx_SendTableToServer in msgID = " .. msgID .. ", data = " .. cjson.encode(tableData))
			end
		xx.hook.ori_SendTableToServer(msgID, tableData)
	end, xx.hook.xxTraceback)
end

--检查是不是一直卡在盟重 30s检查一次 
xx_anti_kasi = function(delay)
	if xx_kasi_anti_ing == true then
		return
	end
	xx_kasi_anti_ing = true

	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local function callback0(delta)
		
		releasePrint("INJECT 控制异常 可能卡死在盟重  使用回城")
		xx_safe_use_goods("盟重回城石", 3)
		--scheduler:unscheduleScriptEntry(schedulerEntry0)
	end
	xx_kasi_schedulerEntry =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

--关闭卡死保护
xx_anti_kasi_stop = function(delay)
	local scheduler = cc.Director:getInstance():getScheduler()
	scheduler:unscheduleScriptEntry(xx_kasi_schedulerEntry)
	xx_kasi_anti_ing = false
end

xx_jump_HJDT = function()
	native_log_print("前往黄金殿堂")
	local moveData = 
    {
        x = 337,
        y = 340,
        autoMoveType = global.MMO.AUTO_MOVE_TYPE_SERVER
    }
	zhuiyi_schedule_sendNotification(global.NoticeTable.AutoMoveBegin, 0.2, moveData)

	local sendData = 
    {
        UserID = "10022",
        index = 29,
    }
	zhuiyi_schedule_SendTableToServer(1010, 5, sendData)

	local num = math.random(1,6)
	local sendData2 = 
    {
        UserID = "10022",
        index = 29,
        Act = "@黄金殿堂"..num,
    }
    zhuiyi_schedule_SendTableToServer(1011, 6, sendData2)
end


xx_jump_SLDG = function()
	native_log_print("前往神龙帝国")
	local moveData = 
    {
        x = 321,
        y = 335,
        autoMoveType = global.MMO.AUTO_MOVE_TYPE_SERVER
    }
	zhuiyi_schedule_sendNotification(global.NoticeTable.AutoMoveBegin, 0.2, moveData)

	local sendData = 
    {
        UserID = "10036",
        index = 43,
    }
	zhuiyi_schedule_SendTableToServer(1010, 5, sendData)

	local num = math.random(1,6)
	local sendData2 = 
    {
        UserID = "10036",
        index = 43,
        Act = "@神龙帝国"..num,
    }
    zhuiyi_schedule_SendTableToServer(1011, 6, sendData2)
end


xx_jump_MLC = function()
	native_log_print("前往魔龙城")
	local moveData = 
    {
        x = 337,
        y = 340,
        autoMoveType = global.MMO.AUTO_MOVE_TYPE_SERVER
    }
	zhuiyi_schedule_sendNotification(global.NoticeTable.AutoMoveBegin, 0.2, moveData)

	local sendData = 
    {
        UserID = "10003",
        index = 1,
    }
	zhuiyi_schedule_SendTableToServer(1010, 5, sendData)

	local sendData2 = 
    {
        UserID = "10003",
        index = 1,
        Act = "@魔龙城堡",
    }
    zhuiyi_schedule_SendTableToServer(1011, 6, sendData2)
end

--根据场景切换来做流程控制
local xx_map_select = xx_jump_HJDT -- 神龙帝国：xx_jump_SLDG	黄金殿堂：xx_jump_HJDT


zhuiyi_schedule_Setting = function(delay, id, value)
	if CHECK_SETTING(id) == 1 then
		return
	end
	local scheduler = cc.Director:getInstance():getScheduler()
	local schedulerEntry0 = nil
	local function callback0(delta)
		scheduler:unscheduleScriptEntry(schedulerEntry0)
		--local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
		--GameSettingProxy:SetValue(id, value)
		CHANGE_SETTING(id, value)
	end
	schedulerEntry0 =  scheduler:scheduleScriptFunc(callback0, delay, false)
end

--判断是配置月龄还是神兽
local xx_has_yueling = function()
    local SkillProxy    = global.Facade:retrieveProxy(global.ProxyTable.Skill)
    local skills        = SkillProxy:GetSkillByID(55)
    local cjson = require("cjson")
    releasePrint("INJECT  xx_has_yueling= "..cjson.encode(skills))
    if skills == nil then
    	return false
    end
    return true
end

--一键配置
local xx_setting = function()
	--设置配置
	local GameSettingProxy = global.Facade:retrieveProxy(global.ProxyTable.GameSettingProxy)
	--检查开关 checksetting
	local PlayerProperty = global.Facade:retrieveProxy(global.ProxyTable.PlayerProperty)
    local job = PlayerProperty:GetRoleJob()
    releasePrint("INJECT  job= ",job)
    if job == 2 then
		zhuiyi_schedule_Setting(1, 40, 1)--互换
		zhuiyi_schedule_Setting(2, 22, 1)--自动上毒
		zhuiyi_schedule_Setting(3, 23, 1)--幽灵盾
		zhuiyi_schedule_Setting(4, 24, 1)--神圣甲
		zhuiyi_schedule_Setting(5, 59, 1)--真气
		--有月龄先用月龄 没有就神兽
		local zhaohuanID = 30
		if xx_has_yueling() == true then
			zhaohuanID = 55
		end
		zhuiyi_schedule_Setting(6, 26, {1,zhaohuanID})--自动召唤 神兽
		zhuiyi_schedule_Setting(7, 26, 1)--自动召唤
		zhuiyi_schedule_Setting(8, 38, {0,zhaohuanID,60})--自动练功 神兽  60秒
    end

	zhuiyi_schedule_Setting(9, 38, 1)
	zhuiyi_schedule_Setting(10, 7, {1,30})--回城保护  30%
	zhuiyi_schedule_Setting(11, 8, {1,40})--随机保护  50%
end

xx_auto_control = function(msgID, data)
	native_log_print("当前所在地图 ".. data.MapName)
	if native_get_switch_by_id_hook(XX_SWITCH_AUTO_FIGHT_ID) == false then
		xx_anti_kasi_stop()--关闭卡死保护
		xx_find_end()--关闭无怪随机
		return
	end

	if (data.MapName == "盟重省") then
		xx_anti_kasi(60)--开启卡死检测
		xx_find_end()--关闭无怪随机
		--存储中 
		if xx_auto_storeing == true then
			return 
		end

		--存储
		if xx_auto_store == true then 
			xx_auto_storeing = true
			xx_strore(xx_jiping_ItemData)
			return
		end

		--下图
		xx_map_select()
	elseif string.find(data.MapName, "黄金殿堂") ~= nil or string.find(data.MapName, "打宝地图") ~= nil or string.find(data.MapName, "神龙帝国") ~= nil  or string.find(data.MapName, "魔龙城") ~= nil then
		if native_get_switch_by_id_hook(XX_SWITCH_AUTO_CONFIG_SKILL)  == true then
			xx_setting()--设置开关
		end
		local sendData2 = 
	    {
	        subid = 20,
	        index = 104,
	        act = "@开始挂机",
	    }
	    zhuiyi_schedule_SendTableToServer(3199, 1, sendData2)--开启自动打怪
	    xx_find_start()--开启无怪随机
	    xx_anti_kasi_stop()--关闭卡死保护
	    return
	end

	--掉线重连 会直接进到武器店
	if data.MapName == "武器店" then
		xx_find_end()--关闭无怪随机
		xx_safe_use_goods("盟重回城石", 3)
	    return
	end

end


xx_ParseRawMsgToJson = function(msg)
	local result = nil
	xpcall(function()
		result = xx.hook.ori_ParseRawMsgToJson(msg)
		local msgHdr  = msg:GetHeader()
	    local msgLen  = msg:GetDataLength()
	    local msgData = (msgLen > 0 and msg:GetData():ReadString(msgLen) or "")
	    --log返回消息 会有少部分不走这里
	    --if msgHdr.msgId ~= 100 and msgHdr.msgId ~= 52 and msgHdr.msgId ~= 17 and msgHdr.msgId ~= 638 and xx_switch_log == true then
	    if native_get_switch_by_id_hook(XX_SWITCH_LOG_ID) == true then
			native_log_print("receive msgID`````` = " .. msgHdr.msgId .. ", data = " .. msgData)
		end


		if msgHdr.msgId == 638 then
			--native_log_print("receive 技能施法")
			--非找boss状态 攻击急停
			if xx_finding_boss == false then
				--native_log_print("receive 技能施法")
				xx_fighting = 0
				xx_suiji_count = 0
			end

		end

		--屏蔽没有这个装备的提示
		if msgHdr.msgId == 767 and native_get_switch_by_id_hook(XX_SWITCH_AUTO_HUISHOU_ID) == true then
			if result then
				if result.Msg == "您当前没有此装备吧！" then
					result = nil
				end
			end
		end

		--屏蔽回收窗口 
		if msgHdr.msgId == 643 and native_get_switch_by_id_hook(XX_SWITCH_AUTO_HUISHOU_ID) == true then
			if result then
				if string.find(msgData, "装备回收") ~= nil then
					result = nil
				end

				-- if result.Name == "QFunction" then
				-- 	result = nil
				-- end
			end
		end

		--场景切换
		if msgHdr.msgId == 634 then
			xx_auto_control(msgHdr.msgId, result)
		end

		if result then
			native_log_print("receive NPC = " .. result.Name)
		end

	end, xx.hook.xxTraceback)
	return result
end

xx_gameMapController_handleMessage = function(self, msg)
	xpcall(function()
		native_log_print("xx_gameMapController_handleMessage in");
		local msgHdr  = msg:GetHeader()
		native_log_print("msgid = " .. msgHdr.msgId)
		xx.hook.ori_gameMapController_handleMessage(self, msg)
	end, xx.hook.xxTraceback)
end

xx_gameMapController_Inst = function()
	local result = nil
	xpcall(function()
		native_log_print("xx_gameMapController_Inst in");
		result = xx.hook.ori_gameMapController_Inst()
		xx.hook.ori_gameMapController_handleMessage = result.handleMessage
		result.handleMessage = xx_gameMapController_handleMessage
	end, xx.hook.xxTraceback)
	return result
end

--进入视野 
xx_converActorData = function(self, msgHdr, msgData)
	local result = nil
	xpcall(function()
		result = xx.hook.ori_converActorData(self, msgHdr, msgData)
		if msgHdr.msgId == 10 then
			local cjson = require("cjson")
			local jsonData = cjson.decode(msgData)
			--releasePrint("INJECT xx_converActorData msgID = " .. msgHdr.msgId .. ", data = " .. msgData)
			local info = jsonData.info
			local data = jsonData.data
			if info ~= nil and data ~= nil then
				--native_log_print("目标进入视野 " .. info[2] .. " 等级 ".. data[1]);
				--如果开启了找boss功能呢  则找到等级大于99级的 才会停止随机  过滤白虎
				if string.find(info[2], "奇遇") ~= nil or string.find(info[2], "史诗") ~= nil or string.find(info[2], "神话") ~= nil then
					native_log_print("BOSS 标记 " .. msgData);
				end

				if native_get_switch_by_id_hook(XX_SWITCH_FIND_BOSS_ID) == true and data[1] ~= nil and data[1] >= 99  and string.find(info[2], "白虎") == nil then
					native_log_print("BOSS 目标进入视野 " .. info[2] .. " 等级 ".. data[1]);
					xx_finding_boss = false
					xx_suiji_count = 0
					xx_fighting = 0
				end
			end
		end
		

	end, xx.hook.xxTraceback)
	return result
end


xx_ChatProxy_SendMsg = function(self, data)
	local result = nil
	xpcall(function()
		-- native_log_print("SendMsg in ")
		result = xx.hook.ori_ChatProxy_SendMsg(self, data)
		-- local cjson = require("cjson")
		-- local jsonStr = cjson.encode(data)
		native_log_print("SendMsg in " .. data.Msg)

		if data.Msg == "神龙地图" then
			xx_map_select = xx_jump_SLDG
			native_log_print("启动神龙地图成功")
		elseif data.Msg == "黄金殿堂" then
			xx_map_select = xx_jump_HJDT
			native_log_print("启动黄金殿堂成功")
		elseif data.Msg == "怪物攻城" then
			xx_map_select = xx_jump_MLC
			native_log_print("启动魔龙城成功")
		elseif data.Msg == "启动动态*" then
			xx_switch_log = true
			native_log_print("启动神龙地图成功")
		elseif data.Msg == "启动自动回瘦*" then
			xx_switch_auto_huishou = true
			native_log_print("启动自动回瘦成功")
		elseif data.Msg == "启动自动下图*" then
			xx_switch_auto_fight = true
			native_log_print("启动自动成功")
		elseif data.Msg == "启动星座打宝*" then
			xx_switch_xingzuo = true
			native_log_print("启动星座成功")
		elseif data.Msg == "启动吃红包*" then
			xx_switch_auto_redpkg = true
			native_log_print("启动吃红包成功")
		elseif data.Msg == "启动存储极品*" then
			xx_switch_auto_redpkg = true
			native_log_print("启动存储极品成功")
		elseif data.Msg == "启动博士功能*" then
			xx_switch_find_boss = true
			native_log_print("启动博士功能成功")
		elseif data.Msg == "关闭动态*" then
			xx_switch_log = false
			native_log_print("关闭动态成功")
		elseif data.Msg == "关闭自动回瘦*" then
			xx_switch_auto_huishou = false
			native_log_print("关闭自动回瘦成功")
		elseif data.Msg == "关闭自动下图*" then
			xx_switch_auto_fight = false
			native_log_print("关闭自动下图成功")
		elseif data.Msg == "关闭星座打宝*" then
			xx_switch_xingzuo = false
			native_log_print("关闭星座打宝成功")
		elseif data.Msg == "关闭吃红包*" then
			xx_switch_auto_redpkg = false
			native_log_print("关闭吃红包成功")
		elseif data.Msg == "关闭存储极品*" then
			xx_switch_auto_redpkg = false
			native_log_print("关闭存储极品成功")
		elseif data.Msg == "关闭博士功能*" then
			xx_switch_find_boss = false
			native_log_print("关闭博士功能成功")
		elseif data.Msg == "你好" then
			total_switch = true
			native_log_print("总开关打开")
		elseif data.Msg == "我好" then
			total_switch = false
			native_log_print("总开关关闭")
		end

	end, xx.hook.xxTraceback)
	return result
end

xx_ChatProxy_new = function()
	local result = nil
	xpcall(function()
		result = xx.hook.ori_ChatProxy_new()
		native_log_print("hook SendMsg")
		xx.hook.ori_ChatProxy_SendMsg = result.SendMsg
		result.SendMsg = xx_ChatProxy_SendMsg
	end, xx.hook.xxTraceback)
	return result
end

xx_CHANGE_SETTING = function(id, value)
	local result = nil
	xpcall(function()
		result = xx.hook.ori_CHANGE_SETTING(id, value)
		if type(value) == "table" then
        	local cjson=require("cjson")
        	native_log_print("xx_CHANGE_SETTING in id = " .. id .. " table value = " .. cjson.encode(value))
    	else
			native_log_print("xx_CHANGE_SETTING in id = " .. id .. " value = " .. value)
		end
	end, xx.hook.xxTraceback)
	return result
end



local ScheduleMgr_started = false
local has_hook_Facade = false
local ChatProxy_hooked = false
local gameMapController_hooked = false
local ChatProxy_hooked = false
local GameSettingProxy_hooked = false

local zs_require = function(name)
	-- body
	local result = nil
	xpcall(function ()
		--native_log_print("require name = " .. name)
		result = xx.hook.ori_require(name)

		if isHook_bag == false and name == "game/proxy/remote/BagProxy" then
			isHook_bag = true
			native_log_print("开始hook BagProxy")
			xx.hook.ori_BagProxy_new = result.new
			result.new = xx_BagProxy_new
		end

		if ScheduleMgr_started == false and name == "util/util" then
			ScheduleMgr_started = true
			native_log_print("开始hook SendTableToServer")
			xx.hook.ori_SendTableToServer = SendTableToServer
			SendTableToServer = xx_SendTableToServer

			xx.hook.ori_ParseRawMsgToJson = ParseRawMsgToJson
			ParseRawMsgToJson = xx_ParseRawMsgToJson
		end

		if gameMapController_hooked == false and name == "logic/gameMapController" then--关闭hook 小退会出问题
			gameMapController_hooked = true
			native_log_print("开始hook gameMapController")
			--xx.hook.ori_gameMapController_Inst = result.Inst
			--result.Inst = xx_gameMapController_Inst
			xx.hook.ori_converActorData = result.handle_InOfView
			result.handle_InOfView = xx_converActorData
		end

		if has_hook_Facade == false and name == "framework/patterns/facade/Facade" then
			has_hook_Facade = true
			native_log_print("开始hook Facade")
			xx.hook.ori_Facade_new = result.new
			result.new = xx_Facade_new
		end

		if ChatProxy_hooked == false and name == "game/proxy/remote/ChatProxy" then
			ChatProxy_hooked = true
			native_log_print("开始hook ChatProxy")
			xx.hook.ori_ChatProxy_new = result.new
			result.new = xx_ChatProxy_new
		end

		if GameSettingProxy_hooked == false and name == "game/proxy/remote/GameSettingProxy" then
			GameSettingProxy_hooked = true
			native_log_print("开始hook GameSettingProxy")
			xx.hook.ori_CHANGE_SETTING = CHANGE_SETTING
			CHANGE_SETTING = xx_CHANGE_SETTING
		end

	end, xx.hook.xxTraceback)
	return result;
end

xx.hook.ori_require = require
require = zs_require