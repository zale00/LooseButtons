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
	if not LB.charKey and type(UnitName) == "function" and type(GetRealmName) == "function" then
		local name = UnitName("player")
		LB.charKey = Logic.CharKey(name, GetRealmName())
		if LB.charKey then
			LB.charName = name
		end
	end
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

-- A row this character cannot paint has no button, so every caller skips it.
local function ButtonFor(record)
	if Logic.Pool(record.kind) == "launcher" then
		return LB.launchers[record.slot]
	end
	if not Shows(record) then
		return nil
	end
	return LB.actions[record.slot]
end

local function HiddenIds()
	local hidden = {}
	local buttons = DB().buttons
	local i
	for i = 1, #buttons do
		if not Shows(buttons[i]) then
			table.insert(hidden, buttons[i].id)
		end
	end
	return table.concat(hidden, ",")
end

local function OverBook()
	local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
	if book and book.IsMouseOver and book:IsShown() and book:IsMouseOver() then
		return true
	end
	return false
end

local function PrettyKey(key)
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

local function HotkeyString(record)
	if record and record.key then
		return PrettyKey(record.key)
	end
	if record and type(GetBindingKey) == "function" then
		local frameName = Logic.FrameName(record.kind, record.slot)
		local key = GetBindingKey(Logic.ClickBinding(frameName))
		if type(key) == "string" and key ~= "" then
			return PrettyKey(key)
		end
	end
	return nil
end

local function Describe(record)
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

local CLICK = {
	character = function()
		ToggleCharacter("PaperDollFrame")
	end,
	spellbook = function()
		if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
			PlayerSpellsUtil.ToggleSpellBookFrame()
		end
	end,
	talents = function()
		if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentOrSpecFrame then
			PlayerSpellsUtil.ToggleClassTalentOrSpecFrame()
		end
	end,
	professions = function()
		if ToggleProfessionsBook then
			ToggleProfessionsBook()
		end
	end,
	legacy = function()
		if ToggleLegacySystemUI then
			ToggleLegacySystemUI()
		end
	end,
	quest = function()
		if ToggleQuestLog then
			ToggleQuestLog()
		end
	end,
	guild = function()
		if ToggleGuildFrame then
			ToggleGuildFrame()
		end
	end,
	collections = function()
		if ToggleCollectionsJournal then
			ToggleCollectionsJournal()
		end
	end,
	backpack = function()
		if ToggleBackpack then
			ToggleBackpack()
		end
	end,
	bags = function()
		if ToggleAllBags then
			ToggleAllBags()
		end
	end,
	gamemenu = function()
		if InCombatLockdown() then
			return
		end
		if GameMenuFrame_IsShown and GameMenuFrame_IsShown() then
			if HideUIPanel then
				HideUIPanel(GameMenuFrame)
			end
			return
		end
		if GameMenuFrame_Show then
			GameMenuFrame_Show()
		end
	end,
	finder = function()
		if ToggleGroupFinderFrame then
			ToggleGroupFinderFrame()
		end
	end,
	achievements = function()
		if ToggleAchievementFrame then
			ToggleAchievementFrame()
		end
	end,
	journal = function()
		if ToggleEncounterJournal then
			ToggleEncounterJournal()
		end
	end,
	housing = function()
		if HousingFramesUtil and HousingFramesUtil.ToggleHousingDashboard then
			HousingFramesUtil.ToggleHousingDashboard()
		end
	end,
}

local function RunLauncher(record)
	local spec = Logic.LauncherByCommand(record.payload)
	local fn = spec and CLICK[spec.click]
	if not fn then
		return
	end
	if type(securecall) == "function" then
		securecall(fn)
		return
	end
	fn()
end

local function HideRegion(region)
	if region then
		region:Hide()
	end
end

local function MicroPlate(button)
	if not button.plate then
		button.plate = button:CreateTexture(nil, "BACKGROUND")
		button.plate:SetPoint("CENTER")
	end
	return button.plate
end

local function ClearStateTextures(button)
	if button.ClearNormalTexture then
		button:ClearNormalTexture()
	else
		HideRegion(button:GetNormalTexture())
	end
	if button.ClearPushedTexture then
		button:ClearPushedTexture()
	else
		HideRegion(button:GetPushedTexture())
	end
	if button.ClearHighlightTexture then
		button:ClearHighlightTexture()
	else
		HideRegion(button:GetHighlightTexture())
	end
end

local function Edge(button, layer)
	local tex = button:CreateTexture(nil, layer)
	tex:SetColorTexture(1, 1, 1, 1)
	return tex
end

local function EnsureChrome(button)
	if button.lbChrome then
		return button.lbChrome
	end
	local chrome = {
		shadow = Edge(button, "BACKGROUND"),
		well = Edge(button, "BORDER"),
		top = Edge(button, "OVERLAY"),
		bottom = Edge(button, "OVERLAY"),
		left = Edge(button, "OVERLAY"),
		right = Edge(button, "OVERLAY"),
	}
	button.lbChrome = chrome
	return chrome
end

local function HideChrome(button)
	local chrome = button.lbChrome
	if not chrome then
		return
	end
	chrome.shadow:Hide()
	chrome.well:Hide()
	chrome.top:Hide()
	chrome.bottom:Hide()
	chrome.left:Hide()
	chrome.right:Hide()
end

local function PlaceEdge(tex, parent, a, b, c, d, e, f, g, h, r, gch, bch, alpha)
	tex:ClearAllPoints()
	tex:SetPoint(a, parent, b, c, d)
	tex:SetPoint(e, parent, f, g, h)
	tex:SetColorTexture(r, gch, bch, alpha)
	tex:Show()
end

local function ApplyChrome(button, spec)
	local chrome = EnsureChrome(button)
	if spec.shadowA > 0 then
		local shift = spec.shadow
		chrome.shadow:ClearAllPoints()
		chrome.shadow:SetPoint("TOPLEFT", button, "TOPLEFT", shift, -shift)
		chrome.shadow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", shift, -shift)
		chrome.shadow:SetColorTexture(0, 0, 0, spec.shadowA)
		chrome.shadow:Show()
	else
		chrome.shadow:Hide()
	end
	if spec.wellA > 0 then
		chrome.well:ClearAllPoints()
		chrome.well:SetPoint("TOPLEFT", button, "TOPLEFT", spec.rim, -spec.rim)
		chrome.well:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -spec.rim, spec.rim)
		chrome.well:SetColorTexture(spec.wellR, spec.wellG, spec.wellB, spec.wellA)
		chrome.well:Show()
	else
		chrome.well:Hide()
	end
	if spec.rim > 0 then
		local rim = spec.rim
		PlaceEdge(chrome.top, button, "TOPLEFT", "TOPLEFT", 0, 0, "BOTTOMRIGHT", "TOPRIGHT", 0, -rim, spec.rimR, spec.rimG, spec.rimB, spec.rimA)
		PlaceEdge(chrome.bottom, button, "TOPLEFT", "BOTTOMLEFT", 0, rim, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, spec.rimR, spec.rimG, spec.rimB, spec.rimA)
		PlaceEdge(chrome.left, button, "TOPLEFT", "TOPLEFT", 0, -rim, "BOTTOMRIGHT", "BOTTOMLEFT", rim, rim, spec.rimR, spec.rimG, spec.rimB, spec.rimA)
		PlaceEdge(chrome.right, button, "TOPLEFT", "TOPRIGHT", -rim, -rim, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, rim, spec.rimR, spec.rimG, spec.rimB, spec.rimA)
	else
		chrome.top:Hide()
		chrome.bottom:Hide()
		chrome.left:Hide()
		chrome.right:Hide()
	end
	if button.border then
		button.border:Hide()
	end
	button.icon:ClearAllPoints()
	button.icon:SetPoint("TOPLEFT", spec.inset, -spec.inset)
	button.icon:SetPoint("BOTTOMRIGHT", -spec.inset, spec.inset)
end

local function FitStockFrame(texture, frameW, frameH, role)
	if not texture or not texture.ClearAllPoints then
		return
	end
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", 0, 0)
	texture:SetSize(frameW, frameH)
	if role == "highlight" then
		if texture.SetDrawLayer then
			texture:SetDrawLayer("HIGHLIGHT")
		end
		return
	end
	if texture.SetDrawLayer then
		texture:SetDrawLayer("OVERLAY")
	end
	if Logic.StockIdleShown(role) then
		texture:Show()
	else
		texture:Hide()
	end
end

local function SetIconMask(button, shown, width, height)
	local icon = button.icon
	if not icon then
		return
	end
	if shown and not button.lbIconMask and icon.AddMaskTexture and button.CreateMaskTexture then
		local mask = button:CreateMaskTexture()
		if mask and mask.SetAtlas then
			mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
			button.lbIconMask = mask
		end
	end
	if not button.lbIconMask then
		return
	end
	if shown then
		if icon.RemoveMaskTexture then
			icon:RemoveMaskTexture(button.lbIconMask)
		end
		if icon.AddMaskTexture then
			icon:AddMaskTexture(button.lbIconMask)
		end
		button.lbIconMask:Show()
		button.lbIconMask:ClearAllPoints()
		button.lbIconMask:SetPoint("CENTER", icon, "CENTER", 0, 0)
		button.lbIconMask:SetSize(width, height)
		return
	end
	if icon.RemoveMaskTexture then
		icon:RemoveMaskTexture(button.lbIconMask)
	end
	button.lbIconMask:Hide()
end

local function AnchorCooldown(button)
	local cooldown = button.cooldown
	local icon = button.icon
	if not cooldown or not icon or not cooldown.ClearAllPoints then
		return
	end
	cooldown:ClearAllPoints()
	cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 3, -3)
	cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -3, 3)
end

local function RaiseCooldown(button)
	local cooldown = button.cooldown
	if not cooldown then
		return
	end
	if cooldown.SetDrawSwipe then
		cooldown:SetDrawSwipe(true)
	end
	if cooldown.SetSwipeColor then
		cooldown:SetSwipeColor(0, 0, 0, 0.64)
	end
	if cooldown.SetFrameLevel and button.GetFrameLevel then
		cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	end
	if button.hotkey and button.hotkey.SetFrameLevel and button.GetFrameLevel then
		button.hotkey:SetFrameLevel(button:GetFrameLevel() + 2)
	end
	AnchorCooldown(button)
end

local function PlaceCount(button)
	if not button.lbCount then
		local frame = CreateFrame("Frame", nil, button)
		if frame.EnableMouse then
			frame:EnableMouse(false)
		end
		local text = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		text:SetJustifyH("RIGHT")
		button.lbCount = frame
		button.lbCountText = text
	end
	local icon = button.icon or button
	local frame = button.lbCount
	frame:ClearAllPoints()
	frame:SetAllPoints(icon)
	if frame.SetFrameLevel and button.GetFrameLevel then
		frame:SetFrameLevel(button:GetFrameLevel() + 2)
	end
	local text = button.lbCountText
	text:ClearAllPoints()
	text:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
end

local function ItemCount(payload)
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(payload)
	end
	if type(GetItemCount) == "function" then
		return GetItemCount(payload)
	end
	return nil
end

local function RestoreIcon(icon)
	if icon and icon.SetDesaturated then
		icon:SetDesaturated(false)
	end
	if icon and icon.SetVertexColor then
		icon:SetVertexColor(1, 1, 1)
	end
end

local function PaintItemCount(button, record)
	PlaceCount(button)
	local text = button.lbCountText
	local icon = button.icon
	if not record or record.kind ~= "item" then
		text:SetText("")
		RestoreIcon(icon)
		return
	end
	local count = ItemCount(record.payload)
	local secret = type(issecretvalue) == "function" and issecretvalue(count)
	if secret then
		text:SetText(count)
		text:SetTextColor(1, 1, 1)
		return
	end
	local look = Logic.ItemCountLook(count)
	if not look then
		text:SetText("")
		RestoreIcon(icon)
		return
	end
	text:SetText(look.text)
	text:SetTextColor(look.r, look.g, look.b)
	if icon and icon.SetDesaturated then
		icon:SetDesaturated(look.desaturate)
	end
	if icon and icon.SetVertexColor then
		icon:SetVertexColor(look.vertexR, look.vertexG, look.vertexB)
	end
end

local ApplyRecordCooldown
local RefreshLayoutChrome

local function ApplyActionOverlay(button)
	if not button then
		return
	end
	RaiseCooldown(button)
	local record = Find(button.lbKind or "spell", button.lbSlot)
	if record then
		ApplyRecordCooldown(button, record)
	end
	PaintItemCount(button, record)
end

local function ButtonLayout(button)
	local width
	local height
	if type(button.GetWidth) == "function" then
		width = button:GetWidth()
	end
	if type(button.GetHeight) == "function" then
		height = button:GetHeight()
	end
	return Logic.StockIconLayout(width, height)
end

local function WirePressFeedback(button, frameW, frameH, theme)
	local function hideGlow()
		if button.lbIconGlow then
			button.lbIconGlow:Hide()
		end
		if button.lbIconPress then
			button.lbIconPress:Hide()
		end
	end
	if Logic.PressFeedback(theme) ~= "icon" then
		hideGlow()
		if button.SetPushedAtlas then
			button:SetPushedAtlas(Logic.STOCK_PUSHED_ATLAS)
			FitStockFrame(button:GetPushedTexture(), frameW, frameH, "pushed")
		end
		if button.SetHighlightAtlas then
			button:SetHighlightAtlas(Logic.STOCK_HIGHLIGHT_ATLAS)
			FitStockFrame(button:GetHighlightTexture(), frameW, frameH, "highlight")
		end
		return
	end
	local icon = button.icon
	if not icon then
		hideGlow()
		return
	end
	local function copyFace(from, to)
		local atlas
		if type(from.GetAtlas) == "function" then
			atlas = from:GetAtlas()
		end
		if type(atlas) == "string" and atlas ~= "" and type(to.SetAtlas) == "function" then
			to:SetAtlas(atlas)
			return true
		end
		if type(from.GetTexture) == "function" and type(to.SetTexture) == "function" then
			local texture = from:GetTexture()
			if texture then
				to:SetTexture(texture)
				return true
			end
		end
		return false
	end
	local function placeGlow(tex, alpha)
		local inset = Logic.ICON_GLOW_INSET
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
		tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
		if tex.SetBlendMode then
			tex:SetBlendMode("ADD")
		end
		tex:SetAlpha(alpha)
		tex:Show()
	end
	if not button.lbIconGlow then
		button.lbIconGlow = button:CreateTexture(nil, "HIGHLIGHT")
	end
	if not copyFace(icon, button.lbIconGlow) and button.lbIconGlow.SetColorTexture then
		button.lbIconGlow:SetColorTexture(1, 0.95, 0.8, 1)
	end
	placeGlow(button.lbIconGlow, Logic.ICON_GLOW_ALPHA)
	if not button.lbIconPress then
		button.lbIconPress = button:CreateTexture(nil, "OVERLAY")
	end
	if not copyFace(icon, button.lbIconPress) and button.lbIconPress.SetColorTexture then
		button.lbIconPress:SetColorTexture(1, 0.95, 0.8, 1)
	end
	placeGlow(button.lbIconPress, Logic.ICON_PRESS_ALPHA)
	if button.SetPushedTexture then
		button:SetPushedTexture(button.lbIconPress)
		placeGlow(button.lbIconPress, Logic.ICON_PRESS_ALPHA)
	end
end

local function ShowStockSlot(button, shown)
	if shown and not button.lbSlotArt then
		button.lbSlotArt = button:CreateTexture(nil, "BACKGROUND", nil, -1)
		button.lbSlotArt:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
		button.lbSlotArt:SetAllPoints(button)
	end
	if button.lbSlotArt then
		button.lbSlotArt:SetShown(shown)
	end
end

local function PaintStockAction(button, icon)
	HideChrome(button)
	local iconW, iconH, frameW, frameH, maskW, maskH = ButtonLayout(button)
	ShowStockSlot(button, true)
	button.icon:Show()
	button.icon:SetDrawLayer("BACKGROUND", 1)
	button.icon:ClearAllPoints()
	button.icon:SetPoint("CENTER", 0, 0)
	button.icon:SetSize(iconW, iconH)
	local texture = Logic.UsableTexture(icon)
	if texture then
		button.icon:SetTexture(texture)
	end
	if button.border then
		button.border:Hide()
	end
	if button.SetNormalAtlas then
		button:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
		FitStockFrame(button:GetNormalTexture(), frameW, frameH, "normal")
	end
	WirePressFeedback(button, frameW, frameH)
	SetIconMask(button, true, maskW, maskH)
end

local function PaintThemedFace(button, paint, icon, theme)
	if paint.chrome == "micro" and paint.portrait and type(SetPortraitTexture) == "function" then
		if type(securecall) == "function" then
			securecall(SetPortraitTexture, button.icon, "player")
		else
			SetPortraitTexture(button.icon, "player")
		end
	elseif paint.chrome == "micro" and paint.normal and button.icon.SetAtlas then
		button.icon:SetAtlas(paint.normal)
	elseif paint.chrome == "bag" then
		button.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
	else
		local texture = Logic.UsableTexture(icon)
		if texture then
			button.icon:SetTexture(texture)
		end
	end
	ApplyChrome(button, Logic.ThemeSpec(theme))
	local _, _, frameW, frameH = ButtonLayout(button)
	WirePressFeedback(button, frameW, frameH, theme)
end

local function PaintFace(button, paint, icon, theme)
	theme = Logic.NormalizeTheme(theme or CurrentTheme())
	local chrome = paint.chrome
	local stock = Logic.StockTheme(theme)
	button.icon:ClearAllPoints()
	if button.icon.SetTexCoord then
		button.icon:SetTexCoord(0, 1, 0, 1)
	end
	SetIconMask(button, false)
	ShowStockSlot(button, false)
	ClearStateTextures(button)
	if button.lbIconGlow then
		button.lbIconGlow:Hide()
	end
	if button.lbIconPress then
		button.lbIconPress:Hide()
	end
	if stock and chrome == "micro" then
		HideChrome(button)
		local plate = MicroPlate(button)
		plate:Show()
		plate:SetAtlas(paint.plate, true)
		if paint.portrait and type(SetPortraitTexture) == "function" then
			button:SetPushedAtlas("UI-HUD-MicroMenu-ButtonBG-Down")
			button.icon:Show()
			button.icon:SetDrawLayer("OVERLAY", 1)
			button.icon:SetPoint("TOPLEFT", 7, -7)
			button.icon:SetPoint("BOTTOMRIGHT", -7, 7)
			SetPortraitTexture(button.icon, "player")
		else
			button.icon:Hide()
			button:SetNormalAtlas(paint.normal)
			button:SetPushedAtlas(paint.pushed)
			button:SetHighlightAtlas(paint.highlight)
			local normal = button:GetNormalTexture()
			if normal then
				normal:Show()
			end
		end
		if button.border then
			button.border:Hide()
		end
		AnchorCooldown(button)
		return
	end
	if button.plate then
		button.plate:Hide()
	end
	button.icon:Show()
	button.icon:SetDrawLayer("ARTWORK", 1)
	if stock and chrome == "bag" then
		HideChrome(button)
		button.icon:SetPoint("TOPLEFT", 4, -4)
		button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
		button.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
		if button.border then
			button.border:Show()
			button.border:SetAtlas("bag-border")
		end
		local _, _, frameW, frameH = ButtonLayout(button)
		WirePressFeedback(button, frameW, frameH)
		AnchorCooldown(button)
		return
	end
	if stock and chrome == "action" then
		PaintStockAction(button, icon)
		ApplyActionOverlay(button)
		return
	end
	PaintThemedFace(button, paint, icon, theme)
	if chrome == "action" then
		ApplyActionOverlay(button)
	else
		AnchorCooldown(button)
	end
end

local function RepaintPlaced()
	local buttons = DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		local button = ButtonFor(record)
		if button and button.IsShown and button:IsShown() then
			if record.kind == "launcher" then
				PaintFace(button, Logic.LauncherPaint(record), nil, ThemeOf(record))
			else
				PaintFace(button, { chrome = "action" }, record.icon, CurrentTheme())
			end
		end
	end
end

local function ApplyTheme(id)
	local live = DB()
	live.theme = Logic.NormalizeTheme(id)
	local theme = live.theme
	if LB.themeDropdown and LB.themeDropdown.SetDefaultText then
		LB.themeDropdown:SetDefaultText(Logic.THEMES[theme].title)
	end
	RepaintPlaced()
end

local function ApplyLauncherTheme(id)
	local theme = Logic.NormalizeTheme(id)
	DB().launcherTheme = theme
	if LB.launcherThemeDropdown and LB.launcherThemeDropdown.SetDefaultText then
		LB.launcherThemeDropdown:SetDefaultText(Logic.THEMES[theme].title)
	end
	RepaintPlaced()
end

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
	return nil
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

local function RefreshHotkey(button, record)
	if not button or not button.hotkeyText then
		return
	end
	local text = BindingKeyText(button) or (record and HotkeyString(record)) or nil
	if text then
		button.hotkeyText:SetText(text)
	else
		button.hotkeyText:SetText("")
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
	local button = ButtonFor(record)
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
local FinishDrop

-- Placed buttons sit above the spell drop layer, so a catalog spell released
-- over one lands here instead of on that layer.
local function ReceiveCatalogDrop()
	if LB.dragSpell or LB.dragLauncher then
		FinishDrop()
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
	Say("Press a key. Escape clears the bind.")
end

local function BindingFromKey(key)
	if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
		return nil
	end
	if key == "ESCAPE" then
		return "CLEAR"
	end
	if not key or key == "UNKNOWN" then
		return nil
	end
	local parts = {}
	if IsAltKeyDown() then
		table.insert(parts, "ALT")
	end
	if IsControlKeyDown() then
		table.insert(parts, "CTRL")
	end
	if IsShiftKeyDown() then
		table.insert(parts, "SHIFT")
	end
	table.insert(parts, key)
	return table.concat(parts, "-")
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
		local record = Find(button.lbKind or "spell", button.lbSlot)
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
	if record.kind == "spell" and type(payload) == "number" and type(GameTooltip.SetSpellByID) == "function" then
		if GameTooltip:SetSpellByID(payload) ~= false then
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
		name = Describe(record)
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
		ShowTip(self, Find(self.lbKind or "spell", self.lbSlot))
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
			if show and button and button.lbKind ~= "launcher" and not InCombatLockdown() then
				button:SetAttribute("type", "")
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

local function BindHovered(button, key)
	local binding = BindingFromKey(key)
	local command = button and button.commandName
	if not binding or not command or InCombatLockdown() then
		return
	end
	local old = { GetBindingKey(command) }
	local i
	for i = 1, #old do
		SetBinding(old[i])
	end
	if binding ~= "CLEAR" then
		SetBinding(binding, command)
	end
	SaveBindings(GetCurrentBindingSet())
	RefreshHotkey(button, Find(button.lbKind or "spell", button.lbSlot))
	button:QuickKeybindButtonSetTooltip()
end

keys:SetScript("OnKeyDown", function(self, key)
	BindHovered(self.button, key)
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
		Say("Cannot bind in combat.")
		return
	end
	LB.binding = true
	HideTips()
	if type(SetOverrideBindingClick) == "function" then
		SetOverrideBindingClick(endBindButton, true, "ESCAPE", endBindButton:GetName(), "LeftButton")
	end
	SyncQuickKeybind(true)
	Say("Hover a loose button and press a key. Escape clears it. Click Edit or press Escape elsewhere to finish.")
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
		local record = Find(self.lbKind or "spell", self.lbSlot)
		RefreshHotkey(self, record)
	end
	button.QuickKeybindButtonOnClick = function(self, mouseButton)
		local number = mouseButton == "MiddleButton" and 3 or tonumber(string.match(mouseButton or "", "^Button(%d+)$"))
		if number and keys:IsShown() and keys.button == self then
			BindHovered(self, "BUTTON" .. number)
		end
	end
end

local function NewFace(parent, name, template)
	local button = CreateFrame("Button", name, parent, template)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetPoint("CENTER")
	button.border:SetSize(46, 45)
	button:SetMovable(true)
	button:RegisterForDrag("LeftButton")
	button:SetClampedToScreen(true)
	AttachHotkey(button)
	EnsureQuickKeybind(button, name)
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
	end
	button:Hide()
end

ApplyRecordCooldown = function(button, record)
	local cooldown = button and button.cooldown
	if not cooldown or not record then
		return
	end
	if record.kind == "spell" and C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
		local duration = C_Spell.GetSpellCooldownDuration(record.payload)
		local secret = type(issecretvalue) == "function" and issecretvalue(duration)
		if secret or duration then
			cooldown:SetCooldownFromDurationObject(duration)
		end
		return
	end
	if record.kind == "item" and C_Item and C_Item.GetItemCooldown and cooldown.SetCooldown then
		local start, duration, enable = C_Item.GetItemCooldown(record.payload)
		local secret = type(issecretvalue) == "function" and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(enable))
		if secret or enable then
			cooldown:SetCooldown(start, duration)
		elseif cooldown.Clear then
			cooldown:Clear()
		end
	end
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
		button:SetSize(Logic.ButtonExtent(record, ScaleOf(record)))
		PaintFace(button, paint, nil, ThemeOf(record))
	else
		button:SetSize(Logic.ButtonExtent(record, ScaleOf(record)))
		if record.kind == "spell" then
			button:SetAttribute("type", "spell")
			button:SetAttribute("spell", tostring(record.payload))
			button:SetAttribute("item", "")
			button:SetAttribute("macro", "")
		elseif record.kind == "item" then
			local item = Logic.ItemUseAttribute(record.payload)
			button:SetAttribute("type", "item")
			button:SetAttribute("item", item or "")
			button:SetAttribute("spell", "")
			button:SetAttribute("macro", "")
		else
			button:SetAttribute("type", "macro")
			button:SetAttribute("macro", tostring(record.payload))
			button:SetAttribute("spell", "")
			button:SetAttribute("item", "")
		end
		button:SetAttribute("*type2", "")
		local holds = Logic.CastHoldPrefixes()
		local hold
		for hold = 1, #holds do
			button:SetAttribute(holds[hold] .. "type1", "")
		end
		if KeybindOpen() then
			button:SetAttribute("type", "")
		end
		local texture = Logic.PlacedTexture(record, IconFor)
		if texture then
			record.icon = texture
		end
		if record.kind == "spell" and record.class == nil and SpellInBook(record.payload) then
			record.class = PlayerClass()
		end
		PaintFace(button, { chrome = "action" }, texture, CurrentTheme())
	end
	button:Show()
	ApplyKey(button, record)
	RefreshHotkey(button, record)
	SetActionClicks(button)
end

local function ApplyAll()
	if not LB.poolReady or InCombatLockdown() then
		return
	end
	local usedAction = {}
	local usedLauncher = {}
	local buttons = DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		local button = ButtonFor(record)
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
	LB.hiddenIds = HiddenIds()
end
LB.ApplyAll = ApplyAll

local function RefreshPortraits()
	if type(SetPortraitTexture) ~= "function" then
		return
	end
	if LB.poolReady then
		local buttons = DB().buttons
		local i
		for i = 1, #buttons do
			local record = buttons[i]
			if record.kind == "launcher" and Logic.LauncherPaint(record).portrait then
				local button = ButtonFor(record)
				if button and button.icon and button:IsShown() then
					if type(securecall) == "function" then
						securecall(SetPortraitTexture, button.icon, "player")
					else
						SetPortraitTexture(button.icon, "player")
					end
				end
			end
		end
	end
	local rows = LB.catalogButtons
	local i
	for i = 1, #rows do
		local row = rows[i]
		if row:IsShown() and row.entry and row.entry.portrait and row.icon then
			if type(securecall) == "function" then
				securecall(SetPortraitTexture, row.icon, "player")
			else
				SetPortraitTexture(row.icon, "player")
			end
		end
	end
end

local function RefreshHotkeys()
	if not LB.poolReady then
		return
	end
	local buttons = DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		RefreshHotkey(ButtonFor(record), record)
	end
end

local function RemoveRecord(kind, poolSlot)
	if InCombatLockdown() then
		Say("Cannot remove a button in combat.")
		return
	end
	local record, index = Find(kind, poolSlot)
	if not index then
		return
	end
	if record then
		Logic.Detach(DB().buttons, record.id)
	end
	table.remove(DB().buttons, index)
	local button = Logic.Pool(kind) == "launcher" and LB.launchers[poolSlot] or LB.actions[poolSlot]
	HideSlot(button, kind)
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
	local prefixIndex
	for prefixIndex = 1, #ACTION_BUTTON_PREFIXES do
		local prefix = ACTION_BUTTON_PREFIXES[prefixIndex]
		local i
		for i = 1, 12 do
			local button = _G[prefix .. i]
			if button and button.IsVisible and button.IsMouseOver and button:IsVisible() and button:IsMouseOver() then
				return button
			end
		end
	end
	return nil
end

local function PlaceIntoAction(button, kind, payload)
	if InCombatLockdown() or type(PlaceAction) ~= "function" or not button then
		return false
	end
	local slot = button.action
	if type(slot) ~= "number" then
		return false
	end
	if kind == "spell" and C_Spell and C_Spell.PickupSpell then
		C_Spell.PickupSpell(payload)
	elseif kind == "item" and C_Item and C_Item.PickupItem then
		C_Item.PickupItem(payload)
	elseif kind == "macro" and type(PickupMacro) == "function" then
		PickupMacro(payload)
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
	local live = DB()
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
	local list = DB().buttons
	Logic.Reflow(list, function(record)
		return Logic.ButtonExtent(record, ScaleOf(record))
	end)
	local i
	for i = 1, #list do
		local record = list[i]
		local button = ButtonFor(record)
		if button then
			button:SetSize(Logic.ButtonExtent(record, ScaleOf(record)))
			PlaceButton(button, record)
		end
	end
end

local function ApplyLauncherScale(scale)
	scale = Logic.NormalizeScale(scale)
	DB().launcherScale = scale
	local slider = LB.launcherSlider
	if slider and slider.SetValue and not LB.launcherScaleWriting then
		LB.launcherScaleWriting = true
		slider:SetValue(Logic.ScalePercent(scale))
		LB.launcherScaleWriting = nil
	end
	ApplyScale(DB().scale)
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
			local record = Logic.RecordById(DB().buttons, shift.ids[i])
			local button = record and ButtonFor(record)
			if button then
				button:ClearAllPoints()
				button:SetPoint("CENTER", UIParent, "CENTER", record.x + shift.dx, record.y + shift.dy)
				pushed[record.id] = true
			end
		end
	end
	local id
	for id in pairs(LB.previewShift) do
		local record = not pushed[id] and Logic.RecordById(DB().buttons, id)
		local button = record and ButtonFor(record)
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
		local record = Logic.RecordById(DB().buttons, ids[i])
		local button = record and ButtonFor(record)
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
		local record = Logic.RecordById(DB().buttons, moving.ids[i])
		local button = record and ButtonFor(record)
		if button and start and not InCombatLockdown() then
			button:ClearAllPoints()
			button:SetPoint("CENTER", UIParent, "CENTER", start.x + dx, start.y + dy)
		end
	end
	if moving.mode == "one" and Logic.DropIntent("loose", ActionButtonUnderCursor() ~= nil, moving.kind) == "action" then
		ClearSnapPlan()
		return
	end
	ShowSnapPlan(Logic.SnapPlan(DB().buttons, moving.movers, nx, ny, ScaleOf))
end

BeginDrag = function(button)
	if LB.moving or not button or InCombatLockdown() or KeybindOpen() or IsLocked() then
		return
	end
	local record = Find(button.lbKind or "spell", button.lbSlot)
	if not record or type(record.x) ~= "number" or type(record.y) ~= "number" then
		return
	end
	if type(GameTooltip) == "table" and type(GameTooltip.Hide) == "function" then
		GameTooltip:Hide()
	end
	local mode = Logic.DragMode(ModifierDown("IsShiftKeyDown"), ModifierDown("IsAltKeyDown"))
	if mode == "one" then
		Logic.Detach(DB().buttons, record.id)
	end
	local ids = { record.id }
	if mode == "group" then
		ids = Logic.Component(DB().buttons, record.id)
	end
	local starts = {}
	local movers = {}
	local i
	for i = 1, #ids do
		local member = Logic.RecordById(DB().buttons, ids[i])
		if member then
			starts[ids[i]] = { x = member.x, y = member.y }
			table.insert(movers, member)
		end
	end
	local cx, cy = CursorCenter()
	local savedType
	if button.lbKind ~= "launcher" and button.GetAttribute and button.SetAttribute then
		savedType = button:GetAttribute("type")
		if type(savedType) ~= "string" or savedType == "" then
			savedType = nil
		else
			button:SetAttribute("type", "")
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
	local leader = moving.leader
	Defer(function()
		LB.suppressClick = nil
		if not savedType or not leader or not leader.SetAttribute then
			return
		end
		if InCombatLockdown() then
			LB.pendingDragType = { button = leader, savedType = savedType }
			return
		end
		leader:SetAttribute("type", savedType)
	end)
	if InCombatLockdown() then
		return
	end
	local record = Find(button.lbKind or "spell", button.lbSlot)
	if not record then
		return
	end
	if moving.mode == "one" then
		local over = ActionButtonUnderCursor()
		if Logic.DropIntent("loose", over ~= nil, record.kind) == "action" and PlaceIntoAction(over, record.kind, record.payload) then
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
	local plan = Logic.Drop(DB().buttons, moving.id, moving.ids, nx, ny, ScaleOf)
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
	local ids = Logic.Component(DB().buttons, record.id)
	local i
	for i = 1, #ids do
		local member = Logic.RecordById(DB().buttons, ids[i])
		if member and ButtonFor(member) then
			RemoveRecord(member.kind, member.slot)
		end
	end
end

local function TryDelete(self)
	if KeybindOpen() or IsLocked() then
		return
	end
	local scope = Logic.DeleteScope(ModifierDown("IsShiftKeyDown"), ModifierDown("IsAltKeyDown"))
	if not scope then
		return
	end
	if InCombatLockdown() then
		Say("Cannot remove a button in combat.")
		return
	end
	local record = Find(self.lbKind or "spell", self.lbSlot)
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
		if mouseButton ~= "LeftButton" or InCombatLockdown() or KeybindOpen() or IsLocked() then
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
	button:SetScript("OnReceiveDrag", ReceiveCatalogDrop)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		if self.lbKind ~= "launcher" then
			PaintFace(self, { chrome = "action" }, nil)
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
		RaiseCooldown(button)
		button.lbKind = "spell"
		button.lbSlot = i
		WireDrag(button)
		AttachTooltip(button)
		LB.actions[i] = button
	end
	for i = 1, Logic.LAUNCHER_SLOTS do
		local name = Logic.FrameName("launcher", i)
		local button = NewFace(UIParent, name, nil)
		button:SetSize(32, 40)
		button:Hide()
		button:RegisterForClicks(Logic.ClickRegistration("launcher"))
		button.lbKind = "launcher"
		button.lbSlot = i
		button:SetScript("OnClick", function(self, mouseButton)
			if mouseButton == "RightButton" then
				return
			end
			if LB.suppressClick then
				return
			end
			if KeybindOpen() then
				return
			end
			local record = Find("launcher", self.lbSlot)
			if record then
				RunLauncher(record)
			end
		end)
		WireDrag(button)
		AttachTooltip(button)
		LB.launchers[i] = button
	end
	LB.poolReady = true
	ApplyAll()
	return true
end

local function Place(kind, payload, x, y, icon)
	if kind ~= "spell" and kind ~= "item" and kind ~= "macro" and kind ~= "launcher" then
		return
	end
	icon = Logic.UsableTexture(icon)
	if InCombatLockdown() then
		LB.pending = { kind = kind, payload = payload, x = x, y = y, icon = icon }
		Say("Will place that after combat.")
		return
	end
	if not EnsurePool() then
		LB.pending = { kind = kind, payload = payload, x = x, y = y, icon = icon }
		return
	end
	local list = DB().buttons
	local poolSlot = Logic.NextSlot(list, kind)
	if not poolSlot then
		Say("That row is full.")
		return
	end
	local _, claimed = Logic.Layouts.Claim(Account(), CharKey(), LB.charName)
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
		record.class = PlayerClass()
	end
	table.insert(list, record)
	local plan = Logic.Drop(list, record.id, { record.id }, x, y, ScaleOf)
	Configure(ButtonFor(record), record)
	if plan and plan.shift then
		PlaceIds(plan.shift.ids)
	end
	if claimed then
		RefreshLayoutChrome()
	end
end

local function ResetAll()
	if InCombatLockdown() then
		Say("Cannot reset in combat.")
		return
	end
	DB().buttons = {}
	if LB.poolReady then
		ApplyAll()
	end
	Say("Removed every button.")
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
		Say("Cannot reset in combat.")
		return
	end
	StaticPopup_Show("LOOSEBUTTONS_CLEAR_ALL")
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
		self.record.key = binding
		ApplyKey(self.button, self.record)
		RefreshHotkey(self.button, self.record)
	end
	self:Hide()
end)

local receive = CreateFrame("Frame", "LooseButtonsReceive", UIParent)
receive:SetAllPoints(UIParent)
receive:SetFrameStrata("FULLSCREEN")
receive:EnableMouse(true)
receive:Hide()

local function CatalogMover()
	if LB.dragLauncher then
		return { id = "catalog", kind = "launcher", chrome = LB.dragLauncher.chrome }
	end
	if LB.dragSpell then
		return { id = "catalog", kind = LB.dragSpell.kind }
	end
	return nil
end

local function PreviewCatalogDrop()
	local mover = CatalogMover()
	local x, y = CursorCenter()
	if not mover or not x or OverBook() or ActionButtonUnderCursor() then
		ClearSnapPlan()
		return
	end
	ShowSnapPlan(Logic.SnapPlan(DB().buttons, { mover }, x, y, ScaleOf))
end

receive:SetScript("OnHide", ClearSnapPlan)
receive:SetScript("OnUpdate", function(self)
	if not self:IsShown() then
		return
	end
	PreviewCatalogDrop()
	self:EnableMouse(true)
end)

local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetSize(32, 40)
ghost:SetFrameStrata("TOOLTIP")
ghost:Hide()
ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
ghost.icon:SetAllPoints()
ghost:SetScript("OnUpdate", function(self)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	if not scale or scale == 0 then
		scale = 1
	end
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end)

local function HideGhost()
	ghost:Hide()
	LB.dragLauncher = nil
end

local function ShowSpellGhost(icon)
	local texture = Logic.UsableTexture(icon)
	if texture and ghost.icon.SetTexture then
		ghost.icon:SetTexture(texture)
	end
	ghost:Show()
end

local function ShowReceive(aboveUi)
	receive:SetFrameStrata(aboveUi and "FULLSCREEN" or "LOW")
	receive:EnableMouse(true)
	receive:Show()
end

local function HideReceive()
	receive:Hide()
	HideGhost()
end

local dropBusy = false
FinishDrop = function()
	if dropBusy then
		return
	end
	dropBusy = true
	local kind, payload, icon
	if LB.dragLauncher then
		kind = "launcher"
		payload = LB.dragLauncher.payload
		icon = LB.dragLauncher.icon
	elseif LB.dragSpell then
		kind = LB.dragSpell.kind
		payload = LB.dragSpell.payload
		icon = LB.dragSpell.icon
		LB.dragSpell = nil
	else
		HideReceive()
		dropBusy = false
		return
	end
	local over = ActionButtonUnderCursor()
	local intent = Logic.DropIntent("catalog", over ~= nil, kind)
	if intent == "action" then
		PlaceIntoAction(over, kind, payload)
		if ClearCursor then
			ClearCursor()
		end
		HideReceive()
		dropBusy = false
		return
	end
	if intent == "cancel" then
		HideReceive()
		dropBusy = false
		return
	end
	local onBook = OverBook()
	local x, y = CursorCenter()
	if ClearCursor then
		ClearCursor()
	end
	HideReceive()
	if not onBook and x then
		Place(kind, payload, x, y, icon)
	end
	dropBusy = false
end

receive:SetScript("OnReceiveDrag", FinishDrop)
receive:SetScript("OnMouseUp", function(_, mouseButton)
	if mouseButton == "RightButton" and not LB.dragLauncher then
		LB.dragSpell = nil
		if ClearCursor then
			ClearCursor()
		end
		HideReceive()
		return
	end
	FinishDrop()
end)

local function BeginLauncherDrag(entry)
	LB.dragLauncher = entry
	if entry.portrait and type(SetPortraitTexture) == "function" then
		SetPortraitTexture(ghost.icon, "player")
	elseif entry.atlas and ghost.icon.SetAtlas then
		ghost.icon:SetAtlas("UI-HUD-MicroMenu-" .. entry.atlas .. "-Up")
	elseif entry.chrome == "bag" then
		ghost.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
	end
	ghost:Show()
	ShowReceive(true)
end

local function UpdateCooldowns()
	if not LB.poolReady then
		return
	end
	local i
	for i = 1, Logic.ACTION_SLOTS do
		local button = LB.actions[i]
		local record = Find("spell", i)
		if button and button:IsShown() and record and (record.kind == "spell" or record.kind == "item") then
			ApplyActionOverlay(button)
		end
	end
end

local function SpellAt(index)
	if not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo or not Enum or not Enum.SpellBookSpellBank then
		return nil
	end
	local info = C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
	if not info then
		return nil
	end
	local isSpell = Enum.SpellBookItemType and info.itemType == Enum.SpellBookItemType.Spell
	local actionID = info.actionID
	local spellID = info.spellID
	if type(spellID) ~= "number" then
		spellID = actionID
	end
	if type(actionID) ~= "number" then
		actionID = spellID
	end
	return {
		spellID = actionID,
		baseSpellID = type(info.spellID) == "number" and info.spellID or nil,
		name = info.name,
		iconID = info.iconID,
		isSpell = isSpell and true or false,
		isPassive = info.isPassive and true or false,
		isOffSpec = info.isOffSpec and true or false,
	}
end

local function SkillLines()
	local lines = {}
	if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines then
		return lines
	end
	local count = C_SpellBook.GetNumSpellBookSkillLines()
	local i
	for i = 1, count do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
		if info then
			table.insert(lines, {
				name = info.name,
				shouldHide = info.shouldHide and true or false,
				offSpecID = info.offSpecID,
				itemIndexOffset = info.itemIndexOffset,
				numSpellBookItems = info.numSpellBookItems,
			})
		end
	end
	return lines
end

local function BindingExists(command)
	if type(GetBindingIndex) ~= "function" then
		return false
	end
	local index = GetBindingIndex(command)
	return type(index) == "number" and index > 0
end

local function ApplySpellbookColor(fontString)
	local color = SPELLBOOK_FONT_COLOR
	if not fontString or not fontString.SetTextColor or type(color) ~= "table" then
		return
	end
	local r, g, b = color.r, color.g, color.b
	if not r and color.GetRGB then
		r, g, b = color:GetRGB()
	end
	if r and g and b then
		fontString:SetTextColor(r, g, b)
	end
end

local function PaintCatalogIcon(icon, entry)
	if entry.portrait and type(SetPortraitTexture) == "function" then
		SetPortraitTexture(icon, "player")
		return
	end
	if entry.atlas and icon.SetAtlas then
		icon:SetAtlas("UI-HUD-MicroMenu-" .. entry.atlas .. "-Up")
		return
	end
	if entry.chrome == "bag" then
		icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
		return
	end
	local texture = Logic.UsableTexture(entry.icon)
	if texture then
		icon:SetTexture(texture)
	end
end

local function plainNumber(value)
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return nil
	end
	if type(value) == "number" and value == math.floor(value) then
		return value
	end
	return nil
end

local function plainString(value)
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return nil
	end
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function ConsumableRow(info)
	local itemID = type(info) == "table" and plainNumber(info.itemID) or nil
	if not itemID or type(C_Item) ~= "table" or type(C_Item.GetItemInfoInstant) ~= "function" or type(C_Item.GetItemSpell) ~= "function" then
		return nil
	end
	local _, _, _, _, instantIcon, classID = C_Item.GetItemInfoInstant(itemID)
	classID = plainNumber(classID)
	local spellName, spellID = C_Item.GetItemSpell(itemID)
	local hasUse = false
	if type(issecretvalue) == "function" and (issecretvalue(spellName) or issecretvalue(spellID)) then
		hasUse = true
	elseif plainNumber(spellID) or plainString(spellName) then
		hasUse = true
	end
	if not hasUse or classID ~= Logic.ITEM_CLASS_CONSUMABLE then
		return nil
	end
	local icon = plainNumber(info.iconFileID)
	if not icon then
		icon = plainNumber(instantIcon)
	end
	return {
		itemID = itemID,
		name = plainString(info.itemName),
		icon = icon,
		classID = classID,
		spellID = true,
	}
end

local function BagConsumables()
	if type(C_Container) ~= "table" or type(C_Container.GetContainerNumSlots) ~= "function" or type(C_Container.GetContainerItemInfo) ~= "function" then
		return {}
	end
	local rows = {}
	local bag
	for bag = 0, 5 do
		local slots = plainNumber(C_Container.GetContainerNumSlots(bag))
		if slots and slots > 0 then
			local slot
			for slot = 1, slots do
				local ok, row = pcall(function()
					return ConsumableRow(C_Container.GetContainerItemInfo(bag, slot))
				end)
				if ok and type(row) == "table" then
					table.insert(rows, row)
				end
			end
		end
	end
	return Logic.ConsumableEntries(rows)
end

local function HideSectionScale(header)
	if header.check then
		header.check:Hide()
	end
	if header.checkLabel then
		header.checkLabel:Hide()
	end
	if header.sectionSlider then
		header.sectionSlider:Hide()
	end
	if header.themeCheck then
		header.themeCheck:Hide()
	end
	if header.themeCheckLabel then
		header.themeCheckLabel:Hide()
	end
	if header.sectionTheme then
		header.sectionTheme:Hide()
	end
end

local function EnsureCheckLabel(header, key, text)
	local label = header[key]
	if label then
		return label
	end
	label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetText(text)
	ApplySpellbookColor(label)
	header[key] = label
	return label
end

local function ShowSectionScale(header)
	if not header.check then
		local check = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
		check:SetSize(26, 26)
		check:SetScript("OnClick", function(self)
			DB().launcherScaleSeparate = self:GetChecked() and true or false
			if header.sectionSlider then
				header.sectionSlider:SetShown(DB().launcherScaleSeparate)
			end
			ApplyScale(CurrentScale())
		end)
		header.check = check
		EnsureCheckLabel(header, "checkLabel", "Scale")
		local slider = CreateFrame("Frame", nil, header, "MinimalSliderWithSteppersTemplate")
		slider:SetSize(Logic.SECTION_STACK.sliderW, Logic.SECTION_STACK.sliderH)
		local label = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
		if slider.Init and label then
			local formatters = {}
			formatters[label.Top] = function(value)
				if type(value) ~= "number" then
					return ""
				end
				return math.floor(value + 0.5) .. "%"
			end
			slider:Init(Logic.ScalePercent(DB().launcherScale), Logic.SCALE_MIN_PERCENT, Logic.SCALE_MAX_PERCENT, Logic.SCALE_STEPS, formatters)
		end
		local function OnChanged(_, value)
			if LB.launcherScaleWriting then
				return
			end
			local percent = Logic.ScaleFromSlider(slider, value)
			if type(percent) ~= "number" then
				return
			end
			ApplyLauncherScale(percent / 100)
		end
		local inner = slider.Slider
		if type(inner) == "table" and type(inner.HookScript) == "function" then
			inner:HookScript("OnValueChanged", OnChanged)
		elseif type(slider.HookScript) == "function" then
			slider:HookScript("OnValueChanged", OnChanged)
		end
		header.sectionSlider = slider
	end
	if not header.themeCheck then
		local themeCheck = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
		themeCheck:SetSize(26, 26)
		themeCheck:SetScript("OnClick", function(self)
			DB().launcherThemeSeparate = self:GetChecked() and true or false
			if header.sectionTheme then
				header.sectionTheme:SetShown(DB().launcherThemeSeparate)
			end
			RepaintPlaced()
		end)
		header.themeCheck = themeCheck
		EnsureCheckLabel(header, "themeCheckLabel", "Theme")
		local dropdown = CreateFrame("DropdownButton", nil, header, "WowStyle1DropdownTemplate")
		dropdown:SetSize(Logic.SECTION_STACK.dropW, Logic.SECTION_STACK.dropH)
		local theme = Logic.NormalizeTheme(DB().launcherTheme)
		if dropdown.SetDefaultText then
			dropdown:SetDefaultText(Logic.THEMES[theme].title)
		end
		if MenuUtil and MenuUtil.CreateRadioMenu then
			local rows = {}
			local i
			for i = 1, #Logic.THEME_ORDER do
				local id = Logic.THEME_ORDER[i]
				rows[i] = { Logic.THEMES[id].title, id }
			end
			MenuUtil.CreateRadioMenu(dropdown, function(id)
				return Logic.NormalizeTheme(DB().launcherTheme) == id
			end, function(id)
				ApplyLauncherTheme(id)
			end, unpack(rows))
		end
		header.sectionTheme = dropdown
	end
	local scaleLabel = EnsureCheckLabel(header, "checkLabel", "Scale")
	local themeLabel = EnsureCheckLabel(header, "themeCheckLabel", "Theme")
	local stack = Logic.SECTION_STACK
	header.check:Show()
	header.check:ClearAllPoints()
	header.check:SetPoint("TOPLEFT", header.text, "BOTTOMLEFT", 0, -stack.sliderCap)
	if header.check.SetChecked then
		header.check:SetChecked(DB().launcherScaleSeparate)
	end
	scaleLabel:Show()
	scaleLabel:ClearAllPoints()
	scaleLabel:SetPoint("LEFT", header.check, "RIGHT", stack.labelGap, 0)
	ApplySpellbookColor(scaleLabel)
	local slider = header.sectionSlider
	slider:ClearAllPoints()
	slider:SetPoint("LEFT", scaleLabel, "RIGHT", stack.controlGap, Logic.SectionSliderNudge())
	if slider.SetValue and not LB.launcherScaleWriting then
		LB.launcherScaleWriting = true
		slider:SetValue(Logic.ScalePercent(DB().launcherScale))
		LB.launcherScaleWriting = nil
	end
	slider:SetShown(DB().launcherScaleSeparate)
	LB.launcherSlider = slider
	local themeCheck = header.themeCheck
	themeCheck:Show()
	themeCheck:ClearAllPoints()
	themeCheck:SetPoint("TOPLEFT", header.check, "TOPLEFT", 0, Logic.SectionThemeOffset())
	if themeCheck.SetChecked then
		themeCheck:SetChecked(DB().launcherThemeSeparate)
	end
	themeLabel:Show()
	themeLabel:ClearAllPoints()
	themeLabel:SetPoint("LEFT", themeCheck, "RIGHT", stack.labelGap, 0)
	ApplySpellbookColor(themeLabel)
	local dropdown = header.sectionTheme
	dropdown:ClearAllPoints()
	dropdown:SetPoint("LEFT", themeLabel, "RIGHT", stack.controlGap, 0)
	local theme = Logic.NormalizeTheme(DB().launcherTheme)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(Logic.THEMES[theme].title)
	end
	dropdown:SetShown(DB().launcherThemeSeparate)
	LB.launcherThemeDropdown = dropdown
end

local function LayoutCatalog(items, scheduleItems)
	local page = LB.page
	if not page then
		return
	end
	local content = page.content
	local width = page.scroll:GetWidth()
	if not width or width < 40 then
		width = page:GetWidth()
	end
	if not width or width < 40 then
		width = 680
	end
	local columns = 3
	if width > 1000 then
		columns = 6
	end
	local rowH = 60
	local yGap = 10
	local xPad = 15
	local headerH = Logic.SECTION_STACK.plain
	local pad = Logic.CatalogTextLeft()
	local inner = width - pad * 2
	if inner < 40 then
		inner = width
		pad = 0
	end
	local colWidth = math.floor((inner - xPad * (columns - 1)) / columns)
	if colWidth < 40 then
		colWidth = 40
	end
	local sections = Logic.BuildSections(SkillLines(), SpellAt, Logic.VisibleLaunchers(BindingExists), items, Logic.Macros(_G))
	local y = 0
	local col = 0
	local buttonIndex = 0
	local headerIndex = 0
	local s
	for s = 1, #sections do
		local section = sections[s]
		if col ~= 0 then
			y = y + rowH + yGap
			col = 0
		end
		headerIndex = headerIndex + 1
		local header = LB.catalogHeaders[headerIndex]
		if not header then
			header = CreateFrame("Frame", nil, content)
			header.backplate = header:CreateTexture(nil, "BACKGROUND")
			header.backplate:SetAtlas("spellbook-list-backplate", true)
			header.backplate:SetAlpha(0.65)
			header.backplate:SetAllPoints(header)
			header.text = header:CreateFontString(nil, "OVERLAY", "SystemFont_Huge2")
			header.text:SetJustifyH("LEFT")
			header.divider = header:CreateTexture(nil, "ARTWORK")
			header.divider:SetAtlas("spellbook-divider", true)
			header.divider:SetHeight(Logic.SECTION_STACK.divider)
			header.divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
			header.divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
			LB.catalogHeaders[headerIndex] = header
		end
		headerH = Logic.CatalogHeaderHeight(section.title)
		header:ClearAllPoints()
		header:SetSize(inner, headerH)
		header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -y)
		header.text:ClearAllPoints()
		local textY = -4
		if section.title == Logic.SECTION_ORDER[1] then
			textY = Logic.SectionHeaderInset()
		end
		header.text:SetPoint("TOPLEFT", header, "TOPLEFT", pad, textY)
		header.text:SetText(section.title)
		ApplySpellbookColor(header.text)
		if section.title == Logic.SECTION_ORDER[1] then
			ShowSectionScale(header)
		else
			header.text:SetPoint("TOPRIGHT", header, "TOPRIGHT", -pad, textY)
			HideSectionScale(header)
		end
		header:Show()
		y = y + headerH + yGap
		local e
		for e = 1, #section.entries do
			local entry = section.entries[e]
			if col >= columns then
				col = 0
				y = y + rowH + yGap
			end
			buttonIndex = buttonIndex + 1
			local row = LB.catalogButtons[buttonIndex]
			if not row then
				row = CreateFrame("Button", nil, content)
				row.lbCatalog = true
				row.backplate = row:CreateTexture(nil, "BACKGROUND")
				row.backplate:SetAtlas("spellbook-item-backplate", true)
				row.backplate:SetAlpha(0.33)
				row.backplate:SetPoint("CENTER", row, "CENTER", 5, -5)
				row.icon = row:CreateTexture(nil, "ARTWORK")
				row.icon:SetSize(40, 40)
				row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
				row.nameText = row:CreateFontString(nil, "OVERLAY", "SystemFont_Large")
				row.nameText:SetJustifyH("LEFT")
				row.nameText:SetPoint("LEFT", row, "LEFT", 50, 0)
				row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				row:RegisterForDrag("LeftButton")
				row:SetScript("OnDragStart", function(self)
					local dragged = self.entry
					if not dragged then
						return
					end
					if dragged.kind == "item" or dragged.kind == "macro" then
						LB.dragSpell = { kind = dragged.kind, payload = dragged.payload, icon = dragged.icon }
						ShowSpellGhost(dragged.icon)
						ShowReceive(true)
						return
					end
					if dragged.kind == "spell" then
						if InCombatLockdown() then
							Say("Cannot pick up a spell in combat.")
							return
						end
						LB.dragSpell = { kind = "spell", payload = dragged.payload, icon = dragged.icon }
						ShowSpellGhost(dragged.icon)
						ShowReceive(true)
						return
					end
					BeginLauncherDrag(dragged)
				end)
				row:SetScript("OnEnter", function(self)
					ShowTip(self, self.entry)
				end)
				row:SetScript("OnLeave", function()
					if type(GameTooltip) == "table" and type(GameTooltip.Hide) == "function" then
						GameTooltip:Hide()
					end
				end)
				LB.catalogButtons[buttonIndex] = row
			end
			row.entry = entry
			row:SetSize(colWidth, rowH)
			row.icon:SetSize(40, 40)
			PaintCatalogIcon(row.icon, entry)
			row.nameText:SetText(entry.name or "")
			ApplySpellbookColor(row.nameText)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", content, "TOPLEFT", pad + col * (colWidth + xPad), -y)
			row:Show()
			col = col + 1
		end
	end
	if col ~= 0 then
		y = y + rowH
	end
	local i
	for i = headerIndex + 1, #LB.catalogHeaders do
		LB.catalogHeaders[i]:Hide()
	end
	for i = buttonIndex + 1, #LB.catalogButtons do
		LB.catalogButtons[i]:Hide()
	end
	content:SetSize(width, math.max(y + 12, 40))
	page.scroll:SetVerticalScroll(0)
	if not scheduleItems or LB.itemScanQueued then
		return
	end
	LB.itemScanQueued = true
	local function finishItems()
		LB.itemScanQueued = false
		if not LB.page or not LB.page:IsShown() then
			return
		end
		local ok, scanned = pcall(BagConsumables)
		if ok and type(scanned) == "table" then
			LayoutCatalog(scanned, false)
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, finishItems)
	else
		finishItems()
	end
end

local function ClearBlizzardPage(book)
	local paged = book and book.PagedSpellsFrame
	if not paged then
		return
	end
	if paged.RemoveDataProvider then
		paged:RemoveDataProvider()
	end
	if paged.ViewFrames then
		local i
		for i = 1, #paged.ViewFrames do
			paged.ViewFrames[i]:Hide()
		end
	end
	if paged.PagingControls then
		paged.PagingControls:Hide()
	end
	paged:Hide()
end

local function RestoreBlizzardPage(book)
	local paged = book and book.PagedSpellsFrame
	if not paged then
		return
	end
	paged:Show()
	local views = paged.viewsPerPage or 1
	if paged.ViewFrames then
		local i
		for i = 1, #paged.ViewFrames do
			if i <= views then
				paged.ViewFrames[i]:Show()
			else
				paged.ViewFrames[i]:Hide()
			end
		end
	end
	if paged.PagingControls then
		paged.PagingControls:Show()
	end
end

local function AttachCatalogScroll(page)
	local scroll = CreateFrame("ScrollFrame", "LooseButtonsCatalogScroll", page)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(20, 20)
	scroll:SetScrollChild(content)
	scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 0)
	local bar = CreateFrame("EventFrame", "LooseButtonsCatalogBar", page, "WowTrimScrollBar")
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 28, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 28, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
	page.scroll = scroll
	page.content = content
end

local function PaintStripButton(button, texture)
	if not button.icon then
		if type(button.Icon) == "table" then
			button.icon = button.Icon
		else
			button.icon = button:CreateTexture(nil, "ARTWORK")
		end
	end
	ClearStateTextures(button)
	PaintStockAction(button, texture)
end

local function CenterLockIcon(button)
	local icon = button.Icon
	if type(icon) ~= "table" or not icon.ClearAllPoints then
		return
	end
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
end

local function CenterStripIcon(button)
	local icon = button.Icon
	if type(icon) ~= "table" or not icon.ClearAllPoints then
		return
	end
	local iconW, iconH = ButtonLayout(button)
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	if icon.SetSize then
		icon:SetSize(iconW, iconH)
	end
	if icon.SetTexCoord then
		icon:SetTexCoord(0, 1, 0, 1)
	end
end

local function RefreshLockButton()
	local button = LB.lockButton
	if not button then
		return
	end
	local locked = IsLocked()
	local art = Logic.LockArt(locked)
	if button.SetIcon then
		button:SetIcon(art)
	end
	PaintStripButton(button, art)
	CenterLockIcon(button)
	if button.SetButtonState then
		if locked then
			button:SetButtonState("PUSHED", true)
		else
			button:SetButtonState("NORMAL", false)
		end
	end
	if button.SetTooltipInfo then
		if locked then
			button:SetTooltipInfo("Unlock", "Buttons are locked. Click to move and snap them again.")
		else
			button:SetTooltipInfo("Lock", "Stop moving and snapping loose buttons.")
		end
	end
end

local function ToggleLock()
	local live = DB()
	live.locked = Logic.NormalizeLocked(not IsLocked())
	RefreshLockButton()
end

local function LayoutLabel()
	return Logic.Layouts.ActiveName(Account(), CharKey()) or Logic.BLANK_LAYOUT
end

RefreshLayoutChrome = function()
	RefreshLockButton()
	if LB.themeDropdown and LB.themeDropdown.SetDefaultText then
		LB.themeDropdown:SetDefaultText(Logic.THEMES[CurrentTheme()].title)
	end
	if LB.scaleSlider and LB.scaleSlider.SetValue then
		LB.scaleWriting = true
		LB.scaleSlider:SetValue(Logic.ScalePercent(CurrentScale()))
		LB.scaleWriting = nil
	end
	if LB.layoutDropdown and LB.layoutDropdown.SetDefaultText then
		LB.layoutDropdown:SetDefaultText(LayoutLabel())
	end
	if LB.layoutDropdown and LB.layoutDropdown.GenerateMenu then
		LB.layoutDropdown:GenerateMenu()
	end
	if LB.page and LB.page.IsShown and LB.page:IsShown() then
		LayoutCatalog(nil, true)
	end
end

local function PresentLayout()
	if LB.poolReady then
		ApplyAll()
	else
		EnsurePool()
	end
	RefreshLayoutChrome()
end

local function layoutLoadedText()
	local text = "Loaded. Quick Keybind keys stay on their slots."
	local buttons = DB().buttons
	local i
	for i = 1, #buttons do
		local row = buttons[i]
		if type(row) == "table" and row.kind == "macro" then
			return text .. " Macro buttons run this character's macro with the same name."
		end
	end
	return text
end

local function PopupEditText(dialog)
	if type(dialog) ~= "table" then
		return ""
	end
	if type(dialog.GetEditBox) == "function" then
		local box = dialog:GetEditBox()
		if type(box) == "table" and type(box.GetText) == "function" then
			local text = box:GetText()
			if type(text) == "string" then
				return text
			end
		end
	end
	if type(dialog.editBox) == "table" and type(dialog.editBox.GetText) == "function" then
		local text = dialog.editBox:GetText()
		if type(text) == "string" then
			return text
		end
	end
	return ""
end

local function NameIsBlank(text)
	return type(text) ~= "string" or string.match(text, "^[ \t]*$") ~= nil
end

local function CommitNew(typed)
	local created, detail = Logic.Layouts.Create(Account(), CharKey(), typed, nil, InCombatLockdown())
	if not created then
		Say(detail)
		return
	end
	RefreshLayoutChrome()
end

local function CommitImport(pasted, typed)
	local profile, sharedName = Logic.ShareCodec.Decode(pasted)
	if not profile then
		Say(sharedName)
		return
	end
	local name = typed
	if NameIsBlank(name) then
		name = sharedName
	end
	local created, detail = Logic.Layouts.Create(Account(), CharKey(), name, profile, InCombatLockdown())
	if not created then
		Say(detail)
		return
	end
	PresentLayout()
	Say(layoutLoadedText())
end

local function CommitDelete(name)
	local effect, detail = Logic.Layouts.Delete(Account(), CharKey(), name, InCombatLockdown())
	if not effect then
		Say(detail)
		return
	end
	if effect == "cleared" then
		PresentLayout()
		Say("Removed that layout.")
		return
	end
	RefreshLayoutChrome()
end

local function ConfirmDelete(name)
	if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
		CommitDelete(name)
		return
	end
	local dialog = StaticPopupDialogs["LOOSEBUTTONS_LAYOUT_DELETE"]
	dialog.text = Logic.Layouts.DeleteText(Account(), CharKey(), name)
	StaticPopup_Show("LOOSEBUTTONS_LAYOUT_DELETE", nil, nil, { name = name })
end

local function OpenNewLayout()
	if type(StaticPopup_Show) == "function" then
		StaticPopup_Show("LOOSEBUTTONS_LAYOUT_NAME")
		return
	end
	Say("Enter a name.")
end

local function BindEscape(box, frame)
	box:SetScript("OnEscapePressed", function(self)
		self:SetPropagateKeyboardInput(false)
		frame:Hide()
	end)
end

local function AttachDialogChrome(frame)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableKeyboard(true)
	frame:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			self:Hide()
			return
		end
		self:SetPropagateKeyboardInput(true)
	end)
	local drag = CreateFrame("Button", nil, frame)
	drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, 0)
	drag:SetHeight(28)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	drag:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
	end)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	local catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("DIALOG")
	catcher:EnableMouse(true)
	catcher:SetScript("OnClick", function()
		frame:Hide()
	end)
	catcher:Hide()
	frame:HookScript("OnShow", function()
		catcher:SetFrameLevel(1)
		frame:SetFrameLevel(20)
		catcher:Show()
	end)
	frame:HookScript("OnHide", function()
		catcher:Hide()
	end)
end

function LB.FitDialog(frame, bottom, pad, watched)
	local function fit()
		local top = frame:GetTop()
		local low = bottom:GetBottom()
		if type(top) ~= "number" or type(low) ~= "number" then
			return
		end
		-- Centered frame: a new height moves the top, and children move with it.
		local height = (top - low) + pad
		if height > frame:GetHeight() + 0.5 then
			frame:SetHeight(height)
		end
	end
	local function watch(widget)
		if type(widget) == "table" and type(widget.HookScript) == "function" then
			widget:HookScript("OnSizeChanged", fit)
		end
	end
	watch(bottom)
	if type(watched) == "table" then
		local i
		for i = 1, #watched do
			watch(watched[i])
		end
	end
	frame:HookScript("OnShow", fit)
	fit()
end

local function EnsureShareFrame()
	if LB.shareFrame then
		return LB.shareFrame
	end
	local frame = CreateFrame("Frame", "LooseButtonsShare", UIParent)
	frame:SetSize(420, 180)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.06, 0.05, 0.04, 0.94)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	title:SetText("Share")
	local box = CreateFrame("EditBox", nil, frame)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetSize(388, 90)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
	box:SetTextInsets(6, 6, 6, 6)
	box:SetMaxLetters(20000)
	local shareBg = box:CreateTexture(nil, "BACKGROUND")
	shareBg:SetAllPoints(box)
	shareBg:SetColorTexture(0, 0, 0, 0.45)
	local copy = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	copy:SetSize(164, 22)
	copy:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
	copy:SetText("Copy to Clipboard")
	copy:SetScript("OnClick", function()
		if InCombatLockdown() then
			Say("Leave combat to copy.")
			return
		end
		local text = box:GetText()
		if type(CopyToClipboard) ~= "function" then
			Say("Copy is not available.")
			return
		end
		CopyToClipboard(text)
	end)
	frame.box = box
	BindEscape(box, frame)
	AttachDialogChrome(frame)
	LB.FitDialog(frame, copy, 16, { box })
	frame:Hide()
	LB.shareFrame = frame
	return frame
end

local function OpenShare()
	local name = Logic.Layouts.ActiveName(Account(), CharKey())
	if not name then
		Say("Nothing to share yet.")
		return
	end
	local text, reason = Logic.ShareCodec.Encode(Logic.Profile(DB()), name)
	if not text then
		Say(reason)
		return
	end
	local frame = EnsureShareFrame()
	frame.box:SetText(text)
	frame:Show()
end

local function EnsureImportFrame()
	if LB.importFrame then
		return LB.importFrame
	end
	local frame = CreateFrame("Frame", "LooseButtonsImport", UIParent)
	frame:SetSize(420, 236)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.06, 0.05, 0.04, 0.94)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	title:SetText("Import")
	local paste = CreateFrame("EditBox", nil, frame)
	paste:SetMultiLine(true)
	paste:SetAutoFocus(false)
	paste:SetFontObject("ChatFontNormal")
	paste:SetSize(388, 90)
	paste:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
	paste:SetTextInsets(6, 6, 6, 6)
	paste:SetMaxLetters(20000)
	local pasteBg = paste:CreateTexture(nil, "BACKGROUND")
	pasteBg:SetAllPoints(paste)
	pasteBg:SetColorTexture(0, 0, 0, 0.45)
	local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameLabel:SetPoint("TOPLEFT", paste, "BOTTOMLEFT", 0, -8)
	nameLabel:SetText("Rename Layout")
	local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	nameBox:SetAutoFocus(false)
	nameBox:SetSize(240, 22)
	nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
	nameBox:SetFontObject("ChatFontNormal")
	nameBox:SetMaxLetters(32)
	local accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	accept:SetSize(88, 22)
	accept:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -12)
	accept:SetText("Import")
	accept:SetScript("OnClick", function()
		local pasted = paste:GetText()
		local typed = nameBox:GetText()
		CommitImport(pasted, typed)
		frame:Hide()
	end)
	BindEscape(paste, frame)
	BindEscape(nameBox, frame)
	frame:SetScript("OnShow", function()
		paste:SetText("")
		nameBox:SetText("")
	end)
	AttachDialogChrome(frame)
	LB.FitDialog(frame, accept, 16, { paste, nameBox })
	frame:Hide()
	LB.importFrame = frame
	return frame
end

local function SelectLayout(name)
	local profile, changed = Logic.Layouts.Switch(Account(), CharKey(), name, InCombatLockdown())
	if not profile then
		Say(changed)
		return
	end
	if changed then
		PresentLayout()
		Say(layoutLoadedText())
	end
end

local function LayoutMenu(_, root)
	if type(root) ~= "table" or type(root.CreateRadio) ~= "function" then
		return
	end
	local names = Logic.Layouts.Names(Account())
	local i
	for i = 1, #names do
		local name = names[i]
		root:CreateRadio(name, function(picked)
			return Logic.Layouts.ActiveName(Account(), CharKey()) == picked
		end, function(picked)
			SelectLayout(picked)
		end, name)
	end
	if type(root.CreateDivider) == "function" then
		root:CreateDivider()
	end
	root:CreateRadio(Logic.BLANK_LAYOUT, function()
		return Logic.Layouts.ActiveName(Account(), CharKey()) == nil
	end, function()
		SelectLayout(nil)
	end)
	if type(root.CreateDivider) == "function" then
		root:CreateDivider()
	end
	local function addAction(text, fn)
		local row = root:CreateButton(text, fn)
		if type(row) == "table" and type(row.SetSelectionIgnored) == "function" then
			row:SetSelectionIgnored()
		end
	end
	addAction("New Layout", OpenNewLayout)
	addAction("Import", function()
		EnsureImportFrame():Show()
	end)
	addAction("Share", OpenShare)
	local deleteRow = root:CreateButton("Delete")
	if type(deleteRow) == "table" and type(deleteRow.SetSelectionIgnored) == "function" then
		deleteRow:SetSelectionIgnored()
	end
	if type(deleteRow) == "table" and type(deleteRow.CreateButton) == "function" then
		for i = 1, #names do
			local name = names[i]
			local child = deleteRow:CreateButton(name, function()
				ConfirmDelete(name)
			end)
			if type(child) == "table" and type(child.SetSelectionIgnored) == "function" then
				child:SetSelectionIgnored()
			end
		end
	end
end

local DROP_W = 170
local DROP_H = 22
local STACK_GAP = 2
local STACK_LIFT = (DROP_H + STACK_GAP) / 2
local SLIDER_W = 176
local SLIDER_H = 40
local SLIDER_NUDGE = 4
local STRIP_H = DROP_H * 2 + STACK_GAP + 8
local SUBBAR_NUDGE = 6
local PARCHMENT_CAP = "GarrMission_ParchmentHeader-End"
local PARCHMENT_MID = "_GarrMission_ParchmentHeader-Mid"
local PARCHMENT_OVERLAP = 35

local function EnsureLayoutControl(strip, theme)
	local dropdown = CreateFrame("DropdownButton", "LooseButtonsLayout", strip, "WowStyle1DropdownTemplate")
	dropdown:SetSize(DROP_W, DROP_H)
	dropdown:SetPoint("TOPLEFT", theme, "BOTTOMLEFT", 0, -STACK_GAP)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(LayoutLabel())
	end
	if dropdown.SetupMenu then
		dropdown:SetupMenu(LayoutMenu)
	end
	LB.layoutDropdown = dropdown
end

if type(StaticPopupDialogs) == "table" then
	StaticPopupDialogs["LOOSEBUTTONS_LAYOUT_NAME"] = {
		text = "New layout name",
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 32,
		OnAccept = function(dialog)
			CommitNew(PopupEditText(dialog))
		end,
		EditBoxOnEnterPressed = function(editBox)
			local dialog = editBox:GetParent()
			CommitNew(PopupEditText(dialog))
			if type(StaticPopup_Hide) == "function" then
				StaticPopup_Hide("LOOSEBUTTONS_LAYOUT_NAME")
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs["LOOSEBUTTONS_LAYOUT_DELETE"] = {
		text = "Delete this saved layout?",
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, data)
			if type(data) == "table" then
				CommitDelete(data.name)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end


local function HideNamed(name)
	local frame = _G[name]
	if frame and frame.IsShown and frame:IsShown() then
		frame:Hide()
	end
end

local function EnsureHelpFrame()
	if LB.helpFrame then
		return LB.helpFrame
	end
	local frame = CreateFrame("Frame", "LooseButtonsHelp", UIParent)
	local rows = Logic.HELP
	local rowH = 20
	frame:SetSize(640, 48 + #rows * rowH)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.06, 0.05, 0.04, 0.94)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	title:SetText("Help")
	local i
	for i = 1, #rows do
		local row = rows[i]
		local y = -40 - (i - 1) * rowH
		local gesture = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		gesture:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
		gesture:SetJustifyH("LEFT")
		gesture:SetText(row.gesture)
		local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, y)
		detail:SetJustifyH("LEFT")
		if detail.SetWidth then
			detail:SetWidth(410)
		end
		detail:SetText(row.detail)
	end
	AttachDialogChrome(frame)
	frame:Hide()
	LB.helpFrame = frame
	return frame
end

local function OpenHelp()
	HideNamed("LooseButtonsShare")
	HideNamed("LooseButtonsImport")
	EnsureHelpFrame():Show()
end

local function ToggleHelp()
	local frame = EnsureHelpFrame()
	if frame:IsShown() then
		frame:Hide()
		return
	end
	OpenHelp()
end

local PAGE_CLICK = {
	clear = ConfirmClear,
	edit = ToggleBind,
	lock = ToggleLock,
	help = ToggleHelp,
}

local function AttachParchmentRibbon(strip)
	local left = strip:CreateTexture(nil, "BACKGROUND", nil, 1)
	left:SetAtlas(PARCHMENT_CAP, true)
	left:SetHeight(STRIP_H)
	left:SetPoint("LEFT", strip, "LEFT", 0, 0)
	local right = strip:CreateTexture(nil, "BACKGROUND", nil, 1)
	right:SetAtlas(PARCHMENT_CAP, true)
	right:SetHeight(STRIP_H)
	right:SetTexCoord(1, 0, 0, 1)
	right:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
	local mid = strip:CreateTexture(nil, "BACKGROUND", nil, 0)
	mid:SetAtlas(PARCHMENT_MID, true)
	mid:SetHorizTile(true)
	mid:SetHeight(STRIP_H)
	mid:SetPoint("LEFT", left, "RIGHT", -PARCHMENT_OVERLAP, 0)
	mid:SetPoint("RIGHT", right, "LEFT", PARCHMENT_OVERLAP, 0)
end

local function EnsureSubBar(book)
	local strip = CreateFrame("Frame", nil, book)
	strip:SetHeight(STRIP_H)
	strip:Hide()
	AttachParchmentRibbon(strip)
	local previous
	local i
	for i = 1, #Logic.PAGE_COMMANDS do
		local spec = Logic.PAGE_COMMANDS[i]
		local buttonName = nil
		if spec.id == "help" then
			buttonName = "LooseButtonsHelpButton"
		end
		local button = CreateFrame("Button", buttonName, strip, "SquareIconButtonTemplate")
		button:SetSize(32, 32)
		if previous then
			button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
		else
			button:SetPoint("LEFT", strip, "LEFT", 8, 0)
		end
		if spec.icon and button.SetIcon then
			button:SetIcon(spec.icon)
		end
		PaintStripButton(button, spec.icon)
		if spec.id == "clear" then
			CenterStripIcon(button)
		end
		if spec.atlas and button.icon and button.icon.SetAtlas then
			button.icon:SetAtlas("UI-HUD-MicroMenu-" .. spec.atlas .. "-Up")
			button.icon:Show()
		end
		local run = PAGE_CLICK[spec.id]
		button:SetOnClickHandler(function()
			if run then
				run()
			end
		end)
		button:SetTooltipInfo(spec.title, spec.text)
		if spec.id == "lock" then
			LB.lockButton = button
			RefreshLockButton()
		end
		previous = button
	end
	local dropdown = CreateFrame("DropdownButton", "LooseButtonsTheme", strip, "WowStyle1DropdownTemplate")
	dropdown:SetSize(DROP_W, DROP_H)
	if previous then
		dropdown:SetPoint("LEFT", previous, "RIGHT", 8, STACK_LIFT)
	else
		dropdown:SetPoint("LEFT", strip, "LEFT", 8, STACK_LIFT)
	end
	local theme = Logic.THEMES[CurrentTheme()]
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(theme.title)
	end
	if MenuUtil and MenuUtil.CreateRadioMenu then
		local rows = {}
		local i
		for i = 1, #Logic.THEME_ORDER do
			local id = Logic.THEME_ORDER[i]
			rows[i] = { Logic.THEMES[id].title, id }
		end
		MenuUtil.CreateRadioMenu(dropdown, function(id)
			return CurrentTheme() == id
		end, function(id)
			ApplyTheme(id)
		end, unpack(rows))
	end
	LB.themeDropdown = dropdown
	local slider = CreateFrame("Frame", "LooseButtonsScale", strip, "MinimalSliderWithSteppersTemplate")
	slider:SetSize(SLIDER_W, SLIDER_H)
	slider:SetPoint("LEFT", dropdown, "RIGHT", 12, -STACK_LIFT - SLIDER_NUDGE)
	local label = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
	if slider.Init and label then
		local formatters = {}
		formatters[label.Top] = function(value)
			if type(value) ~= "number" then
				return ""
			end
			return math.floor(value + 0.5) .. "%"
		end
		slider:Init(Logic.ScalePercent(CurrentScale()), Logic.SCALE_MIN_PERCENT, Logic.SCALE_MAX_PERCENT, Logic.SCALE_STEPS, formatters)
	end
	local function OnScaleChanged(_, value)
		if LB.scaleWriting then
			return
		end
		local percent = Logic.ScaleFromSlider(slider, value)
		if type(percent) ~= "number" then
			return
		end
		ApplyScale(percent / 100)
	end
	local inner = slider.Slider
	if type(inner) == "table" and type(inner.HookScript) == "function" then
		inner:HookScript("OnValueChanged", OnScaleChanged)
	elseif type(slider.HookScript) == "function" then
		slider:HookScript("OnValueChanged", OnScaleChanged)
	end
	LB.scaleSlider = slider
	EnsureLayoutControl(strip, dropdown)
	LB.subbar = strip
end

local function AnchorSubBar(book)
	local strip = LB.subbar
	if not strip or not book then
		return
	end
	strip:ClearAllPoints()
	local ribbonRight = -(80 + 4 + Logic.CatalogTextLeft())
	local tabs = book.CategoryTabSystem
	if tabs then
		strip:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 16, -4 - SUBBAR_NUDGE)
		strip:SetPoint("TOPRIGHT", book, "TOPRIGHT", ribbonRight, -55 - SUBBAR_NUDGE)
	else
		strip:SetPoint("TOPLEFT", book, "TOPLEFT", 86, -55 - SUBBAR_NUDGE)
		strip:SetPoint("TOPRIGHT", book, "TOPRIGHT", ribbonRight, -55 - SUBBAR_NUDGE)
	end
	local level = 0
	if book.GetFrameLevel then
		level = book:GetFrameLevel() or 0
	end
	strip:SetFrameLevel(level + 40)
end

local function EnsurePage(book)
	if LB.page then
		return
	end
	local page = CreateFrame("Frame", nil, book)
	page:Hide()
	EnsureSubBar(book)
	AttachCatalogScroll(page)
	LB.page = page
end

local function AnchorPage(book)
	local page = LB.page
	if not page then
		return
	end
	page:ClearAllPoints()
	page:SetPoint("TOPLEFT", book, "TOPLEFT", 100, -120)
	page:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -80, 48)
	local level = 0
	if book and book.GetFrameLevel then
		level = book:GetFrameLevel() or 0
	end
	page:SetFrameLevel(level + 30)
	AnchorSubBar(book)
end

local function ShowCatalog(book)
	EnsurePage(book)
	ClearBlizzardPage(book)
	AnchorPage(book)
	LB.page:Show()
	if LB.subbar then
		LB.subbar:Show()
	end
	LayoutCatalog(nil, true)
end

local function HideLooseChrome()
	if LB.page then
		LB.page:Hide()
	end
	if LB.subbar then
		LB.subbar:Hide()
	end
end

local function HideCatalog(book)
	HideLooseChrome()
	RestoreBlizzardPage(book)
end

local function CatalogUp()
	if LB.page and LB.page.IsShown and LB.page:IsShown() then
		return true
	end
	if LB.subbar and LB.subbar.IsShown and LB.subbar:IsShown() then
		return true
	end
	return false
end

local function HideForOtherTab(book, tabID)
	if LB.restoringTabs then
		return
	end
	if LB.tabID == nil or tabID == LB.tabID or not CatalogUp() then
		return
	end
	HideLooseChrome()
end

local function WatchTabButton(book, button, tabID, watchedButtons)
	if type(button) ~= "table" or watchedButtons[button] then
		return
	end
	watchedButtons[button] = true
	local function liveID(self)
		if type(self) == "table" and type(self.GetTabID) == "function" then
			local id = self:GetTabID()
			if id ~= nil then
				return id
			end
		end
		return tabID
	end
	if type(button.SetTabSelected) == "function" then
		hooksecurefunc(button, "SetTabSelected", function(self, isSelected)
			local id = liveID(self)
			if isSelected and id ~= LB.tabID then
				HideForOtherTab(book, id)
			elseif not isSelected and id == LB.tabID then
				HideForOtherTab(book, nil)
			end
		end)
	end
	if type(button.SetScript) ~= "function" then
		return
	end
	local setScript = button.SetScript
	local function clickThenHide(handler)
		return function(self, ...)
			handler(self, ...)
			local id = liveID(self)
			if id ~= LB.tabID then
				HideForOtherTab(book, id)
			end
		end
	end
	button.SetScript = function(self, script, handler)
		if script == "OnClick" and type(handler) == "function" then
			return setScript(self, script, clickThenHide(handler))
		end
		return setScript(self, script, handler)
	end
	if type(button.GetScript) == "function" then
		local current = button:GetScript("OnClick")
		if type(current) == "function" then
			button:SetScript("OnClick", current)
		end
	end
end

local function WatchTabButtons(book, tabs, watchedButtons)
	if not tabs or type(tabs.GetTabButton) ~= "function" then
		return
	end
	local id = 1
	while true do
		local button = tabs:GetTabButton(id)
		if not button then
			break
		end
		WatchTabButton(book, button, id, watchedButtons)
		id = id + 1
	end
end

local function WatchTabSelection(book)
	local tabs = book.CategoryTabSystem
	if not tabs or LB.tabWatched or type(hooksecurefunc) ~= "function" then
		return
	end
	LB.tabWatched = true
	local watchedButtons = {}
	local function follow(_, tabID)
		HideForOtherTab(book, tabID)
	end
	if type(tabs.SetTab) == "function" then
		hooksecurefunc(tabs, "SetTab", follow)
	end
	if type(tabs.SetTabVisuallySelected) == "function" then
		hooksecurefunc(tabs, "SetTabVisuallySelected", follow)
	end
	if type(tabs.AddTab) == "function" then
		hooksecurefunc(tabs, "AddTab", function(self)
			WatchTabButtons(book, self, watchedButtons)
		end)
	end
	WatchTabButtons(book, tabs, watchedButtons)
end

local function BindCatalogTab(book, tabID)
	if LB.tabID and LB.tabID ~= tabID then
		if book.SetTabCallback then
			book:SetTabCallback(LB.tabID, nil)
		end
		if book.SetTabDeselectCallback then
			book:SetTabDeselectCallback(LB.tabID, nil)
		end
	end
	LB.tabID = tabID
	if book.SetTabCallback then
		book:SetTabCallback(tabID, function()
			if LB.restoringTabs then
				if LB.wantCatalog then
					ShowCatalog(book)
				end
				return
			end
			LB.wantCatalog = true
			ShowCatalog(book)
		end)
	end
	if book.SetTabDeselectCallback then
		book:SetTabDeselectCallback(tabID, function()
			if LB.restoringTabs then
				return
			end
			LB.wantCatalog = false
			HideCatalog(book)
		end)
	end
end

local function HideUnavailableTabs(book)
	local mixins = book.categoryMixins
	local tabSystem = book.CategoryTabSystem
	if type(mixins) ~= "table" or not tabSystem or not tabSystem.SetTabShown then
		return
	end
	local i
	for i = 1, #mixins do
		local row = mixins[i]
		if row.GetTabID and row.IsAvailable then
			tabSystem:SetTabShown(row:GetTabID(), row:IsAvailable())
		end
	end
end

local function AddCatalogTab(book)
	local tabID = book:AddIconTab("Interface\\Icons\\INV_Misc_Book_09")
	BindCatalogTab(book, tabID)
	local tabButton = book.CategoryTabSystem and book.CategoryTabSystem.GetTabButton and book.CategoryTabSystem:GetTabButton(tabID)
	if tabButton then
		if tabButton.SetTooltipText then
			tabButton:SetTooltipText("Loose Buttons")
		end
		if tabButton.SetSquareMode then
			tabButton:SetSquareMode(true)
		end
		if tabButton.Icon and tabButton.Icon.SetAtlas then
			tabButton.Icon:SetAtlas("UI-HUD-MicroMenu-SpellbookAbilities-Up")
			if tabButton.Icon.Show then
				tabButton.Icon:Show()
			end
		end
		if type(tabButton.IconMask) == "table" and tabButton.IconMask.Show then
			tabButton.IconMask:Show()
		end
	end
	HideUnavailableTabs(book)
end

local function HookBook()
	if LB.bookHooked then
		return
	end
	local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
	if not book or type(book.CreateCategoryMixins) ~= "function" then
		return
	end
	LB.bookHooked = true
	local origCreate = book.CreateCategoryMixins
	local origUpdate = book.UpdateAllSpellData
	book.CreateCategoryMixins = function(self, ...)
		if type(securecall) == "function" then
			securecall(origCreate, self, ...)
		else
			origCreate(self, ...)
		end
		AddCatalogTab(self)
	end
	if type(origUpdate) == "function" then
		book.UpdateAllSpellData = function(self, ...)
			local keep = LB.wantCatalog
			LB.restoringTabs = true
			if type(securecall) == "function" then
				securecall(origUpdate, self, ...)
			else
				origUpdate(self, ...)
			end
			LB.restoringTabs = false
			if keep and LB.tabID and self.GetTab and self:GetTab() ~= LB.tabID then
				LB.wantCatalog = true
				if type(securecall) == "function" then
					securecall(self.SetTab, self, LB.tabID)
				else
					self:SetTab(LB.tabID)
				end
			elseif not keep and LB.tabID and self.GetTab and self:GetTab() == LB.tabID then
				HideCatalog(self)
				if type(self.ResetToFirstAvailableTab) == "function" then
					self:ResetToFirstAvailableTab()
				end
			elseif LB.page and LB.page:IsShown() then
				LayoutCatalog(nil, true)
			end
		end
	end
	local origDisplayed = book.UpdateDisplayedSpells
	if type(origDisplayed) == "function" then
		book.UpdateDisplayedSpells = function(self, ...)
			if LB.wantCatalog then
				ClearBlizzardPage(self)
				return
			end
			if type(securecall) == "function" then
				return securecall(origDisplayed, self, ...)
			end
			return origDisplayed(self, ...)
		end
	end
	WatchTabSelection(book)
	book:CreateCategoryMixins()
end

local function WatchBook()
	HookBook()
	if EventUtil and EventUtil.ContinueOnAddOnLoaded then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", HookBook)
	end
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
			LoadDB()
			WatchBook()
			WatchQuickKeybind()
		elseif arg1 == "Blizzard_QuickKeybind" then
			WatchQuickKeybind()
		elseif arg1 == "Blizzard_PlayerSpells" then
			HookBook()
		end
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		keys:Hide()
		if LB.binding then
			EndBind()
		end
		return
	end
	if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
		if event == "PLAYER_LOGIN" then
			LoadDB()
		end
		EnsurePool()
		if LB.bookStale and LB.poolReady and not InCombatLockdown() then
			LB.bookStale = nil
			ApplyAll()
		end
		WatchQuickKeybind()
		ClearSnapPlan()
		if LB.pendingScale and not InCombatLockdown() then
			ApplyScale(DB().scale)
		end
		if LB.pending and not InCombatLockdown() then
			local pending = LB.pending
			LB.pending = nil
			Place(pending.kind, pending.payload, pending.x, pending.y, pending.icon)
		end
		if LB.pendingDragType and not InCombatLockdown() then
			local pendingType = LB.pendingDragType
			LB.pendingDragType = nil
			if pendingType.button and pendingType.button.SetAttribute then
				pendingType.button:SetAttribute("type", pendingType.savedType)
			end
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or event == "PORTRAITS_UPDATED" or event == "UNIT_PORTRAIT_UPDATE" then
		if event == "UNIT_PORTRAIT_UPDATE" then
			if type(issecretvalue) == "function" and issecretvalue(arg1) then
				Defer(RefreshPortraits)
				return
			end
			if arg1 ~= "player" then
				return
			end
		end
		Defer(RefreshPortraits)
		return
	end
	if event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "BAG_UPDATE_DELAYED" then
		UpdateCooldowns()
		return
	end
	if event == "UPDATE_BINDINGS" then
		RefreshHotkeys()
		return
	end
	if event == "SPELLS_CHANGED" then
		LB.bookCache = {}
		if LB.poolReady and HiddenIds() ~= LB.hiddenIds then
			LB.bookStale = true
		end
		if LB.bookStale and not InCombatLockdown() then
			LB.bookStale = nil
			ApplyAll()
		end
		return
	end
	if event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "UPDATE_MACROS" then
		if LB.page and LB.page:IsShown() then
			LayoutCatalog(nil, true)
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
				HideReceive()
			end
			return
		end
		receive:Hide()
	end
end)

SLASH_LOOSEBUTTONS1 = "/loose"
SLASH_LOOSEBUTTONS2 = "/lb"
SlashCmdList["LOOSEBUTTONS"] = function(msg)
	msg = string.lower(msg or "")
	msg = string.gsub(msg, "^%s+", "")
	msg = string.gsub(msg, "%s+$", "")
	if msg == "reset" then
		ResetAll()
		return
	end
	if msg == "help" then
		OpenHelp()
		return
	end
	if msg == "bind" or msg == "keybind" or msg == "" then
		ToggleBind()
		return
	end
	Say("Unknown command. /loose help")
end
