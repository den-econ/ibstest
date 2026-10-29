* ==============================================================================
* gen_ibs_psid.do -- Panel contoh IBS yang BISA DI-MERGE ke data asli 2005
* ------------------------------------------------------------------------------
* Ide: ambil id ASLI (nkip05) dari data 2005 (ibs/indus05.dta), lalu tempelkan
* ke data sampel mfgYYYY sebagai "psid". Karena nilainya id asli, panel sampel
* ini BENAR-BENAR cocok saat di-merge ke indus05 (sintetis tapi mergeable).
*
* - Nilai ekonomi: dari SAMPEL (mfgYYYY).
* - psid        : nilai asli nkip05 (string) -> ~500 firm, ada entry/exit.
* - Hasil       : data/panel_ibs_sintesis/mfgYYYY.dta (kolom raw + psid).
* ==============================================================================

	clear all
	set more off
	set varabbrev off
	set seed 12345                              // supaya hasil bisa diulang

	local NFIRM = 500                           // jumlah firm (>100, ~30% dari 1.651 matched)

* --- lokasi folder (ganti bila beda komputer) ---------------------------------
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"
	global src  "$root/data/raw_ibs_sampel"     // data sampel (nilai ekonomi)
	global asli "$root/data/ibs"                // data asli (sumber id + target merge)
	global out  "$root/data/panel_ibs_sintesis"   // output
	capture mkdir "$out"

* --- (1) Ambil `NFIRM` id asli (nkip05) dari data 2005 ------------------------
	use "$asli/indus05.dta", clear
	keep nkip05
	duplicates drop
	gen double r = runiform()
	sort r
	keep if _n <= `NFIRM'
	gen psid = nkip05                           // psid = id asli 2005 (string)
	keep psid

	* beri tiap firm tahun masuk (entry) & keluar (exit) -> panel unbalanced
	gen double u = runiform()
	gen double w = runiform()
	gen entry = 2010
	gen exit  = 2022
	replace entry = 2012 + floor(w*4) if u > 0.60 & u <= 0.80   // ~20% masuk telat
	replace exit  = 2017 + floor(w*4) if u > 0.80 & u <= 0.95   // ~15% keluar awal
	replace entry = 2013 if u > 0.95                            // ~5% umur pendek
	replace exit  = 2019 if u > 0.95
	tempfile roster
	save `roster'

* --- (2) Tiap tahun: tempel psid ke baris sampel acak -------------------------
	local years "2010 2011 2012 2013 2014 2015 2017 2018 2019 2020 2021 2022"
	foreach y of local years {

		* firm yang hadir tahun ini -> urut acak -> beri nomor baris
		use `roster', clear
		keep if entry <= `y' & exit >= `y'
		gen double pr = runiform()
		sort pr
		gen long rowid = _n
		keep psid rowid
		count
		local nfirm = r(N)
		tempfile pres
		save `pres'

		* ambil sebanyak itu baris acak dari sampel -> beri nomor baris
		use "$src/mfg`y'.dta", clear
		gen double pr = runiform()
		sort pr
		gen long rowid = _n
		keep if rowid <= `nfirm'

		* tempel psid lewat nomor baris
		merge 1:1 rowid using `pres', keep(match) nogen
		drop rowid pr
		order psid

		save "$out/mfg`y'.dta", replace
		display "   -> mfg`y'.dta : `nfirm' firm"
	}

* --- (3) Gabungan semua tahun (FULL raw: semua kolom di-union) ----------------
	clear
	tempfile allibs
	save `allibs', emptyok replace
	foreach y of local years {
		use "$out/mfg`y'.dta", clear
		capture drop year
		gen int year = `y'                      // penanda tahun
		append using `allibs', force            // force: gabung walau tipe kolom beda antar-tahun
		save `allibs', replace
	}
	use `allibs', clear
	order psid year
	save "$out/ibs_panel_2010_2022.dta", replace
	display "   -> ibs_panel_2010_2022.dta (gabungan semua tahun, full raw)"

* --- (4) Tambah data ASLI 2005 sebagai year=2005 (append) ---------------------
*   Ambil record 2005 untuk 500 firm panel kita (lewat psid=nkip05), tandai
*   year=2005, lalu tempel (append) ke panel. Jadi 2005=ASLI, 2010-2022=sintetis.
	use "$asli/indus05.dta", clear
	rename nkip05 psid                          // samakan nama id dgn panel
	merge 1:1 psid using `roster', keep(match) nogen   // hanya 500 firm panel kita
	gen int year = 2005
	tempfile real2005
	save `real2005'

	use "$out/ibs_panel_2010_2022.dta", clear
	append using `real2005', force             // 2005 (asli) + 2010-2022 (sintetis); kolom di-union
	order psid year
	save "$out/ibs_panel_2010_2022.dta", replace
	display _n "   -> ibs_panel_2010_2022.dta : 2005 (asli) + 2010-2022 (sintetis)"
	tab year
