*  ==========================================================================================
*  = Summary table to compare the different populations within which you discuss trajectory =
*  ==========================================================================================

GenericSetupSteveHarris spot_traj an_tables_traj_compare_pops, logon
global table_name traj_compare_pops

/*
created:    130402
modified:   130402
byvar set-up does not work with overlapping populations
so the multiple table creation is modified
*/

local clean_run 1
if `clean_run' == 1 {
    clear
    use ../data/working.dta
    qui include cr_preflight.do
}

use ../data/working_postflight.dta, clear

*  ======================================
*  = Define column categories or byvars =
*  ======================================
* NOTE: 2013-02-07 - dummy variable for the byvar loop that forces use of all patients
cap drop by_all_patients
gen by_all_patients = 1
* NOTE: 2013-02-07 - label this value to create super-category label
label define by_all_patients 1 "All patients"
label values by_all_patients by_all_patients

local byvar by_all_patients
* Think of these as the gap row headings
local super_vars sepsis cardiovascular respiratory ///
    renal neurological laboratory

local sepsis temp2 wcc2
local cardiovascular hr2 bps2 ph2 lac2
local respiratory rr2 pf2
local renal na2 urea2 cr2 urin2
local neurological gcs2
local laboratory plat2

* This is the layout of your table by sections
local table_vars ///
    age sex yulosd dead28 ///
    `sepsis' ///
    `cardiovascular' ///
    `respiratory' ///
    `renal' ///
    `neurological' ///
    `laboratory'

* Specify the type of variable
local norm_vars age
local skew_vars wcc2 ph2 lac2 rr2 pf2 urea2 cr2 urin2 gcs2 plat2 temp2 hr2 bps2 na2 yulosd
local range_vars
local bin_vars
local cat_vars sex dead28

*  ==============================
*  = Set up sparkline variables =
*  ==============================
* sparks = number of bars
local sparks 12
* sparkwidth = number of x widths for sparkline plot
local sparkwidth 8
global sparkspike_width 1.5
local sparkspike_vars ///
    `skew_vars' age yulosd

* Use fat 2 point sparkline for horizontal bars (default 0.2pt)
local sparkhbar_width 3pt
local sparkhbar_vars sex dead28


* CHANGED: 2013-02-05 - use the gap_here indicator to add gaps
* these need to be numbered as _1 etc
* Define the order of vars in the table
global table_order ///
    age sex ///
    gap_here ///
    temp2 wcc2 ///
    hr2 bps2 ph2 lac2 ///
    rr2 pf2 ///
    na2 urea2 cr2 urin2 ///
    gcs2 ///
    plat2 ///
    gap_here ///
    yulosd dead28

* number the gaps
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

tempname pname
tempfile pfile
postfile `pname' ///
    int     bylevel ///
    int     table_order ///
    str32   var_type ///
    str32   var_super ///
    str32   varname ///
    str96   varlabel ///
    str64   var_sub ///
    int     var_level ///
    double  vcentral ///
    double  vmin ///
    double  vmax ///
    double  vother ///
    int     vmiss ///
    int     vcount ///
    str244  sparkspike ///
    using `pfile' , replace


tempfile working
save `working', replace

levelsof `byvar', clean local(bylevels)
local pops iif_lac iif_ims_c iif_ims_ms
local lvl = 0
foreach pop of local pops {
// foreach lvl of local bylevels {
    local ++lvl
    use `working', clear
    keep $`pop'
    // local lvl_label: label (`byvar') `lvl'
    if "`pop'" == "iif_lac" local lvl_label "Lactate trajectory"
    if "`pop'" == "iif_ims_c" local lvl_label "Complete physiology trajectory"
    if "`pop'" == "iif_ims_ms" local lvl_label "Partial physiology trajectory"
    local lvl_labels `lvl_labels' `lvl_label'
    count
    local grp_sizes `grp_sizes' `=r(N)'
    local table_order 1
    local sparkspike = ""
    foreach var of local table_vars {
        local varname `var'
        local varlabel: variable label `var'
        local var_sub
        count
        local vcount = r(N)
        count if missing(`var')
        local vmiss = r(N)
        // CHANGED: 2013-02-05 - in theory you should not have negative value labels
        local var_level -1
        // Little routine to pull the super category
        local super_var_counter = 1
        foreach super_var of local super_vars {
            local check_in_super: list posof "`var'" in `super_var'
            if `check_in_super' {
                local var_super: word `super_var_counter' of `super_vars'
                continue, break
            }
            local var_super
            local super_var_counter = `super_var_counter' + 1
        }

        // Now assign values base on the type of variable
        local check_in_list: list posof "`var'" in norm_vars
        if `check_in_list' > 0 {
            local var_type  = "Normal"
            su `var'
            local vcentral  = r(mean)
            local vmin      = .
            local vmax      = .
            local vother    = r(sd)
        }

        local check_in_list: list posof "`var'" in bin_vars
        if `check_in_list' > 0 {
            local var_type  = "Binary"
            count if `var' == 1
            local vcentral  = r(N)
            local vmin      = .
            local vmax      = .
            su `var'
            local vother    = r(mean) * 100
            // sparkhbar routine
            local check_in_list: list posof "`var'" in sparkhbar_vars
            if `check_in_list' > 0 {
                local x : di %9.2f `=r(mean)'
                local x = trim("`x'")
                local sparkspike "\setlength{\sparklinethickness}{`sparkhbar_width'}\begin{sparkline}{`sparkwidth'}\spark 0.0 0.5 `x' 0.5 / \end{sparkline}\setlength{\sparklinethickness}{0.2pt}"
            }
        }

        local check_in_list: list posof "`var'" in skew_vars
        if `check_in_list' > 0 {
            local var_type  = "Skewed"
            su `var', d
            local vcentral  = r(p50)
            local vmin      = r(p25)
            local vmax      = r(p75)
            local vother    = .
        }

        local check_in_list: list posof "`var'" in range_vars
        if `check_in_list' > 0 {
            local var_type  = "Skewed"
            su `var', d
            local vcentral  = r(p50)
            local vmin      = r(min)
            local vmax      = r(max)
            local vother    = .
        }


        // sparkspike routine
        local check_in_list: list posof "`var'" in sparkspike_vars
        if `check_in_list' > 0 {
            local sparkspike = ""
            cap drop kd kx kx20 kdmedian
            kdensity `var', gen(kx kd) nograph
            // normalise over the [0,1] scale
            qui su kd
            replace kd = kd / r(max)
            egen kx20 = cut(kx), group(`sparks')
            replace kx20 = kx20 + 1
            bys kx20: egen kdmedian = median(kd)
            local sparkspike "\begin{sparkline}{`sparkwidth'}\renewcommand*{\do}[1]{\sparkspike #1 }\docsvlist{"
            forvalues k = 1/`sparks' {
                // hack to get the kdmedian value
                qui su kdmedian if kx20 == `k', meanonly
                local spike : di %9.2f `=r(mean)'
                local spike = trim("`spike'")
                local x = `k' / `sparks'
                local x : di %9.2f `x'
                local x = trim("`x'")
                local sparkspike "`sparkspike'{`x' `spike'}"
                // add a comma if not the end of the list
                if `k' != `sparks' local sparkspike "`sparkspike',"
            }
            local sparkspike "`sparkspike'}\end{sparkline}"
        }

        local check_in_list: list posof "`var'" in cat_vars
        if `check_in_list' == 0 {
            post `pname' ///
                (`lvl') ///
                (`table_order') ///
                ("`var_type'") ///
                ("`var_super'") ///
                ("`varname'") ///
                ("`varlabel'") ///
                ("`var_sub'") ///
                (`var_level') ///
                (`vcentral') ///
                (`vmin') ///
                (`vmax') ///
                (`vother') ///
                (`vmiss') ///
                (`vcount') ///
                ("`sparkspike'")

            local table_order = `table_order' + 1
            continue
        }

        // Need a different approach for categorical variables
        cap restore, not
        preserve
        contract `var'
        rename _freq vcentral
        egen vother = total(vcentral)
        replace vother = vcentral / vother * 100
        decode `var', gen(var_sub)
        drop if missing(`var')
        local last = _N

        forvalues i = 1/`last' {
            local var_type  = "Categorical"
            local var_sub   = var_sub[`i']
            local var_level = `var'[`i']
            local vcentral  = vcentral[`i']
            local vmin      = .
            local vmax      = .
            local vother    = vother[`i']
            // sparkhbar routine
            local check_in_list: list posof "`var'" in sparkhbar_vars
            if `check_in_list' > 0 {
                local x = round(`vother' / 100, 0.01)
                local sparkspike "\setlength{\sparklinethickness}{`sparkhbar_width'}\begin{sparkline}{`sparkwidth'}\spark 0.0 0.5 `x' 0.5 / \end{sparkline}\setlength{\sparklinethickness}{0.2pt}"
            }

        post `pname' ///
            (`lvl') ///
            (`table_order') ///
            ("`var_type'") ///
            ("`var_super'") ///
            ("`varname'") ///
            ("`varlabel'") ///
            ("`var_sub'") ///
            (`var_level') ///
            (`vcentral') ///
            (`vmin') ///
            (`vmax') ///
            (`vother') ///
            (`vmiss') ///
            (`vcount') ///
            ("`sparkspike'")


        local table_order = `table_order' + 1
        }
        restore

    }
}
global lvl_labels `lvl_labels'
global grp_sizes `grp_sizes'
postclose `pname'
use `pfile', clear
qui compress
br

save ../outputs/tables/$table_name.dta, replace
*  ===================================================================
*  = Now you need to pull in the table row labels, units and formats =
*  ===================================================================

*  ===============================
*  = Now produce the final table =
*  ===============================
/*
Now you have a dataset that represents the table you want
- one row per table row
- each uniquely keyed

Now make your final table
All of the code below is generic except for the section that adds gaps
*/

use ../outputs/tables/$table_name.dta, clear

spot_label_table_vars
order bylevel tablerowlabel var_level var_level_lab
gen var_label = tablerowlabel

* Define the table row order
local table_order $table_order

cap drop table_order
gen table_order = .
local i = 1
foreach var of local table_order {
    replace table_order = `i' if varname == "`var'"
    local ++i
}
* CHANGED: 2013-02-07 - try and reverse sort severity categories
gsort +bylevel +table_order -var_level
bys bylevel: gen seq = _n

* Now format all the values
cap drop vcentral_fmt
cap drop vmin_fmt
cap drop vmax_fmt
cap drop vother_fmt

gen vcentral_fmt = ""
gen vmin_fmt = ""
gen vmax_fmt = ""
gen vother_fmt = ""

*  ============================
*  = Format numbers correctly =
*  ============================
local lastrow = _N
local i = 1
while `i' <= `lastrow' {
    di varlabel[`i']
    local stataformat = stataformat[`i']
    di `"`stataformat'"'
    foreach var in vcentral vmin vmax vother {
        // first of all specific var formats
        local formatted : di `stataformat' `var'[`i']
        di `formatted'
        replace `var'_fmt = "`formatted'" ///
            if _n == `i' ///
            & !inlist(var_type[`i'],"Binary", "Categorical") ///
            & !missing(`var'[`i'])
        // now binary and categorical vars
        local format1 : di %9.0gc `var'[`i']
        local format2 : di %9.1fc `var'[`i']
        replace `var'_fmt = "`format1'" if _n == `i' ///
            & "`var'" == "vcentral" ///
            & inlist(var_type[`i'],"Binary", "Categorical") ///
            & !missing(`var'[`i'])
        replace `var'_fmt = "`format2'" if _n == `i' ///
            & "`var'" == "vother" ///
            & inlist(var_type[`i'],"Binary", "Categorical") ///
            & !missing(`var'[`i'])
    }
    local ++i
}
cap drop vbracket
gen vbracket = ""
replace vbracket = "(" + vmin_fmt + "--" + vmax_fmt + ")" if !missing(vmin_fmt, vmax_fmt)
replace vbracket = "(" + vother_fmt + ")" if !missing(vother_fmt)
replace vbracket = subinstr(vbracket," ","",.)

* Append units
* CHANGED: 2013-01-25 - test condition first because unitlabel may be numeric if all missing
cap confirm string var unitlabel
if _rc {
    tostring unitlabel, replace
    replace unitlabel = "" if unitlabel == "."
}
replace tablerowlabel = tablerowlabel + " (" + unitlabel + ")" if !missing(unitlabel)

order tablerowlabel vcentral_fmt vbracket
* NOTE: 2013-01-25 - This adds gaps in the table: specific to this table

br tablerowlabel vcentral_fmt vbracket


chardef tablerowlabel vcentral_fmt vbracket, ///
    char(varname) ///
    prefix("\textit{") suffix("}") ///
    values("Characteristic" "Value" "")

listtab_vars tablerowlabel vcentral_fmt vbracket, ///
    begin("") delimiter("&") end(`"\\"') ///
    substitute(char varname) ///
    local(h1)

*  ==============================
*  = Now convert to wide format =
*  ==============================
keep bylevel table_order tablerowlabel vcentral_fmt vbracket seq ///
    varname var_type var_label var_level_lab var_level 

chardef tablerowlabel vcentral_fmt, ///
    char(varname) prefix("\textit{") suffix("}") ///
    values("Parameter" "Value")


xrewide vcentral_fmt vbracket , ///
    i(seq) j(bylevel) ///
    lxjk(nonrowvars)

order seq tablerowlabel vcentral_fmt1 vbracket1

* Now add in gaps or subheadings
save ../data/scratch/scratch.dta, replace
clear
local table_order $table_order
local obs = wordcount("`table_order'")
set obs `obs'
gen design_order = .
gen varname = ""
local i 1
foreach var of local table_order {
    local word_pos: list posof "`var'" in table_order
    replace design_order = `i' if _n == `word_pos'
    replace varname = "`var'" if _n == `word_pos'
    local ++i
}

joinby varname using ../data/scratch/scratch.dta, unmatched(both)
gsort +design_order -var_level
drop seq _merge

*  ==================================================================
*  = Add a gap row before categorical variables using category name =
*  ==================================================================
local lastrow = _N
local i = 1
local gaprows
while `i' <= `lastrow' {
    // CHANGED: 2013-01-25 - changed so now copes with two different but contiguous categorical vars
    if varname[`i'] == varname[`i' + 1] ///
        & varname[`i'] != varname[`i' - 1] ///
        & var_type[`i'] == "Categorical" {
        local gaprows `gaprows' `i'
    }
    local ++i
}
di "`gaprows'"
if trim("`gaprows'") != "" {
    ingap `gaprows', gapindicator(gaprow)
    foreach var in tablerowlabel  {
        replace `var' = `var'[_n + 1] ///
            if gaprow == 1 & !missing(`var'[_n + 1])
    }
}
replace tablerowlabel = var_level_lab if var_type == "Categorical"
replace table_order = _n

// now generate percentage missing
* gen vmiss_percent = round(vmiss/vcount * 100)
* sdecode vmiss_percent, format(%9.0fc) replace
* replace vmiss_percent = "" if var_type == "Categorical"

* Indent subcategories
* NOTE: 2013-01-28 - requires the relsize package
replace tablerowlabel =  "\hspace*{1em}\smaller[1]{" + tablerowlabel + "}" if var_type == "Categorical"
* CHANGED: 2013-02-07 - by default do not append statistic type
local append_statistic_type 0
if `append_statistic_type' {
    local median_iqr    "\smaller[1]{--- median (IQR)}"
    local n_percent     "\smaller[1]{--- N (\%)}"
    local mean_sd       "\smaller[1]{--- mean (SD)}"
    replace tablerowlabel = tablerowlabel + " `median_iqr'" if var_type == "Skewed"
    replace tablerowlabel = tablerowlabel + " `mean_sd'" if var_type == "Normal"
    replace tablerowlabel = tablerowlabel + " `n_percent'" if var_type == "Binary"
    replace tablerowlabel = tablerowlabel + " `n_percent'" if gaprow == 1
}

local justify lrlrlrl
local tablefontsize "\scriptsize"

local super_heading1 "& \multicolumn{2}{c}{Lactate trajectories}  &\multicolumn{2}{c}{Complete trajectories} &\multicolumn{2}{c}{Partial trajectories} \\"

forvalues j = 1/3 {
    local grp_size: word `j' of $grp_sizes
    local grp_size: di %9.0gc `grp_size'
    local grp_size = trim("`grp_size'")
    local grp_size "(`grp_size' patients)"
    local super_heading2 "`super_heading2' & \multicolumn{2}{c}{`grp_size'} "
}
local super_heading2 "`super_heading2' \\ "

listtab tablerowlabel `nonrowvars'   ///
    using ../outputs/tables/$table_name.tex, ///
    replace rstyle(tabular) ///
    headlines( ///
        "`tablefontsize'" ///
        "`sparkspike_width'" ///
        "\begin{tabu} to " ///
        "\textwidth {`justify'}" ///
        "\toprule" ///
        "`super_heading1'" ///
        "`super_heading2'" ///
        "\midrule" ) ///
    footlines( ///
        "\bottomrule" ///
        "\end{tabu} " ///
        "\label{$table_name} ") ///

cap log off
