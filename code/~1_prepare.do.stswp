* ==============================================================================
* 1_prepare.do  -- SECTION 1: build the firm-year panel (ONE file, all years)
* ------------------------------------------------------------------------------
* IBS variable names are regular ("base name + year", e.g. Output10, Output11),
* so one loop cleans 2010-2022. Output: data/firm_panel.dta
*   fid  idscheme  year  isic2  isic5  output  iinput  va  emp  export  labcost
*
* DATA SOURCE ($source): "raw" = clean data/raw/mfgYYYY.dta ; "panel" = use the
* ready synthetic panel data/ibs_panel_2010_2022.csv ; "auto" = try raw, and if
* the firm id is masked (like the sample) fall back to the synthetic panel.
* Note: "capture" = try a command; if it errors, just ignore it.
* ==============================================================================

	clear all
	set more off
	set varabbrev off        // exact variable names only (so "drop output"
	                         // cannot accidentally match "output10")

* --- (0) Folders & defaults (edit $root; skipped if run from MASTER.do) --------
	if "$root" == "" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
		global raw  "$root/data/raw"
		global data "$root/data"
	}
	if "$source" == "" global source "auto"
	global link_ok 0                        // 1 if firm id is usable for linkage

* ==============================================================================
* (A) RAW PATH: clean each year and append into one panel
* ==============================================================================
if inlist("$source", "raw", "auto") {

	tempfile panel
	clear
	save `panel', emptyok replace

	forvalues yr = 2010/2022 {

		* skip years with no raw file (e.g. 2016)
		capture confirm file "$raw/mfg`yr'.dta"
		if _rc continue

		display "Cleaning year `yr' ..."
		use "$raw/mfg`yr'.dta", clear
		local yy = `yr' - 2000               // 2010 -> 10, etc.

		* (a) lowercase all names (skip reserved words like "Long")
		foreach v of varlist * {
			local low = strlower("`v'")
			capture rename `v' `low'
		}

		* (b) drop raw vars named like our targets (avoids rename clashes)
		foreach x in output iinput va emp export isic5 labcost year {
			capture drop `x'
		}

		* (c) firm id + scheme (Kipb / KIP 2015 / Psid 2017)
		local scheme ""
		capture confirm variable kipb
		if !_rc local scheme "kipb"
		if "`scheme'" == "" {
			capture confirm variable kip
			if !_rc local scheme "kip"
		}
		if "`scheme'" == "" {
			capture confirm variable psid
			if !_rc local scheme "psid"
		}
		capture rename kipb fid
		capture rename kip  fid
		capture rename psid fid
		capture confirm variable fid
		if _rc gen str8 fid = ""
		capture tostring fid, replace force
		gen idscheme = "`scheme'"

		* (d) core variables: try suffixed name, then plain (2015 has some plain)
		capture rename output`yy'  output
		capture rename output      output
		capture rename iinput`yy'  iinput
		capture rename iinput      iinput
		capture rename vtlvcu`yy'  va
		capture rename vtlvcu      va
		capture rename ltlnou`yy'  emp
		capture rename ltlnou      emp
		capture rename ekspor`yy'  export
		capture rename ekspor      export
		capture rename disic5`yy'  isic5
		capture rename disic5      isic5

		* (e) labour cost = production + non-production wages (only 2010-2018).
		*     We KEEP the two raw wage components too (w_prod, w_nonprod).
		capture rename zpsvcu`yy'  w_prod
		capture rename zpsvcu      w_prod
		capture rename znsvcu`yy'  w_nonprod
		capture rename znsvcu      w_nonprod
		capture gen double labcost = w_prod + w_nonprod

		* (f) force numbers to numeric (some years store them as text), derive
		foreach x in output iinput va emp export isic5 w_prod w_nonprod {
			capture destring `x', replace force
		}
		gen int year  = `yr'
		gen int isic2 = floor(isic5/1000)    // ISIC 5-digit -> 2-digit

		* fill any target that wasn't created, so "keep" won't error
		foreach x in output iinput va emp export isic5 labcost w_prod w_nonprod {
			capture confirm variable `x'
			if _rc gen double `x' = .
		}

		* (g) keep needed vars; restrict to manufacturing (ISIC 10-33)
		keep  fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod
		order fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod
		keep if isic2 >= 10 & isic2 <= 33

		* (h) append to previous years
		append using `panel'
		save `panel', replace
	}

	use `panel', clear
	save "$data/firm_panel.dta", replace

	* --- detect: is the firm id usable for linkage? ---------------------------
	*   If most years have only 1 distinct fid value (masked "***"), linkage
	*   is impossible.
	preserve
		keep year fid
		duplicates drop
		bysort year: gen long nfid = _N
		by year: keep if _n == 1
		count if nfid <= 1
		local nmasked = r(N)
		count
		local nyears  = r(N)
	restore

	if `nmasked' <= `nyears'/2 {
		global link_ok 1
		display as result "   firm id valid -> all sections can run from raw"
	}
	else {
		display as text "   NOTE: firm id is masked in this data."
		if "$source" == "auto" {
			display as result "   -> falling back to the synthetic panel for testing."
			global source "panel"
		}
		else {
			display as error  "   -> sections 2c/2d/2e (need linkage) will be skipped."
		}
	}
}

* ==============================================================================
* (B) PANEL PATH: ready-made synthetic panel (valid firm ids)
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
	gen str8 idscheme = "panel"              // continuous id -> linkage valid

	foreach v in output iinput va emp export isic5 isic2 labcost w_prod w_nonprod year {
		capture confirm variable `v'
		if _rc gen double `v' = .
	}
	keep  fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod
	order fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod
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
	label var w_prod    "Raw wages, production workers"
	label var w_nonprod "Raw wages, non-production workers"
	compress
	save "$data/firm_panel.dta", replace

	* also save an Excel copy of the processed dataset (into output/ if available)
	if "$output" != "" local xdir "$output"
	else               local xdir "$data"
	export excel using "`xdir'/firm_panel.xlsx", replace firstrow(variables)

	display as result "== saved: $data/firm_panel.dta  +  `xdir'/firm_panel.xlsx (link_ok=$link_ok) =="
	tab year
