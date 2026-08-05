* ==============================================================================
* 1_prepare.do   -- SECTION 1: build the panel
* ------------------------------------------------------------------------------
* Builds the firm-year panel: data/firm_panel.dta
*
* DATA SOURCE ($source in MASTER.do):
*   "raw"   -> raw microdata data/raw/mfgYYYY.dta
*   "panel" -> use the ready-made synthetic panel data/ibs_panel_2010_2022.csv
*              (for TESTING on the sample; has valid firm ids)
*   "auto"  -> try "raw"; if firm id is masked (like this sample),
*              fall back to "panel" automatically. <-- default, plug-and-play.
*
* RAW VARIABLE-NAME PROBLEM: names change every year (year suffix, capitals,
*   different firm-id scheme). We keep only the core variables, standardise the
*   names, and stack (append) the years.
*
* "real" NOTE: values are nominal. For a real (deflated) version, deflate by
*   sector-year (see the [DEFLATOR] marker below).
* ==============================================================================

	display as text "== 01_prepare: source = $source =="
	global link_ok 0                      // 1 if firm id can be used for linkage

* ==============================================================================
* (1) RAW PATH: harmonise data/raw/mfgYYYY.dta
* ==============================================================================
if inlist("$source", "raw", "auto") {

	tempfile panel
	clear
	save `panel', emptyok replace

	forvalues y = $year_start/$year_end {

		local yy   = `y' - 2000                 // 2010 -> 10
		local file "$raw/mfg`y'.dta"

		capture confirm file "`file'"
		if _rc {
			display as text "   (skip) missing: mfg`y'.dta"
			continue
		}
		display as text "   processing mfg`y'.dta ..."
		use "`file'", clear

		* lowercase all names (per-variable + capture so a raw name that becomes
		* a reserved word when lowered, e.g. "Long", is simply skipped)
		foreach v of varlist * {
			local lc = strlower("`v'")
			if "`lc'" != "`v'" capture rename `v' `lc'
		}

		* --- (a) firm identifier: prefer the Kipb scheme ----------------------
		local scheme ""
		foreach c in kipb kip psid number {
			if "`scheme'" == "" {
				capture confirm variable `c'
				if !_rc local scheme "`c'"
			}
		}
		if "`scheme'" == "" {
			display as error "   !! no firm id recognised in `y' - skipped"
			continue
		}
		rename `scheme' fid
		capture tostring fid, replace force
		gen str8 idscheme = "`scheme'"

		* --- (b) core variables -> temporary "_"-prefixed names ---------------
		*   the "_" prefix avoids clashing with a raw variable of the same name
		*   (e.g. "Year", "Export"). Try the year-suffixed name first, then plain.
		capture rename output`yy'  _output
		capture rename output      _output
		capture rename iinput`yy'  _iinput
		capture rename iinput      _iinput
		capture rename vtlvcu`yy'  _va
		capture rename vtlvcu      _va
		capture rename ltlnou`yy'  _emp
		capture rename ltlnou      _emp
		capture rename ekspor`yy'  _export
		capture rename ekspor      _export
		capture rename disic5`yy'  _isic5
		capture rename disic5      _isic5

		* --- (c) labour-cost components (only some years) ---------------------
		capture rename zpsvcu`yy'  _wp
		capture rename zpsvcu      _wp
		capture rename znsvcu`yy'  _wn
		capture rename znsvcu      _wn

		* --- (d) drop raw vars named like the targets, then standardise -------
		foreach v in output iinput va emp export isic5 labcost year {
			capture drop `v'
		}
		foreach v in output iinput va emp export isic5 {
			capture confirm variable _`v'
			if _rc gen double _`v' = .          // this year lacks it -> missing
			rename _`v' `v'
		}
		capture gen double labcost = _wp + _wn
		capture confirm variable labcost
		if _rc gen double labcost = .
		capture drop _wp _wn

		* --- (e) types & derived variables ------------------------------------
		foreach v in output iinput va emp export isic5 {
			capture confirm numeric variable `v'
			if _rc capture destring `v', replace force
		}
		gen int year  = `y'
		gen int isic2 = floor(isic5/1000)       // 5-digit -> 2-digit

		* --- (f) keep what we need; restrict to manufacturing (ISIC 10-33) ----
		keep  fid idscheme year isic2 isic5 output iinput va emp export labcost
		order fid idscheme year isic2 isic5 output iinput va emp export labcost
		keep if isic2 >= 10 & isic2 <= 33

		append using `panel'
		save `panel', replace
	}

	use `panel', clear
	save "$data/firm_panel.dta", replace

	* --- detect: can the firm id be used for linkage? ---------------------------
	*   If most years have only 1 distinct fid value (masked "***"),
	*   then linkage is impossible.
	preserve
		keep year fid
		duplicates drop
		bysort year: gen long nfid = _N        // number of distinct fids per year
		by year: keep if _n == 1
		count if nfid <= 1
		local nmasked = r(N)
		count
		local nyears  = r(N)
	restore

	if `nmasked' <= `nyears'/2 {
		global link_ok 1
		display as result "   firm id valid -> all lenses can run from raw"
	}
	else {
		display as text "   NOTE: firm id is masked in this data."
		if "$source" == "auto" {
			display as result "   -> falling back to the synthetic panel for testing."
			global source "panel"
		}
		else {
			display as error  "   -> lenses 4/5/6 (need linkage) will be skipped."
		}
	}
}

* ==============================================================================
* (2) PANEL PATH: ready-made synthetic panel (valid firm ids)
* ==============================================================================
if "$source" == "panel" {

	local pfile "$data/ibs_panel_2010_2022.csv"
	capture confirm file "`pfile'"
	if _rc {
		display as error "!! synthetic panel not found: `pfile'"
		exit 601
	}
	display as text "   loading synthetic panel: ibs_panel_2010_2022.csv"

	import delimited "`pfile'", clear case(lower)
	capture rename ekspor export
	gen str8 idscheme = "panel"                // continuous id -> linkage valid

	foreach v in output iinput va emp export isic5 isic2 labcost year {
		capture confirm variable `v'
		if _rc gen double `v' = .
	}
	keep  fid idscheme year isic2 isic5 output iinput va emp export labcost
	order fid idscheme year isic2 isic5 output iinput va emp export labcost
	keep if isic2 >= 10 & isic2 <= 33

	save "$data/firm_panel.dta", replace
	global link_ok 1
}

* --- [DEFLATOR] (optional) -----------------------------------------------------
*   If you have a sector-year price index (data/deflator.dta: isic2 year defl):
*     use "$data/firm_panel.dta", clear
*     merge m:1 isic2 year using "$data/deflator.dta", keep(1 3) nogen
*     replace output = output/defl
*     replace va     = va/defl
*     save "$data/firm_panel.dta", replace

* --- Labels & final save -------------------------------------------------------
	use "$data/firm_panel.dta", clear
	label var fid      "Firm identifier"
	label var idscheme "Id scheme (link validity)"
	label var year     "Year"
	label var isic2    "ISIC 2-digit"
	label var output   "Output (nominal)"
	label var va       "Value added (nominal)"
	label var emp      "Number of workers"
	label var export   "Exports (nominal)"
	label var labcost  "Labour cost (nominal)"
	compress
	save "$data/firm_panel.dta", replace

	display as result "== panel saved: $data/firm_panel.dta (link_ok=$link_ok) =="
	tab year
