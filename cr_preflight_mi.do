clear all
local datasets plus plus_surv
foreach dataset of local datasets {
	clear
	use ../data/working_mi_icnarc_`dataset'.dta
	merge m:1 id using ../data/working_postflight ///
		, keepusing(ims2 date_trace daicu dead) nolabel
	drop if _merge != 3
	drop _merge
	set scheme shbw
	// derive ICNARC score and weights
	include cr_severity.do

	cap drop age_c
	gen age_c = age - 65


	cap drop m0
	gen m0 = _mi_m == 0
	label var m0 "Original (pre-imputation) data"

	count
	tab m0


	save ../data/working_postflight_mi_`dataset'.dta, replace
}

