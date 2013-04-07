*  ====================================
*  = Model ICNARC score using Mi data =
*  ====================================

/*
Uses MI data

created:	130404
modified:	130405
*/

GenericSetupSteveHarris spot_traj an_mi_model_icnarc, logon
clear all
use ../data/working_mi_icnarc_plus.dta
set scheme shbw
// derive ICNARC score and weights
qui include cr_severity.do

cap drop age_c
gen age_c = age - 65

local traj_x 12
cap drop ims_c_traj
gen ims_c_traj = (ims_c2 - ims_c1) / (round(time2icu, `traj_x') + 1)
label var ims_c_traj "IMscore - complete - slope"
cap drop ims_ms_traj
gen ims_ms_traj = (ims_ms2 - ims_ms1) / (round(time2icu, `traj_x') + 1)
label var ims_ms_traj "ICNARC score (partial) - trajectory"

cap drop m0
gen m0 = _mi_m == 0
label var m0 "Original (pre-imputation) data"

save ../data/scratch/scratch.dta, replace
use ../data/scratch/scratch.dta, clear

local premodel_checks 0
if `premodel_checks' {

	// Check the distribution of the pre-imputation and imputed data
	su ims_c* if m0

	// hack that uses regress to get the mean via Rubin's rules (not that you need the SE)
	mi estimate: regress ims_c1
	mi estimate: regress ims_c1
	mi estimate: regress ims_c_traj

	/* Prepare a table of co-efficients / odds ratios */
	logit dead28 ims_c1 if m0, nolog
	logit dead28 ims_c2 if m0, nolog
	logit dead28 ims_c_traj if m0, nolog

	// now repeat using MI data
	mi estimate: logit dead28 ims_c1 , nolog
	mi estimate: logit dead28 ims_c2 , nolog
	mi estimate: logit dead28 ims_c_traj , nolog

	// now adjust without MI
	logit dead28 ims_c1 age_c i.dx_cat if m0, nolog
	/* current value, no trajectory */
	logit dead28 ims_c2 age_c i.dx_cat if m0, nolog
	est store m0_c_cv
	logit dead28 ims_c_traj age_c i.dx_cat if m0, nolog
	/* current value, linear trajectory */
	logit dead28 ims_c2 ims_c_traj age_c i.dx_cat if m0, nolog
	est store m0_c_cvt
	lrtest m0_c_cv m0_c_cvt

	// now adjust with MI
	mi estimate: logit dead28 ims_c1 age_c i.dx_cat, nolog
	/* current value, no trajectory */
	mi estimate: logit dead28 ims_c2 age_c i.dx_cat, nolog
	est store mi_c_cv
	mi estimate: logit dead28 ims_c_traj age_c i.dx_cat, nolog
	/* current value, linear trajectory */
	mi estimate: logit dead28 ims_c2 ims_c_traj age_c i.dx_cat, nolog
	est store mi_c_cvt

	/* Make a linear spline with knot at 0 */
	/* mkspline: linear splines run up to AND including the knot */
	cap drop ims_csp*
	mkspline ims_csp1 0 ims_csp2 = ims_c_traj, displayknots

	/* Now combine current value and trajectory */
	// first without MI
	logit dead28 ims_c2 ims_csp1 ims_csp2 if m0, or
	/* current value, linear spline trajectory */
	logit dead28 ims_c2 ims_csp1 ims_csp2 age_c i.dx_cat if m0, or
	est store m0_c_cvls
	lrtest m0_c_cv m0_c_cvls
	/* LR test NOT significant for linear spline term */
	estimates stats m0_c_cv m0_c_cvls

	// now with MI
	// first without MI
	mi estimate: logit dead28 ims_c2 ims_csp1 ims_csp2
	/* current value, linear spline trajectory */
	mi estimate, saving(../data/estimates/mi_c_cvls, replace):  ///
		logit dead28 ims_c2 ims_csp1 ims_csp2 age_c i.dx_cat
	est store mi_c_cvls
	/* LR test NOT significant for linear spline term */
	estimates stats mi_c_cv mi_c_cvls

	// prediction saved in original data so don't be surprised when all other data sets appear empty

	// hand version of margins
	cap drop ims_c2_orig
	clonevar ims_c2_orig = ims_c2
	su ims_c2 if m0
	replace ims_c2 = r(mean)
	cap drop xb_mi
	mi predict xb_mi using ../data/estimates/mi_c_cvls
	qui mi xeq: summ xb_mi
	cap drop phat_mi
	qui mi xeq: gen phat_mi = invlogit(xb_mi)
	running phat_mi ims_c_traj if m0, logit
	drop ims_c2
	rename ims_c2_orig ims_c2

}

/* Final model with interactions as planned */
global confounders age_c i.dx_cat sex
mi estimate, saving(../data/estimates/mi_est, replace):  ///
	logit dead28 

exit
mi estimate, saving(../data/estimates/mi_c_cvls, replace):  ///
	logit dead28 ims_c2 ims_csp1 ims_csp2 age_c i.dx_cat


/*
// hack to get margins to work via mi command
// via http://bit.ly/10CEKNU
cap program drop myret
program myret, rclass
    return add
    return matrix b = b
    return matrix V = V
end
cap program drop emargins
program emargins, eclass properties(mi)
	version 12
	logit dead28 ims_c2 c.ims_c_traj##c.ims_c_traj age_c i.dx_cat
	margins, atmeans at(ims_c_traj=(-20(4)20)) post
end
mi estimate, cmdok: emargins 1
mat b = e(b_mi)
mat V = e(V_mi)
qui logit dead28 ims_c2 c.ims_c_traj##c.ims_c_traj age_c i.dx_cat if m0
qui	margins, atmeans at(ims_c_traj=(-20(4)20))
myret
mata: st_global("e(cmd)", "margins")
marginsplot, x(ims_c_traj)
*/

/* INTERACTIONS */
/* Check for interaction between current value and trajectoy */
logit dead28 ims_c2 ims_csp1 ims_csp2 ///
	c.ims_c2#c.ims_csp1 c.ims_c2#c.ims_csp2 if m0, nolog
/* current value, linear spline trajectory */
logit dead28 ims_c2 ims_csp1 ims_csp2 ///
	c.ims_c2#c.ims_csp1 c.ims_c2#c.ims_csp2 ///
	age_c i.dx_cat  if m0, nolog
est store m0_c_cvls_int
lrtest m0_c_cvls m0_c_cvls_int
/* LR test *significant* for linear spline term */
estimates stats m0_c_cvls m0_c_cvls_int

// and now with the MI data
mi estimate: logit dead28 ims_c2 ims_csp1 ims_csp2 ///
	c.ims_c2#c.ims_csp1 c.ims_c2#c.ims_csp2, nolog
/* current value, linear spline trajectory */
mi estimate, saving(../data/estimates/mi_c_cvls_int, replace):  ///
	logit dead28 ims_c2 ims_csp1 ims_csp2 ///
	c.ims_c2#c.ims_csp1 c.ims_c2#c.ims_csp2 ///
	age_c i.dx_cat, nolog
est store m0_c_cvls_int


exit
// hack to get margins to work via mi command
// via http://bit.ly/10CEKNU
logit dead28 c.ims_c2 c.ims_c_traj age_c i.dx_cat if m0
est store m1
logit dead28 c.ims_c2##c.ims_c_traj age_c i.dx_cat if m0
est store m2
lrtest m1 m2
cap program drop myret
program myret, rclass
    return add
    return matrix b = b
    return matrix V = V
end
cap program drop emargins
program emargins, eclass properties(mi)
	version 12
	logit dead28 c.ims_c2##c.ims_c_traj age_c i.dx_cat
	margins, atmeans at(ims_c_traj=(-20(4)20)) post
end
mi estimate, cmdok: emargins 1
mat b = e(b_mi)
mat V = e(V_mi)
qui logit dead28 c.ims_c2##c.ims_c_traj age_c i.dx_cat if m0
qui	margins, atmeans at(ims_c_traj=(-20(4)20))
myret
mata: st_global("e(cmd)", "margins")
marginsplot, x(ims_c_traj)

cap log close