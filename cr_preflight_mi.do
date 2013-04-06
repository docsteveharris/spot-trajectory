clear all
local datasets plus plus_surv
foreach dataset of local datasets {
	clear
	use ../data/working_mi_icnarc_`dataset'.dta
	set scheme shbw
	// derive ICNARC score and weights
	include cr_severity.do

	cap drop age_c
	gen age_c = age - 65

	/* Default will be to work with 1st 24 hour delta */
	keep if time2icu <= 24
	local traj_x 24
	cap drop ims_c_traj
	gen ims_c_traj = (ims_c2 - ims_c1) / (round(time2icu, `traj_x') + 1)
	label var ims_c_traj "IMscore - complete - slope"
	cap drop ims_ms_traj
	gen ims_ms_traj = (ims_ms2 - ims_ms1) / (round(time2icu, `traj_x') + 1)
	label var ims_ms_traj "ICNARC score (partial) - trajectory"

	cap drop m0
	gen m0 = _mi_m == 0
	label var m0 "Original (pre-imputation) data"

	count
	tab m0

	*  ========================================
	*  = Now set up the trajectory categories =
	*  ========================================

	cap drop c2_k
	egen c2_k = cut(ims_c2), at(0, 15, 25 100) icodes
	replace c2_k = c2_k + 1
	label var c2_k "ICNARC APS - CMPD"

	cap label drop c2_k
	label define c2_k 1 "Low risk" 2 "Medium risk" 3 "High risk"
	label values c2_k c2_k
	tabstat ims_c_traj, by(c2_k) s(n mean sd q) format(%9.3g)

	/*
	NOTE: 2013-04-06 - arbitrary definition of trajectory class
	- deteriorating (any increase in severity)
	- neutral is in the range of -1sd to zero
	- improving is any fall greater than 1sd
	Now divide the classes
	- c2_k = 1 = lowest admission severity
		- roughly the same
		- markedly improved

	*/


	qui su ims_c_traj
	local traj_sd = round(r(sd))
	cap drop tclass
	gen tclass = 0
	label var tclass "Trajectory class"
	cap label drop tclass
	label define tclass 0 "Unclassified"

	replace tclass = 1 if c2_k == 1 & ims_c_traj < -1 * `traj_sd'
	label define tclass 1 "Low risk - improving", add

	replace tclass = 2 if c2_k == 1 & ims_c_traj >= -1 * `traj_sd'
	label define tclass 2 "Low risk - neutral", add

	/* No Low risk deteriorating because that would imply -ve severity */

	replace tclass = 4 if c2_k == 2 & ims_c_traj < -1 * `traj_sd'
	label define tclass 4 "Medium risk - improving", add

	replace tclass = 5 if c2_k == 2 & ims_c_traj >= -1 * `traj_sd' & ims_c_traj < 0
	label define tclass 5 "Medium risk - neutral", add

	replace tclass = 6 if c2_k == 2 & ims_c_traj >= 0
	label define tclass 6 "Medium risk - deteriorating", add

	/* No high risk improving because that would imply a crazy severity */

	replace tclass = 8 if c2_k == 3 & ims_c_traj < 0
	label define tclass 8 "High risk - neutral", add

	replace tclass = 9 if c2_k == 3 & ims_c_traj >= 0
	label define tclass 9 "High risk - deteriorating", add

	label values tclass tclass
	tab tclass

	tabstat ims_c_traj, by(tclass) s(n mean sd q) format(%9.3g)

	cap drop tvector
	gen tvector = .
	label var tvector "Pre-admission trajectory"
	replace tvector = 1 if inlist(tclass,1,4)
	label define tvector 1 "Improving"
	replace tvector = 2 if inlist(tclass,2,5,8)
	label define tvector 2 "Neutral", add
	replace tvector = 3 if inlist(tclass,6,9)
	label define tvector 3 "Deteriorating", add
	label values tvector tvector

	tab c2_k tvector if m0

	table c2_k tvector if m0, contents(p25 ims_c_traj p75 ims_c_traj)

	save ../data/working_postflight_mi_`dataset'.dta, replace
}
