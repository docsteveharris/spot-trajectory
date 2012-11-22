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
qui su age,d
local min: di %6.0g r(min)
local med: di %6.0g r(p50)
local max: di %6.0g r(max)
local xlab: di `" `min' `med' `max' "'
di `"`xlab'"'
hist age, s(18) w(2) xlab(`xlab') freq name(age_hist, replace) ///
	note("Age legend: min,  median, max")
graph export ../logs/age_hist.pdf, replace

tab ethnic
tab white

/* Severity of illness @ CMPD */
local severities ims1 ims2 ap2aps ap2score pf1 pf2 na2
* local severities na2
foreach var of local severities {
	tabstat `var', s(n mean sd skew kurt min max) c(stat)
	qui su `var',d
	local min: di %6.0f r(min)
	local med: di %6.0f r(p50)
	local max: di %6.0f r(max)
	local p1: di %6.0f r(p1)
	local p99: di %6.0f r(p99)
	local xlab: di `" `min' `p1' `med' `p99' `max' "'
	di `"`xlab'"'
	cap drop qq
	running dead28 `var', gen(qq) nodraw
	replace qq = . if qq > 1
	replace qq = . if qq < 0
	twoway 	(hist `var', s(1) w(1) freq xlab(`xlab')) ///
			(line qq `var', sort lpattern(dash) ///
			yaxis(2) ylab(0 "0%" 0.5 "50%" 1 "100%", axis(2)) ytitle("28d mortality - running mean", axis(2))), ///
			xline(`p1' `p99', noextend lcolor(gs4) lpattern(dot)) ///
			legend(off) note("x labels: min/1st centile/median/99th centile/max") ///
			name(`var'_hist, replace) 
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
/* Not showing max in histogram b/c at 317 hours */
su time2icu, d
local min: di %6.0f r(min)
local med: di %6.0f r(p50)
local max: di %6.0f r(max)
local p75: di %6.0f r(p75)
local p95: di %6.0f r(p95)
local p99: di %6.0f r(p99)
local xlab: di `" `min' `med' `p75' `p95' `p99' "'
di `"`xlab'"'
twoway hist time2icu if time2icu <= 168, s(0) w(1) freq ///
	xlabel(`xlab') xscale(noextend) yscale(noextend) ///
	xline(`p1' `p99', noextend lcolor(gs4) lpattern(dot)) ///
	legend(off) note("x labels: min/median/75th/95th/99th centiles") ///
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





