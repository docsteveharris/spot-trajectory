*  ==================================================
*  = Present diagnostic rankings by sepsis category =
*  ==================================================

// data from spot_traj
global pos_gap 0.1
global keep_this_many 5

use ../data/working_postflight.dta, clear

icmsplit raicu1
icm raicu1, gen(diagcode1) desc ap2 replace

gen sepsis_split = 0 if inlist(sepsis,1)
replace sepsis_split = 1 if inlist(sepsis,4)
drop if sepsis_split == .
tab sepsis_split
forvalues i = 0/1 {
	count if sepsis_split == `i'
	tempvar q
	gen `q' = r(N)
	sdecode `q', format(%9.0fc) replace
	global title`i' = "(n = " + `q'[1] + ")"
}

global population sepsis_very



contract desc sepsis_split
drop if missing(desc)
gsort - _freq
cap drop freq_max
bys sepsis_split: egen freq_max = max(_freq)
cap drop freq_inv
gen freq_inv = freq_max - _freq
cap drop rank
bys sepsis_split (freq_inv desc): gen rank = _n
bys sepsis_split: egen percent = total(_freq)
replace percent = round(_freq / percent * 100,0.1)

// keep top 5 diagnoses over-all and for your site
keep if rank <= $keep_this_many
cap drop diagnosis
encode desc, gen(diagnosis)

// reshape long
// merge on trajectories

// draw the slope graph
set scheme shbw
cap drop one zero

gen one = 1
gen zero = 0
cap drop pct_text
sdecode percent, format(%9.1fc) generate(pct_text)
cap drop mlabel
gen mlabel =  desc + " (" + pct_text + "%)"


// now work out the scale and the risk of over-writing
qui su percent
local mmax = r(max)
local mmin = r(min)
local rrange = `mmax' - `mmin'
di `rrange'
local mingap =`rrange'/16
di `mingap'
// will need to repeat this definition via a for loop
cap drop column
egen column = group(sepsis_split)
gsort column -percent
local current_pos 1
qui su column
local last_column = r(max)
tempfile working results
save `working', replace
forvalues column = 1/`last_column' {
	use `working', clear
	keep if column == `column'
	local current_pos = 1
	local end = _N
	di `end'
	cap drop label_stack
	gen label_stack = ""
	cap drop tooclose
	gen tooclose = 0
	forvalues i = 1/`end' {
		if `current_pos' > `i' continue
		local obslist
		local this_gap = abs(percent[`i'] - percent[`i' + 1])
		if `this_gap' < `mingap' {
			local j = `i'
			di "i: `i': `this_gap'"
			local obslist `i'
			while `this_gap' < `mingap' {
				local ++j
				local obslist  `obslist' `j'
				local this_gap = abs(percent[`j'] - percent[`j' + 1])
				di "j: `j': `this_gap'"
				di "`obslist'"
			}
			local current_pos = `j'
			di "`obslist'"
			// now you have a list of obs that need merging into a single label
			if "`obslist'" != "" {
				local new_label
				foreach ob of local obslist {
					replace tooclose = 1 if _n == `ob'
					local l = mlabel[`ob']
					local new_label = `" `new_label' "`l'"  "'
				}
				replace label_stack = trim(`" `new_label' "') if tooclose == 1 & label_stack == ""
			}
		}
	}
	if `column' == 1 {
		save `results', replace
	}
	else {
		append using `results'
		save `results', replace
	}
}
compress
sort column percent
replace label_stack = `" ""' + mlabel + `"" "' if missing(label_stack)
forvalues i = 1/`=_N' {
	replace label_stack = "" if label_stack[`i'] == label_stack[`i'+1] & _n == `i'

}
global textlabels
forvalues i = 1/`=_N' {
	if label_stack[`i'] == "" continue
	local label_size small
	local l = label_stack[`i']
	local x = sepsis_split[`i']
	local y = percent[`i']
	if `x' == 0 {
		local options "place(w) just(right) size(`label_size') margin(l=0 r=2 b=1 t=1)"
	}
	if `x' == 1 {
		local options "place(e) just(left) size(`label_size') margin(l=2 r=0 b=1 t=1)"
	}
	local new_text `"text(`y' `x' `l',`options' ) "'
	global textlabels `" $textlabels `new_text' "'
}
di `"$textlabels"'

order sepsis_split desc percent 
local plots  ""
levelsof diagnosis, local(parms) clean
// colour code slopes - commented out for now
foreach i of local parms {
	qui count if diagnosis == `i'
	if r(N) != 2 {
		local plot  "(scatter percent sepsis_split if diagnosis == `i', msymbol(o) mcolor(black) msize(small))"
	}
	else {
		local lcolor black
		local lwidth medthin
		local plot  "(connected percent sepsis_split if diagnosis == `i', lpattern(solid) lwidth(`lwidth') lcolor(`lcolor') msymbol(o) mcolor(black) msize(small))"
	}
	local plots  "`plots' `plot'"
}
di "`plots'"


qui su percent
local ymax = round(r(max))
local sidemargin "margin(l=70 r=70)"
tw `plots' ///
	, ///
	$textlabels ///
	yscale(noextend off) ///
	ylab(0/`ymax') ///
	xlab(0 1) ///
	xscale(noextend off) ///
	legend(off) ///
	plotregion(lcolor(gs12) lstyle(solid) lpattern(blank) `sidemargin') ///
	ysize(5) xsize(8) ///
	text(0 0 "{bf:Very unlikely}" "$title0", size(medsmall) placement(9) justification(right)) ///
	text(0 1 "{bf:Very likely}" "$title1", size(medsmall) placement(3) justification(left))


graph rename sepsis_split, replace


graph rename sepsis_split, replace
graph display sepsis_split
graph export ../outputs/figures/sepsis_split.pdf ///
    , name(sepsis_split) replace


