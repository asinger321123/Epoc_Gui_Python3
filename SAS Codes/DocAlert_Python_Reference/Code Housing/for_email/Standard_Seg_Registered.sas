************************************************************************************************
* CODE NAME: PS_NPI_ME_3PT_Segment_Pricing                                                     *
* AUTHOR: Adam Rubin                                                                           *
* CREATION DATE: 20170109                                                                      *
* MACRO VERSION: 1.0                                                                           *
* PURPOSE: Price Client List by NPI or ME or 3PT and shows matched counts and price by segment *
*                                                                                              *
* REVISIONS:                                                                                   *
*  VERSION        DATE       AUTHOR              DESCRIPTION                                   *
*  -------      ---------  	--------        ----------------------                             *
*   4.0	        20170831   Adam Rubin       Updated Rate Card Sheet                            *
************************************************************************************************;

*NEED TO UPDATE ***************                              ***********************************;


options source source2 notes date center;

%let mainCols = epoc_me, epoc_npi, epoc_fname, epoc_lname, epoc_zip;

/*****Put the location for the client file below******/


*******************Input target files and save to LMT library************************************************;

options compress=yes nonotes nosource;
/* three options: 1)pipe--columns are separated by '|' ; 
            	  2)csv-- coulmns are separated by ',' ; 
                  3)tab --columns are separated by tab */

	%let file_type = tab;
	%let keepvars= fname lname npi zip me &seg., &mainCols.; 

 %macro input_file;
 /* importing all columns as string to avoid missing of leading zero in ME or Zip */
     proc import datafile="&filepath.\target.txt" 
                 out=target_import replace 
     %if %upcase(&file_type)=PIPE  %then %do; dbms=dlm; delimiter='|'; %end;
     %else %if %upcase(&file_type)=CSV   %then %do; dbms=csv; %end;
     %else %if %upcase(&file_type)=TAB   %then %do; dbms=dlm; delimiter='09'x; %end; 
     guessingrows=50000; getnames=yes; run; 

%mend; 

	 %input_file;

proc sql;
create table target_zips as
select * from target_import;
quit;

data target;
set target_zips;
length zip1 $5;
zip1=left(zip);
drop zip;
rename zip1=zip;
run;


proc sql;
  select count(*) into :fcount from (select distinct npi, fname, lname, me, zip from target);
quit;

data lmt.&rvp._&brand._&analyst._&sysdate._%trim(&fcount.);
  set target;
metype=vtype(me); 
run;

 %macro id_clean_up;

options source source2 notes date center;

Proc sql noprint;
Select distinct metype into :metype
from lmt.&rvp._&brand._&analyst._&sysdate._%trim(&fcount.);
quit;

data lm; set lmt.&rvp._&brand._&analyst._&sysdate._%trim(&fcount.); 
NPI_NEW= (npi*1);
drop npi;
rename NPI_NEW=npi;
specchar = ",<.>/?:;'\|[{]}!@#$%^&*()_-+=~`" || '" '; 
me_temp=me;
me_temp=compress(me,specchar);
run;


%if &metype=C %then %do;

data lma; set lm;
	me_temp=compress(me_temp,specchar);
          if compress(me_temp,"0123456789","d") = "" & me_temp ^= "" then me_temp2=put(input(me_temp,10.),z10.);
 run;
%end;

%else %if &metype=N %then %do; 

data lma; set lm;
	me_temp2=put(me_temp,z10.);
run;
%end;


%mend; 

	 %id_clean_up;

proc sql;
create table lmb_append as
select * from lma;
quit;

proc sql;
alter table lmb_append
add epoc_me char(50), epoc_npi numeric, epoc_fname char(50), epoc_lname char(50), epoc_zip char(50);
quit;

proc sql;
update lmb_append
set epoc_me=me_temp2, epoc_npi=npi, epoc_fname=fname, epoc_lname=lname, epoc_zip=zip;
quit;

Proc sql;
Create table lmb as 
Select me_temp2 as me, lname, fname, zip, npi, &seg., &mainCols. 
from lmb_append;
quit;


data lm1 lm2; set lmb;
  if NPI NE . then output lm1;
  else if NPI EQ . then output lm2;
run;

proc sql;
create table temp_customer_users_nppes as
select * from da.customer_user_nppes
where put(state_key,sk2sn.) NOT IN (&excludeStates.)
and put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific");
quit;

proc sql;
  create table new_lm1 as
  select w.*, cu.userid, cu.user_account_key, cu.primary_account_ind, cu.occupation_key, cu.specialty_key, cu.state_key, cu.last_session_dt, cu.country_key
	from lm1 w
  left join temp_customer_users_nppes cu on w.npi = cu.npi;
quit;

proc sql;
create table registered_npi_user as
select *
from new_lm1
where userid is not null;
quit;

proc sql;
create table CE_npi_user as
select *
from registered_npi_user
where primary_account_ind = "Y"
/*AND put(state_key,sk2sn.) NOT IN ("Vermont", "Colorado", "Europe,Mid East,Af,Can","Pacific")*/
and country_key = 947;
quit;

proc sql;
create table Not_CE_npi_user as
select *
from registered_npi_user
where primary_account_ind NOT = "Y"
/*or put(state_key,sk2sn.) in ('Vermont', 'Colorado')*/
or country_key NOT = 947;
quit;

proc sql;
create table nonmatched_npi_users as
select *
from new_lm1
where userid =.;
quit;

proc sql;
create table records_for_me as
select me, lname, fname, zip, &seg., &mainCols.
from lm2
union
select me, lname, fname, zip, &seg., &mainCols.
from not_CE_npi_user
union
select me, lname, fname, zip, &seg., &mainCols.
from nonmatched_npi_users
;quit;

/*matching on me num*/

data has_me_num no_me_num; set records_for_me;
  if ME NE . then output has_me_num;
  else if ME EQ . then output no_me_num;
run;

proc sql;
  create table new_lm3 as
  select w.*, cu.userid, cu.user_account_key, cu.primary_account_ind, cu.occupation_key, cu.specialty_key, cu.state_key, cu.verified_me_num, cu.last_session_dt, cu.country_key
	from has_me_num w
  left join temp_customer_users_nppes cu on w.me = cu.verified_me_num
;quit;

proc sql;
create table registered_me_user as
select *
from new_lm3
where userid is not null;
quit;

proc sql;
create table CE_me_user as
select *
from registered_me_user
where primary_account_ind = "Y"
/*AND put(state_key,sk2sn.) NOT IN ("Vermont", "Colorado", "Europe,Mid East,Af,Can","Pacific")*/
and country_key = 947;
quit;

proc sql;
create table Not_CE_me_user as
select *
from registered_me_user
where primary_account_ind NOT = "Y"
/*or put(state_key,sk2sn.) in ('Vermont', 'Colorado')*/
or country_key NOT = 947;
quit;

proc sql;
create table nonmatched_me_users as
select *
from new_lm3
where userid =.;
quit;

proc sql;
create table lmt.fuzzy_lm as
select lname, fname, zip, &seg., &mainCols.
from no_me_num
union
select lname, fname, zip, &seg., &mainCols.
from not_CE_me_user
union
select lname, fname, zip, &seg., &mainCols.
from nonmatched_me_users
;quit;


*-------------------------------------------------------------------------------------------*;
***LIST MATCH***;
***LIST MATCH PARAMETERS***;
%let epoxfile = USER BASE;                      ***HONORS PANEL or USER BASE                                                                                                              ***;
%let matchtype = inexact;                       ***MATCHTYPE=Exact, Inexact, Both  (DEFAULT=BOTH)                                                                               ***;
                                                            ***EXACT   : ID only Match (REQUIRE THAT ID BE PROVIDED                                                                        ***;
                                                          ***INEXACT : Fuzzy match only (REQUIRE THAT AT LEAST THE FNAME, LNAME, and ZIP BE PROVIDED)                     ***;
                                                            ***BOTH    : ID and Fuzzy match (REQUIRE THAT AT LEAST THE ID, FNAME, LNAME, and ZIP BE PROVIDED)         ***;
%let USER = MD OTHER;                           ***MD, OTHER, and/or STUDENT (DEFAULT is EITHER MD OTHER and STUDENT when matching to USER BASE
                                                             and MD OTHER and UNVERIFIED when matching to HONORS PANEL)                                                         ***;
                                                            ***MD      : Match MDs within                          ***;
                                                            ***OTHER   : Match Other Healthcase Professional             ***;
                                                            ***STUDENT : Match Students within User Base                 ***;
%let ACTIVEONLY = N;                          ***Y, N  (DEFAULT=N)                                                      ***;
                                                            ***Y           : Only active users will be matched          ***;
                                                            ***N       : Register (all users) will be matched       ***;
%let GROUPBY = ;                              ***Fields used to get subcounts                         ***;
%let ME = ;                                    ***ME Number                                            ***;
%let FNAME = fname;                                   ***First Name                                           ***;
%let LNAME = lname;                                 ***Last Name                                                                    ***;
%let ZIP = zip;   
*-------------------------------------------------------------------------------------------*;


%lmt(Data=lmt.fuzzy_lm
      ,Epoxfile=&epoxfile
      ,User=&user
      ,Matchtype=&matchtype
      ,Activeonly=&activeonly
      ,Groupby=&groupby
      ,ME=&me
      ,FName=&fname
      ,LName=&lname 
      ,Zip=&zip );


***RUN UP THRU HERE;

proc contents data=work._all_ directory out=temp (keep= libname memname) noprint; run;
proc sort data = temp nodupkey; by memname; run;

data temp; set temp; where upcase(memname) contains '_MATCHRESULTS_'; run;
proc sort data = temp; by libname memname; run;
data temp; set temp; by libname; if last.libname; run;

proc sql noprint; select memname into :lmtresults from temp; quit;
%put WARNING: &lmtresults;

data &lmtresults; set &lmtresults; run;



PROC SQL;
  CREATE TABLE customlist AS
  SELECT distinct userid, occupation_key, specialty_key, &seg., &mainCols.
  FROM &lmtresults 
WHERE _dupclientrecord_ = 0 AND _dupbaserecord_ = 0 AND _match_ = 1;
QUIT;

proc sql;
create table customlist2 as
select a.*, b.last_session_dt, b.primary_account_ind, b.state_key, b.country_key
from customlist a 
left join temp_customer_users_nppes b on a.userid=b.userid
;quit;

proc sql;
create table CE_fuzzy_user as
select *
from customlist2
where primary_account_ind = "Y"
/*AND put(state_key,sk2sn.) NOT IN ("Vermont", "Colorado", "Europe,Mid East,Af,Can","Pacific")*/
and country_key = 947;
quit;


proc sql;
create table temp_users1 as
select userid, &seg., &mainCols.
from CE_fuzzy_user
union
select userid, &seg., &mainCols.
from CE_me_user
union
select userid, &seg., &mainCols.
from CE_npi_user
;quit;


proc sql;
create table registered_users as
select distinct a.*, b.occupation_key, b.specialty_key 
from temp_users1 a 
inner join temp_customer_users_nppes b on a.userid=b.userid
where b.primary_account_ind = "Y"
/*AND put(b.state_key,sk2sn.) NOT IN ("Vermont", "Colorado", "Europe,Mid East,Af,Can","Pacific")*/
and country_key = 947;
quit;

%macro suppression; 
%do i=1 %to 1;

%if &suppression = Yes %then %do;

proc sql;
create table registered_users_1 as
select distinct a.*
from registered_users a
left join supp._supp_%trim(&suppcount.) b on a.userid = b.userid
where b.userid IS NULL;
quit;
%end;

%else %if &suppression = No %then %do;
data registered_users_1;
set registered_users;
run;
%end;

%end;
%mend;
%suppression;

proc sql;
create table nonDupUsers as
select distinct a.*, cats(epoc_fname,epoc_lname,epoc_zip) as combo
from registered_users_1 a
inner join temp_customer_users_nppes (keep = userid user_account_key last_session_dt) b on a.userid=b.userid
group by a.epoc_me, a.epoc_npi, combo
having count(a.epoc_me) < 2 and count(a.epoc_npi) < 2 and count(combo) < 2;
quit;

proc sql;
create table latestDupUsers as
select distinct a.*, cats(epoc_fname,epoc_lname,epoc_zip) as combo, last_session_dt
from registered_users_1 a
inner join temp_customer_users_nppes (keep = userid user_account_key last_session_dt) b on a.userid=b.userid
group by a.epoc_me, a.epoc_npi, combo
having (count(a.epoc_me) > 1 or count(a.epoc_npi) > 1) and count(combo) > 1 and last_Session_dt = max(last_Session_dt)
order by a.epoc_me DESC;
quit;

proc sort data=latestDupUsers out=singleUsers dupout=mydups nodupkey;
by epoc_me epoc_npi combo;
run;

proc sql;
create table final as
select * from nonDupUsers
union
select * from latestDupUsers
where userid not in (select userid from mydups);
quit;

proc sql noprint;
select count(userid) into :ncount from final;
quit;

proc sort data = final out=lmt._matched_%trim(&ncount.) nodupkey; by userid occupation_key specialty_key; run;

proc sql noprint;
select count(*) into :client_file_count from lm;
select count(userid) into :campaign_eligible from lmt._matched_%trim(&ncount.);
quit;

%put WARNING:  ;
%put WARNING:  ;
%put WARNING:  ;

%put WARNING: There are &client_file_count. records in the client file.;
%put  ;
%put WARNING: There are &campaign_eligible. campaign eligible matches. ;

%put WARNING:  ;
%put WARNING:  ;
%put WARNING:  ;

proc sql;
create table usr_profile as
select 
distinct userid,
case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
from lmt._matched_%trim(&ncount.) t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;



data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

proc sql;
create table rate1 as
select a.occspec, count(a.userid) as users, b.rate
from usr_profile a
left join rate_card b on a.occspec = b.occspec
group by 1,3;
quit;

data price1; set rate1; price = users*rate; run;

proc sql;
create table tempm as
select sum(price) as list_price from price1;
quit;

%macro LM_Pricing; 
%do i=1 %to 1;
	%if &Product = DocAlert %then %do;
	proc sql;
	select list_price*1.2 as CL_Price into :p1 from tempm;
	select sum(users) as CL_Count into :c1 from price1;
	quit;
	%end;
	
	%if &Product = Epoc_Quiz %then %do;
	proc sql;
	select list_price*1.2*1.25 as CL_Price into :p1 from tempm;
	select sum(users) as CL_Count into :c1 from price1;
	quit;
	%end;

	%if &Product = Triggered %then %do;
	proc sql;
	select list_price*1.2*1.15 as CL_Price into :p1 from tempm;
	select sum(users) as CL_Count into :c1 from price1;
	quit;
	%end;
%end;
%mend;
%LM_Pricing;

%put &p1;
%put &c1;

proc sql;
create table target_total as
select 'Target Total',count(*) as target_total, '                                   ' into :target_total from (select distinct npi, lname, fname, me, zip from target);
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

/*proc export data=what_we_need outfile="&filepath.\&brand._what_we_need.csv" dbms=csv replace; run;*/

proc freq data=lmt._matched_%trim(&ncount.);TITLE1 "Client List Occupation Breakout"; tables occupation_key / out=occ; run; TITLE1;

proc freq data=lmt._matched_%trim(&ncount.)  order=freq; TITLE2 "Client List Specialty Breakout"; tables specialty_key / out=spec; where put(occupation_key,ok2on.) IN ("MD","DO");
run; TITLE2;

/*new tracker attempt*/
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

proc freq data=lmt._matched_%trim(&ncount.) noprint;
tables &seg_nocommas. / out=table9;
run;

%macro pivot_table;
%do i=1 %to 1;

	%if &createPivotTable. = Y %then %do;
		proc template;
			define crosstabs Base.Freq.CrossTabFreqs;
				define header tableof;
					text "Segment Cross Tab Results";
			end;
			define header rowsheader;
				text _row_label_ / _row_label_ ^= ' ';
				text _row_name_;
			end; 

			define header colsheader;
				text _col_label_ / _col_label_ ^= ' ';
				text _col_name_;
			end;
			cols_header=colsheader;
			rows_header=rowsheader;
			header tableof;
			end;
		run;

		/*Replace Segment1 and Segment2 with proper segments for pivot/cross tab chart then save the code Its ok to overwrite the file that how it has to work*/
		proc freq data=lmt._matched_%trim(&ncount.);
		tables &pivSeg1.*&pivSeg2. / norow nocol nopercent;
		run;
	%end;
%end;
%mend;
%pivot_table;

PROC SQL;
CREATE TABLE usr_profile4 as 
select distinct	t.&seg., 
	t.userid, 
	case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as OCCSPEC
from lmt._matched_%trim(&ncount.) t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;


%macro pricing;

%local i pricing;
%do i=1 %to %sysfunc(countw(&seg_nocommas));
   %let pricing = %scan(&seg_nocommas, &i);

proc sql;
create table target_total_dedup as
select distinct npi, lname, fname, me, zip, &seg. from target;
quit;

proc freq data=target_total_dedup noprint;
tables &pricing. / out=&pricing._target nopercent norow nocol;
run;

proc freq data=lmt._matched_%trim(&ncount.) noprint;
tables &pricing. / out=&pricing._table nopercent norow nocol;
run;

proc sql;
create table occspeccount4 as
select distinct &pricing, occspec, count(userid) as ncount 
from usr_profile4
group by 1,2;
quit;

proc sql;
create table price4 as
select &pricing, a.occspec, b.rate, rate*ncount as lmrate
from occspeccount4 a
left join rate_card  b on a.occspec=b.occspec;
quit;

%if &Product = DocAlert %then %do;
proc sql;
create table &pricing._Price as
select distinct a.&pricing as Client_Segment, c.count as target_users, b.count as matched_users, b.count/c.count as match_rate, (1000 * (CEIL(sum(a.lmrate)*1.2/1000))) as list_price
from price4 a
inner join &pricing._table b on a.&pricing=b.&pricing
inner join &pricing._target c on a.&pricing=c.&pricing
group by 1
order by matched_users desc
;quit;
%end;

%if &Product = DocAlert %then %do;
proc sql;
create table &pricing._Price2 as
select distinct a.&pricing as Client_Segment, c.count as target_users, b.count as matched_users, sum(a.lmrate)*1.2 as list_price, (b.count/c.count) as match_rate
from price4 a
inner join &pricing._table b on a.&pricing=b.&pricing
inner join &pricing._target c on a.&pricing=c.&pricing
group by 1
;quit;
%end;

%if &Product = Epoc_Quiz %then %do;
proc sql;
create table &pricing._Price as
select distinct a.&pricing as Client_Segment, c.count as target_users, b.count as matched_users, b.count/c.count as match_rate, (1000 * (CEIL(sum(a.lmrate)*1.2*1.25/1000))) as list_price
from price4 a
inner join &pricing._table b on a.&pricing=b.&pricing
inner join &pricing._target c on a.&pricing=c.&pricing
group by 1
order by matched_users desc
;quit;
%end;

%if &Product = Epoc_Quiz %then %do;
proc sql;
create table &pricing._Price2 as
select distinct a.&pricing, c.count as target_users, b.count as matched_users, sum(a.lmrate)*1.2*1.25 as list_price, (b.count/c.count) as match_rate
from price4 a
inner join &pricing._table b on a.&pricing=b.&pricing
inner join &pricing._target c on a.&pricing=c.&pricing
group by 1
;quit;
%end;

%if &Product = Triggered %then %do;
proc sql;
create table &pricing._Price as
select distinct a.&pricing as Client_Segment, c.count as target_users, b.count as matched_users, b.count/c.count as match_rate, (1000 * (CEIL(sum(a.lmrate)*1.2*1.15/1000))) as list_price
from price4 a
inner join &pricing._table b on a.&pricing=b.&pricing
inner join &pricing._target c on a.&pricing=c.&pricing
group by 1
order by matched_users desc
;quit;
%end;

%if &Product = Triggered %then %do;
proc sql;
create table &pricing._Price2 as
select distinct a.&pricing, c.count as target_users, b.count as matched_users, sum(a.lmrate)*1.2*1.15 as list_price, (b.count/c.count) as match_rate
from price4 a
inner join &pricing._table b on a.&pricing=b.&pricing
inner join &pricing._target c on a.&pricing=c.&pricing
group by 1
;quit;
%end;

data &pricing._Price1;
set &pricing._Price;
format target_users comma10.;
format matched_users comma10.;
format list_price dollar10.;
format match_rate percent10.;
run;

proc print data=&pricing._Price2 noobs;
run;

proc print data=&pricing._Price noobs;
format target_users comma10.
format matched_users comma10.
format list_price dollar10.
format match_rate percent10.
run;



proc export data=work.&pricing._Price outfile="&filepath.\&pricing._Price.csv" dbms=csv replace; run;

%end;
%mend;
%pricing;

