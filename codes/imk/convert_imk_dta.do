* ==============================================================================
* convert_imk_dta.do -- Convert the IMK (VIMK) Excel files into Stata .dta files
* ------------------------------------------------------------------------------
* WHAT THIS FILE DOES (in plain words):
*   It reads the raw survey spreadsheets (.xlsx) and saves one Stata dataset
*   (.dta) per year, 2017-2025, right next to the Excel files.
*
*   - Most years come as ONE firm-level spreadsheet (one row per firm, where the
*     firm is identified by "pmid"). For those we simply import and save.
*   - Two years are SPLIT across several spreadsheets:
*       2024: VIMK24-Tahunan.xlsx       (main table, one row per firm)
*           + VIMK24-Tahunan-Blok6.xlsx (raw materials, MANY rows per firm)
*       2025: VIMK25-Tahunan.xlsx       (main table, one row per firm)
*           + VIMK25-Tahunan-data5.xlsx (products,      MANY rows per firm)
*           + VIMK25-Tahunan-data6.xlsx (raw materials, MANY rows per firm)
*     The "detail" spreadsheets list one row per item, so to keep ONE row per
*     firm we first add those item rows up to the firm level (a total value and a
*     count of items) and then attach them to the main table, matched on pmid.
*
* INPUT  : data/raw_imk/VIMK*-Tahunan*.xlsx
* OUTPUT : data/raw_imk/VIMK17.dta ... VIMK25.dta
* HOW TO RUN: usually called automatically by imk_MASTER.do (Section 0); can also
*             be run on its own with  do "code/convert_imk_dta.do".
* ==============================================================================

	clear                    // wipe only the DATA in memory. We use "clear" (not
	set more off             // "clear all") on purpose, so that when imk_MASTER.do
	set varabbrev off        // calls this file it does NOT erase the path "globals".
	                         // set more off  = never pause for "-more-" prompts.
	                         // set varabbrev off = variable names must be typed in
	                         //   full (no abbreviations), which prevents mistakes.

* --- Project folder ("global" = a name that stays set for the whole session) ---
*   c(username) is the computer login name. On the author's machine we hard-code
*   the repo path; on any other machine we fall back to the current folder.
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"     // $root still empty -> use cwd
	global imk "$root/data/raw_imk"      // where the VIMK files live

* ==============================================================================
* 1. Single-file years (2017-2023): just import the spreadsheet and save it
* ==============================================================================
*   "foreach" repeats the same block once for each value in the list (here the
*   two-digit year 17, 18, ...). Inside the loop `y' is the current value.
	foreach y in 17 18 19 20 21 22 23 {
		display "== VIMK20`y' (single file) =="

		* "capture" runs a command but swallows any error (so the do-file keeps
		* going). "confirm file" just checks whether a file exists: it leaves the
		* error code _rc = 0 if found, non-zero if missing. So "if _rc" = "if the
		* file was NOT found -> skip this year".
		capture confirm file "$imk/VIMK`y'-Tahunan.xlsx"
		if _rc {
			display as text "   (skip 20`y': VIMK`y'-Tahunan.xlsx not found)"
			continue                 // "continue" = jump to the next year
		}

		* import the spreadsheet (firstrow = the first row holds the column names)
		import excel "$imk/VIMK`y'-Tahunan.xlsx", firstrow clear
		save "$imk/VIMK`y'.dta", replace
		display "   -> VIMK`y'.dta : `=_N' firms, " c(k) " columns"   // _N = #rows, c(k) = #vars
	}

* ==============================================================================
* 2. Year 2024 = main table + Blok6 (raw-material detail, many rows per firm)
* ==============================================================================
	display "== VIMK2024 (main + Blok6) =="
	capture confirm file "$imk/VIMK24-Tahunan.xlsx"
	if _rc {
		display as text "   (skip 2024: VIMK24-Tahunan.xlsx not found)"
	}
	else {
		* (a) The raw-material block is OPTIONAL. has_bb6 is a flag (0/1) that
		*     records whether we found and summarised it.
		local has_bb6 = 0
		capture confirm file "$imk/VIMK24-Tahunan-Blok6.xlsx"
		if !_rc {                                       // !_rc = "file WAS found"
			import excel "$imk/VIMK24-Tahunan-Blok6.xlsx", firstrow clear
			* "destring" turns text into numbers; "force" blanks anything that is
			* not a clean number. Excel often stores values as text.
			capture destring nilai, replace force

			* "collapse" shrinks the data to one row per group. Here the group is
			* the firm (by(pmid)). (sum) adds the item values into bb_nilai, and
			* (count) counts how many item rows the firm had into bb_n_item.
			collapse (sum) bb_nilai = nilai (count) bb_n_item = nilai, by(pmid)
			label var bb_nilai  "Total raw-material value (Blok6, sum)"
			label var bb_n_item "Number of raw-material items (Blok6)"

			* "tempfile" = a scratch file that is deleted automatically at the end.
			* We stash the firm-level summary here to merge in a moment.
			tempfile bb24
			save `bb24'
			local has_bb6 = 1
		}
		else display as text "   (2024: Blok6 detail not found -> main table only)"

		* (b) Load the main firm-level table and attach the block summary.
		import excel "$imk/VIMK24-Tahunan.xlsx", firstrow clear
		if `has_bb6' {
			* "merge 1:1 pmid" joins two datasets row-for-row, matching on pmid
			* (one row per firm on each side). keep(master match) keeps firms from
			* the main table whether or not they had a block row; nogen drops the
			* automatic _merge marker variable.
			merge 1:1 pmid using `bb24', keep(master match) nogen
			replace bb_nilai  = 0 if missing(bb_nilai)   // firm with no material rows -> 0
			replace bb_n_item = 0 if missing(bb_n_item)
		}
		save "$imk/VIMK24.dta", replace
		display "   -> VIMK24.dta : `=_N' firms, " c(k) " columns"
	}

* ==============================================================================
* 3. Year 2025 = main table + data5 (products) + data6 (raw materials)
*    (both detail tables have many rows per firm)
* ==============================================================================
	display "== VIMK2025 (main + data5 + data6) =="
	capture confirm file "$imk/VIMK25-Tahunan.xlsx"
	if _rc {
		display as text "   (skip 2025: VIMK25-Tahunan.xlsx not found)"
	}
	else {
		* (a) OPTIONAL products block -> one summary row per firm
		local has_d5 = 0
		capture confirm file "$imk/VIMK25-Tahunan-data5.xlsx"
		if !_rc {
			import excel "$imk/VIMK25-Tahunan-data5.xlsx", firstrow clear
			capture destring r501k5, replace force
			collapse (sum) prod_nilai = r501k5 (count) prod_n_item = r501k5, by(pmid)
			label var prod_nilai  "Total production value (data5, sum)"
			label var prod_n_item "Number of products (data5)"
			tempfile pr25
			save `pr25'
			local has_d5 = 1
		}
		else display as text "   (2025: data5 not found -> skipped)"

		* (b) OPTIONAL raw-material block -> one summary row per firm
		local has_d6 = 0
		capture confirm file "$imk/VIMK25-Tahunan-data6.xlsx"
		if !_rc {
			import excel "$imk/VIMK25-Tahunan-data6.xlsx", firstrow clear
			capture destring r601k6, replace force
			collapse (sum) bb_nilai = r601k6 (count) bb_n_item = r601k6, by(pmid)
			label var bb_nilai  "Total raw-material value (data6, sum)"
			label var bb_n_item "Number of raw-material items (data6)"
			tempfile bb25
			save `bb25'
			local has_d6 = 1
		}
		else display as text "   (2025: data6 not found -> skipped)"

		* (c) Load the main firm-level table and attach whichever blocks exist.
		import excel "$imk/VIMK25-Tahunan.xlsx", firstrow clear
		if `has_d5' merge 1:1 pmid using `pr25', keep(master match) nogen
		if `has_d6' merge 1:1 pmid using `bb25', keep(master match) nogen

		* For any summary column that got created, turn missing values into 0
		* (a firm with no product/material rows truly has a total of 0).
		foreach v in prod_nilai prod_n_item bb_nilai bb_n_item {
			capture confirm variable `v'
			if !_rc replace `v' = 0 if missing(`v')
		}
		save "$imk/VIMK25.dta", replace
		display "   -> VIMK25.dta : `=_N' firms, " c(k) " columns"
	}

	display "Done. VIMK17.dta ... VIMK25.dta written to data/raw_imk/"
