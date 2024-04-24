/*******************************************************************************
	
						 * Main do-file
						  
/***********FOR THIS TEMPLATE TO WORK CORRECTLY, EDIT THE FILE PATHS IN SECTION 2 TO MATCH YOUR COMPUTER-*/
						  
/*--------------------------------------------------------------------------------*/
	01 Select parts of the code to run (change from 0 to 1 if necessary)
*------------------------------------------------------------------------------*/

	clear all
	cap log close  
	*ssc install iefieldkit, replace 
	*ssc install ietoolkit, replace
	*iefolder new project, projectfolder("$folder")
	local prepare		0
	local analysis  	0


	* Set initial configurations as much as allowed by Stata version
	ieboilstart, v(16.0)
	`r(version)'
	
/*------------------------------------------------------------------------------
	02 Set file paths
------------------------------------------------------------------------------*/

	* Enter the file path to the project folder in Box for every new machine you use
	* Type 'di c(username)' to see the name of your machine
	
	local researcher = "Victoria"

	if  "`researcher'"== "Victoria" {
		global github	"C:/Users/Victoria/OneDrive/文档/GitHub/DIL_task_2024"
	}

	else if researcher == "username" {
		global github	"C://///" //Please replace your working directory here
	}
	
	global	code		"${github}/code"
	global	data		"${github}/data"
	global	doc			"${github}/documentation"
	global	output		"${github}/output"
	
/*------------------------------------------------------------------------------
	03 Initial settings
------------------------------------------------------------------------------*/

	cd ${github}

/*------------------------------------------------------------------------------
	04 Run code
------------------------------------------------------------------------------*/
	if `prepare' {
		
		/*----------------------------------------------------------------------
			Import survey data into Stata format
			
			Requires: "${data}/raw"
			Creates:  "${data}/clean"
		----------------------------------------------------------------------*/
		do "${code}/data_prepare.do"
		
	}
	

	if `analysis' {
		
		/*----------------------------------------------------------------------
			Import survey data into Stata format
			
			Requires: "${data}/clean"
			Creates:  "${output}/raw"
		----------------------------------------------------------------------*/
		do "${code}/data_analysis.do"
		
	}
	

	
	log using "${output}/raw/logfile.txt",replace

************************************************************ End of main do-file
