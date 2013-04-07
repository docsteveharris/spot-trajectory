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
local traj_x 12

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
