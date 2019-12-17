options source source2 notes date center;

/*SUPPRESSION INPUTS*/
%let suppApplied = /*suppApplied*/;
%let supp = "/*suppFolder*/\/*suppFile*/";

%let excludeStates = /*statesToExclude*/;

*************************************************;
%let Product = DocAlert;
%let totalBDAS = /*BDA_Total*/;
%let therapy_class= /*therapyClass*/;
%let lookups_GE = /*totalLookUps*/; /*Put in how many  times a user looked up a drug (i.e. 2+ or 3+)*/
%let occupation = /*BDA_Occ*/;
%let specialty = /*BDA_Spec*/;
%let matched_file= "/*matchedFile*/";
%let email_user= /*username*/;
%let bda_occ_nocom= /*BDA_Occ_Disp*/;
%let bda_spec= /*BDA_Spec_Disp*/;
%let bda_lookback_period= /*dispPeriod*/;
%let drugs= /*drugList2*/;
%let lookupdate = /*activeUserDate*/;

data dmaster;
input mk_drug $50.;   /*insert drug names where the yellow writing is... no commas or quotes*/
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


%macro drug_therapy;
%do i=1 %to 1;

	%if &therapy_class. = Yes %then %do;
		proc sql;
		create table drugs_from_class as
		select distinct m.mk_drug, x.DRUG_KEY, x.THERAPEUTIC_CLASS_KEY
		from dmaster m, uaw.drug_therapeuticclass_map x
		where put(x.THERAPEUTIC_CLASS_KEY, TCK2TCN.) in (select m.mk_drug from dmaster m)
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
 	 	from dmaster m
		left join edwf.format_lookup f on m.mk_drug = f.label
	  	left join uaw.drug_dim z on f.key_value = z.drug_key
		where f.FMTNAME="DK2DN"
		;quit; 

		proc sql noprint;
		select count(mk_drug) as orig_drug_count into :input_drugs from dmaster;
		select count(distinct key_value) as final_drug_count into :output_drugs from drug_check;
		quit;

		proc sql;
		create table unmatchedDrugs as
		Select * from dmaster a
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

		proc sql;
		select mk_drug as miss_spelled_drugs from unmatchedDrugs;
		quit;
	%end;
%end;
%mend;
%drug_therapy;

proc sql noprint;
select distinct key_value into : drug_keys separated by ','
from drug_check;
quit;

/*Change the occupation and specialty if needed*/
/*campaign eligible users*/
proc sql;
create table PRE_DFU as
select user_account_key, occupation_key, specialty_key, userid
from da.customer_user
where last_session_dt GE &user_lookup_date.-180
and last_session_dt LE &user_lookup_date.
and primary_account_ind = "Y"
and put(country_key,CK2COUN44.) = "United States of America"
and put(occupation_key,ok2on.) IN (&occupation)
and put(specialty_key,SK2S2X38.) IN (&specialty)
AND put(state_key,sk2sn.) NOT IN (&excludeStates.)
AND put(state_key,sk2sn.) NOT IN ("Europe,Mid East,Af,Can","Pacific");
;quit;

proc sql;
create table PRE_DFU2 as
select a.user_account_key, a.occupation_key, a.specialty_key, a.userid, b.drug_key, sum(sum_events) as lookups
from PRE_DFU a
left join uaw.Drug_rx_1yr b on a.user_account_key = b.user_account_key
where drug_key in (&drug_keys.)
and b.event_date GE &user_lookup_date.-/*LookUpPeriod*/
and b.event_date LE &user_lookup_date.
group by 1
;quit;

proc sql;
create table DFU as 
select distinct a.user_account_key, b.*
from PRE_DFU2 a
left join PRE_DFU b on a.user_account_key = b.user_account_key
where lookups GE &lookups_GE.
;quit;

data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

data match; set &matched_file.; run;
%macro suppression1;
%do i=1 %to 1;

	%if &suppApplied = Yes %then %do;
		data supp; set &supp.; run;

		proc sql;
		create table supp_matched as
		select distinct a.*
		FROM match a
		left join supp b on a.userid=b.userid
		where b.userid is null;
		quit;

		proc sql noprint;
		select count(userid) into :ncount from supp_matched;
		quit;

		proc sql;
		create table match_profile as
		select 
		distinct userid,
		case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
		from supp_matched t 
		left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
		inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
		quit;
	%end;

	%if &suppApplied = No %then %do;

		proc sql noprint;
		select count(userid) into :ncount from match;
		quit;

		proc sql;
		create table match_profile as
		select 
		distinct userid,
		case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
		from match t 
		left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
		inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
		quit;
	%end;
%end;
%mend;
%suppression1;

proc freq data = match_profile; tables occspec / out = freq; run;

	proc sql;
	create table client_rate as
	select a.occspec, a.count, b.rate
	from freq a
	left join rate_card b on a.occspec = b.occspec;
	quit;

%macro client_list_pricing;

	%if &Product = DocAlert %then %do;
	data client_price; set client_rate; price = rate*count*1.2; run;
	%end;

	%if &Product = Epoc_Quiz %then %do;
	data client_price; set client_rate; price = rate*count*1.2*1.25; run;
	%end;

	%if &Product = Triggered %then %do;
	data client_price; set client_rate; price = rate*count*1.2*1.15; run;
	%end;

%mend;
%client_list_pricing;


proc sql;
select sum(price) as CL_price into :p from client_price;
select sum(count) as CL_count into :c from client_price;
quit;

%put &p;
%put &c;

proc sql outobs=1;
create table CL_results as
select &c. as campaign_eligible, &p. as roundedPrice
from client_price;
quit;

%macro suppression2;
%do i=1 %to 1;

	%if &suppApplied = Yes %then %do;

		Proc sql;
		create table new_bb as 
		select a.*
		from DFU a 
		left join match b on a.userid=b.userid
		left join supp c on a.userid=c.userid
		where b.userid is null
		and c.userid is null;
		quit;
	%end;

	%if &suppApplied = No %then %do;

		Proc sql;
		create table new_bb as 
		select a.*
		from DFU a 
		left join match b on a.userid=b.userid
		where b.userid is null;
		quit;
	%end;
%end;
%mend;
%suppression2

proc sql;
create table bda_profile as
select distinct userid,
case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
from new_bb t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;

proc sql noprint;
select count(userid) into :num from bda_profile;
quit;

proc freq data = bda_profile; tables occspec / out = bdafreq; run;

proc sql;
create table bdarate as
select a.occspec, a.count, b.rate
from bdafreq a
left join rate_card b on a.occspec = b.occspec;
quit;

%macro add_on_pricing;

	%if &Product = DocAlert %then %do;
	data bdaprice; set bdarate; price = rate*count; run;
	%end;

	%if &Product = Epoc_Quiz %then %do;
	data bdaprice; set bdarate; price = rate*count*1.25; run;
	%end;

	%if &Product = Triggered %then %do;
	data bdaprice; set bdarate; price = rate*count*1.15; run;
	%end;

%mend;
%add_on_pricing;

proc sql;
select sum(price) as BDA_price into :bp from bdaprice;
select sum(count) as BDA_count into :bc from bdaprice;
quit;

proc sql;
create table bda_results as
select sum(price) as BDA_price, sum(count) as BDA_count
from bdaprice;
quit;

%put &bp;
%put &bc;


proc sql;
create table bda_table_headers (Criteria char(25), Users numeric(25), Price numeric(25));
quit;

/*proc sql;*/
/*create table finalPrice as*/
/*Select list_price*1.2 as rounded*/
/*FROM tempm;*/
/*quit;*/

proc sql;
create table bda_list_match as
Select distinct 'List Match Users' as type, campaign_eligible, round((roundedPrice+499),1000) as roundedPrice
FROM CL_results;
quit;

proc sql;
create table bda_count_price as
select 'Remaining Behavioral Segment**' as type, BDA_count, round((BDA_price+499),1000) as BDA_price
FROM bda_results;
quit;

proc sql;
create table list_bda_total as
Select 'List Match + Behavioral', (campaign_eligible + BDA_count) as listTotal, (roundedPrice + BDA_price) as priceTotal
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

proc print data=bda_email_results1 noobs;
run;

data rate1;
set CL_results;
amount=campaign_eligilbe; 
amount1=round((amount+499),1000);
drop amount;
format amount1 dollar10.;
run;

/*CREATE BDA PRICE TOTAL VARIABLE*/
proc sql;
create table lm_plus_bda1 as
select priceTotal format=13. FROM list_bda_total;
run;

data lm_plus_bda;
set lm_plus_bda1;
run;

proc sql noprint;
select priceTotal format=dollar10. into: lm_bda_price from lm_plus_bda;
quit;
%put &lm_bda_price;

/*CREATE BDA LIST MATCH TOTAL VARIABLE*/
proc sql;
create table lm_bda_users1 as
select listTotal as count1 from list_bda_total;
run;

data lm_bda_users;
set lm_bda_users1;
run;

proc sql noprint;
select listTotal format=comma8. into: lm_bda_count from list_bda_total;
quit;
%put &lm_bda_count;




option nocenter;
filename mymail email from="&email_user@athenahealth.com"
to=("&email_user@athenahealth.com")
subject="BDA Add On Table"
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

data noobs;
a='';
run;

ODS ESCAPECHAR='^';
ods html body=mymail style=mystyle;
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
ods html text="" style=mystyle; 
ODS ESCAPECHAR='^';
title j=left font = Calibri height=11Pt color=blumine;
title "
^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs &lookups_GE + Times in the past &bda_lookback_period days}
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


/*multiBDAMacro*/