global debug = 0
if $debug {
    use ../data/working.dta, clear
}

sort icnno adno
gen id=_n
set seed 3001

stset date_trace, origin(time daicu) failure(dead) exit(time daicu+28)


count if _valid_row == 0

*  ============================================
*  = Report data quality issues as a reminder =
*  ============================================


tab _valid_row
duplicates example _list_unusual if _count_unusual > 0
duplicates example _list_imposs if _count_imposs > 0

keep if _valid_row
* TODO: 2012-11-26 - drop impossible values ... but revisit because these should not exist
replace lactate = . if lactate < 0

* ==================================================================================
* = Create study wide generic variables - that are not already made in python code =
* ==================================================================================


gen age = round((daicu - dob) / 365.25)
label var age "Age (yrs)"

gen white = inlist(ethnicity, 1,2,3)
label var white "Ethnicity - white"


* Now inspect key variables by sample
gen time2icu = floor(hours(icu_admit - v_timestamp))
* TODO: 2012-10-02 - this should not be necessary!!
replace time2icu = 0 if time2icu < 0
label var time2icu "Time to ICU (hrs)"

* NOTE: 2012-09-27 - get more precise survival timing for those who die in ICU
* Add one hour though else ICU discharge and last_trace at same time
* this would mean these records being dropped by stset
* CHANGED: 2012-10-02 - changed to 23:59:00 from 23:59:59 because of rounding errors
gen last_trace = cofd(date_trace) + hms(23,58,00)
replace last_trace = icu_discharge if dead_icu == 1 & !missing(icu_discharge)
format last_trace %tc
label var last_trace "Timestamp last event"


gen male=sex==2
label var male "Sex"
label define male 0 "Female" 1 "Male"
label values male male

gen sepsis1 = inlist(sepsis,3,4)
label var sepsis1 "Clinical sepsis"
label values sepsis1 truefalse

gen rxlimits = inlist(v_disposal,4,7)
label var rxlimits "Treatment limits at visit end"
label values rxlimits truefalse

gen dead28 = (date_trace - dofc(v_timestamp) <= 28 & dead)
replace dead28 = . if missing(date_trace)
label var dead28 "28d mortality"
label values dead28 truefalse

gen dead90 = (date_trace - dofc(v_timestamp) <= 90 & dead)
replace dead90 = . if missing(date_trace)
label var dead90 "90d mortality"
label values dead90 truefalse

rename icnarc_score ims1
rename imscore ims2
label var ims1 "ICNARC score (SPOT)"
label var ims2 "ICNARC score (CMPD)"

/*
NOTE: 2012-11-12 - this assumes that
all ICNARC scores within the 1st 24 hours are equivalent
*/
gen delta = ims2 - ims1
label var delta "ICNARC score delta (total diff)"
gen ims_traj = (ims2 - ims1) / (round(time2icu, 24) +1)
label var ims_traj "ICNARC score trajectory (per day)"

cap drop traj_cat
cap drop ims_traj_cat
gen ims_traj_cat = .
replace ims_traj_cat =  1   if ims_traj <= -10 & ims_traj_cat == .
replace ims_traj_cat =  2   if ims_traj <= -5 & ims_traj_cat == .
replace ims_traj_cat =  3   if ims_traj <= -2 & ims_traj_cat == .
replace ims_traj_cat =  4   if ims_traj <=  1 & ims_traj_cat == .
replace ims_traj_cat =  5   if ims_traj <=  4 & ims_traj_cat == .
replace ims_traj_cat =  6   if ims_traj <=  9 & ims_traj_cat == .
replace ims_traj_cat =  7   if ims_traj <=  14 & ims_traj_cat == .
replace ims_traj_cat =  8   if ims_traj >   14 & ims_traj_cat == .
cap label drop ims_traj_cat
label define ims_traj_cat ///
        1 "Decr - fast" ///
        2 "Decr - med" ///
        3 "Decr - slow" ///
        4 "No change" ///
        5 "Incr - slow" ///
        6 "Incr - med" ///
        7 "Incr - fast" ///
        8 "Incr - extreme"
label values ims_traj_cat ims_traj_cat
tab ims_traj_cat


/*
Diagnostic coding

 2.1.4.27.5 |        838       18.53       18.53
 2.1.4.27.1 |        278        6.15       24.68
2.2.12.35.2 |        183        4.05       28.73
 2.3.9.28.1 |        145        3.21       31.93
 2.7.1.13.2 |        139        3.07       35.01
 2.7.1.13.1 |        130        2.87       37.88
 2.7.1.13.4 |        127        2.81       40.69

 Pneumonia - no org
 Pneumonia - bacterial
 Septic shock
 Acute pancreatitis
 Acute renal failure



*/

cap drop dx_*
gen dx_pneum = regexm(raicu1, "[12]\.1\.4\.27\.+")
gen dx_pneum_v = regexm(raicu1, "[12]\.1\.4\.27\.3")
gen dx_pneum_b = regexm(raicu1, "[12]\.1\.4\.27\.[12]")
gen dx_pneum_u = regexm(raicu1, "[12]\.1\.4\.27\.5")
label var dx_pneum "Pneumonia"
label var dx_pneum_v "Pneumonia - viral"
label var dx_pneum_b "Pneumonia - bacterial"
label var dx_pneum_u "Pneumonia - unknown"

gen dx_sepshock = regexm(raicu1, "[2]\.2\.12\.35\.2")
label var dx_sepshock "Septic shock"

gen dx_acpanc = regexm(raicu1, "[2]\.3\.9\.28\.1")
label var dx_acpanc "Acute Pancreatitis"

gen dx_arf = regexm(raicu1, "[2]\.7\.1\.13\.[1-9]+")
label var dx_arf "Acute Renal Failure"

egen dx_other = anymatch(dx_*), values(1)
replace dx_other = !dx_other
label var dx_other "Other diagnosis"

cap drop dx_cat
gen dx_cat = 0 if dx_other
replace dx_cat = 1 if dx_pneum_v
replace dx_cat = 2 if dx_pneum_b
replace dx_cat = 3 if dx_pneum_u
replace dx_cat = 4 if dx_sepshock
replace dx_cat = 5 if dx_acpanc
replace dx_cat = 6 if dx_arf
label var dx_cat "Diagnosis - categorical"
cap label drop dx_cat
label define dx_cat 0 "Other" 1 "Pneum - viral" 2 "Pneum - bact" ///
    3 "Pneum - unknown" 4 "Septic shock" 5 "Acute pancreatitis" ///
    6 "Acute renal failure"
label values dx_cat dx_cat
tab dx_cat

d dx_*

*  ====================================================
*  = Derive specific spot-cmpd physiology comparisons =
*  ====================================================

/* Heart rate */
cap drop hr1 hr2
ren hrate hr1
label var hr1 "Heart rate - SPOT"
gen hr2 = hhr
replace hr2 = lhr if hr2 == .
label var hr1 "Heart rate - CMPD"


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
cap drop bps1 bps2
rename bpsys bps1
label var bps1 "SBP - SPOT"
gen bps2 = lsys
replace bps2 = hsys if bps2 == .
label var bps1 "SBP - CMPD"

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
cap drop temp1 temp2
rename temperature temp1
label var temp1 "Temp - SPOT"
gen temp2 = hctemp
replace temp2 = hnctemp if temp2 == .
label var temp2 "Temp - CMPD"
su temp1 temp2

foreach var of varlist temp1 temp2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 12 if `var' <= 33.9 & `var'_wt == .
    replace `var'_wt = 7 if `var' <= 35.9 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 38.4 & `var'_wt == .
    replace `var'_wt = 1 if `var' > 41 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    replace `var'_wt = . if `var' < 25
    bys `var'_wt: su `var'
}

/* Respiratory rate */
cap drop rr1 rr2
rename rrate rr1
label var rr1 "Resp rate - SPOT"
gen rr2 = lnvrr if lnvrr != 0
replace rr2 = hnvrr if hnvrr != 0 & rr2 == .
label var rr2 "Resp rate - CMPD"
su rr1 rr2

foreach var of varlist rr1 rr2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 1 if `var' <= 5 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 11 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 13 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 24 & `var'_wt == .
    replace `var'_wt = 5 if `var' > 25 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* P:F ratio */
cap drop pf1 pf2
replace pao2 = pao2 / 7.7 if abgunit == 2
gen pf1 = pao2 / abgfio2 * 100
gen pf2 = ilpo / filpo
label var pf1 "P:F ratio - SPOT"
label var pf2 "P:F ratio - CMPD"
su pf1 pf2

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
cap drop ph1 ph2
ren ph ph1
label var ph1 "pH - SPOT"
ren lph_v3 ph2
label var ph2 "pH - CMPD"
/* Temp fix to avoid H+ data */
replace ph2 = .a if ph2 > 8 | ph2 < 6.5
su ph1 ph2

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
cap drop urea1 urea2
ren urea urea1
ren hu urea2
label var urea1 "Urea - SPOT"
label var urea2 "Urea - CMPD"
su urea1 urea2

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
cap drop cr1 cr2
rename creatinine cr1
gen cr2 = hcreat
replace cr2 = lcreat if missing(hcreat)
label var cr1 "Creatinine - SPOT"
label var cr2 "Creatinine - CMPD"
su cr1 cr2

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
gen na2 = lna
replace na2 = hna if na2 == .
label var na2 "Sodium - CMPD"
/* Some v low sodiums in CMPD ... not possible */
replace na2 = .a if na2 < 80
ren sodium na1
label var na1 "Sodium - SPOT"
replace na1 = .a if na1 < 80
gen na_traj = (na2 - na1) / (round(time2icu, 24) + 1)
label var na_traj "Sodium slope"

foreach var of varlist na1 na2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 4 if `var' <= 129 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 149 & `var'_wt == .
    replace `var'_wt = 4 if `var' <= 154 & `var'_wt == .
    replace `var'_wt = 7 if `var' <= 159 & `var'_wt == .
    replace `var'_wt = 8 if `var' >  160 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* Urine */
cap drop urin1 urin2
rename uvol1h urin1

cap drop yulos
gen yulos = round(hours(cofd(ddicu) + tdicu - cofd(daicu) - taicu)) if dead_icu == 0
replace yulos = round(hours(cofd(dod) + tod - cofd(daicu) - taicu)) if dead_icu == 1
su yulos, d
label var yulos "ICU LOS (hrs)"
gen urin2 = up if yulos > 24
replace urin2 = round(up * (24/yulos)) if missing(urin2)
replace urin2 = urin2 / 24

replace urin1 = .a if urin1 > 250
replace urin2 = .a if urin2 > 250
label var urin1 "Urine ml/hr - SPOT"
label var urin2 "Urine ml/hr - CMPD"
su urin1 urin2

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
cap drop wcc1 wcc2
ren wcc wcc1
label var wcc1 "WCC - SPOT"
gen wcc2 = hwbc
replace wcc2 = lwbc if wcc2 == .
label var wcc2 "WCC - CMPD"
su wcc1 wcc2

foreach var of varlist wcc1 wcc2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 6 if `var' <= 0.6 & `var'_wt == .
    replace `var'_wt = 3 if `var' <= 2.9 & `var'_wt == .
    replace `var'_wt = 0 if `var' <= 14.9 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 39.9 & `var'_wt == .
    replace `var'_wt = 4 if `var' >  39.9 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}

/* GCS */
cap drop gcs1 gcs2
ren gcst gcs1
label var gcs1 "GCS - SPOT"
ren ltot gcs2
label var gcs2 "GCS - CMPD"
replace gcs2 = .a if gcs2 < 3
su gcs1 gcs2

* NOTE: 2012-11-15 - does not include the weighting for sedated or paralysed
foreach var of varlist gcs1 gcs2 {
    cap drop `var'_wt
    gen `var'_wt = .
    replace `var'_wt = 11 if `var' <= 3 & `var'_wt == .
    replace `var'_wt = 9 if `var' <= 4 & `var'_wt == .
    replace `var'_wt = 6 if `var' <= 5 & `var'_wt == .
    replace `var'_wt = 4 if `var' <= 6 & `var'_wt == .
    replace `var'_wt = 2 if `var' <= 13 & `var'_wt == .
    replace `var'_wt = 1 if `var' <= 14 & `var'_wt == .
    replace `var'_wt = 0 if `var' == 15 & `var'_wt == .
    replace `var'_wt = . if `var' >= .
    bys `var'_wt: su `var'
}


/* Lactate */
cap drop lac1 lac2
ren lactate lac1
rename hbl lac2
label var lac1 "Lactate - SPOT"
label var lac2 "Lactate - CMPD"
su lac1 lac2

/* Platelets */
ren lpc plat2
ren platelets plat1
label var plat1 "Platelets - SPOT"
label var plat2 "Platelets - CMPD"
gen plat_traj = (plat2 - plat1) / (round(time2icu, 24) + 1)
label var plat_traj "Platelets slope"


*  =================================
*  = Create your own ICNARC scores =
*  =================================
cap drop ims1_miss ims2_miss ims_c1 ims_c2 ims_c_traj ims1_miss ims2_miss
/* NOTE: 2012-11-15 - egen rowmiss does not catch .a, .b etc */
egen ims1_miss = rowmiss(*1_wt)
egen ims2_miss = rowmiss(*2_wt)
tab ims1_miss ims2_miss
egen ims_c1 = rowtotal(*1_wt) if ims1_miss == 0 & ims2_miss == 0
egen ims_c2 = rowtotal(*2_wt) if ims1_miss == 0 & ims2_miss == 0
label var ims_c1 "ICNARC score (complete) - Ward"
label var ims_c2 "ICNARC score (complete) - ICU"
gen ims_c_traj = (ims_c2 - ims_c1) / (round(time2icu, 24) + 1)
label var ims_c_traj "IMscore - complete - slope"

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

gen ims_ms_traj = (ims_ms2 - ims_ms1) / (round(time2icu, 24) + 1)
label var ims_ms_traj "ICNARC score (partial) - trajectory"
su ims_ms_traj, d




*  ================
*  = Trajectories =
*  ================
cap drop pf_traj traj_urin cr_traj
drop pf_ratio
gen pf_traj = (pf2 - pf1) / (round(time2icu, 24) + 1)
label var pf_traj "P:F slope"
gen traj_urin = (urin2 - urin1) / (round(time2icu, 24) + 1)
label var traj_urin "Urine output slope"
gen cr_traj = (cr2 - cr1) / (round(time2icu, 24) + 1)
label var cr_traj "Creatinine slope"
gen lac_traj = (lac2 - lac1) / (round(time2icu, 24) + 1)
label var lac_traj "Lactate slope"
su lac* cr* pf* ims* na* *urin* , sep(4)

