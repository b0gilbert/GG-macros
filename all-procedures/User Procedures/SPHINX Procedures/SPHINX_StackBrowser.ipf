#pragma rtGlobals=1		// Use modern global access method.
#include "SPHINX_StackLoader"
#include "SPHINX_ImageLoader"
#include "SPHINX_ImageDisplay"
#include "SPHINX_Mapping"
#include "SPHINX_RGBMapExport"
#include "SPHINX_MTMapping"
#include "SPHINX_PeakFindingFilter"
#include "SPHINX_Distributions"
#include "SPHINX_Raman"
#include "SPHINX_ROI"
#include "SPHINX_Animation"
#include "SPHINX_CytoViva"

Menu "SPHINX"
	"Display Stack"
	SubMenu "Stacks"
		"Summarize STXM Folder"
		"Stack Images"
		"Load Jobin Raman"
		"Load ENVI ASCII Stack"
		"Load WiTec Raman"
		"Load TIFF Stack"
//		"Load XiM Stack"
//		"Load P3B Stack"
		"Load Stack Axis"
		"Save Stack"
		"Delete Stack"
	End
	SubMenu "Images"
		"Load Image"
		"\\M1Display Images /0"
		"Display RGB Image"
		"Load Dist Map Images"
		"Display A Dist Map"
		"Export Images"
		"Duplicate Image"
		"Remove Images"
		"Close All Images"
	End
//	SubMenu "Mapping"
//	End
End

Function InitializeStackBrowser()

	InitLoadSpectra()

	NewDataFolder /O root:SPHINX
	NewDataFolder /O root:SPHINX:Import
	NewDataFolder /O root:SPHINX:Stacks
	NewDataFolder /O root:SPHINX:Browser
	NewDataFolder /O root:SPHINX:Distributions
		
	MakeVariableIfNeeded("root:SPHINX:Import:imageBitInfo",255)
	
//	MakeVariableIfNeeded("root:SPHINX:Import:gHistLogFlag",1)
	MakeVariableIfNeeded("root:SPHINX:Import:gHistCntr",0)
	MakeVariableIfNeeded("root:SPHINX:Import:gHistMax",0)
	MakeVariableIfNeeded("root:SPHINX:Import:gHistMaxLoc",0)
	MakeVariableIfNeeded("root:SPHINX:Import:gHistCutLow",0)
	MakeVariableIfNeeded("root:SPHINX:Import:gHistCutHigh",0)
	
	MakeVariableIfNeeded("root:SPHINX:Import:gInfoFlag",0)
	MakeVariableIfNeeded("root:SPHINX:Import:gNameChoice",1)
	
	MakeStringIfNeeded("root:SPHINX:Import:gFileType","P3B")
	MakeStringIfNeeded("root:SPHINX:Import:gBitInfo","8bit")
	MakeStringIfNeeded("root:SPHINX:Import:gImportName","")
	MakeStringIfNeeded("root:SPHINX:Import:gStackName","")
	
	MakeVariableIfNeeded("root:SPHINX:Import:gXAxisMin",-1)
	MakeVariableIfNeeded("root:SPHINX:Import:gXAxisMax",-1)
	MakeStringIfNeeded("root:SPHINX:Import:gXAxisUnit","")
	
	MakeVariableIfNeeded("root:SPHINX:Import:gYAxisMin",-1)
	MakeVariableIfNeeded("root:SPHINX:Import:gYAxisMax",-1)
	MakeStringIfNeeded("root:SPHINX:Import:gYAxisUnit","")
	
	MakeVariableIfNeeded("root:SPHINX:Import:gEnergy",-1)
	MakeVariableIfNeeded("root:SPHINX:Import:gEAxisMin",-1)
	MakeVariableIfNeeded("root:SPHINX:Import:gEAxisMax",-1)
	MakeStringIfNeeded("root:SPHINX:Import:gEAxisUnit","")
End

// By default, set full image range as the component mapping analysis area
Function InitializeStackMapping(NumX,NumY)
	Variable NumX,NumY

	NewDataFolder /O root:SPHINX:SVD
	Variable /G root:SPHINX:SVD:gSVDLeft 		= 0
	Variable /G root:SPHINX:SVD:gSVDRight 		= ceil(NumX)
	Variable /G root:SPHINX:SVD:gSVDBottom 	= 0
	Variable /G root:SPHINX:SVD:gSVDTop 		= ceil(NumY)
End

// *************************************************************
// ****		Stack Display Panel
// *************************************************************
Function DisplayStack()

	DisplayStackBrowser("")
End

Function DisplayStackBrowser(StackName)
	String StackName
	
	InitializeStackBrowser()
	
	MakeStringIfNeeded("root:SPHINX:Browser:gStackName","")
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	
	if (strlen(StackName) == 0)
		gStackName 	= ChooseStack(" Choose a stack to browse pixels",gStackName,0)
	else
		gStackName 	= StackName
	endif
	
	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1)
		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)
		Variable NumE = Dimsize(SPHINXStack,2)
		
		MakeSPHINXROI(gStackName,NumX,NumY,1)
		
		MakeAveragedStack(SPHINXStack,NumX,NumY)
		
		InitializeStackMapping(NumX,NumY)
		
		// This is the displayed one
		WAVE /D avStack 		= $("root:SPHINX:Stacks:"+gStackName+"_av")
		
		// This is the real average
		WAVE /D averageStack 	= $("root:SPHINX:Stacks:"+gStackName+"_average")
	
		StackBrowserPanel(avStack,SPHINXStack,"Stack Browser: "+gStackName,"Browser",NumX,NumY,NumE)
	endif
End

Function MakeSPHINXROI(StackName,NumX,NumY,ResetFlag)
	String StackName
	Variable NumX,NumY, ResetFlag
	
	Variable MakeNew = 0
	String ROIName = "root:SPHINX:Stacks:"+StackName + "_roi"
	
	if ((ResetFlag) || (!WaveExists($ROIName)))
		MakeNew=1
	endif
	
	if (MakeNew)
		Make /O/B/U/N=(NumX,NumY) $ROIName	/WAVE=ROI
		ROI 	= NAN
	endif
End

Function StackBrowserPanel(StackDisplay,SPHINXStack,Title,Folder,NumX,NumY,NumE)
	Wave StackDisplay, SPHINXStack
	String Title,Folder
	Variable NumX, NumY, NumE
	
	// Locations of panel globals
	String PanelFolder 	= "root:SPHINX:"+Folder
	String PanelName 	= "Stack"+Folder
	
	// The actual stack and its location. 
	String StackName 		= NameOfWave(SPHINXStack)
	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
	String StackAxisName	= StackName + "_axis"
		
	WAVE StackAxis = $(CheckFolderColon(StackFolder) + StackAxisName)
	if (WaveExists(StackAxis) == 0)
		Make /O/D/N=(NumE) $(CheckFolderColon(StackFolder) + StackAxisName)
		WAVE StackAxis = $(CheckFolderColon(StackFolder) + StackAxisName)
		StackAxis = p
	endif
	
	String OldDf = GetDataFolder(1)
	NewDataFolder /O/S $PanelFolder
	
		// Make waves for extracting pixel spectra
		Make /O/D/N=(NumE) energy, spectrum, specresid, specbg, specfit, specplot, prange, pspectrum
		energy = StackAxis
		
		//  Make waves for extracting line spectra
		Make /O/N=2 ProfileLineX, ProfileLineY
		
		ResetExtraction(SPHINXStack,PanelFolder)
		
		DoWindow /K $PanelName
		NewPanel /K=1/W=(228,5,656,830) as Title
		Dowindow /C $PanelName
		CheckWindowPosition(PanelName,228,5,656,830)
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(StackDisplay)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(StackDisplay,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
		
		SetWindow $PanelName,userdata+= "ColorScaleName="+";"
		
		// Give this panel information about the displayed plot
		SetWindow $PanelName,userdata+= "VCsrWinName="+PanelName+"#PixelPlot;"
		SetWindow $PanelName,userdata+= "VCsrTraceName=specplot;"
		SetWindow $PanelName,userdata+= "VCsr1=C;"
		SetWindow $PanelName,userdata+= "VCsr1r=0;"
		SetWindow $PanelName,userdata+= "VCsr1g=0;"
		SetWindow $PanelName,userdata+= "VCsr1b=65535;"
		SetWindow $PanelName,userdata+= "VCsr2=D;"
		SetWindow $PanelName,userdata+= "VCsr2r=65535;"
		SetWindow $PanelName,userdata+= "VCsr2g=0;"
		SetWindow $PanelName,userdata+= "VCsr2b=52428;"
		
		//  	-------- 	Display the stack image
		Display/W=(10,110,415,465)/HOST=# 
			AppendImage StackDisplay
			ModifyGraph mirror=2, standoff=0,height={Aspect,0.9}
			ModifyGraph margin(left)=45,margin(bottom)=30,margin(top)=10,margin(right)=10,width=350
			RenameWindow #, StackImage
		SetActiveSubwindow ##
		
		// 	-------- 	Display the extracted plot
//		Display/W=(10,490,415,695)/HOST=#  specplot vs energy
		Display/W=(8,571,413,815)/HOST=#  specplot vs energy
			ModifyGraph /W=# mirror=2, margin(right)=22, margin(left)=43
		RenameWindow #, PixelPlot
		
		Variable EMinPt 	 = 0.1*NumE
		Variable EMaxPt 	 = 0.9*NumE
		
		// Place cursors on the plot for linear background subtraction
		MakeVariableIfNeeded(PanelFolder+":gCursorEMin",energy[EMinPt])
		MakeVariableIfNeeded(PanelFolder+":gCursorEMax",energy[EMaxPt])
		NVAR gCursorEMin 	= $(PanelFolder+":gCursorEMin")
		NVAR gCursorEMax 	= $(PanelFolder+":gCursorEMax")
		
		// Place cursors on the plot for image processing
		MakeVariableIfNeeded(PanelFolder+":gCursorE1",energy[0.8*NumE])
		MakeVariableIfNeeded(PanelFolder+":gCursorE2",energy[0.2*NumE])
		NVAR gCursorE1 	= $(PanelFolder+":gCursorE1")
		NVAR gCursorE2 	= $(PanelFolder+":gCursorE2")
		
		// Create the Plot of Extracted Spectra
		SetActiveSubwindow StackBrowser#PixelPlot
			// Cursors for linear background subtraction
			Cursor /W=# A specplot EMinPt
			Cursor /W=# B specplot EMaxPt
			
			// Cursors for image ratio or subtraction - DARK BLUE = on-peak
			Cursor /C=(0,0,65535)/F/S=2/H=2/W=# C specplot gCursorE1, 0
			// Cursors for image ratio or subtraction - MAGENTA = off-peak
			Cursor /C=(65535,0,52428)/F/S=2/H=2/W=# D specplot gCursorE2, 0
			
			// Give some instructions
			SetDrawEnv fname= "Helvetica",fstyle= 1,textrgb= (30583,30583,30583)
			DrawText 0.685294117647059,0.0909090909090909,"Press 1 or 2 to get"
			SetDrawEnv fname= "Helvetica",fstyle= 1,textrgb= (30583,30583,30583)
			DrawText 0.726470588235294,0.188311688311688,"vertical cursors"
		SetActiveSubwindow ##
		
		//  	-------- 	Display an extracted spectrum  ...
		Variable AX = NumVarOrDefault(PanelFolder + ":gCursorAX",NumX/2)
		Variable AY = NumVarOrDefault(PanelFolder + ":gCursorAY",NumY/2)
		ExtractSpectrumFromPixel(SPHINXStack,"",PanelFolder,AX,AY,0)
		
		AppendContrastControls(NameOfWave(StackDisplay),"root:SPHINX:Stacks",PanelFolder,NumX,NumY)
		
		AppendCursors(NameOfWave(StackDisplay),PanelName,"StackImage",PanelFolder,NumX,NumY,470,0)
		
		AppendROIControls(NameOfWave(StackDisplay),PanelName,"Stackimage",GetWavesDataFolder(StackDisplay,1),PanelFolder,NumX,NumY,64,87)
		
		// Transfer current cursor positions to all suitable images MANUALLY ... 
		Button TransferCrsButton,pos={220,468}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,468}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"
		// .. or AUTOMATICALLY. 
		Variable /G gAutoTransfer=0
		CheckBox AutoTransfer,pos={290,469}, size={55,26},fSize=11,title="Auto Transfer",variable= $(PanelFolder+":gAutoTransfer")
		
		//	========			Panel Hooks ... for the Stack plot ...
		SetWindow StackBrowser, hook(PanelCursorHook)=BrowserCursorHooks
		SetWindow StackBrowser, hook(PanelCloseHook)=KillBrowserHooks
		SetWindow StackBrowser, hook(PanelMarqueeHook)=MarqueeMenu
		// ... and for the Spectrum plot
		SetWindow StackBrowser, hook(VerticalCursorsHook)=VCsrHook
		
		// Group boxes at the top
		GroupBox EAxisBox,pos={138,0},size={76,58}, title="Energy axis",fColor=(39321,1,1)
		GroupBox AnimationBox,pos={215,0},size={76,58}, title="Animation",fColor=(39321,1,1)
		GroupBox LocationsBox,pos={292,0},size={76,58}, title="ROI locations",fColor=(39321,1,1)
//		GroupBox RefSpectraBox2,pos={369,0},size={115,58}, title="Refs",fColor=(39321,1,1)
		
		GroupBox SpectraExtractBox,pos={138,57},size={280,52}, title="E, L or r/R to extract spectrum from pixel, line or ROI",fColor=(39321,1,1)
		
		// LOAD or REVERSE an energy axis
		Button LoadEnergyAxis,pos={148,15}, size={60,18},fSize=13,proc=StackPanelButtons,title="Load"
		Button ReverseAxis,pos={148,34}, size={60,18},fSize=13,proc=StackPanelButtons,title="Reverse"
		
		// Stack to Movie buttons
		Button ResetExtraction,pos={300,15}, size={60,18},fSize=13,proc=StackPanelButtons,title="Reset"
		Button ShowPositions,pos={300,34}, size={60,18},fSize=13,proc=StackPanelButtons,title="Show"
		
		// Some ROI Buttons
		Button NewAnimation,pos={224,15}, size={60,18},fSize=13,proc=StackPanelButtons,title="New"
		Button ShowAnimation,pos={224,34}, size={60,18},fSize=13,proc=StackPanelButtons,title="Show"
		
		// Extracted Plot controls
		MakeVariableIfNeeded(PanelFolder+":gLinBGFlag",0)
		CheckBox LinBGFlag,pos={147,72},size={184,14},title="Linear BG",fSize=11,variable= $(PanelFolder+":gLinBGFlag")
		
		// I don't think this option is needed anymore
//		MakeVariableIfNeeded(PanelFolder+":gInvertSpectraFlag",0)
//		CheckBox InvertSpectraCheck,pos={147,72},size={114,17},title="Invert",fSize=11,variable= $(PanelFolder+":gInvertSpectraFlag")
		
		Variable /G gAutoSVD=0
		CheckBox AutoSVD,pos={147,88}, size={55,26},fSize=11,title="Auto Analyze",variable= $(PanelFolder+":gAutoSVD")
		
		// Bin pixels to improve statistics
		MakeVariableIfNeeded(PanelFolder+":gCursorBin",1)
		SetVariable CursorBinSetVar,title="Bin pixels",fSize=11,pos={318,69},limits={1,inf,2 },size={90,17},value= $(PanelFolder+":gCursorBin")
		
		// Skip n pixels during line scans to avoid gazillions of extracted spectra
		MakeVariableIfNeeded(PanelFolder+":gSkipped",1)
		SetVariable LineSkipSetVar,title="Skip pixels in line",fSize=11,pos={268,88},limits={1,inf,1},size={140,17},value= $(PanelFolder+":gSkipped")
		
		// Average image frames when dividing or subtracting to improve statistics
		MakeVariableIfNeeded(PanelFolder+":gNFramesOn",1)
		MakeVariableIfNeeded(PanelFolder+":gNFramesOff",1)
		SetVariable NFramesOnSetVar,title="on",fSize=11,pos={237,510},limits={1,7,2},size={54,17},value= $(PanelFolder+":gNFramesOn"),fstyle=1,valueColor=(0,0,65535)
		SetVariable NFramesOffSetVar,title="off",fSize=11,pos={235,539},limits={1,29,2},size={56,17},value= $(PanelFolder+":gNFramesOff"),fstyle=1,valueColor=(65535,0,52428)
		
		SetVariable NFramesOnSetVar fstyle=1,valueColor=(0,0,65535)
		
		// Group boxes at the -- BOTTOM --
		GroupBox IzeroBox,pos={8,492},size={94,72}, title="Normalization",fColor=(39321,1,1)
		GroupBox RefSpectraBox,pos={298,492},size={115,72}, title="Reference Spectra",fColor=(39321,1,1)
		GroupBox ImageProcBox,pos={105,492},size={190,72}, title="   Show and process stack frames",fColor=(39321,1,1)
		
		Button ShowFrame,pos={110,508}, size={60,26},fSize=13,fstyle=1,valueColor=(0,0,65535),proc=StackPanelButtons,title="Frame"
		Button ShowAverage,pos={110,534}, size={60,26},fSize=13,proc=StackPanelButtons,title="Average"
		Button ImageRatio,pos={173,508}, size={60,26},fSize=13,proc=StackPanelButtons,title="Divide"
		Button ImageDifference,pos={173,534}, size={60,26},fSize=13,proc=StackPanelButtons,title="Subtract"
		
		// 2014-04-12 Add options for either TRANSMISSION or EMISSION normalization of data
		MakeVariableIfNeeded(PanelFolder+":gIoDivFlag",0)		// <--- obselete, but keep for backwards compatibility
		MakeVariableIfNeeded(PanelFolder+":gIoDivChoice",1)
		NVAR gIoDivChoice 	= $(PanelFolder+":gIoDivChoice")
		WaveStats /Q/M=1 StackDisplay
		Variable /G gIoODIMax 	= V_max
		
		
		String NormList = "\""+"none;divide;OD-Izero;OD-Int;"+"\""
		PopupMenu IzeroNormMenu,fSize=10,pos={10,506},size={112,18},title=" ",value= #NormList, mode=gIoDivChoice
		PopupMenu IzeroNormMenu,proc=IzeroNormMenuProc
		
		Button CaptureIo,pos={12,531}, size={26,26},fSize=13,proc=StackPanelButtons,title="I\B0"
		SetVariable ODIntSetVar,title=" ",fSize=12,pos={40,539},limits={0,Inf,0.1},size={59,18},value= $(PanelFolder+":gIoODIMax"),format="%3.1f"
		
		// Choose plotted spectrum as a reference for chemical distribution mapping
		Button RefSelect,pos={302,507}, size={50,24},fSize=13,proc=StackPanelButtons,title="Select"
		Button RefReset,pos={358,507}, size={50,24},fSize=13,proc=StackPanelButtons,title="Reset"
		Button RefShow,pos={302,534}, size={50,24},fSize=13,proc=StackPanelButtons,title="Show"
		
		// for small monitors!!"
//		Button RefShow2,pos={375,72}, size={50,24},fSize=13,proc=StackPanelButtons,title="Show"

//		MakeVariableIfNeeded(PanelFolder+":gIoODIMax",0)
//		CheckBox IoDivideCheck,pos={16,700},title=" ",fSize=11,variable= $(PanelFolder+":gIoDivFlag"), disable=2
		
		// Automatically apply some kind of intensity normalization
//		GroupBox INormalizeBox, pos={8,752}, title="   Normalize",fColor=(39321,1,1) // This may not be needed
//		MakeVariableIfNeeded(PanelFolder+":gNormFlag",0)
//		CheckBox NormCheckBox,pos={16,751},title=" ",fSize=11,proc=NormExtractedSpectra,variable= $(PanelFolder+":gNormFlag"),disable=2
		
//		if (0)
//			GroupBox ECorrectBox,pos={105,700},size={190,72}, title="   Correct pixel energy axes",fColor=(39321,1,1)
//		
//			// Select and fit to a peak at known energy to correct all pixes energy offsets. 
//			Variable /G gECorrectFlag=0
//			CheckBox ShowECorrectCheck,pos={113,700},title=" ",fSize=11,proc=ShowPRange,variable= $(PanelFolder+":gECorrectFlag")
//			
//			MakeVariableIfNeeded(PanelFolder+":gPMin",0)
//			MakeVariableIfNeeded(PanelFolder+":gPMax",NumE-1)
//			SetVariable PMinSetVar,title="peak fit range",pos={114,751},size={110,18},proc=SetPRange,value= $(PanelFolder+":gPMin"),disable=2
//			SetVariable PMaxSetVar,title=" - ",pos={227,751},size={58,18},proc=SetPRange,value= $(PanelFolder+":gPMax"),disable=2
//			
//			MakeVariableIfNeeded(PanelFolder+":gPEnergy",0)
//			SetVariable PEnergySetVar,fsize=11,title="Peak E =",pos={110,723},size={120,19},value= $(PanelFolder+":gPEnergy"),disable=2
//			
//			Button CorrectE,pos={235,719}, size={55,26},fSize=13,proc=StackPanelButtons,title="Correct",disable=2
//		endif
		
	SetDataFolder $(OldDf)
End


// *************************************************************
// ****		Controls on the Stack Browser panel only
// *************************************************************
Function StackPanelButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	Variable eventMod 	= B_Struct.eventMod
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	Variable ShiftDown = 0
	if ((eventMod & 2^1) != 0)	// Bit 1 = shift key down
		ShiftDown = 1
	endif
	
	// This is everything we need to look up, starting from the SUBWINDOW name
	String PanelName 	= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	String StackWindow = PanelName+"#StackImage"
	String SpectraWindow 	= PanelName +"#PixelPlot"
	
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	String StackFolder	= GetWavesDataFolder(avStack,1)
	String StackName 	= ReplaceString("_av",StackAvg,"")
	String IzeroName, StackAxisName
	
	WAVE SPHINXStack	= $(StackFolder+StackName)
	WAVE StackAxis  	= $(ParseFilePath(2,StackFolder,":",0,0)+StackName+"_axis")
	WAVE energy 		= $(PanelFolder + ":energy")
	NVAR gNFramesOn 	= $(PanelFolder+":gNFramesOn")
	NVAR gNFramesOff 	= $(PanelFolder+":gNFramesOff")
	
	if (cmpstr(ctrlName,"LoadEnergyAxis") == 0)
		RealLoadStackAxis(SPHINXStack)
	elseif (cmpstr(ctrlName,"ReverseAxis") == 0)
		ReverseStackAxis(StackFolder,StackName)
		
	elseif (cmpstr(ctrlName,"NewAnimation") == 0)
		NewStackMovie()
	elseif (cmpstr(ctrlName,"ShowAnimation") == 0)
//		ShowStackMovie()
		
	elseif (cmpstr(ctrlName,"ImageHistButton") == 0)
		ShowImageHistogram(SPHINXStack,StackName,PanelFolder,"StackBrowser")
		
	// I don't think these buttons are still active ... 
	elseif (cmpstr(ctrlName,"ImageSaveButton") == 0)
		ExportImage(SPHINXStack,1,"default")
	elseif (cmpstr(ctrlName,"ExportPositions") == 0)
		ExportPixelPositions(SPHINXStack)
		
	elseif (cmpstr(ctrlName,"ResetExtraction") == 0)
		ResetExtraction(SPHINXStack,PanelName)
	elseif (cmpstr(ctrlName,"ShowPositions") == 0)
		DisplaySPHINXImage(StackName + "_extract")
		
	elseif (cmpstr(ctrlName,"CaptureIo") == 0)
		if (ShiftDown == 0)
			// Select the DISPLAYED spectrum to be the Izero. Either normalized or not depending on user choice. 
			Duplicate /O/D root:SPHINX:Browser:specplot, root:SPHINX:Browser:spectrumIo
//			Duplicate /O/D root:SPHINX:Browser:spectrum, root:SPHINX:Browser:spectrumIo
		else
			WAVE specIo 		= root:SPHINX:Browser:spectrumIo
			IzeroName 			= UniqueName(StackName + "_Io_",1,0)
			StackAxisName 		= StackName + "_axis"
			AdoptAxisAndDataFromMemory(StackAxisName,"null",StackFolder,"spectrumIo","null",PanelFolder,IzeroName,"",0,1,1)
		endif
		
	elseif (cmpstr(ctrlName,"ImageRatio") == 0)
		StackFrameProcessing(SPHINXStack,energy,StackName,SpectraWindow,"Divide",gNFramesOn,gNFramesOff)
		
	elseif (cmpstr(ctrlName,"ImageDifference") == 0)
		StackFrameProcessing(SPHINXStack,energy,StackName,SpectraWindow,"Subtract",gNFramesOn,gNFramesOff)
		
	elseif (cmpstr(ctrlName,"ShowAverage") == 0)
		DisplayStackFrame(SPHINXStack,PanelName,-1)
		
	elseif (cmpstr(ctrlName,"ShowFrame") == 0)
		Variable xPoint = NumberByKey("POINT",CsrInfo(C,SpectraWindow),":",";")
		Variable frame = FrameFromPoint(energy,xPoint)
		
		DisplayStackFrame(SPHINXStack,PanelName,frame)
		
	elseif (cmpstr(ctrlName,"RefReset") == 0)
		InitializeSVD(1)
		
	elseif (cmpstr(ctrlName,"RefSelect") == 0)
		ExtractReferenceSpectrum(StackAxis,StackName,PanelName)
		
	elseif ((cmpstr(ctrlName,"RefShow") == 0) ||  (cmpstr(ctrlName,"RefShow2") == 0))
		ReferenceSpectraPanel(StackName,PanelName)
		
	endif
End

Function IzeroNormMenuProc(PU_Struct) : PopupMenuControl
	STRUCT WMPopupAction &PU_Struct
	
	String panelName 		= PU_Struct.win
	String ctrlName 		= PU_Struct.ctrlName
	Variable eventCode 		= PU_Struct.eventCode
	NVAR gIoDivChoice 		= root:SPHINX:Browser:gIoDivChoice
	
	if (eventCode < 0)
		return 0	// This is needed!!
	endif
	
	if (cmpstr(ctrlName,"IzeroNormMenu")==0)
		gIoDivChoice 	= PU_Struct.popNum
	endif
End

// *************************************************************
// ****		Stack Frame processing
// *************************************************************
Function StackFrameProcessing(SPHINXStack,energy,StackName,SpectraWindow,ImageOp,NOn,NOff)
	Wave SPHINXStack, energy
	String StackName, SpectraWindow, ImageOp
	Variable NOn,NOff
	
	Variable xPoint, energy1, frame1, energy2, frame2, NumX, NumY
	String E1str, E2str, ResultName, FullName, msg
	
	KillWaves /Z frame_1, frame_2
	
	// The blue ON-PEAK cursor C
	xPoint 		= NumberByKey("POINT",CsrInfo(C,SpectraWindow),":",";")
	frame1 		= FrameFromPoint(energy,xPoint)
	energy1 	= energy[frame1]
	sprintf E1str, "%3.2f",  energy1
	
	// The magenta OFF-PEAK cursor D
	xPoint 		= NumberByKey("POINT",CsrInfo(D,SpectraWindow),":",";")
	frame2 		= FrameFromPoint(energy,xPoint)
	energy2 	= energy[frame2]
	sprintf E2str, "%3.2f",  energy2
	
	if ((frame1 < 0) || (frame2 < 0))
		return 0
	endif
				
	NumX 	= DimSize(SPHINXStack,0)
	NumY 	= DimSize(SPHINXStack,1)
	Make /O/D/N=(NumX,NumY) frame_1, frame_2
	
	AverageNFrames(SPHINXStack,frame_1,frame1,NOn)
	AverageNFrames(SPHINXStack,frame_2,frame2,NOff)
	
	strswitch (ImageOp)
		case "Subtract":
			Print " 	*** Subtraction distribution map."
			ResultName = CheckSPHINXImageName(StackName+"_"+E1str+"m"+E2str,"Please shorten name of subtraction result")
			if (cmpstr("_quit!_",ResultName) == 0)
				return 0
			endif
			FullName = "root:SPHINX:Stacks:"+ReplaceString(".",ResultName,"p")
			MatrixOp /O $FullName = frame_1-frame_2
			WAVE Image 	= $FullName
			Note /K Image, NameOfWave(Image)
			Note Image, "ImageType=Subtraction distribution map;"
			break
		case "Divide":
			Print " 	*** Division distribution map."
			ResultName = CheckSPHINXImageName(StackName+"_"+E1str+"d"+E2str,"Please shorten name of division result")
			if (cmpstr("_quit!_",ResultName) == 0)
				return 0
			endif
			FullName = "root:SPHINX:Stacks:"+ReplaceString(".",ResultName,"p")
			MatrixOp /O $FullName = frame_1/frame_2
			
			// Get rid of any Inf
			WAVE Image 	= $FullName
			Image[][] = (numtype(Image[p][q]) == 0) ? Image[p][q] : NaN
			Note /K Image, NameOfWave(Image)
			Note Image, "ImageType=Division distribution map;"
			break
		default:
			break
	endswitch
	
	msg = "OnPeak="+num2str(energy1)+"eV; OnFrames="+num2str(NOn)+" frames;"
	Print " 		... " + msg
	Note /NOCR Image, msg
	msg = "OffPeak="+num2str(energy2)+"eV; OffFrames="+num2str(NOff)+" frames;"
	Print " 		... " + msg
	Note /NOCR Image, msg
	
	TransferSPHINXImageScale(SPHINXStack,$FullName)
	
	DisplaySPHINXImage(ReplaceString(".",ResultName,"p"))
	
	KillWaves /Z frame_1, frame_2
End

Function AverageNFrames(SPHINXStack,AverageImage,Frame,NFrames)
	Wave SPHINXStack, AverageImage
	Variable Frame, NFrames
	
	Variable i, i0=Frame - (NFrames-1)/2, i1=Frame + (NFrames-1)/2, n=0
	
	AverageImage = 0
	
	for (i=i0;i<=i1;i+=1)
		n += 1
		ImageTransform /P=(i) getPlane SPHINXStack
		WAVE M_ImagePlane = M_ImagePlane
		AverageImage += M_ImagePlane
	endfor
	
	AverageImage /= n
End

Function /T CheckSPHINXImageName(ResultName,Msg)
	String ResultName, Msg
	
	String ImageName = ResultName
	
	if (strlen(ResultName) > 20)
		do
			ImageName 	= PromptForUserStrInput(ResultName,"",Msg)
			if (cmpstr("_quit!_",ImageName) == 0)
				ImageName 	= ImageName[0,30]
			endif
		while(strlen(ImageName) > 30)
	endif
	
	return ImageName
End

Function FrameFromPoint(energy,xPoint)
	Wave energy
	Variable xPoint

	Variable eValue, NumE = numpnts(energy)
	
	eValue 	= energy[0] + xPoint*(energy[NumE-1] - energy[0])
	
	return BinarySearch(energy,eValue)
End

// *************************************************************
// ****		Controlling the image displayed in the Browser
// *************************************************************

Function DisplayStackFrame(SPHINXStack,PanelFolder,frame)
	Wave SPHINXStack
	String PanelFolder
	Variable frame
	
	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
	String StackName		= NameOfWave(SPHINXStack)
	
	WAVE avStack 			= $("root:SPHINX:Stacks:"+NameOfWave(SPHINXStack)+"_av")
	WAVE averageStack 		= $("root:SPHINX:Stacks:"+NameOfWave(SPHINXStack)+"_average")
	
	if (frame == -1)
		avStack = averageStack
	else
		ImageTransform /P=(frame) getPlane SPHINXStack
		WAVE M_ImagePlane = M_ImagePlane
		
		avStack = M_ImagePlane
	endif
End

// *************************************************************
// ****		Capturing a rectangular ROI for SVD analysis
// *************************************************************
Function DefineSVDROI(WindowName,StackName,StackFolder,X1,X2,Y1,Y2)
	String WindowName,StackName,StackFolder
	Variable X1,X2,Y1,Y2
	
	Variable i, XMin, XMax, XRange, YMin, YMax, YRange
	
	WAVE SPHINXStack 	= ImageNameToWaveRef(WindowName, StackName+"_av") 
	
	MakeSPHINXROI(StackName,DimSize(SPHINXStack,0),Dimsize(SPHINXStack,1),0)
	WAVE ROI 			= $(ParseFilePath(2,StackFolder,":",0,0)+StackName+"_roi")
	
	ROI = 1
	ROI[X1,X2][Y1,Y2] = 0
	
	// Record the corners in globals
//	NewDataFolder /O root:SPHINX:SVD
//	Variable /G root:SPHINX:SVD:gSVDLeft 		= floor(X1)
//	Variable /G root:SPHINX:SVD:gSVDRight 		= ceil(X2)
//	Variable /G root:SPHINX:SVD:gSVDBottom 	= floor(Y1)
//	Variable /G root:SPHINX:SVD:gSVDTop 		= ceil(Y2)
	
	NVAR gSVDLeft 		=  root:SPHINX:SVD:gSVDLeft
	NVAR gSVDRight 	=  root:SPHINX:SVD:gSVDRight
	NVAR gSVDBottom 	=  root:SPHINX:SVD:gSVDBottom
	NVAR gSVDTop 		=  root:SPHINX:SVD:gSVDTop
	
	gSVDLeft 		= floor(X1)
	gSVDRight 		= ceil(X2)
	gSVDBottom 	= floor(Y1)
	gSVDTop 		= ceil(Y2)
	
	// Display the ROI on the image
	SetDrawLayer /W=$WindowName /K ProgFront
	SetDrawLayer /W=$WindowName ProgFront
	SetDrawEnv /W=$WindowName linethick= 2,linefgc= (65535,65535,0),fillpat= 0,xcoord=bottom,ycoord=left
	DrawRect /W=$WindowName  X1,Y1,X2,Y2
End

// Create a new contextual menu following Shift-Click within Stack marquee. 
Function MarqueeMenu(s) 
	STRUCT WMWinHookStruct &s 

	String WindowName = s.winname
	String PanelName 	= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	String StackWindow = PanelName+"#StackImage"
	
	GetWindow $PanelName activeSW 
	if (cmpstr(S_value, StackWindow) != 0) 
		return 0 
	endif
	
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	String StackFolder	= GetWavesDataFolder(avStack,1)
	String StackName 	= ReplaceString("_av",StackAvg,"")
	WAVE SPHINXStack	= $(StackFolder+StackName)
	
	Variable X1,X2,Y1,Y2,ret=0
	
	switch(s.eventcode)
		case 3: 			// mousedown
			GetMarquee/Z left, bottom
			
			if ((V_Flag ) && (GetKeyState(0) & 4))
				// I.e., we only get here if (i) click occurs inside marque and (ii) SHIFT is held down. 
				Variable xpix= s.mouseLoc.h
				Variable ypix= s.mouseLoc.v
				
				String checked= "\\M0:!" + num2char(18)+":"
				String divider="\\M1-;"
				
				PopupContextualMenu/C=(xpix, ypix) "Analysis area = marquee;Analysis area = displayed;"//+divider+"PCA on marquee;PCA on marque with ROI;"
				
				if (StrSearch(S_selection,"marquee",0) > -1)
					// First define the ROI to be the marquee
					X1 = max(V_left,0)
					X2 = min(V_right,DimSize(SPHINXStack,0))
					
					Y1 = max(V_bottom,0)
					Y2 = min(V_top,DimSize(SPHINXStack,1))
					
					DefineSVDROI(WindowName,StackName,StackFolder,X1,X2,Y1,Y2)
						
				elseif (StrSearch(S_selection,"displayed",0) > -1)
					GetAxis /Q/W=$WindowName bottom
					X1 = max(V_min,0)
					X2 = min(V_max,DimSize(SPHINXStack,0)-1)
					
					GetAxis /Q/W=$WindowName left
					Y1 = max(V_min,0)
					Y2 = min(V_max,DimSize(SPHINXStack,1)-1)
					
					DefineSVDROI(WindowName,StackName,StackFolder,X1,X2,Y1,Y2)
				endif
				
				// Then perform PCA if requested
				if (StrSearch(S_selection,"PCA",0) > -1)
					NVAR gROIMapFlag 	= root:SPHINX:SVD:gROIMappingFlag	
					if (StrSearch(S_selection,"ROI",0) > -1)
						gROIMapFlag = 1
					else
						gROIMapFlag = 0			
					endif
					
					DoAlert 0, "PCS is not implemented yet!"
//					ROIPCA(SPHINXStack,StackFolder,PanelFolder,2)
				endif
				
				ret= 1	// skip the standard marquee menu
			endif
			break
	endswitch
	
	return ret
End

// *************************************************************
// ****		Import a text file containing the energy values
// *************************************************************
Function RealLoadStackAxis(SPHINXStack)
	Wave SPHINXStack
	
	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
	String SPHINXFolder 	= "root:SPHINX:"

	Variable NumE = Dimsize(SPHINXStack,2)
	String StackName 		= NameOfWave(SPHINXStack)
	String LoadWaveList 	= InteractiveLoadTextFile("Please locate the axis file")
	
	FinishStackAxisLoad(LoadWaveList,StackFolder,StackName,NumE)
End

Function FinishStackAxisLoad(LoadWaveList,StackFolder,StackName,NumE)
	String LoadWaveList, StackFolder, StackName
	Variable NumE
	
	Variable AbortFlag=0, NumA

	if (ItemsInList(LoadWaveList) > 0)
		String StackAxisName	= StackName + "_axis"
		String AxisName		= StringFromList(0,LoadWaveList)
		WAVE axis 	= $AxisName
		
		NumA = numpnts(axis)
		
		if (NumA < NumE)
			DoAlert 0, "Loaded axis has fewer than "+num2str(NumE)+" points! Aborting. "
			AbortFlag = 1
		elseif (NumA > NumE)
			DoAlert 1, "Loaded axis has more than "+num2str(NumE)+" points! Continue? "
			if (V_flag)
				Print " 	*** Loaded only the first",NumE,"energy values from the",NumA,"values in the file."
			else
				AbortFlag = 1
			endif
		endif
		
		if (AbortFlag)
			KillWavesFromList(LoadWaveList,1)
			return 0
		endif
		
		Duplicate /O/D $AxisName, $(CheckFolderColon(StackFolder) + StackAxisName)
		
		// *!*!* Must update the plot energy axis in order to fitting to work properly. 
		WAVE energy 	= root:SPHINX:Browser:energy
		if (WaveExists(energy))
			energy = axis
		endif
		
		KillWavesFromList(LoadWaveList,0)
		
		return 1
	endif
	
	return 0
End


// What is the point of this, exactly? To reverse the direction of the energy axis to match the stack frame order. 
Function ReverseStackAxis(StackFolder,StackName)
	String StackFolder,StackName
	
	WAVE SPHINXStack 		= $(CheckFolderColon(StackFolder) + StackName)
	WAVE StackAxis 		= $(CheckFolderColon(StackFolder) + StackName + "_axis")
	
	if (WaveExists(StackAxis))
		Reverse StackAxis
		
		Wave energy 		= root:SPHINX:Browser:energy
		Reverse energy
		
		ImageTransform flipPlanes SPHINXStack
	endif
End

// *************************************************************
// ****		Images recording the pixel positions from which spectra were extracted
// *************************************************************
Function ExportPixelPositions(SPHINXStack)
	Wave SPHINXStack
	
	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
	String StackName		= NameOfWave(SPHINXStack)
	String ExtractName 		= StackName + "_extract"
	
	WAVE ExtractPositions	= $(ParseFilePath(2,StackFolder,":",0,0) + ExtractName)
	
	ImageSave /I ExtractPositions as ExtractName+".tif"
End

Function ResetExtraction(SPHINXStack,PanelFolder)
	Wave SPHINXStack
	String PanelFolder
	
	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
	String StackName		= NameOfWave(SPHINXStack)
	String ExtractName 		= StackName + "_extract"
	
	Variable NumX = Dimsize(SPHINXStack,0)
	Variable NumY = Dimsize(SPHINXStack,1)
	
	// Make/reset a 2D image for displaying the extraction positions. 
	Make /O/N=(NumX,NumY) $(ParseFilePath(2,StackFolder,":",0,0) + ExtractName) = 0
	
	// Variables to keep track of the number of Extracted and Adopted spectra. 
	MakeVariableIfNeeded(StackFolder+"g"+StackName+"_roiNum",0)
	NVAR gROINumber 	= $(StackFolder+"g"+StackName+"_roiNum")
	gROINumber = 0
	
	MakeVariableIfNeeded(StackFolder+"g"+StackName+"_roiPixel",0)
	NVAR gROIPixelNum 	= $(StackFolder+"g"+StackName+"_roiPixel")
	gROIPixelNum = 0
	
	MakeVariableIfNeeded(StackFolder+"g"+StackName+"_lineNum",0)
	NVAR gLineNumber 	= $(StackFolder+"g"+StackName+"_lineNum")
	gLineNumber = 0
End

// *************************************************************
// ****		Housekeeping -- Stack Browser Hooks to catch window kill events
// *************************************************************
Function KillBrowserHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
		
	Variable hookResult 	= 0
	Variable keyCode 		= H_Struct.keyCode
	Variable eventCode		= H_Struct.eventCode
	Variable Modifier 		= H_Struct.eventMod
	Variable CmdBit 		= 3
	
	return 0
	
	if (eventCode == 2) 	// Window kill
		// This is everything we need to look up, starting from the subWindow name
		String WindowName = H_Struct.winname
		String PanelName 	= ParseFilePath(0, WindowName, "#", 0, 0)
		String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
		String StackWindow = PanelName+"#StackImage"
		String SpectraWindow = PanelName+"#PixelPlot"
		String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
		WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
		String StackFolder	= GetWavesDataFolder(avStack,1)
		string StackName 	= ReplaceString("_av",StackAvg,"")
		WAVE SPHINXStack	= $(StackFolder+StackName)
		
		NVAR gCursorAX 	= $(PanelFolder+":gCursorAX")
		NVAR gCursorAY 	= $(PanelFolder+":gCursorAY")
		NVAR gCursorBX 	= $(PanelFolder+":gCursorBX")
		NVAR gCursorBY 	= $(PanelFolder+":gCursorBY")
		NVAR gCursorEMin 	= $(PanelFolder+":gCursorEMin")
		NVAR gCursorEMax 	= $(PanelFolder+":gCursorEMax")
		NVAR gCursorE1 	= $(PanelFolder+":gCursorE1")
		NVAR gCursorE2 	= $(PanelFolder+":gCursorE2")
		
		gCursorAX 		= NumberByKey("POINT",CsrInfo(A,StackWindow),":",";")
		gCursorAY 		= NumberByKey("YPOINT",CsrInfo(A,StackWindow),":",";")
		gCursorBX 		= NumberByKey("POINT",CsrInfo(B,StackWindow),":",";")
		gCursorBY 		= NumberByKey("YPOINT",CsrInfo(B,StackWindow),":",";")
		
		gCursorEMin 	= NumberByKey("POINT",CsrInfo(A,SpectraWindow),":",";")
		gCursorEMax 	= NumberByKey("POINT",CsrInfo(B,SpectraWindow),":",";")
		gCursorE1 		= NumberByKey("POINT",CsrInfo(C,SpectraWindow),":",";")
		gCursorE2 		= NumberByKey("POINT",CsrInfo(D,SpectraWindow),":",";")
		
		// Much less hassle to automatically close the Ref Spectra Panel as well
		DoWindow /K ReferencePanel
		
		String HistPanel = StackName+"_hist"
		DoWindow $HistPanel
	endif
	
	return hookResult
End

// *************************************************************
// ****		Extracting Spectra from Stack Pixels
// *************************************************************

// This is the main Panel Hook for cursur and extraction events
// Catch cursor moves on the StackWindow, and update global cursor values. 
Function BrowserCursorHooks(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 
	
	String WindowName 	= H_Struct.winname
	Variable eventCode 		= H_Struct.eventCode
	Variable keyCode 		= H_Struct.keyCode
	String csrname 			= H_Struct.cursorName
	
	// Check that the image subWindow is active
	GetWindow $WindowName activeSW
	String subWindow 	= ParseFilePath(0, S_Value, "#", 1, 0)
	if (cmpstr(subWindow,"StackImage") != 0)
		return 0
	endif
	
	Variable eventMod 	= H_Struct.eventMod
	Variable ShiftDown=0, CommandDown=0
	if ((eventMod & 2^1) != 0)	// Bit 1 = shift key down
		ShiftDown = 1
	endif
	if ((eventMod & 2^3) != 0)	// Bit 2 = option key down
		CommandDown=1
	endif
	
	Variable AdoptFlag, AutoSVD, CsrX, CsrY, CsrZ, ret=0
	
	String PanelName 	= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	String StackWindow = PanelName+"#StackImage"
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	String StackFolder	= GetWavesDataFolder(avStack,1)
	string StackName 	= ReplaceString("_av",StackAvg,"")
	WAVE SPHINXStack	= $(StackFolder+StackName)
	
	NVAR gSkipped			= $(PanelFolder +":gSkipped")
	WAVE ProfileLineX		= $(PanelFolder +":ProfileLineX")
	WAVE ProfileLineY		= $(PanelFolder +":ProfileLineY")
	
	// Extract and display the spectrum if the cursor has been moved. 
	if (eventCode == 7)	// cursor moved. 
		
		// *** Odd: This eventCode occurs 3 times for a single cursor move. !!!
//		 print " eventCode=",eventCode," and keycode=",keycode,"and eventCode=",eventCode,"and cursor name=",csrname
		 
		if (cmpstr(csrname,"A") == 0)
			ExtractSpectrumFromPixel(SPHINXStack,"",PanelFolder,hcsr(A, StackWindow),vcsr(A, StackWindow),0)

//	print "cursor has been moved"
			
			NVAR gAutoTransfer		= $(PanelFolder + ":gAutoTransfer")
			if (gAutoTransfer)
				TransferCsrToAllImages(PanelName)
			endif
		
			NVAR gAutoSVD		= $(PanelFolder + ":gAutoSVD")
			WAVE energy 		= $(ParseFilePath(2,PanelFolder,":",0,0) + "energy")
			WAVE spectrum 	= $(ParseFilePath(2,PanelFolder,":",0,0) + "specplot")
			
			WAVE RefSpectra 	= $("root:SPHINX:SVD:ReferenceSpectra")
			WAVE Results 		= $("root:SPHINX:SVD:Results")
			
			AutoSVD=gAutoSVD
			if (!WaveExists(RefSpectra) || (DimSize(RefSpectra,0) == 0) || (!WaveExists(Results)))
				AutoSVD=0
			endif
			
			if (AutoSVD)
				SpectrumAnalysis(energy,spectrum,gAutoSVD,StackName)
			endif
			
			return 1
		endif
	endif
	
	// Adopt the pixel spectrum if the "E" key is pressed. 
	if ((keyCode == 101) || (keyCode == 69))
		ExtractSpectrumFromPixel(SPHINXStack,"",PanelFolder,hcsr(A, StackWindow),vcsr(A, StackWindow),1)
		ret = 1
	endif
	
	// Adopt the pixel spectra across the line if the "L" key is pressed. 
	if ((keyCode == 108) || (keyCode == 76))
	
		ProfileLineX[0] = trunc(hcsr(A, StackWindow))
		ProfileLineY[0] = trunc(vcsr(A, StackWindow))
		ProfileLineX[1] = trunc(hcsr(B, StackWindow))
		ProfileLineY[1] = trunc(vcsr(B, StackWindow))
	
		ExtractSpectraFromLine(SPHINXStack,ProfileLineX,ProfileLineY,PanelFolder,gSkipped)
		ret = 1
	endif
	
	// Extract the ROI spectrum if the "r" key is pressed. 
	// Extract and adopt the ROI spectrum if the "R" key is pressed. 
	// Extract all pixel spectra in the ROI is option-shift-r is pressed
	if ((keyCode == 114) || (keyCode == 82))
		if (CommandDown)
			ExtractSpectraFromROI(SPHINXStack,PanelFolder)
		else
			AdoptFlag =  (ShiftDown) ? 1 : 0
			ExtractSpectrumFromROI(SPHINXStack,PanelFolder,AdoptFlag)
		endif
		ret = 1
	endif
	
	return ret
End

Function ExtractSpectraFromLine(SPHINXStack,ProfileLineX,ProfileLineY,PanelFolder,Skipped)
	Wave SPHINXStack,ProfileLineX,ProfileLineY
	String PanelFolder
	Variable Skipped
	
	String StackName 		= NameOfWave(SPHINXStack)
	String PanelName 		= "Stack"+ParseFilePath(0,PanelFolder,":",1,0)
	String StackWindow		= PanelName +"#StackImage"
	String StackFolder		=  GetWavesDataFolder(SPHINXStack,1)
	
	MakeVariableIfNeeded(StackFolder+"g"+StackName+"_lineNum",0)
	NVAR gLineNumber 	= $(StackFolder+"g"+StackName+"_lineNum")
	gLineNumber += 1
	
	String SpectrumSuffix	= "_L" + num2str(gLineNumber)
	
	// Draw the new line
	SetDrawLayer /W=$PanelName UserFront
	SetDrawEnv /W=$PanelName linefgc= (65535,0,52428), linethick=2
	DrawLine /W=$PanelName 250,250,260,260
	
	SetDrawLayer /W=$StackWindow UserFront
	SetDrawEnv /W=$StackWindow linefgc= (65535,0,52428), linethick=2
	DrawLine /W=$StackWindow 250,250,260,260
	
	ImageLineProfile srcWave=SPHINXStack, xWave=ProfileLineX, yWave=ProfileLineY
	WAVE LineX = W_LineProfileX
	WAVE LineY = W_LineProfileY
	
	Variable i, Success, npx = numpnts(LineX)
	
	for (i=0;i<npx;i+=Skipped)
		Success = ExtractSpectrumFromPixel(SPHINXStack,SpectrumSuffix,PanelFolder,LineX[i],LineY[i],1)
		if (Success == 0)
			return 0
		endif
	endfor
End

// **** IMPORTANT NOTE about BINNING. 
// 			In this routine, the binning is performed symmetrically about the central pixel
// 			In mapping and ROI extraction routines, the binning is performed 'forward' from the chosen pixel. 
Function ExtractSpectrumFromPixel(SPHINXStack,SpectrumSuffix,PanelFolder,CsrX,CsrY,AdoptFlag)
	Wave SPHINXStack
	String SpectrumSuffix, PanelFolder
	Variable CsrX,CsrY, AdoptFlag
	
	if ((numtype(CsrX) == 2) || (numtype(CsrY) == 2))
		return 0
	endif
	
	String StackName 		= NameOfWave(SPHINXStack)
	String PanelName 		= "Stack"+ParseFilePath(0,PanelFolder,":",1,0)
	String SpectraWindow 	= PanelName +"#PixelPlot"
	String StackFolder		=  GetWavesDataFolder(SPHINXStack,1)
		
	NVAR gCursorBin			= $(PanelFolder+":gCursorBin")
	WAVE spectrum 			= $(PanelFolder + ":spectrum")
	
	Variable i, j, nm=0, BGMin, BGMax, Success, hBox = trunc(gCursorBin/2)
	String StackAxisName, StackFolderName, ExtractName, SpectrumName, SpectrumNote, CsrXStr, CsrYStr, FullPath
	
	spectrum 	= 0 	// Perhaps ImageTransform setBeam would be faster? 
	for (i=(CsrX-hBox);i<=(CsrX+hBox);i+=1)
		for (j=(CsrY-hBox);j<=(CsrY+hBox);j+=1)
			spectrum[] 	+= SPHINXStack[i][j][p]
			nm += 1
		endfor
	endfor
	
	spectrum /= nm
	
	 CsrXStr	= sprintbg(round(CsrX), 1)
	 CsrYStr 	= sprintbg(round(CsrY), 1)
	
	// Give the spectrum some information about where the data came from
	SpectrumNote 	= "Spectrum from "+num2str(gCursorBin)+"x"+num2str(gCursorBin)+ " pixel on "+StackName+"\r"
	SpectrumNote 	= SpectrumNote + "Pixel location = ("+CsrXStr+","+CsrYStr+")\r"
	SpectrumNote 	= SpectrumNote + ";X1="+num2str(CsrX-hBox)+";X2="+num2str(CsrX+hBox)+";Y1="+num2str(CsrY-hBox)+";Y2="+num2str(CsrY+hBox)+"\r"
	Note /K spectrum, SpectrumNote

	NormalizeExtractedSpectrum(PanelFolder)
	
	if (AdoptFlag == 1)		// Save the spectra ... 
		 
		SpectrumName 		= StackName + SpectrumSuffix + "_" + CsrXStr + "_" + CsrYStr
		StackAxisName 		= StackName + "_axis"
		
		FullPath = AdoptAxisAndDataFromMemory(StackAxisName,"null",StackFolder,"specplot","null",PanelFolder,SpectrumName,"",0,1,1)
		
		if (strlen(FullPath) == 0)
			return 0
		else
			// ... and record the pixel locations
			ExtractName 		= StackName + "_extract"
			WAVE ExtractPositions	= $(ParseFilePath(2,StackFolder,":",0,0) + ExtractName)
			ExtractPositions[CsrX][CsrY]	= 1
		endif
	endif
End

// This extracts the spectra from ALL the pixels within the ROI
// There is a potential to generate a huge number of spectra!
Function ExtractSpectraFromROI(SPHINXStack,PanelFolder)
	Wave SPHINXStack
	String PanelFolder
	
	String StackName 		= NameOfWave(SPHINXStack)
	String StackFolder		=  GetWavesDataFolder(SPHINXStack,1)

	String StackWindow = "StackBrowser#StackImage"
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	
	NVAR gBin				= $(PanelFolder+":gCursorBin")
	WAVE spectrum 		= $(PanelFolder + ":spectrum")
	
	String ROIName = StackFolder+StackName+"_av_roi"
	WAVE StackROI 	= $(ROIName)
	if (!WaveExists(StackROI))
		return 0
	endif
	
	// Calculate the number of pixels that are inside the ROI
	Duplicate /O StackROI, tempROI
	tempROI=1 
	tempROI[][] 	= (StackROI[p][q] == 1) ? 0 : 1
	WaveStats /Q/M=1 tempROI
	DoAlert 1,"ROI contains "+num2str(ceil(V_sum/gBin))+" pixels. Proceed?"
	if (V_flag==2)
		return 0
	endif

	MakeVariableIfNeeded(StackFolder+"g"+StackName+"_roiPixel",0)
	NVAR gROIPixelNum 	= $(StackFolder+"g"+StackName+"_roiPixel")
	gROIPixelNum += 1
	
	Variable i, j, iMin, iMax, jMin, jMax, NumX,NumY,NumE, GoodPixel, roiAvg
	String SpectrumName,StackAxisName, SpectrumNote=""
	
	NumX 	= DimSize(SPHINXStack,0)
	NumY 	= DimSize(SPHINXStack,1)
	NumE 	= DimSize(SPHINXStack,2)
	
	// Assumes that the bin size is ODD number
	Variable hBox = trunc(gBin/2), step=hBox+1
	
	// I think with these settings it is not possible to get our of array bounds
	for (i=hBox;i<(NumX-hBox);i+=step)
		for (j=hBox;j<(NumY-hBox);j+=step)
			
			iMin = i-hBox
			iMax = i+hBox
			jMin = j-hBox
			jMax = j+hBox
			
			if (gBin==1)
				GoodPixel 	= tempROI[i][j]
			else
				ImageStats/M=1/G={iMin,iMax,jMin,jMax} StackROI
				roiAvg 		= V_avg
				GoodPixel 	= (V_avg<1) ? 1 : 0
			endif
			
			if (GoodPixel)	// At least part of this binned area is inside the ROI
				
				// Extract the spectrum and transfer it to 'spectrum'
				ImageStats /M=1/BEAM/RECT={i,iMax,j,jMax} SPHINXStack
				WAVE W_ISBeamAvg=W_ISBeamAvg
				spectrum = W_ISBeamAvg
				
				// Give the spectrum some information about where the data came from
				SpectrumNote 	= "Spectrum extracted from "+num2str(gBin^2)+" pixel(s) from stack: "+StackName+"\r"
				if (gBin == 1)
					SpectrumNote 	= SpectrumNote + "Pixel location = ("+num2str(i)+","+num2str(j)+")\r"
				else
					SpectrumNote 	= SpectrumNote + "Binned pixel locations: X1="+num2str(i)+";X2="+num2str(i+gBin-1)+";Y1="+num2str(j)+";Y2="+num2str(j+gBin-1)+"\r"
				endif
				Note /K spectrum, SpectrumNote
			
				NormalizeExtractedSpectrum(PanelFolder)
				
				SpectrumName 		= StackName + "_RPx" + num2str(gROIPixelNum)
				StackAxisName 		= StackName + "_axis"
				gROIPixelNum += 1
			
				AdoptAxisAndDataFromMemory(StackAxisName,"null",StackFolder,"specplot","null",PanelFolder,SpectrumName,"RPx",0,1,1)
			endif
		endfor
	endfor
	
End

Function ExtractSpectrumFromROI(SPHINXStack,PanelFolder,AdoptFlag)
	Wave SPHINXStack
	String PanelFolder
	Variable AdoptFlag
	
	String StackName 		= NameOfWave(SPHINXStack)
	String StackFolder		=  GetWavesDataFolder(SPHINXStack,1)
	WAVE spectrum 		= $(PanelFolder + ":spectrum")
	
	String ROIName = StackFolder+StackName+"_av_roi"
	WAVE StackROI 	= $(ROIName)
	if (!WaveExists(StackROI))
		return 0
	endif
	
	Variable i, NumE
	String SpectrumName,StackAxisName, ExtractName, SpectrumNote=""
	
	NumE 	= DimSize(SPHINXStack,2)
	
	for (i=0;i<NumE;i+=1)
		ImageStats /M=1/R=StackROI/P=(i) SPHINXStack
		spectrum[i] = V_avg
	endfor
	
	// Give the spectrum some information about where the data came from
	SpectrumNote 	= "Spectrum from "+num2str(trunc(V_avg))+"-pixel ROI on "+StackName+"\r"
	Note /K spectrum, SpectrumNote
	
	NormalizeExtractedSpectrum(PanelFolder)
	
	if (AdoptFlag == 1)		// Save the spectra ... 
		
		MakeVariableIfNeeded(StackFolder+"g"+StackName+"_roiNum",0)
		NVAR gROINumber 	= $(StackFolder+"g"+StackName+"_roiNum")
		gROINumber += 1
		
		SpectrumName 		= StackName + "_ROI" + num2str(gROINumber)
		StackAxisName 		= StackName + "_axis"
	
		AdoptAxisAndDataFromMemory(StackAxisName,"null",StackFolder,"specplot","null",PanelFolder,SpectrumName,"",0,1,1)
		
		// Record the pixel locations
		ExtractName 		= StackName + "_extract"
		WAVE ExtractPositions	= $(ParseFilePath(2,StackFolder,":",0,0) + ExtractName)
		
		ImageAnalyzeParticles /Q/U/M=1 stats StackROI
		WAVE M_ParticlePerimeter = M_ParticlePerimeter
		
		ExtractPositions[][]		= (M_ParticlePerimeter[p][q] == 0) ? 1 : ExtractPositions[p][q]
		
		WAVE ROIExtract 	= $(StackFolder+StackName+"_extract")
		ROIExtract[][] 		= (ExtractPositions[p][q] == 0) ? ROIExtract[p][q] : 1
	endif
End

Function /S sprintbg(Value, MaxDP)
	Variable Value, MaxDP
	
	String ValStr

	sprintf ValStr, "%3."+num2str(MaxDP)+"f", Value
	
	Variable len=strlen(ValStr)
	Variable i = len-1
	
	do 
		if (cmpstr("0",ValStr[i]) == 0)
			ValStr 	= ValStr[0,i-1]
		else
			if (cmpstr(".",ValStr[i]) == 0)
				ValStr 	= ValStr[0,i-1]
			endif
		
			break
		endif
		
		i-=1
	while(1)
	
	return ReplaceString(".",ValStr,"p")
End

Function NormalizeExtractedSpectrum(PanelFolder)
	String PanelFolder
	
	WAVE energy 				= $(PanelFolder + ":energy")
	WAVE spectrum 			= $(PanelFolder + ":spectrum")
	WAVE specplot 				= $(PanelFolder + ":specplot")
	WAVE specbg 				= $(PanelFolder + ":specbg")
	WAVE specIo 				= $(PanelFolder + ":spectrumIo")

	NVAR gCursorBin			= $(PanelFolder+":gCursorBin")
	NVAR gLinBGFlag			= $(PanelFolder+":gLinBGFlag")
//	NVAR gInvertSpectraFlag	= $(PanelFolder+":gInvertSpectraFlag")
//	NVAR gReverseAxisFlag		= $(PanelFolder+":gReverseAxisFlag")
	
	// 2014-40-12 Added STXM vs PEEM normalization options
	NVAR gIoDivFlag			= $(PanelFolder+":gIoDivFlag")
	NVAR gIoODImax 			= $(PanelFolder+":gIoODImax")
	NVAR gIoDivChoice 			= $(PanelFolder+":gIoDivChoice")
	
	Variable BGMin, BGMax, IoDivChoice 		= gIoDivFlag + 1
	if (NVAR_Exists(gIoDivChoice))
		IoDivChoice 	= gIoDivChoice
	endif

	// Much better for this to happen in the calling routine! 
//	spectrum /= gCursorBin^2
	
	String SpecPlotNote = note(spectrum)
	SpecPlotNote = SpecPlotNote + "Normalization summary: "
	
//	if (gReverseAxisFlag)
//		Reverse spectrum
//		SpecPlotNote = SpecPlotNote + "ReverseAxis=1;"
//	endif
//	if (gInvertSpectraFlag == 1)
//		specplot *=	-1
//		SpecPlotNote = SpecPlotNote + "InvertSpectrum=1;"
//	endif
	
	specplot 	= spectrum
	
	if (IoDivChoice == 2)
		// Divide by the Izero - for PEEM
		specplot /= specIo
	elseif (IoDivChoice == 3)
		// Convert to OD using Izero - STXM
		specplot[] 	= -1 * ln(specplot[p]/specIo[p])
	elseif (IoDivChoice == 4)
		specplot[] 	= -1 * ln(specplot[p]/gIoODImax)
	endif
	
	if (gLinBGFlag == 1)
		GetEnergyRange(PanelFolder,"StackBrowser#PixelPlot",BGMin,BGMax)
		SubtractLinearBG(specplot,specbg,BGMin,BGMax)
		SpecPlotNote = SpecPlotNote + "LinearBG=1;"
	endif
	
	Note /K specplot, SpecPlotNote
End

//	if (gIoDivFlag)
//		specplot /= specIo
//		SpecPlotNote = SpecPlotNote + "Izero=1;"
//	endif
//	
	// *!*!*!   2014-04-12 - WTF - don't understand this -
//	if (gInvertSpectraFlag == 0)
//		specplot	= -1*spectrum
//	else
//		SpecPlotNote = SpecPlotNote + "InvertSpectrum=1;"
//	endif

Function GetEnergyRange(PanelFolder,SpectraWindow,BGMin,BGMax)
	String PanelFolder, SpectraWindow
	Variable &BGMin, &BGMax

	NVAR gCursorEMin 			= $(PanelFolder+":gCursorEMin")
	NVAR gCursorEMax 			= $(PanelFolder+":gCursorEMax")
	
	if (CsrIsOnPlot(SpectraWindow,"A") && CsrIsOnPlot(SpectraWindow,"B"))
		BGMin 	= min(pcsr(A, SpectraWindow),pcsr(B, SpectraWindow))
		BGMax 	= max(pcsr(A, SpectraWindow),pcsr(B, SpectraWindow))
	else
		print "does this ever happen now?"
		BGMin 	= gCursorEMin
		BGMax 	= gCursorEMax
	endif
End

Function SubtractLinearBG(spectrum,specbg,bgmin,bgmax)
	Wave spectrum, specbg
	Variable bgmin,bgmax
	
	if (bgmin != bgmax)
		CurveFit /Q/W=0/N line, spectrum[bgmin,bgmax] /D=specbg
		
		WAVE W_coef = W_coef
		specbg = W_coef[0] + w_coef[1]*p
		
		spectrum -= specbg
	endif
End

// *************************************************************
// ****		New Stack with energy shifts based on LLS fits - EXPERIMENTAL CODE NEVER USED
// *************************************************************
	
//Function ApplyLLSECorrection()
//
//	MakeStringIfNeeded("root:SPHINX:Browser:gStackName","")
//	SVAR gStackName 	= root:SPHINX:Browser:gStackName
//	gStackName = ChooseStack("Choose stack to apply energy shift",gStackName,0)
//	
//	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
//	WAVE SPHINXdE		= $("root:SPHINX:Stacks:"+gStackName+"_Map_dE")
//	
//	Variable i, j, NumX, NumY, NumE, NumXdE, NumYdE, offset
//	
//	if (!WaveExists(SPHINXdE))
//		Print " *** Please run the LLS routine to create a map of energy shifts"
//		return 0
//	endif
//	
//	NumX 	= DimSize(SPHINXStack,0)
//	NumY 	= DimSize(SPHINXStack,1)
//	NumE 	= DimSize(SPHINXStack,2)
//	NumXdE	= DimSize(SPHINXdE,0)
//	NumYdE	= DimSize(SPHINXdE,1)
//	
//	if ((NumX != NumXdE) || (NumY != NumYdE))
//		Print " *** Stack and energy shift map are not the same size"
//		return 0
//	endif
//	
//	// Lookup the stack axis
//	String cStackName
//	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
//	WAVE PAxis 			= $(ParseFilePAth(2,StackFolder,":",0,0) + gStackName + "_axis")
//	
//	if (!WaveExists(root:SPHINX:Stacks:S6_c))
//		// Create a new stack to contain the corrected energy values ...
//		cStackName = ModifiedStackName(gStackName,"c")
//		Make /O/B/U/N=(NumX,NumY,NumE) $(ParseFilePath(2,StackFolder,":",0,0)+cStackName) /WAVE=cStack
//		Duplicate /O/D PAxis, $(ParseFilePath(2,StackFolder,":",0,0)+cStackName+"_axis") /WAVE=cAxis
//	else
//		WAVE cStack = root:SPHINX:Stacks:S6_c
//		cStackName = "S6_c"
//		Duplicate /O/D PAxis, $(ParseFilePath(2,StackFolder,":",0,0)+cStackName+"_axis") /WAVE=cAxis
//	endif
//	
//	Variable Duration, timeRef 	= startMSTimer
//	
//	OpenProcBar("Correcting the energy axes for "+gStackName)
//	for (i=0;i<NumX;i+=1)
//		for (j=0;j<NumY;j+=1)
//			offset = SPHINXdE[i][j]
//			
//			if ((NumType(offset) == 0) && (abs(offset) > 0.001))
//				cStack[i][j][] 	= round(SPHINXStack[i][j][BinarySearchInterp(PAxis,PAxis[r]+offset)])
//			else
//				cStack[i][j][] 	= NAN
//			endif
//			
//		endfor
//		UpdateProcessBar(i/NumX)
//	endfor
//	
//	CloseProcessBar()
//	
//	Duration = stopMSTimer(timeRef)/1000000
//	Print " 		.............. took  ", Duration,"  seconds for ",NumX*NumY,"pixels. "
//End




























































// This is a more general slow routine for EXPORTING from the Browser cursors. 
//Function TransferImageCsrs(B_Struct)
//	STRUCT WMButtonAction &B_Struct
//	
//	String ctrlName 	= B_Struct.ctrlName
//	String WindowName = B_Struct.win
//	
//	Variable eventCode 	= B_Struct.eventCode
//	if (eventCode != 2)
//		return 0	// Mouse up after pressing
//	endif
//	
//	String PanelNameList = ImagePanelList("StackImage") 			// Window Names
//	String PanelTitleList = WinNamesToWinTitles(PanelNameList)	// Window Titles
//	String PanelTitle
//	Prompt PanelTitle, "Destination", popup, PanelTitleList
//	DoPrompt "Transfering cursor locations", PanelTitle
//	if (V_flag)
//		return 0
//	endif
//	
//	Variable PanelNum 	= WhichListItem(PanelTitle,PanelTitleList)
//	String PanelName 	= StringFromList(PanelNum,PanelNameList)
//	
//	String CsrWindow 	= WindowName+"#StackImage"
//	String DestWindow 	= PanelName+"#StackImage"
//	
//	TransferCsr("A",CsrWindow,DestWindow)
//	TransferCsr("B",CsrWindow,DestWindow)
//End

//Function RealLoadStackAxis(SPHINXStack)
//	Wave SPHINXStack
//	
//	String SPHINXFolder 	= "root:SPHINX:"
////	NVAR gReverseAxisFlag	= $(SPHINXFolder+"gReverseAxisFlag")
//	NVAR gReverseAxisFlag	= root:SPHINX:Browser:gReverseAxisFlag
//
//	Variable NumE 			= Dimsize(SPHINXStack,2)
//	String StackName 		= NameOfWave(SPHINXStack)
//	String StackAxisName	= StackName + "_axis"
//	String LoadWaveList 	= InteractiveLoadTextFile("Please locate the axis file")
//	
//	if (ItemsInList(LoadWaveList) > 0)
//		String AxisName		= StringFromList(0,LoadWaveList)
//		String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
//		
//		WAVE axis 	= $AxisName
//		
//		if (numpnts(axis) != NumE)
//			DoAlert 0, "Loaded axis does not have "+num2str(NumE)+" points! Aborting. "
//			KillWavesFromList(LoadWaveList,1)
//			return 0
//		endif
//		
//		if (gReverseAxisFlag == 1)
//			Reverse axis
//		endif
//		
//		Duplicate /O/D $AxisName, $(CheckFolderColon(StackFolder) + StackAxisName)
//		
//		// *!*!* Must update the plot energy axis in order to fitting to work properly. 
//		WAVE energy 	= root:SPHINX:Browser:energy
//		energy = axis
//		
//		KillWavesFromList(LoadWaveList,0)
//	endif
//End

//// Create a new contextual menu following Shift-Click within Stack marquee. 
//Function MarqueeMenu(s) 
//	STRUCT WMWinHookStruct &s 
//
//	String WindowName = s.winname
//	String PanelName 	= ParseFilePath(0, WindowName, "#", 0, 0)
//	String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
//	String StackWindow = PanelName+"#StackImage"
//	
//	GetWindow $PanelName activeSW 
//	if (cmpstr(S_value, StackWindow) != 0) 
//		return 0 
//	endif
//	
//	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
//	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
//	String StackFolder	= GetWavesDataFolder(avStack,1)
//	String StackName 	= ReplaceString("_av",StackAvg,"")
//	WAVE SPHINXStack	= $(StackFolder+StackName)
//	
//	Variable X1,X2,Y1,Y2,ret=0
//	
//	switch(s.eventcode)
//		case 3: 			// mousedown
//			GetMarquee/Z left, bottom
//			
//			if ((V_Flag ) && (GetKeyState(0) & 4))
//				// I.e., we only get here if (i) click occurs inside marque and (ii) SHIFT is held down. 
//				Variable xpix= s.mouseLoc.h
//				Variable ypix= s.mouseLoc.v
//				
//				String checked= "\\M0:!" + num2char(18)+":"
//				String divider="\\M1-;"
//				
//				PopupContextualMenu/C=(xpix, ypix) "ROI = marquee;ROI = displayed;"+divider+"PCA on marquee;"
//				
//				strswitch(S_selection)
//					case "ROI = marquee":
//						X1 = max(V_left,0)
//						X2 = min(V_right,DimSize(SPHINXStack,0))
//						
//						Y1 = max(V_bottom,0)
//						Y2 = min(V_top,DimSize(SPHINXStack,1))
//						
//						DefineSVDROI(WindowName,StackName,StackFolder,X1,X2,Y1,Y2)
//						break;
//					case "ROI = displayed":
//						GetAxis /Q/W=$WindowName bottom
//						X1 = max(V_min,0)
//						X2 = min(V_max,DimSize(SPHINXStack,0))
//						
//						GetAxis /Q/W=$WindowName left
//						Y1 = max(V_min,0)
//						Y2 = min(V_max,DimSize(SPHINXStack,1))
//						
//						DefineSVDROI(WindowName,StackName,StackFolder,X1,X2,Y1,Y2)
//						break;
//					case "maybe":
//						break;
//				endswitch
//				ret= 1	// skip the standard marquee menu
//			endif
//			break
//	endswitch
//	
//	return ret
//End