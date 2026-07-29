## Tentang repo ini

Repository ini digunakan untuk mengetes pipeline workshop penggunaan data IBS dan IMK dari BPS. Workflow ini didasari pada data sample yang ada di local computers dari kamu. Repo ini masih bersifat sangat sementara.

Repo ini dimaintain oleh Meizahra Afidatie, Krisna Gupta dan England Can.

## Cara pakai

### Requirements

Fork dulu repo ini ke komputer lokal anda.

<!-- edit requirement ini -->
Anda memerlukan instalasi Stata dan memerlukan paket  `outreg2` dan `esttab`.

Cara penggunaan:

1. pastikan data berlokasi di "data/raw/" supaya di-gitignored.

2. Buka stata di folder yang sama dengan lokasi datanya, lalu jalankan kode berikut ini:

```{stata}
prepare.do
analysis.do
```

Hasil data yang bersih akan ada di folder "output", hasil gambar akan ada di folder "fig" dan hasil regresi akan ada di fodler "reg".

## Sitasi

Sitasi yang dapat digunakan adalah:

Last, First. year. paper name. DEN Working Paper no. x.

atau jika anda menggunakan bibtex:

```bibtex
@article{citekey,
  author  = {Nash, John},
  title   = {Non-cooperative Games},
  journal = {DEN Working Paper},
  year    = {2026},
  volume  = {3},
  url = {}
}
```

## Lisensi dan Hak Cipta
Seluruh aset, kode, dan data dalam repositori ini dilindungi di bawah **Lisensi DEN**.

Penggunaan, penggandaan, atau pendistribusian materi di dalam repositori ini harus mematuhi ketentuan yang tercantum dalam file **[LICENSE](LICENSE)**.

*Hak Cipta (c) 2026 Dewan Ekonomi Nasional Republik Indonesia (DEN)*
