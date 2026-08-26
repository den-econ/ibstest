* ==============================================================================
* 2c_size_mobility.do -- SECTION 2c: Mobility across firm size classes
* ------------------------------------------------------------------------------
* Size class by number of workers:
*   1 Small (20-99), 2 Medium (100-499), 3 Large (500+).
* Transition matrix: row = start-year class, column = end-year class,
* cell = % of firms that moved. Built for the pre-crisis and post-crisis year
* pairs (set in MASTER.do). A firm must appear in both years.
*
* Output (into $reg = output/):
*   2c_transition_pre.csv      pre-crisis pair ($pre_y0    -> $pre_y1)
*   2c_transition_crisis.csv   crisis pair    ($crisis_y0 -> $crisis_y1)
* ==============================================================================

	display as text "== 2c: mobility across size classes =="

	if "$link_ok" == "0" {
		display as error "   (skip) needs valid firm id - see 1_prepare / \$source"
		exit
	}

* --- helper program: transition matrix for a pair of years --------------------
	capture program drop _transmat
	program define _transmat
		args y0 y1 outfile
		use "$data/firm_panel.dta", clear
		keep if year == `y0' | year == `y1'
		keep fid idscheme year emp

		* one row per firm-year (sum if multi-plant)
		collapse (sum) emp, by(fid idscheme year)

		* size class
		gen byte cls = .
		replace  cls = 1 if emp >= 20  & emp <= $small_max
		replace  cls = 2 if emp >  $small_max  & emp <= $medium_max
		replace  cls = 3 if emp >  $medium_max & emp < .
		drop if missing(cls)

		* wide form: one row per firm
		keep fid idscheme year cls
		reshape wide cls, i(fid idscheme) j(year)

		* only firms PRESENT in both years (traceable)
		keep if !missing(cls`y0') & !missing(cls`y1')
		count
		if r(N) == 0 {
			display as error "   !! no firm appears in both `y0' & `y1'"
			exit
		}

		* transition frequency + row percent (start class)
		rename cls`y0' cls_start
		rename cls`y1' cls_end
		contract cls_start cls_end, freq(n)
		bysort cls_start: egen double base = total(n)
		gen double share_pct = 100*n/base

		label define cls 1 "Small" 2 "Medium" 3 "Large", replace
		label values cls_start cls_end cls

		export delimited cls_start cls_end n share_pct using "`outfile'", replace
		display as text "   `y0' -> `y1':"
		list cls_start cls_end n share_pct, noobs sepby(cls_start)
	end

* --- run for pre & post crisis -------------------------------------------------
	_transmat $pre_y0    $pre_y1    "$reg/2c_transition_pre.csv"
	_transmat $crisis_y0 $crisis_y1 "$reg/2c_transition_crisis.csv"

	display as result "   -> 2c_transition_pre.csv, 2c_transition_crisis.csv"
