* ==============================================================================
* 2b_jobless_growth.do  -- SECTION 2b: Labour productivity & "jobless growth"
* ------------------------------------------------------------------------------
* Index (base year = 100) for output, value added, employment, and labour
* productivity (VA/L). The "jobless growth" pattern shows up when output/VA
* recover but employment lags behind.
*
* Unit Labour Cost (ULC = labour cost / value added) can only be computed for
* years that have labour-cost data (2010-2018) -> exported separately, no index.
*
* Output:
*   reg/2b_index.csv          yearly index (output/VA/employment/productivity)
*   reg/2b_summary.csv        index values at base, crisis & final year
*   reg/2b_ulc.csv            yearly ULC level (where data available)
*   fig/2b_jobless_growth.png index figure
* ==============================================================================

	display as text "== 2b: labour productivity & jobless growth =="
	use "$data/firm_panel.dta", clear

* --- national aggregate per year -----------------------------------------------
	collapse (sum) output va emp labcost, by(year)
	gen double prod = va/emp                       // labour productivity

* --- index (base year = 100) ---------------------------------------------------
	foreach v in output va emp prod {
		quietly summarize `v' if year == $base_year, meanonly
		if r(N) == 0 {
			display as error "   !! base year $base_year not present in data"
			continue
		}
		gen double idx_`v' = 100*`v'/r(mean)
		label var idx_`v' "`v' (index, $base_year=100)"
	}

* --- export index table & summary ----------------------------------------------
	preserve
		keep year idx_output idx_va idx_emp idx_prod
		export delimited using "$reg/2b_index.csv", replace
		list, noobs sep(0)
	restore

	preserve
		keep if inlist(year, $base_year, $crisis_year, $year_end)
		keep year idx_output idx_va idx_emp idx_prod
		export delimited using "$reg/2b_summary.csv", replace
	restore

* --- ULC (only years with labour-cost data) -----------------------------------
	preserve
		keep if labcost < . & labcost > 0 & va > 0
		gen double ulc = labcost/va
		keep year labcost va ulc
		if _N > 0 {
			export delimited using "$reg/2b_ulc.csv", replace
			display as text "   ULC computed for years: " _c
			list year ulc, noobs sep(0)
		}
		else display as text "   (labour cost not available - ULC skipped)"
	restore

* --- figure --------------------------------------------------------------------
	twoway  (line idx_output year, lpattern(solid)) ///
	        (line idx_va     year, lpattern(dash)) ///
	        (line idx_emp    year, lpattern(shortdash)) ///
	        (line idx_prod   year, lpattern(longdash)), ///
	        yline(100, lcolor(gs10)) ///
	        xline($crisis_year, lcolor(red) lpattern(dot)) ///
	        legend(order(1 "Output" 2 "Value added" 3 "Employment" 4 "Labour productivity") rows(1) size(small)) ///
	        ytitle("Index ($base_year = 100)") xtitle("Year") ///
	        title("Jobless growth: output vs employment") ///
	        note("Red line = crisis year ($crisis_year). Source: IBS, authors' calculations.")
	graph export "$fig/2b_jobless_growth.png", replace width(1400)

	display as result "   -> reg/2b_*.csv, fig/2b_jobless_growth.png"
