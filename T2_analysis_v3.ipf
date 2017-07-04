#pragma rtGlobals=1

function T2_analysis()

Make /O/N=3 /T NameWave
//Used to store samplename, filename, and experiment type

Make /O/N=6 /D ParameterWave
//Used to store number of points

String fitText										//This string will be used to display curve-fitting results
												//It may be supplanted by functionality introduced in Igor 6.
								
String filename, SigRname, id, R2Name, PeakN		//These strings will be used to generate wave names for
String Timename, graphname, SigRError			//signal amplitude, etc.
String PeakName, samplename, ExpType
Variable rcolor, gcolor, bcolor						//Used to color graphs									
Variable i, j, n, Norm								//i, j and n are used as counters, Norm is to normalize echo amplitudes


//*********************  Waves Passed TO function (intialize first!) **************************//

Wave wave0, wave1 , LoopT, TauCP					//The real and imaginary signal amplitudes, from FT'd NTNMR file


//**************************************************************************************************//

//********************************** User-Entered Parameters *********************************//
Variable Points1D ,Points2D,Points3D, Points4D
Variable NPeaks,LPoint,RPoint


//***** Initial values *****//
Points1D=2048;									//Number of 1D points (points in each scan)
Points2D=150;									//Number of 2D points (Single run of data, different loop values)
Points3D=1;										//Number of 3D points (different values of tau_CP)
Points4D=16;									//Number of 4D points (repetitions)

NPeaks=1;										//Number of resolved peaks in spectrum
LPoint=2074;										//Left edge of peak, point value from NTNMR
RPoint=2148;									//Right edge of peak, point value from NTNMR

filename=NameWave[0];
samplename=NameWave[1]
ExpType=NameWave[2]
Points1D=ParameterWave[1];
Points2D=ParameterWave[2];
Points3D=ParameterWave[3];
Points4D=ParameterWave[4]
NPeaks=ParameterWave[5];


//**************************//

//**************************************** User Prompts *****************************************//
Prompt filename, "What is the file name?"
Prompt samplename, "What is the type of sample?"
Prompt ExpType, "What type of experiment?"
	DoPrompt "Enter file name and sample name", filename, samplename,ExpType
	//Used to generate labelled wavenames
	if (V_Flag)
		return -1		// User canceled
	endif
NameWave[0]=filename
NameWave[1]=samplename
NameWave[2]=ExpType

Prompt Points1D, "How many 1D points were in each scan?"
Prompt Points2D, "How many loop entries are there?"				//Number of entries are in each loop table
Prompt Points3D, "How many different tau values are there?"			//Number of different Carr-Purcell times in file
	DoPrompt "Enter 1D points, and number of loop entries and tau values", Points1D, Points2D, Points3D
	if (V_Flag)
		return -1		// User canceled
	endif

ParameterWave[1]=Points1D
ParameterWave[2]=Points2D
ParameterWave[3]=Points3D

Prompt Npeaks, "How many peaks are there?"
Prompt Points4D, "How many repetitions?"
	DoPrompt "Enter number of peaks and repetitions", NPeaks, Points4D
	if (V_Flag)
		return -1		// User canceled
	endif
ParameterWave[4]=Points4D
ParameterWave[5]=NPeaks

Make/O/N =(Npeaks)/D LPeaks, RPeaks	//Generates two waves carrying
										//the peak edges by indexed value

Make/O/N =(NPeaks)/T PeakNames

//Execute "R2_Peaks()"										//obsolete?							
										
for(n = 1;n <= (NPeaks);n += 1)

	PeakN = num2istr(n)						//Facilitates loop
	LPoint=LPeaks[n-1]+1					//References previous l/rpoint value for a given peak number
	RPoint=Rpeaks[n-1]+1					//1 is added to directly correspond to NTNMR point index
	Prompt LPoint, "Which point number is the left edge of peak " + PeakN + "?"
	Prompt RPoint, "Which point number is the right edge of peak " + PeakN + "?"
	Prompt PeakName, "What is this peak's name?"
		DoPrompt "Enter Left and Right limits.  Enter Name", LPoint, RPoint, PeakName
		if (V_Flag)
			return -1		// User canceled
		endif
	LPeaks[n-1]=LPoint-1						//Assigns user-entered value to left/right peak wave
	RPeaks[n-1]=RPoint-1					//1 is subtracted so that Igor chooses the correct point value

	PeakNames[i-1]=PeakName
endfor

//********************************** End User Prompts *******************************************//



//********************************* Fit Coefficient Initialization **********************************//

Make /O/N =3/D W_coef, W_sigma			//Creates or overwrites fit parameters waves, 3 entries
W_coef=0								//Resets W_coef to be 0
W_sigma=0								//Resets W_sigma to be 0
K0=0									//artifact?  remove?

//**************************************************************************************************//




		
//***************************** Begin NPeaks for loop ******************************************//

for(n=1;n<=(NPeaks);n+=1)

	PeakN = num2istr(n)					//Facilitates loop


	for(j=1;j<=(Points4D);j+=1)				



	//****************************** Begin Repetition loop ********************************************//

	for(i = 1;i <= (Points3D);i+=1)
	
		//*************************** Plot Colors *******************************************************//
		
		if(i<=4)												//This if loop determines the colors used in a given dataset
			rcolor=0
			gcolor=0
			bcolor=0
		elseif(i<=8)											//Blue
			rcolor=0
			gcolor=0
			bcolor=65535
		elseif(i<=12)											//Cyan
			rcolor=16384
			gcolor=48896
			bcolor=65280
		elseif(i<=16)											//Darkish Green
			rcolor=0
			gcolor=48896
			bcolor=0
		elseif(i<=20)											//Dark Yellow
			rcolor=52224
			gcolor=52224
			bcolor=0
		elseif(i<=24)											//Orange
			rcolor=63488
			gcolor=43776
			bcolor=7424
		elseif(i<=28)											//Red
			rcolor=65535
			gcolor=0
			bcolor=0
		elseif(i<=32)											//Dark Red
			rcolor=39168
			gcolor=0
			bcolor=0							
		endif	
	
		//******************************** End Plot Colors *****************************************//
	
		id = num2istr(i)+"_"+num2istr(j)				//Definition of counter in string form

		//********************************** Wave Creation ******************************************//

		SigRname=filename + "_Peak" + PeakN + "_" + id		//Defines Signal wave name

		if(j==1)
			
			Timename=filename + "_Tau_"+ num2istr(i)
			Make/O/N =(Points2D)/D $Timename;	
			Wave Timeloop = $Timename
			//Timeloop=TimeTable[mod(p,Points2D)+Points2D*(i-1)]
			//Timeloop=TauCP[i-1]*LoopT*2
			Timeloop=TauCP[i-1]*LoopT[p+Points2D*(i-1)]*2
														
			elseif(j>1)
			
				Timename=filename + "_Tau_"+ num2istr(i)
				Wave Timeloop = $Timename
			//	Timeloop=TimeTable[mod(p,Points2D)+Points2D*(i-1)]
				//Timeloop=TauCP[i-1]*LoopT*2
				Timeloop=TauCP[i-1]*LoopT[p+Points2D*(i-1)]*2
		endif
		
		//print SigRname, SigIname, Timename


		Make/O/N =(Points2D)/D $SigRname;					//Makes a wave with the name SigRname
		Wave SigRloop = $SigRname;								
		SigRloop=area(wave0, LPeaks[n-1]+p*Points1D+Points2D*Points1D*(i-1)+Points3D*Points2D*Points1D*(j-1),RPeaks[n-1]+p*Points1D+Points2D*Points1D*(i-1)+Points3D*Points2D*Points1D*(j-1))
	
		//LOffset=LPeaks[n-1]+p*Points1D+Points2D*Points1D*(i-1)+Points3D*Points2D*Points1D*(j-1)
		//ROffset=RPeaks[n-1]+p*Points1D+Points2D*Points1D*(i-1)+Points3D*Points2D*Points1D*(j-1)
	
	
//		Norm=SigRloop[0]									//Signal Amp with no gradient (no spatial encoding)
//		SigRloop=SigRloop/Norm								//Normalization
	
		//**************************** Graph Creation ************************************************//
	
		//This section needs SERIOUS work, make it more in line with
		//t2disp() function used in chemical exchange analysis,
		//so that all plots for given peak appear on same graph, rather than as 
		//individual graphs.  See t2disp() for example code.
	
		graphname=filename+"_Peak"+ PeakN+"_"+ num2istr(j)
	
	if(i==1)														//This if loops plots the data with different colors and markers
			Display SigRloop vs Timeloop as graphname				//Initializes plot
			ModifyGraph log(left)=1								//Makes plot semilog
			Label left "\f01EchoAmp [A.U.]";DelayUpdate		//Axis Labelling
			Label bottom "\f01Time [s]"
			SetAxis/A/E=1 bottom								//Forces x-axis to display 0
			ModifyGraph mode($SigRname)=3						//Data displays using markers instead of lines between points
			ModifyGraph marker($SigRname)=19					//Filled circle data marker
			ModifyGraph rgb($SigRname)=(rcolor,gcolor,bcolor)		//Forces data points to be a certain color
			
		elseif(mod (i,4)==1)
			AppendToGraph SigRLoop vs Timeloop
			ModifyGraph mode($SigRname)=3						//Data marker plot
			ModifyGraph marker($SigRname)=19					//Filled circle data marker
			ModifyGraph rgb($SigRname)=(rcolor,gcolor,bcolor)
			
		elseif(mod (i,4)==2)
			AppendToGraph SigRLoop vs Timeloop
			ModifyGraph mode($SigRname)=3						//Data marker plot
			ModifyGraph marker($SigRname)=16					//Filled square data marker
			ModifyGraph rgb($SigRname)=(rcolor,gcolor,bcolor)
			
		elseif(mod (i,4)==3)
			AppendToGraph SigRLoop vs Timeloop
			ModifyGraph mode($SigRname)=3						//Data marker plot
			ModifyGraph marker($SigRname)=17					//Filled triangle data marker
			ModifyGraph rgb($SigRname)=(rcolor,gcolor,bcolor)

		elseif(mod (i,4)==0)
			AppendToGraph SigRLoop vs Timeloop
			ModifyGraph mode($SigRname)=3						//Data marker plot
			ModifyGraph marker($SigRname)=18					//Filled diamond data marker
			ModifyGraph rgb($SigRname)=(rcolor,gcolor,bcolor)
			
		endif													//end of Plotting if loop

	//************************ End Graph Creation ***********************************************//
		
	R2Name=filename+"_Peak"+PeakN+"_R2_"+num2istr(j)			//Defines R2 wave name for each peak
	Make/O/N=(Points3D) $R2Name								//Make a set of R2 waves, one wave for each peak

	K0=0
//	CurveFit/H="100" exp SigRLoop[0,19] /X=Timeloop /D 			//Curve fits first 20 data points
	CurveFit/H="000" exp SigRLoop /X=Timeloop /D 				
	Wave R2loop = $R2Name										//Allows $R2Name to accept values
	R2loop[i-1]=W_coef[2]
	
	endfor		
												  //ends Tau Loop
AppendToTable R2loop
	//********************************* End Points3D loop **********************************************//

i=1
	endfor //*ends 4D loop


//************************* Aggregate Graph Creation ************************************************//

String ListOfWaves

		SigRName=filename + "_Peak" + PeakN +"_R2_*"
		printf "%s\r", SigRName
		ListOfWaves=WaveList(SigRName,";","")
		printf "%s\r", ListOfWaves
		fWaveAverage(ListOfWaves, "",1, 1, filename + "_Peak" + PeakN +"_R2Avg", filename + "_Peak" + PeakN + "_R2StdDev")
	
		graphname= filename+"_Peak"+ PeakN+"_R2vsTauCP"
		SigRName= filename + "_Peak" + PeakN + "_R2Avg"
		SigRerror= filename + "_Peak" + PeakN +"_R2StdDev"
		Timename=filename + "_TauCP"
		Make/O/N =(Points3D)/D $Timename;
		Wave Timeloop=$Timename
		Timeloop=TauCP
			
		Display $SigRName vs $Timename as graphname				//Initializes plot
		ModifyGraph log(bottom)=1								//Makes plot semilog
		Label left "\f01R\B2\M [s\S-1\M]";DelayUpdate		//Axis Labelling
		Label bottom "\f01\F'Symbol't \B\F'Arial'CP\M [s]"
		ModifyGraph mode($SigRname)=3						//Data displays using markers instead of lines between points
		ModifyGraph marker($SigRname)=19					//Filled circle data marker
		ModifyGraph rgb($SigRname)=(65280,0,0)
		ErrorBars $SigRName Y,wave=($SigRerror,$SigRerror)
		//end of Plotting if loop


		//************************ End Graph Creation ***********************************************//
		
		//************************** Curve Fitting *****************************************************//
//			K0=0
//			CurveFit/H="10000"/NTHR=1 dblexp $SigRName[3,Points2D] /X=$Timename /W=$SigRError /I=1 /D
//			if(i==1)
//				TextBox/C/N=fitResults/A=MT/X=0/Y=0/E/M=0
//				sprintf fitText, "\Zr125\JC\f01%s- Glycerol CPMG_PGSE, Peak %s\Zr080",filename,num2istr(n)
//				AppendText/N=fitResults fitText
//				elseif(i>1)
//			endif
//			sprintf fitText, "\JL\s(%s) \f01\F'Symbol'd\F'Arial'=%.3g ms, D\B1\M = %.3g ± %.3g m\S2\M/s, \f01D\B2\M = %.3g ± %.3g m\S2\M/s",SigRName, delta(i-1)*1e3,W_coef[2],W_Sigma[2],[4],W_Sigma[4]
//			AppendText/N=fitResults fitText
			
			//AppendText/N=fitResults fitText
			//sprintf fitText, "\f01\F'Symbol't\F'Arial'\Be\M = %g ms, \F'Symbol't\F'Arial'\BM\M = %g ms", t_e, t_m

			//************************* End Curve Fitting *************************************************//
	
endfor

//******************************** End NPeaks for loop *******************************************//

End