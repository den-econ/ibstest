* ==============================================================================
* imk_1_prepare.do -- SECTION 1 (IMK): clean & harmonize every year -> imk_firm.dta
* ------------------------------------------------------------------------------
* WHAT THIS FILE DOES (in plain words):
*   The IMK (VIMK) survey renames its columns EVERY year, so the same quantity
*   hides behind a different code each year. This file reads all nine yearly
*   files and copies each year's columns onto FOUR tidy, standard variables so
*   the rest of the pipeline never has to care about the yearly code names:
*       emp    = total workers (incl. the owner), 1-19     [BPS micro/small range]
*       output = total business revenue  (pendapatan usaha, rupiah)
*       wage   = total labour compensation (balas jasa, rupiah)
*                NOTE: this is 0 for most firms -- IMK firms are mostly unpaid
*                family businesses, so a 0 here is real, not a missing value.
*       input  = raw material + fuel cost (rupiah)
*   It also builds kbli5/kbli2 (the industry code), a size class (Micro/Small),
*   and two broad sector groupings (secgroupA, secgroupB).
*
* ##############################################################################
* #  PLUG-AND-PLAY: the ONLY thing to edit for real data is the COLUMN MAP      #
* #  block below (one line per year). If BPS keeps the same column names in the #
* #  real files, nothing here changes. Just drop the real VIMK{YY}.dta files    #
* #  into the $raw_imk folder and run.                                          #
* ##############################################################################
*
* INPUT  : $raw_imk/VIMK{17..25}.dta   (produced by convert_imk_dta.do)
* OUTPUT : $data/imk_firm.dta          (one row per firm, harmonized, all years)
* HOW TO RUN: normally called by imk_MASTER.do (Section 1).
* ==============================================================================

	display as text "== IMK 1: prepare & harmonize (2017-2025) =="

* --- Start an empty "panel" that we will add each year's rows to ---------------
*   tempfile = a scratch file deleted automatically at the end of the run.
*   emptyok  = allow saving even though there is no data in memory yet.
	clear
	tempfile panel
	save `panel', emptyok replace

* "local" = a name that holds a value only until this do-file finishes.
	local years 17 18 19 20 21 22 23 24 25

* --- Loop over the years. `y' is the current two-digit year inside the loop ----
	foreach y of local years {
		display as text "  -- 20`y' --"

		* Skip a year whose file is not present ("capture confirm file" sets the
		* error code _rc; "if _rc" means the file was not found).
		capture confirm file "$raw_imk/VIMK`y'.dta"
		if _rc {
			display as text "     (skip 20`y': VIMK`y'.dta not found)"
			continue                 // jump straight to the next year
		}
		use "$raw_imk/VIMK`y'.dta", clear

		* ==================================================================== *
		* >>>>>>>>>>>>>>>>  COLUMN MAP  (edit here for real data)  <<<<<<<<<<<< *
		*   For each year we record which raw column feeds each standard var:   *
		*     kblicol  = the KBLI 5-digit industry code column                  *
		*     empsrc   = worker-count column                                    *
		*     outputsrc= revenue column                                         *
		*     wagesrc  = wage column(s)                                         *
		*     inputsrc = material/fuel column(s)                                *
		*   A source may list SEVERAL columns separated by spaces; those get    *
		*   added together further below.                                       *
		* ==================================================================== *
		if "`y'" == "17" {
			local kblicol b2_2052
			local empsrc  b4_402a_6
			local outputsrc  b6_604_5
			local wagesrc b4_403a_4 b4_403b_4 b4_403c_4
			local inputsrc  b5_501_4 b5_502_4
		}
		else if "`y'" == "18" {
			local kblicol b2_2052
			local empsrc  b4_402a_6
			local outputsrc  b6_604_5
			local wagesrc b4_403d_4
			local inputsrc  b5_501u_5 b5_502a_5
		}
		else if "`y'" == "19" {
			local kblicol b2_2042
			local empsrc  b3_301a_last
			local outputsrc  b5_504_5
			local wagesrc b3_303d_4
			local inputsrc  b4_401u_5 b4_402a_5
		}
		else if "`y'" == "20" {
			local kblicol r204b
			local empsrc  r401aklast
			local outputsrc  r504
			local wagesrc r403dk4
			local inputsrc  r601uk6 r602ak5
		}
		else if "`y'" == "21" {
			local kblicol r204b
			local empsrc  r401aklast
			local outputsrc  r504
			local wagesrc r403dk4
			local inputsrc  r601uk6 r602ak5
		}
		else if "`y'" == "22" {
			local kblicol r204b
			local empsrc  r401aklast
			local outputsrc  r504k6
			local wagesrc r403dk4
			local inputsrc  r601vk6 r602ak5
		}
		else if "`y'" == "23" {
			local kblicol r205
			local empsrc  r401aklast
			local outputsrc  r504k6
			local wagesrc r403dk4
			local inputsrc  r601jk6 r602ak5
		}
		else if "`y'" == "24" {
			local kblicol r205
			local empsrc  r402ak4
			local outputsrc  r503k5
			local wagesrc r403dk2
			local inputsrc  r601nk6
		}
		else if "`y'" == "25" {
			local kblicol r205_label
			local empsrc  r402a
			local outputsrc  r503
			local wagesrc r403d
			local inputsrc  r601_jumlah
		}
		* ==================================================================== *

		* --- Industry code: make kbli5 numeric, then derive the 2-digit kbli2 -
		*   If the raw code is already numeric we copy it; otherwise "destring"
		*   converts the text code to a number ("force" blanks non-numeric junk).
		capture confirm numeric variable `kblicol'
		if _rc destring `kblicol', gen(kbli5) force
		else   gen double kbli5 = `kblicol'
		gen kbli2 = floor(kbli5/1000)              // first two digits of the code
		keep if kbli2 >= 10 & kbli2 <= 33          // keep manufacturing only

		* --- Build the four standard variables, guarding missing columns ------
		*   We loop over the four target names. For each one we need the list of
		*   source columns stored in the matching local (empsrc, outputsrc, ...).
		foreach t in emp output wage input {
			* NESTED-MACRO TRICK -- do NOT change this line.
			* `t' is the target name, e.g. emp. We want the CONTENTS of the local
			* called `empsrc'. Writing `t'src builds the text "empsrc", and the
			* extra backticks ``...'' then expand THAT local. So `src' ends up
			* holding, for emp, exactly what empsrc holds. Same idea for output,
			* wage, input.
			local src ``t'src'
			local have ""                          // will collect the columns that exist
			foreach c of local src {
				capture confirm variable `c'
				if !_rc {
					* column exists: make sure it is numeric, then keep it
					capture confirm numeric variable `c'
					if _rc destring `c', replace force
					local have "`have' `c'"
				}
				else display as error "     20`y': source column `c' not found (`t')"
			}
			if "`have'" == "" {
				* none of the listed columns exist this year -> set the target missing
				gen double `t' = .
				display as error "     20`y': NO source for `t' -> set missing"
			}
			else {
				* "egen ... rowtotal" adds the kept columns across each row. The
				* "missing" option keeps the result missing when ALL inputs are
				* missing (rather than turning it into 0).
				egen double `t' = rowtotal(`have'), missing
			}
		}

		* Wage is genuinely empty for unpaid family firms, so treat blank as 0.
		replace wage = 0 if missing(wage)

		* --- Size class using the BPS worker-count definition -----------------
		gen byte sizeclass = .
		replace sizeclass = 1 if emp >= 1 & emp <= $imk_micro_max        // Micro 1-4
		replace sizeclass = 2 if emp > $imk_micro_max & emp <= 19         // Small 5-19
		label define szc 1 "Micro (1-4)" 2 "Small (5-19)", replace
		label values sizeclass szc

		* --- Broad sector groups (two alternative ways to bucket industries) --
		*   "inlist(x, a, b, ...)" is true when x equals any value in the list.
		*   A = end-use buckets (5 groups).
		gen byte secgroupA = .
		replace secgroupA = 1 if inlist(kbli2,10,11,12)
		replace secgroupA = 2 if inlist(kbli2,13,14,15)
		replace secgroupA = 3 if inlist(kbli2,16,17,18,31)
		replace secgroupA = 4 if inlist(kbli2,19,20,21,22,23,24,25) | inlist(kbli2,26,27,28,29,30)
		replace secgroupA = 5 if inlist(kbli2,32,33)

		*   B = factor-intensity buckets (4 groups, Aswicahyono-style).
		gen byte secgroupB = .
		replace secgroupB = 1 if inlist(kbli2,10,11,12,16,17,23,24)
		replace secgroupB = 2 if inlist(kbli2,13,14,15,18,31,32)
		replace secgroupB = 3 if inlist(kbli2,19,20,21,22,25) | inlist(kbli2,28,29,30,33)
		replace secgroupB = 4 if inlist(kbli2,26,27)

		gen int year = 2000 + `y'                  // 17 -> 2017, etc.

		* --- Keep only the harmonized columns (the raw ones stay in VIMK`y'.dta)
		*   Keep pmid too if it exists (so a firm can be identified within a year).
		capture confirm variable pmid
		if !_rc keep pmid year kbli5 kbli2 emp output wage input sizeclass secgroupA secgroupB
		else    keep       year kbli5 kbli2 emp output wage input sizeclass secgroupA secgroupB

		* Stack this year's rows under the years already processed, then save.
		append using `panel'
		save `panel', replace
	}

* --- All years stacked: add labels and save the final firm-level dataset -------
	use `panel', clear
	label var emp    "Total workers (1-19)"
	label var output "Business revenue (Rp)"
	label var wage   "Labour compensation (Rp, 0 if unpaid)"
	label var input  "Material + fuel cost (Rp)"
	label var kbli2  "KBLI 2-digit industry"
	label define secA 1 "Food & bev" 2 "Textiles" 3 "Wood & furniture" ///
	                  4 "Chem/metal/mach" 5 "Other manuf", replace
	label define secB 1 "Resource-based" 2 "Labour-intensive" ///
	                  3 "Capital/footloose" 4 "Electronics", replace
	label values secgroupA secA
	label values secgroupB secB
	label var secgroupA "Sector group A (end-use, 5)"
	label var secgroupB "Sector group B (factor intensity, 4)"
	order year kbli2 kbli5 secgroupA secgroupB emp output wage input sizeclass
	compress                                       // shrink storage types to save space
	save "$data/imk_firm.dta", replace

	display as result "   -> imk_firm.dta"
	tab year                                       // quick check: rows per year
