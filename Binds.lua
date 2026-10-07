local Logic = LooseButtonsLogic
local LB = Logic.LB

local function IconFor(record)
	if record.kind == "spell" and C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(record.payload)
	end
	if record.kind == "item" and C_Item then
		if C_Item.GetItemIconByID then
			local icon = C_Item.GetItemIconByID(record.payload)
			if Logic.UsableTexture(icon) then
				return icon
			end
		end
		if C_Item.GetItemInfoInstant then
			local _, _, _, _, icon = C_Item.GetItemInfoInstant(record.payload)
			return icon
		end
	end
	if record.kind == "macro" and type(GetMacroInfo) == "function" then
		local _, icon = GetMacroInfo(record.payload)
		return icon
	end
	if record.kind == "pet" and record.petCast == "spell" and C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(record.payload)
	end
	return nil
end

local RefreshHotkey

local function RangeSpellID(record)
	if type(record) ~= "table" then
		return nil
	end
	if record.kind == "spell" or (record.kind == "pet" and record.petCast == "spell") then
		if type(record.payload) == "number" then
			return record.payload
		end
	end
	return nil
end

local function ApplyOutOfRange(button, record, outOfRange)
	if not button then
		return
	end
	button.lbOutOfRange = outOfRange and true or false
	RefreshHotkey(button, record)
end

function LB.PetActionBarSlot(petActionID)
	if type(petActionID) ~= "number" then
		return nil
	end
	if not C_ActionBar or type(C_ActionBar.GetPetActionPetBarIndices) ~= "function" then
		return nil
	end
	return Logic.PetBarSlot(C_ActionBar.GetPetActionPetBarIndices(petActionID))
end

local function PaintPetActionRange(record)
	if type(record) ~= "table" or record.kind ~= "pet" or record.petCast ~= "action" then
		return false
	end
	local button = LB.ButtonFor(record)
	local barSlot = LB.PetActionBarSlot(record.payload)
	if not barSlot or type(GetPetActionInfo) ~= "function" then
		ApplyOutOfRange(button, record, false)
		return true
	end
	local _, _, _, _, _, _, _, checksRange, inRange = GetPetActionInfo(barSlot)
	ApplyOutOfRange(button, record, Logic.HotkeyOutOfRange(checksRange, inRange))
	return true
end

local function RefreshPetActionRanges()
	if not LB.poolReady or type(LB.DB) ~= "function" then
		return
	end
	local buttons = LB.DB().buttons
	if type(buttons) ~= "table" then
		return
	end
	local i
	for i = 1, #buttons do
		PaintPetActionRange(buttons[i])
	end
end

local function RefreshSpellRange(record, checksRange, inRange)
	local button = LB.ButtonFor(record)
	ApplyOutOfRange(button, record, Logic.HotkeyOutOfRange(checksRange, inRange))
end

local function QuerySpellRange(spellID)
	if not C_Spell or type(C_Spell.IsSpellInRange) ~= "function" then
		return false, true
	end
	local inRange = C_Spell.IsSpellInRange(spellID)
	if type(issecretvalue) == "function" and issecretvalue(inRange) then
		return false, true
	end
	if inRange == nil then
		return false, true
	end
	if inRange == false then
		return true, false
	end
	return true, true
end

local function SyncSpellRanges()
	if not LB.poolReady or type(LB.DB) ~= "function" then
		return
	end
	local buttons = LB.DB().buttons
	if type(buttons) ~= "table" then
		return
	end
	local nextIds = {}
	local i
	for i = 1, #buttons do
		local spellID = RangeSpellID(buttons[i])
		if spellID then
			nextIds[spellID] = true
		end
	end
	local previous = LB.rangeSpellIds or {}
	if C_Spell and type(C_Spell.EnableSpellRangeCheck) == "function" then
		local id
		for id in pairs(previous) do
			if not nextIds[id] then
				C_Spell.EnableSpellRangeCheck(id, false)
			end
		end
		for id in pairs(nextIds) do
			if not previous[id] then
				C_Spell.EnableSpellRangeCheck(id, true)
			end
		end
	end
	LB.rangeSpellIds = nextIds
	for i = 1, #buttons do
		local record = buttons[i]
		local spellID = RangeSpellID(record)
		if spellID then
			local checksRange, inRange = QuerySpellRange(spellID)
			RefreshSpellRange(record, checksRange, inRange)
		elseif not PaintPetActionRange(record) then
			local button = LB.ButtonFor(record)
			if button and button.lbOutOfRange then
				ApplyOutOfRange(button, record, false)
			end
		end
	end
end

local function OnSpellRange(spellID, isInRange, checksRange)
	if type(issecretvalue) == "function" and issecretvalue(spellID) then
		return
	end
	if type(spellID) ~= "number" or not LB.poolReady or type(LB.DB) ~= "function" then
		return
	end
	local buttons = LB.DB().buttons
	if type(buttons) ~= "table" then
		return
	end
	local oor = Logic.HotkeyOutOfRange(checksRange, isInRange)
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		if RangeSpellID(record) == spellID then
			ApplyOutOfRange(LB.ButtonFor(record), record, oor)
		else
			PaintPetActionRange(record)
		end
	end
end

local function BindingKeyText(button)
	if type(GetBindingKey) ~= "function" or not button or not button.commandName then
		return nil
	end
	local key = GetBindingKey(button.commandName)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	if type(GetBindingText) == "function" then
		return GetBindingText(key, "KEY_")
	end
	return key
end

function RefreshHotkey(button, record)
	if not button or not button.hotkeyText then
		return
	end
	local text = BindingKeyText(button) or (record and LB.HotkeyString(record)) or nil
	if text then
		button.hotkeyText:SetText(text)
	else
		button.hotkeyText:SetText("")
	end
	if LB.PaintHotkeyRange then
		LB.PaintHotkeyRange(button.hotkeyText, button.lbOutOfRange)
	end
	if button.hotkey then
		button.hotkey:EnableMouse(text ~= nil)
	end
end

local function ApplyKey(button, record)
	if InCombatLockdown() or not button then
		return
	end
	if type(ClearOverrideBindings) == "function" then
		ClearOverrideBindings(button)
	end
	if not record or not record.key then
		return
	end
	if record.kind == "launcher" then
		if type(SetOverrideBinding) == "function" then
			SetOverrideBinding(button, false, record.key, record.payload)
		end
		return
	end
	if type(SetOverrideBindingClick) == "function" then
		SetOverrideBindingClick(button, false, record.key, button:GetName(), "LeftButton")
	end
end

local function ClearKey(record)
	if not record or InCombatLockdown() then
		return
	end
	record.key = nil
	local button = LB.ButtonFor(record)
	local who = LB.CharKey()
	if who then
		Logic.Binds.Put(LB.Account(), who, Logic.ClickBinding(Logic.FrameName(record.kind, record.slot)), "CLEAR")
		LB.ApplyCharacterBinds()
	end
	ApplyKey(button, record)
	RefreshHotkey(button, record)
end

local function SetActionClicks(button)
	if InCombatLockdown() or not button.RegisterForClicks then
		return
	end
	button:RegisterForClicks(Logic.ClickRegistration(button.lbKind))
end

local catcher

-- Placed buttons sit above the spell drop layer, so a catalog spell released
-- over one lands here instead of on that layer.
local function ReceiveCatalogDrop()
	if LB.dragSpell or LB.dragLauncher then
		LB.FinishDrop()
	end
end

local function StartCapture(button, record)
	if InCombatLockdown() or not catcher or not record then
		return
	end
	catcher.record = record
	catcher.button = button
	catcher:Show()
	if catcher.SetPropagateKeyboardInput then
		catcher:SetPropagateKeyboardInput(true)
	end
	LB.Say("Press a key, extra mouse button, wheel, or controller button. Escape clears the bind.")
end

local function BindingFromKey(key)
	return Logic.BindingToken(key, IsAltKeyDown(), IsControlKeyDown(), IsShiftKeyDown())
end

local function AttachHotkey(button)
	local hot = CreateFrame("Button", nil, button)
	hot:SetSize(37, 10)
	hot:SetPoint("TOPRIGHT", -4, -5)
	hot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local text = hot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	text:SetAllPoints()
	text:SetJustifyH("RIGHT")
	button.hotkey = hot
	button.hotkeyText = text
	hot:SetScript("OnReceiveDrag", ReceiveCatalogDrop)
	hot:SetScript("OnClick", function(self, mouseButton)
		local record = LB.Find(button.lbKind or "spell", button.lbSlot)
		if not record or InCombatLockdown() then
			return
		end
		if mouseButton == "RightButton" then
			ClearKey(record)
			return
		end
		StartCapture(button, record)
	end)
end

local function ShowTip(owner, record)
	if type(GameTooltip) ~= "table" or type(GameTooltip.SetOwner) ~= "function" or type(record) ~= "table" then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")
	local payload = record.payload
	if (record.kind == "spell" or (record.kind == "pet" and record.petCast == "spell")) and type(payload) == "number" and type(GameTooltip.SetSpellByID) == "function" then
		if GameTooltip:SetSpellByID(payload) ~= false then
			return
		end
	end
	if record.kind == "pet" and record.petCast == "action" and type(payload) == "number" and type(GameTooltip.SetPetAction) == "function" then
		local barSlot = LB.PetActionBarSlot(payload)
		if barSlot and GameTooltip:SetPetAction(barSlot) ~= false then
			return
		end
	end
	if record.kind == "item" and type(payload) == "number" and type(GameTooltip.SetItemByID) == "function" then
		if GameTooltip:SetItemByID(payload) ~= false then
			return
		end
	end
	local name = record.name
	if type(name) ~= "string" or name == "" then
		name = LB.Describe(record)
	end
	if type(name) ~= "string" or name == "" or type(GameTooltip.SetText) ~= "function" then
		return
	end
	GameTooltip:SetText(name)
	if type(GameTooltip.Show) == "function" then
		GameTooltip:Show()
	end
end

local function KeybindOpen()
	return LB.binding or (type(KeybindFrames_InQuickKeybindMode) == "function" and KeybindFrames_InQuickKeybindMode())
end

local function HideTips()
	if type(GameTooltip) == "table" and type(GameTooltip.Hide) == "function" then
		GameTooltip:Hide()
	end
	if type(QuickKeybindTooltip) == "table" and type(QuickKeybindTooltip.Hide) == "function" then
		QuickKeybindTooltip:Hide()
	end
end

local function AttachTooltip(button)
	button:SetScript("OnEnter", function(self)
		if KeybindOpen() then
			HideTips()
		end
		if self.QuickKeybindButtonOnEnter then
			self:QuickKeybindButtonOnEnter()
		end
		if KeybindOpen() then
			return
		end
		ShowTip(self, LB.Find(self.lbKind or "spell", self.lbSlot))
	end)
	button:SetScript("OnLeave", function(self)
		if self.QuickKeybindButtonOnLeave then
			self:QuickKeybindButtonOnLeave()
		end
		HideTips()
	end)
end

local function Defer(fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, fn)
		return
	end
	fn()
end

local function SyncQuickKeybind(show)
	local pools = { LB.actions, LB.launchers }
	local p
	for p = 1, #pools do
		local pool = pools[p]
		local i
		for i = 1, #pool do
			local button = pool[i]
			if button and button.DoModeChange then
				button:DoModeChange(show)
			end
			if button and button.UpdateMouseWheelHandler then
				button:UpdateMouseWheelHandler()
			end
			if show and button and not InCombatLockdown() then
				if button.lbKind == "launcher" then
					button:SetAttribute("type1", nil)
				else
					button:SetAttribute("type", "")
				end
			end
		end
	end
end

local function RestoreButtons()
	SyncQuickKeybind(false)
	if not LB.poolReady then
		return
	end
	if InCombatLockdown() then
		LB.bookStale = true
		return
	end
	LB.ApplyAll()
end

local function WatchQuickKeybind()
	local frame = QuickKeybindFrame
	if LB.quickWatch or not frame or not frame.HookScript then
		return
	end
	LB.quickWatch = true
	frame:HookScript("OnShow", function()
		Defer(function()
			HideTips()
			SyncQuickKeybind(true)
		end)
	end)
	frame:HookScript("OnHide", function()
		Defer(function()
			if not LB.binding then
				RestoreButtons()
			end
		end)
	end)
	if frame:IsShown() then
		SyncQuickKeybind(true)
	end
end

local keys = CreateFrame("Frame", nil, UIParent)
keys:SetFrameStrata("TOOLTIP")
keys:Hide()
if keys.EnableKeyboard then
	keys:EnableKeyboard(true)
end

function LB.LiveBindRows()
	local live = {}
	local commands = Logic.Binds.Commands()
	local i
	for i = 1, #commands do
		local keys = { GetBindingKey(commands[i]) }
		local k
		for k = 1, #keys do
			if type(keys[k]) == "string" and keys[k] ~= "" then
				live[#live + 1] = { key = keys[k], command = commands[i] }
			end
		end
	end
	return live
end

function LB.ApplyCharacterBinds()
	if type(SetBinding) ~= "function" or type(GetBindingKey) ~= "function" or type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then
		return
	end
	if InCombatLockdown() then
		LB.bindsPending = true
		return
	end
	local who = LB.CharKey()
	if not who then
		return
	end
	LB.bindsPending = nil
	local ops = Logic.Binds.Reconcile(Logic.Binds.All(LB.Account(), who), LB.LiveBindRows())
	LB.bindsReady = true
	if #ops == 0 then
		return
	end
	LB.bindsApplying = true
	local i
	for i = 1, #ops do
		local op = ops[i]
		if op.command then
			SetBinding(op.key, op.command)
		else
			SetBinding(op.key)
		end
	end
	SaveBindings(GetCurrentBindingSet())
	LB.bindsApplying = nil
end

function LB.CaptureCharacterBinds()
	if LB.bindsApplying or not LB.bindsReady then
		return
	end
	local who = LB.CharKey()
	if not who then
		return
	end
	Logic.Binds.Capture(LB.Account(), who, LB.LiveBindRows())
end

local function BindHovered(button, key)
	local binding = BindingFromKey(key)
	local command = button and button.commandName
	if not binding or not command or InCombatLockdown() then
		return
	end
	local who = LB.CharKey()
	if who and Logic.Binds.Put(LB.Account(), who, command, binding) then
		LB.ApplyCharacterBinds()
	else
		local old = { GetBindingKey(command) }
		local i
		for i = 1, #old do
			SetBinding(old[i])
		end
		if binding ~= "CLEAR" then
			SetBinding(binding, command)
		end
		SaveBindings(GetCurrentBindingSet())
	end
	RefreshHotkey(button, LB.Find(button.lbKind or "spell", button.lbSlot))
	button:QuickKeybindButtonSetTooltip()
end

keys:SetScript("OnKeyDown", function(self, key)
	BindHovered(self.button, key)
end)
keys:SetScript("OnShow", function(self)
	if self.EnableGamePadButton then
		self:EnableGamePadButton(true)
	end
end)
keys:SetScript("OnHide", function(self)
	if self.EnableGamePadButton then
		self:EnableGamePadButton(false)
	end
end)
keys:SetScript("OnGamePadButtonDown", function(self, button)
	BindHovered(self.button, button)
end)
-- A missed OnLeave would leave this frame eating every key press.
keys:SetScript("OnUpdate", function(self)
	local button = self.button
	if InCombatLockdown() or not KeybindOpen() or not button or not button:IsVisible() or not button:IsMouseOver() then
		self:Hide()
		HideTips()
	end
end)

local endBindButton = CreateFrame("Button", "LooseButtonsEndBind")

local function EndBind()
	LB.binding = nil
	keys:Hide()
	HideTips()
	if type(ClearOverrideBindings) == "function" then
		ClearOverrideBindings(endBindButton)
	end
	RestoreButtons()
end

endBindButton:SetScript("OnClick", EndBind)

local function ToggleBind()
	if LB.binding then
		EndBind()
		return
	end
	if InCombatLockdown() then
		LB.Say("Cannot bind in combat.")
		return
	end
	LB.binding = true
	HideTips()
	if type(SetOverrideBindingClick) == "function" then
		SetOverrideBindingClick(endBindButton, true, "ESCAPE", endBindButton:GetName(), "LeftButton")
	end
	SyncQuickKeybind(true)
	LB.Say("Hover a loose button and press a key, extra mouse button, wheel, or controller button. Escape clears it. Click Edit or press Escape elsewhere to finish.")
end

local function EnsureQuickKeybind(button, name)
	if not button.QuickKeybindHighlightTexture then
		local tex = button:CreateTexture(nil, "OVERLAY")
		tex:SetPoint("CENTER")
		tex:SetSize(46, 45)
		tex:SetColorTexture(1, 0.82, 0, 0.35)
		tex:Hide()
		button.QuickKeybindHighlightTexture = tex
	end
	button.commandName = Logic.ClickBinding(name or button:GetName())
	button.DoModeChange = function(self, isInQuickbindMode)
		if self.QuickKeybindHighlightTexture then
			self.QuickKeybindHighlightTexture:SetShown(isInQuickbindMode)
		end
	end
	button.QuickKeybindButtonOnEnter = function(self)
		if not KeybindOpen() or InCombatLockdown() then
			return
		end
		if self.QuickKeybindHighlightTexture then
			self.QuickKeybindHighlightTexture:Show()
			self.QuickKeybindHighlightTexture:SetAlpha(1)
		end
		keys.button = self
		keys:Show()
		self:QuickKeybindButtonSetTooltip()
	end
	button.QuickKeybindButtonSetTooltip = function(self)
		if type(self.commandName) ~= "string" then
			return
		end
		local tip = QuickKeybindTooltip
		if type(tip) ~= "table" or type(tip.SetOwner) ~= "function" or type(tip.Show) ~= "function" then
			return
		end
		tip:SetOwner(self, "ANCHOR_RIGHT")
		local title = self.commandName
		if type(GetBindingName) == "function" then
			local label = GetBindingName(self.commandName)
			if type(label) == "string" and label ~= "" then
				title = label
			end
		end
		if type(GameTooltip_AddHighlightLine) == "function" then
			GameTooltip_AddHighlightLine(tip, title)
		elseif type(tip.AddLine) == "function" then
			tip:AddLine(title)
		end
		local key
		if type(GetBindingKey) == "function" then
			key = GetBindingKey(self.commandName)
		end
		if type(key) == "string" and key ~= "" and type(tip.AddLine) == "function" then
			tip:AddLine(key)
		end
		tip:Show()
	end
	button.QuickKeybindButtonOnLeave = function(self)
		keys:Hide()
		if self.QuickKeybindHighlightTexture then
			self.QuickKeybindHighlightTexture:SetAlpha(0.35)
		end
		local record = LB.Find(self.lbKind or "spell", self.lbSlot)
		RefreshHotkey(self, record)
	end
	button.QuickKeybindButtonOnClick = function(self, mouseButton)
		if keys:IsShown() and keys.button == self then
			BindHovered(self, mouseButton)
		end
	end
	button.UpdateMouseWheelHandler = function(self)
		if self.EnableMouseWheel then
			self:EnableMouseWheel(KeybindOpen() and true or false)
		end
	end
	button:SetScript("OnMouseWheel", function(self, delta)
		if not keys:IsShown() or keys.button ~= self or type(delta) ~= "number" or delta == 0 then
			return
		end
		if delta > 0 then
			BindHovered(self, "MOUSEWHEELUP")
			return
		end
		BindHovered(self, "MOUSEWHEELDOWN")
	end)
	button:UpdateMouseWheelHandler()
end


catcher = CreateFrame("Frame", "LooseButtonsCatcher", UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("TOOLTIP")
catcher:EnableMouse(true)
catcher:Hide()
if catcher.EnableKeyboard then
	catcher:EnableKeyboard(true)
end
catcher:SetScript("OnMouseDown", function(self)
	self:Hide()
end)
catcher:SetScript("OnKeyDown", function(self, key)
	if self.SetPropagateKeyboardInput then
		self:SetPropagateKeyboardInput(false)
	end
	local binding = BindingFromKey(key)
	if not binding then
		if self.SetPropagateKeyboardInput then
			self:SetPropagateKeyboardInput(true)
		end
		return
	end
	if binding == "CLEAR" then
		ClearKey(self.record)
	elseif self.record then
		local who = LB.CharKey()
		local command = Logic.ClickBinding(Logic.FrameName(self.record.kind, self.record.slot))
		if who and Logic.Binds.Put(LB.Account(), who, command, binding) then
			self.record.key = nil
			LB.ApplyCharacterBinds()
		else
			self.record.key = binding
		end
		ApplyKey(self.button, self.record)
		RefreshHotkey(self.button, self.record)
	end
	self:Hide()
end)

LB.ApplyKey = ApplyKey
LB.AttachHotkey = AttachHotkey
LB.AttachTooltip = AttachTooltip
LB.Defer = Defer
LB.EndBind = EndBind
LB.EnsureQuickKeybind = EnsureQuickKeybind
LB.IconFor = IconFor
LB.KeybindOpen = KeybindOpen
LB.ReceiveCatalogDrop = ReceiveCatalogDrop
LB.RefreshHotkey = RefreshHotkey
LB.RefreshPetActionRanges = RefreshPetActionRanges
LB.SyncSpellRanges = SyncSpellRanges
LB.OnSpellRange = OnSpellRange
LB.SetActionClicks = SetActionClicks
LB.ShowTip = ShowTip
LB.ToggleBind = ToggleBind
LB.WatchQuickKeybind = WatchQuickKeybind
LB.keys = keys
