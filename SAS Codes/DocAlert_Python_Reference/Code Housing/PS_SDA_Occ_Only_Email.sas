options source source2 notes date center;

%let email_user= asinger;
%let sda_occ_nocom= MD, DO, NP, PA;

%macro fetch_docalerts
  (occupation_string,
   country_string,
   specialty_string,
   name_string
  );

  %local oks cks spe;

  proc sql noprint;

    %if %length(&occupation_string.) > 1 %then
    select key_value into:  oks separated by ','
    from   edwf.format_lookup
    where  column_name = 'OCCUPATION_KEY'
      and  fmtname = 'OK2ON'
      and  label in (&occupation_string.);;

       %if %length(&specialty_string.) > 1 %then
    select key_value into:  spe separated by ','
    from   edwf.format_lookup
    where  column_name = 'SPECIALTY_KEY'
      and  fmtname = 'SK2S2X'
      and  label in (&specialty_string.);;

    %if %length(&country_string.) > 1 %then
    select key_value into:  cks separated by ','
    from   edwf.format_lookup
    where  column_name = 'COUNTRY_KEY'
      and  fmtname = 'CK2COUN'
      and  label in (&country_string.);;

  proc sort data=da.customer_user out=&name_string. noequals;
    by user_account_key;
    where 1=1 
           and state_key NE 1083
       and primary_account_ind = 'Y'
          %if %length(&oks.)                     > 1 %then and occupation_key in (&oks.);
          %if %length(&cks.)                     > 1 %then and country_key in (&cks.);
          %if %length(&spe.)                     > 1 %then and specialty_key in (&spe.);
       ;
    run;

%mend fetch_docalerts;

%fetch_docalerts
  (
   occupation_string       =%nrstr("MD", "DO", "NP", "PA"),
   country_string          =%nrstr('United States of America'),
/*   specialty_string             =%nrstr ("Infectious Disease", "Surgery, General"),*/
   name_string					=%nrstr(card)
  ); 

proc sql;
create table bb as
select userid, occupation_key, specialty_key, state_key
from card 
where last_session_dt GE (today()-180) 
;
quit;

proc sql;
create table bb_profile as
select 
distinct userid,
case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
from bb t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;

data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;

proc freq data = bb_profile; tables occspec / out = bbfreq; run;

proc sql;
create table bbrate as
select a.occspec, a.count, b.rate
from bbfreq a
left join rate_card b on a.occspec = b.occspec;
quit;

data bbprice; set bbrate; price = rate*count; run;

proc sql;
select sum(price) as price into :bp from bbprice;
select sum(count) as count into :bc from bbprice;
quit;

proc sql;
select sum(price) as SDA_price into :bp from bbprice;
select sum(count) as SDA_count into :bc from bbprice;
quit;

proc sql;
create table sda_results as
select sum(price) as SDA_price, sum(count) as SDA_count
from bbprice;
quit;

%put &bp;
%put &bc;

proc sql;
create table sda_table_headers (Criteria char(25), Users numeric(25), Price numeric(25));
quit;

proc sql;
create table sda_count_price as
select 'Specialty Segment**' as type, SDA_count, round((SDA_price+499),1000) as SDA_price
FROM sda_results;
quit;

proc sql;
create table sda_email_results as
select * from sda_table_headers
union all
select * from sda_count_price;
quit;

data sda_email_results1;
set sda_email_results;
format Users Comma8.;
format Price Dollar10.;
run;

proc print data=sda_email_results1 noobs;
run;

/*CREATE SDA PRICE TOTAL VARIABLE*/

data lm_plus_sda;
set sda_email_results1;
run;

proc sql noprint;
select Price format=dollar10. into: lm_sda_price from lm_plus_sda;
quit;
%put &lm_sda_price;

/*CREATE SDA LIST MATCH TOTAL VARIABLE*/

data lm_sda_users;
set sda_email_results1;
run;

proc sql noprint;
select Users format=comma8. into: lm_sda_count from lm_sda_users;
quit;
%put &lm_sda_count;

option nocenter;
filename mymail email from="&email_user@athenahealth.com"
to=("&email_user@athenahealth.com")
subject="SDA Add On Table"
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
^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the client list and Specialty is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_price } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
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
if Criteria = 'Specialty Segment**' then do;
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
^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79]All Campaign ELigible &sda_occ_nocom.}
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
