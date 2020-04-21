local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

Statsy.StatsyInfo = LDB:NewDataObject("Statsy Info", {
	type = "data source",
	icon = "Interface\\Icons\\ability_marksmanship",
	text = ""
})

local StatsyInfo = Statsy.StatsyInfo

function StatsyInfo:OnTooltipShow()
	self:AddLine(WrapTextInColorCode("Statsy", COLOR_RED))

	local report = Statsy:CreateReport()
    for g, group in ipairs(report) do
		if (#group.elements > 0) then
			self:AddLine(" ")	-- Пустая строка для отступа
			self:AddLine(WrapTextInColorCode("[" .. group.title .. "]:", COLOR_BLUE))

            for e, element in ipairs(group.elements) do
                local elementMsg = element.title .. ": " .. WrapTextInColorCode(element.value, COLOR_WHITE)
				self:AddLine(elementMsg)
			end
        end
    end
end

function StatsyInfo:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	StatsyInfo.OnTooltipShow(GameTooltip)
	GameTooltip:Show()
end

function StatsyInfo:OnLeave()
	GameTooltip:Hide()
end

function StatsyInfo:Update()
	local wins, losses, winRate = Statsy:GetWinsLosses()
	StatsyInfo.text = string.format(
		WrapTextInColorCode("W:%d ", COLOR_GREEN) ..
		WrapTextInColorCode("L:%d ", COLOR_RED) ..
		WrapTextInColorCode("WR:%s", COLOR_YELLOW), 
		wins, losses, winRate)

	local rankName, rankNumber = Utils:GetPlayerPVPRankInfo()
	local rankNumberStr = rankNumber >= 10 and rankNumber or ("0" .. rankNumber)
	StatsyInfo.icon = "Interface\\PvPRankBadges\\PvPRank" .. rankNumberStr
end