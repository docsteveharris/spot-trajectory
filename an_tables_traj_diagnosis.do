*  ==============================================
*  = Table of diagnoses among patients admitted =
*  ==============================================

use ../data/working_postflight.dta, clear
cap drop __*
count
icmsplit raicu1
icm raicu1, gen(diagcode1) desc ap2 replace

contract desc
drop if missing(desc)
gsort - _freq
keep in 1/50
gen rank = _n

egen percent = total(_freq)
replace percent = round(_freq / percent * 100,0.1)
sdecode _freq, format(%9.0gc) replace
sdecode percent, format(%9.1fc) replace ///
	prefix("(") suffix(")")

local vars rank desc _freq percent
chardef `vars', ///
	char(varname) ///
	values( ///
		"Rank" ///
		"Primary reason for ICU admission" ///
		"Number" ///
		"(\%)" ///
		)

listtab_vars `vars', ///
	begin("") delimiter("&") end(`"\\"') ///
	substitute(char varname) ///
	local(h1)

global table_name traj_diagnosis_50
local justify llrl
local tablefontsize "\tiny"
* local arraystretch 1.0
* local taburowcolors 2{white .. gray90}
/*
NOTE: 2013-01-28 - needed in the pre-amble for colors
\usepackage[usenames,dvipsnames,svgnames,table]{xcolor}
\definecolor{gray90}{gray}{0.9}
*/

listtab `vars' ///
	using ../outputs/tables/$table_name.tex, ///
	replace rstyle(tabular) ///
	headlines( ///
		"`tablefontsize'" ///
		"\begin{tabu} spread " ///
		"\textwidth {`justify'}" ///
		"\toprule" ///
		"`h1'" ///
		"\midrule" ) ///
	footlines( ///
		"\bottomrule" ///
		"\end{tabu}  " ///
		"\label{$table_name} " ///
		"\normalsize" ) 




