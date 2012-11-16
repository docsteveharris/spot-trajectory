* ===================================
* = Summarise patient characteristics =
* ===================================

*  =======================================
*  = Log definitions and standard set-up =
*  =======================================
GenericSetupSteveHarris spot_traj an_table_patient, logon
clear all
use ../data/working.dta
quietly include cr_preflight.do
quietly include mtPrograms.do
count

/* Check inclusion - exclusion */
su elg*

/* Demographics */
tab sex
tabstat age, s(n mean sd skew kurt min max) c(stat) format(%9.3g)
hist age, s(18) w(2) freq name(age_hist, replace)
graph export ../logs/age_hist.pdf, replace

tab ethnic
tab white

/* Severity of illness @ CMPD */
local severities ims1 ims2 ap2aps ap2score pf1 pf2
foreach var of local severities {
	tabstat `var', s(n mean sd skew kurt min max) c(stat)
	hist `var', s(1) w(1) freq name(`var'_hist, replace)
	/* NOTE: 2012-11-14 - display otherwise is not picked up by log2md */
	noi di "graph export ../logs/`var'_hist.pdf, replace"
	graph export ../logs/`var'_hist.pdf, replace

}

/* SPOT sepsis */
tab sepsis
tab sepsis_site
tab sepsis2001

tabstat dx_*, s(n sum mean sd) c(stat)


/* Admission timing */
su time2icu, d
twoway hist time2icu if time2icu <= 72, s(0) w(1) freq ///
	xlabel(0(24)72) xscale(noextend) yscale(noextend) ///
	name(time2icu_hist, replace)
graph export ../logs/time2icu_hist.pdf, replace



/* Trajectory */
su delta, d
twoway hist delta, width(1) freq ///
	xlabel(-40 0 40) xscale(noextend) yscale(noextend) ///
	name(delta_hist, replace)
graph export ../logs/delta_ims_hist.pdf, replace


su ims_traj, d
twoway hist ims_traj, width(1) freq ///
	xlabel(-20 0 20) xscale(noextend) yscale(noextend) ///
	name(traj_hist, replace)
graph export ../logs/ims_traj_hist.pdf, replace


tab ims_traj_cat

/* Other physiology variables */
traj_check pf, mmw(0 100 2)
traj_check cr, mmw(0 800 25)
traj_check urin, mmw(0 150 5)

/* Outcome data */
tab dead_icu
tab dead28
tab dead90

tab dead_icu dead28
tab dead_icu dead90


/*  */
cap log close





