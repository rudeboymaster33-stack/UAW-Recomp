package com.halo3.recomp;

import android.os.Bundle;
import android.view.WindowManager;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;

import org.libsdl.app.SDLActivity;

/**
 * Halo 3 recomp launcher.
 *
 * Files live in the app's folder on the device's storage:
 *   Android/data/com.halo3.recomp/files/game/       <- game files (maps, bink, default.xex ...)
 *   Android/data/com.halo3.recomp/files/userdata/   <- saves
 *   Android/data/com.halo3.recomp/files/halo3.log   <- log
 *   Android/data/com.halo3.recomp/files/args.txt    <- optional extra flags, one per line
 *   Android/data/com.halo3.recomp/files/env.txt     <- optional KEY=VALUE environment lines
 */
public class Halo3Activity extends SDLActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }

    @Override
    protected String[] getLibraries() {
        // librexruntime.so (with SDL inside) is loaded first so its JNI entry
        // points are registered before libmain.so (the game) starts.
        return new String[] { "c++_shared", "rexruntime", "main" };
    }

    @Override
    protected String[] getArguments() {
        File base = getExternalFilesDir(null);
        String b = base.getAbsolutePath();
        new File(b, "game").mkdirs();
        new File(b, "userdata").mkdirs();

        ArrayList<String> args = new ArrayList<>();
        args.add("--gpu_plugin=xenos");
        // Halo 3 uses texture fetch constants with an "invalid" type for some of its
        // textures (menu background, effects); accept them like the console does.
        args.add("--gpu_allow_invalid_fetch_constants=true");
        // Halo 3 renders to 8_8_8_8_GAMMA targets and expects real 8-bit storage;
        // the 16-bit emulation of them makes the menu scene far too bright.
        args.add("--gamma_render_target_as_unorm16=false");
        // Copying shader memory writes back to the CPU stalled the GPU ~10 times
        // per frame (10 -> 13.5 fps on the menu without it); Halo 3 does not need it.
        args.add("--readback_memexport=false");
        // Render without 4x MSAA: about +33% speed on the menu (13.5 -> 18 fps).
        // Known side effect: black boxes for a moment right after skipping the intro.
        args.add("--gpu_force_msaa_1x=true");
        // Plain multiplies in translated shaders instead of emulating the Xbox 360
        // "0 * anything = 0" rule: about +25% on the menu, no visible difference.
        args.add("--gpu_shader_fast_multiply=true");
        // Hardware texture LOD + bias instead of explicit gradients: about +5%.
        args.add("--gpu_shader_implicit_lod=true");
        // Evenly paced frames: FIFO presentation (VK_GOOGLE_display_timing).
        args.add("--vulkan_allow_present_mode_immediate=false");
        args.add("--vulkan_allow_present_mode_mailbox=false");
        args.add("--vulkan_allow_present_mode_fifo_relaxed=false");
        // AMD FSR 1 upscales the 1280x720 game image to the 1080p screen.
        args.add("--present_effect=fsr");
        args.add("--game_data_root=" + b + "/game");
        args.add("--user_data_root=" + b + "/userdata");
        args.add("--log_file=" + b + "/halo3.log");

        // Developer switch: a file named profile_on turns on the sampling profiler.
        if (new File(b, "profile_on").exists()) {
            try {
                android.system.Os.setenv("UAW_PROFILE", "1", true);
            } catch (Exception e) {
                // Ignore; profiling just stays off.
            }
        }

        // Developer switch: env.txt lines KEY=VALUE become environment variables.
        File envFile = new File(b, "env.txt");
        if (envFile.exists()) {
            try (BufferedReader r = new BufferedReader(new FileReader(envFile))) {
                String line;
                while ((line = r.readLine()) != null) {
                    line = line.trim();
                    int eq = line.indexOf('=');
                    if (eq > 0 && !line.startsWith("#")) {
                        android.system.Os.setenv(line.substring(0, eq).trim(), line.substring(eq + 1).trim(), true);
                    }
                }
            } catch (Exception e) {
                // Ignore a bad env file.
            }
        }

        File extra = new File(b, "args.txt");
        if (extra.exists()) {
            try (BufferedReader r = new BufferedReader(new FileReader(extra))) {
                String line;
                while ((line = r.readLine()) != null) {
                    line = line.trim();
                    if (!line.isEmpty() && !line.startsWith("#")) {
                        args.add(line);
                    }
                }
            } catch (Exception e) {
                // Ignore a bad args file; defaults still apply.
            }
        }
        return args.toArray(new String[0]);
    }
}
