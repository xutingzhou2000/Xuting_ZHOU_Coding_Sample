****This do file performs the following:
**** 1) Import and clean 3 imperfect datasets: Demographics, Assets, Depression data in the raw data folder.
**** 2) Generate a cleaned dataset that will be used for data exploration and analysis.




* Set working directory:
global folder  "C:/Users/Victoria/OneDrive/文档/GitHub/DIL_task_2024"
    include   "${folder}/main.do"



*/--------------------------------------------------------------------------------*/
	*00. This program takes all missing value codes and turn them into proper stata
	//  missing value codes 
*/------------------------------------------------------------------------------*/

qui {
cap program drop cleaning_missing 
cap program define  cleaning_missing // 
	qui {
		foreach var of varlist _all {
            // Check if the variable is numeric
            capture confirm numeric variable `var'
            if _rc == 0 {  // If the variable is numeric, _rc will be 0
                // Replace -999 with Stata's numeric missing value indicator
                replace `var' = . if inlist(`var', -99, -88, -8, -7, 9999)
            }
      		else {
                // For string variables, replace common text missing value indicators
                // Convert variable to lowercase to ensure case-insensitive matching
                capture confirm string variable `var'
                if _rc == 0 {
                    foreach missingValue in "" "NA" {
                        replace `var' = "" if lower(`var') == "`missingValue'"
                    }
                }
            }
        }
		}	
	end
}	


*/--------------------------------------------------------------------------------*/
	*01. This program detect outliers
*/------------------------------------------------------------------------------*/
qui {
cap program drop detect_outliers
program detect_outliers
    * Loop over all variables
    foreach var of varlist _all {
        * Check if the variable is numeric since outlier detection doesn't apply to strings
        capture confirm numeric variable `var'
        if _rc == 0 {
            * Calculate IQR and bounds for outliers
            summarize `var', detail
            local Q1 = r(p25)
            local Q3 = r(p75)
            local IQR = `Q3' - `Q1'
            local lower_bound = `Q1' - 1.5 * `IQR'
            local upper_bound = `Q3' + 1.5 * `IQR'
            
            * Count outliers
            count if `var' < `lower_bound' | `var' > `upper_bound'
            
            * Report findings
            if r(N) > 0 {
                display "Variable `var' has " r(N) " outliers (Lower bound: `lower_bound', Upper bound: `upper_bound')"
            }
        }
    }
end
}	



*/--------------------------------------------------------------------------------*/
	*02. Import, clean, and recode data. 
*/------------------------------------------------------------------------------*/

use "${data}/raw/mother_survey.dta",clear
keep if n_children > 0 //drop if the suveryed participant has no children
sort village_id mother_id
cleaning_missing


foreach var of varlist sex_1-sex_6 {
  replace `var' = "0" if `var' == "Male" | `var' == "M" | `var' == "male"
  replace `var' = "1" if `var' == "Female" | `var' == "F" | `var' == "female"
}


*/--------------------------------------------------------------------------------*/
    *03. Check for duplicates
*/------------------------------------------------------------------------------*/


egen new_ID_var_temp = group(village_id mother_id)
duplicates report new_ID_var_temp
duplicates list new_ID_var_temp

br if new_ID_var_temp == 39
br if new_ID_var_temp == 108
br if new_ID_var_temp == 114

drop if new_ID_var_temp == 39 & age_1 ==. // one of the duplicates has no value. Drop the one with no value.
duplicates drop new_ID_var_temp, force // both duplicates for 108 and 114 have values. Drop any would be fine.
duplicates report

*/--------------------------------------------------------------------------------*/
    *04. Tidy by reshaping
*/------------------------------------------------------------------------------*/


reshape long age_ sex_ in_school_ yob_ grade_, i(village_id mother_id) j(child_id) string
drop new_ID_var_temp

*/--------------------------------------------------------------------------------*/
    *05. Rename and labelling
*/------------------------------------------------------------------------------*/

destring sex_, gen(child_sex)
drop sex_
label variable child_sex "Child sex"
label define child_sex_label 0 "Male" 1 "Female"
label values child_sex child_sex_label


rename age_ child_age
rename yob_ child_yob
rename grade_ child_grade
rename in_school_ child_in_school

rename educ mother_educ
rename age mother_age
rename yob mother_yob
rename n_children mother_n_children

recast double child_in_school
recast double child_sex

label variable mother_educ "Mother years of education"
label variable mother_age "Mother age"
label variable mother_yob "Mother birthyear"
label variable mother_n_children "Mother num children"
label variable mother_income "Mother income"


label variable child_age "Child age"
label variable child_yob "Child birthyear"
label variable child_grade "Child school grade"
label variable child_in_school "Child is in school"

label variable village_id "village id"
label variable mother_id "mother_id"
label variable child_id "child_id"

*/--------------------------------------------------------------------------------*/
    *06. Missing value generation and replacement
*/------------------------------------------------------------------------------*/

//replace missing values of mother incomes by the median income for a given education level
bysort mother_educ: egen median_income_temp = median(mother_income)
replace mother_income = median_income_temp if missing(mother_income)
drop median_income_temp

//replace missing values of mother year of birth by calculating from the age and the year of survey (2022)
local year_survey 2022
gen mother_yob_temp = `year_survey' - mother_age
replace mother_yob = mother_yob_temp if missing(mother_yob)
drop mother_yob_temp


//replace missing values of child year of birth by calculating from the age and the year of survey (2022)
drop if child_age == . & child_yob == .

local year_survey 2022
gen child_yob_temp = `year_survey' - child_age
replace child_yob = child_yob_temp if missing(child_yob)
drop child_yob_temp


*/--------------------------------------------------------------------------------*/
    *07. Suspicious Values
*/------------------------------------------------------------------------------*/
// A child born after year of survey is suspicious
br if child_yob >2022


// Check for any incorrect entries in the child's grade.
// A grade value higher than the survey year is suspect
// unless it's a case of a child being exceptionally advanced and skipping grades

gen check_year_temp = child_yob + child_grade
sum check_year_temp
br if check_year_temp > 2022



// An infant with age 0-1 who is in school is suspicious. It could be missed reporting. 
gen suspicious_grade_temp = 0
replace suspicious_grade_temp = 1 if (child_age == 0|child_age == 1) & child_in_school ==1
br if suspicious_grade_temp == 1
drop if suspicious_grade_temp == 1



// For this analysis, suspicious data will be removed.
// However, in an actual scenario, this should be cross-verified with the data collector to understand
// if it represents a special kindergarten program for infants in that region.

*/--------------------------------------------------------------------------------*/
    *08. Outliers
*/------------------------------------------------------------------------------*/
*detect_outliers
keep if inrange(mother_income, r(p1), r(p99)) 


save "${data}/clean/cleaned_data.dta", replace

