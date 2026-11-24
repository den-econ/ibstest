# Deflator energi: harga listrik industri PLN, 2000–2023

Catatan ini menjelaskan asal dan cara penyusunan deret harga listrik yang dipakai
untuk mendeflasi nilai konsumsi energi IBS.

## Mengapa deret ini diperlukan

`data/wpi_extended_1990t2022.dta` hanya memuat sektor manufaktur (ISIC Rev.3 divisi
15–37). Satu-satunya harga energi di dalamnya adalah divisi 23 (kokas dan hasil kilang
minyak), yaitu harga **BBM**. Berkas itu **tidak** memuat indeks harga listrik, gas,
atau batu bara. API BPS juga tidak menyediakan harga listrik industri.

Tarif listrik industri diatur pemerintah dan bergerak berbeda dari harga BBM: pada
2017–2022 harga listrik industri datar, sedangkan WPI divisi 23 naik dari 133 ke 174.
Mendeflasi listrik dengan indeks BBM akan merendahkan konsumsi listrik riil 2022
sekitar seperlima.

## Berkas

| Berkas | Lokasi |
|---|---|
| `energy_price_esdm.csv` | repo `scarring-industry`, folder `data/` |
| pemakai | `scarring-industry/codes/ibs/2h_energy.do` (`$energy_defl = "mix"`) |

Kolom:

| Kolom | Isi |
|---|---|
| `year` | tahun, 2000–2023 |
| `elec_industry_krp_boe` | harga jual rata-rata listrik PLN ke industri, ribu Rp per BOE |
| `elec_industry_rp_kwh` | harga yang sama dalam Rp per kWh |
| `elec_industry_index_2010` | indeks, 2010 = 100 (ini yang dipakai sebagai deflator) |
| `elec_household_krp_boe`, `elec_commercial_krp_boe` | harga listrik rumah tangga dan komersial, ribu Rp per BOE |
| `coal_krp_boe` | harga batu bara, ribu Rp per BOE (belum dipakai) |
| `source` | edisi buku sumber untuk tahun tersebut |

## Sumber

*Handbook of Energy & Economic Statistics of Indonesia* (HEESI), Kementerian ESDM,
tabel 4.4 "Energy Price per Energy Unit" (tabel 4.5 pada edisi 2009), kolom
"Electricity (Average) – Industry". Semua edisi dapat diunduh dari
<https://www.esdm.go.id/en/publikasi/handbook-of-energy-economic-statistics-of-indonesia>.

Angka ini adalah **pendapatan rata-rata per kWh** dari seluruh pelanggan industri PLN,
bukan daftar tarif per golongan, dan tidak mencakup listrik non-PLN.

## Konversi satuan

Buku sumber melaporkan harga per BOE. Konversi ke Rp/kWh memakai faktor buku itu
sendiri, 1 MWh = 0,613 BOE:

```
Rp/kWh = (ribu Rp/BOE) × 0,613
```

Contoh: 2010, 1.078 ribu Rp/BOE × 0,613 = Rp 660,8/kWh.

## Penyambungan antar-edisi

Tidak ada satu edisi yang mencakup 2000–2023, dan edisi-edisi itu **tidak konsisten**
untuk 2008 dan 2009.

| Tahun | Edisi yang dipakai | Alasan |
|---|---|---|
| 2000–2007 | HEESI 2012 | identik dengan edisi 2016 |
| 2008 | HEESI 2009 | lihat di bawah |
| 2009 | HEESI 2019 | lihat di bawah |
| 2010–2012 | HEESI 2020 | identik dengan edisi 2019 |
| 2013–2023 | HEESI 2023 | identik dengan edisi 2020 pada 2013–2020 |

Masalah 2008–2009 (harga industri, ribu Rp/BOE):

| Edisi | 2007 | 2008 | 2009 | 2010 | 2011 |
|---|---|---|---|---|---|
| 2009 | 1.013,6 | **1.014,7** | – | – | – |
| 2012 | 1.013,6 | 1.013,6 (salin 2007) | 1.014,7 | 1.051,1 | 1.078,3 |
| 2016 | 1.013,6 | 912,2 (salin 2004) | 1.014,7 | 1.078,3 | 1.134,5 |
| 2018 | 1.013,6 | 493,5 (salin 2000) | 1.014,7 | 1.078,3 | 1.134,5 |
| 2019 | – | – | **1.051** | 1.078 | 1.135 |

- **2008** diambil dari edisi 2009, edisi yang terbit paling dekat dengan tahun itu.
  Baris 2008 pada edisi 2012, 2016, dan 2018 adalah salinan baris tahun lain.
- **2009** diambil dari edisi 2019. Edisi 2012, 2016, dan 2018 menaruh nilai 2008 di
  baris 2009; pada edisi 2012 seluruh baris 2009–2011 tergeser satu tahun.

Pilihan ini adalah penilaian penyusun, bukan koreksi resmi ESDM. Panel IBS mulai 2010,
jadi pilihan 2008–2009 tidak memengaruhi studi *scarring*. Untuk pemakaian lain,
cocokkan dua tahun itu dengan *Statistik PLN*.

## Pemeriksaan silang

Nilai 2021 (Rp 1.086,2/kWh) sama dengan angka harga jual industri PLN yang dilaporkan
Databoks (Rp 1.086,22/kWh).

## Deret (Rp/kWh)

| Tahun | Rp/kWh | Tahun | Rp/kWh | Tahun | Rp/kWh |
|---|---|---|---|---|---|
| 2000 | 302,5 | 2008 | 622,0 | 2016 | 1.051,9 |
| 2001 | 361,7 | 2009 | 644,3 | 2017 | 1.088,7 |
| 2002 | 442,9 | 2010 | 660,8 | 2018 | 1.085,0 |
| 2003 | 530,3 | 2011 | 695,8 | 2019 | 1.100,9 |
| 2004 | 559,1 | 2012 | 709,9 | 2020 | 1.091,1 |
| 2005 | 569,9 | 2013 | 796,3 | 2021 | 1.086,2 |
| 2006 | 621,2 | 2014 | 977,7 | 2022 | 1.080,7 |
| 2007 | 621,3 | 2015 | 1.142,6 | 2023 | 1.080,1 |

## Keterbatasan

- Gas, batu bara, dan biomassa belum punya deflator sendiri; di `2h_energy.do`
  ketiganya masih dideflasi dengan WPI divisi 23.
- Listrik non-PLN dideflasi dengan harga PLN.
- Berkas CSV disusun dari PDF dengan skrip sekali pakai yang tidak disimpan di repo.
