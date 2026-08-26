# Do-file: Replikasi kerangka 6-lensa AHN (2010)

Pipeline Stata untuk mereplikasi kerangka penelusuran *firm-level* Aswicahyono,
Hill & Narjoko (2010) — analisis "scarring" manufaktur — memakai mikrodata IBS
2010–2022. Metodologi lengkap ada di [`ref/Lala.pdf`](../ref/Lala.pdf).

Pipeline dirancang **plug-and-play**: kembangkan/uji di data sampel, lalu jalankan
apa adanya di komputer berisi data asli.

---

## Cara pakai (3 langkah)

1. Taruh mikrodata mentah di `data/raw/` (file `mfgYYYY.dta`).
2. Buka Stata **di folder repo ini** (atau `cd` ke sana).
3. Jalankan:
   ```stata
   do "code/MASTER.do"
   ```

Tidak perlu mengedit path per-komputer. Bila di komputer lain tidak bisa membuka
Stata di folder repo, isi `$root` secara manual di
[`SET_FILEPATHS.do`](SET_FILEPATHS.do).

**Tanpa paket tambahan** — hanya perintah Stata bawaan (butuh Stata 16+).

---

## Struktur

Satu **master** mengontrol seluruh **sub-file** lewat sakelar nyala/mati.

**Section 1** = paneling · **Section 2** = cleaning & analysis.

| File | Fungsi | Output |
|------|--------|--------|
| [`MASTER.do`](MASTER.do) | Kontrol pusat: setelan + trigger tiap sub-file | — |
| [`SET_FILEPATHS.do`](SET_FILEPATHS.do) | Tetapkan semua path dari folder kerja Stata | — |
| [`1_prepare.do`](1_prepare.do) | Bersihkan semua tahun (loop) + append → panel firm-year baku | `data/firm_panel.dta` |
| [`2a_growth.do`](2a_growth.do) | Pertumbuhan output & nilai tambah | `output/2a_*.csv` |
| [`2b_jobless_growth.do`](2b_jobless_growth.do) | Produktivitas TK & *jobless growth* | `output/2b_*.csv`, `output/2b_jobless_growth.png` |
| [`2c_size_mobility.do`](2c_size_mobility.do) | Matriks transisi kelas ukuran | `output/2c_transition_*.csv` |
| [`2d_entry_exit.do`](2d_entry_exit.do) | Entry/exit rate | `output/2d_entry_exit.csv`, `output/2d_entry_exit.png` |
| [`2e_decomposition.do`](2e_decomposition.do) | Dekomposisi ekspansi/kontraksi TK | `output/2e_decomp.csv` |

Semua hasil → folder [`output/`](../output/): tiap tabel disimpan **`.csv` + `.xlsx`**,
gambar `.png`, plus **`firm_panel.xlsx`** (salinan Excel dataset olahan).

Tiap sub-file **berdiri sendiri** (membaca `data/firm_panel.dta` dari disk), jadi
bisa dijalankan ulang terpisah.

---

## Setelan di `MASTER.do`

Semua yang perlu diubah ada di bagian atas `MASTER.do`.

**Sumber data** (`$source`):

| Nilai | Arti |
|-------|------|
| `"auto"` *(default)* | Coba `raw`; bila id firm ter-mask (spt data sampel) → otomatis pakai panel sintetis. |
| `"raw"` | Paksa dari `data/raw/mfgYYYY.dta`. **← dipakai di data ASLI.** |
| `"panel"` | Paksa dari `data/ibs_panel_2010_2022.csv` (uji). |

**Setelan lain:** rentang tahun, tahun krisis (`$crisis_year`, default 2020 =
COVID), tahun basis indeks, ambang kelas ukuran, dan pasangan tahun untuk matriks
transisi.

**Trigger:** set `1` (jalankan) atau `0` (lewati) untuk tiap langkah.

### Alur hemat waktu (komputer terbatas)
1. Jalankan sekali dengan `s1_prepare = 1` → panel tersimpan ke `data/firm_panel.dta`.
2. Set `s1_prepare = 0`, lalu nyalakan hanya lensa yang ingin dijalankan ulang.

---

## Panel hasil olahan — `data/firm_panel.dta`

Satu baris = perusahaan × tahun. Nilai **nominal** (ribu Rp).

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

Disimpan sebagai **`.dta`** (di `data/firm_panel.dta`) **+ `.xlsx`** (di `output/firm_panel.xlsx`).

---

## Catatan penting

- **ID firm ter-mask di data sampel.** Di `data/raw/` sampel, id perusahaan
  disamarkan (`"***"`), sehingga penelusuran firm-level (Lensa 4/5/6) tidak bisa
  dari raw. Mode `auto` otomatis beralih ke panel sintetis yang id-nya valid. **Di
  data asli id tidak ter-mask**, jadi `auto` langsung memakai jalur `raw`.

- **Validitas linkage.** Entry/exit & dekomposisi hanya menautkan tahun
  **berurutan dengan skema id sama**; pasangan yang melewati pergantian skema BPS
  atau tahun bolong otomatis dilewati.

- **Panel sintetis bersifat *balanced*** (firm sama tiap tahun), sehingga di
  sampel entry/exit = 0 — itu sifat data contoh, bukan bug. Pada data asli yang
  tidak balanced, Lensa 5 & 6 akan informatif.

- **Nominal vs riil.** Nilai masih nominal. Untuk versi riil, sisipkan deflasi per
  sektor pada penanda `[DEFLATOR]` di `1_prepare.do`.

---

## Referensi

Aswicahyono, H., Hill, H., & Narjoko, D. (2010). *Industrialisation after a Deep
Economic Crisis: Indonesia.* The Journal of Development Studies, 46(6), 1084–1108.
