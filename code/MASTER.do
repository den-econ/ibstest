* ==============================================================================
* Project        : Scarring Effect Manufacturing Industry in COVID-19 Period
* Stata version  : 19
* ------------------------------------------------------------------------------
* READ ME !!
*   1. Put the raw microdata in  data/raw/  (the IBS data to be used).
*   2. Open Stata IN this repo folder (or cd into it).
*   3. Run:  do "code/MASTER.do"
*
* Time-saving flow on a limited machine:
*   - Run Section 1 (cleaning + panel) only once (builds & saves data/firm_panel.dta).
*   - Once the panel is saved, turn the Section 1 triggers off (set to 0) and just
*     switch on the Section 2 step you want to re-run. Each step is self-contained.
* ==============================================================================

	capture log close
	clear all
	set more off
	set varabbrev off        // IMPORTANT: exact variable names only, so e.g.
	                         // "drop output" cannot accidentally match "output10"

* ===================================================================== *
* -------------------           Path               -------------------- *
* ===================================================================== *
*   Set the project root for THIS machine (add your username + repo path below),
*   then load SET_FILEPATHS.do from it. Do NOT rely on Stata's working folder.

	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	* fallback if your username isn't listed: use the current working folder
	if "$root" == "" global root "`c(pwd)'"

	do "$root/code/SET_FILEPATHS.do"

* ===================================================================== *
* -------------------           Setup              -------------------- *
* ===================================================================== *

	*** (0) Data source
	*   "auto"  : try raw data in data/raw/; if firm id is masked (like this
	*             sample) fall back to the synthetic panel. <- default.
	*   "raw"   : force from data/raw/mfgYYYY.dta  (used on the REAL data).
	*   "panel" : force from synthetic panel data/ibs_panel_2010_2022.csv (test).
		global source       "auto"

	*** (1) Data range (2016 has no raw file, handled automatically)
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
*   1 = run, 0 = skip.

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

* ===================================================================== *
* -----------------            Do-files             ----------------- *
* ===================================================================== *

	display c(current_time)
	timer clear 1
	timer on 1

	if `s1_prepare' == 1 {
		do "$code/1_prepare.do"
	}
	if `s2a_growth' == 1 {
		do "$code/2a_growth.do"
	}
	if `s2b_jobless' == 1 {
		do "$code/2b_jobless_growth.do"
	}
	if `s2c_mobility' == 1 {
		do "$code/2c_size_mobility.do"
	}
	if `s2d_entry_exit' == 1 {
		do "$code/2d_entry_exit.do"
	}
	if `s2e_decomp' == 1 {
		do "$code/2e_decomposition.do"
	}

	*** Save every result table (the output CSVs) also as Excel
	if `s2_excel' == 1 {
		foreach t in 2a_growth_by_period 2a_growth_by_sector 2a_va_by_year ///
		             2b_index 2b_summary 2b_ulc ///
		             2c_transition_pre 2c_transition_crisis ///
		             2d_entry_exit 2e_decomp {
			capture confirm file "$output/`t'.csv"
			if !_rc {
				import delimited "$output/`t'.csv", clear varnames(1) case(preserve)
				export excel using "$output/`t'.xlsx", replace firstrow(variables)
			}
		}
	}

	timer off 1
	timer list 1
	display "Done. Results saved to: $output"
