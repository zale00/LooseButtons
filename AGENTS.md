# Loose Buttons

Forever addon. Lua 5.1. Mainline 12.1.x API, secret values on. Not Classic Era.

The Origin tree keeps the addon in `LooseButtons/`. The GitHub repo `zale00/LooseButtons` keeps the same files at the repo root.

## Interface

Keep `## X-Flavor: Mainline`. The TOC interface is the Forever beta number. It is `16001` for game version `1.60.1`. `.github/forever-monitor.sh` is the only automation that bumps `## Interface:` and `## Version:` when that number changes. Pause it by setting the Actions variable `FOREVER_MONITOR` to `off`, or by committing an empty `.github/FOREVER_MONITOR_PAUSE`.

Forever beta build `1.60.1.70170` (`Gethe/wow-ui-source` `forever`, `9a789c07`, 2026-10-01) is version `1.60.1`. [TOC format](https://warcraft.wiki.gg/wiki/TOC_format) lists Forever Beta as `16001` (`1.60.1`) and Standard as `120100`. The Forever client marks a `120100` TOC incompatible. That retail number is not the load path.

Do not add `Interface-Forever` or a `_Camelot.toc`. This addon is Forever only, so the one TOC is what the client reads. Camelot is the game type. The same dump sets `WOW_PROJECT_CAMELOT = 18` and `WOW_PROJECT_ID` to that value.

CurseForge metadata is the Forever row (`gameVersionTypeID` `88568`) whose name is the live game version. The upload script looks that row up, refuses retail type `517`, and does not fall back to another Forever version. Packager v2.6.1 maps interface `16???` to Forever and prints game version `1.60.1`. The upload passes `-d` and unsets `CF_API_KEY`, so the packager does not upload. Its own uploader falls back to a different Forever version when the exact name is missing. Do not bump `## Version:` for lint or CI. On GitHub, the changelog heading and the TOC version stay the same string.

`Bindings.xml` is loaded by the client. Leave it out of the TOC file list.

## Three restrictions

Secret values, combat lockdown, and protected actions are different rules.

- Call `issecretvalue()` before arithmetic or other use of a secret return. `UnitHealth` looks like a number. `pcall` does not make the arithmetic legal.
- Call `InCombatLockdown()` before changing protected UI.
- Launcher clicks that open a panel stay on the secure click path.

## APIs

Do not invent APIs. Read warcraft.wiki.gg or `Gethe/wow-ui-source` branch `forever` before adding a call. `version.txt` on that branch is the client build. The TOC interface is the Forever Beta number for that version, which is `16001` for `1.60.1`.

Fetch a sparse checkout with `tools/fetch-forever-ui-source.sh`. It writes `.cache/wow-ui-source`, which is gitignored. Grep that tree. Camelot files are the Forever overrides: `Blizzard_PlayerSpells/Camelot/` and `Blizzard_EditMode` load lines marked `camelot`. `SecureActionButtonTemplate` is in `Blizzard_FrameXML/SecureTemplates.xml`. `UnitHealth` is `SecretReturns = true` in `UnitDocumentation.lua`. `CreateFrame` is an engine global; the dump shows call sites, not its definition.

`@nighthawk42/wow-api-mcp` flavor `forever` can answer a signature. Its bundled data can lag the branch (seen: build 1.60.1.70009 while the branch was already `1.60.1.70170`). The first source search in that server downloads about 200MB; the script above is the smaller grep path.

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
