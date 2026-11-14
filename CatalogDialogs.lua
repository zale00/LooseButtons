local Logic = LooseButtonsLogic
local LB = Logic.LB

-- Layout menu, share and import dialogs, and the help frame for the catalog strip.
-- Catalog.lua loads after this file and sets LB.RefreshLayoutChrome.

local function PresentLayout()
	if LB.poolReady then
		LB.ApplyAll()
	else
		LB.EnsurePool()
	end
	LB.RefreshLayoutChrome()
end

local function layoutLoadedText()
	local text = "Loaded. Quick Keybind keys stay on their slots."
	local buttons = LB.DB().buttons
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
	local created, detail = Logic.Layouts.Create(LB.Account(), LB.CharKey(), typed, nil, InCombatLockdown())
	if not created then
		LB.Say(detail)
		return
	end
	LB.RefreshLayoutChrome()
end

local function CommitImport(pasted, typed)
	local profile, sharedName = Logic.ShareCodec.Decode(pasted)
	if not profile then
		LB.Say(sharedName)
		return
	end
	local name = typed
	if NameIsBlank(name) then
		name = sharedName
	end
	local created, detail = Logic.Layouts.Create(LB.Account(), LB.CharKey(), name, profile, InCombatLockdown())
	if not created then
		LB.Say(detail)
		return
	end
	PresentLayout()
	LB.Say(layoutLoadedText())
end

local function CommitDelete(name)
	local effect, detail = Logic.Layouts.Delete(LB.Account(), LB.CharKey(), name, InCombatLockdown())
	if not effect then
		LB.Say(detail)
		return
	end
	if effect == "cleared" then
		PresentLayout()
		LB.Say("Removed that layout.")
		return
	end
	LB.RefreshLayoutChrome()
end

local function ConfirmDelete(name)
	if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
		CommitDelete(name)
		return
	end
	local dialog = StaticPopupDialogs["LOOSEBUTTONS_LAYOUT_DELETE"]
	dialog.text = Logic.Layouts.DeleteText(LB.Account(), LB.CharKey(), name)
	StaticPopup_Show("LOOSEBUTTONS_LAYOUT_DELETE", nil, nil, { name = name })
end

local function OpenNewLayout()
	if type(StaticPopup_Show) == "function" then
		StaticPopup_Show("LOOSEBUTTONS_LAYOUT_NAME")
		return
	end
	LB.Say("Enter a name.")
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
	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
	hint:SetText("Press Ctrl+C to copy.")
	local box = CreateFrame("EditBox", nil, frame)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetSize(388, 90)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -56)
	box:SetTextInsets(6, 6, 6, 6)
	box:SetMaxLetters(20000)
	local shareBg = box:CreateTexture(nil, "BACKGROUND")
	shareBg:SetAllPoints(box)
	shareBg:SetColorTexture(0, 0, 0, 0.45)
	frame.box = box
	BindEscape(box, frame)
	AttachDialogChrome(frame)
	LB.FitDialog(frame, box, 16)
	frame:Hide()
	LB.shareFrame = frame
	return frame
end

local function OpenShare()
	local name = Logic.Layouts.ActiveName(LB.Account(), LB.CharKey())
	if not name then
		LB.Say("Nothing to share yet.")
		return
	end
	local text, reason = Logic.ShareCodec.Encode(Logic.Profile(LB.DB()), name)
	if not text then
		LB.Say(reason)
		return
	end
	local frame = EnsureShareFrame()
	frame.box:SetText(text)
	frame:Show()
	frame.box:SetFocus()
	frame.box:HighlightText()
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
	local profile, changed = Logic.Layouts.Switch(LB.Account(), LB.CharKey(), name, InCombatLockdown())
	if not profile then
		LB.Say(changed)
		return
	end
	if changed then
		PresentLayout()
		LB.Say(layoutLoadedText())
	end
end

local function LayoutMenu(_, root)
	if type(root) ~= "table" or type(root.CreateRadio) ~= "function" then
		return
	end
	local names = Logic.Layouts.Names(LB.Account())
	local i
	for i = 1, #names do
		local name = names[i]
		root:CreateRadio(name, function(picked)
			return Logic.Layouts.ActiveName(LB.Account(), LB.CharKey()) == picked
		end, function(picked)
			SelectLayout(picked)
		end, name)
	end
	if type(root.CreateDivider) == "function" then
		root:CreateDivider()
	end
	root:CreateRadio(Logic.BLANK_LAYOUT, function()
		return Logic.Layouts.ActiveName(LB.Account(), LB.CharKey()) == nil
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

local function HelpViewLimit()
	local h
	if UIParent and UIParent.GetHeight then
		h = UIParent:GetHeight()
	end
	if type(issecretvalue) == "function" and issecretvalue(h) then
		return nil
	end
	if type(h) ~= "number" or h < 200 then
		return nil
	end
	return h - 80
end

local function TextBlockHeight(fontString)
	local h
	if fontString and fontString.GetStringHeight then
		h = fontString:GetStringHeight()
	end
	if type(issecretvalue) == "function" and issecretvalue(h) then
		return 16
	end
	if type(h) ~= "number" or h < 1 then
		return 16
	end
	return h
end

local function LayoutHelp(frame, deferred)
	local rows = Logic.HELP
	local content = frame.helpContent
	local lines = frame.helpLines
	local y = 0
	local i
	for i = 1, #rows do
		local spec = rows[i]
		local line = lines[i]
		if not line then
			line = {
				gesture = content:CreateFontString(nil, "OVERLAY", "GameFontNormal"),
				detail = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
			}
			line.gesture:SetJustifyH("LEFT")
			line.detail:SetJustifyH("LEFT")
			if line.gesture.SetJustifyV then
				line.gesture:SetJustifyV("TOP")
			end
			if line.detail.SetJustifyV then
				line.detail:SetJustifyV("TOP")
			end
			lines[i] = line
		end
		if line.gesture.SetWidth then
			line.gesture:SetWidth(180)
		end
		if line.detail.SetWidth then
			line.detail:SetWidth(410)
		end
		line.gesture:SetText(spec.gesture)
		line.detail:SetText(spec.detail)
		local gestureH = TextBlockHeight(line.gesture)
		local detailH = TextBlockHeight(line.detail)
		local textH = gestureH
		if detailH > textH then
			textH = detailH
		end
		if textH < 20 then
			textH = 20
		end
		if line.gesture.SetHeight then
			line.gesture:SetHeight(textH)
		end
		if line.detail.SetHeight then
			line.detail:SetHeight(textH)
		end
		line.gesture:ClearAllPoints()
		line.detail:ClearAllPoints()
		line.gesture:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -y)
		line.detail:SetPoint("TOPLEFT", content, "TOPLEFT", 210, -y)
		y = y + textH + 4
	end
	if y < 1 then
		y = 1
	end
	content:SetHeight(y)
	local full = 36 + y + 12
	local limit = HelpViewLimit()
	local height = full
	if limit and full > limit then
		height = limit
	end
	frame:SetSize(640, height)
	local visible = height - 48
	if visible < 1 then
		visible = 1
	end
	local maxScroll = y - visible
	if maxScroll < 0 then
		maxScroll = 0
	end
	frame.helpScrollMax = maxScroll
	local offset = frame.helpOffset or 0
	if offset < 0 then
		offset = 0
	end
	if offset > maxScroll then
		offset = maxScroll
	end
	frame.helpOffset = offset
	local scroll = frame.helpScroll
	scroll:SetSize(624, visible)
	if scroll.SetVerticalScroll then
		scroll:SetVerticalScroll(offset)
	end
	if scroll.EnableMouseWheel then
		scroll:EnableMouseWheel(maxScroll > 0)
	end
	if not deferred and C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if frame:IsShown() then
				LayoutHelp(frame, true)
			end
		end)
	end
end

local function EnsureHelpFrame()
	if LB.helpFrame then
		return LB.helpFrame
	end
	local frame = CreateFrame("Frame", "LooseButtonsHelp", UIParent)
	frame:SetSize(640, 48)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.06, 0.05, 0.04, 0.94)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	title:SetText("Help")
	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -36)
	scroll:EnableMouse(true)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(624, 1)
	if scroll.SetScrollChild then
		scroll:SetScrollChild(content)
	end
	frame.helpScroll = scroll
	frame.helpContent = content
	frame.helpLines = {}
	scroll:SetScript("OnMouseWheel", function(_, delta)
		local maxScroll = frame.helpScrollMax or 0
		if maxScroll <= 0 or type(delta) ~= "number" then
			return
		end
		local offset = (frame.helpOffset or 0) - delta * 48
		if offset < 0 then
			offset = 0
		end
		if offset > maxScroll then
			offset = maxScroll
		end
		frame.helpOffset = offset
		LayoutHelp(frame, true)
	end)
	frame:SetScript("OnShow", function(self)
		LayoutHelp(self, false)
	end)
	AttachDialogChrome(frame)
	LayoutHelp(frame, true)
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

LB.LayoutMenu, LB.OpenHelp, LB.ToggleHelp = LayoutMenu, OpenHelp, ToggleHelp
