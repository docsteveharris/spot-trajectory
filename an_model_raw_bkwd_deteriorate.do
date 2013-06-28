*  =============================================
*  = Sensitivity analysis - deteriorating only =
*  =============================================

/*
created:	130408
modified:	130623

TODO: 2013-06-23 - need to fix the ranges for the models
	should not allow -ve trajectories in medium only margins
	given that these don't exist in the model

*/

GenericSetupSteveHarris spot_traj an_model_raw_bkwd_det, logon
if c(os) == "MacOSX" global gext pdf
if c(os) == "MacOSX" global gext_other eps
if c(os) != "MacOSX" global gext eps
if c(os) != "MacOSX" global gext_other pdf

global debug 0
set scheme shred


*  ============================
*  = Bring in the MI data set =
*  ============================
local physiology working_postflight_mi_plus_surv
use ../data/`physiology'.dta, clear
merge m:1 id using ../data/working_postflight ///
	, keepusing(date_trace daicu dead dead28) nolabel replace update
drop if inlist(_merge, 1,2)
drop _merge

global table_name model_bkwd_monly_det
tempfile estimates_file working
global i = 0

cap program drop myret
program myret, rclass
    return add
    return matrix b = b
    return matrix V = V
end

cap program drop emargins
program emargins, eclass properties(mi)
	version 12
	$mi_est_cmdline
	di "$margins_cmd"
	$margins_cmd post
end


mi misstable patterns lac_traj cr_traj plat_traj pf_traj, freq
cap drop touse
* CHANGED: 2013-05-29 - uses ims_ms as a common denominator (broader than ims_c)
* gen touse = !missing(ims_ms_traj)
* CHANGED: 2013-06-14 - drop the concept of defining a common population since 
* you are now looking at a broader range of vars than included in ims_ms
gen touse = 1
* gen touse = !missing(lac_traj, cr_traj, plat_traj, pf_traj)
label var touse "Comparison population"

global ycat_labels `" 0 "0" 0.2 "20" 0.4 "40" 0.6 "60" 0.8 "80" "'
global ycat_labels `" 0.1 "10" 0.3 "30" 0.5 "50" "'


* local physiology_vars lac cr plat pf
local physiology_vars ims_ms_det

*  ================================================================
*  = Define a new variable that will be a 4h specific version =
*  ================================================================
clonevar ims_ms_det1 = ims_ms1
clonevar ims_ms_det2 = ims_ms2
clonevar ims_ms_det_traj = ims_ms_traj 

save ../data/scratch/scratch.dta, replace

foreach pvar of local physiology_vars {
	use ../data/scratch/scratch.dta, clear
	global imputations  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20

	* local pvar ims_c
	// temporary vars for identifying min / max of mortality
	tempvar min max
	cap drop ims_other

	// HEART RATE
	// U-shaped: examine high heart rates only
	if "`pvar'"	== "hr_det" {
		local var_label "Heart rate"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)
		egen `min' = min(`pvar'2_dead28) 
		su `pvar'2_dead28 `min'

		// use modulus to return the floor using multiples of 10
		local floor 10

		su `pvar'2 if `min' == `pvar'2_dead28
		local inflexion = `floor' * int(r(mean)/`floor')
		di "Inflexion point for `pvar' at `inflexion'"

		count if `pvar'2 < `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set"
		replace `pvar'2 = . if `pvar'2 < `inflexion'

		su `pvar'1 if `min' == `pvar'2_dead28
		local inflexion = `floor' * mod(r(mean),`floor')

		count if `pvar'1 < `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from SPOT data set"
		replace `pvar'1 = . if `pvar'1 < `inflexion'

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Heart rate - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// RESPIRATORY RATE
	// U-shaped: examine high resp rates only
	if "`pvar'"	== "rr_det" {
		local var_label "Respiratory rate"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)
		tempvar min 
		egen `min' = min(`pvar'2_dead28)

		su `pvar'2 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 5)
		di "Inflexion point for `pvar' at `inflexion'"

		count if `pvar'2 < `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set"
		replace `pvar'2 = . if `pvar'2 < `inflexion'

		su `pvar'1 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 5)
		count if `pvar'1 < `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from SPOT data set"
		replace `pvar'1 = . if `pvar'1 < `inflexion'

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Respiratory rate - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// SYSTOLIC BLOOD PRESSURE
	// U-shaped: examining low blood pressures only
	if "`pvar'"	== "bps_det" {
		local var_label "Systolic Blood Pressure"
		// Ordering of risk
		local reverse_label 1

		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"

		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		mkspline `pvar'2_sp = `pvar'2, nknots(4) cubic displayknots
		logistic dead28 `pvar'2_sp* ims_other age
		predict `pvar'2_xb
		running `pvar'2_xb `pvar'2 if m0
		graph rename plot1, replace

		// simple running version - visually compare this with adjusted
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28) 
		graph rename plot2, replace
		graph combine plot1 plot2, xsize(6) ysize(4) rows(1)
		tempvar min 
		egen `min' = min(`pvar'2_dead28)
		su `min'

		// use modulus to return the floor using multiples of 10
		local floor 10


		su `pvar'2 if `min' == `pvar'2_dead28
		local inflexion = `floor' * int(r(mean)/`floor')
		// now use the lower of inflexion or floor - based on ICNARC APS
		if `inflexion' > 180 local inflexion 180
		di "Inflexion point for `pvar' at `inflexion'"

		count if `pvar'2 > `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set"
		replace `pvar'2 = . if `pvar'2 > `inflexion'

		su `pvar'1 if `min' == `pvar'2_dead28
		local inflexion = `floor' * mod(r(mean),`floor')

		count if `pvar'1 > `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from SPOT data set"
		replace `pvar'1 = . if `pvar'1 > `inflexion'

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Systolic Blood Pressure - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5

	}

	// pH
	// U-shaped: focus just on acidotic
	if "`pvar'"	== "ph_det" {
		local var_label "pH"
		// Ordering of risk
		local reverse_label 1
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28) 
		tempvar min 
		egen `min' = min(`pvar'2_dead28)

		su `pvar'2 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 0.05)
		count if `pvar'2 > `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set"
		replace `pvar'2 = . if `pvar'2 > `inflexion'

		su `pvar'1 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 0.05)
		count if `pvar'1 > `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from SPOT data set"
		replace `pvar'1 = . if `pvar'1 > `inflexion'

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "pH - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// LACTATE
	// Monotonic - high is bad
	if "`pvar'"	== "lac_det" {
		local var_label "Lactate"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Lactate - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other 
		label var ims_other "ICNARC score (other)"
	}

	// TEMPERATURE
	// U-shaped: Examine low temperatures only
	if "`pvar'"	== "temp_det" {
		local var_label "Temperature"
		// Ordering of risk
		local reverse_label 1
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)
		tempvar min 
		egen `min' = min(`pvar'2_dead28)

		su `pvar'2 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 0.1)
		count if `pvar'2 > `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set (`pvar' > `inflexion')"
		replace `pvar'2 = . if `pvar'2 > `inflexion'

		count if `pvar'1 > `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set (`pvar' > `inflexion')"
		replace `pvar'1 = . if `pvar'1 > `inflexion'

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Temperature - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// WHITE CELL COUNT
	// U-shaped: Examine high counts only
	if "`pvar'"	== "wcc_det" {
		local var_label "White cell count"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		// NOTE: 2013-05-29 - extra requirement for WCC < 30 else uses high minima
		running dead28 `pvar'2 if m0 & `pvar'2 < 30, generate(`pvar'2_dead28)
		tempvar min 
		egen `min' = min(`pvar'2_dead28)

		su `pvar'2 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 1) - 1
		count if `pvar'2 < `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set (`pvar' < `inflexion')"
		replace `pvar'2 = . if `pvar'2 < `inflexion'

		count if `pvar'1 < `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set (`pvar' < `inflexion')"
		replace `pvar'1 = . if `pvar'1 < `inflexion'

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "White cell count - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// URINE
	// Monotonic (with spike at zero): low is bad (in fact running is flat!)
	if "`pvar'"	== "urin_det" {
		local var_label "Urine volume"
		// Ordering of risk
		local reverse_label 1
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Urine volume - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// P:F ratio
	// Should be monotonic
	if "`pvar'"	== "pf_det" {
		local var_label "P:F ratio"
		// Ordering of risk
		local reverse_label 1
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "P:F ratio - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// PLATELETS
	// Monotonic: Low is bad
	if "`pvar'"	== "plat_det" {
		local var_label "Platelets"
		// Ordering of risk
		local reverse_label 1
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Platelets - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other 
		label var ims_other "ICNARC score (other)"
	}
	
	// SODIUM
	// U-shaped: Focus on low
	if "`pvar'"	== "na_det" {
		local var_label "Sodium"
		// Ordering of risk
		local reverse_label 1
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)
		tempvar min 
		egen `min' = min(`pvar'2_dead28)

		su `pvar'2 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 5)
		count if `pvar'2 > `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set"
		replace `pvar'2 = . if `pvar'2 > `inflexion'

		su `pvar'1 if `min' == `pvar'2_dead28
		local inflexion = round(r(mean), 5)
		count if `pvar'1 > `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from SPOT data set"
		replace `pvar'1 = . if `pvar'1 > `inflexion'

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Sodium - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// CREATININE
	// Monotonic (ish) - high is bad
	if "`pvar'"	== "cr_det" {
		local var_label "Creatinine"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)
		egen `max' = max(`pvar'2_dead28)

		su `pvar'2 if `max' == `pvar'2_dead28
		local inflexion = round(r(mean), 10)
		count if `pvar'2 > `inflexion' & !missing(`pvar'2) & m0
		di as result "`=r(N)' cases to be dropped from ICU data set"
		replace `pvar'2 = . if `pvar'2 > `inflexion'

		su `pvar'1 if `max' == `pvar'2_dead28
		local inflexion = round(r(mean), 5)
		count if `pvar'1 > `inflexion' & !missing(`pvar'1) & m0
		di as result "`=r(N)' cases to be dropped from SPOT data set"
		replace `pvar'1 = . if `pvar'1 > `inflexion'
		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Creatinine - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// UREA
	// Monotonic (ish) - high is bad
	if "`pvar'"	== "urea_det" {
		local var_label "Urea"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Urea - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// GCS
	// Monotonic: Low is bad
	if "`pvar'"	== "gcs_det" {
		local var_label "Urine volume"
		// Ordering of risk
		local reverse_label 1
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "Urine volume - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		egen ims_other = rowtotal(*2_wt) 
		replace ims_other = ims_other - `pvar'2_wt
		label var ims_other "ICNARC score (other)"
	}

	// ICNARC APS
	// Monotonic (ish) - high is bad
	if "`pvar'"	== "ims_c_det" {
		local var_label "ICNARC APS (complete)"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "ICNARC APS - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		gen ims_other = 1
		label var ims_other "No adjustment possible"
		// Avoids a problem with imputation data set 12 which leads to different cats being dropped
		global imputations  1 2 3 4 5 6 7 8 9 10 11 13 14 15 16 17 18 19 20
	}
	// ICNARC APS - Partial
	// Monotonic (ish) - high is bad
	if "`pvar'"	== "ims_ms_det" {
		local var_label "ICNARC APS (Partial)"
		// Ordering of risk
		local reverse_label 0
		// find the minimum of the inflexion point with mortality
		// and replace with missing where below so you have a linear variable
		running dead28 `pvar'2 if m0, generate(`pvar'2_dead28)

		cap drop `pvar'_traj
		gen `pvar'_traj = `pvar'2 - `pvar'1 if time2icu <= 24
		label var `pvar'_traj "ICNARC APS (Partial) - Ward to ICU change"
		su `pvar'1 `pvar'2 `pvar'_traj if m0
		
		// define touse specifically for this variable
		* cap drop touse
		* gen touse = !missing(`pvar'_traj)
		* label var touse "Comparison population"
		global y_hrlabels 0.5(0.5)2.5
		// define severity adjustment without this var
		gen ims_other = 1
		label var ims_other "No adjustment possible"
	}

	cap graph rename running, replace

	di as result "`pvar'"
	lookfor `pvar'
	// =====================================================
	// = Define the grid for the physiology being examined =
	// =====================================================

	if $debug {
		spikeplot `pvar'2 if m0, name(p2, replace) nodraw
		spikeplot `pvar'1 if m0, name(p1, replace) nodraw
		spikeplot `pvar'_traj if m0, name(pt, replace) nodraw
		graph combine p1 p2 pt, col(1)
	}

	su `pvar'1 `pvar'2 `pvar'_traj if touse, d

	/* Transform? */
	cap drop `pvar'2_bc
	// CHANGED: 2013-05-28 - define trajectory in full population not just the common 
	qui su `pvar'2, d
	if r(skewness) > 3 {

		bcskew0 `pvar'2_bc =`pvar'2 , level(90)
		global bc_lambda = r(lambda)
		di as result "Using $bc_lambda transform of `var_label' (i.e. to avoid skewness)"
	}
	else {
		gen `pvar'2_bc =`pvar'2 
		global bc_lambda = 1
		di as result "No transformation (skewness < 3)"
	}
	su `pvar'2 `pvar'2_bc , d

	/* 	Now define Low-Medium-High risk categories based on quartiles
		Alternatively you can define this by coming 'in' from the extremes of the 2nd value
		by some standardised amount of the trajectory
		i.e. if trajectory SD is 5, and the min, max of the 2nd value is 0 30
		then you would pick your mid-range as 5-25
		leaving room for those at the top to move up and those at the bottom to move down
	*/

	cap drop `pvar'2_k
	qui su `pvar'2_bc , d
	local min = r(min) - 1 // subtract 1 b/c egen cut does not use the boundary
	local max = r(max) + 1 // ditto
	egen `pvar'2_k = cut(`pvar'2_bc), at(`min' `=r(p25)'  `=r(p75)' `max' ) icodes
	replace `pvar'2_k = `pvar'2_k + 1
	label var `pvar'2_k "`var_label' - CMPD"
	cap label drop `pvar'2_k
	// reverse categories where low is bad and high is good
	if `reverse_label' {
		replace `pvar'2_k = 4 - `pvar'2_k
	}
	label define `pvar'2_k 1 "Lower risk" 2 "Medium risk" 3 "Higher risk"
	label values `pvar'2_k `pvar'2_k
	tab `pvar'2_k if m0

	tabstat dead28 if m0 , by(`pvar'2_k) s(n mean sd ) format(%9.3g)
	tabstat `pvar'2 if m0 , by(`pvar'2_k) s(n mean sd q) format(%9.3g)
	tabstat `pvar'_traj if m0 , by(`pvar'2_k) s(n mean sd q) format(%9.3g)


	forvalues i = 1/3 {
		ci dead28 if m0 & `pvar'2_k == `i'
		// 28 d mortality
		local q = r(mean) * 100
		local q: di %9.1fc `q'
		local dead28_2_k`i' = trim("`q'")
		// n
		local q = r(N)
		local q: di %9.0fc `q'
		local n_2_k`i' = trim("`q'")
	}

	/* 	Now define trajectory classes
		Use 0 as the centre and a symmetrical region around it
		Use the 0.5 standard deviations above and below it
	*/

	// CHANGED: 2013-05-28 - define trajectory in full population not just the common 
	* su `pvar'_traj if m0 & touse, d
	su `pvar'_traj if m0 , d
	global boundary = r(sd)/2
	// Now set up the trajectory class variable
	cap drop `pvar'_tclass
	gen `pvar'_tclass = 0 if `pvar'_traj != .
	label var `pvar'_tclass "`var_label' trajectory class"
	cap label drop `pvar'_tclass
	label define `pvar'_tclass 0 "Unclassified"

	cap drop `pvar'_tvector
	gen `pvar'_tvector = .
	label var `pvar'_tvector "Pre-admission `var_label' trajectory"

	su `pvar'_traj
	local cut_min = r(min) - 1
	local cut1 = -1.0 * $boundary
	local cut2 = -0.25 * $boundary
	local cut3 =  0.25 * $boundary
	local cut4 =  1.0 * $boundary
	local cut_max = r(max) + 1
	local cuts `cut_min' `cut1' `cut2' `cut3' `cut4' `cut_max'
	forvalues r = 1/3 {
		// for each level of risk divide trajectories into 5 groups
		if `r' == 1 local risk Lower
		if `r' == 2 local risk Medium
		if `r' == 3 local risk Higher
		tempvar c
		* // make sure nothing falls outside the max and min you have set
		* replace `pvar'_tclass 		= . if `pvar'2_k == `r' & `pvar'_traj <= `cut_min'
		* replace `pvar'_tclass 		= . if `pvar'2_k == `r' & `pvar'_traj >= `cut_max'
		egen `c' = cut(`pvar'_traj) 	if `pvar'2_k == `r', at(`cuts') icodes
		tab `c' if m0
		// define the trajectory vector
		replace `pvar'_tvector = `c' + 1 if `pvar'2_k == `r' & `pvar'_tvector == .
		// define the category
		replace `c' = `c' + ((`r' - 1) * 5) + 1
		tab `c' if m0
		* assert r(r) == 5
		replace `pvar'_tclass = `c' if `pvar'_tclass == 0 & !missing(`c')
		forvalues l = 1/5 {
			if `l' == 1 local traj "Decr ++"
			if `l' == 2 local traj "Decr +"
			if `l' == 3 local traj "Neutral"
			if `l' == 4 local traj "Incr +"
			if `l' == 5 local traj "Incr ++"
			local label = `l' + ((`r' - 1) * 5) 
			label define `pvar'_tclass `label' "`risk' risk - `traj'", add
		}
	}
	label values `pvar'_tclass `pvar'_tclass
	tab `pvar'_tclass if m0

	/* No Low risk deteriorating because that would imply -ve severity */
	// if high is bad then impossible to have +ve traj (deteriorate) in lowest risk
	// working with tclass 1--5
	if !`reverse_label' {
		replace `pvar'_tvector = 4 if inlist(`pvar'_tclass, 4, 5)
		replace `pvar'_tclass = 4 if inlist(`pvar'_tclass, 4, 5)
	}
	// if low is bad then working at other end tclasses 1--2
	// lower risk is a high number then --ve vectors imposs in
	else {
		replace `pvar'_tvector = 2 if inlist(`pvar'_tclass, 1, 2)
		replace `pvar'_tclass = 2 if inlist(`pvar'_tclass, 1, 2)
	}

	/* Medium risk - all possible */

	/* No high risk improving because that would imply a crazy severity */
	// if high risk is low value then imposs to have ++ve traj in worst pts
	if !`reverse_label' {
		replace `pvar'_tvector = 2 if inlist(`pvar'_tclass, 11, 12)
		replace `pvar'_tclass = 12 if inlist(`pvar'_tclass, 11, 12)
	}
	else {
		replace `pvar'_tvector = 4 if inlist(`pvar'_tclass, 14, 15)
		replace `pvar'_tclass = 14 if inlist(`pvar'_tclass, 14, 15)
	}

	replace `pvar'_tclass = . if missing(`pvar'_traj, `pvar'2_k)
	label values `pvar'_tclass `pvar'_tclass

	tab `pvar'_tclass if m0 
	tabstat `pvar'_traj if m0 , by(`pvar'_tclass) s(n mean sd q) format(%9.3g)

	cap label drop `pvar'_tvector
	label define `pvar'_tvector 1  "Decr ++"
	label define `pvar'_tvector 2  "Decr +", add
	label define `pvar'_tvector 3  "Neutral", add
	label define `pvar'_tvector 4  "Incr +", add
	label define `pvar'_tvector 5  "Incr ++", add
	label values `pvar'_tvector `pvar'_tvector

	tab `pvar'2_k `pvar'_tvector if m0 & touse
	table `pvar'2_k `pvar'_tvector if m0 & touse, contents(p25 `pvar'_traj p75 `pvar'_traj)

	table `pvar'2_k `pvar'_tv if m0, c(mean `pvar'_tc)
	// DEBUGGING: 2013-06-03 - 
	* exit	

	if $debug {
		dotplot `pvar'_traj if m0 & touse, over(`pvar'2_k)
		dotplot `pvar'_traj if m0 & touse, over(`pvar'_tvector)
	}

	/* Complete cases estimate */
	qui su ims_other
	replace ims_other = ims_other - r(mean)

	// NOTE: 2013-06-19 - drop sparse categories else problems with MI
	// where omitted categories vary from data set to data set
	// used in in debugging only
	* forvalues i = 1/15 {
	* 	if inlist(`i',5,11) continue
	* 	count if `pvar'_tclass == `i' & m0
	* 	if r(N) < 10 {
	* 		replace touse = 0 if `pvar'_tclass == `i'
	* 	}
	* }

	// DEFINE CONFOUNDERS
	local confounders age_c ims_other


	// CHANGED: 2013-06-23 - NOW DROP ALL IMPROVING CASES
	if !`reverse_label' {
		drop if inlist(`pvar'_tvector, 1, 2)
	}
	else {
		drop if inlist(`pvar'_tvector, 4, 5)
	}

	//  ==============
	//  = Grid model =
	//  ==============
	d *`pvar'*


	logistic dead28 ib2.`pvar'2_k##ib3.`pvar'_tvector `confounders' if m0 & touse
	/* Average marginal effects at the means */
	margins `pvar'2_k#`pvar'_tvector if m0 & touse, post
	est store margins_m0_grid
	* marginsplot, x(`pvar'_tvector) legend(pos(3))

	est restore margins_m0_grid
	/* Now tidy up the plot */
	local ggreen "49 163 84"
	local rred "215 48 31"
	local bblue "blue"

	local ycat_labels `"$ycat_labels"'

	marginsplot ///
		, ///
		xdimension(`pvar'_tvector) ///
		bydimension(`pvar'2_k) ///
		byopts(rows(1) title("") ///
			subtitle("(A) Complete cases", position(11) justification(left) )) ///
		recastci(rspike) ///
		plotopts(msymbol(o)) ///
		xtitle("Pre-admission trajectory", margin(medium)) ///
		xlabel(1 "{&darr}{&darr}" 2 "{&darr}" 3 "0" 4 "{&uarr}" 5 "{&uarr}{&uarr}", labsize(medium) ) ///
		ylabel(`ycat_labels', nogrid labsize(small)) ///
		ytitle("Adjusted 28 day mortality (%)" ) ///
		title("") ///
		legend(off) ///
		xsize(8) ysize(6) ///
		plotregion(margin(large))

	graph rename bkwd_`pvar'_grid_m0, replace
	graph display bkwd_`pvar'_grid_m0
	graph export ../outputs/figures/bkwd_`pvar'_grid_m0.$gext ///
	    , name(bkwd_`pvar'_grid_m0) replace
	!rm ../outputs/figures/bkwd_`pvar'_grid_m0.$gext_other

	/* MI estimate */
	cap drop esample
	mi estimate, esampvaryok esample(esample) imputations($imputations): ///
		logistic dead28 ib2.`pvar'2_k##ib3.`pvar'_tvector `confounders' 
	est store mi

	// *************************************************
	/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
	// via http://bit.ly/10CEKNU
	est restore mi
	est describe
	global mi_est_cmdline `=r(cmdline)'

	/* First specify the margins command HERE */
	global margins_cmd "margins `pvar'2_k#`pvar'_tvector, "


	mi estimate, cmdok esampvaryok imputations($imputations): emargins 1
	mat b = e(b_mi)
	mat V = e(V_mi)
	if strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline & m0
	if !strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline if m0
	qui $margins_cmd
	myret
	mata: st_global("e(cmd)", "margins")
	* marginsplot, x(`pvar'_tvector) legend(pos(3))

	/* Now tidy up the plot */
	local ggreen "49 163 84"
	local rred "215 48 31"
	local bblue "blue"
	local ycat_labels `"$ycat_labels"'
	marginsplot ///
		, ///
		xdimension(`pvar'_tvector) ///
		bydimension(`pvar'2_k) ///
		byopts(rows(1) title("") ///
			subtitle("(B) Multiple imputation", position(11) justification(left) )) ///
		recastci(rspike) ///
		plotopts(msymbol(o)) ///
		xtitle("Pre-admission trajectory", margin(medium)) ///
		xlabel(1 "{&darr}{&darr}" 2 "{&darr}" 3 "0" 4 "{&uarr}" 5 "{&uarr}{&uarr}", labsize(medium) ) ///
		ylabel(`ycat_labels', nogrid labsize(small)) ///
		ytitle("Adjusted 28 day mortality (%)" ) ///
		title("") ///
		legend(off) ///
		xsize(8) ysize(6) ///
		plotregion(margin(large))

	graph rename bkwd_`pvar'_grid_mi, replace

	graph combine bkwd_`pvar'_grid_m0 bkwd_`pvar'_grid_mi, ///
		rows(2) name(bkwd_`pvar'_grid, replace) ///
		xsize(4) ysize(6)

	graph display bkwd_`pvar'_grid
	graph export ../outputs/figures/bkwd_`pvar'_grid.$gext ///
	    , name(bkwd_`pvar'_grid) replace
	!rm ../outputs/figures/bkwd_`pvar'_grid.$gext_other




	//***********************************************************************

	//  ==============================
	//  = Continuous mid-range model =
	//  ==============================

	/* Complete cases */

	/* 	Mid-range / risk
		redefine touse here should also bring back in *all* medium risk patients */
	cap drop touse
	gen touse = `pvar'2_k == 2
	spikeplot `pvar'_traj if touse & m0

	/* Inspect */
	cap drop `pvar'2_k2_q5
	xtile `pvar'2_k2_q5 = `pvar'2 , nq(5)
	tabstat `pvar'2, by(`pvar'2_k2_q5) s(n mean sd q) format(%9.3g)
	dotplot `pvar'_traj, over(`pvar'2_k2_q5)

	/* Centre your variable */
	cap drop `pvar'2_original
	clonevar `pvar'2_original = `pvar'2
	// CHANGED: 2013-06-03 - centre only wrt to mid-range
	su `pvar'2 if touse & m0, meanonly
	replace `pvar'2 = `pvar'2 - r(mean)

	/* `pvar' 2 - check for interaction */
	// NOTE: 2013-06-03 - although checking for interaction you are *ignoring* this in the mid-range
	stcox `pvar'2 `pvar'_traj `confounders' if touse & m0, nolog noshow
	est store m1
	stcox c.`pvar'2##c.`pvar'_traj `confounders' if touse & m0, nolog noshow
	est store m2
	lincom c.`pvar'2#c.`pvar'_traj,
	ret li
	local p = 2 * (1 - normal(abs(r(estimate) / r(se))))
	local p: di %9.3f `p'
	di as result "======================================="
	di as result "Significance of interaction: `p'"
	di as result "======================================="
	est stats m1 m2

	est restore m1
	di as result "Complete cases model"
	di as result "===================="
	est replay


	local model_name = "cc `pvar'"
	global i = $i + 1

	parmest, ///
		eform ///
		label list(parm label estimate min* max* p) ///
		idnum($i) idstr("`model_name'") ///
		stars(0.05 0.01 0.001) ///
		format(estimate min* max*  p ) ///
		saving(`estimates_file', replace)

	cap restore, not
	preserve

	if $i == 1 {
		use `estimates_file', clear
		save ../outputs/tables/$table_name.dta, replace
	}
	else {
		use ../outputs/tables/$table_name.dta, clear
		append using `estimates_file'
		save ../outputs/tables/$table_name.dta, replace
	}

	restore

	su `pvar'_traj if m0, d
	local range05_95 = r(p95) - r(p5)
	if "`pvar'" == "gcs" {
		local nnumlist -5(1)5
		local lab_numlist -5 0 5
		local ooffset 2.5
	}
	else if "`pvar'" == "ph" {
		local nnumlist -0.5(0.05)0.5
		local lab_numlist -0.5 0 0.5
		local ooffset 0.25
	}
	else if `range05_95' <= 5 {
		local nnumlist -2.5(0.25)2.5
		local lab_numlist -2.5 0 2.5
		local ooffset 1.25
	}
	else if `range05_95' <= 10 {
		local nnumlist -5(0.5)5
		local lab_numlist -5 0 5
		local ooffset 2.5
	}
	else if `range05_95' <= 20 {
		local nnumlist -10(1)10
		local lab_numlist -10 0 10
		local ooffset 5
	}
	else if `range05_95' <= 50 {
		local nnumlist -20(4)20
		local lab_numlist -20 0 20
		local ooffset 10
	}
	else if `range05_95' <= 100 {
		local nnumlist -50(5)50
		local lab_numlist -50 0 50
		local ooffset 25
	}
	else if `range05_95' <= 200 {
		local nnumlist -100(10)100
		local lab_numlist -100 0 100
		local ooffset 50
	}
	else if `range05_95' <= 500 {
		local nnumlist -250(25)250
		local lab_numlist -250 0 250
		local ooffset 125
	}
	else if `range05_95' <= 1000 {
		local nnumlist -500(50)500
		local lab_numlist -500 0 500
		local ooffset 250
	}

	global nnumlist `nnumlist'
	global lab_numlist `lab_numlist'
	di "Margin will be plotted over $nnumlist"

	margins, at(`pvar'_traj = ($nnumlist) ) vsquish post
	est store marginsplot_`pvar'

	/* Extract the numbers so you can plot without depending on marginsplot */
	matrix at = e(at)
	matrix list at
	// extract the trajectories from the matrix
	matrix at = at[1...,2]
	matrix b = e(b)
	matrix v = vecdiag(e(V))
	matrix plot = at, b', v'
	cap drop plot*
	svmat plot

	cap drop toplot
	gen toplot = plot2 != .
	cap drop at_* bhat vhat
	rename plot1 at_`pvar'_traj
	rename plot2 bhat
	rename plot3 vhat
	cap drop bhat_min bhat_max
	gen bhat_min = bhat - (1.96 * vhat^0.5)
	gen bhat_max = bhat + (1.96 * vhat^0.5)

	replace bhat = . if bhat > 2.5
	replace bhat = . if bhat < 0.5
	replace bhat_max = 2.5 if bhat_max > 2.5
	replace bhat_min = 0.5 if bhat_min < 0.5

	* local reverse_label 0
	* local pvar rr
	local ggreen "49 163 84"
	local rred "215 48 31"
	if `reverse_label' {
		local left_worse "-"
		local right_worse ""
	}
	else {
		local left_worse ""
		local right_worse "-"
	}
	marginsplot ///
		, ///
		recastci(rarea) ///
		ciopts(pstyle(ci)) ///
		recast(line) ///
		xlabel($lab_numlist, labsize(small)) ///
		ylabel(,labsize(small)) ///
		title("") ///
		xsize(6) ysize(6) ///
		plotregion(margin(large)) ///
		xtitle("Change from pre-admission ICNARC score" ///
				"(1{superscript:st} 24 hour value - ward assessment value)", ///
				size(small)) ///
		text(0 `left_worse'`ooffset' "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
		text(0  0 "Neutral", placement(c) size(small)) ///
		text(0 `right_worse'`ooffset' "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
		legend(off) ///
		name(marginsplot_`pvar', replace)

	local ggreen "49 163 84"
	local rred "215 48 31"
	local ylabels $y_hrlabels
	local yline yline(1, lcolor(gs4) lwidth(thin) lpattern(solid) noextend)
	tw ///
		(rarea bhat_min bhat_max at_`pvar'_traj, ///
			pstyle(ci) sort) ///
		(line bhat at_`pvar'_traj, ///
			lcolor(black) lpattern(solid) sort) ///
		, ///
		ylabel(`ylabels',labsize(small) format(%9.1fc)) ///
		ytitle("Relative hazard") ///
		xlabel($lab_numlist, labsize(vsmall) ) ///
		xlabel(`left_worse'`ooffset' "Worsening", add custom labcolor("`rred'") labsize(small) noticks labgap(medium)) ///
		xlabel(`right_worse'`ooffset' "Improving", add custom labcolor("`ggreen'") labsize(small) noticks labgap(medium)) ///
		xsize(6) ysize(6) ///
		subtitle("(A) Complete cases", position(11) justification(left) ) ///
		title("") ///
		plotregion(margin(large)) ///
		xtitle("Change from pre-admission value", ///
				size(medsmall)) ///
		legend(off) ///
		`yline' ///
		name(bhatplot_`pvar', replace)

		/* NOW AFTER MI */

	*  =================================
	*  = Continuous plot using MI data =
	*  =================================
	cap drop esample
	mi estimate, esampvaryok esample(esample): ///
		stcox `pvar'2 `pvar'_traj `confounders' if touse
	est store mi1

	cap drop esample
	mi estimate, esampvaryok esample(esample): ///
		stcox c.`pvar'2##c.`pvar'_traj `confounders' if touse
	est store mi2
	di as result "Multiple imputation model"
	di as result "========================="
	est replay, eform

	/* `pvar' 2 - check for interaction */
	mi test c.`pvar'2#c.`pvar'_traj
	ret li
	local p: di %9.3f `=r(p)'
	di "Significance of interaction: `p'"

	est restore mi1
	est replay

	tempfile estimates_file working

	local model_name = "mi `pvar'"
	global i = $i + 1

	parmest, ///
		eform ///
		label list(parm label estimate min* max* p) ///
		idnum($i) idstr("`model_name'") ///
		stars(0.05 0.01 0.001) ///
		format(estimate min* max*  p ) ///
		saving(`estimates_file', replace)

	cap restore, not
	preserve

	if $i == 1 {
		use `estimates_file', clear
		save ../outputs/tables/$table_name.dta, replace
	}
	else {
		use ../outputs/tables/$table_name.dta, clear
		append using `estimates_file'
		save ../outputs/tables/$table_name.dta, replace
	}

	restore

	/* Use the same numlist as for the m0 sample */
	di "Margin will be plotted over $nnumlist"

	**************************************************
	/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
	// via http://bit.ly/10CEKNU
	est describe
	global mi_est_cmdline `=r(cmdline)'
	/* First specify the margins command HERE */
	global margins_cmd "margins, at(`pvar'_traj = ($nnumlist) ) vsquish"


	mi estimate, cmdok esampvaryok: emargins 1
	mat b = e(b_mi)
	mat V = e(V_mi)
	est store margins_mi_plot_`pvar'

	/* Extract the numbers so you can plot without depending on marginsplot */

	matrix at = e(at)
	matrix list at
	// extract the trajectories from the matrix
	matrix at = at[1...,2]
	matrix b = e(b_mi)
	matrix v = vecdiag(e(V_mi))
	cap matrix drop mi_plot
	matrix mi_plot = at, b', v'
	matrix list mi_plot

	cap drop mi_plot*
	svmat mi_plot
	cap drop tomi_plot
	gen tomi_plot = mi_plot2 != .
	cap drop mi_at_* mi_bhat mi_vhat
	rename mi_plot1 mi_at_`pvar'_traj
	rename mi_plot2 mi_bhat
	rename mi_plot3 mi_vhat
	cap drop mi_bhat_min mi_bhat_max
	gen mi_bhat_min = mi_bhat - (1.96 * mi_vhat^0.5)
	gen mi_bhat_max = mi_bhat + (1.96 * mi_vhat^0.5)

	replace mi_bhat = . if mi_bhat > 2.5
	replace mi_bhat = . if mi_bhat < 0.5
	replace mi_bhat_max = 2.5 if mi_bhat_max > 2.5
	replace mi_bhat_min = 0.5 if mi_bhat_min < 0.5

	local ggreen "49 163 84"
	local rred "215 48 31"
	tw ///
		(rarea mi_bhat_min mi_bhat_max mi_at_`pvar'_traj, ///
			pstyle(ci) sort) ///
		(line mi_bhat mi_at_`pvar'_traj, ///
			lcolor(black) lpattern(solid) sort) ///
		, ///
		ylabel(`ylabels',labsize(small) format(%9.1fc)) ///
		ytitle("Relative hazard") ///
		xlabel($lab_numlist, labsize(vsmall) ) ///
		xlabel(`left_worse'`ooffset' "Worsening", add custom labcolor("`rred'") labsize(small) noticks labgap(medium)) ///
		xlabel(`right_worse'`ooffset' "Improving", add custom labcolor("`ggreen'") labsize(small) noticks labgap(medium)) ///
		xsize(6) ysize(6) ///
		title("") ///
		subtitle("(B) Multiple imputation", position(11) justification(left) ) ///
		plotregion(margin(large)) ///
		xtitle("Change from pre-admission value", ///
				size(medsmall)) ///
		legend(off) ///
		`yline' ///
		name(mi_bhatplot_`pvar', replace)

	graph combine bhatplot_`pvar' mi_bhatplot_`pvar', ///
		rows(1) ycommon xcommon xsize(6) ysize(4) ///
		name(bkwd_`pvar'_monly, replace)

	graph display bkwd_`pvar'_monly
	graph export ../outputs/figures/bkwd_`pvar'_monly.$gext ///
	    , name(bkwd_`pvar'_monly) replace
	!rm ../outputs/figures/bkwd_`pvar'_monly.$gext_other

	* graph combine bkwd_`pvar'_grid bkwd_`pvar'_monly, ///
	* 	rows(2) xsize(6) ysize(6) ///
	* 	name(`pvar'_traj_all, replace)


}

* use ../outputs/tables/$table_name.dta, clear

cap log close
