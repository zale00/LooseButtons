local Logic = {}
LooseButtonsLogic = Logic

function Logic.BindingToken(input, alt, ctrl, shift)
	if type(input) ~= "string" or input == "" or input == "UNKNOWN" then
		return nil
	end
	return input
end
