local seamFile = "Blizzard.lua"

local tokens = {
	"hooksecurefunc",
	"PlayerSpellsFrame",
	"ToggleGameMenu",
	"RegisterGameMenuEscHandler",
	"UISpecialFrames",
	"securecall",
	"CopyToClipboard",
	"PetActionBar",
	"SetShownBase",
}

local function say(message)
	io.stdout:write(message, "\n")
	io.stdout:flush()
end

local function readFile(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local text = handle:read("*a")
	handle:close()
	return text
end

local root
if readFile("LooseButtons/LooseButtons.toc") then
	root = "LooseButtons"
elseif readFile("LooseButtons.toc") then
	root = ""
end

local function addonPath(name)
	if not root or root == "" then
		return name
	end
	return root .. "/" .. name
end

local function baseName(path)
	return path:match("([^/]+)$") or path
end

local function targetPaths()
	local paths = {}
	if arg and #arg > 0 then
		for index = 1, #arg do
			paths[#paths + 1] = arg[index]
		end
		return paths
	end
	if not root then
		return nil
	end
	local toc = readFile(addonPath("LooseButtons.toc"))
	if not toc then
		return nil
	end
	for line in toc:gmatch("[^\r\n]+") do
		local name = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
		if name then
			paths[#paths + 1] = addonPath(name)
		end
	end
	return paths
end

-- Whole identifiers only: LB.PetActionBarSlot is not PetActionBar.
local function hasToken(text, token)
	return text:find("%f[%w_]" .. token .. "%f[^%w_]") ~= nil
end

local function tokenHits(text)
	local hits = {}
	for index = 1, #tokens do
		if hasToken(text, tokens[index]) then
			hits[#hits + 1] = tokens[index]
		end
	end
	return hits
end

local function hitsIn(path)
	if baseName(path) == seamFile then
		return {}
	end
	local text = readFile(path)
	if not text then
		return nil
	end
	return tokenHits(text)
end

local selfTest = {
	{ "LB.PetActionBarSlot = 1", 0 },
	{ "PetActionBar:SetShownBase(true)", 2 },
	{ "local x = PetActionBar", 1 },
	{ "hooksecurefunc(a, b)", 1 },
}
for index = 1, #selfTest do
	local got = #tokenHits(selfTest[index][1])
	if got ~= selfTest[index][2] then
		say("token match is wrong for " .. selfTest[index][1] .. ": " .. got)
		os.exit(1)
	end
end

local paths = targetPaths()
if not paths then
	say("missing TOC")
	os.exit(1)
end
if #paths == 0 then
	say("no lua files")
	os.exit(1)
end

local failed = false
for _, path in ipairs(paths) do
	local name = baseName(path)
	local hits = hitsIn(path)
	if not hits then
		failed = true
		say(name .. " is unreadable")
	else
		for _, token in ipairs(hits) do
			failed = true
			say(name .. " has " .. token .. " outside " .. seamFile .. ". Edit " .. seamFile .. ".")
		end
	end
end

if failed then
	os.exit(1)
end
say("blizzard seam ok")
os.exit(0)
