*  ========================
*  = Draw sites on GB map =
*  ========================


/*
NOTE: 2013-02-21 - beware doing this with the highest resolution files
The pdf file subsequently produced by stata is massive and slow to open
CHANGED: 2013-02-22 - modified to now highlight one site for site report
CHANGED: 2013-04-16 - now highlights spot_traj sites
*/

clear
global cleanrun = 0
global filename ne_10m_admin_0_map_subunits

if $cleanrun {
	// load sites final
	local ddsn mysqlspot
	local uuser stevetm
	local ppass ""
	odbc load, exec("SELECT * FROM spot.sitesFinal")  dsn("`ddsn'") user("`uuser'") pass("`ppass'") lowercase sqlshow clear
	keep icode namesite site_pcode protocol_referrals
	rename site_pcode site_postcode
	gen allreferrals = protocol_referrals == "Prospective"
	drop protocol_referrals
	file open myvars using ../data/scratch/vars.yml, text write replace
	foreach var of varlist * {
		di "- `var'" _newline
		file write myvars "- `var'" _newline
	}
	file close myvars
	shell ../ccode/label_stata_fr_yaml.py "../data/scratch/vars.yml" "../local/lib_phd/dictionary_fields.yml"
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
	compress
	d
	cap drop pcode
	gen pcode = lower(subinstr(site_postcode, " ", "",.))

	save ../data/data_spotstudy/sites_for_maps.dta, replace

	//  =============================================================
	//  = Prepare CSV files of postcodes and eastings and northings =
	//  =============================================================
	// this is slow: and only needs to be done once
	local clean_run_csv 0
	if `clean_run_csv' {
		local codepo_dir "/Users/steve/Pictures/mapping/ordnance_survey/codepo_gb/Data/CSV/"
		! ls `codepo_dir'*.csv > ../data/scratch/filelist.txt
		cap file close f
		file open f using ../data/scratch/filelist.txt, read
		file read f line
		clear
		insheet pc pq ea no cy rh lh cc dc wc using `line'
		foreach var in pc cy rh lh cc dc wc {
			cap confirm string var `var'
			if _rc {
				tostring `var', replace force
			}
		}
		save ../data/data_spotstudy/codepo.dta, replace
		drop _all
		file read f line
		while r(eof)==0 {
			insheet pc pq ea no cy rh lh cc dc wc using `line'
			foreach var in pc cy rh lh cc dc wc {
				cap confirm string var `var'
				if _rc {
					tostring `var', replace force
				}
			}
			append using ../data/data_spotstudy/codepo.dta
			save ../data/data_spotstudy/codepo.dta, replace
			drop _all
			file read f line
		}
		cap file close f
	* NOTE: 2013-02-21 - there are 1.6 million UK postcodes
	use ../data/data_spotstudy/codepo.dta, clear
	cap drop pcode
	gen pcode = lower(subinstr(pc, " ", "",.))
	save ../data/data_spotstudy/codepo.dta, replace
	}

	// merge in eastings and northings
	use ../data/data_spotstudy/sites_for_maps.dta, clear
	merge 1:1 pcode using ../data/data_spotstudy/codepo.dta
	drop if _m == 2
	drop _m

	*  ================================================
	*  = Manually add in ea and no for NI postcodes =
	*  ================================================
	replace ea = 144626 if icode == "83S"
	replace no = 529251 if icode == "83S"
	replace ea = 153586 if icode == "55S"
	replace no = 528954 if icode == "55S"
	replace ea = 114186 if icode == "04S"
	replace no = 513309 if icode == "04S"

	save ../data/data_spotstudy/sites_for_maps.dta, replace

	*  ==========================================================
	*  = Now convert the eastings and northings to long and lat =
	*  ==========================================================
	use ../data/data_spotstudy/sites_for_maps.dta, clear
	cap drop lon lat
	cap drop id
	gen id = _n
	save ../data/data_spotstudy/sites_for_maps.dta, replace
	outsheet id ea no using "../data/osgrid.txt", replace nonames
	// python script run from the shell
	! /Users/steve/data/spot_reports/ccode/osgrid2lonlat.py
	insheet id ea no lon lat using "../data/lonlat.txt", clear
	merge 1:1 id using ../data/data_spotstudy/sites_for_maps.dta
	drop _m

	save ../data/data_spotstudy/sites_for_maps.dta, replace

	// ==============================
	// = Import and draw a test map =
	// ==============================
	// CHANGED: 2013-02-22 - don't use the OS map - resolution too high, PDF too large
	// cd /Users/steve/Pictures/mapping/ordnance_survey/merid2_essh_gb/data
	cd /Users/steve/Pictures/mapping/natural_earth/ne_10m_admin_0_map_subunits
	local filename $filename
	if $cleanrun {
		shp2dta using `filename', ///
			database(`filename'_db) coordinates(`filename'_xy) genid(id) ///
			replace
	}
	! cp ./`filename'_db.dta ~/data/spot_reports/data/data_spotstudy/`filename'_db.dta
	! cp ./`filename'_xy.dta ~/data/spot_reports/data/data_spotstudy/`filename'_xy.dta
	cd ~/data/spot_traj/vcode

	// use ../data/`filename'_db,clear
	// spmap using ../data/`filename'_xy, id(id)
	// graph rename base_map, replace
}


local filename $filename
use ../data/data_spotstudy/sites_for_maps.dta, clear
tempfile 2merge working
save `working', replace
use ../data/working.dta, clear
contract icode
keep icode
save `2merge', replace
use `working', clear
cap drop _merge
merge 1:1 icode using `2merge'
cap drop spot_traj_site
gen spot_traj_site = _m == 3
cap drop _merge
save ../data/data_spotstudy/sites_for_maps.dta, replace

use ../data/data_spotstudy/`filename'_db,clear
spmap using ../data/data_spotstudy/`filename'_xy ///
	if adm0_a3 == "GBR" ///
	, id(id) ///
	point( ///
		by(spot_traj_site) ///
		data(../data/data_spotstudy/sites_for_maps.dta) xcoord(lon) ycoord(lat) ///
		fcolor(gs4 blue) ocolor(gs4 blue) ///
		) ///
	xsize(2) ysize(3)

graph rename point_map, replace
* NOTE: 2013-02-22 - console will not write pdf, png 
* and you must do graph display before export to get the eps version out
graph display point_map
graph export ../outputs/figures/study_sites_traj.eps, ///
	name(point_map) ///
	replace

* exit
* * NOTE: 2013-02-22 - shell script not happy being run from stata
* ! /Users/steve/Data/spot_early/cCode/pdfcrop.pl /users/steve/data/spot_reports/outputs/figures/fig_study_sites.pdf


