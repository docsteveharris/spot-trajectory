* ===================================
* = Summarise patient characteristics =
* ===================================

*  =======================================
*  = Log definitions and standard set-up =
*  =======================================
GenericSetupSteveHarris spot_traj an_table_patient
clear all
use ../data/working.dta
quietly include cr_preflight.do
count

/* Check inclusion - exclusion */
su elg*

/* Demographics */
tab sex
tabstat age, s(n mean sd skew kurt min max) c(stat)
hist age, s(18) w(2) freq name(age_hist, replace)
tab ethnic
tab white

/* Severity of illness @ CMPD */
local severities ims1 ims2 ap2aps ap2score
foreach var of local severities {
	tabstat `var', s(n mean sd skew kurt min max) c(stat)
	hist `var', s(0) bin(20) freq name(`var'_hist, replace)
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


/* Trajectory */
su delta, d
twoway hist delta, width(1) freq ///
	xlabel(-40 0 40) xscale(noextend) yscale(noextend) ///
	name(delta_hist, replace)


su traj, d
twoway hist traj, width(1) freq ///
	xlabel(-20 0 20) xscale(noextend) yscale(noextend) ///
	name(traj_hist, replace)

tab traj_cat


/* Outcome data */
tab dead_icu
tab dead28
tab dead90

tab dead_icu dead28
tab dead_icu dead90


/*  */





