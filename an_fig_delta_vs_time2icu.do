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
drop if time2icu > 168
egen time2icu_k = cut(time2icu), at(0 1 2 4 8 16 32 64 128 168) label
tab time2icu_k
cap drop __*


* TODO: 2013-05-21 - add back in pH by working with H+ conc?
local pvars hr bps rr temp urin pf lac wcc plat na cr urea 
foreach pvar of local pvars {
	centile `pvar'_traj, centile(1 99)
	local traj_limit = max(r(c_1),r(c_2))
	local xtitle: variable label `pvar'2
	local ytitle: variable label `pvar'_traj
	dotplot `pvar'_traj if abs(`pvar'_traj) < `traj_limit'   ///
		, ///
		over(time2icu_k) nogroup center  ///
		msize(tiny) msymbol(o) ///
		ytitle("`ytitle'", ) ///
		ylabel(,  nogrid) ///
		xtitle("Delay to ICU admission (hrs)", margin(medium)) ///
		xlabel(, labsize(vsmall)) ///
		xscale(noextend) ///
		yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) ) ///
		name(delta_vs_cmp_`pvar', replace) nodraw
		local plots `plots' delta_vs_cmp_`pvar'
}
graph combine `plots' , ///
	cols(3) xsize(6) ysize(8) ///
	name(delta_vs_time2icu_grid, replace)


if c(os) == "Unix" local ext eps
if c(os) != "Unix" local ext pdf
graph display delta_vs_time2icu_grid
graph export ../outputs/figures/delta_vs_time2icu_grid.`ext' ///
    , name(delta_vs_time2icu_grid) replace

