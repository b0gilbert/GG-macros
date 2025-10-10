#pragma rtGlobals=1		// Use modern global access method.

// 	This is how to display all the digits in a large integer: 
// 	printf "The time difference is: %d\r", 3412324589-3398968862

Menu "Spectra"
	SubMenu "Electrochemistry"
		"Set Chrono Start Time"
	End
End

Function InitializeElectrochemistry()
	
	NewDataFolder /O root:ELECTROCHEM
	
	MakeVariableIfNeeded("root:ELECTROCHEM:gChronoStartTime",0)
	MakeVariableIfNeeded("root:ELECTROCHEM:gChronoRestartFlag",0)
	
End

Function SetChronoStartTime()

	InitializeElectrochemistry()

	NVAR  	gChronoStartTime = root:ELECTROCHEM:gChronoStartTime
	
	Variable ChronoStartTime 	= gChronoStartTime
	Prompt ChronoStartTime, "Please enter the start time in Igor seconds"
	DoPrompt "Chronoamperometry start", ChronoStartTime
	if (V_flag == 1)
		// If the user pressed "Cancel", return without changing the global variable. 
		return 0
	endif
	
	Print " 		*** Reset the start time of all Chronoamperometry loads to", ChronoStartTime
	gChronoStartTime = gChronoStartTime
End

Function PARChronoLoadPreferences()

	InitializeElectrochemistry()
	
	NVAR  	gChronoStartTime 		= root:ELECTROCHEM:gChronoStartTime
	NVAR  	gChronoRestartFlag 		= root:ELECTROCHEM:gChronoRestartFlag

	Variable ChronoRestartFlag = gChronoRestartFlag
	Prompt ChronoRestartFlag, "Time axis offset options" , popup, "Do not offset time axis;New start time from (first) data file;Use current start time;"
	Variable ChronoStartTime = gChronoStartTime
	Prompt ChronoStartTime, "(Optional) Manually change the start time (Igor seconds)"
	DoPrompt "Chronoamperometry load preferences", ChronoRestartFlag, ChronoStartTime
	if (V_flag)
		// If user pressed "Cancel" returning "1" lets the loading routines know to stop. 
		return 1
	endif
	
	gChronoRestartFlag 	= ChronoRestartFlag
	if (ChronoRestartFlag == 3)
		Print " 		*** Reset the start time of all Chronoamperometry loads to", ChronoStartTime
		gChronoStartTime = ChronoStartTime
	endif
	
	return 0
End

		
// ***************************************************************************
// **************** 			Main routine for loading ALL TYPES OF PAR DATA
// ***************************************************************************
//
//		For all data files, load only the first data segment. 
//		For measurements performed vs time, the _axis wave will be in seconds from the start of the measurement. 
//		For ALL data files, create a new wave of name <sample_name>_time recording the absolute date and time in Igor seconds convention. 

Function LoadPARFile(FileName,DataName,SampleName, PARType,NLoaded)
	String FileName, DataName, SampleName, PARType
	Variable &NLoaded
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	String PathAndFileName 	= gPath2Data + FileName 
	
	NVAR  	gChronoStartTime 		= root:ELECTROCHEM:gChronoStartTime
	NVAR  	gChronoRestartFlag 		= root:ELECTROCHEM:gChronoRestartFlag
	
	String PARLine, HeaderLine, DataNote="", ActionNote="", IgorSecondsStr
	Variable IgorTime, IgorDate, IgorSeconds, Header=0, n=0
	Variable FileRefNum, NCols, ECol, IColold, ICol, tCol, VaCol, FreqCol, ErCol, EiCol, ZrCol, ZiCol
	
	// Make the appropriate waves
	if (cmpstr("EIS",PARType) == 0)
		Make /O/D/N=10000 Frequency, Z_Real, Z_Imag, Z_Mag,Z_Phase
	elseif ((cmpstr("CV",PARType) == 0) || (cmpstr("CV (segmented)",PARType) == 0))
		Make /O/D/N=10000 CV_V, CV_I, CV_t
	elseif (cmpstr("Chrono",PARType) == 0)
		Make /O/D/N=1000000 Chrono_s, Chrono_I, Chrono_t
	elseif (cmpstr("Open",PARType) == 0)
		Make /O/D/N=1000000 Open_s, Open_V , Open_t
	elseif (cmpstr("LSCV",PARType) == 0)
		Make /O/D/N=1000000 LSCV_s, LSCV_E, LSCV_I, LSCV_t
		Make /O/D/N=100 LSCV_V, LSCV_Q, LSCV_Ieq
	endif
	
	Open /R FileRefNum as PathAndFileName
	
	do
		FReadLine FileRefNum, PARLine
		if (strlen(PARLine) == 0)
			break	// No more lines in file.
		elseif ((Header) && (StrSearch(PARLine,"</Segment",0) > -1))
			break	// Stop reading in lines if we reach the end of a data segment. 
		endif
		
		// Read the time and date at which the data acquisition was started
		if (StrSearch(PARLine,"TimeAcquired=",0) > -1)
			IgorTime 	= IgorTimefromPARLine(PARLine)
		endif
		if (StrSearch(PARLine,"DateAcquired=",0) > -1)
			IgorDate 	= IgorDatefromPARLine(PARLine)
		endif
		IgorSeconds 	= IgorDate + IgorTime
		
		// Read in some information about the data acquisition
		if (StrSearch(PARLine,"<Action1>",0) > -1)
			ReadPARActionSettings(FileRefNum,PARLine,ActionNote)
		endif
		
		if ((!Header) && (StrSearch(PARLine,"Definition=",0) > -1))
		
			HeaderLine 	= ReplaceString(", ",PARLine,",")
			HeaderLine 	= ReplaceString(" ",HeaderLine,"_")
			NCols 		= ItemsInList(HeaderLine,",")
			
			// Look up the column numbers for each type of data
			ECol 		= WhichListItem("E(V)",HeaderLine,",")
			IColold 		= WhichListItem("I(V)",HeaderLine,",")	// <--- is this a stupid unit error in the PAR program?
			ICol 		= WhichListItem("I(A)",HeaderLine,",")	// <--- Yes! Corrected in a later version. 
			tCol 		= WhichListItem("Elapsed_Time(s)",HeaderLine,",")
			VaCol 		= WhichListItem("E_Applied(V)",HeaderLine,",")
			FreqCol 	= WhichListItem("Frequency(Hz)",HeaderLine,",")
			ErCol 		= WhichListItem("E_Real",HeaderLine,",")
			EiCol 		= WhichListItem("E_Imag",HeaderLine,",")
			ZrCol 		= WhichListItem("Z_Real",HeaderLine,",")
			ZiCol 		= WhichListItem("Z_Imag",HeaderLine,",")
			
			if (ICol<0)
				ICol 	= IColold
			endif
			
			// Read in the next line, which contains the first data values. 
			FReadLine FileRefNum, PARLine
			if (strlen(PARLine) == 0)
				break	// No data in file.   
			endif
			
			Header = 1
		endif
		
		if (Header) 	// We have read in the column information so, now read in the values. 
			if (cmpstr("EIS",PARType) == 0)
				Frequency[n] 	= str2num(StringFromList(FreqCol,PARLine,","))
				Z_Real[n] 		= str2num(StringFromList(ZrCol,PARLine,","))
				Z_Imag[n] 		= str2num(StringFromList(ZiCol,PARLine,","))
				Z_Mag[n] 		= cabs(cmplx(Z_Real[n],Z_Imag[n]))
				Z_Phase[n] 	= (360/(2*pi)) * imag(r2polar(cmplx(Z_Real[n],Z_Imag[n])))
			elseif ((cmpstr("CV",PARType) == 0) || (cmpstr("CV (segmented)",PARType) == 0))
				CV_V[n] 		= str2num(StringFromList(ECol,PARLine,","))
				CV_I[n] 		= str2num(StringFromList(ICol,PARLine,","))
				CV_t[n] 		= str2num(StringFromList(tCol,PARLine,","))
			elseif (cmpstr("Chrono",PARType) == 0)
				Chrono_s[n] 	= str2num(StringFromList(tCol,PARLine,","))
				Chrono_I[n] 	= str2num(StringFromList(ICol,PARLine,","))
				Chrono_t[n] 	= str2num(StringFromList(tCol,PARLine,","))
			elseif (cmpstr("Open",PARType) == 0)
				Open_s[n] 		= str2num(StringFromList(tCol,PARLine,","))
				Open_V[n] 		= str2num(StringFromList(ECol,PARLine,","))
				Open_t[n] 		= str2num(StringFromList(tCol,PARLine,","))
			elseif (cmpstr("LSCV",PARType) == 0)
				LSCV_s[n] 		= str2num(StringFromList(tCol,PARLine,","))
				LSCV_I[n] 		= str2num(StringFromList(ICol,PARLine,","))
				LSCV_E[n] 		= str2num(StringFromList(VaCol,PARLine,","))
				LSCV_t[n] 		= str2num(StringFromList(tCol,PARLine,","))
			endif
			
			n += 1
		endif
		
	while(1)
	
	Close FileRefNum
	
	if (n<2)
		Print " 		*** No data found in the file",FileName
		NLoaded = 0
		return 1
	elseif (n > 10000)
		Print " 	***** more than 10000 points"
	elseif (n > 1000000 )
		Print " 	***** more than 1000000 points"
	endif
	
	// Determine the Sample name
	if (CheckPARSampleName(PARType,SampleName) == 0)
		return 0
	endif
	
	// Record file information in the wavenote. 
	sprintf IgorSecondsStr, "%d", IgorSeconds
	DataNote 	= FileInfoWaveNote(gPath2Data,FileName)
	DataNote 	= DataNote + "AcquisitionStart="+IgorSecondsStr+"\r\r"
	DataNote 	= DataNote + "** PAR Data Acquisition parameters\r"
	DataNote 	= DataNote +ActionNote
	
	// Adopt the waves into memory
	AdoptPARDataWaves(PARType,SampleName,DataNote,n,IgorSeconds,NLoaded,CV_V,CV_I,CV_t,Chrono_s, Chrono_I, Chrono_t,Open_s, Open_V, Open_t,Frequency, Z_Real, Z_Imag, Z_Mag, Z_Phase,LSCV_t, LSCV_E, LSCV_I,LSCV_Q,LSCV_V, LSCV_Ieq)
	
	return 1
End

Function ReadPARActionSettings(FileRefNum,PARLine,ActionNote)
	Variable FileRefNum
	String PARLine, &ActionNote
	
	do
		FReadLine FileRefNum, PARLine
		if (strlen(PARLine) == 0)
			break
		elseif (StrSearch(PARLine,"</Action1>",0) > -1)
			break
		endif
		
		ActionNote 	= AddListItem(PARLine,ActionNote,";",0)
	while(1)
	
	ActionNote 	= ReplaceString(";",ActionNote,"")
End

Function CheckPARSampleName(PARType,SampleName)
	String PARType, &SampleName
	
	Variable MaxNameLength

	// Check the sample name is not too long. 	
	if (cmpstr("EIS",PARType) == 0)
		MaxNameLength 	= 16
	elseif (cmpstr("CV",PARType) == 0)
		MaxNameLength 	= 22
	elseif (cmpstr("CV (segmented)",PARType) == 0)
		MaxNameLength 	= 16
	elseif (cmpstr("Chrono",PARType) == 0)
		MaxNameLength 	= 22
	elseif (cmpstr("Open",PARType) == 0)
		MaxNameLength 	= 22
	elseif (cmpstr("LSCV",PARType) == 0)
		MaxNameLength 	= 16
	endif
	
	if (strlen(SampleName)>MaxNameLength)
		SampleName 	= ReplaceString("_",SampleName,"")
	endif
	if (strlen(SampleName)>MaxNameLength)
		SampleName 	= GetSampleName(SampleName,"","",0,1,0)
		if (cmpstr("_quit!_",SampleName) == 0)
			return 0
		endif
	endif
	
	return 1
End

Function AdoptPARDataWaves(PARType,SampleName,DataNote,n,IgorSeconds, NLoaded,CV_V,CV_I,CV_t,Chrono_s, Chrono_I, Chrono_t,Open_s, Open_V, Open_t,Frequency, Z_Real, Z_Imag, Z_Mag, Z_Phase,LSCV_t, LSCV_E, LSCV_I,LSCV_Q,LSCV_V, LSCV_Ieq)
	String PARType, SampleName, DataNote
	Variable n, IgorSeconds, &NLoaded
	Wave CV_V,CV_I,CV_t,Chrono_s, Chrono_I, Chrono_t,Open_s, Open_V, Open_t,Frequency, Z_Real, Z_Imag, Z_Mag, Z_Phase,LSCV_t, LSCV_E, LSCV_I,LSCV_Q,LSCV_V, LSCV_Ieq
	
	NLoaded = 1
	
	if (cmpstr("CV",PARType) == 0)
		Redimension /N=(n) CV_V,CV_I,CV_t
		CV_I *= 1000	// convert to mA
		CV_t += IgorSeconds
		SetScale d, CV_t[0], CV_t[n-1], "dat", CV_t
		SingleAxisDataErrorsFitLoad(SampleName,DataNote,CV_V,CV_I,$"",$"",$"",CV_t)
		KillWaves /Z  CV_V, CV_I,CV_t
		
	elseif (cmpstr("CV (segmented)",PARType) == 0)
		Redimension /N=(n) CV_V,CV_I,CV_t
		CV_I *= 1000	// convert to mA
		CV_t += IgorSeconds
		SetScale d, CV_t[0], CV_t[n-1], "dat", CV_t
		
		// *** This also loads the segments into their own Data Load folders ****
		NLoaded 	= SegmentCVData2(CV_V,CV_I,CV_t,SampleName,"root:SPECTRA:Import:",DataNote,1)
		
		KillWaves /Z  CV_V, CV_I,CV_t
		
	elseif (cmpstr("Chrono",PARType) == 0)
		Redimension /N=(n) Chrono_s, Chrono_I, Chrono_t
		Chrono_I *= 1000	// convert to mA
		Chrono_t += IgorSeconds
		SetScale d, Chrono_t[0], Chrono_t[n-1], "dat", Chrono_t
		
//		if (gChronoRestartFlag == 3)
//			Chrono_t += (IgorSeconds-gChronoStartTime)
//		elseif (gChronoRestartFlag == 2)
//			Print " 		*** Reset the start time of all Chronoamperometry loads to the start acquisition time of file",Filename,"at", IgorSeconds
//			gChronoStartTime 	= IgorSeconds
//			gChronoRestartFlag 	= 3
//		endif
		
		SingleAxisDataErrorsFitLoad(SampleName,DataNote,Chrono_s, Chrono_I,$"",$"",$"",Chrono_t)
		KillWaves /Z  Chrono_s, Chrono_I, Chrono_t
		
	elseif (cmpstr("Open",PARType) == 0)
		Redimension /N=(n) Open_s, Open_V, Open_t
		Open_t += IgorSeconds
		SetScale d, Open_t[0], Open_t[n-1], "dat", Open_t
		SingleAxisDataErrorsFitLoad(SampleName,DataNote,Open_s, Open_V,$"",$"",$"",Open_t)
		KillWaves /Z  Open_s, Open_V, Open_t
		
	elseif (cmpstr("EIS",PARType) == 0)
		Redimension /N=(n) Frequency, Z_Real, Z_Imag, Z_Mag, Z_Phase
		SingleAxisDataErrorsFitLoad(SampleName+"_Real",DataNote,Frequency,Z_Real,$"",$"",$"",$"")
		SingleAxisDataErrorsFitLoad(SampleName+"_Imag",DataNote,Frequency,Z_Imag,$"",$"",$"",$"")
		SingleAxisDataErrorsFitLoad(SampleName+"_Nyq",DataNote,Frequency,Z_Mag,$"",$"",$"",$"")
		SingleAxisDataErrorsFitLoad(SampleName+"_Phs",DataNote,Frequency,Z_Phase,$"",$"",$"",$"")
		
		// Take the negative of the imaginary part for the Bode plot. 
		Z_Imag *= -1
		SingleAxisDataErrorsFitLoad(SampleName+"_Bode",DataNote,Z_Real,Z_Imag,$"",$"",$"",$"")
		KillWaves /Z Frequency, Z_Real, Z_Imag, Z_Mag, Z_Phase
		
	elseif (cmpstr("LSCV",PARType) == 0)
		Redimension /N=(n) LSCV_s, LSCV_E, LSCV_I, LSCV_Q, LSCV_t
		LSCV_I *= 1000	// convert to mA
		LSCV_t += IgorSeconds
		SetScale d, LSCV_t[0], LSCV_t[n-1], "dat", LSCV_t
		
		// Now calculate other parameters, such as the final current
		AnalyzeLSCVData(LSCV_t, LSCV_E, LSCV_I,LSCV_Q,LSCV_V, LSCV_Ieq)
		
		SingleAxisDataErrorsFitLoad(SampleName+"_LSE",DataNote,LSCV_s, LSCV_E,$"",$"",$"",LSCV_t)
		SingleAxisDataErrorsFitLoad(SampleName+"_LSI",DataNote,LSCV_s, LSCV_I,$"",$"",$"",LSCV_t)
		SingleAxisDataErrorsFitLoad(SampleName+"_LSQ",DataNote,LSCV_s, LSCV_Q,$"",$"",$"",LSCV_t)
		SingleAxisDataErrorsFitLoad(SampleName+"_LCV",DataNote,LSCV_V, LSCV_Ieq,$"",$"",$"",LSCV_t)
		KillWaves /Z  LSCV_s, LSCV_t, LSCV_E, LSCV_I, LSCV_V, LSCV_Q, LSCV_Ieq
	endif
End

// ***************************************************************************
// **************** 			Segment the CV data into different up and down sweeps
// ***************************************************************************

// This creates a bunch of segments in a new folder. 
// It also optionally loads into new DataLoad folders. 
Function SegmentCVData2(Axis,Data,AcqT,SampleName,FolderName,DataNote,LoadFlag)
	Wave Axis,Data,AcqT
	String SampleName, FolderName, DataNote
	Variable LoadFlag
	
	// Does this work? 
	String DataName = SampleName
	if (strlen(SampleName) > 16)
		DataName = SampleName[0,16]
	endif
	
	String segName, segDataName, segAxisName, segTimeName, CVFolderName 	= ParseFilePath(2,FolderName,":",0,0)+"CV"
	NewDataFolder /O $CVFolderName
	
	Variable segStart, segStop, segNPts, StepSign, NextStepSign, Next2StepSign, Next3StepSign, Next4StepSign, Next5StepSign
	Variable i=0, SegmentNum=0, NPts = numpnts(Data)
	
	StepSign = sign(Axis[1] - Axis[0])
	do
		segStart 	= i
		do
			i+=1	
			if ((i+2) == NPts)
				break
			endif
			
			NextStepSign = sign(Axis[i+1] - Axis[i])
			if  (StepSign * NextStepSign < 1)
			
				Next2StepSign = sign(Axis[i+2] - Axis[i])
				if (Next2StepSign * StepSign < 1)	
					
					Next3StepSign = sign(Axis[i+3] - Axis[i])
					if(Next3StepSign * StepSign < 1)
					
						Next4StepSign = sign(Axis[i+4] - Axis[i])
						if(Next4StepSign * StepSign < 1)
						
							Next5StepSign = sign(Axis[i+5] - Axis[i])
							if(Next5StepSign * StepSign < 1)
							
							break
							
							endif					
						endif
					endif
				endif
			endif
			
		while(1)
		
		segStop 		= i
		segNPts 	= segStop - segStart + 1
		
		StepSign 		= NextStepSign
		
		if (segNPts > 2)
			SegmentNum += 1
			
			segName		= DataName + "_CV" + FrontPadVariable(SegmentNum,"0",2)
			segDataName 	= segName + "_data"
			segAxisName 	= segName + "_axis"
			segTimeName 	= segName + "_time"
			
			Make /O/D/N=(segNPts) $(ParseFilePath(2,CVFolderName,":",0,0)+segDataName) /WAVE=segData
			Make /O/D/N=(segNPts) $(ParseFilePath(2,CVFolderName,":",0,0)+segAxisName) /WAVE=segAxis
			Make /O/D/N=(segNPts) $(ParseFilePath(2,CVFolderName,":",0,0)+segTimeName) /WAVE=segTime
			
			segData[] 	= Data[segStart+p]
			segAxis[] 	= Axis[segStart+p]
			segTime[] 	= AcqT[segStart+p]
			
			Sort segAxis, segAxis, segData, segTime
			
			if (LoadFlag)
				SingleAxisDataErrorsFitLoad(segName,DataNote,segAxis,segData,$"",$"",$"",segTime)
			endif
		endif
	
	while(i < (NPts-2))
	
	return SegmentNum
End

// ***************************************************************************
// **************** 			do some simple calculations for the slow-scan CV data. **Obselete?**
// ***************************************************************************

Function AnalyzeLSCVData(LSCV_t, LSCV_E, LSCV_I,LSCV_Q, LSCV_V, LSCV_Ieq)
	Wave LSCV_t, LSCV_E, LSCV_I,LSCV_Q, LSCV_V, LSCV_Ieq
	
	Variable i, n=0, NPnts=numpnts(LSCV_t)
	Variable Istart=0, Istop
	
	for (i=1;i<NPnts;i+=1)
			
		if ((i==NPnts-1) || (abs(LSCV_E[i] - LSCV_E[i-1]) > 0.001))
			Istop 	= i-i
			
			// The applied potential for the previous segment. 
			LSCV_V[n] 		= LSCV_E[i-1]
			// The final 'equilibrium' current (averaged over 10 points). 
			LSCV_Ieq[n] 	= mean(LSCV_I,i-11,i-1)
			
			n 	+= 1
		endif
	endfor
	
	Redimension /N=(n) LSCV_V, LSCV_Ieq
	
	// Now integrate to calculate the total transfered charge
	Integrate /METH=1 LSCV_I /X=LSCV_t /D=LSCV_Q
End

// ***************************************************************************
// **************** 			Read TEMPERATURE LOGGER DATA
// ***************************************************************************

Function /T LoadTemperatureLog(FileName,SampleName)
	String FileName,SampleName
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	String FullDataName, FullAxisName, FullDataSigName, FullAcqTName, FullAxisSigName
	FullDataName 		= SampleName+"_data"
	FullAxisName 		= SampleName+"_axis"
	FullAcqTName 		= SampleName+"_time"
	FullDataSigName 	= FullDataName+"_sig"
	FullAxisSigName 	= FullAxisName+"_sig"
	
	Make /O/D/N=0 $FullAxisName /WAVE=Axis
	Make /O/D/N=0 $FullAcqTName /WAVE=AcqT
	Make /O/D/N=0 $FullDataName /WAVE=Data
	
	Variable j=0, refNum, pt, temperature, value, AMPM1, AMPM2
	String TempLine="", dStr, tStr, AMPM, sStr, AcqnStart
	
	 Open/R/Z=2 refNum as gPath2Data+FileName
	
	// Find the last of the header lines - look for # flag
	do
		FReadLine refNum, TempLine
		if (strlen(TempLine) == 0)
			Close refNum
			return ""
		elseif (StrSearch(TempLine,"#",0) > -1)
			break
		endif
	while(1)
				
	do
		FReadLine refNum, TempLine
		if (strlen(TempLine) == 0)
			break
		endif
		
		// 1, 08/01/12 06:26:58 PM,7 4.098, 2.97,,,,,
		sscanf TempLine, "%u,%s %s %c%c,%f,%f,%s", pt, dStr, tStr, AMPM1, AMPM2, temperature, value, sStr
		AMPM 	= num2char(AMPM1)+num2char(AMPM2)
		
		// Ignore points corresponding to Logging commands, not data acquisition. 
		if (temperature != 0)
			j += 1
			ReDimension /N=(j) Axis, Data, AcqT
			
			AcqT[j-1] 	= DateStringToSecs(dStr+" "+tStr+" "+AMPM)
			Data[j-1] 	= temperature
			
		endif
	
	while(1)
	Close refNum
	
	// Record file information in the wavenote. 
	String DataNote 	= FileInfoWaveNote(gPath2Data,FileName)
	Note /K Data, DataNote
	
	// Append header information to a wave note
	sprintf AcqnStart, "%d", AcqT[0]
	Note Data, "AcquisitionStart="+AcqnStart
	
	// The AXIS is the number of seconds since the start of the acquisition
	// The ACQN is the date+time in Igor seconds convention
	Make /O/D/N=(j) $FullDataSigName, $FullAxisSigName
	Axis = AcqT - AcqT[0]

	return SampleName
End

// Look up the file creation information
Function /T FileInfoWaveNote(Path2Data,FileName)
	String Path2Data,FileName
	
	String DataNote, PathAndFileName = Path2Data+FileName
	GetFileFolderInfo /Z/Q PathAndFileName
	
//	DataNote 	= "FileName="+FileName + "\r"
	DataNote 	= FileName + "\r"
	DataNote 	= DataNote + "FilePath="+Path2Data + "\r"
	DataNote 	= DataNote + "CreationDate="+Secs2Date(V_creationDate,-2)+"\r"
	DataNote 	= DataNote + "CreationTime="+Secs2Time(V_creationDate,3)+"\r"
	
	return DataNote
End

// ***************************************************************************
// **************** 			DATE and TIME Routines
// ***************************************************************************

Function /T WaveNoteStrByKey(WaveNote,Key)
	String WaveNote, Key
	
	// Make the wavenote into a list. 
	WaveNote 	= ReplaceString("\r",WaveNote,";")
	// Look for the key
	return StringByKey(Key,WaveNote,"=",";")
End

modDate
DateToJulian

Function ParseWaveNote(WaveNote,Key)
	String WaveNote, Key
	
	String WaveLine
	Variable i=1
	
	do
		WaveLine 	= ReturnTextBeforeNthChar(WaveNote,"\r",i)
		WaveNote 	= ReplaceString(WaveLine,WaveNote,"",0,1)
		if (StrSearch(WaveLine,Key,0) > -1)
			return  ReturnLastNumber(WaveLine)
		endif
		i += 1
	while(strlen(WaveLine) > 0)

	return NaN
End

// User by the PAR loader
Function IgorDatefromPARLine(PARLine)
	String PARLine

	String PARDate, AcqnDay, MonthDate, MonthOnly
	Variable IgorDate, AcqnYear, AcqnMonth, DateOnly, AcqnDate
	
	PARDate 	= ReplaceString("\r",ReplaceString("DateAcquired=",PARLine,""),"")
	AcqnDay 	= StringFromList(0,PARDate,",")
	MonthDate 	= ReplaceString(" ",StringFromList(1,PARDate,","),"")
	MonthOnly 	= ReturnTextBeforeNumber(MonthDate)
	DateOnly 	= ReturnLastNumber(MonthDate)
	AcqnMonth 	= MonthNameToNumber(MonthOnly)
	AcqnDate 	= str2num(ReturnTextAfterNthChar(StringFromList(1,PARDate,",")," ",2))
	AcqnYear 	= str2num(StringFromList(2,PARDate,","))
	
	IgorDate 	= date2secs(AcqnYear,AcqnMonth,AcqnDate)
	
	return IgorDate
End	
		
// User by the PAR loader	
Function IgorTimefromPARLine(PARLine)
	String PARLine

	String PARTime, AcqnHour, AcqnMin, AcqnSec, AcqnAMPM
	Variable IgorTime
	
	PARTime 	= ReplaceString("\r",ReplaceString("TimeAcquired=",PARLine,""),"")
	AcqnHour 	= StringFromList(0,PARTime,":")
	AcqnMin 	= StringFromList(1,PARTime,":")
	AcqnSec 	= ReturnTextBeforeNthChar(StringFromList(2,PARTime,":")," ",1)
	AcqnAMPM 	= ReturnTextAfterNthChar(StringFromList(2,PARTime,":")," ",1)	// Changed "AcqnPM" to "AcqnAMPM",
																					// both here and above in Function section
	if (cmpstr(AcqnHour,"12") == 0)							//
		if (cmpstr(AcqnAMPM,"AM") == 0)						//
			AcqnHour = num2str(str2num(AcqnHour)-12)		// Here is the section I added, Ben
		elseif(cmpstr(AcqnAMPM,"PM") == 0)					//
		endif													//
	
	elseif (cmpstr(AcqnAMPM,"PM") == 0)
		AcqnHour = num2str(str2num(AcqnHour)+12)
	endif
	
	IgorTime 	= TimeStr2Secs(AcqnHour+":"+AcqnMin+":"+AcqnSec)
	
	return IgorTime
End

// Used by the Temperature log loader
// Example date and time: 	08/01/12 07:11:58 PM
Function DateStringToSecs(dStr)
	String dStr
	
	String AMPM
	Variable dDay, dMonth, dYear, dHour, dMin, dSec
	Variable IgorDate, IgorTime, IgorSeconds
	
	sscanf dStr, "%u/%u/%u %u:%u:%u %s", dMonth, dDay, dYear, dHour, dMin, dSec, AMPM
	
	// convert from '12 to 2012
	dYear += 2000
	
	IgorDate 		= date2secs(dYear,dMonth,dDay)
	IgorTime 		= Time2Secs(dHour,dMin,dSec,AMPM)
	IgorSeconds 	= IgorDate + IgorTime
	
	if (0)
		print 	" 	Input was",dStr
		print 	" 	Conversion",IgorSeconds
		Print	" 	Data check",secs2date(IgorSeconds,0)
		Print	" 	Data check",secs2time(IgorSeconds,1)
	endif
	
	return IgorSeconds
End

Function TestTimeParsing(PARTime)
	String PARTime
	
	Variable IgorTime
	String AcqnHour, AcqnMin, AcqnSec, AcqnAMPM

	AcqnHour 	= StringFromList(0,PARTime,":")
	AcqnMin 	= StringFromList(1,PARTime,":")
	AcqnSec 	= ReturnTextBeforeNthChar(StringFromList(2,PARTime,":")," ",1)
	AcqnAMPM 	= ReturnTextAfterNthChar(StringFromList(2,PARTime,":")," ",1)
	
	if (cmpstr(AcqnHour,"12") == 0)							//
		if (cmpstr(AcqnAMPM,"AM") == 0)						//
			AcqnHour = num2str(str2num(AcqnHour)-12)		// Here is the section I added, Ben
		elseif(cmpstr(AcqnAMPM,"PM") == 0)					//
		endif													//
	
	elseif (cmpstr(AcqnAMPM,"PM") == 0)
		AcqnHour = num2str(str2num(AcqnHour)+12)
	endif
	
	IgorTime 	= TimeStr2Secs(AcqnHour+":"+AcqnMin+":"+AcqnSec)
	
	Print IgorTime
End