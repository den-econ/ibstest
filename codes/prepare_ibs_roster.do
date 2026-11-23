* ==============================================================================
* prepare_ibs_roster.do -- STANDALONE engine: IBS raw-material & product rosters
* ------------------------------------------------------------------------------
* WHAT THIS FILE IS
*   The IBS "Data Roster Produksi" comes as two LONG files per year:
*     Bahanbaku{YYYY} : one row = firm x raw material   (inputs)
*     Proman{YYYY}    : one row = firm x product        (outputs)
*   This file harmonises them across years into two tidy long tables:
*     data/raw/ibs_input_long.dta    key: fid year line
*     data/raw/ibs_output_long.dta   key: fid year line
*   Both link to the firm panel built by prepare_ibs_panel.do with
*       merge m:1 fid year using "data/raw/firm_panel.dta"
*   No merged file is saved: each study pulls the firm variables it needs.
*
* WHAT IT DOES, IN ORDER
*   (1) harmonise   : apply the COLUMN MAP per file type and year, fix types,
*                     stack the years.
*   (2) units       : fill a missing unit name from its code (and the reverse).
*   (3) sanity check: LOUD stop if a core column came out empty.
*   (4) merge check : m:1 link to firm_panel.dta and a comparison of roster
*                     totals with the firm-level totals. Reported in the log only.
*
* HOW TO RUN
*   1. Edit the CONFIG block below (at least $root) for THIS machine.
*   2. Put the roster files in  data/raw/Data Roster Produksi/  (.xlsx or .dta).
*   3. Run prepare_ibs_panel.do first if you want the merge check (4).
*   4. Open Stata and run:  do "codes/prepare_ibs_roster.do"
*
* ##############################################################################
* #  For a NEW YEAR: add one block to the COLUMN MAP in Section 1 for each file #
* #  type. Nothing else changes if the columns keep the meaning they have now.  #
* ##############################################################################
* ==============================================================================

	capture log close
	clear all
	set more off
	set varabbrev off

* ===================================================================== *
* >>>>>>>>>>>>>>>>>>>>>>>>>>>   CONFIG   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< *
* ===================================================================== *

	*** (1) Project root = the ibstest folder on THIS computer.
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"

	*** (2) Year range to read (a year with no file is skipped).
		global year_start   2021
		global year_end     2022

	*** (3) Folder holding the roster files, and how the files are named:
	***        {stub}{YYYY}{suffix}.xlsx   e.g. Bahanbaku2021_sampel.xlsx
	***     On the REAL data set file_suffix to "" (or to whatever follows the year).
		global roster      "$root/data/raw/Data Roster Produksi"
		global in_stub     "Bahanbaku"
		global out_stub    "Proman"
		global file_suffix "_sampel"

	*** (4) Firm panel (from prepare_ibs_panel.do) used by the merge check.
	***     check_merge = 0 skips Section 4 entirely.
		global panel_file  "$root/data/raw/firm_panel.dta"
		global check_merge 1

* ===================================================================== *
* -----------------   Folders and run log   --------------------------- *
* ===================================================================== *
	global out "$root/data/raw"         // inside raw/ -> gitignored, stays with the data
	capture mkdir "$root/data"
	capture mkdir "$out"

	local _d = subinstr("`c(current_date)'", " ", "_", .)
	local _t = subinstr("`c(current_time)'", ":", "",  .)
	log using "$root/prepare_ibs_roster_`_d'_`_t'.log", replace text

* ===================================================================== *
* -----------   (1) Harmonise each file and append   ----------------- *
* ===================================================================== *
*   Standard columns (every other raw column is dropped):
*     both    : fid idscheme year line prov kab item_name kbki kbki_name
*               unit_code unit_name isic5_roster flag
*     input   : q_dom v_dom q_imp v_imp v_total uv_dom uv_imp
*               origin_code origin_name origin_other
*     output  : q v uv export_share dest_code dest_name dest_other isic5_product

	local targets fid prov kab item_name kbki kbki_name unit_code unit_name   ///
	              q_dom v_dom q_imp v_imp v_raw_total                          ///
	              origin_code origin_name origin_other                         ///
	              q v export_share dest_code dest_name dest_other              ///
	              isic5_roster isic5_product flag

	local str_input  fid kab item_name kbki kbki_name unit_name origin_name origin_other flag
	local num_input  prov unit_code q_dom v_dom q_imp v_imp v_raw_total origin_code isic5_roster
	local str_output fid kab item_name kbki kbki_name unit_name dest_name dest_other flag
	local num_output prov unit_code q v export_share dest_code isic5_roster isic5_product

	tempfile long_input long_output

	foreach kind in input output {

		if "`kind'" == "input"  local stub "$in_stub"
		if "`kind'" == "output" local stub "$out_stub"

		clear
		save `long_`kind'', emptyok replace
		local n_`kind' = 0

		forvalues yr = $year_start/$year_end {

			* read the year's file: .xlsx if present, otherwise .dta, otherwise skip
			local f "$roster/`stub'`yr'$file_suffix"
			capture confirm file "`f'.xlsx"
			if !_rc {
				import excel "`f'.xlsx", firstrow clear
			}
			else {
				capture confirm file "`f'.dta"
				if _rc {
					display as text "   (skip `kind' `yr': no file `stub'`yr'$file_suffix)"
					continue
				}
				use "`f'.dta", clear
			}
			display as text "Cleaning `kind' `yr' ..."

			foreach v of varlist * {
				local low = strlower("`v'")
				if "`low'" != "`v'" capture rename `v' `low'
			}
			gen long _ord = _n               // original row order, used for "line"

			* ================================================================ *
			* >>>>>>>>>>>>>>  COLUMN MAP  (edit here for a new year)  <<<<<<<<< *
			*   c_<standard name> = the raw column(s) feeding it, lower-case.   *
			*   Several candidates may be listed; the first one found is used.  *
			*   A trailing * matches the rest of a long name: import excel      *
			*   squeezes "B3R307_K4 (Banyaknya BB Lokal)" into one long word.   *
			*   Leave a standard name out if the file does not have it.         *
			* ================================================================ *
			foreach t of local targets {
				local c_`t' ""
			}
			local mapped = 0
			local c_fid  "kipb kip psid"
			local c_prov "prop"
			local c_kab  "kab kabu"

			if "`kind'" == "input" & `yr' == 2021 {
				local mapped = 1
				local c_item_name    "komoditi"
				local c_kbki         "kodekbki"
				local c_kbki_name    "deskbki"
				local c_unit_code    "kodesat"
				local c_unit_name    "satuan"
				local c_q_dom        "volok21"
				local c_v_dom        "nilok21"
				local c_q_imp        "volim21"
				local c_v_imp        "nilim21"
				local c_origin_code  "kodeneg"
				local c_origin_name  "desneg"
				local c_origin_other "desnegla"
				local c_isic5_roster "kbli5"
				local c_flag         "flg21"
			}
			if "`kind'" == "input" & `yr' == 2022 {
				local mapped = 1
				local c_item_name    "b3r307_k2*"
				local c_kbki         "kodekbki"
				local c_kbki_name    "desind"
				local c_unit_code    "satuan"        // 2022: "satuan" holds the CODE
				local c_unit_name    "satuan_desk"
				local c_q_dom        "b3r307_k4*"
				local c_v_dom        "b3r307_k5*"
				local c_q_imp        "b3r307_k6*"
				local c_v_imp        "b3r307_k7*"
				local c_v_raw_total  "totalnilai*"
				local c_origin_code  "b3r307_k8n*"
				local c_origin_name  "negarautama*"
				local c_origin_other "b3r307_k8_l*"
				local c_isic5_roster "kbli522"
			}
			if "`kind'" == "output" & `yr' == 2021 {
				local mapped = 1
				local c_item_name     "komoditi"
				local c_kbki          "kodkbki"
				local c_kbki_name     "deskbki"
				local c_unit_code     "kodesat"
				local c_unit_name     "satuan"
				local c_q             "volume"
				local c_v             "nilai"
				local c_export_share  "prprex"
				local c_dest_code     "kodeneg"
				local c_dest_name     "namaneg"
				local c_dest_other    "kneglain"
				local c_isic5_roster  "kbli"
				local c_isic5_product "kbli5kom"
				local c_flag          "flg21"
			}
			if "`kind'" == "output" & `yr' == 2022 {
				local mapped = 1
				local c_item_name     "komoditi"
				local c_kbki          "kodekbki"
				local c_kbki_name     "kbkidesk"
				local c_unit_code     "kodesat"
				local c_unit_name     "satuan"
				local c_q             "volpro22"
				local c_v             "nilpro22"
				local c_export_share  "ekspor"
				local c_dest_code     "kodeneg"
				local c_dest_name     "negara"
				local c_dest_other    "neglain"
				local c_isic5_roster  "kbli522"
				local c_flag          "flagpr22"
			}
			if `mapped' == 0 {
				display as error "!! no COLUMN MAP for `kind' `yr' -> file skipped. Add a block above."
				continue
			}

			* copy each mapped source into a scratch column, drop everything else,
			* then give the scratch columns their standard names. Going through
			* scratch names means a raw column can never collide with a standard name.
			local scheme ""
			local i = 0
			foreach t of local targets {
				local ++i
				local found ""
				foreach cand of local c_`t' {
					if "`found'" == "" {
						capture unab hit : `cand'
						if !_rc local found : word 1 of `hit'
					}
				}
				if "`found'" != "" {
					clonevar __t`i' = `found'
					if "`t'" == "fid" local scheme "`found'"
				}
			}
			keep __t* _ord
			local i = 0
			foreach t of local targets {
				local ++i
				capture rename __t`i' `t'
			}

			* one storage type per column across years: text stays text, codes and
			* amounts become numbers. kbki is TEXT so a leading zero survives; if a
			* file stores it as a number it is rebuilt as a 10-digit string.
			foreach x of local str_`kind' {
				capture confirm variable `x'
				if _rc gen str1 `x' = ""
				capture confirm string variable `x'
				if _rc {
					if "`x'" == "kbki" tostring kbki, replace force format(%010.0f)
					else               tostring `x',  replace force
					replace `x' = "" if `x' == "."
				}
				replace `x' = strtrim(`x')
			}
			foreach x of local num_`kind' {
				capture confirm variable `x'
				if _rc gen double `x' = .
				destring `x', replace force      // not quiet: the log shows any text lost
			}
			replace flag = strupper(flag)

			gen str8 idscheme = "`scheme'"
			gen int  year     = `yr'
			bysort fid year (_ord): gen long line = _n
			drop _ord

			* derived columns, defined the same way in every year
			if "`kind'" == "input" {
				egen double v_total = rowtotal(v_dom v_imp), missing
				quietly count if !missing(v_raw_total) & abs(v_raw_total - v_total) > 0.5
				if r(N) > 0 display as error "!! `yr': " r(N) " rows where the file's own total differs from v_dom + v_imp."
				drop v_raw_total
				gen double uv_dom = v_dom / q_dom if q_dom > 0 & q_dom < .
				gen double uv_imp = v_imp / q_imp if q_imp > 0 & q_imp < .
			}
			else {
				gen double uv = v / q if q > 0 & q < .
				quietly count if (export_share < 0 | export_share > 100) & export_share < .
				if r(N) > 0 display as error "!! `yr': " r(N) " rows with export_share outside 0-100 (left as is)."
			}

			quietly count
			local n_`kind' = `n_`kind'' + r(N)
			append using `long_`kind''
			save `long_`kind'', replace
		}
	}

	if `n_input' == 0 & `n_output' == 0 {
		display as error "STOP: no roster file was read. Check \$roster, the stubs and \$file_suffix in CONFIG."
		capture log close
		exit 601
	}

* ===================================================================== *
* -----------   (2) Units: fill name from code and code from name   --- *
* ===================================================================== *
*   Some files carry only the unit code, some rows only the unit name. The
*   lookup is the most frequent name per code over ALL rows read. A code is
*   filled from a name only when that name belongs to exactly one code.
*   unit_filled = 1 marks every row touched here.

	use `long_input', clear
	append using `long_output'
	keep unit_code unit_name
	keep if !missing(unit_code) & unit_name != ""
	quietly count
	local have_lu = r(N) > 0
	if `have_lu' {
		contract unit_code unit_name
		bysort unit_code: gen byte _amb = (_n == 1 & _N > 1)
		quietly count if _amb
		if r(N) > 0 display as error "!! " r(N) " unit codes carry more than one name; the most frequent name is used."
		bysort unit_code (_freq unit_name): keep if _n == _N
		keep unit_code unit_name
		rename unit_name unit_name_lu
		tempfile ulu
		save `ulu'
		bysort unit_name_lu: keep if _N == 1
		rename (unit_code unit_name_lu) (unit_code_lu unit_name)
		tempfile ulu_inv
		save `ulu_inv'
	}

	foreach kind in input output {
		if `n_`kind'' == 0 continue
		use `long_`kind'', clear
		gen byte unit_filled = 0
		if `have_lu' {
			merge m:1 unit_code using `ulu', keep(master match) nogen
			replace unit_filled = 1         if unit_name == "" & unit_name_lu != ""
			replace unit_name = unit_name_lu if unit_name == "" & unit_name_lu != ""
			drop unit_name_lu
			merge m:1 unit_name using `ulu_inv', keep(master match) nogen
			replace unit_filled = 1         if missing(unit_code) & !missing(unit_code_lu)
			replace unit_code = unit_code_lu if missing(unit_code)
			drop unit_code_lu
		}

		label var fid          "Firm identifier (same as firm_panel)"
		label var idscheme     "Raw name of the id column"
		label var year         "Year"
		label var line         "Row number within firm-year (file order)"
		label var prov         "Province code"
		label var kab          "Regency code"
		label var item_name    "Commodity name as reported (free text)"
		label var kbki         "KBKI commodity code (text)"
		label var kbki_name    "KBKI description"
		label var unit_code    "Unit code"
		label var unit_name    "Unit name"
		label var unit_filled  "1 = unit code or name filled from the lookup"
		label var isic5_roster "KBLI 5-digit as carried by the roster file"
		label var flag         "Roster flag as reported (R/N)"
		if "`kind'" == "input" {
			label var q_dom        "Quantity, domestic"
			label var v_dom        "Value, domestic (nominal)"
			label var q_imp        "Quantity, imported"
			label var v_imp        "Value, imported (nominal)"
			label var v_total      "Value, domestic + imported (nominal)"
			label var uv_dom       "Unit value, domestic = v_dom / q_dom"
			label var uv_imp       "Unit value, imported = v_imp / q_imp"
			label var origin_code  "Main origin country code"
			label var origin_name  "Main origin country name"
			label var origin_other "Other origin country"
			order fid idscheme year line prov kab isic5_roster item_name kbki kbki_name     ///
			      unit_code unit_name unit_filled q_dom v_dom q_imp v_imp v_total           ///
			      uv_dom uv_imp origin_code origin_name origin_other flag
		}
		else {
			label var q             "Quantity produced"
			label var v             "Value produced (nominal)"
			label var uv            "Unit value = v / q"
			label var export_share  "Share exported (%)"
			label var dest_code     "Main destination country code"
			label var dest_name     "Main destination country name"
			label var dest_other    "Other destination country"
			label var isic5_product "KBLI 5-digit of the product"
			order fid idscheme year line prov kab isic5_roster isic5_product item_name      ///
			      kbki kbki_name unit_code unit_name unit_filled q v uv export_share        ///
			      dest_code dest_name dest_other flag
		}
		sort fid year line
		compress
		save "$out/ibs_`kind'_long.dta", replace
		display as result "== saved: $out/ibs_`kind'_long.dta =="
		tab year
	}

* ===================================================================== *
* -----------   (3) SANITY CHECK: shout on a name mismatch   --------- *
* ===================================================================== *
*   A source column whose raw name differs from the COLUMN MAP is not an
*   error above -- it just comes out empty. This block names every core
*   column that is empty in a year and stops the run.

	display as text "{hline 72}"
	display as text "SANITY CHECK (column map)"
	display as text "{hline 72}"
	local problems = 0
	foreach kind in input output {
		if `n_`kind'' == 0 {
			display as error "!! no `kind' rows were read at all."
			local problems = `problems' + 1
			continue
		}
		use "$out/ibs_`kind'_long.dta", clear
		if "`kind'" == "input"  local value "v_total"
		if "`kind'" == "output" local value "v"
		levelsof year, local(yrs)
		foreach y of local yrs {
			foreach c in fid item_name kbki {
				quietly count if year == `y' & `c' != ""
				if r(N) == 0 {
					display as error "!! `kind' `y': '`c'' is EMPTY -> its raw name may differ in that file."
					local problems = `problems' + 1
				}
			}
			quietly count if year == `y' & !missing(`value')
			if r(N) == 0 {
				display as error "!! `kind' `y': '`value'' is EMPTY -> its raw name may differ in that file."
				local problems = `problems' + 1
			}
		}
	}
	if `problems' > 0 {
		display as error "{hline 72}"
		display as error "STOP: SANITY CHECK found `problems' problem(s) listed above."
		display as error "Fix the COLUMN MAP in Section 1, then run again."
		display as error "{hline 72}"
		capture log close
		exit 459
	}
	display as result "SANITY CHECK ok: id, name, code and value present for every year."
	display as text "{hline 72}"

* ===================================================================== *
* -----------   (4) MERGE CHECK against the firm panel   ------------- *
* ===================================================================== *
*   Links each roster to firm_panel.dta on fid + year and reports
*     - how many firm-years appear in the roster only, the panel only, both;
*     - roster totals against the firm-level totals of the main questionnaire:
*         sum(v_dom) vs rdnvcu, sum(v_imp) vs rimvcu, sum(v) vs yprvcu.
*       A median ratio near 1000 or 0.001 means the two files use different
*       money units.
*   Nothing is saved. The step is skipped (with a note) when the panel is
*   missing or when fid + year does not identify a firm in it, as on the
*   sample where the id is masked.

	if $check_merge == 1 {
		display as text "{hline 72}"
		display as text "MERGE CHECK (roster -> firm panel, m:1 on fid year)"
		display as text "{hline 72}"
		capture confirm file "$panel_file"
		if _rc {
			display as error "!! firm panel not found: $panel_file -> merge check skipped."
			display as error "   Run prepare_ibs_panel.do first."
		}
		else {
			use "$panel_file", clear
			local firmvars ""
			foreach v in rdnvcu rimvcu yprvcu {
				capture confirm numeric variable `v'
				if !_rc local firmvars `firmvars' `v'
			}
			keep fid year `firmvars'
			keep if inrange(year, $year_start, $year_end)
			bysort fid year: gen long _copies = _N
			quietly count if _copies > 1
			local n_dup = r(N)
			quietly count
			if r(N) == 0 {
				display as error "!! the firm panel has no rows for $year_start-$year_end -> merge check skipped."
			}
			else if `n_dup' > 0 {
				display as error "!! fid + year is NOT unique in the firm panel (`n_dup' rows share a key)."
				display as error "   An m:1 merge is impossible on this data (masked id?) -> merge check skipped."
			}
			else {
				drop _copies
				tempfile firm
				save `firm'

				foreach kind in input output {
					if `n_`kind'' == 0 continue
					use "$out/ibs_`kind'_long.dta", clear
					if "`kind'" == "input" {
						collapse (sum) s_dom = v_dom s_imp = v_imp (count) n_lines = line, by(fid year)
						local pairs "s_dom:rdnvcu s_imp:rimvcu"
					}
					else {
						collapse (sum) s_out = v (count) n_lines = line, by(fid year)
						local pairs "s_out:yprvcu"
					}
					merge 1:1 fid year using `firm'
					label define _mlab 1 "roster only" 2 "panel only" 3 "both", replace
					label values _merge _mlab
					display as text _n "-- `kind': firm-years by link status --"
					tab year _merge

					foreach p of local pairs {
						gettoken s f : p, parse(":")
						local f = substr("`f'", 2, .)
						capture confirm variable `f'
						if _rc {
							display as text "   (`f' not in the firm panel -> total not compared)"
							continue
						}
						quietly gen double _r = `s' / `f' if _merge == 3 & `f' > 0 & `f' < .
						quietly count if !missing(_r)
						local n = r(N)
						if `n' == 0 {
							display as text "   `s' vs `f': no firm-year to compare"
						}
						else {
							quietly count if abs(_r - 1) <= 0.01
							local ok = r(N)
							quietly summarize _r, detail
							display as result "   `s' vs `f': `n' firm-years, "   ///
								%5.1f 100 * `ok' / `n' "% within 1%, median ratio " %9.4g r(p50)
						}
						drop _r
					}
				}
			}
		}
		display as text "{hline 72}"
	}

	capture log close
