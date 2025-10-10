#pragma rtGlobals=1		// Use modern global access method.


Function /S PromptforStackName(Filename)
	String Filename
	
	String StackName

	// Give the stack a nice name
	StackName 	= StripSpacesAndSuffix(Filename,".")
	StackName 	= CleanUpDataName(StackName)
	Prompt StackName, "Name of imported stack"
	do
		DoPrompt "Please avoid odd characters and 'stack'!", StackName
		if (V_flag)
			return ""
		endif
		StackName 	= CleanUpDataName(StackName)
	while(StrSearch(StackName,"stack",0,2) > -1)
	
	return StackName		
End

// *************************************************************
// ****		IMPORTING Pradeep's Raman spectromicroscopy data
// *************************************************************
Function LoadHPRaman()

	String LoadedName, StackName, AxisName, OldDf = GetDataFolder(1)
	Variable NX=76, NY=76, NE
	Variable i, j, NPx = NX*NY
	
	InitializeStackBrowser()
	SetDataFolder root:SPHINX:Stacks
	
		LoadWave /Q/G/M/N=RamanStack
		if (V_flag == 0)
			return 0
		endif
		NewPath /Q/O StackPath, S_path
		
		LoadedName = StringFromList(0,S_Filename) // This is the name of the file, not the new matrix
		WAVE Loaded 	= RamanStack0
		
		if (DimSize(Loaded,0)!=NPx)
			print " *** Please check number of pixels ***"
			return 0
		endif
		
		StackName 	= PromptforStackName(S_Filename)
		if (strlen(StackName)==0)
			return 0
		endif
		
		AxisName 	= StackName + "_axis"
		NE 	= DimSize(Loaded,1)
		Make /D/O/N=(NE) $AxisName /WAVE=Axis
		Axis = 442 + 3*p
		
		// Rename the stack
		if (WaveExists($StackName) == 1)
			DoWindow /K StackBrowser
			RemoveDataFromAllWindows(StackName)
			KillWaves $StackName
		endif
		
		Make /D/O/N=(NX,NY,NE) $StackName /WAVE=Raman
		
		for (i=0;i<NX;i+=1)
			for (j=0;j<NX;j+=1)
				Raman[i][j][] 	= Loaded[i*76 + j][r]
			endfor
		endfor
		
		KillWaves /Z Loaded
		
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded a SPHINX stack: "+StackName
		
	SetDataFolder $(OldDf)
	
End





// *************************************************************
// ****		IMPORTING 10.3.2 MCA X-ray Fluorescence binary files
// *************************************************************
Function LoadMCAStack()

	String LoadedName, StackName, XRFFileName, XRFLine, OldDf = GetDataFolder(1)
	Variable i, j, NPoints, NLines, NMCAs
	
	InitializeStackBrowser()
	SetDataFolder root:SPHINX:Stacks
		
		Variable FileRefNum
		Open /D/R/T=".xrf" FileRefNum
		if (StrLen(S_fileName) == 0)
			return 0 
		endif
		
		Open /R FileRefNum as S_fileName
		
		do
			FReadLine FileRefNum, XRFLine
			
			if (strlen(XRFLine) == 0)
				break	// No more lines in file.
			elseif (StrSearch(XRFLine,"# points, # scan lines",0) > -1)
				NPoints = ReturnNthNumber(XRFLine,1)
				NLines = ReturnNthNumber(XRFLine,2)
				break	// Got what we needed.
			endif
		while(1)
		Close FileRefNum
		
		XRFFileName = ReplaceString(".xrf",S_fileName,".xb")
		
//		GBLoadWave /A=mca/O/B/T={96,4}/W=1 XRFFileName
		GBLoadWave /A=mca/O/B/T={16,96}/W=1 XRFFileName
		if (V_flag==0)
			print "	*** error loading bindary MCA data ***	"
			return 0
		endif
		
		print " 	*** Loaded binary MCA data size",NPoints,"x",NLines
		NMCAs = NPoints*NLines
		WAVE mca0 = mca0
		WaveStats /M=1/Q mca0
		
//		return 0
		
		Duplicate /O mca0, mca1
		FindLevel /EDGE=1/P/R=[1] mca0, 1
		
		print " 		... the first value is",mca0[0],"and the first data point is at p=",V_LevelX
		
		DeletePoints 0,V_LevelX+1, mca1
		
		Duplicate /O mca1, mca2
//		ReDimension /N=(NMCAs,256) mca2
		ReDimension /N=(512,NMCAs) mca2
		mca2 = NaN
		
		for (i=0;i<10000;i+=1)
			mca2[][i] = mca1[(513*i)+p]
		endfor
		
//		mca2[][] = mca1[][]
		
		return 0
		
		Make /U/N=(NPoints,NLines,512) mcaStack
//		mcaStack[][][] = mca0[][][]
		
		// Give the stack a nice name
		StackName 	= StripSpacesAndSuffix(S_Filename,".")
		StackName 	= CleanUpDataName(StackName)
		Prompt StackName, "Name of imported stack"
		do
			DoPrompt "Please avoid odd characters and 'stack'!", StackName
			if (V_flag)
				return 0
			endif
			StackName 	= CleanUpDataName(StackName)
		while(StrSearch(StackName,"stack",0,2) > -1)

		// Rename the stack
		if (WaveExists($StackName) == 1)
			DoWindow /K StackBrowser
			RemoveDataFromAllWindows(StackName)
			KillWaves $StackName
		endif
//		LoadedName = StringFromList(0,S_Filename)
		Rename mca0, $StackName
		
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded an MCA stack: "+StackName+", of ",NPoints,"x",NLines
		
	SetDataFolder $(OldDf)
End




// *************************************************************
// ****		IMPORTING TIFF STACKS that have already been created and saved
// *************************************************************
Function LoadTIFFStack()

	String LoadedName, StackName, OldDf = GetDataFolder(1)
	
	InitializeStackBrowser()
	SetDataFolder root:SPHINX:Stacks
	
		ImageLoad /C=-1/Q/O/T=TIFF
		if (V_flag == 0)
			return 0
		endif
		NewPath /Q/O StackPath, S_path
		
		// Give the stack a nice name
		StackName 	= StripSpacesAndSuffix(S_Filename,".")
		StackName 	= CleanUpDataName(StackName)
		Prompt StackName, "Name of imported stack"
		do
			DoPrompt "Please avoid odd characters and 'stack'!", StackName
			if (V_flag)
				return 0
			endif
			StackName 	= CleanUpDataName(StackName)
		while(StrSearch(StackName,"stack",0,2) > -1)
		
		// Rename the stack
		if (WaveExists($StackName) == 1)
			DoWindow /K StackBrowser
			RemoveDataFromAllWindows(StackName)
			KillWaves $StackName
		endif
		LoadedName = StringFromList(0,S_Filename)
		Rename $LoadedName, $StackName
		
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded a SPHINX stack: "+StackName
		
	SetDataFolder $(OldDf)
End

Function /T ReturnStackList(StackFolder)
	String StackFolder
	
	Variable i, NumWaves
	String WvName, StackList = ""
	
	NumWaves = CountObjects(StackFolder,1)
	for(i=0;i<NumWaves;i+=1)
		WvName =  GetIndexedObjName(StackFolder,1,i)
		if (StrSearch(WvName,"_axis",0) == -1)
			WAVE Wv 	= $(ParseFilePath(2,StackFolder,":",0,0) + WvName)
			if (DimSize(Wv,2) > 0)
				StackList += WvName+";"
			endif
		endif
	endfor
	
	return StackList
End

Function /T ReturnImageList(ImageFolder,RGBFlag)
	String ImageFolder
	Variable RGBFlag
	
	Variable i, NumWaves
	String WvName, ImageList = ""
	
	NumWaves = CountObjects(ImageFolder,1)
	for(i=0;i<NumWaves;i+=1)
		WvName =  GetIndexedObjName(ImageFolder,1,i)
		if (StrSearch(WvName,"_axis",0) == -1)
			WAVE Wv 	= $(ParseFilePath(2,ImageFolder,":",0,0) + WvName)
			if ((DimSize(Wv,1) > 0))
				if (RGBFlag)
					if (DimSize(Wv,2) == 3)
						ImageList += WvName+";"
					endif
				else
					if (DimSize(Wv,2) == 0)
						ImageList += WvName+";"
					endif
				endif
			endif
		endif
	endfor
	
	return ImageList
End

Function /T ChooseStack(Msg,defaultStack,AllFlag)
	String Msg,defaultStack
	Variable AllFlag
	
	Variable NStacks
	String StackName, StackFolder = "root:SPHINX:Stacks"
	String WvName, StackList = ""
	
	StackName 	= defaultStack
	StackList 	= ReturnStackList(StackFolder)
	NStacks 	= ItemsInList(StackList)
	
	if (NStacks == 0)
		DoAlert 0, "Please load a stack to plot"
		return ""
	elseif (NStacks == 1)
		return StringFromList(0,StackList)
	else
		if (AllFlag)
			StackList 	= "all;"+StackList
		endif
		Prompt StackName, "List of loaded stacks", popup, StackList
		DoPrompt Msg, StackName
		if (V_flag)
			return "_quit!_"
		endif
		
		return StackName
	endif
End

Function /T ModifiedStackName(StackName,suffix)
	String StackName, suffix

	Variable MatchIdx, RptNum=1
	String cStackName 	= StripSpacesAndSuffix(StackName ,"_"+suffix)+ "_" + suffix
	String StackList 	= ReturnStackList("root:SPHINX:Stacks")
	
	do
		MatchIdx = FindListItem(cStackName,StackList)
		if (MatchIdx > -1)
			cStackName = StripSpacesAndSuffix(StackName,"_"+suffix) + "_"+suffix 
			if (RptNum > 1)
				cStackName += num2str(RptNum)
			endif
			RptNum += 1
		endif
			
	while(MatchIdx>-1)
	
	return cStackName
End

Function DeleteStack()
	
	String StackFolder 	= "root:SPHINX:Stacks"
	String StackName, StackList 	= ReturnStackList(StackFolder)
	
	Variable i, NStacks= ItemsInList(StackList)
	
	if (NStacks == 0)
		return 0
	elseif (NStacks == 1)
		DoWindow /K StackBrowser
		StackName 	= StringFromList(0,StackList)
		KillAllWavesInFolder(StackFolder,StackName+"*")
	
	else
		StackName 	= ChooseStack(" Choose the stack to delete","",1)
		if (cmpstr("_quit!_",StackName) == 0)
			return 0
		elseif (cmpstr("all",StackName) == 0)
			DoWindow /K StackBrowser
			
			for (i=0;i<NStacks;i+=1)
				StackName 	= StringFromList(i,StackList)
				KillAllWavesInFolder(StackFolder,StackName+"*")
			endfor
		else	
			DoWindow StackBrowser
			if (V_flag)
				if (WhichListItem(StackName+"_av",ImageNameList("StackBrowser#StackImage", ";")) > -1)
					DoWindow /K StackBrowser
				endif
			endif
			KillAllWavesInFolder(StackFolder,StackName+"*")
		endif
	endif
	
	WAVE aPOL_RGB 	= root:SPHINX:Stacks:aPOL_RGB
	if (WaveExists(aPOL_RGB))
		aPOL_RGB = NaN
	endif
End



// *************************************************************
// ****		EXPORTING TIFF STACKS and Images
// *************************************************************
//Function SaveStack()
//
//	SVAR gStackName = root:SPHINX:Import:gStackName
//	
//	WAVE ImageStack = $("root:SPHINX:Stacks:"+gStackName)
//	ExportImage(ImageStack,0)
//	
//	return 0
//	
//	MakeStringIfNeeded("root:SPHINX:Stacks:gStack2Save","")
//	MakeStringIfNeeded("root:SPHINX:Stacks:gSaveName","")
//	
//	SVAR gStack2Save	= root:SPHINX:Stacks:gStack2Save
//	SVAR gSaveName	= root:SPHINX:Stacks:gSaveName
//	
//	String StackFolder = "root:SPHINX:Stacks"
//	String SackAxisName
//	String StackList 	= ReturnStackList(StackFolder)
//	
//	String StackName=gSaveName
//	Prompt StackName, "List of loaded stacks", popup, StackList
//	String SaveName = gStack2Save
//	Prompt SaveName, "New export name or blank for default"
//	DoPrompt "Save stack", StackName, SaveName
//	if (V_flag)
//		return 0
//	endif
//	
//	SackAxisName = StackName + "_axis"
//	
//	Print " *** Not saved"
//End