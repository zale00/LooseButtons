local Logic = LooseButtonsLogic
local LB = Logic.LB

local function NewFace(parent, name, template)
	local button = CreateFrame("Button", name, parent, template)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetPoint("CENTER")
	button.border:SetSize(46, 45)
	button:SetMovable(true)
	button:RegisterForDrag("LeftButton")
	button:SetClampedToScreen(true)
	LB.AttachHotkey(button)
	LB.EnsureQuickKeybind(button, name)
	return button
end

local function HideSlot(button, kind)
	if not button or InCombatLockdown() then
		return
	end
	if type(ClearOverrideBindings) == "function" then
		ClearOverrideBindings(button)
	end
	if kind ~= "launcher" then
		button:SetAttribute("type", "")
		button:SetAttribute("spell", "")
		button:SetAttribute("item", "")
		button:SetAttribute("macro", "")
		button:SetAttribute("action", nil)
		button.lbOutOfRange = nil
	end
	button:Hide()
end

function LB.EnsurePanelProxy(click)
	local name = Logic.PANEL_PROXY[click]
	if not name then
		return nil
	end
	local proxy = _G[name]
	if not proxy and not InCombatLockdown() then
		proxy = CreateFrame("Button", name, UIParent, "SecureHandlerClickTemplate")
		proxy:SetAttribute("_onclick", Logic.PanelToggleSnippet)
		proxy:Hide()
	end
	if not proxy or InCombatLockdown() or not proxy.SetFrameRef then
		return proxy
	end
	local panel
	if click == "gamemenu" then
		panel = GameMenuFrame
	else
		panel = LB.BookFrame()
	end
	if not panel then
		return proxy
	end
	proxy:SetFrameRef("panel", panel)
	if click == "gamemenu" then
		return proxy
	end
	local function isFrame(value)
		local kind = type(value)
		return kind == "table" or kind == "userdata"
	end
	if isFrame(panel.SpellBookFrame) then
		proxy:SetFrameRef("book", panel.SpellBookFrame)
	end
	if isFrame(panel.TalentsFrame) then
		proxy:SetFrameRef("talents", panel.TalentsFrame)
	end
	if isFrame(panel.SpecFrame) then
		proxy:SetFrameRef("spec", panel.SpecFrame)
	end
	local page = panel.SpellBookFrame
	if click == "talents" then
		page = panel.TalentsFrame
		if not isFrame(page) then
			page = panel.SpecFrame
		end
	end
	if isFrame(page) then
		proxy:SetFrameRef("page", page)
	end
	proxy:SetAttribute("escape", true)
	if not proxy.lbHideWrapped and proxy.WrapScript then
		proxy:WrapScript(panel, "OnHide", Logic.PanelHidePre, Logic.PanelHideSnippet)
		proxy.lbHideWrapped = true
	elseif not proxy.lbHideWrapped and SecureHandlerWrapScript then
		SecureHandlerWrapScript(panel, "OnHide", proxy, Logic.PanelHidePre, Logic.PanelHideSnippet)
		proxy.lbHideWrapped = true
	end
	return proxy
end

function LB.WireLauncher(button, record)
	if not button or not button.SetAttribute or InCombatLockdown() then
		return
	end
	if LB.KeybindOpen() then
		button:SetAttribute("type1", nil)
		button:SetAttribute("clickbutton1", nil)
		return
	end
	local spec = Logic.LauncherByCommand(record.payload)
	local click = spec and spec.click
	local microName = click and Logic.MICRO_CLICK[click]
	local micro = microName and _G[microName]
	if micro then
		button:SetAttribute("type1", "click")
		button:SetAttribute("clickbutton1", micro)
		return
	end
	local proxy = click and LB.EnsurePanelProxy(click)
	if proxy then
		button:SetAttribute("type1", "click")
		button:SetAttribute("clickbutton1", proxy)
		return
	end
	button:SetAttribute("type1", nil)
	button:SetAttribute("clickbutton1", nil)
end

local function Configure(button, record)
	if not button or InCombatLockdown() then
		return
	end
	button.lbKind = record.kind
	button.lbSlot = record.slot
	button:ClearAllPoints()
	button:SetPoint(record.point, UIParent, record.relPoint, record.x, record.y)
	if record.kind == "launcher" then
		local paint = Logic.LauncherPaint(record)
		record.chrome = paint.chrome
		record.atlas = paint.atlas
		record.portrait = paint.portrait and true or nil
		button:SetSize(Logic.ButtonExtent(record, LB.ScaleOf(record)))
		LB.PaintFace(button, paint, nil, LB.ThemeOf(record))
		LB.WireLauncher(button, record)
	else
		button:SetSize(Logic.ButtonExtent(record, LB.ScaleOf(record)))
		if record.kind == "spell" or (record.kind == "pet" and record.petCast == "spell") then
			button:SetAttribute("type", "spell")
			button:SetAttribute("spell", tostring(record.payload))
			button:SetAttribute("item", "")
			button:SetAttribute("macro", "")
			button:SetAttribute("action", nil)
		elseif record.kind == "item" then
			local item = Logic.ItemUseAttribute(record.payload)
			button:SetAttribute("type", "item")
			button:SetAttribute("item", item or "")
			button:SetAttribute("spell", "")
			button:SetAttribute("macro", "")
			button:SetAttribute("action", nil)
		elseif record.kind == "pet" then
			button:SetAttribute("type", "pet")
			button:SetAttribute("action", LB.PetActionBarSlot(record.payload))
			button:SetAttribute("spell", "")
			button:SetAttribute("item", "")
			button:SetAttribute("macro", "")
		else
			button:SetAttribute("type", "macro")
			button:SetAttribute("macro", tostring(record.payload))
			button:SetAttribute("spell", "")
			button:SetAttribute("item", "")
			button:SetAttribute("action", nil)
		end
		button:SetAttribute("*type2", "")
		local holds = Logic.CastHoldPrefixes()
		local hold
		for hold = 1, #holds do
			button:SetAttribute(holds[hold] .. "type1", "")
		end
		if LB.KeybindOpen() then
			button:SetAttribute("type", "")
		end
		local texture = Logic.PlacedTexture(record, LB.IconFor)
		if texture then
			record.icon = texture
		end
		if record.kind == "spell" and record.class == nil and LB.SpellInBook(record.payload) then
			record.class = LB.PlayerClass()
		end
		LB.PaintFace(button, { chrome = "action" }, texture, LB.CurrentTheme())
	end
	button:Show()
	LB.ApplyKey(button, record)
	LB.RefreshHotkey(button, record)
	LB.SetActionClicks(button)
end

local function ApplyAll()
	if not LB.poolReady or InCombatLockdown() then
		return
	end
	local usedAction = {}
	local usedLauncher = {}
	local buttons = LB.DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		local button = LB.ButtonFor(record)
		if button then
			Configure(button, record)
			if Logic.Pool(record.kind) == "launcher" then
				usedLauncher[record.slot] = true
			else
				usedAction[record.slot] = true
			end
		end
	end
	for i = 1, Logic.ACTION_SLOTS do
		if not usedAction[i] then
			HideSlot(LB.actions[i], "spell")
		end
	end
	for i = 1, Logic.LAUNCHER_SLOTS do
		if not usedLauncher[i] then
			HideSlot(LB.launchers[i], "launcher")
		end
	end
	LB.hiddenIds = LB.HiddenIds()
	if LB.SyncSpellRanges then
		LB.SyncSpellRanges()
	end
end
LB.ApplyAll = ApplyAll

local function RefreshPortraits()
	if type(SetPortraitTexture) ~= "function" then
		return
	end
	if LB.poolReady then
		local buttons = LB.DB().buttons
		local i
		for i = 1, #buttons do
			local record = buttons[i]
			if record.kind == "launcher" and Logic.LauncherPaint(record).portrait then
				local button = LB.ButtonFor(record)
				if button and button.icon and button:IsShown() then
					LB.PaintPortrait(button.icon)
				end
			end
		end
	end
	local rows = LB.catalogButtons
	local i
	for i = 1, #rows do
		local row = rows[i]
		if row:IsShown() and row.entry and row.entry.portrait and row.icon then
			LB.PaintPortrait(row.icon)
		end
	end
end

local function RefreshHotkeys()
	if not LB.poolReady then
		return
	end
	local buttons = LB.DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		LB.RefreshHotkey(LB.ButtonFor(record), record)
	end
end

local function RemoveRecord(kind, poolSlot)
	if InCombatLockdown() then
		LB.Say("Cannot remove a button in combat.")
		return
	end
	local record, index = LB.Find(kind, poolSlot)
	if not index then
		return
	end
	if record then
		Logic.Detach(LB.DB().buttons, record.id)
	end
	table.remove(LB.DB().buttons, index)
	local button = Logic.Pool(kind) == "launcher" and LB.launchers[poolSlot] or LB.actions[poolSlot]
	HideSlot(button, kind)
	if LB.SyncSpellRanges then
		LB.SyncSpellRanges()
	end
end

local ACTION_BUTTON_PREFIXES = {
	"ActionButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
	"MultiBarRightButton",
	"MultiBarLeftButton",
	"MultiBar5Button",
	"MultiBar6Button",
	"MultiBar7Button",
}

local function ActionButtonUnderCursor()
	if type(GetMouseFoci) ~= "function" then
		return nil
	end
	local foci = GetMouseFoci()
	if type(foci) ~= "table" then
		return nil
	end
	local focusIndex
	for focusIndex = 1, #foci do
		local frame = foci[focusIndex]
		local depth = 0
		while frame and depth < 6 do
			local name = type(frame) == "table" and type(frame.GetName) == "function" and frame:GetName()
			if type(name) == "string" then
				local prefixIndex
				for prefixIndex = 1, #ACTION_BUTTON_PREFIXES do
					local prefix = ACTION_BUTTON_PREFIXES[prefixIndex]
					if string.sub(name, 1, #prefix) == prefix then
						local rest = string.sub(name, #prefix + 1)
						local index = tonumber(rest)
						if index and index >= 1 and index <= 12 and tostring(index) == rest then
							return frame
						end
					end
				end
			end
			if type(frame) ~= "table" or type(frame.GetParent) ~= "function" then
				break
			end
			frame = frame:GetParent()
			depth = depth + 1
		end
	end
	return nil
end

local function PlaceIntoAction(button, kind, payload, petCast, bookSlot)
	if InCombatLockdown() or type(PlaceAction) ~= "function" or not button then
		return false
	end
	local slot = button.action
	if type(slot) ~= "number" then
		return false
	end
	if (kind == "spell" or (kind == "pet" and petCast == "spell")) and C_Spell and C_Spell.PickupSpell then
		C_Spell.PickupSpell(payload)
	elseif kind == "item" and C_Item and C_Item.PickupItem then
		C_Item.PickupItem(payload)
	elseif kind == "macro" and type(PickupMacro) == "function" then
		PickupMacro(payload)
	elseif kind == "pet" and petCast == "action" and type(bookSlot) == "number" and C_SpellBook and C_SpellBook.PickupSpellBookItem and Enum and Enum.SpellBookSpellBank then
		C_SpellBook.PickupSpellBookItem(bookSlot, Enum.SpellBookSpellBank.Pet)
	elseif kind == "pet" and petCast == "action" and type(PickupPetAction) == "function" then
		local barSlot = LB.PetActionBarSlot(payload)
		if not barSlot then
			return false
		end
		PickupPetAction(barSlot)
	else
		return false
	end
	PlaceAction(slot)
	if ClearCursor then
		ClearCursor()
	end
	return true
end

local function ModifierDown(name)
	local fn = _G[name]
	if type(fn) ~= "function" then
		return false
	end
	local value = fn()
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return false
	end
	if value then
		return true
	end
	return false
end

local function PlaceButton(button, record)
	button:ClearAllPoints()
	button:SetPoint(record.point or "CENTER", UIParent, record.relPoint or "CENTER", record.x, record.y)
end

local function ApplyScale(scale)
	local live = LB.DB()
	live.scale = Logic.NormalizeScale(scale)
	scale = live.scale
	if LB.scaleSlider and LB.scaleSlider.SetValue and not LB.scaleWriting then
		LB.scaleWriting = true
		LB.scaleSlider:SetValue(Logic.ScalePercent(scale))
		LB.scaleWriting = nil
	end
	if InCombatLockdown() then
		LB.pendingScale = true
		return
	end
	LB.pendingScale = nil
	local list = LB.DB().buttons
	Logic.Reflow(list, function(record)
		return Logic.ButtonExtent(record, LB.ScaleOf(record))
	end)
	local i
	for i = 1, #list do
		local record = list[i]
		local button = LB.ButtonFor(record)
		if button then
			button:SetSize(Logic.ButtonExtent(record, LB.ScaleOf(record)))
			PlaceButton(button, record)
		end
	end
	LB.RepaintPlaced()
end

local function ApplyLauncherScale(scale)
	scale = Logic.NormalizeScale(scale)
	LB.DB().launcherScale = scale
	local slider = LB.launcherSlider
	if slider and slider.SetValue and not LB.launcherScaleWriting then
		LB.launcherScaleWriting = true
		slider:SetValue(Logic.ScalePercent(scale))
		LB.launcherScaleWriting = nil
	end
	ApplyScale(LB.DB().scale)
end

local function PlainCoord(value)
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return nil
	end
	if type(value) ~= "number" then
		return nil
	end
	return value
end


local function CursorPixels()
	if type(GetCursorPosition) ~= "function" then
		return nil
	end
	local x, y = GetCursorPosition()
	return PlainCoord(x), PlainCoord(y)
end

local function CursorCenter()
	if type(GetCursorPosition) ~= "function" or not UIParent or not UIParent.GetCenter then
		return nil
	end
	local x, y = GetCursorPosition()
	x = PlainCoord(x)
	y = PlainCoord(y)
	if not x or not y then
		return nil
	end
	local scale = 1
	if UIParent.GetEffectiveScale then
		local s = PlainCoord(UIParent:GetEffectiveScale())
		if s and s ~= 0 then
			scale = s
		end
	end
	local cx, cy = UIParent:GetCenter()
	cx = PlainCoord(cx)
	cy = PlainCoord(cy)
	if not cx or not cy then
		return nil
	end
	return x / scale - cx, y / scale - cy
end

local function SnapLine(index)
	local line = LB.snapLines[index]
	if not line then
		line = CreateFrame("Frame", "LooseButtonsSnapLine" .. index, UIParent)
		line:SetFrameStrata("TOOLTIP")
		line:EnableMouse(false)
		local tex = line:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		tex:SetColorTexture(0.1, 0.95, 0.35, 1)
		line:Hide()
		LB.snapLines[index] = line
	end
	return line
end

local function PlaceSnapLine(line, box, side)
	local cx, cy = UIParent:GetCenter()
	cx = PlainCoord(cx)
	cy = PlainCoord(cy)
	if not cx or not cy or type(box) ~= "table" or type(box.left) ~= "number" then
		line:Hide()
		return
	end
	local left = cx + box.left
	local right = cx + box.right
	local bottom = cy + box.bottom
	local top = cy + box.top
	line:ClearAllPoints()
	if side == "north" or side == "south" then
		line:SetSize(math.max(right - left, 8), 5)
		local y = side == "north" and top or (bottom - 5)
		line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, y)
	else
		line:SetSize(5, math.max(top - bottom, 8))
		local x = side == "east" and right or (left - 5)
		line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, bottom)
	end
	line:Show()
end

local function ShowSnapPlan(plan)
	local links = plan and plan.links or {}
	local i
	for i = 1, #links do
		PlaceSnapLine(SnapLine(i), links[i].box, links[i].side)
	end
	for i = #links + 1, #LB.snapLines do
		LB.snapLines[i]:Hide()
	end
	if InCombatLockdown() then
		return
	end
	local shift = plan and plan.shift
	local pushed = {}
	if shift then
		for i = 1, #shift.ids do
			local record = Logic.RecordById(LB.DB().buttons, shift.ids[i])
			local button = record and LB.ButtonFor(record)
			if button then
				button:ClearAllPoints()
				button:SetPoint("CENTER", UIParent, "CENTER", record.x + shift.dx, record.y + shift.dy)
				pushed[record.id] = true
			end
		end
	end
	local id
	for id in pairs(LB.previewShift) do
		local record = not pushed[id] and Logic.RecordById(LB.DB().buttons, id)
		local button = record and LB.ButtonFor(record)
		if button then
			PlaceButton(button, record)
		end
	end
	LB.previewShift = pushed
end

local function ClearSnapPlan()
	ShowSnapPlan(nil)
end

local FollowDrag
local BeginDrag
local FinishDrag
local TrackMoving
local StartSnapWatch
local StopSnapWatch

local snapWatch = CreateFrame("Frame", nil, UIParent)
snapWatch:SetSize(1, 1)
snapWatch:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
snapWatch:EnableMouse(false)
snapWatch:Hide()
LB.snapWatch = snapWatch

StartSnapWatch = function()
	snapWatch:SetScript("OnUpdate", TrackMoving)
	snapWatch:Show()
end

StopSnapWatch = function()
	snapWatch:SetScript("OnUpdate", nil)
	snapWatch:Hide()
end

local function PlaceIds(ids)
	local i
	for i = 1, #ids do
		local record = Logic.RecordById(LB.DB().buttons, ids[i])
		local button = record and LB.ButtonFor(record)
		if record and button and not InCombatLockdown() then
			PlaceButton(button, record)
			if button.SetUserPlaced then
				button:SetUserPlaced(false)
			end
		end
	end
end

FollowDrag = function(moving)
	if not moving then
		return
	end
	local cx, cy = CursorCenter()
	local nx, ny = moving.lastX, moving.lastY
	if cx then
		nx = cx - moving.grabDx
		ny = cy - moving.grabDy
	end
	moving.lastX = nx
	moving.lastY = ny
	local dx = nx - moving.originX
	local dy = ny - moving.originY
	local i
	for i = 1, #moving.ids do
		local start = moving.starts[moving.ids[i]]
		local record = Logic.RecordById(LB.DB().buttons, moving.ids[i])
		local button = record and LB.ButtonFor(record)
		if button and start and not InCombatLockdown() then
			button:ClearAllPoints()
			button:SetPoint("CENTER", UIParent, "CENTER", start.x + dx, start.y + dy)
		end
	end
	if moving.mode == "one" and Logic.DropIntent("loose", ActionButtonUnderCursor() ~= nil, moving.kind) == "action" then
		ClearSnapPlan()
		return
	end
	ShowSnapPlan(Logic.SnapPlan(LB.DB().buttons, moving.movers, nx, ny, LB.ScaleOf))
end

BeginDrag = function(button)
	if LB.moving or not button or InCombatLockdown() or LB.KeybindOpen() or LB.IsLocked() then
		return
	end
	local record = LB.Find(button.lbKind or "spell", button.lbSlot)
	if not record or type(record.x) ~= "number" or type(record.y) ~= "number" then
		return
	end
	if type(GameTooltip) == "table" and type(GameTooltip.Hide) == "function" then
		GameTooltip:Hide()
	end
	local mode = Logic.DragMode(ModifierDown("IsShiftKeyDown"), ModifierDown("IsAltKeyDown"))
	if mode == "one" then
		Logic.Detach(LB.DB().buttons, record.id)
	end
	local ids = { record.id }
	if mode == "group" then
		ids = Logic.Component(LB.DB().buttons, record.id)
	end
	local starts = {}
	local movers = {}
	local i
	for i = 1, #ids do
		local member = Logic.RecordById(LB.DB().buttons, ids[i])
		if member then
			starts[ids[i]] = { x = member.x, y = member.y }
			table.insert(movers, member)
		end
	end
	local cx, cy = CursorCenter()
	local savedType
	local savedAttr = "type"
	if button.lbKind == "launcher" then
		savedAttr = "type1"
	end
	if button.GetAttribute and button.SetAttribute then
		savedType = button:GetAttribute(savedAttr)
		if type(savedType) ~= "string" or savedType == "" then
			savedType = nil
		elseif button.lbKind == "launcher" then
			button:SetAttribute(savedAttr, nil)
		else
			button:SetAttribute(savedAttr, "")
		end
	end
	LB.suppressClick = true
	LB.moving = {
		leader = button,
		id = record.id,
		kind = record.kind,
		mode = mode,
		ids = ids,
		movers = movers,
		starts = starts,
		originX = record.x,
		originY = record.y,
		grabDx = (cx or record.x) - record.x,
		grabDy = (cy or record.y) - record.y,
		lastX = record.x,
		lastY = record.y,
		savedType = savedType,
		savedAttr = savedAttr,
	}
	FollowDrag(LB.moving)
	StartSnapWatch()
end

FinishDrag = function(button)
	local moving = LB.moving
	if not moving or moving.leader ~= button then
		LB.press = nil
		if not LB.moving then
			StopSnapWatch()
		end
		return
	end
	StopSnapWatch()
	ClearSnapPlan()
	LB.moving = nil
	LB.press = nil
	local savedType = moving.savedType
	local savedAttr = moving.savedAttr or "type"
	local leader = moving.leader
	LB.Defer(function()
		LB.suppressClick = nil
		if not savedType or not leader or not leader.SetAttribute then
			return
		end
		if InCombatLockdown() then
			LB.pendingDragType = { button = leader, savedType = savedType, savedAttr = savedAttr }
			return
		end
		leader:SetAttribute(savedAttr, savedType)
	end)
	if InCombatLockdown() then
		return
	end
	local record = LB.Find(button.lbKind or "spell", button.lbSlot)
	if not record then
		return
	end
	if moving.mode == "one" then
		local over = ActionButtonUnderCursor()
		if Logic.DropIntent("loose", over ~= nil, record.kind) == "action" and PlaceIntoAction(over, record.kind, record.payload, record.petCast, record.bookSlot) then
			RemoveRecord(record.kind, record.slot)
			return
		end
	end
	local nx, ny = moving.lastX, moving.lastY
	local cx, cy = CursorCenter()
	if cx then
		nx = cx - moving.grabDx
		ny = cy - moving.grabDy
	end
	local plan = Logic.Drop(LB.DB().buttons, moving.id, moving.ids, nx, ny, LB.ScaleOf)
	PlaceIds(moving.ids)
	if plan and plan.shift then
		PlaceIds(plan.shift.ids)
	end
end

TrackMoving = function()
	local press = LB.press
	if press and not LB.moving and press.x then
		local x, y = CursorPixels()
		if x and y and (math.abs(x - press.x) >= 8 or math.abs(y - press.y) >= 8) then
			BeginDrag(press.button)
		end
	end
	if LB.moving then
		FollowDrag(LB.moving)
	end
end

local function DeleteGroup(record)
	local ids = Logic.Component(LB.DB().buttons, record.id)
	local i
	for i = 1, #ids do
		local member = Logic.RecordById(LB.DB().buttons, ids[i])
		if member and LB.ButtonFor(member) then
			RemoveRecord(member.kind, member.slot)
		end
	end
end

local function TryDelete(self)
	if LB.KeybindOpen() or LB.IsLocked() then
		return
	end
	local scope = Logic.DeleteScope(ModifierDown("IsShiftKeyDown"), ModifierDown("IsAltKeyDown"))
	if not scope then
		return
	end
	if InCombatLockdown() then
		LB.Say("Cannot remove a button in combat.")
		return
	end
	local record = LB.Find(self.lbKind or "spell", self.lbSlot)
	if not record then
		return
	end
	if scope == "group" then
		DeleteGroup(record)
		return
	end
	RemoveRecord(record.kind, record.slot)
end

local function WireDrag(button)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton ~= "LeftButton" or InCombatLockdown() or LB.KeybindOpen() or LB.IsLocked() then
			return
		end
		local x, y = CursorPixels()
		LB.press = { button = self, x = x, y = y }
		StartSnapWatch()
	end)
	button:SetScript("OnDragStart", function(self)
		BeginDrag(self)
	end)
	button:SetScript("OnDragStop", function(self)
		FinishDrag(self)
	end)
	button:SetScript("OnReceiveDrag", LB.ReceiveCatalogDrop)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		if self.lbKind ~= "launcher" then
			LB.PaintFace(self, { chrome = "action" }, nil)
		end
		if mouseButton == "LeftButton" then
			local press = LB.press
			if press and not LB.moving and press.button == self and press.x then
				local x, y = CursorPixels()
				if x and y and (math.abs(x - press.x) >= 8 or math.abs(y - press.y) >= 8) then
					BeginDrag(self)
				end
			end
			FinishDrag(self)
			return
		end
		if mouseButton ~= "RightButton" then
			return
		end
		TryDelete(self)
	end)
	if button.HookScript then
		button:HookScript("OnClick", function(self, mouseButton, down)
			if self.lbKind == "launcher" and mouseButton == "LeftButton" and not down and not LB.suppressClick and not LB.KeybindOpen() then
				if not self.GetAttribute or self:GetAttribute("type1") ~= "click" then
					local record = LB.Find("launcher", self.lbSlot)
					if record then
						LB.RunLauncher(record)
					end
				end
			end
			if not down then
				self:QuickKeybindButtonOnClick(mouseButton)
			end
			if mouseButton ~= "RightButton" or LB.suppressClick then
				return
			end
			TryDelete(self)
		end)
	end
end

local function EnsurePool()
	if LB.poolReady or InCombatLockdown() then
		return LB.poolReady
	end
	local i
	for i = 1, Logic.ACTION_SLOTS do
		local name = Logic.FrameName("spell", i)
		local button = NewFace(UIParent, name, "SecureActionButtonTemplate")
		button:SetSize(45, 45)
		button:Hide()
		local cooldown = CreateFrame("Cooldown", name .. "Cooldown", button, "CooldownFrameTemplate")
		if cooldown.SetDrawBling then
			cooldown:SetDrawBling(false)
		end
		if cooldown.SetDrawEdge then
			cooldown:SetDrawEdge(false)
		end
		button.cooldown = cooldown
		LB.RaiseCooldown(button)
		button.lbKind = "spell"
		button.lbSlot = i
		WireDrag(button)
		LB.AttachTooltip(button)
		LB.actions[i] = button
	end
	for i = 1, Logic.LAUNCHER_SLOTS do
		local name = Logic.FrameName("launcher", i)
		local button = NewFace(UIParent, name, "SecureActionButtonTemplate")
		button:SetSize(32, 40)
		button:Hide()
		button:RegisterForClicks(Logic.ClickRegistration("launcher"))
		button.lbKind = "launcher"
		button.lbSlot = i
		WireDrag(button)
		LB.AttachTooltip(button)
		LB.launchers[i] = button
	end
	LB.poolReady = true
	ApplyAll()
	return true
end

local function Place(kind, payload, x, y, icon, petCast)
	if kind ~= "spell" and kind ~= "item" and kind ~= "macro" and kind ~= "launcher" and kind ~= "pet" then
		return
	end
	if kind == "pet" and petCast ~= "spell" and petCast ~= "action" then
		return
	end
	icon = Logic.UsableTexture(icon)
	if InCombatLockdown() then
		LB.pending = { kind = kind, payload = payload, x = x, y = y, icon = icon, petCast = petCast }
		LB.Say("Will place that after combat.")
		return
	end
	if not EnsurePool() then
		LB.pending = { kind = kind, payload = payload, x = x, y = y, icon = icon, petCast = petCast }
		return
	end
	local list = LB.DB().buttons
	local poolSlot = Logic.NextSlot(list, kind)
	if not poolSlot then
		LB.Say("That row is full.")
		return
	end
	local _, claimed = Logic.Layouts.Claim(LB.Account(), LB.CharKey(), LB.charName)
	local record = {
		id = Logic.RecordId(kind, poolSlot),
		kind = kind,
		payload = payload,
		key = nil,
		point = "CENTER",
		relPoint = "CENTER",
		x = x,
		y = y,
		slot = poolSlot,
		icon = icon,
	}
	if kind == "launcher" then
		record.chrome, record.atlas, record.portrait = Logic.FaceFields(record, payload)
	elseif kind == "spell" then
		record.class = LB.PlayerClass()
	elseif kind == "pet" then
		record.petCast = petCast
	end
	table.insert(list, record)
	local plan = Logic.Drop(list, record.id, { record.id }, x, y, LB.ScaleOf)
	Configure(LB.ButtonFor(record), record)
	if LB.SyncSpellRanges then
		LB.SyncSpellRanges()
	end
	if plan and plan.shift then
		PlaceIds(plan.shift.ids)
	end
	if claimed then
		LB.RefreshLayoutChrome()
	end
end

local function ResetAll()
	if InCombatLockdown() then
		LB.Say("Cannot reset in combat.")
		return
	end
	LB.DB().buttons = {}
	if LB.poolReady then
		ApplyAll()
	end
	LB.Say("Removed every button.")
end

if type(StaticPopupDialogs) == "table" then
	StaticPopupDialogs["LOOSEBUTTONS_CLEAR_ALL"] = {
		text = "Remove every loose button?",
		button1 = YES,
		button2 = NO,
		OnAccept = ResetAll,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end

local function ConfirmClear()
	if InCombatLockdown() then
		LB.Say("Cannot reset in combat.")
		return
	end
	StaticPopup_Show("LOOSEBUTTONS_CLEAR_ALL")
end

LB.ActionButtonUnderCursor = ActionButtonUnderCursor
LB.ApplyLauncherScale = ApplyLauncherScale
LB.ApplyScale = ApplyScale
LB.ClearSnapPlan = ClearSnapPlan
LB.ConfirmClear = ConfirmClear
LB.CursorCenter = CursorCenter
LB.EnsurePool = EnsurePool
LB.Place = Place
LB.PlaceIntoAction = PlaceIntoAction
LB.RefreshHotkeys = RefreshHotkeys
LB.RefreshPortraits = RefreshPortraits
LB.ResetAll = ResetAll
LB.ShowSnapPlan = ShowSnapPlan
