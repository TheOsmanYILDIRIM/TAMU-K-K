package com.osman.godotloader;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Minimal game launcher; never exposes the Godot editor. */
public final class MainActivity extends Activity {
    private static final int PICK_PCK = 23;
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private TextView status;
    private Button play;
    private Button pick;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setGravity(Gravity.CENTER_VERTICAL);
        panel.setPadding(32, 36, 32, 36);
        panel.setBackgroundColor(Color.rgb(18, 22, 30));

        TextView title = new TextView(this);
        title.setText("OSMAN Godot Loader");
        title.setTextSize(25);
        title.setTextColor(Color.WHITE);
        panel.addView(title);

        status = new TextView(this);
        status.setTextColor(Color.LTGRAY);
        status.setTextSize(15);
        status.setPadding(0, 22, 0, 28);
        panel.addView(status);

        pick = new Button(this);
        pick.setText("PCK İÇERİ AKTAR");
        pick.setOnClickListener(v -> {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.setType("*/*");
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            startActivityForResult(intent, PICK_PCK);
        });
        panel.addView(pick);

        play = new Button(this);
        play.setText("OYUNU AÇ");
        play.setOnClickListener(v -> launchPack());
        panel.addView(play);

        setContentView(panel);
        refreshStatus();
    }

    private void refreshStatus() {
        String name = getPreferences(MODE_PRIVATE).getString("selected_pack", null);
        try {
            PackStore.resolve(getFilesDir(), name);
            status.setText("Oyun paketi hazır. Editör açılmadan çalıştırılacak.");
            play.setEnabled(true);
        } catch (IOException e) {
            status.setText("Godot 4.6 PCK seçin. ZIP veya kaynak klasörü değil.");
            play.setEnabled(false);
        }
    }

    private void launchPack() {
        String selected = getPreferences(MODE_PRIVATE).getString("selected_pack", null);
        try {
            PackStore.resolve(getFilesDir(), selected);
            Intent game = new Intent(this, GameActivity.class);
            game.putExtra(GameActivity.EXTRA_PACK, selected);
            startActivity(game);
        } catch (IOException e) {
            status.setText("Paket açılmadı: " + e.getMessage());
            play.setEnabled(false);
        }
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != PICK_PCK || result != RESULT_OK || data == null) return;
        Uri uri = data.getData();
        if (uri == null) return;
        status.setText("İçeri aktarılıyor…");
        pick.setEnabled(false);
        play.setEnabled(false);
        io.execute(() -> {
            try {
                String name = PackStore.importFrom(getContentResolver(), uri, getFilesDir());
                runOnUiThread(() -> {
                    if (!getPreferences(MODE_PRIVATE).edit().putString("selected_pack", name).commit()) {
                        status.setText("Paket saklandı ancak seçim kaydedilemedi.");
                    } else {
                        refreshStatus();
                    }
                    pick.setEnabled(true);
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    status.setText("İçe aktarma reddedildi: " + e.getMessage());
                    pick.setEnabled(true);
                    refreshIfPackExists();
                });
            }
        });
    }

    private void refreshIfPackExists() {
        String old = getPreferences(MODE_PRIVATE).getString("selected_pack", null);
        try {
            PackStore.resolve(getFilesDir(), old);
            play.setEnabled(true);
        } catch (IOException ignored) {
            play.setEnabled(false);
        }
    }

    @Override protected void onDestroy() {
        io.shutdown();
        super.onDestroy();
    }
}
