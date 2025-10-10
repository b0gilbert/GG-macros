#pragma rtGlobals=1		// Use modern global access method.

Function MaskCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	String PlotName = WinName(0,65)
	String PlotFolderName 	= "root:SPECTRA:Plotting:" + PlotName
	SVAR gSelection1 		= $(PlotFolderName+":gSelection1")
	NVAR gUseMaskFlag		= $(PlotFolderName+":gUseMaskFlag")
	
	String TraceName, TraceList 	= TraceNameList(PlotName, ";", 1)
	
	if ((cmpstr("_all_",gSelection1) == 0) || cmpstr("_none_",gSelection1) == 0)
		TraceName 	= StringFromList(0,TraceNameList(PlotName, ";", 1))
	else
		TraceName 	= gSelection1
	endif
	
	WAVE axis 			= $GetWavesDataFolder(XWaveRefFromTrace(PlotName,TraceName),2)
	
	if (checked == 0)
		gUseMaskFlag = 0
		Button MASK2_PLOT_EditMaskButton, disable=1
		TabControlOfPlotControls(3,3,"MASK3*",PlotName,1)
		RemoveFromGraph /Z/W=$PlotName mask
	endif
	
	if (checked == 1)
		gUseMaskFlag = 1
		
		// Make the maskvalues wave if needed. 
		WAVE maskvalues 	= $(PlotFolderName+":maskvalues")
		if (waveexists(maskvalues) == 0)
			Make /O/D/N=0 $(PlotFolderName+":maskvalues")
		endif
		
		// Make the mask and invmask waves if needed 
		MaskFromMaskValues(axis,PlotFolderName,PlotFolderName)
		
		DisplayMaskBeneathData(PlotName,PlotFolderName,TraceName)
		Button MASK2_PLOT_EditMaskButton, disable=0
	endif
End

// 	NOTES: The MaskValues are stored in the Plotting:Mask folder.
// 	NOTES: The mask and invmask waves are stored into the Plot Folder.  

// *************************************************************
// ****		MASKING DATA - Main approach is to create list of axis value pairs
// *************************************************************
//
// NOTE: For clearer labeling of plots, "mask" is the displayed mask; "invmask" is used during fitting
//
Function MaskFromMaskValues(axis,MaskFolder,MaskValuesFolder)
	Wave axis
	String MaskFolder, MaskValuesFolder
	
	Variable i, NSections, NPts
	
	WAVE maskvalues 	= $(MaskValuesFolder+":maskvalues")
	WAVE mask 			= $(MaskFolder+":mask")
	WAVE invmask 		= $(MaskFolder+":invmask")
	
	NPts = DimSize(axis,0)
	NSections=DimSize(maskvalues,0)/2
	
	if (!WaveExists(mask))
		Make /O/N=(NPts) $(MaskFolder+":invmask") /WAVE=invmask
		Make /O/N=(NPts) $(MaskFolder+":mask") /WAVE=mask
	elseif (DimSize(mask,0) != NPts)
		Redimension /N=(NPts) mask, invmask
	endif
	
	invmask=1
	
	if (NSections == 0)
		mask =0
		return 0
	endif
	
	if ((CheckEvenVariable(2*NSections) == 1) && (NSections>0))
		Variable StartIdx, StopIdx, SkipSection
		for (i=0;i<NSections;i+=1) 
			SkipSection	= 0
			
			StartIdx 	= AxisValueToPoint(axis, maskvalues[2*i])
			StopIdx 		= AxisValueToPoint(axis, maskvalues[2*i+1])
			
			invmask[StartIdx,StopIdx] = 0
		endfor
		mask = 1-invmask
	endif
End

Function MaskValuesFromMask(axis,MaskFolder,MaskValuesFolder)
	Wave axis
	String MaskFolder, MaskValuesFolder
	
	Variable i=0, NSections=0, BIG=2e9
	
	WAVE mask 			= $(MaskFolder+":mask")
	
	Duplicate /O mask, $(MaskFolder+":invmask")
	WAVE invmask 		= $(MaskFolder+":invmask")
	invmask = 1-mask
	
	Make /O/N=0 $(MaskValuesFolder+":maskvalues")
	WAVE maskvalues 	= $(MaskValuesFolder+":maskvalues")
	
	do
		FindValue /V=1/T=0.01/S=(i) mask
		if (V_value > -1)
			NSections += 1
			ReDimension /N=(2*NSections) maskvalues
			maskvalues[2*(NSections-1)] = axis[V_value]
			
			FindValue /V=0/T=0.01/S=(V_value) mask
			if (V_value > -1)
				maskvalues[2*(NSections-1) + 1] = axis[V_value-1]
			else
				maskvalues[2*(NSections-1) + 1] = axis[BIG]
				break
			endif
			i = V_value
		else
			break
		endif
	while(1)
End

Function DisplayMaskBeneathData(PlotName,PlotFolderName,TraceName)
	String PlotName,PlotFolderName,TraceName
	
	NVAR 	gUseMaskFlag 	= $("root:SPECTRA:Plotting:"+PlotName+":gUseMaskFlag")
	if (gUseMaskFlag == 0)
		return 0
	endif
	
	if ((cmpstr("_all_",TraceName) == 0) || cmpstr("_none_",TraceName) == 0)
		TraceName 	= StringFromList(0,TraceNameList(PlotName, ";", 1))
	endif
	
	WAVE axis 			= $GetWavesDataFolder(XWaveRefFromTrace(PlotName,TraceName),2)
	WAVE data 			= $GetWavesDataFolder(TraceNameToWaveRef(PlotName,TraceName),2)
	
	WAVE maskvalues = $(PlotFolderName+":maskvalues")
	if (waveexists(maskvalues) == 0)
		return 0
	elseif (numpnts(maskvalues) == 0)
		return 0
	endif
	
	MaskFromMaskValues(axis,PlotFolderName,PlotFolderName)
	
	WAVE mask	= $(PlotFolderName + ":mask")
	CheckDisplayed /W=$PlotName mask
	if (V_flag == 1)
		RemoveFromGraph /W=$PlotName mask
	endif
	
	AppendToGraph/L=MaskAxis mask vs axis
	SetAxis MaskAxis, 0, 1
	ModifyGraph axThick(MaskAxis)=0, noLabel(MaskAxis)=2
	ModifyGraph mode(mask)=5, hbFill(mask)=2
	ModifyGraph rgb(mask)=(52428,52428,52428)
	
	ReorderTraces $(StringFromList(0,TraceNameList(PlotName,";",1))),{mask}
End

Function MaskRegionButtons(ctrlName) : ButtonControl
	String ctrlName
	
	Variable CsrA, CsrB, CsrAValue, CsrBValue, MaskMin, MaskMax, MaskNm
	String MaskValuesName, PlotName = WinName(0,65)
	String PlotFolderName 	= "root:SPECTRA:Plotting:" + PlotName
	String MaskFolderName	= "root:SPECTRA:Plotting:Mask"
	
	SVAR TraceName 	= $(PlotFolderName+":gSelection1")
	String TraceList 	= TraceNameList(PlotName, ";", 1)
	Variable TraceNum 	= WhichListItem(TraceName,TraceList)
	
	if (cmpstr(ctrlName,"MASK2_PLOT_EditMaskButton") == 0)
		if (TraceNum == -1)
			DoAlert 0, "Please select a trace to mask"
			return 0
		endif
		
		TabControlOfPlotControls(3,3,"MASK2*",PlotName,1)
		TabControlOfPlotControls(3,3,"MASK3*",PlotName,0)
		return 1
	
	elseif (cmpstr(ctrlName,"MASK2_PLOT_MaskPoly2DataButton") == 0)
		MaskedPolyValuesToData()
		return 1
	endif
	
	WAVE axis 		= $GetWavesDataFolder(XWaveRefFromTrace(PlotName,TraceName),2)
	WAVE data 		= $GetWavesDataFolder(TraceNameToWaveRef(PlotName,TraceName),2)
		
	WAVE mask 		= $(PlotFolderName+":mask")
	WAVE invmask 	= $(PlotFolderName+":invmask")
	
	
	// The buttons to mask or unmask a portion of the data. Typically the first buttons to be used for masking. 
	if ((cmpstr(ctrlName,"MASK3_PLOT_MaskButton") == 0) || (cmpstr(ctrlName,"MASK3_PLOT_UnMaskButton") == 0))
	
		if ((CsrIsOnPlot("","A") == 0) || (CsrIsOnPlot("","B") == 0))
			return 0
		endif
		
		// Find the x-axis positions of the cursors. 
		CsrAValue 	= GetCursorPositionOrValue(PlotName,"A",1)
		CsrBValue 	= GetCursorPositionOrValue(PlotName,"B",1)
		
		MaskMin 	= min(CsrAValue,CsrBValue)
		MaskMax 	= max(CsrAValue,CsrBValue)
		
		CsrA 		= AxisValueToPoint(axis, MaskMin)
		CsrB 		= AxisValueToPoint(axis, MaskMax)
		
		if (StrSearch(ctrlname,"UnMask",0) > -1)
			mask[CsrA,CsrB] = 0
		elseif (StrSearch(ctrlname,"Mask",0) > -1)
			mask[CsrA,CsrB] = 1
		endif
		
		MaskValuesFromMask(axis,PlotFolderName,PlotFolderName)
		DisplayMaskBeneathData(PlotName,PlotFolderName,TraceName)
		
		return 1
	endif
	
	
	// Skip all other button functions if no mask is displayed. 
//	CheckDisplayed /W=$PlotName mask
//	if (V_flag == 0)
//		return 0
//	endif
	
	
	if (cmpstr(ctrlName,"MASK3_PLOT_UpdateMaskButton") == 0)

		// Update the plot maskvalues with the displayed mask. 
		MaskValuesFromMask(axis,PlotFolderName,PlotFolderName)
		
		// Save the mask to disk. 
		TabControlOfPlotControls(3,3,"MASK2*",PlotName,0)
		TabControlOfPlotControls(3,3,"MASK3*",PlotName,1)
		
	elseif (cmpstr(ctrlName,"MASK3_PLOT_CancelMaskButton") == 0)
		MaskFromMaskValues(axis,PlotFolderName,PlotFolderName)
		TabControlOfPlotControls(3,3,"MASK2*",PlotName,0)
		TabControlOfPlotControls(3,3,"MASK3*",PlotName,1)
		
	elseif (cmpstr(ctrlName,"MASK3_PLOT_KeepButton") == 0)
		// Save the plotted mask to the Mask folder, for later recall. 
		MaskValuesFromMask(axis,PlotFolderName,MaskFolderName)
		
		// Update the plot maskvalues with the displayed mask. 
		MaskValuesFromMask(axis,PlotFolderName,PlotFolderName)
		
		// Close the Mask options. 
		TabControlOfPlotControls(3,3,"MASK2*",PlotName,0)
		TabControlOfPlotControls(3,3,"MASK3*",PlotName,1)
	
	elseif (cmpstr(ctrlName,"MASK3_PLOT_RecallButton") == 0)
		// Recall the mask values from the Plotting:Mask folder
		MaskFromMaskValues(axis,PlotFolderName,MaskFolderName)
		MaskValuesFromMask(axis,PlotFolderName,PlotFolderName)
		DisplayMaskBeneathData(PlotName,PlotFolderName,TraceName)
		
	elseif (cmpstr(ctrlName,"MASK3_PLOT_SaveButton") == 0)
	
		// Update the plot maskvalues with the displayed mask. 
		MaskValuesFromMask(axis,PlotFolderName,PlotFolderName)
		
		// Save the mask to disk. 
		if (WaveExists(maskvalues) == 1)
			Save /I/C/O/P=home maskvalues as "maskvalues.ibw"
		endif
		
		// Close the Mask options. 
		TabControlOfPlotControls(3,3,"MASK2*",PlotName,0)
		TabControlOfPlotControls(3,3,"MASK3*",PlotName,1)
	
	elseif (cmpstr(ctrlName,"MASK3_PLOT_ImportButton") == 0)
		Loadwave /Q/D/H ""
		MaskValuesName 	= StringFromList(0,S_waveNames)
		
		WAVE maskvalues 	= $(MaskValuesName)
		if (WaveExists(maskvalues) == 1)
			Duplicate /O maskvalues, $(PlotFolderName+":maskvalues")
		
			MaskFromMaskValues(axis,PlotFolderName,PlotFolderName)
		endif
		KillWavesFromList(S_waveNames,1)
	endif
End


// Essentially a de-glitching routine. The polynomial must have been created and plotted; the cursors 
// must be on the gSelection1 trace
Function MaskedPolyValuesToData()
	
	String PlotName = WinName(0,65)
	String PlotFolderName 	= "root:SPECTRA:Plotting:" + PlotName
	SVAR TraceName 		= $(PlotFolderName+":gSelection1")
	NVAR MaskFlag			= $(PlotFolderName+":gUseMaskFlag")
	
	String TraceList = TraceNameList(PlotName, ";", 1)
	Variable i, TraceNum = WhichListItem(TraceName,TraceList)
	if (TraceNum == -1)
		return 0
	endif
	
	String ACsrTrace 	= StringByKey("TNAME",CsrInfo(A,PlotName))
	if (cmpstr(TraceName,ACsrTrace) != 0)
		return 0
	endif
	
	String BCsrTrace 	= StringByKey("TNAME",CsrInfo(B,PlotName))
	if (cmpstr(TraceName,BCsrTrace) != 0)
		return 0
	endif
	
	WAVE mask			= $GetWavesDataFolder(TraceNameToWaveRef(PlotName,"mask"),2)
	WAVE polynomial	= $GetWavesDataFolder(TraceNameToWaveRef(PlotName,"polynomial"),2)
	CheckDisplayed /W=$PlotName polynomial, mask
	if (V_flag == 0)
		return 0
	endif
	
	WAVE axis 	= $GetWavesDataFolder(XWaveRefFromTrace(PlotName,TraceName),2)
	WAVE data 	= $GetWavesDataFolder(TraceNameToWaveRef(PlotName,TraceName),2)
	
	Variable CsrMin 	= min(pcsr(A,PlotName),pcsr(B,PlotName))
	Variable CsrMax 	= max(pcsr(A,PlotName),pcsr(B,PlotName))
		
	for (i=CsrMin;i<CsrMax;i+=1)
		if (mask[i] == 1)
			data[i] = polynomial[i]
		endif
	endfor
End











// Open and plot a binary QSQ file
//Function LoadIgorBinWAXSData(ctrlname):ButtonControl
//	String ctrlname
//	
//	KillTracesWithMatchStr("","io_")
//	
//	String DataType 		= ctrlname[0,2]
//	String DataPathName	= DataType+"Path"
//	
//	PathInfo /S $DataPathName
//	if (V_flag==1)
//		Loadwave /Q/D/H/P=$DataPathName ""
//	else
//		Loadwave /Q/D/H ""
//	endif
//	NewPath /Q/O/Z $DataPathName, S_path
//	
//	String ImportName, Prefix = "io_" + DataType
//	
//	if (cmpstr(S_filename[0,5],Prefix)==0)
//		ImportName=StringFromList(0,S_waveNames)
//		if (cmpstr("XRD",DataType) == 0)
//			AppendToGraph /R $ImportName
//			ModifyGraph rgb($ImportName)=(1,16019,65535)
//		else
//			AppendToGraph $ImportName
//			ModifyGraph rgb($ImportName)=(1,52428,26586)
//		endif
//		
//		TextBox/C/N=LoadLegend/F=0/B=1/A=MC/X=-44.36/Y=29.94 "\\Z12\K(1,52428,26586)"+ReplaceString(Prefix+"_",ImportName,"")
//	endif
//End
//
//
//		X0				= 0
//		dX				= 0.0383495
//		FileName		= "io_PDF_"+gSampleName
//		WAVE Data		= $("PDF_"+gSampleName)
//	endif
	

