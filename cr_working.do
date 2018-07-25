*  ===========================================
*  = Define data for the trajectory analysis =
*  ===========================================

local clean_run 1
if `clean_run' {

	clear
	local ddsn mysqlspot
	local uuser stevetm
	local ppass ""

	odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

	clear
	timer on 1
	odbc load, exec("SELECT * FROM spot_traj.working_traj")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
	timer off 1
	timer list 1
	count

	// Merge in site level data
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
	qui compress

	shell ../ccode/label_stata_fr_yaml.py "../data/scratch/vars.yml" "../local/lib_phd/dictionary_fields.yml"

	capture confirm file ../data/scratch/_label_data.do
	if _rc == 0 {
		include ../data/scratch/_label_data.do
		// shell  rm ../data/scratch/_label_data.do
		// shell rm ../data/scratch/myvars.yml
	}
	else {
		di as error "Error: Unable to label data"
		exit
	}

	save ../data/working_raw.dta, replace
}

GenericSetupSteveHarris spot_traj cr_working, logon
set scheme shbw

*  ========================
*  = Define analysis axes =
*  ========================
/*
NOTE: 2012-11-12 -
	- make_table.py seems to fail with large tables
	- therefore currently working with inclusion criteria in SQL statement
*/

use ../data/working_raw.dta, clear
/* CHANGED: 2012-11-21 - drop airedale */
drop if icode == "72s"
cap drop included_sites
egen included_sites = tag(icode)
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth)
count
count if included_sites == 1
count if included_months == 1
tab match_is_ok

*  =============================
*  = DROP SUSPECTED DUPLICATES =
*  =============================
// but first clear out duplicate patients
count
local n_0 = r(N)
cap drop __*
duplicates report idpatient if !missing(idpatient)
ret li
local idpatient_dup_N = r(N) - r(unique_value)
// TODO: 2013-05-20 - so some tails matched to the same head
// switch here to omit output when not investigating underlying cause
if 0 {
	duplicates report idpatient icnno adno if !missing(idpatient)
	duplicates tag idpatient if !missing(idpatient), gen(idpatient_dup)
	tab idpatient_dup
	tab matchtype if idpatient_dup > 0 
	// NOTE: 2013-05-20 - so this is not confined to poor quality matches?
	// Is it due to readmissions?
	sort idpatient daicu
	list dob sex withinsh adno matchtype daicu if inlist(idpatient_dup,1,2), sepby( idpatient) string(16)
	// not flagged as re-admissions but look very much like the same patients
	// TODO: 2013-05-20 - add this to discussion
	// NOTE: 2013-05-20 - for now subsequent admissions should be dropped: work with 1st only
	sort idpatient daicu
}
duplicates drop idpatient if !missing(idpatient), force
count
di as result "Duplicates (idpatient): `idpatient_dup_N' dropped (initial episode saved)"
save ../data/scratch/working_scratch, replace


*  ================================
*  = Now merge in final MRIS data =
*  ================================

clear
local ddsn mysqlspot
local uuser stevetm
local ppass ""
odbc load, exec("SELECT * FROM spot.light_mris_final")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
count
destring adno, replace
sort adno
list adno in 1/10
gsort -adno
list adno in 1/10
replace icnno = trim(lower(icnno))
tab icnno
ren dead dead_mris
save ../data/scratch/scratch.dta, replace


use ../data/scratch/scratch.dta, clear
tempfile 2merge_icnarc
keep if !missing(icnno, adno)
* list icnno adno in 1/10
count
save `2merge_icnarc', replace

use ../data/scratch/scratch.dta, clear
keep if !missing(idpatient)
duplicates report idpatient 
duplicates report idpatient dead
count
tempfile 2merge_spot
save `2merge_spot', replace

* duplicates report icnno adno if !missing(icnno, adno)
// 1st merge: merge in based on icnno and adno because this does not rely on match accuracy
use ../data/scratch/working_scratch, clear
count 
local n_1 = r(N)
merge 1:1 icnno adno using `2merge_icnarc'
count if _merge != 3 & !missing(idpatient)
count if _merge != 3 & missing(idpatient)
// NOTE: 2013-05-20 - so 1200+ icnno adno patients still missing survival
drop if _merge == 2
keep if _merge == 3 
drop _merge
tempfile working_icnarc
count
save `working_icnarc', replace

// 2nd merge: merge based on idpatient 
use ../data/scratch/working_scratch, clear
merge 1:1 icnno adno using `working_icnarc', keepusing() nolabel
// and drop patients were you have already matched to MRIS in stage 1
drop if _merge == 3
drop _merge
cap drop __*
drop if missing(idpatient)
merge 1:1 idpatient using `2merge_spot', update
count if _merge == 2
// these are the patients who depended on idpatient for a match who have not been
drop if _merge == 2
drop _merge
tempfile working_spot
drop if missing(idpatient)
save `working_spot', replace

// use original data to merge in the mris data
use ../data/scratch/working_scratch, clear
merge 1:1 icnno adno using `working_icnarc', nolabel keepusing(dead_mris date_event)
count if _merge == 2
assert r(N) == 0
drop _merge
merge m:1 idpatient using `working_spot', nolabel keepusing(dead_mris date_event) update
count if _merge == 2
assert r(N) == 0
drop _merge

tab dead_mris, missing
count
di as error "Duplicates (idpatient): `idpatient_dup_N' dropped (initial episode saved)"
di as result "Initial count: `n_0'"
di as result "Final count: `=r(N)'"

save ../data/working_raw_mris.dta, replace
use ../data/working_raw_mris.dta, clear

*  ====================================================
*  = Now start the standard include / exclude process =
*  ====================================================

* JH: Drop existing included_sites column, create new column included_sites, 1 if icode present??

cap drop included_sites
egen included_sites = tag(icode)
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth)
count
count if included_sites == 1
count if included_months == 1
tab match_is_ok

// Define the inclusion by intention
// Emergency direct ward to ICU admissions
/*
First of all define the clean data
- cmpd_month_miss
- elgdate
- studymonth_protocol_problem
- elgprotocol
*/

gen include = 1
replace include = 0 if cmpd_month_miss != 0
replace include = 0 if elgdate != 1
// CHANGED: 2012-11-14 - make direct ward to icu admission part of the inclusion
// CHANGED: 2013-03-28 - changed back!
replace include = 0 if elgward == 0 & elgoward == 0 & elgtrans == 0
/* elgprotocol only exists for heads so check for '0' not '1'  */
replace include = 0 if elgprotocol == 0
* CHANGED: 2012-11-14 - add this to inclusion
replace include = 0 if elgemx != 1

tab include
tab match_is_ok if include == 1

cap drop included_sites
egen included_sites = tag(icode) if include == 1
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1
count if include == 1
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1
* Theoretical pool of patients if all sites had been perfect

*  =========================================================
*  = Include only if meet minimum initial quality criteria =
*  =========================================================
// NOTE: 2013-03-28 - missing site_quality_q1 occurs when there were protocol problems
replace include = 0 if (site_quality_q1 < 80 | site_quality_q1 == .) ///
	& include == 1
cap drop included_sites
egen included_sites = tag(icode) if include == 1
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1
count if include == 1
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1

*  =====================
*  = Exclude by design =
*  =====================
* Non-eligible patients (no risk of bias ... dropped by design)
* What proportion of these were ineligible and for what reason?
cap drop exclude1
gen exclude1 = 0
label var exclude1 "Exclude - by design"

* Inspect exclusions _after_ removing poor quality months
count if include == 1 & elgage == 0 & exclude1 == 0
count if include == 1 & elgcpr == 0 & exclude1 == 0
count if include == 1 & withinsh == 1 & exclude1 == 0
count if include == 1 & elgreport_heads == 0 & exclude1 == 0
count if include == 1 & elgreport_tails == 0 & exclude1 == 0

replace exclude1 = 1 if include == 1 & elgage == 0 & exclude1 == 0
replace exclude1 = 1 if include == 1 & elgcpr == 0 & exclude1 == 0
replace exclude1 = 1 if include == 1 & withinsh == 1 & exclude1 == 0
replace exclude1 = 1 if include == 1 & elgreport_heads == 0 & exclude1 == 0
replace exclude1 = 1 if include == 1 & elgreport_tails == 0 & exclude1 == 0

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0
count if include == 1 & exclude1 == 0
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1 & exclude1 == 0
// Inspect sites that will *not* be included
tempvar x y
gen `x' = include == 1 & exclude1 == 0
bys icode: egen `y' = total(`x')
cap drop excluded_sites
egen excluded_sites = tag(icode) if `y' == 0
tab dorisname if excluded_sites == 1

*  ===================================
*  = Exclude because of poor quality =
*  ===================================
cap drop exclude2
gen exclude2 = 0
label var exclude2 "Exclude - by choice"
replace exclude2 = 1 if include == 1 & exclude1 == 0 & ///
	(site_quality_by_month < 80 | site_quality_by_month == .)
tab exclude2 if include == 1 & exclude1 == 0

* Count how many studymonths have an exclude2 flag
duplicates report icode studymonth if exclude2 == 1
ret li

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1 & exclude1 == 0 & exclude2 == 0

*  =============================
*  = Exclude lost to follow-up =
*  =============================
* TODO: 2013-05-20 - PROBABLE ERRORS but probably arise from merge priority differences
* differences here ought to be errors
* as same data used dead comes from SQL merge and dead_mris from stata merge
count if date_event != date_trace
count if abs(date_event - date_trace) > 7 & !missing(date_event, date_trace)
tab dead dead_mris
* For now prioritise the stata merge
drop dead
rename dead_mris dead
drop date_trace
rename date_event date_trace

cap drop exclude3
gen exclude3 = 0
label var exclude3 "Exclude - lost to follow-up"
replace exclude3 = 1 if include == 1 & exclude1 == 0 & missing(date_trace)
tab exclude3 if include == 1 & exclude1 == 0 & exclude2 == 0

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0


*  ===========================================
*  = Exclude where data cannot be reconciled =
*  ===========================================
/*
TODO: 2013-03-28 -
- ICNARC and MRIS death mismatch
- icu admit before visit
- date trace before icu admit
*/
cap drop exclude4
gen exclude4 = 0
label var exclude4 "Exclude - data irreconcilable"

* NOTE: 2012-09-27 - get more precise survival timing for those who die in ICU
* Add one hour though else ICU discharge and last_trace at same time
* this would mean these records being dropped by stset
* CHANGED: 2012-10-02 - changed to 23:59:00 from 23:59:59 because of rounding errors
cap drop last_trace
gen last_trace = cofd(date_trace) + hms(23,58,00)
replace last_trace = icu_discharge if dead_icu == 1 & !missing(icu_discharge)
format last_trace %tc
label var last_trace "Timestamp last event"

list icode dead dead_icu dod date_trace  ///
	if ( dod != date_trace | dofc(icu_discharge) > date_trace) ///
	& dead_icu != dead & dead != . & dod != . & icu_discharge != ., ///
	sepby(idvisit) table compress
	
	## dofc converts time in milliseconds to date format for icu_discharge

count if dofc(icu_discharge) != date_trace & dead_icu == 1 & dead !=.
* NB all done at the at hours resolution
count if floor(hours(icu_admit)) 	> floor(hours(icu_discharge)) & !missing(icu_admit, icu_discharge)
count if floor(hours(v_timestamp)) > floor(hours(icu_admit)) & !missing(v_timestamp, icu_admit)
count if floor(hours(v_timestamp)) > floor(hours(icu_discharge)) & !missing(v_timestamp, icu_discharge)
count if floor(hours(icu_admit)) 	> floor(hours(last_trace)) & !missing(icu_admit, last_trace)
// CHANGED: 2013-03-28 - change this to a date rather than an hour check since you are imputing hours above
count if dofc(icu_discharge) > dofc(last_trace) & !missing(icu_discharge, last_trace)
count if dofc(v_timestamp) > dofc(last_trace) & !missing(v_timestamp, last_trace)

replace exclude4 = 1 if dofc(icu_discharge) != date_trace & dead_icu == 1 & dead !=.
* NB all done at the at hours resolution
replace exclude4 = 1 if floor(hours(icu_admit)) 	> floor(hours(icu_discharge)) & !missing(icu_admit, icu_discharge)
replace exclude4 = 1 if floor(hours(v_timestamp)) > floor(hours(icu_admit)) & !missing(v_timestamp, icu_admit)
replace exclude4 = 1 if floor(hours(v_timestamp)) > floor(hours(icu_discharge)) & !missing(v_timestamp, icu_discharge)
replace exclude4 = 1 if floor(hours(icu_admit)) 	> floor(hours(last_trace)) & !missing(icu_admit, last_trace)
// CHANGED: 2013-03-28 - change this to a date rather than an hour check
replace exclude4 = 1 if dofc(icu_discharge) > dofc(last_trace) & !missing(icu_discharge, last_trace)
replace exclude4 = 1 if dofc(v_timestamp) > dofc(last_trace) & !missing(v_timestamp, last_trace)
tab exclude4 if !exclude1 & !exclude2 & !exclude3 & include

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude4 == 0
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude4 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude4 == 0
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude4 == 0

*  ==========================================================
*  = Exclude - unmatched therefore cannot assess trajectory =
*  ==========================================================

cap drop exclude5
gen exclude5 = 0
label var exclude5 "Exclude - unmatched / missed"
replace exclude5 = 1 if include == 1 & exclude1 == 0 & match_is_ok == 0
tab exclude5 if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 

cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude5 == 0
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude5 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude5 == 0
count if included_sites == 1
count 
tab match_is_ok if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0 & exclude5 == 0

*  =================================================
*  = Save working_all before dropping any patients =
*  =================================================
save ../data/working_all.dta, replace
use ../data/working_all.dta, clear
cap drop __*

* // FINAL NUMBERS (NOT DROPPING exclude3 which is no MRIS follow-up)
* cap drop included_sites
* egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0
* count if included_sites == 1
* cap drop included_months
* egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0
* count if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0
* count if included_sites == 1
* count if included_months == 1
* tab match_is_ok if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0

keep if include 	== 1
drop if exclude1 	== 1
drop if exclude2 	== 1
drop if exclude3	== 1
drop if exclude4 	== 1
drop if exclude5 	== 1

cap drop included_sites
egen included_sites = tag(icode)
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth)
count if include == 1
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1

drop include exclude*
drop included_sites
drop included_months
cap drop __*
compress
codebook, compact

save ../data/working.dta, replace
cap log close


