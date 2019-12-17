
options source source2 notes date center;

/*INPUTS*/
%let matched_file= "/*folder*/\/*matchedFile*/";
%let occupation=/*BDA_Occ*/;
%let specialty= /*BDA_Spec*/;
%let email_user= /*username*/;
%let bda_occ_nocom= /*BDA_Occ_Disp*/;
%let bda_spec= /*BDA_Spec_Disp*/;
%let bda_lookback_period= /*dispPeriod*/;
%let drugs= /*drugList2*/;

data dmaster;
  input mk_drug $50.;   /*insert drug names where the yellow writing is... no commas or quotes*/
cards; 
/*drugList*/
;
run;


proc sql;
  create table drug_check as
  select distinct m.mk_drug, z.DRUG_KEY, f.key_value
  from dmaster m
left join edwf.format_lookup f on m.mk_drug = f.label
  left join uaw.drug_dim z on f.key_value = z.drug_key
where f.FMTNAME="DK2DN"
;
quit; 

proc sql;
select count(mk_drug) as orig_drug_count from dmaster;
select count(distinct key_value) as final_drug_count from drug_check;
quit;

proc sql;
create table unmatchedDrugs as
Select * from dmaster a
left join drug_check b on a.mk_drug=b.mk_drug
where b.mk_drug is null;
quit;

proc sql;
select mk_drug as miss_spelled_drugs from unmatchedDrugs;
quit;

**STOP HERE!!!!!  Make sure that orig_drug_count = final_drug_count in your output or reporting window! 
    If not, check spelling for missing drugs from drug_test****;

/*Inputs Default*/
%let country='United States of America';
%let state='Vermont';

/*Insert Custom drug list*/

/*Below section of code grabs format key value for each of the inputs above*/
/*drugs_list*/
proc sql noprint;
select distinct key_value into : drug_keys separated by ','
from drug_check;
quit;
/*country*/
proc sql noprint;
select
distinct put(key_value, 13.) into : country separated by ','
from edwf.format_lookup where put(key_value, ck2coun.) in (&country);
quit;
/*state*/
proc sql noprint;
select
distinct put(key_value, 13.) into : state separated by ','
from edwf.format_lookup where put(key_value, sk2sn.) in (&state);
quit;
proc sql noprint;
select
distinct put(key_value, 13.) into : occupation separated by ','
from edwf.format_lookup where put(key_value, ok2on.) in (&occupation);
quit;
proc sql noprint;
select
distinct put(key_value, 13.) into : specialty separated by ','
from edwf.format_lookup where put(key_value, SK2S2X.) in (&specialty);
quit;

/*****STOP!!!!  Make sure that the number of days selected below reflects the true value of one month.*/

Proc Sql;
  select put(today()-/*LookUpPeriod*/, 13.) into :days
  from uaw.drug_therapeuticclass_map (obs=1);

proc sort data=uaw.Drug_rx_1yr out=d nodupkey;
  by user_account_key;
  where drug_key in (&drug_keys.)
  and event_date > &days.;
  quit;

proc sql;
  create table _4wk as
  select cu.userid, cu.occupation_key, cu.specialty_key
  from da.customer_user (keep=user_account_key userid occupation_key specialty_key state_key Country_key primary_account_ind last_session_dt) cu
       inner join d on cu.user_account_key = d.user_account_key
	where cu.last_session_dt GE today()-180
	and cu.primary_account_ind = 'Y' 
	and cu.country_key = &country 
	AND cu.state_key NOT = &state 
	AND cu.occupation_key IN (&occupation)
	AND cu.specialty_key IN (&specialty)
	AND put(state_key,sk2sn.) NOT IN ("Vermont", "Colorado")
;
quit;

data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

data match; set &matched_file.; run;
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

proc freq data = match_profile; tables occspec / out = freq; run;

proc sql;
create table rate as
select a.occspec, a.count, b.rate
from freq a
left join rate_card b on a.occspec = b.occspec;
quit;

data rate1; set rate; new_rate = rate*1.2; run;

data price; set rate1; price = new_rate*count; run;

proc sql;
select sum(price) as CL_price into :p from price;
select sum(count) as CL_count into :c from price;
quit;


%put &p;
%put &c;

proc sql outobs=1;
create table CL_results as
select &c. as campaign_eligible, &p. as roundedPrice
from price;
quit;

Proc sql;
create table new_bb as 
select a.*
from _4wk a 
left join match b on a.userid=b.userid
where b.userid is null;
quit;

proc sql;
create table bb_profile as
select 
distinct userid,
case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
from new_bb t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;

proc freq data = bb_profile; tables occspec / out = bbfreq; run;

proc sql;
create table bbrate as
select a.occspec, a.count, b.rate
from bbfreq a
left join rate_card b on a.occspec = b.occspec;
quit;

data bbprice; set bbrate; price = rate*count; run;

proc sql;
select sum(price) as BDA_price into :bp from bbprice;
select sum(count) as BDA_count into :bc from bbprice;
quit;

proc sql;
create table bda_results as
select sum(price) as BDA_price, sum(count) as BDA_count
from bbprice;
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
^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79] Campaign eligible &bda_occ_nocom (who specialize in &bda_spec and) who have looked up Drugs &drugs in the past &bda_lookback_period days}
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


