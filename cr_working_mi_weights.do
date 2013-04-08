*  ========================================
*  = Missing data and multiple imputation =
*  ========================================

/*
created: 	130407
modified: 	130407

As for cr_working_mi_icnarc but imputes using ologit and weights

*/

clear all
use ../data/working.dta
qui include mtPrograms.do
qui include cr_preflight.do
use ../data/working_postflight.dta, clear
set scheme shbw
set seed 3001
global n_imputations 20
* sample 500, count

/* Complete observed vars (NB dx_cat missing in 14) */
// NOTE: 2013-04-04 - ignoring hierarchical structure for now
local complete_vars age sex dx_cat time2icu
keep if !missing(age, sex, dx_cat, dead28, time2icu)


global complete_vars `complete_vars'

/* ICNARC model vars */
local im_vars ///
	hr2_wt bps2_wt temp2_wt rr2_wt urea2_wt cr2_wt na2_wt wcc2_wt ///
	urin2_wt gcs2_wt pf2_wt ph2_wt




/* Vars used in MI but not part of physiology */
/* Not needed here because you are working with weights */
global other_vars ///
	rxfio2 intilpo

* CHANGED: 2013-04-06 - difference pre-admission data
/* Variables that need to be differenced before imputation */
local pre_vars	///
	hr bps temp rr urea cr na wcc ///
	urin gcs pf ph

foreach var of local pre_vars {
	gen `var'_wt_d = `var'2_wt - `var'1_wt
	local diff_vars `diff_vars' `var'_wt_d
}

/* Other major physiology vars */
local severity_vars ///
	lac2 plat2

gen lac_d = lac2 - lac1
gen plat_d = plat2 - plat1

global pre_vars `pre_vars'
global diff_vars `diff_vars' lac_d plat_d

global mi_vars `im_vars' `severity_vars'  $diff_vars

di "$mi_vars"

/* What proportion of data is missing - crude average */
local i = 1
foreach var of global mi_vars {
	qui count if `var' == .
	local x = `=r(N)'
	local total = `total' + `x'
	local y = `x'/_N
	local y: di %9.2fc `y'
	di "`var': `y'"
	local ++i
}
local miss_bar = `total' / (`i' * _N)
di "Crude missing proportion: `miss_bar'"
/* So imputation number should be greater than this as % i.e .15 m = 15 */


save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear


/* Work with a logistic outcome model for now */
local out_vars dead28
global out_vars `out_vars'
/* MI checks that the data is not stset */
stset, clear

/* Work just with the components of the ICNARC score for now */
keep icode icnno id $complete_vars $out_vars $mi_vars $other_vars
order icode icnno id $out_vars $complete_vars $mi_vars $other_vars

count
d
* misstable patterns $mi_vars, replace clear asis freq bypatterns
misstable summarize $mi_vars, gen(mv_)
// NOTE: 2013-04-04 - you have *hard* missing values for some vars
// these are not eligible for imputation by stata
// you must set them to soft missing first

foreach var of global mi_vars {
	replace `var' = . if `var' >= .
}
misstable summarize $mi_vars

/* Set up multiple imputation  */
/* While testing this let's pretend you are just working with P:F ratio */
cap mi extract 0, clear
mi set flong
mi register passive $other_vars `surv_passive'
mi register imputed $mi_vars
mi register regular $complete_vars $out_vars

/* Imputation model assumes linear relations? - check */

* collin $mi_vars

/* Multiple imputation step */
/*
Stay with PMM for now ...
- firstly because it easy to implement
- secondly it is probably? the right answer for the differences
- and it is probably not a *bad* answer for the raw weights
	- using ologit for the weights would lose the fact that
	there are different 'gaps' in the weight scale
*/
mi impute chained ///
	(pmm) ///
	hr_wt_d hr2_wt ///
	bps_wt_d bps2_wt ///
	temp_wt_d temp2_wt ///
	rr_wt_d rr2_wt ///
	urea_wt_d urea2_wt ///
	cr_wt_d cr2_wt ///
	na_wt_d na2_wt ///
	wcc_wt_d wcc2_wt ///
	urin_wt_d urin2_wt ///
	pf_wt_d pf2_wt ///
	ph_wt_d ph2_wt ///
	gcs_wt_d gcs2_wt ///
	lac_d lac2 ///
	plat_d plat2 ///
	= age sex dead28 i.dx_cat time2icu ///
	, ///
	add($n_imputations) replace dots augment

cap drop ims_c2
egen ims_c2 = rowtotal(*2_wt)
label var ims_c2 "ICNARC score (complete) - ICU"

local traj_x 12
cap drop ims_c_traj
egen ims_c_traj = rowtotal(*_wt_d)
replace ims_c_traj = ims_c_traj / (round(time2icu, `traj_x') + 1)
label var ims_c_traj "IMscore - complete - slope"

scatter ims_c_traj ims_c2

save ../data/working_mi_weight_plus, replace

*  ================================
*  = Now repeat for survival data =
*  ================================
use ../data/scratch/scratch.dta, clear

/* Royston recommend using NA (Cumulative hazard function) and _d if survival modelling */
cap drop NA
sts gen NA = na
local surv_regular _d NA
local surv_passive _st _origin _t _t0
local out_vars `surv_regular'
global out_vars `out_vars'
drop if missing(_d, NA)

misstable summarize $mi_vars, gen(mv_)
// NOTE: 2013-04-04 - you have *hard* missing values for some vars
// these are not eligible for imputation by stata
// you must set them to soft missing first

foreach var of global mi_vars {
	replace `var' = . if `var' >= .
}
misstable summarize $mi_vars $out_vars

/* Work just with the components of the ICNARC score for now */
keep icode icnno id $complete_vars $out_vars $mi_vars $other_vars `surv_passive'
order icode icnno id $out_vars $complete_vars $mi_vars $other_vars `surv_passive'


cap mi extract 0, clear
mi set flong
mi register passive $other_vars
mi register imputed $mi_vars
mi register regular $complete_vars $out_vars

/* Multiple-imputation for survival data */
mi impute chained ///
	(pmm) ///
	hr_wt_d hr2_wt ///
	bps_wt_d bps2_wt ///
	temp_wt_d temp2_wt ///
	rr_wt_d rr2_wt ///
	urea_wt_d urea2_wt ///
	cr_wt_d cr2_wt ///
	na_wt_d na2_wt ///
	wcc_wt_d wcc2_wt ///
	urin_wt_d urin2_wt ///
	pf_wt_d pf2_wt ///
	ph_wt_d ph2_wt ///
	gcs_wt_d gcs2_wt ///
	lac_d lac2 ///
	plat_d plat2 ///
	= age sex _d NA i.dx_cat time2icu ///
	, ///
	add($n_imputations) replace dots augment

cap drop  ims2_miss ims_traj_miss
egen ims2_miss = rowmiss(*2_wt)
egen ims_traj_miss = rowmiss(*_wt_d)
tab ims2_miss
tab ims_traj_miss

cap drop ims_c2
egen ims_c2 = rowtotal(*2_wt) if !ims2_miss
label var ims_c2 "ICNARC score (complete) - ICU"

local traj_x 12
cap drop ims_c_traj
egen ims_c_traj = rowtotal(*_wt_d) if !ims_traj_miss
replace ims_c_traj = ims_c_traj / (round(time2icu, `traj_x') + 1)
label var ims_c_traj "IMscore - complete - slope"

scatter ims_c_traj ims_c2

save ../data/working_mi_weight_plus_surv, replace

exit
