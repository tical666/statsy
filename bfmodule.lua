local _G = getfenv(0)

local BFModule = Statsy:NewModule("BFModule", "AceEvent-3.0", "AceHook-3.0")

function BFModule:OnInitialize()
    self.db = Statsy.db

    self.players = {
        [FACTION_ALIANCE] = {},
        [FACTION_HORDE] = {}
    }
end

function BFModule:OnEnable()
    --self:RawHook("WorldStateScoreFrame_Update", true)
end

function BFModule:OnDisable()
end

-- TODO: Подумать, может убрать прямой вызов?
function BFModule:OnBattlefieldStart()
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
    self:ArchiveEnemiesPartyInfo()
end

function BFModule:UNIT_TARGET(unitTarget)
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

    local player = {    -- TODO: Повторение кода
        name = fullName,
        level = level,
        archived = false
    }
    self.players[unitFaction][fullName] = player
end

function BFModule:UpdatePartyInfo()
    -- TODO: Плохо обращаться к Statsy напрямую
    self.players[Statsy.playerFaction] = {}   -- Сброс уже сохраненной информации
    local friends = self.players[Statsy.playerFaction]

    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
        if (name) then
            local fullName = self:GetFullName(name, nil)
            local player = {
                name = fullName,
                level = level,  -- FIXME: Почему-то иногда отображается 0
                archived = false
            }
            friends[fullName] = player
        end
    end
end

-- TODO: Подумать как переделать, т.к. архив будет большим
function BFModule:ArchiveEnemiesPartyInfo()
    local enemiesFraction = Statsy.playerFaction == FACTION_ALIANCE and FACTION_HORDE or FACTION_ALIANCE
    local players = self.players[enemiesFraction]
    for name, player in ipairs(players) do
        player.archived = true
    end
end

function BFModule:UpdateTargetInfo(unitTarget)
    local unitFaction = Statsy:GetUnitFaction(unitTarget)
    if (Statsy.playerFaction == unitFaction) then
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

    local player = {    -- TODO: Повторение кода
        name = fullName,
        level = level,
        archived = false
    }
    self.players[unitFaction][fullName] = player

    self:SendAddonEventMessage(ADDON_EVENT_TARGET_INFO, fullName .. ":" .. level)
end

function BFModule:WorldStateScoreFrame_Update()
    --Statsy:PrintMessage("Hook: WorldStateScoreFrame_Update")  -- FIXME: Вызывается несколько раз подряд

    local scrollOffset = FauxScrollFrame_GetOffset(WorldStateScoreScrollFrame)
    for i = 1, MAX_SCORE_BUTTONS do
        local name, killingBlows, honorKills, deaths, honorGained, faction, rank, race, class, filename, damageDone, healingDone = GetBattlefieldScore(scrollOffset + i)
        if (name) then
            local nameWidget = _G["WorldStateScoreButton" .. i .. "NameText"]
            local playerName, playerServer = BFModule:SplitNameServer(name)
            local fullName = playerName .. "-" .. playerServer

            local nameStr = BFModule:WrapNameInClassColor(playerName, filename) .. "-" .. playerServer

            local playerFaction = faction == 0 and FACTION_HORDE or FACTION_ALIANCE
            local player = BFModule.players[playerFaction][fullName]
            if (player) then
                local lvlColor = player.archived and COLOR_GREY or "FFFFFFFF"   --TODO: Переделать цвета в константах без |c
                nameStr = " " .. WrapTextInColorCode(player.level, lvlColor) .. " " .. nameStr
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
        server = Statsy.playerServer
    end
    return name, server
end

-- TODO: Перенести в Utils
function BFModule:WrapNameInClassColor(name, classFilename)
    return WrapTextInColorCode(name, GetClassColorObj(classFilename).colorStr)
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
    if (sender == Statsy.playerName) then
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

hooksecurefunc("WorldStateScoreFrame_Update", function()
    BFModule:WorldStateScoreFrame_Update()
end)