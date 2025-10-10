#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// *************************************************************
// ****		Load ALS OP IR csv fuke
// *************************************************************


Function LoadALSOptIR()

	InitializeStackBrowser()
	
	String OptIRName, StackName, StackAxis
	Variable NRows, NCols, NAxisPts, i, j, n=0, XMin, XMax, YMin, YMax, dX, DY
	
//	Variable NDataPts, NAxisPts, NPixels, Side, i, j, n=0
//	String OptIRName, WiTecAxis, StackName, StackAxis

	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Stacks
	
		KillWaves /Z IRmatrix0, IRStack, IRStack_axis
		
		// Load the csv file
		LoadWave /Q/O/J/M/D/A=$"IRmatrix"/E=0/K=0 //"Macintosh HD:Users:BGilbert:-Projects:East River II:2021 Langlang:Sagebrush:Sagebrush IR 0719:sagebrush_long_scan_0.25mmstep-O-PTIR.csv"
		
		if (V_flag==1)
			StackName 		= StripSpacesAndSuffix(S_Filename,".")
			StackName 		= CleanUpDataName(StackName)
			OptIRName 		= StringFromList(0, S_Wavenames)
			WAVE OptIRData 	= $OptIRName
		else
			return 0
		endif
		
		NRows 	= DimSize(OptIRData,0)
		NCols 	= DimSize(OptIRData,1)
		
		// Extract the data axis (the first row)
		MatrixOp /O OptIRAxis = row(OptIRData,0)^t
		DeletePoints 0, 2, OptIRAxis
		NAxisPts = NCols - 2
		
		// Extract the X axis (the first column)
		MatrixOp /O XAxis = col(OptIRData,0)
		DeletePoints 0, 1, XAxis
		WaveStats /Q/M=0 XAxis
		XMin 	= V_min
		XMax 	= V_max
		Duplicate /O/D XAxis, DXAxis
		DXAxis[1,] 	= XAxis[p] - XAxis[p-1]
		
		MatrixOp /O YAxis = col(OptIRData,1)
		DeletePoints 0, 1, YAxis
		WaveStats /Q/M=0 YAxis
		YMin 	= V_min
		YMax 	= V_max
		Duplicate /O/D YAxis, DYAxis
		DYAxis[1,] 	= YAxis[p] - YAxis[p-1]
		
		Variable NX = 35, NY = 8, NE = NAxisPts
		Make /O/D/N=(NX,NY,NE) OptIRStack
		
		n = 0
		for (i=0;i<NX;i+=1)
			for (j=0;j<NY; j+=1)
				
				MatrixOp /FREE Spectrum = row(OptIRData,n)^t
				DeletePoints 0, 2, Spectrum
				
				OptIRStack[i][j][] = Spectrum[r]
				
				n += 1
				
			endfor
		endfor
		
		
//		// Next load the axis file with wavenumber values
//		Loadwave /A=$"axis"/Q/N/O/D/G
//		if (V_flag==1)
//			WiTecAxis = StringFromList(0, S_waveNames)
//			WAVE WTAxis 	= $WiTecAxis
//		else
//			return 0
//		endif
//		
//		NDataPts 		= DimSize($WiTecData,0)
//		NAxisPts 		= DimSize($WiTecAxis,0)
//		NPixels 		= NDataPts/NAxisPts
//		Side 			= sqrt(NPixels)
//		
//		Print "NDataPts=",NDataPts,"   NAxisPts =",NAxisPts,"   NPixels=",NPixels,"   Side=",Side
//		
//		Make /O/U/N=(Side,Side,NAxisPts) RamanMatrix=0
//		
//		for (i=0;i<Side;i+=1)
//			for (j=0;j<Side;j+=1)
//				RamanMatrix[j][i][] 	= WTData[n*NAxisPts + r]
//				n += 1
//			endfor
//		endfor
//		
//		Prompt StackName, "Name of imported stack"
//		do
//			DoPrompt "Please avoid odd characters and 'stack'!", StackName
//			if (V_flag)
//				return 0
//			endif
//			StackName 	= CleanUpDataName(StackName)
//		while(StrSearch(StackName,"stack",0,2) > -1)
//		StackAxis 	= StackName+"_axis"
//
//		if (WaveExists($StackName) == 1)
//			DoWindow /K StackBrowser
//			RemoveDataFromAllWindows(StackName)
//			KillWaves $StackName
//		endif
//		
//		Rename RamanMatrix, $StackName
//		Rename WTAxis, $StackAxis
//		KillWaves /Z data0, wave0
		
		print StackName
		StackName = "IRStack"
		Rename OptIRStack, $StackName
		StackAxis 	= StackName+"_axis"
		Rename OptIRAxis, $StackAxis
		DisplayStackBrowser(StackName)
		
		KillWaves /Z IRmatrix0
		
		Print " *** Loaded a Opt-IR stack: "+StackName+" from "+S_Filename
//		Print " 		...	 (",NX,"x",NY,") images and ",NAxis," optical wavelength values."
		
	SetDataFolder $(OldDf)
	
End





// ***************************************************************************
// **************** 			Raman Spectromicroscopy
// ***************************************************************************



Function FoundryHD5ToStack()

	String LoadedName, StackName, OldDf = GetDataFolder(1)
	
		InitializeStackBrowser()
		SetDataFolder root:SPHINX:Stacks
	
		WAVE sm = spec_map
		WAVE wls = wls
		if (!WaveExists(sm) || !WaveExists(wls))
			print " Please import a Foundry Scope HD5 dataset and wavelengths into the Stacks data folder" 
			return 0
		endif
		
		Variable NRow=DimSize(sm,0), nCol=DimSize(sm,1), nLay=DimSize(sm,2), nChunk=DimSize(sm,3)
		
		// Give the stack a nice name
		StackName 	= "FoundryRaman"
		StackName 	= CleanUpDataName(StackName)
		Prompt StackName, "Name of imported stack"
		do
			DoPrompt "Please avoid odd characters and 'stack'!", StackName
			if (V_flag)
				return 0
			endif
			StackName 	= CleanUpDataName(StackName)
		while(StrSearch(StackName,"stack",0,2) > -1)
		
		Make /D/O/N=(nCol,nLay,nChunk) $StackName /WAVE = FStack
		FStack[][][] 	= sm[0][p][q][r]
		
		Make /O/D/N=(DimSize(wls,0)) root:SPHINX:Browser:energy /WAVE = energy
		energy = wls
		
		String StackAxisName	= StackName + "_axis"
		KillWaves /Z $StackAxisName
		Rename wls, $StackAxisName
	
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded a Foundry Scope Raman stack: "+StackName
		
	SetDataFolder $(OldDf)

End

//	Make /D/O/N=(nCol,nLay) slice
//	slice[][] 	= sm[0][p][q][10]

// *************************************************************
// ****		Load WiTec Raman stack
// *************************************************************


Function LoadJobinRaman()

	InitializeStackBrowser()
	
	Variable NDataPts, NAxisPts, NPixels, NXPts, NYPts, XStep, YStep, i, j, n=0
	String XPosStr, YPosStr, XPosList, YPosList
	String WiTecData, WiTecAxis, StackName, StackAxis

	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Stacks
		
		// First load the text file into a matrix
		LoadWave/J/M/D/A=$"raman"/K=0
		
		if (V_flag==1)
			StackName 	= StripSpacesAndSuffix(S_Filename,".")
			StackName 	= CleanUpDataName(StackName)
			WAVE raman 	= $("root:SPHINX:Stacks:"+StringFromList(0,S_waveNames))
		else
			return 0
		endif
		
		NPixels 	= DimSize(raman,0)-1
		NAxisPts = DimSize(raman,1)-2
		
		Make /O/N=(NAxisPts) RAxis
		RAxis[] 	= raman[0][p+2]
		
		XPosList = num2str(raman[1][0])
		YPosList = num2str(raman[1][1])
		
		for (i=2;i<NPixels;i+=1)
		
			XPosStr = num2str(raman[i][0])
			YPosStr = num2str(raman[i][1])
			
			if (WhichListItem(XPosStr,XPosList) == -1)
				XPosList = XPosList + ";" + XPosStr
			endif
			
			if (WhichListItem(YPosStr,YPosList) == -1)
				YPosList = YPosList + ";" + YPosStr
			endif
		endfor
		
		NXPts = ItemsInList(XPosList)
		Make /O/N=(NXPts) Xvalues
		ListValuesToWave(Xvalues,XPosList,";",0)
		Sort Xvalues, Xvalues
		XStep = Xvalues[1] - Xvalues[0]
		
		NYPts = ItemsInList(YPosList)
		Make /O/N=(NYPts) Yvalues
		ListValuesToWave(Yvalues,YPosList,";",0)
		Sort Yvalues, Yvalues
		YStep = Yvalues[1] - Yvalues[0]
		
		Make /O/U/N=(NXPts,NYPts,NAxisPts) RamanMatrix=0
		
		for (i=0;i<NXPts;i+=1)
			for (j=0;j<NYPts;j+=1)
				
				RamanMatrix[i][j][] = raman[n+1][r+2]
				
				n+=1
			endfor
		endfor
		
		Prompt StackName, "Name of imported stack"
		do
			DoPrompt "Please avoid odd characters and 'stack'!", StackName
			if (V_flag)
				return 0
			endif
			StackName 	= CleanUpDataName(StackName)
		while(StrSearch(StackName,"stack",0,2) > -1)
		StackAxis 	= StackName+"_axis"

		if (WaveExists($StackName) == 1)
			DoWindow /K StackBrowser
			RemoveDataFromAllWindows(StackName)
			KillWaves $StackName
		endif
		
		Rename RamanMatrix, $StackName
		Rename RAxis, $StackAxis
//		KillWaves /Z data0, wave0
		
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded a B30 Jobin Raman stack: "+StackName+" from "+S_Filename
		
	SetDataFolder $(OldDf)
	
End

		
		
//		Loadwave /A=$"data"/Q/N/O/D/G
	
		if (V_flag==1)
			StackName 	= StripSpacesAndSuffix(S_Filename,".")
			StackName 	= CleanUpDataName(StackName)
			WiTecData = StringFromList(0, S_waveNames)
			WAVE WTData 	= $WiTecData
		else
			return 0
		endif
		
		// Next load the axis file with wavenumber values
		Loadwave /A=$"axis"/Q/N/O/D/G
		if (V_flag==1)
			WiTecAxis = StringFromList(0, S_waveNames)
			WAVE WTAxis 	= $WiTecAxis
		else
			return 0
		endif
		
		NDataPts 		= DimSize($WiTecData,0)
		NAxisPts 		= DimSize($WiTecAxis,0)
		NPixels 		= NDataPts/NAxisPts
		Side 			= sqrt(NPixels)
		
		Print "NDataPts=",NDataPts,"   NAxisPts =",NAxisPts,"   NPixels=",NPixels,"   Side=",Side
		
		Make /O/U/N=(Side,Side,NAxisPts) RamanMatrix=0
		
		for (i=0;i<Side;i+=1)
			for (j=0;j<Side;j+=1)
				RamanMatrix[j][i][] 	= WTData[n*NAxisPts + r]
				n += 1
			endfor
		endfor
		
		Prompt StackName, "Name of imported stack"
		do
			DoPrompt "Please avoid odd characters and 'stack'!", StackName
			if (V_flag)
				return 0
			endif
			StackName 	= CleanUpDataName(StackName)
		while(StrSearch(StackName,"stack",0,2) > -1)
		StackAxis 	= StackName+"_axis"

		if (WaveExists($StackName) == 1)
			DoWindow /K StackBrowser
			RemoveDataFromAllWindows(StackName)
			KillWaves $StackName
		endif
		
		Rename RamanMatrix, $StackName
		Rename WTAxis, $StackAxis
//		KillWaves /Z data0, wave0
		
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded a WiTec Raman stack: "+StackName+" from "+S_Filename
//		Print " 		...	 (",NX,"x",NY,") images and ",NAxis," optical wavelength values."
		
	SetDataFolder $(OldDf)
	
End

// *************************************************************
// ****		Load WiTec Raman stack
// *************************************************************


Function LoadWiTecRaman()

	InitializeStackBrowser()
	
	Variable NDataPts, NAxisPts, NPixels, Side, i, j, n=0
	String WiTecData, WiTecAxis, StackName, StackAxis

	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Stacks
		
		// First load the data file with N spectra
		Loadwave /A=$"data"/Q/N/O/D/G
	
		if (V_flag==1)
			StackName 	= StripSpacesAndSuffix(S_Filename,".")
			StackName 	= CleanUpDataName(StackName)
			WiTecData = StringFromList(0, S_waveNames)
			WAVE WTData 	= $WiTecData
		else
			return 0
		endif
		
		// Next load the axis file with wavenumber values
		Loadwave /A=$"axis"/Q/N/O/D/G
		if (V_flag==1)
			WiTecAxis = StringFromList(0, S_waveNames)
			WAVE WTAxis 	= $WiTecAxis
		else
			return 0
		endif
		
		NDataPts 		= DimSize($WiTecData,0)
		NAxisPts 		= DimSize($WiTecAxis,0)
		NPixels 		= NDataPts/NAxisPts
		Side 			= sqrt(NPixels)
		
		Print "NDataPts=",NDataPts,"   NAxisPts =",NAxisPts,"   NPixels=",NPixels,"   Side=",Side
		
		Make /O/U/N=(Side,Side,NAxisPts) RamanMatrix=0
		
		for (i=0;i<Side;i+=1)
			for (j=0;j<Side;j+=1)
				RamanMatrix[j][i][] 	= WTData[n*NAxisPts + r]
				n += 1
			endfor
		endfor
		
		Prompt StackName, "Name of imported stack"
		do
			DoPrompt "Please avoid odd characters and 'stack'!", StackName
			if (V_flag)
				return 0
			endif
			StackName 	= CleanUpDataName(StackName)
		while(StrSearch(StackName,"stack",0,2) > -1)
		StackAxis 	= StackName+"_axis"

		if (WaveExists($StackName) == 1)
			DoWindow /K StackBrowser
			RemoveDataFromAllWindows(StackName)
			KillWaves $StackName
		endif
		
		Rename RamanMatrix, $StackName
		Rename WTAxis, $StackAxis
//		KillWaves /Z data0, wave0
		
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded a WiTec Raman stack: "+StackName+" from "+S_Filename
//		Print " 		...	 (",NX,"x",NY,") images and ",NAxis," optical wavelength values."
		
	SetDataFolder $(OldDf)
	
End
	