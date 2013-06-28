
* GenericSetupSteveHarris spot_traj an_model_raw_bkwd, logon

*  ============================
*  = Bring in the MI data set =
*  ============================
* local physiology working_postflight_mi_plus_surv
* use ../data/`physiology'.dta, clear
* merge m:1 id using ../data/working_postflight ///
* 	, keepusing(date_trace daicu dead dead28) nolabel
* drop if _merge != 3
* drop _merge
use ../data/working_postflight.dta, clear

global table_name model_bkwd_monly
tempfile estimates_file working
global i = 0

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


* mi misstable patterns lac_traj cr_traj plat_traj pf_traj, freq
* cap drop touse
* * NOTE: 2013-04-16 - changed to focus on ICNARC APS
* gen touse = !missing(ims_c_traj)
* * gen touse = !missing(lac_traj, cr_traj, plat_traj, pf_traj)
gen touse = 1
label var touse "Comparison population"
gen m0 = 1

/* Trick to make sure platelets move in the same direction as everything else
	i.e. high is worse */

* su plat1 plat2
* replace plat2 = 1500 - plat2
* replace plat1 = 1500 - plat1
* replace plat_traj = -1 * plat_traj

* local physiology_vars lac cr plat pf

local physiology_vars ims_c
local pvar ph

* foreach pvar of local physiology_vars {
if "`pvar'" == "lac" local var_label Lactate
if "`pvar'" == "cr" local var_label Creatinine
if "`pvar'" == "plat" local var_label Platelets
if "`pvar'" == "pf" local var_label P:F ratio
if "`pvar'" == "ims_c" local var_label ICNARC APS

// =====================================================
// = Define the grid for the physiology being examined =
// =====================================================

* spikeplot `pvar'2 if m0, name(p2, replace) nodraw
* spikeplot `pvar'1 if m0, name(p1, replace) nodraw
* spikeplot `pvar'_traj if m0, name(pt, replace) nodraw
* graph combine p1 p2 pt, col(1)

su `pvar'1 `pvar'2 `pvar'_traj if touse, d


//***********************************************************************

//  ==============================
//  = Continuous mid-range model =
//  ==============================

/* Complete cases */

/* 	Mid-range / risk
	redefine touse here should also bring back in *all* medium risk patients */

/* Inspect */
cap drop `pvar'2_k2_q5
xtile `pvar'2_k2_q5 = `pvar'2 , nq(5)
tabstat `pvar'2, by(`pvar'2_k2_q5) s(n mean sd q) format(%9.3g)
dotplot `pvar'_traj, over(`pvar'2_k2_q5)

/* Centre your variable */
cap drop `pvar'2_original
clonevar `pvar'2_original = `pvar'2
su `pvar'2, meanonly
replace `pvar'2 = `pvar'2 - r(mean)

/* `pvar' 2 - check for interaction */
stcox `pvar'2 `pvar'_traj if touse & m0, nolog noshow
est store m1
stcox c.`pvar'2##c.`pvar'_traj if touse & m0, nolog noshow
est store m2
lincom c.`pvar'2#c.`pvar'_traj,
ret li
local p = 2 * (1 - normal(abs(r(estimate) / r(se))))
local p: di %9.3f `p'
di "Significance of interaction: `p'"

stcox c.`pvar'2##c.`pvar'_traj##c.`pvar'_traj if touse & m0, nolog noshow
* stcox c.`pvar'2##c.`pvar'_traj##c.`pvar'_traj##c.`pvar'_traj if touse & m0, nolog noshow
est store m3
est stats m1 m2 m3

est restore m3
est replay


* local model_name = "cc `pvar'"
* global i = $i + 1

* parmest, ///
* 	eform ///
* 	label list(parm label estimate min* max* p) ///
* 	idnum($i) idstr("`model_name'") ///
* 	stars(0.05 0.01 0.001) ///
* 	format(estimate min* max*  p ) ///
* 	saving(`estimates_file', replace)

* cap restore, not
* preserve

* if $i == 1 {
* 	use `estimates_file', clear
* 	save ../outputs/tables/$table_name.dta, replace
* }
* else {
* 	use ../outputs/tables/$table_name.dta, clear
* 	append using `estimates_file'
* 	save ../outputs/tables/$table_name.dta, replace
* }

* restore

su `pvar'_traj if m0, d
local range05_95 = r(p95) - r(p5)
if `range05_95' <= 2 {
	local nnumlist -1(1)1
	local lab_numlist -1 0 1
	local ooffset 0.5
}
else if `range05_95' <= 20 {
	local nnumlist -10(1)10
	local lab_numlist -10 0 10
	local ooffset 5
}
else if `range05_95' <= 50 {
	local nnumlist -20(4)20
	local lab_numlist -20 0 20
	local ooffset 10
}
else if `range05_95' <= 100 {
	local nnumlist -50(5)50
	local lab_numlist -50 0 50
	local ooffset 25
}
else if `range05_95' <= 200 {
	local nnumlist -100(10)100
	local lab_numlist -100 0 100
	local ooffset 50
}
else if `range05_95' <= 500 {
	local nnumlist -250(25)250
	local lab_numlist -250 0 250
	local ooffset 125
}
else if `range05_95' <= 1000 {
	local nnumlist -500(50)500
	local lab_numlist -500 0 500
	local ooffset 250
}

global nnumlist `nnumlist'
global lab_numlist `lab_numlist'
di "Margin will be plotted over $nnumlist"

margins, at(`pvar'_traj = ($nnumlist) ) vsquish post
est store marginsplot_`pvar'

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
rename plot1 at_`pvar'2
rename plot2 at_`pvar'_traj
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
	xlabel($lab_numlist, labsize(small)) ///
	ylabel(,labsize(small)) ///
	title("") ///
	xsize(6) ysize(6) ///
	plotregion(margin(large)) ///
	xtitle("Change from pre-admission ICNARC score" ///
			"(1{superscript:st} 24 hour value - ward assessment value)", ///
			size(small)) ///
	text(0 -`ooffset' "Worsening" "severity", placement(c) size(small) color("`rred'")) ///
	text(0  0 "Neutral", placement(c) size(small)) ///
	text(0 `ooffset' "Improving" "severity", placement(c) size(small) color("`ggreen'")) ///
	legend(off) ///
	name(marginsplot_`pvar', replace)


local ggreen "49 163 84"
local rred "215 48 31"
local ylabels 0 1 5 
replace bhat_min = 0 if bhat_min < 0
replace bhat = . if bhat < 0
replace bhat_max = 5 if bhat_max > 5 & !missing(bhat_max)
replace bhat = . if bhat > 5 & !missing(bhat)
local yline yline(1, lcolor(gs4) lwidth(thin) lpattern(solid) noextend)
tw ///
	(rarea bhat_min bhat_max at_`pvar'_traj, ///
		pstyle(ci)) ///
	(line bhat at_`pvar'_traj, ///
		lcolor(black) lpattern(solid)) ///
	, ///
	ylabel(`ylabels',labsize(small)) ///
	ytitle("Relative hazard") ///
	xlabel($lab_numlist, labsize(vsmall) ) ///
	xlabel(`ooffset' "Worsening", add custom labcolor("`rred'") labsize(small) noticks labgap(medium)) ///
	xlabel(-`ooffset' "Improving", add custom labcolor("`ggreen'") labsize(small) noticks labgap(medium)) ///
	xsize(6) ysize(6) ///
	title("") ///
	plotregion(margin(large)) ///
	xtitle("Change from pre-admission value", ///
			size(medsmall)) ///
	legend(off) ///
	`yline' ///
	name(bhatplot_`pvar', replace)

exit
	/* NOW AFTER MI */

*  =================================
*  = Continuous plot using MI data =
*  =================================
cap drop esample
mi estimate, esampvaryok esample(esample): ///
	stcox `pvar'2 `pvar'_traj if touse
est store mi1

cap drop esample
mi estimate, esampvaryok esample(esample): ///
	stcox c.`pvar'2##c.`pvar'_traj if touse
est store mi2
est replay, eform

/* `pvar' 2 - check for interaction */
mi test c.`pvar'2#c.`pvar'_traj
ret li
local p: di %9.3f `=r(p)'
di "Significance of interaction: `p'"

est restore mi1
est replay

tempfile estimates_file working

local model_name = "mi `pvar'"
global i = $i + 1

parmest, ///
	eform ///
	label list(parm label estimate min* max* p) ///
	idnum($i) idstr("`model_name'") ///
	stars(0.05 0.01 0.001) ///
	format(estimate min* max*  p ) ///
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
global margins_cmd "margins, at(`pvar'_traj = ($nnumlist) ) vsquish"


mi estimate, cmdok esampvaryok: emargins 1
mat b = e(b_mi)
mat V = e(V_mi)
est store margins_mi_plot_`pvar'

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
rename mi_plot1 mi_at_`pvar'2
rename mi_plot2 mi_at_`pvar'_traj
rename mi_plot3 mi_bhat
rename mi_plot4 mi_vhat
cap drop mi_bhat_min mi_bhat_max
gen mi_bhat_min = mi_bhat - (1.96 * mi_vhat^0.5)
gen mi_bhat_max = mi_bhat + (1.96 * mi_vhat^0.5)

local ggreen "49 163 84"
local rred "215 48 31"
tw ///
	(rarea mi_bhat_min mi_bhat_max mi_at_`pvar'_traj, ///
		pstyle(ci)) ///
	(line mi_bhat mi_at_`pvar'_traj, ///
		lcolor(black) lpattern(solid)) ///
	, ///
	ylabel(`ylabels',labsize(small)) ///
	ytitle("Relative hazard") ///
	xlabel($lab_numlist, labsize(vsmall) ) ///
	xlabel(`ooffset' "Worsening", add custom labcolor("`rred'") labsize(small) noticks labgap(medium)) ///
	xlabel(-`ooffset' "Improving", add custom labcolor("`ggreen'") labsize(small) noticks labgap(medium)) ///
	xsize(6) ysize(6) ///
	title("") ///
	plotregion(margin(large)) ///
	xtitle("Change from pre-admission value", ///
			size(medsmall)) ///
	legend(off) ///
	`yline' ///
	name(mi_bhatplot_`pvar', replace)

graph combine bhatplot_`pvar' mi_bhatplot_`pvar', ///
	rows(1) ycommon xcommon xsize(6) ysize(4) ///
	name(bkwd_`pvar'_monly, replace)

graph export ../outputs/figures/bkwd_`pvar'_monly.pdf ///
    , name(bkwd_`pvar'_monly) replace

graph combine bkwd_`pvar'_grid bkwd_`pvar'_monly, ///
	rows(2) xsize(6) ysize(6) ///
	name(`pvar'_traj_all, replace)



* use ../outputs/tables/$table_name.dta, clear

cap log close
