#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function avgfit(exptype, filename_root, outputwave_root, soln_num) 	//takes in filename from cpmg experiment,
															//storagewave rootname for aggregate results,
															//and solution number


//************************ wave/variable intialization *****************************************
	string filename_root, outputwave_root, exptype
	variable soln_num

	string avg_wave, err_wave, datawave, timewave
	variable i
	
	avg_wave=filename_root+"_singlefits"
	err_wave=filename_root+"singlefits_err"
	

	Make /O/N=3 $avg_wave, $err_wave
	Make /D/N=3/O W_coef, W_sigma

//************************ end of wave/variable intialization **************************************

//************************ if conditional for invrec, cpmg, se, or none of the above ************

	//***************** CPMG **********************************************************************
	if(cmpstr(exptype,"CPMG")==0)
		
		timewave="CPMG_Tau_"+filename_root	
		
		for(i=1;i<=3;i+=1)		
			datawave="CPMG_"+filename_root+"_W_"+num2str(i)	//names datawave appropriately
			Wave ywave=$datawave, xwave=$timewave				//passes waves to function, with proper names
			CurveFit/NTHR=0 exp ywave /X=xwave /D				//fits datawaves
			Wave xwave=$avg_wave, ywave=$err_wave				//makes active waves the "singlefits" waves
			xwave[i-1]=w_coef[2]; ywave[i-1]=w_sigma[2]				//sets singlefits waves (avg and err) values
		endfor
	
		wavestats xwave											//Gets summary statistics on singlefits waves
		avg_wave=outputwave_root+"avg"							//Makes summary wave names
		err_wave=outputwave_root+"err"
		Wave xwave=$avg_wave, ywave=$err_wave					//Passes summary waves to function
		xwave[soln_num-1]=V_avg; ywave[soln_num-1]=V_sdev		//sets summary waves value

	//****************** INVREC *******************************************************************
	elseif(cmpstr(exptype,"invrec")==0)
	
		timewave="InvRecTau_"+filename_root	
		
		
		for(i=1;i<=3;i+=1)		
			W_coef={0,100e6,2,.1}										//Matches current InvRec function's initial guesses, somewhat simplistic
			datawave="InvRec_"+filename_root+"_W_"+num2str(i)	//names datawave appropriately
			Wave ywave=$datawave, xwave=$timewave				//passes waves to function, with proper names
			FuncFit/NTHR=0 InvRecFit W_coef ywave /X=xwave /D	//fits datawaves
			Wave xwave=$avg_wave, ywave=$err_wave				//makes active waves the "singlefits" waves
			xwave[i-1]=w_coef[3]; ywave[i-1]=w_sigma[3]				//sets singlefits waves (avg and err) values
		endfor
	
		wavestats xwave											//Gets summary statistics on singlefits waves
		avg_wave=outputwave_root+"avg"							//Makes summary wave names
		err_wave=outputwave_root+"err"
		Wave xwave=$avg_wave, ywave=$err_wave					//Passes summary waves to function
		xwave[soln_num-1]=V_avg; ywave[soln_num-1]=V_sdev		//sets summary waves value
	
	//****************** Spin Echo (SE) *******************************************************************		
	elseif(cmpstr(exptype,"SE")==0)
	
		timewave="CPMG_Tau_"+filename_root						//This is a placeholder (identical to CPMG) until SE analysis is properly coded.
		
		for(i=1;i<=3;i+=1)		
			datawave="CPMG_"+filename_root+"_W_"+num2str(i)	//names datawave appropriately
			Wave ywave=$datawave, xwave=$timewave				//passes waves to function, with proper names
			CurveFit/NTHR=0 exp ywave /X=xwave /D				//fits datawaves
			Wave xwave=$avg_wave, ywave=$err_wave				//makes active waves the "singlefits" waves
			xwave[i-1]=w_coef[2]; ywave[i-1]=w_sigma[2]				//sets singlefits waves (avg and err) values
		endfor
	
		wavestats xwave											//Gets summary statistics on singlefits waves
		avg_wave=outputwave_root+"avg"							//Makes summary wave names
		err_wave=outputwave_root+"err"
		Wave xwave=$avg_wave, ywave=$err_wave					//Passes summary waves to function
		xwave[soln_num-1]=V_avg; ywave[soln_num-1]=V_sdev		//sets summary waves value
			
	//******************anything else*******************************************************************		
	else
		print "Experiment type (first called parameter) must be of type \"InvRec\", \"CPMG\", or \"SE\"."
	
	endif
	
End