*  ======================
*  = Working log 121122 =
*  ======================
/*
Basic analysis to present for (SPOT)light trajectory in Pittsburgh
- differences since last shown to DH
	- pulled in more survival data
	- cleaner versions of ICNARC score
*/

/* ## Working on trajectory issues in (SPOT)light */

GenericSetupSteveHarris spot_traj labbook121122, logon
clear all
use ../data/working.dta
quietly include mtPrograms.do
quietly include cr_preflight.do
count
set scheme shbw

/* Centre adjustment variables */
su age
gen age_c = age - r(mean)
label var age_c "Age (centred)"
su ims2
gen ims2_c = ims2 - r(mean)
label var ims2_c "ICNARC physiology score (centred)"
*  ===========
*  = Lactate =
*  ===========
global iif_lac if lac_traj < 10 & lac_traj > -10 ///
	& lac1 < 10 & lac2 < 10 & lac1 >=0 & lac2 >=0

/* Inspect ward value vs ICU value */
running lac1 lac2 $iif_lac, ///
	yline(0, lcolor(gs12) noextend) ///
	ylab(0 5 10) yscale(range(-10 10) noextend) ///
	title("Ward vs ICU") ///
	name(plot1, replace)
running lac_traj lac2 $iif_lac, ///
	yline(0, lcolor(gs12) noextend) ///
	title("Trajectory vs ICU") ///
	name(plot2, replace)
graph combine plot1 plot2 , ///
	title("Lactate") ///
	row(1) name(lac_2v1, replace) ysize(3) xsize(4)
graph export ../logs/lac_2v1.pdf, replace

global iif_lac if !missing(lac1, lac2)

/* Inspect wrt 28d mortality */
running dead28 lac1 $iif_lac, ///
	title("Mortality vs initial ward lactate") ///
	name(plot1, replace)
running dead28 lac2 $iif_lac, ///
	title("Mortality vs initial ICU lactate") ///
	name(plot2, replace)
running dead28 lac_traj $iif_lac, ///
	title("Mortality vs lactate trajectory") ///
	name(plot3, replace)
graph combine plot1 plot2 plot3 , ///
	title("Lactate") ///
	row(1) name(lac_running, replace) ysize(3) xsize(6)
graph export ../logs/lac_running.pdf, replace

/* Prepare a table of co-efficients / odds ratios */
logit dead28 lac1 $iif_lac, or
logit dead28 lac2 $iif_lac, or
logit dead28 lac_traj $iif_lac, or

logit dead28 lac1 age_c i.dx_cat ims2_c $iif_lac, or
/* current value, no trajectory */
logit dead28 lac2 age_c i.dx_cat ims2_c $iif_lac, or
est store lac_cv
logit dead28 lac_traj age_c i.dx_cat ims2_c $iif_lac, or
/* current value, linear trajectory */
logit dead28 lac2 lac_traj age_c i.dx_cat ims2_c $iif_lac, or
est store lac_cvt
lrtest lac_cv lac_cvt
/* lrtest borderline significant */

/* Make a linear spline with knot at 0 */
/* mkspline: linear splines run up to AND including the knot */
cap drop lacsp*
mkspline lacsp1 0 lacsp2 = lac_traj, displayknots
logit dead28 lacsp1 lacsp2 $iif_lac, or
logit dead28 lacsp1 lacsp2 age_c i.dx_cat ims2_c  $iif_lac, or

/* Now combine current value and trajectory */
logit dead28 lac2 lacsp1 lacsp2 $iif_lac, or
/* current value, linear spline trajectory */
logit dead28 lac2 lacsp1 lacsp2 age_c i.dx_cat ims2_c  $iif_lac, or
est store lac_cvls
lrtest lac_cv lac_cvls
/* LR test borderline significant for linear spline term */
estimates stats lac_cv lac_cvls

/*
You will need to use margins and margins plot here
*/
margins, atmeans at(lacsp1 = (-10(1)0) lacsp2 = 0) ///
	noatlegend
marginsplot, recast(line) recastci(rarea) ///
	ylab(0 1) ciopts(color(*.5)) ///
	legend(off) name(plot1, replace)
/*
So Pr(death) is higher if for the same admission lactate ...
you have a higher pre-admission lactate
*/
margins, atmeans at(lacsp2 = (0(1)10) lacsp1 = 0) ///
	noatlegend
marginsplot, recast(line) recastci(rarea) ///
	ylab(0 1) ciopts(color(*.5)) ///
	legend(off) name(plot2, replace)
graph combine plot1 plot2, ///
	row(1) ysize(3) xsize(4) ycommon ///
	name(lac_margins, replace) 	
graph export ../logs/lac_margins.pdf, replace


/* Frac poly version */
/* fracpoly version */
xi: fracpoly, compare: logit dead28 lac_traj lac2 age_c i.dx_cat ims2_c $iif_lac
est store lac_cvfp
lrtest lac_cv lac_cvfp
estimates stats lac_cv lac_cvfp
/* Borderline significant improvement over 'current value only' */
fracplot if lac_traj > -10 & lac_traj < 10, msym(p)
graph export ../logs/lac_fracplot.pdf, replace

/* Finally check in a survival model ... would expect this to better tease apart differences */

stcox lac2 age_c i.dx_cat ims2_c  $iif_lac, nolog
est store lac_cox_cv
stcox lac2 lacsp1 lacsp2 age_c i.dx_cat ims2_c  $iif_lac, nolog
est store lac_cox_cvls
lrtest lac_cox_cv lac_cox_cvls
/* current value only, linear spline with same knot really does not help */
xi: fracpoly, compare: stcox lac_traj lac2 age_c i.dx_cat ims2_c $iif_lac, nolog
est store lac_cox_cvfp
lrtest lac_cv lac_cvfp
estimates stats lac_cv lac_cvfp
/* Significant improvement over 'current value only', similar to logit */
fracplot if lac_traj > -10 & lac_traj < 10, msym(p)
graph export ../logs/lac_fracplot.pdf, replace


*  =================================
*  = ICNARC score - complete cases =
*  =================================
su ims_c*
global iif_ims_c if !missing(ims_c1, ims_c2)
codebook ims_c* $iif_ims_c , compact
tabstat ims_c* $iif_ims_c, s(n mean sd skew kurt min max) c(s)
/* Note very little difference in mean score */
corr ims_c1 ims_c2 $iif_ims_c

/* Set the if stmt to better show graphs */
global iif_ims_c if !missing(ims_c1, ims_c2) & ims_c1 < 40 & ims_c2 < 40 ///
	& abs(ims_c_traj) < 20
/* Inspect ward value vs ICU value */
running ims_c1 ims_c2 $iif_ims_c, ///
	yline(0, lcolor(gs12) noextend) ///
	ylab(0(10)40) yscale(range(-20 40) noextend) ///
	title("Ward vs ICU") ///
	name(plot1, replace)
running ims_c_traj ims_c2 $iif_ims_c, ///
	yline(0, lcolor(gs12) noextend) ///
	ylab(-20(10)20) yscale(range(-20 40) noextend) ///
	title("Trajectory vs ICU") ///
	name(plot2, replace)
graph combine plot1 plot2 , ///
	title("ICNARC score (complete)") ///
	row(1) name(ims_c_2v1, replace) ysize(3) xsize(4)
graph export ../logs/ims_c_2v1.pdf, replace

/* Inspect wrt 28d mortality */
running dead28 ims_c1 $iif_ims_c, ///
	title("Initial ward score") ///
	name(plot1, replace)
running dead28 ims_c2 $iif_ims_c, ///
	title("Initial ICU score") ///
	name(plot2, replace)
running dead28 ims_c_traj $iif_ims_c, ///
	title("Trajectory") ///
	name(plot3, replace)
graph combine plot1 plot2 plot3 , ///
	title("28 day mortality vs ICNARC score (complete)") ///
	ycommon ///
	row(1) name(ims_c_running, replace) ysize(3) xsize(6)
graph export ../logs/ims_c_running.pdf, replace


/* NOW MODEL */
/* Reset the exclusion if stmt for modelling */
global iif_ims_c if !missing(ims_c1, ims_c2)

/* Prepare a table of co-efficients / odds ratios */
logit dead28 ims_c1 $iif_ims_c, or
logit dead28 ims_c2 $iif_ims_c, or
logit dead28 ims_c_traj $iif_ims_c, or

logit dead28 ims_c1 age_c i.dx_cat ims2_c $iif_ims_c, or
/* current value, no trajectory */
logit dead28 ims_c2 age_c i.dx_cat ims2_c $iif_ims_c, or
est store ims_c_cv
logit dead28 ims_c_traj age_c i.dx_cat ims2_c $iif_ims_c, or
/* current value, linear trajectory */
logit dead28 ims_c2 ims_c_traj age_c i.dx_cat ims2_c $iif_ims_c, or
est store ims_c_cvt
lrtest ims_c_cv ims_c_cvt
/* lrtest borderline significant ... but form of trajectory misspecified*/

/* Make a linear spline with knot at 0 */
/* mkspline: linear splines run up to AND including the knot */
cap drop ims_csp*
mkspline ims_csp1 0 ims_csp2 = ims_c_traj, displayknots
logit dead28 ims_csp1 ims_csp2 $iif_ims_c, or
logit dead28 ims_csp1 ims_csp2 age_c i.dx_cat ims2_c  $iif_ims_c, or

/* Now combine current value and trajectory */
logit dead28 ims_c2 ims_csp1 ims_csp2 $iif_ims_c, or
/* current value, linear spline trajectory */
logit dead28 ims_c2 ims_csp1 ims_csp2 age_c i.dx_cat ims2_c  $iif_ims_c, or
est store ims_c_cvls
lrtest ims_c_cv ims_c_cvls
/* LR test NOT significant for linear spline term */
estimates stats ims_c_cv ims_c_cvls

/*
You will need to use margins and margins plot here
*/
margins, atmeans at(ims_csp1 = (-20(4)0) ims_csp2 = 0) ///
	noatlegend
marginsplot, recast(line) ///
	yline(0.29, noextend lcolor(gs8)) ///
	ylab(0 1) ciopts(color(*.5)) ///
	legend(off) name(plot1, replace)
/*
So Pr(death) is higher if for the same admission IM score (complete) ...
you have a higher pre-admission IM score (complete)
*/
margins, atmeans at(ims_csp2 = (0(4)20) ims_csp1 = 0) ///
	noatlegend
marginsplot, recast(line) ///
	yline(0.29, noextend lcolor(gs8)) ///
	ylab(0 1) ciopts(color(*.5)) ///
	legend(off) name(plot2, replace)
graph combine plot1 plot2, ///
	row(1) ysize(3) xsize(4) ycommon ///
	name(ims_c_margins, replace) 	
graph export ../logs/ims_c_margins.pdf, replace


/* Frac poly version */
/* fracpoly version */
xi: fracpoly, compare: logit dead28 ims_c_traj ims_c2 age_c i.dx_cat ims2_c $iif_ims_c
est store ims_c_cvfp
lrtest ims_c_cv ims_c_cvfp
estimates stats ims_c_cv ims_c_cvfp
/* *Borderline* significant improvement over 'current value only' */
fracplot if ims_c_traj > -20 & ims_c_traj < 20, msym(p)
graph export ../logs/ims_c_fracplot.pdf, replace
/*
NOTE: 2012-11-22 - GOOD! Lead time bias evidence: you can massage the figures but patients still do badly?
*/

/* Finally check in a survival model ... would expect this to better tease apart differences */

stcox ims_c2 age_c i.dx_cat ims2_c  $iif_ims_c, nolog
est store ims_c_cox_cv
stcox ims_c2 ims_csp1 ims_csp2 age_c i.dx_cat ims2_c  $iif_ims_c, nolog
est store ims_c_cox_cvls
lrtest ims_c_cox_cv ims_c_cox_cvls
/* current value only, linear spline with same knot really does not help */
xi: fracpoly, compare: stcox ims_c_traj ims_c2 age_c i.dx_cat ims2_c $iif_ims_c, nolog
est store ims_c_cox_cvfp
lrtest ims_c_cox_cv ims_c_cox_cvfp
estimates stats ims_c_cox_cv ims_c_cox_cvfp
/* *Borderline* significant improvement over 'current value only', similar to logit */
fracplot if ims_c_traj > -20 & ims_c_traj < 20, msym(p) ///
	yline(0, noextend lcolor(gs8))
graph export ../logs/ims_c_fracplot.pdf, replace

*  ==========================
*  = ICNARC score - partial =
*  ==========================
/*

8 of 12 components of ICNARC physiology score
- hr
- bps
- rr
- cr
- na
- wcc
- temp
- urea
*/

su ims_ms*
global iif_ims_ms if !missing(ims_ms1, ims_ms2)
codebook ims_ms* $iif_ims_ms , compact
tabstat ims_ms* $iif_ims_ms, s(n mean sd skew kurt min max) c(s)
/* Note very little difference in mean score */
corr ims_ms1 ims_ms2 $iif_ims_ms


/* Set the if stmt to better show graphs */
global iif_ims_ms if !missing(ims_ms1, ims_ms2) & ims_ms1 < 40 & ims_ms2 < 40 ///
	& abs(ims_ms_traj) < 20
/* Inspect ward value vs ICU value */
running ims_ms1 ims_ms2 $iif_ims_ms, ///
	yline(0, lcolor(gs12) noextend) ///
	ylab(0(10)40) yscale(range(-20 40) noextend) ///
	title("Ward vs ICU") ///
	name(plot1, replace)
running ims_ms_traj ims_ms2 $iif_ims_ms, ///
	yline(0, lcolor(gs12) noextend) ///
	ylab(-20(10)20) yscale(range(-20 40) noextend) ///
	title("Trajectory vs ICU") ///
	name(plot2, replace)
graph combine plot1 plot2 , ///
	title("ICNARC score (partial)") ///
	row(1) name(ims_ms_2v1, replace) ysize(3) xsize(4)
graph export ../logs/ims_ms_2v1.pdf, replace

/* Inspect wrt 28d mortality */
running dead28 ims_ms1 $iif_ims_ms, ///
	title("Initial ward score") ///
	name(plot1, replace)
running dead28 ims_ms2 $iif_ims_ms, ///
	title("Initial ICU score") ///
	name(plot2, replace)
running dead28 ims_ms_traj $iif_ims_ms, ///
	title("Trajectory") ///
	name(plot3, replace)
graph combine plot1 plot2 plot3 , ///
	title("28 day mortality vs ICNARC score (partial)") ///
	ycommon ///
	row(1) name(ims_ms_running, replace) ysize(3) xsize(6)
graph export ../logs/ims_ms_running.pdf, replace


/* NOW MODEL */
/* Reset the exclusion if stmt for modelling */
global iif_ims_ms if !missing(ims_ms1, ims_ms2)

/* Prepare a table of co-efficients / odds ratios */
logit dead28 ims_ms1 $iif_ims_ms, or
logit dead28 ims_ms2 $iif_ims_ms, or
logit dead28 ims_ms_traj $iif_ims_ms, or

logit dead28 ims_ms1 age_c i.dx_cat $iif_ims_ms, or
/* current value, no trajectory */
logit dead28 ims_ms2 age_c i.dx_cat $iif_ims_ms, or
est store ims_ms_cv
logit dead28 ims_ms_traj age_c i.dx_cat $iif_ims_ms, or
/* current value, linear trajectory */
logit dead28 ims_ms2 ims_ms_traj age_c i.dx_cat $iif_ims_ms, or
est store ims_ms_cvt
lrtest ims_ms_cv ims_ms_cvt
/* lrtest borderline significant ... but form of trajectory misspecified*/

/* Make a linear spline with knot at 0 */
/* mkspline: linear splines run up to AND including the knot */
cap drop ims_mssp*
mkspline ims_mssp1 0 ims_mssp2 = ims_ms_traj, displayknots
logit dead28 ims_mssp1 ims_mssp2 $iif_ims_ms, or
logit dead28 ims_mssp1 ims_mssp2 age_c i.dx_cat  $iif_ims_ms, or

/* Now combine current value and trajectory */
logit dead28 ims_ms2 ims_mssp1 ims_mssp2 $iif_ims_ms, or
/* current value, linear spline trajectory */
logit dead28 ims_ms2 ims_mssp1 ims_mssp2 age_c i.dx_cat  $iif_ims_ms, or
est store ims_ms_cvls
lrtest ims_ms_cv ims_ms_cvls
/* LR test *significant* for linear spline term */
estimates stats ims_ms_cv ims_ms_cvls

/*
You will need to use margins and margins plot here
*/
margins, atmeans at(ims_mssp1 = (-20(4)0) ims_mssp2 = 0) ///
	noatlegend
marginsplot, recast(line) ///
	yline(0.28, noextend lcolor(gs8)) ///
	ylab(0 1) ciopts(color(*.5)) ///
	legend(off) name(plot1, replace)
/*
So Pr(death) is higher if for the same admission IM score (complete) ...
you have a higher pre-admission IM score (complete)
*/
margins, atmeans at(ims_mssp2 = (0(4)20) ims_mssp1 = 0) ///
	noatlegend
marginsplot, recast(line) ///
	yline(0.28, noextend lcolor(gs8)) ///
	ylab(0 1) ciopts(color(*.5)) ///
	legend(off) name(plot2, replace)
graph combine plot1 plot2, ///
	row(1) ysize(3) xsize(4) ycommon ///
	name(ims_ms_margins, replace) 	
graph export ../logs/ims_ms_margins.pdf, replace


/* Frac poly version */
/* fracpoly version */
xi: fracpoly, compare: logit dead28 ims_ms_traj ims_ms2 age_c i.dx_cat $iif_ims_ms
est store ims_ms_cvfp
lrtest ims_ms_cv ims_ms_cvfp
estimates stats ims_ms_cv ims_ms_cvfp
/* *Borderline* significant improvement over 'current value only' */
fracplot if ims_ms_traj > -20 & ims_ms_traj < 20, msym(p)
graph export ../logs/ims_ms_fracplot.pdf, replace
/*
NOTE: 2012-11-22 - GOOD! Lead time bias evidence: you can massage the figures but patients still do badly?
*/

/* Finally check in a survival model ... would expect this to better tease apart differences */

stcox ims_ms2 age_c i.dx_cat  $iif_ims_ms, nolog
est store ims_ms_cox_cv
stcox ims_ms2 ims_mssp1 ims_mssp2 age_c i.dx_cat  $iif_ims_ms, nolog
est store ims_ms_cox_cvls
lrtest ims_ms_cox_cv ims_ms_cox_cvls
/* current value only, linear spline with same knot really does not help */
xi: fracpoly, compare: stcox ims_ms_traj ims_ms2 age_c i.dx_cat $iif_ims_ms, nolog
est store ims_ms_cox_cvfp
lrtest ims_ms_cox_cv ims_ms_cox_cvfp
estimates stats ims_ms_cox_cv ims_ms_cox_cvfp
/* *HIGHLY* significant improvement over 'current value only', similar to logit */
fracplot if ims_ms_traj > -20 & ims_ms_traj < 20, msym(p) ///
	yline(0, noextend lcolor(gs8))
graph export ../logs/ims_ms_cox_fracplot.pdf, replace


cap log close