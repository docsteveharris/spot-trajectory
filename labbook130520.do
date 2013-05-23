*  =============================================================
*  = Produce comparative table of trajectory in raw physiology =
*  =============================================================
/*
So rows will be parameters
with one col for complete cases and another for MI
Keep the variables paired (current value and trajectory then easy to scan down and compare)
*/

use ../outputs/tables/$table_name.dta, clear
drop max95 dof t
cap drop mi
gen mi = strpos(idstr, "mi")
order mi
encode parm, gen(parm_code)
reshape wide idnum idstr parm label estimate stderr z p stars, i(parm_code) j(mi)

/* Now you have the complete cases on the LEFT and the MI data on the RIGHT */



exit
eclplot estimate min95 max95 id ///
	, ///
	horizontal ///
	rplottype(rspike) ///
	estopts(msymbol(D)) ///
	nociforeground ///
	xscale(noextend) ///
	xlab(0(1)2, format(%9.1f)) ///
	xtitle("Mean change in ICNARC Acute Physiology Score" ///
			"when ICU has no beds at the time of the ward assessment") ///
	xline(1, lpattern(dot) lcolor(black) ) ///
	yscale(noextend) ///
	ytitle("") ///
	xsize(8) ysize(4)


exit

*  ======================
*  = Now produce tables =
*  ======================

use ../data/scratch/scratch.dta, clear
cap drop model_sequence
gen model_sequence = .
replace model_sequence = 1 if strpos(idstr, "univariate")
replace model_sequence = 2 if strpos(idstr, "no_frailty")
replace model_sequence = 3 if strpos(idstr, "time_dependent")
replace model_sequence = 4 if strpos(idstr, "full_frailty")

ren es_1 theta_est
ren es_2 theta_se

// convert to wide
tempfile working 2merge
cap restore, not
preserve
local wide_vars estimate stderr z p stars min95 max95 theta_est theta_se theta_chi2
forvalues i = 1/4 {
	keep parm model_sequence `wide_vars'
	keep if model_sequence == `i'
	foreach name in `wide_vars' {
		rename `name' `name'_`i'
	}
	save `2merge', replace
	if `i' == 1 {
		save `working', replace
	}
	else {
		use `working', clear
		merge 1:1 parm using `2merge'
		drop _merge
		save `working', replace
	}
	restore
	preserve

}
restore, not
use `working', clear
qui include mt_Programs.do
mt_extract_varname_from_parm
order model_sequence varname var_level

// hand label the time-varying interaction
replace var_level = "0" if strpos(var_level, "0")
replace var_level = "1" if strpos(var_level, "1")
replace var_level = "3" if strpos(var_level, "3")
replace var_level = "7" if strpos(var_level, "7")
destring var_level, replace
replace varname = "icnarc0_timev" if strpos(varname, "tb#c")
// label the vars
spot_label_table_vars
replace tablerowlabel = "\textit{--- with modifier of Day 0 effect}" if varname == "icnarc0_timev"

// replace var_level_lab = "Days 0 effect"  if varname == "icnarc0_timev" & var_level == 0
replace var_level_lab = "Days 1--2"  if varname == "icnarc0_timev" & var_level == 1
replace var_level_lab = "Days 3--7"  if varname == "icnarc0_timev" & var_level == 3
replace var_level_lab = "Days 8+" if varname == "icnarc0_timev" & var_level == 7

order tablerowlabel var_level_lab
// add in blank line as ref category for ccot_shift_pattern

global table_order ///
	hes_overnight ///
	hes_emergx ///
	cmp_beds_max ///
	patients_perhesadmx ///
	ccot_shift_pattern ///
	gap_here ///
	out_of_hours ///
	weekend ///
	decjanfeb ///
	gap_here ///
	age ///
	male ///
	sepsis_dx ///
	delayed_referral ///
	v_ccmds ///
	icnarc0 ///
	icnarc0_timev

mt_table_order
sort table_order var_level

forvalues i = 1/4 {
	gen est_raw_`i' = estimate_`i'
	sdecode estimate_`i', format(%9.2fc) replace
	replace stars_`i' = "\textsuperscript{" + stars_`i' + "}"
	replace estimate_`i' = estimate_`i' + stars_`i'
	// replace reference categories
	replace estimate_`i' = "" if est_raw_`i' == .
	replace estimate_`i' = "--" if varname == "ccot_shift_pattern" & var_level == 3
	replace estimate_`i' = "--" if varname == "sepsis_dx" & var_level == 0
	replace estimate_`i' = "--" if varname == "v_ccmds" & var_level == 1
	replace estimate_`i' = "" if varname == "icnarc0_timev" & var_level == 0
}

// indent categorical variables
mt_indent_categorical_vars

// Other headings
ingap 1 10 13 27
replace tablerowlabel = "\textit{Site parameters}" if _n == 1
replace tablerowlabel = "\textit{Timng parameters}" if _n == 11
replace tablerowlabel = "\textit{Patient parameters}" if _n == 15
ingap 11 15

*  =====================
*  = Comparative table =
*  =====================
// now prepare footers with site level variability
qui su theta_est_4, meanonly
local f = r(mean)
qui su theta_chi2_4, meanonly
local theta_p = chi2tail(1,`=r(mean)')/2
if `theta_p' < 0.001 local theta_stars = "***"
local frailty: di %9.3fc `f'
local frailty "`frailty'\textsuperscript{`theta_stars'}"
local frailty = subinstr("`frailty'", " ", "",.)
local f1 "Frailty &  &  & & `frailty'  \\"
di "`f1'"

local cols tablerowlabel estimate_1 estimate_2 estimate_3 estimate_4
order `cols'

global table_name ward_survival_all
local super_heading "& \multicolumn{4}{c}{Hazard ratio} \\"
local h1 "& Uni-variate & Multi-variate & Time-varying & Frailty \\ "
local justify X[6l]XXXX
local tablefontsize "\footnotesize"
local taburowcolors 2{white .. white}

listtab `cols' ///
	using ../outputs/tables/$table_name.tex, ///
	replace  ///
	begin("") delimiter("&") end(`"\\"') ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`super_heading'" ///
		"\cmidrule(r){2-5}" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\midrule" ///
		"`f1'" ///
		"\bottomrule" ///
		"\end{tabu}  " ///
		"\label{tab: $table_name} ")



*  ==========================
*  = Final best model table =
*  ==========================
gen estimate = est_raw_4
gen min95 = min95_4
gen max95 = max95_4
gen p = p_4

sdecode estimate, format(%9.2fc) gen(est)
sdecode min95, format(%9.2fc) replace
sdecode max95, format(%9.2fc) replace
sdecode p, format(%9.3fc) replace
replace p = "<0.001" if p == "0.000"
gen est_ci95 = "(" + min95 + "--" + max95 + ")" if !missing(min95, max95)
replace est = "--" if reference_cat == 1
replace est_ci95 = "" if reference_cat == 1
replace est = "" if varname == "icnarc0_timev" & var_level == 0

// now prepare footers with site level variability
qui su theta_est_4, meanonly
local f = r(mean)
qui su theta_chi2_4, meanonly
local theta_p = chi2tail(1,`=r(mean)')/2
local theta_p: di %9.3fc `theta_p'
local theta_p = subinstr("`theta_p'", " ", "",.)
if `theta_p' < 0.001 local theta_p = "<0.001"
local frailty: di %9.3fc `f'
local frailty "`frailty'"
local frailty = subinstr("`frailty'", " ", "",.)
local f1 "\multicolumn{4}{r}{Frailty `frailty' $(p`theta_p')$}  \\"
di "`f1'"

* now write the table to latex
order tablerowlabel var_level_lab est est_ci95 p
local cols tablerowlabel est est_ci95 p
order `cols'
cap br

global table_name ward_survival_final
local h1 "Parameter & Odds ratio & (95\% CI) & p \\ "
local justify lrlr
* local justify X[5l] X[1l] X[2l] X[1r]
local tablefontsize "\scriptsize"
local arraystretch 1.0
local taburowcolors 2{white .. white}

listtab `cols' ///
	using ../outputs/tables/$table_name.tex, ///
	replace  ///
	begin("") delimiter("&") end(`"\\"') ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\taburowcolors `taburowcolors'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\midrule" ///
		"`f1'" ///
		"\bottomrule" ///
		"\end{tabu}  " ///
		"\label{tab: $table_name} ")

*  =====================================
*  = Now inspect importance of frailty =
*  =====================================
est restore full3
est replay full3

* predict the random effects
cap drop site_re
predict site_re, effects
gsort +site_re
list icode dorisname site_re in 1/10
* NOTE: 2013-02-03 - musgrove park: best effect
gsort -site_re
list icode dorisname site_re in 1/10
* NOTE: 2013-02-03 - tameside worst effect

*  ======================================
*  = Plot the baseline survival frailty =
*  ======================================
cap restore, not
preserve

su site_re
local site_re_min = r(min)
local site_re_max = r(max)
stcurve, survival ///
 	outfile(../data/scratch/base_survival, replace)
use ../data/scratch/base_survival, clear
duplicates drop surv1 _t, force
rename surv1 base_surv_est
gen base_surv_max = base_surv_est^(exp(`site_re_max'))
gen base_surv_min = base_surv_est^(exp(`site_re_min'))

* Manually create the graph: beware 60k data points so draws very slowly
line base_surv_min base_surv_est base_surv_max _t ///
	, ///
	sort c(J J J) ///
	ylab(0(0.25)1, format(%9.2f) nogrid) ///
	yscale(noextend) ///
	ytitle("Survival (proportion)") ///
	xlab(0(7)28) ///
	xscale(noextend) ///
	xtitle("Days following assessment") ///
	legend( ///
		label(1 "Best site") ///
		label(2 "Mean survival") ///
		label(3 "Worst site") ///
		cols(1) position(4) ring(0) ///
		)
graph rename survival_reffects, replace
graph export ../outputs/figures/survival_reffects.pdf, ///
	name(survival_reffects) ///
	replace

restore


*  ================================
*  = Now draw the baseline hazard =
*  ================================
cap restore, not
preserve

su site_re
local site_re_min = r(min)
local site_re_max = r(max)
stcurve, hazard kernel(gaussian) ///
 	outfile(../data/scratch/base_hazard, replace)
use ../data/scratch/base_hazard, clear
rename haz1 base_haz_est
label var base_haz_est "Mean frailty hazard"
gen base_haz_min = base_haz_est * (exp(`site_re_min'))
gen base_haz_max = base_haz_est * (exp(`site_re_max'))

line base_haz_min base_haz_est base_haz_max _t ///
	, ///
	sort c(l l l) ///
	ylab(, format(%9.2f) nogrid) ///
	yscale(noextend) ///
	ytitle("Hazard rate" "(Deaths per site per day)") ///
	xlab(0(7)28) ///
	xscale(noextend) ///
	xtitle("Days following assessment") ///
	legend( ///
		order(3 2 1) ///
		label(1 "Best site") ///
		label(2 "Mean frailty hazard") ///
		label(3 "Worst site") ///
		cols(1) position(2) ring(0) ///
		)

graph rename survival_reffects_bhaz, replace
graph export ../outputs/figures/survival_reffects_bhaz.pdf, ///
	name(survival_reffects_bhaz) ///
	replace

restore

