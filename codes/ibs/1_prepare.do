* ==============================================================================
* 1_prepare.do -- SECTION 1: build the firm-year panel (ONE file, all years)
* ------------------------------------------------------------------------------
* WHAT THIS DOES
*   Reads each yearly IBS microdata file, renames its columns to the SAME simple
*   names every year, stacks all years on top of each other, and saves one tidy
*   panel: data/firm_panel.dta, with columns
*       fid  idscheme  year  isic2  isic5  output  iinput  va  emp  export  labcost
*   IBS column names are regular ("base name + 2-digit year", e.g. Output10,
*   Output11), so a single loop can clean 2010-2022.
*
* DATA SOURCE
*   This file ALWAYS cleans the yearly files in data/raw/mfgYYYY.dta (the real data).
*   It then checks whether the firm id can actually link firms across years and SAYS so:
*     - id valid  -> link_ok = 1, every section (incl. 2c/2d/2e) can run;
*     - id masked -> link_ok = 0, the link-based sections (2c/2d/2e) are skipped.
*   There is NO automatic switch to synthetic/test data: whatever you put in data/raw is
*   exactly what gets analysed, so you always know which data you are looking at.
*
* STATA WORDS USED BELOW (plain-English):
*   local / global = a named value ( `name' = temporary ; $name = project-wide )
*   foreach / forvalues = repeat a block once per item / number
*   capture = "try this; if it errors, carry on" (the error code lands in _rc)
*   tempfile = a scratch dataset that is deleted when the run ends
*   destring = turn text that holds numbers into real numbers
*   append = stack another dataset underneath the one in memory
* ==============================================================================

	clear all                // start from an empty, clean memory
	set more off             // no "-more-" pauses
	set varabbrev off        // exact variable names only (so "drop output"
	                         // cannot accidentally match "output10")

* --- (0) Folders & defaults (only needed if this file is run on its own) --------
*   If $root is empty, nobody set the paths yet, so fill in sensible defaults.
	if "$root" == "" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
		global raw  "$root/data/raw"
		global data "$root/data"
	}
	global link_ok 0                          // set to 1 later if the firm id can link firms across years

* ==============================================================================
* Clean each year in data/raw and append them into one firm-year panel
* ==============================================================================

	* start an empty scratch dataset that we will grow year by year
	tempfile panel
	clear
	save `panel', emptyok replace          // emptyok = allowed to save with no data yet

	* loop over every year from 2010 to 2022 (forvalues = count through numbers)
	forvalues yr = 2010/2022 {

		* skip years with no raw file (e.g. 2016). "confirm file" errors if missing.
		capture confirm file "$raw/mfg`yr'.dta"
		if _rc continue                     // _rc != 0 -> file missing -> next year

		display "Cleaning year `yr' ..."
		use "$raw/mfg`yr'.dta", clear
		local yy = `yr' - 2000               // 2010 -> 10, 2011 -> 11, etc. (the name suffix)

		* (a) make every variable name lower-case (skip ones Stata reserves)
		foreach v of varlist * {
			local low = strlower("`v'")      // lower-cased version of the name
			capture rename `v' `low'         // capture: some reserved names can't be renamed
		}

		* (b) drop any raw column already named like our targets (prevents rename clashes)
		foreach x in output iinput va emp export isic5 labcost year {
			capture drop `x'
		}

		* (c) firm id + which id scheme the year uses (Kipb / KIP 2015 / Psid 2017).
		*     Check each candidate in turn; the first one found wins.
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
		* rename whichever id column exists to the single name "fid"
		capture rename kipb fid
		capture rename kip  fid
		capture rename psid fid
		capture confirm variable fid
		if _rc gen str8 fid = ""             // if no id column at all, make an empty one
		capture tostring fid, replace force  // make fid text, so all years match type
		gen idscheme = "`scheme'"            // record which scheme this year used

		* (d) core variables: try the year-suffixed name first, then the plain name
		*     (2015 stores some columns without the year suffix).
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

		* (e) labour cost = production wages + non-production wages (only 2010-2018).
		*     Keep the two raw wage components too (w_prod, w_nonprod).
		capture rename zpsvcu`yy'  w_prod
		capture rename zpsvcu      w_prod
		capture rename znsvcu`yy'  w_nonprod
		capture rename znsvcu      w_nonprod
		capture gen double labcost = w_prod + w_nonprod

		* (f) force the money/count columns to numeric (some years store them as text),
		*     then derive year and the 2-digit industry code.
		foreach x in output iinput va emp export isic5 w_prod w_nonprod {
			capture destring `x', replace force
		}
		gen int year  = `yr'
		gen int isic2 = floor(isic5/1000)    // ISIC 5-digit -> 2-digit (drop last 3 digits)

		* fill any target that was never created, so the "keep" below cannot error
		foreach x in output iinput va emp export isic5 labcost w_prod w_nonprod {
			capture confirm variable `x'
			if _rc gen double `x' = .
		}

		* (g) keep only the columns we need; restrict to manufacturing (ISIC 10-33)
		keep  fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod
		order fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod
		keep if isic2 >= 10 & isic2 <= 33

		* (h) stack this year's rows underneath the years done so far
		append using `panel'
		save `panel', replace
	}

	* bring the full stacked panel into memory and save it
	use `panel', clear
	save "$data/firm_panel.dta", replace

	* --- detect: is the firm id actually usable for linking firms over time? ---
	*   If almost every year has only ONE distinct fid value (a masked "***"),
	*   then we cannot follow a firm from one year to the next.
	preserve                                 // remember current data; "restore" brings it back
		keep year fid
		duplicates drop                      // one row per (year, fid)
		bysort year: gen long nfid = _N      // nfid = how many distinct fids that year has
		by year: keep if _n == 1             // one summary row per year
		count if nfid <= 1                   // count years with a masked (single-value) id
		local nmasked = r(N)
		count                                // total number of years
		local nyears  = r(N)
	restore

	* if at most half the years are masked, treat the id as good for linkage
	if `nmasked' <= `nyears'/2 {
		global link_ok 1
		display as result "   firm id VALID (not masked) -> all sections can run on this data."
	}
	else {
		global link_ok 0
		display as error  "   NOTE: the firm id is MASKED in this data."
		display as error  "   -> link-based sections 2c/2d/2e will be SKIPPED (nothing is faked)."
	}

* --- [DEFLATOR] (optional, turned off) -----------------------------------------
*   If you have a sector-year price index (data/deflator.dta: isic2 year defl),
*   you could divide the nominal values by it here to get real values:
*     use "$data/firm_panel.dta", clear
*     merge m:1 isic2 year using "$data/deflator.dta", keep(1 3) nogen
*     replace output = output/defl
*     replace va     = va/defl
*     save "$data/firm_panel.dta", replace

* --- Labels & final save -------------------------------------------------------
*   Attach human-readable labels, shrink the file (compress), and save.
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
	compress                                 // use the smallest storage type per variable
	save "$data/firm_panel.dta", replace

	* also save an Excel copy of the processed dataset (into output/ if we have it)
	if "$output" != "" local xdir "$output"
	else               local xdir "$data"
	export excel using "`xdir'/firm_panel.xlsx", replace firstrow(variables)

	display as result "== saved: $data/firm_panel.dta  +  `xdir'/firm_panel.xlsx (link_ok=$link_ok) =="
	tab year                                 // quick count of rows per year
