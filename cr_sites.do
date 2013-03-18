clear
* ==================================
* = DEFINE LOCAL AND GLOBAL MACROS =
* ==================================
local ddsn mysqlspot
local uuser stevetm
local ppass ""
******************


*  ===================
*  = Site level data =
*  ===================

odbc query "`ddsn'", user("`uuser'") pass("`ppass'") verbose

clear
timer on 1
odbc load, exec("SELECT * FROM spot_early.sites_early")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
timer off 1
timer list 1
compress
count

file open myvars using ../data/scratch/vars.yml, text write replace
foreach var of varlist * {
	di "- `var'" _newline
	file write myvars "- `var'" _newline
}
file close myvars


shell ../local/lib_usr/label_stata_fr_yaml.py "../data/scratch/vars.yml" "../local/lib_phd/dictionary_fields.yml"

capture confirm file ../data/scratch/_label_data.do
if _rc == 0 {
	include ../data/scratch/_label_data.do
	shell  rm ../data/scratch/_label_data.do
	shell rm ../data/scratch/myvars.yml
}
else {
	di as error "Error: Unable to label data"
	exit
}

*  ===========================================
*  = Summary or categorical versions of data =
*  ===========================================
xtile ht_ratio_q3 = ht_ratio, nq(3)
xtile heads_tailed_q3 = heads_tailed, nq(3)
xtile tails_wardemx_q3 = tails_wardemx, nq(3)
xtile cmp_beds_persite_q3 = cmp_beds_persite, nq(3)


save ../data/sites.dta, replace


