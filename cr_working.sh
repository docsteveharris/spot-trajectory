#  ====================================================================
#  = Generic shell script to set up tables needed for spot trajectory =
#  ====================================================================
#  Based on spot_early version

cd ~/data/spot_traj/vcode
# First of all prepare all the tables you need
uuser="stevetm"
ppass=""
ddbase="spot_early"
/usr/local/bin/mysql --user=$uuser --pass=$ppass $ddbase  --local-infile=1 < cr_working.sql >  '../logs/log_cr_working.txt';

# unitsFinal
../ccode/import_sql.py spot_traj unitsfinal_raw -replace
../ccode/index_table.py spot_traj unitsfinal

# sites
../ccode/import_sql.py spot_traj sitesfinal -source spot -replace
../ccode/index_table.py spot_traj sitesfinal
../ccode/make_table.py spot_traj sitesfinal

# heads
../ccode/import_sql.py spot_traj headsfinal_raw -replace
../ccode/index_table.py spot_traj headsfinal
../ccode/make_table.py spot_traj headsfinal -o validated

# monthly quality by unit
../ccode/import_sql.py spot_traj lite_summ_monthly_raw -replace
../ccode/index_table.py spot_traj lite_summ_monthly
../ccode/make_table.py spot_traj lite_summ_monthly -o validated

# tails
# beware this takes ages to run
# TODO: 2013-03-19 - recode make_table to work with chunks of data rather than entire tables
../ccode/import_sql.py spot_traj tailsfinal_raw -replace
../ccode/index_table.py spot_traj tailsfinal
../ccode/make_table.py spot_traj tailsfinal -o validated


# finally make the working data table
../ccode/make_table.py spot_traj working_traj -o clean
