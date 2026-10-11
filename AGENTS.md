# AGENTS.md — oyun (Android Portrait Crafting Survival)

Kanonik kapsam yeni `main`; önceki proje `backup/pre-portrait-reboot-20261011` dalında değişmeden korunur. Yeniden başlatma 2026-10-11.

## İlerleme sınırları
- Eski yedeği düzenleme, silme veya `main` üzerine geri merge etme. Üretken veri/saved world kaybına sebep olacak migration yapma.
- `SESSION_HANDOFF.md` güncel teknik devir, `AGENTS.md` kalıcı geliştirme kuralıdır.
- Kullanıcı test etmeden gerçek cihaz performansı, ergonomi, oynanış veya çok oyunculu başarı iddia etme.
- Şimdiki görev: mimari, sözleşme, araştırma ve scaffold. Tam oyun ancak fazlar halinde.

## Teknik kararlar
- Android portrait-first; Godot 4.6.3 sabitlenmiş geliştirme/CI sürümü. GL Compatibility başlangıç renderer'ı; gerçek cihazda Mobile renderer karşılaştırması yapılabilir.
- GDScript statik tür tercih edilir. Oyun davranışı ortak sistemlerde; içerik salt tanımlarda (`data/catalog`).
- Her içerik tanımı `schemas/` sözleşmesine, her ref tanımlı bir ID'ye bağlanır; UUID instance ID, namespaced stable definition ID; çalışma belleğindeki indeksleri kayda doğrudan yazma.
- Blok/chunk, etkileşimli instance ve oyuncu kayıtları ayrıdır. Kayıtlarda şema sürümü ve migration; atomik ve geri alınabilir yazım.
- Android kullanıcı verisi yalnız `user://` yazılır; repodaki dosyalar üretim içerikleridir.
- Otoriter host dünya değişikliği/üretim/envanter işlemlerini doğrular. İstemci ekranı/hareket tahmin edebilir, eşya üretemez.
- Lisans doğrulanmadan Mineclonia, MTS veya üçüncü taraf asset import etme. Dosya kaynağı, sürüm, lisans ve hash sakla.

## Doğrulama
- Python stdlib+jsonschema ile JSON Schema, referans bütünlüğü, ID eşsizlik, geçersiz negatif örnek testleri.
- Godot headless import ve başlangıç scene smoke; CI geçmeden platform başarısı ilan etme.
- Mobil doğrulama matrisinde 320-360dp, 392-411dp, büyük yazı 1.3x; kesik/güvenli alan, 19.5:9 ve 20:9.
- APK imzası kalıcı ve gizli; tek kullanımlık keystore ile kalıcı APK üretme. Android build ileride ayrı görev.
- GitHub tree/blob içerik ön doğrulaması -> commit(parent=okunan HEAD) -> `update_ref(force=false,expected_sha=HEAD)`; reddedilen CAS'ı kör tekrar etme.
- Beyin görevlerini kanonik `agy-vault/main` üzerinde ve resmî IO ile doğrula.

## Geliştirme kuralı
Yalnız doğrulanan kabulleri 'done' yap. Yeni içerik, önce tanım+refs+test, sonra runtime bağlayıcı, sonra cihaz UX. Çekirdek kodu statik veri için çoğaltma; sahte içerik ekleyip tamamlandı deme.
