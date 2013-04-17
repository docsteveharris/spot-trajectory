* ============================================
* = Prepare severity scores and trajectories =
* ============================================

/*
- best to use mean value rather than highest or lowest
- although in the end you will need to run sensitivity analyses for all
*/

// check to see if the MI command worked OK (if called)
lookfor _mi_m
if !missing(r(varlist)) {
	local im_vars ///
		hr1 bps1 temp1 rr1 urea1 cr1 na1 wcc1 ///
		urin1 gcs1 pf1 ph1 ///
		hr2 bps2 temp2 rr2 urea2 cr2 na2 wcc2 ///
		urin2 gcs2 pf2 ph2

	foreach var of local im_vars {
		di "Checking: `var'"
		count if `var' == . & _mi_m > 0
		assert r(N) == 0
	}
}


/* Heart rate */
foreach var of varlist hr1 hr2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 14 if `var' <= 39
    replace `var'_wt = 0 if `var' <= 109 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 119 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 139 & `var'_wt == .
    replace `var'_wt = 3 if `var' > 139 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}


/* BP systolic */
foreach var of varlist bps1 bps2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 15 if `var' <= 49 & `var'_wt == .
    replace `var'_wt = 9 if `var' <= 59 & `var'_wt == .
    replace `var'_wt = 6 if `var' <= 69 & `var'_wt == .
    replace `var'_wt = 4 if `var' <= 79 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 99 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 179 & `var'_wt == .
    replace `var'_wt = 7 if `var' <= 219 & `var'_wt == .
    replace `var'_wt = 16 if `var' > 219 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* Temperature */

foreach var of varlist temp1 temp2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 12 if `var' <= 33.9 & `var'_wt == .
    replace `var'_wt = 7 if `var' <= 35.9 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 38.4 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 41 & `var'_wt == .
    replace `var'_wt = 1 if `var' > 41 & `var'_wt == .
    // CHANGED: 2013-04-04 - replace missing and nonsense values with 0 weights
    replace `var'_wt = 0 if `var' >= .
    replace `var'_wt = 0 if `var' < 25
    bys `var'_wt: su `var'
}

/* Respiratory rate */
foreach var of varlist rr1 rr2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 1 if `var' <= 5 & `var'_wt == .
    replace `var'_wt = 0 if `var' < 12 & `var'_wt == .
    replace `var'_wt = 1 if `var' < 14 & `var'_wt == .
    replace `var'_wt = 2 if `var' < 25 & `var'_wt == .
    replace `var'_wt = 5 if `var' >= 25 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* P:F ratio */
// NOTE: 2013-04-04 - replace with room air / unintubated to generate weights
replace rxfio2 = 0 if rxfio2 == .
foreach var of varlist pf1 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 6 if `var' <=    13 & !inlist(rxfio2,1,2,3) & `var'_wt == .
    replace `var'_wt = 3 if `var' <=    27 & !inlist(rxfio2,1,2,3) & `var'_wt == .
    replace `var'_wt = 0 if `var' >     27 & !inlist(rxfio2,1,2,3) & `var'_wt == .
    tab `var'_wt
    replace `var'_wt = 8 if `var' <=    13 & inlist(rxfio2,1,2,3) & `var'_wt == .
    replace `var'_wt = 5 if `var' <=    27 & inlist(rxfio2,1,2,3) & `var'_wt == .
    replace `var'_wt = 3 if `var' >     27 & inlist(rxfio2,1,2,3) & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    tab `var'_wt
    bys `var'_wt: su `var'
}

replace intilpo = 0 if intilpo == .
foreach var of varlist pf2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 6 if `var' <=    13 & intilpo == 0 & `var'_wt == .
    replace `var'_wt = 3 if `var' <=    27 & intilpo == 0 & `var'_wt == .
    replace `var'_wt = 0 if `var' >     27 & intilpo == 0 & `var'_wt == .
    replace `var'_wt = 8 if `var' <=    13 & intilpo == 1 & `var'_wt == .
    replace `var'_wt = 5 if `var' <=    27 & intilpo == 1 & `var'_wt == .
    replace `var'_wt = 3 if `var' >     27 & intilpo == 1 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* pH */
foreach var of varlist ph1 ph2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 4 if `var' <= 7.14 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 7.24 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 7.32 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 7.49 & `var'_wt == .
    replace `var'_wt = 4 if `var' >  7.49 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* Urea */
foreach var of varlist urea1 urea2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 0 if `var' <= 6.1 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 7.1 & `var'_wt == .
    replace `var'_wt = 3 if `var' <= 14.3 & `var'_wt == .
    replace `var'_wt = 5 if `var' >  14.3 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* Creatinine */
foreach var of varlist cr1 cr2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 0 if `var' <= 0.5 * 88.4 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 1.5 * 88.4 & `var'_wt == .
    replace `var'_wt = 4 if `var' >  1.5 * 88.4 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* Sodium */

foreach var of varlist na1 na2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 4 if `var' <= 129 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 149 & `var'_wt == .
    replace `var'_wt = 4 if `var' <= 154 & `var'_wt == .
    replace `var'_wt = 7 if `var' <= 160 & `var'_wt == .
    replace `var'_wt = 8 if `var' >  160 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* Urine */

foreach var of varlist urin1 urin2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 7 if `var' <= 399 / 24 & `var'_wt == .
    replace `var'_wt = 6 if `var' <= 599 / 24 & `var'_wt == .
    replace `var'_wt = 5 if `var' <= 899 / 24 & `var'_wt == .
    replace `var'_wt = 3 if `var' <= 1499 / 24 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 1999 / 24 & `var'_wt == .
    replace `var'_wt = 0 if `var' >  1999 / 24 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* White cell count */
foreach var of varlist wcc1 wcc2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 6 if `var' <= 0.9 & `var'_wt == .
    replace `var'_wt = 3 if `var' <= 2.9 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 14.9 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 39.9 & `var'_wt == .
    replace `var'_wt = 4 if `var' >  39.9 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* GCS */
* NOTE: 2012-11-15 - does not include the weighting for sedated or paralysed
foreach var of varlist gcs1 gcs2 {
    cap drop `var'_wt
    // CHANGED: 2013-04-06 - default weight zero (but still missing if var is missing)
    gen `var'_wt = 0
    replace `var'_wt = 11 if `var' == 3 & `var'_wt == .
    replace `var'_wt = 9 if `var' == 4 & `var'_wt == .
    replace `var'_wt = 6 if `var' == 5 & `var'_wt == .
    replace `var'_wt = 4 if `var' == 6 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 13 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 14 & `var'_wt == .
    replace `var'_wt = 0 if `var' == 15 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

// check that the weight procedure worked and all weight calculated
lookfor _mi_m
if !missing(r(varlist)) {
	local im_vars ///
		hr1 bps1 temp1 rr1 urea1 cr1 na1 wcc1 ///
		urin1 gcs1 pf1 ph1 ///
		hr2 bps2 temp2 rr2 urea2 cr2 na2 wcc2 ///
		urin2 gcs2 pf2 ph2

	foreach var of local im_vars {
		di "Checking: `var'_wt to ensure imputation has been sucessful"
		count if `var'_wt == . & _mi_m > 0
		assert r(N) == 0
	}
}

*  =================================
*  = Create your own ICNARC scores =
*  =================================

// Complete scores only
/* NOTE: 2012-11-15 - egen rowmiss does not catch .a, .b etc */
cap drop ims1_miss ims2_miss ims_c1 ims_c2 ims_c_traj
egen ims1_miss = rowmiss(*1_wt)
egen ims2_miss = rowmiss(*2_wt)
tab ims1_miss ims2_miss

egen ims_c1 = rowtotal(*1_wt) if ims1_miss == 0 & ims2_miss == 0
label var ims_c1 "ICNARC score (complete) - Ward"
egen ims_c2 = rowtotal(*2_wt) if ims1_miss == 0 & ims2_miss == 0
label var ims_c2 "ICNARC score (complete) - ICU"


// Partial (drops GCS, urine, pH, and PF)
cap drop ims1_miss_some ims2_miss_some ims_ms1 ims_ms2 ims_ms_traj
egen ims1_miss_some = rowmiss(hr1 bps1 rr1 cr1 na1 wcc1 temp1 urea1)
egen ims2_miss_some = rowmiss(hr2 bps2 rr2 cr2 na2 wcc2 temp2 urea2)
tab ims1_miss_some ims2_miss_some

egen ims_ms1 = rowtotal(hr1_wt bps1_wt rr1_wt cr1_wt na1_wt wcc1_wt ///
     temp1_wt urea1_wt) if ims1_miss_some == 0 & ims2_miss_some == 0
egen ims_ms2 = rowtotal(hr2_wt bps2_wt rr2_wt cr2_wt na2_wt wcc2_wt ///
     temp2_wt urea2_wt) if ims1_miss_some == 0 & ims2_miss_some == 0

label var ims_ms1 "ICNARC score (partial) - Ward"
label var ims_ms2 "ICNARC score (partial) - ICU"

// Partial with ABG (drops GCS, urine)
cap drop ims1_miss_abg ims2_miss_abg ims_abg1 ims_abg2 ims_abg_traj
egen ims1_miss_abg = rowmiss(hr1 bps1 rr1 cr1 na1 wcc1 temp1 urea1 pf1 ph1)
egen ims2_miss_abg = rowmiss(hr2 bps2 rr2 cr2 na2 wcc2 temp2 urea2 pf1 ph1)
tab ims1_miss_abg ims2_miss_abg

egen ims_abg1 = rowtotal(hr1_wt bps1_wt rr1_wt cr1_wt na1_wt wcc1_wt ///
     temp1_wt urea1_wt ph1_wt pf1_wt) if ims1_miss_abg == 0 & ims2_miss_abg == 0
egen ims_abg2 = rowtotal(hr2_wt bps2_wt rr2_wt cr2_wt na2_wt wcc2_wt ///
     temp2_wt urea2_wt ph1_wt pf1_wt) if ims1_miss_abg == 0 & ims2_miss_abg == 0

label var ims_abg1 "ICNARC score (+ABG) - Ward"
label var ims_abg2 "ICNARC score (+ABG) - ICU"


*  =======================================================
*  = Define a bastardised NEWS score for ward and ICNARC =
*  =======================================================

* cap drop news1 news2
* // respiratory rate
* foreach var of varlist rr1 rr2 {
*     cap drop `var'_wt_news
*     gen `var'_wt_news = .
*     replace `var'_wt_news = 3 if `var' <= 8 & `var'_wt_news == .
*     replace `var'_wt_news = 1 if `var' <= 11 & `var'_wt_news == .
*     replace `var'_wt_news = 0 if `var' <= 20 & `var'_wt_news == .
*     replace `var'_wt_news = 2 if `var' <= 24 & `var'_wt_news == .
*     replace `var'_wt_news = 5 if `var' > 25 & `var'_wt_news == .
*     replace `var'_wt_news = . if `var' >= .
*     bys `var'_wt_news: su `var'
* }
* su rr*_news

// oxygen saturations
* cap drop sats1_wt_news sats2_wt_news
* replace sats1_wt_news = 2 if fio2_std

*  ================
*  = Trajectories =
*  ================
local traj_x 24

cap drop ims_c_traj
gen ims_c_traj = (ims_c2 - ims_c1) / (round(time2icu, `traj_x') + 1)
label var ims_c_traj "IMscore - complete - slope"

cap drop ims_ms_traj
gen ims_ms_traj = (ims_ms2 - ims_ms1) / (round(time2icu, `traj_x') + 1)
label var ims_ms_traj "ICNARC score (partial) - trajectory"

cap drop ims_abg_traj
gen ims_abg_traj = (ims_abg2 - ims_abg1) / (round(time2icu, `traj_x') + 1)
label var ims_abg_traj "ICNARC score (+ABG) - trajectory"

cap drop pf_traj
gen pf_traj = (pf2 - pf1) / (round(time2icu, `traj_x') + 1)
label var pf_traj "P:F slope"

cap drop traj_urin
gen traj_urin = (urin2 - urin1) / (round(time2icu, `traj_x') + 1)
label var traj_urin "Urine output slope"

cap drop cr_traj
gen cr_traj = (cr2 - cr1) / (round(time2icu, `traj_x') + 1)
label var cr_traj "Creatinine slope"

cap drop lac_traj
gen lac_traj = (lac2 - lac1) / (round(time2icu, `traj_x') + 1)
label var lac_traj "Lactate slope"

cap drop urea_traj
gen urea_traj = (urea2 - urea1) / (round(time2icu, `traj_x') + 1)
label var urea_traj "Urea slope"

cap drop na_traj
gen na_traj = (na2 - na1) / (round(time2icu, 24) + 1)
label var na_traj "Sodium slope"

cap drop plat_traj
gen plat_traj = (plat2 - plat1) / (round(time2icu, 24) + 1)
label var plat_traj "Platelets slope"

* su lac* cr* pf* ims* na* *urin* , sep(4)


*  =============================================
*  = ICNARC COMPLETE CASES - BACKWARDS LOOKING =
*  =============================================

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

*  =============================================
*  = ICNARC COMPLETE CASES - FORWARDS LOOKING =
*  =============================================

cap drop ims_c1_k
egen ims_c1_k = cut(ims_c1), at(0, 15, 25 100) icodes
replace ims_c1_k = ims_c1_k + 1
label var ims_c1_k "ICNARC APS - Ward"
cap label drop ims_c1_k
label define ims_c1_k 1 "Low risk" 2 "Medium risk" 3 "High risk"
label values ims_c1_k ims_c1_k
tabstat ims_c_traj, by(ims_c1_k) s(n mean sd q) format(%9.3g)


su ims_c_traj
local traj_sd = round(r(sd))
cap drop ims_tclass_fwd
gen ims_tclass_fwd = 0
label var ims_tclass_fwd "ICNARC trajectory class (forwards)"
cap label drop ims_tclass_fwd
label define ims_tclass_fwd 0 "Unclassified"

/* DROP THIS - cannot be low risk and go on and improve */
* replace ims_tclass_fwd = 1 if ims_c2_k == 1 & ims_c_traj < -1 * `traj_sd'
* label define ims_tclass_fwd 1 "Low risk - improving", add

su ims_c_traj, d
replace ims_tclass_fwd = 2 if ims_c1_k == 1 & ims_c_traj < 0
label define ims_tclass_fwd 2 "Low risk - neutral", add

* CHANGED: 2013-04-16 - Low risk deteriorating now possible
replace ims_tclass_fwd = 3 if ims_c1_k == 1 & ims_c_traj >= 0
label define ims_tclass_fwd 3 "Low risk - deteriorating", add
tab ims_tclass_fwd

* MEDIUM
replace ims_tclass_fwd = 4 if ims_c1_k == 2 & ims_c_traj < -1 * `traj_sd'
label define ims_tclass_fwd 4 "Medium risk - improving", add

replace ims_tclass_fwd = 5 if ims_c1_k == 2 & ims_c_traj >= -1 * `traj_sd' & ims_c_traj < 0
label define ims_tclass_fwd 5 "Medium risk - neutral", add

replace ims_tclass_fwd = 6 if ims_c1_k == 2 & ims_c_traj >= 0
label define ims_tclass_fwd 6 "Medium risk - deteriorating", add

/* SEVERE - now possible to have severe improving */
replace ims_tclass_fwd = 7 if ims_c1_k == 3 & ims_c_traj < -1 * `traj_sd'
label define ims_tclass_fwd 7 "High risk - improving", add

replace ims_tclass_fwd = 8 if ims_c1_k == 3 & ims_c_traj >= -1 * `traj_sd' 
label define ims_tclass_fwd 8 "High risk - neutral", add

/* No longer makes sens to have deteriorating high risk */
* replace ims_tclass_fwd = 9 if ims_c1_k == 3 & ims_c_traj >= 0
* label define ims_tclass_fwd 9 "High risk - deteriorating", add

label values ims_tclass_fwd ims_tclass_fwd
tab ims_tclass_fwd

tabstat ims_c_traj, by(ims_tclass_fwd) s(n mean sd q) format(%9.3g)

cap drop ims_tvector_fwd
cap label drop ims_tvector_fwd
gen ims_tvector_fwd = .
label var ims_tvector_fwd "Pre-admission ICNARC trajectory"
replace ims_tvector_fwd = 1 if inlist(ims_tclass_fwd,1,4,7)
label define ims_tvector_fwd 1 "Improving"
replace ims_tvector_fwd = 2 if inlist(ims_tclass_fwd,2,5,8)
label define ims_tvector_fwd 2 "Neutral", add
replace ims_tvector_fwd = 3 if inlist(ims_tclass_fwd,3,6,9)
label define ims_tvector_fwd 3 "Deteriorating", add
label values ims_tvector_fwd ims_tvector_fwd

tab ims_c1_k ims_tvector_fwd

table ims_c1_k ims_tvector_fwd , contents(p25 ims_c_traj p75 ims_c_traj)

*  =========================================
*  = ICNARC partial cases - with ABG grid =
*  =========================================

cap drop ims_abg2_k
su ims_abg2, d
egen ims_abg2_k = cut(ims_abg2), at(0, `=r(p25)', `=r(p75)', 100) icodes
replace ims_abg2_k = ims_abg2_k + 1
label var ims_abg2_k "ICNARC ABG - CMPD"
cap label drop ims_abg2_k
label define ims_abg2_k 1 "Low risk" 2 "Medium risk" 3 "High risk"
label values ims_abg2_k ims_abg2_k
tabstat ims_abg_traj, by(ims_abg2_k) s(n mean sd q) format(%9.3g)

qui su ims_abg_traj
local traj_sd = round(r(sd))
cap drop ims_abg_tclass
gen ims_abg_tclass = 0
label var ims_abg_tclass "ICNARC trajectory class"
cap label drop ims_abg_tclass
label define ims_abg_tclass 0 "Unclassified"

replace ims_abg_tclass = 1 if ims_abg2_k == 1 & ims_abg_traj < -1 * `traj_sd'
label define ims_abg_tclass 1 "Low risk - improving", add

replace ims_abg_tclass = 2 if ims_abg2_k == 1 & ims_abg_traj >= -1 * `traj_sd'
label define ims_abg_tclass 2 "Low risk - neutral", add

/* No Low risk deteriorating because that would imply -ve severity */

replace ims_abg_tclass = 4 if ims_abg2_k == 2 & ims_abg_traj < -1 * `traj_sd'
label define ims_abg_tclass 4 "Medium risk - improving", add

replace ims_abg_tclass = 5 if ims_abg2_k == 2 & ims_abg_traj >= -1 * `traj_sd' & ims_abg_traj < 0
label define ims_abg_tclass 5 "Medium risk - neutral", add

replace ims_abg_tclass = 6 if ims_abg2_k == 2 & ims_abg_traj >= 0
label define ims_abg_tclass 6 "Medium risk - deteriorating", add

/* No high risk improving because that would imply a crazy severity */

replace ims_abg_tclass = 8 if ims_abg2_k == 3 & ims_abg_traj < 0
label define ims_abg_tclass 8 "High risk - neutral", add

replace ims_abg_tclass = 9 if ims_abg2_k == 3 & ims_abg_traj >= 0
label define ims_abg_tclass 9 "High risk - deteriorating", add

label values ims_abg_tclass ims_abg_tclass
tab ims_abg_tclass

tabstat ims_abg_traj, by(ims_abg_tclass) s(n mean sd q) format(%9.3g)

cap drop ims_abg_tvector
gen ims_abg_tvector = .
label var ims_abg_tvector "Pre-admission ICNARC (+ABG) trajectory"
replace ims_abg_tvector = 1 if inlist(ims_abg_tclass,1,4)
label define ims_abg_tvector 1 "Improving"
replace ims_abg_tvector = 2 if inlist(ims_abg_tclass,2,5,8)
label define ims_abg_tvector 2 "Neutral", add
replace ims_abg_tvector = 3 if inlist(ims_abg_tclass,6,9)
label define ims_abg_tvector 3 "Deteriorating", add
label values ims_abg_tvector ims_abg_tvector

tab ims_abg2_k ims_abg_tvector

table ims_abg2_k ims_abg_tvector , contents(p25 ims_abg_traj p75 ims_abg_traj)


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
