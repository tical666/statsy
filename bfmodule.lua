local _G = getfenv(0)

local BFModule = Statsy:NewModule("BFModule", "AceEvent-3.0", "AceHook-3.0")

function BFModule:OnInitialize()
    self:Init()
    self:InitDB()
end

function BFModule:OnEnable()
    --self:RawHook("WorldStateScoreFrame_Update", true)
    --self:RegisterEvent("CHAT_MSG_ADDON")
end

function BFModule:OnDisable()
end

function BFModule:Init()
    self.playerName = Utils:GetPlayerName()
    self.playerServer = Utils:GetPlayerServer()
    self.playerFaction = Utils:GetPlayerFaction()
    self.oppositeFaction = Utils:GetOppositeFaction()

    self.players = {
        [FACTION_ALIANCE] = {},
        [FACTION_HORDE] = {}
    }
    self.numOppositePlayers = 0
end

function BFModule:InitDB()
    self.db = Statsy.db
end

-- TODO: Подумать, может убрать прямой вызов?
function BFModule:OnBattlefieldStart()
    Statsy:PrintMessage("OnBattlefieldStart")
    self:ClearPlayersInfo()
    local visibleOppositePlayers = self:CheckOppositePlayers()
    if (visibleOppositePlayers) then
        Statsy:PrintMessage("OnBattlefieldStart: visible")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        -- TODO: Вставить передачу данных, если событие не вызывается
        local partyBehavior = {
            OnInfo = function(fullName)
                Statsy:PrintMessage("OnInfo (OBS): " .. fullName)
                self:SendInfoToPartyPlayer(fullName)
            end
        }
        self:UpdatePartyInfo(partyBehavior)
    else
        self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    end
    self:RegisterEvent("UNIT_TARGET")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("CHAT_MSG_ADDON")
end

function BFModule:OnBattlefieldEnd(battlefieldWinner)
    self:SavePlayersStats(battlefieldWinner)
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("UNIT_TARGET")
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:UnregisterEvent("CHAT_MSG_ADDON")
    self:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
end

function BFModule:UPDATE_BATTLEFIELD_SCORE()
    Statsy:PrintMessage("UPDATE_BATTLEFIELD_SCORE")
    local visibleOppositePlayers = self:CheckOppositePlayers()
    if (visibleOppositePlayers) then
        Statsy:PrintMessage("UPDATE_BATTLEFIELD_SCORE: visible")
        self:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        local partyBehavior = {
            OnInfo = function(fullName)
                Statsy:PrintMessage("OnInfo (UBS): " .. fullName)
                self:SendInfoToPartyPlayer(fullName)
            end,
            OnJoin = function(fullName)
                Statsy:PrintMessage("OnJoin (UBS): " .. fullName)
            end,
            OnLeave = function(fullName)
                Statsy:PrintMessage("OnLeave (UBS): " .. fullName)
            end
        }
        self:UpdatePartyInfo(partyBehavior)
    end
end

function BFModule:GROUP_ROSTER_UPDATE()
    Statsy:PrintMessage("GROUP_ROSTER_UPDATE")
    local partyBehavior = {
        OnInfo = function(fullName)
            Statsy:PrintMessage("OnInfo (GRS): " .. fullName)
        end,
        OnJoin = function(fullName)
            Statsy:PrintMessage("OnJoin (GRS): " .. fullName)
            self:SendInfoToPartyPlayer(fullName)
        end,
        OnLeave = function(fullName)
            Statsy:PrintMessage("OnLeave (GRS): " .. fullName)
        end
    }
    self:UpdatePartyInfo(partyBehavior)
end

function BFModule:UNIT_TARGET(arg1, unitTarget)
    self:UpdateTargetInfo(unitTarget .. "target")
end

function BFModule:PLAYER_TARGET_CHANGED()
    self:UpdateTargetInfo("target")
end

function BFModule:UPDATE_MOUSEOVER_UNIT()
    self:UpdateTargetInfo("mouseover")
end

function BFModule:CHAT_MSG_ADDON(arg1, prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
    local event, msg = self:GetAddonEventMessage(prefix, text, channel, sender)
    if (not event or not msg) then
        return
    end
    if (event == ADDON_EVENT_TARGET_INFO or event == ADDON_EVENT_JOIN_INFO) then
        self:UpdateChatTargetInfo(msg)
    end
end

function BFModule:UpdateChatTargetInfo(msg)
    local parts = Utils:Split(msg, ":")
    if (#parts < 2) then
        return
    end
    local fullName, level = parts[1], tonumber(parts[2])
    self:AddBattlefieldPlayer(self.oppositeFaction, fullName, level, true)
end

function BFModule:UpdatePartyInfo(behavior)
    local partyPlayers = self.players[self.playerFaction]
    local currentPlayers = {}
    local leavePlayers = {}
    local joinPlayers = {}

    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)
        local fullName = self:GetFullName(name, nil)
        table.insert(currentPlayers, fullName)

        local actualPlayer = partyPlayers[fullName]
        -- Определение новых дружественных игроков
        if (actualPlayer == nil) then
            self:AddBattlefieldPlayer(self.playerFaction, fullName, level, false)
            table.insert(joinPlayers, fullName)
        -- Багфикс для обновления игроков с 0 уровнем
        elseif ((actualPlayer.level == nil or actualPlayer.level == 0) and level ~= 0) then
            actualPlayer.level = level
        end

        if (behavior and behavior.OnInfo) then
            behavior.OnInfo(fullName)
        end
    end

    for i, fullName in ipairs(joinPlayers) do
        if (behavior and behavior.OnJoin) then
            behavior.OnJoin(fullName)
        end
    end

    -- Определение вышедших игроков
    for fullName, partyPlayer in pairs(partyPlayers) do
        if (not Utils:Contains(currentPlayers, fullName)) then
            table.insert(leavePlayers, fullName)
        end
    end

    -- Очистка partyPlayers от вышедших игроков
    for i, fullName in ipairs(leavePlayers) do
        partyPlayers[fullName] = nil

        if (behavior and behavior.OnLeave) then
            behavior.OnLeave(fullName)
        end
    end
end

-- До начала игры информация о противниках иногда недоступна. Необходимо отправлять её после старта.
function BFModule:CheckOppositePlayers()
    Statsy:PrintMessage("CheckOppositePlayers")

    self.numOppositePlayers = 0

    --[[ local numScores = GetNumBattlefieldScores()
    for i = 1, numScores do
        local name, killingBlows, honorKills, deaths, honorGained, faction, rank, race, class, filename, damageDone, healingDone = GetBattlefieldScore(i)
        if (name and faction == self.oppositeFaction) then
            self.numOppositePlayers = self.numOppositePlayers + 1
        end
    end ]]

    local arg1, arg2, arg3, arg4, numPlayers
    if (self.oppositeFaction == FACTION_ALIANCE) then
        arg1, arg2, arg3, arg4, numPlayers = GetBattlefieldTeamInfo(1)  -- Альянс TODO: Переделать на константы
    else
        arg1, arg2, arg3, arg4, numPlayers = GetBattlefieldTeamInfo(0) -- Орда TODO: Переделать на константы
    end
    self.numOppositePlayers = numPlayers

    if (self.numOppositePlayers > 0) then
        return true
    else
        return false
    end
end

function BFModule:SendInfoToPartyPlayer(targetName)
    Statsy:PrintMessage("SendInfoToPartyPlayer: " .. targetName)

    local numScores = GetNumBattlefieldScores()
    self.numOppositePlayers = 0
    for i = 1, numScores do
        local name, killingBlows, honorKills, deaths, honorGained, faction, rank, race, class, filename, damageDone, healingDone = GetBattlefieldScore(i)
        if (name and faction == self.oppositeFaction) then
            self.numOppositePlayers = self.numOppositePlayers + 1

            local playerName, playerServer = BFModule:SplitNameServer(name)
            local fullName = playerName .. "-" .. playerServer

            local player = BFModule:GetBattlefieldPlayer(faction, fullName)
            if (player) then
                self:SendAddonEventMessage(ADDON_EVENT_JOIN_INFO, fullName .. ":" .. player.level, CHAT_WHISPER, targetName)
            end
        end
    end
end

function BFModule:ClearPlayersInfo()
    self.numOppositePlayers = 0    -- Количество противников
    
    self.players = {
        [FACTION_ALIANCE] = {},
        [FACTION_HORDE] = {}
    }
end

function BFModule:UpdateTargetInfo(unitTarget)
    local unitFaction = Utils:GetUnitFaction(unitTarget)
    if (self.playerFaction == unitFaction) then
        return
    end

    -- Отсекаем петов, NPC и призванных существ
    local isPlayer = UnitIsPlayer(unitTarget)
    if (not isPlayer) then
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

    self:SendAddonEventMessage(ADDON_EVENT_TARGET_INFO, fullName .. ":" .. level, CHAT_INSTANCE, nil)
end

function BFModule:CreatePlayer(fullName, level)
    local player = {
        level = level
    }
    return player
end

-- TODO: Оптимизировать, сейчас игрок добавляется каждый раз, даже если уже есть в массивах
function BFModule:AddBattlefieldPlayer(faction, fullName, level, savePdb)
    local player = self:GetBattlefieldPlayer(faction, fullName)
    if (player == nil) then
        player = self:CreatePlayer(fullName, level)
    elseif (level > player.level) then
        player.level = level
    end

    self.players[faction][fullName] = player

    if (savePdb) then
        self.db.global.players[faction][fullName] = player
    end
end

function BFModule:GetBattlefieldPlayer(faction, fullName)
    -- Получение игрока с актуальной информацией из текущей игровой сессии
    local actualPlayer = BFModule.players[faction][fullName]    --TODO: Избавиться от BFModule
    if (actualPlayer) then
        actualPlayer.archived = nil
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
    local numScores = GetNumBattlefieldScores()
    for i = 1, MAX_SCORE_BUTTONS do
        local index = scrollOffset + i
        if (index <= numScores) then
            local name, killingBlows, honorKills, deaths, honorGained, faction, rank, race, class, filename = GetBattlefieldScore(index)
            
            local nameWidget = _G["WorldStateScoreButton" .. i .. "NameText"]
            local playerName, playerServer = BFModule:SplitNameServer(name)
            local fullName = playerName .. "-" .. playerServer

            local nameStr
            if (BFModule.db.profile.showBattlefieldClassColors) then
                nameStr = Utils:WrapNameInClassColor(playerName, filename) .. "-" .. playerServer
            else
                nameStr = nameWidget:GetText()
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
function BFModule:SendAddonEventMessage(event, msg, chatType, target)
    local chatTypeStr
    if (chatType == CHAT_INSTANCE) then
        chatTypeStr = "INSTANCE_CHAT"
    elseif (chatType == CHAT_WHISPER) then
        chatTypeStr = "WHISPER"
    else
        Statsy:PrintMessage(WrapTextInColorCode("Error: SendAddonEventMessage unrecognized chatType", COLOR_RED))
    end
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, event .. "@" .. msg, chatTypeStr, target)
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
        return parts[1], parts[2]
    elseif (#parts == 1) then
        return parts[1], nil
    else
        return nil, nil
    end
end

function BFModule:OptimizeDatabase()
    print("Optimization start")
    local players = BFModule.db.global.players[BFModule.oppositeFaction]
    local num = 0
    for fullName, player in pairs(players) do
        if (player.wins == 0) then
            player.wins = nil
        end
        if (player.losses == 0) then
            player.losses = nil
        end
        player.archived = nil
        num = num + 1
    end
    print("Optimized players: " .. num)
end

function BFModule:FixDatabase()
    BFModule:FixFractionAllocation()
    BFModule:FixZeroStats()
    BFModule:FixRuServers()
    BFModule:FixRuLetters()
end

function BFModule:FixFractionAllocation()
    print("FixFractionAllocation: start")
    local players = BFModule.db.global.players[BFModule.playerFaction]
    local num = 0
    for fullName, player in pairs(players) do
        BFModule.db.global.players[BFModule.oppositeFaction][fullName] = player
        num = num + 1
    end
    BFModule.db.global.players[BFModule.playerFaction] = {}
    print("FixFractionAllocation: Fixed players: " .. num)
end

function BFModule:FixZeroStats()
    print("FixZeroStats: start")
    local players = BFModule.db.global.players[BFModule.oppositeFaction]
    local num = 0
    for fullName, player in pairs(players) do
        local fixed = false
        if (player.wins == 0) then
            player.wins = nil
            fixed = true
        end
        if (player.losses == 0) then
            player.losses = nil
            fixed = true
        end
        if (fixed) then
            num = num + 1
        end
    end
    print("FixZeroStats: Fixed players: " .. num)
end

function BFModule:FixRuServers()
    print("FixRuServers: start")
    local players = BFModule.db.global.players[BFModule.oppositeFaction]
    local num = 0
    for fullName, player in pairs(players) do
        for i = 1, #RU_SERVERS do
            local server = RU_SERVERS[i]
            if (string.find(fullName, server)) then
                BFModule.db.global.players[BFModule.oppositeFaction][fullName] = nil
                num = num + 1
            end
        end
    end
    print("FixRuServers: Fixed players: " .. num)
end

function BFModule:FixRuLetters()
    print("FixRuLetters: start")
    local players = BFModule.db.global.players[BFModule.oppositeFaction]
    local num = 0
    for fullName, player in pairs(players) do
        for i = 1, #RU_LETTERS do
            local letter = RU_LETTERS[i]
            if (string.find(fullName, letter)) then
                BFModule.db.global.players[BFModule.oppositeFaction][fullName] = nil
                num = num + 1
            end
        end
    end
    print("FixRuLetters: Fixed players: " .. num)
end

function BFModule:SavePlayersStats(battlefieldWinner)
    for i = 1, #ALL_FACTIONS do
        local faction = ALL_FACTIONS[i]
        local win = (faction == battlefieldWinner)
        for fullName, player in pairs(self.players[faction]) do -- FIXME: статистика сохранится для всех игроков, даже тех, которые вышли!
            if (win) then
                if (player.wins == nil) then
                    player.wins = 1
                else
                    player.wins = player.wins + 1
                end
            else
                if (player.losses == nil) then
                    player.losses = 1
                else
                    player.losses = player.losses + 1
                end
            end
        end
    end
end

-- TODO: Перенести в Utils
--[[ function BFModule:WrapTextInFactionColor(text, faction)
    return WrapTextInColorCode(name, faction == FACTION_ALIANCE and "FF" or "FF")
end ]]

--TODO: Использовать AceHook
hooksecurefunc("WorldStateScoreFrame_Update", function()
    BFModule:UpdatePartyInfo()
    BFModule:WorldStateScoreFrame_Update()
end)