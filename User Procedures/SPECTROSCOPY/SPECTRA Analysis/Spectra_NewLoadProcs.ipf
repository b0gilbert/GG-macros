#pragma rtGlobals=1		// Use modern global access method.

// ***************************************************************************
// 	NOTES on file loading in these routines. 
// ***************************************************************************

// 	DataName is the default name based on the filenmae
// 	SampleName is the actual name that will be used, accounting for user modifications and potential length or conflict issues. 
// 	*** SampleName DOES NOT END in "_data"

// ***************************************************************************
// **************** 		Text file loading helper routines
// ***************************************************************************

// 	This is how the index of each new Load folder is determined. 
Function NextLoadFolderNumber()

	Wave wDataGroup	= root:SPECTRA:wDataGroup
	Variable i=numpnts(wDataGroup)
	
	do
		i+=1
		FindValue /V=(i) wDataGroup
	while(V_value != -1)
	
	return i
End


// ***************************************************************************
// **************** 			COLUMN HEADING ROUTINES --- Aaarggghhh
// ***************************************************************************
//
// 		!*!* Annoying. The PAR data format has an extra ",0" at the end of the column title for no fucking reason. 
// 			Consequently, the number of titles .N.E. number of loaded columns, and we have to relax the equality test. 

Function /T ReturnListOfColumnHeadings(PathAndFileName,HeaderString,NHeaderLines,ExpectedNCols,UserFlag)
	String PathAndFileName, HeaderString
	Variable NHeaderLines, ExpectedNCols, UserFlag
	
	String TitleLine, TitleReturn="", TitleList_CSV, TitleList_TAB, TitleList_SPC, TitleList_BRA, TitleList_SQR, ColChoice
	Variable Test, NCols, Success=0, refNum = 0, looping=1, i, ColAccept=1, HStringLen=strlen(HeaderString)
	
	Open/R refNum as PathAndFileName
	if (refNum == 0)
		return ""
	endif
	
	// Skip unwanted header lines if we know how many there are. 
	if (NHeaderLines > 0)
		for (i=0;i<NHeaderLines;i+=1)
			FReadLine refNum, TitleLine
			if (strlen(TitleLine) == 0)
				Close refNum
				return ""
			endif
		endfor
	endif
	
	do
		FReadLine refNum, TitleLine
		if (strlen(TitleLine) == 0)
			Close refNum
			return ""
		endif
		
		Test=0
		if (HStringLen == 0)
			Test 		= 1
		elseif ((HStringLen>0) && (cmpstr(HeaderString,TitleLine[0,HStringLen-1]) == 0))
			// Remove the flag indicating column titles, and any spaces that get left behind. 
			TitleLine 	= ReplaceString(HeaderString,TitleLine,"",1,1)
			TitleLine 	= StripLeadingChars(TitleLine," ")
			Test 		= 1
		endif
		
		if (Test)
			// Strip trailing carriage return(s)
			TitleLine 	= ReplaceString("\r",TitleLine,"")
			TitleLine 	= ReplaceString("\n",TitleLine,"")
			
			// Arg - why add another comma to the end here, but not for the other delimiters? 
//			TitleList_CSV = ReturnHeadings1(TitleLine+",",",",0,ExpectedNCols)
			TitleList_CSV = ReturnHeadings1(TitleLine,",",0,ExpectedNCols)
			if (ItemsInList(TitleList_CSV) == ExpectedNCols)
				TitleReturn 	= StripTrailingCharsFromList(TitleList_CSV,",")
				
			elseif (ItemsInList(TitleList_CSV) == ExpectedNCols+1)
				// For csv only, permit more column titles than columns (see above)
				TitleList_CSV 	= TruncateList(TitleList_CSV,";",ExpectedNCols)
				TitleReturn 	= StripTrailingCharsFromList(TitleList_CSV,",")
			else
				TitleList_TAB = ReturnHeadings1(TitleLine+"	","	",0,ExpectedNCols)
				if (ItemsInList(TitleList_TAB) == ExpectedNCols)
					TitleReturn = StripTrailingCharsFromList(TitleList_TAB,"	")
				else
					TitleList_SPC = ReturnHeadings1(TitleLine+" "," ",0,ExpectedNCols)
					if (ItemsInList(TitleList_SPC) == ExpectedNCols)
						TitleReturn = StripTrailingCharsFromList(TitleList_SPC," ")
					else
						TitleList_BRA = ReturnHeadings1(TitleLine,")",0,ExpectedNCols)
						if (ItemsInList(TitleList_BRA) == ExpectedNCols)
							TitleReturn = TitleList_BRA
						else
							TitleList_SQR = ReturnHeadings1(TitleLine,"]",0,ExpectedNCols)
							if (ItemsInList(TitleList_SQR) == ExpectedNCols)
								TitleReturn = TitleList_SQR
							else
								TitleReturn = ""
							endif
						endif
					endif
				endif
			endif
		endif
		
		if (strlen(TitleReturn) > 0)
			looping = 0
			if (UserFlag)
				Prompt ColChoice, "List of headings", popup, TitleReturn
				// This would be an improvement I think
//				Prompt ColAccept, "Accept the headings?", popup, "yes;yes - but use column numbers;no - keep looking;no - use column numbers;"
				Prompt ColAccept, "Accept the headings?", popup, "yes;no - keep looking;no - use column numbers;"
				DoPrompt "Automatic search for column headings", ColChoice, ColAccept
				if ((V_flag == 1) || (ColAccept == 3))
					TitleReturn 	= ""	// This will exit the loop AND the routine
				elseif (ColAccept == 1)
					// Get rid of tabs in the titles
					TitleReturn 	= ReplaceString("\t",TitleReturn," ")
					TitleReturn 	= StripLeadingCharsFromList(TitleReturn," ")
					// CrunchTope adds separators BEFORE the first Heading
					if (cmpstr(";",TitleReturn[0,0])==0)
						TitleReturn 	= RemoveListItem(0,TitleReturn)
					endif
				elseif (ColAccept == 2)
					looping = 1
				endif
			endif
		endif
		
	while(looping)
	
	return TitleReturn
End	

// Various possible ways to construct column headings:
// 		Title_1  Title_2  etc...
// 		Title1 (Units1)  Title2 (Units2) ... etc
// 		Title One (Units 1)  ... etc .. 
//
// 		Especially with spaces, there may be repeated delimiters. 
// 
Function /T ReturnHeadings1(TitleLine,Delimiter,AppendChar,ExpectedNCols)
	String TitleLine, Delimiter
	Variable AppendChar, ExpectedNCols
	
	Variable NCols
	String Segment, Title, TitleMods, TitleList=""
	
	// Make sure the delimiters were not repeated (if space)
	if (cmpstr(Delimiter," ") == 0)
		TitleMods 	= StripRepeatedChars(TitleLine,Delimiter)
	else
		TitleMods 	= TitleLine
	endif
	
	// Make sure the trial list of column headings ends in the trial delimiter. 
	TitleMods 	= AppendDelimiter(TitleMods,Delimiter)
	
	// First try the easy approach. Replace all delimiters with ";" and count list items. 
	TitleMods 	= ReplaceString(Delimiter,TitleMods,";")
	
//	print TitleMods
	
	NCols 		= ItemsInList(TitleMods,";")
	if ((ExpectedNCols == -1) || ((ExpectedNCols > -1) && (NCols == ExpectedNCols)))
		return TitleMods
	endif
	
	// If there's one too few, let's try to add a blank one. 
	if (NCols == ExpectedNCols-1)
		return TitleMods + Delimiter
	endif
	
	return ""
	
	
	
	
	
	
	
	// Now we have to worry about what to do if don't match expected 
	return ""
	
	TitleLine 	= AppendDelimiter(TitleList,Delimiter)
	NCols 		= ItemsInList(TitleList,";")
	if (NCols == ExpectedNCols)
		return TitleList
	endif
	
	TitleList 	= StripRepeatedChars(TitleList,";")
	NCols 		= ItemsInList(TitleList,";")
	if (NCols == ExpectedNCols)
		return TitleList
	endif
	
	return ""
	
	NCols 		= ItemsInList(TitleLine,Delimiter)
	if (NCols != ExpectedNCols)
		Print " 	 ... delimiter",Delimiter," .... expecting",ExpectedNCols,"column headings but actually there seem to be",NCols
		TitleLine 	= ReplaceString(Delimiter,TitleLine,";")
		
	endif
	if (NCols > ExpectedNCols)
		TitleLine 	= StripRepeatedChars(TitleLine,Delimiter)
	endif
	if (NCols < ExpectedNCols)
//		print TitleLine
	endif
	
	// What is this loop for? Seem to recall strange repeated headers in some file ... 
	do
		// Extract the first text segment, up to the first trial delimiter character. 
		// Equivalent to ParseFilePath(1, TitleLine, Char, 0, 1), but can handle longer strings. 
		Segment 	= ReturnTextBeforeNthChar(TitleLine,Delimiter,1)
		Title 		= StripLeadingChars(Segment,Delimiter)
			
		if (strlen(Title) > 0)
			if (AppendChar)
				TitleList += Title+Delimiter+";"
			else
				TitleList += Title+";"
			endif
			
			// Now remove this segment. Only replace a SINGLE INSTANCE of a repeated column heading. 
			TitleLine = ReplaceString(Segment+Delimiter,TitleLine,"",1,1)
		endif
	while(strlen(Title) > 0)
	
	return TitleList
End


// ***************************************************************************
// **************** 		My General Routine to try to load a text file into wave, wave1 etc. 
// ***************************************************************************

// Try loading data as either General or Delimited text formats. 
Function /S TrytoLoadSingleTextFile(PathAndFileName,Basename,NHeaderLines,NFileLines,MinColNum)
	String PathAndFileName, Basename
	Variable NHeaderLines, NFileLines, MinColNum
	
	Variable LoadError
	String LoadedList
	
	// If there are any header lines, let's just call the line preceeding the data the title line. 
	Variable nameLine 	= (NHeaderLines == 0) ? 0 : NHeaderLines-1
	
	// This should be fine for both zero and non-zero numbers of header lines. 
	Variable firstLine 	= NHeaderLines

	// First try loading in General text format
	Loadwave /Q/A=$Basename/N/O/D/G/L={nameLine,firstLine,0,0,0} PathAndFileName
	
	// This works OK for CARY spreadsheet format. 
//	LoadWave/J/D/A=$Basename/K=0/L={nameLine,firstLine,0,0,0} PathAndFileName
	
	LoadError 	= GetRTError(1)
	
	if (LoadError)
		// Then try loading in Delimited text format ... OK for some PC text files, but can leave a NAN at end. 
		Print " 		*** No columns found in file with General Text load. Try with Delimited Text approach."
		Loadwave /Q/A=$Basename/N/O/D/J/L={nameLine,firstLine,0,0,0} PathAndFileName
		LoadError 	= GetRTError(1)
		if (LoadError)
			Print " 		*** No columns found in file with Delimited Text approach."
		else
			LoadedList 	= S_Wavenames
		endif
	else
		LoadedList 	= S_Wavenames
	endif
	
	// *%*%*% Added as emergency debug as could not load SigScan files. 
	if (MinColNum > 0)
		if (ItemsInList(LoadedList) < MinColNum)
			FindStartOfData(PathAndFileName,NHeaderLines, NFileLines)
//			Loadwave /Q/A=$Basename/N/O/D/J/L={NHeaderLines-1,NHeaderLines,0,0,0} PathAndFileName
			Loadwave /Q/A=$Basename/N/O/D/J/L={NHeaderLines-2,NHeaderLines-1,0,0,0} PathAndFileName
			LoadedList 	= S_Wavenames
		endif
	endif
	
//	print S_Wavenames
	
	if (!LoadError)
		return LoadedList
	else
		return ""
	endif
End

// 	Desperation! This is called if the Igor auto-load routines can't find the start of the data block. 
// 	E.g., there may be a sequence of blank lines, and thus this tries to find the number of lines to skip. 
Function FindStartOfData(PathAndFileName,NHeaderLines, NFileLines)
	String PathAndFileName
	Variable &NHeaderLines, &NFileLines
	
	Variable refNum, space=0, i=0
	String TitleLine
	
	Open/R refNum as PathAndFileName
	if (refNum == 0)
		return -1
	endif
	
	do
		FReadLine refNum, TitleLine
		
		if (strlen(TitleLine) == 0)
			NHeaderLines = 0
		elseif (strlen(TitleLine) == 1)
			NHeaderLines = i+1
		elseif (StrSearch(TitleLine,"Time of Day",0) > -1)
			// ALS Beamline 6 SigScan data. This is the title of the first column. 
			NHeaderLines = i
			Close refNum
			return 1
		endif
		
		i += 1
	while(1)
End

// # ACTUAL:	YAXIS: -6.4358	ZAXIS: 1.285

// ***************************************************************************
// **************** 		Create a new Load folder for the axis-data pair
// ***************************************************************************
// This routine assumes that all the waves of type SampleName + suffix already exist. 

Function /T NewLoadedDataFolder(LoadFolderNumber,CmplxFlag,ImportFolder,AxisWaveName,DataWaveName,SampleName,SpectrumNote,AssocDataList, AssocDataFolder)
	Variable LoadFolderNumber,CmplxFlag
	String ImportFolder,AxisWaveName,DataWaveName,SampleName,SpectrumNote,AssocDataList, AssocDataFolder

	Wave/T wDataList			= root:SPECTRA:wDataList
	Wave wDataSelection		= root:SPECTRA:wDataSel
	Wave wDataGroup			= root:SPECTRA:wDataGroup
	
	Variable i, NAssocData, NLoadFolders=numpnts(wDataList)
	String LoadFolderPath, OrigFolderPath, AssocFolderPath, FullAxisName, FullDataName, AssocDataName, FullAssocDataName

	LoadFolderPath 	= "root:SPECTRA:Data:Load" + num2str(LoadFolderNumber)
	NewDataFolder /O $LoadFolderPath
	OrigFolderPath 	= ParseFilePath(2,LoadFolderPath,":",0,0) + "Originals"
	NewDataFolder /O $OrigFolderPath
	
	if (strlen(AssocDataFolder) > 0)
		AssocFolderPath 	= ParseFilePath(2,LoadFolderPath,":",0,0) + AssocDataFolder
		NewDataFolder /O $AssocFolderPath
	else
		AssocFolderPath 	= ParseFilePath(2,LoadFolderPath,":",0,0)
	endif
	
	TransferSingleDataWave(SampleName,"_axis",LoadFolderPath)
	TransferSingleDataWave(SampleName,"_data",LoadFolderPath)
	TransferSingleDataWave(SampleName,"_time",LoadFolderPath)
	TransferSingleDataWave(SampleName,"_axis_sig",LoadFolderPath)
	TransferSingleDataWave(SampleName,"_data_sig",LoadFolderPath)
	TransferSingleDataWave(SampleName,"_fit",LoadFolderPath)
	TransferSingleDataWave(SampleName,"_res",LoadFolderPath)
	
	// The axis and data waves may not have the same name as SampleName
	WAVE InputAxis 	= $(ParseFilePath(2,ImportFolder,":",0,0) + AxisWaveName)
	Make /O/D/N=(DimSize(InputAxis,0)) $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_axis") /WAVE=Axis
	Axis 	= InputAxis
	
	if (CmplxFlag)
		WAVE /C ComplexData 	= $(ParseFilePath(2,ImportFolder,":",0,0) + DataWaveName)
		Make /O/D/C/N=(DimSize(ComplexData,0)) $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_data") /WAVE=Complex
		Complex = ComplexData
		// Transfer any wave note information. 
		Note /K Complex note(ComplexData)
	else
		WAVE InputData 	= $(ParseFilePath(2,ImportFolder,":",0,0) + DataWaveName)
		Make /O/D/N=(DimSize(InputData,0)) $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_data") /WAVE=Data
		Data 	= InputData
		// Transfer any wave note information. 
		Note /K Data note(InputData)
	endif
	
	// Optionally append more information to the wave note
	if (strlen(SpectrumNote) > 0)
		Note $FullDataName SpectrumNote
	endif
	
	// Make copies of the loaded data in the Originals subfolder
	DuplicateAllWavesInDataFolder(LoadFolderPath,OrigFolderPath,SampleName+"*",0)

	// Update the list of loaded waves
	ReDimension /N=(NLoadFolders+1) wDataList
	wDataList[NLoadFolders] 		= SampleName+"_data"
		
	ReDimension /N=(NLoadFolders+1) wDataSelection, wDataGroup
	wDataSelection[NLoadFolders] 	= 0
	wDataGroup[NLoadFolders] 		= LoadFolderNumber
	
	// Transfer any additional data waves to subdata folder. 
	NAssocData 		= ItemsInList(AssocDataList)
	if (NAssocData > 0)
		for (i=0;i<NAssocData;i+=1)
			AssocDataName 		= StringFromList(i,AssocDataList)
			FullAssocDataName 	= ParseFilePath(2,AssocFolderPath,":",0,0) + StringFromList(i,AssocDataList)
			Duplicate /O $AssocDataName, $FullAssocDataName
		endfor
	endif
	
	// Make copies of 2D data (if it exists) in the Originals subfolder
	DuplicateAllWavesInDataFolder(AssocFolderPath,OrigFolderPath,SampleName+"_2D",0)
	
	return ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_data"
End

Function TransferSingleDataWave(SampleName,Suffix,LoadFolderPath)
	String SampleName,Suffix,LoadFolderPath
	
	String DataWaveName 	= SampleName+Suffix
	if (WaveExists($DataWaveName))
		Duplicate /O $DataWaveName, $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+Suffix)
	endif
End

// ***************************************************************************
// **************** 		An ALTERNATIVE function to create a new Load folder for the axis-data pair
// ***************************************************************************
// 	This is used by some special loading routines that load many data per file : RODFile; 

Function SingleAxisDataErrorsFitLoad(SampleName,SampleNote,Axis,Data,Errors,Fit,Resids,AcqTime)
	String SampleName, SampleNote
	Wave Axis,Data,Errors,Fit,Resids,AcqTime
	
	Wave/T wDataList			= root:SPECTRA:wDataList
	Wave wDataSelection		= root:SPECTRA:wDataSel
	Wave wDataGroup			= root:SPECTRA:wDataGroup
	
	// ******* NUMBERING THE LOAD FOLDERS *******
	Variable NextLoadFolder 	= NextLoadFolderNumber()
	Variable NumLoaded 		= numpnts(wDataList)
	// *************************************
	
	// Check the sample name is not too long. 	
	if (strlen(SampleName)>22)
		SampleName 	= GetSampleName(SampleName,"","",0,1,1)
		if (cmpstr("_quit!_",SampleName) == 0)
			return 0
		endif
	endif
	SampleName 	= CleanUpDataName(SampleName)
	SampleName 	= AvoidDataNameConflicts(SampleName,"_r",wDataList)
	
	String LoadFolderPath 	= "root:SPECTRA:Data:Load" + num2str(NextLoadFolder)
	String OrigFolderPath 	= "root:SPECTRA:Data:Load" + num2str(NextLoadFolder)+":Originals"
	NewDataFolder /O $LoadFolderPath
	NewDataFolder /O $OrigFolderPath

	// Optionally add information to the wave note. 
	if (strlen(SampleNote) > 0)
		Note /K Data, SampleNote
	endif
	
	Duplicate /O Axis, $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_axis")
	Duplicate /O Data, $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_data")
	
	if (WaveExists(AcqTime))
		Duplicate /O AcqTime, $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_time")
	endif
	if (WaveExists(Errors))
		Duplicate /O Errors, $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_data_sig")
	endif
	if (WaveExists(Fit))
		Duplicate /O Fit, $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_fit")
	endif
	if (WaveExists(Resids))
		Duplicate /O Resids, $(ParseFilePath(2,LoadFolderPath,":",0,0) + SampleName+"_res")
	endif
	
	// Backup the data
	DuplicateAllWavesInDataFolder(LoadFolderPath,OrigFolderPath,SampleName+"*",0)

	// Update the list of loaded waves
	NumLoaded += 1
	ReDimension /N=(NumLoaded) wDataList
	wDataList[NumLoaded-1] 		= SampleName+"_data"
		
	ReDimension /N=(NumLoaded) wDataSelection, wDataGroup
	wDataSelection[NumLoaded-1] 	= 0
	
	wDataGroup[NumLoaded-1] 		= NextLoadFolder
	
	return 1
End

Function /T LoadComplexTextFile(FileName,SampleName)
	String FileName, SampleName
	
	NVAR gComplexCol1 		= root:SPECTRA:GLOBALS:gComplexCol1
	NVAR gComplexCol2 		= root:SPECTRA:GLOBALS:gComplexCol2
	NVAR gComplexPhase 	= root:SPECTRA:GLOBALS:gComplexPhase
	NVAR gComplexType 		= root:SPECTRA:GLOBALS:gComplexType
	NVAR gComplexDecimate 	= root:SPECTRA:GLOBALS:gComplexDecimate
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	String PathAndFileName = gPath2Data + FileName
	
	String LoadNames, AxisWaveName, RealName, ImagName, FullAxisName, FullDataName, WaveNameList, TempNameList
	Variable NHeaderLines=0, NFileLines=0, NumCols, NCmplxPts
	
		// ---- The general text-file loading attempt
	LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,2)
	if (ItemsInList(LoadNames) < 2)
		FindStartOfData(PathAndFileName,NHeaderLines, NFileLines)
		LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,2)
	endif
	
	NumCols 	= ItemsInList(LoadNames)
	if (NumCols == 0)
		Print " *** Cannot find the end of the header lines and the start of the data."
		return ""
	elseif (NumCols < 3)
		Print " *** The chosen file",FileName,"contains too few columns (",NumCols,")"
		return ""
	endif

	// Assume that the Axis is the first column
	AxisWaveName 	= StringFromList(0, LoadNames)
	TempNameList 	= StringFromList(0, LoadNames) + ";"
	WAVE Axis 		= $AxisWaveName
	
	// Assume that complex data are in the next 2 columns
	RealName 			= StringFromList(gComplexCol1, LoadNames)
	TempNameList 		= TempNameList + RealName + ";"
	WAVE Cmplx1 		= $(StringFromList(gComplexCol1, LoadNames))
	ImagName 			= StringFromList(gComplexCol2, LoadNames)
	TempNameList 		= TempNameList + ImagName + ";"
	WAVE Cmplx2 		= $(StringFromList(gComplexCol2, LoadNames))
	
	StripNANsFromDataWavesInList(AxisWaveName+";"+RealNAme+";"+ImagName+";")
	
	if (gComplexDecimate > 1)
		Print " 			... decimating axis and complex data by",gComplexDecimate
		WaveList_Decimate(TempNameList,gComplexDecimate)
	endif

	NCmplxPts 		= Dimsize(Cmplx1,0)
	
	// Give the Axis wave a correct names
	FullAxisName=SampleName+"_axis"
	Duplicate /O $AxisWaveName, $FullAxisName
	WaveNameList += FullAxisName+";"
	
	// Make a COMPLEX wave for the data
	FullDataName=SampleName+"_data"
	Make /O/D/C/N=(NCmplxPts) $FullDataName /WAVE=ComplexData
	WaveNameList += FullDataName+";"
	
	ComplexData = cmplx(Cmplx1,Cmplx2)	// fine for z = a + ib form
	
	if (gComplexType==2)
		if (gComplexPhase==2)
			// If the Angle is in degrees, use a user function to convert
			Print "  		----  Converting from {mag,degrees} to {real,imaginary}"
			UserPolarToRect(Axis,Cmplx1,Cmplx2,ComplexData)
			
			if (0)
			// try alternative
			Duplicate /FREE Cmplx2, ComplexRadians
			ComplexRadians[] = (2*pi) * (Cmplx2[p])/360
			Duplicate /C/FREE ComplexData, ComplexDataRect
			ComplexDataRect[] 	= p2rect(ComplexData[p])
			ComplexData 	= ComplexDataRect
			endif
		else
			// Use the built-in function
			Print "  		----  Converting from {mag,radians} to {real,imaginary}"
			Duplicate /C/FREE ComplexData, ComplexDataRect
			ComplexDataRect[] 	= p2rect(ComplexData[p])
			ComplexData 	= ComplexDataRect
		endif
	endif
	
	// Record the full original filename as a wave note. 
	Note /K ComplexData, FileName
	Note ComplexData, gPath2Data
	
	// Append the file creation date to the wave note. 
	GetFileFolderInfo /Z/Q PathAndFileName
	Note ComplexData, "CreationDate="+Secs2Date(V_creationDate,-2)+";"
	Note /NOCR ComplexData, "CreationTime="+Secs2Time(V_creationDate,3)+";"
	Note /NOCR ComplexData, "DataType=Complex;"
	
	KillWavesFromList(LoadNames,1)

	return SampleName
		
End

// Convert from Magnitude - Angle into Real - Imaginary
// The Wavemetrics function p2rect() seems to be limited to ±π 
 
STATIC Function UserPolarToRect(Freq,Mag,Ang,RectCmplx)
	Wave Freq,Mag,Ang
	Wave /C RectCmplx
	
	Variable NPts = DimSize(Freq,0), Zo=50, Denom
	Variable A2R = pi/180
	
	Make /O/FREE/N=(NPts) TempReal, TempImag
	
//	Denom 		= 1 + Mag^2  -  2*Mag*cos(Ang*A2R)
//	TempReal 	= (Zo * (1-Mag^2))  /  Denom
//	TempImag 	= (Zo * 2*Mag*sin(Ang*A2R))  /  Denom
	
	TempReal 	= (Zo * (1-Mag^2))  /  (1 + Mag^2  -  2*Mag*cos(Ang*A2R))
	TempImag 	= (Zo * 2*Mag*sin(Ang*A2R))  /  (1 + Mag^2  -  2*Mag*cos(Ang*A2R))
	
	RectCmplx = Cmplx(TempReal,TempImag)
	
End


// ***************************************************************************
// **************** 		Single-Column list of data 
// ***************************************************************************

Function /T LoadSingleRockJockFile(FileName,SampleName)
	String FileName, SampleName
	
	Loadwave /Q/A=$("RJdata")/N/O/D/G/P=LoadDataPath FileName
	if (V_flag == 0)
		return ""
	endif
	WAVE RJdata 			= $StringFromList(0,S_waveNames)
	
	String RJDataName 	= SampleName + "_data"
	String RJAxisName = SampleName + "_axis"
	
	Variable AxisStart	= NumVarOrDefault("root:SPECTRA:GLOBALS:gAxisStart", 0)
	Prompt AxisStart, "The starting 2-theta angle"
	Variable AxisStep	= NumVarOrDefault("root:SPECTRA:GLOBALS:gAxisStep", 0)
	Prompt AxisStep, "The constant 2-theta angle step"
	DoPrompt "Axis information", AxisStart, AxisStep
	if (V_flag)
		return ""
	endif
	Variable /G $("root:SPECTRA:GLOBALS:gAxisStart")=AxisStart
	Variable /G $("root:SPECTRA:GLOBALS:gAxisStep")=AxisStep
	
	Duplicate /O/D RJdata, $RJAxisName, $RJDataName
	WAVE RJaxis 		= $RJAxisName
	RJaxis[] 				= AxisStart + p * AxisStep
	
	return SampleName+";"
End

// ***************************************************************************
// **************** 		IGOR Text file load routine. Written for KOLXPD exports: Data, Fit, Components
// ***************************************************************************

Function /T LoadIgorTextDataFitFile(FileName,SampleName,AssocDataList)
	String FileName, SampleName, &AssocDataList
	
	LoadWave /O/Q/T/P=LoadDataPath FileName
	if (V_flag == 0)
		return ""
	endif
	
	Variable i, NWaves = ItemsInList(S_waveNames)
	
	String DataName  	= SampleName + "_data"
	String AxisName 	= AxisNameFromDataName(DataName)
	String WaveNameList = AxisName+";"+DataName+";"
	
	WAVE DataWave 	= $StringFromList(0,S_waveNames)
	Duplicate /O DataWave, $DataName /WAVE=Data
	Duplicate /O DataWave, $AxisName /WAVE=Axis
	Axis[] = pnt2x(Data,p)
	
	if (NWaves>1)
		WAVE FitWave 	= $StringFromList(1,S_waveNames)
		String FitName 	= FitNameFromDataName(DataName)
		String ResName = ResidsNameFromDataName(DataName)
		Duplicate /O FitWave, $FitName /WAVE=Fit
		Duplicate /O FitWave, $ResName /WAVE=Resids
		Resids 	= DataWave - FitWave
		WaveNameList = WaveNameList+FitName+";"+ResName+";"
	endif 
	
	for (i=2;i<NWaves;i+=1)
		WAVE CmptWave 	= $StringFromList(i,S_waveNames)
		if (WaveType(CmptWave,1) == 1)
			String CmptName 	= AnyNameFromDataName(DataName,"cpt"+num2str(i-1))
			Duplicate /O CmptWave, $CmptName /WAVE=Resids
			AssocDataList 	= AssocDataList+CmptName+";"
//			WaveNameList = WaveNameList+CmptName+";"
		endif
	endfor
	
	return WaveNameList
End

// ***************************************************************************
// **************** 		SINGLE Text file load routine
// ***************************************************************************

Function /T LoadSingleTextFile(FileName,SampleName,ErrorsFlag,FitFlag,AllColumnsFlag,MonotonicFlag,RequestNCols)
	String FileName, SampleName
	Variable ErrorsFlag, FitFlag, AllColumnsFlag, &MonotonicFlag, RequestNCols
	//
	NVAR AxisColNum 		= root:SPECTRA:GLOBALS:gAxisCol
	NVAR DataColNum			= root:SPECTRA:GLOBALS:gDataCol
	NVAR AxisSigColNum		= root:SPECTRA:GLOBALS:gAxisSigCol
	NVAR DataSigColNum		= root:SPECTRA:GLOBALS:gDataSigCol
	NVAR DecimateNum		= root:SPECTRA:GLOBALS:gDecimateNum
	NVAR gSortFlag 			= root:SPECTRA:GLOBALS:gSortFlag
	NVAR gNameSource 		= root:SPECTRA:GLOBALS:gNameSource
	//
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	Variable i, iMin, iMax, IgorTextFlag, NPnts, NumCols, MinNumCol, FitColNum, ResidsColNum, DataErrors=0, LoadError,NHeaderLines=0, NFileLines=0
	String DataWaveName, FullDataName, AxisWaveName, FullAxisName, FullAxisSigName, FullDataSigName, suffix
	String LoadNames, ColFitName, FitWaveName, FullFitName, ResWaveName, FullResName, FitPeakName, FullFitPeakName, ColNameList="", DataNameList="",WaveNameList=""
	
	String PathAndFileName = gPath2Data + FileName
	
		// ---- The general text-file loading attempt
	LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,RequestNCols)
	if (ItemsInList(LoadNames) < 2)
		FindStartOfData(PathAndFileName,NHeaderLines, NFileLines)
		LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,RequestNCols)
	endif
	
	NumCols 	= ItemsInList(LoadNames)
	if (NumCols == 0)
		Print " *** Cannot find the end of the header lines and the start of the data."
		return ""
	endif
	
	// *%*%*%* terrible debug
	if (RequestNCols > 0)
		MinNumCol 	= RequestNCols
	else
		MinNumCol 	= 2 + 2*ErrorsFlag + FitFlag
	endif
	if (NumCols < MinNumCol)
		Print " *** The chosen file",FileName,"contains too few columns (",NumCols,")"
		return ""
	endif
	
	// This finds the loaded name of the relevant column, e.g., 'wave0' and 'wave1'
	AxisWaveName 	= StringFromList(AxisColNum, LoadNames)
	DataWaveName 	= StringFromList(DataColNum, LoadNames)
	
	Variable SortAxis 	= (gSortFlag > 2) ? 1 : 0
	if (CheckMonotonic($AxisWaveName) == 0)
		MonotonicFlag	= 0
		SortAxis 		= 0
	endif
	if (SortAxis)
		Print " 		.... Sorting data so that axis runs low to high."
		SortWavesFromList(LoadNames,AxisColNum)
	endif
	
	// The column headings, if they are needed. 
	gNameSource = 1		// <----    Currently disabled reading column titles. 
	if (gNameSource == 2)
		ColNameList 	= ReturnListOfColumnHeadings(PathAndFileName,"",NHeaderLines,NumCols,1)
		SampleName 	= CleanUpDataName(StringFromList(DataColNum, ColNameList))
	endif
	
	// First look for the AXIS so that this is the first entry in WaveNameList
	FullAxisName=SampleName+"_axis"
	if (cmpstr(FullAxisName, AxisWaveName) != 0)
		Duplicate /O $AxisWaveName, $FullAxisName
		WaveNameList += FullAxisName+";"
	endif
	
	FullDataName=SampleName+"_data"
	if (cmpstr(FullDataName, DataWaveName) != 0)
		Duplicate /O $DataWaveName, $FullDataName
		WaveNameList += FullDataName+";"
	endif
	
	// Record the full original filename as a wave note. 
	Note /K $FullDataName, FileName
	Note $FullDataName, gPath2Data
	
	// Append the file creation date to the wave note. 
	GetFileFolderInfo /Z/Q PathAndFileName
	Note $FullDataName, "CreationDate="+Secs2Date(V_creationDate,-2)+";"
	Note /NOCR $FullDataName, "CreationTime="+Secs2Time(V_creationDate,3)+";"
	String DataNote 	= note($FullDataName)
	
	// I'm not entirely sure if this is still needed. 
	DataNameList += FullDataName+";"
	
	// Look for data errors
	DataWaveName=StringFromList(DataSigColNum, LoadNames)
	if (WaveExists($DataWaveName))
		FullDataSigName=SampleName+"_data_sig"
		Duplicate /O $DataWaveName, $FullDataSigName
		WaveNameList += FullDataSigName+";"
		DataErrors = 1
	endif
	
	// Look for axis errors. 
	AxisWaveName=StringFromList(AxisSigColNum, LoadNames)
	FullAxisSigName=SampleName+"_axis_sig"
	if (WaveExists($AxisWaveName))
		Duplicate /O $AxisWaveName, $FullAxisSigName
		WaveNameList += FullAxisSigName+";"
	elseif (DataErrors == 1)
		Duplicate /O $DataWaveName, $FullAxisSigName
		WAVE AxisErrors 	= $FullAxisSigName
		AxisErrors = 0
		WaveNameList += FullAxisSigName+";"
	endif
	
	// In some cases, automatically look for a fit column
	if ((FitFlag==0) && (NumCols > 4))
		ColNameList 	= ReturnListOfColumnHeadings(PathAndFileName,"",NHeaderLines,NumCols,0)
		if (ItemsInList(ColNameList) > 0)
			if (StrSearch(StringFromList(DataColNum,ColNameList),"_data",0) > -1)
				ColFitName 	= ReplaceString("_data",StringFromList(DataColNum,ColNameList),"_fit")
				FitColNum 	= WhichListItem(ColFitName,ColNameList)
				if (FitColNum != -1)
					FitFlag = 1
				endif
			endif
		endif
	endif
	
	if (FitFlag == 1)
	
		// Try finding the fit column from the headings. 
		ColNameList 	= ReturnListOfColumnHeadings(PathAndFileName,"",NHeaderLines,NumCols,1)
		FitColNum 	= WhichMatchListItem(ColNameList,"_fit",";")
		if (FitColNum == -1)
			FitColNum 	= WhichMatchListItem(ColNameList,"fit",";")
			if (FitColNum == -1)
				FitColNum 	= DataColNum+1
				Print " *** No column headings! Assumed the fit column is the one after the data column"
			endif
		endif
		
		if (FitColNum > 1)
			FitWaveName	= StringFromList(FitColNum, LoadNames)
			FullFitName	= SampleName+"_fit"
			Duplicate /O $FitWaveName, $FullFitName
			WaveNameList += FullFitName+";"
			
			FullResName	= SampleName+"_res"
			ResidsColNum	= WhichMatchListItem(ColNameList,"_res",";")		
			if (ResidsColNum > 2)
				ResWaveName	= StringFromList(ResidsColNum, LoadNames)
				Duplicate /O $ResWaveName, $FullResName
			else
				// Make our own residuals
				Duplicate /O $FitWaveName, $FullResName
				WAVE Data 	= $FullDataName
				WAVE Fit		= $FullFitName
				WAVE Resids	= $FullResName
				Resids = Data - Fit
			endif
			WaveNameList += FullResName+";"
			
			// Load each successive column with a proper "_???" type suffix
			for (i=ResidsColNum;i<NumCols;i+=1)
				FitPeakName	= StringFromList(i, ColNameList)
				suffix = ReturnLastSuffix(FitPeakName,"_")
				
				if (strlen(suffix) > 0)
					FitPeakName		= StringFromList(i, LoadNames)
					FullFitPeakName 	= SampleName + "_" + suffix
					Duplicate /O $FitPeakName, $FullFitPeakName
					WaveNameList += FullFitPeakName+";"
				endif
			endfor
		else
			Print " *** Cannot automatically load data & fit from text files without '_fit', etc suffixes in the column headings!"
		endif
	endif
	
	WaveList_StripOrReplaceNaNs(WaveNameList,0,0)
//	StripNANsFromDataWavesInList(WaveNameList)
	
	if ((NumType(DecimateNum) == 0) && (DecimateNum != 1))
		Print " 			... decimating axis and data by",DecimateNum
		WaveList_Decimate(WaveNameList,DecimateNum)
	endif
	
	KillWavesFromList(LoadNames,1)

	return SampleName
End



// ***************************************************************************
// **************** 		Loading n data waves from a file with a single column - like Witec Raman
// ***************************************************************************

// Load a single X-axis for all the loads ... or use the first in the file. 
Function PromptFor1ColumnInputs()

	NVAR g1ColAxisInFile 		= root:SPECTRA:GLOBALS:g1ColLoadAxis
	NVAR g1ColNumPts 			= root:SPECTRA:GLOBALS:g1ColNumPts

	Variable AxisIsInFile = (g1ColAxisInFile==1) ? 1 : 2
	Prompt AxisIsInFile, "Axis is first in column ...", popup, "yes;no;"
	Variable ColNumPts = g1ColNumPts
	Prompt ColNumPts, "(... if yes) number of points per spectrum"
	DoPrompt "Loading 1-column data file", AxisIsInFile, ColNumPts
	if (V_flag)
		return 1
	endif
	
	SetDataFolder root:SPECTRA:Import
		KillWaves /A/Z
	
	g1ColAxisInFile 	= AxisIsInFile
	if (g1ColAxisInFile == 1)
		g1ColNumPts 		= ColNumPts
	else
		// Need to load a separate text file. 
		LoadWave /Q/G/D/A=axis1col/O/E=0
	
		if (GetRTError(1))
			Print " 		*** Could not load a separate axis file ... cancelling 1-column load." 
			return 1
		else
			WAVE Axis 	= $("root:SPECTRA:Import:axis1col0")
			ColNumPts 	= DimSize(Axis,0)
			if ((numtype(ColNumPts)!=0) || (ColNumPts<2)) 
				Print " 		*** No axis values in file ... cancelling 1-column load." 
				return 1
			else
				g1ColNumPts 		= ColNumPts
			endif
		endif
	endif
	
	return 0
End

Function Load1ColumnData(FileName, SampleName,NewLoadFolderNumber,NLoaded)
	String FileName, SampleName
	Variable NewLoadFolderNumber, &NLoaded
	
	NVAR gSortFlag 			= root:SPECTRA:GLOBALS:gSortFlag
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	NVAR g1ColAxisInFile 	= root:SPECTRA:GLOBALS:g1ColLoadAxis
	NVAR g1ColNumPts 		= root:SPECTRA:GLOBALS:g1ColNumPts
	
	String AxisWaveName, DataWaveName, FullDataName, DataName, DataNote
	Variable i, iStart=0, LoadError, NColPts, NSpectra
	
	SetDataFolder root:SPECTRA:Import
		
		WAVE Axis1C 	= $("root:SPECTRA:Import:axis1col0")
	
		String PathAndFileName = gPath2Data + FileName
		
		// General text load works for CARY datasheet format. 
		LoadWave /Q/G/D/A=wave/E=0 PathAndFileName
	
		if (GetRTError(1))	// not sure what to do here
			return 0
		endif
		
		WAVE Column 	= $StringFromList(0,S_Wavenames)
		NColPts 		= DimSize(Column,0)
		NSpectra 		= (g1ColAxisInFile==1) ? (NColPts/g1ColNumPts)-1 : (NColPts/g1ColNumPts)
		Print " *** Loaded a single column data file containing",NSpectra,"spectra."
		
		// Record the filename and file creation date to the wave note. 
		GetFileFolderInfo /Z/Q PathAndFileName
		DataNote 	= FileName + "\r"
		DataNote 	+= gPath2Data + "\r"
		DataNote 	+= "CreationDate="+Secs2Date(V_creationDate,-2)+";" + "\r"
		DataNote 	+= "CreationTime="+Secs2Time(V_creationDate,3)+";" + "\r"
		
		Make /O/D/N=(g1ColNumPts) Data, Axis
		
		if (g1ColAxisInFile)
			Axis[] 	= Column[p]
			iStart 	= g1ColNumPts
		else
			Axis 	= Axis1C
		endif
			
		
		for (i=iStart;i<NSpectra;i+=1)
		
			DataName 		= SampleName+"_"+num2str(i)
			Data[] 			= Column[i*g1ColNumPts + p]
			
			SingleAxisDataErrorsFitLoad(DataName,DataNote,Axis,Data,$"",$"",$"",$"")
		endfor
		
	return 1
End

// A set of Igor text files. 
Function LoadKolXPD(FileName, SampleName,NewLoadFolderNumber,NLoaded)
	String FileName, SampleName
	Variable NewLoadFolderNumber, &NLoaded
	
	NVAR gSortFlag 			= root:SPECTRA:GLOBALS:gSortFlag
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	String AxisWaveName, DataWaveName, FullDataName, DataName, DataNote
	Variable i, iStart=0, LoadError, NColPts, NSpectra
	
	SetDataFolder root:SPECTRA:Import
	
		String PathAndFileName = gPath2Data + FileName
		
		// General text load works for CARY datasheet format. 
		LoadWave /T/D/A=wave/E=0 PathAndFileName
		
//		WAVE Column 	= $StringFromList(0,S_Wavenames)
//		NColPts 		= DimSize(Column,0)
//		NSpectra 		= (g1ColAxisInFile==1) ? (NColPts/g1ColNumPts)-1 : (NColPts/g1ColNumPts)
		
		NSpectra 		= ItemsInList(S_Wavenames)
		Print " *** Loaded a KolXPD file containing",NSpectra,"spectra."
		
		// Record the filename and file creation date to the wave note. 
		GetFileFolderInfo /Z/Q PathAndFileName
		DataNote 	= FileName + "\r"
		DataNote 	+= gPath2Data + "\r"
		DataNote 	+= "CreationDate="+Secs2Date(V_creationDate,-2)+";" + "\r"
		DataNote 	+= "CreationTime="+Secs2Time(V_creationDate,3)+";" + "\r"
			
		
		for (i=iStart;i<NSpectra;i+=1)
		
			if (Wavetype($StringFromList(i,S_Wavenames),1) != 1)
			else
				DataName 		= SampleName+"_"+num2str(i)
				WAVE Data 	= $StringFromList(i,S_Wavenames)
				
				Duplicate /FREE Data, Axis
				Axis[] 		= DimOffset(Data,0) + p * DimDelta(Data,0)
				
				SingleAxisDataErrorsFitLoad(DataName,DataNote,Axis,Data,$"",$"",$"",$"")
			endif
		endfor
		
	return 1
End
	
// ***************************************************************************
// **************** 		Loading n data waves from a file with a TWO columns - like Rigaku XRD
// ***************************************************************************

Function Load2ColumnData(FileName, SampleName,NewLoadFolderNumber,NLoaded)
	String FileName, SampleName
	Variable NewLoadFolderNumber, &NLoaded
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	String DataName, DataNote
	Variable i, iStart=0, LoadError
	
	SetDataFolder root:SPECTRA:Import
	
		KillNNamedWaves("wave",100)
		String PathAndFileName = gPath2Data + FileName
		
		// General text load works for CARY datasheet format. 
		LoadWave /Q/G/D/A=wave/E=0 PathAndFileName
		Variable NWaves 	= ItemsInList(S_Wavenames)
	
		if (GetRTError(1))	// not sure what to do here
			print " *** Unknown problem trying to open a 2-column file with multiple axis-data sets" 
			return 0
		elseif (!CheckEvenVariable(NWaves))
			print " *** Trying to load a 2-column file with multiple axis-data sets, but loaded an odd number of waves ... aborting" 
			// return 0
		else
			print " *** Loaded a 2-column file with ",NWaves/2," axis-data sets" 
		endif
		
		// Record the filename and file creation date to the wave note. 
		GetFileFolderInfo /Z/Q PathAndFileName
		DataNote 	= FileName + "\r"
		DataNote 	+= gPath2Data + "\r"
		DataNote 	+= "CreationDate="+Secs2Date(V_creationDate,-2)+";" + "\r"
		DataNote 	+= "CreationTime="+Secs2Time(V_creationDate,3)+";" + "\r"
		
		Variable NCols = 3
		for (i=0;i<NWaves;i+=NCols)
			WAVE Axis 		= $("wave"+num2str(i))
			WAVE Data 		= $("wave"+num2str(i+1))
			
			DataNote 	+= "DataBlock="+num2str(i)+";" + "\r"
			SingleAxisDataErrorsFitLoad(SampleName,DataNote,Axis,Data,$"",$"",$"",$"")
		endfor
		
	return 1
End

// ***************************************************************************
// **************** 		Loading n pairs of axis-data columns
// ***************************************************************************

Function LoadNAxisDataColumns(FileName, SampleName,NewLoadFolderNumber,NLoaded)
	String FileName, SampleName
	Variable NewLoadFolderNumber, &NLoaded
	
	NVAR gSortFlag 			= root:SPECTRA:GLOBALS:gSortFlag
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	String LoadedList, ColNameList, ColName, AxisWaveName, DataWaveName, FullDataName, DataName, DataNote
	Variable i, LoadError, NColumns, NData, NPts
	
	SetDataFolder root:SPECTRA:Import
		KillWaves /A/Z
	
		String PathAndFileName = gPath2Data + FileName
		
		// General text load works for CARY datasheet format. 
		LoadWave /Q/G/D/A=wave/E=0 PathAndFileName
		LoadError 	= GetRTError(1)
	
		if (LoadError)	// not sure what to do here
			return 0
		else
			LoadedList 	= S_Wavenames
			NColumns 	= ItemsInList(S_Wavenames)
			NData 		= trunc(NColumns/2)
			Print " *** Loaded",NData,"column pairs."
		endif
		
		// Record the filename and file creation date to the wave note. 
		GetFileFolderInfo /Z/Q PathAndFileName
		DataNote 	= FileName + "\r"
		DataNote 	+= gPath2Data + "\r"
		DataNote 	+= "CreationDate="+Secs2Date(V_creationDate,-2)+";" + "\r"
		DataNote 	+= "CreationTime="+Secs2Time(V_creationDate,3)+";" + "\r"
		
		ColNameList =  ReturnListOfColumnHeadings(PathAndFileName,"",-1,NColumns,0)
		
		for (i=0;i<NData;i+=1)
			AxisWaveName 	= StringFromList(2*i, LoadedList)
			DataWaveName 	= StringFromList(2*i+1, LoadedList)
			
			DataName 			= SampleName+"_"+num2str(i)
			
			if (strlen(SampleName)>22)
				DataName 	= GetSampleName(DataName,"","",0,1,1)
				if (cmpstr("_quit!_",DataName) == 0)
					KillWavesFromList(LoadedList,1)
					return 0
				endif
			endif
			DataName 	= AvoidDataNameConflicts(DataName,"_r",wDataList)
			
			Duplicate /O/D $AxisWaveName, $(DataName+"_axis") /WAVE=axis
			Duplicate /O/D $DataWaveName, $(DataName+"_data") /WAVE=data
			
			if (gSortFlag)
				Sort axis, axis, data
			endif
			
			if (strlen(ColNameList) > 0)
				ColName 	= StringFromList(2*i,ColNameList)
				if (strlen(ColName) == 0)
					ColName 	= StringFromList(2*i,ColNameList)
				endif
				DataNote 	= ColName + "\r" + DataNote
			endif
			
			SingleAxisDataErrorsFitLoad(DataName,DataNote,Axis,Data,$"",$"",$"",$"")
		endfor
	
		KillWaves /A/Z
	SetDataFolder root:
	
	return 1
End

// ***************************************************************************
// **************** 		Loading axis and n-data format
// ***************************************************************************

Function LoadMultipleWavesFromFile(FileName, SampleName,NewLoadFolderNumber,NLoaded)
	String FileName, SampleName
	Variable NewLoadFolderNumber, &NLoaded
	
	NVAR gAxisCol 				= root:SPECTRA:GLOBALS:gAxisCol
	NVAR gSortFlag 			= root:SPECTRA:GLOBALS:gSortFlag
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	Variable i, NumCols, NumTitles, NameSource=0, NHeaderLines=0, NFileLines=0, AxisCol
	String LoadNames, AxisWaveName, DataWaveName, FullDataName, DataName, DataNote
	String ColNameList, ColName="", ColNote="", HeaderString=""
	
	SetDataFolder root:SPECTRA:Import
	
		String PathAndFileName = gPath2Data + FileName
		
		// ---- The general text-file loading attempt
		LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,-1)
		if (ItemsInList(LoadNames) < 2)
			FindStartOfData(PathAndFileName,NHeaderLines, NFileLines)
			LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,-1)
		endif
		
		if (strlen(LoadNames) == 0)
			Print " *** Cannot find the end of the header lines and the start of the data."
			return 0
		endif
		
		// Record the filename and file creation date to the wave note. 
		GetFileFolderInfo /Z/Q PathAndFileName
		DataNote 	= FileName + "\r"
		DataNote 	+= gPath2Data + "\r"
		DataNote 	+= "CreationDate="+Secs2Date(V_creationDate,-2)+";" + "\r"
		DataNote 	+= "CreationTime="+Secs2Time(V_creationDate,3)+";" + "\r"
		
		// Try to load a list of column headings
		NumCols 		= ItemsInList(LoadNames)
		ColNameList 	= ReturnListOfColumnHeadings(PathAndFileName,HeaderString,NHeaderLines,NumCols,1)
		NumTitles 		= ItemsInList(ColNameList)
		if (NumTitles != NumCols)
			NameSource = 1
			Print " 		... Found",NumTitles,"column headings but",NumCols," columns so name columns numerically "
		endif
		
		if (gSortFlag > 2)
			Print " 		.... Sorting data so that axis runs low to high."
			SortWavesFromList(LoadNames,0)
		endif
		
		AxisCol 				= gAxisCol
		AxisWaveName 	= StringFromList(AxisCol, LoadNames)
		
//		for (i=AxisCol+1;i<NumCols;i+=1)
		for (i=0;i<NumCols;i+=1)
		
			if (i != AxisCol)
				DataWaveName 	= StringFromList(i, LoadNames)
				
				if (NumTitles == NumCols)
					ColName 			= StringFromList(i, ColNameList)
					ColNote 			= DataNote + "Column = "+ ColName + "\r"
				endif
				
				if (NameSource == 0)
					DataName 		= SampleName + "_" + CleanUpName(ColName,0)
				else
					DataName 		= SampleName+"_col"+num2str(i)
				endif
				
				if (strlen(SampleName)>22)
					DataName 	= GetSampleName(DataName,"","",0,1,1)
					if (cmpstr("_quit!_",DataName) == 0)
						KillWavesFromList(LoadNames,1)
						return 0
					endif
				endif
				DataName 	= AvoidDataNameConflicts(DataName,"_r",wDataList)
				
				Duplicate /O/D $AxisWaveName, $(DataName+"_axis") /WAVE=axis
				Duplicate /O/D $DataWaveName, $(DataName+"_data") /WAVE=data
				
				SingleAxisDataErrorsFitLoad(DataName,DataNote,Axis,Data,$"",$"",$"",$"")
			endif
			
		endfor
		
		KillWaves /A/Z
	SetDataFolder root:
	
	return 1
End

Function PromptForMultiColumnInput()
	
	Variable MultiAxisCol	= NumVarOrDefault("root:SPECTRA:GLOBALS:gMultiAxisCol", 0)
	Prompt MultiAxisCol, "The x-axis is in which column? [First column is #0]"
	Variable MultiColTitleLook	= NumVarOrDefault("root:SPECTRA:GLOBALS:gMultiColTitleLook", -1) 
	Prompt MultiColTitleLook, "Look for column titles in the file?", popup, "yes;no;"
	Variable MultiColTitleUse	= NumVarOrDefault("root:SPECTRA:GLOBALS:gMultiColTitleUse", -1) 
	Prompt MultiColTitleUse, "Use column titles as date names?", popup, "yes;no;"
	Variable MultiColTitleCheck	= NumVarOrDefault("root:SPECTRA:GLOBALS:gMultiColTitleCheck", -1) 
	Prompt MultiColTitleCheck, "Interactively check column title read?", popup, "yes;no;"
	
	DoPrompt "Loading many columns from a single file", MultiAxisCol, MultiColTitleLook, MultiColTitleCheck
	if (V_flag)
		return 0
	endif
	
	Variable /G $("root:SPECTRA:GLOBALS:gMultiAxisCol")=MultiAxisCol
	Variable /G $("root:SPECTRA:GLOBALS:gMultiColTitleLook")= MultiColTitleLook	
	Variable /G $("root:SPECTRA:GLOBALS:gMultiColTitleUse")=MultiColTitleUse
	Variable /G $("root:SPECTRA:GLOBALS:gMultiColTitleCheck")= MultiColTitleCheck
	return 1
End

// ***************************************************************************
// **************** 		General Interactive Procedure for Single Text file load
// ***************************************************************************
Function /T InteractiveLoadTextFile(Msg)
	String Msg
	
	Variable FileRefNum
	
	Open /R/Z=2/M=Msg/R/T="????" FileRefNum
	if (V_Flag!=0)
		if (V_Flag == -1)
			Print " *** Data load cancelled by user."
		else
			// Unknown problem
		endif
		return ""
	else
		Close FileRefNum
		String Path2File = S_fileName
		
		// Label the loaded data by its column name
		Loadwave /W/A/O/D/G/Q Path2File
	endif
	
	return S_WaveNames
End

// ***************************************************************************
// **************** 					Standard TEXT file input
// ***************************************************************************
Function PromptForColumnNumbers()
	
	Variable AxisCol	= NumVarOrDefault("root:SPECTRA:GLOBALS:gAxisCol", 0)
	Prompt AxisCol, "The x-axis is in which column? [First column is #0]"
	Variable AxisSigCol	= NumVarOrDefault("root:SPECTRA:GLOBALS:gAxisSigCol", -1) 
	Prompt AxisSigCol, "(Optional) Axis errors are in which column?"
	Variable DataCol	= NumVarOrDefault("root:SPECTRA:GLOBALS:gDataCol", 1) 
	Prompt DataCol, "The data is in which column?"
	Variable DataSigCol	= NumVarOrDefault("root:SPECTRA:GLOBALS:gDataSigCol", -1) 
	Prompt DataSigCol, "(Optional) Data errors are in which column?"
	Variable DecimateNum	= NumVarOrDefault("root:SPECTRA:GLOBALS:gDecimateNum", 1) 
	Prompt DecimateNum, "(Optional) Bin values into n"
	
	DoPrompt "Please enter the axis & data column numbers.", AxisCol, AxisSigCol, DataCol, DataSigCol, DecimateNum
	if (V_flag)
		return 1
	else
		Variable /G $("root:SPECTRA:GLOBALS:gAxisCol")=AxisCol
		Variable /G $("root:SPECTRA:GLOBALS:gAxisSigCol")= AxisSigCol	
		Variable /G $("root:SPECTRA:GLOBALS:gDataCol")=DataCol
		Variable /G $("root:SPECTRA:GLOBALS:gDataSigCol")= DataSigCol
		Variable /G $("root:SPECTRA:GLOBALS:gDecimateNum")= DecimateNum
		return 0
	endif
End

Function PromptForAxisColumn()
	
	Variable AxisCol	= NumVarOrDefault("root:SPECTRA:GLOBALS:gAxisCol", 0)
	Prompt AxisCol, "The x-axis is in which column? [First column is #0]"
	
	DoPrompt "Please enter the axis column numbers.", AxisCol
	if (V_flag)
		return 1
	else
		Variable /G $("root:SPECTRA:GLOBALS:gAxisCol")=AxisCol
		return 0
	endif
End


Function PromptForComplexType()
	
	Variable ComplexCol1	= NumVarOrDefault("root:SPECTRA:GLOBALS:gComplexCol1", 0)
	Prompt ComplexCol1, "Complex column 1"
	Variable ComplexCol2	= NumVarOrDefault("root:SPECTRA:GLOBALS:gComplexCol2", 0)
	Prompt ComplexCol2, "Complex column 2"
	
	Variable ComplexType	= NumVarOrDefault("root:SPECTRA:GLOBALS:gComplexType", 0)
	Prompt ComplexType, "Format for complex data", popup, "rectangular;polar;"
	Variable ComplexPhase	= NumVarOrDefault("root:SPECTRA:GLOBALS:gComplexPhase", 0)
	Prompt ComplexPhase, "For polar data, phase is in", popup, "radians;degrees"
	Variable ComplexDecimate	= NumVarOrDefault("root:SPECTRA:GLOBALS:gComplexDecimate", 0)
	Prompt ComplexDecimate, "(Optional) Decimate number"
	
	DoPrompt "Loading complex data", ComplexCol1, ComplexCol2, ComplexType, ComplexPhase, ComplexDecimate
	if (V_flag)
		return 1
	else
		Variable /G $("root:SPECTRA:GLOBALS:gComplexCol1")=ComplexCol1
		Variable /G $("root:SPECTRA:GLOBALS:gComplexCol2")=ComplexCol2
		Variable /G $("root:SPECTRA:GLOBALS:gComplexType")=ComplexType
		Variable /G $("root:SPECTRA:GLOBALS:gComplexPhase")=ComplexPhase
		Variable /G $("root:SPECTRA:GLOBALS:gComplexDecimate")=ComplexDecimate
		return 0
	endif
End

// ***************************************************************************
// **************** 		Subdivide files in which multiple spectra are simply appended
// ***************************************************************************
Function /T SegmentData(SampleName,FolderName)
	String SampleName,FolderName
	
	WAVE Data 	= $(ParseFilePath(2,FolderName,":",0,0) + SampleName) + "_data"
	WAVE Axis 	= $(ParseFilePath(2,FolderName,":",0,0) + SampleName) + "_axis"
	
	String segDataName, segAxisName, segSampleName, segSampleNameList=""
	
	Variable segStart, segStop, segNPts, StepSign, NextStepSign
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
				break
			endif
		while(1)
		
		segStop 		= i
		segNPts 		= segStop - segStart + 1
		
		StepSign 		= NextStepSign
		
		if (segNPts > 2)
			SegmentNum += 1
		
			segSampleName 		= SampleName + "_S" + FrontPadVariable(SegmentNum,"0",2)
			segSampleNameList 	= segSampleNameList + segSampleName + ";"
			
			segDataName 		= segSampleName + "_data"
			segAxisName 		= segSampleName + "_axis"
		
			Make /O/D/N=(segNPts) $(ParseFilePath(2,FolderName,":",0,0)+segDataName) /WAVE=segData
			Make /O/D/N=(segNPts) $(ParseFilePath(2,FolderName,":",0,0)+segAxisName) /WAVE=segAxis
			
			segData[] 	= Data[segStart+p]
			segAxis[] 	= Axis[segStart+p]
		endif
	
	while(i < (NPts-2))
	
	return segSampleNameList
End

// ***************************************************************************
// **************** 					3-column pH measurement data; pH volume time (temp)
// ***************************************************************************
Function /T LoadpHMeasurementFile(FileName,DataName,SampleName)
	String FileName, DataName, SampleName
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	Variable i, j=0, NCols, NPnts, ProcFlag=1
	Variable pHColNum=0, VolColNum=1, TimeColNum=2
	String pHDataName, DataWaveName, FullDataName, AxisWaveName, FullAxisName, DataNameList="",PathAndFileName
	
	FullDataName=SampleName+"_data"
	FullAxisName=SampleName+"_axis"
	
	PathAndFileName = gPath2Data + FileName
	
	Loadwave /Q/N/O/D/J/K=2 PathAndFileName	// <--- Delimited text format, loading all columns as text. 
	
	NCols 	= V_flag
	if (NCols < 3)
		Print " *** The chosen file",FileName,"contains too few columns (",V_flag,")"
		return ""
	endif
	
	WAVE /T pHText 		= $(StringFromList(pHColNum, S_Wavenames))
	WAVE /T TimeText 	= $(StringFromList(TimeColNum, S_Wavenames))
	
	NPnts = numpnts(pHText)
	Make /O/D/N=(NPnts) pHData, TimeData
	
	pHData[] 		= str2num(pHText[p])
	TimeData[] 	= 60* str2num(ParseFilePath(0,TimeText[p],":",0,0)) + str2num(ParseFilePath(0,TimeText[p],":",0,1))
	TimeData 		/= 60 // Convert to minutes. 
	
	KillWavesFromList(S_wavenames,1)
	
	Duplicate /O pHData, $FullDataName
	Duplicate /O TimeData, $FullAxisName
	
	KillWaves /Z pHData, TimeData
	
	DataNameList += FullDataName+";"
	
	return DataNameList
End

// ***************************************************************************
// **************** 					3-column pH stat data; pH volume time (temp)
// ***************************************************************************
Function /T LoadpHStatFile(FileName,DataName,SampleName)
	String FileName, DataName, SampleName
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	Variable i, j=0, NCols, NPnts, ProcFlag=1
	Variable pHColNum=0, VolColNum=1, TimeColNum=2
	String pHDataName, DataWaveName, FullDataName, AxisWaveName, FullAxisName, DataNameList="",PathAndFileName
	
	pHDataName=SampleName+"_pH"
	FullDataName=SampleName+"_data"
	FullAxisName=SampleName+"_axis"
	
	PathAndFileName = gPath2Data + FileName
	
	Loadwave /Q/N/O/D/J/K=2 PathAndFileName	// <--- Delimited text format, loading all columns as text. 
	
	NCols 	= V_flag
	if (NCols < 3)
		Print " *** The chosen file",FileName,"contains too few columns (",V_flag,")"
		return ""
	endif
	
	WAVE /T pHText 		= $(StringFromList(pHColNum, S_Wavenames))
	WAVE /T VolText 		= $(StringFromList(VolColNum, S_Wavenames))
	WAVE /T TimeText 	= $(StringFromList(TimeColNum, S_Wavenames))
	
	NPnts = numpnts(pHText)
	Make /O/D/N=(NPnts) pHData, VolData, TimeData
	
	pHData[] 		= str2num(pHText[p])
	VolData[] 		= str2num(VolText[p])
	TimeData[] 	= 60* str2num(ParseFilePath(0,TimeText[p],":",0,0)) + str2num(ParseFilePath(0,TimeText[p],":",0,1))
	TimeData 		/= 60 // Convert to minutes. 
	
	KillWavesFromList(S_wavenames,1)
	
	// An option to pare down the data
	Prompt ProcFlag, "Process the stat data", popup, "yes;no;"
	Variable StatTit = NumVarOrDefault("root:SPECTRA:GLOBALS:gStatTit", 1)
	Prompt StatTit, "Titrant", popup, "acid;base;"
	Variable StatpH = NumVarOrDefault("root:SPECTRA:GLOBALS:gStatpH", 7)
	Prompt StatpH, "The statted pH"
	DoPrompt "pH Stat load", ProcFlag, StatTit, StatpH
	if (V_Flag)
		return ""
	endif
	
	Variable /G root:SPECTRA:GLOBALS:gStatTit = StatTit
	Variable /G root:SPECTRA:GLOBALS:gStatpH = StatpH
	
	if (ProcFlag == 1)
		FindLevels /Q/EDGE=(StatTit)/P pHData, StatpH
		WAVE Levels 	= W_FindLevels
		
		if (V_LevelsFound == 0)
			Print " *** pH never crossed",StatpH,". Please check pH stat conditions."
			return ""
		else
			Print " *** pH stat data with",V_LevelsFound,"points crossing pH=",StatpH
		endif
		
		Make /O/D/N=(V_LevelsFound) $FullDataName /WAVE=data
		Make /O/D/N=(V_LevelsFound) $FullAxisName /WAVE=axis
		
		axis[]	= TimeData[Levels[p]]
		data[]	= VolData[Levels[p]]
	else
		Duplicate /O pHData, $pHDataName
		Duplicate /O VolData, $FullDataName
		Duplicate /O TimeData, $FullAxisName
	endif
	
	KillWaves /Z pHData, VolData, TimeData
	
	DataNameList += FullDataName+";"
	
	return DataNameList
End



// ***************************************************************************
// **************** 					TITRATION DATA input
// ***************************************************************************

// Loads the Mettler LabXLite converted text files, ending in ".csv" or ".txt"
Function /T ConvertT70Data(FileName,DataName,SampleName)
	String FileName, DataName, SampleName
	
	SVAR gPath2Data 	  = root:SPECTRA:GLOBALS:gPath2Data
	
	String T70Name, T70SaveName, ExciseStr, suffix, PathAndFileName = gPath2Data + FileName
	Variable i, refNum, UnicodePts, AsciiPts, StartIdx, EndIdx
	
	GBLoadWave /T={72,72} /A/Q PathAndFileName		// Load into unsigned binary wave.

	T70Name = StringFromList(0, S_waveNames)			// S_waveNames is set by GBLoadWave.
	WAVE T70Data = $T70Name
	
	UnicodePts = numpnts(T70Data)
	
	if (UnicodePts<2 || T70Data[0] != 0xFF || T70Data[1] != 0xFE)
		// Check the Unicode BOM (byte-order mark) which is in the first two bytes.
		KillWaves /Z T70Data
		// Print  " *** Aborting Titration Data load. This file is not a Unicode 16-bit, little-endian file. BOM is missing or wrong. "
		return ""
	endif
	
	AsciiPts = (UnicodePts - 2) / 2
	Make /O/N=(AsciiPts)/B/U T70Num
	Make /T/O/N=(AsciiPts) T70Char, tempT70Char
	Make /O/N=4/B/U T70Seq = {69,81,80}
	ReDimension /U T70Seq
	
	T70Num	= T70Data[2+2*p]		// Transfer even bytes after the BOM to output.
	T70Char	= num2char(T70Num[p])
	tempT70Char = T70Char
	
	do
		// Strip lines containing equivalence point information
		FindSequence /S=0/I=T70Seq T70Num
		StartIdx = V_value
			
		if (StartIdx > -1)
			FindValue /S=(StartIdx+1)/I=13 T70Num
			EndIdx = V_value
			
			ExciseStr=""
			for (i=StartIdx;i<EndIdx;i+=1)
				ExciseStr += T70Char[i]
			endfor
			Print " *** Equivalence point: ",ExciseStr
			
			DeletePoints StartIdx, (EndIdx-StartIdx+2), T70Num, T70Char
		endif
	while(StartIdx > -1)
	
	suffix 				= ReturnLastSuffix(FileName,".")
	T70SaveName 		= StripSpacesAndSuffix(FileName,".") + "_asc.tit"
	PathAndFileName 	= gPath2Data + T70SaveName
	Open refNum as PathAndFileName
	FBinWrite refNum, T70Num
	Close refNum
	
	KillWaves /Z T70Data, T70Num, tempT70Char, T70Seq
		
	return T70SaveName
End


// ***************************************************************************
// **************** 					SSRL XAS .dat files
// ***************************************************************************

Function /T LoadSSRLXANESSpectrum(FileName,SampleName)
	String FileName, SampleName
	
	DoWindow/K ALS_QX_Avs
	Print " || Loading LS .qx XANES data from: ",FileName
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data	
	String PathAndFileName 	= gPath2Data + FileName 
	
	Make /T/FREE/N=0 SSRLXASOffsets
	Make /T/FREE/N=0 SSRLXASColTitles
	
	Variable DataRow, ECol, I0Col, I1Col, I2Col, LyttleCol
	
	DataRow = LoadSSRLXANESHeader(PathAndFileName,  XASOffsets,XASColTitles, ECol,I0Col,I1Col,I2Col,LyttleCol)
	
End

// Special function for the .qx files 
// OUTPUTS: 
Function LoadSSRLXANESHeader(PathAndFileName,  XASOffsets,XASColTitles, ECol,I0Col,I1Col,I2Col,LyttleCol)
	String PathAndFileName
	Wave XASOffsets
	WAVE /T XASColTitles
	Variable &ECol, &I0Col, &I1Col, &I2Col, &LyttleCol
	
	String XRFLine
	Variable i=0, n, colNum=0, colFlag=0, LineNum=0, FileRefNum
	
	Variable NPts, NCols
	
	Open /R FileRefNum as PathAndFileName
	do
		// Read individual lines of text sequentially
		FReadLine FileRefNum, XRFLine
		LineNum += 1
		
		if (strlen(XRFLine) == 0)
			break	// No more lines in file.
			
		elseif (StrSearch(XRFLine,"PTS:",0) > -1)
			NPts 		= ReturnNthNumber(XRFLine,1)
			NCols 	= ReturnNthNumber(XRFLine,2)
			
			Redimension /N=(NCols) XASOffsets, XASColTitles
			
		elseif (StrSearch(XRFLine,"Offsets:",0) > -1)
			FReadLine FileRefNum, XRFLine
			LineNum += 1
			
			XRFLine 	= ReplaceString("	",XRFLine,";")+";"
			ListValuesToWave(XASOffsets,XRFLine,";",1)
			
		elseif (StrSearch(XRFLine,"Data:",0) > -1)
		
			for (n=0;n<NCols;n+=1)
				FReadLine FileRefNum, XRFLine
				LineNum += 1
			
				XASColTitles[n] 	= XASColTitles
				
				if (StrSearch(XRFLine,"Requested Energy",0) > -1)
					ECol 	= n
				elseif (StrSearch(XRFLine,"I0",0) > -1)
					I0Col	= n
				elseif (StrSearch(XRFLine,"I1",0) > -1)
					I1Col	= n
				elseif (StrSearch(XRFLine,"I2",0) > -1)
					I2Col	= n
				elseif (StrSearch(XRFLine,"Lyttle",0) > -1)
					LyttleCol 	= n
				endif
			endfor
			
		endif

	while(1)
	Close FileRefNum
	
	// Return the line number for the start of the data block. 
	return LineNum
End


// ***************************************************************************
// **************** 					ALS 10.3.2 .qx files
// ***************************************************************************

// For the ALS '.qx' load
Function DefaultOrManualScalers(ScalarWave, ScalarList)
	WAVE ScalarWave
	String ScalarList
	
	String ScalerStr
	Variable i, NScalers = ItemsInList(ScalarList,",")
	
	if ( NScalers> 0)
		// Reset the scaler wave 
		ScalarWave = 0
		for (i=0;i<NScalers;i+=1)
			ScalerStr = StringfromList(i,ScalarList)
			ScalarWave[str2num(ScalerStr)] = 1
		endfor
	endif
End 


// Need to know the nymber of Scalers = Data blocks
// Loads a 10.3.2 '.qx' file. 
Function /T LoadALSXANESSpectrum(FileName,SampleName)
	String FileName, SampleName
	
	DoWindow/K ALS_QX_Avs
	Print " || Loading LS .qx XANES data from: ",FileName
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data	
	String PathAndFileName 	= gPath2Data + FileName 
	String XASNote 				= SampleName+"\r"+FileName+"\r"+gPath2Data+"/r"
	
	String XRFLine, DataLine, PosStr, PosNote, IoScalers="", FYScalers="",Scaler_Name, Scaler_Name_List=""
	Variable i, j, FileRefNum, Success, NPts, NScalers, NRegions, NScans, NLines, ScalarN, ScalarAvg, LineN, XX,YY, EShift, GlitchPnt
	
	Make /D/O/N=0 Numerator, Denominator, Deadtimes, Dwells, Energy
	
	Success = LoadALSXANESHeader(PathAndFileName, Numerator,Denominator,Deadtimes,Dwells,Energy,  NPts, NScalers, NRegions, NScans, NLines, XX,YY)
	if (Success==0)
		return ""
	endif

	SVAR gALSNumScalers 			= root:SPECTRA:GLOBALS:gALSNumScalers
	SVAR gALSDenScalers 			= root:SPECTRA:GLOBALS:gALSDenScalers
	
	DefaultOrManualScalers(Numerator,gALSNumScalers)
	DefaultOrManualScalers(Denominator,gALSDenScalers)
	
	// Here we have the choice of loading the individual scans or just the average. 
	
	for (i=0;i<NScalers;i+=1)
		for (j=0;j<NLines;j+=1)
			Make /O/D/N=(NPts) $("scalar_"+num2str(i)+"_line_"+num2str(j))
			
			Scaler_Name 	= "scalar_"+num2str(i)+"_line_"+num2str(j)
			Scaler_Name_List = AddListItem(Scaler_Name,Scaler_Name_List)
		endfor
		Make /O/D/N=(NPts) $("scalar_"+num2str(i)+"_avg")
		WAVE  	scalar_avg = $("scalar_"+num2str(i)+"_avg")
		scalar_avg = 0
		Scaler_Name 	= "scalar_"+num2str(i)+"_avg"
		Scaler_Name_List = AddListItem(Scaler_Name,Scaler_Name_List)
	endfor

	Open /R FileRefNum as PathAndFileName
	do
		// Read individual lines of text sequentially
		FReadLine FileRefNum, XRFLine
		
		if (strlen(XRFLine) == 0)
			break	// No more lines in file.
			
		elseif (StrSearch(XRFLine,", 0, 0]",0) > -1)
			ScalarN 		= ReturnNthNumber(XRFLine,1)
			WAVE  	avg 	= $("scalar_"+num2str(ScalarN)+"_avg")
			
			for (j=0;j<NLines;j+=1)
				FReadLine FileRefNum, XRFLine
				
				DataLine 	= ListFromLine(XRFLine, "\t")
				
				// A whole spectrum is in 1 line
				WAVE data 	= $("scalar_"+num2str(ScalarN)+"_line_"+num2str(j))
				data[] 		= str2num( stringFromList(p,DataLine) )
				
				// Hmmm ... really we should perform glitch calibration on every line ... but don't have the Izero yet. 
				// GlitchCalibration(Energy, Izero, Spectrum, GlitchEnergy)
				
				// Skip data with NaNs
				ScalarAvg 		= mean(data)
				if (numtype(ScalarAvg)==0)
					avg[] 		+= data[p]
				endif
				
			endfor
		endif
	while(1)
	Close FileRefNum
	
	Make /O/D/N=(NPts) scalar_num=0, scalar_den=0, spectrum
	
	for (i=0;i<NScalers;i+=1)
		WAVE  	avg 		= $("scalar_"+num2str(i)+"_avg")
		if (Numerator[i] > 0)
			ScalarAvg 		= mean(avg)
			if (numtype(ScalarAvg)==0)
				FYScalers 	= FYScalers + num2str(i) + ","
				scalar_num[]		+= avg[p]
			endif
		endif
		if (Denominator[i] > 0)
			ScalarAvg 		= mean(avg)
			if (numtype(ScalarAvg)==0)
				IoScalers 	= IoScalers + num2str(i) + ","
				scalar_den[]		+= avg[p]
			endif
		endif
	endfor
	
	Print " 		.... Read Fluorescence Signal from channels:",FYScalers,"and I-zero from channels:",IoScalers
		
	NVAR gGlitchEnergy 			= root:SPECTRA:GLOBALS:gALSGlitchEnergy	
	//if (gGlitchEnergy > -1)
		EShift = GlitchCalibration(Energy, scalar_den, scalar_num, gGlitchEnergy,GlitchPnt)
		Print " 		.... Glitch calibration shift =",EShift,"eV to match",gGlitchEnergy
	//endif
	
	spectrum[] 	= scalar_num[p]/scalar_den[p]
	
	// find the edge onset
	Differentiate spectrum/D=spectrum_DIF
	WaveStats /Q/M=1 spectrum_DIF
	Variable DifMaxPt = V_maxloc
	Variable DifMaxE = Energy[V_maxloc]
		
	Success = FitXASPreEdge("pre-edge", Energy,spectrum,SampleName,DifMaxE,1,1)
	KillWaves /Z spectrum_DIF
	
	ALSXANESDisplay(Energy,Spectrum,Izero_Flat,NScalers,NLines,GlitchPnt)
	
	sprintf PosStr, "%.4f", XX
	PosNote = "X="+PosStr+";"
	sprintf PosStr, "%.4f", YY
	PosNote += "Y="+PosStr+";"
	
	XASNote 	= PosNote + "\r" + XASNote
	Note spectrum, XASNote
	
	String FullAxisName=SampleName+"_axis"
	Duplicate /O Energy, $FullAxisName

	String FullDataName=SampleName+"_data"
	Duplicate /O spectrum, $FullDataName
	
	// KillWavesFromList(Scaler_Name_List,0)
	
	if (Success == 1)
		return SampleName + ";"
	else
		return ""
	endif
End
	
	
// Special function for the .qx files 
// OUTPUTS: 
Function LoadALSXANESHeader(PathAndFileName,  Num,Denom,DTs,Ts, Energy,  NPts, NScalers, NRegions, NScans, NLines, XX, YY)
	String PathAndFileName
	Wave Num, Denom, DTs, Ts, Energy
	Variable &NPts, &NScalers, &NRegions, &NScans, &NLines,  &XX, &YY
	
	String XRFLine, EnergyLine, DTLine, PosList
	Variable i=0, LineNum=0, FileRefNum
	
	Open /R FileRefNum as PathAndFileName
	do
		// Read individual lines of text sequentially
		FReadLine FileRefNum, XRFLine
		LineNum += 1
		
		if (strlen(XRFLine) == 0)
			break	// No more lines in file.
			
		elseif (StrSearch(XRFLine,"Stage position=",0) > -1)
			XX 		= ReturnNthNumber(XRFLine,1)
			YY 		= ReturnNthNumber(XRFLine,2)
			
		elseif (StrSearch(XRFLine,"Regions=",0) > -1)
			NRegions 	= ReturnLastNumber(XRFLine)
			
		elseif (StrSearch(XRFLine,"Scans in set=",0) > -1)
			NScans 	= ReturnLastNumber(XRFLine)
			
		elseif (StrSearch(XRFLine,"Points=",0) > -1)
			NPts 		= ReturnLastNumber(XRFLine)
			Redimension /N=(NPts) Energy
			
		elseif (StrSearch(XRFLine,"Scalers=",0) > -1)
			NScalers 	= ReturnLastNumber(XRFLine)
			Redimension /N=(NScalers) Num, Denom, DTs, Ts
			
		elseif (StrSearch(XRFLine,"Number of lines=",0) > -1)
			NLines 	= ReturnLastNumber(XRFLine)
			
		elseif (StrSearch(XRFLine,"Numerator plot=",0) > -1)
			DTLine 	= ReplaceString("Numerator plot= ",XRFLine,"")
			DTLine 	= ListFromLine(DTLine, " ")
			Num[] 	= str2num( stringFromList(p,DTLine) )
			
		elseif (StrSearch(XRFLine,"Denominator plot=",0) > -1)
			DTLine 	= ReplaceString("Denominator plot= ",XRFLine,"")
			DTLine 	= ListFromLine(DTLine, " ")
			Denom[] 	= str2num( stringFromList(p,DTLine) )
			
		elseif (StrSearch(XRFLine,"Energies=",0) > -1)
			EnergyLine 	= ReplaceString("Energies= ",XRFLine,"")
			EnergyLine 	= ListFromLine(EnergyLine, " ")
			Energy[] 		= str2num( stringFromList(p,EnergyLine) )
			
		elseif (StrSearch(XRFLine,"Deadtimes=",0) > -1)
			DTLine 	= ReplaceString("Deadtimes= ",XRFLine,"")
			DTLine 	= ListFromLine(DTLine, " ")
			DTs[] 	= str2num( stringFromList(p,DTLine) )
		
		elseif (StrSearch(XRFLine,"********** Start of data block",0) > -1)
			break
		endif

	while(1)
	Close FileRefNum
	return 1
End

// ***************************************************************************
// **************** 					XANES file input 
// ***************************************************************************

Function /T LoadSingleXANESFile(FileName,SampleName)
	String FileName, SampleName
	
	WAVE /T wDataList 	= root:SPECTRA:wDataList
	NVAR gSortFlag 		= root:SPECTRA:GLOBALS:gSortFlag
	NVAR gAxisColNum 	= root:SPECTRA:GLOBALS:gXASAxisColNum
	SVAR gDataColStr	= root:SPECTRA:GLOBALS:gXASDataColStr
	NVAR gDataColNum	= root:SPECTRA:GLOBALS:gXASDataColNum
	NVAR gIoColNum		= root:SPECTRA:GLOBALS:gXASIoColNum
	NVAR gFoilColNum	= root:SPECTRA:GLOBALS:gXASFoilColNum
	//
	NVAR gXASPreset		= root:SPECTRA:GLOBALS:gXASPreset
	NVAR gNormChoice	= root:SPECTRA:GLOBALS:gXASNormChoice
	NVAR gFoilChoice	= root:SPECTRA:GLOBALS:gXASFoilChoice
	NVAR gFoilEdge		= root:SPECTRA:GLOBALS:gXASFoilEdge
	NVAR gDataEdge		= root:SPECTRA:GLOBALS:gXASDataEdge
	SVAR gPreEdgeFit 	= root:SPECTRA:GLOBALS:gXASPreEdgeFit
	NVAR gXASXYFlag 	= root:SPECTRA:GLOBALS:gXASXYFlag
	//
	SVAR gAxisUnits 		= root:SPECTRA:GLOBALS:gXASAxisUnits
	SVAR gPath2Data 		= root:SPECTRA:GLOBALS:gPath2Data	
	
	Variable i, FoilChoice, FoilColNum, DataColNum1, DataColNum2, DummyFlag, SuccessFlag = 1, PreEdgeFlag=0, Shift, LoadError
	String DataWaveName, FullDataName, AxisWaveName, FullAxisName, IoWaveName, FullIoName, WaveNameList=""
	String FoilWaveName, FullFoilName, FoildEName, FoildE2Name, ShiftFoildName, OrigDataName, ShiftDataName
	String LoadNames, PathAndFileName = gPath2Data + FileName 
	
	Print " || Loading XANES data from: ",FileName
	
	Variable NHeaderLines=0, NFileLines=0, MinColNum = 2
	
	MinColNum 				= (gIoColNum > -1) ? MinColNum+1 : MinColNum
	MinColNum 				= (gFoilColNum > -1) ? MinColNum+1 : MinColNum
	
	// ---- The general text-file loading attempt
	LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,MinColNum)
	if (ItemsInList(LoadNames) < 2)
		FindStartOfData(PathAndFileName,NHeaderLines, NFileLines)
		LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,MinColNum)
	endif
	
	if (strlen(LoadNames) == 0)
		Print " *** Cannot find the end of the header lines and the start of the data."
		return ""
	endif
	
	if (gSortFlag > 2)
		Print " 		.... Sorting data so that axis runs low to high."
		SortWavesFromList(LoadNames,gAxisColNum)
	endif
	
	AxisWaveName=StringFromList(gAxisColNum, LoadNames)
	FullAxisName=SampleName+"_axis"
	Duplicate /O $AxisWaveName, $FullAxisName
	WAVE XASAxis = $FullAxisName
	
	if (numpnts(XASAxis) < 10)
		Print " 		.... Not enough points in this file! ", numpnts(XASAxis)
		return ""
	endif
	
	String Message="", XASNote=SampleName+"\r"+FileName+"\r"
	
	// Check for a simple column number or a range
	if (CountNumbersInString(gDataColStr,0) == 1)
		DataColNum1 	= str2num(gDataColStr)
		DataWaveName=StringFromList(DataColNum1, LoadNames)
		WAVE XASData = $DataWaveName
	else
		DataColNum1 	= ReturnNthNumber(gDataColStr,1)
		DataColNum2 	= ReturnNthNumber(gDataColStr,2)
		Duplicate /O/D XASAxis, XASData
		XASData=0
		for (i=DataColNum1;i<=DataColNum2;i+=1)
			WAVE XASSingleData = $StringFromList(i, LoadNames)
			XASData += XASSingleData
		endfor
		XASData /= (DataColNum2-DataColNum1+1)
	endif

	FullDataName=SampleName+"_data"
	Duplicate /O XASData, $FullDataName
	WAVE XASDataNorm = $FullDataName
	
	WaveNameList 	= FullDataName + ";" + FullAxisName + ";"
	
	if (gXASXYFlag ==1)
		Variable XX, YY
		String XStr, YStr
		SuccessFlag = FindXYPosn(PathAndFileName,"# ACTUAL:	YAXIS:",XX,YY)
		if (SuccessFlag)
			sprintf XStr, "%.4f", XX
			sprintf YStr, "%.4f", YY
			Note XASDataNorm, "X="+XStr+";Y="+YStr
		endif
	endif
	
	IoWaveName=StringFromList(gIoColNum, LoadNames)
	FullIoName=SampleName+"_Izero"
	if (WaveExists($IoWaveName))
		Duplicate /O $IoWaveName, $FullIoName
		WAVE XASIzero = $FullIoName
		WaveNameList 	+= FullIoName + ";"
	endif
	
	if (gNormChoice == 2)
		Message = "Normalized XAS TRANSMISSION data (i.e., calculating absorbance)"
		XASDataNorm = log(XASIzero/XASData)
	elseif (gNormChoice == 3)
		Message = "Normalized XAS FLUORESCENCE data"
		XASDataNorm = XASData/XASIzero
	elseif (gNormChoice == 4)
		Message = "Calculated the difference between two XAS signals"
		XASDataNorm = XASData - XASIzero
	elseif (gNormChoice == 5)
		Message = "Averaged two XAS signals"
		XASDataNorm = (XASData + XASIzero)/2
	elseif (gNormChoice == 6)
		Message = "Calculated the delta-OD"
		XASDataNorm = (XASData - XASIzero)/XASIzero
	elseif (gNormChoice == 7)
		XASDataNorm *= -1
	endif
	XASNote = XASNote + Message + "\r"
	Print " 		...."+Message
	
	if (cmpstr("none",gPreEdgeFit)!=0)
		if (BinarySearch($FullAxisName,gDataEdge)<0)
			Variable DataEdge	= gDataEdge
			Prompt DataEdge, "[Optional] threshold energy"
			String AxisUnits = gAxisUnits
			Prompt AxisUnits, "[Optional] energy units",popup,"eV;keV;"
			DoPrompt "Input XAS parameters", DataEdge, AxisUnits
			if (V_flag)
				// do nothing
			else
				gAxisUnits	= AxisUnits
				gDataEdge 	= DataEdge
				if (BinarySearch($FullAxisName,DataEdge)<0)
					Print " 		.... The input threshold still not inside energy axis range! Cannot remove pre-edge. "
				else
					PreEdgeFlag = 1
					gDataEdge = DataEdge
				endif
			endif
		else
			PreEdgeFlag = 1
		endif
	endif
	
	Variable AxisScale = (cmpstr("keV",gAxisUnits) == 0) ? 0.001 : 1
	
	FoilChoice 	= (gXASPreset == 8) ? 0 : gFoilChoice
	
	if (FoilChoice > 1)
		
//		FoilColNum 	= (gFoilChoice == 3) ? gFoilColNum : gDataColNum 	// This is wrong
	
		FoilColNum 		= (gFoilChoice == 3) ? gDataColNum : gFoilColNum
		FoilWaveName	= StringFromList(FoilColNum, LoadNames)
		WAVE XASFoil = $(FoilWaveName)
		WaveNameList 	+= FoilWaveName + ";"
		
		if (WaveExists(XASFoil) == 1)
			NewDataFolder /O Foil
			
			FullFoilName 		= SampleName+"_foil"
			FoildEName 			= SampleName+"_fdE"
			FoildE2Name 		= SampleName+"_fdE2"
			ShiftFoildName 		= SampleName+"_fshift"
			OrigDataName	 	= SampleName+"_orig"
			ShiftDataName 		= SampleName+"_shift"
			
			Duplicate /O XASFoil, $(":Foil:"+FullFoilName), $(":Foil:"+FoildEName), $(":Foil:"+FoildE2Name),$(":Foil:"+ShiftFoildName)
			WAVE XASFoilNorm 	= $(":Foil:"+FullFoilName)
			WAVE XASFoildE 		= $(":Foil:"+FoildEName)
			WAVE XASFoildE2 		= $(":Foil:"+FoildE2Name)
			WAVE XASShiftFoil 	= $(":Foil:"+ShiftFoildName)
			
			Duplicate /O XASDataNorm, $(":Foil:"+OrigDataName), $(":Foil:"+ShiftDataName)
			WAVE XASOrigData 	= $(":Foil:"+OrigDataName)
			WAVE XASShiftData 	= $(":Foil:"+ShiftDataName)
			
			if (FoilChoice == 2)
				Message = "Normalized FOIL TRANSMISSION data"
				XASFoilNorm 	= log(XASIzero/XASFoil)
				XASNote = XASNote + Message + "\r"
				Print " 		...."+Message
			else
				XASFoilNorm 	= XASDataNorm
			endif
			
			XASFoildE 		= XASFoilNorm
			Differentiate XASFoildE /X=XASAxis
			
			XASFoildE2 	= XASFoildE
			Differentiate XASFoildE2 /X=XASAxis
			
			Shift = FoilCalibration(XASAxis,XASDataNorm,XASShiftData,XASFoilNorm,XASShiftFoil,XASFoildE,gFoilEdge,AxisScale)
			
			if (PreEdgeFlag == 1)
				SuccessFlag = FitXASPreEdge(gPreEdgeFit, XASAxis,XASShiftFoil,SampleName,gDataEdge,AxisScale,1)
			endif
			
			if (abs(Shift) > (0.05*AxisScale))
				Message = "Shifted the data by"+num2str(Shift)+"eV so reference ('foil') inflection point lies at"+num2str(gFoilEdge)+"eV."
				Duplicate /O/D XASShiftFoil, $FullFoilName
				Duplicate /O/D XASShiftData, $FullDataName
			else
				Message = "The foil threshold is "+num2str(Shift)+"eV from the input inflection point"+num2str(gFoilEdge)+"eV."
				Duplicate /O/D XASFoilNorm, $FullFoilName
			endif
			XASNote = XASNote + Message + "\r"
			Print " 		...."+Message
		endif
	endif
	
	Note XASDataNorm, XASNote
	
	if (PreEdgeFlag == 1)
		SuccessFlag = FitXASPreEdge(gPreEdgeFit, XASAxis,XASDataNorm,SampleName,gDataEdge,AxisScale,1)
	endif
	
	// *** I think this should occur BEFORE any fitting or other processing
	StripNANsFromDataWavesInList(WaveNameList)
	
//	KillWavesFromList(LoadNames,1)
	KillWaves /Z $FullIoName
	
	if (SuccessFlag == 1)
		return SampleName + ";"
//		return FullDataName + ";"
	else
		return ""
	endif
End

// Look for the X< Y coordinates 
// SSRL xdi: 				# ACTUAL:	YAXIS: -6.4358	ZAXIS: 1.285
Function FindXYPosn(PathAndFileName,LineStr,  XX,YY)
	String PathAndFileName,, LineStr
	Variable &XX, &YY

	Variable refNum
	String TitleLine
	
	Open/R refNum as PathAndFileName
	if (refNum == 0)
		return -1
	endif
	
	do
		FReadLine refNum, TitleLine
		
		if (strlen(TitleLine) == 0)
			Close refNum
			return -1
		elseif (StrSearch(TitleLine,LineStr,0) > -1)
			XX = ReturnNthNumber(TitleLine,1)
			YY = ReturnNthNumber(TitleLine,2)
			Close refNum
			return 1
		endif
		
	while(1)
End

Function ALSXANESDisplay(Energy,Spectrum,Izero_Flat,NScalers,NLines,GlitchPnt)
	Wave Energy,Spectrum, Izero_Flat
	Variable NScalers, NLines, GlitchPnt
	
	Variable i, j
	
	Display /K=1/W=(783,205,1255,558) as "ALS .qx load scalar averages"
	
	DoWindow/C ALS_QX_Avs
	
	for (i=0;i<NScalers;i+=1)
		for (j=0;j<NLines;j+=1)
			WAVE data 	= $("scalar_"+num2str(i)+"_line_"+num2str(j))
			KillWaves /Z data
		endfor
		WAVE  	scalar_avg = $("scalar_"+num2str(i)+"_avg")
		AppendToGraph scalar_avg vs Energy
	endfor
	ModifyGraph highTrip(bottom)=100000
	
	ColorPlotTraces()
	
	AppendToGraph/R /R spectrum vs Energy 
	ModifyGraph lSize(spectrum)=4, rgb(spectrum)=(34952,34952,34952,32768)
	
	AppendToGraph/L=GlitchAxis Izero_Flat vs Energy
	ModifyGraph freePos(GlitchAxis)=0
	
	ModifyGraph axisEnab(right)={0,0.7}, axisEnab(left)={0,0.7}, axisEnab(GlitchAxis)={0.75,1}
	
	Cursor/P/H=1 A Izero_Flat GlitchPnt
	ShowInfo
End	

// The Energy axis is not shifted. The Energy_SS axisis shifted. 
//	SELENIUM: 10.3.2 reference glitch energy is 12738.59 eV. However, because we are using FindPeak not CurveFit ...
// ... this routine gives virtually identical results using a glitch energy of 12738.39 eV

Function GlitchCalibration(Energy, Izero, Spectrum, GlitchEnergy, GlitchPnt)
	Wave Energy, Izero, Spectrum
	Variable GlitchEnergy, &GlitchPnt
	
	Variable MaxPnt, MaxVal, EPt1, GPt, EPt2, AxisShift = 0 
	
	Duplicate /O Energy, Energy_SS, Izero_SS, Izero_Flat, Shifted
	
	Interpolate2/T=3/F=1/Y=Izero_SS/X=Energy_SS/I=3 Energy, Izero
	
	Izero_Flat = abs(Izero - Izero_SS)
	
	WaveStats/Q/M=1 Izero_Flat
	MaxPnt 	= V_MaxLoc
	MaxVal 	= V_Max
	
	EPt1			= BinarySearchInterp(Energy,GlitchEnergy-10)
	EPt2			= BinarySearchInterp(Energy,GlitchEnergy+10)
	FindPeak /Q/M=(MaxVal/2)/R=(EPt1,EPt2) Izero_Flat
	
	GlitchPnt 	= V_PeakLoc
	
	if (GlitchEnergy < 0)
		return 0
	endif
	
	if (V_flag==0)
		
		// This would give better agreement with 10.3.2 'cooked' data. 
		// CurveFit gauss :SPECTRA:Import:Izero_Flat[pcsr(A),pcsr(B)] /X=:SPECTRA:Import:Energy /D 
		
		GPt 			= Energy[V_PeakLoc]
		AxisShift 	= GlitchEnergy - GPt
		
		Energy_SS 	-= AxisShift
		
		Shifted[] 	= Izero[BinarySearchInterp(Energy, Energy_SS[p])]
		Izero[] 		= Shifted
		
		Shifted[] 	= Spectrum[BinarySearchInterp(Energy, Energy_SS[p])]
		Spectrum[] 	= Shifted
	endif
	
	return AxisShift
End

Function FoilCalibration(Axis,DataNorm,ShiftDataNorm,FoilNorm,ShiftFoilNorm,FoildE,FoilEdge,AxisScale)
	Wave Axis,DataNorm,ShiftDataNorm,FoilNorm,ShiftFoilNorm,FoildE
	Variable FoilEdge, AxisScale
	
	WaveStats /Q/M=1 FoildE
	K0 	= 0
	K1 	= FoildE[V_maxloc]
	K2 	=Axis[ V_maxloc]
	K3 	= 0.5*AxisScale
	
	CurveFit /Q/G/N gauss FoildE(V_maxloc-3,V_maxloc+3) /X=Axis /D
	
	WAVE W_coef 	= W_coef
	Variable Shift 	= (FoilEdge - AxisScale*W_coef[2])
	KillWaves /Z W_coef, W_sigma
	
	ShiftDataOnAxis(Axis,ShiftFoilNorm,FoilNorm,Shift,0)
	ShiftDataOnAxis(Axis,ShiftDataNorm,DataNorm,Shift,0)
	
	return Shift
End

Function PromptForALSXANESParams()

	String OldDF = getDataFolder(1)
	NewDataFolder/O root:SPECTRA
	NewDataFolder/O/S root:SPECTRA:GLOBALS

		Variable ALSGlitchEnergy = NumVarOrDefault("root:SPECTRA:GLOBALS:gALSGlitchEnergy", -1)
		Prompt ALSGlitchEnergy, "[Optional] Io glitch energy (eV)"
		
		String ALSNumScalers = StrVarOrDefault("root:SPECTRA:GLOBALS:gALSNumScalers", "")
		Prompt ALSNumScalers, "[Optional] Scalar list for XANES, e.g. '1,2,3,4' "
		
		String ALSDenScalers = StrVarOrDefault("root:SPECTRA:GLOBALS:gALSDenScalers", "")
		Prompt ALSDenScalers, "[Optional] Scalar list for Izero"
	
		DoPrompt "ALS XANES .qx Load", ALSGlitchEnergy, ALSNumScalers, ALSDenScalers
		if (V_flag)
			return 1
		endif
		
		Variable /G gALSGlitchEnergy = ALSGlitchEnergy
		String /G gALSNumScalers = ALSNumScalers
		String /G gALSDenScalers = ALSDenScalers
	
	SetDataFolder $(OldDF)
	
	return 0
End

Function PromptForXANESInputParams()
	
	String OldDF = getDataFolder(1)
	NewDataFolder/O root:SPECTRA
	NewDataFolder/O/S root:SPECTRA:GLOBALS
	
	Variable XASPreset = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASPreset", 1)
	Prompt XASPreset, "Preset column assignment?", popup, "none;BL7 XAS TEY;BL7 XAS FY;BL8 XAS TEY;BL8 XAS FY;SSRL Transmission;SSRL FY;SSRL Foil;SSRL xdi;"
	
	Variable XASAxisCol = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASAxisColNum", 0)
	Prompt XASAxisCol, "Energy axis column"
	
	Variable XASIoCol = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASIoColNum", 1) 
	Prompt XASIoCol, "Izero column"
	 
	Variable XASDataCol = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASDataColNum", 1) 
//	Prompt XASDataCol, "Sample column"
	String XASDataColStr = StrVarOrDefault("root:SPECTRA:GLOBALS:gXASDataColStr", "1") 
	Prompt XASDataColStr, "Sample column(s)"
	
	Variable XASFoilChoice = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASFoilChoice", 1) 
	Prompt XASFoilChoice, "Calibrate?", popup, "no;foil;sample;" 
	 
	Variable XASFoilCol = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASFoilColNum", 1) 
	Prompt XASFoilCol, "Standard column"
	
	Variable XASNormChoice = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASNormChoice", 1) 
	Prompt XASNormChoice, "Normalization method", popup, "none;Log(I/Io);I/Io;I-Io;(I+Io)/2;(I-Io)/Io;Invert;" 
	
	Variable XASFoilEdge = NumVarOrDefault("root:SPECTRA:GLOBALS:gXASFoilEdge", -1)
	Prompt XASFoilEdge, "[Optional] threshold energy"
	
	String XASPreEdgeFit = StrVarOrDefault("root:SPECTRA:GLOBALS:gXASPreEdgeFit", "none") 
	Prompt XASPreEdgeFit, "Handle background and edge jump?",popup,"none;pre-edge;arc-tan;"
	
	String XASAxisUnits		= StrVarOrDefault("root:SPECTRA:GLOBALS:gXASAxisUnits", "eV") 
	Prompt XASAxisUnits, "[Optional] energy units",popup,"eV;keV;"
	
	DoPrompt "XANES Input Parameters.", XASPreset, XASAxisCol, XASIoCol, XASDataColStr, XASFoilChoice, XASFoilCol, XASFoilEdge, XASNormChoice, XASPreEdgeFit, XASAxisUnits
	if (V_flag)
		return 1
	endif
	
	Variable /G gXASFoilColNum 	= -1
	
	Variable /G gXASXYFlag 		= 0
		
	if (XASPreset == 1)
		// Completely Manual entry
		Variable /G gXASAxisColNum 	= XASAxisCol
		Variable /G gXASIoColNum 	= XASIoCol
		String /G gXASDataColStr 	= XASDataColStr
		Variable /G gXASDataColNum 	= XASDataCol
		Variable /G gXASFoilColNum	= XASFoilCol
		Variable /G gXASNormChoice = XASNormChoice
		Variable /G gXASFoilChoice 	= XASFoilChoice
		Variable /G gXASFoilEdge 	= XASFoilEdge
	elseif (XASPreset == 2)
		// BL7 XANES TEY
		Variable /G gXASAxisColNum 	= 0
		Variable /G gXASIoColNum 	= 3
		Variable /G gXASDataColNum 	= 1
		String /G gXASDataColStr 	= "1"
		Variable /G gXASNormChoice 	= 3
		Variable /G gXASFoilChoice 	= 1
	elseif (XASPreset == 3)
		// BL7 XANES FY
		Variable /G gXASAxisColNum 	= 0
		Variable /G gXASIoColNum 	= 3
		Variable /G gXASDataColNum 	= 2
		String /G gXASDataColStr 	= "2"
		Variable /G gXASNormChoice 	= 3
		Variable /G gXASFoilChoice 	= 1
	elseif (XASPreset == 4)
		// BL8 XANES TEY
		Variable /G gXASAxisColNum 	= 0
		Variable /G gXASIoColNum 	= 4
		Variable /G gXASDataColNum 	= 5
		String /G gXASDataColStr 	= "5"
		Variable /G gXASNormChoice 	= 3
		Variable /G gXASFoilChoice 	= 1
	elseif (XASPreset == 5)
		// BL8 XANES FY
		Variable /G gXASAxisColNum 	= 0
		Variable /G gXASIoColNum 	= 4
		Variable /G gXASDataColNum 	= 6
		String /G gXASDataColStr 	= "6"
		Variable /G gXASNormChoice 	= 3
		Variable /G gXASFoilChoice 	= 1
	elseif(XASPreset == 6)
		// SSRL Transmission
		Variable /G gXASAxisColNum 	= 2
		Variable /G gXASIoColNum 	= 3
		Variable /G gXASDataColNum 	= 4
		String /G gXASDataColStr 	= "4"
		Variable /G gXASFoilColNum 	= 5
		Variable /G gXASNormChoice 	= 2
		Variable /G gXASFoilChoice 	= 2
	elseif(XASPreset == 7)
		// SSRL Fluorescence
		Variable /G gXASAxisColNum 	= 2
		Variable /G gXASIoColNum 	= 3
		Variable /G gXASDataColNum 	= 6
		String /G gXASDataColStr 	= "6"
		Variable /G gXASFoilColNum 	= 5
		Variable /G gXASNormChoice 	= 3
		Variable /G gXASFoilChoice 	= 2
	elseif(XASPreset == 8)
		// SSRL Foil Transmission
		Variable /G gXASAxisColNum 	= 2
		Variable /G gXASIoColNum 	= 4
		Variable /G gXASDataColNum 	= 5
		String /G gXASDataColStr 	= "5"
		Variable /G gXASFoilColNum 	= 5
		Variable /G gXASNormChoice 	= 2
		Variable /G gXASFoilChoice 	= 1
	elseif(XASPreset == 9)
		// SSRL µXRF .xdi
		Variable /G gXASAxisColNum 	= 0
		Variable /G gXASIoColNum 	= 2
		Variable /G gXASDataColNum 	= 8
		String /G gXASDataColStr 	= "8"
		Variable /G gXASFoilColNum 	= -1
		Variable /G gXASNormChoice 	= 3
		Variable /G gXASFoilChoice 	= 1
		Variable /G gXASXYFlag 		= 1
	endif
	
	Variable /G gXASPreset 		= XASPreset
	Variable /G gXASFoilEdge 		= XASFoilEdge
	Variable /G gXASDataEdge 	= XASFoilEdge
	Variable /G gXASFoilChoice	= XASFoilChoice
	//
	String /G gXASPreEdgeFit 	= XASPreEdgeFit
	String /G gXASAxisUnits		= XASAxisUnits

	return 0
	
	SetDataFolder $(OldDF)
End

// ***************************************************************************
// **************** 					GenX file input 
// ***************************************************************************

Function /T LoadGenXDataFit(FileName, SampleName)
	String FileName, SampleName
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	String AxisWaveName, FullAxisName, DataWaveName, FullDataName, FitWaveName, FullFitName
	String LoadNames, PathAndFileName = gPath2Data + FileName 
	
	Variable NHeaderLines=3, NFileLines=0, MinColNum=4
	
	LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,MinColNum)
	
	WAVE Axis = $StringFromList(0, LoadNames)
	Duplicate /O Axis, $(SampleName+"_axis") /WAVE=GenXAxis
	
	WAVE Data = $StringFromList(2, LoadNames)
	Duplicate /O Data, $(SampleName+"_data") /WAVE=GenXData
	
	WAVE Fit = $StringFromList(1, LoadNames)
	Duplicate /O Fit, $(SampleName+"_fit") /WAVE=GenXFit
	
	WAVE Sig = $StringFromList(3, LoadNames)
	Duplicate /O Sig, $(SampleName+"_data_sig") /WAVE=GenXSig
	
//	Variable AxisColNum = 0
//	AxisWaveName=StringFromList(AxisColNum, LoadNames)
//	WAVE Axis = $AxisWaveName
//	FullAxisName=SampleName+"_axis"
//	Duplicate /O Axis, $FullAxisName
//	WAVE GenXAxis = $FullAxisName
	
//	Variable DataColNum = 2
//	DataWaveName=StringFromList(DataColNum, LoadNames)
//	WAVE Data = $DataWaveName
//	FullDataName=SampleName+"_data"
//	Duplicate /O Data, $FullDataName
//	WAVE GenXData = $FullDataName
	
//	Variable FitColNum = 1
//	FitWaveName=StringFromList(FitColNum, LoadNames)
//	WAVE Fit = $FitWaveName
//	FullFitName=SampleName+"_fit"
//	Duplicate /O Fit, $FullFitName
//	WAVE GenXFit = $FullFitName
	
	return SampleName+"_axis;" + SampleName + "_data;" + SampleName + "_fit;" + SampleName + "_data_sig;"
End


// ***************************************************************************
// **************** 					ROD file input 
// ***************************************************************************

Function LoadRODDataAndFit(FileName,SampleName,RODSource,FolderNumber,NLoaded)
	String FileName, SampleName,RODSource
	Variable FolderNumber, &NLoaded
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	
	String DataName
	Variable ReqNCols, H, K, L, H0, K0, L0
	
	SetDataFolder root:SPECTRA:Import
		KillWaves /A/Z
		
		String PathAndFileName = gPath2Data + FileName
		
		// Load all the columns using basename "wave"
		Loadwave /Q/A/O/D/G PathAndFileName	// <--- General text format
		
		if (cmpstr(RODSource,"ROD") == 0)
			ReqNCols 		= 7
			Wave HAxis 	= $"wave0"
			Wave KAxis 	= $"wave1"
			Wave LAxis 	= $"wave2"
			Wave RodFit 	= $"wave3"
			Wave FQ 		= $"wave4"
			Wave FQ_sig 	= $"wave5"
			Wave RodRes 	= $"wave6"
		elseif (cmpstr(RODSource,"PDS") == 0)
			ReqNCols 		= 6
			Wave PtIdx 	= $"wave0"
			Wave HAxis 	= $"wave1"
			Wave KAxis 	= $"wave2"
			Wave LAxis 	= $"wave3"
			Wave FQ 		= $"wave4"
			Wave FQ_sig 	= $"wave5"
		endif
		
		if (V_flag != ReqNCols)
			Print " *** The file does not contain enough columns"
			return 0
		endif
			
		Variable ContinueFlag, i = 0, j, NPts = numpnts(HAxis)
		
		Make /O/D/N=(NPts) Axis, Data, Errors, Fit, Resids
		
		H0 	= HAxis[0]
		K0 	= KAxis[0]
		DataName 	= SampleName+"_"+num2str(H0)+num2str(K0)+"L"
		j = 0
		
		do
			i += 1
			
			if (i == NPts)
				// Save this rod scan as we've reached the end of file
				Redimension /N=(j) Axis, Data, Errors, Fit, Resids
				if (cmpstr(RODSource,"ROD") == 0)
					ContinueFlag 	= SingleAxisDataErrorsFitLoad(DataName,"Rod scan from "+FileName,Axis,Data,Errors,Fit,Resids,$"")
				else
					ContinueFlag 	= SingleAxisDataErrorsFitLoad(DataName,"Rod scan from "+FileName,Axis,Data,Errors,$"",$"",$"")
				endif
				break
				
			elseif ((HAxis[i] != H0) || (KAxis[i] != K0) || (LAxis[i] < LAxis[i-1]))
				// Save this rod scan as we've hit a new scan axis
				Redimension /N=(j) Axis, Data, Errors, Fit, Resids
				if (cmpstr(RODSource,"ROD") == 0)
					ContinueFlag 	= SingleAxisDataErrorsFitLoad(DataName,"Rod scan from "+FileName,Axis,Data,Errors,Fit,Resids,$"")
				else
					ContinueFlag 	= SingleAxisDataErrorsFitLoad(DataName,"Rod scan from "+FileName,Axis,Data,Errors,$"",$"",$"")
				endif
				if (ContinueFlag == 0)
					break
				endif
				
				// Reset a new rod scan
				Redimension /N=(NPts) Axis, Data, Errors, Fit, Resids
				H0 	= HAxis[i]
				K0 	= KAxis[i]
				DataName 	= SampleName+"_"+num2str(H0)+num2str(K0)+"L"
				j=0
			endif

			// Keep adding rod points to existing scan
			Axis[j] 	= LAxis[i]
			Data[j] 	= FQ[i]
			Errors[j] 	= FQ_sig[i]
			
			if (cmpstr(RODSource,"ROD") == 0)
				Fit[j] 		= RodFit[i]
				Resids[j] 	= RodRes[i]
			endif
			
			j += 1
		while(i < Npts)
		
		KillWaves /A/Z
	SetDataFolder root:
	
	return 	1
End







// ***************************************************************************
// **************** 		Alternative routine for loading multiple data columns and one axis. 
// ***************************************************************************

//Function LoadAllColumns(PathAndFileName,LoadNames,SampleName,DataNote)
//	String PathAndFileName, LoadNames, SampleName, DataNote
//	
//	String AxisWaveName, DataWaveName, ColName, ColNameList, ColNote = DataNote
//	Variable i, NCols, NameSource=1
//	
//	AxisWaveName 	= StringFromList(0, LoadNames)
//	
//	NCols 	= ItemsInList(LoadNames)
//	
//	for (i=1;i<NCols;i+=1)
//	
//		DataWaveName 	= StringFromList(i, LoadNames)
//		
//		if (NameSource == 0)
//			ColName 		= StringFromList(i, ColNameList)
//			SampleName 	= CleanUpName(ColName,0)
//			ColNote 		+= "Column = "+ ColName + "\r"
//		else
//			SampleName 	= SampleName+"_col"+num2str(i)
//			ColNote 		+= "Column = "+ num2str(i) + "\r"
//		endif
//		
//		if (strlen(SampleName)>22)
//			SampleName 	= GetSampleName(SampleName,"","",0,1,1)
//			if (cmpstr("_quit!_",SampleName) == 0)
//				KillWavesFromList(LoadNames,1)
//				return 0
//			endif
//		endif
//		SampleName 	= AvoidDataNameConflicts(SampleName,"_r",wDataList)
//		
//		Duplicate /O/D $AxisWaveName, $(SampleName+"_axis") /WAVE=axis
//		Duplicate /O/D $DataWaveName, $(SampleName+"_data") /WAVE=data
//		
//		SingleAxisDataErrorsFitLoad(SampleName,DataNote,Axis,Data,$"",$"",$"")
//	endfor
//End