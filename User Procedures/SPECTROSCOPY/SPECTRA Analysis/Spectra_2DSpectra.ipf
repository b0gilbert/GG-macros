#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method.

Menu "Spectra"
	SubMenu "2D Data"
		"Baseline subtract 2D"
		"Transfer 2D Y-axis"
		"Extract from 2D Data"
		"Dechirp 2D Data"
		"Vertical Bin 2D Data"
	End
End


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

// *************************************************************
// ****		TwoD Data Plotting Panel
// *************************************************************

Function Plot2DData(DataAndFolderName,DataNote)
	String DataAndFolderName,DataNote
	
	String DataType
	DataType 	= StringByKey("Data type",DataNote,"=","\r")
	
//	if (cmpstr(DataType,"EEM") == 0)
//		PlotEEMData(DataAndFolderName)
		
	if (cmpstr(DataType,"TA") == 0)
		PlotTAData(DataAndFolderName)
			
//	elseif (cmpstr(DataType,"IMAGE") == 0)
//		PlotImageAnalysisWindow(DataAndFolderName)
			
	else
		
		PlotTAData(DataAndFolderName)

	endif
End

Function PlotTAData(DataAndFolderName)
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
	
	XLabel2D 		= "Wavelength (nm)"
	YLabel2D 		= "Delay (ps)"
	ZLabel2D 		= "ΔOD"
	
	Plot2DImage($Data2DName, $AxisName, $Axis2Name, $Axis2DxName, $Axis2DyName, DataFolder,XLabel2D,YLabel2D,ZLabel2D)
End

// This is quite a general 2D spectrum plot routine, although made with transient absorption data in mind. 
Function Plot2DImage(DataMatrix, Axis, Axis2,Axis2Dx,Axis2Dy,DataFolder,XLabel2D, YLabel2D, ZLabel2D)
	Wave DataMatrix, Axis, Axis2,Axis2Dx,Axis2Dy
	String DataFolder, XLabel2D, YLabel2D, ZLabel2D
	
	String PanelName, PanelFolder, OldDf = GetDataFolder(1)
	String CheckTitle
	Variable NumX=numpnts(Axis), NumY=numpnts(Axis2)
	
	NewPanel /K=1/W=(11,44,740,790) as "2D Image Plot: " + NameofWave(DataMatrix)
	
	PanelName 	= WinName(0,65)
	PanelFolder = "root:SPECTRA:Plotting:" + PanelName
	
	// Hooks for the main panel, e.g., when killing plot. 
	SetWindow $PanelName, hook(Panel2DHooks)=TwoDPanelHooks
		
	NewDataFolder/O/S $(PanelFolder)
		
		String /G $NameOfWave(DataMatrix)=NameOfWave(DataMatrix)
		String /G gIntensityLabel = "mOD"
	
		// I need some global variables to control cursor positions and moves. 
		Variable /G gH1, gV1, gHWidth, gVWidth, gHStep, gVStep, gHNPts, gVNPts
		Variable /G gCsrAX, gCsrAY, gCsrBX, gCsrBY, gCsrCX, gCsrCY
		gCsrCX 	= trunc(NumX/2)
		gCsrCY 	= trunc(NumY/2)
	
		//  	-------- 	Display the stack image
		Display/W=(10,110,435,500)/HOST=# 
			AppendImage DataMatrix vs {Axis2Dx,Axis2Dy}
			ModifyGraph /W=# margin(left)=65,margin(bottom)=45,margin(top)=15,margin(right)=10,width=350
			ModifyImage /W=# $NameOfWave(DataMatrix) ctab= {0,0,Terrain,0}
			RenameWindow #, TwoDPlot
		SetActiveSubwindow ##
		
		// Hooks for the 2D plot subwindow - RECALL HOOKS ARE NOT SUB-WINDOW AWARE!!
		SetWindow $PanelName, hook(Plot2DHooks)=TwoDPlotHooks
		SetWindow $PanelName, hook(Plot2DMarquee)=Plot2DMarqueeMenu
		
		// Extracted Optical Spectra
		Make /O/D/N=(NumX) spectrum, fit, residuals, errors
		spectrum[] = DataMatrix[p][gCsrCX]
		fit = NaN; residuals = NaN; errors = NaN
		Display/W=(10,515,435,735)/HOST=# spectrum vs Axis
			ModifyGraph /W=# margin(left)=65,margin(bottom)=45,margin(right)=10
			ModifyGraph /W=# tick=2, mirror=1, lowTrip(left)=0.001
			ModifyGraph /W=# fSize=12, zero(left)=1
			// Append the ICA - LLS fit results
			AppendToGraph fit vs Axis
			AppendToGraph residuals vs Axis
			ModifyGraph rgb(residuals)=(34952,34952,34952),rgb(fit)=(0,0,65535)
			// Make a masking wave
			Make /O/D/N=(NumX) spectrumMask=nan
			AppendToGraph /L=MaskAxis spectrumMask vs Axis
			SetAxis MaskAxis, 0, 1
			ModifyGraph axThick(MaskAxis)=0, noLabel(MaskAxis)=2
			ModifyGraph mode(spectrumMask)=5, hbFill(spectrumMask)=2
			ModifyGraph rgb(spectrumMask)=(52428,52428,52428)
			ReorderTraces spectrum,{spectrumMask}
			// Name this subwindow
			RenameWindow #, SpecPlot
		SetActiveSubwindow ##
		
		// Extracted Kinetics Trace
		Make /O/D/N=(NumY) kinetics
		kinetics[] = DataMatrix[gCsrCX][p]
		Display/W=(450,110,710,500)/HOST=# kinetics vs Axis2
			ModifyGraph /W=# margin(bottom)=45,margin(right)=10
			ModifyGraph /W=# tick=2, mirror=1, lowTrip(left)=0.001
			ModifyGraph /W=# fSize=12, tkLblRot(bottom)=-90
			ModifyGraph /W=# swapXY=1, zero(bottom)=1
			RenameWindow #, KinPlot
		SetActiveSubwindow ##

		// The Independent Components Plot
		Make /O/D/N=(NumX) nullcomponent=NaN
		Display/W=(450,515,710,735)/HOST=# nullcomponent vs Axis
			ModifyGraph /W=# margin(left)=40,margin(bottom)=45,margin(right)=20
			ModifyGraph /W=# tick=2, mirror=1, lowTrip(left)=0.001, zero(left)=1
			RenameWindow #, ComponentsPlot
		SetActiveSubwindow ##

		// The Trends in the Coefficients
		Make /O/D/N=(NumY) nulltrend=NaN
		Display/W=(450,515,710,735)/HOST=# nulltrend vs Axis2
			ModifyGraph /W=# margin(left)=40,margin(bottom)=45,margin(right)=20
			ModifyGraph /W=# tick=2, mirror=1, lowTrip(left)=0.001, zero(left)=1
			RenameWindow #, TrendsPlot
		SetActiveSubwindow ##
				
		// Label all the axes
		Label /W=#TwoDPlot left YLabel2D
		Label /W=#TwoDPlot bottom XLabel2D
		Label /W=#SpecPlot left ZLabel2D
		Label /W=#SpecPlot bottom XLabel2D
		Label /W=#KinPlot left YLabel2D
		Label /W=#KinPlot bottom ZLabel2D
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#TwoDPlot;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(DataMatrix)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+DataFolder+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
			
		AppendContrastControls(NameOfWave(DataMatrix),DataFolder,PanelFolder,NumX,NumY)
		
		// This also appends a ColorScale
		ApplyStackContrast(PanelName)
	
		// Cursor for extracting data from the 2D plot
		
		Cursor/P/I/H=1/C=(52428,1,41942)/W=#TwoDPlot C $NameOfWave(DataMatrix) gCsrCX,gCsrCY
		Cursor/P/H=2/S=2/C=(52428,1,41942)/W=#SpecPlot C $NameOfWave(spectrum) gCsrCX
		Cursor/P/H=3/S=2/C=(52428,1,41942)/W=#KinPlot C $NameOfWave(kinetics) gCsrCY
		
		// Cursors for selecting a range of data for masking and component analysis. 
		Cursor/P/I/H=1/C=(52428,1,41942)/W=#TwoDPlot A $NameOfWave(DataMatrix) gCsrCX-10,gCsrCY-10
		Cursor/P/I/H=1/C=(3,52428,1)/W=#TwoDPlot B $NameOfWave(DataMatrix) gCsrCX+10,gCsrCY+10
		
		// Lock the A & B cursors so that they can't be moved by arrow keys
		Cursor /A=0/M/W=#TwoDPlot A
		Cursor /A=0/M/W=#TwoDPlot B
		
		Variable /G gRescaleFlag = 1
		CheckBox RescaleCheck,pos={80,88}, size={55,26},fSize=11,title="AutoScale", variable=gRescaleFlag//, proc=TwoDPlotCheckProcs
		CheckBox ColorLegendCheck,pos={160,88}, size={55,26},fSize=11,title="Color legend", value=1, proc=TwoDPlotCheckProcs
		
		CheckTitle = "log "+ StripValuesInBrackets(YLabel2D,"(",")")
		CheckBox LogYAxes,pos={10,88}, size={55,26},fSize=11,title=CheckTitle, proc=ModifyGraphCheckProcs
		CheckBox LogYAxes, userdata(subWinList)=PanelName+"#TwoDPlot;"+PanelName+"#KinPlot;"+PanelName+"#TrendsPlot;", userdata(AxesList)="left;left;bottom;", userdata(FuncCall)="LogAxes;LogAxes;LogAxes;"
		
		CheckTitle = "log "+ StripValuesInBrackets(ZLabel2D,"(",")")
		CheckBox LogZAxes,pos={656,88}, size={55,26},fSize=11,title=CheckTitle, proc=ModifyGraphCheckProcs
		CheckBox LogZAxes, userdata(subWinList)=PanelName+"#SpecPlot;"+PanelName+"#KinPlot;", userdata(AxesList)="left;bottom;", userdata(FuncCall)="LogAxes;LogAxes;"
		
		GroupBox ICAGroup1,pos={136,0},size={80,81},fColor=(39321,1,1),title="Masking"
		GroupBox ICAGroup2,pos={218,0},size={80,81},fColor=(39321,1,1),title="Extract"
		GroupBox ICAGroup3,pos={300,0},size={135,81},fColor=(39321,1,1),title="Component Analysis"
		GroupBox ICAGroup4,pos={438,0},size={139,81},fColor=(39321,1,1),title="Component Fitting"
		
		// -----------------		Other Buttons
		Button ShiftTimeZero,pos={318,85}, size={60,18},fSize=13,proc=TwoDPlotButtons,title="Shift To"
		Button Dechirp,pos={384,85}, size={60,18},fSize=13,proc=TwoDPlotButtons,title="Dechirp"
		Button ApplyDechirp,pos={450,85}, size={45,18},fSize=13,proc=TwoDPlotButtons,title="Apply"
//		Button DeleteLine,pos={276,85}, size={90,18},fSize=13,proc=TwoDPlotButtons,title="Delete Line"
		
		// -----------------		Controls for Masking
		Button Mask2D,pos={146,16}, size={60,18},fSize=13,proc=TwoDPlotButtons,title="Mask"
		Button UnMask2D,pos={146,36}, size={60,18},fSize=13,proc=TwoDPlotButtons,title="Unmask"
		
		Variable /G gImportMaskChoice = 1
		PopupMenu ImportMaskMenu,fSize=12,pos={148, 57},size={112,20},proc=TwoDPanelPopupProcs,title="mask"
		PopupMenu ImportMaskMenu,mode=0,value= ListOf2DImagePlots()
		
		// -----------------		Controls for Extracting Spectra and Trends
		Button Extract1Button,pos={223,16}, size={70,18},fSize=13,proc=TwoDPlotButtons,title="Spectrum"
		Button Extract2Button,pos={223,36}, size={70,18},fSize=13,proc=TwoDPlotButtons,title="Trend"
		
		Variable /G gICAExtractWidth 	= 1
		SetVariable ICAWidthSet,title="width",fSize=11,pos={223,58},limits={1,inf,2},size={70,18},value= $(PanelFolder+":gICAExtractWidth")
		
		// -----------------		Controls for Component Analysis
		String /G gFindMethod = "ICA"
		PopupMenu FindMethodMenu,fSize=12,pos={306,16},size={112,20},proc=MethodMenuProc,title=" "
		PopupMenu FindMethodMenu,mode=1,value= #"\"ICA;PCA;\""
		
		Variable /G gICA_NumCmpnts 	= 3
		SetVariable ICA_NCSetVar,title="#",fSize=11,pos={375,18},limits={1,inf,1 },size={52,16},value= $(PanelFolder+":gICA_NumCmpnts")
		
		Button FindButton,pos={309,55}, size={120,18},fSize=13,proc=TwoDPlotButtons,title="Find Components"
		
		// -----------------		Controls for Component Fitting
		Variable /G gFitCmptChoice = 1
		PopupMenu FitChoiceMenu,fSize=12,pos={437,14},size={112,20},proc=MethodMenuProc,title=" "
		PopupMenu FitChoiceMenu,mode=1,value= ListOfComponents(0)
		
		Variable /G gImportMask 	= 1
		CheckBox ImportMaskCheck,pos={445,37}, size={55,26},fSize=11,title="Import mask?", variable=gImportMask
		
		Button FitButton,pos={445,55}, size={120,18},fSize=13,proc=TwoDPlotButtons,title="Fit Components"
		
		// -----------------		Controls for Displaying results of Component Fitting
		CheckBox ICACheck1,pos={606,15},value=1,mode=1,title="components",proc=ICADisplay
		CheckBox ICACheck2,pos={606,35},value=0,mode=1,title="trends",proc=ICADisplay 
		
		Button SaveButton,pos={610,55}, size={60,18},fSize=13,proc=TwoDPlotButtons,title="Save"
		
		String InfoStr = "ShowInfo /W="+PanelName+" /CP=1"
		Execute/Q/Z InfoStr
		
	SetDataFolder $(OldDf)
End

// ***************************************************************************
// **************** 		Routines that work on many (selected) 2D data
// ***************************************************************************

Function ExtractFrom2DData()
	Analyze2DData("Extract")
End

Function Dechirp2DData()
	Analyze2DData("Dechirp")
End

Function VerticalBin2DData()

	Analyze2DData("VBin")
End

Function LampCorrectEEM()

	Analyze2DData("LampCorrection")
End

Function BaselineSubtract2D()

	Analyze2DData("Baseline")
End

// 	This is a generic loop through all the selected 2D data. 
Function Analyze2DData(TwoDChoice)
	String TwoDChoice
	
	Wave/T wDataList	= root:SPECTRA:wDataList
	Wave wDataSel		= root:SPECTRA:wDataSel
	Wave wDataGroup	= root:SPECTRA:wDataGroup
	
	Variable i
	String DataName, TwoDFolder,FolderStem = "root:SPECTRA:Data:Load"
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S root:SPECTRA:Serial
	
		// Prompt for user input
		if (cmpstr(TwoDChoice,"Extract") == 0)
			if (TwodExtractInputs() == 0)
				return 0
			endif
					
		elseif (cmpstr(TwoDChoice,"Dechirp") == 0)
			if (TwoDDeChirpInputs(wDataList,wDataGroup) == 0)
				return 0
			endif
		
		elseif (cmpstr(TwoDChoice,"VBin") == 0)
			if (TwoDVBinInputs() == 0)
				return 0
			endif
		
		elseif (cmpstr(TwoDChoice,"LampCorrection") == 0)
			if (TwoDLampCorrinInputs() == 0)
				return 0
			endif
		
		elseif (cmpstr(TwoDChoice,"Baseline") == 0)
			if (TwoDBaselineSubInputs() == 0)
				return 0
			endif
					
		endif
		
		// Loop through selected data ... 
		for (i=0;i<numpnts(wDataSel);i+=1)
			if (((wDataSel[i]&2^0) != 0) || ((wDataSel[i]&2^3) != 0))
				DataName 		= ReplaceString("_data",wDataList[i],"")
				TwoDFolder 	= FolderStem + num2str(wDataGroup[i]) + ":TwoD"
				
				// ... and process only the 2D data
				if (DataFolderExists(TwoDFolder))
					if (cmpstr(TwoDChoice,"Extract") == 0)
						ExtractFromTwoD(DataName+"_2D",TwoDFolder)
					
					elseif (cmpstr(TwoDChoice,"Dechirp") == 0)
						ChirpCorrectTwoD(DataName+"_2D",TwoDFolder)
					
					elseif (cmpstr(TwoDChoice,"VBin") == 0)
						VerticalBinTwoD(DataName+"_2D",TwoDFolder)
		
					elseif (cmpstr(TwoDChoice,"LampCorrection") == 0)
						LampCorrectionEEM(DataName+"_2D",TwoDFolder)
		
					elseif (cmpstr(TwoDChoice,"Baseline") == 0)
					
						BaselineSubtractTwoD(DataName+"_2D",TwoDFolder)
						
					endif
					
				endif
			endif
		endfor
		
		if (cmpstr(TwoDChoice,"LampCorrection") == 0)
			// UpdatePlottedEEMs()
		endif
	
	SetDataFolder $OldDf
End

// ---------------------------------------------------------------------------
// **************** 		Lamp Correction applied to EEM data
// ---------------------------------------------------------------------------

Function TwoDLampCorrinInputs()
	
	Variable refNum
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S root:SPECTRA:EEM
	
		String msg 	= "Please locate lamp correction file"
		Open /M=msg/R/T="????" refNum
		if (strlen(S_filename) == 0)
			Print " *** load aborted by user.  "
			return 0
		endif
		Close refNum
		
		LoadWave /Q/O/A/G/W S_filename
		
		if (ItemsInList(S_waveNames) < 2)
			Print " 		*** Could not load the file for some reason."
			return 0
		else
			Print " 		*** Applying excitation lamp intensity correction to selected EEM data. Correction values from file:",S_filename
		endif
		
		String /G gLampAxisName 		= "root:SPECTRA:EEM:"+StringFromList(0,S_waveNames)
		String /G gLampIntensityName 	= "root:SPECTRA:EEM:"+StringFromList(1,S_waveNames)
	
	SetDataFolder $OldDf
	
	return 1
End

Function LampCorrectionEEM(DataName,TwoDFolder)
	String DataName,TwoDFolder
	
	// The lamp correction data
	SVAR gLampAxisName 		= root:SPECTRA:EEM:gLampAxisName
	SVAR gLampIntensityName 	= root:SPECTRA:EEM:gLampIntensityName
	WAVE LampAxis 		= $gLampAxisName
	WAVE LampIntensity 	= $gLampIntensityName
	
	// The EEM data and axis
	WAVE DataMatrix 	= $(ParseFilePath(2,TwoDFolder,":",0,0) + DataName)	
	WAVE Axis2 		= $(ParseFilePath(2,TwoDFolder,":",0,0) + ReplaceString("_2D",DataName,"_axis2"))
	
	Variable i, NumY=DimSize(Axis2,0)
	
	// Apply the correction using duplicated waves just in case we need to interpolate. 
	Duplicate /FREE/D Axis2, LampAxis2, LampIntensity2
			
	if (!EqualWaves(LampAxis,Axis2,1,.01))
		Print " 		*** The lamp correction data does not have the same axis values as the EEM data ",DataName
		if ((Axis2[0] <= LampAxis[0]) && (Axis2[DimSize(Axis2,0)-1] <= LampAxis[DimSize(Axis2,0)-1]))
			Print " 			 ... The lamp correction data will be interpolated onto the EEM excitation axis"
			Interpolate2 /T=1/I=3/X=LampAxis2/Y=LampIntensity2 LampAxis, LampIntensity
		else
			Print " 			 ... The lamp correction data cannot be interpolated onto the EEM excitation axis because it does not cover a large enough range. Skipping this EEM file"
		endif
	else
		Print " 			 ... Applied lamp correction to",DataName
		LampAxis2 	= LampAxis
		LampIntensity2 = LampIntensity
	endif
	
	DataMatrix[][] /= LampIntensity2[q]
End

// ---------------------------------------------------------------------------
// **************** 		Vertically bin 2D (Eos) data
// ---------------------------------------------------------------------------

Function TwoDVBinInputs()
	Variable VBinPixels = NUMVarOrDefault("root:SPECTRA:Serial:g2DVBinPixels",1)
	
	Prompt VBinPixels, "Number of pixels to bin"
	DoPrompt "Vertically Bin 2D matrix", VBinPixels
	if (V_flag)
		return 0
	endif
	
	Variable /G g2DVBinPixels 	= VBinPixels
	
	return 1
End

Function VerticalBinTwoD(DataName,TwoDFolder)
	String DataName,TwoDFolder
	
	NVAR gBin			 = root:SPECTRA:Serial:g2DVBinPixels
	WAVE DataMatrix 	= $(ParseFilePath(2,TwoDFolder,":",0,0) + DataName)	
	WAVE Axis1 		= $(ParseFilePath(2,ReplaceString(":TwoD",TwoDFolder,""),":",0,0) + ReplaceString("_2D",DataName,"_axis"))
	WAVE Axis2 		= $(ParseFilePath(2,TwoDFolder,":",0,0) + ReplaceString("_2D",DataName,"_axis2"))
	
	Variable i, NumX=DimSize(DataMatrix,0), NumY=DimSize(DataMatrix,1)
	Variable j, jMin, jMax, jAvg, jj, NumBin = ceil(NumY/gBin)
	
	Make /FREE/N=(NumX) LineOut
	Make /O/D/N=(NumBin) BinAxis2
	Make /O/D/N=(NumX,NumBin) BinMatrix
	
	for (i=0;i<NumBin;i+=1)
		
		jj = 0
		jMin 		= i*gBin
		jMax 		= min(jMin+gBin,NumY)
		jAvg 		=  mean(Axis2,jMin,jMax)
		LineOut 	= 0
		
		for (j=jMin;j<jMax;j+=1)
			LineOut += DataMatrix[p][j]
			jj += 1
		endfor
		
		BinMatrix[][i]	= LineOut[p]/jj
		BinAxis2[i] 		= jAvg
		
	endfor
	
	String SampleName = ReplaceString("_2D",DataName,"")+"_bin"
	LoadSingle2DPlot(SampleName,"",BinMatrix,BinAxis2,Axis1)
	
	KillWaves /Z BinAxis2, BinMatrix
End

// ---------------------------------------------------------------------------
// **************** 		Baseline Subtraction (i.e., substract an averaged TA spectrum from before T0 from all the data
// ---------------------------------------------------------------------------

Function TwoDBaselineSubInputs()
	Variable BaseCenter = NUMVarOrDefault("root:SPECTRA:Serial:g2DBaseCenter",1)
	Variable BaseLines = NUMVarOrDefault("root:SPECTRA:Serial:g2DBaseLines",1)
	Variable BaseScale = NUMVarOrDefault("root:SPECTRA:Serial:g2DBaseScale",1)
	
	Prompt BaseCenter, "Baseline center (in pixels)"
	Prompt BaseLines, "Lines to average"
	Prompt BaseScale, "Scale factor"
	DoPrompt "Baseline substraction from 2D matrix", BaseCenter, BaseLines, BaseScale
	if (V_flag)
		return 0
	endif
	
	BaseLines = (trunc(BaseLines/2)) * 2 + 1
	
	Variable /G g2DBaseCenter 	= BaseCenter
	Variable /G g2DBaseLines 	= BaseLines
	Variable /G g2DBaseScale 	= BaseScale
	
	print g2DBaseCenter, g2DBaseLines, g2DBaseScale
	
	return 1
End

Function BaseLineSubtractTwoD(DataName,TwoDFolder)
	String DataName,TwoDFolder
	
	NVAR gCenter		= root:SPECTRA:Serial:g2DBaseCenter
	NVAR gLines		= root:SPECTRA:Serial:g2DBaseLines
	NVAR gScale			= root:SPECTRA:Serial:g2DBaseScale
	
	WAVE DataMatrix 	= $(ParseFilePath(2,TwoDFolder,":",0,0) + DataName)	
	WAVE Axis1 		= $(ParseFilePath(2,ReplaceString(":TwoD",TwoDFolder,""),":",0,0) + ReplaceString("_2D",DataName,"_axis"))
	WAVE Axis2 		= $(ParseFilePath(2,TwoDFolder,":",0,0) + ReplaceString("_2D",DataName,"_axis2"))
	
	Variable i, NumX=DimSize(DataMatrix,0), NumY=DimSize(DataMatrix,1)
	Variable j, jMin, jMax, jHW, jj=0
	
	Make /FREE/N=(NumX) LineOut=0
	Make /O/D/N=(NumX,NumY) NewMatrix
	
	// First calculate the baseline to subtract
	jHW 		= (gLines-1)/2
	jMin 		= max(0,gCenter-jHW)
	jMax 		= min(gCenter+jHW,NumY)
	
	for (j=jMin;j<=jMax;j+=1)
		LineOut += DataMatrix[p][j]
		jj += 1
	endfor
	LineOut /= jj
	
	// Now apply the subtraction
	for (i=0;i<NumY;i+=1)
		NewMatrix[][i] 	= DataMatrix[p][i] - gScale*LineOut[p]
	endfor
	
	String WaveNote = note(DataMatrix)
	WaveNote = WaveNote + "\rBaseline subtracted"
	Note NewMatrix, WaveNote
	
	String SampleName = ReplaceString("_2D",DataName,"")+"_B"+num2str(gScale)
	LoadSingle2DPlot(SampleName,WaveNote,NewMatrix,Axis2,Axis1)
	
	KillWaves /Z NewMatrix
End
	

// ---------------------------------------------------------------------------
// **************** 		Applying a previously-fitted dechirp correction to many 2D data
// ---------------------------------------------------------------------------

Function TwoDDeChirpInputs(wDataList,wDataGroup)
	Wave /T wDataList
	Wave wDataGroup
	
	String DataList 		= TextWaveToList(wDataList,numpnts(wDataList),"","")
	String ChirpRef 	= STRVarOrDefault("root:SPECTRA:Serial:g2DChirpRef",wDataList[0])
	
	Prompt ChirpRef, "2D data with chirp fit", popup, DataList
	DoPrompt "Apply chirp correction", ChirpRef
	if (V_flag)
		return 0
	endif
	
	String /G g2DChirpRef 		= ChirpRef
	
	FindValue /TEXT=ChirpRef /TXOP=7 wDataList
	
	String /G g2DChirpFolder 	= "root:SPECTRA:Data:Load" + num2str(wDataGroup[V_value])+":TwoD"
	
	if (!WaveExists($(g2DChirpFolder + ":chirpcoefs")))
		Print " 		*** No chirp correction has been fitted for",g2DChirpRef
		return 0
	else 
		return 1
	endif
End

Function ChirpCorrectTwoD(DataName,TwoDFolder)
	String DataName,TwoDFolder
	
	SVAR gChirpRef 	= root:SPECTRA:Serial:gChirpRef
	SVAR gChirpFolder	= root:SPECTRA:Serial:g2DChirpFolder
	
	WAVE DataMatrix 	= $(ParseFilePath(2,TwoDFolder,":",0,0) + DataName)
	WAVE Axis1 			= $(ParseFilePath(1,TwoDFolder,":",1,0) + ReplaceString("_2D",DataName,"_axis"))
	WAVE Axis2 		= $(ParseFilePath(2,TwoDFolder,":",0,0) + ReplaceString("_2D",DataName,"_axis2"))
	
	ApplyDechirp(DataMatrix,Axis1,Axis2,gChirpFolder,"")
End

// ---------------------------------------------------------------------------
// **************** 		Extracting line scans from many 2D data
// ---------------------------------------------------------------------------

Function TwodExtractInputs()

	String ExtractType = STRVarOrDefault("root:SPECTRA:Serial:g2DExtractType","horizontal")
	String ExtractValList = STRVarOrDefault("root:SPECTRA:Serial:g2DExtractList","")
	Variable ExtractWidth = NUMVarOrDefault("root:SPECTRA:Serial:g2DExtractWidth",1)
	
	Prompt ExtractType, "Extraction type", popup, "horizontal;vertical;"
	Prompt ExtractValList, "List of axis values"
	Prompt ExtractWidth, "Pixel width for averaging"
	DoPrompt "Extract data from 2D matrix", ExtractType, ExtractValList, ExtractWidth
	if (V_flag)
		return 0
	endif
	
	String /G g2DExtractType 		= ExtractType
	String /G g2DExtractList 		= ExtractValList
	Variable /G g2DExtractWidth 	= ExtractWidth
	
	return 1
End

Function ExtractFromTwoD(DataName,TwoDFolder)
	String DataName,TwoDFolder
	
	SVAR gExtractType 		= root:SPECTRA:Serial:g2DExtractType
	SVAR gExtractList 		= root:SPECTRA:Serial:g2DExtractList
	NVAR gExtractWidth 	= root:SPECTRA:Serial:g2DExtractWidth
	WAVE DataMatrix 		= $(ParseFilePath(2,TwoDFolder,":",0,0) + DataName)	
	
	String LineOutName, AdoptedName, AdoptNote
	Variable n, m, i, di, i1, i2, value, posn, LineOutNPts, ExtractNPts
	Variable NExtract = ItemsInList(gExtractList)
	
	if (cmpstr(gExtractType,"horizontal") == 0)
		// e.g., a transient absorption spectrum at a set delay time. 
		WAVE ExtractAxis 		= $(ParseFilePath(2,ReplaceString(":TwoD",TwoDFolder,""),":",0,0) + ReplaceString("_2D",DataName,"_axis"))
		WAVE ValueAxis 		= $(ParseFilePath(2,TwoDFolder,":",0,0) + ReplaceString("_2D",DataName,"_axis2"))
		
		LineOutNPts			= DimSize(DataMatrix,0)
		ExtractNPts 			= DimSize(DataMatrix,1)
	else
		// e.g., a kinetics trace at a set wavelength
		WAVE ExtractAxis 		= $(ParseFilePath(2,TwoDFolder,":",0,0) + ReplaceString("_2D",DataName,"_axis2"))
		WAVE ValueAxis 		= $(ParseFilePath(2,ReplaceString(":TwoD",TwoDFolder,""),":",0,0) + ReplaceString("_2D",DataName,"_axis"))
		
		LineOutNPts			= DimSize(DataMatrix,1) // Need to know the number of rows
		ExtractNPts 			= DimSize(DataMatrix,0)
	endif
	
	di = max(1,ceil((gExtractWidth-1)/2)+1)
	
	Make /D/O/N=(LineOutNPts) LineOut
	
	for (n=0;n<NExtract;n+=1)
		value 	= str2num(StringFromList(n,gExtractList))
		posn 	= BinarySearch(ValueAxis,value)

		i1 	= max(0,posn-di)
		i2 	= min(ExtractNPts,posn+di)
		
		m 		= 0
		LineOut = 0
		for (i=i1;i<=i2;i+=1)
			
			if (cmpstr(gExtractType,"horizontal") == 0)
				ImageStats /G={0,ExtractNPts,i,i} DataMatrix
				if (numtype(V_avg) == 0)
					LineOut[] 		+= DataMatrix[p][i]
					m += 1
				endif
			else
				ImageStats /G={i,i,0,ExtractNPts} DataMatrix
				if (numtype(V_avg) == 0)
					LineOut[] 		+= DataMatrix[i][p]
					m += 1
				endif
			endif
			
			LineOut /= m
		endfor
				
		// Save this line out and move on
		LineOutName 	= ReplaceString("_2D",NameOfWave(DataMatrix),"") + "_" + StringFromList(n,gExtractList)
		AdoptedName 	= AdoptAxisAndDataFromMemory(NameOfWave(ExtractAxis),"",GetWavesDataFolder(ExtractAxis,1),"LineOut","","root:SPECTRA:Serial",LineOutName,"",0,1,1)
	
		// Store some information in the wave note. 
		if (strlen(AdoptedName) > 0)
			AdoptNote 	= "A "+num2str(LineOutNPts)+" " +gExtractType+" Lineout from "+ReplaceString("_2D",NameOfWave(DataMatrix),"")
			Note $AdoptedName, AdoptNote
		endif
	
	endfor
End

// ---------------------------------------------------------------------------
// --------------------- 		Transfer a 2D y-axis to many 2D data
// ---------------------------------------------------------------------------
// 	This is actually obselete ... hopefully

Function Transfer2DYAxis()
	
	Wave/T wDataList	= root:SPECTRA:wDataList
	Wave wDataSel		= root:SPECTRA:wDataSel
	Wave wDataGroup	= root:SPECTRA:wDataGroup
	
	Variable i, SelectionIndex, NPts
	String DataName, FolderStem = "root:SPECTRA:Data:Load"
	String SelectionNameList = "", SelectionGroupList="", AxisRef, TwoDFolder
	
	// One of the selected 2D waves will be used for the source of the transferred axis. 
	for (i=0;i<numpnts(wDataSel);i+=1)
		if (((wDataSel[i]&2^0) != 0) || ((wDataSel[i]&2^3) != 0))
			DataName 		= ReplaceString("_data",wDataList[i],"")
			TwoDFolder 	= FolderStem + num2str(wDataGroup[i]) + ":TwoD"
			
			// Only make a list of 2D data
			if (DataFolderExists(TwoDFolder))
				SelectionNameList 	= SelectionNameList + DataName + ";"
				SelectionGroupList 	= SelectionGroupList + num2str(wDataGroup[i]) + ";"
			endif
		endif
	endfor
	
	if (ItemsInList(SelectionNameList) == 0)
		return 0 
	endif
	
	Prompt AxisRef, "Choose the reference axis", popup, SelectionNameList
	DoPrompt "2D Y-axis transfer", AxisRef
	if (V_Flag)
		return -1
	else
		SelectionIndex 	= WhichListItem(AxisRef,SelectionNameList)
	endif
			
	WAVE Axis2DyRef  		= $(FolderStem + StringFromList(SelectionIndex,SelectionGroupList) + ":TwoD:" + AxisRef+"_2Dy")
	NPts 	= DimSize(Axis2DyRef,0)
	
	// Now transfer the axis. 
	for (i=0;i<numpnts(wDataSel);i+=1)
		if (((wDataSel[i]&2^0) != 0) || ((wDataSel[i]&2^3) != 0))
			DataName 		= ReplaceString("_data",wDataList[i],"")
			WAVE Axis2Dy  	= $(FolderStem + num2str(wDataGroup[i]) + ":TwoD:" + DataName + "_2Dy")
			
			if (DimSize(Axis2Dy,0) == NPts)
				Print " 			.... changed 2Dy axis for",DataName
				Axis2Dy 	= Axis2DyRef
			endif
		endif
	endfor
End

// *************************************************************
// ****		Independent Component Analysis
// *************************************************************

Function ComponentAnalysis(DataMatrix,XMask,Axis,Axis2,X1,X2,Y1,Y2,NCmpts,panelName,method)
	Wave DataMatrix,XMask,Axis,Axis2
	Variable X1,X2,Y1,Y2,NCmpts
	String panelName, method
	
	String CmptNote, OldDf 		= GetDataFolder(1)
	String DataFolder 	= GetWavesDataFolder(DataMatrix,1)
	String ICAFolder 	= "root:SPECTRA:Fitting:"+method
	String PlotFolder 	= "root:SPECTRA:Plotting:" + panelName
	
	Variable i, j=0, k, n, ICAX=0, ICAY, nXPts=DimSize(DataMatrix,0), nYPts=DimSize(DataMatrix,1)

	ICAY 	= Y2-Y1									// Number of spectra between the cursors (vertically). 
	ICAX 	= CountUnMaskedPoints(XMask,X1,X2) 		// Number of selected, unmasked data points between the cursurs (horizontally). 
	if (ICAX == 0)
		Print " 		... No non-masked data points!"
		return 0
	endif
	
	NewDataFolder /O/S $ICAFolder
		
		// Temporary LOOK-UP wave to make it faster to move values between masked and unmasked spectrum arrays.
		Make /O/N=(ICAX) ICADataIndices
		MaskLookup(ICADataIndices,XMask,X1,X2)
		
		//  First create an array of the selected, non-masked subset of the data. 
		Make /O/D/N=(ICAX,ICAY) MaskedData
		CreateMaskedDataArray(DataMatrix,MaskedData,XMask,X1,X2,Y1)
		
		// Remove the mean value from each of the spectra ...
		MatrixOp /O ConditionedData = subtractMean(MaskedData,1)
		
		// ... and store the mean values. 
		Make /O/D/N=(ICAY) DataMeans
		for (i=0;i<ICAY;i+=1)
			MatrixOp /O/FREE DataColumn = col(MaskedData,i)
			DataMeans[i] 	= mean(DataColumn)
		endfor
		
		// Make sure there are no problems with the input data. 
		WaveStats /Q/M=1 ConditionedData
		if (V_numNaNs > 0)
			Print " *** 	Please alter selected area to avoid NaN's!"
			return 0
			Print " 		... replacing NANs with zeroes"
			ReplaceNANsWithValue(ConditionedData,0)
		endif
		
		// Make a wave to RECEIVE the results of the ICA analysis (masked)
		Make /O/D/N=(ICAX,NCmpts) MaskedCmpts	// The ICA results - the OUTPUT of the ICA routine
		
		// Find the Independent Components of the CONDITIONED, MASKED data
		if (cmpstr(method,"ICA") == 0)
			Print " 	--- 	INDEPENDENT COMPONENT ANALYSIS of",NameOfWave(DataMatrix),"with",NCmpts,"components."
			ICA2DData(ConditionedData,MaskedCmpts,NCmpts,$"")
		elseif (cmpstr(method,"PCA") == 0)
			Print " 	--- 	PRINCIPAL COMPONENT ANALYSIS of",NameOfWave(DataMatrix),"."
			PCA2DData(ConditionedData,MaskedCmpts,NCmpts)
		endif
		
		Print " 				... Horizontal selected data region:  Points",X1,"-",X2,".   Data values",Axis[X1],"-",Axis[X2]
		Print " 				... Vertical selected data region: Points",Y1,"-",Y2,".   Data values",Axis2[Y1],"-",Axis2[Y2]
		
		// Make a wave to STORE the results of the ICA analysis (unmasked)
		Make /O/D/N=(nXPts,NCmpts) $(ParseFilePath(2,DataFolder,":",0,0) + method+"Components") /WAVE=ICAComponents
		CreateUnmaskedDataArray(ICAComponents,MaskedCmpts,XMask,X1,X2,0)
		
		// Save the cursor positions in the ICAComponents wavenote
		CmptNote 	= "SampleName="+ReplaceString("_2D",NameOfWave(DataMatrix),"")+";"
		CmptNote 	= CmptNote + "NCmpts="+num2str(NCmpts)+";FitMethod="+method+";"
		CmptNote 	= CmptNote + "CsrAX="+num2str(X1)+";CsrAY="+num2str(Y2)+";CsrBX="+num2str(X2)+";CsrBY="+num2str(Y1)+";"
		Note ICAComponents, CmptNote
		
		DisplayFitResults(PanelName,MaskedCmpts,$"null",ICADataIndices,Axis,Axis2,0,X2,Y1,Y2,ICAX,nXPts,nYPts,0,0)
		
	SetDataFolder $OldDf
End

Function MethodMenuProc(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	String panelName 		= PU_Struct.win
	Variable eventCode 		= PU_Struct.eventCode
	String PlotFolder 		= "root:SPECTRA:Plotting:" + panelName
	
	
	if (cmpstr("none",PU_Struct.popStr) == 0)
		return 0
	elseif (eventCode != 2)
		return 0
	endif
	
	if (cmpstr("FindMethodMenu",PU_Struct.ctrlName) == 0)
		SVAR gMethod 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gFindMethod")
		gMethod 			= PU_Struct.popStr

	elseif (cmpstr("FitChoiceMenu",PU_Struct.ctrlName) == 0)
		NVAR gFitCmptChoice 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "gFitCmptChoice")
		gFitCmptChoice 			= PU_Struct.popNum
		
		if (ImportComponents(PanelName) != 1)
			// I'm not sure how to reverse a choice that won't work ... perhaps remove from the menu list? 
		endif
	endif
End


Function TwoDPanelPopupProcs(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	String panelName 		= PU_Struct.win
	Variable eventCode 		= PU_Struct.eventCode
	String PlotFolder 		= "root:SPECTRA:Plotting:" + panelName
	
	if (cmpstr("none",PU_Struct.popStr) == 0)
		return 0
	elseif (eventCode != 2)
		return 0
	endif
	
	// Look up the names of the displayed 2D data and axes
	String ImageName 	= StringByKey("ImageName",GetUserData(PanelName,"",""),"=",";")
	String ImageFolder 	= StringByKey("ImageFolder",GetUserData(PanelName,"",""),"=",";")
	WAVE DataMatrix 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	WAVE Axis 			= $(ParseFilePath(1,ImageFolder,":",1,0) + ReplaceString("_2D",ImageName,"_axis"))
	
	WAVE fit 					= $(ParseFilePath(2,PlotFolder,":",0,0) + "fit")
	WAVE spectrum 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum")
	WAVE mask 					= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrumMask")
	
	if (cmpstr("ImportMaskMenu",PU_Struct.ctrlName) == 0)
//		NVAR gImportMaskChoice 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "gImportMaskChoice")
//		gImportMaskChoice 			= PU_Struct.popNum

		String MaskFolder 		=  TwoDImageUserData(PU_Struct.popStr,"PanelFolder")
		WAVE spectrumMask 	= $(ParseFilePath(2,MaskFolder,":",0,0) + "spectrumMask")
	
		mask 	= spectrumMask
		
		Scale2DSpectrum(panelName,spectrum, fit, mask,Axis)
	endif
End
		
// Make a list of all 2D data that are displayed in an Image plot
Function /S Listof2DImagePlots()
	
	String ImageName, ImageList=""
	String WindowName, WindowList =WinList("*",";","WIN:67")
	Variable i,NumWins = ItemsInList(WindowList)
	
	if (NumWins>0)
		for (i=NumWins;i>0;i-=1)
			WindowName = StringFromList(i,WindowList)
			if (WinType(WindowName) == 7)
				ImageName 		= StringByKey("ImageName",GetUserData(WindowName,"",""),"=",";")
				if (strlen(ImageName) > 0)
					ImageList += ImageName +";"
				endif
			endif
		endfor
	endif
	
	return ImageList
End

// This assumes that there is a single image plot for the target image. Returns User Data
Function /S TwoDImageUserData(ImageSearch,InfoKey)
	String ImageSearch, InfoKey
	
	String ImageName, WindowName, WindowList =WinList("*",";","WIN:67")
	Variable i, NumWins = ItemsInList(WindowList)
	
	if (NumWins>0)
		for (i=0;i<NumWins;i+=1)
			WindowName = StringFromList(i,WindowList)
			if (WinType(WindowName) == 7)
				ImageName 		= StringByKey("ImageName",GetUserData(WindowName,"",""),"=",";")
				if (cmpstr(ImageSearch,ImageName) == 0)
					return StringByKey(InfoKey,GetUserData(WindowName,"",""),"=",";")
				endif
			endif
		endfor
	endif
	
	return ""
End

// Make a list of all 2D data for which Components have been created, and the full folder paths to them. 
Function /S ListOfComponents(FolderFlag)
	Variable FolderFlag
	
	WAVE /T wDataList		= root:SPECTRA:wDataList
	WAVE wDataGroup		= root:SPECTRA:wDataGroup
	
	Variable ii, jj, NumFolders, NComponents
	String TwoDDataList, LoadFolder, TwoDFolder, CmpntList="", FolderList="", SampleName, DataFolder 	= "root:Spectra:Data"
	
	// Look through all the Load folders
	NumFolders = CountObjects(DataFolder, 4) -1
	
	for (ii = 0; ii <= NumFolders; ii += 1)
		LoadFolder 	= GetIndexedObjName(DataFolder, 4, ii)
		TwoDFolder = ParseFilePath(2,DataFolder,":",0,0) + LoadFolder + ":TwoD"
		
		if (DataFolderExists(TwoDFolder))
			TwoDDataList 	= FolderWaveList(TwoDFolder,"*Components",";","",-1,0)
			NComponents 	= ItemsInList(TwoDDataList)
			
			if (NComponents > 0)
				SampleName 	= ReplaceString("_2D",StringFromList(0,FolderWaveList(TwoDFolder,"*_2D",";","",-1,0)),"")
				TwoDDataList 	= ReplaceString("Components",TwoDDataList,"")
				TwoDDataList 	= AddPrefixOrSuffixToListItems(TwoDDataList,SampleName + " - ","")
				CmpntList 		= CmpntList + TwoDDataList
				
				for (jj=0;jj<NComponents;jj+=1)
					FolderList 		= FolderList + TwoDFolder + ";"
				endfor
			endif
		endif
	endfor
	
	if (ItemsInList(FolderList) == 0)
		FolderList = "none;"
		CmpntList = "none;"
	endif
	
	if (FolderFlag)
		return FolderList
	else
		return CmpntList 
	endif
End
// *************************************************************
// ****		 Importing Components already found for other 2D data
// *************************************************************

// This does not transfer components from one data set to another 
Function ImportComponents(PanelName)
	String PanelName
		
	// Look up the names of the displayed 2D data and axes
	String ImageName 	= StringByKey("ImageName",GetUserData(PanelName,"",""),"=",";")
	String ImageFolder 	= StringByKey("ImageFolder",GetUserData(PanelName,"",""),"=",";")
	WAVE DataMatrix 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	WAVE Axis 			= $(ParseFilePath(1,ImageFolder,":",1,0) + ReplaceString("_2D",ImageName,"_axis"))
	WAVE Axis2 		= $(ParseFilePath(2,ImageFolder,":",0,0) + ReplaceString("_2D",ImageName,"_axis2"))
		
	Variable nXPts=DimSize(DataMatrix,0), nYPts=DimSize(DataMatrix,1)
		
	String TwoDPlot 		= panelName + "#TwoDPlot"
	String specPlot 			= panelName + "#SpecPlot"
	String PlotFolder 		= "root:SPECTRA:Plotting:" + panelName
	NVAR gNCmpts 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "gICA_NumCmpnts")
	NVAR gFitCmptChoice 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "gFitCmptChoice")
	NVAR gImportMask 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gImportMask")
	
	WAVE fit 				= $(ParseFilePath(2,PlotFolder,":",0,0) + "fit")
	WAVE mask 				= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrumMask")
	WAVE spectrum 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum")
	
	// Look for the array of components to be fitted to the 2D plot data. 
	String CmptList, CmptChoice, method, sample, CmptFolderList, CmptFolder, CmntNote
	CmptList 				= ListOfComponents(0)
	CmptChoice 				= StringFromList(gFitCmptChoice-1,CmptList)
	sample 					= StripSuffixBySeparator(ReplaceString(" ",CmptChoice,""),"-")
	method 					= ReturnLastSuffix(ReplaceString(" ",CmptChoice,""),"-")
	CmptFolderList 			= ListOfComponents(1)
	CmptFolder 				= StringFromList(gFitCmptChoice-1,ListOfComponents(1))
	WAVE Components 		= $(ParseFilePath(2,CmptFolder,":",0,0) + method+"Components")
	Wave CmptAxis 			= $(ParseFilePath(1,CmptFolder,":",1,0) + sample+"_axis")
	
	if (!EqualWaves(Axis,CmptAxis,1))
		DoAlert 1, "Non-identical axes. Interpolate THIS 2D data set? IRREVERSIBLE!"
		if (V_flag == 2)
			return 0
		endif
		Print " 		*** 	The horizontal axes for"+ImageName+"and"+sample+"are not identical. *** IRREVERSIBLY interpolating the 2D data on to the comonent axis. "
		Interpolate2DData(Axis,DataMatrix,CmptAxis,nXPts,nYPts)
	endif
	
	// As we are not fitting, display the entire range of the selected components. 
	Make /FREE/O/N=(nXPts) ICADataIndices=p
		
	DisplayFitResults(PanelName,Components,$"null",ICADataIndices,Axis,Axis2,0,nXPts-1,NaN,NaN,nXPts,nXPts,nYPts,0,0)
	
	if (gImportMask)
		// Mask whereever the components are NaN
		MaskFromComponents(mask,Components)
		Scale2DSpectrum(PanelName,spectrum, fit, mask,Axis)
		
		// Read the cursor positions from the note
		Variable CsrAX, CsrAY, CsrBX, CsrBY
		CmntNote 	= note(Components)
		CsrAX 	= NumberByKey("CsrAX",CmntNote,"=")
		CsrAY 	= NumberByKey("CsrAY",CmntNote,"=")
		CsrBX 	= NumberByKey("CsrBX",CmntNote,"=")
		CsrBY 	= NumberByKey("CsrBY",CmntNote,"=")
		
		// Transfer the cursur values, making sure A & B are not moved by arrow keys. 
		Cursor /A=0/P/I/H=1/W=$TwoDPlot A $NameOfWave(DataMatrix) CsrAX, CsrAY
		Cursor /A=0/P/I/H=1/W=$TwoDPlot B $NameOfWave(DataMatrix) CsrBX, CsrBY
	endif
	
	return 1
End

Function Interpolate2DData(Axis,DataMatrix,CmptAxis,nXPts,nYPts)
	Wave Axis,DataMatrix,CmptAxis
	Variable nXPts,nYPts
	
	Variable i, AxisMin, AxisMax, newXPts=DimSize(CmptAxis,0)
	
	Make /FREE/D/N=(nXPts) SpectrumOrig
	Make /FREE/D/N=(newXPts) SpectrumInterp
	Make /FREE/D/N=(newXPts,nYPts) DataInterp
	
	
	AxisMin 	= BinarySearch(Axis,CmptAxis[0])
	AxisMax 	= BinarySearch(Axis,CmptAxis[newXPts-1])
	
	for (i=0;i<nYPts;i+=1)
		SpectrumOrig 		=	 DataMatrix[p][i]
		Interpolate2 /T=1/I=3/X=CmptAxis/Y=SpectrumInterp Axis, SpectrumOrig
		if (AxisMin > -1)
			SpectrumInterp[0,AxisMin-1] = NaN
		endif
		if (AxisMax > -1)
			SpectrumInterp[AxisMax+1,] = NaN
		endif
		DataInterp[][i] 		=	 SpectrumInterp[p]
	endfor
	
	Redimension /N=(newXPts) Axis
	Axis 	= CmptAxis
	
	Redimension /N=(newXPts,nYPts) DataMatrix
	DataMatrix 	= DataInterp
	
	WAVE Axis2D 	= $(GetWavesDataFolder(DataMatrix,2)+"x")
	MakeAxisForImagePlot(Axis,Axis2D)
End

// This is not used. Just too annoying to incorporate an interpolation step into all the fitting. Instead, change the 2D data. 
Function InterpolateComponents(Axis,Components,CmptAxis,InterpCmpts,nXPts,NCmpts)
	Wave Axis,Components,CmptAxis,InterpCmpts
	Variable nXPts,NCmpts
	
	Make /FREE/D/N=(DimSize(CmptAxis,0)) SingleCmpt
	Make /FREE/D/N=(DimSize(Axis,0)) SingleInterp
	
	Variable i, j, X1
	
	for (i=0;i<NCmpts;i+=1)
		SingleCmpt 		=	 Components[p][i]
		Interpolate2 /T=1/I=3/X=Axis/Y=SingleInterp CmptAxis, SingleCmpt
		for (j=0;j<nXPts;j+=1)
			X1 	= BinarySearchInterp(CmptAxis,Axis[j])
			if (numtype(X1) == 2)
				SingleInterp[j] 	= NaN
			elseif (numtype(SingleCmpt[X1]) == 2)
				SingleInterp[j] 	= NaN
			endif
		endfor
		InterpCmpts[][i] 	= SingleInterp[p]
	endfor
End

// *************************************************************
// ****		 Component Fitting
// *************************************************************
Function ComponentFitting(DataMatrix,XMask,Axis,Axis2,X1,X2,Y1,Y2,NCmpts,ReportFlag,DisplayOnly,PanelName)
	Wave DataMatrix,XMask,Axis,Axis2
	Variable X1,X2,Y1,Y2,NCmpts,ReportFlag,DisplayOnly
	String PanelName
		
	String OldDf 			= GetDataFolder(1)
	String DataFolder 		= GetWavesDataFolder(DataMatrix,1)
	String FitFolder 		= "root:SPECTRA:Fitting:NLLS"
	String PlotFolder 		= "root:SPECTRA:Plotting:" + panelName
	
	String TwoDPlot 		= panelName + "#TwoDPlot"
	String specPlot 			= panelName + "#SpecPlot"
	
	NVAR gImportMask 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gImportMask")
	
	String CmptList, CmptChoice, CmptFolderList, CmptFolder, CmntNote, method, sample
	Variable PositivityFlag = 0, Normalization=0, FitChoice=1
	Variable i, j, ICAX, ICAY, nPts, Const, nXPts=DimSize(DataMatrix,0), nYPts=DimSize(DataMatrix,1)
	
	ICAY 	= Y2-Y1									// Number of spectra between the cursors (vertically). 
	ICAX 	= CountUnMaskedPoints(XMask,X1,X2) 		// Number of selected, unmasked data points between the cursurs (horizontally). 
	if (ICAX == 0)
		Print " 		... No non-masked data points!"
		return 0
	endif
		
	// Look for the array of components to be fitted to the 2D plot data. 
	// The components are selected from the popup menu, and need to be found dynamically. 
	NVAR gFitCmptChoice 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "gFitCmptChoice")
	CmptList 				= ListOfComponents(0)
	CmptChoice 				= StringFromList(gFitCmptChoice-1,CmptList)
	method 					= ReturnLastSuffix(ReplaceString(" ",CmptChoice,""),"-")
	sample 					= StripSuffixBySeparator(ReplaceString(" ",CmptChoice,""),"-")
	CmptFolderList 			= ListOfComponents(1)
	CmptFolder 				= StringFromList(gFitCmptChoice-1,ListOfComponents(1))
	WAVE Components 		= $(ParseFilePath(2,CmptFolder,":",0,0) + method+"Components")
	Wave CmptAxis 			= $(ParseFilePath(1,CmptFolder,":",1,0) + sample+"_axis")
	
	if (!WaveExists(Components))
		Print " 	*** The components for",CmptChoice," have not been generated! ."
		return 0
	elseif ((cmpstr(method,"ICA")) && (NCmpts != DimSize(Components,1)))
		Print " 	*** Wrong number of components! ."
		return 0
	elseif (nXPts != DimSize(Components,0))
		Print " 	*** The axis for the components does not match the current data ."
		return 0
	endif
	// ------------------------------------------
		
	if (DisplayOnly) // - CURRENTLY UNUSED
		// If we are not fitting, display the entire range of the selected components. 
		Make /O/N=(nXPts) ICADataIndices=p
		DisplayFitResults(PanelName,Components,$"null",ICADataIndices,Axis,Axis2,0,nXPts-1,Y1,Y2,nXPts,nXPts,nYPts,0,0)
		return 0
	endif
	
	// Mask the components according to the current cursor positions and mask. 
	Make /O/N=(ICAX) ICADataIndices=p
	MaskLookup(ICADataIndices,XMask,X1,X2)
	
	Print " 	*** Component fitting to",NameOfWave(DataMatrix),"with",NCmpts,"components ",CmptChoice
	if (ReportFlag)
		Print " 		... Horizontal selected data region:  Points",X1,"-",X2,".   Data values",Axis[X1],"-",Axis[X2]
		Print " 		... Vertical selected data region: Points",Y1,"-",Y2,".   Data values",Axis[Y1],"-",Axis[Y2]
	endif
		
	NewDataFolder /O/S $FitFolder
	
		//  First create an array of the selected, non-masked subset of the data. 
		Make /O/D/N=(ICAX,ICAY) MaskedData
		CreateMaskedDataArray(DataMatrix,MaskedData,XMask,X1,X2,Y1)
		
		// Remove the mean value from each of the spectra ...
		MatrixOp /O ConditionedData = subtractMean(MaskedData,1)
		
		// ... and store the mean values. 
		Make /O/D/N=(ICAY) DataMeans
		for (i=0;i<ICAY;i+=1)
			MatrixOp /O/FREE DataColumn = col(MaskedData,i)
			DataMeans[i] 	= mean(DataColumn)
		endfor
		
		// Make sure there are no problems with the input data. 
		WaveStats /Q/M=1 ConditionedData
		if (V_numNaNs > 0)
			Print " 		... replacing NANs with zeroes"
			ReplaceNANsWithValue(ConditionedData,0)
		endif
		
		// Make an array of truncated and/or masked reference spectra. 
		Make /O/D/N=(ICAX,NCmpts) MaskedCmpts
		CreateMaskedDataArray(Components,MaskedCmpts,XMask,X1,X2,0)
		
//		if (!EqualWaves(Axis,CmptAxis,1))
//			Make /FREE/D/N=(nXPts,NCmpts) InterpCmpts
//			InterpolateComponents(Axis,Components,CmptAxis,InterpCmpts,nXPts,NCmpts)
//			CreateMaskedDataArray(InterpCmpts,MaskedCmpts,XMask,X1,X2,0)
//		else
//			CreateMaskedDataArray(Components,MaskedCmpts,XMask,X1,X2,0)
//		endif
		
		WaveStats /Q/M=1 MaskedCmpts
		if (V_numNaNs != 0)
			Print " 	*** References have NaNs - they probably don't span the fitting range! ."
			return 0
		endif
		
		// Temporary matrix of all the LLS fit result for a single spectrum
		Make /O/D/N=(ICAX) LLSResult
		
		// Temporary matrix of the LLS coefficient for a single spectrum
		Make /O/D/N=(NCmpts) LLSCfs
		
		// A single (2D) wave for the LLS analyses
		if (FitChoice == 1)
			Print " 		... using the least-square matrix method."
			Make /O/D/N=(ICAX,1) LLSSingle
		else
			Print " 		... using the non-linear least-square fitting algorithm."
			Make /O/D/N=(ICAX) LLSSingle
		endif
		
		// ----------	These arrays have the same dimensions as the full 2D image plot. ----------------
		Duplicate /O/D DataMatrix, $(ParseFilePath(2,DataFolder,":",0,0) + "LLSFit") /WAVE=LLSFit
		Duplicate /O/D DataMatrix, $(ParseFilePath(2,DataFolder,":",0,0) + "LLSResiduals") /WAVE=LLSResiduals
		LLSFit 			= NaN
		LLSResiduals 	= NaN
		
		// ----------	This array stores the NCmpts LLS coefficients for each spectrum ----------------
		Make /O/D/N=(NCmpts,ICAY) $(ParseFilePath(2,DataFolder,":",0,0) + "LLSCoefficients") /WAVE=LLSCoefficients
			
		// Loop through each cursor-bracketed horizontal spectrum in the 2D plot. 
		for (i=0;i<ICAY;i+=1)
			LLSSingle[][0] 	= ConditionedData[p][i]
			
			// Fit the components to each spectrum
			if (FitChoice == 1)
				LLSFitRoutine(LLSSingle,MaskedCmpts,LLSCfs,LLSResult)
			else
				NLLSFitRoutine(LLSSingle,MaskedCmpts,LLSCfs,LLSResult)
			endif
			
			// Let's assume that if a coefficient is negative, then the component should by multiplied by minus 1. 
			if (PositivityFlag == 1)
				for (j=0;j<NCmpts;j+=1)
					if (LLSCfs[j] < 0)
						Print " *** Inverted coefficient number",j
						MaskedCmpts[][j] *= -1
						Components[][j] *=-1
						LLSCfs[j] *=-1
					endif
				endfor
			endif
			
			// Saved array of NORMALIZED coefficients
			LLSCoefficients[][i] 	= LLSCfs[p]
			if (Normalization)
				Const = sum(LLSCfs)
				LLSCoefficients[][i] 	= LLSCfs[p]/Const
			endif
			
			// Loop through each cursor-bracketed and non-masked data point horizontal spectrum
			for (j=0;j<ICAX;j+=1)
				// This indexing approach does work. It correctly reproduces the input spectrum when LLSSpectrum[j][0] is exchanged for LLSResult[j]
				LLSFit[  ICADataIndices[j]  ][i+Y1] 	= LLSResult[j]
			endfor
			
			// Add the previously-subtracted mean spectrum value back to the fit results. 
			LLSFit[][i+Y1] 	+= DataMeans[i]
		endfor
		
		LLSResiduals 	= DataMatrix - LLSFit
		
		DisplayFitResults(PanelName,MaskedCmpts,LLSCoefficients,ICADataIndices,Axis,Axis2,X1,X2,Y1,Y2,ICAX,nXPts,nYPts,1,0)
		
		WaveStats /Q LLSResiduals
		nPts 	= numpnts(LLSResiduals) - V_numNaNs
		Print " 		... The reduced chi-squared for selected, non-masked data is",(V_rms/nPts)
	
	SetDataFolder $OldDf
End

// *************************************************************
// ****		Display the Components or the trends in their fit coefficients
// *************************************************************
Function DisplayFitResults(PanelName,ICAComponents,LLSCoefficients,ICADataIndices,Axis,Axis2,X1,X2,Y1,Y2,ICAX,nXPts,nYPts,TrendFlag,SaveFlag)
	String PanelName
	Wave ICAComponents, LLSCoefficients, ICADataIndices, Axis,Axis2
	Variable X1,X2,Y1,Y2,ICAX,nXPts, nYPts,TrendFlag, SaveFlag

	String TracesList, SampleName, DataName, AxisName, AxisFolder
	String PlotFolder 	= "root:SPECTRA:Plotting:" + PanelName
	
	Variable n, j, NCmpts
	
	if (SaveFlag)		// Remove prior traces
		SampleName 	=  GetSampleName(ReplaceString("_axis",NameOfWave(Axis),""),"","",0,1,1)
		if (cmpstr("_quit!_",SampleName) == 0)
			return 0
		endif
	else
		if (TrendFlag)
			NCmpts=max(1,DimSize(LLSCoefficients,0))
			TracesList = RemoveFromList("nulltrend",AxisTraceListBG(panelName+"#TrendsPlot","left",""))
			RemoveWavesInListFromPlot(panelName+"#TrendsPlot", TracesList)
		else
			NCmpts=max (1,DimSize(ICAComponents,1))
			TracesList = RemoveFromList("nullcomponent",AxisTraceListBG(panelName+"#ComponentsPlot","left",""))
			RemoveWavesInListFromPlot(panelName+"#ComponentsPlot", TracesList)
		endif
	endif
	
	// Append the results to the plots
	for (n=0;n<NCmpts;n+=1)
		if (SaveFlag)
			if (TrendFlag)
				DataName 			= "ICA_Trend_"+num2str(n)
				AxisName 			= GetWavesDataFolder(Axis2,2)
				AxisFolder			= GetWavesDataFolder(Axis2,1)
			else
				DataName 			= "ICA_Component_"+num2str(n)
				AxisName 			= GetWavesDataFolder(Axis,2)
				AxisFolder			= GetWavesDataFolder(Axis,1)
			endif
			
			AdoptAxisAndDataFromMemory(AxisName,"",AxisFolder,DataName,"",PlotFolder,SampleName+"_trend"+num2str(n),"",0,0,1)
		else
			if (TrendFlag)
				Make /O/D/N=(nYPts) $(ParseFilePath(2,PlotFolder,":",0,0)+"ICA_Trend_"+num2str(n)) /WAVE=Trend
				Trend 			= NaN
				Trend[Y1,Y2] 	= LLSCoefficients[n][p-Y1]
				AppendToGraph /W=$(panelName+"#TrendsPlot") Trend vs Axis2
				GiveTraceRainbowColor(PanelName+"#TrendsPlot",n,"ICA_Trend_"+num2str(n),"",0,0)
			else
				Make /O/D/N=(nXPts) $(ParseFilePath(2,PlotFolder,":",0,0)+"ICA_Component_"+num2str(n)) /WAVE=Component
				Component 		= NaN
				for (j=0;j<ICAX;j+=1)
					Component[   ICADataIndices[j]   ] 	= ICAComponents[j+X1][n]
				endfor
				AppendToGraph /W=$(panelName+"#ComponentsPlot") Component vs Axis
				GiveTraceRainbowColor(PanelName+"#ComponentsPlot",n,"ICA_Component_"+num2str(n),"",0,0)
			endif
		endif
	endfor
	
	// Make sure the relevant plot is visible
	if (!SaveFlag)
			if (TrendFlag)
			UpdateICADisplay(2,panelName)
		else
			UpdateICADisplay(1,panelName)
		endif
	endif
End

Function SaveFitResults(PanelName,Axis,Axis2,TrendFlag,SaveFlag)
	String PanelName
	Wave Axis,Axis2
	Variable TrendFlag, SaveFlag

	String suffix, TracesList, OldSampleName, SampleName, DataName, AxisName, AxisFolder
	String PlotFolder 	= "root:SPECTRA:Plotting:" + PanelName
	
	Variable n, j, NCmpts
	
	OldSampleName 		= ReplaceString("_axis",NameOfWave(Axis),"")
	SampleName 		= ReplaceString("_r",GetSampleName(OldSampleName,"","",0,1,1),"")
	if (cmpstr("_quit!_",SampleName) == 0)
		return 0
	endif
	
	if (TrendFlag)
		NCmpts 	= ItemsInList(AxisTraceListBG(panelName+"#TrendsPlot","left",""))
	else
		NCmpts 	= ItemsInList(AxisTraceListBG(panelName+"#ComponentsPlot","left",""))
	endif
	
	// Append the results to the plots
	for (n=0;n<NCmpts-1;n+=1)
		if (TrendFlag)
			DataName 			= "ICA_Trend_"+num2str(n)
			AxisName 			= NameOfWave(Axis2)
			AxisFolder			= GetWavesDataFolder(Axis2,1)
			suffix = "_T"
		else
			DataName 			= "ICA_Component_"+num2str(n)
			AxisName 			= NameOfWave(Axis)
			AxisFolder			= GetWavesDataFolder(Axis,1)
			suffix = "_C"
		endif
		
		DataName 	= AdoptAxisAndDataFromMemory(AxisName,"",AxisFolder,DataName,"",PlotFolder,SampleName+suffix+num2str(n),"",0,0,1)
		
		Note $DataName, "Trend from Component Analysis of "+OldSampleName
	endfor
End

// *************************************************************
// ****		Routines to fit the components to individual spectra
// *************************************************************
Function NLLSFitRoutine(spectrum,components,coefficients,result)
	Wave spectrum,components,coefficients,result
	
	Variable NCmpts = DimSize(components,1)
	
	STRUCT NLLSFitStruct fs 
	WAVE fs.components 	= components
	WAVE fs.cmpntcfs 		= coefficients
	fs.numcmpts 			= NCmpts
	
	Make /O/D/FREE/N=(fs.numcmpts+1) fitCoefs
	fitCoefs[0,NCmpts-1] 	= enoise(0.1)
	fitCoefs[NCmpts] 		= 1
	
	Variable V_FitQuitReason, V_FitError, V_fitOptions=4
	
	FuncFit /Q/N NLLSFitFunction, fitCoefs, spectrum /STRC=fs
	
	If ((V_FitQuitReason == 0) && (V_FitError == 0))
		coefficients[] 		= fitCoefs[p]
	
		WAVE fs.coefw		= fitCoefs
		WAVE fs.yw			= result
		NLLSFitFunction(fs)
	else
		coefficients 	= NaN
		result = NaN
	endif
End

Function  NLLSFitFunction(fs) : FitFunc 
	Struct NLLSFitStruct &fs 
	
	fs.cmpntcfs[] 	= fs.coefw[p]
	
	MatrixOp /O fs.yw 	= (fs.components x fs.cmpntcfs)
	
	// Add a fitted offset. 
	fs.yw += fs.coefw[fs.numcmpts]
End

Structure NLLSFitStruct 
	Wave coefw 
	Wave yw 
	Wave xw						// don't use the x-axis
	STRUCT WMFitInfoStruct fi 		// Optional WMFitInfoStruct. 
	
	WAVE components				// The array of components
	WAVE cmpntcfs					// The array of coefficients for the components
	Variable numcmpts 				// The number of components
	
EndStructure

Function LLSFitRoutine(spectrum,components,coefficients,result)
	Wave spectrum,components,coefficients,result
			
	// Solve for x in A.x = B, where A are the components found from PCA, and B is the single data spectrum
	// Because the number of data points >> number of components, the system is overdetermined. 
	MatrixLLS /M=0 components, spectrum
	
	WAVE M_B 	= M_B
	coefficients 	= M_B[p]
	MatrixOp /O result =  components x coefficients
End

// *************************************************************
// ****		Masking and unmasking
// *************************************************************
Function MaskFromComponents(mask,Components)
	Wave mask, Components

	Variable i, NPts=numpnts(mask)
	
	mask = NaN
	
	for (i=0;i<NPts;i+=1)
		if (numtype(Components[i][0]) == 2)
			mask[i] = 1
		endif
	endfor
End
		
Function CreateMaskedDataArray(DataMatrix,MaskedData,Mask,X1,X2,Y1)
	Wave DataMatrix,MaskedData,Mask
	Variable X1,X2,Y1
	
	Variable i, j=0
	
	for (i=X1;i<X2;i+=1)
		if (numtype(Mask[i]) == 2)
			MaskedData[j][] = DataMatrix[i][Y1+q]
			j += 1
		endif
	endfor
End

Function CreateUnmaskedDataArray(DataMatrix,MaskedData,Mask,X1,X2,Y1)
	Wave DataMatrix,MaskedData,Mask
	Variable X1,X2,Y1
	
	Variable i, j=0
	
	DataMatrix = NaN
	
	for (i=X1;i<X2;i+=1)
		if (numtype(Mask[i]) == 2)
			DataMatrix[i][Y1,] = MaskedData[j][q]
			j += 1
		endif
	endfor
End

Function MaskLookup(DataIndices,Mask,X1,X2)
	Wave DataIndices,Mask
	Variable X1, X2
	
	Variable i, j
	
	j=0
	for (i=X1;i<X2;i+=1)
		if (numtype(Mask[i]) == 2)
			DataIndices[j] = i
			j += 1
		endif
	endfor
End

Function CountUnMaskedPoints(Mask,X1,X2)
	Wave Mask
	Variable X1, X2

	Variable i, NPts=0
		
	// Count the number of non-masked data points in each spectrum (horizontally) .
	for (i=X1;i<X2;i+=1)
		if (numtype(Mask[i]) == 2)
			NPts += 1
		endif
	endfor
	
	return NPts
End

// *************************************************************
// ****		2D Plot Controls
// *************************************************************
	
Function TwoDPlotButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String panelName 	= B_Struct.win
	Variable eventMod 	= B_Struct.eventMod
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	// The 2D plot data in the Data folder
	String ImageName 	= StringByKey("ImageName",GetUserData(panelName,"",""),"=",";")
	String ImageFolder 	= StringByKey("ImageFolder",GetUserData(panelName,"",""),"=",";")
	WAVE DataMatrix 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	WAVE Axis 			= $(ParseFilePath(1,ImageFolder,":",1,0) + ReplaceString("_2D",ImageName,"_axis"))
	WAVE Axis2 		= $(ParseFilePath(2,ImageFolder,":",0,0) + ReplaceString("_2D",ImageName,"_axis2"))
	
	// The waves in the Panel folder
	String PlotFolder 	= "root:SPECTRA:Plotting:" + panelName
	WAVE fit 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "fit")
	WAVE residuals 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "residuals")
	WAVE spectrum 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum")
	WAVE mask 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrumMask")
	
	NVAR gCsrCX 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCX")
	NVAR gCsrCY 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCY")
	NVAR gNCmpts 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gICA_NumCmpnts")
	NVAR gWidth 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gICAExtractWidth")
	SVAR gFindMethod 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "gFindMethod")
	SVAR gFitMethod 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "gFitMethod")
	
	// The cursor point positions
	String TwoDPlot 	= panelName + "#TwoDPlot"
	String specPlot 		= panelName + "#SpecPlot"
	Variable ACsrX 		= min(pcsr(A, TwoDPlot),pcsr(B, TwoDPlot))
	Variable BCsrX 		= max(pcsr(A, TwoDPlot),pcsr(B, TwoDPlot))
	Variable ACsrY 		= min(qcsr(A, TwoDPlot),qcsr(B, TwoDPlot))
	Variable BCsrY 		= max(qcsr(A, TwoDPlot),qcsr(B, TwoDPlot))
	
	String SpectrumPos
	Variable i, NExtract=1, ShiftDown=0
	
	if ((eventMod & 2^1) != 0)	// Bit 1 = shift key down
		ShiftDown = 1
//		if (ManuallySetCsrC(DataMatrix,Axis,Axis2,PlotFolder,panelName) == 0)
//			return 0
//		endif
	endif
	
	if (cmpstr("Mask2D",ctrlName) == 0)
		Print " 				... Masked the data between points",ACsrX,"-",BCsrX,".   Data values",Axis[ACsrX],"-",Axis[BCsrX]
		mask[ACsrX,BCsrX][] 	= 1
		Scale2DSpectrum(PanelName,spectrum, fit, mask,Axis)
		
	elseif (cmpstr("Unmask2D",ctrlName) == 0)
		Print " 				... Unmasked the data between points",ACsrX,"-",BCsrX,".   Data values",Axis[ACsrX],"-",Axis[BCsrX]
		mask[ACsrX,BCsrX][] 	= nan
		Scale2DSpectrum(PanelName,spectrum, fit, mask,Axis)
		
	elseif (cmpstr("DeleteLine",ctrlName) == 0)
		Process2DDataSpectra(DataMatrix,Axis,Axis2,PlotFolder,panelName)
		
	elseif (cmpstr("ShiftTimeZero",ctrlName) == 0)
		ShiftTimeZero(DataMatrix,Axis,Axis2,PlotFolder,panelName)
		
//	elseif (cmpstr("LoadChirpCoeffs",ctrlName) == 0)
//		LoadChirpCoeffs(DataMatrix,Axis,Axis2,PlotFolder,panelName)
		
	elseif (cmpstr("Dechirp",ctrlName) == 0)
		CalculateDechirp(DataMatrix,Axis,Axis2,PlotFolder,panelName,ShiftDown)
		
	elseif (cmpstr("ApplyDechirp",ctrlName) == 0)
//		LoadChirpCoeffs(DataMatrix,Axis,Axis2,PlotFolder,panelName)
		ApplyDechirp(DataMatrix,Axis,Axis2,PlotFolder,panelName)
		
	elseif (cmpstr("FindButton",ctrlName) == 0)
		ComponentAnalysis(DataMatrix,mask,Axis,Axis2,ACsrX,BCsrX,ACsrY,BCsrY,gNCmpts,panelName,gFindMethod)
		
	elseif (cmpstr("FitButton",ctrlName) == 0)
		ComponentFitting(DataMatrix,mask,Axis,Axis2,ACsrX,BCsrX,ACsrY,BCsrY,gNCmpts,1,0,panelName)
		
	elseif (cmpstr("SaveButton",ctrlName) == 0)
		GetWindow $(panelName+"#ComponentsPlot") hide
		SaveFitResults(PanelName,Axis,Axis2,V_value,1)
	
	elseif (cmpstr("Extract1Button",ctrlName) == 0)
		AdoptExtractedSpectrum(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName,gCsrCX,gCsrCY,gWidth,1,ShiftDown)
			
//		if (ShiftDown)
//			ExtractSpectraScans(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName)
//		else
//			AdoptExtractedSpectrum(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName,gCsrCX,gCsrCY,gWidth,1)
//		endif
		
	elseif (cmpstr("Extract2Button",ctrlName) == 0)
		AdoptExtractedKinetics(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName,gCsrCX,gCsrCY,gWidth,1,ShiftDown)
	
//		if (ShiftDown)
//			ExtractKineticsScans(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName)
//		else
//			AdoptExtractedKinetics(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName,gCsrCX,gCsrCY,gWidth,1)
//		endif
	endif
End

// *************************************************************
// ****		Extracting horizontal and vertical linescans
// *************************************************************
Function ExtractSpectraScans(DataMatrix,Axis1,Axis2,PlotFolder,ImageFolder,panelName)
	Wave DataMatrix, Axis1, Axis2
	String PlotFolder, ImageFolder,panelName

	NVAR gHStep 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gHStep")
	NVAR gHNPts 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gHNPts")
	NVAR gHWidth 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gHWidth")
	NVAR gCsrCX 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCX")
	NVAR gCsrCY 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCY")
	NVAR gmODFlag 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gmODFlag")
	
	Variable i, CsrY, H1=gCsrCY, HStep=gHStep, HNpts=gHNPts, HWidth=gHWidth, mODFlag=gmODFlag

	Prompt H1, "First vertical point"
	Prompt HStep, "Step size in points"
	Prompt HNpts, "Number of points"
	Prompt HWidth, "Points to average"
	Prompt mODFlag, "Extract in mOD?", popup, "yes;no;"
	DoPrompt "Extract horizontal spectra from 2D plot", H1, HStep, HNPts, HWidth, mODFlag
	if (V_flag)
		return 0
	endif
	gHStep 		= HStep
	gHNPts 		= HNPts
	gHWidth 	= HWidth
	gmODFlag 	= mODFlag
	mODFlag 	= (gmODFlag == 1) ? 1 : 0
	
	for (i=0;i<gHNPts;i+=1)
		CsrY 	= H1 + i*gHStep
	
		Cursor/I/P/W=$(panelName+"#TwoDPlot") C $NameOfWave(DataMatrix) gCsrCX, CsrY

		ExtractFrom2DPlot(DataMatrix,PlotFolder,panelName+"#SpecPlot",gCsrCX,CsrY,gHWidth,0)
		
		AdoptExtractedSpectrum(DataMatrix,Axis1,Axis2,PlotFolder,ImageFolder,panelName,gCsrCX,CsrY,gHWidth,0,mODFlag)
	endfor
End

Function ExtractKineticsScans(DataMatrix,Axis1,Axis2,PlotFolder,ImageFolder,panelName)
	Wave DataMatrix, Axis1, Axis2
	String PlotFolder, ImageFolder, panelName

	NVAR gVStep 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gVStep")
	NVAR gVNPts 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gVNPts")
	NVAR gVWidth 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gVWidth")
	NVAR gCsrCX 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCX")
	NVAR gCsrCY 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCY")
	NVAR gmODFlag 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gmODFlag")
	
	Variable i, CsrX, V1=gCsrCX, VStep=gVStep, VNpts=gVNPts, VWidth=gVWidth, mODFlag=gmODFlag
	
	String SpectrumName, AdoptedName, AdoptNote, VertPos
	String TwoDPlot 	= panelName + "#TwoDPlot"
	String specPlot 		= panelName + "#SpecPlot"
	
	Prompt V1, "First horizontal point"
	Prompt VStep, "Step size in points"
	Prompt VNpts, "Number of points"
	Prompt VWidth, "Points to average"
	DoPrompt "Extract vertical kinetics from 2D plot", V1, VStep, VNPts, VWidth
	if (V_flag)
		return 0
	endif
	gVStep 		= VStep
	gVNPts 		= VNPts
	gVWidth	= VWidth
	gmODFlag 	= mODFlag
	mODFlag 	= (gmODFlag == 1) ? 1 : 0
	
	for (i=0;i<gVNPts;i+=1)
		CsrX 	= V1 + i*VStep
	
		Cursor/I/P/W=$(panelName+"#TwoDPlot") C $NameOfWave(DataMatrix) CsrX, gCsrCY

		ExtractFrom2DPlot(DataMatrix,PlotFolder,panelName+"#SpecPlot",CsrX,gCsrCY,gVWidth,0)
		
		AdoptExtractedKinetics(DataMatrix,Axis1,Axis2,PlotFolder,ImageFolder,panelName,CsrX,gCsrCY,gVWidth,mODFlag,mODFlag)
	endfor
End

Function AdoptExtractedSpectrum(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName,CsrCX,CsrCY,Width,UserFlag,mODFlag)
	Wave DataMatrix, Axis, Axis2
	String PlotFolder, ImageFolder, panelName
	Variable CsrCX,CsrCY,Width,UserFlag, mODFlag

	String SpectrumName, AdoptedName, AdoptNote, HorzPos
	String TwoDPlot 	= panelName + "#TwoDPlot"
	String specPlot 		= panelName + "#SpecPlot"
	
	sprintf HorzPos, "%2.2f", Axis2[qcsr(C, TwoDPlot)]
	SpectrumName 	= ReplaceString("_2D",NameOfWave(DataMatrix),"") + "_" + HorzPos
	
	Duplicate /O/D  $(ParseFilePath(2,PlotFolder,":",0,0) + "fit"), $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum_fit")
	Duplicate /O/D  $(ParseFilePath(2,PlotFolder,":",0,0) +"spectrum"), $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum_adopt")
	WAVE spectrumAdopt = 	$(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum_adopt")
	if (mODFlag)
		spectrumAdopt *= 1000
	endif
	
	AdoptedName 	= AdoptAxisAndDataFromMemory(NameOfWave(Axis),"",ParseFilePath(1,ImageFolder,":",1,0),"spectrum_adopt","",PlotFolder,SpectrumName,"",UserFlag,1,1)

	// Store some information in the wave note. 
	if (strlen(AdoptedName) > 0)
		AdoptNote 	= "Lineout from "+ReplaceString("_2D",NameOfWave(DataMatrix),"")+", "
		AdoptNote 	= AdoptNote + num2str(Width) + " pixel avg at " +num2str(Axis[CsrCX])+ " (" + num2str(Axis2[max(0,CsrCY-((Width-1)/2))]) + " - " + num2str(Axis2[min(numpnts(Axis2)-1,CsrCY+((Width-1)/2))]) + ")."
		Note $AdoptedName, AdoptNote
		KillWaves $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum_adopt")
		KillWaves $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum_fit")
	endif
End

Function AdoptExtractedKinetics(DataMatrix,Axis,Axis2,PlotFolder,ImageFolder,panelName,CsrCX,CsrCY,Width,UserFlag,mODFlag)
	Wave DataMatrix, Axis, Axis2
	String PlotFolder, ImageFolder, panelName
	Variable CsrCX,CsrCY,Width,UserFlag, mODFlag

	String SpectrumName, AdoptedName, AdoptNote, VertPos
	String TwoDPlot 	= panelName + "#TwoDPlot"
	String specPlot 		= panelName + "#SpecPlot"

//	sprintf VertPos, "%f2.2", Axis2[qcsr(C, TwoDPlot)]
//	SpectrumName 	= ReplaceString("_2D",NameOfWave(DataMatrix),"") + "_" + VertPos
	SpectrumName 	= ReplaceString("_2D",NameOfWave(DataMatrix),"") + "_" + num2str(Axis[pcsr(C, TwoDPlot)])
	
	Duplicate /O/D  $(ParseFilePath(2,PlotFolder,":",0,0) +"kinetics"), $(ParseFilePath(2,PlotFolder,":",0,0) + "kinetics_adopt")
	WAVE kinetics_adopt = 	$(ParseFilePath(2,PlotFolder,":",0,0) + "kinetics_adopt")
	if (mODFlag)
		kinetics_adopt *= 1000
	endif
	
	AdoptedName 	= AdoptAxisAndDataFromMemory(NameOfWave(Axis2),"",ParseFilePath(2,ImageFolder,":",0,0),"kinetics_adopt","",PlotFolder,SpectrumName,"",UserFlag,0,1)

	// Store some information in the wave note. 
	if (strlen(AdoptedName) > 0)
		AdoptNote 	= "Lineout from "+ReplaceString("_2D",NameOfWave(DataMatrix),"")+", "
		AdoptNote 	= AdoptNote + num2str(Width) + " pixel avg at " +num2str(Axis[CsrCX])+ " (" + num2str(Axis[max(0,CsrCX-((Width-1)/2))]) + " - " + num2str(Axis[min(numpnts(Axis)-1,CsrCX+((Width-1)/2))]) + ")."
		Note $AdoptedName, AdoptNote
		KillWaves $(ParseFilePath(2,PlotFolder,":",0,0) + "kinetics_adopt")
	endif
End

Function ManuallySetCsrC(DataMatrix,Axis1,Axis2,PlotFolder,panelName)
	Wave DataMatrix, Axis1, Axis2
	String PlotFolder, panelName

	NVAR gCsrCX 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCX")
	NVAR gCsrCY 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCY")
	NVAR gWidth 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gICAExtractWidth")
	
	Variable NewX 	= Axis1[gCsrCX]
	Variable NewY 	= Axis2[gCsrCY]
	Prompt NewX, "New horizontal position"
	Prompt NewY, "New vertical position"
	DoPrompt "Move cursor C", NewX, NewY
	if (V_flag)
		return 0
	endif
	
	gCsrCX 	= AxisValueToPoint(Axis1, NewX)
	gCsrCY 	= AxisValueToPoint(Axis2, NewY)
	Cursor/I/P/W=$(panelName+"#TwoDPlot") C $NameOfWave(DataMatrix) gCsrCX, gCsrCY
	
	ExtractFrom2DPlot(DataMatrix,PlotFolder,panelName+"#SpecPlot",gCsrCX,gCsrCY,gWidth,1)
End

// *************************************************************
// ****		A rigid time-zero offset
// *************************************************************
Function ShiftTimeZero(DataMatrix,Axis1,Axis2,PlotFolder,panelName)
	Wave DataMatrix, Axis1, Axis2
	String PlotFolder, panelName

	Variable i, CurrentT0
	Prompt CurrentT0, "Current time zero "
	DoPrompt "Reset time zero to 1 ps? (IRREVERSIBLE)", CurrentT0
	if (V_flag)
		return 0
	endif
	
	Variable NXPts = DimSize(Axis1,0), NYPts = DimSize(Axis2,0)
	
	Make /D/N=(NYPts)/FREE shiftAxis, oldKinetics, newKinetics
	
	// Shift the axis so that current To is at 1 ps
	shiftAxis 	= Axis2 + (CurrentT0 - 1)
	
	for (i=0;i<=NXPts;i+=1)
		oldKinetics 		= DataMatrix[i][p]
		// Replace any NaNs with zeros
		oldKinetics[] 	= (numtype(oldKinetics[p]) == 0) ? oldKinetics[p] : 0
		Interpolate2 /T=1/I=3/X=shiftAxis/Y=newKinetics Axis2, oldKinetics
		DataMatrix[i][] = newKinetics[q]
	endfor
End

// *************************************************************
// ****		Try to determing the chirp
// *************************************************************

// 	Seems to work OK to look at the max or min intensity in a derivative plot. 
// 	Note on extrapolation beyond the selected region :
// 		1. Lower wavelength. Extrapolate using the polynomial 
// 		2. Higher wavelength. Do not extrapolate. Use the last offset value
Function CalculateDechirp(DataMatrix,Axis1,Axis2,PlotFolder,panelName,ShiftDown)
	Wave DataMatrix, Axis1, Axis2
	String PlotFolder, panelName
	Variable ShiftDown

	Variable CsrAX, CsrAY, CsrBX, CsrBY
	Variable V_FitQuitReason, V_FitError=0, V_fitOptions=4
	Variable i, chirp, center, XPts, XStart, XStop, YPts, YStart, YStop, NCfs=4
	Variable NXPts = DimSize(Axis1,0), NYPts = DimSize(Axis2,0)
	
	WAVE mask 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrumMask")
	
	String TwoDFolder 	= GetWavesDataFolder(DataMatrix,1)+":TwoD"
	MakeWaveIfNeeded(TwoDFolder+":chirpcoefs",NCfs)
	WAVE chirpcoefs2D 	= $(TwoDFolder+":chirpcoefs")
	
	String subWinName 	= panelName+"#TwoDPlot"
	CsrAX 		= pcsr(A, subWinName); CsrAY 		= qcsr(A, subWinName)
	CsrBX 		= pcsr(B, subWinName); CsrBY 	= qcsr(B, subWinName)
	
	XPts 	= abs(CsrBX-CsrAX)+1
	YPts 	= abs(CsrBY-CsrAY)+1
	XStart 	= min(CsrAX,CsrBX)
	XStop 	= max(CsrAX,CsrBX)
	YStart 	= min(CsrAY,CsrBY)
	YStop 	= max(CsrAY,CsrBY)
	
	String msg = " 		*** Calculating the chirp for "+NameOfWave(DataMatrix)
	if (ShiftDown)
		msg += " ... fitting to the minimum of the negative peak in the dI/dt curve."
	else
		msg += " ... fitting to the maximum of the positive peak in the dI/dt curve."
	endif
	
	String OldDf = GetDataFolder(1)
	SetDataFolder $PlotFolder
		
		Make /D/N=(XPts)/O edgeaxis, edge=0, edgemask=1, edgefit
		Make /D/N=(NCfs)/O chirpcoefs=0
		
		Make /D/N=(YPts)/FREE lineout, lineaxis
		
		lineaxis[] 	= Axis2[YStart+p]
		edgeaxis[] 	= Axis1[XStart+p]
		
		// First make a list of the inflection points for all time series
		for (i=XStart;i<=XStop;i+=1)
			if (numtype(mask[i]) == 2)
				lineout[] 	= DataMatrix[i][YStart+p]
				Differentiate lineout /X=lineaxis
				WaveStats /Q lineout
				if (ShiftDown)
					// Selected the NEGATIVE peak, if shift was held
					center 		= lineaxis[V_minloc]
				else	
					center 		= lineaxis[V_maxloc]
				endif
				edge[i-XStart] 	= center
			else
				edgemask[i-XStart] = 0
			endif
		endfor
		
		print msg
		
		chirpcoefs = {2,-0.01,XStop,0}
		
		FuncFit /Q/H="0110" ChirpFunction, chirpcoefs, edge /M=edgemask /X=edgeaxis 
		FuncFit /Q/H="0010" ChirpFunction, chirpcoefs, edge /M=edgemask /X=edgeaxis 
		FuncFit /Q/H="0000" ChirpFunction, chirpcoefs, edge /M=edgemask /X=edgeaxis 
		
		chirpcoefs2D 	= chirpcoefs
		
		// This is to display the results of the fit on the selected area
		edgefit = ChirpFunction(chirpcoefs,edgeaxis[p])
		
		// This is to display the full chirp correction
		Duplicate /O/O Axis1, ChirpAxis, ChirpValue
		ChirpValue[] 		= ChirpFunction(chirpcoefs,ChirpAxis[p])
		DisplayChirpFit(edgeaxis,edge,edgefit,ChirpAxis, ChirpValue,TwoDFolder,NameOfWave(DataMatrix))
		
		CheckDisplayed /W=$subWinName ChirpValue
		if (V_flag == 0)
			AppendToGraph /W=$subWinName ChirpValue vs ChirpAxis
		endif
		
	SetDataFolder $OldDf
End

Function ChirpFunction(w, x) : FitFunc
	Wave w
	Variable x
	
	Variable i, chirp, nCfs=numpnts(w)
	
	chirp = w[0] / (1 + exp(w[1] * (2*x - w[2]))) + w[3]
	
	return chirp
End

Function DisplayChirpFit(edgeaxis,edge,edgefit,ChirpAxis, ChirpValue,TwoDFolder,DataName)
	Wave edgeaxis,edge,edgefit,ChirpAxis, ChirpValue
	String TwoDFolder,DataName
	
	String ChirpPanel = DataName+"_chirp"
	
	DoWindow $ChirpPanel
	if (V_flag)
		DoWindow /F $ChirpPanel
		return 0
	endif
	
	Display /K=1/W=(443,44,801,332) edge,edgefit vs edgeaxis as ChirpPanel
	AppendToGraph ChirpValue vs ChirpAxis
	ModifyGraph rgb(ChirpValue)=(1,4,52428)
	Label left "Delay"
	Label bottom "Wavelength"
	DoWindow /C $ChirpPanel
End

Function ApplyDechirp(DataMatrix,Axis1,Axis2,ChirpFolder,panelName)
	Wave DataMatrix,Axis1,Axis2
	String ChirpFolder, panelName
	
	WAVE chirpcoefs 	= $(ChirpFolder+":chirpcoefs")
	
	Duplicate /D/FREE Axis1, ChirpAxis, ChirpValue
	ChirpValue[] = ChirpFunction(chirpcoefs,ChirpAxis[p])
	
	Variable i, Chirp
	Variable NXPts = DimSize(Axis1,0), NYPts = DimSize(Axis2,0)
	
	Make /D/N=(NYPts)/FREE DechAxis2, kinetics1, kinetics2
	
	// Now time shift all the points. 
	for (i=0;i<=NXPts;i+=1)
		
		Chirp 		= ChirpValue[i]
		DechAxis2 	= Axis2[p] + chirp - 1
		kinetics1 	= DataMatrix[i][p]
		
		WaveStats /Q/M=1 kinetics1
		
		if (V_numNaNs + V_numINFs <2)
			Interpolate2 /T=1/I=3/X=DechAxis2/Y=kinetics2 Axis2, kinetics1
			DataMatrix[i][] 	= kinetics2[q]
		endif
	endfor
		
	// This is only relevant if the routine has been called by a button on an active plot window
	if (strlen(panelName)>0)
		String subWinName = panelName+"#TwoDPlot"
		RemoveFromGraph /Z/W=$subWinName ChirpValue
	endif
End

// *************************************************************
// ****		2D Plot Hooks
// *************************************************************
Function TwoDPanelHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	Variable keyCode 		= H_Struct.keyCode
	Variable eventCode		= H_Struct.eventCode
	Variable Modifier 		= H_Struct.eventMod
	Variable CmdBit 		= 3
	
	String PlotName 	= WinName(0,65)
	String PlotFolder 	= "root:SPECTRA:Plotting:" + PlotName
	
	Variable height
	
	// Minimize the window
	if (eventCode == 11) 	// Key pressed
		GetWindow $PlotName wsize
		height 	= V_bottom - V_top
			
		if (((keyCode == 72) || (keyCode == 104)) && (height > 200))
			CheckWindowPosition(PlotName,V_left,V_top,V_right,V_top+100)
			HideInfo
		endif
		
		if ((((keyCode == 83) || (keyCode == 115)) && ((Modifier & 2^CmdBit) == 0)) && (height < 773))
			CheckWindowPosition(PlotName,V_left,V_top,V_right,V_top+773)
			ShowInfo
		endif
	endif
	
	// Killing the window cleanly. Could also remember cursor positions. 
	if (eventCode == 2)
		KillAllWavesInFolder(PlotFolder,"*")
		KillDataFolder /Z $ PlotFolder
		return 1
	endif
	
	return 0
End
	
Function TwoDPlotHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	Variable keyCode 		= H_Struct.keyCode
	Variable eventCode		= H_Struct.eventCode
	Variable Modifier 		= H_Struct.eventMod
	Variable CmdBit 		= 3
	
	String subWinName 	= H_Struct.winName
	String cursorName 		= H_Struct.cursorName
	
	// *!*! The only way to determine which subWindow is active
	GetWindow $"" activeSW
	String panelName 		= ParseFilePath(0, S_value, "#", 0, 0)
	String plotName 		= ParseFilePath(0, S_value, "#", 1, 0)
	
	// This doesn't seem to be exiting the function if plotName is null
	if (strlen(plotName) == 0)
		return 0
	endif
	
	// Exit the routine if we are not on any of the relevant subwindows. 
	if ((cmpstr(plotName,"TwoDPlot") != 0) && (cmpstr(plotName,"SpecPlot") != 0) && (cmpstr(plotName,"KinPlot") != 0))
		return 0
	endif
	
	// The 2D plot data in the Data folder
	String ImageName 	= StringByKey("ImageName",GetUserData(panelName,"",""),"=",";")
	String ImageFolder 	= StringByKey("ImageFolder",GetUserData(panelName,"",""),"=",";")
	WAVE DataMatrix 	= $(ParseFilePath(2,ImageFolder,":",0,0) + ImageName)
	
	WAVE Axis 			= $(ParseFilePath(1,ImageFolder,":",1,0) + ReplaceString("_2D",ImageName,"_axis"))
	WAVE Axis2 		= $(ParseFilePath(2,ImageFolder,":",0,0) + ReplaceString("_2D",ImageName,"_axis2"))
	Wave AxisX 			= $(ParseFilePath(2,ImageFolder,":",0,0) + ReplaceString("_2D",ImageName,"_2Dx"))
	Wave AxisY 			= $(ParseFilePath(2,ImageFolder,":",0,0) + ReplaceString("_2D",ImageName,"_2Dy"))
	
	String PlotFolder 	= "root:SPECTRA:Plotting:" + panelName
	WAVE fit 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "fit")
	WAVE mask 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrumMask")
	WAVE spectrum 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum")
	
	String LineOutName, AdoptedName, AdoptNote, VertPos1, VertPos2
	Variable i, iMax, yy=0, CsrAX, CsrBX, CsrAY, CsrBY, CsrCY, X1, X2, Y1, Y2, XPts, YPts, AvPx
	
	// This set of routines is only applicable to a MARQUEE created in the 2D Plot
	if ((H_Struct.eventcode == 3) && (cmpstr(plotName,"TwoDPlot") == 0))	// mousedown
		
		// Determine the marquee position relative to the left and bottom axis waves
		GetMarquee left, bottom
		
		if ((V_Flag ) && (GetKeyState(0) & 4))
		
			// I.e., we only get here if (i) click occurs inside marque and (ii) SHIFT is held down. 
			Variable xpix= H_Struct.mouseLoc.h
			Variable ypix= H_Struct.mouseLoc.v
			
			String checked= "\\M0:!" + num2char(18)+":"
			String divider="\\M1-;"
			
			PopupContextualMenu/C=(xpix, ypix) "expand;subtract x-y average;subtract y average;extract y-average;average kinetics;"
			
			sprintf VertPos1, "%1.3f", V_bottom
			sprintf VertPos2, "%1.3f", V_top
			
			if (cmpstr(S_selection,"expand") == 0)
				SetAxis  /W=$(panelName+"#TwoDPlot") left, V_bottom, V_top
				SetAxis  /W=$(panelName+"#TwoDPlot") bottom, V_left, V_right
				
				SetAxis  /W=$(panelName+"#SpecPlot") bottom, V_left, V_right
				SetAxis  /W=$(panelName+"#SpecPlot") /A left
				
				SetAxis  /W=$(panelName+"#KinPlot") left, V_bottom, V_top
				SetAxis  /W=$(panelName+"#KinPlot") /A bottom
				return 1
			endif
			
			if (StrSearch(S_selection,"average",0) > -1)
				X1 		= BinarySearch(Axis,max(V_left,0))
				X2 		= BinarySearch(Axis,min(V_right,DimSize(DataMatrix,0)))
				Y1 		= BinarySearch(Axis2,max(V_bottom,0))
				Y2 		= BinarySearch(Axis2,min(V_top,DimSize(DataMatrix,1)))
				YPts 	= abs(Y2 - Y1) + 1
				
				Make /FREE/N=(DimSize(DataMatrix,0)) YLineOut=0, YLineAvg=0
				
				for (i=Y1;i<Y2;i+=1)
					YLineOut[] 	= DataMatrix[p][i]
					WaveStats /Q/M=1/R=[X1,X2] YLineOut
					if (V_numNaNs == 0)
						YLineAvg += YLineOut
						yy += 1
					endif
					
//					YLineOut[] 	= (mask[p] == 1) ? NaN : DataMatrix[p][i]
//					YLineAvg[] += (numtype(YLineOut[p]) == 0) ? YLineOut[p] : 0
//					yy += 1
//					
//					WaveStats /Q/M=1/R=[X1,X2] YLineOut
//					if (V_numNaNs == 0)
//						YLineAvg += YLineOut
//						yy += 1
//					endif
				endfor
				
				if (yy == 0)
					DoAlert 0, "Selected region has too many NaNs"
					return 1
				endif
				YLineAvg /= yy
			
				if (cmpstr(S_selection,"subtract x-y average") == 0)
					// Either calculate the average pixel value within marquee ...
					AvPx 	= mean(YLineAvg,X1,X2)
					DataMatrix -= AvPx
					
					Print " 		*** Subtracted",AvPx,"from the 2D plot",ImageName
					
				elseif (cmpstr(S_selection,"subtract y average") == 0)
					Variable EosScale=1, EosGateTime 	= NumVarOrDefault("root:SPECTRA:GLOBALS:gEosGateTime",26.5)
					Prompt EosGateTime, "Max time for subtracting averaged horizontal spectrum?"
					Prompt EosScale, "Optional scale factor"
					DoPrompt "Background subtraction", EosGateTime, EosScale
					if (V_flag)
						return 1
					endif
					Variable /G root:SPECTRA:GLOBALS:gEosGateTime = EosGateTime
					
					iMax 	= AxisValueToPoint(Axis2,EosGateTime)
					// ... or the average spectrum
					for (i=0;i<iMax;i+=1) 
						DataMatrix[][i] -= EosScale * YLineAvg[p]
					endfor
					Print " 		*** Subtracted an average spectrum between",V_bottom,"to",V_top,"from the 2D plot",ImageName
					
				elseif (cmpstr(S_selection,"extract y-average") == 0)
					LineOutName 	= ReplaceString("_2D",NameOfWave(DataMatrix),"") + "_" + VertPos1+"_"+VertPos2
					Duplicate /O/D YLineAvg, root:SPECTRA:Plotting:LineOut
					
					AdoptedName 	= AdoptAxisAndDataFromMemory(NameOfWave(Axis),"",GetWavesDataFolder(Axis,1),"LineOut","","root:SPECTRA:Plotting",LineOutName,"",0,1,1)
				
					if (strlen(AdoptedName) > 0)
						AdoptNote 	= "A "+num2str(yy)+" pixel average horizontal lineout from "+ReplaceString("_2D",NameOfWave(DataMatrix),"")
						Note $AdoptedName, AdoptNote
					endif
				endif
			endif
					
		endif
	endif
	
	if (cmpstr(cursorName,"C") == 0)
		Update2DCursors(PanelName,PlotName,DataMatrix)
	endif
	
	// Test for Command-A, to autoscale axes
	if ((keyCode == 97 || keyCode == 65) && (GetKeyState(0) & 1))
		SetAxis  /W=$(panelName+"#TwoDPlot") /A
		SetAxis  /W=$(panelName+"#SpecPlot") /A
		SetAxis /W=$(panelName+"#SpecPlot") MaskAxis, 0, 1
		SetAxis  /W=$(panelName+"#KinPlot") /A	
		Scale2DSpectrum(panelName,spectrum, fit, mask,axis)
		return 1
	endif

	// This was an experiment to try manually tweaking line intensity problems in EEM data. 
	// Can probably be removed. 
	if ((keyCode == 60) || keyCode == 62)
		CsrCY 					= qcsr(C, subWinName+"#TwoDPlot")
		if (keyCode == 60)
			DataMatrix[][CsrCY] 	*= 1.1
		elseif (keyCode == 62)
			DataMatrix[][CsrCY] 	/= 1.1
		endif
	endif
		
	return 0
End	

//Function SetAll2DPlotAxisRanges(WindowName, AxisName, AutoFlag, Axis1, Axis2)
//	String WindowName, AxisName
//	Variable AutoFlag, Axis1, Axis2
//	
//	Variable j
//	
//	String PlotName, PlotList = ChildWindowList(WindowName)
//	
//	for (j=0;j<ItemsInList(PlotList);j+=1)
//		PlotName 	= WindowName+"#"+StringFromList(j,PlotList)
//		if (AutoFlag)
//			SetAxis /A
//		endif
//	endfor
//End

Function Process2DDataSpectra(DataMatrix,Axis,Axis2,PlotFolder,panelName)
	Wave DataMatrix,Axis,Axis2
	String PlotFolder,panelName
	
	String Process
	Prompt Process, "Choose processing", popup, "Invert positive spectra;Deglitch spectra;Delete spectrum;"
	DoPrompt "Processing menu", Process
	if (V_flag)
		return -1
	endif
	
	String ImageName 	= ReplaceString("_2D",NameOfWave(DataMatrix),"")
	String DataFolder 	= GetWavesDataFolder(DataMatrix,1)
	
	WAVE Axis2 		= $(DataFolder + ImageName + "_axis2")
	WAVE Axis2D 		= $(DataFolder + ImageName + "_2Dy")
	
	String subWinName	= panelName + "#TwoDPlot"
	Variable col = qcsr(C, subWinName)
	Variable i, avg, NTestPts, Range, NoiseLevel
	Variable NTimes=DimSize(DataMatrix,1), NEnergy=DimSize(DataMatrix,0)
	
	Make /FREE/D/N=(NEnergy) spectrum1, spectrum2
	Make /FREE/D/N=(NTimes) kinetics1, kinetics2
	Variable V_adev1, V_adev2, V_rms1, V_rms2
	
	if (cmpstr(Process,"Invert positive spectra") == 0)
		Print " 	*** Inverting positive spectra"
		for (i=0;i<NTimes;i+=1)
			spectrum1[] 	= DataMatrix[p][i]
//			avg 	= SumWaveWithNANs(spectrum1,0,NTimes-1)
			avg 	= SumWaveWithNANs(spectrum1,4,27)
			if (avg > 0)
				DataMatrix[][i] = -1 * spectrum1[p]
			endif
		endfor
		
	elseif (cmpstr(Process,"Deglitch spectra") == 0)
		Print " 	*** Attempting to deglitch random offsets."
		
		NTestPts = 5
		Range = (NTestPts-1)/2
		NoiseLevel = 0.5e-3
		
		for (i=1;i<NEnergy;i+=1)
			kinetics1[] 	= DataMatrix[p][i]
			kinetics2[] 	= DataMatrix[p][i]
			
			// Some wave stats on unaltered kinetics. 
			WaveStats /Q/R=[max(0,i-Range),min(NTimes-1,i+Range)] kinetics2 
			V_adev1 	= V_adev
			V_rms1 	= V_rms
			
			// Add the offset and re-test
			WaveStats /Q/R=[max(0,i-Range),min(NTimes-1,i+Range)] kinetics2
			V_adev2 	= V_adev
			V_rms2 	= V_rms
			
			if (spectrum1[i] > V_avg)
				spectrum1[i] -= NoiseLevel
			endif
			
			DataMatrix[][i] =  spectrum1[p]
		endfor
	
	elseif (cmpstr(Process,"Delete spectrum") == 0)
		Print " 	*** Deleting the spectrum at timepoint",Axis2[col],"ps. "
		DeletePoints /M=1 col, 1, DataMatrix
		DeletePoints /M=0 col, 1, Axis2
		MakeAxisForImagePlot(Axis2,Axis2D)
	endif
End

// 	Fucking annoying thing about cursors on images. 
// 	I can read off the (x,y) coordinates, but I cannot place using (x,y) coordinates. 
// 	I also cannot seem to be able to look up the X, Y axes from the Cursor recreation 
Function Update2DCursors(PanelName,PlotName,DataMatrix)
	String PanelName, PlotName
	Wave DataMatrix
	
	String subWinName	= PanelName + "#" + PlotName
	String PlotFolder 	= "root:SPECTRA:Plotting:" + panelName
	NVAR gCsrCX 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCX")
	NVAR gCsrCY 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gCsrCY")
	NVAR gWidth 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "gICAExtractWidth")
	
	Variable CsrCX=gCsrCX, CsrCY=gCsrCY
	
	strswitch (PlotName)
		case "TwoDPlot":
			CsrCX 	= pcsr(C, subWinName)
			CsrCY 	= qcsr(C, subWinName)
			break
		case "SpecPlot":
			CsrCX 	= pcsr(C, subWinName)
			break
		case "KinPlot":
			CsrCY 	= pcsr(C, subWinName)
			break
	endswitch
	
	gCsrCX=CsrCX; gCsrCY=CsrCY
	
	// Update all the cursors on the 2D and extracted plots. 
	Cursor/I/P/W=$(panelName+"#TwoDPlot") C $NameOfWave(DataMatrix) gCsrCX, gCsrCY
	Cursor/P/W=$(panelName+"#SpecPlot") C spectrum gCsrCX
	Cursor/P/W=$(panelName+"#KinPlot") C kinetics gCsrCY
	
//	ExtractFrom2DPlot(DataMatrix,PlotFolder,panelName+"#SpecPlot",gCsrCX,gCsrCY,gWidth)
	ExtractFrom2DPlot(DataMatrix,PlotFolder,panelName,gCsrCX,gCsrCY,gWidth,0)
End

// *************************************************************
// ****		Extract linescans from the 2D plot
// *************************************************************

Function ExtractFrom2DPlot(DataMatrix,PlotFolder,panelName,XPosition,YPosition,Width,Rescale)
	Wave DataMatrix
	String PlotFolder, panelName
	Variable XPosition,YPosition,Width,Rescale
	
	WAVE spectrum 	= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrum")
	WAVE kinetics 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "kinetics")
	WAVE fit 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "fit")
	WAVE resids 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "residuals")
	WAVE errors 		= $(ParseFilePath(2,PlotFolder,":",0,0) + "errors")
	WAVE mask 			= $(ParseFilePath(2,PlotFolder,":",0,0) + "spectrumMask")
	
	String ImageFolder 	= GetWavesDataFolder(DataMatrix,1)
	WAVE LLSFit 		= $(ParseFilePath(2,ImageFolder,":",0,0) + "LLSFit")
	WAVE LLSResids 	= $(ParseFilePath(2,ImageFolder,":",0,0) + "LLSResiduals")
	WAVE Axis 			= $(ParseFilePath(1,ImageFolder,":",1,0) + ReplaceString("_2D",NameOfWave(DataMatrix),"_axis"))
	
	Variable n, m=0, i, i1, i2, di = (Width-1)/2
	Variable MaxX=DimSize(DataMatrix,0)-1, MaxY=DimSize(DataMatrix,1)-1
	
	kinetics 		= 0
	spectrum 		= 0
	fit 				= 0
	resids 			= 0
	
	// Extract the trend, skipping bad pixel NaN's
	n 	= 0
	i1 	= max(0,XPosition-di)
	i2 	= min(MaxX,XPosition+di)
	
	for (i=i1;i<=i2;i+=1)
		n +=1
		ImageStats /G={i,i,0,MaxY} DataMatrix
		if (numtype(V_avg) == 0)
			kinetics[] 		+= DataMatrix[i][p]
			m += 1
		endif
	endfor
	kinetics /= m
	
	// Extract the spectrum
	n 	= 0
	i1 	= max(0,YPosition-di)
	i2 	= min(MaxY,YPosition+di)
	
	for (i=i1;i<=i2;i+=1)
		n += 1
		spectrum[] 		+= DataMatrix[p][i]
		
		if (WaveExists(LLSFit))
			fit[] 		+= LLSFit[p][i]
			resids[] 	+= LLSResids[p][i]
		else
			fit[] 		= NaN
			resids[] 	= NaN
		endif
	endfor
	spectrum /= n
	fit /= n
	resids /= n
	
	Rescale = 1
	if (Rescale)
		Scale2DSpectrum(PanelName,spectrum, fit, mask,Axis)
	endif
End

Function Scale2DSpectrum(panelName,spectrum, fit, mask,axis)
	String panelName
	Wave spectrum, fit, mask, axis
	
	NVAR gRescale 	= $("root:SPECTRA:Plotting:" + PanelName+":gRescaleFlag")
	if (!gRescale)
		return 0
	endif
	
	Variable i, MinPt, MaxPt
	Variable MaxV=-1e99, MinV=1e99, NPnts=numpnts(spectrum)
	
	GetAxis /Q/W=$(panelName+"#TwoDPlot") bottom
	MinPt 	= AxisValueToPoint(axis,V_min)
	MaxPt 	= AxisValueToPoint(axis,V_max)
	
	for (i=MinPt;i<MaxPt;i+=1)
		if (numtype(mask[i]) == 2)
			MinV 	= (spectrum[i] < MinV) ? spectrum[i] : MinV
			MaxV 	= (spectrum[i] > MaxV) ? spectrum[i] : MaxV
			
			if (numtype(fit[i]) == 0)
				MinV 	= (fit[i] < MinV) ? fit[i] : MinV
				MaxV 	= (fit[i] > MaxV) ? fit[i] : MaxV
			endif
		endif
	endfor
	
	SetAxis /W=$(panelName+"#SpecPlot") left, MinV, MaxV
	SetAxis /W=$(panelName+"#SpecPlot") MaskAxis, 0, 1
End

Function TwoDPlotCheckProcs(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	Variable checked		= CB_Struct.checked
	String userData 		= CB_Struct.userData
	String plotWin			= CB_Struct.win
	String ctrlName			= CB_Struct.ctrlName
	
	String subWinName = plotWin+"#TwoDPlot"
	String subWinList 	= GetUserData(plotWin,ctrlName,"subWinList")
	String AxesList 		= GetUserData(plotWin,ctrlName,"AxesList")
	String FuncList 		= GetUserData(plotWin,ctrlName,"FuncCall")
	Variable i, NItems	= ItemsInList(subWinList)
	
	if (cmpstr(ctrlName,"ColorLegendCheck") == 0)
		ColorScale /W=$subWinName/A=LT/C/N=ColorScale0 /V=(checked)
	elseif (cmpstr(ctrlName,"LogYAxes") == 0)
//		ModifyGraph /W=$subWinName log($axisName)=checked
	endif

End

// Toggle between the Components and Trends plots. 
Function ICADisplay(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	UpdateICADisplay(ReturnLastNumber(CB_Struct.ctrlName),CB_Struct.win)
	
	return 0
End

Function UpdateICADisplay(ICACheck,panelName)
	Variable ICACheck
	String panelName
	
	CheckBox ICACheck1,value= (ICACheck==1)
	CheckBox ICACheck2,value= (ICACheck==2)
	
	SetWindow $(panelName+"#TrendsPlot"),hide= (ICACheck==1)
	SetWindow $(panelName+"#ComponentsPlot"),hide= (ICACheck==2)
End	

// *************************************************************
// ****		A general procedure to modify named axes using a named user function
// *************************************************************
Function ModifyGraphCheckProcs(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	Variable checked		= CB_Struct.checked
	String userData 		= CB_Struct.userData
	String plotWin			= CB_Struct.win
	String ctrlName			= CB_Struct.ctrlName
	
	String subWinList 	= GetUserData(plotWin,ctrlName,"subWinList")
	String AxesList 		= GetUserData(plotWin,ctrlName,"AxesList")
	String FuncList 		= GetUserData(plotWin,ctrlName,"FuncCall")
	Variable i, NItems	= ItemsInList(subWinList)
	
	for (i=0;i<NItems;i+=1)
		String subWinName 	= StringFromList(i,subWinList)
		String axisName 		= StringFromList(i,AxesList)
		
		FUNCREF AxisFuncPrototype CheckBoxFunc = $StringFromList(i,FuncList)
		CheckBoxFunc(subWinName,axisName,checked)
	endfor
	
	return 1
End

Function LogAxes(subWinName,axisName,checked)
	String subWinName,axisName
	Variable checked
	
	ModifyGraph /W=$subWinName log($axisName)=checked
End

Function AxisFuncPrototype(subWinName,axisName,checked)
	String subWinName,axisName
	Variable checked
	
	// do nothing
End

// ***************************************************************************
// **************** 		Convert single data loads into a 2D array
// ***************************************************************************
Function Finish2DDataInput(UserName,TwoDDataList,LoadNum)
	String UserName,TwoDDataList
	Variable LoadNum
	
	Variable i, j=0, NPoints, NSpectra
	String AxisName, DataName, AssocDataFolder, AssocDataList
	String HAxisChoice="title", AxisNameList, DataNameList, GoodAxisList="", GoodDataList=""
	
	String SampleName 	= UserName
	Prompt SampleName, "Name the 2D data"
	Prompt HAxisChoice, "Values for each spectrum", popup, "manual;creation date;title;text file;"
	DoPrompt "Import spectra to 2D plot", SampleName, HAxisChoice
	if (V_flag)
		return 0
	endif
	
	AxisNameList = AddPrefixOrSuffixToListItems(TwoDDataList,"","_axis")
	DataNameList = AddPrefixOrSuffixToListItems(TwoDDataList,"","_data")
	
	AxisName 	= StringFromList(0,AxisNameList)
	DataName 	= StringFromList(0,DataNameList)
	
	// We will enforce interpolation onto the first loaded axis. 
	WAVE Axis = $AxisName
	WAVE Data = $DataName
	NPoints 	= numpnts(Axis)
	
	Make /D/N=(NPoints)/FREE SingleDataInterp
	
	NSpectra = ItemsInList(AxisNameList)
	Make /O/D/N=(NPoints,NSpectra) $(SampleName+"_2D") /WAVE=DataMatrix
	DataMatrix[][0]	= Data[p]
	
	for (i=1;i<NSpectra;i+=1)
		WAVE SingleAxis 	= $StringFromList(i,AxisNameList)
		WAVE SingleData 	= $StringFromList(i,DataNameList)
		
		if (!EqualWaves(Axis,SingleAxis,1))
			print " 		... difference in axes between",AxisName,"and",StringFromList(i,AxisNameList)
		endif
		Interpolate2 /T=1/I=3/X=Axis/Y=SingleDataInterp SingleAxis, SingleData
		
		 DataMatrix[][i]	= SingleDataInterp[p]
	endfor
	
	Make /O/D/N=(NSpectra) $(SampleName+"_axis2") /WAVE=Axis2
	
	strswitch (HAxisChoice)
		case "manual":
			Axis2 = p
			break
		case "title":
			ExtractValuesFromTitle(DataNameList,Axis2)
			break
		case "creation date":
			Axis2 = p
			break
		case "text file":
			Axis2 = p
			break
	endswitch
	
	// Make axes for displaying the data as image plots. 
	Make /O/D/N=(NPoints+1) $(SampleName+"_2Dx") /WAVE=AxisX
	Make /O/D/N=(NSpectra+1) $(SampleName+"_2Dy") /WAVE=AxisY
	MakeAxisForImagePlot(Axis,AxisX)
	MakeAxisForImagePlot(Axis2,AxisY)
	
	if (!CheckMonotonic(Axis2))
		EnforceMonotonic(DataMatrix,Axis2)
	endif
	
	AssocDataFolder = "TwoD"
	AssocDataList 	= SampleName+"_axis2;"+SampleName+"_2Dx;"+SampleName+"_2Dy;"+SampleName+"_2D;"
	
	NewLoadedDataFolder(LoadNum,0,"root:SPECTRA:Import",AxisName,DataName,SampleName,"",AssocDataList,AssocDataFolder)
	
	KillWavesFromList(AxisNameList,0)
	KillWavesFromList(DataNameList,0)
	KillWavesFromList(AssocDataList,0)
	KillWavesFromList(AddPrefixOrSuffixToListItems(AxisNameList,"","_sig"),0)
	KillWavesFromList(AddPrefixOrSuffixToListItems(DataNameList,"","_sig"),0)
	
	return 1
End

Function ExtractValuesFromTitle(DataNameList,Axis)
	String DataNameList
	Wave Axis
	
	Variable i, NData=ItemsInList(DataNameList)
	String NoteStr, FileName, DayStr, MonthStr, HMSStr
	Variable Year,Month,Day,DDate,Hour,Minute,Seconds,IgorDate,IgorTime, IgorStart
	
	for (i=0;i<NData;i+=1)
		NoteStr 	= note($(StringFromList(i,DataNameList)))
		FileName 	= ReplaceString("-",ReturnTextBeforeNthChar(NoteStr,".",1),":")
		sscanf FileName, "%s%s %i %s %i", DayStr,MonthStr,DDate,HMSStr,Year
		Month 		= MonthNameToNumber(MonthStr)
		IgorDate 	= date2secs(Year,Month,DDate)
		IgorTime 	= TimeStr2Secs(HMSStr)
		if (i==0)
			IgorStart = IgorDate + IgorTime
		endif
		Axis[i] 		= (IgorDate + IgorTime) - IgorStart
	endfor
End

// *************************************************************
// ****		Load 2D matrix of data
// *************************************************************

Function /T Load2DData(MatrixType,FileName,DataName,SampleName,AssocDataList, AssocDataFolder)
	String MatrixType,FileName,DataName,SampleName, &AssocDataList, &AssocDataFolder

	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	String PathAndFileName 	= gPath2Data + FileName
	String fileInfo 				= FileName + "\r" + gPath2Data
	
	String SampleName2D 		= SampleName+"_2D"
	String AxisName 			= SampleName+"_axis"
	String Axis2Name 			= SampleName+"_axis2"
	String Axis2DName 			= SampleName+"_2Dx"
	String Axis2DName2		= SampleName+"_2Dy"
	String DataAvgName 		= SampleName+"_data"
	
	KillWaves /Z $AxisName, Axis2Name, Axis2DName, Axis2DName2, SampleName2D
	
	String DataNote, DataType
	Variable Success
	
	Make /O/D/N=(0,0) DataMatrix
	Make /O/D/N=0 Axis1, Axis2
	
	strswitch (MatrixType)
		case "FTIR kinetics":
			DataType = "Kinetic spectra"
			Success = Load2DWave(PathAndFileName,MatrixType,DataMatrix,Axis1, Axis2)
			break
		case "Fluorolog EEM":
			DataType = "EEM"
			Success = Load2DWave(PathAndFileName,MatrixType,DataMatrix,Axis1, Axis2)
			break
		case "transient absorption":
			DataType = "TA"
			Success = Load2DWave(PathAndFileName,MatrixType,DataMatrix,Axis1, Axis2)
			ReadTAFileInfo(PathAndFileName,"file info",fileInfo)
			break
		case "Eos":
			DataType = "TA"
			Success = Load2DWave(PathAndFileName,"transient absorption",DataMatrix,Axis1, Axis2)
			ReadTAFileInfo(PathAndFileName,"file info",fileInfo)
			break
		case "TIFF image":
			DataType = "IMAGE"
			Success = LoadImageWave(PathAndFileName, FileName, MatrixType,DataMatrix,Axis1, Axis2)
			ReadTAFileInfo(PathAndFileName,"file info",fileInfo)
			break
	endswitch
	
	if (!Success)
		return ""
	endif
	
	// Properly name the axis waves
	Rename Axis1, $AxisName
	Rename Axis2, $Axis2Name
	
	// Make axes for displaying the data as image plots. 
	Variable NXPts=DimSize(Axis1,0), NYPts=DimSize(Axis2,0)
	Make /O/D/N=(NXPts+1) $Axis2DName /WAVE=AxisX
	Make /O/D/N=(NYPts+1) $Axis2DName2 /WAVE=AxisY
	MakeAxisForImagePlot(Axis1,AxisX)
	MakeAxisForImagePlot(Axis2,AxisY)
	
	// Make an dummy data wave for display in the Plotting Panel
	MatrixOp /O temp = ReplaceNaNs(DataMatrix,0)
	MatrixOp /O $DataAvgName = sumRows(temp)
	
	Rename DataMatrix, $SampleName2D
	
	// Record the full original filename as a wave note. 
	DataNote = fileInfo + "\r"
	DataNote = DataNote + "Data Type="+DataType
	Note /K $DataAvgName, DataNote
	Note /K $SampleName2D, DataNote
		
	AssocDataFolder = "TwoD"
	AssocDataList 	= Axis2Name+";"+Axis2DName+";"+Axis2DName2+";"+SampleName2D+";"
	
	KillWaves /Z temp
	
	return SampleName
	
End	


Function LoadImageWave(PathAndFileName,FileName, ImageType,DataMatrix,Axis1, Axis2)
	String PathAndFileName, FileName, ImageType
	Wave DataMatrix,Axis1, Axis2
	
	String imageName
	Variable DimX, DimY, DimZ
	
	strswitch (ImageType)
		case "TIFF Image":
//			KillDataFolder /Z tmp
//			NewDataFolder /O/S tmp
//			ImageLoad /C=4/T=any/RAT PathAndFileName
			ImageLoad /C=1/T=TIFF/RAT PathAndFileName

//			print V_numImages
//			KillDataFolder :
			
			break
		case "PN ImageG":
			ImageLoad /Q/T=PNG PathAndFileName
			break
	endswitch
	
	if (!V_flag)
		return 0
	else
		print " 		*** Loaded",V_numImages,"image(s) from",S_fileName
	endif
	
	ImageName 	= CleanUpName(FileName,0)
	KillWaves /Z $ImageName
	Rename $FileName, $imageName
	WAVE TIFFImage 	= $("root:SPECTRA:Import:"+imageName)
	
	DimX 	= DimSize(TIFFImage,0)
	DimY 	= DimSize(TIFFImage,1)
	DimZ 	= DimSize(TIFFImage,2)
	
	if (DimZ > 1)
		print " 		.... Selecting the first image only"
		Redimension /N=(DimX,DimY) TIFFImage
	endif
	
	Redimension /N=(DimX,DimY) DataMatrix
	DataMatrix 	= TIFFImage
	KillWaves /Z TIFFImage
	
	Redimension /N=(DimX) Axis1; Axis1[]=p
	Redimension /N=(DimY) Axis2; Axis2[]=p
	
	return 1
End


// Use the LoadWave command for simpler file types. 
// 	The Axis1 is always in the first column. 
// 	The Axis2 may or may not be in the first row. 
Function Load2DWave(PathAndFileName,MatrixType,DataMatrix,Axis1, Axis2)
	String PathAndFileName, MatrixType
	Wave DataMatrix,Axis1, Axis2
	
	Variable NRows, NCols, NAxis1, NAxis2, NAvg, NNaN1, NNaN2, Success=1, resolution
	
	KillWaves /Z wave0, matrix0
	
	// Load in the full 2D matrix, with or without the Axis2 line. 
	strswitch (MatrixType)
		case "FTIR kinetics":
			// Load Axis2 in the first row. Skip the first column of blank tabs
			LoadWave/J/M/D/A=matrix/K=1/L={0,0,1,0,0}/V={"\t"," $",0,0} PathAndFileName
//			LoadWave/J/M/D/A=matrix/K=1/L={0,0,1,0,0}/V={", "," $",0,0} PathAndFileName
			break
		case "Fluorolog EEM":
			// Skip the first two header lines, including the Axis2 line
			LoadWave /Q/J/M/D/A=matrix/L={0,2,0,0,0} PathAndFileName
			break
		case "transient absorption":
			// Load Axis2 is in the first row. 
			LoadWave /Q/J/M/D/A=matrix/L={0,0,0,0,0} PathAndFileName
			break
	endswitch
		
	if (V_flag == 0)
		Print " *** No columns found in file. Abort"
		return 0
	endif
	
	WAVE FullMatrix 	= $"matrix0"
	Duplicate /O/D FullMatrix, root:temp
	NRows = DimSize(FullMatrix,0)
	NCols = DimSize(FullMatrix,1)
	Print " 	 	...	Loading data from a",NRows,"x",NCols,"matrix."
	
	// This is the default assumption for loaded array dimensions
	NAxis1 	= NRows		// The horizontal axis
	NAxis2 	= NCols-1		// The vertical axis. 
	
	// Redimension the axes accordingly
	Redimension /N=(NAxis1) Axis1
	Redimension /N=(NAxis2) Axis2
	
	// Read out the Axis2 values
	strswitch (MatrixType)
		case "FTIR kinetics":
			MatrixOp /O Axis2 = row(FullMatrix,0)
			Redimension /N=(NAxis2) Axis2
			// Delete the first point, which contained the dummy "0.0000" value
			DeletePoints 0, 1, Axis2
			// Remove the first row which contained the Axis 2 values. 
			DeletePoints /M=0 0, 1, FullMatrix
			break
			
		case "Fluorolog EEM":
 			if (cmpstr(ReturnLastSuffix(S_Filename,"."),"csv") == 0)
				Success = ReadAxis2Values(Axis2,S_Path,S_Filename,"Wavelength",",",0)	// comma delimiter
			else
				Success = ReadAxis2Values(Axis2,S_Path,S_Filename,"Wavelength","\t",0)	// tab delimiter
			endif
			break
			
		case "transient absorption":
			MatrixOp /O Axis2 = row(FullMatrix,0)
			// Transport the axis and redimension into a 1D wave
			MatrixOp /O Axis2 = Axis2^t
			Redimension /N=(NAxis2+1) Axis2
			// Delete the first point, which contained the dummy "0.0000" value
			DeletePoints 0, 1, Axis2
			// Remove the first row which contained the Axis 2 values. 
			DeletePoints /M=0 0, 1, FullMatrix
			break
	endswitch
		
	if (!Success)
		return 0
	endif
	
	// Read out the Axis1 values
	MatrixOp /O Axis1 = col(FullMatrix,0)
	// Remove the first column which contained the Axis 1 values
	DeletePoints /M=1 0, 1, FullMatrix
	
	// Transfer to DataMatrix while removing the first column = Axis1
	ReDimension /N=(DimSize(FullMatrix,0),DimSize(FullMatrix,1)) DataMatrix
	DataMatrix[][] 	= FullMatrix[p][q]
	
	KillWaves /Z FullMatrix
	
	// Some optional post-processing
	strswitch (MatrixType)
	
		case "transient absorption":
			CheckAxisValues(DataMatrix,Axis1,Axis2,NAvg,NNaN1,NNaN2)
			if (NNaN1 > 0)
				print " 		... 	Removed",NNaN1,"columns with NaN horizontal axis values"
			endif
			if (NAvg > 0)
				print " 		... 	Averaged",NAvg,"columns with identical vertical axis values"
			endif
			if (NNaN2 > 0)
				print " 		... 	Removed",NNaN2,"columns with NaN vertical axis values"
			endif
			break
			
		case "Fluorolog EEM":
			// For Fluorolog data, remove the Elastic contribution. Set "resolution" to about ±8 nm. 
			resolution=10
			Print " 	 	...	Removing elastic contribution and low-energy region from Fluorolog data up to E_ex +"+num2str(resolution)+" nm"
			DataMatrix[][] 	= (Axis1[p] < Axis2[q]+resolution) ? NaN : DataMatrix[p][q]
			DataMatrix[][] 	= (Axis1[p] > (2*Axis2[q]-resolution)) ? NaN : DataMatrix[p][q]
			break
	endswitch
	
	Print " 	 	...	The horizontal axis runs from",Axis1[0],"to",Axis1[NAxis1-1],". The vertical axis runs from",Axis2[0],"to",Axis2[NAxis2-1]
	
	return 1
End

Function CheckAxisValues(DataMatrix,Axis1,Axis2,NAvg,NNaN1,NNaN2)
	Wave DataMatrix,Axis1, Axis2
	Variable &NAvg, &NNaN1, &NNaN2
	
	Variable i=1, j
	Variable NRows 	= DimSize(DataMatrix,0)
	Variable NCols 	= DimSize(DataMatrix,1)
	
	NAvg = 0; NNaN1 = 0; NNaN2 = 0
	
	// Remove NaNs from the horizontal axis (actually the first column)
	i = 0
	for (j=0;j<NRows;j+=1)
		if (numtype(Axis1[i]) != 0)
			DeletePoints /M=0 (i), 1, DataMatrix
			DeletePoints (i), 1, Axis1
			NNaN1 += 1
		else
			i+=1
		endif
	endfor
	NRows 	= DimSize(DataMatrix,0)
	
	// Remove NaNs from the vertical axis (actually the top row)
	i = 0
	for (j=0;j<NCols;j+=1)
		if (numtype(Axis2[i]) != 0)
			DeletePoints /M=1 (i), 1, DataMatrix
			DeletePoints (i), 1, Axis2
			NNaN2 += 1
		else
			i+=1
		endif
	endfor
	NCols 	= DimSize(DataMatrix,1)
	
	// Remove spectra that have no data at some vertical axis values
	i = 0
	for (j=0;j<NCols;j+=1)
		MatrixOp /O AvgCol = col(DataMatrix,i)
		WaveStats /Q/M=1 AvgCol
		if (numtype(V_avg)== 2)
			DeletePoints /M=1 (i), 1, DataMatrix
			DeletePoints (i), 1, Axis2
		else
			i+=1
		endif
	endfor
	NCols 	= DimSize(DataMatrix,1)
	
	// Average spectra at the same vertical axis values
	i = 1
	for (j=1;j<NCols;j+=1)
	
	
		if (Axis2[i-1] == Axis2[i])
			MatrixOp /O AvgCol 	= (col(DataMatrix,i-1) + col(DataMatrix,i))/2
			DataMatrix[][i-1] 	= AvgCol[p]
			DeletePoints /M=1 (i), 1, DataMatrix
			DeletePoints (i), 1, Axis2
			NAvg += 1
		else
			i+=1
		endif
	endfor
End

// Return string containing experimental conditions. 
Function ReadTAFileInfo(PathAndFileName,keyword,fileInfo)
	String PathAndFileName, keyword, &fileInfo
	
	String text
	Variable refNum
	
	Open/R refNum as PathAndFileName
	if (refNum == 0)
		return 0	// User canceled
	endif
	
	do
		FReadLine refNum, text
		if (strlen(text) == 0)
			Close refNum
			return 0
		elseif (strsearch(text,keyword,0) > -1)
			break
		endif
	while(1)
	
	do
		FReadLine refNum, text
		if (strlen(text) == 0)
			Close refNum
			return 1
		else
			fileInfo 	= fileInfo + text
		endif
	while(1)
End

// *************************************************************
// ****		Routines to create the second axis for the 2D plot
// *************************************************************

Function ReadAxis2Values(Axis2,Path,Filename,keyword,delimiter,linenum)
	Wave Axis2
	String Path, Filename, keyword, delimiter
	Variable linenum
	
	Variable n, i, FileRefNum, NValues, Identical, Success = 0, NPnts, NChars, AxPt
	String FileLine, FullPath = Path + Filename
	
	NPnts 	= numpnts(Axis2)
	NChars 	= strlen(keyword)
	AxPt	= Axis2[0]		// <---- Needed to strip 'bad' columns from Eod data
	
	Open /Z/R FileRefNum as FullPath
	
	do	// -------- Loop through lines in input file -------
		FReadLine FileRefNum, FileLine
		if (strlen(FileLine) == 0)
			break
		endif
		
		if (NChars > 0) 
			// We are searching for a keyword at the START of the line containing the Y-axis values.  
			if (StrSearch(FileLine[0,NChars-1],keyword,0) > -1)
				Success = 1
				break
			elseif (StrSearch(FileLine[1,NChars],keyword,0) > -1)
				Success = 1
				break
			endif
		elseif (linenum == n)
			// We are searching for a known line number
			Success = 1
			break
		endif
		
		n += 1
	while(1)
	
	Close FileRefNum
	
	if (Success)
		NValues 	= ItemsInList(FileLine,delimiter)
		Print " 		... 	Found keyword",keyword,"at line",n,"containing",NValues,"columns"
		if (NValues == NPnts) 
			ListValuesToWave(Axis2,FileLine,delimiter,0)
		elseif (NValues == (NPnts+1))
			ListValuesToWave(Axis2,FileLine,delimiter,1)
		elseif (NValues == (NPnts+2))
			ListValuesToWave(Axis2,FileLine,delimiter,2)
		elseif (AxPt > 0)
			Make /D/FREE/N=(NValues) LongAxis
			ListValuesToWave(LongAxis,FileLine,delimiter,0)
			Axis2[] 	= LongAxis[p+AxPt]
		else
			Print " 		...	Could not read column values from file. "
			return 0
		endif
	endif
	
	return 1
End

// Recall that the Image display axes have an extra point. 
Function MakeAxisForImagePlot(Axis,Axis2D)
	Wave Axis, Axis2D
	
	Variable i, delta, NPnts=numpnts(Axis), NPnts2D=numpnts(Axis2D)
	
	if ((NPnts2D - NPnts) != 1)
		Redimension /N=(NPnts+1) Axis2D
	endif
	
	// From the Wavemetrics procedure MakeEdgesWave
	Axis2D[0] 				= Axis[0]-0.5*(Axis[1]-Axis[0]) 
	Axis2D[NPnts] 			= Axis[NPnts-1]+0.5*(Axis[NPnts-1]-Axis[NPnts-2]) 
	Axis2D[1,NPnts-1] 	= Axis[p]-0.5*(Axis[p]-Axis[p-1])
	
End

Function EnforceMonotonic(Data2D,Axis2D)
	Wave Data2D, Axis2D
	
	Variable i=0, j=0, NXPts, NYPts, Value, AscendingFlag, MonoFlag, NSwapped=0
	NXPts=Dimsize(Data2D,0)
	NYPts=Dimsize(Data2D,1)
	
	Make /D/FREE/N=(NXPts) Row
	
	AscendingFlag 	= (Axis2D[0] < Axis2D[NYPts-1]) ?  1  :  0
	
	
	Print " 		... swapping column ordering so that the Y-axis is monotonic"

	do
		for (i=1;i<NYPts;i+=1)
			if ((AscendingFlag && (Axis2D[i] < Axis2D[i-1])) || (!AscendingFlag && (Axis2D[i] > Axis2D[i-1])))
				// Swap the order of these 
				Row[] 			= Data2D[i-1][p]
				Data2D[i-1][] 	= Data2D[i][q]
				Data2D[i][]		= Row[q]
				
				Value 			= Axis2D[i-1]
				Axis2D[i-1] 	= Axis2D[i]
				Axis2D[i] 		= Value
				
				NSwapped += 1
			endif
		endfor
		
		j += 1
		
		MonoFlag = CheckMonotonic(Axis2D)
		
		
	while(!MonoFlag)
	
	Print " 		... completed in",j,"loops"
	
	
End

