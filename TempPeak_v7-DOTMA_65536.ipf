#pragma rtGlobals=1		// Use modern global access method.

Function lorentzian(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = y0+A*gamma/(Pi*((x-x0)^2+gamma^2))
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 4
	//CurveFitDialog/ w[0] = y0
	//CurveFitDialog/ w[1] = gamma
	//CurveFitDialog/ w[2] = x0
	//CurveFitDialog/ w[3] = A

	return w[0]+w[3]*w[1]/(Pi*((x-w[2])^2+w[1]^2))
End

Function LorPeakFit(SpectrumName, PeakName, PointStart, PointEnd)
string SpectrumName, PeakName
variable PointStart,PointEnd
wave spectrum=$SpectrumName
NVAR g_ppmstart, g_ppmend


	Make/D/N=4/O W_coef, W_sigma
		//Initializes W_coef, W_sigma
	W_coef[0]=0.05e6
	//assumes the baseline is 0.1e6
	
	if(cmpstr(PeakName,"DSS")==0)
		FindPeak/R=(PointStart,PointEnd) /M=10e6 spectrum
		
		elseif(cmpstr(PeakName,"W")==0)
			FindPeak/R=(PointStart,PointEnd) /M=50e6 spectrum
		
		elseif(cmpstr(PeakName,"W2")==0)
			FindPeak/R=(PointStart,PointEnd) /M=1.0e6 spectrum
		//	W_coef[0]=0.3e6
			//for troublesome baselines in the vicinity of the DSS tube's residual water peak
		//	W_coef[1]=.002
			//This should be a fairly narrow line
			
				
		elseif(cmpstr(PeakName,"CH3")==0)
			FindPeak/R=(PointStart,PointEnd) /M=1e6 spectrum
		
		else
			FindPeak/B=15/R=(PointStart,PointEnd) /M=0.14e6 spectrum
	endif			
		//Finds the PeakName's approximate max


	W_coef[1]=abs(V_PeakWidth)	
		//This should be a fairly narrow line
	W_coef[2]=V_PeakLoc
		//Sets the rough center frequency of the peak
	W_coef[3]=V_PeakVal
		//Sets the amplitude
					
	NVAR g_DSS_shift, g_DSS_shift_err
	if(cmpstr(PeakName,"DSS")==0)
		Variable/G g_shift=0, g_shift_err=0
		//print shift
			//for debugging
//		For difficult DSS fits, edit below
//		W_coef[0]=1e6
			//assumes the baseline is 1e6
//		W_coef[1]=.002
			//This should be a fairly narrow line
//		W_coef[2]=0
			//Sets the rough center frequency of the peak
//		W_coef[3]=2.0e7
			//Sets the amplitude	
			
		elseif(cmpstr(PeakName,"W2")==0)
			Variable/G g_shift=g_DSS_shift, g_shift_err=g_DSS_shift_err
			//print shift
				//for debugging
//			For difficult DSS fits, edit below
			W_coef[0]=0.1e6
				//assumes the baseline is 1e6
			W_coef[1]=.015
				//This should be a fairly narrow line
			W_coef[2]=4.95
				//Sets the rough center frequency of the peak
			W_coef[3]=0.8e7
				//Sets the amplitude		
			
		else
			Variable/G g_shift=g_DSS_shift, g_shift_err=g_DSS_shift_err
			//print shift
				//for debugging
		endif
		
	String/G g_fitname="fit_"+SpectrumName+"_"+PeakName						
		//allows references to the fit, to change color and later move it	
	Make/N=65536/O $g_fitname
	SetScale /I x, g_ppmstart-g_shift, g_ppmend-g_shift, "ppm", $g_fitname
		//sets fit to have the proper scaling
	FuncFit /NTHR=0 lorentzian W_coef spectrum(PointStart, PointEnd) /D=$g_fitname
		//invokes the custom Lorentzian fit, labels fit; results will be referenced to spectrum
		//the wave "spectrum" is shifted post-DSS fit, so all fit values will already be DSS-corrected
	AppendToGraph $g_fitname
		//adds fit to graph for vistual inspection									
	ModifyGraph rgb($g_fitname)=(0,0,0)
		//Makes the fit appear in black
	g_shift=W_coef[2]; g_shift_err=W_sigma[2]
	//print shift
		//for debugging
End


Function TempPeak(SpectrumName, ppmstart, ppmend, repetitions)

	string SpectrumName
		//from user-input, must be declared immediately?
	variable ppmstart, ppmend, repetitions
		//from user-input, to accomodate different bandwidths
	variable/G g_ppmstart, g_ppmend
	g_ppmstart=ppmstart;	g_ppmend=ppmend	
		//allows the BW info to be passed to other functions
	variable i
		//counter for the for loops below
	wave wave0, wave1
		//passes wave0 into the function for parsing

	//***************************************************Parse Experiment*******************************************************
	
	string ParsedName
	variable j
	for(j=0;j<repetitions;j+=1)
		//this for encompasses the rest of the function
	
		sprintf ParsedName, "%s_%02d", SpectrumName, j+1
	//	ParsedName=SpectrumName+"_"+num2str(j+1)
	//	print ParsedName
		Make/O/N=65536 $ParsedName
		wave w=$ParsedName
		w=wave0[65536*j+p]
		
	



	//***********************************************Initialize Storage Waves****************************************************

	
		string WaveLabelList="RunName;DSS_Center;DSS_Center_err;H2_Center;H2_Center_err;H3_Center;H3_Center_err;CH3_Center;CH3_Center_err;W_Center;W_Center_err;W2_Center;W2_Center_err"
		//Make/O/T/N=7 WaveLabels=StringFromList(p,WaveLabelList)
	
		for(i=0;i<13;i+=1)
			string WaveLabel=StringFromList(i,WaveLabelList)
				//picks appropriate name from WaveLabelList
			if(i==0 && !WaveExists($WaveLabel))
				Make/T/N=0 $WaveLabel
				Wave/T/Z tw=$WaveLabel
					//now that $WaveLabel is created, tw can be used to reference it
				Redimension/N=(numpnts(tw)+1) tw
					//resizes tw (WaveLabel) to accomodate latest run
				tw[numpnts($WaveLabel)-1]=ParsedName
					//makes the last entry SpectrumName, specific to RunName (i==0)
			elseif(i==0) 
				wave/T/Z tw=$WaveLabel
				Redimension/N=(numpnts(tw)+1) tw
					//resizes tw (WaveLabel) to accomodate latest run
				tw[numpnts($WaveLabel)-1]=ParsedName
			else
				if(!WaveExists($WaveLabel))
					Make/N=0 $WaveLabel
				endif
			endif
		endfor

	//*****************************************Initial Spectrum Wave Preparation************************************************
	
		string PeakName
			//will be used to differentiate peaks
		Variable PointStart, PointEnd
			//used to choose fit ranges, in ppm
		Wave spectrum=w
			//passes wave into function
		SetScale /I x, g_ppmstart, g_ppmend, "ppm", spectrum 							
			//Sets x-scaling for spectrum wave in ppm, assumes specific bandwidth and point number (8192)
		SetScale d 0,0, "AU", spectrum													
			//Sets units for y-axis, AU from NTNMR
		
		
	//******************************************Initial Graph Preparation*******************************************************
	
		sprintf ParsedName, "%s_%02d", "Plot_"+SpectrumName, j+1
		Display /N=$ParsedName spectrum
			//Generates graph, already scaled, no reference to 0
		sprintf ParsedName, "%s_%02d", SpectrumName, j+1
		Label left "\\u"
			//Makes left axis label look better than "MAU"
		SetAxis/A/R bottom
			//Reverses bottom axis as per standard NMR convention, positive chemical shifts on the left (upfield), 
			//negative chemical shifts of the right (downfield)
	
	//******************************************DSS Peak Find*****************************************************************
		
		PeakName="DSS"
			//Sets PeakName, DSS in this case, for passage to LorPeakFit
		PointStart=.4; PointEnd=-1.3	
			//Sets PointStart and PointEnd for passage to LorPeakFit
		LorPeakFit(ParsedName, PeakName, PointStart, PointEnd)
			//Invokes LorPeakFit to find the DSS Speak
	
	
	//******************************************Reference 0ppm to DSS Center***********************************************
			
		NVAR g_shift, g_shift_err

		if(abs(g_shift)>3)
			variable/G g_DSS_shift=0, g_DSS_shift_err=0
		else
			variable/G g_DSS_shift=g_shift, g_DSS_shift_err=g_shift_err
		endif
				
			SetScale /I x, g_ppmstart-g_DSS_shift, g_ppmend-g_DSS_shift, "ppm", spectrum 	
			 	//Shifts reference of the spectrum
			SVAR g_fitname
				//References the global variable fitname (from LorPeakFit)
			SetScale /I x, g_ppmstart-g_DSS_shift, g_ppmend-g_DSS_shift, "ppm", $g_fitname
				//Shifts DSS fit for visual inspection
			wave w=DSS_Center
			Redimension/N=(numpnts(w)+1) w
				//resizes DSS_Center to accomodate latest run
			w[numpnts(w)-1]=g_DSS_shift
			
			wave w=DSS_Center_err
			Redimension/N=(numpnts(w)+1) w
				//resizes DSS_Center_err to accomodate latest run
			w[numpnts(w)-1]=g_DSS_shift_err
		

	//**********************************************Find Hn peaks**************************************************************
	
		PeakName="W"
			//Sets PeakName, W in this case, for passage to LorPeakFit
		PointStart=5.5; PointEnd=8
			//Sets PointStart and PointEnd for passage to LorPeakFit
		LorPeakFit(ParsedName, PeakName, PointStart, PointEnd)
			//Invokes LorPeaFit to find the DSS Speak	
		wave w=W_Center
		Redimension/N=(numpnts(w)+1) w
			//resizes W_Center to accomodate latest run
		w[numpnts(w)-1]=g_shift
		
		wave w=W_Center_err
		Redimension/N=(numpnts(w)+1) w
			//resizes W_Center_err to accomodate latest run
		w[numpnts(w)-1]=g_shift_err

		PeakName="W2"
			//Sets PeakName, W2 in this case, for passage to LorPeakFit
		PointStart=4.2; PointEnd=5.2
			//Sets PointStart and PointEnd for passage to LorPeakFit
		LorPeakFit(ParsedName, PeakName, PointStart, PointEnd)
			//Invokes LorPeaFit to find the DSS Speak	
		wave w=W2_Center
		Redimension/N=(numpnts(w)+1) w
			//resizes W2_Center to accomodate latest run
		w[numpnts(w)-1]=g_shift
		
		wave w=W2_Center_err
		Redimension/N=(numpnts(w)+1) w
			//resizes W2_Center_err to accomodate latest run
		w[numpnts(w)-1]=g_shift_err

		PeakName="CH3"
			//Sets PeakName, CH3 in this case, for passage to LorPeakFit
		PointStart=-85; PointEnd=-130
			//Sets PointStart and PointEnd for passage to LorPeakFit
		LorPeakFit(ParsedName, PeakName, PointStart, PointEnd)
			//Invokes LorPeaFit to find the DSS Speak
		wave w=CH3_Center
		Redimension/N=(numpnts(w)+1) w
			//resizes CH3_Center to accomodate latest run
		w[numpnts(w)-1]=g_shift
		
		wave w=CH3_Center_err
		Redimension/N=(numpnts(w)+1) w
			//resizes CH3_Center_err to accomodate latest run
		w[numpnts(w)-1]=g_shift_err	
			
		PeakName="H2"
			//Sets PeakName, H2 in this case, for passage to LorPeakFit
		PointStart=95; PointEnd=120
			//Sets PointStart and PointEnd for passage to LorPeakFit
		LorPeakFit(ParsedName, PeakName, PointStart, PointEnd)
			//Invokes LorPeaFit to find the DSS Speak	
		wave w=H2_Center
		Redimension/N=(numpnts(w)+1) w
			//resizes H2_Center to accomodate latest run
		w[numpnts(w)-1]=g_shift
		
		wave w=H2_Center_err
		Redimension/N=(numpnts(w)+1) w
			//resizes H2_Center_err to accomodate latest run
		w[numpnts(w)-1]=g_shift_err
		
		PeakName="H3"
			//Sets PeakName, H3 in this case, for passage to LorPeakFit
		PointStart=60; PointEnd=90
			//Sets PointStart and PointEnd for passage to LorPeakFit
		LorPeakFit(ParsedName, PeakName, PointStart, PointEnd)
			//Invokes LorPeaFit to find the DSS Speak	
		wave w=H3_Center
		Redimension/N=(numpnts(w)+1) w
			//resizes H3_Center to accomodate latest run
		w[numpnts(w)-1]=g_shift
		
		wave w=H3_Center_err
		Redimension/N=(numpnts(w)+1) w
			//resizes H3_Center_err to accomodate latest run
		w[numpnts(w)-1]=g_shift_err
		
	
		
	//**************************************************Save Graph as a Macro********************************************

		sprintf ParsedName, "DoWindow /N /K %s_%02d", "Plot_"+SpectrumName, j+1
		Execute /P ParsedName
		sprintf ParsedName, "%s_%02d", SpectrumName, j+1


	endfor
		//first for, for parsing data
End