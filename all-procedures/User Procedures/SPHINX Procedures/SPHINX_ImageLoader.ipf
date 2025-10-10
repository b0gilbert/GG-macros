#pragma rtGlobals=1		// Use modern global access method.

// *************************************************************
// ****		Dedicated routine for STXM data
// *************************************************************
// Summarize STXM data contained within a single folder, e.g., all the data acquired on a single day. 
Function SummarizeSTXMFolder()
	String LoadType

	InitializeStackBrowser()
	
	String DataName, HeaderPath, FileLine, PointsList
	Variable i, refNum, LineNum, aMax, aMin
	
	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Import
		KillWaves /A/Z
		
		NewPath /Q/M="Select path to STXM data" /O Path2STXM
		if (V_Flag!=0)
			SetDataFolder $(OldDf)
			return 0
		endif 
		PathInfo Path2STXM
		String PathName 	= S_path
		String STXMName 	= ParseFilePath(0,S_path,":",1,0)
		String FolderName 	= CleanUpName(STXMName,0)
		
		String ListOfAllFiles = ReplaceString(".hdr",IndexedFile(Path2STXM,-1,".hdr"),"")
		String ListOfAllDirs = AddPrefixOrSuffixToListItems(IndexedDir(Path2STXM,-1,0),""," (folder)")
		String STXMList 	= SortList(ListOfAllFiles + ListOfAllDirs)
		
		Make /O/T/N=(ItemsInList(STXMList)) $("STXM_Names"+STXMName) /WAVE=STXMNames
		Make /O/T/N=(ItemsInList(STXMList),6) $("STXM_Params"+STXMName) /WAVE=STXMParams
		STXMNames 	= ""
		STXMNames[] 	= StringFromList(p,STXMList)
		STXMParams 	= ""
		
		for (i=0;i<ItemsInList(STXMList);i+=1)
			DataName 	= STXMNames[i][0]
			
			if (StrSearch(DataName,"(folder)",-1) > -1)
				DataName 	= ReplaceString(" (folder)",DataName,"")
				HeaderPath 	= ParseFilePath(2,PathName + DataName,":",0,0) + DataName + ".hdr"
			else
				HeaderPath 	= ParseFilePath(2,PathName,":",0,0) + DataName + ".hdr"
			endif
							
			Open /Z/R refNum as HeaderPath
			if (refNum != 0)
				
				FileLine 		= ReturnKeyWordLineInOpenfile(refNum,"StackAxis",LineNum,0)
				FileLine 		= ReplaceString("\"",FileLine,"")
				FileLine 		= ReplaceString(" ",FileLine,"")
				
				STXMParams[i][0] 	= StringByKey("Unit",FileLine,"=")		// The axis unit (tricky to extract the name
				STXMParams[i][1] 	= StringByKey("Min",FileLine,"=")			// Axis min value
				STXMParams[i][2] 	= StringByKey("Max",FileLine,"=")			// Axis max value
				
				FReadLine refNum, FileLine
				FileLine 		= ReplaceString(" ",FileLine,"")
				PointsList 		= ReturnStringInBrackets(FileLine,"(",")")
				STXMParams[i][3] 	= StringFromList(0,PointsList,",")			// Axis max value
			
				Close refNum
			endif
			refNum = 0
		endfor
		
		DoWindow $FolderName
		if (!V_flag)
			Edit /K=1/N=$FolderName STXMNames as "STXM data in "+FolderName
			AppendToTable STXMParams
			ModifyTable /W= $FolderName title[1]="Name"
		endif
		
	SetDataFolder $(OldDf)
End


// *************************************************************
// ****		Main Image Loading routines
// *************************************************************
Function StackImages()

	LoadMultipleImages("Stack")
End

Function LoadDistMapImages()

	LoadMultipleImages("Distribution Map")
End

// *************************************************************
// ****		Create a Stack from all the images in a folder
// *************************************************************
Function LoadMultipleImages(LoadType)
	String LoadType

	InitializeStackBrowser()
	
	Variable i, NImages, NLoaded=0, NumE
	String suffix, FolderName, FileList, FileName, ImageName, msg
	String StackFolder = "root:SPHINX:Stacks"

	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Import
		KillWaves /A/Z
		
		Variable /G gDimX=0, gDimY=0
		
		SVAR gFileType 		= gFileType
		SVAR gImportName	= gImportName
		SVAR gNameChoice 	= gNameChoice
		SVAR gBitInfo 		= gBitInfo
	
		NewPath /Q/M="Select path to images" /O Path2Image
		if (V_Flag!=0)
			SetDataFolder $(OldDf)
			return 0
		endif 
		
		PathInfo Path2Image
		FolderName 	= ParseFilePath(0, S_path, ":", 1, 0)
		
		String FileType = gFileType
		Prompt FileType, "Type of file", popup, "TIFF;P3B;XIM;PNG;"
		String ImportName = FolderName
		Prompt ImportName, LoadType + " name"
		DoPrompt "Importing "+LoadType+" images",FileType, ImportName
		if (V_flag)
			return 0
		endif
		
		gFileType 		= FileType
		gImportName 	= CleanUpName(ImportName,0) 
		
		suffix 			= ReturnImageSuffix(FileType)
		FileList 		= IndexedFile(Path2Image,-1,suffix)
		FileList 		= SortList(FileList,";",16)
		NImages 		= ItemsInList(FileList)
		
		if (NImages == 0)
			DoAlert 0,"The folder is empty or contains files of a different format"
			SetDataFolder $(OldDf)
			return 0
		elseif (NImages == 1)
			DoAlert 0,"The folder contains a single image"
			SetDataFolder $(OldDf)
			return 0
		
		// I'm not sure why this option that automatically assumed 2 images were a distribution map was disabled. 
		
//		elseif ((cmpstr("Distribution Map",LoadType) != 0) && (NImages == 2))
//			DoAlert 1, "Distribution Map?"
//			if (V_flag == 2)
//				DoAlert 0, "2 images can only be opened as a Distribution Map"
//				SetDataFolder $(OldDf)
//				return 0
//			else
//				LoadType 	= "Distribution Map"
//			endif

		endif
		
		for (i=0;i<NImages; i+=1)
			FileName 		= StringFromList(i,FileList)
			ImageName 		= LoadSingleImage(FileType,FileName,i,0)
			
			if (strlen(imageName) == 0)
				DoAlert 0, "Zero bytes in image file! Aborting!"
				KillNNamedWaves("image",NImages)
				SetDataFolder $(OldDf)
				return 0
			endif
		endfor
		
		if (cmpstr("Stack",LoadType) == 0)
			NumE 	= StackFromImages(gImportName,FileType)
			msg 	= " *** Loaded a stack from: "+S_path
			
			// Try to automatically load the energy axis
			String Path2File 	= ParseFilePath(2,S_path,":",0,0) + gImportName + ".dat"
			Loadwave /W/A/O/D/G/Q Path2File
			if (FinishStackAxisLoad(S_WaveNames,StackFolder,gImportName,NumE) == 1)
				msg += " and loaded the accompanying energy axis. "
			endif
			
			print msg
			
		elseif (cmpstr("Distribution Map",LoadType) == 0)
			Print " *** Loaded a distribution map from: ",S_path
			DistMapFromImages(gImportName,FileType)
		endif
		
	SetDataFolder $(OldDf)
End

Function StackFromImages(StackName,FileType)
	String StackName, FileType
		
	SVAR gStackName	= root:SPHINX:Import:gStackName
	gStackName 		= StackName
	
	Variable is8Bit, NumE
	String EAxisName
	
	// Construct and rename the Stack
	ImageTransform/K stackImages $"image0"
	WAVE ImageStack = M_Stack
	
	SetSPHINXImageScale("M_Stack")
	
	DoWindow /K StackBrowser
	KillAllWavesInFolder("root:SPHINX:Import",gStackName+"*")
	KillAllWavesInFolder("root:SPHINX:Stacks",gStackName+"*")
	
	NumE 	= DimSize(M_Stack,2)
	Rename M_Stack, $gStackName
	MoveWave $gStackName, root:SPHINX:Stacks:
	
	// I don't know which data type this is associated with. 
	WAVE EAxis 	= root:SPHINX:Import:image0_axis
	if (WaveExists(EAxis))
		EAxisName 	= gStackName+"_axis"
		Rename EAxis, $EAxisName
		MoveWave $EAxisName, root:SPHINX:Stacks:
	endif
	
	is8Bit 		= WaveType(ImageStack) & 0x08
	if ((cmpstr(FileType,"P3B")==0) && !is8Bit)
		// Convert 16-bit P3B files to 8-bit
		RunConvertStackTo8Bit(ImageStack,gStackName)
	else
		DisplayStackBrowser(gStackName)
	endif
	
	Print " *** Created a SPHINX stack: "+StackName
	
	return NumE
End

// *************************************************************
// ****		Load and Display a Single Image of any supported type
// *************************************************************
Function LoadImage()

	InitializeStackBrowser()
	
	Variable refNum
	String ImagePath, FileName, ImageName, ImageNewName, StackWaveList
	String ImageFilterList = "Data Files (*.tif,*.bmp,*.p3b,*.xim,*.png):.tif,.bmp,.p3b,.xim,.png;"
	
	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Import
		KillWaves /Z/A
		
		SVAR gFileType 	= gFileType
		SVAR gBitInfo 	= gBitInfo
		
		String FileType = gFileType
		Prompt FileType, "Type of file", popup, "TIFF;P3B;XIM;PNG;"
		DoPrompt "Importing image",FileType
		if (V_flag)
			return 0
		endif
		
		gFileType 	= FileType
		
		String msg = "Please locate the "+fileType+" file"
		Open /D/R/M=msg/F=ImageFilterList refNum
		if (strlen(S_fileName) == 0)
			SetDataFolder $OldDf
			return 0
		endif
		
		// Save the path to the file. 
		ImagePath 		= ParseFilePath(1, S_fileName, ":", 1, 0)
		NewPath /O/Q/Z Path2Image, ImagePath
		
		// Load the image
		FileName 		= ParseFilePath(0, S_fileName, ":", 1, 0)
		imageName 		= LoadSingleImage(FileType,FileName,0,1)
		
		if (strlen(imageName) > 0)
			StackWaveList = FolderWaveList("root:SPHINX:Import",ImageName+"*",";","",-1,0)
			KillWavesInFolderFromList("root:SPHINX:Stacks",StackWaveList)
			DuplicateAllWavesInDataFolder("","root:SPHINX:Stacks",ImageName+"*",0)
		
			DisplaySPHINXImage(ImageName)
		endif
		
	SetDataFolder $OldDf
End

Function /T LoadSingleImage(FileType,FileName,FileNumber,UserFlag)
	String FileType, FileName
	Variable FileNumber, UserFlag

	String ImageName=""
	String FileSuffix 		= ReturnImageSuffix(FileType)
		
	strswitch (FileType)
		case "TIFF":
			imageName = LoadImageOfType(FileType,FileName,FileSuffix,FileNumber,UserFlag)
			break
		case "JPEG":
			break
		case "PNG":
			imageName = LoadImageOfType(FileType,FileName,FileSuffix,FileNumber,UserFlag)
			break
		case "BMP":
			break
		case "P3B":
			imageName = LoadP3BImage(FileName,FileSuffix,FileNumber,UserFlag)
			break
		case "XIM":
			imageName = LoadXIMImage(FileName,FileSuffix,FileNumber,UserFlag)
			break
	endswitch
	
	return imageName
End

Function /T GetSPHINXImageName(FileName,FileSuffix,FileNumber,UserFlag)
	String FileName,FileSuffix
	Variable FileNumber,UserFlag
	
	String ImageName
	
	if (UserFlag)
		ImageName 	= CleanUpName(StripSuffixBySuffix(FileName,FileSuffix),0)
		ImageName	= PromptForUserStrInput(ImageName,"Image Load","Rename image if desired")
		if (cmpstr("_quit!_",ImageName) ==0)
			return ""
		endif
		ImageName 	= CleanUpName(ImageName,0)
	else
		imageName = "image"+num2str(FileNumber)
	endif
	
	return ImageName
End

Function SetSPHINXImageScale(ImageName)
	String ImageName
	
	WAVE Image 		= $("root:SPHINX:Import:"+ImageName)
	
	NVAR gXAxisMin 	= root:SPHINX:Import:gXAxisMin
	NVAR gXAxisMax 	= root:SPHINX:Import:gXAxisMax
	SVAR gXAxisUnit 	= root:SPHINX:Import:gXAxisUnit
	
	NVAR gYAxisMin 	= root:SPHINX:Import:gYAxisMin
	NVAR gYAxisMax 	= root:SPHINX:Import:gYAxisMax
	SVAR gYAxisUnit 	= root:SPHINX:Import:gYAxisUnit
	
	// At present, throw away absolute coordinate information. 
	SetScale /I x, 0, (gXAxisMax-gXAxisMin), gXAxisUnit, Image 
	SetScale /I y, 0, (gYAxisMax-gYAxisMin), gYAxisUnit, Image 
	
//	SetScale /I x, gXAxisMin, gXAxisMax, gXAxisUnit, Image 
//	SetScale /I y, gYAxisMin, gYAxisMax, gYAxisUnit, Image 
End


Function TransferSPHINXImageScale(Image1,Image2)
	Wave image1, image2
	
	SetScale /P x, DimOffset(Image1,0), DimDelta(image1,0), WaveUnits(Image1,0), Image2
	SetScale /P y, DimOffset(Image1,1), DimDelta(image1,1), WaveUnits(Image1,1), Image2
End

// *************************************************************
// ****		Image File Loading Routine: TIFF
// *************************************************************
Function /T LoadImageOfType(FileType,FileName, FileSuffix, FileNumber, UserFlag)
	String FileType, FileName, FileSuffix
	Variable FileNumber, UserFlag
	
	String imageName, TIFFname
	Variable DimX, DimY, DimZ
	
	strswitch (FileType)
		case "TIFF":
			// *** 2017-10-10 No longer use the filename as the image name
//			ImageLoad /Q/T=TIFF/P=Path2Image FileName
			ImageLoad /N=TIFFimage/Q/T=TIFF/P=Path2Image FileName
			if (!V_flag)
				return ""
			else
				TIFFname = StringFromList(0,S_waveNames)
			endif
			break
		case "PNG":
			ImageLoad /Q/T=PNG/P=Path2Image FileName
			break
	endswitch
	
//	DimX 	= DimSize($FileName,0)
//	DimY 	= DimSize($FileName,1)
//	DimZ 	= DimSize($FileName,2)
	
	DimX 	= DimSize($TIFFname,0)
	DimY 	= DimSize($TIFFname,1)
	DimZ 	= DimSize($TIFFname,2)
	
	if (DimZ > 1)
		Redimension /N=(DimX,DimY) $FileName
	endif
	
	ImageName = GetSPHINXImageName(FileName,FileSuffix,FileNumber,UserFlag)
	if (strlen(ImageName) == 0)
		return ""
	endif
	
//	print FileName, imageName
	
	if (cmpstr(FileName,ImageName) != 0)
		KillWaves /Z $ImageName
//		Rename $FileName, $imageName
		Rename $TIFFname, $imageName
	endif
	
	return imageName
End

// *************************************************************
// ****		Image File Loading Routine: TIFF
// *************************************************************
//Function /T LoadTIFFImage(FileName, FileSuffix, FileNumber, UserFlag)
//	String FileName, FileSuffix
//	Variable FileNumber, UserFlag
//	
//	String imageName
//	
//	ImageLoad /Q/T=TIFF/P=Path2Image FileName
//	
//	ImageName = GetSPHINXImageName(FileName,FileSuffix,FileNumber,UserFlag)
//	if (strlen(ImageName) == 0)
//		return ""
//	endif
//	
//	if (cmpstr(FileName,ImageName) != 0)
//		KillWaves /Z $ImageName
//		Rename $FileName, $imageName
//	endif
//	
//	return imageName
//End

// *************************************************************
// ****		Image File Loading Routine: Xim
// *************************************************************
Function /T LoadXIMImage(FileName,FileSuffix,FileNumber,UserFlag)
	String FileName, FileSuffix
	Variable FileNumber, UserFlag
	
	String ImageName, LoadName
	Variable DimX, DimY
	
	LoadWave /Q/J/M/D/V={"\t "," $",0,1}/A=image/P=Path2Image FileName
	
	if (V_flag == 0)
		Print " *** No image data loaded!"
		return ""
	endif
	
	LoadName 	= StringFromList(0,S_waveNames)
	ImageName 	= GetSPHINXImageName(FileName,FileSuffix,FileNumber,UserFlag)
	if (strlen(ImageName) == 0)
		return ""
	endif
	
	if (cmpstr(LoadName,ImageName) != 0)
		KillWaves /Z $ImageName
		Rename $LoadName, $imageName
	endif
	
	if (1)	// Delete a blank column that is read in
		DimX = DimSize($imageName,0)
		DimY = DimSize($imageName,1)
		ReDimension /N=(DimX,DimY-1) $imageName
	endif
	
	// For the zeroth (or only) image, parse the header file for spatial and energy ranges
	if (FileNumber == 0)
		LoadXIMHeader(ImageName,StripSuffixBySeparator(FileName,"_")+".hdr")
	endif
	
	SetSPHINXImageScale(ImageName)
	
	return imageName
End

Function /T LoadXIMHeader(ImageName,HdrName)
	String ImageName, HdrName
	
	Variable refNum, AxisMin,AxisMax,AxisNPts
	String HDRLine, AxisName, AxisUnit
	
	Open /Z/R/P=Path2Image refNum as HdrName
	if (V_flag != 0)
		Print " *** Problem loading header file!"
		return ""
	endif
	
	do
		FReadLine refNum, HDRLine
		if (strlen(HDRLine) == 0)
			break
		endif
		
		// Find the list of x-values
		if (StrSearch(HDRLine,"PAxis",0) > -1)
			AxisFromXIMHeaderLines(CleanUpHeaderLine(HDRLine,"PAxis","{","}"), ImageName+"_p","X",AxisName,AxisNPts,0,refNum)
		endif
		
		// Find the list of y-values
		if (StrSearch(HDRLine,"QAxis",0) > -1)
			AxisFromXIMHeaderLines(CleanUpHeaderLine(HDRLine,"QAxis","{","}"), ImageName+"_q","Y",AxisName,AxisNPts,0,refNum)
		endif
		
		// Find the list of energy-values
		if (StrSearch(HDRLine,"StackAxis",0) > -1)
			AxisFromXIMHeaderLines(CleanUpHeaderLine(HDRLine,"StackAxis","{","}"), ImageName+"_axis","E",AxisName,AxisNPts,1,refNum)
			
			// Should this happen here? 
			NVAR gEAxisMin 	= root:SPHINX:Import:gEAxisMin
			SVAR gEAxisUnit 	= root:SPHINX:Import:gEAxisUnit
			Note /K $ImageName, AxisName+" = "+num2str(gEAxisMin)+" "+gEAxisUnit
		endif
		
	while(1)
	
	Close refNum
End

Function /T CleanUpHeaderLine(HDRLine,KeyWord,Brkt1,Brkt2)
	String HDRLine, KeyWord,Brkt1,Brkt2
	
	HDRLine 	= ReplaceString(" " ,HDRLine,"")
	HDRLine 	= ReplaceString("\t" ,HDRLine,"")
	HDRLine 	= ReplaceString("\"" ,HDRLine,"")
	HDRLine 	= ReplaceString(KeyWord+"=" ,HDRLine,"")
	HDRLine 	= ReplaceString(Brkt1 ,HDRLine,"")
	HDRLine 	= ReplaceString(Brkt2 ,HDRLine,"")
	
	return HDRLine
End

Function AxisFromXIMHeaderLines(HDRLine, AxisWaveName,AxisType,AxisName,AxisNPts,MakeAxis,refNum)
	String HDRLine, AxisWaveName, AxisType, &AxisName
	Variable &AxisNPts,MakeAxis,refNum
	
	
	NVAR AxisMin 	= $("root:SPHINX:Import:g"+AxisType+"AxisMin")
	NVAR AxisMax 	= $("root:SPHINX:Import:g"+AxisType+"AxisMax")
	SVAR AxisUnit 	= $("root:SPHINX:Import:g"+AxisType+"AxisUnit")
	
	String AxisValues
	Variable i
	
	// First, read in some information from the present line. 
	AxisName 	= StringByKey("Name",HDRLine,"=")
	AxisUnit 	= StringByKey("Unit",HDRLine,"=")
	AxisMin 	= NumberByKey("Min",HDRLine,"=")
	AxisMax 	= NumberByKey("Max",HDRLine,"=")
	
//	Print HDRLine
	
	// Now read in the next line. 
	FReadLine refNum, HDRLine
	AxisValues 	= CleanUpHeaderLine(HDRLine,"Points","(",")")
	AxisNPts 	= str2num(StringFromList(0,AxisValues,","))
	AxisValues 	= RemoveListItem(0, AxisValues, ",")
	
	// Offset absolute values??
//	Print AxisName,AxisUnit,AxisMin,AxisMax,AxisNPts
	
	if ((MakeAxis) && (AxisNPts > 1))
		Make /O/D/N=(AxisNPts) $AxisWaveName /WAVE=Axis
		for (i=0;i<AxisNPts;i+=1)
			Axis[i] 	= str2num(StringFromList(i,AxisValues,","))
		endfor
	endif
	
	// Return the first value, which is a way to return the energy of a single image
//	return str2num(StringFromList(0,AxisValues,","))
End




// *************************************************************
// ****		Image File Loading Routine: P3B
// *************************************************************
Function /T LoadP3BImage(FileName,FileSuffix,FileNumber,UserFlag)
	String FileName, FileSuffix
	Variable FileNumber, UserFlag
	
	NVAR gDimX 	= root:SPHINX:Import:gDimX
	NVAR gDimY 	= root:SPHINX:Import:gDimY
	
	Variable i, dataType, dataLen, data
	Variable pixType, dimX, dimY, dummy
	Variable refNum, numTags, tagLen, singlebyte, endFlag, numBytes
	String tagName, tagtext, imageName
	
//	if (FileNumber >= 0)
//		imageName = "image"+num2str(FileNumber)
//	else
//		imageName = CleanUpName(FileName,0)
//	endif
	
	Open/R/Z=2/P=Path2Image refNum as FileName
	
	ImageName = GetSPHINXImageName(FileName,FileSuffix,FileNumber,UserFlag)
	
	FStatus refNum
	numBytes = V_logEOF
	
	if (numBytes == 0)
		Print " *** zero bytes in", FileName
		Close RefNum
		
//		if ((gDimX > 0) && (gDimY > 0))
//			// Make unsigned 16-bit wave to read in the image data
//			Make/W/U/O/N=(gDimX,gDimY) $imageName=0
//			return imageName
//		else
//			return ""
//		endif
	endif
	
	FBinRead/F=3/B=3/U refNum, numTags
	ReportPosition(refNum,"number of tags ="+num2str(numTags))
	
	for (i=0;i<numTags;i+=1)
		print ""
		
		FBinRead/F=3/B=3/U refNum, tagLen
		ReportPosition(refNum,"length of tag name ="+num2str(tagLen))
		
		tagName = PadString("", tagLen,0)
		FBinRead refNum, tagName
		ReportPosition(refNum,"name of the tag ="+tagName)
		
		FBinRead/F=3/B=3/U refNum, dataType
		ReportPosition(refNum,"data type ="+num2str(dataType))
		
		FBinRead/F=3/B=3/U refNum, dataLen
		ReportPosition(refNum,"data length ="+num2str(dataLen))
		
		strswitch (tagName)
			 case "DIMX":
				FBinRead/F=3/B=3/U refNum, dimX
				ReportPosition(refNum,"DIMX ="+num2str(dimX))
				
				if (gDimX == 0)
					gDimX = dimX
				endif
				break
				
			 case "DIMY":
				FBinRead/F=3/B=3/U refNum, dimY
				ReportPosition(refNum,"DIMY ="+num2str(dimY))
				
				if (gDimY == 0)
					gDimY = dimY
				endif
				break
				
			 case "PIXTYPE":
				FBinRead/F=2/B=3/U refNum, pixType 
				ReportPosition(refNum,"PIXTYPE ="+num2str(pixType))
				break
				
			 case "DATA":
				if (dimX*dimY != dataLen)
					doAlert 0,"dimX*dimY != dataLen"
					Close RefNum
					return imageName
				endif
				
				// Load image data as unsigned 16-bit (two-byte) with Intel/Windows little-endian
				Make/W/U/O/N=(dimX,dimY) $imageName /WAVE=image_p3b
				FBinRead/F=2/B=3/U refNum, image_p3b
				ReportPosition(refNum,"Finished data load")
				
				Close RefNum
				return imageName
				
			default: 
				// find the start of the next tag length
				tagtext = ""
				endFlag = 0
				
				do
					FStatus refNum
					
					 if (V_filePos == numBytes)
					 	endFlag = 1
					 	break
					 else
						FBinRead /F=1/U/B=3 refNum, singlebyte
//						FBinRead refNum, singlebit
						tagtext += num2str(singlebyte)
					 endif
					
				while ((endFlag==0) || numtype(singlebyte) == 0)
//				print tagtext
				
				if (endFlag)
					Close refNum
					return ""
				endif
				
				FStatus refNum
				FSetPos refNum, V_filePos-1
				
//				FBinRead/F=2/B=3/U refNum, dummy
				break
		endswitch
		
	endfor
	
	Close refNum
	return ""
End

Function ReportPosition(refNum,msg)
	Variable refNum
	String msg
	
	Variable ReportFlag = 0
	
	if (ReportFlag)
		FStatus refNum
		print " 		.@",V_filePos,msg
	endif
End

Function /T ReturnImageSuffix(FileType)
	String FileType

	String suffix
	
	strswitch (FileType)
		case "TIFF":
			suffix=".tif"
			break
		case "JPEG":
			suffix=".jpg"
			break
		case "PNG":
			suffix=".png"
			break
		case "BMP":
			suffix=".bmp"
			break
		case "P3B":
			suffix=".p3b"
			break
		case "XIM":
			suffix=".xim"
			break
	endswitch
	
	return suffix
End

// *************************************************************
// ****		If necessary, convert a 16-bit stack to 8-bit
// *************************************************************
Function RunConvertStackTo8Bit(ImageStack,StackName)
	Wave ImageStack
	String StackName
	
	Variable i, NSlices 	= DimSize(ImageStack,2)
	
	// Work out pixel intensity range ... 
	WaveStats /Q/M=1 ImageStack
	// ... in order to pre-set a histogram axis. 
	Make /O/N=(10001) StackHistogram=0
	SetScale /I x, 0, V_max, StackHistogram
	
	for (i=0;i<NSlices;i+=1)
		ImageTransform /P=(i) getPlane ImageStack
		WAVE M_ImagePlane = M_ImagePlane
		
		Histogram /A/B=2 M_ImagePlane, StackHistogram
	endfor
	
	DisplayStackHistogram(StackHistogram,StackName)
	
	KillWaves /Z M_ImagePlane
End

Function ConvertStackTo8Bit(IMin,IMax)
	Variable IMin,IMax
	
	DoAlert /T="Convert stack to 8-bit" 1, "Pixel intensity range is "+num2str(IMin)+"-"+num2str(IMax)+"\rProceed?"
	if (V_flag != 1)
		return 0
	endif
	
	SVAR gStackName 	= root:SPHINX:Import:gStackName
	WAVE ImageStack 	= $("root:SPHINX:Stacks:"+gStackName)
	
	Variable i, NSlices 	= DimSize(ImageStack,2)
	
	for (i=0;i<NSlices;i+=1)
		ImageTransform /P=(i) getPlane ImageStack
		WAVE M_ImagePlane = M_ImagePlane
		
		MatrixOp /NTHR=1/O M_ImagePlane = clip(M_ImagePlane,IMin,IMax)
		
		// Manually expand intensity range to fill the initial bit resolution. 
		M_ImagePlane = (M_ImagePlane-IMin) * (255/(IMax-IMin))
		
		// This is wrong - rescales each image INDIVIDUALLY
//		ImageTransform convert2gray M_ImagePlane
//		WAVE M_Image2Gray = M_Image2Gray
		
		ImageTransform/P=(i)/D=M_ImagePlane setPlane ImageStack
	endfor
	
	Redimension /B/U ImageStack
	
	DisplayStackBrowser(gStackName)
	
	KillWaves /Z M_ImagePlane
	
	Print " *** Converted stack",gStackName," to 8-bit between",IMin,"and",IMax
	
	return 1
End

// *************************************************************
// ****		User interaction to define min and max pixel intensity valyes
// *************************************************************
Function DisplayStackHistogram(StackHistogram,StackName)
	Wave StackHistogram
	String StackName
		
	NVAR gHistCntr 		= root:SPHINX:Import:gHistCntr
	NVAR gHistMax 		= root:SPHINX:Import:gHistMax
	NVAR gHistMaxLoc	= root:SPHINX:Import:gHistMaxLoc
	NVAR gHistCutLow 	= root:SPHINX:Import:gHistCutLow
	NVAR gHistCutHigh 	= root:SPHINX:Import:gHistCutHigh
	
	DoWindow StackHist
	if (!V_flag)
		Display /K=0/W=(292,391,1521,681) StackHistogram as "Select pixel intensity range for conversion to 8-bit"
		DoWindow /C StackHist
		
		// Give some information
		String Instruction = "Use vertical cursors to cut off the edges of the histogram at a fraction of the maximum"
		GroupBox PixelCutOffGroup title=Instruction,pos={60,4},size={483,43},fColor=(39321,1,1)
//		TitleBox PixelCutOffText win=StackHist,frame=5,fSize=12,pos={138,10},title="Use vertical cursors or variable to cut off the edges of the histogram at a fraction of the maximum"
			
		SetDrawLayer UserFront
		SetDrawEnv fname= "Helvetica",fsize= 24,fstyle= 1,textrgb= (48059,48059,48059)
		DrawText 0.28810606843792,0.175565175565176,"Histogram of all pixel intensities in the stack"
		SetDrawEnv fname= "Helvetica",fstyle= 1,textrgb= (30583,30583,30583)
		DrawText 0.749441745063579,0.0803270803270796,"Note: When moving cursor with mouse, you must"
		SetDrawEnv fname= "Helvetica",fstyle= 1,textrgb= (30583,30583,30583)
		DrawText 0.781954926082912,0.170274170274169,"place the cursor symbol onto the red curve"
		
		ModifyGraph mirror=1, log(left)=1
		Label left "Frequency"
		Label bottom "Pixel value (i.e., the full dynamic range of the input image)"
		ShowInfo
		
		ControlBar 50
		Button StackHistButton,pos={597,6}, size={155,36},fSize=13,proc=StackHistButtons,title="Accept"
		
		CheckBox HistLogYCheck,pos={8,10},title="log y",fSize=13,proc=HistLog, value=1
		CheckBox HistLogXCheck,pos={8,27},title="log x",fSize=13,proc=HistLog, value=0
	
		// Threshold values for discarding pixels
		ValDisplay HistMinDisplay,title="Left cut-off",pos={69,26},limits={0,inf,0.001},size={180,17},fsize=11,value=#"root:SPHINX:Import:gHistCutLow"
		ValDisplay HistMaxDisplay,title="Right cut-off",pos={337,26},limits={0,inf,0.001},size={180,17},fsize=11,value=#"root:SPHINX:Import:gHistCutHigh"
		
		// Can't work out how to update the bounds using both a SetVar display and the cursors. 
//		SetVariable HistMinSetVar,title="Left cut-off",pos={69,26},limits={0,inf,0.001},size={180,17},fsize=11,proc=SetHistCutoffs,value= gHistCutLow
//		SetVariable HistMaxSetVar,title="Right cut-off",pos={337,26},limits={0,inf,0.001},size={180,17},fsize=11,proc=SetHistCutoffs,value= gHistCutHigh
		
		// Must put these on before the Hook is created
		Cursor /H=2/S=2/W=StackHist A $NameOfWave(StackHist) 0
		Cursor /H=2/S=2/W=StackHist B $NameOfWave(StackHist) 0
	
		// A hook for when the cursor is moved. 
		SetWindow StackHist, hook(CursorHook)=P3BHistCursorHook
	endif
	
	// Calculate some useful values once. 
	WaveStats /Q/M=1 StackHistogram
	gHistMax 		= V_max
	gHistMaxLoc 	= V_maxLoc
	gHistCntr 		= x2pnt(StackHistogram,gHistMaxLoc)
	
	gHistCutLow 	= (gHistCutLow == 0) ? 1/10 : gHistCutLow
	gHistCutHigh 	= (gHistCutHigh == 0) ? 1/10 : gHistCutHigh
	
	UpdateHistogramCutOffs()

End

Function UpdateHistogramCutOffs()
	
	WAVE StackHist 	= root:SPHINX:Import:StackHistogram
	NVAR gHistCntr 		= root:SPHINX:Import:gHistCntr
	NVAR gHistMax 		= root:SPHINX:Import:gHistMax
	NVAR gHistMaxLoc	= root:SPHINX:Import:gHistMaxLoc
	NVAR gHistCutLow 	= root:SPHINX:Import:gHistCutLow
	NVAR gHistCutHigh 	= root:SPHINX:Import:gHistCutHigh
	
	Variable CutLow, CutHigh, MinStackHist, MaxStackHist
	Variable HardCutOff = 100

// 	Determine the cut-off values from the global variables. 
//	Note: We are plotting the histogram against X pixel values, not point numbers. 

	CutLow 			= gHistCutLow*gHistMax
//	FindLevel /Q/EDGE=2/R=(gHistMaxLoc,0) StackHist, CutLow
	FindLevel /Q/EDGE=1/R=(gHistMaxLoc,0) StackHist, HardCutOff
	MinStackHist 	= V_LevelX
	
	CutHigh 		= gHistCutHigh*gHistMax
//	FindLevel /Q/EDGE=2/R=(gHistMaxLoc,npts) StackHist, CutHigh
	FindLevel /Q/EDGE=2/R=(gHistMaxLoc,rightX(StackHist)) StackHist, HardCutOff
	MaxStackHist 	= V_LevelX
	
	// Update the displayed cursor positions
	Cursor /H=2/S=2/W=StackHist A $NameOfWave(StackHist) MinStackHist
	Cursor /H=2/S=2/W=StackHist B $NameOfWave(StackHist) MaxStackHist
End


// Change the histogram cut-offs by changing the global variables
Function SetHistCutoffs(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	String ctrlName 	= sva.ctrlName
	Variable varNum 	= sva.dval
	Variable event 		= sva.eventCode
	
	if ((event == 2) || (event == 1))
		UpdateHistogramCutOffs()
		return 1
	endif
	
	return 0
End

// Change the histogram cut-offs by moving the cursors
Function P3BHistCursorHook(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 	= H_Struct.winname
	String cursorName 		= H_Struct.cursorName
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	
	WAVE StackHist 	= root:SPHINX:Import:StackHistogram
	NVAR gHistCutLow 	= root:SPHINX:Import:gHistCutLow
	NVAR gHistCutHigh 	= root:SPHINX:Import:gHistCutHigh
	NVAR gHistMax 		= root:SPHINX:Import:gHistMax
	
	Variable CsrMin, CsrMax
	
	if (eventCode == 7)	// cursor moved. 
		
		if (!CsrIsOnPlot("StackHist","A") || (!CsrIsOnPlot("StackHist","B")))
			DoAlert 0, "Please make sure both cursors are on the histogram"
			return 0
		endif
		
		// Read the new position of the cursors into the global variables
		CsrMin = pcsr(A, "StackHist")
		CsrMax = pcsr(B, "StackHist")
		
		gHistCutLow = StackHist[min(CsrMin, CsrMax)]/gHistMax
		gHistCutHigh = StackHist[max(CsrMin, CsrMax)]/gHistMax
		
		ControlUpdate /A
		
		return 1
	endif
	
	if (eventCode == 2) 	// Window kill
		return 1
	endif
End

Function HistLog(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	String ctrlName			= CB_Struct.ctrlName
	Variable checked		= CB_Struct.checked
	if (StrSearch(ctrlName,"Y",0) > -1)
		ModifyGraph /W=StackHist log(left)=(checked)
	else
		ModifyGraph /W=StackHist log(bottom)=(checked)
	endif
End

Function StackHistButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	Variable Proceed, xAValue, xBValue
	
	if (cmpstr(ctrlName,"StackHistButton") == 0)
	
		xAValue 	= xcsr(A,"StackHist")
		xBValue 	= xcsr(B,"StackHist")
		Proceed 	= ConvertStackTo8Bit(min(xAValue,xBValue),max(xAValue,xBValue))
		
		if (Proceed)
			DoWindow /K StackHist
		endif
	endif
End









































Function modload_p3b(folderPath, fileName)
    String folderPath, fileName
    print fileName

//    SVAR folderPath=root:fileIO:folderPath
    Variable refNum
    Open/R/Z=2 refNum as folderPath+fileName
    Variable tagNum, tagLen
    FBinRead/F=3/B=3/U refNum, tagNum
    printf "number of tag: %d\r", tagNum

    Variable i,j,k
    String tagName
    Variable dataType, dataLen, data
    Variable pixType, dimX, dimY
    
//    NVAR dimX = root:IP_consts:dimX
   // NVAR dimY = root:IP_consts:dimY
   
    for (i=0;i<tagNum;i+=1)
        FBinRead/F=3/B=3/U refNum, tagLen
        printf "\r length of tag: %d characters\r", tagLen
        tagName = PadString("", tagLen,0)
        FBinRead refNum, tagName
        print "the name of the tag: " + tagName
        FBinRead/F=3/B=3/U refNum, dataType
        printf "data type is %d, ", dataType
        FBinRead/F=3/B=3/U refNum, dataLen
        
        printf "data length is %d\r", dataLen
        strswitch (tagName)
            case "DIMX":
                FBinRead/F=3/B=3/U refNum, dimX
                printf "dimension in x: %d\r", dimX
                break
            case "DIMY":
                FBinRead/F=3/B=3/U refNum, dimY
                printf "dimension in y: %d\r", dimY
                break
            case "PIXTYPE":
                FBinRead/F=2/B=3/U refNum, pixType 
                printf "pixel type for the image: %d\r", pixType
                break
            case "DATA":
                if (dimX*dimY != dataLen)
		    doAlert 0,"dimX*dimY != dataLen"
                endif
                Make/W/U/O/N=(dimX,dimY) image_p3b
                FBinRead/F=2/B=3/U refNum, image_p3b
                Rename image_p3b $fileName
                Close refNum
                return 0 // when data is load, return
                break
            default:
                break
        endswitch
    endfor

    return 0
End


// Make KeyWord list of useful values. 
Function /S ParseXIMHeader()
	
	
	
//	ReturnKeyWordLineInOpenfile(refNum,keyword)
	
End



// *************************************************************
// ****		IMPORTING IMAGES AND STACKS
// *************************************************************
Function /T ReturnTIFFParameters(TagFolderName,ParamName)
	String TagFolderName,ParamName
		
	WAVE /T TagWave		= $(TagFolderName+"T_Tags")
	
	Variable KeyCol = 1, ValueCol = 4
	Variable i, NKeys = Dimsize(TagWave,0)
	String KeyStr, ValueStr
	
	if (WaveExists(TagWave) == 1)
		for (i=0;i<NKeys;i+=1)
			KeyStr			= TagWave[i][KeyCol]
			
			if (cmpstr(KeyStr,ParamName) == 0)
				ValueStr		= TagWave[i][ValueCol]
				return ValueStr
			endif
		endfor
	endif
		
	return ""
End


function LoadTIFFImageTag()
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S root:TIFFs
		KillDataFolder /Z Tag0
		
		// Use /C flag to load only the first image if it's a stack
		ImageLoad /C=1/T=TIFF/RTIO 
		
	SetDataFolder $OldDf
End

function LoadTIFFImageTags(TIFFPathName,TIFFFileName)
	String TIFFPathName,TIFFFileName
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S root:TIFFs
		KillDataFolder /Z Tag0
		
		// Use /C flag to load only the first image if it's a stack
		ImageLoad /Q/P=$TIFFPathName/C=1/T=TIFF/RTIO TIFFFileName
		
	SetDataFolder $OldDf
End

Function ImportImagesToStack()

	NewDataFolder /O/S root:SPHINX
	NewDataFolder /O/S root:SPHINX:Stacks
	KillWaves /A
	
	MakeVariableIfNeeded("imageBitInfo",255)
	MakeStringIfNeeded("gFileType","p3b")
	MakeStringIfNeeded("gBitInfo","8bit")
	
	SVAR gFileType 	= gFileType
	SVAR gBitInfo 	= gBitInfo
	
	String FileType = gFileType
	Prompt FileType, "Type of file", popup, "TIFF;JPEG;PNG;P3B;XIM;"
	String BitInfo = gBitInfo
	Prompt BitInfo, "Image depth", popup, "8bit;16bit;"
	DoPrompt "Importing stack images",FileType, BitInfo
	if (V_flag)
		return 0
	endif
	
	gFileType 	= FileType
	gBitInfo 	= BitInfo
	
	ImagesToStack(fileType,BitInfo)
End

Function ImagesToStack(fileType,BitInfo)
	String fileType,BitInfo
	
	String StackFolder 	= "root:SPHINX:Stacks"
	NVAR gImageBitInfo 	= $(StackFolder + ":gImageBitInfo")
	NVAR gNumImages 	= $(StackFolder + ":gNumImages")

	String suffix="????"
	strswitch(fileType)
	case "TIFF":
		suffix=".tif"
		break
	case "JPEG":
		suffix=".jpg"
		break
	case "PNG":
		suffix=".png"
		break
	case "BMP":
		suffix=".bmp"
		break
	case "P3B":
		suffix=".p3b"
		break
	case "XIM":
		suffix=".xim"
		break
	endswitch
	
	NewPath /Q/M="Select path to images" /O ImagesPath
	if (V_Flag!=0)
		Abort
	endif 
	
	String listAllFiles=indexedfile(ImagesPath,-1,suffix)
	if(ItemsInList(listAllFiles)<=0)
		DoAlert 0,"The folder does not list file of the correct type"
		return 0
	endif
	
    String fileName, LoadedName, waveStr, myStr
    
    if (cmpstr(BitInfo,"8bit") == 0)
        gImageBitInfo = 255
    elseif (cmpstr(BitInfo,"16bit") == 0)
        gImageBitInfo = 65535
    endif

    String firstWave, imageLoadName, baseName = "sglimage"
    
    Variable i=0
    gNumImages = 0
	
	do
		fileName=StringFromList(i,listAllFiles)
		if(strlen(fileName)<=0)
			break
		endif
		
		strswitch(fileType)
		case "P3B":
//			LoadP3BImage(fileName)
			imageLoadName = fileName
			break;
		case "XIM":
//			loadXIMImage(folderPath+fileName)
			imageLoadName = fileName
			break
		default: 
			ImageLoad/O/Q/P=ImagesPath/T=$fileType fileName
			imageLoadName = S_waveNames
			break
		endswitch
		
		waveStr=StringFromList(0,imageLoadName)
		sprintf myStr,"%s%04d",baseName,i
		Rename $waveStr,$myStr
		if(i==0)
			firstWave=myStr
		endif
			
		gNumImages+=1
		i+=1
	while(1)
	
	abort
	
	ImageTransform /K stackImages $firstWave      
	
	String StackName
	StackName 	= StripSpacesAndSuffix(firstWave,".")
	StackName 	= CleanUpDataName(StackName)
	Prompt StackName, "Name of imported stack"
	DoPrompt "Please avoid Igor-unfriendly characters!", StackName
	if (V_flag)
		return 0
	endif
	StackName 	= CleanUpDataName(StackName)
	
	// Rename the stack
	if (WaveExists($StackName) == 1)
		DoWindow /K StackBrowser
		RemoveDataFromAllWindows(StackName)
		KillWaves $StackName
	endif
	LoadedName = StringFromList(0,S_Filename)
	Rename $LoadedName, $StackName
	
	Print " *** Loaded a SPHINX stack: "+StackName
	
	    
End




//Function /T LoadXIMHeader(ImageName,FileName,HdrName)
//	String ImageName, FileName, HdrName
//	
//	NVAR gXAxisMin 	= root:SPHINX:Import:gXAxisMin
//	NVAR gXAxisMax 	= root:SPHINX:Import:gXAxisMax
//	SVAR gXAxisUnit 	= root:SPHINX:Import:gXAxisUnit
//	
//	NVAR gYAxisMin 	= root:SPHINX:Import:gYAxisMin
//	NVAR gYAxisMax 	= root:SPHINX:Import:gYAxisMax
//	SVAR gYAxisUnit 	= root:SPHINX:Import:gYAxisUnit
//	
//	NVAR gEAxisMin 	= root:SPHINX:Import:gEAxisMin
//	NVAR gEAxisMax 	= root:SPHINX:Import:gEAxisMax
//	SVAR gEAxisUnit 	= root:SPHINX:Import:gEAxisUnit
//	
//	Variable refNum, AxisMin,AxisMax,AxisNPts
//	String HDRLine, AxisName, AxisUnit
//	
//	Open /Z/R/P=Path2Image refNum as HdrName
//	if (V_flag != 0)
//		Print " *** Problem loading header file!"
//		return ""
//	endif
//	
//	do
//		FReadLine refNum, HDRLine
//		if (strlen(HDRLine) == 0)
//			break
//		endif
//		
//		// Find the list of x-values
//		if (StrSearch(HDRLine,"PAxis",0) > -1)
//			AxisFromXIMHeaderLines(CleanUpHeaderLine(HDRLine,"PAxis","{","}"), ImageName+"_p",AxisName,AxisUnit,AxisMin,AxisMax,AxisNPts,0,refNum)
//			SetScale /I x, AxisMin, AxisMax, AxisUnit, $ImageName 
////			gDimX 	= AxisNPts
//		endif
//		
//		// Find the list of y-values
//		if (StrSearch(HDRLine,"QAxis",0) > -1)
//			AxisFromXIMHeaderLines(CleanUpHeaderLine(HDRLine,"QAxis","{","}"), ImageName+"_q",AxisName,AxisUnit,AxisMin,AxisMax,AxisNPts,0,refNum)
//			SetScale /I y, AxisMin, AxisMax, AxisUnit, $ImageName 
////			gDimY 	= AxisNPts
//		endif
//		
//		// Find the list of energy-values
//		if (StrSearch(HDRLine,"StackAxis",0) > -1)
//			AxisFromXIMHeaderLines(CleanUpHeaderLine(HDRLine,"StackAxis","{","}"), ImageName+"_axis",AxisName,AxisUnit,AxisMin,AxisMax,AxisNPts,0,refNum)
//			Note /K $ImageName, AxisName+" = "+num2str(AxisMin)+" "+AxisUnit
//		endif
//		
//	while(1)
//	
//	Close refNum
//End