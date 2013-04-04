*  ============================================
*  = QQ plots of main physiological variables =
*  ============================================

/*
created: 	130404
modified:	130404

These will not be easy to interpret so show the dot-plots too:

So imagaine a regression line, then
- a shift of the intercept corresponds to a shift of the median of the distribution
- a line with a slope > 1 means that the y-distribution is more dispersed than the x
- aline with a slope < 1 means that the x-distribution is more dispersed
- a sigmoid with 'steeper' tails means that the tails of the x are more dispersed (fatter, kurtosis is less)
- a sigmoid with 'flatter' tails means that the tails of the x are less dispersed (thinner, kurtosis is more)

*/


use ../data/working_postflight.dta, clear
keep if time2icu < 24

// ignore population issues for now
// these are all the vars in the ICNARC model plus lactate plus platelets
local vars ///
 ims_c hr bps temp rr urea cr na wcc ///
 urin gcs pf ph ///
 lac plat


* local vars wcc bps
foreach var of local vars {
	su `var'1, d
	local max = r(p99)
	su `var'2, d
	if  `max' < r(p99) local max = r(p99)
	qqplot `var'2 `var'1 if `var'1 <= `max' & `var'2 <= `max' ///
		, ///
		aspect(1) xsize(4) ysize(4) ///
		title("") ///
		nodraw name(qq_`var', replace)
	local plots `plots' qq_`var'
}
graph combine `plots' ///
	, ///
	cols(3) ysize(10) xsize(6)


graph rename qqplot_combine, replace
graph display qqplot_combine
graph export ../outputs/figures/qqplot_combine.pdf ///
    , name(qqplot_combine) replace

