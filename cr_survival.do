*  =====================================
*  = Set up data for survival analysis =
*  =====================================
GenericSetupSteveHarris spot_traj cr_survival, logon
use ../data/working.dta, clear
qui include cr_preflight.do



d daicu date_trace dead
stset date_trace, origin(time daicu) failure(dead) exit(time daicu+90)
sts graph, xlab(0 90)
graph export ../logs/survival_all_90d.pdf, replace

save ../data/working_survival.dta, replace


cap log close