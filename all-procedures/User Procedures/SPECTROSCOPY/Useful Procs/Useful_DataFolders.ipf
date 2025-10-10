#pragma rtGlobals=1		// Use modern global access method.
// ********************************************************************
// ********			Transfer these general procedures somewhere
// ******************************************************************** 

Function /S ChooseAFolder(MainFolder,DefaultFolder,Msg1,Msg2,NewFlag)
	String MainFolder,DefaultFolder,Msg1,Msg2
	Variable NewFlag

	String FolderList
	
	if (NewFlag)
		FolderList 	= "new;"+ListOfObjectsInFolder(4,MainFolder,"", "")
	else
		FolderList 	= ListOfObjectsInFolder(4,MainFolder,"", "")
	endif
	
	// Check that the default folder choice actually appears in the folder list, or set to 'new'
	if (WhichListItem(DefaultFolder,FolderList) == -1)
		DefaultFolder 	= StringFromList(0,FolderList)
	endif
	
	if (ItemsInList(FolderList) > 0)
		String Folder = DefaultFolder
		Prompt Folder, Msg1, popup, FolderList
		DoPrompt Msg2, Folder
		if (V_flag)
			return ""
		endif
		
		return Folder
	else
		return ""
	endif
End

// 	Choice = 1 (waves), 2 (numeric variables), 3 (string variables), 4 (data folders)
// 	exactness = 2 means consider exact matched to the include/exclude items
//	 	exactness = 1 means consider partial matches to everything on the list 
//	 	exactness = 0 means consider partial matches to anything on the list 

Function ExactnessTest(objName,textList,exactness)
	String objName,textList
	Variable exactness
	
	Variable j, nItems, SearchFlag
	String Item
	
	if (exactness == 2)			// The full object name must be on the Include list
		if ( WhichListItem(objName,textList) >  -1)
			// The object name exactly matches a text item. Passes exactness = 2
			return 1
		else
			// Fails exactness = 2
			return 0
		endif
		
	else 
		nItems 	= ItemsInList(textList)
		for (j=0;j<nItems;j+=1)
			Item 			= StringFromList(j,textList)
			SearchFlag 	= StrSearch(objName,Item,0)
			
			if ( (SearchFlag == -1) && (exactness == 1))
				// The object name does not contain this text item. Fails exactness = 1
				return 0
			endif
			
			if ( (SearchFlag > -1) && (exactness == 0))
				// The object name contains at least one text item within it. Passes exactness = 0
				return 1
			endif 
		endfor
		
	endif
	
	if (exactness == 1)
		return 1		// No failures, so passes test. 
	elseif (exactness == 0)
		return 0		// No successes, so fails test
	endif

End

Function /S ListOfObjectsInFolderDF(choice,FolderDF,IncludeList,ExcludeList,exactness)
	Variable choice, exactness
	DFRef FolderDF
	String IncludeList, ExcludeList
	
	String objName, objList=""
	Variable nObjects, i, nInclude, nExclude, IncludeFlag=1, ExcludeFlag=0
	
	nObjects 	= CountObjectsDFR(FolderDF,choice)
	nInclude 	= ItemsInList(IncludeList)
	nExclude 	= ItemsInList(ExcludeList)
	
	for (i=0;i<nObjects;i+=1)
		objName 	= GetIndexedObjNameDFR(FolderDF, choice, i)

		if (nInclude > 0)
			IncludeFlag 	= ExactnessTest(objName,IncludeList,exactness)
		endif
		if (nExclude > 0)
			ExcludeFlag 	= ExactnessTest(objName,ExcludeList,exactness)
		endif
		
		if ( IncludeFlag==1 && ExcludeFlag==0)
			objList +=  objName + ";"
		endif
		
	endfor
	
	return objList
End


// 	Choice = 1 (waves), 2 (numeric variables), 3 (string variables), 4 (data folders)
Function /S ListOfObjectsInFolder(choice,MainFolder,IncludeStr, ExcludeList)
	Variable choice
	String MainFolder,IncludeStr, ExcludeList
	
	String objName, objList=""
	Variable index=0
	
	DFREF 	saveDfr		= GetDataFolderDFR()
	
	if (!DataFolderExists(MainFolder))
		return ""
	endif
	
	SetDataFolder $MainFolder
	DFREF 	currDfr 	= GetDataFolderDFR()
	
		do
			objName 	= GetIndexedObjNameDFR(currDfr, choice, index)
			if (strlen(objName) == 0)
				break
			endif
			
			if (ItemsInList(ExcludeList) > 0)
				Variable nnn = WhichListItem(objName,ExcludeList)
				if ( WhichListItem(objName,ExcludeList) >  -1)
				else
					objList +=  objName + ";"
				endif
			else
				objList +=  objName + ";"
			endif
			
			// Currently not working to include or exclude strings
//			if ((strlen(IncludeStr) == 0) || (StrSearch(objName,IncludeStr,0) > -1))
//				if (cmpstr(objName,StripStringItemsFromText(ExcludeList,objName)) == 0)
//					objList +=  objName + ";"
//				endif
//			endif
			index += 1
		while(1)
	
	SetDataFolder saveDfr
	
	return objList
End

Function /S UniqueFolderName(MainFolder,NewFolderName)
	String MainFolder, NewFolderName
	
	Variable LastNumber, FolderIndex=1
	String FolderBaseName, FullFolderName
	FullFolderName 	= ParseFilePath(2,MainFolder,":",0,0) + PossiblyQuoteName(NewFolderName)
	
	if (!DataFolderExists(FullFolderName))
		return NewFolderName		// No naming conflict
	endif
	
	// Test whether the name already ends in a number
	LastNumber 	= ReturnLastNumber(NewFolderName)
	
	// No number, so add one and test for a conflict	
	if (numtype(LastNumber) == 1)
		LastNumber = 1							
		NewFolderName 	= NewFolderName + " " + num2str(LastNumber)		// No numeric suffix, so try adding "1"
		FullFolderName 	= ParseFilePath(2,MainFolder,":",0,0) + PossiblyQuoteName(NewFolderName)
		if (!DataFolderExists(FullFolderName))
			return NewFolderName
		endif
	endif
	
	// Keep incrementing the last number until no conflict. 
	do
		LastNumber += 1
		FolderBaseName 	= ReturnTextBeforeNumber(NewFolderName)
		NewFolderName 	= FolderBaseName + num2str(LastNumber)
		FullFolderName 	= ParseFilePath(2,MainFolder,":",0,0) + PossiblyQuoteName(NewFolderName)
	while(DataFolderExists(FullFolderName))
	
	return NewFolderName
End


Function SetDataFolderOrRoot(Df)
	String Df
	
	if (DataFolderExists(Df) == 1)
		SetDataFolder $(Df)
	else
		SetDataFolder root:
	endif
end

Function /T CheckFolderColon(DataFolder)
	String DataFolder
	
	Variable len=strlen(DataFolder)
	if (cmpstr(":",DataFolder[len-1,len-1]) != 0)
		DataFolder+= ":"
	endif
	return DataFolder
End

Function /T StripFolderColon(DataFolder)
	String DataFolder
	
	return ParseFilePath(2, DataFolder, ":", 0, 0) 
End

// ***************************************************************************
// ********* 					Waves in Data Folders
// ***************************************************************************

// NOTE: Must include "*" in MatchStr!!!!
// An example of the use of this function FolderWaveList("root:StrucSims:FRACTALS:Clusters","XYZ*",";","")
Function /T FolderWaveList(DataFolder,MatchStr,Char,OPT,NPts,TextWaveFlag)
	String DataFolder,MatchStr,Char,OPT
	Variable NPts, TextWaveFlag
	
	Variable NumWaves, i, WvLen
	String WvName, ListOfWavesInFolder = "", ListOfAxesInFolder=""
	
	if (DataFolderExists(DataFolder) == 1)
		NumWaves = CountObjects(DataFolder,1)
		for(i=0;i<NumWaves;i+=1)
			WvName =  GetIndexedObjName(DataFolder,1,i)
			if (StringMatch(WvName,MatchStr) == 1)
				WAVE Wv 	= $(ParseFilePath(2,DataFolder,":",0,0) + WvName)
				
				if ((TextWaveFlag == 0) && (WaveType(Wv) > 0))			// Numeric waves only. 
					if ((NPts == -1) ||  (numpnts(Wv) == NPts))
						WvLen 	= strlen(WvName)
						/// !*!* We want axis waves to be deleted AFTER data waves. 
						if (cmpstr(WvName[WvLen-5,WvLen-1],"_axis") == 0)
							ListOfAxesInFolder += WvName + Char
						else
							ListOfWavesInFolder += WvName + Char
						endif
					endif
				elseif ((TextWaveFlag == 1) && (WaveType(Wv) == 0))	// Text waves only. 
					if ((NPts == -1) ||  (numpnts(Wv) == NPts))
						ListOfWavesInFolder += WvName + Char
					endif
				endif
			endif
		endfor
		
		return SortList(ListOfWavesInFolder) + SortList(ListOfAxesInFolder)
	else
		return ""
	endif
End

SortList

Function KillWavesInFolderFromList(DataFolder,DeleteDataList)
	String DataFolder, DeleteDataList

	if (DataFolderExists(DataFolder) == 1)
		String OldDF = getDataFolder(1)
		SetDataFolder $(DataFolder)
			KillWavesFromList(DeleteDataList,1)
		SetDataFolder $(OldDF)
	else
		// Print " *** The dataFolder",DataFolder,"does not exist!"
	endif
End

Function KillAllWavesInFolder(DataFolder,MatchStr)
	String DataFolder, MatchStr
	
	String ListOfWaves
	
	ListOfWaves = FolderWaveList(DataFolder,MatchStr,";","",-1,1)
	KillWavesInFolderFromList(DataFolder,ListOfWaves)
	
	ListOfWaves = FolderWaveList(DataFolder,MatchStr,";","",-1,0)
	KillWavesInFolderFromList(DataFolder,ListOfWaves)
End

// NOTE: Must include "*" in MatchStr!!!!
// NOTE: *$*$* This does not copy values between text waves! 
Function DuplicateAllWavesInDataFolder(Df1,Df2,MatchStr,TextWaveFlag)
	String Df1,Df2,MatchStr
	Variable TextWaveFlag
	
	String DataName, ListOfWavesInFolder
	Variable i, DataType, TextType, success
	
	if (DataFolderExists(Df1) == 1)
		ListOfWavesInFolder = FolderWaveList(Df1,MatchStr,";","",-1,TextWaveFlag)
		
		if (DataFolderExists(Df2) == 0)
			NewDataFolder /O $(Df2)
		endif
		
		if ((ItemsInList(ListOfWavesInFolder) == 0) && (strlen(MatchStr) > 1))
			// Print " *** DuplicateAllWavesInDataFolder: Did you omit the * from MatchStr?"
		else
			for (i=0;i<ItemsInList(ListOfWavesInFolder);i+=1)
			
				DataName = StringFromList(i,ListOfWavesInFolder)
				
				DataType = WaveType($ParseFilePath(2,Df1,":",0,0) +DataName)
				TextType 	= WaveType($ParseFilePath(2,Df1,":",0,0) +DataName,1)
				
				// Try to avoid Duplicate to preserve memory management. 
//				if ((DataType & 2^1) == 0)
				if (DataType == 3)
					success = OverwriteComplexWaves(Df1,Df2,DataName)
				elseif (TextType==2)
					success = OverwriteTextWaves(Df1,Df2,DataName)
				else
					success = OverwriteRealWaves(Df1,Df2,DataName)
				endif
				
				if (success == 0)
					Duplicate /O $(ParseFilePath(2,Df1,":",0,0) +DataName), $(ParseFilePath(2,Df2,":",0,0) +DataName)
				endif
				
			endfor
		endif
	endif
End

Function OverwriteRealWaves(Df1,Df2,DataName)
	String Df1,Df2,DataName
	
	WAVE /D data1 	= $(ParseFilePath(2,Df1,":",0,0) +DataName)
	WAVE /D data2 	= $(ParseFilePath(2,Df2,":",0,0) +DataName)
	
	if ((WaveExists(data2)) && (numpnts(data1) == numpnts(data2)))
		data2[] = data1[p]
		return 1
	else
		return 0
	endif
End

Function OverwriteComplexWaves(Df1,Df2,DataName)
	String Df1,Df2,DataName
	
	WAVE /C data1 	= $(ParseFilePath(2,Df1,":",0,0) +DataName)
	WAVE /C data2 	= $(ParseFilePath(2,Df2,":",0,0) +DataName)

	
	if ((WaveExists(data2)) && (numpnts(data1) == numpnts(data2)))
		data2[] = data1[p]
		return 1
	else
		return 0
	endif
End

Function OverwriteTextWaves(Df1,Df2,DataName)
	String Df1,Df2,DataName
	
	WAVE /T data1 	= $(ParseFilePath(2,Df1,":",0,0) +DataName)
	WAVE /T data2 	= $(ParseFilePath(2,Df2,":",0,0) +DataName)
	
	if ((WaveExists(data2)) && (numpnts(data1) == numpnts(data2)))
		data2[] = data1[p]
		return 1
	else
		return 0
	endif
End

Function DuplicateAllTracesToDataFolder(PlotName,Df2,MatchStr,AxisFlag)
	String PlotName,Df2,MatchStr
	Variable AxisFlag
	Variable i
	
	if (ItemsInList(WinList(PlotName,";","WIN:1")) > 0)
		String TraceList = InclusiveWaveList(TraceNameList(PlotName,";",1),MatchStr,";")

		if (ItemsInList(TraceList) > 0)
			if (DataFolderExists(Df2) == 0)
				NewDataFolder /O $(Df2)
			endif
			for (i=0;i<ItemsInList(TraceList);i+=1)
				CopyIndexTraceToDataFolder(PlotName,Df2,i, AxisFlag)
			endfor
		endif
	endif
End

Function CopyIndexTraceToDataFolder(PlotName,Df2,Index, AxisFlag)
	String PlotName,Df2
	Variable Index, AxisFlag
	
	String DataName, TraceDataAndFolder, CopyDataAndFolder
	
	DataName 			= NameOfWave(WaveRefIndexed(PlotName,Index,AxisFlag))
	TraceDataAndFolder	= GetWavesDataFolder(WaveRefIndexed(PlotName,Index,AxisFlag),2)
	CopyDataAndFolder	= Df2+":"+DataName
	
	Duplicate /O/D $TraceDataAndFolder, $CopyDataAndFolder
End

// ***************************************************************************
// ********* 					Global Strings & Variables in Data Folders
// ***************************************************************************

Function TransferStrsAndVars(Df1,Df2,MatchStr)
	String Df1,Df2, MatchStr
	
	DuplicateAllVarsInDataFolder(Df1,Df2,MatchStr,1)
	DuplicateAllVarsInDataFolder(Df1,Df2,MatchStr,0)
end

Function DuplicateAllVarsInDataFolder(Df1,Df2,MatchStr,NVARFlag)
	String Df1,Df2, MatchStr
	Variable NVARFlag
	
	String ObjName, Var1Name, Var2Name, Str1Name, Str2Name
	Variable NumVars,NumStr,i
	
	if (DataFolderExists(Df1) == 1)
		if (DataFolderExists(Df2) == 0)
			NewDataFolder /O $(Df2)
		endif
		
		MatchStr = ReplaceString("*",MatchStr,"")
		
		if (NVARFlag == 1)
			// CONSIDER VARIABLES
			NumVars = CountObjects(Df1,2)
			for (i=0;i<NumVars;i+=1)
				Var1Name = ""
				
				ObjName = GetIndexedObjName(Df1,2,i)
				
				if (StrSearch(GetIndexedObjName(Df1,2,i),MatchStr,0) > -1)
					Var1Name = CheckFolderColon(Df1) + GetIndexedObjName(Df1,2,i)
				elseif (strlen(MatchStr) == 0)
					Var1Name = CheckFolderColon(Df1) + GetIndexedObjName(Df1,2,i)
				endif
				
				if (strlen(Var1Name) > 0)
					NVAR Var1	= $(Var1Name)
					
					Var2Name = CheckFolderColon(Df2) + GetIndexedObjName(Df1,2,i)
					Variable /G $(Var2Name) = Var1
					
//					Print " 		 >>>>>>	Transfering",Var1Name,"to",Var2Name
				endif
			endfor
		else
			// CONSIDER STRINGS
			NumVars = CountObjects(Df1,3)
			for (i=0;i<NumVars;i+=1)
				Str1Name = ""
				
				if (StrSearch(GetIndexedObjName(Df1,3,i),MatchStr,0) > -1)
					Str1Name = CheckFolderColon(Df1) + GetIndexedObjName(Df1,3,i)
				elseif (strlen(MatchStr) == 0)
					Str1Name = CheckFolderColon(Df1) + GetIndexedObjName(Df1,3,i)
				endif
				
				if (strlen(Str1Name) > 0)
					SVAR Str1	= $(Str1Name)
					
					Str2Name = CheckFolderColon(Df2) + GetIndexedObjName(Df1,3,i)
					String /G $(Str2Name) = Str1
					
//					Print " 		 >>>>>>	Transfering",Str1Name,"to",Str2Name
				endif
			endfor
		endif
	endif
End




// ***************************************************************************
// ********* 					Managing Data Folders II Recursively
// ***************************************************************************

Function /T RecursiveDataFolderList(DataFolder)
	String DataFolder
	
	String DataFolderList, InnerDf
	Variable i, NumDf
	
	DataFolderList = AddPrefixOrSuffixToListItems(ReturnListOfDataFolders(DataFolder,"*"),CheckFolderColon(DataFolder),"")
	
	if (ItemsInList(DataFolderList) > 100)
		Print " *** Too many data folders to properly list!!"	
		return ""
	endif
	
	NumDf = ItemsInList(DataFolderList)
	if (NumDf > 0)
		for (i=0;i<NumDf;i+=1)
			InnerDf		= StringFromList(i,DataFolderList)
			
			DataFolderList += RecursiveDataFolderList(InnerDf)
		endfor
	endif
	
	return DataFolderList
End

Function ArchiveDataFolder(Df1,Df2,KillFlag)
	String Df1, Df2
	Variable KillFlag
	
	Variable NumDf, i
	String DataFolderList, InnerDf1,InnerDf2
	
	if (DataFolderExists(Df1) == 1)
		if ((DataFolderExists(Df2) == 1) && (KillFlag ==1))
			KillDataFolder $(Df2)
		endif
		NewDataFolder /O $(Df2)
		
		TransferStrsAndVars(Df1,Df2,"*")
		DuplicateAllWavesInDataFolder(Df1,Df2,"*",0)
		DuplicateAllWavesInDataFolder(Df1,Df2,"*",1)
		
		DataFolderList = RecursiveDataFolderList(Df1)
		NumDf	= ItemsInList(DataFolderList)
		
		if (NumDf > 0)
			for (i=0;i<NumDf;i+=1)
				InnerDf1 = StringFromList(i,DataFolderList)
				InnerDf2 = CheckFolderColon(Df2) + ReplaceString(CheckFolderColon(Df1),StringFromList(i,DataFolderList),"")
				
				NewDataFolder $(InnerDf2)
				TransferStrsAndVars(InnerDf1,InnerDf2,"*")
				DuplicateAllWavesInDataFolder(InnerDf1,InnerDf2,"*",0)
				DuplicateAllWavesInDataFolder(InnerDf1,InnerDf2,"*",1)
			endfor
		endif
	endif
End

Function SwapDataFolderNames(Df0,Df1,Df2)
	String Df0,Df1,Df2
	
	String SelectFolder, SwapFolder, TempFolder

//print Df0
//print CheckFolderColon(Df0)+Df1
//print CheckFolderColon(Df0)+Df2

	if ((DataFolderExists(Df0) + DataFolderExists(CheckFolderColon(Df0)+Df1) + DataFolderExists(CheckFolderColon(Df0)+Df2)) == 3)
		SwapFolder	= CheckFolderColon(Df0) + Df1
		RenameDataFolder $(SwapFolder), $("Temp")
		
		SelectFolder	= CheckFolderColon(Df0) + Df2
		RenameDataFolder $(SelectFolder), $(Df1)
		
		TempFolder	= CheckFolderColon(Df0) + "Temp"
		RenameDataFolder $(TempFolder), $(Df2)
	endif
End



// ***************************************************************************
// ********* 					Managing Data Folders
// ***************************************************************************

Function KillMatchingDataFolders(DataFolder,MatchStr)
	String DataFolder, MatchStr
	
	String ToKillList 	= ReturnListOfDataFolders(DataFolder,MatchStr)
	KillDataFoldersFromList(DataFolder,ToKillList)
End

Function /T ReturnListOfDataFolders(DataFolder,MatchStr)
	String DataFolder, MatchStr
	
	if (DataFolderExists(DataFolder) == 1)
		Variable i, NumDataFolders = CountObjects(DataFolder, 4 )
		String DataFolderName, DataFolderList=""
		
		MatchStr = ReplaceString("*",MatchStr,"")
		
		for (i=0;i<NumDataFolders;i+=1)
			DataFolderName = GetIndexedObjName(DataFolder, 4, i)
			if (strsearch(DataFolderName,MatchStr,0) > -1)
				DataFolderList += DataFolderName + ";"
			elseif (strlen(MatchStr) == 0)
				DataFolderList += DataFolderName + ";"
			endif
		endfor
		
		return DataFolderList
	else
		return ""
	endif
End

Function KillDataFoldersFromList(DataFolder,DataFolderList)
	String DataFolder,DataFolderList
	
	String DataFolderName, FullDataFolder
	Variable i, NumDataFolders = ItemsInList(DataFolderList)
	
	if ((DataFolderExists(DataFolder) == 1) && (NumDataFolders>0))
		for (i=0;i<NumDataFolders;i+=1)
			DataFolderName = StringFromList(i,DataFolderList)
			If (DataFolderExists(ParseFilePath(2,DataFolder,":",0,0)+DataFolderName) == 1)
				FullDataFolder = ParseFilePath(2,DataFolder,":",0,0)+DataFolderName
				KillDataFolder $(ParseFilePath(2,DataFolder,":",0,0)+DataFolderName)
			endif
		endfor
	endif
End