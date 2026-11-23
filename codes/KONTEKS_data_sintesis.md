# Konteks: data sampel (seformat data asli)

Alur kerja proyek ini:

> **Data asli (IBS/IMK BPS) tidak boleh keluar dari komputer terestriksi.** Maka sebuah
> **sampel seformat** disediakan di luar. Do-file merging disusun & diuji memakai sampel
> itu, lalu dibawa masuk untuk dijalankan pada **data asli** di komputer tersebut.

Engine di `codes/` (`prepare_ibs_panel.do`, `prepare_imk_panel.do`) hanya
**membaca → menyeragamkan nama → menumpuk antar-tahun → menyimpan**. Tidak ada data
yang dibuat atau dikarang. Selama nama variabel data asli **sama** dengan sampel,
do-file jalan tanpa diubah; kalau ada yang beda, **SANITY CHECK** di akhir
`prepare_ibs_panel.do` berhenti keras dan menyebut kolom yang bermasalah.

## Lokasi sampel
| Folder | Isi |
|--------|-----|
| `data/raw_ibs_sampel/` | `mfg2010…2022.dta` — sampel mentah IBS |
| `data/raw_imk/` | `VIMK17…25` — sampel mentah IMK (ganti dengan file asli saat run data asli) |

## Caveat sampel (BUKAN sifat data asli)
- **Id perusahaan pada sampel IBS ter-mask**, sehingga penelusuran firma antar-tahun
  (lensa mobilitas / entry-exit / dekomposisi) **tidak bermakna di sampel** — namun
  **bermakna di data asli** yang id-nya nyata.
- Klasifikasi industri: IMK memakai KBLI / ISIC Rev.4 (2-digit 10–33); seri SI historis
  memakai ISIC Rev.2 (31–39) — hanya relevan bila menautkan ke seri historis.
- Semua nilai **nominal**.

> Catatan: skrip pembuat sampel sintetis terdahulu (`gen_ibs_psid.do`,
> `gen_imk_panel.do`, `concordance_kbli_isic2.do`) sudah dikeluarkan dari `codes/`
> supaya folder ini **murni berisi merging data asli**. Skrip itu masih tersimpan di
> riwayat git bila sewaktu-waktu diperlukan.
