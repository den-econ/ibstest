* ==============================================================================
* gen_imk_panel.do -- build the IMK sample panel (2017-2025), keeping ALL raw vars
*                     Industry-level panel: the linking key is kbli2 / isic2d.
* ------------------------------------------------------------------------------
* WHAT THIS FILE DOES:
*   Each row = one IMK business (firm). We keep the full raw VIMK structure and
*   just add three helper columns:
*     year   = the survey year
*     kbli2  = KBLI / ISIC Rev.4 2-digit (the ORIGINAL code)
*     isic2d = ISIC Rev.2 2-digit (the MERGE key to the old SI surveys 1975-2005)
*   The KBLI column has a different name every year, so those names are listed by
*   hand below.
*
* INPUT  : data/raw_imk_sampel/VIMK{YY}-Tahunan.xlsx  (one per year)
*          data/ibs/indus{75,85,95,05}.dta            (old SI surveys)
* OUTPUT : data/panel_imk_sintesis/imk20{YY}.dta       (one per year)
*          data/panel_imk_sintesis/imk_panel_2017_2025.dta   (all IMK years)
*          data/panel_imk_sintesis/imk_si_panel_1975_2025.dta (IMK + old SI, matched)
* HOW TO RUN:  do "code/gen_imk_panel.do"
* ==============================================================================

	// Start clean; keep output flowing; require full variable names.
	clear all
	set more off
	set varabbrev off

* --- folder locations ---------------------------------------------------------
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"
	global imk "$root/data/raw_imk_sampel"
	global out "$root/data/panel_imk_sintesis"
	// "capture mkdir" makes the output folder (ignored if it already exists).
	capture mkdir "$out"

* --- list of years + the matching KBLI-5-digit column name for each year -------
	// These two lists line up position-by-position: year 17 uses column b2_2052,
	// year 19 uses b2_2042, and so on. (A "local macro" is a temporary value.)
	local years  "17 18 19 20 21 22 23 24 25"
	local kbcols "b2_2052 b2_2052 b2_2042 r204b r204b r204b r205 r205 r205_label"

	// `: word count `years'' counts how many items are in the list.
	local n : word count `years'
	// "forvalues i = 1/`n'" loops i = 1,2,...,n (once per year).
	forvalues i = 1/`n' {
		// Pick the i-th year and the i-th KBLI column name.
		local y  : word `i' of `years'
		local kb : word `i' of `kbcols'
		display "== IMK 20`y' (kbli column: `kb') =="

		// Read the whole Excel sheet; firstrow = first row holds column names.
		// (ALL original columns are kept.)
		import excel "$imk/VIMK`y'-Tahunan.xlsx", firstrow clear

		// Build kbli5 from the KBLI column (keeping the original column too).
		// If the column is already numeric, copy it; otherwise "destring" converts
		// text to numbers (force = turn anything non-numeric into missing).
		capture confirm numeric variable `kb'
		if _rc  destring `kb', gen(kbli5) force
		else    gen double kbli5 = `kb'

		// kbli2 = first 2 digits of the 5-digit code; keep manufacturing only (10-33).
		gen kbli2 = floor(kbli5/1000)
		keep if kbli2 >= 10 & kbli2 <= 33

		// isic2d = ISIC Rev.2 group (the merge key to the old SI surveys).
		// "inlist(x, a, b, ...)" is true when x equals any of the listed values.
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
		// "label var" sets each column's human-readable description.
		label var kbli2  "KBLI/ISIC Rev.4 2-digit (original code)"
		label var isic2d "ISIC Rev.2 2-digit (merge key to old SI surveys)"
		label var kbli5  "KBLI 5-digit"

		// Put the helper columns first; all original columns stay after them.
		order year kbli2 isic2d kbli5
		capture order pmid, first

		save "$out/imk20`y'.dta", replace
		count                                   // store row count in r(N)
		display "   -> imk20`y'.dta : `r(N)' businesses, " c(k) " columns"
	}

* --- stack all IMK years into one file (union of columns across years) ---------
	clear
	tempfile all
	// "emptyok" allows saving an empty dataset to start the stack.
	save `all', emptyok replace
	foreach y of local years {
		// "append ... force" stacks rows even when the columns differ between years.
		append using "$out/imk20`y'.dta", force   // force: combine despite differing columns
	}
	save "$out/imk_panel_2017_2025.dta", replace

* --- join with the old SI surveys 1975-2005, linked by 2-digit INDUSTRY --------
*   The old SI data uses ISIC Rev.2 (prod5d / isic5); its 2-digit value = isic2d,
*   which matches the IMK isic2d. (Note: different populations - SI = big/medium
*   firms, IMK = micro/small - so the link is at the INDUSTRY level, not firm.
*   indus15 has no industry code, so it is not used here.)
	global asli "$root/data/ibs"
	tempfile base
	use "$out/imk_panel_2017_2025.dta", clear
	save `base', replace
	// Each item below is "year variablename"; we read the two parts with "word".
	foreach spec in "1975 prod5d75" "1985 prod5d85" "1995 prod5d95" "2005 isic5" {
		local yr : word 1 of `spec'
		local pv : word 2 of `spec'
		local yy = substr("`yr'", 3, 2)        // last 2 digits of the year
		use "$asli/indus`yy'.dta", clear
		// Skip this survey if its industry-code column is missing.
		capture confirm variable `pv'
		if _rc {
			display "   (skip `yr': `pv' not present)"
			continue
		}
		capture destring `pv', replace force   // some years store the code as text
		gen isic2d = floor(`pv'/1000)          // ISIC Rev.2 2-digit
		keep if isic2d >= 31 & isic2d <= 39    // manufacturing only
		gen int year = `yr'
		append using `base', force
		save `base', replace
	}
	use `base', clear
	// Keep ONLY industries present in BOTH eras: an SI year (<=2015) AND an IMK
	// year (>=2017). "bysort isic2d: egen ... = max(condition)" makes a 0/1 flag.
	bysort isic2d: egen byte m_si  = max(year <= 2015)
	bysort isic2d: egen byte m_imk = max(year >= 2017)
	keep if m_si==1 & m_imk==1
	drop m_si m_imk
	order year isic2d
	save "$out/imk_si_panel_1975_2025.dta", replace

	display "Done. Files: imk20YY (per-year) + imk_panel_2017_2025 + imk_si_panel_1975_2025 (matched)"
	display "   (the per-year files are kept, not deleted)"
	tab year
