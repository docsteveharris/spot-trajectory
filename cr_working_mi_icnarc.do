*  ========================================
*  = Missing data and multiple imputation =
*  ========================================

/*
Use MI approach to rebuild the ICNARC score from the raw values available
After which you will need to generate the weights again

Decisions to discuss
- do you run the MI on the raw data and then generate the score using the imputed values
	or do you use the raw data as the input to generate the final score
- the MI model will often be non-linear
	... but the best predictor will be the 'paired' variable
	and this *should* be linear (i.e. Na is non-linear but na1 is a linear predictor of na2)
- might be best to run MI on the weights (and thereby handle the non-linearity issues)

Solutions
1. MI model using weights and including the final aggregate score
	- this will largely be missing - but hopefully there is enough info in the weights
2. MI model the raw data and then re-calculate the weights in the final model
	Then run your analyses in the MI data

Define the variables that should be kept in the MI data set

*/

clear all
use ../data/working.dta
qui include mtPrograms.do
qui include cr_preflight.do
use ../data/working_postflight.dta, clear
set scheme shbw
set seed 3001
local n_imputations 10
* sample 500, count

/* Complete observed vars (NB dx_cat missing in 14) */
// NOTE: 2013-04-04 - ignoring hierarchical structure for now
local complete_vars age sex dx_cat time2icu
keep if !missing(age, sex, dx_cat, dead28, time2icu)
global complete_vars `complete_vars'

/* ICNARC model vars */
local im_vars ///
	hr1 bps1 temp1 rr1 urea1 cr1 na1 wcc1 ///
	urin1 gcs1 pf1 ph1 ///
	hr2 bps2 temp2 rr2 urea2 cr2 na2 wcc2 ///
	urin2 gcs2 pf2 ph2

/* Other major physiology vars */
local severity_vars ///
	lac1 plat1 ///
	lac2 plat2

/* Vars used in MI but not part of physiology */
global other_vars ///
	rxfio2 intilpo

global mi_vars `im_vars' `severity_vars' 

/* Royston recommend using NA (Cumulative hazard function) if survival modelling */
cap drop NA
sts gen NA = na
local surv_vars _d NA
stset, clear

/* Work with a logistic outcome model for now */
local out_vars dead28
global out_vars `out_vars'

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
mi register passive $other_vars
mi register imputed $mi_vars
mi register regular $complete_vars $out_vars

/* Imputation model assumes linear relations? - check */

* collin $mi_vars

/* Multiple imputation step */
// NOTE: 2013-04-04 - force option specified - seems to struggle with some urine and pf??
// because I have large SE in the model?
// see http://bit.ly/XSjZBK
mi impute chained ///
	(pmm) ///
	hr1 hr2 ///
	bps1 bps2 ///
	temp1 temp2 ///
	rr1 rr2 ///
	urea1 urea2 ///
	cr1 cr2 ///
	na1 na2 ///
	wcc1 wcc2 ///
	urin1 urin2 ///
	pf1 pf2 ///
	ph1 ph2 ///
	lac1 lac2 ///
	plat1 plat2 ///
	(ologit, ascontinuous) ///
	gcs1 gcs2 ///
	= age sex dead28 i.dx_cat time2icu ///
	, ///
	add(`n_imputations') replace dots augment

save ../data/working_mi_icnarc_plus, replace

exit
