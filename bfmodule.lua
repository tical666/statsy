local _G = getfenv(0)

local BFModule = Statsy:NewModule("BFModule", "AceEvent-3.0", "AceHook-3.0")

function BFModule:OnInitialize()
    self:Init()
    self:InitDB()
end

function BFModule:OnEnable()
    --self:RawHook("WorldStateScoreFrame_Update", true)
end

function BFModule:OnDisable()
end

function BFModule:Init()
    Statsy:PrintMessage("Init")
    self.playerName = Utils:GetPlayerName()
    self.playerServer = Utils:GetPlayerServer()
    self.playerFaction = Utils:GetPlayerFaction()

    self.players = {
        [FACTION_ALIANCE] = {},
        [FACTION_HORDE] = {}
    }
end

function BFModule:InitDB()
    Statsy:PrintMessage("InitDB")
    self.db = Statsy.db
end

-- TODO: Подумать, может убрать прямой вызов?
function BFModule:OnBattlefieldStart()
    self:ClearPlayersInfo()
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("UNIT_TARGET")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:UpdatePartyInfo()
end

function BFModule:OnBattlefieldEnd()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("UNIT_TARGET")
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:UnregisterEvent("CHAT_MSG_ADDON")
end

function BFModule:GROUP_ROSTER_UPDATE()
    self:UpdatePartyInfo()
end

function BFModule:UNIT_TARGET(arg1, unitTarget)
    --Statsy:PrintMessage("UNIT_TARGET: " .. unitTarget)
    self:UpdateTargetInfo(unitTarget .. "target")
end

function BFModule:PLAYER_TARGET_CHANGED()
    self:UpdateTargetInfo("target")
end

function BFModule:UPDATE_MOUSEOVER_UNIT()
    self:UpdateTargetInfo("mouseover")
end

function BFModule:CHAT_MSG_ADDON(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
    local event, msg = self:GetAddonEventMessage(prefix, text, channel, sender)
    if (event and msg and event == ADDON_EVENT_TARGET_INFO) then
        self:UpdateChatTargetInfo(msg)
    end
end

function BFModule:UpdateChatTargetInfo(msg)
    local parts = Utils:Split(msg, ":")
    if (#parts < 2) then
        return
    end
    local fullName, level = parts[1], parts[2]
    self:AddBattlefieldPlayer(self.playerFaction, fullName, level, true)
end

function BFModule:UpdatePartyInfo()
    -- TODO: Плохо обращаться к Statsy напрямую
    self.players[self.playerFaction] = {}   -- Сброс уже сохраненной информации

    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
        if (name) then
            local fullName = self:GetFullName(name, nil)
            self:AddBattlefieldPlayer(self.playerFaction, fullName, level, false)
        end
    end
end

function BFModule:ClearPlayersInfo()
    self.players = {
        [FACTION_ALIANCE] = {},
        [FACTION_HORDE] = {}
    }
end

function BFModule:Test()
    --TODO: метод для тестов
end

function BFModule:UpdateTargetInfo(unitTarget)
    local unitFaction = Utils:GetUnitFaction(unitTarget)
    if (self.playerFaction == unitFaction) then
        return
    end

    -- Отсекаем петов
    local creatureFamily = UnitCreatureFamily(unitTarget)
    if (creatureFamily ~= nil) then
        return
    end

    local name, server = UnitName(unitTarget)
    if (not name) then
        return
    end

    local level = UnitLevel(unitTarget)
    if (not level) then
        return
    end

    local fullName = self:GetFullName(name, server)
    self:AddBattlefieldPlayer(unitFaction, fullName, level, true)

    self:SendAddonEventMessage(ADDON_EVENT_TARGET_INFO, fullName .. ":" .. level)
end

function BFModule:CreatePlayer(fullName, level)
    local player = {
        level = level
    }
    return player
end

function BFModule:AddBattlefieldPlayer(faction, fullName, level, savePdb)
    local player = self:CreatePlayer(fullName, level)
    self.players[faction][fullName] = player

    if (savePdb) then
        self.db.global.players[faction][fullName] = player
    end
end

function BFModule:GetBattlefieldPlayer(faction, fullName)
    -- Получение игрока с актуальной информацией из текущей игровой сессии
    local actualPlayer = BFModule.players[faction][fullName]    --TODO: Избавиться от BFModule
    if (actualPlayer) then
        actualPlayer.archived = false
        return actualPlayer
    end
    
    -- Получение игрока из сохраненной БД
    local archivedPlayer = BFModule.db.global.players[faction][fullName]  --TODO: Избавиться от BFModule
    if (archivedPlayer) then
        archivedPlayer.archived = true
        return archivedPlayer
    end

    return nil
end

function BFModule:WorldStateScoreFrame_Update()
    --Statsy:PrintMessage("Hook: WorldStateScoreFrame_Update")  -- FIXME: Вызывается несколько раз подряд
    
    if not (BFModule.db.profile.showBattlefieldLevels or BFModule.db.profile.showBattlefieldClassColors) then
        return
    end

    local scrollOffset = FauxScrollFrame_GetOffset(WorldStateScoreScrollFrame)
    for i = 1, MAX_SCORE_BUTTONS do
        local name, killingBlows, honorKills, deaths, honorGained, faction, rank, race, class, filename, damageDone, healingDone = GetBattlefieldScore(scrollOffset + i)
        if (name) then
            local nameWidget = _G["WorldStateScoreButton" .. i .. "NameText"]
            local playerName, playerServer = BFModule:SplitNameServer(name)
            local fullName = playerName .. "-" .. playerServer

            local nameStr
            if (BFModule.db.profile.showBattlefieldClassColors) then
                nameStr = Utils:WrapNameInClassColor(playerName, filename) .. "-" .. playerServer
            else
                nameStr = nameWidget.GetText()
            end

            if (BFModule.db.profile.showBattlefieldLevels) then
                local playerFaction = faction == 0 and FACTION_HORDE or FACTION_ALIANCE
                local player = BFModule:GetBattlefieldPlayer(playerFaction, fullName)
                if (player) then
                    local lvlColor = player.archived and COLOR_GREY or "FFFFFFFF"   --TODO: Переделать цвета в константах без |c
                    nameStr = " " .. WrapTextInColorCode(player.level, lvlColor) .. " " .. nameStr
                end
            end

            nameWidget:SetFormattedText(nameStr)
		end
    end
end

-- TODO: Перенести в Utils
function BFModule:GetFullName(name, server)
    if (server) then
        return name .. "-" .. server
    end
    local playerName, playerServer = self:SplitNameServer(name)
    return playerName .. "-" .. playerServer
end

-- TODO: Перенести в Utils
function BFModule:SplitNameServer(nameServer)
    local name, server
    if (string.match(nameServer, "-")) then
        name, server = string.match(nameServer, "(.-)%-(.*)$")
    else
        name = nameServer
        server = self.playerServer
    end
    return name, server
end

-- TODO: Перенести в Utils, сделать общи метод
function BFModule:SendAddonEventMessage(event, msg)
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, event .. "@" .. msg, "INSTANCE_CHAT");
end

function BFModule:GetAddonEventMessage(prefix, msg, channel, sender)
    if (prefix ~= ADDON_PREFIX) then
        return
    end
    if (channel ~= "INSTANCE_CHAT") then
        return
    end
    if (sender == self.playerName) then
        return
    end

    local parts = Utils:Split(msg, "@")
    if (#parts > 1) then
        return part[1], part[2]
    elseif (#parts == 1) then
        return part[1], nil
    else
        return nil, nil
    end
end

-- TODO: Перенести в Utils
--[[ function BFModule:WrapTextInFactionColor(text, faction)
    return WrapTextInColorCode(name, faction == FACTION_ALIANCE and "FF" or "FF")
end ]]

--TODO: Использовать AceHook
hooksecurefunc("WorldStateScoreFrame_Update", function()
    BFModule:WorldStateScoreFrame_Update()
end)