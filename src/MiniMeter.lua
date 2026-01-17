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

local function GetPlayerDurabilityPercent()
	local curTotal, maxTotal = 0, 0

	for slot = 1, 19 do
		-- 4 = shirt (no durability)
		if slot ~= 4 then
			local cur, max = GetInventoryItemDurability(slot)
			if cur and max and max > 0 then
				curTotal = curTotal + cur
				maxTotal = maxTotal + max
			end
		end
	end

	if maxTotal == 0 then
		return nil -- nothing with durability equipped
	end

	return curTotal / maxTotal
end

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

	if fps <= db.LowFpsThreshold then
		return db.BadColor
	elseif fps <= db.MediumFpsThreshold then
		return db.OkColor
	end

	return db.GoodColor
end

function LatencyColour(fps)
	if not db.ColorsEnabled then
		return db.DefaultColor
	end

	if fps <= db.LowLatencyThreshold then
		return db.GoodColor
	elseif fps <= db.MediumLatencyThreshold then
		return db.OkColor
	end

	return db.BadColor
end

function DurabilityColour(durability)
	if not db.ColorsEnabled then
		return db.DefaultColor
	end

	if durability <= db.LowDurabilityThreshold then
		return db.BadColor
	elseif durability <= db.MediumDurabilityThreshold then
		return db.OkColor
	end

	return db.GoodColor
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
	local parts = {}

	if db.FpsEnabled then
		local fps = GetFramerate()
		local colour = FpsColour(fps)
		local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(fps))
		local part = string.format(db.FpsFormat, coloured)
		parts[#parts + 1] = part
	end

	if db.LatencyEnabled then
		local _, _, _, worldLatency = GetNetStats()
		local colour = LatencyColour(worldLatency)
		local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(worldLatency))
		local part = string.format(db.LatencyFormat, coloured)
		parts[#parts + 1] = part
	end

	if db.DurabilityEnabled then
		local durability = GetPlayerDurabilityPercent()

		if durability then
			local colour = DurabilityColour(durability)
			local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(durability * 100))

			local part = string.format(db.DurabilityFormat, coloured)
			parts[#parts + 1] = part
		end
	end

	local message = table.concat(parts, " ")
	text:SetText(message)

	ResizeDraggableToText()
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
