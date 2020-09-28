Utils = {}

function Utils:GetParentPropertiesFromArray(tbl, pathArray)
    local props = {}
    for i = 1, #pathArray do
        local path = pathArray[i]
        local parentProps = Utils:GetParentProperties(tbl, path)
        for p = 1, #parentProps do
            props[#props + 1] = parentProps[p]
        end
    end
    return props
end

function Utils:GetParentProperties(tbl, path)
    local pathProp = Utils:GetPropByPath(tbl, path)
    local props = {}
    for k, v in pairs(pathProp) do
        props[#props + 1] = path .. "." .. k
        if (k == "report") then
            props = {path}
            break
        end
    end
    return props
end

function Utils:GetPropByPath(tbl, path)
    local pathArray = Utils:Split(path, ".")
    return Utils:GetPropByPathArray(tbl, pathArray)
end

function Utils:GetPropByPathArray(tbl, pathArray)
    local result = tbl
    while #pathArray > 0 do
        part = pathArray[1]
        result = result[part]
        table.remove(pathArray, 1)
    end
    return result
end

function Utils:Split(input, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(input, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function Utils:Contains(tab, val)
    for k, v in ipairs(tab) do
        if v == val then
            return true
        end
    end
    return false
end

function Utils:DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils:DeepCopy(orig_key)] = Utils:DeepCopy(orig_value)
        end
        setmetatable(copy, Utils:DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Utils:PercentFormat(value)
    return string.format("%d%%", value)
end

function Utils:GetPlayerName()
    return UnitName("player")
end

function Utils:GetPlayerServer()
    return GetRealmName()
end

function Utils:GetPlayerFaction()
    return Utils:GetUnitFaction("player")
end

function Utils:GetOppositeFaction()
    local playerFaction = Utils:GetPlayerFaction()
    return playerFaction == FACTION_ALIANCE and FACTION_HORDE or FACTION_ALIANCE
end

function Utils:GetUnitFaction(unitId)
    return UnitFactionGroup(unitId) == "Alliance" and FACTION_ALIANCE or FACTION_HORDE
end

function Utils:GetPlayerPVPRankInfo()
    local rankId = UnitPVPRank("player")
    local rankName, rankNumber = GetPVPRankInfo(rankId)
    return rankName, rankNumber
end

function Utils:WrapNameInClassColor(name, classFilename)
    return WrapTextInColorCode(name, GetClassColorObj(classFilename).colorStr)
end

function Utils:ColorPrint(msg, color)
    print(WrapTextInColorCode(msg, color))
end

function Utils:CalcUpWinRateGames(wins, losses, winRate)
    return math.ceil(((winRate + 1) * losses) / (100 - (winRate + 1)) - wins)
end

function Utils:FormatWinRate(winRate, showUpGames, wins, losses)
    local games = wins + losses

    local upWRText = ""
    if (showUpGames and games > 0 and winRate < 99) then
        local upWR = Utils:CalcUpWinRateGames(wins, losses, winRate)
        upWRText = string.format("(%d)", upWR)
    end

    return Utils:PercentFormat(winRate) .. upWRText
end

function Utils:SendWhisperMessage(msg, playerName)
    SendChatMessage(msg, "WHISPER", nil, playerName)
end

function Utils:SendTypedMessage(msg, chatType)
    if chatType == CHAT_PRINT then
        print(msg)
    elseif chatType == CHAT_SAY then
        SendChatMessage(msg , "SAY")
    elseif chatType == CHAT_PARTY then
        Utils:SendPartyMessage(msg)
    elseif chatType == CHAT_GUILD then
        SendChatMessage(msg , "GUILD")
    end
end

function Utils:SendPartyMessage(msg)
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

function Utils:SendAddonEventMessage(event, msg, chatType, target)
    local chatTypeStr
    if (chatType == CHAT_INSTANCE) then
        chatTypeStr = "INSTANCE_CHAT"
    elseif (chatType == CHAT_WHISPER) then
        chatTypeStr = "WHISPER"
    elseif (chatType == CHAT_GUILD) then
        chatTypeStr = "GUILD"
    else
        Statsy:PrintMessage(WrapTextInColorCode("Error: SendAddonEventMessage unrecognized chatType", COLOR_RED))
    end
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, event .. "@" .. msg, chatTypeStr, target)
end

function Utils:GetAddonEventMessage(prefix, msg, channel, sender)
    if (prefix ~= ADDON_PREFIX) then
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

function Utils:CompareVersions(v1, v2)
    local a1 = Utils:Split(v1, ".")
    local a2 = Utils:Split(v2, ".")
    
    local n1 = tonumber(a1[1])
    local n2 = tonumber(a2[1])
    if (n1 > n2) then
        return 1
    elseif (n1 < n2) then
        return -1
    end

    -- TODO: Избавиться от копипасты
    n1 = tonumber(a1[2])
    n2 = tonumber(a2[2])
    if (n1 > n2) then
        return 1
    elseif (n1 < n2) then
        return -1
    end

    -- TODO: Избавиться от копипасты
    n1 = tonumber(a1[3])
    n2 = tonumber(a2[3])
    if (n1 > n2) then
        return 1
    elseif (n1 < n2) then
        return -1
    end

    return 0
end

function Utils:GetSenderData(sender)
    local parts = Utils:Split(sender, "-")
    return parts[1], parts[2]
end