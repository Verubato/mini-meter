-- The font preview machinery is exercised through the initializer the font dropdown's menu
-- generator captures, since the mock's modern-menu path never drives DecorateItem on its own.

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

---A stand-in for a pooled dropdown row: just the label field DecorateFontRow reads and
---writes, the way a real row carries its label as `.fontString`.
---@param stockFont table?
---@return table
local function NewRow(stockFont)
	local fontObject = stockFont
	local text = {}

	function text:GetFontObject()
		return fontObject
	end

	function text:SetFontObject(object)
		fontObject = object
	end

	return { fontString = text }
end

---A modern dropdown only exposes its per-row decorator through the initializer AddInitializer
---captures, so a test replays the generator against a description that records them by value.
---@param dd table
---@return table<any, fun(button:table)>
local function MenuInitializers(dd)
	local initializers = {}
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function(_, _, _, _, value)
		local radio = {}

		function radio:AddInitializer(fn)
			initializers[value] = fn
		end

		return radio
	end

	dd.__menuGenerator(dd, description)

	return initializers
end

---The font dropdown is the only one wired with DecorateItem, so the row it captures an
---initializer for a real font path picks it out among every dropdown on the panel.
---@param value string
---@return fun(button:table)?
local function FindFontRowInitializer(value)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.__menuGenerator then
			local initializer = MenuInitializers(frame)[value]

			if initializer then
				return initializer
			end
		end
	end
end

---The same search as FindFontRowInitializer, but handing back the dropdown frame itself so a
---test can replay its menu generator more than once.
---@return table?
local function FindFontDropdown()
	for _, frame in ipairs(WowMock.Frames) do
		if frame.__menuGenerator and MenuInitializers(frame)["Fonts\\ARIALN.TTF"] then
			return frame
		end
	end
end

---MenuInitializers keys rows by their value, so two rows sharing a file would collapse to one
---key even when the list underneath still carries both. A row count catches that duplication.
---@param dd table
---@return number
local function CountFontRows(dd)
	local count = 0
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function()
		count = count + 1

		return nil
	end

	dd.__menuGenerator(dd, description)

	return count
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

fw.describe("MiniMeter - font dropdown preview rows", function()
	local context

	fw.before_each(function()
		context = harness.Run("MiniMeter")
	end)

	fw.it("wires the preview decorator onto the font dropdown, wearing the font it names", function()
		fw.not_nil(context, "load must succeed first")

		local initializer = FindFontRowInitializer("Fonts\\ARIALN.TTF")
		fw.not_nil(initializer, "fixture: the font dropdown captured an initializer for a known font")

		local stock = {}
		local row = NewRow(stock)

		initializer(row)

		local object = row.fontString:GetFontObject()
		fw.not_nil(object, "the row picked up a font object")
		fw.neq(object, stock, "not the stock font it started with")
		fw.eq(object:GetFont(), "Fonts\\ARIALN.TTF", "wearing the face it names")

		-- Only CreateFontFamily records its member definition.
		fw.not_nil(object.__members, "built through CreateFontFamily, not CreateFont+SetFont")

		local alphabets = {}
		for i, member in ipairs(object.__members) do
			alphabets[i] = member.alphabet
		end

		fw.eq(table.concat(alphabets, ","), "roman,korean,simplifiedchinese,traditionalchinese,russian",
			"one member for every alphabet the client distinguishes")
	end)

	fw.it("keeps the row's original stock font through repeated decorates, not the first preview", function()
		fw.not_nil(context, "load must succeed first")

		local first = FindFontRowInitializer("Fonts\\ARIALN.TTF")
		local second = FindFontRowInitializer("Fonts\\FRIZQT__.TTF")
		fw.not_nil(first, "fixture: an initializer captured for the first font")
		fw.not_nil(second, "fixture: an initializer captured for a different font")

		local stock = {}
		local row = NewRow(stock)

		first(row)
		second(row)

		fw.eq(row.MiniMeterStockFont, stock, "the remembered stock font is still the original, not the first preview")
	end)
end)

fw.describe("MiniMeter - font media subscription", function()
	fw.before_each(function()
		harness.Run("MiniMeter")
	end)

	fw.it("picks up a font a media pack registers after the panel is built", function()
		local testFile = "Fonts\\MiniMeterTestFace.ttf"

		fw.is_nil(FindFontRowInitializer(testFile), "fixture: the unregistered face isn't offered yet")

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", "MiniMeter Test Face", testFile)
		fw.is_nil(FindFontRowInitializer(testFile), "the registration alone doesn't rebuild the list yet")

		WowMock.RunTimers()

		fw.not_nil(FindFontRowInitializer(testFile), "the font appears once the coalesced refresh runs")
	end)

	fw.it("coalesces two registrations in the same frame into a single refresh", function()
		local secondFile = "Fonts\\MiniMeterSecondTestFace.ttf"
		local thirdFile = "Fonts\\MiniMeterThirdTestFace.ttf"

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", "MiniMeter Second Test Face", secondFile)
		lsm:Register("font", "MiniMeter Third Test Face", thirdFile)

		fw.eq(WowMock.RunTimers(), 1, "two registrations in one frame coalesce into a single refresh")
		fw.not_nil(FindFontRowInitializer(secondFile), "the first of the pair lands after the one refresh")
		fw.not_nil(FindFontRowInitializer(thirdFile), "the second of the pair lands after the same refresh")
	end)

	fw.it("leaves the other faces listed once a global font override is set", function()
		local overrideTargetName = "MiniMeter Override Target Face"
		local overrideTargetFile = "Fonts\\MiniMeterOverrideTargetFace.ttf"
		local otherFile = "Fonts\\MiniMeterOtherTestFace.ttf"
		local overriddenFile = "Fonts\\MiniMeterOverriddenTestFace.ttf"

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", overrideTargetName, overrideTargetFile)
		lsm:Register("font", "MiniMeter Other Test Face", otherFile)
		WowMock.RunTimers()

		fw.not_nil(FindFontRowInitializer(otherFile), "fixture: the other face is listed before the override")

		-- Fetch would answer this one face for every name, leaving a single row naming a raw path.
		lsm:SetGlobal("font", overrideTargetName)
		lsm:Register("font", "MiniMeter Overridden Test Face", overriddenFile)

		WowMock.RunTimers()

		fw.not_nil(FindFontRowInitializer(otherFile), "a global font override leaves the other face listed")
		fw.not_nil(FindFontRowInitializer(overriddenFile), "the face registered under the override lands too")

		lsm:SetGlobal("font", nil)
	end)

	fw.it("adds a single row when two names resolve to the same file", function()
		local dd = FindFontDropdown()
		fw.not_nil(dd, "fixture: the font dropdown is found")

		local rowsBefore = CountFontRows(dd)
		local sharedFile = "Fonts\\MiniMeterSharedTestFace.ttf"

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", "MiniMeter Shared Name One", sharedFile)
		lsm:Register("font", "MiniMeter Shared Name Two", sharedFile)

		WowMock.RunTimers()

		fw.eq(CountFontRows(dd) - rowsBefore, 1, "two names resolving to one file add a single row")
	end)
end)
