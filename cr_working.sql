use spot_traj;
--  ====================================================
--  = SQL set up views and tables that will be needed =
--  ====================================================

-- Make up-to-date views of tailsFinal
DROP VIEW IF EXISTS spot_traj.tailsFinal_raw;
CREATE VIEW spot_traj.tailsFinal_raw AS
  SELECT *
FROM spot.tailsFinal
  WHERE icode IS NOT NULL;

-- Make up-to-date views of headsFinal
DROP VIEW IF EXISTS spot_traj.headsFinal_raw;
CREATE VIEW spot_traj.headsFinal_raw AS
  SELECT *
FROM spot.headsFinal;

-- Monthly quality (by unit)
DROP VIEW IF EXISTS spot_traj.lite_summ_monthly_raw;
CREATE VIEW spot_traj.lite_summ_monthly_raw AS
	SELECT
		icode,
		studymonth,
		icnno,
		dropflag,
		spottrue,
		cmp_admx_permonth,
		cmpd_month_miss,
		match_quality_by_month,
		match_quality_by_site,
		studymonth_allreferrals,
		studymonth_protocol_problem,
		site_quality_q1,
		site_quality_by_month,
		count_patients,
		count_all_eligible
	FROM spot.lite_summ_monthly;

-- Sites and units data
DROP VIEW IF EXISTS spot_traj.hes_providers;
CREATE VIEW spot_traj.hes_providers AS
	SELECT * FROM spot.hes_providers;
DROP VIEW IF EXISTS spot_traj.sites_via_directory_raw;
CREATE VIEW spot_traj.sites_via_directory_raw AS
	SELECT * FROM spot.sites_via_directory;
DROP VIEW IF EXISTS spot_traj.sitesFinal_raw;
CREATE VIEW spot_traj.sitesFinal_raw AS
	SELECT * FROM spot.sitesFinal;
DROP VIEW IF EXISTS spot_traj.unitsFinal_raw;
CREATE VIEW spot_traj.unitsFinal_raw AS
	SELECT * FROM spot.unitsFinal;

-- Make a table containing data from MRIS tracing to be used 
-- to make working_traj
DROP TABLE IF EXISTS spot_traj.light_mris_final_raw;
CREATE TABLE spot_traj.light_mris_final_raw 
	SELECT * FROM spot.light_mris_final;
ALTER TABLE light_mris_final_raw ADD INDEX (idpatient);

-- CHANGED: 2013-05-18 - Don't bother remaking headsFinal - just pull the version from spot_early
DROP TABLE IF EXISTS spot_traj.headsFinal;
CREATE TABLE spot_traj.headsFinal 
  SELECT *
	FROM spot_early.headsFinal;
ALTER TABLE headsFinal ADD INDEX (idvisit);
ALTER TABLE headsFinal ADD INDEX (idpatient);
-- SELECT idpatient, date_trace, dead, icnno, adno FROM headsFinal LIMIT 5;

DROP  TABLE IF EXISTS tails_mris;
CREATE  TABLE tails_mris
	SELECT
	lower(icnno) as icnno,
	adno,
	idpatient,
	"" AS idvisit,
	dead,
	date_event
	FROM light_mris_final_raw 
	WHERE icnno != "" AND adno != "";
-- SELECT * FROM tails_mris LIMIT 5;

INSERT INTO tails_mris (icnno, adno, idpatient, idvisit, dead, date_event)
	SELECT 
	h.icnno,
	h.adno,
	m.idpatient,
	h.idvisit,
	m.dead,
	m.date_event
	FROM light_mris_final_raw as m
	LEFT JOIN headsFinal as h ON h.idpatient = m.idpatient
	WHERE h.icnno IS NOT NULL AND h.adno IS NOT NULL AND m.icnno = "" and m.adno = "";

ALTER TABLE tails_mris ADD INDEX (icnno, adno);

ALTER TABLE tails_mris ADD INDEX (icnno);
ALTER TABLE tails_mris ADD INDEX (adno);
ALTER TABLE tails_final_ix ADD INDEX (icnno);
ALTER TABLE tails_final_ix ADD INDEX (adno);

SELECT count(*) FROM light_mris_final_raw;
SELECT count(*) FROM tails_mris;
-- SELECT * FROM tails_mris;  



