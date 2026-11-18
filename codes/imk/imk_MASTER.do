* ==============================================================================
* imk_MASTER.do -- control center for the IMK (Industri Mikro & Kecil) analysis
* ------------------------------------------------------------------------------
* WHAT THIS FILE DOES (in plain words):
*   This is the ONE file you run. It sets a few settings, then calls each step of
*   the IMK pipeline in order. The IMK analysis mirrors the IBS one, but
*   EVERYTHING is at INDUSTRY level (2-digit KBLI), because IMK has no persistent
*   firm id (firms cannot be followed across years). Size follows the BPS
*   worker-count definition: Micro = 1-4, Small = 5-19 workers.
*
* READ ME !!
*   1. The raw IMK data lives in  data/raw_imk_sampel/  as VIMK{YY}.dta
*      (created from the Excel files by convert_imk_dta.do).
*   2. Open Stata in this repo folder (or set $root below), then run this file:
*        do "code/imk_MASTER.do"
*   3. Sections 0 and 1 are "run once" steps. Once data/imk_firm.dta exists you
*      can set their triggers to 0 and re-run only the analysis step you want;
*      each analysis step is self-contained.
*
* OUTPUT goes to  output_imk/  (kept separate from the IBS output/).
* ==============================================================================

	capture log close        // close any log left open by a previous run
	clear all                // wipe everything (data, programs, saved results)
	set more off             // never pause for "-more-" prompts
	set varabbrev off        // variable names must be typed in full (safer)

* ===================================================================== *
* -------------------           Path               -------------------- *
* ===================================================================== *
*   Set the project root, then load the shared path settings. c(username) is the
*   computer login name; on another machine we fall back to the current folder.
	if "`c(username)'" == "meizahra" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}
	if "$root" == "" global root "`c(pwd)'"
	do "$root/codes/SET_FILEPATHS.do"            // shared file at codes/ root; defines $code, $data, $raw_imk, $output_imk, $code_scar, ...

* ===================================================================== *
* -------------------           Setup              -------------------- *
* ===================================================================== *
*   These "globals" are the knobs for the whole analysis; every step reads them.

	*** (1) Data range (the IMK sample covers 2017-2025)
		global imk_y_start  2017
		global imk_y_end    2025

	*** (2) Index base year (= 100) and the crisis marker
		global imk_base     2019        // last pre-crisis year (index base)
		global imk_crisis   2020        // COVID-19: a year >= this is "crisis"

	*** (3) Three periods (richer than IBS because IMK runs all the way to 2025)
		global imk_pre_y0   2017        // pre-crisis: start -> end
		global imk_pre_y1   2019
		global imk_cri_y0   2020        // crisis:     start -> end
		global imk_cri_y1   2022
		global imk_rec_y0   2023        // recovery:   start -> end
		global imk_rec_y1   2025

	*** (4) BPS worker-count size classes (micro vs small), at firm level
		global imk_micro_max 4          // Micro: 1-4 workers ; Small: 5-19

	*** (5) Survey weight (name a weight variable to weight aggregates; "" = none)
	***     The sample has no documented design weight, so the default is unweighted.
		global imk_weight   ""

* ===================================================================== *
* -----------------            Triggers             ----------------- *
* ===================================================================== *
*   Each switch below is 1 = run this step, 0 = skip it. The "local" names only
*   exist while this file runs.

		local s0_convert     1   // Excel VIMK{YY} -> .dta (run once; skips absent Excel)
		local s1_prepare     1   // build data/imk_firm.dta (harmonize all years)
		local s2a_growth     1   // 2a: output/employment growth by period & industry
		local s2b_jobless    1   // 2b: labour productivity & jobless growth, ULC
		local s2c_mobility   1   // 2c: industry size-tier mobility (+ Sankey data)
		local s2d_entry_exit 1   // 2d: establishment-count dynamics (net churn)
		local s2e_decomp     1   // 2e: within/between (shift-share) decomposition
		local s2_excel       1   // also write the result tables as .xlsx
		local s2_sankey      1   // Sankey of size-tier mobility (native Stata, auto-install)

* ===================================================================== *
* -----------------            Do-files             ----------------- *
* ===================================================================== *
*   Run each step whose trigger is 1. "do" runs another do-file.

	display c(current_time)
	timer clear 2                                // reset stopwatch #2
	timer on 2                                   // start timing the whole run

	* convert + prepare are ENGINE steps (this repo), under codes/imk/ -> $code/imk/.
	* The 2a-2e analysis do-files live in the SIBLING project scarring_industry/,
	* under codes/imk/ -> $code_scar/imk/.
	if `s0_convert'     do "$code/imk/convert_imk_dta.do"
	if `s1_prepare'     do "$code/imk/imk_1_prepare.do"
	if `s2a_growth'     do "$code_scar/imk/imk_2a_growth.do"
	if `s2b_jobless'    do "$code_scar/imk/imk_2b_jobless_growth.do"
	if `s2c_mobility'   do "$code_scar/imk/imk_2c_size_mobility.do"
	if `s2d_entry_exit' do "$code_scar/imk/imk_2d_entry_exit.do"
	if `s2e_decomp'     do "$code_scar/imk/imk_2e_decomposition.do"

	*** Also save each result table as Excel, if the CSV exists.
	*   We import the CSV back in and export it as .xlsx (case(preserve) keeps the
	*   original column-name capitalization).
	if `s2_excel' {
		foreach t in imk_2a_growth_by_period imk_2a_growth_by_industry imk_2a_totals ///
		             imk_2b_index imk_2b_ulc ///
		             imk_2c_transition_pre imk_2c_transition_crisis imk_2c_transition_recovery ///
		             imk_2c_sizeshare imk_2d_establishments imk_2e_decomp {
			capture confirm file "$output_imk/`t'.csv"
			if !_rc {
				import delimited "$output_imk/`t'.csv", clear varnames(1) case(preserve)
				export excel using "$output_imk/`t'.xlsx", replace firstrow(variables)
			}
		}
	}

	*** Render the Sankey diagrams (native Stata; auto-installs packages, with a
	*** Python fallback). render_sankey.do reads whatever folder $sankey_dir points to.
	if `s2_sankey' {
		global sankey_dir "$output_imk"
		do "$code_scar/render_sankey.do"
	}

	timer off 2                                  // stop the stopwatch
	timer list 2                                 // print how long the run took
	display "Done. IMK results saved to: $output_imk"
