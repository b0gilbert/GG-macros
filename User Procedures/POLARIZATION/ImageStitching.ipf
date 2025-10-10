//Updated 9.5.2012 11:54

#pragma rtGlobals=1		// Use modern global access method.
// !*!*!*! Both ImageAlign.ipf and ImageStitching.ipf  were given the same ModelName, which led to a an error
// !*!*!*! Removing the one in ImageAlign.ipf
#pragma ModuleName=file_IO

//==================================================================

Function ImageStitching()

	NewDataFolder /O root:ImageStitch
	NewDataFolder /O root:ImageStitch:import
	SetDataFolder root:ImageStitch

	DoWindow /K $"ImageStitchingPanel"
	NewPanel /K=1/W=(10,10,1100,910) as "Image Stitching"
	DoWindow /C $"ImageStitchingPanel"
	CheckWindowPosition("ImageStitchingPanel",10,10,1100,910)
	
	//	========			Panel Hooks
	SetWindow ImageStitchingPanel, hook(PanelCursorHook)=ImageStitchingCursorHooks
	
	Make /O/N=(1,1)/D $"combinedImage" /WAVE=combinedImage
	combinedImage = NaN
	
	//  	-------- 	Display the image
	Display/W=(0,0,900,900)/N=combinedImagePlot/HOST=# 
	AppendImage combinedImage
	
	Variable /G displayFactor = 10
	SetVariable displayFactor,title="Reduction",pos={920,5},limits={1,20,1},size={120,20},fsize=13,value=displayFactor
	Button loadFirstImage,pos={920,25}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Load First Image"
	Button loadSecondImage,pos={920,45}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Load Second Image",disable=2	
	
	Button moveUp,pos={970,70}, size={40,19},fSize=12,proc=ImageStitchPanelButtons,title="up", disable=2
	Button moveDown,pos={970,110}, size={40,19},fSize=12,proc=ImageStitchPanelButtons,title="down", disable=2
	Button moveRight,pos={1030,90}, size={40,19},fSize=12,proc=ImageStitchPanelButtons,title="right", disable=2
	Button moveLeft,pos={910,90}, size={40,19},fSize=12,proc=ImageStitchPanelButtons,title="left", disable=2
	Variable /G stepSize = 10
	SetVariable stepSize,title="Step",pos={950,90},limits={1,200,1},size={80,20},fsize=13,value=stepSize, disable=2
	
	Button toggle2ndImage,pos={920,140}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Toggle Image", disable=2
	
	Button mergeImages,pos={920,200}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Merge Images", disable=2
	
	Button ExportStitchedImage,pos={920,340}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Export Stitched Image", disable=2
	
	MakeVariableIfNeeded("root:ImageStitch:sliceImage",1)
	CheckBox sliceImageCheckBox,pos={920,262},fSize=11,variable=$("root:ImageStitch:sliceImage"),title="Slice Image"
	
	Button calculateStatistics,pos={920,280}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Calculate Statistics", disable=2
	
	//Button organizeImageWindows,pos={920,360}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Organize Windows", disable=2
	Button hideImageStitchingPanel,pos={920,380}, size={120,19},fSize=12,proc=ImageStitchPanelButtons,title="Send to Back"
	
End

Function loadFirstImage()

	SetDataFolder root:ImageStitch:import
	NVAR displayFactor = root:ImageStitch:displayFactor
	
	String S_waveNames = ""
	LoadWave /H /D
	
	if (stringmatch(S_waveNames,""))
		return 0
	endif
	
	Wave loadedWave = $StringFromList(0, S_waveNames)
	String /G loaded1stWaveName = StringFromList(0, S_fileName,".")
	Duplicate loadedWave,$loaded1stWaveName
	KillWaves loadedWave
	Wave loadedWave = $loaded1stWaveName
	
	Variable xDim = floor(DimSize(loadedWave,0)/displayFactor)
	Variable yDim = floor(DimSize(loadedWave,1)/displayFactor)
	
	Wave loadedWave = $loaded1stWaveName
	
	ImageInterpolate /RESL={xDim,yDim} /DEST=$("root:ImageStitch:small1stImage") Spline loadedWave 
	Wave small1stImage = $("root:ImageStitch:small1stImage")
	
	Make /D/N=(xDim*3-1,yDim*3-1)/O $("root:ImageStitch:small1stImage_s") /WAVE=loadedWave_s
	
	Variable i,j
	Make /D/N=(xDim*3-1,yDim*3-1)/O $("root:ImageStitch:combinedImage") /WAVE=combinedImage
	for (i=0;i<xDim;i+=1)
		for (j=0;j<yDim;j+=1)
			loadedWave_s[i+xDim][j+yDim] = small1stImage[i][j]
		endfor
	endfor
	
	combinedImage = loadedWave_s
	
	SetActiveSubwindow ImageStitchingPanel#combinedImagePlot
	AppendImage combinedImage
	
	return 1
End

Function loadSecondImage()

	SetDataFolder root:ImageStitch:import
	NVAR displayFactor = root:ImageStitch:displayFactor
	
	LoadWave /H /D
	
	if (stringmatch(S_waveNames,""))
		return 0
	endif
	
	Wave loadedWave = $StringFromList(0, S_waveNames)
	String /G loaded2ndWaveName = StringFromList(0, S_fileName,".")
	Duplicate loadedWave,$loaded2ndWaveName
	KillWaves loadedWave
	Wave loadedWave = $loaded2ndWaveName
	
	Variable xDim = floor(DimSize(loadedWave,0)/displayFactor)
	Variable yDim = floor(DimSize(loadedWave,1)/displayFactor)
	
	ImageInterpolate /RESL={xDim,yDim} /DEST=$("root:ImageStitch:small2ndImage") Spline loadedWave
	Wave small2ndImage = $("root:ImageStitch:small2ndImage")
	
	Variable i,j
	Wave combinedImage = $("root:ImageStitch:combinedImage")
	for (i=0;i<xDim;i+=1)
		for (j=0;j<yDim;j+=1)
			combinedImage[i][j] = small2ndImage[i][j]
		endfor
	endfor
	
	SetActiveSubwindow ImageStitchingPanel#combinedImagePlot
	AppendImage combinedImage
	
	return 1
End

Function move2ndImage(xChange, yChange)

	Variable xChange, yChange
	NVAR displayFactor = root:ImageStitch:displayFactor
	
	SetDataFolder root:ImageStitch
	Variable /G toggle = 1
	Variable /G yOffset
	Variable /G xOffset

	SetDataFolder root:ImageStitch:import
	
	String /G loaded1stWaveName
	String /G loaded2ndWaveName
	
	Variable xDim = floor(DimSize($loaded2ndWaveName,0)/displayFactor)
	Variable yDim = floor(DimSize($loaded2ndWaveName,1)/displayFactor)
	
	Wave loaded1stWave_s = $("root:ImageStitch:small1stImage_s")
	Wave loaded2ndWave = $("root:ImageStitch:small2ndImage")
	
	NVAR stepSize = root:ImageStitch:stepSize
	yOffset += yChange*stepSize
	xOffset += xChange*stepSize
	
	if (yOffset < 0)
		yOffset = 0
	endif
	if (xOffset < 0)
		xOffset = 0
	endif
	
	Variable i,j
	Wave combinedImage = $("root:ImageStitch:combinedImage")
	
	combinedImage = loaded1stWave_s
	
	for (i=0;i<xDim;i+=1)
		for (j=0;j<yDim;j+=1)
			combinedImage[i+xOffset][j+yOffset] = loaded2ndWave[i][j]
		endfor
	endfor
	
	SetActiveSubwindow ImageStitchingPanel#combinedImagePlot
	AppendImage combinedImage
	
End

Function toggle2ndImage()
	SetDataFolder root:ImageStitch
	Variable /G toggle
	
	if (toggle)
		Wave loaded1stWave_s = $("root:ImageStitch:small1stImage_s")
		SetActiveSubwindow ImageStitchingPanel#combinedImagePlot
		AppendImage loaded1stWave_s
		toggle = 0
	else
		move2ndImage(0,0)
	endif
End

Function mergeImages()
	SetDataFolder root:ImageStitch
	Variable /G yOffset
	Variable /G xOffset
	NVAR displayFactor = root:ImageStitch:displayFactor
	
	SetDataFolder root:ImageStitch:import
	String /G loaded1stWaveName
	String /G loaded2ndWaveName
	
	Wave loaded1stWave = $loaded1stWaveName
	Wave loaded2ndWave = $loaded2ndWaveName
	
	Variable x1 = DimSize(loaded1stWave,0)
	Variable y1 = DimSize(loaded1stWave,1)
	
	Variable x2 = DimSize(loaded2ndWave,0)
	Variable y2 = DimSize(loaded2ndWave,1)
	
	Variable relativeX = xOffset*displayFactor - x1
	Variable relativeY = yOffset*displayFactor - y1
	
	NewDataFolder /O root:SPHINX
	NewDataFolder /O root:SPHINX:Stacks
	
	Make /D/O/N=(x1+abs(x2-x1)+abs(relativeX),y1+abs(y2-y1)+abs(relativeY))/O $("root:SPHINX:Stacks:StitchedImage") /WAVE=StitchedImage

	StitchedImage = NaN
	
	Variable StartX1
	Variable StartY1
	Variable StartX2
	Variable StartY2
	
	if (relativeX < 0)
		StartX1 =abs(relativeX)
		StartX2=0 
	else
		StartX1=0
		StartX2=abs(relativeX)
	endif
	if (relativeY < 0)
		StartY1=abs(relativeY)
		StartY2=0
	else
		StartY1=0
		StartY2=abs(relativeY)
	endif
	
	Variable i,j
	
	// Starting at 1 to chop off bad 1st pixel in X
	for (i=1;i<x1;i+=1)
		for (j=0;j<y1;j+=1)
			StitchedImage[startX1+i][startY1+j] = loaded1stWave[i][j]
		endfor
	endfor
	for (i=1;i<x2;i+=1)
		for (j=0;j<y2;j+=1)
			StitchedImage[startX2+i][startY2+j] = loaded2ndWave[i][j]
		endfor
	endfor
	
	DisplaySPHINXImage("StitchedImage")
	Wave imageHist = $("root:SPHINX:"+"StitchedImage"+":W_ImageHist")
	Variable numPts = DimSize(imageHist,0)
	NVAR gImageMin = $("root:SPHINX:"+"StitchedImage"+":gImageMin")
	NVAR gImageMax = $("root:SPHINX:"+"StitchedImage"+":gImageMax")
	FindLevel /Q/R=[0,numPts-1] imageHist, 100
	gImageMin 	= V_LevelX
	FindLevel /Q/R=[numPts-1,0] imageHist, 100
	gImageMax 	= V_LevelX
	
	// Display Histogram
	String ImageName 		= StringByKey("ImageName",GetUserData("StackStitchedImage","",""),"=",";")
	String ImageFolder 		= StringByKey("ImageFolder",GetUserData("StackStitchedImage","",""),"=",";")
	String PanelFolder 		= StringByKey("PanelFolder",GetUserData("StackStitchedImage","",""),"=",";")
	WAVE Image 			= $(ImageFolder+ImageName)
	ShowImageHistogram(Image,ImageName,PanelFolder,"StackStitchedImage")
	
	//Prepare Image Slices
	NVAR sliceImage = root:ImageStitch:sliceImage
	Variable numSlices = 4
	
	Variable xDim = DimSize(StitchedImage,0)
	Variable yDim = DimSize(StitchedImage,1)
	
	for (i=0;i<numSlices;i+=1)
		//Set new ROI y positions
		Y1 = floor(i * (yDim/numSlices))
		Y2 = floor(i * (yDim/numSlices)+(yDim/numSlices))
		Duplicate /O /R=(0,xDim-1)(Y1,Y2) StitchedImage, $("root:SPHINX:Stacks:Slice_"+num2str(i))
		if (sliceImage)
			DisplaySPHINXImage("Slice_"+num2str(i))
			Wave imageHist = $("root:SPHINX:Slice_"+num2str(i)+":W_ImageHist")
			numPts = DimSize(imageHist,0)
			NVAR gImageMin = $("root:SPHINX:Slice_"+num2str(i)+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:Slice_"+num2str(i)+":gImageMax")
			FindLevel /Q/R=[0,numPts-1] imageHist, 100
			gImageMin 	= V_LevelX
			FindLevel /Q/R=[numPts-1,0] imageHist, 100
			gImageMax 	= V_LevelX
			
			// Display Histogram
			ImageName 		= StringByKey("ImageName",GetUserData("StackSlice_"+num2str(i),"",""),"=",";")
			ImageFolder 		= StringByKey("ImageFolder",GetUserData("StackSlice_"+num2str(i),"",""),"=",";")
			PanelFolder 		= StringByKey("PanelFolder",GetUserData("StackSlice_"+num2str(i),"",""),"=",";")
			WAVE Image 			= $(ImageFolder+ImageName)
			ShowImageHistogram(Image,ImageName,PanelFolder,"StackSlice_"+num2str(i))
			
		endif
	endfor
	if (sliceImage)
		organizeImageWindows()
	endif
End

Function ExportStitchedImage()
	WAVE stitchedImage = $("root:SPHINX:stacks:StitchedImage")
	save /C stitchedImage
End

Function calculateStatistics(imageName)

	String imageName

	if (stringmatch(igorInfo(1),"Untitled"))
		SaveExperiment
	endif

	// print data header
	print "---- IMAGE STATISTICS ----"
	//Commenting out as we are not calculating the Angle Spread Footprint
	print "FileName	Data	Footprint	Standard Deviation	Circ Std Dev	FWHM	Mean	Mode"
	//print "FileName	Data	Standard Deviation	Circ Std Dev	FWHM	Mean	Mode"

	doCalculateStats(imageName)
	
	// complete the same analysis iteratively for each slice
	NVAR sliceImage = root:ImageStitch:sliceImage
	if (sliceImage)
		Variable numSlices = 4
		Variable i
		for (i=0;i<numSlices;i+=1)
			doCalculateStats("Slice_"+num2str(i))
		endfor
	endif
End

Function doCalculateStats(imageName)
	String imageName
	WAVE imageWave = $("root:SPHINX:stacks:"+imageName)
	String fileName = IgorInfo(1)
	
	//Commenting out as we are not calculating the Angle Spread Footprint
	// calculate angle spread
		NVAR gImageMin = $("root:SPHINX:"+imageName+":gImageMin")
		NVAR gImageMax = $("root:SPHINX:"+imageName+":gImageMax")
		Variable angleSpread = gImageMax-gImageMin
	
	// calculate linear statistics
		WaveStats /Q imageWave
		Variable imageStdDev = V_sdev
		Variable imageMean = V_avg
	
	// calculate circular statistics
		statsCircularMoments /Q/ORGN=-90 /CYCL=180 imageWave
		WAVE circStats = $("W_CircularStats")
		Variable imageCircStdDev
		imageCircStdDev = circStats[10]
	
	// calculate FWHM
		Wave imageHist = $("root:SPHINX:"+imageName+":W_ImageHist")
		Variable maxValue = WaveMax(imageHist)
		Variable numPts = DimSize(imageHist,0)
		Variable FWHM
		
		FindLevel /Q/R=[0,numPts-1] imageHist, maxValue/2
		Variable FWHM_left 	= V_LevelX
	
		FindLevel /Q/R=[numPts-1,0] imageHist, maxValue/2
		Variable FWHM_right 	= V_LevelX		
		// Compute FWHM
		FWHM = FWHM_right - FWHM_left
		
	// calculate mode
		FindLevel /Q/R=[0,numPts-1] imageHist, maxValue
		Variable imageMode 	= V_LevelX
	
	// Print the results
		//Commenting out as we are not calculating the Angle Spread Footprint
		print fileName,"	",imageName,"	",angleSpread,"	",imageStdDev,"	",imageCircStdDev,"	",FWHM,"	",imageMean,"	",imageMode
		//print fileName,"	",imageName,"	",imageStdDev,"	",imageCircStdDev,"	",FWHM,"	",imageMean,"	",imageMode
End

Function organizeImageWindows()

	String screenRes = StringFromList(2,StringByKey("SCREEN1",igorinfo(0)),"=")
	Variable screenX = str2num(StringFromList(2,screenRes,","))
	Variable screenY = str2num(StringFromList(3,screenRes,","))
	
	GetWindow StackSlice_1, wsize
	Variable tileWidth = screenX-20
	Variable tileHeight = (V_bottom-V_top)*screenX/5/(V_right-V_left)

	Execute "TileWindows /A=(1,5)/W=(20,10,"+num2str(tileWidth)+","+num2str(tileHeight)+") StackStitchedImage,StackSlice_0,StackSlice_1,StackSlice_2,StackSlice_3"
	Execute "TileWindows /A=(1,5)/W=(20,"+num2str(tileHeight+10)+","+num2str(tileWidth)+","+num2str(2*tileHeight+10)+") StitchedImage_Hist,Slice_0_Hist,Slice_1_Hist,Slice_2_Hist,Slice_3_Hist"
	
	DoWindow /B ImageStitchingPanel

End

Function ImageStitchingCursorHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 	= H_Struct.winname
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	
	//print keyCode
	
	if (keycode == 0)
		return 0
	//Up
	elseif (keyCode == 30)
		ControlInfo moveUp
		if (V_disable == 0)
  			move2ndImage(0,1)
  		endif
  	//Down
  	elseif (keyCode == 31)
  		ControlInfo moveDown
		if (V_disable == 0)
  			move2ndImage(0,-1)
  		endif
  	//Right
  	elseif (keyCode == 29)
    		ControlInfo moveRight
		if (V_disable == 0)
  			move2ndImage(1,0)
  		endif
  	//Left
	elseif (keyCode == 28)
  		ControlInfo moveLeft
		if (V_disable == 0)
  			move2ndImage(-1,0)
  		endif
  	//SpaceBar
  	elseif (keyCode == 32)
  	  	ControlInfo toggle2ndImage
		if (V_disable == 0)
  			toggle2ndImage()
  		endif
  	//z
  	elseif (keyCode == 122)
  		NVAR stepSize = root:ImageStitch:stepSize
  		stepSize -=1
  	//x
  	elseif (keyCode == 120)
  		NVAR stepSize = root:ImageStitch:stepSize
  		stepSize += 1
  	//m
  	elseif (keyCode == 109)
  		ControlInfo mergeImages
		if (V_disable == 0)
			Button ExportStitchedImage, disable = 0
			Button calculateStatistics, disable = 0
			//Button organizeImageWindows, disable = 0
			mergeImages()
		endif
	//o
	//elseif (keyCode == 111)
	//	organizeImageWindows()
	endif
End

// *************************************************************
// ****	Button controls on the Polarization Analysis panel only
// *************************************************************
Function ImageStitchPanelButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	if (cmpstr(ctrlName,"loadFirstImage") == 0)
		if (loadFirstImage())
			Button loadSecondImage,disable=0
			SetVariable displayFactor,disable=2
		endif
	elseif (cmpstr(ctrlName,"loadSecondImage") == 0)
		if (loadSecondImage())
			Button moveUp,disable=0
			Button moveDown,disable=0
			Button moveRight,disable=0
			Button moveLeft, disable=0
			SetVariable stepSize, disable=0
			Button toggle2ndImage, disable=0
			Button mergeImages, disable=0
		endif
	elseif (cmpstr(ctrlName,"moveUp") == 0)
		move2ndImage(0,1)
	elseif (cmpstr(ctrlName,"moveDown") == 0)
		move2ndImage(0,-1)
	elseif (cmpstr(ctrlName,"moveRight") == 0)
		move2ndImage(1,0)
	elseif (cmpstr(ctrlName,"moveLeft") == 0)
		move2ndImage(-1,0)
	elseif (cmpstr(ctrlName,"toggle2ndImage") == 0)
		toggle2ndImage()
	elseif (cmpstr(ctrlName,"mergeImages") == 0)
		Button ExportStitchedImage, disable = 0
		Button calculateStatistics, disable = 0
		//Button organizeImageWindows, disable = 0
		mergeImages()
	elseif (cmpstr(ctrlName,"ExportStitchedImage") == 0)
		ExportStitchedImage()
	elseif (cmpstr(ctrlName,"calculateStatistics") == 0)
		calculateStatistics("StitchedImage")
	//elseif (cmpstr(ctrlName,"organizeImageWindows") == 0)
	//	organizeImageWindows()
	elseif (cmpstr(ctrlName,"hideImageStitchingPanel") == 0)
		DoWindow /B ImageStitchingPanel
	endif
End