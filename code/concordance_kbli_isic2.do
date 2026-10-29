* ==============================================================================
* concordance_kbli_isic2.do
* ------------------------------------------------------------------------------
* Tabel konkordans 2-digit: KBLI / ISIC Rev.4 (10-33)  ->  ISIC Rev.2 (31-39)
* Gunanya: menautkan IMK (pakai KBLI) dengan SI lama 1975/85/95 (pakai ISIC Rev.2)
* pada klasifikasi industri yang SAMA (9 golongan Rev.2).
* Sumber: korespondensi baku UN/BPS di level 2-digit (aproksimasi).
* ==============================================================================

	clear all
	set more off
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"
	global data "$root/data"
	global asli "$root/data/ibs"

* --- (1) Bangun tabel konkordans ----------------------------------------------
	clear
	input int kbli2 int isic2_r2 str28 kbli_label
	10 31 "Makanan"
	11 31 "Minuman"
	12 31 "Tembakau"
	13 32 "Tekstil"
	14 32 "Pakaian jadi"
	15 32 "Kulit & alas kaki"
	16 33 "Kayu (bukan furnitur)"
	31 33 "Furnitur"
	17 34 "Kertas"
	18 34 "Percetakan"
	19 35 "Migas & batubara"
	20 35 "Kimia"
	21 35 "Farmasi"
	22 35 "Karet & plastik"
	23 36 "Galian bukan logam"
	24 37 "Logam dasar"
	25 38 "Barang logam"
	26 38 "Komputer & elektronik"
	27 38 "Peralatan listrik"
	28 38 "Mesin n.e.c."
	29 38 "Kendaraan bermotor"
	30 38 "Alat angkutan lain"
	32 39 "Pengolahan lainnya"
	33 39 "Reparasi mesin"
	end

	label define r2 31 "Makanan/minuman/tembakau" 32 "TPT & kulit" ///
	                33 "Kayu & furnitur" 34 "Kertas & percetakan" ///
	                35 "Kimia/migas/karet" 36 "Galian bukan logam" ///
	                37 "Logam dasar" 38 "Logam/mesin/alat angkut" ///
	                39 "Pengolahan lainnya"
	label values isic2_r2 r2
	label var kbli2    "KBLI / ISIC Rev.4 2-digit"
	label var isic2_r2 "ISIC Rev.2 2-digit"

	save "$data/concordance_kbli2_isic2rev2.dta", replace
	export delimited "$data/concordance_kbli2_isic2rev2.csv", replace
	display "Konkordans tersimpan (24 KBLI -> 9 golongan Rev.2)."

* --- (2) DEMO: IMK per golongan ISIC Rev.2 (lewat isic2d) --------------------
	display _n "=== IMK 2023 per ISIC Rev.2 (jumlah usaha) ==="
	use "$data/panel_imk_sintesis/imk2023.dta", clear
	gen satu = 1
	collapse (sum) n_usaha=satu, by(isic2d)
	list isic2d n_usaha, noobs

* --- (3) DEMO: SI 1975 sudah ISIC Rev.2 -> golongan yang sama -----------------
	display _n "=== SI 1975 (indus75) per golongan ISIC Rev.2 ==="
	use "$asli/indus75.dta", clear
	gen isic2_r2 = floor(prod5d75/1000)
	gen satu = 1
	collapse (sum) n_usaha75=satu, by(isic2_r2)
	list isic2_r2 n_usaha75, noobs
