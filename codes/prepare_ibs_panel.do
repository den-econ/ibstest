* ==============================================================================
* prepare_ibs_panel.do -- STANDALONE engine: build the IBS firm-year panel
* ------------------------------------------------------------------------------
* WHAT THIS FILE IS
*   ONE self-contained do-file that turns the raw IBS yearly files into a single
*   tidy panel, data/firm_panel.dta, that ANY study can then use. It does not need
*   a separate MASTER or SET_FILEPATHS: you set the folders in the CONFIG block
*   right below, then run this one file. The panel is the reusable OUTPUT; each
*   analysis project (e.g. scarring-industry) just reads data/firm_panel.dta.
*
* WHAT IT DOES, IN ORDER
*   (0) convert_first == 1 : import each mfgYYYY.xlsx and save it as mfgYYYY.dta
*                            (IBS arrives as Excel). A year with no .xlsx is skipped.
*   (1) harmonise          : lower-case names, strip the trailing year from every
*                            name (Output10 / OUTPUT15 / Output22 -> "output"),
*                            lock a handful of analysis columns to stable names,
*                            KEEP EVERY variable, then stack all years.
*   (2) sanity check       : LOUD stop if a core column came out empty (a raw name
*                            differs from what the rename list expects).
*
* HOW TO RUN
*   1. Edit the CONFIG block below (at least $root) for THIS machine.
*   2. Put the raw files in  data/raw/  as mfgYYYY.xlsx (or mfgYYYY.dta).
*   3. Open Stata and run:  do "codes/prepare_ibs_panel.do"
*
* STATA WORDS USED BELOW (plain-English):
*   global = a project-wide named value, written $name
*   local  = a temporary named value, written `name'
*   capture = "try this; if it errors, carry on" (the error code lands in _rc)
*   forvalues / foreach = repeat a block once per number / item
* ==============================================================================

	capture log close        // close any log left open by a previous run
	clear all                // start from an empty, clean memory
	set more off             // no "-more-" pauses
	set varabbrev off        // exact variable names only (so "drop output"
	                         // cannot accidentally match "output10")

* ===================================================================== *
* >>>>>>>>>>>>>>>>>>>>>>>>>>>   CONFIG   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *
* ===================================================================== *
*   This is the ONLY block you edit when you move machines or change years.

	*** (1) Project root = the ibstest folder on THIS computer.
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"

	*** (2) Year range to read (2016 has no file; the loop skips missing years).
		global year_start   2010
		global year_end     2022

	*** (3) Manufacturing only? 1 = keep ISIC 10-33 ; 0 = keep every sector.
		global keep_mfg     1

	*** (4) Convert Excel -> .dta first? IBS arrives as mfgYYYY.xlsx, so default 1.
	***     Set 0 only if the raw files are already mfgYYYY.dta. (On the sample,
	***     which is .dta only, this step simply finds no .xlsx and skips -- harmless.)
		global convert_first 1

	*** (5) WHERE the raw yearly files live -- this is the "directory" you change.
	***     DEFAULT = REAL data: put the real mfgYYYY.xlsx (or .dta) in data/raw.
	***     (To TEST on the provided sample -- same format -- point this at
	***      "$root/data/raw_ibs_sampel" instead.)
		global raw "$root/data/raw"

* ===================================================================== *
* -----------------   Folders (made if missing)   -------------------- *
* ===================================================================== *
*   Defined here so this file never depends on SET_FILEPATHS. The folders match
*   the standard project layout; "capture mkdir" makes each one if it is missing
*   ("capture" ignores the harmless "already exists" error).
	global code "$root/codes"           // where the do-files live
	global data "$root/data"            // project data folder
	global out  "$root/data/raw"        // SAVE the built panel HERE: inside raw/ -> gitignored,
	                                    //   so the panel never leaves via git and stays with the data
	global fig  "$root/fig"             // figures (unused here; kept for a common layout)
	global reg  "$root/reg"             // tables  (unused here; kept for a common layout)
	capture mkdir "$data"
	capture mkdir "$out"                // make the panel-output folder (data/raw) if missing
	capture mkdir "$raw"                // $raw was chosen in CONFIG item (5) above
	capture mkdir "$fig"
	capture mkdir "$reg"

*   Open a run log -- a SAVED .log file (not a folder). One file per run: the name
*   carries the date and time so runs do not overwrite each other.
	local _d = subinstr("`c(current_date)'", " ", "_", .)   // e.g. 23_Nov_2026
	local _t = subinstr("`c(current_time)'", ":", "",  .)    // e.g. 143205
	log using "$root/prepare_ibs_panel_`_d'_`_t'.log", replace text

* ===================================================================== *
* -----------   (0) Convert Excel -> .dta (if asked)   --------------- *
* ===================================================================== *
*   import each mfgYYYY.xlsx and save it as the mfgYYYY.dta that Section 1 reads.
*   A year with no .xlsx is simply skipped, so .dta-only years are left untouched.
	if $convert_first == 1 {
		display as text "== IBS 0: convert Excel -> .dta (only where an .xlsx exists) =="
		forvalues yr = $year_start/$year_end {
			capture confirm file "$raw/mfg`yr'.xlsx"
			if _rc {
				display as text "   (skip `yr': no mfg`yr'.xlsx)"
				continue                 // jump to the next year
			}
			display "   converting mfg`yr'.xlsx -> mfg`yr'.dta ..."
			* firstrow = the first spreadsheet row holds the column names.
			import excel "$raw/mfg`yr'.xlsx", firstrow clear
			save "$raw/mfg`yr'.dta", replace
		}
		display as result "== IBS convert done: .dta files are in $raw =="
	}

* ===================================================================== *
* -----------   (1) Harmonise each year and append   ---------------- *
* ===================================================================== *
*   Reads each mfgYYYY.dta, harmonises the names, and stacks all years into one
*   panel. It KEEPS EVERY VARIABLE (general engine), and also gives a few analysis
*   columns friendly, stable names: fid idscheme year isic2 isic5 output iinput
*   va emp export labcost (plus w_prod, w_nonprod).

	* start an empty scratch dataset that we will grow year by year
	tempfile panel
	clear
	save `panel', emptyok replace          // emptyok = allowed to save with no data yet

	* loop over every year in the chosen range
	forvalues yr = $year_start/$year_end {

		* skip years with no raw file (e.g. 2016). "confirm file" errors if missing.
		capture confirm file "$raw/mfg`yr'.dta"
		if _rc continue                     // _rc != 0 -> file missing -> next year

		display "Cleaning year `yr' ..."
		use "$raw/mfg`yr'.dta", clear
		local yy = substr("`=`yr''", 3, 2)   // last 2 digits of the year: 2010 -> "10"

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
		*     harmoniser matters: if a year carries BOTH ekspor`yy' and a stray plain
		*     "ekspor", we still pick the right (suffixed) one here.
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

		* (i) restrict to manufacturing (ISIC 10-33) unless keep_mfg == 0.
		if $keep_mfg == 1 keep if isic2 >= 10 & isic2 <= 33

		* (j) put the key columns first; EVERY other raw column is kept after them,
		*     so any study can use any variable that exists in the data.
		order fid idscheme year isic2 isic5 output iinput va emp export labcost w_prod w_nonprod

		* (k) stack this year's rows underneath the years done so far. "force" lets
		*     the stack go through even if a rare extra column changed type between
		*     years (the key analysis columns are consistent, so they are unaffected).
		append using `panel', force
		save `panel', replace
	}

	* bring the full stacked panel into memory and save it
	use `panel', clear
	save "$out/firm_panel.dta", replace

* --- [DEFLATOR] (optional, turned off) -----------------------------------------
*   If you have a sector-year price index (data/deflator.dta: isic2 year defl),
*   you could divide the nominal values by it here to get real values:
*     use "$out/firm_panel.dta", clear
*     merge m:1 isic2 year using "$data/deflator.dta", keep(1 3) nogen
*     replace output = output/defl
*     replace va     = va/defl
*     save "$out/firm_panel.dta", replace

* --- Labels & final save -------------------------------------------------------
*   Attach human-readable labels, shrink the file (compress), and save.
	use "$out/firm_panel.dta", clear
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
	save "$out/firm_panel.dta", replace

	* also save an Excel copy of the processed dataset (next to the panel)
	export excel using "$out/firm_panel.xlsx", replace firstrow(variables)

	display as result "== saved: $out/firm_panel.dta  +  $out/firm_panel.xlsx =="
	tab year                                 // quick count of rows per year

* ===================================================================== *
* -----------   (2) SANITY CHECK: shout on a name mismatch   --------- *
* ===================================================================== *
*   Every rename above used "capture", so a column whose raw name differs on the
*   REAL data is NOT an error -- it is just left empty (all missing). This block
*   re-reads the panel and prints a LOUD warning naming any core column that came
*   out empty, so a name mismatch is caught at once instead of silently producing
*   blank results. It changes nothing when every name matches.
	use "$out/firm_panel.dta", clear
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
		capture log close
	}
	else {
		display as error "{hline 72}"
		display as error "STOP: SANITY CHECK found `problems' problem(s) listed above."
		display as error "A source variable NAME probably differs from the real data."
		display as error "Fix the rename list in step (b) above, then run again."
		display as error "(The run is halted here ON PURPOSE so no study analyses blank data.)"
		display as error "{hline 72}"
		capture log close
		exit 459          // non-zero code = error -> stops any caller too
	}
