local Logic = {}
LooseButtonsLogic = Logic

Logic.ACTION_SLOTS = 48
Logic.LAUNCHER_SLOTS = 24

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
