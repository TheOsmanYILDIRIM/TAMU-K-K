# constants.md — Sabitler (değişmezler)

## Motor & Ortam
| Sabit | Değer |
|---|---|
| GODOT_VERSION | 4.4.1-stable (linux.arm64) |
| GODOT_BIN | `~/godot/Godot_v4.4.1-stable_linux.arm64` |
| PROOT_DISTRO | ubuntu (proot-distro) |
| RENDERER | gl_compatibility (Forward+ yasak) |
| SCREEN | 1080×1920 (portrait) |
| CAMERA | Orthographic, yaw 45°, pitch -35.264° (2:1 isometrik) |

## Dünya
| Sabit | Değer |
|---|---|
| CHUNK_SIZE_X | 16 |
| CHUNK_SIZE_Z | 16 |
| WORLD_DEPTH | 32 (y: 0=bedrock … 31=build limit) |
| SKY_HEIGHT | build limit üstü = gökyüzü (maksimum) |
| NOISE | FastNoiseLite (Perlin), seed deterministik |

## Network
| Sabit | Değer |
|---|---|
| DEFAULT_PORT | 24565 |
| MAX_PLAYERS | 8 |
| MODEL | server-authoritative (ENet) |

## Diller
| Sabit | Değer |
|---|---|
| DEFAULT_LOCALE | en |
| SUPPORTED | en, tr |
| FORMAT | CSV (TranslationServer) |
