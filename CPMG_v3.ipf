#pragma rtGlobals=1

function CPMG()


Make /O/N=3 /T NameWave
//Used to store samplename, filename, and experiment type

NameWave[2]="CPMG"

Make /O/N=6 /D ParameterWave
//Used to store number of points

String fitText, filename, samplename,ExpType, id, R1Name, PeakN, PeakName,Timename	
//Various internal strings of the function

Wave wave0, wave1	
//wave0 and wave1 are the default names of the Real and Imag. parts of the NTNMR dataset upon import

Wave LoopT, TauCP												
//Wave that contains Tau values from NTNMR experiment

Variable i, n, Norm, NPeaks, Points1D, Points2D, Points3D						
//Various internal variables of the function

Variable LPoint, RPoint									
//Various internal variables of the function

filename=NameWave[0];
samplename=NameWave[1]
ExpType=NameWave[2]
Points1D=ParameterWave[1];
Points2D=ParameterWave[2];
Points3D=ParameterWave[3]
NPeaks=ParameterWave[5];
//LoopValues=20;
//Points2D=24;
LPoint=4000;
RPoint=4050;

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
//The number of 1D points in the NTNMR file
Prompt Points2D, "How many loop entries are there?"			
//Number of taus in Inversion Recovery
Prompt Points3D, "How many repetitions?"
	DoPrompt "Enter 1D, 2D, 3D number of points", Points1D,  Points2D, Points3D
	if (V_Flag)
		return -1		// User canceled
	endif
ParameterWave[1]=Points1D
ParameterWave[2]=Points2D
ParameterWave[3]=Points3D
Prompt NPeaks, "How many peaks are there?"
	DoPrompt "Enter number of peaks", NPeaks
	//Total number of peaks the user wants to analyze

ParameterWave[5]=NPeaks
Make/O/N =(NPeaks)/D LPeaks, RPeaks							
//Generates two waves carrying the peak edges by indexed value

Make/O/N =(NPeaks)/T PeakNames								
//Generates a string wave named PeakNames

for(i = 1;i <= (NPeaks);i += 1)

	PeakN = num2istr(i)											
	//Facilitates loop
	
	LPoint=LPeaks[i-1]+1											
	//References previous l/rpoint value for a given peak number
	
	RPoint=Rpeaks[i-1]+1											
	//1 is added to directly correspond to NTNMR point index
	
	Peakname=PeakNames[i-1]
	Prompt LPoint, "Which point number is the left edge of peak " + PeakN + "?"
	Prompt RPoint, "Which point number is the right edge of peak " + PeakN + "?"
	Prompt PeakName, "What is this peak's name?"
		DoPrompt "Enter Left and Right limits.  Enter Name", LPoint, RPoint, PeakName
		if (V_Flag)
			return -1		// User canceled
		endif

	LPeaks[i-1]=LPoint-1											
	//Assigns user-entered value to left/right peak wave
	
	RPeaks[i-1]=RPoint-1											
	//1 is subtracted so that Igor chooses the correct point value
	
	PeakNames[i-1]=PeakName
endfor

string SigRname, SigRname_N, SigEName, SigEName_N, graphname
//Internal string(s) used in upcoming for loops

graphname= "CPMG_" + filename
//Tauname="CPMG_"+filename

	
for(n = 0;n<= (NPeaks)-1;n += 1)

	for(i=1;i<=(Points3D);i+=1)
	
		SigRname="CPMG_"+filename+"_"+PeakNames[n]+"_"+num2str(i)						
		//Wave basename with label
	
		//SigRname_N="CPMG_"+filename+"_"+PeakNames[n]+"_N"	+num2str(i)				
		//Wave basename with label
		
		Make/O/N=(Points2D)/D $SigRname
//		Make/O/N=(Points2D)/D $SigRname_N
	
		Wave SigRloop = $SigRname
		//Wave SigRloop_N = $SigRname_N
		SigRloop=area(wave0, LPeaks[n]+p*Points1D+Points2D*Points1D*(i-1),RPeaks[n]+p*Points1D+Points2D*Points1D*(i-1))
		//SigRloop_N=1-SigRloop/mean(SigRloop,Points2D-3,Points2D-1)
		

		endfor
		//end of "i" loop, for repetitions

	//************************* Aggregate Graph Creation ************************************************//

	Timename="CPMG_Tau_"+filename
	Make/O/N=(Points2D)/D $Timename
	Wave Tauname=$Timename
	Tauname=TauCP[i-1]*LoopT*2

	String ListOfWaves, ListOfXWaves

	SigRName="CPMG_"+filename+"_"+PeakNames[n]+"_*"
	printf "%s\r", SigRName
	ListOfWaves=WaveList(SigRName,";","")
	ListofXWaves=WaveList(Timename,";","")
	printf "%s\r", ListOfWaves
	fWaveAverage(ListOfWaves, "",1, 1, "CPMG_"+filename+"_"+PeakNames[n]+"Avg", "CPMG_"+filename+"_"+PeakNames[n]+ "StdDev")
	
	graphname= "CPMG_"+filename
	SigRName= "CPMG_"+filename+"_"+PeakNames[n]+"Avg"
	SigEName= "CPMG_"+filename+"_"+PeakNames[n]+"StdDev"
//	SigRName_N= "CPMG_"+filename+"_"+PeakNames[n]+"Avg_N"
//	SigEName_N= "CPMG_"+filename+"_"+PeakNames[n]+"StdDev_N"
//	printf "%s\r", SigRName_N
//	printf "%s\r", SigEName_N
//	Make/O/N=(Points2D)/D $SigRName_N, $SigEName_N
	Wave SigRLoop=$SigRName
	Wave SigELoop=$SigEName	
//	Wave SigRLoop_N=$SigRName_N
//	Wave SigELoop_N=$SigEName_N
//	SigRLoop_N=1-SigRloop/mean(SigRloop,Points2D-3,Points2D-1)
//	SigELoop_N=1-SigEloop/mean(SigEloop,Points2D-3,Points2D-1)
	

	
	if(n==0)
				
		Display $SigRName vs $Timename as graphname	
		//Initializes plot
		ModifyGraph log(left)=1	
		//Makes plot semilog
		Label left "\f01EchoAmp [A.U.]";DelayUpdate	
		//Axis Labelling
		Label bottom "\f01Time [s]"
		SetAxis/A/E=1 bottom	
		ModifyGraph mode($SigRname)=3
		//Data displays using markers instead of lines between points
		ModifyGraph marker($SigRname)=19
		//Filled circle data marker
		ModifyGraph rgb($SigRname)=(65280,0,0)
		
		if(Points3D>1)
			ErrorBars $SigRName Y,wave=($SigEName,$SigEName)
		endif
		
		Make/D/N=4/O W_coef, W_sigma
		W_coef = {0,300e3,2,.1}	
		if(Points3D>1)
			CurveFit/X=1/NTHR=0 exp $SigRName /X=$Timename /W=$SigEName /I=1 /D /R
		elseif(Points3D==1)
			CurveFit/X=1/NTHR=0 exp $SigRName /X=$Timename  /I=1 /D /R
		endif
		//CurveFit/NTHR=0 exp $SigRName /X=$Timename /W=$SigEName /I=1 /D 
		//FuncFit/H="0000"/NTHR=0 InvRecFit W_coef $SigRname /X=$Timename /W=$SigEName /I=0 /D 
		//FuncFit/H="100"/NTHR=1 ExpDecay W_coef $SigRname_N /X=InvRecTau /D 

		TextBox/C/N=fitResults/A=MT/X=0/Y=0/E/M=0
		sprintf fitText, "\Zr125\JC\f01%s: %s \r %s \M",ExpType,filename,samplename
		AppendText/N=fitResults fitText
		sprintf fitText, "\JL\s('%s') %s Peak \f01 R\B2\M = %.3g ± %.3g s\S-1\M",SigRName, PeakNames[n], W_coef[3],W_Sigma[3]
		//Appends legend with coefficients from curvefit
		AppendText/N=fitResults fitText

	else
	
		AppendToGraph $SigRName vs $Timename
		ModifyGraph mode($SigRname)=3		
		//Data displays using markers instead of lines between points
		ModifyGraph marker($SigRname)=16
		//Filled square data marker
		ModifyGraph rgb($SigRname)=(63488,43776,7424)
	
		if(Points3D>1)
			ErrorBars $SigRName Y,wave=($SigEName,$SigEName)
		endif
		
		W_coef={0,300e3,2,1}	
		if(Points3D>1)
			CurveFit/X=1/NTHR=0 exp $SigRName /X=$Timename /W=$SigEName /I=1 /D /R
		elseif(Points3D==1)
			CurveFit/X=1/NTHR=0 exp $SigRName /X=$Timename  /I=1 /D /R
		endif
		//FuncFit/H="0000"/NTHR=0 InvRecFit W_coef $SigRname /X=$Timename /W=$SigEName /I=0 /D 
		//FuncFit/H="100"/NTHR=1 ExpDecay W_coef $SigRname_N /X=InvRecTau /D 
		sprintf fitText, "\JL\s('%s') %s Peak \f01 R\B2\M = %.3g ± %.3g s\S-1\M",SigRName, PeakNames[n], W_coef[3],W_Sigma[3]
		//Appends legend with coefficients from curvefit
		AppendText/N=fitResults fitText
		
	endif
	//end of Plotting if loop


		//************************ End Graph Creation ***********************************************//


	i=1
	//resets i for use in the next peak's analysis
	endfor
	//end of "n" loop, for different NMR Peaks
	
//AppendToTable R1loop


End