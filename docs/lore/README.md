# Lore wiki kuralları

- **Tek kaynak:** `docs/lore/` içindeki Markdown dosyaları; teknik belgeler kanıt/kaynak olarak dışarıdan referanslanır, kopyalanmaz.
- **Bağlantı:** Obsidian biçimi `[[03_DUNYA/Fisilti_Ormani|Fısıltı Ormanı]]`. Yol `docs/lore/` köküne göre yazılır, `.md` eklenmez; böylece adaş sayfalar çakışmaz. GitHub wiki-linkleri doğal olarak tıklanabilir değildir; GitHub'da açmak için normal Markdown bağlantısı ayrıca kullanılabilir.
- **Boş başlık:** Henüz hazırlanmadıysa sahte dosya/link yerine `91_BOSLUKLAR.md` içinde `OPEN-...` kimliğiyle durur.
- **Frontmatter:** `id` (kalıcı, benzersiz), `title`, `type`, `status`, `canon`, `aliases`, `tags`. Yalnız katalog işleyişi için kullanılan metadata; oyun runtime/save şeması değildir.
- **status:** `empty` (yalnız konu indeksi), `draft`, `review`, `canon`, `deprecated`. **canon:** `accepted-framework`, `confirmed`, `pending`, `retired`. İçerik için nihai onay gelmeden `confirmed` seçilmez.
- **Karar:** Kanonik değişiklik [[90_KARARLAR]] kaydında karar kaynağı ve çeliştiği önceki ilkeyle belirtilir. Eski bilginin silinmesi yerine tarihsel olarak işaretlenmesi tercih edilir.
- **Bağlantı güvenliği:** Hedefteki `.md` gerçekten bulunmalı. Çift yönlü bağlantı Obsidian backlinks ile görünür; karşılıklı bağlantı gerekliyse iki sayfada da açıkça yazılır. Bağlantısı olmayan yeni kavram önce boşluk listesinde açılır.
- **Kaynak ayrımı:** Lore iddiası, oyun mekaniği, taslak spekülasyon ve tarihsel karar birbirine karıştırılmaz. Var olan Core/plazma belgeleri ilk fikirleri içerir; 29 Ekim Rigby görsel kararı daha yenidir.
- **Güncelleme:** Önce indeks ve boşluk kimliğini kontrol et; mevcut sayfayı genişlet, mükerrer sayfa oluşturma. Yeni sayfa oluşturulunca OPEN durumunu kapatıp bağlantısını yerine koy.
- **Doğrulama:** İlgili sayfaların frontmatter ve wikilink hedefleri, benzersiz `id` ve OPEN kimlikleri, kaynağa giden dosya yolları gözden geçirilir. Bu sürümde otomatik CI/graph jeneratörü kurulmadı.
