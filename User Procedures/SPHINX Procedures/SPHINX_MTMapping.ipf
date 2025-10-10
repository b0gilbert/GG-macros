#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Function MTROISVD(SPHINXStack,StackAxis, StackROI, StackName, StackFolder,PanelFolder)
	Wave SPHINXStack, StackAxis, StackROI
	String StackName, StackFolder, PanelFolder
	
	stopAllTimers()
	
	NewDataFolder /O/S root:SPHINX:MTSVD

	Variable nThreads 	= ThreadProcessorCount
	Variable FitTolerance = NumVarOrDefault("root:SPHINX:MTSVD:gFitTolerance",2)
	Prompt FitTolerance,"Fit tolerance", popup, "0.1;0.01;0.001;0.0001;0.00001"
	Variable NPortions = NumVarOrDefault("root:SPHINX:MTSVD:gNPortions",nThreads)
	Prompt NPortions, "Dividing the stack into portions"
	DoPrompt "Multi-thread Component Mapping", NPortions, FitTolerance
	if (V_flag)
		return 0
	endif
	
	Variable /G 	gFitTolerance 	= FitTolerance
	Variable /G gNPortions 		= NPortions

	Variable NumX	= DimSize(SPHINXStack,0)
	Variable NumY	= DimSize(SPHINXStack,1)
	Variable NumE	= DimSize(SPHINXStack,2)
	
	NVAR gROIMapFlag 	= root:SPHINX:SVD:gROIMappingFlag
	NVAR gPBGFlag 		= root:SPHINX:SVD:gPolyBGFlag
	NVAR gPBGOrder 	= root:SPHINX:SVD:gPolyBGOrder
	NVAR gSVDdEFlag 	= root:SPHINX:SVD:gSVDdEFlag
	NVAR gSVDdEMax 	= root:SPHINX:SVD:gSVDdEMax
	NVAR gSVDPosFlag 	= root:SPHINX:SVD:gSVDPosFlag
	
	NVAR gSVDEMin 	= root:SPHINX:SVD:gSVDEMin
	NVAR gSVDEMax 	= root:SPHINX:SVD:gSVDEMax

	NVAR gBin 			= root:SPHINX:SVD:gSVDBin
	NVAR gSVDX1 		= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDX2 		= root:SPHINX:SVD:gSVDRight
	NVAR gSVDY1 		= root:SPHINX:SVD:gSVDBottom
	NVAR gSVDY2 		= root:SPHINX:SVD:gSVDTop
	
	// Need to know the selected references
	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection

	// Find the indices of the fit range
	Variable PtMin 		= BinarySearch(StackAxis,gSVDEMin)
	Variable PtMax 		= BinarySearch(StackAxis,gSVDEMax)
	Variable SVDPtMin 	= min(PtMin,PtMax)
	Variable SVDPtMax 	= max(PtMin,PtMax)
	Variable NPts 		= SVDPtMax - SVDPtMin + 1
	
	// The total number of selected reference spectra. 
	Variable i, j=0, NSel=0, NRefs 	=DimSize(RefList,0)
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			NSel += 1
		endif
	endfor
	if (NSel < 1)
		Print " *** Please select one or more reference spectra"
		return 0
	endif
	
	// The center value for the background polynomial 
	gPBGOrder 	= (gPBGFlag == 1) ? gPBGOrder : 0
	Variable PCenter = gSVDEMin+(gSVDEMax-gSVDEMin)/2
	
	// The total number of fitted components, including ref spectra, polynomial backgrounds and energy offset. 
	Variable NCoefs 	= (gPBGFlag == 1) ? (NSel + gPBGOrder + 1) : NSel
	
	// The References Matrix -- must be on the FULL NumE axis to allow shifting. 
	Make /D/O/N=(NumE,NSel) RefMatrix	// <-- For some reason, this is set to (NPTs,NCoefs) in the ST routines ... 
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			WAVE Ref 	= $("root:SPHINX:SVD:"+RefList[i])
			RefMatrix[][j] 	= Ref[p]
			j += 1
		endif
	endfor
	
	// Prepare the default coefficients
	Make /D/O/N=(NCoefs) defaultCoefs
	FillLLSCoefficients(defaultCoefs,NSel,gSVDdEFlag,gPBGOrder)
	
	// Make the constraint matrix and wave
	PrepareLLSConstMatrix(NSel,NCoefs,gSVDdEFlag,gSVDdEMax,gSVDPosFlag)
	
	// Make the images that will display the results
	PrepareSVDImages(StackName,NumX,NumY)
	WAVE iChi2 	= $("root:SPHINX:Stacks:"+StackName + "_iMap_x2")
	WAVE pChi2 	= $("root:SPHINX:Stacks:"+StackName + "_pMap_x2")
	WAVE dEMap 	= $("root:SPHINX:Stacks:"+StackName + "_Map_dE")
	
	// Temporary waves to compile all the results
	Make /D/O/N=(NumX,NumY,NSel) StackSolnMatrix=0, StackScaleMatrix=0
	
	// Options for linear background subtraction
	Variable BGMin, BGMax
	GetEnergyRange(PanelFolder,"StackBrowser#PixelPlot",BGMin,BGMax)
	
	Variable n, Duration, timeRef 	= startMSTimer
	
	// check for valid ROI
//	Variable ROIFlag 	= CheckROIMapping(StackROI,gROIMapFlag,gSVDX1,gSVDX2,gSVDY1,gSVDY2)
	
	// The full X-pixel dimension of the selected region
	Variable NMapX 	= gSVDX2-gSVDX1+1
	Variable NMapX1, NMapX2, FirstX, LastX
	
	// Look for portions that equally divide up the image
	if (mod(NMapX,nPortions) == 0)
		NMapX1 = NMapX/nPortions
		NMapX2 = NMapX1
		print " 			...The stack",StackName,"will be subdivided horizontally into",nPortions,"portions of width",NMapX1
// BEN: this is where I made changes
// I think this elseif is made unnecessary by the change below
//	elseif(mod(NMapX,nPortions-1) == 0)
//		nPortions -= 1
//		NMapX1 = NMapX/nPortions
//		NMapX2 = NMapX1
//		print " 			...The stack",StackName,"will be subdivided horizontally into",nPortions,"portions of width",NMapX1

// See change below
	else
//		NMapX1 	= floor(NMapX/(nPortions-1))
		NMapX1 	= floor(NMapX/(nPortions))
		NMapX2 	= NMapX - ((nPortions-1)*NMapX1)
		print " 			...The stack",StackName,"will be subdivided horizontally into",nPortions-1,"portions of width",NMapX1,"and one portion of width",NMapX2
	endif
	
	// !*!*!*!*!*! This might not be the fastest way to do things ...
	nThreads = nPortions
	
	// This global variable is needed for the MT approach
	Variable/G threadGroupID = ThreadGroupCreate(nThreads)
	
	// The full Y-pixel dimension of the selected region
	Variable NMapY 	= gSVDY2-gSVDY1+1

	// ==================	Launch the chosen number of threads
	for(n=0;n<nThreads;n+=1)
		ThreadStart threadGroupID,n,MTSpectrumAnalysis2()
	endfor
	print " 			... Initiated",nThreads,"threads in ID #",threadGroupID,"to run Non-Linear Least-Squares component mapping with function: 'MTSpectrumAnalysis2' and fit tolerance = ",10^(-1*FitTolerance)
	// ==========================================================================
	
	
	//  ==================	Subdivide the Stack and pass the portions to the threads
	for(n=0;n<nPortions;n+=1)
	
		NewDataFolder/S forThread
			
			// New global variables to pass to the thread
			Variable /G gTgId 		= threadGroupID
			Variable /G gXStart 		= n*NMapX1
			Variable /G gNCoefs 		= NCoefs
			Variable /G gNSel 		= NSel
//			Variable /G gBin 		= gBin
			Variable /G gPosFlag 	= gSVDPosFlag
			Variable /G gConstraint 	= (gSVDPosFlag || gSVDdEFlag) ? 1 : 0
			Variable /G gFitTol 		= 10^(-1*FitTolerance)
			Variable /G gPCenter 	= PCenter
			Variable /G gBGMin 		= BGMin
			Variable /G gBGMax 	= BGMax
			String /G gHold 			= PrepareLLSHoldString(NSel,gSVDdEFlag,gPBGOrder)
			
			// Existing global variables to pass to the thread
//			DuplicateVar("root:SPHINX:SVD:gROIMappingFlag",":gROIFlag")			
			DuplicateVar("root:SPHINX:SVD:gSVDEMin",":gSVDEMin")
			DuplicateVar("root:SPHINX:SVD:gSVDEMax",":gSVDEMax")
			//
			DuplicateVar("root:SPHINX:SVD:gPolyBGOrder",":gPBGOrder")
			DuplicateVar("root:SPHINX:SVD:gSVDdEFlag",":gSVDdEFlag")
			//
			DuplicateVar("root:SPHINX:Browser:gIoDivChoice",":gIoChoice")
			DuplicateVar("root:SPHINX:Browser:gIoODIMax",":gIoODIMax")
		
			// Subdivide the full SPHINX stack into a smaller piece
			if (n == nPortions-1)
				// The last portion might have smaller dimensions
				Make /D/N=(NMapX2,NMapY,NumE) $("StackN") /WAVE=StackN
			else
				Make /D/N=(NMapX1,NMapY,NumE) $("StackN") /WAVE=StackN
			endif
			
			// 	-------------------	FILL THE PARTIAL STACK ------------------
			StackN[][][] 	= SPHINXStack[p+gSVDX1+n*NMapX1][q+gSVDY1][r]
			// ---------------------------------------------------------
			
			Duplicate StackAxis, EAxis
			Duplicate RefMatrix, RMatrix
			Duplicate defaultCoefs,dCoefs
			
			// This creates the constraints matrices in this data folder
			PrepareLLSConstMatrix(NSel,gNCoefs,gSVDdEFlag,gSVDdEMax,gSVDPosFlag)
			
			WAVEClear StackN
			WAVEClear EAxis
			WAVEClear RMatrix
			WAVEClear dCoefs
			
		ThreadGroupPutDF threadGroupID,:	// Send current data folder to input queue
	endfor
	print " 			... All the partial stacks have been sent to individual threads for processing."
	// ==========================================================================
	
	Variable msgd=0
	
	for(n=0;n<nPortions;n+=1)
		do
			DFREF dfr= ThreadGroupGetDFR(threadGroupID,1000)	// Get results in free data folder
			if ( DatafolderRefStatus(dfr) == 0 )
				if (msgd == 0)
					print " 			... Waiting for the threads to finish processing ..."
					
					msgd = 1
				endif
			else
				break
			endif
		while(1)
		
		WAVE SolnMatrix 	= dfr:SolnMatrix
		WAVE ScaleMatrix 	= dfr:ScaleMatrix
		WAVE iChi2N	 	= dfr:iChi2
		WAVE pChi2N		= dfr:pChi2
		WAVE dEMapN		= dfr:dEMap
		
		NVAR gXStart 		= dfr:gXStart
		FirstX 				= gSVDX1+gXStart
		
		NMapX 	= DimSize(ScaleMatrix,0)
		LastX 	= NMapX - 1
				
		print " 			... Received the fit results for horizontal pixels from X=",FirstX,"to",FirstX+LastX
		StackSolnMatrix[FirstX,FirstX+LastX][gSVDY1,gSVDY2][] 	= SolnMatrix[p-FirstX][q-gSVDY1][r]
		StackScaleMatrix[FirstX,FirstX+LastX][gSVDY1,gSVDY2][] 	= ScaleMatrix[p-FirstX][q-gSVDY1][r]
		
		iChi2[FirstX,FirstX+LastX][gSVDY1,gSVDY2] 			= iChi2N[p-FirstX][q-gSVDY1]
		pChi2[FirstX,FirstX+LastX][gSVDY1,gSVDY2] 			= pChi2N[p-FirstX][q-gSVDY1]
		dEMap[FirstX,FirstX+LastX][gSVDY1,gSVDY2] 			= dEMapN[p-FirstX][q-gSVDY1]
		
		// These statements apparently redundant
		WAVEClear SolnMatrix
		WAVEClear ScaleMatrix
		WAVEClear iChi2N
		WAVEClear pChi2N
		WAVEClear dEMapN
		
		KillDataFolder dfr
	endfor
	
	FillSVDImages2(StackSolnMatrix, StackScaleMatrix, RefSelect, StackName,gSVDX1,gSVDX2,gSVDY1,gSVDY2,0)
	
	duration = stopMSTimer(timeRef)
	print " 		*** The multi-thread operation took", duration/1e6,"s\r"
	
	// This terminates the MyWorkerFunc by setting an abort flag
	Variable tstatus= ThreadGroupRelease(threadGroupID)
	if( tstatus == -2 )
		Print "Thread would not quit normally, had to force kill it. Restart Igor."
	endif
End

Threadsafe Function MTSpectrumAnalysis2()
	do
		do
			// Get free data folder from input queue
			DFREF dfr = ThreadGroupGetDFR(0,1000)
			if (DataFolderRefStatus(dfr) == 0)
				// Options to print messages concerning MT thread status
				if( GetRTError(2) )
					// Print "worker closing down due to group release"
				else
					// Print "worker thread still waiting for input queue"
				endif
			else
				break
			endif
		while(1)
				
		// These are the waves that need to be transferred to the MT data folder. 
		// The subdivided stack
		WAVE StackN 		= dfr:StackN
		// The full stack energy axis
		WAVE StackAxis 	= dfr:EAxis
		// The matrix of references
		WAVE RefMatrix 	= dfr:RMatrix
		// Starting (default) coefficients
		WAVE dCoefs 		= dfr:dCoefs
		// The constraint matrix and vector
		WAVE Cmatrix 		= dfr:Cmatrix
		WAVE Cwave 		= dfr:Cwave
		// The (optional) Izero
		WAVE Izero 			= dfr:Izero
		
		// Transferred globals
		NVAR gNCoefs 		= dfr:gNCoefs		// The number of fit coefficients
		NVAR gNSel 			= dfr:gNSel			// The number of selected reference spectra
		NVAR gX0 			= dfr:gXStart		// Record how to stitch the output back together. 
		NVAR gConstraint 	= dfr:gConstraint	// Need a constraints matrix
		NVAR gPosFlag 		= dfr:gPosFlag		// Enforce positive ref scale factors. 
		// Transferred globals for the Structure Function
		NVAR gPBGOrder 	= dfr:gPBGOrder
		NVAR gPCenter 		= dfr:gPCenter
		NVAR gSVDdEFlag 	= dfr:gSVDdEFlag
		NVAR gFitTol 		= dfr:gFitTol
		// The Hold String
		SVAR gHold 			= dfr:gHold
		
		NVAR gSVDEMin		= dfr:gSVDEMin		// The fit range
		NVAR gSVDEMax		= dfr:gSVDEMax	
		
		// Parameters for Io normalization
		NVAR gIoChoice 		= dfr:gIoDivChoice
		NVAR gIoODImax 	= dfr:gIoODImax
		NVAR gLinBGFlag 	= dfr:gLinBGFlag
		NVAR gBGMin 		= dfr:gBGMin
		NVAR gBGMax 		= dfr:gBGMax
		
		Variable i, j, iMax, jMax, Const, refArea, iChiSqr, pChiSqr
		Variable NumXN	= DimSize(StackN,0)
		Variable NumYN	= DimSize(StackN,1)
		Variable NumE	= DimSize(StackN,2)
		
		Variable PtMin 		= BinarySearch(StackAxis,gSVDEMin)
		Variable PtMax 		= BinarySearch(StackAxis,gSVDEMax)
		Variable NFit 		= PtMax-PtMin+1
		
		// This data folder will contain the results of the processing
		NewDataFolder /S outDF

			Variable /G gXStart = gX0
			Variable V_FitQuitReason, V_FitError, V_fitOptions=4, V_FitTol=gFitTol
		
			// TEMPORARY WAVES
			MAke /D/O/N=(gNCoefs) LLSCfs
			Make /D/O/N=(gNSel) RefScale
			
			// The references axes are on the full NumE axis to allow shifting
			Make /D/O/N=(gPBGOrder) fpcs
			Make /D/O/N=(NumE) fsum, faxis, fshift
			faxis = StackAxis
			
			// OUTPUT waves
			Make /O/D/N=(NumXN,NumYN,gNSel) SolnMatrix=NaN, ScaleMatrix=NaN
			Make /O/D/N=(NumXN,NumYN) iChi2=NaN, pChi2=NaN, dEMap=NaN

			// ==================	Prepare the Structure for the Structure Fitting Function
			STRUCT LLSFitStruct fs 
			fs.minpt 	= PtMin		// First point in fit range
			fs.nsel 		= gNSel			// Number of reference spectra to fit
			fs.shflag 	= gSVDdEFlag	// Energy shift flag
			fs.center 	= gPCenter		// x-value at the center of the fit range
			fs.firstpt 	= PtMin 		// the first point at the start of the fit range
			fs.lastpt 	= PtMax 		// the last point at the start of the fit range
			fs.pcoefpt 	= gNSel+1		// start of polynomial coefficients in the coef wave
			fs.porder 	= gPBGOrder	// polynomial order
			fs.areaflag 	= 0 			// For fitting, do not calculate area under the references
			
			// This seems to be essential to pass the references matrix to the structure function
			WAVE fs.pcoefw		= fpcs 				// polynomial coefficients
			WAVE fs.refmatrix	= RefMatrix 		// matrix of reference spectra
			WAVE fs.shaxis		= fshift 			// shifted energy axis for reference spectra
			WAVE fs.unaxis		= faxis 				// unshifted energy axis for reference spectra
			WAVE fs.sumrefs	= fsum 				// sum of reference spectrum
			// ==========================================================================
						
			// Loop through all the pixels in the Stack portion
			for (i=0;i<NumXN;i+=1)
				for (j=0;j<NumYN;j+=1)
				
					// This could be used for binning. 
					// ImageStats /M=1/BEAM/RECT={i,iMax,j,jMax} StackN
					// WAVE spectrum=W_ISBeamAvg
					
					MatrixOp /O W_beam = beam(StackN,i,j) 
					WAVE spectrum = W_beam
					
					// ----------------			NormalizeExtractedSpectrum() 		------------------------
					if (gIoChoice == 2)
						spectrum /= Izero
					elseif (gIoChoice == 3)
						spectrum[] 	= -1 * ln(spectrum[p]/Izero[p])
					elseif (gIoChoice == 4)
						spectrum[] 	= -1 * ln(spectrum[p]/gIoODImax)
					endif
					if (gLinBGFlag)	
						MTSubtractLinearBG(spectrum,gBGMin,gBGMax)
					endif
					// ---------------------------------------------------------------------------
				
					// Always start from default values before any fit
					LLSCfs 	= dCoefs
					
					if (gConstraint)
						// Need to use constraint matrices instead of text wave
						FuncFit /Q/N/H=gHold MTLLSFitFunction, LLSCfs, spectrum[PtMin,PtMax] /X=StackAxis /C={Cmatrix,Cwave} /STRC=fs /I=1
					else
						FuncFit /Q/N/H=gHold MTLLSFitFunction, LLSCfs, spectrum[PtMin,PtMax] /X=StackAxis /STRC=fs /I=1
					endif
					
					// The reqported chi-square
					iChiSqr = V_chisq/NFit
					
					If ((V_FitQuitReason == 0) && (V_FitError == 0))
						
						// Place  the Reference Spectra SCALE coefficients into a 3D array
						if (gPosFlag)
							RefScale[] = max(LLSCfs[p],0)
						else
							RefScale[] = LLSCfs[p]
						endif
						SolnMatrix[i][j][] = RefScale[r]
						
						// Place  the Reference Spectra PROPORTIONAL coefficients into a 3D array
						Const = sum(RefScale)
						RefScale /= Const
						ScaleMatrix[i][j][] = RefScale[r]
						
						// The proportional chi-squared is scaled by the sum of the scale factors. 
						pChiSqr = iChiSqr/Const
							
						// Transfer the chi-squared and energy shift values directly to the image results
						iChi2[i][j] 			= iChiSqr
						pChi2[i][j]			= pChiSqr
						dEMap[i][j] 		= LLSCfs[gNSel]
					else
						// Indicate that the fit was not reliable at this pixed. 
						SolnMatrix[i][j][]	= NaN
						ScaleMatrix[i][j][] = NaN
						iChi2[i][j] 			= NaN
						pChi2[i][j]			= NaN
						dEMap[i][j] 		= NaN
					endif
					
				endfor
			endfor
			
			// Clear all the wave references so we can properly close down the thread. 
			
			// Set all Structure waves to null
			WAVE fs.pcoefw		= $"" 
			WAVE fs.refmatrix	= $"" 
			WAVE fs.shaxis		= $""
			WAVE fs.unaxis		= $""
			WAVE fs.sumrefs	= $""

			WAVEClear StackN
			WAVEClear StackAxis
			WAVEClear spectrum
			WAVEClear W_beam
			WAVEClear Izero
			
			WAVEClear RefMatrix
			WAVEClear RefScale
			WAVEClear LLSCfs
			WAVEClear dCoefs
			
			WAVEClear Cmatrix
			WAVEClear Cwave
			
			WAVEClear SolnMatrix
			WAVEClear ScaleMatrix
			WAVEClear iChi2
			WAVEClear pChi2
			WAVEClear dEMap
			
			WAVEClear fpcs
			WAVEClear fsum
			WAVEClear faxis
			WAVEClear fshift
			
			// Put current data folder in output queue
			ThreadGroupPutDF 0,:
		
			// We are done with the input data folder
			KillDataFolder dfr
	while(1)

	return 0
End

// The fitting function 
Threadsafe Function  MTLLSFitFunction(s) : FitFunc 
	Struct LLSFitStruct &s 
	
	Variable i, unshft, shifted
	
	// Add the unshifted, scaled reference spectra to the composite
	s.sumrefs = 0
	for (i=0;i<s.nsel;i+=1)
		s.sumrefs[] += s.coefw[i] * s.refmatrix[p][i]
	endfor
	
	if (s.shflag)	// Shift the energy axis if requested
		//  *** Cannot use the xw if shifting - causes edge effects during interpolation.
		//  *** There are out-of-range error if we use the fit-range for the references axis. 
		s.shaxis[] 	= s.unaxis[p] - s.coefw[s.nsel]
		s.yw[] 		= s.sumrefs[BinarySearchInterp(s.unaxis, s.shaxis[p+s.minpt])]
	else
		s.yw[] 		= s.sumrefs[p+s.minpt]
	endif
	
	// This is used for normalizing chi-squared values. 
	if (s.areaflag == 1)
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

ThreadSafe Function MTSubtractLinearBG(spectrum,bgmin,bgmax)
	Wave spectrum
	Variable bgmin,bgmax
	
	if (bgmin != bgmax)
		CurveFit /Q/W=0/N line, spectrum[bgmin,bgmax]
		
		WAVE W_coef = W_coef
		
		spectrum -= W_coef[0] + w_coef[1]*p
	endif
End

Threadsafe Function testMTSpectrumAnalysis2()
	do
		do
			// Get free data folder from input queue
			DFREF dfr = ThreadGroupGetDFR(0,1000)
			if (DataFolderRefStatus(dfr) == 0)
				// Options to print messages concerning MT thread status
				if( GetRTError(2) )
//					Print "worker closing down due to group release"
				else
//					Print "worker thread still waiting for input queue"
				endif
			else
				break
			endif
		while(1)
		
		NewDataFolder /S outDF
			
			// Put current data folder in output queue
			ThreadGroupPutDF 0,:
		
			// We are done with the input data folder
			KillDataFolder dfr
	while(1)

	return 0
End







































// *************************************************************
// ****		Single-Thread SPECTRUM ANALYSIS on image ROI for DEBUGGING
// *************************************************************


Function STMTROISVD(SPHINXStack,StackAxis, StackROI, StackName, StackFolder,PanelFolder)
	Wave SPHINXStack, StackAxis, StackROI
	String StackName, StackFolder, PanelFolder
	
	stopAllTimers()
	
	NewDataFolder /O/S root:SPHINX:MTSVD

	Variable NumX	= DimSize(SPHINXStack,0)
	Variable NumY	= DimSize(SPHINXStack,1)
	Variable NumE	= DimSize(SPHINXStack,2)
	
	NVAR gROIMapFlag 	= root:SPHINX:SVD:gROIMappingFlag
	NVAR gPBGFlag 		= root:SPHINX:SVD:gPolyBGFlag
	NVAR gPBGOrder 	= root:SPHINX:SVD:gPolyBGOrder
	NVAR gSVDdEFlag 	= root:SPHINX:SVD:gSVDdEFlag
	NVAR gSVDdEMax 	= root:SPHINX:SVD:gSVDdEMax
	NVAR gSVDPosFlag 	= root:SPHINX:SVD:gSVDPosFlag
	
	NVAR gSVDEMin 	= root:SPHINX:SVD:gSVDEMin
	NVAR gSVDEMax 	= root:SPHINX:SVD:gSVDEMax

	NVAR gBin 			= root:SPHINX:SVD:gSVDBin
	NVAR gSVDX1 		= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDX2 		= root:SPHINX:SVD:gSVDRight
	NVAR gSVDY1 		= root:SPHINX:SVD:gSVDBottom
	NVAR gSVDY2 		= root:SPHINX:SVD:gSVDTop
	
	// Need to know the selected references
	WAVE /T RefList 	= root:SPHINX:SVD:ReferenceSpectra
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection

	// Find the indices of the fit range
	Variable PtMin 		= BinarySearch(StackAxis,gSVDEMin)
	Variable PtMax 		= BinarySearch(StackAxis,gSVDEMax)
	Variable SVDPtMin 	= min(PtMin,PtMax)
	Variable SVDPtMax 	= max(PtMin,PtMax)
	Variable NPts 		= SVDPtMax - SVDPtMin + 1
	
	// The total number of selected reference spectra. 
	Variable i, j=0, NSel=0, NRefs 	=DimSize(RefList,0)
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			NSel += 1
		endif
	endfor
	if (NSel < 1)
		Print " *** Please select one or more reference spectra"
		return 0
	endif
	
	// The center value for the background polynomial 
	gPBGOrder 	= (gPBGFlag == 1) ? gPBGOrder : 0
	Variable PCenter = gSVDEMin+(gSVDEMax-gSVDEMin)/2
	
	// The total number of fitted components, including ref spectra, polynomial backgrounds and energy offset. 
	Variable NCoefs 	= (gPBGFlag == 1) ? (NSel + gPBGOrder + 1) : NSel
	
	// NOTE: The References waves must be on the FULL NumE axis to allow shifting. 
	
	// The References Matrix
	Make /D/O/N=(NumE,NSel) RefMatrix	// <-- For some reason, this is set to (NPTs,NCoefs) in the ST routines ... 
	for (i=0;i<NRefs;i+=1)
		if (isChecked(RefSelect[i][0]))
			WAVE Ref 	= $("root:SPHINX:SVD:"+RefList[i])
			RefMatrix[][j] 	= Ref[p]
			j += 1
		endif
	endfor
	
	// The References energy axis
//	Make /D/O/N=(NumE) RefAxis
//	RefAxis[] 	= StackAxis[p]
	
	// Prepare the default coefficients
	Make /D/O/N=(NCoefs) defaultCoefs
	FillLLSCoefficients(defaultCoefs,NSel,gSVDdEFlag,gPBGOrder)
	
	// Make the constraint matrix and wave
	PrepareLLSConstMatrix(NSel,NCoefs,gSVDdEFlag,gSVDdEMax,gSVDPosFlag)
	
	// Make the rest of the waves that are needed by the Structure Function
//	PrepareLLSMatrices(NPts,NCoefs,gPBGOrder)
	
	// Make the images that will display the results
	PrepareSVDImages(StackName,NumX,NumY)
	WAVE iChi2 	= $("root:SPHINX:Stacks:"+StackName + "_iMap_x2")
	WAVE pChi2 	= $("root:SPHINX:Stacks:"+StackName + "_pMap_x2")
	WAVE dEMap 	= $("root:SPHINX:Stacks:"+StackName + "_Map_dE")
	
	// Temporary waves to compile all the results
	Make /D/O/N=(NumX,NumY,NSel) StackSolnMatrix=0, StackScaleMatrix=0
	
	Variable BGMin, BGMax
	GetEnergyRange(PanelFolder,"StackBrowser#PixelPlot",BGMin,BGMax)

	// Options to set the number of Stack portions and the number of threads
	Variable nPortions 	= 5
//	Variable nThreads 	= ThreadProcessorCount
	Variable nThreads 	= 5
	
	// This global variable is needed for the MT approach
	Variable/G threadGroupID = ThreadGroupCreate(nThreads)
	Variable n, Duration, timeRef 	= startMSTimer
	
	// check for valid ROI
//	Variable ROIFlag 	= CheckROIMapping(StackROI,gROIMapFlag,gSVDX1,gSVDX2,gSVDY1,gSVDY2)
	
	// Calculate how to subdivide the analysis region for parallel processing
	// The full X-pixel dimension of the selected region
	Variable NMapX 	= gSVDX2-gSVDX1+1
	Variable NMapX1 	= floor(NMapX/(nPortions-1))
	Variable NMapX2 	= NMapX - ((nPortions-1)*NMapX1)
	Variable FirstX, LastX
	// The full Y-pixel dimension of the selected region
	Variable NMapY 	= gSVDY2-gSVDY1+1

	// ==================	Launch the chosen number of threads
//	for(n=0;n<nThreads;n+=1)
////		ThreadStart threadGroupID,n,MTSpectrumAnalysis()
//		ThreadStart threadGroupID,n,MTSpectrumAnalysis2()
//	endfor
//	print " 			... initiated the threads."
	// ==========================================================================
	

	for(n=0;n<nPortions;n+=1)
		KillDataFolder /Z $("forThread"+num2str(n))
	endfor
	
	//  ==================	Subdivide the Stack and pass the portions to the threads
	Variable nMax=1
//	for(n=0;n<nMax;n+=1)
	for(n=0;n<nPortions;n+=1)
		NewDataFolder/O/S $("forThread"+num2str(n))
//		NewDataFolder/S forThread
		
			// New global variables to pass to the thread
			Variable /G gXStart 		= n*NMapX1
			Variable /G gNCoefs 		= NCoefs
			Variable /G gNSel 		= NSel
//			Variable /G gBin 		= gBin
			Variable /G gPosFlag 	= gSVDPosFlag
			Variable /G gConstraint 	= (gSVDPosFlag || gSVDdEFlag) ? 1 : 0
			Variable /G gPCenter 	= PCenter
			Variable /G gBGMin 		= BGMin
			Variable /G gBGMax 	= BGMax
			String /G gHold 			= PrepareLLSHoldString(NSel,gSVDdEFlag,gPBGOrder)
			
			// Existing global variables to pass to the thread
//			DuplicateVar("root:SPHINX:SVD:gROIMappingFlag",":gROIFlag")			
			DuplicateVar("root:SPHINX:SVD:gSVDEMin",":gSVDEMin")
			DuplicateVar("root:SPHINX:SVD:gSVDEMax",":gSVDEMax")
			//
			DuplicateVar("root:SPHINX:SVD:gPolyBGOrder",":gPBGOrder")
			DuplicateVar("root:SPHINX:SVD:gSVDdEFlag",":gSVDdEFlag")
			//
			DuplicateVar("root:SPHINX:Browser:gIoDivChoice",":gIoChoice")
			DuplicateVar("root:SPHINX:Browser:gIoODIMax",":gIoODIMax")
		
			// Subdivide the full SPHINX stack into a smaller piece
			if (n == nPortions-1)
				// The last portion might have smaller dimensions
				Make /D/N=(NMapX2,NMapY,NumE) $("StackN") /WAVE=StackN
			else
				Make /D/N=(NMapX1,NMapY,NumE) $("StackN") /WAVE=StackN
			endif
			
			// 	-------------------	FILL THE PARTIAL STACK ------------------
			StackN[][][] 	= SPHINXStack[p+gSVDX1+n*NMapX1][q+gSVDY1][r]
			// ---------------------------------------------------------
			
			Duplicate StackAxis, $("root:SPHINX:MTSVD:forThread"+num2str(n)+":EAxis")
			Duplicate RefMatrix, $("root:SPHINX:MTSVD:forThread"+num2str(n)+":RMatrix")
//			Duplicate RefAxis, $("root:SPHINX:MTSVD:forThread"+num2str(n)+":RAxis")
			Duplicate defaultCoefs, $("root:SPHINX:MTSVD:forThread"+num2str(n)+":dCoefs")
			
			// This creates the constraints matrices in this data folder
			PrepareLLSConstMatrix(NSel,gNCoefs,gSVDdEFlag,gSVDdEMax,gSVDPosFlag)
			
			// --------------------- PERFORM THE ANALYSIS
			STMTSpectrumAnalysis2("forThread"+num2str(n))
					
//			WAVEClear StackN
//			WAVEClear EAxis
//			WAVEClear RMatrix
//			WAVEClear RAxis
//			WAVEClear dCoefs
			
//			WAVEClear SPHINXStack
//			WAVEClear Cmatrix
//			WAVEClear Cwave
			
		SetDataFolder root:SPHINX:MTSVD
//		ThreadGroupPutDF threadGroupID,:	// Send current data folder to input queue
	endfor
	print " 			... transferred the partial SPHINX stacks."
	// ==========================================================================
	
	Variable nWaves
	Variable msgd=0
		print " 	... x-range is",gSVDX1,"to",gSVDX2
		
//	for(n=0;n<nMax;n+=1)
	for(n=0;n<nPortions;n+=1)
		DFREF dfr = $("root:SPHINX:MTSVD:forThread"+num2str(n)+":outDF")
		
		WAVE SolnMatrix 	= dfr:SolnMatrix
		WAVE ScaleMatrix 	= dfr:ScaleMatrix
		WAVE iChi2N	 	= dfr:iChi2
		WAVE pChi2N		= dfr:pChi2
		WAVE dEMapN		= dfr:dEMap
		
		NVAR gXStart 		= dfr:gXStart
		FirstX 				= gSVDX1+gXStart
		
		if (n == nPortions-1)
			LastX = NMapX2-1
		else
			LastX = NMapX1-1
		endif
		
		print " 	... filling x-pixels from",FirstX,"to",FirstX+LastX
		StackSolnMatrix[FirstX,FirstX+LastX][gSVDY1,gSVDY2][] 	= SolnMatrix[p-FirstX][q-gSVDY1][r]
		StackScaleMatrix[FirstX,FirstX+LastX][gSVDY1,gSVDY2][] 	= ScaleMatrix[p-FirstX][q-gSVDY1][r]
		
		iChi2[FirstX,FirstX+LastX][gSVDY1,gSVDY2] 			= iChi2N[p-FirstX][q-gSVDY1]
		pChi2[FirstX,FirstX+LastX][gSVDY1,gSVDY2] 			= pChi2N[p-FirstX][q-gSVDY1]
		dEMap[FirstX,FirstX+LastX][gSVDY1,gSVDY2] 			= dEMapN[p-FirstX][q-gSVDY1]
		
		// These statements apparently redundant
//		WAVEClear SolnMatrix
//		WAVEClear ScaleMatrix
//		WAVEClear iChi2N
//		WAVEClear pChi2N
//		WAVEClear dEMapN
//		KillDataFolder dfr
	endfor
	
	FillSVDImages2(StackSolnMatrix, StackScaleMatrix, RefSelect, StackName,gSVDX1,gSVDX2,gSVDY1,gSVDY2,0)
	
	duration = stopMSTimer(timeRef)
	print " 	*** The single-multi-thread operation took", duration/1e6,"s"
	
	// This terminates the MyWorkerFunc by setting an abort flag
	Variable tstatus= ThreadGroupRelease(threadGroupID)
	if( tstatus == -2 )
		Print "Thread would not quit normally, had to force kill it. Restart Igor."
	endif
	
	
	for(n=0;n<nPortions;n+=1)
		KillDataFolder $("forThread"+num2str(n))
	endfor
End
			
Function STMTSpectrumAnalysis2(dfrName)
	String dfrName
	DFREF dfr = $dfrName
		
		// These are the waves that need to be transferred to the MT data folder. 
		// The subdivided stack
		WAVE StackN 		= dfr:StackN
		// The full stack energy axis
		WAVE StackAxis 	= dfr:EAxis
		// The matrix of references
		WAVE RefMatrix 	= dfr:RMatrix
		// Starting (default) coefficients
		WAVE dCoefs 		= dfr:dCoefs
		// The constraint matrix and vector
		WAVE Cmatrix 		= dfr:Cmatrix
		WAVE Cwave 		= dfr:Cwave
//		// The ROI
//		WAVE roiStack 		= dfr:roiStack
//		// The Izero
//		WAVE Izero 			= dfr:specIo
		
		// Transferred globals
		NVAR gNCoefs 		= dfr:gNCoefs		// The number of fit coefficients
		NVAR gNSel 			= dfr:gNSel			// The number of selected reference spectra
		NVAR gX0 			= dfr:gXStart		// Record how to stitch the output back together. 
		NVAR gConstraint 	= dfr:gConstraint	// Need a constraints matrix
		NVAR gPosFlag 		= dfr:gPosFlag		// Enforce positive ref scale factors. 
		// Transferred globals for the Structure Function
		NVAR gPBGOrder 	= dfr:gPBGOrder
		NVAR gPCenter 		= dfr:gPCenter
		NVAR gSVDdEFlag 	= dfr:gSVDdEFlag
		// The Hold String
		SVAR gHold 			= dfr:gHold
		
		// No binning and no ROI use in the MT version
//		NVAR gBin 			= dfr:gBin
//		NVAR gROIFlag 		= dfr:gROIFlag
		
		NVAR gSVDEMin		= dfr:gSVDEMin		// The fit range
		NVAR gSVDEMax		= dfr:gSVDEMax	
		
		// Parameters for Io normalization
		NVAR gIoChoice 		= dfr:gIoDivChoice
		NVAR gIoODImax 	= dfr:gIoODImax
		NVAR gLinBGFlag 	= dfr:gLinBGFlag
		NVAR gBGMin 		= dfr:gBGMin
		NVAR gBGMax 		= dfr:gBGMax
		
		Variable i, j, iMax, jMax, Const, refArea, iChiSqr, pChiSqr
		Variable NumXN	= DimSize(StackN,0)
		Variable NumYN	= DimSize(StackN,1)
		Variable NumE	= DimSize(StackN,2)
		
		Variable PtMin 		= BinarySearch(StackAxis,gSVDEMin)
		Variable PtMax 		= BinarySearch(StackAxis,gSVDEMax)
		
		// This data folder will contain the results of the processing
		NewDataFolder /O/S outDF

			Variable /G gXStart = gX0
			Variable V_FitQuitReason, V_FitError, V_fitOptions=4
//		
//			// TEMPORARY WAVES
			MAke /D/O/N=(gNCoefs) LLSCfs
			Make /D/O/N=(gNSel) RefScale
			
			// The references axes are on the full NumE axis to allow shifting
			Make /D/O/N=(gPBGOrder) fpcs
			Make /D/O/N=(NumE) fsum, faxis, fshift
			Make /O/D/N=(NumE) RefResids, RefResults
			faxis = StackAxis
			
//			// OUTPUT waves
			Make /O/D/N=(NumXN,NumYN,gNSel) SolnMatrix=NaN, ScaleMatrix=NaN
			Make /O/D/N=(NumXN,NumYN) iChi2=NaN, pChi2=NaN, dEMap=NaN

			// ==================	Prepare the Structure for the Structure Fitting Function
			STRUCT LLSFitStruct fs 
			fs.minpt 	= PtMin		// First point in fit range
			fs.nsel 		= gNSel			// Number of reference spectra to fit
			fs.shflag 	= gSVDdEFlag	// Energy shift flag
			fs.center 	= gPCenter		// x-value at the center of the fit range
			fs.firstpt 	= PtMin 		// the first point at the start of the fit range
			fs.lastpt 	= PtMax 		// the last point at the start of the fit range
			fs.pcoefpt 	= gNSel+1		// start of polynomial coefficients in the coef wave
			fs.porder 	= gPBGOrder	// polynomial order
			fs.areaflag 	= 0 			// For fitting, do not calculate area under the references
			
			// This seems to be essential to pass the references matrix to the structure function
			WAVE fs.pcoefw		= fpcs 				// polynomial coefficients
			WAVE fs.refmatrix	= RefMatrix 		// matrix of reference spectra
			WAVE fs.shaxis		= fshift 			// shifted energy axis for reference spectra
			WAVE fs.unaxis		= faxis 				// unshifted energy axis for reference spectra
			WAVE fs.sumrefs	= fsum 				// sum of reference spectrum
			// ==========================================================================
		
			Variable nn=0, prob=0, SimpleChi2=1
			string FitInfo
			
			// Loop through all the pixels in the Stack portion
			for (i=0;i<NumXN;i+=1)
				for (j=0;j<NumYN;j+=1)
				
					// This could be used for binning. 
//					ImageStats /M=1/BEAM/RECT={i,iMax,j,jMax} StackN
//					WAVE spectrum=W_ISBeamAvg
					
					MatrixOp /O W_beam = beam(StackN,i,j) 
					WAVE spectrum = W_beam
					
					// ----------------			NormalizeExtractedSpectrum() 		------------------------
//					if (gIoChoice == 2)
//						spectrum /= Izero
//					elseif (gIoChoice == 3)
//						spectrum[] 	= -1 * ln(spectrum[p]/Izero[p])
//					elseif (gIoChoice == 4)
//						spectrum[] 	= -1 * ln(spectrum[p]/gIoODImax)
//					endif
//					if (gLinBGFlag)	
//						// disable linear background subtraction for the moment. 
////						SubtractLinearBG(spectrum,specbg,gBGMin,gBGMax)
//					endif
					// ---------------------------------------------------------------------------
				
					// Always start from default values before any fit
					LLSCfs 	= dCoefs
					
					if (gConstraint)
						// Need to use constraint matrices instead of text wave
						FuncFit /Q/N/H=gHold MTLLSFitFunction, LLSCfs, spectrum[PtMin,PtMax] /X=StackAxis /C={Cmatrix,Cwave} /STRC=fs /I=1
					else
						FuncFit /Q/N/H=gHold MTLLSFitFunction, LLSCfs, spectrum[PtMin,PtMax] /X=StackAxis /STRC=fs /I=1
					endif
					
					iChiSqr = sqrt(V_chisq)/4
					
					If ((V_FitQuitReason == 0) && (V_FitError == 0))
						
						// Place  the Reference Spectra SCALE coefficients into a 3D array
						if (gPosFlag)
							RefScale[] = max(LLSCfs[p],0)
						else
							RefScale[] = LLSCfs[p]
						endif				
						SolnMatrix[i][j][] = RefScale[r]
						
						// Place  the Reference Spectra PROPORTIONAL coefficients into a 3D array
						Const = sum(RefScale)
						RefScale /= Const
						ScaleMatrix[i][j][] = RefScale[r]
						
						if (SimpleChi2)
							refArea 	= abs(sum(fsum,PtMin,PtMax))
							pChiSqr 	= iChiSqr/refArea
						else
							WAVE fs.coefw		= LLSCfs 								// All best fit coefficients, including polynomial coefficients
							WAVE fs.xw			= StackAxis
							WAVE fs.yw			= RefResults
							
							fs.areaflag 			= 1 									// .Calculate the area under the reference 
							LLSFitFunction(fs)
							refArea 	= fs.refarea
							
							RefResids = NaN
							RefResids[PtMin,PtMax] = spectrum[p] - RefResults[p]
							
							WaveStats /Q RefResids
							iChiSqr =  V_rms^2
							pChiSqr =  iChiSqr/refArea
						endif
							
						// Transfer the chi-squared and energy shift values directly to the image results
						iChi2[i][j] 		= iChiSqr
						pChi2[i][j]		= pChiSqr
						dEMap[i][j] 	= LLSCfs[gNSel]
					else
						RefResids = NaN
					endif
					
				endfor
			endfor
			
			// Clear all the wave references so we can properly close down the thread. 
			WAVEClear StackN
			WAVEClear StackAxis
			WAVEClear dCoefs
			WAVEClear spectrum
			WAVEClear W_beam
			
//			WAVEClear roiStack
//			WAVEClear Izero
			
			WaveClear RefResids
			WaveClear RefResults
//			WaveClear RefAxis
			
			WAVEClear SolnMatrix
			WAVEClear ScaleMatrix
			WAVEClear iChi2
			WAVEClear pChi2
			WAVEClear dEMap
			
			// Put current data folder in output queue
//			ThreadGroupPutDF 0,:
		
			// We are done with the input data folder
//			KillDataFolder dfr

	return 0
End
