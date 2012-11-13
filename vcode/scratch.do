foreach var of varlist dx_pneum_u dx_pneum_b dx_sepshock dx_acpanc dx_arf {
	preserve
	d `var'
	keep if `var'
	stcox dead28 traj_1 traj_2 age ims2 i.dx_cat, nolog noshow
	est store cox_f_t
	stcox dead28 age ims2 i.dx_cat if _est_cox_f_t, nolog noshow
	est store cox_f
	lrtest cox_f cox_f_t
	est table cox*, b(%9.3f) star newpanel stats(N ll aic bic)
	restore
}
