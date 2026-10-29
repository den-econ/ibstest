* ==============================================================================
* gen_imk_panel.do -- Panel contoh IMK per tahun (2017-2025), SEMUA variabel asli
*                     DIPERTAHANKAN. Panel "by industry": penaut = kbli2 / isic2d.
* ------------------------------------------------------------------------------
* Tiap baris = usaha (firm) IMK; struktur raw VIMK dipertahankan penuh, lalu
* ditambah:
*   year   = tahun
*   kbli2  = KBLI/ISIC Rev.4 2-digit (kode ASLI)
*   isic2d = ISIC Rev.2 2-digit (kunci MERGE ke SI lama 1975-2005) via konkordans
* Nama kolom KBLI beda tiap tahun -> didaftar manual di bawah.
* ==============================================================================

	clear all
	set more off
	set varabbrev off

* --- lokasi folder ------------------------------------------------------------
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"
	global imk "$root/data/raw_imk_sampel"
	global out "$root/data/panel_imk_sintesis"
	capture mkdir "$out"

* --- daftar tahun + nama kolom KBLI 5-digit tiap tahun (sejajar) ---------------
	local years  "17 18 19 20 21 22 23 24 25"
	local kbcols "b2_2052 b2_2052 b2_2042 r204b r204b r204b r205 r205 r205_label"

	local n : word count `years'
	forvalues i = 1/`n' {
		local y  : word `i' of `years'
		local kb : word `i' of `kbcols'
		display "== IMK 20`y' (kolom kbli: `kb') =="

		* baca Excel (SEMUA kolom dipertahankan)
		import excel "$imk/VIMK`y'-Tahunan.xlsx", firstrow clear

		* buat kbli5 dari kolom kbli (kolom asli tetap ada)
		capture confirm numeric variable `kb'
		if _rc  destring `kb', gen(kbli5) force
		else    gen double kbli5 = `kb'

		* kbli2 (asli) + batasi manufaktur 10-33
		gen kbli2 = floor(kbli5/1000)
		keep if kbli2 >= 10 & kbli2 <= 33

		* isic2d = ISIC Rev.2 (buat merge ke SI lama), via konkordans
		gen isic2d = .
		replace isic2d = 31 if inlist(kbli2,10,11,12)
		replace isic2d = 32 if inlist(kbli2,13,14,15)
		replace isic2d = 33 if inlist(kbli2,16,31)
		replace isic2d = 34 if inlist(kbli2,17,18)
		replace isic2d = 35 if inlist(kbli2,19,20,21,22)
		replace isic2d = 36 if kbli2==23
		replace isic2d = 37 if kbli2==24
		replace isic2d = 38 if inlist(kbli2,25,26,27,28,29,30)
		replace isic2d = 39 if inlist(kbli2,32,33)

		gen int year = 2000 + `y'
		label var kbli2  "KBLI/ISIC Rev.4 2-digit (kode asli)"
		label var isic2d "ISIC Rev.2 2-digit (kunci merge ke SI lama)"
		label var kbli5  "KBLI 5-digit"

		* taruh penaut di depan; sisa kolom asli tetap ada
		order year kbli2 isic2d kbli5
		capture order pmid, first

		save "$out/imk20`y'.dta", replace
		count
		display "   -> imk20`y'.dta : `r(N)' usaha, " c(k) " kolom"
	}

* --- gabungkan semua tahun (full: union kolom antar-tahun) --------------------
	clear
	tempfile all
	save `all', emptyok replace
	foreach y of local years {
		append using "$out/imk20`y'.dta", force   // force: gabung walau kolom beda
	}
	save "$out/imk_panel_2017_2025.dta", replace

* --- gabung dgn SI lama 1975-2005, di-link by INDUSTRI 2-digit (isic2d) --------
*   SI lama pakai ISIC Rev.2 (prod5d / isic5); 2-digit-nya = isic2d, cocok dgn
*   isic2d IMK. (Catatan: populasi beda - SI besar/sedang vs IMK mikro/kecil;
*   penautan di level INDUSTRI 2-digit, bukan firm. indus15 tak punya kode industri.)
	global asli "$root/data/ibs"
	tempfile base
	use "$out/imk_panel_2017_2025.dta", clear
	save `base', replace
	foreach spec in "1975 prod5d75" "1985 prod5d85" "1995 prod5d95" "2005 isic5" {
		local yr : word 1 of `spec'
		local pv : word 2 of `spec'
		local yy = substr("`yr'", 3, 2)
		use "$asli/indus`yy'.dta", clear
		capture confirm variable `pv'
		if _rc {
			display "   (lewati `yr': `pv' tak ada)"
			continue
		}
		capture destring `pv', replace force   // sebagian tahun simpan kode sbg teks
		gen isic2d = floor(`pv'/1000)          // ISIC Rev.2 2-digit
		keep if isic2d >= 31 & isic2d <= 39    // manufaktur
		gen int year = `yr'
		append using `base', force
		save `base', replace
	}
	use `base', clear
	order year isic2d
	save "$out/imk_si_panel_1975_2025.dta", replace

	display "Selesai. Panel IMK: $out"
	display "  - imk_panel_2017_2025.dta    (IMK saja, 2017-2025)"
	display "  - imk_si_panel_1975_2025.dta (IMK + SI lama, link isic2d 2-digit)"
	tab year
