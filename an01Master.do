*  ====================
*  = Preparatory code =
*  ====================

// Initial data sets
include cr_working.do
include cr_working_sensitivity.do

// Post flight data
// NOTE: 2013-05-21 - BEWARE you have defined traj per 24 hrs in cr_severity.do
use ../data/working.dta, clear
qui include cr_preflight.do
count
save ../data/working_postflight.dta, replace

// Survival data
pwd
use ../data/working_postflight.dta, clear
count
include cr_survival.do
sts list, at(1 30 90 365)
save ../data/working_survival.do, replace


*  =================
*  = Analysis code =
*  =================

// Baseline tables
do an_tables_traj_pt_chars.do
do an_tables_traj_pt_physiology.do
do an_tables_traj_pt_physiology_ward.do


*  ========================
*  = Inspect trajectories =
*  ========================

do an_fig_inspect_all.do

// Model trajectories from adjusted for admission values
do an_model_raw_bkwd.do
