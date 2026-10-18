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
        args.add("--game_data_root=" + b + "/game");
        args.add("--user_data_root=" + b + "/userdata");
        args.add("--log_file=" + b + "/uaw.log");

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
