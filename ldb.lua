local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

Statsy.StatsyInfo = LDB:NewDataObject("Statsy Info", {
	type = "data source",
	icon = "Interface\\Icons\\ability_marksmanship",
	text = ""
})

local StatsyInfo = Statsy.StatsyInfo

function StatsyInfo:OnTooltipShow()
	self:AddLine(COLOR_RED .. "Statsy")

	local report = Statsy:CreateReport()
    for g, group in ipairs(report) do
		if (#group.elements > 0) then
			self:AddLine(" ")	-- Пустая строка для отступа
            --TODO: Подумать как переделать
            local groupMsg = COLOR_BLUE .. "[" .. group.title .. "]:"
			self:AddLine(groupMsg)

            for e, element in ipairs(group.elements) do
                local elementMsg = element.title .. ": " .. COLOR_WHITE .. element.value
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
	StatsyInfo.text = string.format(COLOR_GREEN .. "W:%d " .. COLOR_RED .. "L:%d " .. COLOR_YELLOW .. "WR:%s", wins, losses, winRate)

	local rankName, rankNumber = Statsy:GetPlayerPVPRankInfo()
	local rankNumberStr = rankNumber >= 10 and rankNumber or ("0" .. rankNumber)
	StatsyInfo.icon = "Interface\\PvPRankBadges\\PvPRank" .. rankNumberStr

	-- TODO: Временно, для отлова ошибки с зеленой иконкой
	Statsy:PrintMessage(StatsyInfo.icon)
end