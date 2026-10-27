* ==============================================================================
* imk_prepare.do -- Gabungkan 3 file VIMK jadi SATU .dta firm-level, per tahun
* ------------------------------------------------------------------------------
* Untuk tiap tahun (2023, 2024):
*   01 tabel utama : 1 baris per firm (pmid)  -> basis
*   02 bahan baku  : long (item/firm)  -> diringkas (total nilai + jumlah)
*   03 komoditas   : long (produk/firm)-> diringkas (total nilai + jumlah)
* Hasil: data/raw imk/vimkYYYY.dta  (1 baris per firm)
* ==============================================================================

	clear all
	set more off

	if "$root" == "" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	global imk "$root/data/raw imk"

foreach yr in 2023 2024 {

	display "== Memproses VIMK`yr' =="

	* --- (1) tabel utama: 1 baris per firm ---
	import excel "$imk/VIMK`yr' - 01 - tabel utama.xlsx", firstrow clear
	capture tostring pmid, replace                 // pmid = kode/UUID -> string
	tempfile utama
	save `utama'

	* --- (2) bahan baku (long) -> ringkas per firm ---
	import excel "$imk/VIMK`yr' - 02 - bahan baku.xlsx", firstrow clear
	capture tostring pmid, replace
	capture destring nilai, replace force
	collapse (sum) bb_nilai_total=nilai (count) bb_n_item=nilai, by(pmid)
	label var bb_nilai_total "Total nilai bahan baku (file 02)"
	label var bb_n_item      "Jumlah jenis bahan baku"
	tempfile bb
	save `bb'

	* --- (3) komoditas (long) -> ringkas per firm ---
	import excel "$imk/VIMK`yr' - 03 - komoditas.xlsx", firstrow clear
	capture tostring pmid, replace
	capture destring nilai, replace force
	collapse (sum) kom_nilai_total=nilai (count) kom_n_produk=nilai, by(pmid)
	label var kom_nilai_total "Total nilai komoditas/produk (file 03)"
	label var kom_n_produk    "Jumlah jenis produk"
	tempfile kom
	save `kom'

	* --- gabung ke tabel utama (1:1 by pmid) ---
	use `utama', clear
	merge 1:1 pmid using `bb',  keep(master match) nogen
	merge 1:1 pmid using `kom', keep(master match) nogen
	gen int year = `yr'

	order pmid year prov kab kbli2 kbli5
	compress
	save "$imk/vimk`yr'.dta", replace
	display as result "== tersimpan: $imk/vimk`yr'.dta =="
	count
}
