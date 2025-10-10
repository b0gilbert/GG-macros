#pragma rtGlobals=1		// Use modern global access method.

Function DTfromDAKName()

	WAVE /T CoeffList = wCoeffList
	WAVE CoeffAxis = wCoeffAxis

	String cName1, cName2
	Variable i, t1hr, t1min, t1sec, time1, t2hr, t2min, t2sec, time2, DT, NPts=DimSize(CoeffAxis,0)

	CoeffAxis[0] = 0
	
	for (i=1;i<NPts;i+=1)
		if (i==1)
		cName1 = CoeffList[i-1]
		t1hr = ReturnNthNumber(cName1,1)
		t1min = ReturnNthNumber(cName1,2)
		t1sec = ReturnNthNumber(cName1,3)
		time1 = (t1hr*60*60 + t1min*60 + t1sec)
		endif
		
		cName2 = CoeffList[i]
		t2hr = ReturnNthNumber(cName2,1)
		t2min = ReturnNthNumber(cName2,2)
		t2sec = ReturnNthNumber(cName2,3)
		time2 = (t2hr*60*60 + t2min*60 + t2sec)
		
		DT =  time2 - time1

		CoeffAxis[i] = DT/60
	endfor
End

// ***************************************************************************
// **************** 	MAKE GLOBAL VARIABLES AND DATA FOLDERS FOR COEFFICIENT LOADING
// ***************************************************************************
Function CheckCoeffPlotPanel()

//	DoWindow CoefficientPlotPanel
	DoWindow Coefficients
	if (V_flag == 0)
		InitPlotSpectra()
//		CreateCoeffPlotDataFolder()
		MakePlotDataFolders("Coefficients",1)
		CreatePlotCoefficientPanel()
//		DoWindow/C CoefficientPlotPanel
		DoWindow/C Coefficients
	else
		NVAR gFirstDisplayCoef		=root:COEFFICIENTS:GLOBALS:gFirstDisplayCoef
		ExtractCoefficientSeries(gFirstDisplayCoef)
	endif
End

Function InitLoadCoefficients()
	String OldDF = getDataFolder(1)
	
	// MAKE WAVES THAT LIST THE LOADED COEFFICIENTS
	NewDataFolder/O/S root:COEFFICIENTS
		// Load Coefficients as a Single Group only
		Make /D/O/N=0/T 	wCoeffList
		Make /D/O/N=0 		wCoeffSel
		
	// A SINGLE FOLDER FOR THE LOADED COEFFICIENTS
	NewDataFolder/O/S root:COEFFICIENTS:Load
		// Make sure we remove any previous coefficients
		KillWaves /A/Z
	
	// *** MAKE GLOBAL VARIABLES FOR ALL SPECTRA ROUTINES
	NewDataFolder/O/S root:COEFFICIENTS:GLOBALS
		Variable /G gNumCoeffsLoaded=0, gDisplayCoef=0//, gFirstDisplayCoef=0, gLastDisplayCoef=Inf, gCoefLegendFlag=0
		Variable /G gShowErrorBarsFlag, gCoeffTabChoice=0, gNumCoeffsValues
		String /G gLegendWaveName, gCoefficientLegend
	
	SetDataFolder $(OldDF)
End

Function CreateCoeffPlotDataFolder()
	
	String OldDF = getDataFolder(1)
	String PlotFolderName 	= "root:SPECTRA:Plotting:Coefficients"
	SetDataFolder root:SPECTRA:Plotting
	NewDataFolder /O/S $(PlotfolderName)
		
//		// LABELING THE AXES
//		String /G gManualXLabel, gManualYLabel, gManualY2Label, gCommonXUnits, gCommonYUnits, gCommonY2Units
//		Variable /G  gXLabelChoice = 4, gYLabelChoice = 1, gY2LabelChoice = 1
//		SetCommonXUnits(gXLabelChoice,PlotfolderName)
//		SetCommonYUnits(gYLabelChoice,0,PlotfolderName)
//		SetCommonYUnits(gY2LabelChoice,1,PlotfolderName)
//		Variable /G gXUnitChoice=0, gYUnitChoice=0, gY2UnitChoice=0, gErrorsFlag=0
		
	SetDataFolder $(OldDF)
End

// ***************************************************************************
// **************** 			Routine for loading a single Coefficients binary file. 
// ***************************************************************************
Function LoadSingleCoefficientsFile(FileName,DataName)
	String FileName, DataName
	
	WAVE/T wCoeffList		= root:COEFFICIENTS:wCoeffList
	WAVE wCoeffSelection		= root:COEFFICIENTS:wCoeffSel
	
	NVAR gNumCoeffsLoaded	= root:COEFFICIENTS:GLOBALS:gNumCoeffsLoaded
	NVAR gNumCoeffsValues	= root:COEFFICIENTS:GLOBALS:gNumCoeffsValues
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	Variable i, first=1, NHeaderLines, NLines, NCoefs
	String LoadWaveName, CoeffName, PathAndFileName = gPath2Data + FileName
	
	
	String OldDf 	= GetDataFolder(1)
	SetDataFolder root:COEFFICIENTS:Load
		
		Loadwave /Q/D/O/H PathAndFileName
		
		// bizarrely, this is giving the wrong name. 'fr_" not "fc_"
		LoadWaveName = StringfromList(0,S_Wavenames)
		WAVE /T CoeffImport 	= $LoadWaveName
		
		NHeaderLines 	= str2num(CoeffImport[0][1])
		NLines 		= DimSize(CoeffImport,0)
		NCoefs 			= NLines - NHeaderLines
		
		if (first)
			gNumCoeffsValues = NCoefs
			first = 0
		endif
		
//		CoeffName 		= ReplaceString("fc_",LoadWaveName,"")
		CoeffName 		= DataName
		Make /O/T/N=(NCoefs,3) $CoeffName /WAVE=Coeffs
		
		Coeffs[][0] 	= CoeffImport[p+NHeaderLines][0]
		Coeffs[][1] 	= CoeffImport[p+NHeaderLines][1]
		Coeffs[][2] 	= CoeffImport[p+NHeaderLines][2]
		
		gNumCoeffsLoaded += 1
		ReDimension /N=(gNumCoeffsLoaded) wCoeffList
			wCoeffList[gNumCoeffsLoaded-1] = CoeffName
		ReDimension /N=(gNumCoeffsLoaded) wCoeffSelection
			wCoeffSelection[gNumCoeffsLoaded-1] = 0
		
		KillWaves /Z $LoadWaveName
	SetDataFolder $(OldDF)
	
	return 1
End

Function LoadCoeffAxisAndErrors(ctrlname):ButtonControl
	String ctrlname
	
	WAVE wCoeffAxis			= 	root:COEFFICIENTS:wCoeffAxis
	WAVE wCoeffAxisErrors 	= 	root:COEFFICIENTS:wCoeffAxisErrors
	
	String AxisWaveName, LoadWaveList = InteractiveLoadTextFile("Please locate the axis file")
	Variable NLoads = ItemsInList(LoadWaveList)
	
	if (NLoads > 0)
		AxisWaveName = StringFromList(0,LoadWaveList)
		Wave AxisWave1 = $AxisWaveName
		
		if (cmpstr("LoadCoeffAxisButton",ctrlname) == 0)
			wCoeffAxis[] = AxisWave1[p]
			if (NLoads>1)
				AxisWaveName = StringFromList(1,LoadWaveList)
				Wave AxisWave2 = $AxisWaveName
				wCoeffAxisErrors[] = AxisWave2[p]
			endif
		endif
		if (cmpstr("LoadCoeffAxisErrorsButton",ctrlname) == 0)
			wCoeffAxisErrors[] = AxisWave1[p]
		endif
		KillWavesFromList(LoadWaveList,1)
	endif
End
	
// ***************************************************************************
// **************** 		THE INTERACTIVE PANEL FOR COEFFICIENT PLOTTING
// ***************************************************************************
Function CreatePlotCoefficientPanel()
	
	WAVE wCoeffList 			 	= root:COEFFICIENTS:wCoeffList
	WAVE wCoeffValues 			= root:COEFFICIENTS:wCoeffValues
	WAVE wCoeffErrors 			= root:COEFFICIENTS:wCoeffErrors
	WAVE wCoeffAxis	 	 		= root:COEFFICIENTS:wCoeffAxis
	WAVE wCoeffAxisErrors		= root:COEFFICIENTS:wCoeffAxisErrors
	//
	NVAR gDisplayCoef			= root:COEFFICIENTS:GLOBALS:gDisplayCoef
	NVAR gCoeffTabChoice			= root:COEFFICIENTS:GLOBALS:gCoeffTabChoice
	NVAR gNumCoeffsValues			= root:COEFFICIENTS:GLOBALS:gNumCoeffsValues
	NVAR gShowErrorBarsFlag 	= root:COEFFICIENTS:GLOBALS:gShowErrorBarsFlag
	SVAR gCoefficientLegend		= root:COEFFICIENTS:GLOBALS:gCoefficientLegend
	
	NewPanel /W=(205,44,637,615)/K=1  as "Coefficient Plotting Panel"
	DoWindow/C Coefficients
	ModifyPanel /W=Coefficients fixedsize=1

	// *************************************************************
	// ****			The Coefficient Plot is a SUBWINDOW
	// *************************************************************
	Display /W=(0.049,0.439,0.961,0.967)/FG=(FL,,FR,FB)/HOST=#  wCoeffValues vs wCoeffAxis
	RenameWindow #,CoeffPlot
//		gDisplayCoef = gFirstDisplayCoef
		gDisplayCoef = 0
		ExtractCoefficientSeries(gDisplayCoef)
		DisplayCoeffErrorBars("",gShowErrorBarsFlag)
		
		ModifyGraph mode=4,marker=8
		ModifyGraph mirror=2
		Label left gCoefficientLegend
	SetActiveSubwindow ## // Return focus to Host

	// *************************************************************
	// ****		TAB 0:	The Coefficient Fitting and Saving Routines
	// *************************************************************
	Button LoadCoeffAxisButton, pos={164,35}, size={120,20}, proc=LoadCoeffAxisAndErrors, title="Load Axis Values"
	Button LoadCoeffAxisErrorsButton, pos={294,35}, size={120,20}, proc=LoadCoeffAxisAndErrors, title="Load Axis Errors"
	
	Button SaveCoeffSeriesButton, pos={164,80}, size={120,20}, proc=SavePlottedCoefficient, title="Save Coefficients"
	Button KeepCoeffSeriesButton, pos={295,80}, size={120,20}, proc=SavePlottedCoefficient, title="Adopt Coefficients"

	// *************************************************************
	// ****		TAB 1:	The Table of Axis values is a SUBWINDOW
	// *************************************************************
	TabControl CoeffPanelTab,pos={8,7},size={422,208},tabLabel(0)="Manipulate and Save", tabLabel(1)="Manual Axis Entry"
	TabControl CoeffPanelTab, proc=CoefficientsPanelTabFn,value= gCoeffTabChoice
//	TabControl CoeffPanelTab,tabLabel(2)="Axis Labels", proc=CoefficientsPanelTabFn,value= gCoeffTabChoice
	
	// This table is only created within a Tab control. 
	Edit /W=(1000,1000,100,100)/HOST=# wCoeffList, wCoeffAxis, wCoeffAxisErrors
	RenameWindow #,CoeffTable
	SetActiveSubwindow ## // Return focus to Host
	
	// *************************************************************
	// ****		TAB 2:	The Axis Label controls
	// *************************************************************	
//	AppendPlotLabelControls("CoefficientPlotPanel",1,1)
//	AppendPlotLabelControls("Coefficients",1,1,0,1,-80,0)

	// *************************************************************
	// ****			The MAIN PANEL CONTROLS
	// *************************************************************	
	CheckBox CoeffErrorsCheckBox,pos={9,226},size={103,15},proc=DisplayCoeffErrorBars,title="Display errors"
	CheckBox CoeffErrorsCheckBox,fSize=14,value= gShowErrorBarsFlag
	
	SetVariable CoeffLegendSetVar,pos={153,222},size={255,25},title="Select coefficients to plot: "
	SetVariable CoeffLegendSetVar,fSize=18,frame=0, proc=SetPlotCoefficient
	SetVariable CoeffLegendSetVar,limits={0,gNumCoeffsValues,1},value= root:COEFFICIENTS:GLOBALS:gDisplayCoef
End

Function CoefficientsPanelTabFn(name,tab)
	String name
	Variable tab
	
	WAVE wCoeffList 			 = root:COEFFICIENTS:wCoeffList
	WAVE wCoeffAxis	 		 = root:COEFFICIENTS:wCoeffAxis
	WAVE wCoeffAxisErrors	 = root:COEFFICIENTS:wCoeffAxisErrors
	//
	NVAR gCoefLegendFlag	= root:COEFFICIENTS:GLOBALS:gCoefLegendFlag
	
	if (tab == 1)
		MoveSubWindow/W=Coefficients#CoeffTable fnum=(0.041,0.063,0.972,0.359)
	else
		MoveSubWindow/W=Coefficients#CoeffTable fnum=(100,100,100,100)
	endif
	
	// TAB 0: Use  disable= (tab!=0)
	Button LoadCoeffAxisButton, win=Coefficients, disable= (tab!=0)
	Button LoadCoeffAxisErrorsButton, win=Coefficients, disable= (tab!=0)
	Button SaveCoeffSeriesButton, win=Coefficients, disable= (tab!=0)
	
	// TAB 1: Use disable= (tab!=1)
	
	// TAB 2: Use disable= (tab!=2)
//	TabControlOfPlotLabelControls(tab,2,0,gCoefLegendFlag,0,"Coefficients")
//	TabControlOfPlotLabelControls(ChosenTab,HostTab,GreyXFlag,GreyYFlag,GreyY2Flag,Y2LabelFlag,WindowName)
	TabControlOfPlotLabelControls(tab,2,0,gCoefLegendFlag,0,0,"Coefficients#CoeffPlot")
End

Function DisplayCoeffErrorBars(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	NVAR gShowErrorBarsFlag 	=root:COEFFICIENTS:GLOBALS:gShowErrorBarsFlag
	gShowErrorBarsFlag = checked
	
	WAVE wCoeffValues 		= root:COEFFICIENTS:wCoeffValues
	WAVE wCoeffErrors 	 	= root:COEFFICIENTS:wCoeffErrors
	WAVE wCoeffAxisErrors	= root:COEFFICIENTS:wCoeffAxisErrors

	if (gShowErrorBarsFlag == 1)
		ErrorBars /W=Coefficients#CoeffPlot wCoeffValues XY, wave =(wCoeffAxisErrors,wCoeffAxisErrors),wave=(wCoeffErrors,wCoeffErrors)
	else
		ErrorBars /W=Coefficients#CoeffPlot wCoeffValues OFF
	endif
End

Function SavePlottedCoefficient(ctrlname):ButtonControl
	String ctrlname

	String CoefsFolder = "root:COEFFICIENTS"
	SVAR gCoefficientLegend	= $(CoefsFolder + ":GLOBALS:gCoefficientLegend")
	//
	WAVE /T wCoeffList 		= $(CoefsFolder + ":wCoeffList")
	WAVE wCoeffValues 		= $(CoefsFolder + ":wCoeffValues")
	WAVE wCoeffErrors 	 	= $(CoefsFolder + ":wCoeffErrors")
	WAVE wCoeffAxis	 	 	= $(CoefsFolder + ":wCoeffAxis")
	WAVE wCoeffAxisErrors	= $(CoefsFolder + ":wCoeffAxisErrors")
	
	String CoefsSaveName = wCoeffList[0] + "_" + gCoefficientLegend
	do 
		CoefsSaveName = PromptForUserStrInput(CoefsSaveName,"Filename for saving coefficient series","Maximum 22 chars!")
	while(strlen(CoefsSaveName) > 22)
	
	if (cmpstr("_quit!_",CoefsSaveName)==0)
		return -1
	endif
	
	String CoefsDataName		= CoefsSaveName+"_data"
	String CoefsSigName 		= CoefsSaveName+"_data_sig"
	String CoefsAxisName 	= CoefsSaveName+"_axis"
	String CoefsAxisSigName 	= CoefsSaveName+"_axis_sig"
	
	Duplicate /O/D wCoeffValues, $(CheckFolderColon(CoefsFolder) + CoefsDataName)
	Duplicate /O/D wCoeffErrors, $(CheckFolderColon(CoefsFolder) + CoefsSigName)
	Duplicate /O/D wCoeffAxis, $(CheckFolderColon(CoefsFolder) + CoefsAxisName)
	Duplicate /O/D wCoeffAxisErrors, $(CheckFolderColon(CoefsFolder) + CoefsAxisSigName)
	
	if (cmpstr(ctrlname,"KeepCoeffSeriesButton") == 0)
		AdoptAxisAndDataFromMemory(CoefsAxisName,CoefsAxisSigName,CoefsFolder,CoefsDataName,CoefsSigName,CoefsFolder,CoefsDataName,"",0,0,1)
	else
		Save /O/T/P=home $(CheckFolderColon(CoefsFolder)+CoefsAxisName),$(CheckFolderColon(CoefsFolder)+CoefsAxisSigName),$(CheckFolderColon(CoefsFolder)+CoefsDataName),$(CheckFolderColon(CoefsFolder)+CoefsSigName) as CoefsSaveName+".itx"
	endif
	
	KillWaves /Z $(CheckFolderColon(CoefsFolder)+CoefsAxisName),$(CheckFolderColon(CoefsFolder)+CoefsAxisSigName),$(CheckFolderColon(CoefsFolder)+CoefsDataName),$(CheckFolderColon(CoefsFolder)+CoefsSigName)
End

Function SetPlotCoefficient(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	NVAR gDisplayCoef	= root:COEFFICIENTS:GLOBALS:gDisplayCoef
	gDisplayCoef=varNum
	
	ExtractCoefficientSeries(gDisplayCoef)
End

Function ExtractCoefficientSeries(DisplayCoef)
	Variable DisplayCoef
	
	WAVE /T wCoeffList 		= root:COEFFICIENTS:wCoeffList
	WAVE	 wCoeffValues 		= root:COEFFICIENTS:wCoeffValues
	WAVE	 wCoeffErrors 	= root:COEFFICIENTS:wCoeffErrors
	//
	NVAR gNumCoeffsLoaded	= root:COEFFICIENTS:GLOBALS:gNumCoeffsLoaded
	SVAR gCoefficientLegend	= root:COEFFICIENTS:GLOBALS:gCoefficientLegend
	
	Variable i
	String CoeffValuesName, CoeffSigmasName
	
	for (i=0;i<gNumCoeffsLoaded;i+=1)
	
		WAVE /T Coeffs 		= root:COEFFICIENTS:Load:$wCoeffList[i]
		
		// The coefficient value
		wCoeffValues[i]	= str2num(Coeffs[DisplayCoef][1])
		// The coefficient error
		wCoeffErrors[i]	= str2num(Coeffs[DisplayCoef][2])
		// The coefficient legend
		gCoefficientLegend = Coeffs[DisplayCoef][0]
	endfor
	
	if (strlen(WinList("Coefficients",";","WIN:64")) != 0)
		Label /W=$"Coefficients#CoeffPlot" left gCoefficientLegend
	endif
End






















//Function LoadSingleCoefficientsFile(FileName,DataName)
//	String FileName, DataName
//	
//	WAVE/T wCoeffList		= root:COEFFICIENTS:wCoeffList
//	WAVE wCoeffSelection		= root:COEFFICIENTS:wCoeffSel
//	
//	SVAR gLegendWaveName	= root:COEFFICIENTS:GLOBALS:gLegendWaveName
//	NVAR gNumCoeffsLoaded	= root:COEFFICIENTS:GLOBALS:gNumCoeffsLoaded
//	NVAR gCoefLegendFlag		= root:COEFFICIENTS:GLOBALS:gCoefLegendFlag
//	
//	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
//	
//	String LoadWaveName, SigmasName, LegendName, suffix, PathAndFileName = gPath2Data + FileName
//	
//	
//	String OldDf 	= GetDataFolder(1)
//	SetDataFolder root:COEFFICIENTS:Load
//	
//		// Enforce simpler name for the loaded coefficient waves
//		DataName 	= UniqueName("Coeff",1,0)
//		
//		Loadwave /Q/D/O/H PathAndFileName
//		LoadWaveName = StringfromList(0,S_Wavenames)
//		
//		// Load the coefficient legend wave
//		if ((cmpstr("fL_",FileName[0,2]) == 0) || (strsearch(LoadWaveName,"Legend",0) > -1))
//			LegendName = "Coefficient_legend"
//			Duplicate /O $LoadWaveName, $LegendName
//			gLegendWaveName		= LegendName
//			gCoefLegendFlag 		= 1
//			FindFirstLastDisplayCoefs($LegendName)
//			return 1
//		
//		// Load a coefficient values wave
//		elseif (cmpstr("fC_",FileName[0,2]) == 0)
//			suffix = ReturnLastSuffix(ReplaceString(".ibw",FileName,""),"_")
//			if (cmpstr("Bs",suffix) == 0)
//				Print " *** The file",FileName,"contains atomic thermal factors, and has been skipped."
//				return 0
//			else
//				
//				Duplicate /O $LoadWaveName, $DataName
//				
//				gNumCoeffsLoaded += 1
//				ReDimension /N=(gNumCoeffsLoaded) wCoeffList
//					wCoeffList[gNumCoeffsLoaded-1] = DataName
//				ReDimension /N=(gNumCoeffsLoaded) wCoeffSelection
//					wCoeffSelection[gNumCoeffsLoaded-1] = 0
//					
//				return 1
//			endif
//			
//		// Load a coefficient errors wave. 
//		elseif (cmpstr("fS_",FileName[0,2]) == 0)
//			SigmasName = DataName + "_sig"
//			Duplicate /O $LoadWaveName, $SigmasName
//			
//			return 1
//		endif
//		
//		KillWaves /Z $LoadWaveName
//	SetDataFolder $(OldDF)
//	
//	Print " *** The file",FileName,"is not a coefficients file, and has been skipped."
//	return 0
//End


//Function FindFirstLastDisplayCoefs(wCoefLegend)
//	Wave /T wCoefLegend
//	
//	NVAR gDisplayCoef		=root:COEFFICIENTS:GLOBALS:gDisplayCoef
//	NVAR gFirstDisplayCoef	= root:COEFFICIENTS:GLOBALS:gFirstDisplayCoef
//	NVAR gLastDisplayCoef	= root:COEFFICIENTS:GLOBALS:gLastDisplayCoef
//	
//	Variable i=-1
//	do
//		i+=1
//	while(cmpstr("_header_",wCoefLegend[i]) == 0)
//	gFirstDisplayCoef = i
//	
//	i=numpnts(wCoefLegend)
//	do 
//		i-=1
//	while(strlen(wCoefLegend[i]) == 0)
//	gLastDisplayCoef = i
//	
//	if(strlen(WinList("Coefficients",";","WIN:64")) > 0)
//		gDisplayCoef = gFirstDisplayCoef
//		SetVariable CoeffLegendSetVar,win=Coefficients,limits={gFirstDisplayCoef,gLastDisplayCoef,1}
//		DoUpdate
//	endif
//End