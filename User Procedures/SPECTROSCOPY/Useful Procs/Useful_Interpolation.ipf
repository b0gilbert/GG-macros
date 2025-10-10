#pragma rtGlobals=1		// Use modern global access method.




Function InterpolateOnLogAxis(yw,xMin,xMax,nPts)
	Wave yw
	Variable xMin, xMax, nPts
	
	String Name = NameOfWave(yw)
	String NameIntY = Name + "_Y"
	String NameIntX = Name + "_X"
	
	Variable i, Alpha
	
	Alpha = ReturnLogStep(xMin,xMax,NPts)
	
	Make /O/D/N=(NPts) $NameIntY 	/ WAVE=IntY
	Make /O/D/N=(NPts) $NameIntX 	/ WAVE=IntX
	
	IntX[0] = xMin
	IntX[1,] = Alpha * IntX[p-1]
	
	Interpolate2/T=1/Y=IntY/X=IntX/I=3 yw
End


// ********************************************************
// ******     			Interpolation Routines
// ********************************************************
Function ReturnLogStep(Start,Stop,NPts)
	Variable Start,Stop,NPts
	
	Variable LogAlpha	= Log(Stop/Start) / (NPts-1)
	
	return 10^LogAlpha
End

Function AxisDataToConstantStep(Axis,Data,Tolerance)
	Wave Axis, Data
	Variable Tolerance

	Variable BIG=2e9
	Variable AxisStep 	= abs(CheckConstantStep(Axis,Tolerance,0))
	Variable AxisPts	= abs(Axis[BIG] - Axis[0])/AxisStep + 1
	
	String csAxisName = (NameOfWave(Axis)+"_cstep")
	String csDataName	= (NameOfWave(Data)+"_cstep")
	
	Make /O/D/N=(AxisPts) $csAxisName, $csDataName
	WAVE csAxis 	= $csAxisName
	csAxis			= min(Axis[BIG],Axis[0]) + x*AxisStep
	
	Interpolate2/T=1/I=3/Y=$csDataName/X=$csAxisName Axis, Data
End

Function AutoMakeCommonAxis(axis1,axis2, cAxisName,UserPromptFlag)
	Wave axis1,axis2
	String cAxisName
	Variable UserPromptFlag
	
	Variable AxMin, AxMax, AxStep, NumPts, BIG=2e9
	
	if (EqualWaves(axis1,axis2,1) == 1)
		Duplicate /O/D axis1, $cAxisName
		return 1
	endif
	
	// Determine the axis range encompassing both waves. 
	// I think this will handle low-to-high and high-to-low input axes ...
	// ... and end up with low-to-high interpolated axis. 
	
	AxMin = min(MinWithNANs(axis1[0], axis2[0]),MinWithNANs(axis1[BIG],axis2[BIG]))
	AxMax = max(MaxWithNANs(axis1[0], axis2[0]),MaxWithNANs(axis1[BIG],axis2[BIG]))
	AxStep = abs(MinWithNANs(CheckConstantStep(axis1,0,0),CheckConstantStep(axis2,0,0)))
	
	if (UserPromptFlag == 0)
		if ((AxStep == 0) || (numtype(AxStep != 0)))
			DoAlert 0, "Zero, infinite or NAN axis step!"
			UserPromptFlag = 1
		elseif ((numtype(AxMin != 0)) || (numtype(AxMax != 0)))
			DoAlert 0, "Problem determining the axis range!"
			UserPromptFlag = 1
		else
			NumPts = (AxMax - AxMin)/AxStep + 1
			if (NumPts > 10000)
				DoAlert 0, "Too many points for the common axis!"
				UserPromptFlag = 1
			endif
		endif
	endif
	
	if (UserPromptFlag == 1)
		Variable nAxMin = AxMin
		Prompt nAxMin, "Start of the axis range"
		Variable nAxMax = AxMax
		Prompt nAxMax, "End of the axis range"
		Variable nAxStep = AxStep
		Prompt nAxStep, "The axis step"
		DoPrompt "Please modify the range of the interpolation axis", nAxMin, nAxMax, nAxStep
		if (V_flag)
			return 0
		endif
		
		AxMin	= nAxMin
		AxMax	= nAxMax
		AxStep	= nAxStep
		
		NumPts = (AxMax - AxMin)/AxStep + 1
	endif

	Make /D/O/N=(NumPts) $cAxisName
	WAVE cAxis = $cAxisName
	cAxis[]=AxMin+x*AxStep
	
	return 1
End

Function InterpolateDataOnCommonAxis(data1,axis1,data2,axis2, cAxisName, cWave1Name,cWave2Name)
	Wave data1,axis1,data2,axis2
	String cAxisName, cWave1Name,cWave2Name
	
	// First ensure there are no NANs in the waves we actually will join together. 
	Duplicate /O/D axis1, tempAxis1
	Duplicate /O/D data1, tempData1
	StripNANsFromWaveAxisPair(tempData1,tempAxis1)
	
	Duplicate /O/D axis2, tempAxis2
	Duplicate /O/D data2, tempData2
	StripNANsFromWaveAxisPair(tempData2,tempAxis2)
	
	// Make an axis that encompasses both input axes
	if (AutoMakeCommonAxis(tempAxis1,tempAxis2, cAxisName,0) == 1)
		Duplicate /O/D $cAxisName, $cWave1Name, $cWave2Name
		
		Interpolate2/T=1/N=3/I=3/Y=$cWave1Name/X=$cAxisName tempAxis1, tempData1
		Interpolate2/T=1/N=3/I=3/Y=$cWave2Name/X=$cAxisName tempAxis2, tempData2
		KillWaves /Z tempAxis1, tempData1, tempAxis2, tempData2
		
		return 1
	else
		Print " *** User aborted interpolation routine"
		KillWaves /Z tempAxis1, tempData1, tempAxis2, tempData2
		
		return 0
	endif	
End