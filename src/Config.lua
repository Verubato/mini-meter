local addonName, addon = ...
---@type MiniFramework
local mini = addon.Framework

---@type Db
local db

---@class Db
local dbDefaults = {
	Version = 2,
	Point = "TOP",
	RelativeTo = "Minimap",
	RelativePoint = "BOTTOM",
	X = 0,
	Y = -25,

	UpdateInterval = 1,

	TextFormat = "FPS: %s MS: %s",
	FontPath = "Fonts\\FRIZQT__.TTF",
	FontSize = 18,
	FontFlags = "OUTLINE",

	LowFpsThreshold = 30,
	MediumFpsThreshold = 60,
	LowLatencyThreshold = 50,
	MediumLatencyThreshold = 200,

	ColorsEnabled = true,

	DefaultColor = {
		R = 255,
		G = 255,
		B = 255,
	},
	BadColor = {
		R = 231,
		G = 76,
		B = 60,
	},
	OkColor = {
		R = 241,
		G = 196,
		B = 15,
	},
	GoodColor = {
		R = 46,
		G = 204,
		B = 113,
	},
}

---@class ConfigModule
local M = {
	DbDefaults = dbDefaults,
}

addon.Config = M

local function GetAndUpgradeDb()
	local vars = mini:GetSavedVars(dbDefaults)

	-- I had some typos like color vs colour and some values like height/width that are no longer used
	-- so get rid of them
	if vars.Version == 2 then
		mini:CleanTable(vars, dbDefaults, true, false)
	end

	return vars
end

function M:Init()
	db = GetAndUpgradeDb()

	local verticalSpacing = mini.VerticalSpacing
	local panel = CreateFrame("Frame")
	panel.name = addonName

	local category = mini:AddCategory(panel)

	if not category then
		return
	end

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, -verticalSpacing)
	title:SetText(addonName)

	local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subtitle:SetText("Shows an fps and ping meter on your UI.")

	local enableColors = mini:Checkbox({
		Parent = panel,
		LabelText = "Enable Colors",
		GetValue = function()
			return db.ColorsEnabled
		end,
		SetValue = function(value)
			db.ColorsEnabled = value
			addon:Refresh()
		end,
	})

	enableColors:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -verticalSpacing)

	local sizeSlider = mini:Slider({
		Parent = panel,
		LabelText = "Size",
		Min = 12,
		Max = 50,
		Step = 1,
		GetValue = function()
			return tonumber(db.FontSize) or dbDefaults.FontSize
		end,
		SetValue = function(value)
			db.FontSize = mini:ClampInt(value, 12, 50, dbDefaults.FontSize)
			addon:Refresh()
		end,
	})

	sizeSlider.Slider:SetPoint("TOPLEFT", enableColors, "BOTTOMLEFT", 0, -verticalSpacing * 3)

	mini:RegisterSlashCommand(category, panel, {
		-- note /mm is used by MiniMarkers
		"/minimeter",
		"/mmeter",
	})
end
