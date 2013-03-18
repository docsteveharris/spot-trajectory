* ===================================
* = Summarise study characteristics =
* ===================================

*  =======================================
*  = Log definitions and standard set-up =
*  =======================================
GenericSetupSteveHarris spot_traj an_table_study, logon
clear all
use ../data/working.dta
quietly include cr_preflight.do
// codebook, compact
count

*  =====================
*  = Describe wrt site =
*  =====================

/*
For each site you want to know ...
- Number of patients
- Number of study months

*/
* preserve
egen study_months = tag(icode studymonth)
label var study_months "Months participating in (SPOT)light"
gen patients = 1
label var patients "Patients contributed to (SPOT)light"
collapse (sum) study_months patients, by(icode)
cap drop patients_per_month
gen patients_per_month = round(patients / study_months)

sort study_months
list * , sepby(study_months)
su patients_per_month, d

* restore
/*
You see some sites (Blackpool, Basildon etc) with v low number of patients
- this is because of the exclusions which meant their was data by which to judge the site hence the month stays in but no data to use from that month
*/

use ../data/working.dta, clear
contract icode,
/* Patients per site */
su _freq, d

use ../data/working.dta, clear
contract icode studymonth
drop _freq
contract icode
/* Months per site */
su _freq, d

use ../data/working.dta, clear
contract icode match_is_ok
drop if missing(match_is_ok)
bys icode (match_is_ok): gen match_per_site = _freq[2] / (_freq[1] + _freq[2])
drop if match_is_ok == 0
su match_per_site,d 

*  =======================================
*  = Understand patterns of missing data =
*  =======================================
use ../data/working.dta, clear
qui include cr_preflight.do
local vars hr bps temp rr pf ph urea cr na urin wcc gcs
tempname memhold
tempfile results
postfile `memhold' str12 name float(spot cmp both) using `results'
foreach var of local vars {
	count if missing(`var'1)
	local miss1 = r(N) / _N
	count if missing(`var'2)
	local miss2 = r(N) / _N
	count if missing(`var'1, `var'2)
	local miss1_2 = r(N) / _N
	post `memhold' ("`var'") (`miss1') (`miss2') (`miss1_2')
}
postclose `memhold'
use `results', clear
format spot cmp both %9.3g
sort both
list


cap log close
