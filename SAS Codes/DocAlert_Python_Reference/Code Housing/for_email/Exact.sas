************************************************************************************************
* CODE NAME: PS_NPI_ME_Exact                                                                   *
* AUTHOR: Adam Rubin                                                                           *
* CREATION DATE: 20170109                                                                      *
* MACRO VERSION: 1.0                                                                           *
* PURPOSE: Price Client List by NPI or ME                                                      *
*                                                                                              *
* REVISIONS:                                                                                   *
*  VERSION        DATE       AUTHOR              DESCRIPTION                                   *
*  -------      ---------  	--------        ----------------------                             *
*   3.0	        20170223   Adam Rubin       Updated Rate Card Sheet                            *
************************************************************************************************;

*NEED TO UPDATE ***************                              ***********************************;

options source source2 notes date center;

%let mainCols = epoc_me, epoc_npi;

/*%lmtassign_p(projectfolder=Epocrates Analytics\List Match\RyanO\JR_Januvia_092214); */

*******************Input target files and save to LMT library************************************************;

options compress=yes nonotes nosource;
/* three options: 1)pipe--columns are separated by '|' ; 
            	  2)csv-- coulmns are separated by ',' ; 
                  3)tab --columns are separated by tab */

	%let file_type = tab;
	%let keepvars= npi me;

 %macro input_file;
 /* importing all columns as string to avoid missing of leading zero in ME or Zip */
     proc import datafile="&filepath.\target.txt" 
                 out=target replace 
     %if %upcase(&file_type)=PIPE  %then %do; dbms=dlm; delimiter='|'; %end;
     %else %if %upcase(&file_type)=CSV   %then %do; dbms=csv; %end;
     %else %if %upcase(&file_type)=TAB   %then %do; dbms=dlm; delimiter='09'x; %end; 
     guessingrows=50000; getnames=yes; run; 

%mend; 

	 %input_file;

proc sql;
  select count(*) into :fcount from (select distinct npi, me from target);
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
add epoc_me char(50), epoc_npi numeric;
quit;

proc sql;
update lmb_append
set epoc_me=me_temp2, epoc_npi=npi;
quit;

Proc sql;
Create table lmb as 
Select me_temp2 as me, npi, &mainCols.
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
where last_session_dt GE &user_lookup_date.-180
and last_session_dt LE &user_lookup_date.
and primary_account_ind = "Y"
/*AND put(state_key,sk2sn.) NOT IN ("Vermont", "Colorado", "Europe,Mid East,Af,Can","Pacific")*/
and country_key = 947;
quit;

proc sql;
create table Not_CE_npi_user as
select *
from registered_npi_user
where last_session_dt LT &user_lookup_date.-180
or primary_account_ind NOT = "Y"
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
select me, &mainCols.
from lm2
union
select me, &mainCols.
from not_CE_npi_user
union
select me, &mainCols.
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
where last_session_dt GE &user_lookup_date.-180
and last_session_dt LE &user_lookup_date.
and primary_account_ind = "Y"
/*AND put(state_key,sk2sn.) NOT IN ("Vermont","Europe,Mid East,Af,Can","Pacific")*/
and country_key = 947;
quit;

proc sql;
create table temp_users1 as
select userid, &mainCols.
from CE_me_user
union
select userid, &mainCols.
from CE_npi_user
;quit;

proc sql;
create table registered_users as
select distinct a.*, b.occupation_key, b.specialty_key, &mainCols., b.last_session_dt
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

/*proc sql;*/
/*create table final as*/
/*select distinct a.* from registered_users_1 a*/
/*inner join temp_customer_users_nppes (keep = userid user_account_key last_session_dt) b on a.userid=b.userid*/
/*	where last_session_dt GE today()-180;*/
/*quit;*/

proc sql;
create table nonDupUsers as
select distinct a.*
from registered_users_1 a
inner join temp_customer_users_nppes (keep = userid user_account_key last_session_dt) b on a.userid=b.userid
where b.last_session_dt GE &user_lookup_date.-180
and b.last_session_dt LE &user_lookup_date.
group by a.epoc_me, a.epoc_npi
having count(a.epoc_me) < 2 and count(a.epoc_npi) < 2;
quit;

proc sql;
create table latestDupUsers as
select distinct a.*, b.last_session_dt
from registered_users_1 a
inner join temp_customer_users_nppes (keep = userid user_account_key last_session_dt) b on a.userid=b.userid
where b.last_session_dt GE &user_lookup_date.-180
and b.last_session_dt LE &user_lookup_date.
group by a.epoc_me, a.epoc_npi
having (count(a.epoc_me) > 1 or count(a.epoc_npi) > 1) and b.last_Session_dt = max(b.last_Session_dt)
order by a.epoc_me DESC;
quit;

proc sort data=latestDupUsers out=singleUsers dupout=mydups nodupkey;
by epoc_me epoc_npi;
run;

proc sql;
create table pre_final as
select * from nonDupUsers
union
select * from latestDupUsers
where userid not in (select userid from mydups);
quit;

%macro queryStateZip;
%do i=1 %to 1;
	%if &applyToClientList. = Yes %then %do;
		%if &queryByState. = Yes %then %do;
			proc sql;
			create table final as
			Select a.*, b.state_key FROM pre_final a
			inner join temp_customer_users_nppes b
			on a.userid=b.userid
			where put(state_key,sk2sn.) in (&statesToQuery.);
			quit;
		%end;

		%if &queryByZip. = Yes %then %do;
			proc import datafile="&filepath.\zipsImport.csv"
			     out=zip_import
			     dbms=csv
			     replace;
			GUESSINGROWS=100000;
			run;

			data zips;
			set zip_import;
			postal_code=put(zipcode,z5.);
			run;

			proc sql;
			create table final as
			Select a.*, b.postal_code FROM pre_final a
			inner join temp_customer_users_nppes b
			on a.userid=b.userid
			where b.postal_code in (Select postal_code from zips);
			quit;	
		%end;
	%end;

	%else %if &applyToClientList. ne Yes %then %do;
		data final;
		set pre_final;
		run;
	%end;
%end;
%mend;
%queryStateZip;

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

%macro Pricing; 
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
%Pricing;


%put &p1;
%put &c1;

proc sql;
create table target_total as
select 'Target Total',count(*) as target_total, '                                   ' into :target_total from (select distinct npi, me from target);
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

proc freq data=lmt._matched_%trim(&ncount.); TITLE1 "Client List Occupation Breakout"; tables occupation_key / out=occ;; run; TITLE1;

proc freq data=lmt._matched_%trim(&ncount.)  order=freq; TITLE2 "Client List Specialty Breakout"; tables specialty_key specialty_key / out=spec; where put(occupation_key,ok2on.) IN ("MD","DO")
;run; TITLE2;

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