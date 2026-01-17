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
	if not db.Colors.Enabled then
		return db.Colors.Default
	end

	if fps <= db.Fps.Thresholds.Low then
		return db.Colors.Bad
	elseif fps <= db.Fps.Thresholds.Medium then
		return db.Colors.Ok
	end

	return db.Colors.Good
end

function LatencyColour(fps)
	if not db.Colors.Enabled then
		return db.Colors.Default
	end

	if fps <= db.Latency.Thresholds.Low then
		return db.Colors.Good
	elseif fps <= db.Latency.Thresholds.Medium then
		return db.Colors.Ok
	end

	return db.Colors.Bad
end

function DurabilityColour(durability)
	if not db.Colors.Enabled then
		return db.Colors.Default
	end

	if durability <= db.Durability.Thresholds.Low then
		return db.Colors.Bad
	elseif durability <= db.Durability.Thresholds.Medium then
		return db.Colors.Ok
	end

	return db.Colors.Good
end

function RgbNumber(r, g, b, value)
	return string.format("|cFF%02x%02x%02x%d|r", r, g, b, value)
end

local function ApplyPosition()
	local point = db.Point
	local relativePoint = db.RelativePoint
	local relativeTo = (db.RelativeTo and _G[db.RelativeTo]) or UIParent
	local x = db.X
	local y = db.Y

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
	text:SetFont(db.Font.File, db.Font.Size, db.Font.Flags)
end

local function UpdateText()
	local parts = {}

	if db.Fps.Enabled then
		local fps = GetFramerate()
		local colour = FpsColour(fps)
		local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(fps))
		local part = string.format(db.Fps.Format, coloured)
		parts[#parts + 1] = part
	end

	if db.Latency.Enabled then
		local _, _, _, worldLatency = GetNetStats()
		local colour = LatencyColour(worldLatency)
		local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(worldLatency))
		local part = string.format(db.Latency.Format, coloured)
		parts[#parts + 1] = part
	end

	if db.Durability.Enabled then
		local durability = GetPlayerDurabilityPercent()

		if durability then
			local colour = DurabilityColour(durability)
			local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(durability * 100))

			local part = string.format(db.Durability.Format, coloured)
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

	ticker = C_Timer.NewTicker(db.UpdateInterval, OnTick)
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
