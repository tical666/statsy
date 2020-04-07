local GUI = {
    optionsFrame = nil,
    db = nil
}

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Statsy")
LibStub("AceEvent-3.0"):Embed(GUI)

function GUI:InitDB(db)
    self.db = db
end

function GUI:OptionsFrameToggle()
    if (self.optionsFrame == nil) then
        self:OptionsFrameCreate()
    else
        AceGUI:Release(self.optionsFrame)
        self.optionsFrame = nil
    end
end

function GUI:OptionsFrameCreate()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Statsy Options")
    frame:SetCallback("OnClose",
        function(widget)
            self.optionsFrame = nil
            AceGUI:Release(widget)
        end)
    frame:SetLayout("Fill")

    scrollContainer = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("List")
    frame:AddChild(scrollContainer)

    local commonContainer = self:CreateModelContainer(scrollContainer, L["GUI_COMMON"])

    local cbMcs = AceGUI:Create("CheckBox")
    cbMcs:SetLabel(L["GUI_MAKE_CONFIRM_SCREENSHOTS"])
    cbMcs:SetValue(self.db.profile.makeConfirmScreenshots)
    cbMcs:SetWidth(250)
    cbMcs:SetCallback("OnValueChanged",
        function(arg1, arg2, value)
            self:SetMakeConfirmScreenshots(value)
        end)
    commonContainer:AddChild(cbMcs)

    local cbScw = AceGUI:Create("CheckBox")
    cbScw:SetLabel(L["GUI_SEND_CONFIRM_WHISPER"])
    cbScw:SetValue(self.db.profile.sendConfirmWhisper)
    cbScw:SetWidth(250)
    cbScw:SetCallback("OnValueChanged",
        function(arg1, arg2, value)
            self:SetSendConfirmWhisper(value)
        end)
    commonContainer:AddChild(cbScw)

    local cbDm = AceGUI:Create("CheckBox")
    cbDm:SetLabel(L["GUI_DEBUG_MESSAGES"])
    cbDm:SetValue(self.db.profile.debugMessages)
    cbDm:SetWidth(250)
    cbDm:SetCallback("OnValueChanged",
        function(arg1, arg2, value)
            self:SetDebugMessages(value)
        end)
    commonContainer:AddChild(cbDm)

    -- TODO: Отрефакторить и сделать по аналогии с кодом из Statsy
    -- Общая статистика со всех БГ
    local tscFields = {"games", "wins", "losses", "winRate", "commonStats"}
    self:CreateModelCheckboxGroup(scrollContainer, L["GUI_TOTAL_COMMONSTATS"], BATTLEFIELD_NONE, tscFields, true)

    -- Максимальная статистика со всех БГ
    local tmsFields = {"maxStats"}
    self:CreateModelCheckboxGroup(scrollContainer, L["GUI_TOTAL_MAXSTATS"], BATTLEFIELD_NONE, tmsFields, false)

    -- Общая статистика на "Ущелье Песни Войны"
    local wcsFields = {"games", "wins", "losses", "winRate", "commonStats"}
    local wcsTitle = string.format(L["GUI_BATTLEFIELD_COMMONSTATS"], L["SYSTEM_BATTLEFIELD_WARSONG"])
    self:CreateModelCheckboxGroup(scrollContainer, wcsTitle, BATTLEFIELD_WARSONG, wcsFields, true)

    -- Максимальная статистика на "Ущелье Песни Войны"
    local wmsFields = {"maxStats"}
    local wmsTitle = string.format(L["GUI_BATTLEFIELD_MAXSTATS"], L["SYSTEM_BATTLEFIELD_WARSONG"])
    self:CreateModelCheckboxGroup(scrollContainer, wmsTitle, BATTLEFIELD_WARSONG, wmsFields, false)

    -- Общая статистика на "Низина Арати"
    local abcsFields = {"games", "wins", "losses", "winRate", "commonStats"}
    local abcsTitle = string.format(L["GUI_BATTLEFIELD_COMMONSTATS"], L["SYSTEM_BATTLEFIELD_ARATHI"])
    self:CreateModelCheckboxGroup(scrollContainer, abcsTitle, BATTLEFIELD_ARATHI, abcsFields, true)

    -- Максимальная статистика на "Низина Арати"
    local abmsFields = {"maxStats"}
    local abmsTitle = string.format(L["GUI_BATTLEFIELD_MAXSTATS"], L["SYSTEM_BATTLEFIELD_ARATHI"])
    self:CreateModelCheckboxGroup(scrollContainer, abmsTitle, BATTLEFIELD_ARATHI, abmsFields, false)

    -- Общая статистика на "Альтеракская Долина"
    local avcsFields = {"games", "wins", "losses", "winRate", "commonStats"}
    local avcsTitle = string.format(L["GUI_BATTLEFIELD_COMMONSTATS"], L["SYSTEM_BATTLEFIELD_ALTERAC"])
    self:CreateModelCheckboxGroup(scrollContainer, avcsTitle, BATTLEFIELD_ALTERAC, avcsFields, true)

    -- Максимальная статистика на "Альтеракская Долина"
    local avmsFields = {"maxStats"}
    local avmsTitle = string.format(L["GUI_BATTLEFIELD_MAXSTATS"], L["SYSTEM_BATTLEFIELD_ALTERAC"])
    self:CreateModelCheckboxGroup(scrollContainer, avmsTitle, BATTLEFIELD_ALTERAC, avmsFields, false)

    -- Label для фикса ошибки когда не вмещается всё содержимое
    local fixLb = AceGUI:Create("Label")
    scrollContainer:AddChild(fixLb)

    self.optionsFrame = frame
end

function GUI:CreateModelCheckboxGroup(container, text, battlefield, fields, isCommon)
    local props = Utils:GetParentPropertiesFromArray(self.db.char.stats[battlefield], fields)
    local c = self:CreateModelContainer(container, text)
    for i = 1, #props do
        local p = props[i]
        self:CreateModelCheckBox(c, battlefield, p)
    end

    self:CreateButtonsGroup(c, battlefield, isCommon)
end

function GUI:CreateModelContainer(container, text)
    local g = AceGUI:Create("InlineGroup")
    g:SetTitle(text .. ":")
    g:SetFullWidth(true)
    g:SetLayout("Flow")
    container:AddChild(g)
    return g
end

function GUI:CreateModelCheckBox(container, battlefield, path)
    local bfStats = self.db.char.stats[battlefield]
    local pathArray = Utils:Split(path, ".")
    local localeId = pathArray[#pathArray]
    local locale = "STATS_" .. string.upper(localeId)
    local modelPart = Utils:GetPropByPathArray(bfStats, pathArray)

    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(L[locale])
    cb:SetValue(modelPart.report)
    cb:SetWidth(200)
    cb:SetCallback("OnValueChanged",
        function(arg1, arg2, value)
            modelPart.report = value
        end)
    container:AddChild(cb)
end

function GUI:CreateButtonsGroup(container, battlefield, isCommon)
    local btnsGroup = AceGUI:Create("SimpleGroup")
    btnsGroup:SetLayout("Flow")
    btnsGroup:SetFullWidth(true)
    container:AddChild(btnsGroup)

    local sayBtn = AceGUI:Create("Button")
    sayBtn:SetText(L["GUI_SEND_SAY"])
    sayBtn:SetCallback("OnClick", function()
        Statsy:PrintGroupReport(battlefield, isCommon, CHAT_SAY)
    end)
    btnsGroup:AddChild(sayBtn)

    local partyBtn = AceGUI:Create("Button")
    partyBtn:SetText(L["GUI_SEND_PARTY"])
    partyBtn:SetCallback("OnClick",
        function()
            Statsy:PrintGroupReport(battlefield, isCommon, CHAT_PARTY)
        end)
    btnsGroup:AddChild(partyBtn)

    local guildBtn = AceGUI:Create("Button")
    guildBtn:SetText(L["GUI_SEND_GUILD"])
    guildBtn:SetCallback("OnClick",
        function()
            Statsy:PrintGroupReport(battlefield, isCommon, CHAT_GUILD)
        end)
    btnsGroup:AddChild(guildBtn)
end

function GUI:SetMakeConfirmScreenshots(value)
    self.db.profile.makeConfirmScreenshots = value
end

function GUI:SetSendConfirmWhisper(value)
    self.db.profile.sendConfirmWhisper = value
end

function GUI:SetDebugMessages(value)
    self.db.profile.debugMessages = value
end

function GUI:MESSAGE_HANDLER(arg1, handlerMethod, ...)
    self[handlerMethod](self, ...)
end

GUI:RegisterMessage("GUI", "MESSAGE_HANDLER")