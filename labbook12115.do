*  ======================
*  = Working log 121115 =
*  ======================


/* ## Working on trajectory issues in (SPOT)light */

GenericSetupSteveHarris spot_traj scratch121115, logon
clear all
use ../data/working.dta
quietly include mtPrograms.do
quietly include cr_preflight.do
count
set scheme shbw

/*
Trajectory rarely seems important
- drill down on raw physiology to start
	PF ratios
	Serum lactate
*/

/* Wary of extreme values messing up the trajectory */


*  ==========================
*  = ### Lactate trajectory =
*  ==========================

global iif_lac if !missing(lac1, lac2) & abs(lac_traj) < 15
/*
NOTE: 2012-11-15 - specification of the population of interest
makes a big difference
spec below means lactate trajectory is un-important
since the difference between the 2 specifications is that
- in one I throw away extreme values
- in the othr I throw away extreme differences
Is it possible that extreme differences only arise when one measurement is in error
Then the strongest effect of a big differences is a 'mistake'
- this then drives the model to be 'unimportant'
global iif_lac if !missing(lac1, lac2) & lac1 <20 & lac2 < 20 & lac1>0 & lac2>0
*/

running dead28 lac1 $iif_lac, name(plot1, replace)
running dead28 lac2 $iif_lac, name(plot2, replace)
running dead28 lac_traj $iif_lac, name(plot3, replace)
graph combine plot1 plot2 plot3, ///
	row(1) ycommon name(lac_running, replace) ysize(3) xsize(6)
graph export ../logs/lac_running.pdf, replace


/* Would suit a linear spline nicely? single knot at 0 */

logit dead28 lac1 $iif_lac
logit dead28 lac2 $iif_lac
logit dead28 lac_traj $iif_lac
logit dead28 lac1 lac_traj $iif_lac
logit dead28 lac2 lac_traj $iif_lac
/* lactae trajectory is negative too!! */
logit dead28 age i.dx_cat lac2 lac_traj $iif_lac
/* and effect is stronger with improved adjustment */
logit dead28 age i.dx_cat c.lac2 c.lac_traj ims2 $iif_lac
/* no interaction found */
logit dead28 age i.dx_cat c.lac2##c.lac_traj ims2 $iif_lac

/* fracpoly version */
logit dead28 age i.dx_cat lac2 lac_traj ims2 $iif_lac
est store fp1
xi: fracpoly, compare: logit dead28 lac_traj age i.dx_cat lac2  ims2 $iif_lac
est store fp2
lrtest fp1 fp2
estimates stats fp1 fp2
fracplot if lac_traj > -10 & lac_traj < 10, msym(p)
graph export ../logs/lac_fracplot.pdf, replace

/* no interaction found */



cap drop lacsp*
mkspline lacsp1 0 lacsp2 = lac_traj, displayknots
logit dead28 lacsp1 lacsp2 $iif_lac
/* Much better as a standalone */
logit dead28 lacsp1 lacsp2 lac2 $iif_lac
est store m1
/*
1st part of the spline not much use still, 2nd part has a -ve coefficient
So if you were less unwell before you got to ICU then you do better
Needs an interaction
 */

logit dead28 lacsp1 c.lacsp2##c.lac2 $iif_lac
est store m2

/*
So the interaction is significant but the main effect is not ...
Intepretation is that admission lactate has different effects
- high lactates at admission have less of an effect than rising lactates at admission
- so patients with high lactate at admission
	- better outcome if pre-admission lactate is low
 */
lrtest m1 m2

/*
Stratify and create a table of outcomes to check this
*/
cap drop lac2_q5
xtile lac2_q5 = lac2 $iif_lac , nq(5)
tab lac2_q5 $iif_lac

cap drop lac_tr_cat
egen lac_tr_cat = cut(lac_traj) $iif_lac, at(-40,0,1,2,3,4,5,100) label
tab lac_tr_cat

tab lac_tr_cat lac2_q5
/*
Odd ... no pts exist who have incr lac and low pre-admisson lac
this must be the selection effect for admission to ICU?
*/
table lac_tr_cat lac2_q5, c(freq mean dead28) format(%9.2g)

/* Repeat model with categorical version */
logit dead28 lac2 i.lac_tr_cat ib(freq).lac_tr_cat#c.lac2 $iif_lac

/* This didn't help much ... similar pattern but less well demonstrated */
bys lac_tr_cat: logit dead28 lac2 $iif_lac
bys lac2_q5: logit dead28 lacsp1 lacsp2 $iif_lac


*  ============================
*  = Let's explore P:F ratios =
*  ============================
su pf1 pf2 pf_traj
global iif_pf if pf_traj > -30 & pf_traj < 20
su pf1 pf2 $iif_pf

running dead28 pf1 $iif_pf, name(plot1, replace)
running dead28 pf2 $iif_pf, name(plot2, replace)
running dead28 pf_traj $iif_pf, name(plot3, replace)
graph combine plot1 plot2 plot3, ///
	row(1) ycommon name(pf_running, replace) ysize(3) xsize(6)
graph export ../logs/pf_running.pdf, replace


/*
So below PF 40 then linear(ish) relation with mortality
- for current value (weaker with ward measurements)
For slope then static and negative slopes have no effect
- but upwards slopes above 5 kPa/day are good (and linear)
*/
cap drop pf2sp*
mkspline pf2sp1 40 pf2sp2 = pf2 $iif_pf, displayknots
su pf2sp* $iif_pf

logit dead28 pf2 $iif_pf
logit dead28 pf2sp1 pf2sp2 $iif_pf
/* So a spline fits better */

cap drop pf_trsp*
mkspline pf_trsp1 5 pf_trsp2 = pf_traj $iif_pf, displayknots
su pf_trsp* $iif_pf

logit dead28 pf_traj $iif_pf
logit dead28 pf_trsp1 pf_trsp2 $iif_pf
/* Again a spline fits better for the trajectory and incr PF is good */

/* So how many patients are there in these categories */
gen pf2_bad = pf2 < 40 $iif_pf
gen pf_tr_improv = pf_traj > 5 $iif_pf
tab pf2_bad pf_tr_improv
logit dead28 pf2_bad pf_tr_improv $iif_pf
logit dead28 pf2_bad##pf_tr_improv $iif_pf
/*
Simple classifcation
- bad PF is bad!!!
- improving PF is good!!
- no interaction
*/

logit dead28 pf2sp1 pf2sp2 pf_trsp1 pf_trsp2 $iif_pf, or
/* Now consider interactions ... does improvement affect current value */
logit dead28 pf2sp1 pf2sp2 pf_trsp1 pf_trsp2 c.pf2sp1#c.pf_trsp2 $iif_pf, or
/* No effect among those with low PF at admission */
logit dead28 pf2sp1 pf2sp2 pf_trsp1 pf_trsp2 c.pf2sp2#c.pf_trsp2 $iif_pf, or
/* Noe effect of delta among those with higher PF at admission */

/* fracpoly version */
logit dead28 pf2sp1 pf2sp2 age i.dx_cat $iif_pf
est store fp1
xi: fracpoly, compare: logit dead28 pf_traj pf2sp1 pf2sp2 age i.dx_cat $iif_pf
est store fp2
lrtest fp1 fp2
estimates stats fp1 fp2
fracplot if pf_traj > -20 & pf_traj < 20, msym(p)
graph export ../logs/pf_fracplot.pdf, replace


/* Completely flat!!! */

*  ==============
*  = Creatinine =
*  ==============
su cr1 cr2 cr_traj, d
global iif_cr if cr_traj > -200 & cr_traj < 200	& cr1 < 1000 & cr2 < 1000
su cr1 cr2 cr_traj $iif_cr

running dead28 cr1 $iif_cr, name(plot1, replace)
running dead28 cr2 $iif_cr, name(plot2, replace)
running dead28 cr_traj $iif_cr, name(plot3, replace)
graph combine plot1 plot2 plot3, ///
	row(1) ycommon name(cr_running, replace) ysize(3) xsize(6)
graph export ../logs/cr_running.pdf, replace

/*
So usual biphasic relationship betw creat and mortality
And oddly(?) incr or decr in creatinine is a 'bad' thing
*/

cap drop crsp*
mkspline crsp1 50 crsp2 300 crsp3 = cr2 $iif_cr, displayknots
su crsp* $iif_cr

logit dead28 cr2 $iif_cr
logit dead28 crsp1 crsp2 crsp3 $iif_cr

cap drop cr_trsp*
mkspline cr_trsp1 -50 cr_trsp2 100 cr_trsp3 = cr_traj $iif_cr, displayknots
su cr_trsp* $iif_cr

logit dead28 cr_traj $iif_cr
/* so 'average effect' is that incr cr is bad */
logit dead28 cr_trsp1 cr_trsp2 cr_trsp3 $iif_cr
/* and linear spline follows 'U' pattern then flattens off */
logit dead28 crsp1-crsp3 cr_trsp1-cr_trsp3 $iif_cr
/* and here, everything remains important */

/* Now check for interactions focusing on crsp2 */
logit dead28 crsp1 crsp2 crsp3 cr_trsp1 cr_trsp2 cr_trsp3 ///
	c.crsp2#c.cr_trsp1 c.crsp2#c.cr_trsp2 c.crsp2#c.cr_trsp3  ///
	$iif_cr


*  =============
*  = Platelets =
*  =============
su plat1 plat2 plat_traj, d
global iif_plat if plat_traj > -175 & plat_traj < 30
su plat1 plat2 plat_traj $iif_plat

running dead28 plat1 $iif_plat, name(plot1, replace)
running dead28 plat2 $iif_plat, name(plot2, replace)
running dead28 plat_traj $iif_plat, name(plot3, replace)
graph combine plot1 plot2 plot3, ///
	row(1) ycommon name(plat_running, replace) ysize(3) xsize(6)
graph export ../logs/plat_running.pdf, replace


/*
So that is not a straightforward relationship!
- Better outcome with lowest plateletes and again around 200
- see below
*/

cap drop plat_tr_cat
egen plat_tr_cat = cut(plat_traj), at(-200,-50,-25,0 50) label
tab dead28 plat_tr_cat $iif_plat, col

/* Simplification but categoriese plat2 into high-low */
cap drop plat_cat
egen plat_cat = cut(plat2), at(0,200,2000) label
tab dead28 plat_cat $iif_plat, col

/* Cross tab these categories to see if they are reasonably populated*/
tab plat_cat plat_tr_cat $iif_plat

table plat_cat plat_tr_cat $iif_plat, c(freq mean dead28) format(%9.2g)
/*
very odd relationship ...
- it is good either to have incr platelets or moderate fall
but not minor falls nor large falls
*/

logit dead28 plat_cat ib3.plat_tr_cat $iif_plat
logit dead28 plat_cat##ib3.plat_tr_cat $iif_plat
/* interaction doesn't add anything which is good 'cos it would be hard to interpret */

logit dead28 age plat_cat ib3.plat_tr_cat $iif_plat

/* Redo with simpler division for plat trajectory */
cap drop plat_tr_sp*
mkspline plat_tr_sp1 0 plat_tr_sp2 = plat_traj $iif_plat, displayknots
su plat_tr_sp*

logit dead28 plat_tr_sp1 plat_tr_sp2 $iif_plat
logit dead28 plat2 plat_tr_sp1 plat_tr_sp2 $iif_plat
logit dead28 plat_tr_sp1 c.plat2##c.plat_tr_sp2 $iif_plat
/*
So plat2 OK, 1st part of spline unhelpful, 2nd part OK
Interaction does not help
*/



*  ==========
*  = Sodium =
*  ==========
su na1 na2 na_traj, d
global iif_na if na_traj > -10 & na_traj < 10 & na2 >100
su na1 na2 na_traj $iif_na

running dead28 na1 $iif_na, name(plot1, replace)
running dead28 na2 $iif_na, name(plot2, replace)
/* Need to plot trajectory by 'level' */
tempvar sodium_cat
local cutpoints 116 136 150 
local cutpoints_csv = subinstr(trim("`cutpoints'"), " ", ", ", .)
egen `sodium_cat' = cut(na2), at(`cutpoints_csv') label
tab `sodium_cat'

local last = wordcount("`cutpoints'")
forvalues i = 2/`last' {
	local min = word("`cutpoints'", `i' - 1)
	local max = word("`cutpoints'", `i')
	local iif $iif_na & na2 >= `min' & na2 < `max'
	cap drop qq`i'
	running dead28 na_traj `iif', nodraw gen(qq`i')
	local iif $iif_na & na2 >= `min' & na2 < `max' & qq`i' > 0 & qq`i' < 1
	local tw_command `tw_command' (line qq`i' na_traj `iif')
}
sort na_traj
global tw_command "`tw_command'"

/* rug not v good as it needs jitter, the only visible 'smear' is b/c you divide by days */
* rug na_traj $iif_na , levels(10) zero(0.05)
* global rug1 $rugcommand
twoway $tw_command ///
	(hist na_traj $iif_na, freq s(-10) w(1) yaxis(2)) ///
	, ylab(0 1, axis(1)) ytitle("28 day mortality", axis(1)) ///
	yscale(range(0 5000) axis(2)) ylab(0 1000, axis(2)) ytitle("Frequency", axis(2)) ///
	legend(order(1 2) label(1 "Na < 136") label(2 "Na >= 136") pos(2) ring(0)) ///
	name(plot3, replace)

* running dead28 na_traj $iif_na, name(plot3, replace)
graph combine plot1 plot2 plot3, ///
	row(1) ycommon ysize(3) xsize(6) ///
	name(na_running, replace)

graph export ../logs/na_running.pdf, replace


/*
More odd pattenrs because v low Na is 'protective' ...
- prob a diagnostic class issue
- stick with simple turning point at 140 but drop the lowest Na < 120
Trajectory
- fall in Na is bad, rise is neutral
*/

cap drop na_cat na_tr_cat
gen na_cat = na2 > 140
gen na_tr_cat = na_traj > 0
tab na_cat na_tr_cat
table na_cat na_tr_cat $iif_na, c(freq mean dead28) format(%9.2g)
/*
Cross tab
- high sodium is bad
- falling sodium is good(!)
*/
logit dead28 na_cat $iif_na
logit dead28 na_tr_cat $iif_na
logit dead28 na_cat na_tr_cat $iif_na
logit dead28 na_cat##na_tr_cat $iif_na
/*
So trajectory is unimportant after accounting for current value
No interaction
*/


*  ========================
*  = ## ICNARC or SOFA score =
*  ========================
/*
Use a global severity measurement ... but handle 1st of all the missing data issue
*/

/*
1. Define a 'complete case' population where this is 'well measured' in both
2. Use MI to fill where it is not
*/
use ../data/working.dta, clear
qui include cr_preflight.do
/* vars for ICNARC score in (SPOT)light */

misstable summ hr1 bps1 temp1 rr1 pf1 ph1 urea1 cr1 na1 urin1 wcc1 gcs1
misstable patt hr1 bps1 temp1 rr1 pf1 ph1 urea1 cr1 na1 urin1 wcc1 gcs1, freq

misstable summ hr2 bps2 temp2 rr2 pf2 ph2 urea2 cr2 na2 urin2 wcc2 gcs2
misstable patt hr1 bps2 temp2 rr2 pf2 ph2 urea2 cr2 na2 urin2 wcc2 gcs2, freq


misstable patt 	hr1 bps1 temp1 rr1 pf1 ph1 urea1 cr1 na1 urin1 wcc1 gcs1 ///
				hr1 bps2 temp2 rr2 pf2 ph2 urea2 cr2 na2 urin2 wcc2 gcs2, freq


/*
So there are ~700 with complete data for ICNARC score in SPOT and CMPD
Now go on and define ICNARC score with and without the 4 most commonly missed vars
- gcs1 urin1 ph1 pf1

*/
*  ===================================
*  = ### ICNARC score complete cases =
*  ===================================
su ims_c*
global iif_ims_c if !missing(ims_c1, ims_c2)
codebook ims_c* $iif_ims_c , compact
tabstat ims_c* $iif_ims_c, s(n mean sd skew kurt min max) c(s)
/* Note very little difference in mean score */
corr ims_c1 ims_c2 $iif_ims_c

running dead28 ims_c1 $iif_ims_c, name(plot1, replace)
running dead28 ims_c2 $iif_ims_c, name(plot2, replace)
running dead28 ims_c_traj $iif_ims_c, name(plot3, replace)
graph combine plot1 plot2 plot3, ///
	row(1) ycommon name(ims_c_running, replace) ysize(3) xsize(6)
graph export ../logs/ims_c_running.pdf, replace

/* ims_c is linear, trajectory has inflexion at 0 */
logit dead28 ims_c2 $iif_ims_c
est store m1
logit dead28 ims_c2 ims_c_traj $iif_ims_c
est store m2

cap drop ims_c_tr_spl*
mkspline ims_c_tr_spl1 0 ims_c_tr_spl2 = ims_c_traj $iif_ims_c, displayknots
su ims_c_tr_spl* $iif_ims_c
logit dead28 ims_c_tr_spl1 ims_c_tr_spl2 $iif_ims_c
/* Negative trajectory has no effect, positive similar to ims_c2 */
logit dead28 ims_c2 ims_c_tr_spl1 ims_c_tr_spl2 $iif_ims_c
/* With interaction */
logit dead28 ims_c2 ims_c_tr_spl1 ims_c_tr_spl2 c.ims_c2#c.ims_c_tr_spl1 c.ims_c2#c.ims_c_tr_spl2 $iif_ims_c
/*
Now you see that trajectory and current value are correlated above 0
And having a flat trajectory is non-significantly protective
*/
corr ims_c2 ims_c_tr_spl2
corr ims_c2 ims_c_tr_spl1

/* Now add in age and diagnosis */
logit dead28 age ims_c2 ims_c_tr_spl1 ims_c_tr_spl2 $iif_ims_c
logit dead28 age i.dx_cat ims_c2 ims_c_tr_spl1 ims_c_tr_spl2 $iif_ims_c
/*
NOTE: 2012-11-15 - 
So complete cases
... negative traj no effect alone, positive traj is assoc with harm
But in full model
... an INCREASE in trajectory if the traj is negative is 'good'
i.e. a less negative trajectory is good?!

TODO: 2012-11-15 - repeat in full sample (include poor quality sites)
*/
/* Fracpoly version */
logit dead28 age ims_c2 i.dx_cat $iif_ims_c
est store m1
xi: fracpoly, compare: logit dead28 ims_c_traj age ims_c2 i.dx_cat $iif_ims_c
est store m2
lrtest m1 m2
estimates stats m1 m2
fracplot if ims_c_traj > -20 , msym(p)
graph export ../logs/ims_c_traj_fracplot.pdf, replace

/* So overall fit of fracpoly suggests again that a +ve trajectory is 'good' */
/* Borderline improvement in fit with trajectory ... basically same story */

/* Survival version */
stcox age ims_c2 i.dx_cat $iif_ims_c, nolog
est store m1
xi: fracpoly, compare: stcox ims_c_traj age ims_c2 i.dx_cat $iif_ims_c, nolog
est store m2
lrtest m1 m2
estimates stats m1 m2
fracplot if ims_c_traj > -20 , msym(p)


/* Same story */

*  =====================================================================
*  = ### ICNARC score - missing some but matched between spot and cmpd =
*  =====================================================================
/*

8 of 12 components of ICNARC physiology score
- hr
- bps
- rr
- cr
- na
- wcc
- temp
- urea

*/

su ims_ms*
global iif_ims_ms if !missing(ims_ms1, ims_ms2)
codebook ims_ms* $iif_ims_ms , compact
tabstat ims_ms* $iif_ims_ms, s(n mean sd skew kurt min max) c(s)
/* Note very little difference in mean score */
corr ims_ms1 ims_ms2 $iif_ims_ms

running dead28 ims_ms1 $iif_ims_ms, name(plot1, replace)
running dead28 ims_ms2 $iif_ims_ms, name(plot2, replace)
running dead28 ims_ms_traj $iif_ims_ms, name(plot3, replace)
graph combine plot1 plot2 plot3, ///
	row(1) ycommon name(ims_ms_running, replace) ysize(3) xsize(6)
graph export ../logs/ims_ms_running.pdf, replace


/* Similar pattern to compete cases but truncated range of mortality in SPOT */
logit dead28 ims_ms2 $iif_ims_ms
est store m1
logit dead28 ims_ms2 ims_ms_traj $iif_ims_ms
est store m2
lrtest m1 m2
estimates stats m1 m2
/* Trajectory 'protective' and significantly so */
logit dead28 c.ims_ms2##c.ims_ms_traj $iif_ims_ms
est store m3
lrtest m2 m3
estimates stats m1 m2 m3
/* No evidence of an interaction ... but remember the main effect is mis-specified */

/* Use linear splines with knot at 0 */
cap drop ims_ms_tr_spl*
mkspline ims_ms_tr_spl1 0 ims_ms_tr_spl2 = ims_ms_traj $iif_ims_ms, displayknots
su ims_ms_tr_spl* $iif_ims_ms
logit dead28 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms
/* In isolation ...  */
/* Negative trajectory has no effect, positive similar to ims_ms2 */
logit dead28 ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms
/* So this is puzzling ... 
- now the flat part has no effect
- but the steep part has a negative effect
Need to check for interactions ...
*/
est drop _all
logit dead28 age i.dx_cat ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms
est store m1
/* Effect incr after adjusting for age and diagnosis */
logit dead28 age i.dx_cat ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 ///
	c.ims_ms2#c.ims_ms_tr_spl1 c.ims_ms2#c.ims_ms_tr_spl2 ///
	$iif_ims_ms
est store m2
lrtest m1 m2
estimates stats m1 m2
/* So no evidence of a simple multiplicative interaction */

/* Switch to frac poly and check in cox model */
stcox age i.dx_cat ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms, nolog
/* Same story ... incr trajectory is protective */
logit dead28 ims_ms2 age i.dx_cat $iif_ims_ms
est store fp1
xi: fracpoly, compare: logit dead28 ims_ms_traj ims_ms2 age i.dx_cat $iif_ims_ms
est store fp2
lrtest fp1 fp2
estimates stats fp1 fp2
fracplot if ims_ms_traj > -20 , msym(p)
graph export ../logs/ims_ms_traj_fracplot.pdf, replace



/* Same story, deteriorating is better than deteriorated */
/* Now check in cox */
stcox ims_ms2 age i.dx_cat $iif_ims_ms
est store cox1
xi: fracpoly, compare: stcox ims_ms_traj ims_ms2 age i.dx_cat $iif_ims_ms
est store cox2
lrtest cox1 cox2
estimates stats cox1 cox2
fracplot if ims_ms_traj > -20 , msym(p)

/* Refit with centred values */
su age
gen age_c = age - `r(mean)'
su ims_ms2
gen ims_ms2_c = ims_ms2 - `r(mean)'
stcox ims_ms2_c age_c i.dx_cat $iif_ims_ms
est store cox1
xi: fracpoly, compare: stcox ims_ms_traj ims_ms2_c age_c i.dx_cat $iif_ims_ms
est store cox2
lrtest cox1 cox2
estimates stats cox1 cox2
fracplot if ims_ms_traj > -20 , msym(p)

/* Actually effect appears pretty linear / constant over main range */
/* Refit linear spline with knot at -10 */
cap drop ims_ms_tr_spl*
mkspline ims_ms_tr_spl1 -10 ims_ms_tr_spl2 = ims_ms_traj $iif_ims_ms, displayknots
su ims_ms_tr_spl* $iif_ims_ms
logit dead28 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms
/* Negative trajectory has no effect, positive similar to ims_ms2 */
logit dead28 ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms
logit dead28 age i.dx_cat ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms
/* Same 'benefit' ... deteriorating is better than deteriorated */
lincom ims_ms_tr_spl2*5, or
/* So a 5 point increase in severity per day reduces your odds by ~15% */
/* Check again for interaction */
logit dead28 age i.dx_cat ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 c.ims_ms2#c.ims_ms_tr_spl2 ///
		$iif_ims_ms
/* Again no evidence */

/* Alternative specification */
/* binreg for risk differences and risk ratios */
* binreg dead28 ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms, rd 
/*
Doesn't converge with default settings - options 'search ml' no help
*/

/* Mixed effects, within sites */
encode icode, gen(idsite)
xtlogit dead28 age i.dx_cat ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms, i(idsite) re

/* Now check in the full uncleaned population */
use ../data/working_all.dta, clear
/* set debug off else will load working.dta */
global debug = 0
qui include cr_preflight.do
count
cap drop ims_ms_tr_spl*
mkspline ims_ms_tr_spl1 -10 ims_ms_tr_spl2 = ims_ms_traj $iif_ims_ms, displayknots
su ims_ms_tr_spl* $iif_ims_ms
logit dead28 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms
logit dead28 age i.dx_cat ims_ms2 ims_ms_tr_spl1 ims_ms_tr_spl2 $iif_ims_ms


/* Now check how this plays with time2icu */
use ../data/working.dta, clear
qui include cr_preflight.do

gen ims_ms_delta = ims_ms2 - ims_ms1
gen ims_c_delta = ims_c2 - ims_c1
su ims_ms_delta ims_c_delta
running ims_ms_delta time2icu if time2icu < 96, msym(p) ci
running ims_c_delta time2icu if time2icu < 96, msym(p) ci
regress ims_ms_delta time2icu
regress ims_c_delta time2icu
/* Very weak +ve relationship */

running dead28 ims_ms_delta $iif_ims_ms
/* usual inflexion at around -10 - 0 */
cap drop ims_ms_tr_spl*
mkspline ims_ms_delta_spl1 -10 ims_ms_delta_spl2 = ims_ms_delta $iif_ims_ms, displayknots
su ims_ms_delta_spl* $iif_ims_ms
logit dead28 ims_ms_delta_spl1 ims_ms_delta_spl2 $iif_ims_ms
logit dead28 age i.dx_cat time2icu ims_ms2 ims_ms_delta_spl1 ims_ms_delta_spl2 $iif_ims_ms


/*
NOTE: 2012-11-15 - big jumps in ICNARC score seem to be often driven by BP
*/
cap log off