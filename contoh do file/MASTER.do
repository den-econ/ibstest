* ==============================================================================
*
* Project			: Estimating Living Wage (KHL) 2024 
* Description		: Master Do File for KHL 2024
* Stata version  	: 16 
* Date created		: October 30, 2025 - by Bertha
* Last modified  	: October 30, 2025 - by Bertha
*
* ==============================================================================

	capture: 	log close
	clear 		all
	set more 	off

**# Set file paths 
	
	* Note: please update the information in "SET_FILEPATHS.do" first before running "MASTER.do" 	
	if "`c(username)'" == "meizahra" { 																// change username
        do "/Users/meizahra/Documents/work/National Economic Council (NEC)/UMP/KHL/Do File Analysis/KHL Direct Estimate Kabkot/SET_FILEPATHS.do"	// change path for "SET_FILEPATHS.do"
    } 

* ===================================================================== *
* -------------------           Setup              -------------------- *
* ===================================================================== * 
	
	*** (1) Set year 
		gl  year        	= 2025

	*** (2) Set quintile reference (national)
		** 	a) Indicate if quintile is fixed at national level (1 or 0)
			gl 	q_fixed 	= 1
		** 	b) If yes, set the quintile reference
			gl  quintile 	= 4

	*** (3) Set reference calorie
		gl  cal_optimal	 	= 2150		

	*** (4) Set numbers to estimate KHL 
		gl  hh_size			= 4 		// Set household size (national average HH size is 4)
		gl  adult_equiv 	= 2.96 		// Set OECD adult equivalent scale (national average is 2.96)
		gl  work_adults 	= 1.4 		// # of full time working adults in HH of 4 is 1.4 (national average)

* ===================================================================== *
* -----------------     	    Triggers              ----------------- *
* ===================================================================== * 

**# Preparation 
	loc 1a_assumptions						1
	loc 1b_expenditure_quintile 			1
	loc 1c_housing_score					1

**# KHL Estimation
	* Non-Food 
	loc 2a_non_food_basket					0
	loc 2b_non_food_expenditure 			0
	* Food  
	loc 2c_food_basket 						0
	loc 2d_reference_quintile				0  	// should always be set to 1
	loc 2e_food_expenditure 				0 	// should always be set to 1
	* Aggregate 
	loc 2f_living_wage 						0 	// should always be set to 1

**# KHL Analysis
	loc 3a_khl_analysis  					0


* ===================================================================== *
* -----------------     	    Do-files              ----------------- *
* ===================================================================== * 

display c(current_time)
timer on 1

**# Preparation 

	if 	`1a_assumptions' == 1 	{
		do 	"$dofile/1a_assumptions.do"
	}
	if 	`1b_expenditure_quintile' == 1 	{
		do 	"$dofile/1b_expenditure_quintile.do"
	}
	if 	`1c_housing_score' == 1 	{
		do 	"$dofile/1c_housing_score.do"
	}


**# KHL Estimation

	* Non-Food 	
	if 	`2a_non_food_basket' == 1 	{
		do 	"$dofile/2a_non_food_basket.do"
	}
	if 	`2b_non_food_expenditure' == 1 	{
		do 	"$dofile/2b_non_food_expenditure.do"
	}

	* Food
	if 	`2c_food_basket' == 1 	{
		do 	"$dofile/2c_food_basket.do"
	}
	if 	`2d_reference_quintile' == 1 	{
		do 	"$dofile/2d_reference_quintile.do"
	}
	if 	`2e_food_expenditure' == 1 	{
		do 	"$dofile/2e_food_expenditure.do"
	}
	* Combined 
	if 	`2f_living_wage' == 1 	{
		do 	"$dofile/2f_living_wage.do"
	}


**# KHL Analysis

	if 	`3a_khl_analysis' == 1 	{
		do 	"$dofile/3a_khl_analysis.do"
	}


timer off 1
timer list
scalar elapsed_seconds = r(t1)
scalar elapsed_minutes = elapsed_seconds / 60
display "Elapsed time: " round(elapsed_minutes, 0.01) " minutes"
