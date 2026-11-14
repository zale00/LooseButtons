-- Lua 5.1 + the globals this addon calls.
-- Undefined globals and syntax errors still fail.
-- Unused locals, shadowing, and line length do not: the shipped files
-- have over a hundred of each, and silencing code 113 would hide typos.
std = "lua51"
max_line_length = false
codes = true
ignore = {
    "212/self",
    "421",
    "431",
    "512",
    "311",
    "211",
    "213",
}
globals = {
    "LooseButtonsLogic",
    "LooseButtonsDB",
    "LooseBagsLogic",
    "LooseBagsDB",
    "SLASH_LOOSEBAGS1",
    "SLASH_LOOSEBAGS2",
    "ToggleBackpack",
    "ToggleBag",
    "OpenBag",
    "OpenAllBags",
    "ToggleAllBags",
    "CloseAllBags",
    "OpenBackpack",
    "BINDING_HEADER_LOOSEBUTTONS",
    "BINDING_HEADER_LOOSEBUTTONSLAUNCHERS",
    "SLASH_LOOSEBUTTONS1",
    "SLASH_LOOSEBUTTONS2",
    "StaticPopupDialogs",
    "SlashCmdList",
}
read_globals = {
    "ACCEPT",
    "CANCEL",
    "C_ActionBar",
    "C_AddOns",
    "C_Container",
    "C_CurveUtil",
    "C_EncodingUtil",
    "C_Item",
    "C_Spell",
    "C_SpellBook",
    "C_Timer",
    "ClearCursor",
    "ClearOverrideBindings",
    "CreateFrame",
    "Enum",
    "EventUtil",
    "GameMenuFrame",
    "GameTooltip",
    "GameTooltip_AddHighlightLine",
    "GetBindingIndex",
    "GetBindingKey",
    "GetBindingName",
    "GetBindingText",
    "GetCurrentBindingSet",
    "GetCursorPosition",
    "GetItemCount",
    "GetMacroInfo",
    "GetMacroSpell",
    "GetPetActionSlotUsable",
    "GetMouseFoci",
    "GetRealmName",
    "InCombatLockdown",
    "IsAltKeyDown",
    "IsControlKeyDown",
    "IsShiftKeyDown",
    "KeybindFrames_InQuickKeybindMode",
    "MenuUtil",
    "MinimalSliderWithSteppersMixin",
    "NO",
    "ACTIONBAR_HOTKEY_FONT_COLOR",
    "GetPetActionInfo",
    "PET",
    "PetHasSpellbook",
    "PickupMacro",
    "PickupPetAction",
    "RED_FONT_COLOR",
    "TOOLTIP_UPDATE_TIME",
    "PlaceAction",
    "PlayerSpellsFrame",
    "QuickKeybindFrame",
    "QuickKeybindTooltip",
    "SPELLBOOK_FONT_COLOR",
    "SLASH_USE1",
    "SaveBindings",
    "ScrollUtil",
    "SecureHandlerWrapScript",
    "SetBinding",
    "SetOverrideBinding",
    "SetOverrideBindingClick",
    "SetPortraitTexture",
    "StaticPopup_Hide",
    "StaticPopup_Show",
    "ToggleLegacySystemUI",
    "UIParent",
    "UnitClass",
    "UnitName",
    "YES",
    "hooksecurefunc",
    "issecretvalue",
    "securecall",
    "COMBINED_BAG_TITLE",
    "SetItemButtonTexture",
    "SetItemButtonCount",
    "SetItemButtonQuality",
    "SetItemButtonDesaturated",
    "HandleModifiedItemClick",
    "CursorHasItem",
    "StackSplitFrame",
    "OpenStackSplitFrame",
    "PlaySound",
    "SOUNDKIT",
    "ContainerFrameCombinedBags",
    "GameTooltip_Hide",
    "NUM_BAG_FRAMES",
    "NUM_CONTAINER_FRAMES",
    "ChatEdit_GetActiveWindow",
    "IsModifiedClick",
    "IsMouseButtonDown",
    "IsShiftKeyDown",
    "IsControlKeyDown",
    "IsAltKeyDown",
    "MoneyFrame_Update",
}

local binding_save_stubs = {
    globals = {
        "CreateFrame",
        "GetBindingKey",
        "GetCurrentBindingSet",
        "GetRealmName",
        "InCombatLockdown",
        "SaveBindings",
        "SetBinding",
        "UIParent",
        "UnitName",
    },
}

files["LooseButtons/devcheck/check_binding_save.lua"] = binding_save_stubs
files["devcheck/check_binding_save.lua"] = binding_save_stubs

-- The LooseBags combat checks build the client from tools/blizzard_stub.lua.
-- They only assign the default bag frame they mark protected.
local combat_stubs = {
    globals = {
        "ContainerFrameCombinedBags",
    },
}

files["LooseBags/devcheck/check_combat_layout.lua"] = combat_stubs
files["LooseBags/devcheck/check_combat_use.lua"] = combat_stubs

-- tools/check_*.lua stand in for the client. They assign the client globals
-- they stub, so those names are writable there. A name that is read but never
-- assigned anywhere in the file is still W113.
-- 131: a stub the addon reads is never read by the check itself.
-- 432: a nested stub method names its own self.
files["tools"] = {
    allow_defined_top = true,
    allow_defined = true,
    globals = read_globals,
    ignore = { "131", "432" },
}
