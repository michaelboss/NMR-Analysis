#pragma rtGlobals=1

//***************************USER PROMPTS*****************************************************

function prompts()
//Prompts() asks the users questions regarding the type of experiment, its name,
//and general TNMR file questions in order to setup later analysis

	String fldrSav0= GetDataFolder(1)
	
	//declaring strings and variables for use in other functions
	string filename, samplename, ExpType, PeakN, PeakName			
	variable Points1D, Points2D, Points3D, NPeaks, i, LPoint, RPoint				
	SetDataFolder root:ProcedureWaves
	//NameWave will be used to store samplename, filename, and experiment type
	Make /O/N=3 /T NameWave										
	NameWave[1]="IR"
	//ParameterWave will be used to store number peaks, number of points in acqisition (1D), 
	//number of 2D records (e.g., TI values), and number of repetitions (3D)
	Make /O/N=4 /D ParameterWave									
	
	//Here, we assign the variables to be stored in NameWave and ParameterWave for future access after user input
	filename=NameWave[0]; ExpType=NameWave[1]; samplename=NameWave[2]
	NPeaks=ParameterWave[0];Points1D=ParameterWave[1]; Points2D=ParameterWave[2]; Points3D=ParameterWave[3]

	//Here we ask the base file name (usually a date_##), the kind of sample, and the experiment type. 
	//The filename and experiment type will be used to generated labeled wave names.
	//The sample type will be used in the final graph generation
	Prompt filename, "What is the file name?"							
	Prompt samplename, "What is the type of sample?"					
	Prompt ExpType, "What type of experiment (IR, CPMG, SE, or PGSE)?"						
	DoPrompt "Enter file name and sample name", filename, samplename,ExpType
	if (V_Flag)
		return -1		// User canceled
	endif
	
	NameWave[0]=filename;	NameWave[1]=ExpType; NameWave[2]=samplename

	//Points1D are the number of points in each individual record, always should be a power of 2
	//Points2D is the number of different inversion recovery delays, "TI" in MRI parlance, or the number of spin echo TEs,
	//or the number of "loops" in a CPMG experiment	
	//Points3D is how many times the entire inversion recovery experiment is repeated, usually this is 3
		
	Prompt Points1D, "How many 1D points were in each scan?"						
	Prompt Points2D, "How many different TI, TE, or CPMG loops values are there?"		
	Prompt Points3D, "How many repetitions?"										
	DoPrompt "Enter 1D, 2D, 3D number of points", Points1D,  Points2D, Points3D
	if (V_Flag)
		return -1		// User canceled
	endif
		
	//Now we can assign these user-entered numbers to ParameterWave for future use	
	ParameterWave[1]=Points1D; ParameterWave[2]=Points2D; ParameterWave[3]=Points3D

	//We ask the user how many peaks there are; for aqueous relaxometry of one peak
	//it is a good idea to retain the limits of integration, which will be done shortly
	Prompt NPeaks, "How many peaks are there?"									
	DoPrompt "Enter number of peaks", NPeaks					
	ParameterWave[0]=NPeaks

	//Here we make waves to keep track of the peak edges (entered by the user later on), presently TNMR indices.
	//Future versions might get fancy and pull in the spectral width from the TNMR header enabling entry by frequency,
	//e.g. -10 to +10 Hz (for a centered water peak)		
	Make/O/N =(NPeaks)/D LPeaks, RPeaks							
	
	//Generates a string wave named PeakNames, useful when plotting multiple peaks
	Make/O/N =(NPeaks)/T PeakNames								
	//In this for loop, the user will input the limits of integration for each peak "i", and the peak name
	for(i = 1;i <= (NPeaks);i += 1)								
			
		//Because the peaks haven't been named, the user will be prompted for Peak 1, Peak 2, etc.
		//This will be accomplished by converting the for index "i" into a string so that it can appear as text
		PeakN = num2istr(i)										
	
		//Oftentimes, users will want to use the same limits of integration as they analyze a sample;
		//The following code references previous l/r point value for a given peak number
		//1 is added to directly correspond to the TNMR point index, which starts at 1, not 0 like Igor
		LPoint=LPeaks[i-1]+1; RPoint=Rpeaks[i-1]+1												
		
		//Igor indexing vs. wanting to start with "1" instead of "0" when referring to peaks
		Peakname=PeakNames[i-1]									
		Prompt LPoint, "Which point number is the left edge of peak " + PeakN + "?"
		Prompt RPoint, "Which point number is the right edge of peak " + PeakN + "?"
		Prompt PeakName, "What is this peak's name?"
		DoPrompt "Enter Left and Right limits.  Enter Name", LPoint, RPoint, PeakName
		if (V_Flag)
			return -1		// User canceled
		endif
		//Assigns user-entered value to left/right peak wave
		//1 is subtracted so that Igor chooses the correct point value
		LPeaks[i-1]=LPoint-1; RPeaks[i-1]=RPoint-1; PeakNames[i-1]=PeakName
	endfor
	//We create a string for a new data subfolder
	string DataFolderName="root:Data:'"+NameWave[0]+"_"+NameWave[1]+"'"
	NewDataFolder/O/S $DataFolderName
	//Now we duplicate the Procedure Parameters into a new subfolder
	DataFolderName="root:Data:'"+NameWave[0]+"_"+NameWave[1]+"':ProcedureWaves"
	
	//Can't overwrite datafolders with Duplicate, so Kill exisiting folder, then duplicate
	if(DataFolderExists(DataFolderName))
		KillDataFolder $DataFolderName
	endif
	
	DuplicateDataFolder root:ProcedureWaves, $DataFolderName
	SetDataFolder fldrSav0
	
End

//*********************************** Initialize Data Folder ******************************************************
function InitDataFolder()

String fldrSav0= GetDataFolder(1)
	SetDataFolder root:ProcedureWaves
	
	//We pass the experiment name and peak names
	Wave/T NameWave, PeakNames; 
	//We pass the numeric parameters of the experiment and integration limits
	Wave ParameterWave, LPeaks, RPeaks
//	//We need a few loop counters
//	Variable n, i
	//We create a string to generate a data subfolder name
	String DataFolderName="root:Data:'"+NameWave[0]+"_"+NameWave[1]+"'"
	//We change the folder to store the data waves that we will generate
	SetDataFolder $DataFolderName

End

//**************************** Peak Area Wave Generation ************************************************

function PeakArea()
//This function calculates the area under the curve and generates data waves of the same
	InitDataFolder()
	//We need a few loop counters
	Variable n, i
	//Define some strings
	String RealSignalName
	//Next two wave calls are repetitive, better way to do this?
	//We pass the experiment name and peak names
	Wave/T NameWave, PeakNames; 
	//We pass the numeric parameters of the experiment and integration limits
	Wave ParameterWave, LPeaks, RPeaks

//	String fldrSav0= GetDataFolder(1)
//	SetDataFolder root:ProcedureWaves
//	
//	//We pass the experiment name and peak names
//	Wave/T NameWave, PeakNames; 
//	//We pass the numeric parameters of the experiment and integration limits
//	Wave ParameterWave, LPeaks, RPeaks
//	//We need a few loop counters
//	Variable n, i
//	//We create a string to generate wave names for each peak and each repetition of the experiment, and a data subfolder name
//	string RealSignalName, DataFolderName="root:Data:'"+NameWave[0]+"_"+NameWave[1]+"'"
//	//We change the folder to store the data waves that we will generate
//	SetDataFolder $DataFolderName
	Duplicate/O root:wave0, wave0
	
	//We now begin a loop that will cycle through each of the peaks, indexed by "n"
	for(n=0;n<=(ParameterWave[0])-1;n+=1)
		
		//Now we begin a loop that cycles through the experiment repetitions, indexed by "i"
		for(i=1;i<=(ParameterWave[3]);i+=1)
			
			RealSignalName=NameWave[1]+"_"+NameWave[0]+"_"+PeakNames[n]+"_"+num2str(i)
			//Create a wave with the above name
			Make/O/N=(ParameterWave[2])/D $RealSignalName
			Wave RealSignalWave=$RealSignalName
			RealSignalWave=area(wave0, LPeaks[n]+p*ParameterWave[1]+ParameterWave[2]*ParameterWave[1]*(i-1),RPeaks[n]+p*ParameterWave[1]+ParameterWave[2]*ParameterWave[1]*(i-1))

		endfor
		
	endfor
	
	SetDataFolder fldrSav0
	
End


//***************************** MakeGraphs ****************************************************
function makegraphs()



End

////***************************INVERSION RECOVERY*****************************************************
//function InvRec()
//
//	//Various internal strings of the function
//	String fitText, R1Name, PeakN, PeakName,Timename	
//
//	//wave0 and wave1 are the default names of the Real and Imag. parts of the NTNMR dataset upon import,
//	//Wave will pass them to the function so that they are accessible
//	Wave wave0, wave1	
//
//	//Wave that contains Tau values from NTNMR experiment, has to be manually set by the user
//	//See the "SequenceParameters" table for lists of commonly used inversion delays
//	Wave InvRecTau													
//
//	//Various internal variables of the function
//	Variable i, n, NPeaks, LPoint, RPoint									
//
//	//Internal string(s) used in upcoming for loops
//	string SigRname, SigEName, graphname
//	graphname= "InvRec_" + filename
//
//	//Beginning of a big loop, indexed by "n", the # of peaks	
//	for(n = 0;n<= (NPeaks)-1;n += 1)
//
//		//This for loop is indexed by the number of repetitions
//		//It will create a bunch of waves like:
//		//    InvRec_filename_PeakName_#
//		//where # is the particular repetition (usually 1-3)
//		for(i=1;i<=(Points3D);i+=1)
//	
//			//SigRName will change with each passing of the "i" for loop, with the final number at the end incrementing
//			SigRname="InvRec_"+filename+"_"+PeakNames[n]+"_"+num2str(i)	
//			//Now we make a wave called whatever SigRname has been set to above					
//			Make/O/N=(Points2D)/D $SigRname
//			//Now we need to provide values for the wave, by passing it into the function.
//			//SigRloop is how this function will reference the wave, which external to the function is called SigRname (where that is a string defined above)
//			Wave SigRloop = $SigRname
//			//Let's set what the value of this particular index of the wave is:
//			SigRloop=area(wave0, LPeaks[n]+p*Points1D+Points2D*Points1D*(i-1),RPeaks[n]+p*Points1D+Points2D*Points1D*(i-1))
//
//			//end of "i" loop, for repetitions
//		endfor
//		
//
//		// ********* The above portion of wave generation should remain unchanged
//		// ********* Analysis and graph generation need to have 2 options, fit of averages (original)
//		// ********* and average of fits (preferred)
//
//
//		//************************* Aggregate Graph Generation ************************************************//
//	
//		// ****** This section should be retained, but as an OPTION
//		// ****** for analysis, i.e., this will result in a fit of averages
//		// ****** NOT an average of fits
//		// ****** Perhaps make a separate function?
//
//		//Now we are going to generate some average statistics for the repetitions
//		String ListOfWaves
//		//We are going to use SigRName to create a string to search with a wildcard (i.e., *) at the end
//		SigRName="InvRec_"+filename+"_"+PeakNames[n]+"_*"
//		//printf below is a sanity check, look at history for wildcard SigRName
//		printf "%s\r", SigRName
//		//printf below is a sanity check, look at history for list of waves
//		ListOfWaves=WaveList(SigRName,";","")
//		printf "%s\r", ListOfWaves
//		//fWaveAverage will now generate the average of the waves, and the standard deviation of each point
//		fWaveAverage(ListOfWaves, "",1, 1, "InvRec_"+filename+"_"+PeakNames[n]+"Avg", "InvRec_"+filename+"_"+PeakNames[n]+ "StdDev")
//	
//		//Now we create some strings to reference the GraphName, the real Signal, and the error Signal.  
//		//The format for the last two directly follows the format created in the fWaveAverage call above.
//		GraphName= "InvRec_"+filename
//		SigRName= "InvRec_"+filename+"_"+PeakNames[n]+"Avg"
//		SigEName= "InvRec_"+filename+"_"+PeakNames[n]+"StdDev"
//
//		//Here we pass the wave generated by fWaveAverage into the procedure
//		Wave SigRLoop=$SigRName
//		Wave SigELoop=$SigEName	
//	
//		//Inversion Recovery experiments use logarithmic TI's, so we use a separate wave for the TI's
//		//The generic relaxivity file includes 20 point logarithmic TI waves going out to between 0.1 and 30 seconds
//		//It is assumed that the user will set InvRecTau to be equal to the appropriate TI wave
//		//e.g., "InvRecTau=IR_30"
//		//Long-term change: user-input to select the appropriate TI wave to avoid needless wave creation
//		Timename="InvRecTau_"+filename
//		Make/O/N=(Points2D)/D $Timename
//		Wave Tauname=$Timename
//		Tauname=InvRecTau
//	
//	
//		//This big if loop deals with graph creation and fitting
//		//The first part of it deals with the first peak that is examined (often times, the only one)
//		if(n==0)
//			//Here we create a graph called "graphname", and use a log scale on the x-axis
//			Display $SigRName vs $Timename as graphname	
//			ModifyGraph log(bottom)=1	
//		
//			//Axis Labeling
//			Label left "\f011-M(t)/M\B0\M";DelayUpdate
//			Label bottom "\f01Recovery Time [s]"
//			//Data displays using markers instead of lines between points
//			//Filled circle data marker
//			ModifyGraph mode($SigRname)=3
//			ModifyGraph marker($SigRname)=19
//			//Changes color of markers to red
//			ModifyGraph rgb($SigRname)=(65280,0,0)
//		
//			//If there are 2 or more repetitions, error bars will be attached to each data marker
//			if(Points3D>1)
//				ErrorBars $SigRName Y,wave=($SigEName,$SigEName)
//			endif
//		
//			//We generate waves (standard Igor nomenclature) to contain fit parameters, and to constrain the possible values of those parameters
//			Make/D/N=4/O W_coef, W_sigma
//			Make/T/N=2/O T_constraints
//	
//		
//			//Igor has trouble fitting the inversion recovery equation (InvRecFit) ab initio
//			//It has proven useful to get user input as to what the parameters are roughly
//			//The following code displays the raw data so that the user can input
//			//Amplitude, T1 (look for the zero crossing for rough approximation), and y0 offset
//			variable guess_offset, guess_amplitude, guess_t1
//			guess_offset=w_coef[0]
//			guess_amplitude=w_coef[1]
//			guess_t1=w_coef[3]
//			Prompt guess_offset, "y0?"
//			Prompt guess_amplitude, "A?"
//			Prompt guess_t1, "T1?"
//			DoPrompt "Enter initial guesses", guess_offset, guess_amplitude, guess_t1
//			//Used to generate labelled wavenames
//			if (V_Flag)
//				return -1		// User canceled
//			endif
//			//The previously created fit parameter wave is now populated with these guesses;
//			//the inversion coefficient, B, is hard-coded to be 2 as an intial guess (no need for user input)
//			w_coef[0]=guess_offset
//			w_coef[1]=guess_amplitude
//			w_coef[2]=2
//			w_coef[3]=guess_t1
//
//			//Here we constrain B to be between 1.5 and 2.3;
//			//Ideally this is 2, typicaly values for a composite 180° pulse are 1.9-1.95
//			T_Constraints[0] = {"K2 > 1.5","K2 < 2.3"}
//		
//			//This code deals with fitting the data
//			//The first if is for more than 1 dataset (repetitions)
//			//and uses the standard deviation of the signal to weight the fit
//			if(Points3D>1)
//				FuncFit/X=1/NTHR=0 InvRecFit W_coef  $SigRName /X=$Timename /W=$SigEName /I=1 /C=T_Constraints /D /R
//				//If there is only one dataset, error bars cannot be generated, so there is no weighting used in the fit
//			elseif(Points3D==1)
//				FuncFit/X=1/NTHR=0 InvRecFit W_coef  $SigRName /X=$Timename /C=T_Constraints /D /R
//			endif
//		
//			//********* FUTURE ITERATIONS OF THIS PROCEDURE SHOULD ALLOW FOR AVERAGE OF FITS AND FIT OF AVERAGES ************
//		
//			//Now we add a textbox with the name of the experiment, sample, filename, and fit values.
//			TextBox/C/N=fitResults/A=MT/X=0/Y=0/E/M=0
//			sprintf fitText, "\Zr125\JC\f01%s: %s \r %s \M",ExpType,filename,samplename
//			AppendText/N=fitResults fitText
//			sprintf fitText, "\JL\s('%s') %s Peak \f01 T\B1\M= %.3g ± %.3g s",SigRName, PeakNames[n], W_coef[3],W_Sigma[3]
//			//Appends legend with coefficients from curvefit
//			AppendText/N=fitResults fitText
//			//THESE FIT PARAMETERS SHOULD BE OUTPUTED TO AN APPROPRIATE WAVE
//			//If there are multiple peaks, they will be displayed on the graph generated for the first peak, using "AppendToGraph"
//			//The code here should be modified so that the markers and marker colors are not all the same
//		else
//			AppendToGraph $SigRName vs $Timename
//			ModifyGraph mode($SigRname)=3		
//			//Data displays using markers instead of lines between points
//			ModifyGraph marker($SigRname)=16
//			//Filled square data marker
//			ModifyGraph rgb($SigRname)=(63488,43776,7424)
//		
//			if(Points3D>1)
//				ErrorBars $SigRName Y,wave=($SigEName,$SigEName)
//			endif
//	
//			T_Constraints[0] = {"K2 > 1","K2 < 2.5"}
//			if(Points3D>1)
//				FuncFit/X=1/NTHR=0 InvRecFit W_coef  $SigRName /X=$Timename /W=$SigEName /I=1 /C=T_Constraints /D /R
//			elseif(Points3D==1)
//				FuncFit/X=1/NTHR=0 InvRecFit W_coef  $SigRName /X=$Timename /C=T_Constraints /D /R
//			endif
//
//			sprintf fitText, "\JL\s('%s') %s Peak \f01 T\B1\M= %.3g ± %.3g s",SigRName, PeakNames[n], W_coef[3],W_Sigma[3]
//			//Appends legend with coefficients from curvefit
//			AppendText/N=fitResults fitText
//		
//		endif
//		//end of Plotting if loop
//
//
//		//************************ End Graph Creation ***********************************************//
//
//
//		i=1
//		//resets i for use in the next peak's analysis
//
//	endfor
//	//end of "n" loop, for different NMR Peaks
//	
//	//AppendToTable R1loop
//
//
//End