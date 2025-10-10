#pragma rtGlobals=1		// Use modern global access method.




// ***************************************************************************
// **************** 				Save Loaded Data	(will not work on ROOT: data)
// ***************************************************************************
Function SaveSelectedData(DataList, DataSel, DataGroup,SaveAllFlag)
	Wave DataSel, DataGroup
	Wave /T DataList
	Variable SaveAllFlag
	
	Variable i, j=1, n, ExportErrors, DataOnly=0, ExportFit=0, ExportTruncate, ExportTitles, ExportAxisMin, ExportAxisMax, EOLFlag, NANFlag, UserFlag= !SaveAllFlag, NSel, NCols, NPnts=0, Start
	String AxisName, AxisAndFolderName, DataName, SaveName,DataAndFolderName, DataSigFolderName, AxisSigFolderName
	String SaveAxisName, SaveDataName, SaveAxisSigName, SaveDataSigName, SaveFitName, SaveResidName, ExportCutText, ExportReplaceText
	String ExportList="",ExportNaming, ExportFormat, ExportFolder, EOLChar, ColumnList="", NColSaveName
	
	Variable Bragg=1, BraggStep=1
	String H, K, rodName, rodHKL
	
	String FolderStem 		= "root:SPECTRA:Data:Load"
	
	String OldDf =GetDataFolder(1)
	SetDataFolder root:SPECTRA:Export
		String /G gExportFormats, gExportNaming, gExportFormat, gExportFolder, gExportCutText, gExportReplaceText
		Variable /G gNANFlag, gEOLFlag, gExportErrors, gExportAxisMin, gExportAxisMax, gExportTruncate, gExportTitles
		
		// --------------------------------------------- User input ----------------------------------------
			ExportNaming 		= gExportNaming
			ExportFolder 		= gExportFolder
			ExportErrors			= gExportErrors
			ExportFormat 		= gExportFormat
			EOLFlag 				= gEOLFlag+1
			NANFlag 				= gNANFlag
			ExportCutText 		= gExportCutText
			ExportReplaceText 	= gExportReplaceText
			ExportTruncate		= gExportTruncate
			
			Prompt ExportNaming,"File naming", popup, "automatic;manual;"
			Prompt ExportFolder,"Export folder", popup, "home;current export location;new export location;"
			Prompt ExportFormat, "Export format", popup, gExportFormats
			Prompt ExportErrors, "Save errors if present?", popup, "yes;no;"	
			Prompt ExportTitles, "Column headers", popup, "yes;no;"
			Prompt NANFlag,"NAN handling",popup,"ignore;strip from data;replace with zero;"
			Prompt EOLFlag, "End-of-line character", popup, "automatic;Macintosh;Windows;Linux;"
			Prompt ExportTruncate, "Truncate data on export?", popup, "no;yes;"
			DoPrompt "Save data parameters", ExportNaming, ExportFolder, ExportFormat, ExportErrors,  NANFlag, EOLFlag, ExportTruncate, ExportTitles
			if (V_Flag)
				SetDataFolder root:
				return 1
			endif	
		
			gExportNaming 		= ExportNaming
			gExportFolder 		= ExportFolder
			gExportFormat 		= ExportFormat
			gExportErrors 		= ExportErrors
			gNANFlag 			= NANFlag
			gEOLFlag 			= EOLFlag-1
			gExportCutText 		= ExportCutText
			gExportReplaceText 	= ExportReplaceText
			gExportTruncate 	= ExportTruncate
			gExportTitles 		= ExportTitles
			
			if (ExportTruncate == 2)
				ExportAxisMin 		= gExportAxisMin
				ExportAxisMax 		= gExportAxisMax
				Prompt ExportAxisMin, "Minimum axis value"
				Prompt ExportAxisMax, "Maximum axis value"
				DoPrompt "Truncate data range on export", ExportAxisMin, ExportAxisMax
				if (V_Flag)
					SetDataFolder root:
					return 1
				endif
				gExportAxisMin 	= ExportAxisMin
				gExportAxisMax 	= ExportAxisMax
			endif
		// --------------------------------------------- User input ----------------------------------------
		
		NSel 		= CountSelected(DataSel)
		EOLChar 	= ReturnEOLCharacter(gEOLFlag,0)
		
		if (SetExportPath(ExportFolder) == 0)
			return 1
		endif
		if (cmpstr(ExportFormat,"Profex Input") == 0)
			//
		endif
		if (cmpstr(ExportFormat,"ROD input") == 0)
			ExportNaming 	= "manual"
			ExportErrors 	= 1
			ExportFit = 0
			NANFlag 		= 2
		endif
		if (cmpstr(ExportFormat,"data only") == 0)
			DataOnly 		= 1
			ExportErrors 	= 0
		endif
		if (cmpstr(ExportFormat,"fit results") == 0)
			ExportFit = 1
		endif
		if (cmpstr(ExportFormat,"axis - n column") == 0)
			MultiColumnExportPreferences(1,0,-1,-1,"","","","")
		endif		
		
		for (i=0;i<numpnts(DataSel);i+=1)
			if (((DataSel[i]&2^0) != 0) || ((DataSel[i]&2^3) != 0) || (SaveAllFlag))
			
				DataName				= DataList[i]
				DataAndFolderName	= FolderStem + num2str(DataGroup[i]) + ":" + DataName
				AxisName 				= AxisNameFromDataName(DataName)
				AxisAndFolderName	= AxisNameFromDataName(DataAndFolderName)
				
				WAVE Data 			= $DataAndFolderName
				WAVE AxisErrors		= $(AxisAndFolderName + "_sig")
				WAVE DataErrors 	= $(DataAndFolderName + "_sig")
				WAVE Fit 				= $(ReplaceString("_data",DataAndFolderName,"") + "_fit")
				WAVE Residuals 		= $(ReplaceString("_data",DataAndFolderName,"") + "_res")
				
				// Determine the name for saving the data. 
				SaveName 				= StripSuffixBySuffix(DataName,"_data")
				SaveName 				= ReplaceString(ExportCutText,SaveName,ExportReplaceText,0,1)
				
				SaveAxisName			= SaveName + "_axis"
				SaveDataName			= SaveName + "_data"
				SaveAxisSigName 	= SaveAxisName + "_sig"
				SaveDataSigName 	= SaveDataName + "_sig"
				SaveFitName 			= SaveName + "_fit"
				SaveResidName 		= SaveName + "_res"
				
				// Duplicate the selected axis and data into the current folder
				Duplicate /O/D $(AxisAndFolderName), $(SaveAxisName) /WAVE=ExportAxis
				Duplicate /O/D $(DataAndFolderName), $(SaveDataName) /WAVE=ExportData
				
				// Ensure we have error waves if these are requested. 
				if (ExportErrors == 1)
					if (WaveExists(DataErrors) == 1)		// The data errors exist ... 
						if (WaveExists(AxisErrors)==0)	// ... so create axis errors if needed. 
							Duplicate /O/D DataErrors, $(AxisAndFolderName + "_sig") /WAVE=AxisErrors
							AxisErrors = 0
						else
							WaveStats /Q AxisErrors
							if (numtype(V_avg) == 2)
								AxisErrors = 0
							endif
						endif
						
						Duplicate /O/D AxisErrors, $(SaveName + "_axis_sig") /WAVE=ExportAxisErrors
						Duplicate /O/D DataErrors, $(SaveName + "_data_sig") /WAVE=ExportDataErrors
						
						ExportList 	= SaveAxisName+";"+SaveAxisSigName+";"+SaveDataName+";"+SaveDataSigName+";"
					else
						ExportList 	=  SaveAxisName+";"+SaveDataName+";"
					endif
				else
					if (DataOnly)
						ExportList 	=  SaveDataName+";"
					else
						ExportList 	=  SaveAxisName+";"+SaveDataName+";"
					endif
				endif
				
				// Look for fit result waves if these are requested. 
				if (ExportFit == 1)
					if (WaveExists(Fit))
						if (WaveExists(Residuals)==0)	// ... so create axis errors if needed. 
							Duplicate /O/D Fit, $(DataName + "_res") /WAVE=Residuals
							Residuals = Data - Fit
						endif
						
						Duplicate /O/D Fit, $SaveFitName /WAVE=SaveFit
						Duplicate /O/D Residuals, $SaveResidName /Wave=SaveResid
						
						ReplaceNANsWithValue(SaveFit,0)
						ReplaceNANsWithValue(SaveResid,0)
						
						ExportList 	= ExportList + SaveFitName+";"+SaveResidName+";"
					else
						ExportFit = 0
					endif
				endif
				
				// Look for fit component waves
				if (ExportFit == 1)
					Variable NCmpts
					String FolderName, SampleName, AcqTName, ListAssocWaves, CmptName, CmptSuffix, SaveCmptName
					
					FolderName		= FolderStem + num2str(DataGroup[i])
					SampleName 	= SampleNameFromDataName(DataName)
					AcqTName 		= SampleName+"_time"
					ListAssocWaves 	= FolderWaveList(FolderName,SampleName + "_*",";","",-1,0)
					
					// Remove axis, data, time and error waves. Then remove fit and residuals. 
					ListAssocWaves = ExclusiveWaveList(ExclusiveWaveList(ExclusiveWaveList(ExclusiveWaveList(ListAssocWaves,DataName,";"),AxisName,";"),AcqTName,";"),"_sig",";")
					ListAssocWaves = ExclusiveWaveList(ExclusiveWaveList(ListAssocWaves,"_fit",";"),"_res",";")
					NCmpts 		= ItemsInList(ListAssocWaves)
					
					for (n=0;n<NCmpts;n+=1)
						CmptName 	= StringFromList(n,ListAssocWaves)
						CmptSuffix 	= ReturnLastSuffix(CmptName,"_")
						SaveCmptName 	= SaveName + "_" + CmptSuffix
						WAVE Cmpt 	= $(FolderName+":"+CmptName)
						Duplicate /O/D Cmpt, $SaveCmptName /WAVE=SaveCmpt
						ReplaceNANsWithValue(SaveResid,0)
						ExportList 	= ExportList + SaveCmptName+";"
					endfor
				endif
				
				
				if (ExportTruncate == 2)
					WaveList_Truncate(ExportList,ExportAxisMin,ExportAxisMax)
				endif
				
				if (NANFlag == 2)
					WaveList_StripOrReplaceNaNs(ExportList,0,0)
				elseif (NANFlag == 3)
					WaveList_StripOrReplaceNaNs(ExportList,1,0)
				endif
				
				
				// This basically appends columns rightwards ... 
				if (cmpstr(ExportFormat,"axis - n column") == 0)
					if (j==1)		// Very crude: just look at the first wave in the list for axis and number of points. 
						NColSaveName 	= SaveName
						NCols 			= sum(DataSel)+1
						NPnts 			= numpnts(ExportData)
						Make /O/D/N=(NPnts,NCols) Export2DMatrix=NAN
						
						ColumnList 	= "axis;"
						ColumnList 	= AddListItem(SaveName,ColumnList,";",Inf)
						Export2DMatrix[][0] 	= ExportAxis[p]
						Export2DMatrix[][1] 	= ExportData[p]
					else
						ColumnList 	= AddListItem(SaveName,ColumnList,";",Inf)
						Export2DMatrix[][j] 	= ExportData[p]
					endif

					if (j == NCols-1)

						
						if (ExportTitles==2)
							ColumnList = ""
						endif 
						
						ExportMultiColumnData(Export2DMatrix,ColumnList,ExportNaming,NColSaveName,EOLChar,"")
						KillWaves /Z Export2DMatrix
					endif
					
					j+=1
				
				// ... while this basically appends axis and columns downwards. 
				// It is not easily put in a separate routine as it adds all selected files to the same array. 
				// 2022-08 Modified to add alpha and beta angles
				elseif  ((cmpstr(ExportFormat,"ROD input") == 0))
					
//					NCols 			= 7
					NCols 			= 9
					Start 				= NPnts
					NPnts 			+= numpnts(ExportData)
					
					if (j==1)
						Make /O/D/N=(NPnts,NCols) Export2DMatrix
					else
						ReDimension /N=(NPnts,NCols) Export2DMatrix
					endif
					
					// Get additional input for this rod. 
					rodName 	= ReturnTextBeforeNthChar(DataName,"_",1)+"_"
					sscanf DataName, rodName + "%s", rodHKL
					H 			= rodHKL[0,0]
					K 			= rodHKL[1,1]
					
					Prompt H, "H"
					Prompt K, "K"
					Prompt Bragg, "First Bragg peak"
					Prompt BraggStep, "Bragg L-step"
					DoPrompt "Rod info for "+DataName, H, K, Bragg, BraggStep
					if (V_Flag)
						SetDataFolder root:
						return 1
					endif
					
//					Variable CTRScale = 100, ErrorScale = 0.5
					Variable CTRScale = 1, ErrorScale = 0.05 // (i.e., errors are 5% of data values
					
					Export2DMatrix[Start,NPnts-1][0] 	= str2num(H)
					Export2DMatrix[Start,NPnts-1][1] 	= str2num(K)
					Export2DMatrix[Start,NPnts-1][2] 	= ExportAxis[p-Start]
					Export2DMatrix[Start,NPnts-1][3] 	= CTRScale*ExportData[p-Start]
					if (WaveExists(ExportDataErrors))
						Export2DMatrix[Start,NPnts-1][4] 	= CTRScale*ErrorScale*ExportDataErrors[p-Start]
					else
						Export2DMatrix[Start,NPnts-1][4] 	= CTRScale*ErrorScale*ExportData[p-Start]
					endif
					Export2DMatrix[Start,NPnts-1][5] 	= Bragg
					Export2DMatrix[Start,NPnts-1][6] 	= BraggStep
					
					WAVE AlphaValues  	= $(ReplaceString("_data",DataAndFolderName,"") + "_alp")
					WAVE BetaValues  	= $(ReplaceString("_data",DataAndFolderName,"") + "_bet")
					
					if (WaveExists(AlphaValues) && WaveExists(BetaValues))
						Export2DMatrix[Start,NPnts-1][7] 	= AlphaValues[p-Start]
						Export2DMatrix[Start,NPnts-1][8] 	= BetaValues[p-Start]
					else
						Export2DMatrix[Start,NPnts-1][7] 	= -1
						Export2DMatrix[Start,NPnts-1][8] 	= -1
					endif

					if (j == NSel)
//						MultiColumnExportPreferences(0,0,0,1,"%u;%u;%1.4f;%1.4f;%1.4f;%u;%u;","  ","  ","wgt")
//						MultiColumnExportPreferences(0,0,0,1,"%u;%u;%1.4f;%1.4f;%1.4f;%u;%u;%1.4f;%1.4f;","  ","  ","txt")
						MultiColumnExportPreferences(0,0,0,1,"%u;%u;%1.4f;%1.4f;%1.4f;%u;%u;%1.4f;%1.4f;","","\t","txt")
						ExportMultiColumnData(Export2DMatrix,ColumnList,ExportNaming,SaveName,EOLChar,"")
						KillWaves /Z Export2DMatrix
						
						PathInfo ExportPath
						Print " 	*** Saved rod scans to " + S_path
					endif
					
					j+=1
				
				elseif (cmpstr(ExportFormat,"Profex Input") == 0)
					ExportForProfex(SaveName,ExportAxis,ExportData)
				else
					// Saving the data as a two- or four-column file
					WavesList_ExportData(ExportList,ExportNaming,SaveName,ExportFormat,DataOnly,EOLChar)
				endif
				
				KillWaves /Z ExportAxis, ExportAxisErrors, ExportData, ExportDataErrors
			endif
		endfor
		
		if (SaveAllFlag == 1)
	 		Print " *** Saved all the loaded data as tab-delimited text files. "
		endif
	
	SetDataFolder root:
End

// ***************************************************************************
// **************** 			Exporting for Profex
// ***************************************************************************
Function ExportForProfex(SaveName,ExportAxis,ExportData)
	String SaveName
	Wave ExportAxis,ExportData

	Variable refNum, j, NPts
	String LineStr, ValStr, EOLChar 	= "\n"
	
	Open /Z/T="TEXT" /P=ExportPath refNum as SaveName+".csv"
	if (V_flag != 0)
		return 0
	endif
	
	NPts 		= DimSize(ExportAxis,0)
		
	for (j=0;j<NPts;j+=1)
		LineStr = ""
		
		sprintf ValStr, "%0.5f", ExportAxis[j]
		LineStr = LineStr + ValStr+","
		
		sprintf ValStr, "%0.5f", ExportData[j]
		LineStr = LineStr + ValStr
		
		fprintf refNum, LineStr + EOLChar
	endfor

	Close refNum
	
	return 1
End


Function CountSelected(DataSel)
	Wave DataSel
	
	Variable i, NSel=0
	
	for (i=0;i<numpnts(DataSel);i+=1)
		if (DataSel[i] != 0)
			NSel += 1
		endif
	endfor
	
	return NSel
End

Function SetExportPath(ExportFolder)
	String ExportFolder
	
	Variable NewPathFlag=1
	
	if (cmpstr("home",ExportFolder) == 0)
		PathInfo home
		if (V_flag == 1)
			NewPath /O/Q ExportPath S_path
			NewPathFlag = 0
		endif
	elseif (cmpstr("current export location",ExportFolder) == 0)
		PathInfo ExportPath
		if (V_flag == 1)
			NewPathFlag = 0
		endif
	endif
	
	if (NewPathFlag == 1)
		NewPath /C/M="Location to save the data"/O/Q ExportPath
		if (V_flag != 0)
			return 0
		endif
		PathInfo ExportPath; Print " 	 %%% New Export Location: ",S_path
	endif
	
	return 1
End

// ***************************************************************************
// **************** 			The default export format
// ***************************************************************************

Function WavesList_ExportData(ExportList,ExportNaming,SaveName,ExportFormat,DataOnly,EOLChar)
	String ExportList,ExportNaming,SaveName,ExportFormat,EOLChar
	Variable DataOnly
	
	PathInfo ExportPath 	// This should have already been defined. 
	if (V_flag ==0)
		if (SetExportPath("") == 0)
			return 1
		endif
	endif
	
	String TableName, suffix="txt"
	Variable success
	
	if (cmpstr(ExportNaming,"manual") == 0)
		SaveName 	= PromptForUserStrInput(SaveName,"Filename","Enter the name for saving")
	endif
	

	strswitch (ExportFormat)
		case "WT input":
			success 	= ExportWTInput(ExportList,EOLChar,SaveName)
			break
		default:
			Edit /HIDE=1/K=1 $(StringFromList(0,ExportList))
			TableName = S_name
			ModifyTable format[1]=3, digits[1]=8
			if (DataOnly)
				Save /F/B/O/J /M=EOLChar/P=ExportPath ExportList as SaveName+"."+suffix
			else
				Save /F/B/O/W/J /M=EOLChar/P=ExportPath ExportList as SaveName+"."+suffix
			endif
			DoWindow /K TableName
			break
	endswitch
	
	PathInfo ExportPath
	Print " *** Saved",SaveName,"to", S_path
End

// ***************************************************************************
// **************** 			Exporting in the WT format
// ***************************************************************************
Function ExportWTInput(ExportList,EOLChar,SaveName)
	String ExportList, EOLChar, SaveName
	
	String ValStr, LineStr=""
	Variable j, n, refNum, NPts, NWaves
	
	Open /Z/T="TEXT" /P=ExportPath refNum as SaveName+".txt"
	if (V_flag != 0)
		return 0
	endif
	
	WAVE Axis = $StringFromList(0,ExportList)
	NPts 		= DimSize(Axis,0)
	NWaves 	= ItemsInList(ExportList)
	
	fprintf refNum, LineStr + EOLChar
		
	for (j=0;j<NPts;j+=1)
		LineStr = ""
		for (n=0;n<NWaves;n+=1)
			WAVE Data 	= $(StringFromList(n,ExportList))
			sprintf ValStr, "%0.5f", Data[j]
			LineStr = LineStr + ValStr+"\t"
		endfor
		fprintf refNum, LineStr + EOLChar
	endfor

	Close refNum
	
	return 1
End


// ***************************************************************************
// **************** 			Exporting axis - n-column 
// ***************************************************************************

Function /T ExportMultiColumnData(Export2DMatrix,ColumnList,ExportNaming,SaveName,EOLChar,Path2Folder)
	Wave Export2DMatrix
	String ColumnList, ExportNaming, SaveName, EOLChar, Path2Folder
	
	NVAR gMCNPntsFlag = root:SPECTRA:Export:gMCNPntsFlag
	NVAR gMCSkipPnts 	= root:SPECTRA:Export:gMCSkipPnts
	SVAR gMCFmtStr 	= root:SPECTRA:Export:gMCFmtStr
	SVAR gMCMargin 	= root:SPECTRA:Export:gMCMargin
	SVAR gMCDelimiter 	= root:SPECTRA:Export:gMCDelimiter
	SVAR gMCSuffix 	= root:SPECTRA:Export:gMCSuffix
	
	String ValStr, FmtStr, ExportLine
	Variable i, j, refNum, NPts=DimSize(Export2DMatrix,0), NCols=DimSize(Export2DMatrix,1)
	
	Variable NFmtStr=ItemsInList(gMCFmtStr), FmtStrFlag
	if (NFmtStr == NCols)
		FmtStrFlag = 1
	elseif (NFmtStr == 1)
		FmtStrFlag = 0
	else
		Print " *** Wrong number of formal strings" 
		return ""
	endif
	
	if (cmpstr(ExportNaming,"manual") == 0)
		SaveName 	= PromptForUserStrInput(SaveName,"Filename","Enter the name for saving")
		if (cmpstr(SaveName,"_quit!_") == 0)
			return ""
		endif
	endif
	
	if (strlen(Path2Folder) > 0)
		NewPath /O/Q ExportPath, Path2Folder
	endif
	
	PathInfo ExportPath
	if (strlen(S_path) == 0)
		NewPath /O/Q/M="Please select a folder" ExportPath
		if (V_flag != 0)
			return ""
		endif
	endif
	
	Open /Z/T="TEXT" /P=ExportPath refNum as SaveName+"."+gMCSuffix
	if (strlen(S_fileName) == 0)
		Print " A problem creating the file for export. Is the name correct?", SaveName+"."+gMCSuffix
		return ""
	endif
	
	if (gMCNPntsFlag == 1)
		fprintf refNum, "%d"+EOLChar, NPts/gMCSkipPnts
	endif
	
	// Write the column titles if provided
	if (ItemsInList(ColumnList)==NCols)
		ExportLine 	= StringFromList(0,ColumnList)
		for (j=1;j<NCols;j+=1)
			sprintf ValStr, gMCDelimiter+"%s", StringFromList(j,ColumnList)
			ExportLine += ValStr
		endfor
		
//		print ExportLine
		fprintf refNum, gMCMargin+"%s"+EOLChar, ExportLine
	endif
	
	for (i=0;i<NPts;i+=1)
		if (mod(i,gMCSkipPnts) == 0)
		
			FmtStr 	= StringFromList(0,gMCFmtStr)
			sprintf ExportLine, FmtStr, Export2DMatrix[i][0]
				
			for (j=1;j<NCols;j+=1)
				if (FmtStrFlag)
					FmtStr 	= StringFromList(j,gMCFmtStr)
				endif
				sprintf ValStr, gMCDelimiter+FmtStr, Export2DMatrix[i][j]
				ExportLine += ValStr
			endfor
			
//			print ExportLine
			fprintf refNum, gMCMargin+"%s"+EOLChar, ExportLine
		endif
	endfor

	Close refNum
	
	return SaveName
End

Function MultiColumnExportPreferences(UserFlag,DefaultFlag,MCNPntsFlag,MCSkipPnts,MCFmtStr,MCMargin,MCDelimiter,MCSuffix)
	Variable UserFlag,DefaultFlag, MCNPntsFlag,MCSkipPnts
	String MCFmtStr,MCMargin,MCDelimiter,MCSuffix
	
	if (DefaultFlag)
		MCNPntsFlag 	= 1
		MCSkipPnts 	= 4
		MCFmtStr 		= "%1.4#E"
		MCMargin 		= "  "
		MCDelimiter 	= "      "
		MCSuffix 		= "txt"
	endif
	
	Variable /G root:SPECTRA:Export:gMCNPntsFlag 	= MCNPntsFlag
	Variable /G root:SPECTRA:Export:gMCSkipPnts 	= MCSkipPnts
	String /G root:SPECTRA:Export:gMCFmtStr 		= MCFmtStr
	String /G root:SPECTRA:Export:gMCMargin 		= MCMargin
	String /G root:SPECTRA:Export:gMCDelimiter 	= MCDelimiter
	String /G root:SPECTRA:Export:gMCSuffix 		= MCSuffix
	
//	MakeVariableIfNeeded("root:SPECTRA:Export:gMCNPntsFlag",1)
//	MakeVariableIfNeeded("root:SPECTRA:Export:gMCSkipPnts",4)
//	MakeStringIfNeeded("root:SPECTRA:Export:gMCFmtStr","%1.4#E")
//	MakeStringIfNeeded("root:SPECTRA:Export:gMCMargin","  ")
//	MakeStringIfNeeded("root:SPECTRA:Export:gMCDelimiter","      ")
//	MakeStringIfNeeded("root:SPECTRA:Export:gMCSuffix","txt")
	
	NVAR gMCNPntsFlag 	= root:SPECTRA:Export:gMCNPntsFlag
	NVAR gMCSkipPnts 		= root:SPECTRA:Export:gMCSkipPnts
	SVAR gMCFmtStr 		= root:SPECTRA:Export:gMCFmtStr
	SVAR gMCMargin 		= root:SPECTRA:Export:gMCMargin
	SVAR gMCDelimiter 		= root:SPECTRA:Export:gMCDelimiter
	SVAR gMCSuffix 		= root:SPECTRA:Export:gMCSuffix
	
	if (UserFlag)
		String FmtStr = gMCFmtStr
		Prompt FmtStr, "Format string"
		Variable SkipPnts = gMCSkipPnts
		Prompt SkipPnts, "Output nth points", popup, "1;2;3;4;5;6;7;8;"
		Variable NPntsFlag = gMCNPntsFlag
		Prompt NPntsFlag, "Output points in file?", popup, "yes;no;"
		String Margin = gMCMargin
		Prompt Margin, "Left margin"
		String Delimiter = gMCDelimiter
		Prompt Delimiter, "Delimiter"
		String Suffix = gMCSuffix
		Prompt Suffix, "Suffix"
		DoPrompt "Enter multi-column export parameters", FmtStr, SkipPnts, NPntsFlag, Margin, Delimiter, Suffix
		if (V_flag)
			return 0
		endif
		
		gMCNPntsFlag 	= NPntsFlag
		gMCFmtStr 		= FmtStr
		gMCSkipPnts 		= SkipPnts
		gMCMargin 		= Margin
		gMCDelimiter 	= Delimiter
		gMCSuffix 		= ReplaceString(".",Suffix,"")
	endif
	
	return 1
End

// ***************************************************************************
// **************** 			Exporting in the FLAC format
// ***************************************************************************
Function ExportSAXSDataForFLAC(Axis,Data,SaveName)
	Wave Axis,Data
	String SaveName
	
	Variable j, refNum, NPts
	
	Open /Z/T="TEXT" /P=ExportPath refNum as SaveName+".ex1"
	if (V_flag != 0)
		return 0
	endif
	
	NPts = numpnts(Data)
	for (j=0;j<NPts;j+=1)
		fprintf refNum, "%  0.8#E       %0.8#E\n", Axis[j], Data[j]
	endfor

	Close refNum
	
	return 1
End



Function ExportAxisDataAndErrors(Axis,Data,AxisErrors,DataErrors,SaveName,EOLChar)
	Wave Axis,Data,AxisErrors,DataErrors
	String SaveName, EOLChar
	
	String msg = " *** Saved "+NameOfWave(Data)
	Variable SaveErrorsFlag=1, PathExists
	
	if (!WaveExists(AxisErrors) || !WaveExists(DataErrors))
		SaveErrorsFlag = 0
	endif
	
	PathInfo ExportPath
	if (V_flag ==0)
		if (SetExportPath("") == 0)
			return 1
		endif
	endif
	
	if (SaveErrorsFlag == 0)
		Save /O/W/J /M=EOLChar/P=ExportPath Axis, Data as SaveName+".txt"
 		msg += " without errors."
	else
		Save /O/W/J /M=EOLChar /P=ExportPath Axis, AxisErrors, Data, DataErrors as SaveName+".txt"
 		msg += " including errors."
	endif	
	
	PathInfo ExportPath
	Print msg + "to " + S_path
	
	return 1
End

//Function SaveSAXSDataForFLAC()
//	
//	WAVE/T DataList	= root:SPECTRA:wDataList
//	WAVE DataSel		= root:SPECTRA:wDataSel
//	WAVE DataGroup	= root:SPECTRA:wDataGroup
//	
//	String FolderStem = "root:SPECTRA:Data:Load"
//	String SaveName, DataName, DataAndFolderName, AxisName, AxisAndFolderName
//	Variable i, j, refNum, ValuePad, NPts
//	
//	NewPath /O/Q/M="Location to save FLAC file(s)" FLACPath
//	if (V_flag != 0)
//		return 0
//	endif
//	
//	for (i=0;i<numpnts(DataSel);i+=1)
//		if (DataSel[i] == 1)
//			DataName				= DataList[i]
//			DataAndFolderName	= FolderStem + num2str(DataGroup[i]) + ":" + DataName
//			AxisName 				= AxisNameFromDataName(DataName)
//			AxisAndFolderName	= AxisNameFromDataName(DataAndFolderName)
//			
//			WAVE Data 	= $DataAndFolderName
//			WAVE Axis 	= $AxisAndFolderName
//			
//			SaveName 	= PromptForUserStrInput(DataName,"Filename","Enter the name for saving")
//			
//			Open /T="TEXT" /P=FLACPath refNum as SaveName+".ex1"
//			if (V_flag != 0)
//				return 0
//			endif
//			
//			NPts = numpnts(Data)
//			for (j=0;j<NPts;j+=1)
//				fprintf refNum, "%  0.8#E       %0.8#E\n", Axis[j], Data[j]
//			endfor
//
//			Close refNum
//		endif
//	endfor
//End