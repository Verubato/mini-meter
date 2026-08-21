local _, addon = ...
local eventsFrame
---@type MiniFramework
local mini = addon.Framework
---@type ConfigModule
local config = addon.Config
local draggable
local text
local ticker
local lastWidth, lastHeight
local resizeQueued = false
-- The last string written to the fontstring, so an unchanged tick skips the write.
local lastMessage
-- Cached durability, and whether the client has said it moved.
local durabilityPercent
local durabilityStale = true
---@type Db
local db
-- The edge that holds still for each grow direction. The frame is resized to the text on every
-- update, so the edge its anchor point names is the only part that stays where it was.
local growEdges = {
	LEFT = "RIGHT",
	CENTER = "",
	RIGHT = "LEFT",
}

local libQTip = LibStub("LibQTip-1.0")
local tooltip
local cellProvider, cellPrototype = libQTip:CreateCellProvider()

function cellPrototype:InitializeCell()
	self.texture = self:CreateTexture()
	self.texture:SetAllPoints(self)
end

function cellPrototype:SetupCell(_, value, _, _, iconCoords, unitID)
	local tex = self.texture
	tex:SetWidth(18)
	tex:SetHeight(18)

	if unitID then
		SetPortraitTexture(tex, unitID)
		if iconCoords then
			---@diagnostic disable-next-line: deprecated
			tex:SetTexCoord(unpack(iconCoords))
		end
	else
		tex:SetTexture(value)
		-- Apply standard cropping to all icons to ensure consistent sizing
		tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end

	return tex:GetWidth(), tex:GetHeight()
end

function cellPrototype:ReleaseCell()
	-- required for prototype
end

local function UpdatePlaceholders(format, value)
	return string.gsub(format or "", "$value", value)
end

local function ReadPlayerDurabilityPercent()
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

---Durability moves when you take a hit, repair, or change gear, none of which happen on a
---clock, so the nineteen slot reads happen when the client says something moved.
local function GetPlayerDurabilityPercent()
	if durabilityStale then
		durabilityStale = false
		durabilityPercent = ReadPlayerDurabilityPercent()
	end

	return durabilityPercent
end

local function ResizeDraggableToText()
	-- Cleared before the early return below, otherwise a tick whose text changed without
	-- changing size leaves the queue latched shut and the frame never resizes again.
	resizeQueued = false

	local width = text:GetUnboundedStringWidth() or 0
	local height = text:GetStringHeight() or 0

	if width < 1 then
		width = 1
	end

	if height < 1 then
		height = 1
	end

	-- might help reduce flicker/noise
	if width == lastWidth and height == lastHeight then
		return
	end

	draggable:SetSize(width, height)

	lastWidth = width
	lastHeight = height
end

local function QueueResizeDraggable()
	if resizeQueued then
		return
	end

	resizeQueued = true

	-- wait for the font string to have updated it's rendered width/height before we compute it
	C_Timer.After(0, ResizeDraggableToText)
end

---Pins the text to the same edge the frame is anchored by, so a longer string runs away from
---that edge instead of spreading either side of the frame's centre. Without this the text sits
---wherever the frame's last measured size put it, which lags a tick behind the string.
local function AnchorText()
	local point = draggable:GetPoint(1) or "CENTER"

	text:ClearAllPoints()
	text:SetPoint(point, draggable, point, 0, 0)
end

local function FpsColour(fps)
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

local function LatencyColour(fps)
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

local function DurabilityColour(durability)
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

local function RgbNumber(r, g, b, value)
	return string.format("|cFF%02x%02x%02x%d|r", r, g, b, value)
end

local function UpdateFont()
	text:SetFont(db.Font.File, db.Font.Size, db.Font.Flags)

	-- The string is unchanged but its measured size is not, so let the next UpdateText through
	-- to re-measure the draggable.
	lastMessage = nil
end

local function UpdateText()
	local parts = {}

	if db.Fps.Enabled then
		local fps = GetFramerate()
		local colour = FpsColour(fps)
		local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(fps))
		local part = UpdatePlaceholders(db.Fps.Format, coloured)
		parts[#parts + 1] = part
	end

	if db.Latency.Enabled then
		local _, _, _, worldLatency = GetNetStats()
		local colour = LatencyColour(worldLatency)
		local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(worldLatency))
		local part = UpdatePlaceholders(db.Latency.Format, coloured)
		parts[#parts + 1] = part
	end

	if db.Durability.Enabled then
		local durability = GetPlayerDurabilityPercent()

		if durability then
			local colour = DurabilityColour(durability)
			local coloured = RgbNumber(colour.R, colour.G, colour.B, math.floor(durability * 100))

			local part = UpdatePlaceholders(db.Durability.Format, coloured)
			parts[#parts + 1] = part
		end
	end

	local message = table.concat(parts, " ")

	-- SetText re-lays out the fontstring and the resize below measures it, so an unchanged
	-- string has nothing left to do. UpdateFont clears this when the metrics move.
	if message == lastMessage then
		return
	end

	lastMessage = message
	text:SetText(message)

	QueueResizeDraggable()
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

local function OnEvent(_, event)
	-- Equipping a fresh item moves the total without any item's durability changing, so both
	-- events matter. They arrive in bursts, and the ticker is soon enough for a durability
	-- readout, so this only marks the value stale.
	if event == "UPDATE_INVENTORY_DURABILITY" or event == "PLAYER_EQUIPMENT_CHANGED" then
		durabilityStale = true
		return
	end

	mini:ApplyPosition(draggable, db, config.DbDefaults)
	AnchorText()
	UpdateText()
end

local function MouseHandler(event, func, button, ...)
	func(event, func, button, ...)
	libQTip:Release(tooltip)
	tooltip = nil
end

local function ShowMicroMenu()
	if InCombatLockdown() then
		return
	end

	if tooltip then
		libQTip:Release(tooltip)
	end

	tooltip = libQTip:Acquire("MiniMeterTooltip", 2, "LEFT", "LEFT")
	tooltip:Clear()

	-- Character Info with portrait
	local y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "", cellProvider, { 0.2, 0.8, 0.2, 0.8 }, "player")
	tooltip:SetCell(y, 2, "Character Info")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		ToggleCharacter("PaperDollFrame")
	end)

	-- Professions
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\Trade_BlackSmithing", cellProvider)
	tooltip:SetCell(y, 2, "Professions")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		if not InCombatLockdown() then
			ToggleProfessionsBook()
		end
	end)

	-- Talents & Spellbook
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\Ability_Marksmanship", cellProvider)
	tooltip:SetCell(y, 2, "Talents & Spellbook")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		if not InCombatLockdown() then
			if ToggleTalentFrame then
				ToggleTalentFrame()
			elseif TogglePlayerSpellsFrame then
				TogglePlayerSpellsFrame()
			end
		end
	end)

	-- Achievements
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\Achievement_Quests_Completed_07", cellProvider)
	tooltip:SetCell(y, 2, "Achievements")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		ToggleAchievementFrame()
	end)

	-- Quest Log
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\GossipFrame\\ActiveQuestIcon", cellProvider)
	tooltip:SetCell(y, 2, "Quest Log")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		ToggleQuestLog()
	end)

	-- Housing Dashboard
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\Misc_RNRPaintButtonUp", cellProvider)
	tooltip:SetCell(y, 2, "Housing Dashboard")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		if HousingMicroButton then
			HousingMicroButton:Click()
		end
	end)

	-- Guild & Communities
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\INV_Shirt_GuildTabard_01", cellProvider)
	tooltip:SetCell(y, 2, "Guild & Communities")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		ToggleGuildFrame()
	end)

	-- Group Finder
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\INV_Misc_Eye_02", cellProvider)
	tooltip:SetCell(y, 2, "Group Finder")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		PVEFrame_ToggleFrame()
	end)

	-- Warband Collections
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\MountJournalPortrait", cellProvider)
	tooltip:SetCell(y, 2, "Warband Collections")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		ToggleCollectionsJournal()
	end)

	-- Adventure Guide
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\INV_Misc_Book_07", cellProvider)
	tooltip:SetCell(y, 2, "Adventure Guide")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		ToggleEncounterJournal()
	end)

	-- Game Menu
	y = tooltip:AddLine()
	tooltip:SetCell(y, 1, "Interface\\ICONS\\INV_Gizmo_02", cellProvider)
	tooltip:SetCell(y, 2, "Game Menu")
	tooltip:SetLineScript(y, "OnMouseUp", MouseHandler, function()
		if not InCombatLockdown() then
			if GameMenuFrame and GameMenuFrame:IsShown() then
				HideUIPanel(GameMenuFrame)
			else
				ShowUIPanel(GameMenuFrame)
			end
		end
	end)

	tooltip:SetAutoHideDelay(0.1, draggable)
	tooltip:SmartAnchorTo(draggable)
	tooltip:Show()
end

local function ApplyLockState()
	draggable:SetMovable(not db.Locked)

	-- Only movability is locked, never mouse input - the micro menu is a hover handler on the
	-- same frame and has to keep working while the bar is locked in place.
	draggable:EnableMouse(true)
end

local function IsLocked()
	return db.Locked and true or false
end

---The saved anchor point with its horizontal half replaced by the one the grow direction wants.
local function GrowPoint(point)
	local vertical = point:match("^TOP") or point:match("^BOTTOM") or ""
	local wanted = vertical .. (growEdges[db.Grow] or "")

	return wanted ~= "" and wanted or "CENTER"
end

---Distance from the frame's left edge to the given anchor point.
local function PointOffset(point, width)
	if point:find("LEFT") then
		return 0
	end

	if point:find("RIGHT") then
		return width
	end

	return width / 2
end

---Re-anchors the frame to the edge the grow direction keeps still, leaving it exactly where it
---sits on screen. Only runs when the user drags or picks a direction: the new offset is worked
---out from the width at that moment, so doing it on every update would drift the frame rather
---than hold it.
local function ApplyGrowAnchor()
	local point, relativeTo, relativePoint, x, y = draggable:GetPoint(1)

	if not point then
		return
	end

	local wanted = GrowPoint(point)

	if wanted == point then
		return
	end

	local width = draggable:GetWidth() or 0
	local shift = PointOffset(wanted, width) - PointOffset(point, width)

	draggable:ClearAllPoints()
	draggable:SetPoint(wanted, relativeTo or UIParent, relativePoint or point, x + shift, y)
	mini:SavePosition(draggable, db)
	AnchorText()
end

local function Init()
	config:Init()

	db = mini:GetSavedVars()

	-- might need to wait a bit later for frames to be created before applying our position
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
	eventsFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	eventsFrame:SetScript("OnEvent", OnEvent)

	draggable = CreateFrame("Frame", nil, UIParent)
	draggable:Show()

	mini:MakeMovable(draggable, db, { IsLocked = IsLocked, OnMoved = ApplyGrowAnchor })

	-- Add hover scripts for micro menu (using LibQTip)
	-- LibQTip handles auto-hide, so don't need OnLeave
	draggable:SetScript("OnEnter", function()
		if db.MicroMenuEnabled then
			ShowMicroMenu()
		end
	end)

	text = UIParent:CreateFontString(nil, "ARTWORK", "GameFontWhiteLarge")
	text:SetWordWrap(false)
	text:SetNonSpaceWrap(false)

	AnchorText()

	UpdateFont()
	UpdateText()
	QueueResizeDraggable()
	StartTicker()
	ApplyLockState()
end

local function OnAddonLoaded()
	Init()
end

function addon:Refresh()
	UpdateFont()
	UpdateText()
	ApplyLockState()
end

---Called when the grow direction changes, to move the anchor onto the new edge.
function addon:ApplyGrow()
	ApplyGrowAnchor()
end

mini:WaitForAddonLoad(OnAddonLoaded)
