--local AceGUI = LibStub("AceGUI-3.0")
--local AceEvent = LibStub("AceEvent-3.0")

local GUI = {
    testFrame = nil
}

function GUI:TestFrameShow()
    if (self.testFrame ~= nil) then
        return
    end
    self:TestFrameCreate()
end

function GUI:TestFrameHide()
    if (self.testFrame == nil) then
        return
    end
    self.testFrame:Hide()
    self.testFrame:SetParent(nil)
    self.testFrame = nil
end

function GUI:TestFrameCreate()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("BACKGROUND")
    f:SetWidth(64)
    f:SetHeight(64)

    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetTexture("Interface\\Icons\\Ability_Ambush")
    t:SetAllPoints(f)
    f.texture = t

    f:SetPoint("TOPLEFT", 64, -64)
    f:Show()

    self.testFrame = f
end

--[[
-- Пример инициализации через функцию инициализации в основном методе
function GUI:Init()
    --Statsy.GUI = GUI
end

Statsy:AddInitFunction(GUI:Init)
]]

--[[
-- Пример инициализации через события
function GUI:MessageHandler(handlerMethod, ...)
    self[handlerMethod](...)
end

AceEvent:RegisterMessage("GUI", self:MessageHandler)
]]