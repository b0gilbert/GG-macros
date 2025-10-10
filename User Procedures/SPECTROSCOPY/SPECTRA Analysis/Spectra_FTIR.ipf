#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// *************************************************************
// ****		TAB 7:	FTIR Diffraction Operations
// *************************************************************
Function AppendPlotFTIRControls(WindowName)
	String WindowName
	
	String PlotFolderName 	= "root:SPECTRA:Plotting:"+WindowName
	String FTIRFolderName 	= "root:SPECTRA:Plotting:FTIR"
	
	
//	Button FTIR_ClearRefsButton,pos={590,60},size={100,18},proc=DataControlButtons,title="Average", disable=1

	PopupMenu FTIR_RefMenu pos={102,66},title="Substance or group  ",fSize=12, proc=FTIRMenuProcs, disable=1
	PopupMenu FTIR_RefMenu,size={250,18},value=GetFTIRSpeciesList(), mode=1

End

Function /T GetFTIRSpeciesList()

	SVAR gFTIRSpeciesList 	= root:SPECTRA:FTIR:gFTIRSpeciesList
	
	String FTIRSpeciesList = "none;"
	if (SVAR_Exists(gFTIRSpeciesList))
		 FTIRSpeciesList 	= gFTIRSpeciesList
	endif
	
	return FTIRSpeciesList
End

Function FTIRMenuProcs(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	String ctrlName 			= PU_Struct.ctrlName
	String plotName 			= PU_Struct.win
	String ctrlString 			= PU_Struct.popStr
	String PlotFolderName 		= "root:SPECTRA:Plotting:" + PlotName
	
	SVAR gSelection1 	= $(PlotFolderName+":gSelection1")
	
	if (PU_Struct.eventCode > 0)
		if (StrSearch(ctrlString,"none",0) > -1)
			RemoveFTIRBands(plotName)
		else
			AddFTIRBands(ctrlString,plotName)
		endif
		
		return 1
	endif
End

Function RemoveFTIRBands(plotName)
	String plotName
	
	SVAR gFTIRSpeciesList 	= root:SPECTRA:FTIR:gFTIRSpeciesList
	
	Variable i, NSpecies = ItemsInList(gFTIRSpeciesList)
	String FTIRSpecies
	
	for (i=0;i<NSpecies;i+=1)
		FTIRSpecies 	= StringFromList(i,gFTIRSpeciesList)
		WAVE Bands 	= $("root:SPECTRA:FTIR:Bands_"+FTIRSpecies)
		CheckDisplayed /W=$plotName Bands
		if (V_flag == 1)
			GetAxis /Q/W=$plotName bottom
			RemoveFromGraph /Z/W=$plotName $NameOfWave(Bands)
			SetAxis /W=$plotName bottom, V_min, V_max
		endif
	endfor
End


Function AddFTIRBands(FTIRSpecies,plotName)
	String FTIRSpecies, plotName
	
	Variable i, NBands, cm1, cm2, B1, B2
	
	String FTIRFolder = "root:SPECTRA:FTIR"
	if (!DataFolderExists(FTIRFolder))
		LoadFTIRBands()
	endif
	
	WAVE /T FTIRBands 	= $("root:SPECTRA:FTIR:FTIR_"+FTIRSpecies)
	if (!WaveExists(FTIRBands))
		return 0
	endif
	
	NBands 	= DimSize(FTIRBands,0)
	Make /O/N=(5000) $("root:SPECTRA:FTIR:Bands_"+FTIRSpecies) /WAVE=Bands
	SetScale /P x, 0, 1, Bands
	Bands = 0
	
	for (i=1;i<NBands;i+=1)
		cm1 	= str2num(FTIRBands[i][0]) - trunc(str2num(FTIRBands[i][1])/2)
		cm2 	= str2num(FTIRBands[i][0]) + trunc(str2num(FTIRBands[i][1])/2)
		B1 		= x2pnt(Bands,cm1)
		B2 		= x2pnt(Bands,cm2)
		
		Bands[B1,B2] 	= str2num(FTIRBands[i][2])/100
	endfor
	
	CheckDisplayed /W=$plotName $("root:SPECTRA:FTIR:Bands_"+FTIRSpecies)
	if (V_flag == 0)
		GetAxis /Q/W=$plotName bottom
		AppendToGraph /W=$plotName/R=FTIRAxis Bands
		SetAxis /W=$plotName bottom, V_min, V_max
		
		ReorderTraces $(StringFromList(0,TraceNameList(PlotName,";",1))),{$NameOfWave(Bands)}
	endif
	
	SetAxis /W=$plotName FTIRAxis, 0, 1.2
	ModifyGraph /W=$plotName axThick(FTIRAxis)=0, noLabel(FTIRAxis)=2
	ModifyGraph /W=$plotName mode($NameOfWave(Bands))=5, hbFill($NameOfWave(Bands))=5, lsize($NameOfWave(Bands))=0
	
	ColorAxisTraces(PlotName,"FTIRAxis","LandAndSea8")
End

Function ColorAxisTraces(PlotName,Axis,ColorTable)
	String PlotName, Axis, ColorTable
	
	String TraceRGB, TraceName, ListOfTraces=AxisTraceListBG(PlotName, Axis,"")
	Variable i=0, j=0, r, g, b, NumTraces=ItemsInList(ListOfTraces)	
	
	for (i=0;i<NumTraces;i+=1)
		TraceRGB 	= ReturnColorTableRGB(NumTraces,i,0,ColorTable,0)
		TraceName 	= StringFromList(i,ListOfTraces)
		
		r = 10*str2num(StringFromList(0,TraceRGB,","))
		g = 10*str2num(StringFromList(1,TraceRGB,","))
		b = 10*str2num(StringFromList(2,TraceRGB,","))	
		
		ModifyGraph /W=$PlotName rgb($TraceName)=(r,g,b)
		
		j += 1
	endfor
End

Function LoadFTIRBands()
	
	if (CheckPathToFTIRBands() == 0)
		return 0
	endif
	
	Variable i, NSpecies
	
	String OldDf, FTIRFileList, FTIRName
	OldDf 	= GetDataFolder(1)
	NewDataFolder /O/S root:SPECTRA:FTIR
		String /G gFTIRSpeciesList="none;"
	
		FTIRFileList 	= IndexedFile($"FTIRPath", -1, ".itx")
		NSpecies 		= ItemsInList(FTIRFileList)
		
		for (i=0;i<NSpecies;i+=1)
			FTIRName 	= StringFromList(i,FTIRFileList)
			if (StringMatch(FTIRName,"FTIR_*") == 1)
				LoadWave /Q/O/T/P=FTIRPath FTIRName
				gFTIRSpeciesList 	= gFTIRSpeciesList + ReplaceString("FTIR_",StripSuffixBySeparator(FTIRName,"."),"") + ";"
			endif
		endfor
		
	SetDataFolder $OldDF
End

Function CheckPathToFTIRBands()
	
	String OSType
	
	PathInfo FTIRPath
	if (!V_flag)
		// Path doesn't exist. Try default location. 
		OSType = stringbykey("OS", IgorInfo(3)) 
		if (StrSearch(OSType,"Windows",0) > -1)
			// This path should function for a generic PC. 
	        	NewPath /Z/O/Q FTIRPath "C:\Program Files\Wavemetrics\Igor Pro 6 Folder\User Procedures\WAXS ATOMIC FORM FACTORS"
	         else
	       	// This path should function for a generic Mac. 	
			NewPath /Z/O/Q FTIRPath "Macintosh HD:Applications:Igor Pro 6.1:User Procedures:WAXS ATOMIC FORM FACTORS:"
		endif
	else 
		return 1
	endif

	PathInfo FTIRPath
	if (!V_flag)
		// Need user help to locate the proper location. 
		NewPath /Q/O/Z/M="Please locate the FTIR reference" FTIRPath
		if (V_flag != 0)		// User cancelled
			return 0
		else
			return 1
		endif
	else
		return 1
	endif
End