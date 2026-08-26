* ==============================================================================
* SET_FILEPATHS.do
* ------------------------------------------------------------------------------
* Sets the folder locations for the whole pipeline.
*
* GOAL: plug-and-play across machines. By default, the project "root" is taken
* from the folder where Stata is running (c(pwd)). So you just:
*     - put this whole repo on any machine,
*     - open Stata IN the repo folder (or cd into it),
*     - run MASTER.do.
* No need to edit paths per machine.
*
* If on another machine you CANNOT open Stata in the repo folder, simply set
* $root manually in the "MANUAL OVERRIDE" block below.
* ==============================================================================

* --- (1) Project root ----------------------------------------------------------
*   Normally $root is already set by MASTER.do. If you run THIS file on its own,
*   it falls back to the path below -> edit it for your machine.
	if "$root" == "" {
		global root "/Users/meizahra/Documents/work/National Economic Council (NEC)/ibstest"
	}

* --- (3) Sub-folders (relative to $root) ---------------------------------------
	global code   "$root/code"          // do-files
	global data   "$root/data"          // processed panel
	global raw    "$root/data/raw"      // raw BPS microdata (mfgYYYY.dta)
	global output "$root/output"        // ALL results here (tables .csv + figures .png)
	global reg    "$output"             // tables  -> output/
	global fig    "$output"             // figures -> output/
	capture mkdir "$output"

* --- (4) Quick check so a wrong path is caught early ---------------------------
	capture confirm file "$raw"
	if _rc {
		display as error "!! raw folder not found: $raw"
		display as error "   Make sure Stata is opened in the repo folder, or set \$root manually."
	}

	display as result "Project paths:"
	display "  root = $root"
	display "  raw  = $raw"
