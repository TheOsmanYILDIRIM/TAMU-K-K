package com.osman.godotloader;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Android file-manager "Open with" and the internal SAF picker share one PCK import path. */
public final class MainActivity extends Activity {
    private static final int PICK_PCK = 23;
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private TextView status;
    private Button play;
    private Button pick;
    private boolean importBusy;

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
            Intent chooser = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            chooser.setType("*/*");
            chooser.addCategory(Intent.CATEGORY_OPENABLE);
            startActivityForResult(chooser, PICK_PCK);
        });
        panel.addView(pick);

        play = new Button(this);
        play.setText("OYUNU AÇ");
        play.setOnClickListener(v -> launchPack());
        panel.addView(play);

        setContentView(panel);
        refreshStatus();
        // A configuration change must not import (or execute) a received pack twice.
        if (state == null) receiveFileManagerIntent(getIntent());
    }

    @Override protected void onNewIntent(Intent incoming) {
        super.onNewIntent(incoming);
        setIntent(incoming);
        receiveFileManagerIntent(incoming);
    }

    private void receiveFileManagerIntent(Intent incoming) {
        if (incoming == null) return;
        String action = incoming.getAction();
        Uri uri = null;
        if (Intent.ACTION_VIEW.equals(action)) {
            uri = incoming.getData();
        } else if (Intent.ACTION_SEND.equals(action)) {
            if (android.os.Build.VERSION.SDK_INT >= 33) {
                uri = incoming.getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
            } else {
                uri = incoming.getParcelableExtra(Intent.EXTRA_STREAM);
            }
        } else {
            return;
        }
        if (uri == null) {
            status.setText("Dosya yöneticisi okunabilir PCK adresi göndermedi.");
            return;
        }
        final String scheme = uri.getScheme();
        if (!"content".equals(scheme) && !"file".equals(scheme)) {
            status.setText("Yalnız yerel dosya veya content:// PCK açılabilir.");
            return;
        }
        // An octet-stream MIME association also matches unrelated binary files.
        // Reject a known non-PCK display name before reading any of its data.
        String displayName = externalDisplayName(uri);
        if (displayName != null && !PackStore.hasPckExtension(displayName)) {
            status.setText("Yalnız .pck dosyası açılabilir: " + displayName);
            return;
        }
        importPack(uri, true);
    }

    private String externalDisplayName(Uri uri) {
        if ("content".equals(uri.getScheme())) {
            try (Cursor cursor = getContentResolver().query(
                    uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                    if (index >= 0) return cursor.getString(index);
                }
            } catch (RuntimeException ignored) {
                // Some content providers do not expose a name; the PCK magic check still applies.
            }
            return null;
        }
        return uri.getLastPathSegment();
    }

    private void refreshStatus() {
        String name = getPreferences(MODE_PRIVATE).getString("selected_pack", null);
        try {
            PackStore.resolve(getFilesDir(), name);
            status.setText("Oyun paketi hazır. Editör açılmadan çalıştırılabilir.");
            play.setEnabled(!importBusy);
        } catch (IOException e) {
            status.setText("Godot 4.6 PCK seçin. Kaynak ZIP'i desteklenmiyor.");
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
        if (uri != null) importPack(uri, false);
    }

    private void importPack(Uri uri, boolean fromFileManager) {
        if (importBusy) {
            status.setText("Önceki PCK içe aktarma işlemi sürüyor.");
            return;
        }
        importBusy = true;
        status.setText("PCK içeri aktarılıyor…");
        pick.setEnabled(false);
        play.setEnabled(false);
        io.execute(() -> {
            try {
                String pack = PackStore.importFrom(getContentResolver(), uri, getFilesDir());
                runOnUiThread(() -> {
                    if (isDestroyed()) return;
                    importBusy = false;
                    pick.setEnabled(true);
                    if (!getPreferences(MODE_PRIVATE).edit()
                            .putString("selected_pack", pack).commit()) {
                        status.setText("Paket kopyalandı ancak seçim saklanamadı.");
                        refreshIfPackExists();
                        return;
                    }
                    refreshStatus();
                    if (fromFileManager) {
                        // Exported activities can be launched by other apps.
                        // Require an explicit user action before running external GDScript.
                        new AlertDialog.Builder(this)
                                .setTitle("PCK oyunu aç")
                                .setMessage("Bu PCK Godot oyun kodu çalıştırır. " +
                                        "Yalnız güvendiğiniz oyun dosyalarını açın.")
                                .setPositiveButton("OYUNU AÇ", (dialog, which) -> launchPack())
                                .setNegativeButton("SADECE İÇERİ AKTAR", null)
                                .show();
                    }
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    if (isDestroyed()) return;
                    importBusy = false;
                    pick.setEnabled(true);
                    status.setText("PCK alınamadı: " + e.getMessage());
                    refreshIfPackExists();
                });
            }
        });
    }

    private void refreshIfPackExists() {
        String previous = getPreferences(MODE_PRIVATE).getString("selected_pack", null);
        try {
            PackStore.resolve(getFilesDir(), previous);
            play.setEnabled(!importBusy);
        } catch (IOException ignored) {
            play.setEnabled(false);
        }
    }

    @Override protected void onDestroy() {
        io.shutdown();
        super.onDestroy();
    }
}
