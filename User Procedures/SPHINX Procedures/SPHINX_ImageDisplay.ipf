#pragma rtGlobals=1		// Use modern global access method.

// *************************************************************
// ****		Deleting Images from Memory
// *************************************************************

Function RemoveImages()
	
	InitializeStackBrowser()
	
	MakeStringIfNeeded("root:SPHINX:gImageName","")
	MakeStringIfNeeded("root:SPHINX:gImage2Name","")
	
	SVAR gImageName 	= root:SPHINX:gImageName
	SVAR gImage2Name 	= root:SPHINX:gImage2Name
	
	String ImageFolder 	= "root:SPHINX:Stacks"
	String ImageName 	= gImageName
	String Image2Name 	= gImage2Name
	
	String ImageList = ReturnImageList(ImageFolder,0)
	Prompt ImageName, "List of images", popup, ImageList
	Prompt Image2Name, "Second for multiple deletion", popup, "_none_;"+ImageList
	DoPrompt "Select image(s) to remove from memory", ImageName,Image2Name
	if (V_flag)
		return 0
	endif
	
	gImageName 	= ImageName
	gImage2Name 	= Image2Name
	
	Variable i, IStart, IStop
	
	if (cmpstr("_none_",Image2Name) == 0)
		KillSPHINXImage(ImageName)
	else
		IStart 	= WhichListItem(gImageName,ImageList)
		IStop 	= WhichListItem(gImage2Name,ImageList)
		for (i=IStart;i<=IStop;i+=1)
			ImageName = StringFromList(i,ImageList)
			KillSPHINXImage(ImageName)
		endfor
	endif
End

Function KillSPHINXImage(ImageName)
	String ImageName

	Variable i
	String PanelNameList = ImagePanelList("","StackImage",ImageName,0)
	
	for (i=0;i<ItemsInList(PanelNameList);i+=1)
		Dowindow /K $(StringFromList(i,PanelNameList))
	endfor
	
	KillWaves /Z $("root:SPHINX:Stacks:"+ImageName)
	
End

// *************************************************************
// ****		Image Display Management
// *************************************************************

Function DuplicateImage()
	
	InitializeStackBrowser()
	SetDataFolder root:SPHINX:Stacks:
	
		SVAR gStackName 	= root:SPHINX:Browser:gStackName
		String NewName 	= StrVarOrDefault("root:SPHINX:gNewName",gStackName)
		String ImageName 	= StrVarOrDefault("root:SPHINX:gImageName","")
		
		String ImageList = ReturnImageList("root:SPHINX:Stacks",0)
		Prompt ImageName, "List of images", popup, ImageList
		Prompt NewName, "New name"
		DoPrompt "Select image to duplicate", ImageName, NewName
		if (V_flag)
			return 0
		endif
		String /G root:SPHINX:gImageName 	= ImageName
		String /G root:SPHINX:gNewName 		= NewName
	
		NewName = CleanUpName(NewName,0)
		WAVE Image 	= $("root:SPHINX:Stacks:"+ImageName)
		Duplicate /O Image, $NewName/WAVE=NewImg
		NewImg *= 1000
		
		
		DisplaySPHINXImage(NewName)
	SetDataFolder root:
End

Function DisplayImages()
	
	InitializeStackBrowser()
	
	MakeStringIfNeeded("root:SPHINX:gImageName","")
	MakeStringIfNeeded("root:SPHINX:gImage2Name","")
	
	SVAR gImageName 	= root:SPHINX:gImageName
	SVAR gImage2Name 	= root:SPHINX:gImage2Name
	
	String ImageFolder 	= "root:SPHINX:Stacks"
	String ImageName 	= gImageName
	String Image2Name 	= gImage2Name
	
	String ImageList = ReturnImageList(ImageFolder,0)
	
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	ImageList 	= ReOrderImageList(gStackName,"average",ImageList)
	
	
	Prompt ImageName, "List of images", popup, ImageList
	Prompt Image2Name, "Second for multiple display", popup, "_none_;"+ImageList
	DoPrompt "Select image(s) to view", ImageName,Image2Name
	if (V_flag)
		return 0
	endif
	
	gImageName 	= ImageName
	gImage2Name 	= Image2Name
	
	Variable i, IStart, IStop
	
	if (cmpstr("_none_",Image2Name) == 0)
		DisplaySPHINXImage(ImageName)
	else
		IStart 	= WhichListItem(gImageName,ImageList)
		IStop 	= WhichListItem(gImage2Name,ImageList)
		for (i=IStart;i<=IStop;i+=1)
			ImageName = StringFromList(i,ImageList)
			DisplaySPHINXImage(ImageName)
		endfor
	endif
End

Function /S ReOrderImageList(StackName,ImageSuffix,ImageList)
	String StackName,ImageSuffix,ImageList
	
	String TargetImage 	= StackName + "_" + ImageSuffix
	Variable TargetNum 	= WhichListItem(TargetImage,ImageList)
	
	if (TargetNum>-1)
		ImageList 	= RemoveListItem(TargetNum,ImageList)
		ImageList 	= AddListItem(TargetImage,ImageList)
	endif 
	
	return ImageList
End

Function CloseAllImages()
	
	Variable i, NPanels
	String PanelName, DestWindow, PanelNameList
	
	PanelNameList = ImagePanelList("","StackImage","",0)
	NPanels = ItemsInList(PanelNameList)
	
	for (i=0;i<NPanels;i+=1)
		PanelName 		= StringFromList(i,PanelNameList)
		
		if (cmpstr("StackBrowser",PanelName) == 0)
		elseif (cmpstr("ReferencePanel",PanelName) == 0)
		else
			DoWindow /K $PanelName
		endif
	endfor
End

Function DisplaySPHINXImage(ImageName)
	String ImageName
	
	Variable NumX, NumY, SVDNum
	String ColorTable, PanelName

	WAVE Image 	= $("root:SPHINX:Stacks:"+ImageName)
	NumX = Dimsize(Image,0)
	NumY = Dimsize(Image,1)
	
	if (StrSearch(ImageName,"Map_X2",0) > -1)
		ColorTable 	= "Gold"
	else
		SVDNum 	= ReturnLastNumber(ImageName)
		ColorTable 	= ReturnColorTable(SVDNum)
	endif
	
	PanelName = ImageDisplayPanel(Image,ColorTable,NameOfWave(Image),NameOfWave(Image),NumX,NumY)
	
	ApplyStackContrast(PanelName)
End

Function /T ReturnColorTable(i)
	Variable i
	String ColorTable
	
	switch (i)
		case 0:
			ColorTable = "Red"
			break
		case 1:
			ColorTable = "Green"
			break
		case 2:
			ColorTable = "Blue"
			break
		default:
			ColorTable = "Grays"
			break
	endswitch
	
	return ColorTable
End

Function MakeAveragedStack(SPHINXStack,NumX,NumY)
	Wave SPHINXStack
	Variable NumX,NumY

	// Default view is the average of all the stack slices
	Make /O/D/N=(NumX,NumY) $("root:SPHINX:Stacks:"+NameOfWave(SPHINXStack)+"_average") /WAVE=averageStack
	
	ImageTransform averageImage SPHINXStack
	WAVE M_AveImage
	
	averageStack = M_AveImage
	
	KillWaves /Z M_AveImage
	
	// We'll also create a wave for display purposes
	Make /O/D/N=(NumX,NumY) $("root:SPHINX:Stacks:"+NameOfWave(SPHINXStack)+"_av") /WAVE=avStack
	avStack = averageStack
	
	// Not sure why, but this messes up cursor positioning!!
//	TransferSPHINXImageScale(SPHINXStack,averageStack)
//	TransferSPHINXImageScale(averageStack,avStack)
End

// *************************************************************
// ****		Exporting a Stack
// *************************************************************
Function SaveStack()

	SVAR gStackName = root:SPHINX:Import:gStackName
	
	String ChosenStack = ChooseStack("Choose a stack to export as TIFF",gStackName,0)
	if (strlen(ChosenStack) == 0)
		return 0
	endif
	
	WAVE ImageStack 	= $("root:SPHINX:Stacks:"+gStackName)
	ExportStack(ImageStack,ChosenStack)
	
End

Function ExportStack(ImageStack,FullSaveName)
	Wave ImageStack
	String FullSaveName
	
	String ExportName = FullSaveName
	Prompt ExportName, "Name for saving"
	DoPrompt "Stack export", ExportName
	if (V_flag)
		return 0
	endif

	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Stacks
	
		String axisName = "root:SPHINX:Stacks:"+NameOfWave(ImageStack)+"_axis"
		
		if (WaveExists($axisName))
			ImageSave /S/T="tiff" imageStack as FullSaveName
			Save /J $axisName
			
			Print " *** Exported the stack as",FullSaveName," and the energy axis"
		else
			DoAlert 1, "Cannot find axis for "+FullSaveName+". Export anyway?"
			if (V_flag)
				ImageSave /S/T="tiff" imageStack as FullSaveName
				Print " *** Exported the stack as",FullSaveName,"WITHOUT energy axis."
			endif
		endif
		
	SetDataFolder $(OldDf)
End

// *************************************************************
// ****		Exporting Images
// *************************************************************

// *!*!*!*! Modified August 2021
Function ExportImage(Image,Interactive,ExportLevels)
	Wave Image
	Variable Interactive
	String ExportLevels
	
	String PanelName, FullPath="", Msg = ""
	
	if (Interactive == 0)
		PathInfo ExportPath
		if (V_flag)
			FullPath = S_path
		endif
	endif
	String FullSaveName = FullPath+NameOfWave(Image)+".tif"
	
	if (DimSize(Image,2) > 0)
		DoAlert 0, "Please use 'Save Stack' to export a stack"
		return 0
	endif
	
	Duplicate /FREE Image, ExportImage
	ExportImage[][] = (numtype(Image[p][q]) == 0) ? Image[p][q] : NaN		// Get rid of infinite values. 
	
	if (cmpstr(ExportLevels,"displayed") == 0)
		NVAR gIMin = $("root:SPHINX:"+NameOfWave(Image)+":gImageMin")
		NVAR gIMax = $("root:SPHINX:"+NameOfWave(Image)+":gImageMax")
		
		if (NVAR_Exists(gIMin) && NVAR_Exists(gIMax))
			Msg = " - cropping min and max values before export"
			ExportImage[][] = min(gIMax,ExportImage[p][q])
			ExportImage[][] = max(gIMin,ExportImage[p][q])
		endif
	endif
	
	Variable ImageType 	= NumberByKey("NUMTYPE", WaveInfo(Image, 0))
	
		if ((ImageType == 2) || (ImageType == 4))
		
			// Singe or double precision, save as single precision tif (/F flag)
			ImageSave /U/DS=16/T="tiff" ExportImage as FullSaveName
			Print " *** Saved image as 16-bit TIF to file: ",FullSaveName,Msg
		

		elseif (ImageType == 72)
			// Unsigned 8-bit data (64 + 8)
			// Save as 8-bit tif with no renormalization of gray levels. 
			ImageSave /D=8/U/T="tiff" ExportImage as FullSaveName
			Print " *** Saved image as 8-bit gray scale TIF to file: ",FullSaveName,Msg
		else
			ImageSave /T="tiff" ExportImage as FullSaveName
			Print " *** Saved image as TIF to file: ",FullSaveName
			Print " 		 CAUTION: The image gray levels have been renormalized upon saving. "
		endif
	
	return V_flag
End

Function ExportImages()
	
	InitializeStackBrowser()
	
	MakeStringIfNeeded("root:SPHINX:gImageName","")
	MakeStringIfNeeded("root:SPHINX:gImage2Name","")
	MakeStringIfNeeded("root:SPHINX:gExportLevels","default")
	
	SVAR gImageName 	= root:SPHINX:gImageName
	SVAR gImage2Name 	= root:SPHINX:gImage2Name
	SVAR gExportLevels 	= root:SPHINX:gExportLevels
	
	String ImageFolder 	= "root:SPHINX:Stacks"
	String ImageName 		= gImageName
	String Image2Name 	= gImage2Name
	String ExportLevels 	= gExportLevels
	
	String ImageList = ReturnImageList(ImageFolder,0)
	Prompt ImageName, "List of images", popup, ImageList
	Prompt Image2Name, "Second for multiple export", popup, "_none_;"+ImageList
	Prompt ImageName, "List of images", popup, ImageList
	Prompt ExportLevels, "Exported intensity range", popup, "default;displayed;"
	DoPrompt "Select image(s) export as TIFF", ImageName, Image2Name, ExportLevels
	if (V_flag)
		return 0
	endif
	
	gImageName 	= ImageName
	gImage2Name 	= Image2Name
	gExportLevels 	= ExportLevels
	
	Variable i, IStart, IStop, Success
	
	if (cmpstr("_none_",Image2Name) == 0)
		WAVE Image 	= $("root:SPHINX:Stacks:"+ImageName)
		ExportImage(Image,1,ExportLevels)
	else
		IStart 	= WhichListItem(gImageName,ImageList)
		IStop 	= WhichListItem(gImage2Name,ImageList)
		for (i=IStart;i<=IStop;i+=1)
			
			if (i==iStart)
				NewPath /Q/O/M="Location for saving images" ExportPath
			endif
			
			ImageName = StringFromList(i,ImageList)
			WAVE Image 	= $("root:SPHINX:Stacks:"+ImageName)
			Success = ExportImage(Image,0,ExportLevels)
			
			if (!Success)
				return 0
			endif
		endfor
	endif
End

// *************************************************************
// ****		A Common Image Display Panel with Controls
// *************************************************************
Function /S ImageDisplayPanel(Image,ColorTable,Title,Folder,NumX,NumY)
	Wave Image
	String ColorTable,Title,Folder
	Variable NumX,NumY
	
	String PanelFolder 	= "root:SPHINX:"+Folder
	String PanelName 	= "Stack"+Folder
	String StackName	= NameOfWave(Image)
	
	String Description, OldDf = GetDataFolder(1)
	NewDataFolder /O/S $PanelFolder
		
		Duplicate /O Image, BlankImage
		BlankImage = 125
		
		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		Dowindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)
		
		Display/W=(7,111,419,441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab= {1,200,Yellow,0}
		
		AppendImage Image
		ModifyImage $(NameOfWave(Image)) ctab= {*,*,$ColorTable,1}
		ModifyGraph mirror=2
		RenameWindow #, StackImage
		
		Description = note(Image)
		
		if (strlen(Description) > 0)
			TitleBox ImageDescription win=$PanelName,frame=5,fSize=12,pos={138,10},title=Description
		endif
		
		AppendContrastControls(StackName,"root:SPHINX:Stacks",PanelFolder,NumX,NumY)
		
		ApplyStackContrast(PanelName)
		
		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450,0)
	
		// Permit saving for images or stacks
		Button ImageSaveButton,pos={5,83}, size={55,24},fSize=13,proc=ImagePanelButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"
		
		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(Image)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(Image,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
		
	SetDataFolder $(OldDf)
	
	return PanelName
End



// *************************************************************
// ****		A Common Image Display Panel for RGB images
// *************************************************************
Function /S RGBDisplayPanel(RGBImage,Title,Folder,NumX,NumY,[PosnStr])
	Wave RGBImage
	String Title,Folder, PosnStr
	Variable NumX,NumY
	
	String PanelName 	= "RGB_"+Folder
	String PanelFolder 	= "root:SPHINX:"+PanelName
	String RGBName	= NameOfWave(RGBImage)
	
	Variable px1=6, px2=440, py1=44, py2=520, swx1=7, swx2=419, swy1=111, swy2=441
	if (ParamIsDefault(PosnStr)==0)
		px1 = NumberByKey("px1", PosnStr, "=")
		px2 = NumberByKey("px2", PosnStr, "=")
		py1 = NumberByKey("py1", PosnStr, "=")
		py2 = NumberByKey("py2", PosnStr, "=")
		swx1 = NumberByKey("swx1", PosnStr, "=")
		swx2 = NumberByKey("swx2", PosnStr, "=")
		swy1 = NumberByKey("swy1", PosnStr, "=")
		swy2 = NumberByKey("swy2", PosnStr, "=")
	endif
	
	String Description, OldDf = GetDataFolder(1)
	NewDataFolder /O/S $PanelFolder
		
		Duplicate /O RGBImage, BlankImage
		BlankImage = 125
		
		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		Dowindow /C $PanelName
		CheckWindowPosition(PanelName,px1,py1,px2,py2)
//		CheckWindowPosition(PanelName,6,44,440,520)
		
//		Display/W=(7,111,419,441)/HOST=#
		Display/W=(swx1,swy1,swx2,swy2)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab= {1,200,Yellow,0}
		
		AppendImage RGBImage
		ModifyGraph mirror=2
		RenameWindow #, RGBImage
		
//		Description = note(Image)
//		if (strlen(Description) > 0)
//			TitleBox ImageDescription win=$PanelName,frame=5,fSize=12,pos={138,10},title=Description
//		endif
//		AppendContrastControls(RGBName,"root:SPHINX:Stacks",PanelFolder,NumX,NumY)	
//		ApplyStackContrast(PanelName)
		
		// this appends ImageCursorHooks
		AppendCursors(RGBName,PanelName,"RGBImage",PanelFolder,NumX,NumY,450,1)
//		AppendCursors(RGBName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
	
		// Permit saving for images or stacks
		Button ImageCopyButton,pos={5,53}, size={55,24},fSize=13,proc=ImagePanelButtons,title="Copy"
		Button ImageSaveButton,pos={5,83}, size={55,24},fSize=13,proc=ImagePanelButtons,title="Export"
		Button TransferCrsButton,pos={220,38}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"
		
		// Hooks
		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#RGBImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGBImage)+";"
		SetWindow $PanelName,userdata+= "ImageType="+"RGB;"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGBImage,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
		
	SetDataFolder $(OldDf)
	
	return PanelName
End

// *************************************************************
// ****		Common routines to get Image information from PanelName
// *************************************************************

Function /T PanelSourceInformation(PanelName,SourceName,SourceFolder)
	String PanelName, &SourceName, &SourceFolder
	
	SourceName 	= StringByKey("SourceName",GetUserData(PanelName, "", ""),"=",";")
	SourceFolder 	= StringByKey("SourceFolder",GetUserData(PanelName, "", ""),"=",";")
	
	return ""
End

Function /T PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	String PanelName, &PanelFolder, &ImageName, &ImageFolder, &subWName, &ImageSubW
	
//	PanelFolder 	= "root:SPECTRA:Plotting:" + panelName
	PanelFolder 	= StringByKey("PanelFolder",GetUserData(PanelName, "", ""),"=",";")
	ImageName 		= StringByKey("ImageName",GetUserData(PanelName, "", ""),"=",";")
	ImageFolder 	= StringByKey("ImageFolder",GetUserData(PanelName, "", ""),"=",";")
	subWName 		= StringByKey("subWName",GetUserData(PanelName, "", ""),"=",";")
	
	// Argh! Incompatibility in EEM vs SPHINX routines. 
	// In EEMS, subWName is just the name of the subwindow. 
	// In SPHINX, subWName is already the PanelName + subwindow. 
	
	ImageSubW 		= PanelName + "#" + subWName
	GetWindow /Z $ImageSubW exterior
	if (V_flag != 0)
		ImageSubW 	= subWName
	endif
	
	return ""
End

Function /T ImageAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder)
	String PanelName, &Axis1Name, &Axis1Folder, &Axis2Name, &Axis2Folder
	
	Axis1Name 		= StringByKey("Axis1Name",GetUserData(PanelName, "", ""),"=",";")
	Axis1Folder 	= StringByKey("Axis1Folder",GetUserData(PanelName, "", ""),"=",";")
	Axis2Name 		= StringByKey("Axis2Name",GetUserData(PanelName, "", ""),"=",";")
	Axis2Folder 	= StringByKey("Axis2Folder",GetUserData(PanelName, "", ""),"=",";")
	
	return ""
End

Function /T CountourAxesInfo(PanelName,Axis1Name,Axis1Folder,Axis2Name,Axis2Folder,HorzName,VertName)
	String PanelName, &Axis1Name, &Axis1Folder, &Axis2Name, &Axis2Folder, &HorzName, &VertName
	
	Axis1Name 		= StringByKey("CtrAxis1Name",GetUserData(PanelName, "", ""),"=",";")
	Axis1Folder 	= StringByKey("CtrAxis1Folder",GetUserData(PanelName, "", ""),"=",";")
	Axis2Name 		= StringByKey("CtrAxis2Name",GetUserData(PanelName, "", ""),"=",";")
	Axis2Folder 	= StringByKey("CtrAxis2Folder",GetUserData(PanelName, "", ""),"=",";")
	HorzName 		= StringByKey("HorzName",GetUserData(PanelName, "", ""),"=",";")
	VertName 		= StringByKey("VertName",GetUserData(PanelName, "", ""),"=",";")
	
	return ""
End

Function /T PanelAnnotationInfo(PanelName,ColorScaleName)
	String PanelName, &ColorScaleName
	
	ColorScaleName 	= StringByKey("Axis1Name",GetUserData(ColorScaleName, "", ""),"=",";")
	
	return ""
End

// *************************************************************
// ****		Append some common controls for IMAGE SETTINGS
// *************************************************************

Function NewAppendContrastControls(PanelName)
	String PanelName
	
	String PanelFolder,ImageName,ImageFolder,subWName, ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	
	Variable wNumType, ImageMin, ImageMax, LevelIncrement, DisplayMin, DisplayMax
	
	GroupBox ContrastGroup title="Image contrast",pos={5,0},size={130,81},fColor=(39321,1,1)
	Button ImageHistButton,pos={84,13}, size={46,18},fSize=13,proc=ImagePanelButtons,title="Levels"
	
	MakeVariableIfNeeded(PanelFolder+":gInvertFlag",0) // This means BLACK = MORE
	CheckBox InvertContrastCheck,pos={13,15},size={114,17},title="Invert",fSize=12,proc=InvertStackContrast,variable= $(PanelFolder+":gInvertFlag")
	
	WAVE Image 		= $(ParseFilePath(2,ImageFolder,":",0,0)+ImageName)
	DefaultLevels(PanelFolder,Image,ImageMin, ImageMax, DisplayMin, DisplayMax)
	
	Variable /G gImageMin 	= ImageMin
	Variable /G gImageMax 	= ImageMax
	
	LevelIncrement 	= (ImageMax - ImageMin)/101
	
	SetVariable ImageMinSetVar,title="min",pos={12,36},limits={-Inf,Inf,LevelIncrement},size={120,17},fsize=12,proc=StackContrast,value=$(PanelFolder+":gImageMin")
	SetVariable ImageMaxSetVar,title="max",pos={9,58},limits={-Inf,Inf,LevelIncrement},size={123,17},fsize=12,proc=StackContrast,value=$(PanelFolder+":gImageMax")
	
	String DefaultTable = "Grays"
	if (StrSearch(ImageName,"Map_x2",0) > -1)
		DefaultTable = "Gold"
	endif
	MakeStringIfNeeded(PanelFolder+":gColorTable",DefaultTable)
End

Function AppendContrastControls(StackName,StackFolder,PanelFolder,NumX,NumY)
	String StackName,StackFolder,PanelFolder
	Variable NumX,NumY
	
	Variable wNumType, ImageMin, ImageMax, LevelIncrement, DisplayMin, DisplayMax
	
	GroupBox ContrastGroup title="Image contrast",pos={5,0},size={130,81},fColor=(39321,1,1)
	Button ImageHistButton,pos={84,13}, size={46,18},fSize=13,proc=ImagePanelButtons,title="Levels"
	
	MakeVariableIfNeeded(PanelFolder+":gInvertFlag",1) // This means BLACK = MORE
	CheckBox InvertContrastCheck,pos={13,15},size={114,17},title="Invert",fSize=12,proc=InvertStackContrast,variable= $(PanelFolder+":gInvertFlag")
	
	WAVE Image 		= $(ParseFilePath(2,StackFolder,":",0,0)+StackName)
	NVAR gImageMin 	= $(PanelFolder+":gImageMin")
	NVAR gImageMax 	= $(PanelFolder+":gImageMax")
		
	// Find default values for min and max levels. 
	if (!NVAR_Exists(gImageMin) || !NVAR_Exists(gImageMax))
		DefaultLevels(PanelFolder,Image,ImageMin, ImageMax, DisplayMin, DisplayMax)
		MakeVariableIfNeeded(PanelFolder+":gImageMin",ImageMin)
		MakeVariableIfNeeded(PanelFolder+":gImageMax",ImageMax)
	endif
	
	ImageMin = gImageMin
	ImageMax = gImageMax
	LevelIncrement 	= (ImageMax - ImageMin)/101
	
	SetVariable ImageMinSetVar,title="min",pos={12,36},limits={-Inf,Inf,LevelIncrement},size={120,17},fsize=12,proc=StackContrast,value=$(PanelFolder+":gImageMin")
	SetVariable ImageMaxSetVar,title="max",pos={9,58},limits={-Inf,Inf,LevelIncrement},size={123,17},fsize=12,proc=StackContrast,value=$(PanelFolder+":gImageMax")
	
//	MakeVariableIfNeeded(PanelFolder+":gHistAxisMin",gImageMin)
//	MakeVariableIfNeeded(PanelFolder+":gHistAxisMax",gImageMax)
	
	String DefaultTable = "Grays"
	if (StrSearch(StackName,"Map_x2",0) > -1)
		DefaultTable = "Gold"
	endif
	MakeStringIfNeeded(PanelFolder+":gColorTable",DefaultTable)
	// find me
	MakeStringIfNeeded(PanelFolder+":gColorTable",DefaultTable)
End

// Evalute the image and estimate minimum and maximum intensity levels for display
Function DefaultLevels(PanelFolder,Image,LevelMin, LevelMax,DisplayMin, DisplayMax)
	String PanelFolder
	Wave Image
	Variable &LevelMin, &LevelMax, &DisplayMin, &DisplayMax
	
	LevelMin 	= 0
	LevelMax 	= LevelOverrides(NameOfWave(Image))
	
	if (LevelMax > -1)
		DisplayMin 	= 0
		DisplayMax = LevelMax
		return 1
	endif
	
	Variable NHVals, HistMax, MaxPLoc
	
	ImageHistogram /I Image
	WAVE W_ImageHist
	
	// Find the histogram maximum
	WaveStats /M=1/Q W_ImageHist
	MaxPLoc 	= x2pnt(W_ImageHist,V_maxloc)
	DeletePoints MaxPLoc, 1, W_ImageHist
	
	WaveStats /M=1/Q W_ImageHist
	HistMax 	= V_max
	NHVals 		= V_npnts
	
	FindLevel /Q/R=[0,NHVals-1] W_ImageHist, HistMax/100
	DisplayMin 		= V_LevelX
	
	FindLevel /Q/R=[NHVals-1,0] W_ImageHist, HistMax/100
	DisplayMax 	= V_LevelX
	
	LevelMin 	= pnt2x(W_ImageHist,0)
	LevelMax 	= pnt2x(W_ImageHist,NHVals-1)
End

Function LevelOverrides(ImageName)
	String ImageName

	if (StrSearch(ImageName,"_pMap_",0) > -1)
		if (StrSearch(ImageName,"_sc_BE",0) > -1)
			// A brghtness-enhanced scaled proportional map, should be displayed from 0 - 255
			return 255
		elseif (StrSearch(ImageName,"_sc",0) > -1)
			// A scaled proportional map, should be displayed from 0 - 255
			return 255
		else
			// A proportional map, should be displayed from 0 - 1
			return 1
		endif
	endif

	return -1
End

Function InvertStackContrast(ctrlName,checked) : CheckBoxControl 
	String ctrlName 
	Variable checked 
	
	String PlotName 		= WinName(0,65)
	ApplyStackContrast(PlotName)
End

Function StackContrast(ctrlName,varNum,varStr,varName) : SetVariableControl 
	String ctrlName 
	Variable varNum
	String varStr
	String varName
	
	String PlotName 		= WinName(0,65)
	ApplyStackContrast(PlotName)
End

Function ApplyStackContrast(PanelName)
	String PanelName
	
	String PanelFolder,ImageName,ImageFolder,subWName,ImageSubW
	PanelImageInformation(PanelName,PanelFolder,ImageName,ImageFolder,subWName, ImageSubW)
	
	NVAR gInvertFlag 		= $(PanelFolder + ":gInvertFlag")
	NVAR gImageMin 		= $(PanelFolder + ":gImageMin")
	NVAR gImageMax 		= $(PanelFolder + ":gImageMax")
	SVAR gIntensityLabel 	= $(PanelFolder + ":gIntensityLabel")	// <--- New name
	SVAR gColorScaleLabel 	= $(PanelFolder + ":gColorScaleLabel")	// <--- Old name
	
	DoWindow $PanelName
	if (!V_flag)
		return 0
	endif
	
	String recString, colorTable, IntensityLabel=""
	recString 	= StringByKey("RECREATION",ImageInfo(ImageSubW,ImageName,0))
	colorTable 	= StringFromList(2,recString,",")
	
	ModifyImage /W=$ImageSubW $ImageName ctab= {gImageMin,gImageMax,$colorTable,gInvertFlag}, minRGB=NaN,maxRGB=NaN
	
	String ColorScaleName=""
	PanelAnnotationInfo(PanelName,ColorScaleName)
	
	// Backwards compatibility
	if (SVAR_Exists(gColorScaleLabel))
		IntensityLabel	= gColorScaleLabel
	elseif (SVAR_Exists(gIntensityLabel))
		IntensityLabel	= gIntensityLabel
	endif
	
	if (strlen(IntensityLabel) > 0)
		ColorScale /W=$ImageSubW/A=LT/C/N=ColorScale0 heightPct=25, ctab={gImageMin,gImageMax,,gInvertFlag} $IntensityLabel
	endif
	
	CheckDisplayed /W=$ImageSubW BlankImage
	if (V_flag)
		ModifyImage /W=$ImageSubW BlankImage ctab= {1,200,Yellow,0}
	endif
End

// *************************************************************
// ****		Display a histogram with image levels for user interactive contrast control
// *************************************************************
Function ShowImageHistogram(Image,StackName,PanelFolder,PanelName)
	Wave Image
	String StackName, PanelFolder, PanelName
	
	String OldDf = GetDataFolder(1)
	SetDataFolder $PanelFolder
	
		ImageHistogram /I Image
		WAVE W_ImageHist
		
		DisplayImageHistogram(W_ImageHist,StackName,PanelFolder,PanelName)
		
	SetDataFolder $OldDf
End

Function DisplayImageHistogram(ImageHist,ImageName,PanelFolder,PanelName)
	Wave ImageHist
	String ImageName, PanelFolder, PanelName
	
	NVAR gImageMin 	= $(PanelFolder + ":gImageMin")
	NVAR gImageMax 	= $(PanelFolder + ":gImageMax")
	
	String HistPanel = ImageName+"_hist"
	
	DoWindow $HistPanel
	if (V_flag)
		DoWindow /F $HistPanel
		return 0
	endif
	
	Display /K=1/W=(443,44,801,332) ImageHist as HistPanel
	DoWindow /C $HistPanel
	
	// Record the folder of the main image panel into this plot
	SetWindow $HistPanel,userdata= "PanelName="+PanelName+";"
	SetWindow $HistPanel,userdata+= "PanelFolder="+PanelFolder+";"
	
	// Give this panel information about the displayed plot
	SetWindow $HistPanel,userdata+= "VCsrWinName="+HistPanel+";"
	SetWindow $HistPanel,userdata+= "VCsrTraceName="+NameOfWave(ImageHist)+";"
	SetWindow $HistPanel,userdata+= "VCsr1=A;VCsr2=B;"
	SetWindow $HistPanel,userdata+= "VCsr1r=30000;VCsr1g=65535;VCsr1b=30000;"
	SetWindow $HistPanel,userdata+= "VCsr2r=0;VCsr2g=65535;VCsr2b=0;"
		
	SetWindow $HistPanel, hook(VerticalCursorsHook)=VCsrHook
	
	SetAxis /A/N=2
	
	ModifyGraph mirror=2, highTrip(left)=1e+06, log(left)=1
	Label left "Frequency"
	Label bottom "Intensity value"
	
	Variable minIntensity = gImageMin 
	Variable maxIntensity = gImageMax
	
	Cursor /F/H=2/S=2/W=$HistPanel A $NameOfWave(ImageHist) gImageMin, 0
	Cursor /F/H=2/S=2/W=$HistPanel B $NameOfWave(ImageHist) gImageMax, 0
	
	CheckBox LogFrequencyCheck,pos={3,30},size={114,17},title="log",fSize=12,value=1,proc=LogFrequency
	
	// A hook for when the cursor is moved. 
	SetWindow $HistPanel, hook(CursorHook)=HistogramCursorHook
	
	// Give some instructions
	SetDrawLayer UserFront
	SetDrawEnv fname= "Helvetica",fstyle= 1,textrgb= (30583,30583,30583)
	DrawText 0.592986425339367,0.061373225930188,"Press 1 or 2 to get"
	SetDrawEnv fname= "Helvetica",fstyle= 1,textrgb= (30583,30583,30583)
	DrawText 0.653393665158371,0.133459367636583,"vertical cursors"
End

Function LogFrequency(ctrlName,checked) : CheckBoxControl 
	String ctrlName 
	Variable checked 
	
	ModifyGraph log(left)=checked
End

// Catch events on the Histogram Window, and update global cursor values. 
Function HistogramCursorHook(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 	= H_Struct.winname
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	
	Variable CsrA, CsrB, CsrZ, ret=0
	
	// Find the folder of the MAIN image from HISTOGRAM PLOT the userdata
	String PanelFolder 	= StringByKey("PanelFolder",GetUserData(WindowName, "", ""),"=",";")
	String PanelName 	= StringByKey("PanelName",GetUserData(WindowName, "", ""),"=",";")
	
	NVAR gImageMin 	= $(PanelFolder + ":gImageMin")
	NVAR gImageMax 	= $(PanelFolder + ":gImageMax")
//	NVAR gHistAxisMin 	= $(PanelFolder + ":gHistAxisMin")
//	NVAR gHistAxisMax 	= $(PanelFolder + ":gHistAxisMax")
		
	// Update the image constract the cursor has been moved. 
	if (eventCode == 7)	// cursor moved. 
		
		CsrA 	= hcsr(A, WindowName)
		CsrB 	= hcsr(B, WindowName)
		
		UpdateImageContrast(PanelName,PanelFolder,CsrA,CsrB)
		
//		gImageMin 	= min(CsrA,CsrB)
//		gImageMax 	= max(CsrA,CsrB)
//		
//		ApplyStackContrast(PanelName)
		
		ret = 1
	endif
	
//	if (eventCode == 2) 	// Window kill
//		GetAxis /Q bottom
//		gHistAxisMin = V_min
//		gHistAxisMax = V_max
//		DoWindow /K $WindowName
//		ret = 1
//	endif
	
	return ret
End

Function UpdateImageContrast(PanelName,PanelFolder,CsrA,CsrB)
	String PanelName,PanelFolder
	Variable CsrA,CsrB

	NVAR gImageMin 	= $(PanelFolder + ":gImageMin")
	NVAR gImageMax 	= $(PanelFolder + ":gImageMax")
	
	gImageMin 	= min(CsrA,CsrB)
	gImageMax 	= max(CsrA,CsrB)
		
	ApplyStackContrast(PanelName)
End

// For plot (sub)windows with vertical cursors, allow key strokes to bring them to the mouse position. 
Function VCsrHook(H) 
	STRUCT WMWinHookStruct &H
	
	String WindowName 	= H.winname
	Variable eventCode 	= H.eventCode
	Variable keyCode 		= H.keyCode
	
	// Find the name of the window or subwindow containing vertical cursors from the userdata
	String VCsrWinName 	= StringByKey("VCsrWinName",GetUserData(WindowName, "", ""),"=",";")
	String VCsrTraceName 	= StringByKey("VCsrTraceName",GetUserData(WindowName, "", ""),"=",";")
	if (strlen(VCsrWinName) == 0)
		return 0
	endif
	
	// Make sure the active subwindow matches the above subwindow
	GetWindow $WindowName activeSW
	if (cmpstr(S_Value,VCsrWinName) != 0)
		return 0
	endif
	
	// Add a single-key "A" or "a" to make it easier to grab cursors at the plot extremes. 
	
	// This does not work as it seems you cannot catch CMD-key combinations, although Shift-Key seems to work. 
//	if ((keyCode == 97 || keyCode == 65) && (GetKeyState(0) & 1))
//		SetAxis /W=$WindowName/A bottom
//		DoUpdate /W=$WindowName
//		GetAxis /Q/W=$WindowName bottom		
//		Variable dRange 	= (V_max - V_min)/10
//		SetAxis /W=$WindowName bottom (V_min - dRange), (V_max + dRange)
//		return 1
//	endif

	// This works
	if (keyCode == 97 || keyCode == 65)
		
		SetAxis /W=$VCsrWinName/A bottom
		DoUpdate /W=$VCsrWinName
		GetAxis /Q/W=$VCsrWinName bottom
		
		Variable dRange 	= (V_max - V_min)/10
		SetAxis /W=$VCsrWinName bottom (V_min - dRange), (V_max + dRange)
		SetAxis /A/W=$VCsrWinName left
		
		return 1
	endif
	
	if (eventCode != 11)
		return 0
	endif
	
	// NOT NEEDED
	// Get the Panel Window location in Device Coordinates
//	GetWindow $WindowName wsize
//	Variable wL 	= V_left
//	Variable wR		= V_right
//	Variable wT 	= V_top
//	Variable wB		= V_bottom
//	Print " 	The window coordinates: ",wL, wR, wT, wB
	
	// The mouse location is in Device Coordinates relative to the Window top left (0,0)
	Variable mX 	= H.mouseLoc.h
	Variable mY 	= H.mouseLoc.v

//	Print " 	The mouse coordinates: ",H.mouseLoc.h,H.mouseLoc.v
	
	// Get the plot boundaries in Device Coordinates relative to the Window top left  (0,0)
	GetWindow $VCsrWinName psizeDC
	Variable pL 		= V_left
	Variable pR		= V_right
	Variable pT 		= V_top
	Variable pB		= V_bottom

//	Print " 	The plot coordinates: ",V_left, V_right, V_top, V_bottom
	
	Variable width=V_right-V_left
	Variable height=V_bottom-V_top

//	Print " 	The plot size: ", width,height
	
	// WRONG
//	Variable x 	= (mX - pL - wL)/width
//	Variable y 	= (mY - pT - wT)/height
	Variable x 	= (mX - pL)/width
	Variable y 	= (mY - pT)/height

//	Print " 	THe mouse location in plot coordinates: ", x, y
	
//	x = (x > 1) ? 0.9 : x
//	x = (X < 0) ? 0.1 : x
	
	String VCsr1 			= StringByKey("VCsr1",GetUserData(WindowName, "", ""),"=",";")
	Variable r1 			= NumberByKey("VCsr1r",GetUserData(WindowName, "", ""),"=",";")
	Variable g1				= NumberByKey("VCsr1g",GetUserData(WindowName, "", ""),"=",";")
	Variable b1 			= NumberByKey("VCsr1b",GetUserData(WindowName, "", ""),"=",";")
	
	String VCsr2 			= StringByKey("VCsr2",GetUserData(WindowName, "", ""),"=",";")
	Variable r2 			= NumberByKey("VCsr2r",GetUserData(WindowName, "", ""),"=",";")
	Variable g2 				= NumberByKey("VCsr2g",GetUserData(WindowName, "", ""),"=",";")
	Variable b2 			= NumberByKey("VCsr2b",GetUserData(WindowName, "", ""),"=",";")
	
//	print GetUserData(WindowName, "", "")
	
	if ((keyCode == 49) || (keyCode == 50))
	
//		print x
		if (keyCode == 49)
			Cursor /C=(r1,g1,b1)/F/P/W=$VCsrWinName $VCsr1 $VCsrTraceName x, 0.5
		
		elseif (keyCode == 50)
			Cursor /C=(r2,g2,b2)/F/P/W=$VCsrWinName $VCsr2 $VCsrTraceName x, 0.5
		endif
		
		String PanelFolder 	= StringByKey("PanelFolder",GetUserData(WindowName, "", ""),"=",";")
		String PanelName 	= StringByKey("PanelName",GetUserData(WindowName, "", ""),"=",";")
		
		if (strlen(PanelName) > 0)
			Variable CsrA 	= hcsr($VCsr1, WindowName)
			Variable CsrB 	= hcsr($VCsr2, WindowName)
			
			UpdateImageContrast(PanelName,PanelFolder,CsrA,CsrB)
		endif
			
		if (cmpstr(WindowName,"ReferencePanel") == 0)
			NVAR gSVDEMin 		= root:SPHINX:SVD:gSVDEMin
			NVAR gSVDEMax 		= root:SPHINX:SVD:gSVDEMax
			gSVDEMin 	= hcsr($VCsr1, VCsrWinName)
			gSVDEMax 	= hcsr($VCsr2, VCsrWinName)
		endif
		
		return 1
	endif
	
	return 0
End

// *************************************************************
// ****		Implement a better way for Controls, using User Data
// *************************************************************
Function ImagePanelButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	// Variables from the User Data
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String ImageName 		= StringByKey("ImageName",GetUserData(PanelName,"",""),"=",";")
	String ImageFolder 	= StringByKey("ImageFolder",GetUserData(PanelName,"",""),"=",";")
	String subWName 		= StringByKey("subWName",GetUserData(PanelName,"",""),"=",";")
	String PanelFolder 		= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	String ImageType 		= StringByKey("ImageType",GetUserData(PanelName,"",""),"=",";")
	
	WAVE Image 			= $(ImageFolder+ImageName)
	
	Variable ret = 0
	
	if (cmpstr(ctrlName,"ImageHistButton") == 0)
		ShowImageHistogram(Image,ImageName,PanelFolder,PanelName)
		ret = 1
	elseif (cmpstr(ctrlName,"ImageCopyButton") == 0)
		String NewName = ImageName
		Prompt NewName, "Name of image copy"
		DoPrompt "Duplicate RGB image", NewName
		if (V_flag)
			return 0
		elseif (cmpstr(NewName,ImageName)==0)
			return 0
		endif 
		WAVE RGBImage 	= $(ImageFolder+ImageName)
		Duplicate /O/D RGBImage, $(ImageFolder+NewName) /WAVE=CopyImage
		
		RGBDisplayPanel(CopyImage,NewName,NewName,-1,-1)
		
	elseif (cmpstr(ctrlName,"ImageSaveButton") == 0)
		if (cmpstr("RGB",ImageType) == 0)
			ExportRGBMap(Image,0)
		else
			ExportImage(Image,1,"displayed")
		endif
		ret = 1
	endif
	
	return ret
End

// *************************************************************
// ****		Append some common controls for IMAGE CURSORS
// *************************************************************
Function AppendCursors(ImageName,WindowName,SubWindow,PanelFolder,NumX,NumY,Height,RGBFlag)
	String ImageName,WindowName,SubWindow,PanelFolder
	Variable NumX,NumY,Height,RGBFlag
	
	PanelFolder 		= ParseFilePath(2,PanelFolder,":",0,0)
	MakeVariableIfNeeded(PanelFolder+"gCursorAX",NumX/2)
	MakeVariableIfNeeded(PanelFolder+"gCursorAY",NumY/2)
	MakeVariableIfNeeded(PanelFolder+"gCursorBX",NumX/2+10)
	MakeVariableIfNeeded(PanelFolder+"gCursorBY",NumY/2+10)
	
	NVAR gCursorAX 	= $(PanelFolder+"gCursorAX")
	NVAR gCursorAY 	= $(PanelFolder+"gCursorAY")
	NVAR gCursorBX 	= $(PanelFolder+"gCursorBX")
	NVAR gCursorBY 	= $(PanelFolder+"gCursorBY")
	
	String activeWindow = WindowName+"#"+SubWindow
	
	SetActiveSubwindow $activeWindow
	Cursor/P/I/W=# A $ImageName gCursorAX,gCursorAY
	Cursor/P/I/W=# B $ImageName gCursorBX,gCursorBY
	SetActiveSubwindow ##
	
	SetVariable CursorXSetVar,title="X",pos={9,Height},size={56,15},proc=SetStackCursor,value=gCursorAX
	SetVariable CursorYSetVar,title="Y",pos={78,Height},size={56,15},proc=SetStackCursor,value=gCursorAY
	
	if (RGBFlag) 		// For RGB images we need to display 3 values per pixel
		MakeVariableIfNeeded(PanelFolder+"gCursorARed",0)
		MakeVariableIfNeeded(PanelFolder+"gCursorAGreen",0)
		MakeVariableIfNeeded(PanelFolder+"gCursorABlue",0)
		NVAR gCursorARed 	= $(PanelFolder+"gCursorARed")
		NVAR gCursorAGreen 	= $(PanelFolder+"gCursorAGreen")
		NVAR gCursorABlue 	= $(PanelFolder+"gCursorABlue")
		
		// I don't think we need a procedure just to display a value
//		ValDisplay CsrIntDisplay title="red",format="%0.5f",pos={143,Height},size={70,15},proc=SetStackCursor
		ValDisplay CsrRedDisplay title="red",format="%0.5f",pos={143,Height},size={70,15}
		SetControlGlobalVariable("","CsrRedDisplay",PanelFolder,"gCursorARed",2)
		ValDisplay CsrGreenDisplay title="green",format="%0.5f",pos={143,Height},size={70,15}
		SetControlGlobalVariable("","CsrGreenDisplay",PanelFolder,"gCursorAGreen",2)
		ValDisplay CsrBlueDisplay title="blue",format="%0.5f",pos={143,Height},size={70,15}
		SetControlGlobalVariable("","CsrBlueDisplay",PanelFolder,"gCursorABlue",2)
		
	
	else				// For Gray-Scale images, Z is the Intensity
		MakeVariableIfNeeded(PanelFolder+"gCursorAZ",0)
		NVAR gCursorAZ 	= $(PanelFolder+"gCursorAZ")
		MakeVariableIfNeeded(PanelFolder+"gCursorBZ",0)
		NVAR gCursorBZ 	= $(PanelFolder+"gCursorBZ")
		gCursorAZ = zcsr(A,activeWindow)
	
		ValDisplay CsrIntDisplay title="int",format="%0.5f",pos={143,Height},size={70,15},proc=SetStackCursor
		SetControlGlobalVariable("","CsrIntDisplay",PanelFolder,"gCursorAZ",2)
	
	endif
	
	// A hook for when the cursor is moved. 
	SetWindow $WindowName, hook(CursorHook)=ImageCursorMove
End

// *************************************************************
// ****		Hook to catch cursor moves on the image
// *************************************************************

// Catch cursor moves on the StackWindow, and update global cursor values. 
// Also implement auto-scaling, which seems to be disabled. 
Function ImageCursorMove(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 	= H_Struct.winname
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode

	// Check that the image subWindow is active
	GetWindow $WindowName activeSW
	String subWindow 	= ParseFilePath(0, S_Value, "#", 1, 0)
	if (cmpstr(subWindow,"StackImage") != 0)
		if (cmpstr(subWindow,"RGBImage") != 0)
			return 0
		endif
	endif
	
	if (eventCode == 11) 	// Keyboard event. 
		// Test for Command-A, to autoscale image
//		if ((keyCode == 97 || keyCode == 65) && (GetKeyState(0) & 1))
		if (keyCode == 97 || keyCode == 65)
			GetWindow $WindowName activeSW
			
			Variable wt=WinType(S_value)
			
			if (WinType(S_value) == 1)
				SetAxis /Z/W=$S_value/A
				return 1
			else
				return 0
			endif
		endif
		return 0
	endif
	
	if (eventCode != 7)
		return 0
	endif
	
	// Variables from the User Data
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String ImageName 		= StringByKey("ImageName",GetUserData(PanelName,"",""),"=",";")
	String ImageFolder 		= StringByKey("ImageFolder",GetUserData(PanelName,"",""),"=",";")
	String subWName 		= StringByKey("subWName",GetUserData(PanelName,"",""),"=",";")
	String PanelFolder 		= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	
	UpdateCursorGlobals(PanelName,PanelFolder,WindowName)
	
	// !*!* return 0 to allow other hooks to use this cursor moved event!
	return 0
End

Function UpdateCursorGlobals(PanelName,PanelFolder,StackWindow)
	String PanelName,PanelFolder,StackWindow
	
	NVAR gCursorAX 		= $(PanelFolder + ":gCursorAX")
	NVAR gCursorAY 		= $(PanelFolder + ":gCursorAY")
	NVAR gCursorAZ 		= $(PanelFolder + ":gCursorAZ")
	
	CheckCursorOnImage("A",StackWindow)
	CheckCursorOnImage("B",StackWindow)
	
	// This not appropriate for imates with scaled axes!!
//	gCursorAX = hcsr(A, StackWindow)
//	gCursorAY = vcsr(A, StackWindow)

	gCursorAX = pcsr(A, StackWindow)
	gCursorAY = qcsr(A, StackWindow)
	gCursorAZ = zcsr(A, StackWindow)
	
	ControlUpdate /W=$PanelName CsrIntDisplay
End

Function CheckCursorOnImage(Csr,ImageWin)
	String Csr, ImageWin
	
	Variable NImages
	String InfoList,ImageList, ImageName
	
	InfoList = CsrInfo($Csr,ImageWin)
	if (strlen(InfoList) == 0)
		ImageList 	= ImageNameList(ImageWin,";")
		NImages 	= ItemsInList(ImageList)
		ImageName 	= StringFromList(NImages-1,ImageList)
		Cursor/P/I/W=$ImageWin $Csr $ImageName 0,0
		
//		Print " Placed ",Csr,"on image"
	endif
End

// *************************************************************
// ****		Set the cursor positions using SetVariable controls
// *************************************************************
Function SetStackCursor(SV_Struct) 
	STRUCT WMSetVariableAction &SV_Struct 
	
	String WindowName = SV_Struct.win
	String ctrlName 	= SV_Struct.ctrlName
	Variable varNum 	= SV_Struct.dval
	
	Variable eventCode 	= SV_Struct.eventCode
	if (eventCode == -1)
		return 0
	endif
	
	// Variables from the User Data
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String ImageName 		= StringByKey("ImageName",GetUserData(PanelName,"",""),"=",";")
	String ImageFolder 	= StringByKey("ImageFolder",GetUserData(PanelName,"",""),"=",";")
	String subWName 		= StringByKey("subWName",GetUserData(PanelName,"",""),"=",";")
	String PanelFolder 		= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	
	NVAR gCursorAX	= $(PanelFolder+":gCursorAX")
	NVAR gCursorAY	= $(PanelFolder+":gCursorAY")
	NVAR gCursorBX	= $(PanelFolder+":gCursorBX")
	NVAR gCursorBY	= $(PanelFolder+":gCursorBY")
		
	if (cmpstr(ctrlName,"CursorXSetVar") == 0)
		gCursorAX 	= varNum
		Cursor/P/I/W=$subWName A $ImageName gCursorAX, gCursorAY
	elseif (cmpstr(ctrlName,"CursorYSetVar") == 0)
		gCursorAY 	= varNum
		Cursor/P/I/W=$subWName A $ImageName gCursorAX, gCursorAY
	elseif (cmpstr(ctrlName,"CursorBXSetVar") == 0)
		gCursorBX 	= varNum
		Cursor/P/I/W=$subWName B $ImageName gCursorBX, gCursorBY
	elseif (cmpstr(ctrlName,"CursorBYSetVar") == 0)
		gCursorBY 	= varNum
		Cursor/P/I/W=$subWName B $ImageName gCursorBX, gCursorBY
	endif
	
	// For the Browser panel, Cursor motion automatically calls the hook function to extract the pixel spectrum. 
End 

// *************************************************************
// ****		Set all images to same zoom
// *************************************************************

Function TransferImageZoom(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	// Variables from the User Data
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 		= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	String subWName 		= StringByKey("subWName",GetUserData(PanelName,"",""),"=",";")

	// Check that the active subWindow is the image named in the UserData
	GetWindow $WindowName activeSW
	if (cmpstr(subWName,S_Value) != 0)
		SetActiveSubWindow $subWName
		GetWindow $WindowName activeSW
		if (cmpstr(subWName,S_Value) != 0)
			return 0
		endif
	endif
	
	Variable i, x0, x1, y0, y1, NumX, NumY, NPanels
	String DestWindow, PanelNameList
	
	GetAxis /Q/W=$S_Value left
	y0 = V_min
	y1 = V_max
	
	GetAxis /Q/W=$S_Value bottom
	x0 = V_min
	x1 = V_max
	
	// Hope that at least one cursor is on the image. 
	WAVE StackImage 	= CsrWaveRef(A,S_Value)
	if (!WaveExists(StackImage))
		WAVE StackImage 	= CsrWaveRef(B,S_Value)
		if (!WaveExists(StackImage))
			Print " *** Cannot transfer image zoom settings unless a cursor is on the image."
			return 0
		endif
	endif
	NumX 	= DimSize(StackImage,0)
	NumY 	= DimSize(StackImage,1)
	
	PanelNameList = ImagePanelList("","StackImage","",0)
	PanelNameList = PanelNameList + ImagePanelList("","RGBImage","",0)
	NPanels = ItemsInList(PanelNameList)
	
	for (i=0;i<NPanels;i+=1)
		PanelName 		= StringFromList(i,PanelNameList)
		DestWindow 	= StringByKey("subWName",GetUserData(PanelName, "", ""),"=",";")
		
		if (cmpstr(PanelName,DestWindow) != 0)
			WAVE Image = CsrWaveRef(A,DestWindow)
			if (WaveExists(Image))
				if ((NumX == DimSize(Image,0)) && (NumY == DimSize(Image,1)))
					
					SetAxis /W=$DestWindow bottom, x0, x1
					SetAxis /W=$DestWindow left, y0, y1
					
				endif
			endif
		endif
	endfor
End

// *************************************************************
// ****		Transfer cursors between images. 
// *************************************************************

// This is a dedicated fast routine for IMPORTING to the Browser cursors. 
Function TransferCsrsToBrowser(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	String CsrWindow 	= StringByKey("subWName",GetUserData(WindowName, "", ""),"=",";")
	String DestWindow 	= "StackBrowser#StackImage"
	
	TransferCsr("A",CsrWindow,DestWindow)
	TransferCsr("B",CsrWindow,DestWindow)
End

Function TransferImageCsrs(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	TransferCsrToAllImages(WindowName)
End

Function TransferCsrToAllImages(WindowName)
	String WindowName
	
	String CsrWindow 	= StringByKey("subWName",GetUserData(WindowName, "", ""),"=",";")
	String PanelFolder 	= StringByKey("PanelFolder",GetUserData(WindowName, "", ""),"=",";")
	
	// Hope that at least one cursor is on the image. 
	WAVE StackImage 	= CsrWaveRef(A,CsrWindow)
	if (!WaveExists(StackImage))
		WAVE StackImage 	= CsrWaveRef(B,CsrWindow)
		if (!WaveExists(StackImage))
			Print " *** Cannot transfer image cursor positions unless a cursor is on the image."
			return 0
		endif
	endif
	
	Variable i, NPanels, NumX, NumY
	NumX = DimSize(StackImage,0)
	NumY = DimSize(StackImage,1)
	
	String PanelName, DestWindow, PanelNameList
//	PanelNameList = ImagePanelList("","StackImage","",0)
	PanelNameList = ImagePanelList("","","",0)
	NPanels = ItemsInList(PanelNameList)
	
	for (i=0;i<NPanels;i+=1)
		PanelName 		= StringFromList(i,PanelNameList)
		DestWindow 	= StringByKey("subWName",GetUserData(PanelName, "", ""),"=",";")
		
		if (cmpstr(CsrWindow,DestWindow) != 0)
			WAVE Image = CsrWaveRef(A,DestWindow)
			if (WaveExists(Image))
				if ((NumX == DimSize(Image,0)) && (NumY == DimSize(Image,1)))
					TransferCsr("A",CsrWindow,DestWindow)
					TransferCsr("B",CsrWindow,DestWindow)
					
					UpdateCursorGlobals(PanelName,PanelFolder,DestWindow)
				endif
			endif
		endif
	endfor
End

Function TransferCsr(Csr,CsrWindow,DestWindow)
	String Csr,CsrWindow,DestWindow
	
	if (strlen(CsrInfo($Csr,CsrWindow)) > 0)
		Variable CsrAX 		= NumberByKey("POINT",CsrInfo($Csr,CsrWindow),":",";")
		Variable CsrAY 		= NumberByKey("YPOINT",CsrInfo($Csr,CsrWindow),":",";")
		
		WAVE CrsImage 		= CsrWaveRef(A,DestWindow)
		
		if (WaveExists(CrsImage))
			Cursor/P/I/W=$DestWindow $Csr $NameOfWave(CrsImage) CsrAX,CsrAY
		endif
	endif
End

Function /T WinNamesToWinTitles(WinNameList)
	String WinNameList
	
	String WindowName, WinTitleList=""
	Variable i, NWindows=ItemsInList(WinNameList)
	
	for (i=0;i<NWindows;i+=1)
		WindowName = StringFromList(i,WinNameList)
		GetWindow $WindowName title
		WinTitleList += S_value+";"
	endfor
	
	return WinTitleList
End

// Construct a list of Panels displaying an image in a SubWindow. 
// 	-- match some Panel and SubWindow naming requirements. 
// 	-- optionally match some image size requirements. 
// 	-- return either a list of Panel or Image names. 
Function /T ImagePanelList(PanelNameStr,ImageWinStr, ImageNameStr, ImageListFlag, [DimX, DimY])
	String PanelNameStr,ImageWinStr, ImageNameStr
	Variable ImageListFlag, DimX, DimY
	
	String ListOfPanels="", ListOfImages=""
	String PanelList, PanelName, SubWinList, SubWinName, ImageList, ImageName
	Variable i, j, k, NPanels, NSubWins, NImages, CheckX, CheckY, OKX=1, OKY=1
	
	CheckX 	= (ParamIsDefault(DimX)) ? 0 : 1
	CheckY 	= (ParamIsDefault(DimY)) ? 0 : 1
	
	// Make a list of panels containing the string PanelNameStr
	PanelList 	= InclusiveWaveList(WinList("*",";","WIN:64"),PanelNameStr,";")
	NPanels 	= ItemsInList(PanelList)
	
	// Loop through the Panels looking for those with correctly named SubWindow
	for (i=0;i<NPanels;i+=1)
		PanelName 		= StringFromList(i,PanelList)
		SubWinList 	= InclusiveWaveList(ChildWindowList(PanelName),ImageWinStr,";")
		NSubWins 		= ItemsInList(SubWinList)
		
		for (j=0;j<NSubWins; j+=1)
			SubWinName 	= StringFromList(j,SubWinList)
			ImageList 		= InclusiveWaveList(ImageNameList(PanelName+"#"+SubWinName,";"),ImageNameStr,";")
			NImages 		= ItemsInList(ImageList)
			
			if ((NImages>0) && (!CheckX) && (!CheckY))
				ListOfPanels += PanelName + ";"
				ListOfImages += ImageList
				
			elseif ((NImages>0) && (CheckX || CheckY))
				for (k=0;k<NImages;k+=1)
					ImageName 		= StringFromList(k,ImageList)
					WAVE Image 	= ImageNameToWaveRef(PanelName+"#"+SubWinName,ImageName)
					
					if (CheckX)
						OKX 	= (DimSize(Image,0) == DimX) ? 1 : 0
					endif
					
					if (CheckY)
						OKY 	= (DimSize(Image,1) == DimY) ? 1 : 0
					endif
					
					if (OKX && OKY)
						ListOfPanels += PanelName + ";"
						ListOfImages += ImageName + ";"
					endif
				endfor
			endif
		endfor
	endfor
	
	if (ImageListFlag)
		return ListOfImages
	else
		return CompressList(ListOfPanels,0)
	endif
End

// *************************************************************
// ****		Housekeeping Display Panel Hooks to catch window kill events
// *************************************************************
Function KillPanelHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	// This is everything we need to look up, starting from the subWindow name
	String WindowName 	= H_Struct.winname
	Variable eventCode	= H_Struct.eventCode
	
	if (eventCode != 2) 	// Window kill
		return 0
	endif
	
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String StackWindow 	= PanelName+"#StackImage"
	if (StrSearch(WindowName,"RGB",0) > -1)
		StackWindow = PanelName+"#RGBmage"
		return 0
	endif
	
	// Don't currently create a window Level Histogram for RGB display panels
	String StackAvg	= StringByKey("TNAME",CsrInfo(A,StackWindow))
	string StackName 	= ReplaceString("_av",StackAvg,"")	
	String HistPanel 	= StackName+"_hist"
	DoWindow /K $HistPanel
	
End


// *************************************************************
// ****		Hook to catch events in the Image Display window. 
// *************************************************************
Function ImageDisplayHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	// This is everything we need to look up, starting from the subWindow name
	String WindowName 	= H_Struct.winname
	Variable eventCode		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String StackWindow 	= PanelName+"#StackImage"
	if (StrSearch(WindowName,"RGB",0) > -1)
		StackWindow = PanelName+"#RGBmage"
	endif
	
	if ((keyCode == 72) || (keyCode == 104))
		ShrinkImageDisplay(PanelName)
		return 1	
	endif
End

Function ShrinkImageDisplay(PanelName)
	String PanelName
	
		GetWindow $PanelName, activeSW
		Print S_Value
		
	GetWindow $PanelName, wsize
	Variable height 	= (V_right-V_left)
	Variable width 	= (V_bottom-V_top)
	
	CheckWindowPosition(PanelName,V_left, V_top, V_left+width/2, V_top+height/2)
	
	String DisplayWindow = PanelName+"#StackImage"
	SetActiveSubwindow $DisplayWindow
		GetWindow $PanelName, activeSW
		Print S_Value
		Display
		MoveWindow /W=$DisplayWindow 0, 0, height, width
	SetActiveSubwindow ##
	
//	MoveWindow /W=$PanelName V_left, V_right, V_top/2, V_bottom/2
	
///	ModifyGraph margin=1, noLabel=2
End

Function GrowImageDisplay(PanelName)
	String PanelName

	GetWindow $PanelName, wsize
	Variable height 	= (V_right-V_left)
	Variable width 	= (V_bottom-V_top)
	
	CheckWindowPosition(PanelName,V_left, V_top, V_left+2*width, V_top+2*height)
	
//	SetActiveSubwindow $activeWindow
//	ModifyGraph margin=1, noLabel=2
End

// *************************************************************
// ****		Stack Display Panel Button Controls
// *************************************************************


