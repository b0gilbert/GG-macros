#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method.

// !*!*! NOTE on the Global Coefficients waves. 
// GlobalCfs: 		The primary coefficient wave, which should be accurate before and after each fit. 
// GlobalCfsSave: 	A copy of GlobalCfs generated before each fit. This seems dispensable. 
// GlobalCfsOpt: 	The short list of coefficients that are optimized.
// GlobalCfsAll: 	The coefficients used in the GK Optimization routines to calculate the spectra. It combines fitted ("Opt") and held ("Save") coefficients. 

// !*!* NOTE on the Scale factors and the Component waves
// 	Tricky business - needs good notes here. 
//
// !*!* 2020-12 
// Okay, the issue is that the transient spectra include excited-state absorption (i.e., positive) and ground-state bleaches (i.e., negative). 
// 	We need to allow both positive and negative byt avoid unphysical transients being introduced to improve the fit. 
// 	A problem 

Constant BetaMin 	= 0.05


// *************************************************************
// ****		The structure of the coefficients wave
// *************************************************************

// 	NCmpts 	= number of spectra components

Function GlobalKineticsPointers(nData,NCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
	Variable nData,NCmpts, &pDTau, &pOffset, &pFWHM, &pTaus, &pScales, &pAmps,PrintFlag
	
	pDTau 		= 0							// Index of TEMPORAL offset
	pOffset 		= pDTau+1					// Index of INTENSITY offset 
	pFWHM 		= pDTau+2					// Index of the TEMPORAL RESOLUTION FUNCTION
	pTaus 		= pFWHM + 1				// Index of the exponential decay parameters for each spectral component. 
	pScales 		= pTaus + 2*NCmpts		// Index of overal scale factors for each spectral component. 
	pAmps 		= pScales + NCmpts		// Index of wavelength-dependent amplitudes that define each spectral component
	
	PrintFlag = 0
	
	if (PrintFlag)	// debugging
		Print " ** Indices to the coefficients ***"
		Print " 		Number of Spectral Components=",NCmpts
		Print " 		Index of INTENSITY OFFSET point , 	pOffset=	",pOffset
		Print " 		Index of FWHM point 		pFWHM=	",pFWHM
		Print " 		Index of DECAY Consts starting point 	pTaus=		",pTaus
		Print " 		Index of SCALES starting point 		pScales:		",pScales
		Print " 		Index of AMPLITUDES starting point , pAmps=	",pAmps,"\r"
	endif
	
	// Calculate the total number of coefficients and make the concatenated coefficients waves
	return 3 + 2*NCmpts + NCmpts + (NCmpts*NData)
End

Function GlobalKineticsLegend(nData,NCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,GKLegend)
	Variable nData,NCmpts, &pDTau, &pOffset, &pFWHM, &pTaus, &pScales, &pAmps
	Wave /T GKLegend
	
	pDTau 		= 0							// Index of TEMPORAL offset
	pOffset 		= pDTau+1					// Index of INTENSITY offset 
	pFWHM 		= pDTau+2					// Index of the TEMPORAL RESOLUTION FUNCTION
	pTaus 		= pFWHM + 1				// Index of the exponential decay parameters for each spectral component. 
	pScales 		= pTaus + 2*NCmpts		// Index of overal scale factors for each spectral component. 
	pAmps 		= pScales + NCmpts		// Index of wavelength-dependent amplitudes that define each spectral component
	
	GKLegend[] = ""
	GKLegend[pDTau] = 	"Time offset"
	GKLegend[pOffset] = 	"Intensity offset"
	GKLegend[pFWHM] = 	"Resolution"
	GKLegend[pTaus] = 	"Decay parameters"
	GKLegend[pScales] = 	"Scale factors"
	GKLegend[pAmps] = 	"Amplitudes"
	GKLegend[pDTau] = 	"Time offset"
	
End



// *************************************************************
// ****		GLOBAL KINETICS FITS
// *************************************************************

Function InitGlobalKineticsFit()

	String OldDF = getDataFolder(1)
	NewDataFolder/O root:SPECTRA
	NewDataFolder/O/S root:SPECTRA:Fitting
	NewDataFolder/O/S root:SPECTRA:Fitting:GlobalKinetics
		
		// The list of data that can be plotted and fitted
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gNData",1)
		NVAR gNData	= root:SPECTRA:Fitting:GlobalKinetics:gNData
		
		// This command actually creates the wFitData wave
		gNData 	= SelectedDataList(0,1,"wFitData","root:SPECTRA:Fitting:GlobalKinetics","")
		
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gNCmpts",1)
		NVAR gNCmpts	= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
		
		// The ListBox waves for manually entering Time Constant coefficient values
		if (!WaveExists(TimeConstantsSel))
			Make /O/D/N=(gNCmpts+2,3) TimeConstantsSel=0
			Make /O/T/N=(gNCmpts+2,3) TimeConstantsList=""
		endif
		
		// The ListBox waves for controlling fits of Spectral Amplitudes
		if (!WaveExists(SpectralAmplitudeSel) || (DimSize(SpectralAmplitudeSel,1) != 6))
			Make /O/D/N=(gNCmpts,6) SpectralAmplitudeSel=0
			Make /O/T/N=(gNCmpts,6) SpectralAmplitudeList=""
		endif
		
		 SetNumGlobalKineticsCmpts()
				
		// Globals to record the delimited fit range
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gFitMin",0)
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gFitMax",0)
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gConvolve",0)
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gConvCenter",0)
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gChiSqr",0)
		
		// Add a global to enforce positive amplitudes or not
		MakeVariableIfNeeded("root:SPECTRA:Fitting:GlobalKinetics:gPositiveAmpls",0)
		
	SetDataFolder $(OldDF)
End

// Update the list boxes used to control parameter fitting. 
Function SetNumGlobalKineticsCmpts()

	WAVE/T TCList		= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
	WAVE TCSel			= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsSel
	WAVE/T SAList		= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeList
	WAVE SASel			= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	
	Variable i, k=1
	
	Redimension /N=(2*gNCmpts+3,3) TCList, TCSel
	SetDimLabel 1, 0, $"\\f01Legend", TCList
	SetDimLabel 1, 1, $"\\f01Values", TCList
	SetDimLabel 1, 2, $"\\f01Hold", TCList
	
	// Allow the coefficient column to be editable. 
	TCSel[][1] 	= BitSet(TCSel[p][1],1)
	// Check boxes to hold all coefficients. 
	TCSel[][2]	= BitSet(TCSel[p][2],5)
	
	TCList[0][0] 	= "Time zero"
	TCList[1][0] 	= "Intensity offset"
	TCList[2][0] 	= "Pulse FWHM"
	
	for(i=3;i<DimSize(TCList,0);i+=2)
		TCList[i][0]  = "Time constant "+num2str(k)
		TCList[i+1][0]  = "Stretch expt "+num2str(k)
		k+=1
	endfor
	
	Redimension /N=(gNCmpts,6) SAList, SASel
	SetDimLabel 1, 0, $"\\f01Legend", SAList
	SetDimLabel 1, 1, $"\\f01Keep", SAList
	SetDimLabel 1, 2, $"\\f01Hold", SAList
	SetDimLabel 1, 3, $"\\f01Scale", SAList
	SetDimLabel 1, 4, $"\\f01Plot", SAList
	SetDimLabel 1, 5, $"\\f01Use #", SAList
	
	// NOTE: Making a cell editable requires setting Bit 1. 
	// NOTE: Placing check boxes into a ListBox cell requires setting Bit 5. 
	// NOTE: Checking and unchecking the box requires setting or clearing Bit 4. 
	
	// Check boxes to keep/RANDOMIZE the spectral envelopes. 
	SASel[][1]	= BitSet(SASel[p][1],5)
	// Check boxes to vary/HOLD the spectral envelopes. 
	SASel[][2]	= BitSet(SASel[p][2],5)
	// Check boxes to SCALE the spectral envelopes. 
	SASel[][3]	= BitSet(SASel[p][3],5)
	// Check boxes to PLOT the spectral envelopes. 
	SASel[][4]	= BitSet(SASel[p][4],5)
	// The 5th column is to allow linking spectral amplitudes. Allow it to be editable. 
	SASel[][5] 	= BitSet(SASel[p][5],1)
	
	for(i=0;i<DimSize(SAList,0);i+=1)
		SAList[i][0]  = "Spectrum "+num2str(i+1)
	endfor
End

// ***************************************************************************
// **************** 			CREATE THE INTERACTIVE PANEL FOR FITTING
// ***************************************************************************
Function PlotGlobalKineticsFit()
	
	WAVE/T wFitDataList			= root:SPECTRA:Fitting:GlobalKinetics:wFitDataList
	WAVE wFitDataSel				= root:SPECTRA:Fitting:GlobalKinetics:wFitDataSel
	WAVE wFitDataGroup			= root:SPECTRA:Fitting:GlobalKinetics:wFitDataGroup
	
	WAVE/T TimeConstantsList		= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
	WAVE TimeConstantsSel			= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsSel
	NVAR gNCmpts					= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	
	DoWindow/K GlobalKineticsPanel
	Display /W=(196,65,993,838)/K=1  as "Global Kinetics Fitting Panel"
	DoWindow/C GlobalKineticsPanel
	CheckWindowPosition("GlobalKineticsPanel",196,65,993,938)
	ControlBar 400
	
	SetWindow GlobalKineticsPanel, hook(GlobalKineticsHook)=GlobalKineticsPanelHooks
	
	// Plot the first of the traces. 
	wFitDataSel[0] = 1
	PlotTheDataInFitPanel("GlobalKineticsPanel","root:SPECTRA:Fitting:GlobalKinetics")
	ColorTraces("GlobalKineticsPanel")
	
	// The List of the DATA to plot and fit
	ListBox FitDataListBox,mode= 4,pos={4,150},size={230,246}, proc=SelectTheDataToFit
	ListBox FitDataListBox,listWave=root:SPECTRA:Fitting:GlobalKinetics:wFitDataList
	ListBox FitDataListBox,selWave=root:SPECTRA:Fitting:GlobalKinetics:wFitDataSel
	
	// List displaying the Time Constants for each component
	ListBox TimeConstantsListBox1,mode= 4,pos={250,186},size={200,209}, fsize=11,widths={90,45,35},proc=GlobalKineticsListBox1
	ListBox TimeConstantsListBox1,listWave=root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
	ListBox TimeConstantsListBox1,selWave=root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsSel
	
	// List displaying the Spectral Amplitudes for each component
	ListBox TimeConstantsListBox2,mode= 4,pos={470,186},size={310,209}, fsize=11,widths={90,35,35,45,45},proc=GlobalKineticsListBox2
	ListBox TimeConstantsListBox2,listWave=root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeList
	ListBox TimeConstantsListBox2,selWave=root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
	
	SetVariable NCmptsSetVar,title="# Components ",pos={250,150},size={140,20},fsize=13,limits={1,Inf,1},proc=GlobalKineticsSetVars,value=gNCmpts
	
	Button GlobalKineticsTrialButton,pos={400,70},fColor=(32768,40777,65535),proc=GlobalKineticsButtonProcs,size={50,20},title="Trial"
	Button GlobalKineticsFitButton,pos={475,70},fColor=(65535,32768,32768),proc=GlobalKineticsButtonProcs,size={50,20},title="Fit"
	Button ComponentPlotButton,pos={660,163},proc=GlobalKineticsButtonProcs,size={50,18},fsize=11,title="Plot"
	
	// Display some results of fitting: The Chi-Squared
	ValDisplay ChiSqrDisplay title="\Z16Χ\M\Z14\S2",size={126,20},pos={545,65},fSize=12,format="%2.8f"
	SetControlGlobalVariable("","ChiSqrDisplay","root:SPECTRA:Fitting:GlobalKinetics","gChiSqr",2)
	
	String OldDF = getDataFolder(1)
	NewDataFolder/O/S root:SPECTRA:Plotting:GlobalKineticsPanel
	
		SetCommonPlotFormat("GlobalKineticsPanel","")
	
		AppendPlotAxisControls("GlobalKineticsPanel",1)
		
		AppendCursorControls("GlobalKineticsPanel",1)
		
		TransferPlotPreferences("GlobalKineticsPanel",1)
	
	SetDataFolder $(OldDF)
End


Function PlotConcatenatedData()

	WAVE Axis			= root:SPECTRA:Fitting:GlobalKinetics:GlobalAxis
	WAVE Data			= root:SPECTRA:Fitting:GlobalKinetics:GlobalData
	WAVE Fit			= root:SPECTRA:Fitting:GlobalKinetics:GlobalFit
	
	DoWindow GlobalConcatPlot
	if (!V_flag)
		Display /K=1/W=(35,44,1696,268) Fit,Data as "Global Fit Comparison"
		Legend/C/N=text0/J/F=0/A=MC "\\s(GlobalFit) GlobalFit\r\\s(GlobalData) GlobalData"
		ModifyGraph rgb(GlobalFit)=(0,0,65535)
		DoWindow /C GlobalConcatPlot
		DoWindow /F GlobalKineticsPanel
	endif
End

// *************************************************************
// ****		Housekeeping Display Panel Hooks to catch window kill events
// *************************************************************
Function GlobalKineticsPanelHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	String WindowName 	= H_Struct.winname
	Variable eventCode		= H_Struct.eventCode
	
	if (eventCode == 2) 	// Window kill
		// Save the current display range? 
		
		DoWindow /K GlobalConcatPlot
		return 0
	endif
End

Function PlotTheDataInFitPanel(WindowName,DataFolder)
	String WindowName,DataFolder
	
	WAVE /T wFitDataList 	= $(ParseFilePath(2,DataFolder,":",0,0) + "wFitDataList")
	WAVE wFitDataSel 		= $(ParseFilePath(2,DataFolder,":",0,0) + "wFitDataSel")
	WAVE wFitDataGroup 	= $(ParseFilePath(2,DataFolder,":",0,0) + "wFitDataGroup")
	
	NVAR gFitMin		= root:SPECTRA:Fitting:GlobalKinetics:gFitMin
	NVAR gFitMax		= root:SPECTRA:Fitting:GlobalKinetics:gFitMax
	
	String FirstTraceName, AssocWavesFolder = ""
	Variable PlotAllFlag = 0, AppendFlag = 0, ErrorsFlag = 1, RightFlag = 0, PlotvsTime=0, AssocWavesFlag = 1, PlotFlag
	Variable CsrA=NAN, CsrB=NAN
	
	if (CsrIsOnPlot("GlobalKineticsPanel","A"))
		CsrA 	= GetCursorPositionOrValue("GlobalKineticsPanel","A",0)
	else
		CsrA 	= gFitMin
	endif
	if (CsrIsOnPlot("GlobalKineticsPanel","B"))
		CsrB 	= GetCursorPositionOrValue("GlobalKineticsPanel","B",0)
	else
		CsrB 	= gFitMax
	endif

	FirstTraceName = PlotDataInWindow(WindowName, wFitDataList, wFitDataSel, wFitDataGroup, "blue", PlotAllFlag, AppendFlag, RightFlag, ErrorsFlag,PlotvsTime,AssocWavesFlag,AssocWavesFolder,"",0)

	if (strlen(FirstTraceName) > 0)
		if (numtype(CsrA) == 0)
			PlaceCursorOnTrace("GlobalKineticsPanel", FirstTraceName, "A", CsrA, 0)
		endif
		if (numtype(CsrB) == 0)
			PlaceCursorOnTrace("GlobalKineticsPanel", FirstTraceName, "B", CsrB, 0)
		endif
	endif
End

// ***************************************************************************
// **************** 			Global Kinetics calculations using OPTIMIZE method
// ***************************************************************************

Function CheckCfsNaNs()

	WAVE /T TCList		= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
	
	Variable i, value, NCfs=DimSize(TCList,0)
	
	for (i=0;i<NCfs;i+=1)
		value 	= str2num(TCList[i][1])
		if (numtype(value) != 0)
			return 0
		endif
	endfor
	
	return 1
End

Function TrialOrOptGlobalKinetics(FitFlag)
	Variable FitFlag
	
	NVAR gChiSqr		= root:SPECTRA:Fitting:GlobalKinetics:gChiSqr
	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	NVAR gConvolve		= root:SPECTRA:Fitting:GlobalKinetics:gConvolve
	WAVE Res			= root:SPECTRA:Fitting:GlobalKinetics:GlobalRes
	WAVE /T TCList		= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
	WAVE SASel			= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
	
	Variable i=0, NGlobalCfs, GoodFit, start, its, BSNIts = 5
	Variable ChiSqrStart = gChiSqr
	
	if (CheckCfsNaNs() == 0)
		DoAlert 0, "One or more coefficients undefined!"
		return 0
	endif
	
	// Work out once if we need to interpolate the data for convolution. 
	Variable FWHM 			= str2num(TCList[2][1])
	if (numtype(FWHM) == 0)
		gConvolve 		= (abs(FWHM) > 0.001) ? 1 : 0
	else
		FWHM 			= 0
		TCList[2][1] 	= "0"
		gConvolve 		= 0
	endif
	
	// Create the concatenated Data
	if (DataToGlobalKinetics(FitFlag,FWHM) == 0)
		return 0
	endif
	
	// Create the concatenated Coefficients
	NGlobalCfs 		= CreateGlobalKineticsCfs(FitFlag)
	WAVE Cfs		= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfs
	
	// Create a Hold wave
	Make /O/D/N=(NGlobalCfs) $("root:SPECTRA:Fitting:GlobalKinetics:GlobalHold") /WAVE=Hold
	Hold = 0
	
	start = datetime
	
	if (FitFlag==1)
		
		// Fill the Hold Wave
		CreateGlobalKineticsHold(Hold,gNCmpts,gNData)
		
		// Make a shorter wave only containing coefficients to be varied
		CreateOptimizationCfs(Hold,Cfs)
		WAVE CfsOpt 	= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfsOpt
		if (numpnts(CfsOpt) == 0)
			DoAlert 0, "No coefficients are allowed to vary!"
			return 0
		endif
		
//		return 0
		
		Print " "
		Print " **************************************************************************************"
		if (1) 	// This chooses NLLS rathern than Simulated Annealing
			Print "		... performing Global Fit to transient kinetics data, using Non-Linear Least Squares approach 	.... "
			if (gConvolve)
				Print "		... convolving the calculated traces with an the instrumental response function 	.... "
			endif
			
			BSNIts = 100
			
			do
				// Repeat the optimize routine until we no longer hit the maximum number of iterations
				// 	NOTE: The /T=tol option is important to avoid fits that don't seek to change any parameters 
				Optimize /Q/M={0,0} /X=CfsOpt /I=(BSNIts)/T=1e-7 OptimizeGlobalKinetics, Hold
				i += 1
				its += V_OptNumIters
			while((V_OptTermCode == 4) && (i < 10))
			
			Print "		... Finished optimization after",i,"  loops and a total of ",its,"iterations and",V_OptNumFunctionCalls,"function calls. Optimization took",(datetime - start),"seconds. "
			Print " 		... Optimization exit codes=",V_flag,V_OptTermCode,". Note that 788 indicates iteration limits reached; 791 indicates starting values near optimum."

		else
			Print "		... performing Global Fit to transient kinetics data, using Simulated Annealing approach 	.... "
		
			// Limit the ranges of the coefficients
			// MakeGlobalKineticsLimits(gNData,gNCmpts)
			WAVE GKLimits	= root:SPECTRA:Fitting:GlobalKinetics:GlobalLimits
			
			Optimize /M={3,0} /X=CfsOpt /Y=(1) /TSA={0, 0.1} /XSA=GKLimits OptimizeGlobalKinetics, Hold
		endif
		
		
		
		Print " 		... Chi-squared value at start =",ChiSqrStart,"Chi-squared value at end =",V_min
		if (ChiSqrStart<V_min)
			Print " **************************************************************************************"
			Print "		... Problem with optimization - Chi-Squared value increased! Keeping coefficients at their initial values. "
			return 0
		endif
			
		WaveStats /Q/M=1 CfsOpt
		
		if (V_numNaNs != 0)
			Print " **************************************************************************************"
			Print "		... Problem with optimization - NaNs introduced into coefficients! Keeping coefficients at their initial values. "
			return 0
		endif
		
		// The concatenated data waves
		WAVE GlobalAxis	= root:SPECTRA:Fitting:GlobalKinetics:GlobalAxis
		WAVE GlobalData	= root:SPECTRA:Fitting:GlobalKinetics:GlobalData
		
		Print "		... Final fitting routine to estimate the errors on fit parameters. "
		FuncFit FitGlobalKinetics CfsOpt GlobalData /X=GlobalAxis
		
		GoodFit 	= ReadOutOptimizationCfs(Hold,Cfs,CfsOpt,gNData,gNCmpts)
		
		UpdateTimeConstantCoefficients()
		UpdateComponentSpectralAmplitudes()
		
		if (GoodFit)
			// Supress randomizing Spectra Amplitudes for the next Trial or Fit
			SASel[][1]	= BitSet(SASel[p][1],4)
			gChiSqr 	= sum(Res)
			
//			DisplayGlobalKineticsCfs()
			UpdateComponentSpectralAmplitudes()
			UpdateTimeConstantCoefficients()
		else
		endif
		
	else
		// Trial: Calculate the spectrum without fitting. 
		gChiSqr 	= OptimizeGlobalKinetics(Hold,Cfs)
		Print "		... The calculated Chi-Squared is",gChiSqr
	endif
	
	PlotConcatenatedData()					// <--- perhaps no longer necessary to display this. 
	UpdateFitsAndResiduals()
	
End

// ***************************************************************************
// **************** 			The Global Kinetics Optimize function
// ***************************************************************************

// *** NOTE: Should we enforce SCALE FACTORS or COMPONENT SPECTRA to be POSITIVE? 
// The issue is that we probably want to have only POSITIVE or NEGATIVE component spectra

Function OptimizeGlobalKinetics(hold,CfsOpt)
	Wave hold, CfsOpt
	
	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	NVAR gConvolve		= root:SPECTRA:Fitting:GlobalKinetics:gConvolve
	NVAR gConvCenter	= root:SPECTRA:Fitting:GlobalKinetics:gConvCenter
	NVAR gPositiveAmpls	= root:SPECTRA:Fitting:GlobalKinetics:gPositiveAmpls
	
	WAVE Axis			= root:SPECTRA:Fitting:GlobalKinetics:GlobalAxis
	WAVE Data			= root:SPECTRA:Fitting:GlobalKinetics:GlobalData
	WAVE Fit				= root:SPECTRA:Fitting:GlobalKinetics:GlobalFit
	WAVE Res			= root:SPECTRA:Fitting:GlobalKinetics:GlobalRes
	WAVE Pulse			= root:SPECTRA:Fitting:GlobalKinetics:ConvolutionPulse

	// CfsAll is used to actually calculate the total spectrum. 
	// CfsOpt just contains the coefficients that are varied. 
	WAVE CfsAll			= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfsAll
	WAVE Cfs			= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfs
	WAVE SAPt			= root:SPECTRA:Fitting:GlobalKinetics:GlobalSAPointers
	WAVE Indices		= root:SPECTRA:Fitting:GlobalKinetics:GlobalIndices
	
	Variable i, j=0, k=0, pMin, pMax, dtau, tau, betta, pwsc, scale, FWHM, Center, FitArea1, FitArea2
	Variable index, sX, ampl, ampindex, iOffset, residual
	
	Variable PrintFlag=0
	Variable NGlobalCfs, pDTau, pOffset, pFWHM, pTaus, pScales, pAmps 	// Pointers to coefficients
	NGlobalCfs 	= GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
	
	// First, prepare a coefficients wave that combines held and non-held values
	// This is where positive constrains can be enforced and remembered in the evolving Optimization coefficents. 
	for (i=0;i<NGlobalCfs;i+=1)
		
		if (hold[i] == 0)
			// !*!*!* Do Not Constrain here
			// Constrain all Scale factors to be positive. 
//			if ((i > (pScales-1)) && (i < pAmps))
//				CfsOpt[k] 	= abs(CfsOpt[k])
//			endif

			// !*!*!* Constrain here if Global set
			// Constrain all Component Spectrum Amplitudes to be positive. 
			if ( (gPositiveAmpls==1) && (i > (pAmps-1)) )
				CfsOpt[k] 	= abs(CfsOpt[k])
			endif
			
			CfsAll[i] 	= CfsOpt[k]
			k += 1
		else
			CfsAll[i] 	= Cfs[i]
		endif
	endfor
	
////	//  Check whether we are using one set of Spectral Amplitudes for a subsequent Time Constant ...
////	for (j=0;j<gNCmpts;j+=1)
////		// SAPt = GlobalSAPointers, the zero-based index of Spectral Amplitudes to copy and scale. 
////		// This allows changes to fitted Spectral Amplitudes to be used by all appropriate Time Constants. 
////		sX 	= SAPt[j]
////		if (numtype(sX) == 0)
////			// ... and transfer within the GlobalCfsAll coefficients wave if so. 
//////			CfsAll[pAmps + j*gNData,pAmps + (j+1)*gNData] 	= CfsAll[p - (j-sX)*gNData]			// This this is one point too many on the left. YES
////			CfsAll[pAmps + j*gNData,pAmps + (j+1)*gNData - 1] 	= CfsAll[p - (j-sX)*gNData]
////		endif
////	endfor
	
	// Lookup a constant time offset
	dtau 	= CfsAll[pDTau]
	
	// Look up a constant (t>0) intensity offset
	iOffset 	= CfsAll[pOffset]
	
	// Set the fit to zero? No! Set the fit to the OFFSET
	Fit = iOffset
	
	for (i=0;i<gNData;i+=1)
		// Find the point range for this data set
		pMin 	= Indices[2*i]
		pMax 	= Indices[2*i+1]
		
		for (j=0;j<gNCmpts;j+=1)
			// Each component has its own time constant, tau ...
			tau 		= CfsAll[pTaus+2*j]
			
			// ... a stretching exponent beta ...
			
			// ** NOTE on the stretching exponent. To avoid the tails of one decay affecting the decay an order of magnitude larger, 
			// 	constrain the minimum beta to be BetaMin
			betta 	= max(BetaMin,CfsAll[pTaus+2*j+1])			// <--- for stretched exponentials
			
			// If we are fitting a powerlaw, then this coefficient is a scale factor
			pwsc	= CfsAll[pTaus+2*j+1]							// <--- for power laws
			
			// !*!*!* Do Not Constrain here
			// ... A scale factor ... constrained above to be positive 
//			scale 	= abs(CfsAll[pScales+j])
			scale 	= CfsAll[pScales+j]
						
			// ... and an amplitude that varies with the data set (wavelength) ...
			// .. which CANNOT be forced to be positive because of bleaches. 
//			ampl 	= CfsAll[pAmps + (j*gNData) + i]
			
			sX 		= SAPt[j]
			// !*!*!* Do Constrain here
			if (gPositiveAmpls==1)
				ampl 	= abs(CfsAll[pAmps + (sX*gNData) + i])
			else
				ampl 	= CfsAll[pAmps + (sX*gNData) + i]
			endif
			
			// Add this exponential decay - UNLESS a negative time constant is used ... 
			if (tau > 0)
				Fit[pMin,pMax] += (Axis[p] >= dtau) ? scale * ampl * exp(-((Axis[p]-dtau)/tau)^betta) : 0
			else
				// ... in which case MULTIPLY a power-law decay that is SHIFTED relative to the zero point 
				Fit[pMin,pMax] *= (Axis[p] >= dtau) ? ampl * (Axis[p]+pwsc)^tau : 0
			endif
		endfor
	endfor
	
	if (gConvolve)	// Convolve the calculated fit with a Gaussian
		FWHM 	= CfsAll[pFWHM]
		Pulse 	= Gauss(x,gConvCenter,FWHM/sqrt(2))
		
		FitArea1 	=  area(Fit)
		Convolve /A Pulse, Fit
		FitArea2 	=  area(Fit)
		
		Fit *= (abs(FitArea1)/abs(FitArea2))
	endif
	
	// The optimization target is to minimize the sum of the Chi-Squared. 
	Res[] 		= (Data[p] - Fit[p])^2
	residual 	= sum(Res)
	
	return residual
End
// ***************************************************************************
// **************** 			The Global Kinetics FITTING function
// ***************************************************************************

// !*!**!* NOTE - this is essentially a copy of OptimizeGlobalKinetics and the annotations are more complete there. 
Function FitGlobalKinetics(w, ywv, xwv) : FitFunc
	Wave w, ywv, xwv
	
	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	NVAR gConvolve		= root:SPECTRA:Fitting:GlobalKinetics:gConvolve
	NVAR gConvCenter	= root:SPECTRA:Fitting:GlobalKinetics:gConvCenter
	
	WAVE Res			= root:SPECTRA:Fitting:GlobalKinetics:GlobalRes
	WAVE Pulse			= root:SPECTRA:Fitting:GlobalKinetics:ConvolutionPulse
	WAVE Hold			= root:SPECTRA:Fitting:GlobalKinetics:GlobalHold

	WAVE CfsAll			= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfsAll
	WAVE Cfs			= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfs
	WAVE SAPt			= root:SPECTRA:Fitting:GlobalKinetics:GlobalSAPointers
	WAVE Indices		= root:SPECTRA:Fitting:GlobalKinetics:GlobalIndices
	
	Variable i, j=0, k=0, pMin, pMax, dtau, tau, betta, pwsc, scale, FWHM, Center, FitArea1, FitArea2
	Variable index, sX, ampl, ampindex, iOffset, residual
	
	Variable PrintFlag=0
	Variable NGlobalCfs, pDTau, pOffset, pFWHM, pTaus, pScales, pAmps 	// Pointers to coefficients
	NGlobalCfs 	= GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
	
	// First, prepare a coefficients wave that combines held and non-held values
	for (i=0;i<NGlobalCfs;i+=1)
		if (Hold[i] == 0)
			CfsAll[i] 	= w[k]
			k += 1
		else
			CfsAll[i] 	= Cfs[i]
		endif
	endfor
	
	//  Check whether we are using one set of Spectral Amplitudes for a subsequent Time Constant ...
	// *!*!*! CHANGE APPROACH !*!*!*
	// Would be faster and possible more stable NOT to move coefficient values around inside a fit function
//	for (j=0;j<gNCmpts;j+=1)
//		sX 	= SAPt[j]
//		if (numtype(sX) == 0)
//			// ... and transfer within the GlobalCfsAll coefficients wave if so. 
//			CfsAll[pAmps + j*gNData,pAmps + (j+1)*gNData - 1] 	= CfsAll[p - (j-sX)*gNData]
//		endif
//	endfor
	
	// Lookup a constant time offset
	dtau 	= CfsAll[pDTau]
	
	// Look up a constant (t>0) intensity offset
	iOffset 	= CfsAll[pOffset]
	
	// Set the fit to offset
	ywv = iOffset
	
	for (i=0;i<gNData;i+=1)
		// Find the point range for this data set
		pMin 	= Indices[2*i]
		pMax 	= Indices[2*i+1]
		
		for (j=0;j<gNCmpts;j+=1)
			// Each component has its own time constant, tau ...
			tau 		= CfsAll[pTaus+2*j]
			
			// ... a stretching exponent beta ... 
			// 	To avoid the tails of one decay affecting the decay an order of magnitude larger, constrain the minimum beta to be BetaMin
			betta 	= max(BetaMin,CfsAll[pTaus+2*j+1])			// <--- for stretched exponentials
			
			// If we are fitting a powerlaw, then this coefficient is a scale factor
			pwsc	= CfsAll[pTaus+2*j+1]							// <--- for power laws
			
			// !*!*!* Do Not Constrain here
			// ... , an overall POSITIVE  scale factor (usually unity) ...
//			scale 	= abs(CfsAll[pScales+j])
			scale 	= CfsAll[pScales+j]
			
			// ... and an amplitude that varies with the data set (wavelength) ...
			sX 		= SAPt[j]
			// !*!*!* Do Constrain here
			ampl 	= abs(CfsAll[pAmps + (sX*gNData) + i])
			
			// Add this exponential decay - UNLESS a negative time constant is used. Then do a power-law fit
			if (tau > 0)
				ywv[pMin,pMax] += (xwv[p] >= dtau) ? scale * ampl * exp(-((xwv[p]-dtau)/tau)^betta) : 0
			else
				ywv[pMin,pMax] *= (xwv[p] >= dtau) ? ampl * (xwv[p]+pwsc)^tau : 0
			endif
		endfor
	endfor
			
	if (gConvolve)	// Convolve the calculated fit with a Gaussian
		FWHM 	= CfsAll[pFWHM]
		Pulse 	= Gauss(x,gConvCenter,FWHM/sqrt(2))
		
		FitArea1 	=  area(ywv)
		Convolve /A Pulse, ywv
		FitArea2 	=  area(ywv)
		
		ywv *= (abs(FitArea1)/abs(FitArea2))
	endif
End


// ***************************************************************************
// **************** 			SAVING the COEFFICIENTS 
// ***************************************************************************

// 

Function SaveGlobalKineticsCoefficients()

	// Save the coefficients and errors to disk if requested
//	if (SaveToDiskFlag == 1)
//		if (OverWriteFlag == 1)
//			Save /O/C/P=home CoefficientValues as SampleCoefsName+".ibw"
//			Save /O/C/P=home CoefficientSigmas as SampleCoefsSigmasName+".ibw"
//		else
//			Save /C/P=home CoefficientValues as SampleCoefsName+".ibw"
//			Save /O/C/P=home CoefficientSigmas as SampleCoefsSigmasName+".ibw"
//		endif
//	endif

End

// ***************************************************************************
// **************** 			HOLDING COEFFICIENTS 
// ***************************************************************************

// This creates the OPTIMIZATION HOLD WAVE
Function CreateGlobalKineticsHold(hold,NCmpts,NData)
	Wave hold
	Variable NCmpts,NData
	
	WAVE TCSel			= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsSel
	WAVE SASel			= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
	
	Variable PrintFlag=0, HoldTrue, ScaleTrue
	
	Variable i, pDTau, pOffset, pFWHM, pTaus, pScales, pAmps	// Pointers to coefficients
	GlobalKineticsPointers(NData,NCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
	
	// Hold or vary the manually adjusted parameters (for the exponential or powerlaw decays)
	hold[0,pScales-1] 	= (BitTest(TCSel[p][2],4))
	
	// Start by holding all the component Scale factors and Amplitudes
	hold[pScales,] 		= 1
	
	// Now check each Component 
	for (i=0;i<NCmpts;i+=1)
		
		ScaleTrue 	= BitTest(SASel[i][3],4)
		HoldTrue 	= BitTest(SASel[i][2],4)
		
		if (ScaleTrue && HoldTrue)					// Keep both Scale and Amplitudes held for this component
		
		elseif (ScaleTrue && !HoldTrue)				// Allow the Scale to vary, keeping the Amplitudes fixed
			hold[pScales + i] 	= 0
			
		elseif (!ScaleTrue && !HoldTrue)			// Allow Amplitudes to vary, and keep the Scale fixed
			hold[pAmps + (i*Ndata),pAmps + (i*NData) + NData -1] 		= 0
			
		endif

	endfor
End

// This creates the OPTIMIZATION version of the  GLOBAL KINETICS COEFFICIENTS WAVE
// This wave only contains coefficients to be varied. 
Function CreateOptimizationCfs(hold,Cfs)
	Wave hold,Cfs

	Variable i, k=0, NGlobalCfs	= numpnts(Cfs)
	
	Variable NHeld 		= sum(hold)
	Variable NVaried 	= numpnts(Cfs)-NHeld
	
	Make /O/D/N=(NVaried) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfsOpt") /WAVE=CfsOpt
	
	for (i=0;i<NGlobalCfs;i+=1)
		if (hold[i] == 0)
			CfsOpt[k] = Cfs[i]
			k+=1
		endif
	endfor
End

// ***************************************************************************
// **************** 			COEFFICIENTS Before Fitting
// ***************************************************************************

Function CreateGlobalKineticsCfs(FitFlag)
	Variable FitFlag
	
	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	WAVE /T TCList	= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
	WAVE SASel 		= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
	WAVE /T SAList 	= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeList
	
	String CmptName, RndCmpts=""
	Variable i, k, scaleFactor, cmptIndex, NGlobalCfs, AxisMin,  AxisMax, RndFlag, RndMsg=0, PrintFlag=0
		
	Variable pDTau, pOffset, pFWHM, pTaus, pScales, pAmps	// Pointers to coefficients
	NGlobalCfs 	= GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
	
	GetAxis /Q/W=GlobalKineticsPanel left
	AxisMax = max(abs(V_max),abs(V_min))
	
	Make /O/D/N=(NGlobalCfs) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfs") /WAVE=Cfs
	Make /O/D/N=(NGlobalCfs) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfsAll") /WAVE=CfsAll
	Make /O/T/N=(NGlobalCfs) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfsLgd") /WAVE=CfsLgd
	
	GlobalKineticsLegend(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,CfsLgd)
	
	// Pointers for a Component to use Scaled Reference Spectral Amplitudes by with a different Time Constant
	Make /O/D/N=(gNCmpts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalSAPointers") /WAVE=SAPt
	SAPt 	= NaN
	
	// Read the starting Offsets and Taus into the global coefficient wave
	Cfs[pDTau,pScales-1] 	= str2num(TCList[p - (pDTau)][1])		// Note that pDTau = 0
	
	Variable KeepTrue, HoldTrue, ScaleTrue, SAPtrValid
	
	// Now check each Component 
	for (i=0;i<gNCmpts;i+=1)
		
		KeepTrue 	= BitTest(SASel[i][1],4)		// Not needed
		HoldTrue 	= BitTest(SASel[i][2],4)
		ScaleTrue 	= BitTest(SASel[i][3],4)
		SAPtrValid 	= numtype(str2num(SAList[i][5])) == 0
		
		// Create an individual component spectrum for each Time Constant. 
		CmptName 	= "root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+num2str(i+1) 	// Component indexes from UNITY not ZERO
		
		if (!WaveExists($CmptName) || (numpnts($CmptName) != gNData))
			Make /O/D/N=(gNData) $CmptName		// Create the Component 
			Cfs[pScales + i] 	= 1						// Set the starting Scale factor to Unity
			RndFlag 	= 1
		endif
		
		WAVE Component 	= $CmptName
		
		// Case 1: Randomize the Component if it's a new Component, requested by User, or contains NaNs
		if (RndFlag || !KeepTrue || (numtype(sum(Component)) != 0))
			Component = abs(gnoise(AxisMax/5))
//			Component = gnoise(AxisMax/5)/100
		 	RndMsg = 1; RndCmpts = RndCmpts + num2str(i)+","
		endif
		
		// Case 2a: This Component is using a Reference. 
		if (SAPtrValid)
			// Set the Component Pointer to the Reference Component if the Pointer is valid
			SAPt[i] 	= str2num(SAList[i][5])-1
			WAVE RefCmpt = $("root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+SAList[i][5])
			Component 	= RefCmpt
			
			if (PrintFlag)
				print " 	- Component number",i+1,"is set to component number",SAList[i][5]
			endif
			
		// Case 2b: This Component is NOT using a Reference. 
		else
			// Set the Component Pointer to itself for the Optimization routines
			SAPt[i] 	= i
		endif
		
		// Case 3: If the Component already exists and has the right number of points, do nothing
			
		// Read the starting Spectral Amplitudes into the Global Kinetics coefficients from the individual Component
		Cfs[pAmps + i*gNData, pAmps + (i+1)*gNData] 	= Component[p - (pAmps + i*gNData)]
		
	endfor
	
	if (RndMsg)
		Print " 			... Randomizing the wavelength-dependent amplitudes of the spectral components",RndCmpts
	endif
	
	return NGlobalCfs
End



// ***************************************************************************
// **************** 			COEFFICIENTS After Fitting
// ***************************************************************************

// This transfers the OPTIMIZED coefficients into the GLOBAL KINETICS COEFFICIENTS WAVE
Function ReadOutOptimizationCfs(hold,Cfs,CfsOpt,NData,NCmpts)
	Wave hold,Cfs,CfsOpt
	Variable NData,NCmpts
	
	// Pointers to the Spectral Amplitude
	WAVE SAPt			= root:SPECTRA:Fitting:GlobalKinetics:GlobalSAPointers
	WAVE SASel 		= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
	
	Variable i, k=0, ScaleFactor, ScaleTrue, HoldTrue, SAPtrValid, sX, NGlobalCfs, PrintFlag=0
	
	Variable pDTau, pOffset, pFWHM, pTaus, pScales, pAmps	// Pointers to coefficients
	NGlobalCfs 	= GlobalKineticsPointers(NData,NCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
	
	// First update ANY optimized coefficients. 
	for (i=0;i<NGlobalCfs;i+=1)
		if (hold[i] == 0)
			Cfs[i] = CfsOpt[k]
			k+=1
		endif
	endfor
	
	// Now check each Component 
	for (i=0;i<NCmpts;i+=1)
		
		ScaleTrue 	= BitTest(SASel[i][3],4)
		HoldTrue 	= BitTest(SASel[i][2],4)
		
		// (Optional) pointer to a Reference Component
		sX 				= SAPt[i]
		SAPtrValid 	= numtype(sX) == 0
		
		// Look up this Component scale factor
		ScaleFactor 		= Cfs[pScales + i]
		
		if (ScaleTrue && HoldTrue)					// Both Scale and Amplitudes were held for this component, so do nothing. 
		
		elseif (ScaleTrue && !HoldTrue)				// Allowed the Scale to vary, keeping the Amplitudes fixed
		
			if (numtype(sX) == 0)					// Case 1: This Component is a scaled version of Reference Component
				
				// Copy the UNSCALED Amplitudes from the sX'th Component to this jth Component within the GlobalCfs wave
				Cfs[pAmps + i*NData,pAmps + (i+1)*NData - 1] 	= Cfs[p - (i-sX)*NData]
			
			else 											// Case 2: This Component is Independent, so rescale the Amplitudes and reset Scale to 1
			
				// Rescale the Amplitudes ... 
				Cfs[pAmps + i*NData,pAmps + (i+1)*NData - 1] 	= ScaleFactor * Cfs[p]
				// ... and reset the Scale to 1
				Cfs[pScales + i] 	= 1
				
			endif
			
		elseif (!ScaleTrue && !HoldTrue)			// Allow Amplitudes to vary, and keep the Scale fixed. The best-fit Amplitudes were already updated above
			
		endif
	endfor
	
	return 1
End


// ***************************************************************************
// **************** 			Spectral Components After Fitting
// ***************************************************************************

Function UpdateComponentSpectralAmplitudes()

	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	
	Variable i, j, dtau, tau, ampl, PrintFlag=0
	
	Variable pDTau, pOffset, pFWHM, pTaus, pScales, pAmps // Pointers to coefficients
	GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus, pScales, pAmps,PrintFlag)
	
	WAVE GlobalCfs 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfs")
	
	for (i=0;i<gNCmpts;i+=1)
		// Component indexes start from UNITY not ZERO
		WAVE Component 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+num2str(i+1))
		
		Component[] 		= GlobalCfs[pAmps + i*gNData + p]
	endfor
End

// This UPDATES the SPECTRAL AMPLITUDES and List Box display of coefficients
Function UpdateTimeConstantCoefficients()
	
	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	WAVE /T TCList		= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
	
	Variable i, NGlobalCfs, PrintFlag=0
	
	Variable pDTau, pOffset, pFWHM, pTaus, pScales, pAmps	// Pointers to coefficients
	NGlobalCfs 	= GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
	
	WAVE Cfs 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfs")
	
	// Read the best-fit offsets and taus into ListBox wave for display
	for (i=0;i<(3+2*gNCmpts);i+=1)
			TCList[i][1] = num2str(Cfs[pDTau + i])
	endfor
	
//	// Read the best-fit the spectral amplitudes for each component. 
//	for (i=0;i<gNCmpts;i+=1)
//		// Enforce starting component indexes from UNITY not ZERO
//		WAVE Component 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+num2str(i+1))
//		Component[] 		= Cfs[pAmps + i*gNData + p]
//	endfor
End

Function PlotSpectralComponents()

	WAVE SASel			= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
	WAVE CmptAxis 	= root:SPECTRA:Fitting:GlobalKinetics:CmptAxis
	
	Variable i, n=0, newplot=1, NCmpts = DimSize(SASel,0)
	
	for (i=0;i<NCmpts;i+=1)
		if (BitTest(SASel[i][4],4))
		
			// Enforce starting component indexes from UNITY not ZERO
			WAVE CmptSpectrum 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+num2str(i+1))
			
			if (newplot)
				if (!WaveExists(CmptAxis))
					Make /D/N=(DimSize(CmptSpectrum,0)) $("root:SPECTRA:Fitting:GlobalKinetics:CmptAxis") 
					WAVE CmptAxis = root:SPECTRA:Fitting:GlobalKinetics:CmptAxis
					CmptAxis[] = p
				endif
				if (DimSize(CmptAxis,0) != DimSize(CmptSpectrum,0))
					Redimension /N=(DimSize(CmptSpectrum,0)) CmptAxis
				endif
				DoWindow CmptAxisTable
				if (!V_flag)
					Edit /K=1/W=(358,733,554,996) CmptAxis as "Component Axis"
					DoWindow /C CmptAxisTable
					ModifyTable format(Point)=1,alignment(CmptAxis)=1,width(CmptAxis)=178,title(CmptAxis)="Please enter wavelength values"
					ModifyTable showParts=0xF7
				endif
				Display /K=1/W=(347,439,703,706) CmptSpectrum vs CmptAxis
				newplot = 0
			else
				AppendToGraph CmptSpectrum vs CmptAxis
			endif
			SASel[i][4]	= BitClear(SASel[i][4],4)
		endif
	endfor
	if (!newplot)
		ModifyGraph mode=4
		ColorPlotTraces()
		AddLegend()
	endif
End


// ***************************************************************************
// **************** 			Transfer DATA between Global and Individual waves
// ***************************************************************************

Function DataToGlobalKinetics(FitFlag,FWHM)
	Variable FitFlag, FWHM

	// These are needed to look up the names and locations of the input data. 
	WAVE/T wFitList	= root:SPECTRA:Fitting:GlobalKinetics:wFitDataList
	WAVE wFitGroup	= root:SPECTRA:Fitting:GlobalKinetics:wFitDataGroup
	
	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	NVAR gConvolve		= root:SPECTRA:Fitting:GlobalKinetics:gConvolve
	NVAR gConvCenter	= root:SPECTRA:Fitting:GlobalKinetics:gConvCenter
	NVAR gFitMin		= root:SPECTRA:Fitting:GlobalKinetics:gFitMin
	NVAR gFitMax		= root:SPECTRA:Fitting:GlobalKinetics:gFitMax
	
	String IndexStr="", KineticsName
	Variable i, j, k=0, nPts=0, MinStep, SensibleMin, ConvMin, ConvMax, ConvStep, ConvNPts, ConcatNPts, CursorNPts
	
	if (FitFlag)
		if (!CsrIsOnPlot("GlobalKineticsPanel","A") || !CsrIsOnPlot("GlobalKineticsPanel","B"))
			DoAlert 1, "Abort and narrow fit range?"
			if (V_flag)
				abort
			endif
		endif
	endif
	
	// If the cursors are not on the plot, these will be set to 0 and Inf. 
	gFitMin		= min(GetCursorPositionOrValue("GlobalKineticsPanel","A",0),GetCursorPositionOrValue("GlobalKineticsPanel","B",0))
	gFitMax		= max(GetCursorPositionOrValue("GlobalKineticsPanel","A",0),GetCursorPositionOrValue("GlobalKineticsPanel","B",0))
	if ((numtype(gFitMin) != 0) || (numtype(gFitMax) != 0))
		DoAlert 0, "Please put the cursors on the plot"
		return 0
	endif
	
	// Make all the concatenated data waves
	Make /O/D/N=(0) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalAxis") /WAVE=Axis
	Make /O/D/N=(0) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalData") /WAVE=Data
	Make /O/D/N=(0) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalFit") /WAVE=Fit
	Make /O/D/N=(0) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalRes") /WAVE=Resids
	
	// A point index lookup wave. Works OK for both regular and convolved data
	Make /O/D/N=(2*gNData) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalIndices") /WAVE=Indices
	
	// A constraints wave - not likely to be used as SA approach is tricky
	Make /O/T/N=(gNCmpts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalConstraints") /WAVE=Constraints
	
	if (gConvolve)
		// 	Separate waves required for convolving the data with the pump pulse width
		WAVE KineticsAxis 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[0]) +":"+ ReplaceString("_data",wFitList[0],"_axis" ))
		ConvMin 	= KineticsAxis[gFitMin]
		ConvMax 	= KineticsAxis[gFitMax]
		MinStep 	= abs(CheckConstantStep(KineticsAxis,0.00000001,0))
		
		// Determine the data range over which to apply the fit and the convolution. 
		// Need to interpolate the data onto a constant-step axis. 
		ConvStep 		= (ConvMin > 0) ? (min(ConvMin,MinStep)) : MinStep
		SensibleMin 	= trunc(10*log(ConvMin+1))/20
		ConvStep 		= max(SensibleMin,0.05)
		ConvNPts 		= 1 + trunc((ConvMax-ConvMin)/ConvStep)
		gConvCenter 	= ConvMin + (ConvMax-ConvMin)/2
		
		// The individual input data interpolated onto a constant step axis
		Make /O/D/N=(ConvNPts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"ConvolutionAxis2") /WAVE=ConvAxis2
		Make /O/D/N=(ConvNPts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"ConvolutionData2") /WAVE=ConvData2
		Make /O/D/N=(ConvNPts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"ConvolutionPulse") /WAVE=ConvPulse
		
		ConvAxis2[] 	= ConvMin + p * ConvStep
		SetScale /P x, ConvMin,  ConvStep, ConvAxis2, ConvData2, ConvPulse
		
		ConcatNPts 	= 	gNData * ConvNPts
		Redimension /N=(ConcatNPts) Axis, Data, Fit, Resids
	
		// The cursor-selected range of the individual input data, not on a constant step axis
		CursorNPts = (gFitMax - gFitMin)+1
		Make /O/D/N=(CursorNPts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"ConvolutionAxis1") /WAVE=ConvAxis1
		Make /O/D/N=(CursorNPts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"ConvolutionData1") /WAVE=ConvData1
		
		// Interpolate each kinetics data onto a common axis and transfer into the concatenated data wave
		for (i=0;i<gNData;i+=1)
			Indices[2*i] 	= k
			
			WAVE KineticsData 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ wFitList[i] )
			WAVE KineticsAxis 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_axis" ))
			ConvAxis1[] 		= KineticsAxis[p+gFitMin]
			ConvData1[] 		= KineticsData[p+gFitMin]
			
			Interpolate2 /T=1/I=3/X=ConvAxis2/Y=ConvData2 ConvAxis1, ConvData1
			
			Axis[k,k+ConvNPts] 	= ConvAxis2[p - k]
			Data[k,k+ConvNPts] 	= ConvData2[p - k]
			
			k += ConvNPts
			
			Indices[2*i+1] 	= k-1
		endfor
		
		// The convolution of the concatenated calculated curves occurs in the Optimization routine. 
	endif
	
	if (!gConvolve)
		// Transfer the (non-NaN) data into the concatenated data wave
		// 	*!*!*: We are now assuming all axes to be IDENTICAL
		for (i=0;i<gNData;i+=1)
			Indices[2*i] 	= k
			
			WAVE KineticsData 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ wFitList[i] )
			WAVE KineticsAxis 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_axis" ))
			nPts += DimSize(KineticsData,0)
			
			Redimension /N=(nPts) Axis, Data
			
			j = gFitMin
			do
				if (numtype(KineticsData[j]) == 0)		// Skip NaNs for fitting
					Axis[k] 	= KineticsAxis[j]
					Data[k] 	= KineticsData[j]
				k+=1
				endif
				
				j+=1
			while((j<numpnts(KineticsData)) && (j<=gFitMax))
			
			// This reduces the fit range for future fits if any trace does not reach the end. 
//			gFitMax = j-1
			
			Indices[2*i+1] 	= k-1
		endfor
	
		Redimension /N=(k) Axis, Data, Fit, Resids
	endif
End

// Save the fit results with the individual traces. 
Function UpdateFitsAndResiduals()
//Function FitsFromGlobalKinetics()

	// These are needed to look up the names and locations of the input data. 
	WAVE/T wFitList	= root:SPECTRA:Fitting:GlobalKinetics:wFitDataList
	WAVE wFitGroup	= root:SPECTRA:Fitting:GlobalKinetics:wFitDataGroup
	
	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	NVAR gConvolve		= root:SPECTRA:Fitting:GlobalKinetics:gConvolve
	NVAR gFitMin		= root:SPECTRA:Fitting:GlobalKinetics:gFitMin
	NVAR gFitMax		= root:SPECTRA:Fitting:GlobalKinetics:gFitMax
	
	Variable i, j, k=0, pMin, pMax, ConvNPts

	WAVE Axis 		= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalAxis")
	WAVE Data 		= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalData")
	WAVE Fit 		= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalFit")
	WAVE Resids 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalRes")
	WAVE Indices 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalIndices")
	
	// If we applied a convolution we need to interpolate back onto the original data axis. 
	if (gConvolve)
		WAVE ConvAxis1	= root:SPECTRA:Fitting:GlobalKinetics:ConvolutionAxis1
		WAVE ConvFit1		= root:SPECTRA:Fitting:GlobalKinetics:ConvolutionData1
		WAVE ConvAxis2	= root:SPECTRA:Fitting:GlobalKinetics:ConvolutionAxis2
		WAVE ConvFit2		= root:SPECTRA:Fitting:GlobalKinetics:ConvolutionData2
		ConvNPts 			= DimSize(ConvAxis2,0)
		
		for (i=0;i<gNData;i+=1)
			WAVE KineticsData 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ wFitList[i] )
			WAVE KineticsAxis 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_axis" ))	
			WAVE KineticsFit 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_fit" ))	
			WAVE KineticsRes 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_res" ))	
			
			ConvAxis2[] 	= Axis[p + i*ConvNPts]
			ConvFit2[]		= Fit[p + i*ConvNPts]
			
			Interpolate2 /T=1/I=3/X=ConvAxis1/Y=ConvFit1 ConvAxis2, ConvFit2
			
			KineticsFit = NAN
			KineticsFit[gFitMin,gFitMax] 	= ConvFit1[p-gFitMin]
			KineticsRes = NAN
			KineticsRes[gFitMin,gFitMax] 	= KineticsData[p] - ConvFit1[p-gFitMin]
		endfor
	endif
	
	if (!gConvolve)
		for (i=0;i<gNData;i+=1)
			WAVE KineticsData 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ wFitList[i] )
			WAVE KineticsAxis 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_axis" ))	
			WAVE KineticsFit 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_fit" ))	
			WAVE KineticsRes 	= $("root:SPECTRA:Data:Load" + num2str(wFitGroup[i]) +":"+ ReplaceString("_data",wFitList[i],"_res" ))	
			
			KineticsFit = NAN
			KineticsRes = NAN
			
			k = -1
			pMin 	= Indices[2*i]
			pMax 	= Indices[2*i+1]
			for (j=pMin;j<=pMax;j+=1)
				do
					k+=1
				while(KineticsAxis[k] < Axis[j])
				KineticsFit[k] 	= Fit[j]
				KineticsRes[k] 	= Data[j] - Fit[j]
			endfor
		endfor
	endif
End

// *************************************************************
// ****		Global Kinetics Fit Panel Controls
// *************************************************************
Function GlobalKineticsButtonProcs(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 		= B_Struct.ctrlName
	String WindowName 	= B_Struct.win
	Variable eventCode 		= B_Struct.eventCode
	
	if (eventCode != 2)	// Mouse up after pressing
		return 0
	endif
	
	if (cmpstr("GlobalKineticsFitButton",ctrlName) == 0)
		TrialOrOptGlobalKinetics(1)
	elseif (cmpstr("GlobalKineticsTrialButton",ctrlName) == 0)
		TrialOrOptGlobalKinetics(0)
	elseif (cmpstr("ComponentPlotButton",ctrlName) == 0)
	
		PlotSpectralComponents()
	endif
End

Function GlobalKineticsSetVars(SV_Struct) 
	STRUCT WMSetVariableAction &SV_Struct 
	
	String WindowName = SV_Struct.win
	String ctrlName 	= SV_Struct.ctrlName
	Variable varNum 	= SV_Struct.dval
	
	Variable eventCode 	= SV_Struct.eventCode
	if (eventCode == -1)
		return 0
	endif
	
	 SetNumGlobalKineticsCmpts()
End 

Function GlobalKineticsListBox1(s) : ListBoxControl
	STRUCT WMListboxAction &s
	
	Variable event 			= s.eventCode
	WAVE/T/Z listWave 	= s.listWave

	String entryStr
	
	if (event==7)
		entryStr = ListWave[s.row][s.col]
		if (numtype(str2num(entryStr)) != 0)
			entryStr = "0"
		endif
		ListWave[s.row][s.col] = num2str(str2num(entryStr))
	endif

	return 0
End

Function GlobalKineticsListBox2(s) : ListBoxControl
	STRUCT WMListboxAction &s
	
	Variable event 			= s.eventCode
	WAVE/T/Z listWave 	= s.listWave
	WAVE/Z selWave 		= s.selWave

	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
	
	// We are expecting entry to be an integer between 1 and gNCmpts
	Variable entry, BadEntry=0
	
	// User edited column 5
	if ((event==7) && (s.col == 5))
		entry 	= floor(str2num(ListWave[s.row][s.col]))
		if (numtype(entry) != 0)
			BadEntry=1
		elseif ((entry < 1) || (entry > gNCmpts))
			BadEntry=1
		elseif (entry == (s.row+1))
			BadEntry=1
		endif
		
		if (BadEntry)
			// Empty the cell
			ListWave[s.row][5]  	= ""
			// Probably not necessary to UNCHECK the Scale Spectral Amplitudes box. 
//			SelWave[s.row][3]		= BitClear(SelWave[s.row][3],4)
		else
			// Re-fill the cell and CHECK the Scale Spectral Amplitudes box. 
			ListWave[s.row][5]  	= num2str(entry)
			SelWave[s.row][3]		= BitSet(SelWave[s.row][3],4)
		endif
		
		OrderReferenceSpectra(ListWave,SelWave)
	endif
	
	// Modify Scale check box
	if ((event==13) && (s.col == 3))
		if (!BitTest(SelWave[s.row][3],4))
			// Cannot use another spectrum without scaling. 
			ListWave[s.row][5] 	= ""
		endif
	endif

	return 0
End

//	It is important to set the lowest index spectrum to be the reference so the Component Spectra are filled correctly. 
Function OrderReferenceSpectra(ListWave,SelWave)
	Wave /T ListWave
	Wave SelWave
	
	Variable i, sX, NSpectra=DimSize(ListWave,0)
	
	for (i=0;i<NSpectra;i+=1)
		sX 	= str2num(ListWave[i][5])
		if (sX > i)
			ListWave[sX][5] 	= num2str(i+1)
			SelWave[sX][3]		= BitSet(SelWave[sX][3],4)
			
			ListWave[i][5] 		= ""
			SelWave[i][3]		= BitClear(SelWave[i][3],4)
		endif
	endfor
End

Function SelectTheDataToFit(s) : ListBoxControl
	STRUCT WMListboxAction &s
	
	Variable row = s.row
	Variable col = s.col
	Variable event = s.eventCode
	String panelName = s.win
	
	WAVE/T/Z listWave 	= s.listWave
	WAVE/Z selWave 		= s.selWave
	
	Variable XMin,XMax,YMin,YMax,XLog,YLog
	
	String PanelFolder 	= "root:SPECTRA:Plotting:" + PanelName
	String DataFolder 	= "root:SPECTRA:Fitting:" + ReplaceString("Panel",panelName,"")
	NVAR gFixLeftAxis 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "gFixLeftAxis")
	
	if ((event==4) || (event==5))
	
		GetPlotDisplayRange(PanelName,XMin,XMax,YMin,YMax,XLog,YLog)
			PlotTheDataInFitPanel(PanelName,DataFolder)
		SetPlotDisplayRange(PanelName,XMin,XMax,YMin,YMax,XLog,YLog)
		
		ColorTraces(PanelName)
		if (!gFixLeftAxis)
			SetAxis /A=2/W=$panelName left
		endif
		
		ModifyGraph zero(left)=12,zeroThick(left)=1
	endif
	
	return 0
End

Function ApplyGlobalKineticsPlotPref(panelFolder)
	String panelFolder
	
//	NVAR gLogX 			= $(ParseFilePath(2,panelFolder,":",0,0) + "gLogX")
//	NVAR gLogYLeft 		= $(ParseFilePath(2,panelFolder,":",0,0) + "gLogYLeft")
//	
//	NVAR gPlotXMin 	= $(ParseFilePath(2,panelFolder,":",0,0) + "gPlotXMin")
//	NVAR gPlotXMax 	= $(ParseFilePath(2,panelFolder,":",0,0) + "gPlotXMax")
//	NVAR gPlotLeftMin 	= $(ParseFilePath(2,panelFolder,":",0,0) + "gPlotLeftMin")
//	NVAR gPlotLeftMax 	= $(ParseFilePath(2,panelFolder,":",0,0) + "gPlotLeftMax")
//	
//	
//	SetLogAxis("AXES_LogYLeftCheckBox",gLogYLeft)
//	SetLogAxis("AXES_LogXCheckBox",gLogX)
End









//Function FitGlobalKinetics(w, ywv, xwv) : FitFunc
//	Wave w, ywv, xwv
//	
//	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
//	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
//	NVAR gConvolve		= root:SPECTRA:Fitting:GlobalKinetics:gConvolve
//	NVAR gConvCenter	= root:SPECTRA:Fitting:GlobalKinetics:gConvCenter
//	
//	WAVE Res			= root:SPECTRA:Fitting:GlobalKinetics:GlobalRes
//	WAVE Pulse			= root:SPECTRA:Fitting:GlobalKinetics:ConvolutionPulse
//	WAVE Hold			= root:SPECTRA:Fitting:GlobalKinetics:GlobalHold
//
//	WAVE CfsAll		= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfsAll
//	WAVE CfsSave		= root:SPECTRA:Fitting:GlobalKinetics:GlobalCfsSave
//	WAVE SAPt			= root:SPECTRA:Fitting:GlobalKinetics:GlobalSAPointers
//	WAVE Indices		= root:SPECTRA:Fitting:GlobalKinetics:GlobalIndices
//	
//	Variable i, j=0, k=0, pMin, pMax, dtau, tau, betta, pwsc, scale, FWHM, Center, FitArea1, FitArea2
//	Variable index, sX, ampl, ampindex, iOffset, residual
//	
//	Variable PrintFlag=0
//	Variable NGlobalCfs, pDTau, pOffset, pFWHM, pTaus, pScales, pAmps 	// Pointers to coefficients
//	NGlobalCfs 	= GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
//	
//	// First, prepare a coefficients wave that combines held and non-held values
//	for (i=0;i<NGlobalCfs;i+=1)
//		if (Hold[i] == 0)
//			CfsAll[i] 	= w[k]
//			k += 1
//		else
//			CfsAll[i] 	= CfsSave[i]
//		endif
//	endfor
//	
//	//  Check whether we are using one set of Spectral Amplitudes for a subsequent Time Constant ...
//	// 	This allows changes to fitted Spectral Amplitudes to be used by all appropriate Time Constants. 
//	for (j=0;j<gNCmpts;j+=1)
//		sX 	= SAPt[j]
//		if (numtype(sX) == 0)
//			// ... and transfer within the GlobalCfsAll coefficients wave if so. 
//			CfsAll[pAmps + j*gNData,pAmps + (j+1)*gNData - 1] 	= CfsAll[p - (j-sX)*gNData]
//		endif
//	endfor
//	
//	// Lookup a constant time offset
//	dtau 	= CfsAll[pDTau]
//	
//	// Look up a constant (t>0) intensity offset (power-law only)
//	iOffset 	= CfsAll[pOffset]
//	
//	// Set the fit to zero
//	ywv = 0
//	
//	for (i=0;i<gNData;i+=1)
//		// Find the point range for this data set
//		pMin 	= Indices[2*i]
//		pMax 	= Indices[2*i+1]
//		
//		for (j=0;j<gNCmpts;j+=1)
//			// Each component has its own time constant, tau ...
//			tau 		= CfsAll[pTaus+2*j]
//			
//			// ... a stretching exponent beta ... 
//			// 	To avoid the tails of one decay affecting the decay an order of magnitude larger, constrain the minimum beta to be BetaMin
//			betta 	= max(BetaMin,CfsAll[pTaus+2*j+1])			// <--- for stretched exponentials
//			
//			// If we are fitting a powerlaw, then this coefficient is a scale factor
//			pwsc	= CfsAll[pTaus+2*j+1]							// <--- for power laws
//			
//			// ... , an overall POSITIVE  scale factor (usually unity) ...
//			scale 	= abs(CfsAll[pScales+j])
//			
//			// ... and an amplitude that varies with the data set (wavelength) ...
//			ampl 	= CfsAll[pAmps + (j*gNData) + i]
//			
//			// Add this exponential decay - UNLESS a negative time constant is used. Then do a power-law fit
//			if (tau > 0)
//				ywv[pMin,pMax] += (xwv[p] >= dtau) ? scale * ampl * exp(-((xwv[p]-dtau)/tau)^betta) : 0
//			else
//				ywv[pMin,pMax] += (xwv[p] >= dtau) ? iOffset + pwsc*xwv[p]^tau : 0
//			endif
//		endfor
//	endfor
//			
//	if (gConvolve)	// Convolve the calculated fit with a Gaussian
//		FWHM 	= CfsAll[pFWHM]
//		Pulse 	= Gauss(x,gConvCenter,FWHM/sqrt(2))
//		
//		FitArea1 	=  area(ywv)
//		Convolve /A Pulse, ywv
//		FitArea2 	=  area(ywv)
//		
//		ywv *= (abs(FitArea1)/abs(FitArea2))
//	endif
//End



// ***************************************************************************
// **************** 			Transfer COEFFICIENTS between Global and Individual waves
// ***************************************************************************

// This creates GlobalCfs, the GLOBAL KINETICS COEFFICIENTS WAVE 
// 	Read into GlobalCfs (1) the manually adjusted time constants and (2) the spectral components. 
//Function CreateGlobalKineticsCfs(FitFlag)
//	Variable FitFlag
//	
//	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
//	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
//	WAVE /T TCList	= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
//	WAVE SASel 		= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeSel
//	WAVE /T SAList 	= root:SPECTRA:Fitting:GlobalKinetics:SpectralAmplitudeList
//	
//	String CmptName, RndCmpts=""
//	Variable i, k, scaleFactor, cmptIndex, NGlobalCfs, AxisMin,  AxisMax, RndFlag, RndMsg=0, PrintFlag=0
//		
//	Variable pDTau, pOffset, pFWHM, pTaus, pScales, pAmps	// Pointers to coefficients
//	NGlobalCfs 	= GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
//	
//	GetAxis /Q/W=GlobalKineticsPanel left
//	AxisMax = max(abs(V_max),abs(V_min))
//	
//	Make /O/D/N=(NGlobalCfs) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfs") /WAVE=Cfs
////	Make /O/D/N=(NGlobalCfs) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfsSave") /WAVE=CfsSave
//	Make /O/D/N=(NGlobalCfs) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfsAll") /WAVE=CfsAll
//	
//	// This is a way of using a reference set of Spectral Amplitudes for many Time Constants. 
//	Make /O/D/N=(gNCmpts) $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalSAPointers") /WAVE=SAPt
//	SAPt 	= NaN
//	
//	// Read the starting offsets and taus into the global coefficient wave
//	Cfs[pDTau,pScales-1] 	= str2num(TCList[p - (pDTau)][1])
//	
//	// !*!*!*! Debugging - prevent tinkering with Scale values. 
//	if (!FitFlag)
//		// If we are performing a trial, leave them at the fitted values UNLESS they are undefined
//		Cfs[pScales,pAmps-1] 	= (Cfs[p] == 0) ? 1 : Cfs[p]
//	else
//		// The spectrum scale factors are set to unity if we are fitting - Necessary?
//		Cfs[pScales,pAmps-1] 	= 1
//	endif
//	
//	// Make the spectral amplitudes for each component. Several options: 
//	// 	-- Reset to random values
//	// 	-- Allow previous values to be reused
//	// 	-- Use the values for another Time Constant. 
//	
//	for (i=0;i<gNCmpts;i+=1)
//		
//		// Create an individual component spectrum for each Time Constant. 
//		// Enforce starting component indexes from UNITY not ZERO
//		CmptName 	= "root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+num2str(i+1)
//		
//		if (!WaveExists($CmptName) || (numpnts($CmptName) != gNData))
//			Make /O/D/N=(gNData) $CmptName
//			// Randomize the components if it's a new Component ...
//			RndFlag 	= 1
//		else
//			// ... if requested by the user ...
//			RndFlag 	= ((BitTest(SASel[i][1],4)) == 1) ? 0 : 1
//		endif
//		
//		 WAVE Component 	= $CmptName
//		 // ... or if the component spectrum contains any NaNs
//		 if ((RndFlag) || (numtype(sum(Component)) != 0))
//		 	RndMsg = 1
//			Component = gnoise(AxisMax/5)
//			RndCmpts = RndCmpts + num2str(i)+","
//		endif
//		
//		// Test whether we should be using a different Time Constant. 
//		WAVE RefCmpt 		= $("root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+SAList[i][5])
//		if (WaveExists(RefCmpt))
//			// Determine and record the starting index for the Reference Component
//			SAPt[i] 	= str2num(SAList[i][5])-1
//			
//			// Look up the Scale Factor appropriate to THIS component
//			scaleFactor 	= Cfs[pScales+i]
//			
//			Component 	= scaleFactor * RefCmpt
//			
//			if (PrintFlag)
//				print " 	- Component number",i+1,"is set to component number",SAList[i][5],"multiplied by",scaleFactor
//			endif
//		endif
//		
//		// Read the starting Spectral Amplitudes into the Global Kinetics coefficients from the individual Components. 
//		Cfs[pAmps + i*gNData, pAmps + (i+1)*gNData] 	= Component[p - (pAmps + i*gNData)]
//		
//	endfor
//	
//	// This is a backup of the 
////	CfsSave = Cfs
//	
//	if (RndMsg && PrintFlag)
//		Print " 			... Randomizing the wavelength-dependent amplitudes of the spectral components",RndCmpts
//	endif
//	
//	return NGlobalCfs
//End

//Function DisplayTimeConstantCoefficients()
//	
//	NVAR gNData		= root:SPECTRA:Fitting:GlobalKinetics:gNData
//	NVAR gNCmpts		= root:SPECTRA:Fitting:GlobalKinetics:gNCmpts
//	WAVE /T TCList		= root:SPECTRA:Fitting:GlobalKinetics:TimeConstantsList
//	
//	Variable i, NGlobalCfs, PrintFlag=0
//	
//	Variable pDTau, pOffset, pFWHM, pTaus, pScales, pAmps	// Pointers to coefficients
//	NGlobalCfs 	= GlobalKineticsPointers(gNData,gNCmpts,pDTau,pOffset,pFWHM,pTaus,pScales,pAmps,PrintFlag)
//	
//	WAVE Cfs 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"GlobalCfs")
//	
//	// Read the best-fit offsets and taus into ListBox wave for display
//	for (i=0;i<(3+2*gNCmpts);i+=1)
////		TCList[i][1] = num2str(Cfs[pDTau + i])
//
//		// Ensure that each stretching exponent is greater than BetaMin		
//		if ((i>pTaus) && (mod(i,2) == 0))
//			// !*!*!* Disable this while we play with powerlaws
////			TCList[i][1] = num2str(max(BetaMin,Cfs[pDTau + i]))
//			TCList[i][1] = num2str(Cfs[pDTau + i])
//		else
//			TCList[i][1] = num2str(Cfs[pDTau + i])
//		endif
//	endfor
//	
//	// Read the best-fit the spectral amplitudes for each component. 
//	for (i=0;i<gNCmpts;i+=1)
//		// Enforce starting component indexes from UNITY not ZERO
//		WAVE Component 	= $("root:SPECTRA:Fitting:GlobalKinetics:"+"CmptSpectrum"+num2str(i+1))
//		Component[] 		= Cfs[pAmps + i*gNData + p]
//	endfor
//End