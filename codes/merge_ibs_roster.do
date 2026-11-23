* ==============================================================================
* merge_ibs_roster.do -- attach firm-level variables to the IBS rosters
* ------------------------------------------------------------------------------
* WHAT THIS FILE IS
*   An EXTRA step on top of the three engines. It reads their outputs and writes
*   two NEW files; nothing that already exists is changed.
*
*     reads   data/raw/firm_panel.dta        (prepare_ibs_panel.do)
*             data/raw/ibs_input_long.dta    (prepare_ibs_roster.do)
*             data/raw/ibs_output_long.dta   (prepare_ibs_roster.do)
*     writes  data/raw/ibs_input_firm.dta    one row = firm x year x raw material
*             data/raw/ibs_output_firm.dta   one row = firm x year x product
*
*   Each output is a roster table plus the firm variables listed in CONFIG,
*   linked m:1 on fid + year. Inputs and products stay in SEPARATE files: the
*   survey does not say which raw material goes into which product, so putting
*   them on one row would mean an arbitrary input x product cross.
*
* READ THIS BEFORE USING THE OUTPUT
*   Firm variables carry the prefix f_ (f_output, f_emp, ...). They are the SAME
*   number on every row of a firm-year. Never sum an f_ variable across rows.
*
* HOW TO RUN
*   1. Run prepare_ibs_panel.do and prepare_ibs_roster.do first.
*   2. Edit the CONFIG block below (at least $root).
*   3. Open Stata and run:  do "codes/merge_ibs_roster.do"
* ==============================================================================

	capture log close
	clear all
	set more off
	set varabbrev off

* ===================================================================== *
* >>>>>>>>>>>>>>>>>>>>>>>>>>>   CONFIG   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *
* ===================================================================== *

	*** (1) Project root = the ibstest folder on THIS computer.
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"

	*** (2) Firm variables to bring over from firm_panel.dta (names as they are in
	***     the panel). Edit freely. A name that is not in the panel is left out
	***     with a note in the log; it does not stop the run.
		global firm_keep                                                       ///
			isic2 isic5                                                        ///
			output iinput va emp export                                        ///
			output_real_umum iinput_real_umum va_real_umum export_real_umum    ///
			output_real_sekt iinput_real_sekt va_real_sekt export_real_sekt    ///
			dprovi dkabup dkecam ddesa

* ===================================================================== *
* -----------------   Files and run log   ----------------------------- *
* ===================================================================== *
	global out        "$root/data/raw"
	global panel_file "$out/firm_panel.dta"

	local _d = subinstr("`c(current_date)'", " ", "_", .)
	local _t = subinstr("`c(current_time)'", ":", "",  .)
	log using "$root/merge_ibs_roster_`_d'_`_t'.log", replace text

	foreach f in "$panel_file" "$out/ibs_input_long.dta" "$out/ibs_output_long.dta" {
		capture confirm file "`f'"
		if _rc {
			display as error "STOP: file not found: `f'"
			display as error "Run prepare_ibs_panel.do and prepare_ibs_roster.do first."
			capture log close
			exit 601
		}
	}

* ===================================================================== *
* -----------   (1) Firm side: one row per fid + year   -------------- *
* ===================================================================== *
*   Only the years covered by the rosters are used, so an id problem in some
*   other year of the panel cannot block this merge.

	local ymin = .
	local ymax = .
	foreach kind in input output {
		use year using "$out/ibs_`kind'_long.dta", clear
		quietly summarize year
		local ymin = min(`ymin', r(min))
		local ymax = max(`ymax', r(max))
	}

	use "$panel_file", clear
	keep if inrange(year, `ymin', `ymax')

	local have ""
	local miss ""
	foreach v of global firm_keep {
		if inlist("`v'", "fid", "year") continue
		capture confirm variable `v'
		if _rc local miss `miss' `v'
		else   local have `have' `v'
	}
	if "`miss'" != "" display as error "!! not in the firm panel, left out: `miss'"
	keep fid year `have'

	bysort fid year: gen long _copies = _N
	quietly count if _copies > 1
	if r(N) > 0 {
		display as error "STOP: fid + year is NOT unique in the firm panel for `ymin'-`ymax'"
		display as error "      (" r(N) " rows share a key). An m:1 merge is impossible on this data."
		display as error "      On the sample this is expected: the firm id is masked."
		capture log close
		exit 459
	}
	drop _copies

	foreach v of local have {
		rename `v' f_`v'
	}
	tempfile firm
	save `firm'

* ===================================================================== *
* -----------   (2) Attach to each roster and save   ---------------- *
* ===================================================================== *
*   Every roster row is kept. in_panel = 0 marks rows whose firm-year is not
*   in the firm panel (their f_ variables are missing). Firm-years with no
*   roster rows are not here; they remain in firm_panel.dta.
*
*   Added per row, from the roster values only:
*     n_items        number of roster rows of the firm-year
*     v_firm_roster  the firm-year's roster total (v_total for inputs, v for products)
*     item_share     the row's share of that total
*     main_item      1 for the row with the largest value in the firm-year
*     imp_share      inputs only: imported share of the row's value

	foreach kind in input output {

		use "$out/ibs_`kind'_long.dta", clear
		if "`kind'" == "input"  local val "v_total"
		if "`kind'" == "output" local val "v"

		merge m:1 fid year using `firm', keep(master match)
		gen byte in_panel = (_merge == 3)
		drop _merge

		bysort fid year: gen long n_items = _N
		by fid year: egen double v_firm_roster = total(`val')
		gen double item_share = `val' / v_firm_roster if v_firm_roster > 0 & `val' < .
		gen double _neg = -`val'
		bysort fid year (_neg line): gen byte main_item = (_n == 1 & `val' < .)
		drop _neg
		if "`kind'" == "input" {
			gen double imp_share = cond(missing(v_imp), 0, v_imp) / v_total if v_total > 0 & v_total < .
			label var imp_share "Imported share of the row's value"
		}

		label var in_panel      "1 = firm-year found in firm_panel"
		label var n_items       "Roster rows in the firm-year"
		label var v_firm_roster "Firm-year roster total of `val'"
		label var item_share    "Row's share of the firm-year roster total"
		label var main_item     "1 = largest-value row of the firm-year"

		order fid year line in_panel
		sort fid year line
		compress
		save "$out/ibs_`kind'_firm.dta", replace
		display as result "== saved: $out/ibs_`kind'_firm.dta =="
		tab year in_panel
	}

	display as text "{hline 72}"
	display as text "Firm variables attached (prefix f_): `have'"
	display as text "They repeat on every row of a firm-year: never sum them across rows."
	display as text "{hline 72}"
	capture log close
