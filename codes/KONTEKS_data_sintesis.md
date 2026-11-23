# Konteks: Data Sintesis IBS & IMK (ber-id, bisa di-merge ke data asli)

Dokumen ini menjelaskan **mengapa & bagaimana** data sintesis ini dibuat, apa saja
sumbernya, keputusan desainnya, dan file hasilnya.

---

## 1. Tujuan

Mengembangkan & menguji pipeline analisis di **data contoh**, lalu menjalankannya di
**data asli** (Statistik Industri / IBS, ada di komputer lain). Masalahnya:

- Sampel IBS yang kita punya **id perusahaannya ter-mask** (`"***"`) → tak bisa dipanel
  dari id aslinya.
- Jadi dibuat **panel SINTESIS** yang: (a) bisa dipanel antar-tahun, dan
  (b) **bisa di-merge ke data asli** memakai id/kunci yang NYATA (bukan asal-asalan).

---

## 2. Sumber data

| Folder | Isi | Status |
|--------|-----|--------|
| `data/ibs/` | `indus75/85/95/05/15` (SI historis), `rawin*`, `proin*`, metadata | **ASLI** |
| `data/raw_ibs_sampel/` | `mfg2010…2022.dta` | sampel mentah IBS (id ter-mask) |
| `data/raw_imk/` | `VIMK17…25-Tahunan.xlsx` | sampel mentah IMK |

---

## 3. Temuan kunci (yang membentuk desain)

- **Sampel IBS** id-nya ter-mask → penaut panel harus dibuat.
- **Data asli** memakai penaut `psid`/`nkip`/`kip`, TAPI skema penomoran berganti:
  - `psid95` (counter 4–5 digit) **≠** `nkip05`/`kip` (kode 9-digit) → **1995 tak
    nyambung** ke 2005/2015 (dicoba samakan format → ISIC cocok 0% = kebetulan).
  - **`nkip05` ↔ `kip` (2005↔2015) = 1.651 firm** match (satu-satunya jembatan firm nyata).
  - `indus75/85` **tak punya id firm** sama sekali.
- **Klasifikasi industri beda revisi**: SI lama = **ISIC Rev.2** (2-digit **31–39**);
  IMK = **KBLI / ISIC Rev.4** (2-digit **10–33**) → butuh **konkordans** untuk menautkan.

---

## 4. Yang dibuat

### 4a. IBS — panel per FIRM, merge by firm id → 2005
- **100 firm** sintetis. Nilai ekonomi diambil dari **sampel** `mfg`, struktur raw utuh.
- **`psid` = `nkip05` ASLI** (ditarik acak dari `indus05`) → panel **benar-benar match**
  saat di-merge ke data asli 2005.
- Record **2005 asli** (`indus05`) di-**append** sebagai `year=2005` → panel span
  **2005 (asli) + 2010–2022 (sintetis)**, nyambung antar-tahun lewat `psid`.
- Unbalanced (entry/exit) + variasi ukuran → lensa mobilitas/entry-exit/dekomposisi aktif.
- **File merged:** `data/panel_ibs_sintesis/ibs_panel_2010_2022.dta`
  (± 1.087 baris, 100 firm, ± 2.678 kolom; kolom `*05` dari asli, `*10`–`*22` dari sintetis).
  Di-edit untuk **keep hanya firm yang match** (hadir di 2005 **dan** tahun sintetis).
- **Per-tahun (sintetis):** `mfg2010…2022.dta` — **tetap disimpan** (belum di-merge).

### 4b. IMK — panel per INDUSTRI, merge by industri 2-digit → SI 1975–2005
- IMK (2017–2025) **level usaha**, **semua variabel asli VIMK dipertahankan**, + `year`,
  `kbli2` (KBLI asli), `kbli5`, **`isic2d`** (ISIC Rev.2 via konkordans).
- Record **SI asli 1975/85/95/2005** di-**append**, ditautkan lewat **`isic2d`**
  (ISIC Rev.2 2-digit) → panel span **1975/85/95/2005 (asli) + 2017–2025 (IMK)**.
- **File merged:** `data/panel_imk_sintesis/imk_si_panel_1975_2025.dta`
  (± 142.474 baris, ± 1.917 kolom). Di-edit untuk **keep hanya industri yang match**
  (`isic2d` hadir di era SI **dan** era IMK).
- **Per-tahun:** `imk2017…2025.dta` + `imk_panel_2017_2025.dta` (IMK saja) — **tetap disimpan**.
- ⚠️ Populasi beda (SI **besar/sedang** vs IMK **mikro/kecil**) → tautan di level
  **industri 2-digit**, bukan firm. `indus15` dilewati (tak ada kode industri).

### 4c. Konkordans industri
- **KBLI/ISIC Rev.4 (10–33) → ISIC Rev.2 (31–39)**, 2-digit (korespondensi baku UN/BPS).
- **File:** `data/concordance_kbli2_isic2rev2.dta` (+ `.csv`).

---

## 5. Kunci merge (ringkas)

| Panel | Tahun lama (asli) | Kunci merge | Unit |
|-------|-------------------|-------------|------|
| **IBS** | 2005 | `psid` (= `nkip05`) | **firm** |
| **IMK** | 1975, 1985, 1995, 2005 | `isic2d` (ISIC Rev.2 2-digit) | **industri** |

---

## 6. Cara regenerate (do-file Stata, reproducible)

```stata
do "code/concordance_kbli_isic2.do"   // tabel konkordans
do "code/gen_ibs_psid.do"             // panel IBS (merge ke 2005)
do "code/gen_imk_panel.do"            // panel IMK (merge ke SI 1975-2005)
```
- `set seed` dipakai di IBS → hasil bisa diulang.
- File **per-tahun tetap disimpan**; hanya file **merged** yang diedit agar berisi
  record yang **match** (firm/industri yang hadir di kedua era).

---

## 7. Catatan penting / caveat

- **IBS**: nilai `psid` NYATA (`nkip05`), tapi firm-nya **sintetis** (nilai = baris sampel
  acak). Jadi merge-nya **mekanis valid** (kunci cocok), **bukan** identitas firm sungguhan.
  Merge lintas-tahun (atribut 2005 ditempel per firm ke seluruh tahun).
- **IMK**: beda populasi (SI vs IMK) & beda revisi klasifikasi → tautan industri bersifat
  **aproksimasi** (konkordans 2-digit). Kode raw VIMK beda tiap vintage.
- Nilai bersifat **nominal**.
- `1995` dan `indus75/85` **tak bisa** ditautkan firm-level (skema/absen id) — hanya
  via industri (IMK) untuk 1975/85/95.
