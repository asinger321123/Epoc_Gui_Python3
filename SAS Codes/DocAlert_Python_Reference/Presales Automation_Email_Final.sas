options mprint mlogic source source2 notes date center;
*************************************************;
/*CL INPUTS*/
%let Product= /*DocORQuiz*/; /*(DocAlert/Epoc_Quiz)*/
%let list_match_type = /*listMatchType*/; /*(Standard/Exact/Standard_Seg/Exact_Seg/Fuzzy)*/
%let filepath =/*target_text_file*/;
%let seg= /*Segments*/; /*	***Seperate each datasharing column/segment by comma***/
%let seg_nocommas= /*Segments2*/; /*	***Seperate each datasharing column/segment by comma***/
%let run_30_60_90 = /*run_30_60_90*/;
%let merck_organic_list = No;
%let lookupdate = /*activeUserDate*/;

/*Pivot Table Inputs*/
%let createPivotTable= /*createPivotTable*/;
%let pivSeg1 = /*pivYes1*/; /*Only fill out if createPivotTable = Y*/
%let pivSeg2 = /*pivYes2*/; /*Only fill out if createPivotTable = Y*/

/*State or Zip Inputs*/
%let excludeStates = /*statesToExclude*/;
%let applyToClientList = /*applyToClientList*/;
%let applyToSda = /*applyToSda*/;
%let applyToBda = /*applytoBda*/;
%let queryByState = /*queryStates*/;
%let queryByZip = /*queryZips*/;
%let statesToQuery = /*statesToQuery*/;

%let rvp = /*Requester_Initials*/;  /*Requester's initials*/
%let brand =/*Brand*/; /*Brand Name*/
%let analyst = /*MY_INIT*/; /*Your initials*/
*************************************************;
/*SUPPRESSION INPUTS*/
/*suppression file must be labeled supp.txt*/

%let suppression = /*suppApplied*/; /* Yes/No */
%let supp_filepath = /*supp_text_file*/; /*File location of supp.txt file, which must be different from the Target folder to avoid overwriting the target's _matched file. Example: P:\Epocrates Analytics\Individual\ARubin\New Codes\Test\supp*/
%let suppression_match_type = /*supp_Match_Type*/; /*(Standard/Exact)*/

*************************************************;
/*SDA INPUTS*/
%let totalSDAS = /*totalSDAS*/;
%let Sda_Only = /*sda_only*/; /*Only running SDA or SDA + BDA. (Y/N)*/
%let sda_occ= /*SDA_Occ*/; /*Specialty occupations listed with quotes and commas ("MD","DO")*/
%let sda_spec=/*SDA_Spec*/; /*Specialty specialties listed with quotes and commas ("Family Practice","Cardiology")*/
*************************************************;
/*BDA INPUTS*/
%let totalBDAS = /*totalBDAS*/;
%let therapy_class = /*therapyClass*/;
%let Bda_only = /*bda_only*/; /*Only running BDA. (Y/N)*/ 
%let Dedupe_from_Sda = /*yesORno*/;		/*Dedupe Dedupe from SDA (Yes/No)*/
%let bda_lookback_period = /*LookUpPeriod*/;	/*Insert Lookup Period for the Drugs (31)*/
%let drug_lookups_GE = /*totalLoookUps*/; 	/*Number of Lookups requested (1)*/
%let bda_occ = /*BDA_Occ*/; /*Behavioral Occupations listed with quotes and commas ("MD","DO")*/
%let bda_spec = /*BDA_Spec*/; /*Behavioral specialties listed with quotes and commas ("Family Practice","Cardiology")*/


/*Email inputs*/
%let caseno= /*caseno*/;
%let Manufacturer= /*manu*/;
%let PTMTCH=YES;
%let mtype= /*mtype*/;
%let SE= /*SE*/;
%let email_user= /*username*/;
%let sda_occ_nocom= /*sdaocc2*/;
%let bda_occ_nocom= /*bdaocc2*/;
%let dispPeriod= /*dispPeriod*/;
%let drugs= /*drugsnocomma*/;


/*Drug Tracker Info*/
%let filepath2 = "/*target_text_file*/";
%let caseno2= "/*caseno*/";
%let brand2 = "/*Brand*/";
data bda_drugs; input mk_drug $50.;   /*insert drug names underneath the "cards;" and above ";run;". No commas or quotes. The names will turn yellow. 1 drug per line.**/
cards;
/*drugList*/
;run;

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


LIBNAME LMT "&filepath.";
%macro CL_list; 
%global fcount;
%do i=1 %to 1;
%if &suppression = Yes %then %do;
	LIBNAME SUPP "&supp_filepath.";
	%if &suppression_match_type = Standard %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Presales\Supp_Standard.sas"; %end;
	%else %if &suppression_match_type = Exact %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Presales\Supp_Exact.sas"; %end;
data supp; set supp._supp_%trim(&suppcount.); run;
%end;

%if &list_match_type = Standard %then %do; %include "P:\Epocrates Analytics\Code_Library\Standard_Codes\Pre Sales\DocAlert_Python_Reference\Code Housing\for_email\Standard.sas"; %end;
%else %if &list_match_type=Standard_Seg  %then %do; %include "P:\Epocrates Analytics\Code_Library\Standard_Codes\Pre Sales\DocAlert_Python_Reference\Code Housing\for_email\Standard_Seg.sas"; %end;
%else %if &list_match_type=Exact  %then %do; %include "P:\Epocrates Analytics\Code_Library\Standard_Codes\Pre Sales\DocAlert_Python_Reference\Code Housing\for_email\Exact.sas"; %end;
%else %if &list_match_type=Exact_Seg  %then %do; %include "P:\Epocrates Analytics\Code_Library\Standard_Codes\Pre Sales\DocAlert_Python_Reference\Code Housing\for_email\Exact_Seg.sas"; %end;
%else %if &list_match_type=Fuzzy  %then %do; %include "P:\Epocrates Analytics\Code_Library\Standard_Codes\Pre Sales\DocAlert_Python_Reference\Code Housing\Fuzzy.sas"; %end;

%if &list_match_type. ne None %then %do;
data match; set lmt._matched_%trim(&ncount.); run;
%end;

%end;
%mend;
%CL_list;

data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

/*30 60 90 Counts*/
%macro get_30_60_90;
%do i=1 %to 1;
%if &list_match_type. ne None %then %do;
	proc sql;
	select count(distinct a.userid) as _90_Days_Active into :_90
	from match a
	inner join da.customer_user_nppes b on a.userid=b.userid
	where b.last_session_dt GE &user_lookup_date.-91 and b.last_session_dt LE &user_lookup_date.;
	select count(distinct a.userid) as _60_Days_Active into :_60
	from match a
	inner join da.customer_user_nppes b on a.userid=b.userid
	where b.last_session_dt GE &user_lookup_date.-61 and b.last_session_dt LE &user_lookup_date.;
	select count(distinct a.userid) as _30_Days_Active into :_30
	from match a
	inner join da.customer_user_nppes b on a.userid=b.userid
	where b.last_session_dt GE &user_lookup_date.-31 and b.last_session_dt LE &user_lookup_date.;
	quit;


	data _90;
	Days_Active="90 Days";
	Match_Count=&_90.;
	run;

	data _60;
	Days_Active="60 Days";
	Match_Count=&_60.;
	run;

	data _30;
	Days_Active="30 Days";
	Match_Count=&_30.;
	run;


	proc sql;
	create table all_active2 as
	select * from _90
	union all
	select * from _60
	union all
	select * from _30;
	quit;

	data all_active;
	set all_active2;
	format Match_Count comma8.;
	label Days_Active="Days Active";
	label Match_Count="Match Count";
	run;

	proc print data=all_active noobs;
	run;
%end;
%end;
%mend;
%get_30_60_90;

/*Add-On Macro*/
/*SDA*/
%macro Add_Ons; 
%do i=1 %to 1;
  %if &sda_occ. ne "" %then %do;
	%if &sda_spec. ne "" %then %do;
	proc sql;
	create table SDA as 
	select distinct userid, occupation_key, specialty_key, state_key, postal_code
	from da.customer_user_nppes
	where primary_account_ind = "Y"
	and put(country_key,CK2COUN.) = "United States of America"
	and last_session_dt GE (&user_lookup_date.-180)
	and last_session_dt LE &user_lookup_date.
	and put(specialty_key,SK2S2X.) in (&sda_spec.)
	and put(occupation_key, OK2ON.) in (&sda_occ.)
	AND put(state_key,sk2sn.) NOT IN (&excludeStates.)
	AND put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific")
	;quit;
	%end;

	%else %if &sda_spec. = "" %then %do;  
	proc sql;
	create table SDA as 
	select distinct userid, occupation_key, specialty_key, state_key, postal_code
	from da.customer_user_nppes
	where primary_account_ind = "Y"
	and put(country_key,CK2COUN.) = "United States of America"
	and last_session_dt GE (&user_lookup_date.-180)
	and last_session_dt LE &user_lookup_date.
	and put(occupation_key, OK2ON.) in (&sda_occ.)
	AND put(state_key,sk2sn.) NOT IN (&excludeStates.)
	AND put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific")
	;quit;
	%end;

	%if &suppression = No %then %do;
		%if &Sda_only. = N %then %do;
		Proc sql;
		create table sda_dedupe_1 as 
		select distinct a.*
		from sda a 
		left join match b on a.userid=b.userid
		where b.userid is null
		;quit;
		%end;

		%else %if &Sda_only. = Y %then %do;
		Proc sql;
		create table sda_dedupe_1 as 
		select distinct a.*
		from sda a 
		;quit;
		%end;
	%end;

	%else %if &suppression = Yes %then %do;
		%if &Sda_only. = N %then %do;
		Proc sql;
		create table sda_dedupe_1 as 
		select distinct a.*
		from sda a 
		left join match b on a.userid=b.userid
		left join supp c on a.userid=c.userid
		where b.userid is null
		and c.userid is null
		;quit;
		%end;

		%else %if &Sda_only. = Y %then %do;
		Proc sql;
		create table sda_dedupe_1 as 
		select distinct a.*
		from sda a 
		left join supp c on a.userid=c.userid
		where c.userid is null
		;quit;
		%end;
	%end;

	%if &applyToSda. = Yes %then %do;
		%if &queryByState. = Yes %then %do;
			proc sql;
			create table sda_dedupe as
			Select a.*, b.state_key FROM sda_dedupe_1 a
			inner join SDA b
			on a.userid=b.userid
			where put(b.state_key,sk2sn.) in (&statesToQuery.);
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
			create table sda_dedupe as
			Select a.*, b.postal_code FROM sda_dedupe_1 a
			inner join SDA b
			on a.userid=b.userid
			where b.postal_code in (Select postal_code from zips);
			quit;	
		%end;
	%end;

	%else %if &applyToSda. ne Yes %then %do;
		data sda_dedupe;
		set sda_dedupe_1;
		run;
	%end;

	proc sql;
	create table sda_profile as
	select distinct userid,
	case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
	from sda_dedupe t 
	left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
	inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
	quit;

/*	data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;*/

	proc freq data = sda_profile; tables occspec / out = sda_freq; run;

	proc sql;
	create table sda_rate as
	select a.occspec, a.count, b.rate
	from sda_freq a
	left join rate_card b on a.occspec = b.occspec;
	quit;

	%if &Product = DocAlert %then %do;
	data sda_price; set sda_rate; price = rate*count; run;
	%end;

	%if &Product = Epoc_Quiz %then %do;
	data sda_price; set sda_rate; price = rate*count*1.25; run;
	%end;

	%if &Product = Triggered %then %do;
	data sda_price; set sda_rate; price = rate*count*1.15; run;
	%end;

	proc sql;
	select sum(price) as SDA_price into :sdap1 from sda_price;
	select sum(count) as SDA_count into :sdac1 from sda_price;
	quit;

	/*Extra table created for generating my SDA Add on Results*/
	proc sql;
    create table sda_results as
    select sum(price) as SDA_price, sum(count) as SDA_count
	from sda_price;
    quit;

	%put &sdap1;
	%put &sdac1;
  %end;

Proc contents data=work._all_ noprint out=work_data;quit;run;

Proc sql;
Select distinct NOBS as number_of_drugs into :num_of_drugs
from work_data 
where MEMNAME = "BDA_DRUGS"
;quit; 

	%if &num_of_drugs. > 0  %then %do;
	/*BDA*/
		%if &therapy_class. = Yes %then %do;
			proc sql;
			create table drugs_from_class as
			select distinct m.mk_drug, x.DRUG_KEY, x.THERAPEUTIC_CLASS_KEY
			from bda_drugs m, uaw.drug_therapeuticclass_map x
			where put(x.THERAPEUTIC_CLASS_KEY, TCK2TCN.) in (select m.mk_drug from bda_drugs m)
			;quit;

			proc sql;
			create table drug_check as
			select distinct m.DRUG_KEY, z.drug_key, f.key_value
			from drugs_from_class m
			left join uaw.drug_dim z on m.DRUG_KEY = z.drug_key
			left join edwf.format_lookup f on f.key_value = z.drug_key
			;quit;
		%end;

		%if &therapy_class. = No %then %do;

			proc sql;
	  		create table drug_check as
	  		select distinct m.mk_drug, z.DRUG_KEY, f.key_value
	 	 	from bda_drugs m
			left join edwf.format_lookup f on m.mk_drug = f.label
		  	left join uaw.drug_dim z on f.key_value = z.drug_key
			where f.FMTNAME="DK2DN"
			;quit; 

			proc sql noprint;
			select count(mk_drug) as orig_drug_count into :input_drugs from bda_drugs;
			select count(distinct key_value) as final_drug_count into :output_drugs from drug_check;
			quit;

			proc sql;
			create table unmatchedDrugs as
			Select * from bda_drugs a
			left join drug_check b on a.mk_drug=b.mk_drug
			where b.mk_drug is null;
			quit;

			data final_drug_check;
			length Drug_Check $50;
			if &input_drugs. = &output_drugs. then Drug_Check = 'All Drugs found';
			else Drug_Check =  '**ERROR** 1 or more drugs are mispelled';
			run; 

		  	proc print data=unmatchedDrugs;
			run; 

			proc print data=final_drug_check noobs;
			run;

				%if &input_drugs. ne &output_drugs. %then %do;
				%abort cancel;
				%end;
		%end;

		proc sql noprint;
		select distinct key_value into : drug_keys separated by ','
		from drug_check;
		quit;

	/*	All users who looked up XX drugs*/
		%if &bda_occ. = "" and &bda_spec. = "" %then %do;
			proc sql;
			create table bda_filter1 as
			select user_account_key, occupation_key, specialty_key, userid, state_key, postal_code
			from da.customer_user_nppes
			where last_session_dt GE &user_lookup_date.-180
			and last_session_dt LE &user_lookup_date.
			and primary_account_ind = "Y"
			and put(country_key,CK2COUN44.) = "United States of America"
			AND put(state_key,sk2sn.) NOT IN (&excludeStates.)
			AND put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific")
			;quit;
		%end;

	/*	Only specific Occupations who looked up XX drugs*/
		%else %if &bda_occ. ne "" and &bda_spec. = "" %then %do;  
			proc sql;
			create table bda_filter1 as
			select user_account_key, occupation_key, specialty_key, userid, state_key, postal_code
			from da.customer_user_nppes
			where last_session_dt GE &user_lookup_date.-180
			and last_session_dt LE &user_lookup_date.
			and primary_account_ind = "Y"
			and put(country_key,CK2COUN44.) = "United States of America"
			and put(occupation_key,ok2on.) IN (&bda_occ)
			AND put(state_key,sk2sn.) NOT IN (&excludeStates.)
			AND put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific")
			;quit;
		%end;

	/*	Only specific Occupations AND Specialties who looked up XX drugs*/
		%if &bda_occ. ne "" and &bda_spec. ne "" %then %do;
			proc sql;
			create table bda_filter1 as
			select user_account_key, occupation_key, specialty_key, userid, state_key, postal_code
			from da.customer_user_nppes
			where last_session_dt GE &user_lookup_date.-180
			and last_session_dt LE &user_lookup_date.
			and primary_account_ind = "Y"
			and put(country_key,CK2COUN44.) = "United States of America"
			and put(occupation_key,ok2on.) IN (&bda_occ)
			and put(specialty_key,SK2S2X38.) in (&bda_spec)
			AND put(state_key,sk2sn.) NOT IN (&excludeStates.)
			AND put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific")
			;quit;
		%end;

		proc sql;
		create table bda_filter2 as
		select a.user_account_key, a.occupation_key, a.specialty_key, a.userid, b.drug_key, sum(sum_events) as lookups, a.state_key, a.postal_code
		from bda_filter1 a
		left join uaw.Drug_rx_1yr b on a.user_account_key = b.user_account_key
		where drug_key in (&drug_keys.)
		and b.event_date GE &user_lookup_date.-(&bda_lookback_period.)
		and b.event_date LE &user_lookup_date.
		group by 1
		;quit;

		proc sql;
		create table bda_filter3 as 
		select distinct a.user_account_key, b.*, a.state_key, a.postal_code
		from bda_filter2 a
		left join bda_filter1 b on a.user_account_key = b.user_account_key
		where lookups GE &drug_lookups_GE.
		;quit;

	%if &Bda_only. = Y %then %do;
		%if &suppression = No %then %do;
			Proc sql;
			create table bda_dedupe_1 as 
			select distinct a.*
			from bda_filter3 a 
			;quit;
		%end;

		%else %if &suppression = Yes %then %do;
			Proc sql;
			create table bda_dedupe_1 as 
			select distinct a.*
			from bda_filter3 a 
			left join supp b on a.userid=b.userid
			where b.userid is null
			;quit;
		%end;
	%end;

	%if &Bda_only. = N %then %do;
		%if &Dedupe_from_Sda. = No %then %do;
			%if &list_match_type. = None %then %do;
				%if &suppression = No %then %do;
					Proc sql;
					create table bda_dedupe_1 as 
					select distinct a.*
					from bda_filter3 a 
					;quit;
				%end;

				%else %if &suppression = Yes %then %do;
					Proc sql;
					create table bda_dedupe_1 as 
					select distinct a.*
					from bda_filter3 a 
					left join supp b on a.userid=b.userid
					where b.userid is null
					;quit;
				%end;
			%end;
			
			%else %if &list_match_type. ne None %then %do;

				%if &suppression = No %then %do;
					Proc sql;
					create table bda_dedupe_1 as 
					select distinct a.*
					from bda_filter3 a 
					left join match b on a.userid=b.userid
					where b.userid is null;
					quit;
				%end;

				%else %if &suppression = Yes %then %do;
					Proc sql;
					create table bda_dedupe_1 as 
					select distinct a.*
					from bda_filter3 a 
					left join match b on a.userid=b.userid
					left join supp c on a.userid=c.userid
					where b.userid is null
					and c.userid is null;
					quit;
				%end;
			%end;
		%end;
		%else %if &Dedupe_from_Sda. = Yes %then %do;
			%if &suppression = No %then %do;
				proc sql;
				create table cl_sda_users as
				select distinct userid
				from match
				union
				select distinct userid
				from sda_dedupe
				;quit;

				Proc sql;
				create table bda_dedupe_1 as 
				select distinct a.*
				from bda_filter3 a 
				left join cl_sda_users b on a.userid=b.userid
				where b.userid is null;
				quit;
			%end;

			%else %if &suppression = Yes %then %do;
				proc sql;
				create table cl_supp_sda_users as
				select distinct userid
				from match
				union
				select distinct userid
				from sda_dedupe
				union 
				select distinct userid
				from supp
				;quit;

				Proc sql;
				create table bda_dedupe_1 as 
				select distinct a.*
				from bda_filter3 a 
				left join cl_supp_sda_users b on a.userid=b.userid
				where b.userid is null;
				quit;
			%end;
		%end;
	%end;

	%if &applyToBda. = Yes %then %do;
		%if &queryByState. = Yes %then %do;
			proc sql;
			create table bda_dedupe as
			Select a.*, b.state_key FROM bda_dedupe_1 a
			inner join bda_filter3 b
			on a.userid=b.userid
			where put(b.state_key,sk2sn.) in (&statesToQuery.);
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
			create table bda_dedupe as
			Select a.*, b.postal_code FROM bda_dedupe_1 a
			inner join bda_filter3 b
			on a.userid=b.userid
			where b.postal_code in (Select postal_code from zips);
			quit;	
		%end;
	%end;

	%else %if &applyToBda. ne Yes %then %do;
		data bda_dedupe;
		set bda_dedupe_1;
		run;
	%end;

	proc sql;
	create table bda_profile as
	select distinct userid,	case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
	from bda_dedupe t 
	left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
	inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
	quit;

	proc sql noprint;
	select count(userid) into :num from bda_profile;
	quit;

	proc freq data = bda_profile; tables occspec / out = bda_freq; run;

	proc sql;
	create table bda_rate as
	select a.occspec, a.count, b.rate
	from bda_freq a
	left join rate_card b on a.occspec = b.occspec;
	quit;

	%if &Product = DocAlert %then %do;
	data bda_price; set bda_rate; price = rate*count; run;
	%end;

	%if &Product = Epoc_Quiz %then %do;
	data bda_price; set bda_rate; price = rate*count*1.25; run;
	%end;

	%if &Product = Triggered %then %do;
	data sda_price; set sda_rate; price = rate*count*1.15; run;
	%end;

	proc sql;
	select sum(price) as BDA_price into :bp from bda_price;
	select sum(count) as BDA_count into :bc from bda_price;
	quit;

	/*Extra table created for generating my BDA Add on Results*/
	proc sql;
    create table bda_results as
    select sum(price) as BDA_price, sum(count) as BDA_count
	from bda_price;
    quit;

	%put &bdap;
	%put &bdac;

	
%end;
%end;
%mend;
%Add_Ons;

%macro client_list_data;
%global MDDOFINAL;
%global OHCFINAL;
%global speccount;
%global finalpricetext1;
%global finalpricetext2;
%global prodType;
%do i=1 %to 1;
%if &list_match_type. ne None %then %do;
	proc sql noprint;
	  select count(distinct userid) into :c1 from match;
	quit;

	%macro Pricing;
	%global p1; 
	%do i=1 %to 1;
		%if &Product = DocAlert %then %do;
		proc sql noprint;
		select list_price*1.2 into :p1 from tempm;
		quit;
		%end;
		
		%if &Product = Epoc_Quiz %then %do;
		proc sql noprint;
		select list_price*1.2*1.25 as CL_Price into :p1 from tempm;
		quit;
		%end;

		%if &Product = Triggered %then %do;
		proc sql noprint;
		select list_price*1.2*1.15 as CL_Price into :p1 from tempm;
		quit;
		%end;
	%end;
	%mend;
	%Pricing;

	data check1;
	og_list = &fcount.;
	count = &c1.;
	price = &p1.;
	run;

	/*Generates the | list total | match total | match rate | table */
	data count;
	OriginalClientListCount1 = symget('fcount');
	Original_ClientList_Count=input(OriginalClientListCount1,8.);
	format Original_ClientList_Count Comma8.;
	label Original_ClientList_Count="Original Client List Count";
	drop OriginalClientListCount1;
	CampaignEligibleMatchCount1=symget('c1');
	Campaign_Eligible_Match_Count=input(CampaignEligibleMatchCount1,8.);
	label Campaign_Eligible_Match_Count="Campaign Eligible Match Count";
	format Campaign_Eligible_Match_Count Comma8.;
	drop CampaignEligibleMatchCount1;
	Campaign_Eligible_Match_Rate = Campaign_Eligible_Match_Count/Original_ClientList_Count;
	format Campaign_Eligible_Match_Rate percent7.;
	label Campaign_Eligible_Match_Rate="Campaign Eligible Match Rate";
	run;
	/* ELIGIBLE COUNT END*/
	/*MD/DO & NP/PA*/
	data MDDO;
	set occ;
	where put(occupation_key,ok2on.) in ("MD","DO");
	drop PERCENT;
	Dummy="MDDO";
	run;
	proc sql;
	create table MDDO1 as select sum(COUNT)as MDDOCOUNT from MDDO group by dummy;
	quit;
	data MDDO1;
	set MDDO1;
	format MDDOCOUNT comma8.;
	run;
	proc sql;
	select MDDOCOUNT into: MDDOFINAL from MDDO1;
	quit;
	%put &MDDOFINAL.;
	/*NPPA*/
	data OHC;
	set occ;
	where put(occupation_key,ok2on.) not in ("MD","DO");
	drop occupation_key PERCENT;
	Dummy=OHC;
	run;
	proc sql;
	create table OHC1 as select sum(count) as OHCCOUNT from OHC group by dummy;
	quit;
	data OHC1;
	set OHC1;
	format OHCCOUNT comma8.;
	run;
	proc sql;
	select OHCCOUNT into: OHCFINAL from OHC1;
	quit;
	%put &OHCFINAL.;
	/* END --- MD/DO & NP/PA*/
	/*SPEC*/
	data Spec1;
	set spec;
	where put(specialty_key,SK2S2X38.) not in ("Student","Other","No Specialty");
	run;
	data spec2;
	set spec1;
	if Percent < .5 then delete;
	run;
	proc sql number outobs=5;
	create table spec3 as select * from spec2;
	quit;
	data spec4 (keep= specialty_key Percentage);
	set spec3;
	Percentage=percent/100;
	drop precent;
	format Percentage percent7.;
	run;
	data spec4;
	set spec4;
	retain specialty_key1 Percentage;
	specialty_key1=put(specialty_key,SK2S2X38.);
	drop specialty_key;
	run;
	proc sql;
	create table spec4 as select specialty_key1 as MD_DO_Specialty, percentage from spec4;
	quit;
	data spec5;
	set spec4;
	/*label MD_DO_Specialty="MD\DO Specialty";*/
	run;
	proc sql;
	select count(MD_DO_Specialty) as speccount1 into :speccount from spec5;
	quit;
	/*SPEC END*/
	/*PRICE*/
	data rate1;
	set tempm;
	amount=&p1.; 
	amount1=round((amount+499),1000);
	drop list_price amount;
	format amount1 dollar10.;
	run;
	proc sql;
	select amount1 into: finalrate from rate1;
	quit;
	%put &finalrate;

	%if &Product = DocAlert or &Product = Triggered %then %do;
		%let prodType= DocAlert;

		data ratetext;
		set rate1;
		length pricetext1 $1000;
		if amount1 >20000 then pricetext1="
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ]Price:&finalrate } ^{newline 2}
		";

		else if amount1 <=20000 then pricetext1="
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ]Price: $20,000 (minimum price for a wave) } ^{newline 2}
		";
		run;

		data ratetext1;
		set ratetext;
		length pricetext2 $1000;
		if amount1 >20000 then pricetext2="
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Due to de-duplication, the price may drop if an additional }
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] &prodType.} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] target is being added. Please put in a new Salesforce ticket in that case. }
		";

		else if amount1 <=20000 then pricetext2="
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] If adding on to another}
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] &prodType.} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] target, the above set of targets would be priced at} 
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] &finalrate..} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Please put in a Salesforce ticket however as the price may decline further depending on de-duping based on the definition of the additional target. }
		";
		run;

		proc sql;
		select pricetext1 into: finalpricetext1 from ratetext1;
		select pricetext2 into: finalpricetext2 from ratetext1;
		quit;
		%put &finalpricetext1;
		%put &finalpricetext2;
	%end;

	%if &Product = Epoc_Quiz %then %do;
		%let prodType= ePocQuiz;
		data ratetext;
		set rate1;
		length pricetext1 $1000;
		if amount1 >25000 then pricetext1="
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ]Price:&finalrate } ^{newline 2}
		^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79 FONTSTYLE=ITALIC] Note: }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 FONTSTYLE=ITALIC] The minimum price per package for an ePocQuiz is $75,000. The minimum number of waves allowed to be offered is 3. } ^{newline 2}
		";

		else if amount1 <=25000 then pricetext1="
		^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79 ] Price: $25,000 (minimum price for a wave) } ^{newline 2}
		^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79 FONTSTYLE=ITALIC] Note: }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 FONTSTYLE=ITALIC] The minimum price per package for an ePocQuiz is $75,000. The minimum number of waves allowed to be offered is 3. } ^{newline 2}
		";
		run;

		data ratetext1;
		set ratetext;
		length pricetext2 $1000;
		if amount1 >25000 then pricetext2="
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Due to de-duplication, the price may drop if an additional }
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] ePocQuiz} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] target is being added. Please put in a new Salesforce ticket in that case. }
		";

		else if amount1 <=25000 then pricetext2="
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] If adding on to another}
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] ePocQuiz} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] target, the above set of targets would be priced at} 
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] &finalrate..} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Please put in a Salesforce ticket however as the price may decline further depending on de-duping based on the definition of the additional target. }
		";
		run;
		

		proc sql;
		select pricetext1 into: finalpricetext1 from ratetext1;
		select pricetext2 into: finalpricetext2 from ratetext1;
		quit;
		%put &finalpricetext1;
		%put &finalpricetext2;
	%end;
%end;
%end;
%mend;
%client_list_data;


/*my code to build the SDA and BDA add on tables ONLY if they are needed*/
%MACRO Add_on_conditionals;
%do i=1 %to 1;
	%if &sda_occ. ne "" or &sda_spec. ne "" %then %do;
		%if &list_match_type. ne None %then %do;
		/*BUilds SDA headers, list match results, SDA results and totals table for Add on*/
			proc sql;
			create table sda_table_headers (Criteria char(25), Users numeric(25), Price numeric(25));
			quit;

			proc sql;
			create table finalPrice as
			Select amount1 as rounded
			FROM rate1;
			quit;

			proc sql;
			create table sda_list_match as
			Select distinct 'List Match Users' as type, Count(distinct userid) as campaign_eligible, round((rounded+499),1000) as roundedPrice
			FROM final, finalPrice;
			quit;

			proc sql;
			create table sda_count_price as
			select 'Occupation/Specialty*' as type, SDA_count, round((SDA_price+499),1000) as SDA_price
			FROM sda_results;
			quit;

			proc sql;
			create table list_sda_total as
			Select 'Specialty + List Match', (campaign_eligible + SDA_count) as listTotal, (roundedPrice + SDA_price)
			FROM sda_list_match, sda_count_price;
			quit;

			proc sql;
			create table sda_email_results as
			select * from sda_table_headers
			union
			select * from sda_list_match
			union
			select * from sda_count_price
			union
			select * from list_sda_total;
			quit;

			data sda_email_results1;
			set sda_email_results;
			format Users Comma8.;
			format Price Dollar10.;
			run;
		%end;

		%if &list_match_type. =None %then %do;
			proc sql;
			create table sda_table_headers (Criteria char(25), Users numeric(25), Price numeric(25));
			quit;

			proc sql;
			create table sda_count_price as
			select 'Occupation/Specialty*' as type, SDA_count, round((SDA_price+499),1000) as SDA_price
			FROM sda_results;
			quit;

			proc sql;
			create table sda_email_results as
			select * from sda_table_headers
			union
			select * from sda_count_price
			quit;

			data sda_email_results1;
			set sda_email_results;
			format Users Comma8.;
			format Price Dollar10.;
			run;
		%end;
	%end;

	%if &bda_occ. ne "" or &bda_spec. ne "" %then %do;
		%if &list_match_type. ne None %then %do;
			/*BUilds BDA headers, list match results, BDA results and totals table for Add on*/
			proc sql;
			create table bda_table_headers (Criteria char(25), Users numeric(25), Price numeric(25));
			quit;

			proc sql;
			create table finalPrice as
			Select amount1 as rounded
			FROM rate1;
			quit;

			proc sql;
			create table bda_list_match as
			Select distinct 'List Match Users' as type, Count(distinct userid) as campaign_eligible, round((rounded+499),1000) as roundedPrice
			FROM final, finalPrice;
			quit;

			proc sql;
			create table bda_count_price as
			select 'Remaining Behavioral Segment**' as type, BDA_count, round((BDA_price+499),1000) as BDA_price
			FROM bda_results;
			quit;

			proc sql;
			create table list_bda_total as
			Select 'List Match + Behavioral', (campaign_eligible + BDA_count) as listTotal, (roundedPrice + BDA_price)
			FROM bda_list_match, bda_count_price;
			quit;

			proc sql;
			create table bda_email_results as
			select * from bda_table_headers
			union all
			select * from bda_list_match
			union all
			select * from bda_count_price
			union all
			select * from list_bda_total;
			quit;

			data bda_email_results1;
			set bda_email_results;
			format Users Comma8.;
			format Price Dollar10.;
			run;
		%end;

		%if &list_match_type. =None %then %do;
			proc sql;
			create table bda_table_headers (Criteria char(25), Users numeric(25), Price numeric(25));
			quit;

			proc sql;
			create table bda_count_price as
			select 'Remaining Behavioral Segment**' as type, BDA_count, round((BDA_price+499),1000) as BDA_price
			FROM bda_results;
			quit;

			proc sql;
			create table bda_email_results as
			select * from bda_table_headers
			union all
			select * from bda_count_price
			quit;

			data bda_email_results1;
			set bda_email_results;
			format Users Comma8.;
			format Price Dollar10.;
			run;
		%end;
	%end;
%end;
%mend;
%Add_on_conditionals;
/* PRICE END */

%macro email_opener;
%do i=1 %to 1;

	%if &Product. = DocAlert or &Product. = Triggered %then %do;
	/*EMAIL*/
		option nocenter;
		filename mymail email from="&email_user@athenahealth.com"
		to=("&email_user@athenahealth.com")
		subject="Case &caseno: &brand List Match Results and Pricing"
		content_type="Text/HTML";
		ods _all_ close;

		proc template;
		define style mystyle;
		 /* Body */
		 class body /
		 backgroundcolor = white
		 color = black
		 ;
		 /* Tables */
		 class table /
		 frame = box
		 rules = all
		 borderwidth = 1px
		 borderstyle = solid

		 bordercolor = black
		 borderspacing = 0
		 bordercollapse = collapse
		 ;
		end;
		run; 
		ODS ESCAPECHAR='^';
		ods html body=mymail style=mystyle;
		title j=left font = Calibri height=10pt color=Blumine;
		title "
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Dear &SE, }^{newline 2}
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] This is in reference to Case }
		^{style [ FONT=(Calibri,11Pt) textdecoration=underline color=#1f4e79 ] &caseno }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] for list match results and pricing for &brand .}
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] This match was performed as a &mtype .}^{newline 2}
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] A note of importance for &brand, we base our new list match pricing on our }
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] Campaign Eligible Match Rate }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] based on those users that would legitimately be eligible to receive a DocAlert because they have been active in our mobile software in the last 180 days. We always encourage our partners to require other vendors they may be considering to verify that the match rate provided is based on }
		^{style [ Font_weight=bold FONT=(Calibri,11Pt) textdecoration=underline color=#1f4e79 ] active users }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] that are in their }
		^{style [ Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79] mobile universe.} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79] We would also encourage getting their }
		^{style [ Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79] definition of an active user.} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] An overall }
		^{style [ FONT=(Calibri,11Pt) textdecoration=underline color=#1f4e79 ] registered match rate }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] (which some vendors may choose to provide) is not a true reflection of what &Manufacturer may consider purchasing. } ^{newline 2}
		^{style [ Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Complete List match results: } ^{newline 1}"
		;
	%end;

	%else %if &Product. = Epoc_Quiz %then %do;
	/*EMAIL*/
		option nocenter;
		filename mymail email from="&email_user@athenahealth.com"
		to=("&email_user@athenahealth.com")
		subject="Case &caseno: &brand List Match Results and Pricing for Epoc Quiz"
		content_type="Text/HTML";
		ods _all_ close;

		proc template;
		define style mystyle;
		 /* Body */
		 class body /
		 backgroundcolor = white
		 color = black
		 ;
		 /* Tables */
		 class table /
		 frame = box
		 rules = all
		 borderwidth = 1px
		 borderstyle = solid

		 bordercolor = black
		 borderspacing = 0
		 bordercollapse = collapse
		 ;
		end;
		run; 
		ODS ESCAPECHAR='^';
		ods html body=mymail style=mystyle;
		title j=left font = Calibri height=10pt color=Blumine;
		title "
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Dear &SE, }^{newline 2}
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] This is in reference to Case }
		^{style [ FONT=(Calibri,11Pt) textdecoration=underline color=#1f4e79 ] &caseno }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] for list match results and pricing for &brand ePocQuiz.}
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] This match was performed as a &mtype .}^{newline 2}
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] A note of importance for &brand, we base our new list match pricing on our }
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] Campaign Eligible Match Rate }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] based on those users that would legitimately be eligible to receive a }
		^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 ] Epoc Quiz }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] because they have been active in our mobile software in the last 180 days. We always encourage our partners to require other vendors they may be considering to verify that the match rate provided is based on }
		^{style [ Font_weight=bold FONT=(Calibri,11Pt) textdecoration=underline color=#1f4e79 ] active users }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] that are in their }
		^{style [ Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79] mobile universe.} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79] We would also encourage getting their }
		^{style [ Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79] definition of an active user.} 
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] An overall }
		^{style [ FONT=(Calibri,11Pt) textdecoration=underline color=#1f4e79 ] registered match rate }
		^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] (which some vendors may choose to provide) is not a true reflection of what &Manufacturer may consider purchasing. } ^{newline 2}
		^{style [ Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Complete List match results: } ^{newline 1}"
		;
	%end;
%end;
%mend;
%email_opener;


%macro client_list_email;
%do i=1 %to 1;

%if &list_match_type. =None %then %do;
	data noobs;
	a='';
	run;

	proc report data=noobs nowd
	style(report)={background=white foreground=white borderrightcolor=white
	           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
	style(header)={background=white foreground=white}
	style(column)={background=white foreground=white};
	column a;
	define a / " ";
	run;
%end;

%if &list_match_type. ne None %then %do;
	proc report data=count
	split="*"
	style(column)=[just=c]
	style(column)={width=4cm}
	style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#4975AD
	           borderleftcolor=#4975AD bordertopcolor=#4975AD borderbottomcolor=#4975AD */color=#1f4e79 /*borderspacing=0 borderwidth=2*/]
	style(column)=[background=white]
	style(header)=[background=white foreground=#1f4e79]
	style(summary)=[background=white]
	style(lines)=[background=#1f4e79]
	style(calldef)=[background=#1f4e79];
	compute Original_ClientList_Count ;
	count+1;
	if(mod(count,2)) then do;
	CALL DEFINE(_ROW_, "STYLE",
	"STYLE=[BACKGROUND=#d3dfee /*FOREGROUND=WHITE*/
	color=#1f4e79]");
	end;
	endcomp;
	label Original_ClientList_Count="Original Client List*Count"
	Campaign_Eligible_Match_Count="Campaign Eligible*Match Count"
	Campaign_Eligible_Match_Rate="Campaign Eligible*Match Rate";
	run;
	/*proc report data=count ;*/
	/*quit;*/
	ODS ESCAPECHAR='^';
	ods html text="" style=minimal;
	title j=left font = Calibri height=11pt color=blumine;
	title " ^{newline 1}
	^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ]Additionally, for your reference, the numbers segmented by Occupation are as follows:} ^{newline 2}
	^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ]Count of Campaign Eligible MD/DOs: &MDDOFINAL. } ^{newline 1}
	^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ]Count of Campaign Eligible Other HCPs: &OHCFINAL.} ^{newline 2}
	^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Pricing:} ^{newline 2}
	^{style [ Font_weight=bold  FONT=(Calibri,11Pt) color=#1f4e79 FONTSTYLE=ITALIC] Note:}
	^{style [ FONT=(Calibri,11Pt) color=#1f4e79 FONTSTYLE=ITALIC] Please refer to the rate card for net open rate guarantee parameters and whether the targeting scenario(s) outlined below are eligible for a guarantee.} ^{newline 2}
	^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Of the Campaign Eligible MD\DOs (count &MDDOFINAL.), the top &speccount specialties are 
	broken out as follows:} ^{newline 1}"
	;
	proc template;
	define style mystyle;
	 /* Body */
	 class body /
	 backgroundcolor = white
	 color = black
	 ;
	 /* Tables */
	 class table /
	 frame = box
	 rules = all
	 borderwidth = 1px
	 borderstyle = solid
	 cellspacing = 1pt

	 bordercolor = black
	 borderspacing = 0
	 bordercollapse = collapse
	 ;
	end;
	run;

	ods html text="" style=mystyle; 
	proc report data=spec5
	split="*"
	style(column)=[just=c]
	style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
	           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
	style(column)=[background=white]
	style(header)=[background=white foreground=#1f4e79]
	style(summary)=[background=white]
	style(lines)=[background=#1f4e79]
	style(calldef)=[background=#1f4e79];
	compute MD_DO_Specialty ;
	count+1;
	if(mod(count,2)) then do;
	CALL DEFINE(_ROW_, "STYLE",
	"STYLE=[BACKGROUND=#d3dfee /*FOREGROUND=WHITE*/ color=#1f4e79]");
	pagebreakhtml=_undef_;
	end;
	endcomp;
	label MD_DO_Specialty="MD/DO*Specialty";
	run;
	/*proc report data=spec4;*/
	/*quit;*/
	ods html text="" style=mystyle; 
	ODS ESCAPECHAR='^';
	title j=left font = Calibri height=11Pt color=blumine;
	title "
	^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] Based on the specialty break-out results, the price for a wave comes to the following: }^{newline 1}
	&finalpricetext1.
	&finalpricetext2.
	"
	;

	data noobs;
	a='';
	run;

	proc report data=noobs nowd
	style(report)={background=white foreground=white borderrightcolor=white
	           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
	style(header)={background=white foreground=white}
	style(column)={background=white foreground=white};
	column a;
	define a / " ";
	run;


	/*30/60/90 CSS code for title and proc report*/
	ods html text="" style=mystyle; 
	ODS ESCAPECHAR='^';
	title j=left font = Calibri height=11Pt color=blumine;
	title "
	^{style [FONT=(Calibri,11Pt) ont_weight=bold textdecoration=underline color=#1f4e79 ] 30/60/90 Match Counts: }^{newline 1}
	"
	;

	proc report data=all_active
	style(column)=[just=c]
	style(Column)={width=4cm}
	style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD color=#1f4e79]
	style(column)=[background=white]
	style(header)=[background=white foreground=#1f4e79]
	style(summary)=[background=white]
	style(lines)=[background=#1f4e79]
	style(calldef)=[background=#1f4e79];
	compute Days_Active; /*this compute statemnet is what creates every otherrow styling blue*/
	count+1;
	if(mod(count,2)) then do;
	CALL DEFINE(_ROW_, "STYLE",
	"STYLE=[BACKGROUND=#d3dfee /*FOREGROUND=WHITE*/ color=#1f4e79]");
	pagebreakhtml=_undef_;
	end;
	endcomp;
	run;
%end;
%end;
%mend;
%client_list_email;

/*ALl conditionals for generating the segment + SDA + BDA charts is all combinations*/
%MACRO conditionals;
%do i=1 %to 1;
%if &list_match_type.=Standard_Seg or &list_match_type.=Exact_Seg %then %do;
		/*Segmentation Titles*/
		ods html text="" style=mystyle;
		ODS ESCAPECHAR='^';
		title1 j=left font = Calibri height=11Pt color=blumine;
		title1 "
		^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Client Segmentation: }
		";
		title2 j=left font = Calibri height=11Pt color=blumine;
		title2 "
		^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] If the client would like to target specific segments from different columns of the target list for their } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &prodType.} ^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] launch (i.e. targeting only Segment A and Decile 2) then we will need to know }
		^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] which segment(s) take priority for post-campaign reporting purposes. Please put in a Salesforce ticket in that case.}
		"
		;

		proc report data=noobs nowd
		style(report)={background=white foreground=white borderrightcolor=white
		           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
		style(header)={background=white foreground=white}
		style(column)={background=white foreground=white};
		column a;
		define a / " ";
		run;

	%macro pricing;
	%global _30_60_90_Segs;
		/*Scan segments and fix interger value types in output charts*/
		%local i pricing;
		%do i=1 %to %sysfunc(countw(&seg_nocommas));
		  %let pricing = %scan(&seg_nocommas, &i);

		data &pricing._Price2;
		set &pricing._Price1;
		client_segment_type = vtype(client_segment);
		run;

		Proc sql noprint;
		Select distinct client_segment_type into :segment_type
		from &pricing._Price2;
		quit;

		%if &segment_type=C %then %do;
		data &pricing._Price3;
		length Client_Segment10 $45;
		set &pricing._Price2;
		if Client_Segment="" then Client_Segment10="(blank)";
		else client_segment10=client_segment;
		drop client_segment_type client_segment;
		rename Client_Segment10=Client_Segment;
		run;
		%end;

		%else %if &segment_type=N %then %do;
		data &pricing._Price3;
		Length Client_Segment9 $8;
		set &pricing._Price2;
		if Client_Segment =. then Client_Segment9="(blank)";
		else Client_Segment9=trim(put(Client_Segment,8.));
		drop Client_Segment client_segment_type;
		rename Client_Segment9=Client_Segment;
		run;
		%end;
 		
		proc sql;
		create table &pricing._Price4 as
		select distinct Client_Segment, target_users, matched_users, match_rate, list_price
		from &pricing._Price3
		;quit;

		/*Create Segment title per chart generated*/
		TITLE1 j=left font = Calibri height=11Pt color=blumine; TITLE1 "
		^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The break-out by “&pricing.” is as follows:}";

		ods html text="" style=mystyle; 
		proc report data=&pricing._Price4
		split="*" 
		style(column)=[just=c]
		style(Column)={width=4cm}
		style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD color=#1f4e79]
		style(column)=[background=white]
		style(header)=[background=white foreground=#1f4e79]
		style(summary)=[background=white]
		style(lines)=[background=#1f4e79]
		style(calldef)=[background=#1f4e79];
		compute target_users;
		count+1;
		if(mod(count,2)) then do;
		CALL DEFINE(_ROW_, "STYLE",
		"STYLE=[BACKGROUND=#d3dfee /*FOREGROUND=WHITE*/ color=#1f4e79]");
		pagebreakhtml=_undef_;
		end;
		endcomp;
		label Client_Segment="Client Segment"
		target_users="Original Client List*Segment Count"
		matched_users="Campaign Eligible*Segment Match Count"
		match_rate="Campaign Eligible*Segment Match Rate"
		list_price="Campaign Eligible*Segment Price";
		run;

		%end;
		%mend;
		%pricing;

		%if &run_30_60_90. = Yes %then %do;
			%macro pricing2;
			/*Scan segments and fix interger value types in output charts*/
			%local i _30_60_90_Segs;
				%do i=1 %to %sysfunc(countw(&seg_nocommas));
				%let _30_60_90_Segs = %scan(&seg_nocommas, &i);

				data _30_active_&_30_60_90_Segs._2;
				set _30_active_&_30_60_90_Segs.;
				client_segment_type = vtype(&_30_60_90_Segs.);
				run;

				Proc sql noprint;
				Select distinct client_segment_type into :segment_type
				from _30_active_&_30_60_90_Segs._2;
				quit;

				%if &segment_type=C %then %do;
				data _30_active_&_30_60_90_Segs._3;
				length Client_Segment10 $45;
				set _30_active_&_30_60_90_Segs._2;
				if &_30_60_90_Segs.="" then Client_Segment10="(blank)";
				else client_segment10=&_30_60_90_Segs.;
				drop client_segment_type client_segment;
				rename Client_Segment10=&_30_60_90_Segs.;
				run;
				%end;

				%else %if &segment_type=N %then %do;
				data _30_active_&_30_60_90_Segs._3;
				Length Client_Segment9 $8;
				set _30_active_&_30_60_90_Segs._2;
				if &_30_60_90_Segs. =. then Client_Segment9="(blank)";
				else Client_Segment9=trim(put(&_30_60_90_Segs.,8.));
				drop &_30_60_90_Segs. client_segment_type;
				rename Client_Segment9=&_30_60_90_Segs.;
				run;
				%end;

				TITLE1 j=left font = Calibri height=11Pt color=blumine; TITLE1 "
				^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The break-out by “&_30_60_90_Segs.” is as follows:}";

				ods html text="" style=mystyle; 
				proc report data=_30_active_&_30_60_90_Segs._3
				split="*" 
				style(column)=[just=c]
				style(Column)={width=4cm}
				style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD color=#1f4e79]
				style(column)=[background=white]
				style(header)=[background=white foreground=#1f4e79]
				style(summary)=[background=white]
				style(lines)=[background=#1f4e79]
				style(calldef)=[background=#1f4e79];
				compute &_30_60_90_Segs.;
				count+1;
				if(mod(count,2)) then do;
				CALL DEFINE(_ROW_, "STYLE",
				"STYLE=[BACKGROUND=#d3dfee /*FOREGROUND=WHITE*/ color=#1f4e79]");
				pagebreakhtml=_undef_;
				end;
				endcomp;
				/*					label Client_Segment="Client Segment"*/
				/*					target_users="Original Client List*Segment Count"*/
				/*					matched_users="Campaign Eligible*Segment Match Count"*/
				/*					match_rate="Campaign Eligible*Segment Match Rate"*/
				/*					list_price="Campaign Eligible*Segment Price";*/
				run;


				data _60_active_&_30_60_90_Segs._2;
				set _60_active_&_30_60_90_Segs.;
				client_segment_type = vtype(&_30_60_90_Segs.);
				run;

				Proc sql noprint;
				Select distinct client_segment_type into :segment_type
				from _60_active_&_30_60_90_Segs._2;
				quit;

				%if &segment_type=C %then %do;
				data _60_active_&_30_60_90_Segs._3;
				length Client_Segment10 $45;
				set _60_active_&_30_60_90_Segs._2;
				if &_30_60_90_Segs.="" then Client_Segment10="(blank)";
				else client_segment10=&_30_60_90_Segs.;
				drop client_segment_type client_segment;
				rename Client_Segment10=&_30_60_90_Segs.;
				run;
				%end;

				%else %if &segment_type=N %then %do;
				data _60_active_&_30_60_90_Segs._3;
				Length Client_Segment9 $8;
				set _60_active_&_30_60_90_Segs._2;
				if &_30_60_90_Segs. =. then Client_Segment9="(blank)";
				else Client_Segment9=trim(put(&_30_60_90_Segs.,8.));
				drop &_30_60_90_Segs. client_segment_type;
				rename Client_Segment9=&_30_60_90_Segs.;
				run;
				%end;

				TITLE1 j=left font = Calibri height=11Pt color=blumine; TITLE1 "
				^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The break-out by “&_30_60_90_Segs.” is as follows:}";

				ods html text="" style=mystyle; 
				proc report data=_60_active_&_30_60_90_Segs._3
				split="*" 
				style(column)=[just=c]
				style(Column)={width=4cm}
				style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD color=#1f4e79]
				style(column)=[background=white]
				style(header)=[background=white foreground=#1f4e79]
				style(summary)=[background=white]
				style(lines)=[background=#1f4e79]
				style(calldef)=[background=#1f4e79];
				compute &_30_60_90_Segs.;
				count+1;
				if(mod(count,2)) then do;
				CALL DEFINE(_ROW_, "STYLE",
				"STYLE=[BACKGROUND=#d3dfee /*FOREGROUND=WHITE*/ color=#1f4e79]");
				pagebreakhtml=_undef_;
				end;
				endcomp;
				/*					label Client_Segment="Client Segment"*/
				/*					target_users="Original Client List*Segment Count"*/
				/*					matched_users="Campaign Eligible*Segment Match Count"*/
				/*					match_rate="Campaign Eligible*Segment Match Rate"*/
				/*					list_price="Campaign Eligible*Segment Price";*/
				run;

				data _90_active_&_30_60_90_Segs._2;
				set _90_active_&_30_60_90_Segs.;
				client_segment_type = vtype(&_30_60_90_Segs.);
				run;

				Proc sql noprint;
				Select distinct client_segment_type into :segment_type
				from _90_active_&_30_60_90_Segs._2;
				quit;

				%if &segment_type=C %then %do;
				data _90_active_&_30_60_90_Segs._3;
				length Client_Segment10 $45;
				set _90_active_&_30_60_90_Segs._2;
				if &_30_60_90_Segs.="" then Client_Segment10="(blank)";
				else client_segment10=&_30_60_90_Segs.;
				drop client_segment_type client_segment;
				rename Client_Segment10=&_30_60_90_Segs.;
				run;
				%end;

				%else %if &segment_type=N %then %do;
				data _90_active_&_30_60_90_Segs._3;
				Length Client_Segment9 $8;
				set _90_active_&_30_60_90_Segs._2;
				if &_30_60_90_Segs. =. then Client_Segment9="(blank)";
				else Client_Segment9=trim(put(&_30_60_90_Segs.,8.));
				drop &_30_60_90_Segs. client_segment_type;
				rename Client_Segment9=&_30_60_90_Segs.;
				run;
				%end;

				/*Create Segment title per chart generated*/
				TITLE1 j=left font = Calibri height=11Pt color=blumine; TITLE1 "
				^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The break-out by “&_30_60_90_Segs.” is as follows:}";

				ods html text="" style=mystyle; 
				proc report data=_90_active_&_30_60_90_Segs._3
				split="*" 
				style(column)=[just=c]
				style(Column)={width=4cm}
				style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD color=#1f4e79]
				style(column)=[background=white]
				style(header)=[background=white foreground=#1f4e79]
				style(summary)=[background=white]
				style(lines)=[background=#1f4e79]
				style(calldef)=[background=#1f4e79];
				compute &_30_60_90_Segs.;
				count+1;
				if(mod(count,2)) then do;
				CALL DEFINE(_ROW_, "STYLE",
				"STYLE=[BACKGROUND=#d3dfee /*FOREGROUND=WHITE*/ color=#1f4e79]");
				pagebreakhtml=_undef_;
				end;
				endcomp;
				/*					label Client_Segment="Client Segment"*/
				/*					target_users="Original Client List*Segment Count"*/
				/*					matched_users="Campaign Eligible*Segment Match Count"*/
				/*					match_rate="Campaign Eligible*Segment Match Rate"*/
				/*					list_price="Campaign Eligible*Segment Price";*/
				run;


				%end;
			%mend;
			%pricing2;
			%end;
			%end;

	%if &list_match_type.=Standard or &list_match_type.=Standard_Seg or &list_match_type.=Exact or &list_match_type.=Exact_Seg or &list_match_type.=Fuzzy or &list_match_type.=None%then %do;
		%if &sda_occ. ne "" or &sda_spec. ne "" %then %do;
			%if &bda_occ. = "" and &bda_spec. = "" %then %do;
				%if &list_match_type. ne None %then %do;

					/*SDA ADD ON ONLY*/
					/*Creates Macro Variables of List Match + SDA Totals for email*/
					proc sql;
					create table lm_sda_users1 as
					select sum(users) as count1 from price1
					union
					select SDA_count from sda_count_price;
					run;

					data lm_sda_users;
					set lm_sda_users1;
					run;

					proc sql noprint;
					select sum(count1) format=comma8. into: lm_sda_count from lm_sda_users;
					quit;
					%put &lm_sda_count;


					proc sql;
					create table lm_plus_sda1 as
					select amount1 format=13. FROM rate1
					union all
					select SDA_price from sda_count_price;
					run;

					data lm_plus_sda;
					set lm_plus_sda1;
					run;

					proc sql noprint;
					select sum(amount1) format=dollar10. into: lm_sda_price from lm_plus_sda;
					quit;
					%put &lm_sda_price;

					/*SDA Chart Titles with Macro Variables Populated*/
					ods html text="" style=styles.nobreak; 
					ODS ESCAPECHAR='^';
					title j=left font = Calibri height=11Pt color=blumine;
					title "
					^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 1}
					^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the client list and specialty is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_price} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
					"
					;

					ods html text="" style=mystyle; 
					proc report data=sda_email_results1 
					style(column)=[just=l]
					style(column)={width=7cm}
					style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
					           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
					style(column)=[background=white]
					style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
					style(summary)=[background=white]
					style(lines)=[background=#1f4e79]
					style(calldef)=[background=#1f4e79];
					compute Criteria;
					if Criteria = 'Specialty + List Match' then do;
					CALL DEFINE(_ROW_, "STYLE",
					"STYLE={font_weight=bold background=white}");
					end;
					if Criteria in ('List Match Users', 'Occupation/Specialty*') then do;
					CALL DEFINE(_COL_, "STYLE",
					"STYLE={font_weight=bold background=white}");
					end;
					endcomp;
					run;

					/*SDA Chart Details*/
					ods html text="" style=styles.nobreak; 
					ODS ESCAPECHAR='^';
					title j=left font = Calibri height=11Pt color=blumine;
					title "
					^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] *} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] &sda_occ_nocom who specialize in &sda_spec} ^{newline 2}
					"
					;

					proc report data=noobs nowd
					style(report)={background=white foreground=white borderrightcolor=white
					           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
					style(header)={background=white foreground=white}
					style(column)={background=white foreground=white};
					column a;
					define a / " ";
					run;
				%end;

				%if &list_match_type. =None %then %do;
					proc sql;
					create table lm_sda_users1 as
/*					select sum(users) as count1 from price1*/
/*					union*/
					select SDA_count as count1 from sda_count_price;
					run;

					data lm_sda_users;
					set lm_sda_users1;
					run;

					proc sql noprint;
					select sum(count1) format=comma8. into: lm_sda_count from lm_sda_users;
					quit;
					%put &lm_sda_count;


					proc sql;
					create table lm_plus_sda1 as
/*					select amount1 format=13. FROM rate1*/
/*					union all*/
					select SDA_price as amount1 from sda_count_price;
					run;

					data lm_plus_sda;
					set lm_plus_sda1;
					run;

					proc sql noprint;
					select sum(amount1) format=dollar10. into: lm_sda_price from lm_plus_sda;
					quit;
					%put &lm_sda_price;

					/*SDA Chart Titles with Macro Variables Populated*/
					ods html text="" style=styles.nobreak; 
					ODS ESCAPECHAR='^';
					title j=left font = Calibri height=11Pt color=blumine;
					title "
					^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 1}
					^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the specialty is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_price} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
					"
					;

					ods html text="" style=mystyle; 
					proc report data=sda_email_results1 
					style(column)=[just=l]
					style(column)={width=7cm}
					style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
					           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
					style(column)=[background=white]
					style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
					style(summary)=[background=white]
					style(lines)=[background=#1f4e79]
					style(calldef)=[background=#1f4e79];
					compute Criteria;
					if Criteria in ('Occupation/Specialty*') then do;
					CALL DEFINE(_COL_, "STYLE",
					"STYLE={font_weight=bold background=white}");
					end;
					endcomp;
					run;

					/*SDA Chart Details*/
					ods html text="" style=styles.nobreak; 
					ODS ESCAPECHAR='^';
					title j=left font = Calibri height=11Pt color=blumine;
					title "
					^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] *} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] &sda_occ_nocom who specialize in &sda_spec} ^{newline 2}
					"
					;

					proc report data=noobs nowd
					style(report)={background=white foreground=white borderrightcolor=white
					           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
					style(header)={background=white foreground=white}
					style(column)={background=white foreground=white};
					column a;
					define a / " ";
					run;
				%end;
			%end;
		%end;

		%if (&bda_occ. ne "" and &bda_spec. ne "") or (&bda_occ. ne "" and &bda_spec. = "") %then %do;
			%if &sda_occ. = "" and &sda_spec. = "" %then %do;
				%if &list_match_type. ne None %then %do;


					/*BDA Table Price Total*/
					/*Creates Macro Variables of List Match + BDA Totals for email*/
					proc sql;
					create table lm_plus_bda1 as
					select amount1 format=13. FROM rate1
					union all
					select BDA_price from bda_count_price;
					run;

					data lm_plus_bda;
					set lm_plus_bda1;
					run;

					proc sql noprint;
					select sum(amount1) format=dollar10. into: lm_bda_price from lm_plus_bda;
					quit;
					%put &lm_bda_price;

					/*BDA USER TOTAL*/

					proc sql;
					create table lm_bda_users1 as
					select sum(users) as count1 from price1
					union
					select BDA_count from bda_count_price;
					run;

					data lm_bda_users;
					set lm_bda_users1;
					run;

					proc sql noprint;
					select sum(count1) format=comma8. into: lm_bda_count from lm_bda_users;
					quit;
					%put &lm_bda_count;

					ods html text="" style=styles.nobreak; 
					ODS ESCAPECHAR='^';
					title j=left font = Calibri height=11Pt color=blumine;
					title "
					^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 2}
					^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the client list and behavioral is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_price } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
					"
					;

					ods html text="" style=mystyle; 
					proc report data=bda_email_results1 
					style(column)=[just=l]
					style(column)={width=7cm}
					style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
					           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
					style(column)=[background=white]
					style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
					style(summary)=[background=white]
					style(lines)=[background=#1f4e79]
					style(calldef)=[background=#1f4e79];
					compute Criteria;
					if Criteria = 'List Match + Behavioral' then do;
					CALL DEFINE(_ROW_, "STYLE",
					"STYLE={font_weight=bold background=white}");
					end;
					if Criteria in ('List Match Users', 'Remaining Behavioral Segment**') then do;
					CALL DEFINE(_COL_, "STYLE",
					"STYLE={font_weight=bold background=white}");
					end;
					endcomp;
					run;


					/*BDA Chart Details*/
					ods html text="" style=styles.nobreak; 
					ODS ESCAPECHAR='^';
					title j=left font = Calibri height=11Pt color=blumine;
					title "
					^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs in the past &dispPeriod days}
					"
					;

					proc report data=noobs nowd
					style(report)={background=white foreground=white borderrightcolor=white
					           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
					style(header)={background=white foreground=white}
					style(column)={background=white foreground=white};
					column a;
					define a / " ";
					run;
				%end;
		
				%if &list_match_type. =None %then %do;
					/*BDA Table Price Total*/
					/*Creates Macro Variables of List Match + BDA Totals for email*/
					proc sql;
					create table lm_plus_bda1 as
/*					select amount1 format=13. FROM rate1*/
/*					union all*/
					select BDA_price as amount1 from bda_count_price;
					run;

					data lm_plus_bda;
					set lm_plus_bda1;
					run;

					proc sql noprint;
					select sum(amount1) format=dollar10. into: lm_bda_price from lm_plus_bda;
					quit;
					%put &lm_bda_price;

					/*BDA USER TOTAL*/

					proc sql;
					create table lm_bda_users1 as
/*					select sum(users) as count1 from price1*/
/*					union*/
					select BDA_count as count1 from bda_count_price;
					run;

					data lm_bda_users;
					set lm_bda_users1;
					run;

					proc sql noprint;
					select sum(count1) format=comma8. into: lm_bda_count from lm_bda_users;
					quit;
					%put &lm_bda_count;

					ods html text="" style=styles.nobreak; 
					ODS ESCAPECHAR='^';
					title j=left font = Calibri height=11Pt color=blumine;
					title "
					^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 2}
					^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the behavioral is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_price } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
					"
					;

					ods html text="" style=mystyle; 
					proc report data=bda_email_results1 
					style(column)=[just=l]
					style(column)={width=7cm}
					style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
					           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
					style(column)=[background=white]
					style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
					style(summary)=[background=white]
					style(lines)=[background=#1f4e79]
					style(calldef)=[background=#1f4e79];
					compute Criteria;
					if Criteria = 'List Match + Behavioral' then do;
					CALL DEFINE(_ROW_, "STYLE",
					"STYLE={font_weight=bold background=white}");
					end;
					if Criteria in ('List Match Users', 'Remaining Behavioral Segment**') then do;
					CALL DEFINE(_COL_, "STYLE",
					"STYLE={font_weight=bold background=white}");
					end;
					endcomp;
					run;


					/*BDA Chart Details*/
					%macro bda_chart_details_None1;
					%do i=1 %to 1;
						%if &bda_occ. ne "" and &bda_spec. ne "" %then %do;
							%if &drug_lookups_GE. = 1 %then %do; 
								ods html text="" style=styles.nobreak; 
								ODS ESCAPECHAR='^';
								title j=left font = Calibri height=11Pt color=blumine;
								title "
								^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs in the past &dispPeriod days}
								"
								;

								proc report data=noobs nowd
								style(report)={background=white foreground=white borderrightcolor=white
								           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
								style(header)={background=white foreground=white}
								style(column)={background=white foreground=white};
								column a;
								define a / " ";
								run;
							%end;

							%if &drug_lookups_GE. > 1 %then %do;
								ods html text="" style=styles.nobreak; 
								ODS ESCAPECHAR='^';
								title j=left font = Calibri height=11Pt color=blumine;
								title "
								^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs &drug_lookups_GE. + Times in the past &dispPeriod days}
								"
								;

								proc report data=noobs nowd
								style(report)={background=white foreground=white borderrightcolor=white
								           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
								style(header)={background=white foreground=white}
								style(column)={background=white foreground=white};
								column a;
								define a / " ";
								run;
							%end;
						%end;
						%if &bda_occ. ne "" and &bda_spec. = "" %then %do;
							%if &drug_lookups_GE. = 1 %then %do; 
								ods html text="" style=styles.nobreak; 
								ODS ESCAPECHAR='^';
								title j=left font = Calibri height=11Pt color=blumine;
								title "
								^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom who have looked up Drugs &drugs in the past &dispPeriod days}
								"
								;

								proc report data=noobs nowd
								style(report)={background=white foreground=white borderrightcolor=white
								           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
								style(header)={background=white foreground=white}
								style(column)={background=white foreground=white};
								column a;
								define a / " ";
								run;
							%end;

							%if &drug_lookups_GE. > 1 %then %do;
								ods html text="" style=styles.nobreak; 
								ODS ESCAPECHAR='^';
								title j=left font = Calibri height=11Pt color=blumine;
								title "
								^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom who have looked up Drugs &drugs &drug_lookups_GE. + Times in the past &dispPeriod days}
								"
								;

								proc report data=noobs nowd
								style(report)={background=white foreground=white borderrightcolor=white
								           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
								style(header)={background=white foreground=white}
								style(column)={background=white foreground=white};
								column a;
								define a / " ";
								run;
							%end;
						%end;
					%end;
					%mend;
					%bda_chart_details_None1;;
				%end;
			%end;
		%end;

		%if ((&bda_occ. ne "" and &bda_spec. ne "") or (&bda_occ. ne "" and &bda_spec. = "")) and (&sda_occ. ne "" or &sda_spec. ne "") %then %do;
			%if &list_match_type. ne None %then %do;

	/*			SDA + BDA*/

				proc sql;
				create table lm_sda_users1 as
				select sum(users) as count1 from price1
				union
				select SDA_count from sda_count_price;
				run;

				data lm_sda_users;
				set lm_sda_users1;
				run;

				proc sql noprint;
				select sum(count1) format=comma8. into: lm_sda_count from lm_sda_users;
				quit;
				%put &lm_sda_count;


				proc sql;
				create table lm_plus_sda1 as
				select amount1 format=13. FROM rate1
				union all
				select SDA_price from sda_count_price;
				run;

				data lm_plus_sda;
				set lm_plus_sda1;
				run;

				proc sql noprint;
				select sum(amount1) format=dollar10. into: lm_sda_price from lm_plus_sda;
				quit;
				%put &lm_sda_price;

				ods html text="" style=styles.nobreak; 
				ODS ESCAPECHAR='^';
				title j=left font = Calibri height=11Pt color=blumine;
				title "
				^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 2}
				^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] SDA OPTION } ^{newline 2}
				^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the client list and specialty is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_price} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave}
				"
				;

				ods html text="" style=mystyle; 
				proc report data=sda_email_results1 
				style(column)=[just=l]
				style(column)={width=7cm}
				style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
				           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
				style(column)=[background=white]
				style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
				style(summary)=[background=white]
				style(lines)=[background=#1f4e79]
				style(calldef)=[background=#1f4e79];
				compute Criteria;
				if Criteria = 'Specialty + List Match' then do;
				CALL DEFINE(_ROW_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				if Criteria in ('List Match Users', 'Occupation/Specialty*') then do;
				CALL DEFINE(_COL_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				endcomp;
				run;

				/*SDA Chart Details*/
				ods html text="" style=styles.nobreak; 
				ODS ESCAPECHAR='^';
				title j=left font = Calibri height=11Pt color=blumine;
				title "
				^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] *} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] &sda_occ_nocom who specialize in &sda_spec}
				"
				;

				proc report data=noobs nowd
				style(report)={background=white foreground=white borderrightcolor=white
				           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
				style(header)={background=white foreground=white}
				style(column)={background=white foreground=white};
				column a;
				define a / " ";
				run;



				/*BDA Table Price Total*/
				proc sql;
				create table lm_plus_bda1 as
				select amount1 format=13. FROM rate1
				union all
				select BDA_price from bda_count_price;
				run;

				data lm_plus_bda;
				set lm_plus_bda1;
				run;

				proc sql noprint;
				select sum(amount1) format=dollar10. into: lm_bda_price from lm_plus_bda;
				quit;
				%put &lm_bda_price;

				/*BDA USER TOTAL*/

				proc sql;
				create table lm_bda_users1 as
				select sum(users) as count1 from price1
				union
				select BDA_count from bda_count_price;
				run;

				data lm_bda_users;
				set lm_bda_users1;
				run;

				proc sql noprint;
				select sum(count1) format=comma8. into: lm_bda_count from lm_bda_users;
				quit;
				%put &lm_bda_count;

				ods html text="" style=styles.nobreak; 
				ODS ESCAPECHAR='^';
				title j=left font = Calibri height=11Pt color=blumine;
				title "
				^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] BDA OPTION } ^{newline 2}
				^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the client list and behavioral is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_price } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
				"
				;

				ods html text="" style=mystyle; 
				proc report data=bda_email_results1 
				style(column)=[just=l]
				style(column)={width=7cm}
				style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
				           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
				style(column)=[background=white]
				style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
				style(summary)=[background=white]
				style(lines)=[background=#1f4e79]
				style(calldef)=[background=#1f4e79];
				compute Criteria;
				if Criteria = 'List Match + Behavioral' then do;
				CALL DEFINE(_ROW_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				if Criteria in ('List Match Users', 'Remaining Behavioral Segment**') then do;
				CALL DEFINE(_COL_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				endcomp;
				run;


				/*BDA Chart Details*/
				ods html text="" style=styles.nobreak; 
				ODS ESCAPECHAR='^';
				title j=left font = Calibri height=11Pt color=blumine;
				title "
				^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs in the past &dispPeriod days}
				"
				;

				proc report data=noobs nowd
				style(report)={background=white foreground=white borderrightcolor=white
				           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
				style(header)={background=white foreground=white}
				style(column)={background=white foreground=white};
				column a;
				define a / " ";
				run;
			%end;

			%if &list_match_type. =None %then %do;
	/*			SDA + BDA*/

				proc sql;
				create table lm_sda_users1 as
/*				select sum(users) as count1 from price1*/
/*				union*/
				select SDA_count as count1 from sda_count_price;
				run;

				data lm_sda_users;
				set lm_sda_users1;
				run;

				proc sql noprint;
				select sum(count1) format=comma8. into: lm_sda_count from lm_sda_users;
				quit;
				%put &lm_sda_count;


				proc sql;
				create table lm_plus_sda1 as
/*				select amount1 format=13. FROM rate1*/
/*				union all*/
				select SDA_price as amount1 from sda_count_price;
				run;

				data lm_plus_sda;
				set lm_plus_sda1;
				run;

				proc sql noprint;
				select sum(amount1) format=dollar10. into: lm_sda_price from lm_plus_sda;
				quit;
				%put &lm_sda_price;

				ods html text="" style=styles.nobreak; 
				ODS ESCAPECHAR='^';
				title j=left font = Calibri height=11Pt color=blumine;
				title "
				^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 2}
				^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] SDA OPTION } ^{newline 2}
				^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the specialty is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_price} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave}
				"
				;

				ods html text="" style=mystyle; 
				proc report data=sda_email_results1 
				style(column)=[just=l]
				style(column)={width=7cm}
				style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
				           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
				style(column)=[background=white]
				style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
				style(summary)=[background=white]
				style(lines)=[background=#1f4e79]
				style(calldef)=[background=#1f4e79];
				compute Criteria;
				if Criteria = 'Specialty + List Match' then do;
				CALL DEFINE(_ROW_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				if Criteria in ('List Match Users', 'Occupation/Specialty*') then do;
				CALL DEFINE(_COL_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				endcomp;
				run;

				/*SDA Chart Details*/
				ods html text="" style=styles.nobreak; 
				ODS ESCAPECHAR='^';
				title j=left font = Calibri height=11Pt color=blumine;
				title "
				^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] *} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] &sda_occ_nocom who specialize in &sda_spec}
				"
				;

				proc report data=noobs nowd
				style(report)={background=white foreground=white borderrightcolor=white
				           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
				style(header)={background=white foreground=white}
				style(column)={background=white foreground=white};
				column a;
				define a / " ";
				run;



				/*BDA Table Price Total*/
				proc sql;
				create table lm_plus_bda1 as
/*				select amount1 format=13. FROM rate1*/
/*				union all*/
				select BDA_price as amount1 from bda_count_price;
				run;

				data lm_plus_bda;
				set lm_plus_bda1;
				run;

				proc sql noprint;
				select sum(amount1) format=dollar10. into: lm_bda_price from lm_plus_bda;
				quit;
				%put &lm_bda_price;

				/*BDA USER TOTAL*/

				proc sql;
				create table lm_bda_users1 as
/*				select sum(users) as count1 from price1*/
/*				union*/
				select BDA_count as count1 from bda_count_price;
				run;

				data lm_bda_users;
				set lm_bda_users1;
				run;

				proc sql noprint;
				select sum(count1) format=comma8. into: lm_bda_count from lm_bda_users;
				quit;
				%put &lm_bda_count;

				ods html text="" style=styles.nobreak; 
				ODS ESCAPECHAR='^';
				title j=left font = Calibri height=11Pt color=blumine;
				title "
				^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] BDA OPTION } ^{newline 2}
				^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the behavioral is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_bda_price } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
				"
				;

				ods html text="" style=mystyle; 
				proc report data=bda_email_results1 
				style(column)=[just=l]
				style(column)={width=7cm}
				style(report)=[bordercollapse=collapse borderspacing=0px bordercolor = #4975AD /*background=white cellspacing=0 borderrightcolor=#1f4e79
				           borderleftcolor=#1f4e79 bordertopcolor=#1f4e79 borderbottomcolor=#1f4e79*/ color=#1f4e79]
				style(column)=[background=white]
				style(header)=[just=l font_weight=bold background=white foreground=#1f4e79]
				style(summary)=[background=white]
				style(lines)=[background=#1f4e79]
				style(calldef)=[background=#1f4e79];
				compute Criteria;
				if Criteria = 'List Match + Behavioral' then do;
				CALL DEFINE(_ROW_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				if Criteria in ('List Match Users', 'Remaining Behavioral Segment**') then do;
				CALL DEFINE(_COL_, "STYLE",
				"STYLE={font_weight=bold background=white}");
				end;
				endcomp;
				run;


				/*BDA Chart Details*/
				%macro bda_chart_details_None2;
				%do i=1 %to 1;
					%if &bda_occ. ne "" and &bda_spec. ne "" %then %do;
						%if &drug_lookups_GE. = 1 %then %do; 
							ods html text="" style=styles.nobreak; 
							ODS ESCAPECHAR='^';
							title j=left font = Calibri height=11Pt color=blumine;
							title "
							^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs in the past &dispPeriod days}
							"
							;

							proc report data=noobs nowd
							style(report)={background=white foreground=white borderrightcolor=white
							           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
							style(header)={background=white foreground=white}
							style(column)={background=white foreground=white};
							column a;
							define a / " ";
							run;
						%end;

						%if &drug_lookups_GE. > 1 %then %do;
							ods html text="" style=styles.nobreak; 
							ODS ESCAPECHAR='^';
							title j=left font = Calibri height=11Pt color=blumine;
							title "
							^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs &drug_lookups_GE. + Times in the past &dispPeriod days}
							"
							;

							proc report data=noobs nowd
							style(report)={background=white foreground=white borderrightcolor=white
							           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
							style(header)={background=white foreground=white}
							style(column)={background=white foreground=white};
							column a;
							define a / " ";
							run;
						%end;
					%end;
					%if &bda_occ. ne "" and &bda_spec. = "" %then %do;
						%if &drug_lookups_GE. = 1 %then %do; 
							ods html text="" style=styles.nobreak; 
							ODS ESCAPECHAR='^';
							title j=left font = Calibri height=11Pt color=blumine;
							title "
							^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom who have looked up Drugs &drugs in the past &dispPeriod days}
							"
							;

							proc report data=noobs nowd
							style(report)={background=white foreground=white borderrightcolor=white
							           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
							style(header)={background=white foreground=white}
							style(column)={background=white foreground=white};
							column a;
							define a / " ";
							run;
						%end;

						%if &drug_lookups_GE. > 1 %then %do;
							ods html text="" style=styles.nobreak; 
							ODS ESCAPECHAR='^';
							title j=left font = Calibri height=11Pt color=blumine;
							title "
							^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom who have looked up Drugs &drugs &drug_lookups_GE. + Times in the past &dispPeriod days}
							"
							;

							proc report data=noobs nowd
							style(report)={background=white foreground=white borderrightcolor=white
							           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
							style(header)={background=white foreground=white}
							style(column)={background=white foreground=white};
							column a;
							define a / " ";
							run;
						%end;
					%end;
				%end;
				%mend;
				%bda_chart_details_None2;

			%end;
		%end;
	%end;
%end;
%mend;
%conditionals;


ODS ESCAPECHAR='^';
ods html text="" style=styles.nobreak; 
title j=left font = Calibri height=11Pt color=blumine;
title "
^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Please let me know if you have any questions.} ^{newline 1}
^{style [ FONT=(Calibri,11Pt) color=#1f4e79 ] Regards,} ^{newline 1}
"
;

proc report data=noobs nowd
style(report)={background=white foreground=white borderrightcolor=white
           borderleftcolor=white bordertopcolor=white borderbottomcolor=white borderwidth=0 }
style(header)={background=white foreground=white}
style(column)={background=white foreground=white};
column a;
define a / " ";
run;

ods html close;
ods _all_ close;
/* EMAIL END*/

/*multiSDAMacro*/


/*multiBDAMacro*/
