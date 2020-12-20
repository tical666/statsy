local _G = getfenv(0)

local Guild = Statsy:NewModule("Guild", "AceEvent-3.0")

function Guild:OnInitialize()
    self:InitDB()
    self:Init()
end

function Guild:OnEnable()
    self:RegisterEvent("CHAT_MSG_GUILD")
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("CHAT_MSG_ADDON")

    self:SendAddonGuildOnline()
    self:SendAddonVersionToGuild()
end

function Guild:OnDisable()
    self:UnregisterEvent("CHAT_MSG_GUILD")
    self:UnregisterEvent("CHAT_MSG_WHISPER")
    self:UnregisterEvent("CHAT_MSG_ADDON")
end

function Guild:Init()
    self.version = Statsy:GetVersion()
    self.playerName = Utils:GetPlayerName()
    self.players = {}
    self:SavePlayerVersion(self.playerName, self.version)
    self.versionLabel = nil
    self.versionText = nil
end

function Guild:InitDB()
    self.db = Statsy.db
end

function Guild:SendAddonGuildOnline()
    Utils:SendAddonEventMessage(ADDON_EVENT_GUILD_ONLINE, self.playerName, CHAT_GUILD, nil)
end

function Guild:SendAddonVersionToGuild()
    Utils:SendAddonEventMessage(ADDON_EVENT_ADDON_VERSION, self.version, CHAT_GUILD, nil)
end

function Guild:SendAddonVersionToPlayer(playerName)
    Utils:SendAddonEventMessage(ADDON_EVENT_ADDON_VERSION, self.version, CHAT_WHISPER, playerName)
end

function Guild:SendBatlefieldInfoToGuild()
    local info = self:GetCurrentBgInfo()
    if (info == nil) then
        return
    end

    -- Сохранение информации о БГ для себя
    self:SavePlayerBgInfo(self.playerName, info.id, info.instanceID)

    local msg = info.id .. ":" .. info.instanceID
    Utils:SendAddonEventMessage(ADDON_EVENT_BATTLEFIELD_INFO, msg, CHAT_GUILD, nil)
end

function Guild:SendBatlefieldInfoToPlayer(playerName)
    local info = self:GetCurrentBgInfo()
    if (info == nil) then
        return
    end
    local msg = info.id .. ":" .. info.instanceID
    Utils:SendAddonEventMessage(ADDON_EVENT_BATTLEFIELD_INFO, msg, CHAT_WHISPER, playerName)
end

function Guild:CHAT_MSG_GUILD(arg1, text, playerName)
    if (text == CHAT_COMMAND_BG) then
        self:PrintCurrentBgInfo(CHAT_GUILD, nil)
    end
end

function Guild:CHAT_MSG_WHISPER(arg1, text, playerName)
    if (text == CHAT_COMMAND_BG) then
        self:PrintCurrentBgInfo(CHAT_WHISPER, playerName)
    end
end

function Guild:CHAT_MSG_ADDON(arg1, prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
    if (prefix == ADDON_PREFIX) then
        Statsy:PrintMessage(text)
    end
    local event, msg = Utils:GetAddonEventMessage(prefix, text, channel, sender)
    if (not event) then
        return
    end
    local senderName, senderServer = Utils:GetSenderData(sender)
    if (event == ADDON_EVENT_ADDON_VERSION) then
        self:SavePlayerVersion(senderName, msg)
    elseif (event == ADDON_EVENT_GUILD_ONLINE) then
        self:SendAddonVersionToPlayer(senderName)
        self:SendBatlefieldInfoToPlayer(senderName)
    elseif (event == ADDON_EVENT_BATTLEFIELD_INFO) then
        self:ReceiveBgInfo(senderName, msg)
    end
end

function Guild:OnBattlefieldStart()
    self:SendBatlefieldInfoToGuild()
end

function Guild:OnBattlefieldEnd(winner)
    -- Сохранение информации о БГ для себя
    self:SavePlayerBgInfo(self.playerName, BATTLEFIELD_NONE, INSTANCE_ID_NONE)
    
    local msg = BATTLEFIELD_NONE .. ":" .. INSTANCE_ID_NONE
    Utils:SendAddonEventMessage(ADDON_EVENT_BATTLEFIELD_INFO, msg, CHAT_GUILD, nil)
end

function Guild:PrintCurrentBgInfo(chatType, playerName)
    local info = self:GetCurrentBgInfo()
    if (info == nil) then
        return
    end
    local msg = info.mapName .. " " .. info.instanceID
    if (chatType == CHAT_WHISPER) then
        Utils:SendWhisperMessage(msg, playerName)
    else
        Utils:SendTypedMessage(msg, chatType)
    end
end

function Guild:ReceiveBgInfo(playerName, msg)
    local infoParts = Utils:Split(msg, ":")
    if (#infoParts < 2) then
        return
    end

    local id = tonumber(infoParts[1])
    local instanceID = tonumber(infoParts[2])

    if (id == BATTLEFIELD_NONE or Utils:Contains(ALL_BATTLEFIELDS, id)) then
        self:SavePlayerBgInfo(playerName, id, instanceID)
    end
end

function Guild:GetCurrentBgInfo()
    local maxBattlefieldID = GetMaxBattlefieldID()
    for i = 1, maxBattlefieldID do
        local status, mapName, instanceID, lowestlevel, highestlevel, teamSize, registeredMatch = GetBattlefieldStatus(i)
        if (status == "active") then
            -- local name, canEnter, isHoliday, isRandom, battleGroundID, info = GetBattlegroundInfo(i)
            -- return mapName .. " " .. instanceID
            return {
                id = Statsy.currentBattlefieldId,
                mapName = mapName,
                instanceID = instanceID
            }
        end
    end
    return nil
end

function Guild:SavePlayerBgInfo(playerName, id, instanceID)
    if (self.players[playerName] == nil) then
        self.players[playerName] = self:NewPlayer()
    end

    local player = self.players[playerName]
    player.instanceID = instanceID
end

function Guild:SavePlayerVersion(playerName, version)
    if (self.players[playerName] == nil) then
        self.players[playerName] = self:NewPlayer()
    end

    local player = self.players[playerName]
    player.version = version

    if (self.db.global.latestVersion == nil or Utils:CompareVersions(version, self.db.global.latestVersion) == 1) then
        self.db.global.latestVersion = version
    end
end

function Guild:GetPlayer(playerName)
    return self.players[playerName]
end

function Guild:NewPlayer()
    return {
        version = nil,
        instanceID = nil
    }
end

function Guild:GuildStatus_Update()
    local guildOffset = FauxScrollFrame_GetOffset(GuildListScrollFrame)
    local totalMembers, onlineMembers, onlineAndMobileMembers = GetNumGuildMembers()
	local numGuildMembers = 0
	local showOffline = GetGuildRosterShowOffline()
	if (showOffline) then
		numGuildMembers = totalMembers
	else
		numGuildMembers = onlineMembers
    end
    
    for i = 1, GUILDMEMBERS_TO_DISPLAY, 1 do
        local guildIndex = guildOffset + i
        if (guildIndex <= numGuildMembers) then
            local fullName, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(guildIndex)
            if (fullName and online) then
                local displayedName = Ambiguate(fullName, "guild")
                local decoratedName = self:DecorateGuildPlayerName(displayedName)
                local decoratedZone = self:DecorateGuildPlayerZone(displayedName, zone)
                if (FriendsFrame.playerStatusFrame) then
                    getglobal("GuildFrameButton"..i.."Name"):SetText(decoratedName)
                    getglobal("GuildFrameButton"..i.."Zone"):SetText(decoratedZone)
                else
                    getglobal("GuildFrameGuildStatusButton"..i.."Name"):SetText(decoratedName)
                end
            end
        end
    end

    -- TODO: Переписать чтоб не дублировать получение версий и т.д.
    local selectedPlayerIndex = GetGuildRosterSelection()
    if (selectedPlayerIndex > 0) then
        local fullName, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(selectedPlayerIndex)
        local displayedName = Ambiguate(fullName, "guild")

        local selectedPlayerVersion = "-"
        local savedPlayer = self:GetPlayer(displayedName)
        if (savedPlayer ~= nil) then
            selectedPlayerVersion = savedPlayer.version
        end

        local frameHeight = GuildMemberDetailFrame:GetHeight()
        GuildMemberDetailFrame:SetHeight(frameHeight + 14)
        
        if (self.versionLabel == nil) then
            self.versionLabel = GuildMemberDetailFrame:CreateFontString(GuildMemberDetailFrame, "OVERLAY")
            self.versionLabel:SetFontObject(GameFontNormalSmall)
            self.versionLabel:SetPoint("BOTTOMLEFT", 16, 38)
            self.versionLabel:SetText("Версия Statsy:")
        end

        if (self.versionText == nil) then
            local versionLabelWidth = self.versionLabel:GetWidth()
            self.versionText = GuildMemberDetailFrame:CreateFontString(GuildMemberDetailFrame, "OVERLAY")
            self.versionText:SetFontObject(GameFontHighlightSmall)
            self.versionText:SetPoint("BOTTOMLEFT", 16 + versionLabelWidth, 38)
        end
        
        self.versionText:SetText(selectedPlayerVersion)
    end
end

function Guild:DecorateGuildPlayerName(displayedName)
    local savedPlayer = self:GetPlayer(displayedName)
    if (savedPlayer == nil or savedPlayer.version == nil) then
        return displayedName
    end
    local compareResult = Utils:CompareVersions(savedPlayer.version, self.db.global.latestVersion)
    if (compareResult == -1) then
        return WrapTextInColorCode(displayedName, COLOR_ORANGE)
    else
        return WrapTextInColorCode(displayedName, COLOR_GREEN)
    end
end

function Guild:DecorateGuildPlayerZone(displayedName, zone)
    local savedPlayer = self:GetPlayer(displayedName)
    if (savedPlayer == nil or savedPlayer.instanceID == nil or savedPlayer.instanceID == INSTANCE_ID_NONE) then
        return zone
    else
        return savedPlayer.instanceID .. " " .. zone
    end
end

hooksecurefunc("GuildStatus_Update", function()
    Guild:GuildStatus_Update()
end)