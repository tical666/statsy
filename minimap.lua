local L = LibStub("AceLocale-3.0"):GetLocale("Statsy")

local StatsyMinimap = {
	db = nil
}

LibStub("AceEvent-3.0"):Embed(StatsyMinimap)

StatsyMinimap.StatsyButton = LibStub("LibDBIcon-1.0")

StatsyMinimap.StatsyLDB = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Statsy", {
	type = "launcher",
	text = "Statsy",
    icon = "Interface\\Icons\\ability_marksmanship",
    OnTooltipShow = function(tooltip)
		tooltip:AddLine(WrapTextInColorCode("Statsy", COLOR_RED));
		tooltip:AddLine(WrapTextInColorCode("Left Click: ", COLOR_WHITE) .. L["MINIMAP_REPORT"])
		tooltip:AddLine(WrapTextInColorCode("Right Click: ", COLOR_WHITE) .. L["MINIMAP_OPTIONS"])
	end,
	OnClick = function(arg1, button)
		if (button == MOUSE_BUTTON_LEFT) then
			StatsyMinimap:SendMessage("STATSY", "PrintReport")
		elseif (button == MOUSE_BUTTON_RIGHT) then
			StatsyMinimap:SendMessage("GUI", "OptionsFrameToggle")
		elseif (button == MOUSE_BUTTON_MIDDLE) then
			StatsyMinimap:SendMessage("STATSY", "Test")
		end
	end
})

function StatsyMinimap:InitDB(db)
	self.db = db
	self.StatsyButton:Register("Statsy", self.StatsyLDB, self.db.profile.minimap)
end

function StatsyMinimap:MESSAGE_HANDLER(arg1, handlerMethod, ...)
    self[handlerMethod](self, ...)
end

StatsyMinimap:RegisterMessage("MINIMAP", "MESSAGE_HANDLER")