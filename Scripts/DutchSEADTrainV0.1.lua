Utils = {}
do
    function Utils.messageToAll(text,displayTime,clearview)
        local displayTime = displayTime or 5
        local clearview = clearview or false
        trigger.action.outText(text, displayTime, clearview)
    end

    function Utils.getTableSize(t)
        local count = 0
        for _ in pairs(t) do count = count + 1 end
        return count
    end

    function Utils.makeVec3(vec, y)
		if not vec.z then
			if vec.alt and not y then
				y = vec.alt
			elseif not y then
				y = 0
			end
			return {x = vec.x, y = y, z = vec.y}
		else
			return {x = vec.x, y = vec.y, z = vec.z}	-- it was already Vec3, actually.
		end
	end

    -- @return vec2 coord
    function Utils.getRandPointInCircle(p, r, innerRadius, maxA, minA)
        local point =Utils.makeVec3(p)
        local theta = 2*math.pi*math.random()
        local radius = r or 1000
        local minR = innerRadius or 0
        if maxA and not minA then
            theta = math.rad(math.random(0, maxA - math.random()))
        elseif maxA and minA then
            if minA < maxA then
                theta = math.rad(math.random(minA, maxA) - math.random())
            else
                theta = math.rad(math.random(maxA, minA) - math.random())
            end
        end
        local rad = math.random() + math.random()
        if rad > 1 then
            rad = 2 - rad
        end

        local radMult
        if minR and minR <= radius then
            --radMult = (radius - innerRadius)*rad + innerRadius
            radMult = radius * math.sqrt((minR^2 + (radius^2 - minR^2) * math.random()) / radius^2)
        else
            radMult = radius*rad
        end

        local rndCoord
        if radius > 0 then
            rndCoord = {x = math.cos(theta)*radMult + point.x, y = math.sin(theta)*radMult + point.z}
        else
            rndCoord = {x = point.x, y = point.z}
        end
        return rndCoord
    end

end

DutchSEADTrain = {}

do
    local ev = {}
    
    function ev:onEvent(event)
        if event.id == world.event.S_EVENT_BIRTH and event.initiator and event.initiator.getPlayerName then
            local unit = event.initiator
            if not unit then return end

            local group = unit:getGroup()
            if not group then return end

            local groupName = group:getName()
            if not groupName then return end

            local pattern = "^Hawk(%d)"

            local groupPrefix = '1'
            local targetZone = 'Hawk1_TGT_SpawnZone'

            local number = string.match(groupName,pattern)
            if number then
                if number == '2' then
                    groupPrefix = '2'
                    targetZone = 'Hawk2_TGT_SpawnZone'
                end
                
                if number == '3' then
                    groupPrefix = '3'
                    targetZone = 'Hawk3_TGT_SpawnZone'
                end

                if number == '4' then
                    groupPrefix = '4'
                    targetZone = 'Hawk4_TGT_SpawnZone'
                end

                Utils.messageToAll('groupName: '..groupName..'groupPrefix: '..groupPrefix) --Debug
                DutchSEADTrain:new(group,groupPrefix,groupName,targetZone)
            end
        end
    end

    world.addEventHandler(ev)

    DutchSEADTrain.TGTCategory = {
        Easy = 'Easy',
        Complex = 'Complex',
    }

    DutchSEADTrain.templates = {
        [DutchSEADTrain.TGTCategory.Easy] = {},
        [DutchSEADTrain.TGTCategory.Complex] = {},
    }

    DutchSEADTrain.allGroups = {}
    function DutchSEADTrain:new(group,groupPrefix,groupName,targetZone)

        if DutchSEADTrain.allGroups[groupName] then 
            DutchSEADTrain.allGroups[groupName]:remove()
        end

        local obj = {}

        obj.group = group
        obj.groupPrefix = groupPrefix
        obj.groupName = groupName

        obj.targetZone = trigger.misc.getZone(targetZone) or nil

        obj.groupMenu = {}

        obj.TGTGroup = {}

        setmetatable(obj, self)
        self.__index = self

        obj:addMenu()

        DutchSEADTrain.allGroups[groupName] = obj

        return obj
    end

    function DutchSEADTrain:remove()
        DutchSEADTrain.allGroups[self.groupName] = nil
    end

    function DutchSEADTrain:validation()
        if not self.group then return false end

        local units = self.group:getUnits()
        if not units then return false end

        local alive = false
        for i,unit in pairs(units) do
            if unit:getLife() >= 1 then alive = true end
        end

        return alive
    end

    function DutchSEADTrain:addMenu()
        if not self:validation() then return end

        local group = self.group
        local groupID = group:getID()

        missionCommands.removeItemForGroup(groupID, self.groupMenu)
        self.groupMenu = {}

        self.groupMenu['activeSAMEasy'] = missionCommands.addCommandForGroup(groupID,"激活随机简单阵地",nil,self.activeSAM,{context = self,category = DutchSEADTrain.TGTCategory.Easy})
        self.groupMenu['activeSAMComplex'] = missionCommands.addCommandForGroup(groupID,"激活随机复合阵地",nil,self.activeSAM,{context = self,category = DutchSEADTrain.TGTCategory.Complex})
        self.groupMenu['deactiveSAMEasy'] = missionCommands.addCommandForGroup(groupID,"撤销简单阵地目标",nil,self.deactiveSAM,{context = self,category = DutchSEADTrain.TGTCategory.Easy})
        self.groupMenu['deactiveAMComplex'] = missionCommands.addCommandForGroup(groupID,"撤销复合阵地目标",nil,self.deactiveSAM,{context = self,category = DutchSEADTrain.TGTCategory.Complex})
    end

    function DutchSEADTrain.addTGTGroupTemplate(groupName,category)
        local group = Group.getByName(groupName)
        if not group then return end

        local units = group:getUnits()
        if not units then return end

        DutchSEADTrain.templates[category] = DutchSEADTrain.templates[category] or {}

        local groupData = {}
        groupData.name = groupName
        groupData.task = "Ground Nothing"
        groupData.units = {}

        for i,unit in pairs(units) do
            local unitData = {}
            unitData.type = unit:getTypeName()
            table.insert(groupData.units,unitData)
        end

        table.insert(DutchSEADTrain.templates[category],groupData)
    end

    function DutchSEADTrain:spawnTargetGroup(newGroupName,template,point)
        local newGroup = {}
        newGroup.name = newGroupName
        newGroup.task = "Ground Nothing"

        newGroup.units = template.units

        for i,unit in pairs(newGroup.units) do
            unit.name = newGroupName..'-'..i
            unit.heading = math.random()*math.pi*2
            unit.playerCanDrive = true
            unit.skill = 'High'            
            
            if i == 1 then
                unit.x = point.x
                unit.y = point.y
            end

            if i ~= 1 then
                local spawnPoint = nil
                for i=1,100,1 do
                    local tempPoint = Utils.getRandPointInCircle(point, 160,80)
                    if land.getSurfaceType({x = tempPoint.x,y = tempPoint.y}) == land.SurfaceType.LAND then
                        spawnPoint = tempPoint
                        break
                    end
                end

                if not spawnPoint then
                    spawnPoint.x = point.x+math.random(80,160)
                    spawnPoint.y = point.y+math.random(80,160)
                end

                unit.x = spawnPoint.x
                unit.y = spawnPoint.y
            end

        end

        return coalition.addGroup(country.id.RUSSIA, Group.Category.GROUND, newGroup)
    end

    function DutchSEADTrain.activeSAM(vars)
        local self = vars.context
        if not self:validation() then return end

        if not self.targetZone then return end

        local category = vars.category
        if not category then return end

        self.TGTGroup[category] = self.TGTGroup[category] or nil
        if self.TGTGroup[category] then
            self.deactiveSAM({context = self,category = category})
        end
        
        local point = nil

        for i=1,500,1 do
            local tempPoint = Utils.getRandPointInCircle(self.targetZone.point, self.targetZone.radius)
            if land.getSurfaceType({x = tempPoint.x,y = tempPoint.y}) == land.SurfaceType.LAND then
                point = tempPoint
                break
            end
        end

        if not point then return end

        local templateList = DutchSEADTrain.templates[category]
        local template = templateList[math.random(1,#templateList)]
        local newGroupName = template.name..'_'..self.groupName

        self.TGTGroup[category] = DutchSEADTrain:spawnTargetGroup(newGroupName,template,point)
        
        if self.TGTGroup[category] then Utils.messageToAll('群组: '..self.TGTGroup[category]:getName()..'已刷新') end
    end

    function DutchSEADTrain.deactiveSAM(vars)
        local self = vars.context
        if not self:validation() then return end

        if not self.TGTGroup[vars.category] then return end

        self.TGTGroup[vars.category]:destroy()
        
        Utils.messageToAll('群组: '..self.TGTGroup[vars.category]:getName()..'已清除')
        self.TGTGroup[vars.category] = nil
    end
end

DutchSEADTrain.addTGTGroupTemplate('SA11-简单',DutchSEADTrain.TGTCategory.Easy)
DutchSEADTrain.addTGTGroupTemplate('SA-6-简单',DutchSEADTrain.TGTCategory.Easy)
DutchSEADTrain.addTGTGroupTemplate('SA-6-复合',DutchSEADTrain.TGTCategory.Complex)
DutchSEADTrain.addTGTGroupTemplate('SA11-复合',DutchSEADTrain.TGTCategory.Complex)