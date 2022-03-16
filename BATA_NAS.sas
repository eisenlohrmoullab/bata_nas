/*BATA 2022 NAS-IMMUNE-THREAT-SX - PREREGISTERED*/

/*IMPORT DATASETS*/

/*Import Immune Data*/

data batanas.immune /*(keep=subject_id torytime il6 tnfa crp)*/;
	set batanas.immune_rois;
	torytime=.;

	if visit_fmri=1 then
		torytime=1;

	if visit_fmri=2 then
		torytime=3;

	if visit_fmri=3 then
		torytime=4;

	if visit_fmri=4 then
		torytime=5;

	/* REMOVING OUTLIERS IDENTIFIED BY TORY AND ERIN through VISUAL INSPECTION OF TIME SERIES*/
	/* Remove all obs for person-level outliers
	if subject_id in ("BA0329", "BA0170") then
		il6=.;

	if subject_id in ("BA0253") then
		crp=.;

	/* Remove specific visit-level CRP outliers
	if torytime=3 and subject_id in ("BA0294") then
		crp=.;

	if torytime=4 and subject_id in ("BA0691") then
		crp=.;

	if torytime=5 and subject_id in ("BA0389", "BA0403") then
		crp=.;

	/* Remove specific visit-level TNFa outliers
	if torytime=4 and subject_id in ("BA0741") then
		tnfa=.;

	if torytime=5 and subject_id in ("BA0741") then
		tnfa=.;*/
run;



/*Import new Hammer PCING Data 2021-07-29*/


FILENAME REFFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/03_code_dataedits_output/bata_nas/hammer.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=batanas.hammer REPLACE;
	GETNAMES=YES;
RUN;



/* Rename scanid and prep for merging*/
data batanas.hammer /*(keep=subject_id scanid pcing6 pcing7)*/;
	set batanas.hammer;
	scanid=scan;

	/* REMOVING OUTLIERS IDENTIFIED BY TORY AND ERIN through VISUAL INSPECTION OF TIME SERIES*/
	/*none yet*/
run;


/*Import and Sort State Questionnaire Data*/
data batanas.selfreport (keep=subject_id torytime behav_wk bdi shaps_scan bai pss pswq 
		decentering curiosity pcl5);
	set batanas.mlm_sub73;
	torytime=.;

	if visit_fmri=1 then
		torytime=1;

	if visit_fmri=. then
		torytime=2;

	if visit_fmri=2 then
		torytime=3;

	if visit_fmri=3 then
		torytime=4;

	if visit_fmri=4 then
		torytime=5;

	/* REMOVING OUTLIERS IDENTIFIED BY TORY AND ERIN through VISUAL INSPECTION OF TIME SERIES*/
	/* Remove all obs for person-level outliers*/
	if subject_id in ("BA0104") then
		bai=.;
run;





/*Import NAS data*/


FILENAME REFFILE 'Y:/Library/CloudStorage/Box-Box/00 - CLEAR Lab (Locked Folders)/02 - Data Management, Analysis, and Papers/Studies_Projects/BATA/03_analytic_projects/BATA_NAS/03_code_dataedits_output/bata_nas/2021-10-28 - bata_nas_cyc.sav';

PROC IMPORT DATAFILE=REFFILE
	DBMS=SPSS
	OUT=batanas.nas REPLACE;
RUN;





proc sort data=selfreport;
	by subject_id torytime;
run;

/*Merge All Person-Period Datasets together*/;

data bata_pp (keep=subject_id torytime behav_wk il6 lgil6 tnfa lgtnfa crp lgcrp 
		lamy ramy pcing pcing6 pcing7 shaps_behav shaps_scan bdi 
		bai lgbai pss pswq decentering curiosity pcl5);
	merge immune hammer selfreport;
	by subject_id torytime;
	il6_plusone=il6+1;
	crp_plusone=crp+1;
	tnfa_plusone=tnfa+1;
	bai_plusone=bai+1;
	lgil6=log10(il6_plusone);
	lgcrp=log10(crp_plusone);
	lgtnfa=log10(tnfa_plusone);
	lgbai=log10(bai_plusone);

	if subject_id="BA1737" then
		delete;
	drop il6_plusone tnfa_plusone crp_plusone bai_plusone;
run;

proc sort data=bata_pp out=bata_pp nodupkey;
	by subject_id torytime;
run;


/*Grab the right time variable from the RSFC scanid-torytime link*/
data hammer (keep=subject_id scanid torytime pcing6 pcing7);
	merge rsfc hammer02;
	by subject_id scanid;

	if pcing6=. then
		delete;
run;

/*Re-sort rsfc dataset*/
proc sort data=rsfc;
	by subject_id torytime;
run;

/*Merge into hammer dataset*/
data hammer;
	merge hammer hammer02;
	by subject_id torytime;
run;





/*N=30*/
/* SAVING TRAITS FROM THE STATE DATASETS*/
/* Macro for Saving Baseline values of repeated measures and Sample Standardizing baseline diffs */
%macro savebaseline (yvar=);
	data baseline;
		set bata_pp;

		if torytime ne 1 then
			delete;
	run;

	data &yvar.baseline (keep=subject_id &yvar._BL z&yvar._BL);
		set baseline;
		&yvar._BL=&yvar;
		z&yvar._BL=&yvar;
	run;

	proc standard data=&yvar.baseline out=&yvar.baseline m=0 std=1;
		var z&yvar._BL;
	run;

	/*Merge Baselines back into state dataset as traits*/
	data bata_pp;
		merge bata_pp &yvar.baseline;
		by subject_id;
		&yvar.change=&yvar-&yvar._BL;
	run;

%mend;

%let ylist= il6 lgil6 tnfa lgtnfa crp lgcrp lamy ramy pcing pcing6 pcing7 L_nacc_3 L_nacc_6 L_caud_3 
L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 cuerew_c12 shaps_behav shaps_scan
bdi bai lgbai pss pswq decentering curiosity pcl5 PwSN PwFPN PwDMN PwRew;

%macro savebaselinerun;
	%do i=1 %to 41;
		%let yvar=%scan(&ylist, &i);
		%savebaseline(yvar=&yvar);
	%end;
%mend;

%savebaselinerun;

/* Macro for Saving Person Means for repeated measures and Sample Standardizing individual diffs in means, as well as calculating state deviations */
%macro meansanddevs (yvar=);
	data bata_pp;
		set bata_pp;
		&yvar.d=&yvar;
		&yvar.zd=&yvar;
	run;

	proc standard data=bata_pp out=bata_pp m=0;
		var &yvar.d;
		by subject_id;
	run;

	proc standard data=bata_pp out=bata_pp m=0 std=1;
		var &yvar.zd;
		by subject_id;
	run;

	proc means data=bata_pp noprint;
		var &yvar;
		by subject_id;
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
		by subject_id;
	run;

	proc sort data=bata_pp out=bata_pp;
		by subject_id torytime;
	run;

	data bata_pp;
		merge bata_pp &yvar.means;
		by subject_id;
	run;

%mend;

%let ylist= il6 lgil6 tnfa lgtnfa crp lgcrp lamy ramy pcing pcing6 pcing7 L_nacc_3 L_nacc_6 L_caud_3 
L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 R_caud_6 R_put_3 R_put_6 cuerew_c9 cuerew_c10 cuerew_c11 cuerew_c12 shaps_behav shaps_scan
bdi bai lgbai pss pswq decentering curiosity pcl5 PwSN PwFPN PwDMN PwRew;

%macro meansanddevsrun;
	%do i=1 %to 39;
		%let yvar=%scan(&ylist, &i);
		%meansanddevs(yvar=&yvar);
	%end;
%mend;

%meansanddevsrun;

/*IMPORT TRAIT DATASETS*/
/* IMPORT BMI*/
proc import 
		datafile="Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\bmi_pp.xlsx" 
		out=bmi dbms=xlsx replace;
run;

data bmi (keep=subject_id visit_fmri bmi);
	set bmi;
	bmi=bmi_final;
run;

proc sort data=bmi nodupkey;
	by subject_id;
run;

/*Import and sort baseline PET Data*/
data pet (keep=subject_id petdiff);
	set bata2021.pet_bl_roi;
	petdiff=pet_bl_rew_neu_diff;
	where pet_bl_rew_neu_diff ne .;
run;

proc sort data=pet out=pet nodupkey;
	by subject_id;
run;

/*Import CTQ Data*/
data ctq (keep=subject_id emoabuse emoneg physneg physabuse sexabuse 
		ctqtot_mean);
	set bata2021.ctq;
run;

proc sort data=ctq out=ctq nodupkey;
	by subject_id;
run;

/*Create Trait Dataset with demos and study info from first visit in self-report dataset*/
data demos_studyinfo (keep=subject_id age sex diagnosis tx therapist completer 
		total_scans);
	set bata2021.mlm_sub73;
	where visit_fmri=1;
run;

/*Create Trait Dataset from from first visit in immune_roi dataset*/
data traitcovars (keep=subject_id oralcontraceptive allergy_asthma bp_meds 
		migraine endocrine rx_opiod nsaid progestin_iud weight_lb);
	set bata2021.immune_rois;
	where visit_fmri=1;
run;

proc sort data=traitcovars out=traitcovars nodupkey;
	by subject_id;
run;

/*Create and sort HW trait dataset from first visit in MLM_Midrois*/
data homework (keep=subject_id pt_hw_tot clin_hw_tot);
	set bata2021.mlm_midrois;
	where fmri_visit=1;
run;

proc sort data=homework out=homework nodupkey;
	by subject_id;
run;

/*Create and sort baseline values dataset*/
data baseline (keep=subject_id shaps_behav_BL shaps_scan_BL bdi_BL bai_BL 
		lgbai_BL pss_BL pswq_BL decentering_BL curiosity_BL pcl5_BL il6_BL lgil6_BL 
		tnfa_BL lgtnfa_BL crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL pcing6_BL 
		pcing7_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL L_caud_6_BL L_put_3_BL 
		L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL 
		R_put_6_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL cuerew_c9_BL cuerew_c10_BL 
		cuerew_c11_BL cuerew_c12_BL);
	set bata_pp;
	where torytime=1;
run;

proc sort data=baseline out=baseline nodupkey;
	by subject_id;
run;

/* Merge all Traits together (except means and baseline values for repeated vars, which were saved, sample-standardized, and merged into bata_pp above) */
data bata_p;
	merge demos_studyinfo pet homework ctq traitcovars baseline bmi;
	by subject_id;

	if oralcontraceptive=. then
		oralcontraceptive=0;

	if progestin_iud=. then
		progestin_iud=0;

	if allergy_asthma=. then
		allergy_asthma=0;

	if subject_id="BA1737" then
		delete;
run;

/*Macro for standardizing continuous traits and saving their median split levels */
%macro traitprep (trait=);
	data bata_p;
		set bata_p;
		z&trait=&trait;
	run;

	proc standard data=bata_p out=bata_p m=0 std=1;
		var z&trait;
	run;

	/*Create a constant variable so you can merge in a constant medin variable - and create a flag variable for trait obs outside 3sd*/
	data bata_p;
		set bata_p;
		constantmed=1;
		flagz&trait=.;

		if (z&trait < -3) or (z&trait > 3) then
			flagz&trait=1;
		else
			flagz&trait=0;
	run;

	/*Calculate Medians for Plots*/
	proc format;
		value split 0="Below Median" 1="Above Median";
	run;

	proc means data=bata_p median noprint;
		var &trait constantmed;
		output out=&trait.median median=&trait.med constantmed;
	run;

	data bata_p;
		merge bata_p &trait.median;
		by constantmed;
		&trait.split=.;

		if &trait>=&trait.med then
			&trait.split=1;

		if &trait<&trait.med then
			&trait.split=0;
		format &trait.split split.;
	run;

	/* Print the IDs of those with traits outside 3 SDs*/
	proc print data=bata_p;
		var subject_id z&trait &trait;
		where flagz&trait=1 and &trait ne .;
		title "z&trait: Subject_IDs with values outside of 3 SDs from grand mean";
	run;

	data bata_p_olrem;
		set bata_p;

		if flagz&trait=1 then
			do;
				z&trait=.;
				&trait=.;
				&trait.split=.;
			end;
	run;

%mend;

%let traitlist= age pt_hw_tot clin_hw_tot weight_lb bmi emoabuse emoneg physneg physabuse sexabuse ctqtot_mean petdiff 
shaps_behav_BL shaps_scan_BL bdi_BL bai_BL lgbai_BL pss_BL pswq_BL decentering_BL curiosity_BL pcl5_BL il6_BL lgil6_BL tnfa_BL lgtnfa_BL 
crp_BL lgcrp_BL lamy_BL ramy_BL pcing_BL pcing6_BL pcing7_BL L_nacc_3_BL L_nacc_6_BL L_caud_3_BL 
L_caud_6_BL L_put_3_BL L_put_6_BL R_nacc_3_BL R_nacc_6_BL R_caud_3_BL R_caud_6_BL R_put_3_BL R_put_6_BL cuerew_c9_BL cuerew_c10_BL cuerew_c11_BL 
cuerew_c12_BL PwSN_BL PwFPN_BL PwDMN_BL PwRew_BL;

%macro traitpreprun;
	%do i=1 %to 53;
		%let trait=%scan(&traitlist, &i);
		%traitprep(trait=&trait);
	%end;
%mend;

%traitpreprun;

/*MERGE TOGETHER TRAIT AND STATE DATASETS - keeping trait outliers*/
data bata_p_pp;
	merge bata_pp bata_p;
	by subject_id;
run;

*Save merged pp-p dataset to BATA2021 folder;
*recall that a variety of state(d) and trait(m) outliers have been removed after Tory and Erin's visual inspection of individual trajectories - done in the import steps above;

data bata2021.bata_p_pp;
	merge bata_pp bata_p;
	by subject_id;
run;

/* Create Final bata_p dataset including BLs and means*/
proc sort data=bata_p_pp out=bata_p nodupkey;
	by subject_id;
run;

/*Save to Folder*/
proc sort data=bata_p_pp out=bata2021.bata_p nodupkey;
	by subject_id;
run;

/*MERGE TOGETHER TRAIT AND STATE DATASETS - removing trait outliers*/
data bata_p_pp_olrem;
	merge bata_pp bata_p_olrem;
	by subject_id;
run;

*Save merged pp-p dataset to BATA2021 folder;
*recall that a variety of state(d) and trait(m) outliers have been removed after Tory and Erin's visual inspection of individual trajectories - done in the import steps above;

data bata2021.bata_p_pp_olrem;
	merge bata_pp bata_p_olrem;
	by subject_id;
run;

/* Create Final bata_p dataset including BLs and means*/
proc sort data=bata_p_pp_olrem out=bata_p_olrem nodupkey;
	by subject_id;
run;

/*Save to Folder*/
proc sort data=bata_p_pp_olrem out=bata2021.bata_p_olrem nodupkey;
	by subject_id;
run;

/*************************************************************** END DATA PREP */
/* Load Saved Dataset*/
LIBNAME bata2021 "Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\";

proc format;
	value split 0="Below Median" 1="Above Median";
run;

data bata_p_pp;
	set bata2021.bata_p_pp;
run;

data bata_p;
	set bata2021.bata_p;
run;

data bata_p_pp_olrem;
	set bata2021.bata_p_pp_olrem;
	female=.;

	if sex="M" then
		female=0;

	if sex="F" then
		female=1;
run;

data bata_p_olrem;
	set bata2021.bata_p_olrem;
	female=.;

	if sex="M" then
		female=0;

	if sex="F" then
		female=1;
run;

/*32 REPEATED OUTCOMES*/
*il6 lgil6 tnfa lgtnfa crp lgcrp lamy ramy pcing pcing6 pcing7 L_nacc_3 L_nacc_6 L_caud_3 
L_caud_6 L_put_3 L_put_6 R_nacc_3 R_nacc_6 R_caud_3 R_caud_6 R_put_3 R_put_6 shaps_behav 




				bdi bai lgbai pss pswq decentering curiosity pcl5 PwSN PwFPN PwDMN PwRew;

/*MEANS AND BASELINE VALUES FOR REPEATED OUTCOMES*/
*var.m, zvar.m, var_BL, zvar_BL;

/*TRAITS - ALL continuous saved as zvar and zvarsplit as well*/
*age sex diagnosis tx therapist completer 
		total_scans pt_hw_tot clin_hw_tot oralcontraceptive allergy_asthma bp_meds 
		migraine endocrine rx_opiod nsaid progestin_iud weight_lb emoabuse emoneg physneg 




						physabuse sexabuse ctqtot_mean petdiff;
*/ 
		
		

/*************************************************************** END VARIABLE LISTS */

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
		model &yvar=female zage zbmi oralcontraceptive behav_wk / solution ddfm=kr;
		random intercept behav_wk/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive behav_wk/ solution ddfm=kr;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and FIXED Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive TORYTIME / solution ddfm=kr;
		random intercept TORYTIME/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over TORYTIME -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive TORYTIME/ solution ddfm=kr;
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
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk / solution ddfm=kr;
		random intercept behav_wk/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk/ solution ddfm=kr;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over BEHAV_WK -  Growth Model with a Random Intercept and FIXED Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME / solution ddfm=kr;
		random intercept TORYTIME/subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar over TORYTIME -  Growth Model with a Random Intercept and Random Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|behav_wk z&mod|tx|behav_wk / solution ddfm=kr;
		random intercept behav_wk/subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous Time  - Growth Model with a Random Intercept and Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|behav_wk z&mod|tx|behav_wk / solution ddfm=kr;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous behav_wk  - Growth Model with a Random Intercept and FIXED Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime z&mod|tx|torytime / solution ddfm=kr;
		random intercept torytime /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous torytime - Growth Model with a Random Intercept and Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx|torytime z&mod|tx|torytime / solution ddfm=kr;
		random intercept /subject=subject_id type=vc;

		/*repeated /subject=subject_id type=ar(1)*/
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Continuous torytime - Growth Model with a Random Intercept and FIXED time slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) torytime (ref=first) 
			progestin_iud(ref=first);
		model &yvar=female zage zbmi tx|torytime z&mod|tx|torytime/ solution ddfm=kr;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - Cross-Level Interaction of &mod, TX, and Categorical Time - Growth Model with a Random Intercept and Time Slope";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi tx z&mod|behav_wk / solution ddfm=kr;
		random intercept /subject=subject_id type=vc;
		ods select Nobs fitstatistics covparms solutionf;
		title "Predicting &yvar - PARED DOWN MODEL WITH JUST &mod x behav_wk";
	run;

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive tx z&mod|torytime / solution 
			ddfm=kr;
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

/* How do they covary*/
*Clear Results Viewer;

%macro covar(xvar=, yvar=);

	options nosource nonotes;
	
	ods html5 style=htmlblue 
		path='Y:\Box\01 - CLEAR Lab Data & Analyses\myfolders\BATA2021\' file="%sysfunc(today(), yymmddd10.) - BATA2021 - trait state assoc of &xvar with &yvar - traj trait zm zd ol rem - cov age bmi OC sex .html";

	proc mixed data=bata_p_pp_olrem covtest;
		class subject_id tx (ref="MBCT") female (ref=first) progestin_iud (ref=first) 
			oralcontraceptive (ref=first);
		model &yvar=female zage zbmi oralcontraceptive z&xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi oralcontraceptive tx behav_wk z&xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk z&xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi oralcontraceptive tx|behav_wk z&xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi oralcontraceptive tx TORYTIME z&xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME z&xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi oralcontraceptive tx|TORYTIME z&xvar.m &xvar.d/ solution ddfm=kr;
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
			ddfm=kr;
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
			solution ddfm=kr;
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
			solution ddfm=kr;
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
			solution ddfm=kr;
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
			solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|behav_wk/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|behav_wk &xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|behav_wk/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|behav_wk &xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|torytime/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|torytime &xvar.m &xvar.d/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|torytime/ solution ddfm=kr;
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
		model &yvar=female zage zbmi tx|torytime &xvar.m &xvar.d/ solution ddfm=kr;
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