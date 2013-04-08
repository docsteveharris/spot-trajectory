*  ==========================================================================
*  = Effect of trajectory - but examined only within the mid-range severity =
*  ==========================================================================
/*
created:	130408
modified:	130408

Examine trajectory in a region where constraints should not matter

*/

GenericSetupSteveHarris spot_traj an_model_raw_monly, logon

*  ============================
*  = Bring in the MI data set =
*  ============================
local physiology working_postflight_mi_plus_surv
use ../data/`physiology'.dta, clear
merge m:1 id using ../data/working_postflight ///
	, keepusing(date_trace daicu dead dead28) nolabel
drop if _merge != 3
drop _merge

global table_name model_raw_monly
tempfile estimates_file working
global i = 0

*  =====================================================
*  = Define the grid for the physiology being examined =
*  =====================================================

spikeplot lac2 if m0, name(p2, replace) nodraw
spikeplot lac1 if m0, name(p1, replace) nodraw
spikeplot lac_traj if m0, name(pt, replace) nodraw
graph combine p1 p2 pt, col(1)

su lac1 lac2 lac_traj, d

/* Transform? */
cap drop lac2_bc
bcskew0 lac2_bc =lac2, level(90)
global bc_lambda = r(lambda)
su lac2 lac2_bc, d

/* 	Now define Low-Medium-High risk categories based on quartiles
	Alternatively you can define this by coming 'in' from the extremes of the 2nd value
	by some standardised amount of the trajectory
	i.e. if trajectory SD is 5, and the min, max of the 2nd value is 0 30
	then you would pick your mid-range as 5-25
	leaving room for those at the top to move up and those at the bottom to move down
*/

cap drop lac2_k
qui su lac2_bc, d
local min = r(min) - 1 // subtract 1 b/c egen cut does not use the boundary
local max = r(max) + 1 // ditto
egen lac2_k = cut(lac2_bc), at(`min' `=r(p25)'  `=r(p75)' `max' ) icodes
replace lac2_k = lac2_k + 1
label var lac2_k "Lactate - CMPD"
cap label drop lac2_k
label define lac2_k 1 "Low risk" 2 "Medium risk" 3 "High risk"
label values lac2_k lac2_k
tab lac2_k if m0

tabstat dead28 if m0, by(lac2_k) s(n mean sd ) format(%9.3g)
tabstat lac_traj if m0, by(lac2_k) s(n mean sd q) format(%9.3g)

/* 	Now define trajectory classes
	Use 0 as the centre and a symmetrical region around it
	Use the 0.5 standard deviations above and below it
*/

su lac_traj if m0, d
global boundary = r(sd)/2
cap drop lac_tclass
gen lac_tclass = 0 if lac_traj != .
label var lac_tclass "Lactate trajectory class"
cap label drop lac_tclass
label define lac_tclass 0 "Unclassified"

/* No Low risk deteriorating because that would imply -ve severity */
replace lac_tclass = 1 if lac2_k == 1 & lac_traj < -1 * $boundary
label define lac_tclass 1 "Low risk - improving", add
replace lac_tclass = 2 if lac2_k == 1 & lac_traj >= -1 * $boundary & lac_traj != .
label define lac_tclass 2 "Low risk - neutral", add

/* Medium risk - all possible */
replace lac_tclass = 4 if lac2_k == 2 & lac_traj < -1 * $boundary
label define lac_tclass 4 "Medium risk - improving", add
replace lac_tclass = 5 if lac2_k == 2 & lac_traj >= -1 * $boundary & lac_traj < $boundary
label define lac_tclass 5 "Medium risk - neutral", add
replace lac_tclass = 6 if lac2_k == 2 & lac_traj >= $boundary
label define lac_tclass 6 "Medium risk - deteriorating", add

/* No high risk improving because that would imply a crazy severity */
replace lac_tclass = 8 if lac2_k == 3 & lac_traj < $boundary
label define lac_tclass 8 "High risk - neutral", add
replace lac_tclass = 9 if lac2_k == 3 & lac_traj >= $boundary
label define lac_tclass 9 "High risk - deteriorating", add

replace lac_tclass = . if missing(lac_traj, lac2_k)
label values lac_tclass lac_tclass

tab lac_tclass if m0
tabstat lac_traj if m0, by(lac_tclass) s(n mean sd q) format(%9.3g)

cap drop lac_tvector
gen lac_tvector = .
label var lac_tvector "Pre-admission lactate trajectory"
replace lac_tvector = 1 if inlist(lac_tclass,1,4)
cap label drop lac_tvector
label define lac_tvector 1 "Improving"
replace lac_tvector = 2 if inlist(lac_tclass,2,5,8)
label define lac_tvector 2 "Neutral", add
replace lac_tvector = 3 if inlist(lac_tclass,6,9)
label define lac_tvector 3 "Deteriorating", add
label values lac_tvector lac_tvector

tab lac2_k lac_tvector if m0
table lac2_k lac_tvector if m0, contents(p25 lac_traj p75 lac_traj)

dotplot lac_traj, over(lac2_k)
dotplot lac_traj, over(lac_tvector)

*  ==============
*  = Grid model =
*  ==============
d *lac*

/* Complete cases estimate */

logistic dead28 ib1.lac2_k##ib1.lac_tvector if m0
/* Average marginal effects at the means */
margins lac2_k#lac_tvector if m0, atmeans grand post
est store margins_m0_grid
marginsplot, x(lac_tvector) legend(pos(3))

est restore margins_m0_grid
/* Now tidy up the plot */
local ggreen "49 163 84"
local rred "215 48 31"
marginsplot ///
	, ///
	x(lac_tvector) ///
	recastci(rspike) ///
	plotopts(msymbol(o)) ///
	plot1opts(mcolor("`ggreen'") lcolor("`ggreen'")) ///
	ci1opts(lcolor("`ggreen'")) ///
	plot3opts(mcolor("`rred'") lcolor("`rred'")) ///
	ci3opts(lcolor("`rred'")) ///
	xtitle("Pre-admission trajectory") ///
	xlabel(, labsize(small)) ///
	ylabel(0 "0" 0.2 "20" 0.4 "40" 0.6 "60" 0.8 "80", labsize(small)) ///
	ytitle("Adjusted 28 day mortality (%)" ) ///
	title("") ///
	legend( ///
		order(7 6 5) ///
		label(5 "Low severity") ///
		label(6 "Medium severity") ///
		label(7 "High severity") ///
		size(small) ///
		pos(10) ring(0)) ///
	xsize(6) ysize(6) ///
	plotregion(margin(large))

graph rename raw_lac_grid_m0, replace
graph export ../outputs/figures/raw_lac_grid_m0.pdf ///
    , name(raw_lac_grid_m0) replace

/* MI estimate */
cap drop esample
mi estimate, esampvaryok esample(esample): ///
	logistic dead28 ib1.lac2_k##ib1.lac_tvector
est store mi

**************************************************
/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
// via http://bit.ly/10CEKNU
est restore mi
est describe
global mi_est_cmdline `=r(cmdline)'
/* First specify the margins command HERE */
global margins_cmd "margins lac2_k#lac_tvector , atmeans grand "
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
marginsplot, x(lac_tvector) legend(pos(3))

/* Now tidy up the plot */
local ggreen "49 163 84"
local rred "215 48 31"
marginsplot ///
	, ///
	x(lac_tvector) ///
	recastci(rspike) ///
	plotopts(msymbol(o)) ///
	plot1opts(mcolor("`ggreen'") lcolor("`ggreen'")) ///
	ci1opts(lcolor("`ggreen'")) ///
	plot3opts(mcolor("`rred'") lcolor("`rred'")) ///
	ci3opts(lcolor("`rred'")) ///
	xtitle("Pre-admission trajectory") ///
	xlabel(, labsize(small)) ///
	ylabel(0 "0" 0.2 "20" 0.4 "40" 0.6 "60" 0.8 "80", labsize(small)) ///
	ytitle("Adjusted 28 day mortality (%)" ) ///
	title("") ///
	legend( ///
		order(7 6 5) ///
		label(5 "Low severity") ///
		label(6 "Medium severity") ///
		label(7 "High severity") ///
		size(small) ///
		pos(10) ring(0)) ///
	xsize(6) ysize(6) ///
	plotregion(margin(large))

graph rename raw_lac_grid_mi, replace
graph export ../outputs/figures/raw_lac_grid_mi.pdf ///
    , name(raw_lac_grid_mi) replace

graph combine raw_lac_grid_m0 raw_lac_grid_mi, ///
	rows(1) name(raw_lac_grid, replace) ///
	xsize(6) ysize(4)

************************************************************************

*  ==============================
*  = Continuous mid-range model =
*  ==============================

/* Complete cases */

/* Mid-range = CMPD Lactate 1--5 */
cap drop touse
gen touse = lac2_k == 2
spikeplot lac_traj if touse & m0

/* Inspect */
cap drop lac2_k2_q5
xtile lac2_k2_q5 = lac2 , nq(5)
tabstat lac2, by(lac2_k2_q5) s(n mean sd q) format(%9.3g)
dotplot lac_traj, over(lac2_k2_q5)

/* Lac 2 - check for interaction */
stcox lac2 lac_traj if touse & m0, nolog noshow
est store m1
stcox c.lac2##c.lac_traj if touse & m0, nolog noshow
est store m2
lincom c.lac2#c.lac_traj,
ret li
local p = 2 * (1 - normal(abs(r(estimate) / r(se))))
local p: di %9.3f `p'
di "Significance of interaction: `p'"
est stats m1 m2

est restore m1
est replay


local model_name = "cc lac"
global i = $i + 1

parmest, ///
	eform ///
	label list(parm label estimate min* max* p) ///
	idnum($i) idstr("`model_name'") ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max* %9.2f p %9.3f) ///
	saving(`estimates_file', replace)

cap restore, not
preserve

if $i == 1 {
	use `estimates_file', clear
	save ../outputs/tables/$table_name.dta, replace
}
else {
	use ../outputs/tables/$table_name.dta, clear
	append using `estimates_file'
	save ../outputs/tables/$table_name.dta, replace
}

restore

su lac_traj if m0, d
local range05_95 = r(p95) - r(p5)
if `range05_95' <= 20 {
	local nnumlist -10(1)10
}
else if `range05_95' <= 50 {
	local nnumlist -20(4)20
}
else if `range05_95' <= 100 {
	local nnumlist -50(5)50
}
else if `range05_95' <= 200 {
	local nnumlist -50(10)50
}
else if `range05_95' <= 500 {
	local nnumlist -250(25)250
}
else if `range05_95' <= 1000 {
	local nnumlist -500(50)500
}

global nnumlist `nnumlist'
di "Margin will be plotted over $nnumlist"

margins, at(lac_traj = ($nnumlist) ) vsquish post
est store marginsplot_lac

/* Extract the numbers so you can plot without depending on marginsplot */
matrix at = e(at)
matrix b = e(b)
matrix v = vecdiag(e(V))
matrix plot = at, b', v'
cap drop plot1-plot4
svmat plot
cap drop toplot
gen toplot = plot3 != .
cap drop at_* bhat vhat
rename plot1 at_lac2
rename plot2 at_lac_traj
rename plot3 bhat
rename plot4 vhat
cap drop bhat_min bhat_max
gen bhat_min = bhat - (1.96 * vhat^0.5)
gen bhat_max = bhat + (1.96 * vhat^0.5)

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
	xtitle("Change from pre-admission ICNARC score" ///
			"(1{superscript:st} 24 hour value - ward assessment value)", ///
			size(small)) ///
	text(0  7 "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
	text(0  0 "Neutral", placement(c) size(small)) ///
	text(0 -7 "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
	legend(off) ///
	name(marginsplot_lac, replace)

local ggreen "49 163 84"
local rred "215 48 31"
tw ///
	(rarea bhat_min bhat_max at_lac_traj, ///
		pstyle(ci)) ///
	(line bhat at_lac_traj, ///
		lcolor(black) lpattern(solid)) ///
	, ///
	ylabel(,labsize(small)) ///
	ytitle("Relative hazard") ///
	xlabel(-10(5)10, labsize(small)) ///
	xsize(6) ysize(6) ///
	title("") ///
	plotregion(margin(large)) ///
	xtitle("Change from pre-admission value", ///
			size(small)) ///
	text(0  7 "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
	text(0  0 "Neutral", placement(c) size(small)) ///
	text(0 -7 "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
	legend(off) ///
	name(bhatplot_lac, replace)

	/* NOW AFTER MI */

*  =================================
*  = Continuous plot using MI data =
*  =================================
cap drop esample
mi estimate, esampvaryok esample(esample): ///
	stcox lac2 lac_traj if touse
est store mi1

cap drop esample
mi estimate, esampvaryok esample(esample): ///
	stcox c.lac2##c.lac_traj if touse
est store mi2
est replay, eform

/* Lac 2 - check for interaction */
mi test c.lac2#c.lac_traj
ret li
local p: di %9.3f `=r(p)'
di "Significance of interaction: `p'"

est restore mi1
est replay

tempfile estimates_file working

local model_name = "mi lac"
global i = $i + 1

parmest, ///
	eform ///
	label list(parm label estimate min* max* p) ///
	idnum($i) idstr("`model_name'") ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max* %9.2f p %9.3f) ///
	saving(`estimates_file', replace)

cap restore, not
preserve

if $i == 1 {
	use `estimates_file', clear
	save ../outputs/tables/$table_name.dta, replace
}
else {
	use ../outputs/tables/$table_name.dta, clear
	append using `estimates_file'
	save ../outputs/tables/$table_name.dta, replace
}

restore

/* Use the same numlist as for the m0 sample */
di "Margin will be plotted over $nnumlist"

**************************************************
/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
// via http://bit.ly/10CEKNU
est describe
global mi_est_cmdline `=r(cmdline)'
/* First specify the margins command HERE */
global margins_cmd "margins, at(lac_traj = ($nnumlist) ) vsquish"
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
est store margins_mi_plot_lac

/* Extract the numbers so you can plot without depending on marginsplot */

matrix at = e(at)
matrix b = e(b_mi)
matrix v = vecdiag(e(V_mi))
matrix mi_plot = at, b', v'
matrix list mi_plot

cap drop mi_plot1-mi_plot4
svmat mi_plot
cap drop tomi_plot
gen tomi_plot = mi_plot3 != .
cap drop mi_at_* mi_bhat mi_vhat
rename mi_plot1 mi_at_lac2
rename mi_plot2 mi_at_lac_traj
rename mi_plot3 mi_bhat
rename mi_plot4 mi_vhat
cap drop mi_bhat_min mi_bhat_max
gen mi_bhat_min = mi_bhat - (1.96 * mi_vhat^0.5)
gen mi_bhat_max = mi_bhat + (1.96 * mi_vhat^0.5)

local ggreen "49 163 84"
local rred "215 48 31"
tw ///
	(rarea mi_bhat_min mi_bhat_max mi_at_lac_traj, ///
		pstyle(ci)) ///
	(line mi_bhat mi_at_lac_traj, ///
		lcolor(black) lpattern(solid)) ///
	, ///
	ylabel(,labsize(small)) ///
	ytitle("Relative hazard") ///
	xlabel(-10(5)10, labsize(small)) ///
	xsize(6) ysize(6) ///
	title("") ///
	plotregion(margin(large)) ///
	xtitle("Change from pre-admission value", ///
			size(small)) ///
	text(0  7 "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
	text(0  0 "Neutral", placement(c) size(small)) ///
	text(0 -7 "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
	legend(off) ///
	name(mi_bhatplot_lac, replace)

graph combine bhatplot_lac mi_bhatplot_lac, ///
	rows(1) ycommon xcommon xsize(6) ysize(4) ///
	name(raw_lac_monly, replace)

graph export ../outputs/figures/raw_lac_monly.pdf ///
    , name(raw_lac_monly) replace

graph combine raw_lac_grid raw_lac_monly, ///
	rows(2) xsize(6) ysize(6) ///
	name(lac_traj_all, replace)



cap log close