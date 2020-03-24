Statsy = LibStub("AceAddon-3.0"):NewAddon("Statsy", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
L = LibStub("AceLocale-3.0"):GetLocale("Statsy")

function Statsy:OnInitialize()
    self:InitDB()
    self:Init()
    self:RunInitFunctions()
end

function Statsy:InitDB()
    local defaults = {
        char = {
            lastBattlefieldStatus = {},
            stats = {
                [BATTLEFIELD_WARSONG] = {
                    wins = 0,
                    losses = 0,
                    commonStats = {
                        killingBlows = 0,
                        deaths = 0,
                        honorableKills = 0,
                        flagCaptures = 0,
                        flagReturns = 0
                    }
                },
                [BATTLEFIELD_ARATHI] = {
                    wins = 0,
                    losses = 0,
                    commonStats = {
                        killingBlows = 0,
                        deaths = 0,
                        honorableKills = 0,
                        basesAssaulted = 0,
                        basesDefended = 0
                    }
                },
                [BATTLEFIELD_ALTERAC] = {
                    wins = 0,
                    losses = 0,
                    commonStats = {
                        killingBlows = 0,
                        deaths = 0,
                        honorableKills = 0,
                        graveyardsAssaulted = 0,
                        graveyardsDefended = 0,
                        towersAssaulted = 0,
                        towersDefended = 0,
                        minesCaptured = 0,
                        leadersKilled = 0,
                        secondaryObjectives = 0
                    }
                }
            }
        },
        profile = {
            makeConfirmScreenshots = false, -- Делать скриншот игры, если есть прок (для отлавливания события вне игры)
            minimap = {
                shown = true,
                locked = false,
                minimapPos = 218
            }
        }
    }
    self.db = LibStub("AceDB-3.0"):New("StatsyDB", defaults)
end

function Statsy:Init()
    self.screenshotTimer = nil
    self.playerName = self:GetPlayerName()
    self.playerFaction = self:GetPlayerFaction() == "Alliance" and FACTION_ALIANCE or FACTION_HORDE
    self.currentBattlefieldId = BATTLEFIELD_NONE
end

function Statsy:AddInitFunction(func)
    if self.initFunctions == nil then
        self.initFunctions = {}
    end
	self.initFunctions[#self.initFunctions + 1] = func
end

function Statsy:RunInitFunctions()
    print("initFunctions: " .. #self.initFunctions)
    for i = 1, #self.initFunctions do
        local func = self.initFunctions[i]
        if func and type(func) == "function" then
            func()
        end
    end
    self.initFunctions = {}
end

function Statsy:OnEnable()
    self:PrintLoadMessage()
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    --self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
    self:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
    self:RegisterChatCommand("statsy", "SLASHCOMMAND_STATSY")
end

function Statsy:OnDisable()
end

function Statsy:UPDATE_BATTLEFIELD_STATUS()
    local maxBattlefieldID = GetMaxBattlefieldID()
    for i = 1, maxBattlefieldID do
        local battlefield = self:GetBattlefieldId()
        if (self.currentBattlefieldId ~= battlefield) then
            self.currentBattlefieldId = battlefield
            --self:ClearBattlefieldsScores()
        end
        
        local status, mapName, instanceID, lowestlevel, highestlevel, teamSize, registeredMatch = GetBattlefieldStatus(i)
        if (self.db.char.lastBattlefieldStatus[i] ~= status) then
            self.db.char.lastBattlefieldStatus[i] = status
            if (status == "none") then
                print("UPDATE_BATTLEFIELD_STATUS: None")
            elseif (status == "confirm") then
                -- TODO: Сделать опциональное уведомление в личку о старте?
                self:SendGroupMessage("Statsy: BG Confirmed '" .. mapName .. "'")
                self:MakeConfirmScreenshot()
            elseif (status == "active") then
                print("UPDATE_BATTLEFIELD_STATUS: BG Active '" .. mapName .. "'")
            elseif (status == "queued") then
                self:SendGroupMessage("Statsy: BG Queued '" .. mapName .. "'")
            elseif (status == "error") then
                print("UPDATE_BATTLEFIELD_STATUS: Error")
            end
        end
    end
end

function Statsy:CHAT_MSG_BG_SYSTEM_HORDE(arg1, text)
    if (self.currentBattlefieldId == BATTLEFIELD_WARSONG) then
        if (text == L["SYSTEM_HORDE_WINS"]) then
            self:OnFactionWins(FACTION_HORDE, BATTLEFIELD_WARSONG)
        end
    end
end

function Statsy:CHAT_MSG_BG_SYSTEM_ALLIANCE(arg1, text)
    if (self.currentBattlefieldId == BATTLEFIELD_WARSONG) then
        if (text == L["SYSTEM_ALIANCE_WINS_1"]) then
            self:OnFactionWins(FACTION_ALIANCE, BATTLEFIELD_WARSONG)
        end
    end
end

function Statsy:CHAT_MSG_BG_SYSTEM_NEUTRAL(arg1, text)
    if (self.currentBattlefieldId == BATTLEFIELD_ARATHI) then
        if (text == L["SYSTEM_HORDE_WINS"]) then
            self:OnFactionWins(FACTION_HORDE, BATTLEFIELD_ARATHI)
        elseif (text == L["SYSTEM_ALIANCE_WINS_2"]) then
            self:OnFactionWins(FACTION_ALIANCE, BATTLEFIELD_ARATHI)
        end
    end
end

function Statsy:UPDATE_BATTLEFIELD_SCORE()
    if self.currentBattlefieldId == BATTLEFIELD_WARSONG then
        print("UPDATE_BATTLEFIELD_SCORE: Warsong")
        self:GetBattlefieldScores()
        self:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
    elseif self.currentBattlefieldId == BATTLEFIELD_ARATHI then
        print("UPDATE_BATTLEFIELD_SCORE: Arathi")
        self:GetBattlefieldScores()
        self:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
    else
        print("UPDATE_BATTLEFIELD_SCORE")
        self:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
    end
end

function Statsy:OnFactionWins(faction, battlefield)
    print("Statsy: " .. self:GetFactionName(faction) .. " wins!")
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    RequestBattlefieldScoreData()
    self:AddGameResult(faction, battlefield)
end

function Statsy:AddGameResult(winFraction, battlefield)
    if (self.playerFaction == winFraction) then
        self.db.char.stats[battlefield].wins = self.db.char.stats[battlefield].wins + 1
    else
        self.db.char.stats[battlefield].losses = self.db.char.stats[battlefield].losses + 1
    end
end

function Statsy:GetBattlefieldScores()
    print("GetBattlefieldScores: start")
    local battlefield = self.currentBattlefieldId
    local numScores = GetNumBattlefieldScores()
    for i = 1, numScores do
        local name, killingBlows, honorableKills, deaths, honorGained, faction, rank, race, class = GetBattlefieldScore(i);
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

            break
        end
    end
    print("GetBattlefieldScores: end")
end

function Statsy:AddGameStats(battlefield, commonStats, specificStats)
    print("AddGameStats")
    local savedStats = self.db.char.stats[battlefield]

    local cs = savedStats.commonStats
    cs.killingBlows = commonStats.killingBlows
    cs.deaths = commonStats.deaths
    cs.honorableKills = commonStats.honorableKills
    
    if (battlefield == BATTLEFIELD_WARSONG) then
        cs.flagCaptures = cs.flagCaptures + specificStats.flagCaptures
        cs.flagReturns = cs.flagReturns + specificStats.flagReturns
    elseif (battlefield == BATTLEFIELD_ARATHI) then
        cs.basesAssaulted = cs.basesAssaulted + specificStats.basesAssaulted
        cs.basesDefended = cs.basesDefended + specificStats.basesDefended
    elseif (battlefield == BATTLEFIELD_ALTERAC) then
        cs.graveyardsAssaulted = cs.graveyardsAssaulted + specificStats.graveyardsAssaulted
        cs.graveyardsDefended = cs.graveyardsDefended + specificStats.graveyardsDefended
        cs.towersAssaulted = cs.towersAssaulted + specificStats.towersAssaulted
        cs.towersDefended = cs.towersDefended + specificStats.towersDefended
        cs.minesCaptured = cs.minesCaptured + specificStats.minesCaptured
        cs.leadersKilled = cs.leadersKilled + specificStats.leadersKilled
        cs.secondaryObjectives = cs.secondaryObjectives + specificStats.secondaryObjectives
    end
end

function Statsy:SLASHCOMMAND_STATSY()
    print(COLOR_RED .. "Statsy report:")
    print("---")

    local stats = self.db.char.stats
    local sumGames, sumWins, sumLosses, sumWinRate = 0, 0, 0, 0
    local sumKillingBlows, sumDeaths, sumHonorableKills = 0, 0, 0

    for i = 1, #ALL_BATTLEFIELDS do
        local battlefield = ALL_BATTLEFIELDS[i]
        local bfName = self:GetBattlefieldName(battlefield)
        local bfStats = stats[battlefield]
        local bfGames = bfStats.wins + bfStats.losses
        local bfWinRate = bfGames == 0 and 0 or (bfStats.wins * 100 / bfGames)

        print("[".. bfName .. "] Games: " .. bfGames .. ", Wins: " .. bfStats.wins .. ", Losses: " .. bfStats.losses .. ", WinRate: " .. string.format("%0.2f", bfWinRate) .. "%")

        local bfCs = bfStats.commonStats
        print("[".. bfName .. "] Killing Blows: " .. bfCs.killingBlows .. ", Deaths: " .. bfCs.deaths .. ", Honorable Kills: " .. bfCs.honorableKills)

        if (battlefield == BATTLEFIELD_WARSONG) then
            print("[".. bfName .. "] Flag Captures: " .. bfCs.flagCaptures .. ", Flag Returns: " .. bfCs.flagReturns)
        elseif (battlefield == BATTLEFIELD_ARATHI) then
            print("[".. bfName .. "] Bases Assaulted: " .. bfCs.basesAssaulted .. ", Bases Defended: " .. bfCs.basesDefended)
        elseif (battlefield == BATTLEFIELD_ALTERAC) then
            print("[".. bfName .. "] Graveyards Assaulted: " .. bfCs.graveyardsAssaulted .. ", Graveyards Defended: " .. bfCs.graveyardsDefended .. ", Towers Assaulted: " .. bfCs.towersAssaulted .. ", Towers Defended: " .. bfCs.towersDefended .. ", Mines Captured: " .. bfCs.minesCaptured .. ", Leaders Killed: " .. bfCs.leadersKilled .. ", Secondary Objectives: " .. bfCs.secondaryObjectives)
        end

        sumGames = sumGames + bfGames
        sumWins = sumWins + bfStats.wins
        sumLosses = sumLosses + bfStats.losses

        sumKillingBlows = sumKillingBlows + bfCs.killingBlows
        sumDeaths = sumDeaths + bfCs.deaths
        sumHonorableKills = sumHonorableKills + bfCs.honorableKills

        print("---")
    end
    
    sumWinRate = sumGames == 0 and 0 or (sumWins * 100 / sumGames)
    print("[Total] Games: " .. sumGames .. ", Wins: " .. sumWins .. ", Losses: " .. sumLosses .. ", WinRate: " .. string.format("%0.2f", sumWinRate) .. "%")
    print("[Total] Killing Blows: " .. sumKillingBlows .. ", Deaths: " .. sumDeaths .. ", Honorable Kills: " .. sumHonorableKills)
end

function Statsy:ToggleMakeConfirmScreenshot()
    self.db.profile.makeConfirmScreenshots = not self.db.profile.makeConfirmScreenshots
    print("MakeConfirmScreenshots: " .. tostring(self.db.profile.makeConfirmScreenshots))
end

function Statsy:MakeConfirmScreenshot()
    if (self.db.profile.makeConfirmScreenshots) then
        print("MakeConfirmScreenshot")
        Screenshot()
    end
end

function Statsy:PrintLoadMessage()
    print(COLOR_RED .. "Statsy: Loaded")
end

function Statsy:SendGroupMessage(msg)
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

function Statsy:GetBattlefieldId()
    local name, typeName, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapId, lfgID = GetInstanceInfo()
    if self:Contains(ALL_BATTLEFIELDS, instanceMapId) then
        return instanceMapId
    else
        return BATTLEFIELD_NONE
    end
end

--TODO: Подумать как избавиться от этого
function Statsy:GetBattlefieldName(battlefieldId)
    if (battlefieldId == BATTLEFIELD_WARSONG) then
        return "Warsong"
    elseif (battlefieldId == BATTLEFIELD_ARATHI) then
        return "Arathi"
    elseif (battlefieldId == BATTLEFIELD_ALTERAC) then
        return "Alterac"
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

function Statsy:GetPlayerName()
    return UnitName("player")
end

function Statsy:GetPlayerFaction()
    return UnitFactionGroup("player")
end

-- TODO: Вынести в Utils
function Statsy:Contains(tab, val)
    for k, v in ipairs(tab) do
        if v == val then
            return true
        end
    end
    return false
end