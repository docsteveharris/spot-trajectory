*  =====================================
*  = Set up data for survival analysis =
*  =====================================
GenericSetupSteveHarris spot_traj cr_survival, logon


* CHANGED: 2013-05-20 - ONLY USE BELOW FOR DEBUGGING: this file should not call or save
* local clean_run = 0
* if `clean_run' == 1 & $clean_run != 0 {
* 	use ../data/working.dta, clear
* 	qui include cr_preflight.do
* }
* else {
* 	di as error "WARNING: debug off - using data in memory"
* }



d daicu date_trace dead
stset date_trace, origin(time daicu) failure(dead) exit(time daicu+365)
* sts graph, xlab(0 90)
* graph export ../logs/survival_all_90d.pdf, replace

* Flag a single record per patient for examining non-timedependent characteristics
bys id: gen ppsample =  _n == _N
label var ppsample "Per patient sample"

* if `clean_run' {
* 	save ../data/working_survival.dta, replace
* }

cap log close