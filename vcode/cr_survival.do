*  =====================================
*  = Set up data for survival analysis =
*  =====================================

use ../data/working.dta, clear
include cr_preflight.do

*  ==============
*  = Exclusions =
*  ==============
tab dead, missing
drop if dead == .

* TODO: 2012-09-27 - mismatch between icu outcome and dates and MRIS data
list id dorisname dead dead_icu v_timestamp icu_admit icu_discharge date_trace  ///
	if dofc(icu_discharge) != date_trace & dead_icu == 1 & dead !=.
drop if dofc(icu_discharge) != date_trace & dead_icu == 1 & dead !=.

* NB all done at the at hours resolution
drop if floor(hours(icu_admit)) 	> floor(hours(icu_discharge)) & !missing(icu_admit, icu_discharge)
drop if floor(hours(v_timestamp)) > floor(hours(icu_admit)) & !missing(v_timestamp, icu_admit)
drop if floor(hours(v_timestamp)) > floor(hours(icu_discharge)) & !missing(v_timestamp, icu_discharge)
drop if floor(hours(icu_admit)) 	> floor(hours(last_trace)) & !missing(icu_admit, last_trace)
drop if floor(hours(icu_discharge)) > floor(hours(last_trace)) & !missing(icu_discharge, last_trace)
drop if floor(hours(v_timestamp)) > floor(hours(last_trace)) & !missing(v_timestamp, last_trace)

d daicu date_trace dead
stset date_trace, origin(time daicu) failure(dead) exit(time daicu+90)
sts graph