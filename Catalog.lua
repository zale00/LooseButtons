local Logic = LooseButtonsLogic
local LB = Logic.LB
local LayoutMenu, ToggleHelp, ApplySpellbookColor = LB.LayoutMenu, LB.ToggleHelp, LB.ApplySpellbookColor

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
	local x, y = LB.CursorCenter()
	if not mover or not x or LB.OverBook() or LB.ActionButtonUnderCursor() then
		LB.ClearSnapPlan()
		return
	end
	LB.ShowSnapPlan(Logic.SnapPlan(LB.DB().buttons, { mover }, x, y, LB.ScaleOf))
end

receive:SetScript("OnHide", LB.ClearSnapPlan)
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
local function FinishDrop()
	if dropBusy then
		return
	end
	dropBusy = true
	local kind, payload, icon, petCast, bookSlot, keepRank
	if LB.dragLauncher then
		kind = "launcher"
		payload = LB.dragLauncher.payload
		icon = LB.dragLauncher.icon
	elseif LB.dragSpell then
		kind = LB.dragSpell.kind
		payload = LB.dragSpell.payload
		icon = LB.dragSpell.icon
		petCast = LB.dragSpell.petCast
		bookSlot = LB.dragSpell.bookSlot
		keepRank = LB.dragSpell.keepRank
		LB.dragSpell = nil
	else
		HideReceive()
		dropBusy = false
		return
	end
	local over = LB.ActionButtonUnderCursor()
	local intent = Logic.DropIntent("catalog", over ~= nil, kind)
	if intent == "action" then
		LB.PlaceIntoAction(over, kind, payload, petCast, bookSlot)
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
	local onBook = LB.OverBook()
	local x, y = LB.CursorCenter()
	if ClearCursor then
		ClearCursor()
	end
	HideReceive()
	if not onBook and x then
		LB.Place(kind, payload, x, y, icon, petCast, keepRank)
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
		local record = LB.Find("spell", i)
		if button and button:IsShown() and record and (record.kind == "spell" or record.kind == "item" or (record.kind == "pet" and record.petCast == "spell")) then
			LB.ApplyActionOverlay(button)
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
		subName = info.subName,
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

function LB.SpellBase(spellID)
	if type(issecretvalue) == "function" and issecretvalue(spellID) then
		return nil
	end
	if type(spellID) ~= "number" or spellID < 1 or spellID ~= math.floor(spellID) then
		return nil
	end
	if type(C_SpellBook) ~= "table" or type(C_SpellBook.FindBaseSpellByID) ~= "function" then
		return nil
	end
	local base = C_SpellBook.FindBaseSpellByID(spellID)
	if type(issecretvalue) == "function" and issecretvalue(base) then
		return nil
	end
	if type(base) ~= "number" or base < 1 or base ~= math.floor(base) then
		return nil
	end
	return base
end

function LB.SpellName(spellID)
	if type(issecretvalue) == "function" and issecretvalue(spellID) then
		return nil
	end
	if type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return nil
	end
	local name = C_Spell.GetSpellName(spellID)
	if type(issecretvalue) == "function" and issecretvalue(name) then
		return nil
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

function LB.SpellRank(spellID)
	if type(issecretvalue) == "function" and issecretvalue(spellID) then
		return nil
	end
	if type(C_Spell) ~= "table" or type(C_Spell.GetSpellSubtext) ~= "function" then
		return nil
	end
	return Logic.SpellRank(C_Spell.GetSpellSubtext(spellID))
end

function LB.FollowRanks()
	if Logic.UpgradeSpellRanks(LB.DB().buttons, SkillLines(), function(index)
		return Logic.RankRow(SpellAt(index))
	end, LB.SpellBase, LB.SpellName, LB.SpellRank) then
		LB.bookStale = true
	end
end

local function BindingExists(command)
	if type(GetBindingIndex) ~= "function" then
		return false
	end
	local index = GetBindingIndex(command)
	return type(index) == "number" and index > 0
end

local function FrameCatalogIcon(row, framed)
	local icon = row.icon
	icon:ClearAllPoints()
	if framed then
		icon:SetSize(36, 36)
		icon:SetPoint("CENTER", row, "LEFT", 20, 0)
		if not row.iconMasked then
			icon:AddMaskTexture(row.iconMask)
			row.iconMasked = true
		end
	else
		icon:SetSize(40, 40)
		icon:SetPoint("LEFT", row, "LEFT", 0, 0)
		if row.iconMasked then
			icon:RemoveMaskTexture(row.iconMask)
			row.iconMasked = nil
		end
	end
	row.iconBorder:SetShown(framed)
	row.iconShadow:SetShown(framed)
end

-- plate is the row's plate texture. The rank button repaints a spell icon and passes none.
local function PaintCatalogIcon(icon, entry, plate)
	local paint
	if entry.chrome == "micro" then
		paint = Logic.LauncherPaint({ kind = "launcher", payload = entry.payload })
	end
	if plate then
		if paint and paint.plate then
			plate:SetAtlas(paint.plate, true)
			plate:Show()
		else
			plate:Hide()
		end
	end
	if paint and paint.normal and icon.SetAtlas then
		icon:SetAtlas(paint.normal, true)
		if plate then
			icon:ClearAllPoints()
			icon:SetPoint("CENTER", plate, "CENTER", 0, 0)
		end
		return
	end
	-- A pooled row keeps the last atlas's texture coordinates until they are reset.
	if icon.SetTexCoord then
		icon:SetTexCoord(0, 1, 0, 1)
	end
	if entry.portrait and type(SetPortraitTexture) == "function" then
		if plate and paint then
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", plate, "TOPLEFT", 7, -7)
			icon:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -7, 7)
		end
		SetPortraitTexture(icon, "player")
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
	label = header:CreateFontString(nil, "OVERLAY", "SystemFont_Med1")
	label:SetText(text)
	ApplySpellbookColor(label)
	header[key] = label
	return label
end

local function PlaceByAnchors(anchors, frames, order)
	local i
	for i = 1, #order do
		local anchor = anchors[order[i]]
		local frame = frames[order[i]]
		local relFrame = anchor and frames[anchor.rel]
		if frame and relFrame then
			frame:ClearAllPoints()
			frame:SetPoint(anchor.point, relFrame, anchor.relPoint, anchor.x, anchor.y)
		end
	end
end

local function ShowSectionScale(header)
	if not header.check then
		local check = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
		check:SetSize(26, 26)
		check:SetScript("OnClick", function(self)
			LB.DB().launcherScaleSeparate = self:GetChecked() and true or false
			if header.sectionSlider then
				header.sectionSlider:SetShown(LB.DB().launcherScaleSeparate)
			end
			LB.ApplyScale(LB.CurrentScale())
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
			slider:Init(Logic.ScalePercent(LB.DB().launcherScale), Logic.SCALE_MIN_PERCENT, Logic.SCALE_MAX_PERCENT, Logic.SCALE_STEPS, formatters)
		end
		local function OnChanged(_, value)
			if LB.launcherScaleWriting then
				return
			end
			local percent = Logic.ScaleFromSlider(slider, value)
			if type(percent) ~= "number" then
				return
			end
			LB.ApplyLauncherScale(percent / 100)
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
			LB.DB().launcherThemeSeparate = self:GetChecked() and true or false
			if header.sectionTheme then
				header.sectionTheme:SetShown(LB.DB().launcherThemeSeparate)
			end
			LB.RepaintPlaced()
		end)
		header.themeCheck = themeCheck
		EnsureCheckLabel(header, "themeCheckLabel", "Theme")
		local dropdown = CreateFrame("DropdownButton", nil, header, "WowStyle1DropdownTemplate")
		dropdown:SetSize(Logic.SECTION_STACK.dropW, Logic.SECTION_STACK.dropH)
		local theme = Logic.NormalizeTheme(LB.DB().launcherTheme)
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
				return Logic.NormalizeTheme(LB.DB().launcherTheme) == id
			end, function(id)
				LB.ApplyLauncherTheme(id)
			end, unpack(rows))
		end
		header.sectionTheme = dropdown
	end
	local scaleLabel = EnsureCheckLabel(header, "checkLabel", "Scale")
	local themeLabel = EnsureCheckLabel(header, "themeCheckLabel", "Theme")
	local row = Logic.SectionRow(scaleLabel:GetStringWidth(), themeLabel:GetStringWidth())
	local frames = {
		title = header.text,
		scaleCheck = header.check,
		scaleLabel = header.checkLabel,
		slider = header.sectionSlider,
		themeCheck = header.themeCheck,
		themeLabel = header.themeCheckLabel,
		dropdown = header.sectionTheme,
	}
	PlaceByAnchors(row.anchors, frames, { "scaleCheck", "scaleLabel", "slider", "themeCheck", "themeLabel", "dropdown" })
	header.check:Show()
	if header.check.SetChecked then
		header.check:SetChecked(LB.DB().launcherScaleSeparate)
	end
	scaleLabel:Show()
	ApplySpellbookColor(scaleLabel)
	local slider = header.sectionSlider
	if slider.SetValue and not LB.launcherScaleWriting then
		LB.launcherScaleWriting = true
		slider:SetValue(Logic.ScalePercent(LB.DB().launcherScale))
		LB.launcherScaleWriting = nil
	end
	slider:SetShown(LB.DB().launcherScaleSeparate)
	LB.launcherSlider = slider
	local themeCheck = header.themeCheck
	themeCheck:Show()
	if themeCheck.SetChecked then
		themeCheck:SetChecked(LB.DB().launcherThemeSeparate)
	end
	themeLabel:Show()
	ApplySpellbookColor(themeLabel)
	local dropdown = header.sectionTheme
	local theme = Logic.NormalizeTheme(LB.DB().launcherTheme)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(Logic.THEMES[theme].title)
	end
	dropdown:SetShown(LB.DB().launcherThemeSeparate)
	LB.launcherThemeDropdown = dropdown
end

local function ApplyHeldRank(entry)
	if type(entry) ~= "table" or type(entry.ranks) ~= "table" or #entry.ranks < 2 then
		return nil
	end
	local pickedId = LB.rankPick and LB.rankPick[entry.name]
	local chosen
	local i
	if pickedId then
		for i = 1, #entry.ranks do
			if entry.ranks[i].payload == pickedId then
				chosen = entry.ranks[i]
				break
			end
		end
	end
	if not chosen then
		chosen = entry.ranks[#entry.ranks]
	end
	entry.payload = chosen.payload
	if chosen.icon then
		entry.icon = chosen.icon
	end
	local top = entry.ranks[#entry.ranks]
	if top and chosen.payload ~= top.payload then
		entry.keepRank = true
	else
		entry.keepRank = nil
	end
	return chosen
end

local function EnsureRankButton(row)
	if row.rankButton then
		return row.rankButton
	end
	local button = CreateFrame("Button", nil, row)
	button:SetSize(160, 16)
	button:RegisterForDrag("LeftButton")
	local label = button:CreateFontString(nil, "OVERLAY", "SystemFont_Med1")
	label:SetAllPoints(button)
	label:SetJustifyH("LEFT")
	button.label = label
	button:SetScript("OnClick", function(self)
		local host = self:GetParent()
		local entry = host and host.entry
		if not entry then
			return
		end
		local picked = Logic.StepSpellRank(entry.ranks, entry.payload)
		if not picked then
			return
		end
		LB.rankPick = LB.rankPick or {}
		LB.rankPick[entry.name] = picked.payload
		entry.payload = picked.payload
		if picked.icon then
			entry.icon = picked.icon
		end
		local top = entry.ranks[#entry.ranks]
		if top and picked.payload ~= top.payload then
			entry.keepRank = true
		else
			entry.keepRank = nil
		end
		PaintCatalogIcon(host.icon, entry)
		self.label:SetText("Rank " .. picked.rank)
		ApplySpellbookColor(self.label)
	end)
	button:SetScript("OnDragStart", function(self)
		local host = self:GetParent()
		local drag = host and host.GetScript and host:GetScript("OnDragStart")
		if drag then
			drag(host)
		end
	end)
	row.rankButton = button
	return button
end

local catalogWidth

local function NewHeader(content)
	local spec = Logic.CATALOG_PAGE
	local header = CreateFrame("Frame", nil, content)
	header.text = header:CreateFontString(nil, "OVERLAY", "SystemFont_Huge2")
	header.text:SetJustifyH("LEFT")
	header.backplate = header:CreateTexture(nil, "BACKGROUND")
	header.backplate:SetAtlas("spellbook-list-backplate", true)
	header.backplate:SetAlpha(0.65)
	header.backplate:SetSize(spec.backplateW, spec.backplateH)
	header.backplate:SetPoint("LEFT", header.text, "LEFT", spec.backplateX, spec.backplateY)
	header.divider = header:CreateTexture(nil, "ARTWORK")
	header.divider:SetAtlas("spellbook-divider", true)
	header.divider:SetHeight(Logic.SECTION_STACK.divider)
	header.divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	header.divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	return header
end

local function AttachTip(frame, tip)
	frame:HookScript("OnEnter", function(self)
		if type(GameTooltip) ~= "table" or type(GameTooltip.SetOwner) ~= "function" or type(GameTooltip_SetTitle) ~= "function" then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip_SetTitle(GameTooltip, tip.title)
		if type(GameTooltip_AddNormalLine) == "function" then
			GameTooltip_AddNormalLine(GameTooltip, tip.text, true)
		end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function()
		if type(GameTooltip) == "table" and type(GameTooltip.Hide) == "function" then
			GameTooltip:Hide()
		end
	end)
end

local function LayoutLabel()
	return Logic.Layouts.ActiveName(LB.Account(), LB.CharKey()) or Logic.BLANK_LAYOUT
end

local function EnsureSettings(header)
	local stack = Logic.SETTINGS_STACK
	local tips = Logic.SETTINGS_TIPS
	EnsureCheckLabel(header, "themeLabel", "Theme")
	EnsureCheckLabel(header, "layoutLabel", "Layout")
	EnsureCheckLabel(header, "scaleLabel", "Scale")
	local dropdown = CreateFrame("DropdownButton", "LooseButtonsTheme", header, "WowStyle1DropdownTemplate")
	dropdown:SetSize(stack.dropW, stack.dropH)
	local theme = Logic.THEMES[LB.CurrentTheme()]
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
			return LB.CurrentTheme() == id
		end, function(id)
			LB.ApplyTheme(id)
		end, unpack(rows))
	end
	AttachTip(dropdown, tips.theme)
	LB.themeDropdown = dropdown
	local layout = CreateFrame("DropdownButton", "LooseButtonsLayout", header, "WowStyle1DropdownTemplate")
	layout:SetSize(stack.dropW, stack.dropH)
	if layout.SetDefaultText then
		layout:SetDefaultText(LayoutLabel())
	end
	if layout.SetupMenu then
		layout:SetupMenu(LayoutMenu)
	end
	AttachTip(layout, tips.layout)
	LB.layoutDropdown = layout
	local slider = CreateFrame("Frame", "LooseButtonsScale", header, "MinimalSliderWithSteppersTemplate")
	slider:SetSize(stack.sliderW, stack.sliderH)
	local label = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
	if slider.Init and label then
		local formatters = {}
		formatters[label.Top] = function(value)
			if type(value) ~= "number" then
				return ""
			end
			return math.floor(value + 0.5) .. "%"
		end
		slider:Init(Logic.ScalePercent(LB.CurrentScale()), Logic.SCALE_MIN_PERCENT, Logic.SCALE_MAX_PERCENT, Logic.SCALE_STEPS, formatters)
	end
	local function OnScaleChanged(_, value)
		if LB.scaleWriting then
			return
		end
		local percent = Logic.ScaleFromSlider(slider, value)
		if type(percent) ~= "number" then
			return
		end
		LB.ApplyScale(percent / 100)
	end
	local inner = slider.Slider
	if type(inner) == "table" and type(inner.HookScript) == "function" then
		inner:HookScript("OnValueChanged", OnScaleChanged)
	elseif type(slider.HookScript) == "function" then
		slider:HookScript("OnValueChanged", OnScaleChanged)
	end
	AttachTip(slider, tips.scale)
	if type(inner) == "table" then
		AttachTip(inner, tips.scale)
	end
	LB.scaleSlider = slider
end

local function PlaceHeader(header, content, spec, y, height, title)
	header:ClearAllPoints()
	header:SetSize(spec.headerInner, height)
	header:SetPoint("TOPLEFT", content, "TOPLEFT", spec.headerLeft, -y)
	header.text:ClearAllPoints()
	local hasControls = height > Logic.SECTION_STACK.plain
	local textY = -4
	if hasControls then
		textY = Logic.SectionHeaderInset()
	end
	header.text:SetPoint("TOPLEFT", header, "TOPLEFT", spec.titleLeft, textY)
	header.text:SetText(title)
	ApplySpellbookColor(header.text)
	if not hasControls then
		header.text:SetPoint("TOPRIGHT", header, "TOPRIGHT", -spec.rightPad, textY)
	end
	header:Show()
end

local function LayoutSettings(header, content, spec, y)
	local row = Logic.SettingsRow(header.themeLabel:GetStringWidth(), header.layoutLabel:GetStringWidth(), header.scaleLabel:GetStringWidth())
	PlaceHeader(header, content, spec, y, row.height, Logic.SETTINGS_TITLE)
	PlaceByAnchors(row.anchors, {
		title = header.text,
		themeLabel = header.themeLabel,
		theme = LB.themeDropdown,
		layoutLabel = header.layoutLabel,
		layout = LB.layoutDropdown,
		scaleLabel = header.scaleLabel,
		slider = LB.scaleSlider,
	}, { "themeLabel", "theme", "layoutLabel", "layout", "scaleLabel", "slider" })
	return row.height
end

local ROW_REST_ALPHA = 0.25

local function NewCatalogRow(content)
	local row = CreateFrame("Button", nil, content)
	row.lbCatalog = true
	row.backplate = row:CreateTexture(nil, "BACKGROUND")
	row.backplate:SetAtlas("spellbook-item-backplate", true)
	row.backplate:SetAlpha(ROW_REST_ALPHA)
	row.backplate:SetPoint("CENTER", row, "CENTER", 5, -5)
	row.plate = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.plate:SetPoint("CENTER", row, "LEFT", 20, 0)
	row.plate:Hide()
	row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.iconShadow = row:CreateTexture(nil, "ARTWORK", nil, 0)
	row.iconShadow:SetAtlas("spellbook-item-iconframe-shadow")
	row.iconShadow:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -14, 5)
	row.iconShadow:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 4, -10)
	row.iconBorder = row:CreateTexture(nil, "OVERLAY")
	row.iconBorder:SetAtlas("spellbook-item-iconframe")
	row.iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -13, 3)
	row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 3, -9)
	row.iconMask = row:CreateMaskTexture()
	row.iconMask:SetAtlas("spellbook-item-spellicon-mask", false)
	row.iconMask:SetAllPoints(row.icon)
	row.hover = row:CreateTexture(nil, "OVERLAY", nil, 2)
	row.hover:SetAtlas("spellbook-item-iconframe-hover", false)
	row.hover:SetBlendMode("ADD")
	row.hover:SetAlpha(0.35)
	row.hover:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -2, 2)
	row.hover:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 2, -2)
	row.hover:Hide()
	row.nameText = row:CreateFontString(nil, "OVERLAY", "SystemFont_Large")
	row.nameText:SetJustifyH("LEFT")
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
		if dragged.kind == "spell" or dragged.kind == "pet" then
			if InCombatLockdown() then
				LB.Say("Cannot pick up a spell in combat.")
				return
			end
			LB.dragSpell = { kind = dragged.kind, payload = dragged.payload, icon = dragged.icon, petCast = dragged.petCast, bookSlot = dragged.bookSlot, keepRank = dragged.keepRank }
			ShowSpellGhost(dragged.icon)
			ShowReceive(true)
			return
		end
		BeginLauncherDrag(dragged)
	end)
	row:SetScript("OnEnter", function(self)
		self.backplate:SetAlpha(1)
		if self.entry and self.entry.kind ~= "launcher" then
			self.hover:Show()
		end
		LB.ShowTip(self, self.entry)
	end)
	row:SetScript("OnLeave", function(self)
		self.backplate:SetAlpha(ROW_REST_ALPHA)
		self.hover:Hide()
		if type(GameTooltip) == "table" and type(GameTooltip.Hide) == "function" then
			GameTooltip:Hide()
		end
	end)
	return row
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
	catalogWidth = width
	local rowH = 60
	local yGap = 10
	local xPad = 15
	local plainH = Logic.SECTION_STACK.plain
	local spec = {
		headerLeft = Logic.CATALOG_PAGE.headerLeft,
		rowLeft = Logic.CATALOG_PAGE.rowLeft,
		titleLeft = Logic.CATALOG_PAGE.titleLeft,
		rightPad = Logic.CatalogTextLeft(),
	}
	local rowInner = width - spec.rowLeft - spec.rightPad
	if rowInner < 40 then
		rowInner = width
		spec.headerLeft = 0
		spec.rowLeft = 0
		spec.titleLeft = 0
		spec.rightPad = 0
	end
	spec.headerInner = width - spec.headerLeft - spec.rightPad
	local y = Logic.CATALOG_PAGE.firstY
	local headerIndex = 0
	local buttonIndex = 0
	local function nextHeader()
		headerIndex = headerIndex + 1
		local header = LB.catalogHeaders[headerIndex]
		if not header then
			header = NewHeader(content)
			LB.catalogHeaders[headerIndex] = header
		end
		return header
	end
	local function finish()
		local i
		for i = headerIndex + 1, #LB.catalogHeaders do
			LB.catalogHeaders[i]:Hide()
		end
		for i = buttonIndex + 1, #LB.catalogButtons do
			LB.catalogButtons[i]:Hide()
		end
		content:SetSize(width, math.max(y + 12, 40))
		page.scroll:SetVerticalScroll(0)
	end
	if LB.catalogView == "help" then
		LB.settingsHeader:Hide()
		local header = nextHeader()
		PlaceHeader(header, content, spec, y, plainH, "Help")
		HideSectionScale(header)
		y = LB.LayoutHelpPage(content, spec.rowLeft, rowInner, y + plainH + yGap)
		finish()
		return
	end
	LB.HideHelpPage()
	local minCol = 178
	local columns = math.floor((rowInner + xPad) / (minCol + xPad))
	if columns < 1 then
		columns = 1
	end
	local colWidth = math.floor((rowInner - xPad * (columns - 1)) / columns)
	if colWidth < 40 then
		colWidth = 40
	end
	local sections = Logic.BuildSections(SkillLines(), SpellAt, Logic.VisibleLaunchers(BindingExists), items, Logic.Macros(_G), Logic.PetBookEntries(C_SpellBook, Enum, PetHasSpellbook))
	sections = Logic.FilterSections(sections, LB.SearchText and LB.SearchText())
	y = y + LayoutSettings(LB.settingsHeader, content, spec, y) + yGap
	local col = 0
	local s
	for s = 1, #sections do
		local section = sections[s]
		if col ~= 0 then
			y = y + rowH + yGap
			col = 0
		end
		local header = nextHeader()
		local headerH = Logic.CatalogHeaderHeight(section.title)
		PlaceHeader(header, content, spec, y, headerH, section.title)
		if section.title == Logic.SECTION_ORDER[1] then
			ShowSectionScale(header)
		else
			HideSectionScale(header)
		end
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
				row = NewCatalogRow(content)
				LB.catalogButtons[buttonIndex] = row
			end
			local shownRank = ApplyHeldRank(entry)
			row.entry = entry
			row:SetSize(colWidth, rowH)
			row.backplate:SetAlpha(ROW_REST_ALPHA)
			row.hover:Hide()
			FrameCatalogIcon(row, entry.kind ~= "launcher")
			PaintCatalogIcon(row.icon, entry, row.plate)
			row.nameText:SetText(entry.name or "")
			ApplySpellbookColor(row.nameText)
			row.nameText:ClearAllPoints()
			if shownRank then
				local rankButton = EnsureRankButton(row)
				rankButton.label:SetText("Rank " .. shownRank.rank)
				ApplySpellbookColor(rankButton.label)
				rankButton:ClearAllPoints()
				rankButton:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 50, 4)
				rankButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				rankButton:Show()
				row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 50, -6)
				row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				if row.nameText.SetWordWrap then
					row.nameText:SetWordWrap(false)
				end
			else
				if row.rankButton then
					row.rankButton:Hide()
				end
				row.nameText:SetPoint("LEFT", row, "LEFT", 50, 0)
				row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				if row.nameText.SetWordWrap then
					row.nameText:SetWordWrap(true)
				end
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", content, "TOPLEFT", spec.rowLeft + col * (colWidth + xPad), -y)
			row:Show()
			col = col + 1
		end
	end
	if col ~= 0 then
		y = y + rowH
	end
	finish()
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
			LB.catalogItems = scanned
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
	local bar = CreateFrame("EventFrame", "LooseButtonsCatalogBar", page, Logic.CATALOG_BAR.template)
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", Logic.CATALOG_BAR.x, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", Logic.CATALOG_BAR.x, 0)
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
	LB.ClearStateTextures(button)
	LB.PaintStockAction(button, texture)
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
	local iconW, iconH = LB.ButtonLayout(button)
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
	local locked = LB.IsLocked()
	local art = Logic.LockArt(locked)
	if button.SetIcon then
		button:SetIcon(art)
	end
	PaintStripButton(button, art)
	CenterLockIcon(button)
	if type(button.Icon) == "table" and button.Icon.SetTexCoord then
		local crop = Logic.LOCK_CROP
		button.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
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
	local live = LB.DB()
	live.locked = Logic.NormalizeLocked(not LB.IsLocked())
	RefreshLockButton()
end

local function RefreshLayoutChrome()
	RefreshLockButton()
	if LB.themeDropdown and LB.themeDropdown.SetDefaultText then
		LB.themeDropdown:SetDefaultText(Logic.THEMES[LB.CurrentTheme()].title)
	end
	if LB.scaleSlider and LB.scaleSlider.SetValue then
		LB.scaleWriting = true
		LB.scaleSlider:SetValue(Logic.ScalePercent(LB.CurrentScale()))
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

local PAGE_CLICK = {
	clear = LB.ConfirmClear,
	edit = LB.ToggleBind,
	lock = ToggleLock,
	help = ToggleHelp,
}

local STRIP_GAP = 6
local HELP_GAP = 8
local HELP_SIZE = 16

local function EnsureSubBar(book)
	local size = Logic.PAGE_BUTTON
	local strip = CreateFrame("Frame", nil, book)
	strip:Hide()
	local previous
	local squares = 0
	local i
	for i = 1, #Logic.PAGE_COMMANDS do
		local spec = Logic.PAGE_COMMANDS[i]
		local run = PAGE_CLICK[spec.id]
		local function click()
			if run then
				run()
			end
		end
		local button
		if spec.info then
			button = CreateFrame("Button", "LooseButtonsHelpButton", strip, "UIPanelInfoButton")
			button:SetSize(HELP_SIZE, HELP_SIZE)
			button:SetPoint("LEFT", previous, "RIGHT", HELP_GAP, 0)
			button:SetScript("OnClick", click)
			AttachTip(button, spec)
		else
			squares = squares + 1
			button = CreateFrame("Button", nil, strip, "SquareIconButtonTemplate")
			button:SetSize(size, size)
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", STRIP_GAP, 0)
			else
				button:SetPoint("LEFT", strip, "LEFT", 0, 0)
			end
			if spec.icon and button.SetIcon then
				button:SetIcon(spec.icon)
			end
			PaintStripButton(button, spec.icon)
			if spec.id == "clear" then
				CenterStripIcon(button)
			end
			button:SetOnClickHandler(click)
			button:SetTooltipInfo(spec.title, spec.text)
			if spec.id == "lock" then
				LB.lockButton = button
				RefreshLockButton()
			end
		end
		previous = button
	end
	strip:SetSize(squares * size + (squares - 1) * STRIP_GAP + HELP_GAP + HELP_SIZE, size)
	LB.subbar = strip
end

local function AnchorSubBar(book)
	local strip = LB.subbar
	if not strip or not book then
		return
	end
	strip:ClearAllPoints()
	local spec = Logic.CATALOG_PAGE
	strip:SetPoint("BOTTOMLEFT", book, "BOTTOMLEFT", spec.left + spec.rowLeft, spec.stripBottom)
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
	LB.settingsHeader = NewHeader(page.content)
	EnsureSettings(LB.settingsHeader)
	page:SetScript("OnSizeChanged", function(self)
		if not self:IsShown() then
			return
		end
		local width = self.scroll and self.scroll:GetWidth()
		if not width or width < 40 then
			width = self:GetWidth()
		end
		if catalogWidth and type(width) == "number" and math.abs(width - catalogWidth) < 1 then
			return
		end
		LayoutCatalog(nil, true)
	end)
	LB.page = page
end

local function AnchorPage(book)
	local page = LB.page
	if not page then
		return
	end
	page:ClearAllPoints()
	local spec = Logic.CATALOG_PAGE
	page:SetPoint("TOPLEFT", book, "TOPLEFT", spec.left, spec.top)
	page:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", spec.right, spec.bottom)
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

-- IsShown stays true on the page after the book closes. IsVisible follows the book.
function LB.CatalogVisible()
	return LB.page ~= nil and LB.page:IsVisible() and true or false
end

function LB.SetCatalogView(view)
	LB.catalogView = view
	if not LB.page or not LB.page:IsShown() then
		return
	end
	LayoutCatalog(LB.catalogItems, false)
	if view ~= "help" or not C_Timer or not C_Timer.After then
		return
	end
	-- Wrapped text reports its height one frame late.
	C_Timer.After(0, function()
		if LB.catalogView == "help" and LB.CatalogVisible() then
			LayoutCatalog(LB.catalogItems, false)
		end
	end)
end

LB.CatalogUp, LB.ClearBlizzardPage, LB.FinishDrop, LB.HideCatalog = CatalogUp, ClearBlizzardPage, FinishDrop, HideCatalog
LB.HideLooseChrome, LB.HideReceive, LB.LayoutCatalog = HideLooseChrome, HideReceive, LayoutCatalog
LB.RefreshLayoutChrome, LB.ShowCatalog, LB.UpdateCooldowns, LB.receive = RefreshLayoutChrome, ShowCatalog, UpdateCooldowns, receive
