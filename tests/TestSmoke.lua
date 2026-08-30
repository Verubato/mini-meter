-- Loads the whole addon into a mocked client and drives it through login.
-- The shared body lives in build/Lua/SmokeTest.lua.

local fw = require("TestFramework")
local smoke = require("SmokeTest")
local WowMock = require("WowMock")

---A dropdown caption sits directly on the panel, so a test finds it by the text it shows.
---@param text string
---@return table?
local function GetPanelCaption(text)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.name == "MiniMeter" then
			for _, region in ipairs(frame.__regions or {}) do
				if region.GetText and region:GetText() == text then
					return region
				end
			end
		end
	end
end

smoke.Run("MiniMeter", {
	extra = function(context)
		fw.eq(context.Addon.Framework.CustomStyling, true, "custom styling on")
		fw.eq(context.Addon.Framework.CustomStylingOverrides.Button, false, "stock buttons")

		local growCaption = GetPanelCaption("Grow Direction")
		local fontCaption = GetPanelCaption("Font Style")

		fw.eq(growCaption and growCaption.__template, "GameFontHighlight", "grow direction caption is white, not Blizzard gold")
		fw.eq(fontCaption and fontCaption.__template, "GameFontHighlight", "font style caption is white, not Blizzard gold")
	end,
})
