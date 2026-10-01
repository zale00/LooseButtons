# Loose Buttons

Forever addon. Lua 5.1. Mainline 12.1.x API, secret values on. Not Classic Era.

The Origin tree keeps the addon in `LooseButtons/`. The GitHub repo `zale00/LooseButtons` keeps the same files at the repo root.

## Interface

Keep `## Interface: 120100` and `## X-Flavor: Mainline`.

The Forever client loads this addon with `120100`. CurseForge metadata is game version `1.60.1`, type Forever. The upload script sends that row. Packager `-g 1.60.1` rewrites a zip's `Interface` line to `16001`. That zip does not match the load path.

Do not set `## Interface: 16001`, `Interface-Forever`, or a `_Camelot.toc`. Camelot is Blizzard's game type for Forever. A tool that lists Forever's interface as `16001` is not a load proof for this addon. Do not bump `## Version:` for lint or CI. On GitHub, the changelog heading and the TOC version stay the same string.

`Bindings.xml` is loaded by the client. Leave it out of the TOC file list.

## Three restrictions

Secret values, combat lockdown, and protected actions are different rules.

- Call `issecretvalue()` before arithmetic or other use of a secret return. `UnitHealth` looks like a number. `pcall` does not make the arithmetic legal.
- Call `InCombatLockdown()` before changing protected UI.
- Launcher clicks that open a panel stay on the secure click path.

## APIs

Do not invent APIs. Read warcraft.wiki.gg or `Gethe/wow-ui-source` branch `forever` before adding a call. That branch is a reference. It does not change the TOC interface.

Fetch a sparse checkout (about 14MB at 1.60.1.70124) with `tools/fetch-forever-ui-source.sh`. It writes `.cache/wow-ui-source`, which is gitignored. Grep that tree. Camelot files are the Forever overrides: `Blizzard_PlayerSpells/Camelot/` and `Blizzard_EditMode` load lines marked `camelot`. `SecureActionButtonTemplate` is in `Blizzard_FrameXML/SecureTemplates.xml`. `UnitHealth` is `SecretReturns = true` in `UnitDocumentation.lua`. `CreateFrame` is an engine global; the dump shows call sites, not its definition.

`@nighthawk42/wow-api-mcp` flavor `forever` can answer a signature. Its bundled data can lag the branch (seen: build 1.60.1.70009, interface `16001`). That `16001` is the tool's flavor constant. It is not a TOC edit. The first source search in that server downloads about 200MB; the script above is the smaller grep path.

Secret behavior notes: [Secret values](https://warcraft.wiki.gg/wiki/Secret_values). `issecretvalue` before arithmetic. A wiki MCP lookup of that name can be only a redirect.

Keep new functions local, or on `LooseButtonsLogic` / the addon table. SavedVariables initialize from the restored table, not from a file-scope default that restoration replaces.

## Offline checks

From the Origin root:

```text
luacheck LooseButtons
lua5.1 tools/check_loosebuttons.lua
```

From the GitHub root, `luacheck .` uses the same `.luacheckrc`.

Luacheck fails on a syntax error, an unknown global, and a new accidental global. It does not fail on unused locals, shadowing, or line length. GitHub CI also runs wow-secret-lint with `--patch=auto --strict --max-warnings=0`. Secret arithmetic fails that job. The linter's default mode does not.

A clean luacheck run is not a Forever `/reload`. Say which of those you actually did.

These still need the Forever client. They match recorded BugGrabber failures. Lint does not cover them.

- Player frame and Edit Mode party frames: no secret compare tainted by LooseButtons (`TextStatusBar`, `CompactUnitFrame`).
- Launcher clicks: no `ADDON_ACTION_FORBIDDEN` (`ToggleGameMenu`, `ClearTarget`, `PlayerSpellsFrame` size, `PetActionBar:SetShownBase`).
- Loose Buttons spellbook tab: catalog replaces the skill line, the page is not blank, and textures are not set to nil.
- Scale slider and shift-snap: the slider value is a number, and the snap guide does not throw.
