// Updated 07.21.2015 19:51
#pragma rtGlobals=1		// Use modern global access method.

#include "PELICAN_Gizmo"
#include "PELICAN_Angles"

// See Word Manual for details! 

Menu "PELICAN"
	"Pelican/1"
	"Display PELICAN RGB/2"
	"Pelican Scale Circle"
	"Display PELICAN Histograms"
	"Display PELICAN Gizmo"
	"Export PELICAN Figures/E"
	"Export PELICAN Color Bar"
	"Calculate Neighbor Angles/G"
	"Kill Histograms"
End


// ***************************************************************************
// *************** MAIN PELICAN FUNCTION
// ***************************************************************************

Function Pelican()
	
	PathInfo PELIDefaultsPath
	if (V_flag==0)
//		NewPath /O/Q PELIDefaultsPath
		NewPath/O PELIDefaultsPath "PGilbert_HD:Users:pupa:Library:CloudStorage:Dropbox:Igor Routines:Igor Pro 7 User Files:User Procedures:POLARIZATION:PELICAN Defaults:"
	endif

	String StackFolder = "root:SPHINX:Stacks"
	String POLFolder 	= "root:POLARIZATION"

	SVAR gStackName = root:SPHINX:Browser:gStackName
	WAVE XStack 		= $(StackFolder+":"+gStackName)
	If (!WaveExists(XStack))
		print " *** Please load a stack" 
		return 0
		DoWindow StackBrowser
		if (V_flag != 1)
			print " *** Please display a stack" 
			return 0
		endif
	endif
	
	NewDataFolder /O/S $POLFolder
		NewDataFolder /O Analysis
		Make /O/N=(3) NumData				// Need (?) to record the stack size here. 
		NumData[] = DimSize(XStack,p)
		
		ConvertXrayAxisToAngle()
		
	SetDataFolder root: 
	
	DoWindow /K $("RGB_"+gStackName)
	DoWindow /K PolarizationAnalysis
	DoWindow /K PeliPanel
	DoWindow /K RGB_PELICAN
	DoWindow /K GizmoPeli
	
	KillPELICANHistograms()
	
	MakePELICANWaves()
	
	// 2024-01 Enforce default variables upon (re)launching Pelican
	MakePELICANVariables()

	PELICANPanel(SPHINXStack,"PELICAN Panel: "+gStackName,"root:SPHINX:RGB_"+gStackName,NumData[2])
	
	PelicanColorScaleBar()
	
	PelicanScaleCircle()
		
	return 1
End

// ***************************************************************************
// **************** 	Default Variables
// ***************************************************************************

Function MakePELICANVariables()

	if (ImportPELICANDefaults() > -1)
	
		WAVE PELIParameters = root:POLARIZATION:PELIParameters
		
		// The a, b and Phizy min angles
		Variable /G root:POLARIZATION:gAmax 					= PELIParameters[0]
		Variable /G root:POLARIZATION:gBmin 					= PELIParameters[1]
		Variable /G root:POLARIZATION:gBmax 					= PELIParameters[2]
		Variable /G root:POLARIZATION:gPhiZYMin 			= PELIParameters[3]
	
		// Default display Phi and Theta
		Variable /G root:POLARIZATION:gPhiSPmin 			= PELIParameters[4]
		Variable /G root:POLARIZATION:gPhiSPmax 			= PELIParameters[5]
		Variable /G root:POLARIZATION:gThetaSPmin 			= PELIParameters[6]
		Variable /G root:POLARIZATION:gThetaSPmax 			= PELIParameters[7]
		
		Variable /G root:POLARIZATION:gPhiDisplayChoice 	= PELIParameters[8]
		
		Variable /G root:POLARIZATION:gThetaAxisZero 		= PELIParameters[9]
		
		Variable /G root:POLARIZATION:gDark2Light 			= PELIParameters[10]
		
		Variable /G root:POLARIZATION:gSwapPhiTheta 		= PELIParameters[11]
		
		Variable /G root:POLARIZATION:gColorOffset 		= PELIParameters[12]
		
		Variable /G root:POLARIZATION:gAutoColor 			= PELIParameters[13]
		
		Variable /G root:POLARIZATION:gDisplayBMax 		= PELIParameters[14]
	else 

		// The a, b and Phizy min angles
		Variable /G root:POLARIZATION:gAmax = 1
		Variable /G root:POLARIZATION:gBmin = 1
		Variable /G root:POLARIZATION:gBmax = 120
		Variable /G root:POLARIZATION:gPhiZYMin = 45
	
		// Default display Phi and Theta
		Variable /G root:POLARIZATION:gPhiSPmin = 50
		Variable /G root:POLARIZATION:gPhiSPmax = 120
		Variable /G root:POLARIZATION:gThetaSPmin = -45
		Variable /G root:POLARIZATION:gThetaSPmax = 45
	
		Variable /G root:POLARIZATION:gLightMax = 65535/2
		
		Variable /G root:POLARIZATION:gDark2Light = 2
		
		Variable /G root:POLARIZATION:gSwapPhiTheta = 1
		
		Variable /G root:POLARIZATION:gColorOffset = 0.7
		
		Variable /G root:POLARIZATION:gDisplayBMax = 150
		
	endif
	
	Variable /G root:POLARIZATION:gLightMax = 65535/2
		
	Variable /G root:POLARIZATION:gPauseUpdate = 0
	
	// Options to use a mask when performing neighbor misorientation angle calculation. 
	// 1 = use bMin 2 = Current user mask, 3 = Load user mask 4 = none, 5 = bMin+
	Variable /G root:POLARIZATION:gANGLEMASK = 3	
	
	WAVE HistBMaxBar 	= root:POLARIZATION:HistBMaxBar
	if (WaveExists(HistBMaxBar))
		Variable AMax = NumVarOrDefault("root:POLARIZATION:gAmax",1)
		Variable BMin = NumVarOrDefault("root:POLARIZATION:gBMin",1)
		Variable BMax = NumVarOrDefault("root:POLARIZATION:gBmax",1)
		Setscale /P x, (Amax), 1, root:POLARIZATION:HistAMaxBar
		Setscale /P x, (Bmin), 1, root:POLARIZATION:HistBMinBar
		Setscale /P x, (Bmax), 1, root:POLARIZATION:HistBMaxBar
	endif
	
	// ClearPol mean Delete prior Polarization calculations. Intended when doing calculations on a subset of the image. 
	MakeVariableIfNeeded("root:POLARIZATION:gClearPol",0)
	
End

Function ExportPELICANDefaults()
	
	String WaveStrings 	= "PeliLegend;PeliParameters;"
	
	PathInfo PELIDefaultsPath
	if (V_flag==0)
		print " please press Ctrl-1 and create the path to the default" 
	endif
	
	SetDatafolder root:POLARIZATION
		SaveData /Q/O/J=WaveStrings /P=PELIDefaultsPath "defaults.pxp"
	SetDatafolder root:
End

Function ImportPELICANDefaults()

	String WaveStrings 	= "PeliLegend;PeliParameters;"
	
	SetDatafolder root:POLARIZATION
		LoadData /Q/O/J=WaveStrings /P=PELIDefaultsPath "defaults.pxp"
		if (V_flag==2)
			print " 	Loaded PELICAN default settings"
		else
			print " 	problem loading PELICAN default settings"
		endif
	SetDatafolder root:
	
	return V_flag
End
// ***************************************************************************
// **************** 	THE MAIN PELICAN CALCULATION PANEL
// ***************************************************************************

Function PELICANPanel(SPHINXStack,Title,Folder,NumE)
	Wave SPHINXStack
	String Title,Folder
	Variable NumE

	// Locations of panel globals
	String PanelFolder 	= Folder
	
	DoWindow /K PeliPanel
	NewPanel /K=1/W=(872,53,1172,558) as Title
	Dowindow /C PeliPanel
	
	DoUpdate /W=PeliPanel /SPIN=10
	
	NewDataFolder /O/S root:POLARIZATION:Analysis
	Make /O/D/N=(NumE) spectrum,fit_spectrum

	// Create the Plot of Extracted Spectra
	Display/W=(0,335,300,505)/HOST=# spectrum vs root:POLARIZATION:angles
	ModifyGraph mode(spectrum)=3,marker(spectrum)=8
	AppendToGraph fit_spectrum vs root:POLARIZATION:angles
	ModifyGraph rgb(fit_spectrum)=(0,0,65535)
	AppendToGraph root:POLARIZATION:Analysis:Cos2Fit
	ModifyGraph rgb(Cos2Fit)=(1,39321,19939)
	Label bottom "\\Z11X-ray Polarization Angle"
	SetAxis left 0,280
	SetAxis bottom -90,180
	AppendToGraph /R root:POLARIZATION:PhiPolBars
	SetAxis right 0,*
	ModifyGraph mode(PhiPolBars)=1,lsize(PhiPolBars)=3,rgb(PhiPolBars)=(0,0,0,19661)
	RenameWindow #, PixelPlot
	SetActiveSubwindow ##
		Display/W=(150,0,300,329)/HOST=#
	RenameWindow #, PixelData
	
	// Populate an initial single pixel plot
	PixelPELICAN()
	
	// Group Box and Buttons
	GroupBox PolAnalyzeGroup,pos={8,0},size={137,115}, fSize=13, title="Pol Analysis",fColor=(39321,1,1)
	GroupBox PolDisplayGroup,pos={8,132},size={137,198}, fSize=13, title="Pol Display",fColor=(39321,1,1)
	
	ValDisplay PolPixelX title="X",pos={15,34},size={50,15},fSize=13,value=#"root:SPHINX:Browser:gCursorAX"
	ValDisplay PolPixelY title="Y",pos={73,34},size={50,15},fSize=13,value=#"root:SPHINX:Browser:gCursorAY"
	
	Button AnalyzePixel,pos={15,17}, size={100,19},fSize=13,proc=PELICANButtons,title="Pixel"
	Button AnalyzeStack,pos={15,75}, size={100,19},fSize=13,proc=PELICANButtons,title="Stack"
	
	//	Button AnalyzeROI,pos={15,54}, size={40,19},fSize=13,proc=PELICANButtons,title="ROI"
	//	MakeVariableIfNeeded("root:SPHINX:SVD:gROIMappingFlag",0)	// Use existing ROI mask
	//	CheckBox SVDROICheck,pos={74,53},size={114,17},title="pink",fSize=13,variable=$("root:SPHINX:SVD:gROIMappingFlag")
	
	MakeVariableIfNeeded("root:POLARIZATION:gClearPol",0)	// Use existing ROI mask
	CheckBox POLClearCheck_1 title="Clear prior maps",pos={17,92},size={45,16},variable=root:POLARIZATION:gClearPol,fSize=13
	
	// These are important parameters that dynamically update pixel or stack angle calculations. 
	
	MakeVariableIfNeeded("root:POLARIZATION:gMarqueeRGB",1)	// Only adjust RGB contrast of the analysis marquee area
	PopupMenu PolABMenu pos={61,150},value="pixel;stack;substack;", proc=PelicanPanelMenus, mode=2
	NVAR gAmax 			= root:POLARIZATION:gAmax
	
	SetVariable POLSet_Amax,title="\\Z20\\F'Times New Roman'\\f02\\K(29524,1,58982)a\\Bmax",pos={26,175},limits={1,1000,5},size={90,98},fsize=13,proc=SetAnB,value=gAmax
	MakeVariableIfNeeded("root:POLARIZATION:gBmin",0)
	NVAR gBmin 			= root:POLARIZATION:gBmin
	SetVariable POLSet_Bmin,title="\\Z20\\F'Times New Roman'\\f02\\K(65535,0,0)b\\Bmin",pos={26,209},limits={0,1000,5},size={90,98},fsize=13,proc=SetAnB,value=gBmin
	NVAR gBmax 			= root:POLARIZATION:gBmax
	SetVariable POLSet_Bmax,title="\\Z20\\F'Times New Roman'\\f02\\K(65535,0,0)b\\Bmax",pos={26,245},limits={0,1000,5},size={90,98},fsize=13,proc=SetAnB,value=gBmax
	MakeVariableIfNeeded("root:POLARIZATION:gPhiZYMin",0)
	NVAR gPhiZYMin 		= root:POLARIZATION:gPhiZYMin
	SetVariable POLSet_gPhiZYMin,title="\Z14𝜙\Bzy min",pos={17,280},limits={-180,90,1},size={105,118},fsize=13,proc=SetAnB,value=gPhiZYMin

	//	NVAR gThetaSPRot 	= root:POLARIZATION:gThetaSPRot
	//	SetVariable POLSet_gThetaSPRot,title="\Z14𝜃\Bsp min",pos={26,182},limits={0,1000,5},size={90,98},fsize=13,proc=SetAnB,value=gThetaSPRot

End

Function PELICANButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	if (cmpstr(ctrlName,"AnalyzePixel") == 0)
		PixelPELICAN()				// This shows how c-axis angles vary depending on inputs: Amax, Bmax, Phi range
	elseif (cmpstr(ctrlName,"AnalyzeStack") == 0)
		StackPELICAN()							// This is the longest step, only needs doing once. 
		Projection2SphericalPolars()			// This generates c-axis spherical polars depending on variable inputs
		CreatePELICAN1DHistograms()			// Show how the c-axis angles vary depending on inputs
		CreatePELICAN2DHistograms()
		ShowPELICANResultPanel()					// Convert PhiSP and ThetaSP to Hue and Lightness, depending on inputs, and create RGB map
	elseif(cmpstr(ctrlName,"ImageSaveButton") == 0)
		ExportPELICANFigures()
	endif
	
	if (cmpstr(ctrlName,"AutoRGBButton") == 0)
		AutoAdjustPelicanRGB()
	elseif (cmpstr(ctrlName,"SaveDefaultsButton") == 0)
		CreatePeliSettingsTable()
		ExportPELICANDefaults()
	endif
End

Function PelicanPanelChecks(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			AdjustPELICANRGB()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function PelicanPanelMenus(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	String panelName 		= PU_Struct.win
	String ctrlName 		= PU_Struct.ctrlName
	Variable eventCode 	= PU_Struct.eventCode
	
	NVAR gMarqueeRGB 		= root:POLARIZATION:gMarqueeRGB
	NVAR gPhiDisplayChoice 	= root:POLARIZATION:gPhiDisplayChoice
	NVAR gDark2Light 		= root:POLARIZATION:gDark2Light
	NVAR gThetaAxisZero 	= root:POLARIZATION:gThetaAxisZero
	
	if (eventCode < 0)
		return 0	// This is needed!!
	endif
	
	if (eventCode == 2) // Mouse up
		if (cmpstr(ctrlName,"PolABMenu")==0)
			gMarqueeRGB 	= (PU_Struct.popNum == 3) ? 1 : 0
		else
		
			if (cmpstr(ctrlName,"PhiDisplayMenu")==0)
				gPhiDisplayChoice 	= PU_Struct.popNum
			elseif (cmpstr(ctrlName,"ThetaDisplayMenu1")==0)
				gDark2Light 	= PU_Struct.popNum
				PelicanColorScaleBar()
				PelicanScaleCircle()
			elseif (cmpstr(ctrlName,"ThetaDisplayMenu2")==0)
				gThetaAxisZero 	= PU_Struct.popNum
			endif
			
			PELICANDisplayUpdate()
			
			AdjustPELICANRGB()
			
			if ((gPhiDisplayChoice==3) || (gThetaAxisZero==3))
				// DisplayPELICANAlphBetaHistograms()
			endif
		endif
	endif
End

// ***************************************************************************
// **************** 	Image Masking
// ***************************************************************************

Function DisplayPeliMask()
	
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	
	String MaskName 		= gStackName+"_mask"
	String MaskFullName 	= "root:SPHINX:Stacks:"+gStackName+"_mask"
	WAVE AngleMask 		= $MaskFullName
	if (!WaveExists(AngleMask))
		return 0
	endif

	KillWindow /Z AngleMaskDisplay
		//Display /K=1/W=(1341,275,1825,814) as "User mask"
		Display /K=1/W=(912,928,1396,1467) as "User mask"
	DoWindow /C AngleMaskDisplay
	
	AppendImage/T $MaskFullName
	ModifyImage $MaskName ctab= {*,*,Grays,0}
	ModifyGraph margin(left)=14,margin(bottom)=14,margin(top)=14,margin(right)=14,gFont="Helvetica"
	ModifyGraph mirror=2
	ModifyGraph nticks=19
	ModifyGraph minor=1
	ModifyGraph fSize=9
	ModifyGraph standoff=0
	ModifyGraph tkLblRot(left)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
End

// ***************************************************************************
// **************** 	SPHERICAL POLAR FUNCTIONS
// ***************************************************************************

Function SetAnB(SV_Struct) 
	STRUCT WMSetVariableAction &SV_Struct 
	
	String WindowName 	= SV_Struct.win
	String ctrlName 		= SV_Struct.ctrlName
	Variable varNum 		= SV_Struct.dval
	
	Variable eventCode 	= SV_Struct.eventCode
	if (eventCode == -1)
		return 0
	endif
	
	Variable UpdateFlag = 0
	switch( eventCode )
		case 1: // mouse up
			UpdateFlag = 1
		case 2: // Enter key
			UpdateFlag = 1
	endswitch
	
//	StopAllMSTimers()
//	Variable MS0 = startMSTimer
//	Variable MS1 = startMSTimer
//	Variable MS2 = startMSTimer
//	Variable MS3 = startMSTimer
//	Variable MS4 = startMSTimer
	
	if (UpdateFlag)
		String ABName = ParseFilePath(0,ctrlName,"_",1,0)
		WAVE HistBar 	= $("root:POLARIZATION:Hist"+ABName+"Bar")
		if (WaveExists(HistBar))
			Setscale /P x, (varNum), 1, HistBar
		endif
			
		ControlInfo PolABMenu
		if (V_Value == 1)
			PixelPELICAN()							// New pixel calculation of c-axis angles
		else
			DoUpdate /W=PeliPanel /SPIN=2
//			Variable MSOt 	= StopMSTimer(MS0)
			Projection2SphericalPolars()			// New stack calculation of c-axis angles
//			Variable MS1t 	= StopMSTimer(MS1)
			CreatePELICAN1DHistograms()
//			Variable MS2t 	= StopMSTimer(MS2)
			CreatePELICAN2DHistograms()
//			Variable MS3t 	= StopMSTimer(MS3)
			AdjustPELICANRGB()
//			Variable MS4t 	= StopMSTimer(MS4)
		endif
		
//		print "durations are",MSOt/1e6,"s, ",MS1t/1e6,"s, ",MS2t/1e6,"s, ",MS3t/1e6,"s, ",MS4t/1e6,"s, "
		Variable PixelFlag=1
		GizmoPeli_CsrVector(PixelFlag)
	endif
End

// The is the Main Algorithm that converts a, b, and PhiPol to Spherical Polars. 
// This function will run every time any variable is updated. 
Function Projection2SphericalPolars()

	String StackFolder = "root:SPHINX:Stacks"
	WAVE /D POL_RZYPrime 	= $(StackFolder+":POL_RZYPrime")
	if (!WaveExists(POL_RZYPrime))
		MakePELICANWaves()
	endif
	
	String POLFolder 		= "root:POLARIZATION"
	NVAR Amax 			= $(POLFolder+":gAmax")
	NVAR Bmax 				= $(POLFolder+":gBmax")
	NVAR Bmin 				= $(POLFolder+":gBmin")
	NVAR gPhiZYMin 		= $(POLFolder+":gPhiZYMin")
	
	// These arrays are calculated by Analyze ROI/Stack
	WAVE POL_AA 		= $(StackFolder+":POL_AA")
	WAVE POL_BB 			= $(StackFolder+":POL_BB")
	WAVE POL_PhiPol 		= $(StackFolder+":POL_PhiPol")
	
	// These arrays are calculated below
	WAVE POL_Rpol 		= $(StackFolder+":POL_Rpol")
	WAVE POL_RZY 		= $(StackFolder+":POL_RZY")
	WAVE POL_RZYSat 	= $(StackFolder+":POL_RZYSat")
	WAVE POL_RZYPrime 	= $(StackFolder+":POL_RZYPrime")
	WAVE POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
	
	// The c-axis vectors in Sperical Polars with Theta relative to the X-ray axis
	WAVE POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
	WAVE POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
	
	// The c-axis vectors in Sperical Polars with Theta relative to the Sample Normal
	WAVE POL_ThetaSample 	= $(StackFolder+":POL_ThetaSample")
	
	// The proection of the c-axis vectors onto the Sample Surface
	WAVE POL_AlphaSample 	= $(StackFolder+":POL_AlphaSample")
	WAVE POL_BetaSample 		= $(StackFolder+":POL_BetaSample")


	// The projection of the c-axis vector onto the POL plane. Can be updated dynamically with Amax and Bmax
	if (1)
		POL_Rpol[][] 		= POL_BB[p][q]/Bmax																					// Plot this as Rb
	else
		POL_Rpol[][] 		= 1-exp(1/(Bmax) + 1/(POL_BB[p][q]-Bmax))
	endif
		
	// Only apply the Intensity correction if Amax > 1 and if the fitted a < Amax
	if (Amax > 1)
		POL_RZY[][] 	= (POL_AA[p][q] < Amax) ? (Amax/POL_AA[p][q]) * POL_Rpol[p][q] : POL_Rpol[p][q] 		// Plot this as Rba
	else
		POL_RZY 		= POL_Rpol
	endif
	
	if (0)
		POL_RZYSat[][] 	= (POL_RZY[p][q] > 1) ? 1 : 0						// Keep track of pixels where R projected is unphysically greater than unity. 
		POL_RZY[][] 		= min(POL_RZY[p][q],1)								// Ensure the projection of the unit vector does not exceed unity. 
	else
		POL_RZYPrime 		= POL_RZY
		// Dodgy empirical squishing of histogram axis. 
		POL_RZY[][] 		= (POL_RZY[p][q] > 0.828) ? (1 - 1.23*exp(0.5-POL_RZY[p][q])^6 ) : POL_RZY[p][q]
		POL_RZYSat = 0
	endif


	// Enforce PhiMin < PhiZY < PhiMax with range of 180˚
	Variable PhiZYMax = gPhiZYMin + 180

		// FROM Pixel PELICAN - should be identical 
	//	if (PhiPol < gPhiZYMin)
	//		PhiZY 	= 180 + PhiPol
	//	elseif (PhiPol > PhiZYMax)
	//		PhiZY 	= PhiPol - 180
	//	else
	//		PhiZY 	= PhiPol
	//	endif
	//	PhiSP 		= acos( Rzy * cos( (pi/180) * (PhiZY)) )
	//	ThetSP 	= atan2( (Rzy * sin( (pi/180) * PhiZY)) , sqrt(1 - Rzy^2))


	// First, account for PhiPol being smaller than PhiMin
	POL_PhiZY[][] 		= POL_PhiPol[p][q] < gPhiZYMin ? (POL_PhiPol[p][q] + 180) : POL_PhiPol[p][q]
	
	// Second, account for PhiPol being larger than PhiMax
	POL_PhiZY[][] 		= POL_PhiZY[p][q] > PhiZYMax ? (POL_PhiZY[p][q] - 180) : POL_PhiZY[p][q]

	// Third ... very unclear to me why this additional step is necessary ... 
	POL_PhiZY[][] 		= POL_PhiZY[p][q] < gPhiZYMin ? (POL_PhiZY[p][q] + 180) : POL_PhiZY[p][q]
	
	
	// PhiSP is the polar angle of the c-axis unit vector in sperical polars
	// PhiSP is defined relative to the z-axis. 
	POL_PhiSP[][] 		= (180/pi) * acos(  POL_RZY[p][q] * cos( (pi/180) * POL_PhiZY[p][q] )  )
	
	// ThetSP is the azimuthal angle of the c-axis unit vector in sperical polars
	// ThetSP lies in the horizontal (x,y) plane is defined relative to the x-axis (X-ray beam axis)
	POL_ThetSP[][] 	= (180/pi) * atan2(  POL_RZY[p][q] * sin((pi/180) * POL_PhiZY[p][q])  ,  sqrt(1 - POL_RZY[p][q]^2)  )
	//	POL_ThetSP[][] 	=  (180/pi) * atan(  POL_RZY[p][q] * sin((pi/180) * POL_PhiZY[p][q])  /  sqrt(1 - POL_RZY[p][q]^2)  )

	// ThetaSample lies in the horizontal (x,y) plane is defined relative to the Sample Normal
	POL_ThetaSample 	= 60 + POL_ThetSP
	
	// Beta is now the "out-of-plane" azimuthal angle with respect to the sample normal
	// The positive direction is now reversed so that postive beta is out of the sample
	POL_BetaSample 	= 30 - POL_ThetSP

	// Alpha is now the "in-plane" polar angle with respect to the z-axis, and in the sample plane
	POL_AlphaSample[][] 	= (180/pi) * atan2(  sin( (pi/180)*POL_PhiSP[p][q] ) * cos( (pi/180)*POL_BetaSample[p][q] ) , cos( (pi/180)*POL_PhiSP[p][q] ) )
	
End


// ***************************************************************************
// **************** 	IMAGE COLOR 
// ***************************************************************************

Function AdjustPELICANRGB()

	Variable /G root:POLARIZATION:gAutocolor=0

	Print " Colored the PELICAN display"

	NVAR gPauseUpdate 		= root:POLARIZATION:gPauseUpdate
	if (gPauseUpdate)
		return 0
	endif

	String OldDf 		= GetDataFolder(1)
	
	// If SwapPhiTheta == 0 		LIGHTNESS determined by Theta and HUE determined by Phi
	// If SwapPhiTheta == 1 		HUE determined by Theta and LIGHTNESS determined by Phi
	Variable SwapPhiTheta = NumVarOrDefault("root:POLARIZATION:gSwapPhiTheta",0)
	Variable /G root:POLARIZATION:gSwapPhiTheta = SwapPhiTheta
	
	NVAR gPhiSPmin 			= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 			= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 		= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 		= root:POLARIZATION:gThetaSPmax

	Variable ThetaSPRange 	= gThetaSPmax - gThetaSPmin
	Variable PhiSPRange 		= gPhiSPmax - gPhiSPmin
	
	NVAR gX1 				= root:SPHINX:SVD:gSVDLeft
	NVAR gX2 				= root:SPHINX:SVD:gSVDRight
	NVAR gY1 				= root:SPHINX:SVD:gSVDBottom
	NVAR gY2 				= root:SPHINX:SVD:gSVDTop
	
	NVAR gMarqueeRGB 		= root:POLARIZATION:gMarqueeRGB
	NVAR gClearPol 			= root:POLARIZATION:gClearPol
	NVAR gPhiDisplayChoice 	= root:POLARIZATION:gPhiDisplayChoice

	
	String StackFolder = "root:SPHINX:Stacks"
	WAVE /D POL_BetaSample 	= $(StackFolder+":POL_BetaSample")
	if (!WaveExists(POL_BetaSample))
		MakePELICANWaves()
	endif
	
	// Results from the fit to the data. 
	WAVE /D POL_BB 			= $(StackFolder+":POL_BB")
	WAVE /D POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
	WAVE /D POL_RZYSat 	= $(StackFolder+":POL_RZYSat")
	
	// These are the calculated c-axis spherical polar angles
	WAVE /D POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
	WAVE /D POL_ThetSP 		= $(StackFolder+":POL_ThetSP")
	WAVE /D POL_ThetaSample 	= $(StackFolder+":POL_ThetaSample")
	
	// Analyze the entire image (ignore gMarqueeRGB)
	Variable X1=0, Y1=0
	Variable X2 	= DimSize(POL_PhiSP,0)-1
	Variable Y2 	= DimSize(POL_PhiSP,1)-1
	
	
	WAVE POL_AlphaSample 	= $(StackFolder+":POL_AlphaSample")
	WAVE POL_BetaSample 		= $(StackFolder+":POL_BetaSample")
	
	// These are the color maps
	WAVE /D aPOL_HSL 		= $(StackFolder+":aPOL_HSL")
	WAVE /D aPOL_RGB 		= $(StackFolder+":aPOL_RGB")

	NVAR gThetaAxisZero 	= root:POLARIZATION:gThetaAxisZero
	NVAR gDark2Light 		= root:POLARIZATION:gDark2Light
	NVAR gBmin 				= root:POLARIZATION:gBmin

	// ***** Alter the Lightness Scale 2023-01-05
	
	NVAR gLightMax 		= root:POLARIZATION:gLightMax
	// gLightMax = 65535/2				// 65535/2 is the max for Lightness 
	// gLightMax = 65535					// 65535 is now the max for Lightness 

	// This was introduced to shift the Brightness values ... 
	Variable LightOffsetFactor = NumVarOrDefault("root:POLARIZATION:gLightOffsetFactor",1e9)
	// ... but now is switched off by setting LightOffsetFactor to a large value 
	LightOffsetFactor = 1e9
	Variable /G root:POLARIZATION:gLightOffsetFactor = LightOffsetFactor
	
	Variable LightOffset 		= 65535/LightOffsetFactor
	Variable LightMin 			= LightOffset
	Variable LightMax 			= gLightMax + LightOffset
	
	
	
	// —————————— Set the Saturation - Channel 1 ———————————
		Variable SaturationScale = NumVarOrDefault("root:POLARIZATION:gSaturationScale",1)
		Variable /G root:POLARIZATION:gSaturationScale = SaturationScale
	
		aPOL_HSL[][][1] = SaturationScale * 65535			// 65535 is the max for Saturation 
	
	// —————————— Set the Hue - Channel 0 —————————— 
	
		
		// Use a portion of the range, 0 - F×65535. For F = 0.85, the scale then goes Red to Magenta
		Variable ColorFraction = NumVarOrDefault("root:POLARIZATION:gColorFraction",1)
		ColorFraction = 1
		Variable /G root:POLARIZATION:gColorFraction = ColorFraction

		// Enable a rotation of the Hue
		Variable ColorOffset = NumVarOrDefault("root:POLARIZATION:gColorOffset",0.2)
		// ColorOffset = 0.6
		Variable /G root:POLARIZATION:gColorOffset = ColorOffset
	
		
		Variable ColorMaxHue 	= ColorFraction * 65535
		Variable Offset 		= ColorOffset * PhiSPRange
			
		if (gPhiDisplayChoice == 1)
			aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_PhiZY[p][q]      - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
			
		elseif (gPhiDisplayChoice == 2) 		// ------------------------------------------------------------------------------
			
			if (SwapPhiTheta == 0)
				Offset 								= ColorOffset * PhiSPRange
				aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_PhiSP[p][q]       - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
			else
				Offset 								= ColorOffset * ThetaSPRange
				aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_ThetSP[p][q]       - gThetaSPmin + Offset)/ThetaSPRange, 1) * ColorMaxHue
			endif
			
		else 											// ------------------------------------------------------------------------------
		
			aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_AlphaSample[p][q] - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
		endif
	
	
	// —————————— Set the Brightness - Channel 2 —————————— 
	
		if (gDark2Light==1)			// "bright -> dark" setting. DEFAULT
		
			if (gThetaAxisZero == 1) 			 		// ------------------------------------------------------------------------------
			
				if (SwapPhiTheta == 0)
					aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
				else
					aPOL_HSL[][][2] 	= LightMax -  ( POL_PhiSP[p][q] - gPhiSPmin) * ( (LightMax-LightMin)/ PhiSPRange)
				endif
			
																 // ------------------------------------------------------------------------------
			elseif (gThetaAxisZero == 2)
				aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
			else
				aPOL_HSL[][][2] 	= gLightMax -  ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			endif
			
		elseif (gDark2Light==2)			// "dark -> bright" setting. Looks better with Offset
		
			if (gThetaAxisZero == 1) 			 		// ------------------------------------------------------------------------------
			
				if (SwapPhiTheta == 0)
					aPOL_HSL[][][2] 	= LightMin + ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
				else
					aPOL_HSL[][][2] 	= LightMin + ( POL_PhiSP[p][q] - gPhiSPmin) * ( (LightMax-LightMin)/ PhiSPRange)
				endif
																 // ------------------------------------------------------------------------------
																 
			elseif (gThetaAxisZero == 2)
				aPOL_HSL[][][2] 	= LightMin + ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
			else
				aPOL_HSL[][][2] 	= ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			endif
			
		endif
	
	// Remove pixels that are likely not crystalline, based on the magnitude of the cos2 signal
	aPOL_HSL[][][2] 		= POL_BB[p][q] < gBmin ? 0 : aPOL_HSL[p][q][2]
	
	// Remove where calculated Rzy > 1
	aPOL_HSL[][][0,2] 		= (POL_RZYSat[p][q] == 1) ? 65535 : aPOL_HSL[p][q][r]

	SetDataFolder $StackFolder
		ImageTransform hsl2rgb aPOL_HSL
		WAVE M_HSL2RGB = M_HSL2RGB
		aPOL_RGB 	= M_HSL2RGB
		KillWaves M_HSL2RGB
	SetDataFolder $OldDf
	
	TrimRGBImage()
	
	PelicanColorScaleBar()
	
	// Update the scaling of the Gradient Scale Bars in the PELICAN 2D Histogram
	WAVE /D aPOL_Hue_Scale 		= $(StackFolder+":aPOL_Hue_Scale")
	WAVE /D aPOL_Bright_Scale 	= $(StackFolder+":aPOL_Bright_Scale")
	SetScale /I y, gPhiSPmin, gPhiSPmax, aPOL_Hue_Scale
	SetScale /I x, gThetaSPmin, gThetaSPmax, aPOL_Bright_Scale
	
	WAVE /D aPOL_RGB_Scale 		= $(StackFolder+":aPOL_RGB_Scale")
	SetScale /I x, gThetaSPmin, gThetaSPmax, "", aPOL_RGB_Scale
	SetScale /I y, gPhiSPmin, gPhiSPmax, "", aPOL_RGB_Scale
	
	
	// It would be better to change the scaling based on the height of the relevant histogram. Or plot on yet another axis. 
	NVAR gAlphaHistMax 	= root:POLARIZATION:gAlphaHistMax
	NVAR gBetaHistMax 	= root:POLARIZATION:gBetaHistMax
	SetScale /I x, 0, gAlphaHistMax, aPOL_Hue_Scale
	SetScale /I y, 0, gBetaHistMax, aPOL_Bright_Scale
	
	CreatePeliSettingsTable()
	
	// I wanted to place the curson on the right location of the 2D scale panel ... but could not get this to work. 
	// CsrColorCalculation()
	
	DoWindow PeliScaleCircle
	if (V_flag)
		PelicanScaleCircle()
	endif
End

Function AutoAdjustPelicanRGB()
	
	Variable /G root:POLARIZATION:gAutocolor=1
	
	Print " Auto-Colored the PELICAN display"
	
	String OldDf 			= GetDataFolder(1)
	String StackFolder 	= "root:SPHINX:Stacks"
	
	// Results from the fit to the data. 
	WAVE /D POL_BB 			= $(StackFolder+":POL_BB")
	WAVE /D POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
	WAVE /D POL_RZYSat 	= $(StackFolder+":POL_RZYSat")
	
	// These are the calculated c-axis spherical polar angles
	WAVE /D POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
	WAVE /D POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
	
	// These are the color maps
	WAVE /D aPOL_HSL 		= $(StackFolder+":aPOL_HSL")
	WAVE /D aPOL_RGB 		= $(StackFolder+":aPOL_RGB")
	
	NVAR gBmin 					= root:POLARIZATION:gBmin
	NVAR gBmax 					= root:POLARIZATION:gBmax
	NVAR gDark2Light 			= root:POLARIZATION:gDark2Light
	NVAR gLightMax 				= root:POLARIZATION:gLightMax 
	NVAR gSwapPhiTheta 		= root:POLARIZATION:gSwapPhiTheta
	NVAR gColorOffset 			= root:POLARIZATION:gColorOffset
	NVAR gDisplayBMax 			= root:POLARIZATION:gDisplayBMax

	NVAR gPhiSPmin 				= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 				= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 			= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 			= root:POLARIZATION:gThetaSPmax

	Variable ThetaSPRange 	= gThetaSPmax - gThetaSPmin
	Variable PhiSPRange 		= gPhiSPmax - gPhiSPmin
	
//	ThetaSPRange 	= 90
//	PhiSPRange 		= 360
	
	Variable ColorMaxHue 	= 1 * 65535
	Variable Offset 		= gColorOffset * PhiSPRange
	
	// —————————— Set the Hue ———————————— Channel 0 —————————— 
	aPOL_HSL[][][1] = 65535			// 65535 is the max for Saturation 
		
	// —————————— Set the Saturation ————- Channel 1 ———————————
	if (gSwapPhiTheta == 0)
		Offset 								= gColorOffset * PhiSPRange
		aPOL_HSL[][][0] 		= mod( (POL_PhiSP[p][q]       - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
	else
		Offset 								= gColorOffset * ThetaSPRange
		aPOL_HSL[][][0] 		= mod( (POL_ThetSP[p][q]       - gThetaSPmin + Offset)/ThetaSPRange, 1) * ColorMaxHue
	endif
	
	// —————————— Set the Brightness ————- Channel 2 —————————— 
	
	Variable Bscale = 1
	if (Bscale)
		WaveStats /Q/M=1 POL_BB
		Variable Bmin = V_min
		Variable Bmax = trunc(min(V_max,gBmax))
		
		aPOL_HSL[][][2] 	= ( POL_BB[p][q] - Bmin) * ( (2*gLightMax)/ (gDisplayBMax - Bmin))
		
		aPOL_HSL[][][2] 	= min(2*gLightMax,aPOL_HSL[p][q][2])
	
	else
		if (gSwapPhiTheta == 0)
			aPOL_HSL[][][2] 	= ( POL_ThetSP[p][q] - gThetaSPmin) * ( (2*gLightMax)/ ThetaSPRange)
		else
			aPOL_HSL[][][2] 	= ( POL_PhiSP[p][q] - gPhiSPmin) * ( (2*gLightMax)/ PhiSPRange)
		endif
	endif

	// —————————— Remove problematic pixels
	
	// Remove pixels that are likely not crystalline, based on the magnitude of the cos2 signal
	aPOL_HSL[][][2] 		= POL_BB[p][q] < gBmin ? 0 : aPOL_HSL[p][q][2]
	
	// Remove where calculated Rzy > 1
	aPOL_HSL[][][0,2] 		= (POL_RZYSat[p][q] == 1) ? 65535 : aPOL_HSL[p][q][r]

	SetDataFolder $StackFolder
		ImageTransform hsl2rgb aPOL_HSL
		WAVE M_HSL2RGB = M_HSL2RGB
		aPOL_RGB 	= M_HSL2RGB
		KillWaves M_HSL2RGB
	SetDataFolder $OldDf
	
	TrimRGBImage()
End


// ***************************************************************************
// **************** 	PELICAN SCALE BAR AND SCALE CIRCLE
// ***************************************************************************

Function PelicanColorScaleBar()
	
	NVAR gLightMax 		= root:POLARIZATION:gLightMax
	NVAR gDark2Light 	= root:POLARIZATION:gDark2Light
	NVAR gSwapPhiTheta = root:POLARIZATION:gSwapPhiTheta
	
	NVAR gPhiSPmin 		= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 		= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 	= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 	= root:POLARIZATION:gThetaSPmax
	
	// This was introduced to shift the Brightness values, but now is switched off by setting LightOffsetFactor to a large value 
	Variable LightOffsetFactor = NumVarOrDefault("root:POLARIZATION:gLightOffsetFactor",1e9)
	LightOffsetFactor = 1e9
	Variable /G root:POLARIZATION:gLightOffsetFactor = LightOffsetFactor
	
	// All adjustment of the range of Hue to use
	Variable ColorFraction = NumVarOrDefault("root:POLARIZATION:gColorFraction",1)
	Variable /G root:POLARIZATION:gColorFraction = ColorFraction
	
	// Enable a rotation of the Hue
	Variable ColorOffset = NumVarOrDefault("root:POLARIZATION:gColorOffset",0.2)
	Variable /G root:POLARIZATION:gColorOffset = ColorOffset
	
	String StackFolder = "root:SPHINX:Stacks"
	
	// -----------------------		Create the RGB display bars 	---------------------
	// aPOL_RGB_Scale is the RGB version of the 2D scale BAR in the Pelican Display panel
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Scale") /WAVE=aPOL_RGB_Scale

	// aPOL_Hue_Scale is the Vertical colored scale in the 2D Histogram
	WAVE /D aPOL_Hue_Scale 		= root:SPHINX:Stacks:aPOL_Hue_Scale
	// aPOL_Bright_Scale is the Horizontal gray scale in the 2D Histogram
	WAVE /D aPOL_Bright_Scale 	= root:SPHINX:Stacks:aPOL_Bright_Scale
	if (!WaveExists(root:SPHINX:Stacks:aPOL_Hue_Scale))
		Make /D/O/N=(100,1000,3) $(StackFolder+":aPOL_Hue_Scale") /WAVE=aPOL_Hue_Scale
		Make /D/O/N=(1000,100,3) $(StackFolder+":aPOL_Bright_Scale") /WAVE=aPOL_Bright_Scale
	endif
	
	// aPOL_RGB_Circle is the RGB version of a 2D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Circle") /WAVE=aPOL_RGB_Circle
	// aPOL_RGB_Phi_Circle is the RGB version of a 1D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Phi_Circle") /WAVE=aPOL_RGB_Phi_Circle
	// aPOL_RGB_Theta_Circle is the RGB version of a 1D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Theta_Circle") /WAVE=aPOL_RGB_Theta_Circle
	// -------------------------------------------------------------------------------
		
	// Use a portion of the range: Red to Magenta
	Variable ColorMaxHue = ColorFraction * 65535
	
	Variable Offset = ColorOffset*1000
	
	// ***** Alter the Lightness Scale 2023-01-05
	//	Variable LightMax = gLightMax 	// This needs to be 65535/2 in order to show "brightness" not "lightness
	// LightOffsetFactor is default set to 1e9 so LightOffset ~ 0
	Variable LightOffset 		= 65535/LightOffsetFactor
	Variable LightMin 			= LightOffset
	Variable LightMax 			= gLightMax + LightOffset
	
	// -----------------------		Create the HSL calculation arrays 	---------------------
	Make /D/FREE /N=(1000,1000,3) aPOL_HSL_Scale				// 2D
	Make /D/FREE /N=(100,1000,3) aPOL_HSL_Hue_Scale
	Make /D/FREE /N=(1000,100,3) aPOL_HSL_Bright_Scale
	
	Make /D/FREE /N=(1000,1000,3) aPOL_HSL_Circle
	Make /D/FREE /N=(100,1000,3) aPOL_HSL_Phi_Circle
	Make /D/FREE /N=(1000,100,3) aPOL_HSL_Theta_Circle
	// -------------------------------------------------------------------------------
	
	// The Hue (Channel 0) runs from 0 - 65535
	// The Saturation (Channel 1) is always 65535
	// The Brightness (Channel 2) runs from 0 - 65535/2 (or vice versa)
	
	aPOL_HSL_Scale[][][1] 			= 65535						// Constant Saturation for the color bar
	
	if (gSwapPhiTheta==0)
		aPOL_HSL_Scale[][][0] 			= mod((q+Offset)/1000,1) * ColorMaxHue
		if (gDark2Light==2)
			aPOL_HSL_Scale[][][2] 		= LightMin + (p/1000) * (LightMax-LightMin)		
		elseif (gDark2Light==1)
			aPOL_HSL_Scale[][][2] 		= ((1000-p)/1000) * (LightMax-LightMin) + LightMin
		endif
	else
		aPOL_HSL_Scale[][][0] 			= mod((p+Offset)/1000,1) * ColorMaxHue
		if (gDark2Light==2)
			aPOL_HSL_Scale[][][2] 		= LightMin + (q/1000) * (LightMax-LightMin)		
		elseif (gDark2Light==1)
			aPOL_HSL_Scale[][][2] 		= ((1000-q)/1000) * (LightMax-LightMin) + LightMin
		endif
	endif
	
	if (gSwapPhiTheta==0)
		aPOL_HSL_Hue_Scale[][][0] 		= mod((q+Offset)/1000,1) * ColorMaxHue
		aPOL_HSL_Hue_Scale[][][1] 		= 65535						// Constant Saturation for the color bar
		aPOL_HSL_Hue_Scale[][][2] 		= gLightMax 				// choose a constant Brightness for the Hue scale bar
		
		aPOL_HSL_Bright_Scale[][][0] 	= 65535/2 					// Constant Hue for the Brightness scale bar
		aPOL_HSL_Bright_Scale[][][1] 	= 0							// Zero Saturation for the Brightness scale bar creates a Gray Scale
		if (gDark2Light==2)
			aPOL_HSL_Bright_Scale[][][2] 		= LightMin + (p/1000) * (LightMax-LightMin)
		elseif (gDark2Light==1)
			aPOL_HSL_Bright_Scale[][][2] 		= ((1000-p)/1000) * (LightMax-LightMin) + LightMin
		endif
	else
		aPOL_HSL_Hue_Scale[][][0] 		= 65535/2
		aPOL_HSL_Hue_Scale[][][1] 		= 0						//
		if (gDark2Light==2)
			aPOL_HSL_Hue_Scale[][][2] 	= LightMin + (q/1000) * (LightMax-LightMin)
		elseif (gDark2Light==1)
			aPOL_HSL_Hue_Scale[][][2] 	= ((1000-q)/1000) * (LightMax-LightMin) + LightMin
		endif
		
		aPOL_HSL_Bright_Scale[][][0] 	= mod((p+Offset)/1000,1) * ColorMaxHue
		aPOL_HSL_Bright_Scale[][][1] 	= 65535							// 
		aPOL_HSL_Bright_Scale[][][2] 	= gLightMax 				// 

	endif
	
	// aPOL_RGB_Scale is displayed in the inset to the PELICAN panel
	ImageTransform hsl2rgb aPOL_HSL_Scale
	WAVE M_HSL2RGB = M_HSL2RGB
	aPOL_RGB_Scale 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	SetScale /I x, gThetaSPmin, gThetaSPmax, "", aPOL_RGB_Scale
	SetScale /I y, gPhiSPmin, gPhiSPmax, "", aPOL_RGB_Scale
	
	// aPOL_Hue_Scale is the Vertical colored scale in the 2D Histogram
	ImageTransform hsl2rgb aPOL_HSL_Hue_Scale
	WAVE M_HSL2RGB = M_HSL2RGB
	aPOL_Hue_Scale 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	// aPOL_Bright_Scale is the Horizontal gray scale in the 2D Histogram
	ImageTransform hsl2rgb aPOL_HSL_Bright_Scale
	WAVE M_HSL2RGB = M_HSL2RGB
	aPOL_Bright_Scale 	= M_HSL2RGB
	KillWaves M_HSL2RGB
End

Function PelicanScaleCircle()

	NVAR gPhiSPmin 		= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 		= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 	= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 	= root:POLARIZATION:gThetaSPmax
	
	// Parameters determining the range of Hue for Phi
	NVAR gColorOffset 			= root:POLARIZATION:gColorOffset		// = 0.2
	NVAR gColorFraction 		= root:POLARIZATION:gColorFraction	// = 1
	Variable ColorMaxHue 		= gColorFraction * 65535
	
	// Parameters determing the range of Lightness/Brightness for Theta
	NVAR gDark2Light 			= root:POLARIZATION:gDark2Light		// = 0.2
	NVAR gLightMax 				= root:POLARIZATION:gLightMax			// = 0.2
	
	NVAR gSwapPhiTheta 		= root:POLARIZATION:gSwapPhiTheta
	
	Variable NPts 	= 1000//DimSize(PhiCircle,0)
	VAriable ptc 	= trunc(NPts/2)
	Variable i, j, angle, pt1, pt2, radius, radfrac=0.75, radfrac2=0.65, PhiFlag, ThetaFlag, rad2deg=(180/pi)
	
	Variable HueVal, PhiRange = abs(gPhiSPmin-gPhiSPmax)
	Variable LightVal, DisplayVal, ThetaRange = abs(gThetaSPmin-gThetaSPmax)

	String StackFolder = "root:SPHINX:Stacks"
	// aPOL_RGB_Circle is the RGB version of a 2D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Circle") /WAVE=aPOL_RGB_Circle
	
	// aPOL_RGB_Phi_Circle is the RGB version of a 1D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Phi_Circle") /WAVE=aPOL_RGB_Phi_Circle
	// aPOL_RGB_Theta_Circle is the RGB version of a 1D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Theta_Circle") /WAVE=aPOL_RGB_Theta_Circle
	
	// PhiCircleArray is 1 when there is a Phi Scale Bar value or -1 otherwise
	// CircleArray does not seem to be used. 
	// CompArray 
	Make /D/FREE/N=(NPts,NPts) PhiCircleArray=-1, CompArray=-1
	
	Duplicate /D/FREE aPOL_RGB_Circle, PhiHSLCircle, ThetaHSLCircle, PhiThetaHSLCircle
	
	// Circular scale bar varying the Hue to represent Phi
	if (gSwapPhiTheta==0)
		PhiHSLCircle[][][1] 			= 65535		// Constant high Saturation
		PhiHSLCircle[][][2] 			= 65535		// For the background: Max Brightness/Lightness = white 
		
		ThetaHSLCircle[][][1] 		= 0			// Zero Saturation
		ThetaHSLCircle[][][2] 		= 65535		// For the background: Max Brightness/Lightness = white 
	else
		PhiHSLCircle[][][1] 			= 0		// Constant high Saturation
		PhiHSLCircle[][][2] 			= 65535		// For the background: Max Brightness/Lightness = white 
		
		ThetaHSLCircle[][][1] 		= 65535			// Zero Saturation
		ThetaHSLCircle[][][2] 		= 65535		// For the background: Max Brightness/Lightness = white 
	endif
	
	Variable pxMin=(1-radfrac)*NPts/2
	Variable pxMax=(NPts-pxMin)
	
	for (i=pxMin;i<pxMax;i+=1)
		for (j=pxMin;j<pxMax;j+=1)
			pt1 		= i-ptc
			pt2 		= j-ptc
			angle 	= rad2deg * atan2(pt1,pt2)
			radius 	= sqrt(pt1^2 + pt2^2)
			
			// Flags for Hue pixels for Phi
			PhiFlag 		= 0
			ThetaFlag 	= 0
			
			if (radius < radfrac*ptc)
				if ((angle>gPhiSPMin) && (angle<gPhiSPMax))
					PhiFlag 	=	 1
				endif
				if (radius < radfrac2*ptc)
					if ((angle>gThetaSPMin) && (angle<gThetaSPMax))
						ThetaFlag 	= 1
					endif
				endif
			endif 
			
			// *!*!*!*!*!*!*!*!
			// PhiFlag = 0
			
			if (PhiFlag)
				PhiCircleArray[i][j] 		= 1		
				
				if (gSwapPhiTheta==0)
					HueVal 						= (angle - gPhiSPMin)/PhiRange 		// 0 - 1
					PhiHSLCircle[i][j][0] 	= mod((HueVal+gColorOffset),1) * ColorMaxHue
					PhiHSLCircle[i][j][2] 	= 65535/2	
					
				else
					LightVal 						= (angle - gPhiSPMin)/PhiRange 
					if (gDark2Light==2)
						DisplayVal 				= LightVal * gLightMax
					else 
						DisplayVal 				= (1-LightVal) * gLightMax
					endif 
					
					PhiHSLCircle[i][j][2] 	= DisplayVal
					
				endif
			endif
			
			if (ThetaFlag)
				CompArray[i][NPts - (NPts/4+j/2)] = 1
				
				if (gSwapPhiTheta==0)
				
					LightVal 						= (angle - gThetaSPMin)/ThetaRange
					if (gDark2Light==2)
						DisplayVal 				= LightVal * gLightMax
					else 
						DisplayVal 				= (1-LightVal) * gLightMax
					endif 
					
					ThetaHSLCircle[i][NPts - (NPts/4+j/2)][2] 	= DisplayVal
					
				else
					HueVal 						= (angle - gThetaSPMin)/ThetaRange
					ThetaHSLCircle[i][NPts - (NPts/4+j/2)][0] 	= mod((HueVal+gColorOffset),1) * ColorMaxHue
					ThetaHSLCircle[i][NPts - (NPts/4+j/2)][2] 	= 65535/2	
				endif
			endif
			
		endfor
	endfor
	
	// Quite a large loop! 
	
	PhiThetaHSLCircle[pxMin,pxMax][pxMin,pxMax][] 	= (CompArray[p][q] > 0) ? ThetaHSLCircle[p][q][r] : PhiHSLCircle[p][q][r]

	ImageTransform hsl2rgb PhiHSLCircle
	WAVE M_HSL2RGB = M_HSL2RGB
	aPOL_RGB_Phi_Circle 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	ImageTransform hsl2rgb ThetaHSLCircle
	WAVE M_HSL2RGB = M_HSL2RGB
	aPOL_RGB_Theta_Circle 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	ImageTransform hsl2rgb PhiThetaHSLCircle
	WAVE M_HSL2RGB = M_HSL2RGB
	aPOL_RGB_Circle 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	DisplayPelicanScaleCircle()
End

// DISPLAYs aPOL_RGB_Circle
Function DisplayPelicanScaleCircle()
	
	DoWindow PeliScaleCircle
	if (V_flag == 1)
		return 0
	endif
	
	Display /K=1/W=(405,53,577,225) as "ScaleCircle"
	DoWindow /C PeliScaleCircle
	
	AppendImage/T root:SPHINX:Stacks:aPOL_RGB_Circle
	ModifyImage aPOL_RGB_Circle ctab= {*,*,Grays,0}
	ModifyGraph margin(left)=14,margin(bottom)=14,margin(top)=14,margin(right)=14,gFont="Helvetica"
	ModifyGraph width=144,height=144
	ModifyGraph tick(top)=3
	ModifyGraph mirror(left)=2,mirror(top)=0
	ModifyGraph nticks=18
	ModifyGraph font="Helvetica"
	ModifyGraph minor=1
	ModifyGraph noLabel=2
	ModifyGraph fSize=9
	ModifyGraph standoff=0
	ModifyGraph axThick=0
	ModifyGraph tkLblRot(left)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
	SetDrawLayer UserFront
	SetDrawEnv linethick= 2,fillpat= 0
	DrawOval 0.123737373737374,0.118918918918919,0.873737373737375,0.881081081081081
	SetDrawEnv linethick= 1.5
	DrawLine 0.504629629629629,0.925115449202351,0.504629629629629,0.0339000839630563
	SetDrawEnv linethick= 1.5
	DrawLine 0.104166666666667,0.501259445843829,0.93287037037037,0.501259445843829
	SetDrawEnv fsize= 20
	DrawText 0.630464318803244,0.0783438665365617,"𝜙\\Bsp"
	SetDrawEnv dash= 4,arrow= 3,fillpat= 0
	DrawArc  0.486111111111111,0.305555555555556,63.1268564083465,-129.382419409873,-47.3215305898327
	SetDrawEnv arrow= 2,fillpat= 0
	DrawArc  0.451388888888889,0.548611111111111,71.4002801114954,38.4032617021058,83.5169263071028
	DrawText 0.428075497706371,1.04051624042178,"180˚"
	DrawText 0.476686608817481,0.0405162404217754,"0˚"
	DrawText 0.941964386595259,0.554405129310665,"90˚"
	
	SetDrawEnv fstyle= 1
	DrawText 0.483631053261925,0.811349573755108,"0˚"
	
	SetDrawEnv fsize= 20
	DrawText 0.0818532076921332,0.863066088758783,"𝜃\\Bsp"
	DrawText -0.0719245022936297,0.561349573755109,"-90˚"
End


Function PelicanDisplayVar(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	Variable UpdateFlag = 0

	switch( sva.eventCode )
		case 1: // mouse up
			UpdateFlag = 1
		case 2: // Enter key
			UpdateFlag = 1
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			break
		case -1: // control being killed
			break
	endswitch
	
	if (UpdateFlag == 1)
		
		if (strsearch(sva.ctrlName,"SetDisplayBMax",0) > -1)
			AutoAdjustPelicanRGB()
			return 0
		endif 
		
		AdjustPELICANRGB()
		
		PelicanColorScaleBar()
		
			// Update the scaling of the scale bars
		if (strsearch(sva.ctrlName,"SetTheta",0) > -1)
			WAVE /D aPOL_Bright_Scale 	= root:SPHINX:Stacks:aPOL_Bright_Scale
			NVAR gThetaSPmin 	= root:POLARIZATION:gThetaSPmin
			NVAR gThetaSPmax 	= root:POLARIZATION:gThetaSPmax
			SetScale /I x, gThetaSPmin, gThetaSPmax, aPOL_Bright_Scale
			
		elseif (strsearch(sva.ctrlName,"SetPhi",0) > -1)
			WAVE /D aPOL_Hue_Scale 		= root:SPHINX:Stacks:aPOL_Hue_Scale
			NVAR gPhiSPmin 	= root:POLARIZATION:gPhiSPmin
			NVAR gPhiSPmax 	= root:POLARIZATION:gPhiSPmax
			SetScale /I y, gPhiSPmin, gPhiSPmax, aPOL_Hue_Scale
		endif
	
	endif
	
	return 0
End


// Only need to run this once
Function ShowPELICANResultPanel()

	String StackFolder = "root:SPHINX:Stacks"
	WAVE /D POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
	WAVE /D POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
	
	WAVE NumData 			= $("root:POLARIZATION:NumData")
	Make /O/N=(NumData[0],NumData[1],3)/D $(StackFolder+":aPOL_HSL") /WAVE=aPOL_HSL
	Make /O/N=(NumData[0],NumData[1],3)/D $(StackFolder+":aPOL_RGB") /WAVE=aPOL_RGB
	
	// This is the key routine that controls the RGB display
	NVAR gAutoColor = root:POLARIZATION:gAutoColor
	if (gAutoColor)
		AutoAdjustPELICANRGB()
	else
		AdjustPELICANRGB()
	endif
	
	SVAR gStackName = root:SPHINX:Browser:gStackName
	String RGBWinName = "RGB_"+gStackName
	DoWindow $RGBWinName
	if (V_flag)
		return 0
	endif
	
	// Create a Panel to display and modify the RGB color map
	SVAR gStackName = root:SPHINX:Browser:gStackName
	PELICANDisplay(aPOL_RGB,"PELICAN Display: "+gStackName,gStackName,NumData[0],NumData[1])
//	PELICANDisplay(aPOL_RGB,"C-axis angles for "+gStackName,"RGB_"+gStackName,NumData[0],NumData[1])
//	RGBDisplayPanel(aPOL_RGB,"C-axis angles for "+gStackName,"RGB_"+gStackName,NumData[0],NumData[1])
	
	// Should be optional? 
//	LargePELICANImages()
	
	PelicanColorScaleBar()
	PelicanScaleCircle()
End 



// ***************************************************************************
// **************** 	PIXEL PELICAN CALCULATIONS 
// ***************************************************************************

// Extracts the angle-dependent intensity from the stack
Function ExtractPixel()

	String PanelFolder 		= "root:POLARIZATION:Analysis"
	WAVE spectrum 		= $(PanelFolder + ":spectrum")
	WAVE fit_spectrum 	= $(PanelFolder + ":fit_spectrum")
	
	String StackFolder 		= "root:SPHINX:Stacks"
	SVAR StackName 		= root:SPHINX:Browser:gStackName
	WAVE SPHINXStack 	= $(StackFolder+":"+StackName)
	
	NVAR gCsrX 	= root:SPHINX:Browser:gCursorAX
	NVAR gCsrY 	= root:SPHINX:Browser:gCursorAY
	NVAR gBin 	= root:SPHINX:Browser:gCursorBin
	
	if ((numtype(gCsrX) == 2) || (numtype(gCsrY) == 2))
		return 0
	endif
	
	// hBox bins, if specified in the StackBrowser.
	Variable i, j, hBox = trunc(gBin/2)
	
	spectrum 	= 0 	// Perhaps ImageTransform setBeam would be faster? 
	for (i=(gCsrX-hBox);i<=(gCsrX+hBox);i+=1)
		for (j=(gCsrY-hBox);j<=(gCsrY+hBox);j+=1)
			spectrum[] 	+= SPHINXStack[i][j][p]
		endfor
	endfor
	
	spectrum /= gBin^2
	
	// DO NOT NORMALIZE THE Polarization data !!!
End

Function FitPixel(AA, BB, Cprime1, Cprime2, PhiPol, X2)
	Variable &AA, &BB, &Cprime1, &Cprime2, &PhiPol, &X2
	
	Variable V_fitOptions=4		//Suppresses Curve Fit Window
	
	WAVE Cos2Fit 	= root:POLARIZATION:Analysis:Cos2Fit
	
	Make/D/N=(3)/O POL_coefs
	POL_coefs 	= {140,150,pi/4}
	
	Variable APt, BPt, CsrFlag = 0
	WAVE ACsrWave = CsrWaveRef(A,"PeliPanel#PixelPlot")
	WAVE BCsrWave = CsrWaveRef(B,"PeliPanel#PixelPlot")
//	WAVE ACsrWave = CsrWaveRef(A,"PolarizationAnalysis#PixelPlot")
//	WAVE BCsrWave = CsrWaveRef(B,"PolarizationAnalysis#PixelPlot")
	
	if ( WaveExists(ACsrWave) && WaveExists(BCsrWave) )
		APt 	= min(pcsr(A,"PeliPanel#PixelPlot"),pcsr(B,"PeliPanel#PixelPlot"))
		BPt 	= max(pcsr(A,"PeliPanel#PixelPlot"),pcsr(B,"PeliPanel#PixelPlot"))
		if ( NumType(APt) == 0 && NumType(APt) == 0 )
			CsrFlag = 1
		endif
	endif
	
	WAVE angles 			= root:POLARIZATION:angles
	WAVE fit_spectrum 	= root:POLARIZATION:Analysis:fit_spectrum
	fit_spectrum = NaN
	
	if (CsrFlag)
		FuncFit /Q BGPolCos2 POL_coefs  root:POLARIZATION:Analysis:spectrum[APt,BPt] /X=root:POLARIZATION:angles[APt,BPt] //D=root:POLARIZATION:Analysis:fit_spectrum		
		fit_spectrum[APt,BPt] 	= BGPolCos2(POL_coefs,angles[p])
	else
		FuncFit /Q BGPolCos2 POL_coefs  root:POLARIZATION:Analysis:spectrum /X=root:POLARIZATION:angles /D=root:POLARIZATION:Analysis:fit_spectrum
	endif
	// POL_coefs [0] and [1] are the fitted values of a and b
	AA 				= POL_coefs[0]
	BB 				= abs(POL_coefs[1])
	
	// POL_coefs[2] is the fitted value of PhiPol
	POL_coefs[2] 	= mod(POL_coefs[2],pi) 						// The fit can find a multiple of pi !! 
	PhiPol 			= (180/pi) * POL_coefs[2]
// 	PhiPol 			= (PhiPol < 0) ? (180 - PhiPol) : PhiPol	// The fit can find a negative polar angle BUT DON't CORRECT THIS HERE
	X2 				= V_chisq
	
	Cos2Fit[] 	= BGPolCos2(POL_coefs,x)
	
	// 	==========================================================================================
	// This way of "looking up" the maximum of the fit function (and hence the c-angle projection, PhiPol) should not be necessary
		createFitSpectrumShell()
		WAVE /D fit_spectrum_m = $("root:POLARIZATION:Analysis:fit_spectrum_m")
		fit_spectrum_m = POL_coefs[0]+POL_coefs[1]*cos((x)/180*pi-POL_coefs[2])^2
		
		WaveStats /Q /M=1 fit_spectrum_m
		Cprime1 = V_maxloc
//		AA = V_min
//		BB = V_max-V_min
		
		WAVE /D fit_spectrum_m2 = $("root:POLARIZATION:Analysis:fit_spectrum_m2")
		fit_spectrum_m2 = POL_coefs[0]+POL_coefs[1]*cos((x)/180*pi-POL_coefs[2])^2
		
		WaveStats /Q /M=1 fit_spectrum_m2
		Cprime2 = V_maxloc
		
		// With the quite complex RDV fit, these values were not the same. (90˚offset).  
		// With the simpler fitting approach they are the same. 
		// Print "Compare estimates of PhiPol. 1) the fitted coefficient:",(180/pi)*POL_coefs[2],"and the others the cos2 max locs",Cprime,PhiPol
	// 	==========================================================================================

End

STATIC Function createFitSpectrumShell()
	// Assign wave
		WAVE /D fit_spectrum_m = $("root:POLARIZATION:Analysis:fit_spectrum_m")
		WAVE /D fit_spectrum_m2 = $("root:POLARIZATION:Analysis:fit_spectrum_m2")
	
	// Make  Waves if needed
		if (!WaveExists(fit_spectrum_m))
			Make /O/N=(1800)/D $("root:POLARIZATION:Analysis:fit_spectrum_m") /WAVE=fit_spectrum_m
			fit_spectrum_m = NaN
			SetScale x,-90,90,fit_spectrum_m
		endif
		if (!WaveExists(fit_spectrum_m2))
			Make /O/N=(1800)/D $("root:POLARIZATION:Analysis:fit_spectrum_m2") /WAVE=fit_spectrum_m2
			fit_spectrum_m2 = NaN
			SetScale x,0,180,fit_spectrum_m2
		endif
End

// This fit function is used for Pixel and Stack analyses
// ** It sometimes chooses a POSITIVE or NEGATIVE value of Phi Pol essentially randomly
Function BGPolCos2(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = a + b * (cos(x + c)) ^ 2
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = a
	//CurveFitDialog/ w[1] = b
	//CurveFitDialog/ w[2] = c
	
	// Enforce a and b positive
	return abs(w[0]) + abs(w[1]) * (cos((pi*x/180) - w[2])) ^ 2

//	return abs(w[0]) + abs(w[1]) * (cos((pi*x/180) - w[2])) ^ 2
//	return w[0] + w[1] * (cos((pi*x/180) - w[2])) ^ 2

End

// This can be used to explore how key variables, particularly Amax and Bmax, affect the calculated c-axis angles
// The calculation approach and variable names should be exactly the same here as for the Stack analysis
Function PixelPELICAN()

	NVAR PixelAX		= $("root:SPHINX:Browser:gCursorAX")
	NVAR PixelAY		= $("root:SPHINX:Browser:gCursorAY")

	NVAR gAmax 			= root:POLARIZATION:gAmax
	NVAR gBmax 			= root:POLARIZATION:gBmax
	NVAR gPhiZYMin 		= root:POLARIZATION:gPhiZYMin
	// This parameter, gThetaSPMax, should probably be removed from here. 
	NVAR gThetaSPMax 	= root:POLARIZATION:gThetaSPMax

	String WarnText
	Variable AA, BB, Cprime1, Cprime2, PhiPol, X2
	Variable Rpol, Rzy, PhiZY, PhiSP, ThetSP
	
	ExtractPIxel()
	
	FitPIxel(AA, BB, Cprime1, Cprime2, PhiPol, X2)
	
	// PIC measurement of Rpol corrected for user-determined Bmax
	Rpol 	= BB/gBmax
	
	if ( (AA>1) && (AA < gAmax))	// ... corrected for user-determined Amax and Bmax
		Rzy 	= (  (gAmax/AA)*BB  )/gBmax
	else
		Rzy 	= Rpol
	endif
	
	if (Rzy > 1)
		WarnText = "\r\r\\K(65535,0,0)is B\Bmax\M\Z12: "+ num2str(gBmax)+" too low?"
		if (gAmax > 1)
			WarnText = WarnText + "\r\\K(65535,0,0)is A\Bmax\M\Z12: "+ num2str(gAmax)+" too high?"
		endif
		Rzy=1
	else
		WarnText = ""
	endif
	
	
	Variable PhiZYMax = gPhiZYMin + 180
	
	if (PhiPol < gPhiZYMin)
	
		PhiZY 	= PhiPol + 180
		
	elseif (PhiPol > PhiZYMax)
	
		PhiZY 	= PhiPol - 180
	
	else
	
		PhiZY 	= PhiPol
	
	endif
	
	Setscale /P x, PhiZY, 180, root:POLARIZATION:PhiPolBars
	
	PhiSP 		= acos( Rzy * cos( (pi/180) * (PhiZY)) )
	ThetSP 	= atan2( (Rzy * sin( (pi/180) * PhiZY)) , sqrt(1 - Rzy^2))
//	ThetSP 	= atan( (Rzy * sin( (pi/180) * PhiZY)) / sqrt(1 - Rzy^2))
	
	// The Reverse PELICAN calculation
//	gPhiSPCalc2 	= (180/pi)*acos( gRzy2 * cos( (pi/180) * (gPhiZY2)) )
//	gThetaNCalc2 	= 60 + (180/pi)*atan2( (gRzy2 * sin( (pi/180) * gPhiZY2)) , sqrt(1 - gRzy2^2))
	
	// Calculate the angles with respect to the sample plane. 
	Variable PhiSample  	= (180/pi) * PhiSP
	Variable ThetaSample = (180/pi) * ThetSP + 60
	
	if ( (180/pi)*ThetSP > gThetaSPMax)
		ThetaSample 	= 180 - (ThetSP - gThetaSPMax) + 60
		PhiSample 	= 180 - PhiSP
	endif
	
	// I don't think I need to worry about signs
//	PhiSP 		= sign(PhiZY) * acos( Rzy * cos( (pi/180) * (PhiZY)) )
	
	String ResultsText = "\Z12f(x)=a + b cos\S2\M\Z12(\Z14𝜙\Bx\M\Z12 - \Z14𝜙\Bpol\M\Z12)\rChiSq:\t"+num2str(X2)
	ResultsText = ResultsText +"\r\ra:\t\t"+num2str(AA)+"\rb:\t\t"+num2str(BB)+"\rc':\t\t"+num2str(Cprime1)+","+num2str(Cprime2)
	ResultsText = ResultsText +"\r\r\Z14𝜙\Bpol\Z12:\t\t"+num2str(PhiPol) +"\r\Z14R\Bpol\\Z12:\t\t"+num2str(Rpol)
	ResultsText = ResultsText +"\r\r\Z14𝜙\Bzy\Z12:\t\t"+num2str(PhiZY) +"\r\Z14R\Bzy\\Z12:\t\t"+num2str(Rzy)
	ResultsText = ResultsText +"\r\r\Z14𝜙\Bsp\Z12:\t\t"+num2str((180/pi)*PhiSP) +"\r\Z14𝜃\Bsp\\Z12:\t\t"+num2str((180/pi)*ThetSP)
	ResultsText = ResultsText +"\r\r\Z14𝜙\Bsample\Z12:\t"+num2str(PhiSample) +"\r\Z14𝜃\Bsample\\Z12:\t"+num2str(ThetaSample)
	ResultsText = ResultsText + WarnText
	TextBox /W=PeliPanel#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
//	TextBox /W=PolarizationAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	
	// Create Pixel Global Variables 
	Variable /G root:POLARIZATION:gPixelPhiZY 		= PhiZY
	Variable /G root:POLARIZATION:gPixelRZY 		= Rzy
	Variable /G root:POLARIZATION:gPixelPhiSP 		= (180/pi)*PhiSP
	Variable /G root:POLARIZATION:gPixelThetaSP 	= (180/pi)*ThetSP
	
	// Compare with stack analysis -- DO NOT DELETE 
	String POLFolder = "root:POLARIZATION"
	NVAR Bmax 				= $(POLFolder+":gBmax")
	NVAR Bmin 				= $(POLFolder+":gBmin")
	NVAR gPhiZYMin 		= $(POLFolder+":gPhiZYMin")

	String StackFolder = "root:SPHINX:Stacks"
	WAVE POL_AA 			= $(StackFolder+":POL_AA")
	WAVE POL_BB 			= $(StackFolder+":POL_BB")
	WAVE POL_PhiPol 	= $(StackFolder+":POL_PhiPol")
	WAVE POL_Rpol 		= $(StackFolder+":POL_Rpol")
	WAVE POL_RZY 		= $(StackFolder+":POL_RZY")
	WAVE POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
	WAVE POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
	WAVE POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
	
	if (0)
	Variable pX=PixelAX, pY=PixelAY
	print "At",pX,pY,"b=",POL_BB[pX][pY],"PhiPol=",POL_PhiPol[pX][pY],"Rzy=",POL_RZY[pX][pY]
	print "Calculated PhiSP=",POL_PhiSP[pX][pY],"and ThetaSP=",POL_ThetSP[pX][pY]
	endif
	
	Variable PixelFlag = 1
	GizmoPeli_CsrVector(PixelFlag)

End


// ***************************************************************************
// **************** 	FULL STACK PELICAN CALCULATION
// **************** 	!! Only needs to be run once !!
// ***************************************************************************

// Fit the Cos2 function to all pixels in the Stack. 
Function StackPELICAN()
	
	SetDataFolder root:POLARIZATION:Analysis
	String PanelFolder 			= "root:POLARIZATION:Analysis"
	WAVE spectrum 			= $(PanelFolder + ":spectrum")
	WAVE fit_spectrum		= $(PanelFolder + ":fit_spectrum")

	String StackFolder = "root:SPHINX:Stacks"
	WAVE POL_AA 			= $(StackFolder+":POL_AA")
	WAVE POL_BB 				= $(StackFolder+":POL_BB")
	WAVE POL_PhiPol 			= $(StackFolder+":POL_PhiPol")
	WAVE POL_X2 				= $(StackFolder+":POL_X2")
	
	WAVE POL_Rpol 			= $(StackFolder+":POL_Rpol")
	WAVE POL_RZY 			= $(StackFolder+":POL_RZY")
	WAVE POL_PhiZY 			= $(StackFolder+":POL_PhiZY")
	WAVE POL_PhiSP 			= $(StackFolder+":POL_PhiSP")
	WAVE POL_ThetSP 		= $(StackFolder+":POL_ThetSP")
	
	NVAR gClearPol = root:POLARIZATION:gClearPol
	
	if (gClearPol == 1)
		POL_AA = NaN
		POL_BB = NaN
		POL_X2 = NaN
		POL_PhiPol = NaN
		POL_Rpol = NaN
		POL_RZY = NaN
		POL_PhiZY = NaN
		POL_PhiSP = NaN
		POL_ThetSP = NaN
		
		gClearPol = 0
	endif
	
	NVAR gX1 					= root:SPHINX:SVD:gSVDLeft
	NVAR gX2 					= root:SPHINX:SVD:gSVDRight
	NVAR gY1 					= root:SPHINX:SVD:gSVDBottom
	NVAR gY2 					= root:SPHINX:SVD:gSVDTop
	if (!NVAR_Exists(gX1))
		Print " *** Please select an ROI"
		return 0
	endif
	
	NVAR Bin 						= root:SPHINX:Browser:gCursorBin
	NVAR gInvertSpectraFlag		= root:SPHINX:Browser:gInvertSpectraFlag
	
//	SVAR StackName 				= root:POLARIZATION:gStackName
	SVAR StackName 				= root:SPHINX:Browser:gStackName
	WAVE SPHINXStack 			= $(StackFolder+":"+StackName)
	Variable MaxX 	= DimSize(SPHINXStack,0)
	Variable MaxY 	= DimSize(SPHINXStack,1)
	
	Make /FREE/D/N=(3)/O POL_coefs

	Variable i, j, k=0, n, m, nm, nMax, mMax
	Variable A, B, Phi, X2, DoFit, GoodFit
	Variable Duration, timeRef = startMSTimer
	Variable V_fitOptions=4		//Suppresses Curve Fit Window
	
	OpenProcBar("Analyzing Polarization Angle Intensity Data for "+StackName)

	for (i = gX1; i < gX2; i += Bin)
		for (j = gY1; j < gY2; j += Bin)

			POL_coefs[] = {120,150,pi/4}

			nm = 0	// Binning 
			mMax 	= (i+Bin > MaxX) ? MaxX : (i+Bin)
			nMax 		= (j+Bin > MaxY) ? MaxY : (j+Bin)
			
			DoFit 		= 1
			GoodFit 	= 0
			spectrum = 0

			// EXTRACT SPECTRUM from PIXEL i,j (with Binning, if specified)
			for (m=i; m < mMax; m += 1)
				for (n=j; n < nMax; n += 1)
					spectrum[] 	+= SPHINXStack[m][n][p]
					nm += 1
				endfor
			endfor
			
			if (nm > 0)
				spectrum /= Bin^2
				// DO NOT Normalize Extracted Spectra, per settings in Stack Browser
			endif

			if (  NumType(spectrum[1]) != 0  )
				DoFit = 0
			endif
			// if ( ROIFlag && roiStack[i][j]==1 ) 
			// 	DoFit = 0
			// endif
			
			if (DoFit)
				//PERFORM FIT FUNCTION FOR spectrum
				Variable V_FitError = 0	// Capture fit errors, and do not prompt user!
				FuncFit /N/Q=1 BGPolCos2 POL_coefs  root:POLARIZATION:Analysis:spectrum /X=root:POLARIZATION:angles /D=root:POLARIZATION:Analysis:fit_spectrum
				GoodFit = (V_FitError == 0) ? 1: 0
			endif
				
			if (GoodFit)
				A 		= POL_coefs[0]
				B 		= abs(POL_coefs[1])
				Phi 	= (180/pi) * mod(POL_coefs[2],pi)
//				Phi 	= (Phi < 0) ? (180 - Phi) : Phi 			// The fit can find a negative polar angle BUT DON't CORRECT THIS HERE. THIS IS ALSO WRONG! Should be (180 + Phi)
				X2 	= V_chisq
			else
				A			= NaN
				B			= NaN
				Phi			= NaN
				X2 		= NaN
			endif
			
			//ASSIGN RESULTS TO POL_C STACK
			for (m = i; m < mMax; m += 1)
				for (n = j; n < nMax; n += 1)
					POL_AA[m][n] 		= A
					POL_BB[m][n] 		= B
					POL_PhiPol[m][n] 	= Phi
					POL_X2[m][n]  	= X2
				endfor
			endfor
			
		endfor
		UpdateProcessBar((i-gX1)/(gX2-gX1))
	endfor
	
	CloseProcessBar()
	
	String PeliNote 	= "PELICAN Stack Fit at "+Secs2Time(DateTime,3)+" "+Secs2Date(datetime,-2)
	Note /K POL_AA, PeliNote
	Note /K POL_BB, PeliNote
	Note /K POL_PhiPol, PeliNote

	Duration = stopMSTimer(timeRef)/1000000
	Print " 		.............. took  ", Duration,"  seconds for ",trunc((gX2-gX1)*(gY2-gY1)/Bin^2),"pixels with binning",Bin,"x",Bin,"."

	String ResultsText = "Stack Analysis Completed\r"
	ResultsText = ResultsText + "\r\Z12f(x)=a + b cos\S2\M\Z12(\Z14𝜙\Bx\M\Z12 - \Z14𝜙\Bpol\M\Z12)"
	ResultsText = ResultsText + "\rView Analysis and X\S2\M\Z12\rimages in SPHINX"
	TextBox /W=PeliPanel#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
//	TextBox /W=PolarizationAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	
	SetDataFolder root: 
End


// ***************************************************************************
// **************** 	PELICAN RESULTS PANEL
// ***************************************************************************
Function PELICANDisplayUpdate()

	NVAR gPhiDisplayChoice 	= root:POLARIZATION:gPhiDisplayChoice
	NVAR gThetaAxisZero 	= root:POLARIZATION:gThetaAxisZero
	
	SVAR gStackName 		= root:SPHINX:Browser:gStackName
	String WindowName 		= "RGB_"+gStackName
	
	if (gPhiDisplayChoice == 3)		// Displaying Hue as Alpha
		SetVariable SetPhiMin title="\\Z16α\\Bmin", win=$WindowName
		SetVariable SetPhiMax title="\\Z16α\\Bmax", win=$WindowName
		ValDisplay APhiVal title="A \\Z16α"
		ValDisplay BPhiVal title="B \\Z16α"
		
	else									// Displaying Hue as Phi
		SetVariable SetPhiMin title="\\Z16Φ\\Bmin", win=$WindowName
		SetVariable SetPhiMax title="\\Z16Φ\\Bmax", win=$WindowName
		ValDisplay APhiVal title="A \\Z16𝜙"
		ValDisplay BPhiVal title="B \\Z16𝜙"
	endif
	
	if (gThetaAxisZero == 3)			// Displaying Brightness as Beta
		SetVariable SetThetaMin title="\\Z16β\\Bmin", win=$WindowName
		SetVariable SetThetaMax title="\\Z16β\\Bmax", win=$WindowName
		ValDisplay AThetVal title="A \\Z16β"
		ValDisplay BThetVal title="B \\Z16β"

	else									// Displaying Brightness as Theta
		SetVariable SetThetaMin title="\\Z16θ\\Bmin", win=$WindowName
		SetVariable SetThetaMax title="\\Z16θ\\Bmax", win=$WindowName
		ValDisplay AThetVal title="A \\Z16𝜃"
		ValDisplay BThetVal title="B \\Z16𝜃"
	endif
	
	//		PopupMenu PhiDisplayMenu title="\\Z42\\Sα\\Z13", win=$WindowName
	//		PopupMenu PhiDisplayMenu title="\\Z42\\S𝜙\\Z13", win=$WindowName
	//		PopupMenu ThetaDisplayMenu2 title="\\Z42\\Sβ\\Z07 ", win=$WindowName
	//		PopupMenu ThetaDisplayMenu2 title="\\Z42\\S𝜃\\Z07 ", win=$WindowName
End


Function /S PELICANDisplay(RGBImage,Title,Folder,NumX,NumY)
	Wave RGBImage
	String Title,Folder
	Variable NumX,NumY
	
	PelicanColorScaleBar()
	PelicanScaleCircle()
	// Reuse the RGB Image display
//	String PanelName = RGBDisplayPanel(RGBImage,Title,Folder,NumX,NumY,PosnStr="px1=877;py1=114;px2=1455;py2=960;swx1=2;swy1=223;swx2=573;swy2=797;")
	String PanelName = RGBDisplayPanel(RGBImage,Title,Folder,NumX,NumY,PosnStr="px1=1175;py1=53;px2=1753;py2=899;swx1=2;swy1=223;swx2=573;swy2=797;")
	
	String subWindow = PanelName+"#RGBImage"
	NVAR gCursorAX 	= $("root:SPHINX:"+PanelName+":gCursorAX")
	Variable ACsrX 	= NumVarOrDefault("root:SPHINX:"+PanelName+":gCursorAX",500)
	Variable ACsrY 	= NumVarOrDefault("root:SPHINX:"+PanelName+":gCursorAY",500)
	
	Cursor /I/P/H=1/W=$subWindow/C=(65535,65535,0) A $NameOfWave(RGBImage) ACsrX, ACsrY
			
	// Reposition all the automatically added controls
	Button ImageSaveButton,pos={493,816},proc=PELICANButtons
	Button TransferZoomButton,pos={293,816}
	Button TransferCrsButton,pos={325,816}
	ValDisplay CsrRedDisplay,pos={16,816}
	ValDisplay CsrGreenDisplay,pos={101,816}
	ValDisplay CsrBlueDisplay,pos={185,816}
	
	PelicanColorScaleBar()
	PelicanScaleCircle()
	
	// The 2D Color and Gray Scale Bar
	WAVE aPOL_RGB_Scale = root:SPHINX:Stacks:aPOL_RGB_Scale
	Display/W=(99,38,279,200)/HOST=# 
		AppendImage root:SPHINX:Stacks:aPOL_RGB_Scale
		ModifyGraph gbRGB=(60790,60790,60790)			// or gbRGB=(61166,61166,61166)
		SetAxis/A/R left 	// *!*!*!*!*!*!*!*!*!*! This is extremelt important. We want to plot Phi-min at the top. 
		ModifyImage aPOL_RGB_Scale ctab= {*,*,Grays,0}
		ModifyGraph axOffset(left)=-3.8,axOffset(bottom)=-1.1
		ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,50}
		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,50}
		ModifyGraph mirror=2
		RenameWindow #,HueBrightScale
		
		// Create and add a cursor
		MakeVariableIfNeeded("root:POLARIZATION:gARGBScaleX",50)
		MakeVariableIfNeeded("root:POLARIZATION:gARGBScaleY",50)
		// Hmm /H=1 should set Hair style cursor. 
		Cursor /M/H=1/C=(65535,65535,0) A
		Cursor /M/H=1/C=(65535,65535,0) B
	SetActiveSubwindow ##
	
	SetVariable SetPhiMin,pos={9.00,37.00},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16Φ\\Bmin"
	SetVariable SetPhiMin,fSize=13,limits={-180,180,5},value= root:POLARIZATION:gPhiSPmin
	SetVariable SetPhiMax,pos={7.00,165.00},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16Φ\\Bmax"
	SetVariable SetPhiMax,fSize=13,limits={-180,180,5},value= root:POLARIZATION:gPhiSPmax
	
	SetVariable SetThetaMin,pos={81.00,197.00},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16θ\\Bmin"
	SetVariable SetThetaMin,fSize=13,limits={-90,180,5},value= root:POLARIZATION:gThetaSPmin
	SetVariable SetThetaMax,pos={212.00,197.00},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16θ\\Bmax"
	SetVariable SetThetaMax,fSize=13,limits={-90,180,5},value= root:POLARIZATION:gThetaSPmax
	
	// ROTATE the color bar
	SetVariable SetHueRotation,pos={9,132},size={77.00,19.00},proc=PelicanDisplayVar
	SetVariable SetHueRotation,title="↔",fSize=13
	SetVariable SetHueRotation,limits={0,1,0.05},value=root:POLARIZATION:gColorOffset

	// SWAP Choice of using Colors or Grays for Phi or Theta
	CheckBox SwapPhiThetacheck,pos={27,74},size={40.00,16.00},proc=PelicanPanelChecks
	CheckBox SwapPhiThetacheck,fsize=14,title="swap"
	CheckBox SwapPhiThetacheck,variable=root:POLARIZATION:gSwapPhiTheta,side=1
	
	// PAUSE updating the PELICAN display and histograms 
	CheckBox PauseUpdateCheck,pos={23,100},size={40.00,16.00},proc=PelicanPanelChecks
	CheckBox PauseUpdateCheck,fsize=14,title="pause"
	CheckBox PauseUpdateCheck,variable=root:POLARIZATION:gPauseUpdate,side=1
	
	// Choice of displaying either in-polarization-plane or spherical-polar phi angle
	MakeVariableIfNeeded("root:POLARIZATION:gPhiDisplayChoice",2)
	NVAR gPhiDisplayChoice = root:POLARIZATION:gPhiDisplayChoice
	gPhiDisplayChoice = 2
//	PopupMenu PhiDisplayMenu pos={8,8},fsize=20,title="Hue ",value="𝜙 zy;\K(29524,1,58982)𝜙 sp;\K(0,0,0)α;", mode=gPhiDisplayChoice, proc=PelicanPanelMenus
	
	MakeVariableIfNeeded("root:POLARIZATION:gThetaAxisZero",1)	
	NVAR gThetaAxisZero = root:POLARIZATION:gThetaAxisZero
	gThetaAxisZero = 1
//	PopupMenu ThetaDisplayMenu2 pos={118,8},fsize=20,title="Lightness ",value="\K(29524,1,58982)𝜃 from x-ray axis;\K(0,0,0)𝜃 from sample normal;β from sample plane;", mode=gThetaAxisZero, proc=PelicanPanelMenus

	// Choice of displaying in-plane or spherical polar phi angle
	MakeVariableIfNeeded("root:POLARIZATION:gDark2Light",2)	
	NVAR gDark2Light = root:POLARIZATION:gDark2Light
	PopupMenu ThetaDisplayMenu1 pos={400,9},title=" ",value="\K(29524,1,58982)light -> dark;\K(0,0,0)dark -> light;", mode=gDark2Light, proc=PelicanPanelMenus
	
	
	WAVE /D POL_BB 				= root:SPHINX:Stacks:POL_BB
	NVAR gDisplayBMax 			= root:POLARIZATION:gDisplayBMax
//	WaveStats /Q/M=1 POL_BB
//	gDisplayBMax = trunc(V_max)
	
	SetVariable SetDisplayBMax,pos={470.00,39.00},size={90.00,26.00},proc=PelicanDisplayVar
	SetVariable SetDisplayBMax,title="\\Z16B\\Bmax",fSize=13
	SetVariable SetDisplayBMax,limits={1,256,5},value=root:POLARIZATION:gDisplayBMax
	
	Button AutoRGBButton,pos={305.00,41.00},size={150.00,20.00},title="Autocolor"
	Button AutoRGBButton,fColor=(65535,0,0),proc=PELICANButtons
	
	
	Button SaveDefaultsButton,pos={113,8},size={150.00,20.00},title="Save Defaults"
	Button SaveDefaultsButton,fColor=(65535,0,0),proc=PELICANButtons
	
	SetWindow $PanelName, hook(PanelCursorHook)=PELICANCursorHooks 	//BrowserCursorHooks
	
	String PanelFolder 	= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	NVAR gCursorAX 	= $(PanelFolder+":gCursorAX")
	NVAR gCursorAY 	= $(PanelFolder+":gCursorAY")
	NVAR gCursorBX 	= $(PanelFolder+":gCursorBX")
	NVAR gCursorBY 	= $(PanelFolder+":gCursorBY")
	SetVariable CursorXSetVar,title="A X",pos={324.00,84.00},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorAX
	SetVariable CursorYSetVar,title="A Y",pos={324.00,109.00},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorAY
	SetVariable CursorBXSetVar,title="B X",pos={444.00,84.00},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorBX
	SetVariable CursorBYSetVar,title="B Y",pos={444.00,109.00},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorBY
	
	
	MakeVariableIfNeeded("root:POLARIZATION:gCursorAPhiSP",0)
	MakeVariableIfNeeded("root:POLARIZATION:gCursorBPhiSP",0)
	MakeVariableIfNeeded("root:POLARIZATION:gCursorAThetSP",0)
	MakeVariableIfNeeded("root:POLARIZATION:gCursorBThetSP",0)
	MakeVariableIfNeeded("root:POLARIZATION:gCursorAThetaSample",0)
	MakeVariableIfNeeded("root:POLARIZATION:gCursorBThetaSample",0)
	
	NVAR gCursorAPhiSP 		= $("root:POLARIZATION:gCursorAPhiSP")
	NVAR gCursorAThetSP 	= $("root:POLARIZATION:gCursorAThetSP")
	NVAR gCursorBPhiSP 		= $("root:POLARIZATION:gCursorBPhiSP")
	NVAR gCursorBThetSP 	= $("root:POLARIZATION:gCursorBThetSP")
	ValDisplay APhiVal title="A \Z16𝜙",pos={324.00,134.00},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorAPhiSP"
	ValDisplay AThetVal title="A \Z16𝜃",pos={324.00,159.00},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorAThetSP"
	ValDisplay BPhiVal title="B \Z16𝜙",pos={444.00,134.00},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorBPhiSP"
	ValDisplay BThetVal title="B \Z16𝜃",pos={444.00,159.00},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorBThetSP"
	
	MakeVariableIfNeeded("root:POLARIZATION:gTwoCursorGamma",0)
	ValDisplay Pol2PixelGamma title="\Z22𝛾",pos={404.00,179.00},size={80,15},fSize=13,value=#"root:POLARIZATION:gTwoCursorGamma"

		
	return PanelName
End


Function /S ExportPELICANFigures()
	
	SVAR gStackName		= root:SPHINX:Browser:gStackName
	String PeliName 		= gStackName
	
	WAVE aPOL_RGB 		= root:SPHINX:Stacks:aPOL_RGB
		
	PathInfo home
	DeleteFile /P=home /Z PeliName+"_PeliRGB.tif"
	DeleteFile /P=home /Z PeliName+"_PeliRGB.csv"
	DeleteFile /P=home /Z PeliName+"_PeliLayout.tif"
	
	// Export the PELICAN RGB data
	ImageSave /O/DS=8/T="tiff"/P=home aPOL_RGB as (PeliName+"_PeliRGB.tif")
	
	// Export the PELICAN RGB data and scale bar
	CreatePeliRGBExports()
	
	CreatePELICAN2DHExports()
	
	// Export the Relevant Settings as a Table 
	CreatePeliSettingsTable()
	SaveTableCopy /O/W=PeliSettingsTable/P=home/T=2 as PeliName+"_PeliRGB.csv"
	
	CreatePeliLayout()
	SavePICT /O/E=-7/B=288/WIN=PeliLayout/P=home as (PeliName+"_PeliLayout.tif")
	
	PathInfo home
	Print " *** Exported PELICAN analysis results to", S_path
	
End

//	ImageSave /O/DS=8/T="tiff"/P=PeliRGBPath aPOL_RGB as (PeliName+"_PeliRGB.tif")
//	SavePICT /O/E=-7/B=288/P=PeliRGBPath/WIN=PeliRGBExport as (PeliName+"_PeliRGBImage.tif")
//	SavePICT /O/E=-7/B=288/P=PeliRGBPath/WIN=PeliRGBScale as (PeliName+"_PeliRGBScale.tif")
//	SavePICT /O/E=-7/B=288/P=home/WIN=PeliRGBExport as (PeliName+"_PeliRGBImage.tif")
//	SavePICT /O/E=-7/B=288/P=home/WIN=PeliRGBScale as (PeliName+"_PeliRGBScale.tif")
//	SaveTableCopy /O/W=PeliSettingsTable/P=PeliRGBPath/T=2 as PeliName+"_PeliRGB.csv"
//	SavePICT /O/E=-7/B=288/WIN=PeliLayout/P=PeliRGBPath as (PeliName+"_PeliLayout.tif")

//Function /S ExportPELICANColorBar()
//	
//	SVAR gStackName		= root:SPHINX:Browser:gStackName
//	String PeliName 		= gStackName
//	
//	WAVE aPOL_RGB 		= root:SPHINX:Stacks:aPOL_RGB
//	
//	CreatePeliRGBExports()
//
//	//	SavePICT /O/E=-7/B=288/P=home/WIN=PeliRGBExport as (PeliName+"_PeliRGBImage.tif")
//	SavePICT /O/E=-7/B=288/P=home/WIN=PeliRGBScale as (PeliName+"_PeliRGBScale.tif")
//	
//	PathInfo home
//	Print " *** Exported PELICAN color scale bar to", S_path
//	
//End

Function CreatePeliLayout()

	SVAR gStackName			= root:SPHINX:Browser:gStackName
	SVAR gPeliSettings		= root:POLARIZATION:gPeliSettings
	SVAR gPeliSettings2		= root:POLARIZATION:gPeliSettings2
	
	DoWindow /K PeliLayout
	DoWindow PeliLayout
	if (V_flag==0)
		
		NewLayout /K=1/HIDE=1/W=(553,367,1827,1111)/N=PeliLayout
		if (IgorVersion() >= 7.00)
			LayoutPageAction size=(792,612),margins=(18,18,18,18)
		endif
		
		ModifyLayout mag=1
		AppendLayoutObject/F=0/T=0/R=(25,55,559,543) Graph PeliRGBExport
		AppendLayoutObject/F=0/T=0/R=(561,36,733,208) Graph PeliScaleCircle
		//	AppendLayoutObject/F=0/T=0/R=(533,58,776,263) Graph PeliRGBScale
		AppendLayoutObject/F=0/T=0/R=(537,214,776,473) Graph Hist2D1DSmall
		
		TextBox/C/N=text0/F=0/A=LB/X=33.47/Y=92.53 "\\Z24"+gStackName
		TextBox/C/N=text1/F=0/A=LB/X=71.56/Y=1.22 gPeliSettings
		TextBox/C/N=text2/F=0/A=LB/X=81.75/Y=2.26 gPeliSettings2
//		TextBox/C/N=text2/F=0/A=LB/X=80.56/Y=5.90 gPeliSettings2
	endif
End

Function CreatePeliRGBExports()
	
	// Make 2 HIDDEN windows for the image plot and scale bar to export. 
	DoWindow PeliRGBExport
	if (V_flag==0)
		Display /HIDE=1/W=(1384,279,1918,767)/N=PeliRGBExport 
		AppendImage root:SPHINX:Stacks:aPOL_RGB 
		ModifyImage aPOL_RGB ctab= {*,*,Grays,0}
		ModifyGraph font="Helvetica", gFont="Helvetica",width=432,height=432, mirror=2
	endif
	
	DoWindow /K PeliRGBScale
	DoWindow PeliRGBScale
	if (V_flag==0)
		Display /HIDE=1/W=(1701,266,1916,445)/N=PeliRGBScale 
		AppendImage root:SPHINX:Stacks:aPOL_RGB_Scale
		ModifyGraph lblMargin(left)=20
		ModifyGraph width=144,height=144
		ModifyGraph standoff=0
		ModifyImage aPOL_RGB_Scale ctab= {*,*,Grays,0}
		ModifyGraph font="Helvetica", gFont="Helvetica"
		ModifyGraph fSize=12, mirror=2
		ModifyGraph manTick(left)={0,45,0,0}, manTick(bottom)={0,45,0,0}
//		Label left "\\Z18φ\\Bsp"
//		Label bottom "\\Z18θ\\Bsp"
//		Label left "\\Z16φ\\Bsp\\M\\Z16 vertical angle \\f02vs\\f00 up"
//		Label bottom "\\Z16θ\Bsp,\M\Z16 horizontal angle \f02vs\f00 X-rays"
		Label left "\\Z16φ (˚)"
		Label bottom "\\Z16θ (˚)"
		SetAxis/A/R left
	endif
	
End

Function CreatePeliSettingsTable()

	NVAR gAmax 			= root:POLARIZATION:gAmax
	NVAR gBmin 			= root:POLARIZATION:gBmin
	NVAR gBmax 			= root:POLARIZATION:gBmax
	NVAR gPhiZYMin 		= root:POLARIZATION:gPhiZYMin
	
	NVAR gPhiSPmin 		= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 		= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 	= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 	= root:POLARIZATION:gThetaSPmax
	
	NVAR gAutoColor 				= root:POLARIZATION:gAutoColor
	NVAR gDisplayBMax 				= root:POLARIZATION:gDisplayBMax
	
	NVAR gPhiDisplayChoice 		= root:POLARIZATION:gPhiDisplayChoice
	NVAR gThetaAxisZero 			= root:POLARIZATION:gThetaAxisZero
	NVAR gDark2Light 				= root:POLARIZATION:gDark2Light
	
	NVAR gColorOffset 				= root:POLARIZATION:gColorOffset
	
	NVAR gSwapPhiTheta 			= root:POLARIZATION:gSwapPhiTheta
	
	String PhiDisplayList 	= "𝜙 zy;𝜙 sp;α;"
	String Phidisplay 		= StringFromList(gPhiDisplayChoice-1,PhiDisplayList)
	String ThetaZeroList = "𝜃 from x-ray axis;𝜃 from sample normal;β from sample plane;"
	String ThetaZero 		= StringFromList(gThetaAxisZero-1,ThetaZeroList)
	String Dark2LightStr 	= StringFromList(gDark2Light-1,"light -> dark;dark -> light;")
//	String Dark2LightStr 	= StringFromList(gDark2Light-1,"bright -> dark;dark -> bright;")

	String SwapChoice 		= StringFromList(gSwapPhiTheta,"default;swap;")
	String ColorAxis 		= StringFromList(gSwapPhiTheta,"PhiSP;ThetaSP;")
	
	String AutoColorStr 	= StringFromList(gAutocolor,"no;yes;")
	
	Variable NumSettings = 13
	Make /T/O/N=(NumSettings) root:POLARIZATION:PeliLegend /WAVE=PeliLegend
	Make /T/O/N=(NumSettings) root:POLARIZATION:PeliSettings /WAVE=PeliSettings
	Make /D/O/N=(NumSettings) root:POLARIZATION:PeliParameters /WAVE=PeliParameters
	

	PeliLegend={"gAmax","gBMin","gBMax","gPhiZYMin","gPhiSPMin","gPhiSPmax","gThetaSPmin","gThetaSPmax","Phidisplay","ThetaZero","Dark2Light","ColorAxis","gColorOffset","gAutoColor","gDisplayBMax"}
	PeliSettings={num2str(gAmax),num2str(gBMin),num2str(gBMax),num2str(gPhiZYMin),num2str(gPhiSPMin),num2str(gPhiSPmax),num2str(gThetaSPmin),num2str(gThetaSPmax),Phidisplay,ThetaZero,Dark2LightStr,ColorAxis,num2str(gColorOffset),AutoColorStr,num2str(gDisplayBMax)}
	PeliParameters={gAmax,gBMin,gBMax,gPhiZYMin,gPhiSPMin,gPhiSPmax,gThetaSPmin,gThetaSPmax,gPhiDisplayChoice,gThetaAxisZero,gDark2Light,gSwapPhiTheta,gColorOffset,gAutoColor,gDisplayBMax}
	
	DoWindow PeliSettingsTable
	if (V_flag == 0)
		Edit /K=1/HIDE=1/N=PeliSettingsTable PeliLegend, PeliSettings
	endif 
	
	String /G root:POLARIZATION:gPeliSettings=""
	SVAR gPeliSettings = root:POLARIZATION:gPeliSettings
	
	gPeliSettings 	= "a\Bmax\M = "+num2str(gAmax)+"\rb\Bmin\M = "+num2str(gBmin)+"\rb\Bmax\M = "+num2str(gBmax)+"\r"
	gPeliSettings 	= gPeliSettings + "𝜙\Bzy min\M = "+num2str(gPhiZYMin)+"\r𝜙\Bmin\M = "+num2str(gPhiSPmin)+"\r𝜙\Bmax\M = "+num2str(gPhiSPmax)+"\r"

	String /G root:POLARIZATION:gPeliSettings2=""
	SVAR gPeliSettings2 = root:POLARIZATION:gPeliSettings2
	
	gPeliSettings2 	= "𝜃\Bmin\M = "+num2str(gThetaSPmin)+"\r𝜃\Bmax\M = "+num2str(gThetaSPmax)+"\r"
	gPeliSettings2 	= gPeliSettings2 + "Hue = "+Phidisplay+"\rLightness = "+ThetaZero+"\r"+Dark2LightStr+"\r"
	gPeliSettings2 	= gPeliSettings2 + "Color axis = "+ColorAxis+"\rColor Offset = "+num2str(gColorOffset)+"\r"
	gPeliSettings2 	= gPeliSettings2 + "Auto Color = "+AutoColorStr+"\rgDisplayBMax = "+num2str(gDisplayBMax)
End

//	gPeliSettings 	= gPeliSettings + "𝜃\Bmin\M = "+num2str(gThetaSPmin)+"\r𝜃\Bmax\M = "+num2str(gThetaSPmax)+"\r"
//	gPeliSettings 	= gPeliSettings + "Hue = "+Phidisplay+"\rLightness = "+ThetaZero+"\r"+Dark2LightStr


Function /S Old_ExportPELICANRGB()
	
	SVAR gStackName		= root:SPHINX:Browser:gStackName
	String PeliName 		= gStackName
	
	WAVE aPOL_RGB 		= root:SPHINX:Stacks:aPOL_RGB
	
	NVAR gAmax 			= root:POLARIZATION:gAmax
	NVAR gBmin 			= root:POLARIZATION:gBmin
	NVAR gBmax 			= root:POLARIZATION:gBmax
	NVAR gPhiZYMin 		= root:POLARIZATION:gPhiZYMin
	
	NVAR gPhiSPmin 		= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 		= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 	= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 	= root:POLARIZATION:gThetaSPmax
	
	NVAR gPhiDisplayChoice 		= root:POLARIZATION:gPhiDisplayChoice
	NVAR gThetaAxisZero 		= root:POLARIZATION:gThetaAxisZero
	NVAR gDark2Light 			= root:POLARIZATION:gDark2Light
	
	String PhiDisplayList 	= "𝜙 zy;𝜙 sp;α;"
	String Phidisplay 		= StringFromList(gPhiDisplayChoice-1,PhiDisplayList)
	String ThetaZeroList = "𝜃 from x-ray axis;𝜃 from sample normal;β from sample plane;"
	String ThetaZero 		= StringFromList(gThetaAxisZero-1,ThetaZeroList)
	String Dark2LightStr 	= StringFromList(gDark2Light-1,"bright -> dark;dark -> bright;")
	
	Variable refNum
	
	PathInfo PeliRGBPath
	if (V_flag)
		NewPath /O PeliRGBPath
	else
		NewPath /O PeliRGBPath
	endif
	
//	if (V_flag)
//		Open /D/M="Location for exporting RGB image"/P=PeliRGBPath refNum as PeliName+"_PeliRGB.tif"
//	else
//		Open /D/M="Location for exporting RGB image" refNum as PeliName+"_PeliRGB.tif"
//	endif
	
	
//	if (strlen(S_fileName) == 0)
//		print "failed here 1"
//		return ""
//	else
//		NewPath /O/Q PeliRGBPath, ParseFilePath(1,S_fileName,":",0,1)
//		if (V_flag != 0)
//			print "failed here 2"
//			return ""
//		endif
//	endif
	
//	ImageSave /O/DS=8/T="tiff"/P=PeliRGBPath aPOL_RGB as (PeliName+"_PeliRGB.tif")
	ImageSave /O/DS=8/T="tiff" aPOL_RGB as (PeliName+"_PeliRGB.tif")
	
	// This does not work for Google drive! 
	if (0)
		Open /T="TEXT" /P=PeliRGBPath refNum as PeliName+"_PeliRGB.txt"
		fprintf refNum, "%s       %f", "","gAmax",gAmax
		Close refNum
	else	
		DoWindow /K PeliSettingsTable
		Make /T/O/N=11 root:PeliLegend={"gAmax","gBMin","gBMax","gPhiZYMin","gPhiSPMin","gPhiSPmax","gThetaSPmin","gThetaSPmax","Phidisplay","ThetaZero","Dark2Light"}
		Make /T/O/N=11 root:PeliSettings={num2str(gAmax),num2str(gBMin),num2str(gBMax),num2str(gPhiZYMin),num2str(gPhiSPMin),num2str(gPhiSPmax),num2str(gThetaSPmin),num2str(gThetaSPmax),Phidisplay,ThetaZero,Dark2LightStr}
		Edit /HIDE=1/N=PeliSettingsTable PeliLegend, PeliSettings
//		SaveTableCopy /W=PeliSettingsTable/P=PeliRGBPath/T=1 as PeliName+"_PeliRGB.txt"
		SaveTableCopy /W=PeliSettingsTable/T=2 as PeliName+"_PeliRGB.txt"
		DoWindow /K PeliSettingsTable
		KillWaves root:PeliLegend, root:PeliSettings
	endif
	
	
End

// See Named Window Hook Events IV-286 in the manual
Function PelicanCursorHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 	= H_Struct.winname
	Variable eventCode 	= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	String csrname 			= H_Struct.cursorName
	
	// !*!*!*! The window of the cursor move may not be the Active window. 
	String CsrWindow 	= ParseFilePath(0, WindowName, "#", 1, 0)
	if (cmpstr(CsrWindow,"RGBImage") != 0)
		return 0
	endif
	
	// ----------------- 2024-07-30 removed this below
//	DoWindow WindowName
//	if (!V_flag == 1)
//		return 0
//	endif 
	// ----------------- 2024-07-30 removed this above
	
	// Check that the image subWindow is active
//	GetWindow $WindowName activeSW
//	String subWindow 	= ParseFilePath(0, S_Value, "#", 1, 0)
//	if (cmpstr(subWindow,"RGBImage") != 0)
////		return 0
//	endif
	
//	Variable eventMod 	= H_Struct.eventMod
//	Variable ShiftDown=0, CommandDown=0
//	if ((eventMod & 2^1) != 0)	// Bit 1 = shift key down
//		ShiftDown = 1
//	endif
//	if ((eventMod & 2^3) != 0)	// Bit 2 = option key down
//		CommandDown=1
//	endif
//	
//	String PanelName 	= ReplaceString("#RGBImage",WindowName,"",0,1)
//	PanelName 	= ReplaceString("RGB_",PanelName,"",0,1)
//	String PanelFolder 	= "root:SPHINX:"+PanelName
//	String PanelFolder 	= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
	// Dynamic calculations if the cursor has been moved. 
	if (eventCode == 7)	// cursor moved. 

		if (cmpstr(csrname,"A") == 0)
			if (strlen(CsrInfo(A)) == 0)
				return 0
			endif
			PelicanCursorCalculations("A")
		elseif (cmpstr(csrname,"B") == 0)
			if (strlen(CsrInfo(B)) == 0)
				return 0
			endif
			PelicanCursorCalculations("B")
		endif
	endif

	// Dynamic calculations if the cursor has been moved. 
	if (eventCode == 5)	// mouse up
		TransferCsrToAllImages(WindowName)
		PixelPELICAN()
		Variable PixelFlag = 0
		GizmoPeli_CsrVector(PixelFlag)
	endif
End
	
Function PelicanCursorCalculations(CsrName)
	String CsrName
	
	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder 	= "root:SPHINX:RGB_"+gStackName

	NVAR gAX 	= $(PanelFolder+":gCursorAX")
	NVAR gAY 	= $(PanelFolder+":gCursorAY")
	NVAR gBX 	= $(PanelFolder+":gCursorBX")
	NVAR gBY 	= $(PanelFolder+":gCursorBY")
	
	NVAR gARed 	= $(PanelFolder+":gCursorARed")
	NVAR gABlue 	= $(PanelFolder+":gCursorABlue")
	NVAR gAGreen 	= $(PanelFolder+":gCursorAGreen")
		
	WAVE aPOL_HSL 				= root:SPHINX:Stacks:aPOL_HSL
	WAVE aPOL_RGB 				= root:SPHINX:Stacks:aPOL_RGB
	WAVE aPOL_RGB_Scale 		= root:SPHINX:Stacks:aPOL_RGB_Scale
	WAVE POL_PhiZY 				= root:SPHINX:Stacks:POL_PhiZY
	WAVE POL_PhiSP 				= root:SPHINX:Stacks:POL_PhiSP
	WAVE POL_ThetSP 			= root:SPHINX:Stacks:POL_ThetSP
	WAVE POL_ThetaSample 	= root:SPHINX:Stacks:POL_ThetaSample
	WAVE POL_AlphaSample 	= root:SPHINX:Stacks:POL_AlphaSample
	WAVE POL_BetaSample 		= root:SPHINX:Stacks:POL_BetaSample
	
	NVAR gCursorAPhiSP 				= root:POLARIZATION:gCursorAPhiSP
	NVAR gCursorBPhiSP 				= root:POLARIZATION:gCursorBPhiSP
	NVAR gCursorAThetSP 			= root:POLARIZATION:gCursorAThetSP
	NVAR gCursorBThetSP 			= root:POLARIZATION:gCursorBThetSP
	NVAR gCursorAThetaSample 	= root:POLARIZATION:gCursorAThetaSample
	NVAR gCursorBThetaSample 	= root:POLARIZATION:gCursorBThetaSample
	
	NVAR gThetaAxisZero 	= root:POLARIZATION:gThetaAxisZero
	NVAR gPhiDisplayChoice 	= root:POLARIZATION:gPhiDisplayChoice
	
	Variable PCsrA, PCsrB
	
	// Need different cursor X and Y locations to pass to the 2D histogram plots
	Variable CsrAX1, CsrAY1, CsrBX1, CsrBY1
	Variable CsrAX2, CsrAY2, CsrBX2, CsrBY2
	Variable CsrAX3, CsrAY3, CsrBX3, CsrBY3
	
	
		if (cmpstr(CsrName,"A") == 0)
			if (strlen(CsrInfo(A)) == 0)
				return 0
			endif
			
			PCsrA 	= pcsr(A)
			PCsrB 	= pcsr(B)
			
			if (PCsrA == 0)
				return 0
				BreakPoint2()
			endif
			
			gAX 	= pcsr(A)
			gAY 	= qcsr(A)
			
			
			// We need to look up all the Pelican Cursor values to accurately move the Histogram cursors
			CsrAX3 						= POL_AlphaSample[gAX][gAY]
			CsrAY3 						= POL_BetaSample[gAX][gAY]
			
			CsrAX2 						= POL_PhiSP[gAX][gAY]
			CsrAY2 						= POL_ThetaSample[gAX][gAY]
			
			CsrAX1 						= POL_PhiSP[gAX][gAY]
			CsrAY1 						= POL_ThetSP[gAX][gAY]
			
			if (gPhiDisplayChoice == 3)		// Displaying Hue as Alpha
				gCursorAPhiSP 				= POL_AlphaSample[gAX][gAY]
			elseif (gPhiDisplayChoice == 2)// Displaying Hue as Phi SP
				gCursorAPhiSP 				= POL_PhiSP[gAX][gAY]
			else									// Displaying Hue as Phi ZY
				gCursorAPhiSP 				= POL_PhiZY[gAX][gAY]
			endif
			
			if (gThetaAxisZero == 3)			// Displaying Brightness as Beta
				gCursorAThetSP 			= POL_BetaSample[gAX][gAY]
			elseif (gThetaAxisZero == 2)	// Displaying Brightness as Theta versus Sample Normal
				gCursorAThetSP 			= POL_ThetaSample[gAX][gAY]
			else									// Displaying Brightness as Theta versus x-ray axis
				gCursorAThetSP 			= POL_ThetSP[gAX][gAY]
			endif
			
			gARed 	= aPOL_RGB[gAX][gAY][0] / 65535
			gAGreen 	= aPOL_RGB[gAX][gAY][1] / 65535
			gABlue	= aPOL_RGB[gAX][gAY][2] / 65535
			
			Hist2D1DCursors(CsrWaveRef(A,"Hist2D1D"),"Hist2D1D","A",CsrAX1,CsrAY1)
			Hist2D1DCursors(CsrWaveRef(A,"Hist2D1D_Sample"),"Hist2D1D_Sample","A",CsrAX2,CsrAY2)
			Hist2D1DCursors(CsrWaveRef(A,"Hist2D1D_Surface"),"Hist2D1D_Surface","A",CsrAX3,CsrAY3)
			
			Variable RGB256Flag = 0
			if (RGB256Flag == 1)
				gARed 	= 256 * aPOL_RGB[gAX][gAY][0] / 65535
				gAGreen 	= 256 * aPOL_RGB[gAX][gAY][1] / 65535
				gABlue	= 256 * aPOL_RGB[gAX][gAY][2] / 65535
			else
				gARed 	= aPOL_RGB[gAX][gAY][0]
				gAGreen 	= aPOL_RGB[gAX][gAY][1]
				gABlue	= aPOL_RGB[gAX][gAY][2]
			endif
			
			// Create Stack Pixel Global Variables 
			Variable /G root:POLARIZATION:gStackPhiSP 		= CsrAX1
			Variable /G root:POLARIZATION:gStackThetaSP 	= CsrAY1
			
			// Move the cursor on the Color Scale image
//			CsrColorCalculation(gARed,gAGreen,gABlue)
			CsrColorCalculation()
			
		elseif (cmpstr(csrname,"B") == 0)
			if (strlen(CsrInfo(B)) == 0)
				return 0
			endif
			gBX 	= pcsr(B)
			gBY 	= qcsr(B)
			
			CsrBX3 						= POL_AlphaSample[gBX][gBY]
			CsrBY3 						= POL_BetaSample[gBX][gBY]
//			CsrBX2 						= POL_PhiZY[gBX][gBY]
			CsrBX2 						= POL_PhiSP[gBX][gBY]
			CsrBY2 						= POL_ThetaSample[gBX][gBY]
			CsrBX1 						= POL_PhiSP[gBX][gBY]
			CsrBY1 						= POL_ThetSP[gBX][gBY]
			
			if (gPhiDisplayChoice == 3)		// Displaying Hue as Alpha
				gCursorBPhiSP 				= POL_AlphaSample[gBX][gBY]
			elseif (gPhiDisplayChoice == 2)// Displaying Hue as Phi SP
				gCursorBPhiSP 				= POL_PhiSP[gBX][gBY]
			else									// Displaying Hue as Phi ZY
				gCursorBPhiSP 				= POL_PhiZY[gBX][gBY]
			endif
			
			if (gThetaAxisZero == 3)			// Displaying Brightness as Beta
				gCursorBThetSP 			= POL_BetaSample[gBX][gBY]
			elseif (gThetaAxisZero == 2)// Displaying Brightness as Theta versus Sample Normal
				gCursorBThetSP 			= POL_ThetaSample[gBX][gBY]
			else									// Displaying Brightness as Theta versus x-ray axis
				gCursorBThetSP 			= POL_ThetSP[gBX][gBY]
			endif
			
			Hist2D1DCursors(CsrWaveRef(B,"Hist2D1D"),"Hist2D1D","B",CsrBX1,CsrBY1)
			Hist2D1DCursors(CsrWaveRef(B,"Hist2D1D_Sample"),"Hist2D1D_Sample","B",CsrBX2,CsrBY2)
			Hist2D1DCursors(CsrWaveRef(B,"Hist2D1D_Surface"),"Hist2D1D_Surface","B",CsrBX3,CsrBY3)
		endif
		
		CalcGammaAngle(gAX,gAY,gBX,gBY)
	
End

Function BreakPoint2()

End
	
Function CsrColorCalculation()
	
	// This is just not fucking working.
	return 0

	NVAR gDark2Light 	= root:POLARIZATION:gDark2Light
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	String WindowName 	= "RGB_"+gStackName
	String PlotName 		= "RGB_"+gStackName+"#HueBrightScale"
	
	DoWindow $WindowName
	if (V_flag == 0)
		return 0 
	endif
	
	String PanelName 	= ReplaceString("#RGBImage",WindowName,"",0,1)
	
	String PanelFolder 	= "root:SPHINX:"+PanelName
	NVAR gARed 	= $(PanelFolder+":gCursorARed")
	NVAR gAGreen 	= $(PanelFolder+":gCursorAGreen")
	NVAR gABlue 	= $(PanelFolder+":gCursorABlue")
	
	Variable ARed 			= gARed
	Variable AGreen 		= gAGreen
	Variable ABlue			= gABlue
	
	Variable ColorFraction = 0.85, Pt1, Pt2
	Variable BigG 			= 65535
	Variable One6th 		= 1000/(6*ColorFraction)
	Variable Slope 			= 65535/One6th
	
	Variable index
	Variable BrightIndex
	Variable HueIndex 		// index is the p point between 0 - 999
	
	if (ARed == 0)
		if (AGreen > ABlue) 		// Blue has a positive slope
			Pt1 = 1000/(3*ColorFraction)
			// Pt2 = 1000/(3*ColorFraction) + 1000/(6*ColorFraction)
			Index 	= (ABlue/Slope) + Pt1
		else							// Green has a negative slope
			Pt1 = 1000/(3*ColorFraction) + 1000/(6*ColorFraction) + 1
			// Pt1 = 1000/(3*ColorFraction) + 1000/(6*ColorFraction) + 1
			Index = (BigG-AGreen)/Slope + Pt1
		endif
	elseif (AGreen == 0)
		if (ABlue > ARed)		// Red has a positive slope
			Pt1 = 2000/(3*ColorFraction)
			// Pt2 = 2000/(3*ColorFraction) + 1000/(6*ColorFraction)
			Index 	= (ARed/Slope) + Pt1
		else							// Blue has a negative slope
			Pt1 = 2000/(3*ColorFraction) + 1000/(6*ColorFraction) + 1
			// Pt2 = 999
			Index = (BigG-ABlue)/Slope + Pt1
		endif
	else // Blue = 0
		if (ARed > AGreen)		// Green has a positive slope
			Pt1 = 0
			// Pt2 = 1000/(6*ColorFraction)
			Index 	= (AGreen/Slope) + Pt1
		else							// Red has a negative slope
			Pt1 = 1000/(6*ColorFraction) + 1
			// Pt2 = 1000/(3*ColorFraction)
			Index = (BigG-ARed)/Slope + Pt1
		endif
	endif
	
	HueIndex 	= index
	index			= 1000 * max(max(ARed, AGreen), ABlue) / BigG
	BrightIndex 	= (gDark2Light == 2) ? index : 1000-index

	// This is just not fucking working.
	// Moving the C cursor on the subwindow somehow causes A and B cursors to be placed there and move also which fucks up the main panel. 
	Cursor /W=$PlotName /I/P C aPOL_RGB_Scale BrightIndex, HueIndex
	
	return Index
End

Function Hist2D1DCursors(POL_Hist_2D,PlotName,CsrName,Phi,Theta)
	Wave POL_Hist_2D
	String PlotName,CsrName
	Variable Phi,Theta
	
	DoWindow $PlotName
	if (V_flag)
//		WAVE POL_Hist_2D = root:POLARIZATION:POL_Hist_2D
		
		Variable X = ScaleToIndex(POL_Hist_2D,Theta,0)
		Variable Y = ScaleToIndex(POL_Hist_2D,Phi,1)
	
		Cursor /W=$PlotName /I/P $CsrName $NameOfWave(POL_Hist_2D) X, Y
//		Cursor /W=Hist2D1D /I/P $CsrName POL_Hist_2D X, Y
	endif
End

Function CalcGammaAngle(x1,y1,x2,y2)
	Variable x1,y1,x2,y2

	WAVE POL_PhiSP 			= root:SPHINX:Stacks:POL_PhiSP
	WAVE POL_ThetSP 		= root:SPHINX:Stacks:POL_ThetSP
	NVAR gTwoCursorGamma 	= root:POLARIZATION:gTwoCursorGamma
	
	Variable phi1 	= POL_PhiSP[x1][y1] * (pi/180)
	Variable phi2 	= POL_PhiSP[x2][y2] * (pi/180)
	
	Variable thet1 	= POL_ThetSP[x1][y1] * (pi/180)
	Variable thet2 	= POL_ThetSP[x2][y2] * (pi/180)
	
	Variable CosGamma, GammaAngle
	
	// I rederived this for the chosen angle convention - see instruction document
	CosGamma = cos(phi1)*cos(phi2)   +   sin(phi1)*sin(phi2)*cos(thet1-thet2)
	
	GammaAngle = acos(CosGamma)
	
	gTwoCursorGamma =  GammaAngle * (180/pi)
End


// These might not be necessary in general if we have a single panel for display and modification 
Function LargePELICANImages()
	
	DoWindow RGB_aPOL_RGB
	if (V_flag != 1)
		String /G root:SPHINX:Stacks:gRGBMapName = "aPOL_RGB"
		WAVE RGB_Map = $("root:SPHINX:Stacks:aPOL_RGB")
		Variable NumX = DimSize(RGB_Map,0)
		Variable NumY = DimSize(RGB_Map,1)
		RGBDisplayPanel(RGB_Map,"aPOL_RGB","aPOL_RGB",NumX,NumY)
	endif
	
	Variable ShowOtherPlots=1
	
	if (ShowOtherPlots)
		DoWindow BG_RGB
		if (V_flag != 1)
			NewImage/K=1 root:SPHINX:Stacks:aPOL_RGB 
			DoWindow /C BG_RGB
			DoWindow /T BG_RGB, "C-axis angles RGB map"
			SetAxis/R/A left -0.5,1053.5
		endif
	
		DoWindow BG_PhiSP
		if (V_flag != 1)
			NewImage/K=1 root:SPHINX:Stacks:POL_PhiSP // as "Phi SP"
			DoWindow /C BG_PhiSP
			DoWindow /T BG_PhiSP, "Phi SP: Polar angle relative to vertical"
			SetAxis/R/A left -0.5,1053.5
		endif
	
		DoWindow BG_ThetSP
		if (V_flag != 1)
			NewImage/K=1 root:SPHINX:Stacks:POL_ThetSP 
			DoWindow /C BG_ThetSP
			DoWindow /T BG_ThetSP, "Theta SP: Azimuthal angle relative to x-ray"
			SetAxis/R/A left -0.5,1053.5
		endif
		
		DoWindow BG_RZY
		if (V_flag != 1)
			NewImage/K=1 root:SPHINX:Stacks:POL_RZY // as "Phi SP"
			DoWindow /C BG_RZY
			DoWindow /T BG_RZY, "R ZY: Magnitude of projection"
			SetAxis/R/A left -0.5,1053.5
		endif
	endif

End

Function KillPELICANHistograms()

	DoWindow /K Hist1D
	DoWindow /K HistAnB
	DoWindow /K HistCprojZY
	DoWindow /K Hist2D1D
	DoWindow /K Hist2D1D_Sample
	DoWindow /K Hist2D1D_Surface
	
	
	KillWaves /Z root:SPHINX:Stacks:POL_PhiPol_hist, POL_PhiZY_hist
	KillWaves /Z root:SPHINX:Stacks:POL_Rpol_hist
	KillWaves /Z root:SPHINX:Stacks:POL_PhiZY_hist
	KillWaves /Z root:SPHINX:Stacks:POL_PhiSP_hist
	KillWaves /Z root:SPHINX:Stacks:POL_ThetSP_hist
	KillWaves /Z root:SPHINX:Stacks:POL_ThetaSample_hist
	KillWaves /Z root:SPHINX:Stacks:POL_AlphaSample_hist
	KillWaves /Z root:SPHINX:Stacks:POL_BetaSample_hist
End

Function CreatePELICAN1DHistograms()
	
	String StackFolder = "root:SPHINX:Stacks"
	SVAR gStackName 	= root:SPHINX:Browser:gStackName

	SetDataFolder root:SPHINX:Stacks
	
		// Make a Mask based on Bmin
		NVAR gBmin				= root:POLARIZATION:gBMin
		WAVE POL_BB			= $(StackFolder+":POL_BB")
		
		// Use Bmin to remove pixels that are likely not crystalline
		Duplicate /O/D POL_BB, TempArray

		if (!WaveExists(POL_AlphaSample_hist))
			Make /O/N=(3601)/D $(StackFolder+":POL_PhiPol_hist") /WAVE=POL_PhiPol_hist
			Make /O/N=(3601)/D $(StackFolder+":POL_PhiZY_hist") /WAVE=POL_PhiZY_hist
			SetScale /P x, -180, 0.1, POL_PhiZY_hist, POL_PhiPol_hist
			
			Make /O/N=(3601)/D $(StackFolder+":POL_PhiSP_hist") /WAVE=POL_PhiSP_hist
			SetScale /P x, -180, 0.1, POL_PhiSP_hist
			
			Make /O/N=(1801)/D $(StackFolder+":POL_ThetSP_hist") /WAVE=POL_ThetSP_hist
			SetScale /P x, -90, 0.1, POL_ThetSP_hist
			
			Make /O/N=(1801)/D $(StackFolder+":POL_ThetaSample_hist") /WAVE=POL_ThetaSample_hist
			SetScale /P x, -50, 0.1, POL_ThetaSample_hist
			
			Make /O/N=(1801)/D $(StackFolder+":POL_AlphaSample_hist") /WAVE=POL_AlphaSample_hist
			SetScale /P x, 0, 0.1, POL_AlphaSample_hist
			Make /O/N=(1801)/D $(StackFolder+":POL_BetaSample_hist") /WAVE=POL_BetaSample_hist
			SetScale /P x, -90, 0.1, POL_BetaSample_hist
		endif
		
		WAVE POL_PhiZY 	= POL_PhiZY
		TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_PhiZY[p][q]
		Histogram/B=1 TempArray, POL_PhiZY_hist
		
		WAVE POL_PhiSP 	= POL_PhiSP
		TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_PhiSP[p][q]
		Histogram/B=1 TempArray, POL_PhiSP_hist
		
		WAVE POL_ThetSP 	= POL_ThetSP
		TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_ThetSP[p][q]
		Histogram/B=1 TempArray, POL_ThetSP_hist
		
		WAVE POL_ThetaSample 	= POL_ThetaSample
		TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_ThetaSample[p][q]
		Histogram/B=1 TempArray, POL_ThetaSample_hist
		
		WAVE POL_AlphaSample 	= POL_AlphaSample
		TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_AlphaSample[p][q]
		Histogram/B=1 TempArray, POL_AlphaSample_hist
		
		WAVE POL_BetaSample 	= POL_BetaSample
		TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_BetaSample[p][q]
		Histogram/B=1 TempArray, POL_BetaSample_hist
		
		// These histograms are based on all points
		if (!WaveExists(POL_Rpol_hist))
			Make /O/N=(512)/D $(StackFolder+":POL_AA_hist") /WAVE=POL_AA_hist
			Make /O/N=(512)/D $(StackFolder+":POL_BB_hist") /WAVE=POL_BB_hist
			SetScale /P x, 0, 1, POL_AA_hist, POL_BB_hist
			
			Make /O/N=(100)/D $(StackFolder+":POL_Rpol_hist") /WAVE=POL_Rpol_hist
			Make /O/N=(100)/D $(StackFolder+":POL_RZY_hist") /WAVE=POL_RZY_hist
			SetScale /P x, 0, 0.01, POL_Rpol_hist, POL_RZY_hist
		endif
		
		Histogram/B=2 POL_AA,POL_AA_hist
		Histogram/B=2 POL_BB,POL_BB_hist
		Histogram/B=2 POL_Rpol,POL_Rpol_hist
		Histogram/B=2 POL_RZY,POL_RZY_hist
		
		WAVE NumData 	= root:POLARIZATION:NumData
		Variable NPixels 	= NumData[0] * NumData[1]
		POL_AA_hist /= NPixels
		POL_BB_hist /= NPixels
		POL_RZY_hist /= NPixels
	
	WaveStats /Q/M=1 POL_AlphaSample_hist
	Variable /G root:POLARIZATION:gAlphaHistMax = V_max
	WaveStats /Q/M=1 POL_AlphaSample_hist
	Variable /G root:POLARIZATION:gBetaHistMax = V_max
	
	SetDataFolder root:
End

Function DisplayPELICANHistograms()

	DisplayPELICAN1DHistograms()
	DisplayPELICAN2DHistograms()
	
End

Function DisplayPELICAN1DHistograms()

	String StackFolder 		= "root:SPHINX:Stacks"
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	WAVE POL_AA_hist			= $(StackFolder+":POL_AA_hist")
	WAVE POL_BB_hist			= $(StackFolder+":POL_BB_hist")
	WAVE POL_RZY_hist 			= $(StackFolder+":POL_RZY_hist")
	WAVE POL_PhiPol_hist 		= $(StackFolder+":POL_PhiPol_hist")
	WAVE POL_Rpol_hist 			= $(StackFolder+":POL_Rpol_hist")
	WAVE POL_PhiZY_hist 		= $(StackFolder+":POL_PhiZY_hist")
	
	DoWindow Hist1D
	if (V_flag == 1)
		return 0
	endif 
//	Display /K=1/W=(572,278,1438,810)/L=ALeft/B=ABBottom POL_AA_hist as "Histograms of Fitted a, a and Rzy"
	Display /K=1/W=(1754,671,2620,1203)/L=ALeft/B=ABBottom POL_AA_hist as "Histograms of Fitted a, a and Rzy"
	
	DoWindow/C Hist1D
	Label ALeft "\\Z22Frequency"
	Label ABBottom "\\Z22a or b Value"
	TextBox/C/N=text0/J/F=0/B=1/A=MC/X=29.83/Y=38.14 "\\Z22\\s(POL_AA_hist) Histogram of a values\n\\s(HistAMaxBar) a\\Bmax\\M\\Z22 set in panel\n"
	
	AppendToGraph/L=BLeft/B=ABBottom POL_BB_hist
	Label BLeft "\\Z22Frequency"
	TextBox/C/N=text1/J/F=0/B=1/A=MC/X=29.14/Y=3.55 "\\Z22\\s(POL_BB_hist) Histogram of b values\n\\s(HistBMaxBar) b\\Bmin\\M\\Z22 set to make epoxy black\n\\s(HistBMinBar) b\\Bmax\\M\\Z22 set to max of distribution"
	
	AppendToGraph POL_RZY_hist
	Label left "\\Z22Frequency"
	Label bottom "\\Z22R\\BZY\\M\\Z22 Value"
	TextBox/C/N=text2/J/F=0/B=1/A=MC/X=28.59/Y=-32.37 "\\Z22\\s(POL_RZY_hist) Histogram of R\\BZY\\M\\Z22 values\r"
	
	AppendToGraph/R=BRight/B=ABBottom root:POLARIZATION:HistBMaxBar, root:POLARIZATION:HistBMinBar
	AppendToGraph/R=ARight/B=ABBottom root:POLARIZATION:HistAMaxBar
	ModifyGraph mode(HistAMaxBar)=1, mode(HistBMinBar)=1, mode(HistBMaxBar)=1
	ModifyGraph lSize(HistAMaxBar)=3, lSize(HistBMinBar)=3, lSize(HistBMaxBar)=3
	ModifyGraph rgb(HistAMaxBar)=(0,0,0,26214),rgb(HistBMinBar)=(0,0,0,26214),rgb(HistBMaxBar)=(0,0,0,26214)
	
	ModifyGraph lblPos(bottom)=60,lblPos(ALeft)=80,lblPos(ABBottom)=60,lblPos(BLeft)=80,lblPos(left)=80
	
	ModifyGraph lSize(POL_AA_hist)=2,lSize(POL_BB_hist)=2,lSize(POL_RZY_hist)=2
	ModifyGraph rgb(POL_AA_hist)=(36873,14755,58982),rgb(POL_RZY_hist)=(19675,39321,1)
	
	ModifyGraph freePos(ALeft)=0, freePos(BLeft)=0
	ModifyGraph freePos(ARight)=50, freePos(BRight)=50
	ModifyGraph freePos(ABBottom)=-130
	
	ModifyGraph axisEnab(ALeft)={0.7,1}
	ModifyGraph axisEnab(BLeft)={0.38,0.68}
	ModifyGraph axisEnab(left)={0,0.25}
	ModifyGraph axisEnab(BRight)={0.38,0.68}
	ModifyGraph axisEnab(ARight)={0.7,1}
	
	SetAxis ABBottom 0,280
	SetAxis left 0,*
	SetAxis bottom 0,1.01
	SetAxis BRight 0,*
	SetAxis ARight 0,*
	
	ModifyGraph lowTrip=0.001
	
	ModifyGraph margin(left)=108
	ModifyGraph noLabel(ALeft)=1,noLabel(BLeft)=1,noLabel(left)=1
	ModifyGraph mirror(ALeft)=2,mirror(ABBottom)=2,mirror(BLeft)=2,mirror(left)=2
	ModifyGraph grid(ALeft)=2,grid(BLeft)=2,grid(left)=2
end

Function CreatePELICAN2DHExports()

	DoWindow Hist2D1DSmall
	if (V_flag)
		return 0
	endif
	
	SetDataFolder root:SPHINX:Stacks:
		Display /W=(466,277,703,534)/K=1 /VERT :::POLARIZATION:Hist2DBack as "PELICAN 2D"
		DoWindow /C Hist2D1DSmall
		
		AppendToGraph/L=ThetaHist POL_ThetSP_hist
		AppendToGraph/VERT/B=HorizCrossing POL_PhiSP_hist
		AppendImage :::POLARIZATION:Hist2DExclude0
		ModifyImage Hist2DExclude0 ctab= {*,10,Grays,1}
		AppendImage :::POLARIZATION:POL_Hist_2D
		ModifyImage POL_Hist_2D ctab= {*,*,CyanMagenta,0}
		AppendImage/B=HorizCrossing aPOL_Hue_Scale
		ModifyImage aPOL_Hue_Scale ctab= {*,*,Grays,0}
		AppendImage/L=ThetaHist aPOL_Bright_Scale
		ModifyImage aPOL_Bright_Scale ctab= {*,*,Grays,0}
	SetDataFolder root:
	
	ModifyGraph gFont="Helvetica"
	ModifyGraph lSize(POL_ThetSP_hist)=2,lSize(POL_PhiSP_hist)=2
	ModifyGraph rgb(POL_ThetSP_hist)=(16385,28398,65535)
	ModifyGraph hideTrace(Hist2DBack)=2
	ModifyGraph grid(left)=1,grid(bottom)=1
	ModifyGraph mirror(left)=0,mirror(bottom)=0
	ModifyGraph nticks(ThetaHist)=0,nticks(HorizCrossing)=0
	ModifyGraph font(left)="Helvetica",font(bottom)="Helvetica"
	ModifyGraph noLabel(HorizCrossing)=2
	ModifyGraph axOffset(left)=-1.33333
	ModifyGraph axRGB(ThetaHist)=(65535,65535,65535),axRGB(HorizCrossing)=(65535,65535,65535)
	ModifyGraph lblPos(left)=74,lblPos(bottom)=50
	ModifyGraph freePos(ThetaHist)=0
	ModifyGraph freePos(HorizCrossing)=0
	ModifyGraph axisEnab(left)={0,0.75}
	ModifyGraph axisEnab(bottom)={0,0.75}
	ModifyGraph axisEnab(ThetaHist)={0.75,1}
	ModifyGraph axisEnab(HorizCrossing)={0.75,1}
	ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,0}
	ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}
	Label left "\\Z16𝜙\\Bsp\\M\\Z22"
	Label bottom "\\Z16𝜃\\Bsp\\M"
	SetAxis/R left*,0

End

Function DisplayPELICAN2DHistograms()

	String StackFolder 		= "root:SPHINX:Stacks"
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	WAVE POL_PhiSP_hist 		= $(StackFolder+":POL_PhiSP_hist")
	WAVE POL_ThetSP_hist 		= $(StackFolder+":POL_ThetSP_hist")
	WAVE POL_ThetaSample_hist 	= $(StackFolder+":POL_ThetaSample_hist")
	
	WAVE aPOL_Hue_Scale 		= $(StackFolder+":aPOL_Hue_Scale")
	WAVE aPOL_Bright_Scale 	= $(StackFolder+":aPOL_Bright_Scale")

	WAVE POL_Hist_2D 						= root:POLARIZATION:POL_Hist_2D
	WAVE POL_Hist_2D_Sym 				= root:POLARIZATION:POL_Hist_2D_Sym

	DoWindow Hist2D1D
	if (V_flag != 1)
//		Title = "2D & 1D Histograms of C-axis Spherical Polars for " + gStackName
		String Title = "PELICAN 2D Histogram of C-Axis Angles for " + gStackName
//		Display /K=1/W=(1502,89,2026,678)/VERT root:POLARIZATION:Hist2DBack as Title
		Display /K=1/W=(1753,53,2277,642)/VERT root:POLARIZATION:Hist2DBack as Title
		
		DoWindow/C Hist2D1D
		
		AppendImage root:POLARIZATION:Hist2DExclude0
		ModifyImage Hist2DExclude0 ctab= {*,10,Grays,1}
		
		SetDrawEnv textrgb= (21845,21845,21845),textrot= 90
		DrawText 0.5193236714975843,0.6441005802707926,"Sample Surface is at θ\\Bsp\\M = 30˚"
		
		// Plot the Theta-SP histogram on the bottom axis with the histogram values plotted on a new Left Axis called ThetaHist
		AppendToGraph/L=ThetaHist root:SPHINX:Stacks:POL_ThetSP_hist
		ModifyGraph rgb(POL_ThetSP_hist)=(16385,28398,65535)
		
		// Plot the Phi-SP histogram Vertically on a new Axis called HorizCrossing
		AppendToGraph/VERT/B=HorizCrossing root:SPHINX:Stacks:POL_PhiSP_hist
		
		// Add the 2D Histogram
		AppendImage root:POLARIZATION:POL_Hist_2D
//		ModifyImage POL_Hist_2D ctab= {*,*,ColdWarm,0}
		ModifyImage POL_Hist_2D ctab= {*,*,CyanMagenta,0}
		
		
		// Choose not to add the Symmetric versions of the histogram
//		AppendImage root:POLARIZATION:POL_Hist_2D_Sym
//		ModifyImage POL_Hist_2D_Sym ctab= {*,*,ColdWarm,0}

		// Add the partial color bars 
		AppendImage/B=HorizCrossing aPOL_Hue_Scale
		AppendImage/L=ThetaHist aPOL_Bright_Scale
		
		// Set the spatial extent of Left Axes
		ModifyGraph axisEnab(ThetaHist)={0.75,1}
		ModifyGraph axisEnab(left)={0,0.75}
		// Set the spatial extent of Bottom Axes
		ModifyGraph axisEnab(bottom)={0,0.75}
		ModifyGraph axisEnab(HorizCrossing)={0.75,1}
		
		// Modify Theta-SP histogram and ThetaHist
		ModifyGraph freePos(THetaHist)=0
		ModifyGraph freePos(HorizCrossing)=0
		
		ModifyGraph axRGB(THetaHist)=(65535,65535,65535) // needed?
		ModifyGraph axRGB(HorizCrossing)=(65535,65535,65535)
		
		// Modify HorizCrossing
		ModifyGraph noLabel(HorizCrossing)=2
		
		ModifyGraph hideTrace(Hist2DBack)=2
		ModifyGraph grid(left)=1,grid(bottom)=1
		ModifyGraph mirror(left)=0,mirror(bottom)=0
		ModifyGraph nticks(THetaHist)=0,nticks(HorizCrossing)=0
		ModifyGraph lblPos(left)=74,lblPos(bottom)=50
		ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,0}
		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}
//		Label left "\\Z22𝜙\\Bsp\M\Z22 relative to Vertical axis"
//		Label bottom "\\Z20𝜃\\Bsp\M\Z20 relative to X-ray axis"
		Label left "\\Z22𝜙\\Bsp\M\Z22 vertical angle relative to up"
		Label bottom "\\Z20𝜃\\Bsp\M\Z20 horizontal angle relative to X-ray axis"
//		ModifyGraph lblRot(left)=-90
		SetAxis/A/R left *,0
		Cursor/P/I/H=1/C=(65535,0,52428) A POL_Hist_2D 108,263
		Cursor/P/I/H=1/C=(65535,0,52428) B POL_Hist_2D 70,151
		
		
		ColorScale/C/N=text0/X=3.17/Y=-37.33 image=POL_Hist_2D, heightPct=20, width=10
		ColorScale/C/N=text0 nticks=2, lowTrip=0.001
		ColorScale/C/N=text0 "Norm # Pixels"
	endif
	
End


Function DisplayPELICANAlphBetaHistograms()

	String StackFolder 		= "root:SPHINX:Stacks"
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	
	WAVE POL_AlphaSample_hist 	= $(StackFolder+":POL_AlphaSample_hist")
	WAVE POL_BetaSample_hist 	= $(StackFolder+":POL_BetaSample_hist")
	
	WAVE aPOL_Hue_Scale 		= $(StackFolder+":aPOL_Hue_Scale")
	WAVE aPOL_Bright_Scale 	= $(StackFolder+":aPOL_Bright_Scale")
	
	WAVE POL_Hist_2D_Sample 			= root:POLARIZATION:POL_Hist_2D_Sample
	WAVE POL_Hist_2D_Sample_Sym 	= root:POLARIZATION:POL_Hist_2D_Sample_Sym
	WAVE POL_Hist_2D_Surface 			= root:POLARIZATION:POL_Hist_2D_Surface
	WAVE POL_Hist_2D_Surface_Sym 	= root:POLARIZATION:POL_Hist_2D_Surface_Sym
	
	DoWindow Hist2D1D_Surface
	if (V_flag != 1)
		String Title = "PELICAN Alpha and Beta angle Histograms for " + gStackName
		Display /K=1/W=(1502,89,2026,678)/VERT root:POLARIZATION:Hist2DBack as Title
		ModifyGraph hideTrace(Hist2DBack)=2
		DoWindow/C Hist2D1D_Surface
		
		AppendToGraph/L=ThetaHist root:SPHINX:Stacks:POL_BetaSample_hist
		AppendToGraph/VERT/B=HorizCrossing root:SPHINX:Stacks:POL_AlphaSample_hist
		
		AppendImage root:POLARIZATION:Hist2DExclude2
		ModifyImage Hist2DExclude2 ctab= {*,10,Grays,1}
		
		AppendImage root:POLARIZATION:POL_Hist_2D_Surface
		ModifyImage POL_Hist_2D_Surface ctab= {*,*,CyanMagenta,0}
		
		// Choose not to add the Symmetric versions of the histogram
//		AppendImage root:POLARIZATION:POL_Hist_2D_Surface_Sym
//		ModifyImage POL_Hist_2D_Surface_Sym ctab= {*,*,CyanMagenta,0}
		
		ModifyGraph rgb(POL_BetaSample_hist)=(16385,28398,65535)
		
		ModifyGraph grid(left)=1,grid(bottom)=1
		ModifyGraph mirror(left)=0,mirror(bottom)=0
		ModifyGraph nticks(ThetaHist)=0,nticks(HorizCrossing)=0
		ModifyGraph noLabel(HorizCrossing)=2
		ModifyGraph axRGB(ThetaHist)=(65535,65535,65535),axRGB(HorizCrossing)=(65535,65535,65535)
		ModifyGraph lblPos(left)=110,lblPos(bottom)=50
		ModifyGraph freePos(ThetaHist)=0
		ModifyGraph freePos(HorizCrossing)=0
		ModifyGraph axisEnab(left)={0,0.75}
		ModifyGraph axisEnab(bottom)={0,0.75}
		ModifyGraph axisEnab(ThetaHist)={0.75,1}
		ModifyGraph axisEnab(HorizCrossing)={0.75,1}
		ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,0}
		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}
		Label left "\\Z22𝛼\\Bsurface"
		Label bottom "\\Z22𝛽\\Bsurface"
		ModifyGraph lblRot(left)=-90
		SetAxis/A/R left *,0
		SetAxis/R bottom 90,-60
		Cursor/P/I/H=1/C=(65535,0,52428) A POL_Hist_2D_Surface 108,263
		Cursor/P/I/H=1/C=(65535,0,52428) B POL_Hist_2D_Surface 70,151
		
		// Add the partial color bars 
		AppendImage/B=HorizCrossing aPOL_Hue_Scale
		AppendImage/L=ThetaHist aPOL_Bright_Scale
		
		ColorScale/C/N=text0/X=3.17/Y=-37.33 image=POL_Hist_2D_Surface, heightPct=20, width=10
		ColorScale/C/N=text0 nticks=2, lowTrip=0.001
		ColorScale/C/N=text0 "Norm # Pixels"
	endif
	
	return 0
	
	DoWindow Hist2D1D_Sample
	if (V_flag != 1)
		Title = "PELICAN Spherical Polar angles. 𝜃sp=0 on Sample surface" + gStackName
		Display /K=1/W=(1502,89,2026,678)/VERT root:POLARIZATION:Hist2DBack as Title
		ModifyGraph hideTrace(Hist2DBack)=2
		DoWindow/C Hist2D1D_Sample
		
		AppendToGraph/L=ThetaHist root:SPHINX:Stacks:POL_ThetaSample_hist
		AppendToGraph/VERT/B=HorizCrossing root:SPHINX:Stacks:POL_PhiSP_hist
		
		AppendImage root:POLARIZATION:Hist2DExclude
		ModifyImage Hist2DExclude ctab= {*,10,Grays,1}
		
		AppendImage root:POLARIZATION:POL_Hist_2D_Sample
		ModifyImage POL_Hist_2D_Sample ctab= {*,*,CyanMagenta,0}
		// ColdWarm
		
		// Choose not to add the Symmetric versions of the histogram
//		AppendImage root:POLARIZATION:POL_Hist_2D_Sample_Sym
//		ModifyImage POL_Hist_2D_Sample_Sym ctab= {*,*,CyanMagenta,0}
		
		ModifyGraph rgb(POL_ThetaSample_hist)=(16385,28398,65535)
		
		ModifyGraph grid(left)=1,grid(bottom)=1
		ModifyGraph mirror(left)=0,mirror(bottom)=0
		ModifyGraph nticks(ThetaHist)=0,nticks(HorizCrossing)=0
		ModifyGraph noLabel(HorizCrossing)=2
		ModifyGraph axRGB(ThetaHist)=(65535,65535,65535),axRGB(HorizCrossing)=(65535,65535,65535)
		ModifyGraph lblPos(left)=74,lblPos(bottom)=50
		ModifyGraph freePos(ThetaHist)=0
		ModifyGraph freePos(HorizCrossing)=0
		ModifyGraph axisEnab(left)={0,0.75}
		ModifyGraph axisEnab(bottom)={0,0.75}
		ModifyGraph axisEnab(ThetaHist)={0.75,1}
		ModifyGraph axisEnab(HorizCrossing)={0.75,1}
		ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,0}
		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}
//		Label left "\\Z22𝜙\\Bsp"
//		Label bottom "\\Z22𝜃\\Bsample"
		Label left "\\Z22𝜙\\Bsp\M\Z22 relative to Vertical axis"
		Label bottom "\\Z20𝜃\\Bsp\M\Z20 relative to Sample surface"
//		ModifyGraph lblRot(left)=-90
		SetAxis/A/R left *,0
		Cursor/P/I/H=1/C=(65535,0,52428) A POL_Hist_2D_Sample 108,263
		Cursor/P/I/H=1/C=(65535,0,52428) B POL_Hist_2D_Sample 70,151
		
		// Add the partial color bars 
		AppendImage/B=HorizCrossing aPOL_Hue_Scale
		AppendImage/L=ThetaHist aPOL_Bright_Scale
		
		ColorScale/C/N=text0/X=3.17/Y=-37.33 image=POL_Hist_2D_Sample, heightPct=20, width=10
		ColorScale/C/N=text0 nticks=2, lowTrip=0.001
		ColorScale/C/N=text0 "Norm # Pixels"
	endif
End



// Do this once. Should we add aPOL_RGB and aPOL_HSL here? 
Function MakePELICANWaves()

	String StackFolder 	= "root:SPHINX:Stacks"
	String PELIFolder 		= "root:PELICAN"
	String POLFolder 		= "root:POLARIZATION"
	
	// Stack dimensions 
	WAVE NumData = $("root:POLARIZATION:NumData")
	Variable MaxX = NumData[0]
	Variable MaxY = NumData[1]
	
	WAVE /D Cos2Fit 			= root:POLARIZATION:Analysis:Cos2Fit
	
	// These are the results of fitting
	WAVE /D POL_AA 		= $(StackFolder+":POL_AA")
	WAVE /D POL_BB 			= $(StackFolder+":POL_BB")
	WAVE /D POL_PhiPol 		= $(StackFolder+":POL_PhiPol")
	WAVE /D POL_X2 			= $(StackFolder+":POL_X2")
	// These are intermediate calculations 
	WAVE /D POL_Rpol 		= $(StackFolder+":POL_Rpol")
	WAVE /D POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
	WAVE /D POL_RZY 		= $(StackFolder+":POL_RZY")
	WAVE /I/U POL_RZYSat 		= $(StackFolder+":POL_RZYSat")
	// These are calculated c-axis angles 
	WAVE /D POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
	WAVE /D POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
	
	// The Theta angle relative to the Normal to the sample plane
	WAVE /D POL_ThetaSample 	= $(StackFolder+":POL_ThetaSample")
	
	// The "in-plane" and "out-of-plane" angles relative to the sample plane
	WAVE /D POL_AlphaSample 	= $(StackFolder+":POL_AlphaSample")
	WAVE /D POL_BetaSample 		= $(StackFolder+":POL_BetaSample")
	
	if (!WaveExists(Cos2Fit))
		Make /D/O/N=360/D root:POLARIZATION:Analysis:Cos2Fit /WAVE=Cos2Fit
		setscale /P x, -180, 1, Cos2Fit 
		Cos2Fit = NaN
	endif
	if (!WaveExists(POL_AA))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_AA") /WAVE=POL_AA
		POL_AA = NaN
	endif
	if (!WaveExists(POL_BB))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_BB") /WAVE=POL_BB
		POL_BB = NaN
	endif
	if (!WaveExists(POL_X2))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_X2") /WAVE=POL_X2
		POL_X2 = NaN
	endif
	if (!WaveExists(POL_PhiPol))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_PhiPol") /WAVE=POL_PhiPol
		POL_PhiPol = NaN
	endif
	if (!WaveExists(POL_Rpol))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Rpol") /WAVE=POL_Rpol
		POL_Rpol = NaN
	endif
	if (!WaveExists(POL_RZY))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_RZY") /WAVE=POL_RZY
		POL_RZY = NaN
	endif
	if (!WaveExists(POL_RZYSat))
		Make /I/U/O/N=(NumData[0],NumData[1]) $(StackFolder+":POL_RZYSat") /WAVE=POL_RZYSat
		POL_RZYSat = NaN
	endif
	if (!WaveExists(POL_RZYPrime))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_RZYPrime") /WAVE=POL_RZYPrime
		POL_RZYPrime = NaN
	endif
	if (!WaveExists(POL_PhiZY))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_PhiZY") /WAVE=POL_PhiZY
		POL_PhiZY = NaN
	endif
	if (!WaveExists(POL_PhiSP))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_PhiSP") /WAVE=POL_PhiSP
		POL_PhiSP = NaN
	endif
	if (!WaveExists(POL_ThetSP))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_ThetSP") /WAVE=POL_ThetSP
		POL_ThetSP = NaN
	endif
	if (!WaveExists(POL_ThetaSample))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_ThetaSample") /WAVE=POL_ThetaSample
		POL_ThetaSample = NaN
	endif
//	if (!WaveExists(POL_BetaSP))
//		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_BetaSP") /WAVE=POL_BetaSP
//		POL_BetaSP = NaN
//	endif
	if (!WaveExists(POL_AlphaSample))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_AlphaSample") /WAVE=POL_AlphaSample
		POL_AlphaSample = NaN
	endif
	if (!WaveExists(POL_BetaSample))
		Make /D/O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_BetaSample") /WAVE=POL_BetaSample
		POL_BetaSample = NaN
	endif
	
	// I'm not sure this is needed
	Variable ClearPol=0
	If (ClearPol)
		POL_AA = NaN
		POL_BB = NaN
		POL_X2 = NaN
		POL_PhiPol = NaN
		POL_Rpol = NaN
		POL_RZY = NaN
		POL_PhiZY = NaN
		POL_PhiSP = NaN
		POL_ThetSP = NaN
		POL_ThetaSample = NaN
		POL_AlphaSample = NaN
		POL_BetaSample = NaN
	endif
	
	SetDataFolder root:POLARIZATION:
		
		// A useful little wave that ensures the 2D histogram axis ranges do not change
		Make /O/D/N=4 Hist2DBack={90,-90,90,-90}
		setscale /P x, -180, 90, Hist2DBack
		
		Make /O/D/N=1 HistAMaxBar=1, HistBMinBar=1, HistBMaxBar=1
		
		Variable AMax = NumVarOrDefault("root:POLARIZATION:gAmax",1)
		Variable BMin = NumVarOrDefault("root:POLARIZATION:gBMin",1)
		Variable BMax = NumVarOrDefault("root:POLARIZATION:gBMax",1)
		Setscale /P x, (AMax), 1, HistAMaxBar
		Setscale /P x, (BMin), 1, HistBMinBar
		Setscale /P x, (BMax), 1, HistBMaxBar
		
		Make /O/D/N=2 PhiPolBars=1
		Setscale /P x, 45, 180, PhiPolBars
	SetDataFolder root: 
End


// ***************************************************************************
// *************** 			HISTOGRAMS
// ***************************************************************************

Function CreatePELICAN2DHistograms()
	
	NVAR gBmin				= root:POLARIZATION:gBMin
	WAVE POL_BB 			= root:SPHINX:Stacks:POL_BB
	
	WAVE POL_PhiSP 		= root:SPHINX:Stacks:POL_PhiSP
	WAVE POL_ThetaSP 	= root:SPHINX:Stacks:POL_ThetSP
	
	WAVE POL_AlphaSample 	= root:SPHINX:Stacks:POL_AlphaSample
	WAVE POL_BetaSample 		= root:SPHINX:Stacks:POL_BetaSample
	
	Variable NX = Dimsize(POL_PhiSP,0), NY = Dimsize(POL_PhiSP,1)
	Variable i, j, BB, xPhi, xTheta, pPhi, pTheta, xAlpha, xBeta, pAlpha, pBeta
	
	SetDataFolder root:Polarization:
		
		// The 2D histogram referenced to the X-ray axis
		Make /O/N=(180,180)/D $("root:POLARIZATION:POL_Hist_2D") /WAVE=POL_Hist_2D
		SetScale /P x, -90, 1, POL_Hist_2D 	// Theta axis
		SetScale /P y, 0, 1, POL_Hist_2D		// Phi axis

		Duplicate /O POL_Hist_2D, POL_Hist_2D_Sym, POL_Hist_2D_Xray, POL_Hist_2D_Xray_Sym	
		
		Duplicate /O POL_Hist_2D, Hist2DExclude0
		Hist2DExclude0 = 0
		Hist2DExclude0[125,Inf][] = 1
	
		// The 2D histogram referenced to the Sample normal
		Make /O/N=(240,180)/D $("root:POLARIZATION:POL_Hist_2D_Sample") /WAVE=POL_Hist_2D_Sample
		SetScale /P x, -90, 1, POL_Hist_2D_Sample  	// Theta axis
		SetScale /P y, 0, 1, POL_Hist_2D_Sample		// Phi axis
		
		Duplicate /O POL_Hist_2D_Sample, POL_Hist_2D_Sample_Sym
		
		Duplicate /O POL_Hist_2D_Sample, Hist2DExclude
		Hist2DExclude = 0
		Hist2DExclude[0,60][] = 4
		Hist2DExclude[180,Inf][] = 1
		
		// The 2D histogram referenced to the Sample Surface
		Make /O/N=(150,180)/D $("root:POLARIZATION:POL_Hist_2D_Surface") /WAVE=POL_Hist_2D_Surface
		SetScale /P x, -90, 1, POL_Hist_2D_Surface  	// Beta axis
		SetScale /P y, 0, 1, POL_Hist_2D_Surface		// Alpha axis
		
		Duplicate /O POL_Hist_2D_Surface, POL_Hist_2D_Surface_Sym
		
		Duplicate /O POL_Hist_2D_Sample, Hist2DExclude2
		Hist2DExclude2 = 0
		Hist2DExclude2[0,90][] = 1
	
		POL_Hist_2D = 0
		POL_Hist_2D_Sym = 0
		POL_Hist_2D_Sample = 0
		POL_Hist_2D_Sample_Sym = 0
		POL_Hist_2D_Surface = 0
		POL_Hist_2D_Surface_Sym = 0
		
		for (i=0;i<NX;i+=1)
			for (j=0;j<NY;j+=1)
				
				BB 		= POL_BB[i][j]
				
				xPhi 		= POL_PhiSP[i][j]
				xTheta 	= POL_ThetaSP[i][j]
				
				if ( (NumType(xPhi) == 0) && (BB > gBmin) )
				
					// The half-histogram in the X-ray space
					pPhi		= ScaleToIndex(POL_Hist_2D,xPhi,1)
					pTheta 	= ScaleToIndex(POL_Hist_2D,xTheta,0)
					POL_Hist_2D[pTheta][pPhi] += 1
					
					// The full-histogram in the X-ray space
					POL_Hist_2D_Sym[pTheta][pPhi] += 1
					pPhi		= ScaleToIndex(POL_Hist_2D_Sym,180-xPhi,1)
					pTheta 	= ScaleToIndex(POL_Hist_2D_Sym,-xTheta,0)
					POL_Hist_2D_Sym[pTheta][pPhi] += 1
					
					// The half-histogram in the Sample space
					pPhi		= ScaleToIndex(POL_Hist_2D_Sample,xPhi,1)
					pTheta 	= ScaleToIndex(POL_Hist_2D_Sample,60+xTheta,0)
					POL_Hist_2D_Sample[pTheta][pPhi] += 1
					
					// The full-histogram in the Sample space
					POL_Hist_2D_Sample_Sym[pTheta][pPhi] += 1
					pPhi		= ScaleToIndex(POL_Hist_2D_Sample_Sym,180-xPhi,1)
					pTheta 	= ScaleToIndex(POL_Hist_2D_Sample_Sym,(60-xTheta),0)
					POL_Hist_2D_Sample_Sym[pTheta][pPhi] += 1
				endif
				
				xAlpha 		= POL_AlphaSample[i][j]
				xBeta 		= POL_BetaSample[i][j]
				
				if ( (NumType(xAlpha) == 0) && (BB > gBmin) )
					// The half-histogram in the Surface space
					pAlpha		= ScaleToIndex(POL_Hist_2D_Sample,xAlpha,1)
					pBeta 		= ScaleToIndex(POL_Hist_2D_Sample,xBeta,0)
					POL_Hist_2D_Surface[pBeta][pAlpha] += 1
					
					// The full-histogram in the Surface space
					POL_Hist_2D_Surface_Sym[pBeta][pAlpha] += 1
					pAlpha		= ScaleToIndex(POL_Hist_2D_Sample_Sym,180-pAlpha,1)
					pBeta 		= ScaleToIndex(POL_Hist_2D_Sample_Sym,xBeta,0)
					POL_Hist_2D_Surface_Sym[pBeta][pAlpha] += 1
				endif
				
			endfor
		endfor
		
		Variable Threshold = 4
		POL_Hist_2D[][] = POL_Hist_2D[p][q] < Threshold ? NaN : POL_Hist_2D[p][q]
		POL_Hist_2D_Sym[][] = POL_Hist_2D_Sym[p][q] < Threshold ? NaN : POL_Hist_2D_Sym[p][q]
		POL_Hist_2D_Sample[][] = POL_Hist_2D_Sample[p][q] < Threshold ? NaN : POL_Hist_2D_Sample[p][q]
		POL_Hist_2D_Sample_Sym[][] = POL_Hist_2D_Sample_Sym[p][q] < Threshold ? NaN : POL_Hist_2D_Sample_Sym[p][q]
		POL_Hist_2D_Surface[][] = POL_Hist_2D_Surface[p][q] < Threshold ? NaN : POL_Hist_2D_Surface[p][q]
		POL_Hist_2D_Surface_Sym[][] = POL_Hist_2D_Surface_Sym[p][q] < Threshold ? NaN : POL_Hist_2D_Surface_Sym[p][q]
		
		WaveStats /Q/M=1 POL_Hist_2D
		Variable NHPts = V_npnts, NHNaNs = V_numNaNs, HMax = V_max
		POL_Hist_2D /= V_max
		POL_Hist_2D_Sample /= V_max
		POL_Hist_2D_Surface /= V_max
		
		POL_Hist_2D_Xray 	= POL_Hist_2D
		POL_Hist_2D_Xray_Sym	= POL_Hist_2D_Sym
		
	SetDataFolder root: 
	
End


// ***************************************************************************
// *************** 	Utility and Clean-Up Functions 
// ***************************************************************************

Function TrimRGBImage()

	WAVE /D aPOL_RGB 		= root:SPHINX:Stacks:aPOL_RGB
	NVAR gX1 					= root:SPHINX:SVD:gSVDLeft
	NVAR gX2 					= root:SPHINX:SVD:gSVDRight
	NVAR gY1 					= root:SPHINX:SVD:gSVDBottom
	NVAR gY2 					= root:SPHINX:SVD:gSVDTop
	
	aPOL_RGB[0,gX1][][] = 65535
	aPOL_RGB[gX2,Inf][][] = 65535
	
	aPOL_RGB[][0,gY1][] = 65535
	aPOL_RGB[][gY2,Inf][] = 65535
End

// The ALS PEEM beamline has strange values that need to be converted to angles from vertical. 
Function ConvertXrayAxisToAngle()

		Wave energy = root:SPHINX:Browser:energy
		Duplicate /O root:SPHINX:Browser:energy, root:POLARIZATION:angles
		WAVE /D POLAngles = root:POLARIZATION:angles
		WaveStats /Q POLAngles
		POLAngles -= V_min + (V_max-V_min-90)
		Reverse POLAngles
		WaveStats /Q POLAngles
		
		POLAngles[] = 190 - energy
		
		// Store min and max angles for use in Cos-SQ Fitting ... 
		// These should probably not be needed at this point. 
		MakeVariableIfNeeded("root:POLARIZATION:maxAngle",0)
		MakeVariableIfNeeded("root:POLARIZATION:minAngle",0)
		NVAR maxAngle = $("root:POLARIZATION:maxAngle")
		NVAR minAngle = $("root:POLARIZATION:minAngle")
		maxAngle = V_max
		minAngle = V_min
End

STATIC Function StopAllMSTimers()
	Variable i
	for (i=0;i<9;i+=1)
		Variable tt = StopMSTimer(i)
	endfor
End

// Might be useful to delete all the RDV data arrays from prior calculations 
Function RemovePICMapArrays()
	
	SetDataFolder root:SPHINX:Stacks:
		Killwaves /Z POL_A, , POL_A_polROI, POL_A_vat, POL_A_vat_polROI
		Killwaves /Z POL_B, , POL_B_polROI, POL_B_vat, POL_B_vat_polROI
		Killwaves /Z POL_Cprime, POL_C_polROI, POL_C_SampCen, POL_C_SampCen_polROI
		Killwaves /Z POL_C_vat, POL_C_vat_polROI, POL_C_vat_SampCen, POL_C_vat_SampCen_polROI
		Killwaves /Z POL_D, POL_D_polROI, POL_D_vat, POL_D_vat_polROI
		Killwaves /Z POL_Theta, POL_Theta_SampCen, POL_Theta_SampCen_polROI
		Killwaves /Z POL_Theta_vat, POL_Theta_vat_SampCen, POL_Theta_vat_SampCen_polROI
		Killwaves /Z POL_Intensity, POL_RGB, COLORBAR_RGB
	SetDataFolder root: 
End






































// ***************************************************************************
// *************** 	Unused Functions 
// ***************************************************************************



Function ZeroToNaN(ImageWave)
	Wave ImageWave
	
	Variable i, j, NX=DimSize(ImageWave,0), NY=DimSize(ImageWave,1)
	
	ImageWave[][] 	= (ImageWave[p][q]==0) ? NaN : ImageWave[p][q]
End

Function LocatePixels2(PhiZY)
	Variable PhiZY

	WAVE FP_PhiZY180 	= root:FP_PhiZY180
	
	Duplicate /O FP_PhiZY180, EqualAngles
	EqualAngles = NaN 
End

Function LocatePixels(PhiZY,Value,Zero)
	Variable PhiZY, Value, Zero

	WAVE FP_PhiZY180 	= root:FP_PhiZY180
	
	if (!WaveExists($"EqualAngles"))
		Duplicate /O FP_PhiZY180, EqualAngles
	endif
	
	WAVE EqualAngles = EqualAngles
	
	if (Zero==1)
		EqualAngles = 0 
	endif
	
		Variable i, j
		
		for (i=0;i<360;i+=1)
			for (j=0;j<180;j+=1)
			
				
				if ( abs(FP_PhiZY180[i][j] - PhiZY) < 0.5)
					EqualAngles[i][j]  = Value
				endif
			
			endfor 
		endfor
End

// This can be used to explore how key variables, particularly Amax and Bmax, affect the calculated c-axis angles
// The calculation approach and variable names should be exactly the same here as for the Stack analysis
Function ManualPELICAN(PhiZY,Rzy)
	Variable PhiZY,Rzy
	
	Variable PhiSP, ThetX, ThetN
	// For the Input angle
	PhiSP 		= (180/pi)*acos( Rzy * cos( (pi/180) * (PhiZY)) )
	ThetX 	= (180/pi)*atan2( (Rzy * sin( (pi/180) * PhiZY)) , sqrt(1 - Rzy^2))
	ThetN 	= ThetX + 60
	
	print " Calculated PhiSP=",PhiSP,"and ThetaN=",ThetN
End


Function PELICANMenuStatus()
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	String PanelName 		= "RGB_"+gStackName
	ControlUpdate /A/W=$PanelName //PhiDisplayMenu
	
	ControlInfo /W=$PanelName PhiDisplayMenu
	NVAR gPhiDisplayChoice = root:POLARIZATION:gPhiDisplayChoice
	Print "Hue choice is",S_Value,"and gPhiDisplayChoice is", gPhiDisplayChoice
	PopupMenu PhiDisplayMenu,mode=gPhiDisplayChoice
	
	ControlInfo /W=$PanelName ThetaDisplayMenu2
	NVAR gThetaAxisZero = root:POLARIZATION:gThetaAxisZero
	Print "Brightness choice is",S_Value,"and gThetaAxisZero is",gThetaAxisZero
	PopupMenu ThetaDisplayMenu2,mode=gThetaAxisZero
	
	ControlInfo /W=$PanelName ThetaDisplayMenu1
	NVAR gDark2Light = root:POLARIZATION:gDark2Light
	Print "Brightness direction is",S_Value,"and gDark2Light is",gDark2Light
	PopupMenu ThetaDisplayMenu1,mode=gDark2Light
	
End

Function DisplayPELICANRGB()

	ShowPELICANResultPanel()
	
	Projection2SphericalPolars()			// New stack calculation of c-axis angles
	
	CreatePELICAN1DHistograms()
	CreatePELICAN2DHistograms()
	DisplayPELICANHistograms()
	
//	PELICANMenuStatus()
	
//	NVAR gAutoColor 	= root:POLARIZATION:gAutoColor
//	if (gAutoColor)
//		AutoAdjustPELICANRGB()
//	else
//		AdjustPELICANRGB()
//	endif
	
//	GizmoPeli_Create()	
End


Function BGAngleBetweenCursors0(phi1deg,phi2deg,thet1deg,thet2deg)
	Variable phi1deg, phi2deg,thet1deg,thet2deg
	
	Variable phi1 	= (pi/180)*phi1deg
	Variable phi2 	= (pi/180)*phi2deg
	Variable thet1 	= (pi/180)*thet1deg
	Variable thet2 	= (pi/180)*thet2deg
	
	Variable CosGam, Gam
	
	CosGam = cos(phi1)*cos(phi2)   +   sin(phi1)*sin(phi2)*cos(thet1-thet2)
	
	Gam = acos(CosGam)
	
	return Gam * (180/pi)
End


Function ArrayCorrelations()
	
	SetdataFolder root:POLARIZATION:
		
		Wave POL_AA = root:SPHINX:Stacks:POL_AA
		Wave POL_BB = root:SPHINX:Stacks:POL_BB
		Wave POL_PhiPol = root:SPHINX:Stacks:POL_PhiPol
		Wave Pm15_average = root:SPHINX:Stacks:Pm15_average
		
		Variable NAX = DimSize(POL_AA,0), NAY= DimSize(POL_AA,0)
		
		Variable NBX = DimSize(POL_BB,0), NBY= DimSize(POL_BB,0)
		
		Variable i, j, nn=0, NAA = NAX*NAY, NBB = NBX*NBY
		
		Make /O/D/N=(NAA) POL_AA_corr
		Make /O/D/N=(NBB) POL_BB_corr
		Make /O/D/N=(NBB) POL_PhiPol_corr
		Make /O/D/N=(NBB) POL_AVG_corr
		
		for (i=1;i<NAX;i+=1)
			for (j=1;j<NAY;j+=1)
				POL_AA_corr[nn] 		= POL_AA[i][j]
				POL_BB_corr[nn] 		= POL_BB[i][j]
				POL_PhiPol_corr[nn] 	= POL_PhiPol[i][j]
				POL_AVG_corr[nn] 	= Pm15_average[i][j]
				nn += 1
			endfor
		endfor
End


// ***************************************************************************
// *************** 	Some early Calculation Functions 
// ***************************************************************************

Function ForwardPELICAN()

	SetDataFolder root: 
	
		Make /D/O/N=(360,180) FP_ThetaSample, FP_PhiSample, FP_ThetXY, FP_PhiZY, FP_Rzy, FP_PhiZY180
		SetScale /P x, -90, 1, FP_ThetaSample, FP_PhiSample, FP_ThetXY, FP_PhiZY, FP_Rzy, FP_PhiZY180
		SetScale /P y, 0, 1, FP_ThetaSample, FP_PhiSample, FP_ThetXY, FP_PhiZY, FP_Rzy, FP_PhiZY180
		
		FP_ThetaSample[][] = x
		FP_PhiSample[][] 	= y
		
		FP_ThetXY[][] 		= x-60
		
		FP_PhiZY[][] 	 	= (180/pi) * atan2(   sin( (pi/180)*y ) * sin( (pi/180)*(x-60) ) , cos( (pi/180)*y ) )
		
		Variable i, j
		
		for (i=0;i<360;i+=1)
			for (j=0;j<180;j+=1)
				if (FP_PhiZY180[i][j] > 90)
					FP_PhiZY180[i][j] 	= FP_PhiZY[i][j] - 90
					
				elseif(FP_PhiZY180[i][j] < -90)
					FP_PhiZY180[i][j] = 180 + FP_PhiZY[i][j]
					
				else
					FP_PhiZY180[i][j] 	= FP_PhiZY[i][j]
				endif
			endfor
		endfor
		
//		FP_PhiZY180[][] 	= (FP_PhiZY[p][q] > 90) ? (100000) : FP_PhiZY[p][q]
//		FP_PhiZY180[][] 	= (FP_PhiZY[p][q] < -90) ? (-100000) : FP_PhiZY[p][q]
//		FP_PhiZY180[][]= -1 * FP_PhiZY[p][q]

//		// First, account for PhiPol being smaller than PhiMin
//		POL_PhiZY[][] 		= POL_PhiPol[p][q] < gPhiZYMin ? (180 + POL_PhiPol[p][q]) : POL_PhiPol[p][q]
//		// Second, account for PhiPol being larger than PhiMax
//		POL_PhiZY[][] 		= POL_PhiZY[p][q] > PhiZYMax ? (POL_PhiZY[p][q] - PhiZYMax) : POL_PhiZY[p][q]
		
		FP_Rzy[][] 		= sqrt( sin((pi/180)*y)^2*sin((pi/180)*(x-60))^2  +   cos((pi/180)*y)^2)
End
