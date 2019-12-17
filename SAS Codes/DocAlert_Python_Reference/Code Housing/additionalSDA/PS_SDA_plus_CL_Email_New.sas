options source source2 notes date center;

/*SUPPRESSION INPUTS*/
%let suppApplied = /*suppApplied*/;
%let suppNotUsed = "/*suppFolder*/\/*suppFile*/";

%let Product = DocAlert;
%let matched_file = "/*matchedFilePath*/";
%let sda_only = /*sda_only*/;

%let sda_occ = /*SDA_Occ*/;
%let sda_spec = /*SDA_Spec*/;

%let email_user= /*username*/;
%let sda_occ_nocom= /*SDA_Occ_Disp*/;
%let sda_spec2= /*SDA_Spec_Disp*/;


%macro set_matchFile;
%do i=1 %to 1;
	%if &sda_only = Y %then %do;
		data match;
		set &matched_file.;
		run;
	%end;
%end;
%mend;
%set_matchFile;

%macro sda_macro;
%do i=1 %to 1;
	%if &sda_occ. ne "" %then %do;
		%if &sda_spec. ne "" %then %do;
			proc sql;
			create table bb/*inc*/ as 
			select distinct userid, occupation_key, specialty_key
			from da.customer_user_nppes
			where primary_account_ind = "Y"
			and put(country_key,CK2COUN.) = "United States of America"
			and last_session_dt GE (today()-180)  
			and put(specialty_key,SK2S2X.) in (&sda_spec.)
			and put(occupation_key, OK2ON.) in (&sda_occ.)
			AND put(state_key,sk2sn.) NOT IN ("Vermont", "Colorado")
			;quit;
		%end;

		%else %if &sda_spec. = "" %then %do;  
			proc sql;
			create table bb/*inc*/ as 
			select distinct userid, occupation_key, specialty_key
			from da.customer_user_nppes
			where primary_account_ind = "Y"
			and put(country_key,CK2COUN.) = "United States of America"
			and last_session_dt GE (today()-180)  
			and put(occupation_key, OK2ON.) in (&sda_occ.)
			AND put(state_key,sk2sn.) NOT IN ("Vermont", "Colorado")
			;quit;
		%end;
	%end;
%end;
%mend;
%sda_macro;

data rate_card; set 'J:\MKrich\list match pricing\current_rate_card'; run;


%macro client_list_macro;
%do i=1 %to 1;

	%if &list_match_type. ne None or &matched_file. ne "" %then %do;
		%if &suppApplied = Yes %then %do;
			/*data supp; set &supp.; run;*/

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
			data client_price; set client_rate; price = rate*count*1.25; run;
			%end;

			%if &Product = Triggered %then %do;
			data client_price; set client_rate; price = rate*count*1.15; run;
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
	%end;

%end;
%mend;
%client_list_macro;


%macro suppression2;
%do i=1 %to 1;

	%if &list_match_type. ne None or &matched_file. ne "" %then %do;
		%if &suppApplied = Yes %then %do;

			Proc sql;
			create table new_bb/*inc*/ as 
			select distinct a.*
			from bb/*inc*/ a 
			left join match b on a.userid=b.userid
			left join supp c on a.userid=c.userid
			where b.userid is null
			and c.userid is null;
			quit;
		%end;

		%if &suppApplied = No %then %do;

			Proc sql;
			create table new_bb/*inc*/ as 
			select distinct a.*
			from bb/*inc*/ a 
			left join match b on a.userid=b.userid
			where b.userid is null;
			quit;
		%end;
	%end;

	%if &list_match_type. = None and &matched_file. = "" %then %do;
		%if &suppApplied = Yes %then %do;

			Proc sql;
			create table new_bb/*inc*/ as 
			select distinct a.*
			from bb/*inc*/ a 
			left join supp b on a.userid=b.userid
			where b.userid is null;
			quit;
		%end;

		%if &suppApplied = No %then %do;

			Proc sql;
			create table new_bb/*inc*/ as 
			select distinct a.*
			from bb/*inc*/ a;
			quit;
		%end;
	%end;

%end;
%mend;
%suppression2

proc sql;
create table bb_profile/*inc*/ as
select 
distinct userid,
case when (f1.label = 'MD' OR f1.label = 'DO') then CATX(' - ','MD/DO',f2.label) else f1.label end as occspec
from new_bb/*inc*/ t 
left join edwf.format_lookup (where=(fmtname='OK2ON')) f1 on t.occupation_key = f1.key_value
inner join edwf.format_lookup (where=(fmtname='SK2S2X')) f2 on t.specialty_key = f2.key_value;
quit;

proc freq data = bb_profile/*inc*/; tables occspec / out = bbfreq/*inc*/; run;

proc sql;
create table bbrate/*inc*/ as
select a.occspec, a.count, b.rate
from bbfreq/*inc*/ a
left join rate_card b on a.occspec = b.occspec;
quit;

%macro add_on_pricing;

	%if &Product = DocAlert %then %do;
	data bbprice/*inc*/; set bbrate/*inc*/; price = rate*count; run;
	%end;

	%if &Product = Epoc_Quiz %then %do;
	data bbprice/*inc*/; set bbrate/*inc*/; price = rate*count*1.25; run;
	%end;

	%if &Product = Triggered %then %do;
	data bbprice/*inc*/; set bbrate/*inc*/; price = rate*count*1.15; run;
	%end;

%mend;
%add_on_pricing;

data bbprice/*inc*/; set bbrate/*inc*/; price = rate*count; run;

proc sql;
select sum(price) as SDA_price/*inc*/ into :bp/*inc*/ from bbprice/*inc*/;
select sum(count) as SDA_count/*inc*/ into :bc/*inc*/ from bbprice/*inc*/;
quit;

proc sql;
create table sda_results as
select sum(price) as SDA_price, sum(count) as SDA_count
from bbprice/*inc*/;
quit;

%put &bp/*inc*/;
%put &bc/*inc*/;


%macro build_final_email_table;

	%if &list_match_type. ne None or &matched_file. ne "" %then %do;
		proc sql;
		create table sda_table_headers (Criteria char(25), Users numeric(25), Price numeric(25));
		quit;

		proc sql;
		create table sda_list_match as
		Select distinct 'List Match Users' as type, campaign_eligible, round((roundedPrice+499),1000) as roundedPrice
		FROM CL_results;
		quit;

		proc sql;
		create table sda_count_price as
		select 'Remaining Specialty Segment**' as type, SDA_count, round((SDA_price+499),1000) as SDA_price
		FROM sda_results;
		quit;

		proc sql;
		create table list_sda_total as
		Select 'List Match + Specialty', (campaign_eligible + SDA_count) as listTotal, (roundedPrice + SDA_price) as priceTotal
		FROM sda_list_match, sda_count_price;
		quit;

		proc sql;
		create table sda_email_results as
		select * from sda_table_headers
		union all
		select * from sda_list_match
		union all
		select * from sda_count_price
		union all
		select * from list_sda_total;
		quit;


		data rate1;
		set CL_results;
		amount=campaign_eligilbe; 
		amount1=round((amount+499),1000);
		drop amount;
		format amount1 dollar10.;
		run;

		/*CREATE BDA PRICE TOTAL VARIABLE*/
		proc sql;
		create table lm_plus_sda1 as
		select priceTotal format=13. FROM list_sda_total;
		run;

		data lm_plus_sda;
		set lm_plus_sda1;
		run;

		proc sql noprint;
		select priceTotal format=dollar10. into: lm_sda_price from lm_plus_sda;
		quit;
		%put &lm_sda_price;

		/*CREATE BDA LIST MATCH TOTAL VARIABLE*/
		proc sql;
		create table lm_sda_users1 as
		select listTotal as count1 from list_sda_total;
		run;

		data lm_sda_users;
		set lm_sda_users1;
		run;

		proc sql noprint;
		select listTotal format=comma8. into: lm_sda_count from list_sda_total;
		quit;
		%put &lm_sda_count;		
	%end;

	%if &list_match_type. = None and &matched_file. = "" %then %do;
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
	%end;

	data sda_email_results1;
	set sda_email_results;
	format Users Comma8.;
	format Price Dollar10.;
	run;

	proc print data=sda_email_results1 noobs;
	run;

%mend;
%build_final_email_table;


option nocenter;
filename mymail email from="&email_user@athenahealth.com"
to=("&email_user@athenahealth.com")
subject="SDA Add On Table/*inc*/"
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

%macro sda_table_title;
	%if &list_match_type. ne None or &matched_file. ne "" %then %do;
		ODS ESCAPECHAR='^';
		ods html body=mymail style=mystyle;
		title j=left font = Calibri height=11Pt color=blumine;
		title "
		^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 2}
		^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the client list and Specialty is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_price } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
		"
		;
	%end;

	%if &list_match_type. = None and &matched_file. = "" %then %do;
		ODS ESCAPECHAR='^';
		ods html body=mymail style=mystyle;
		title j=left font = Calibri height=11Pt color=blumine;
		title "
		^{style [Font_weight=bold textdecoration=underline FONT=(Calibri,11Pt) color=#1f4e79 ] Requested Add-on Pricing: } ^{newline 2}
		^{style [FONT=(Calibri,11Pt) color=#1f4e79 ] The total size of the Specialty is } ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_count } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] campaign eligible users. The total price to target all these users is} ^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] &lm_sda_price } ^{style [FONT=(Calibri,11Pt) color=#1f4e79] per wave.}
		"
		;
	%end;

%mend;
%sda_table_title;


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
if Criteria = 'List Match + Specialty' then do;
CALL DEFINE(_ROW_, "STYLE",
"STYLE={font_weight=bold background=white}");
end;
if Criteria in ('List Match Users', 'Remaining Specialty Segment**') then do;
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
^{style [Font_weight=bold FONT=(Calibri,11Pt) color=#1f4e79] **} ^{style [FONT=(Calibri,11Pt) color=#1f4e79]&sda_occ_nocom who specialize in &sda_spec2.}
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