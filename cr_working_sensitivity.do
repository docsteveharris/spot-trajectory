*  ========================================
*  = Define data for sensitivity analyses =
*  ========================================

* NOTE: 2013-05-20 - depends on having run cr_working FIRST
use ../data/working_raw_mris.dta, clear

*  ====================================================
*  = Now start the standard include / exclude process =
*  ====================================================

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
* CHANGED: 2013-05-20 - ALLOW ALL SITES AND ALL MONTHS TO BE CONSIDERED

// NOTE: 2013-03-28 - missing site_quality_q1 occurs when there were protocol problems
* replace include = 0 if (site_quality_q1 < 70 | site_quality_q1 == .) ///
* 	& include == 1
* cap drop included_sites
* egen included_sites = tag(icode) if include == 1
* count if included_sites == 1
* cap drop included_months
* egen included_months = tag(icode studymonth) if include == 1
* count if include == 1
* count if included_sites == 1
* count if included_months == 1
* tab match_is_ok if include == 1

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
	(site_quality_by_month < 70 | site_quality_by_month == .)
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
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1 & exclude1 == 0 & exclude2 == 0 & exclude3 == 0 & exclude4 == 0


// FINAL NUMBERS (NOT DROPPING exclude3 which is no MRIS follow-up)
cap drop included_sites
egen included_sites = tag(icode) if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0
count if included_sites == 1
cap drop included_months
egen included_months = tag(icode studymonth) if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0
count if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0
count if included_sites == 1
count if included_months == 1
tab match_is_ok if include == 1 & exclude1 == 0 & exclude2 == 0 &  exclude4 == 0

keep if include 	== 1
drop if exclude1 	== 1
drop if exclude2 	== 1
* drop if exclude3	== 1
drop if exclude4 	== 1

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
* codebook, compact

save ../data/working_sensitivity.dta, replace


