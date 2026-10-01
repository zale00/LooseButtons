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
