local function readFile(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local text = handle:read("*a")
	handle:close()
	return text
end

local root = ""
if readFile("LooseButtons/Logic.lua") then
	root = "LooseButtons/"
end

local function addonPath(name)
	return root .. name
end

local failures = {}

local function fail(message)
	failures[#failures + 1] = message
	io.stderr:write("FAIL " .. message .. "\n")
end

local function check(ok, message)
	if not ok then
		fail(message)
	end
end

local made = {}

local function widget()
	local self = { scripts = {}, events = {} }
	return setmetatable(self, {
		__index = function(frame, key)
			if key == "SetScript" then
				return function(_, name, fn)
					frame.scripts[name] = fn
				end
			end
			if key == "GetScript" then
				return function(_, name)
					return frame.scripts[name]
				end
			end
			if key == "RegisterEvent" then
				return function(_, event)
					frame.events[event] = true
				end
			end
			if key == "Hide" or key == "Show" or key == "SetFrameStrata" or key == "SetAllPoints" or key == "EnableMouse" or key == "EnableKeyboard" then
				return function() end
			end
			return function()
				return frame
			end
		end,
	})
end

function CreateFrame(_, name)
	local frame = widget()
	made[#made + 1] = frame
	if type(name) == "string" then
		_G[name] = frame
	end
	return frame
end

UIParent = widget()
SlashCmdList = {}

local WHO = "Maximus-Classic Beta PvE 2"
local currentSet
local saves
local mutations
local saveExplodes
local saving
local eventsFrame

function UnitName()
	return "Maximus"
end

function GetRealmName()
	return "Classic Beta PvE 2"
end

function InCombatLockdown()
	return false
end

function GetCurrentBindingSet()
	return currentSet
end

function SaveBindings(which)
	if which ~= 1 and which ~= 2 then
		error("Usage: SaveBindings(1|2)", 2)
	end
	if saveExplodes then
		error("SaveBindings failed", 2)
	end
	if saving then
		error("SaveBindings reentered", 2)
	end
	saves[#saves + 1] = which
	saving = true
	local frame = eventsFrame()
	if frame and frame.scripts.OnEvent then
		frame.scripts.OnEvent(frame, "UPDATE_BINDINGS")
	end
	saving = false
end

local bindings = {}

function GetBindingKey(command)
	local key, bound
	local found = {}
	for key, bound in pairs(bindings) do
		if bound == command then
			found[#found + 1] = key
		end
	end
	table.sort(found)
	return unpack(found)
end

function SetBinding(key, command)
	mutations[#mutations + 1] = command or false
	if command then
		bindings[key] = command
	else
		bindings[key] = nil
	end
	return true
end

function eventsFrame()
	local found
	local i
	for i = 1, #made do
		local frame = made[i]
		if frame.events.UPDATE_BINDINGS and frame.scripts.OnEvent then
			found = frame
		end
	end
	return found
end

local function boot()
	currentSet = nil
	saves = {}
	mutations = {}
	saveExplodes = false
	saving = false
	bindings = {}
	LooseButtonsDB = nil
	dofile(addonPath("Logic.lua"))
	dofile(addonPath("LooseButtons.lua"))
	dofile(addonPath("Binds.lua"))
	local Logic = LooseButtonsLogic
	local LB = Logic.LB
	local command = Logic.ClickBinding(Logic.FrameName("spell", 1))
	LooseButtonsDB = {
		chars = {
			[WHO] = { binds = { [command] = "F" } },
		},
	}
	LB.FollowRanks = function() end
	LB.EnsurePool = function() end
	LB.ApplyAll = function() end
	LB.RefreshLayoutChrome = function() end
	LB.ClearSnapPlan = function() end
	LB.RefreshHotkeys = function() end
	LB.RefreshPortraits = function() end
	return LB, command
end

local function fire(event)
	local frame = eventsFrame()
	if not frame then
		fail("events frame missing for " .. event)
		return
	end
	frame.scripts.OnEvent(frame, event)
end

local function joined(list)
	local parts = {}
	local i
	for i = 1, #list do
		parts[#parts + 1] = tostring(list[i])
	end
	return table.concat(parts, ",")
end

local function login(set)
	local LB = boot()
	currentSet = set
	local ok, err = pcall(fire, "PLAYER_LOGIN")
	return LB, ok, err
end

local function expectHeld(label, set)
	local LB, ok, err = login(set)
	local Logic = LooseButtonsLogic
	check(ok, label .. " login errored: " .. tostring(err))
	check(#saves == 0, label .. " called SaveBindings(" .. joined(saves) .. ")")
	check(#mutations == 0, label .. " changed " .. tostring(#mutations) .. " bindings")
	check(not LB.bindsApplying, label .. " left bindsApplying set")
	check(LB.bindsPending == true, label .. " did not keep the apply pending")
	check(Logic.Binds.Read(LB.Account(), WHO)[Logic.ClickBinding(Logic.FrameName("spell", 1))] == "F", label .. " overwrote the saved key")
	return LB
end

expectHeld("nil binding set", nil)
expectHeld("default binding set", 0)
expectHeld("current binding set", 3)

local function expectSaved(label, set)
	local LB, ok, err = login(set)
	check(ok, label .. " login errored: " .. tostring(err))
	check(#saves == 1 and saves[1] == set, label .. " saved [" .. joined(saves) .. "]")
	check(#mutations > 0, label .. " did not apply the saved key")
	check(not LB.bindsApplying, label .. " left bindsApplying set")
	check(not LB.bindsPending, label .. " stayed pending after a save")
	check(LB.bindsReady == true, label .. " did not mark binds ready")
	local againOk, againErr = pcall(LB.ApplyCharacterBinds)
	check(againOk, label .. " second apply errored: " .. tostring(againErr))
	check(#saves == 1, label .. " saved again on a repeat apply [" .. joined(saves) .. "]")
end

expectSaved("account binding set", 1)
expectSaved("character binding set", 2)

local LB, ok, err = login(2)
saveExplodes = true
saves = {}
mutations = {}
LB.bindsReady = nil
LB.bindsPending = nil
bindings = {}
ok, err = pcall(LB.ApplyCharacterBinds)
check(ok, "failed save errored out: " .. tostring(err))
check(not LB.bindsApplying, "failed save left bindsApplying set")
check(#saves == 0, "failed save recorded a write")
check(LB.bindsPending == true, "failed save did not stay pending")
saveExplodes = false
ok, err = pcall(LB.ApplyCharacterBinds)
check(ok, "retry after a failed save errored: " .. tostring(err))
check(#saves == 1 and saves[1] == 2, "retry after a failed save saved [" .. joined(saves) .. "]")
check(not LB.bindsApplying, "retry after a failed save left bindsApplying set")
check(not LB.bindsPending, "retry after a failed save stayed pending")

local function retry(label, event)
	local pending = boot()
	currentSet = nil
	local firstOk, firstErr = pcall(fire, "PLAYER_LOGIN")
	check(firstOk, label .. " login errored: " .. tostring(firstErr))
	check(#saves == 0, label .. " saved before the set was known")
	check(pending.bindsPending == true, label .. " login did not stay pending")
	currentSet = 2
	local nextOk, nextErr = pcall(fire, event)
	check(nextOk, label .. " " .. event .. " errored: " .. tostring(nextErr))
	check(#saves == 1 and saves[1] == 2, label .. " " .. event .. " saved [" .. joined(saves) .. "]")
	check(not pending.bindsApplying, label .. " left bindsApplying set")
	check(not pending.bindsPending, label .. " stayed pending after the set was known")
	check(LooseButtonsLogic.Binds.Read(pending.Account(), WHO)[LooseButtonsLogic.ClickBinding(LooseButtonsLogic.FrameName("spell", 1))] == "F", label .. " overwrote the saved key")
end

retry("bindings update", "UPDATE_BINDINGS")
retry("entering world", "PLAYER_ENTERING_WORLD")

if #failures > 0 then
	io.stderr:write(#failures .. " binding save failure(s)\n")
	os.exit(1)
end

print("binding save ok")
