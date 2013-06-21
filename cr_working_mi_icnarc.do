*  ========================================
*  = Missing data and multiple imputation =
*  ========================================

/*
Use MI approach to rebuild the ICNARC score from the raw values available
After which you will need to generate the weights again

ASK: 2013-04-06 -
Decisions to discuss
- do you run the MI on the raw data and then generate the score using the imputed values
	or do you use the raw data as the input to generate the final score
- the MI model will often be non-linear
	... but the best predictor will be the 'paired' variable
	and this *should* be linear (i.e. Na is non-linear but na1 is a linear predictor of na2)
	- model might be less non-linear than you think since you are predicting physiology from other physiology *not* predicting mortality
- might be best to run MI on the weights (and thereby handle the non-linearity issues)
- finally the imputation models assume everything is independent
	but you have repeated measures


Solutions
1. MI model using weights and including the final aggregate score
	- this will largely be missing - but hopefully there is enough info in the weights
2. MI model the raw data and then re-calculate the weights in the final model
	Then run your analyses in the MI data
3. MI model the raw data converting all pre-admission values to 'differences'

Define the variables that should be kept in the MI data set

*/

clear all
* use ../data/working.dta
qui include mtPrograms.do
* qui include cr_preflight.do
use ../data/working_postflight.dta, clear
set scheme shbw
set seed 3001
global n_imputations 20
// DEBUGGING: 2013-05-31 - comment this out when ready
* sample 500, count

/* Complete observed vars (NB dx_cat missing in 14) */
// NOTE: 2013-04-04 - ignoring hierarchical structure for now
local complete_vars age sex dx_cat time2icu
keep if !missing(age, sex, dx_cat, dead28, time2icu)


global complete_vars `complete_vars'

/* ICNARC model vars */
local im_vars ///
	hr2 bps2 temp2 rr2 urea2 cr2 na2 wcc2 ///
	urin2 gcs2 pf2 ph2


/* Other major physiology vars */
local severity_vars ///
	lac2 plat2

/* Vars used in MI but not part of physiology */
global other_vars ///
	rxfio2 intilpo

* CHANGED: 2013-04-06 - difference pre-admission data
/* Variables that need to be differenced before imputation */
local pre_vars	///
	hr bps temp rr urea cr na wcc ///
	urin gcs pf ph ///
	lac plat

foreach var of local pre_vars {
	gen `var'_d = `var'2 - `var'1
	local diff_vars `diff_vars' `var'_d
}
global pre_vars `pre_vars'
global diff_vars `diff_vars'

global mi_vars `im_vars' `severity_vars' `diff_vars'

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

// Calculate proportion of missing data
local s = 0
local n = 0
foreach var of global mi_vars {
	count if `var' == .
	local s = `s' + r(N)
	local ++n
}
local r = `s' / (_N *`n')
di `r'


/* Imputation model assumes linear relations? - check */

* collin $mi_vars

/* Multiple imputation step */
mi impute chained ///
	(pmm, knn(10)) ///
	hr_d hr2 ///
	bps_d bps2 ///
	temp_d temp2 ///
	rr_d rr2 ///
	urea_d urea2 ///
	cr_d cr2 ///
	na_d na2 ///
	wcc_d wcc2 ///
	urin_d urin2 ///
	pf_d pf2 ///
	ph_d ph2 ///
	lac_d lac2 ///
	plat_d plat2 ///
	(ologit, ascontinuous) ///
	gcs_d gcs2 ///
	= age sex dead28 i.dx_cat time2icu ///
	, ///
	add($n_imputations) replace dots augment 

// CHANGED: 2013-04-06 - now recover the original pre-vars from the differences
foreach var of global pre_vars {
	gen `var'1 = `var'2 - `var'_d
}

save ../data/working_mi_icnarc_plus, replace

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
	hr_d hr2 ///
	bps_d bps2 ///
	temp_d temp2 ///
	rr_d rr2 ///
	urea_d urea2 ///
	cr_d cr2 ///
	na_d na2 ///
	wcc_d wcc2 ///
	urin_d urin2 ///
	pf_d pf2 ///
	ph_d ph2 ///
	lac_d lac2 ///
	plat_d plat2 ///
	(ologit, ascontinuous) ///
	gcs_d gcs2 ///
	= age sex _d NA i.dx_cat time2icu ///
	, ///
	add($n_imputations) replace dots augment

// CHANGED: 2013-04-06 - now recover the original pre-vars from the differences
foreach var of global pre_vars {
	cap drop `var'1
	gen `var'1 = `var'2 - `var'_d
}

save ../data/working_mi_icnarc_plus_surv, replace

exit
