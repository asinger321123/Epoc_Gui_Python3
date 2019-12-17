
************Add parent directory (\\tweety.corp.athenahealth.com\private\Epocrates Analytics)************************************
***********************   to your project folder, and assign to LMT libref   ************************************************;
options source source2 notes date center;

/*%let filepath = P:\Epocrates Analytics\List Match\List Match Folder\NJ_Impax_Oxymorphone_20180209_AS;*/

LIBNAME LMT "&filepath";
/*%let rvp = NJ;  /*Requester's initials*/*/
/*%let brand = Oxymorphone; /*Brand Name*/*/
/*%let analyst = AS; /*Your initials*/*/

/*%lmtassign_p(projectfolder=Epocrates Analytics\List Match\RyanO\JR_Januvia_092214); */

*******************Input target files and save to LMT library************************************************;

options compress=yes nonotes nosource;
/* three options: 1)pipe--columns are separated by '|' ; 
            	  2)csv-- coulmns are separated by ',' ; 
                  3)tab --columns are separated by tab */

	%let file_type = tab;
	%let keepvars= fname lname zip state ;

	%macro wtf;
 /* importing all columns as string to avoid missing of leading zero in ME or Zip */
     proc import datafile="&filepath\target.txt" 
                 out=target replace 
     %if %upcase(&file_type)=PIPE  %then %do; dbms=dlm; delimiter='|'; %end;
     %else %if %upcase(&file_type)=CSV   %then %do; dbms=csv; %end;
     %else %if %upcase(&file_type)=TAB   %then %do; dbms=dlm; delimiter='09'x; %end; 
     guessingrows=50000; getnames=yes; run; 

	 %mend; 

	 %wtf;

proc sql noprint; select count(*) into :fcount from (select distinct lname, fname, zip from target);quit;

data lmt.&rvp._&brand._&analyst._&sysdate._%trim(&fcount.); set target; run;

***LIST MATCH PARAMETERS***;
%let epoxfile = USER BASE;                      ***HONORS PANEL or USER BASE                                                                                                              ***;
%let matchtype = INEXACT;                          ***MATCHTYPE=Exact, Inexact, Both  (DEFAULT=BOTH)                                                                                  ***;
                                                ***EXACT   : ID only Match (REQUIRE THAT ID BE PROVIDED                                                                    ***;
                                                ***INEXACT : Fuzzy match only (REQUIRE THAT AT LEAST THE FNAME, LNAME, and ZIP BE PROVIDED)                       ***;
                                                ***BOTH    : ID and Fuzzy match (REQUIRE THAT AT LEAST THE ID, FNAME, LNAME, and ZIP BE PROVIDED)       ***;
%let USER = MD OTHER;                           ***MD, OTHER, and/or STUDENT (DEFAULT is EITHER MD OTHER and STUDENT when matching to USER BASE
                                                   and MD OTHER and UNVERIFIED when matching to HONORS PANEL)                                                     ***;
                                                ***MD      : Match MDs within                              ***;
                                                ***OTHER   : Match Other Healthcase Professional             ***;
                                                ***STUDENT : Match Students within User Base              ***;
%let ACTIVEONLY = N;                            ***Y, N  (DEFAULT=N)                                                      ***;
                                        		***Y           : Only active users will be matched          ***;
                                                ***N       : Register (all users) will be matched       ***;
%let GROUPBY = ;                                ***Fields used to get subcounts                         ***;
%let ME = ;                                   ***ME Number                                            ***;
%let FNAME = fname;                             ***First Name                                           ***;
%let LNAME = lname;                             ***Last Name ***;
%let ZIP = zip;   
*-------------------------------------------------------------------------------------------*;

%lmt(Data=lmt.&rvp._&brand._&analyst._&sysdate._%trim(&fcount.)
      ,Epoxfile=&epoxfile
      ,User=&user
      ,Matchtype=&matchtype
      ,Activeonly=&activeonly
      ,Groupby=&groupby
      ,ME=&me
      ,FName=&fname
      ,LName=&lname 
      ,Zip=&zip );

proc contents data=work._all_ directory out=temp (keep= libname memname) noprint; run;
proc sort data = temp nodupkey; by memname; run;

data temp; set temp; where upcase(memname) contains '_MATCHRESULTS_'; run;
proc sort data = temp; by libname memname; run;
data temp; set temp; by libname; if last.libname; run;

proc sql noprint; select memname into :lmtresults from temp; quit;
%put &lmtresults;

proc contents data=work.target directory out=temp2 (keep=name) noprint; run;

data temp2; set temp2;
  length new_var $30.;
  if upcase(name) EQ "ME" then new_var = "client_me";
   else if upcase(name) EQ "FNAME" then new_var = "client_fname";
   else if upcase(name) EQ "LNAME" then new_var = "client_lname";
   else if upcase(name) EQ "ZIP" then new_var = "client_zip";
   else new_var = name;
run;

proc sql noprint;
  select distinct(new_var) into :retainers separated by " " from temp2;
quit;
%put &retainers;

libname p 'j:\mkrich\list match pricing';

PROC SQL;
  CREATE TABLE customlist AS
  SELECT distinct a.*
  FROM &lmtresults (WHERE = (_dupclientrecord_ = 0 AND _dupbaserecord_ = 0 AND _match_ = 1)) a
  left join da.customer_user (keep = userid user_account_key last_session_dt) b on a.userid = b.userid
  where b.last_session_dt GE (today()-180);
QUIT;

proc sql;
create table temp1 as
select count(client_fuzzymatchcode_) as original_count, "dummy" as dummy 
from &lmtresults 
where _dupclientrecord_ = 0 and _dupbaserecord_ = 0
group by 2;

create table temp2 as
select count(userid) as match_count, "dummy" as dummy 
from customlist
group by 2;
quit;

data temp3; merge temp1 temp2; by dummy; run;

*starting report here;
*gives orig count, match count, match %;

proc sql;
select original_count, match_count, match_count/original_count as match_rate
from temp3;
quit;

proc sql;
create table usr_profile as
select  distinct userid,
case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as OCCSPEC
from customlist t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;

proc sql;
create table usr_profile2 as
select  distinct userid,
case when (f1.label = 'MD' OR f1.label = 'DO') then "MD/DO" else "Other" end as OCC,
f2.label as SPEC
from customlist t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;

proc sql;
create table occspeccount as
select occspec, count(userid) as ncount from usr_profile
group by 1;
quit;

*reporting number of MDs and Others;

proc sql; 
select count(userid) as md_count from usr_profile2 where occ = "MD/DO";
select count(userid) as other_count from usr_profile2 where occ = "Other";
quit;

proc sql outobs=10;
create table top_5 as
select spec, count(userid) as dr_no
from usr_profile2
where occ = "MD/DO"
group by 1
order by 2 desc;
quit;

/*data top_5; set top_5; if _n_ GT 5 then delete; run;*/


proc sql noprint; 
select count(userid) into :mdcount from usr_profile2 where occ = "MD/DO";
select count(userid) into :othcount from usr_profile2 where occ = "Other";
quit;


*showing top 5 physicians;

proc sql; 
select *, dr_no/&mdcount as md_Spec_percent 
from top_5 
; 
run;

proc sql;
create table price1 as
select a.*, b.rate
from occspeccount a
left join p.current_rate_card b on a.occspec=b.occspec;
quit;

data price2; set price1; lmrate = rate*ncount; run;

proc sql;
create table tempm as
select sum(lmrate) as list_price from price2;
quit;

proc sql;
select list_price*1.2 as list_price
from tempm;
quit;

proc sql;
create table target_total as
select 'Target Total',count(*) as target_total, '                                   ' into :target_total from (select distinct fname, lname, zip from target);
quit;

proc sql;
create table ce_total as
Select 'Campaign Eligible' as type, Count(distinct userid) as campaign_eligible, '                                   '
FROM final;
quit;

proc sql;
create table ce_rate as
Select 'CE Match Rate' as type, ROUND((campaign_eligible / target_total * 100)), '                                   '
FROM ce_total, target_total;
quit;

proc sql;
create table md_do_elig as
Select 'MD/DO Eligible' as type, count(occspec) as occTotal, '                                   '
FROM usr_profile 
WHERE occspec LIKE 'MD/DO%';
quit;

proc sql;
create table hpc_elig as
Select 'HPC Eligible' as type, count(occspec), '                                   '
FROM usr_profile 
WHERE occspec NOT LIKE 'MD/DO%';
quit;

proc sql outobs=7;
create table top_5_spec as
Select Count(*) as count, occspec, '                              '
FROM usr_profile
WHERE occspec LIKE 'MD/DO%'
Group By occspec
ORDER BY count DESC;
quit;

proc sql;
create table top_5 as
Select 'Top 7 MD/DO', ROUND((count / occTotal * 100)) as count, occspec
FROM top_5_spec, md_do_elig;
quit;

proc sql;
create table finalPrice as
Select 'Actual Price', round(((list_price*1.2)+499),1000) as listFinalPrice format Dollar8., '                              '
FROM tempm;
quit;


proc sql;
create table what_we_need as
Select * FROM target_total;
INSERT INTO what_we_need
Select * FROM ce_total;
INSERT INTO what_we_need
Select * FROM ce_rate;
INSERT INTO what_we_need
Select * FROM md_do_elig;
INSERT INTO what_we_need
Select * FROM hpc_elig;
INSERT INTO what_we_need
Select * FROM top_5;
INSERT INTO what_we_need
Select * FROM finalPrice;
quit;

proc sql noprint; select count(userid) into :ncount from customlist; quit;

data lmt._matched_%trim(&ncount.); set customlist;
  keep &retainers userid occupation_key specialty_key;
run;

proc freq data=lmt._matched_%trim(&ncount.); TITLE1 "Client List Occupation Breakout"; tables occupation_key / out=occ; run; TITLE1;

proc freq data=lmt._matched_%trim(&ncount.)  order=freq; TITLE2 "Client List Specialty Breakout"; tables specialty_key / out=spec; where put(occupation_key,ok2on.) IN ("MD","DO");
run; TITLE2;

proc sort data=occ; by descending count;run;
proc sort data=spec; by descending count;run;

data firstOcc;
set occ (obs=1 firstobs=1);
occ1=put(occupation_key,ok2on.);
if occ1='MD' then
occ1='MD/DO';
run;

data secondOcc;
set occ (obs=2 firstobs=2);
occ2=put(occupation_key,ok2on.);
run;

/*data SpecTest;*/
/*set spec;*/
/*where put(specialty_key,SK2S2X38.) not in ("Student","Other","No Specialty");*/
/*run;*/

data firstSpec;
set spec (obs=1 firstobs=1);
where put(specialty_key,SK2S2X.) not in ("Student","Other","No Specialty");
spec1=put(specialty_key,SK2S2X.);
run;

data secondSpec;
set spec (obs=2 firstobs=2);
where put(specialty_key,SK2S2X.) not in ("Student","Other","No Specialty");
spec2=put(specialty_key,SK2S2X.);
run;

proc sql;
create table listMatchTracker (case_number char(25), primeOcc char(25), secOcc char(25), primeSpec char(25), secSpec char(25), listTotal numeric(25) format comma8., matchSize numeric(25) format comma8., matchRate numeric(25), brand char(25), price numeric(25) format Dollar8., date numeric(25) format mmddyys10., folderPath char(250));
quit;

data letInputs;
case_number=&caseno2.;
brand=&brand2.;
filepath=&filepath2.;
date=today();
format date mmddyys10.;
run;

proc sql;
create table letInputs2 as
select * from letInputs;
quit;

proc sql;
insert into listMatchTracker (case_number, brand, folderPath, matchSize, listTotal, price, date, primeOcc, secOcc, primeSpec, secSpec)
select case_number, brand, filepath, campaign_eligible, target_total, listFinalPrice, date, occ1, occ2, spec1, spec2 from letInputs2, ce_total, target_total, finalPrice, firstOcc, secondOcc, firstSpec, secondSpec;
quit;


/*proc sql;*/
/*select * from listMatchTracker;*/
/*quit;*/

proc export data=listMatchTracker outfile="&filepath.\ListMatch_Tracker_Info.csv" dbms=csv replace; run;
