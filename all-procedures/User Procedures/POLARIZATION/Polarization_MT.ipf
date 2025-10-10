//Updated 01.12.2015 17:00

#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function MTAnalyzeStack()

	SetDataFolder root:POLARIZATION:Analysis
	
	Variable i,j,k,kft,keep,n,m,nm,nMax,mMax,V_chisq,V_max,MaxPolAngle,A,B
	Variable nCounter
	NVAR Bin = root:SPHINX:Browser:gCursorBin
	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	WAVE spectrum 	= $(PanelFolder + ":spectrum")
	WAVE SPHINXStack = $(StackFolder+":"+StackName)
	Wave NumData = $("root:POLARIZATION:NumData")
	Variable MaxX = NumData[0]
	Variable MaxY = NumData[1]
	Variable PolAxis = DimSize(SPHINXStack,2)

	// Get number of threads
	Variable nThreads 	= ThreadProcessorCount
	Variable NPortions	= NumVarOrDefault("root:SPHINX:MTSVD:gNPortions",nThreads)
	Prompt NPortions, "Dividing the stack into portions"
	DoPrompt "Multi-thread PIC-Mapping", NPortions
	
	Variable /G gNPortions = NPortions

	// If AutoSave box is checked, save the experiment
	Variable /G autoSave
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
	
	//Get ROI Positions from SVD Folder
		NVAR X1 	= root:SPHINX:SVD:gSVDLeft
		NVAR X2 	= root:SPHINX:SVD:gSVDRight
		NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
		NVAR Y2 	= root:SPHINX:SVD:gSVDTop
		if (!NVAR_Exists(X1))
			Print " *** Please select an ROI"
			return 0
		endif
	
	//Get angle range for finding peaks after fit
		NVAR maxAngle = $("root:POLARIZATION:maxAngle")
		NVAR minAngle = $("root:POLARIZATION:minAngle")
	
	// Normalization Settings
		NVAR gInvertSpectraFlag	= $(BrowserFolder+":gInvertSpectraFlag")
		Variable /G NormToI0
		if (NormToI0 == 1)
			WAVE I0 = root:POLARIZATION:Analysis:I0
		endif
		
	// Assign Results waves
		WAVE /D POLAnalysis	= $(StackFolder+":POL_Analysis")
		WAVE /D POLChiSq		= $(StackFolder+":POL_ChiSq")
		WAVE /D POLIntensity	= $(StackFolder+":POL_Intensity")
		WAVE /D POL_A			= $(StackFolder+":POL_A")
		WAVE /D POL_B			= $(StackFolder+":POL_B")
	
	// Make Results Waves if needed
		if (!WaveExists(POLAnalysis))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Analysis") /WAVE=POLAnalysis
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_ChiSq") /WAVE=POLChiSq
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Intensity") /WAVE=POLIntensity
			POLAnalysis = NaN
			POLChiSq = NaN
			POLIntensity = NaN
		endif
	// Make NEW Results Waves if needed
		if (!WaveExists(POL_A))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_A") /WAVE=POL_A
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_B") /WAVE=POL_B
			POL_A = NaN
			POL_B = NaN
		endif

	Variable Duration, timeRef = startMSTimer
	
	// The full X-pixel dimension of the selected region
	Variable NMapX = X2 - X1 + 1
	Variable NMapX1, NMapX2, FirstX, LastX
	
	// Look for portions that equally divide up the image
	if (mod(NMapX, nPortions) == 0)
		NMapX1 = NMapX/nPortions
		NMapX2 = NMapX1
		print " 			...The stack",StackName,"will be subdivided horizontally into",nPortions,"portions of width",NMapX1
	else
		NMapX1 	= floor(NMapX/nPortions)
		NMapX2 	= NMapX - ((nPortions-1)*NMapX1)
		print " 			...The stack",StackName,"will be subdivided horizontally into",nPortions-1,"portions of width",NMapX1,"and one portion of width",NMapX2
	endif
	nThreads = nPortions
	
	// This global variable is needed for the MT approach
	Variable/G threadGroupID = ThreadGroupCreate(nThreads)

	// The full Y-pixel dimension of the selected region
	Variable NMapY 	= Y2 - Y1 + 1

	// ==================	Launch the chosen number of threads
	for(nCounter=0;nCounter<nThreads;nCounter+=1)
		ThreadStart threadGroupID,nCounter,MTPolAnalysis()
	endfor
	print " 			... Initiated",nThreads,"threads"
	// ==========================================================================


	//  ==================	Subdivide the Stack and pass the portions to the threads
	for (nCounter=0; nCounter < nPortions; nCounter += 1)
	
		NewDataFolder/S forThread
			
			// New global variables to pass to the thread
			Variable /G gTgId		= threadGroupID
			Variable /G gXStart	= nCounter * NMapX1
			
			// Existing global variables to pass to the thread
		
			// Subdivide the full SPHINX stack into a smaller piece
			if (nCounter == nPortions-1)
				// The last portion might have smaller dimensions
				Make /D/N=(NMapX2,NMapY,PolAxis) $("StackN") /WAVE=StackN
			else
				Make /D/N=(NMapX1,NMapY,PolAxis) $("StackN") /WAVE=StackN
			endif
			
			// 	-------------------	FILL THE PARTIAL STACK ------------------
			StackN[][][] 	= SPHINXStack[p + X1 + nCounter*NMapX1][q + Y1][r]
			// ---------------------------------------------------------

//			Duplicate StackAxis, PolAxisWave

			WAVEClear StackN
//			WAVEClear PolAxisWave

		ThreadGroupPutDF threadGroupID,:	// Send current data folder to input queue
	endfor
	print " 			... All the partial stacks have been sent to individual threads for processing."
	// ==========================================================================

	Variable msgd=0

	for (nCounter = 0; nCounter < nPortions; nCounter += 1)
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
		
		WAVE POLAnalysisN		= dfr:POLAnalysisN
		WAVE POLChiSqN		= dfr:POLChiSqN
		WAVE POLIntensityN		= dfr:POLIntensityN
		WAVE POL_AN			= dfr:POL_AN
		WAVE POL_BN			= dfr:POL_BN

		NVAR gXStart	= dfr:gXStart
		FirstX 			= X1+gXStart

		NMapX 	= DimSize(POLAnalysisN,0)
		LastX 	= NMapX - 1

		print " 			... Received the fit results for horizontal pixels from X=",FirstX,"to",FirstX+LastX

//		POLAnalysis[FirstX,FirstX+LastX][Y1,Y2][] 	= POLAnalysisN[p - FirstX][q - Y1][r]
//		POLChiSq[FirstX,FirstX+LastX][Y1,Y2][] 	= POLChiSqN[p - FirstX][q - Y1][r]
//		POLIntensity[FirstX,FirstX+LastX][Y1,Y2][] 	= POLIntensityN[p - FirstX][q - Y1][r]
//		POL_A[FirstX,FirstX+LastX][Y1,Y2][] 		= POL_AN[p - FirstX][q - Y1][r]
//		POL_B[FirstX,FirstX+LastX][Y1,Y2][] 		= POL_BN[p - FirstX][q - Y1][r]

		POLAnalysis[FirstX,FirstX+LastX][Y1,Y2] 	= POLAnalysisN[p - FirstX][q - Y1]
		POLChiSq[FirstX,FirstX+LastX][Y1,Y2]	 	= POLChiSqN[p - FirstX][q - Y1]
		POLIntensity[FirstX,FirstX+LastX][Y1,Y2] 	= POLIntensityN[p - FirstX][q - Y1]
		POL_A[FirstX,FirstX+LastX][Y1,Y2] 		= POL_AN[p - FirstX][q - Y1]
		POL_B[FirstX,FirstX+LastX][Y1,Y2] 		= POL_BN[p - FirstX][q - Y1]

		// These statements apparently redundant
		WAVEClear POLAnalysisN
		WAVEClear POLChiSqN
		WAVEClear POLIntensityN
		WAVEClear POL_AN
		WAVEClear POL_BN

//		print "disposing data folder"
		KillDataFolder dfr
	endfor


//	OpenProcBar("Analyzing Polarization Angle Intensity Data for "+StackName)
//	CloseProcessBar()
	
	Duration = stopMSTimer(timeRef)/1000000
	Print " 		.............. took  ", Duration,"  seconds for ",(X2-X1)*(Y2-Y1),"pixels. "
	String ResultsText = "Stack Analysis Completed\r\rView Analysis and X\S2\M\rimages in SPHINX"
	TextBox /W=PolarizationAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	SetActiveSubwindow PolarizationAnalysis
	
	// If AutoSave box is checked, save the experiment
	if (autoSave)
		// uncheck the box to prevent accidental AutoSaving in the future
		autoSave = 0
		SaveExperiment
	endif

	// This terminates the MyWorkerFunc by setting an abort flag
	Variable tstatus = ThreadGroupRelease(threadGroupID)
	if (tstatus == -2 )
		Print "Thread would not quit normally, had to force kill it. Restart Igor."
	endif

	return 0
End

Threadsafe Function MTPolAnalysis()
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

		Variable i,j,k,kft,keep,n,m,nm,nMax,mMax,V_chisq,V_max,MaxPolAngle,A,B
		Variable testVar0, testVar1
//		NVAR Bin = root:SPHINX:Browser:gCursorBin
		Variable Bin = 1 // FIXME: get the actual bin. this is temporary, as the bin does not seem to be copying correctly
		String BrowserFolder = "root:SPHINX:Browser"
//		WAVE spectrum 	= $("dfr:spectrum")
//		WAVE spectrum 	= dfr:spectrum
		Make /O/N=(19) /D dfr:spectrum /WAVE=spectrum

		// Normalization Settings
			NVAR gInvertSpectraFlag	= $(BrowserFolder+":gInvertSpectraFlag")
			Variable /G NormToI0
			if (NormToI0 == 1)
				WAVE I0 = root:POLARIZATION:Analysis:I0
			endif

		// Variable for storing current guesses
			Make/D/N=(3,2)/O W_coef
			// Make appropriate guesses, depending on data inversion, to hopefully avoid "Singular Matrix" errors and get better fits...
			if (gInvertSpectraFlag == 0)
				W_coef[][0] = {-140,50,1}
				W_coef[][1] = {-140,-50,-2}
			else
				W_coef[][0] = {140,-100,2}
				W_coef[][1] = {140,100,-5}
			endif

		Variable V_FitError=0		//Block error reporting and capture error data

		// These are the waves that need to be transferred to the MT data folder. 
		// The subdivided stack
		WAVE StackN 		= dfr:StackN
		
		// Transferred globals
		NVAR gX0 = dfr:gXStart
		
		Variable MaxX	= DimSize(StackN,0)
		Variable MaxY	= DimSize(StackN,1)
		Variable X1N		= 0
		Variable Y1N		= 0
		Variable X2N		= MaxX
		Variable Y2N		= MaxY

		// This data folder will contain the results of the processing
		NewDataFolder /S outDF

			Variable /G gXStart = gX0

			// OUTPUT waves
			Make /O/D/N=(X2N,Y2N) POLAnalysisN=NaN, POLChiSqN=NaN, POLIntensityN=NaN, POL_AN=NaN, POL_BN=NaN


			// this (hopefully) does the same thing as createFitSpectrumShell()
//			WAVE /D fit_spectrum_m = $("dfr:fit_spectrum_m")
			WAVE /D fit_spectrum_m = dfr:fit_spectrum_m
			if (!WaveExists(fit_spectrum_m))
//				Make /O/N=(1800)/D $("dfr:fit_spectrum_m") /WAVE=fit_spectrum_m
				Make /O/N=(1800)/D dfr:fit_spectrum_m /WAVE=fit_spectrum_m
				fit_spectrum_m = NaN
				SetScale x,-90,90,fit_spectrum_m
			endif

//			print "bin=",Bin

			for (i = X1N; i < X2N; i += Bin)
				for (j = Y1N; j < Y2N; j += Bin)
					nm = 0
					// May get data from a bit past ROI, but binning stats are more accurate for Intensity data!
					mMax 	= (i+Bin > MaxX) ? MaxX : (i+Bin)
					nMax 	= (j+Bin > MaxY) ? MaxY : (j+Bin)
					spectrum = 0

					// EXTRACT SPECTRUM from PIXEL i,j (with Binning, if specified)
						for (m = i; m < mMax; m += 1)
							for (n = j; n < nMax; n += 1)
								spectrum[] 	+= StackN[m][n][p]
								nm += 1
							endfor
						endfor

					// If Binning worked, continue
						if (nm > 0)
						// Normalize Extracted Spectra, per settings in Stack Browser
							if (gInvertSpectraFlag == 0)
								spectrum = -1*spectrum
							endif
							spectrum /= Bin^2
							if (NormToI0 == 1)
								spectrum /= I0
							endif

						//PERFORM FIT FUNCTION FOR spectrum
							keep = 0 // Variable for exiting the FOR loop
							for (k = 0; k < 2; k += 1)	// Allow iterations, if required, to improve Fit
								V_FitError = 0		// Capture fit errors, and do not prompt user!
//								FuncFit/NTHR=0/N/Q=1 cos_squared W_coef[][k]  spectrum /X=:::POLARIZATION:angles /D
//								FuncFit/NTHR=1/N/Q=1 cos_squared_mt W_coef[][k]  spectrum /X=:::POLARIZATION:angles /D
//								FuncFit/NTHR=1 cos_squared_mt W_coef  :POLARIZATION:Analysis:fit_spectrum /D
								FuncFit/NTHR=1/N/Q=1 cos_squared_mt W_coef[][k] spectrum /D

//								print "V_Chisq =",V_Chisq // FIXME: V_Chisq is NaN every time

								if (V_Chisq < 300)
									break // Break out of For loop - Good Fit.
								elseif (k == 0)
									kft = V_Chisq
									if (keep == 1)
										break // Break out of For loop - Best possible fit.
									endif
								elseif (k > 0)
									if (kft > V_Chisq)
										break // Break out of For loop - Best possible fit.
									else
										keep = 1
										k = -1 // Redo the first attempt
									endif
								endif
							endfor

							if (V_FitError == 0)
//								print "good stuff"
								fit_spectrum_m = W_coef[0][0]+W_coef[1][0]*cos((x)/180*pi-W_coef[2][0])^2
								WaveStats /Q /M=1 fit_spectrum_m

								MaxPolAngle = V_maxloc
								A = V_min
								B = V_max-V_min
							else
//								print "bad stuff"
								MaxPolAngle	= NaN
								A			= NaN
								B			= NaN
								V_Chisq		= NaN
								V_max		= NaN

								if (gInvertSpectraFlag == 0)
									W_coef[][0] = {-140,50,1}
									W_coef[][1] = {-140,-50,-2}
								else
									W_coef[][0] = {140,-100,2}
									W_coef[][1] = {140,100,-5}
								endif
							endif

					// If Binning didn't work

						else
							MaxPolAngle	= NaN
							A			= NaN
							B			= NaN
							V_Chisq		= NaN
							V_max		= NaN
						endif

					// ASSIGN RESULTS TO POLAnalysis STACK
						for (m = i; m < mMax; m += 1)
							for (n = j; n < nMax; n += 1)
								POLAnalysisN[m][n]	= maxPolAngle
								POLChiSqN[m][n]	= V_Chisq
								POLIntensityN[m][n]	= V_max
								POL_AN[m][n]		= A
								POL_BN[m][n]		= B
							endfor
						endfor
				endfor
			endfor

			// Clear all the wave references so we can properly close down the thread. 

			WAVEClear POLAnalysisN
			WAVEClear POLChiSqN
			WAVEClear POLIntensityN
			WAVEClear POL_AN
			WAVEClear POL_BN

			WAVEClear spectrum
			WAVEClear fit_spectrum_m
			WAVEClear StackN
			WAVEClear W_coef

			// Put current data folder in output queue
			ThreadGroupPutDF 0,:
//			ThreadGroupPutDF threadGroupID,:
		
			// We are done with the input data folder
			KillDataFolder dfr
		while(1)

		return 0
End

// *************************************************************
// ****		Cos Squared Fit Function
// *************************************************************
Threadsafe Function cos_squared_mt(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = a + b * (cos(x + c)) ^ 2
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = a
	//CurveFitDialog/ w[1] = b
	//CurveFitDialog/ w[2] = c

	return w[0] + w[1] * (cos((pi*x/180) - w[2])) ^ 2
End