local addonName, _ = ...
local draggable
local text
local db
local dbDefaults = {
	Point = "TOP",
	RelativeTo = "Minimap",
	RelativePoint = "BOTTOM",
	X = 0,
	Y = -25,

	UpdateInterval = 1,

	Height = 40,
	Width = 200,

	TextFormat = "FPS: %s MS: %s",
	FontPath = "Fonts\\FRIZQT__.TTF",
	FontSize = 18,
	FontFlags = "OUTLINE",

	LowFpsThreshold = 30,
	MediumFpsThreshold = 60,
	LowLatencyThreshold = 50,
	MediumLatencyThreshold = 200,

	BadColor = {
		R = 231,
		G = 76,
		B = 60,
	},
	OkColour = {
		R = 241,
		G = 196,
		B = 15,
	},
	GoodColour = {
		R = 46,
		G = 204,
		B = 113,
	},
}

local function CopyTable(src, dst)
	if type(dst) ~= "table" then
		dst = {}
	end

	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyTable(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end

	return dst
end

function FpsColour(fps)
	if fps <= (db.LowFpsThreshold or dbDefaults.LowFpsThreshold) then
		return db.BadColour or dbDefaults.BadColor
	elseif fps <= (db.MediumFpsThreshold or dbDefaults.MediumFpsThreshold) then
		return db.OkColor or dbDefaults.OkColour
	end

	return db.GoodColour or dbDefaults.GoodColour
end

function LatencyColour(fps)
	if fps <= (db.LowLatencyThreshold or dbDefaults.LowLatencyThreshold) then
		return db.GoodColour or dbDefaults.GoodColour
	elseif fps <= (db.MediumLatencyThreshold or dbDefaults.MediumLatencyThreshold) then
		return db.OkColour or dbDefaults.OkColour
	end

	return db.BadColour or dbDefaults.BadColor
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

local function Update()
	local fps = GetFramerate()
	local _, _, _, worldLatency = GetNetStats()
	local fpsColour = FpsColour(fps)
	local latencyColour = LatencyColour(worldLatency)
	local colouredFps = RgbNumber(fpsColour.R, fpsColour.G, fpsColour.B, math.floor(fps))
	local colouredLatency = RgbNumber(latencyColour.R, latencyColour.G, latencyColour.B, math.floor(worldLatency))
	local format = db.TextFormat or dbDefaults.TextFormat
	local message = string.format(format, colouredFps, colouredLatency)

	text:SetText(message)

	C_Timer.After(db.UpdateInterval or dbDefaults.UpdateInterval, Update)
end

local function OnEvent()
	ApplyPosition()
	Update()
end

local function Init()
	MiniMeterDB = MiniMeterDB or {}
	db = CopyTable(dbDefaults, MiniMeterDB)

	draggable = CreateFrame("Frame", nil, UIParent)
	draggable:SetSize(db.Width or dbDefaults.Width, db.Height or dbDefaults.Height)
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
	text:SetFont(
		db.FontPath or dbDefaults.FontPath,
		db.FontSize or dbDefaults.FontSize,
		db.FontFlags or dbDefaults.FontFlags
	)
	text:SetAllPoints(draggable)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		Init()

		loader:UnregisterEvent("ADDON_LOADED")

		-- might need to wait a bit later for frames to be created before applying our position
		loader:RegisterEvent("PLAYER_ENTERING_WORLD")
		loader:SetScript("OnEvent", OnEvent)
	end
end)
