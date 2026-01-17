local _, addon = ...
local eventsFrame
---@type MiniFramework
local mini = addon.Framework
---@type ConfigModule
local config = addon.Config
local draggable
local text
local ticker
---@type Db
local db
---@type Db
local dbDefaults = config.DbDefaults

local function ResizeDraggableToText()
	local padding = 10
	local width = text:GetStringWidth() or 0
	local height = text:GetStringHeight() or 0

	if width < 1 then
		width = 1
	end

	if height < 1 then
		height = 1
	end

	draggable:SetSize(width + 2 * padding, height + 2 * padding)
end

function FpsColour(fps)
	if not db.ColorsEnabled then
		return db.DefaultColor
	end

	if fps <= (db.LowFpsThreshold or dbDefaults.LowFpsThreshold) then
		return db.BadColor or dbDefaults.BadColor
	elseif fps <= (db.MediumFpsThreshold or dbDefaults.MediumFpsThreshold) then
		return db.OkColor or dbDefaults.OkColor
	end

	return db.GoodColor or dbDefaults.GoodColor
end

function LatencyColour(fps)
	if not db.ColorsEnabled then
		return db.DefaultColor
	end

	if fps <= (db.LowLatencyThreshold or dbDefaults.LowLatencyThreshold) then
		return db.GoodColor or dbDefaults.GoodColor
	elseif fps <= (db.MediumLatencyThreshold or dbDefaults.MediumLatencyThreshold) then
		return db.OkColor or dbDefaults.OkColor
	end

	return db.BadColor or dbDefaults.BadColor
end

function RgbNumber(r, g, b, value)
	return string.format("|cFF%02x%02x%02x%d|r", r, g, b, value)
end

local function ApplyPosition()
	local point = db.Point or dbDefaults.Point
	local relativePoint = db.RelativePoint or dbDefaults.RelativePoint
	local relativeTo = (db.RelativeTo and _G[db.RelativeTo]) or UIParent
	local x = (type(db.X) == "number") and db.X or dbDefaults.X
	local y = (type(db.Y) == "number") and db.Y or dbDefaults.Y

	draggable:ClearAllPoints()
	draggable:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function SavePosition()
	local point, relativeTo, relativePoint, x, y = draggable:GetPoint(1)

	db.Point = point
	-- ensure a non-nil value so it doesn't get overriden by defaults
	db.RelativeTo = relativeTo or "UIParent"
	db.RelativePoint = relativePoint
	db.X = x
	db.Y = y
end

local function UpdateFont()
	text:SetFont(
		db.FontPath or dbDefaults.FontPath,
		db.FontSize or dbDefaults.FontSize,
		db.FontFlags or dbDefaults.FontFlags
	)
end

local function UpdateText()
	local fps = GetFramerate()
	local _, _, _, worldLatency = GetNetStats()
	local fpsColour = FpsColour(fps)
	local latencyColour = LatencyColour(worldLatency)
	local colouredFps = RgbNumber(fpsColour.R, fpsColour.G, fpsColour.B, math.floor(fps))
	local colouredLatency = RgbNumber(latencyColour.R, latencyColour.G, latencyColour.B, math.floor(worldLatency))
	local format = db.TextFormat or dbDefaults.TextFormat
	local message = string.format(format, colouredFps, colouredLatency)

	ResizeDraggableToText()

	text:SetText(message)
end

local function OnTick()
	UpdateText()
end

local function StartTicker()
	if ticker then
		return
	end

	ticker = C_Timer.NewTicker(db.UpdateInterval or dbDefaults.UpdateInterval, OnTick)
end

local function OnEvent()
	ApplyPosition()
	UpdateText()
end

local function Init()
	config:Init()

	db = mini:GetSavedVars()

	-- might need to wait a bit later for frames to be created before applying our position
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:SetScript("OnEvent", OnEvent)

	draggable = CreateFrame("Frame", nil, UIParent)
	draggable:SetClampedToScreen(true)
	draggable:EnableMouse(true)
	draggable:SetMovable(true)
	draggable:RegisterForDrag("LeftButton")
	draggable:Show()

	draggable:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)

	draggable:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)

	text = UIParent:CreateFontString(nil, "ARTWORK", "GameFontWhiteLarge")
	text:SetAllPoints(draggable)

	UpdateFont()
	UpdateText()
	ResizeDraggableToText()
	StartTicker()
end

local function OnAddonLoaded()
	Init()
end

function addon:Refresh()
	UpdateFont()
	UpdateText()
end

mini:WaitForAddonLoad(OnAddonLoaded)
