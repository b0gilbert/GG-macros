#pragma rtGlobals=1		// Use modern global access method.

//Menu "Spectra"
//	SubMenu "Images"
//		"Show Nacre Analysis Panel"
//	End
//End

// *************************************************************
// ****		Nacre Image Analysis Routines
// *************************************************************

Function NewTabletInterface(WindowName,Xstart,Ystart)
	String WindowName
	Variable Xstart,Ystart

	// Read out data on folder and image locations. 
	String WindowFolder 	= StringByKey("WindowFolder",GetUserData(WindowName,"",""),"=",";")
	String ImageName 		= StringByKey("ImageName",GetUserData("","",""),"=",";")
	String ImageFolder 		= StringByKey("ImageFolder",GetUserData("","",""),"=",";")
	
	WAVE Nacre 			= $(ParseFilePath(2,ImageFolder,":",0,0)+ImageName)
	
	NVAR gNUserPts 		= $(WindowFolder+":gNUserPts")
	WAVE UserXs 			= $(WindowFolder+":UserXs")
	WAVE UserYs 			= $(WindowFolder+":UserYs")
	
//	gNUserPts += 1
//	Redimension /N=(gNUserPts) UserXs, UserYs
//	UserXs[gNUserPts-1] 	= UserX
//	UserYs[gNUserPts-1] 	= UserY
	
	Redimension /N=(1) UserXs, UserYs
	UserXs[0] 	= Xstart
	UserYs[0] 	= Ystart
	
	LayerInterface(Nacre,Xstart,Ystart)
End

Function LayerInterface(Nacre,Xstart,Ystart)
	Wave Nacre
	Variable Xstart,Ystart
	
	NVAR gHPx 	= root:SPECTRA:Plotting:Nacre:gHPx
	NVAR gVPx 	= root:SPECTRA:Plotting:Nacre:gVPx
	
	Make /O/D/N=(gHPx) LineOut=0, LineAvg=0
	Make /O/D/N=0 BXs, BYs, BSigX1, BSigX2, BSigXs
	
	Variable V_FitError, V_FitQuitReason, AcceptFit, BXo
	Variable i, j, kk=0, looop=1, hStart, iStart, iStop, vStart, jstart, jstop, NBs=0
	Variable hDelta 	= DimDelta(Nacre,0), hOffset = DimOffset(Nacre,0), halfHPx = floor(gHPx/2)
	Variable vDelta = DimDelta(Nacre,1), vOffset = DimOffset(Nacre,1), halfVPx = floor(gVPx/2)
	
	// Convert the mouse-click position from axis value to pixel
	// (ScaledDimPos - DimOffset(waveName, dim))/DimDelta(waveName,dim)
	hStart 	= trunc((Xstart - hOffset)/hDelta)
	vStart 	= trunc((Ystart - vOffset)/vDelta)
	
	// i indexes the horizontal line-out
	// For a straight boundary, hStart does not change
	iStart 	= floor(hStart - halfHPx)
	iStop 	= floor(hStart + halfHPx)
	
	// j indexes the vertical line-outs to be averaged. 
	// Increment this by one pixel to survey up a line. 
	jStart 	= floor(vStart - halfVPx)
	jStop 	= floor(vStart + halfVPx)
	
//	print " Integrating horizontally from",iStart,"to",iStop
//	print " Integrating vertically from",jStart,"to",jStop

	do
		// ---------------------------------------------------------\\
		LineAvg 	= 0
		for (j=jStart;j<=jStop;j+=1)
			for (i=iStart;i<=iStop;i+=1)
				if (Nacre[i][j] == 255)
					looop = 0
					return 1
				endif
				LineOut[i-iStart] 	= Nacre[i][j]
			endfor
			LineAvg += LineOut
		endfor
		LineAvg /= (jStop-jStart+1)
		
		// Option: 
		
		Make /O/T T_Constraints = {"K1<0","K2 > 100"}
		V_FitError = 0
		// Note: could fit to mimized the sum of the absolute deviations
		CurveFit /Q/M=2/N/W=2 gauss, LineAvg/D /C=T_Constraints
		WAVE W_coef 	= W_coef
		WAVE W_sigma 	= W_sigma
		DoUpdate /W=Graph0
		
		AcceptFit = 1
		if (W_coef[2]<0 || W_coef[2]>gHPx)
			// The minimum must lie within the fit range. 
			AcceptFit = 0
		elseif (V_FitError == 1)
			AcceptFit = 0
		elseif (numtype(W_sigma[2]) != 0)
			AcceptFit = 0
		elseif (W_sigma[2] > 1)
			AcceptFit = 0
		endif
		
		if (AcceptFit)
			// Record the results of the fit. 
			NBs += 1
			Redimension /N=(NBs) BXs, BYs, BSigXs, BSigX1, BSigX2
			BYs[NBs] 		= vOffset + vDelta*vStart
			BXs[NBs] 		= hOffset + hDelta*(iStart+W_coef[2])
			BSigXs[NBs] 	= hOffset + hDelta*W_sigma[2]
			BSigX1[NBs] 	= hOffset + hDelta*(iStart+W_coef[2] - W_sigma[2])
			BSigX2[NBs] 	= hOffset + hDelta*(iStart+W_coef[2] + W_sigma[2])
			
			// Allow the horizontal fit range to stray 
			if (abs(W_coef[2]-halfHPx) < (halfHPx/3))
//				print " 		center shift by", abs(W_coef[2]-halfHPx)
				hStart = iStart+W_coef[2]
				iStart 	= floor(hStart - halfHPx)
				iStop 	= floor(hStart + halfHPx)
			endif
		endif
		// ---------------------------------------------------------\\
		
		kk += 1
		vStart 	+= 1
		jStart 	+=1
		jStop 	+= 1
		
		if (kk == 800)
			looop = 0
		endif
		
	while(looop)
End


Function NacreHookProc(H_Struct)
	STRUCT WMWinHookStruct &H_Struct 

	Variable keyCode 		= H_Struct.keyCode
	Variable eventCode		= H_Struct.eventCode
	Variable Modifier 		= H_Struct.eventMod
	
	Variable CmdBit 		= 3
	Variable statusCode 		= 0
	Variable px, py, Xvalue, Yvalue
	
	if (eventCode == 3) 		// mousedown
		px=H_Struct.mouseLoc.h
		py=H_Struct.mouseLoc.v
		
		Xvalue 	= AxisValFromPixel(H_Struct.winName, "top", px)
		Yvalue 	= AxisValFromPixel(H_Struct.winName, "left", py)
			
		if (GetKeyState(0) & 4) 	// Shift down. 
			// Read out the name of this window
			String WindowName 	= StringByKey("WindowName",GetUserData("","",""),"=",";")
			
			NewTabletInterface(WindowName,Xvalue, Yvalue)
		endif
	endif
	
	
//	curX=AxisValFromPixel(s.winName, "top", px)
//	curY=AxisValFromPixel(s.winName, "left", py)
				
//	String info=TraceFromPixel(px,py,"")
//	if(strlen(info)>0)
//	lastIndex=NumberByKey("HITPOINT", info , ":")
//	row=mod(lastIndex,rows)
//	col=trunc(lastIndex/rows)
//	endif

	return statusCode		// 0 if nothing done, else 1
End

//PixelFromAxisVal, TraceFromPixel


// *************************************************************
// ****		Nacre Image Plot
// *************************************************************

Function PlotImageAnalysisWindow(DataAndFolderName)
	String DataAndFolderName
	
	String DataFolder, AxisFolder, Data2DName,  AxisName, Axis2Name, Axis2DxName, Axis2DyName, XLabel2D, YLabel2D, ZLabel2D
	
	DataFolder 		= ParseFilePath(1,DataAndFolderName,":",1,0)
	Data2DName 	= AnyNameFromDataName(DataAndFolderName,"2D")
	
	// The proper x-axis
	AxisFolder 		= ParseFilePath(1,DataFolder,":",1,0)
	AxisName 		= AxisFolder + AnyNameFromDataName(ParseFilePath(3,DataAndFolderName,":",0,0),"axis")
	
	// The other axes
	Axis2Name 		= AnyNameFromDataName(DataAndFolderName,"axis2")
	Axis2DxName 	= AnyNameFromDataName(DataAndFolderName,"2Dx")
//	Axis2DyName 	= AnyNameFromDataName(DataAndFolderName,"2Dy")
//	
//	XLabel2D 		= "Distance (pixels)"
//	YLabel2D 		= "Distance (pixels)"
//	ZLabel2D 		= "Intensity"

	WAVE NacreImage 	= $DataAndFolderName
	WAVE NacreAxis 	= $AxisName
	WAVE NacreAxis2 	= $Axis2Name
	
	Variable NumX 	= DimSize(NacreAxis,0)
	Variable NumY 	= DimSize(NacreAxis2,0)
	
	String Filename, WindowName, WindowFolder 
	Filename 	= ReturnTextBeforeNthChar(Note($DataAndFolderName),"\r",1)
	
	
	NewImage/K=1/S=1 $DataAndFolderName
	WindowName 	= ReplaceString("Graph",WinName(0,1),"Image")
	WindowFolder = "root:SPECTRA:Plotting:"+WindowName
	
	DoWindow /C $WindowName
	DoWindow /T $WindowName, Filename
	SetWindow $WindowName hook(NacreHook)=NacreHookProc

	// Give this Window all the information it needs about the displayed image
	SetWindow $WindowName,userdata= "WindowName="+WindowName+";"
	SetWindow $WindowName,userdata+= "WindowFolder="+WindowFolder+";"
	SetWindow $WindowName,userdata+= "ImageName="+NameOfWave(NacreImage)+";"
	SetWindow $WindowName,userdata+= "ImageFolder="+DataFolder+";"
	
	NewDataFolder /S/O $WindowFolder
		// Make the waves and variables that are needed. 
		
		Duplicate /O/D NacreImage, NacreLines
		
		Variable /G gNUserPts=0
		
		// displaying these points ensures SetAxis /A works for both image and plotted points. 
		Make /O/N=4 CornerXs, CornerYs
		CornerXs[0] = 0; CornerYs[0] = 0
		CornerXs[1] = NacreAxis[NumX-1]; CornerYs[1] = 0
		CornerXs[2] = 0; CornerYs[2] = NacreAxis2[NumY-1]
		CornerXs[3] = NacreAxis[NumX-1]; CornerYs[3] = NacreAxis2[NumY-1]
		AppendToGraph /W=$WindowName CornerYs vs CornerXs
		ModifyGraph lSize(CornerYs)=0
		
		Make /O/N=(0) UserXs, UserYs
		AppendToGraph /W=$WindowName UserYs vs UserXs
		ModifyGraph/W=$WindowName mode(UserYs)=3,marker(UserYs)=1
		
		ModifyGraph mirror(left)=1,axThick=1,standoff=0, nticks=0
		
		SetAxis bottom 0, NacreAxis[DimSize(NacreAxis,0)-1]
		SetAxis left 0, NacreAxis2[DimSize(NacreAxis2,0)-1]
	
	SetDataFolder root:
	
	NacreAnalysisPanel($DataAndFolderName,WindowName, WindowFolder)
End

// *************************************************************
// ****		Nacre Image Panel
// *************************************************************
Function NacreAnalysisPanel(NacreImage, WindowName, WindowFolder)
	Wave NacreImage
	String WindowName, WindowFolder
	
	DoWindow NacrePanel
	if (V_flag)
		DoWindow /F NacrePanel
		return 1
	endif
	
	NewPanel /K=1/W=(6,6,206,906)/N=NacrePanel as "Nacre Table Thickness"
	
	String NacreFolder 	= "root:SPECTRA:Plotting:Nacre"
	
	NewDataFolder/O/S root:SPECTRA:Plotting:Nacre
		
		Variable /G gHPx 	= 23
		SetVariable NCR_HPxSetVar,title="Horizontal pixels",fSize=11,pos={15,80},limits={1,inf,2 },size={120,16},value= $(NacreFolder+":gHPx")
		
		Variable /G gVPx 	= 11
		SetVariable NCR_VPxSetVar,title="Vertical pixels",fSize=11,pos={15,100},limits={1,inf,2 },size={120,16},value= $(NacreFolder+":gVPx")		
End

Function ShowNacreAnalysisPanel()

	DoWindow NacrePanel
	if (V_flag)
		DoWindow /F NacrePanel
	endif
End