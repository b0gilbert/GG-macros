#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method.


//Menu "Spectra"
//	SubMenu "EEMs"
//		"Lamp Correct EEM"
//		"Close all EEMs"
//		"EEM Intensity"
//	End
//End

// *************************************************************


// *************************************************************
// ****		*!*!*! ROUTINES FOR LARRYHUTCHINSON
// *************************************************************

Function ExportEEMButton(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	SVAR gEEMList 		= root:SPECTRA:GLOBALS:gEEMList
	SVAR gEEMPath 		= root:SPECTRA:GLOBALS:gEEMPath
	
	String ctrlName 	= B_Struct.ctrlName
	String panelName 	= B_Struct.win
	Variable eventMod 	= B_Struct.eventMod
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif

	SVAR gColorScaleLabel 	= $("root:SPECTRA:Plotting:" + panelName + ":gIntensityLabel")
//	SVAR gColorScaleLabel 	= $("root:SPECTRA:Plotting:" + panelName + ":gColorScaleLabel")
	
	String SourceName,SourceFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	
	String PlotName
	
	if (cmpstr(ctrlName,"ExportEEMButton") == 0)
		SavePICT/Q=1/E=-6/B=288/WIN=$(PanelName+"#EEMPlot")/W=(0,0,500,400) as ReplaceString("_2D",SourceName,"")
	endif
End

// *************************************************************
// ****		Common routines to get Image information from PanelName
// *************************************************************

Function /T PanelSourceInformation(PanelName,SourceName,SourceFolder)
	String PanelName, &SourceName, &SourceFolder
	
	SourceName 	= StringByKey("SourceName",GetUserData(PanelName, "", ""),"=",";")
	SourceFolder 	= StringByKey("SourceFolder",GetUserData(PanelName, "", ""),"=",";")
	
	return ""
End

Function /T PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	String PanelName, &PanelFolder, &ImageName, &ImageFolder, &subWName, &ImageSubW
	
//	PanelFolder 	= "root:SPECTRA:Plotting:" + panelName
	PanelFolder 	= StringByKey("PanelFolder",GetUserData(PanelName, "", ""),"=",";")
	ImageName 		= StringByKey("ImageName",GetUserData(PanelName, "", ""),"=",";")
	ImageFolder 	= StringByKey("ImageFolder",GetUserData(PanelName, "", ""),"=",";")
	subWName 		= StringByKey("subWName",GetUserData(PanelName, "", ""),"=",";")
	
	// Argh! Incompatibility in EEM vs SPHINX routines. 
	// In EEMS, subWName is just the name of the subwindow. 
	// In SPHINX, subWName is already the PanelName + subwindow. 
	
	ImageSubW 		= PanelName + "#" + subWName
	GetWindow /Z $ImageSubW exterior
	if (V_flag != 0)
		ImageSubW 	= subWName
	endif
	
	return ""
End

Function /T ImageAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder)
	String PanelName, &Axis1Name, &Axis1Folder, &Axis2Name, &Axis2Folder
	
	Axis1Name 		= StringByKey("Axis1Name",GetUserData(PanelName, "", ""),"=",";")
	Axis1Folder 	= StringByKey("Axis1Folder",GetUserData(PanelName, "", ""),"=",";")
	Axis2Name 		= StringByKey("Axis2Name",GetUserData(PanelName, "", ""),"=",";")
	Axis2Folder 	= StringByKey("Axis2Folder",GetUserData(PanelName, "", ""),"=",";")
	
	return ""
End

Function /T CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	String PanelName, &Axis1Name, &Axis1Folder, &Axis2Name, &Axis2Folder, &HorzName, &VertName
	
	Axis1Name 		= StringByKey("CtrAxis1Name",GetUserData(PanelName, "", ""),"=",";")
	Axis1Folder 	= StringByKey("CtrAxis1Folder",GetUserData(PanelName, "", ""),"=",";")
	Axis2Name 		= StringByKey("CtrAxis2Name",GetUserData(PanelName, "", ""),"=",";")
	Axis2Folder 	= StringByKey("CtrAxis2Folder",GetUserData(PanelName, "", ""),"=",";")
	HorzName 		= StringByKey("HorzName",GetUserData(PanelName, "", ""),"=",";")
	VertName 		= StringByKey("VertName",GetUserData(PanelName, "", ""),"=",";")
	
	return ""
End

Function /T PanelAnnotationInfo(PanelName,ColorScaleName)
	String PanelName, &ColorScaleName
	
	ColorScaleName 	= StringByKey("Axis1Name",GetUserData(ColorScaleName, "", ""),"=",";")
	
	return ""
End

// ***************************************************************************
// **************** 		Finding and Listing Data Folders and Plotting Panels with EEM data
// ***************************************************************************

// Look through all the Data Load folders for EEM and Non-EEM data. 
Function /S ReturnEEMList(EEMFlag)
	Variable EEMFlag
	
	WAVE /T wDataList 	= root:SPECTRA:wDataList
	WAVE wDataGroup 	= root:SPECTRA:wDataGroup
	
	Variable i, NLoaded = numpnts(wDataGroup)
	String DataNote, DataType, DataName, EEMList = "none;", EEMPath = "none;"
	String ExcList = "none;", ExcPath = "none;"
	
	for (i=0;i<NLoaded;i+=1)
		WAVE DataWave 	= $("root:SPECTRA:Data:Load"+num2str(wDataGroup[i])+":"+wDataList[i])
		DataNote 			= Note(DataWave)
		DataType 			= StringByKey("Data type",DataNote,"=","\r")
		DataName 			= ReplaceString("_data",wDataList[i],"") + ";"
		
		if (cmpstr(DataType,"EEM") == 0)
			EEMList	= EEMList + DataName
			EEMPath 	= EEMPath + "root:SPECTRA:Data:Load"+num2str(wDataGroup[i])+":TwoD:"+ReplaceString("_data",wDataList[i],"_2D") + ";"
		elseif (!DataFolderExists("root:SPECTRA:Data:Load"+num2str(wDataGroup[i])+":TwoD"))
			ExcList 		= ExcList + DataName
			ExcPath 	= ExcPath + "root:SPECTRA:Data:Load"+num2str(wDataGroup[i])+":"+wDataList[i] + ";"
		endif
	endfor
	
	String /G root:SPECTRA:GLOBALS:gEEMList 	= EEMList
	String /G root:SPECTRA:GLOBALS:gEEMPath 	= EEMPath
	
	String /G root:SPECTRA:GLOBALS:gExcList 	= ExcList
	String /G root:SPECTRA:GLOBALS:gExcPath 	= ExcPath
	
	if (EEMFlag)
		return EEMList
	else
		return ExcList
	endif
End

// ***************************************************************************
// **************** 		If we have changed the Original 2D data we may wish to propogate that to the image plots
// ***************************************************************************
Function UpdatePlottedEEMs()
	
	Variable i, NPanels
	String PanelName, PanelNameList, DataMatrixList
	String SourceName,SourceFolder
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	
	PanelNameList = ImagePanelList("","EEMPlot","",0)
	DataMatrixList = ImagePanelList("","EEMPlot","",1)
	NPanels = ItemsInList(PanelNameList)
	
	for (i=0;i<NPanels;i+=1)
		PanelName 		= StringFromList(i,PanelNameList)
		
		PanelSourceInformation(PanelName,SourceName,SourceFolder)
		WAVE EEM 			= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)
		
		PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
		WAVE cEEM			= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
		
		cEEM 	= EEM
	endfor
End

// ***************************************************************************
// **************** 		Hooks for the Image and Contour panels and integrated plts. 
// ***************************************************************************
Function CloseAllEEms()
	
	Variable i, NPanels
	String PanelName, PanelNameList
	
	PanelNameList = ImagePanelList("","EEMPlot","",0)
	NPanels = ItemsInList(PanelNameList)
	
	for (i=0;i<NPanels;i+=1)
		PanelName 		= StringFromList(i,PanelNameList)
		
		if (cmpstr("StackBrowser",PanelName) == 0)
		elseif (cmpstr("ReferencePanel",PanelName) == 0)
		else
			DoWindow /K $PanelName
		endif
	endfor
End

// ***************************************************************************
// **************** 		Hooks for the Image and Contour panels and embedded plots. 
// ***************************************************************************

Function ImagePanelHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	Variable keyCode 	= H_Struct.keyCode
	Variable eventCode	= H_Struct.eventCode
	Variable Modifier 	= H_Struct.eventMod
	
	String PanelName 	= H_Struct.winName
	String PlotFolder 	= "root:SPECTRA:Plotting:" + PanelName
	
	// Delete the datafolder associated with the panel
	if (eventCode == 2)
		KillAllWavesInFolder(PlotFolder,"*")
		KillDataFolder $PlotFolder
		return 1
	endif
	
	return 0
End

// Unfortunately, I don't think plot hooks can capture if Image display is changed??
Function EEMPlotHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	Variable keyCode 		= H_Struct.keyCode
	Variable eventCode		= H_Struct.eventCode
	Variable Modifier 		= H_Struct.eventMod
	String cursorName 		= H_Struct.cursorName
	
	GetWindow $"" activeSW	// *!*! The only way to determine which subWindow is active. 
	String PanelName 		= ParseFilePath(0, S_value, "#", 0, 0)
	String subWName 		= ParseFilePath(0, S_value, "#", 1, 0)
	
	if ((eventCode == 7) && (cmpstr(cursorName,"A") == 0))
		if (cmpstr(PanelName,subWName) != 0)
			UpdateEEMCursors(PanelName,subWName)
		endif
	endif
	
	return 0
End

// ***************************************************************************
// **************** 			Routine for plotting and analysing excitation-emission matrix (EEM)
// ***************************************************************************

Function PlotEEMData(DataAndFolderName)
	String DataAndFolderName
	
	String DataFolder, AxisFolder, Data2DName,  AxisName, Axis2Name, Axis2DxName, Axis2DyName, XLabel2D, YLabel2D, ZLabel2D
	
	DataFolder 		= ParseFilePath(1,DataAndFolderName,":",1,0)
	Data2DName 	= AnyNameFromDataName(DataAndFolderName,"2D")
	
	// The proper x-axis
	AxisFolder 		= ParseFilePath(1,DataFolder,":",1,0)
	AxisName 		= AxisFolder + AnyNameFromDataName(ParseFilePath(3,DataAndFolderName,":",0,0),"axis")
	
	// The other axes
	Axis2Name 		= AnyNameFromDataName(DataAndFolderName,"axis2")
	Axis2DxName 	= AnyNameFromDataName(DataAndFolderName,"2Dx")
	Axis2DyName 	= AnyNameFromDataName(DataAndFolderName,"2Dy")
	
	XLabel2D 		= "Emission Wavelength (nm)"
	YLabel2D 		= "Excitation Wavelength (nm)"
	ZLabel2D 		= "Counts"
	
	Plot2DEEM($Data2DName, $AxisName, $Axis2Name, $Axis2DxName, $Axis2DyName, XLabel2D,YLabel2D,ZLabel2D)
End

Function UpdateEEMLabels(panelName,PlotFolder)
	String panelName, PlotFolder
	
	SVAR gIntensityLabel = $(PlotFolder + ":gIntensityLabel")

	ColorScale /W=$(panelName +  "#EEMPlot")/C/N=ColorScale0 gIntensityLabel
	Label /W=$(panelName +  "#EmissionPlot") left gIntensityLabel
	Label /W=$(panelName +  "#ExcitationPlot") bottom gIntensityLabel
End

// 	Try to make this as general as possible - the second generation approach relative to the Transient Absorption routines. 
// 	Include plot names as new inputs. 
Function Plot2DEEM(DataMatrix, Axis, Axis2,Axis2Dx,Axis2Dy,XLabel2D, YLabel2D, ZLabel2D)
	Wave DataMatrix, Axis, Axis2,Axis2Dx,Axis2Dy
	String XLabel2D, YLabel2D, ZLabel2D
	
	String DataName 		= NameOfWave(DataMatrix)
	String DataBGName 		= ReplaceString("_2D",DataName,"_2Dbg")
	
	String CheckTitle, OldDf = GetDataFolder(1)
	Variable NumX=numpnts(Axis), NumY=numpnts(Axis2)
	
	// Small size - allow expansion and contraction of the panel dimensions
	NewPanel /K=1/W=(637,44,1085,556) as "EEM Plot: " + NameofWave(DataMatrix)
	
	String PanelName 		= WinName(0,65)
	String PanelFolder 		= "root:SPECTRA:Plotting:" + PanelName
	
	// Hooks for the main panel, e.g., when killing plot. 
	SetWindow $PanelName, hook(PanelEEMHooks)=ImagePanelHooks
	// Hooks for the 2D plot subwindow - RECALL HOOKS ARE NOT SUB-WINDOW AWARE!!
	SetWindow $PanelName, hook(PlotEEMHooks)=EEMPlotHooks
		
	NewDataFolder/O/S $(PanelFolder)
//		String /G $DataName=DataName // <--- why this???
		
		// Duplicate the SOURCE data for display and processing
		Duplicate /O/D DataMatrix, $DataBGName /WAVE=DataBGMatrix
	
		// I need some global variables to control cursor positions and moves. 
		Variable /G gH1, gV1, gHWidth, gVWidth, gHStep, gVStep, gHNPts, gVNPts
		Variable /G gCsrAX, gCsrAY, gCsrBX, gCsrBY, gCsrCX, gCsrCY, gCsrDX, gCsrDY
		
		// I need global strings for changes in intensity units
//		String /G gColorScaleLabel="Counts"
		String /G gIntensityLabel=ZLabel2D
		
		// USER DATA: Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+"EEMPlot;"
		// Use these as general names for Image and two extracted plot subwindows
		SetWindow $PanelName,userdata+= "TwoDName="+"EEMPlot;"
		SetWindow $PanelName,userdata+= "ColorScaleName="+"EEMColorScale;"
		SetWindow $PanelName,userdata+= "VertName="+"ExcitationPlot;"
		SetWindow $PanelName,userdata+= "HorzName="+"EmissionPlot;"
		// The name of the plotted image for the Contrast routines (backwards compatible). 
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(DataBGMatrix)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(DataBGMatrix,1)+";"
		// A new convention for displaying 2D data. Distinguish between SOURCE Data in Load folders, and PROCESSED Data in Panel folder
		SetWindow $PanelName,userdata+= "SourceName="+NameOfWave(DataMatrix)+";"
		SetWindow $PanelName,userdata+= "SourceFolder="+GetWavesDataFolder(DataMatrix,1)+";"
		// Pointers to 2D axes for IMAGE plots
		SetWindow $PanelName,userdata+= "Axis1Name="+NameOfWave(Axis2Dx)+";"
		SetWindow $PanelName,userdata+= "Axis1Folder="+GetWavesDataFolder(Axis2Dx,1)+";"
		SetWindow $PanelName,userdata+= "Axis2Name="+NameOfWave(Axis2Dy)+";"
		SetWindow $PanelName,userdata+= "Axis2Folder="+GetWavesDataFolder(Axis2Dy,1)+";"
		// Pointers to 2D axes for CONTOUR plots
		SetWindow $PanelName,userdata+= "CtrAxis1Name="+NameOfWave(Axis)+";"
		SetWindow $PanelName,userdata+= "CtrAxis1Folder="+GetWavesDataFolder(Axis,1)+";"
		SetWindow $PanelName,userdata+= "CtrAxis2Name="+NameOfWave(Axis2)+";"
		SetWindow $PanelName,userdata+= "CtrAxis2Folder="+GetWavesDataFolder(Axis2,1)+";"
		// Additional useful information. 
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
	
		//  	-------- 	Display the *Background-Subtracted* EEM as a color Image Plot PLUS a Contour Image
		Display/W=(10,110,435,500)/HOST=# 
			// Display the matrix as an Image Plot
			AppendImage DataBGMatrix vs {Axis2Dx,Axis2Dy}
			ModifyGraph /W=# margin(left)=65,margin(bottom)=45,margin(top)=15,margin(right)=10,width=350
			ModifyImage /W=# $NameOfWave(DataBGMatrix) ctab= {*,*,Geo,0}
			
			// Additionally display the matrix as a Contour Plot
			AppendMatrixContour DataBGMatrix vs {Axis,Axis2}
			ModifyContour /W=# $NameOfWave(DataBGMatrix) rgbLines=(34952,34952,34952), labels=0
			RenameWindow #, EEMPlot
			
			// Display the Color Scale 
			WaveStats /Q/M=1 DataBGMatrix
//			ColorScale/C/N=ColorScale0/A=LT/X=-0.3/Y=-0.3  ctab={V_min,V_max,Geo,0} $"gColorScaleLabel"
			ColorScale/C/N=ColorScale0/A=LT/X=-0.3/Y=-0.3  ctab={V_min,V_max,Geo,0} $gIntensityLabel
			ColorScale/C/N=ColorScale0 heightPct=40, width=12, lblMargin=20
		SetActiveSubwindow ##
		
		// Extracted Emission Spectrum (horizontal axis)
		Make /O/D/N=(NumX) HzSpectrum, HzFit, HzResiduals, HzErrors
		HzSpectrum[] = DataBGMatrix[p][gCsrAX]
		HzFit = NaN; HzResiduals = NaN; HzErrors = NaN
		
		// Emission Spectrum waves for Raman normalization
		Make /O/D/N=(NumX) RmFit, RmMask, RmPeak
		RmFit = NaN; RmMask = 1; RmPeak = NaN
		
		Display/W=(10,515,435,735)/HOST=# HzSpectrum vs Axis
			ModifyGraph /W=# margin(left)=65,margin(bottom)=45,margin(right)=10
			ModifyGraph /W=# tick=2, mirror=1, lowTrip(left)=0.001
			ModifyGraph /W=# fSize=12, zero(left)=1
			// Append the ICA - LLS fit results
			AppendToGraph HzFit, HzResiduals vs Axis
//			AppendToGraph HzResiduals vs Axis
			ModifyGraph rgb(HzResiduals)=(34952,34952,34952),rgb(HzFit)=(0,0,65535)
			// Make a masking wave
			Make /O/D/N=(NumX) HzMask=nan
			AppendToGraph /L=MaskAxis HzMask vs Axis
			SetAxis MaskAxis, 0, 1
			ModifyGraph axThick(MaskAxis)=0, noLabel(MaskAxis)=2
			ModifyGraph mode(HzMask)=5, hbFill(HzMask)=2
			ModifyGraph rgb(HzMask)=(52428,52428,52428)
//			ReorderTraces spectrum,{HzMask}
			// Add the Raman normalization curves
			AppendToGraph RmFit, RmPeak vs Axis
			ModifyGraph lstyle(RmFit)=3,rgb(RmFit)=(3,52428,1)
			ModifyGraph mode(RmPeak)=7,hbFill(RmPeak)=5,rgb(RmPeak)=(2,39321,1)
			// Name this subwindow
			RenameWindow #, EmissionPlot
		SetActiveSubwindow ##
		
		// Extracted Excitation Spectrum (vertical axis)
		Make /O/D/N=(NumY) VtSpectrum, VtFit, VtResiduals, VtErrors
		VtSpectrum[] = DataBGMatrix[gCsrAX][p]
		
		Display/W=(450,110,710,500)/HOST=# VtSpectrum vs Axis2
			ModifyGraph /W=# margin(bottom)=45,margin(right)=10
			ModifyGraph /W=# tick=2, mirror=1, lowTrip(left)=0.001
			ModifyGraph /W=# fSize=12, tkLblRot(bottom)=-90
			ModifyGraph /W=# swapXY=1, zero(bottom)=1
			RenameWindow #, ExcitationPlot
		SetActiveSubwindow ##
				
		// Label all the axes
		Label /W=#EEMPlot left YLabel2D
		Label /W=#EEMPlot bottom XLabel2D
		Label /W=#EmissionPlot left ZLabel2D
		Label /W=#EmissionPlot bottom XLabel2D
		Label /W=#ExcitationPlot left YLabel2D
		Label /W=#ExcitationPlot bottom ZLabel2D
		
		NewAppendContrastControls(PanelName)
		
		ApplyStackContrast(PanelName)
		
		// Image plot check boxes
		CheckBox EEMContourCheck,pos={14,89},value=1,title="countour",proc=EEMContourDisplay
		CheckBox EEMInfoCheck,pos={77,89},value=0,title="info",proc=EEMCsrInfoDisplay
		CheckBox EEMSpectraCheck,pos={130,89},value=0,title="spectra",proc=EEMSpectraDisplay
	
		// The "A" cursor for extracting data from the 2D plot
		gCsrAX 	= trunc(NumX/2)
		gCsrAY 	= trunc(NumY/2)
		Cursor/P/I/H=1/C=(1,26214,0)/W=#EEMPlot A $NameOfWave(DataBGMatrix) gCsrAX,gCsrAY
		Cursor/P/H=2/S=2/C=(1,26214,0)/W=#EmissionPlot A $NameOfWave(HzSpectrum) gCsrAX
		Cursor/P/H=3/S=2/C=(1,26214,0)/W=#ExcitationPlot A $NameOfWave(VtSpectrum) gCsrAY
		
		// Label groups of controls
		GroupBox ICAGroup1,pos={457,0},size={158,81},fColor=(39321,1,1),title="Extract"
		GroupBox ICAGroup2,pos={133,0},size={133,81},fColor=(39321,1,1),title="Background subtraction"
		GroupBox ICAGroup3,pos={260,0},size={174,81},fColor=(39321,1,1),title="Intensity Corrections"
		
		// -----------------		Controls for Extracting Spectra and Trends
		Variable /G gExtractWidth 	= 1
		SetVariable EEMWidthSet,title="width",fSize=11,pos={460,58},limits={1,inf,2},size={70,18},value= $(PanelFolder+":gExtractWidth")
		Button ExtractHorzButton,pos={462,16}, size={70,18},fSize=13,proc=TwoDSpectraButtons,title="Emission"
		Button ExtractVertButton,pos={462,36}, size={70,18},fSize=13,proc=TwoDSpectraButtons,title="Excitation"
		Button ExtractLampButton,pos={539,36}, size={70,18},fSize=13,proc=TwoDSpectraButtons,title="Lamp"
		
		// -----------------		Simple EEM Data Processing - Select a "background" EEM for subtraction
		String /G gBGEEMChoice = "none"
		PopupMenu BGEEMMenu,fSize=12,pos={140,14},size={112,20},proc=BGEEMList,title=" ",mode=1,value=ReturnEEMList(1)
		
		Variable /G gBGEEMScale 	= 1
		SetVariable BGEEMScaleSetVar,title="bg scale",fSize=11,pos={140,36},limits={0,inf,0.01},size={114,16},value= $(PanelFolder+":gBGEEMScale"),proc=SetBGEEMScale
		Variable /G gEEMrms=0
//		ValDisplay EEMrmsDisplay pos={297,60},size={80,17}, title="rms",fSize=11,value=#(PanelFolder+":gEEMrms")
		Button AutoBGButton,pos={211,59}, size={45,18},fSize=13,proc=DiffEEMButtons,title="Auto"
		
		// -----------------		Simple EEM Data Processing - Select an Excitation Spectrum for EEM rescaling
//		Button RamanCorrEEMButton,pos={270,14}, size={45,18},fSize=13,proc=SaveScaleEEMButton,title="Raman"
//		Variable /G gEmLambda 	= 500
//		String /G gExcChoice = "none"
		PopupMenu CorrMenu,fSize=12,pos={270,14},size={112,20},proc=EEMCorrChoice,title=" ",mode=1,value="none;Raman;QS;"
				
		// -----------------		Save or duplicate changes to displayed EEM
		Button KeepScaleEEMButton,pos={276,35}, size={78,18},fSize=13,proc=SaveScaleEEMButton,title="Overwrite"
		Button SaveScaleEEMButton,pos={276,56}, size={78,18},fSize=13,proc=SaveScaleEEMButton,title="Duplicate"
		
		// -----------------		Simple EEM Data Processing - Select an Excitation Spectrum for EEM rescaling
//		Variable /G gEmLambda 	= 500
//		String /G gExcChoice = "none"
//		PopupMenu ExcMenu,fSize=12,pos={270,14},size={112,20},proc=ExcList,title=" ",mode=1,value=ReturnEEMList(0)
		
		// Image plot check boxes
		Variable /G gDiffEEMNorm 	= 0, gDiffEEMLevel 	= 0
//		CheckBox NormDiffEEMCheck,pos={145,61},value=0,title="Normalized", proc=DiffEEMChecks
		CheckBox LevelDiffEEMCheck,pos={142,61},value=0,title="Auto-level", proc=DiffEEMChecks
		
		Button ExportEEMButton,pos={194,88}, size={45,18},fSize=13,proc=ExportEEMButton,title="Export"
		
	SetDataFolder $(OldDf)
End

// *************************************************************
// ****		Calculate integrated intensity values for the entire or partial EEM regions. 
// *************************************************************

Function EEMIntensity()
	
	Variable i, NPanels, EmLambda, ExLambda, ExRange, EmRange
	String PanelName, DestWindow, PanelNameList, IntensityChoice, RegionChoice
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S root:SPECTRA:EEM
		Variable /G gEmLambda, gExLambda, gExRange, gEmRange
		String /G gIntensityChoice, gRegionChoice

		RegionChoice 	= gRegionChoice
		Prompt RegionChoice, "Area of EEM to integrate", popup, "full;rectangle;"
		IntensityChoice 	= gIntensityChoice
		Prompt IntensityChoice, "Integration choice", popup, "average;rms;"
		ExLambda 		= gExLambda
		Prompt ExLambda, "Excitation wavelength"
		EmLambda 		= gEmLambda
		Prompt EmLambda, "Emission wavelength"
		ExRange 		= gExRange
		Prompt ExRange, "Excitation range"
		EmRange 		= gEmRange
		Prompt EmRange, "Emission range"
		DoPrompt "Integrate intensity of plotted EEMs", IntensityChoice, RegionChoice, ExLambda, ExRange, EmLambda, EmRange
		if (V_flag)
			return 0
		endif
		
		gIntensityChoice 	= IntensityChoice
		gRegionChoice 		= RegionChoice
		gExLambda 			= ExLambda
		gEmLambda 			= EmLambda
		gExRange			= ExRange
		gEmRange 			= EmRange

	SetDataFolder $OldDf
	
	PanelNameList = ImagePanelList("","EEMPlot","",0)
	NPanels = ItemsInList(PanelNameList)
	
	for (i=0;i<NPanels;i+=1)
		PanelName 		= StringFromList(i,PanelNameList)
		
		if (cmpstr("StackBrowser",PanelName) == 0)
		elseif (cmpstr("ReferencePanel",PanelName) == 0)
		else
			CalculateEEMIntensity(panelName,IntensityChoice, RegionChoice,ExLambda,EmLambda,ExRange,EmRange)
		endif
	endfor
End

Function CalculateEEMIntensity(panelName,intChoice,regionChoice,Lex, Lem, dLex, dLem)
	String panelName, regionChoice, intChoice
	Variable Lex, Lem, dLex, dLem
	
//	String SourceName,SourceFolder
//	PanelSourceInformation(PanelName,SourceName,SourceFolder)
//	WAVE EEM 			= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)

	
	String Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName
	CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	WAVE Axis1 		= $(ParseFilePath(2,Axis1Folder,":",0,0) + Axis1Name)
	WAVE Axis2 		= $(ParseFilePath(2,Axis2Folder,":",0,0) + Axis2Name)
	
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	WAVE cEEM			= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	Duplicate /O/FREE cEEM, EEMMask
	EEMMask=0
	MakeEEMMask(cEEM,EEMMask,Axis1,Axis2)
	
	Variable x0, y0, x1, y1, i, j, int=0, npix=0, sqrFlag
	
	if (cmpstr(regionChoice,"full") == 0)
		x0 	= 0
		y0 	= 0
		x1 	= DimSize(Axis1,0)-1
		y1 	= DimSize(Axis2,0)-1
	else
		x0 	= BinarySearch(Axis1,Lem-dLem/2)
		y0 	= BinarySearch(Axis2,Lex-dLex/2)
		x1 	= BinarySearch(Axis1,Lem+dLem/2)
		y1 	= BinarySearch(Axis2,Lex+dLex/2)
		
		x0	= (x0 < 0) ? 0 : x0
		y0	= (y0 < 0) ? 0 : y0
		x1	= (x1 < 0) ? DimSize(Axis1,0)-1 : x1
		y1	= (y1 < 0) ? DimSize(Axis2,0)-1 : y1
	endif
	
	if (cmpstr(intChoice,"average")==0)
		sqrFlag = 0
	elseif (cmpstr(intChoice,"rms")==0)
		sqrFlag = 1
	endif
	
	for (i=x0;i<x1;i+=1)
		for (j=y0;j<y1;j+=1)
			if (EEMMask[i][j] == 0)
				if (sqrFlag == 1)
					int += cEEM[i][j]^2
				else
					int += cEEM[i][j]
				endif
				
				npix += 1
			endif
		endfor
	endfor
	
	int /= npix
	
	if (sqrFlag)
		int = sqrt(int)
		print ImageName,"rms = ",int,"from",npix,"pixels"
	else
		print ImageName,"average = ", int,"from",npix,"pixels"
	endif
	
	 
End

//	Equations for special regions of the EEM plot. 
// 	Upper bound: y = x
//	Lower bound: y = 0.5 x
//	Center of water Raman peak: 	y = 0.8 x  +  33.1
//	Upper bound of Raman peak: 		y = 0.8 x  +  33.1  +  10
//	Upper bound of Raman peak: 		y = 0.8 x  +  33.1  -  10

Function MakeEEMMask(EEM,EEMMask,Axis1,Axis2)
	Wave EEM,EEMMask,Axis1,Axis2
	
	Variable i, j, NEmPts=DimSize(Axis1,0), NExPts=DimSize(Axis2,0)
	
	for (i=0;i<NEmPts;i+=1)
		for (j=0;j<NExPts;j+=1)
			if (PointIsBetweenTwoLines(Axis1[i],Axis2[j],1,0,0.8,38) == 1)
				EEMMask[i][j] 	= 0		// Not masked
			elseif (PointIsBetweenTwoLines(Axis1[i],Axis2[j],0.8,28,0.5,0) == 1)
				EEMMask[i][j] 	= 0
			else
				EEMMask[i][j] 	= 1
			endif
		endfor
	endfor
End

Function PointIsBetweenTwoLines(Px,Py,m1,c1,m2,c2)
	Variable Px,Py,m1,c1,m2,c2
	
	// Vertical test	
	Variable P1y, P2y
	
	P1y = m1*Px+c1
	P2y = m2*Px+c2
	
	if ((Py<P1y) && (Py>P2y))
		return 1
	elseif ((Py>P1y) && (Py<P2y))
		return 1
	else
		return 0
	endif
End

// *************************************************************
// ****		Routines to correct the EEM using standard methods
// *************************************************************
Function EEMCorrChoice(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct	// POP-UP MENU	
	
	String panelName 		= PU_Struct.win
	Variable eventCode 		= PU_Struct.eventCode
	String PlotFolder 		= "root:SPECTRA:Plotting:" + panelName
	SVAR gCorrChoice 		= $("root:SPECTRA:Plotting:" + panelName + ":gCorrChoice")
	
	gCorrChoice 		= PU_Struct.popStr
	
	SVAR gIntensityLabel = $(PlotFolder + ":gIntensityLabel")
		
	if (cmpstr("none",PU_Struct.popStr) == 0)
		ResetDisplayed(PanelName)
		RamanCorrection(panelName,0)
		gIntensityLabel = "Counts"
		
	elseif (cmpstr("Raman",PU_Struct.popStr) == 0)
//	elseif (eventCode == 2) // Mouse up
		RamanCorrection(panelName,1)
		gIntensityLabel = "Raman corrected"

	elseif (cmpstr("QS",PU_Struct.popStr) == 0)
		DoAlert 0, "Quinine sulfate correction not yet implemented!"
		return 1
	
	endif
	
	UpdateEEMLabels(panelName,PlotFolder)
	
	return 1
End

Function RamanCorrection(panelName,FitFlag)
	String panelName
	Variable FitFlag
	
	String SourceName,SourceFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	WAVE EEM 			= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)
	
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	WAVE cEEM			= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	String Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName
	CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	WAVE Axis1 		= $(ParseFilePath(2,Axis1Folder,":",0,0) + Axis1Name)
	WAVE Axis2 		= $(ParseFilePath(2,Axis2Folder,":",0,0) + Axis2Name)
	
	// Update the cursors on the 2D plot - the extracted plots are automatically updated. 
	Variable CsrX 	= BinarySearch(Axis1,450)
	Variable CsrY 	= BinarySearch(Axis2,350)
	Cursor/I/P/W=$(panelName+"#"+subWName) A $ImageName CsrX, CsrY
	
	SpectraFrom2DPlot(cEEM,ImageFolder,panelName,CsrX,CsrY,3,0)
	
	WAVE HzSpectrum 	= $(ParseFilePath(2,ImageFolder,":",0,0) + "HzSpectrum")
	WAVE VtSpectrum 	= $(ParseFilePath(2,ImageFolder,":",0,0) + "VtSpectrum")
	WAVE RmFit 		= $(ParseFilePath(2,ImageFolder,":",0,0) + "RmFit")
	WAVE RmMask 		= $(ParseFilePath(2,ImageFolder,":",0,0) + "RmMask")
	WAVE RmPeak 		= $(ParseFilePath(2,ImageFolder,":",0,0) + "RmPeak")
	
	Variable RmnX1		 = BinarySearch(Axis1,374)
	Variable RmnX2		 = BinarySearch(Axis1,434)
	Variable MaskX1	 = BinarySearch(Axis1,384)
	Variable MaskX2	 = BinarySearch(Axis1,410)
	
	RmFit = NaN
	RmPeak = 0
	RmMask[MaskX1,MaskX2] 	= 0
	
	Variable /G gPolyCenterOffset 	= 400
	Make /FREE/D/N=4 PolyCoefs = 0.1^x
	
	if (FitFlag)
		FuncFit /Q PolynomialPart, PolyCoefs, HzSpectrum[RmnX1,RmnX2] /X=Axis1 /M=RmMask
		
		RmFit[RmnX1,RmnX2] = PolynomialPart(PolyCoefs,Axis1[p])
	
		RmPeak[RmnX1,RmnX2] 	= HzSpectrum[p] - RmFit[p]
		
		Variable RmArea 	= AreaXY(RmPeak,Axis1,MaskX1,MaskX2)
		print " 		*** The area under the water Raman peak is", RmArea
		
		cEEM /= RmArea
		HzSpectrum /= RmArea
		VtSpectrum /= RmArea
		RmPeak/=RmArea
		RmFit/=RmArea
	endif
End

// *************************************************************
// ****		Routines to correct the EEM based on a selected 1D excitation spectrum - NOT USED
// *************************************************************
Function ExcList(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct	// POP-UP MENU	
	
	String panelName 		= PU_Struct.win
	Variable eventCode 		= PU_Struct.eventCode
	String PlotFolder 		= "root:SPECTRA:Plotting:" + panelName
	SVAR gExcChoice 		= $("root:SPECTRA:Plotting:" + panelName + ":gExcChoice")
	
	gExcChoice 		= PU_Struct.popStr
		
	if (cmpstr("none",PU_Struct.popStr) == 0)
		// remove previously chosen excitation wave from the vertical plot
		
		EEMRescaling(panelName)
		return 0
	elseif (eventCode == 2) // Mouse up
		EEMRescaling(panelName)
		return 1
	endif
	
	return 0
End

Function EEMRescaling(panelName)
	String panelName
	
	String ExcSpecPath
	Variable i, NumRows, RowNum, ColNum, PntNum, EmLambda, ExLambda, Scaling
	Variable RefInt, EEMInt
	
	SVAR gExcList 			= root:SPECTRA:GLOBALS:gExcList
	SVAR gExcPath 			= root:SPECTRA:GLOBALS:gExcPath
	
	String SourceName,SourceFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	WAVE EEM 			= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)
	
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	WAVE cEEM			= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	String Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName
	CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	WAVE Axis1 		= $(ParseFilePath(2,Axis1Folder,":",0,0) + Axis1Name)
	WAVE Axis2 		= $(ParseFilePath(2,Axis2Folder,":",0,0) + Axis2Name)
	
	// Globals for the rescaling operation
	SVAR gExcChoice 		= $(PanelFolder + ":gExcChoice")
	NVAR gEmLambda 		= $(PanelFolder + ":gEmLambda")
	
	// Optional Image plot display rescaling
	NVAR gDiffEEMLevel 	= $(PanelFolder + ":gDiffEEMLevel")
	NVAR gImageMin 		= $(PanelFolder + ":gImageMin")
	NVAR gImageMax 		= $(PanelFolder + ":gImageMax")
	
	// The Excitation data - in the chosen Data Load folder
	ExcSpecPath 			= StringFromList(WhichListItem(gExcChoice,gExcList),gExcPath)
	WAVE ExcSpec 			= $(ExcSpecPath)
	WAVE ExcAxis 			= $(ReplaceString("_data",ExcSpecPath,"_axis"))
	
	// FREE waves to extract from the source EEM
	Make /FREE/D/N=(DimSize(EEM,0)) EmSpecFromEEM
	Make /FREE/D/N=(DimSize(EEM,1)) ExcSpecFromEEM
	
	// Data processing
	if (!WaveExists(ExcSpec))
		cEEM 	= EEM	// Reset the displayed EEM in case "none" is chosen
	else
		EmLambda 	= gEmLambda
		Prompt EmLambda, "Emission wavelength"
		DoPrompt "Rescaling to excitation scan", EmLambda
		if (V_flag)
			return 0
		endif
		gEmLambda 	= EmLambda
		
		// Extract a VERTICAL lineout for comparison with the chosen excitation data. 
		ColNum 	= BinarySearchInterp(Axis1,gEmLambda)
		ExcSpecFromEEM[] = EEM[ColNum][p]
		
		NumRows 	= DimSize(EEM,0)
		for (i=0;i<NumRows;i+=1)
			
			// Look up the Intensity value from the independent excitation spectrum
			ExLambda 	= Axis2[i]
			PntNum 	= BinarySearchInterp(ExcAxis,ExLambda)
			
			// Look up the Intensity value from the EEM. (Optional boxcar scaling?)
			EEMInt 		= EEM[ColNum][i]
			RefInt 		= ExcSpec[PntNum]
			Scaling 		= RefInt/EEMInt
			
			cEEM[][i] 	= Scaling * EEM[p][q]
		endfor
	endif
	
//	WaveStats /Q CEEMMatrix
//	gEEMrms 	= V_rms
	
	if (gDiffEEMLevel)
		Variable LevelMin, LevelMax,DisplayMin, DisplayMax
		DefaultLevels(PanelFolder,cEEM,LevelMin, LevelMax,DisplayMin, DisplayMax)
		gImageMin 	= DisplayMin
		gImageMax 	= DisplayMax
		 ApplyStackContrast(PanelName)
	endif
End

// *************************************************************
// ****		EEM panel controls for differential EEM creation
// *************************************************************

// Would be great to be able to tweak with a finer increment if shift key held. 
Function SetBGEEMScale(SV_Struct) 	// SET VARIABLE
	STRUCT WMSetVariableAction &SV_Struct 
	
	String panelName 	= SV_Struct.win
	String ctrlName 	= SV_Struct.ctrlName
	Variable varNum 	= SV_Struct.dval
	
	Variable eventCode 	= SV_Struct.eventCode
	if (eventCode == -1)
		return 0
	endif
	
	// What event codes? 
	EEMSubtraction(panelName)
	
	// if the spectra windows are showing, update them
	ControlInfo /W=$panelName EEMSpectraCheck
	if (V_Value)
		UpdateEEMCursors(PanelName,"EEMPlot")
	endif
End

Function BGEEMList(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct	// POP-UP MENU	
	
	String panelName 		= PU_Struct.win
	Variable eventCode 		= PU_Struct.eventCode
	String PlotFolder 		= "root:SPECTRA:Plotting:" + panelName
	SVAR gBGEEMChoice 	= $("root:SPECTRA:Plotting:" + panelName + ":gBGEEMChoice")
	
	gBGEEMChoice 		= PU_Struct.popStr
		
	if (cmpstr("none",PU_Struct.popStr) == 0)
		EEMSubtraction(panelName)
		return 0
	elseif (eventCode == 2) // Mouse up
		EEMSubtraction(panelName)
		return 1
	endif
	
	return 0
End

Function DiffEEMChecks(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	String panelName 	= CB_Struct.win
	String ctrlName		= CB_Struct.ctrlName
	Variable checked	= CB_Struct.checked
	Variable eventCode	= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	NVAR gDiffEEMNorm 	= $("root:SPECTRA:Plotting:" + panelName + ":gDiffEEMNorm")
	NVAR gDiffEEMLevel 	= $("root:SPECTRA:Plotting:" + panelName + ":gDiffEEMLevel")
	
		
	if (cmpstr(ctrlName,"LevelDiffEEMCheck") == 0)
		gDiffEEMLevel = checked
		if (checked)
			AutoScaleEEM(panelName)
		endif
	elseif (cmpstr(ctrlName,"NormDiffEEMCheck") == 0)
		gDiffEEMNorm = checked	// This is no longer used. 
		EEMSubtraction(panelName)
	endif
	
	return 1
End

// Optional Image plot display rescaling
Function AutoScaleEEM(panelName)
	String panelName
	
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	WAVE cEEM			= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	NVAR gImageMin 		= $(PanelFolder + ":gImageMin")
	NVAR gImageMax 		= $(PanelFolder + ":gImageMax")
	
	Variable LevelMin, LevelMax,DisplayMin, DisplayMax
	DefaultLevels(PanelFolder,cEEM,LevelMin, LevelMax,DisplayMin, DisplayMax)
	
	gImageMin 	= DisplayMin
	gImageMax 	= DisplayMax
	
	ApplyStackContrast(PanelName)
End

// *************************************************************
// ****		Permanently change the image data, or create a copy
// *************************************************************

Function SaveScaleEEMButton(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	SVAR gEEMList 		= root:SPECTRA:GLOBALS:gEEMList
	SVAR gEEMPath 		= root:SPECTRA:GLOBALS:gEEMPath
	
	String ctrlName 	= B_Struct.ctrlName
	String panelName 	= B_Struct.win
	Variable eventMod 	= B_Struct.eventMod
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	String PlotName
	
	if (cmpstr(ctrlName,"KeepScaleEEMButton") == 0)
		KeepDisplayed(PanelName,"")
	
	elseif (cmpstr(ctrlName,"SaveScaleEEMButton") == 0)
		DuplicateDisplayed(PanelName,"","_c")
		
	endif
End

// Copy the data in the Source Image to the Displayed Image. 
Function ResetDisplayed(PanelName)
	String PanelName
	
	SVAR gEEMList 			= root:SPECTRA:GLOBALS:gEEMList
	SVAR gEEMPath 			= root:SPECTRA:GLOBALS:gEEMPath
	
	String SourceName,SourceFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	WAVE EEM 			= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)
	
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	WAVE cEEM			= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	cEEM = EEM
End

// Copy the data in the Displayed Image to the Source Image. 
Function KeepDisplayed(PanelName,ProcessNote)
	String PanelName, ProcessNote
	
	String SourceName,SourceFolder,PanelFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	
	String ImageName,ImageFolder,subWName,EEMPlot
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName,EEMPlot)
	
	WAVE source 	= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)
	WAVE displayed 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	DoAlert 1, "Overwrite source data?"
	if (V_flag == 2)
		return 0
	endif
	
	source 	= displayed
End

Function DuplicateDisplayed(PanelName,ProcessNote,suffix)
	String PanelName, ProcessNote, suffix
	
	String SourceName,SourceFolder,PanelFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	
	String ImageName,ImageFolder,subWName,EEMPlot
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName,EEMPlot)
	
	String Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName
	CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	
	WAVE DataMatrix 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	WAVE Axis1 		= $(ParseFilePath(2,Axis1Folder,":",0,0) + Axis1Name)
	WAVE Axis2 		= $(ParseFilePath(2,Axis2Folder,":",0,0) + Axis2Name)
	
	String DataType, DataNote, SampleName
	
	DataNote 	= "Copy of "+SourceName+"\rProcessing steps:\r"+ProcessNote
	DataType 	= StringByKey("Data type",Note(DataMatrix),"=","\r")
	DataNote 	= DataNote + "Data type=" + DataType
	
	SampleName = ReplaceString("_2D",SourceName,"")+suffix
	
	LoadSingle2DPlot(SampleName,DataNote,DataMatrix,Axis2,Axis1)
End

// *************************************************************
// ****		Routines to create DIFFERENTIAL EEMs
// *************************************************************

Function DiffEEMButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	SVAR gEEMList 		= root:SPECTRA:GLOBALS:gEEMList
	SVAR gEEMPath 		= root:SPECTRA:GLOBALS:gEEMPath
	
	String ctrlName 	= B_Struct.ctrlName
	String panelName 	= B_Struct.win
	Variable eventMod 	= B_Struct.eventMod
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	// These lines compress the looking up of various wave references relative to the manual subtraction routine below 
	String SourceName,SourceFolder,PanelFolder,cEEMName,cEEMFolder,subWName,EEMPlot
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	PanelImageInformation(PanelName,PanelFolder,cEEMName,cEEMFolder,subWName,EEMPlot)
	
	SVAR gBGEEM 	= $(PanelFolder + ":gBGEEMChoice")
	NVAR gBGScale 	= $(PanelFolder + ":gBGEEMScale")
	WAVE cEEM 	= $(ParseFilePath(2,cEEMFolder,":",0,0) + cEEMName)
	WAVE EEM 		= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)
	WAVE bgEEM 	= $(StringFromList(WhichListItem(gBGEEM,gEEMList),gEEMPath))
	
	if (cmpstr(gBGEEM,"none") != 0)
		Duplicate /O/D EEM, root:EEM2
		Duplicate /O/D cEEM, root:cEEM2
		
		Optimize /Q/X={1} DifferenceEEM, bgEEM
		gBGScale 	= V_minloc
		
		KillWaves /Z root:EEM2, root:cEEM2
	endif
End

Function DifferenceEEM(bgEEM,bgScale)
	Wave bgEEM
	Variable bgScale
	
	WAVE EEM 		= root:EEM2
	WAVE cEEM 	= root:cEEM2
	
	cEEM 	= EEM - bgScale*bgEEM
	
	WaveStats /Q cEEM
	
	return V_rms
End

Function DifferenceEEMMedia(bgEEM,bgScale)
	Wave bgEEM
	Variable bgScale
	
	WAVE EEM 		= root:EEM2
	WAVE cEEM 	= root:cEEM2
	WAVE roiEEM 	= root:roiEEM
	
	cEEM 	= EEM - bgScale*bgEEM - bgScale*bgEEM
	
	ImageStats /R=roiEEM cEEM
//	WaveStats /Q cEEM
	
	return V_rms
End

Function EEMSubtraction(panelName)
	String panelName
	
	SVAR gEEMList 			= root:SPECTRA:GLOBALS:gEEMList
	SVAR gEEMPath 			= root:SPECTRA:GLOBALS:gEEMPath
	
	String SourceName,SourceFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	WAVE EEM 			= $(ParseFilePath(2,SourceFolder,":",0,0) + SourceName)
	
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	WAVE cEEM			= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	String Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName
	CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	WAVE Axis1 		= $(ParseFilePath(2,Axis1Folder,":",0,0) + Axis1Name)
	WAVE Axis2 		= $(ParseFilePath(2,Axis2Folder,":",0,0) + Axis2Name)
	
	// Glbals for the rescaling operation
	NVAR gDiffEEMLevel 	= $(PanelFolder + ":gDiffEEMLevel")
	NVAR gBGEEMScale 		= $(PanelFolder + ":gBGEEMScale")
	SVAR gBGEEMChoice 	= $(PanelFolder + ":gBGEEMChoice")
//	SVAR gColorScaleLabel 	= $(PanelFolder + ":gColorScaleLabel")
	SVAR gIntensityLabel 	= $(PanelFolder + ":gIntensityLabel")
	
	// The Excitation data - in the chosen Data Load folder
	// The Background data - in the chosen Data Load folder
	WAVE bgEEM 			= $(StringFromList(WhichListItem(gBGEEMChoice,gEEMList),gEEMPath))
	
	// Data processing
	if (WaveExists(bgEEM))
		cEEM 	= EEM - gBGEEMScale * bgEEM
		
		gIntensityLabel 	= "ΔI"
	else
		cEEM 	= EEM
		gIntensityLabel 	= "Counts"
	endif
	
//	GetAxis
//	ColorScale /W=$ImageSubW/C/N=ColorScale0 trace=hello $gColorScaleLabel
	
//	if (strlen(ColorScaleName) > 0)
//		ColorScale /W=$ImageSubW/C/N=ColorScale0 ctab={gImageMin,gImageMax,,gInvertFlag} $gColorScaleLabel
//	endif
	
	if (gDiffEEMLevel)
		AutoScaleEEM(panelName)
	endif
End

// *************************************************************
// ****		EEM Panel checkboxes
// *************************************************************

// Toggle EEM contour display
Function EEMContourDisplay(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode	= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	String panelName 	= CB_Struct.win
	Variable checked	= CB_Struct.checked
	
	String PanelFolder,EEMName,ImageFolder,subWName,EEMPlot
	PanelImageInformation(PanelName,PanelFolder,EEMName,ImageFolder,subWName,EEMPlot)
	
	String Axis1Name,Axis1Folder,Axis2Name,Axis2Folder
	ImageAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder)
	
	WAVE EEMMatrix 	= $(ParseFilePath(2,PanelFolder,":",0,0) + EEMName)
	WAVE Axis1 		= $(ParseFilePath(2,Axis1Folder,":",0,0) + Axis1Name)
	WAVE Axis2 		= $(ParseFilePath(2,Axis2Folder,":",0,0) + Axis2Name)
	
	Variable plotted 	= (ItemsInList(ContourNameList(EEMPlot,";")) > 0) ? 1 : 0
	
	if (checked && !plotted)
		AppendMatrixContour /W=$EEMPlot EEMMatrix vs {Axis1,Axis2}
		ModifyContour /W=$EEMPlot $EEMName rgbLines=(34952,34952,34952), labels=0
	elseif (!checked && plotted)
		RemoveContour /W=$EEMPlot $EEMName
	endif
	
	return 1
End

// Toggle Info bar
Function EEMCsrInfoDisplay(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	String InfoStr
	String panelName 	= CB_Struct.win
	Variable checked	= CB_Struct.checked
	Variable eventCode	= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	showinfo
	if (checked)
		InfoStr = "ShowInfo /W="+PanelName+" /CP=0"
	else
		InfoStr = "HideInfo /W="+PanelName
	endif

	Execute/Q/Z InfoStr
	
	return 1
End

// Expand/Contract panel to show emission and excitation spectra. 
Function EEMSpectraDisplay(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	String InfoStr
	String panelName 	= CB_Struct.win
	Variable checked	= CB_Struct.checked
	
	Variable eventCode	= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	Variable x1, x2, y1, y2, w1=448, w2=729, h1=512, h2=746
	
	GetWindow $panelName, wsize
	x1 	= V_left
	y1 	= V_top
	
	if (!checked)
		CheckWindowPosition(panelName,x1,y1,x1+w1,y1+h1)
//		MoveWindow /W=$panelName x1,y1,x1+w1,y1+h1
	else
		CheckWindowPosition(panelName,x1,y1,x1+w2,y1+h2)
//		MoveWindow /W=$panelName x1,y1,x1+w2,y1+h2
	endif
	
	return 1
End



// *************************************************************
// ****		Adopt horizontal or vertical line scans
// *************************************************************
Function TwoDSpectraButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String panelName 	= B_Struct.win
	Variable eventMod 	= B_Struct.eventMod
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	Variable ShiftDown
	if ((eventMod & 2^1) != 0)	// Bit 1 = shift key down
		ShiftDown = 1
	endif
	
	String SourceName,SourceFolder
	PanelSourceInformation(PanelName,SourceName,SourceFolder)
	
	String PanelFolder,ImageName,ImageFolder,TwoDName,TwoDPath
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,TwoDName,TwoDPath)
	
	String Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName
	CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	
	WAVE DataMatrix 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	WAVE Axis 			= $(ParseFilePath(2,Axis1Folder,":",0,0) + Axis1Name)
	WAVE Axis2 		= $(ParseFilePath(2,Axis2Folder,":",0,0) + Axis2Name)
	
	NVAR gCsrAX 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "gCsrAX")
	NVAR gCsrAY 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "gCsrAY")
	NVAR gWidth 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "gExtractWidth")
	
	
	String SpectrumName, AdoptedName, AdoptNote, HorzPos, VertPos
	sprintf HorzPos, "%2.2f", Axis2[qcsr(A, TwoDPath)]
	sprintf VertPos, "%2.2f", Axis[pcsr(A, TwoDPath)]
	
	AdoptNote 	= "Lineout from "+ReplaceString("_2D",NameOfWave(DataMatrix),"")+", "
		
	if (cmpstr("ExtractHorzButton",ctrlName) == 0)
		SpectrumName 	= SourceName + "_" + HorzPos
		AdoptNote 		= AdoptNote + num2str(gWidth) + " pixel avg at " +num2str(Axis2[gCsrAY])+ " (" + num2str(Axis2[max(0,gCsrAY-((gWidth-1)/2))]) + " - " + num2str(Axis2[min(numpnts(Axis2)-1,gCsrAY+((gWidth-1)/2))]) + ")."
		AdoptedName 	= AdoptAxisAndDataFromMemory(Axis1Name,"",Axis1Folder,"HzSpectrum","",PanelFolder,SpectrumName,"",1,1,1)
	
	elseif (cmpstr("ExtractVertButton",ctrlName) == 0)
		SpectrumName 	= SourceName + "_" + VertPos
		AdoptNote 		= AdoptNote + num2str(gWidth) + " pixel avg at " +num2str(Axis[gCsrAX])+ " (" + num2str(Axis[max(0,gCsrAX-((gWidth-1)/2))]) + " - " + num2str(Axis[min(numpnts(Axis)-1,gCsrAX+((gWidth-1)/2))]) + ")."
		AdoptedName 	= AdoptAxisAndDataFromMemory(Axis2Name,"",Axis2Folder,"VtSpectrum","",PanelFolder,SpectrumName,"",1,1,1)
	
	elseif (cmpstr("ExtractLampButton",ctrlName) == 0)
		LampSpectrumFromEEM(DataMatrix,Axis2)
		
		SpectrumName 	= ReplaceString("_2D",SourceName,"") + "_Lamp"
		AdoptNote 		= "Lamp output data: Integration of the full range of emission intensity as a function of excitation wavelength from "+num2str(Axis[0])+"to"+num2str(Axis[DimSize(Axis,0)-1])+"nm. "
		AdoptedName 	= AdoptAxisAndDataFromMemory(Axis2Name,"",Axis2Folder,"LampCorrection","","root:SPECTRA:EEM:",SpectrumName,"",1,1,1)

	endif
	Note $AdoptedName, AdoptNote
End

// *************************************************************
// ****		Handle cursor moves on the Image plot, or the Horizontal or Vertical spectra
// *************************************************************

// If we standardize the naming of the EEM, Excitation and Emission plots in User Data, this could be a general approach. 
Function UpdateEEMCursors(PanelName,subWName)
	String PanelName,subWName
	
	String PanelFolder,ImageName,ImageFolder,TwoDName,ImagePlot
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,TwoDName,ImagePlot)
	
	String Axis1Name, Axis1Folder, Axis2Name, Axis2Folder, HorzName, VertName
	CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	
	String PlotFolder 	= "root:SPECTRA:Plotting:" + panelName
	NVAR gCsrAX 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrAX")
	NVAR gCsrAY 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrAY")
	NVAR gWidth 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gExtractWidth")
	
	Variable CsrAX=gCsrAX, CsrAY=gCsrAY
	
	if (cmpstr(subWName,TwoDName) == 0)
		CsrAX 	= pcsr(A, ImagePlot)
		CsrAY 	= qcsr(A, ImagePlot)
	elseif (cmpstr(subWName,HorzName) == 0)
		CsrAX 	= pcsr(A, ImagePlot)
	elseif (cmpstr(subWName,VertName) == 0)
		CsrAY 	= pcsr(A, ImagePlot)
	endif
	
	gCsrAX=CsrAX; gCsrAY=CsrAY
	
	// Update all the cursors on the 2D and extracted plots. 
	Cursor/I/P/W=$(panelName+"#"+subWName) A $ImageName gCsrAX, gCsrAY
	Cursor/P/W=$(panelName+"#"+HorzName) A HzSpectrum gCsrAX
	Cursor/P/W=$(panelName+"#"+VertName) A VtSpectrum gCsrAY
	
	WAVE DataMatrix 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
//	ExtractFrom2DPlot(DataMatrix,PlotFolder,panelName,gCsrAX,gCsrAY,gWidth,0)
	SpectraFrom2DPlot(DataMatrix,PlotFolder,panelName,gCsrAX,gCsrAY,gWidth,0)
End

// *************************************************************
// ****		Extract linescans from the 2D plot
// *************************************************************

Function LampSpectrumFromEEM(DataMatrix,Axis2)
	Wave DataMatrix, Axis2
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S root:SPECTRA:EEM
	
		Variable i, NumX=DimSize(DataMatrix,0), NumY=DimSize(DataMatrix,1)
		Make /O/D/N=(NumY) root:SPECTRA:EEM:LampCorrection /WAVE=Lamp
		
		for (i=0;i<NumY;i+=1)
			MatrixOp /O EEMRow = col(DataMatrix,i)
			ReDimension /N=(NumX) EEMRow
			WaveStats /Q/M=1 EEMRow
			Lamp[i] = V_avg
		endfor
	SetDataFolder $OldDf
End


Function SpectraFrom2DPlot(DataMatrix,PlotFolder,panelName,XPosition,YPosition,Width,Rescale)
	Wave DataMatrix
	String PlotFolder, panelName
	Variable XPosition,YPosition,Width,Rescale
	
	// The complete set of VERTICAL spectra
	WAVE VtSpectrum 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "VtSpectrum")
	
	// The complete set of HORIZONTAL spectra
	WAVE HzSpectrum 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "HzSpectrum")
	WAVE HzFit 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "HzFit")
	WAVE HzResids 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "HzResiduals")
	WAVE HzErrors 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "HzErrors")
	WAVE HzMask 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "HzMask")
	
	String ImageFolder 	= GetWavesDataFolder(DataMatrix,1)
	WAVE LLSFit 		= $(ParseFilePath(2,ImageFolder,":",0,0) + "LLSFit")
	WAVE LLSResids 	= $(ParseFilePath(2,ImageFolder,":",0,0) + "LLSResiduals")
	WAVE Axis 			= $(ParseFilePath(1,ImageFolder,":",1,0) + ReplaceString("_2D",NameOfWave(DataMatrix),"_axis"))
	
	Variable n, m=0, i, i1, i2, di = (Width-1)/2, j
	Variable MaxX=DimSize(DataMatrix,0)-1, MaxY=DimSize(DataMatrix,1)-1
	
	// Extract the VERTICAL SPECTRUM, skipping bad pixel NaN's
	VtSpectrum 	= 0
	i1 	= max(0,XPosition-di)
	i2 	= min(MaxX,XPosition+di)
	
	for (i=i1;i<=i2;i+=1)
		ImageStats /G={i,i,0,MaxY} DataMatrix
		if (numtype(V_avg) == 0)
			VtSpectrum[] 		+= DataMatrix[i][p]
			m += 1
		endif
	endfor
	VtSpectrum /= m
	
	// Extract the HORIZONTAL SPECTRUM
	HzSpectrum 	= 0
	HzFit 			= 0
	HzResids 		= 0
	
	n 	= 0
	i1 	= max(0,YPosition-di)
	i2 	= min(MaxY,YPosition+di)
	
	for (i=i1;i<=i2;i+=1)
		n += 1
		HzSpectrum[] 	+= DataMatrix[p][i]
		
		if (WaveExists(LLSFit))
			HzFit[] 		+= LLSFit[p][i]
			HzResids[] 	+= LLSResids[p][i]
		else
			HzFit[] 		= NaN
			HzResids[] 	= NaN
		endif
	endfor
	HzSpectrum /= n
	HzFit /= n
	HzResids /= n
	
	if (Rescale)
		Scale2DSpectrum(PanelName,HzSpectrum, HzFit, HzMask,Axis)
	endif
End

// ***************************************************************************
// **************** 			Routine for loading excitation-emission matrix (EEM)
// ***************************************************************************
//
//		We don't know ahead of time how many 2D data sets will be loaded. 
// 		Well plate locations are A, B, C ... horizontally and 1, 2, 3, .... vertically. 
//
//		FILE FORMAT ASSUMPTIONS:
//		- Try to impose a constant emission lambda axis
// 		- 

Function LoadEEM(EEMType,FileName,SampleName,NLoaded)
	String EEMType, FileName, SampleName
	Variable &NLoaded
	
	String DataName, DataNote
	Variable i, NEx,NEm
	
	if (cmpstr(EEMType,"Synergy") == 0)
		if (ImportFluorologEEM(FileName,DataNote,NEx,NEm) == 0)
			return 0
		endif
	elseif (cmpstr(EEMType,"Fluorolog") == 0)
		if (ImportSynergyEEM(FileName,DataNote,NEx,NEm) == 0)
			return 0
		endif
	endif
	
	WAVE /T EEMTitles 		= root:SPECTRA:Import:EEMTitles
	WAVE EEMMatrix 		= root:SPECTRA:Import:EEMMatrix
	WAVE ExWavelengths 	= root:SPECTRA:Import:ExWavelengths
	WAVE EmWavelengths 	= root:SPECTRA:Import:EmWavelengths
	WAVE Em1Wavelengths 	= root:SPECTRA:Import:Em1Wavelengths
	
	Make /O/D/N=(NEm,NEx) SingleEEM
	
	for (i=0;i<96;i+=1)
		SingleEEM[][] 	= EEMMatrix[p][q][i]
		WaveStats /Q/M=1 SingleEEM
		if (V_avg > 0)
			DataName 	= SampleName + "_" + EEMTitles[0][0][i]
			LoadSingle2DPlot(DataName,DataNote,SingleEEM,ExWavelengths,Em1Wavelengths)
		endif
	endfor
	
	String /G root:SPECTRA:GLOBALS:gEEMList=""
	String /G root:SPECTRA:GLOBALS:gEEMPath=""
	String /G root:SPECTRA:GLOBALS:gExcList=""
	String /G root:SPECTRA:GLOBALS:gExcPath=""
	
	KillWaves /A
End


// This is the 2D-data equivalent of SingleAxisDataErrorsFitLoad
Function LoadSingle2DPlot(SampleName,DataNote,SingleEEM,ExWavelengths,EmWavelengths)
	String SampleName, DataNote
	Wave SingleEEM,ExWavelengths,EmWavelengths
	
	Wave/T wDataList			= root:SPECTRA:wDataList
	Wave wDataSelection		= root:SPECTRA:wDataSel
	Wave wDataGroup			= root:SPECTRA:wDataGroup
	
	// ******* NUMBERING THE LOAD FOLDERS *******
	Variable NextLoadFolder 	= NextLoadFolderNumber()
	Variable NumLoaded 		= numpnts(wDataList)
	// *************************************
	
	SampleName 	= CleanUpDataName(SampleName)
	SampleName 	= AvoidDataNameConflicts(SampleName,"_r",wDataList)
	String SampleName2D 		= SampleName+"_2D"
	String AxisName 			= SampleName+"_axis"
	String Axis2Name 			= SampleName+"_axis2"
	String Axis2DName 			= SampleName+"_2Dx"
	String Axis2DName2		= SampleName+"_2Dy"
	String DataAvgName 		= SampleName+"_data"
	
	String LoadFolderPath 	= "root:SPECTRA:Data:Load" + num2str(NextLoadFolder)
	String OrigFolderPath 	= "root:SPECTRA:Data:Load" + num2str(NextLoadFolder)+":Originals"
	String TwoDFolderPath 	= "root:SPECTRA:Data:Load" + num2str(NextLoadFolder)+":TwoD"
	
	Make /O/D/N=(1) AxisX2D
	Make /O/D/N=(1) AxisY2D
	MakeAxisForImagePlot(EmWavelengths,AxisX2D)
	MakeAxisForImagePlot(ExWavelengths,AxisY2D)
	
	// Make an dummy data wave for display in the Plotting Panel
	MatrixOp /FREE temp = sumRows(SingleEEM)
	WaveStats /Q/M=1 temp
	if (V_npnts == 0)
		temp= 1
	endif
	Note /K temp, DataNote
	
	NewDataFolder /O $LoadFolderPath
		Duplicate /O/D EmWavelengths, $(ParseFilePath(2,LoadFolderPath,":",0,0) + AxisName)
		Duplicate /O/D temp, $(ParseFilePath(2,LoadFolderPath,":",0,0) + DataAvgName)
		
	NewDataFolder /O $TwoDFolderPath
		Note /K SingleEEM, DataNote	// <--- add Data Note to the 2D data as well. 
		Duplicate /O/D SingleEEM, $(ParseFilePath(2,TwoDFolderPath,":",0,0) + SampleName2D)
		Duplicate /O/D ExWavelengths, $(ParseFilePath(2,TwoDFolderPath,":",0,0) + Axis2Name)
		Duplicate /O/D AxisX2D, $(ParseFilePath(2,TwoDFolderPath,":",0,0) + Axis2DName)
		Duplicate /O/D AxisY2D, $(ParseFilePath(2,TwoDFolderPath,":",0,0) + Axis2DName2)
	
	NewDataFolder /O $OrigFolderPath
		DuplicateAllWavesInDataFolder(LoadFolderPath,OrigFolderPath,SampleName+"*",0)
		Duplicate /O/D SingleEEM, $(ParseFilePath(2,OrigFolderPath,":",0,0) + SampleName2D)

	// Update the list of loaded waves
	NumLoaded += 1
	ReDimension /N=(NumLoaded) wDataList
	ReDimension /N=(NumLoaded) wDataSelection, wDataGroup
	wDataList[NumLoaded-1] 		= SampleName+"_data"
	wDataSelection[NumLoaded-1] 	= 0
	wDataGroup[NumLoaded-1] 		= NextLoadFolder
	
	return 1
End

// 	This is the importer routine that makes one 3D array and 2 axis waves. 
Function ImportFluorologEEM(FileName,DataNote,NEx,NEm1)
	String FileName, &DataNote
	Variable &NEx, &NEm1
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	String PathAndFileName 	= gPath2Data + FileName 
	DataNote 					= FileName + "\r" + gPath2Data + "\r"
	DataNote 					+= DataNote + "Data type=EEM\r"
	
End

// 	This is the importer routine that makes one 3D array and 2 axis waves. 
Function ImportSynergyEEM(FileName,DataNote,NEx,NEm1)
	String FileName, &DataNote
	Variable &NEx, &NEm1
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	String PathAndFileName 	= gPath2Data + FileName 
	DataNote 					= FileName + "\r" + gPath2Data + "\r"
	DataNote 					= DataNote + "Data type=EEM\r"
	
	String EEMLine, EEMBrackets, EEMTitleList, EEMDataList, EEMEmList="", Str1, Str2, Str3
	Variable FileRefNum, FilePos, i=0, j=0, Lambda, EmStart,EmStop,EmStep, NEm, NPlates=96, Found=0
	
	KillWaves /Z ExWavelengths, EmWavelengths, EEMMatrix
	
	// Make the appropriate waves - UNSIGNED INTEGER
	Make /O/I/N=1000 ExWavelengths, EmWavelengths, Em1Wavelengths
	
	Open /R FileRefNum as PathAndFileName
	
	// First determine the number of EXCITATION and EMISSION wavelengths
	do
		FReadLine FileRefNum, EEMLine
		if (strlen(EEMLine) == 0)
			break	// End of file
		endif
		
		if (StrSearch(EEMLine,"Read:  ex",0) > -1)
			Found = 1
			
			// Record the excitation wavelength
			sscanf EEMLine,"%s\t%s  ex%u %s", Str1, Str2, Lambda, Str3
			ExWavelengths[i] 	= Lambda
			
			// Calculate and record the emission wavelengths
			EEMBrackets 		= ReturnStringInBrackets(EEMLine,"[","]")
			sscanf EEMBrackets,"%unm to %unm by %u", EmStart, EmStop, EmStep
			EmissionAxisList(EmStart,EmStop,EmStep,EEMEmList)
			
			if (i==0)
				// Record the FIRST list of emission wavelengths
				NEm1 	=  ItemsInList(EEMEmList)
				Redimension /I/N=(NEm1) Em1Wavelengths
				ListValuesToWave(Em1Wavelengths,EEMEmList,";",0)
			endif
			
			i += 1
		else
			if (Found)
				break	// No more 'Read' lines. 
			endif
		endif
	while(1)
	
	if (i == 0)
		return 0
	endif
	
	// A wave containing all the excitation wavelengths
	Nex = i
	Redimension /I/N=(NEx) ExWavelengths
	
	// A wave containing ALL the emission wavelengths
	Nem = ItemsInList(EEMEmList)
	Redimension /I/N=(NEm) EmWavelengths
	ListValuesToWave(EmWavelengths,EEMEmList,";",0)
	
	// Make a LARGE 3D matrix containing EEM data for all 96 samples
	// NOTE: Here we are forcing the EEMs to have the emission wavelengths for the FIRST spectrum
	Make /O/I/N=(NEm1,NEx,96) EEMMatrix=0
	
	// Make a 1x1x96 matrix for the data titles
	Make /O/T/N=(1,1,96) EEMTitles=""
	
	// Don't think this is necessary (and not set correctly)
//	FSetPos FileRefNum, FilePos
	
	// Loop through all the excitation wavelengths
	for (i=0;i<NEx;i+=1)
	
		// Find the start of the ith block of emission data. 
		Found = 0
		do
			FReadLine FileRefNum, EEMLine
			if (strlen(EEMLine) == 0)
				break	// End of file
			elseif (StrSearch(EEMLine,"Wavelength",0) > -1)
				EEMTitleList 		= ReplaceString("\t",EEMLine,";")
				EEMTitles[0][0][] 	= StringFromList(r+1,EEMTitleList)
				Found=1
				break 	// Start of emission data
			endif
		while(1)

		// Read in the data from the ith block of emission data. 
		do 
			FReadLine FileRefNum, EEMLine
			if (strlen(EEMLine) == 0)
				break	// End of file
			endif
			
			if (StrSearch(EEMLine,"nm",0) > -1)
				// Now, the EEMLine is one row containing up to 96 columns of data. 
				sscanf EEMLine,"%u nm%s", Lambda, Str3
				EEMDataList 	= ReplaceString("\t",EEMLine,";")
				FillEEMMatrix(EEMMatrix,Em1Wavelengths,i, Lambda,EEMDataList)
			else
				if (Found)
					break	// No more emission data lines. 
				endif
			endif
		while(1)
	endfor
	
	return 1
End

Function FillEEMMatrix(EEMMatrix,Em1Wavelengths,ExIndex, EmLambda,EEMDataList)
	Wave EEMMatrix, Em1Wavelengths
	Variable ExIndex, EmLambda
	String EEMDataList
	
	Variable n, EmIndex1, EmIndex2=-1, dLambda, Scale1, Scale2, Counts
	Variable Lambda0 = Em1Wavelengths[0]
	Variable LambdaN = Em1Wavelengths[numpnts(Em1Wavelengths)-1]
	
	// Find the location of the emission wavelength, OR the partial point location for interpolation
	// FindLevel will find the first and last values correctly but not a value outside that range. 
	FindLevel /P/Q Em1Wavelengths, EmLambda
	
	if (V_flag ==0)		// Wavelength lies within the range. 
		EmIndex1 = floor(V_LevelX)
		if (abs(EmIndex1 - V_LevelX) < 0.00001)
			// The value exactly matches a wavelength in the list. 
		else
			// The values lies between two wavelengths, so interpolation is needed. 
			EmIndex2 	= EmIndex1 + 1
			dLambda 	= (Em1Wavelengths[EmIndex2] - Em1Wavelengths[EmIndex1])
			Scale1 		= (EmLambda - Em1Wavelengths[EmIndex1])/dLambda
			Scale2 		= 1 - Scale1
		endif
	else
		// If we're outside the range, only include the data less than 10 nm away. 
		// The trouble is we need intensities at the last data point within the range!!
		if ((EmLambda < Lambda0) && (abs(EmLambda - Lambda0) < 10))
		
		elseif ((EmLambda > LambdaN) && (abs(EmLambda - LambdaN) < 10))
//			dLambda 	= LambdaN - EmLambda
//			Scale1 		= ???
//			Scale2 		= 1 - Scale1
		else
			return 0
		endif
		
			return 0
	endif
	
	
	for (n=1;n<97;n+=1) // Loop through 96 wells
		Counts 	= str2num(StringFromList(n,EEMDataList))
		if (numtype(Counts) == 0)
			if (EmIndex2 == -1)
				// Transfer the counts directly
				EEMMatrix[EmIndex1][ExIndex][n-1] = Counts
			else
				// Share the counts proportionally between the two neighboring wavelengths
				EEMMatrix[EmIndex1][ExIndex][n-1] += Scale1 * Counts
				EEMMatrix[EmIndex2][ExIndex][n-1] += Scale2 * Counts
			endif
		endif
	endfor
End

// Make a sorted list of all possible emission axis values with no duplicates. 
Function EmissionAxisList(EmStart,EmStop,EmStep,EmList)
	Variable EmStart,EmStop,EmStep
	String &EmList
	
	String NewEmList="", EmStr
	Variable n, NEm = 1 + (EmStop - EmStart)/EmStep
	
	for (n=0;n<NEm;n+=1)
		EmStr	= num2str(EmStart + n*EmStep)
		NewEmList += EmStr + ";"
	endfor
	
	// Compress and sort list of all emission wavelength values
	EmList = CompressList(EmList + NewEmList,1)
End

//Structure WMPopupAction 
//	char ctrlName[32]	 // Control name 
//	char win[200] 		// Host window or subwindow name 
//	Rect winRect 		// Local coordinates of host window 
//	Rect ctrlRect 		// Enclosing rectangle of the control 
//	Point mouseLoc 		// Mouse location 
//	Int32 eventCode 		// -1: Control being killed 
//							//  2: Mouse up 
//	Int32 eventMod 		// See Control Structure eventMod Field on page III-387 
//	String userData 		// Primary unnamed user data 
//	Int32 blockReentry 		// See Control Structure blockReentry Field on page III-388 
//	Int32 popNum 			// Item number currently selected (1-based) 
//	char popStr[400] 		// Contents of current popup item 
//EndStructure 















//Function LoadSynergyEEM(FileName,SampleName,NLoaded)
//	String FileName, SampleName
//	Variable &NLoaded
//	
//	String DataName, DataNote
//	Variable i, NEx,NEm
//	
//	if (ImportSynergyEEM(FileName,DataNote,NEx,NEm) == 0)
//		return 0
//	endif
//	
//	WAVE /T EEMTitles 		= root:SPECTRA:Import:EEMTitles
//	WAVE EEMMatrix 		= root:SPECTRA:Import:EEMMatrix
//	WAVE ExWavelengths 	= root:SPECTRA:Import:ExWavelengths
//	WAVE EmWavelengths 	= root:SPECTRA:Import:EmWavelengths
//	WAVE Em1Wavelengths 	= root:SPECTRA:Import:Em1Wavelengths
//	
//	Make /O/D/N=(NEm,NEx) SingleEEM
//	
//	for (i=0;i<96;i+=1)
//		SingleEEM[][] 	= EEMMatrix[p][q][i]
//		WaveStats /Q/M=1 SingleEEM
//		if (V_avg > 0)
//			DataName 	= SampleName + "_" + EEMTitles[0][0][i]
//			LoadSingle2DPlot(DataName,DataNote,SingleEEM,ExWavelengths,Em1Wavelengths)
//		endif
//	endfor
//	
//	String /G root:SPECTRA:GLOBALS:gEEMList=""
//	String /G root:SPECTRA:GLOBALS:gEEMPath=""
//	String /G root:SPECTRA:GLOBALS:gExcList=""
//	String /G root:SPECTRA:GLOBALS:gExcPath=""
//	
//	KillWaves /A
//End