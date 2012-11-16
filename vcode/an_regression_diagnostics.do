 * ==========================
 * = Regression diagnostics =
 * ==========================
 /* Holding file .. you need to work this up into a more formal approach */

/* Regression diagnostics */
* TODO: 2012-11-13 - need to factor out this work so can be used more generically
cap drop regdx_*
predict regdx_dbeta, dbeta
label var regdx_dbeta "Influence"
predict regdx_dx2, dx2
sum regdx_dx2 regdx_dbeta
/* gsort without the mfirst option keeps the missing values at the end */
gsort -regdx_dx2
list id dead28 yhat_c ims2 regdx_dx2 regdx_dbeta if regdx_dx2 != . in 1/10
cap drop id_flag
gen id_flag = _n
label var id_flag "Flag records as per sort order"
label var regdx_dx2 "Change in Pearson chi-squared"
twoway 	(scatter regdx_dx2 yhat_c if id_flag <= 10, ///
		msym(i) mlab(id) mlabsize(small)) ///
		(scatter regdx_dx2 yhat_c  [aweight = regdx_dbeta], msym(oh) ///
		 name(d28_ims2_regex_dx2, replace))

predict regdx_ddev, ddeviance
sum regdx_ddev, d


label var regdx_ddev "Change in deviance"
sum regdx_ddev, d
* list id dead28 yhat_c ims2 regdx_ddev if regdx_ddev > `r(p95)' & regdx_ddev != .
twoway 	(scatter regdx_ddev yhat_c, msym(i) mlab(id) mlabsize(small)) ///
		(scatter regdx_ddev yhat_c  [aweight = regdx_dbeta], msym(oh) ///
		 name(d28_ims2_regex_dx2, replace))

