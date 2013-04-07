*  ============================================================
*  = Model trajectory based on the idea of a constrained grid =
*  ============================================================

/*
created:	130406
modified:	130407

Use factor notation so can exploit margins afterwards
e.g.
	ib2.ims_c2_k##ib2.ims_tvector
However there will (by definition be no category (1,3) or (3,1))

Planned outputs
	- table (not for now: does not really add much ... save this for the "final" model)
	- margins (as grid) ... will need some manipulation

with a by-clause to show the MI result alongside the CC

NOTE: 2013-04-07 - add the MI version of the outputs later

*/

GenericSetupSteveHarris spot_traj an_model_im_traj_grid, logon
clear all
use ../data/working_postflight_mi_plus.dta, clear
cap drop cc
gen cc = m0 == 1 & !missing(ims_c1, ims_c2)
label var cc "Complete cases"
label values cc truefalse
tab cc

global tablename im_traj_grid_cc


/* Complete cases set up to look at Average Marginal Effects */
tab ims_tclass if cc
logistic dead28 age_c sex i.dx_cat ib5.ims_tclass if cc
margins , dydx(ims_tclass) atmeans
margins , dydx(ims_tclass)

/* Complete cases estimate */
logistic dead28 age_c sex i.dx_cat ib1.ims_c2_k##ib1.ims_tvector if cc
/* Average marginal effects at the means */
margins ims_c2_k#ims_tvector if cc, atmeans grand post
est store margins_cc_grid
marginsplot, x(ims_tvector) legend(pos(3))

/* Now tidy up the plot */
local ggreen "49 163 84"
local rred "215 48 31"
marginsplot ///
	, ///
	recastci(rspike) ///
	plotopts(msymbol(o)) ///
	plot1opts(mcolor("`ggreen'") lcolor("`ggreen'")) ///
	ci1opts(lcolor("`ggreen'")) ///
	plot3opts(mcolor("`rred'") lcolor("`rred'")) ///
	ci3opts(lcolor("`rred'")) ///
	x(ims_tvector) ///
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

graph rename im_traj_grid_cc, replace
graph export ../outputs/figures/im_traj_grid_cc.pdf ///
    , name(im_traj_grid_cc) replace

*  ==============================
*  = TEMPORARY PROGRAM END HERE =
*  ==============================
exit


/* Partial+ABG cases estimate */
logistic dead28 age_c sex i.dx_cat ib1.ims_abg2_k##ib1.ims_abg_tvector if cc
est store ims_abg_grid
margins ims_abg2_k#ims_abg_tvector if cc, grand post
marginsplot, x(ims_abg_tvector) legend(pos(3))


exit
bys m0: tab ims_c2_k ims_tvector
tabstat ims_c2, by(_mi_m) s(n mean sd min q max) format(%9.3g)
tabstat ims_c_traj, by(_mi_m) s(n mean sd min q max) format(%9.3g)
tabstat ims_tvector, by(_mi_m) s(n mean sd min q max) format(%9.3g)
tabstat ims_c2_k, by(_mi_m) s(n mean sd min q max) format(%9.3g)



mi estimate, saving(../data/estimates/traj_grid, replace): ///
	logistic dead28 age_c sex i.dx_cat ib1.ims_c2_k##ib1.ims_tvector

* // back to the original tclass version
* mi estimate, saving(../data/estimates/traj_grid, replace): ///
* 	logistic dead28 age_c sex i.dx_cat ib5.tclass
est store mi_traj_grid

est restore mi_traj_grid
est describe
global mi_est_cmdline `=r(cmdline)'

// hack to get margins to work via mi command
// via http://bit.ly/10CEKNU
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
	margins ims_c2_k#ims_tvector, atmeans post
end
mi estimate, cmdok: emargins 1
mat b = e(b_mi)
mat V = e(V_mi)
qui $mi_est_cmdline if m0
qui margins ims_c2_k#ims_tvector, atmeans
myret
mata: st_global("e(cmd)", "margins")
marginsplot, x(ims_c2_k)
marginsplot, x(ims_tvector)

/* within mid-range only */
logistic dead28 age_c sex i.dx_cat c.ims_c2 c.ims_c_traj##c.ims_c_traj ///
	if ims_c2_k == 2 & m0

/*
NOTE: 2013-04-07 - using `if` with MI means the estimation sample will vary
Stata will not allow this to happen unless you force it to do so with esampvaryok
*/
mi estimate, esampvaryok esample(esample) ///
	saving(../data/estimates/traj_grid, replace): ///
	logistic dead28 age_c sex i.dx_cat c.ims_c2 c.ims_c_traj##c.ims_c_traj ///
	if ims_c2_k == 2

est store mi_traj_grid

est restore mi_traj_grid
est describe
global mi_est_cmdline `=r(cmdline)'

**************************************************
/* HACK TO GET MARGINS TO WORK AFTER MI COMMAND */
// via http://bit.ly/10CEKNU

/* First specify the margins command HERE */
global margins_cmd "margins, at(ims_c_traj = (-10(2)10))"
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
mi estimate, cmdok esampvaryok: emargins 1
mat b = e(b_mi)
mat V = e(V_mi)
if strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline & m0
if !strpos("$mi_est_cmdline"," if ") qui $mi_est_cmdline if m0
qui $margins_cmd
myret
mata: st_global("e(cmd)", "margins")
marginsplot, x(ims_c_traj)

cap log close
