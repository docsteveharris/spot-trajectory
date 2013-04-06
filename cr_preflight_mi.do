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
	local traj_x 12
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

	*  ============================
	*  = Define ICNARC score grid =
	*  ============================

	cap drop ims_c2_k
	egen ims_c2_k = cut(ims_c2), at(0, 15, 25 100) icodes
	replace ims_c2_k = ims_c2_k + 1
	label var ims_c2_k "ICNARC APS - CMPD"
	cap label drop ims_c2_k
	label define ims_c2_k 1 "Low risk" 2 "Medium risk" 3 "High risk"
	label values ims_c2_k ims_c2_k
	tabstat ims_c_traj, by(ims_c2_k) s(n mean sd q) format(%9.3g)

	/*
	NOTE: 2013-04-06 - arbitrary definition of trajectory class
	- deteriorating (any increase in severity)
	- neutral is in the range of -1sd to zero
	- improving is any fall greater than 1sd
	Now divide the classes
	- ims_c2_k = 1 = lowest admission severity
		- roughly the same
		- markedly improved

	*/

	qui su ims_c_traj
	local traj_sd = round(r(sd))
	cap drop ims_tclass
	gen ims_tclass = 0
	label var ims_tclass "ICNARC trajectory class"
	cap label drop ims_tclass
	label define ims_tclass 0 "Unclassified"

	replace ims_tclass = 1 if ims_c2_k == 1 & ims_c_traj < -1 * `traj_sd'
	label define ims_tclass 1 "Low risk - improving", add

	replace ims_tclass = 2 if ims_c2_k == 1 & ims_c_traj >= -1 * `traj_sd'
	label define ims_tclass 2 "Low risk - neutral", add

	/* No Low risk deteriorating because that would imply -ve severity */

	replace ims_tclass = 4 if ims_c2_k == 2 & ims_c_traj < -1 * `traj_sd'
	label define ims_tclass 4 "Medium risk - improving", add

	replace ims_tclass = 5 if ims_c2_k == 2 & ims_c_traj >= -1 * `traj_sd' & ims_c_traj < 0
	label define ims_tclass 5 "Medium risk - neutral", add

	replace ims_tclass = 6 if ims_c2_k == 2 & ims_c_traj >= 0
	label define ims_tclass 6 "Medium risk - deteriorating", add

	/* No high risk improving because that would imply a crazy severity */

	replace ims_tclass = 8 if ims_c2_k == 3 & ims_c_traj < 0
	label define ims_tclass 8 "High risk - neutral", add

	replace ims_tclass = 9 if ims_c2_k == 3 & ims_c_traj >= 0
	label define ims_tclass 9 "High risk - deteriorating", add

	label values ims_tclass ims_tclass
	tab ims_tclass

	tabstat ims_c_traj, by(ims_tclass) s(n mean sd q) format(%9.3g)

	cap drop ims_tvector
	gen ims_tvector = .
	label var ims_tvector "Pre-admission ICNARC trajectory"
	replace ims_tvector = 1 if inlist(ims_tclass,1,4)
	label define ims_tvector 1 "Improving"
	replace ims_tvector = 2 if inlist(ims_tclass,2,5,8)
	label define ims_tvector 2 "Neutral", add
	replace ims_tvector = 3 if inlist(ims_tclass,6,9)
	label define ims_tvector 3 "Deteriorating", add
	label values ims_tvector ims_tvector

	tab ims_c2_k ims_tvector 

	table ims_c2_k ims_tvector , contents(p25 ims_c_traj p75 ims_c_traj)


	*  =======================
	*  = Define lactate grid =
	*  =======================

	/* Lactate is much more skewed than ICNARC score therefore transform */
	su lac2, d

	cap drop lac2_ln lac2_bc
	lnskew0 lac2_ln =lac2, level(90)
	bcskew0 lac2_bc =lac2, level(90)
	global bc_lambda = r(lambda)

	su lac2 lac2_bc, d


	// CHANGED: 2013-04-06 - you are working with the transform
	cap drop lac2_k
	qui su lac2_bc, d
	local min = r(min) - 1
	local max = r(max) + 1
	egen lac2_k = cut(lac2_bc), at(`min' `=r(p25)'  `=r(p75)' `max' ) icodes
	replace lac2_k = lac2_k + 1
	label var lac2_k "Lactate - CMPD"
	cap label drop lac2_k
	label define lac2_k 1 "Low risk" 2 "Medium risk" 3 "High risk"
	label values lac2_k lac2_k

	tab lac2_k

	* tabstat dead28, by(lac2_k) s(n mean sd q) format(%9.3g)
	tabstat lac_traj, by(lac2_k) s(n mean sd q) format(%9.3g)

	/*
	NOTE: 2013-04-06 - arbitrary definition of trajectory class
	- deteriorating (any increase in severity)
	- neutral is in the range of 0.5 SD below zero
	- improving is any fall greater than 1sd
	Now divide the classes
	- lac2_k = 1 = lowest admission severity
		- roughly the same
		- markedly improved

	*/

	su lac_traj, d
	* CHANGED: 2013-04-06 - define boundary as 1 SD above below (scaled by kurtosis)
	global boundary = 1
	cap drop lac_tclass
	gen lac_tclass = 0 if lac_traj != .
	label var lac_tclass "Lactate trajectory class"
	cap label drop lac_tclass
	label define lac_tclass 0 "Unclassified"

	replace lac_tclass = 1 if lac2_k == 1 & lac_traj < -1 * $boundary 
	label define lac_tclass 1 "Low risk - improving", add

	replace lac_tclass = 2 if lac2_k == 1 & lac_traj >= -1 * $boundary & lac_traj != .
	label define lac_tclass 2 "Low risk - neutral", add

	/* No Low risk deteriorating because that would imply -ve severity */

	replace lac_tclass = 4 if lac2_k == 2 & lac_traj < -1 * $boundary
	label define lac_tclass 4 "Medium risk - improving", add

	replace lac_tclass = 5 if lac2_k == 2 & lac_traj >= -1 * $boundary & lac_traj < $boundary
	label define lac_tclass 5 "Medium risk - neutral", add

	replace lac_tclass = 6 if lac2_k == 2 & lac_traj >= $boundary
	label define lac_tclass 6 "Medium risk - deteriorating", add

	/* No high risk improving because that would imply a crazy severity */

	replace lac_tclass = 8 if lac2_k == 3 & lac_traj < $boundary
	label define lac_tclass 8 "High risk - neutral", add

	replace lac_tclass = 9 if lac2_k == 3 & lac_traj >= $boundary
	label define lac_tclass 9 "High risk - deteriorating", add

	replace lac_tclass = . if missing(lac_traj, lac2_k)
	label values lac_tclass lac_tclass
	tab lac_tclass

	tabstat lac_traj, by(lac_tclass) s(n mean sd q) format(%9.3g)

	cap drop lac_tvector
	gen lac_tvector = .
	label var lac_tvector "Pre-admission lactate trajectory"
	replace lac_tvector = 1 if inlist(lac_tclass,1,4)
	cap label drop lac_tvector
	label define lac_tvector 1 "Improving"
	replace lac_tvector = 2 if inlist(lac_tclass,2,5,8)
	label define lac_tvector 2 "Neutral", add
	replace lac_tvector = 3 if inlist(lac_tclass,6,9)
	label define lac_tvector 3 "Deteriorating", add
	label values lac_tvector lac_tvector

	tab lac2_k lac_tvector 

table lac2_k lac_tvector , contents(p25 lac_traj p75 lac_traj)

	save ../data/working_postflight_mi_`dataset'.dta, replace
}

exit
// inspect the imputed completed scores and the 'true' ICNARC score
use ../data/working_postflight_mi_plus, clear
merge m:1 id using ../data/working_postflight, keepusing(ims1 ims2)
drop if m0
collapse (mean) ims_c2 ims2, by(id)
su ims_c2 ims2
qqplot ims_c2 ims2 

