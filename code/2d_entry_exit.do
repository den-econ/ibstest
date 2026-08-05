* ==============================================================================
* 2d_entry_exit.do -- SECTION 2d: Entry & exit rates
* ------------------------------------------------------------------------------
* For consecutive year pairs (t-1, t):
*   Entry rate = number of NEW firms in t        / number of firms in t-1
*   Exit  rate = number of firms that LEFT in t   / number of firms in t-1
*
* IMPORTANT (link validity): identity linking is only valid across CONSECUTIVE
* years with the SAME id SCHEME (idscheme). Pairs that cross a BPS scheme change
* or a missing year are skipped automatically.
*
* Output:
*   reg/2d_entry_exit.csv        entry/exit rate per year
*   fig/2d_entry_exit.png        entry vs exit figure
* ==============================================================================

	display as text "== 2d: entry & exit rate =="

	if "$link_ok" == "0" {
		display as error "   (skip) needs valid firm id - see 1_prepare / \$source"
		exit
	}

	use "$data/firm_panel.dta", clear

	keep fid idscheme year
	duplicates drop

	tempfile results
	postfile buf int year long nprev long entry long exit double entry_rate double exit_rate ///
		using "`results'", replace

	levelsof year, local(years)
	foreach t of local years {
		local tp = `t' - 1

		* skip if the previous year is not in the data
		quietly count if year == `tp'
		if r(N) == 0 continue

		preserve
			keep if year == `t' | year == `tp'

			* scheme must be the same between t-1 and t
			quietly levelsof idscheme, local(schs)
			if `:word count `schs'' > 1 {
				restore
				continue
			}

			* status of each firm in this year pair
			keep fid year
			bysort fid: gen byte n = _N          // 2 = present in both years
			by fid: gen byte in_t  = sum(year == `t')  == 1
			by fid: gen byte in_tp = sum(year == `tp') == 1
			by fid: keep if _n == _N             // one row per firm

			quietly count if in_tp == 1                        // NTP (t-1)
			local nprev = r(N)
			quietly count if in_t == 1 & in_tp == 0            // NEP (entrants)
			local nentry = r(N)
			quietly count if in_tp == 1 & in_t == 0            // NXP (exits)
			local nexit = r(N)

			if `nprev' > 0 {
				post buf (`t') (`nprev') (`nentry') (`nexit') ///
					(100*`nentry'/`nprev') (100*`nexit'/`nprev')
			}
		restore
	}
	postclose buf

* --- table & figure ------------------------------------------------------------
	use "`results'", clear
	sort year
	if _N == 0 {
		display as error "   !! no valid year pair for entry/exit"
		exit
	}

	format entry_rate exit_rate %5.1f
	export delimited using "$reg/2d_entry_exit.csv", replace
	list year nprev entry exit entry_rate exit_rate, noobs sep(0)

	twoway  (line entry_rate year, lpattern(solid)) ///
	        (line exit_rate  year, lpattern(dash)), ///
	        xline($crisis_year, lcolor(red) lpattern(dot)) ///
	        legend(order(1 "Entry rate" 2 "Exit rate") rows(1)) ///
	        ytitle("% of firms in t-1") xtitle("Year") ///
	        title("Manufacturing entry & exit rate") ///
	        note("Consecutive year pairs & same id scheme only. Source: IBS, authors' calculations.")
	graph export "$fig/2d_entry_exit.png", replace width(1400)

	display as result "   -> reg/2d_entry_exit.csv, fig/2d_entry_exit.png"
