package com.osman.godotloader;

import android.content.ContentResolver;
import android.net.Uri;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.Locale;
import java.security.NoSuchAlgorithmException;

/** Stores untrusted SAF imports in private storage without touching game saves. */
public final class PackStore {
    private static final long MAX_PACK_BYTES = 2L * 1024 * 1024 * 1024;
    private static final byte[] PCK_MAGIC = { 'G', 'D', 'P', 'C' };
    private PackStore() {}

    public static boolean validHeader(byte[] header, int length) {
        if (header == null || length < 4) return false;
        for (int i = 0; i < 4; i++) {
            if (header[i] != PCK_MAGIC[i]) return false;
        }
        return true;
    }

    public static boolean hasPckExtension(String displayName) {
        return displayName != null && displayName.length() > 4 &&
                displayName.toLowerCase(Locale.ROOT).endsWith(".pck");
    }

    public static boolean validName(String name) {
        return name != null && name.matches("[0-9a-f]{64}\\.pck");
    }

    public static File resolve(File appFiles, String name) throws IOException {
        if (!validName(name)) throw new IOException("Invalid pack name");
        File directory = new File(appFiles, "packs").getCanonicalFile();
        File selected = new File(directory, name).getCanonicalFile();
        if (!directory.equals(selected.getParentFile()) || !selected.isFile()) {
            throw new IOException("Pack not available");
        }
        try (FileInputStream input = new FileInputStream(selected)) {
            byte[] header = new byte[4];
            if (!validHeader(header, input.read(header))) {
                throw new IOException("Invalid Godot PCK header");
            }
        }
        return selected;
    }

    public static String importFrom(ContentResolver resolver, Uri source, File appFiles)
            throws IOException {
        File directory = new File(appFiles, "packs");
        if (!directory.isDirectory() && !directory.mkdirs()) {
            throw new IOException("Cannot create private package directory");
        }
        File temporary = File.createTempFile("import-", ".partial", directory);
        boolean finished = false;
        try {
            MessageDigest digest = sha256();
            long count = 0;
            byte[] buffer = new byte[65536];
            byte[] header = new byte[4];
            int headerCount = 0;
            try (InputStream input = resolver.openInputStream(source);
                 FileOutputStream output = new FileOutputStream(temporary)) {
                if (input == null) throw new IOException("Cannot read the selected file");
                int n;
                while ((n = input.read(buffer)) != -1) {
                    if (n == 0) continue;
                    count += n;
                    if (count > MAX_PACK_BYTES) throw new IOException("Pack exceeds 2 GiB");
                    if (headerCount < 4) {
                        int copy = Math.min(n, 4 - headerCount);
                        System.arraycopy(buffer, 0, header, headerCount, copy);
                        headerCount += copy;
                    }
                    digest.update(buffer, 0, n);
                    output.write(buffer, 0, n);
                }
                output.getFD().sync();
            }
            if (count < 64 || !validHeader(header, headerCount)) {
                throw new IOException("Select an exported Godot .pck (not a project ZIP)");
            }
            StringBuilder key = new StringBuilder(64);
            for (byte b : digest.digest()) key.append(String.format("%02x", b & 0xff));
            String name = key + ".pck";
            File destination = new File(directory, name);
            if (destination.exists()) {
                if (destination.length() != count) {
                    throw new IOException("Existing package hash collision or corruption");
                }
            } else if (!temporary.renameTo(destination)) {
                throw new IOException("Failed to publish package atomically");
            }
            finished = true;
            return name;
        } finally {
            // Never keep partial downloads or overwrite an existing pack on failure.
            if (!finished || temporary.exists()) temporary.delete();
        }
    }

    private static MessageDigest sha256() throws IOException {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException e) {
            throw new IOException("SHA-256 is unavailable", e);
        }
    }
}
