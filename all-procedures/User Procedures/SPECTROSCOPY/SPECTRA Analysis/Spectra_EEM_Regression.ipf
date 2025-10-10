#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// This is a function that runs in each independent thread to perform pixel-by-pixel analysis on a portion of the stack of EEMS
ThreadSafe Function EEMWorkerFunc()
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
		
		
	print "dfr status = ",DataFolderRefStatus(dfr )
		
		// Transferred waves
		WAVE EEMn 	= dfr:EEMn			// The partial EEM stack
		WAVE Scalar 	= dfr:Scalar 		// The 1D array of scalar values
		WAVE Stats 		= dfr:Stats			// The partial 3D array of results of the statistical analysis
		// Transferred globals
		NVAR gX0 		= dfr:gEEMXStart	// Record how to stitch the output back together. 
		
		Variable i, j
		Variable NumX	= DimSize(EEMn,0)
		Variable NumY	= DimSize(EEMn,1)

		// This data folder will contain the results of the processing
		NewDataFolder/S outDF
		
			Variable /G gEEMXStart = gX0
			
			Variable nWaves = CountObjectsDFR(dfr,1)
			print "there are ",nWaves,"waves in here"
			string waves=""
			for (i=0;i<nWaves;i+=1)
				waves = waves+GetIndexedObjName(":",1,i)+";"
			endfor
			print waves
		
			// Transfer the wave to contain the results of the statistical analyses
			// Actually this could be created in this loop, rather than in the main queue
			Duplicate Stats,StatsOut
			
			// Loop through all the pixels in the EEM piece
			for (i=0;i<NumX;i+=1)
				for (j=0;j<NumY;j+=1)
						
					// Skip if the first EEM value is NaN
					// Much of the rectangular EEM image contains no data at {Em,Ex} values
					if (numtype(EEMn[i][j][0]) == 0)
					
						// Extract the beam of intensity points
						MatrixOp /O W_beam = beam(EEMn,i,j) 
						WAVE W_beam = W_beam
						
						// ********************************************************
						// 		ADD YOUR STATISTICAL TEST HERE
						// *********************************************************
						// Perform a statistical test
						StatsLinearRegression /Q Scalar, W_Beam
						WAVE W_LinearRegressionMC = W_LinearRegressionMC
						WAVE W_StatsLinearRegression = W_StatsLinearRegression
						
						// Transfer the results of the test to the results array
						StatsOut[i][j][] = W_StatsLinearRegression[r]
//						StatsOut[i][j][] = gnoise(5)
						// *********************************************************
						
					endif
					
				endfor
			endfor
			
			// Clear all the wave references so we can properly close down the thread. 
			WAVEClear StatsOut
			WAVEClear W_beam
			WAVEClear W_StatsLinearRegression
			WAVEClear W_LinearRegressionMC
			
			// Put current data folder in output queue
			ThreadGroupPutDF 0,:
		
			// We are done with the input data folder
			KillDataFolder dfr
	while(1)

	print "dfr status = ",DataFolderRefStatus(dfr )
	
	return 0
End

// List waves that have certain dimensions
// DataChoice = 1 is 1D waves
// DataChoice = 2 is 2D wave (e.g., EEM)
// DataChoice = 3 is stack of 2D waves
Function /T ReturnFolderWaveList(FolderName,DataChoice)
	String FolderName
	Variable DataChoice
	
	Variable i, NumWaves
	String WvName, List1D="", List2D="", List3D=""
	
	FolderName = ParseFilePath(2,FolderName,":",0,0)
		
	NumWaves = CountObjects(FolderName,1)
	for(i=0;i<NumWaves;i+=1)
		WvName =  GetIndexedObjName(FolderName,1,i)
		WAVE Wv 	= $(ParseFilePath(2,FolderNAme,":",0,0) + WvName)
		if ((DimSize(Wv,1) == 0) && (DimSize(Wv,2) == 0))
			List1D += WvName+";"
		elseif ((DimSize(Wv,1) > 0) && (DimSize(Wv,2) == 0))
			List2D += WvName+";"
		elseif (DimSize(Wv,2) > 0)
			List3D += WvName+";"
		endif
	endfor
	
	if (DataChoice == 1)
		return List1D
	elseif (DataChoice == 2)
		return List2D
	elseif (DataChoice == 3)
		return List3D
	endif
End


Function EEMStackAnalysis()

	// ------- Select the EEM stack and one array of scalar parameters for analysis
	String EEMStackName 	= STRVarOrDefault("root:gEEMStackName","")
	Prompt EEMStackName, "Choose an EEM stack for correlation analysis", popup, ReturnFolderWaveList("root:",3)
	String EEMScalarName 	= STRVarOrDefault("root:gEEMScalarName","")
	Prompt EEMScalarName, "Choose 1D array of scalar variables", popup, ReturnFolderWaveList("root:",1)
	DoPrompt "EEM Stack Analysis", EEMStackName, EEMScalarName
	if (V_flag)
		return 0
	endif
	
	String /G root:gEEMStackName 	= EEMStackName
	String /G root:gEEMScalarName 	= EEMScalarName
	
	WAVE EEM 	= $("root:"+EEMStackName)
	WAVE Parameters = $("root:"+EEMScalarName)
	// ---------------------------------------------------
	
	
	Variable NumX	= DimSize(EEM,0)
	Variable NumY	= DimSize(EEM,1)
	Variable NumZ	= DimSize(EEM,2)
	
	// Options to set the number of EEM portions and the number of threads
	Variable nPortions 	= 5

	Variable nThreads 	= ThreadProcessorCount
//	Variable nThreads 	= 2
	
	// This global variable is needed for the MT approach
	Variable/G threadGroupID = ThreadGroupCreate(nThreads)
	Variable n, Duration, timeRef 	= startMSTimer
	
	Variable NNX 	= floor(NumX/nPortions)
	
	// These are dummy scalar data waves. 
//	Make /O/D/N=(NumZ) MainScalar=gnoise(1)
	
	// EEM-size arrays to hold the results of processing
	Variable NStatsResults=15
	Make /O/D/N=(NumX,NumY,NStatsResults) MTStatistics=NaN
	
	print " 		*** Analysis of EEM stack:",NameOfWave(EEM)," with dimensions",NumX,"x",NumY,"x",NumZ
	print " 			... subdividing the EEM into",nPortions,"pieces for parallel processing using",nthreads,"threads."
	
	// Create the threads
	for(n=0;n<nthreads;n+=1)
		ThreadStart threadGroupID,n,EEMWorkerFunc()
	endfor
	print " 			... initiated the threads."
	
	// Pass create waves and strings to pass to the threads
	for(n=0;n<nPortions;n+=1)
		NewDataFolder/S forThread

		// Need to note which part of the EEM this is
		Variable /G gEEMXStart = n*NNX
		
		// Transfer the scalar data
		Make /D/N=(NumZ) Scalar
		Scalar = Parameters
		
		// Subdivide the full EEM stack into a smaller piece
		Make /D/N=(NNX,NumY,NumZ) $("EEMn") /WAVE=EEMn
		EEMn[][][] 	= EEM[p+n*NNX][q][r]
		
		// Make a similar dimensioned array to hold the results of the Statistical Correlation analysis
		Make /O/D/N=(NNX,NumY,NStatsResults) Stats
		
		WAVEClear EEMn
		WAVEClear Scalar
		WAVEClear Stats
		
		ThreadGroupPutDF threadGroupID,:	// Send current data folder to input queue
	endfor
	print " 			... transferred the partial EEM data."

	
	Variable msgd=0
	for(n=0;n<nPortions;n+=1)
		do
			DFREF dfr= ThreadGroupGetDFR(threadGroupID,1000)	// Get results in free data folder
			if ( DatafolderRefStatus(dfr) == 0 )
				if (msgd == 0)
					Print "Main still waiting for worker thread results ...."
					msgd = 1
				endif
			else
				break
			endif
		while(1)
		
		WAVE Stats 		= dfr:StatsOut
		NVAR gXStart 	= dfr:gEEMXStart
		
		// Transfer the statistics portions to full statistics array
		MTStatistics[gXStart,gXStart+NNX-1][] 	= Stats[p-gXStart][q][0]
		
		// The 2 statements apparently redundant
		WAVEClear Stats
		KillDataFolder dfr
	endfor
	
	duration = stopMSTimer(timeRef)
	print " 	*** The multi-thread operation took", duration/1e6,"s"
	
	// This terminates the MyWorkerFunc by setting an abort flag
	Variable tstatus= ThreadGroupRelease(threadGroupID)
	if( tstatus == -2 )
		Print "Thread would not quit normally, had to force kill it. Restart Igor."
	endif
End

//Function StopAllTimers()
//	Variable i
//	for (i=0;i<10;i+=1)
//		stopMSTimer(i)
//	endfor
//End





