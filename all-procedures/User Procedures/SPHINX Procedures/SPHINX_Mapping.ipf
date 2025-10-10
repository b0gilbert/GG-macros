#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method.

// *************************************************************
// ****		Prepare the matrices used for Single, Marque or ROI SVD analysis
// *************************************************************
//
//		Notes: 
// 		Make a 2D matrix of extracted spectra from the ROI
// 		The spectrum range will be set to be the one selected for SVD
// 			
//		

Function InitializeSVD(KillPanelFlag)
	Variable KillPanelFlag
	
	if (KillPanelFlag)
		DoWindow /K ReferencePanel
	endif
	
	String OldDf = GetDataFolder(1)
	
	NewDataFolder /O/S root:SPHINX
	NewDataFolder /O/S root:SPHINX:SVD
		
		RemoveRefsFromViewer()
		
		KillAllWavesInFolder("root:SPHINX:SVD","Ref_*")
		
		Make /O/N=0 DataMatrix, SolutionMatrix, ReferenceAxis, ReferenceScale, RefShiftAxis, RefShift
		Make /O/N=(0,0) ReferenceMatrix
		
		Make /O/T/N=0 ReferenceSpectra
		Make /O/T/N=(0,2)ReferenceDescription
		Make /O/N=(0,2) ReferenceSelection
		Make/O/N=0 nullWave
	
	SetDataFolder $(OldDf)
End


// *************************************************************
// ****		Managing Reference Spectra
// *************************************************************
Function ExportReferenceSpectra()
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	
	String EOLChar, SaveName, RefName, RefAxisName
	Variable i
	
	NewPath /Q/O/C/M="Location to save the reference spectra" RefsPath
	if (V_flag)
		return 0
	endif
	
	EOLChar = ReturnEOLCharacter(0,0)
	
	for (i=0;i<numpnts(RefList);i+=1)
		RefName		= RefList[i]
		RefAxisName 	= RefName+"_axis"
		
		WAVE Ref 		= $("root:SPHINX:SVD:"+RefName)
		WAVE RefAxis 	= $("root:SPHINX:SVD:"+RefAxisName)
		
		if (RefSelect[i][1] == 1)
			SaveName = RefDesc[i][1]
			Prompt SaveName, "Name for saving"
			DoPrompt "Exporting Reference", SaveName
			if (V_flag)
				return 0
			endif
			
			Save /O/W/J/M=EOLChar/P=RefsPath RefAxis, Ref as SaveName+".txt"
			
		endif
	endfor
End

Function ImportReferenceSpectrum(StackAxis)
	Wave StackAxis
	
	String LoadWaveList 	= InteractiveLoadTextFile("Please locate the reference spectrum")
	
	Variable i, InterpFlag, NCols, NRefs
	
	NCols = ItemsInList(LoadWaveList)
	if (NCols < 2)
		DoAlert 0, "Too few columns in text file"
		return 0
	endif
	NRefs = NCols-1
	
	WAVE axis 	= $(StringFromList(0,LoadWaveList))
	InterpFlag 	= (EqualWaves(axis,StackAxis,1) == 1) ? 0 : 1
	
	for (i=1;i<NCols;i+=1)
		WAVE spectrum	= $(StringFromList(i,LoadWaveList))
		String description = StringFromList(i,LoadWaveList)
	
		Duplicate /O/D StackAxis, spectrum2
			
		if (InterpFlag)
			spectrum2[] = spectrum[BinarySearchInterp(axis,StackAxis[p])]
		else
			spectrum2[] = spectrum[p]
		endif
		
		NewReferenceSpectrum(StackAxis,spectrum2,description)
	endfor
	
	KillWaves /Z spectrum2
	KillWavesFromList(LoadWaveList,1)
End

Function ExtractReferenceSpectrum(StackAxis,StackName,PanelName)
	Wave StackAxis
	String StackName,PanelName
	
	if (!DataFolderExists("root:SPHINX:SVD"))
		InitializeSVD(0)
	endif
	
	// The extracted spectrum from the stack. 
	String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	WAVE spectrum 	= $(PanelFolder + ":specplot")
	
	NVAR gCursorBin	= $(PanelFolder+":gCursorBin")
	String StackWindow = PanelName+"#StackImage"
	String PixelSuffix 	= "x = " + num2str(hcsr(A, StackWindow)) + " y = " + num2str(vcsr(A, StackWindow)) + " bin = " + num2str(gCursorBin)
		
	String RefDescription 	= PromptForUserStrInput(PixelSuffix,"Describe this reference spectrum","New reference")
	if (cmpstr(RefDescription,"_quit!_") == 0)
		return 0
	endif
	
	NewReferenceSpectrum(StackAxis,spectrum,RefDescription)
	
	ReferenceSpectraPanel(StackName,PanelName)

End

Function NewReferenceSpectrum(axis,spectrum,description)
	Wave axis,spectrum
	String description
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	
	Variable NPts, NRefs = numpnts(RefList)
	
	String SpectrumName, RefAxisName, RefName=""
	
	RefName 		= "Ref_"+num2str(NRefs)
	RefAxisName 	= "Ref_"+num2str(NRefs)+"_axis"
	
	ReDimension /N=(NRefs+1) RefList
	RefList[NRefs] 		= RefName
	
	ReDimension /N=(NRefs+1,2) RefSelect, RefDesc
	RefDesc[NRefs][1] 		= description
	
	// Sort out the checkboxes in the ListBox
	RefSelect[NRefs][0] 	= SetBit(RefSelect[NRefs][0],5)
	RefSelect[NRefs][0] 	= SetBit(RefSelect[NRefs][0],4)
	RefSelect[NRefs][1] 	= ClearBit(RefSelect[NRefs][1],5)
	RefSelect[NRefs][1] 	= ClearBit(RefSelect[NRefs][1],4)
	
	// No need to worry about identical axes for ref spectra obtained from Browsed Stack. 
	Duplicate /O/D spectrum, $("root:SPHINX:SVD:"+RefName)
	Duplicate /O/D axis, $("root:SPHINX:SVD:"+RefAxisName)
End

// *************************************************************
// ****		Reference Spectra Panel Controls
// *************************************************************
Function ReferenceSpectraPanel(StackName,PanelName)
	String StackName,PanelName
	
	DoWindow StackBrowser
	if (!V_flag)
		return 0
	endif
	
	DoWindow ReferencePanel
	if (V_flag)
		DoWindow /F ReferencePanel
		return 0
	endif
	
	WAVE /T RefSpectra 	= root:SPHINX:SVD:ReferenceSpectra
	if (!WaveExists(RefSpectra))
		InitializeSVD(0)
	endif
	
	String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	WAVE specplot 		= $(PanelFolder + ":specplot")
	
	String StackWindow = PanelName+"#StackImage"
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	String StackFolder	= GetWavesDataFolder(avStack,1)
	WAVE SPHINXStack	= $(StackFolder+StackName)
	WAVE StackAxis  	= $(ParseFilePath(2,StackFolder,":",0,0)+StackName+"_axis")
	
	Variable NPts 		= numpnts(StackAxis)
	WAVE nullWave 	= root:SPHINX:SVD:nullWave
	Redimension /N=(NPts) nullWave
	nullWave = NAN
	
//	NewPanel /K=1/W=(195,45,525,800) as "Reference Spectra"
	NewPanel /K=1/W=(195,45,525,800) as "Component Fitting"
	Dowindow /C ReferencePanel
	CheckWindowPosition("ReferencePanel",195,45,525,800)
	
	SetWindow ReferencePanel, hook(CursorMovedHook)=SVDLimitsHooks
	SetWindow ReferencePanel, hook(PanelCloseHook)=KillSVDHooks
	
	ListBox ReferenceListBox,mode=8 ,pos={24,30},size={300,80}, widths={24,300}
	ListBox ReferenceListBox, editstyle=1, fSize=12, proc=PlotReference
	ListBox ReferenceListBox,listWave=root:SPHINX:SVD:ReferenceDescription
	ListBox ReferenceListBox,selWave=root:SPHINX:SVD:ReferenceSelection
	
	// Display the reference spectra
	Display/W=(7,137,322,337)/HOST=#  nullWave vs StackAxis
	RenameWindow #, RefPlot
	ModifyGraph /W=# mirror=2
	SetActiveSubwindow ##
	
	PlotRefInViewer()
	DoUpdate /W=ReferencePanel
	
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDEMin",StackAxis[10])
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDEMax",StackAxis[numpnts(nullWave)-10])
	NVAR gSVDEMin 	= root:SPHINX:SVD:gSVDEMin
	NVAR gSVDEMax 	= root:SPHINX:SVD:gSVDEMax
	
	if (0)
		// This is wrongly changing the values for no apparent reason. 
		gSVDEMin = SensibleRefPlotCsr(StackAxis,gSVDEMin,0)
		gSVDEMax = SensibleRefPlotCsr(StackAxis,gSVDEMax,1)
	endif
	
	Cursor /F/H=2/S=2/W=ReferencePanel#RefPlot A nullWave gSVDEMin, 1
	Cursor /F/H=2/S=2/W=ReferencePanel#RefPlot B nullWave gSVDEMax, 1

	
//	SetActiveSubwindow ReferencePanel#RefPlot
//	Cursor /F/H=2/S=2/W=# A nullWave gSVDEMin, 0.5
//	Cursor /F/H=2/S=2/W=# B nullWave gSVDEMax, 0.5
//	SetActiveSubwindow ##
	
	// *!*!* Add a hook to make it easier to reposition vertical cursors
	SetWindow ReferencePanel, hook(VerticalCursorsHook)=VCsrHook
	
	// Give this panel information about the displayed plot
	SetWindow ReferencePanel,userdata+= "VCsrWinName=ReferencePanel#RefPlot;"
	SetWindow ReferencePanel,userdata+= "VCsrTraceName=nullwave;"
	SetWindow ReferencePanel,userdata+= "VCsr1=A;"
	SetWindow ReferencePanel,userdata+= "VCsr1r=0;"
	SetWindow ReferencePanel,userdata+= "VCsr1g=0;"
	SetWindow ReferencePanel,userdata+= "VCsr1b=65535;"
	SetWindow ReferencePanel,userdata+= "VCsr2=B;"
	SetWindow ReferencePanel,userdata+= "VCsr2r=65535;"
	SetWindow ReferencePanel,userdata+= "VCsr2g=0;"
	SetWindow ReferencePanel,userdata+= "VCsr2b=52428;"
	
	// Display the pixel spectrum
//	Display/W=(7,363,322,563)/HOST=#  specplot vs StackAxis
	Display/W=(8,538,323,738)/HOST=#  specplot vs StackAxis
	RenameWindow #, SVDPlot
	ModifyGraph /W=# mirror=2
	SetActiveSubwindow ##
	
	// Background polynomial
	MakeVariableIfNeeded("root:SPHINX:SVD:gPolyBGFlag",1)
	CheckBox PolyBGCheck,pos={3,116},size={114,17},title=" ",fSize=11,variable= root:SPHINX:SVD:gPolyBGFlag

	MakeVariableIfNeeded("root:SPHINX:SVD:gPolyBGOrder",3)
	NVAR gPolyBGOrder = root:SPHINX:SVD:gPolyBGOrder
	SetVariable PolyBGSetVar,title="BG poly terms",pos={27,116},limits={0,7,1},size={117,15},fSize=11,value= gPolyBGOrder
	DrawText 150,132,"1=const, 2=line, 3=parabola"
	
	Button SVDImportRef title="Import",pos={26,3},size={60,24},proc=SVDPanelButtons
	Button SVDExportRef title="Export",pos={126,3},size={60,24},proc=SVDPanelButtons
	Button SVDResetRefs title="Reset",pos={226,3},size={60,24},proc=SVDPanelButtons
	
	// Group boxes at the bottom
	GroupBox SingleSVDBox,pos={7,374},size={118,85}, title="Single spectrum",fColor=(39321,1,1)
	GroupBox ROISVDBox,pos={128,374},size={194,85},title="Stack ROI",fColor=(39321,1,1)
	GroupBox RescaleSVDBox,pos={7,460},size={312,68},title="Rescale maps onto 250 gray scale values for TIFF output",fColor=(39321,1,1)
	
	// *** decomposition method
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDChoice",2)
	NVAR gSVDChoice 	= root:SPHINX:SVD:gSVDChoice
	PopupMenu SVDChoiceMenu,fSize=11,pos={10,351},title="Analysis",mode=gSVDChoice
	PopupMenu SVDChoiceMenu,proc=SVDTypeMenuProcs,value="Matrix LLS;NLLS;MT-NLLS;"
	
	
	// ----------------------------------- NLLS Setting
	// Permit energy shifting during fits - LLS only	
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDdEFlag",1)
	CheckBox SVDLdECheck,pos={176,347},size={212,577},title="Fit ΔE",fSize=11,variable= root:SPHINX:SVD:gSVDdEFlag
	CheckBox SVDLdECheck,disable=(gSVDChoice != 1) ? 0 : 1
	
	// Maximum permissible energy shift
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDdEMax",0.35)
	NVAR gSVDdEMax = root:SPHINX:SVD:gSVDdEMax
	SetVariable MaxdESetVar,title="± ",pos={231,344},limits={0,inf,0.1},size={80,17},fsize=11,value= gSVDdEMax
	SetVariable MaxdESetVar,disable=(gSVDChoice != 1) ? 0 : 1
	
	// Enforce positivitity during fits - LLS only	
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDPosFlag",1)
	CheckBox SVDLPosCheck,pos={244,365},size={212,577},title="Positivity",fSize=11,variable= root:SPHINX:SVD:gSVDPosFlag
	CheckBox SVDLPosCheck,disable=(gSVDChoice != 1) ? 0 : 1
	
	
	// ----------------------------------- Spectrum ROI controls
	Button SVDLaunch title="Analyze",pos={11,389},size={55,26},proc=SVDPanelButtons
	Button SVDSave title="Save",pos={69,389},size={34,26},proc=SVDPanelButtons

	// Option to transfer the single-spectrum results to the Images
	MakeVariableIfNeeded("root:SPHINX:SVD:gSinglePixelUpdate",0)
	CheckBox SVDPixelCheck,pos={107,395},size={22,15},title=" ",fSize=11,variable= root:SPHINX:SVD:gSinglePixelUpdate, help={"transfer the single-spectrum results to the Images"}
	
	// Display some results of fitting: The Chi-Squared
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDChiSqr",0)
//	ValDisplay SVDChiDisplay title="\Z16Χ\M\Z14\S2",size={80,20},pos={16,415},fSize=12,format="%2.5f"
	ValDisplay SVDChiDisplay title="χ\\Z14\\S2",size={80,20},pos={16,415},fSize=12,format="%2.5f"
	SetControlGlobalVariable("","SVDChiDisplay","root:SPHINX:SVD","gSVDChiSqr",2)
	
	// Display some results of fitting: The Energy Shift
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDdE",0)
//	ValDisplay SVDdEDisplay title="\Z16Δ\M\Z14E",size={82,20},pos={14,435},fSize=12,format="%2.3f"
	ValDisplay SVDdEDisplay title="ΔE",size={82,20},pos={14,435},fSize=12,format="%2.3f"
	SetControlGlobalVariable("","SVDdEDisplay","root:SPHINX:SVD","gSVDdE",2)
	
	
	// ----------------------------------- Stack ROI controls
	Button SVDROILaunch title="Analyze",pos={136,389},size={60,26},proc=SVDPanelButtons
	Button SVDClearResults title="Clear",pos={198,389},size={60,26},proc=SVDPanelButtons
	
	// Bin pixels to improve statistics
	MakeVariableIfNeeded("root:SPHINX:SVD:gSVDBin",1)
	NVAR gSVDBin = root:SPHINX:SVD:gSVDBin
	SetVariable CursorBinSetVar,title="Bin",pos={261,392},limits={1,inf,1},size={56,17},fsize=11,value= gSVDBin
	
	// Display the pixel-wise results as they occur	
	MakeVariableIfNeeded("root:SPHINX:SVD:gLiveSVDFlag",0)
	CheckBox SVDLiveCheck,pos={137,419},size={114,17},title="Live updates?",fSize=11,variable= root:SPHINX:SVD:gLiveSVDFlag

	// auto save checkbox
	MakeVariableIfNeeded("root:SPHINX:SVD:autoSave",0)
	CheckBox autoSaveCheckbox,title="Auto Save",pos={240,419},fsize=11,variable=$("root:SPHINX:SVD:autoSave")

	// Options to use 2 kinds of ROI

	// Use existing ROI mask
	MakeVariableIfNeeded("root:SPHINX:SVD:gROIMappingFlag",0)
	CheckBox SVDROICheck,pos={108,439},size={114,17},side=1,title="Use pink ROI",fSize=11,proc=RefROICheckProcs

	// Display the pixel-wise results as they occur	
	MakeVariableIfNeeded("root:SPHINX:SVD:gImageROIFlag",0)
	CheckBox SVDROICheck2,pos={198,439},size={114,17},side=1,title="image mask",fSize=11,proc=RefROICheckProcs	
	
	// ----------------------------------- Rescaling controls
	// Reprocess SVD maps to consistent 0-255 grey scale
	Button SVDRescale title="Rescale",pos={10,476},size={60,24},proc=SVDPanelButtons
	Button SVDRGB title="RGB",pos={10,502},size={35,24},proc=SVDPanelButtons
	Button SVDMM title="MM",pos={43,502},size={31,24},proc=SVDPanelButtons
	
	// Method for discarding pixels
	MakeStringIfNeeded("root:SPHINX:SVD:gRescaleMethod","image mask")
	MakeVariableIfNeeded("root:SPHINX:SVD:gChi2Type",5)
	SVAR gRescaleMethod 	= root:SPHINX:SVD:gRescaleMethod
	NVAR gChi2Type 		= root:SPHINX:SVD:gChi2Type
	
	Variable MenuMode = WhichListItem(gRescaleMethod,"spectral peak;none;iMap chi-sqr;pMap chi-sqr;image intensity;min<i<max;min<p<max;image mask;")
	PopupMenu Chi2TypeMenu,fSize=11,pos={72,478},title="Mask"//,mode=ChiType
	PopupMenu Chi2TypeMenu,proc=Chi2TypeMenuProcs, mode=(MenuMode+1), value="spectral peak;none;iMap chi-sqr;pMap chi-sqr;avg image intensity;min < i < max;min < p < max;image mask;"
//	PopupMenu Chi2TypeMenu,variable= root:SPHINX:SVD:gDiscrim
	
	
	MakeStringIfNeeded("root:SPHINX:SVD:gRescaleOutput","proportion")
	SVAR gRescaleOutput 	= root:SPHINX:SVD:gRescaleOutput
	MenuMode = WhichListItem(gRescaleOutput,"proportion;intensity;")
	PopupMenu RescaleOutputMenu,proc=RescaleOutputMenuProcs,fSize=11,pos={75,503},title="Output",mode=(MenuMode+1),value="proportion;intensity;"
	//variable= root:SPHINX:SVD:gRescaleOutput
	
	
	
	// Threshold values for discarding pixels
	MakeVariableIfNeeded("root:SPHINX:SVD:gMinX2",0)
	NVAR gMinX2 = root:SPHINX:SVD:gMinX2
//	SetVariable MinX2SetVar,bodywidth=60,pos={205,696},limits={-inf,inf,0.1},size={105,17},fsize=11,proc=SetChi2MinMax,value= gMinX2
	SetVariable MinX2SetVar,bodywidth=60,pos={205,477},limits={-inf,inf,0.1},size={105,17},fsize=11,proc=SetChi2MinMax,value= gMinX2, disable=1

	MakeVariableIfNeeded("root:SPHINX:SVD:gMaxX2",1)
	NVAR gMaxX2 = root:SPHINX:SVD:gMaxX2
//	SetVariable MaxX2SetVar,title="Max \Z13Χ\M\Z11\S2",bodywidth=60,pos={205,721},limits={-inf,inf,0.1},size={105,17},fsize=11,proc=SetChi2MinMax,value= gMaxX2
	SetVariable MaxX2SetVar,title="Max \Z13Χ\M\Z11\S2",bodywidth=60,pos={205,502},limits={-inf,inf,0.1},size={105,17},fsize=11,proc=SetChi2MinMax,value= gMaxX2, disable=1

	UpdateChiMaxSetVar(gRescaleMethod)
	
	
End

Function SensibleRefPlotCsr(axis,SVDE,Flag)
	Wave axis
	Variable SVDE,Flag
	
	Variable GoodSVDE=0, NPts = DimSize(axis,0)
	FindValue /V=(SVDE) axis
	
	if (V_value == -1)
		if (Flag == 0)
			GoodSVDE = axis[trunc(NPts/10)]
		else
			GoodSVDE = axis[trunc(NPts - NPts/10)]
		endif
	else
		GoodSVDE = SVDE
	endif
	
	return GoodSVDE
End

// *************************************************************
// ****		SVD Panel Check Boxes for ROI selection
// *************************************************************

// Toggle between various options for using and ROI mask
// We can only have one or the other or neither
Function RefROICheckProcs(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	NVAR gROIMappingFlag 	= root:SPHINX:SVD:gROIMappingFlag
	NVAR gImageROIFlag 	= root:SPHINX:SVD:gImageROIFlag
	
	Variable checked		= CB_Struct.checked
	String ctrlName			= CB_Struct.ctrlName
	
	if (cmpstr(ctrlName,"SVDROICheck") == 0)
		gROIMappingFlag 	= checked
		if (checked)
			gImageROIFlag 	= 0
			CheckBox SVDROICheck2, value=0
			ControlUpdate SVDROICheck2
		endif
	elseif (cmpstr(ctrlName,"SVDROICheck2") == 0)
		gImageROIFlag 		= checked
		if (checked)
			gROIMappingFlag 	= 0
			CheckBox SVDROICheck, value=0
			ControlUpdate SVDROICheck
		endif
	endif
	
	return 1
End

// *************************************************************
// ****		SVD Panel Hooks
// *************************************************************

// Save the SVD fit range if the panel is closed or the cursors are moved. 
Function KillSVDHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	NVAR gSVDEMin 		= root:SPHINX:SVD:gSVDEMin
	NVAR gSVDEMax 		= root:SPHINX:SVD:gSVDEMax
		
	Variable hookResult 	= 0
	Variable keyCode 		= H_Struct.keyCode
	Variable eventCode		= H_Struct.eventCode
	Variable Modifier 		= H_Struct.eventMod
	
	Variable SVDEMin, SVDEMax, SaveSVDRange=0, NPts = numpnts(StackAxis)
	
	if (eventCode == 2)			// Window killed
		SaveSVDRange 	= 1
		
//	elseif (eventCode == 17)		// Window about to be killed
//		SaveSVDRange 	= 1
		
	elseif (eventCode == 7)		// Cursor moved
	
		GetWindow $H_Struct.winName activeSW 
		String WindowName = S_value
		if (cmpstr(WindowName, "ReferencePanel#RefPlot") != 0) 
			return 0 
		endif
		
		if (!CsrIsOnPlot("ReferencePanel#RefPlot","A") || !CsrIsOnPlot("ReferencePanel#RefPlot","B"))
			return 0	// Prevents problems when only one of the cursor has been added when the panel is created
		endif
		
		SaveSVDRange 	= 1
		hookResult 		= 1
	endif
	
	if (SaveSVDRange == 1)
		SVDEMin 		= hcsr(A,"ReferencePanel#RefPlot")
		SVDEMax 		= hcsr(B,"ReferencePanel#RefPlot")
		
		gSVDEMin 		= min(SVDEMin,SVDEMax)
		gSVDEMax 		= max(SVDEMin,SVDEMax)
		
		print " Saved the SVD range ",gSVDEMin,"to",gSVDEMax,"eV when closing the Ref Spectra Panel"
	endif
	
	return hookResult
End



// *************************************************************
// ****		SVD Panel Buttons
// *************************************************************

Function SVDPanelButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String panelName 	= B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	Variable ShiftDown=0
	Variable eventMod 	= B_Struct.eventMod
	if ((eventMod & 2^1) != 0)	// Bit 1 = shift key down
		ShiftDown = 1
	endif
	if ((eventMod & 2^2) != 0)
	endif

	// The Browsed Stack
	String StackWindow = "StackBrowser#StackImage"
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	String StackFolder	= GetWavesDataFolder(avStack,1)
	String StackName 	= ReplaceString("_av",StackAvg,"")
	WAVE SPHINXStack	= $(StackFolder+StackName)
	WAVE StackAxis  	= $("root:SPHINX:Stacks:"+StackName+"_axis")
	
	// The Extracted Spectrum
	String PanelFolder 	= "root:SPHINX:Browser"
	WAVE specplot 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "specplot")
	WAVE spectrum 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "spectrum")
	WAVE energy 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "energy")
	
	if (cmpstr(ctrlName,"SVDLaunch") == 0)
		Note /K/NOCR specplot, Note(spectrum)
		SpectrumAnalysis(energy,specplot,0,StackName)
	
	elseif (cmpstr(ctrlName,"SVDSave") == 0)
		AdoptSVDSpectra(StackName,PanelFolder)
		
	elseif (cmpstr(ctrlName,"SVDImportRef") == 0)
		ImportReferenceSpectrum(StackAxis)
		
	elseif (cmpstr(ctrlName,"SVDExportRef") == 0)
		ExportReferenceSpectra()
		
	elseif (cmpstr(ctrlName,"SVDResetRefs") == 0)
		InitializeSVD(0)
		
	elseif (cmpstr(ctrlName,"SVDROILaunch") == 0)
		ROISVD(SPHINXStack,StackFolder,PanelFolder,ShiftDown)
		
	elseif (cmpstr(ctrlName,"SVDClearResults") == 0)
		ResetSVDImages(StackName)
		
	elseif (cmpstr(ctrlName,"SVDRescale") == 0)
		RescaleSVDImages(StackName,DimSize(SPHINXStack,0),DimSize(SPHINXStack,1))
	
	elseif (cmpstr(ctrlName,"SVDRGB") == 0)
		RGBMapExportPanel()
		
	elseif (cmpstr(ctrlName,"SVDMM") == 0)
		MMExportPanel()
	endif
End
	
	
//Function SVDPanelButtons(ctrlName) : ButtonControl
//	String ctrlName
//
//	// The Browsed Stack
//	String StackWindow = "StackBrowser#StackImage"
//	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
//	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
//	String StackFolder	= GetWavesDataFolder(avStack,1)
//	String StackName 	= ReplaceString("_av",StackAvg,"")
//	WAVE SPHINXStack	= $(StackFolder+StackName)
//	WAVE StackAxis  	= $("root:SPHINX:Stacks:"+StackName+"_axis")
//	
//	// The Extracted Spectrum
//	String PanelFolder 	= "root:SPHINX:Browser"
//	WAVE specplot 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "specplot")
//	WAVE spectrum 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "spectrum")
//	WAVE energy 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "energy")
//	
//	if (cmpstr(ctrlName,"SVDLaunch") == 0)
//		Note /K/NOCR specplot, Note(spectrum)
//		SpectrumAnalysis(energy,specplot,0,StackName)
//	
//	elseif (cmpstr(ctrlName,"SVDSave") == 0)
//		AdoptSVDSpectra(StackName,PanelFolder)
//		
//	elseif (cmpstr(ctrlName,"SVDImportRef") == 0)
//		ImportReferenceSpectrum(StackAxis)
//		
//	elseif (cmpstr(ctrlName,"SVDExportRef") == 0)
//		ExportReferenceSpectra()
//		
//	elseif (cmpstr(ctrlName,"SVDResetRefs") == 0)
//		InitializeSVD(0)
//		
//	elseif (cmpstr(ctrlName,"SVDROILaunch") == 0)
//		ROISVD(SPHINXStack,StackFolder,PanelFolder)
//		
//	elseif (cmpstr(ctrlName,"SVDClearResults") == 0)
//		ResetSVDImages(StackName)
//		
//	elseif (cmpstr(ctrlName,"SVDRescale") == 0)
//		RescaleSVDImages(StackName,DimSize(SPHINXStack,0),DimSize(SPHINXStack,1))
//	
//	endif
//End

Function AdoptSVDSpectra(StackName,PanelFolder)
	String StackName, PanelFolder

	WAVE energy 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "energy")
	WAVE specplot 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "specplot")
	WAVE specfit 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "specfit")
	WAVE specbg 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "specbg")
	WAVE specresid 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "specresid")
	
	WAVE Results 		= root:SPHINX:SVD:Results
	WAVE Residuals 	= root:SPHINX:SVD:Residuals
	WAVE Polynomial 	= root:SPHINX:SVD:Polynomial
	
	Duplicate /O/D Results, $(ParseFilePath(2,PanelFolder,":",0,0) + "specplot_fit")
	Duplicate /O/D Polynomial, $(ParseFilePath(2,PanelFolder,":",0,0) + "specplot_bg")
	
	AdoptAxisAndDataFromMemory("energy","",PanelFolder,"specplot","",PanelFolder,StackName+"_svd","svd",1,1,1)
End

Function SVDTypeMenuProcs(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	NVAR gSVDChoice 		= root:SPHINX:SVD:gSVDChoice
	
	if (PU_Struct.eventCode > 0)
		gSVDChoice 	= PU_Struct.popNum
		
		CheckBox SVDLdECheck,disable=(gSVDChoice != 1) ? 0 : 1
		CheckBox SVDLPosCheck,disable=(gSVDChoice != 1) ? 0 : 1
		SetVariable MaxdESetVar,disable=(gSVDChoice != 1) ? 0 : 1
		
		// This did not help
//		CheckBox SVDWgtCheck,disable=(gSVDChoice == 2) ? 0 : 1
	endif
End

Function SetChi2MinMax(SV_Struct) 
	STRUCT WMSetVariableAction &SV_Struct 
	
	String ctrlName 	= SV_Struct.ctrlName
	Variable varNum 	= SV_Struct.dval
	
	Variable eventCode 	= SV_Struct.eventCode
	if (eventCode == -1)
		return 0
	endif
	
	NVAR gMinX2 = root:SPHINX:SVD:gMinX2
	NVAR gMaxX2 = root:SPHINX:SVD:gMaxX2
	
	varNum = (abs(varNum) < 1e-6) ? 0 : varNum
	
	if (cmpstr(ctrlName,"MinX2SetVar") == 0)
		gMinX2 = varNum
	elseif (cmpstr(ctrlName,"MaxX2SetVar") == 0)
		gMaxX2 = varNum
	endif
End

Function Chi2TypeMenuProcs(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	SVAR gRescaleMethod 	= root:SPHINX:SVD:gRescaleMethod
	NVAR gChi2Type 		= root:SPHINX:SVD:gChi2Type
	
	if (PU_Struct.eventCode > 0)
		gRescaleMethod 	= PU_Struct.popStr
		gChi2Type 		= PU_Struct.popNum
		
		UpdateChiMaxSetVar(gRescaleMethod)
	endif
End

Function RescaleOutputMenuProcs(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	SVAR gRescaleOutput 	= root:SPHINX:SVD:gRescaleOutput
	
	if (PU_Struct.eventCode > 0)
		gRescaleOutput 	= PU_Struct.popStr
	endif
End

Function UpdateChiMaxSetVar(RescaleMethod)
	String RescaleMethod

	if (StrSearch(RescaleMethod,"chi-sqr",0) > -1)
		SetVariable MaxX2SetVar,title="Max \Z13Χ\M\Z11\S2",disable=0
		SetVariable MinX2SetVar,disable=1
	elseif (cmpstr("none",RescaleMethod) == 0)
		SetVariable MaxX2SetVar,disable=1
		SetVariable MinX2SetVar,disable=1
	elseif (cmpstr("image mask",RescaleMethod) == 0)
		SetVariable MaxX2SetVar,disable=1
		SetVariable MinX2SetVar,disable=1
	else
		if (cmpstr("spectral peak",RescaleMethod) == 0)
			SetVariable MaxX2SetVar,title="Max \Z15i",disable=0
			SetVariable MinX2SetVar,title="Min \Z15i",disable=0
		elseif (StrSearch(RescaleMethod,"p",0) >-1)
			SetVariable MaxX2SetVar,title="Max \Z15p",disable=0
			SetVariable MinX2SetVar,title="Min \Z15p",disable=0
		else
			SetVariable MaxX2SetVar,title="Max \Z15i",disable=0
			SetVariable MinX2SetVar,title="Min \Z15i",disable=0
		endif
	endif
End

// *************************************************************
// ****		SVD Panel ListBox controls
// *************************************************************
Function PlotReference(ctrlName,row,col,event) : ListBoxControl
	String ctrlName
	Variable row
	Variable col		//1=mouse down, 2=up, 3=dbl click, 4=cell select with mouse or keys
	Variable event	//5=cell select with shift key, 6=begin edit, 7=end
	
	if ((event==4) || (event==5))
		PlotRefInViewer()
	endif
End

Function RemoveRefsFromViewer()

	String RefList, TraceName
	Variable i, NTraces
	
	RefList 		= TraceNameList("ReferencePanel#RefPlot",";",1)
	NTraces 	= ItemsInList(RefList)
	
	for (i=0;i<NTraces;i+=1)
		TraceName 	= StringFromList(i,RefList)
		if (cmpstr("nullWave",TraceName) != 0)
			RemoveFromGraph /W=ReferencePanel#RefPlot $TraceName
		endif
	endfor
end

Function PlotRefInViewer()
	
	WAVE nullWave 	= root:SPHINX:SVD:nullWave
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	
	String RefName, RefAxisName
	Variable i, isDisplayed
	
	CheckDisplayed /W=ReferencePanel#RefPlot nullWave
	if (!V_flag)
		AppendtoGraph /W=ReferencePanel#RefPlot nullWave
	endif
	
	for (i=0;i<numpnts(RefList);i+=1)
		RefName		= RefList[i]
		RefAxisName 	= RefName+"_axis"
		
		WAVE Ref 		= $("root:SPHINX:SVD:"+RefName)
		WAVE RefAxis 	= $("root:SPHINX:SVD:"+RefAxisName)
		
		CheckDisplayed /W=ReferencePanel#RefPlot Ref
		isDisplayed = V_Flag
		
		if ((RefSelect[i][1] == 0) && (isDisplayed))
			RemoveFromGraph /W=ReferencePanel#RefPlot $RefName
		elseif ((RefSelect[i][1] == 1) && (!isDisplayed))
			AppendtoGraph /W=ReferencePanel#RefPlot Ref vs RefAxis
		endif
	endfor
End

// *************************************************************
// ****		Prepare the matrices used for Single or ROI SVD analysis
// *************************************************************
//
// 	Notes: 	NRefs 	= total number of references
//			NSel 	= number of reference spectra selected for fitting
// 			The waves and matrices called Refxxx: 
// 								... ARE truncated to the fit range for SVD method
// 								... ARE NOT truncated to the fit range for LLS method
//			The organization of RefSoln varies with fit method

Function PrepareSVDMatrices(SVDPtMin,SVDPtMax, NCmpts, PlotFlag)
	Variable &SVDPtMin, &SVDPtMax, &NCmpts, PlotFlag

	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE RefScale 		= root:SPHINX:SVD:ReferenceScale
		
	WAVE RefMatrix 	= root:SPHINX:SVD:ReferenceMatrix
	WAVE DataMatrix 	= root:SPHINX:SVD:DataMatrix
	
	WAVE RefSoln 		= root:SPHINX:SVD:SolutionMatrix
	
	Wave RefAxis 		= root:SPHINX:SVD:ReferenceAxis
	Wave RefShiftAxis 	= root:SPHINX:SVD:RefShiftAxis
	
	NVAR gSVDChoice 	= root:SPHINX:SVD:gSVDChoice
	NVAR gSVDEMin 	= root:SPHINX:SVD:gSVDEMin
	NVAR gSVDEMax 	= root:SPHINX:SVD:gSVDEMax
	NVAR gPolyBGFlag 	= root:SPHINX:SVD:gPolyBGFlag
	NVAR gPolyBGOrder = root:SPHINX:SVD:gPolyBGOrder
	
	String RefName
	Variable i, j=0, n=0, PCenter, PolyFlag, SVDPtStart, NPts, NFitPts, NRefs, NSel=0, NCoefs, PtMin, PtMax
	
	// The energy axis of the currently browsed Stack
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,"StackBrowser#StackImage"))
	string StackName 	= ReplaceString("_av",StackAvg,"")
	WAVE StackAxis  	= $("root:SPHINX:Stacks:"+StackName+"_axis")
	
	if ((!WaveExists(StackAxis)) || (StackAxis[0] == 0))
		DoAlert 0, "Please load a stack axis"
		NRefs = 0
		return 0
	endif
	
	if (gSVDEMin == gSVDEMax)
		DoAlert 0, "Please expand the SVD fit range"
		NRefs = 0
		return 0
	endif
	
	// Find the indices of the fit range ...
	PtMin 	= BinarySearch(StackAxis,gSVDEMin)
	PtMax 	= BinarySearch(StackAxis,gSVDEMax)
	SVDPtMin 	= min(PtMin,PtMax)
	SVDPtMax 	= max(PtMin,PtMax)
	// ... and the starting point for filling the reference matrix. 
	SVDPtStart 	= (gSVDChoice == 1) ? SVDPtMin : 0
	
	// The total and fitted number of points
	NFitPts 	= SVDPtMax - SVDPtMin + 1
	NPts 		= (gSVDChoice == 1) ? NFitPts : DimSize(StackAxis,0)
	
	// The data matrix, or B,  gets filled prior to analysis
	Redimension /N=(NPts,1) DataMatrix
	
	Redimension /N=(NPts) RefAxis
	RefAxis[] 	= StackAxis[p+SVDPtStart]
	
	// Count the number of selected reference spectra. 
	NRefs 	=numpnts(RefList)
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			NSel += 1
		endif
	endfor
	
	if (NSel < 1)
		UpdateSVDResultsPlot(RefAxis,NPts,0)
		return NSel
	endif
	
	PolyFlag 	= ((gPolyBGFlag == 1) && (gSVDChoice == 1)) ? 1 : 0
	
	// The total number of fitted components, including ref spectra and backgrounds
	NCmpts 	= (PolyFlag == 1) ? (NSel + gPolyBGOrder + 1) : NSel
	
	// The total number of fit coefficients, possibly including energy offset
	NCoefs 		= (gSVDChoice == 2) ? (NCmpts + 1) : NCmpts
	
	// The solution matrix, or x
	Redimension /N=(NCoefs) RefSoln
	
	// The References Matrix, or A
	Redimension /N=(NPts,NCmpts) RefMatrix
	
	// A component strength matrix for normalization
	Redimension /N=(NSel) RefScale
	
	// Place selected references into the References Matrix. 
	j=0
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			RefName 	= RefList[i]
			WAVE Ref 	= $("root:SPHINX:SVD:"+RefName)
			
			RefMatrix[][j] 	= Ref[p+SVDPtStart]
			j += 1
		endif
	endfor
	
	// Add background components. 
	if (PolyFlag == 1)
		// This is for the LLS routine, which calculates the polynomial bg
		PCenter 	= gSVDEMin+(gSVDEMax-gSVDEMin)/2
		
		// This is for the SVD routine, which fits the polynomial bg
		for (i=j;i<NCmpts;i+=1)
			RefMatrix[][i] 	= (1/(10^n)) * (RefAxis[p]-PCenter)^n
			n += 1
		endfor
	endif
	
	UpdateSVDResultsPlot(RefAxis,NPts,PlotFlag)
	
	return NSel
End

Function UpdateSVDResultsPlot(RefAxis,NPts,PlotFlag)
	Wave RefAxis
	Variable NPts,PlotFlag

	// Make sure the results and residuals exist and are plotted in the ReferencePanel
	Make /O/D/N=(NPts) root:SPHINX:SVD:Results /WAVE=results
	Make /O/D/N=(NPts) root:SPHINX:SVD:Residuals /WAVE=residuals
	Make /O/D/N=(NPts) root:SPHINX:SVD:Polynomial /WAVE=polynomial
	
	DoWindow ReferencePanel
	if (V_flag)
		CheckDisplayed /W=ReferencePanel#SVDPlot results
		if(!V_Flag && PlotFlag)
			AppendtoGraph /W=ReferencePanel#SVDPlot results vs RefAxis
			ModifyGraph /W=ReferencePanel#SVDPlot rgb(Results)=(0,0,65535)
			
			AppendtoGraph /W=ReferencePanel#SVDPlot residuals vs RefAxis
			ModifyGraph /W=ReferencePanel#SVDPlot rgb(Residuals)=(17476,17476,17476)
		elseif (!PlotFlag)
			RemoveFromGraph /Z/W=ReferencePanel#SVDPlot $NameOfWave(results),$NameOfWave(residuals)
		endif
	endif
End

// *************************************************************
// ****		Calculate the Chi-Squared valye
// *************************************************************

Function CalculateChiSquared(spectrum, results,residuals,SVDChoice,PtMin,PtMax,refArea,iChiSqr,pChiSqr)
	Wave spectrum, results, residuals
	Variable SVDChoice, PtMin, PtMax, refArea, &iChiSqr, &pChiSqr
	
	// Calculate the residuals
	if (SVDChoice == 1)	// Matrix LLS
		residuals[] = spectrum[p+PtMin] - results[p]
	else
		residuals[PtMin,PtMax] = spectrum[p] - results[p]
		results[0,PtMin-1]	= NAN
		results[PtMax+1,]		= NAN
	endif
	
	// The simple chi-squared value
	WaveStats /Q residuals
	iChiSqr =  V_rms^2
	
	// The chi-squared value scaled for the integrated spectrum intensity. 
	// A problem here is that the area can go negative for strangely sloping backgrounds. 
//	Variable sConst = area(results,PtMin,PtMax)
//	Variable pConst = area(polynomial,PtMin,PtMax)
//	pChiSqr = iChiSqr/(sConst-pConst)
	
	pChiSqr = iChiSqr/refArea
	
	if (NumType(pChiSqr) != 0)
		BreakPoint()
	endif
End

// *************************************************************
// ****		SPECTRAL DECOMPOSITION BASED ON FuncFit
// *************************************************************
//
//		This is essential for PEEM data because it allows for small shifts in the Energy axis. 
// 		There is always a small amount of energy dispersion across the (vertical) range of an image. 
//		Fitting the energy, however, is not a completely reliable approach ... 

// Coefficients structure:
// 	0 - (N-1) 	= coefficients for N reference spectra
// 	N 			= energy shift
// 	rest 		= poly coefs

Function /T PrepareLLSMatrices(NPts,NCfs,POrder)
	Variable NPts,NCfs,POrder
	
	Make /O/D/N=(POrder) root:SPHINX:SVD:fpcs
	Make /O/D/N=(NCfs) root:SPHINX:SVD:LLSCfs /WAVE=LLSCfs
	Make /O/D/N=(NPts) root:SPHINX:SVD:fsum
	Make /O/D/N=(NPts) root:SPHINX:SVD:faxis
	Make /O/D/N=(NPts) root:SPHINX:SVD:fshift
	Make /O/D/N=(NPts) root:SPHINX:SVD:fweight
End

Function PrepareLLSConstraints(NSel,NCoefs,dEFlag,dEMax,PosFlag,FitFolder)
	Variable NSel,NCoefs,dEFlag,dEMax,PosFlag
	String FitFolder
	
	// Single thread: FitFolder is root:SPHINX:SVD:
	String OldDf = GetDataFolder(1)
	SetDataFolder $FitFolder

		Variable i, NCnsrts = (2*dEFlag) + (PosFlag*NSel)
		
		if (NCnsrts > 0)
		
			Make /O/T/N=(NCnsrts) $(ParseFilePath(2,FitFolder,":",0,0)+"fcnstr") /Wave=cnstr
			Make /O/T/N=(NCnsrts) $(ParseFilePath(2,FitFolder,":",0,0)+"fcnstr") /Wave=cnstr2
			
			if (dEFlag)
				cnstr[0] 	= "K"+num2str(NSel)+" >  "+num2str(-1*dEMax)
				cnstr[1] 	= "K"+num2str(NSel)+" <  "+num2str(dEMax)
				
				cnstr2[0] 	= "K"+num2str(NSel)+" >  "+num2str(-1*(dEMax-0.01))
				cnstr2[1] 	= "K"+num2str(NSel)+" <  "+num2str(dEMax-0.01)
			endif
			if (PosFlag)
				for (i=0;i<NSel;i+=1)
					// debug 2013-05-20. Constraints not completely enforcing positive coefficients. E.g., -3.2535e-06
					cnstr[i+(2*dEFlag)] 	= "K"+num2str(i)+" > 0.001"
					
					cnstr2[i+(2*dEFlag)] 	= "K"+num2str(i)+" > 0.001"
				endfor
			endif
		endif
		
		// Make the constraint matrix and wave
		PrepareLLSConstMatrix(NSel,NCoefs,dEFlag,dEMax,PosFlag)
	SetDataFolder $OldDf
End

Function PrepareLLSConstMatrix(NSel,NCfs,dEFlag,dEMax,PosFlag)
	Variable NSel,NCfs,dEFlag,dEMax,PosFlag
	
	Variable CwaveN, CmatrixM=NCfs
	Variable NECnsts 	= (dEFlag) ? 2 : 0
	Variable NPCnsts 	= (PosFlag) ? NSel : 0
	Variable i
	
	if (dEFlag || PosFlag)
		Make /D/O/N=(NECnsts+NPCnsts,NCfs) Cmatrix=0
		Make /D/O/N=(NECnsts+NPCnsts) Cwave
		if (dEFlag)
			Cwave[0,1] 	= dEMax
			Cmatrix[0][NSel] = -1
			Cmatrix[1][NSel] = 1
		endif
		if (PosFlag)
			Cwave[NECnsts,]	= -0.001
			for (i=0;i<NSel;i+=1)
				Cmatrix[NECnsts+i][i] = -1
			endfor
		endif
	endif
End

Function /T PrepareLLSHoldString(NSel,EShift,POrder)
	Variable NSel,EShift, POrder
	
	String HoldString	= MakeStringOfChars(NSel,"0")
	
	// Optional energy offset
	if (EShift == 1)
		HoldString 	+= "0"
	else
		HoldString 	+= "1"
	endif
	if (POrder > 0)
		HoldString += MakeStringOfChars(POrder,"0")
	endif
	
	return HoldString
End

// Default coefficients
Function /T FillLLSCoefficients(LLSCfs,NSel,dEFlag,POrder)
	Wave LLSCfs
	Variable NSel,dEFlag,POrder
	
	// The spectrum references
	LLSCfs[0,NSel-1] 	= 1
	
	// Optional energy offset
	if (dEFlag == 1)
		LLSCfs[NSel] 	= 0.01
	else
		LLSCfs[NSel] 	= 0
	endif
	
	if (POrder > 0)
		LLSCfs[NSel+1,] 	= 0.01
	endif
End

Function SingleLLS(energy,spectrum,RefPoly,RefResults,RefResids,RefSoln,PtMin,PtMax,NSel,NCfs,dEFlag,dEMax,Center,POrder,PosFlag,refArea,iChiSqr,HoldString)
	Wave energy,spectrum,RefPoly,RefResults,RefResids,RefSoln
	Variable PtMin,PtMax,NSel,NCfs,dEFlag,dEMax,Center,POrder,PosFlag, &refArea, &iChiSqr
	String HoldString
	
	WAVE LLSCfs 	= root:SPHINX:SVD:LLSCfs
	WAVE cnstr 	= root:SPHINX:SVD:fcnstr
	WAVE weight 	= root:SPHINX:SVD:fweight
	
	WAVE faxis 		= root:SPHINX:SVD:faxis
	faxis = energy
	
	WAVE Cmatrix 	= root:SPHINX:SVD:Cmatrix
	WAVE Cwave 	= root:SPHINX:SVD:Cwave
	
	// Bad idea to use a weighting wave. Tends to prevent the fitted spectra from fully matching the peak intensities
	weight = 1
	
	STRUCT LLSFitStruct fs 
	fs.minpt 	= PtMin		// First point in fit range
	fs.nsel 		= NSel			// Number of reference spectra to fit
	fs.shflag 	= dEFlag		// Energy shift flag
	fs.center 	= Center		// x-value at the center of the fit range
	fs.firstpt 	= PtMin 		// the first point at the start of the fit range
	fs.lastpt 	= PtMax 		// the last point at the start of the fit range
	fs.pcoefpt 	= NSel+1		// start of polynomial coefficients in the coef wave
	fs.porder 	= POrder		// polynomial order
	fs.areaflag 	= 0 			// For fitting, do not calculate area under the references
	
	WAVE fs.pcoefw		= root:SPHINX:SVD:fpcs 					// polynomial coefficients
	WAVE fs.refmatrix	= root:SPHINX:SVD:ReferenceMatrix 	// matrix of reference spectra
	WAVE fs.shaxis		= root:SPHINX:SVD:fshift 				// shifted energy axis for reference spectra
	WAVE fs.unaxis		= root:SPHINX:SVD:faxis 				// unshifted energy axis for reference spectra
	WAVE fs.sumrefs	= root:SPHINX:SVD:fsum 				// sum of reference spectrum
	
	// Always start from default values before any fit
	FillLLSCoefficients(LLSCfs,NSel,dEFlag,POrder)
	
	Variable V_FitQuitReason, V_FitError, V_fitOptions=4, CFlag=1
	
	if (PosFlag || dEFlag)
		if (CFlag)
			// Start using a constraints wave just like for the MT method. 
			FuncFit /Q/N/H=HoldString LLSFitFunction, LLSCfs, spectrum[PtMin,PtMax] /X=energy /C={Cmatrix,Cwave} /STRC=fs /I=1/W=weight
		else
			FuncFit /Q/N/H=HoldString LLSFitFunction, LLSCfs, spectrum[PtMin,PtMax] /X=energy /C=cnstr /STRC=fs /I=1/W=weight
		endif
	else
		FuncFit /Q/N/H=HoldString LLSFitFunction, LLSCfs, spectrum[PtMin,PtMax] /X=energy /STRC=fs /I=1/W=weight
	endif
	
	Variable SimpleChi2=0
	iChiSqr 	= sqrt(V_chisq)/4
	
	// If it worked OK, fill the results waves. 
	If ((V_FitQuitReason == 0) && (V_FitError == 0))
		RefSoln[] 			= LLSCfs[p]								// Record just the amplitues and shift value. 
		
		if (SimpleChi2)
			refArea 	= abs(sum(root:SPHINX:SVD:fsum,PtMin,PtMax))
		else
			// debug 2013-05-20. Constraints not completely enforcing positive coefficients. E.g., -3.2535e-06
			
			WAVE fs.coefw		= LLSCfs 								// All best fit coefficients, including polynomial coefficients
			WAVE fs.xw			= root:SPHINX:SVD:ReferenceAxis
			WAVE fs.yw			= RefResults
			
			fs.minpt 			= 0										// Calculate the results for the entire axis ... 
			fs.areaflag 			= 1 									// ... and the area under the reference 
			LLSFitFunction(fs)
			refArea = fs.refarea
			RefResids[PtMin,PtMax] = spectrum[p] - RefResults[p]
			WaveStats /Q RefResids
			iChiSqr =  V_rms^2
		endif
		
		return iChiSqr
	else
		// Remove any other results from the Results wave
		RefResults = NaN
		return 0
	endif
End

// The fitting function 
Function  LLSFitFunction(s) : FitFunc 
	Struct LLSFitStruct &s 
	
	Variable i
	
	// Add the unshifted reference spectra to the composite
	s.sumrefs = 0
	for (i=0;i<s.nsel;i+=1)
		s.sumrefs[] += s.coefw[i] * s.refmatrix[p][i]
	endfor
	
	if (s.shflag)	// Shift the energy axis if requested
		// Cannot use the xw if shifting - causes edge effects during interpolation.
		s.shaxis[] 	= s.unaxis[p] - s.coefw[s.nsel]
		s.yw[] 		= s.sumrefs[BinarySearchInterp(s.unaxis, s.shaxis[p+s.minpt])]
//		s.yw[] 		= s.sumrefs[BinarySearchInterp(s.unaxis, s.shaxis[p+s.firstpt])]
	else
		s.yw[] 		= s.sumrefs[p+s.minpt]
//		s.yw[] 		= s.sumrefs[p+s.firstpt]
	endif
	
//	Variable fPT, lPT
	
	// This is used for normalizing chi-squared values. 
	if (s.areaflag == 1)
//		fPT = s.firstpt
//		lPT = s.lastpt
		s.refarea = sum(s.sumrefs,s.firstpt,s.lastpt)
	endif
	
	// Add the polynomial background
	if (s.porder == 0)				// Do nothing. 
	elseif (s.porder == 1)			// Add simple offset. 
		s.yw += s.coefw[s.pcoefpt]
	else								// Transfer the coefficients to the structure wave 
		s.pcoefw[] 	= s.coefw[p+s.pcoefpt]
		s.yw[] 	+= poly(s.pcoefw,s.xw[p]-s.center)
	endif
End

Function CalculatePolynomial(energy, polynomial, refCfs,NRefs, PolyOrder,PolyCenter,SVDChoice,PtMin,PtMax)
	Wave energy, polynomial, refCfs
	Variable NRefs, PolyOrder,PolyCenter,SVDChoice,PtMin,PtMax
	
	if (SVDChoice == 1)	// Matrix LLS
		return 0	// Do nothing here? I think  ... 
	endif

	polynomial = 0

	// Add the polynomial background
	if (PolyOrder == 0)			// Do nothing. 
	elseif (PolyOrder == 1)			// Add simple offset. 
		polynomial 		+= refCfs[NRefs+1]
	else								// Transfer the coefficients to the free wave
		Make /D/FREE/N=(PolyOrder) polyCfs
		polyCfs[] 		= refCfs[p+(NRefs+1)]
		polynomial[] 	+= poly(polyCfs,energy[p]-PolyCenter)
	endif
	
	polynomial[0,PtMin-1]		= NAN
	polynomial[PtMax+1,]		= NAN
End

Structure LLSFitStruct 
	Wave coefw 
	Wave yw 
	Wave xw
	STRUCT WMFitInfoStruct fi // Optional WMFitInfoStruct. 
	Variable minpt 		// First point in fit range
	Variable nsel 		// Number of reference spectra to fit
	Variable shflag 		// Energy shift flag
	Variable center 		// x-value at the center of the fit range
	Variable firstpt 	// the first point at the start of the fit range
	Variable lastpt 		// the last point at the start of the fit range
	Variable pcoefpt 	// start of polynomial coefficients in the coef wave
	Variable porder 	// polynomial order
	Variable areaflag 	// flag to calculate area for chi-squared
	Variable refarea 	// area of refs only (no polynomial)
	WAVE pcoefw		// polynomial coefficients
	WAVE refmatrix	// matrix of reference spectra
	WAVE sumrefs		// sum of reference spectrum on unshifted axis
	WAVE shaxis		// shifted energy axis for reference spectra
	WAVE unaxis		// unshifted energy axis for reference spectra

EndStructure

Function ReportLLSComponents(RefSoln)
	Wave RefSoln
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	
	Variable i, j=0, NRefs=DimSize(RefSelect,0)
	
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			Print "  		.... adding ",RefSoln[j],"of",RefDesc[i][1]
			j+=1
		endif
	endfor
End

// *************************************************************
// ****		SPECTRAL DECOMPOSITION BASED ON MatrixLLS 
// *************************************************************
Function SingleSVD(axis,spectrum,solution,PtMin)
	Wave axis,spectrum,solution
	Variable PtMin
	
	WAVE MatrixA 		= root:SPHINX:SVD:ReferenceMatrix
	WAVE MatrixB 		= root:SPHINX:SVD:DataMatrix
	
	// Fill the data matrix, or B
	MatrixB[][0] 	= spectrum[p+PtMin]
	
	// Perform the matrix analysis
	MatrixLLS MatrixA, MatrixB
	
	WAVE M_B = M_B
	solution[] 	= M_B[p]
	
	return !V_flag
End

// Calculate the best-fit composite spectrum
Function SVDChiSquared(spectrum,polynomial,results,residuals,solution,NCmpts,SVDPtMin,opFlag,refArea)
	Wave spectrum,polynomial,results,residuals,solution
	Variable NCmpts,SVDPtMin,opFlag, &refArea
		
	WAVE MatrixA 		= root:SPHINX:SVD:ReferenceMatrix
	WAVE MatrixB 		= root:SPHINX:SVD:DataMatrix
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	
	Variable i, j=0, NRefs, rConst, pConst, factor
	
	// Add the reference spectra
	results 	= 0
	NRefs 	= DimSize(RefSelect,0)
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			if (opFlag)
				Print "  		.... adding ",solution[j][0],"of",RefDesc[j][1]
			endif
			results[] += solution[j][0] * MatrixA[p][j]
			j+=1
		endif
	endfor
	rConst 		= area(results)
	refArea 	= rConst
	
	// Add the polynomial components
	polynomial = 0
	if (NCmpts > NRefs)
		for (i=j;i<NCmpts;i+=1)
			polynomial[] += solution[i][0] * MatrixA[p][i]
		endfor
	endif
	pConst 		= area(polynomial)
	
	results[] += polynomial[p]
End

Function isChecked(val)
	Variable val

	if ((val & 2^4) != 0)
		return 1	// Test if bit 4 is set
	else
		return 0
	endif
End

// *************************************************************
// ****		SPECTRUM ANALYSIS on extracted spectrum
// *************************************************************
//
//	Here, the input is actually SPECPLOT
Function SpectrumAnalysis(energy,spectrum,AutoFlag,StackName)
	Wave energy,spectrum
	Variable AutoFlag
	String StackName
	
	WAVE LLSCfs 		= root:SPHINX:SVD:LLSCfs
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceDescription
	
	WAVE RefScale 		= root:SPHINX:SVD:ReferenceScale
	WAVE RefSoln 		= root:SPHINX:SVD:SolutionMatrix
	WAVE MatrixA 		= root:SPHINX:SVD:ReferenceMatrix
	WAVE MatrixB 		= root:SPHINX:SVD:DataMatrix
	
	NVAR gPolyBGFlag 	= root:SPHINX:SVD:gPolyBGFlag
	NVAR gPolyBGOrder = root:SPHINX:SVD:gPolyBGOrder
	NVAR gSVDChoice 	= root:SPHINX:SVD:gSVDChoice
	NVAR gSVDdEFlag 	= root:SPHINX:SVD:gSVDdEFlag
	NVAR gSVDdEMax 	= root:SPHINX:SVD:gSVDdEMax 		///	<---- careful!!!!! 	Almost identical names
	NVAR gSVDPosFlag 	= root:SPHINX:SVD:gSVDPosFlag
	NVAR gSVDWgtFlag 	= root:SPHINX:SVD:gSVDWgtFlag
	NVAR gSVDdE		= root:SPHINX:SVD:gSVDdE
	NVAR gSVDChiSqr 	= root:SPHINX:SVD:gSVDChiSqr
	NVAR gSVDEMin 	= root:SPHINX:SVD:gSVDEMin		///	<---- careful!!!!! 	Almost identical names
	NVAR gSVDEMax 	= root:SPHINX:SVD:gSVDEMax
	NVAR gSVDUpdate 	= root:SPHINX:SVD:gSinglePixelUpdate
	
	NVAR gCursorBin 	= root:SPHINX:Browser:gCursorBin
	
	String SVDName, HoldString, SpectrumNote, ReferencesList=""
	Variable Success, refArea, iChiSqr,pChiSqr
	Variable duration, timeRef
	Variable i, j=0, n, m=0, SVDPtMin, SVDPtMax, NPts, NRefs, NSel, NCmpts, NCfs, POrder, PCenter
	
	// UpdateSVDMatrices() creates results, polynomial and residuals ... 
	NSel 	= PrepareSVDMatrices(SVDPtMin,SVDPtMax,NCmpts,1)
	if (NSel < 1)
		Print " *** Please select one or more reference spectra"
		return 0
	endif
	// ... so I can reference them here. 
	WAVE RefResults 	= root:SPHINX:SVD:Results
	WAVE RefPoly 		= root:SPHINX:SVD:Polynomial
	WAVE RefResids 	= root:SPHINX:SVD:Residuals
	
	POrder 		= (gPolyBGFlag == 1) ? gPolyBGOrder : 0
	PCenter 	= gSVDEMin+(gSVDEMax-gSVDEMin)/2
	
//	NCmpts 	= DimSize(MatrixA,1) 		// For SVD
	NCfs 		= 1 + NSel + gPolyBGOrder 	// For LLS
	NPts 		= DimSize(RefResults,0)	// For LLS
	NRefs 		= DimSize(RefList,0)	// For output
	
	if (!AutoFlag)
		Print " *** Spectrum analysis between",gSVDEMin,"-",gSVDEMax,"eV."
	endif
	
	timeRef 	= startMSTimer
	if (gSVDChoice == 1)
		SVDName 		= "SVD"
		
		Success 	= SingleSVD(energy,spectrum,RefSoln,SVDPtMin)
		
		if (Success)
			SVDChiSquared(spectrum,RefPoly,RefResults,RefResids,RefSoln,NCmpts,SVDPtMin,!AutoFlag, refArea)
		endif
		
		gSVDdE 	= 0
	elseif (gSVDChoice == 2)
		SVDName 	= "LLS"
		
		PrepareLLSMatrices(NPts,NCfs,POrder)
		PrepareLLSConstraints(NSel,NCfs,gSVDdEFlag,gSVDdEMax,gSVDPosFlag,"root:SPHINX:SVD:")
		HoldString 	= PrepareLLSHoldString(NSel,gSVDdEFlag,POrder)
		Success 	= SingleLLS(energy,spectrum,RefPoly,RefResults,RefResids,RefSoln,SVDPtMin,SVDPtMax,NSel,NCfs,gSVDdEFlag,gSVDEMax,PCenter,POrder,gSVDPosFlag,refArea,iChiSqr,HoldString)
				
		if ((!AutoFlag) && (Success))
			ReportLLSComponents(RefSoln)
//			gSVDdE 	= (gSVDdEFlag == 1) ? RefSoln[NSel] : 0
		else
//			gSVDdE	= 0
		endif
		gSVDdE 	= (gSVDdEFlag == 1) ? RefSoln[NSel] : 0
		
	endif
	duration 	= StopMSTimer(timeRef)
	
	
	if (Success)
		if (!AutoFlag)
			Print " 		.... ",SVDName," analysis took",duration/1000,"ms. "
		endif
		
		SpectrumNote 	= "Analysis method="+SVDName+"\r"
		for (n=0;n<NRefs;n+=1)
			if (isChecked(RefSelect[n][0]))
				ReferencesList 	= ReferencesList + "Reference "+num2str(m)+" Name="+RefList[n][1]+";"
				ReferencesList 	= ReferencesList + "Reference "+num2str(m)+" Amount="+num2str(RefSoln[m])+"\r"
//				ReferencesList 	= ReferencesList + "Reference "+num2str(m)+" Proportion="+num2str(RefSoln[m])+"\r"
				m += 1
			endif
		endfor
		SpectrumNote 	= SpectrumNote + ReferencesList
		SpectrumNote 	= SpectrumNote + "Fit range="+num2str(gSVDEMin)+" - "+num2str(gSVDEMax)+" eV\r"
		
		// Claculate the chi-squared using our definitions
//		CalculateChiSquared(spectrum,RefResults,RefResids,gSVDChoice,SVDPtMin,SVDPtMax,refArea,iChiSqr,pChiSqr)
		
		
		gSVDChiSqr 	= iChiSqr
		
		
		SpectrumNote 	= SpectrumNote + "Chi-squared="+num2str(gSVDChiSqr)+"\r"
		
		if (gSVDdEFlag)
			SpectrumNote 	= SpectrumNote + "Energy shift="+num2str(gSVDdE)+"eV\r"
		endif
		
		CalculatePolynomial(energy,RefPoly,LLSCfs,NSel,POrder,PCenter,gSVDChoice,SVDPtMin,SVDPtMax)
		
		// (Optionally) transfer the fit results to the relevant image(s)
		if (gSVDUpdate == 1)
			String SpecNote = Note(spectrum)
			Variable dE, X, X2, Y, Y2, Bin
			dE = LLSCfs[NSel]
			X=NumberByKey("X1",SpecNote,"=",";"); X2=NumberByKey("X2",SpecNote,"=",";")
			Y=NumberByKey("Y1",SpecNote,"=",";"); Y2=NumberByKey("Y2",SpecNote,"=",";") 
			FillSVDImages(RefSoln, RefScale, StackName,iChiSqr,pChiSqr,dE,X,Y,X2,Y2,gCursorBin,gSVDPosFlag)
		endif
		
		SpectrumNote 	= SpectrumNote + "# Polynomial terms="+num2str(POrder)+" (where 1 = constant)\r"
		Note spectrum, SpectrumNote
	else
		if (!AutoFlag)
			Print " 		.... ",SVDName," analysis failed. You could try one or both of the following: "
			Print " 									-- reducing the number of polynomial terms.  "
			Print " 									-- increasing the maximum permissible energy shift.  "
		endif
		
		gSVDChiSqr 	= 0
	endif
End







// *************************************************************
// ****		SPECTRUM ANALYSIS on image ROI
// *************************************************************
Function ROISVD(SPHINXStack,StackFolder,PanelFolder,ShiftDown)
	Wave SPHINXStack
	String StackFolder, PanelFolder
	Variable ShiftDown
	
	NVAR gSVDChoice 	= root:SPHINX:SVD:gSVDChoice
	
	NVAR gPBGFlag 		= root:SPHINX:SVD:gPolyBGFlag
	NVAR gPBGOrder 	= root:SPHINX:SVD:gPolyBGOrder
	NVAR gSVDdEFlag 	= root:SPHINX:SVD:gSVDdEFlag
	NVAR gSVDdEMax 	= root:SPHINX:SVD:gSVDdEMax
	NVAR gSVDPosFlag 	= root:SPHINX:SVD:gSVDPosFlag
	NVAR gSVDWgtFlag 	= root:SPHINX:SVD:gSVDWgtFlag
	NVAR gSVDEMin 	= root:SPHINX:SVD:gSVDEMin
	NVAR gSVDEMax 	= root:SPHINX:SVD:gSVDEMax
	
	NVAR gROIMapFlag 	= root:SPHINX:SVD:gROIMappingFlag
	NVAR gImageROIFlag = root:SPHINX:SVD:gImageROIFlag

	NVAR gSVDBin 		= root:SPHINX:SVD:gSVDBin
	NVAR gSVDX1 		= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDX2 		= root:SPHINX:SVD:gSVDRight
	NVAR gSVDY1 		= root:SPHINX:SVD:gSVDBottom
	NVAR gSVDY2 		= root:SPHINX:SVD:gSVDTop
	
	String StackName 	= NameOfWave(SPHINXStack)
//	String StackFolder 	= GetWavesDataFolder(SPHINXStack,1)
	WAVE StackAxis  	= $(StackFolder + StackName + "_axis")
	WAVE avStack 		= $(StackFolder + StackName + "_av")
	WAVE roiStack 		= $(StackFolder + StackName + "_av_roi")
	Variable NSel, NCmpts, SVDPtMin, SVDPtMax, POrder, PCenter, ROIFlag, MaskFlag


	// If AutoSave box is checked, save the experiment
	MakeVariableIfNeeded("root:SPHINX:SVD:autoSave",0)
	NVAR autoSave = $("root:SPHINX:SVD:autoSave")
	if (autoSave)
		if (stringmatch(igorInfo(1),"Untitled"))
			string tempFileName = StackName
			if (strsearch(tempFileName,"X",0) == 0)
				tempFileName = ReplaceString("X", tempFileName+".pxp", "", 0, 1)
			endif
			SaveExperiment /P=Path2Image as tempFileName
		else
			SaveExperiment
		endif
	endif


	// *!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*
	// 		The MT method uses entirely different code
	if (gSVDChoice == 3)
		if (gROIMapFlag || gImageROIFlag || (gSVDBin>1))
			DoAlert 1, "Multi-thread mapping does not currently support binning or use of ROI. Continue?"
			if (V_flag == 2)
				return 0
			endif
		endif
		MTROISVD(SPHINXStack,StackAxis, StackROI, StackName, StackFolder,PanelFolder)
		// A single-thread version for debugging
//		STMTROISVD(SPHINXStack,StackAxis, StackROI, StackName, StackFolder,PanelFolder)
		return 1
	endif
	// *!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*!*
	
	
	NSel 	= PrepareSVDMatrices(SVDPtMin,SVDPtMax, NCmpts,1)
	if (NSel < 1)
		Print " *** Please select one or more reference spectra"
		return 0
	endif
	
	// This is only meaningful for Matrix LLS, and is null otherwise. 
//	NCmpts 	= DimSize(MatrixA,1)
	
	if (!NVAR_Exists(gSVDX1))
		Print " *** Please select an ROI"
		return 0
	endif

	POrder 		= (gPBGFlag == 1) ? gPBGOrder : 0
	PCenter 	= gSVDEMin+(gSVDEMax-gSVDEMin)/2
	
	// Prepare the result images
	PrepareSVDImages(StackName,DimSize(SPHINXStack,0),DimSize(SPHINXStack,1))
	
	// Check whether we are mapping an ROI within the selected area
	if (gROIMapFlag)
		ROIFlag 	= CheckROIMapping(roiStack,gROIMapFlag,gSVDX1,gSVDX2,gSVDY1,gSVDY2)
		if (ROIFlag==0)
			print " 		... Aborted the mapping routine due to pink ROI problem"
			return 0
		endif
		Print " *** Mapping the pink ROI within the marquee selected area ... ", gSVDX1," < x < ",gSVDX2," and ", gSVDY1," < y < ",gSVDY2," with bin size",gSVDBin
		
	elseif (gImageROIFlag)
		String MaskDescription
		WAVE SVDMask 	= $("root:SPHINX:Stacks:"+StackName + "_Map_mask")
		MaskFlag 	= SelectImageMask(SVDMask,StackName,Dimsize(SPHINXStack,0),Dimsize(SPHINXStack,1),MaskDescription)
		if (MaskFlag==0)
			print " 		... Aborted the mapping routine due to image mask problem"
			return 0
		endif
		Print " *** Mapping the pixels defined by",MaskDescription," within the marquee selected area ... ", gSVDX1," < x < ",gSVDX2," and ", gSVDY1," < y < ",gSVDY2," with bin size",gSVDBin
	else
		Print " *** Mapping all pixels within the marquee selected area ... ", gSVDX1," < x < ",gSVDX2," and ", gSVDY1," < y < ",gSVDY2," with bin size",gSVDBin
	endif
	
	try
		if (ShiftDown) //<--- This does nothing at present!!
//			RealROISVD(SPHINXStack,avStack,roiStack,StackName,PanelFolder,gSVDChoice,gSVDX1,gSVDY1,gSVDX2,gSVDY2,gSVDBin,POrder,PCenter,gSVDdEFlag,gSVDdEMax,gSVDPosFlag,gSVDWgtFlag,ROIFlag,SVDPtMin,SVDPtMax,NSel,NCmpts); AbortOnRTE
		else
			RealROISVD(SPHINXStack,avStack,roiStack,SVDMask,StackName,PanelFolder,gSVDChoice,gSVDX1,gSVDY1,gSVDX2,gSVDY2,gSVDBin,POrder,PCenter,gSVDdEFlag,gSVDdEMax,gSVDPosFlag,gSVDWgtFlag,ROIFlag,MaskFlag,SVDPtMin,SVDPtMax,NSel,NCmpts); AbortOnRTE
		endif
	catch
		CloseProcessBar()
		StopAllTimers()
		if (V_AbortCode == -1)
			Print " *** Chemical mapping routine aborted by user."
		else
			Print " *** Chemical mapping routine aborted due to error."
		endif
	endtry

	// If AutoSave box is checked, save the experiment
	if (autoSave)
		// uncheck the box to prevent accidental AutoSaving in the future
		autoSave = 0
		SaveExperiment
	endif
End

Function RealROISVD(SPHINXStack,avStack,roiStack,maskStack,StackName,PanelFolder,SVDChoice,X1,Y1,X2,Y2,Bin,POrder,PCenter,dEFlag,dEMax,PosFlag,WgtFlag,ROIFlag,MaskFlag,PtMin,PtMax,NSel,NCmpts)
	Wave SPHINXStack, avStack, roiStack, maskStack
	String StackName, PanelFolder
	Variable SVDChoice, X1,Y1,X2,Y2,Bin, POrder,PCenter, dEFlag, dEMax, PosFlag, WgtFlag, ROIFlag, MaskFlag, PtMin, PtMax, NSel,NCmpts
	
	// The extracted spectrum, in the Browser folder
	WAVE energy 				= $(PanelFolder+":energy")
	WAVE spectrum 			= $(PanelFolder+":specplot")
	WAVE specbg 					= $(PanelFolder+":specbg")
	WAVE specIo 			= $(PanelFolder + ":spectrumIo")
	
// 2014-40-12 Added STXM vs PEEM normalization options
	NVAR gLinBGFlag			= $(PanelFolder+":gLinBGFlag")
	NVAR gIoDivFlag			= $(PanelFolder+":gIoDivFlag")
	NVAR gIoODImax 			= $(PanelFolder+":gIoODImax")
	NVAR gIoDivChoice 			= $(PanelFolder+":gIoDivChoice")
//	NVAR gInvertSpectraFlag	= $(PanelFolder+":gInvertSpectraFlag")
//	NVAR gReverseAxisFlag		= $(PanelFolder+":gReverseAxisFlag")

// 2020-10 Add the ability to save the experiment during the processing
	NVAR autoSave = $("root:SPHINX:SVD:autoSave")
	
	Variable IoDivChoice 		= gIoDivFlag + 1
	if (NVAR_Exists(gIoDivChoice))
		IoDivChoice 	= gIoDivChoice 	// backwards compatibility
	endif
	
	WAVE RefScale 			= root:SPHINX:SVD:ReferenceScale
	WAVE RefResults 		= root:SPHINX:SVD:Results
	WAVE RefPoly 			= root:SPHINX:SVD:Polynomial
	WAVE RefResids 		= root:SPHINX:SVD:Residuals
	WAVE RefSelect 			= root:SPHINX:SVD:ReferenceSelection
	
	// The size of the solution matrix depends on the method. 
	WAVE RefSoln 		= root:SPHINX:SVD:SolutionMatrix
	
	WAVE RefAxis 		= root:SPHINX:SVD:ReferenceAxis
	WAVE MatrixA 		= root:SPHINX:SVD:ReferenceMatrix
	WAVE MatrixB 		= root:SPHINX:SVD:DataMatrix
	
	NVAR gSVDChiSqr 	= root:SPHINX:SVD:gSVDChiSqr
	NVAR gLiveSVDFlag 	= root:SPHINX:SVD:gLiveSVDFlag
	
	// Some Results images
	WAVE iChi2 	= $("root:SPHINX:Stacks:"+StackName + "_iMap_x2")
	WAVE pChi2 	= $("root:SPHINX:Stacks:"+StackName + "_pMap_x2")
	WAVE dEMap 	= $("root:SPHINX:Stacks:"+StackName + "_Map_dE")
	
	// The solutions for every (binned) pixel in the stack. 
	Variable NumX=DimSize(avStack,0), NumY=DimSize(avStack,1)
	Make /FREE/N=(NumX,NumY,NSel) StackSolnMatrix
	Make /FREE/N=(NumX,NumY,NSel) StackScaleMatrix
	
	Variable i, j, m, n, nm, mMax, nMax, BGMin, BGMax, NPixels=0, old=0
	Variable Success, refArea, iChiSqr, pChiSqr, dE=0, Const, NPts, NCfs
	Variable duration,timeRef = startMSTimer
	
	Variable SimpleChi2=0
	
	OpenProcBar("Performing component analysis on ROI from "+StackName); DoUpdate
	
	NCfs 		= 1 + NSel + POrder 		// For LLS
	NPts 		= DimSize(RefResults,0)	 // For LLS
	
	String HoldString=""
	if (SVDChoice == 2) 		// Only need do this once. 
		 PrepareLLSMatrices(NPts,NCfs,POrder)
		 PrepareLLSConstraints(NSel,NCfs,dEFlag,dEMax,PosFlag,"root:SPHINX:SVD:")
		 HoldString	= PrepareLLSHoldString(NSel,dEFlag,POrder)
	endif

	if (gLinBGFlag)	
		BGMin 	= min(pcsr(A, "StackBrowser#PixelPlot"),pcsr(B, "StackBrowser#PixelPlot"))
		BGMax 	= max(pcsr(A, "StackBrowser#PixelPlot"),pcsr(B, "StackBrowser#PixelPlot"))
	endif
	
	Variable GoodPixel=1
	for (i=X1;i<X2;i+=Bin)
		
		if ( (autoSave) && (mod(i,100)==0 ))
			print " 	-	-	- saved a backup at i =",i
			SaveExperiment
		endif

		for (j=Y1;j<Y2;j+=Bin)
					
			// There are two kinds of ROI that could be in use. 
			GoodPixel = 1
			if (ROIFlag)
				if (roiStack[i][j]!=0)
					GoodPixel = 0
				endif
			endif
			
			if (MaskFlag)
				if (maskStack[i][j]!=0)
					GoodPixel = 0
				endif
			endif
	
			if (GoodPixel)
					
//			if (!ROIFlag || (ROIFlag && (roiStack[i][j]==0)))
				// Fill the data matrix
//				MatrixB[][0] = 0
				spectrum = 0
				
				nm 		= 0
				mMax 	= (i+Bin > X2) ? X2 : (i+Bin)
				nMax 	= (j+Bin > Y2) ? Y2 : (j+Bin)
				
				// Bin over the 
				for (m=i;m < mMax;m+=1)
					for (n=j;n < nMax;n+=1)
						spectrum[] 	+= SPHINXStack[m][n][p]
						nm += 1
					endfor
				endfor
		
				if (nm > 0)
					
					// ----------------			NormalizeExtractedSpectrum() 		------------------------
					if (IoDivChoice == 2)
						// Divide by the Izero - for PEEM
						spectrum /= specIo
					elseif (IoDivChoice == 3)
						// Convert to OD using Izero - STXM
						spectrum[] 	= -1 * ln(spectrum[p]/specIo[p])
					elseif (IoDivChoice == 4)
						spectrum[] 	= -1 * ln(spectrum[p]/gIoODImax)
					endif
					
					if (gLinBGFlag)	
						SubtractLinearBG(spectrum,specbg,BGMin,BGMax)
					endif
					
					spectrum /= nm
					// ----------------			NormalizeExtractedSpectrum() 		------------------------
					
//					MatrixB[][0] = spectrum[p +PtMin]
					
					if (SVDChoice == 1)
					
						// I think this can go here
						MatrixB[][0] = spectrum[p +PtMin]
					
						Success = SingleSVD(energy,spectrum,RefSoln,PtMin)
						
						if (Success)
							SVDChiSquared(spectrum,RefPoly,RefResults,RefResids,RefSoln,NCmpts,PtMin,0,refArea)
						endif
						
						// I think this can go here
						MatrixB[][0] = 0
						
					elseif (SVDChoice == 2)
						
						Success = SingleLLS(energy,spectrum,RefPoly,RefResults,RefResids,RefSoln,PtMin,PtMax,NSel,NCfs,dEFlag,dEMax,PCenter,POrder,PosFlag,refArea,iChiSqr,HoldString)
						
						// Make sure that energy shift is set to zero if the fit did not complete properly
						dE 		= (Success > 0) ? RefSoln[NSel] : 0
						
					endif
					
					if (SimpleChi2)
						iChiSqr = Success
						pChiSqr = Success/refArea
					else
						CalculateChiSquared(spectrum, RefResults,RefResids,SVDChoice,PtMin,PtMax,refArea,iChiSqr,pChiSqr)
					endif
					
					if (gLiveSVDFlag)
						DoUpdate /W=ReferencePanel
					endif
				else
					RefSoln 	= NAN
					iChiSqr 	= NAN
					pChiSqr 	= NAN
					dE 			= NAN
				endif
				
				// Place  the Reference Spectra SCALE coefficients into a 3D array
				if (PosFlag)
					RefScale[] = max(RefSoln[p],0)
				else
					RefScale[] = RefSoln[p]
				endif
				StackSolnMatrix[i,min(i+Bin,X2)][j,min(j+Bin,Y2)][] 	= RefScale[r]
				
				// Place  the Reference Spectra PROPORTIONAL coefficients into a 3D array
				Const = sum(RefScale)
				RefScale /= Const
				StackScaleMatrix[i,min(i+Bin,X2)][j,min(j+Bin,Y2)][] 	= RefScale[r]

				// Transfer the chi-squared and energy shift values directly to the image results
				iChi2[i,min(i+Bin,X2)][j,min(j+Bin,Y2)] 	= iChiSqr
				pChi2[i,min(i+Bin,X2)][j,min(j+Bin,Y2)] 	= pChiSqr
				dEMap[i,min(i+Bin,X2)][j,min(j+Bin,Y2)] 	= dE

				NPixels += 1
			endif
			
		endfor
		UpdateProcessBar((i-X1)/(X2-X1))
	endfor
	CloseProcessBar()
	
	// Try putting it here.
	if (old == 0)
		FillSVDImages2(StackSolnMatrix, StackScaleMatrix, RefSelect, StackName,X1,X2,Y1,Y2,MaskFlag)
	endif
	
	if (NPixels == 0)
		DoAlert 0, "Zero pixels lay within marquee and ROI"
	endif
	
	duration 	= stopMSTimer(timeRef)
	print " 		 ... took",duration/1000000,"s."
End



// *************************************************************
// ****		Transferring the Component Mapping results to Images
// *************************************************************

// This is the fast approach for Mapping. Transfers to the images after all the fitting is completed. 
Function FillSVDImages2(StackSolnMatrix, StackScaleMatrix, RefSelect, StackName,X1,X2,Y1,Y2,MaskFlag)
	Wave StackSolnMatrix, StackScaleMatrix, RefSelect
	String StackName
	Variable X1,X2,Y1,Y2,MaskFlag

	String ImageName, planeName
	Variable i, j=0,NRefs = DimSize(RefSelect,0)

	Variable x,y

	WAVE SVDMask 	= $("root:SPHINX:Stacks:"+StackName + "_Map_mask")

	// Loop through the selected Refs
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
		
			ImageTransform /P=(j) getPlane StackSolnMatrix
			WAVE M_ImagePlane 	= M_ImagePlane

			//  --------------		The simple component strength - INTENSITY maps
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+ StackName + "_iMap_"+num2str(i))
//			SVDImage[X1,X2][Y1,Y2] 	= StackSolnMatrix[p][q][j]
			for (x = X1; x < X2; x += 1)
				for (y = Y1; y < Y2; y += 1)
					if ( (MaskFlag && (SVDMask[x][y] == 0)) || !MaskFlag)
						SVDImage[x][y] = StackSolnMatrix[x][y][j]
					endif
				endfor
			endfor
			
			//   --------------		The scaled component strength - PROPORTIONAL maps
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+StackName + "_pMap_"+num2str(i))
//			SVDImage[X1,X2][Y1,Y2] 	= StackScaleMatrix[p][q][j]
			for (x = X1; x < X2; x += 1)
				for (y = Y1; y < Y2; y += 1)
					if ( (MaskFlag && (SVDMask[x][y] == 0)) || !MaskFlag)
						SVDImage[x][y] = StackScaleMatrix[x][y][j]
					endif
				endfor
			endfor
			
			j+=1
		endif
	endfor
End

// This is the old approach, now only used for Single Spectrum analysis. 
// Transfer the results of a single SVD Analysis 
Function FillSVDImages(RefSoln, RefScale, StackName,iChiSqr,pChiSqr,dE,X,Y,X2,Y2,Bin,PosFlag)
	Wave RefSoln, RefScale
	String StackName
	Variable iChiSqr,pChiSqr,dE,X,Y,X2,Y2,Bin,PosFlag

	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	
	String ImageName
	Variable i, j=0, Const,NRefs
	
	// The Single-Spectrum Analysis does not create the SVD Images.
	if (!WaveExists($("root:SPHINX:Stacks:"+StackName + "_iMap_x2")))
		return 0
	endif
	
	NRefs=DimSize(RefSelect,0)
	
	RefScale[] = RefSoln[p]
	
	// Scale the factors to their sum for proportional mapping
	Const = sum(RefScale)
	RefScale /= Const
	
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			// The simple component strength - INTENSITY maps
			ImageName = StackName + "_iMap_"+num2str(i)
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+ImageName)
			SVDImage[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = RefSoln[j]
			
			// The scaled component strength - PROPORTIONAL maps
			ImageName = StackName + "_pMap_"+num2str(i)
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+ImageName)
			SVDImage[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = RefScale[j]
			j+=1
		endif
	endfor
	
	if (iChiSqr > 0)		// The simple chi-squared image
		ImageName = StackName + "_iMap_x2"
		WAVE iChi2 	= $("root:SPHINX:Stacks:"+ImageName)
		iChi2[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = iChiSqr
	endif
	
	if (pChiSqr > 0)		// The scaled chi-squared image
		ImageName = StackName + "_pMap_x2"
		WAVE pChi2 	= $("root:SPHINX:Stacks:"+ImageName)
		pChi2[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = pChiSqr
	endif
	
	if (abs(dE) > 0)		// The energy offset image
		ImageName = StackName + "_Map_dE"
		WAVE dEMap 	= $("root:SPHINX:Stacks:"+ImageName)
		dEMap[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = dE
	endif
End

// *************************************************************
// ****		Rescaling SVD distribution maps to a consistent 256 grey scale
// *************************************************************
//
// 	The current idea is to discard pixels exceeding a chi-squared threshold when finding min and max values in maps. 
// 	This may not be best approach, so add another possibility of manually discarding intensity values. 
// 	

Function RescaleSVDImages(StackName,NumX,NumY)
	String StackName
	Variable NumX,NumY
	
	WAVE RefSelect 			= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 		= root:SPHINX:SVD:ReferenceDescription
	SVAR gRescaleMethod 	= root:SPHINX:SVD:gRescaleMethod
	SVAR gRescaleOutput 	= root:SPHINX:SVD:gRescaleOutput
	NVAR gChi2Type 		= root:SPHINX:SVD:gChi2Type
	NVAR gMinX2 			= root:SPHINX:SVD:gMinX2
	NVAR gMaxX2 			= root:SPHINX:SVD:gMaxX2
	NVAR gSVDPosFlag 		= root:SPHINX:SVD:gSVDPosFlag
	
	String ImageName, MaskDescription,  msg="", Description, SVDType 	= "_pMap_"
	Variable i, j=0, IMin=0, IMax=1, NNans
	Variable BEFlag 		= NumVarOrDefault("root:SPHINX:SVD:gBEFlag",1)
	Variable BEMaxLevel 	= NumVarOrDefault("root:SPHINX:SVD:gBEMaxLevel",230)
	Variable FindRange=0, NUsedRefs=0, NRefs = DimSize(RefSelect,0)
	
	if (gMinX2 >= gMaxX2)
		DoAlert 0, "Please choose an appropriate min-max range for rescaling"
		return 0
	endif
	
	if (cmpstr(gRescaleOutput,"intensity") == 0)
		Print " *** Creating new 'iMap' images with 256 gray levels for output as TIFF"
		SVDType 	= "_iMap_"
	
	elseif (cmpstr(gRescaleOutput,"proportion") == 0)
		Print " *** Creating new 'pMap' images with 250 gray levels for output as TIFF"
		Print " 		 Note: discarded pixels are given a 255 gray level value. "
		SVDType 	= "_pMap_"
			
		DoAlert 1, "Check proportional maps for spurious values?"
		for (i=0;i<NRefs;i+=1)
			if (isChecked(RefSelect[i][0]))
				NUsedRefs += 1
				ImageName = StackName + "_pMap_"+num2str(i)
				WAVE SVDImage = $("root:SPHINX:Stacks:"+ImageName)
				if (V_flag)
					MultiThread SVDImage[][] 	= ((SVDImage[p][q] < 0) || (SVDImage[p][q] > 1)) ? NAN : SVDImage[p][q]
				endif
			endif
		endfor
		
//		if (NUsedRefs == 3)
			BEFlag = 0
//			DoAlert 1, "Enhance pixel RGB brightness?"
			DoAlert 1, "Enhance pixel RGB brightness?"
			if (V_flag)
				BEFlag = 1
			endif
//		endif
	endif
	
	msg 		= " 		.... the range of relative proportions in the renormalized chemical distribution maps for is "
	
	WAVE SVDMask 	= $("root:SPHINX:Stacks:"+StackName + "_Map_mask")
	
	strswitch(gRescaleMethod)
		case "iMap chi-sqr":
			WAVE ChiSqr 	= $("root:SPHINX:Stacks:"+StackName+"_iMap_X2")
			SVDMask[][] = (ChiSqr[p][q] < gMaxX2) ? 0 : 255
			break
			
		case "pMap chi-sqr":
			WAVE ChiSqr 	= $("root:SPHINX:Stacks:"+StackName+"_pMap_X2")
			SVDMask[][] = (ChiSqr[p][q] < gMaxX2) ? 0 : 255
			break
		
		case "avg image intensity":
			WAVE StackAvg 	= $("root:SPHINX:Stacks:"+StackName+"_av")
			SVDMask[][] = ((StackAvg[p][q] < gMinX2) || (StackAvg[p][q] > gMaxX2)) ? 255 : 0
			break
		
		case "spectral peak":
			MaskPixelsBySummingRefs(SVDMask,StackName,"_iMap_",gMinX2,gMaxX2,NRefs)
			break
		
		case "min < i < max":
			MaskPixelsOutsideRange(SVDMask,StackName,"_iMap_",gMinX2,gMaxX2,NRefs)
			break
			
		case "min < p < max":
			MaskPixelsOutsideRange(SVDMask,StackName,"_pMap_",gMinX2,gMaxX2,NRefs)
			break
			
		case "image mask":
			if (SelectImageMask(SVDMask,StackName,NumX,NumY,MaskDescription) == 0)
				return 0
			endif
			break
			
		default:
			SVDMask = 0
			Print " 		.... Rescale relative proportion maps for",StackName,"to full scale."
	endswitch
	
	WaveStats /Q/M=1 $("root:SPHINX:Stacks:"+StackName+"_pMap_X2")
	NNans = V_numNans
	
	WaveStats /Q/M=1 SVDMask
	Print " 		.... Masked",V_npnts*(V_avg/255),"pixels out of ",(V_npnts-NNans) 
	
	FindImageIntensityRange(SVDMask,StackName,SVDType,IMin,IMax,NRefs,gSVDPosFlag)
	Print " 		.... The range of unmasked values is",IMin,"-",IMax
	
	// The actual scaling factors
	Variable offset 	= IMin
	Variable scale 	= 250/(IMax-IMin)
	Print " 		.... The actual transformation factors are: offset = ",offset,"     and scale = ",scale 
	
	MakeRescaledImages(SVDMask,StackName,SVDType,scale,offset,NRefs,NumX,NumY)
	
	if (BEFlag == 1)
//		MakeBrightnessEnhancedRGBImages(SVDMask,StackName,SVDType,scale,offset,255,NRefs,NumX,NumY)
		MakeBrightnessEnhancedImages(SVDMask,StackName,SVDType,scale,offset,255,NRefs,NumX,NumY)
	endif
End

Function SelectImageMask(SVDMask,StackName,NumX,NumY,MaskDescription)
	Wave SVDMask
	String StackName, &MaskDescription
	Variable NumX,NumY

	String PanelList 	= ReplaceString("Stack",ImagePanelList(StackName,"StackImage","",0,DimX=NumX,DimY=NumY),"")
	String PanelName 	= STRVarOrDefault("root:SPHINX:gMaskPanelName","")
	Prompt PanelName, "Name of image display panel containing the mask", popup, PanelList
	DoPrompt "Choose the image display panel containing the mask", PanelName
	if (V_flag)
		return 0
	endif
	String /G root:SPHINX:gMaskPanelName = PanelName
	
	WAVE Image = ImageNameToWaveRef("Stack"+PanelName+"#StackImage",PanelName)
	if (!WaveExists(Image))
		return 0
	endif
	
	String ImageDF 		= "root:SPHINX:"+PanelName
	NVAR gImageMin 	= $(ParseFilePath(2,ImageDF,":",0,0)+"gImageMin")
	NVAR gImageMax 	= $(ParseFilePath(2,ImageDF,":",0,0)+"gImageMax")
	
	SVDMask[][] = ((Image[p][q] < gImageMin) || (Image[p][q] > gImageMax)) ? 255 : 0
	
	MaskDescription = "Thresholded image used for masking is "+NameOfWave(Image)+". Pixels excluded if they lie outside {"+num2str(gImageMin)+" to "+num2str(gImageMax)+"}"
	
	return 1
End

Function MaskPixelsOutsideRange(SVDMask,StackName,SVDType,IMin,IMax,NRefs)
	Wave SVDMask
	String StackName, SVDType
	Variable IMin, IMax, NRefs

	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	
	SVDMask = 0	// i.e., not masked
	
	Variable i
	
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			// Either the simple or scaled distribution maps
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i))
			
			// Perhaps this is better. 
			SVDMask[][] = ((SVDMask[p][q] == 255) || (SVDImage[p][q] < IMin) || (SVDImage[p][q] > IMax)) ? 255 : SVDMask[p][q]
//			SVDMask[][] = ((SVDMask[p][q] == 255) || (SVDImage[p][q] < IMin) || (SVDImage[p][q] > IMax)) ? 255 : 0
			
		endif
	endfor
End

// I really don't recall what situation this is for! 
Function MaskPixelsBySummingRefs(SVDMask,StackName,SVDType,IMin,IMax,NRefs)
	Wave SVDMask
	String StackName, SVDType
	Variable IMin, IMax, NRefs

	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	
	SVDMask = 0	// i.e., not masked
	
	Variable i
	
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			// Either the simple or scaled distribution maps
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i))
			
			SVDMask[][] 		+= SVDImage[p][q]
		endif
	endfor
	
	SVDMask[][] = ((SVDMask[p][q] < IMin) || (SVDMask[p][q] > IMax)) ? 255 : 0
End

Function FindImageIntensityRange(ImageMask,StackName,SVDType,IMin,IMax,NRefs,PosFlag)
	Wave ImageMask
	String StackName, SVDType
	Variable &IMin, &IMax, NRefs, PosFlag

	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	
	Variable i
	
	IMin 	= 1e99
	IMax 	= -1e99
	
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			// Either the simple or scaled distribution maps
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i))
			
			ImageStats /M=1/R=ImageMask SVDImage
			
			if (PosFlag)
				if (abs(V_min) < IMin)
					IMin = V_min
				endif
			else
				if (V_min < IMin)
					IMin = V_min
				endif
			endif
			if (V_max > IMax)
				IMax = V_max
			endif
		endif
	endfor
End


// *******	This gave bad results when trying to make 8-bit waves for the scaled output images. 
// *******	Give up for now, and use single-precision images instead. 
Function MakeRescaledImages(ImageMask,StackName,SVDType,scale,offset,NRefs,NumX,NumY)
	Wave ImageMask
	String StackName, SVDType
	Variable scale,offset, NRefs, NumX, NumY
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	
	String ImageName, Description
	Variable value0, value, i, j=0, n, m

	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			Description 	= "Rescaled Intensities of "+RefDesc[i][1]
			
			ImageName = StackName + SVDType+num2str(i)
			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+ImageName)
			
			// The rescaled ("processed") SVD map
			ImageName 	= StackName + SVDType+num2str(i)+"_sc"
			Make /O/N=(NumX, NumY) $("root:SPHINX:Stacks:"+ImageName) /WAVE=PSVDImage
			
			Note /K PSVDImage
			Note PSVDImage, Description
			
			// in one line
			PSVDImage[][] = (ImageMask[p][q] == 0) ? round(scale * (SVDImage[p][q]-offset)) : 255
			
		endif
	endfor
End



// This Brightness Enhancement routine enhance the pixel brightness for a fit with an arbitrary number of refences. 
Function MakeBrightnessEnhancedImages(ImageMask,StackName,SVDType,scale,offset,MaxLevel,NRefs,NumX,NumY)
	Wave ImageMask
	String StackName, SVDType
	Variable scale,offset, MaxLevel ,NRefs, NumX, NumY
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	
	String ImageNameR, ImageNameG, ImageNameB
	Variable i

	// A temporary normalization wave - find the max value of the same pixel across the 3 waves. 
	Make /FREE/O/N=(NumX, NumY) TmpImage=0
	
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
				
				// A wave reference to the scaled wave
				WAVE Image 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc")
				
				// Set each pixel of the temporary image to the maximum among all waves
				MultiThread TmpImage[][] 	= max(Image[p][q],TmpImage[p][q])
		endif
	endfor
		
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
				
				// A wave reference to the scaled wave
				WAVE Image 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc")
				
				// A new wave for export
				Make /O/D/N=(NumX,NumY) $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc_BE") /WAVE=ImageBE
				
				// Now renormalize each pixel according to the normalization factor so max value is 250 not 255. 
				MultiThread ImageBE[][] 	= Image[p][q] * (MaxLevel/TmpImage[p][q])
				
				// Now set masked values to 0
				MultiThread ImageBE[][] 	= (ImageMask[p][q] == 0) ? Image[p][q] : 0

		endif
	endfor
	
	WaveStats /Q/M=1 TmpImage
	Print " 		.... Brightness enhancement: Individually scale each pixel so that the max channel is set to 250."
	Print " 		.... Brightness enhancement: Largest and smallest scale values are",V_max,V_min
End

// This Brightness Enhancement routine assumes that we are exporting only 3 components from a 3-reference fit. 
Function MakeBrightnessEnhancedRGBImages(ImageMask,StackName,SVDType,scale,offset,MaxLevel,NRefs,NumX,NumY)
	Wave ImageMask
	String StackName, SVDType
	Variable scale,offset, MaxLevel ,NRefs, NumX, NumY
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	
	String ImageNameR, ImageNameG, ImageNameB
	Variable i, maxval, img=0
	
	// First create references to the three images
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			img += 1
			
			if (img == 1)
				WAVE ImageR 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc")
				Make /O/D/N=(NumX,NumY) $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc_BE") /WAVE=ImageRBE
			elseif (img == 2)
				WAVE ImageG 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc")
				Make /O/D/N=(NumX,NumY) $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc_BE") /WAVE=ImageGBE
			elseif (img == 3)
				WAVE ImageB 	= $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc")
				Make /O/D/N=(NumX,NumY) $("root:SPHINX:Stacks:"+StackName + SVDType+num2str(i)+"_sc_BE") /WAVE=ImageBBE
			endif
		endif
	endfor
	
	// A temporary normalization wave - find the max value of the same pixel across the 3 waves. 
	Make /O/N=(NumX, NumY) $("root:SPHINX:Stacks:"+StackName + "_tmp") /WAVE=TmpImage
	MultiThread TmpImage[][] 	= max(max(ImageR[p][q],ImageG[p][q]),ImageB[p][q])
	
	WaveStats /Q/M=1 TmpImage
	Print " 		.... Brightness enhancement: Individually scale each pixel so that the max R, G, or B channel is set to 250."
	Print " 		.... Brightness enhancement: Largest and smallest scale values are",V_max,V_min
	Print " 		.... Brightness enhancement: You will lose contrast over some areas of the brightest channel!"
	
	// Now renormalize each pixel according to the normalization factor. 
	// Set maximum scale value to be 250, not 255
	MultiThread ImageRBE[][] 	= ImageR[p][q] * (MaxLevel/TmpImage[p][q])
	MultiThread ImageGBE[][] 	= ImageG[p][q] * (MaxLevel/TmpImage[p][q])
	MultiThread ImageBBE[][] 	= ImageB[p][q] * (MaxLevel/TmpImage[p][q])
	
	// Now set masked values to 0
	MultiThread ImageRBE[][] 	= (ImageMask[p][q] == 0) ? ImageRBE[p][q] : 0
	MultiThread ImageGBE[][] 	= (ImageMask[p][q] == 0) ? ImageGBE[p][q] : 0 
	MultiThread ImageBBE[][] 	= (ImageMask[p][q] == 0) ? ImageBBE[p][q] : 0
End


// *************************************************************
// ****		Handling the images that contain the chemical mapping
// *************************************************************
//
//		Note: This routine is called for EVERY PIXEL (or bin of pixels)
//Function FillSVDImages(RefSoln, RefScale, StackName,iChiSqr,pChiSqr,dE,X,Y,X2,Y2,Bin,PosFlag)
//	Wave RefSoln, RefScale
//	String StackName
//	Variable iChiSqr,pChiSqr,dE,X,Y,X2,Y2,Bin,PosFlag
//
//	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
//	
//	String ImageName
//	Variable i, j=0, Const,NRefs
//	
//	// Debugging check
//	// 	WRONG!! Because the full range includes polynomial coefficients that can be negative.  
////	if (PosFlag)
////		WaveStats /Q/M=1 RefSoln
////		if (V_min < 0)
////			RefSoln = NAN
////		endif
////	endif
//	
//	NRefs=DimSize(RefSelect,0)
//	
//	// debug 2013-05-20. Constraints not completely enforcing positive coefficients. E.g., -3.2535e-06
////	RefScale[] = RefSoln[p]
//	if (PosFlag)
//		RefScale[] = max(RefSoln[p],0)
//	else
//		RefScale[] = RefSoln[p]
//	endif
//	
//	
//	// Scale the factors to their sum for proportional mapping
//	Const = sum(RefScale)
//	RefScale /= Const
//	
//	for (i=0;i<NRefs;i+=1)
//		if (isChecked(RefSelect[i][0]))
//			// The simple component strength - INTENSITY maps
//			ImageName = StackName + "_iMap_"+num2str(i)
//			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+ImageName)
//			SVDImage[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = RefSoln[j]
//			
//			// The scaled component strength - PROPORTIONAL maps
//			ImageName = StackName + "_pMap_"+num2str(i)
//			WAVE SVDImage 	= $("root:SPHINX:Stacks:"+ImageName)
//			SVDImage[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = RefScale[j]
//			
//			j+=1
//		endif
//	endfor
//	
//	if (iChiSqr > 0)		// The simple chi-squared image
//		ImageName = StackName + "_iMap_x2"
//		WAVE iChi2 	= $("root:SPHINX:Stacks:"+ImageName)
//		iChi2[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = iChiSqr
//	endif
//	
//	if (pChiSqr > 0)		// The scaled chi-squared image
//		ImageName = StackName + "_pMap_x2"
//		WAVE pChi2 	= $("root:SPHINX:Stacks:"+ImageName)
//		pChi2[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = pChiSqr
//	endif
//	
//	if (abs(dE) > 0)		// The energy offset image
//		ImageName = StackName + "_Map_dE"
//		WAVE dEMap 	= $("root:SPHINX:Stacks:"+ImageName)
//		dEMap[X,min(X+Bin,X2)][Y,min(Y+Bin,Y2)] = dE
//	endif
//End
			
Function PrepareSVDImages(StackName,NumX,NumY)
	String StackName
	Variable NumX,NumY

	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection

	String ImageName, Description
	Variable i, NRefs=DimSize(RefList,0)
	
	// The simple component strength
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			ImageName 		= StackName + "_iMap_"+num2str(i)
			Description 	= "Intensity of "+RefDesc[i][1]
			MakeSVDImage(ImageName,NumX,NumY,Description)
		endif
	endfor
	
	// The simple chi-squared image
	ImageName 		= StackName + "_iMap_X2"
	Description 	= "Chi-Squared errors from Intensity Analysis"
	MakeSVDImage(ImageName,NumX,NumY,Description)
	
	// The scaled component strength
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			ImageName 		= StackName + "_pMap_"+num2str(i)
			Description 	= "Proportion of "+RefDesc[i][1]
			MakeSVDImage(ImageName,NumX,NumY,Description)
		endif
	endfor
	
	// The scaled chi-squared image
	ImageName 		= StackName + "_pMap_X2"
	Description 	= "Chi-Squared errors from Proportional Analysis"
	MakeSVDImage(ImageName,NumX,NumY,Description)
	
	// The energy offset that is optionally fit
	ImageName 		= StackName + "_Map_dE"
	Description 	= "Fitted Energy Offset"
	MakeSVDImage(ImageName,NumX,NumY,Description)
	
	// A mask showing accepted pixels. Like ROI, 0 = masked. 
	ImageName 		= StackName + "_Map_mask"
	Description 	= "Accepted pixels"
	MakeMask(ImageName,NumX,NumY)
	
	UpdateImageDisplayTitles()
End

// Make a real-valued 2D wave
Function MakeSVDImage(ImageName,NumX,NumY,Description)
	String ImageName, Description
	Variable NumX,NumY

	WAVE /D SVDImage 	= $("root:SPHINX:Stacks:"+ImageName)
	if (!WaveExists(SVDImage))
		Make /O/D/N=(NumX,NumY) $("root:SPHINX:Stacks:"+ImageName) /WAVE=SVDImage
		SVDImage = NAN
	else
		if ((DimSize(SVDImage,0) != NumX) || (DimSize(SVDImage,1) != NumY))
			Redimension /N=(NumX,NumY) SVDImage
			SVDImage = NAN
		endif
	endif
	
	Note /K SVDImage
	Note SVDImage, Description
End

// Make an integer 2D wave
Function MakeMask(MaskName,NumX,NumY)
	String MaskName
	Variable NumX,NumY

	WAVE /B/U Mask 	= $("root:SPHINX:Stacks:"+MaskName)
	if (!WaveExists(Mask))
		Make /O/B/U/N=(NumX,NumY) $("root:SPHINX:Stacks:"+MaskName) /WAVE=Mask
		Mask = 255 	// i.e., not masked
	else
		if ((DimSize(Mask,0) != NumX) || (DimSize(Mask,1) != NumY))
			Redimension /N=(NumX,NumY) Mask
			Mask = 0
		endif
	endif
End

Function ResetSVDImages(StackName)
	String StackName

	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection

	String ImageName
	Variable i, NRefs=DimSize(RefList,0)
	
	for (i=0;i<NRefs;i+=1)
		// Clear ALL images associated with this stack
		ClearImage(StackName + "_iMap_"+num2str(i))
		ClearImage(StackName + "_pMap_"+num2str(i))
	endfor
	
	ClearImage(StackName + "_iMap_X2")
	ClearImage(StackName + "_pMap_X2")
	ClearImage(StackName + "_Map_dE")
	ClearImage(StackName + "_Map_mask")
	
	UpdateImageDisplayTitles()
End

Function ClearImage(ImageName)
	String ImageName
	
	WAVE /D SVDImage 	= $("root:SPHINX:Stacks:"+ImageName)
	if (WaveExists(SVDImage))
		SVDImage = NAN
	endif
End

Function ClearMask(MaskName)
	String MaskName
	
	WAVE /B/U Mask 	= $("root:SPHINX:Stacks:"+MaskName)
	if (WaveExists(Mask))
		Mask = 255 // I.e., not masked
	endif
End

Function UpdateImageDisplayTitles()

	String ImageName, ImageFolder, Description
	String PanelName, PanelList =WinList("*",";","WIN:64")
	Variable i, NPanels = ItemsInList(PanelList)
	
	// Look for all panels with Image-related UserData. 
	for (i=0;i<NPanels;i+=1)
		PanelName 			= StringFromList(i,PanelList)
		ImageName 			= StringByKey("ImageName",GetUserData(PanelName, "", ""),"=",";")
		ImageFolder 		= StringByKey("ImageFolder",GetUserData(PanelName, "", ""),"=",";")
		
		if (strlen(ImageName) > 0)
			WAVE Image 	= $(ParseFilePath(2,ImageFolder,":",0,0)+ImageName)
			if (WaveExists(Image))
				Description 	= note(Image)
				if (strlen(Description) > 0)
					TitleBox ImageDescription win=$PanelName,frame=5,fSize=12,pos={138,10},title=Description
				endif
			endif
		endif
	endfor
End
