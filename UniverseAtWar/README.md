# Universe at War: Earth Assault — Xbox 360 static recompilation

Native PC (and later Android) port of the Xbox 360 version of *Universe at War: Earth Assault*,
built with the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk). Requires your own copy of the game.

> **AI-generated project.** The code, scripts, patches and documentation in this repository were
> written by an AI assistant (Claude, by Anthropic), directed and play-tested by the repository owner.

**This repository contains no game data.** The game executable, extracted disc files and the C++
generated from the executable are excluded by `.gitignore` and must come from your own disc.

## Status (2026-10-19)
- **PC:** boots, menus 60 FPS, campaign and skirmish play at the game's own ~30 FPS battle pace (D3D12).
- **Android (Retroid Pocket 6, Snapdragon 8 Gen 2, 120 Hz):** plays with the built-in controls at full game speed
  (30 world updates per second) with evenly paced frames.
  - Main 3D scene drawn without MSAA (`gpu_force_msaa_1x`, pitch 320) – about half the GPU work on Adreno 740.
  - Game timing patch: the frame synchronizer keeps leftover time between world updates (hook at `0x8225C6A4`).
  - Frame pacing: frames held to the game's update beat, repeat frames not shown, display-timed presentation.
- SDK changes live in `patches/` and are applied automatically by the build scripts.
- Known: the first A press on the main menu only activates the menu (probably original game behaviour).

## Folder layout
| Path | What |
|---|---|
| `project/uaw_manifest.toml` | ReXGlue manifest: all analysis fixes for this game (the important file) |
| `files/uaw_manifest.toml` | Master copy the scripts copy into `project/` before codegen |
| `project/src/` | `main.cpp`, `uaw_app.h` (app hooks), `uaw_hooks.cpp` (game timing fix, frame pacing, FPS counter, diagnostics) |
| `project/CMakeLists.txt`, `CMakePresets.json` | Game build |
| `scripts/` | `actions/` (what the Start here menu runs) and the inner build scripts |
| `rexglue-sdk/` | SDK checkout (not tracked; commit `c94f5eb` + `patches/`, see below) |
| `patches/` | Our fixes to the SDK source (applied automatically to `rexglue-sdk/` by the builds) |
| `android/` | Android app code (`UawActivity.java`: default settings) and manifest |
| `userdata/` | Save data / profile (not tracked) |
| `logs/` | Build/run logs (not tracked) |

## Launchers (double-click)
| Script | Purpose |
|---|---|
| `Start here.bat` | Menu with every action below (the action scripts are in `scripts/actions/`) |
| 1 Play on PC | `pc_play.bat` (needs a PC build: `scripts/build_sdk_inner.bat`, then `scripts/game_inner.bat`) |
| 2 Retroid: build, install and start | `android_build_app.bat` then `android_install_and_start.bat` (USB debugging on; copies game files the first time) |
| 3 Retroid: test run | `android_test_run.bat`: build, install, play with profiler, collect logs (extra settings: `scripts/android_test_args.txt`, `scripts/android_test_env.txt`) |
| 4 Retroid: get logs | `android_get_logs.bat`: game log + Android log into `logs/` |
| 5 Save and upload | `save_progress.bat` (commit) then `upload_to_github.bat` (push) |
| 6 First-time setup | `android_install_tools.bat`: Java 17, Android SDK + NDK into `android-tools/` |

Build machinery used by the actions: `scripts/android_build_inner.bat`, `scripts/apply_sdk_patches.bat`, `scripts/build_sdk_inner.bat`, `scripts/game_inner.bat`.

Game data path used by the scripts:
`C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)`

Run flags: `uaw.exe --gpu_plugin=xenos --mnk_mode=true --render_target_path_d3d12=rtv --occlusion_query_enable=false --user_data_root=<UAW-Recomp>\userdata --game_data_root=<game folder>`
(`rexgpu-xenos.dll` must be next to `uaw.exe`; keyboard: Enter=Start, Space=A, Backspace=B, WASD=left stick).

## SDK setup notes
- ReXGlue SDK `main` @ `c94f5eb`, built with LLVM/Clang 23 + VS 2022 Build Tools + Ninja, preset `win-amd64`.
- Apply `patches/*.patch` to `rexglue-sdk/` (currently: XAM reports the type of unset profile
  settings — without it the game shows "Achievement Progress could not be loaded").
- Achievements metadata: `rexglue init --project-name uaw --xex-path default.xex achievements default.xex <out>`,
  placed in `<game data root>\..\metadata\` (achievements.toml + icons).
- Windows git checks out libmspack's symlinks as text files: replace
  `thirdparty/libmspack/cabextract/mspack/*` link stubs with copies of their targets before building.

## Manifest fixes (see comments in the manifest)
1. `0x829592C0` – function the analyzer missed (unresolved branch).
2. 57 function-pointer targets referenced from `.rdata`/`.data` (vtable thunks, callbacks).
3. 15 `lis/addi`-built code pointers outside any known function (e.g. `0x828ED520`).
   The other ~674 such targets are switch-case labels — registering them breaks thousands of branches.
4. `setjmp_address = 0x82A17F30`, `longjmp_address = 0x82A184B0` (libjpeg error recovery uses longjmp).
5. 36 C++ vcall thunks (`lwz/lwz/mtctr/bctr`, 16 bytes) at function boundaries (e.g. `0x826F1730`).
6. Mid-asm hook at `0x828C0054` (before `VdSwap`) for the FPS counter / F3 overlay.
7. Diagnostic hooks around `XamUserRead/WriteProfileSettings` call sites (log `[uaw-prof]`); can be removed.

After any manifest change, codegen must report **0** "Unresolved …" / "Jump target … unresolved" lines.

## Debugging techniques
- Crash offset from Windows Application event 1000 → guest function via the `PPCFuncMappings`
  table inside `uaw.exe` ({guest u32, pad, host u64} entries).
- Mid-asm hooks (`[[entrypoint.midasm_hook]]`) + `REXLOG_WARN` in `src/uaw_hooks.cpp`.
- Render path: `--render_target_path_d3d12=rov|rtv` (SDK defaults to ROV on Intel).

## Android notes
- SDK patches `patches/0002-android-port.patch` (platform port) and `0003-vulkan-storage-rewind.patch`
  are applied automatically by the Android build (menu option 2 or 3).
- On the device everything lives in `Android/data/com.uaw.recomp/files/`: `game/` (Data + default.xex),
  `userdata/` (saves, shader cache), `uaw.log`, optional `args.txt` (extra flags, one per line).

## Next steps
1. Investigate the game-side ~23-24 FPS stretches in skirmishes.
