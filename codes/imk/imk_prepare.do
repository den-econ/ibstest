* ==============================================================================
* imk_prepare.do -- combine the 3 VIMK Excel files into ONE firm-level .dta per year
* ------------------------------------------------------------------------------
* WHAT THIS FILE DOES (for each year 2023, 2024):
*   file 01 main table   : one row per firm (pmid)          -> the base
*   file 02 raw materials: long (one row per item per firm) -> summarized per firm
*   file 03 commodities  : long (one row per product/firm)  -> summarized per firm
*   The three are merged into a single row per firm.
*
* INPUT  : data/raw imk/VIMK{YYYY} - 01/02/03 - *.xlsx
* OUTPUT : data/raw imk/vimk{YYYY}.dta   (one row per firm)
* HOW TO RUN:  do "code/imk_prepare.do"
*
* NOTE: this is the older per-year combiner. The current pipeline uses
*       convert_imk_dta.do + imk_1_prepare.do instead.
* ==============================================================================

	// Start clean; keep output flowing.
	clear all
	set more off

	// Project root folder (falls back to the current working directory).
	if "$root" == "" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	global imk "$root/data/raw imk"

// "foreach yr in ..." repeats the whole block once per year listed.
foreach yr in 2023 2024 {

	display "== Processing VIMK`yr' =="

	* --- (1) main table: one row per firm ---
	// Read the Excel sheet; firstrow = first row holds the column names.
	import excel "$imk/VIMK`yr' - 01 - tabel utama.xlsx", firstrow clear
	// "capture tostring" turns pmid into a string (ignored if it already is one);
	// pmid is a code/UUID, so it is text, not a number.
	capture tostring pmid, replace                 // pmid = code/UUID -> string
	// A "tempfile" is a scratch dataset at a temporary path, reused below.
	tempfile utama
	save `utama'

	* --- (2) raw materials (long) -> summarize per firm ---
	import excel "$imk/VIMK`yr' - 02 - bahan baku.xlsx", firstrow clear
	capture tostring pmid, replace
	// "destring ... force" converts text to numbers (non-numeric -> missing).
	capture destring nilai, replace force
	// "collapse" aggregates to one row per firm (by pmid): the SUM of nilai, and
	// the COUNT of nilai rows = how many raw-material items that firm reported.
	collapse (sum) bb_nilai_total=nilai (count) bb_n_item=nilai, by(pmid)
	label var bb_nilai_total "Total raw-material value (file 02)"
	label var bb_n_item      "Number of raw-material types"
	tempfile bb
	save `bb'

	* --- (3) commodities (long) -> summarize per firm ---
	import excel "$imk/VIMK`yr' - 03 - komoditas.xlsx", firstrow clear
	capture tostring pmid, replace
	capture destring nilai, replace force
	// Same idea: total product value, and the count of products per firm.
	collapse (sum) kom_nilai_total=nilai (count) kom_n_produk=nilai, by(pmid)
	label var kom_nilai_total "Total commodity/product value (file 03)"
	label var kom_n_produk    "Number of product types"
	tempfile kom
	save `kom'

	* --- merge the summaries onto the main table (1:1 by pmid) ---
	use `utama', clear
	// "merge 1:1 pmid" joins firm-to-firm on pmid. keep(master match) keeps the
	// main-table firms whether or not they had a 02/03 row; nogen drops _merge.
	merge 1:1 pmid using `bb',  keep(master match) nogen
	merge 1:1 pmid using `kom', keep(master match) nogen
	gen int year = `yr'

	// Put key identifiers first; "compress" shrinks the file to the smallest types.
	order pmid year prov kab kbli2 kbli5
	compress
	save "$imk/vimk`yr'.dta", replace
	display as result "== saved: $imk/vimk`yr'.dta =="
	count
}
