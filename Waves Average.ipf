#pragma rtGlobals=1		// Use modern global access method.
#pragma version=7.01		// Shipped with Igor 7.01

// Procedure file "Waves Average".
// "Waves Average" is greatly improved over the much older "AverageWaves" procedure file.
//
// The best way to use this procedure file is to type "#include <Waves Average>"
// in your own procedure window, usually the main Procedure window,
// or by choosing the Analysis->Packages->Average Waves menu.
//
// Also see the Wave Arithmetic panel: type "#include <Wave Arithmetic Panel>" in your procedure window,
// or choose the Analysis->Packages->Wave Arithmetic menu.

//*****************************************************
// Version 1.01:
//		Altered fWaveAverage() function to handle waves with NaN's and waves having variable length.
// Version 1.02:
//		Fixed the change made in 1.01: made an average wave only as long as the first wave in the list.
// Version 1.03:
//		X scaling in first wave in wave list provided to fWaveAverage() is copied to the output waves.
// Version 1.04:
//		Append To Graph checkbox was not honored.
//	Version 1.05:
//		If your wave name template was bad, it would try to do the average on zero waves, resulting in a
//			CopyScales failure with a bewildering error message.
//		Changed the default Name Template string to "*"; was "wave*".
//	Version 6.2, JP:
//		Resizing the panel resizes the (newly added) group boxes, removed obsolete include files.
//		Works better with waveforms of varying lengths.
//		For the first time, works with XY pairs, too. In this case the results are inexact because linear interpolation is used.
//	Version 6.21, JP:
//		Averaging Y waves all using the same x wave now uses the point-by-point method.
//	Version 6.22, JP:
//		Fixed fWaveAverage() bug.
//	Version 6.23, JP:
//		fWaveAverage() tolerates "averaging" one wave. The error waves are not computed and not appended to the graph.
//		This affected the panel, too; it warns about one wave, but permits it.
//	Version 6.35, JP:
//		Averaging waveforms with reversed x range uses interpolation
//		instead of averaging the wrong points with the point-to-point averaging algorithm.
//		This could happen if deltaX was inverted along with the x range.
//		The user should have used Reverse on the waveform, but we dare not do that here.
//	Version 6.38, JP:
//		Speed improvements to pointForPoint mode, thanks to Thomas Braun.
//		Print Waves now prints many more details.
//	Version 6.38, JP:
//		Three decreasing X scale waveforms now properly use point-for-point averaging and the result also has decreasing X scale.
//		The output wave is excluded by name from the waves returned by the top graph's traces.
//	Version 7.01, JP:
//		Fixed "index out of range" error due to rounding errors caused by storing X ranges in float (instead of double) wave.
//*****************************************************

#include <Resize Controls>
#include <Wave Lists>

Menu "Analysis"
	"Waves Average Panel", MakeWavesAveragePanel()
end

Proc MakeWavesAveragePanel()

	if (WinType("WaveAveragePanel") == 7)
		DoWindow/F WaveAveragePanel
	else
		InitWaveAverageGlobals()
		f_WaveAveragePanel()
	endif
end

Function InitWaveAverageGlobals()

	String SaveDF = GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O/S WM_WavesAverage
	
	if (Exists("ErrorWaveName") != 2)
		String/G AveWaveName="W_WaveAverage"
	endif
	if (Exists("ErrorWaveName") != 2)
		String/G ErrorWaveName="W_WaveAveError"
	endif
	if (Exists("ListExpression") != 2)
		String/G ListExpression="*"
	endif
	String/G WA_ListOfWaves
	
	if (Exists("nSD") != 2)
		Variable/G nSD=2
	endif
	if (Exists("ConfInterval") != 2)
		Variable/G ConfInterval=95
	endif
	if (Exists("GenErrorWaveChecked") != 2)
		Variable/G GenErrorWaveChecked=1
	endif
	if (Exists("ErrorMenuSelection") != 2)
		Variable/G ErrorMenuSelection=2	// default to confidence interval
	endif
	if (Exists("WavesFromItem") != 2)
		Variable/G WavesFromItem=2
	endif
	if (Exists("AppendToGraphCheckValue") != 2)
		Variable/G AppendToGraphCheckValue=1
	endif
	
	SetDataFolder $SaveDF
end
	
static Function x2pntWithFrac(wv, scaledDim)
	WAVE wv
	Variable scaledDim
	
	Variable pnt= (scaledDim - DimOffset(wv, 0)) / DimDelta(wv,0)
	return pnt	// not rounded
End

Function fWaveAverage(ListOfWaves, ListOfXWaves, ErrorType, ErrorInterval, AveName, ErrorName)
	String ListOfWaves		// Y waves
	String ListOfXWaves		// X waves list. Pass "" if you don't have any.
	Variable ErrorType		// 0 = none; 1 = S.D.; 2 = Conf Int; 3 = Standard Error
	Variable ErrorInterval	// if ErrorType == 1, # of S.D.'s; ErrorType == 2, Conf. Interval
	String AveName, ErrorName
	
	Variable numWaves = ItemsInList(ListOfWaves)
	if (numWaves < 2 )
		ErrorType= 0	// don't generate any errors when "averaging" one wave.
	endif
		
	if ( ErrorType == 2)
		if ( (ErrorInterval>100) || (ErrorInterval < 0) )
			DoAlert 0, "Confidence interval must be between 0 and 100"
			return -1
		endif
		ErrorInterval /= 100
	endif
	
	// check the input waves, and choose an appropriate algorithm
	Variable maxLength = 0
	Variable differentLengths= 0
	Variable differentXRanges= 0
	Variable firstDeltaX=NaN					// 6.35: keep track of common deltaX for waveforms.
	Variable firstLeftX=NaN, firstRightX=NaN	// 6.38: keep track of common left/right x range (use point-by-point averaging if all X scaling is identical).
	Variable differentDeltax= 0	// 6.35: use interpolation if deltax's are different, even if simply reversed in sign.
	Variable thisXMin, thisXMax, thisDeltax
	Variable minXmin, maxXmax, minDeltax
	Variable numXWaves=0
	String firstXWavePath = StringFromList(0,ListOfXWaves)
	Variable XWavesAreSame=1	// assume they are until proven differently. Irrelevant if	numXWaves!=numWaves
	Variable i, tmp
	
//	Make/O/N=(numWaves,2)/FREE xRange	// [i][0] is xMin, [i][1] is xMax
	Make/O/N=(numWaves,2)/D/FREE xRange	// [i][0] is xMin, [i][1] is xMax 7.01: double-precision

	for (i = 0; i < numWaves; i += 1)
		String theWaveName=StringFromList(i,ListOfWaves)
		Wave/Z w=$theWaveName
		if (!WaveExists(w))
			DoAlert 0, "A wave ("+theWaveName+") cannot be found in the list of waves."
			return -1
		endif
		Variable thisLength= numpnts(w)
		String theXWavePath=StringFromList(i,ListOfXWaves)
		Wave/Z theXWave= $theXWavePath
		if( WaveExists(theXWave) )
			Variable isMonotonicX= MonotonicCheck(theXWave,thisDeltax)	// thisDeltax is set to min difference in the x wave
			if( !isMonotonicX )
				DoAlert 0, theXWavePath+" is not sorted (or has duplicate x values) and cannot be used to compute the average. You should sort both "+theXWavePath+" and "+theWaveName+"."
				return -1
			endif
			// TO DO: since we know theXWave is monotonic, why not use the first and last values?
			// That way we could keep the X wave order the same if they're all identical. 
			WaveStats/Q/M=0 theXWave
			thisXMin= V_Min
			thisXMax= V_Max
			numXWaves += 1
			if( CmpStr(theXWavePath,firstXWavePath) != 0 )	//comparing full paths, not wave values
				XWavesAreSame=0
			endif
		else
			thisDeltax= deltax(w)
			thisXMin= leftx(w)
			thisXMax= rightx(w)-thisDeltax	// SetScale/I values.
			XWavesAreSame=0	// at least 1 y wave has no x wave
			// 6.35: point-for-point averaging requires the deltaX of all waves to be identical.
			if( numtype(firstDeltaX) != 0 )
				firstDeltaX = thisDeltaX	// remember first deltaX before abs() below
			elseif( thisDeltax != firstDeltaX )
				differentDeltax= 1	// don't do point-for-point averaging.
			endif
		endif
		xRange[i][0]= thisXMin
		xRange[i][1]= thisXMax
		if( i > 0 )
			if( thisLength != maxLength )
				differentLengths= 1
			endif
//			if( (thisXMin != minXmin) || (thisXMax != maxXmax) )
//				differentXRanges= 1	// this also includes the case where identical ranges but one or more is swapped
//			endif
			// 6.38: point-for-point averaging should be used if the X scaling all waveforms is identical
			// 6.38: compare this wave's X range to the raw (un-swapped) X range
			if( (thisXMin != firstLeftX) || (thisXMax != firstRightX) )
				differentXRanges= 1	// this also includes the case where identical ranges but one or more is swapped
			endif
			if( thisXMin > thisXMax )	// swapped X range (X values decrease with increasing point number)
				tmp= thisXMin
				thisXMin= thisXMax
				thisXMax= tmp
			endif
			// accumulate x ranges keeping minXmin < maxXmax (ascending)
			minXmin= min(minXmin, thisXMin)
			maxXmax= max(maxXmax, thisXMax)
			// find smallest deltax
			thisDeltax= abs(thisDeltax)
			if( thisDeltax > 0 && (thisDeltax < minDeltax) )
				minDeltax= thisDeltax
			endif
		else	// i == 0, initialize most range values to the first wave's X scaling range or the X wave's range.
			minXmin= thisXMin
			maxXmax= thisXMax
			
			// 6.38: the following was added, see the differentXRanges tests above
			firstLeftX=thisXMin		// as reported by leftx() or x wave min.
			firstRightX= thisXMax	// as reported by rightx(w)-thisDeltax or x wave max.

			// 6.38: the following was moved here from an if( i == 1 ) condition above, now deleted.
			// Keep minXmin < maxXmax (ascending)
			if( minXmin > maxXmax )		// swapped X range (X values decrease with increasing point number)
				tmp= minXmin
				minXmin= maxXmax
				maxXmax= tmp
			endif

			minDeltax= abs(thisDeltax)
			if( minDeltax == 0 )
				thisDeltax= inf	// thisDeltax is useless, use the next wave's deltaX, instead.
			endif
		endif
		maxLength = max(maxLength, thisLength)
	endfor
	
	Variable doPointForPoint
	if( numXWaves && !XWavesAreSame )
		doPointForPoint= 0
	else
		doPointForPoint = (!differentXRanges && !differentLengths && !differentDeltax) || numtype(minDeltaX) != 0 || minDeltaX == 0
	endif

	if( doPointForPoint )
		Make/N=(maxLength)/D/FREE AveW, TempNWave		// initially 0
		Wave w=$StringFromList(0,ListOfWaves)
		CopyScales/P w, AveW, TempNWave
		
		for (i = 0; i < numWaves; i += 1)
			WAVE w=$StringFromList(i,ListOfWaves)
//			MultiThread AveW[]      += (numtype(w[p]) ==0) * w[p]	// 6.38: however, 0 * NaN is NaN, and we want to add 0 (ignore the point's contribution) if the value is NaN
			MultiThread AveW[]      += (numtype(w[p]) == 0) ? w[p] : 0
			MultiThread TempNWave[] += numtype(w[p]) ==0
		endfor
		
		MultiThread AveW /= TempNWave
		Duplicate/O AveW, $AveName
		
		if (ErrorType)
			Duplicate/O AveW, $ErrorName
			Wave SDW=$ErrorName
			SDW = 0
			i=0
			for (i = 0; i < numWaves; i += 1)
				WAVE w = $StringFromList(i,ListOfWaves)
				//MultiThread SDW[] += !numtype(w[p]) * (w[p]-AveW[p])^2
				MultiThread SDW[] += (numtype(w[p]) == 0) ? (w[p]-AveW[p])^2 : 0
			endfor
			MultiThread SDW /= (TempNWave-1)
			MultiThread SDW = sqrt(SDW)			// SDW now contains s.d. of the data for each point
			if (ErrorType > 1)
				MultiThread SDW /= sqrt(TempNWave)	// SDW now contains standard error of mean for each point
				if (ErrorType == 2)
					MultiThread SDW *= StudentT(ErrorInterval, TempNWave-1) // CLevel confidence interval width in each point
				endif
			else
				MultiThread SDW *= ErrorInterval
			endif
		endif
	else
		// can't do point-for-point because of different point range or scaling or there are multiple X waves
		Variable firstAvePoint,lastAvePoint,point,xVal,yVal
		
		Variable newLength= 1 + round(abs(maxXmax - minXmin) / minDeltaX)
		maxLength= min(maxLength*4,newLength)	// avoid the case where one very small deltaX in an XY pair causes a huge wave to be created.
	
		Make/N=(maxLength)/D/FREE AveW, TempNWave, TempYWave
		Wave w=$StringFromList(0,ListOfWaves)	
		CopyScales w, AveW // just to get the data and x units
		SetScale/I x, minXmin, maxXmax, AveW	// set X scaling to all-encompassing range

		for (i = 0; i < numWaves; i += 1)
			thisXMin= xRange[i][0]
			thisXMax= xRange[i][1]
			if( thisXMin > thisXMax )	// swapped X range (X values decrease with increasing point number)
				tmp= thisXMin
				thisXMin= thisXMax
				thisXMax= tmp
			endif
			firstAvePoint= ceil(x2pntWithFrac(AveW,thisXMin))	// truncate the partial point numbers...
			lastAvePoint= floor(x2pntWithFrac(AveW,thisXMax))	// ... by indenting slightly
			WAVE wy=$StringFromList(i,ListOfWaves)
			Wave/Z wx= $StringFromList(i,ListOfXWaves)
			if( WaveExists(wx) )
				MultiThread TempYWave[firstAvePoint, lastAvePoint] = interp(pnt2x(AveW, p), wx, wy)
			else
				MultiThread TempYWave[firstAvePoint, lastAvePoint] = wy(pnt2x(AveW, p))
			endif
//			MultiThread AveW[firstAvePoint, lastAvePoint]      += !numtype(TempYWave[p]) * TempYWave[p]
//			MultiThread TempNWave[firstAvePoint, lastAvePoint] += !numtype(TempYWave[p])
			MultiThread AveW[firstAvePoint, lastAvePoint]      += (numtype(TempYWave[p]) == 0) ? TempYWave[p] : 0
			MultiThread TempNWave[firstAvePoint, lastAvePoint] += numtype(TempYWave[p]) == 0
		endfor
		
		//  points with no values added are set to NaN here:
		MultiThread AveW= (TempNWave[p] == 0) ? NaN : AveW[p] / TempNWave[p]
		Duplicate/O AveW, $AveName
		
		if (ErrorType)
			Duplicate/O AveW, $ErrorName
			Wave/Z SDW=$ErrorName
			SDW = 0

			for (i = 0; i < numWaves; i += 1)
				thisXMin= xRange[i][0]
				thisXMax= xRange[i][1]
				if( thisXMin > thisXMax )	// swapped X range (X values decrease with increasing point number)
					tmp= thisXMin
					thisXMin= thisXMax
					thisXMax= tmp
				endif
				firstAvePoint= ceil(x2pntWithFrac(AveW,thisXMin))	// truncate the partial point numbers...
				lastAvePoint= floor(x2pntWithFrac(AveW,thisXMax))	// ... by indenting slightly
				WAVE wy=$StringFromList(i,ListOfWaves)
				Wave/Z wx= $StringFromList(i,ListOfXWaves)
				
				if( WaveExists(wx) )
					MultiThread TempYWave[firstAvePoint, lastAvePoint] = interp(pnt2x(AveW, p), wx, wy) - AveW[p]
				else
					MultiThread TempYWave[firstAvePoint, lastAvePoint] = wy(pnt2x(AveW, p)) - AveW[p]
				endif
				//MultiThread SDW[firstAvePoint, lastAvePoint]  += !numtype(TempYWave[p]) * TempYWave[p] * TempYWave[p]
				MultiThread SDW[firstAvePoint, lastAvePoint]  += (numtype(TempYWave[p]) == 0) ? TempYWave[p] * TempYWave[p] : 0
			endfor
			MultiThread SDW= (TempNWave[p] <= 1) ? NaN : sqrt(SDW[p] / (TempNWave[p] -1))	// SDW now contains s.d. of the data for each point
			if (ErrorType > 1)
				MultiThread SDW= (TempNWave[p] == 0) ? NaN : SDW[p] / sqrt(TempNWave[p])	// SDW now contains standard error of mean for each point
				if (ErrorType == 2)
					MultiThread SDW = (TempNWave[p] <= 1) ? NaN : SDW[p] * StudentT(ErrorInterval, TempNWave[p]-1) // Confidence Level confidence interval width in each point
				endif
			else
				MultiThread SDW = SDW[p] * ErrorInterval	// ???
			endif
		endif
		
	endif
	return doPointForPoint
End

static Function MonotonicCheck(wx,smallestXIncrement)
	Wave wx
	Variable &smallestXIncrement	// output

	Variable isMonotonic=0
	
	Duplicate/O/Free wx, diff
	Differentiate/DIM=0/EP=0/METH=1/P diff 
	WaveStats/Q/M=0 diff
	isMonotonic= (V_min > 0) == (V_max > 0)

	diff= abs(diff[p])
	WaveStats/Q/M=0 diff
	smallestXIncrement= V_Min
	
	return isMonotonic && smallestXIncrement != 0 
End

Function ErrorTypeMenuProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	Variable/G root:Packages:WM_WavesAverage:ErrorMenuSelection
	NVAR/Z ErrorMenuSelection=root:Packages:WM_WavesAverage:ErrorMenuSelection
	
	ShowHideErrorControls(1, popNum)
	ErrorMenuSelection = popNum
End

Function GenErrorWaveCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable/G root:Packages:WM_WavesAverage:GenErrorWaveChecked
	NVAR/Z GenErrorWaveChecked=root:Packages:WM_WavesAverage:GenErrorWaveChecked
	ControlInfo ErrorTypeMenu
	Variable ErrorMenuSelection=V_value

	ShowHideErrorControls(checked, ErrorMenuSelection)
	GenErrorWaveChecked=checked
End

Function ShowHideErrorControls(ShowThem, ErrorType)
	Variable ShowThem
	Variable ErrorType	// 0 = no error; 1 = S.D.; 2 = Conf Int; 3 = Standard Error

	Variable disable= ShowThem ? 0 : 1	// hide
	ModifyControlList "ErrorTypeMenu;SetErrorWaveName;" , win= WaveAveragePanel, disable=disable

	disable= ShowThem && (ErrorType == 1) ? 0 : 1	// hide
	ModifyControl SetNSD,win= WaveAveragePanel, disable=disable

	disable= ShowThem && (ErrorType == 2) ? 0 : 1	// hide
	ModifyControl SetConfInterval,win= WaveAveragePanel, disable=disable
end

Function ShowHideWavesFromGraphControls(ShowThem)
	Variable ShowThem
	
	Variable disable= ShowThem ? 0 : 1	// hide
	ModifyControl AverageAppendToGraphCheck,win= WaveAveragePanel, disable=disable
end	

Function ShowHideWaveNameTmpltControls(ShowThem)
	Variable ShowThem
	
	Variable disable= ShowThem ? 0 : 1	// hide
	ModifyControl SetListExpression,win= WaveAveragePanel, disable=disable
end	

Function AppendToGraphCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	NVAR/Z AppendToGraphCheckValue=root:Packages:WM_WavesAverage:AppendToGraphCheckValue
	AppendToGraphCheckValue=checked
	if(  !checked )
		PossiblyRemoveWavesFromGraph()
	endif
End

Function PossiblyRemoveWavesFromGraph()

	String graphName= WinName(0,1)
	if( strlen(graphName) == 0 )
		return 0
	endif
	SVAR/Z AveWaveName=root:Packages:WM_WavesAverage:AveWaveName
	if (SVAR_Exists(AveWaveName))
		Wave/Z aw= $AveWaveName
		do
			CheckDisplayed/W=$graphName aw
			if( V_flag )
				RemoveFromGraph/W=$graphName $AveWaveName
			else
				break
			endif
		while(1)
	endif
End

Function WaveFromMenuProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	NVAR WavesFromItem=root:Packages:WM_WavesAverage:WavesFromItem
	
	WavesFromItem=popNum
	ShowHideWavesFromGraphControls(popNum==2)
	ShowHideWaveNameTmpltControls( (popNum==1) || (popNum==2) )
End

Function f_WaveAveragePanel()

	DoWindow/K WaveAveragePanel
	
	NewPanel/K=1/N=WaveAveragePanel/W=(97,44,300,446) as "Average Waves"
	ModifyPanel/W=WaveAveragePanel noEdit=1
	DefaultGuiFont/W=#/Mac popup={"_IgorMedium",12,0},all={"_IgorMedium",12,0}
	DefaultGuiFont/W=#/Win popup={"_IgorMedium",0,0},all={"_IgorMedium",0,0}
	
	NVAR/Z GenErrorWaveChecked=root:Packages:WM_WavesAverage:GenErrorWaveChecked
	if (!NVAR_Exists(GenErrorWaveChecked))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif
	NVAR/Z WavesFromItem=root:Packages:WM_WavesAverage:WavesFromItem
	if (!NVAR_Exists(WavesFromItem))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif
	NVAR/Z ErrorMenuSelection=root:Packages:WM_WavesAverage:ErrorMenuSelection
	if (!NVAR_Exists(ErrorMenuSelection))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif
	
	SVAR/Z AveWaveName=root:Packages:WM_WavesAverage:AveWaveName
	if (!SVAR_Exists(AveWaveName))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif

// Select Waves	
	GroupBox selectWavesGroup,pos={5,2},size={192,70},title="Select Waves"
	GroupBox selectWavesGroup,userdata(ResizeControlsInfo)= A"!!,?X!!#7a!!#AO!!#?Ez!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	GroupBox selectWavesGroup,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	GroupBox selectWavesGroup,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	GroupBox selectWavesGroup,frame=0

	PopupMenu WaveSourceMenu,pos={30,23},size={120,20}, proc=WaveFromMenuProc
	PopupMenu WaveSourceMenu,mode=WavesFromItem,value= #"\"by Name;from Top Graph;from Top Table\""
	PopupMenu WaveSourceMenu,userdata(ResizeControlsInfo)= A"!!,CT!!#<p!!#@T!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	PopupMenu WaveSourceMenu,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	PopupMenu WaveSourceMenu,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	SetVariable SetListExpression,pos={30,46},size={161,19},title="Name Template:"
	SetVariable SetListExpression,value= root:Packages:WM_WavesAverage:ListExpression
	SetVariable SetListExpression,userdata(ResizeControlsInfo)= A"!!,CT!!#>F!!#A0!!#<Pz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	SetVariable SetListExpression,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable SetListExpression,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

// Output Waves

	GroupBox destinationGroup,pos={5,79},size={192,223},title="Output Waves"
	GroupBox destinationGroup,frame=0
	GroupBox destinationGroup,userdata(ResizeControlsInfo)= A"!!,?X!!#?W!!#AO!!#Anz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	GroupBox destinationGroup,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	GroupBox destinationGroup,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	SetVariable SetAveWaveName,pos={14,105},size={173,19},title=" Average:"
	SetVariable SetAveWaveName,value= root:Packages:WM_WavesAverage:AveWaveName
	SetVariable SetAveWaveName,userdata(ResizeControlsInfo)= A"!!,An!!#@6!!#A<!!#<Pz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	SetVariable SetAveWaveName,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable SetAveWaveName,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	CheckBox GenErrorCheck,pos={23,131},size={138,16},title="Generate Error Wave",value=GenErrorWaveChecked, proc=GenErrorWaveCheckProc
	CheckBox GenErrorCheck,userdata(ResizeControlsInfo)= A"!!,Bq!!#@g!!#@n!!#<8z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	CheckBox GenErrorCheck,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	CheckBox GenErrorCheck,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	SetVariable SetErrorWaveName,pos={28,153},size={155,19},title=" Error:"
	SetVariable SetErrorWaveName,value= root:Packages:WM_WavesAverage:ErrorWaveName
	SetVariable SetErrorWaveName,userdata(ResizeControlsInfo)= A"!!,CD!!#A(!!#A*!!#<Pz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	SetVariable SetErrorWaveName,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable SetErrorWaveName,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	PopupMenu ErrorTypeMenu,pos={38,180},size={140,20},proc=ErrorTypeMenuProc
	PopupMenu ErrorTypeMenu,mode=2,popvalue="Confidence Interval",value= #"\"Standard Deviations;Confidence Interval;Standard Error\""
	PopupMenu ErrorTypeMenu,userdata(ResizeControlsInfo)= A"!!,D'!!#AC!!#@p!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	PopupMenu ErrorTypeMenu,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	PopupMenu ErrorTypeMenu,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	SetVariable SetConfInterval,pos={54,208},size={121,19},bodyWidth=70,title="Interval:"
	SetVariable SetConfInterval,format="%d %"
	SetVariable SetConfInterval,limits={0,100,1},value= root:Packages:WM_WavesAverage:ConfInterval
	SetVariable SetConfInterval,userdata(ResizeControlsInfo)= A"!!,Dg!!#A_!!#@V!!#<Pz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable SetConfInterval,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable SetConfInterval,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	SetVariable SetNSD,pos={32,208},size={153,19},bodyWidth=50,title="Number of s.d.'s:"
	SetVariable SetNSD,limits={0,inf,1},value= root:Packages:WM_WavesAverage:nSD
	SetVariable SetNSD,userdata(ResizeControlsInfo)= A"!!,Cd!!#A_!!#A(!!#<Pz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	SetVariable SetNSD,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	SetVariable SetNSD,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

// Do It & Help
	Button WavesAveDoItButton,pos={12,274},size={50,20},proc=WaveAverageDoItButtonProc,title="Do It"
	Button WavesAveDoItButton,userdata(ResizeControlsInfo)= A"!!,AN!!#BC!!#>V!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	Button WavesAveDoItButton,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	Button WavesAveDoItButton,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	CheckBox print,pos={74,267},size={56,32},title="\\JCPrint\rWaves"
	CheckBox print,userdata(ResizeControlsInfo)= A"!!,EN!!#B?J,hoD!!#=cz!!#`-A7TLfzzzzzzzzzzzzzz!!#`-A7TLfzz"
	CheckBox print,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	CheckBox print,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	CheckBox print,value= 1

	Button WavesAveHelpButton,pos={137,274},size={50,20},title="Help",proc=WavesAverageHelpButtonProc
	Button WavesAveHelpButton,userdata(ResizeControlsInfo)= A"!!,Fn!!#BC!!#>V!!#<Xz!!#o2B4uAezzzzzzzzzzzzzz!!#o2B4uAezz"
	Button WavesAveHelpButton,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	Button WavesAveHelpButton,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

// Graph the Results

	GroupBox graphGroup,pos={5,307},size={192,79},title="Graph the Results"
	GroupBox graphGroup,frame=0
	GroupBox graphGroup,userdata(ResizeControlsInfo)= A"!!,?X!!#BSJ,hr%!!#?Wz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	GroupBox graphGroup,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	GroupBox graphGroup,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	CheckBox AverageAppendToGraphCheck,pos={23,238},size={143,16},proc=AppendToGraphCheckProc,title="Append to Top Graph"
	CheckBox AverageAppendToGraphCheck,value= 1
	CheckBox AverageAppendToGraphCheck,userdata(ResizeControlsInfo)= A"!!,Bq!!#B(!!#@s!!#<8z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	CheckBox AverageAppendToGraphCheck,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	CheckBox AverageAppendToGraphCheck,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	PopupMenu WavesAverageGraphXWave,pos={26,333},size={150,20},title="X Data:"
	PopupMenu WavesAverageGraphXWave,mode=1
	PopupMenu WavesAverageGraphXWave,value= #"\"_Calculated_;\\M1-;\"+WaveListMatchWave(\"\", 4,$root:Packages:WM_WavesAverage:AveWaveName, 0, 6, root:Packages:WM_WavesAverage:WA_ListOfWaves, 1)"
	PopupMenu WavesAverageGraphXWave,userdata(ResizeControlsInfo)= A"!!,C4!!#B`J,hqP!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	PopupMenu WavesAverageGraphXWave,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	PopupMenu WavesAverageGraphXWave,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

	Button WaveAveMakeGraphDoIt,pos={13,359},size={80,20},proc=WaveAverageMakeGraphButtonProc,title="New Graph"
	Button WaveAveMakeGraphDoIt,userdata(ResizeControlsInfo)= A"!!,A^!!#BmJ,hp/!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	Button WaveAveMakeGraphDoIt,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	Button WaveAveMakeGraphDoIt,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"

// Update
	ShowHideWavesFromGraphControls(WavesFromItem == 2)
	ShowHideWaveNameTmpltControls( (WavesFromItem==1) || (WavesFromItem==2) )
	
	ShowHideErrorControls(GenErrorWaveChecked, ErrorMenuSelection)

// Resizing
	SetWindow kwTopWin,userdata(ResizeControlsInfo)= A"!!*'\"z!!#AZ!!#C.z!!*'\"zzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzz!!!"

// Hooks
	SetWindow WaveAveragePanel, hook(WavesAverage)=WavesAverageNamedHook
	SetWindow WaveAveragePanel, hook(ResizeControls)=ResizeControls#ResizeControlsHook
End

// obsolete, 
Function WavesAverageCloseHook(infoStr)
	String infoStr
	
	String Event = StringByKey("EVENT",infoStr)
	if (CmpStr(Event, "kill")== 0)
		DoAlert 1, "Kill the WM_WavesAverage data folder? The Average Waves control panel settings will be lost, but your experiment will be less cluttered."
		if (V_flag == 1)
			KillDataFolder root:Packages:WM_WavesAverage
			return 1
		endif
	endif
	return 0
End

Function WavesAverageNamedHook(hs)
	STRUCT WMWinHookStruct &hs

	strswitch(hs.eventName)
		case "kill":
			DoAlert 1, "Kill the WM_WavesAverage data folder? The Average Waves control panel settings will be lost, but your experiment will be less cluttered."
			if (V_flag == 1)
				Execute/P/Z "KillDataFolder/Z root:Packages:WM_WavesAverage"
			endif
			break
	endswitch
	
	return 0
End


Function WavesAverageHelpButtonProc(ctrlName) : ButtonControl
	String ctrlName

	DisplayHelpTopic "Waves Average Procedure File and Control Panel"
End

Function WaveAverageDoItButtonProc(ctrlName) : ButtonControl
	String ctrlName

	SVAR/Z ListExpression=root:Packages:WM_WavesAverage:ListExpression
	if (!SVAR_Exists(ListExpression))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z ErrorWaveName=root:Packages:WM_WavesAverage:ErrorWaveName
	if (!SVAR_Exists(ErrorWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z AveWaveName=root:Packages:WM_WavesAverage:AveWaveName
	if (!SVAR_Exists(AveWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z WA_ListOfWaves=root:Packages:WM_WavesAverage:WA_ListOfWaves
	if (!SVAR_Exists(WA_ListOfWaves))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	NVAR/Z nSD=root:Packages:WM_WavesAverage:nSD
	if (!NVAR_Exists(nSD))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	NVAR/Z ConfInterval=root:Packages:WM_WavesAverage:ConfInterval
	if (!NVAR_Exists(ConfInterval))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	NVAR/Z ErrorMenuSelection=root:Packages:WM_WavesAverage:ErrorMenuSelection
	if (!NVAR_Exists(ErrorMenuSelection))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	
	String excludeOutputs= AveWaveName+";"
	ControlInfo GenErrorCheck
	if (V_value)
		excludeOutputs += ErrorWaveName+";"
	endif

	String theList="", theXList=""
	String aWave
	String TopGraph=WinName(0,1)
	String TopTable=WinName(0,2)
	
	Variable DoConf
	Variable Interval
	Variable AppndGrph=0, numXWaves=0
	
	ControlInfo WaveSourceMenu
	Variable ListSource=V_value
	if (ListSource == 1)		// by Name
		theList = WaveList(ListExpression, ";", "")
	endif
	if (ListSource == 2)		// from Top Graph
		if (strlen(TopGraph) == 0)
			DoAlert 0, "There are no graphs"
			return -1
		endif
		numXWaves= XYWaveListfromGraph(ListExpression, TopGraph,theList,theXList, exclude=excludeOutputs)
		ControlInfo AverageAppendToGraphCheck
		AppndGrph = V_value
	endif
	if (ListSource == 3)		// from Top Table
		if (strlen(TopTable) == 0)
			DoAlert 0, "There are no tables"
			return -1
		endif
		theList = WA_TableWaveList("*", ";", TopTable)
	endif
	
	Variable ErrorType = 0
	ControlInfo GenErrorCheck
	if (V_value)
		ErrorType = ErrorMenuSelection
		if (ErrorType == 1)
			Interval = nSD
		endif
		if (ErrorType == 2)
			Interval = ConfInterval
		endif
	endif
	
	Variable numWaves= ItemsInList(theList)
	if (numWaves == 0)
		DoAlert 0, "You have no waves selected. If you have selected From Top Graph, make sure the Wave Name Template is correct."
		return -1
	endif

	// Version 6.23: changed to Yes, No DoAlert
	if (numWaves == 1)
		// DoAlert 0, "You have only one wave selected ("+theList+" if you have selected From Top Graph, make sure the Wave Name Template is correct."
		//return -2
		String warning= "Only one wave selected ("+StringFromList(0,theList)+")."
		if (ListSource == 2)		// from Top Graph
			warning += " Make sure the Wave Name Template ( \""+ListExpression+"\" ) is correct."
		endif
		warning += "\r\rContinue anyway?"
		DoAlert 1, warning
		if( V_flag != 1 ) 	// 1 == yes
			return -2
		endif
		ErrorType=0
	endif

	Variable/G root:Packages:WM_WavesAverage:numWaves = numWaves		// for the New Graph button proc

	ControlInfo print
	if (V_value)
		Print "*** "+date()+" "+time()+" ***"
		Print "Averaging "+num2istr(numWaves)+" Y waves: "+ReplaceString(";",RemoveEnding(theList,";"),", ")
		if( numXWaves )
			String xwaveslist= RemoveEnding(RemoveFromList("",theXList),";")
			Print num2istr(numXWaves)+" X waves: "+ReplaceString(";",xwaveslist,", ")
		endif
		Print "Average output: "+AveWaveName
		if( ErrorType )
			ControlInfo ErrorTypeMenu
			String errorInfo= S_Value
			
			//Variable ErrorType		// 0 = none; 1 = S.D.; 2 = Conf Int; 3 = Standard Error
			// Variable ErrorInterval		// if ErrorType == 1, # of S.D.'s; ErrorType == 2, Conf. Interval
			switch( ErrorType )
				case 1:
					errorInfo += num2str(Interval)+" s.d.'s"
					break
				case 2:
					errorInfo += " @ "+num2str(Interval)+"%"
					break
			endswitch
			Print "Error output ("+errorInfo+"): "+ErrorWaveName
		endif
	endif
	Variable wasPointByPoint= fWaveAverage(theList, theXList, ErrorType, Interval, AveWaveName, ErrorWaveName)
	Variable disableXWave= 1	// hide
	
	if( wasPointByPoint >= 0 )	// < 0 means fWaveAverage reported an error
		ControlInfo print
		if (V_value)
			if( wasPointByPoint )
				Print AveWaveName+" computed using point-by-point averaging."
			else
				Print AveWaveName+" computed using interpolation."
			endif
		endif
	
		if (AppndGrph)
			DoWindow/F $(WinName(0,1))
			aWave =  StringFromList(0, theList, ";")
			CheckDisplayed $AveWaveName
			if (V_flag == 0)
				String TInfo = traceinfo("", NameOfWave($(aWave)),0)
				String AFlags=StringByKey("AXISFLAGS",TInfo)
				String XWaveInfo = PossiblyQuoteName(StringByKey("XWAVE", TInfo))
				if (wasPointByPoint && strlen(XWAveInfo) > 0)
					XWaveInfo = " vs "+StringByKey("XWAVEDF", TInfo)+XWaveInfo
				else
					XWaveInfo= ""
				endif
				String AppCom = "AppendToGraph "+AFlags+" "+AveWaveName+XWaveInfo
				Execute AppCom
			endif
			if (ErrorType == 0)
				ErrorBars $AveWaveName, OFF
			else
				ErrorBars $AveWaveName, Y wave=($ErrorWaveName, $ErrorWaveName)
			endif
		endif
		if( wasPointByPoint )
			disableXWave= 0	// enabled and showing
		else
			disableXWave= 2	// disabled but showing
			// force calculated
			PopupMenu WavesAverageGraphXWave, win=WaveAveragePanel, mode=1 
		endif
	endif
	ModifyControl WavesAverageGraphXWave, win=WaveAveragePanel, disable= disableXWave 
	WA_ListOfWaves = theList
End

Function WaveAverageMakeGraphButtonProc(ctrlName) : ButtonControl
	String ctrlName

	SVAR/Z ErrorWaveName=root:Packages:WM_WavesAverage:ErrorWaveName
	if (!SVAR_Exists(ErrorWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z AveWaveName=root:Packages:WM_WavesAverage:AveWaveName
	if (!SVAR_Exists(AveWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	
	Wave/Z AW = $AveWaveName
	if (!WaveExists(AW))
		abort "The wave "+AveWaveName+" does not exist. Perhaps you need to click Do It in the upper part of the panel."
	endif
	
	Variable numWaves= NumVarOrDefault("root:Packages:WM_WavesAverage:numWaves",2)	// legacy support defaults this to 2, which was the minimum that ever worked before 6.23.
	
	ControlInfo WavesAverageGraphXWave
	if (CmpStr(S_value, "_Calculated_") == 0)
		Display AW
	else
		Wave/Z XW = $S_value
		if (!WaveExists(XW))
			abort "The X wave, "+S_value+" cannot be found."
		endif
		Display AW vs XW
	endif
		
	ControlInfo/W=WaveAveragePanel GenErrorCheck
	if (V_value)
		WAVE/Z errorWave= $ErrorWaveName
		if( WaveExists(errorWave) && numWaves > 1 )
			ErrorBars $AveWaveName, Y wave=($ErrorWaveName, $ErrorWaveName)
		endif
	endif
End

Function/S WaveListfromGraph(matchStr, sepStr, graphName)
	String matchStr, sepStr, graphName
	
	String theList=""
	if (strlen(graphName) == 0)
		graphName = WinName(0,1)
	endif
	
	Variable i = 0
	do
		Wave/Z w = WaveRefIndexed(graphName,i,1)
		if (!WaveExists(w))
			break
		endif
		if (stringmatch(NameOfWave(w), matchStr))
			theList += GetWavesDataFolder(w, 2)+sepStr
		endif
		i += 1
	while (1)
	return theList
end

// returns number of non-blank items in xWavesList
Function XYWaveListfromGraph(matchStr, graphName,yWavesList,xWavesList[,exclude])
	String matchStr, graphName
	String &yWavesList, &xWavesList	// outputs
	String exclude						// optional input
	
	if( ParamIsDefault(exclude) )
		exclude=""
	endif
	yWavesList=""
	xWavesList=""
	
	if (strlen(graphName) == 0)
		graphName = WinName(0,1)
		if( strlen(graphName) == 0 )
			return 0
		endif
	endif
	
	Variable numXWaves= 0
	
	String traces= TraceNameList(graphName,";",1+4)	// only visible normal traces
	Variable i, n=ItemsInList(traces)
	for(i=0; i < n; i+=1 )
		String trace= StringFromList(i,traces)		// can be "wy#1", for example, or a custom trace name.
		Wave wy= TraceNameToWaveRef(graphName, trace)
		String wName = NameOfWave(wy)		// just the bare wave name.
		if (stringmatch(wName, matchStr))
			// 6.38: skip excluded wave names
			if( FindListItem(wName, exclude) < 0 )
				// avoid listing a wave more than once if it is displayed multiple times
				String path=GetWavesDataFolder(wy, 2)
				if( FindListItem(path, yWavesList) < 0 )	// not already in list
					yWavesList += path+";"
					Wave/Z wx= XWaveRefFromTrace(graphName, trace)
					if( WaveExists(wx) )
						path=GetWavesDataFolder(wx, 2)
						numXWaves += 1
					else
						path=""
					endif
					xWavesList += path+";"
				endif
			endif
		endif
	endfor
	return numXWaves
end

Function/S WA_TableWaveList(matchStr, sepStr, tableName)
	String matchStr, sepStr, tableName
	
	if (strlen(tableName) == 0)
		TableName=WinName(0,2)
	endif
	
	String ListofWaves=""
	String thisColName
	Variable i, nameLen
	
	GetSelection table, $TableName, 7
	String SelectedColNames=S_selection
	String SelectedDataFolders=S_dataFolder
	
	if (V_startCol == V_endCol)		// There is no selection or the selection doesn't make sense; use the whole table
		i = 0
		do
			Wave/Z w=WaveRefIndexed(TableName,i,1)
			if (!waveExists(w))
				break
			endif
			ListofWaves += GetWavesDataFolder(w, 2)+";"
		
			i += 1
		while (1)
	else	
		i = 0
		do
			thisColName = StringFromList(i, SelectedColNames, ";")
			if (strlen(thisColName) == 0)
				break
			endif
			nameLen = strlen(thisColName)
			if (CmpStr(thisColName[nameLen-2,nameLen-1], ".i") != 0)
				if (CmpStr(thisColName[nameLen-3,nameLen-3], "]") != 0)
					thisColName = thisColName[0,nameLen-3]
					if (stringmatch(thisColName, matchStr))
						thisColName = StringFromList(i, SelectedDataFolders,";")+thisColName
						if (Exists(thisColName))
							ListofWaves += thisColName+";"
						endif
					endif
				endif
			endif
			i += 1
		while (1)
	endif

	return ListofWaves
end
