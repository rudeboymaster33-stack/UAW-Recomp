# Universe at War: Earth Assault — Xbox 360 static recompilation

Native PC (and later Android) port of the Xbox 360 version of *Universe at War: Earth Assault*,
built with the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk). Requires your own copy of the game.

**This repository contains no game data.** The game executable, extracted disc files and the C++
generated from the executable are excluded by `.gitignore` and must come from your own disc.

## Status (2026-10-18)
- Boots, plays the intro cinematic and reaches the main menu at a steady 60 FPS (D3D12 GPU emulation, Intel Arc 130V).
- Skirmish battles load and play, but run slowly (being measured) and there are visual artifacts
  (grey blocks over the menu background video).

## Folder layout
| Path | What |
|---|---|
| `project/uaw_manifest.toml` | ReXGlue manifest: all analysis fixes for this game (the important file) |
| `files/uaw_manifest.toml` | Master copy the scripts copy into `project/` before codegen |
| `project/src/` | `main.cpp`, `uaw_app.h` (app hooks), `uaw_hooks.cpp` (FPS counter, diagnostics) |
| `project/CMakeLists.txt`, `CMakePresets.json` | Game build |
| `scripts/` | Inner build scripts, crash symbolizer, old test scripts |
| `rexglue-sdk/` | SDK checkout (not tracked; commit `c94f5eb`, see below) |
| `logs/` | Build/run logs (not tracked) |

## Launchers (double-click)
| Script | Purpose |
|---|---|
| `01_install_tools.bat` | Install Git, CMake, Ninja, LLVM/Clang, VS 2022 Build Tools (winget) |
| `02_build_sdk.bat` | Clone + build + install the SDK |
| `03_recompile_and_build_game.bat` | Copy manifest, run codegen, build `uaw.exe` |
| `04_run_game.bat` | Run the game |
| `05_rebuild_and_run.bat` | 03 + 04 in one go (main dev loop) |
| `06_debug_run.bat` | RelWithDebInfo build + crash symbolization (blocked by Smart App Control on this PC) |
| `09_speed_compare.bat` | Timed FPS comparison of ROV vs RTV render paths |
| `10a_play_ROV.bat` / `10b_play_RTV.bat` | Play normally with FPS logged every second |
| `11_git_commit.bat` | Commit current state to this git repo |

Game data path used by the scripts:
`C:\ROMS\Xbox 360\Universe at War - Earth Assault (USA)\Universe at War - Earth Assault (USA)`

Run flags: `uaw.exe --gpu_plugin=xenos --mnk_mode=true --game_data_root=<game folder>`
(`rexgpu-xenos.dll` must be next to `uaw.exe`; keyboard: Enter=Start, Space=A, Backspace=B, WASD=left stick).

## SDK setup notes
- ReXGlue SDK `main` @ `c94f5eb`, built with LLVM/Clang 23 + VS 2022 Build Tools + Ninja, preset `win-amd64`.
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

After any manifest change, codegen must report **0** "Unresolved …" / "Jump target … unresolved" lines.

## Debugging techniques
- Crash offset from Windows Application event 1000 → guest function via the `PPCFuncMappings`
  table inside `uaw.exe` ({guest u32, pad, host u64} entries).
- Mid-asm hooks (`[[entrypoint.midasm_hook]]`) + `REXLOG_WARN` in `src/uaw_hooks.cpp`.
- Render path: `--render_target_path_d3d12=rov|rtv` (SDK defaults to ROV on Intel).

## Next steps
1. Measure battle FPS (10a vs 10b) and fix the slowdown.
2. Fix menu-video artifacts.
3. Android: arm64 NDK build, Vulkan backend, touch controls.
