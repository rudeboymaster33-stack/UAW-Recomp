# Halo 3 recomp (work in progress)

> **AI-generated:** the code, scripts and patches in this repository were written by Claude (Anthropic's AI), working on behalf of the repository owner.

An attempt to statically recompile the Xbox 360 version of Halo 3 with the ReXGlue SDK, for Android handhelds (Retroid Pocket 6). There is no PC build.

**No game files are included.** You need your own copy of the game.

## Status
- Project set up; the whole game converts cleanly (3 jump targets added to the manifest). Not booting yet.

Needs the Universe at War project next to it (`Documents\UAW-Recomp`): the first build copies its toolkit and uses its Android build tools.

## How to use
Double-click **Start here.bat** and follow the menu:

| Option | What it does |
|---|---|
| 1 | Unpack the game disc |
| 2 | Retroid: build, install and start the game (first build takes a few hours) |
| 3 | Retroid: test run - build, play, collect logs |
| 4 | Retroid: get logs only |
| 5 | Save progress and upload to GitHub |

This project shares its toolkit patches (`patches\`) with the Universe at War recomp, but is kept fully separate.
