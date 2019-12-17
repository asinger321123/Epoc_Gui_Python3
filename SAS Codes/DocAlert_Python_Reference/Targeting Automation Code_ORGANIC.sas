options mprint mlogic source source2 notes date center;

*******************TARGETING**********************;

/*TARGETING INPUTS*/
%let Product= /*DocORQuiz*/; /*(DocAlert/Epoc_Quiz)*/
%let filepath2 = /*target_text_file*/\Organic; /*Paste file location of target.txt file*/
%let folder = /*targetFoler*/;
%let dump = P:\Epocrates Analytics\TARGETS\/*Date*/\targetdump;

/*CLIENT LIST INPUTS*/
%let Targeting_CL_Type = /*listMatchType*/; /*What type of list match are you running: (Standard/Exact/Standard_Seg/Exact_Seg) If not running list match put (None)*/
%let target_numbers= /*TargetNum*/; /*Can be 1 or Multiple. IF MULTIPLE YOU MUST SEPERATE WITH A SPACE*/
%let variable= /*segVar*/; /*The name of the column that is getting segmented*/
%let seg_nocommas= /*segValues*/; /*Seperate each segment criteria by a space. Make sure the criteria itself does not have a space or special chars. in it*/
%let dataCap= "";
%let scheduleIDs = /*openerScheduleIDs*/;
%let lookupdate = /*activeUserDate*/;

%let backFill_Segment = No;
%let segsNeeded = ;
%let cappedSeg = ;

/*State or Zip Inputs*/
%let excludeStates = /*statesToExclude*/;
%let applyToClientList = /*applyToClientList*/;
%let applyToSda = /*applyToSda*/;
%let applyToBda = /*applytoBda*/;
%let queryByState = /*queryStates*/;
%let queryByZip = /*queryZips*/;
%let statesToQuery = /*statesToQuery*/;

/*CLIENT LIST DATASHARING*/
%let DataSharing = /*dataShareYorN*/;/*(Y/N)*/
%let seg= /*Segments*/;  /***THIS IS FOR DATASHARING SEGMENTS. SEPERATE YOU MUST INCLUDE THE VARIABLE COLUMN***/
%let keep_segment_variable= /*keep_seg*/; /*if you need the segment column for datasharing then = Yes; if you need to drop then = No;*/
%let Manufacturer = /*Manu*/;   /*Input the manufacturer as it appears in the custom folder*/
%let amgenSegs = /*Segments*/ as zip;

/*SUPPRESSION INPUTS*/
/*suppression file must be labeled supp.txt*/

%let suppression = /*suppApplied*/; /* Yes/No */
%let supp_filepath = /*supp_text_file*/; /*File location of supp.txt file, which must be different from the Target folder to avoid overwriting the target's _matched file. Example: P:\Epocrates Analytics\Individual\ARubin\New Codes\Test\supp*/
%let suppression_match_type = /*supp_Match_Type*/; /*(Standard/Exact)*/

*************************************************;

/*USER INFO*/
%let rvp = T;  /*Requester's initials*/
%let brand = /*Brand*/; /*Brand Name*/
%let analyst = ?MY_INIT?; /*Your initials*/
*************************************************;

/*SDA INPUTS*/
%let supp_SDA_Only = N; /*Apply suppression only to SDA. Y or N*/
%let Sda_Only = N; /*Only running SDA or SDA + BDA. (Y/N)*/ 
%let sda_occ= ""; /*Specialty occupations listed with quotes & commas if necessary ("MD","DO")*/
%let sda_spec= ""; /*Specialty specialties listed with quotes & commas if necessary ("Family Practice","Cardiology")*/
%let sda_tgt= ; /*SDA T-#####*/


*************************************************;
/*BDA INPUTS*/
%let supp_BDA_Only = N; /*Apply suppression only to BDA. Y or N*/
%let Bda_only = N; /*Only running BDA. (Y/N)*/ 
%let Dedupe_from_Sda = N;		/*Dedupe Dedupe from SDA (Y/N)*/
%let bda_lookback_period = ;	/*Insert Lookup Period for the Drugs (31)*/
%let drug_lookups_GE = ; 	/*Number of Lookups requested (1)*/
%let bda_occ = ""; /*Behavioral Occupations listed with quotes and commas ("MD","DO")*/
%let bda_spec = ""; /*Behavioral specialties listed with quotes and commas ("Family Practice","Cardiology")*/
%let bda_tgt= ; /*BDA T-#####*/

data bda_drugs; input mk_drug $50.;   /*insert drug names 1 per line underneath the "cards;" and above ";run;". No commas or quotes. The names will turn yellow.*/
cards;
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

*************************************************;
/*CODE STARTS BELOW*/

/*Check if Manufacture is GSK and if user is trying to run Fuzzy Match and abort*/
%macro check_manufacturer;
%do i=1 %to 1;
	%if ("&Manufacturer" = "GSK") and ((&Targeting_CL_Type = Standard) or (&Targeting_CL_Type = Standard_Seg)) %then %do;
    %abort cancel;
    %end;
%end;
%mend;
%check_manufacturer;

%macro CL_list; 
%do i=1 %to 1;
%if &suppression = Yes %then %do;
	LIBNAME SUPP "&supp_filepath";
	%if &suppression_match_type = Standard %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Presales\Supp_Standard.sas"; %end;
	%else %if &suppression_match_type = Exact %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Presales\Supp_Exact.sas"; %end;
data supp; set supp._supp_%trim(&suppcount.); run;
%end;


%if (&Targeting_CL_Type = Standard) and (&DataSharing = Y) %then %do; %include "P:\Epocrates Analytics\Code_Library\Standard_Codes\Pre Sales\DocAlert_Python_Reference\Code Housing\targeting\Standard_Organic.sas"; %end;
%else %if (&Targeting_CL_Type = Standard) and (&DataSharing = N) %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Targeting\Standard_no_data.sas"; %end;
%else %if &Targeting_CL_Type=Standard_Seg  %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Targeting\Standard_Seg.sas"; %end;
%else %if (&Targeting_CL_Type=Exact) and (&DataSharing = N) %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Targeting\Exact.sas"; %end;
%else %if (&Targeting_CL_Type=Exact) and (&DataSharing = Y) %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Targeting\Exact_w_data.sas"; %end;
%else %if &Targeting_CL_Type=Exact_Seg  %then %do; %include "P:\Epocrates Analytics\Individual\ARubin\New Codes\Code Housing\Targeting\Exact_Seg.sas"; %end;

%if &Targeting_CL_Type. ne None %then %do;
data match; set ORGANIC._organic_%trim(&ncount.); run;
%end;

%end;
%mend;
%CL_list;

data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

/*Add-On Macro*/
/*SDA*/
%macro Add_Ons; 
%do i=1 %to 1;
  %if &sda_occ. ne "" %then %do;
	%if &sda_spec. ne "" %then %do;
	proc sql;
	create table SDA as 
	select distinct userid, occupation_key, specialty_key
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
	select distinct userid, occupation_key, specialty_key
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

	proc sql;
	select count(distinct userid) as SDA_Comp_Count into: SDA_Comp_Count from SDA;
	quit;

	%put &SDA_Comp_Count;

	%if &suppression = No %then %do;
		%if &Sda_only. = N %then %do;
		Proc sql;
		create table sda_dedupe as 
		select distinct a.*
		from sda a 
		left join match b on a.userid=b.userid
		where b.userid is null
		;quit;
		%end;

		%else %if &Sda_only. = Y %then %do;
		Proc sql;
		create table sda_dedupe as 
		select distinct a.*
		from sda a 
		;quit;
		%end;
	%end;

	%else %if &suppression = Yes %then %do;
		%if &Sda_only. = N %then %do;
		Proc sql;
		create table sda_dedupe as 
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
		create table sda_dedupe as 
		select distinct a.*
		from sda a 
		left join supp c on a.userid=c.userid
		where c.userid is null
		;quit;
		%end;
	%end;

	/*proc sql;
	select count(distinct userid) as suppression_applied into: suppression_applied
	from sda_dedupe;
	quit;

	%put (&SDA_Comp_Count)-(&suppression_applied);*/

	proc sql;
	create table sda_profile as
	select distinct userid,
	case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
	from sda_dedupe t 
	left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
	inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
	quit;

	proc sql;
	create table sda_final as
	select distinct userid
	from sda_profile;
	quit;

	data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

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

 	%if "&sda_tgt" ^= "" %then %do;

	/*Export*/

	proc sql noprint;
	select count(distinct userid) into :n from sda_final; 
	quit;

	proc export data=work.sda_final outfile="&folder.\&sda_tgt._&n..csv" dbms=csv replace; putnames = no; run;
	proc export data=work.sda_final outfile="&dump.\&sda_tgt._&n..csv" dbms=csv replace; putnames = no; run;

  	%end;
  %end;

Proc contents data=work._all_ noprint out=work_data;quit;run;

Proc sql noprint;
Select count(mk_drug) as number_of_drugs into :num_of_drugs
from Bda_drugs 
where mk_drug ne ""
;quit; 

%if &num_of_drugs. > 0  %then %do;
	/*BDA*/
	%if &bda_occ. ne ""  %then %do;
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

		data final_drug_check;
		length Drug_Check $50;
		if &input_drugs. = &output_drugs. then Drug_Check = 'All Drugs found';
		else Drug_Check =  '**ERROR** 1 or more drugs are mispelled';
		run; 

		proc print data=final_drug_check noobs;
		run;


		proc sql noprint;
		select distinct key_value into : drug_keys separated by ','
		from drug_check;
		quit;

	/*	All users*/
		%if &bda_occ. = "" and &bda_spec. = "" %then %do;
			proc sql;
			create table bda_filter1 as
			select distinct user_account_key, occupation_key, specialty_key, userid
			from da.customer_user_nppes
			where last_session_dt GE &user_lookup_date.-180 
			and last_session_dt LE &user_lookup_date.
			and primary_account_ind = "Y"
			and put(country_key,CK2COUN44.) = "United States of America"
			AND put(state_key,sk2sn.) NOT IN (&excludeStates.)
			AND put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific")
			;quit;
		%end;

	/*	Only specific Occupations*/
		%else %if &bda_occ. ne "" and &bda_spec. = "" %then %do;  
			proc sql;
			create table bda_filter1 as
			select distinct user_account_key, occupation_key, specialty_key, userid
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

	/*	Only specific Occupations AND Specialties*/
		%if &bda_occ. ne "" and &bda_spec. ne "" %then %do;
			proc sql;
			create table bda_filter1 as
			select distinct user_account_key, occupation_key, specialty_key, userid
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

	/* 	Filtering the Behavioral Occupation/Specialties for users who looked up XX drugs  */
		proc sql;
		create table bda_filter2 as
		select distinct a.user_account_key, a.occupation_key, a.specialty_key, a.userid, b.drug_key, sum(sum_events) as lookups
		from bda_filter1 a
		left join uaw.Drug_rx_1yr b on a.user_account_key = b.user_account_key
		where drug_key in (&drug_keys.)
		and b.event_date GE &user_lookup_date.-(&bda_lookback_period.)
		and b.event_date LE &user_lookup_date.
		group by 1
		;quit;

		proc sql;
		select count(distinct userid) as BDA_Comp_Count into: BDA_Comp_Count from bda_filter2;
		quit;

		%put &BDA_Comp_Count;

		proc sql;
		create table bda_filter3 as 
		select distinct a.user_account_key, b.*
		from bda_filter2 a
		left join bda_filter1 b on a.user_account_key = b.user_account_key
		where lookups GE &drug_lookups_GE.
		;quit;

	%if &Bda_only. = Y %then %do;
		%if &suppression = No %then %do;
			Proc sql;
			create table bda_dedupe as 
			select distinct a.*
			from bda_filter3 a 
			;quit;
		%end;

		%else %if &suppression = Yes %then %do;
			Proc sql;
			create table bda_dedupe as 
			select distinct a.*
			from bda_filter3 a 
			left join supp b on a.userid=b.userid
			where b.userid is null
			;quit;
		%end;
	%end;

	%if &Bda_only. = N %then %do;
		%if &Dedupe_from_Sda. = N %then %do;
			%if &Targeting_CL_Type. = None %then %do;
				%if &suppression = No %then %do;
					Proc sql;
					create table bda_dedupe as 
					select distinct a.*
					from bda_filter3 a 
					;quit;
				%end;

				%else %if &suppression = Yes %then %do;
					Proc sql;
					create table bda_dedupe as 
					select distinct a.*
					from bda_filter3 a 
					left join supp b on a.userid=b.userid
					where b.userid is null
					;quit;
				%end;
			%end;
			
			%else %if &Targeting_CL_Type. ne None %then %do;

				%if &suppression = No %then %do;
					Proc sql;
					create table bda_dedupe as 
					select distinct a.*
					from bda_filter3 a 
					left join match b on a.userid=b.userid
					where b.userid is null;
					quit;
				%end;

				%else %if &suppression = Yes %then %do;
					Proc sql;
					create table bda_dedupe as 
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
		%else %if &Dedupe_from_Sda. = Y %then %do;
			%if &suppression = No %then %do;
				proc sql;
				create table cl_sda_users as
				select distinct userid
				from match
				union
				select distinct userid
				from sda_final
				;quit;

				Proc sql;
				create table bda_dedupe as 
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
				from sda_final
				union 
				select distinct userid
				from supp
				;quit;

				Proc sql;
				create table bda_dedupe as 
				select distinct a.*
				from bda_filter3 a 
				left join cl_supp_sda_users b on a.userid=b.userid
				where b.userid is null;
				quit;
			%end;
		%end;
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

		%if &Product. = DocAlert %then %do;
		data bda_price; set bda_rate; price = rate*count; run;
		%end;

		%if &Product. = Epoc_Quiz %then %do;
		data bda_price; set bda_rate; price = rate*count*1.25; run;
		%end;

		%if &Product. = Triggered %then %do;
		data bda_price; set bda_rate; price = rate*count*1.15; run;
		%end;

		proc sql;
		select sum(price) as BDA_price into :bp from bda_price;
		select sum(count) as BDA_count into :bc from bda_price;
		quit;

		%put &bdap;
		%put &bdac;

		proc sql noprint;
		select count(distinct userid) into :n from bda_profile; 
		quit;

		proc sql;
		create table bda_userid as
		select distinct userid
		from bda_profile;
		quit;

		proc export data=work.bda_userid outfile="&folder.\&bda_tgt._&n..csv" dbms=csv replace; putnames = no; run;
		proc export data=work.bda_userid outfile="&dump.\&bda_tgt._&n..csv" dbms=csv replace; putnames = no; run;
	%end;
%end;
%end;
%mend;
%Add_Ons;
