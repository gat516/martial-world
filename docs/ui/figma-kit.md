# Figma UI kit: setup and access

How to get the Martial World UI kit into your own Figma account, connect Figma to
Claude, and give the ui-designer agent the file. What the kit contains is in
[overhaul-plan](overhaul-plan.md), "UI kit in Figma". Core: [ui](../systems/ui.md).

- **The owner's live file:** [Martial World UI Kit](https://www.figma.com/design/9u6RPHLelUJF6aABm6mY7y)
  (gat516's account, Starter plan). Use this link when you have access to it.
- **The master copy in git:** `art/ui/figma/Martial World UI Kit.fig`. Any dev can
  import it as their own file.

## Importing the .fig file

1. **Find the file in the repo.** On Windows with the repo in WSL, it's at
   `\\wsl.localhost\Ubuntu\home\<you>\roblox\martial-world\art\ui\figma\Martial World UI Kit.fig`.
   Paste that path into the file picker's address bar.
2. **Open Figma** (figma.com or the desktop app) and sign in. Go to the file browser
   (the home screen, not inside a file).
3. **Import.** Drag the `.fig` onto the file browser, or click **Import** (top
   right; on some layouts it's under **+ New** or the **⋯** menu), then pick the
   file. It's about 40 MB, so give it a minute.
   - Import into your **Drafts** or a team project.
   - If Figma says you're at the Starter plan's file limit, remove an old file or
     import into Drafts.
4. **Check the fonts.** The kit uses Cormorant Garamond, Fredoka and Cinzel, all
   Google Fonts that Figma has built in. If a "missing fonts" banner shows up,
   pick the same family from the list. Don't swap it for another family.
5. **Check the pages.** You should see 3: Foundations (colour variables and
   type), Kit (ornaments, frames, buttons, bars, badges, glyphs) and Example. The
   Starter plan allows only 3 pages per file, so don't add a fourth: put new work
   on an existing page.
6. **Copy the link.** Click **Share > Copy link**. That URL (it contains
   `/design/<fileKey>/`) is what the agent needs.

The import is a separate file with its own key. Edits in it don't reach the
owner's file, and the owner's edits don't reach it.

## Connecting Figma to Claude

The repo's `.mcp.json` adds Figma's remote MCP server (`https://mcp.figma.com/mcp`)
to every session started in it.
1. Start Claude Code in the repo. When it asks whether to use the project's
   `figma` MCP server, approve it.
2. Sign in. From an interactive `claude` terminal in the repo, run `/mcp`, choose
   `figma`, then **Authenticate**. Your browser opens, and you log in to Figma
   and allow access. The server shows as connected afterwards.
3. Give the agent the file. Paste the link from "Importing" step 6 into your
   request to the main session ("use this Figma file: ..."), and it goes in the
   ui-designer's brief. Without a link, the agent uses the owner's file above.

If the agent reports Figma as missing or failing, it's one of these:
- the server wasn't approved
- you're not signed in (run `/mcp` again)
- the file isn't shared with your Figma account (import your own copy)

## Updating the master copy

After a big kit change (new components, a reworked frame), refresh the `.fig` in
git so other devs can import the current kit:
1. In the Figma file, open the main menu and choose **File > Save local copy…**.
2. Save it over `art/ui/figma/Martial World UI Kit.fig`.
3. Commit it on its own, saying what changed in the kit.

It's a 40 MB binary, so don't re-save it for small tweaks.
