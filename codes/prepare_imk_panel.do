* ==============================================================================
* prepare_imk_panel.do -- STANDALONE engine: build the IMK firm-level panel
* ------------------------------------------------------------------------------
* WHAT THIS FILE IS
*   ONE self-contained do-file that turns the raw IMK (VIMK) yearly files into a
*   single tidy firm-level dataset, data/imk_firm.dta, that any study can use. It
*   does not need a separate MASTER or SET_FILEPATHS: set the folders in the
*   CONFIG block below, then run this one file.
*
*   IMK renames its columns EVERY year, so the same quantity hides behind a
*   different code each year. The COLUMN MAP in Section 1 copies each year's
*   columns onto four tidy variables (emp, output, wage, input) plus the industry
*   code and some groupings, so the rest of any pipeline never sees the yearly
*   code names.
*
* WHAT IT DOES, IN ORDER
*   (0) convert_first == 1 : import the VIMK Excel files and save them as VIMK{YY}.dta.
*                            DEFAULT is 0 because IMK arrives already as .dta.
*   (1) harmonise          : apply the COLUMN MAP per year, build emp/output/wage/
*                            input + kbli2 + size class + sector groups, stack.
*
* ##############################################################################
* #  PLUG-AND-PLAY: the ONLY thing to edit for real data is the CONFIG block    #
* #  below and the COLUMN MAP in Section 1 (one line per year). If BPS keeps     #
* #  the same column names, nothing in the COLUMN MAP changes.                   #
* ##############################################################################
*
* HOW TO RUN
*   1. Edit the CONFIG block (at least $root) for THIS machine.
*   2. Put the raw files in  data/raw_imk/  as VIMK{YY}.dta
*      (or the VIMK{YY}-Tahunan.xlsx files, and set convert_first = 1).
*   3. Open Stata and run:  do "codes/prepare_imk_panel.do"
* ==============================================================================

	capture log close        // close any log left open by a previous run
	clear all                // start from an empty, clean memory
	set more off             // no "-more-" pauses
	set varabbrev off        // exact variable names only (safer)

* ===================================================================== *
* >>>>>>>>>>>>>>>>>>>>>>>>>>>   CONFIG   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *
* ===================================================================== *
*   This is the ONLY block you edit when you move machines.

	*** (1) Project root = the ibstest folder on THIS computer.
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"

	*** (2) BPS worker-count size split: Micro = 1..imk_micro_max, Small = next..19.
		global imk_micro_max 4

	*** (3) Convert Excel -> .dta first? IMK arrives already as .dta, so default 0.
	***     Set 1 only if the raw IMK files are still VIMK{YY}-Tahunan.xlsx.
		global convert_first 0

* ===================================================================== *
* -----------------   Folders (made if missing)   -------------------- *
* ===================================================================== *
*   Defined here so this file never depends on SET_FILEPATHS. "capture mkdir"
*   makes each folder if it is missing ("capture" ignores "already exists").
	global code    "$root/codes"           // where the do-files live
	global data    "$root/data"            // where imk_firm.dta is saved
	global raw_imk "$root/data/raw_imk"    // raw VIMK files: holds the SAMPLE now; drop the REAL VIMK{YY}.dta here for real data
	global fig     "$root/fig"             // figures (unused here; kept for a common layout)
	global reg     "$root/reg"             // tables  (unused here; kept for a common layout)
	capture mkdir "$data"
	capture mkdir "$raw_imk"
	capture mkdir "$fig"
	capture mkdir "$reg"

*   Open a run log -- a SAVED .log file (not a folder), one per run (date + time).
	local _d = subinstr("`c(current_date)'", " ", "_", .)
	local _t = subinstr("`c(current_time)'", ":", "",  .)
	log using "$root/prepare_imk_panel_`_d'_`_t'.log", replace text

* ===================================================================== *
* -----------   (0) Convert Excel -> .dta (if asked)   --------------- *
* ===================================================================== *
*   Only runs when convert_first == 1. Most years are one firm-level spreadsheet;
*   2024 and 2025 are split across extra "detail" sheets that we first add up to
*   one row per firm (matched on pmid) before attaching them.
	if $convert_first == 1 {

		* --- single-file years: just import and save ---
		foreach y in 17 18 19 20 21 22 23 {
			display "== VIMK20`y' (single file) =="
			capture confirm file "$raw_imk/VIMK`y'-Tahunan.xlsx"
			if _rc {
				display as text "   (skip 20`y': VIMK`y'-Tahunan.xlsx not found)"
				continue
			}
			import excel "$raw_imk/VIMK`y'-Tahunan.xlsx", firstrow clear
			save "$raw_imk/VIMK`y'.dta", replace
			display "   -> VIMK`y'.dta : `=_N' firms, " c(k) " columns"
		}

		* --- 2024 = main table + Blok6 (raw-material detail, many rows per firm) ---
		display "== VIMK2024 (main + Blok6) =="
		capture confirm file "$raw_imk/VIMK24-Tahunan.xlsx"
		if _rc {
			display as text "   (skip 2024: VIMK24-Tahunan.xlsx not found)"
		}
		else {
			local has_bb6 = 0
			capture confirm file "$raw_imk/VIMK24-Tahunan-Blok6.xlsx"
			if !_rc {
				import excel "$raw_imk/VIMK24-Tahunan-Blok6.xlsx", firstrow clear
				capture destring nilai, replace force
				collapse (sum) bb_nilai = nilai (count) bb_n_item = nilai, by(pmid)
				label var bb_nilai  "Total raw-material value (Blok6, sum)"
				label var bb_n_item "Number of raw-material items (Blok6)"
				tempfile bb24
				save `bb24'
				local has_bb6 = 1
			}
			else display as text "   (2024: Blok6 detail not found -> main table only)"

			import excel "$raw_imk/VIMK24-Tahunan.xlsx", firstrow clear
			if `has_bb6' {
				merge 1:1 pmid using `bb24', keep(master match) nogen
				replace bb_nilai  = 0 if missing(bb_nilai)
				replace bb_n_item = 0 if missing(bb_n_item)
			}
			save "$raw_imk/VIMK24.dta", replace
			display "   -> VIMK24.dta : `=_N' firms, " c(k) " columns"
		}

		* --- 2025 = main table + data5 (products) + data6 (raw materials) ---
		display "== VIMK2025 (main + data5 + data6) =="
		capture confirm file "$raw_imk/VIMK25-Tahunan.xlsx"
		if _rc {
			display as text "   (skip 2025: VIMK25-Tahunan.xlsx not found)"
		}
		else {
			local has_d5 = 0
			capture confirm file "$raw_imk/VIMK25-Tahunan-data5.xlsx"
			if !_rc {
				import excel "$raw_imk/VIMK25-Tahunan-data5.xlsx", firstrow clear
				capture destring r501k5, replace force
				collapse (sum) prod_nilai = r501k5 (count) prod_n_item = r501k5, by(pmid)
				label var prod_nilai  "Total production value (data5, sum)"
				label var prod_n_item "Number of products (data5)"
				tempfile pr25
				save `pr25'
				local has_d5 = 1
			}
			else display as text "   (2025: data5 not found -> skipped)"

			local has_d6 = 0
			capture confirm file "$raw_imk/VIMK25-Tahunan-data6.xlsx"
			if !_rc {
				import excel "$raw_imk/VIMK25-Tahunan-data6.xlsx", firstrow clear
				capture destring r601k6, replace force
				collapse (sum) bb_nilai = r601k6 (count) bb_n_item = r601k6, by(pmid)
				label var bb_nilai  "Total raw-material value (data6, sum)"
				label var bb_n_item "Number of raw-material items (data6)"
				tempfile bb25
				save `bb25'
				local has_d6 = 1
			}
			else display as text "   (2025: data6 not found -> skipped)"

			import excel "$raw_imk/VIMK25-Tahunan.xlsx", firstrow clear
			if `has_d5' merge 1:1 pmid using `pr25', keep(master match) nogen
			if `has_d6' merge 1:1 pmid using `bb25', keep(master match) nogen
			foreach v in prod_nilai prod_n_item bb_nilai bb_n_item {
				capture confirm variable `v'
				if !_rc replace `v' = 0 if missing(`v')
			}
			save "$raw_imk/VIMK25.dta", replace
			display "   -> VIMK25.dta : `=_N' firms, " c(k) " columns"
		}

		display as result "== IMK convert done: VIMK17.dta ... VIMK25.dta in $raw_imk =="
	}

* ===================================================================== *
* -----------   (1) Harmonise each year and append   ---------------- *
* ===================================================================== *
	display as text "== IMK 1: prepare & harmonize (2017-2025) =="

	* Start an empty "panel" that we add each year's rows to.
	clear
	tempfile panel
	save `panel', emptyok replace

	local years 17 18 19 20 21 22 23 24 25

	* Loop over the years. `y' is the current two-digit year inside the loop.
	foreach y of local years {
		display as text "  -- 20`y' --"

		* Skip a year whose file is not present.
		capture confirm file "$raw_imk/VIMK`y'.dta"
		if _rc {
			display as text "     (skip 20`y': VIMK`y'.dta not found)"
			continue
		}
		use "$raw_imk/VIMK`y'.dta", clear

		* ==================================================================== *
		* >>>>>>>>>>>>>>>>  COLUMN MAP  (edit here for real data)  <<<<<<<<<<<< *
		*   For each year we record which raw column feeds each standard var:   *
		*     kblicol  = the KBLI 5-digit industry code column                  *
		*     empsrc   = worker-count column                                    *
		*     outputsrc= revenue column                                         *
		*     wagesrc  = wage column(s)                                         *
		*     inputsrc = material/fuel column(s)                                *
		*   A source may list SEVERAL columns separated by spaces; those get    *
		*   added together further below.                                       *
		* ==================================================================== *
		if "`y'" == "17" {
			local kblicol b2_2052
			local empsrc  b4_402a_6
			local outputsrc  b6_604_5
			local wagesrc b4_403a_4 b4_403b_4 b4_403c_4
			local inputsrc  b5_501_4 b5_502_4
		}
		else if "`y'" == "18" {
			local kblicol b2_2052
			local empsrc  b4_402a_6
			local outputsrc  b6_604_5
			local wagesrc b4_403d_4
			local inputsrc  b5_501u_5 b5_502a_5
		}
		else if "`y'" == "19" {
			local kblicol b2_2042
			local empsrc  b3_301a_last
			local outputsrc  b5_504_5
			local wagesrc b3_303d_4
			local inputsrc  b4_401u_5 b4_402a_5
		}
		else if "`y'" == "20" {
			local kblicol r204b
			local empsrc  r401aklast
			local outputsrc  r504
			local wagesrc r403dk4
			local inputsrc  r601uk6 r602ak5
		}
		else if "`y'" == "21" {
			local kblicol r204b
			local empsrc  r401aklast
			local outputsrc  r504
			local wagesrc r403dk4
			local inputsrc  r601uk6 r602ak5
		}
		else if "`y'" == "22" {
			local kblicol r204b
			local empsrc  r401aklast
			local outputsrc  r504k6
			local wagesrc r403dk4
			local inputsrc  r601vk6 r602ak5
		}
		else if "`y'" == "23" {
			local kblicol r205
			local empsrc  r401aklast
			local outputsrc  r504k6
			local wagesrc r403dk4
			local inputsrc  r601jk6 r602ak5
		}
		else if "`y'" == "24" {
			local kblicol r205
			local empsrc  r402ak4
			local outputsrc  r503k5
			local wagesrc r403dk2
			local inputsrc  r601nk6
		}
		else if "`y'" == "25" {
			local kblicol r205_label
			local empsrc  r402a
			local outputsrc  r503
			local wagesrc r403d
			local inputsrc  r601_jumlah
		}
		* ==================================================================== *

		* --- Industry code: make kbli5 numeric, then derive the 2-digit kbli2 -
		capture confirm numeric variable `kblicol'
		if _rc destring `kblicol', gen(kbli5) force
		else   gen double kbli5 = `kblicol'
		gen kbli2 = floor(kbli5/1000)              // first two digits of the code
		keep if kbli2 >= 10 & kbli2 <= 33          // keep manufacturing only

		* --- Build the four standard variables, guarding missing columns ------
		foreach t in emp output wage input {
			* NESTED-MACRO TRICK -- do NOT change this line.
			* `t' is the target name, e.g. emp. We want the CONTENTS of the local
			* called `empsrc'. Writing `t'src builds the text "empsrc", and the
			* extra backticks ``...'' then expand THAT local. So `src' ends up
			* holding, for emp, exactly what empsrc holds.
			local src ``t'src'
			local have ""                          // will collect the columns that exist
			foreach c of local src {
				capture confirm variable `c'
				if !_rc {
					capture confirm numeric variable `c'
					if _rc destring `c', replace force
					local have "`have' `c'"
				}
				else display as error "     20`y': source column `c' not found (`t')"
			}
			if "`have'" == "" {
				gen double `t' = .
				display as error "     20`y': NO source for `t' -> set missing"
			}
			else {
				* "egen ... rowtotal" adds the kept columns across each row; "missing"
				* keeps the result missing when ALL inputs are missing (not 0).
				egen double `t' = rowtotal(`have'), missing
			}
		}

		* Wage is genuinely empty for unpaid family firms, so treat blank as 0.
		replace wage = 0 if missing(wage)

		* --- Size class using the BPS worker-count definition -----------------
		gen byte sizeclass = .
		replace sizeclass = 1 if emp >= 1 & emp <= $imk_micro_max        // Micro 1-4
		replace sizeclass = 2 if emp > $imk_micro_max & emp <= 19         // Small 5-19
		label define szc 1 "Micro (1-4)" 2 "Small (5-19)", replace
		label values sizeclass szc

		* --- Broad sector groups (two alternative ways to bucket industries) --
		*   A = end-use buckets (5 groups).
		gen byte secgroupA = .
		replace secgroupA = 1 if inlist(kbli2,10,11,12)
		replace secgroupA = 2 if inlist(kbli2,13,14,15)
		replace secgroupA = 3 if inlist(kbli2,16,17,18,31)
		replace secgroupA = 4 if inlist(kbli2,19,20,21,22,23,24,25) | inlist(kbli2,26,27,28,29,30)
		replace secgroupA = 5 if inlist(kbli2,32,33)

		*   B = factor-intensity buckets (4 groups, Aswicahyono-style).
		gen byte secgroupB = .
		replace secgroupB = 1 if inlist(kbli2,10,11,12,16,17,23,24)
		replace secgroupB = 2 if inlist(kbli2,13,14,15,18,31,32)
		replace secgroupB = 3 if inlist(kbli2,19,20,21,22,25) | inlist(kbli2,28,29,30,33)
		replace secgroupB = 4 if inlist(kbli2,26,27)

		gen int year = 2000 + `y'                  // 17 -> 2017, etc.

		* --- Keep only the harmonized columns (the raw ones stay in VIMK`y'.dta)
		*   Keep pmid too if it exists (so a firm can be identified within a year).
		capture confirm variable pmid
		if !_rc keep pmid year kbli5 kbli2 emp output wage input sizeclass secgroupA secgroupB
		else    keep       year kbli5 kbli2 emp output wage input sizeclass secgroupA secgroupB

		* Stack this year's rows under the years already processed, then save.
		append using `panel'
		save `panel', replace
	}

* --- All years stacked: add labels and save the final firm-level dataset -------
	use `panel', clear
	label var emp    "Total workers (1-19)"
	label var output "Business revenue (Rp)"
	label var wage   "Labour compensation (Rp, 0 if unpaid)"
	label var input  "Material + fuel cost (Rp)"
	label var kbli2  "KBLI 2-digit industry"
	label define secA 1 "Food & bev" 2 "Textiles" 3 "Wood & furniture" ///
	                  4 "Chem/metal/mach" 5 "Other manuf", replace
	label define secB 1 "Resource-based" 2 "Labour-intensive" ///
	                  3 "Capital/footloose" 4 "Electronics", replace
	label values secgroupA secA
	label values secgroupB secB
	label var secgroupA "Sector group A (end-use, 5)"
	label var secgroupB "Sector group B (factor intensity, 4)"
	order year kbli2 kbli5 secgroupA secgroupB emp output wage input sizeclass
	compress                                       // shrink storage types to save space
	save "$data/imk_firm.dta", replace

	display as result "   -> saved: $data/imk_firm.dta"
	tab year                                       // quick check: rows per year
	capture log close
