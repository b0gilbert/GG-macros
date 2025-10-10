//Updated 9.5.2012 17:50

#pragma rtGlobals=1		// Use modern global access method.
// !*!*!*! Both ImageAlign.ipf and ImageStitching.ipf  were given the same ModelName, which led to a an error
// !*!*!*! Removing the one in ImageAlign.ipf
//#pragma ModuleName=file_IO

//==================================================================

Function AlignStack()

	NewDataFolder /O root:ALIGN
	SetDataFolder root:ALIGN
	
	// Select a stack to align
	MakeStringIfNeeded("root:ALIGN:gStackName","")
	SVAR gStackName 	= root:ALIGN:gStackName
	gStackName 	= ChooseStack(" Choose a stack to browse pixels",gStackName,0)
	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	
	if (WaveExists(SPHINXStack) == 1)
	 doAlignStackWindow()
	endif

End
	
Function doAlignStackWindow()

	SetDataFolder root:ALIGN

	SVAR gStackName 	= root:ALIGN:gStackName
	Duplicate /O $("root:SPHINX:Stacks:"+gStackName), root:ALIGN:imageStack /Wave=imageStack
	
	Variable /G DimZ = DimSize(imageStack,2)
	Variable /G gAnimateStack = 0
	Variable /G gThePlane = 0

	DoWindow /K $"StackAlignPanel"
	NewPanel /K=1/W=(10,10,810,610) as "Stack Alignment"
	DoWindow /C $"StackAlignPanel"
	CheckWindowPosition("StackAlignPanel",10,10,810,610)
	
	//	========			Panel Hooks
	SetWindow StackAlignPanel, hook(StackAlignPanelHooks)=StackAlignHooks
	
	//  	-------- 	Display the image
	Display/W=(0,0,600,600)/N=combinedImagePlot/HOST=# 
	AppendImage imageStack
	
	// Create wave for storing shifting factors for all images
	Make /O/N=(DimZ) root:ALIGN:imageShiftX /Wave=imageShiftX
	Make /O/N=(DimZ) root:ALIGN:imageShiftY /Wave=imageShiftY
	imageShiftY = 50
	imageShiftX = 50
	//Explode stack to separate Waves
	NewDataFolder /O root:ALIGN:imagePlanes
	SetDataFolder root:ALIGN:imagePlanes
	Variable i
	for (i=0;i<DimZ;i+=1)
		ImageTransform /P=(i) getPlane imageStack
		Duplicate /O/D M_ImagePlane $("imagePlane_"+num2str(i))
	endfor
	KillWaves M_ImagePlane
	// Shift the imageStack to allow some "negative" shifting in x- and y- directions
	ImageTransform /IOFF={50,50,NaN} offsetImage imageStack
	Duplicate /O M_OffsetImage imageStack
	ImageTransform /O /N={100,100} padImage imageStack
	KillWaves M_OffsetImage
	
	SetDataFolder root:ALIGN
	
	// Create buttons
	Button moveUp,pos={675,70}, size={40,19},fSize=12,proc=StackAlignPanelButtons,title="up"
	Button moveDown,pos={675,110}, size={40,19},fSize=12,proc=StackAlignPanelButtons,title="down"
	Button moveRight,pos={730,90}, size={40,19},fSize=12,proc=StackAlignPanelButtons,title="right"
	Button moveLeft,pos={620,90}, size={40,19},fSize=12,proc=StackAlignPanelButtons,title="left"
	Variable /G stepSize = 1
	SetVariable stepSize,title="Step",pos={660,90},limits={1,200,1},size={70,20},fsize=13,value=stepSize
	
	Button toggleImage,pos={610,140}, size={100,19},fSize=12,proc=StackAlignPanelButtons,title="Toggle Image"
	Variable /G gBaseFrame = 0
	SetVariable baseFrame,pos={710,140},size={80,19},limits={0,DimZ-1,1},variable=gBaseFrame,title="Base",frame=0//,disable=2,noedit=1
	
	Variable /G animateSpeed = 10
	SetVariable animationFrame,pos={610,160},size={80,19},limits={0,DimZ-1,1},proc=frameSelectorProc,variable=gThePlane,title="Frame",frame=1//,disable=2,noedit=1
	Slider animationSpeed,pos={730,180},size={62,143},limits={1,100,1},proc=animateSliderProc,variable = animateSpeed
	Button animateStack,pos={610,200}, size={100,19},fSize=12,proc=StackAlignPanelButtons,title="Animate Stack"
	
	Button acceptAlignedStack,pos={610,330}, size={100,30},fSize=12,proc=StackAlignPanelButtons,title="Accept Alignment"
	
End

Function AnimateStackTask(s)
	STRUCT WMBackgroundStruct &s
	
	NVAR gThePlane = root:ALIGN:gThePlane
	NVAR DimZ = root:ALIGN:DimZ
	
	ModifyImage /W=StackAlignPanel#combinedImagePlot imageStack, plane = gThePlane
	
	gThePlane += 1
	if (gThePlane >= DimZ)
		gThePlane = 0
	endif
	
	return 0	// Continue background task
End

Function AnimateStack()
	NVAR gAnimateStack = root:ALIGN:gAnimateStack
	NVAR animateSpeed = root:ALIGN:animateSpeed
	SVAR gStackName 	= root:ALIGN:gStackName
	WAVE imageStack	= root:ALIGN:imageStack
	
	if (gAnimateStack)
		CtrlNamedBackground AnimateStack, stop
		gAnimateStack = 0
	else
		Variable numTicks = floor(1/animateSpeed*100)		// Run every XX ticks (60 ticks per second)
		CtrlNamedBackground AnimateStack, period=numTicks, proc=AnimateStackTask
		CtrlNamedBackground AnimateStack, start
		gAnimateStack = 1
	endif
End

Function toggleImage(varDir)

	Variable varDir
	Variable destFrame = 0
	NVAR gThePlane = root:ALIGN:gThePlane
	NVAR gBaseFrame = root:ALIGN:gBaseFrame
	
	if (varDir == 1)
		destFrame = gBaseFrame
	elseif (varDir == 2)
		destFrame = gThePlane
	else
		return 0
	endif
	
	ModifyImage /W=StackAlignPanel#combinedImagePlot imageStack, plane = destFrame

End

Function moveImage(xShift,yShift)

	Variable xShift,yShift
	NVAR gThePlane = root:ALIGN:gThePlane
	NVAR stepSize = root:ALIGN:stepSize
	
	WAVE imageShiftX = root:ALIGN:imageShiftX
	WAVE imageShiftY = root:ALIGN:imageShiftY

	//Apply imageShift
	imageShiftX[gThePlane] += xShift*stepSize
	imageShiftY[gThePlane] += yShift*stepSize
	
	if (imageShiftX[gThePlane] < 0)
		imageShiftX[gThePlane] = 0
	endif
	if (imageShiftY[gThePlane] < 0)
		imageShiftY[gThePlane] = 0
	endif
	
	SVAR gStackName 	= root:ALIGN:gStackName
	WAVE imagePlane = $("root:ALIGN:imagePlanes:imagePlane_"+num2str(gThePlane))
	WAVE imageStack = root:ALIGN:imageStack
	
	ImageTransform/P=(gThePlane)/INSX=(imageShiftX[gThePlane])/INSY=(imageShiftY[gThePlane])/INSI=imagePlane insertImage imageStack
	
	ModifyImage /W=StackAlignPanel#combinedImagePlot imageStack, plane = gThePlane

End

Function acceptAlignedStack()
	
	WAVE imageShiftX = root:ALIGN:imageShiftX
	WAVE imageShiftY = root:ALIGN:imageShiftY
	
	SVAR gStackName 	= root:ALIGN:gStackName
	WAVE SPHINXStack = $("root:SPHINX:Stacks:"+gStackName)
	Variable DimX = DimSize(SPHINXStack,0)
	Variable DimY = DimSize(SPHINXStack,1)
	NVAR DimZ = root:ALIGN:DimZ
	
	Variable xMin,xMax,yMin,yMax,NEWxDim,NEWyDim,i
	WaveStats /Q/M=1 imageShiftX
		xMin = V_min
		xMax = V_max
	WaveStats /Q/M=1 imageShiftY
		yMin = V_min
		yMax = V_max
	//Add an offset of 50. This will be removed later with ImageTransform offsetImage
	NEWxDim = (xMin+DimX)-xMax+50
	NEWyDim = (yMin+DimY)-yMax+50
		
	Make /O/B/U/N=(NEWxDim,NEWyDim,DimZ) $("root:SPHINX:Stacks:a_"+gStackName) /WAVE=alignedStack
	
	for (i=0;i<DimZ;i+=1)
		WAVE imagePlane = $("root:ALIGN:imagePlanes:imagePlane_"+num2str(i))
		ImageTransform/P=(i)/INSX=(imageShiftX[i])/INSY=(imageShiftY[i])/INSI=imagePlane insertImage alignedStack
	endfor
	
	ImageTransform /IOFF={-50,-50,NaN} offsetImage alignedStack
	Duplicate /O/R=(0,NEWxDim-1)(0,NEWyDim-1) M_OffsetImage alignedStack
	KillWaves M_OffsetImage
	ImageTransform /O/N={-50,-50} padimage alignedStack
	
	print "Created New Aligned Stack: a_",gStackName
	
End

Function frameSelectorProc(ctrlName, varNum, varStr, varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	ModifyImage /W=StackAlignPanel#combinedImagePlot imageStack, plane = varNum
End

Function animateSliderProc(name, value, event) : SliderControl
	String name	// name of this slider control
	Variable value	// value of slider
	Variable event	// bit field: bit 0: value set; 1: mouse down, 
				//   2: mouse up, 3: mouse moved
				
	Variable numTicks = floor(1/value*100)		// Run every XX ticks (60 ticks per second)
	CtrlNamedBackground AnimateStack, period=numTicks, proc=AnimateStackTask
						
	return 0	// other return values reserved
End

Function StackAlignHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 	= H_Struct.winname
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	
	NVAR gAnimateStack = root:ALIGN:gAnimateStack
	
	//print keyCode
	//print eventCode
	
	if (eventCode == 2) 	// Window kill
		CtrlNamedBackground AnimateStack, stop
	elseif ((keycode == 0) || (keycode == 4))
		return 0
	elseif (gAnimateStack)
		return 0
	//Up
	elseif (keyCode == 30)
  		moveImage(0,1)
  	//Down
  	elseif (keyCode == 31)
  		moveImage(0,-1)
  	//Right
  	elseif (keyCode == 29)
  		moveImage(1,0)
  	//Left
	elseif (keyCode == 28)
  		moveImage(-1,0)
  	endif
End

// *************************************************************
// ****	Button controls on the Polarization Analysis panel only
// *************************************************************
Function StackAlignPanelButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	
	if (cmpstr(ctrlName,"toggleImage") == 0)
		if (eventCode == 1)
			toggleImage(1)
		elseif (eventCode == 2)
			toggleImage(2)
		else
			return 0
		endif
	endif
	
	NVAR gAnimateStack = root:ALIGN:gAnimateStack
	
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	if (cmpstr(ctrlName,"animateStack") == 0)
		AnimateStack()
	elseif (gAnimateStack)
		return 0
	elseif (cmpstr(ctrlName,"moveUp") == 0)
		moveImage(0,1)
	elseif (cmpstr(ctrlName,"moveDown") == 0)
		moveImage(0,-1)
	elseif (cmpstr(ctrlName,"moveRight") == 0)
		moveImage(1,0)
	elseif (cmpstr(ctrlName,"moveLeft") == 0)
		moveImage(-1,0)
	elseif (cmpstr(ctrlName,"acceptAlignedStack") == 0)
		acceptAlignedStack()
	endif
End