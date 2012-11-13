clear
* ==================================
* = DEFINE LOCAL AND GLOBAL MACROS =
* ==================================
local ddsn mysqlspot
local uuser stevetm
local ppass ""
set scheme shbw

*  =======================================
*  = Log definitions and standard set-up =
*  =======================================
GenericSetupSteveHarris spot_traj cr_working


*  =======================================
*  = Visit level data import from SQL db =
*  =======================================

odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

clear
timer on 1
odbc load, exec("SELECT * FROM spot_traj.working_traj")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
timer off 1
timer list 1
count

* Merge in site level data
preserve
include cr_sites.do
restore
merge m:1 icode using ../data/sites.dta, ///
	keepusing(heads_tailed* ccot_shift_pattern all_cc_in_cmp ///
		tails_wardemx* tails_othercc* ///
		ht_ratio cmp_beds_persite*)
drop _m


file open myvars using ../data/scratch/vars.yml, text write replace
foreach var of varlist * {
	di "- `var'" _newline
	file write myvars "- `var'" _newline
}
file close myvars

compress


shell ../local/lib_usr/label_stata_fr_yaml.py "../data/scratch/vars.yml" "../local/lib_phd/dictionary_fields.yml"

capture confirm file ../data/scratch/_label_data.do
if _rc == 0 {
	include ../data/scratch/_label_data.do
	* shell  rm ../data/scratch/_label_data.do
	* shell rm ../data/scratch/myvars.yml
}
else {
	di as error "Error: Unable to label data"
	exit
}

*  ========================
*  = Define analysis axes =
*  ========================
* TODO: 2012-10-01 - you may want to make the definitions more 'transportable'
* i.e. move them back into the python codebase


*  ===========================================================
*  = Now run the include exclude code to produce working.dta =
*  ===========================================================
*  This should produce the data for the consort diagram
/*
NOTE: 2012-11-12 - 
	- make_table.py seems to fail with large tables
	- therefore currently working with inclusion criteria in SQL statement
*/

count

cap drop included_sites
egen included_sites = tag(icode)
count if included_sites == 1

* Define the inclusion by intention

gen include = 1
replace include = 0 if elgdate == 0
replace include = 0 if elgward == 0 & elgoward == 0 & elgtrans == 0
replace include = 0 if elgprotocol == 0
tab include

count if included_sites == 1 & include == 1

cap drop included_months
egen included_months = tag(icode studymonth)
count if included_months == 1 & include == 1

*  ===================================================================
*  = Define inclusion by intention and linkage quality in months 1-3 =
*  ===================================================================

gen early_exclude = include == 1 & site_quality_q1 < 80
tab early_exclude if include
replace include = 0 if early_exclude == 1
tab include

cap drop included_sites
egen included_sites = tag(icode) if include == 1

count if included_sites == 1 & include == 1
cap drop included_months

egen included_months = tag(icode studymonth)
count if included_months == 1 & include == 1


/* Late exclusions on quality grounds */

gen late_exclude = include == 1 & !inlist(studymonth,1,2,3) & ///
	(site_quality_by_month < 80 | site_quality_by_month == .)
tab include
tab studymonth late_exclude if include == 1

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & late_exclude == 0
count if included_sites == 1 & include == 1 & late_exclude == 0

cap drop included_months
egen included_months = tag(icode studymonth)
count if included_months == 1 & include == 1 & late_exclude == 0

*  ==============
*  = Exclusions =
*  ==============

* Define the first main exclusion

gen exclude = 0
replace exclude = 1 if late_exclude == 1

* Inspect exclusions _after_ removing poor quality months
count if include == 1 & elgreport_heads == 0 & exclude == 0
count if include == 1 & elgcpr == 1 & exclude == 0
count if include == 1 & elgreport_tails == 0 & exclude == 0
count if include == 1 & withinsh == 1 & exclude == 0
count if include == 1 & missing(date_trace) & exclude == 0
count if include == 1 & elgward == 0

replace exclude = 1 if include == 1 & elgward == 0
replace exclude = 1 if include == 1 & elgcpr == 0
replace exclude = 1 if include == 1 & elgemx == 0
replace exclude = 1 if include == 1 & elgreport_heads == 0
replace exclude = 1 if include == 1 & elgreport_tails == 0
replace exclude = 1 if include == 1 & withinsh == 1
replace exclude = 1 if include == 1 & missing(date_trace)
tab exclude if include == 1

save ../data/working_all.dta, replace

keep if include
drop if exclude



count

cap drop included_sites
egen included_sites = tag(icode)
count if included_sites == 1

cap drop included_months
egen included_months = tag(icode studymonth)
count if included_months == 1

* No point keeping these vars since they don't mean anything now
drop include exclude
drop early_exclude late_exclude
drop included_sites
drop included_months
codebook, compact

cap log close


save ../data/working.dta, replace




