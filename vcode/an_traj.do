 * =================
 * = ## Main analysis =
 * =================

GenericSetupSteveHarris spot_traj an_traj
clear all
use ../data/working.dta
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
running dead28 age, ci name(age_dead28, replace) ///
	xlabel(`xmin' `xmax') ylabel(0 1) yscale(noextend) xscale(noextend)
graph export ../logs/age_dead28.pdf, replace
/* Nice and linear */

qui sum ims2
local xmin = r(min)
local xmax = r(max)
running dead28 ims2, ci name(ims2_dead28, replace) ///
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

/* Regression diagnostics */
cap drop regdx_*
predict regdx_dbeta, dbeta
label var regdx_dbeta "Influence"
predict regdx_dx2, dx2
sum regdx_dx2 regdx_dbeta
/* gsort without the mfirst option keeps the missing values at the end */
gsort -regdx_dx2
list id dead28 yhat_c ims2 regdx_dx2 regdx_dbeta if regdx_dx2 != . in 1/10
cap drop id_flag
gen id_flag = _n
label var id_flag "Flag records as per sort order"
label var regdx_dx2 "Change in Pearson chi-squared"
twoway 	(scatter regdx_dx2 yhat_c if id_flag <= 10, ///
		msym(i) mlab(id) mlabsize(small)) ///
		(scatter regdx_dx2 yhat_c  [aweight = regdx_dbeta], msym(oh) ///
		 name(d28_ims2_regex_dx2, replace))

predict regdx_ddev, ddeviance
sum regdx_ddev, d


label var regdx_ddev "Change in deviance"
sum regdx_ddev, d
list id dead28 yhat_c ims2 regdx_ddev if regdx_ddev > `r(p95)' & regdx_ddev != .
twoway 	(scatter regdx_ddev yhat_c, msym(i) mlab(id) mlabsize(small)) ///
		(scatter regdx_ddev yhat_c  [aweight = regdx_dbeta], msym(oh) ///
		 name(d28_ims2_regex_dx2, replace))


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
hist traj
running dead28 traj, ci
graph export ../logs/traj_running.pdf, replace
corr traj ims2
scatter traj ims2, name(traj_ims2, replace) ylab(-40 40) xlab(0 100) msym(p)
graph export ../logs/traj_ims2.pdf, replace
fracpoly, compare: regress traj ims2
fracplot, msym(p) name(traj_ims2_fp, replace)
graph export ../logs/traj_ims2_fp.pdf, replace
/* Quiet tight correlation and over the majority of the range linear */

/* Slow command ... */
* fracpoly, center(0) compare: logistic dead28 traj
* est store d28_t
* est table d28*, b(%9.3f) se(%9.3f) newpanel
* est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)

/* Univariate prediction */
/* fracpoly does not like negatives and numbers around zero */
cap drop traj100
gen traj100 = traj + 100
fracpoly, center(100) compare: logistic dead28 traj100
fracplot, msym(p) name(d28_traj_fp, replace)
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

xi: fracpoly, center(no) compare: logistic dead28 traj age 1 ims2 1 i.dx_cat 1
est store d28_f_t
est table d28*, b(%9.3f) se(%9.3f) newpanel
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)


/* Now predict response wrt trajectory */
cap drop yhat_*
fracpred yhat_c, for(traj)
fracpred yhat_e, for(traj) stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort traj
twoway (rarea yhat_u yhat_l traj, color(gs12)) ///
	(line yhat_c traj,  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_f_t, replace)
graph export ../data/logs/d28_f_traj.pdf, replace
/*
NOTE: 2012-11-12 - very little effect of trajectory ... essentially flat within 10 pts
*/

*  =========================
*  = ### Survival analysis =
*  =========================
stset date_trace, origin(time daicu) failure(dead) exit(time daicu+28)
fracgen traj -2 -2, replace
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


*  ==============================================
*  = ### Check specific physiological variables =
*  ==============================================
cap program drop traj_check
program traj_check
	syntax name(name=stem), [MMW(numlist min=3 max=3)]  ///

	confirm variable `stem'1 `stem'2
	if length("`mmw'") > 0 {
		local mmin = word("`mmw'", 1)
		local mmax = word("`mmw'", 2)
		local wwidth =word("`mmw'", 3) 
	}
	else {
		su `stem'1
		local mmin = `r(min)'
		local mmax = `r(max)'
		local wwidth = round((`mmax' -  `mmin') / 20)

	}
	di "Inspecting `stem'1 `stem'2 between `mmin' and `mmax', bin width(`wwidth')"
	local iif if `stem'1 > `mmin' & `stem'1 < `mmax'

	hist `stem'1 `iif', s(`mmin') w(`wwidth') name(`stem'_spot, replace)
	hist `stem'2 `iif', s(`mmin') w(`wwidth') name(`stem'_cmpd, replace)
	graph combine `stem'_spot `stem'_cmpd, col(1) xcommon ycommon name(`stem'1_`stem'2_hist, replace)
	graph export ../logs/`stem'1_`stem'2_hist.pdf, replace

	cap drop traj_`stem'
	gen traj_`stem' = `stem'2 - `stem'1 / time2icu
	label var traj_`stem' "`stem' slope"
	tabstat traj_`stem', stat(n mean sd skew kurt min max) col(st)
	hist traj_`stem' `iif' , s(`mmin') w(`wwidth') freq ///
		name(traj_`stem'_hist, replace)
	graph export ../logs/traj_`stem'_hist.pdf, replace

	running dead28 traj_`stem' `iif' , logit name(d28_`stem'_traj_running, replace)
	cap drop traj_`stem'_bc
	bcskew0 traj_`stem'_bc = traj_`stem', level(90)
	running dead28 traj_`stem'_bc `iif' , logit name(d28_`stem'_bc_traj_running, replace)
end
traj_check pf, mmw(0 100 2)

/* Very flat relationship ... not much hope! */
/* Now test CMPD PF ratio +/- pre-admission trajectory of PF */
/* Logistic model */
xi: fracpoly, compare: logistic dead28 traj_pf_bc pf2 age  i.dx_cat
est store d28_f_pf
fracplot, msym(p) name(traj_pf_d28)
logistic dead28 age  pf2 i.dx_cat if _est_d28_f_pf
est store d28_f
lrtest d28_f d28_f_pf
est table d28*, b(%9.3f) star newpanel stats(N ll aic bic)
/* Logistic model again but re-run without transformed P:F - easier to interpret */
xi: fracpoly, compare: logistic dead28 traj_pf pf2 age  i.dx_cat
est store d28_f_pf
fracplot if traj_pf > -50 & traj_pf < 50, msym(p) name(traj_pf_d28, replace)
graph export ../logs/traj_pf_d28.pdf, replace
/* Now manually run prediciton so you get probabilities instead of linear */
cap drop yhat_*
fracpred yhat_c, for(traj_pf)
fracpred yhat_e, for(traj_pf) stdp
gen yhat_l = yhat_c - 1.96 * yhat_e
gen yhat_u = yhat_c + 1.96 * yhat_e
cap drop yhat_e
foreach var of varlist yhat_* {
	replace `var' = invlogit(`var')
}
su yhat_*
sort traj_pf
cap restore, not
preserve
keep if traj_pf > -50 & traj_pf < 50
twoway (rarea yhat_u yhat_l traj_pf, color(gs12)) ///
	(line yhat_c traj_pf,  lpattern(l) ylab(0 1)) ///
	, legend(off) ///
	ytitle("Pr(28d mortality") ///
	name(d28_f_traj_pf, replace)
graph export ../data/logs/d28_f_traj_pf.pdf, replace
restore

/* Cox model */
local iif if traj_pf > -50 & traj_pf < 50
xi: fracpoly, compare: stcox traj_pf_bc pf2 age  i.dx_cat
est store cox_f_pf
/* Predictions after stcox are of the 'hazard ratio'  */
fracplot `iif', msym(p) name(traj_pf_cox, replace)
stcox age  pf2 i.dx_cat if _est_cox_f_pf
est store cox_f
lrtest cox_f cox_f_pf
est table cox*, b(%9.3f) star newpanel stats(N ll aic bic)

/* Re-run the FP model and graph survival function */
fracgen traj_pf 3 3, replace
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
sort traj_pf
local iif if traj_pf > -50 & traj_pf < 50
twoway (rarea yhat_u yhat_l traj_pf `iif', color(gs12)) ///
	(line yhat_c traj_pf `iif',  lpattern(l) ylab(0 5)) ///
	, legend(off) ///
	ytitle("Hazard ratio") ///
	name(cox_f_traj_pf, replace)
graph export ../data/logs/cox_f_traj_pf.pdf, replace
*/
local i = 1
forvalues v = -40(10)40 {
	fracgen traj_pf 3 3, replace
	local x = (`v'+`r(shift)') / `r(scale)'
	local p_1 = round(`x'^3, 0.01) 
	local p_2 = round(`x'^3 * ln(`x'), 0.01)
	local atlevels `atlevels' at`i'(traj_p_1 = `p_1' traj_p_2 = `p_2')
	local i = `i' + 1
}
di "`atlevels'"
stcurve, haz `atlevels' legend(pos(3) size(small))
graph export ../logs/cox_f_traj_pf_haz.pdf, replace


/*
So some small effect of delta PF with the lowest risk seen for 'stable' PF ratios
- small incr in risk for incr PF ratios!
- moderate incr in risk for decr PF ratios
*/

