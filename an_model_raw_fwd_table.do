*  ============================================================
*  = Produce table following full run of an_model_raw_fwd.do =
*  ============================================================

/*
Created 	130622

Changes
130623 - converted to work with fwd version of data


Table design
- one parameter per row
- then report in columns the estimate for the ICU admission value 
	and the pre-admission trajectory
- work just within MI data? since this is invite comparisons across variables

*/

clear
global table_name model_fwd_monly
use ../outputs/tables/model_fwd_monly.dta
count

// flag cc and mi rows
gen mi = substr(idstr, 1 , 2) == "mi"
gen cc = substr(idstr, 1 , 2) == "cc"

// extract var
gen var = substr(idstr, 4, .)
order idnum mi cc var

// drop cc estimates and age and ims_other
drop if cc == 1
drop if strpos(parm, "age_c")
drop if strpos(parm, "ims_other")

// drop gcs
drop if var == "gcs"

// reshape wide
drop mi cc z dof t
gen wide = .
replace wide = 1 if strpos(parm,"1")
replace wide = 2 if strpos(parm,"traj")
reshape wide estimate stderr p stars min95 max95 parm label, i(idnum) j(wide)


// so estimate1 = ICU admission, estimate2 = pre-admission traj

// prep table
gen varname = parm1
replace varname = "ims_ms1" if varname == "ims_ms1"
include mt_Programs.do
gen var_level = .
spot_label_table_vars

global table_order ///
	ims_c1 ///
	ims_ms1 ///
    gap_here ///
	hr1 ///
	bps1 ///
	temp1 ///
	rr1 ///
	pf1 ///
	ph1 ///
	urea1 ///
	cr1 ///
	na1 ///
	urin1 ///
	wcc1 ///
    gap_here ///
	plat1 ///
	lac1 ///


// number the gaps
local i = 1
local table_order
foreach word of global table_order {
    if "`word'" == "gap_here" {
        local w `word'_`i'
        local ++i
    }
    else {
        local w `word'
    }
    local table_order `table_order' `w'
}
global table_order `table_order'

mt_table_order
sort table_order
order table_order tablerowlabel varname label1 estimate1 min951 max951 p1 estimate2 min952 max952 p2

// format
forvalues i = 1/2 {
	gen est_raw_`i' = estimate`i'
	sdecode estimate`i', format(%9.3fc) replace
	sdecode min95`i', format(%9.3fc) replace
	sdecode max95`i', format(%9.3fc) replace
	replace stars`i' = "\textsuperscript{" + stars`i' + "}"
	* replace estimate`i' = estimate`i' + stars`i'
	* replace estimate`i' = "" if est_raw_`i' == .
	gen vbracket`i' = "(" + min95`i' + "--" + max95`i' + ")" 
	sdecode p`i', format(%9.3fc) replace
	replace p`i' = "<0.001" if p`i' == "0.000"
}

* Append units
cap confirm string var unitlabel
if _rc {
    tostring unitlabel, replace
    replace unitlabel = "" if unitlabel == "."
}
replace unitlabel = "point" if varname == "ims_c1"
replace unitlabel = "point" if varname == "ims_ms1"
replace unitlabel = "unit" if varname == "ph1"
gen unit_change = "per 1 " + unitlabel
order tablerowlabel unit_change

ingap 3 14


replace tablerowlabel = "ICNARC APS (complete)" if varname == "ims_c1"
replace tablerowlabel = "ICNARC APS (partial)" if varname == "ims_ms1"

// now send the table to latex
local cols tablerowlabel unit_change estimate1 vbracket1 p1 estimate2 vbracket2 p2
order `cols'

local super_heading "&&  \multicolumn{3}{c}{Ward assessment value} & \multicolumn{3}{c}{Pre-admission trajectory} \\"
local h1 "& Unit change & OR & 95\%CI & p & OR & 95\%CI & p\\ "

* CHANGED: 2013-05-14 - decimally aligned column
* local zcol "\newcolumntype Z{X[-1m]{S[tight-spacing = true,round-mode=places,round-precision=2]}}"
local justify X[5rm]X[2lm] X[rm]X[2lm]X[rm] X[rm]X[2lm]X[rm]
local tablefontsize "\scriptsize"
local taburowcolors 2{white .. white}

listtab `cols' ///
	using ../outputs/tables/$table_name.tex, ///
	replace  ///
	begin("") delimiter("&") end(`"\\"') ///
	headlines( ///
		"`tablefontsize'" ///
		"\renewcommand{\arraystretch}{`arraystretch'}" ///
		"\taburowcolors `taburowcolors'" ///
		"`zcol'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`super_heading'" ///
		"\cmidrule(lr){3-5}" ///
		"\cmidrule(lr){6-8}" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu}  " ///
		"\label{tab:$table_name} ") 



