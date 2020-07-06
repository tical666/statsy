Statsy = LibStub("AceAddon-3.0"):NewAddon("Statsy", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
L = LibStub("AceLocale-3.0"):GetLocale("Statsy")

function Statsy:OnInitialize()
    self:InitDB()
    self:Init()
end

function Statsy:InitDB()
    self.db = LibStub("AceDB-3.0"):New("StatsyDB", Model)
    
    self:SendMessage("GUI", "InitDB", self.db)
    self:SendMessage("MINIMAP", "InitDB", self.db)
end

function Statsy:Init()
    self.playerName = Utils:GetPlayerName()
    self.playerServer = Utils:GetPlayerServer()
    self.playerFaction = Utils:GetPlayerFaction()
    self.currentBattlefieldId = BATTLEFIELD_NONE
    self.lastBattlefieldStatus = {}
end

function Statsy:AddInitFunction(func)
    if self.initFunctions == nil then
        self.initFunctions = {}
    end
	self.initFunctions[#self.initFunctions + 1] = func
end

function Statsy:OnEnable()
    self:PrintLoadMessage()
    self.StatsyInfo:Update()  --TODO: переделать

    if (not C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)) then
        Utils:ColorPrint("Error: " .. ADDON_PREFIX .. " prefix already registered!", COLOR_RED)
    end

    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    --self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")

    self:RegisterChatCommand("statsy", "SLASHCOMMAND_STATSY")
    self:RegisterMessage("STATSY", "MESSAGE_HANDLER")
end

function Statsy:OnDisable()
end

function Statsy:UPDATE_BATTLEFIELD_STATUS()
    local maxBattlefieldID = GetMaxBattlefieldID()
    for i = 1, maxBattlefieldID do
        local battlefield = self:GetBattlefieldId()
        if (self.currentBattlefieldId ~= battlefield) then
            self.currentBattlefieldId = battlefield
        end
        
        local status, mapName, instanceID, lowestlevel, highestlevel, teamSize, registeredMatch = GetBattlefieldStatus(i)
        if (self.lastBattlefieldStatus[i] ~= status) then
            self.lastBattlefieldStatus[i] = status
            if (status == "none") then
                self:PrintMessage("UPDATE_BATTLEFIELD_STATUS: None")
            elseif (status == "confirm") then
                local confirmMsg = "Statsy: " .. string.format(L["STATSY_BATTLEFIELD_CONFIRM"], mapName)
                self:SendConfirmToParty(confirmMsg)
                self:SendConfirmWhisper(confirmMsg)
                self:MakeConfirmScreenshot()
            elseif (status == "active") then
                self:PrintMessage("UPDATE_BATTLEFIELD_STATUS: BG Active '" .. mapName .. "'")
                self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
                self:GetModule("BFModule"):OnBattlefieldStart() --TODO: Переделать
            elseif (status == "queued") then
                self:PrintMessage("Statsy: BG Queued '" .. mapName .. "'")
            elseif (status == "error") then
                self:PrintMessage("UPDATE_BATTLEFIELD_STATUS: Error")
            end
        end
    end
end

function Statsy:UPDATE_BATTLEFIELD_SCORE()
    local battlefieldWinner = GetBattlefieldWinner()
    if (battlefieldWinner) then
        self:GetModule("BFModule"):OnBattlefieldEnd(battlefieldWinner)   --TODO: Переделать
        self:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
        print("UPDATE_BATTLEFIELD_SCORE: Winner=" .. battlefieldWinner)
    else
        return
    end
    if (self.currentBattlefieldId == BATTLEFIELD_WARSONG or self.currentBattlefieldId == BATTLEFIELD_ARATHI or self.currentBattlefieldId == BATTLEFIELD_ALTERAC) then
        self:PrintMessage("UPDATE_BATTLEFIELD_SCORE: " .. self.currentBattlefieldId)
        local winnerFaction = battlefieldWinner == 0 and FACTION_HORDE or FACTION_ALIANCE   -- TODO: переделать константы на 0 для орды и 1 для альянса?
        self:OnFactionWins(winnerFaction, self.currentBattlefieldId)
        self:GetBattlefieldScores()
    else
        self:PrintMessage("UPDATE_BATTLEFIELD_SCORE")
    end
end

function Statsy:MESSAGE_HANDLER(arg1, handlerMethod, ...)
    self[handlerMethod](self, ...)
end

function Statsy:OnFactionWins(faction, battlefield)
    self:PrintMessage("Statsy: " .. self:GetFactionName(faction) .. " wins!")
    self:AddGameResult(faction, battlefield)
end

function Statsy:AddGameResult(winFraction, battlefield)
    if (self.playerFaction == winFraction) then
        local wins = self.db.char.stats[battlefield].wins
        wins.value = wins.value + 1
    else
        local losses = self.db.char.stats[battlefield].losses
        losses.value = losses.value + 1
    end
end

function Statsy:GetBattlefieldScores()
    local battlefield = self.currentBattlefieldId
    local numScores = GetNumBattlefieldScores()
    for i = 1, numScores do
        local name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class = GetBattlefieldScore(i)
        if (name == self.playerName) then
            local commonStats = {
                killingBlows = killingBlows,
                deaths = deaths,
                honorableKills = honorableKills
            }
            local specificStats = {}
            if (battlefield == BATTLEFIELD_WARSONG) then
                specificStats = {
                    flagCaptures = GetBattlefieldStatData(i, 1),
                    flagReturns = GetBattlefieldStatData(i, 2)
                }
            elseif (battlefield == BATTLEFIELD_ARATHI) then
                specificStats = {
                    basesAssaulted = GetBattlefieldStatData(i, 1),
                    basesDefended = GetBattlefieldStatData(i, 2)
                }
            elseif (battlefield == BATTLEFIELD_ALTERAC) then
                specificStats = {
                    graveyardsAssaulted = GetBattlefieldStatData(i, 1),
                    graveyardsDefended = GetBattlefieldStatData(i, 2),
                    towersAssaulted = GetBattlefieldStatData(i, 3),
                    towersDefended = GetBattlefieldStatData(i, 4),
                    minesCaptured = GetBattlefieldStatData(i, 5),
                    leadersKilled = GetBattlefieldStatData(i, 6),
                    secondaryObjectives = GetBattlefieldStatData(i, 7)
                }
            end
            self:AddGameStats(battlefield, commonStats, specificStats)
            self:AddGameMaxStats(battlefield, commonStats, specificStats)
            break
        end
    end
    -- Обновление информации в информационном DataBroker-е
    self.StatsyInfo:Update()
end

function Statsy:AddGameStats(battlefield, commonStats, specificStats)
    local savedStats = self.db.char.stats[battlefield]

    local cs = savedStats.commonStats
    cs.killingBlows.value = cs.killingBlows.value + commonStats.killingBlows
    cs.deaths.value = cs.deaths.value + commonStats.deaths
    cs.honorableKills.value = cs.honorableKills.value + commonStats.honorableKills
    
    if (battlefield == BATTLEFIELD_WARSONG) then
        cs.flagCaptures.value = cs.flagCaptures.value + specificStats.flagCaptures
        cs.flagReturns.value = cs.flagReturns.value + specificStats.flagReturns
    elseif (battlefield == BATTLEFIELD_ARATHI) then
        cs.basesAssaulted.value = cs.basesAssaulted.value + specificStats.basesAssaulted
        cs.basesDefended.value = cs.basesDefended.value + specificStats.basesDefended
    elseif (battlefield == BATTLEFIELD_ALTERAC) then
        cs.graveyardsAssaulted.value = cs.graveyardsAssaulted.value + specificStats.graveyardsAssaulted
        cs.graveyardsDefended.value = cs.graveyardsDefended.value + specificStats.graveyardsDefended
        cs.towersAssaulted.value = cs.towersAssaulted.value + specificStats.towersAssaulted
        cs.towersDefended.value = cs.towersDefended.value + specificStats.towersDefended
        cs.minesCaptured.value = cs.minesCaptured.value + specificStats.minesCaptured
        cs.leadersKilled.value = cs.leadersKilled.value + specificStats.leadersKilled
        cs.secondaryObjectives.value = cs.secondaryObjectives.value + specificStats.secondaryObjectives
    end
end

function Statsy:AddGameMaxStats(battlefield, commonStats, specificStats)
    local savedStats = self.db.char.stats[battlefield]

    local ms = savedStats.maxStats
    ms.killingBlows.value = commonStats.killingBlows > ms.killingBlows.value and commonStats.killingBlows or ms.killingBlows.value
    ms.deaths.value = commonStats.deaths > ms.deaths.value and commonStats.deaths or ms.deaths.value
    ms.honorableKills.value = commonStats.honorableKills > ms.honorableKills.value and commonStats.honorableKills or ms.honorableKills.value

    if (battlefield == BATTLEFIELD_WARSONG) then
        ms.flagCaptures.value = specificStats.flagCaptures > ms.flagCaptures.value and specificStats.flagCaptures or ms.flagCaptures.value
        ms.flagReturns.value = specificStats.flagReturns > ms.flagReturns.value and specificStats.flagReturns or ms.flagReturns.value
    elseif (battlefield == BATTLEFIELD_ARATHI) then
        ms.basesAssaulted.value = specificStats.basesAssaulted > ms.basesAssaulted.value and specificStats.basesAssaulted or ms.basesAssaulted.value
        ms.basesDefended.value = specificStats.basesDefended > ms.basesDefended.value and specificStats.basesDefended or ms.basesDefended.value
    elseif (battlefield == BATTLEFIELD_ALTERAC) then
        ms.graveyardsAssaulted.value = specificStats.graveyardsAssaulted > ms.graveyardsAssaulted.value and specificStats.graveyardsAssaulted or ms.graveyardsAssaulted.value
        ms.graveyardsDefended.value = specificStats.graveyardsDefended > ms.graveyardsDefended.value and specificStats.graveyardsDefended or ms.graveyardsDefended.value
        ms.towersAssaulted.value = specificStats.towersAssaulted > ms.towersAssaulted.value and specificStats.towersAssaulted or ms.towersAssaulted.value
        ms.towersDefended.value = specificStats.towersDefended > ms.towersDefended.value and specificStats.towersDefended or ms.towersDefended.value
        ms.minesCaptured.value = specificStats.minesCaptured > ms.minesCaptured.value and specificStats.minesCaptured or ms.minesCaptured.value
        ms.leadersKilled.value = specificStats.leadersKilled > ms.leadersKilled.value and specificStats.leadersKilled or ms.leadersKilled.value
        ms.secondaryObjectives.value = specificStats.secondaryObjectives > ms.secondaryObjectives.value and specificStats.secondaryObjectives or ms.secondaryObjectives.value
    end
end

function Statsy:SLASHCOMMAND_STATSY()
    self:PrintReport()
    self:SendMessage("GUI", "OptionsToggle")
end

function Statsy:PrintReport()
    Utils:ColorPrint("Statsy report:", COLOR_RED)

    local report = self:CreateReport()
    for g, group in ipairs(report) do
        if (#group.elements > 0) then
            Utils:ColorPrint("[" .. group.title .. "]:", COLOR_BLUE)

            for e, element in ipairs(group.elements) do
                local elementMsg = element.title .. ": " .. element.value
                print(elementMsg)
            end
        end
    end
end

function Statsy:PrintGroupReport(battlefield, isCommon, chatType)
    local group = self:CreateReportGroup(battlefield, isCommon)

    if (#group.elements == 0) then
        return
    end

    local groupMsg = "[Statsy - " .. group.title .. "]:"
    self:SendTypedMessage(groupMsg, chatType)

    for e, element in ipairs(group.elements) do
        local elementMsg = element.title .. ": " .. element.value
        self:SendTypedMessage(elementMsg, chatType)
    end
end

function Statsy:CreateReport()
    local report = {}
    local stats = self:GetStatsCopy()

    local bfs = Utils:DeepCopy(ALL_BATTLEFIELDS)
    table.insert(bfs, 1, BATTLEFIELD_NONE)

    local fieldGroups = {true, false}   -- common or max

    for b, battlefield in ipairs(bfs) do
        for f, fieldGroup in ipairs(fieldGroups) do
            local group = self:CreateReportGroup(battlefield, fieldGroup, stats)
            table.insert(report, group)
        end
    end

    return report
end

function Statsy:CreateReportGroup(battlefield, isCommon, stats)
    local group = {
        title = nil,
        elements = {}
    }

    local fields = self:GetGroupFields(isCommon)
    local title = self:GetGroupTitle(battlefield, isCommon)

    if (stats == nil) then
        stats = self:GetStatsCopy()
    end

    group.title = title
    group.elements = self:CreateReportElements(battlefield, stats, fields)

    return group
end

function Statsy:CreateReportElements(battlefield, stats, fields)
    local elements = {}
    local bfStats = stats[battlefield]
    local props = Utils:GetParentPropertiesFromArray(bfStats, fields)

    for i, prop in ipairs(props) do
        local element = self:CreateReportElement(bfStats, prop)
        if (element ~= nil) then
            table.insert(elements, element)
        end
    end

    return elements
end

function Statsy:CreateReportElement(bfStats, path)
    local pathArray = Utils:Split(path, ".")
    local localeId = pathArray[#pathArray]
    local locale = "STATS_" .. string.upper(localeId)
    local modelPart = Utils:GetPropByPathArray(bfStats, pathArray)

    if (modelPart ~= nil and modelPart.report) then
        return {
            title = L[locale],
            value = modelPart.value
        }
    else
        return nil
    end
end

function Statsy:GetGroupTitle(battlefield, isCommon)
    local title
    if (battlefield == BATTLEFIELD_NONE) then
        title = isCommon and L["GUI_TOTAL_COMMONSTATS"] or L["GUI_TOTAL_MAXSTATS"]
    elseif (battlefield == BATTLEFIELD_WARSONG) then
        title = isCommon and L["GUI_BATTLEFIELD_COMMONSTATS"] or L["GUI_BATTLEFIELD_MAXSTATS"]
        title = string.format(title, L["SYSTEM_BATTLEFIELD_WARSONG"])
    elseif (battlefield == BATTLEFIELD_ARATHI) then
        title = isCommon and L["GUI_BATTLEFIELD_COMMONSTATS"] or L["GUI_BATTLEFIELD_MAXSTATS"]
        title = string.format(title, L["SYSTEM_BATTLEFIELD_ARATHI"])
    elseif (battlefield == BATTLEFIELD_ALTERAC) then
        title = isCommon and L["GUI_BATTLEFIELD_COMMONSTATS"] or L["GUI_BATTLEFIELD_MAXSTATS"]
        title = string.format(title, L["SYSTEM_BATTLEFIELD_ALTERAC"])
    end
    return title
end

function Statsy:GetGroupFields(isCommon)
    if isCommon then
        return {"games", "wins", "losses", "winRate", "commonStats"}
    else
        return {"maxStats"}
    end
end

function Statsy:CalcSumStats(stats)
    local sumGames, sumWins, sumLosses, sumWinRate = 0, 0, 0, 0
    local sumKillingBlows, sumDeaths, sumHonorableKills = 0, 0, 0
    local maxKillingBlows, maxDeaths, maxHonorableKills = 0, 0, 0

    for i = 1, #ALL_BATTLEFIELDS do
        local battlefield = ALL_BATTLEFIELDS[i]

        local bfStats = stats[battlefield]
        local bfGames = bfStats.wins.value + bfStats.losses.value
        local bfWinRate = bfGames == 0 and 0 or math.floor(bfStats.wins.value * 100 / bfGames)

        bfStats.games.value = bfGames
        bfStats.winRate.value = Utils:FormatWinRate(bfWinRate, self.db.profile.showUpWinRateGames, bfStats.wins.value, bfStats.losses.value)

        sumGames = sumGames + bfGames
        sumWins = sumWins + bfStats.wins.value
        sumLosses = sumLosses + bfStats.losses.value

        local bfCs = bfStats.commonStats
        sumKillingBlows = sumKillingBlows + bfCs.killingBlows.value
        sumDeaths = sumDeaths + bfCs.deaths.value
        sumHonorableKills = sumHonorableKills + bfCs.honorableKills.value

        local bfMs = bfStats.maxStats
        maxKillingBlows = maxKillingBlows >= bfMs.killingBlows.value and maxKillingBlows or bfMs.killingBlows.value
        maxDeaths = maxDeaths >= bfMs.deaths.value and maxDeaths or bfMs.deaths.value
        maxHonorableKills = maxHonorableKills >= bfMs.honorableKills.value and maxHonorableKills or bfMs.honorableKills.value
    end
    
    sumWinRate = sumGames == 0 and 0 or math.floor(sumWins * 100 / sumGames)

    local totalStats = stats[BATTLEFIELD_NONE]
    totalStats.games.value = sumGames
    totalStats.wins.value = sumWins
    totalStats.losses.value = sumLosses
    totalStats.winRate.value = Utils:FormatWinRate(sumWinRate, self.db.profile.showUpWinRateGames, totalStats.wins.value, totalStats.losses.value)

    local tsCs = totalStats.commonStats
    tsCs.killingBlows.value = sumKillingBlows
    tsCs.deaths.value = sumDeaths
    tsCs.honorableKills.value = sumHonorableKills

    local tsMs = totalStats.maxStats
    tsMs.killingBlows.value = maxKillingBlows
    tsMs.deaths.value = maxDeaths
    tsMs.honorableKills.value = maxHonorableKills
end

function Statsy:MakeConfirmScreenshot()
    if (self.db.profile.makeConfirmScreenshots) then
        self:PrintMessage("MakeConfirmScreenshot")
        self:ScheduleTimer(function()   -- Таймер для ожидания появления окна подтверждения перед скриншотом
            Screenshot()
        end, 1)
    end
end

function Statsy:PrintLoadMessage()
    Utils:ColorPrint("Statsy: Loaded", COLOR_RED)
end

function Statsy:SendTypedMessage(msg, chatType)
    if chatType == CHAT_PRINT then
        print(msg)
    elseif chatType == CHAT_SAY then
        SendChatMessage(msg , "SAY")
    elseif chatType == CHAT_PARTY then
        self:SendPartyMessage(msg)
    elseif chatType == CHAT_GUILD then
        SendChatMessage(msg , "GUILD")
    end
end

function Statsy:SendPartyMessage(msg)
    local chatType = nil
    if (UnitInBattleground("player") ~= nil) then
        chatType = "INSTANCE_CHAT"
    elseif IsInRaid() then
        chatType = "RAID"
    elseif IsInGroup() then
        chatType = "PARTY"
    end
    if (chatType ~= nil) then
        SendChatMessage(msg , chatType);
    else
        print(msg)
    end
end

function Statsy:SendConfirmToParty(msg)
    if (self.db.profile.sendConfirmToParty) then
        self:SendPartyMessage(msg)
    end
end

function Statsy:SendConfirmWhisper(msg)
    if (self.db.profile.sendConfirmWhisper) then
        SendChatMessage(msg, "WHISPER", nil, self.playerName)
    end
end

function Statsy:GetStatsCopy()
    local stats = Utils:DeepCopy(self.db.char.stats)
    self:CalcSumStats(stats)
    return stats
end

function Statsy:GetBattlefieldId()
    local name, typeName, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapId, lfgID = GetInstanceInfo()
    if Utils:Contains(ALL_BATTLEFIELDS, instanceMapId) then
        return instanceMapId
    else
        return BATTLEFIELD_NONE
    end
end

function Statsy:GetBattlefieldGroupName(battlefieldId)
    if (battlefieldId == BATTLEFIELD_NONE) then
        return L["GUI_TOTAL_COMMONSTATS_SHORT"]
    elseif (battlefieldId == BATTLEFIELD_WARSONG) then
        return L["SYSTEM_BATTLEFIELD_WARSONG"]
    elseif (battlefieldId == BATTLEFIELD_ARATHI) then
        return L["SYSTEM_BATTLEFIELD_ARATHI"]
    elseif (battlefieldId == BATTLEFIELD_ALTERAC) then
        return L["SYSTEM_BATTLEFIELD_ALTERAC"]
    else
        return nil
    end
end

--TODO: Подумать как избавиться от этого
function Statsy:GetFactionName(faction)
    if (faction == FACTION_ALIANCE) then
        return "Aliance"
    elseif (faction == FACTION_HORDE) then
        return "Horde"
    else
        return nil
    end
end

function Statsy:PrintMessage(msg)
    if not self.db.profile.debugMessages then
        return
    end
    print(msg)
end

function Statsy:GetWinsLosses()
    local stats = self:GetStatsCopy()
    local totalStats = stats[BATTLEFIELD_NONE]
    return totalStats.wins.value, totalStats.losses.value, totalStats.winRate.value
end

-- Метод для тестов TODO: Убрать
function Statsy:Test()
    if (self.playerName ~= ADDON_TESTER_NAME) then
        return
    end

    Statsy:PrintMessage("Statsy:Test")
    --QueryAuctionItems("Масляный черноротик")
    --local BFModule = self:GetModule("BFModule")
    --BFModule:UpdatePartyInfoTest()
    --BFModule:FixDatabase()
    --BFModule:OptimizeDatabase()
end