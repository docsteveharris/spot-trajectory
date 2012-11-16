xi: fracpoly, compare: logistic dead28 pf_traj pf2 age  i.dx_cat
est store d28_f_pf
fracplot if pf_traj > -50 & pf_traj < 50, msym(p) name(pf_traj_d28, replace)
