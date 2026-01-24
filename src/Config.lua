local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework

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

	UpdateInterval = 1,

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
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(string.format("%s - %s", addonName, version))

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetText("Shows a simple status meter on your UI.")

	local togglesDivider = mini:Divider({
		Parent = panel,
		Text = "Toggles",
	})

	togglesDivider:SetPoint("LEFT", panel)
	togglesDivider:SetPoint("RIGHT", panel, -horizontalSpacing, 0 )
	togglesDivider:SetPoint("TOP", subtitle, "BOTTOM", 0, -verticalSpacing)

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

	local sizeDivider = mini:Divider({
		Parent = panel,
		Text = "Size",
	})

	sizeDivider:SetPoint("LEFT", panel)
	sizeDivider:SetPoint("RIGHT", panel, -horizontalSpacing, 0)
	sizeDivider:SetPoint("TOP", enableDurability, "BOTTOM", 0, -verticalSpacing)

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
			db.Font.Size = mini:ClampInt(value, 4, 50, dbDefaults.Font.Size)
			addon:Refresh()
		end,
	})

	sizeSlider.Slider:SetPoint("TOPLEFT", sizeDivider, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	local textDivider = mini:Divider({
		Parent = panel,
		Text = "Text",
	})

	textDivider:SetPoint("LEFT", panel)
	textDivider:SetPoint("RIGHT", panel, -horizontalSpacing, 0)
	textDivider:SetPoint("TOP", sizeSlider.Slider, "BOTTOM", 0, -verticalSpacing)

	local anchor = mini:TextBlock({
		Parent = panel,
		Lines = {
			"Note: ",
			"  - $value gets replaced with the actual fps/latency/durability value.",
			"  - For example 'FPS: $value' becomes 'FPS: 123'",
		},
	})

	anchor:SetPoint("TOPLEFT", textDivider, "BOTTOMLEFT", 0, -verticalSpacing)

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
	resetBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
	resetBtn:SetText("Reset")
	resetBtn:SetScript("OnClick", function()
		db = mini:ResetSavedVars(dbDefaults)

		panel:MiniRefresh()
		addon:Refresh()
		mini:Notify("Settings reset to default.")
	end)

	mini:RegisterSlashCommand(category, panel, {
		-- note /mm is used by MiniMarkers
		"/minimeter",
		"/mmeter",
	})
end
