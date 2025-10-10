#pragma rtGlobals=1		// Use modern global access method.


// Test whether the ROI and analysis marquee region overlap
// Recall the the ROI should be ZERO for all points in the ROI, and any other value elsewhere. 
// Use ImageTransform "invert"

// 	A RECTANGULAR region is always required to delineate the region for component mapping. 
// SPHINX_StackBrowser
//		DefineSVDROI
//		MarqueeMenu
// 		MakeSPHINXROI
// 	*** 	This roi is called "<stackname>_roi"			 ** BUT THIS IS NOT REALLY NEEDED **
// 			More importantly, the corners of the analysis region are given by 4 global parameters, gSVDLeft, etc. 
// 			pixels inside the ROI are zero; outside are unity. 

// 	A free-hand shaped ROI is optional. 
// SPHINX_ROI
// 		ImageROIDraw
// 			This creates a ROIXY array with pairs of (x,y) values for the lines defining the ROI
// 		CreateImageROI
// 	*** 	This roi is called "<stackname>_av_roi"
//			pixels inside the ROI are zero; outside are unity. 

// Input here is the manually drawn "<stackname>_av_roi"
Function CheckROIMapping(ManualROI,ROIMapFlag,X1,X2,Y1,Y2)
	Wave ManualROI
	Variable ROIMapFlag,X1,X2,Y1,Y2

	if (ROIMapFlag)
		if (!WaveExists(ManualROI))
			DoAlert 0, "Please create an ROI or uncheck 'use-ROI' option"
			return 0
		else
			// Check whether the analysis area overlaps the manual ROI
			ImageStats /M=1/G={X1,X2,Y1,Y2} ManualROI
			if (V_avg == 1)
				DoAlert 0, "Please ensure the analysis area contains the ROI"
				return 0
			endif
		endif
	endif
	
	return ROIMapFlag
End






Function AppendROIControls(ImageName,WindowName,SubWindowName,ImageFolder,PanelFolder,NumX,NumY,CntrX,CntrY)
	String ImageName,WindowName,SubWindowName,ImageFolder,PanelFolder
	Variable NumX,NumY,CntrX,CntrY
	
	String ImageSubWindow = WindowName+"#"+SubWindowName
	
	// A hook to toggle between ROI-draw and normal state using keyboard press
	Variable /G $(PanelFolder+":gROIDraw")=0
	Variable /G $(PanelFolder+":gROIMove")=0
	Variable /G $(PanelFolder+":gROIStart")=0
	Variable /G $(PanelFolder+":gROINPts")=0
	Variable /G $(PanelFolder+":gROIX0")=0
	Variable /G $(PanelFolder+":gROIY0")=0
	
	DrawText 5,96,"Press d to draw ROI,"
	DrawText 5,109,"control-click to drag"

	SetWindow $WindowName, hook(ROIStateHook)=ImageROIState
	
	// Make a 2D wave for ROI X,Y values, much larger than conceivably needed
	Make /O/D/N=(1000,2) $(PanelFolder+":ROIXY")=0
	
	SetWindow $WindowName, hook(ROIDrawHook)=ImageROIDraw
	SetWindow $WindowName, hook(ROIMoveHook)=ImageROIMove
End


Function ImageROIDraw(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	// Variables from the Hook Structure
	String WindowName 	= H_Struct.winname
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	Variable ROIticks 		= H_Struct.ticks
	
	// Variables from the User Data
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 		= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	String subWName 		= StringByKey("subWName",GetUserData(PanelName,"",""),"=",";")
	
	// Check that the active subWindow is the image named in the UserData
	GetWindow $WindowName activeSW
	if (cmpstr(subWName,S_Value) != 0)
		return 0
	endif
	
	// Global Waves and Variables
	NVAR gROIDraw 		= $(PanelFolder+":gROIDraw") 
	NVAR gROIStart 			= $(PanelFolder+":gROIStart")
	NVAR gNPts 			= $(PanelFolder+":gROINPts")
	WAVE ROIXY 			= $(PanelFolder+":ROIXY")
	
	// Check that the ROI draw state is enabled
	if (!gROIDraw)
		return 0
	endif
	
	// Variables from the User Data
	String ImageName 		= StringByKey("ImageName",GetUserData(PanelName,"",""),"=",";")
	String ImageFolder 		= StringByKey("ImageFolder",GetUserData(PanelName,"",""),"=",";")
	Variable NumX 			= NumberByKey("ImageNumX",GetUserData(PanelName,"",""),"=",";")
	Variable NumY 			= NumberByKey("ImageNumY",GetUserData(PanelName,"",""),"=",";")
	
	// Local Variables
	Variable elapsed, lastX, lastY, mX, mY, pX, pY, distance
	Variable ROIDelay1 	= 5			// Neglect all mouse points after this short interval
	Variable ROIDelay2 	= 50		// Accept all mouse points after this interval, even if 'too close' to last point
	Variable ROIResn 	= 12
	
	// The coordinates in the PANEL. 
	mX 	= H_Struct.mouseLoc.h
	mY 	= H_Struct.mouseLoc.v
	
	// The pixel coordinates in the IMAGE
	pX 	= AxisValFromPixel(WindowName, "bottom", mX)
	pY 	= AxisValFromPixel(WindowName, "left", mY)
			
	// If the mouse lies outside the Image, finish the ROI draw
	if ((numtype(pX)==2) || (numtype(pY)==2))
		// FINISHING the ROI draw
		gROIDraw 		= 0
		gROIStart 		= 0
		CreateImageROI(WindowName,ImageName,ImageFolder,ROIXY,gNPts,NumX,NumY)
		
		return 1
	endif
	
	if (eventCode == 3) 			// Mouse down
		if (gROIStart == 0)
			// STARTING the ROI draw
			SetDrawLayer /W=$PanelName /K UserFront
			SetDrawEnv /W=$PanelName textrgb= (65535,0,52428),fstyle= 1
			DrawText /W=$PanelName 69,103,"ROI Active"
			
			SetDrawLayer /W=$WindowName /K UserFront
			gROIStart 		= ROIticks	// Record when the drawing began
			ROIXY 			= 0			// Reset the list of ROI X,Y coordinates
			ROIXY[0][0] 	= pX		// Record the first point
			ROIXY[0][1] 	= pY
			gNPts 			= 1
		else
			// FINISHING the ROI draw
			SetDrawLayer /W=$PanelName /K UserFront
			SetDrawEnv /W=$PanelName textrgb= (0,0,0),fstyle= 0
			DrawText /W=$PanelName 5,96,"Press d to draw ROI,"
			DrawText /W=$PanelName 5,109,"control-click to drag"
	
			gROIDraw 		= 0
			gROIStart 		= 0
			CreateImageROI(WindowName,ImageName,ImageFolder,ROIXY,gNPts,NumX,NumY)
		endif
		
		return 1
	endif
		
	if (eventCode == 4) 	// Mouse moved
		if (gROIStart == 0)
			return 0
		endif
		
		elapsed 	= (ROIticks - gROIStart)
		if (elapsed < ROIDelay1)
			return 0					// Insufficient time has elapsed
		endif
		
		lastX 		= ROIXY[gNPts-1][0]
		lastY 		= ROIXY[gNPts-1][1]
		distance		= sqrt((pX-lastX)^2 + (pY-lastY)^2)
			
		if ((distance < ROIResn) && (elapsed < ROIDelay2))
			return 0
		endif		
		
		// Add the new point to the XY list ... 
		ROIXY[gNPts][0] 	= pX
		ROIXY[gNPts][1] 	= pY
		gNPts += 1
		
		// ... and add a line segment to the image. 
		SetDrawLayer /W=$WindowName UserFront
		SetDrawEnv /W=$WindowName linefgc= (65535,0,52428),dash= 11,linethick= 2.00, xcoord=bottom, ycoord=left
		DrawLine /W=$WindowName lastX,lastY,pX,pY
		
		return 1
	endif
	
	return 0
End

Function ImageROIMove(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	// Variables from the Hook Structure
	String WindowName 	= H_Struct.winname
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	Variable ROIticks 		= H_Struct.ticks
	
	// Variables from the User Data
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 		= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	String subWName 		= StringByKey("subWName",GetUserData(PanelName,"",""),"=",";")
	
	// Check that the active subWindow is the image named in the UserData
	GetWindow $WindowName activeSW
	if (cmpstr(subWName,S_Value) != 0)
		return 0
	endif
	
	// Global Waves and Variables
	NVAR gROIMove 			= $(PanelFolder+":gROIMove") 
	NVAR gROIStart 			= $(PanelFolder+":gROIStart")
	NVAR gNPts 			= $(PanelFolder+":gROINPts")
	NVAR gX0 				= $(PanelFolder+":gROIX0")
	NVAR gY0 				= $(PanelFolder+":gROIY0")
	WAVE ROIXY 			= $(PanelFolder+":ROIXY")
	
	// Check that the control key is pressed
	if (!(GetKeyState(0) & 16))
		gROIMove = 0
		return 0
	endif
	
	// Check that an ROI has been creates
	if (gNPts==0)
		return 0
	endif
	
	// Variables from the User Data
	String ImageName 		= StringByKey("ImageName",GetUserData(PanelName,"",""),"=",";")
	String ImageFolder 		= StringByKey("ImageFolder",GetUserData(PanelName,"",""),"=",";")
	Variable NumX 			= NumberByKey("ImageNumX",GetUserData(PanelName,"",""),"=",";")
	Variable NumY 			= NumberByKey("ImageNumY",GetUserData(PanelName,"",""),"=",";")
	
	// Local Variables
	Variable elapsed, lastX, lastY, mX, mY, pX, pY, distance
	Variable ROIDelay1 	= 5			// Neglect all mouse points after this short interval
	Variable ROIDelay2 	= 50		// Accept all mouse points after this interval, even if 'too close' to last point
	Variable ROIResn 	= 1
	Variable dX, dY
	
	// The coordinates in the PANEL. 
	mX 	= H_Struct.mouseLoc.h
	mY 	= H_Struct.mouseLoc.v
	
	// The pixel coordinates in the IMAGE
	pX 	= AxisValFromPixel(WindowName, "bottom", mX)
	pY 	= AxisValFromPixel(WindowName, "left", mY)
	
	if (eventCode == 3) 			// Mouse down
		if (gROIMove == 0)			// STARTING the ROI move
			gROIMove 	= 1
			gROIStart 	= ROIticks	// Record when the drawing began
			gX0 		= pX
			gY0 		= pY
		
			return 1
		endif
	endif
	
	// If we have not started an ROI move, we can leave now. 
	if (gROIMove == 0)
		return 0
	endif
			
	// If the mouse lies outside the Image, finish the ROI move (if started)
	if ((numtype(pX)==2) || (numtype(pY)==2))
		gROIMove 		= 0			// FINISHING the ROI draw
		gROIStart 		= 0
		CreateImageROI(WindowName,ImageName,ImageFolder,ROIXY,gNPts,NumX,NumY)
		
		return 1
	endif
	
	if (eventCode == 5) 			// Mouse up
		gROIMove 		= 0			// FINISHING the ROI move
		gROIStart 		= 0
		CreateImageROI(WindowName,ImageName,ImageFolder,ROIXY,gNPts,NumX,NumY)
	
		return 1
	endif
		
	if (eventCode == 4) 			// Mouse moved
		
		elapsed 	= (ROIticks - gROIStart)
		if (elapsed < ROIDelay1)
			return 0				// Insufficient time has elapsed
		endif
		
		dX 			= (pX-gX0)
		dY 			= (pY-gY0)
		distance		= sqrt(dX^2 + dY^2)
			
		if ((distance < ROIResn) && (elapsed < ROIDelay2))
			return 0
		endif		
		
		// Update the ROI position
		ROIXY[0,gNPts-1][0] 	+= dX
		ROIXY[0,gNPts-1][1] 	+= dY
		CreateImageROI(WindowName,ImageName,ImageFolder,ROIXY,gNPts,NumX,NumY)
		
		// Reset the starting coordinates to the current mouse position
		gX0 		= pX
		gY0 		= pY
		
		return 1
	endif
	
	return 0
End

Function CreateImageROI(WindowName,ImageName,ImageFolder,ROIXY,NPts,NumX,NumY)
	String WindowName,ImageName,ImageFolder
	Wave ROIXY
	Variable NPts,NumX,NumY
	
	if (0)
		Print WindowName
		Print ImageName
		Print ImageFolder
		Print NPts,NumX,NumY
	endif
	
	if (WinType(WindowName) != 1)
		String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
		Print " *** ROI creation aborted"
		SetDrawLayer /W=$PanelName /K UserFront
		SetDrawEnv /W=$PanelName textrgb= (0,0,0),fstyle= 0
		DrawText /W=$PanelName 64,96,"Press d to"
		DrawText /W=$PanelName 63,109,"draw ROI"
		return 0
	endif
	
	Make /O/N=(NPts+1) $(ParseFilePath(2,ImageFolder,":",0,0)+"ROIX") /WAVE=ROIX
	Make /O/N=(NPts+1) $(ParseFilePath(2,ImageFolder,":",0,0)+"ROIY") /WAVE=ROIY
	
	ROIX[] 		= ROIXY[p][0]
	ROIY[] 		= ROIXY[p][1]
	
	ROIX[NPts] 	= ROIXY[0][0]
	ROIY[NPts] 	= ROIXY[0][1]
	
	// Remove the individual lines and draw a single ROI polygon
	SetDrawLayer /W=$WindowName /K UserFront
	SetDrawEnv /W=$WindowName linefgc= (65535,0,52428),fillpat= 0, xcoord=bottom, ycoord=left
	DrawPoly /W=$WindowName ROIX[0], ROIY[0], 1, 1, ROIX, ROIY
	
	ImageBoundaryToMask width=NumX, height=NumY, xwave=ROIX, ywave=ROIY, seedX=0, seedY=0
	WAVE M_ROIMask
	
	String ROIName = ParseFilePath(2,ImageFolder,":",0,0)+ImageName+"_roi"
	Duplicate /O M_ROIMask $(ParseFilePath(2,ImageFolder,":",0,0)+ImageName+"_roi")
	
	KillWaves /Z M_ROIMask
End

// Toggle between ROI-state active/inactive
Function ImageROIState(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 		= H_Struct.winname
	Variable eventCode 	= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	
	// *!*!*!* 2024-02-29
	WindowName 	= "StackBrowser"
	
	// Variables from the User Data
	String ImageName 		= StringByKey("ImageName",GetUserData(WindowName,"",""),"=",";")
	String subWName 		= StringByKey("subWName",GetUserData(WindowName,"",""),"=",";")
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 	= StringByKey("PanelFolder",GetUserData(WindowName,"",""),"=",";")
	
	// Global variables
	NVAR gROIDraw 		= $(PanelFolder+":gROIDraw")
	NVAR gROIStart 			= $(PanelFolder+":gROIStart")
	
	// Check that the active subWindow is the image named in the UserData
//	GetWindow $WindowName activeSW
	GetWindow $PanelName activeSW
	if (cmpstr(subWName,S_Value) != 0)
		return 0
	endif
	
//	print eventCode
	
	if (eventCode == 11) 	// Keyboard event. 
	
		if (keyCode == 100 || keyCode == 68)
			gROIDraw 	= !gROIDraw
			
			if (gROIDraw == 1)
				SetDrawLayer /W=$PanelName /K UserFront
				SetDrawEnv /W=$PanelName textrgb= (65535,0,52428),fstyle= 0
				DrawText /W=$PanelName 64,96,"Click to start"
				SetDrawEnv /W=$PanelName textrgb= (65535,0,52428),fstyle= 0
				DrawText /W=$PanelName 63,109,"drawing ROI"
			
				gROIStart = 0
			else
				// Abort ROI draw if the mouse leaves the image. 
				SetDrawLayer /W=$PanelName /K UserFront
				SetDrawEnv /W=$PanelName textrgb= (0,0,0),fstyle= 0
				DrawText /W=$PanelName 64,96,"Press d to"
				DrawText /W=$PanelName 63,109,"draw ROI"
			endif
			
			return 1
		endif
	endif
	
	return 0
End