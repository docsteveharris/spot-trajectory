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




cap log close
