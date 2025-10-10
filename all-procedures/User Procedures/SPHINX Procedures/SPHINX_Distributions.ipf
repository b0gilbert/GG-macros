#pragma rtGlobals=1		// Use modern global access method.


Function DistMapFromImages(DistName,FileType)
	String DistName, FileType
	
	WAVE Image1 		= root:SPHINX:Import:image0
	WAVE Image2 		= root:SPHINX:Import:image1
	
	Wave EAxis 			= root:SPHINX:Import:image0_axis
	SVAR gEAxisUnit 	= root:SPHINX:Import:gEAxisUnit
	
	if (WaveExists(EAxis))
		Note /K Image1, "Energy = "+num2str(EAxis[0])+" "+gEAxisUnit
		Note /K Image2, "Energy = "+num2str(EAxis[1])+" "+gEAxisUnit
	endif
	
//	String PanelName 	= "DM_"+DistName
	String PanelFolder 	= "root:SPHINX:Distributions:"+DistName
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S $PanelFolder
	
		KillWaves /A/Z
		
		MoveWave Image1, $(ParseFilePath(2,PanelFolder,":",0,0))
		MoveWave Image2, $(ParseFilePath(2,PanelFolder,":",0,0))
		
		Duplicate /O Image1, BlankImage, DistributionMap
		BlankImage = 125
		
		// ImageRegistration requires single precision floating point. 
		Redimension /S Image1, Image2
		
		MakeDistributionMap(PanelFolder,"subtract")
		
		DistributionDisplayPanel(PanelFolder)
		
	SetDataFolder $(OldDf)
End

Function DisplayADistMap()
	
	InitializeStackBrowser()
	
	MakeStringIfNeeded("root:SPHINX:Distributions:gDistName","")
	SVAR gDistName 	= root:SPHINX:Distributions:gDistName
	
	String DistFolder 	= "root:SPHINX:Distributions"
	String DistName 	= gDistName
	
	String DistList = ReturnListOfDataFolders(DistFolder,"*")
	Prompt DistName, "List of distribution maps", popup, DistList
	DoPrompt "Select distribution map to view", DistName
	if (V_flag)
		return 0
	endif
	
	gDistName 	= DistName
	
	DistributionDisplayPanel("root:SPHINX:Distributions:"+DistName)
	
//	String PanelName = DistributionDisplayPanel(Image1,Image2,DistName,ReturnColorTable(-1))
End


// *************************************************************
// ****		A Common Image Display Panel with Controls
// *************************************************************
	
Function /S DistributionDisplayPanel(PanelFolder)
	String PanelFolder
	
	String DistName 	= ParseFilePath(3,PanelFolder,":",0,0)
//	String PanelName 	= "DM_"+DistName
	String PanelName 	= DistName
	
	WAVE Image0 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "image0")
	WAVE Image1 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "image1")
	WAVE BlankImage 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "BlankImage")
	WAVE Distribution 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "DistributionMap")
	
	Variable Height 	= 450
	Variable NumX	= DimSize(Image1,0)
	Variable NumY	= DimSize(Image1,1)
	
	String ColorTable = "CyanMagenta"
		
	DoWindow /K $PanelName
	NewPanel /K=1/W=(6,44,440,520) as "Distribution Map"
	Dowindow /C $PanelName
	CheckWindowPosition(PanelName,6,44,440,520)
	
	Display/W=(7,111,419,441)/HOST=#
	AppendImage BlankImage
	ModifyImage BlankImage ctab= {1,200,Yellow,0}
	
	AppendImage Distribution
	ModifyImage $(NameOfWave(Distribution)) ctab= {*,*,$ColorTable,1}
	ModifyGraph mirror=2
	RenameWindow #, StackImage
	
	TitleBox ImageDescription win=$PanelName,frame=5,fSize=12,pos={138,10},title=DistName
	
//	AppendContrastControls(NameOfWave(Distribution),PanelName,PanelFolder,NumX,NumY)
	AppendContrastControls(NameOfWave(Distribution),PanelFolder,PanelFolder,NumX,NumY)
	
	ApplyStackContrast(PanelName)
	
	AppendCursors(NameOfWave(Distribution),PanelName,"StackImage",PanelFolder,NumX,NumY,Height,0)

	// Permit saving for images or stacks
	Button ImageSaveButton,pos={5,83}, size={55,24},fSize=13,proc=ImagePanelButtons,title="Export"
	Button TransferCrsButton,pos={222,448}, size={45,18},fSize=13,proc=TransferCsrsToBrowser,title=">>"
	
	SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
//	SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
	
	// Give this panel all the information it needs about the displayed image
	SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
	SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
	SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(Distribution)+";"
	SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(Distribution,1)+";"
	SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
	SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
		
End

Function MakeDistributionMap(PanelFolder,ImageMath)
	String PanelFolder, ImageMath
	
	WAVE Image0 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "image0")
	WAVE Image1 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "image1")
	WAVE Dist 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "DistributionMap")
	
	if (cmpstr("subtract",ImageMath)==0)
		Dist 	= Image1 - Image0
	elseif (cmpstr("divide",ImageMath)==0)
		Dist 	= Image1 / Image0
		Dist[][] = (numtype(Dist[p][q]) != 0) ? NAN : Dist[p][q]
	endif
	
End

ImageRegistration