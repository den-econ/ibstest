* ==============================================================================
* 2a_growth.do   -- SECTION 2a: Aggregate output growth & structure
* ------------------------------------------------------------------------------
* Compares the growth rate of aggregate value added (and output) across
* sub-periods: pre-crisis, crisis, post-crisis. Also by ISIC 2-digit sector.
*
* Output:
*   reg/2a_va_by_year.csv          yearly aggregate + y-o-y growth
*   reg/2a_growth_by_period.csv    mean growth per sub-period
*   reg/2a_growth_by_sector.csv    mean growth per sector & period
* ==============================================================================

	display as text "== 2a: output & value-added growth =="
	use "$data/firm_panel.dta", clear

* --- sub-period label ----------------------------------------------------------
*   pre-crisis  : before the crisis year
*   crisis      : crisis year up to crisis+1
*   post-crisis : after crisis+1
	local cy = $crisis_year

* --- (1) National aggregate per year ------------------------------------------
	preserve
		collapse (sum) va output, by(year)
		tsset year
		gen double g_va     = 100*(va/L.va         - 1)
		gen double g_output = 100*(output/L.output - 1)

		gen str12 period = "pre-crisis"
		replace   period = "crisis"      if year >= `cy' & year <= `cy'+1
		replace   period = "post-crisis" if year >  `cy'+1

		export delimited using "$reg/2a_va_by_year.csv", replace
		list year va g_va g_output period, noobs sep(0)

		* mean growth per sub-period
		collapse (mean) g_va g_output, by(period)
		export delimited using "$reg/2a_growth_by_period.csv", replace
		list, noobs
	restore

* --- (2) By ISIC 2-digit sector -----------------------------------------------
	preserve
		collapse (sum) va, by(isic2 year)
		xtset isic2 year
		gen double g_va = 100*(va/L.va - 1)

		gen str12 period = "pre-crisis"
		replace   period = "crisis"      if year >= `cy' & year <= `cy'+1
		replace   period = "post-crisis" if year >  `cy'+1

		collapse (mean) g_va, by(isic2 period)
		export delimited using "$reg/2a_growth_by_sector.csv", replace
	restore

	display as result "   -> reg/2a_*.csv"
