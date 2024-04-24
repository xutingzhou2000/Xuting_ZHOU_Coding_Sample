****This do file performs the following:
**** 1) Data exploration and analysis.
**** 2) RCT evaluation


* Set working directory:
global folder        "C:/Users/Victoria/OneDrive/文档/GitHub/DIL_task_2024"
    include   "${folder}/main.do"

use "${data}/clean/cleaned_data.dta", clear

//drop temp variables
drop check_year_temp suspicious_grade_temp

*/--------------------------------------------------------------------------------*/
    *01. Make a summary table across all the variables in the dataset. 
*/------------------------------------------------------------------------------*/
eststo clear
local vlist mother_educ mother_income mother_age mother_yob mother_n_children child_age child_yob child_sex child_grade

eststo all: estpost summarize `vlist', detail
esttab all using "${output}/raw/describe_stats.tex", replace ///
    label style(tex) ///
    cells("count(pattern(0) fmt(0) label(Obs)) mean(pattern(1) fmt(2) label(Mean)) p50(pattern(1) fmt(2) label(Median)) sd(pattern(1) fmt(2) label(SD)) max(pattern(1) fmt(1) label(Max)) min(pattern(1) fmt(1) label(Min))") ///
    mlabels("All") ///
    title(Descriptive Statistics) ///
    collabels(none)

*/--------------------------------------------------------------------------------*/
    *02. Balance check for child in school outcome variable
    // This is different from a usual balance test for treatment arms.
*/------------------------------------------------------------------------------*/
eststo clear
local vlist mother_educ mother_income mother_age mother_n_children child_age child_sex
iebaltab `vlist', grpvar(child_in_school) ///
          stats(desc(var) pair(p)) replace ///
          savecsv("${output}/raw/sum_stats.csv") savexlsx("${output}/raw/sum_stats.xlsx") ///
          savetex("${output}/raw/sum_stats.tex") texnotefile("${output}/raw/sum_stats_note.tex")

//The p-value for child_age is small, suggesting it may be a confounding factor.


*/--------------------------------------------------------------------------------*/
    *03. Regression
*/------------------------------------------------------------------------------*/


xtile mother_income_quartile = mother_income, nq(4)
label define mother_income_quartile 1 "Lowest Quartile" 2 "Lower Middle Quartile" 3 "Upper Middle Quartile" 4 "Highest Quartile"
label values mother_income_quartile mother_income_quartile

xtile mother_educ_quartile = mother_educ, nq(4)
label define mother_educ_quartile 1 "Lowest Quartile" 2 "Lower Middle Quartile" 3 "Upper Middle Quartile" 4 "Highest Quartile"
label values mother_educ_quartile mother_educ_quartile

xtile child_age_quartile = child_age, nq(4)
label define child_age_quartile 1 "Lowest Quartile" 2 "Lower Middle Quartile" 3 "Upper Middle Quartile" 4 "Highest Quartile"
label values child_age_quartile child_age_quartile


eststo clear
*********Baseline linear robust SE*********
reg child_in_school mother_educ child_age, r
est sto a
*********Baseline logit robust SE*********
logit child_in_school mother_educ child_age, r
est sto b
*********Baseline probit robust SE*********
probit child_in_school mother_educ child_age, r
est sto c
*********linear with income as control*********
reg child_in_school mother_educ child_age i.mother_income_quartile , r
est sto d
*********linear with mother age as control*********
reg child_in_school mother_educ child_age mother_age, r
est sto e
*********linear with mother age as control*********
reg child_in_school mother_educ child_age mother_n_children, r
est sto f
*********linear with child sex as control*********
reg child_in_school mother_educ child_age child_sex, r
est sto g
*********linear cluster by village*********
reg child_in_school mother_educ child_age , cluster(village_id)
est sto h



estout a b c d using "${output}/raw/Table1.txt", label style(tex) replace cells(b(star fmt(3)) se(fmt(3) par(( )))) ///
collabels(, none) mlabels(, none) msign(-) nolz varwidth(20) modelwidth(13) ///
prehead("\begin{table}[hbt!]" "\caption{Regression Result}""\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc}" "\hline \hline" "&(1) &(2)&(3)&(4)\\") ///
posthead(\hline) prefoot(\hline) postfoot() starlevels($^{*}$ 0.10 $^{**}$ 0.05 $^{***}$ 0.01) ///
stats(r2 N, fmt(%9.3f %9.0f) labels("R$^2$" "Observations")) nonumbers

estout e f g h using "${output}/raw/Table1.txt", label style(tex) append cells(b(star fmt(3)) se(fmt(3) par(( )))) ///
collabels(, none) mlabels(, none) msign(-) nolz varwidth(20) modelwidth(13) ///
prehead("\hline \hline" "&(5) &(6)&(7)&(8)\\")  posthead(\hline) prefoot(\hline) ///
postfoot("\hline \hline""\end{tabular*}""\footnotesize" "$^{*}$ p$<$0.10, $^{**}$ p$<$0.05, $^{***}$ p$<$0.01\\""" "\end{table}") ///
starlevels($^{*}$ 0.10 $^{**}$ 0.05 $^{***}$ 0.01) stats(r2 N, fmt(%9.3f %9.0f) labels("R$^2$" "Observations")) nonumbers
eststo clear



*********If time allows, I can also report on quatile*********
//reg child_in_school i.mother_educ_quartile c.child_age, r

*/--------------------------------------------------------------------------------*/
    *04. Matching
*/------------------------------------------------------------------------------*/

*********If time allows, I can also report on matching*********

*tabulate child_age, generate(child_age)
tabulate mother_educ_quartile, generate(mother_educ_quartile)
tabulate child_age_quartile, generate(child_age_quartile)


foreach var in mother_educ_quartile1 mother_educ_quartile2 mother_educ_quartile3 mother_educ_quartile4 {
    teffects psmatch (child_in_school) (`var' child_age)
}


foreach var in child_age_quartile1 child_age_quartile2 child_age_quartile3 child_age_quartile4 {
    teffects psmatch (child_in_school) (`var' mother_educ_quartile)
}



*/--------------------------------------------------------------------------------*/
    *05. Make a box plot of the percentage of children enrolled in school by gender
*/------------------------------------------------------------------------------*/

bys child_sex: egen child_in_school_sex = mean(child_in_school)

* Create a bar graph of the mean enrollment by gender
graph bar (mean) child_in_school, over(child_sex, gap(50) label(labsize(small) alternate)) ///
blabel(bar, position(outside) format(%9.2f)) ///
ylabel(0(0.1)0.6, format(%9.0g) grid) ///
ytitle("Mean Percentage Enrolled") ///
title("Percentage of Children Enrolled in School by Gender") ///
bar(2, fcolor(blue*0.7) lcolor(none)) /// Adjust the bar color and transparency
plotregion(color(white)) scheme(s2color)
graph export "${output}/raw/school_gender_bar.png", as(png) replace


* Create a box plot with child_age on the y-axis and child_sex on the x-axis
bys child_age : egen child_in_school_by_age = mean(child_in_school)

graph box child_in_school_by_age, over(child_in_school) over(child_sex) ///
title("Distribution of School Enrollment by Age and Gender") ///
ytitle("Mean Percentage Enrolled") ///
legend(label(1 "Not Enrolled") label(2 "Enrolled")) ///
scheme(s2color)
graph export "${output}/raw/school_gender_box.png", as(png) replace
