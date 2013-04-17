*  ================================================
*  = Adapted to produce all plots looking forward =
*  ================================================

/*
Trajectory as added value from known ward measurement
*/

*  ==========================================================================
*  = Effect of trajectory - but examined only within the mid-range severity =
*  ==========================================================================
/*
created:	130408
modified:	130416

Examine trajectory in a region where constraints should not matter
Specifically avoided vars that have a non-linear relationship with mortality
Focus on
- CVS: Lactate (as marker of severity, metabolic and CVS stress)
- AKI: Creatinine
- Resp: PF
- Platelets: Haem (in SOFA, and unmodifiable)

Define a population in which none of these are missing
*/

GenericSetupSteveHarris spot_traj an_model_raw_fwd, logon
*  ===================
*  = CLEAN RUN STUFF =
*  ===================
local clean_run 0
if `clean_run' {
	use ../data/working.dta, clear
	include cr_preflight.do
	include cr_preflight_mi.do
}

*  ============================
*  = Bring in the MI data set =
*  ============================
local physiology working_postflight_mi_plus_surv
use ../data/`physiology'.dta, clear
merge m:1 id using ../data/working_postflight ///
	, keepusing(date_trace daicu dead dead28) nolabel
drop if _merge != 3
drop _merge

global table_name model_fwd_monly
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


mi misstable patterns lac_traj cr_traj plat_traj pf_traj, freq
cap drop touse
* NOTE: 2013-04-16 - changed to focus on ICNARC APS
gen touse = !missing(ims_c_traj)
* gen touse = !missing(lac_traj, cr_traj, plat_traj, pf_traj)
label var touse "Comparison population"

/* Trick to make sure platelets move in the same direction as everything else
	i.e. high is worse */

su plat1 plat2
replace plat2 = 1500 - plat2
replace plat1 = 1500 - plat1
replace plat_traj = -1 * plat_traj

* local physiology_vars lac cr plat pf

local physiology_vars ims_c


foreach pvar of local physiology_vars {
	if "`pvar'" == "lac" local var_label Lactate
	if "`pvar'" == "cr" local var_label Creatinine
	if "`pvar'" == "plat" local var_label Platelets
	if "`pvar'" == "pf" local var_label P:F ratio
	if "`pvar'" == "ims_c" local var_label ICNARC APS

	// =====================================================
	// = Define the grid for the physiology being examined =
	// =====================================================

	spikeplot `pvar'2 if m0, name(p2, replace) nodraw
	spikeplot `pvar'1 if m0, name(p1, replace) nodraw
	spikeplot `pvar'_traj if m0, name(pt, replace) nodraw
	graph combine p1 p2 pt, col(1)

	su `pvar'1 `pvar'2 `pvar'_traj if touse, d

	/* Transform? */
	cap drop `pvar'1_bc
	bcskew0 `pvar'1_bc =`pvar'1 if touse, level(90)
	global bc_lambda = r(lambda)
	su `pvar'1 `pvar'1_bc if touse, d

	/* 	Now define Low-Medium-High risk categories based on quartiles
		Alternatively you can define this by coming 'in' from the extremes of the 2nd value
		by some standardised amount of the trajectory
		i.e. if trajectory SD is 5, and the min, max of the 2nd value is 0 30
		then you would pick your mid-range as 5-25
		leaving room for those at the top to move up and those at the bottom to move down
	*/

	cap drop `pvar'1_k
	qui su `pvar'1_bc if touse, d
	local min = r(min) - 1 // subtract 1 b/c egen cut does not use the boundary
	local max = r(max) + 1 // ditto
	egen `pvar'1_k = cut(`pvar'1_bc), at(`min' `=r(p25)'  `=r(p75)' `max' ) icodes
	replace `pvar'1_k = `pvar'1_k + 1
	label var `pvar'1_k "`var_label' - CMPD"
	cap label drop `pvar'1_k
	label define `pvar'1_k 1 "Low risk" 2 "Medium risk" 3 "High risk"
	label values `pvar'1_k `pvar'1_k
	tab `pvar'1_k if m0 & touse

	tabstat dead28 if m0 & touse, by(`pvar'1_k) s(n mean sd ) format(%9.3g)
	tabstat `pvar'_traj if m0 & touse, by(`pvar'1_k) s(n mean sd q) format(%9.3g)

	/* 	Now define trajectory classes
		Use 0 as the centre and a symmetrical region around it
		Use the 0.5 standard deviations above and below it
	*/

	su `pvar'_traj if m0 & touse, d
	global boundary = r(sd)/2
	cap drop `pvar'_tclass
	gen `pvar'_tclass = 0 if `pvar'_traj != .
	label var `pvar'_tclass "`var_label' trajectory class"
	cap label drop `pvar'_tclass
	label define `pvar'_tclass 0 "Unclassified"

	/* No Low risk deteriorating because that would imply -ve severity */
	* replace `pvar'_tclass = 1 if `pvar'1_k == 1 & `pvar'_traj < -1 * $boundary
	* label define `pvar'_tclass 1 "Low risk - improving", add
	replace `pvar'_tclass = 2 if `pvar'1_k == 1 & `pvar'_traj < 1 * $boundary & `pvar'_traj != .
	label define `pvar'_tclass 2 "Low risk - neutral", add
	replace `pvar'_tclass = 3 if `pvar'1_k == 1 & `pvar'_traj >= 1 * $boundary & `pvar'_traj != .
	label define `pvar'_tclass 3 "Low risk - deteriorating", add

	/* Medium risk - all possible */
	replace `pvar'_tclass = 4 if `pvar'1_k == 2 & `pvar'_traj < -1 * $boundary
	label define `pvar'_tclass 4 "Medium risk - improving", add
	replace `pvar'_tclass = 5 if `pvar'1_k == 2 & `pvar'_traj >= -1 * $boundary & `pvar'_traj < $boundary
	label define `pvar'_tclass 5 "Medium risk - neutral", add
	replace `pvar'_tclass = 6 if `pvar'1_k == 2 & `pvar'_traj >= $boundary
	label define `pvar'_tclass 6 "Medium risk - deteriorating", add

	/* No high risk improving because that would imply a crazy severity */
	replace `pvar'_tclass = 7 if `pvar'1_k == 3 & `pvar'_traj < -1 * $boundary
	label define `pvar'_tclass 7 "High risk - improving", add
	replace `pvar'_tclass = 8 if `pvar'1_k == 3 & `pvar'_traj >= -1 * $boundary & `pvar'_traj != .
	label define `pvar'_tclass 8 "High risk - neutral", add
	* replace `pvar'_tclass = 9 if `pvar'1_k == 3 & `pvar'_traj >= $boundary
	* label define `pvar'_tclass 9 "High risk - deteriorating", add

	replace `pvar'_tclass = . if missing(`pvar'_traj, `pvar'1_k)
	label values `pvar'_tclass `pvar'_tclass

	tab `pvar'_tclass if m0 & touse
	tabstat `pvar'_traj if m0 & touse, by(`pvar'_tclass) s(n mean sd q) format(%9.3g)

	cap drop `pvar'_tvector
	gen `pvar'_tvector = .
	label var `pvar'_tvector "Pre-admission `var_label' trajectory"
	replace `pvar'_tvector = 1 if inlist(`pvar'_tclass,1,4,7)
	cap label drop `pvar'_tvector
	label define `pvar'_tvector 1 "Improving"
	replace `pvar'_tvector = 2 if inlist(`pvar'_tclass,2,5,8)
	label define `pvar'_tvector 2 "Neutral", add
	replace `pvar'_tvector = 3 if inlist(`pvar'_tclass,3,6,9)
	label define `pvar'_tvector 3 "Deteriorating", add
	label values `pvar'_tvector `pvar'_tvector

	tab `pvar'1_k `pvar'_tvector if m0 & touse
	table `pvar'1_k `pvar'_tvector if m0 & touse, contents(p25 `pvar'_traj p75 `pvar'_traj)

	dotplot `pvar'_traj if m0 & touse, over(`pvar'1_k)
	dotplot `pvar'_traj if m0 & touse, over(`pvar'_tvector)

	//  ==============
	//  = Grid model =
	//  ==============
	d *`pvar'*

	/* Complete cases estimate */

	logistic dead28 ib1.`pvar'1_k##ib1.`pvar'_tvector if m0 & touse
	/* Average marginal effects at the means */
	margins `pvar'1_k#`pvar'_tvector if m0 & touse, atmeans grand post
	est store margins_m0_grid
	marginsplot, x(`pvar'_tvector) legend(pos(3))

	est restore margins_m0_grid
	/* Now tidy up the plot */
	local ggreen "49 163 84"
	local rred "215 48 31"
	marginsplot ///
		, ///
		x(`pvar'_tvector) ///
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

	graph rename fwd_`pvar'_grid_m0, replace
	graph export ../outputs/figures/fwd_`pvar'_grid_m0.pdf ///
	    , name(fwd_`pvar'_grid_m0) replace

	/* MI estimate */
	cap drop esample
	mi estimate, esampvaryok esample(esample): ///
		logistic dead28 ib1.`pvar'1_k##ib1.`pvar'_tvector
	est store mi

	// *************************************************
	/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
	// via http://bit.ly/10CEKNU
	est restore mi
	est describe
	global mi_est_cmdline `=r(cmdline)'
	/* First specify the margins command HERE */
	global margins_cmd "margins `pvar'1_k#`pvar'_tvector , atmeans grand "


	mi estimate, cmdok esampvaryok: emargins 1
	mat b = e(b_mi)
	mat V = e(V_mi)
	if strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline & m0
	if !strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline if m0
	qui $margins_cmd
	myret
	mata: st_global("e(cmd)", "margins")
	marginsplot, x(`pvar'_tvector) legend(pos(3))

	/* Now tidy up the plot */
	local ggreen "49 163 84"
	local rred "215 48 31"
	marginsplot ///
		, ///
		x(`pvar'_tvector) ///
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

	graph rename fwd_`pvar'_grid_mi, replace
	graph export ../outputs/figures/fwd_`pvar'_grid_mi.pdf ///
	    , name(fwd_`pvar'_grid_mi) replace

	graph combine fwd_`pvar'_grid_m0 fwd_`pvar'_grid_mi, ///
		rows(1) name(fwd_`pvar'_grid, replace) ///
		xsize(6) ysize(4)

	//***********************************************************************

	//  ==============================
	//  = Continuous mid-range model =
	//  ==============================

	/* Complete cases */

	/* 	Mid-range / risk
		redefine touse here should also bring back in *all* medium risk patients */
	cap drop touse
	gen touse = `pvar'1_k == 2
	spikeplot `pvar'_traj if touse & m0

	/* Inspect */
	cap drop `pvar'1_k2_q5
	xtile `pvar'1_k2_q5 = `pvar'1 , nq(5)
	tabstat `pvar'1, by(`pvar'1_k2_q5) s(n mean sd q) format(%9.3g)
	dotplot `pvar'_traj, over(`pvar'1_k2_q5)

	/* Centre your variable */
	cap drop `pvar'1_original
	clonevar `pvar'1_original = `pvar'1
	su `pvar'1, meanonly
	replace `pvar'1 = `pvar'1 - r(mean)

	/* `pvar' 2 - check for interaction */
	stcox `pvar'1 `pvar'_traj if touse & m0, nolog noshow
	est store m1
	stcox c.`pvar'1##c.`pvar'_traj if touse & m0, nolog noshow
	est store m2
	lincom c.`pvar'1#c.`pvar'_traj,
	ret li
	local p = 2 * (1 - normal(abs(r(estimate) / r(se))))
	local p: di %9.3f `p'
	di "Significance of interaction: `p'"
	est stats m1 m2

	est restore m1
	est replay


	local model_name = "cc `pvar'"
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

	su `pvar'_traj if m0, d
	local range05_95 = r(p95) - r(p5)
	if `range05_95' <= 20 {
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
	rename plot1 at_`pvar'1
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
	local ylabels 0 1 5 10 15
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

		/* NOW AFTER MI */

	*  =================================
	*  = Continuous plot using MI data =
	*  =================================
	cap drop esample
	mi estimate, esampvaryok esample(esample): ///
		stcox `pvar'1 `pvar'_traj if touse
	est store mi1

	cap drop esample
	mi estimate, esampvaryok esample(esample): ///
		stcox c.`pvar'1##c.`pvar'_traj if touse
	est store mi2
	est replay, eform

	/* `pvar' 2 - check for interaction */
	mi test c.`pvar'1#c.`pvar'_traj
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
	rename mi_plot1 mi_at_`pvar'1
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
		name(fwd_`pvar'_monly, replace)

	graph export ../outputs/figures/fwd_`pvar'_monly.pdf ///
	    , name(fwd_`pvar'_monly) replace

	graph combine fwd_`pvar'_grid fwd_`pvar'_monly, ///
		rows(2) xsize(6) ysize(6) ///
		name(`pvar'_traj_all, replace)


}

use ../outputs/tables/$table_name.dta, clear

* cap log close
