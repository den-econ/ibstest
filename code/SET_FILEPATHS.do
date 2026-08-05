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

* --- (1) Determine the project root --------------------------------------------
	global root "`c(pwd)'"

* --- (2) MANUAL OVERRIDE (optional) --------------------------------------------
*   Uncomment the line below and fill in the repo path if needed.
*   global root "D:/path/to/ibstest"

* --- (3) Sub-folders (relative to $root) ---------------------------------------
	global code   "$root/code"          // do-files
	global data   "$root/data"          // processed panel
	global raw    "$root/data/raw"      // raw BPS microdata (mfgYYYY.dta)
	global reg    "$root/reg"           // table output (.csv)
	global fig    "$root/fig"           // figure output (.png)

* --- (4) Quick check so a wrong path is caught early ---------------------------
	capture confirm file "$raw"
	if _rc {
		display as error "!! raw folder not found: $raw"
		display as error "   Make sure Stata is opened in the repo folder, or set \$root manually."
	}

	display as result "Project paths:"
	display "  root = $root"
	display "  raw  = $raw"
