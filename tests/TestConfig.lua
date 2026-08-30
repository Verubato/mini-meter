local fw = require("TestFramework")
local harness = require("AddonHarness")
local WowMock = require("WowMock")

---A checkbox is drawn with its label as a child font string, so a test finds it the way a
---player does.
---@param text string
---@return table?
local function FindCheckbox(text)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.Text and frame.Text.GetText and frame.Text:GetText() == text then
			return frame
		end
	end
end

---The client draws nothing in the mock, so a test stands in for the tooltip and reads back
---what the hover asked it to show.
---@param frame table
---@return string? title, string? body
local function TooltipOn(frame)
	local title, body
	local realSetText, realAddLine = GameTooltip.SetText, GameTooltip.AddLine

	GameTooltip.SetText = function(_, text)
		title = text
	end

	GameTooltip.AddLine = function(_, text)
		body = text
	end

	local ok, err = pcall(frame:GetScript("OnEnter"), frame)

	GameTooltip.SetText, GameTooltip.AddLine = realSetText, realAddLine

	if not ok then
		error(err, 0)
	end

	return title, body
end

fw.describe("MiniMeter - config panel toggles", function()
	local context

	fw.before_each(function()
		context = harness.Run("MiniMeter")
	end)

	local toggles = {
		{ "Enable Colors", "Colors the readings by how good or bad they are." },
		{ "Enable FPS", "Shows your frames per second." },
		{ "Enable Latency", "Shows your world latency." },
		{ "Enable Durability", "Shows your gear durability." },
		{ "Locked", "Prevents the display from being dragged." },
		{ "Enable Micro Menu", "Shows a menu of game shortcuts when you hover over the display." },
		{ "Enable Text Outline", "Draws an outline around the text." },
	}

	for _, toggle in ipairs(toggles) do
		local label, tooltip = toggle[1], toggle[2]

		fw.it(label .. " has a tooltip", function()
			fw.not_nil(context, "load must succeed first")

			local checkbox = FindCheckbox(label)
			fw.not_nil(checkbox, "fixture: the " .. label .. " checkbox exists")

			local title, body = TooltipOn(checkbox)

			fw.eq(title, label, "the tooltip is titled with the label")
			fw.eq(body, tooltip, "the tooltip text")
		end)
	end
end)
