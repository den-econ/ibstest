* ==============================================================================
* 1_prepare.do -- SECTION 1: build the firm-year panel (ONE file, all years)
* ------------------------------------------------------------------------------
* WHAT THIS DOES
*   Reads each yearly IBS microdata file and HARMONISES it: it lower-cases the
*   names, strips the trailing year from every name (so Output10 / OUTPUT15 /
*   Output22 all become "output"), then stacks all years into one tidy panel,
*   data/firm_panel.dta. It KEEPS EVERY VARIABLE in the sample data -- not only
*   the ones the scarring analysis needs -- so this repo can serve as a GENERAL
*   engine for any study. A handful of analysis variables also get friendly,
*   stable names on top: fid idscheme year isic2 isic5 output iinput va emp
*   export labcost (plus w_prod, w_nonprod). IBS names are regular ("base name +
*   2-digit year"), so one loop cleans every year 2010-2022.
*
*   Note on the harmoniser: it removes the LAST two digits of a name only when
*   they equal that year (e.g. "...22"). A rare survey code that happens to end
*   in the year digits may be trimmed too; such codes are auxiliary, and the key
*   analysis columns are renamed explicitly below, so results are unaffected.
*
* DATA SOURCE
*   This file cleans the yearly files in data/raw/mfgYYYY.dta. It is written for the
*   REAL IBS microdata, whose firm id is genuine, so the link-based sections
*   (2c/2d/2e) always run. There is NO automatic switch to any synthetic/test data:
*   whatever you put in data/raw is exactly what gets analysed.
*   (The sample files shipped with this repo are only a study case for building these
*   do-files; their id is masked, so mobility / entry-exit on the sample are not
*   meaningful -- but on the real data they are.)
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

	* year range to read (normally set by MASTER.do; sensible defaults if run alone)
	if "$year_start" == "" global year_start 2010
	if "$year_end"   == "" global year_end   2022

* ==============================================================================
* Clean each year in data/raw and append them into one firm-year panel
* ==============================================================================

	* start an empty scratch dataset that we will grow year by year
	tempfile panel
	clear
	save `panel', emptyok replace          // emptyok = allowed to save with no data yet

	* loop over every year in the chosen range (forvalues = count through numbers)
	forvalues yr = $year_start/$year_end {

		* skip years with no raw file (e.g. 2016). "confirm file" errors if missing.
		capture confirm file "$raw/mfg`yr'.dta"
		if _rc continue                     // _rc != 0 -> file missing -> next year

		display "Cleaning year `yr' ..."
		use "$raw/mfg`yr'.dta", clear
		local yy = substr("`=`yr''", 3, 2)   // last 2 digits of the year: 2010 -> "10", 2006 -> "06"

		* (a) make every variable name lower-case, so names match across years
		foreach v of varlist * {
			local low = strlower("`v'")      // lower-cased version of the name
			capture rename `v' `low'         // capture: some reserved names can't be renamed
		}

		* (a2) drop any raw column already named EXACTLY like one of our target names,
		*      so the locking renames below can place the correct source column. Some
		*      years ship a near-empty stray (e.g. a column literally named "Export")
		*      next to the real one ("Ekspor14"); without this it would win the name.
		foreach x in fid idscheme output iinput va emp export isic5 labcost w_prod w_nonprod year isic2 {
			capture drop `x'
		}

		* (b) LOCK the analysis columns FIRST, by their known raw names. We take the
		*     year-suffixed name when it exists (e.g. ekspor`yy'), otherwise the plain
		*     name (2015 stores some without a suffix). Doing this BEFORE the general
		*     harmoniser matters: if a year happens to carry BOTH ekspor`yy' and a
		*     stray plain "ekspor", we still pick the right (suffixed) one here.
		*     (b1) firm id + which id scheme the year uses (Kipb / KIP 2015 / Psid 2017)
		local scheme ""
		foreach cand in kipb kip psid {
			if "`scheme'" == "" {
				capture confirm variable `cand'
				if !_rc local scheme "`cand'"
			}
		}
		capture rename kipb fid              // keep the id under one name: fid
		capture rename kip  fid
		capture rename psid fid
		*     (b2) the money / count / code columns the analysis uses
		capture rename output`yy'  output
		capture rename output      output
		capture rename iinput`yy'  iinput
		capture rename iinput      iinput
		capture rename vtlvcu`yy'  va        // value added
		capture rename vtlvcu      va
		capture rename ltlnou`yy'  emp       // number of workers
		capture rename ltlnou      emp
		capture rename ekspor`yy'  export    // exports
		capture rename ekspor      export
		capture rename disic5`yy'  isic5     // 5-digit industry code
		capture rename disic5      isic5
		capture rename zpsvcu`yy'  w_prod    // wages, production workers
		capture rename zpsvcu      w_prod
		capture rename znsvcu`yy'  w_nonprod // wages, non-production workers
		capture rename znsvcu      w_nonprod
		capture gen double labcost = w_prod + w_nonprod   // labour cost (2010-2018 only)

		* (c) HARMONISER: strip the trailing year from every REMAINING name that
		*     carries it, so each EXTRA variable (survey questions, ownership, ...)
		*     becomes one tidy column per concept across years. The analysis columns
		*     were already renamed in (b), so they are untouched here. This is what
		*     lets us KEEP ALL variables, not only the ones the scarring study needs.
		foreach v of varlist * {
			* long enough, and the last two characters equal this year's digits?
			if length("`v'") > 2 & substr("`v'", -2, 2) == "`yy'" {
				local base = substr("`v'", 1, length("`v'") - 2)   // name minus the suffix
				capture rename `v' `base'                          // skip quietly if it clashes
			}
		}

		* (d) the raw file may carry its own "year"/"isic2"; we rebuild authoritative
		*     ones below, so remove the raw copies first to avoid a name clash.
		capture drop year
		capture drop isic2

		* (e) turn any text-that-is-really-numbers into real numbers. Genuine text
		*     (names, addresses) is left untouched, but the numeric columns now
		*     share one type across years, so they stack without conflict.
		foreach v of varlist * {
			capture destring `v', replace    // no "force" here: never damages real text
		}

		* (f) finish the firm id: make an empty one if the year had none, store it as
		*     text so every year matches type, and record the scheme for link checks.
		capture confirm variable fid
		if _rc gen str8 fid = ""
		capture tostring fid, replace force
		gen idscheme = "`scheme'"

		* (f2) force the analysis money/count columns to numeric. Step (e) numified
		*      the clean ones; this also rescues any that hold a stray non-numeric
		*      character (e.g. exports in a few years), so every lens -- and any
		*      export-based study -- reads REAL numbers, not text that sums to zero.
		foreach x in output iinput va emp export isic5 w_prod w_nonprod {
			capture destring `x', replace force
		}

		* (g) authoritative year, and the 2-digit industry code from isic5.
		gen int year = `yr'
		capture confirm variable isic5
		if !_rc gen int isic2 = floor(isic5/1000)   // 5-digit -> 2-digit (drop last 3)
		else    gen int isic2 = .                   // no industry code this year

		* (h) make sure the analysis targets always exist, so later code never errors
		*     on a year that happens to lack one of them.
		foreach x in output iinput va emp export isic5 labcost w_prod w_nonprod {
			capture confirm variable `x'
			if _rc gen double `x' = .
		}

		* (i) restrict to manufacturing (ISIC 10-33). This repo is a general engine,
		*     so run  "global keep_mfg 0"  beforehand to keep EVERY sector instead.
		if "$keep_mfg" == "" global keep_mfg 1       // default: manufacturing only
		if $keep_mfg == 1 keep if isic2 >= 10 & isic2 <= 33

		* (j) put the key columns first; EVERY other raw column is kept after them,
		*     so any study can use any variable that exists in the sample data.
		order fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod

		* (k) stack this year's rows underneath the years done so far. "force" lets
		*     the stack go through even if a rare extra column changed type between
		*     years (the key analysis columns are consistent, so they are unaffected).
		append using `panel', force
		save `panel', replace
	}

	* bring the full stacked panel into memory and save it
	use `panel', clear
	save "$data/firm_panel.dta", replace

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

	display as result "== saved: $data/firm_panel.dta  +  `xdir'/firm_panel.xlsx =="
	tab year                                 // quick count of rows per year

* --- (SANITY CHECK) shout if a source variable NAME did not match --------------
*   Every rename above used "capture", so a column whose raw name differs on the
*   REAL data is NOT an error -- it is just left empty (all missing). On the sample
*   all names match, but a new vintage of the real data might name a column
*   differently. This block re-reads the panel and prints a LOUD warning naming any
*   core column that came out empty, so a name mismatch is caught at once instead of
*   silently producing blank results. It changes nothing when every name matches.
	use "$data/firm_panel.dta", clear
	display as text "{hline 72}"
	display as text "SANITY CHECK (variable names) -- read this before trusting any result"
	display as text "{hline 72}"

	local problems = 0

	* (1) the panel must not be empty. If it is, the industry-code column (disic5)
	*     probably had a different name -> isic2 was missing -> every row filtered out.
	quietly count
	if r(N) == 0 {
		display as error "!! the panel has 0 rows."
		display as error "   The industry-code column may not be named 'disic5' in your data,"
		display as error "   so isic2 was missing and all rows were dropped by the ISIC 10-33 filter."
		display as error "   -> check the industry-code variable name in the real microdata."
		local problems = `problems' + 1
	}
	else {
		* (2) core columns that SHOULD have values in EVERY manufacturing year.
		*     For each year, if a core column is entirely missing, its raw name likely
		*     differs in that year's file -> warn and name the column + year.
		*     (labcost / wages are NOT here: they are known to be absent after 2018.)
		local core "output va emp isic5"
		levelsof year, local(yrs)
		foreach y of local yrs {
			foreach c of local core {
				quietly count if year == `y' & !missing(`c')
				if r(N) == 0 {
					display as error "!! '`c'' is EMPTY for year `y' -> its source name may differ in that file."
					local problems = `problems' + 1
				}
			}
			* firm id: an all-blank fid means none of kipb/kip/psid was found that year.
			quietly count if year == `y' & fid != ""
			if r(N) == 0 {
				display as error "!! firm id is EMPTY for year `y' -> no kipb/kip/psid column found."
				local problems = `problems' + 1
			}
		}
	}

	* (3) pass quietly, or STOP the WHOLE run so a manual run cannot miss the problem.
	if `problems' == 0 {
		display as result "SANITY CHECK ok: id + all core variables present for every year."
		display as text "{hline 72}"
	}
	else {
		display as error "{hline 72}"
		display as error "STOP: SANITY CHECK found `problems' problem(s) listed above."
		display as error "A source variable NAME probably differs from the sample data."
		display as error "Fix the rename list in step (b) of 1_prepare.do, then run again."
		display as error "(The run is halted here ON PURPOSE so no lens analyses blank data.)"
		display as error "{hline 72}"
		exit 459          // non-zero code = error -> also stops MASTER.do if it called us
	}
