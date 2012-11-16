*  ==============================================================
*  = Use this to keep a record of all programs used in analysis =
*  ==============================================================

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
	local iif if `stem'1 > `mmin' & `stem'1 < `mmax' ///
		& `stem'2 > `mmin' & `stem'2 < `mmax'

	hist `stem'1 `iif', s(`mmin') w(`wwidth') name(`stem'_spot, replace)
	hist `stem'2 `iif', s(`mmin') w(`wwidth') name(`stem'_cmpd, replace)
	graph combine `stem'_spot `stem'_cmpd, row(1) xcommon ycommon name(`stem'1_`stem'2_hist, replace)
	noi di "graph export ../logs/`stem'1_`stem'2_hist.pdf, replace"
	graph export ../logs/`stem'1_`stem'2_hist.pdf, replace

	cap drop traj_`stem'
	/* CHANGED: 2012-11-14 - trajectory per day instead of per hour */
	gen traj_`stem' = `stem'2 - `stem'1 / (round(time2icu, 24) +1)
	label var traj_`stem' "`stem' slope"
	tabstat traj_`stem', stat(n mean sd skew kurt min max) col(st)
	hist traj_`stem' `iif' , s(`mmin') w(`wwidth') freq ///
		name(traj_`stem'_hist, replace)
	noi di "graph export ../logs/traj_`stem'_hist.pdf, replace"
	graph export ../logs/traj_`stem'_hist.pdf, replace

	running dead28 traj_`stem' `iif' , logit name(d28_`stem'_traj_running, replace)
	/* Inspect wrt to current value */
	cap drop `stem'_bc
	/* NOTE: 2012-11-13 - bcskew0 does not handle negative numbers (i.e traj) */
	/* bcskew0 `stem'_bc = `stem'2, level(90) */
	running dead28 `stem'2 `iif' , ///
		title("`stem': Current value") ///
		logit name(d28_`stem'_running, replace)
	/* Inspect wrt to trajectory */
	cap drop traj_`stem'_bc
	/* bcskew0 traj_`stem'_bc = traj_`stem', level(90) */
	running dead28 traj_`stem' `iif' , ///
		title("`stem': Trajectory") ///
		logit name(d28_`stem'_traj_running, replace)
	graph combine d28_`stem'_running d28_`stem'_traj_running, ///
		xcommon ycommon row(1) name(d28_`stem'_curr_traj, replace)
	noi di "graph export ../logs/d28_`stem'_curr_traj.pdf, replace"
	graph export ../logs/d28_`stem'_curr_traj.pdf, replace

end
