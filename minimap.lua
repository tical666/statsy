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
			Statsy:SLASHCOMMAND_STATSY()
		elseif (button == MOUSE_BUTTON_RIGHT) then
			Statsy:ToggleMakeConfirmScreenshot()
		end
	end
})

function StatsyMinimap.Init()
    print("MinimapButton.Init")
    StatsyMinimap.StatsyButton:Register("Statsy", StatsyMinimap.StatsyLDB, Statsy.db.profile.minimap)
end

Statsy:AddInitFunction(StatsyMinimap.Init)