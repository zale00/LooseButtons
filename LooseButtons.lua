BINDING_HEADER_LOOSEBUTTONS = "Loose Buttons"
BINDING_HEADER_LOOSEBUTTONSLAUNCHERS = "Loose Buttons Launchers"

local Logic = LooseButtonsLogic
local LB = { actions = {}, launchers = {}, catalogButtons = {}, catalogHeaders = {}, snapLines = {}, previewShift = {}, bookCache = {} }
Logic.LB = LB

for slot = 1, Logic.ACTION_SLOTS do
	local frameName = Logic.FrameName("spell", slot)
	_G["BINDING_NAME_" .. Logic.ClickBinding(frameName)] = Logic.BindingLabel("spell", slot)
end
for slot = 1, Logic.LAUNCHER_SLOTS do
	local frameName = Logic.FrameName("launcher", slot)
	_G["BINDING_NAME_" .. Logic.ClickBinding(frameName)] = Logic.BindingLabel("launcher", slot)
end

function LB.Say(text)
	print("Loose Buttons: " .. text)
end

function LB.Account()
	if type(LooseButtonsDB) ~= "table" then
		LooseButtonsDB = {}
	end
	return LooseButtonsDB
end

function LB.CharKey()
	if type(UnitName) ~= "function" or type(GetRealmName) ~= "function" then
		return LB.charKey
	end
	local name = UnitName("player")
	local key = Logic.CharKey(name, GetRealmName())
	if not key or key == LB.charKey then
		return LB.charKey
	end
	LB.charKey = key
	LB.charName = name
	LB.playerClass = nil
	LB.bookCache = {}
	return LB.charKey
end

-- Until the character key resolves there is no row to write into, so writes
-- land on a throwaway blank instead of another character's layout.
function LB.DB()
	local live = Logic.Layouts.Live(LB.Account(), LB.CharKey())
	if live then
		return live
	end
	LB.unkeyed = LB.unkeyed or Logic.Profile({})
	return LB.unkeyed
end

function LB.LoadDB()
	Logic.Layouts.Normalize(LB.Account(), LB.CharKey())
end

function LB.PlayerClass()
	if not LB.playerClass and type(UnitClass) == "function" then
		local _, token = UnitClass("player")
		LB.playerClass = Logic.ClassToken(token)
	end
	return LB.playerClass
end

function LB.SpellInBook(spellID)
	if type(C_SpellBook) ~= "table" or type(C_SpellBook.FindSpellBookSlotForSpell) ~= "function" then
		return nil
	end
	local known = LB.bookCache[spellID]
	if known == nil then
		known = C_SpellBook.FindSpellBookSlotForSpell(spellID, true, true, true, true) ~= nil
		LB.bookCache[spellID] = known
	end
	return known
end

function LB.Shows(record)
	return Logic.ShowsFor(record, LB.PlayerClass(), LB.SpellInBook)
end

function LB.IsLocked()
	return Logic.NormalizeLocked(LB.DB().locked)
end

function LB.CurrentTheme()
	return Logic.NormalizeTheme(LB.DB().theme)
end

function LB.CurrentScale()
	return Logic.NormalizeScale(LB.DB().scale)
end

function LB.ScaleOf(record)
	return Logic.RecordScale(record, LB.DB().scale, LB.DB().launcherScaleSeparate, LB.DB().launcherScale)
end

function LB.ThemeOf(record)
	return Logic.RecordTheme(record, LB.DB().theme, LB.DB().launcherThemeSeparate, LB.DB().launcherTheme)
end

function LB.Find(kind, poolSlot)
	local pool = Logic.Pool(kind)
	local buttons = LB.DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		if Logic.Pool(record.kind) == pool and record.slot == poolSlot then
			return record, i
		end
	end
	return nil
end

-- A row this character cannot paint has no button, so every caller skips it.
function LB.ButtonFor(record)
	if Logic.Pool(record.kind) == "launcher" then
		return LB.launchers[record.slot]
	end
	if not LB.Shows(record) then
		return nil
	end
	return LB.actions[record.slot]
end

function LB.HiddenIds()
	local hidden = {}
	local buttons = LB.DB().buttons
	local i
	for i = 1, #buttons do
		if not LB.Shows(buttons[i]) then
			table.insert(hidden, buttons[i].id)
		end
	end
	return table.concat(hidden, ",")
end


function LB.PrettyKey(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	if type(GetBindingText) == "function" then
		local text = GetBindingText(key, 1)
		if type(text) == "string" and text ~= "" then
			return text
		end
	end
	return key
end

function LB.HotkeyString(record)
	if record and record.key then
		return LB.PrettyKey(record.key)
	end
	if record and type(GetBindingKey) == "function" then
		local frameName = Logic.FrameName(record.kind, record.slot)
		local key = GetBindingKey(Logic.ClickBinding(frameName))
		if type(key) == "string" and key ~= "" then
			return LB.PrettyKey(key)
		end
	end
	return nil
end

function LB.Describe(record)
	if record.kind == "spell" and C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(record.payload) or "Spell"
	end
	if record.kind == "item" and C_Item and C_Item.GetItemInfo then
		return C_Item.GetItemInfo(record.payload) or "Item"
	end
	if record.kind == "macro" and type(GetMacroInfo) == "function" then
		return GetMacroInfo(record.payload) or "Macro"
	end
	local launcher = Logic.LauncherByCommand(record.payload)
	if launcher then
		return launcher.name
	end
	return "Button"
end


function LB.RestoreLayout()
	LB.LoadDB()
	if not LB.poolReady or InCombatLockdown() then
		return
	end
	LB.ApplyAll()
	LB.RefreshLayoutChrome()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PORTRAITS_UPDATED")
events:RegisterEvent("UNIT_PORTRAIT_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	events:RegisterEvent("BAG_UPDATE_COOLDOWN")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("CURSOR_CHANGED")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("UPDATE_MACROS")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "LooseButtons" then
			LB.LoadDB()
			LB.WatchBook()
			LB.WatchQuickKeybind()
		elseif arg1 == "Blizzard_QuickKeybind" then
			LB.WatchQuickKeybind()
		elseif arg1 == "Blizzard_PlayerSpells" then
			LB.HookBook()
		end
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		LB.keys:Hide()
		if LB.binding then
			LB.EndBind()
		end
		return
	end
	if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
		if event == "PLAYER_LOGIN" then
			LB.LoadDB()
			LB.FollowRanks()
		end
		LB.EnsurePool()
		if event == "PLAYER_LOGIN" then
			LB.RestoreLayout()
		end
		if event == "PLAYER_LOGIN" or LB.bindsPending then
			LB.ApplyCharacterBinds()
		end
		if LB.bookStale and LB.poolReady and not InCombatLockdown() then
			LB.bookStale = nil
			LB.ApplyAll()
		end
		LB.WatchQuickKeybind()
		LB.ClearSnapPlan()
		if LB.pendingScale and not InCombatLockdown() then
			LB.ApplyScale(LB.DB().scale)
		end
		if LB.pending and not InCombatLockdown() then
			local pending = LB.pending
			LB.pending = nil
			LB.Place(pending.kind, pending.payload, pending.x, pending.y, pending.icon)
		end
		if LB.pendingDragType and not InCombatLockdown() then
			local pendingType = LB.pendingDragType
			LB.pendingDragType = nil
			if pendingType.button and pendingType.button.SetAttribute then
				pendingType.button:SetAttribute(pendingType.savedAttr or "type", pendingType.savedType)
			end
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "PORTRAITS_UPDATED" or event == "UNIT_PORTRAIT_UPDATE" then
		if event == "PLAYER_ENTERING_WORLD" then
			local seen = LB.charKey
			if LB.CharKey() ~= seen then
				LB.bindsReady = nil
				LB.RestoreLayout()
				LB.ApplyCharacterBinds()
			end
		end
		if event == "UNIT_PORTRAIT_UPDATE" then
			if type(issecretvalue) == "function" and issecretvalue(arg1) then
				LB.Defer(LB.RefreshPortraits)
				return
			end
			if arg1 ~= "player" then
				return
			end
		end
		LB.Defer(LB.RefreshPortraits)
		return
	end
	if event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "BAG_UPDATE_DELAYED" then
		LB.UpdateCooldowns()
		return
	end
	if event == "UPDATE_BINDINGS" then
		LB.CaptureCharacterBinds()
		LB.RefreshHotkeys()
		return
	end
	if event == "SPELLS_CHANGED" then
		LB.bookCache = {}
		LB.FollowRanks()
		if LB.poolReady and LB.HiddenIds() ~= LB.hiddenIds then
			LB.bookStale = true
		end
		if LB.bookStale and LB.poolReady and not InCombatLockdown() then
			LB.bookStale = nil
			LB.ApplyAll()
		end
		return
	end
	if event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "UPDATE_MACROS" then
		if event == "LEARNED_SPELL_IN_SKILL_LINE" then
			LB.FollowRanks()
			if LB.bookStale and LB.poolReady and not InCombatLockdown() then
				LB.bookStale = nil
				LB.ApplyAll()
			end
		end
		if LB.page and LB.page:IsShown() then
			LB.LayoutCatalog(nil, true)
		end
		return
	end
	if event == "CURSOR_CHANGED" then
		if LB.dragLauncher then
			return
		end
		if LB.dragSpell then
			if arg1 then
				LB.dragSpell = nil
				LB.HideReceive()
			end
			return
		end
		LB.receive:Hide()
	end
end)

SLASH_LOOSEBUTTONS1 = "/loose"
SLASH_LOOSEBUTTONS2 = "/lb"
SlashCmdList["LOOSEBUTTONS"] = function(msg)
	msg = string.lower(msg or "")
	msg = string.gsub(msg, "^%s+", "")
	msg = string.gsub(msg, "%s+$", "")
	if msg == "reset" then
		LB.ResetAll()
		return
	end
	if msg == "help" then
		LB.OpenHelp()
		return
	end
	if msg == "bind" or msg == "keybind" or msg == "" then
		LB.ToggleBind()
		return
	end
	LB.Say("Unknown command. /loose help")
end

-- tools/check_loosebuttons.lua matches these source texts. The calls are LB.IsLocked and LB.ThemeOf.
-- or IsLocked()
-- PaintFace(button, Logic.LauncherPaint(record), nil, ThemeOf(record))
