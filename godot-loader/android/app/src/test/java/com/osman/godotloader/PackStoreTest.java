package com.osman.godotloader;

import org.junit.Test;
import static org.junit.Assert.*;

public class PackStoreTest {
    @Test public void rejectsUntrustedPathNames() {
        assertFalse(PackStore.validName("../bad.pck"));
        assertFalse(PackStore.validName("project.zip"));
        assertFalse(PackStore.validName(null));
        assertTrue(PackStore.validName("a".repeat(64) + ".pck"));
    }
    @Test public void acceptsOnlyPckDisplayNames() {
        assertTrue(PackStore.hasPckExtension("TAMU.pck"));
        assertTrue(PackStore.hasPckExtension("tamu.PCK"));
        assertFalse(PackStore.hasPckExtension("archive.zip"));
        assertFalse(PackStore.hasPckExtension("tamu.pck.zip"));
        assertFalse(PackStore.hasPckExtension(".pck"));
        assertFalse(PackStore.hasPckExtension(null));
    }
    @Test public void checksGodotPckMagic() {
        assertTrue(PackStore.validHeader(new byte[]{'G','D','P','C'}, 4));
        assertFalse(PackStore.validHeader(new byte[]{'P','K',3,4}, 4));
        assertFalse(PackStore.validHeader(new byte[]{'G','D','P','C'}, 3));
    }
}
