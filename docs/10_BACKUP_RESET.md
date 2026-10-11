# 2026-10-11 Güvenli repo yeniden başlangıcı

Kullanıcı isteği: GitHub `oyun` reposunu yedekle, yeni main'i baştan kur, Android dikey ekranlı 3D crafting için veri şemalarını kur.

Önceki ana HEAD: `e079890dac6b8beef2aaaf9f52539d5701953afc` (2026-09-10). Eski tree: `1d6190429d98e0459da8cfd74e6523d967649344`.

Yedek: `refs/heads/backup/pre-portrait-reboot-20261011`, yukarıdaki SHA ile eşleşti. Bu bir etiket veya loose zip yerine GitHub'da kalıcı branch; yedeğin silinmemesi gerekir.

Yeni main: yeni tree, eski HEAD ebeveyn commit'i; non-force `update_ref` ve `expected_sha` koruması ile ileri güncellenir. Böylece `git show <old-sha>` hâlâ çalışır, geçmiş yeniden yazılmaz. Yeni kaynakla arşivdeki eski CI ve test iddiaları karıştırılmaz.

Rollback gerektiğinde yedek dosyalarını yeni bir commit olarak seçerek geri alınır; eski `main`e force reset atılmaz. İleride yedek dalını silmeden önce kullanıcı onayı gerekir.
