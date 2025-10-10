// Updated 07.21.2015 19:51
#pragma rtGlobals=1		// Use modern global access method.


Function AnalyzePixel()

	SetDataFolder root:POLARIZATION:Analysis
	ExtractPixelPolarizations()
	FitCosSq()

	//Ross globals
	NVAR Bmax 			= root:POLARIZATION:Analysis:MaxBValue
	Variable Amax = 100
	
	NVAR PixelAX			= $("root:SPHINX:Browser:gCursorAX")
	NVAR PixelAY			= $("root:SPHINX:Browser:gCursorAY")
	NVAR chisq				= $("root:POLARIZATION:Analysis:chisq")
	Wave FitCoef			= $("root:POLARIZATION:Analysis:W_coef")
	
	NVAR MaxPolAngle 	= $("root:POLARIZATION:Analysis:MaxPolAngle")
	NVAR MaxPolAngleZY 	= $("root:POLARIZATION:Analysis:MaxPolAngleZY")
	NVAR A 					= $("root:POLARIZATION:Analysis:A")
	NVAR B 					= $("root:POLARIZATION:Analysis:B")
	
	NVAR gBmax 		= root:POLARIZATION:gBmax
	
	// These are the results of the fitting
	Variable PhiZY, Rpol
	PhiZY 	= MaxPolAngleZY
	Rpol 	= B/Bmax
	
	// This seems correct! For (425,617) on H179A
	Variable PhiPol, PhiSP, ThetSP
	if (PhiZY > 90)
		PhiPol 	= 180-PhiZY
		PhiSP 		= acos( Rpol * cos( (pi/180) * PhiPol) )
		ThetSP 	= atan( -1 * Rpol * sin( (pi/180) * PhiPol) )
	else
		PhiPol 	= PhiZY
		PhiSP 		= acos( Rpol * cos( (pi/180) * PhiPol))
		ThetSP 	= atan( Rpol * sin( (pi/180) * PhiPol) )
	endif
	
	// The pixel coordinates and the results of fitting
	String ResultsText = "X:\t"+num2str(PixelAX)+"\rY:\t"+num2str(PixelAY)+"\r\rf(x)=a + b cos\S2\M(x - c')\rChiSq:\t"+num2str(chisq)+"\r\ra:\t\t"+num2str(A)+"\rb:\t\t"+num2str(B)+"\rc':\t\t"+num2str(MaxPolAngle)+"\rphiZY:\t\t"+num2str(MaxPolAngleZY)+"\rd:\t\t"+num2str(B/A)
	
	// The calculation of the c-axis vector angles
	ResultsText = ResultsText +"\r\rwith Bmax:\t"+num2str(Bmax)+"\rRpol:\t\t"+num2str(Rpol)+"\rPhiPol:\t\t"+num2str(PhiPol)
	ResultsText = ResultsText +"\rPolar Phi:\t"+num2str((180/pi)*PhiSP) +"\rAzimuthal Theta:\t"+num2str((180/pi)*ThetSP) +"\r"
	
	// The calculation of the c-axis vector angles using A-normalization
	Amax 	= 170
	Rpol 	= (  (Amax/A)*B  )/Bmax
	if (Rpol > 1)
		print "The value of Amax",Amax,"is too high!" 
		Rpol=1
	endif
	
	if (PhiZY > 90)
		PhiPol 	= 180-PhiZY
		PhiSP 		= acos( Rpol * cos( (pi/180) * PhiPol) )
		ThetSP 	= atan( -1 * Rpol * sin( (pi/180) * PhiPol) )
	else
		PhiPol 	= PhiZY
		PhiSP 		= acos( Rpol * cos( (pi/180) * PhiPol))
		ThetSP 	= atan( Rpol * sin( (pi/180) * PhiPol) )
	endif
	ResultsText = ResultsText +"\r\rwith Amax:\t"+num2str(Amax)+"\rRpol:\t\t"+num2str(Rpol)+"\rPhiPol:\t\t"+num2str(PhiPol)
	ResultsText = ResultsText +"\rPolar Phi:\t"+num2str((180/pi)*PhiSP) +"\rAzimuthal Theta:\t"+num2str((180/pi)*ThetSP) +"\r"


	TextBox /W=PolarizationAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	SetActiveSubwindow PolarizationAnalysis

End




Function DisplayPolarizationPanel()

	NewDataFolder /O root:POLARIZATION

	// Bad way of preventing errors, but if somebody tries to display the Polarization Panel before
	// the Stack Browser has been initialized, they'll receive an error that will crash all macros.
	// If I could verify the existance of the SPHINX folders, gStackName would presumably not be null
	// and this would be unnecessary. For now... Workaround.
	InitializeStackBrowser()
	//Also, we need the SVD data folder to exist in order to get ROI information... So...
	NewDataFolder /O root:SPHINX:SVD

	// Associate Polarization Panel with the desired Stack
	MakeStringIfNeeded("root:SPHINX:Browser:gStackName","")
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	gStackName 	= ChooseStack(" Choose a stack to analyze polarization",gStackName,0)
	
	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1)
		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)
		Variable NumE = Dimsize(SPHINXStack,2)

		MakeStringIfNeeded("root:POLARIZATION:StackName","")
		SVAR StackName 	= root:POLARIZATION:StackName
		StackName = gStackName

		Duplicate /O root:SPHINX:Browser:energy, root:POLARIZATION:angles
		WAVE /D POLAngles = root:POLARIZATION:angles
		WaveStats /Q POLAngles
		POLAngles -= V_min + (V_max-V_min-90)
		Reverse POLAngles
		WaveStats /Q POLAngles
			// Store min and max angles for use in Cos-SQ Fitting
			MakeVariableIfNeeded("root:POLARIZATION:maxAngle",0)
			MakeVariableIfNeeded("root:POLARIZATION:minAngle",0)
			NVAR maxAngle = $("root:POLARIZATION:maxAngle")
			NVAR minAngle = $("root:POLARIZATION:minAngle")
			maxAngle = V_max
			minAngle = V_min

//		PolarizationAnalysisPanel(SPHINXStack,"Polarization Analysis: "+gStackName,"Analysis",NumX,NumY,NumE)
		PolarizationAnalysisPanel(SPHINXStack,"Polarization Panel: "+gStackName,"Analysis",NumX,NumY,NumE)
	endif

End

Function PolarizationAnalysisPanel(SPHINXStack,Title,Folder,NumX,NumY,NumE)
	Wave SPHINXStack
	String Title,Folder
	Variable NumX, NumY, NumE
	
	// Locations of panel globals
	String PanelFolder 	= "root:POLARIZATION:"+Folder
	String PanelName 	= "Polarization"+Folder
	
	NewDataFolder /O/S $PanelFolder
	Make /O/D/N=(NumE) spectrum,fit_spectrum
	Make /O/D/N=3 root:POLARIZATION:NumData
	Wave NumData = $("root:POLARIZATION:NumData")
	NumData[0] = NumX
	NumData[1] = NumY
	NumData[2] = NumE

	
	DoWindow /K $PanelName
	NewPanel /K=1/W=(670,50,970,555) as Title
	Dowindow /C $PanelName
	CheckWindowPosition(PanelName,670,50,970,555)

	// Create the Plot of Extracted Spectra
	Display/W=(0,335,300,505)/HOST=# spectrum vs root:POLARIZATION:angles
	AppendToGraph fit_spectrum
	ModifyGraph rgb(fit_spectrum)=(0,0,65535)
	RenameWindow #, PixelPlot
	SetActiveSubwindow ##
	Display/W=(150,0,300,309)/HOST=#
	RenameWindow #, PixelData
	// Populate an initial single pixel plot
	AnalyzePixel()
	
	// Group Box and Buttons
	GroupBox PolAnalyzeGroup,pos={5,3},size={120,72}, title="Pol Analysis",fColor=(39321,1,1)
	Button AnalyzePixel,pos={15,17}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Analyze Pixel"
	Button AnalyzeROI,pos={15,35}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Analyze ROI as 1"
	Button AnalyzeStack,pos={15,53}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Analyze ROI"

	GroupBox ScalingGroup,pos={5,74},size={120,74}, title="Scale Analysis",fColor=(39321,1,1)
	Button ScaleAnalysis,pos={15,88}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Scale Output"
	MakeVariableIfNeeded(PanelFolder+":scaleSetPoint",0)
	SetVariable ImageScaleSetPoint,title="SetPt",pos={15,107},limits={-90,90,5},size={100,20},fsize=13,value=$(PanelFolder+":scaleSetPoint")
	Button AnalyzePolOutput,pos={15,127}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Analyze Output"

	GroupBox IzeroGroup,pos={5,148},size={120,50}, title="Izero",fColor=(39321,1,1)
	Button LoadI0,pos={15,162}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Load Izero"
	MakeVariableIfNeeded("NormToI0",0)
	CheckBox normToI0checkbox,title="Norm to Izero",pos={15,182},fsize=11,variable=$(PanelFolder+":NormToI0"), disable=2

	GroupBox RGBGroup,pos={5,198},size={140,37}, title="RGB",fColor=(39321,1,1)
	Button HSLtoRGB,pos={15,213}, size={60,19},fSize=10,proc=PolarizationPanelButtons,title="Make RGB"
	MakeVariableIfNeeded(PanelFolder+":HSLtoRGB_level",0)
	SetVariable HSLtoRGB_level,title="B/W",pos={76,213},limits={0,1,5},size={60,18},fsize=13,value=$(PanelFolder+":HSLtoRGB_level")

	Button ClearROIs,pos={5,308}, size={80,19},fSize=10,proc=PolarizationPanelButtons,title="Clear ROIs"

	if (exists("root:POLARIZATION:Analysis:I0") == 1)
		CheckBox normToI0checkbox,disable=0
	endif

	MakeVariableIfNeeded("autoSave",0)
	CheckBox autoSaveCheckbox,title="Auto Save",pos={5,240},fsize=11,variable=$(PanelFolder+":autoSave")
	MakeVariableIfNeeded("root:SPHINX:SVD:gROIMappingFlag",0)	// Use existing ROI mask
	CheckBox SVDROICheck,pos={5,257},size={114,17},title="use pink ROI",fSize=11,proc=PolRefROICheckProcs
	MakeVariableIfNeeded("useImageMask",0)
	CheckBox useImageMaskCheckbox,title="use image mask",pos={5,274},fsize=11,variable=$(PanelFolder+":useImageMask")
	MakeVariableIfNeeded("multithread",0)
	CheckBox mulithreadCheckbox,title="Multi-Threading",pos={5,291},disable=2,fsize=11,variable=$(PanelFolder+":multithread")
End

Function PolResultAnalysisPanel()

	// Locations of panel globals
	String PanelFolder	= "root:POLARIZATION:Analysis"
	String PanelName	= "PolResultAnalysis"
	String Title		= "Polarization Result Analysis"

	// check for use of old name POL_Analysis, and update to POL_Cprime
	if (!WaveExists($("root:SPHINX:Stacks:POL_Cprime")) && exists("root:SPHINX:Stacks:POL_Analysis") != 0)
		Wave /D POL_Analysis = $("root:SPHINX:Stacks:POL_Analysis")
		Wave /D POL_C = $("root:SPHINX:Stacks:POL_Cprime")
		Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $("root:SPHINX:Stacks:POL_Cprime") /WAVE=POL_C
		Duplicate /O POL_Analysis, POL_C
		KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
	endif

	if (exists("root:SPHINX:Stacks:POL_Cprime") == 0)
		Print " *** You must analyze an ROI first!"
		return 0
	endif

	Wave NumData = $("root:POLARIZATION:NumData")
	Make /O/D/N=(361,2)		root:POLARIZATION:Analysis:rowIntensityMap

	DoWindow /K $PanelName
	NewPanel /K=1/W=(985,50,1285,607) as Title
	Dowindow /C $PanelName
	CheckWindowPosition(PanelName,985,50,1285,607)

	PolResultExtractRow()

	// Create the Plot of Extracted Spectra
	Display/W=(0,387,300,557)/HOST=# rowIntensityMap
	SetAxis bottom,-90,90
	RenameWindow #, PixelPlot
	SetActiveSubwindow PolResultAnalysis#PixelPlot

		// Place cursors on the plot for angle range determination
		MakeVariableIfNeeded(PanelFolder+":gCursorP1",-50)
		MakeVariableIfNeeded(PanelFolder+":gCursorP2",50)
		NVAR gCursorP1 	= $(PanelFolder+":gCursorP1")
		NVAR gCursorP2 	= $(PanelFolder+":gCursorP2")

		// Cursors for range determination - DARK BLUE
		Cursor /C=(0,0,65535)/F/S=2/H=2/W=# A rowIntensityMap gCursorP1, 0
		// Cursors for range determination - MAGENTA
		Cursor /C=(65535,0,52428)/F/S=2/H=2/W=# B rowIntensityMap gCursorP2, 0

	SetActiveSubwindow ##
	Display/W=(150,0,300,80)/HOST=#
	RenameWindow #, PixelData

	SetWindow PolResultAnalysis, hook(VerticalCursorsHook)=VCsrHook

	GroupBox NoiseReductionGroup,pos={10,5},size={120,134}, title="Noise Reduction",fColor=(39321,1,1)
		Button EnhancePIC,pos={20,20}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Enhance PICmap"
		MakeVariableIfNeeded("enhancePolAnalysis",0)
		CheckBox enhanceCheckbox,title="Use Enhanced",pos={20,40},fsize=12,variable=$(PanelFolder+":enhancePolAnalysis"), disable=2
		MakeVariableIfNeeded(PanelFolder+":GaussBlurPixels",3)
		SetVariable GaussBlurPixels,title="Gauss Px",pos={20,56},limits={3,50,1},size={100,20},fsize=13,value=$(PanelFolder+":GaussBlurPixels")
		MakeVariableIfNeeded(PanelFolder+":GaussBlurPasses",1)
		SetVariable GaussBlurPasses,title="Passes",pos={20,76},limits={1,20,1},size={100,20},fsize=13,value=$(PanelFolder+":GaussBlurPasses")
		Button GaussBlur,pos={20,100}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Gaussian Blur"
		MakeVariableIfNeeded("gaussPolAnalysis",0)
		CheckBox gaussCheckbox,title="Use Gauss Blur",pos={20,120},fsize=12,variable=$(PanelFolder+":gaussPolAnalysis"), disable=2

//	GroupBox MaskGroup,pos={10,140},size={140,205}, title="Masking",fColor=(39321,1,1)
	GroupBox MaskGroup,pos={10,140},size={140,239}, title="Masking",fColor=(39321,1,1)
		GroupBox excludeGroup,pos={15,155},size={130,89}, title="Exclude Levels",fColor=(39321,1,1)
			Button imageMask,pos={20,170}, size={120,19},fSize=12,proc=PolarizationPanelButtons,title="Select Single Image"
			MakeVariableIfNeeded("imageMask",0)
			CheckBox imageMaskCheckbox,title="From Single Image",pos={20,190},fsize=12,variable=$(PanelFolder+":imageMask"), disable=2
			MakeVariableIfNeeded("polBMask",1)
			CheckBox polBMaskCheckbox,title="From POL B",pos={20,210},fsize=12,variable=$(PanelFolder+":polBMask")
//			MakeVariableIfNeeded("averageMask",1)
			MakeVariableIfNeeded("averageMask",0)
//			CheckBox averageMaskCheckbox,title="From Avg Image",pos={20,210},fsize=12,variable=$(PanelFolder+":averageMask")
			CheckBox averageMaskCheckbox,title="From Avg Image",pos={20,227},fsize=12,variable=$(PanelFolder+":averageMask")
		GroupBox IgnoreGroup,pos={15,247},size={130,72}, title="Exclude Masked Pixels",fColor=(39321,1,1)
			Button ignoreMask,pos={20,262}, size={120,19},fSize=12,proc=PolarizationPanelButtons,title="Add to Mask"
			MakeVariableIfNeeded("ignoreMask",0)
			CheckBox ignoreROIcheckbox,title="Use Mask",pos={20,282},fsize=12,variable=$(PanelFolder+":ignoreMask"), disable=2
			Button clearIgnoreMask,pos={80,297}, size={60,19},fSize=12,proc=PolarizationPanelButtons,title="clear"
			MakeVariableIfNeeded("useMaskedPolAnalysis",0)
		Button createMask,pos={15,322}, size={130,19},fSize=11,proc=PolarizationPanelButtons,title="Create Masked PICmap"	
		CheckBox useMaskedCheckbox,title="Use Masked PICmap",pos={15,342},fsize=12,variable=$(PanelFolder+":useMaskedPolAnalysis"), disable=2
		Button extractMaskedAS,pos={15,359}, size={130,19},fSize=11,proc=PolarizationPanelButtons,title="Extract Masked AS"	

	SVAR StackName = root:POLARIZATION:StackName
	if (exists("root:SPHINX:Stacks:POL_Enhanced") == 1)
		CheckBox enhanceCheckbox,disable=0
	endif
	if (exists("root:SPHINX:Stacks:POL_Gauss") == 1)
		CheckBox gaussCheckbox,disable=0
	endif
	if (exists("root:SPHINX:Stacks:POL_Masked") == 1)
		CheckBox useMaskedCheckbox,disable=0
	endif
	if (exists("root:SPHINX:Stacks:POL_Ignore_Mask") == 1)
		CheckBox ignoreROIcheckbox,disable=0
	endif
	if (exists("root:POLARIZATION:ImageMask_name") == 2)
		SVAR imageMaskName = root:POLARIZATION:ImageMask_name
		if (!StringMatch(imageMaskName,""))
			CheckBox imageMaskCheckbox,disable=0
			CheckBox imageMaskCheckbox,title=("From "+imageMaskName)
		endif
	endif

	GroupBox AnalysisGroup,pos={156,80},size={128,90}, title="Polarization Analysis",fColor=(39321,1,1)
		Button CollectAnalysis,pos={157,94}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Collect Angle Map"
		Button SaveAnalysis,pos={157,112}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Save Cursors to Table"
		Button StdDevAnalysis,pos={157,130}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Linear StdDev Analysis"
		Button CircDispAnalysis,pos={157,148}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Circular StdDev Analysis"

	GroupBox AnalysisSettingsGroup,pos={160,172},size={120,50}, title="Settings",fColor=(39321,1,1)
		MakeVariableIfNeeded(PanelFolder+":scaleSetPoint",0)
		SetVariable ImageScaleSetPoint,title="SetPt",pos={170,186},limits={-90,90,5},size={100,20},fsize=13,value=$(PanelFolder+":scaleSetPoint")
		MakeVariableIfNeeded("anglePolAnalysis",0)
		CheckBox polAngleCheckBox,title="Angle Scan",pos={170,206},fsize=12,variable=$(PanelFolder+":anglePolAnalysis")

	GroupBox CropGroup,pos={156,224},size={128,72}, title="Cropping Tools",fColor=(39321,1,1)
//		Button makeSlices,pos={157,238}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Create Slices"
		Button makeSlices,pos={157,238}, size={76,19},fSize=10,proc=PolarizationPanelButtons,title="Create Slices"
		MakeVariableIfNeeded(PanelFolder+":numSlices",5)
		SetVariable NumSlices,title=" ",pos={235,238},limits={1,50,1},size={46,19},fSize=10,value=$(PanelFolder+":numSlices")
		Button collectSlices,pos={157,256}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Collect Slice AS"
		Button ExtractROI,pos={157,274}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Extract POL ROI"

	Button ExportBin,pos={157,298}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Export Binary"

	Button HSLtoRGBMask,pos={157,320}, size={126,19},fSize=10,proc=PolarizationPanelButtons,title="Create Masked RGB"

//	Button HSLtoRGB,pos={157,320}, size={60,19},fSize=10,proc=PolarizationPanelButtons,title="HSLtoRGB"
//	Button HSLtoRGB,pos={157,320}, size={60,19},fSize=10,proc=PolarizationPanelButtons,title="Make RGB"
//	MakeVariableIfNeeded(PanelFolder+":HSLtoRGB_level",50)
//		SetVariable HSLtoRGB_level,title="Level",pos={218,320},limits={0,100,5},size={80,20},fsize=13,value=$(PanelFolder+":HSLtoRGB_level")
//	MakeVariableIfNeeded(PanelFolder+":HSLtoRGB_level",0)
//		SetVariable HSLtoRGB_level,title="B/W",pos={218,320},limits={0,1,5},size={80,20},fsize=13,value=$(PanelFolder+":HSLtoRGB_level")

End

Function DisplayStackOperationPanel()

	String Title = "Stack Operations"
	String PanelName = "StackOperations"
	String PanelFolder = "root:POLARIZATION:StackOperations"

	NewDataFolder /O/S $PanelFolder

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,360,195) as Title
		Dowindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,360,195)

		GroupBox ROIGroup,pos={3,2},size={205,82}, title="ROI",fColor=(1,1,39321)
			Button SetROI,pos={5,18}, size={95,19},fSize=12,proc=PolarizationPanelButtons,title="Set ROI"
			Button CropStack,pos={110,18}, size={90,19},fSize=12,proc=PolarizationPanelButtons,title="Crop Stack"
			SetVariable SVDLeft,title="left",pos={5,38},limits={0,65535,1},size={95,20},fsize=13,value=$("root:SPHINX:SVD:gSVDLeft")
			SetVariable SVDRight,title="right",pos={110,38},limits={0,65535,1},size={90,20},fsize=13,value=$("root:SPHINX:SVD:gSVDRight")
			SetVariable SVDBottom,title="bottom",pos={5,60},limits={0,65535,1},size={95,20},fsize=13,value=$("root:SPHINX:SVD:gSVDBottom")
			SetVariable SVDTop,title="top",pos={110,60},limits={0,65535,1},size={90,20},fsize=13,value=$("root:SPHINX:SVD:gSVDTop")

//		Button TransferPinkROI,pos={215,18}, size={95,19},fSize=12,proc=PolarizationPanelButtons,title="Transfer Pink ROI"

		GroupBox RotationGroup,pos={3,90},size={205,57}, title="Rotation",fColor=(39321,1,1)
			Button RotateStack,pos={5,105}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Rotate Stack"
			Button CalculateRotation,pos={5,125}, size={100,19},fSize=12,proc=PolarizationPanelButtons,title="Calculate Angles"
			MakeVariableIfNeeded("root:POLARIZATION:Analysis:rotation_angle",0)
			SetVariable rotation_angle,title="Angle",pos={115,105},limits={-360,360,1},size={90,20},fsize=13,value=$("root:POLARIZATION:Analysis:rotation_angle")

End

Function SetROI()

	String WindowName = "StackBrowser#StackImage"
	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName

	NVAR X1 	= root:SPHINX:SVD:gSVDLeft
	NVAR X2 	= root:SPHINX:SVD:gSVDRight
	NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
	NVAR Y2 	= root:SPHINX:SVD:gSVDTop

	DefineSVDROI(WindowName, StackName, StackFolder, X1, X2, Y1, Y2)

End

Function CropStack()

	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	WAVE SPHINXStack = $(StackFolder+":"+StackName)

	//Get ROI Positions from SVD Folder
		NVAR X1 	= root:SPHINX:SVD:gSVDLeft
		NVAR X2 	= root:SPHINX:SVD:gSVDRight
		NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
		NVAR Y2 	= root:SPHINX:SVD:gSVDTop
		if (!NVAR_Exists(X1))
			Print " *** Please select an ROI"
			return 0
		endif

	Variable NumX = X2 - X1
	Variable NumY = Y2 - Y1
	Variable NumZ = DimSize(SPHINXStack, 2)

	WAVE /D StackCrop = $(StackFolder+":"+StackName+"_crp")
	Make /O/N=(NumX, NumY, NumZ)/D $(StackFolder+":"+StackName+"_crp") /WAVE=StackCrop

	StackCrop[][][] = SPHINXStack[p + NumX][q + NumY][r]

End

Function TransferPinkROI()

	print "transferring pink ROI..."

	Wave ROIX = $("root:SPHINX:Stacks:ROIX")
	Wave ROIY = $("root:SPHINX:Stacks:ROIY")

	if (WaveExists(ROIX) && WaveExists(ROIY))

		// get panels
		Variable dimX, dimY
		Variable i, NPanels
		String PanelName, PanelNameList
		String ImageName, ImageList
		String SubWinName, SubWinList

		dimX = DimSize(ROIX, 0)
		dimY = DimSize(ROIY, 0)

//		SetDrawLayer /W=$WindowName /K UserFront
//		SetDrawEnv /W=$WindowName linefgc= (65535,0,52428),fillpat= 0, xcoord=bottom, ycoord=left
//		DrawPoly /W=$WindowName ROIX[0], ROIY[0], 1, 1, ROIX, ROIY

//		PanelNameList = ImagePanelList("","StackImage","POL",0)
//		ImageList = ImagePanelList("","StackImage","POL",1)
//		NPanels = ItemsInList(PanelNameList)

//		for (i = 0; i < NPanels; i += 1)
//			PanelName = StringFromList(i,PanelNameList)
//			SubWinList 	= InclusiveWaveList(ChildWindowList(PanelName),"",";")
//			SubWinName 	= StringFromList(0,SubWinList)
//			ImageName = StringFromList(i,ImageList)

//			if (cmpstr("StackBrowser",PanelName) == 0)
//			elseif (cmpstr("ReferencePanel",PanelName) == 0)
//			elseif (cmpstr("BlankImage",ImageName) == 0)
//			else
//				print ImageName
//				for (j = 1; j < dimX; j += 1)
//					for (k = 1; k < dimY; k += 1)
//						SetDrawLayer /W=$SubWinName UserFront
//						SetDrawEnv /W=$SubWinName linefgc= (65535,0,52428),dash= 11,linethick= 2.00, xcoord=bottom, ycoord=left
//						DrawLine /W=$SubWinName j-1,k-1,j,k
//					endfor
//				endfor
//			endif
//		endfor

	else
		print "no pink ROI"
	endif
End

Function CopyPinkROI()

	String StackFolder = "root:SPHINX:Stacks"

	Wave ROIX = $(StackFolder + ":ROIX")
	Wave ROIY = $(StackFolder + ":ROIY")

	if (WaveExists(ROIX) && WaveExists(ROIY))
		Wave /D ROIX2 = $(StackFolder + ":ROIX2")
		Wave /D ROIY2 = $(StackFolder + ":ROIY2")
		if (!WaveExists(ROIX2))
			Make /O/N=(DimSize(ROIX, 0))/D $(StackFolder + ":ROIX2") /WAVE=ROIX2
		endif
		if (!WaveExists(ROIY2))
			Make /O/N=(DimSize(ROIY, 0))/D $(StackFolder + ":ROIY2") /WAVE=ROIY2
		endif

		Duplicate /O ROIX ROIX2
		Duplicate /O ROIY RIOY2
	else
		print "no pink ROI"
	endif

End

Function RotateStack()

	Variable i, j, k
	Variable x, y
	Variable w1, w2, w3, w4, W
	NVAR delta = $("root:POLARIZATION:Analysis:rotation_angle")
	Variable xShift, yShift

	String StackFolder = "root:SPHINX:Stacks"

	MakeStringIfNeeded("root:SPHINX:Browser:gStackName","")
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	gStackName 	= ChooseStack(" Choose a stack to rotate",gStackName,0)

	WAVE SPHINXStack	= $(StackFolder+":"+gStackName)
	if (!WaveExists(SPHINXStack))
		print "stack does not exist"
		return 0
	endif

	Variable NumX = DimSize(SPHINXStack, 0)
	Variable NumY = DimSize(SPHINXStack, 1)
	Variable NumZ = DimSize(SPHINXStack, 2)

	String suffix
	if (delta < 0)
		suffix = "m" + num2str(-delta)
	else
		suffix = num2str(delta)
	endif

	Variable NumX_rot = floor(2*NumX)
	Variable NumY_rot = floor(2*NumY)

	WAVE /D RotatedStack =	$(StackFolder+":"+gStackName+"_rot_" + suffix)
	Make /O/N=(NumX_rot, NumY_rot, NumZ)/D $(StackFolder+":"+gStackName+"_rot_" + suffix) /WAVE=RotatedStack

	Variable delta_pos = (delta >= 0) ? delta : delta + 360

	xShift = 0
	if (delta_pos >= 0 && delta_pos <= 90)
		xShift = NumX / 2 + delta_pos * NumX / 90						// shift right linearly from NumX / 2 at 0 to 3*NumX / 2 at delta = 90
	elseif (delta_pos > 90 && delta_pos <= 180)
		xShift = 7 * NumX / 4 - abs(135 - delta_pos) * (NumX / 4) / 45		// shift right linearly from 3*NumX / 2 at 90 to 7*NumX / 4 at 135 and back to 3*NumX / 2 at 180
	elseif (delta_pos > 180 && delta_pos <= 270)
		xShift = NumX / 2 + (270 - delta_pos) * NumX / 90				// shift right linearly from 3*NumX / 2 at 180 to NumX / 2 at 270
	elseif (delta_pos > 270 && delta_pos <= 360)
		xShift = NumX / 4 + abs(315 - delta_pos) * (NumX / 4) / 45			// shift right linearly from NumX / 2 at delta = 270 to NumX / 4 at 315 and back to NumX / 2 at 360
	endif

	yShift = 0
	if (delta_pos >= 0 && delta_pos <= 90)
		yShift = (NumY / 4) + abs(45 - delta_pos) * (NumY / 4) / 45		// shift up linearly from NumY/2 at 0 to NumY/4 at 45 and back up to NumY/2 at 90
	elseif (delta_pos > 90 && delta_pos <= 180)
		yShift  = NumY / 2 + (delta_pos - 90) * NumY / 90				// shift up linearly from NumY / 2 at 90 to 3*NumY / 2 at 180
	elseif (delta_pos > 180 && delta_pos <= 270)
		yShift = 7 * NumY / 4 - abs(235 - delta_pos) * (NumY / 4) / 45		// shift up linearly from 3*NumY / 2 at180 to 7*NumX / 4 at 225 and back to 3*NumY / 2 at 270
	elseif (delta_pos > 270 && delta_pos <= 360)
		yShift = NumY / 2 + (360 - delta_pos) * NumY / 90				// shift up linearly from 3*NumY / 2 at 270 to NumY / 2 at 360
	endif

	xShift = floor(xShift)
	yShift = floor(yShift)

	for (i = -xShift; i <= NumX_rot - xShift; i += 1)
		for (j = -yShift; j <= NumY_rot - yShift; j += 1)
			x = i * cos(pi * delta / 180) + j * sin(pi * delta / 180)
			y = -i * sin(pi * delta / 180) + j * cos(pi * delta / 180)

			w1 = (x - floor(x)) * (y - floor(y))
			w2 = (ceil(x) - x) * (y - floor(y))
			w3 = (x - floor(x)) * (ceil(y) - y)
			w4 = (ceil(x) - x) * (ceil(y) - y)

			if (x == floor(x))
				if (y == floor(y))
					w4 = 1
				else
					w2 = y - floor(y)
					w4 = ceil(y) - y
				endif
			elseif (y == floor(y))
				w3 = x - floor(x)
				w4 = ceil(x) - x
			endif

			W = w1 + w2 + w3 + w4
			for (k = 0; k < NumZ; k += 1)
				if (x < 0 || x > NumX || y < 0 || y > NumY)
					RotatedStack[i + xShift][j + yShift][k] = NaN
				else
					RotatedStack[i + xShift][j + yShift][k] = (1/W) * (w1 * SPHINXStack[floor(x)][floor(y)][k] + w2 * SPHINXStack[ceil(x)][floor(y)][k] + w3 * SPHINXStack[floor(x)][ceil(y)][k] + w4 * SPHINXStack[ceil(x)][ceil(y)][k])
				endif
			endfor
		endfor
	endfor

End

// BG: This appears to calculate the "Sample Centered" waves, C, "Theta"
Function CalculateRotation()

	String StackFolder = "root:SPHINX:Stacks"

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:rotation_angle", 0)
	NVAR delta = $("root:POLARIZATION:Analysis:rotation_angle")

	WAVE /D POL_C = $(StackFolder+":POL_Cprime")

	// check for use of old name POL_Analysis, and update to POL_Cprime
	if (!WaveExists(POL_C))
		Wave /D POL_Analysis = $("root:SPHINX:Stacks:POL_Analysis")
		if (!WaveExists(POL_Analysis))
			print "must first run analysis"
			return 0
		endif
		Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $("root:SPHINX:Stacks:POL_Cprime") /WAVE=POL_C
		Duplicate /O POL_Analysis, POL_C
		KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
	endif

	WAVE POL_Theta = $(StackFolder+":POL_Theta")
	WAVE POL_C_vat = $(StackFolder+":POL_C_vat")
	WAVE POL_Theta_vat = $(StackFolder+":POL_Theta_vat")

	if (!WaveExists(POL_C))
		print "must first run analysis"
		return 0	
	endif

	MakeThetaMap()

	Variable NumX = DimSize(POL_C, 0)
	Variable NumY = DimSize(POL_C, 1)
	Variable chi = 30
	Variable i,j

	// Assign waves
		WAVE /D POL_C_SampCen = $(StackFolder+":POL_C_SampCen")
		WAVE /D POL_Theta_SampCen = $(StackFolder+":POL_Theta_SampCen")
		WAVE /D POL_C_vat_SampCen = $(StackFolder+":POL_C_vat_SampCen")
		WAVE /D POL_Theta_vat_SampCen = $(StackFolder+":POL_Theta_vat_SampCen")
	// Make waves if needed
		if (!WaveExists(POL_C_SampCen))
			Make /O/N=(NumX,NumY)/D $(StackFolder+":POL_C_SampCen") /WAVE=POL_C_SampCen
			Make /O/N=(NumX,NumY)/D $(StackFolder+":POL_Theta_SampCen") /WAVE=POL_Theta_SampCen
			POL_C_SampCen = NaN
			POL_Theta_SampCen = NaN
		endif
		if (!WaveExists(POL_C_vat_SampCen))
			Make /O/N=(NumX,NumY)/D $(StackFolder+":POL_C_vat_SampCen") /WAVE=POL_C_vat_SampCen
			Make /O/N=(NumX,NumY)/D $(StackFolder+":POL_Theta_vat_SampCen") /WAVE=POL_Theta_vat_SampCen
			POL_C_vat_SampCen = NaN
			POL_Theta_vat_SampCen = NaN
		endif

		POL_C_SampCen[][] = (180/pi) * atan2(cos(pi * POL_Theta[p][q] / 180) * cos(pi * POL_C[p][q] / 180), cos(pi * POL_Theta[p][q] / 180) * sin(pi * POL_C[p][q] / 180) * sin(pi * chi / 180) + sin(pi * POL_Theta[p][q] / 180) * cos(pi * chi / 180)) - delta
		POL_Theta_SampCen[][] = (180/pi) * asin( -cos(pi * POL_Theta[p][q] / 180) * sin(pi * POL_C[p][q] / 180) * cos(pi * chi / 180) + sin(pi * POL_Theta[p][q] / 180) * sin(pi * chi / 180))

		POL_C_vat_SampCen[][] = (180/pi) * atan2(cos(pi * POL_Theta_vat[p][q] / 180) * cos(pi * POL_C_vat[p][q] / 180), cos(pi * POL_Theta_vat[p][q] / 180) * sin(pi * POL_C_vat[p][q] / 180) * sin(pi * chi / 180) + sin(pi * POL_Theta_vat[p][q] / 180) * cos(pi * chi / 180)) - delta
		POL_Theta_vat_SampCen[][] = (180/pi) * asin( -cos(pi * POL_Theta_vat[p][q] / 180) * sin(pi * POL_C_vat[p][q] / 180) * cos(pi * chi / 180) + sin(pi * POL_Theta_vat[p][q] / 180) * sin(pi * chi / 180))

		for (i = 0; i < NumX; i += 1)
			for (j = 0; j < NumY; j += 1)
				if (POL_C_SampCen[i][j] < -90)
					do
						POL_C_SampCen[i][j] = POL_C_SampCen[i][j] + 180
					while (POL_C_SampCen[i][j] < -90)
				endif
				if (POL_C_vat_SampCen[i][j] < -90)
					do
						POL_C_vat_SampCen[i][j] = POL_C_vat_SampCen[i][j] + 180
					while (POL_C_vat_SampCen[i][j] < -90)
				endif
			endfor
		endfor

End


// BG: This is the function that is called by the Analyze ROI as 1 button
Function AnalyzeROI()

	SetDataFolder root:POLARIZATION:Analysis

	Variable i,j,k,kft,keep,n,m,nm,V_chisq,V_max
	Variable A, B, C, D
	Variable A_vat, B_vat, C_vat, D_vat
	Variable C_SampCen, Theta_SampCen
	Variable C_vat_SampCen, Theta_vat_SampCen
	Variable Theta, Theta_vat
	Variable chi = 30

	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	WAVE spectrum 	= $(PanelFolder + ":spectrum")
	WAVE SPHINXStack = $(StackFolder+":"+StackName)
	Wave NumData = $("root:POLARIZATION:NumData")

	String PanelName = "StackBrowser"
	String StackWindow = PanelName+"#StackImage"
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	String AVStackFolder	= GetWavesDataFolder(avStack,1)

	NVAR gROIMapFlag 	= root:SPHINX:SVD:gROIMappingFlag
	Variable ROIFlag
	WAVE roiStack 		= $(AVStackFolder + StackName + "_av_roi")

	MakeVariableIfNeeded(PanelFolder+":useImageMask",0)
	NVAR useImageMask = $(PanelFolder+":useImageMask")

	MakeVariableIfNeeded(PanelFolder+":MaxDvalue",-10)
	MakeVariableIfNeeded(PanelFolder+":MinDvalue_vat",10)
	NVAR MaxDvalue = $(PanelFolder+":MaxDvalue")
	NVAR MinDvalue_vat = $(PanelFolder+":MinDvalue_vat")
	NVAR delta = $(PanelFolder+":rotation_angle")

	//Get ROI Positions from SVD Folder
		NVAR X1 	= root:SPHINX:SVD:gSVDLeft
		NVAR X2 	= root:SPHINX:SVD:gSVDRight
		NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
		NVAR Y2 	= root:SPHINX:SVD:gSVDTop
		if (!NVAR_Exists(X1))
			Print " *** Please select an ROI"
			return 0
		endif

	if (gROIMapFlag)
		ROIFlag 	= CheckROIMapping(roiStack,gROIMapFlag,X1,X2,Y1,Y2)
		if (ROIFlag==0)
			print " 		... Aborted the mapping routine due to pink ROI problem"
			return 0
		endif
	endif

	// Assign Results waves
		WAVE /D POLChiSq_ROI = $(StackFolder+":POL_ChiSq_polROI")

		WAVE /D POL_A_ROI = $(StackFolder+":POL_A_polROI")
		WAVE /D POL_B_ROI = $(StackFolder+":POL_B_polROI")
		WAVE /D POL_C_ROI = $(StackFolder+":POL_C_polROI")
		WAVE /D POL_D_ROI = $(StackFolder+":POL_D_polROI")

		WAVE /D POL_A_vat_ROI = $(StackFolder+":POL_A_vat_polROI")
		WAVE /D POL_B_vat_ROI = $(StackFolder+":POL_B_vat_polROI")
		WAVE /D POL_C_vat_ROI = $(StackFolder+":POL_C_vat_polROI")
		WAVE /D POL_D_vat_ROI = $(StackFolder+":POL_D_vat_polROI")

		WAVE /D POL_C_SampCen_ROI = $(StackFolder+":POL_C_SampCen_polROI")
		WAVE /D POL_Theta_SampCen_ROI = $(StackFolder+":POL_Theta_SampCen_polROI")

		WAVE /D POL_C_vat_SampCen_ROI = $(StackFolder+":POL_C_vat_SampCen_polROI")
		WAVE /D POL_Theta_vat_SampCen_ROI = $(StackFolder+":POL_Theta_vat_SampCen_polROI")

	// Make NEW Results Waves if needed
		if (!WaveExists(POL_A_ROI))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_A_polROI") /WAVE=POL_A_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_B_polROI") /WAVE=POL_B_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_C_polROI") /WAVE=POL_C_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_D_polROI") /WAVE=POL_D_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_ChiSq_polROI") /WAVE=POLChiSq_ROI
			POL_A_ROI = NaN
			POL_B_ROI = NaN
			POL_C_ROI = NaN
			POL_D_ROI = NaN
			POLChiSq_ROI = NaN
		endif
		if (!WaveExists(POL_A_vat_ROI))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_A_vat_polROI") /WAVE=POL_A_vat_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_B_vat_polROI") /WAVE=POL_B_vat_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_C_vat_polROI") /WAVE=POL_C_vat_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_D_vat_polROI") /WAVE=POL_D_vat_ROI
			POL_A_vat_ROI = NaN
			POL_B_vat_ROI = NaN
			POL_C_vat_ROI = NaN
			POL_D_vat_ROI = NaN
		endif
		if (!WaveExists(POL_C_SampCen_ROI))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_C_SampCen_polROI") /WAVE=POL_C_SampCen_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Theta_SampCen_polROI") /WAVE=POL_Theta_SampCen_ROI
			POL_C_SampCen_ROI = NaN
			POL_Theta_SampCen_ROI = NaN
		endif
		if (!WaveExists(POL_C_vat_SampCen_ROI))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_C_vat_SampCen_polROI")/WAVE=POL_C_vat_SampCen_ROI
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Theta_vat_SampCen_polROI") /WAVE=POL_Theta_vat_SampCen_ROI
			POL_C_vat_SampCen_ROI = NaN
			POL_Theta_vat_SampCen_ROI = NaN
		endif

	//Get angle range for finding peaks after fit
		NVAR maxAngle = $("root:POLARIZATION:maxAngle")
		NVAR minAngle = $("root:POLARIZATION:minAngle")
	
	// Normalization Settings
		NVAR gInvertSpectraFlag	= $(BrowserFolder+":gInvertSpectraFlag")
		Variable /G NormToI0
		if (NormToI0 == 1)
			WAVE I0 = root:POLARIZATION:Analysis:I0
		endif

	// Variable for storing current guesses
		Make/D/N=(3,2)/O W_coef
		// Make appropriate guesses, depending on data inversion, to hopefully avoid "Singular Matrix" errors and get better fits...
		if (gInvertSpectraFlag == 0)
			W_coef[][0] = {-140,50,1}
			W_coef[][1] = {-140,-50,-2}
		else
			W_coef[][0] = {140,-100,2}
			W_coef[][1] = {140,100,-5}
		endif

	Variable V_fitOptions=4		//Suppresses Curve Fit Window
	Variable V_FitError=0		//Block error reporting and capture error data

	createFitSpectrumShell()
	WAVE /D fit_spectrum_m = $("root:POLARIZATION:Analysis:fit_spectrum_m")

	//Select Single Image as Mask
	if (useImageMask == 1)
		String ImageFolder = "root:SPHINX:Stacks"
		MakeStringIfNeeded("root:POLARIZATION:ImageMask_name","")
		svar ImageName = root:POLARIZATION:ImageMask_name

		String tempImageName
		String ImageList = ReturnImageList(ImageFolder,0)
		Prompt tempImageName, "List of images", popup, ImageList
		DoPrompt "Please Select Image from List", tempImageName
		if (V_flag)
			return 0
		endif
		ImageName = tempImageName

		// If user has selected to use an ImageMask, create image mask
		if (exists("root:POLARIZATION:ImageMask_name") == 2)
			SVAR imageMaskName = root:POLARIZATION:ImageMask_name
			WAVE /D imageMask_image = $(StackFolder+":"+imageMaskName)

			NVAR gImageMin = $("root:SPHINX:"+imageMaskName+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+imageMaskName+":gImageMax")

//			MaskedPICmap[][] = (imageMask_image[p][q] < gImageMin) ? NaN : MaskedPICmap[p][q]
//			MaskedPICmap[][] = (imageMask_image[p][q] > gImageMax) ? NaN : MaskedPICmap[p][q]
		endif
	endif




	// Perform fit
		nm = 0
		spectrum = 0

		Variable numPixels = 0

		//EXTRACT SPECTRUM from ROI
			for (m = X1; m < X2; m+=1)
				for (n = Y1; n < Y2; n+=1)
					if (ROIFlag)	// use pink ROI
						if (useImageMask == 1)	// using image mask
							if ((roiStack[m][n] != 1) && (imageMask_image[m][n] > gImageMin) && (imageMask_image[m][n] < gImageMax))
								spectrum[] 	+= SPHINXStack[m][n][p]
								numPixels += 1
							endif
						else						// not using image mask
							if (roiStack[m][n] != 1)
								spectrum[] 	+= SPHINXStack[m][n][p]
								numPixels += 1
							endif
						endif
					else		// not using pink ROI
						if (useImageMask == 1)	// using image mask
							if ((imageMask_image[m][n] > gImageMin) && (imageMask_image[m][n] < gImageMax))
								spectrum[] 	+= SPHINXStack[m][n][p]
								numPixels += 1
							endif
						else						// not using image mask
							spectrum[] 	+= SPHINXStack[m][n][p]
						endif
					endif
					nm += 1
				endfor
			endfor

			//If extraction worked, continue
				if (nm > 0)
				// Normalize Extracted Spectra, per settings in Stack Browser
					if (gInvertSpectraFlag == 0)
						spectrum = -1*spectrum
					endif
					if (ROIFlag || (useImageMask == 1))
						spectrum /= numPixels
					else
						spectrum /= ((X2-X1)*(Y2-Y1))
					endif
					if (NormToI0 == 1)
						spectrum /= I0
					endif
				//PERFORM FIT FUNCTION FOR spectrum
					keep = 0 //Variable for exiting the FOR loop
					for (k = 0; k < 2; k += 1) //Allow iterations, if required, to improve Fit
						V_FitError=0	// Capture fit errors, and do not prompt user!
						FuncFit/NTHR=0/N/Q=1 cos_squared W_coef[][k]  spectrum /X=:::POLARIZATION:angles /D
						if (V_Chisq < 300)
							break // Break out of For loop - Good Fit.
						elseif (k == 0)
							kft = V_Chisq
							if (keep == 1)
								break // Break out of For loop - Best possible fit.
							endif
						elseif (k > 0)
							if (kft > V_Chisq)
								break // Break out of For loop - Best possible fit.
							else
								keep = 1
								k = -1 //Redo the first attempt
							endif
						endif
					endfor

					if (V_FitError == 0)
						fit_spectrum_m = W_coef[0][0]+W_coef[1][0]*cos((x)/180*pi-W_coef[2][0])^2
						WaveStats /Q /M=1 fit_spectrum_m

						C = V_maxloc
						A = V_min
						B = V_max-V_min
						D = (A == 0) ? NaN : B/A
					else
						C	= NaN
						A			= NaN
						B			= NaN
						D			= NaN
						V_Chisq		= NaN
						V_max		= NaN

						if (gInvertSpectraFlag == 0)
							W_coef[][0] = {-140,50,1}
							W_coef[][1] = {-140,-50,-2}
						else
							W_coef[][0] = {140,-100,2}
							W_coef[][1] = {140,100,-5}
						endif
					endif

				else
					C	= NaN
					A			= NaN
					B			= NaN
					D			= NaN
					V_Chisq		= NaN
					V_max		= NaN
				endif

	C_vat = C + 90
	C_vat = (C_vat > 90) ? (C_vat - 180) : C_vat

	A_vat = A + B
	B_vat = -B
	D_vat = B_vat / A_vat
	
	print "MaxDvalue is",MaxDvalue,"and D is",D
	Theta = acos(sqrt(D/MaxDvalue)) * 180 / PI
	Theta_vat = acos(sqrt(D_vat/MinDvalue_vat)) * 180 / PI


	C_SampCen = (180/pi) * atan2(cos(pi * Theta / 180) * cos(pi * C / 180), cos(pi * Theta / 180) * sin(pi * C / 180) * sin(pi * chi / 180) + sin(pi * Theta / 180) * cos(pi * chi / 180)) - delta
	Theta_SampCen = (180/pi) * asin( -cos(pi * Theta / 180) * sin(pi * C / 180) * cos(pi * chi / 180) + sin(pi * Theta / 180) * sin(pi * chi / 180))

	C_vat_SampCen = (180/pi) * atan2(cos(pi * Theta_vat / 180) * cos(pi * C_vat / 180), cos(pi * Theta_vat / 180) * sin(pi * C_vat / 180) * sin(pi * chi / 180) + sin(pi * Theta_vat / 180) * cos(pi * chi / 180)) - delta
	Theta_vat_SampCen = (180/pi) * asin( -cos(pi * Theta_vat / 180) * sin(pi * C_vat / 180) * cos(pi * chi / 180) + sin(pi * Theta_vat / 180) * sin(pi * chi / 180))

	if (C_SampCen < -90)
		do
			C_SampCen = C_SampCen + 180
		while (C_SampCen < -90)
	endif
	if (C_vat_SampCen < -90)
		do
			C_vat_SampCen = C_vat_SampCen + 180
		while (C_vat_SampCen < -90)
	endif


	//Assign results Results
	for (i = X1; i < X2; i+=1)
		for (j = Y1; j < Y2; j+=1)
			if (ROIFlag)		// using pink ROI
				if (useImageMask == 1)	// using image mask
					if ((roiStack[i][j] != 1) && (imageMask_image[i][j] > gImageMin) && (imageMask_image[i][j] < gImageMax))
						POLChiSq_ROI[i][j] = V_Chisq

						POL_A_ROI[i][j] = A
						POL_B_ROI[i][j] = B
						POL_C_ROI[i][j] = C
						POL_D_ROI[i][j] = D

						POL_A_vat_ROI[i][j] = A_vat
						POL_B_vat_ROI[i][j] = B_vat
						POL_C_vat_ROI[i][j] = C_vat
						POL_D_vat_ROI[i][j] = D_vat

						POL_C_SampCen_ROI[i][j] = C_SampCen
						POL_Theta_SampCen_ROI[i][j] = Theta_SampCen

						POL_C_vat_SampCen_ROI[i][j] = C_vat_SampCen
						POL_Theta_vat_SampCen_ROI[i][j] = Theta_vat_SampCen
					endif
				else		// not using image mask
					if (roiStack[i][j] != 1)
						POLChiSq_ROI[i][j] = V_Chisq

						POL_A_ROI[i][j] = A
						POL_B_ROI[i][j] = B
						POL_C_ROI[i][j] = C
						POL_D_ROI[i][j] = D

						POL_A_vat_ROI[i][j] = A_vat
						POL_B_vat_ROI[i][j] = B_vat
						POL_C_vat_ROI[i][j] = C_vat
						POL_D_vat_ROI[i][j] = D_vat

						POL_C_SampCen_ROI[i][j] = C_SampCen
						POL_Theta_SampCen_ROI[i][j] = Theta_SampCen

						POL_C_vat_SampCen_ROI[i][j] = C_vat_SampCen
						POL_Theta_vat_SampCen_ROI[i][j] = Theta_vat_SampCen
					endif
				endif
			else		// not using pink ROI
				if (useImageMask == 1)	// using image mask
					if ((imageMask_image[i][j] > gImageMin) && (imageMask_image[i][j] < gImageMax))
						POLChiSq_ROI[i][j] = V_Chisq

						POL_A_ROI[i][j] = A
						POL_B_ROI[i][j] = B
						POL_C_ROI[i][j] = C
						POL_D_ROI[i][j] = D

						POL_A_vat_ROI[i][j] = A_vat
						POL_B_vat_ROI[i][j] = B_vat
						POL_C_vat_ROI[i][j] = C_vat
						POL_D_vat_ROI[i][j] = D_vat

						POL_C_SampCen_ROI[i][j] = C_SampCen
						POL_Theta_SampCen_ROI[i][j] = Theta_SampCen

						POL_C_vat_SampCen_ROI[i][j] = C_vat_SampCen
						POL_Theta_vat_SampCen_ROI[i][j] = Theta_vat_SampCen
					endif
				else		// not using image mask
					POLChiSq_ROI[i][j] = V_Chisq

					POL_A_ROI[i][j] = A
					POL_B_ROI[i][j] = B
					POL_C_ROI[i][j] = C
					POL_D_ROI[i][j] = D

					POL_A_vat_ROI[i][j] = A_vat
					POL_B_vat_ROI[i][j] = B_vat
					POL_C_vat_ROI[i][j] = C_vat
					POL_D_vat_ROI[i][j] = D_vat

					POL_C_SampCen_ROI[i][j] = C_SampCen
					POL_Theta_SampCen_ROI[i][j] = Theta_SampCen

					POL_C_vat_SampCen_ROI[i][j] = C_vat_SampCen
					POL_Theta_vat_SampCen_ROI[i][j] = Theta_vat_SampCen
				endif
			endif
		endfor
	endfor

	//Generate Text Box Results
	String ResultsText = "X:\t"+num2str(X1) + " : " + num2str(X2)+"\rY:\t"+num2str(Y1) + " : " + num2str(Y2)
	ResultsText = ResultsText + "\r\rf(x)=a + b cos\S2\M(x - c')\rChiSq:\t" + num2str(V_Chisq) + "\r\rPeak angle (c'):\t" + num2str(C) + "\ra:\t\t" + num2str(A) + "\rb:\t\t" + num2str(B) + "\rd:\t\t"+num2str(D)
	ResultsText = ResultsText + "\r\rVaterite:\rPeak angle (c'):\t" + num2str(C_vat) + "\ra:\t\t" + num2str(A_vat) + "\rb:\t\t" + num2str(B_vat) + "\rd:\t\t"+num2str(D_vat)
	ResultsText = ResultsText + "\r\rSample Centered:\rPeak angle (phi):\t" + num2str(C_SampCen) + "\rTheta:\t\t" + num2str(Theta_SampCen)
	ResultsText = ResultsText + "\r\rVaterite, Sample Centered:\rPeak angle (phi):\t" + num2str(C_vat_SampCen) + "\rTheta:\t\t" + num2str(Theta_vat_SampCen)
	TextBox /W=PolarizationAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	SetActiveSubwindow PolarizationAnalysis

End

Function ClearROIs()

	Variable i, j
	String StackFolder = "root:SPHINX:Stacks"

	//Get ROI Positions from SVD Folder
		NVAR X1 	= root:SPHINX:SVD:gSVDLeft
		NVAR X2 	= root:SPHINX:SVD:gSVDRight
		NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
		NVAR Y2 	= root:SPHINX:SVD:gSVDTop
		if (!NVAR_Exists(X1))
			Print " *** Please select an ROI"
			return 0
		endif

	// Assign Results waves
		WAVE /D POL_A_ROI = $(StackFolder+":POL_A_polROI")
		WAVE /D POL_B_ROI = $(StackFolder+":POL_B_polROI")
		WAVE /D POL_C_ROI = $(StackFolder+":POL_C_polROI")
		WAVE /D POL_D_ROI = $(StackFolder+":POL_D_polROI")
		WAVE /D POLChiSq_ROI = $(StackFolder+":POL_ChiSq_polROI")

		WAVE /D POL_A_vat_ROI = $(StackFolder+":POL_A_vat_polROI")
		WAVE /D POL_B_vat_ROI = $(StackFolder+":POL_B_vat_polROI")
		WAVE /D POL_C_vat_ROI = $(StackFolder+":POL_C_vat_polROI")
		WAVE /D POL_D_vat_ROI = $(StackFolder+":POL_D_vat_polROI")

		WAVE /D POL_C_SampCen_ROI = $(StackFolder+":POL_C_SampCen_polROI")
		WAVE /D POL_Theta_SampCen_ROI = $(StackFolder+":POL_Theta_SampCen_polROI")

		WAVE /D POL_C_vat_SampCen_ROI = $(StackFolder+":POL_C_vat_SampCen_polROI")
		WAVE /D POL_Theta_vat_SampCen_ROI = $(StackFolder+":POL_Theta_vat_SampCen_polROI")

	// Clear waves, if they exist
		for (i = X1; i < X2; i+=1)
			for (j = Y1; j < Y2; j+=1)
				if (WaveExists(POL_A_ROI))
					POL_A_ROI[i][j] = NaN
					POL_B_ROI[i][j] = NaN
					POL_C_ROI[i][j] = NaN
					POL_D_ROI[i][j] = NaN
					POLChiSq_ROI[i][j] = NaN
				endif
				if (WaveExists(POL_A_vat_ROI))
					POL_A_vat_ROI[i][j] = NaN
					POL_B_vat_ROI[i][j] = NaN
					POL_C_vat_ROI[i][j] = NaN
					POL_D_vat_ROI[i][j] = NaN
				endif
				if (WaveExists(POL_C_SampCen_ROI))
					POL_C_SampCen_ROI[i][j] = NaN
					POL_Theta_SampCen_ROI[i][j] = NaN
				endif
				if (WaveExists(POL_C_vat_SampCen_ROI))
					POL_C_vat_SampCen_ROI[i][j] = NaN
					POL_Theta_vat_SampCen_ROI[i][j] = NaN
				endif				
			endfor
		endfor

End
		

// BG: This is the function that is called by the Analyze ROI Button
Function AnalyzeStack()


	Variable /G multithread
	if (multithread)
		MTAnalyzeStack()
		return 0
	endif

	SetDataFolder root:POLARIZATION:Analysis

	Variable i,j,k,kft,keep,n,m,nm,nMax,mMax,V_chisq,V_max,MaxPolAngle,MaxPolAngleZY,A,B
	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	WAVE spectrum 	= $(PanelFolder + ":spectrum")
	WAVE SPHINXStack = $(StackFolder+":"+StackName)
	
	WAVE NumData = $("root:POLARIZATION:NumData")
	Variable MaxX = NumData[0]
	Variable MaxY = NumData[1]

	// If AutoSave box is checked, save the experiment
	Variable /G autoSave
	if (autoSave)
		if (stringmatch(igorInfo(1),"Untitled"))
			string tempFileName = StackName
			if (strsearch(tempFileName,"X",0) == 0)
				tempFileName = ReplaceString("X", tempFileName+".pxp", "", 0, 1)
			endif
			SaveExperiment /P=Path2Image as tempFileName
		else
			SaveExperiment
		endif
	endif

	//Get ROI Positions from SVD Folder
	//============= PINK ROI CODE =======================
		NVAR X1 	= root:SPHINX:SVD:gSVDLeft
		NVAR X2 	= root:SPHINX:SVD:gSVDRight
		NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
		NVAR Y2 	= root:SPHINX:SVD:gSVDTop
		if (!NVAR_Exists(X1))
			Print " *** Please select an ROI"
			return 0
		endif
		NVAR Bin = root:SPHINX:Browser:gCursorBin

	// Check pink ROI
		String StackWindow	= "StackBrowser#StackImage"
		String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
		WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
		String AVStackFolder	= GetWavesDataFolder(avStack,1)

		NVAR gROIMapFlag 	= root:SPHINX:SVD:gROIMappingFlag
		Variable ROIFlag
		WAVE roiStack 		= $(AVStackFolder + StackName + "_av_roi")

		if (gROIMapFlag)
			ROIFlag 	= CheckROIMapping(roiStack,gROIMapFlag,X1,X2,Y1,Y2)
			if (ROIFlag==0)
				print " 		... Aborted the mapping routine due to pink ROI problem"
				return 0
			endif
		endif
	//============= PINK ROI CODE =======================


	//Get angle range for finding peaks after fit
		NVAR maxAngle = $("root:POLARIZATION:maxAngle")
		NVAR minAngle = $("root:POLARIZATION:minAngle")

	// Normalization Settings
		NVAR gInvertSpectraFlag	= $(BrowserFolder+":gInvertSpectraFlag")
		Variable /G NormToI0
		if (NormToI0 == 1)
			WAVE I0 = root:POLARIZATION:Analysis:I0
		endif

	// Assign Results waves
		WAVE /D POL_C 			= $(StackFolder+":POL_Cprime")
		WAVE /D POLChiSq 		= $(StackFolder+":POL_ChiSq")
		WAVE /D POLIntensity 	= $(StackFolder+":POL_Intensity")
		WAVE /D POL_A 			= $(StackFolder+":POL_A")
		WAVE /D POL_B 			= $(StackFolder+":POL_B")
		WAVE /D POL_D 			= $(StackFolder+":POL_D")
		WAVE /D POL_HSL 		= $(StackFolder+":POL_HSL")
		//
		WAVE /D POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
//		WAVE /D POL_Rpol 		= $(StackFolder+":POL_Rpol")
//		WAVE /D POL_PhiSP 		= $(StackFolder+"::POL_PhiSP")
//		WAVE /D POL_ThetSP 	= $(StackFolder+":POL_ThetSP")

		// check for use of old name POL_Analysis, and update to POL_Cprime
		if (!WaveExists(POL_C) && WaveExists($(StackFolder+":POL_Analysis")))
			Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
			Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
			Duplicate /O POL_Analysis, POL_C
			KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
		endif

	// Make Results Waves if needed
		if (!WaveExists(POL_C))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_ChiSq") /WAVE=POLChiSq
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Intensity") /WAVE=POLIntensity
			POL_C = NaN
			POLChiSq = NaN
			POLIntensity = NaN
		endif
	// Make NEW Results Waves if needed
		if (!WaveExists(POL_A))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_A") /WAVE=POL_A
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_B") /WAVE=POL_B
			POL_A = NaN
			POL_B = NaN
		endif
		if (!WaveExists(POL_D))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_D") /WAVE=POL_D
			POL_D = NaN
		endif

	// Assign and make vaterite waves
		WAVE /D POL_A_vat = $(StackFolder+":POL_A_vat")
		WAVE /D POL_B_vat = $(StackFolder+":POL_B_vat")
		WAVE /D POL_C_vat = $(StackFolder+":POL_C_vat")
		WAVE /D POL_D_vat = $(StackFolder+":POL_D_vat")

		if (!WaveExists(POL_C_vat))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_A_vat") /WAVE=POL_A_vat
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_B_vat") /WAVE=POL_B_vat
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_C_vat") /WAVE=POL_C_vat
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_D_vat") /WAVE=POL_D_vat
			POL_A_vat = NaN
			POL_B_vat = NaN
			POL_C_vat = NaN
			POL_D_vat = NaN
		endif

	// Variable for storing current guesses
		Make/D/N=(3,2)/O W_coef
		// Make appropriate guesses, depending on data inversion, to hopefully avoid "Singular Matrix" errors and get better fits...
		if (gInvertSpectraFlag == 0)
				W_coef[][0] = {-140,50,1}
				W_coef[][1] = {-140,-50,-2}
		else
				W_coef[][0] = {140,-100,2}
				W_coef[][1] = {140,100,-5}
		endif

	Variable Duration, timeRef = startMSTimer
	Variable V_fitOptions=4		//Suppresses Curve Fit Window
	Variable V_FitError=0		//Block error reporting and capture error data

	createFitSpectrumShell()
	WAVE /D fit_spectrum_m = $("root:POLARIZATION:Analysis:fit_spectrum_m")
	WAVE /D fit_spectrum_m2 = $("root:POLARIZATION:Analysis:fit_spectrum_m2")

	OpenProcBar("Analyzing Polarization Angle Intensity Data for "+StackName)

	for (i = X1; i < X2; i += Bin)
		for (j = Y1; j < Y2; j += Bin)


		// Make appropriate guesses, depending on data inversion, to hopefully avoid "Singular Matrix" errors and get better fits...
		// We do this for every fit so that "bad" fits are not propogated to nearby pixels
		if (gInvertSpectraFlag == 0)
			W_coef[][0] = {-140,50,1}
			W_coef[][1] = {-140,-50,-2}
		else
			W_coef[][0] = {140,-100,2}
			W_coef[][1] = {140,100,-5}
		endif


			nm = 0
			// May get data from a bit past ROI, but binning stats are more accurate for Intensity data!
			mMax 	= (i+Bin > MaxX) ? MaxX : (i+Bin)
			nMax 	= (j+Bin > MaxY) ? MaxY : (j+Bin)
			spectrum = 0

			// EXTRACT SPECTRUM from PIXEL i,j (with Binning, if specified)
				for (m=i; m < mMax; m += 1)
					for (n=j; n < nMax; n += 1)
						spectrum[] 	+= SPHINXStack[m][n][p]
						nm += 1
					endfor
				endfor

			// If Binning worked, continue
				if (nm > 0 && cmpstr(num2str(spectrum[1]), "NaN") != 0 && ((ROIFlag && roiStack[i][j] != 1) || !ROIFlag))

				// Normalize Extracted Spectra, per settings in Stack Browser
					if (gInvertSpectraFlag == 0)
						spectrum = -1*spectrum
					endif
					spectrum /= Bin^2
					if (NormToI0 == 1)
						spectrum /= I0
					endif
				//PERFORM FIT FUNCTION FOR spectrum
					keep = 0 // Variable for exiting the FOR loop
					for (k = 0; k < 2; k += 1) // Allow iterations, if required, to improve Fit
						V_FitError = 0	// Capture fit errors, and do not prompt user!
						FuncFit/NTHR=0/N/Q=1 cos_squared W_coef[][k]  spectrum /X=:::POLARIZATION:angles /D
						
						if (V_Chisq < 300)
							break // Break out of For loop - Good Fit.
						elseif (k == 0)
							kft = V_Chisq
							if (keep == 1)
								break // Break out of For loop - Best possible fit.
							endif
						elseif (k > 0)
							if (kft > V_Chisq)
								break // Break out of For loop - Best possible fit.
							else
								keep = 1
								k = -1 //Redo the first attempt
							endif
						endif
					endfor

					if (V_FitError == 0)
						fit_spectrum_m = W_coef[0][0]+W_coef[1][0]*cos((x)/180*pi-W_coef[2][0])^2
						WaveStats /Q /M=1 fit_spectrum_m

						MaxPolAngle = V_maxloc
						A = V_min
						B = V_max-V_min
						
						fit_spectrum_m2 = W_coef[0][0]+W_coef[1][0]*cos((x)/180*pi-W_coef[2][0])^2
						WaveStats /Q /M=1 fit_spectrum_m2
						MaxPolAngleZY = V_maxloc
						
					// 1.16.2014 - Commenting out now that the fit_spectrum is calculated for -90-90
					//	if ((V_maxloc > minAngle) && (V_maxloc < maxAngle))
					//		MaxPolAngle = V_maxloc
					//	elseif ((V_minloc > minAngle) && (V_minloc < maxAngle))
					//		MaxPolAngle = V_minloc - 90
					//	// Next two cases should only occur in a 0->90 degree angle scan, if the max lies on an edge.
					//	// Enforces the nature of Cos^2
					//	elseif ((V_minloc == 0) && (V_maxloc == 90))
					//		MaxPolAngle = 90
					//	elseif ((V_minloc == 90) && (V_maxloc == 0))
					//		MaxPolAngle = 0	
					//	else
					//		//Error angle
					//		MaxPolAngle = 999
					//	endif
					else
						MaxPolAngle	= NaN
						A			= NaN
						B			= NaN
						V_Chisq		= NaN
						V_max		= NaN

						if (gInvertSpectraFlag == 0)
							W_coef[][0] = {-140,50,1}
							W_coef[][1] = {-140,-50,-2}
						else
							W_coef[][0] = {140,-100,2}
							W_coef[][1] = {140,100,-5}
						endif
					endif

				elseif (ROIFlag && roiStack[i][j] == 1)
					// use previous values
					MaxPolAngle		= POL_C[i][j]
					MaxPolAngleZY 	= POL_PhiZY[i][j]
					A					= POL_A[i][j]
					B					= POL_B[i][j]
					V_Chisq		= POLChiSq[i][j]
					V_max		= POLIntensity[i][j]

			//If Binning didn't work, or the stack is NaN

				else
					MaxPolAngle	= NaN
					MaxPolAngleZY	= NaN
					A				= NaN
					B				= NaN
					V_Chisq		= NaN
					V_max		= NaN
				endif

			//ASSIGN RESULTS TO POL_C STACK
				for (m = i; m < mMax; m += 1)
					for (n = j; n < nMax; n += 1)
						POL_C[m][n] = maxPolAngle
						
						POLChiSq[m][n] = V_Chisq
						POLIntensity[m][n] = V_max
						POL_A[m][n] = A
						POL_B[m][n] = B
						POL_D[m][n] = (A == 0 || A == NaN) ? NaN : B/A
						
//						POL_PhiZY[m][n] = maxPolAngleZY
						
					endfor
				endfor
		endfor
		UpdateProcessBar((i-X1)/(X2-X1))
	endfor

	CloseProcessBar()

	Duration = stopMSTimer(timeRef)/1000000
	Print " 		.............. took  ", Duration,"  seconds for ",trunc((X2-X1)*(Y2-Y1)/Bin^2),"pixels with binning",Bin,"x",Bin,"."
	
	WaveStats /Q/M=1 POL_B
	Print " Maximum b value",V_max,"at",V_maxRowLoc,V_maxColLoc
	
	String ResultsText = "Stack Analysis Completed\r"
	ResultsText = ResultsText + "\r\rf(x)=a + b cos\S2\M(x - c')\r"
	ResultsText = ResultsText + "\rView Analysis and X\S2\M\rimages in SPHINX"
	TextBox /W=PolarizationAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	
//	String ResultsText = "Stack Analysis Completed\r\rView Analysis and X\S2\M\rimages in SPHINX"
//	TextBox /W=PolarizationAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
//	SetActiveSubwindow PolarizationAnalysis

	// create vaterite maps
		POL_A_vat[][] = (POL_A[p][q] != NaN && POL_B[p][q] != NaN) ? POL_A[p][q] + POL_B[p][q] : NaN
		POL_B_vat[][] = (POL_B[p][q] != NaN) ? -POL_B[p][q] : NaN
		POL_C_vat[][] = (POL_C[p][q] != NaN) ? POL_C[p][q] + 90 : NaN
		POL_C_vat[][] = (POL_C_vat[p][q] > 90) ? (POL_C_vat[p][q] - 180) : POL_C_vat[p][q]
		POL_D_vat[][] = POL_B_vat[p][q] / POL_A_vat[p][q]

	// If AutoSave box is checked, save the experiment
	if (autoSave)
		// uncheck the box to prevent accidental AutoSaving in the future
		autoSave = 0
		SaveExperiment
	endif
End

Function createFitSpectrumShell()
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

Function FitCosSq()
	
	MakeVariableIfNeeded("root:POLARIZATION:Analysis:A",0)
	NVAR A = $("root:POLARIZATION:Analysis:A")
	MakeVariableIfNeeded("root:POLARIZATION:Analysis:B",0)
	NVAR B = $("root:POLARIZATION:Analysis:B")
	MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxPolAngle",0)
	NVAR MaxPolAngle = $("root:POLARIZATION:Analysis:MaxPolAngle")
	MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxPolAngleZY",0)
	NVAR MaxPolAngleZY = $("root:POLARIZATION:Analysis:MaxPolAngleZY")
	MakeVariableIfNeeded("root:POLARIZATION:Analysis:chisq",0)
	NVAR chisq = $("root:POLARIZATION:Analysis:chisq")

	String BrowserFolder = "root:SPHINX:Browser"
	NVAR gInvertSpectraFlag	= $(BrowserFolder+":gInvertSpectraFlag")
	
	Variable V_fitOptions=4		//Suppresses Curve Fit Window
	Variable k, kft, keep
	// Variable for storing current guesses
		Make/D/N=(3,2)/O W_coef
		// Make appropriate guesses, depending on data inversion, to hopefully avoid "Singular Matrix" errors and get better fits...
		if (gInvertSpectraFlag == 0)
				W_coef[][0] = {-140,50,1}
				W_coef[][1] = {-140,-50,-2}
		else
				W_coef[][0] = {140,-100,2}
				W_coef[][1] = {140,100,-5}
		endif
	
	for (k=0;k<2;k+=1) // Allow two iterations, if required, to improve Fit
		FuncFit/NTHR=0/Q=1 cos_squared W_coef[][k]  spectrum /X=:::POLARIZATION:angles /D
		if (V_Chisq < 600)
			break // Break out of For loop - Good Fit.
		elseif (k == 0)
			kft = V_Chisq
			if (keep == 1)
				break // Break out of For loop - Best possible fit.
			endif
		elseif (k > 0)
			if (kft > V_Chisq)
				break // Break out of For loop - Best possible fit.
			else
				keep = 1 // First attempt was better
				k = -1 //Redo the first attempt
			endif
		endif
	endfor
	
	chisq = V_chisq
	
	createFitSpectrumShell()
	WAVE /D fit_spectrum_m = $("root:POLARIZATION:Analysis:fit_spectrum_m")
	fit_spectrum_m = W_coef[0][0]+W_coef[1][0]*cos((x)/180*pi-W_coef[2][0])^2
	
	WaveStats /Q /M=1 fit_spectrum_m
	MaxPolAngle = V_maxloc
	A = V_min
	B = V_max-V_min
	
	WAVE /D fit_spectrum_m2 = $("root:POLARIZATION:Analysis:fit_spectrum_m2")
	fit_spectrum_m2 = W_coef[0][0]+W_coef[1][0]*cos((x)/180*pi-W_coef[2][0])^2
	
	WaveStats /Q /M=1 fit_spectrum_m2
	MaxPolAngleZY = V_maxloc
	
// 1.16.2014 - Commenting out since these variables are no longer needed	
//	NVAR maxAngle = $("root:POLARIZATION:maxAngle")
//	NVAR minAngle = $("root:POLARIZATION:minAngle")
	
// 1.16.2014 - Commenting out now that the fit_spectrum is calculated for -90-90
//	if ((V_maxloc > minAngle) && (V_maxloc < maxAngle))
//		MaxPolAngle = V_maxloc
//	elseif ((V_minloc > minAngle) && (V_minloc < maxAngle))
//		MaxPolAngle = V_minloc - 90
//	// Next two cases should only occur in a 0->90 degree angle scan, if the max lies on an edge.
//	// Enforces the nature of Cos^2
//	elseif ((V_minloc == 0) && (V_maxloc == 90))
//		MaxPolAngle = 90
//	elseif ((V_minloc == 90) && (V_maxloc == 0))
//		MaxPolAngle = 0	
//	else
//		//Error angle
//		MaxPolAngle = 999
//	endif
	
End

Function ExtractPixelPolarizations()
	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]
	
	String BrowserFolder  	= "root:SPHINX:Browser"
	String PanelFolder 		= "root:POLARIZATION:Analysis"
	String StackFolder 		= "root:SPHINX:Stacks"
	SVAR StackName 		= root:POLARIZATION:StackName
	WAVE SPHINXStack 	= $(StackFolder+":"+StackName)
	
	Variable CsrX = NumVarOrDefault(BrowserFolder + ":gCursorAX",NumX/2)
	Variable CsrY = NumVarOrDefault(BrowserFolder + ":gCursorAY",NumY/2)
	
	if ((numtype(CsrX) == 2) || (numtype(CsrY) == 2))
		return 0
	endif
			
	NVAR gCursorBin	= $(BrowserFolder+":gCursorBin")
	WAVE spectrum 	= $(PanelFolder + ":spectrum")
	
	// hBox bins, if specified in the StackBrowser.
	Variable i, j, hBox = trunc(gCursorBin/2)
	
	spectrum 	= 0 	// Perhaps ImageTransform setBeam would be faster? 
	for (i=(CsrX-hBox);i<=(CsrX+hBox);i+=1)
		for (j=(CsrY-hBox);j<=(CsrY+hBox);j+=1)
			spectrum[] 	+= SPHINXStack[i][j][p]
		endfor
	endfor
	
	// Normalize Extracted Spectra, per settings in Stack Browser
	NVAR gInvertSpectraFlag	= $(BrowserFolder+":gInvertSpectraFlag")
	if (gInvertSpectraFlag == 0)
		spectrum = -1*spectrum
	endif
	
	spectrum /= gCursorBin^2
	
	// BG: I think we want to avoid any normalization of PIC data (?)
	Variable /G NormToI0
	if (NormToI0 == 1)
		WAVE I0 = root:POLARIZATION:Analysis:I0
		spectrum /= I0
	endif

End

Function PolResultExtractRow()
	
	SetDataFolder root:POLARIZATION:Analysis
	
	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]
	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	String StackWindow = "StackBrowser#StackImage"
	Variable /G enhancePolAnalysis
	Variable /G gaussPolAnalysis
	Variable /G useMaskedPolAnalysis
	if (enhancePolAnalysis == 1)
		//Use enhanced Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Enhanced")
	elseif (gaussPolAnalysis == 1)
		//Use gauss smoothed Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Gauss")
	elseif (useMaskedPolAnalysis == 1)
		//Use masked Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Masked")
	else
		WAVE /D POL_C = $(StackFolder+":POL_Cprime")
		// check for use of old name POL_Analysis, and update to POL_Cprime
		if (!WaveExists(POL_C))
			Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
			Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
			Duplicate /O POL_Analysis, POL_C
			KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
		endif
	endif
	
	Variable CsrX = trunc(hcsr(A, StackWindow))
	Variable CsrY = trunc(vcsr(A, StackWindow))
	Variable CsrX2 = trunc(hcsr(B, StackWindow))
	Variable CsrY2 = trunc(vcsr(B, StackWindow))
	
	if ((numtype(CsrX) == 2) || (numtype(CsrY) == 2) || (numtype(CsrX2) == 2) || (numtype(CsrY2) == 2))
		return 0
	endif
			
	NVAR gCursorBin	= $(BrowserFolder+":gCursorBin")
	WAVE rowIntensityMap 	= $(PanelFolder + ":rowIntensityMap")
	Make /O/D/N=(NumData[0]*gCursorBin+1)	root:POLARIZATION:Analysis:rowMap
	WAVE rowMap		= $(PanelFolder + ":rowMap")
	
	// hBox bins, if specified in the StackBrowser.
	Variable i, j, y, B, M
	Variable /G anglePolAnalysis
	M = (CsrY2-CsrY)/(CsrX2-CsrX)
	B = CsrY - M*CsrX
	
	rowMap 	= 0
	rowIntensityMap 	= 0
	for (i=0;i<gCursorBin;i+=1)
		for (j=0;j<NumX;j+=1)
			y = CsrY+i
			if (anglePolAnalysis == 1)
				y = M*j + B
			endif
			rowMap[j+i*NumX]	= POL_C[j][y]
		endfor
	endfor
	
	NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint
	// Adjust according to scale setpoint!
	rowMap[][] -= scaleSetPoint
	rowMap[][] = (rowMap[p][q] < -90) ? (rowMap[p][q] + 180) : rowMap[p][q]
	rowMap[][] = (rowMap[p][q] > 90) ? (rowMap[p][q] - 180) : rowMap[p][q]
	
	for (i=0;i<=180;i+=0.5)
		rowIntensityMap[i*2][1] 	= i
	endfor
	
	Histogram rowMap, rowIntensityMap
	
End

Function PolResultCollectCursors()

	String PanelFolder = "root:POLARIZATION:Analysis"
	
	PolResultExtractRow()

	NVAR gCursorP1 	= $(PanelFolder+":gCursorP1")
	NVAR gCursorP2 	= $(PanelFolder+":gCursorP2")
	NVAR PixelAY	= $("root:SPHINX:Browser:gCursorAY")
	Variable PolMin, PolMax, difference

	PolMin 	= min(hcsr(A, "PolResultAnalysis#PixelPlot"),hcsr(B, "PolResultAnalysis#PixelPlot"))
	PolMax 	= max(hcsr(A, "PolResultAnalysis#PixelPlot"),hcsr(B, "PolResultAnalysis#PixelPlot"))
	
	gCursorP1 = PolMin
	gCursorP2 = PolMax
	difference = PolMax - PolMin
	
	String ResultsText = "Row Number:\t"+num2str(PixelAY)+"\r\rMin Pol:\t\t"+num2str(PolMin)+"\rMax Pol:\t"+num2str(PolMax)+"\r\rDelta Pol:\t"+num2str(difference)
	TextBox /W=PolResultAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	SetActiveSubwindow PolResultAnalysis

End

Function PolResultSaveAnalysis()

	String PanelFolder = "root:POLARIZATION:Analysis"
	
	PolResultExtractRow()

	NVAR gCursorP1 	= $(PanelFolder+":gCursorP1")
	NVAR gCursorP2 	= $(PanelFolder+":gCursorP2")
	NVAR PixelAY	= $("root:SPHINX:Browser:gCursorAY")
	Variable PolMin, PolMax, difference

	PolMin 	= min(hcsr(A, "PolResultAnalysis#PixelPlot"),hcsr(B, "PolResultAnalysis#PixelPlot"))
	PolMax 	= max(hcsr(A, "PolResultAnalysis#PixelPlot"),hcsr(B, "PolResultAnalysis#PixelPlot"))
	
	gCursorP1 = PolMin
	gCursorP2 = PolMax
	difference = PolMax - PolMin
	
	WAVE /D POL_C = $(PanelFolder+":Pol_Cprime")

	// check for use of old name POL_Analysis, and update to POL_Cprime
	if (!WaveExists(POL_C) && WaveExists($(PanelFolder+":Pol_Analysis")))
		Wave /D POL_Analysis = $(PanelFolder+":Pol_Analysis")
		Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(PanelFolder+":Pol_Cprime") /WAVE=POL_C
		Duplicate /O POL_Analysis, POL_C
		KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
	endif
	
	// Make Results Table if needed
	if (!WaveExists(POL_C))
		Make /O/D/N=(2000,2) $(PanelFolder+":Pol_Cprime") /WAVE=POL_C
		POL_C[0][0] = 88888
		POL_C[0][1] = 1
	endif
	
	Variable PolLength
	PolLength = DimSize(POL_C,0)
	
	POL_C[POL_C[0][1]][0] = PixelAY
	POL_C[POL_C[0][1]][1] = difference
	POL_C[0][1] = POL_C[0][1] + 1
	
	String ResultsText = "Row Number:\t"+num2str(PixelAY)+"\r\rMin Pol:\t\t"+num2str(PolMin)+"\rMax Pol:\t"+num2str(PolMax)+"\r\rDelta Pol:\t"+num2str(difference)+"\r\r\rResults Added to Table"
	TextBox /W=PolResultAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText
	SetActiveSubwindow PolResultAnalysis

End

Function ScaleAnalysisImage()

	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]
	Variable i
	String ImageFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	
	//ScaleSetPoint shifts the center of the curve data... For use if the data is centered around 0* and 180*.
	NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint

	// Input name of image to scale
	String ImageName
	String ImageList = ReturnImageList(ImageFolder,0)
	Prompt ImageName, "List of images", popup, ImageList
	DoPrompt "Select image to scale", ImageName
	if (V_flag)
		return 0
	endif
	
	// Load the image to be scaled, created new WAVE for scaled image
	WAVE /D SourceImage = $(ImageFolder+":"+ImageName)
	Make /O/N=(NumX,NumY+1)/D $(ImageFolder+":"+ImageName+"_SCL") /WAVE=POLAnaScaled
	
	POLAnaScaled = NaN
	POLAnaScaled = ( SourceImage + 90 ) / 180 * 255
	// Force all graylevels in the images to be between 0 and 255 (8-bit)
	POLAnaScaled[][] = (POLAnaScaled[p][q] < 0) ? 0 : POLAnaScaled[p][q]
	POLAnaScaled[][] = (POLAnaScaled[p][q] > 255) ? 255 : POLAnaScaled[p][q]
	// Adjust according to scale setpoint!
	POLAnaScaled[][] -= (scaleSetPoint) / 180 * 255
	POLAnaScaled[][] = (POLAnaScaled[p][q] < 0) ? (POLAnaScaled[p][q] + 255): POLAnaScaled[p][q]
	POLAnaScaled[][] = (POLAnaScaled[p][q] > 255) ? (POLAnaScaled[p][q] - 255) : POLAnaScaled[p][q]
	// Add a "scale-bar" to the bottom of the Scaled Analysis image to ensure proper leveling in Photoshop
	for (i=0;i<=NumX;i+=1)
		POLAnaScaled[i][NumY+1] 	= i / NumX * 255
	endfor

	DisplaySPHINXImage(ImageName+"_SCL")
End

Function IgnoreROI()
	
	// Check if IgnoreROI Wave Exists -- if not, Create.
	String ImageFolder = "root:SPHINX:Stacks"
	if (exists(ImageFolder+":POL_Ignore_Mask") == 0)
		Wave NumData = $("root:POLARIZATION:NumData")
		Variable NumX = NumData[0]
		Variable NumY = NumData[1]
		
		Make /O/N=(NumX,NumY)/D $(ImageFolder+":POL_Ignore_Mask") /WAVE=POL_Ignore_Mask
		
		POL_Ignore_Mask[][] = 1
	else
		Wave /D POL_Ignore_Mask = $(ImageFolder+":POL_Ignore_Mask")
	endif
	
	//Get ROI Positions from SVD Folder
	NVAR X1 	= root:SPHINX:SVD:gSVDLeft
	NVAR X2 	= root:SPHINX:SVD:gSVDRight
	NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
	NVAR Y2 	= root:SPHINX:SVD:gSVDTop
	if (!NVAR_Exists(X1))
		Print " *** Please select an ROI"
		return 0
	endif
	
	Variable i,j
	for (i=X1;i <= X2;i+=1)
		for (j=Y1;j <= Y2;j+=1)
				POL_Ignore_Mask[i][j] 	=	NaN
		endfor
	endfor
	
End

Function clearIgnoreMask()
	String ImageFolder = "root:SPHINX:Stacks"
	if (exists(ImageFolder+":POL_Ignore_Mask") == 1)
		Wave /D POL_Ignore_Mask = $(ImageFolder+":POL_Ignore_Mask")
		POL_Ignore_Mask[][] = 1
	endif
End

Function LoadPolI0()

	SVAR StackName = root:POLARIZATION:StackName
	String StackFolder = "root:SPHINX:Stacks"
	WAVE SPHINXStack = $(StackFolder+":"+StackName)
	Variable AbortFlag=0, NumA, NumE = Dimsize(SPHINXStack,2)
	String LoadWaveList 	= InteractiveLoadTextFile("Please locate the axis file")
	
	if (ItemsInList(LoadWaveList) > 0)
		String I0name		= StringFromList(1,LoadWaveList)		
		WAVE I0_data 	= $I0name
		
		NumA = numpnts(I0_data)
		
		if (NumA < NumE)
			DoAlert 0, "Loaded axis has fewer than "+num2str(NumE)+" points! Aborting. "
			AbortFlag = 1
		elseif (NumA > NumE)
			DoAlert 1, "Loaded axis has more than "+num2str(NumE)+" points! Continue? "
			if (V_flag)
				Print " 	*** Loaded only the first",NumE,"I-zero values from the",NumA,"values in the file."
			else
				AbortFlag = 1
			endif
		endif
		
		if (AbortFlag)
			return 0
		endif

		// *!*!* Must update the plot energy axis in order to fitting to work properly.
		Make /O/D/N=(NumE) root:POLARIZATION:Analysis:I0 /Wave = I0
		I0 = I0_data
	endif

End

Function EnhancePICmap()

	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	WAVE /D POL_C = $(StackFolder+":POL_Cprime")

	// check for use of old name POL_Analysis, and update to POL_Cprime
	if (!WaveExists($(StackFolder+":POL_Cprime")))
		Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
		Wave /D POL_C = $(StackFolder+":POL_Cprime")
		Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
		Duplicate /O POL_Analysis, POL_C
		KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
	endif

	//--------------------- Data exclusion
		// Create LevMask duplicate image (masking based on StackBrowser level settings)
			WAVE /D stackAvg = $(StackFolder+":"+StackName+"_average")
			NVAR gImageMin = root:SPHINX:Browser:gImageMin
			NVAR gImageMax = root:SPHINX:Browser:gImageMax
			Duplicate /O POL_C, $(StackFolder+":POL_Enhanced")
			WAVE /D POLenhanced = $(StackFolder+":POL_Enhanced")
		
			POLenhanced[][] = (stackAvg[p][q] < gImageMin) ? NaN : POLenhanced[p][q]
			POLenhanced[][] = (stackAvg[p][q] > gImageMax) ? NaN : POLenhanced[p][q]
			
		// Also mask any values of ChiSQ from the curve fit greater than 2 standard deviations
			WAVE /D POLChiSq = $(StackFolder+":POL_ChiSq")
			WaveStats /Q POLChiSq
			Variable ChiSQ_limit = 1.7*V_sdev
			
			POLenhanced[][] = (POLChiSq[p][q] > ChiSQ_limit) ? NaN : POLenhanced[p][q]
			
		// And mask any values from POL_Cprime Image Display level settings
			NVAR polImageMin = root:SPHINX:POL_Cprime:gImageMin
			NVAR polImageMax = root:SPHINX:POL_Cprime:gImageMax
			
			POLenhanced[][] = (POLenhanced[p][q] < polImageMin) ? NaN : POLenhanced[p][q]
			POLenhanced[][] = (POLenhanced[p][q] > polImageMax) ? NaN : POLenhanced[p][q]
	//------------------------
	
	// Replace excluded data with average of surrounding existing values
		//Iterate until all NaN values smoothed away, up to 10 times
		Variable i, num_iterations = 0
		do
			Smooth /M=(NaN) 2, POLenhanced
			WaveStats /Q POLenhanced
			num_iterations += 1
		//while(V_numNaNs > 5)
		while(V_numNaNs > 5 && num_iterations < 11)
		
End

Function GaussBlurPOLAnalysis()

	SetDataFolder root:SPHINX:Stacks

	SVAR StackName = root:POLARIZATION:StackName
	String StackFolder = "root:SPHINX:Stacks"
	WAVE /D POL_C = $(StackFolder+":POL_Cprime")

	// check for use of old name POL_Analysis, and update to POL_Cprime
	if (!WaveExists($(StackFolder+":POL_Cprime")))
		Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
		Wave /D POL_C = $(StackFolder+":POL_Cprime")
		Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
		Duplicate /O POL_Analysis, POL_C
		KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
	endif

	Duplicate /O POL_C, $(StackFolder+":POL_Gauss")
	Wave /D POLgauss = $(StackFolder+":POL_Gauss")
	
	// Get the blurring pixel range variable and number of passes
	NVAR GaussBlurPixels = root:POLARIZATION:Analysis:GaussBlurPixels
	NVAR GaussBlurPasses = root:POLARIZATION:Analysis:GaussBlurPasses
	
	NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint
	// Adjust according to scale setpoint before blurring!
	POLGauss[][] -= scaleSetPoint
	POLGauss[][] = (POLGauss[p][q] < -90) ? (POLGauss[p][q] + 180) : POLGauss[p][q]
	POLGauss[][] = (POLGauss[p][q] > 90) ? (POLGauss[p][q] - 180) : POLGauss[p][q]
	
	MatrixFilter /N=(GaussBlurPixels) /P=(GaussBlurPasses) gauss $(StackFolder+":POL_Gauss")
	
End

Function createMaskedPOLAnalysis()

	SVAR StackName = root:POLARIZATION:StackName
	String StackFolder = "root:SPHINX:Stacks"
	String PanelFolder = "root:POLARIZATION:Analysis"
	WAVE /D POL_C = $(StackFolder+":POL_Cprime")
	WAVE /D stackAvg = $(StackFolder+":"+StackName+"_average")

	// check for use of old name POL_Analysis, and update to POL_Cprime
	if (!WaveExists($(StackFolder+":POL_Cprime")))
		Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
		Wave /D POL_C = $(StackFolder+":POL_Cprime")
		Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
		Duplicate /O POL_Analysis, POL_C
		KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
	endif

	SetDataFolder root:POLARIZATION:Analysis
	
	// Duplicate analysis data
	Duplicate /O POL_C, $(StackFolder+":POL_Masked")
	WAVE /D MaskedPICmap = $(StackFolder+":POL_Masked")
	
	// If user has selected to use an averageMask, remove these pixels
	Variable /G averageMask
	if (averageMask == 1)
		NVAR gImageMin = root:SPHINX:Browser:gImageMin
		NVAR gImageMax = root:SPHINX:Browser:gImageMax
		
		MaskedPICmap[][] = (stackAvg[p][q] < gImageMin) ? NaN : MaskedPICmap[p][q]
		MaskedPICmap[][] = (stackAvg[p][q] > gImageMax) ? NaN : MaskedPICmap[p][q]
		
		NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint
		// Adjust according to scale setpoint!
		MaskedPICmap[][] -= scaleSetPoint
		MaskedPICmap[][] = (MaskedPICmap[p][q] < -90) ? (MaskedPICmap[p][q] + 180) : MaskedPICmap[p][q]
		MaskedPICmap[][] = (MaskedPICmap[p][q] > 90) ? (MaskedPICmap[p][q] - 180) : MaskedPICmap[p][q]
	endif

	// If the user has selected to use the Pol B mask explicitly, set Pol B to cut off at 10^2 and remove pixels
	MakeVariableIfNeeded(PanelFolder+":polBMask",0)
	NVAR usePolBMask = $(PanelFolder+":polBMask")
	if (usePolBMask == 1)
		WAVE /D POL_B = $(StackFolder+":POL_B")

		// make sure the POL_B image is displayed so that the histogram is guaranteed to exist
		DisplaySPHINXImage("POL_B")

		// these must be *after* the image has been displayed for the first time
		NVAR polBImageMin = $("root:SPHINX:POL_B:gImageMin")
		NVAR polBImageMax = $("root:SPHINX:POL_B:gImageMax")

		// set histogram to be 100 on the left and the max on the right
		Wave polBImageHist = $("root:SPHINX:POL_B:W_ImageHist")
		Variable numPtsB = DimSize(polBImageHist,0)
		FindLevel /Q/R=[10,numPtsB-1] polBImageHist, 100
		polBImageMin = V_LevelX
		FindLevel /Q/R=[numPtsB-1,polBImageMin] polBImageHist, polBImageHist[numPtsB-1]
		polBImageMax = V_LevelX

		// display POL_B again; this makes sure the blankimage mask on POL_B is updated properly
		DisplaySPHINXImage("POL_B")

		MaskedPICmap[][] = (POL_B[p][q] < polBImageMin) ? NaN : MaskedPICmap[p][q]
		MaskedPICmap[][] = (POL_B[p][q] > polBImageMax) ? NaN : MaskedPICmap[p][q]
	endif

	// If user has selected to use an ImageMask, remove these pixels
	Variable /G imageMask
	if ( (imageMask == 1) && (exists("root:POLARIZATION:ImageMask_name") == 2) )
		SVAR imageMaskName = root:POLARIZATION:ImageMask_name
		WAVE /D imageMask_image = $(StackFolder+":"+imageMaskName)
		
		NVAR gImageMin = $("root:SPHINX:"+imageMaskName+":gImageMin")
		NVAR gImageMax = $("root:SPHINX:"+imageMaskName+":gImageMax")
		
		MaskedPICmap[][] = (imageMask_image[p][q] < gImageMin) ? NaN : MaskedPICmap[p][q]
		MaskedPICmap[][] = (imageMask_image[p][q] > gImageMax) ? NaN : MaskedPICmap[p][q]
	endif

	// If user has selected to use IgnoreMask, remove these pixels
	Variable /G ignoreMask
	if ( (ignoreMask == 1) && (exists("root:SPHINX:Stacks:POL_Ignore_Mask") == 1) )
		WAVE /D POL_Ignore_Mask = $(StackFolder+":POL_Ignore_Mask")
		MaskedPICmap *= POL_Ignore_Mask
	endif

	DisplaySPHINXImage("POL_Masked")

	// recreate the image histogram to make sure it's updated, in case POL_Masked has changed
	String OldDf = GetDataFolder(1)
	SetDataFolder $("root:SPHINX:POL_Masked")
		ImageHistogram /I MaskedPICmap
		WAVE W_ImageHist
	SetDataFolder $OldDf

	Wave imageHist = $("root:SPHINX:POL_Masked:W_ImageHist")
	Variable numPts = DimSize(imageHist,0)
	NVAR gImageMin = $("root:SPHINX:POL_Masked:gImageMin")
	NVAR gImageMax = $("root:SPHINX:POL_Masked:gImageMax")

//	WaveStats /Q/M=1 imageHist
//	Variable histMax = V_maxLoc

	// Set histogram limits to 10^2
	FindLevel /Q/R=[0,numPts-1] imageHist, 100
//	FindLevel /Q/EDGE=2/R=(histMax, -90) imageHist, 100
	gImageMin 	= V_LevelX
	FindLevel /Q/R=[numPts-1,0] imageHist, 100
//	FindLevel /Q/EDGE=2/R=(histMax, 90) imageHist, 100
	gImageMax 	= V_LevelX

	// print 10^2 angle spread to the console window
	print num2str(gImageMax-gImageMin)

	// Set histogram limits to 10^3
	FindLevel /Q/R=[0,numPts-1] imageHist, 1000
//	FindLevel /Q/EDGE=2/R=(histMax, -90) imageHist, 1000
	gImageMin 	= V_LevelX
	FindLevel /Q/R=[numPts-1,0] imageHist, 1000
//	FindLevel /Q/EDGE=2/R=(histMax, 90) imageHist, 1000
	gImageMax 	= V_LevelX

	// print 10^3 angle spread to the console window
	print num2str(gImageMax-gImageMin)

	ShowImageHistogram(MaskedPICmap,"POL_Masked","root:SPHINX:POL_Masked","StackPOL_Masked")
End

Function imageMask()
	String ImageFolder = "root:SPHINX:Stacks"
	
	//Ask the user to load a single image
		//LoadImage()
	
	//Ask a user which image they just loaded
		//MakeStringIfNeeded("root:POLARIZATION:ImageMask_name","")
		//svar ImageName = root:POLARIZATION:ImageMask_name
		// Get the name of the most recently added Wave in the Stacks folder
		//ImageName = GetIndexedObjName("root:SPHINX:Stacks",1,CountObjects("root:SPHINX:Stacks",1)-1)
		
		//String tempImageName
		//String ImageList = ReturnImageList(ImageFolder)
		//Prompt tempImageName, "List of images", popup, ImageList
		//DoPrompt "Please Select Image from List", tempImageName
		//if (V_flag)
		//	return 0
		//endif
		//ImageName = tempImageName
		
	//Select Single Image as Mask
		MakeStringIfNeeded("root:POLARIZATION:ImageMask_name","")
		svar ImageName = root:POLARIZATION:ImageMask_name
		
		String tempImageName
		String ImageList = ReturnImageList(ImageFolder,0)
		Prompt tempImageName, "List of images", popup, ImageList
		DoPrompt "Please Select Image from List", tempImageName
		if (V_flag)
			return 0
		endif
		ImageName = tempImageName
		return 1
End

Function extractMaskedAS()
	NVAR gImageMin = $("root:SPHINX:POL_Masked:gImageMin")
	NVAR gImageMax = $("root:SPHINX:POL_Masked:gImageMax")

	// display angle spread
	print num2str(gImageMax-gImageMin)
End

Function StandardDevAnalysis()

	SetDataFolder root:POLARIZATION:Analysis

	SVAR StackName = root:POLARIZATION:StackName
	String StackFolder = "root:SPHINX:Stacks"
	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	Variable /G enhancePolAnalysis
	Variable /G gaussPolAnalysis
	Variable /G useMaskedPolAnalysis
	if (enhancePolAnalysis == 1)
		//Use enhanced Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Enhanced")
	elseif (gaussPolAnalysis == 1)
		//Use gauss smoothed Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Gauss")
	elseif (useMaskedPolAnalysis == 1)
		//Use masked Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Masked")
	else
		WAVE /D POL_C = $(StackFolder+":POL_Cprime")
		// check for use of old name POL_Analysis, and update to POL_Cprime
		if (!WaveExists(POL_C))
			Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
			Wave /D POL_C = $(StackFolder+":POL_Cprime")
			Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
			Duplicate /O POL_Analysis, POL_C
			KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
		endif
	endif
	
	SetDataFolder root:SPHINX:Stacks
	
	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]
	Make /O/N=(NumData[1])/D $("root:POLARIZATION:Analysis:POL_StdDevAna") /WAVE=POLStdDevAna
	
	NVAR gCursorBin	= $(BrowserFolder+":gCursorBin")
	Make /O/D/N=(NumX*gCursorBin+1)	root:POLARIZATION:Analysis:rowMap
	WAVE rowMap = $(PanelFolder + ":rowMap")
	Variable i,j,k
	
	for (j=0;j<NumY;j+=1)
		rowMap 	= 0
		rowMap[0] = NaN
		for (k=0;k<gCursorBin;k+=1)
			// We're starting at 1 here in X because the first column of the PEEM data is always garbage.
			for (i=1;i<NumX;i+=1)
				rowMap[i+k*NumX] = POL_C[i][j]
			endfor
		endfor
		
		NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint
		// Adjust according to scale setpoint!
		rowMap[][] -= scaleSetPoint
		rowMap[][] = (rowMap[p][q] < -90) ? (rowMap[p][q] + 180) : rowMap[p][q]
		rowMap[][] = (rowMap[p][q] > 90) ? (rowMap[p][q] - 180) : rowMap[p][q]
		
		POLStdDevAna[j] = Sqrt(Variance(rowMap))
	endfor
	
	// Automatically open the results:
	Edit/K=1 $("root:POLARIZATION:Analysis:POL_StdDevAna");DelayUpdate

End

Function CircDispAnalysis()

	SetDataFolder root:POLARIZATION:Analysis

	SVAR StackName = root:POLARIZATION:StackName
	String StackFolder = "root:SPHINX:Stacks"
	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	Variable /G enhancePolAnalysis
	Variable /G gaussPolAnalysis
	Variable /G useMaskedPolAnalysis
	if (enhancePolAnalysis == 1)
		//Use enhanced Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Enhanced")
	elseif (gaussPolAnalysis == 1)
		//Use gauss smoothed Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Gauss")
	elseif (useMaskedPolAnalysis == 1)
		//Use masked Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Masked")
	else
		WAVE /D POL_C = $(StackFolder+":POL_Cprime")
		// check for use of old name POL_Analysis, and update to POL_Cprime
		if (!WaveExists(POL_C))
			Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
			Wave /D POL_C = $(StackFolder+":POL_Cprime")
			Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
			Duplicate /O POL_Analysis, POL_C
			KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
		endif
	endif
	
	SetDataFolder root:SPHINX:Stacks
	
	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]
	Make /O/N=(NumData[1])/D $("root:POLARIZATION:Analysis:POL_CircDisAna_"+StackName) /WAVE=POLCircDisAna
	
	NVAR gCursorBin	= $(BrowserFolder+":gCursorBin")
	Make /O/D/N=(NumX*gCursorBin+1)	root:POLARIZATION:Analysis:rowMap
	WAVE rowMap = $(PanelFolder + ":rowMap")
	Variable i,j,k
	
	SetDataFolder root:POLARIZATION:Analysis
	
	for (j=0;j<NumY;j+=1)
		rowMap 	= 0
		for (k=0;k<gCursorBin;k+=1)
			// We're starting at 1 here in X because the first column of the PEEM data is always garbage.
			for (i=1;i<NumX;i+=1)
				rowMap[i+k*NumX] = POL_C[i][j]
			endfor
		endfor
		
		NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint
		// Adjust according to scale setpoint!
		rowMap[][] -= scaleSetPoint
		rowMap[][] = (rowMap[p][q] < -90) ? (rowMap[p][q] + 180) : rowMap[p][q]
		rowMap[][] = (rowMap[p][q] > 90) ? (rowMap[p][q] - 180) : rowMap[p][q]
		// Expand the -90-90 degrees to -180-180 degrees to allow circular statistics
		rowMap[] *= 2
		
		// Run Circular Statistical Analysis of Row from POL_Cprime
		statsCircularMoments /Q /MODE=3 rowMap
		WAVE circStats = $("W_CircularStats")
		// Assign circular dispersion of row to this section of the results
		// Circular Dispersion is circStats[13]
		// Circular Standard Deviation is circStats[10] in RADIANS convert back to DEGREES
			// Our deviation is DOUBLED, as we had to expand to 360 degrees. Add in a factor of 1/2.
		// Final factor of 4 converts this to 4*sigma (our definition of Angle Spread
		POLCircDisAna[j] = circStats[10] * (180 / pi) / 2 * 2.35482

	endfor

		// Compute standard deviation of entire image!
		duplicate /O POL_C root:POLARIZATION:polCircTemp
		WAVE /D polCircTemp = $("root:POLARIZATION:polCircTemp")
		polCircTemp *= 2
		variable totalImageStdDev
		statsCircularMoments /Q /MODE=3 polCircTemp
		totalImageStdDev = circStats[10] * (180 / pi) / 2 * 2.35482

		String ResultsText = "Circ Std Dev:\t"+num2str(totalImageStdDev)
		TextBox /W=PolResultAnalysis#PixelData /F=0 /C /N=ResultsBox /A=LT ResultsText

	// Automatically open the results:
	Edit/K=1 $("root:POLARIZATION:Analysis:POL_CircDisAna_"+StackName);DelayUpdate
End

Function ExtractROI()

	SetDataFolder root:POLARIZATION:Analysis

	SVAR StackName = root:POLARIZATION:StackName
	String StackFolder = "root:SPHINX:Stacks"
	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	Variable /G enhancePolAnalysis
	Variable /G gaussPolAnalysis
	Variable /G useMaskedPolAnalysis
	if (enhancePolAnalysis == 1)
		//Use enhanced Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Enhanced")
	elseif (gaussPolAnalysis == 1)
		//Use gauss smoothed Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Gauss")
	elseif (useMaskedPolAnalysis == 1)
		//Use masked Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Masked")
	else
		WAVE /D POL_C = $(StackFolder+":POL_Cprime")
		// check for use of old name POL_Analysis, and update to POL_Cprime
		if (!WaveExists(POL_C))
			Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
			Wave /D POL_C = $(StackFolder+":POL_Cprime")
			Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
			Duplicate /O POL_Analysis, POL_C
			KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
		endif
	endif

	WAVE /D POL_B = $(StackFolder+":POL_B")
	WAVE /D POL_D = $(StackFolder+":POL_D")
	WAVE /D POL_Theta = $(StackFolder+":POL_Theta")

	//Get ROI Positions from SVD Folder
	NVAR X1 	= root:SPHINX:SVD:gSVDLeft
	NVAR X2 	= root:SPHINX:SVD:gSVDRight
	NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
	NVAR Y2 	= root:SPHINX:SVD:gSVDTop
	if (!NVAR_Exists(X1))
		Print " *** Please select an ROI"
		return 0
	endif
	
	Duplicate /O /R=(X1,X2)(Y1,Y2) POL_C, root:SPHINX:Stacks:POL_extract
	Duplicate /O /R=(X1,X2)(Y1,Y2) POL_B, root:SPHINX:Stacks:POL_B_extract
	Duplicate /O /R=(X1,X2)(Y1,Y2) POL_D, root:SPHINX:Stacks:POL_D_extract
	Duplicate /O /R=(X1,X2)(Y1,Y2) POL_Theta, root:SPHINX:Stacks:POL_Theta_extract
	
	DisplaySPHINXImage("POL_extract")
	// Reset the histogram to -90 through 90 (otherwise this displays poorly)
	NVAR gImageMin = $("root:SPHINX:POL_extract:gImageMin")
	NVAR gImageMax = $("root:SPHINX:POL_extract:gImageMax")
	NVAR gHistAxisMin = $("root:SPHINX:POL_extract:gHistAxisMin")
	NVAR gHistAxisMax = $("root:SPHINX:POL_extract:gHistAxisMax")
	gImageMin = -90
	gImageMax = 90
	gHistAxisMin = -90
	gHistAxisMax = 90
	ApplyStackContrast("StackPOL_extract")
End

Function ExportBin()
	SetDataFolder root:POLARIZATION:Analysis

	SVAR StackName = root:POLARIZATION:StackName
	String StackFolder = "root:SPHINX:Stacks"
	String BrowserFolder = "root:SPHINX:Browser"
	String PanelFolder = "root:POLARIZATION:Analysis"
	Variable /G enhancePolAnalysis
	Variable /G gaussPolAnalysis
	Variable /G useMaskedPolAnalysis
	if (enhancePolAnalysis == 1)
		//Use enhanced Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Enhanced")
	elseif (gaussPolAnalysis == 1)
		//Use gauss smoothed Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Gauss")
	elseif (useMaskedPolAnalysis == 1)
		//Use masked Polarization Analysis data
		WAVE /D POL_C = $(StackFolder+":POL_Masked")
	else
		WAVE /D POL_C = $(StackFolder+":POL_Cprime")
		// check for use of old name POL_Analysis, and update to POL_Cprime
		if (!WaveExists(POL_C))
			Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
			Wave /D POL_C = $(StackFolder+":POL_Cprime")
			Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
			Duplicate /O POL_Analysis, POL_C
			KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
		endif
	endif
	
	save POL_C
End

Function CreateSlices()
	//Get ROI Positions from SVD Folder
	NVAR X1 	= root:SPHINX:SVD:gSVDLeft
	NVAR X2 	= root:SPHINX:SVD:gSVDRight
	NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
	NVAR Y2 	= root:SPHINX:SVD:gSVDTop

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]

	//Set ROI X positions
	X1=0
	X2=NumData[0]

	Variable i

	for (i = 0; i < numSlices; i+= 1)
		//Set new ROI y positions
		Y1 = floor(i * (NumData[1] / numSlices))
		Y2 = floor(i * (NumData[1] / numSlices) + (NumData[1] / numSlices))

		ExtractROI()

		Duplicate /O root:SPHINX:Stacks:POL_extract, $("root:SPHINX:Stacks:POL_Cprime_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_B_extract, $("root:SPHINX:Stacks:POL_B_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_D_extract, $("root:SPHINX:Stacks:POL_D_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_Theta_extract, $("root:SPHINX:Stacks:POL_ThetaPrime_slice_"+num2str(i))

//			String filename = "POL_Ext_"+num2str(i)
//			DisplaySPHINXImage(filename)
			// Reset the histogram to -90 through 90 (otherwise this displays poorly)
			NVAR gImageMin = $("root:SPHINX:POL_extract:gImageMin")
			NVAR gImageMax = $("root:SPHINX:POL_extract:gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:POL_extract:gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:POL_extract:gHistAxisMax")
			gImageMin = -90
			gImageMax = 90
			gHistAxisMin = -90
			gHistAxisMax = 90
			ApplyStackContrast("StackPOL_extract")
	endfor

	SetSliceCutOff()
	CollectSlices()

End

Function Slice242()
	//Get ROI Positions from SVD Folder
	NVAR X1 	= root:SPHINX:SVD:gSVDLeft
	NVAR X2 	= root:SPHINX:SVD:gSVDRight
	NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
	NVAR Y2 	= root:SPHINX:SVD:gSVDTop

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	numSlices = 6

	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]

	//Set ROI X positions
	X1=0
	X2=NumData[0]

	Variable i

	for (i = 0; i < numSlices; i+= 1)
		//Set new ROI y positions

		if (i == 0)
			Y1 = 0
			Y2 = floor(NumData[1] / 10)
		elseif (i == 5)
			Y1 = floor(NumData[1] / 10 + 4 * NumData[1] / 5)
			Y2 = NumData[1]
		else
			Y1 = floor(NumData[1] / 10 + (i - 1) * NumData[1] / 5)
			Y2 = floor(NumData[1] / 10 + i * NumData[1] / 5)
		endif

		ExtractROI()

		Duplicate /O root:SPHINX:Stacks:POL_extract, $("root:SPHINX:Stacks:POL_Cprime_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_B_extract, $("root:SPHINX:Stacks:POL_B_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_D_extract, $("root:SPHINX:Stacks:POL_D_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_Theta_extract, $("root:SPHINX:Stacks:POL_ThetaPrime_slice_"+num2str(i))

		// Reset the histogram to -90 through 90 (otherwise this displays poorly)
			NVAR gImageMin = $("root:SPHINX:POL_extract:gImageMin")
			NVAR gImageMax = $("root:SPHINX:POL_extract:gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:POL_extract:gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:POL_extract:gHistAxisMax")
			gImageMin = -90
			gImageMax = 90
			gHistAxisMin = -90
			gHistAxisMax = 90
			ApplyStackContrast("StackPOL_extract")
	endfor


	SetSliceCutoff242()
	CollectSlices()

End

Function Slice343()
	//Get ROI Positions from SVD Folder
	NVAR X1 	= root:SPHINX:SVD:gSVDLeft
	NVAR X2 	= root:SPHINX:SVD:gSVDRight
	NVAR Y1 	= root:SPHINX:SVD:gSVDBottom
	NVAR Y2 	= root:SPHINX:SVD:gSVDTop

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	numSlices = 6

	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]

	//Set ROI X positions
	X1=0
	X2=NumData[0]

	Variable i

	for (i = 0; i < numSlices; i+= 1)
		//Set new ROI y positions

		if (i == 0)
			Y1 = 0
			Y2 = 142
		elseif (i == 5)
			Y1 = 142 + 4 * 192
			Y2 = NumData[1]
		else
			Y1 = 143 + (i - 1) * 192
			Y2 = 142 + i * 192
		endif

		ExtractROI()

		Duplicate /O root:SPHINX:Stacks:POL_extract, $("root:SPHINX:Stacks:POL_Cprime_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_B_extract, $("root:SPHINX:Stacks:POL_B_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_D_extract, $("root:SPHINX:Stacks:POL_D_slice_"+num2str(i))
		Duplicate /O root:SPHINX:Stacks:POL_Theta_extract, $("root:SPHINX:Stacks:POL_ThetaPrime_slice_"+num2str(i))

		// Reset the histogram to -90 through 90 (otherwise this displays poorly)
			NVAR gImageMin = $("root:SPHINX:POL_extract:gImageMin")
			NVAR gImageMax = $("root:SPHINX:POL_extract:gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:POL_extract:gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:POL_extract:gHistAxisMax")
			gImageMin = -90
			gImageMax = 90
			gHistAxisMin = -90
			gHistAxisMax = 90
			ApplyStackContrast("StackPOL_extract")
	endfor


	SetSliceCutoff343()
	CollectSlices()

End

Function CollectSlices()
	Variable i
	Variable difference

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	String output = ""

	for (i = 0; i < numSlices; i += 1)
		String filename = "POL_Cprime_slice_"+num2str(i)
		// Find histogram limits
		NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
		NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
		difference = gImageMax - gImageMin
		print "slice " + num2str(i) + ":"
		print "angle spread (c'):\t\t" + num2str(difference) + "\r\r"
		output = output + "\r" + num2str(difference)
	endfor

	print output
End

Function SetSliceCutOff()

	Variable i

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	for (i = 0; i < numSlices; i += 1)

		// set cutoffs for POL_C
			String filename = "POL_Cprime_slice_"+num2str(i)
			WAVE POL_Ext = $("root:SPHINX:Stacks:"+filename)

			DisplaySPHINXImage(filename)

			NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:"+filename+":gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:"+filename+":gHistAxisMax")

			ImageHistogram /I POL_Ext
			WAVE W_ImageHist

			Variable MinStackHist, MaxStackHist
			Variable HardCutOff = 100

			// Determine the cut-off values from the global variables.

//			FindLevel /Q/EDGE=1/R=(gImageMin,gImageMax) W_ImageHist, HardCutOff
			FindLevel /Q/EDGE=1/R=(-90,90) W_ImageHist, HardCutOff
			MinStackHist 	= V_LevelX

//			FindLevel /Q/EDGE=2/R=(gImageMax,MinStackHist) W_ImageHist, HardCutOff
			FindLevel /Q/EDGE=2/R=(90,MinStackHist) W_ImageHist, HardCutOff
			MaxStackHist 	= V_LevelX

			gImageMin = MinStackHist
			gImageMax = MaxStackHist
			gHistAxisMin = MinStackHist
			gHistAxisMax = MaxStackHist
			DisplaySPHINXImage(filename)

	endfor
End

Function SetSliceCutOff242()

	Variable i

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	for (i = 0; i < numSlices; i += 1)

		// set cutoffs for POL_C
			String filename = "POL_Cprime_slice_"+num2str(i)
			WAVE POL_Ext = $("root:SPHINX:Stacks:"+filename)

			DisplaySPHINXImage(filename)

			NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:"+filename+":gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:"+filename+":gHistAxisMax")

			ImageHistogram /I POL_Ext
			WAVE W_ImageHist

			Variable MinStackHist, MaxStackHist
			Variable HardCutOff
			if (i == 0 || i == 5)
				HardCutOff = 50
			else
				HardCutOff = 100
			endif

			// Determine the cut-off values from the global variables.

			FindLevel /Q/EDGE=1/R=(-90,90) W_ImageHist, HardCutOff
			MinStackHist 	= V_LevelX

			FindLevel /Q/EDGE=2/R=(90,MinStackHist) W_ImageHist, HardCutOff
			MaxStackHist 	= V_LevelX

			gImageMin = MinStackHist
			gImageMax = MaxStackHist
			gHistAxisMin = MinStackHist
			gHistAxisMax = MaxStackHist
			DisplaySPHINXImage(filename)

	endfor
End

Function SetSliceCutOff343()

	Variable i

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	for (i = 0; i < numSlices; i += 1)

		// set cutoffs for POL_C
			String filename = "POL_Cprime_slice_"+num2str(i)
			WAVE POL_Ext = $("root:SPHINX:Stacks:"+filename)

			DisplaySPHINXImage(filename)

			NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:"+filename+":gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:"+filename+":gHistAxisMax")

			ImageHistogram /I POL_Ext
			WAVE W_ImageHist

			Variable MinStackHist, MaxStackHist
			Variable HardCutOff
			if (i == 0 || i == 5)
				HardCutOff = 75
			else
				HardCutOff = 100
			endif

			// Determine the cut-off values from the global variables.

			FindLevel /Q/EDGE=1/R=(-90,90) W_ImageHist, HardCutOff
			MinStackHist 	= V_LevelX

			FindLevel /Q/EDGE=2/R=(90,MinStackHist) W_ImageHist, HardCutOff
			MaxStackHist 	= V_LevelX

			gImageMin = MinStackHist
			gImageMax = MaxStackHist
			gHistAxisMin = MinStackHist
			gHistAxisMax = MaxStackHist
			DisplaySPHINXImage(filename)

	endfor
End

Function CollectSlicesAll()
	Variable i
	Variable difference

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	for (i = 0; i < numSlices; i += 1)

		String filename = "POL_Cprime_slice_"+num2str(i)
		// Find histogram limits
		NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
		NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
		difference = gImageMax - gImageMin
		print "slice " + num2str(i) + ":"
		print "angle spread (c'):\t\t" + num2str(difference)

		filename = "POL_ThetaPrime_slice_"+num2str(i)
		// Find histogram limits
		NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
		NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
		NVAR MaxDvalue = $("root:POLARIZATION:Analysis:MaxDvalue")
		difference = gImageMax - gImageMin
		print "angle spread (theta'):\t\t" + num2str(difference) + "\t\t(assuming max d = " + num2str(MaxDvalue) + ")"

		filename = "POL_B_slice_"+num2str(i)
		// Find histogram limits
		NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
		NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
		difference = gImageMax - gImageMin
		print "spread in b:\t\t\t\t" + num2str(difference)

		filename = "POL_D_slice_"+num2str(i)
		// Find histogram limits
		NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
		NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
		difference = gImageMax - gImageMin
		print "spread in d:\t\t\t\t" + num2str(difference) + "\r\r"

	endfor
End

Function SetSliceCutOffAll()

	Variable i

	MakeVariableIfNeeded("root:POLARIZATION:Analysis:numSlices",5)
	NVAR numSlices = $("root:POLARIZATION:Analysis:numSlices")

	for (i = 0; i < numSlices; i += 1)

		// set cutoffs for POL_C
			String filename = "POL_Cprime_slice_"+num2str(i)
			WAVE POL_Ext = $("root:SPHINX:Stacks:"+filename)

			DisplaySPHINXImage(filename)

			NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:"+filename+":gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:"+filename+":gHistAxisMax")

			ImageHistogram /I POL_Ext
			WAVE W_ImageHist

			Variable MinStackHist, MaxStackHist
			Variable HardCutOff = 100

			// Determine the cut-off values from the global variables.

			FindLevel /Q/EDGE=1/R=(gImageMin,gImageMax) W_ImageHist, HardCutOff
			MinStackHist 	= V_LevelX

			FindLevel /Q/EDGE=2/R=(gImageMax,MinStackHist) W_ImageHist, HardCutOff
			MaxStackHist 	= V_LevelX

			gImageMin = MinStackHist
			gImageMax = MaxStackHist
			gHistAxisMin = MinStackHist
			gHistAxisMax = MaxStackHist
			DisplaySPHINXImage(filename)

		// set cutoffs for POL_B
			filename = "POL_B_slice_"+num2str(i)
			WAVE POL_Ext = $("root:SPHINX:Stacks:"+filename)

			DisplaySPHINXImage(filename)

			NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:"+filename+":gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:"+filename+":gHistAxisMax")

			ImageHistogram /I POL_Ext

			HardCutOff = 10

			// Determine the cut-off values from the global variables.

			FindLevel /Q/EDGE=1/R=(gImageMin,gImageMax) W_ImageHist, HardCutOff
			MinStackHist 	= V_LevelX

			FindLevel /Q/EDGE=2/R=(gImageMax,MinStackHist) W_ImageHist, HardCutOff
			MaxStackHist 	= V_LevelX

			gImageMin = MinStackHist
			gImageMax = MaxStackHist
			gHistAxisMin = MinStackHist
			gHistAxisMax = MaxStackHist
			DisplaySPHINXImage(filename)

		// set cutoffs for POL_D
			filename = "POL_D_slice_"+num2str(i)
			WAVE POL_Ext = $("root:SPHINX:Stacks:"+filename)

			DisplaySPHINXImage(filename)

			NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:"+filename+":gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:"+filename+":gHistAxisMax")

			ImageHistogram /I POL_Ext

			HardCutOff = 10

			// Determine the cut-off values from the global variables.

			FindLevel /Q/EDGE=1/R=(gImageMin,gImageMax) W_ImageHist, HardCutOff
			MinStackHist 	= V_LevelX

			FindLevel /Q/EDGE=2/R=(gImageMax,MinStackHist) W_ImageHist, HardCutOff
			MaxStackHist 	= V_LevelX

			gImageMin = MinStackHist
			gImageMax = MaxStackHist
			gHistAxisMin = MinStackHist
			gHistAxisMax = MaxStackHist
			DisplaySPHINXImage(filename)

		// set cutoffs for POL_Theta
			filename = "POL_ThetaPrime_slice_"+num2str(i)
			WAVE POL_Ext = $("root:SPHINX:Stacks:"+filename)

			DisplaySPHINXImage(filename)

			NVAR gImageMin = $("root:SPHINX:"+filename+":gImageMin")
			NVAR gImageMax = $("root:SPHINX:"+filename+":gImageMax")
			NVAR gHistAxisMin = $("root:SPHINX:"+filename+":gHistAxisMin")
			NVAR gHistAxisMax = $("root:SPHINX:"+filename+":gHistAxisMax")

			ImageHistogram /I POL_Ext

			HardCutOff = 10

			// Determine the cut-off values from the global variables.

//			FindLevel /Q/EDGE=1/R=(gImageMin,gImageMax) W_ImageHist, HardCutOff
			FindLevel /Q/EDGE=1/R=(-90,90) W_ImageHist, HardCutOff
			MinStackHist 	= V_LevelX

//			FindLevel /Q/EDGE=2/R=(gImageMax,MinStackHist) W_ImageHist, HardCutOff
			FindLevel /Q/EDGE=2/R=(90,MinStackHist) W_ImageHist, HardCutOff
			MaxStackHist 	= V_LevelX

			gImageMin = MinStackHist
			gImageMax = MaxStackHist
			gHistAxisMin = MinStackHist
			gHistAxisMax = MaxStackHist
			DisplaySPHINXImage(filename)

	endfor
End

Function HSLtoRGB(UseMask)
	Variable UseMask

	SetDataFolder root:POLARIZATION:Analysis

	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	String PanelFolder = "root:POLARIZATION:Analysis"
	Wave NumData = $("root:POLARIZATION:NumData")

	WAVE /D POL_C = $(StackFolder+":POL_Cprime")

	// check for use of old name POL_Analysis, and update to POL_Cprime
	if (!WaveExists(POL_C) && exists("root:SPHINX:Stacks:POL_Analysis") != 0)
		Wave /D POL_Analysis = $(StackFolder+":POL_Analysis")
		Wave /D POL_C = $(StackFolder+":POL_Cprime")
		Make /O/N=(DimSize(POL_Analysis, 0), DimSize(POL_Analysis, 1))/D $(StackFolder+":POL_Cprime") /WAVE=POL_C
		Duplicate /O POL_Analysis, POL_C
		KillWaves /Z POL_Analysis	// suppress error if POL_Analysis cannot be deleted because it's open
	endif

	if (exists(StackFolder+":POL_Cprime") == 0)
		Print " *** You must analyze an ROI first!"
		return 0
	endif

	NVAR HSLtoRGB_level = $(PanelFolder+":HSLtoRGB_level")
	MakeVariableIfNeeded(PanelFolder+":MaxDvalue",-10)
	MakeVariableIfNeeded(PanelFolder+":MinDvalue",-10)
	MakeVariableIfNeeded(PanelFolder+":MaxDvalue_vat",10)
	MakeVariableIfNeeded(PanelFolder+":MinDvalue_vat",10)
	MakeVariableIfNeeded(PanelFolder+":MaxBvalue",-10)
	MakeVariableIfNeeded(PanelFolder+":MinBvalue",-10)
	MakeVariableIfNeeded(PanelFolder+":MaxBvalue_vat",10)
	MakeVariableIfNeeded(PanelFolder+":MinBvalue_vat",10)
	MakeVariableIfNeeded(PanelFolder+":MaxAngle",-200)
	MakeVariableIfNeeded(PanelFolder+":MinAngle",-200)
	MakeVariableIfNeeded(PanelFolder+":MaxColorAngle",-100)
	MakeVariableIfNeeded(PanelFolder+":MinColorAngle",-100)
	MakeVariableIfNeeded(PanelFolder+":MaxColor",-100)
	MakeVariableIfNeeded(PanelFolder+":MinColor",-100)
	MakeVariableIfNeeded(PanelFolder+":blackCutoff",0)
	MakeVariableIfNeeded(PanelFolder+":whiteCutoff",0)
	MakeVariableIfNeeded(PanelFolder+":hueCutoff",0)
	MakeVariableIfNeeded(PanelFolder+":hueCutoffColorValue",0)
	NVAR MaxDvalue = $(PanelFolder+":MaxDvalue")
	NVAR MinDvalue = $(PanelFolder+":MinDvalue")
	NVAR MaxDvalue_vat = $(PanelFolder+":MaxDvalue_vat")
	NVAR MinDvalue_vat = $(PanelFolder+":MinDvalue_vat")
	NVAR MaxBvalue = $(PanelFolder+":MaxBvalue")
	NVAR MinBvalue = $(PanelFolder+":MinBvalue")
	NVAR MaxBvalue_vat = $(PanelFolder+":MaxBvalue_vat")
	NVAR MinBvalue_vat = $(PanelFolder+":MinBvalue_vat")
	NVAR MaxAngle = $(PanelFolder+":MaxAngle")			//  the angle (90 deg by default) that will be mapped to the maximum color (65535 by default)
	NVAR MinAngle = $(PanelFolder+":MinAngle")			//  the angle (-90 deg by default) that will be mapped to the minimum color (0 by default)
	NVAR MaxColorAngle = $(PanelFolder+":MaxColorAngle")
	NVAR MinColorAngle = $(PanelFolder+":MinColorAngle")
	NVAR MaxColor = $(PanelFolder+":MaxColor")			// the maximum color value used (65535 by default)
	NVAR MinColor = $(PanelFolder+":MinColor")			// the minimum color value used (0 by default)
	NVAR blackCutoff = $(PanelFolder+":blackCutoff")
	NVAR whiteCutoff = $(PanelFolder+":whiteCutoff")
	NVAR hueCutoff = $(PanelFolder+":hueCutoff")
	NVAR hueCutoffColorValue = $(PanelFolder+":hueCutoffColorValue")
//	NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint
	Variable i, j, k, l, m

	MakeVariableIfNeeded("root:SPHINX:HSL2RGB:UseB",1)
	NVAR UseB = $("root:SPHINX:HSL2RGB:UseB")
	MakeVariableIfNeeded("root:SPHINX:HSL2RGB:IsVaterite",0)
	NVAR IsVaterite = $("root:SPHINX:HSL2RGB:IsVaterite")
	MakeVariableIfNeeded("root:SPHINX:HSL2RGB:SampleCenteredCoords",0)
	NVAR SampleCenteredCoords = $("root:SPHINX:HSL2RGB:SampleCenteredCoords")

	// begin creating the filename for export
	MakeStringIfNeeded("root:SPHINX:Browser:gFinalWaveName","POL_RGB")
	SVAR gFinalWaveName = root:SPHINX:Browser:gFinalWaveName
//	gFinalWaveName = "POL_RGB"
	gFinalWaveName = "PIC"
	if (UseMask != 0)
//		gFinalWaveName = gFinalWaveName + "_Mask"
	endif
	gFinalWaveName = StackName + "_" + gFinalWaveName
//	gFinalWaveName = gFinalWaveName+"_Ang_"

	// Assign waves
		WAVE /D POL_HSL = $(StackFolder+":POL_HSL")
		WAVE /D POLmasked = $(StackFolder+":POL_Masked")
		WAVE /D POL_A = $(StackFolder+":POL_A")
		WAVE /D POL_B = $(StackFolder+":POL_B")
		WAVE /D POL_D = $(StackFolder+":POL_D")
		WAVE /D POL_Theta = $(StackFolder+":POL_Theta")
		WAVE /D COLORBAR_HSL = $(StackFolder+":COLORBAR_HSL")
		
		// BG 
		WAVE /D POL_Rpol = $(StackFolder+":POL_Rpol")
		WAVE /D POL_Phi2 = $(StackFolder+":POL_Phi2")
		WAVE /D POL_Thet2 = $(StackFolder+":POL_Thet2")

	// Assign and make vaterite waves if needed
		WAVE /D POL_A_vat = $(StackFolder+":POL_A_vat")
		WAVE /D POL_B_vat = $(StackFolder+":POL_B_vat")
		WAVE /D POL_C_vat = $(StackFolder+":POL_C_vat")
		WAVE /D POL_D_vat = $(StackFolder+":POL_D_vat")

		WAVE /D POL_Theta_vat = $(StackFolder+":POL_Theta_vat")

		if (!WaveExists(POL_C_vat))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_A_vat") /WAVE=POL_A_vat
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_B_vat") /WAVE=POL_B_vat
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_C_vat") /WAVE=POL_C_vat
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_D_vat") /WAVE=POL_D_vat
			POL_A_vat[][] = POL_A[p][q] + POL_B[p][q]
			POL_B_vat[][] = -POL_B[p][q]
			POL_C_vat[][] = POL_C[p][q] + 90
			POL_C_vat[][] = (POL_C_vat[p][q] > 90) ? (POL_C_vat[p][q] - 180) : POL_C_vat[p][q]
			POL_D_vat[][] = POL_B_vat[p][q] / POL_A_vat[p][q]
		endif

	// Make D wave if needed
		if (!WaveExists(POL_D))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_D") /WAVE=POL_D
			POL_D[][] = (POL_A[p][q] == 0) ? NaN : (POL_B[p][q] / POL_A[p][q])
		endif

	// Make Theta Wave if needed
		if (!WaveExists(POL_Theta))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Theta") /WAVE=POL_Theta
			POL_Theta = NaN
		endif
		if (!WaveExists(POL_Theta_vat))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Theta_vat") /WAVE=POL_Theta_vat
			POL_Theta_vat = NaN
		endif

	// Make 3D Color Waves if needed
		if (!WaveExists(POL_HSL))	// BG: Why does POL_HSL have 3 Layers? 
			Make /O/N=(NumData[0],NumData[1]+256,3)/D $(StackFolder+":POL_HSL") /WAVE=POL_HSL		// Extra 256 for 2D color bar
		endif

		if (!WaveExists(COLORBAR_HSL))
			Make /O/N=(360,1,3)/D $(StackFolder+":COLORBAR_HSL") /WAVE=COLORBAR_HSL
		endif

		if (HSLtoRGB_level < 0)
			HSLtoRGB_level = 0
		elseif (HSLtoRGB_level > 1)
			HSLtoRGB_level = 1
		endif

		if (MaxAngle < -90)
			MaxAngle = 90
			MinAngle = -90
		endif

		if (MaxColorAngle == MinColorAngle)
			MaxColorAngle = 360
			MinColorAngle = 0
		endif
		if (MinColorAngle < -360)
			MinColorAngle = -360
		endif
		if (MaxColorAngle > 360)
			MaxColorAngle = 360
		endif
		if (MaxColorAngle - MinColorAngle > 360)
			MinColorAngle = MaxColorAngle - 360
		endif
		if (MaxColorAngle <= 0)
			MinColorAngle += 360
			MaxColorAngle += 360
		endif

		// for default MinColorAngle and MaxColorAngle values of 0 and 360, MinColor and MaxColor will be 0 and 65535 (full color range), respectively
		MaxColor = MaxColorAngle * 65535 / 360
		MinColor = MinColorAngle * 65535 / 360

		// make filename based on parameters
		if (MinAngle < 0)
//			gFinalWaveName = gFinalWaveName+"m"+num2Str(-MinAngle)
		else
//			gFinalWaveName = gFinalWaveName+"p"+num2Str(MinAngle)
		endif

		if (MaxAngle < 0)
//			gFinalWaveName = gFinalWaveName+"m"+num2Str(-MaxAngle)
		else
//			gFinalWaveName = gFinalWaveName+"p"+num2Str(MaxAngle)
		endif
//		gFinalWaveName = gFinalWaveName + "_SclBr_" + num2Str(MinColorAngle) + "_" + num2Str(MaxColorAngle)

		if (HSLtoRGB_level == 0)
//			gFinalWaveName = gFinalWaveName+"_BrghtB"
		elseif (HSLtoRGB_level == 1)
//			gFinalWaveName = gFinalWaveName+"_BrghtW"
		else
//			gFinalWaveName = gFinalWaveName+"_SatG"
		endif

		// the HSL values are expected to be between 0 and 65535. The output RGB values are in the range 0 to 65535.
		// POL_C varies from -90->90. Shift to 0 to 65535
//		POL_HSL[][][0] = (POL_C[p][q] + 90)*(65535/180)


		// POL_C varies from -90->90. Users select what angles of this range to use, and what range of colors to use
		// the min angle is set to the min color, and the max angle is set to the max color
//		POL_HSL[][][0] = MinColor+(POL_C[p][q] - MinAngle)*(MaxColor-MinColor)/(MaxAngle-MinAngle)
//		POL_HSL[][][0] = (POL_HSL[p][q][0] < MinColor) ? (MinColor) : POL_HSL[p][q][0]
//		POL_HSL[][][0] = (POL_HSL[p][q][0] > MaxColor) ? (MaxColor) : POL_HSL[p][q][0]

		// use POL_D for brightness, unless the UseB flag is true
		if (MaxDvalue == MinDvalue)
			MaxDvalue = WaveMax(POL_D)
			MinDvalue = 0
		endif
		if (MaxDvalue_vat == MinDvalue_vat)
			MaxDvalue_vat = 0
			MinDvalue_vat = WaveMin(POL_D_vat)
		endif
		if (MaxBvalue == MinBvalue)
			MaxBvalue = WaveMax(POL_B)
			MinBvalue = 0
		endif
		if (MaxBvalue_vat == MinBvalue_vat)
			MaxBvalue_vat = 0
			MinBvalue_vat = WaveMin(POL_B_vat)
		endif
		
		// The seeks to calculate the angles in the Sample Plane
		CalculateRotation()

		// assign sample-centered waves
		WAVE /D POL_C_SampCen = $(StackFolder+":POL_C_SampCen")
		WAVE /D POL_Theta_SampCen = $(StackFolder+":POL_Theta_SampCen")
		WAVE /D POL_C_vat_SampCen = $(StackFolder+":POL_C_vat_SampCen")
		WAVE /D POL_Theta_vat_SampCen = $(StackFolder+":POL_Theta_vat_SampCen")

		if (IsVaterite != 0)
			// vaterite
			if (UseB == 1)
				// use B
				gFinalWaveName = gFinalWaveName+"_minB_m" + num2str(-MinBvalue_vat)
			else
				// use D
				gFinalWaveName = gFinalWaveName+"_minD_m" + num2str(-MinDvalue_vat)
			endif
		else
			// not vaterite
			if (UseB == 1)
				// use B
				gFinalWaveName = gFinalWaveName+"_maxB_" + num2str(MaxBvalue)
			else
				// use D
				gFinalWaveName = gFinalWaveName+"_maxD_" + num2str(MaxDvalue)
			endif
		endif

		gFinalWaveName = ReplaceString(".",gFinalWaveName,"p")

		if (WaveExists(C_wave))
			KillWaves C_Wave
		endif
		if (WaveExists(Theta_wave))
			KillWaves Theta_Wave
		endif

		if (SampleCenteredCoords == 1)
			// sample centered coordinates
			if (IsVaterite == 1)
				// sample centered + vaterite
				if (!WaveExists(POL_C_vat_SampCen))
					print "error: POL_C_vat_SampCen does not exist"
					return 0
				endif
				if (!WaveExists(POL_Theta_vat_SampCen))
					print "error: POL_Theta_vat_SampCen does not exist"
					return 0
				endif
				Duplicate POL_C_vat_SampCen, C_wave
				Duplicate POL_Theta_vat_SampCen, Theta_wave
			else
				// sample centered, not vaterite
				if (!WaveExists(POL_C_SampCen))
					print "error: POL_C_SampCen does not exist"
					return 0
				endif
				if (!WaveExists(POL_Theta_SampCen))
					print "error: POL_Theta_SampCen does not exist"
					return 0
				endif
				Duplicate POL_C_SampCen, C_wave
				Duplicate POL_Theta_SampCen, Theta_wave
			endif
		elseif (IsVaterite == 1)
			// vaterite
			if (!WaveExists(POL_C_vat))
				print "error: POL_C_vat does not exist"
				return 0
			endif
			if (!WaveExists(POL_Theta_vat))
				print "error: POL_Theta_vat does not exist"
				return 0
			endif
			Duplicate POL_C_vat, C_wave
			Duplicate POL_Theta_vat, Theta_wave
		elseif (UseMask == 1)
			// use a mask
			if (exists("root:SPHINX:Stacks:POL_Masked") == 0)
				Print " *** You must create a masked image first!"
				return 0
			endif
			Duplicate POLmasked, C_wave
			Duplicate POL_Theta, Theta_wave
		else
			// use normal PIC-map and theta map
			if (!WaveExists(POL_C))
				print "error: POL_C does not exist"
				return 0
			endif
			if (!WaveExists(POL_Theta))
				print "error: POL_Theta does not exist"
				return 0
			endif
			Duplicate POL_C, C_wave
			Duplicate POL_Theta, Theta_wave
		endif
		
		Variable BGFlag = 0
		
		if (HSLtoRGB_level == 0 || HSLtoRGB_level == 1) // do everything in black (0) or white (1)

			// use full saturation everywhere -- off-plane angle indicated by lightness/brightness
			POL_HSL[][][1] = 65535
			
			if (HSLtoRGB_level == 0) // black
//				POL_HSL[][][2] = (POL_B[p][q]/POL_A[p][q]-MinDvalue)*((65535/2)/(MaxDvalue-MinDvalue))  //Scale D. 0 means black, 65535/2 means bright color.
//				POL_HSL[][][2] = (POL_D[p][q]-MinDvalue)*((65535/2)/(MaxDvalue-MinDvalue))  //Scale D. 0 means black, 65535/2 means bright color.

				if (UseB == 0)
					// use D instead of B
					if (BGFlag)
						print "hjere"
//						POL_HSL = 10000
//						POL_HSL[][][2] = (POL_Thet2[p][q]/90) * (65535/2) 
						POL_HSL[][][2] = cos((pi/180)*POL_Thet2[p][q])^2 * (65535/2) 
					else
						POL_HSL[][][2] = (Theta_wave[p][q] >= 0) ? ((cos(pi * Theta_wave[p][q] / 180))^2) * 65535 / 2 : 65535 - ((cos(pi * Theta_wave[p][q] / 180))^2) * 65535 / 2				
	//					POL_HSL[][][2] =((cos(pi * Theta_wave[p][q] / 180))^2) * 65535 / 2							// Scale Theta from 0-90 to 65535/2-0. 0 means black, 65535/2 means bright color.
					endif
				else
					// use b instead of d
					if (IsVaterite != 0)
						// vaterite
						POL_HSL[][][2] = (POL_B_vat[p][q] - MaxBvalue_vat) * ((65535 / 2) / (MinBvalue_vat - MaxBvalue_vat))
					else
						// not vaterite
						POL_HSL[][][2] = (POL_B[p][q] - MinBvalue) * ((65535 / 2) / (MaxBvalue - MinBvalue))
					endif
				endif

				POL_HSL[][][2] = (POL_HSL[p][q][2] < 0) ? (0) : POL_HSL[p][q][2]
//				POL_HSL[][][2] = (POL_HSL[p][q][2] > 65535/2) ? (65535/2) : POL_HSL[p][q][2]

			else // white
//				POL_HSL[][][2] = 65535-(POL_D[p][q]-MinDvalue)*((65535/2)/(MaxDvalue-MinDvalue))  // Scale D. 65535 means white, 65535/2 means bright color

				if (UseB == 0)
					// use D instead of B
					POL_HSL[][][2] = 65535 - ((cos(pi * Theta_wave[p][q] / 180))^2) * 65535 / 2  // Scale Theta from 0-90 to 65535/2-65535. 65535 means white, 65535/2 means bright color
				else
					if (IsVaterite != 0)
						// vaterite
						POL_HSL[][][2] = 65535 - (POL_B_vat[p][q] - MaxBvalue_vat) * ((65535 / 2) / (MinBvalue_vat - MaxBvalue_vat))	// Scale B. 65535 means white, 65535/2 means bright color
					else
						// not vaterite
						POL_HSL[][][2] = 65535 - (POL_B[p][q] - MinBvalue) * ((65535 / 2) / (MaxBvalue - MinBvalue))					// Scale B. 65535 means white, 65535/2 means bright color
					endif
				endif
				POL_HSL[][][2] = (POL_HSL[p][q][2] < 65535/2) ? (65535/2) : POL_HSL[p][q][2]
				POL_HSL[][][2] = (POL_HSL[p][q][2] > 65535) ? (65535) : POL_HSL[p][q][2]
			endif
			
			// set appropriate cutoff hue/brightness
			if (blackCutoff) // all values outside the angle range are black		
				
				if (MinAngle < MaxAngle) // normal case

					POL_HSL[][][0] = MinColor + (C_wave[p][q] - MinAngle) * (MaxColor - MinColor) / (MaxAngle - MinAngle)
					POL_HSL[][][2] = (POL_HSL[p][q][0] < MinColor) ? 0 : POL_HSL[p][q][2]
					POL_HSL[][][2] = (POL_HSL[p][q][0] > MaxColor) ? 0 : POL_HSL[p][q][2]

				else // wrap-around
					for (i = 0; i <= NumData[0]; i += 1)
						for (j = 0; j <= NumData[1]; j += 1)
							if (C_wave[i][j] >= MinAngle)
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * (C_wave[i][j] - MinAngle) / (180 - (MinAngle - MaxAngle))
							elseif (C_wave[i][j] <= MaxAngle)
								// !*!*!* Ambiguous point number fix - may be incorrect
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave[i][j] + 90) / (MaxAngle + 90))
//								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave + 90) / (MaxAngle + 90))
							else
								POL_HSL[i][j][0] = MinColor // the value here doesn't matter; it will appear completely black
								POL_HSL[i][j][2] = 0
							endif							
						endfor
					endfor
					
				endif

				POL_HSL[][][0] = (POL_HSL[p][q][0] < MinColor) ? (MinColor) : POL_HSL[p][q][0]
				POL_HSL[][][0] = (POL_HSL[p][q][0] > MaxColor) ? (MaxColor) : POL_HSL[p][q][0]
				

			elseif (whiteCutoff) // all values outside the angle range are white

				if (MinAngle < MaxAngle) // normal case

					POL_HSL[][][0] = MinColor + (C_wave[p][q] - MinAngle) * (MaxColor - MinColor) / (MaxAngle - MinAngle)
					POL_HSL[][][2] = (POL_HSL[p][q][0] < MinColor) ? 65535 : POL_HSL[p][q][2]
					POL_HSL[][][2] = (POL_HSL[p][q][0] > MaxColor) ? 65535 : POL_HSL[p][q][2]

				else // wrap-around
					for (i = 0; i <= NumData[0]; i += 1)
						for (j = 0; j <= NumData[1]; j += 1)
							if (C_wave[i][j] >= MinAngle)
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * (C_wave[i][j] - MinAngle) / (180 - (MinAngle - MaxAngle))
							elseif (C_wave[i][j] <= MaxAngle)
								// !*!*!* Ambiguous point number fix - may be incorrect
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave[i][j] + 90) / (MaxAngle + 90))
//								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave + 90) / (MaxAngle + 90))
							else
								POL_HSL[i][j][0] = MinColor // the value here doesn't matter; it will appear completely white
								POL_HSL[i][j][2] = 65535
							endif							
						endfor
					endfor
					
				endif

				POL_HSL[][][0] = (POL_HSL[p][q][0] < MinColor) ? (MinColor) : POL_HSL[p][q][0]
				POL_HSL[][][0] = (POL_HSL[p][q][0] > MaxColor) ? (MaxColor) : POL_HSL[p][q][0]
				
			elseif (hueCutoff) // all values outside the angle range use the specified hue

				if (MinAngle < MaxAngle) // normal case

					POL_HSL[][][0] = MinColor + (C_wave[p][q] - MinAngle) * (MaxColor - MinColor) / (MaxAngle - MinAngle)
					POL_HSL[][][0] = (POL_HSL[p][q][0] < MinColor) ? (hueCutoffColorValue * 65535 / 360) : POL_HSL[p][q][0]
					POL_HSL[][][0] = (POL_HSL[p][q][0] > MaxColor) ? (hueCutoffColorValue * 65535 / 360) : POL_HSL[p][q][0]

				else // wrap-around

					for (i = 0; i <= NumData[0]; i += 1)
						for (j = 0; j <= NumData[1]; j += 1)
							if (C_wave[i][j] >= MinAngle)
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * (C_wave[i][j] - MinAngle) / (180 - (MinAngle - MaxAngle))
							elseif (C_wave[i][j] <= MaxAngle)
								// !*!*!* Ambiguous point number fix - may be incorrect
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave[i][j] + 90) / (MaxAngle + 90))
//								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave + 90) / (MaxAngle + 90))
							else
								POL_HSL[i][j][0] = hueCutoffColorValue * 65535 / 360
							endif
						endfor
					endfor
					
				endif

			else // values outside the angle range get mapped to the min or max color (default, if no boxes are checked)

				if (MinAngle < MaxAngle) // normal case

					POL_HSL[][][0] = MinColor + (C_wave[p][q] - MinAngle) * (MaxColor - MinColor) / (MaxAngle-MinAngle)
					POL_HSL[][][0] = (POL_HSL[p][q][0] < MinColor) ? (MinColor) : POL_HSL[p][q][0]
					POL_HSL[][][0] = (POL_HSL[p][q][0] > MaxColor) ? (MaxColor) : POL_HSL[p][q][0]

				else // wrap-around
					for (i = 0; i < NumData[0]; i += 1)
						for (j = 0; j < NumData[1]; j += 1)
							if (C_wave[i][j] >= MinAngle)
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * (C_wave[i][j] - MinAngle) / (180 - (MinAngle - MaxAngle))
							elseif (C_wave[i][j] <= MaxAngle)
								// !*!*!* Ambiguous point number fix - may be incorrect
								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave[i][j] + 90) / (MaxAngle + 90))
//								POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * ((90 - MinAngle) / (180 - (MinAngle - MaxAngle)) + (1 - (90 - MinAngle) / (180 - (MinAngle - MaxAngle))) * (C_wave + 90) / (MaxAngle + 90))
							else
								if (MinAngle - C_wave[i][j] <= C_wave[i][j] - MaxAngle)
									POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * (90 - MinAngle) / (180 - (MinAngle - MaxAngle))
								else
									POL_HSL[i][j][0] = MinColor + (MaxColor - MinColor) * (90 - MaxAngle) / (180 - (MinAngle - MaxAngle))
								endif
							endif
						endfor
					endfor

				endif

			endif

			// 2D scalebar
			l = (MaxColor - MinColor) / (NumData[0] - 1)	// HUE factor (for computing scale bar)
			m = 65535 / 512			// brightness factor for computing scalebar
			for (i = 0; i < NumData[0]; i+= 1)
				for (j = NumData[1]; j < NumData[1] + 256; j += 1)
					k = j - NumData[1]		//Position in Y (for brightness ScaleBar)
					POL_HSL[i][j][0] = MinColor + i * l
					POL_HSL[i][j][1] = 65535
					if (HSLtoRGB_level == 0) // black
						POL_HSL[i][j][2] = k * m
					else // white
						POL_HSL[i][j][2] = 65535 - k * m
					endif
				endfor
			endfor

		else // use gray

			if (MinAngle < MaxAngle) // normal case
				POL_HSL[][][0] = MinColor + (C_wave[p][q] - MinAngle) * (MaxColor - MinColor) / (MaxAngle - MinAngle)
			else // wrap-around
				POL_HSL[][][0] = MinColor + (C_wave[p][q] - MinAngle) * (MaxColor - MinColor) / (MaxAngle - MinAngle)
			endif

			POL_HSL[][][0] = (POL_HSL[p][q][0] < MinColor) ? (MinColor) : POL_HSL[p][q][0]
			POL_HSL[][][0] = (POL_HSL[p][q][0] > MaxColor) ? (MaxColor) : POL_HSL[p][q][0]

//			POL_HSL[][][1] = (POL_D[p][q]-MinDvalue)*(65535/(MaxDvalue-MinDvalue))  //Scale D
			if (UseB == 0)
				// use D, not B
				POL_HSL[][][1] = ((cos(pi * Theta_wave[p][q] / 180))^2) * 65535					//Scale Theta from 0-90 to 65535-0
			else
				// use B
				if (IsVaterite != 0)
					// vaterite
					POL_HSL[][][1] = (POL_B_vat[p][q] - MaxBvalue_vat) * 65535 / (MinBvalue_vat - MaxBvalue_vat)
				else
					// not vaterite
					POL_HSL[][][1] = (POL_B[p][q] - MinBvalue) * 65535 / (MaxBvalue - MinBvalue)
				endif
			endif
			POL_HSL[][][1] = (POL_HSL[p][q][1] < 0) ? (0) : POL_HSL[p][q][1]
			POL_HSL[][][1] = (POL_HSL[p][q][1] > 65535) ? (65535) : POL_HSL[p][q][1]

			//HSLtoRGB_level is user set, between 0-1. Rescale to 0-65535
			POL_HSL[][][2] = HSLtoRGB_level*65535

			// 2D scalebar
			l = (MaxColor-MinColor)/(NumData[0]-1)	//HUE factor (for computing scale bar)
			m = 65535 / 256			//SATURATION factor (for computing scale bar)
			for (i = 0; i < NumData[0]; i += 1)
				for (j = NumData[1]; j < NumData[1] + 256; j += 1)
					k = j - NumData[1]		//Position in Y (for Saturation ScaleBar)
					POL_HSL[i][j][0] = MinColor + i * l
					POL_HSL[i][j][1] = k * m
				endfor
			endfor
			
		endif

		KillWaves C_wave, Theta_wave

		// adjust for negative colors
		POL_HSL[][][0] = (POL_HSL[p][q][0] < 0) ? (POL_HSL[p][q][0] + 65535) :  POL_HSL[p][q][0]

//		POL_HSL[][][1] = (POL_B[p][q]-MinBvalue)*(65535/(MaxBvalue-MinBvalue))  //Scale B
//		POL_HSL[][][1] = (POL_HSL[p][q][1] < 0) ? (0) : POL_HSL[p][q][1]
//		POL_HSL[][][1] = (POL_HSL[p][q][1] > 65535) ? (65535) : POL_HSL[p][q][1]
		
		//HSLtoRGB_level is user set, between 0-100. Rescale to 0 to 65535
		// POL_HSL[][][2] = HSLtoRGB_level*(65535/100)
		
		//Add a 2D scale bar to POL_HSL
//			l = 65535/(NumData[0]-1)	//HUE factor (for computing scale bar)
//			m = 65535/(50)			//SATURATION factor (for computing scale bar)
//		for (i=0;i<NumData[0];i+=1)
//			for (j=NumData[1];j<NumData[1]+50;j+=1)
//				k = j - NumData[1]		//Position in Y (for Saturation ScaleBar)
//				POL_HSL[i][j][0] = i*l
//				POL_HSL[i][j][1] = k*m
//			endfor
//		endfor

		// POL_HSL[][][2] = (POL_HSL[p][q][1])/2 // scale lightness according to B value
//		POL_HSL[][][2] = (HSLtoRGB_level < 0) ? (POL_HSL[p][q][1])/2 : ((HSLtoRGB_level > 100) ? (65535 - (POL_HSL[p][q][1])/2) : HSLtoRGB_level*(65535/100)) // scale lightness according to B value or level, depending on level. level < 0, use black. level > 100, use white. otherwise, use user-set level

		// Adjust HUE according to scale setpoint (allows rotation of color wheel -- our color wheel is 180 degrees)
//		POL_HSL[][][0] -= scaleSetPoint*(65535/180)

		// Adjust HUE according to scale setpoint (allows rotation of color wheel -- our color wheel is user-defined, so SetPt is a little confusing)
//		POL_HSL[][][0] -= scaleSetPoint*(65535/(MaxAngle-MinAngle))
//		POL_HSL[][][0] = (POL_HSL[p][q][0] < 0) ? (POL_HSL[p][q][0] + 65535) : POL_HSL[p][q][0]
//		POL_HSL[][][0] = (POL_HSL[p][q][0] > 65535) ? (POL_HSL[p][q][0] - 65535) : POL_HSL[p][q][0]


		// create the colorbar that shows the full range of hues and the corresponding numbers
		COLORBAR_HSL[][][1] = 65535	// full saturation
		COLORBAR_HSL[][][2] = 65535/2	// optimal brightness

		for (i = 0; i < 360; i += 1)
			COLORBAR_HSL[i][0][0] = (65535 * i) / (360 - 1)
		endfor

		SetDataFolder $(StackFolder) 
		ImageTransform hsl2rgb POL_HSL
		
		// duplicate the hue part of POL_HSL
//		if (WaveExists(root:SPHINX:Stacks:POL_HUE) == 1)
//			KillWaves POL_HUE
//		endif
//		Duplicate /R=[0,NumData[0]][0,NumData[1]][0,0] POL_HSL, POL_HUE
//		NewImage root:SPHINX:Stacks:POL_HUE
		
		//Cleanup
		if (WinType("HSL2RGB") == 7)
			KillWindow HSL2RGB
		endif
		if (WaveExists(root:SPHINX:Stacks:POL_RGB) == 1)
			KillWaves POL_RGB
		endif
		Duplicate M_HSL2RGB, POL_RGB
//		KillWaves POL_HSL, M_HSL2RGB  //BG Don't kill POL_HSL for the moment
		
		SetDataFolder $(StackFolder)
		ImageTransform hsl2rgb COLORBAR_HSL
		
		//Cleanup
		if (WaveExists(root:SPHINX:Stacks:COLORBAR_RGB) == 1)
			Killwaves COLORBAR_RGB
		endif
		Duplicate M_HSL2RGB, COLORBAR_RGB
		Killwaves COLORBAR_HSL, M_HSL2RGB
		
		//Display Image
		HSL2RGBDisplayPanel()
		
		//NewImage  root:SPHINX:Stacks:M_HSL2RGB
		//ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:M_HSL2RGB
End

Function /S HSL2RGBDisplayPanel()
	Wave Image = root:SPHINX:Stacks:POL_RGB
	Wave Colorbar = root:SPHINX:Stacks:COLORBAR_RGB
	String Title = "Color PIC-map Display Panel"
	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]

	String PanelFolder 	= "root:SPHINX:HSL2RGB"
	String PanelName 	= "HSL2RGB"
	String StackName	= NameOfWave(Image)

	MakeVariableIfNeeded(PanelFolder+":UseB",1)
	NVAR UseB = $(PanelFolder+":UseB")
	MakeVariableIfNeeded(PanelFolder+":IsVaterite",0)
	NVAR IsVaterite = $(PanelFolder+":IsVaterite")

	NewDataFolder /O/S $PanelFolder
	
		Duplicate /O Image, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
//		NewPanel /K=1/W=(6,44,440,520) as Title
//		NewPanel /K=1/W=(6,44,440,600) as Title
//		NewPanel /K=1/W=(6,44,440,660) as Title
		NewPanel /K=1/W=(6,44,440,670) as Title
		Dowindow /C $PanelName
//		CheckWindowPosition(PanelName,6,44,440,520)
//		CheckWindowPosition(PanelName,6,44,440,600)
//		CheckWindowPosition(PanelName,6,44,440,660)
		CheckWindowPosition(PanelName,6,44,440,670)

//		Display/W=(7,111,419,441)/HOST=#
//		Display/W=(7,111,419,521)/HOST=#
//		Display/W=(5,111,431,516)/HOST=#
//		Display/W=(5,171,431,576)/HOST=#
		Display/W=(5,181,431,586)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab= {1,200,Yellow,0}

		AppendImage Image
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		// add the full-range colorbar
//		Display/W=(5,110,431,175)/Host=##
		Display/W=(5,120,431,185)/Host=##
		AppendImage Colorbar
		ModifyGraph noLabel(left)=2	// hide y-axis labels
		ModifyGraph tick(left)=3		// hide y-axis ticks
		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}	// set ticks to 45deg intervals

//		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,525)
//		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,585)
		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,595,1)

//		NewAppendContrastControls(PanelName)
//		AppendContrastControls(StackName,"root:SPHINX:Stacks",PanelFolder,NumX,NumY)
//		AppendContrastControls("POL_Analysis","root:SPHINX:Stacks",PanelFolder,NumX,NumY)
//		AppendColorContrastControls(StackName,"root:SPHINX:Stacks",PanelFolder,NumX,NumY)
//		AppendContrastControls(NameOfWave(HueWave),"root:SPHINX:Stacks",PanelFolder,NumX,NumY)
//		ShowImageHistogram(Image,StackName,PanelFolder,PanelName)

		// Permit saving for images or stacks
//		Button HSLtoRGBImageSaveButton,pos={5,83}, size={55,24},fSize=13,proc=PolarizationPanelButtons,title="Export"
//		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
//		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"
//		Button TransferCrsButton,pos={220,523}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
//		Button TransferZoomButton,pos={250,523}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"
//		Button TransferCrsButton,pos={220,583}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
//		Button TransferZoomButton,pos={250,583}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		// Permit saving for images or stacks
		Button HSLtoRGBImageSaveButton,pos={5,93}, size={55,24},fSize=13,proc=PolarizationPanelButtons,title="Export"
		Button TransferCrsButton,pos={220,593}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,593}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

//		SetVariable MinDvalue,title="Min D",pos={145,20},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinDvalue")
//		SetVariable MaxDvalue,title="Max D",pos={145,40},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxDvalue")
//		SetVariable HSLtoRGB_level,title="B/W",pos={145,60},limits={0,1,1},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:HSLtoRGB_level")

		MakeVariableIfNeeded(PanelFolder+":UseB",1)
		CheckBox useB,title="Use b",pos={5,32},fsize=11,variable=$(PanelFolder+":UseB"),proc=CheckUseB
		MakeVariableIfNeeded(PanelFolder+":IsVaterite",0)
		CheckBox isVaterite,title="Vaterite",pos={65,32},fsize=11,variable=$(PanelFolder+":IsVaterite"),proc=CheckIsVaterite
		MakeVariableIfNeeded(PanelFolder+":SampleCenteredCoords",0)
		CheckBox sampleCenteredCoords,title="Sample centered",pos={5,47},fsize=11,variable=$(PanelFolder+":SampleCenteredCoords")

//		MakeVariableIfNeeded(PanelFolder+":MinDvalue",-10)
//		SetVariable MinDvalue,title="Min D",pos={145,32},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinDvalue")
//		MakeVariableIfNeeded(PanelFolder+":MaxDvalue",-10)
//		SetVariable MaxDvalue,title="Max D",pos={145,52},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxDvalue")
//		MakeVariableIfNeeded("root:POLARIZATION:Analysis:HSLtoRGB_level",0)
//		SetVariable HSLtoRGB_level,title="B/W",pos={145,72},limits={0,1,1},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:HSLtoRGB_level")

		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MinDvalue",-10)
		SetVariable MinDvalue,title="min d",pos={145,32},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinDvalue")
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxDvalue",-10)
		SetVariable MaxDvalue,title="max d",pos={145,52},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxDvalue")

		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MinDvalue_vat",+10)
		SetVariable MinDvalue_vat,title="min d",pos={145,32},limits={-65535,0,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinDvalue_vat")
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxDvalue_vat",+10)
		SetVariable MaxDvalue_vat,title="max d",pos={145,52},limits={-65535,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxDvalue_vat")

		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MinBvalue",-10)
		SetVariable MinBvalue,title="min b",pos={145,32},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinBvalue")
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxBvalue",-10)
		SetVariable MaxBvalue,title="max b",pos={145,52},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxBvalue")

		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MinBvalue_vat",-10)
		SetVariable MinBvalue_vat,title="min b",pos={145,32},limits={-65535,0,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinBvalue_vat")
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxBvalue_vat",-10)
		SetVariable MaxBvalue_vat,title="max b",pos={145,52},limits={-65535,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxBvalue_vat")

		CheckB(UseB)

		MakeVariableIfNeeded("root:POLARIZATION:Analysis:HSLtoRGB_level",0)
		SetVariable HSLtoRGB_level,title="B/W",pos={5,72},limits={0,1,1},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:HSLtoRGB_level")

		GroupBox HueGroup,pos={275,2},size={152,38}, title="Hues",fColor=(39321,1,1)
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MinColorAngle",-400)
		SetVariable MinColorAngle,title="Min",pos={280,17},limits={-360,360,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinColorAngle")
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxColorAngle",-400)
		SetVariable MaxColorAngle,title="Max",pos={355,17},limits={-360,360,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxColorAngle")

		GroupBox AngleGroup,pos={270,40},size={162,77}, title="Angles",fColor=(1,1,65535)
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MinAngle",-100)
		SetVariable MinAngle,title="Min",pos={280,55},limits={-90,90,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinAngle")
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:MaxAngle",-100)
		SetVariable MaxAngle,title="Max",pos={355,55},limits={-90,90,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxAngle")

//		Button HSLtoRGB,pos={120,58}, size={140,24},fSize=10,proc=PolarizationPanelButtons,title="Recreate HSLtoRGB"
//		Button MakeRGBscaleBar,pos={120,83}, size={140,24},fSize=10,proc=PolarizationPanelButtons,title="Make RGB Scalebar"
//		SetVariable HSLtoRGB_level,title="Level",pos={5,60},limits={-1,101,5},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:HSLtoRGB_level")
//		Button MakeRGBscaleBar,pos={220,535}, size={5,5},fSize=10,proc=PolarizationPanelButtons,title="" // hidden button for making the half-circle RGB scalebar

//		Button HSLtoRGB,pos={63,83}, size={60,24},fSize=10,proc=PolarizationPanelButtons,title="Recreate"
//		Button MakeRGBscaleBar,pos={220,595}, size={5,5},fSize=10,proc=PolarizationPanelButtons,title="" // hidden button for making the half-circle RGB scalebar

		Button HSLtoRGB,pos={63,93}, size={60,24},fSize=10,proc=PolarizationPanelButtons,title="Recreate"
		Button MakeRGBscaleBar,pos={220,605}, size={5,5},fSize=10,proc=PolarizationPanelButtons,title="" // hidden button for making the half-circle RGB scalebar

		Button MakeThetaMap,pos={145,93}, size={100,24},fSize=10,proc=PolarizationPanelButtons,title="Make Theta Map"

		GroupBox AngleCutoffGroup,pos={275,75},size={152,38}, title="angles cut off",fColor=(1,1,65535)
		CheckBox blackCutoffcheckbox,title="B",pos={253,92},fsize=11,side=1,proc=UseCutoff
		CheckBox whiteCutoffcheckbox,title="W",pos={284,92},fsize=11,side=1,proc=UseCutoff
		CheckBox hueCutoffcheckbox,title="hue",pos={323,92},fsize=11,side=1,proc=UseCutoff
		MakeVariableIfNeeded(PanelFolder+":hueCutoffColorValue",0)
		SetVariable hueCutoffColorValue,title=" ",pos={375,90},limits={0,360,10},size={50,20},fsize=13,value=$("root:POLARIZATION:Analysis:hueCutoffColorValue")
		UpdateCutoffCheckboxes() // ensures that checkboxes that were previously checked are still checked, and that the Exclusion Hue is properly disabled/enabled
		
		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(Image)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(Image,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"

		//AppendROIControlsWithFlag(NameOfWave(Image), PanelName, "StackImage", GetWavesDataFolder(Image,1), PanelFolder, NumX, NumY, 64, 87, 0)

End

Function /S PolRgbMaskDisplayPanel()
	Wave Image = root:SPHINX:Stacks:POL_RGB_Mask
	Wave Colorbar = root:SPHINX:Stacks:COLORBAR_RGB_Mask
	String Title = "Masked Color PIC-map Display Panel"
	Wave NumData = $("root:POLARIZATION:NumData")
	Variable NumX = NumData[0]
	Variable NumY = NumData[1]

	String PanelFolder 	= "root:SPHINX:HSL2RGBMasked"
	String PanelName 	= "HSL2RGBMasked"
	String StackName	= NameOfWave(Image)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O Image, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,670) as Title
		Dowindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,670)

		Display/W=(5,181,431,586)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab= {1,200,Yellow,0}

		AppendImage Image
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		// add the full-range colorbar
		Display/W=(5,120,431,185)/Host=##
		AppendImage Colorbar
		ModifyGraph noLabel(left)=2	// hide y-axis labels
		ModifyGraph tick(left)=3		// hide y-axis ticks
		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}	// set ticks to 45deg intervals

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,595,1)

		// Permit saving for images or stacks
		Button HSLtoRGBMaskImageSaveButton,pos={5,93}, size={55,24},fSize=13,proc=PolarizationPanelButtons,title="Export"
		Button TransferCrsButton,pos={220,593}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,593}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

//		MakeVariableIfNeeded(PanelFolder+":MinBvalue",-10)
//		SetVariable MinBvalue,title="Min B",pos={145,20},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinBvalue")
//		MakeVariableIfNeeded(PanelFolder+":MaxBvalue",-10)
//		SetVariable MaxBvalue,title="Max B",pos={145,40},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxBvalue")

//		SetVariable MinDvalue,title="Min D",pos={145,20},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinDvalue")
//		SetVariable MaxDvalue,title="Max D",pos={145,40},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxDvalue")
//		SetVariable HSLtoRGB_level,title="B/W",pos={145,60},limits={0,1,1},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:HSLtoRGB_level")

		MakeVariableIfNeeded(PanelFolder+":SampleCenteredCoords",0)
		CheckBox sampleCenteredCoords,title="Sample centered",pos={145,2},fsize=11,variable=$(PanelFolder+":SampleCenteredCoords")
		MakeVariableIfNeeded(PanelFolder+":IsVaterite",0)
		CheckBox isVaterite,title="Vaterite",pos={145,17},fsize=11,variable=$(PanelFolder+":IsVaterite")

		MakeVariableIfNeeded(PanelFolder+":MinDvalue",-10)
		SetVariable MinDvalue,title="min d",pos={145,32},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinDvalue")
		MakeVariableIfNeeded(PanelFolder+":MaxDvalue",-10)
		SetVariable MaxDvalue,title="max d",pos={145,52},limits={0,65535,10},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxDvalue")
		MakeVariableIfNeeded("root:POLARIZATION:Analysis:HSLtoRGB_level",0)
		SetVariable HSLtoRGB_level,title="B/W",pos={145,72},limits={0,1,1},size={100,20},fsize=13,value=$("root:POLARIZATION:Analysis:HSLtoRGB_level")

		GroupBox HueGroup,pos={275,2},size={152,38}, title="Hues",fColor=(39321,1,1)
		MakeVariableIfNeeded(PanelFolder+":MinColorAngle",-400)
		SetVariable MinColorAngle,title="Min",pos={280,17},limits={-360,360,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinColorAngle")
		MakeVariableIfNeeded(PanelFolder+":MaxColorAngle",-400)
		SetVariable MaxColorAngle,title="Max",pos={355,17},limits={-360,360,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxColorAngle")

		GroupBox AngleGroup,pos={270,40},size={162,77}, title="Angles",fColor=(1,1,65535)
		MakeVariableIfNeeded(PanelFolder+":MinAngle",-100)
		SetVariable MinAngle,title="Min",pos={280,55},limits={-90,90,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MinAngle")
		MakeVariableIfNeeded(PanelFolder+":MaxAngle",-100)
		SetVariable MaxAngle,title="Max",pos={355,55},limits={-90,90,10},size={70,20},fsize=13,value=$("root:POLARIZATION:Analysis:MaxAngle")

		Button HSLtoRGBMask,pos={63,93}, size={60,24},fSize=10,proc=PolarizationPanelButtons,title="Recreate"
		Button MakeRGBscaleBar,pos={220,605}, size={5,5},fSize=10,proc=PolarizationPanelButtons,title="" // hidden button for making the half-circle RGB scalebar

		GroupBox AngleCutoffGroup,pos={275,75},size={152,38}, title="angles cut off",fColor=(1,1,65535)
		CheckBox blackCutoffcheckbox,title="B",pos={253,92},fsize=11,side=1,proc=UseCutoff
		CheckBox whiteCutoffcheckbox,title="W",pos={284,92},fsize=11,side=1,proc=UseCutoff
		CheckBox hueCutoffcheckbox,title="hue",pos={323,92},fsize=11,side=1,proc=UseCutoff
		MakeVariableIfNeeded(PanelFolder+":hueCutoffColorValue",0)
		SetVariable hueCutoffColorValue,title=" ",pos={375,90},limits={0,360,10},size={50,20},fsize=13,value=$("root:POLARIZATION:Analysis:hueCutoffColorValue")
		UpdateCutoffCheckboxes() // ensures that checkboxes that were previously checked are still checked, and that the Exclusion Hue is properly disabled/enabled
		
		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(Image)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(Image,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function MakeThetaMap()

	String PanelFolder = "root:POLARIZATION:Analysis"
	String StackFolder = "root:SPHINX:Stacks"
	Wave NumData = $("root:POLARIZATION:NumData")
	NVAR MaxDvalue = $(PanelFolder+":MaxDvalue")
	NVAR MinDvalue_vat = $(PanelFolder+":MinDvalue_vat")

	// Assign Results waves
		WAVE /D POL_D = $(StackFolder+":POL_D")
		WAVE /D POL_Theta = $(StackFolder+":POL_Theta")

		WAVE /D POL_D_vat = $(StackFolder+":POL_D_vat")
		WAVE /D POL_Theta_vat = $(StackFolder+":POL_Theta_vat")
	// Make Results Waves if needed
		if (!WaveExists(POL_Theta))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Theta") /WAVE=POL_Theta
			POL_Theta = NaN
		endif
		if (!WaveExists(POL_Theta_vat))
			Make /O/N=(NumData[0],NumData[1])/D $(StackFolder+":POL_Theta_vat") /WAVE=POL_Theta_vat
			POL_Theta_vat = NaN
		endif
		
		// BG: This is where POL_Theta is calculated
		POL_Theta[][] = acos(sqrt(POL_D[p][q] / MaxDvalue)) * 180 / PI
		POL_Theta_vat[][] = acos(sqrt(POL_D_vat[p][q] / MinDvalue_vat)) * 180 / PI

//		POL_Theta[][] = (cmpstr(num2str(POL_Theta[p][q]), "NaN") != 0) ? POL_Theta[p][q] : ( (POL_D[p][q] > MaxDvalue) ? 0 : 90)
//		POL_Theta_vat[][] = (cmpstr(num2str(POL_Theta_vat[p][q]), "NaN") != 0) ? POL_Theta_vat[p][q] : ( (POL_D_vat[p][q] < MinDvalue_vat) ? 0 : 90)

End

// Used by HSL2RGBDisplayPanel()
Function AppendColorContrastControls(StackName,StackFolder,PanelFolder,NumX,NumY)
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
//		DefaultLevels(PanelFolder,Image,ImageMin, ImageMax, DisplayMin, DisplayMax)
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

// Used by HSL2RGBDisplayPanel()
Function UpdateCutoffCheckboxes()

	String PanelFolder = "root:POLARIZATION:Analysis"

	MakeVariableIfNeeded(PanelFolder+":blackCutoff",0)
	MakeVariableIfNeeded(PanelFolder+":whiteCutoff",0)
	MakeVariableIfNeeded(PanelFolder+":hueCutoff",0)
	NVAR blackCutoff = $(PanelFolder+":blackCutoff")
	NVAR whiteCutoff = $(PanelFolder+":whiteCutoff")
	NVAR hueCutoff = $(PanelFolder+":hueCutoff")

	CheckBox blackCutoffcheckbox,value=blackCutoff
	CheckBox whiteCutoffcheckbox,value=whiteCutoff
	CheckBox hueCutoffcheckbox,value=hueCutoff
	SetVariable hueCutoffColorValue,disable=1-hueCutoff
End

// Used by HSL2RGBDisplayPanel()
Function CheckUseB(name, value) : CheckboxControl
	String name
	Variable value

	CheckB(value)
End

Function CheckB(value)
	Variable value
	if (value != 0 && value != 1)
		value = 1
	endif

	MakeVariableIfNeeded("root:SPHINX:HSL2RGB:IsVaterite",0)
	NVAR IsVaterite = $("root:SPHINX:HSL2RGB:IsVaterite")

	if (value == 1)
		// we are using b
		SetVariable MinDvalue,disable=1
		SetVariable MaxDvalue,disable=1
		SetVariable MinDvalue_vat,disable=1
		SetVariable MaxDvalue_vat,disable=1
		if (IsVaterite == 1)
			SetVariable MinBvalue,disable=1
			SetVariable MaxBvalue,disable=1
			SetVariable MinBvalue_vat,disable=0
			SetVariable MaxBvalue_vat,disable=0
		else
			SetVariable MinBvalue,disable=0
			SetVariable MaxBvalue,disable=0
			SetVariable MinBvalue_vat,disable=1
			SetVariable MaxBvalue_vat,disable=1
		endif
	else
		SetVariable MinBvalue,disable=1
		SetVariable MaxBvalue,disable=1
		SetVariable MinBvalue_vat,disable=1
		SetVariable MaxBvalue_vat,disable=1
		if (IsVaterite == 1)
			SetVariable MinDvalue,disable=1
			SetVariable MaxDvalue,disable=1
			SetVariable MinDvalue_vat,disable=0
			SetVariable MaxDvalue_vat,disable=0
		else
			SetVariable MinDvalue,disable=0
			SetVariable MaxDvalue,disable=0
			SetVariable MinDvalue_vat,disable=1
			SetVariable MaxDvalue_vat,disable=1
		endif
	endif
End

// Used by HSL2RGBDisplayPanel()
Function CheckIsVaterite(name, value) : CheckboxControl
	String name
	Variable value

	MakeVariableIfNeeded("root:SPHINX:HSL2RGB:UseB",0)
	NVAR UseB = $("root:SPHINX:HSL2RGB:UseB")

	if (value == 1)
		// the sample is vaterite
		SetVariable MinDvalue,disable=1
		SetVariable MaxDvalue,disable=1
		SetVariable MinBvalue,disable=1
		SetVariable MaxBvalue,disable=1
		if (UseB == 0)
			// use D, not B
			SetVariable MinDvalue_vat,disable=0
			SetVariable MaxDvalue_vat,disable=0
			SetVariable MinBvalue_vat,disable=1
			SetVariable MaxBvalue_vat,disable=1
		else
			// use B
			SetVariable MinDvalue_vat,disable=1
			SetVariable MaxDvalue_vat,disable=1
			SetVariable MinBvalue_vat,disable=0
			SetVariable MaxBvalue_vat,disable=0
		endif
	else
		// not vaterite
		SetVariable MinDvalue_vat,disable=1
		SetVariable MaxDvalue_vat,disable=1
		SetVariable MinBvalue_vat,disable=1
		SetVariable MaxBvalue_vat,disable=1
		if (UseB == 0)
			// use D, not B
			SetVariable MinDvalue,disable=0
			SetVariable MaxDvalue,disable=0
			SetVariable MinBvalue,disable=1
			SetVariable MaxBvalue,disable=1
		else
			// use B
			SetVariable MinDvalue,disable=1
			SetVariable MaxDvalue,disable=1
			SetVariable MinBvalue,disable=0
			SetVariable MaxBvalue,disable=0
		endif
	endif
End

// Used by HSL2RGBDisplayPanel()
Function UseCutoff(name, value) : CheckboxControl
	String name
	Variable value

	String PanelFolder = "root:POLARIZATION:Analysis"
	
	MakeVariableIfNeeded(PanelFolder+":blackCutoff",0)
	MakeVariableIfNeeded(PanelFolder+":whiteCutoff",0)
	MakeVariableIfNeeded(PanelFolder+":hueCutoff",0)
	NVAR blackCutoff = $(PanelFolder+":blackCutoff")
	NVAR whiteCutoff = $(PanelFolder+":whiteCutoff")
	NVAR hueCutoff = $(PanelFolder+":hueCutoff")

	strswitch(name)
		case "blackCutoffcheckbox":
			blackCutoff = value
			whiteCutoff = 0
			hueCutoff = 0
			CheckBox whiteCutoffCheckbox,value=0
			CheckBox hueCutoffCheckbox,value=0
			SetVariable hueCutoffColorValue,disable=1
			break
		case "whiteCutoffcheckbox":
			blackCutoff = 0
			whiteCutoff = value
			hueCutoff = 0
			CheckBox blackCutoffCheckbox,value=0
			CheckBox hueCutoffCheckbox,value=0
			SetVariable hueCutoffColorValue,disable=1
			break
		case "hueCutoffcheckbox":
			blackCutoff = 0
			whiteCutoff = 0
			hueCutoff = value
			CheckBox blackCutoffCheckbox,value=0
			CheckBox whiteCutoffCheckbox,value=0
			SetVariable hueCutoffColorValue,disable=1-value
			break
	endswitch
End

Function MakeRGBscaleBar()
	SetDataFolder root:POLARIZATION:Analysis
	
	String StackFolder = "root:SPHINX:Stacks"
	SVAR StackName = root:POLARIZATION:StackName
	String PanelFolder = "root:POLARIZATION:Analysis"
	
	NVAR HSLtoRGB_level = $(PanelFolder+":HSLtoRGB_level")
//	NVAR MaxBvalue = $(PanelFolder+":MaxBvalue")
//	NVAR MinBvalue = $(PanelFolder+":MinBvalue")
	NVAR MaxDvalue = $(PanelFolder+":MaxDvalue")
	NVAR MinDvalue = $(PanelFolder+":MinDvalue")
	NVAR scaleSetPoint = root:POLARIZATION:Analysis:scaleSetPoint
	Variable i, j
	Variable SBwidth = 1000
	Variable SBheight = 500
	Variable SBoriginX = SBwidth/2
	Variable SBoriginY = SBheight
	Variable MyDistFromOrigin
	Variable MyAngle
		
	// Assign waves
		WAVE /D POL_HSL_Scale = $(StackFolder+":POL_HSL_Scale")
	
	// Make 3D Color Waves if needed
		if (!WaveExists(POL_HSL_Scale))
			Make /O/N=(SBwidth,SBheight,3)/D $(StackFolder+":POL_HSL_Scale") /WAVE=POL_HSL_Scale
		endif
	
	//HSLtoRGB_level is user set, between 0-100. Rescale to 0 to 65535
	// POL_HSL_Scale[][][2] = HSLtoRGB_level*(65535/100)
		
		if (HSLtoRGB_level == 0 || HSLtoRGB_level == 1) // black (0) or white (1)
			
			POL_HSL_Scale[][][1] = 65535
			
			for (i=0;i<SBwidth;i+=1)
				for (j=0;j<SBheight;j+=1)
					MyDistFromOrigin = sqrt((SBoriginX-i)^2+(SBoriginY-j)^2)
					MyAngle = atan((SBoriginX-i)/(j-SBoriginY))*180/pi+90
					//print MyDistFromOrigin," ",MyAngle
					if (MyDistFromOrigin <= SBheight)
						POL_HSL_Scale[i][j][0] = 65535*MyAngle/180
						
						if (HSLtoRGB_level == 0) // black
							POL_HSL_Scale[i][j][2] = (MyDistFromOrigin/SBheight)*65535/2
						else // white
							POL_HSL_Scale[i][j][2] = 65535 - (MyDistFromOrigin/SBheight)*65535
						endif
					else
						POL_HSL_Scale[i][j][0] = NaN
						POL_HSL_Scale[i][j][2] = NaN
					endif
				endfor
			endfor
			
		else // gray
			
			//HSLtoRGB_level is user set, between 0-1. Rescale to 0 to 65535
			POL_HSL_Scale[][][2] = HSLtoRGB_level*65535
			
			for (i=0;i<SBwidth;i+=1)
				for (j=0;j<SBheight;j+=1)
					MyDistFromOrigin = sqrt((SBoriginX-i)^2+(SBoriginY-j)^2)
					MyAngle = atan((SBoriginX-i)/(j-SBoriginY))*180/pi+90
					//print MyDistFromOrigin," ",MyAngle
					if (MyDistFromOrigin <= SBheight)
						POL_HSL_Scale[i][j][0] = 65535*MyAngle/180
						POL_HSL_Scale[i][j][1] = (MyDistFromOrigin/SBheight)*65535
					else
						POL_HSL_Scale[i][j][0] = NaN
						POL_HSL_Scale[i][j][1] = NaN
					endif
				endfor
			endfor
			
		endif
		
//		for (i=0;i<SBwidth;i+=1)
//			for (j=0;j<SBheight;j+=1)
//				MyDistFromOrigin = sqrt((SBoriginX-i)^2+(SBoriginY-j)^2)
//				MyAngle = atan((SBoriginX-i)/(j-SBoriginY))*180/pi+90
//				//print MyDistFromOrigin," ",MyAngle
//				if (MyDistFromOrigin <= SBheight)
//					POL_HSL_Scale[i][j][0] = 65535*MyAngle/180
//					POL_HSL_Scale[i][j][1] = (MyDistFromOrigin/SBheight)*65535
//				else
//					POL_HSL_Scale[i][j][0] = NaN
//					POL_HSL_Scale[i][j][1] = NaN
//				endif
//			endfor
//		endfor
		
//		POL_HSL_Scale[][][2] = (HSLtoRGB_level < 0) ? (POL_HSL_Scale[p][q][1])/2 : ((HSLtoRGB_level > 100) ? (65535 - (POL_HSL_Scale[p][q][1])/2) : HSLtoRGB_level*(65535/100)) // scale lightness according to B value or level, depending on level. level < 0, use black. level > 100, use white. otherwise, use user-set level
		
		// Adjust HUE according to scale setpoint (allows rotation of color wheel -- our color wheel is 180 degrees)
		POL_HSL_Scale[][][0] -= scaleSetPoint*(65535/180)
		POL_HSL_Scale[][][0] = (POL_HSL_Scale[p][q][0] < 0) ? (POL_HSL_Scale[p][q][0] + 65535) : POL_HSL_Scale[p][q][0]
		POL_HSL_Scale[][][0] = (POL_HSL_Scale[p][q][0] > 65535) ? (POL_HSL_Scale[p][q][0] - 65535) : POL_HSL_Scale[p][q][0]

		SetDataFolder $(StackFolder)
		ImageTransform hsl2rgb POL_HSL_Scale
		
		//Cleanup
		if (WinType("HSL2RGB_Scale") == 7)
			KillWindow HSL2RGB_Scale
		endif
		if (WaveExists(root:SPHINX:Stacks:POL_RGB_Scale) == 1)
			KillWaves POL_RGB_Scale
		endif
		Duplicate M_HSL2RGB, POL_RGB_Scale
		KillWaves POL_HSL_Scale, M_HSL2RGB
		
		//Display Image
		DisplayRGBscaleBarPanel()	
		//NewImage  root:SPHINX:Stacks:POL_RGB_Scale
End

Function /S DisplayRGBscaleBarPanel()
	Variable SBwidth = 1000
	Variable SBheight = 500
	Wave Image = root:SPHINX:Stacks:POL_RGB_Scale
	String Title = "HSL2RGB_Scale"

	String PanelFolder 	= "root:SPHINX:HSL2RGB_Scale"
	String PanelName 	= "HSL2RGB_Scale"
	String StackName	= NameOfWave(Image)

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
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,SBwidth,SBheight,450,1)

		// Permit saving for images or stacks
		Button HSLtoRGBscaleImageSaveButton,pos={5,83}, size={55,24},fSize=13,proc=PolarizationPanelButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4

		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(Image)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(Image,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(SBwidth)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(SBheight)+";"

End

// *************************************************************
// ****	Button controls on the Polarization Analysis panel only
// *************************************************************
Function PolarizationPanelButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 	= B_Struct.ctrlName
	String WindowName = B_Struct.win
	
	Variable eventCode 	= B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	if (cmpstr(ctrlName,"AnalyzePixel") == 0)
		AnalyzePixel()
	elseif (cmpstr(ctrlName,"AnalyzeROI") == 0)
		AnalyzeROI()
	elseif (cmpstr(ctrlName,"ClearROIs") == 0)
		ClearROIs()
	elseif (cmpstr(ctrlName, "SetROI") == 0)
		SetROI()
	elseif (cmpstr(ctrlName, "CropStack") == 0)
		CropStack()
	elseif (cmpstr(ctrlName, "TransferPinkROI") ==0)
		TransferPinkROI()
	elseif (cmpstr(ctrlName, "RotateStack") == 0)
		RotateStack()
	elseif (cmpstr(ctrlName, "CalculateRotation") == 0)
		CalculateRotation()
	elseif (cmpstr(ctrlName,"MakeThetaMap") == 0)
		MakeThetaMap()
	elseif (cmpstr(ctrlName,"AnalyzeStack") == 0)
		try
			AnalyzeStack()
		catch
			CloseProcessBar()
			StopAllTimers()
			if (V_AbortCode == -1)
				Print " *** Polarization analysis routine aborted by user."
			else
				Print " *** Polarization analysis routine aborted due to error."
			endif
		endtry
	elseif (cmpstr(ctrlName,"ScaleAnalysis") == 0)
		ScaleAnalysisImage()
	elseif (cmpstr(ctrlName,"AnalyzePolOutput") == 0)
		PolResultAnalysisPanel()
	elseif (cmpstr(ctrlName,"CollectAnalysis") == 0)
		PolResultCollectCursors()
	elseif (cmpstr(ctrlName,"SaveAnalysis") == 0)
		PolResultSaveAnalysis()
	elseif (cmpstr(ctrlName,"ignoreMask") == 0)
		IgnoreROI()
		CheckBox ignoreROIcheckbox,disable=0
	elseif (cmpstr(ctrlName,"clearIgnoreMask") == 0)
		clearIgnoreMask()
	elseif (cmpstr(ctrlName,"LoadI0") == 0)	
		LoadPolI0()
		CheckBox normToI0checkbox,disable=0
	elseif (cmpstr(ctrlName,"EnhancePIC") == 0)
		SetDataFolder root:POLARIZATION:Analysis
		Variable /G enhancePolAnalysis=1
		CheckBox enhanceCheckbox,disable=0
		EnhancePICmap()
	elseif (cmpstr(ctrlName,"GaussBlur") == 0)
		SetDataFolder root:POLARIZATION:Analysis
		Variable /G gaussPolAnalysis=1
		GaussBlurPOLAnalysis()
		CheckBox gaussCheckbox,disable=0
	elseif (cmpstr(ctrlName,"createMask") == 0)
		SetDataFolder root:POLARIZATION:Analysis
		Variable /G useMaskedPolAnalysis=1
		CheckBox useMaskedCheckbox,disable=0
		createMaskedPOLAnalysis()
	elseif (cmpstr(ctrlName,"extractMaskedAS") == 0)
		extractMaskedAS()
	elseif (cmpstr(ctrlName,"imageMask") == 0)
		if (imageMask() && (exists("root:POLARIZATION:ImageMask_name") == 2))
			CheckBox imageMaskCheckbox,disable=0
			SVAR imageMaskName = root:POLARIZATION:ImageMask_name
			CheckBox imageMaskCheckbox,title=("From "+imageMaskName)
		endif
	elseif (cmpstr(ctrlName,"StdDevAnalysis") == 0)
		StandardDevAnalysis()
	elseif (cmpstr(ctrlName,"CircDispAnalysis") == 0)
		CircDispAnalysis()
	elseif (cmpstr(ctrlName,"ExtractROI") == 0)
		ExtractROI()
	elseif (cmpstr(ctrlName,"ExportBin") == 0)
		ExportBin()
	elseif (cmpstr(ctrlName,"makeSlices") == 0)
		CreateSlices()
	elseif (cmpstr(ctrlName,"collectSlices") == 0)
		CollectSlices()
	elseif (cmpstr(ctrlName,"HSLtoRGB") == 0)
		HSLtoRGB(0)
	elseif (cmpstr(ctrlName,"HSLtoRGBMask") == 0)
		HSLtoRGB(1)
	elseif (cmpstr(ctrlName,"HSLtoRGBImageSaveButton") == 0)
//		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:POL_RGB
		MakeStringIfNeeded("root:SPHINX:Browser:gFinalWaveName","POL_RGB")
		SVAR gFinalWaveName = root:SPHINX:Browser:gFinalWaveName
		ImageSave /DS=8/T="tiff" root:SPHINX:Stacks:POL_RGB gFinalWaveName
		
		// !*!*! BG 2021-05-16
//		String ImageExportFormat = "8-bit"
//		Prompt ImageExportFormat, "Image save format", popup, "8-bit;16-bit floating;"
//		DoPrompt "Save RGB PIC map", ImageExportFormat
//		if (V_flag)
//			return 0
//		endif
//		if (cmpstr(ImageExportFormat,"8-bit") == 0)
//			ImageSave /DS=8/T="tiff" root:SPHINX:Stacks:POL_RGB gFinalWaveName
//		else
//			ImageSave /U/DS=16/T="tiff" root:SPHINX:Stacks:POL_RGB gFinalWaveName
//		endif

//		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:POL_RGB gFinalWaveName

	elseif (cmpstr(ctrlName,"HSLtoRGBMaskImageSaveButton") == 0)
//		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:POL_RGB
		MakeStringIfNeeded("root:SPHINX:Browser:gFinalWaveName","POL_RGB_Mask")
		SVAR gFinalWaveName = root:SPHINX:Browser:gFinalWaveName
		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:POL_RGB_Mask gFinalWaveName
	elseif (cmpstr(ctrlName,"HSLtoRGBscaleImageSaveButton") == 0)
		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:POL_RGB_Scale
	elseif (cmpstr(ctrlName,"MakeRGBscaleBar") == 0)
		MakeRGBscaleBar()
	endif
End

// *************************************************************
// ****		SVD Panel Check Boxes for ROI selection
// *************************************************************

// Toggle between various options for using and ROI mask
// We can only have one or the other or neither
Function PolRefROICheckProcs(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 

	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif

	NVAR gROIMappingFlag 	= root:SPHINX:SVD:gROIMappingFlag
	NVAR gImageROIFlag 	= root:SPHINX:SVD:gImageROIFlag

	Variable checked		= CB_Struct.checked
	String ctrlName			= CB_Struct.ctrlName

	if (cmpstr(ctrlName,"SVDROICheck") == 0)
		gROIMappingFlag 	= checked
		if (checked)
			gImageROIFlag 	= 0
		endif
	endif

	return 1
End

// *************************************************************
// ****		Cos Squared Fit Function
// *************************************************************
Function cos_squared(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = a + b * (cos(x + c)) ^ 2
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = a
	//CurveFitDialog/ w[1] = b
	//CurveFitDialog/ w[2] = c

	return w[0] + w[1] * (cos((pi*x/180) - w[2])) ^ 2
End















//Function BGFillSPWaves()
//
//	NVAR Bmax = root:POLARIZATION:Analysis:MaxBValue
//
//	String StackFolder = "root:SPHINX:Stacks"
//	// These arrays are calculated by Analyze ROI/Stack
//	WAVE /D POL_B 			= $(StackFolder+":POL_B")
//	WAVE /D POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
//	// These arrays are calculated below
//	WAVE /D POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
//	WAVE /D POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
//	WAVE /D POL_Rpol 		= $(StackFolder+":POL_Rpol")
//
//	POL_Rpol[][] 		= POL_B[p][q]/Bmax
//	
//	Variable Convention = 2
//	if (Convention == 1)
//	// Calc 1: 0 < Phi < 180. I think this calculation incorrectly assumes an (x,y) not (z,y) POL plane
//		POL_PhiSP[][] 		= (180/pi) * acos(  POL_Rpol[p][q] * cos((pi/180) * POL_PhiZY[p][q])  )
//		
//		//	POL_ThetSP[][] 	= (180/pi) * atan2(  POL_Rpol[p][q] * sin((pi/180) * POL_PhiZY[p][q])  ,  sqrt(1 - POL_Rpol[p][q]^2)  )
//		POL_ThetSP[][] 	= (180/pi) * atan(  POL_Rpol[p][q] * sin((pi/180) * POL_PhiZY[p][q])  /  sqrt(1 - POL_Rpol[p][q]^2)  )
//	
//	// Calc 2: 0 < Phi < 180. Calculation should be correct for the (z,y) POL plane
//		POL_PhiSP[][] 		= (180/pi) * acos(  POL_Rpol[p][q] * sin((pi/180) * POL_PhiZY[p][q])  )
//		POL_ThetSP[][] 	= (180/pi) * atan(  POL_Rpol[p][q] * cos((pi/180) * POL_PhiZY[p][q])  /  sqrt(1 - POL_Rpol[p][q]^2)  )
//	
//		Make /O/N=(100)/D $(StackFolder+":POL_Rpol_hist") /WAVE=POL_Rpol_hist
//		SetScale /P x, 0, 0.01, POL_Rpol_hist
//		Make /O/N=(1800)/D $(StackFolder+":POL_PhiZY_hist") /WAVE=POL_PhiZY_hist
//		SetScale /P x, 0, 0.1, POL_PhiZY_hist
//		Make /O/N=(1800)/D $(StackFolder+":POL_PhiSP_hist") /WAVE=POL_PhiSP_hist
//		SetScale /P x, 0, 0.1, POL_PhiSP_hist
//		Make /O/N=(1800)/D $(StackFolder+":POL_ThetSP_hist") /WAVE=POL_ThetSP_hist
//		SetScale /P x, -90, 0.1, POL_ThetSP_hist
//	else
//	// Calc 2: 0 < Phi < 90 and -90 < Theta < 90. Calculation should be correct for the (z,y) POL plane
//		Duplicate /O POL_PhiZY, POL_PhiPol 	// I'd prefer to switch the names of these ... 
//		
//		POL_PhiPol[][] 		= (POL_PhiZY[p][q] > 90) ? 180 - POL_PhiZY[p][q] : POL_PhiZY[p][q]
//		
//		POL_PhiSP[][] 		= (180/pi) * acos(  POL_Rpol[p][q] * cos((pi/180) * POL_PhiPol[p][q])  )
//		
//		POL_ThetSP[][] 	= (180/pi) * atan(  POL_Rpol[p][q] * sin((pi/180) * POL_PhiPol[p][q])  /  sqrt(1 - POL_Rpol[p][q]^2)  )
//		POL_ThetSP[][] 	= (POL_PhiZY[p][q] > 90) ? -1 * POL_ThetSP[p][q] : POL_ThetSP[p][q]
//		
//		
////	Variable PhiPol, PhiSP, ThetSP
////	if (PhiZY > 90)
////		PhiPol 	= 180-PhiZY
////		PhiSP 		= acos( Rpol * cos( (pi/180) * PhiPol) )
////		ThetSP 	= atan( -1 * Rpol * sin( (pi/180) * PhiPol) )
////	else
////		PhiPol 	= PhiZY
////		PhiSP 		= acos( Rpol * cos( (pi/180) * PhiPol))
////		ThetSP 	= atan( Rpol * sin( (pi/180) * PhiPol) )
////	endif
//		
//		Make /O/N=(100)/D $(StackFolder+":POL_Rpol_hist") /WAVE=POL_Rpol_hist
//		SetScale /P x, 0, 0.01, POL_Rpol_hist
//		Make /O/N=(1800)/D $(StackFolder+":POL_PhiZY_hist") /WAVE=POL_PhiZY_hist
//		SetScale /P x, 0, 0.1, POL_PhiZY_hist
//		Make /O/N=(1800)/D $(StackFolder+":POL_PhiPol_hist") /WAVE=POL_PhiPol_hist
//		SetScale /P x, 0, 0.1, POL_PhiPol_hist
//		Make /O/N=(1800)/D $(StackFolder+":POL_PhiSP_hist") /WAVE=POL_PhiSP_hist
//		SetScale /P x, 0, 0.1, POL_PhiSP_hist
//		Make /O/N=(1800)/D $(StackFolder+":POL_ThetSP_hist") /WAVE=POL_ThetSP_hist
//		SetScale /P x, -90, 0.1, POL_ThetSP_hist
//	endif
//	
//	Histogram/B=2 POL_ThetSP,POL_ThetSP_hist
//	Histogram/B=2 POL_PhiSP,POL_PhiSP_hist
//	Histogram/B=2 POL_PhiZY,POL_PhiZY_hist
//	Histogram/B=2 POL_PhiPol,POL_PhiPol_hist
//	Histogram/B=2 POL_Rpol,POL_Rpol_hist
//End 


//Function BGRossPOLRGB()
//	
//	String StackFolder = "root:SPHINX:Stacks"
//	WAVE /D POL_B 			= $(StackFolder+":POL_B")
//	WAVE /D C_wave 			= $(StackFolder+":POL_Cprime")
//	WAVE /D Theta_wave 	= $(StackFolder+":POL_theta")
//	WAVE /D POL_HSL 		= $(StackFolder+":POL_HSL")
//	
//	NVAR UseB 					= $("root:SPHINX:HSL2RGB:UseB")
//	NVAR MinBvalue 			= $("root:POLARIZATION:Analysis:MinBvalue")
//	NVAR MaxBvalue 			= $("root:POLARIZATION:Analysis:MaxBvalue")
//	WAVE NumData 			= $("root:POLARIZATION:NumData")
//	
//	Variable MinColor, MaxColor, MinAngle=0, MaxAngle=180, MinColorAngle=0, MaxColorAngle=360
//	MaxColor = MaxColorAngle * 65535 / 360
//	MinColor = MinColorAngle * 65535 / 360
//		
//	POL_HSL[][][0] = MinColor + (C_wave[p][q] - MinAngle) * (MaxColor - MinColor) / (MaxAngle - MinAngle)
//	POL_HSL[][][0] = (POL_HSL[p][q][0] < MinColor) ? (MinColor) : POL_HSL[p][q][0]
//	POL_HSL[][][0] = (POL_HSL[p][q][0] > MaxColor) ? (MaxColor) : POL_HSL[p][q][0]
//				
//	POL_HSL[][][1] 	= 65535
//	
//	if (UseB)
//		POL_HSL[][][2] = (POL_B[p][q] - MinBvalue) * ((65535 / 2) / (MaxBvalue - MinBvalue))
//	else
//		POL_HSL[][][2] = (Theta_wave[p][q] >= 0) ? ((cos(pi * Theta_wave[p][q] / 180))^2) * 65535 / 2 : 65535 - ((cos(pi * Theta_wave[p][q] / 180))^2) * 65535 / 2
//	endif
//	POL_HSL[][][2] = (POL_HSL[p][q][0] < MinColor) ? 0 : POL_HSL[p][q][2]
//	POL_HSL[][][2] = (POL_HSL[p][q][0] > MaxColor) ? 0 : POL_HSL[p][q][2]
//
//
//	SetDataFolder $(StackFolder) 
//	ImageTransform hsl2rgb POL_HSL
//	WAVE M_HSL2RGB = M_HSL2RGB
//	
//	Make /O/N=(NumData[0],NumData[1]+256,3)/D $(StackFolder+":POL_RGB") /WAVE=POL_RGB
//	POL_RGB 	= M_HSL2RGB
//	
//	//Cleanup
////	if (WinType("HSL2RGB") == 7)
//////		KillWindow HSL2RGB
////	endif
////	if (WaveExists(root:SPHINX:Stacks:POL_RGB) == 1)
////		KillWaves POL_RGB
////	endif
////	Duplicate M_HSL2RGB, POL_RGB
////		KillWaves POL_HSL, M_HSL2RGB  //BG Don't kill POL_HSL for the moment
//		
////	SetDataFolder $(StackFolder)
////	ImageTransform hsl2rgb COLORBAR_HSL
//End