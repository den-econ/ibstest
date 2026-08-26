***********
*DATA PATH*
***********

gl user = c(username)

*Personal*
if "$user" == "reissaamaris"{
	gl path "/Users/reissaamaris/Dropbox/Prospera"
	}

*Work*
if "$user" == "Reissa Sugianto"{
	gl path "C:\Users\Reissa Sugianto\Dropbox\Prospera"
	}
	
global data "$path/Sakernas"
global do "$data/Sakernas August Do"

use "$data/sak2013_08", clear

drop year 
/*Preparing variables and adding value labels*/
renvars _all, lower
//rename weightbc weight
//rename URUTAN urutan

//gen age = umur	

/* Province/district Variable   */
// g 			prov 			= KODE_PROV	
g 			kab 			= city_kab_code_2007

/* Province/district Variable   */

tostring 	prov			, replace
tostring 	kab				, replace
		
replace 	kab 			= prov + kab 										if strlen(kab)==2
replace		kab 			= prov + "0" + kab 									if strlen(kab)==1

destring 	prov			, replace
destring 	kab				, replace

gen age_cohort = 0
replace age_cohort = 1 if age>=15 & age<=24
replace age_cohort = 2 if age>=25 & age<=34
replace age_cohort = 3 if age>=35 & age<=44
replace age_cohort = 4 if age>=45

la de age_lab  1 "15-24" 2 "25-34" 3 "35-44" 4 "45+"
la val age_cohort age_lab

tostring prov, replace
destring prov, replace

gen urban_rural = b1p05	
label define urban_rural_lab 1 "Urban" 2 "Rural"
label values urban_rural urban_rural_lab 
tab urban_rural [fw=weight] if age>=15

gen sex = jk 
label define sex_lab 1 "Male" 2 "Female"
label values sex sex_lab 
tab sex
tab sex [fw=weight] if age>=15
tab sex age_cohort [fw=weight] if age >=15

g female = sex == 2 
label define femalel 1 "Female" 0 "Male"
label values female femalel 

/* Number of HH member
gen n_hh = B2_R1 
gen n_hh_10plus = B2_R2 
gen n_hh_10below = n_hh - n_hh_10plus */

* Relationship with HH head
gen 	relationship = 1 if hub==1 
replace relationship = 2 if hub==2 
replace relationship = 3 if inrange(hub, 3, 4)
replace relationship = 4 if inrange(hub, 5, 9) 


gen reltohh=hub


#delimit
label define reltohh_lab
1 "Head of HH"
2 "Spouse"
3 "Child"
4 "Son/Daughter in Law"
5 "Grandkids"
6 "Parents/parents in law"
7 "Other fam"
8 "Maid/domestic helper"
9 "Other";
#d cr

label value reltohh reltohh_lab
tab reltohh [fw=weight] if age>=15
tab reltohh [fw=weight] if age>=15, missing

* Married
gen 	marital_status = 1 if statk==1 
replace marital_status = 2 if statk==2 
replace marital_status = 3 if inlist(statk, 3, 4)
la def ms 1 "Single" 2 "Married" 3 "Divorced/Widowed"
la val marital_status ms 
la var marital_status "Marital status"

gen marital= statk 
label define marital_lab 1 "Never Married" 2 "Married"  3 "Divorced" 4 "Widowed"
label values marital marital_lab
tab marital [fw=weight] if age>=15

gen school_status = sek 
label define school_status_lab 1 "Never been in school" 2 "Currently attending school" 3 "No longer in school"  
label values school_status school_status_lab
tab school, missing
tab school [fw=weight] if age>=15

* Highest education attainment for ICL
gen  	educ_icl = 0 if inlist(b5p1a, 1, 2)
replace educ_icl = 1 if inrange(b5p1a, 3, 4)
replace educ_icl = 2 if inrange(b5p1a, 5, 7)
replace educ_icl = 3 if inrange(b5p1a, 8, 10)
replace educ_icl = 4 if inlist(b5p1a, 11, 12)
replace educ_icl = 5 if b5p1a==13
replace educ_icl = 6 if b5p1a==14
la def edx 	0 "No schooling" 1 "Up to primary school" ///
			2 "Lower secondary school" ///
			3 "Upper secondary school" 4 "DI/DII/DIII" 5 "DIV/Bachelor" ///
			6 "Master's/PhD"
la val educ_icl edx 

* Detailed highest education attainment
gen  	educ_det = 1 if inrange(b5p1a, 1, 4)
replace educ_det = 2 if inrange(b5p1a, 5, 7)
replace educ_det = 3 if inlist(b5p1a, 8, 10)
replace educ_det = 4 if inlist(b5p1a, 9)
replace educ_det = 5 if inlist(b5p1a, 11, 12)
replace educ_det = 6 if inlist(b5p1a, 13, 14)
la def edx_det 1 "Up to primary school" 2 "Lower secondary school" ///
		   3 "General high school" 4 "Vocational high school" ///
		   5 "Diploma" 6 "University" 
la val educ_det edx_det 


gen educ = .							
replace educ = 1 if inrange(b5p1a, 1, 4)			
replace educ = 2 if inrange(b5p1a, 5, 7)	
replace educ = 3 if inlist(b5p1a, 8, 10)	
replace educ = 4 if inlist(b5p1a, 9)	
replace educ = 5 if inrange(b5p1a, 11, 14)

#delimit
label define educ_lab
1 "Up to PS"
2 "JHS"
3 "SHS"
4 "VHS"
5 "Tertiary";
#d cr

label value educ educ_lab
tab educ [fw=weight] if age>=15

gen educ_mw = .							
replace educ_mw = 1 if inlist(b5p1a, 1, 2)			
replace educ_mw = 2 if inlist(b5p1a, 3,4)	
replace educ_mw = 3 if inlist(b5p1a, 5,6,7)	
replace educ_mw = 4 if inlist(b5p1a, 8,9,10)	
replace educ_mw = 5 if inlist(b5p1a, 11,12)
replace educ_mw = 6 if inlist(b5p1a, 13,14)

#delimit
label define educmw_lab
1 "No School"
2 "Elementary"
3 "JHS"
4 "SHS/VHS"
5 "Diploma"
6 "University";
#d cr

label value educ_mw educmw_lab


******************************
*  LABOUR FORCE INDICATORS  *
******************************

/*Main activity*/
gen main_activity = . 						
replace main_activity  = 1 if b5p2a1 == 1 	
replace main_activity  = 2 if b5p2a2 == 1
replace main_activity  = 3 if b5p2a3 == 1
replace main_activity  = 4 if b5p2a4 == 1

label define activity_lab 1 "Work" 2 "School" 3 "Housework" 4 "Other"
label value  main_activity activity_lab
tab main_activity [fw=weight] if age>=15

/*Labour Force*/
gen activity_work = 1 if b5p2a1== 1
gen temp_notwork = 1 if b5p3 == 1
gen looking_forwork = 1 if b5p4 == 1
gen business_prep = 1 if b5p5 == 1
gen reason_notwork = 1 if b5p6>=1&b5p6<=2


#delimit;
gen inLF=0;
replace inLF=1 if activity_work==1|temp_notwork==1|looking_forwork==1|business_prep==1
|reason_notwork==1;
 #d cr

label define LF 0 "Not in LF" 1 "In LF"
label value inLF LF
tab inLF [fw=weight] if age>=15 
/* Confirmed with BPS estimates 
   Labor Force = 136,183,032
   Not in Labor Force = 60,279,733   	 */

drop employed
/*Employed*/
#delimit;
gen employed=0;
replace employed = 1 if activity_work==1|temp_notwork==1;
 #d cr
label define employment 0"Unemployed" 1"Employed"
label value employed employment
tab employed [fw=weight] if inLF==1 & age>=15 
/* Confirmed with BPS estimates found in https://www.bps.go.id/statictable/2009/04/16/969/penduduk-berumur-15-tahun-ke-atas-menurut-jenis-kegiatan-tahun-1986---2018.html
   Employed = 129,366,192 
   Unemployed = 6,816,840  	
   Labor Force = 136,183,032*/

      /* NEET */
	  drop youth
g youth = inrange(age, 15, 24)

gen neet = 0 if inrange(age, 15, 24)
replace neet = 1 if inrange(age,15,24) & employed==0 & b5p1c==2 & (sek ==1 | sek ==4)
tab neet [fw=weight] if youth==1   

/* Underemployed */

gen workhrs = b5p11

gen underemployed = .
replace underemployed = 0 if employed==1
replace underemployed = 1 if employed==1 & workhrs<35 & b5p7==1


gen employment_status=.
replace employment_status=1  if  b5p12 == 1 
replace employment_status=2  if  b5p12 == 2
replace employment_status=3  if  b5p12 == 3
replace employment_status=4  if  b5p12 == 4
replace employment_status=5  if  b5p12 == 5 
replace employment_status=6  if  b5p12 == 6 
replace employment_status=7  if  b5p12 == 7

#delimit;
label define empl_lab
1 "Own account worker"
2 "Employer assisted by temp/unpaid worker"
3 "Employer assisted by perm/paid worker"
4 "Employees"
5 "Casual employee in agriculture"
6 "Casual employee in non-agric"
7 "Family/unpaidworker";
#d cr

label value employment_status empl_lab
tab employment_status sex [fw=weight] if age >=15 & employed==1


*Calculate FLPR and MLPR*

*Female Labor Force*
gen inFLF=0
replace inFLF=1 if (inLF==1 & sex==2)
label define inFLF 0 "Not in FLF" 1 "in FLF"
label value inFLF FLF
tab inFLF [fw=weight] if age >=15  

*Female Working Age Pop*
gen inFWAP=0
replace inFWAP=1 if (sex==2 & age>=15)
label define inFWAP 0 "Not in FWAP" 1 "in FWAP"
label value inFWAP FWAP
tab inFWAP [fw=weight] if age >=15 

*Calculate FLPR by Age Cohort*
tab age_cohort inFLF  [fw=weight]  
tab age_cohort inFWAP[fw=weight]  

*Male Labor Force*
gen inMLF=0
replace inMLF=1 if (inLF==1 & sex==1)
label define inMLF 0 "Not in MLF" 1 "in MLF"
label value inMLF MLF
tab inMLF [fw=weight] if age >=15

*Male Working Age Pop*
gen inMWAP=0
replace inMWAP=1 if (sex==1 & age>=15)
label define inMWAP 0 "Not in MWAP" 1 "in MWAP"
label value inMWAP MWAP
tab inMWAP [fw=weight] if age >=15 

*Calculate MLPR by Age Cohort*
tab age_cohort inMLF [fw=weight]  
tab age_cohort inMWAP[fw=weight]  

/*KBJI*/
//Menggunakan klasifikasi baku jenis pekerjaan KBJI 2014 1 digit//

gen occ=.
replace occ=0 if kbji2002==0&employed==1
replace occ=1 if kbji2002==1&employed==1
replace occ=2 if kbji2002==2&employed==1
replace occ=3 if kbji2002==3&employed==1
replace occ=4 if kbji2002==4&employed==1
replace occ=5 if kbji2002==5&employed==1
replace occ=6 if kbji2002==6&employed==1
replace occ=7 if kbji2002==7&employed==1
replace occ=8 if kbji2002==8&employed==1
replace occ=9 if kbji2002==9&employed==1

#delimit;
label define occ_lab
0 "Armed forces/Police"
1 "Managerial"
2 "Professional"
3 "Technician"
4 "Clerical"
5 "Services/sales"
6 "Agricultural"
7 "Production"
8 "Operators"
9 "Labourer";
#d cr

label values occ occ_lab
tab occ sex [fw=weight] if age>=15 & employed==1

********************************************************************************
/*Informality (Current Status)*/
********************************************************************************

*Creating and labelling informal sector variabel (proxy2_informal)

#delimit;
gen proxy2_informal=.;
replace proxy2_informal=1 if  
employment_status==1|
employment_status==2|
employment_status==5|
employment_status==6|
employment_status==7;
#d cr

replace proxy2_informal=0 if proxy2_informal~=1&employment_status~=.
tab proxy2_informal sex [fw=weight] if age>=15 & employed==1 
tab proxy2_informal urban_rural [fw=weight] if age>=15 & employed==1 , col
tab proxy2_informal [fw=weight]if age>=15 & employed==1

*Creating and labelling informal sector variabel (proxy1_informal)
gen proxy1_informal=.
replace proxy1_informal=1 if employed==1& employment_status==7 /*all unpaid informal*/
replace proxy1_informal=0 if employed==1&(employment_status==3|employment_status==4)

replace proxy1_informal=1 if employed==1&(occ==0|occ==1|occ==2|occ==3|occ==4)&employment_status==7
replace proxy1_informal=0 if employed==1&(occ==0|occ==1|occ==2|occ==3|occ==4)&employment_status~=7

replace proxy1_informal=1 if employed==1&(employment_status==5|employment_status==6|employment_status==1)&(occ>4)
replace proxy1_informal=0 if employed==1&(employment_status==5|employment_status==6|employment_status==1)&(occ<=4)

replace proxy1_informal=1 if employed==1&(employment_status==2)&(occ==6)
replace proxy1_informal=0 if employed==1&(employment_status==2)&(occ~=6)

tab proxy1_informal urban_rural [fw=weight] if age>=15 & employed==1

tab proxy1_informal sex [fw=weight] if age>=15 & employed==1



********************************************************************************
/*KLUI*/
*******************************************************************************

/*main sector KLUI*/

gen main_sector = klui9

#delimit;
label define sector
1 "Agriculture, forestry, and fishery"
2 "Mining and quarrying"
3 "Manufacturing"
4 "Electricity and gas; Water supply and waste management"
5 "Construction"
6 "Wholesales and retail trade; repair of motor vehicles; restaurant and hotels"
7 "Transport and storage; communication"
8 "Financial and insurance activities; Real Estatel Business activities"
9 "Jasa Kemasyarakatan, Sosial, dan Perorangan"
0 "Missing";
#d cr

label values main_sector sector
tab main_sector [fw=weight] if age>=15 & employed==1 

tab employment_status [fw=weight] if age>=14 & employed == 1 & main_sector==3

g contract_tenure = 0
g prov_work = b5p15ap

/* Wage Information */
//gen wage_all = b5p13a + b5p13b

egen wage_all=rsum(b5p13a b5p13b)
label variable wage_all "Nett income"

//disc worker -> b5p6
