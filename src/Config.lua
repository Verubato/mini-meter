local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework

StaticPopupDialogs["MINIMETER_CONFIRM_RESET"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data)
		if data and data.OnYes then
			data.OnYes()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

---@type Db
local db

---@class Db
local dbDefaults = {
	Version = 5,
	Point = "TOP",
	RelativeTo = "Minimap",
	RelativePoint = "BOTTOM",
	X = 0,
	Y = -25,
	-- Which way the display expands as the text length changes: LEFT, CENTER, or RIGHT.
	Grow = "CENTER",

	UpdateInterval = 1,
	Locked = false,
	MicroMenuEnabled = true,

	Fps = {
		Enabled = true,
		Format = "FPS: $value",
		Thresholds = {
			Low = 30,
			Medium = 60,
		},
	},

	Latency = {
		Enabled = true,
		Format = "MS: $value",
		Thresholds = {
			Low = 50,
			Medium = 200,
		},
	},

	Durability = {
		Enabled = true,
		Format = "|A:repair:16:16|a: $value%",
		Thresholds = {
			Low = 0.4,
			Medium = 0.7,
		},
	},

	Font = {
		File = "Fonts\\FRIZQT__.TTF",
		Size = 18,
		Flags = "OUTLINE",
		EnableOutline = true,
	},

	Colors = {
		Enabled = true,
		Default = {
			R = 255,
			G = 255,
			B = 255,
		},
		Bad = {
			R = 231,
			G = 76,
			B = 60,
		},
		Ok = {
			R = 241,
			G = 196,
			B = 15,
		},
		Good = {
			R = 46,
			G = 204,
			B = 113,
		},
	},
}

---@class ConfigModule
local M = {
	DbDefaults = dbDefaults,
}

addon.Config = M

local function GetAndUpgradeDb()
	local vars = mini:GetSavedVars(dbDefaults)

	while vars.Version ~= dbDefaults.Version do
		if not vars.Version or vars.Version == 1 then
			vars = mini:GetSavedVars(dbDefaults)
			vars.Version = dbDefaults.Version
		end

		if vars.Version == 2 then
			-- I had some typos like color vs colour and some values like height/width that are no longer used
			-- so get rid of them
			mini:CleanTable(vars, dbDefaults, true, false)
			vars.Version = 3
		end

		if vars.Version == 3 then
			-- had a big restructure
			mini:CleanTable(vars, dbDefaults, true, false)

			-- changed from string.format %s to a more user safe gsub $value
			vars.Fps.Format = string.gsub(vars.Fps.Format, "%%s", "$value")
			vars.Latency.Format = string.gsub(vars.Latency.Format, "%%s", "$value")
			vars.Durability.Format = "|A:repair:16:16|a: $value%"
			vars.Version = 4
		end

		if vars.Version == 4 then
			-- accidentally copied the FPS format for latency
			vars.Latency.Format = string.gsub(vars.Latency.Format, "FPS", "MS")
			vars.Version = 5
		end
	end

	return vars
end

function M:Init()
	db = GetAndUpgradeDb()

	-- LibSharedMedia is always bundled, so query it directly for all available fonts.
	-- This includes the WoW built-ins plus everything in our bundled fonts folder.
	local LSM = LibStub("LibSharedMedia-3.0")

	local fontFiles = {}
	local fontNames = {}

	for _, name in ipairs(LSM:List("font")) do
		local file = LSM:Fetch("font", name)
		if file then
			fontFiles[#fontFiles + 1] = file
			fontNames[file] = name
		end
	end

	local verticalSpacing = mini.VerticalSpacing
	local horizontalSpacing = mini.HorizontalSpacing
	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)

	if not category then
		return
	end

	local columns = 4
	local columnWidth = mini:ColumnWidth(columns, 0, 0)
	local header = mini:PanelHeader({
		Parent = panel,
		Description = "Shows a simple status meter on your UI.",
		Gap = 8,
	})

	local togglesDivider = mini:Divider({
		Parent = panel,
		Text = "Toggles",
	})

	togglesDivider:SetPoint("LEFT", panel)
	togglesDivider:SetPoint("RIGHT", panel, -horizontalSpacing, 0)
	togglesDivider:SetPoint("TOP", header.Anchor, "BOTTOM", 0, -verticalSpacing)

	local enableColors = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable Colors",
		GetValue = function()
			return db.Colors.Enabled
		end,
		SetValue = function(value)
			db.Colors.Enabled = value
			addon:Refresh()
		end,
	})

	enableColors:SetPoint("TOPLEFT", togglesDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local enableFps = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable FPS",
		GetValue = function()
			return db.Fps.Enabled
		end,
		SetValue = function(value)
			db.Fps.Enabled = value
			addon:Refresh()
		end,
	})

	enableFps:SetPoint("TOP", enableColors, "TOP", 0, 0)
	enableFps:SetPoint("LEFT", panel, "LEFT", columnWidth, -verticalSpacing)

	local enableLatency = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable Latency",
		GetValue = function()
			return db.Latency.Enabled
		end,
		SetValue = function(value)
			db.Latency.Enabled = value
			addon:Refresh()
		end,
	})

	enableLatency:SetPoint("TOP", enableColors, "TOP", 0, 0)
	enableLatency:SetPoint("LEFT", panel, "LEFT", columnWidth * 2, -verticalSpacing)

	local enableDurability = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable Durability",
		GetValue = function()
			return db.Durability.Enabled
		end,
		SetValue = function(value)
			db.Durability.Enabled = value
			addon:Refresh()
		end,
	})

	enableDurability:SetPoint("TOP", enableColors, "TOP", 0, 0)
	enableDurability:SetPoint("LEFT", panel, "LEFT", columnWidth * 3, -verticalSpacing)

	local lockFrame = mini:Checkbox({
		Parent = panel,
		LabelText = "Locked",
		GetValue = function()
			return db.Locked
		end,
		SetValue = function(value)
			db.Locked = value
			addon:Refresh()
		end,
	})

	lockFrame:SetPoint("TOPLEFT", enableColors, "BOTTOMLEFT", 0, -verticalSpacing)

	local enableMicroMenu = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable Micro Menu",
		GetValue = function()
			return db.MicroMenuEnabled
		end,
		SetValue = function(value)
			db.MicroMenuEnabled = value
		end,
	})

	enableMicroMenu:SetPoint("TOP", lockFrame, "TOP", 0, 0)
	enableMicroMenu:SetPoint("LEFT", panel, "LEFT", columnWidth, 0)

	local enableOutline = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable Text Outline",
		GetValue = function()
			return db.Font.EnableOutline
		end,
		SetValue = function(value)
			db.Font.EnableOutline = value
			if value then
				db.Font.Flags = "OUTLINE"
			else
				db.Font.Flags = ""
			end
			addon:Refresh()
		end,
	})

	enableOutline:SetPoint("TOP", enableMicroMenu, "TOP", 0, 0)
	enableOutline:SetPoint("LEFT", panel, "LEFT", columnWidth * 2, 0)

	local sizeDivider = mini:Divider({
		Parent = panel,
		Text = "Size & Position",
	})

	sizeDivider:SetPoint("LEFT", panel)
	sizeDivider:SetPoint("RIGHT", panel, -horizontalSpacing, 0)
	sizeDivider:SetPoint("TOP", lockFrame, "BOTTOM", 0, -verticalSpacing)

	local sizeSlider = mini:Slider({
		Parent = panel,
		LabelText = "Size",
		Width = (columnWidth * columns) - horizontalSpacing,
		Min = 4,
		Max = 50,
		Step = 1,
		GetValue = function()
			return tonumber(db.Font.Size) or dbDefaults.Font.Size
		end,
		SetValue = function(value)
			local newSize = mini:ClampInt(value, 4, 50, dbDefaults.Font.Size)

			if db.Font.Size ~= newSize then
				db.Font.Size = newSize
				addon:Refresh()
			end
		end,
	})

	sizeSlider.Slider:SetPoint("TOPLEFT", sizeDivider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local growNames = {
		LEFT = "Left",
		CENTER = "Center",
		RIGHT = "Right",
	}

	local growLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	growLabel:SetText("Grow Direction")
	growLabel:SetJustifyH("LEFT")
	growLabel:SetPoint("TOPLEFT", sizeSlider.Slider, "BOTTOMLEFT", 0, -verticalSpacing)

	local growDropdown = mini:Dropdown({
		Parent = panel,
		Items = { "LEFT", "CENTER", "RIGHT" },
		TooltipTitle = "Grow Direction",
		Tooltip = "Which way the display expands as the text gets longer or shorter.",
		GetText = function(value)
			return growNames[value] or value
		end,
		GetValue = function()
			return db.Grow
		end,
		SetValue = function(value)
			if db.Grow == value then
				return
			end

			db.Grow = value
			addon:ApplyGrow()
		end,
	})

	growDropdown:SetWidth(160)
	growDropdown:SetPoint("TOPLEFT", growLabel, "BOTTOMLEFT", 0, -4)

	local textDivider = mini:Divider({
		Parent = panel,
		Text = "Text",
	})

	textDivider:SetPoint("LEFT", panel)
	textDivider:SetPoint("RIGHT", panel, -horizontalSpacing, 0)
	textDivider:SetPoint("TOP", growDropdown, "BOTTOM", 0, -verticalSpacing)

	local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fontLabel:SetText("Font Style")
	fontLabel:SetJustifyH("LEFT")
	fontLabel:SetPoint("TOPLEFT", textDivider, "BOTTOMLEFT", 0, -verticalSpacing)

	local fontDropdown = mini:Dropdown({
		Parent = panel,
		Items = fontFiles,
		GetText = function(value)
			return fontNames[value] or value
		end,
		GetValue = function()
			return db.Font.File
		end,
		SetValue = function(value)
			db.Font.File = value
			addon:Refresh()
		end,
	})

	fontDropdown:SetWidth(220)
	fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -4)

	local anchor = mini:TextBlock({
		Parent = panel,
		Lines = {
			"Note: ",
			"  - $value gets replaced with the actual fps/latency/durability value.",
			"  - For example 'FPS: $value' becomes 'FPS: 123'",
		},
	})

	anchor:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 0, -verticalSpacing)

	local editBoxWidth = 200
	local fpsEditBox = mini:EditBox({
		Parent = panel,
		LabelText = "FPS Text",
		Width = editBoxWidth,
		GetValue = function()
			return db.Fps.Format
		end,
		SetValue = function(value)
			db.Fps.Format = value
		end,
	})

	local labelWidth = 100
	fpsEditBox.Label:SetWidth(labelWidth)
	fpsEditBox.Label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -verticalSpacing * 2)
	fpsEditBox.EditBox:SetPoint("LEFT", fpsEditBox.Label, "RIGHT", horizontalSpacing, 0)

	local latencyEditBox = mini:EditBox({
		Parent = panel,
		LabelText = "Latency Text",
		Width = editBoxWidth,
		GetValue = function()
			return db.Latency.Format
		end,
		SetValue = function(value)
			db.Latency.Format = value
		end,
	})

	latencyEditBox.Label:SetWidth(labelWidth)
	latencyEditBox.Label:SetPoint("TOPLEFT", fpsEditBox.Label, "BOTTOMLEFT", 0, -verticalSpacing)
	latencyEditBox.EditBox:SetPoint("LEFT", latencyEditBox.Label, "RIGHT", horizontalSpacing, 0)

	local durabilityEditBox = mini:EditBox({
		Parent = panel,
		LabelText = "Durability Text",
		Width = editBoxWidth,
		GetValue = function()
			return db.Durability.Format
		end,
		SetValue = function(value)
			db.Durability.Format = value
		end,
	})

	durabilityEditBox.Label:SetWidth(labelWidth)
	durabilityEditBox.Label:SetPoint("TOPLEFT", latencyEditBox.Label, "BOTTOMLEFT", 0, -verticalSpacing)
	durabilityEditBox.EditBox:SetPoint("LEFT", durabilityEditBox.Label, "RIGHT", horizontalSpacing, 0)

	local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	resetBtn:SetSize(120, 26)
	resetBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -16)
	resetBtn:SetText("Reset")
	resetBtn:SetScript("OnClick", function()
		StaticPopup_Show("MINIMETER_CONFIRM_RESET", "Are you sure you want to reset to default settings?", nil, {
			OnYes = function()
				db = mini:ResetSavedVars(dbDefaults)

				panel:MiniRefresh()
				addon:Refresh()
				mini:NotifyWithPrefix("Settings reset to default.")
			end,
		})
	end)

	mini:RegisterSlashCommand(category, panel, {
		-- note /mm is used by MiniMarkers
		"/minimeter",
		"/mmeter",
	})
end
