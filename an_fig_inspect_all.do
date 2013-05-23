// Heatmaps
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
set scheme shcol
count
su time2icu, d
keep if time2icu < 24
cap drop __*

local pvars hr bps rr temp urin pf lac wcc plat na cr urea ph ims_c ims_ms ims_c
* local pvars cr
foreach pvar of local pvars {
	count if !missing(`pvar'_traj)	
	local var_n = r(N)
	local var_n: display %9.0fc `var_n'
	local var_n = trim("`var_n'")

	// Specific modifications to improve plots for certain vars
	tempvar p t
	if "`pvar'" == "plat" {
		gen `p' = abs(`pvar'_traj)
		drop if `p' > 250
	}
	if "`pvar'" == "pf" {
		gen `p' = abs(`pvar'_traj)
		drop if `p' > 50
	}
	if "`pvar'" == "lac" {
		gen `p' = abs(`pvar'2)
		gen `t' = abs(`pvar'_traj)
		drop if `p' > 10 & !missing(`p')
		* drop if `t' > 5 & !missing(`t')
	}
	if "`pvar'" == "urea" {
		gen `p' = abs(`pvar'2)
		gen `t' = abs(`pvar'_traj)
		drop if `p' > 50 & !missing(`p')
		drop if `t' > 10 & !missing(`t')
	}
	if "`pvar'" == "cr" {
		gen `p' = abs(`pvar'2)
		gen `t' = abs(`pvar'_traj)
		drop if `p' > 600 & !missing(`p')
		drop if `t' > 250 & !missing(`t')
	}


	preserve
	// make sure you are not rounding things like pH to an integer
	local round 1
	su `pvar'2
	if r(max) - r(min) < 2 local round 0.1

	// drop extreme 1% of values so scale sensible
	centile `pvar'2, centile(99)
	local cmax = round(r(c_1), `round')
	centile `pvar'2, centile(1)
	local cmin = round(r(c_1), `round')
	drop if `pvar'2 > `cmax'
	drop if `pvar'2 < `cmin'

	// drop extreme 1% of trajectories so scale sensible
	centile `pvar'_traj, centile(99)
	local cmax = round(r(c_1), `round')
	centile `pvar'_traj, centile(1)
	local cmin = round(r(c_1), `round')
	drop if `pvar'_traj > `cmax'
	drop if `pvar'_traj < `cmin'

	// check to see if you are working with an integer score
	if inlist("`pvar'","ims_ms") {
		cap drop `pvar'2_k
		gen `pvar'2_k = `pvar'2
		local `pvar'2step = 1
		
		cap drop `pvar'_traj_k
		gen `pvar'_traj_k = round(`pvar'_traj)
		local `pvar'_trajstep = 1
	}
	else {
		local grid 25
		cap drop `pvar'2_k
		qui su `pvar'2
		local `pvar'2step = (r(max)) / `grid'
		gen `pvar'2_k = floor(`pvar'2/``pvar'2step')
		* tab `pvar'2_k

		cap drop `pvar'_traj_k
		qui su `pvar'_traj
		local `pvar'_trajstep = (r(max)) / `grid'
		gen `pvar'_traj_k = floor(`pvar'_traj/``pvar'_trajstep')
		* tab `pvar'_traj_k
	}

	local xtitle: variable label `pvar'2
	local ytitle: variable label `pvar'_traj
	*Now produce your collapsed population
	rename adno n
	collapse (count) n (mean) dead28 , by(`pvar'2_k `pvar'_traj_k)

	gen `pvar'_traj = `pvar'_traj_k * ``pvar'_trajstep'
	gen `pvar'2 = `pvar'2_k * ``pvar'2step'


	replace dead28 = dead28 * 100 
	// NOTE: 2013-05-23 - drop this: and hope that neighbours will support where mortality is seen
	* replace dead28 = . if n <= 2

	// try and make the axes symmetrical
	tempvar y
	gen `y' = abs(`pvar'_traj)
	su `y'
	if r(max) < 1000 local ymax = round(r(max),100)
	if r(max) < 100 local ymax = round(r(max),10)
	if r(max) < 25 local ymax = round(r(max),5)
	if r(max) < 10 local ymax = round(r(max),1)
	if r(max) < 2 local ymax = round(r(max),0.1)

	label var dead28 "28 day mortality (%)"
	* ylab(-`ymax' 0 `ymax', nogrid) ///
	* zlabel(0(10)100) ///
	cap drop dead28_log2
	su dead28
	gen dead28_log2 = log(dead28) / log(2)
	label var dead28_log2 "28 day mortality (Log{subscript:2} scale)"	
	su dead28_log2

	* forvalues i = 10(10)90 {
	* 	local cut = log(`i') / log(2)
	* 	local cutlist `cutlist' `cut'
	* }
	* local cut100 = log(100) / log(2)
	* di "cutlist: 0 `cutlist' `cut100'"
	* zlabel(0 "1%" 1.6094379 "5%" 2.3025851 "10%" 3.2188758 "25%" 3.912023 "50%" 4.6051702 "100%") ///
	// NOTE: 2013-05-23 - need to explain this in the caption
	replace dead28 = 50 if dead28 > 50 & dead28 != .

	tw 	contour dead28 `pvar'_traj `pvar'2,	 ///
		interp(none) ///
		crule(hue) scolor(green) ecolor(red) ///
		ccuts(0(2.5)50)  ///
		zlabel(0(10)50) ///
		ylab(-`ymax' 0 `ymax', nogrid) ///
		yscale(noextend) ///
		ylab(,nogrid) ///
		ytitle("`ytitle'") ///
		xscale(noextend) ///
		xtitle("`xtitle'") ///
		graphregion(color(white)) ///
		plotregion(color(white)) ///
		subtitle("(B) 28 day mortality", size(medium) position(11) justification(left)) ///
		name(plot2, replace) nodraw

	cap drop n_log2
	gen n_log2 = log(n) / log(2)
	label var n_log2 "Number of patients (Log{subscript:2}n)"
	label var n "Number of patients"

	tw 	contour n_log2 `pvar'_traj `pvar'2,	 ///
		interp(none) ///
		crule(intensity) ecolor(green) ///
		ccuts(0(1)8) ///
		zlabel(0 "1" 1 "2" 2 "4" 3 "8" 4 "16" 5 "32" 6 "64" 7 "128" 8 "256") ///
		yscale(noextend) ///
		ylab(-`ymax' 0 `ymax', nogrid) ///
		ytitle("`ytitle'") ///
		xscale(noextend) ///
		xtitle("`xtitle'") ///
		graphregion(color(white)) ///
		plotregion(color(white)) ///
		subtitle("(A) Population distribution (n = `var_n')", size(medium) position(11) justification(left)) ///
		name(plot1, replace) nodraw

	graph combine plot1 plot2, ///
		rows(1) xsize(8) ysize(4) name(inspect_`pvar', replace)
	if c(os) == "Unix" local ext eps
	if c(os) == "Unix" local ext_alt pdf
	if c(os) != "Unix" local ext pdf
	if c(os) != "Unix" local ext_alt eps
	graph display inspect_`pvar'
	!rm ../outputs/figures/inspect_`pvar'.`ext_alt'
	graph export ../outputs/figures/inspect_`pvar'.`ext' ///
	    , name(inspect_`pvar') replace
	restore

}





