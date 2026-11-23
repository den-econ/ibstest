* ==============================================================================
* gen_ibs_psid.do -- build a SYNTHETIC IBS panel that can still merge to real 2005
* ------------------------------------------------------------------------------
* WHY THIS EXISTS:
*   The IBS sample files carry economic values but no firm id that links a firm
*   across years. To test the panel machinery we fabricate a linkable id called
*   "psid". The trick: we borrow REAL firm ids (nkip05) from the real 2005 file
*   (ibs/indus05.dta) and staple them onto random sample rows. Because the id
*   values are genuine, this synthetic panel still merges correctly against the
*   real 2005 data (synthetic, but mergeable).
*
*   Economic values : come from the SAMPLE (mfgYYYY).
*   psid            : a real nkip05 value (string); firms enter/exit over time.
*   Result          : data/panel_ibs_sintesis/mfgYYYY.dta (raw columns + psid).
*
* CAUTION: the firm TRAJECTORIES here are random, so panel RESULTS on this file
*   are illustrative only. On the real data (where psid is the true id) they
*   become meaningful with no code change.
* HOW TO RUN:  do "code/gen_ibs_psid.do"
* ==============================================================================

	// Start clean and keep output flowing without pauses.
	clear all
	set more off
	// "set varabbrev off" = require full variable names (no risky abbreviations).
	set varabbrev off
	// "set seed" fixes the random-number stream so every run gives the SAME result.
	set seed 12345                              // makes the result reproducible

	// A "local macro" is a temporary named value that exists only while this
	// do-file runs; we write it as `NFIRM'. Here it is the number of synthetic firms.
	local NFIRM = 100                           // number of synthetic firms

* --- folder locations (change if you are on a different computer) --------------
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"
	global src  "$root/data/raw_ibs_sampel"     // sample data (economic values)
	global asli "$root/data/ibs"                // real data (id source + merge target)
	global out  "$root/data/panel_ibs_sintesis"   // output folder
	// "capture mkdir" tries to make the folder; "capture" ignores the error if
	// the folder already exists.
	capture mkdir "$out"

* --- (1) Take `NFIRM' real firm ids (nkip05) from the 2005 data ---------------
	use "$asli/indus05.dta", clear
	keep nkip05
	// "duplicates drop" keeps one row per distinct id.
	duplicates drop
	// runiform() draws a random number in [0,1); sorting on it = a random shuffle.
	gen double r = runiform()
	sort r
	// Keep only the first NFIRM rows after the shuffle = a random sample of ids.
	keep if _n <= `NFIRM'
	gen psid = nkip05                           // psid = the real 2005 id (string)
	keep psid

	// Give each firm an entry year and an exit year so the panel is UNBALANCED
	// (firms appear/disappear), which is what real data looks like.
	gen double u = runiform()
	gen double w = runiform()
	gen entry = 2006                            // baseline firms exist from 2006 (earliest year)
	gen exit  = 2022
	replace entry = 2012 + floor(w*4) if u > 0.60 & u <= 0.80   // ~20% enter late
	replace exit  = 2017 + floor(w*4) if u > 0.80 & u <= 0.95   // ~15% exit early
	replace entry = 2013 if u > 0.95                            // ~5% short-lived
	replace exit  = 2019 if u > 0.95
	// A "tempfile" is a scratch dataset saved to a temporary path; we reuse it below.
	tempfile roster
	save `roster'

* --- (2) For each year: staple psid onto random sample rows -------------------
	// "foreach y of local years" repeats the block once per year in the list.
	// 2006-2009 have NO real sample file, so they are FABRICATED by cloning 2010 (see the
	// loop below). They are listed LAST on purpose: adding them does not shift the random
	// draws for 2010-2022, so those years stay byte-for-byte identical.
	local years "2010 2011 2012 2013 2014 2015 2017 2018 2019 2020 2021 2022 2006 2007 2008 2009"
	foreach y of local years {

		// Firms present this year -> shuffle them -> number them 1,2,3,...
		use `roster', clear
		keep if entry <= `y' & exit >= `y'
		gen double pr = runiform()
		sort pr
		gen long rowid = _n                     // row number after shuffling
		keep psid rowid
		count                                   // store the row count in r(N)
		local nfirm = r(N)                      // how many firms are present this year
		tempfile pres
		save `pres'

		// Pick the economic source: the real sample file if it exists; otherwise
		// (2006-2009 have none) CLONE the 2010 sample as a stand-in -- TEST DATA ONLY.
		local srcfile "$src/mfg`y'.dta"
		local cloned  0
		capture confirm file "`srcfile'"
		if _rc {
			local srcfile "$src/mfg2010.dta"
			local cloned  1
		}
		use "`srcfile'", clear
		if `cloned' {
			// This year has no real sample -> fabricate it from the 2010 template.
			// (a) retag the year-suffixed column names (10 -> this year's suffix) so
			//     1_prepare can find them for year `y'. yy = `y'-2000 (e.g. 2006 -> 6).
			local yy = `y' - 2000
			foreach stub in Output Iinput Vtlvcu Ltlnou Ekspor Disic5 Zpsvcu Znsvcu {
				capture rename `stub'10 `stub'`yy'
			}
			// (b) jitter the MONEY columns +/-10% so the clone is not identical to 2010;
			//     leave workers (Ltlnou) and industry (Disic5) alone to keep sizes/sectors.
			foreach v in Output`yy' Iinput`yy' Vtlvcu`yy' Ekspor`yy' Zpsvcu`yy' Znsvcu`yy' {
				capture replace `v' = round(`v' * (0.9 + 0.2*runiform()))
			}
		}

		// Take that many random rows from the sample, and number them the same way.
		gen double pr = runiform()
		sort pr
		gen long rowid = _n
		keep if rowid <= `nfirm'

		// "merge 1:1 rowid" joins the two datasets row-number to row-number, which
		// is how each sample row gets exactly one psid. keep(match) keeps only the
		// matched rows; nogen drops the automatic _merge flag.
		merge 1:1 rowid using `pres', keep(match) nogen
		drop rowid pr
		order psid                              // put psid as the first column

		save "$out/mfg`y'.dta", replace
		display "   -> mfg`y'.dta : `nfirm' firm"
	}

* --- (3) Stack all years into one file (full raw: union of all columns) --------
	clear
	tempfile allibs
	// "emptyok" lets us save an empty dataset to start the stack.
	save `allibs', emptyok replace
	foreach y of local years {
		use "$out/mfg`y'.dta", clear
		capture drop year
		gen int year = `y'                      // tag the year
		// "append ... force" stacks rows on top of the running file even when the
		// column types differ between years.
		append using `allibs', force
		save `allibs', replace
	}
	use `allibs', clear
	order psid year
	save "$out/ibs_panel_2010_2022.dta", replace
	display "   -> ibs_panel_2010_2022.dta (all years stacked, full raw)"

* --- (4) Add the REAL 2005 records as year=2005 (append) ----------------------
*   Pull the 2005 rows for our panel firms (via psid=nkip05), tag them year=2005,
*   and append. So 2005 = REAL data, 2010-2022 = synthetic.
	use "$asli/indus05.dta", clear
	rename nkip05 psid                          // match the id name used in the panel
	merge 1:1 psid using `roster', keep(match) nogen   // only our panel firms
	gen int year = 2005
	tempfile real2005
	save `real2005'

	use "$out/ibs_panel_2010_2022.dta", clear
	append using `real2005', force             // 2005 (real) + 2010-2022 (synthetic)
	// Keep ONLY firms that appear in BOTH eras (a 2005 record AND a synthetic year).
	// "bysort psid: egen ... = max(condition)" makes a 0/1 flag per firm.
	bysort psid: egen byte m_2005 = max(year==2005)
	bysort psid: egen byte m_syn  = max(year>=2010)
	keep if m_2005==1 & m_syn==1
	drop m_2005 m_syn
	order psid year
	save "$out/ibs_panel_2010_2022.dta", replace
	display _n "   -> ibs_panel_2010_2022.dta : 2005 (real)+2010-2022 (synthetic), matched firms only"
	tab year
	// Note: the per-year files mfgYYYY.dta are kept (not deleted).
