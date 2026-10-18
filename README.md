# Universe at War: Earth Assault — Xbox 360 static recompilation

Native PC (and later Android) port of the Xbox 360 version of *Universe at War: Earth Assault*,
built with the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk). Requires your own copy of the game.

**This repository contains no game data.** The game executable, extracted disc files and the C++
generated from the executable are excluded by `.gitignore` and must come from your own disc.

## Status (2026-10-18)
- **PC:** boots, menus 60 FPS, campaign and skirmish play near the game's own 30 FPS battle cap (D3D12, RTV path).
- **Android (Retroid Pocket 6, Snapdragon 8 Gen 2):** plays with the built-in controls, Vulkan on Adreno 740,
  menus 60 FPS, battles ~29-30 FPS. Shader storage persists between runs (no repeat stutter).
- Fixed: blinking shadows (occlusion queries off), achievement-progress error (SDK patch), Android shader-storage reload.
- Known: short game-side stretches at ~23-24 FPS in skirmishes on both PC and Android; some model pop-in.

## Folder layout
| Path | What |
|---|---|
| `project/uaw_manifest.toml` | ReXGlue manifest: all analysis fixes for this game (the important file) |
| `files/uaw_manifest.toml` | Master copy the scripts copy into `project/` before codegen |
| `project/src/` | `main.cpp`, `uaw_app.h` (app hooks), `uaw_hooks.cpp` (FPS counter, diagnostics) |
| `project/CMakeLists.txt`, `CMakePresets.json` | Game build |
| `scripts/` | Inner build scripts, crash symbolizer, old test scripts |
| `rexglue-sdk/` | SDK checkout (not tracked; commit `c94f5eb` + `patches/`, see below) |
| `patches/` | Our fixes to the SDK source (apply to `rexglue-sdk/` before building) |
| `userdata/` | Save data / profile (not tracked) |
| `logs/` | Build/run logs (not tracked) |

## Launchers (double-click)
| Script | Purpose |
|---|---|
| `PC 1 - Install build tools.bat` | Install Git, CMake, Ninja, LLVM/Clang, VS 2022 Build Tools (winget) — once |
| `PC 2 - Build SDK.bat` | Build + install the SDK for Windows — once, or after SDK patches |
| `PC 3 - Build game.bat` | Copy manifest, run codegen, build `uaw.exe` |
| `PC 4 - Play.bat` | Play the PC version |
| `Android 1 - Install build tools.bat` | Java 17, Android SDK + NDK into `android-tools/` — once |
| `Android 2 - Build app.bat` | Build SDK + game for arm64 and package `UniverseAtWar.apk` |
| `Android 3 - Install on Retroid.bat` | Install over USB (USB debugging on), copy game files the first time, start it |
| `Android 4 - Get Retroid logs.bat` | Copy the game log + Android log from the device into `logs/` |
| `Save progress (git).bat` | Commit the current state to this git repo |

Developer/test scripts (FPS comparisons, debug builds, experiments) live in `scripts/dev/`.

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
  are applied automatically by `Android 2 - Build app.bat`.
- On the device everything lives in `Android/data/com.uaw.recomp/files/`: `game/` (Data + default.xex),
  `userdata/` (saves, shader cache), `uaw.log`, optional `args.txt` (extra flags, one per line).

## Next steps
1. Investigate the game-side ~23-24 FPS stretches in skirmishes.
