# Escape!

Roblox game synced with Rojo (`default.project.json`; `rojo serve` is run by the user). Tools are pinned in `rokit.toml`.

## Workflow

- Git is the only work history; no session logs or notes. Start with `git log` and `git status` to see what was done and what comes next.
- The user playtests. Don't write or run tests, start play sessions, or verify through the MCP unless explicitly asked. Note what's untested instead of claiming it works.
- Commit each finished feature as one revertible commit, staging only that feature's files. Don't split a feature into tiny commits or lump several features together. The message's subject says what changed; its body says why, plus anything left unfinished or next.

## Studio instances

- Create persistent instances (RemoteEvents, GUIs, parts, folders, templates) with the Roblox Studio MCP in edit mode. Game scripts reference them; don't build them at runtime with `Instance.new` or "create if missing" fallbacks.
- Runtime cloning of MCP-authored templates and short-lived effects is fine.
- Rojo doesn't write Studio edits back to disk. To keep MCP-authored instances in git, export them to `.rbxmx` under `assets/` and map them in `default.project.json`.
- Edit scripts on disk under `src/`, not in Studio.
- Never create, delete, rename or reparent anything inside a Rojo-managed instance (anything mapped in `default.project.json`). Rojo only tracks the instances it made, so when the exported `.rbxmx` syncs it adds its own copy next to one built by hand, and scripts find the wrong one with `FindFirstChild` (e.g. `Hud:110: attempt to index nil`). Structural changes go through staging instead:
  1. Clone the managed root to an unmapped sibling (e.g. `StarterGui._StagingHud`, `ServerStorage._StagingItemTemplates`). Hide the real one while previewing if it's visible (`Enabled = false`), and restore it afterwards.
  2. Make and preview the changes in the staging copy.
  3. Export the staging copy, rename its root back to the real name in the XML, and write the `.rbxmx`.
  4. Destroy the staging copy. Rojo patches its own instance from the file, so only one copy ever exists. If Rojo isn't connected, have the user connect it; don't rebuild the change by hand.

  Never leave a staging copy behind (StarterGui copies them into every player). Changing properties of existing managed instances in place is fine, as is writing property changes straight into the `.rbxmx`.
- `tools/find_duplicates.luau` (through `execute_luau`) must return `clean` before committing. It's a check, not a routine step. If it finds duplicates, something was built by hand in a managed spot: have the user reconnect Rojo (Disconnect, then Connect and accept), which rebuilds the tree from disk, and run it again.

## Luau pitfalls

- A statement starting with `(` (e.g. `(x :: TextLabel).Text = ...`) right after a line ending in a call, identifier or `)` fails to load with "Ambiguous syntax: this looks like an argument list for a function call". This keeps recurring. End the previous line with `;`, or assign the cast to a local first.
- Run `tools/check.sh` (luau-lsp, pinned in `rokit.toml`) after editing scripts. It reports only load-breaking errors (syntax errors), and those must be fixed. `tools/check.sh --all` shows every lint and type warning. Don't spend time on those unless one is severe (a real bug or a crash); most are noise without Roblox type definitions.
