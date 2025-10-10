#pragma rtGlobals=1		// Use modern global access method.


Menu "Spectra"
	SubMenu "SPEC Files"
		"Scans From SPECFile"
		"Scans From SPEC Summary"
		"SPEC Table"
	End
End


// ***************************************************************************
// **************** 			Extract bunch and orbit specific data from SAVED-DATA file(s)
// ***************************************************************************

// 	Header structure: 

//#F saveddata-00089
//#E 1331605672
//#D Mon Mar 12 21:27:52 2012
//
//#S 90 qavrgscan
//#D Mon Mar 12 21:27:52 2012
//#N 247
//#L Energy  time  MON  c0o0b0  ...
// 	

	MakeVariableIfNeeded("root:SPECTRA:SPEC:gNSampleAPDs",1)
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gSaveDataBlock",1)
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gMinNumPoints",0)
	MakeStringIfNeeded("root:SPECTRA:SPEC:gSaveDataNaming","file - signal - bunch - orbits")
	NVAR gNSampleAPDs 		= root:SPECTRA:SPEC:gNSampleAPDs
	NVAR gSaveDataBlock 		= root:SPECTRA:SPEC:gSaveDataBlock
	NVAR gMinNumPoints 		= root:SPECTRA:SPEC:gMinNumPoints
	SVAR gSaveDataNaming 		= root:SPECTRA:SPEC:gSaveDataNaming
	
	Variable NSampleAPDs = gNSampleAPDs
	Prompt NSampleAPDs,"# sample APDs", popup, "1;2;"
	Variable MinNumPoints = gMinNumPoints
	Prompt MinNumPoints,"Min # points"
	String SaveDataNaming = gSaveDataNaming
	Prompt SaveDataNaming, "Naming style", popup, "file - orbits - bunch  - signal;file - orbits - signal;file - signal;"

	gMinNumPoints 	= MinNumPoints
	gNSampleAPDs 		= NSampleAPDs
	gSaveDataNaming 	= SaveDataNaming
	
		
		if (NumPoints < gMinNumPoints)
			Print "  *** Skip loading",FileName,"as there are not enough points"
			return 0
		endif
		Make /FREE/D/N=(NumPoints-gSkipPoints) Average
		Average = 0

		
		// Find the first column
		FirstCol 	= WhichListItem("c0o0b0",ColumnNameList)

// Assume that channel 0 is always the Izero
// All subsequent channels are sample detectors
Function PromptForSaveDataParams()
	
	NewDataFolder /O root:SPECTRA:SPEC
	
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gSaveDataSecs",-1)
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gSaveDataChoice",1)
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gNormalize",1)
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gSglChannels",1)
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gBunchNumber",0)
	MakeVariableIfNeeded("root:SPECTRA:SPEC:gSkipPoints",0)
	
	MakeStringIfNeeded("root:SPECTRA:SPEC:gOrbitRange","1 - 2")
	MakeStringIfNeeded("root:SPECTRA:SPEC:gSaveDataSPECName","Fe11")
	MakeStringIfNeeded("root:SPECTRA:SPEC:gSaveDataSignal","PrM")
	
	NVAR gSaveDataSecs 		= root:SPECTRA:SPEC:gSaveDataSecs
	NVAR gNormalize 			= root:SPECTRA:SPEC:gNormalize
	NVAR gSglChannels 			= root:SPECTRA:SPEC:gSglChannels
	NVAR gSaveDataChoice 		= root:SPECTRA:SPEC:gSaveDataChoice
	NVAR gBunchNumber 		= root:SPECTRA:SPEC:gBunchNumber
	NVAR gSkipPoints 			= root:SPECTRA:SPEC:gSkipPoints
	
	SVAR gOrbitRange 			= root:SPECTRA:SPEC:gOrbitRange
	SVAR gSaveDataSignal 		= root:SPECTRA:SPEC:gSaveDataSignal
	SVAR gSaveDataSPECName 	= root:SPECTRA:SPEC:gSaveDataSPECName
	
	Variable BunchNumber 	= gBunchNumber
	Prompt BunchNumber, "Enter bunch number"
	String OrbitRange 	= gOrbitRange
	Prompt OrbitRange, "Enter orbit number or range"
	Variable SkipPoints 	= gSkipPoints
	Prompt SkipPoints, "# initial points to skip"
	
	Variable SglChannels = gSglChannels
	Prompt SglChannels, "Adopt all channels?", popup, "no;averaged only;all"
	Variable Normalize = gNormalize
	Prompt Normalize, "Normalize data?", popup, "yes;no;"
	
	String SaveDataSPECName = gSaveDataSPECName
	Prompt SaveDataSPECName, "SPEC file name"
	String SaveDataSignal = gSaveDataSignal
	Prompt SaveDataSignal, "Signal name"
	DoPrompt " Extract signal from bunch(es)", BunchNumber, OrbitRange, SkipPoints, SglChannels, Normalize, SaveDataSPECName, SaveDataSignal
	if (V_Flag)
		return 1
	endif
	
	gBunchNumber 		= BunchNumber
	gOrbitRange			= OrbitRange
	gSkipPoints 		= SkipPoints
	gSglChannels 		= SglChannels
	gNormalize			= Normalize
	gSaveDataSignal 	= SaveDataSignal
	gSaveDataSPECName = SaveDataSPECName
	
	// Reset the start date and time of the first scan to zero 
	gSaveDataSecs 		= -1
	
	Variable Orbit1, Orbit2, NOrbits
	RangeFromTextInput(gOrbitRange,Orbit1,Orbit2,NOrbits)
	
	if (NOrbits==1)
		Print " *** Extracting saved-data from bunch",gBunchNumber," and orbit",Orbit1
	else
		Print " *** Extracting saved-data from bunch",gBunchNumber," and orbits",Orbit1," - ",Orbit2
	endif
	
	return 0
End

// Parse one or a range of values given in the style 1 - 5
Function RangeFromTextInput(Range,RangeMin,RangeMax,NRange)
	String Range
	Variable &RangeMin,&RangeMax, &NRange
	
	Variable Num1, Num2, NNum
	
	NNum 	= CountNumbersInString(Range,0)
	Num1 	= ReturnNthNumber(Range,1)
	Num2 	= ReturnNthNumber(Range,2)
	
	if (NNum == 0)
		NRange 		= 0
		RangeMin 	= NaN
		RangeMax 	= NaN
	elseif (NNum == 1)
		NRange 		= 1
		RangeMin 	= Num1
		RangeMax 	= Num1
	else
		NRange 		= abs(Num2 - Num1)+1
		RangeMin 	= min(Num1,Num2)
		RangeMax 	= max(Num1,Num2)
	endif
End

Function /T CleanUpFileLine(FileLine, Descriptor)
	String FileLine, Descriptor
	
	// Remove the line descriptor flag
	FileLine 	= ReplaceString(Descriptor,FileLine,"",1,1)
	FileLine 	= StripLeadingChars(FileLine," ")

	// Strip trailing carriage return(s)
	FileLine 	= ReplaceString("\r",FileLine,"")
	FileLine 	= ReplaceString("\n",FileLine,"")
	
	return FileLine
End

// To avoid overwriting data, saved-data files with the same filenumbers generated on the same data are appended to the text file. 
// It's currently tricky to extract the correct one, however, as the associated SPEC filename is not included. 
//	Options: 
// 	1. If the date and time of a previous file is given, automatically extract the next sequential one from the current file. 
// 	2. If no previous date and time is given, and there are multiple blocks, prompt the user to chose one. 

Function /T SavedDataFileContents(PathAndFileName,FileDate,FirstFileSecs,HeaderLine,NColumns)
	String PathAndFileName, &FileDate
	Variable FirstFileSecs, &HeaderLine, &NColumns
	
	NVAR gSaveDataSecs 		= root:SPECTRA:SPEC:gSaveDataSecs
	
	String FileLine, ColumnList, ScanDateList="", ScanSecsList ="", ScanLineList="", ScanNColList="", ScanPosList=""
	String DayStr,MonthStr,HMSStr, ScanSecsStr, ColPosStr
	Variable looping=1, lineNum=0, refNum = 0, nScans=0, CorrectScan=-1, NCols, ColPos
	Variable DDate, Year, Month, IgorDate, IgorTime, ScanSecs
	
	Open/R refNum as PathAndFileName
	if (refNum == 0)
		return ""
	endif
	
	do	// First find a date line. 
		FReadLine refNum, FileLine
		if (strlen(FileLine) == 0)
			break
		endif
		lineNum += 1
		
		// Note: This is awkward as there are 2 #D date lines for each block of data! 
		if (cmpstr("#D",FileLine[0,1]) == 0)
			// #D Mon Mar 12 21:27:52 2012
			FileLine 		= CleanUpFileLine(FileLine, "#D")
			
			sscanf FileLine, "%s%s %i %s %i", DayStr,MonthStr,DDate,HMSStr,Year
			Month 			= MonthNameToNumber(MonthStr)
			IgorDate 		= date2secs(Year,Month,DDate)
			IgorTime 		= TimeStr2Secs(HMSStr)
			ScanSecs		= IgorDate + IgorTime
			sprintf ScanSecsStr, "%12d", ScanSecs
			ScanSecsList 	= ScanSecsList + ScanSecsStr + ";"
			ScanDateList 	= ScanDateList + FileLine + ";"
			
			do	// Now read the subsequent Number of Columns line
				FReadLine refNum, FileLine
				lineNum += 1
			while(cmpstr("#N",FileLine[0,1]) != 0)
			ScanNColList 	= ScanNColList + CleanUpFileLine(FileLine, "#N")+";"
		
			do	// Now find the Column Headings line
				FStatus refNum
				ColPos 	= V_filePos
				FReadLine refNum, FileLine
				lineNum += 1
			while(cmpstr("#L",FileLine[0,1]) != 0)
			
			sprintf ColPosStr, "%d", ColPos
			ScanPosList 	= ScanPosList + ColPosStr + ";"
			ScanLineList 	= ScanLineList + num2str(lineNum) + ";"
			
			nScans += 1
			// If we have been given the date and time of a starting scan in FirstFileSecs, ....
			// ... then the correct scan to extract is the first one AFTER that start. 
			if ((CorrectScan == -1) && (FirstFileSecs > -1))
				if (ScanSecs > FirstFileSecs)
					looping 			= 0
					CorrectScan 	= nScans
				endif
			endif
		endif
	while(looping)
	
	if (nScans ==0)
		return ""
	elseif (nScans ==1)
		CorrectScan = 1
	elseif (CorrectScan < 0)
		Prompt CorrectScan, "Choose the correct scan date & time", popup, ScanDateList
		DoPrompt "Multiple scan data in file", CorrectScan
		if (V_flag)
			return ""
		endif
		Print " 		 ... For multiple extraction, the starting date and time is",StringFromList(CorrectScan-1,ScanDateList)
		
		// Save the starting time in Igor seconds
		gSaveDataSecs 	= str2num(StringFromList(CorrectScan-1,ScanSecsList))
	endif
	
	FileDate 		= StringFromList(CorrectScan-1,ScanDateList)
	HeaderLine 		= str2num(StringFromList(CorrectScan-1,ScanLineList))
	ColPos 			= str2num(StringFromList(CorrectScan-1,ScanPosList))
	NCols 			= str2num(StringFromList(CorrectScan-1,ScanNColList))
	
	FSetPos refNum, ColPos
	FReadLine refNum, FileLine
	FileLine 	= CleanUpFileLine(FileLine, "#L")		
	ColumnList 	= ReturnHeadings1(FileLine+" "," ",0,NCols)
	
	return ColumnList
End

Function LoadSavedDataHybridMode(FileName,SampleName,FolderNumber,NLoaded)
	String FileName, SampleName
	Variable FolderNumber, &NLoaded
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	NVAR gSaveDataSecs 		= root:SPECTRA:SPEC:gSaveDataSecs
	NVAR gSaveDataChoice 		= root:SPECTRA:SPEC:gSaveDataChoice
	NVAR gBunch 				= root:SPECTRA:SPEC:gBunchNumber
	NVAR gSaveDataAvgFlag 		= root:SPECTRA:SPEC:gSaveDataAvgFlag
	NVAR gBunchNumber 		= root:SPECTRA:SPEC:gBunchNumber
	NVAR gSglChannels 			= root:SPECTRA:SPEC:gSglChannels
	NVAR gNormalize 			= root:SPECTRA:SPEC:gNormalize
	NVAR gSkipPoints 			= root:SPECTRA:SPEC:gSkipPoints
	SVAR gOrbitRange 			= root:SPECTRA:SPEC:gOrbitRange
	SVAR gSaveDataSignal 		= root:SPECTRA:SPEC:gSaveDataSignal
	SVAR gSPECName 			= root:SPECTRA:SPEC:gSaveDataSPECName
	
	String IzeroColName, IzeroColList="", DataColName, DataColList=""
	Variable EnergyCol, DataCol, IzeroCol
	
	String FileDate, SaveName, SPECFolder="root:SPECTRA:SPEC", PathAndFileName = gPath2Data + FileName
	String SpectrumName, ColumnNameList="", SPECNote
	Variable i, n, channel=0, LookForData=1, NChannels, SpecNum, NumPoints, NumTitles, NumCols, ColNum, LoadError
	
	// Parse the range in orbit values
	Variable Orbit1, Orbit2, NOrbits
	RangeFromTextInput(gOrbitRange,Orbit1,Orbit2,NOrbits)
	
	SetDataFolder root:SPECTRA:SPEC
		KillWaves /A/Z
		
		// *!*!		IMPORTANT NOTE ON SCAN AND FILE NUMBERING
		// *!*! 		The scan numbers reported in qavrg are one more than the corresponding SPEC file numbers. 
		// *!*! 		Within the save-data files, the #S header line reports the qavrg scan number = SPEC scan number + 1. 
		// *!*! 		However, the save-data FILE NUMBER, flag #F,  is equal to the SPEC scan number. 
		SpecNum 		= ReturnLastNumber(FileName)
		SaveName 		= gSPECName + "_" + num2str(SpecNum)
		
		Variable FileSecs,HeaderLine,NColumns
		ColumnNameList 	= SavedDataFileContents(PathAndFileName,FileDate,gSaveDataSecs,HeaderLine,NColumns)
		
		// Load all the columns as a matrix
		Loadwave /M/Q/A=column/O/D/G/L={0,HeaderLine+1,0,0,0} PathAndFileName	// <--- General text format
		WAVE SPECMatrix = $(StringFromList(0,S_waveNames))
		
		LoadError 	= GetRTError(1)
		if (LoadError)
			Print "  ***No data found in",FileName
			return 0
		endif
		
		NumPoints 	= DimSize(column0,0)
		NumCols 	= DimSize(column0,1)
		NumTitles 	= ItemsInList(ColumnNameList)
		if (NumTitles != NumCols)
			Print " *** Could not load as many column names (",NumTitles,") as there are columns (",NumCols,"): "//, ColumnNames
			return 0
		endif
		
		Variable NExtractPts 	= NumPoints-gSkipPoints
		Make /FREE/D/N=(NOrbits) Average
		
		// Cannot use FREE waves if I want to Adopt them
		Make /O/D/N=(NExtractPts) Axis
		Make /O/D/N=(NExtractPts) Column
		Make /O/D/N=(NExtractPts) Izero
		Make /O/D/N=(NExtractPts) IzeroErrors
		Make /O/D/N=(NExtractPts) Data
		Make /O/D/N=(NExtractPts) DataErrors
		Make /O/D/N=(NExtractPts) Normd=0
		Make /O/D/N=(NExtractPts) NormdErrors
		
		Make /O/D/N=(NExtractPts, NOrbits) IzeroMatrix
		Data 	= 0
		Izero 	= 0
		
		// The Energy axis
		EnergyCol 	= WhichListItem("Energy",ColumnNameList)
		if (EnergyCol == -1)
			Print " *** Could not find the energy axis"
			return 0
		endif
		
		Axis[] 	= SPECMatrix[p+gSkipPoints][EnergyCol]
		WaveStats /Q Axis
		if (abs(V_sdev) <  1e-9)
			Print " *** Energy axis is constant"
			return 0
		endif
		
		// The Izero channel (0) for a specific bunch and all orbits
		for (i=Orbit1;i<=Orbit2;i+=1)
			IzeroColName 	= "c0o"+num2str(i)+"b"+num2str(gBunch)
			IzeroColList 	= IzeroColList + IzeroColName + ";"
			IzeroCol 		= WhichListItem(IzeroColName,ColumnNameList)
			Column[] 		= SPECMatrix[p+gSkipPoints][IzeroCol]
			
			if (gSglChannels == 3)		// Adopt all individual channels
				SpectrumName 	= SaveName + "_c0" + NumericalSuffix("_o",i, i) + NumericalSuffix("_b",gBunchNumber,gBunchNumber)
				Note /K Column, ReturnSavedDataNote(FileName,gPath2Data,FileDate,IzeroColName)
				AdoptAxisAndDataFromMemory("Axis","",SPECFolder,"Column","",SPECFolder,SpectrumName,"",0,0,1)
			endif
			
			// Append to the averaged Izero
			IzeroMatrix[][i-Orbit1] = Column[p]
		endfor
		
		// The sample channels (1 - n) for a specific bunch and all orbits
		do
			channel += 1
			
			Make /O/D/N=(NExtractPts,NOrbits) $("root:SPECTRA:SPEC:DataMatrix"+num2str(channel)) /WAVE=DataMatrix
			
			for (i=Orbit1;i<=Orbit2;i+=1)
				DataColName 	= "c"+num2str(channel)+"o"+num2str(i)+"b"+num2str(gBunch)
				DataCol 			= WhichListItem(DataColName,ColumnNameList)
				if (DataCol == -1)
					channel -= 1
					LookForData=0
					break
				endif
				DataColList 	= DataColList + DataColName + ";"
				Column[] 	= SPECMatrix[p+gSkipPoints][DataCol]
			
				if (gSglChannels == 3)		// Adopt all individual channels
					SpectrumName 	= SaveName + "_c" + num2str(channel) + NumericalSuffix("_o",i, i) + NumericalSuffix("_b",gBunchNumber,gBunchNumber)
					Note /K Column, ReturnSavedDataNote(FileName,gPath2Data,FileDate,DataColName)
					AdoptAxisAndDataFromMemory("Axis","",SPECFolder,"Column","",SPECFolder,SpectrumName,"",0,0,1)
				endif
			
				// Append to the averaged Data
				DataMatrix[][i-Orbit1] = Column[p]
			endfor
		while(LookForData)
		
		// Not sure how best to propagate errors. 
		Make /FREE/D/N=(NExtractPts, channel) Average2
		
		for (i=0;i<NExtractPts;i+=1)			// Calculate the single averaged Izero
			Average[] 	= IzeroMatrix[i][p]
			WaveStats /Q Average
			Izero[i] 		= V_avg
			IzeroErrors[i] 	= V_sdev
		endfor

		if (gSglChannels >1)					// Adopt averaged Izero
			SpectrumName 	= SaveName + "_c0" + NumericalSuffix("_o",Orbit1, Orbit2) + NumericalSuffix("_b",gBunchNumber,gBunchNumber)
			Note /K Izero, ReturnSavedDataNote(FileName,gPath2Data,FileDate,IzeroColList)
			AdoptAxisAndDataFromMemory("Axis","",SPECFolder,"Izero","IzeroErrors",SPECFolder,SpectrumName,"",0,0,1)				
		endif
		
		for (n=1;n<=channel;n+=1)			// Calculate the averaged data signal for each channel
			WAVE DataMatrix 	= $("root:SPECTRA:SPEC:DataMatrix"+num2str(n))
			for (i=0;i<NExtractPts;i+=1)
				Average[] 	= DataMatrix[i][p]
				WaveStats /Q Average
				Data[i] 			= V_avg
				DataErrors[i] 	= V_sdev
			endfor
			
			if (gSglChannels >1) 				// Adopt averaged sample channel
				SpectrumName 	= SaveName + "_c" + num2str(channel) + NumericalSuffix("_o",Orbit1, Orbit2) + NumericalSuffix("_b",gBunchNumber,gBunchNumber)
				Note /K Data, ReturnSavedDataNote(FileName,gPath2Data,FileDate,DataColList)
				AdoptAxisAndDataFromMemory("Axis","",SPECFolder,"Data","DataErrors",SPECFolder,SpectrumName,"",0,0,1)
			endif
			
			Normd += Data
		endfor
		
		if (gNormalize==1) 					// Calculate and adopt averaged sample channel
			Normd 	/= channel
			Normd 	/= Izero
		
			SpectrumName = SaveName + NumericalSuffix("_o",Orbit1, Orbit2) + NumericalSuffix("_b",gBunchNumber,gBunchNumber) + "_"+ gSaveDataSignal
			Note /K Normd, ReturnSavedDataNote(FileName,gPath2Data,FileDate,DataColList)
			AdoptAxisAndDataFromMemory("Axis","",SPECFolder,"Normd","",SPECFolder,SpectrumName,"",0,0,1)
		endif
		
		KillWaves /A/Z
	SetDataFolder root:
	
	return 	1
End

Function /T ReturnSavedDataNote(FileName,Path2Data,FileDate,ExtractedList)
	String FileName,Path2Data,FileDate,ExtractedList
	
	String SPECNote

	sprintf SPECNote,"%s\r", "Saved-data file: "+FileName
	SPECNote 	= SPECNote + "Path to saved-data file: " +Path2Data+ "\r"
	SPECNote 	= SPECNote + "Acquisition time: " + FileDate + "\r"
	SPECNote 	= SPECNote + "Columns from saved-data file: " + ExtractedList + "\r"
	
	return SPECNote
End

Function /T NumericalSuffix(prefix,Value1,Value2)
	String prefix
	Variable Value1,Value2
	
	if (Value1 == Value2)
		return prefix +num2str(Value1)
	else
		return prefix +num2str(Value1)+"_"+num2str(Value2)
	endif
End

//Function /T ReturnSaveDataName(SpecNum,Bunch, Orbit1, Orbit2)
//	Variable SpecNum, Bunch, Orbit1, Orbit2
//
//	SVAR gSaveDataSPECName 	= root:SPECTRA:SPEC:gSaveDataSPECName
//	SVAR gSaveDataNaming 		= root:SPECTRA:SPEC:gSaveDataNaming
//	SVAR gSaveDataSignal 		= root:SPECTRA:SPEC:gSaveDataSignal
//
//	String SaveName = gSaveDataSPECName + "_" + num2str(SpecNum)
//	
//	if (StrSearch(gSaveDataNaming,"orbit",0) > -1)
//		if (Orbit1 == Orbit2)
//			SaveName 	= SaveName+"_o"+num2str(Orbit1)
//		else
//			SaveName 	= SaveName+"_o"+num2str(Orbit1)+"_"+"o"+num2str(Orbit2)
//		endif
//	endif
//	
//	if (StrSearch(gSaveDataNaming,"bunch",0) > -1)
//		SaveName 	= SaveName + "_b" + num2str(Bunch)
//	endif
//	
//	if (StrSearch(gSaveDataNaming,"signal",0) > -1)
//		SaveName 	= SaveName + "_" + gSaveDataSignal
//	endif
//	
//	return SaveName
//End

function trialfn()

	Make/O root:trial /WAVE=trial
	
	// A maximum 31 chars in name is OK. 
	Duplicate /O trial, $("x123456789012345678901234567890")
	
return 0
End


// ***************************************************************************
// **************** 			Convert SPEC text files into separate normalized spectra
// ***************************************************************************
// 	In order to avoid loading entire SPEC files into memory, it (1) creates a scan list, 
// 	then (2) extracts scans according to matching criteria. A bit slow for large SPEC files, as step (1) 
// 	is repeated each time. 

Proc ScansFromSPECFile()

	Variable FileRefNum
	
	NewDataFolder/O/S root:SPECTRA:SPEC
	
		// Step 1: Summarize the relevant scans in the SPEC file
		FileRefNum 	=	SPECCondense()
		
		if (FileRefNum >0)
			// Step 2: Extract and save the relevant scans in the SPEC file
			SPECScansFromSPEC(FileRefNum)
		endif
		
	SetDataFolder root:
End

Function ScansFromSPECSummary()

	SVAR gSpecFile 		= root:SPECTRA:SPEC:gSpecFile
	
	Variable FileRefNum
	
	PathInfo SPECPath
	if (V_flag==0)
		Print " *** Please first find the spec file and extract scans."
		return 0
	endif
	
	Open /Z/R/P=SPECPath FileRefNum as gSpecFile
	if (V_flag < 0)
		Print " *** Spec file cannot be found on hard drive. Please run 'Scans from SPEC file'"
		return 0
	endif
	
	SetDataFolder root:SPECTRA:SPEC

		// Step 2: Extract and save the relevant scans in the SPEC file
		SPECScansFromSPEC(FileRefNum)
		
	SetDataFolder root:
End

Function SPECTable()

	WAVE SPECScanPos 		= root:SPECTRA:SPEC:SPECScanPos
	WAVE /T SPECHeaders 	= root:SPECTRA:SPEC:SPECHeaders
	WAVE /T SPECScanInfo 	= root:SPECTRA:SPEC:SPECScanInfo
	
	if (WaveExists(SPECScanPos))
		Edit /K=1/W=(405,365,1530,810) SPECScanPos,SPECHeaders,SPECScanInfo as "SPEC Scan Summaries"
		ModifyTable format(Point)=1,width(SPECHeaders)=582,width(SPECScanInfo)=178
	endif
End


// ***************************************************************************
// **************** 			Part 1: Summarize the relevant scans in the SPEC file
// ***************************************************************************

Function SPECCondense()
	
	Variable FileRefNum, NSpectra, ScreenFileRefNum
	String SPECSpecName, SPECHeaderName, EndOfScan
	String message, SPECLine, SpecFile, ScreenFile, SpecHDFolder, ScreenHDFolder, SaveName
		
	// Examples of additional scan information that could be extracted. 
	MakeStringIfNeeded("root:SPECTRA:SPEC:gInfoKeyList","Scan L;filters;(-10)#D Delay for next EXAFS scan;#CDe Delay=;#CEn Energy=;")
	SVAR gInfoKeyList 	= root:SPECTRA:SPEC:gInfoKeyList
	
	String /G gScanType, gScanAxis, gSpecFile
	Variable /G gScreenFlag
	
	String ScanType 	= gScanType					// Examples of SPEC scan types. 
	Prompt ScanType, "Type of scan to search for", popup, "ascan;exafsscan;gscan;"
	String ScanAxis 	= gScanAxis
	Prompt ScanAxis, "Scan axis (e.g., 'energy', 'laser_d')"
	String InfoKeyList = gInfoKeyList
	Prompt InfoKeyList, "(lines from #S) List of info keywords to search for"
	Variable ScreenFlag = gScreenFlag
	Prompt ScreenFlag, "More scan info in screen file?", popup, "no;yes;"
	DoPrompt "Search for scans in SPEC file", ScanType, ScanAxis, InfoKeyList, ScreenFlag
	if (V_Flag)
		return -1
	endif
	
	gScanType 		= ScanType
	gScanAxis 		= ScanAxis
	gInfoKeyList	= CleanUpInfoKeyList(InfoKeyList)
	gScreenFlag 	= ScreenFlag
	
	Make /O/D/N=(0,5) SPECScanPos
	Make /O/T/N=0 SPECHeaders, SPECScanInfo
	
	message="Please locate SPEC file"
	Open /R/M=message/T="????" FileRefNum
	if (V_flag == -1)
		Print " *** Spec load aborted by user.  "
		return -1
	endif
	SpecHDFolder	= ParseFilePath(1,S_fileName,":",1,0)
	gSpecFile 		= ParseFilePath(0,S_fileName,":",1,0)
	NewPath /Q/O/Z SPECPath, SpecHDFolder
	
	// This is the routine to count suitable scans in the SPEC file 
	NSpectra 		= SPECFindScansInFile(SPECHeaders,SPECScanPos,SPECScanInfo,FileRefNum,"#L",ScanType,ScanAxis,gInfoKeyList,gSpecFile)
//	gSpecFile 		= StripSuffixBySeparator(ParseFilePath(0,S_fileName,":",1,0),".")
	Print " *** Found a total of",NSpectra,ScanType,"scans"
	
	if (NSpectra == 0)
		Close FileRefNum
		FileRefNum = -1
		
	elseif (ScreenFlag == 2)
		// This is the routine to rescue info from the SCREEN file
		message="Please locate SCREEN file"
		Open /R/M=message/T="????" ScreenFileRefNum
		if (V_flag == -1)
			Print " *** Screen file load aborted by user.  "
		else
			ScreenHDFolder		= ParseFilePath(1,S_fileName,":",1,0)
			ScreenFile		 	= ParseFilePath(0,S_fileName,":",1,0)
			NewPath /Q/O/Z SCREENPath, ScreenHDFolder
			
			EndOfScan 	= "Returning " + ScanAxis
			
			NSpectra 	= SPECFindInfoInSCREENFile(SPECScanPos, SPECScanInfo, ScreenFileRefNum, gInfoKeyList,EndOfScan,ScreenFile)
			Print " *** Information found for",NSpectra,"scans"
		endif
	endif
		
	return FileRefNum
End

// 	The purpose of this routine is to find the file positions for the start of the numbered scan on the correct variable. 
//	Note: The file positions that are recorded are for the "#S" (scan type) lines not "#L" (header) lines.
Function SPECFindScansInFile(SPECHeaders, SPECScanPos, SPECScanInfo, FileRefNum,HeaderLabel, ScanType, ScanAxis, InfoKeyList, Filename)
	Wave /T SPECHeaders, SPECScanInfo
	Wave SPECScanPos
	Variable FileRefNum
	String HeaderLabel, ScanType, ScanAxis, InfoKeyList, Filename
	
	String SPECLine, AxisStr, InfoList=""
	Variable SpecNum, ReportLine=0, HeadingFlag, SLineNum, AxisMin, AxisMax, NLines=0, NSpectra=0
	
	printf "%s%s", " *** Running through the lines in the SPEC file ",Filename
	do
		// -------- Loop through lines in SPEC file -------
		FReadLine FileRefNum, SPECLine
		if (strlen(SPECLine) == 0)
			break
		endif
		NLines += 1
		// -------- Loop through lines in SPEC file --------
		
		ReportLine += 1
		if (ReportLine > 1000)
//			print SPECLine
			ReportLine = 0
		endif
		
		// Make a cumulative list of all info 
		SPECLine 	= ListFromLine(SPECLine,"  ")
		SPECScanInfoFromLine(NLines,SPECLine,InfoKeyList,InfoList)
		
		if (cmpstr("#S ",SPECLine[0,2]) == 0)
			SLineNum 	= NLines
			
			if (strsearch(SPECLine, ScanType, 0) > -1)
				// Read the spec-allocated scan number
				SPECLine 	= ReplaceString("#S ",SPECLine,"")
				SpecNum 	= str2num(StringFromList(0,SPECLine,";"))
				
				HeadingFlag = 0
				do 		// Look for the column headings, denoted by HeaderKey (always #L, I think)
					FReadLine FileRefNum, SPECLine
					if (strlen(SPECLine) == 0)
						break
					endif
					NLines += 1
					
					// Keep making a cumulative list of all info 
					SPECLine 	= ListFromLine(SPECLine,"  ")
					SPECScanInfoFromLine(NLines,SPECLine,InfoKeyList,InfoList)
					
					if (StrSearch(SPECLine,HeaderLabel,0) > -1)
						HeadingFlag = 1
					endif
				while(HeadingFlag == 0)
				
				// Transform header row/line into semi-colon separated list. 
				SPECLine 	= ListFromLine(SPECLine,"  ")
				// Remove the HeaderKey (i.e., #L) and leave the scan number. 
				SPECLine 	= ReplaceString(HeaderLabel+" ",SPECLine,num2str(SpecNum)+";")
				// Identify the first column as the axis value. 
				AxisStr 	= StringFromList(1,SPECLine)
				
				if (cmpstr(AxisStr,ScanAxis) == 0)
					NSpectra +=1
					
					ReDimension /N=(NSpectra) SPECHeaders, SPECScanInfo
					SPECHeaders[NSpectra-1] 		= SPECLine
					
					FStatus FileRefNum
					ReDimension /N=(NSpectra,5) SPECScanPos
					SPECScanPos[NSpectra-1][0]	= SpecNum		// The scan number
					SPECScanPos[NSpectra-1][1]	= V_filePos		// The file position at the end of the header line
					SPECScanPos[NSpectra-1][2]	= SLineNum		// The line number of the "#S" line
					
					FindScanAxisMinMax(FileRefNum,NLines,AxisMin, AxisMax)
					SPECScanPos[NSpectra-1][3]	= AxisMin		// The scan number
					SPECScanPos[NSpectra-1][4]	= AxisMax		// The file position at the end of the header line
					
					// Make and update a list of information extracted with this scan, including its line number location relative to the #S line. 
					ReDimension /N=(NSpectra) SPECScanInfo
					SPECScanInfo[NSpectra-1] 		= UpdateScanInfo(SLineNum,InfoKeyList,InfoList,SPECScanInfo[NSpectra-1])
				endif
			endif
		endif
	while(1)
	printf "%s %d %s\r", " ... found", NLines, "lines"
	
	return NSpectra
End

Function FindScanAxisMinMax(FileRefNum,NLines,AxisMin, AxisMax)
	Variable FileRefNum, &NLines, &AxisMin, &AxisMax
	
	Variable FirstNum=NAN
	String SPECLine, NumStr
	AxisMin = NAN
	AxisMax = NAN
	
	// The first line to be read is the first line in the scan. 
	FReadLine FileRefNum, SPECLine
	if (strlen(SPECLine) == 0)
		return -2		// Cound not find any values
	endif
	NLines += 1
	
	NumStr 	= ReturnTextBeforeNthChar(SPECLine," ",1)
	AxisMin 	= str2num(NumStr)
	
	do
		// -------- Loop through lines in SPEC file -------
		FReadLine FileRefNum, SPECLine
		if (strlen(SPECLine) == 0)
			return -2
		endif
		NLines += 1
		
		AxisMax 	= FirstNum
		
		NumStr = ReturnTextBeforeNthChar(SPECLine," ",1)
		FirstNum 	= str2num(NumStr)
		if (numtype(FirstNum) != 0)
			return 1
		endif
		
		// -------- Loop through lines in SPEC file --------
	while(1)
End	

// ***************************************************************************
// **************** 			Look for additional scan lines that provide needed information 
// ***************************************************************************

// 		InfoKeyList is a {(LineConstraint)-KeyWord} list. 
// 			E.g., "#CDe Delay=;filters=;"
// 		Include, in parentheses, a number indicating whether the information is before or after the #S line. 
// 		Default = no brackets 	means the InfoLine is anywhere afterwards. 
//			(11) 				means the InfoLine must be the 11th following the #S line
// 			(-) 				means the InfoLine is anywhere before the #S line.
// 			(-11) 				means the InfoLine must be the 11th before the #S line. 

// 		InfoList is a {(LineNum)-KeyWord-Information} list. 
// 			E.g., "(235)#CDe Delay=2e-10;(4234)filters=2;"
// 			The absolute SPEC line number will be stored in brackets

Function SPECScanInfoFromLine(InfoLineNum,SPECLine,InfoKeyList,InfoList)
	Variable InfoLineNum
	String SPECLine, InfoKeyList, &InfoList
	
	String FullInfoKey, InfoKey, InfoKeyWOB, InfoStr
	Variable i, NInfo=ItemsInList(InfoKeyList)
	
	// Loop through infoKeys, looking for matches in the SPEC line. 
	for (i=0;i<NInfo;i+=1)
		FullInfoKey 	= StringFromList(i,InfoKeyList)
		InfoKey 		= StripValuesInBrackets(FullInfoKey,"(",")")
		InfoKeyWOB 	= ReplaceString("[",ReplaceString("]",InfoKey,""),"")
		
		if (StrSearch(SPECLine,InfoKeyWOB,0) > -1)
			// Read the Information from the SPEC line. 
			InfoStr 		= StringByKey(InfoKeyWOB,SPECLine,"=")
			
			// Append the LineNum-KeyWord-Information to the InformationList. 
			InfoList 	+= "("+num2str(InfoLineNum)+")" + InfoKey + "=" + InfoStr	+ ";"
		endif
	endfor
End

// INPUT: The current LineNum-KeyWord-Information list for a particular SPEC scan. 

// 	One problem with this approach is that it seems to accumulate keyword-information pairs that are never used. 

// Look at all the items of information in the current InfoList being extracted from the SPEC file. 
// For the present scan, append all the appropriate key-value pairs into the SPECScanInfo wave entry, ScanInfoList
// If information is transfered to the SPECScanInfo wave, delete it from the infoList
Function /T UpdateScanInfo(ScanLineNum,InfoKeyList,InfoList,ScanInfoList)
	Variable ScanLineNum
	String InfoKeyList, &InfoList, ScanInfoList
	
	String msg
	String InfoWOB, keyItem, keyNumStr
	String Info, InfoString, InfoWB, InfoListWOB, infoKey, infoKeyWOB, InfoKeyListWOB
	
	Variable i, j, k, Record=0, NumInfo, infoLineNum, keyIndex, keyLineDiff
	
	// The InfoList without brackets
	InfoListWOB 		= StripValuesInBrackets(InfoList,"(",")")
	
	// The KeyList without brackets
	InfoKeyListWOB 	= StripValuesInBrackets(InfoKeyList,"(",")")

	NumInfo 	= ItemsInList(InfoList)
	for (j=0;j<NumInfo;j+=1)
		// For each entry in the InfoList {(LineNum)-KeyWord-Information} list do the following: 
		
		// Extract the line number:  
		// -------- > Note on indexing 1 By default, loop j through all items in the list.
		InfoWB 				= StringFromList(j,InfoList)
		infoLineNum 		= ReturnValueInBrackets(InfoWB,"(",")")
		
		// Extract the InfoKey string (e.g., "#Ce Energy": 
		InfoWOB 			= StringFromList(j,InfoListWOB)
		infoKey 			= StripSuffixBySeparator(InfoWOB,"=")
		infoKeyWOB 		= StripValuesInBrackets(infoKey,"[","]")
		
		// Find the associated InfoKey entry, and thus any contraints on line number. 
		keyIndex 			= WhichListItem(infoKey,InfoKeyListWOB)
		keyItem 			= StringFromList(keyIndex,InfoKeyList)
		keyNumStr 			= ReturnStringInBrackets(keyItem,"(",")")
		
		if (strlen(keyNumStr) == 0)								// Anywhere after #S
			Record 	= (infoLineNum > ScanLineNum) ? 1 : 0
		elseif (cmpstr("-",keyNumStr) == 0)						// Anywhere before #S
			Record 	= (infoLineNum < ScanLineNum) ? 1 : 0
		else
			keyLineDiff 	= str2num(keyNumStr)				// Precisely keyLineDiff lines before or after #S (depending on sign)
			Record 	= (infoLineNum == (ScanLineNum+keyLineDiff)) ? 1 : 0
		endif
		
		if (Record == 1)
			// Get the actual information ...
			InfoString 		= StringByKey(infoKey,InfoWOB,"=")
			
			// ... remove any text to be deleted from the information key
			
			// ... write it to the SPECScanInfo wave entry ...
			ScanInfoList 	= ReplaceStringByKey(infoKeyWOB,ScanInfoList,InfoString,"=")
			
			// ... and remove this information item from BOTH infoLists. 
			InfoList 		= RemoveListItem(j,InfoList)
			InfoListWOB 	= RemoveListItem(j,InfoListWOB)
			
			// -------- > Note on indexing 2: Here's where we compensate for removing a list item. 
			j-=1
		endif
	endfor
	
	return ScanInfoList
End

// Remove trailing equals sign in case added by user. 
Function /T CleanUpInfoKeyList(InfoKeyList)
	String InfoKeyList
	
	InfoKeyList 		= ParseFilePath(2,InfoKeyList,";",0,0)
	
	Variable i, NumKeys=ItemsInList(InfoKeyList)
	String InfoKey
	
	for (i=0;i<NumKeys;i+=1)
		InfoKey 	= StringFromList(i,InfoKeyList)
		InfoKey 	= StripSuffixBySeparator(InfoKey,"=")
		InfoKeyList 	= RemoveListItem(i,InfoKeyList)
		InfoKeyList 	= AddListItem(InfoKey,InfoKeyList)
	endfor
	
	return InfoKeyList
End

// ***************************************************************************
// **************** 			Part 2: Extract and save the relevant scans in the SPEC file
// ***************************************************************************

Function SPECScansFromSPEC(FileRefNum)
	Variable FileRefNum
	
	WAVE /T SPECHeaders	= root:SPECTRA:SPEC:SPECHeaders
	WAVE /T SPECScanInfo	= root:SPECTRA:SPEC:SPECScanInfo
	WAVE SPECScanPos		= root:SPECTRA:SPEC:SPECScanPos
	//
	SVAR gSpecFile	 		= root:SPECTRA:SPEC:gSpecFile
	SVAR gInfoKeyList 		= root:SPECTRA:SPEC:gInfoKeyList
	
	String message, HeaderList=""
	String ScanInfoList
	String InfoKey, InfoStr, InfoName, SPECLine, HEADLine, SaveName, sDetColPatt, sMtrColPatt, sIoColNum
	Variable i, j=-1, k, PathRefNum, CNum, InfoVar,SpecNum2, SpecFilePos, NSpectra=0, TotNSpectra=0, MtrColNum, DetColNum, IoColNum, Izero, NumInfo
	Variable NewScan, SpecMin, SpecMax, AxisDir, LastAxisValue=-Inf, SpecTitleLine=0
	
	// Assumes that each SPEC scan is independent, but we may wish to concatenate scans. 
	NSpectra = numpnts(SPECHeaders)
	
	// Make a list of all possible column headings for user popup menu. 
	for (i=0;i < NSpectra; i+=1)
		HeaderList += RemoveListItem(0,SPECHeaders[i])
		HeaderList = CompressList(HeaderList,0)
	endfor

	message="A location for saving the extract files"
	NewPath /M=message/Q/O/Z SPECOutPath
	if (V_flag != 0)
		Print " *** Scan extraction aborted by user.  "
		return 0
	endif
	
	String OldDf = getDataFolder(1)
	SetDataFolder root:SPECTRA:SPEC
	
		MakeVariableIfNeeded("gMinSpecPts",10)
		MakeVariableIfNeeded("gMaxSpecPts",400)
		NVAR gMinSpecPts	= gMinSpecPts
		NVAR gMaxSpecPts	= gMaxSpecPts
		
		// Input spectrum selection parameters
		Variable /G gScanFirst, gScanLast, gScanNameType
		String /G gDetColPatt, gMtrColPatt, gIoColPatt
		
		String MtrColPatt = gMtrColPatt
		Prompt MtrColPatt, "Scan Motor Name",popup, HeaderList
		String DetColPatt = gDetColPatt
		Prompt DetColPatt, "Detector Name", popup, HeaderList
		String IoColPatt = gIoColPatt
		Prompt IoColPatt, "Optional Io Name",popup, "_none_;" + HeaderList
		Variable ScanFirst = gScanFirst
		Prompt ScanFirst, "First scan"
		Variable ScanLast = gScanLast
		Prompt ScanLast, "Last scan (0 for all)"
		Variable MinSpecPts = gMinSpecPts
		Prompt MinSpecPts, "Minimum number of points"
		Variable MaxSpecPts = gMaxSpecPts
		Prompt MaxSpecPts, "Maximum number of points"
		String ScanNameStem = StripSuffixBySeparator(ParseFilePath(0,gSpecFile,":",1,0),".")
		Prompt ScanNameStem, "Enter basename for saving (short!!)"
//		Variable ScanNameType = gScanNameType
//		Prompt ScanNameType, "Scan naming scheme", popup, "name & number;name, number & info;name & column name;"
		DoPrompt "Loading a spec file", MtrColPatt, DetColPatt,IoColPatt,ScanFirst, ScanLast, MinSpecPts, MaxSpecPts, ScanNameStem//, ScanNameType
		if (V_flag)
			return 0
		endif
		
		gDetColPatt			= DetColPatt
		gMtrColPatt			= MtrColPatt
		gIoColPatt 			= IoColPatt
		gScanFirst			= ScanFirst
		gScanLast 			= ScanLast
		gMinSpecPts		= MinSpecPts
		gMaxSpecPts		= MaxSpecPts
//		gScanNameType 		= ScanNameType
		
		Make /O/D/N=(MaxSpecPts) ScanAxis=0, ScanSignal=0, ScanIzero=1,  ScanNorm=0
		
		ScanFirst 		= (ScanFirst < 1) ? 0 : ScanFirst
		ScanLast 		= (ScanLast < 1) ? Inf : ScanLast
		
		for (i=0;i<NSpectra;i+=1)
			
			// Read in the previously-extracted details of this individual SPEC scan
			HEADLine 	= ListFromLine(SPECHeaders[i], "") 	// check line terminations!!
			
			MtrColNum	= WhichListItem(MtrColPatt,HEADLine,";") - 1
			DetColNum 	= WhichListItem(DetColPatt,HEADLine,";") - 1
			IoColNum 	= WhichListItem(gIoColPatt,HEADLine,";") - 1
			
			SpecNum2	= SPECScanPos[i][0]
			SpecFilePos	= SPECScanPos[i][1]
			SpecMin	= SPECScanPos[i][3]
			SpecMax	= SPECScanPos[i][4]
			
			AxisDir 		= (SpecMax > SpecMin) ? 1 : -1
			if (i==0)
				LastAxisValue 	= (AxisDir == 1) ? inf : -inf
			endif
			
			NewScan = 1
			if ((AxisDir == 1) && (SpecMin > LastAxisValue))
				NewScan = 0
			elseif ((AxisDir == -1) && (SpecMin < LastAxisValue))
				NewScan = 0
			endif
				
			if (NewScan)
				
				// Save the scan as long as we've extracted at least one. 
				if ((i > 0) && (j > 0))
					SaveSpecScan(ScanAxis, ScanIzero, ScanSignal, ScanNorm, j+1, MinSpecPts, MaxSpecPts, SPECScanPos[SpecTitleLine][0],SPECScanInfo[SpecTitleLine],ScanNameStem,DetColPatt,MtrColPatt)
					
//					LastAxisValue 	= SpecMax
					TotNSpectra +=1
				endif
				
				// Now prepare the scan waves for the new scan data ... 
				Redimension /N=(MaxSpecPts) ScanAxis, ScanSignal, ScanIzero, ScanNorm
				ScanAxis 	= 0
				ScanNorm 	= 0
				
				SpecTitleLine = i
				j = -1
			endif
			
			// Check that this individual SPEC scan contains the correct Column Headings and SPEC Scan Numbers. 
			if ((MtrColNum > -1) && (DetColNum > -1) && (SpecNum2 >= ScanFirst) && (SpecNum2 <= ScanLast))

				// Move to the start of this next scan. 
				FSetPos FileRefNum, SpecFilePos
				
				// Read in the scan lines for a single SPEC scan. 
				do
					FReadLine FileRefNum, SPECLine
					if (strlen(SPECLine) == 0)
						break	// I think this would correspond to an unexpected end of file. 
					endif
//					j += 1
					
					// Convert the SPEC line of scan values for a single data point into a semicolon-separated list. 
					// DANGEROUS - assumes always same separator - but seems to work. 
					SPECLine 			= ListFromLine(SPECLine, " ")
					
					// ... until hit a non-numeric variable. 
					CNum 	= str2num(ReturnTextBeforeNthChar(SPECLine,";",1))
					
					if (numtype(CNum) ==0)
						j += 1
						
						ScanAxis[j] 		= str2num(StringFromList(MtrColNum,SPECLine,";"))
						ScanSignal[j] 		= str2num(StringFromList(DetColNum,SPECLine,";"))
					
						if (IoColNum > -1)
							ScanIzero[j] 	=str2num(StringFromList(IoColNum,SPECLine,";"))
						else
							ScanIzero[j] 	= 1
						endif
						ScanNorm[j] 	= ScanSignal[j]/ScanIzero[j] 
					endif
				while(numtype(CNum) == 0)
				
				LastAxisValue 	= SpecMax
				
			endif
		endfor

		if ((i > 0) && (j > 0))
			SaveSpecScan(ScanAxis, ScanIzero, ScanSignal, ScanNorm, j+1, MinSpecPts, MaxSpecPts, SPECScanPos[SpecTitleLine][0],SPECScanInfo[SpecTitleLine],ScanNameStem,DetColPatt,MtrColPatt)
			
			LastAxisValue 	= SpecMax
			TotNSpectra +=1
		endif
		
		Print " *** Extracted and saved",TotNSpectra,"scans"
		
		Close FileRefNum
		
	SetDataFolder $(OldDf)
	
	return 1
End

Function SaveSpecScan(ScanAxis, ScanIzero, ScanSignal, ScanNorm, ScanNPnts, MinSpecPts, MaxSpecPts, FirstScanNumber,FirstScanInfo,ScanNameStem,DetColPatt,MtrColPatt)
	Wave ScanAxis, ScanIzero, ScanSignal, ScanNorm
	Variable ScanNPnts, MinSpecPts, MaxSpecPts, FirstScanNumber
	String ScanNameStem,FirstScanInfo,DetColPatt,MtrColPatt
	
	String sDetColPatt, sMtrColPatt, SaveName

	if (((ScanNPnts+1) > MinSpecPts) && ((ScanNPnts+1) < MaxSpecPts))
	
		Redimension /N=(ScanNPnts) ScanAxis, ScanIzero, ScanSignal, ScanNorm
		
		sDetColPatt 			= ReplaceString("_",ReplaceString("-",DetColPatt,""),"")
		sMtrColPatt 		= ReplaceString("_",ReplaceString("-",MtrColPatt,""),"")
		
//		SaveName 	= ReturnSPECScanName(ScanNameStem,SPECScanInfo[i],sDetColPatt,sMtrColPatt,SpecNum2)
		SaveName 	= ReturnSPECScanName(ScanNameStem,FirstScanInfo,sDetColPatt,sMtrColPatt,FirstScanNumber)
		
		Save /J/O/P=SPECOutPath ScanAxis, ScanNorm as SaveName+".txt"
	endif
End

Function /T ReturnSPECScanName(ScanNameStem,ScanInfoList,sDetColPatt,sMtrColPatt,SpecNum2)
	String ScanNameStem, ScanInfoList, sDetColPatt, sMtrColPatt
	Variable SpecNum2

	String SaveName, InfoStr
	Variable k, NumInfo = ItemsInList(ScanInfoList)
	
	SaveName = ScanNameStem + "_" + FrontPadVariable(SpecNum2,"0",3) + "_" + sDetColPatt
	
	for (k=0;k<NumInfo;k+=1)
		InfoStr 		= StringFromList(k,ScanInfoList)
		SaveName += "_" + ReplaceString(" ",InfoStr,"")
	endfor
	
	return SaveName
end

// ***************************************************************************
// **************** 	Extracting scan infor from SPEC files and SPEC screen dump files. Generally not used. 
// ***************************************************************************
// This routine was written to rescue information that was written to screen by SPEC but not saved to disc. 
Function SPECFindInfoInSCREENFile(SPECScanPos, SPECScanInfo, FileRefNum, InfoKeyList,EndOfScan,Filename)
	Wave SPECScanPos
	Wave /T SPECScanInfo
	Variable FileRefNum
	String InfoKeyList, EndOfScan, Filename
		
	String SPECLine, InfoList=""
	Variable i, ScanNum, ScanIndex, NLines=0, NSpectra=0
	
	printf "%s%s", " *** Running through the lines in the SCREEN file ",Filename
	do
		FReadLine FileRefNum, SPECLine
		if (strlen(SPECLine) == 0)
			break
		endif
		NLines += 1
		
		// Look for the end of the scan data
		if (strsearch(SPECLine,EndOfScan,0) > -1)
			if (ScanIndex > -1)
				// Now enter all the info into the correct spot and reset
				SPECScanInfo[ScanIndex] 	= InfoList
				NSpectra += 1
			endif
			InfoList = ""
		endif
		
		// Look for scan information in the present line
		SPECScanInfoFromLine(-1,SPECLine,InfoKeyList,InfoList)
		
		// Look for the scan number ...
		sscanf SPECLine, "Scan %d", ScanNum
		
		if (V_flag == 1)
			// ... and find the index of this in the ScanPosition wave
			FindValue /V=(ScanNum) SPECScanPos
			ScanIndex 	= V_value
		endif
		
		SPECScanInfo[ScanIndex] = InfoList
		
	while(1)
	printf "%s %d %s\r", "... found", NLines, "lines"
	
	Close FileRefNum
	
	return NSpectra
End


Function FakeSScanFTest(Line,Key)
	String Line, Key
	
	String VarStr 	= ReplaceString(Key,Line,"")
	Variable Var 	= str2num(VarStr)
	
	return Var
End

Function SScanFTest(Line,Key)
	String Line, Key
	
	Variable Var
	
	sscanf Line, "a=%f", Var
//	sscanf Line, "Delay = %e", Var
//	sscanf Line, "Scan %d", Var
//	sscanf Line, "Value= %f", Var
	
	Print Var, V_flag
End

Function ReturnValue(str)
	string str
	
	Variable FirstNum
	
	sscanf str, "%f", FirstNum 		
	print FirstNum
end
