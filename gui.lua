local GUI = {
    optionsFrame = nil
}

local AceGUI = LibStub("AceGUI-3.0")
LibStub("AceEvent-3.0"):Embed(GUI)

function GUI:OptionsFrameToggle()
    if (self.optionsFrame == nil) then
        self:OptionsFrameCreate()
    else
        AceGUI:Release(self.optionsFrame)
        self.optionsFrame = nil
    end
end

function GUI:OptionsFrameCreate()
    local f = AceGUI:Create("Frame")
    f:SetTitle("Statsy Options")
    f:SetStatusText("Statsy Options")
    f:SetCallback("OnClose",
        function(widget)
            self.optionsFrame = nil
            AceGUI:Release(widget)
        end)
    f:SetLayout("Flow")

    self.optionsFrame = f
end

function GUI:MESSAGE_HANDLER(arg1, handlerMethod, ...)
    print("GUI:" .. handlerMethod)
    self[handlerMethod](self, ...)
end

GUI:RegisterMessage("GUI", "MESSAGE_HANDLER")