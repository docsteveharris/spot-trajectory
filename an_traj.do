 * =================
 * = ## Main analysis =
 * =================

GenericSetupSteveHarris spot_traj an_traj, logon
clear all
use ../data/working_survival.dta
quietly include mtPrograms.do
quietly include cr_preflight.do
count
set scheme shbw

*  ============================
*  = ### Pre-model building steps =
*  ============================
/*

List variables that you plan on including (this is all there is in the ICNARC model)
- age
- diagnostic category (as an interaction)
- ims2

Subgroups
- specific  focus on viral and other pneumonia to link to SwiFT work
- other major diagnoses

*/
stset date_trace, origin(time daicu) failure(dead) exit(time daicu+90)

/*
Univariate relations with 28d mortality
*/

qui sum age
local xmin = r(min)
local xmax = r(max)
running dead28 age, logit name(age_dead28, replace) ///
	xlabel(`xmin' `xmax') ylabel(0 1) yscale(noextend) xscale(noextend)
graph export ../logs/age_dead28.pdf, replace
/* Nice and linear */

qui sum ims2
local xmin = r(min)
local xmax = r(max)
running dead28 ims2, logit name(ims2_dead28, replace) ///
	xlabel(`xmin' `xmax') ylabel(0 1) yscale(noextend) xscale(noextend)
graph export ../logs/ims2_dead28.pdf, replace
/* Non-linear below 10 - presumbably because of the missing data approach */

foreach var of varlist dx_pneum_v dx_pneum_b dx_pneum_u dx_sepshock dx_acpanc dx_arf {
	/* Set up here so always comparing against the same 'other' */
	d `var'
	cap drop dx2test
	gen dx2test = 0 if dx_other == 1
	replace dx2test = 1 if `var' == 1
	tab dx2test
	prtest dead28, by(dx2test)
}

/*
Higher mortality with
- bacterial pneumonia
- undiagnosed pneumonia
- septic shock
Lower mortality with
- acute pancreatitis
No difference
- viral pneumonia
- ARF
*/

*  ====================================
*  = Logistic model for 28d mortality =
*  ====================================

est drop _all
logistic dead28
est store d28

/* Age */
logistic dead28 age
est store d28_a
est table d28*, b(%9.3f) se(%9.3f) newpanel
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)
cap drop yhat_*
predict yhat_c, xb
predict yhat_e, stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort age
twoway (rarea yhat_u yhat_l age, color(gs12)) ///
	(line yhat_c age,  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_age, replace)
graph export ../logs/d28_age.pdf, replace


/* ICNARC physiology score @ admission */
logistic dead28 ims2
est store d28_i
est table d28*, b(%9.3f) se(%9.3f) newpanel
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)
cap drop yhat_*
predict yhat_c, xb
predict yhat_e, stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort ims2
twoway (rarea yhat_u yhat_l ims2, color(gs12)) ///
	(line yhat_c ims2,  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_ims2, replace)
graph export ../logs/d28_ims2.pdf, replace

/* Diagnostic category */
tab dx_cat
logistic dead28 i.dx_cat
est store d28_dx
est table d28*, b(%9.3f) se(%9.3f) newpanel
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)


*  ==============
*  = Full model =
*  ==============
logistic dead28 age ims2 i.dx_cat
est store d28_f
est table d28*, b(%9.3f) se(%9.3f) newpanel
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)

/* repeat with interactions */
logistic dead28 age c.ims2##i.dx_cat
est store d28_fi
est table d28*, b(%9.3f) se(%9.3f) newpanel
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)

/* Little improvement ... for simplicity ignore for now */

*  ==========================
*  = ### Now inspect trajectory =
*  ==========================
/*
So at this stage (written in retrospect after first round of analysis)
- little overall effect for trajectory except at extremes
- no evidence of an effect within a specific diangostic group
- some evidence that P:F ratio may have an effect but relatively weak

NOTE: 2012-11-13 - method of calculating trajectory could be problematic
- currently: (value2 - value1) / time2icu
- if time2icu is short then this 'magnifies any error in the difference'
- can't think of a good rule of thumb
	- but could just examine if time2icu > 12hrs
	- or divide by 'days' instead of hours
*/


tabstat pf* ims* traj*, stat(n mean sd skew kurt min max) col(st)

hist ims_traj
running dead28 ims_traj, logit
graph export ../logs/ims_traj_running.pdf, replace
corr ims_traj ims2
scatter ims_traj ims2, name(ims_traj2, replace) ylab(-40 40) xlab(0 100) msym(p)
graph export ../logs/ims_traj2.pdf, replace
fracpoly, compare: regress ims_traj ims2
fracplot, msym(p) name(ims_traj2_fp, replace)
graph export ../logs/ims_traj2_fp.pdf, replace
/* Quiet tight correlation and over the majority of the range linear */


/* Univariate prediction */
/* fracpoly does not like negatives and numbers around zero */
cap drop traj100
gen traj100 = ims_traj + 100
fracpoly, center(100) compare: logistic dead28 traj100
fracplot, msym(p) name(d28_traj_fp, replace) yline(0)
graph export ../logs/d28_traj_fp.pdf, replace

*  =============================
*  = ### Now add in trajectory =
*  =============================
/*
Not worried about centering until now but fracpred works at the centred values
So
- centre age to mean
- centre ims2 to mean
- baseline cat of dx_cat is OK

*/
qui su age
replace age = age - `r(mean)'
qui su ims2
replace ims2 = ims2 - `r(mean)'

xi: fracpoly, center(no) compare: logistic dead28 ims_traj age 1 ims2 1 i.dx_cat 1
est store d28_f_t
est table d28*, b(%9.3f) se(%9.3f) newpanel
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)


/* Now predict response wrt trajectory */
cap drop yhat_*
fracpred yhat_c, for(ims_traj)
fracpred yhat_e, for(ims_traj) stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort ims_traj
twoway (rarea yhat_u yhat_l ims_traj, color(gs12)) ///
	(line yhat_c ims_traj,  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_f_t, replace)
graph export ../logs/d28_f_ims_traj.pdf, replace

logistic dead28 ib4.ims_traj_cat age ims2 i.dx_cat


/*
NOTE: 2012-11-12 - very little effect of trajectory ... essentially flat within 10 pts
*/

*  =========================
*  = ### Survival analysis =
*  =========================

stset date_trace, origin(time daicu) failure(dead) exit(time daicu+28)

/* Using categories for trajectory */
stcox ib4.ims_traj_cat age ims2 i.dx_cat
/* Fractional polynomial specification */
fracgen ims_traj -2 -2, replace
rename traj_i_1 traj_1
rename traj_i_2 traj_2
stcox traj_1 traj_2 age ims2 i.dx_cat
est store cox_f_t
stcox age ims2 i.dx_cat if _est_cox_f_t
est store cox_f
lrtest cox_f cox_f_t
est table cox*, b(%9.3f) star newpanel stats(N ll aic bic)

/* Check for interactions with ims2 */
stcox  age ims2 traj_1 traj_2 i.dx_cat c.ims2#c.traj_1 c.ims2#c.traj_2
/* Now the model does not seem to fit at all well */

/* Now check for interactions with diagnostic categories */
stcox  age ims2 traj_1 traj_2 i.dx_cat c.traj_1#dx_cat c.traj_2#dx_cat
/* Very unimpressive */

*  ============================
*  = ### Check within subgrps =
*  ============================
foreach var of varlist dx_pneum_u dx_pneum_b dx_sepshock dx_acpanc dx_arf {
	preserve
	di "#### Checking within `var' "
	d `var'
	keep if `var'
	stcox traj_1 traj_2 age ims2 i.dx_cat, nolog noshow
	est store cox_f_t
	stcox age ims2 i.dx_cat if _est_cox_f_t, nolog noshow
	est store cox_f
	lrtest cox_f cox_f_t
	est table cox*, b(%9.3f) star newpanel stats(N ll aic bic)
	restore
}

/*
... ditto, still no effect
*/


*  ==================
*  = #### P:F ratio =
*  ==================

/* Very flat relationship ... not much hope! */
/* Now test CMPD PF ratio +/- pre-admission trajectory of PF */
/* Logistic model */
local iif if pf_traj > -50 & pf_traj < 50
xi: fracpoly, compare: logistic dead28 pf_traj pf2 age  i.dx_cat `iif'
est store d28_f_pf
fracplot `íif', msym(p) name(pf_traj_d28, replace)
logistic dead28 age  pf2 i.dx_cat if _est_d28_f_pf
est store d28_f
lrtest d28_f d28_f_pf
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)
/* Now manually run prediciton so you get probabilities instead of linear */
est restore d28_f_pf
cap drop yhat_*
fracpred yhat_c, for(pf_traj)
fracpred yhat_e, for(pf_traj) stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort pf_traj
cap restore, not
preserve
keep if pf_traj > -50 & pf_traj < 50
twoway (rarea yhat_u yhat_l pf_traj, color(gs12)) ///
	(line yhat_c pf_traj,  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_f_pf_traj, replace)
graph export ../logs/d28_f_pf_traj.pdf, replace
restore

/* Cox model */
local iif if pf_traj > -50 & pf_traj < 50
xi: fracpoly, compare: stcox pf_traj pf2 age  i.dx_cat
est store cox_f_pf
/* Predictions after stcox are of the 'hazard ratio'  */
fracplot `iif', msym(p) name(pf_traj_cox, replace)
stcox age  pf2 i.dx_cat if _est_cox_f_pf
est store cox_f
lrtest cox_f cox_f_pf
est table cox*, b(%9.3f) star newpanel stats(N ll aic bic)

/* Re-run the FP model and graph survival function */
fracgen pf_traj 3 3, replace
stcox traj_p_1 traj_p_2 pf2 age  i.dx_cat
/* Now manually run prediciton so you get probabilities instead of linear */
/* TODO: 2012-11-13 - this is not working ... why? */
/*
cap drop yhat_*
predict yhat_c, xb
predict yhat_e, stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = exp(`var')
}
su yhat_*
sort pf_traj
local iif if pf_traj > -50 & pf_traj < 50
twoway (rarea yhat_u yhat_l pf_traj `iif', color(gs12)) ///
	(line yhat_c pf_traj `iif',  lpattern(l) ylab(0 5)) ///
	, legend(off) ///
	ytitle("Hazard ratio") ///
	name(cox_f_pf_traj, replace)
graph export ../logs/cox_f_pf_traj.pdf, replace
*/
local i = 1
forvalues v = -40(10)40 {
	fracgen pf_traj 3 3, replace
	local x = (`v'+`r(shift)') / `r(scale)'
	local p_1 = round(`x'^3, 0.01)
	local p_2 = round(`x'^3 * ln(`x'), 0.01)
	local atlevels `atlevels' at`i'(traj_p_1 = `p_1' traj_p_2 = `p_2')
	local i = `i' + 1
}
di "`atlevels'"
stcurve, haz `atlevels' legend(pos(3) size(small))
graph export ../logs/cox_f_pf_traj_haz.pdf, replace


/*
So some small effect of delta PF with the lowest risk seen for 'stable' PF ratios
- small incr in risk for incr PF ratios!
- moderate incr in risk for decr PF ratios
*/
*  ==============
*  = #### Urine vol =
*  ==============

/* Logistic model */
xi: fracpoly, compare: logistic dead28 traj_urin urin2 age  i.dx_cat
est store d28_f_urin
fracplot, msym(p) name(traj_urin_d28)
logistic dead28 age  urin2 i.dx_cat if _est_d28_f_urin
est store d28_f
lrtest d28_f d28_f_urin
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)
/* Logistic model again but re-run without transformed P:F - easier to interpret */
xi: fracpoly, compare: logistic dead28 traj_urin urin2 age  i.dx_cat
est store d28_f_urin
local iif if traj_urin > -100 & traj_urin < 100
fracplot `iif', msym(p) name(traj_urin_d28, replace)
graph export ../logs/traj_urin_d28.pdf, replace
/* Now manually run prediciton so you get probabilities instead of linear */
cap drop yhat_*
fracpred yhat_c, for(traj_urin)
fracpred yhat_e, for(traj_urin) stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort traj_urin
twoway (rarea yhat_u yhat_l traj_urin `iif', color(gs12)) ///
	(line yhat_c traj_urin `iif',  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_f_traj_urin, replace)
graph export ../logs/d28_f_traj_urin.pdf, replace

/* Cox model */
local iif if traj_urin > -100 & traj_urin < 100
xi: fracpoly, compare: stcox traj_urin urin2 age  i.dx_cat
est store cox_f_urin
/* Predictions after stcox are of the 'hazard ratio'  */
fracplot `iif', msym(p) name(traj_urin_cox, replace)
stcox age  urin2 i.dx_cat if _est_cox_f_urin
est store cox_f
lrtest cox_f cox_f_urin
est table cox*, b(%9.3f) star newpanel stats(N ll aic bic)

*  ==============
*  = #### Creatinine =
*  ==============

/* Logistic model */
xi: fracpoly, compare: logistic dead28 cr_traj cr2 age  i.dx_cat
est store d28_f_cr
fracplot, msym(p) name(cr_traj_d28, replace)
logistic dead28 age  cr2 i.dx_cat if _est_d28_f_cr
est store d28_f
lrtest d28_f d28_f_cr
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)
est restore d28_f_cr
local iif if cr_traj > -500 & cr_traj < 500
fracplot `iif', msym(p) name(cr_traj_d28, replace)
graph export ../logs/cr_traj_d28.pdf, replace
/* Now manually run prediciton so you get probabilities instead of linear */
cap drop yhat_*
fracpred yhat_c, for(cr_traj)
fracpred yhat_e, for(cr_traj) stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort cr_traj
twoway (rarea yhat_u yhat_l cr_traj `iif', color(gs12)) ///
	(line yhat_c cr_traj `iif',  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_f_cr_traj, replace)
graph export ../logs/d28_f_cr_traj.pdf, replace

/* Cox model */
local iif if cr_traj > -500 & cr_traj < 500
xi: fracpoly, compare: stcox cr_traj cr2 age  i.dx_cat
est store cox_f_cr
/* Predictions after stcox are of the 'hazard ratio'  */
fracplot `iif', msym(p) name(cr_traj_cox, replace)
stcox age  cr2 i.dx_cat if _est_cox_f_cr
est store cox_f
lrtest cox_f cox_f_cr
est table cox*, b(%9.3f) star newpanel stats(N ll aic bic)












* NOTE: 2012-11-13 - comment out log close else will not work with master file
log close
