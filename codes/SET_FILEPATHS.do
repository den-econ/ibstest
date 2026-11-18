* ==============================================================================
* SET_FILEPATHS.do -- one place that defines every folder the pipeline uses
* ------------------------------------------------------------------------------
* WHAT THIS DOES
*   Creates the "global macros" (project-wide name tags, written as $name) that
*   point to each folder: the code, the data, the raw microdata, and the output.
*   Every other do-file then refers to e.g. $data instead of a long path, so you
*   only ever edit the paths here.
*
* HOW IT IS RUN
*   MASTER.do / imk_MASTER.do call this automatically. You can also run it on its
*   own; if so, it fills in $root from the fallback path below -- edit that line
*   for your machine.
* ==============================================================================

* --- (1) Project root ----------------------------------------------------------
*   $root is the top folder of the project. MASTER.do normally sets it already.
*   If it is still empty (you ran this file by itself), use the path below.
*   ("global name value" stores value under $name for the rest of the session.)
	if "$root" == "" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}

* --- (2) The analysis project "scarring_industry" (a SIBLING of this repo) ------
*   The analysis do-files (2a-2e, imk_2a-2e, render_sankey) live in a SEPARATE
*   folder next to this repo -- NOT inside it, under scarring_industry/codes/.
*   We locate the sibling by taking $root's PARENT folder and adding the name.
*   ustrregexra(s, pattern, "") erases the part of s that matches the pattern; here
*   "/[^/]+/?$" matches the final "/folder" piece, so erasing it leaves the parent.
	local _parent = ustrregexra("$root", "/[^/]+/?$", "")
	global scar_root "`_parent'/scarring_industry"      // the scarring project's root folder
	global code_scar "$scar_root/codes"                 // its do-files live in codes/
*   If this guess is ever wrong on your machine, set the full paths by hand instead:
*       global scar_root "/full/path/to/scarring_industry"
*       global code_scar "$scar_root/codes"

* --- (3) Sub-folders -----------------------------------------------------------
*   Engine code + data stay in THIS repo; analysis OUTPUT goes to the scarring project.
	global code   "$root/codes"             // engine do-files (master, prepare, shared) -- this repo
	global data   "$root/data"              // processed/analysis-ready data -- this repo
	global raw    "$root/data/raw"          // raw BPS microdata (mfgYYYY.dta)  [IBS]
	global output "$scar_root/output"       // IBS results -> scarring_industry/output/ (NOT in codes/)
	global reg    "$output"                 // tables  -> scarring_industry/output/
	global fig    "$output"                 // figures -> scarring_industry/output/
	capture mkdir "$scar_root"              // make the scarring project folder if it is missing
	capture mkdir "$output"                 // then its output subfolder ("capture" ignores "exists")

* --- (4) IMK (Industri Mikro & Kecil) folders ----------------------------------
*   Used by imk_MASTER.do and the imk_*.do files. Kept separate from IBS.
	global raw_imk    "$root/data/raw_imk_sampel"   // VIMK{YY}.dta (one row per firm)
	global output_imk "$scar_root/output_imk"       // IMK results -> scarring_industry/ (apart from IBS)
	global reg_imk    "$output_imk"
	global fig_imk    "$output_imk"
	capture mkdir "$output_imk"

* --- (5) Sanity check: warn early if the raw folder is missing ------------------
*   "confirm file" errors when the path does not exist; "capture" catches that
*   error and stores its code in _rc (0 = ok, non-zero = problem).
	capture confirm file "$raw"
	if _rc {
		display as error "!! raw folder not found: $raw"
		display as error "   Make sure Stata is opened in the repo folder, or set \$root manually."
	}

	display as result "Project paths:"
	display "  root = $root"
	display "  raw  = $raw"
