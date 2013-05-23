*  ===========================================
*  = Inspect trajectories for all physiology =
*  ===========================================

/*
Created	130521

TODO: 2013-05-21 - 
- repeat for each piece of physiology
	- hr bps rr temp urin pf lac wcc plat na cr urea 
- repeat for different time bands 
	- is there a relationship between trajectory and time of measurements
		that will result in confounding
		plot traj versus time
- then do using heat maps for mortality
*/


use ../data/working_postflight.dta, clear
count
su time2icu, d
keep if time2icu < 24
cap drop __*
su ims_c2 ims_c1


* TODO: 2013-05-21 - add back in pH by working with H+ conc?
local pvars hr bps rr temp urin pf lac wcc plat na cr urea 
foreach pvar of local pvars {
	// drop extremes for the purposes of producing a tidy graph
	centile `pvar'2, centile(99.5)
	local c9995 = round(r(c_1))
	centile `pvar'2, centile(0.05)
	local c0005 = round(r(c_1))
	drop if `pvar'2 > `c9995'
	drop if `pvar'2 < `c0005'
	// make a number list for the cut points
	local sstep = round((`c9995' - `c0005') / 10)
	egen `pvar'2_k10 = cut(`pvar'2), at(`c0005'(`sstep')`c9995') label
	tab `pvar'2_k10, miss

	centile `pvar'_traj, centile(1 99)
	local traj_limit = max(r(c_1),r(c_2))
	local xtitle: variable label `pvar'2
	local ytitle: variable label `pvar'_traj
	dotplot `pvar'_traj if abs(`pvar'_traj) < `traj_limit'   ///
		, ///
		over(`pvar'2_k10) nogroup center  ///
		msize(tiny) msymbol(o) ///
		ytitle("`ytitle'", ) ///
		ylabel(,  nogrid) ///
		xtitle("`xtitle'", margin(medium)) ///
		xlabel(, labsize(vsmall)) ///
		xscale(noextend) ///
		yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) ) ///
		name(delta_vs_cmp_`pvar', replace) nodraw
		local plots `plots' delta_vs_cmp_`pvar'
}
graph combine `plots' , ///
	cols(3) xsize(6) ysize(8) ///
	name(delta_vs_cmp_grid, replace)


if c(os) == "Unix" local ext eps
if c(os) != "Unix" local ext pdf
graph display delta_vs_cmp_grid
graph export ../outputs/figures/delta_vs_cmp_grid.`ext' ///
    , name(delta_vs_cmp_grid) replace

