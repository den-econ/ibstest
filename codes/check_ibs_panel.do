* ==============================================================================
* check_ibs_panel.do -- STANDALONE quality report on the IBS firm-year panel
* ------------------------------------------------------------------------------
* WHAT THIS FILE IS
*   A read-only report on data/raw/firm_panel.dta (built by prepare_ibs_panel.do).
*   It changes no data: it only counts, compares and prints. Run it right after
*   the panel has been built.
*
* WHAT IT REPORTS, IN ORDER
*   (1) overview      : rows per year, id scheme per year.
*   (2) columns       : which columns are absent (entirely empty) in which years.
*   (3) missing/zero  : share missing and share zero per year, by variable group
*                       (core, labour, investment, energy, materials, ...).
*   (4) consistency   : accounting identities, range checks, duplicate rows,
*                       jumps in yearly medians (money-unit changes), text columns
*                       that should be numeric.
*                       Also plots log output against capital, investment,
*                       energy and tax, with and without zero/missing values.
*   (5) panel         : id uniqueness, links between consecutive years, entry and
*                       exit, within-firm jumps, industry switches, values carried
*                       forward. Skipped for years where the firm id is masked or
*                       not unique (as on the sample).
*
* OUTPUT
*   One log file per run:  check_ibs_panel_<date>_<time>.log  in the ibstest folder.
*   With save_csv = 1 also two small tables of COUNTS (no firm-level rows):
*     data/raw/check_ibs_panel_missing.csv   variable x year: rows, filled, zero
*     data/raw/check_ibs_panel_checks.csv    check x year: rows evaluated, rows failing
*   With make_plots = 1 also  data/raw/check_ibs_panel_plot_*.png  (firm-level dots).
*
* HOW TO RUN
*   1. Run prepare_ibs_panel.do first.
*   2. Edit the CONFIG block below (at least $root).
*   3. Open Stata and run:  do "codes/check_ibs_panel.do"
*
* Only built-in Stata commands are used.
* ==============================================================================

	capture log close
	clear all
	set more off
	set varabbrev off
	set linesize 200

* ===================================================================== *
* >>>>>>>>>>>>>>>>>>>>>>>>>>>   CONFIG   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *
* ===================================================================== *

	*** (1) Project root = the ibstest folder on THIS computer.
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"

	*** (2) The panel to check, and where the optional CSV tables go.
		global panel_file "$root/data/raw/firm_panel.dta"
		global out        "$root/data/raw"
		global save_csv   1

	*** (3) Variable groups for the missing/zero tables (Section 3). Names are the
	***     panel names (raw IBS name without the year suffix). The grouping follows
	***     the IBS naming convention; check it against the questionnaire and edit
	***     freely. A name that is not in the panel is listed as such, not an error.
		global groups     "core labour invest energy material tradeown geo"
		global g_core     "output iinput va emp export isic5 labcost w_prod w_nonprod"
		global g_labour   "lprnou lnpnou zpdvcu zndvcu zptvcu zntvcu"
		global g_invest   "ctttcu cbttcu cmttcu cvttcu cottcu clttcu ctsacu v1115"
		global g_energy   "eplvcu enpvcu efuvcu eluvcu epevcu esovcu eclvcu encvcu elpvcu yelvcu"
		global g_material "rtlvcu rdnvcu rimvcu yprvcu stlvcu"
		global g_tradeown "export prprex dasing ddmstk dpemda dpusat"
		global g_geo      "dprovi dkabup dkecam ddesa"

	*** (4) Accounting identities (Section 4), written  lhs=rhs  WITHOUT spaces.
	***     Either side may be any Stata expression. A row is compared only when
	***     both sides are non-missing.
		global identities                                              ///
			va=output-iinput                                           ///
			rtlvcu=rdnvcu+rimvcu                                       ///
			emp=lprnou+lnpnou                                          ///
			ctttcu=cbttcu+cmttcu+cvttcu+cottcu+clttcu                  ///
			ctsacu=cbsacu+cmsacu+cvsacu+cosacu+clsacu                  ///
			v1115=v1101+v1103+v1106+v1109+v1112                        ///
			100=dasing+ddmstk+dpemda+dpusat

	*** (5) Thresholds.
		global tol         0.01   // identity holds if |lhs - rhs| <= tol * max(|lhs|, 1)
		global emp_min     20     // IBS covers establishments with at least this many workers
		global unit_jump   20     // flag a yearly median that moves by this factor or more
		global firm_jump   10     // flag a firm whose value moves by this factor in one step
		global id_bad_max  0.05   // a year enters Section 5 if at most this share of its rows
		                          //   has a blank, masked or duplicated firm id
		global list_min_years 6   // Section 2 lists columns present in at least this many
		                          //   years but not all; the CSV always has every column

	*** (6) Plots (Section 4f): log output against a variable that is often zero
	***     or missing, with a fit line including and one excluding those rows.
	***     p_<name> = the x variable (any Stata expression, no spaces);
	***     t_<name> = its axis title. plot_y = the y variable.
	***     The PNGs show one dot per firm-year, so they are saved next to the panel.
		global make_plots 1
		global plot_y     "output"
		global plots      "capital invest energy tax"
		global p_capital  "v1115"
		global t_capital  "fixed capital"
		global p_invest   "ctttcu"
		global t_invest   "fixed-asset additions"
		global p_energy   "efuvcu+eplvcu+enpvcu"
		global t_energy   "energy cost"
		global p_tax      "itxvcu"
		global t_tax      "indirect tax"

* ===================================================================== *
* -----------------   Run log and input   ----------------------------- *
* ===================================================================== *
	local _d = subinstr("`c(current_date)'", " ", "_", .)
	local _t = subinstr("`c(current_time)'", ":", "",  .)
	log using "$root/check_ibs_panel_`_d'_`_t'.log", replace text

	capture confirm file "$panel_file"
	if _rc {
		display as error "STOP: panel not found: $panel_file"
		display as error "Run prepare_ibs_panel.do first."
		capture log close
		exit 601
	}

*   post_flag: count, per year, the rows where a condition is true.
*     handle = postfile handle     label = text shown in the report
*     cond   = the condition        needs = variables that must be non-missing
*                                            for the row to be evaluated
	capture program drop post_flag
	program define post_flag
		args handle label cond needs
		foreach v of local needs {
			capture confirm variable `v'
			if _rc {
				display as text "   (not checked: `label' -- `v' is not in the panel)"
				exit
			}
		}
		if "`needs'" == "" {
			gen byte _ev = 1
		}
		else {
			local needsc : subinstr local needs " " ", ", all
			gen byte _ev = !missing(`needsc')
		}
		gen byte _bad = _ev & (`cond')
		quietly levelsof year, local(yrs)
		foreach y of local yrs {
			quietly count if year == `y' & _ev
			local n = r(N)
			quietly count if year == `y' & _bad
			post `handle' ("`label'") (`y') (`n') (r(N))
		}
		drop _ev _bad
	end

* ===================================================================== *
* -----------   (1) Overview   --------------------------------------- *
* ===================================================================== *
	use "$panel_file", clear
	display as text "{hline 100}"
	display as text "(1) OVERVIEW"
	display as text "{hline 100}"
	display as text "panel: $panel_file"
	display as text "rows: " _N "    columns: " c(k)
	tab year idscheme, missing
	quietly levelsof year, local(yrs)
	local nyears : word count `yrs'

* ===================================================================== *
* -----------   (2) Scan every column, year by year   ---------------- *
* ===================================================================== *
*   For each column and year: rows, rows filled (non-missing / non-blank) and,
*   for numeric columns, rows equal to zero. A column that the raw file of a
*   year did not carry is entirely empty in that year, so "absent" below means
*   "no filled row in that year".

	foreach y of local yrs {
		quietly count if year == `y'
		local N`y' = r(N)
	}

	tempname sh
	tempfile scan
	postfile `sh' str32 variable byte is_string int year long(n n_filled n_zero) using `scan'
	foreach v of varlist _all {
		if "`v'" == "year" continue
		capture confirm string variable `v'
		local isstr = (_rc == 0)
		foreach y of local yrs {
			if `isstr' {
				quietly count if year == `y' & strtrim(`v') != ""
				post `sh' ("`v'") (1) (`y') (`N`y'') (r(N)) (.)
			}
			else {
				quietly count if year == `y' & !missing(`v')
				local f = r(N)
				quietly count if year == `y' & `v' == 0
				post `sh' ("`v'") (0) (`y') (`N`y'') (`f') (r(N))
			}
		}
	}
	postclose `sh'

	use `scan', clear
	gen double pct_missing = 100 * (n - n_filled) / n
	quietly gen double pct_zero = 100 * n_zero / n
	gen byte   absent      = (n_filled == 0)
	label var variable    "Panel column"
	label var is_string   "1 = text column"
	label var n           "Rows in the year"
	label var n_filled    "Rows with a value"
	label var n_zero      "Rows equal to zero (numeric columns)"
	label var pct_missing "% of rows without a value"
	label var pct_zero    "% of rows equal to zero"
	label var absent      "1 = no row has a value in this year"
	save `scan', replace
	if $save_csv == 1 {
		export delimited using "$out/check_ibs_panel_missing.csv", replace
	}

	display as text _n "{hline 100}"
	display as text "(2) COLUMNS ABSENT IN SOME YEARS"
	display as text "{hline 100}"
	sort variable year
	by variable: gen int years_present = sum(!absent)
	quietly by variable: gen str80 absent_years = cond(absent, substr(string(year), 3, 2), "") if _n == 1
	quietly by variable: replace absent_years = strtrim(absent_years[_n-1] + " " +      ///
		cond(absent, substr(string(year), 3, 2), "")) if _n > 1
	quietly by variable: keep if _n == _N
	display as text "columns by number of years with at least one value (out of `nyears'):"
	tab years_present
	display as text _n "columns present in at least $list_min_years years but not in all, and the years they are absent:"
	list variable years_present absent_years                                     ///
		if years_present >= $list_min_years & years_present < `nyears', noobs sep(0) abbreviate(14)
	quietly count if years_present < $list_min_years
	display as text "(" r(N) " more columns are present in fewer than $list_min_years years; see the CSV for all of them)"

* ===================================================================== *
* -----------   (3) Missing and zero shares by variable group   ------ *
* ===================================================================== *
*   Cells are percentages of the year's rows. "--" = the column is absent in
*   that year. Zero and missing are different things: zero is a reported value.

	display as text _n "{hline 100}"
	display as text "(3) MISSING AND ZERO SHARES BY VARIABLE GROUP   (% of rows; -- = column absent that year)"
	display as text "{hline 100}"
	foreach g of global groups {
		use `scan', clear
		quietly gen int ord = .
		local i = 0
		local notfound ""
		foreach v of global g_`g' {
			local ++i
			quietly count if variable == "`v'"
			if r(N) == 0 local notfound `notfound' `v'
			quietly replace ord = `i' if variable == "`v'"
		}
		quietly keep if ord < .
		display as text _n "-- group: `g' --"
		if "`notfound'" != "" display as text "   not in the panel: `notfound'"
		quietly count
		if r(N) == 0 continue
		foreach stat in missing zero {
			preserve
			gen str6 y = cond(absent, "--", cond(missing(pct_`stat'), ".", string(pct_`stat', "%5.1f")))
			keep variable ord year y
			quietly reshape wide y, i(ord variable) j(year)
			display as text "   % `stat'"
			list variable y*, noobs sep(0)
			restore
		}
	}

* ===================================================================== *
* -----------   (4) Consistency within a year   ---------------------- *
* ===================================================================== *
	use "$panel_file", clear

	tempname ch
	tempfile checks
	postfile `ch' str70 check int year long(n_eval n_fail) using `checks'

	display as text _n "{hline 100}"
	display as text "(4) CONSISTENCY"
	display as text "{hline 100}"

	* (4a) accounting identities
	foreach id of global identities {
		local eq  = strpos("`id'", "=")
		local lhs = substr("`id'", 1, `eq' - 1)
		local rhs = substr("`id'", `eq' + 1, .)
		capture gen double _l = `lhs'
		local rc1 = _rc
		capture gen double _r = `rhs'
		local rc2 = _rc
		if `rc1' | `rc2' {
			display as text "   (not checked: `id' -- a variable is not in the panel)"
			capture drop _l
			capture drop _r
			continue
		}
		gen byte _ev  = !missing(_l, _r)
		gen byte _bad = _ev & abs(_l - _r) > $tol * max(abs(_l), 1)
		foreach y of local yrs {
			quietly count if year == `y' & _ev
			local n = r(N)
			quietly count if year == `y' & _bad
			post `ch' ("identity: `id'") (`y') (`n') (r(N))
		}
		drop _l _r _ev _bad
	}

	* (4b) range checks
	post_flag `ch' "output <= 0"                          "output <= 0"                  "output"
	post_flag `ch' "intermediate input <= 0"              "iinput <= 0"                  "iinput"
	post_flag `ch' "value added <= 0"                     "va <= 0"                      "va"
	post_flag `ch' "workers <= 0"                         "emp <= 0"                     "emp"
	post_flag `ch' "workers below $emp_min"               "emp < $emp_min"               "emp"
	post_flag `ch' "no production workers"                "lprnou == 0"                  "lprnou"
	post_flag `ch' "labour cost > value added"            "labcost > va"                 "labcost va"
	post_flag `ch' "exports > output"                     "export > output"              "export output"
	post_flag `ch' "export share outside 0-100"           "!inrange(prprex, 0, 100)"     "prprex"
	post_flag `ch' "foreign share outside 0-100"          "!inrange(dasing, 0, 100)"     "dasing"
	post_flag `ch' "no energy cost at all"                "eplvcu == 0 & enpvcu == 0 & efuvcu == 0" "eplvcu enpvcu efuvcu"
	post_flag `ch' "industry code missing"                "missing(isic5)"               ""
	post_flag `ch' "isic2 outside 10-33"                  "!inrange(isic2, 10, 33)"      "isic2"
	post_flag `ch' "firm id blank or masked"              `"!regexm(fid, "[0-9A-Za-z]")"' ""

	* (4c) rows identical in every column except the firm id (strL columns cannot
	*      be compared by -duplicates- and are left out)
	local dupvars ""
	foreach v of varlist _all {
		if inlist("`v'", "fid", "idscheme") continue
		local t : type `v'
		if "`t'" == "strL" continue
		local dupvars `dupvars' `v'
	}
	quietly duplicates tag `dupvars', gen(_dup)
	post_flag `ch' "row duplicated (all columns except fid)" "_dup > 0" ""
	drop _dup
	postclose `ch'

	preserve
		use `checks', clear
		quietly gen double pct_fail = 100 * n_fail / n_eval
		label var check    "Check"
		label var n_eval   "Rows evaluated (needed values present)"
		label var n_fail   "Rows failing"
		label var pct_fail "% of evaluated rows failing"
		if $save_csv == 1 {
			export delimited using "$out/check_ibs_panel_checks.csv", replace
		}
		gen long ord = _n
		quietly bysort check (ord): replace ord = ord[1]
		gen str7 f = cond(n_eval == 0, "--", string(pct_fail, "%6.2f"))
		gen str7 n = string(n_eval)
		keep check ord year f n
		quietly reshape wide f n, i(ord check) j(year)
		display as text _n "% of evaluated rows FAILING each check   (-- = nothing to evaluate that year)"
		list check f*, noobs sep(0)
		display as text _n "rows evaluated (both sides / needed values present)"
		list check n*, noobs sep(0)
	restore

	* (4d) yearly medians: a jump by a large factor points to a change of money unit
	display as text _n "yearly medians (nominal)"
	preserve
		collapse (p50) output iinput va labcost export emp, by(year)
		list, noobs sep(0)
		local jumps = 0
		foreach v in output iinput va labcost export emp {
			forvalues i = 2/`=_N' {
				local a = `v'[`i']
				local b = `v'[`i' - 1]
				if `a' > 0 & `b' > 0 & `a' < . & `b' < . {
					if `a' / `b' >= $unit_jump | `a' / `b' <= 1 / $unit_jump {
						display as error "!! median `v' moves by a factor " %9.3g `a' / `b'   ///
							" between " year[`i' - 1] " and " year[`i'] " -> check the money unit."
						local ++jumps
					}
				}
			}
		}
		if `jumps' == 0 display as text "no yearly median moves by a factor of $unit_jump or more."
	restore

	* (4e) text columns whose values are mostly numbers: a stray character in some
	*      year kept the whole column as text when the years were stacked
	display as text _n "text columns where at least half of the filled values are numbers:"
	local found = 0
	foreach v of varlist _all {
		if "`v'" == "fid" continue
		capture confirm string variable `v'
		if _rc continue
		quietly count if strtrim(`v') != ""
		local n = r(N)
		if `n' == 0 continue
		quietly count if real(strtrim(`v')) < .
		if r(N) / `n' >= 0.5 {
			display as text "   `v': " %5.1f 100 * r(N) / `n' "% of " `n' " filled values are numeric"
			local ++found
		}
	}
	if `found' == 0 display as text "   none"

	* (4f) log output against variables that are often zero or missing, as in
	*      Gupta (2023, figure 1). Rows with a zero or missing x sit at x = 0.
	*      Dashed line = fit on all rows; solid line = fit on rows with x > 0.
	if $make_plots == 1 {
		display as text _n "log $plot_y against often-zero variables (rows with $plot_y > 0)"
		display as text "   slope_all = OLS slope with zero/missing x placed at log x = 0"
		display as text "   slope_pos = OLS slope on rows with x > 0 only"
		quietly gen double _ly = ln($plot_y) if $plot_y > 0 & $plot_y < .
		local gnames ""
		foreach p of global plots {
			capture gen double _x = ${p_`p'}
			if _rc {
				display as text "   (not plotted: `p' -- ${p_`p'} uses a variable that is not in the panel)"
				continue
			}
			quietly gen double _lx  = ln(_x) if _x > 0 & _x < . & _ly < .
			quietly gen double _lx0 = cond(_x > 0 & _x < ., ln(_x), 0) if _ly < .
			quietly count if _ly < .
			local n = r(N)
			quietly count if _lx < .
			local npos = r(N)
			quietly count if _ly < . & _x <= 0
			local nzero = r(N)
			quietly count if _ly < . & missing(_x)
			local nmiss = r(N)
			if `npos' < 2 {
				display as text "   (not plotted: `p' -- fewer than two rows with a positive value)"
				drop _x _lx _lx0
				continue
			}
			quietly regress _ly _lx0
			local b_all = _b[_lx0]
			quietly regress _ly _lx
			local b_pos = _b[_lx]
			display as result "   `p' (${p_`p'}): rows " `n' ", x > 0 " %5.1f 100 * `npos' / `n'      ///
				"%, zero " %5.1f 100 * `nzero' / `n' "%, missing " %5.1f 100 * `nmiss' / `n'         ///
				"%;  slope_all " %6.3f `b_all' ", slope_pos " %6.3f `b_pos'
			twoway (scatter _ly _lx0, msize(vtiny) mcolor(gs7))                                     ///
			       (lfit _ly _lx0, lpattern(dash)  lcolor(black) lwidth(medthick))                  ///
			       (lfit _ly _lx,  lpattern(solid) lcolor(black) lwidth(medthick)),                 ///
			       legend(order(2 "Including zero/missing" 3 "Excluding zero/missing")              ///
			              cols(1) position(6) size(small) region(lstyle(none)))                                 ///
			       xtitle("Log of ${t_`p'}") ytitle("Log of $plot_y") title("${t_`p'}", size(medium)) ///
			       graphregion(color(white)) plotregion(color(white)) ylabel(, nogrid) xlabel(, nogrid)     ///
			       name(g_`p', replace)
			quietly graph export "$out/check_ibs_panel_plot_`p'.png", replace width(1600)
			local gnames `gnames' g_`p'
			drop _x _lx _lx0
		}
		drop _ly
		if "`gnames'" != "" {
			graph combine `gnames', cols(2) iscale(0.6) graphregion(color(white)) xsize(9) ysize(8) name(g_all, replace)
			quietly graph export "$out/check_ibs_panel_plot_all.png", replace width(2400)
			display as result "   plots saved: $out/check_ibs_panel_plot_*.png"
		}
	}

* ===================================================================== *
* -----------   (5) Consistency across years (needs a real firm id)   - *
* ===================================================================== *
*   A firm is "linked" in a year when it also appears in the previous AVAILABLE
*   year (2015 -> 2017 counts as consecutive because 2016 has no file). A link
*   rate near zero between two years means the id scheme changed, not that
*   every firm exited.

	display as text _n "{hline 100}"
	display as text "(5) PANEL"
	display as text "{hline 100}"

	local keepv fid idscheme year output va emp isic2 isic5
	local has_prov = 0
	capture confirm numeric variable dprovi
	if !_rc {
		local keepv `keepv' dprovi
		local has_prov = 1
	}
	keep `keepv'
	gen byte masked = !regexm(fid, "[0-9A-Za-z]")
	bysort year fid: gen long _copies = _N
	gen byte dup_id = (_copies > 1 & !masked)
	gen byte bad_id = (masked | dup_id)
	bysort year: egen double share_bad = mean(bad_id)
	gen byte usable = (share_bad <= $id_bad_max)

	preserve
		bysort year fid: gen byte _first = (_n == 1 & !masked)
		collapse (count) rows = masked (sum) distinct_ids = _first masked dup_id   ///
			(max) usable, by(year idscheme)
		display as text "firm id by year (dup_id = rows whose fid appears more than once in the year)"
		list, noobs sep(0) abbreviate(14)
	restore

	quietly levelsof year if usable, local(uyrs)
	local nuse : word count `uyrs'
	if `nuse' < 2 {
		display as error "!! fewer than two years have a usable firm id -> panel checks skipped."
		display as error "   On the sample this is expected: the firm id is masked."
	}
	else {
		quietly count if usable & bad_id
		display as text _n "years used: `uyrs'"
		display as text "rows dropped from those years for a blank, masked or duplicated id: " r(N)
		quietly keep if usable & !bad_id
		egen int yidx = group(year)
		sort fid year
		by fid: gen byte linked   = (_n > 1 & yidx[_n-1] == yidx - 1)
		by fid: gen byte continues = (_n < _N & yidx[_n+1] == yidx + 1)
		foreach v in output va emp isic2 isic5 {
			quietly by fid: gen double l_`v' = `v'[_n-1] if linked
		}
		foreach v in output va emp {
			gen byte jump_`v' = linked & `v' > 0 & l_`v' > 0 & !missing(`v', l_`v') &   ///
				(`v' / l_`v' >= $firm_jump | `v' / l_`v' <= 1 / $firm_jump)
		}
		gen byte sw_isic2 = linked & !missing(isic2, l_isic2) & isic2 != l_isic2
		gen byte sw_isic5 = linked & !missing(isic5, l_isic5) & isic5 != l_isic5
		gen byte carried  = linked & !missing(output, va, emp) &                        ///
			output == l_output & va == l_va & emp == l_emp
		local flags jump_output jump_va jump_emp sw_isic2 sw_isic5 carried
		if `has_prov' {
			quietly by fid: gen double l_prov = dprovi[_n-1] if linked
			gen byte sw_prov = linked & !missing(dprovi, l_prov) & dprovi != l_prov
			local flags `flags' sw_prov
		}

		* firms by number of years observed, and firms with a gap
		preserve
			by fid: gen int n_years = _N
			by fid: gen byte has_gap = (yidx[_N] - yidx[1] + 1 > _N)
			quietly by fid: keep if _n == 1
			display as text _n "firms by number of years observed"
			tab n_years
			quietly count if has_gap
			display as text "firms that leave and come back (gap inside their span): " r(N) " of " _N
		restore

		quietly summarize yidx
		local last = r(max)
		collapse (count) rows = linked (sum) linked continues `flags' (first) yidx, by(year)
		quietly gen double pct_linked = 100 * linked / rows if yidx > 1
		quietly gen double pct_exit   = 100 * (rows - continues) / rows if yidx < `last'
		foreach f of local flags {
			quietly gen double p_`f' = 100 * `f' / linked if linked > 0
		}
		format pct_* p_* %6.2f
		display as text _n "links between consecutive available years"
		display as text "   pct_linked = % of the year's rows also present in the previous year (rest = entrants)"
		display as text "   pct_exit   = % of the year's rows NOT present in the next year"
		list year rows linked pct_linked pct_exit, noobs sep(0) abbreviate(14)
		display as text _n "among linked rows, % with ..."
		display as text "   jump_*   = value moved by a factor of $firm_jump or more since the previous year"
		display as text "   sw_*     = industry (or province) code differs from the previous year"
		display as text "   carried  = output, value added and workers all identical to the previous year"
		list year linked p_*, noobs sep(0) abbreviate(14)
	}

	display as text _n "{hline 100}"
	display as result "check_ibs_panel done. Nothing in the panel was changed."
	if $save_csv == 1 display as result "CSV tables: $out/check_ibs_panel_missing.csv, check_ibs_panel_checks.csv"
	display as text "{hline 100}"
	capture log close
