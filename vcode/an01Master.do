*  =================================
*  = Master analysis plan and file =
*  =================================

* Steve Harris

/* 
Initial set-up of database
Shell

../ccode/import_sql.py spot_traj phd_sites -source spot
../ccode/index_table.py spot_traj phd_sites
../ccode/make_table.py spot_traj phd_sites

../ccode/import_sql.py spot_traj unitsFinal  -source spot 
../ccode/index_table.py spot_traj unitsfinal
../ccode/make_table.py spot_traj unitsfinal

../ccode/import_sql.py spot_traj headsFinal  -source spot 
../ccode/index_table.py spot_traj headsfinal
../ccode/make_table.py spot_traj headsfinal

../ccode/import_sql.py spot_traj lite_summ_monthly  -source spot 
../ccode/index_table.py spot_traj lite_summ_monthly
../ccode/make_table.py spot_traj lite_summ_monthly

Now use tailsMini for spot 

../ccode/import_sql.py spot_traj tailsMini  -source spot 
../ccode/index_table.py spot_traj tailsmini

- but this just provides context

Duplicate and copy the following tables (keys_dvr without content)
SQL

RENAME TABLE spot_early.keys_dvr_copy TO spot_traj.keys_dvr
RENAME TABLE spot.tailsMini_copy TO spot_traj.tailsMini
RENAME TABLE spot.tailsFinal_copy TO spot_traj.tailsFinal;



 */

include cr_working.do

*  ===================================
*  = Summarise study characteristics =
*  ===================================

include an_table_study.do

include an_table_patients.do

include an_traj.do


