# Geliştirme yol haritası (kanıta bağlı)

## A — Güvenli yeniden başlangıç (bu iş)
Eski dal yedeği + temiz main; mimari kararlar; tanım/recipe/save/network/asset şemaları; katalog örneği; bağımsız doğrulama ve CI. **Kabul: repo dosyaları, test, CI; oynanış değil.**

## B — Tek oyunculu mobil vertical slice
Prosedürel küçük 3D orman + oyuncu, kamera ve hedef seçme; tıkla git, ağaç/taş topla, eşya alınır. Touch UX real-device; CPU, FPS ölçülür.

## C — Craft ve inşa
Envanter, üretim, reçete kuyruğu, basit masa ve duvar, sandbox oyunda örnek iş akışı. Atomik save/reopen.

## D — Aynı ağda iki oyuncu
ENet host/client, world sync, crafting yarış/çakışma, ortak sandık, disconnect/reconnect. İki gerçek Android cihaz.

## E — Prosedürel varlık editörü
Ağaç/kaya/mob jeneratörü; GLB ve texture/MTS adaptörünü lisans gate ile oluştur; cihazda LOD ve bellek testi.

## F — İçerik ve ilerleme
Biyom çeşitleri, araştırma ağacı, üretim makineleri, çiftlik/su, dekor ve az stresli tehlikeler.

## Karar kapıları
Her fazda başlat/bitir için Beyin görevi + kanıt; geriye uyumlu veriler; Godot CI; gerçek cihaz screenshot/performance raporu kullanıcıya bırakılabilir ama koşmadan başarı denmez.
