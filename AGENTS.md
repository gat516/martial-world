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
- Rojo duplicates: when a mapped `.rbxmx` changes on disk, Rojo's live sync adds instances from the file next to copies built by hand in Studio, and a destroyed-and-rebuilt instance leaves Rojo patching a stale one. Scripts then find the wrong copy with `FindFirstChild` (e.g. `Hud:110: attempt to index nil`). Prevent it by editing existing instances' properties in place rather than rebuilding them. After any structural change (create, delete, rename, reparent) and export, have the user reconnect Rojo (Disconnect, then Connect and accept), which rebuilds the tree from disk. Then run `tools/find_duplicates.luau` through `execute_luau`; it must return `clean` before committing.

## Luau pitfalls

- A statement starting with `(` (e.g. `(x :: TextLabel).Text = ...`) right after a line ending in a call, identifier or `)` fails to load with "Ambiguous syntax: this looks like an argument list for a function call". This keeps recurring. End the previous line with `;`, or assign the cast to a local first.
- Run `tools/check.sh` (luau-lsp, pinned in `rokit.toml`) after editing scripts. It reports only load-breaking errors (syntax errors), and those must be fixed. `tools/check.sh --all` shows every lint and type warning. Don't spend time on those unless one is severe (a real bug or a crash); most are noise without Roblox type definitions.
