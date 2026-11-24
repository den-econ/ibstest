# ibstest — engine pembangun panel BPS (IBS & IMK)

`ibstest` adalah **engine umum**: ia mengubah mikrodata mentah BPS menjadi
**data siap pakai** yang bisa dipakai studi apa pun (bukan hanya *scarring*).
Semua hasil disimpan di `data/raw/` (gitignored).

**IBS murni** — kuesioner utama, satu baris per perusahaan-tahun:

| Hasil | Dibangun oleh | Isi |
|-------|---------------|-----|
| `firm_panel.dta` | `prepare_ibs_panel.do` | perusahaan × tahun, 2010–2022 |

**IBS roster** — bahan baku dan produk, banyak baris per perusahaan-tahun (2021–2022):

| Hasil | Dibangun oleh | Isi |
|-------|---------------|-----|
| `ibs_input_long.dta`  | `prepare_ibs_roster.do` | perusahaan × tahun × bahan baku |
| `ibs_output_long.dta` | `prepare_ibs_roster.do` | perusahaan × tahun × produk |

Roster **tidak** dilebur ke `firm_panel.dta`. Keduanya ditautkan saat dibutuhkan dengan
`merge m:1 fid year using "data/raw/firm_panel.dta"`.

**IBS roster + variabel perusahaan** — file tambahan, tidak mengganti file di atas:

| Hasil | Dibangun oleh | Isi |
|-------|---------------|-----|
| `ibs_input_firm.dta`  | `merge_ibs_roster.do` | `ibs_input_long` + variabel perusahaan (`f_*`) |
| `ibs_output_firm.dta` | `merge_ibs_roster.do` | `ibs_output_long` + variabel perusahaan (`f_*`) |

**IMK**:

| Hasil | Dibangun oleh | Isi |
|-------|---------------|-----|
| `imk_firm.dta` | `prepare_imk_panel.do` | perusahaan (level industri) |

Analisis (lensa 2a–2e dsb.) **tidak** di sini — itu ada di repo tetangga
`scarring-industry/`, yang tinggal membaca hasil di atas.

---

## Cara pakai (satu file, berdiri sendiri)

Tiap engine adalah **satu do-file mandiri**: tak perlu MASTER atau SET_FILEPATHS.
Semua setelan ada di **blok CONFIG** di bagian atas file.

1. Buka file prepare yang dituju, edit blok **CONFIG** (minimal `$root` =
   lokasi folder `ibstest` di komputer ini; rentang tahun; toggle convert).
2. Taruh data mentah:
   - **IBS** → `data/raw/mfgYYYY.xlsx` (`convert_first = 1`: di-*import* dari Excel,
     di-*save* jadi `.dta`, baru diolah). Boleh juga langsung `mfgYYYY.dta`.
   - **IMK** → `data/raw_imk/VIMK{YY}.dta` (`convert_first = 0`: baca `.dta` langsung).
     Kalau yang ada baru Excel `VIMK{YY}-Tahunan.xlsx`, set `convert_first = 1`.
   - **IBS roster** → `data/raw/Data Roster Produksi/Bahanbaku{YYYY}.xlsx` dan
     `Proman{YYYY}.xlsx` (akhiran nama file diatur lewat `file_suffix` di CONFIG).
3. Jalankan yang dibutuhkan:
   ```stata
   do "codes/prepare_ibs_panel.do"     // -> data/raw/firm_panel.dta
   do "codes/prepare_ibs_roster.do"    // -> data/raw/ibs_input_long.dta, ibs_output_long.dta
   do "codes/prepare_imk_panel.do"     // -> data/raw/imk_firm.dta
   do "codes/merge_ibs_roster.do"      // -> data/raw/ibs_input_firm.dta, ibs_output_firm.dta
   ```
   `merge_ibs_roster.do` dijalankan **setelah** `prepare_ibs_panel.do` dan
   `prepare_ibs_roster.do`.
   `prepare_ibs_roster.do` bisa jalan sendiri; jalankan `prepare_ibs_panel.do` lebih dulu
   bila ingin *merge check*-nya aktif.

Folder (`data`, `raw`, `raw_imk`, `fig`, `reg`) dibuat otomatis bila belum ada
(`capture mkdir`). Tiap run menulis satu **file log** (`prepare_*_panel_<tgl>_<jam>.log`)
di folder `ibstest`. **Tanpa paket tambahan** — hanya perintah Stata bawaan.

---

## Isi `codes/`

| File | Fungsi |
|------|--------|
| `prepare_ibs_panel.do` | **Engine IBS**: (0) convert Excel→dta, (1) harmonisasi semua tahun + append + *sanity check* → `data/firm_panel.dta` |
| `prepare_imk_panel.do` | **Engine IMK**: (0) convert Excel→dta (opsional), (1) **COLUMN MAP** per tahun + harmonisasi → `data/imk_firm.dta` |
| `prepare_ibs_roster.do` | **Engine roster IBS**: bahan baku & produk per perusahaan (2021–2022), **COLUMN MAP** per tahun → `data/raw/ibs_input_long.dta`, `data/raw/ibs_output_long.dta` |
| `merge_ibs_roster.do` | **Gabungan**: menempelkan variabel perusahaan dari `firm_panel.dta` ke kedua roster (`m:1` pada `fid year`) → `data/raw/ibs_input_firm.dta`, `data/raw/ibs_output_firm.dta` |
| `check_ibs_panel.do` | **Laporan mutu** (hanya membaca): kolom yang hilang per tahun, pangsa *missing*/nol per kelompok variabel, identitas akuntansi, cek rentang, baris duplikat, dan cek panel antar-tahun → log `check_ibs_panel_<tgl>_<jam>.log` (+ dua CSV berisi hitungan di `data/raw/`) |

Folder ini **hanya** berisi engine merging data asli di atas. (Skrip pembuat sampel
sintetis terdahulu sudah dikeluarkan; lihat `KONTEKS_data_sintesis.md`.)

---

## `prepare_ibs_panel.do` — harmonisasi IBS

IBS menamai variabel secara teratur ("nama dasar + 2-digit tahun"), jadi satu loop
membersihkan tiap tahun: huruf kecilkan nama → kunci kolom analisis ke nama baku →
**buang akhiran tahun** dari SEMUA nama lain (`Output10`/`OUTPUT15`/`Output22` → `output`)
→ `destring` → `append`. **SEMUA variabel disimpan** (engine umum), dengan beberapa
kolom analisis diberi nama baku di depan.

Panel hasil (`data/firm_panel.dta`) — nilai **nominal**:

| Variabel | Keterangan |
|----------|-----------|
| `fid` | Pengenal perusahaan |
| `idscheme` | Skema pengenal (penanda validitas link antar-tahun) |
| `year` | Tahun |
| `isic2` / `isic5` | Sektor manufaktur 2-digit / 5-digit |
| `output` `iinput` `va` | Output, input antara, nilai tambah |
| `emp` | Jumlah tenaga kerja |
| `export` | Nilai ekspor |
| `labcost` | Biaya tenaga kerja (olahan; bila tersedia) |
| `w_prod` `w_nonprod` | Upah **mentah** pekerja produksi & non-produksi (input `labcost`, 2010–2018) |
| *(…)* | semua kolom mentah lain ikut tersimpan setelah kolom kunci |

Di akhir ada **SANITY CHECK** yang keras: bila sebuah kolom inti (`output va emp isic5`)
atau `fid` keluar kosong untuk suatu tahun (artinya nama variabel mentah berbeda dari
yang diharapkan), run **dihentikan** (`exit 459`) dengan pesan jelas — supaya run manual
tak sampai menganalisis data kosong. Untuk data asli dengan nama kolom berbeda, edit
daftar rename di langkah **(b)**.

> Deflasi (nominal → riil): sisipkan di penanda `[DEFLATOR]` dalam `prepare_ibs_panel.do`.

---

## `prepare_imk_panel.do` — harmonisasi IMK

IMK mengganti nama kolomnya **tiap tahun**, jadi inti file ini adalah **COLUMN MAP**:
satu blok jelas, satu baris per tahun, memetakan kolom mentah ke empat variabel baku
`emp` (pekerja), `output` (pendapatan), `wage` (balas jasa), `input` (bahan+bahan bakar),
plus `kbli2/kbli5`, kelas ukuran (Mikro/Kecil), dan dua pengelompokan sektor
(`secgroupA` 5 kelompok end-use, `secgroupB` 4 kelompok intensitas faktor).

**Plug-and-play:** satu-satunya yang diedit untuk data asli adalah blok CONFIG +
COLUMN MAP. Kode *existence-guarded*: kolom yang hilang → peringatan, bukan error.

---

## `prepare_ibs_roster.do` — roster bahan baku & produk IBS

"Data Roster Produksi" berisi dua file **long** per tahun: `Bahanbaku{YYYY}` (satu baris =
perusahaan × bahan baku) dan `Proman{YYYY}` (satu baris = perusahaan × produk). Nama
kolomnya berbeda antar tahun, jadi intinya **COLUMN MAP** per jenis file dan tahun.

Hasil: dua tabel long berkunci `fid year line`, ditautkan ke panel perusahaan dengan

```stata
merge m:1 fid year using "data/raw/firm_panel.dta"
```

| Tabel | Kolom khusus |
|-------|--------------|
| `ibs_input_long.dta`  | `q_dom` `v_dom` `q_imp` `v_imp` `v_total` `uv_dom` `uv_imp` `origin_code` `origin_name` |
| `ibs_output_long.dta` | `q` `v` `uv` `export_share` `dest_code` `dest_name` `isic5_product` |

Kolom bersama: `item_name` (teks bebas), `kbki` (teks, nol di depan dipertahankan),
`kbki_name`, `unit_code`, `unit_name`, `unit_filled`, `isic5_roster`, `flag`, `prov`, `kab`.

- Tidak ada baris yang dibuang atau digabung; `flag` (`R`/`N`) dibawa apa adanya.
- Satuan yang hanya punya kode atau hanya punya nama diisi dari tabel kode–nama yang
  dibangun dari seluruh baris; baris yang diisi bertanda `unit_filled = 1`.
- **MERGE CHECK** (hanya di log, tidak menyimpan file): status tautan per tahun, dan
  total roster terhadap total kuesioner utama (`v_dom`↔`rdnvcu`, `v_imp`↔`rimvcu`,
  `v`↔`yprvcu`). Dilewati bila `firm_panel.dta` belum ada atau `fid year` tidak unik
  di panel — seperti di data sampel, yang `fid`-nya disensor.
- Untuk data asli: set `file_suffix` di CONFIG (sampel memakai `_sampel`).

---

## `merge_ibs_roster.do` — roster + variabel perusahaan

Langkah tambahan di atas tiga engine: membaca `firm_panel.dta` dan kedua tabel roster,
lalu menulis dua file baru. Bahan baku dan produk tetap di file **terpisah**, karena
survei tidak mencatat bahan baku mana dipakai untuk produk mana.

- Variabel perusahaan yang dibawa diatur lewat `firm_keep` di CONFIG. Nama yang tidak
  ada di panel dilewati dengan catatan di log.
- Variabel perusahaan berawalan **`f_`** (`f_output`, `f_emp`, …). Nilainya **berulang**
  di tiap baris perusahaan-tahun: jangan dijumlahkan lintas baris.
- Semua baris roster dipertahankan; `in_panel = 0` menandai baris yang perusahaan-tahunnya
  tidak ada di `firm_panel.dta`.
- Kolom tambahan per baris: `n_items`, `v_firm_roster`, `item_share`, `main_item`, dan
  `imp_share` (khusus bahan baku).
- Run **berhenti** bila `fid year` tidak unik di panel untuk tahun roster — seperti di
  data sampel, yang `fid`-nya disensor.

## `check_ibs_panel.do` — laporan mutu panel IBS

Dijalankan **setelah** `prepare_ibs_panel.do`; membaca `data/raw/firm_panel.dta` dan **tidak
mengubah data apa pun**. Hasil utamanya satu file log; dengan `save_csv = 1` juga dua tabel
hitungan (tanpa baris perusahaan): `check_ibs_panel_missing.csv` (variabel × tahun) dan
`check_ibs_panel_checks.csv` (cek × tahun).

1. **Overview**: baris per tahun dan skema id.
2. **Kolom hilang**: kolom yang kosong seluruhnya pada tahun tertentu.
3. **Missing dan nol**: pangsa per tahun menurut kelompok variabel (`g_core`, `g_invest`,
   `g_energy`, … di CONFIG). Nol dan *missing* dilaporkan terpisah.
4. **Konsistensi dalam tahun**: identitas akuntansi (`identities` di CONFIG), cek rentang,
   baris duplikat, lompatan median tahunan (perubahan satuan uang), kolom teks yang isinya angka.
   Juga **plot** log output terhadap modal tetap, investasi, energi dan pajak (meniru Gambar 1
   Gupta 2023): garis putus-putus = semua baris (nol/*missing* di x = 0), garis utuh = hanya x > 0.
   PNG disimpan di `data/raw/` karena tiap titik adalah satu perusahaan-tahun.
5. **Konsistensi antar-tahun**: keunikan id, tautan antar-tahun, entry/exit, lompatan nilai
   dalam perusahaan, pindah KBLI/provinsi, nilai yang sama persis dengan tahun sebelumnya.
   Dilewati untuk tahun yang `fid`-nya disensor atau tidak unik — seperti di data sampel.

Pengelompokan variabel mengikuti konvensi nama IBS; periksa dengan kuesioner sebelum dipakai.

---

## Catatan data sampel

Data asli BPS tak boleh keluar dari komputer terestriksi, jadi do-file ini disusun di
**sampel seformat**: IBS di `data/raw_ibs_sampel/`, IMK di `data/raw_imk/`. Merging-nya
tak pernah membuat/mengarang data — hanya menggabungkan apa adanya, lalu SANITY CHECK
berhenti keras bila nama kolom data asli berbeda. Detail & caveat sampel:
[`KONTEKS_data_sintesis.md`](KONTEKS_data_sintesis.md).

---

## Referensi

Aswicahyono, H., Hill, H., & Narjoko, D. (2010). *Industrialisation after a Deep
Economic Crisis: Indonesia.* The Journal of Development Studies, 46(6), 1084–1108.
Metodologi lengkap: [`ref/Lala.pdf`](../ref/Lala.pdf).
