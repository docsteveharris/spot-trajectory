*  ================================
*  = Distribution of ICNARC score =
*  ================================

/*
created:	130406
modified:	130406

Report distribution of trajectory and boundaries selected to define groups
Use MI data and complete cases

*/

/* ICNARC complete - univariate */
use ../data/working_postflight_mi_plus.dta, clear
su ims_c2 ims_c1 ims_c_traj if m0

/* Plot distribution of trajectory */

su ims_c_traj if m0, d
local tsd = r(sd)
local tsd_n = -1*   r(sd) / 2
local tsd_i = (-1*   r(sd) / 2) - (2 * r(sd))
local tsd_w = (-1*   r(sd) / 2) + (2 * r(sd))
tw  ///
	(function y=20, range(-30 -`tsd') recast(area) fintensity(inten10) color("49 163 84") base(0.1)) ///
	(function y=20, range(0 30) recast(area) fintensity(inten10) color("215 48 31") base(0.1)) ///
	(hist ims_c_traj if m0 & abs(ims_c_traj) <= 30, ///
		percent start(-30) width(2) ) ///
	, ///
	ytitle("Patients (%)") ///
	ylabel(0(5)20) ///
	xlabel(-30(10)30) ///
	xtitle("Change from pre-admission ICNARC score" ///
			"(1{superscript:st} 24 hour value - ward assessment value)") ///
	text(19 `tsd_n' "Neutral", placement(c) size(small)) ///
	text(19 `tsd_w' "Worsening" "severity", placement(c) size(small)) ///
	text(19 `tsd_i' "Improving" "severity", placement(c) size(small)) ///
	legend(off)

graph rename ims_c_traj_italian, replace
graph display ims_c_traj_italian
graph export ../outputs/figures/ims_c_traj_italian.pdf ///
    , name(ims_c_traj_italian) replace



*  =========================
*  = Now the bivariate map =
*  =========================
/*
Use MI data and avergae as per Rubin
*/

use ../data/working_postflight_mi_plus.dta, clear

su ims_c_traj if m0, d
global tsd = r(sd)

qui su _mi_m
local imputations = r(max)
drop if m0
keep if !missing(ims_c_traj)
cap drop c2_k traj
egen traj = cut(ims_c_traj), at(-25(5)25)
egen c2_k = cut(ims_c2), at(0(5)50)
collapse (count) n = id, by(traj c2_k)
replace n = round(n/`imputations')

cap drop z
gen z = n
su z

/* Ugly */
tw (contourline z traj c2_k, ///
	ccuts(0 1 2 4 8 16 32 64 128 256 512) ///
	 interp(none))

/* Hand code your own density plot */

// use gs where 0 is black and 16 is white
* cap drop mcolor
* egen mcolor = cut(z), at(1 2 4 8 16 32 64 128 256 512)
* replace mcolor = log(mcolor) / log(2)
* su mcolor
* replace mcolor = 2 * (r(max) - mcolor)
* replace mcolor = 15 if mcolor >= 16 & mcolor != .
* su mcolor
* local max = r(max)
* forvalues i = 0/`max' {
* 	if `i' < 4 local msize huge
* 	if `i' < 8 & `i' >= 4 local msize vlarge
* 	if `i' < 12 & `i' >= 8 local msize large
* 	if `i' < 16 & `i' >= 12 local msize large
* 	local plot (scatter traj c2_k if mcolor == `i', msymbol(S) mcolor(gs`i') msize(`msize') )
* 	local plots `plots' `plot'
* }
* di "`plots'"
* global plots `plots'

* local tsd_n = -1*   $tsd / 2
* local tsd_i = (-1*   $tsd / 2) - (2 * $tsd)
* local tsd_w = (-1*   $tsd / 2) + (2 * $tsd)

// plot with current value on x
* tw ///
* 	(function y=-$tsd, range(0 60) base(-30) ///
* 		recast(area) fintensity(inten10) color("49 163 84") ) ///
* 	(function y=30, range(0 60) base(0) ///
* 		recast(area) fintensity(inten10) color("215 48 31")) ///
* 	$plots ///
* 	, ///
* 	ylabel(-30(10)30) ///
* 	xlabel(0(10)60) ///
* 	legend(off) ///
* 	ysize(6) xsize(6) ///
* 	xtitle("ICNARC Acute Physiology Score" ///
* 			"1{superscript:st} 24 hour value", size(small)) ///
* 	ytitle("Change in ICNARC Acute Physiology Score" ///
* 			, size(small)) ///
* 	text(`tsd_n' 60 "Neutral", placement(w) size(small)) ///
* 	text(`tsd_w' 60 "Worsening" "severity", placement(w) size(small)) ///
* 	text(`tsd_i' 60 "Improving" "severity", placement(w) size(small)) 

// plot with trajectory on x
// use gs where 0 is black and 16 is white
cap drop mcolor
egen mcolor = cut(z), at(1 2 4 8 16 32 64 128 256 512)
replace mcolor = log(mcolor) / log(2)
su mcolor
replace mcolor = 2 * (r(max) - mcolor)
replace mcolor = 15 if mcolor >= 16 & mcolor != .
su mcolor
local max = r(max)
forvalues i = 0/`max' {
	if `i' < 4 local msize huge
	if `i' < 8 & `i' >= 4 local msize vlarge
	if `i' < 12 & `i' >= 8 local msize large
	if `i' < 16 & `i' >= 12 local msize large
	local plot (scatter c2_k traj if mcolor == `i', msymbol(S) mcolor(gs`i') msize(`msize') )
	local plots `plots' `plot'
}
di "`plots'"
global plots = ""
global plots `plots'

local tsd_n = -1*   $tsd / 2
local tsd_i = (-1*   $tsd / 2) - (2 * $tsd)
local tsd_w = (-1*   $tsd / 2) + (2 * $tsd)

tw ///
	(function y=60, range(-30 -$tsd) recast(area) fintensity(inten10) color("49 163 84") base(0.1)) ///
	(function y=60, range(0 30) recast(area) fintensity(inten10) color("215 48 31") base(0.1)) ///
	$plots ///
	, ///
	ylabel(0(10)60) ///
	xlabel(-30(10)30) ///
	legend(off) ///
	ysize(8) xsize(8) ///
	xtitle("Change from pre-admission ICNARC score" ///
			, size(small)) ///
	ytitle("ICNARC score" ///
			"1{superscript:st} 24 hour value", size(small)) ///
	text(57 `tsd_n'  "Neutral", placement(c) size(vsmall)) ///
	text(57 `tsd_w'  "Worsening" "severity", placement(c) size(vsmall)) ///
	text(57 `tsd_i'  "Improving" "severity", placement(c) size(vsmall)) 



graph rename ims_biv_italian, replace
graph display ims_biv_italian
graph export ../outputs/figures/ims_biv_italian.pdf ///
    , name(ims_biv_italian) replace

*  ==================
*  = END OF PROGRAM =
*  ==================
exit
/* Can't work out why the y-axis does not scale OK */
sunflower ims_c_traj ims_c2  ///
	if m0 & abs(ims_c_traj) < 20 ///
	, notable ///
	binwidth(2) ///
	binar(1) ///
	dark(6) ///
	ylabel(-20(10)20) ///
	yscale(noextend) ///
	xlabel(0(10)50) ///
	legend(off) xsize(6) ysize(6) aspect(1)

exit
/*
Code below for contour plot but because there are 'holes' then this looks very ugly
*/
qui su _mi_m
local imputations = r(max)
drop if m0
keep if !missing(ims_c_traj)
cap drop c2_k traj
egen traj = cut(ims_c_traj), at(-30(10)30)
egen c2_k = cut(ims_c2), at(0(10)50)
collapse (count) n = id, by(traj c2_k)
replace n = n/`imputations'

cap drop z
gen z = n
su z
replace z = 0 if n <= 4
drop if z < 4
tw (contour z traj c2_k, ///
	ccuts(0 1 2 4 8 16 32 64 128 256 512) ///
	 interp(none))

exit
