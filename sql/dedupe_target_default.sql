CREATE  OR REPLACE FUNCTION view_target_duplicates() 
RETURNS integer AS  $$
DECLARE
returnrec duplicate_records;
BEGIN

CREATE  TEMP TABLE  dsd_ta_map 
(dsd_id integer,
ta_id integer);

EXECUTE '
INSERT INTO dsd_ta_map
SELECT a.dataelementid as dsd_id,b.dataelementid as ta_id
FROM dataelement a
INNER JOIN  (
SELECT dataelementid,substring(name from ''^.+\(.+,'') as name FROM dataelement 
where name ~(''TARGET'')
AND name ~(''TA\)'') 
and name !~(''NARRATIVE'')
and categorycomboid = 
(SELECT categorycomboid FROM categorycombo WHERE name = ''default'') ) b
ON substring(a.name from ''^.+\(.+,'') = b.name

where a.name ~(''TARGET'')
AND a.name ~(''DSD'')
and a.name !~(''NARRATIVE'')
and a.categorycomboid = 

(SELECT categorycomboid FROM categorycombo WHERE name = ''default'')';

DROP TABLE IF EXISTS dups;
dfdf
CREATE  TABLE  temp1
(sourceid integer,
periodid integer,
dataelementid integer,
categoryoptioncomboid integer,
attributeoptioncomboid integer,
value character varying (500000),
duplicate_type character varying(20)
);



EXECUTE 'INSERT INTO temp1
SELECT DISTINCT
dv1.sourceid,
dv1.periodid,
dv1.dataelementid,
dv1.categoryoptioncomboid,
dv1.attributeoptioncomboid,
dv1.value ,''PURE''::character varying(20) as duplicate_type
from datavalue dv1
INNER JOIN  datavalue dv2 on 
dv1.sourceid = dv2.sourceid
AND 
dv1.periodid = dv2.periodid
AND 
dv1.dataelementid = dv2.dataelementid
AND 
dv1.categoryoptioncomboid = dv2.categoryoptioncomboid
AND 
dv1.attributeoptioncomboid  != dv2.attributeoptioncomboid 
UNION
SELECT DISTINCT ta.sourceid,
ta.periodid,
ta.dataelementid,
ta.categoryoptioncomboid,
ta.attributeoptioncomboid,
ta.value,
''CROSSWALK''::character varying(20) as duplicate_type
 from datavalue ta
INNER JOIN 
(SELECT DISTINCT
dv1.sourceid,
dv1.periodid,
dv1.dataelementid,
map.ta_id,
dv1.categoryoptioncomboid,
dv1.attributeoptioncomboid
from datavalue dv1
INNER JOIN dsd_ta_map map
on dv1.dataelementid = map.dsd_id ) dsd
on ta.sourceid = dsd.sourceid
AND ta.periodid = dsd.periodid
and ta.dataelementid = dsd.ta_id
and ta.categoryoptioncomboid = dsd.categoryoptioncomboid
and ta.attributeoptioncomboid != dsd.attributeoptioncomboid';
 
/*Data element names*/

EXECUTE 'ALTER TABLE temp1 ADD COLUMN dataelement character varying(230);
ALTER TABLE temp1 ADD COLUMN de_uid character varying(11);

UPDATE temp1 set dataelement = b.name from dataelement b
where temp1.dataelementid = b.dataelementid;

UPDATE temp1 set de_uid = b.uid from dataelement b
where temp1.dataelementid = b.dataelementid';
 
 
 /*Disagg*/
EXECUTE 'ALTER TABLE temp1 ADD COLUMN disaggregation character varying(250);
ALTER TABLE temp1 ADD COLUMN coc_uid character varying(11);

UPDATE temp1 set disaggregation = b.categoryoptioncomboname from _categoryoptioncomboname b
where temp1.categoryoptioncomboid = b.categoryoptioncomboid;

UPDATE temp1 set coc_uid = b.uid from categoryoptioncombo b
where temp1.categoryoptioncomboid = b.categoryoptioncomboid';
 /*Agency*/
EXECUTE 'ALTER TABLE temp1 ADD COLUMN agency character varying(250);

UPDATE temp1 set agency = b."Funding Agency" from _categoryoptiongroupsetstructure b
where temp1.attributeoptioncomboid = b.categoryoptioncomboid';

/*Mechanism*/
EXECUTE 'ALTER TABLE temp1 ADD COLUMN mechanism character varying(250);
UPDATE temp1 set mechanism = b.categoryoptioncomboname from _categoryoptioncomboname b
where temp1.attributeoptioncomboid = b.categoryoptioncomboid';
 
 /*Orgunits*/
EXECUTE '
ALTER TABLE temp1 ADD COLUMN oulevel2_name character varying(230);
ALTER TABLE temp1 ADD COLUMN oulevel3_name character varying(230);
ALTER TABLE temp1 ADD COLUMN oulevel4_name character varying(230);
ALTER TABLE temp1 ADD COLUMN oulevel5_name character varying(230);
ALTER TABLE temp1 ADD COLUMN orgunit_name character varying(230);
ALTER TABLE temp1 ADD COLUMN orgunit_level integer;
ALTER TABLE temp1 ADD COLUMN ou_uid character varying(11);

UPDATE temp1 SET orgunit_name = b.orgunit_name,
ou_uid = b.ou_uid,
orgunit_level = b.orgunit_level,
oulevel2_name = b.oulevel2_name,
oulevel3_name = b.oulevel3_name,
oulevel4_name = b.oulevel4_name,
oulevel5_name = b.oulevel5_name FROM (

SELECT temp1.sourceid,ou.name as orgunit_name, ou.uid as ou_uid,
ous.level as orgunit_level,
oulevel2.name as oulevel2_name,
oulevel3.name as oulevel3_name,
oulevel4.name as oulevel4_name,
oulevel5.name as oulevel5_name from _orgunitstructure ous
INNER JOIN temp1 on temp1.sourceid = ous.organisationunitid
INNER JOIN organisationunit ou on temp1.sourceid = ou.organisationunitid
LEFT JOIN organisationunit oulevel2 on ous.idlevel4 = oulevel2.organisationunitid
LEFT JOIN organisationunit oulevel3 on ous.idlevel5 = oulevel3.organisationunitid
LEFT JOIN  organisationunit oulevel4 on ous.idlevel6 = oulevel4.organisationunitid
LEFT JOIN  organisationunit oulevel5 on ous.idlevel7 = oulevel5.organisationunitid ) b

where temp1.sourceid = b.sourceid';
 
 /*Periods*/
EXECUTE 'ALTER TABLE temp1 ADD COLUMN iso_period character varying;
UPDATE temp1 SET iso_period = p.iso from _periodstructure p where p.periodid = temp1.periodid';
 /*Partner*/
 
 EXECUTE 'ALTER TABLE temp1 ADD COLUMN partner character varying(230);
 UPDATE temp1 set partner = b.name from (
 SELECT _cocg.categoryoptioncomboid,_cog.name from categoryoptiongroup _cog
INNER JOIN categoryoptiongroupsetmembers _cogsm on _cog.categoryoptiongroupid=_cogsm.categoryoptiongroupid 
INNER JOIN categoryoptiongroupmembers _cogm on _cog.categoryoptiongroupid=_cogm.categoryoptiongroupid 
INNER JOIN categoryoptioncombos_categoryoptions _cocg on _cogm.categoryoptionid=_cocg.categoryoptionid
 WHERE _cogsm.categoryoptiongroupsetid= 481662 ) b
 where temp1.attributeoptioncomboid = b.categoryoptioncomboid';

  /*Group ID. This will be used to group duplicates. Important for the DSD TA overlap*/
 
 EXECUTE 'ALTER TABLE temp1 ADD COLUMN group_id character(32);
UPDATE temp1 SET group_id = md5( COALESCE(orgunit_name,'') || COALESCE(dataelement,'') || COALESCE(disaggregation,'') || COALESCE(iso_period,'') )';

RETURN 1;
 END;
$$ LANGUAGE plpgsql VOLATILE;



SELECT DISTINCT
dv1.sourceid,
dv1.periodid,
dv1.dataelementid,
dv1.categoryoptioncomboid,
dv1.attributeoptioncomboid,
dv1.value ,'PURE'::character varying(20) as duplicate_type
from datavalue dv1
INNER JOIN  datavalue dv2 on 
dv1.sourceid = dv2.sourceid
AND 
dv1.periodid = dv2.periodid
AND 
dv1.dataelementid = dv2.dataelementid
AND 
dv1.categoryoptioncomboid = dv2.categoryoptioncomboid
AND 
dv1.attributeoptioncomboid  != dv2.attributeoptioncomboid 
UNION
SELECT DISTINCT ta.sourceid,
ta.periodid,
ta.dataelementid,
ta.categoryoptioncomboid,
ta.attributeoptioncomboid,
ta.value,
'CROSSWALK'::character varying(20) as duplicate_type
 from datavalue ta
INNER JOIN 
(SELECT DISTINCT
dv1.sourceid,
dv1.periodid,
dv1.dataelementid,
map.ta_id,
dv1.categoryoptioncomboid,
dv1.attributeoptioncomboid
from datavalue dv1
INNER JOIN (
SELECT a.dataelementid as dsd_id,b.dataelementid as ta_id
FROM dataelement a
INNER JOIN  (
SELECT dataelementid,substring(name from '^.+\(.+,') as name FROM dataelement 
where name ~('TARGET')
AND name ~('TA\)') 
and name !~('NARRATIVE')
and categorycomboid = 
(SELECT categorycomboid FROM categorycombo WHERE name = 'default') ) b
ON substring(a.name from '^.+\(.+,') = b.name

where a.name ~('TARGET')
AND a.name ~('DSD')
and a.name !~('NARRATIVE')
and a.categorycomboid = 
(SELECT categorycomboid FROM categorycombo WHERE name = 'default') ) map
on dv1.dataelementid = map.dsd_id ) dsd
on ta.sourceid = dsd.sourceid
AND ta.periodid = dsd.periodid
and ta.dataelementid = dsd.ta_id
and ta.categoryoptioncomboid = dsd.categoryoptioncomboid
and ta.attributeoptioncomboid != dsd.attributeoptioncomboid




