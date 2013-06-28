*  =================================================================
*  = Plot the pre-admission trajectory against the admission value =
*  =================================================================

GenericSetupSteveHarris spot_traj an_fig_delta_vs_cmp, logon
global figure_name delta_vs_cmp

/*
created:	130403

x-axis admission value
y-axis 1: pre-admission delta
y-axis 2: histogram

Initially focus on admissions within 4 / 12 / 24+ hrs

Dotplots

## Change log



*/


// ICNARC complete
use ../data/working_postflight.dta, clear
keep if time2icu < 24
cap drop __*
su ims_c2 ims_c1

egen ims_c2_k10 = cut(ims_c2), at(0(5)50)
drop if ims_c2_k10 == .

// dotplot version
dotplot ims_c_traj if abs(ims_c_traj) < 20   ///
	, ///
	over(ims_c2_k10) nogroup center  ///
	msize(small) msymbol(o) ///
	ytitle("ICNARC Acute Physiology Score" "Absolute change from ward to ICU", ) ///
	ylabel(-20(5)20,  nogrid) ///
	xtitle("ICNARC Acute Physiology Score" "1{superscript:st} 24 hours in ICU", margin(medium)) ///
	xlabel(0(10)50) ///
	xscale(noextend) ///
	yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) )

graph rename delta_vs_cmp_24_complete_dotplot, replace
graph display delta_vs_cmp_24_complete_dotplot

collapse ///
	(mean) ims_c_traj_bar = ims_c_traj ///
	(semean) ims_c_traj_se = ims_c_traj ///
	(count) n = ims_c_traj ///
	, by(ims_c2_k10)


gen min95 = ims_c_traj_bar - 1.96 * ims_c_traj_se
gen max95 = ims_c_traj_bar + 1.96 * ims_c_traj_se

tw ///
	(bar n ims_c2_k10, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 ims_c2_k10 if n > 10, yaxis(2)) ///
	(scatter ims_c_traj_bar ims_c2_k10 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("ICNARC Acute Physiology Score" "Absolute change from ward to ICU", axis(2)) ///
	ylabel(-10(5)10, axis(2) nogrid) ///
	xtitle("ICNARC Acute Physiology Score" "1{superscript:st} 24 hours in ICU", margin(medium)) ///
	xlabel(0(5)50) ///
	xscale(noextend) ///
	yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) axis(2)) ///
	text(10 0 "(A)", placement(e) yaxis(2) size(large)) ///
	legend(off)

graph rename delta_vs_cmp_24_complete, replace
graph display delta_vs_cmp_24_complete
graph export ../outputs/figures/delta_vs_cmp_24_complete.pdf, replace

*****************
// ICNARC partial
use ../data/working_postflight.dta, clear
keep if time2icu < 24
cap drop __*
su ims_ms1 ims_ms2

egen ims_ms2_k25 = cut(ims_ms2), at(0(2)50)
drop if ims_ms2_k25 == .

// dotplot version
dotplot ims_ms_traj if abs(ims_ms_traj) < 20   ///
	, ///
	over(ims_ms2_k25) nogroup center  ///
	msize(small) msymbol(o) ///
	ytitle("(Partial) ICNARC Acute Physiology Score" "Absolute change from ward to ICU", ) ///
	ylabel(-20(5)20,  nogrid) ///
	xtitle("(Partial) ICNARC Acute Physiology Score" "1{superscript:st} 24 hours in ICU", margin(medium)) ///
	xlabel(0(10)50) ///
	xscale(noextend) ///
	yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) )

graph rename delta_vs_cmp_24_partial_dotplot, replace
graph display delta_vs_cmp_24_partial_dotplot

collapse ///
	(mean) ims_ms_traj_bar = ims_ms_traj ///
	(semean) ims_ms_traj_se = ims_ms_traj ///
	(count) n = ims_ms_traj ///
	, by(ims_ms2_k25)


gen min95 = ims_ms_traj_bar - 1.96 * ims_ms_traj_se
gen max95 = ims_ms_traj_bar + 1.96 * ims_ms_traj_se

tw ///
	(bar n ims_ms2_k25, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 ims_ms2_k25 if n > 10, yaxis(2)) ///
	(scatter ims_ms_traj_bar ims_ms2_k25 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("(Partial) ICNARC Acute Physiology Score" "Absolute change from ward to ICU", axis(2)) ///
	ylabel(-10(5)10, axis(2) nogrid) ///
	xtitle("(Partial) ICNARC Acute Physiology Score" "1{superscript:st} 24 hours in ICU", margin(medium)) ///
	xlabel(0(5)50) ///
	xscale(noextend) ///
	yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) axis(2)) ///
	text(10 0 "(A)", placement(e) yaxis(2) size(large)) ///
	legend(off)

graph rename delta_vs_cmp_24_partial, replace
graph display delta_vs_cmp_24_partial
graph export ../outputs/figures/delta_vs_cmp_24_partial.pdf, replace


**********
// Lactate
* NOTE: 2013-04-03 - this comparison is between a point lactate and the *highest* in the 1st 24 hrs

use ../data/working_postflight.dta, clear
keep if time2icu < 24
cap drop __*
su lac1 lac2

egen lac2_k20 = cut(lac2), at(0(1)20)
drop if lac2_k20 == .

// dotplot version
dotplot lac_traj if lac2 < 15 & lac_traj < 15 ///
	, ///
	over(lac2_k20) nogroup center  ///
	msize(small) msymbol(o) ///
	ytitle("Lactate" "Absolute change from ward to ICU", ) ///
	ylabel(-15(5)15,  nogrid) ///
	xtitle("Lactate" "1{superscript:st} 24 hours in ICU", margin(medium)) ///
	xlabel(0(5)15) ///
	xscale(noextend) ///
	yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) )

graph rename delta_vs_cmp_24_lactate_dotplot, replace
graph display delta_vs_cmp_24_lactate_dotplot

collapse ///
	(mean) lac_traj_bar = lac_traj ///
	(semean) lac_traj_se = lac_traj ///
	(count) n = lac_traj ///
	, by(lac2_k20)


gen min95 = lac_traj_bar - 1.96 * lac_traj_se
gen max95 = lac_traj_bar + 1.96 * lac_traj_se

tw ///
	(bar n lac2_k20, ///
		barwidth(0.5) ///
		color(gs12) yaxis(1)) ///
	(rspike max95 min95 lac2_k20 if n > 10, yaxis(2)) ///
	(scatter lac_traj_bar lac2_k20 if n > 10, ///
		msym(S) yaxis(2)) ///
	, ///
	yscale(alt noextend axis(1)) ///
	ytitle("Patients", axis(1)) ///
	ylabel(, axis(1) nogrid) ///
	yscale(alt noextend axis(2)) ///
	ytitle("Lactate" "Absolute change from ward to ICU", axis(2)) ///
	ylabel(-10(5)10, axis(2) nogrid) ///
	xtitle("Lactate" "1{superscript:st} 24 hours in ICU", margin(medium)) ///
	xlabel(0(5)20) ///
	xscale(noextend) ///
	yline(0, noextend lwidth(thin) lpattern(solid) lcolor(black) axis(2)) ///
	text(10 0 "(A)", placement(e) yaxis(2) size(large)) ///
	legend(off)

graph rename delta_vs_cmp_24_lactate, replace
graph display delta_vs_cmp_24_lactate
graph export ../outputs/figures/delta_vs_cmp_24_lactate.pdf, replace

graph combine delta_vs_cmp_24_lactate delta_vs_cmp_24_complete delta_vs_cmp_24_partial ///
	, cols(1) xsize(4) ysize(8)

// NOTE: 2013-04-04 - so this shows the mean trajectory but not the distribution
graph rename delta_vs_cmp_24_combined, replace
graph display delta_vs_cmp_24_combined
graph export ../outputs/figures/delta_vs_cmp_24_combined.pdf ///
	, name(delta_vs_cmp_24_combined) replace


graph combine  ///
		delta_vs_cmp_24_lactate_dotplot ///
		delta_vs_cmp_24_complete_dotplot ///
		delta_vs_cmp_24_partial_dotplot ///
	, cols(1) xsize(4) ysize(8)

// NOTE: 2013-04-04 - so this shows the mean trajectory but not the distribution
graph rename delta_vs_cmp_24_dotplot_combined, replace
graph display delta_vs_cmp_24_dotplot_combined
graph export ../outputs/figures/delta_vs_cmp_24_dotplot_combined.pdf ///
	, name(delta_vs_cmp_24_dotplot_combined) replace





cap log close

