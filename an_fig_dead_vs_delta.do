*  =================================================
*  = Plot mean 28 day mortality against trajectory =
*  =================================================

GenericSetupSteveHarris spot_traj an_fig_dead_vs_delta, logon
global figure_name dead_vs_delta

/*
created:	130403
modified:	130403

x-axis delta
y-axis 1: dead28
y-axis 2: histogram

Initially focus on admissions within 4 / 12 / 24+ hrs
Repeat for each meetric

*/



local clean_run 0
if `clean_run' == 1 {
    clear
    use ../data/working.dta
    qui include cr_preflight.do
}


// ICNARC complete
use ../data/working_postflight.dta, clear
keep if time2icu < 24
cap drop __*
su ims_c2 ims_c1


egen ims_c_traj_k = cut(ims_c_traj), at(-10(1)10)
drop if ims_c_traj_k == .

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	if icnarc0 <= 50 ///
	, by(ims_c_traj_k)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n ims_c_traj_k, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 ims_c_traj_k if n > 10, yaxis(2)) ///
	(scatter dead28_bar ims_c_traj_k if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(0(25)100, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("Pre-admission trajectory" "(Complete) ICNARC Acute Physiology Score", margin(medium)) ///
	xlabel(-10(5)10) ///
	xscale(noextend) ///
	text(100 -10 "(C)", placement(e) yaxis(2) size(large)) ///
	legend(off)

graph rename dead_vs_delta_24_complete, replace
graph display dead_vs_delta_24_complete
graph export ../outputs/figures/dead_vs_delta_24_complete.pdf, replace

// ICNARC partial
use ../data/working_postflight.dta, clear
keep if time2icu < 24
cap drop __*

egen ims_ms_traj_k = cut(ims_ms_traj), at(-10(1)10)
drop if ims_ms_traj_k == .

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	if icnarc0 <= 50 ///
	, by(ims_ms_traj_k)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n ims_ms_traj_k, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 ims_ms_traj_k if n > 10, yaxis(2)) ///
	(scatter dead28_bar ims_ms_traj_k if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("Pre-admission trajectory" "(Partial) ICNARC Acute Physiology Score", margin(medium)) ///
	xlabel(-10(5)10) ///
	xscale(noextend) ///
	text(100 -10 "(C)", placement(e) yaxis(2) size(large)) ///
	legend(off)

graph rename dead_vs_delta_24_complete, replace
graph display dead_vs_delta_24_complete
graph export ../outputs/figures/dead_vs_delta_24_complete.pdf, replace

// Lactate
use ../data/working_postflight.dta, clear
keep if time2icu < 24
cap drop __*

egen lac_traj_k = cut(lac_traj), at(-10(1)10)
drop if lac_traj_k == .

collapse ///
	(mean) dead28_bar = dead28 ///
	(sebinomial) dead28_se = dead28 ///
	(count) n = dead28 ///
	if icnarc0 <= 50 ///
	, by(lac_traj_k)


gen min95 = dead28_bar - 1.96 * dead28_se
gen max95 = dead28_bar + 1.96 * dead28_se
replace min95 = min95 * 100
replace max95 = max95 * 100
replace dead28_bar = dead28_bar * 100

tw ///
	(bar n lac_traj_k, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 lac_traj_k if n > 10, yaxis(2)) ///
	(scatter dead28_bar lac_traj_k if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("28 day mortality (%)", axis(2)) ///
	ylabel(0(25)100, axis(2) nogrid) ///
	xtitle("Pre-admission trajectory" "Lactate", margin(medium)) ///
	xlabel(-10(5)10) ///
	xscale(noextend) ///
	text(100 -10 "(C)", placement(e) yaxis(2) size(large)) ///
	legend(off)

graph rename dead_vs_delta_24_complete, replace
graph display dead_vs_delta_24_complete
graph export ../outputs/figures/dead_vs_delta_24_complete.pdf, replace

cap log close

