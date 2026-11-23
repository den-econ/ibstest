* ==============================================================================
* convert_ibs_dta.do -- convert the IBS yearly Excel files into Stata .dta files
* ------------------------------------------------------------------------------
* WHAT THIS FILE DOES (in plain words):
*   If the real IBS microdata arrives as Excel (mfgYYYY.xlsx), this step turns each
*   year's spreadsheet into a Stata file mfgYYYY.dta in the SAME data/raw folder,
*   so 1_prepare.do (which reads .dta) can use it. One row per firm per file.
*
*   It is SAFE to leave this step switched on even when you already have .dta files:
*   a year that has NO .xlsx is simply skipped, so the existing .dta is kept and
*   used as-is. (The sample in this repo ships only .dta, so every year is skipped.)
*
* INPUT  : $raw/mfgYYYY.xlsx   (first row = column names; data on the first sheet)
* OUTPUT : $raw/mfgYYYY.dta
* HOW TO RUN: normally called by MASTER.do (Section 0). Can also be run on its own.
* ==============================================================================

	clear                    // wipe only the DATA (keep path globals if MASTER set them)
	set more off             // never pause for "-more-" prompts
	set varabbrev off        // variable names must be typed in full (safer)

* --- folders & year range (fallbacks only if this file is run on its own) -------
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"       // $root still empty -> use cwd
	if "$raw"  == "" global raw  "$root/data/raw" // where mfgYYYY.xlsx / .dta live
	if "$year_start" == "" global year_start 2010 // same default range as 1_prepare
	if "$year_end"   == "" global year_end   2022

	display as text "== IBS 0: convert Excel -> .dta (only where an .xlsx exists) =="

* --- one year at a time --------------------------------------------------------
	forvalues yr = $year_start/$year_end {

		* skip years that have no Excel file (so .dta-only years are left untouched)
		capture confirm file "$raw/mfg`yr'.xlsx"
		if _rc {
			display as text "   (skip `yr': no mfg`yr'.xlsx)"
			continue                              // jump to the next year
		}

		display "   converting mfg`yr'.xlsx -> mfg`yr'.dta ..."
		* import the FIRST sheet; "firstrow" = the first row holds the column names.
		* (If your file keeps the data on a named sheet, add e.g.  sheet("Sheet1")  .)
		import excel "$raw/mfg`yr'.xlsx", firstrow clear

		* save as the .dta that 1_prepare.do reads (overwrites any old .dta for that year)
		save "$raw/mfg`yr'.dta", replace
	}

	display as result "== IBS convert done: .dta files are in $raw =="
