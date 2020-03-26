local AceEvent = LibStub("AceEvent-3.0")

local StatsyMinimap = {}

StatsyMinimap.StatsyButton = LibStub("LibDBIcon-1.0")

StatsyMinimap.StatsyLDB = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Statsy", {
	type = "launcher",
	text = "Statsy",
    icon = "Interface\\Icons\\ability_marksmanship",
    OnTooltipShow = function(tooltip)
		tooltip:AddLine(COLOR_RED .. "Statsy");
		tooltip:AddLine("Report stats to chat")
	end,
	OnClick = function(self, button)
		if (button == MOUSE_BUTTON_LEFT) then
			AceEvent:SendMessage("STATSY", "PrintReport")
		elseif (button == MOUSE_BUTTON_RIGHT) then
			AceEvent:SendMessage("STATSY", "ToggleMakeConfirmScreenshot")
			AceEvent:SendMessage("GUI", "OptionsFrameToggle")
		end
	end
})

function StatsyMinimap.Init()
	print("MinimapButton.Init")
	--TODO: Избавиться от Init метода
    StatsyMinimap.StatsyButton:Register("Statsy", StatsyMinimap.StatsyLDB, Statsy.db.profile.minimap)
end

Statsy:AddInitFunction(StatsyMinimap.Init)