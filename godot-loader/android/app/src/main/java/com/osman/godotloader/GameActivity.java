package com.osman.godotloader;

import android.os.Bundle;
import android.widget.Toast;
import org.godotengine.godot.GodotActivity;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/** Isolated, non-exported game screen. Uses a custom Godot 4.6 native library. */
public final class GameActivity extends GodotActivity {
    public static final String EXTRA_PACK = "com.osman.godotloader.PACK";
    private File activePack;

    @Override protected void onCreate(Bundle state) {
        try {
            activePack = PackStore.resolve(getFilesDir(), getIntent().getStringExtra(EXTRA_PACK));
        } catch (IOException e) {
            Toast.makeText(this, "Geçersiz oyun paketi: " + e.getMessage(), Toast.LENGTH_LONG).show();
            finish();
            return;
        }
        super.onCreate(state);
    }

    @Override public List<String> getCommandLine() {
        List<String> args = new ArrayList<>(super.getCommandLine());
        if (activePack == null) throw new IllegalStateException("No validated PCK");
        args.add("--main-pack");
        args.add(activePack.getAbsolutePath());
        return args;
    }
}
