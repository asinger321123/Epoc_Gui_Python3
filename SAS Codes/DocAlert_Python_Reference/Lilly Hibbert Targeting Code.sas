options source source2 notes date center;

/*TARGETING INPUTS*/
%let Product= /*DocORQuiz*/; /*(DocAlert/Epoc_Quiz)*/
%let filepath = /*target_text_file*/; /*Ex: P:\Epocrates Analytics\TARGETS\01-21-19\Merck Emend\T-44460_    1876.csv*/
%let folder = /*targetFoler*/;
%let dump = P:\Epocrates Analytics\TARGETS\/*Date*/\targetdump;
%let target_numbers= /*TargetNum*/; /*Can be 1 or Multiple. IF MULTIPLE YOU MUST SEPARATE WITH A SPACE*/
%let lookupdate = /*activeUserDate*/;

%let client_list = Y; /*(Y/N)*/

/*CLIENT LIST DATASHARING*/
%let DataSharing = /*dataShareYorN*/;/*(Y/N)*/
%let seg=npi,
Address1,
campaign_Type,
City,
cl_fname,
cl_lname,
Cl_me,
cl_zip,
ClientID,
CompasID,
middle_name,
Segment1,
Specialty,
State_Code,
Tier,
Segment2,
Segment3;  /***Separate all DataSharing columns with a comma + space. Include the 'variable' column header here too if the client list is being segmented, .***/
%let keep_segment_variable= No; /*If you need the 'variable' column for DataSharing then = (Yes); if you need to drop it then = (No);*/
%let Manufacturer = Lilly;   /*Input the manufacturer as it appears in the custom folder*/


%macro active_user_lookup_date;
%global user_lookup_date;

	%if &lookupdate. = "" %then %do;
		%let user_lookup_date = TODAY();
		%put &user_lookup_date.;

	%end;

	%else %if &lookupdate. ne "" %then %do;
		data test;
		pastdate = &lookupdate.;
		look_back_date = input(pastdate, mmddyy10.);
		run;

		proc sql;
		select look_back_date into :user_lookup_date FROM test;
		quit;

		%put &user_lookup_date.;
	%end;

%mend;
%active_user_lookup_date;

data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

/* three options: 1)pipe--columns are separated by '|' ; 
            	  2)csv-- coulmns are separated by ',' ; 
                  3)tab --columns are separated by tab */

	%let file_type = tab;
	%let keepvars= fname lname npi zip me &seg.; 

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
  select count(*) as Client_List_Record_Count into :fcount  from (select distinct userid from target_import);
quit;

proc sql;
create table bb as
select distinct a.userid, a.*, b.occupation_key, b.specialty_key
from target_import a
inner join da.customer_user_nppes b on a.userid=b.userid
where last_session_dt GE (&user_lookup_date.-180)
and last_session_dt LE &user_lookup_date.
and primary_account_ind = "Y"
and put(country_key,CK2COUN.) = "United States of America"
and put(state_key,sk2sn.) NOT IN ("Vermont","Colorado","Europe,Mid East,Af,Can","Pacific")
;
quit;

proc freq data = bb; tables occupation_key / out = target_freq2; run;

/*adjust "MD" or "DO" occupation to "MD/DO"*/
proc sql;
		create table target_profile as
		select distinct userid,	case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
		from bb t 
		left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
		inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
		quit;

		proc sql noprint;
		select count(userid) into :num from target_profile;
		quit;

		proc freq data = target_profile; tables occspec / out = target_freq; run;

		proc sql;
		create table target_rate as
		select a.occspec, a.count, b.rate
		from target_freq a
		left join rate_card b on a.occspec = b.occspec;
		quit;

%macro price; 
		%if &Product. = DocAlert %then %do;
			%if &client_list. = Y %then %do;
				data target_price; set target_rate; price = rate*count*1.2; run;
			%end;

			%else %if &client_list. = N %then %do;
				data target_price; set target_rate; price = rate*count; run;
			%end;
		%end;

		%if &Product. = Epoc_Quiz %then %do;
			%if &client_list. = Y %then %do;
				data target_price; set target_rate; price = rate*count*1.2*1.25; run;
			%end;

			%else %if &client_list. = N %then %do;
				data target_price; set target_rate; price = rate*count*1.25; run;
			%end;
		%end;

		proc sql;
		select sum(price) as target_price into :bp from target_price;
		select sum(count) as target_count into :bc from target_price;
		quit;

		%put &bp;
		%put &bc;
%mend;
%Price;

proc sql;
create table final1 as
select distinct userid
from bb;
quit;

proc sql noprint;
select count(userid) into :m from final1;
quit;

proc export data=work.final1 outfile="&folder.\&target_numbers._&m..csv" dbms=csv replace; putnames = no; run;
proc export data=work.final1 outfile="&dump.\&target_numbers._&m..csv" dbms=csv replace; putnames = no; run;


%macro Datasharing;
%do i=1 %to 1;
	%if &DataSharing.= Y and &Manufacturer. ne Amgen %then %do;
	proc sql;
	create table final2 as
	select distinct userid, &seg. 
	from bb;
	quit;

	proc sql noprint;
	select count(userid) into :m2 from final2;
	quit;

	proc export data=work.final2 outfile="P:\Epocrates Analytics\Projects\RESTORE_2014-08-26\DataSharing\CUSTOM\&Manufacturer.\&target_numbers._&Manufacturer._DS_&m2..csv" dbms=csv replace; putnames = yes; run;
	%end;

	%if &DataSharing.= Y and &Manufacturer.= Amgen %then %do;
	proc sql;
	create table final2 as
	select distinct userid, &amgenSegs. 
	from bb;
	quit;

	proc sql noprint;
	select count(userid) into :m2 from final2;
	quit;

	proc export data=work.final2 outfile="P:\Epocrates Analytics\Projects\RESTORE_2014-08-26\DataSharing\CUSTOM\&Manufacturer.\&target_numbers._&Manufacturer._DS_&m2..csv" dbms=csv replace; putnames = yes; run;
	%end;

%end;
%mend;
%Datasharing;
