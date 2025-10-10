#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method.


// ***************************************************************************
// **************** 	The main routine for Data & Coefficients Loading
// ***************************************************************************
Function InitializeColumnMerge()

	NewDataFolder /O root:SPECTRA
	NewDataFolder /O root:SPECTRA:Import

	MakeStringIfNeeded("root:SPECTRA:Import:gMergeAxis","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeData","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeHeader","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeKeyWordList","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeColumnList","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeFileName","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeRemoveText","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeReplaceText","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeFileList","")
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeSavePath","none")
	
	MakeVariableIfNeeded("root:SPECTRA:Import:gMergeNPnts",0)
	MakeVariableIfNeeded("root:SPECTRA:Import:gMergeUserFlag",0)
	MakeVariableIfNeeded("root:SPECTRA:Import:gMergeAxisCol",0)
	MakeVariableIfNeeded("root:SPECTRA:Import:gMergeDataCol",1)
	
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeExportFormat","EIS")
	String /G root:SPECTRA:Import:gMergeExportFormatList 	= "delimited text;EIS;"
	
	MakeStringIfNeeded("root:SPECTRA:Import:gMergeAdoptFormat","2-column")
	String /G root:SPECTRA:Import:gMergeAdoptFormatList 	= "2-column;save-data;"
End

// 	Unclear at present what happens when loading multiple files. 
// 		Option 1: Append column data with same titles into an expanded file. E.g., successive time-series for a single experiment. 
// 		Option 2: Automatically Adopt columns from each successive file using last set of criteria. 

Function MergeSelectedDataFiles(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 		= B_Struct.ctrlName
	String WindowName 	= B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	Wave/T FileList			= root:SPECTRA:Data:wFileList
	Wave FileSelection		= root:SPECTRA:Data:wFileSel
	SVAR gPath2Data 		= root:SPECTRA:GLOBALS:gPath2Data

	SVAR gMergeHeader 			= root:SPECTRA:Import:gMergeHeader
	SVAR gMergeKeyWordList 	= root:SPECTRA:Import:gMergeKeyWordList
	SVAR gMergeFileName 		= root:SPECTRA:Import:gMergeFileName
	SVAR gMergeFileList 		= root:SPECTRA:Import:gMergeFileList
	SVAR gMergeColumnList 	= root:SPECTRA:Import:gMergeColumnList
	NVAR gMergeNPnts 			= root:SPECTRA:Import:gMergeNPnts
	NVAR gMergeUserFlag 		= root:SPECTRA:Import:gMergeUserFlag
	
	WaveStats /Q/M=1 FileSelection
	if (V_avg == 0)
		SetDataFolder root:
		return 0
	endif
	
	String FileName, ColumnList=""
	Variable i, N2Merge=0, NPnts=0, NLoaded=0, NMerged, NameFlag=0, NFiles=numpnts(FileList)
	
	// The idea here is to automate the loading of data files if more than one are selected. 
	gMergeUserFlag = (sum(FileSelection) > 1) ? 0 : 1
	
	gMergeFileList = ""
	InitializeColumnMerge()
	RemoveAllColumnsFromTable("ColumnMergePanel#ColumnTable")
	
	SetDataFolder root:SPECTRA:Import
		KillWaves /A/Z
		
		Make /O/T/N=(NLoaded) wColumnList="", wColumnTitle=""
		Make /O/N=(NLoaded) wColumnSel=0
	
		for (i=0;i<NFiles;i+=1)
			if (FileSelection[i] == 1)
				FileName = FileList[i]
				
				if (cmpstr("pxp",ReturnLastSuffix(FileName,".")) == 0)
					// Skip Igor experiment files
				else
					if (strlen(FileName) > 0)
						KillNamedNotebook(FileName)
						
						// Load all the columns. For some reason the "AdoptDataFromMemory" routine keeps returning to the root directory. 
						SetDataFolder root:SPECTRA:Import
							if (!gMergeUserFlag)
								KillAllWavesInFolder("root:SPECTRA:Import:","column*")
							endif
							
							NMerged = ImportColumns(wColumnList,wColumnTitle,gPath2Data,FileName,gMergeHeader,gMergeKeyWordList,NLoaded,NPnts)
						
						if (NMerged > 0)
							gMergeFileName = CleanUpName(StripSuffixBySeparator(ReplaceString(" ",FileName,""),"."),0)
							if (!gMergeUserFlag)
								AdoptNColumns()
								// Reset for the next load
								NLoaded = 0
								Redimension /N=0 wColumnList, wColumnTitle, wColumnSel
								DoUpdate
							endif
						endif
						
//						if (NMerged > 0)
//							if (NameFlag == 0)
//								gMergeFileName = CleanUpName(StripSuffixBySeparator(ReplaceString(" ",FileName,""),"."),0)
//								NameFlag = 1
//							endif
//							gMergeFileList += FileName+";"
//						endif
					endif
				endif
			endif
		endfor
		
//		KillSampleWavesNotInList(SampleName,ListOfWavesToSave)
		
		if (NMerged > 0)
			Redimension /N=(numpnts(wColumnList)) wColumnSel
			gMergeColumnList 	= TextWaveToList(wColumnTitle,-1,"","")
			DefaultAxisAndDataColumns()

			if (gMergeUserFlag)
				CreateColumnMergePanel()
			else
				DoWindow /K ColumnMergePanel
				KillAllWavesInFolder("root:SPECTRA:Import:","column*")
			endif
		else
			DoWindow /K ColumnMergePanel
		endif
	
	SetDataFolder root:
End

Function ImportColumns(wColumnList,wColumnTitle,PathName,FileName,HeaderString,KeyWordList,NLoaded,MaxLen)
	Wave /T wColumnList,wColumnTitle
	String PathName,FileName, HeaderString, KeyWordList
	Variable &NLoaded, &MaxLen
	
//	Variable i, refNum, NColumns, NTitles, NWaves, keyLineNum=-1
	
	Variable i, NumCols,  NumTitles, NumMergeCols, NHeaderLines=0,NFileLines=0, NMerged=0
	String DataNote, LoadNameList, ColName, ColNameList
	
	String PathAndFileName = PathName + FileName
	
	// ---- The general text-file loading attempt
	LoadNameList 	= TrytoLoadSingleTextFile(PathAndFileName,"column",NHeaderLines,NFileLines,-1)
	if (ItemsInList(LoadNameList) < 2)
		FindStartOfData(PathAndFileName,NHeaderLines, NFileLines)
		LoadNameList 	= TrytoLoadSingleTextFile(PathAndFileName,"column",NHeaderLines,NFileLines,-1)
	endif
	
	if (ItemsInList(LoadNameList) < 2)
		Print " *** Cannot find the end of the header lines and the start of the data."
		return 0
	endif
	
	// Record the filename and file creation date to the wave note. 
	GetFileFolderInfo /Z/Q PathAndFileName
	DataNote 	= FileName + "\r"
	DataNote 	+= PathName + "\r"
	DataNote 	+= "CreationDate="+Secs2Date(V_creationDate,-2)+";" + "\r"
	DataNote 	+= "CreationTime="+Secs2Time(V_creationDate,3)+";" + "\r"
	
	// Try to load a list of column headings
	NumCols 		= ItemsInList(LoadNameList)
	ColNameList 	= ReturnListOfColumnHeadings(PathAndFileName,HeaderString,NHeaderLines,NumCols,1)
	NumTitles 		= ItemsInList(ColNameList)
	
	if (NumTitles != NumCols)
		Print " *** Could not load as many column names as there are columns: ", ColNameList
	else
	
		// Make sure we have enough columns to accomodate all the loaded waves
		NumMergeCols 	= numpnts(wColumnList)
		ReDimension /N=(NumMergeCols+NumCols) wColumnList,wColumnTitle
	
		for (i=0;i<NumCols;i+=1)
			ColName 		= StringFromList(i,ColNameList)
			
			if ((ItemsInList(KeyWordList) == 0) || (CheckKeyWordsinString(ColName,KeyWordList) == 1))
				WAVE Column 	= $("root:SPECTRA:Import:column"+num2str(NLoaded+i))
				
				Note /K Column, DataNote
				Note Column, "Column = "+ColName
				
				WaveStats /Q/M=1 Column
				if (V_npnts > MaxLen)
					MaxLen = V_npnts
				endif
				
				wColumnList[NumMergeCols+NMerged] 	= "column"+num2str(NLoaded+i)
				wColumnTitle[NumMergeCols+NMerged] 	= ColName
				
				NMerged += 1
			endif
		endfor
	endif
	
	// Update the suffix index 
	NLoaded += NumCols
	
	// Remove blank columns of unwanted waves
	ReDimension /N=(NumMergeCols+NMerged) wColumnList,wColumnTitle
	
	return NMerged
End

		
		
		
		
		
		
		
//	String PathAndFileName = PathName + FileName
//	
//	// Use Igor's regular text loading routines to try finding numerical columns of data. 
//	Loadwave /Q/A=column/O/D/G PathAndFileName	// <--- General text format
//	NWaves 	= V_flag
//	
//	if (NWaves < 2)
//		Print " *** Too few columns (",V_flag," found in file with General Text load. Try with Delimited Text approach."
//		Loadwave /Q/A=column/O/D/J PathAndFileName	// <--- Delimited text format ... OK for some PC text files, but can leave a NAN at end. 
//		NWaves 	= V_flag
//	endif
//	
//	LookforKeyWordInFile(pathName,FileName,HeaderFlag)
//	
//	if ((NWaves < 2) && (strlen(HeaderFlag) > 0))
//		Print " *** Too few columns (",V_flag," found in file with Delimited Text load. Use the header flag to try to find line containing column headings."
//		Close refNum
//		Open/R/P=$PathName refNum as FileName
//		if (refNum == 0)
//			return 0	// User canceled
//		endif
//		ReturnKeyWordLineInOpenfile(refNum,HeaderFlag,keyLineNum,0)
//		Close refNum
//		if (keyLineNum > -1)
//			Loadwave /Q/A=column/O/D/J/L={0,keyLineNum,0,0,0} PathAndFileName	// <--- General text format
//			NWaves 	= V_flag
//		endif
//	endif
//	
//	// Now look for column titles in the file. 
//	ColumnNames 	= ReturnListOfColumnHeadings(PathAndFileName,HeaderFlag,0,NWaves,1)
//	NTitles 			= ItemsInList(ColumnNames)

// ***************************************************************************
// **************** 			Useful Functions
// ***************************************************************************
Function RemoveAllColumnsFromTable(TableName)
	String TableName
	
	String ColName
	Variable i, NCols
	
	NCols 	= NumberByKey("COLUMNS",TableInfo(TableName, -2))
	
	for (i=NCols;i>-1;i-=1)
		WAVE Column 	= $StringByKey("WAVE",TableInfo(TableName, i))
		
		if (WaveExists(Column))
			RemoveFromTable /W=$TableName Column
		endif
	endfor
End

Function AddColumnsToTable(TableName,FolderName,wColumnList,wColumnTitle,wColumnColor,wColumnAlign,wColumnWidth,wColumnDigits)
	String TableName, FolderName
	Wave /T wColumnList, wColumnTitle, wColumnColor
	Wave wColumnAlign, wColumnWidth, wColumnDigits
	
	String title, rgb
	Variable i, align, r, g, b, NCols = numpnts(wColumnList)
	
//	if (strlen(TableInfo(TableName,-2)) ==0)
//		return 0
//	endif
	
	for (i=0;i<NCols;i+=1)
		WAVE 	Column = $(ParseFilePath(2,FolderName,":",0,0)+wColumnList[i])
		AppendToTable /W= $TableName Column
		ModifyTable /W= $TableName title[i+1]=wColumnTitle[i]
		
		if (WaveExists(wColumnAlign))
			ModifyTable /W= $TableName alignment(Column)=wColumnAlign[i]
		endif
		if (WaveExists(wColumnWidth))
			ModifyTable /W= $TableName width(Column)=wColumnWidth[i]
		endif
		if (WaveExists(wColumnDigits))
			if (wColumnDigits[i] > 0)
				ModifyTable /W= $TableName format(Column)=3
				ModifyTable /W= $TableName digits(Column)=wColumnDigits[i]
			endif
		endif
		
		if (WaveExists(wColumnColor))
			rgb = wColumnColor[i]
			sscanf  rgb, "%u%u%u", r, g, b
			ModifyTable /W= $TableName rgb(Column)=(r,g,b)
		endif
	endfor
End

// ***************************************************************************
// **************** 			Popup Procedures
// ***************************************************************************
Function ColumnPopupProcs(PU_Struct) : PopupMenuControl 
	STRUCT WMPopupAction &PU_Struct 
	
	Variable popNum 			= PU_Struct.popNum
	Variable eventCode 			= PU_Struct.eventCode
	String popStr 				= PU_Struct.popStr
	String ctrlName 			= PU_Struct.ctrlName
	
	if (eventCode!=2)
		return 0
	endif
	
	if (cmpstr("SaveColumnsMenu",ctrlName) == 0)
		SVAR gExportFormat	= root:SPECTRA:Import:gMergeExportFormat
		gExportFormat 	= popStr
		
	elseif (cmpstr("AdoptColumnsMenu",ctrlName) == 0)
		SVAR gAdoptFormat	= root:SPECTRA:Import:gMergeAdoptFormat
		gAdoptFormat 	= popStr
		
	elseif (cmpstr("MergeAxisMenu",ctrlName) == 0)
		SVAR gMergeAxis		= root:SPECTRA:Import:gMergeAxis
		NVAR gMergeAxisCol 	= root:SPECTRA:Import:gMergeAxisCol
		
		gMergeAxis 				= popStr
		gMergeAxisCol			= popNum
		
	elseif (cmpstr("MergeDataMenu",ctrlName) == 0)
		SVAR gMergeData		= root:SPECTRA:Import:gMergeData
		NVAR gMergeDataCol		= root:SPECTRA:Import:gMergeDataCol
		
		gMergeData 				= popStr
		gMergeDataCol 			= popNum
	endif
End

// ***************************************************************************
// **************** 			User Interactions with the ListBox
// ***************************************************************************
Function ColumnListActionProcs(LB_Struct) : ListboxControl 
	STRUCT WMListboxAction &LB_Struct 

	Variable eventCode 		= LB_Struct.eventCode
	Variable row 			= LB_Struct.row
	
	WAVE wColumnSel 		= root:SPECTRA:Import:wColumnSel
	WAVE /T wColumnTitle 	= root:SPECTRA:Import:wColumnTitle
	WAVE /T wColumnList 	= root:SPECTRA:Import:wColumnList
	
	SVAR gMergeColumnList 	= root:SPECTRA:Import:gMergeColumnList
	
	if ((eventCode==4) || (eventCode==5))
		wColumnSel 		= 0
		wColumnSel[row] 	= 1
	endif
	
	if (eventCode == 3)	// Double Click
		String oldTitle 	= wColumnTitle[row]
		String newTitle 	= oldTitle
		Prompt newTitle, "New column title"
		DoPrompt "Change the heading", newTitle
		if (V_flag)
			return 0
		endif
		
		wColumnTitle[row] = newTitle
		return 1
	endif
	
	if ((eventCode == 12) && (row == 8))	// Keystroke, delete
		// Can't find the row selection in the structure ... need to look it up
		FindValue /V=1 wColumnSel
		Variable selRow = V_Value
		
		DoAlert 1, "Remove column: "+wColumnTitle[selRow]+"?"
		if (V_flag == 1)
			RemoveFromTable /W=ColumnMergePanel#ColumnTable $("root:SPECTRA:Import:"+wColumnList[selRow])
			DeletePoints selRow, 1, wColumnSel, wColumnTitle, wColumnList
			
			ListBox ColumnListBox, selRow=selRow
			wColumnSel	 = 0
			wColumnSel[selRow] 	= 1
			
			// Update the list of column titles
			gMergeColumnList 	= TextWaveToList(wColumnTitle,-1,"","")
		endif
		
		return 1
	endif
	
	return 0
End

// ***************************************************************************
// **************** 			ListBox Button Procedures
// ***************************************************************************
Function ColumnListButtonProcs(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 		= B_Struct.ctrlName
	String WindowName 	= B_Struct.win
	Variable eventCode 		= B_Struct.eventCode
	
	if (eventCode != 2)	// Mouse up after pressing
		return 0
	endif
	
	if ((cmpstr(ctrlName,"ColumnUpButton")==0) || (cmpstr(ctrlName,"ColumnDownButton")==0))
		ReOrderColumns(ctrlName)
		return 1
	endif
	
	if (cmpstr(ctrlName,"AdoptNColumnButton")==0)
		Adopt2Columns()
		return 1
	endif
	
	if (cmpstr(ctrlName,"ColumnSavePath")==0)
		SetMergeSavePath()
		return 1
	endif
	
	if (cmpstr(ctrlName,"ColumnAdoptButton")==0)
		AdoptNColumns()
		return 1
	endif
	
	if (cmpstr(ctrlName,"ColumnSaveButton")==0)
		
		PathInfo MergeSavePath
		if (V_flag == 0)
			DoAlert 0, "Please choose a location for saving files"
			SetMergeSavePath()
		endif
		
		SaveColumns()
		return 1
	endif
	
	return 0
End

Function ReOrderColumns(ctrlName)
	String ctrlName

	WAVE /T wColumnTitle 		= root:SPECTRA:Import:wColumnTitle
	WAVE /T wColumnList 		= root:SPECTRA:Import:wColumnList
	WAVE wColumnSel 			= root:SPECTRA:Import:wColumnSel
	
	SVAR gMergeColumnList 	= root:SPECTRA:Import:gMergeColumnList
	
	String swapTitle, swapName
	Variable startRow, selRow, swapRow, nRows=numpnts(wColumnSel)
	
	// Find the first visible row
	ControlInfo /W=ColumnMergePanel ColumnListBox
	startRow 	= V_startRow
	
	// Find the (first) selected row
	FindValue /V=1 wColumnSel
	selRow 		= V_Value

	if (selRow == -1)
		return 0
	endif
		
	if ((cmpstr(ctrlName,"ColumnUpButton")==0) && (selRow > 0))
		swapRow	= selRow - 1
	elseif ((cmpstr(ctrlName,"ColumnDownButton")==0) && (selRow < (nRows-1)))
		swapRow	= selRow + 1
	else
		return 1
	endif
	
	// Swap the Title rows in the ListBox
	swapTitle 					= wColumnTitle[swapRow]
	wColumnTitle[swapRow] 	= wColumnTitle[selRow]
	wColumnTitle[selRow] 		= swapTitle
	
	// Update the ordering of column names
	swapName 					= wColumnList[swapRow]
	wColumnList[swapRow] 	= wColumnList[selRow]
	wColumnList[selRow] 		= swapName
	
	// Redisplay the table
	RemoveAllColumnsFromTable("ColumnMergePanel#ColumnTable")
	AddColumnsToTable("ColumnMergePanel#ColumnTable","root:SPECTRA:Import:",wColumnList,wColumnTitle,$"null",$"null",$"null",$"null")
	
	// Ensure the listbox selection follows
	ListBox ColumnListBox, selRow=swapRow
	wColumnSel[swapRow] 	= 1
	wColumnSel[selRow] 	= 0
	
	// Ensure the selected row does not disappear from view. Somewhat empirical values here. 
	if (swapRow <= startRow+1)
		ListBox ColumnListBox, row=(swapRow-1)
	elseif (swapRow >= startRow+12)
		ListBox ColumnListBox, row=(swapRow-5)
	endif
	
	// Update the list of column titles
	gMergeColumnList 	= TextWaveToList(wColumnTitle,-1,"","")
End

// ***************************************************************************
// **************** 			Saving the columns
// ***************************************************************************
Function SetMergeSavePath()

	SVAR gMergeSavePath 		= root:SPECTRA:Import:gMergeSavePath
	
	NewPath /O/Q/M="Location for saving merged column file" MergeSavePath
	if (V_flag == 0)
		PathInfo MergeSavePath
		gMergeSavePath 	= S_path
		
		TitleBox SaveLocation win=ColumnMergePanel, title=S_path
	endif
End

// ***************************************************************************
// **************** 			SAVING the columns to file
// ***************************************************************************
Function SaveColumns()

	WAVE /T wColumnTitle 		= root:SPECTRA:Import:wColumnTitle
	WAVE /T wColumnList 		= root:SPECTRA:Import:wColumnList
	
	NVAR gNPnts 				= root:SPECTRA:Import:gMergeNPnts
	SVAR gSavePath 			= root:SPECTRA:Import:gMergeSavePath
	SVAR gMergeFileName		= root:SPECTRA:Import:gMergeFileName
	SVAR gExportFormat		= root:SPECTRA:Import:gMergeExportFormat
	
	// Default options for output format. 
	Variable /G root:SPECTRA:Export:gMCNPntsFlag 	= 1
	Variable /G root:SPECTRA:Export:gMCSkipPnts 	= 1
	String /G root:SPECTRA:Export:gMCFmtStr 		= "%1.4#E"
	String /G root:SPECTRA:Export:gMCMargin 		= ""
	String /G root:SPECTRA:Export:gMCDelimiter 	= "	"
	String /G root:SPECTRA:Export:gMCSuffix 		= "txt"
	
	String EOLChar, SaveName, ExportList
	Variable i, NValues, NRows=0, NCols = numpnts(wColumnList)
	
//	SaveName= ReturnMergeName(1,gMergeFileName) 
	SaveName= ReturnMergeName("")
	
	strswitch (gExportFormat)
		case "delimited text":
			if (MultiColumnExportPreferences(1,1,-1,-1,"","","","") == 0)
				return 0
			endif
			EOLChar 	= ReturnEOLCharacter(1,1)
			ExportList 	= TextWaveToList(wColumnTitle,-1,"","")
			PrepareColumnsForExport(ExportList,wColumnTitles,wColumnList)
			
			SaveName = ExportMultiColumnData(root:SPECTRA:Import:Export2DMatrix, ExportList,",manual",SaveName,EOLChar,gSavePath)
			break
			
		case "EIS":
			
			EOLChar 		= ReturnEOLCharacter(1,0)
			ExportList 		= "Z Real;Z Imag;Frequency(Hz)"
			PrepareColumnsForExport(ExportList,wColumnTitle,wColumnList)
			
			SaveName = ExportMultiColumnData(root:SPECTRA:Import:Export2DMatrix, "","manual",SaveName,EOLChar,gSavePath)
			break
	endswitch
	
	if ((strlen(SaveName) > 0) && (cmpstr("_quit!_",SaveName)!=0))
		Print " *** Saved",NCols,"columns to file: ",SaveName+".txt"
	endif
End

Function PrepareColumnsForExport(ExportTitles,wColumnTitle,wColumnList)
	String ExportTitles
	Wave /T wColumnTitle,wColumnList
	
	String ColTitle
	Variable i, j=0, ColNum, NPnts =0
	Variable TotCols 	= numpnts(wColumnTitle)
	Variable NCols 		= ItemsInList(ExportTitles)
	
	// First calculate the number of points. 
	for (i=0;i<TotCols;i+=1)
		if (WhichListItem(wColumnTitle[i],ExportTitles) > -1)
			WAVE Column 	= $("root:SPECTRA:Import:"+wColumnList[i])
			NPnts 	= max(numpnts(Column),NPnts)
		endif
	endfor
	
	// Now make the output array. 
	Make /O/D/N=(NPnts,NCols) root:SPECTRA:Import:Export2DMatrix /WAVE=Export2DMatrix
	Export2DMatrix 	= NAN
	
	// Now fill the output array
	for (i=0;i<NCols;i+=1)
		ColTitle 	= StringFromList(i,ExportTitles)
		FindValue /TXOP=2/TEXT=ColTitle wColumnTitle
		ColNum 	= V_value
		
		if (ColNum < 0)
			Print " 	*** This column can't be found",ColTitle
		else
			WAVE Column 	= $("root:SPECTRA:Import:"+wColumnList[ColNum])
			NPnts 	= numpnts(Column)
			Export2DMatrix[0,NPnts][i] 	= Column[p]
			j += 1
		endif
	endfor
	
	return j
End

// ***************************************************************************
// **************** 			ADOPTING the columns to the Igor experiment
// ***************************************************************************
Function Adopt2Columns()

	WAVE /T wColumnTitle 		= root:SPECTRA:Import:wColumnTitle
	WAVE /T wColumnList 		= root:SPECTRA:Import:wColumnList
	
	SVAR gMergeAxis			= root:SPECTRA:Import:gMergeAxis
	SVAR gMergeData			= root:SPECTRA:Import:gMergeData
	SVAR gMergeFileName		= root:SPECTRA:Import:gMergeFileName
	SVAR gMergeColumnList		= root:SPECTRA:Import:gMergeColumnList
	NVAR gMergeUserFlag 		= root:SPECTRA:Import:gMergeUserFlag
	
	Variable i, SegmentFlag, NSegments=0
	String cmd, AdoptName, AxisName, DataName, NewAdoptName, CVAdoptName, CVAxisName, CVDataName, CVDataList=""
	String ColFolder = "root:SPECTRA:Import:", CVFolder = "root:SPECTRA:Import:CV:"
	
	AdoptName 	= ReturnMergeName(gMergeData)
	AxisName 	= wColumnList[WhichListItem(gMergeAxis,gMergeColumnList)]
	DataName 	= wColumnList[WhichListItem(gMergeData,gMergeColumnList)]
	
	// Try segmenting CV data. 
	WAVE Axis 	= $("root:SPECTRA:Import:"+AxisName)
	WAVE Data 	= $("root:SPECTRA:Import:"+DataName)
	// NOTE: Here, we should also properly find the acquisition time axis
	NSegments 	= SegmentCVData2(Axis,Data,Axis,DataName,Colfolder,gMergeFileName,0)
	
	if (NSegments > 1)
		SegmentFlag = PromptForUserYesNoInput("Load CV data as separate segments?",1)
		if  (SegmentFlag == -1)
			return 0
		elseif (SegmentFlag == 2)
			NSegments = 1
		endif
	endif
	
	if (NSegments > 1)
	
		NewAdoptName = GetSampleName(AdoptName,"","",0,1,1)
		if (cmpstr("_quit!_",NewAdoptName) == 0)
		
		else
			for (i=1;i<=NSegments;i+=1)
				CVDataName 	= DataName + "_CV"+FrontPadVariable(i,"0",2)+"_data"
				CVAxisName 	= AxisNameFromDataName(CVDataName)
				CVAdoptName 	= NewAdoptName + "_CV"+FrontPadVariable(i,"0",2)
				
				cmd = "AdoptAxisAndDataFromMemory(\""+CVAxisName+"\",\"null\",\""+CVFolder+"\",\""+CVDataName+"\",\"null\",\""+CVFolder+"\",\""+CVAdoptName+"\",\"\",0,0,0)"
				Execute cmd
			endfor
		endif
	else
		cmd = "AdoptAxisAndDataFromMemory(\""+AxisName+"\",\"null\",\""+Colfolder+"\",\""+DataName+"\",\"null\",\""+Colfolder+"\",\""+AdoptName+"\",\"\",1,0,0)"
		Execute cmd
	endif
	
	KillAllWavesInFolder(CVFolder,"*")
End

Function AdoptNColumns()

	WAVE /T wColumnTitle 		= root:SPECTRA:Import:wColumnTitle
	WAVE /T wColumnList 		= root:SPECTRA:Import:wColumnList
	
	SVAR gFileName 			= root:SPECTRA:Import:gMergeFileName
	SVAR gAdoptFormat			= root:SPECTRA:Import:gMergeAdoptFormat
	NVAR gMergeUserFlag 		= root:SPECTRA:Import:gMergeUserFlag
	
	Variable i, NCols = numpnts(wColumnList)
	String cmd, AxisName, DataName, AxisSigName, DataSigName, AdoptName, ColFolder = "root:SPECTRA:Import:"
	
	AxisName 	= wColumnList[0]
	
	strswitch (gAdoptFormat)
		case "2-column":
			for (i=1;i<NCols;i+=1)
				DataName 	= wColumnList[i]
				AdoptName 	= ReturnMergeName(wColumnTitle[i])
//				AdoptName 	= wColumnTitle[i]
				cmd = "AdoptAxisAndDataFromMemory(\""+AxisName+"\",\"null\",\""+Colfolder+"\",\""+DataName+"\",\"null\",\""+Colfolder+"\",\""+AdoptName+"\",\"\",0,0,0)"
				Execute cmd
			endfor
			break
			
		case "save-data":
			
			AdoptName 	= ReturnMergeName(wColumnTitle[i])
			
			WAVE Izero 	= $("root:SPECTRA:Import:"+wColumnList[1])
			WAVE Data1 = $("root:SPECTRA:Import:"+wColumnList[2])
			Make /O/D/N=(numpnts(Data1)) $("root:SPECTRA:Import:Average") /WAVE=Average
			Average = Data1
			
			for (i=3;i<NCols;i+=1)
				WAVE DataN = $("root:SPECTRA:Import:"+wColumnList[i])
				Average += DataN
			endfor
			Average /= (NCols-2)
			
			Average[] /= Izero[p]
			
			cmd = "AdoptAxisAndDataFromMemory(\""+AxisName+"\",\"null\",\""+ColFolder+"\",\""+"Average"+"\",\"null\",\""+ColFolder+"\",\""+AdoptName+"\",\"\","+num2str(gMergeUserFlag)+",0)"
			Execute cmd
			
			break
	endswitch
End


// We might want to base the naming only on the FILENAME or the COLUMN NAME
Function /T ReturnMergeName(ColTitle)
	String ColTitle

	SVAR gFileName			= root:SPECTRA:Import:gMergeFileName
	SVAR gRemoveText		= root:SPECTRA:Import:gMergeRemoveText
	SVAR gReplaceText		= root:SPECTRA:Import:gMergeReplaceText
	
	String AdoptName, NewFileName=gFileName
	Variable i, NRemove, NReplace
	
	// Re-arrange the filename text if appropriate. 
	if ((strlen(gFileName)) && (NRemove > 0))
		for (i=0;i<ItemsInList(gRemoveText);i+=1)
			if (NReplace == NRemove)
				NewFileName 	= ReplaceString(StringFromList(i,gRemoveText),NewFileName,StringFromList(i,gReplaceText),0,1)
			else
				NewFileName 	= ReplaceString(StringFromList(i,gRemoveText),NewFileName,"",0,1)
			endif
		endfor
	endif
	
	if ((strlen(NewFileName) == 0) && (strlen(ColTitle) == 0))
		AdoptName 	= "XXXX"
	elseif (strlen(NewFileName) == 0)
		AdoptName 	= CleanUpName(ColTitle,0)
	elseif (strlen(ColTitle) == 0)
		AdoptName 	= CleanUpName(NewFileName,0)
	else
		AdoptName 	= CleanUpName(NewFileName+"_"+ColTitle,0)
	endif
	
	return AdoptName
End



//Function /T ReturnMergeName(FileNameFlag,DataName)
//	Variable FileNameFlag
//	String DataName
//
//	SVAR gDataName		= root:SPECTRA:Import:gMergeData
//	SVAR gFileName			= root:SPECTRA:Import:gMergeFileName
//	SVAR gRemoveText		= root:SPECTRA:Import:gMergeRemoveText
//	SVAR gReplaceText		= root:SPECTRA:Import:gMergeReplaceText
//	
//	String AdoptName="", NewFileName
//	Variable i, NRemove, NReplace
//	
//	NewFileName=gFileName
//	
//	if (FileNameFlag)
//		for (i=0;i<ItemsInList(gRemoveText);i+=1)
//			NewFileName 	= ReplaceString(StringFromList(i,gRemoveText),NewFileName,StringFromList(i,gReplaceText),0,1)
//		endfor
//		AdoptName = NewFileName+"_"
//	endif
//	
//	AdoptName 	= AdoptName+CleanUpName(gDataName,0)
//	
//	return AdoptName
//End


// ***************************************************************************
// **************** 			CREATE THE INTERACTIVE PANEL FOR PLOTTING
// ***************************************************************************
Function CreateColumnMergePanel()
	
	WAVE /T wColumnTitle 		= root:SPECTRA:Import:wColumnTitle
	WAVE /T wColumnList 		= root:SPECTRA:Import:wColumnList
	WAVE wColumnSel 			= root:SPECTRA:Import:wColumnSel
	
	SVAR gMergeAxis			= root:SPECTRA:Import:gMergeAxis
	SVAR gMergeData			= root:SPECTRA:Import:gMergeData
	SVAR gMergeColumnList		= root:SPECTRA:Import:gMergeColumnList
	SVAR gSavePath				= root:SPECTRA:Import:gMergeSavePath
	SVAR gExportFormat		= root:SPECTRA:Import:gMergeExportFormat
	SVAR gAdoptFormat			= root:SPECTRA:Import:gMergeAdoptFormat
	
	Variable i
	
	DoWindow ColumnMergePanel
	if (V_flag == 1)
		DoWindow /F ColumnMergePanel
		RemoveAllColumnsFromTable("ColumnMergePanel#ColumnTable")
		AddColumnsToTable("ColumnMergePanel#ColumnTable","root:SPECTRA:Import:",wColumnList,wColumnTitle,$"null",$"null",$"null",$"null")
		
		// List of the loaded data files. 
		ListBox ColumnListBox,listWave=root:SPECTRA:Import:wColumnTitle
		ListBox ColumnListBox,selWave=root:SPECTRA:Import:wColumnSel
	
		return 0
	endif
	
	NewPanel /N=ColumnMergePanel/K=1/W=(528,160,1386,494) as "Column Merging Panel"
	CheckWindowPosition("ColumnMergePanel",528,160,1386,494)

	Edit /W=(243,94,794,326)/HOST=# 
	ModifyTable showParts=0xF7
	RenameWindow #, ColumnTable
	SetActiveSubwindow ##
	
	AddColumnsToTable("ColumnMergePanel#ColumnTable","root:SPECTRA:Import:",wColumnList,wColumnTitle,$"null",$"null",$"null",$"null")
	
	SetWindow ColumnMergePanel, hook(PanelCloseHook)=KillMergePanelHook

	SetDrawLayer UserBack
	DrawText 40,328,"Press 'delete' to remove columns"
	
	GroupBox TwoColumnData,pos={599,21},size={247,69},fColor=(39321,1,1),title="Extract two columns"
	GroupBox NColumnData,pos={244,21},size={247,69},fColor=(39321,1,1),title="Extract multiple columns"
	
	// List of the loaded data files. 
	ListBox ColumnListBox,mode= 1,pos={45,98},size={191,211}, proc=ColumnListActionProcs
	ListBox ColumnListBox,listWave=root:SPECTRA:Import:wColumnTitle
	ListBox ColumnListBox,selWave=root:SPECTRA:Import:wColumnSel
	
	// Display the file saving and loading locations
	Button ColumnSavePath,pos={44,6},size={120,20},proc=ColumnListButtonProcs,title="Output Directory"
	TitleBox SaveLocation frame=0,fSize=11,pos={172,8},fColor=(52428,1,41942),title=gSavePath
	
	SetVariable FileName,pos={8,32},size={227,18},title="Name"
	SetVariable FileName,fSize=12,value=root:SPECTRA:Import:gMergeFileName
	SetVariable RemoveText,pos={7,53},size={228,18},title="Remove"
	SetVariable RemoveText,fSize=12,value=root:SPECTRA:Import:gMergeRemoveText
	SetVariable AddText,pos={9,74},size={227,18},title="Replace"
	SetVariable AddText,fSize=12,value=root:SPECTRA:Import:gMergeReplaceText
	
	Button ColumnUpButton, fsize=28, title="↑",pos={24,99},size={17,65}, proc=ColumnListButtonProcs
	Button ColumnDownButton , fsize=28, title="↓",pos={24,170},size={17,65}, proc=ColumnListButtonProcs
	
	// Adopt 2-columns of data. 
	Button AdoptNColumnButton,pos={604,39},size={60,20},proc=ColumnListButtonProcs,title="Adopt"
	
	// Save or Adopt Multiple columns of data. 
	Button ColumnAdoptButton,pos={253,38},size={60,20},proc=ColumnListButtonProcs,title="Adopt"
	Button ColumnSaveButton,pos={253,64},size={60,20},proc=ColumnListButtonProcs,title="Save"
	
	// Type of data formats for EXPORT
	PopupMenu SaveColumnsMenu,fSize=12,pos={317,63},proc=ColumnPopupProcs,title="as",mode=1
	PopupMenu SaveColumnsMenu, value=#"root:SPECTRA:Import:gMergeExportFormatList", popmatch=gExportFormat
	// Type of data formats for EXPORT
	PopupMenu AdoptColumnsMenu,fSize=12,pos={317,38},proc=ColumnPopupProcs,title="as",mode=1
	PopupMenu AdoptColumnsMenu, value=#"root:SPECTRA:Import:gMergeAdoptFormatList", popmatch=gAdoptFormat
	
	DefaultAxisAndDataColumns()
	
	// Only one of the columns can be the axis. 
	PopupMenu MergeAxisMenu,fSize=12,pos={671,38},proc=ColumnPopupProcs,title="Axis",mode=1
	PopupMenu MergeAxisMenu, value=#"root:SPECTRA:Import:gMergeColumnList"
	PopupMenu MergeAxisMenu, popmatch=gMergeAxis
	
	// Only one of the columns can be the axis. 
	PopupMenu MergeDataMenu,fSize=12,pos={668,65},proc=ColumnPopupProcs,title="Data",mode=1
	PopupMenu MergeDataMenu, value=#"root:SPECTRA:Import:gMergeColumnList"
	PopupMenu MergeDataMenu, popmatch=gMergeData
End

Function DefaultAxisAndDataColumns()

	SVAR gMergeAxis			= root:SPECTRA:Import:gMergeAxis
	SVAR gMergeData			= root:SPECTRA:Import:gMergeData
	SVAR gMergeColumnList		= root:SPECTRA:Import:gMergeColumnList
	
	NVAR gMergeAxisCol 		= root:SPECTRA:Import:gMergeAxisCol
	NVAR gMergeDataCol 		= root:SPECTRA:Import:gMergeDataCol
	
	if ((strlen(gMergeAxis) == 0) || (WhichListItem(gMergeAxis,gMergeColumnList) == -1))
		gMergeAxis 	= StringFromList(0,gMergeColumnList)
	endif

	if ((strlen(gMergeData) == 0) || (WhichListItem(gMergeData,gMergeColumnList) == -1))
		gMergeData 	= StringFromList(1,gMergeColumnList)
	endif
	
	PopupMenu /Z MergeAxisMenu, win=ColumnMergePanel, popmatch=gMergeAxis
	ControlUpdate /W=ColumnMergePanel MergeAxisMenu
	
	PopupMenu /Z MergeDataMenu, win=ColumnMergePanel, popmatch=gMergeData
	ControlUpdate /W=ColumnMergePanel MergeDataMenu
End

Function KillMergePanelHook(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
		
	Variable hookResult 	= 0
	Variable keyCode 		= H_Struct.keyCode
	Variable eventCode		= H_Struct.eventCode
	Variable Modifier 		= H_Struct.eventMod
	Variable CmdBit 		= 3
	
	if (eventCode == 2) 	// Window kill
		RemoveAllColumnsFromTable("ColumnMergePanel#ColumnTable")
		KillAllWavesInFolder("root:SPECTRA:Import","column*")
	endif
	
	return hookResult
End
