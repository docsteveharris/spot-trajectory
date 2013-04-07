*  ==========================================================================
*  = Effect of trajectory - but examined only within the mid-range severity =
*  ==========================================================================
/*
created:	130407
modified:	130407

Examine trajectory in a region where constraints should not matter
- check this

Do this in the 'best' possible model (survival, severity as TVC, flexible forms)
- TVC in complete cases does not add much
- Looks roughly linear so stick with this for now
*/

GenericSetupSteveHarris spot_traj an_model_im_traj_monly, logon

use ../data/working_postflight_mi_plus_surv.dta, clear
merge m:1 id using ../data/working_postflight ///
	, keepusing(date_trace daicu dead) nolabel
drop if _merge != 3
drop _merge


cap drop cc
/* Complete cases */
gen cc = m0 == 1 & !missing(ims_c1, ims_c2)
label var cc "Complete cases"
label values cc truefalse
tab cc

/* Work with complete cases in original data and mid-range */
cap drop ims_c2_c
su ims_c2, d
gen ims_c2_c = ims_c2 - 20 // centre
cap drop ims_abg2_c
su ims_abg2, d
gen ims_abg2_c = ims_abg2 - 20 // centre

save ../data/scratch/scratch.dta, replace

use ../data/scratch/scratch.dta, clear
keep if m0 == 1 & !missing(ims_c1, ims_c2) & ims_c2_k == 2
count


/* Check constraints don't matter : max -ve traj  */
su ims_c_traj ims_c2
cap drop ims_c2_k10
egen ims_c2_k10 = cut(ims_c2), at(0(2)50)
tab ims_c2_k10
dotplot ims_c_traj , over(ims_c2_k10)
/*
OK: much less of a bounding issue on visual inspection
largest -ve traj is -20ish and this is possible *and* observed across (most) of the range
largest _ve traj is +10ish and this is similarly possible and observed
*/


/* Grid model using relative hazards */
stcox age_c sex i.dx_cat ib1.ims_c2_k##ib1.ims_tvector , nolog
margins ims_c2_k#ims_tvector if cc, atmeans grand post
est store margins_cc_grid
marginsplot, x(ims_tvector) legend(pos(3))
/* Same rough result as logistic model */


/* Now fit as continuous */
stcox age_c sex i.dx_cat c.ims_c2_c c.ims_c_traj , nolog
est store m1
stcox age_c sex i.dx_cat c.ims_c2_c##c.ims_c_traj , nolog
est store m2
est stats m1 m2
/* Not much to be gain with the interaction */

est restore m2
/* Inspect severity */
margins , at(ims_c2 = (-10(2)10))  vsquish atmeans noatlegend
marginsplot
/* Inspect trajectory */
margins , at(ims_c_traj = (-10(2)10))  vsquish atmeans noatlegend
marginsplot

/* Looks very nice but your are *forcing* a linear form */
cap drop traj_k
egen traj_k = cut(ims_c_traj), at(-100 -10(5)10 100) label
tab traj_k
stcox age_c sex i.dx_cat c.ims_c2_c##ib(freq).traj_k , nolog
margins traj_k ,  vsquish noatlegend
marginsplot
/* So that seems to confirm the story */

/* Now produce the final margins plot */
est restore m2
margins , at(ims_c_traj = (-10(1)10))  vsquish atmeans noatlegend

local ggreen "49 163 84"
local rred "215 48 31"
marginsplot ///
	, ///
	recastci(rarea) ///
	ciopts(pstyle(ci)) ///
	recast(line) ///
	xlabel(-10(5)10, labsize(small)) ///
	ylabel(,labsize(small)) ///
	title("") ///
	xsize(6) ysize(6) ///
	plotregion(margin(large)) ///
	addplot( ///
		(function y = 1, range(-10 10)) ///
		) ///
	xtitle("Change from pre-admission ICNARC score" ///
			"(1{superscript:st} 24 hour value - ward assessment value)", ///
			size(small)) ///
	text(0  7 "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
	text(0  0 "Neutral", placement(c) size(small)) ///
	text(0 -7 "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
	text(1 10 "Line of no effect", placement(nw) size(vsmall)) ///
	legend(off)

graph rename im_traj_monly_full, replace
graph export ../outputs/figures/im_traj_monly_full.pdf ///
    , name(im_traj_monly_full) replace


local inspect_tvc 0
if inspect_tvc {

	*  =======================================
	*  = Try this out with severity as a TVC =
	*  =======================================
	/* Can you get this to work as TVC */
	use ../data/scratch/scratch.dta, clear
	mi stset date_trace, id(id) origin(time daicu) failure(dead) exit(time daicu+28)
	mi stsplit tb, at(1 3 7)
	label var tb "Analysis time blocks"

	/* Work with complete cases */
	keep if cc & ims_c2_k == 2

	/* Now fit as continuous */
	cap drop ims_c2_c
	su ims_c2, d
	gen ims_c2_c = ims_c2 - 20 // centre

	stcox age_c sex i.dx_cat c.ims_c2_c##c.ims_c_traj , nolog
	est store m1
	stcox age_c sex i.dx_cat c.ims_c2_c i.tb#c.ims_c2_c c.ims_c_traj, nolog
	est store m2
	stcox age_c sex i.dx_cat c.ims_c2_c i.tb#c.ims_c2_c c.ims_c_traj, nolog
	est store m3
	stcox age_c sex i.dx_cat c.ims_c2_c i.tb#c.ims_c2_c c.ims_c_traj i.tb#c.ims_c_traj, nolog
	est store m4
	est stats m*
	/* Not much of an arguement for any TVC so keep this simple for now */

	/* Inspect severity with severity as TVC */
	est restore m2
	margins , at(ims_c2 = (-10(2)10))  vsquish atmeans noatlegend
	marginsplot
	margins , at(ims_c_traj = (-10(2)10))  vsquish atmeans noatlegend
	marginsplot
}


*  ===============================
*  = Now repeat using ICNARC-ABG =
*  ===============================
use ../data/scratch/scratch.dta, clear
keep if m0 == 1 & !missing(ims_abg1, ims_abg2) & ims_abg2_k == 2
count


/* Check constraints don't matter : max -ve traj  */
su ims_abg_traj ims_abg2
cap drop ims_abg2_k10
egen ims_abg2_k10 = cut(ims_abg2), at(0(2)50)
tab ims_abg2_k10
dotplot ims_abg_traj , over(ims_abg2_k10)
/*
OK: much less of a bounding issue on visual inspection
largest -ve traj is -20ish and this is possible *and* observed across (most) of the range
largest _ve traj is +10ish and this is similarly possible and observed
*/


/* Now fit as continuous */
stcox age_c sex i.dx_cat c.ims_abg2_c c.ims_abg_traj , nolog
est store m1
stcox age_c sex i.dx_cat c.ims_abg2_c##c.ims_abg_traj , nolog
est store m2
est stats m1 m2
/* Not much to be gain with the interaction */

est restore m2
/* Inspect severity */
margins , at(ims_abg2 = (-10(2)10))  vsquish atmeans noatlegend
marginsplot
/* Inspect trajectory */
margins , at(ims_abg_traj = (-10(2)10))  vsquish atmeans noatlegend
marginsplot

/* This time not much of an effect at all */
cap drop traj_k
egen traj_k = cut(ims_abg_traj), at(-100 -10(5)10 100) label
tab traj_k
stcox age_c sex i.dx_cat c.ims_abg2_c##ib(freq).traj_k , nolog
margins traj_k if traj_k != 4 ,  vsquish noatlegend
marginsplot
/* Nothing obviously non-linear here */

/* Now produce the final margins plot */
est restore m2
margins , at(ims_abg_traj = (-10(1)10))  vsquish atmeans noatlegend

local ggreen "49 163 84"
local rred "215 48 31"
marginsplot ///
	, ///
	recastci(rarea) ///
	ciopts(pstyle(ci)) ///
	recast(line) ///
	xlabel(-10(5)10, labsize(small)) ///
	plotopts(ylabel(0(0.5)2,labsize(small))) ///
	title("") ///
	xsize(6) ysize(6) ///
	plotregion(margin(large)) ///
	addplot( ///
		(function y = 1, range(-10 10)) ///
		) ///
	xtitle("Change from pre-admission (partial) ICNARC score" ///
			"(1{superscript:st} 24 hour value - ward assessment value)", ///
			size(small)) ///
	text(0  7 "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
	text(0  0 "Neutral", placement(c) size(small)) ///
	text(0 -7 "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
	text(1 10 "Line of no effect", placement(nw) size(vsmall)) ///
	legend(off) ///
	name(im_traj_monly_abg, replace)

graph export ../outputs/figures/im_traj_monly_abg.pdf ///
    , name(im_traj_monly_abg) replace

graph combine im_traj_monly_cc im_traj_monly_abg, ycommon rows(1)

*  ================================================
*  = Now try and reproduce this analysis using MI =
*  ================================================
use ../data/scratch/scratch.dta, clear
/*
Imputation model used raw physiology to predict missing
Since then you have grouped and weighted those values
I am not sure if this is OK or if these 'transformations' will not be properly estimated
*/


tab _mi_m ims_c2_k
// NOTE: 2013-04-07 - not sure why
// but dropping here means the MI commands only work on the original complete cases
* keep if ims_c2_k == 2
count


/* Check constraints don't matter : max -ve traj  */
su ims_c_traj ims_c2
cap drop ims_c2_k10
egen ims_c2_k10 = cut(ims_c2), at(0(2)50)
tab ims_c2_k10
dotplot ims_c_traj , over(ims_c2_k10)
/*
OK: much less of a bounding issue on visual inspection
largest -ve traj is -20ish and this is possible *and* observed across (most) of the range
largest _ve traj is +10ish and this is similarly possible and observed
*/


/* Grid model using relative hazards */
mi estimate, esampvaryok: ///
	stcox age_c sex i.dx_cat ib2.ims_tvector if ims_c2_k == 2 , nolog
/* Same rough result as logistic model */


/* Now fit as continuous */
cap drop esample
mi estimate, esampvaryok esample(esample) ///
	saving(../data/estimates/im_traj_monly_mi, replace): ///
	stcox age_c sex i.dx_cat c.ims_c2_c c.ims_c_traj if ims_c2_k == 2 , nolog
est store m1

cap drop esample
mi estimate, esampvaryok esample(esample) ///
	saving(../data/estimates/im_traj_monly_mi, replace): ///
	stcox age_c sex i.dx_cat c.ims_c2_c##c.ims_c_traj if ims_c2_k == 2
est store m2
/* No effect and what effect there is is in the *opposite* direction */
/* Not much to be gain with the interaction */

est restore m2

**************************************************
/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
// via http://bit.ly/10CEKNU
// assumes the current estimates are the ones to use
global margins_cmd "margins, at(ims_c_traj = (-10(2)10))"
est describe
global mi_est_cmdline `=r(cmdline)'
/* First specify the margins command HERE */
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
mi estimate, cmdok esampvaryok: emargins 1
mat b = e(b_mi)
mat V = e(V_mi)
if strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline & m0
if !strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline if m0
qui $margins_cmd
myret
mata: st_global("e(cmd)", "margins")
marginsplot

/* Now produce the final margins plot */

local ggreen "49 163 84"
local rred "215 48 31"
marginsplot ///
	, ///
	recastci(rarea) ///
	ciopts(pstyle(ci)) ///
	recast(line) ///
	xlabel(-10(5)10, labsize(small)) ///
	ylabel(,labsize(small)) ///
	title("") ///
	xsize(6) ysize(6) ///
	plotregion(margin(large)) ///
	addplot( ///
		(function y = 1, range(-10 10)) ///
		) ///
	xtitle("Change from pre-admission ICNARC score" ///
			"(1{superscript:st} 24 hour value - ward assessment value)", ///
			size(small)) ///
	text(0  7 "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
	text(0  0 "Neutral", placement(c) size(small)) ///
	text(0 -7 "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
	text(1 10 "Line of no effect", placement(nw) size(vsmall)) ///
	legend(off)

graph rename im_traj_monly_full_mi, replace
graph export ../outputs/figures/im_traj_monly_full_mi.pdf ///
    , name(im_traj_monly_full_mi) replace

/* Double check the form is not non-linear */
cap drop traj_k
egen traj_k = cut(ims_c_traj), at(-100 -10(5)10 100) label
tab traj_k if ims_c2_k == 2
cap drop esample
mi estimate, esampvaryok esample(esample): ///
	stcox age_c sex i.dx_cat c.ims_c2_c ib(freq).traj_k if ims_c2_k == 2
est store m3
est restore m3
**************************************************
/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
// via http://bit.ly/10CEKNU
// assumes the current estimates are the ones to use
/* First specify the margins command HERE */
global margins_cmd "margins, dydx(traj_k)"
est describe
global mi_est_cmdline `=r(cmdline)'
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
mi estimate, cmdok esampvaryok: emargins 1
mat b = e(b_mi)
mat V = e(V_mi)
if strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline & m0
if !strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline if m0
qui $margins_cmd
myret
mata: st_global("e(cmd)", "margins")

/* So this looks non-linear but without any meaningful pattern */



cap log close