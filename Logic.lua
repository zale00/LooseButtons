local Logic = {}
LooseButtonsLogic = Logic

Logic.ACTION_SLOTS = 48
Logic.LAUNCHER_SLOTS = 24

Logic.ANCHORS = {
	CENTER = true,
	TOP = true,
	BOTTOM = true,
	LEFT = true,
	RIGHT = true,
	TOPLEFT = true,
	TOPRIGHT = true,
	BOTTOMLEFT = true,
	BOTTOMRIGHT = true,
}

Logic.SECTION_ORDER = {
	"Character & info",
}

Logic.SECTION_STACK = {
	labelGap = 2,
	controlGap = 8,
	check = 26,
	sliderW = 180,
	sliderH = 36,
	dropW = 150,
	dropH = 25,
	stackGap = 2,
	sliderNudge = 4,
	sliderCap = 9,
	titleLine = 22,
	band = 14,
	divider = 11,
	plain = 51,
}

Logic.MACRO_SECTIONS = {
	{ scope = "general", title = "General Macros" },
	{ scope = "character", title = "Character Macros" },
}

Logic.ITEM_CLASS_CONSUMABLE = 0

Logic.LAUNCHERS = {
	{ command = "TOGGLECHARACTER0", name = "Character", section = "Character & info", chrome = "micro", portrait = true, click = "character" },
	{ command = "TOGGLESPELLBOOK", name = "Spellbook", section = "Character & info", chrome = "micro", atlas = "SpellbookAbilities", click = "spellbook" },
	{ command = "TOGGLETALENTS", name = "Talents", section = "Character & info", chrome = "micro", atlas = "SpecTalents", click = "talents" },
	{ command = "TOGGLEPROFESSIONBOOK", name = "Professions", section = "Character & info", chrome = "micro", atlas = "Professions", click = "professions" },
	{ command = "TOGGLELEGACYSYSTEM", name = "Legacy", section = "Character & info", chrome = "micro", atlas = "Legacy", click = "legacy" },
	{ command = "TOGGLEQUESTLOG", name = "Quest log", section = "Character & info", chrome = "micro", atlas = "Questlog", click = "quest" },
	{ command = "TOGGLEBACKPACK", name = "Backpack", section = "Items", chrome = "bag", click = "backpack" },
	{ command = "TOGGLEGUILDTAB", name = "Guild", section = "Character & info", chrome = "micro", atlas = "GuildCommunities", click = "guild" },
	{ command = "TOGGLECOLLECTIONS", name = "Collections", section = "Character & info", chrome = "micro", atlas = "Collections", click = "collections" },
	{ command = "TOGGLEGAMEMENU", name = "Game menu", section = "Character & info", chrome = "micro", atlas = "GameMenu", click = "gamemenu" },
}

Logic.EXTRA_LAUNCHERS = {
	{ command = "TOGGLEACHIEVEMENT", name = "Achievements", section = "Character & info", chrome = "micro", atlas = "Achievements", click = "achievements" },
	{ command = "TOGGLEENCOUNTERJOURNAL", name = "Adventure guide", section = "Character & info", chrome = "micro", atlas = "AdventureGuide", click = "journal" },
	{ command = "TOGGLEHOUSINGDASHBOARD", name = "Housing", section = "Character & info", chrome = "micro", atlas = "Housing", click = "housing" },
	{ command = "TOGGLEGROUPFINDER", name = "Group finder", section = "Character & info", chrome = "micro", atlas = "Groupfinder", click = "finder" },
}

function Logic.Pool(kind)
	if kind == "launcher" then
		return "launcher"
	end
	return "action"
end

function Logic.SlotLimit(kind)
	if Logic.Pool(kind) == "launcher" then
		return Logic.LAUNCHER_SLOTS
	end
	return Logic.ACTION_SLOTS
end

function Logic.FrameName(kind, slot)
	if Logic.Pool(kind) == "launcher" then
		return "LooseButtonsLauncher" .. slot
	end
	return "LooseButtonsAction" .. slot
end

function Logic.ClickBinding(frameName)
	if type(frameName) ~= "string" or frameName == "" then
		return nil
	end
	return "CLICK " .. frameName .. ":LeftButton"
end

function Logic.BindingLabel(kind, slot)
	if Logic.Pool(kind) == "launcher" then
		return "Launcher " .. slot
	end
	return "Button " .. slot
end

function Logic.BindingToken(input, alt, ctrl, shift)
	if type(input) ~= "string" or input == "" or input == "UNKNOWN" then
		return nil
	end
	if input == "LSHIFT" or input == "RSHIFT" or input == "SHIFT" or input == "LCTRL" or input == "RCTRL" or input == "CTRL" or input == "LALT" or input == "RALT" or input == "ALT" then
		return nil
	end
	if input == "ESCAPE" then
		return "CLEAR"
	end
	if input == "LeftButton" or input == "RightButton" or input == "Button1" or input == "Button2" then
		return nil
	end
	local key = input
	if input == "MiddleButton" then
		key = "BUTTON3"
	else
		local number = tonumber(string.match(input, "^Button(%d+)$"))
		if number then
			if number < 4 or number > 31 then
				return nil
			end
			key = "BUTTON" .. number
		else
			number = tonumber(string.match(input, "^BUTTON(%d+)$"))
			if number and (number < 3 or number > 31) then
				return nil
			end
		end
	end
	local parts = {}
	if alt then
		table.insert(parts, "ALT")
	end
	if ctrl then
		table.insert(parts, "CTRL")
	end
	if shift then
		table.insert(parts, "SHIFT")
	end
	table.insert(parts, key)
	return table.concat(parts, "-")
end
