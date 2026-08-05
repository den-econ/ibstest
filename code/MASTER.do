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
*   - Run 01_prepare only once (builds the panel & saves it to data/).
*   - Once the panel is saved, turn the prepare trigger off (set to 0) and just
*     switch on the lens you want to re-run. Each lens is self-contained.
* ==============================================================================

	capture log close
	clear all
	set more off

* ===================================================================== *
* -------------------           Path               -------------------- *
* ===================================================================== *
*   All paths are set in SET_FILEPATHS.do (based on Stata's working folder).
*   This line locates SET_FILEPATHS.do relative to the working folder.

	do "`c(pwd)'/code/SET_FILEPATHS.do"

* ===================================================================== *
* -------------------           Setup              -------------------- *
* ===================================================================== *

	*** (0) Data source
	*   "auto"  : try raw data in data/raw/; if firm id is masked (like this
	*             sample) fall back to the synthetic panel. <- default.
	*   "raw"   : force from data/raw/mfgYYYY.dta  (used on the REAL data).
	*   "panel" : force from synthetic panel data/ibs_panel_2010_2022.csv (test).
		global source       "auto"

	*** (1) Range of years available in data/raw/
		global year_start   2010
		global year_end     2022

	*** (2) Crisis year & index base year
		global crisis_year  2020        // COVID-19
		global base_year    2019        // index base = 100 (year before crisis)

	*** (3) Firm size-class thresholds (number of workers) - AHN definition
		global small_max    99          // Small : 20-99
		global medium_max   499         // Medium: 100-499  (Large: 500+)

	*** (4) Year pairs for the size transition matrix (Lens 4)
		global pre_y0       2018        // pre-crisis: start -> end
		global pre_y1       2019
		global post_y0      2021        // post-crisis: start -> end
		global post_y1      2022

* ===================================================================== *
* -----------------            Triggers             ----------------- *
* ===================================================================== *
*   1 = run, 0 = skip.

	*** Section 1 - build the panel (run once, then may be turned off)
		local s1_prepare            1

	*** Section 2 - cleaning & analysis
		local s2a_growth            1   // 2a: output/value-added growth
		local s2b_jobless           1   // 2b: labour productivity & jobless growth
		local s2c_mobility          1   // 2c: mobility across size classes
		local s2d_entry_exit        1   // 2d: entry/exit rate
		local s2e_decomp            1   // 2e: employment-growth decomposition

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

	timer off 1
	timer list 1
	display "Done. Tables -> $reg  |  Figures -> $fig"
