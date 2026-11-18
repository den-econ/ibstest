* ==============================================================================
* concordance_kbli_isic2.do
* ------------------------------------------------------------------------------
* WHAT THIS FILE DOES:
*   Builds a small 2-digit "concordance" (a lookup/crosswalk) table that maps
*   KBLI / ISIC Rev.4 industry codes (10-33) onto the older ISIC Rev.2 codes
*   (31-39). Why: it lets us link the IMK data (which uses KBLI) to the old
*   Industri Besar/Sedang (SI) surveys from 1975/85/95 (which use ISIC Rev.2),
*   using the SAME industry grouping (9 Rev.2 divisions).
*   Source: the standard UN/BPS 2-digit correspondence (approximate).
*
* INPUT  : none (the table is typed in by hand below).
* OUTPUT : data/concordance_kbli2_isic2rev2.dta  (+ a .csv copy).
* HOW TO RUN:  do "code/concordance_kbli_isic2.do"
* ==============================================================================

	// Start clean: wipe data/programs/etc. from memory, and don't pause output.
	clear all
	set more off
	// A "global macro" is a named value reused later, written as $name.
	// Set the project root folder for this machine (falls back to the current
	// working directory if the username is not the one listed).
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"
	global data "$root/data"
	global asli "$root/data/ibs"

* --- (1) Build the concordance table by hand ----------------------------------
	// "input" lets us type a dataset directly. We declare 3 columns and their
	// types: kbli2 (integer), isic2_r2 (integer), kbli_label (string, 28 chars),
	// then list one row per KBLI division until "end".
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

	// Attach readable names to the 9 ISIC Rev.2 division codes. "label define"
	// creates a named set of code->text pairs; "label values" ties it to a
	// variable so 31 shows as "Makanan/minuman/tembakau", etc. "///" just
	// continues a long command onto the next line.
	label define r2 31 "Makanan/minuman/tembakau" 32 "TPT & kulit" ///
	                33 "Kayu & furnitur" 34 "Kertas & percetakan" ///
	                35 "Kimia/migas/karet" 36 "Galian bukan logam" ///
	                37 "Logam dasar" 38 "Logam/mesin/alat angkut" ///
	                39 "Pengolahan lainnya"
	label values isic2_r2 r2
	// "label var" sets the human-readable description of a column.
	label var kbli2    "KBLI / ISIC Rev.4 2-digit"
	label var isic2_r2 "ISIC Rev.2 2-digit"

	// Save the finished crosswalk as a Stata file, plus a plain-text CSV copy.
	save "$data/concordance_kbli2_isic2rev2.dta", replace
	export delimited "$data/concordance_kbli2_isic2rev2.csv", replace
	display "Concordance saved (24 KBLI codes -> 9 ISIC Rev.2 divisions)."

	display "Concordance table: $data/concordance_kbli2_isic2rev2.dta (+ .csv)"
