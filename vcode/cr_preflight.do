local debug = 1
if `debug' {
	use ../data/working.dta, clear
}

sort icnno adno
gen id=_n
set seed 3001


count if _valid_row == 0

*  ============================================
*  = Report data quality issues as a reminder =
*  ============================================


tab _valid_row
duplicates example _list_unusual if _count_unusual > 0
duplicates example _list_imposs if _count_imposs > 0

keep if _valid_row

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
label var delta "ICNARC score delta"
gen traj = (ims2 - ims1) / time2icu
label var traj "ICNARC score trajectory"

cap drop traj_cat
egen traj_cat = cut(traj), at(-40,-20,-10,-4,-2,0,2,4,10,20,40) label
label var traj_cat "Trajectory - categorical"
tab traj_cat

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
/* P:F ratio */
cap drop pf1 pf2
replace pao2 = pao2 / 7.7 if abgunit == 2
gen pf1 = pao2 / abgfio2 * 100
gen pf2 = ilpo / filpo
label var pf1 "P:F ratio - SPOT"
label var pf2 "P:F ratio - CMPD"
su pf1 pf2

/* Creatinine and urine */
cap drop cr1 cr2
rename creatinine cr1
gen cr2 = hcreat
replace cr2 = lcreat if missing(hcreat)
label var cr1 "Creatinine - SPOT"
label var cr2 "Creatinine - CMPD"
su cr1 cr2

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










