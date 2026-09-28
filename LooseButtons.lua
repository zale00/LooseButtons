BINDING_HEADER_LOOSEBUTTONS = "Loose Buttons"
BINDING_HEADER_LOOSEBUTTONSLAUNCHERS = "Loose Buttons Launchers"

local Logic = LooseButtonsLogic
local LB = { actions = {}, launchers = {}, catalogButtons = {}, catalogHeaders = {}, snapLines = {}, previewShift = {}, bookCache = {} }

for slot = 1, Logic.ACTION_SLOTS do
	local frameName = Logic.FrameName("spell", slot)
	_G["BINDING_NAME_" .. Logic.ClickBinding(frameName)] = Logic.BindingLabel("spell", slot)
end
for slot = 1, Logic.LAUNCHER_SLOTS do
	local frameName = Logic.FrameName("launcher", slot)
	_G["BINDING_NAME_" .. Logic.ClickBinding(frameName)] = Logic.BindingLabel("launcher", slot)
end

local function Say(text)
	print("Loose Buttons: " .. text)
end

local function Account()
	if type(LooseButtonsDB) ~= "table" then
		LooseButtonsDB = {}
	end
	return LooseButtonsDB
end

local function CharKey()
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
local function DB()
	local live = Logic.Layouts.Live(Account(), CharKey())
	if live then
		return live
	end
	LB.unkeyed = LB.unkeyed or Logic.Profile({})
	return LB.unkeyed
end

local function LoadDB()
	Logic.Layouts.Normalize(Account(), CharKey())
end

local function PlayerClass()
	if not LB.playerClass and type(UnitClass) == "function" then
		local _, token = UnitClass("player")
		LB.playerClass = Logic.ClassToken(token)
	end
	return LB.playerClass
end

local function SpellInBook(spellID)
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

local function Shows(record)
	return Logic.ShowsFor(record, PlayerClass(), SpellInBook)
end

local function IsLocked()
	return Logic.NormalizeLocked(DB().locked)
end

local function CurrentTheme()
	return Logic.NormalizeTheme(DB().theme)
end

local function CurrentScale()
	return Logic.NormalizeScale(DB().scale)
end

local function ScaleOf(record)
	return Logic.RecordScale(record, DB().scale, DB().launcherScaleSeparate, DB().launcherScale)
end

local function ThemeOf(record)
	return Logic.RecordTheme(record, DB().theme, DB().launcherThemeSeparate, DB().launcherTheme)
end

local function Find(kind, poolSlot)
	local pool = Logic.Pool(kind)
	local buttons = DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		if Logic.Pool(record.kind) == pool and record.slot == poolSlot then
			return record, i
		end
	end
	return nil
end
