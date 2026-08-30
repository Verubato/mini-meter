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

---A hand-anchored divider is a plain frame with a labelled child, so a test finds it the
---way a player sees it, by that label.
---@param text string
---@return table?
local function GetDivider(text)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.Label and frame.Label.GetText and frame.Label:GetText() == text then
			return frame
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

		local togglesDivider = GetDivider("TOGGLES")
		local _, _, relativePoint, x = togglesDivider:GetPoint(2)

		fw.eq(relativePoint, "RIGHT", "the divider ends at the panel's own right edge")
		fw.eq(x, 0, "flush with the panel's right edge, matching the header rule above it")
	end,
})
