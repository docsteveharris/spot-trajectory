*  ================================================
*  = Inspect and understand observed trajectories =
*  ================================================

*  =======================================
*  = Log definitions and standard set-up =
*  =======================================
GenericSetupSteveHarris spot_traj an_trajectories, logon
clear all
use ../data/working.dta
quietly include cr_preflight.do
quietly include mtPrograms.do

/* Proto-type trajectory graph */
* cap drop ims_traj_cat
* * xtile ims_traj_cat = ims_traj, nq(20)
* egen ims_traj_cat = cut(ims2), group(20) label
* graph box ims_traj, over(ims_traj_cat) ///
* 	box(1, lwidth(vvvthin)) medtype(cline) medline(lcolor(black)) ///
* 	alsize(33) ///
* 	marker(1, msymbol(point))

*  ==================================================================
*  = Linear markers - those with a linear relatinoship with outcome =
*  ==================================================================
/* ICNARC score - missing some */
running ims_ms_traj ims_ms2 ///
	if !missing(ims_ms2) & abs(ims_ms_traj) <= 20, ///
	ylab(-20(10)20)

/* ICNARC score - complete */
running ims_c_traj ims_c2 ///
	if !missing(ims_c2) & abs(ims_c_traj) <= 20, ///
	ylab(-20(10)20)

/* Lactate */
running lac_traj lac2 ///
	if !missing(lac2) & abs(lac_traj) <= 10 & lac2 < 10, ///
	ylab(-10(5)10)


/* P:F ratio */
running pf_traj pf2 ///
	if !missing(pf2) & abs(pf_traj) <= 50 & pf2 < 100, ///
	ylab(-50(25)50)


*  ======================
*  = Non-linear markers =
*  ======================
/*
So here trajectory depends on the position in the 'u'
*/
cap drop qq
running dead28 na2, gen(qq) nodraw

cap log close