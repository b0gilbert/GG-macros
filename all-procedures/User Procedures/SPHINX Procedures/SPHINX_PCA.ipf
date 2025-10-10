#pragma rtGlobals=3		// Use modern global access method and strict wave access.



// *************************************************************
// ****		Principle Component Analysis on selected region
// *************************************************************

// *************************************************************
// ****		SPECTRUM ANALYSIS on image ROI
// *************************************************************
	
Function ROIPCA(SPHINXStack,StackFolder,PanelFolder,PCAChoice)
	Wave SPHINXStack
	String StackFolder, PanelFolder
	Variable PCAChoice

	NVAR gSVDBin 		= root:SPHINX:SVD:gSVDBin
	NVAR gSVDX1 		= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDX2 		= root:SPHINX:SVD:gSVDRight
	NVAR gSVDY1 		= root:SPHINX:SVD:gSVDBottom
	NVAR gSVDY2 		= root:SPHINX:SVD:gSVDTop
	NVAR gROIMapFlag 	= root:SPHINX:SVD:gROIMappingFlag
	
	String StackName 	= NameOfWave(SPHINXStack)
	WAVE avStack 		= $(StackFolder + StackName + "_av")
	WAVE roiStack 		= $(StackFolder + StackName + "_av_roi")
	WAVE StackAxis  	= $("root:SPHINX:Stacks:"+StackName+"_axis")
	
	// DEBUGGING
	Variable NCmpts=2
	PCAChoice = 1
	
	if (!NVAR_Exists(gSVDX1))
		Print " *** Please select an ROI"
		return 0
	endif
	
	if ((!WaveExists(StackAxis)) || (StackAxis[0] == 0))
		DoAlert 0, "Please load a stack axis"
		return 0
	endif
	
	Variable PCAPtMin,PCAPtMax,PCANumPts, PCANumSpectra
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S root:SPHINX
	NewDataFolder /S/O root:SPHINX:XPCA

		FindPCAMatrixSize(StackAxis,roiStack,PCAPtMin,PCAPtMax,PCANumSpectra)
		if (PCANumSpectra == 0)
			DoAlert 0, "Zero pixels lay within marquee and ROI"
			return 0
		endif
		PCANumPts 	= PCAPtMax - PCAPtMin + 1
		
		// Check: I think the PCA routines expects the individual spectra to be placed into the COLUMNS
		// 	Regardless of the inputs, the operation expects that the number of rows in the resulting matrix is greater than or equal to the number of columns.
		// 		i.e., the number of Data Points in each Spectrum is greater than the number of Spectra to be Analyzed
		// 	The operation starts by creating the data matrix from the input wave(s). If you provide a list of 1D waves they become the columns of the data matrix. 
		Make /O/D/N=(PCANumPts,PCANumSpectra) PCAMatrix
		Make /O/D/N=(PCANumPts) PCAAxis
		PCAAxis 	= StackAxis[p + PCAPtMin]
		
		FillPCAMatrix(SPHINXStack,roiStack,PCAMatrix,PCAPtMin)
		
		if (PCAChoice == 1)
			Print " 	--- 	PRINCIPAL COMPONENT ANALYSIS of",PCANumSpectra,"spectra with ",PCANumPts,"points from",NameOfWave(SPHINXStack)
			
			Print " 		*** Analyzing",PCANumSpectra,"spectra with ",PCANumPts,"pointsfrom",NameOfWave(SPHINXStack),"for principle components"
			
	//		PCA /ALL/SRMT/SEVC PCAMatrix
			PCA /SCMT/SRMT/SEVC PCAMatrix
			WAVE M_R=M_R
			
//			PCADisplayPanel(PCAAxis,W_Eigen,M_R)
			
			Duplicate/O/R=[][0,(NCmpts-1)] M_R, PCACmpts, PCACmptsVM
			PCAFactorAndDisplay(PCAAxis,PCACmpts,PCACmptsVM)
			
		elseif (PCAChoice == 2)
			Print " 	--- 	INDEPENDENT COMPONENT ANALYSIS of",PCANumSpectra,"spectra with ",PCANumPts,"points from",NameOfWave(SPHINXStack),"with",NCmpts,"components."
			
			Duplicate/O/R=[][0,(NCmpts-1)] PCAMatrix, ICACmpts, ICACmptsVM
			
			ICA2DData(PCAMatrix,ICACmpts,NCmpts,$"")
		
			PCAFactorAndDisplay(PCAAxis,ICACmpts,ICACmptsVM)
		endif
	
	SetDataFolder $(OldDf)
End	


Function PCAFactorAndDisplay(StackAxis,CmptMatrix,CmptMatrixVM)
	Wave StackAxis,CmptMatrix,CmptMatrixVM
	
	String prefix=NameOfWave(CmptMatrix)[0,1]
	Variable i, NPts=DimSize(CmptMatrix,0), NCmpts=DimSize(CmptMatrix,1)
	
	DoWindow /K SPHINXComponents1
	DoWindow /K SPHINXComponents2
	
	// display the components
	Display/K=1
	for(i=0;i<NCmpts;i+=1)
		Make /O/D/N=(NPts) $("root:SPHINX:XPCA:"+prefix+num2str(i)) /WAVE=Cmpt
		Cmpt[] 	= CmptMatrix[p][i]
		AppendtoGraph Cmpt vs StackAxis
//		AppendToGraph ICACmpts[][i]
	endfor
	AddLegend()
	ColorPlotTraces()
	DoWindow /C SPHINXComponents1
	
	// apply Varimax analysis
	WM_VarimaxRotation(CmptMatrixVM,1e-7)
	Wave varimaxWave = M_varimax
	CmptMatrixVM = varimaxWave
	
	// display the rotated components
	Display/K=1
	for(i=0;i<NCmpts;i+=1)
		Make /O/D/N=(NPts) $("root:SPHINX:XPCA:"+prefix+"VM"+num2str(i)) /WAVE=Cmpt
		Cmpt[] 	= varimaxWave[p][i]
		AppendtoGraph  Cmpt vs StackAxis
//		AppendToGraph ICACmptsVM[][i]
	endfor
	AddLegend()
	ColorPlotTraces()
	DoWindow /C SPHINXComponents2
End

//		Duplicate/O/R=[][0,(useNEigenValues-1)] M_R, VarimaxInputWave
//		WM_VarimaxRotation(VarimaxInputWave,1e-7)
//		Wave varimaxWave
//		Display/K=1
//		for(i=0;i<useNEigenValues;i+=1)
//			AppendToGraph varimaxWave[][i]
//		endfor

Function PCADisplayPanel(StackAxis,PCAEigenValues,PCAResults)
	Wave StackAxis,PCAEigenValues,PCAResults
	
	// Need to kill the window to tidy up any previous waves. 
	DoWindow /K PCADisplay
	Display /K=1/W=(443,44,801,332)
	ControlBar 80
	DoWindow /C PCADisplay
	DoWindow/T PCADisplay,"PCA components"
	
	// Extract some PCA components with some guessed values. 
	ExtractPCAResults(StackAxis,PCAEigenValues,PCAResults,mean(PCAEigenValues)/2,6)
	
	ColorTraces("PCADisplay")
	Legend /W=PCADisplay/C/N=text0/F=0/A=MC
	
End

Function ExtractPCAResults(StackAxis,PCAEigenValues,PCAResults,EigenThresh,MaxExtracted)
	WAVE StackAxis,PCAEigenValues,PCAResults
	Variable EigenThresh, MaxExtracted
	
	Variable i, iMax, NSpec=DimSize(PCAEigenValues,0), NPts=DimSize(PCAResults,0)
	
	KillNNamedWaves("Eigen",NSpec)
	
	FindLevel /Q/P/R=[NSpec-1,0] PCAEigenValues, EigenThresh
	
	iMax 	= MaxExtracted
//	iMax 	= min(V_LevelX,MaxExtracted)
	
//	for (i=0;i<iMax;i+=1)
//		Make /O/D/N=(NPts) $("root:SPHINX:XPCA:Eigen"+num2str(i)) /WAVE=Cmpt
//		Cmpt[] 	= PCAResults[p][i]
//		AppendtoGraph /W=PCADisplay Cmpt vs StackAxis
//	endfor
	
	Duplicate/O/R=[][0,(iMax-1)] PCAResults, VarimaxInputWave
	WM_VarimaxRotation(VarimaxInputWave,1e-7)
	Wave varimaxWave = M_Varimax
	
	for (i=0;i<iMax;i+=1)
		Make /O/D/N=(NPts) $("root:SPHINX:XPCA:Eigen"+num2str(i)) /WAVE=Cmpt
		Cmpt[] 	= varimaxWave[p][i]
		AppendtoGraph /W=PCADisplay Cmpt vs StackAxis
	endfor
End


//		Duplicate/O/R=[][0,(useNEigenValues-1)] M_R, VarimaxInputWave
//		WM_VarimaxRotation(VarimaxInputWave,1e-7)
//		Wave varimaxWave
//		Display/K=1
//		for(i=0;i<useNEigenValues;i+=1)
//			AppendToGraph varimaxWave[][i]
//		endfor
		
		

Function FillPCAMatrix(SPHINXStack,roiStack,PCAMatrix,PCAPtMin)
	Wave SPHINXStack,roiStack,PCAMatrix
	Variable PCAPtMin
	
	WAVE energy 				= root:SPHINX:Browser:energy
	WAVE spectrum 			= root:SPHINX:Browser:specplot
	WAVE specbg 				= root:SPHINX:Browser:specbg
	WAVE specIo 				= root:SPHINX:Browser:spectrumIo
	//
	NVAR gLinBGFlag			= root:SPHINX:Browser:gLinBGFlag
//	NVAR gInvertSpectraFlag	= root:SPHINX:Browser:gInvertSpectraFlag
//	NVAR gReverseAxisFlag		= root:SPHINX:Browser:gReverseAxisFlag
	
// 2014-40-12 Added STXM vs PEEM normalization options
	NVAR gIoDivFlag			= root:SPHINX:Browser:gIoDivFlag
	NVAR gIoODImax 			= root:SPHINX:Browser:gIoODImax
	NVAR gIoDivChoice 			= root:SPHINX:Browser:gIoDivChoice
	
	Variable IoDivChoice 		= gIoDivFlag + 1
	if (NVAR_Exists(gIoDivChoice))
		IoDivChoice 	= gIoDivChoice
	endif
	
	NVAR gSVDBin 				= root:SPHINX:SVD:gSVDBin
	NVAR gSVDX1 				= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDX2 				= root:SPHINX:SVD:gSVDRight
	NVAR gSVDY1 				= root:SPHINX:SVD:gSVDBottom
	NVAR gSVDY2 				= root:SPHINX:SVD:gSVDTop
	
	NVAR gROIFlag 				= root:SPHINX:SVD:gROIMappingFlag
	gROIFlag 					= (WaveExists(roiStack)) ? gROIFlag : 0
	
	Variable i, j, m, n, nm, nSpec=0, nFail=0, mMax, nMax, BGMin, BGMax, NPixels=0
	Variable duration,timeRef = startMSTimer
	
	OpenProcBar("Finding principle components in  "+NameOfWave(SPHINXStack)); DoUpdate
	
	if (gLinBGFlag)	
		BGMin 	= min(pcsr(A, "StackBrowser#PixelPlot"),pcsr(B, "StackBrowser#PixelPlot"))
		BGMax 	= max(pcsr(A, "StackBrowser#PixelPlot"),pcsr(B, "StackBrowser#PixelPlot"))
	endif
	
	for (i=gSVDX1;i<gSVDX2;i+=gSVDBin)
		for (j=gSVDY1;j<gSVDY2;j+=gSVDBin)
			
			if (!gROIFlag || (gROIFlag && (roiStack[i][j]==0)))
				
				nm 		= 0
				mMax 	= (i+gSVDBin > gSVDX2) ? gSVDX2 : (i+gSVDBin)
				nMax 	= (j+gSVDBin > gSVDY2) ? gSVDY2 : (j+gSVDBin)
				
				spectrum = 0
				
				for (m=i;m < mMax;m+=1)
					for (n=j;n < nMax;n+=1)
						spectrum[] 	+= SPHINXStack[m][n][p]
						nm += 1
					endfor
				endfor
		
				if (nm > 0)
					
					spectrum /= nm
					
					// ----------------			NormalizeExtractedSpectrum() 		------------------------
					// *** 	This duplicates the spectrum extraction and normalization routine used by the Stack Browser. 
					// 			The difference is that the output is the wave called 'spectrum' not 'specplot'
//					if (gReverseAxisFlag)
//						Reverse spectrum
//					endif
//					if (gInvertSpectraFlag == 0)
//						spectrum *= -1
//					endif

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
					// ----------------			NormalizeExtractedSpectrum() 		------------------------
					
					PCAMatrix[][nSpec] = spectrum[p +PCAPtMin]
					
					nSpec += 1
				else
					nFail += 1
				endif
			endif
			
		endfor
		UpdateProcessBar((i-gSVDX1)/(gSVDX2-gSVDX1))
	endfor
	CloseProcessBar()
	
	// Normalize the spectra in each ROW - WRONG
//	MatrixOp /FREE PCAConditioned = NormalizeRows(PCAMatrix)
//	MatrixOp /O PCAMatrix = SubtractMean(PCAConditioned,2)

	if (1)
	// Normalize the spectra in each COLUMN
	MatrixOp /FREE PCAConditioned = NormalizeCols(PCAMatrix)
	MatrixOp /O PCAMatrix = SubtractMean(PCAConditioned,1)
	endif
	
//	You can pre-process the input data using MatrixOp with the SubtractMean, NormalizeRows, and NormalizeCols functions.
	
	if (nFail>0)
		Print " ######## seems to be a probelm here. "
	endif
	
	duration 	= stopMSTimer(timeRef)
	print " 		 ... took",duration/1000000,"s."
End

Function FindPCAMatrixSize(StackAxis,roiStack,PCAPtMin,PCAPtMax,PCANumSpectra)
	Wave StackAxis,roiStack
	Variable &PCAPtMin, &PCAPtMax,&PCANumSpectra
	
	NVAR gSVDEMin 	= root:SPHINX:SVD:gSVDEMin
	NVAR gSVDEMax 	= root:SPHINX:SVD:gSVDEMax
	
	NVAR gSVDBin 		= root:SPHINX:SVD:gSVDBin
	NVAR gSVDX1 		= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDX2 		= root:SPHINX:SVD:gSVDRight
	NVAR gSVDY1 		= root:SPHINX:SVD:gSVDBottom
	NVAR gSVDY2 		= root:SPHINX:SVD:gSVDTop
	
	NVAR gROIFlag 		= root:SPHINX:SVD:gROIMappingFlag
	gROIFlag 			= (gROIFlag==1 && WaveExists(roiStack)) ? gROIFlag : 0
	
	Variable i, j, PtMin, PtMax, NPCAPts
	
	if (gSVDEMin == gSVDEMax)
		DoAlert 0, "Please expand the SVD fit range"
		return 0
	endif
	
	// Find the indices of the fit range ...
	PtMin 	= BinarySearch(StackAxis,gSVDEMin)
	PtMax 	= BinarySearch(StackAxis,gSVDEMax)
	PCAPtMin 	= min(PtMin,PtMax)
	PCAPtMax 	= max(PtMin,PtMax)
	
	// Now quickly count the number of spectra that will be extracted. 
	PCANumSpectra = 0
	
	for (i=gSVDX1;i<gSVDX2;i+=gSVDBin)
		for (j=gSVDY1;j<gSVDY2;j+=gSVDBin)
			
			if (!gROIFlag || (gROIFlag && (roiStack[i][j]==0)))
				PCANumSpectra += 1
			endif
		endfor
	endfor
End
















