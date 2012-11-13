* ===================================
* = Summarise study characteristics =
* ===================================

*  =======================================
*  = Log definitions and standard set-up =
*  =======================================
GenericSetupSteveHarris spot_traj an_table_study
clear all
use ../data/working.dta
quietly include cr_preflight.do
codebook, compact
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

