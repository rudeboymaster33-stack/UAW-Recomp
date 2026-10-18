package com.uaw.recomp;

import android.os.Bundle;
import android.view.WindowManager;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;

import org.libsdl.app.SDLActivity;

/**
 * Universe at War recomp launcher.
 *
 * Files live in the app's folder on the phone's storage:
 *   Android/data/com.uaw.recomp/files/game/       <- copy the game folder here (Data\ + default.xex)
 *   Android/data/com.uaw.recomp/files/userdata/   <- saves
 *   Android/data/com.uaw.recomp/files/uaw.log     <- log
 *   Android/data/com.uaw.recomp/files/args.txt    <- optional extra flags, one per line
 */
public class UawActivity extends SDLActivity {

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
        // Same as the PC launcher: occlusion queries make the game wait for GPU
        // results every frame (and caused blinking shadows on PC).
        args.add("--occlusion_query_enable=false");
        // Cheaper GPU settings for the handheld (no visible difference in testing).
        args.add("--anisotropic_override=-1");
        args.add("--gamma_render_target_as_unorm16=false");
        args.add("--snorm16_render_target_full_range=false");
        args.add("--game_data_root=" + b + "/game");
        args.add("--user_data_root=" + b + "/userdata");
        args.add("--log_file=" + b + "/uaw.log");

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
