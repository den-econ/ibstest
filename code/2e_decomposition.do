* ==============================================================================
* 2e_decomposition.do -- SECTION 2e: Survivor expansion/contraction & decomposition
* ------------------------------------------------------------------------------
* Follows Davis, Haltiwanger & Schuh (1996), employment-based. For each
* consecutive year pair (t-1, t) with the same id scheme, employment growth is
* decomposed into 4 components (denominator = total employment in t-1):
*   entry_rate       new firms entering        (EMPL_EN / EMPL_T(t-1))
*   expansion_rate   surviving firms growing   (EMPL_POS / EMPL_T(t-1))
*   exit_rate        firms exiting             (EMPL_EX / EMPL_T(t-1))
*   contraction_rate surviving firms shrinking (|EMPL_NEG| / EMPL_T(t-1))
* Net = entry + expansion - exit - contraction  (= employment growth).
*
* Output:
*   reg/2e_decomp.csv   decomposition per year (in %)
* ==============================================================================

	display as text "== 2e: employment-growth decomposition =="

	if "$link_ok" == "0" {
		display as error "   (skip) needs valid firm id - see 1_prepare / \$source"
		exit
	}

	use "$data/firm_panel.dta", clear

	keep fid idscheme year emp
	drop if missing(emp)

	* one row per firm-year (sum if multi-plant)
	collapse (sum) emp, by(fid idscheme year)

	tempfile results
	postfile buf int year double entry_rate double expansion_rate ///
		double exit_rate double contraction_rate double net_rate ///
		using "`results'", replace

	levelsof year, local(years)
	foreach t of local years {
		local tp = `t' - 1

		quietly count if year == `tp'
		if r(N) == 0 continue

		preserve
			keep if year == `t' | year == `tp'

			quietly levelsof idscheme, local(schs)
			if `:word count `schs'' > 1 {
				restore
				continue
			}

			keep fid year emp
			reshape wide emp, i(fid) j(year)      // emp`tp'  emp`t'

			* denominator: total employment of all firms present in t-1
			quietly summarize emp`tp'
			local Tprev = r(sum)
			if `Tprev' <= 0 {
				restore
				continue
			}

			* status & employment change
			gen byte cont = !missing(emp`tp') & !missing(emp`t')
			gen byte ent  =  missing(emp`tp') & !missing(emp`t')
			gen byte ex   = !missing(emp`tp') &  missing(emp`t')
			gen double d  = emp`t' - emp`tp'

			gen double v_en  = emp`t'  if ent
			gen double v_ex  = emp`tp' if ex
			gen double v_pos = d       if cont & d > 0
			gen double v_neg = -d      if cont & d < 0

			quietly summarize v_en
			local EN = r(sum)
			quietly summarize v_ex
			local EX = r(sum)
			quietly summarize v_pos
			local POS = r(sum)
			quietly summarize v_neg
			local NEG = r(sum)

			post buf (`t') (100*`EN'/`Tprev') (100*`POS'/`Tprev') ///
				(100*`EX'/`Tprev') (100*`NEG'/`Tprev') ///
				(100*(`EN'+`POS'-`EX'-`NEG')/`Tprev')
		restore
	}
	postclose buf

	use "`results'", clear
	sort year
	if _N == 0 {
		display as error "   !! no valid year pair for the decomposition"
		exit
	}

	format entry_rate expansion_rate exit_rate contraction_rate net_rate %6.2f
	export delimited using "$reg/2e_decomp.csv", replace
	list, noobs sep(0)

	display as result "   -> reg/2e_decomp.csv"
