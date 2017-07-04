#pragma rtGlobals=1		// Use modern global access method.

Function GradCal(w, gradamp, OuterSize, InnerSize, bandwidth, Points1D, Points2D, Threshhold, Box, smoothfactor, grad)	//This is for an "inverse" phantom, with water on the outside and void on the inside
	wave w, gradamp; variable OuterSize, InnerSize, bandwidth, Points1D, Points2D, Threshhold, Box, smoothfactor; string grad;
	variable i
	string GradLeftOut=grad+"OutLeft", GradRightOut=grad+"OutRight", GradLeftIn=grad+"InLeft", GradRightIn=grad+"InRight",GradCalib=grad+"Calib"
	string GradBWIn=grad+"InBW", GradBWOut=grad+"OutBW", GradCent=grad+"Cent"
	Make /O/N=(Points2D)/D $GradLeftOut,$GradLeftIn, $GradRightOut, $GradRightIn, $GradCalib, $GradBWIn, $GradBWOut, $GradCent
	Wave LeftOut=$(GradLeftOut), RightOut=$(GradRightOut), LeftIn=$(GradLeftIn), RightIn=$(GradRightIn), Calib=$(GradCalib), BWIn=$(GradBWIn), BWOut=$(GradBWOut), Cent=$(GradCent);
	
	//duplicate/o w w0; smooth smoothfactor, w0;differentiate w0 /d=w1; differentiate w1 /d=w2 
	//The above is presently unused (working on original, unsmoothed wave)

	for(i=0;i<Points2D;i+=1)
		wavestats /R=[Points1D*i,Points1D*(i+1)-1] /Q w
		pulsestats/b=(Box) /f=(Threshhold) /L=(V_max, mean(w,Points1D*i+0,Points1D*i+20)) /R=[Points1D*i,Points1D*(i+1)-1] /M=10 /Q w
//		COMMENT: above pulsestats is for normal phantom, with singular edges, or to find the outer edges of double or inverse phantom
//		pulsestats/b=(Box) /f=(Threshhold) /L=(V_max, V_max*.85) /R=[Points1D*i,Points1D*(i+1)-1] /M=10 /Q w

		printf "Outer %g, %g\r" V_PulseLoc1, V_PulseLoc2
		if(i<Points2D/2-1)
			LeftOut[i]=V_PulseLoc1; RightOut[i]=V_PulseLoc2
			FindPeak /B=(box) /R=(LeftOut[i],(RightOut[i]+LeftOut[i])/2) /M=(0.8*V_max) /Q w //looks for left-side peak, L->R
			LeftIn[i]=V_PeakLoc
			FindPeak /B=(box) /R=(RightOut[i],(RightOut[i]+LeftOut[i])/2) /M=(0.8*V_max) /Q w //looks for right-side peak, R->L
			RightIn[i]=V_PeakLoc
			printf "Inner %g, %g\r-----------\r" LeftIn[i], RightIn[i]
			
		else
			LeftOut[i]=V_PulseLoc2; RightOut[i]=V_PulseLoc1
			FindPeak /B=(box) /R=(LeftOut[i],(RightOut[i]+LeftOut[i])/2) /M=(0.8*V_max) /Q w //looks for left-side peak, L->R
			LeftIn[i]=V_PeakLoc
			FindPeak /B=(box) /R=(RightOut[i],(RightOut[i]+LeftOut[i])/2) /M=(0.8*V_max) /Q w //looks for right-side peak, R->L
			RightIn[i]=V_PeakLoc
			printf "Inner %g, %g\r-----------\r" LeftIn[i], RightIn[i]
		endif
	endfor
	
	BWOut=(LeftOut-RightOut)*bandwidth/Points1D
	BWIn=(LeftIn-RightIn)*bandwidth/Points1D
	Calib=BWIn/(42.5775e6*InnerSize)
	
//	Display w
//	AppendToGraph/VERT $GradLeft
//	ModifyGraph mode($GradLeft)=3,marker($GradLeft)=19,rgb($GradLeft)=(0,0,0)
//	AppendToGraph/VERT $GradRight
//	ModifyGraph mode($GradRight)=3,marker($GradRight)=19,rgb($GradRight)=(0,0,0)
	
//	Display $GradCalib vs gradamp
//	ModifyGraph mode($GradCalib)=3,marker($GradCalib)=19,rgb($GradCalib)=(0,0,0)
//	CurveFit/NTHR=1/TBOX=785 line  $GradCalib /X=gradAmp /D 
End