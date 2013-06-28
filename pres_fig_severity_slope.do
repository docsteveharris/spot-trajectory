*  ====================================
*  = SCRATCH VERSION FOR PRESENTATION =
*  ====================================

*  =======================================
*  = Slope graph of ward vs ICU severity =
*  =======================================

/*
created:	130402
modified:	130402

Create a slope graph using the ICNARC model weights
	- ward weights on the left
	- ICU weights on the right

Run twice
	- once with ICNARC partial
	- once with ICNARC complete

Assumptions
	- work only with patients admitted within 24 hrs

You will need to define in advance the population.
Otherwise the comparison will be between different populations - not different variables.
The idea is to quickly understand *what* is changing around the time of admission.

*/

use ../data/working_postflight.dta, clear
keep if time2icu < 24


keep if ims1_miss == 0 & ims2_miss == 0
global population complete
qui count
local n: di %9.0fc `=r(N)'
local n = trim("`n'")
global title "`n' patients with complete physiology"
local vars hr bps temp rr urea cr na wcc pf gcs urin ph
* CHANGED: 2013-04-16 - drop GCS because flat
local vars hr bps temp rr urea cr na wcc pf urin ph
keep id *1_wt *2_wt 



// set up labels for graph
gen label_text = ""
replace label_text = "Sodium" if varname == "na"
replace label_text = "White cell count" if varname == "wcc"
replace label_text = "Systolic BP" if varname == "bps"
replace label_text = "Temperature" if varname == "temp"
replace label_text = "Urea" if varname == "urea"
replace label_text = "Creatinine" if varname == "cr"
replace label_text = "Respiratory rate" if varname == "rr"
replace label_text = "Heart rate" if varname == "hr"
replace label_text = "pH" if varname == "ph"
replace label_text = "gcs" if varname == "GCS"
replace label_text = "P:F ratio" if varname == "pf"
replace label_text = "Urine output" if varname == "urin"

// draw the slope graph
set scheme shbw
cap drop one zero
gen one = 1
gen zero = 0
cap drop wt_mean_text
sdecode wt_mean, format(%9.1fc) generate(wt_mean_text)
cap drop mlabel
gen mlabel =  label_text + " (" + wt_mean_text + ")"

cap drop pos
gen pos = .
replace pos = 9 if time == 0
replace pos = 3 if time == 1

// try and handle labels over-writing by altering the label position
// pos_gap is a variable that controls how close two labels must be before the position is changed
// it can only handle a series of 3 overlapping labels
// the first is assigned up a clock position
// the second is assigned down a clock positon
global pos_gap 0.05
local pos_gap $pos_gap
bys time (wt_mean): replace pos = pos + 1 ///
	if abs(wt_mean[_n] - wt_mean[_n+1]) < `pos_gap' ///
	& pos[_n] == pos[_n+1]
bys time (wt_mean): replace pos = pos - 1 ///
	if abs(wt_mean[_n] - wt_mean[_n-1]) < `pos_gap' ///
	& pos[_n] == pos[_n-1]

order time parm wt_mean pos
qui su parm
local max = r(max)
local plots  ""
forvalues i = 1/`max' {
	qui count if parm == `i'
	if r(N) != 2 continue
	qui su traj if parm == `i', meanonly
	if `=r(mean)' < 0 local lcolor green
	if `=r(mean)' >= 0 local lcolor red
	local plot  "(line wt_mean time if parm == `i', lpattern(solid) lwidth(thick) lcolor(`lcolor') )"
	local plots  "`plots' `plot'"
}
di "`plots'"

qui su wt_mean
local ymax = round(r(max))
local sidemargin 33

* Customise postion of labels that overlap
clonevar mlabel_copy = mlabel
gen lab_height = wt_mean
* Repostion HR label
replace mlabel = "" if time == 0 & varname == "hr"
replace lab_height = lab_height - 0.08 if time == 0 & varname == "hr"
local hr0label (scatter lab_height zero if time == 0 & varname == "hr" ///
	, mlabel(mlabel_copy) mlabsize(medsmall) mlabpos(9) msymbol(none))
* Repostion pH label
replace mlabel = "" if time == 0 & varname == "ph"
replace lab_height = lab_height - 0.04 if time == 0 & varname == "ph"
local ph0label (scatter lab_height zero if time == 0 & varname == "ph" ///
	, mlabel(mlabel_copy) mlabsize(medsmall) mlabpos(9) msymbol(none))

tw `plots' ///
	`hr0label' ///
	`ph0label' ///
	(scatter wt_mean zero if time == 0, ///
		mlabel(mlabel) msymbol(o) ///
		mlabsize(medsmall) ///
		mlabv(pos) ///
		) ///
	(scatter wt_mean one if time == 1, ///
		mlabel(mlabel) msymbol(o) ///
		mlabsize(medsmall) ///
		mlabv(pos) ///
		) ///
	, ///
	yscale(noextend off) ///
	ylab(0/`ymax') ///
	xlab(0 1) ///
	xscale(noextend off) ///
	legend(off) ///
	plotregion(margin(l=`sidemargin' r=`sidemargin')) ///
	ysize(6) xsize(4) ///
	text(0 0 "Ward", size(large) placement(9) justification(right)) ///
	text(0 1 "ICU", size(large) placement(3) justification(left)) ///
	title("($title)", position(6) size(small))


graph rename slope_$population, replace

graph display slope_$population


graph export ../outputs/figures/pres_severity_slope.pdf ///
    , name(slope_$population) replace

