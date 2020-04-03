local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local StatsyInfo = LDB:NewDataObject("Statsy Info", {
	type = "data source",
	icon = "Interface\\Icons\\ability_marksmanship",
	text = "",
	updatePeriod = 300,	--TODO: Переделать функционал по обновлению на событие окончания игр
	elapsed = 300
})

function StatsyInfo:OnTooltipShow()
	local rankName, rankNumber = Statsy:GetPlayerPVPRankInfo()
	self:AddLine(rankName .. " " .. rankNumber)
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

function StatsyInfo:CreateFrame()
	local frame = CreateFrame("frame")
	frame:SetScript("OnUpdate", function(self, elapse)
		StatsyInfo.elapsed = StatsyInfo.elapsed + elapse
		if StatsyInfo.elapsed < StatsyInfo.updatePeriod then
			return
		end

		StatsyInfo.elapsed = 0
		local wins, losses, winRate = Statsy:GetWinsLosses()
		StatsyInfo.text = string.format(COLOR_GREEN .. "W:%d " .. COLOR_RED .. "L:%d " .. COLOR_YELLOW .. "WR:%s", wins, losses, winRate)

		local rankName, rankNumber = Statsy:GetPlayerPVPRankInfo()
		local rankNumberStr = rankNumber >= 10 and rankNumber or ("0" .. rankNumber)
		StatsyInfo.icon = "Interface\\PvPRankBadges\\PvPRank" .. rankNumberStr
	end)
end

StatsyInfo:CreateFrame()