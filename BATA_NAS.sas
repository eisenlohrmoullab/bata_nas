/*BATA 2022 NAS-IMMUNE-THREAT-SX - PREREGISTERED*/
*Set Working Project Folder - Coding, Data Edits, and Output;
libname batanas "Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/03_code_dataedits_output";

/* [D] DATA SECTION */
*[D-1] Import self-report dataset and save to working project folder;
FILENAME REFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/02_data_import_snapshot/bata_selfreport.csv';

PROC IMPORT DATAFILE=REFILE DBMS=CSV OUT=selfreport REPLACE;
	GETNAMES=YES;
RUN;

*[D-2] Import NAS and Repro dataset and save to working project folder;
FILENAME REFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/02_data_import_snapshot/batanasrepro.csv';

PROC IMPORT DATAFILE=REFILE DBMS=CSV OUT=nasrepro REPLACE;
	GETNAMES=YES;
RUN;

*[D-3] Import Immune dataset and save to working project folder;
FILENAME REFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/02_data_import_snapshot/immune_3.8.22.csv';

PROC IMPORT DATAFILE=REFILE DBMS=CSV OUT=immune REPLACE;
	GETNAMES=YES;
RUN;

*[D-4] Import BMI dataset and save to working project folder;
FILENAME REFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/02_data_import_snapshot/BMI_pp.xlsx';

PROC IMPORT DATAFILE=REFILE DBMS=XLSX OUT=bmi REPLACE;
	GETNAMES=YES;
RUN;

proc sort data=bmi;
	by subject_id visit_fmri;
run;

*[D-5] Import Hammer dataset and save to working project folder;
FILENAME REFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/02_data_import_snapshot/Hammer_fq_cope6_07.28.2021.xlsx';

PROC IMPORT DATAFILE=REFILE DBMS=XLSX OUT=hammer21 REPLACE;
	GETNAMES=YES;
RUN;

*[D-6] Import Hammer Amygdala dataset and save to working project folder;
FILENAME REFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/02_data_import_snapshot/Hammer_amy_fq_cope8_03.09.2022.xlsx';

PROC IMPORT DATAFILE=REFILE DBMS=XLSX OUT=hammer22 REPLACE;
	GETNAMES=YES;
RUN;

*[D-7] Merge selfreport and nasrepro into temp1;

data temp1;
	merge selfreport nasrepro;
	by Subject_ID visit_mlm;
run;

proc sort data=temp1;
	by subject_id visit_fmri;
run;

*[D-8] Merge temp1, immune into temp2;

data temp2;
	merge temp1 immune;
	by Subject_ID visit_fmri;
run;

*[D-9] Merge temp1, immune, BMI into temp2;

data temp2;
	merge temp1 immune bmi;
	by Subject_ID visit_fmri;
run;

proc sort data=temp2;
	by subject_id scan;
run;

*[D-10] Merge temp2, hammer21, hammer22 into batanaspp, select only the variables we need, and PREP new variables;

data batanaspp (keep=id scan behav_wk age afab tx bmi SHAPS BAI BDI PSS 
		prog_ng_ml meno Hormonal_Status luteal p4 allo pregna p5 thdoc thdoc_3a5b 
		androsterone androstanediol etiocholanone etiocholanediol CRP IL6 TNFa 
		OralContraceptive Progestin_IUD BMI_final pcing7 pcing6 L_Amy_cp8 R_Amy_cp8 scannum luteal);
	merge temp2 hammer21 hammer22;
	by Subject_ID Scan;
/*Rename variables*/
	id=(substrn(Subject_id, length(subject_id)-3, 4))*1;
	*converts subject_id to numeric value;
	shaps=shaps_scan;
	bmi=bmi_final;
	scannum=(substrn(scan, length(scan), 1))*1;

	/*create afab variable*/
	afab=.;

	if sex="F" then
		afab=1;
	else
		afab=0;

	/*recode missing luteal to 0*/
	if luteal=999 then
		luteal=0;

	if luteal=. then
		luteal=0;

	/* Deletes cases with no id number*/
	if id=. then
		delete;
run;

*[D-11] Eliminate Duplicate Cases;

proc sort data=batanaspp out=batanaspp nodupkey;
	by id scannum;
run;

/* Removing Outliers and Making Calculations*/ 


%macro outliers (yvar=);

	data batanaspp;
		set batanaspp;
		z&yvar=&yvar; 
	run;
	
		
	*Remove outliers ;
	
	proc standard data=batanaspp out=batanaspp m=0 std=1; 
	var z&yvar; 
	run; 
	
	data batanaspp; 
	set batanaspp; 
	if z&yvar >=3 then &yvar=.;
	if z&yvar <=-3 then &yvar=.;
	run;

%mend;

%let ylist= SHAPS BAI BDI PSS p4 allo pregna p5 thdoc thdoc_3a5b 
		androsterone androstanediol etiocholanone etiocholanediol CRP IL6 TNFa 
		pcing7 pcing6 L_Amy_cp8 R_Amy_cp8;

%macro outliersrun;
	%do i=1 %to 21;
		%let yvar=%scan(&ylist, &i);
		%outliers(yvar=&yvar);
	%end;
%mend;

%outliersrun;

/*Calculate New Variables after Outliers Removed*/ 


data batanaspp (keep=id scan behav_wk age afab tx bmi SHAPS BAI BDI PSS 
		prog_ng_ml meno Hormonal_Status luteal p4 allo pregna p5 thdoc thdoc_3a5b 
		androsterone androstanediol etiocholanone etiocholanediol CRP IL6 TNFa 
		OralContraceptive Progestin_IUD BMI_final pcing7 pcing6 L_Amy_cp8 R_Amy_cp8 scannum luteal 
		allop4 pregnap4 allopregnap4 allop5 pregnap5 allopregnap5);
	set batanaspp;

	/*Create Neurosteroid Ratios - AFTER outliers removed above*/
	
	allop4=allo/p4;
	pregnap4=pregna/p4;
	allopregnap4=(allo+pregna)/p5;
	allop5=allo/p5;
	pregnap5=pregna/p5;
	allopregnap5=(allo+pregna)/p5;
	
	run;


*[D-12] Saving Person Means for repeated measures and Sample Standardizing individual diffs in means, as well as calculating state deviations;

%macro meansanddevs (yvar=);

	data batanaspp;
		set batanaspp;
		&yvar.d=&yvar;
		&yvar.zd=&yvar;
	run;
	
	
	proc standard data=batanaspp out=batanaspp m=0;
		var &yvar.d;
		by id;
	run;

	proc standard data=batanaspp out=batanaspp m=0 std=1;
		var &yvar.zd;
		by id;
	run;

	proc means data=batanaspp noprint;
		var &yvar;
		by id;
		output out=&yvar.means mean=&yvar.m;
	run;

	data &yvar.means;
		set &yvar.means;
		z&yvar.m=&yvar.m;
	run;

	proc standard data=&yvar.means out=&yvar.means m=0 std=1;
		var z&yvar.m;
	run;

	proc sort data=&yvar.means out=&yvar.means;
		by id;
	run;

	proc sort data=batanaspp out=batanaspp;
		by id scannum;
	run;

	data batanaspp;
		merge batanaspp &yvar.means;
		by id;
	run;


%mend;

%let ylist= luteal bmi SHAPS BAI BDI PSS p4 allo pregna p5 thdoc thdoc_3a5b 
		androsterone androstanediol etiocholanone etiocholanediol CRP IL6 TNFa 
		pcing7 pcing6 L_Amy_cp8 R_Amy_cp8 allop4 pregnap4 allopregnap4 allop5 pregnap5 allopregnap5;

%macro meansanddevsrun;
	%do i=1 %to 29;
		%let yvar=%scan(&ylist, &i);
		%meansanddevs(yvar=&yvar);
	%end;
%mend;

%meansanddevsrun;

*[D-14] Saving one obs per person (trait);

proc sort data=batanaspp out=batanastrait nodupkey;
	by id;
run;

*[D-15] Saving smaller dataset and creating zbmi and zage;

data batanastrait (keep=id natcyc zbmi bmim OralContraceptive Progestin_IUD age zage afab tx SHAPSm BAIm BDIm 
		PSSm p4m allom pregnam p5m thdocm thdoc_3a5bm androsteronem androstanediolm 
		etiocholanonem etiocholanediolm CRPm IL6m TNFam pcing7m pcing6m L_Amy_cp8m 
		R_Amy_cp8m allop4m pregnap4m allopregnap4m allop5m pregnap5m allopregnap5m);
	set batanastrait;
	zage=age;

	/* Note: BMI here is represented by mean BMI across the trial*/
	zbmi=bmim;

	/*Create Natural Cycling Trait Variable incidating people who have natural menstrual cycles*/
	natcyc=.;

	if lutealm>0 then
		natcyc=1;
	else
		natcyc=0;
run;

*[D-16] z-scoring BMI and age;

proc standard data=batanastrait out=batanastrait m=0 std=1;
	var zbmi zage;
run;

*[D-17] Re-merging trait zbmi and zage into person-period dataset;

data batanaspp;
	merge batanaspp batanastrait;
	by id;

	if id=. then
		delete;
run;

*[D-18] Save out Trajectory Estimates of within-person vars after covarying /eliminating cycle phase effects etc;

data estimates;
	id=.;
run;


%macro savetraj (yvar=);
	proc mixed data=batanaspp covtest;
		class id;
		model &yvar= luteal zP4m P4d behav_wk / solution;
		random intercept behav_wk/subject=id s;
		ods output solutionR=resp4timeest&yvar; 
	run;

	data intpr&yvar (keep=id intpr&yvar zintpr&yvar);
		set resp4timeest&yvar;
		intpr&yvar=.;

		if Effect="Intercept" then
			intpr&yvar=Estimate;
		else
			delete;
		zintpr&yvar=intpr&yvar;
	run;
	
	proc standard data=intpr&yvar out=intpr&yvar m=0 std=1;
	var zintpr&yvar; 
	run;

	data slopepr&yvar (keep=id slopepr&yvar zslopepr&yvar);
		set resp4timeest&yvar;
		slopepr&yvar=.;

		if Effect="behav_wk" then
			slopepr&yvar=Estimate;
		else
			delete;
			
			zslopepr&yvar=slopepr&yvar;
	run;
	
	proc standard data=slopepr&yvar out=slopepr&yvar m=0 std=1;
	var zslopepr&yvar; 
	run;

	data estimates;
		merge estimates &yvar.means intpr&yvar slopepr&yvar /*int&yvar slope&yvar*/;
		by id;
	run;
	
	/* REMOVE outlier slope estimates (outside of 3 SDs) */
	data estimates; 
	set estimates; 
		if -3>zslopepr&yvar then zslopepr&yvar=.; 
		if zslopepr&yvar>3 then zslopepr&yvar=.; 
			if -3>zslopepr&yvar then slopepr&yvar=.; 
		if zslopepr&yvar>3 then slopepr&yvar=.; 
		run;

%mend;

%let ylist= SHAPS BAI BDI PSS allo pregna p5 thdoc thdoc_3a5b 
		androsterone androstanediol etiocholanone etiocholanediol CRP IL6 TNFa 
		pcing7 pcing6 L_Amy_cp8 R_Amy_cp8 allop4 pregnap4 allopregnap4 allop5 pregnap5 allopregnap5;

%macro savetrajrun;
	%do i=1 %to 26;
		%let yvar=%scan(&ylist, &i);
		%savetraj(yvar=&yvar);
	%end;
%mend;

%savetrajrun;

/* Merge estimates into trait dataset */
data batanastrait;
	merge batanastrait estimates;
	by id;
	if id=. then
		delete;
run;


/************************************************************/
/*END DATA PREP*/
/************************************************************/

*[A-1] - Print Between-Person Trait Dataset;

proc print data=batanastrait;
run;

*[A-2] - Output Frequencies for categorical traits;

proc freq data=batanastrait;
	table id afab natcyc tx natcyc*tx;
run;

*[A-3] - Output Means for continuous traits;

proc means data=batanastrait;
	var zbmi bmim age zage SHAPSm BAIm BDIm PSSm p4m allom pregnam p5m thdocm 
		thdoc_3a5bm androsteronem androstanediolm etiocholanonem etiocholanediolm 
		CRPm IL6m TNFam pcing7m pcing6m L_Amy_cp8m R_Amy_cp8m p4allom p4pregnam 
		p4allopregnam p5allom p5pregnam p5allopregnam allop4m pregnap4m allopregnap4m 
		allop5m pregnap5m allopregnap5m;
run;

*[A-3.5] - Output Means for Estimates;

proc means data=estimates;
	var intprshaps slopeprshaps intprbai slopeprbai intprbdi slopeprbdi intprpss 
		slopeprpss intprallo slopeprallo intprpregna slopeprpregna intprp5 slopeprp5 
		intprthdoc slopeprthdoc intprthdoc_3a5b slopeprthdoc_3a5b intprandrosterone 
		slopeprandrosterone intprandrostanediol slopeprandrostanediol 
		intpretiocholanone slopepretiocholanone intpretiocholanediol 
		slopepretiocholanediol intprcrp slopeprcrp intpril6 slopepril6 intprtnfa 
		slopeprtnfa intprpcing7 slopeprpcing7 intprpcing6 slopeprpcing6 
		intprL_Amy_cp8 slopeprL_Amy_cp8 intprR_Amy_cp8 slopeprR_Amy_cp8 intprallop4 
		slopeprallop4 intprpregnap4 slopeprpregnap4 intprallopregnap4 
		slopeprallopregnap4 intprallop5 slopeprallop5 intprpregnap5 slopeprpregnap5 
		intprallopregnap5 slopeprallopregnap5;
run;

*[A-4] - Output Histograms for continuous traits;

proc univariate data=batanastrait;
	var zbmi bmim age zage SHAPSm BAIm BDIm PSSm p4m allom pregnam p5m thdocm 
		thdoc_3a5bm androsteronem androstanediolm etiocholanonem etiocholanediolm 
		CRPm IL6m TNFam pcing7m pcing6m L_Amy_cp8m R_Amy_cp8m allop4m pregnap4m 
		allopregnap4m allop5m pregnap5m allopregnap5m intprshaps slopeprshaps 
		intprbai slopeprbai intprbdi slopeprbdi intprpss slopeprpss intprallo 
		slopeprallo intprpregna slopeprpregna intprp5 slopeprp5 intprthdoc 
		slopeprthdoc intprthdoc_3a5b slopeprthdoc_3a5b intprandrosterone 
		slopeprandrosterone intprandrostanediol slopeprandrostanediol 
		intpretiocholanone slopepretiocholanone intpretiocholanediol 
		slopepretiocholanediol intprcrp slopeprcrp intpril6 slopepril6 intprtnfa 
		slopeprtnfa intprpcing7 slopeprpcing7 intprpcing6 slopeprpcing6 
		intprL_Amy_cp8 slopeprL_Amy_cp8 intprR_Amy_cp8 slopeprR_Amy_cp8 /*intprallop4
		slopeprallop4*/
		intprpregnap4 slopeprpregnap4 intprallopregnap4 slopeprallopregnap4 
		intprallop5 slopeprallop5 intprpregnap5 slopeprpregnap5 intprallopregnap5 
		slopeprallopregnap5;
	histogram zbmi bmim age zage SHAPSm BAIm BDIm PSSm p4m allom pregnam p5m 
		thdocm thdoc_3a5bm androsteronem androstanediolm etiocholanonem 
		etiocholanediolm CRPm IL6m TNFam pcing7m pcing6m L_Amy_cp8m R_Amy_cp8m 
		allop4m pregnap4m allopregnap4m allop5m pregnap5m allopregnap5m intprshaps 
		slopeprshaps intprbai slopeprbai intprbdi slopeprbdi intprpss slopeprpss 
		intprallo slopeprallo intprpregna slopeprpregna intprp5 slopeprp5 intprthdoc 
		slopeprthdoc intprthdoc_3a5b slopeprthdoc_3a5b intprandrosterone 
		slopeprandrosterone intprandrostanediol slopeprandrostanediol 
		intpretiocholanone slopepretiocholanone intpretiocholanediol 
		slopepretiocholanediol intprcrp slopeprcrp intpril6 slopepril6 intprtnfa 
		slopeprtnfa intprpcing7 slopeprpcing7 intprpcing6 slopeprpcing6 
		intprL_Amy_cp8 slopeprL_Amy_cp8 intprR_Amy_cp8 slopeprR_Amy_cp8 
		/*intprallop4
		slopeprallop4*/
		intprpregnap4 slopeprpregnap4 intprallopregnap4 slopeprallopregnap4 
		intprallop5 slopeprallop5 intprpregnap5 slopeprpregnap5 intprallopregnap5 
		slopeprallopregnap5;
	ods select histogram;
run;

*[A-5] - Correlations Among Continuous Traits;

proc corr data=batanastrait spearman best=15;
	var afab natcyc age bmim SHAPSm BAIm BDIm PSSm p4m allom pregnam p5m thdocm thdoc_3a5bm 
		androsteronem androstanediolm etiocholanonem etiocholanediolm CRPm IL6m TNFam 
		pcing7m pcing6m L_Amy_cp8m R_Amy_cp8m allop4m pregnap4m allopregnap4m allop5m pregnap5m 
		allopregnap5m intprshaps slopeprshaps intprbai slopeprbai intprbdi slopeprbdi 
		intprpss slopeprpss intprallo slopeprallo intprpregna slopeprpregna intprp5 
		slopeprp5 intprthdoc slopeprthdoc intprthdoc_3a5b slopeprthdoc_3a5b 
		intprandrosterone slopeprandrosterone intprandrostanediol 
		slopeprandrostanediol intpretiocholanone slopepretiocholanone 
		intpretiocholanediol slopepretiocholanediol intprcrp slopeprcrp intpril6 
		slopepril6 intprtnfa slopeprtnfa intprpcing7 slopeprpcing7 intprpcing6 
		slopeprpcing6 intprL_Amy_cp8 slopeprL_Amy_cp8 intprR_Amy_cp8 slopeprR_Amy_cp8 
		/*intprallop4*/ slopeprallop4 intprpregnap4 slopeprpregnap4 intprallopregnap4 
		slopeprallopregnap4 intprallop5 slopeprallop5 intprpregnap5 slopeprpregnap5 
		intprallopregnap5 slopeprallopregnap5;
run;

proc corr data=batanastrait spearman best=10;
	partial afab natcyc age bmim;
	var p4m allom pregnam p5m thdocm thdoc_3a5bm androsteronem androstanediolm 
		etiocholanonem etiocholanediolm allop4m pregnap4m allopregnap4m allop5m pregnap5m 
		allopregnap5m;
	with SHAPSm BAIm BDIm PSSm CRPm IL6m TNFam pcing7m pcing6m L_Amy_cp8m 
		R_Amy_cp8m;
run;


*[A-6] - Within-Person Descriptives;

proc freq data=batanaspp;
	table luteal scannum luteal*scannum;
run;

*[A-7] - Within-Person Plots of repeated measures over Time;
ods graphics on / width=8in;
ods graphics on / height=6in;

%macro plotovertime (yvar=);
	proc mixed data=batanaspp covtest;
		class id afab (ref=first) natcyc (ref=first) luteal (ref=first);
		model &yvar=behav_wk / solution ddfm=kenwardroger2;
		random intercept scannum/subject=id type=vc;
		ods select Nobs ConvergenceStatus covparms solutionf;
		title "Does &yvar change over time?";
	run;

	proc sgplot data=batanaspp;
		xaxis integer;
		series x=behav_wk y=&yvar/ group=id markers;
	run;

	proc sgpanel data=batanaspp;
		panelby afab;
		colaxis integer;
		series x=behav_wk y=&yvar/ group=id markers;
	run;

	proc sgpanel data=batanaspp;
		panelby natcyc;
		colaxis integer;
		series x=behav_wk y=&yvar/ group=id markers;
	run;

	proc sgpanel data=batanaspp;
		panelby natcyc;
		colaxis integer;
		series x=behav_wk y=&yvar/ group=id markers;
		where luteal ne 1;
		title "Removing Luteal Observations";
	run;


%mend;

%let ylist= bmi SHAPS BAI BDI PSS p4 allo pregna p5 thdoc thdoc_3a5b 
		androsterone androstanediol etiocholanone etiocholanediol CRP IL6 TNFa 
		pcing7 pcing6 L_Amy_cp8 R_Amy_cp8 allop4 pregnap4 allopregnap4 allop5 pregnap5 allopregnap5;

%macro plotovertimerun;
	%do i=1 %to 28;
		%let yvar=%scan(&ylist, &i);
		%plotovertime(yvar=&yvar);
	%end;
%mend;

%plotovertimerun;

*[H-1] - HYPOTHESIS 1 TESTS - Models Examining Between- and Within-Person Associations of NAS with other repeated measures;

/**/
/*FROM PREREG: (1) To evaluate the relative contributions of trait- and state-level variance
in neuroactive steroids in predicting inflammatory markers, neural indices of
threat activation, and symptoms, a series of multilevel models (with
observations nested within participants) will evaluate the relative
contributions of between-person (person mean across all observations) and
within-person (deviations of the current observation from the person mean)
variability in neurosteroids on each outcome. We predict that higher levels of
neurosteroids (and neurosteroid ratios) will be associated with positive
outcomes at both the between and within-person levels.*/
/*Printing Scan Days Dataset to see  Missing Values*/

proc print data=batanaspp;
	var id scannum zbmi bmim afab natcyc zage luteal shaps allo pregna p5 thdoc 
		thdoc_3a5b androsterone androstanediol etiocholanone etiocholanediol allop4 
		pregnap4 allopregnap4 allop5 pregnap5 allopregnap5 SHAPS BAI BDI PSS CRP IL6 
		TNFa pcing7 pcing6 L_Amy_cp8 R_Amy_cp8;
	where scannum ne .;
run;


%macro covar(xvar=, yvar=);
proc mixed data=batanaspp covtest;
class id;
model &yvar=/ solution ddfm=kenwardroger2;
random intercept /subject=id type=vc;
ods select covparms;
title "&yvar NULL MODEL";
run;

proc mixed data=batanaspp covtest;
class id;
model &yvar=behav_wk/ solution ddfm=kenwardroger2;
random intercept behav_wk/subject=id type=vc;
ods select covparms solutionf;
title "&yvar UNCOND GROWTH MODEL";
run;

proc mixed data=batanaspp covtest;
class id afab (ref=first) natcyc (ref=first) luteal (ref=first);
model &yvar=behav_wk zbmi afab natcyc zage luteal z&xvar.m &xvar.d/ solution
ddfm=kenwardroger2;
random intercept &xvar.d/subject=id type=vc;
ods select Nobs fitstatistics ConvergenceStatus covparms solutionf;
title "Predicting &yvar from Between and Within-Person Variance in &xvar";
run;

proc mixed data=batanaspp covtest;
class id afab (ref=first) natcyc (ref=first) luteal (ref=first);
model &yvar=behav_wk zbmi afab natcyc zage luteal z&xvar.m &xvar.d/ solution
ddfm=kenwardroger2;
random intercept /subject=id type=vc;
ods select Nobs fitstatistics ConvergenceStatus covparms solutionf;
title "no random slope - Predicting &yvar from Between and Within-Person Variance in &xvar";
run;

%mend;

%let xlist= allo pregna p5 thdoc thdoc_3a5b
androsterone androstanediol etiocholanone etiocholanediol allop4 pregnap4 allopregnap4 allop5 pregnap5 allopregnap5;
%let ylist= SHAPS BAI BDI PSS CRP IL6 TNFa
pcing7 pcing6 L_Amy_cp8 R_Amy_cp8;

%macro covarrun;
%do j=1 %to 15 /*15*/;
%do i=1 %to 11 /*11*/;
%let yvar=%scan(&ylist, &i);
%let xvar=%scan(&xlist, &j);
%covar(yvar=&yvar, xvar=&xvar);
%end;
%end;
%mend;
%covarrun;

*[H-1-v] - VISUALIZATION OF HYPOTHESIS 1 TESTS - between-person graphs;


*[H-2] - HYPOTHESIS 2 TESTS - INSERT DESCRIPTION HERE;

/*(Hypothesis 2) To evaluate how differences in neurosteroid change from pre- to
post-treatment (specified as a L2 trait-like variable, calculated as post
minus pre) MODERATE the trajectory of other outcomes across the
trial (neurosteroid change score * time), we will utilize multilevel growth
models. We expect that those with greater increases (or lesser decreases) in
neurosteroid levels and ratios from pre- to post- treatment will show a
greater decline in inflammatory markers, neural threat indices, and
psychiatric symptoms across treatment. */
/*Since reproductive status (particularly pregnancy and luteal phase of the
menstrual cycle) are known to exponentially increase progesterone levels, and
since progesterone is the precursor to several GABAergic neuroactive steroids
of interest in the present study, we did pre-evaluate the impact of
reproductive status on progesterone in order to derive a meaningful covariate
for use in analyses. We first created a categorical "reproductive status"
variable including the following options: male sex, combined oral
contraceptive-using female, LNG-IUD-using female, post-menopausal female,
naturally cycling female in the follicular phase of the menstrual cycle, and
naturally cycling female in the luteal phase of the menstrual cycle. Next, we
ran ANOVA models to examine which categories differed significantly from one
another. Results yielded a very clear picture in which Naturally-Cycling
Luteal Phase Females had significantly higher levels of progesterone than all
other categories, and no other pairwise differences emerged. Visual inspection
of data suggested that either (1) binary classification at the observation
level for luteal phase status (vs. all other reproductive statuses) or (2)
covarying levels of progesterone at each visit, represent equally reasonable
approaches to removing variance associated with the menstrual cycle in our
primary models. Therefore, depending on appropriateness for our outcome of
interest, we will engage one of these two strategies. */


proc print data=batanastrait; 
var afab natcyc bmim zage;
run;


	


	
	proc mixed data=batanaspp covtest;
		class id afab (ref=first) natcyc (ref=first) luteal (ref=first);
		model SHAPS=behav_wk zbmi afab natcyc zage luteal zp5m zP4m zallom zpregnam zthdocm zthdoc_3a5bm zetiocholanonem zetiocholanediolm zandrosteronem zandrostanediolm/ solution;
		random intercept behav_wk/subject=id type=vc;
		ods select covparms solutionf;
		title "BDI - with random slopes";
	run;
	
	
proc sgplot data=batanaspp;  
reg x=behav_wk y=bdi/group=etioinc degree=2; 
run; 
	

proc sgplot data=batanaspp;  
reg x=zthdocm y=shapsm/group=afab; 
run; 


/* Does sex influence change over time in any variable? --> Only THCOC3a5b, greater inc in M */ 

proc ttest data=batanastrait; 
class afab;
var slopeprshaps slopeprbdi slopeprpss slopeprallo slopeprpregna slopeprp5 slopeprthdoc slopeprthdoc_3a5b 
		slopeprandrosterone slopeprandrostanediol slopepretiocholanone 
	 slopepretiocholanediol slopeprcrp 
		slopepril6 slopeprtnfa slopeprpcing7 
		slopeprpcing6 slopeprL_Amy_cp8 slopeprR_Amy_cp8

		/*intprallop4 slopeprallop4*/
		 slopeprpregnap4  slopeprallopregnap4 
		 slopeprallop5  slopeprpregnap5  
		slopeprallopregnap5; 
run; 

/* Does naturally cycling status influence change over time in any variable? -->  */ 

proc ttest data=batanastrait; 
class natcyc;
var slopeprshaps slopeprbdi slopeprpss slopeprallo slopeprpregna slopeprp5 slopeprthdoc slopeprthdoc_3a5b 
		slopeprandrosterone slopeprandrostanediol slopepretiocholanone 
	 slopepretiocholanediol slopeprcrp 
		slopepril6 slopeprtnfa slopeprpcing7 
		slopeprpcing6 slopeprL_Amy_cp8 slopeprR_Amy_cp8

		/*intprallop4 slopeprallop4*/
		 slopeprpregnap4  slopeprallopregnap4 
		 slopeprallop5  slopeprpregnap5  
		slopeprallopregnap5; 
run; 




/*Growth model macro predicting degree of change over time from slope of other variables*/ 

%macro growth (xvar=, yvar=);

data batanaspp; 
merge batanaspp batanastrait; 
by id; 
run;

proc corr data=batanastrait spearman ;
	partial afab natcyc zbmi zage;
	var &xvar.m intpr&xvar slopepr&xvar;
	with &yvar.m intpr&yvar slopepr&yvar;
	where z&xvar.m<3 and z&yvar.m<3;
run;


	proc mixed data=batanaspp covtest;
		class id afab (ref=first) natcyc (ref=first) luteal (ref=first);
		model &yvar=behav_wk zbmi afab natcyc zage luteal zintpr&xvar /*zintpr&xvar*behav_wk*/ zslopepr&xvar zslopepr&xvar*behav_wk/ solution;
		random intercept behav_wk/subject=id type=vc;
		ods select covparms solutionf;
		title "SLOPE of &xvar * TIME = &yvar";
			where -3<zslopepr&xvar<3 and -3<zslopepr&yvar<3;
	run;
	
	proc sgplot data=batanaspp;
		vline scannum /response=&yvar.zd stat=mean limitstat=stderr;
		vline scannum /response=&xvar.zd stat=mean limitstat=stderr;
				title "Changes in Person-Standardized &xvar and &yvar Over Time";
	run;


%mend;

%let xlist= allo pregna p5 thdoc thdoc_3a5b 
		androsterone androstanediol etiocholanone etiocholanediol allop4 
		pregnap4 allopregnap4 allop5 pregnap5 allopregnap5;
%let ylist= SHAPS BAI BDI PSS CRP IL6 TNFa 
		pcing7 pcing6 L_Amy_cp8 R_Amy_cp8;

%macro growthrun;
	%do j=1 %to 15 /*15*/;

		%do i=1 %to 11 /*13*/;
			%let yvar=%scan(&ylist, &i);
			%let xvar=%scan(&xlist, &j);
			%growth(yvar=&yvar, xvar=&xvar);
		%end;
	%end;
%mend;

%growthrun;


/* Creating Plots for Significant Associations*/ 

/*ALLO*/ 

/*allo-shaps - NOT SIG

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprshaps= zslopeprallo ; 
where natcyc=0 and id not in (1017);
run; */

/*PREGNA*/ 

proc print data=batanastrait; 
var id zslopeprpregna zslopeprshaps; 
run;

*pregna-shaps - r2=.06, robust to sex and natcyc;

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprshaps= zslopeprpregna  ; 
where id not in (741,982,1582,1630); 
run; 

*pregna-il6 - r2=.05, males r2=.36, females r2=.04; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopepril6= zslopeprpregna  ; 
where id not in (389,456,569,982,1582,1630); 
run; 


*pregna-Ramyc8 - r2=.19, robust to sex and natcyc; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprR_Amy_cp8= zslopeprpregna  ; 
where id not in (456,741,949,982,1346,1504,1582,1630); 
run; 


*pregna-Lamyc8 - r2=.06, stronger in males, robust to natcyc; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprL_Amy_cp8= zslopeprpregna  ; 
where id not in (647,741,949,982,1582,1630); 
run; 


*pregna-CRP - NOT SIG - had been marginal in dev covary H1 models; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprCRP= zslopeprpregna  ; 
where id not in (75,104,247,569,720,741,847,982,949,1346,1582,1630); 
run; 

/*PREGNENOLONE*/ 

*p5-BDI - not robust to eliminating worst leverage values; in males, nonparadoxical rel; in females, paradoxical ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprBDI= slopeprp5  ; 
where id not in (459,104,741,244,847,1346,1465,1504,982); 
run; 

*p5-CRP - not sig ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprCRP= slopeprp5  ; 
where id not in (847,1603,459,1465); 
run; 

*p5-amygL - not sig ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage); 
id id; 
model slopeprL_Amy_cp8= slopeprp5  ; 
where id not in (847,741); 
run; 

*p5-amygR - robust to eliminating high leverage values; ONLY sig in females ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprR_Amy_cp8= slopeprp5  ; 
where id not in (329,741,459,847,1346,1465,1504,1603); 
run; 


/*THDOC-3a5b*/ 

*thdoc3a5b-shaps - not sig; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprSHAPS= slopeprthdoc_3a5b  ; 
where id not in (812,1460,945,392,1783); 
run; 


*thdoc3a5b-bdi - not sig; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprBDI= slopeprthdoc_3a5b  ; 
where id not in (392,1783,945,1460,812,1346,623,1702,387); 
run; 

/*ANDROSTERONE*/ 

*andro-bdi - not sig; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprBDI= slopeprandrosterone  ; 
where id not in (456,1680,1582); 
run; 


*andro-pcing6 - not sig; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprpcing6= slopeprandrosterone  ; 
where id not in (170,456,247,403,1582,1680,549); 
run;

*andro-amyL - not sig; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprL_Amy_cp8= slopeprandrosterone  ; 
where id not in (949,877,1680); 
run; 

*andro-amyR - sig after removing leverage values, r2=.14; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprR_Amy_cp8= slopeprandrosterone  ; 
where id not in (877,247,456,1680,403,1504); 
run; 

/*ANDROSTANEDIOL*/ 

*androstanediol-BDI - very small, marginally sig, not sig within either sex ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprbdi= slopeprandrostanediol  ; 
where id not in (199, 104,329,1346,1582,403); 
run;


*androstanediol-SHAPS - not sig ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprshaps= slopeprandrostanediol  ; 
where id not in (1633,403) ; 
run;


*androstanediol-amyR - not sig ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprR_Amy_cp8= slopeprandrostanediol  ; 
where id not in (1346,1504,329) ; 
run;


*androstanediol-amyL - r2=.07, NS in females; males r2=.32; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprL_Amy_cp8= slopeprandrostanediol  ; 
where id not in (329,403) ; 
run;


/*ETIOCHOLANOLONE*/ 

*etiocholanolone-BDI - very small, marginally sig, not sig within either sex ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprbdi= slopepretiocholanone  ; 
where id not in (456,549,741,847,1347,1706) ; 
run;

*etiocholanolone-SHAPS - r2=.11 , males r2=.30 ; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprshaps= slopepretiocholanone  ; 
where id not in (456,741,847) ; 
run;

*etiocholanolone-PSS - small, marginal; males r2=.19; NS in females; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprpss= slopepretiocholanone  ; 
where id not in (233,456,847,1347,549); 
run;


/*ETIOCHOLANEDIOL*/ 

*etiocholanediol-BDI - NOT SIG in either sex; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprbdi= slopepretiocholanediol  ; 
where id not in (549,244,741,329,1680,1346,389,105,1124,1582,23) ; 
run;


*etiocholanediol-SHAPS - NOT SIG in either sex; might be there in males; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprshaps= slopepretiocholanediol  ; 
where id not in (877,1504,1783,389,741,244,329,1680,549,105,647,1124,141,23); 
run;



*etiocholanediol-CRP - NOT SIG in either sex; also might be there in males; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprCRP= slopepretiocholanediol  ; 
where id not in (549,741,1680,244,329,389,105,1504,1633) and afab=1; 
run;


*etiocholanediol-IL6 - NOT SIG in either sex; another that might be there in males; 

proc reg data=batanastrait plots(label) = (fitplot rstudentbyleverage cooksd); 
id id; 
model slopeprIL6= slopepretiocholanediol  ; 
where id not in (329,389,244,741,1680,549,105,23,1465,1124,855) and afab=1; 
run;









/* How do they covary*/

%macro covar(xvar=, yvar=);
	/*options nosource nonotes;
	ods html5 style=htmlblue
	path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - trait state assoc of &xvar with &yvar - traj trait zm zd ol rem - cov age bmi OC sex .html";
	*/
	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive z&xvar.m &xvar.d/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from Between and Within-Person Variance in &xvar";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx behav_wk z&xvar.m &xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for time and treatment";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk z&xvar.m &xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for the interaction TREATMENT x BEHAV_WK";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk z&xvar.m &xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept &xvar.d/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for the interaction TREATMENT x BEHAV_WK (RANDOM EFFECT of &xvar.d)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx TORYTIME z&xvar.m &xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for TORYTIME and treatment";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME z&xvar.m &xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for the interaction of TORYTIME and treatment ";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME z&xvar.m &xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept &xvar.d/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for the interaction of TORYTIME and treatment (RANDOM EFFECT of &xvar.d)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc sgplot data=bata_p_olrem;
		reg x=z&xvar.m y=&yvar.m;
		title "BETWEEN-PERSON: Predicting &yvar person-mean from &xvar person-mean";
		where  (-3 < z&yvar.m < 3) AND (-3 < z&xvar.m < 3);
	run;

	proc sgplot data=bata_p_pp_olrem;
		reg x=&xvar.d y=&yvar.d / group=subject_id;
		reg x=&xvar.d y=&yvar.d /lineattrs=(color=black thickness=4);
		title "WITHIN-PERSON: Predicting &yvar from &xvar (dev from person-mean)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3);
	run;

%mend;

%let xlist=  pcing7 pcing6 lgil6 lgtnfa lgcrp pcing6 pcing7 lamy ramy pcing il6 tnfa crp shaps_behav shaps_scan bdi bai lgbai pss pswq decentering curiosity pcl5 L_nacc_3 
L_nacc_6 L_caud_3 L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 
cuerew_c12 PwSN PwFPN PwDMN PwRew ;
%let ylist= lgil6 shaps_behav shaps_scan bdi pss bai lgbai   lgtnfa lgcrp  lamy ramy pcing pcing6 pcing7 il6 tnfa crp  pswq decentering curiosity pcl5 L_nacc_3 L_nacc_6 L_caud_3 L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 
R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 cuerew_c12 PwSN PwFPN PwDMN PwRew   ;

%macro covarrun;
	%do j=1 %to 1 /*xlist - 41*/;

		%do i=1 %to 1 /*ylist - 41*/;
			%let yvar=%scan(&ylist, &i);
			%let xvar=%scan(&xlist, &j);
			%covar(yvar=&yvar, xvar=&xvar);
		%end;
	%end;
%mend;

%covarrun;
*Preregistration Text;

/*(1) To evaluate the relative contributions of trait- and state-level variance
in neuroactive steroids in predicting inflammatory markers, neural indices of
threat activation, and symptoms, a series of multilevel models (with
observations nested within participants) will evaluate the relative
contributions of between-person (person mean across all observations) and
within-person (deviations of the current observation from the person mean)
variability in neurosteroids on each outcome. We predict that higher levels of
neurosteroids (and neurosteroid ratios) will be associated with positive
outcomes at both the between and within-person levels.

(2) To evaluate how differences in neurosteroid change from pre- to
post-treatment (specified as a L2 trait-like variable, calculated as post
minus pre) MODERATE the trajectory of other outcomes across the
trial (neurosteroid change score * time), we will utilize multilevel growth
models. We expect that those with greater increases (or lesser decreases) in
neurosteroid levels and ratios from pre- to post- treatment will show a
greater decline in inflammatory markers, neural threat indices, and
psychiatric symptoms across treatment. */
/*Since reproductive status (particularly pregnancy and luteal phase of the
menstrual cycle) are known to exponentially increase progesterone levels, and
since progesterone is the precursor to several GABAergic neuroactive steroids
of interest in the present study, we did pre-evaluate the impact of
reproductive status on progesterone in order to derive a meaningful covariate
for use in analyses. We first created a categorical "reproductive status"
variable including the following options: male sex, combined oral
contraceptive-using female, LNG-IUD-using female, post-menopausal female,
naturally cycling female in the follicular phase of the menstrual cycle, and
naturally cycling female in the luteal phase of the menstrual cycle. Next, we
ran ANOVA models to examine which categories differed significantly from one
another. Results yielded a very clear picture in which Naturally-Cycling
Luteal Phase Females had significantly higher levels of progesterone than all
other categories, and no other pairwise differences emerged. Visual inspection
of data suggested that either (1) binary classification at the observation
level for luteal phase status (vs. all other reproductive statuses) or (2)
covarying levels of progesterone at each visit, represent equally reasonable
approaches to removing variance associated with the menstrual cycle in our
primary models. Therefore, depending on appropriateness for our outcome of
interest, we will engage one of these two strategies. */
/*Primary analytic variables are starred;
others will be used in exploratory and sensitivity analyses.

- Snaith-Hamilton Pleasure Scale (SHAPS)* - Beck Depression Inventory (BDI)*
- Perceived Stress Scale (PSS) - Beck Anxiety Inventory (BAI) INFLAMMATORY
MARKERS (high-sensitivity ELISA) - Interleukin-6 (IL-6) (pg/ml)* - Tumor
Necrosis Factor-Alpha (TNFa) (pg/ml)* - C-Reactive Protein (CRP) (mg/l)*
NEUROACTIVE STEROIDS (GC-MS) - Pregnenolone (P5)* - 3a,
5a-THP (Allopregnanolone)* - 3a, 5b-THP (Pregnanolone)* - 3a, 5a-THDOC
- 3a, 5b-THDOC
- 3a, 5a-A
- 3a, 5a-A-Diol
- 3a, 5b-A
- 3a, 5b-A-Diol

- Progesterone (P4) - covariate* NEUROIMAGING INDICES Primary contrasts of
interest using the Hariri "Hammer" task:

- All Faces (> Control) Blocks* - Negative Faces (Angry + Fearful
Block > Control) Blocks Our outcome variables are contrast-specific BOLD
percent-signal change value.

Both small-volume correction (SVC) and whole-brain approaches were used for
neuroimaging analyses. Our primary region-of-interest for SVC analyses was the
amygdala (left and right hemispheres), as defined by the AAL atlas. The
permutation analysis of linear models (PALM)
toolbox (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/PALM/) was used to generate
SVC and whole-brain task-based functional activation maps. For our application
of PALM, data were permuted 5000 times and significant effects were identified
through threshold-free cluster enhancement method (TFCE), controlling for
family-wise error (FWE) rate of P < 0.05. For each contrast, we examined
task-related brain activation at baseline (group-level one-sample t-test), as
well as the change in activation from pre- to post-treatment (2x2 Mixed Effect
ANOVA examining the effect of Time and interaction of Group*Time). For
activation maps that yielded significant clusters, BOLD percent-signal change
values were calculated and extracted for each participant and time-point.

COVARIATES

- Body Mass Index (BMI)* - Biological Sex* - Age* - Reproductive Status (Luteal
Phase Naturally-Cycling Female vs. Other)* - Current progesterone level (as
appropriate vs. reproductive status) - RCT condition (BATA vs. MBCT)
- Medications No files selected Indices In addition to evaluating associations
of individual pregnane neuroactive steroids with other variables, we will
calculate ratios of P4 to downstream metabolites:

- P4: ALLO* - P4: Pregnanolone* - P4: Pregnanolone+ALLO* - Pregnenolone: ALLO*
- Pregnenolone: Pregnanolone* - Pregnenolone: Pregnanolone+ALLO* No files
selected Analysis Plan Statistical models Analyses will be conducted for two
separate purposes in two different ways. */
/*First, a smaller set of variables will be evaluated for the purposes of testing
specific hypotheses (see asterisks for denoted "Primary" variables above). In
addition to frequentist multilevel models, bayesian multilevel models will
also be utilized to generate credible intervals for estimates.

Second, exploratory analyses will examine the remaining variables for the
purposes of generating new hypotheses and guiding model development. */
/*Sensitivity analyses will examine models with and without
univariate outliers (>=3 SD away from the mean), as well as with and without
any cases suspected to be multivariate outliers following multilevel
regression diagnostics. */
*DESCRIPTIVES;

/*Run Frequencies for Categorical Variables*/
ods html5 style=htmlblue 
	path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - Frequencies of Categorical Variables.html";

proc freq data=bata_p;
	table sex diagnosis tx therapist completer allergy_asthma oralcontraceptive 
		progestin_iud;
	title "Descriptives for Categorical Variables";
run;

/*Run Correlations Among Continuous Trait and Baseline Variables*/
ods html5 style=htmlblue 
	path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - traj OL rem & trait OL rem- Descriptives and Correlations Among Baseline and Trait Variables.html";

proc corr data=bata_p_olrem;
	var shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL 
		decentering_BL curiosity_BL pcl5_BL petdiff il6_BL lgil6_BL tnfa_BL lgtnfa_BL 
		crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL L_nacc_3_BL 
		L_nacc_6_BL L_caud_3_BL L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL 
		R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL 
		cuerew_c10_BL cuerew_c11_BL cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL 
		age total_scans pt_hw_tot clin_hw_tot oralcontraceptive progestin_iud 
		weight_lb bmi emoabuse emoneg physneg physabuse sexabuse ctqtot_mean;
	title "Pearson Correlations - traj outliers removed in data step";
run;

proc corr data=bata_p_olrem spearman;
	var shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL 
		decentering_BL curiosity_BL pcl5_BL petdiff il6_BL lgil6_BL tnfa_BL lgtnfa_BL 
		crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL L_nacc_3_BL 
		L_nacc_6_BL L_caud_3_BL L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL 
		R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL 
		cuerew_c10_BL cuerew_c11_BL cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL 
		age total_scans pt_hw_tot clin_hw_tot oralcontraceptive progestin_iud 
		weight_lb bmi emoabuse emoneg physneg physabuse sexabuse ctqtot_mean;
	title "Spearman Rank Correlations - traj outliers removed in data step";
run;

/*2021-07-29 - Runs specific to pcing6 and 7 */
proc corr data=bata_p_olrem;
	var pcing6_BL pcing7_BL;
	with shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL 
		decentering_BL curiosity_BL pcl5_BL petdiff il6_BL lgil6_BL tnfa_BL lgtnfa_BL 
		crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL 
		L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL 
		R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL 
		cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL age total_scans pt_hw_tot 
		clin_hw_tot oralcontraceptive progestin_iud weight_lb bmi emoabuse emoneg 
		physneg physabuse sexabuse ctqtot_mean;
	title "2021-07-29 - PCING6 and 7 - Pearson Correlations - traj outliers removed in data step";
run;

proc corr data=bata_p_olrem spearman;
	var pcing6_BL pcing7_BL;
	with shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL 
		decentering_BL curiosity_BL pcl5_BL petdiff il6_BL lgil6_BL tnfa_BL lgtnfa_BL 
		crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL 
		L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL 
		R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL 
		cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL age total_scans pt_hw_tot 
		clin_hw_tot oralcontraceptive progestin_iud weight_lb bmi emoabuse emoneg 
		physneg physabuse sexabuse ctqtot_mean;
	title "2021-07-29 - PCING6 and 7 - Spearman Rank Correlations - traj outliers removed in data step";
run;

/* Correlation Macro for all baseline Variables */
%macro correl (yvar=);
	/*Run Correlations Among Continuous Trait and Baseline Variables*/
	ods html5 style=htmlblue 
		path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - traj OL rem and trait OL3sd rem- Top 15 Corr of &yvar with BL and Trait Vars.html";

	proc corr data=bata_p_olrem best=15;
		var shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL 
			decentering_BL curiosity_BL pcl5_BL petdiff il6_BL lgil6_BL tnfa_BL 
			lgtnfa_BL crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL 
			L_nacc_3_BL L_nacc_6_BL L_caud_3_BL L_caud_6_BL L_put_3_BL L_put_6_BL 
			R_nacc_3_BL R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL 
			cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL cuerew_c12_BL PwSN_BL PwFPN_BL 
			PwDMN_BL PwRew_BL age pt_hw_tot clin_hw_tot oralcontraceptive progestin_iud 
			weight_lb bmi emoabuse emoneg physneg physabuse sexabuse ctqtot_mean;
		with &yvar;
		ods select PearsonCorr;
		title "Top 15 Largest Pearson Correlations with &yvar - outside 3SD EXCLUDED";
	run;

	/*
	proc corr data=bata_p best=15;
	var shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL
	decentering_BL curiosity_BL pcl5_BL petdiff il6_BL lgil6_BL tnfa_BL lgtnfa_BL
	crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL
	L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL
	R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL
	cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL age
	pt_hw_tot clin_hw_tot oralcontraceptive progestin_iud weight_lb
	emoabuse emoneg physneg physabuse sexabuse ctqtot_mean;
	with &yvar ;
	ods select PearsonCorr;
	title "FOR COMPARISON: same analysis with outside 3SD INCLUDED";
	run;
	*/

%mend;

%let ylist= shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL decentering_BL curiosity_BL pcl5_BL petdiff 
lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL 
L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL 
cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL;

%macro correlrun;
	%do i=1 %to 36;
		%let yvar=%scan(&ylist, &i);
		%correl(yvar=&yvar);
	%end;
%mend;

%correlrun;

/* Models predicting Baseline Symptoms from immune vars */
%macro immunebaseline (yvar=);
	ods html5 style=htmlblue 
		path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - traj OL and trait 3sd OL rem - Predicting Baseline &yvar from age, sex, hormones, and Immune Vars.html";

	proc glm data=bata_p;
		class sex oralcontraceptive (ref=first) progestin_iud (ref=first);
		model &yvar=zage sex zbmi zlgcrp_BL/ solution;
		ods select fitstatistics ParameterEstimates;
		title "Predicting Baseline &yvar from age, sex, weight, and CRP";
		where  (-3 < z&yvar < 3) and (-3 < zlgcrp_BL < 3);
		run;

	proc sgplot data=bata_p;
		reg x=zlgcrp_bl y=&yvar;
		title "Predicting &yvar from CRP";
		where  (-3 < z&yvar < 3) and (-3 < zlgcrp_BL < 3);
	run;

	proc glm data=bata_p;
		class sex oralcontraceptive (ref=first) progestin_iud (ref=first);
		model &yvar=zage sex zbmi zlgil6_BL/ solution;
		ods select fitstatistics ParameterEstimates;
		title "Predicting Baseline &yvar from age, sex, weight, and IL-6";
		where  (-3 < z&yvar < 3) and (-3 < zlgil6_BL < 3);
		run;

	proc sgplot data=bata_p;
		reg x=zlgil6_bl y=&yvar;
		title "Predicting &yvar from IL-6";
		where  (-3 < z&yvar < 3) and (-3 < zlgil6_BL < 3);
	run;

	proc glm data=bata_p;
		class sex oralcontraceptive (ref=first) progestin_iud (ref=first);
		model &yvar=zage sex zbmi zlgtnfa_BL/ solution;
		ods select fitstatistics ParameterEstimates;
		title "Predicting Baseline &yvar from age, sex, weight, and TNFa";
		where  (-3 < z&yvar < 3) and (-3 < zlgtnfa_BL < 3);
		run;

	proc sgplot data=bata_p;
		reg x=zlgtnfa_bl y=&yvar;
		title "Predicting &yvar from TNFa";
		where  (-3 < z&yvar < 3) and (-3 < zlgtnfa_BL < 3);
	run;

	proc glm data=bata_p;
		class sex oralcontraceptive (ref=first) progestin_iud (ref=first);
		model &yvar=zage sex zbmi zlgtnfa_BL zlgil6_BL zlgCRP_BL/ solution;
		ods select fitstatistics ParameterEstimates;
		title "ALL IMMUNE IN SAME MODEL: Predicting Baseline &yvar from age, sex, weight, and TNFa/IL-6/CRP";
		where  (-3 < z&yvar < 3) and (-3 < zlgtnfa_BL < 3) and (-3 < zlgcrp_BL < 3) 
			and (-3 < zlgil6_BL < 3);
		run;
	%mend;

	%let ylist= pcing6_BL pcing7_BL 
	
	pt_hw_tot clin_hw_tot shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL decentering_BL curiosity_BL pcl5_BL 
	petdiff lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL 
L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL 
cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL;

	%macro immunebaselinerun;
		%do i=1 %to 38;
			%let yvar=%scan(&ylist, &i);
			%immunebaseline(yvar=&yvar);
		%end;
	%mend;

	%immunebaselinerun;

	/* Models predicting Baseline Symptoms from immune vars in REG MODELS */
	%macro immunebaseline (yvar=);
		ods html5 style=htmlblue 
			path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - all OL rem - proc reg - Predicting Baseline &yvar from age, female, weight, and Immune Vars.html";

	proc reg data=bata_p_olrem plots=fitplot;
		model &yvar=zage female zbmi zlgcrp_BL;
		title "Predicting Baseline &yvar from age, female, weight, and CRP";
		where  (-3 < z&yvar < 3) and (-3 < zlgcrp_BL < 3);
		run;

	proc sgplot data=bata_p_olrem;
		reg x=zlgcrp_bl y=&yvar;
		title "Predicting &yvar from CRP";
		where  (-3 < z&yvar < 3) and (-3 < zlgcrp_BL < 3);
	run;

	proc reg data=bata_p_olrem plots=fitplot;
		model &yvar=zage female zbmi zlgil6_BL;
		title "Predicting Baseline &yvar from age, female, weight, and IL-6";
		where  (-3 < z&yvar < 3) and (-3 < zlgil6_BL < 3);
		run;

	proc sgplot data=bata_p_olrem;
		reg x=zlgil6_bl y=&yvar;
		title "Predicting &yvar from IL-6";
		where  (-3 < z&yvar < 3) and (-3 < zlgil6_BL < 3);
	run;

	proc reg data=bata_p_olrem plots=fitplot;
		model &yvar=zage female zbmi zlgtnfa_BL;
		title "Predicting Baseline &yvar from age, female, weight, and TNFa";
		where  (-3 < z&yvar < 3) and (-3 < zlgtnfa_BL < 3);
		run;

	proc sgplot data=bata_p_olrem;
		reg x=zlgtnfa_bl y=&yvar;
		title "Predicting &yvar from TNFa";
		where  (-3 < z&yvar < 3) and (-3 < zlgtnfa_BL < 3);
	run;

	proc reg data=bata_p_olrem plots=fitplot;
		model &yvar=zage female zbmi zlgtnfa_BL zlgil6_BL zlgCRP_BL;
		title "ALL IMMUNE IN SAME MODEL: Predicting Baseline &yvar from age, female, weight, and TNFa/IL-6/CRP";
		where  (-3 < z&yvar < 3) and (-3 < zlgtnfa_BL < 3) and (-3 < zlgcrp_BL < 3) 
			and (-3 < zlgil6_BL < 3);
		run;
	%mend;

	%let ylist= pt_hw_tot clin_hw_tot shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL decentering_BL curiosity_BL 
	pcl5_BL petdiff lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL 
L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL 
cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL;

	%macro immunebaselinerun;
		%do i=1 %to 38;
			%let yvar=%scan(&ylist, &i);
			%immunebaseline(yvar=&yvar);
		%end;
	%mend;

	%immunebaselinerun;

	/* Effects of Time on outcomes */
	%macro onelevel (yvar=);
		ods html5 style=htmlblue 
			path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - traj and trait gr3sd OL rem - covar age sex bmi birthcontrol - &yvar over time.html";

	proc sgplot data=bata_p_pp_olrem;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr group=tx;
		title "Baseline-Centered &yvar (raw value - person V1 value)";
	run;

	proc sgpanel data=bata_p_pp_olrem;
		panelby tx;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr 
			group=subject_id datalabel=subject_id;
		title "By Group - Each Individual - Baseline-Centered &yvar";
	run;

	proc sort data=bata_p_pp_olrem;
		by subject_id torytime;
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive behav_wk / solution 
			ddfm=kenwardroger2;
		random intercept behav_wk/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive behav_wk/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and FIXED Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive TORYTIME / solution 
			ddfm=kenwardroger2;
		random intercept TORYTIME/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over TORYTIME -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive TORYTIME/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over TORYTIME -  Growth Model with a Random Intercept and FIXED Time Slope";
	run;

%mend;

%let ylist= lgil6 lgtnfa lgcrp pcing6 pcing7 

shaps_behav shaps_scan bdi lgbai pss decentering curiosity  pcing lamy ramy cuerew_c9 cuerew_c10 cuerew_c11 cuerew_c12 
	PwSN PwFPN PwDMN PwRew;

%macro onelevelrun;
	%do i=1 %to 5 /*23*/;
		%let yvar=%scan(&ylist, &i);
		%onelevel(yvar=&yvar);
	%end;
%mend;

%onelevelrun;

/* 2021-08-05 - Effects of Group * Time on outcomes */
%macro txtime (yvar=);
	ods html5 style=htmlblue 
		path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - traj and trait gr3sd OL rem - covar age sex bmi birthcontrol - Tx by Time Predicting &yvar.html";

	proc sgplot data=bata_p_pp_olrem;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr group=tx;
		title "Baseline-Centered &yvar (raw value - person V1 value)";
	run;

	proc sgpanel data=bata_p_pp_olrem;
		panelby tx;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr 
			group=subject_id datalabel=subject_id;
		title "By Group - Each Individual - Baseline-Centered &yvar";
	run;

	proc sort data=bata_p_pp_olrem;
		by subject_id torytime;
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk / solution 
			ddfm=kenwardroger2;
		random intercept behav_wk/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and FIXED Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME / solution 
			ddfm=kenwardroger2;
		random intercept TORYTIME/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over TORYTIME -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over TORYTIME -  Growth Model with a Random Intercept and FIXED Time Slope";
	run;

%mend;

%let ylist= lgil6 lgtnfa lgcrp pcing6 pcing7 

shaps_behav shaps_scan bdi lgbai pss decentering curiosity  pcing lamy ramy cuerew_c9 cuerew_c10 cuerew_c11 cuerew_c12 
	PwSN PwFPN PwDMN PwRew;

%macro txtimerun;
	%do i=1 %to 5 /*23*/;
		%let yvar=%scan(&ylist, &i);
		%txtime(yvar=&yvar);
	%end;
%mend;

%txtimerun;

/* Effects of Time, Treatment by Time, and moderator by time */
%macro crosslevel (yvar=, mod=);
	ods html5 style=htmlblue 
		path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - covar age weight sex - traj and trait gr3sd OL rem - Baseline &mod (and Tx) predicting &yvar over time.html";

	proc sgplot data=bata_p_pp_olrem;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr group=tx;
		title "Baseline-Centered &yvar (raw value - person V1 value)";
	run;

	proc sgpanel data=bata_p_pp_olrem;
		panelby tx;
		vline torytime/ response=&yvar stat=mean limitstat=stderr group=subject_id 
			datalabel=subject_id;
		title "By Group - Each Individual - Raw &yvar";
	run;

	proc sgpanel data=bata_p_pp_olrem;
		panelby tx;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr 
			group=subject_id datalabel=subject_id;
		title "By Group - Each Individual - Baseline-Centered &yvar";
	run;

	proc sgpanel data=bata_p_pp_olrem;
		panelby tx;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr 
			group=&mod.split;
		title 
			"Baseline-Centered change in &yvar - plotted by Tx and median split &mod";
	run;

	proc sgpanel data=bata_p_pp_olrem;
		panelby &mod.split;
		vline torytime/ response=&yvar.change stat=mean limitstat=stderr group=tx;
		title 
			"Baseline-Centered change in &yvar - plotted by Tx  and median split &mod";
	run;

	proc sort data=bata_p_pp_olrem;
		by subject_id torytime;
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|behav_wk z&mod|tx|behav_wk / solution 
			ddfm=kenwardroger2;
		random intercept behav_wk/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous Time  - Growth Model with a Random Intercept and Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|behav_wk z&mod|tx|behav_wk / solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous behav_wk  - Growth Model with a Random Intercept and FIXED Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime z&mod|tx|torytime / solution 
			ddfm=kenwardroger2;
		random intercept torytime /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous torytime - Growth Model with a Random Intercept and Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime z&mod|tx|torytime / solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous torytime - Growth Model with a Random Intercept and FIXED time slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) torytime (ref=first) 
			progestin_iud(ref=first);
		model &yvar=female zage zbmi tx|torytime z&mod|tx|torytime/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Categorical Time - Growth Model with a Random Intercept and Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx z&mod|behav_wk / solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - PARED DOWN MODEL WITH JUST &mod x behav_wk";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx z&mod|torytime / solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - PARED DOWN MODEL WITH JUST &mod x torytime";
	run;

%mend;

%let ylist= lgil6 lgtnfa lgcrp pcing6 pcing7 shaps_behav shaps_scan bdi   lgbai pss decentering curiosity    
lamy ramy cuerew_c9 cuerew_c10 cuerew_c11 cuerew_c12 
	PwSN PwFPN PwDMN PwRew;
%let modlist= ctqtot_mean pt_hw_tot clin_hw_tot lgil6_BL lgtnfa_BL lgcrp_BL pcing6_BL pcing7_BL petdiff lamy_BL ramy_BL  L_nacc_3_BL L_nacc_6_BL L_caud_3_BL 
L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL 
cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL emoabuse 
emoneg physabuse physneg sexabuse  age ;

%macro crosslevelrun;
	%do j=1 %to 1 /*modlist - 38 total*/;

		%do i=1 %to 3 /*ylist - 23 total*/;
			%let yvar=%scan(&ylist, &i);
			%let mod=%scan(&modlist, &j);
			%crosslevel(yvar=&yvar, mod=&mod);
		%end;
	%end;
%mend;

%crosslevelrun;

/* How do they covary - MOD BY CTQ*/
*Clear Results Viewer;

%macro covar(xvar=, yvar=);
	/*dm 'odsresults; clear';*/
	ods html5 style=htmlblue 
		path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021ctq\' file="%sysfunc(today(), yymmddd10.) - BATA2021ctq - (traj and 3zm 3zd outl removed) - CTQ mod of trait and state assoc of &xvar with &yvar .html";

	proc mixed data=bata_p_pp covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=sex zage zctqtot_mean|z&xvar.m zctqtot_mean|&xvar.d/ solution 
			ddfm=kenwardroger2;
		random intercept/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title 
			"CTQ MOD - Predicting &yvar from Between and Within-Person Variance in &xvar";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=sex zage tx behav_wk zctqtot_mean|z&xvar.m zctqtot_mean|&xvar.d / 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "CTQ MOD - Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for time and treatment";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=sex zage tx|behav_wk zctqtot_mean|z&xvar.m zctqtot_mean|&xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "CTQ MOD - Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for the interaction of time and treatment ";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=sex zage tx TORYTIME zctqtot_mean|z&xvar.m zctqtot_mean|&xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "CTQ MOD - Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for TORYTIME and treatment";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=sex zage tx|TORYTIME zctqtot_mean|z&xvar.m zctqtot_mean|&xvar.d/ 
			solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "CTQ MOD - Predicting &yvar from Between and Within-Person Variance in &xvar - Controlling for the interaction of TORYTIME and treatment ";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc sgplot data=bata_p;
		reg x=z&xvar.m y=&yvar.m/ group=ctqtot_meansplit;
		title 
			"CTQ MOD - BETWEEN-PERSON: Predicting &yvar person-mean from &xvar person-mean";
		where  (-3 < z&yvar.m < 3) AND (-3 < z&xvar.m < 3);
	run;

	proc sgplot data=bata_p_pp;
		reg x=&xvar.d y=&yvar.d / group=ctqtot_meansplit;
		title "CTQ MOD - WITHIN-PERSON: Predicting daily &yvar from daily &xvar (dev from person-mean)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3);
	run;

%mend;

%let ylist= shaps_behav shaps_scan bdi bai lgbai pss pswq decentering curiosity pcl5 il6 lgil6 tnfa lgtnfa crp lgcrp lamy ramy pcing pcing6 pcing7 L_nacc_3 
L_nacc_6 L_caud_3 L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 
cuerew_c12 PwSN PwFPN PwDMN PwRew  ;
%let xlist= il6 lgil6 tnfa lgtnfa crp lgcrp lamy ramy pcing pcing6 pcing7 L_nacc_3 L_nacc_6 L_caud_3 L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 
R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 
cuerew_c12 PwSN PwFPN PwDMN PwRew shaps_behav shaps_scan bdi bai lgbai pss pswq decentering curiosity pcl5 ;

%macro covarrun;
	%do j=1 %to 41;

		%do i=1 %to 41;
			%let yvar=%scan(&ylist, &i);
			%let xvar=%scan(&xlist, &j);
			%covar(yvar=&yvar, xvar=&xvar);
		%end;
	%end;
%mend;

%covarrun;

%macro baronkenny(xvar=, yvar=);
	ods html5 style=htmlblue 
		path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - Mediation of Tx by Time - all OL rem - Tx by Time Effects (Torytime and Behav_wk) - Random & Fixed Time - adding trait and state assoc of &xvar with &yvar .html";

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|behav_wk/ solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title 
			"Predicting &yvar from TREATMENT BY BEHAV_WK (FIXED EFFECT OF BEHAV_WK)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|behav_wk &xvar.m &xvar.d/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from TREATMENT BY BEHAV_WK (FIXED EFFECT of BEHAV_WK) - adding &xvar.m and &xvar.d";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|behav_wk/ solution ddfm=kenwardroger2;
		random intercept behav_wk/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title 
			"Predicting &yvar from TREATMENT BY BEHAV_WK (RANDOM EFFECT of BEHAV_WK)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|behav_wk &xvar.m &xvar.d/ solution 
			ddfm=kenwardroger2;
		random intercept behav_wk/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from TREATMENT BY BEHAV_WK (RANDOM EFFECT of BEHAV_WK) - adding &xvar.m and &xvar.d";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime/ solution ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title 
			"Predicting &yvar from TREATMENT BY TORYTIME (FIXED EFFECT OF TORYTIME)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime &xvar.m &xvar.d/ solution 
			ddfm=kenwardroger2;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from TREATMENT BY TORYTIME (FIXED EFFECT OF TORYTIME) - adding &xvar.m and &xvar.d";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime/ solution ddfm=kenwardroger2;
		random intercept torytime/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title 
			"Predicting &yvar from TREATMENT BY TORYTIME (RANDOM EFFECT of TORYTIME)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime &xvar.m &xvar.d/ solution 
			ddfm=kenwardroger2;
		random intercept torytime/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar from TREATMENT BY TORYTIME (RANDOM EFFECT of TIME) - adding &xvar.m and &xvar.d";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3) AND (-3 < z&yvar.m < 3) 
			AND (-3 < z&xvar.m < 3);
	run;

	proc sgplot data=bata_p_pp_olrem;
		reg x=torytime y=&xvar / group=subject_id;
		reg x=torytime y=&xvar /lineattrs=(color=black thickness=4);
		title "Torytime Predicting &xvar";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3);
	run;

	proc sgplot data=bata_p_pp_olrem;
		reg x=behav_wk y=&xvar / group=subject_id;
		reg x=behav_wk y=&xvar /lineattrs=(color=black thickness=4);
		title "behav_wk Predicting &xvar";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3);
	run;

	proc sgplot data=bata_p_pp_olrem;
		reg x=torytime y=&yvar / group=subject_id;
		reg x=torytime y=&yvar /lineattrs=(color=black thickness=4);
		title "Torytime Predicting &yvar";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3);
	run;

	proc sgplot data=bata_p_pp_olrem;
		reg x=behav_wk y=&yvar / group=subject_id;
		reg x=behav_wk y=&yvar /lineattrs=(color=black thickness=4);
		title "behav_wk Predicting &yvar";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3);
	run;

	proc sgplot data=bata_p_olrem;
		reg x=z&xvar.m y=&yvar.m;
		title "BETWEEN-PERSON: Predicting &yvar person-mean from &xvar person-mean";
		where  (-3 < z&yvar.m < 3) AND (-3 < z&xvar.m < 3);
	run;

	proc sgplot data=bata_p_pp_olrem;
		reg x=&xvar.d y=&yvar.d / group=subject_id;
		reg x=&xvar.d y=&yvar.d /lineattrs=(color=black thickness=4);
		title "WITHIN-PERSON: Predicting &yvar from &xvar (dev from person-mean)";
		where  (-3 < &yvar.zd < 3) AND (-3 < &xvar.zd < 3);
	run;

%mend;

%let ylist= shaps_behav shaps_scan bdi bai lgbai pss pswq decentering curiosity pcl5 il6 lgil6 tnfa lgtnfa crp lgcrp lamy ramy pcing pcing6 pcing7 L_nacc_3 
L_nacc_6 L_caud_3 L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 
cuerew_c12 PwSN PwFPN PwDMN PwRew  ;
%let xlist= il6 lgil6 tnfa lgtnfa crp lgcrp lamy ramy pcing pcing6 pcing7 L_nacc_3 L_nacc_6 L_caud_3 L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 
R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 
cuerew_c12 PwSN PwFPN PwDMN PwRew shaps_behav shaps_scan bdi bai lgbai pss pswq decentering curiosity pcl5 ;

%macro bkrun;
	%do j=1 %to 41;

		%do i=1 %to 41;
			%let yvar=%scan(&ylist, &i);
			%let xvar=%scan(&xlist, &j);
			%baronkenny(yvar=&yvar, xvar=&xvar);
		%end;
	%end;
%mend;

%bkrun;

/*Making Prettier Figures for erin's talk*/
proc sgplot data=bata_p_pp_olrem;
	xaxis label="PCING at this Time Point";
	yaxis label="SHAPS Score at this Time Point";
	reg x=pcingd y=shaps_behavd /nomarkers group=subject_id;
	reg x=pcingd y=shaps_behavd /nomarkers lineattrs=(color=black thickness=4);
	refline 0 /axis=x;
	refline 0/ axis=y;
	title "Within-Person Correlation of PCING and SHAPS";
	where  (-3 < shaps_behavzd < 3) AND (-3 < pcingzd < 3);
run;

proc sgplot data=bata_p_pp_olrem;
	xaxis label="PCING at this Time Point";
	yaxis label="IL-6 at this Time Point";
	reg x=pcingd y=il6d /nomarkers group=subject_id;
	reg x=pcingd y=il6d /nomarkers lineattrs=(color=black thickness=4);
	refline 0 /axis=x;
	refline 0/ axis=y;
	title "Within-Person Correlation of PCING and IL-6";
	where  (-3 < shaps_behavzd < 3) AND (-3 < pcingzd < 3);
run;

proc sgplot data=bata_p_pp_olrem;
	xaxis label="PCING at this Time Point";
	yaxis label="CRP at this Time Point";
	reg x=pcingd y=crpd /nomarkers group=subject_id;
	reg x=pcingd y=crpd /nomarkers lineattrs=(color=black thickness=4);
	refline 0 /axis=x;
	refline 0/ axis=y;
	title "Within-Person Correlation of PCING and CRP";
	where  (-3 < shaps_behavzd < 3) AND (-3 < pcingzd < 3);
run;

proc sgplot data=bata_p_pp_olrem;
	xaxis label="IL-6 at this Time Point";
	yaxis label="SHAPS at this Time Point";
	reg x=il6d y=SHAPS_behavd /nomarkers group=subject_id;
	reg x=il6d y=SHAPS_behavd /nomarkers lineattrs=(color=black thickness=4);
	refline 0 /axis=x;
	refline 0/ axis=y;
	title "Within-Person Correlation of IL-6 and SHAPS";
	where  (-3 < shaps_behavzd < 3) AND (-3 < pcingzd < 3);
run;