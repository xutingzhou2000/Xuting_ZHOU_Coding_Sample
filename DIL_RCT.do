////////////////////////This part performs the following:////////////////////

**** 1) Import data and clean it
**** 2) Run regressions
**** 3) Make LaTeX tables and graphs for the paper
////////////////////////////////////////////////////////////////////////////

clear all
cap log close  
set more off        
set mem 100m  

    local researcher = "Anonymous"

    if  "`researcher'"== "Anonymous" {
        global github   "C:\Users\Anonymous\OneDrive\文档\GitHub"
        global box      "C:\Users\username\Box\project-folder"
    }

    else if researcher == "username" {
        global box      "C:\Users\username\Box\project-folder"
        global github   "C:\Users\username\GitHub\dil-template-repo"
    }



////////////////////////This part performs the following:////////////////////
**** 1) Import data and transform to dta file
**** 2) Merge to create one panel dataset
**** 3) Remove duplicates and other 
////////////////////////////////////////////////////////////////////////////
clear all
cap log close  
set more off        
set mem 100m  
set seed 2000410
* Set working directory:
cd "${github}\data"

* Import CSV files
import delimited schools.csv, clear
save schools.dta, replace
import delimited school_visits_log.csv, clear
save school_visits_log.dta, replace
import delimited student_baseline.csv, clear
save student_baseline.dta, replace
import delimited student_follow_ups.csv, clear
save student_follow_ups.dta,  replace

* Merge school-level data with school visit logs
use schools.dta
merge 1:m school_id using school_visits_log.dta

* Check for merge issues
tab _merge
drop if _merge != 3
drop _merge
save school_merged.dta, replace

* Load the follow-up data
use student_baseline.dta, clear
sort student_id 

* check duplicates
duplicates report student_id 
duplicates drop student_id , force
merge 1:m student_id using student_follow_ups.dta

* Check for any merge issues
tab _merge
drop if _merge == 2
drop _merge
* Save the merged data
save student_panel.dta, replace


* Load the school data
use school_merged.dta, clear

* Sort the data by school_id since it should be the unique identifier in this dataset
sort school_id

* Now load the student panel data
use student_panel.dta, clear
sort school_id student_id year

* Merge the student panel data with the school data
merge m:1 school_id year using school_merged.dta

* Check for merge issues
tab _merge
drop if _merge == 2
drop _merge

* Recode -99 to missing for variables where -99 indicates unavailable information
foreach var in av_teacher_age av_student_score n_latrines{
    recode `var' (-99 = .)
}
foreach var in died married children pregnant dropout {
    replace `var' = "." if `var' == "NA"
}
destring died married children pregnant dropout, replace
foreach var in died married children pregnant dropout {
    replace `var' = . if `var' == -99
}

foreach var in yob {
    replace `var' = . if `var' == 9999
}
*only keeps those who are known to be alive
keep if died==0


save final_panel_data.dta, replace


////////////////////////This part performs the following:////////////////////
**** 1) Explore dataset& Create descriptive statistic table for LaTex
**** 2)  Create descriptive statistic table for LaTex
**** 3)  Evaluate the program : ATE
////////////////////////////////////////////////////////////////////////////
clear all
cap log close  
set more off        
set mem 100m  
set seed 2000410
* Set working directory:
cd "${github}"
use "${box}/final_panel_data.dta" 



//Statistics for general data (number of schools, students, districts, stratums in the study)
distinct school_id
distinct student_id
distinct district
distinct stratum
* Change "2" to "0" in the location variable to represent rural
replace location = 0 if location == 2
tab location
tab treatment

//Create a latex Table1 format to plug in the above values
file open myfile using Table1.txt, write replace
file write myfile "\begin{table}[!htbp]\centering\caption{Counts of Distinct Values}\label{tab:distinct_counts}\begin{tabular}{lc}\toprule" _n
file write myfile "Variable & Count \\\ \midrule" _n
file write myfile "School Numbers & `num_school' \\\ " _n
file write myfile "Student Numbers & `num_students' \\\ " _n
file write myfile "Districts v & `num_district' \\\ " _n
file write myfile "Strata Numbers& `num_stratum' \\\ " _n
file write myfile "Urban Ratio & `' \\\ " _n
file write myfile "Treatment Ratio & `' \\\ " _n
file write myfile "\bottomrule\end{tabular}\end{table}" _n
file close myfile

//Statistics for school baseline data
tabout treatment using Table2.txt, ///
c(mean n_teachers mean n_teachers_fem mean n_students_fem mean n_students_male mean n_schools_2km mean av_teacher_age mean av_student_score mean n_latrines) ///
f(2) ///
clab(n_teachers n_teachers_fem n_students_fem n_students_male n_schools_2km av_teacher_age av_student_score n_latrines) ///
sum npos(tufte) ///
rep ///
style(tex)  ///
botstr(final_panel_data.dta)

//Statistics for student data
tabout treatment using Table2.txt, ///
c(mean n_teachers mean n_teachers_fem mean n_students_fem mean n_students_male mean n_schools_2km mean av_teacher_age mean av_student_score mean n_latrines) ///
f(2) ///
clab(n_teachers n_teachers_fem n_students_fem n_students_male n_schools_2km av_teacher_age av_student_score n_latrines) ///
sum npos(tufte) ///
rep ///
style(tex)  ///
botstr(final_panel_data.dta)


* Perform balance test by treatment group (There seems to be a non-random assignment based on stratums)
ttest stratum, by(treatment)  //Pr(|T| > |t|) = 0.0397  
ttest district, by(treatment) //   Pr(|T| > |t|) = 0.3140   
ttest location, by(treatment) //   Pr(|T| > |t|) = 0.0000    
ttest female_head_teacher , by(treatment)  //   Pr(|T| > |t|) = 0.0138  
ttest av_student_score , by(treatment) //Pr(|T| > |t|) = 0.0000 
ttest n_latrines , by(treatment) //Pr(|T| > |t|) = 0.0000 
ttest sex, by(treatment)  //Pr(|T| > |t|) = 0.1278

* ATE for the whole cohort
est clear
***ATE on dropout after 3 years
bysort treatment: sum dropout if year==3
ttest dropout if year==3, by(treatment) 
reg dropout treatment if year==3, cluster (stratum) 
est sto a

***ATE on dropout after 5 years
bysort treatment: sum dropout if year==5
ttest dropout if year==5, by(treatment) 
reg dropout treatment if year==5, cluster (stratum) 
est sto b

***ATE on marriage after 3 years
bysort treatment: sum married if year==3
ttest married if year==3, by(treatment) 
reg married treatment if year==3, cluster (stratum) 
est sto c

***ATE on marriage after 5 years
bysort treatment: sum married if year==5
ttest married if year==5, by(treatment) 
reg married treatment if year==5, cluster (stratum) 
est sto d

***ATE on pregnancy/partner pregnancy after 3 years
bysort treatment: sum pregnant if year==3
ttest pregnant if year==3, by(treatment) 
reg pregnant treatment if year==3, cluster (stratum) 
est sto e

***ATE on pregnancy/partner pregnancy after 5 years
bysort treatment: sum pregnant if year==5
ttest pregnant if year==5, by(treatment) 
reg pregnant treatment if year==5, cluster (stratum) 
est sto f


estout a b c d e f using Table3.txt, label style(tex) replace cells(b(star fmt(3)) se(fmt(3) par(\emph{( )}))) collabels(, none) posthead(\hline)prefoot()postfoot("\hline \hline""\end{tabular*}""\footnotesize $^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01""\end{center}") starlevels($^{*}$ 0.10 $^{**}$ 0.05 $^{***}$ 0.01)

eststo clear

* ATE for the female cohort
***ATE on dropout after 3 years
bysort treatment: sum dropout if year==3&sex==2
ttest dropout if year==3&sex==2, by(treatment) 
reg dropout treatment if year==3&sex==2, cluster (stratum) 
est sto a

***ATE on dropout after 5 years
bysort treatment: sum dropout if year==5&sex==2
ttest dropout if year==5&sex==2, by(treatment) 
reg dropout treatment if year==5&sex==2, cluster (stratum) 
est sto b

***ATE on marriage after 3 years
bysort treatment: sum married if year==3&sex==2
ttest married if year==3&sex==2, by(treatment) 
reg married treatment if year==3&sex==2, cluster (stratum) 
est sto c

***ATE on marriage after 5 years
bysort treatment: sum married if year==5&sex==2
ttest married if year==5&sex==2, by(treatment) 
reg married treatment if year==5&sex==2, cluster (stratum) 
est sto d

***ATE on female pregnancy after 3 years
bysort treatment: sum pregnant if year==3&sex==2
ttest pregnant if year==3&sex==2, by(treatment) 
reg pregnant treatment if year==3&sex==2, cluster (stratum) 
est sto e

***ATE on female pregnancy after 5 years
bysort treatment: sum pregnant if year==5&sex==2
ttest pregnant if year==5&sex==2, by(treatment) 
reg pregnant treatment if year==5&sex==2, cluster (stratum) 
est sto f


estout a b c d e f using Table4.txt, label style(tex) replace cells(b(star fmt(3)) se(fmt(3) par(\emph{( )}))) collabels(, none) posthead(\hline)prefoot()postfoot("\hline \hline""\end{tabular*}""\footnotesize $^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01""\end{center}") starlevels($^{*}$ 0.10 $^{**}$ 0.05 $^{***}$ 0.01)

eststo clear

***Sometimes age could be a factor that affects marriage/pregnancy status
***generate age when the surveys were conducted
gen age = 2012- yob
sum age
gen age2 = 2015- yob
sum age2

reg pregnant treatment age if year==3, cluster (stratum) 
reg pregnant treatment age2 if year==5, cluster (stratum) 


***generate graphs to illustrate the difference between treatment and control group at year=3 and year=5
gen dropout_ratio_year3C = sum(dropout == 1 & year == 3 & treatment == 0) / sum(year == 3 & treatment == 0)
gen dropout_ratio_year3T = sum(dropout == 1 & year == 3 & treatment == 1) / sum(year == 3 & treatment == 1)

graph bar dropout_ratio_year3C dropout_ratio_year3T, ///
    title("Ratio of Dropout Rates by Treatment Group for Year 3", size(medium)) ///
    ylabel(0 0.15, grid) ///
    legend(order(1 "Control" 2 "Treatment") pos(1) size(small))
graph export "dropout_ratio_year3.png", replace
    


gen dropout_ratio_year5C = sum(dropout == 1 & year == 5& treatment == 0) / sum(year == 5 & treatment == 0)
gen dropout_ratio_year5T = sum(dropout == 1 & year == 5 & treatment == 1) / sum(year == 5 & treatment == 1)

graph bar dropout_ratio_year5C dropout_ratio_year5T, ///
    title("Ratio of Dropout Rates by Treatment Group for Year 5", size(medium)) ///
    ylabel(0 0.15, grid) ///
    legend(order(1 "Control" 2 "Treatment") pos(1) size(small)) 
graph export "dropout_ratio_year5.png", replace

log using "./logfile.txt",replace
