*  =======================================================
*  = Define the lactate admission versus trajectory grid =
*  =======================================================

/*
created:	130406
modified:	130406

Report distribution of trajectory and boundaries selected to define groups
Use MI data and complete cases

*/

/* LACTATE complete - univariate */
* use ../data/working_postflight.dta, clear
use ../data/_archive/working_postflight_mi.dta, clear
su lac2 lac1 lac_traj if m0

/* Plot distribution of trajectory */

su lac_traj if m0, d
global tsd = r(sd)
local tsd_n = 0
local tsd_i = (-1 *   r(sd) / 2)
local tsd_w = (+1 *   r(sd) / 2)
tw  ///
	(function y=40, range(-15 `tsd_i') recast(area) fintensity(inten10) color("49 163 84") base(0.1)) ///
	(function y=40, range(`tsd_w' 15) recast(area) fintensity(inten10) color("215 48 31") base(0.1)) ///
	(hist lac_traj if m0 & abs(lac_traj) <= 15, ///
		percent start(-15) width(1) ) ///
	, ///
	ytitle("Patients (%)") ///
	ylabel(0(5)40) ///
	xlabel(-15(5)15) ///
	xtitle("Change in lactate" ///
			"(1{superscript:st} 24 hour value - ward assessment value)") ///
	text(39 0 "Neutral", placement(c) size(small)) ///
	text(39 5 "Worsening", placement(c) size(small)) ///
	text(39 -5 "Improving", placement(c) size(small)) ///
	legend(off)

graph rename lac_traj_italian, replace
graph display lac_traj_italian
graph export ../outputs/figures/lac_traj_italian.pdf ///
    , name(lac_traj_italian) replace



*  =========================
*  = Now the bivariate map =
*  =========================
/*
Use MI data and avergae as per Rubin
*/

use ../data/working_postflight_mi_plus.dta, clear

su lac_traj if m0, d
global tsd = r(sd)

qui su _mi_m
local imputations = r(max)
drop if m0
keep if !missing(lac_traj)
cap drop c2_k traj
egen traj = cut(lac_traj), at(-10(1)10)
egen c2_k = cut(lac2), at(0(1)20)
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
	if `i' < 4 local msize vlarge
	if `i' < 8 & `i' >= 4 local msize large
	if `i' < 12 & `i' >= 8 local msize medlarge
	if `i' < 16 & `i' >= 12 local msize medlarge
	local plot (scatter c2_k traj if mcolor == `i', msymbol(S) mcolor(gs`i') msize(`msize') )
	local plots `plots' `plot'
}
di "`plots'"
global plots = ""
global plots `plots'

local tsd_n = 0
local tsd_i = (-1 *   $tsd) / 2
local tsd_w = (+1 *   $tsd) / 2

tw ///
	(function y=20, range(-10 -$tsd) recast(area) fintensity(inten10) color("49 163 84") base(0.1)) ///
	(function y=20, range(0 10) recast(area) fintensity(inten10) color("215 48 31") base(0.1)) ///
	$plots ///
	, ///
	ylabel(0(5)20) ///
	xlabel(-10(5)10) ///
	legend(off) ///
	ysize(8) xsize(8) ///
	xtitle("Change from pre-admission lactate" ///
			, size(small)) ///
	ytitle("Lactate" ///
			"1{superscript:st} 24 hour value", size(small)) ///
	text(19 0  "Neutral", placement(c) size(vsmall)) ///
	text(19 5  "Worsening" "severity", placement(c) size(vsmall)) ///
	text(19 -5  "Improving" "severity", placement(c) size(vsmall)) 



graph rename lac_biv_italian, replace
graph display lac_biv_italian
graph export ../outputs/figures/lac_biv_italian.pdf ///
    , name(lac_biv_italian) replace

