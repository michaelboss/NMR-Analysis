#pragma rtGlobals=1

Function KillGraphs(startnum, endnum)
	Variable startnum, endnum
	Variable i
	String WindowName
	
	for(i=startnum; i<=(endnum); i+=1)
		WindowName="Graph"+num2str(i)
		KillWindow $WindowName
	endfor
	
End