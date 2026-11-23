# ibstest — engine pembangun panel BPS (IBS & IMK)

`ibstest` adalah **engine umum**: ia mengubah mikrodata mentah BPS menjadi dua
**panel siap pakai** yang bisa dipakai studi apa pun (bukan hanya *scarring*):

| Panel | Dibangun oleh | Isi |
|-------|---------------|-----|
| `data/firm_panel.dta` | `prepare_ibs_panel.do` | IBS — satu baris = perusahaan × tahun |
| `data/imk_firm.dta`   | `prepare_imk_panel.do` | IMK — satu baris = perusahaan (level industri) |

Analisis (lensa 2a–2e dsb.) **tidak** di sini — itu ada di repo tetangga
`scarring-industry/`, yang tinggal membaca kedua panel di atas lewat `$data`.

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
3. Jalankan salah satu:
   ```stata
   do "codes/prepare_ibs_panel.do"     // -> data/firm_panel.dta
   do "codes/prepare_imk_panel.do"     // -> data/imk_firm.dta
   ```

Folder (`data`, `raw`, `raw_imk`, `fig`, `reg`) dibuat otomatis bila belum ada
(`capture mkdir`). Tiap run menulis satu **file log** (`prepare_*_panel_<tgl>_<jam>.log`)
di folder `ibstest`. **Tanpa paket tambahan** — hanya perintah Stata bawaan.

---

## Isi `codes/`

| File | Fungsi |
|------|--------|
| `prepare_ibs_panel.do` | **Engine IBS**: (0) convert Excel→dta, (1) harmonisasi semua tahun + append + *sanity check* → `data/firm_panel.dta` |
| `prepare_imk_panel.do` | **Engine IMK**: (0) convert Excel→dta (opsional), (1) **COLUMN MAP** per tahun + harmonisasi → `data/imk_firm.dta` |

Folder ini **hanya** berisi dua engine merging data asli di atas. (Skrip pembuat sampel
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
