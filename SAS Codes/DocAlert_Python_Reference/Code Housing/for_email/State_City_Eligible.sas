
%let spec_occs = "PsychiatryMD_DO",  
"PsychiatryNP_PA", 
"Obstetrics/GynecologyMD_DO", 
"Obstetrics/GynecologyNP_PA";

%let whole_states = "Alabama",
"Illinois",
"Indiana",
"Kentucky",
"Louisiana",
"Mississippi",
"North Dakota",
"New Jersey",
"New York",
"Ohio",
"Pennsylvania",
"Tennessee";

%let city_states = "Arkansas",
"Arizona",
"California",
"Colorado",
"District of Columbia",
"Delaware",
"Florida",
"Georgia",
"Hawaii",
"Iowa",
"Idaho",
"Michigan",
"Minnesota",
"Missouri",
"Nevada",
"North Carolina",
"Oklahoma",
"Rhode Island",
"South Carolina",
"South Dakota",
"Texas",
"Utah",
"Virginia",
"Wisconsin";

%let cities_in_states = "Little Rock_Arkansas",
"North Little Rock_Arkansas",
"Conway_Arkansas",
"Phoenix_Arizona",
"Mesa_Arizona",
"Scottsdale_Arizona",
"Tucson_Arizona",
"Los Angeles_California",
"Long Beach_California",
"Santa Ana_California",
"Sacramento_California",
"Arden_California",
"Arcade_California",
"Roseville_California",
"Washington_District of Columbia",
"Wilmington_Delaware",
"Miami_Florida",
"Fort Lauderdale_Florida",
"Pompano Beach_Florida",
"Orlando_Florida",
"Kissimmee_Florida",
"Jacksonville_Florida",
"Deltona_Florida",
"Daytona Beach_Florida",
"Ormond Beach_Florida",
"Naples_Florida",
"Marco Island_Florida",
"Gainesville_Florida",
"Atlanta_Georgia",
"Sandy Springs_Georgia",
"Marietta_Georgia",
"Savannah_Georgia",
"Honolulu_Hawaii",
"Iowa City_Iowa",
"Coeur d'Alene_Idaho",
"Detroit_Michigan",
"Warren_Michigan",
"Livonia_Michigan",
"Ann Arbor_Michigan",
"Saginaw_Michigan",
"Saginaw Township North_Michigan",
"Battle Creek_Michigan",
"Minneapolis_Minnesota",
"St. Paul_Minnesota",
"Bloomington_Minnesota",
"St. Louis_Missouri",
"Kansas City_Missouri",
"Columbia_Missouri",
"Charlotte_North Carolina",
"Gastonia_North Carolina",
"Concord_North Carolina",
"Durham_North Carolina",
"Las Vegas_Nevada",
"Paradise_Nevada",
"Oklahoma City_Oklahoma",
"Providence_Rhode Island",
"New Bedford_Rhode Island",
"Fall River_Rhode Island",
"Charleston_South Carolina",
"North Charleston_South Carolina",
"Sioux Falls_South Dakota",
"Rapid City_South Dakota",
"City_Whole State",
"Dallas_Texas",
"Fort Worth_Texas",
"Arlington_Texas",
"Houston_Texas",
"Sugar Land_Texas",
"Baytown_Texas",
"San Antonio_Texas",
"Austin_Texas",
"Round Rock_Texas",
"Salt Lake City_Utah",
"Provo_Utah",
"Orem_Utah",
"Ogden_Utah",
"Clearfield_Utah",
"Arlington_Virginia",
"Alexandria_Virginia",
"Joliet_Wisconsin",
"Madison_Wisconsin";


LIBNAME LMT "&filepath.";

/*Whole State Eligible*/
proc sql;
Create table eligilbe_by_whole_state as
Select userid, state_key, occupation_key, specialty_key, me_num, npi, last_session_dt
from da.customer_user_nppes
where last_session_dt GE today()-180
and primary_account_ind = "Y"
and put(state_key,sk2sn.) in (&whole_states.)
and put(state_key,sk2sn.) NOT IN ('Vermont', 'Colorado')
and country_key = 947
order by state_key;
quit;


proc sql;
alter table eligilbe_by_whole_state
add spec_occ2 char(50);
quit;

proc sql;
update eligilbe_by_whole_state
set spec_occ2 = "MD_DO"
where put(occupation_key, OK2ON.) = "MD" or put(occupation_key, OK2ON.) = "DO";
quit;

proc sql;
update eligilbe_by_whole_state
set spec_occ2 = "NP_PA"
where put(occupation_key, OK2ON.) = "NP" or put(occupation_key, OK2ON.) = "PA";
quit;

proc sql;
create table eligilbe_by_whole_state_2 as
select userid, state_key, occupation_key, specialty_key, CATS(put(specialty_key, SK2S2X.), spec_occ2) as spec_occ
FROM eligilbe_by_whole_state;
quit;

proc sql;
create table eligilbe_by_whole_state_final as
select userid, state_key, occupation_key, specialty_key, state_key
FROM eligilbe_by_whole_state_2
where spec_occ in (&spec_occs.)
group by state_key, spec_occ;
quit;


/*City State Eligible*/
proc sql;
Create table eligilbe_by_city_state as
Select userid, state_key, city, occupation_key, specialty_key, me_num, npi, last_session_dt
from da.customer_user_nppes
where last_session_dt GE today()-180
and primary_account_ind = "Y"
and put(state_key,sk2sn.) in (&city_states.)
and put(state_key,sk2sn.) NOT IN ('Vermont', 'Colorado')
and country_key = 947
order by state_key;
quit;

proc sql;
alter table eligilbe_by_city_state
add city_state char(100);
quit;

proc sql;
update eligilbe_by_city_state
set city_state = CATS(city, '_', put(state_key,sk2sn.));
quit;

proc sql;
create table eligilbe_by_city_state_2 as
select userid, state_key, occupation_key, specialty_key, state_key, city_state
FROM eligilbe_by_city_state
where city_state in (&cities_in_states.);
quit;

proc sql;
alter table eligilbe_by_city_state_2
add spec_occ2 char(50);
quit;

proc sql;
update eligilbe_by_city_state_2
set spec_occ2 = "MD_DO"
where put(occupation_key, OK2ON.) = "MD" or put(occupation_key, OK2ON.) = "DO";
quit;

proc sql;
update eligilbe_by_city_state_2
set spec_occ2 = "NP_PA"
where put(occupation_key, OK2ON.) = "NP" or put(occupation_key, OK2ON.) = "PA";
quit;

proc sql;
create table eligilbe_by_city_state_3 as
select userid, state_key, occupation_key, specialty_key, CATS(put(specialty_key, SK2S2X.), spec_occ2) as spec_occ
FROM eligilbe_by_city_state_2;
quit;

proc sql;
create table eligilbe_by_city_state_final as
select userid, state_key, occupation_key, specialty_key, state_key
FROM eligilbe_by_city_state_3
where spec_occ in (&spec_occs.)
group by state_key, spec_occ;
quit;

proc sql;
create table final_1 as
select * from eligilbe_by_whole_state_final
union
select * from eligilbe_by_city_state_final;
quit;

proc sort data = final_1 out=final nodupkey; by userid occupation_key specialty_key; run;

proc sql noprint;
select count(userid) into :ncount from final;
quit;

proc sort data = final out=lmt._matched_%trim(&ncount.) nodupkey; by userid occupation_key specialty_key; run;

proc sql noprint;
select count(*) into :client_file_count from final;
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
	select list_price*1.2*1.00 as CL_Price into :p1 from tempm;
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
select 'Target Total',count(*) as target_total, '                                   ' into :target_total from (select distinct userid, occupation_key, specialty_key from final);
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

proc freq data=lmt._matched_%trim(&ncount.); TITLE1 "Client List Occupation Breakout"; tables occupation_key / out=occ; run; TITLE1;

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

proc sql;
  select count(*) as Target_List_Count into :fcount from (select distinct userid, occupation_key, specialty_key from final);
quit;