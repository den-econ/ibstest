# Panel contoh ber-`psid` (sampel IBS & IMK)

Panel sintetis untuk pengembangan/uji pipeline. Dirancang **mirror struktur data
asli** supaya do-file yang sama bisa langsung dipakai di data asli.

Generator (do-file Stata, reproducible, `set seed`):
- [`gen_ibs_psid.do`](gen_ibs_psid.do) → IBS  (jalankan: `do "code/gen_ibs_psid.do"`)
- [`gen_imk_panel.do`](gen_imk_panel.do) → IMK  (jalankan: `do "code/gen_imk_panel.do"`)

---

## IBS — panel per FIRM, MATCHED ke 2005 (`data/panel_ibs_sintesis/mfgYYYY.dta`, 2010–2022)

- Nilai ekonomi dari **sampel** `data/raw_ibs_sampel/mfgYYYY.dta` (struktur raw utuh),
  disubsample jadi **~500 firm** + kolom **`psid`**.
- **`psid` = id ASLI `nkip05`** yang ditarik dari `data/ibs/indus05.dta` → panel ini
  **benar-benar bisa di-merge** ke data asli 2005 (sintetis tapi mergeable).
  Verifikasi di do-file: `merge m:1 nkip05 using indus05` → **100% matched**.
- **Unbalanced (entry/exit)**: ~371–500 firm/tahun → lensa entry/exit & dekomposisi aktif.
- Semua kolom raw asli tetap ada (Output{YY}, Vtlvcu{YY}, Ltlnou{YY}, …) + `psid`.
- Untuk merge: `rename psid nkip05` lalu `merge m:1 nkip05 using "data/ibs/indus05.dta"`.
- **Gabungan + data ASLI 2005 sebagai `year=2005`**: `ibs_panel_2010_2022.dta`
  — panel sintetis 2010–2022 di-**append** dengan record ASLI 2005 (`indus05`) untuk
  500 firm yang sama (via `psid`=`nkip05`), ditandai `year=2005`. Jadi panel span
  **2005 (asli) + 2010–2022 (sintetis)** = 5.684 baris × 2.678 kolom (kolom union:
  `*05` dari 2005, `*10`–`*22` dari sintetis). Kunci panel: `psid`.

## IMK — level usaha, SEMUA variabel dipertahankan (`data/panel_imk_sintesis/imkYYYY.dta`, 2017–2025)

- Dibuat dari `data/raw_imk_sampel/VIMK{YY}-Tahunan.xlsx` (dump kuesioner) —
  **SEMUA kolom asli dipertahankan** (kode pertanyaan r…/b…), lalu ditambah:
  `year`, `kbli2` (KBLI/ISIC Rev.4 2-digit, kode **asli**), `kbli5`, dan
  **`isic2d`** (ISIC Rev.2 2-digit via konkordans → kunci **MERGE** ke SI lama).
- IMK = *repeated cross-section* → **panel "by industry"**: penaut antar-tahun =
  **`kbli2`** (atau **`isic2d`** untuk nyambung ke era Rev.2 `indus75/85/95`,`indus05`).
  `pmid` = id usaha (mentah).
- Tiap tahun ~8.000–9.300 usaha × ~120–354 kolom. Gabungan `imk_panel_2017_2025.dta`
  = 79.816 baris × 1.218 kolom (union kolom antar-tahun).
- Konkordans 2-digit: `code/concordance_kbli_isic2.do`.
- **Gabung dgn SI lama (1975–2005) by industri 2-digit**: `imk_si_panel_1975_2025.dta`
  — IMK (2017–2025) + SI asli `indus75/85/95/05` di-append, di-link lewat **`isic2d`**
  (ISIC Rev.2 2-digit). 142.474 baris × 1.917 kolom; tahun **1975, 1985, 1995, 2005**
  (asli) + 2017–2025 (IMK). ⚠️ populasi beda (SI besar/sedang vs IMK mikro) → tautan
  di level **industri**, bukan firm. (`indus15` dilewati: tak punya kode industri.)

> **Catatan:** kolom raw ber-kode kuesioner & **beda tiap vintage** (mis. `401a`=
> jumlah pekerja, `401b`=hari kerja; blok ter-nomori ulang). Jadi untuk memakai
> variabel ekonomi tertentu tetap perlu mapping per-vintage — tapi datanya **sudah
> ada semua** di panel ini.

---

## ⚠️ Agar pipeline memakai `psid` (bukan id lama yang ter-mask)

File IBS masih punya `Kipb` bawaan (ter-mask `"***"`). `1_prepare.do` saat ini
mendeteksi id dengan urutan `kipb → kip → psid`, jadi masih akan memilih `Kipb`.
Agar panel ini berfungsi (dan konsisten dgn data asli yang di-key `psid`),
**ubah prioritas jadi `psid` lebih dulu** di `1_prepare.do`, dan arahkan
`$raw` ke `data/panel_ibs_sintesis`.

> psid IBS sekarang = **nilai `nkip05` asli** dari `indus05` → selain membentuk panel,
> juga **cocok saat di-merge** ke data asli 2005 (bukan lagi asal-asalan).
