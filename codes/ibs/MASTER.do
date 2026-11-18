* ==============================================================================
* Project        : Scarring Effect Manufacturing Industry in COVID-19 Period
* Stata version  : 19
* ------------------------------------------------------------------------------
* WHAT THIS FILE IS
*   The "control panel" for the whole IBS pipeline. It sets the options, then
*   calls each step (1_prepare, 2a ... 2e) in order. You normally run ONLY this
*   file; it runs everything else for you.
*
* HOW TO RUN
*   1. Put the raw microdata in  data/raw/  (the IBS data to be used).
*   2. Open Stata IN this repo folder (or cd into it).
*   3. Run:  do "code/MASTER.do"
*
* TIME-SAVING TIP
*   Section 1 (cleaning + panel) only needs to run once; it saves
*   data/firm_panel.dta. After that, set its trigger to 0 and switch on only the
*   Section 2 step you want to re-run -- each step reads the saved panel and is
*   self-contained.
* ==============================================================================

	capture log close        // close any log left open from a previous run (ignore error if none)
	clear all                // wipe data/programs from memory for a clean start
	set more off             // do not pause output with "-more-" prompts
	set varabbrev off        // IMPORTANT: require exact variable names, so e.g.
	                         // "drop output" cannot accidentally match "output10"

* ===================================================================== *
* -------------------           Path               -------------------- *
* ===================================================================== *
*   Set the project root ($root) for THIS machine, then load SET_FILEPATHS.do
*   from it. We set $root explicitly instead of trusting Stata's working folder.

	* if this is the known machine, use its full repo path
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	* fallback for any other machine: use the current working folder, c(pwd)
	if "$root" == "" global root "`c(pwd)'"

	* load all folder definitions ($code, $data, $raw, $output, $code_scar, ...)
	* SET_FILEPATHS.do is a SHARED file at the root of codes/ (not in ibs/ or imk/).
	do "$root/codes/SET_FILEPATHS.do"

* ===================================================================== *
* -------------------           Setup              -------------------- *
* ===================================================================== *
*   These globals are the knobs for the analysis. Every step below reads them.

	*** Data source: always the real microdata in data/raw/mfgYYYY.dta.
	*   1_prepare.do then checks whether the firm id can link firms across years and
	*   reports it (link_ok). It never silently swaps in any synthetic/test data, so you
	*   always know whether you are looking at the real data or a masked file.

	*** (1) Data range (2016 has no raw file; the loop skips it automatically)
		global year_start   2010
		global year_end     2022

	*** (2) Two periods (data is 2010-2022): pre-crisis 2010-2019, crisis 2020-2022
		global crisis_year  2020        // COVID-19; year >= this = crisis period
		global base_year    2019        // index base = 100 (last pre-crisis year)

	*** (3) Firm size-class thresholds (number of workers) - AHN definition
		global small_max    99          // Small : 20-99
		global medium_max   499         // Medium: 100-499  (Large: 500+)

	*** (4) Year pairs (start -> end of each period) for the size transition matrix (2c)
		global pre_y0       2010        // pre-crisis: start -> end
		global pre_y1       2019
		global crisis_y0    2020        // crisis:     start -> end
		global crisis_y1    2022

* ===================================================================== *
* -----------------            Triggers             ----------------- *
* ===================================================================== *
*   On/off switches: 1 = run this step, 0 = skip it. (These are "locals":
*   temporary names, written `name', that live only while this file runs.)

	*** Section 1 - build the panel (run once, then may be turned off)
		local s1_prepare            1   // clean all years + append -> data/firm_panel.dta

	*** Section 2 - cleaning & analysis
		local s2a_growth            1   // 2a: output/value-added growth
		local s2b_jobless           1   // 2b: labour productivity & jobless growth
		local s2c_mobility          1   // 2c: mobility across size classes
		local s2d_entry_exit        1   // 2d: entry/exit rate
		local s2e_decomp            1   // 2e: employment-growth decomposition

	*** Extra - also save result tables as Excel (.xlsx)
		local s2_excel              1   // also write result tables as .xlsx

	*** Extra - Sankey of the size-class transitions (real firm flows)
		local s2_sankey             1   // draw Sankey from 2c_transition_*.csv

* ===================================================================== *
* -----------------            Do-files             ----------------- *
* ===================================================================== *

	display c(current_time)          // print the clock time this run started
	timer clear 1                    // reset stopwatch #1
	timer on 1                       // start timing the whole run

	* run each step only if its trigger above is 1
	if `s1_prepare' == 1 {
		do "$code/ibs/1_prepare.do"
	}
	* NOTE: the analysis do-files live in the SIBLING project scarring_industry/,
	* under codes/ibs/, so they are called with $code_scar/ibs/ (not $code).
	if `s2a_growth' == 1 {
		do "$code_scar/ibs/2a_growth.do"
	}
	if `s2b_jobless' == 1 {
		do "$code_scar/ibs/2b_jobless_growth.do"
	}
	if `s2c_mobility' == 1 {
		do "$code_scar/ibs/2c_size_mobility.do"
	}
	if `s2d_entry_exit' == 1 {
		do "$code_scar/ibs/2d_entry_exit.do"
	}
	if `s2e_decomp' == 1 {
		do "$code_scar/ibs/2e_decomposition.do"
	}

	*** Save every result table (the output CSVs) also as Excel.
	*   "foreach t in ..." loops once per table name, putting it in the local `t'.
	if `s2_excel' == 1 {
		foreach t in 2a_growth_by_period 2a_growth_by_sector 2a_va_by_year ///
		             2b_index 2b_summary 2b_ulc ///
		             2c_transition_pre 2c_transition_crisis ///
		             2d_entry_exit 2e_decomp {
			capture confirm file "$output/`t'.csv"   // does this CSV exist?
			if !_rc {                                // _rc == 0 means yes
				import delimited "$output/`t'.csv", clear varnames(1) case(preserve)
				export excel using "$output/`t'.xlsx", replace firstrow(variables)
			}
		}
	}

	*** Sankey of the 2c size-class transitions (uses output/2c_transition_*.csv).
	*   render_sankey.do reads $sankey_dir, so point it at the IBS output folder.
	if `s2_sankey' {
		global sankey_dir "$output"
		do "$code_scar/render_sankey.do"
	}

	timer off 1                      // stop the stopwatch
	timer list 1                     // print how long the run took
	display "Done. Results saved to: $output"
