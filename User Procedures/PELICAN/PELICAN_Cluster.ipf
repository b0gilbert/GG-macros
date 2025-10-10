// Updated 07.21.2015 19:51
#pragma rtGlobals=1		// Use modern global access method.

// See Word Manual for details! 

Menu "Polarization"
	SubMenu "PELICAN"
		"Pelican/1"
		"Display PELICAN RGB/2"
		"Pelican Scale Circle"
		"Display PELICAN Histograms"
		"Display PELICAN Gizmo"
		"Export PELICAN Figures/E"
		"Export PELICAN Color Bar"
		"Calculate Neighbor Angles/G"
		"K Means Cluster Analysis"
		"Kill Histograms"
	End
End

		

// Necessary global variables
Function MakePELICANVariables()

	if (ImportPELICANDefaults() > -1)
	
		WAVE PELIParameters = root:POLARIZATION:PELIParameters
		
		// The a, b and Phizy min angles
		Variable /G root:POLARIZATION:gAmax 			= PELIParameters[0]
		Variable /G root:POLARIZATION:gBmin 			= PELIParameters[1]
		Variable /G root:POLARIZATION:gBmax 			= PELIParameters[2]
		Variable /G root:POLARIZATION:gPhiZYMin 	= PELIParameters[3]
	
		// Default display Phi and Theta
		Variable /G root:POLARIZATION:gPhiSPmin 	= PELIParameters[4]
		Variable /G root:POLARIZATION:gPhiSPmax 	= PELIParameters[5]
		Variable /G root:POLARIZATION:gThetaSPmin 	= PELIParameters[6]
		Variable /G root:POLARIZATION:gThetaSPmax 	= PELIParameters[7]
		
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
	
end

Function KMeansClusterAnalysis()


End 

// The input for FPClustering is a 2D wave srcWave
// which consists of M rows by N columns where each row represents a point in N-dimensional space. 

Function PeliCluster()

	NVAR gBMin	 			= root:POLARIZATION:gBMin
	
	WAVE POL_BB	 		= root:SPHINX:Stacks:POL_BB
	WAVE POL_PhiSP 		= root:SPHINX:Stacks:POL_PhiSP
	WAVE POL_ThetSP 	= root:SPHINX:Stacks:POL_ThetSP
	
	NVAR gSVDLeft 		= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDRight 		= root:SPHINX:SVD:gSVDRight
	NVAR gSVDTop 		= root:SPHINX:SVD:gSVDTop
	NVAR gSVDBottom 	= root:SPHINX:SVD:gSVDBottom
	
	NewDataFolder /S/O root:POLARIZATION:Cluster
		
		Duplicate /O POL_PhiSP,  POL_KMeans,  POL_FP
		Duplicate /O POL_PhiSP,  POL_ROI
		Redimension /B/U POL_ROI
		
		// Mask out (and count) the pixels with low B
		POL_ROI = 0
		POL_ROI[][] 	= (POL_BB[p][q] < gBMin) ? 1 : 0
		WaveStats /Q /RMD=[gSVDLeft , gSVDRight ][gSVDBottom , gSVDTop ] POL_ROI
//		ImageStats /Q/RECT={gSVDLeft, gSVDRight, gSVDBottom, gSVDTop} POL_ROI
		Variable NMasked 	= V_sum
		
		Variable NX 	= gSVDRight - gSVDLeft
		Variable NY 	= gSVDTop - gSVDBottom
		Variable i, j, k
		
//		Variable NPixels 	= (NX * NY)
		Variable NPixels 	= (NX * NY) - NMasked

		Make /O/S/N=(2,NPixels) KM_pop3, FP_pop3
		
		k = 0
		for (i=gSVDLeft; i<NX;i+=1)
			for (j=gSVDBottom; j<NY;j+=1)
				if (POL_ROI[i][j] == 0)
					KM_pop3[0][k] 			= POL_PhiSP[i][j]
					KM_pop3[1][k] 			= POL_ThetSP[i][j]
					k += 1
				endif
			endfor
		endfor
		MatrixOp /O FP_pop3 = KM_pop3^t
		
		WaveStats /Q/M=1 KM_pop3
		if (V_NumNaNs > 0)
			print "remove nans"
			return 0
		endif
		
		Variable NKMC 	= 9
		KMeans /NCLS=(NKMC)/OUT=2 KM_pop3
		WAVE W_KMMembers = W_KMMembers
		
		Variable MaxRad 	= 30
		FPClustering /CM/MAXR=(MaxRad) /Q/Z FP_pop3
//		FPClustering /CM/MAXC=(NKMC) /Z FP_pop3
		WAVE M_clustersCM = M_clustersCM
		WAVE W_FPClusterIndex = W_FPClusterIndex
		
		POL_KMeans 	= NaN
		POL_FP 			= NaN
		k = 0
		for (i=gSVDLeft; i<NX;i+=1)
			for (j=gSVDBottom; j<NY;j+=1)
				if (POL_ROI[i][j] == 0)
					POL_KMeans[i][j] 		= W_KMMembers[k]
					POL_FP[i][j] 			= W_FPClusterIndex[k]
					k += 1
				endif
			endfor
		endfor
		
		
		Variable NFPClusters = DimSize(M_ClustersCM,0)
		Make /D/O/N=(NFPClusters) FP_PhiSP, FP_ThetaSP
		FP_PhiSP[] 		= M_ClustersCM[p][0]
		FP_ThetaSP[] 	= M_ClustersCM[p][1]
		Make /D/O/N=(NFPClusters,NFPClusters) FP_AngleDiff
		
		Variable NClasses = DimSize(M_KMClasses,1)
		Make /D/O/N=(NClasses) KM_PhiSP, KM_ThetaSP
		Make /D/O/N=(NClasses,NClasses) KM_AngleDiff
		
		Variable PrintFlag = 0
		if (PrintFlag)
			for (i=0;i<NClasses;i+=1)
				String Msg = "Class "+num2str(i)+" : "
				POL_ROI = -1 
				POL_ROI[][] 	= (POL_KMeans[p][q] == i) ? 0 : POL_ROI[p][q]
				ImageStats /R=POL_ROI POL_PhiSP
				KM_PhiSP[i] 	= V_avg
				Msg = Msg + "	Phi-sp = "+num2str(V_avg)+" ± "+num2str(V_sdev)
				ImageStats /R=POL_ROI POL_ThetSP
				KM_ThetaSP[i] 	= V_avg
				Msg = Msg + " 		Theta-sp = "+num2str(V_avg)+" ± "+num2str(V_sdev)
				print Msg
			endfor
		endif
		
		for (i=0;i<NClasses;i+=1)
			for (j=0;j<NClasses;j+=1)
				KM_AngleDiff[i][j] 	= BGAngleBetweenCursors0(KM_PhiSP[i],KM_PhiSP[j],KM_ThetaSP[i],KM_ThetaSP[j])
			endfor
		endfor
		Histogram/B={1,1,90} KM_AngleDiff,KM_AngleDiff_Hist
		
	SetDataFolder root:
End

Window Graph1() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(1099,284,1631,815)
	AppendImage/T :POLARIZATION:Cluster:POL_KMeans
	ModifyImage POL_KMeans ctab= {*,*,Rainbow,0}
	ModifyGraph margin(left)=14,margin(bottom)=14,margin(top)=14,margin(right)=14
	ModifyGraph mirror=2
	ModifyGraph nticks=19
	ModifyGraph minor=1
	ModifyGraph fSize=9
	ModifyGraph standoff=0
	ModifyGraph tkLblRot(left)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
EndMacro




// property={rotationWave, wave }
	// Specifies the 2D Mx4 rotation wave for the markers. 
	// For each marker the rotation wave has a corresponding row of data containing four entries in this order: 
	// the angle in degrees, the rotation axis components in the X, Y, and Z directions.
	
	
Function CreateRandomClusterCoordinates(NVectors)
	Variable NVectors
	
	// Use the KMeans cluster result to color the arrows
	WAVE M_KMClasses 	= root:POLARIZATION:Cluster:M_KMClasses
	WAVE POL_KMeans 	= root:POLARIZATION:Cluster:POL_KMeans
	
	WAVE POL_PhiSP 		= root:SPHINX:Stacks:POL_PhiSP
	WAVE POL_ThetSP 	= root:SPHINX:Stacks:POL_ThetSP
	
	NVAR gSVDLeft 		= root:SPHINX:SVD:gSVDLeft
	NVAR gSVDRight 		= root:SPHINX:SVD:gSVDRight
	NVAR gSVDTop 		= root:SPHINX:SVD:gSVDTop
	NVAR gSVDBottom 	= root:SPHINX:SVD:gSVDBottom
	
	SetDataFolder root:POLARIZATION:Cluster
	
		ColorTab2Wave Rainbow16
		WAVE M_colors 	= root:POLARIZATION:Cluster:M_colors
		
		Make /O/S/N=(NVectors,3) ClusterScatter
		Make /O/S/N=(NVectors,4) ClusterRotation
		Make /O/S/N=(NVectors) ClusterIndex
		Make /O/S/N=(NVectors,4) ClusterColor=0.5
		
		Make /D/FREE/N=3 RotAxis1
		Make /D/FREE/N=(3,3) RotMatrix=0
		
		Variable i, NX, NY, PixelX, PixelY
		NX 	= gSVDRight - gSVDLeft
		NY 	= gSVDTop - gSVDBottom
		
		Variable ThetaSP, PhiSP, Betta
		Variable NKMClasses = DimSize(M_KMClasses,1)
		Variable KMClass, ColorIndex
		
		do
			PixelX = gSVDLeft + NX/2 + enoise(NX/2)
			PixelY = gSVDBottom + NY/2 + enoise(NY/2)
			
			KMClass 	= POL_KMeans[PixelX][PixelY]
			if (numtype(KMClass) == 0)
				ClusterScatter[i][0] 	= 0
				ClusterScatter[i][1] 	= PixelX
				ClusterScatter[i][2] 	= PixelY
				
				// Look up Theta-SP and convert to the angle from the Y-axis
				Betta 			= (pi/180) * (30 - POL_ThetSP[PixelX][PixelY])
				
				// Reset the rotation axis to lie along the -X axis. 
				RotAxis1 	= {-1,0,0}
				
				// Make the rotation matrix to rotate RotAxis1 
				MakeZAxisRotationMatrix(RotMatrix,Betta)
				
				// Apply the rotation 
				ApplyRotationMatrixToVector(RotMatrix,RotAxis1)
				
				// Transfer the rotation information
				ClusterRotation[i][0] 		= POL_PhiSP[PixelX][PixelY]
				ClusterRotation[i][1,3] 	= RotAxis1[q-1]
				
				ColorIndex 	= floor(16 * (POL_KMeans[PixelX][PixelY]/NKMClasses))
				ClusterIndex[i] 			= ColorIndex
				ClusterColor[i][0,2] 	= M_colors[ColorIndex][q]
			
				i +=1 
			endif
		while (i<NVectors)
		
//		for (i=0;i<NVectors;i+=1)
//			PixelX = gSVDLeft + NX/2 + enoise(NX/2)
//			PixelY = gSVDBottom + NY/2 + enoise(NY/2)
//			
//			ClusterScatter[i][0] 	= 0
//			ClusterScatter[i][1] 	= PixelX
//			ClusterScatter[i][2] 	= PixelY
//			
//			// Look up Theta-SP and convert to the angle from the Y-axis
//			Betta 			= (pi/180) * (30 - POL_ThetSP[PixelX][PixelY])
//			
//			// Reset the rotation axis to lie along the -X axis. 
//			RotAxis1 	= {-1,0,0}
//			
//			// Make the rotation matrix to rotate RotAxis1 
//			MakeZAxisRotationMatrix(RotMatrix,Betta)
//			
//			// Apply the rotation 
//			ApplyRotationMatrixToVector(RotMatrix,RotAxis1)
//			
//			// Transfer the rotation information
//			ClusterRotation[i][0] 		= POL_PhiSP[PixelX][PixelY]
//			ClusterRotation[i][1,3] 	= RotAxis1[q-1]
//			
//			ColorIndex 	= floor(16 * (POL_KMeans[PixelX][PixelY]/NKMClasses))
//			ClusterIndex[i] 			= ColorIndex
//			ClusterColor[i][0,2] 	= M_colors[ColorIndex][q]
//		endfor
	
	SetDataFolder root:
End

//property={colorWave, wave }
//	wave  is a 2D wave containing R, G, B, A values in the range [0,1] specifying the color of each marker. 
//	For an Mx3 scatter source wave the colorWave is Mx4 with RGBA values in each row. 
//	For more information see Color Waves.
Function GizmoCluster_Create()

	
	CreateRandomClusterCoordinates(600)
	
	WAVE ClusterScatter 		= root:POLARIZATION:Cluster:ClusterScatter
	WAVE ClusterRotation 	= root:POLARIZATION:Cluster:ClusterRotation
	WAVE ClusterColor 		= root:POLARIZATION:Cluster:ClusterColor
	
	NewGizmo /K=1/T="Gizmo Cluster"/W=(4,53,528,546)
//	ModifyGizmo startRecMacro=700
	ModifyGizmo scalingOption=63
	
	AppendToGizmo attribute blendFunc={770,771},name=blendFunc0
	
	// Append the relevant Stack averaged image
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	WAVE AvgStack 		= $("root:SPHINX:Stacks:"+gStackName+"_av")
	AppendToGizmo Image=AvgStack,name=StackAvg
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ srcType,1}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ cTab,Grays}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ invertCTab,0}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ colorType,0}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ orientation,2}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ rotationType,1}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ rotation,180,0,0,1}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ translationType,1}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ translate,0,0,-0}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ orientation,2}
	
	AppendToGizmo Scatter=ClusterScatter,name=scatter0
	// These 2 lines use a built in color table
//	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ scatterColorType,3}
//	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ markerCTab,Rainbow16}
	// These 2 lines use a color wave
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ scatterColorType,1}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ colorWave,ClusterColor}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ markerType,0}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ sizeType,0}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ rotationType,1}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ Shape,7}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ size,0.75}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ rotationWave,ClusterRotation}
	ModifyGizmo ModifyObject=scatter0,objectType=scatter,property={ objectName,line0}
	
	AppendToGizmo Axes=boxAxes,name=axes0
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={-1,axisScalingMode,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={-1,axisColor,0,0,0,1}
	ModifyGizmo modifyObject=axes0,objectType=Axes,property={-1,Clipped,0}
	
	AppendToGizmo line={0,0,0,0,0,0.04}, name=line0
//	ModifyGizmo ModifyObject=line0,objectType=line,property={ colorType,2}
//	ModifyGizmo ModifyObject=line0,objectType=line,property={ colorValue,0,1,1,0,1}
//	ModifyGizmo ModifyObject=line0,objectType=line,property={ colorValue,1,1,1,0,1}
	
	AppendToGizmo light=Directional,name=light0
	ModifyGizmo modifyObject=light0,objectType=light,property={ position,0.108586,0.884365,0.453990,0.000000}
	ModifyGizmo modifyObject=light0,objectType=light,property={ direction,0.108586,0.884365,0.453990}
	ModifyGizmo modifyObject=light0,objectType=light,property={ specular,1.000000,1.000000,1.000000,1.000000}
	

	ModifyGizmo setDisplayList=0, object=light0
	ModifyGizmo setDisplayList=1, object=StackAvg
	ModifyGizmo setDisplayList=2, object=scatter0
	ModifyGizmo setDisplayList=3, object=axes0
	ModifyGizmo setDisplayList=4, opName=clearColor, operation=clearColor, data={0.8,0.8,0.8,1}
	
	ModifyGizmo autoscaling=1
	ModifyGizmo currentGroupObject=""
	ModifyGizmo showInfo
	ModifyGizmo infoWindow={532,230,1349,533}
	ModifyGizmo showAxisCue=1
	ModifyGizmo endRecMacro
	ModifyGizmo SETQUATERNION={0.234408,0.530854,0.744081,0.331051}
	
	
	
End

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

Function CalculateNeighborAngles()
	
	NVAR gBmin 				= root:POLARIZATION:gBmin
	
	SVAR gStackName 		= root:SPHINX:Browser:gStackName
	WAVE POL_BB 				= root:SPHINX:Stacks:POL_BB
	WAVE POL_PhiSP 			= root:SPHINX:Stacks:POL_PhiSP
	WAVE POL_ThetSP 		= root:SPHINX:Stacks:POL_ThetSP
	
	Variable ANGLEMASK = NumVarOrDefault("root:POLARIZATION:gANGLEMASK",4)	// <-- this is the current Default
//	Variable ANGLEMASK = NumVarOrDefault("root:POLARIZATION:gANGLEMASK",3)	// <-- Default is Load User mask
//	Variable ANGLEMASK = NumVarOrDefault("root:POLARIZATION:gANGLEMASK",4)	// <-- Default is no mask

	ANGLEMASK = 3 // <-- this is the current Default (this overrides and transfers to new pxp's)
	
	Prompt ANGLEMASK, "Mask options", popup, "bMin;Current user mask;Load user mask;none;bMin+;"
	DoPrompt "Neighbor angles calculation", ANGLEMASK
	if (V_flag)
		return 0
	endif
	Variable /G root:POLARIZATION:gANGLEMASK = ANGLEMASK
	NVAR gANGLEMASK = root:POLARIZATION:gANGLEMASK
	
	String LoadMaskName, MaskName 	= gStackName+"_mask"
	Variable NXW, NYW, NX=DimSize(POL_PhiSP,0), NY=DimSize(POL_PhiSP,1)
		
	if (ANGLEMASK==2)	// Check that a mask is loaded
		WAVE MaskWave = $("root:SPHINX:Stacks:"+MaskName)
		if (!WaveExists(MaskWave))
			Print " ** No mask in memory - need to load one"
			ANGLEMASK=3
		endif
	endif
	
	if (ANGLEMASK==3)	// Load a new mask
		SetDataFolder root:SPHINX:Stacks
			KillWaves /Z $("root:SPHINX:Stacks:"+MaskName)
			ImageLoad/P=home/T=tiff/Q
			if (V_flag)
				LoadMaskName = StringFromList(0,S_waveNames)
				WAVE LoadMaskWave 	= $LoadMaskName
				NXW 	= DimSize(POL_PhiSP,0)
				NYW 	= DimSize(POL_PhiSP,1)
				if ((NXW != NX) || (NYW != NY))
					print " *** Loaded mask image has different dimensions than polarization stacks"
					return 0
				endif
				WAVE MaskWave 	= $MaskName
				if (WaveExists(MaskWave))
					MaskWave = LoadMaskWave
				else
					Rename $LoadMaskName, $MaskName
					WAVE MaskWave 	= $MaskName
				endif
				ANGLEMASK=2
				gANGLEMASK=2
			else
				print " *** Mask image not loaded"
				return 0
			endif
			DisplayPeliMask()
		SetDataFolder root:
	endif
	
	Make /FREE/D/N=8 NbrGamma=0 
	
	Duplicate /O/D POL_PhiSP, root:SPHINX:Stacks:POL_AvgGamma
	WAVE POL_AvgGamma 		= root:SPHINX:Stacks:POL_AvgGamma
	
	Duplicate /O/D POL_PhiSP, root:SPHINX:Stacks:POL_MaxGamma
	WAVE POL_MaxGamma 		= root:SPHINX:Stacks:POL_MaxGamma
	
	String HistExportName, HistAxisName, HistDataName
	Variable CosGamma, GammaAngle, phi1, phi2, thet1, thet2, histAvg, HistNm = 0
	
	Variable i, j, m, n, Nbr=0, , NPx=0, NPxNbr=0, TotNPx=NX*NY
	
	VARIABLE USERMASK = 1
	VARIABLE MEASUREPX = 0, USERPOL
	
	DoUpdate /W=AvgGammaAngleHistogram /SPIN=2
	
	POL_AvgGamma = NaN
	POL_MaxGamma = NaN
	for (i=1;i<NX-1;i+=1)
		for (j=1;j<NY-1;j+=1)
			
			// Is the central pixel masked? 
			MEASUREPX = 0
			if (ANGLEMASK==2)
				if ( (MaskWave[i][j][0] == 65535) || (MaskWave[i][j][0] == 255) )
					MEASUREPX = 1
				endif
			elseif (ANGLEMASK==1)
				if (POL_BB[i][j] > gBmin)
					MEASUREPX = 1
				endif
			elseif (ANGLEMASK==4)
					MEASUREPX = 1
			endif
			
			if (MEASUREPX == 1)
				// Count this pixel for normalization purposes (currently not used I think)
				NPx += 1
			
				Nbr 		= 0
				NbrGamma = NaN
				
				// The angles of the central pixel
				phi1 			= POL_PhiSP[i][j] * (pi/180)
				thet1 		= POL_ThetSP[i][j] * (pi/180)
					
				for (m=-1;m<2;m+=1)
					for (n=-1;n<2;n+=1)
						if ( (m==0) && (n==0) )
							// Do nothing - Skip the pixel itself
						else
						
							// Is the neighbor pixel masked? 
							MEASUREPX = 0
							if (ANGLEMASK==2)
								if ( (MaskWave[i+n][j+m][0] == 65535) || (MaskWave[i+n][j+m][0] == 255))
									MEASUREPX = 1
								endif
							elseif (ANGLEMASK==1)
								if (POL_BB[i+n][j+m] > gBmin)
									MEASUREPX = 1
								endif
							elseif (ANGLEMASK==4)
									MEASUREPX = 1
							endif
						
							if (MEASUREPX == 1)
								// The angles of the neighboring pixel
								phi2 		= POL_PhiSP[i+n][j+m] * (pi/180)
								thet2 	= POL_ThetSP[i+n][j+m] * (pi/180)
								
								// Rederived for the chosen angle convention - see instruction document
								CosGamma 		= cos(phi1)*cos(phi2)   +   sin(phi1)*sin(phi2)*cos(thet1-thet2)
								GammaAngle 	= (180/pi) * acos(CosGamma)
								
								NbrGamma[Nbr] = GammaAngle
								Nbr += 1
							endif
			
						endif
					endfor	// Loop through m
				endfor		// Loop through n
				
				if (Nbr > 0)
					WaveStats /Q/M=1 NbrGamma
					POL_AvgGamma[i][j] 	= V_avg
					POL_MaxGamma[i][j] 	= V_max
					NPxNbr += Nbr
					
				endif
				
			endif
			
		endfor	// Loop through i
	endfor		// Loop through j
	
	if (ANGLEMASK==1)
		Print " *** Calculated neighbor angles with bMin mask: Number of pixels =",NPx,"or",100*(NPx/TotNPx),"%"
	elseif (ANGLEMASK==2)
		Print " *** Calculated neighbor angles with user mask: Number of pixels =",NPx,"or",100*(NPx/TotNPx),"%"
	else
		Print " *** Calculated neighbor angles with no mask: Number of pixels =",NPx,"or",100*(NPx/TotNPx),"%"
	endif
	
//	POL_AvgGamma[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_AvgGamma[p][q]
//	POL_MaxGamma[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_MaxGamma[p][q]
		
	Make /O/N=(901)/D root:SPHINX:Stacks:POL_AvgGamma_hist /WAVE=POL_AvgGamma_hist
	Make /O/N=(901)/D root:SPHINX:Stacks:POL_MaxGamma_hist /WAVE=POL_MaxGamma_hist
	SetScale /P x, 90, 0.1, POL_AvgGamma_hist, POL_MaxGamma_hist
	
	// ********* AVERAGE GAMMA ********************************
	Duplicate /FREE POL_AvgGamma, TempArray
	TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_AvgGamma[p][q]
//	Histogram/B=1 TempArray, POL_AvgGamma_hist
	Histogram /B={0.25,0.25,720} TempArray, POL_AvgGamma_hist
	
	histAvg 	= area(POL_AvgGamma_hist)
	POL_AvgGamma_hist /= histAvg
	// *********************************************************
	
	
	// ********* MAXIMUM GAMMA ********************************
	TempArray = POL_MaxGamma
	TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_MaxGamma[p][q]
	
	// First, use an automatic angle spacing so that the fitting is more robust. 
	Histogram /B=1 TempArray, POL_MaxGamma_hist
	
	histAvg 	= area(POL_MaxGamma_hist)
//	print " *** CAUTION - normalization off for debugging"
	POL_MaxGamma_hist /= histAvg
	
	// Second, use a fixed angle spacing so the exported histograms are all on the same axis
	Histogram /B={0.25,0.25,720} TempArray, POL_MaxGamma_hist
	histAvg 	= area(POL_MaxGamma_hist)
	POL_MaxGamma_hist /= histAvg
	
	
	Make /D/FREE/N=3 histStats
	Make /T/FREE/N=3 histStatsLegend = {"Peak position","FWHM","Footprint"}
	Variable CsrPt = NbrAngleHistogramStats(POL_MaxGamma_hist,histStats)
	

//	print " *** CAUTION - alternative normalization off for debugging"
//	Variable PxHistAvg 	= NPxNbr/histAvg
//	POL_MaxGamma_hist *= PxHistAvg
//	print " the area of the histogram should now be equal to the total number of measurements",NPxNbr
	// *********************************************************
	
	DoWindow AvgGammaAngleHistogram
	if (!V_flag)
		DisplayAvgGammaAngleHistogram(POL_AvgGamma_hist,POL_MaxGamma_hist,gStackName)
	endif
	
	CheckDisplayed /W=AvgGammaAngleHistogram fit_POL_MaxGamma_hist
	if (!V_flag)
		AppendToGraph fit_POL_MaxGamma_hist
	endif
	// Cursor/P/H=2/W=AvgGammaAngleHistogram A POL_MaxGamma_hist CsrPt
	
	if (0)	
	//	String HistExportName = gStackName+"_GammaHistograms.csv"
		HistExportName = gStackName+"_MaxGammaHistogram.csv"
		Duplicate /FREE/D POL_AvgGamma_hist, Hist_Axis
		Hist_Axis[] = pnt2x(POL_AvgGamma_hist,p)
		
	//	Save/J/M="\n"/DLIM=","/P=home Hist_Axis,POL_AvgGamma_hist,POL_MaxGamma_hist as HistExportName
		Save/J/M="\n"/DLIM=","/P=home Hist_Axis,POL_MaxGamma_hist as HistExportName
	//	print " 	Saved the histogram of average and maximum pixel neighbor misorientation angles to", HistExportName
		print " 	Saved the histogram of maximum pixel neighbor misorientation angles to", HistExportName
		
	else
		HistExportName = gStackName+"_MaxGammaHistogram.txt"
		HistAxisName 	= gStackName+"_Max_Gamma"
		HistDataName 	= gStackName+"_Frequency"
		Duplicate /O/D POL_MaxGamma_hist, $HistAxisName /WAVE=Hist_Axis
		Duplicate /O/D POL_MaxGamma_hist, $HistDataName /WAVE=Hist_Data
//		Duplicate /O/D POL_AvgGamma_hist, $HistAxisName /WAVE=Hist_Axis
//		Duplicate /O/D POL_AvgGamma_hist, $HistDataName /WAVE=Hist_Data
		Hist_Axis[] = pnt2x(POL_AvgGamma_hist,p)
		
//		Save/J/M="\n"/DLIM=","/P=home/U={0,0,1,0} Hist_Axis,Hist_Data as HistExportName
//		Save/J/M="\n"/DLIM=","/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data as HistExportName
//		Save/J/M="\n"/DLIM=","/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data,histStatsLegend,histStats as HistExportName
		
		// Works 2024-11 
		// Save/J/M="\n"/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data,histStatsLegend,histStats as HistExportName
		
		if(0)
			// Add horizontal orientation - trial 1
			Make /T/N=2/FREE histStats1, histStats2, histStats3
			histStats1[0] = histStatsLegend[0]
			histStats1[1] = num2str(histStats[0])
			histStats2[0] = histStatsLegend[1]
			histStats2[1] = num2str(histStats[1])
			histStats3[0] = histStatsLegend[2]
			histStats3[1] = num2str(histStats[2])
			
			Save/J/M="\n"/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data,histStats1,histStats2,histStats3 as HistExportName
		endif
		
		// Add horizontal orientation - trial 2
		Make /O/D/N=1 Peak_position, FWHM, Footprint
		Peak_position 	= histStats[0]
		FWHM 	= histStats[1]
		Footprint 	= histStats[2]
		
		
		// 2025-08-28 
		String HomeFileList 	= IndexedFile(home,-1,".txt")
		do
			HistNm +=1 
			HistExportName = gStackName+"_MaxGammaHistogram"+num2str(HistNm)+".txt"
		while (WhichListItem(HistExportName,HomeFileList) > -1)
		
		//Save/J/M="\n"/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data,Peak_position,FWHM,Footprint as HistExportName
		Save /I/J/M="\n"/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data,Peak_position,FWHM,Footprint as HistExportName
	endif
	
End

//Function NbrAngleHistogramStats(GammaHist,Center,FWHM,Footprint)
Function NbrAngleHistogramStats(GammaHist,histStats)
	Wave GammaHist, histStats
	
	Variable Center, FWHM, Footprint
	
	Variable histMax, histMaxLoc, fitMinX, fitMinPt, fitMaxX, fitMaxPt
	
	// Find peak is not working reliably 
//	FindPeak /Q GammaHist
//	histMax 		= V_PeakVal
//	histMaxLoc 	= V_PeakLoc
//	// print " 		the histogram center is at ~",histMaxLoc,"of width ~",V_PeakWidth

	WaveStats /Q/M=1/R=[1] GammaHist
	histMax 		= V_max
	histMaxLoc 	= V_maxloc
	
	// Look for the start of the peak, starting from 0
	FindLevel /B=3/Q/EDGE=1 GammaHist, 0.6*histMax
	if (numtype(V_LevelX)==0)
		fitMinX 	= V_LevelX
		fitMinPt 	= x2pnt(GammaHist,V_LevelX)
	else
		fitMinPt = 0
	endif
	
	FindLevel /B=3/Q/EDGE=2/R=(histMaxLoc,180) GammaHist, 0.6*histMax
	fitMaxX 	= V_LevelX
	fitMaxPt 	= x2pnt(GammaHist,V_LevelX)
	
	Make /D/FREE/N=4 AngCoefs = {0,histMax,histMaxLoc,1}
	
	if ((fitMaxPt - fitMinPt) < 3)
		Print " *** Peak fit finder can't ind the peak for fitting. Aborting"
		return 0
	endif
	
	CurveFit /Q LogNormal kwCWave=AngCoefs GammaHist[fitMinPt,fitMaxPt] /D
	Center 	= AngCoefs[2]
	print " 		the log-normal is at ~",AngCoefs[2],"of width ~",AngCoefs[3]


//	ModifyGraph lsize(fit_POL_MaxGamma_hist)=3
	
	PulseStats /Q/L=(histMax/2, histMax/2) GammaHist
	FWHM = V_PulseLoc2 - V_PulseLoc1
	
	PulseStats /Q/L=(histMax/10, histMax/10) GammaHist
	Footprint = V_PulseLoc2 - V_PulseLoc1
	
	String CenterStr, FWHMStr, FootStr
	sprintf CenterStr, "%.2f", Center
	sprintf FWHMStr, "%.2f", FWHM
	sprintf FootStr, "%.2f", Footprint
	
	histStats[0] = str2num(CenterStr)
	histStats[1] = str2num(FWHMStr)
	histStats[2] = str2num(FootStr)
//	print " 		the FWHM is",FWHM,"and Footprint",Footprint
	
	Variable CsrPt = x2pnt(GammaHist,Center)
 
 	return CsrPt
	
End


Function DisplayAvgGammaAngleHistogram(AvgGammaHist,MaxGamma_hist,StackName)
	Wave AvgGammaHist, MaxGamma_hist
	String StackName

//	Display /K=1/W=(397,166,876,697) AvgGammaHist as "Neighbor Angle Histogram for "+StackName
	Display /K=1/W=(783,587,1262,1118) AvgGammaHist as "Neighbor Angle Histogram for "+StackName
	
	AppendToGraph MaxGamma_hist
	DoWindow /C AvgGammaAngleHistogram
	
	ModifyGraph rgb(POL_MaxGamma_hist)=(0,0,65535)
	
	ModifyGraph rgb(POL_AvgGamma_hist)=(2,39321,1)
	ModifyGraph hideTrace(POL_AvgGamma_hist)=1

	ModifyGraph gFont="Helvetica"
	ModifyGraph log(left)=0
	ModifyGraph mirror=2
	ModifyGraph font="Helvetica"
	ModifyGraph fSize=18
	Label left "Normalized Frequency "
	Label bottom "Misorientation Angle γ"
	Legend/C/N=text0/J/F=0/A=MC/X=21.75/Y=40.48 "\\Z17\\s(POL_AvgGamma_hist) Average γ angle\r\\s(POL_MaxGamma_hist) Maximum γ angle"
//	Cursor/P/H=2 A $NameofWave(AvgGammaHist) 6;Cursor/P B $NameofWave(AvgGammaHist) 19
	Cursor/P/H=2 A $NameofWave(AvgGammaHist) 19
	ShowInfo

	CheckBox NbgLogScaleCheck title="Log",pos={4,4},size={45,16},fSize=13,proc=NbrLogProc
End

Function NbrLogProc(CB_Struct) : CheckBoxControl
	STRUCT WMCheckboxAction &CB_Struct
	
	if (CB_Struct.eventcode==2)
		ModifyGraph log(left)=CB_Struct.checked
	endif
	return 0
End

Function DisplayPELICANGizmo()

	GizmoPeli_Create()
	
End

Function GizmoPeli_Test(PhiSP,ThetaSP,PhiZY)
	Variable PhiSP,ThetaSP,PhiZY
	
	ModifyGizmo /N=GizmoPeli opName=rotate_minPhiSPbyX, operation=rotate, data={-PhiSP,1,0,0}
	ModifyGizmo /N=GizmoPeli opName=rotate_plusPhiSPbyX, operation=rotate, data={PhiSP,1,0,0}
	
	Variable ThetaAngle = ThetaSP-30
	ModifyGizmo /N=GizmoPeli opName=rotate_minThetaSPbyZ, operation=rotate, data={-ThetaAngle,0,0,1}
	ModifyGizmo /N=GizmoPeli opName=rotate_plusThetaSPbyZ, operation=rotate, data={ThetaAngle,0,0,1}
	
	ModifyGizmo /N=GizmoPeli opName=rotate_minPhiZYbyY, operation=rotate, data={-PhiZY,0,1,0}
	ModifyGizmo /N=GizmoPeli opName=rotate_plusPhiZYbyY, operation=rotate, data={PhiZY,0,1,0}
	
End

Function GizmoPeli_CsrVector(PixelFlag)
	Variable PixelFlag
	
	DoWindow GizmoPeli
	if (!V_flag)
		return 0
	endif
	
	WAVE NumData 				= root:POLARIZATION:NumData
	
	SVAR gStackName 			= root:SPHINX:Browser:gStackName
	String CsrFolder 				= "root:SPHINX:RGB_"+gStackName
	NVAR gCursorAX 				= $(CsrFolder+":gCursorAX")
	NVAR gCursorAY 				= $(CsrFolder+":gCursorAY")
	
	NVAR gCursorAPhiSP 			= root:POLARIZATION:gCursorAPhiSP
	NVAR gCursorAThetSP 		= root:POLARIZATION:gCursorAThetSP
	
	NVAR gPixelPhiZY			 	= root:POLARIZATION:gPixelPhiZY
	NVAR gPixelRZY 				= root:POLARIZATION:gPixelRZY
	NVAR gPixelPhiSP 				= root:POLARIZATION:gPixelPhiSP
	NVAR gPixelThetaSP 			= root:POLARIZATION:gPixelThetaSP
	NVAR gStackPhiSP 			= root:POLARIZATION:gStackPhiSP
	NVAR gStackThetaSP 			= root:POLARIZATION:gStackThetaSP

	NVAR gGP_NDisplayItems 	= root:POLARIZATION:GizmoPeli:gGP_NDisplayItems
	
	WAVE POL_PhiZY 				= root:SPHINX:Stacks:POL_PhiZY
	WAVE POL_RZY 				= root:SPHINX:Stacks:POL_RZY
	
	// Translation to the position of the A cursor. Apply this to all arrows and axes
	Variable YOffset = 2 * (gCursorAX - NumData[0]/2)/NumData[0]
	Variable ZOffset = 2 * (gCursorAY - NumData[1]/2)/NumData[1]
	ModifyGizmo /N=GizmoPeli opName=translateToCsr, operation=translate, data={0,YOffset,ZOffset,}
	
	// 									The C-axis Vector
	
	Variable PhiAngle, ThetaAngle
	if (PixelFlag == 1)
		PhiAngle 		= gPixelPhiSP
		ThetaAngle 	= gPixelThetaSP-30
	else
		PhiAngle 		= gStackPhiSP
		ThetaAngle 	= gStackThetaSP-30
	endif
	
	// Rotation of PhiSP away from Z-axis around the X-axis
	// Gixmo zero is along Z. Positive angles rotate anticlockwise when viewed from X+ to X-
	ModifyGizmo /N=GizmoPeli opName=rotate_minPhiSPbyX, operation=rotate, data={-PhiAngle,1,0,0}
	ModifyGizmo /N=GizmoPeli opName=rotate_plusPhiSPbyX, operation=rotate, data={PhiAngle,1,0,0}
	
	// Rotation of ThetSP away from the X-ray axis
	// Gizmo zero is along Y. Positive angles rotate clockwise when viewed from Z+ to Z-
	// Need to subtract 30 to align the thetaSP zero with the X-ray axis
	ModifyGizmo /N=GizmoPeli opName=rotate_minThetaSPbyZ, operation=rotate, data={-ThetaAngle,0,0,1}
	ModifyGizmo /N=GizmoPeli opName=rotate_plusThetaSPbyZ, operation=rotate, data={ThetaAngle,0,0,1}
	//	print "rotated C axis by",gCursorAPhiSP,ThetaAngle
	
	// 									The C-axis Projection
	
	Variable PhiZY, RZY
	
	if (PixelFlag == 1)
		PhiZY 	= gPixelPhiZY
		RZY = 0.75 * gPixelRZY
	else
		PhiZY 	= POL_PhiZY[gCursorAX][gCursorAY]
		RZY 	= 0.75 * POL_RZY[gCursorAX][gCursorAY]
	endif
	//	print "PhiZY is",PhiZY,"and RZY is",RZY

	// Rotation of PhiZY away from Z-axis around the Y-axis
	// Gixmo zero is along Z. Positive angles rotate anticlockwise when viewed from Y+ to Y-
	ModifyGizmo /N=GizmoPeli opName=rotate_minPhiZYbyY, operation=rotate, data={-PhiZY,0,1,0}
	ModifyGizmo /N=GizmoPeli opName=rotate_plusPhiZYbyY, operation=rotate, data={PhiZY,0,1,0}
	
	// Scale RZY by 0.5 for Gizmo display 
	Modifygizmo modifyobject=linePhiZY,objectType=line,property={vertex,0,0,0,0,0,RZY}
End

// II-361

Function GizmoPeli_Create()

	DoWindow GizmoPeli
	if (V_flag)
		return 0
	endif
	
	NewDataFolder /S/O root:POLARIZATION:GizmoPeli
	 
		NewGizmo /K=1/N=GizmoPeli /W=(823,91,1890,1008)
		
		ModifyGizmo home={90,150,0}
		ModifyGizmo goHome
		
		ModifyGizmo startRecMacro=700
		ModifyGizmo scalingMode=34
		ModifyGizmo scalingOption=63
		
		GizmoPeli_AddObjects()
		
		// Gizmo will always have these items. 
		ModifyGizmo setDisplayList=0, attribute=blendFunc0
		ModifyGizmo setDisplayList=1, opName=enableBlend, operation=enable, data=3042
		
		// The Image, called StackAvg, with a little offset
		ModifyGizmo setDisplayList=2, opName=translateImageBack, operation=translate, data={-0.01,0,0}
		ModifyGizmo setDisplayList=3, object=StackAvg
		ModifyGizmo setDisplayList=4, opName=translateImageForward, operation=translate, data={0.01,0,0}
		
		// Translation to the A cursor location. Initially zero, will be updated. 
		ModifyGizmo setDisplayList=5, opName=translateToCsr, operation=translate, data={0,0,0}
		
		// A c-axis vector
		ModifyGizmo setDisplayList=6, opName=rotate_plusThetaSPbyZ, operation=rotate, data={0,0,0,1}		// Zero degrees about Z
		ModifyGizmo setDisplayList=7, opName=rotate_minPhiSPbyX, operation=rotate, data={0,1,0,0} 		// Zero degrees about X
		ModifyGizmo setDisplayList=8, object=lineCAxis
		ModifyGizmo setDisplayList=9, opName=rotate_plusPhiSPbyX, operation=rotate, data={0,1,0,0} 		// Zero degrees about X
		ModifyGizmo setDisplayList=10, opName=rotate_minThetaSPbyZ, operation=rotate, data={0,0,0,1}		// Zero degrees about Z
		
		// The main axes in the Sample frame
		ModifyGizmo setDisplayList=11, object=axesSample
		
		// The X-ray polarization plane and the Vector in the plane
		ModifyGizmo setDisplayList=12, opName=rotate_min30byZ, operation=rotate, data={-30,0,0,1}				// Rotation from Sample to Polarization plane
		ModifyGizmo setDisplayList=13, object=planePOL
		ModifyGizmo setDisplayList=14, opName=rotate_plus30byZ, operation=rotate, data={30,0,0,1}			// Undo rotation from Sample to Polarization plane
		
		ModifyGizmo setDisplayList=15, opName=rotate_min30byZ, operation=rotate, data={-30,0,0,1}				// Rotation from Sample to Polarization plane
		ModifyGizmo setDisplayList=16, opName=translate_plus0p75Y, operation=translate, data={0,0.75,0}		// Offset the Polarization plane
		ModifyGizmo setDisplayList=17, opName=rotate_minPhiZYbyY, operation=rotate, data={0,0,1,0}			// Zero degrees about Y
		ModifyGizmo setDisplayList=18, object=linePhiZY
		ModifyGizmo setDisplayList=19, opName=rotate_plusPhiZYbyY, operation=rotate, data={0,0,1,0}			// Undo zero degrees about Y
		ModifyGizmo setDisplayList=20, opName=translate_min0p75Y, operation=translate, data={0,-0.75,0}	// Undo offset the Polarization plane
		ModifyGizmo setDisplayList=21, opName=rotate_plus30byZ, operation=rotate, data={30,0,0,1}			// Undo rotation from Sample to Polarization plane
		
		
		// A single X-ray axis
		ModifyGizmo setDisplayList=22, opName=rotate_min30byZ, operation=rotate, data={-30,0,0,1}
		ModifyGizmo setDisplayList=23, object=axesXray
		ModifyGizmo setDisplayList=24, opName=rotate_plus30byZ, operation=rotate, data={30,0,0,1}
		

		Variable /G gGP_NDisplayItems = 24
		
		ModifyGizmo autoscaling=1
		ModifyGizmo aspectRatio=1
		
	//	ModifyGizmo currentGroupObject=""
	//	ModifyGizmo showInfo
	//	ModifyGizmo infoWindow={2107,568,2924,1256}
	//	ModifyGizmo endRecMacro
	//	ModifyGizmo idleEventQuaternion={-4.28978e-05,6.26733e-05,1.80671e-05,1}
	//	Execute/Q/Z "SetWindow kwTopWin sizeLimit={46,234,inf,inf}" // sizeLimit requires Igor 7 or later
	
		ShowTools
//		ModifyGizmo showInfo
//		ModifyGizmo infoWindow={2107,568,2924,1256}
	
	SetDataFolder root:
End
	



Function GizmoPeli_AddObjects()

	
	// Append the relevant Stack averaged image
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	WAVE AvgStack 		= $("root:SPHINX:Stacks:"+gStackName+"_av")
	AppendToGizmo Image=AvgStack,name=StackAvg
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ srcType,1}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ cTab,Grays}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ invertCTab,0}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ colorType,0}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ orientation,2}
	
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ rotationType,1}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ rotation,180,0,0,1}
	
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ translationType,1}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ translate,0,0,-0}
	ModifyGizmo ModifyObject=StackAvg,objectType=image,property={ orientation,2}
	
	AppendToGizmo attribute blendFunc={770,771},name=blendFunc0
//	AppendToGizmo freeAxesCue={0,0,0,1},name=freeAxesCue0
	
	// ARROW representing the 3D C-axis vector in Spherical Polar coordinates
	if (0)
		// Double length and double header arrow. Confusing
		AppendToGizmo line={0,0,-1,0,0,0.75}, name=lineCAxis
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ colorType,2}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ colorValue,0,1,0,0.8,1}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ colorValue,1,1,0,0.8,1}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ arrowMode,19}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ startArrowHeight,0.2}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ startArrowBase,0.04}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ endArrowHeight,0.2}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ endArrowBase,0.04}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ cylinderStartRadius,0.01}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ cylinderEndRadius,0.01}
	else
		AppendToGizmo line={0,0,0,0,0,0.75}, name=lineCAxis
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ colorType,2}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ colorValue,0,1,0,0.8,1}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ colorValue,1,1,0,0.8,1}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ arrowMode,16}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ endArrowHeight,0.2}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ endArrowBase,0.04}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ cylinderStartRadius,0.01}
		ModifyGizmo ModifyObject=lineCAxis,objectType=line,property={ cylinderEndRadius,0.01}
	endif
	
	// ARROW representing the Projection of the C-axis onto the Polarization plane
	AppendToGizmo line={0,0,0,0,0,0.5}, name=linePhiZY
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ colorType,2}
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ colorValue,0,4.57771e-05,0.8,1.5259e-05,1}
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ colorValue,1,4.57771e-05,0.8,1.5259e-05,1}
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ arrowMode,16}
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ endArrowHeight,0.1}
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ endArrowBase,0.04}
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ cylinderStartRadius,0.01}
	ModifyGizmo ModifyObject=linePhiZY,objectType=line,property={ cylinderEndRadius,0.01}
	
	// The Polarization plane
	AppendToGizmo quad={-0.5,0.75,0.5,0.5,0.75,0.5,0.5,0.75,-0.5,-0.5,0.75,-0.5},name=planePOL
	ModifyGizmo ModifyObject=planePOL,objectType=quad,property={ colorType,1}
	ModifyGizmo ModifyObject=planePOL,objectType=quad,property={ colorValue,0,0,1,0,0.2}
	
	AppendToGizmo Axes=tripletAxes,name=axesSample
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={-1,axisType,-1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisRange,-1,0,0,1,0,0}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisRange,0,-1,0,0,1,0}M
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisRange,0,0,-1,0,0,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={-1,lineWidth,2}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisType,2097153}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisType,2097154}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisType,2097156}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={-1,axisScalingMode,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisColor,0.8,1.5259e-05,1.5259e-05,1}
//	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisColor,0,1,0,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisColor,1,0.499947,0.250019,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisColor,1.5259e-05,0.244434,1,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisLabel,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisLabel,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisLabel,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisLabelText,"Sample Normal"}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisLabelText,"Sample Surface"}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisLabelText,"Vertical"}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisLabelCenter,1.25}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisLabelCenter,1.25}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisLabelCenter,1.25}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisLabelDistance,0}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisLabelDistance,0}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisLabelDistance,0}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisLabelRGBA,0,0,0,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,axisLabelRGBA,0,0,0,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisLabelRGBA,0,0,0,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,axisLabelTilt,45}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,axisLabelTilt,15}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={0,labelBillboarding,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={1,labelBillboarding,1}
	ModifyGizmo ModifyObject=axesSample,objectType=Axes,property={2,labelBillboarding,1}
	ModifyGizmo modifyObject=axesSample,objectType=Axes,property={-1,Clipped,0}

	AppendToGizmo Axes=tripletAxes,name=axesXray
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={-1,axisType,-1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={0,visible,0}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={2,visible,0}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={0,axisRange,-1,0,0,1,0,0}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisRange,0,-1,0,0,1,0}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={2,axisRange,0,0,-1,0,0,1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={0,lineWidth,2}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={0,axisType,2097153}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisType,2097154}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={2,axisType,2097156}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={-1,axisScalingMode,1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={0,axisColor,1,0,0,1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisColor,0,1,0,1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={2,axisColor,0,0,0,1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisLabel,1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisLabelText,"X-ray"}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisLabelCenter,1.25}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisLabelDistance,0}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,axisLabelRGBA,0,0,0,1}
	ModifyGizmo ModifyObject=axesXray,objectType=Axes,property={1,labelBillboarding,1}
	ModifyGizmo modifyObject=axesXray,objectType=Axes,property={-1,Clipped,0}
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

//NewImage root:images:peppers
//ImageTransform/H={330,50}/L={0,255}/S={0,255} root:images:peppers
//NewImage M_HueSegment

Function LocatePixels2(PhiZY)
	Variable PhiZY

	WAVE FP_PhiZY180 	= root:FP_PhiZY180
	
	Duplicate /O FP_PhiZY180, EqualAngles
	EqualAngles = NaN 
End

Function ZeroToNaN(ImageWave)
	Wave ImageWave
	
	Variable i, j, NX=DimSize(ImageWave,0), NY=DimSize(ImageWave,1)
	
	ImageWave[][] 	= (ImageWave[p][q]==0) ? NaN : ImageWave[p][q]
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

// The Main BG PIC Mapping function that creates the fitting panel
Function Pelican()

	
	PathInfo PELIDefaultsPath
	if (V_flag==0)
//		NewPath /O/Q PELIDefaultsPath
		NewPath/O PELIDefaultsPAth "PGilbert_HD:Users:pupa:Library:CloudStorage:Dropbox:Igor Routines:Igor Pro 7 User Files:User Procedures:POLARIZATION:PELEICAN Defaults:"
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
	
//	NVAR gAutoColor 	= root:POLARIZATION:gAutoColor
//	if (gAutoColor)
//		AutoAdjustPELICANRGB()
//	endif
	
	return 1
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

function StopAllMSTimers()

	Variable i
	for (i=0;i<9;i+=1)
		Variable tt = StopMSTimer(i)
	endfor
End

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
	

//	// Alpha is now the "in-plane" polar angle with respect to the z-axis, and in the sample plane
//	POL_AlphaSample[][] 	= (180/pi) * atan2(  sin( (pi/180)*POL_PhiSP[p][q] ) * sin( (pi/180)*POL_ThetaSample[p][q] ) , cos( (pi/180)*POL_PhiSP[p][q] ) )
//	// Beta is now the "out-of-plane" azimuthal angle with respect to the sample normal
//	POL_BetaSample[][] 		= (180/pi) * atan2(  sin( (pi/180)*POL_PhiSP[p][q] ) * cos( (pi/180)*POL_ThetaSample[p][q] ) , sqrt( 1 - (sin( (pi/180)*POL_PhiSP[p][q] ))^2 * (sin( (pi/180)*POL_ThetaSample[p][q] ))^2 ) )
	
End
	
//////////	// PhiPol and PhiZY are the polar angle of the c-axis unit vector relative to the z-axis in the POL plane
//////////	// The convention here is that the fit routine finds 0 < PhiPol < 180 ... NO
//////////	
//////////	// To keep 0 < POL_PhiZY < 180
//////////	POL_PhiZY[][] 		= POL_PhiPol[p][q] < gPhiZYRot ? (180 + POL_PhiPol[p][q]) : POL_PhiPol[p][q]
//////////	
//////////	// This is an important second step
//////////	POL_PhiZY[][] 		= POL_PhiZY[p][q] > (180 + gPhiZYRot) ? (POL_PhiZY[p][q] - 180) : POL_PhiZY[p][q]
//////////	
//////////	POL_PhiZY[][] 		= POL_PhiPol[p][q] < 0 ? (180 + POL_PhiPol[p][q]) : POL_PhiPol[p][q]
//////////	
//////////	// To transform to -90 < POL_PhiZY < 90
//////////	POL_PhiZY[][] 		= (POL_PhiPol[p][q] > 90) ? 180 - POL_PhiPol[p][q] : POL_PhiPol[p][q]
//////////	
//////////	
//////////	// PhiSP is the polar angle of the c-axis unit vector in 3D spherical polar coordinates relative to the z-axis
//////////	POL_PhiSP[][] 		= sign(POL_PhiZY[p][q]) * (180/pi) * acos(  POL_RZY[p][q] * cos( (pi/180) * POL_PhiZY[p][q] )  )
//////////	
//////////	
//////////	// ThetSP is the azimuthal angle of the c-axis unit vector in sperical polars
//////////	// ThetSP lies in the horizonatal (x,y) plane is defined relative to the x-axis (X-ray beam axis)
//////////	POL_ThetSP[][] 	= (POL_PhiZY[p][q]>90) ? (180/pi) * atan(  POL_RZY[p][q] * sin((pi/180) * (180 - POL_PhiZY[p][q])  )  /  sqrt(1 - POL_RZY[p][q]^2)  ) : (180/pi) * atan(  POL_RZY[p][q] * sin((pi/180) * POL_PhiZY[p][q])  /  sqrt(1 - POL_RZY[p][q]^2)  )
//////////	
//////////	// To transform to -90 < POL_PhiZY < 90
//////////	POL_ThetSP[][] 	= (POL_PhiZY[p][q] > 90) ? -1 * POL_ThetSP[p][q] : POL_ThetSP[p][q]
//////////	
//////////	
//////////	POL_PhiSP[][] 		= POL_BB[p][q] < Bmin ? NaN : POL_PhiSP[p][q]
//////////	POL_ThetSP[][] 	= POL_BB[p][q] < Bmin ? NaN : POL_ThetSP[p][q]
	
	// This is the regular normalization
//	POL_RZY[][] 		= (Amax==0) ? POL_Rpol[p][q] : (Amax/POL_AA[p][q]) * POL_Rpol[p][q]		// Plot this as Rba
	// *!*!*! Unknown Non-Linearity ... not very helpful but interesting
//	POL_RZY[][] 		= (Amax==0) ? POL_Rpol[p][q] : sqrt((Amax/POL_AA[p][q])) * POL_Rpol[p][q]		// Plot this as Rba

//	Other earlier stuff
//	PhiZY 		= (PhiPol < gPhiZYRot) ? (180 + PhiPol) : PhiPol			// gPhiZYRot < PhiZY < 180+gPhiZYRot
//	
//	PhiSP 		= acos( Rzy * cos( (pi/180) * (PhiZY)) )
//		
//	if (PhiZY < 0)
//		PhiSP *= -1
//		ThetSP 	= atan( (Rzy * sin( (pi/180) * PhiZY)) / sqrt(1 - Rzy^2))
//		
//	elseif (PhiZY > 90)
//		ThetSP 	= atan( (Rzy * sin( (pi/180) * (180-PhiZY))) / sqrt(1 - Rzy^2))
//	else
//		ThetSP 	= atan( (Rzy * sin( (pi/180) * PhiZY)) / sqrt(1 - Rzy^2))
//	endif
		
		
		
		
	
//	if (UseCprime)
//		POL_PhiZY[][] 		= (POL_PhiPol[p][q] < 0) ? -1 * POL_PhiPol[p][q] : POL_PhiPol[p][q]
//	else
//		POL_PhiZY[][] 		= (POL_PhiPol[p][q] > 90) ? 180 - POL_PhiPol[p][q] : POL_PhiPol[p][q]
//	endif

//	if (UseCprime)
//		POL_ThetSP[][] 	= (POL_C[p][q] < 0) ? -1 * POL_ThetSP[p][q] : POL_ThetSP[p][q]
//	else
//		POL_ThetSP[][] 	= (POL_PhiZY[p][q] > 90) ? -1 * POL_ThetSP[p][q] : POL_ThetSP[p][q]
//	endif

FastOp 

Function newAdjustPELICANRGB()

	String OldDf 		= GetDataFolder(1)

	Variable SwapPhiTheta = 0
	
	
	if (SwapPhiTheta)
		NVAR gThetaSPmin 		= root:POLARIZATION:gPhiSPmin
		NVAR gThetaSPmax 		= root:POLARIZATION:gPhiSPmax
		NVAR gPhiSPmin 			= root:POLARIZATION:gThetaSPmin
		NVAR gPhiSPmax			= root:POLARIZATION:gThetaSPmax
	else
		NVAR gPhiSPmin 			= root:POLARIZATION:gPhiSPmin
		NVAR gPhiSPmax 			= root:POLARIZATION:gPhiSPmax
		NVAR gThetaSPmin 		= root:POLARIZATION:gThetaSPmin
		NVAR gThetaSPmax 		= root:POLARIZATION:gThetaSPmax
	endif
	
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
	Variable X2 	= DimSize(POL_PhiSP,0)
	Variable Y2 	= DimSize(POL_PhiSP,1)
	
	
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
	
	
	
	// —————————— Set the Hue - Channel 0 —————————— 
	Variable PhiSPRange 	= gPhiSPmax - gPhiSPmin
	
	// Adjust the range of Hue to use
	
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
	
	
	
	// —————————— Set the Brightness - Channel 2 —————————— 
	Variable ThetaSPRange 	= gThetaSPmax - gThetaSPmin
		
	
	Variable i, j
	
	for (i=X1;i<X2;i+=1)
		for (j=Y1;j<Y2;j+=1)
		
			aPOL_HSL[i][j][1] 		= SaturationScale * 65535			// 65535 is the max for Saturation 
			
			aPOL_HSL[i][j][0] 		= mod( (POL_PhiSP[i][j]       - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
			
			if (gDark2Light==1)
				
				aPOL_HSL[i][j][2] 	= LightMax -  ( POL_ThetSP[i][j] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
			
			else
			
				aPOL_HSL[i][j][2] 	= LightMin + ( POL_ThetSP[i][j] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
			
			endif
			
			if (POL_BB[i][j] < gBmin)
				aPOL_HSL[i][j][2] 		= 0
			endif
			
			if (POL_RZYSat[i][j] == 1)
				aPOL_HSL[i][j][2] 		= 65535
			endif
			
		endfor 
	endfor
	
	// LOOP 
	
	

			
//	// ... or allow the hue to wrap around 
//	if (gPhiDisplayChoice == 1)
//		aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_PhiZY[p][q]      - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
//	elseif (gPhiDisplayChoice == 2)
//		aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_PhiSP[p][q]       - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
//	else
//		aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_AlphaSample[p][q] - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
//	endif
//
//	
//	if (gDark2Light==1)			// "bright -> dark" setting. DEFAULT
//		if (gThetaAxisZero == 1) 	// DEFAULT
//			aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
//		elseif (gThetaAxisZero == 2)
//			aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
//		else
//			aPOL_HSL[][][2] 	= gLightMax -  ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
//		endif
//	elseif (gDark2Light==2)			// "dark -> bright" setting. Looks better with Offset
//		if (gThetaAxisZero == 1)		// DEFAULT
//			aPOL_HSL[][][2] 	= LightMin + ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
//		elseif (gThetaAxisZero == 2)
//			aPOL_HSL[][][2] 	= LightMin + ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
//		else
//			aPOL_HSL[][][2] 	= ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
//		endif
//	endif
//	
//	// Remove pixels that are likely not crystalline, based on the magnitude of the cos2 signal
//	aPOL_HSL[][][2] 		= POL_BB[p][q] < gBmin ? 0 : aPOL_HSL[p][q][2]
//	
//	// Remove where calculated Rzy > 1
//	aPOL_HSL[][][0,2] 		= (POL_RZYSat[p][q] == 1) ? 65535 : aPOL_HSL[p][q][r]



	SetDataFolder $StackFolder
		ImageTransform hsl2rgb aPOL_HSL
		WAVE M_HSL2RGB = M_HSL2RGB
		aPOL_RGB 	= M_HSL2RGB
		KillWaves M_HSL2RGB
	SetDataFolder $OldDf
	
	
	TrimRGBImage()
	
	PelicanColorScaleBar()
	return 0
	
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

Function AdjustPELICANRGBwithSwap()

	String OldDf 		= GetDataFolder(1)
	
	
	// If SwapPhiTheta == 0 		LIGHTNESS determined by Theta and HUE determined by Phi
	// If SwapPhiTheta == 1 		HUE determined by Theta and LIGHTNESS determined by Phi
	
	Variable SwapPhiTheta = 1
	
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

Function workingAdjustPELICANRGB()

	String OldDf 		= GetDataFolder(1)

	Variable SwapPhiTheta = 1
	
//	if (SwapPhiTheta)
//		NVAR gThetaSPmin 		= root:POLARIZATION:gPhiSPmin
//		NVAR gThetaSPmax 		= root:POLARIZATION:gPhiSPmax
//		NVAR gPhiSPmin 			= root:POLARIZATION:gThetaSPmin
//		NVAR gPhiSPmax			= root:POLARIZATION:gThetaSPmax
//	else
//	endif
	
	NVAR gPhiSPmin 			= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 			= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 		= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 		= root:POLARIZATION:gThetaSPmax
	
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
	Variable PhiSPRange 	= gPhiSPmax - gPhiSPmin
	
	Variable DefaultColor = 0
	
	if (DefaultColor)
		// The default color scale, 0 - 65535, is circular, Red to Red, which can lead to some ambiguity
		if (gPhiDisplayChoice == 1)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiZY[p][q] - gPhiSPmin) * (65535/ PhiSPRange)
		elseif (gPhiDisplayChoice == 2)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiSP[p][q] - gPhiSPmin) * (65535/ PhiSPRange)
		else
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_AlphaSample[p][q] - gPhiSPmin) * (65535/ PhiSPRange)
		endif
		
		// If pixel HSL values lie outside the range, truncate them to the edges of the range. 
		aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) > 65535 ? 65535 : aPOL_HSL[p][q][0]
		aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) < 0 ? 0 : aPOL_HSL[p][q][0]	
	else
		
		// Adjust the range of Hue to use
		
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
		
		// Simple expressions ... 
		// aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiZY[p][q] - gPhiSPmin) * (ColorMaxHue/ PhiSPRange)
		// aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiSP[p][q] - gPhiSPmin) * (ColorMaxHue/ PhiSPRange)
		// aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_AlphaSample[p][q] - gPhiSPmin) * (ColorMaxHue/ PhiSPRange)
			
		// ... or allow the hue to wrap around 
		if (gPhiDisplayChoice == 1)
			aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_PhiZY[p][q]      - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
		elseif (gPhiDisplayChoice == 2)
			aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_PhiSP[p][q]       - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
		else
			aPOL_HSL[X1,X2][Y1,Y2][0] 		= mod( (POL_AlphaSample[p][q] - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
		endif
		
		// If pixel HSL values lie outside the range, truncate them to the edges of the range. 
		// ... IS THIS NEEDED if we are wrapping? 
		Variable Needed=0
		if (Needed)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) > ColorMaxHue ? ColorMaxHue : aPOL_HSL[p][q][0]
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) < 0           ? 0           : aPOL_HSL[p][q][0]	
		endif
	endif
	
	
	// —————————— Set the Brightness - Channel 2 —————————— 
	Variable ThetaSPRange 	= gThetaSPmax - gThetaSPmin
	
	if (gDark2Light==1)			// "bright -> dark" setting. DEFAULT
		if (gThetaAxisZero == 1) 	// DEFAULT
//			aPOL_HSL[][][2] 	= gLightMax -  ( POL_ThetSP[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		elseif (gThetaAxisZero == 2)
//			aPOL_HSL[][][2] 	= gLightMax -  ( POL_ThetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		else
			aPOL_HSL[][][2] 	= gLightMax -  ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
		endif
	elseif (gDark2Light==2)			// "dark -> bright" setting. Looks better with Offset
		if (gThetaAxisZero == 1)		// DEFAULT
//			aPOL_HSL[][][2] 	= ( POL_ThetSP[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMin + ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		elseif (gThetaAxisZero == 2)
//			aPOL_HSL[][][2] 	= ( POL_ThetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMin + ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		else
			aPOL_HSL[][][2] 	= ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
		endif
	endif
//		aPOL_HSL[][][2] 	= ( POL_BetaSP[p][q]/90) * gLightMax
	
	// Threshold any values outside of the display range to the max or min
	Needed=0
	if (Needed)
		aPOL_HSL[][][2] 	= (aPOL_HSL[p][q][2]) > 65535 ? 65535 : aPOL_HSL[p][q][2]
		aPOL_HSL[][][2] 	= (aPOL_HSL[p][q][2]) < 0     ? 0     : aPOL_HSL[p][q][2]
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

Function oldoldAdjustPELICANRGB()

	String OldDf 		= GetDataFolder(1)

	NVAR gPhiSPmin 			= root:POLARIZATION:gPhiSPmin
	NVAR gPhiSPmax 			= root:POLARIZATION:gPhiSPmax
	NVAR gThetaSPmin 		= root:POLARIZATION:gThetaSPmin
	NVAR gThetaSPmax 		= root:POLARIZATION:gThetaSPmax
	
	NVAR gX1 					= root:SPHINX:SVD:gSVDLeft
	NVAR gX2 					= root:SPHINX:SVD:gSVDRight
	NVAR gY1 					= root:SPHINX:SVD:gSVDBottom
	NVAR gY2 					= root:SPHINX:SVD:gSVDTop
	
	NVAR gMarqueeRGB 		= root:POLARIZATION:gMarqueeRGB
	NVAR gClearPol 			= root:POLARIZATION:gClearPol
	NVAR gPhiDisplayChoice 	= root:POLARIZATION:gPhiDisplayChoice
	
	// I think this is no longer needed. 
	Variable X1=0, X2, Y1=0, Y2=0
	if (gMarqueeRGB == 1)
		X1 = gX1
		X2 = gX2
		Y1 = gY1
		Y2 = gY2
	else
		X2 	= DimSize(POL_PhiSP,0)
		Y2 	= DimSize(POL_PhiSP,1)
	endif
	
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
	WAVE /D POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
	WAVE /D POL_ThetaSample 	= $(StackFolder+":POL_ThetaSample")
	
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
//	gLightMax = 65535/2				// 65535/2 is the max for Lightness 
//	gLightMax = 65535					// 65535 is now the max for Lightness 

	// This was introduced to shift the Brightness values, but now is switched off by setting LightOffsetFactor to a large value 
	Variable LightOffsetFactor = NumVarOrDefault("root:POLARIZATION:gLightOffsetFactor",1e9)
	LightOffsetFactor = 1e9
	Variable /G root:POLARIZATION:gLightOffsetFactor = LightOffsetFactor
	
	Variable LightOffset 		= 65535/LightOffsetFactor
	Variable LightMin 			= LightOffset
	Variable LightMax 			= gLightMax + LightOffset
	
	// —————————— Set the Saturation - Channel 1 ———————————
	aPOL_HSL[][][1] = 65535			// 65535 is the max for Saturation 
	
	// —————————— Set the Hue - Channel 0 —————————— 
	Variable PhiSPRange 	= gPhiSPmax - gPhiSPmin
	
	Variable DefaultColor = 0, ColorMaxHue
	
	if (DefaultColor)
		// The default color scale, 0 - 65535, is circular, Red to Red, which can lead to some ambiguity
		if (gPhiDisplayChoice == 1)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiZY[p][q] - gPhiSPmin) * (65535/ PhiSPRange)
		elseif (gPhiDisplayChoice == 2)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiSP[p][q] - gPhiSPmin) * (65535/ PhiSPRange)
		else
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_AlphaSample[p][q] - gPhiSPmin) * (65535/ PhiSPRange)
		endif
		
		// If pixel HSL values lie outside the range, truncate them to the edges of the range. 
		aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) > 65535 ? 65535 : aPOL_HSL[p][q][0]
		aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) < 0 ? 0 : aPOL_HSL[p][q][0]	
	else
		
		// All adjustment of the range of Hue to use
		Variable ColorFraction = NumVarOrDefault("root:POLARIZATION:gColorFraction",1)
		Variable /G root:POLARIZATION:gColorFraction = ColorFraction

		// Enable a rotation of the Hue
		Variable ColorOffset = NumVarOrDefault("root:POLARIZATION:gColorOffset",0.2)
		Variable /G root:POLARIZATION:gColorOffset = ColorOffset
	
		// Use a portion of the range, 0 - F×65535. For F = 0.85, the scale then goes Red to Magenta
//		Variable ColorFraction = 0.95
		ColorMaxHue 	= ColorFraction * 65535
		Variable Offset 	= ColorOffset * PhiSPRange
		if (gPhiDisplayChoice == 1)
//			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiZY[p][q] - gPhiSPmin) * (ColorMaxHue/ PhiSPRange)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	=  mod( (POL_PhiZY[p][q] - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
		elseif (gPhiDisplayChoice == 2)
//			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_PhiSP[p][q] - gPhiSPmin) * (ColorMaxHue/ PhiSPRange)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= mod( (POL_PhiSP[p][q] - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
		else
//			aPOL_HSL[X1,X2][Y1,Y2][0] 	= (POL_AlphaSample[p][q] - gPhiSPmin) * (ColorMaxHue/ PhiSPRange)
			aPOL_HSL[X1,X2][Y1,Y2][0] 	= mod( (POL_AlphaSample[p][q] - gPhiSPmin + Offset)/PhiSPRange, 1) * ColorMaxHue
		endif
		
		// If pixel HSL values lie outside the range, truncate them to the edges of the range. 
		aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) > ColorMaxHue ? ColorMaxHue : aPOL_HSL[p][q][0]
		aPOL_HSL[X1,X2][Y1,Y2][0] 	= (aPOL_HSL[p][q][0]) < 0 ? 0 : aPOL_HSL[p][q][0]	
	endif
	
	
	// —————————— Set the Brightness - Channel 2 —————————— 
	Variable ThetaSPRange 	= gThetaSPmax - gThetaSPmin
	
	if (gDark2Light==1)			// "bright -> dark" setting. DEFAULT
		if (gThetaAxisZero == 1) 	// DEFAULT
//			aPOL_HSL[][][2] 	= gLightMax -  ( POL_ThetSP[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		elseif (gThetaAxisZero == 2)
//			aPOL_HSL[][][2] 	= gLightMax -  ( POL_ThetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMax -  ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		else
			aPOL_HSL[][][2] 	= gLightMax -  ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
		endif
	elseif (gDark2Light==2)			// "dark -> bright" setting. Looks better with Offset
		if (gThetaAxisZero == 1)		// DEFAULT
//			aPOL_HSL[][][2] 	= ( POL_ThetSP[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMin + ( POL_ThetSP[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		elseif (gThetaAxisZero == 2)
//			aPOL_HSL[][][2] 	= ( POL_ThetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
			aPOL_HSL[][][2] 	= LightMin + ( POL_ThetaSample[p][q] - gThetaSPmin) * ( (LightMax-LightMin)/ ThetaSPRange)
		else
			aPOL_HSL[][][2] 	= ( POL_BetaSample[p][q] - gThetaSPmin) * (gLightMax/ ThetaSPRange)
		endif
	endif
//		aPOL_HSL[][][2] 	= ( POL_BetaSP[p][q]/90) * gLightMax
	
	// Threshold any values outside of the display range to the max or min
	aPOL_HSL[][][2] 	= (aPOL_HSL[p][q][2]) > 65535 ? 65535 : aPOL_HSL[p][q][2]
	aPOL_HSL[][][2] 	= (aPOL_HSL[p][q][2]) < 0 ? 0 : aPOL_HSL[p][q][2]
	
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
	
	
	// Update the scaling of the scale bars
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
	
	// IS THIS APPROPRIATE HERE? 
	// Update the displayed pixel angles 
//	NVAR gCursorAPhiSP 	= root:POLARIZATION:gCursorAPhiSP
//	NVAR gCursorAThetSP 	= root:POLARIZATION:gCursorAThetSP
//	NVAR gCursorBPhiSP 	= root:POLARIZATION:gCursorBPhiSP
//	NVAR gCursorBThetSP 	= root:POLARIZATION:gCursorBThetSP
//	
//	SVAR gStackName 	= root:SPHINX:Browser:gStackName
//	NVAR gAX 	= $("root:SPHINX:RGB_"+gStackName+":gCursorAX")
//	NVAR gAY 	= $("root:SPHINX:RGB_"+gStackName+":gCursorAY")
//	NVAR gBX 	= $("root:SPHINX:RGB_"+gStackName+":gCursorBX")
//	NVAR gBY 	= $("root:SPHINX:RGB_"+gStackName+":gCursorBY")
//	
//	gCursorAPhiSP 		= POL_PhiSP[gAX][gAY]
//	gCursorAThetSP 	= POL_ThetSP[gAX][gAY]
//	gCursorBPhiSP 		= POL_PhiSP[gBX][gBY]
//	gCursorBThetSP 	= POL_ThetSP[gBX][gBY]
	
	CsrColorCalculation()
	
	DoWindow PeliScaleCircle
	if (V_flag)
		PelicanScaleCircle()
	endif
End


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
	
//	SetDrawEnv linefgc= (65535,65535,65535)
//	DrawRect 0.451388888888889,0.694444444444444,0.548611111111111,0.819444444444444
	
	SetDrawEnv fstyle= 1
	DrawText 0.483631053261925,0.811349573755108,"0˚"
	
//	SetDrawEnv linefgc= (65535,65535,65535)
//	DrawRect 0.145833333333333,0.75,0.340277777777778,0.902777777777777
	
	SetDrawEnv fsize= 20
	DrawText 0.0818532076921332,0.863066088758783,"𝜃\\Bsp"
	DrawText -0.0719245022936297,0.561349573755109,"-90˚"
End

















Function workingPelicanColorScaleBar()
	
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
	
	
	// -----------------------		Create the HSL calculation arrays 	---------------------
	Make /D/FREE /N=(1000,1000,3) aPOL_HSL_Scale
	Make /D/FREE /N=(100,1000,3) aPOL_HSL_Hue_Scale
	Make /D/FREE /N=(1000,100,3) aPOL_HSL_Bright_Scale
	
	Make /D/FREE /N=(1000,1000,3) aPOL_HSL_Circle
	Make /D/FREE /N=(100,1000,3) aPOL_HSL_Phi_Circle
	Make /D/FREE /N=(1000,100,3) aPOL_HSL_Theta_Circle
	// -------------------------------------------------------------------------------
	
	// The Saturation (Channel 1) is always 65535
	aPOL_HSL_Scale[][][1] 			= 65535						// Constant Saturation for the color bar
	aPOL_HSL_Hue_Scale[][][1] 		= 65535						// Constant Saturation for the color bar
	aPOL_HSL_Bright_Scale[][][1] 	= 0							// Zero Saturation for the Brightness scale bar creates a Gray Scale
 	
	// The Hue (Channel 0) runs from 0 - 65535
	aPOL_HSL_Bright_Scale[][][0] 	= 65535/2 					// Constant Hue for the Brightness scale bar
	
	Variable DefaultColor = 0, ColorMaxHue
	
	if (DefaultColor)
		// The default color scale is circular, which can lead to some ambiguity
		aPOL_HSL_Scale[][][0] 			= (q/1000) * 65535
		aPOL_HSL_Hue_Scale[][][0] 		= (q/1000) * 65535
	else
		// Use a portion of the range: Red to Magenta
		ColorMaxHue = ColorFraction * 65535
		Variable Offset = ColorOffset*1000
		//aPOL_HSL_Scale[][][0] 			= (q/1000) * ColorMaxHue
		//aPOL_HSL_Hue_Scale[][][0] 	= (q/1000) * ColorMaxHue
		aPOL_HSL_Scale[][][0] 			= mod((q+Offset)/1000,1) * ColorMaxHue
		aPOL_HSL_Hue_Scale[][][0] 		= mod((q+Offset)/1000,1) * ColorMaxHue
	endif
	
	// The Brightness (Channel 2) runs from 0 - 65535/2 (or vice versa)
	// aPOL_HSL_Hue_Scale[][][2] 	= 65535/2 				// choose a constant Brightness for the Hue scale bar
	aPOL_HSL_Hue_Scale[][][2] 	= gLightMax/2 				// choose a constant Brightness for the Hue scale bar

	//	Variable LightMax = gLightMax 	// This needs to be 65535/2 in order to show "brightness" not "lightness
	
	// ***** Alter the Lightness Scale 2023-01-05
	// LightOffsetFactor is default set to 1e9 so LightOffset ~ 0
	Variable LightOffset 		= 65535/LightOffsetFactor
	Variable LightMin 			= LightOffset
	Variable LightMax 			= gLightMax + LightOffset
	
	if (gDark2Light==2)		// "dark -> bright" setting
		//aPOL_HSL_Scale[][][2] 				= (p/1000) * LightMax
		//aPOL_HSL_Bright_Scale[][][2] 	= (p/1000) * LightMax
		aPOL_HSL_Scale[][][2] 				= LightMin + (p/1000) * (LightMax-LightMin)
		aPOL_HSL_Bright_Scale[][][2] 		= LightMin + (p/1000) * (LightMax-LightMin)
		
	elseif (gDark2Light==1)
		// aPOL_HSL_Scale[][][2] 			= ((1000-p)/1000) * LightMax
		// aPOL_HSL_Bright_Scale[][][2] 	= ((1000-p)/1000) * LightMax
		aPOL_HSL_Scale[][][2] 				= ((1000-p)/1000) * (LightMax-LightMin) + LightMin
		aPOL_HSL_Bright_Scale[][][2] 		= ((1000-p)/1000) * (LightMax-LightMin) + LightMin
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
			// Add an offset to aPOL_HSL_Bright_Scale
			//	aPOL_HSL_Bright_Scale *=1.8
	ImageTransform hsl2rgb aPOL_HSL_Bright_Scale
	WAVE M_HSL2RGB = M_HSL2RGB
	aPOL_Bright_Scale 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
// 	PelicanScaleCircle(aPOL_RGB_Circle,aPOL_RGB_Phi_Circle,aPOL_RGB_Theta_Circle,gPhiSPmin,gPhiSPmax,gThetaSPmin,gThetaSPmax)
End

// Input angles must be in the range -180 < Phi < 180
//Function PelicanScaleCircle(PhiThetaCircle,PhiCircle,ThetaCircle,PhiMin,PhiMax,ThetaMin,ThetaMax)
//	Wave PhiThetaCircle, PhiCircle, ThetaCircle
//	Variable PhiMin,PhiMax,ThetaMin,ThetaMax
	
Function workingPelicanScaleCircle()

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
	
	Variable NPts 	= 1000//DimSize(PhiCircle,0)
	VAriable ptc 	= trunc(NPts/2)
	Variable i, j, angle, pt1, pt2, radius, radfrac=0.75, radfrac2=0.65, PhiFlag, ThetaFlag, rad2deg=(180/pi)
	
	Variable HueVal, PhiRange = abs(gPhiSPmin-gPhiSPmax)
	Variable LightVal, ThetaRange = abs(gThetaSPmin-gThetaSPmax)

	String StackFolder = "root:SPHINX:Stacks"
	// aPOL_RGB_Circle is the RGB version of a 2D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Circle") /WAVE=PhiThetaCircle
	// aPOL_RGB_Phi_Circle is the RGB version of a 1D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Phi_Circle") /WAVE=PhiCircle
	// aPOL_RGB_Theta_Circle is the RGB version of a 1D scale CIRCLE
	Make /D/O/N=(1000,1000,3) $(StackFolder+":aPOL_RGB_Theta_Circle") /WAVE=ThetaCircle
	
	Make /D/O/N=(NPts,NPts) CircleArray=-1, PhiCircleArray=-1, CompArray=-1
	
	Duplicate /D/FREE PhiCircle, PhiHSLCircle, ThetaHSLCircle, PhiThetaHSLCircle
	
	// Circular scale bar varying the Hue to represent Phi
	// PhiHSLCircle[][][0] 		= 65535		// For the scale bar: The Hue will be varied 
														// For the background: The Hue is irrelevant for max Brightness/Lightness = white 
	PhiHSLCircle[][][1] 			= 65535		// Constant high Saturation
	PhiHSLCircle[][][2] 			= 65535		// For the background: Max Brightness/Lightness = white 
	
	// Circular scale bar varying the Brightness/Lightness to represent Theta
	// ThetaHSLCircle[][][0] 	= 0			// The Hue is irrelevant because zero saturation leads to gray 
	ThetaHSLCircle[][][1] 		= 0			// Zero Saturation
														// For the scale bar: The Brightness will be varied 
	ThetaHSLCircle[][][2] 		= 65535		// For the background: Max Brightness/Lightness = white 
	
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
			
			if (PhiFlag)
				PhiCircleArray[i][j] 		= 1		
					
				HueVal 						= (angle - gPhiSPMin)/PhiRange 		// 0 - 1
				PhiHSLCircle[i][j][0] 	= mod((HueVal+gColorOffset),1) * ColorMaxHue
				PhiHSLCircle[i][j][2] 	= 65535/2	
			endif
			
			if (ThetaFlag)
				CompArray[i][NPts - (NPts/4+j/2)] = 1
				LightVal 							= (angle - gThetaSPMin)/ThetaRange
				if (gDark2Light==2)			// "dark -> bright" setting
//					ThetaHSLCircle[i][j][2] 	= LightVal * gLightMax
					ThetaHSLCircle[i][NPts - (NPts/4+j/2)][2] 	= LightVal * gLightMax
//					CircleArray[i][NPts/4+j/2] = LightVal
					CircleArray[i][NPts - (NPts/4+j/2)] = LightVal
				elseif (gDark2Light==1)
//					ThetaHSLCircle[i][j][2] 	= (1-LightVal) * gLightMax
					ThetaHSLCircle[i][NPts - (NPts/4+j/2)][2] 	= (1-LightVal) * gLightMax
//					CircleArray[i][NPts/4+j/2] = (1-LightVal) * gLightMax
					CircleArray[i][NPts - (NPts/4+j/2)] = (1-LightVal) * gLightMax
				endif
			endif
			
		endfor
	endfor
	
	// Quite a large loop! 
	PhiThetaHSLCircle[pxMin,pxMax][pxMin,pxMax][] 	= (CompArray[p][q] > 0) ? ThetaHSLCircle[p][q][r] : PhiHSLCircle[p][q][r]

	ImageTransform hsl2rgb PhiHSLCircle
	WAVE M_HSL2RGB = M_HSL2RGB
	PhiCircle 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	ImageTransform hsl2rgb ThetaHSLCircle
	WAVE M_HSL2RGB = M_HSL2RGB
	ThetaCircle 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	ImageTransform hsl2rgb PhiThetaHSLCircle
	WAVE M_HSL2RGB = M_HSL2RGB
	PhiThetaCircle 	= M_HSL2RGB
	KillWaves M_HSL2RGB
	
	DisplayPelicanScaleCircle()
End

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



// Extracts the angle-dependent intensity from the stack
Function ExtractPIxel()

	String PanelFolder 		= "root:POLARIZATION:Analysis"
	WAVE spectrum 		= $(PanelFolder + ":spectrum")
	WAVE fit_spectrum 	= $(PanelFolder + ":fit_spectrum")
	
	String StackFolder 		= "root:SPHINX:Stacks"
	SVAR StackName 		= root:SPHINX:Browser:gStackName
	WAVE SPHINXStack 	= $(StackFolder+":"+StackName)
	
	NVAR gCsrX 	= root:SPHINX:Browser:gCursorAX
	NVAR gCsrY 	= root:SPHINX:Browser:gCursorAY
	NVAR gBin 		= root:SPHINX:Browser:gCursorBin
	
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
	WAVE POL_AA 		= $(StackFolder+":POL_AA")
	WAVE POL_BB 			= $(StackFolder+":POL_BB")
	WAVE POL_PhiPol 		= $(StackFolder+":POL_PhiPol")
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
	


// Fit the Cos2 function to all pixels in the Stack. Should only need to be run once. 
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

	
//	PopupMenu ThetaDisplayMenu2 pos={134.00,14.00},title="\\Z13 brightness",value="theta vs x-ray axis;theta vs sample normal;beta vs sample plane;", mode=1, proc=PelicanPanelMenus
//	PopupMenu ThetaDisplayMenu2 pos={402,0},title="\\Z42\\S𝜃\\Z07 ",value="x-ray axis;sample normal;beta;", mode=1, proc=PelicanPanelMenus
	

//	PopupMenu PhiDisplayMenu pos={14.00,12.00},title="\\Z13Hue",value="phi zy;phi sp;alpha;", mode=2, proc=PelicanPanelMenus
//	PopupMenu PhiDisplayMenu pos={318,0},title="\\Z42\\S𝜙\\Z13",value="zy;sp;alpha;", mode=2, proc=PelicanPanelMenus

//	PopupMenu ThetaDisplayMenu1 pos={400,9},title=" ",value="\K(29524,1,58982)bright -> dark;\K(0,0,0)dark -> bright;", mode=gDark2Light, proc=PelicanPanelMenus

//	SetVariable Desaturate,pos={9.00,120.00},size={77.00,19.00},proc=PelicanDisplayVar
//	SetVariable Desaturate,title="↓",fSize=13
//	SetVariable Desaturate,limits={0,1,0.1},value=root:POLARIZATION:gSaturationScale

//	NVAR gCursorARed 	= $(PanelFolder+"gCursorARed")
//	ValDisplay CsrRGBDisplay title="hue",format="%0.5f",pos={22,773},size={70,15},proc=SetStackCursor

//	NVAR gCursorAZ 	= $(PanelFolder+"gCursorAZ")
//	ValDisplay CsrIntDisplay title="hue",format="%0.5f",pos={22,773},size={70,15},proc=SetStackCursor
//	NVAR gCursorAZ 	= $(PanelFolder+"gCursorBZ")
//	
//	// Hmm /H=1 should set Hair style cursor. 
//	Cursor /M/H=1/C=(65535,65535,0) A
//	Cursor /M/H=1/C=(65535,65535,0) B
	
//	Cursor/P/I/H=1/C=(65535,65535,0)/W=RGBImage A aPOL_RGB gCursorAX,gCursorAY
//	Cursor/P/I/H=1/C=(65535,65535,0)/W=RGBImage B aPOL_RGB gCursorBX,gCursorBY
	
//	SetActiveSubwindow $activeWindow
//	Cursor/P/I/W=# A $ImageName gCursorAX,gCursorAY
//	Cursor/P/I/W=# B $ImageName gCursorBX,gCursorBY
//	SetActiveSubwindow ##

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

	String StackFolder = "root:SPHINX:Stacks"
	String POLFolder 	= "root:POLARIZATION"
	
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
		// This POL_ColorWave is not used anymore
//		KillWaves /Z root:POLARIZATION:POL_ColorWave
//		ColorTab2Wave ColdWarm
//		WAVE M_colors = M_Colors
//		Rename M_Colors, POL_ColorWave
		
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

//Function CsrColorCalculationTest(ARed, AGreen, ABlue)
//	Variable ARed, AGreen, ABlue
//	
//	Variable ColorFraction = 0.85, Pt1, Pt2
//	Variable BigG 			= 65535
//	Variable One6th 		= 1000/(6*ColorFraction)
//	Variable Slope 			= 65535/One6th
//	
//	Variable index
//	Variable BrightIndex
//	Variable HueIndex 		// index is the p point between 0 - 999
//	
//	if (ARed == 0)
//		if (AGreen > ABlue) 		// Blue has a positive slope
//			Pt1 = 1000/(3*ColorFraction)
//			Pt2 = 1000/(3*ColorFraction) + 1000/(6*ColorFraction)
//			Index 	= (ABlue/Slope) + Pt1
//		else							// Green has a negative slope
//			Pt1 = 1000/(3*ColorFraction) + 1000/(6*ColorFraction) + 1
//			Pt2 = 2000/(3*ColorFraction)
//			Index = (BigG-AGreen)/Slope + Pt1
//		endif
//	elseif (AGreen == 0)
//		if (ABlue > ARed)		// Red has a positive slope
//			Pt1 = 2000/(3*ColorFraction)
//			Pt2 = 2000/(3*ColorFraction) + 1000/(6*ColorFraction)
//			Index 	= (ARed/Slope) + Pt1
//		else							// Blue has a negative slope
//			Pt1 = 2000/(3*ColorFraction) + 1000/(6*ColorFraction) + 1
//			Pt2 = 999
//			Index = (BigG-ABlue)/Slope + Pt1
//		endif
//	else // Blue = 0
//		if (ARed > AGreen)		// Green has a positive slope
//			Pt1 = 0
//			Pt2 = 1000/(6*ColorFraction)
//			Index 	= (AGreen/Slope) + Pt1
//		else							// Red has a negative slope
//			Pt1 = 1000/(6*ColorFraction) + 1
//			Pt2 = 1000/(3*ColorFraction)
//			Index = (BigG-ARed)/Slope + Pt1
//		endif
//	endif
//	
//	HueIndex 	= index
//	BrightIndex 	= 1000 * max(max(ARed, AGreen), ABlue) / BigG
//	
//	print "Hue index",HueIndex,"and Brightness index",BrightIndex
//	
//	return Index
//End

//Function DisplayPELICANHistograms()
//
//	String StackFolder = "root:SPHINX:Stacks"
//	SVAR gStackName 	= root:SPHINX:Browser:gStackName
//	WAVE POL_AA			= $(StackFolder+":POL_AA")
//	WAVE POL_BB			= $(StackFolder+":POL_BB")
//	WAVE POL_Rpol 		= $(StackFolder+":POL_Rpol")
//	WAVE POL_RZY 		= $(StackFolder+":POL_RZY")
//	WAVE POL_PhiPol 		= $(StackFolder+":POL_PhiPol")
//	WAVE POL_PhiZY 		= $(StackFolder+":POL_PhiZY")
//	WAVE POL_PhiSP 		= $(StackFolder+":POL_PhiSP")
//	WAVE POL_ThetSP 	= $(StackFolder+":POL_ThetSP")
////	WAVE POL_BetaSP 	= $(StackFolder+":POL_BetaSP")
//	
//	WAVE POL_ThetaSample = $(StackFolder+":POL_ThetaSample")
//	WAVE POL_AlphaSample = $(StackFolder+":POL_AlphaSample")
//	WAVE POL_BetaSample 	= $(StackFolder+":POL_BetaSample")
//	
//	WAVE aPOL_Hue_Scale 	= $(StackFolder+":aPOL_Hue_Scale")
//	WAVE aPOL_Bright_Scale 	= $(StackFolder+":aPOL_Bright_Scale")
//	
//	NVAR gBmin				= root:POLARIZATION:gBMin
//	NVAR gX1 					= root:SPHINX:SVD:gSVDLeft
//	NVAR gX2 					= root:SPHINX:SVD:gSVDRight
//	NVAR gY1 					= root:SPHINX:SVD:gSVDBottom
//	NVAR gY2 					= root:SPHINX:SVD:gSVDTop
//
//	CreatePELICAN2DHistograms()
//	WAVE POL_Hist_2D 						= root:POLARIZATION:POL_Hist_2D
//	WAVE POL_Hist_2D_Sym 				= root:POLARIZATION:POL_Hist_2D_Sym
//	WAVE POL_Hist_2D_Sample 			= root:POLARIZATION:POL_Hist_2D_Sample
//	WAVE POL_Hist_2D_Sample_Sym 	= root:POLARIZATION:POL_Hist_2D_Sample_Sym
//	WAVE POL_Hist_2D_Surface 			= root:POLARIZATION:POL_Hist_2D_Surface
//	WAVE POL_Hist_2D_Surface_Sym 	= root:POLARIZATION:POL_Hist_2D_Surface_Sym
//	
//	// What are these for? 
//	WAVE Hist2DExclude 						= root:POLARIZATION:Hist2DExclude
//	WAVE Hist2DExclude2 					= root:POLARIZATION:Hist2DExclude2
//	
//	Make /O/N=(512)/D $(StackFolder+":POL_AA_hist") /WAVE=POL_AA_hist
//	Make /O/N=(512)/D $(StackFolder+":POL_AA_Mhist") /WAVE=POL_AA_Mhist
//	SetScale /P x, 0, 1, POL_AA_hist, POL_AA_Mhist
//	Make /O/N=(512)/D $(StackFolder+":POL_BB_hist") /WAVE=POL_BB_hist
//	Make /O/N=(512)/D $(StackFolder+":POL_BB_Mhist") /WAVE=POL_BB_Mhist
//	SetScale /P x, 0, 1, POL_BB_hist, POL_BB_Mhist
//	
//	// This should be PhiPol not Rpol!
////	Make /O/N=(100)/D $(StackFolder+":POL_Rpol_CRange") /WAVE=POL_Rpol_CRange
////	SetScale /P x, 0, 0.01, POL_Rpol_hist, POL_Rpol_CRange
//	
//	Make /O/N=(100)/D $(StackFolder+":POL_Rpol_hist") /WAVE=POL_Rpol_hist
//	Make /O/N=(100)/D $(StackFolder+":POL_RZY_hist") /WAVE=POL_RZY_hist
//	SetScale /P x, 0, 0.01, POL_Rpol_hist, POL_RZY_hist
//	
//	// As determined by the fitting routine, -90 < PhiPol < 90 (I think). As a check, let the histogram axis be -180 < Phi < 180
//	Make /O/N=(3601)/D $(StackFolder+":POL_PhiPol_hist") /WAVE=POL_PhiPol_hist
//	Make /O/N=(3601)/D $(StackFolder+":POL_PhiZY_hist") /WAVE=POL_PhiZY_hist
//	SetScale /P x, -180, 0.1, POL_PhiZY_hist, POL_PhiPol_hist
//	
//	Make /O/N=(3601)/D $(StackFolder+":POL_PhiSP_hist") /WAVE=POL_PhiSP_hist
//	SetScale /P x, -180, 0.1, POL_PhiSP_hist
//	
//	Make /O/N=(1801)/D $(StackFolder+":POL_ThetSP_hist") /WAVE=POL_ThetSP_hist
//	SetScale /P x, -90, 0.1, POL_ThetSP_hist
//	
//	Make /O/N=(1801)/D $(StackFolder+":POL_ThetaSample_hist") /WAVE=POL_ThetaSample_hist
//	SetScale /P x, -50, 0.1, POL_ThetaSample_hist
//	
////	Make /O/N=(901)/D $(StackFolder+":POL_BetaSP_hist") /WAVE=POL_BetaSP_hist
////	SetScale /P x, 0, 0.1, POL_BetaSP_hist
//	
//	Make /O/N=(1801)/D $(StackFolder+":POL_AlphaSample_hist") /WAVE=POL_AlphaSample_hist
//	SetScale /P x, 0, 0.1, POL_AlphaSample_hist
//	Make /O/N=(1801)/D $(StackFolder+":POL_BetaSample_hist") /WAVE=POL_BetaSample_hist
//	SetScale /P x, -90, 0.1, POL_BetaSample_hist
//	
//	
//	// All the pixels in the stack
//	Histogram/B=2 POL_AA,POL_AA_hist
//	Histogram/B=2 POL_BB,POL_BB_hist
//	Histogram/B=2 POL_PhiPol,POL_PhiPol_hist
//	Histogram/B=2 POL_PhiZY,POL_PhiZY_hist
//	Histogram/B=2 POL_Rpol,POL_Rpol_hist
//	Histogram/B=2 POL_RZY,POL_RZY_hist
//	
//	if (1)
//	
//	Histogram/B=2 POL_PhiSP,POL_PhiSP_hist
//	
//	Histogram/B=2 POL_ThetSP,POL_ThetSP_hist
//	
//	Histogram/B=2 POL_ThetaSample,POL_ThetaSample_hist
//	
////	Histogram/B=2 POL_BetaSP,POL_BetaSP_hist
//	Histogram/B=2 POL_AlphaSample, POL_AlphaSample_hist
//	Histogram/B=2 POL_BetaSample, POL_BetaSample_hist
//	
//	WaveStats /Q/M=1 POL_AlphaSample_hist
//	Variable /G root:POLARIZATION:gAlphaHistMax = V_max
//	WaveStats /Q/M=1 POL_AlphaSample_hist
//	Variable /G root:POLARIZATION:gBetaHistMax = V_max
//	
//	
//	elseif(0)
//		KillWaves /Z POL_PhiPol_hist
//	
//		ImageThreshold /Q/T=(gBMin) POL_BB
//		WAVE M_ImageThresh = M_ImageThresh
//		
//		CreateMasked1DHistogram(M_ImageThresh,POL_PhiPol,POL_PhiPol_hist,"POL_PhiPol_hisy")
//		
////		ImageHistogram /R=M_ImageThresh POL_PhiPol
////		Rename W_ImageHist, POL_PhiPol_hist
//	
//	elseif(0)
//	
//		// Use this to remove pixels that are likely not crystalline
//		Duplicate /FREE/D POL_RZY_hist, TempArray
//	
//		TempArray[][] 		= POL_BB[p][q] < gBmin ? 0 : POL_PhiSP[p][q]
//		Histogram/B=2 TempArray,POL_PhiSP_hist
//		
//		TempArray[][] 		= POL_BB[p][q] < gBmin ? 0 : POL_ThetSP[p][q]
//		Histogram/B=2 TempArray,POL_ThetSP_hist
//		
//		TempArray[][] 		= POL_BB[p][q] < gBmin ? 0 : POL_ThetaSample[p][q]
//		Histogram/B=2 TempArray,POL_ThetaSample_hist
//	//	
//	//	TempArray[][] 		= POL_BB[p][q] < gBmin ? 0 : POL_Rpol[p][q]
//	//	Histogram/B=2 TempArray,POL_Rpol_hist
//	//	
//	//	TempArray[][] 		= POL_BB[p][q] < gBmin ? 0 : POL_RZY[p][q]
//	//	Histogram/B=2 TempArray,POL_RZY_hist
//	endif 
//
//	DoWindow HistAnB
//	if (V_flag != 1)
//		String Title = "A and B histograms for " + gStackName
//		Display /K=1/W=(332,584,667,883) POL_AA_hist, POL_BB_hist as Title
//		DoWindow/C HistAnB
//		ModifyGraph rgb(POL_BB_hist)=(65535,0,0), rgb(POL_AA_hist)=(29524,1,58982)
//		ModifyGraph mirror=2, lsize(POL_BB_hist)=2
//		ModifyGraph fSize(left)=14,fSize(bottom)=16
//		Label left "\\Z16Number"
//		Label bottom "Value"
//		SetAxis bottom 0,256
//		Legend/C/N=text0/J/F=0/B=1/A=MC "\F'Times New Roman'\f02\\Z28\\s(POL_AA_hist) a\r\\s(POL_BB_hist) b"
//	endif
//	
//	DoWindow HistCprojZY
//	if (V_flag != 1)
//		Title = "R(z,y) histogram for " + gStackName
//		Display /K=1/W=(668,587,1003,886) POL_RZY_hist as Title
////		Display /K=1/W=(208,421,543,720) POL_Rpol_hist, POL_RZY_hist as Title
//		DoWindow/C HistCprojZY
////		ModifyGraph rgb(POL_Rpol_hist)=(3,52428,1)
//		ModifyGraph rgb(POL_RZY_hist)=(65535,0,52428)
//		ModifyGraph mirror=2, lsize=2
//		ModifyGraph fSize(left)=14,fSize(bottom)=16
//		Label left "\\Z16Number"
//		Label bottom "Projection Magnitude"
//		SetAxis bottom 0,1.01
//		Legend/C/N=text0/J/B=1 "\Z28\\s(POL_RZY_hist) R\\Bzy"
////		Legend/C/N=text0/J/B=1 "\\Z28\\s(POL_Rpol_hist) R\\BB\\M\r\\Z28\\s(POL_RZY_hist) R\\BBA"
////		Legend/C/N=text0/J/B=1 "\\Z28\\s(POL_Rpol_hist) R\\Bproj\\M\r\\Z28\\s(POL_RZY_hist) R\\BZY"
////		Legend/C/N=text0/J/F=0/B=1/A=MC "\\Z28\\s(POL_Rpol_hist) R\\Bproj"
//	endif
//	
//	DoWindow Hist2D1D
//	if (V_flag != 1)
////		Title = "2D & 1D Histograms of C-axis Spherical Polars for " + gStackName
//		Title = "C-axis Spherical Polars for " + gStackName + " Primary Angles"
//		Display /K=1/W=(1502,89,2026,678)/VERT root:POLARIZATION:Hist2DBack as Title
//		DoWindow/C Hist2D1D
//		
//		// Plot the Theta-SP histogram on the bottom axis with the histogram values plotted on a new Left Axis called ThetaHist
//		AppendToGraph/L=ThetaHist root:SPHINX:Stacks:POL_ThetSP_hist
//		ModifyGraph rgb(POL_ThetSP_hist)=(16385,28398,65535)
//		
//		// Plot the Phi-SP histogram Vertically on a new Axis called HorizCrossing
//		AppendToGraph/VERT/B=HorizCrossing root:SPHINX:Stacks:POL_PhiSP_hist
//		
//		// Add the 2D Histogram
//		AppendImage root:POLARIZATION:POL_Hist_2D
////		ModifyImage POL_Hist_2D ctab= {*,*,ColdWarm,0}
//		ModifyImage POL_Hist_2D ctab= {*,*,CyanMagenta,0}
//		
//		// Choose not to add the Symmetric versions of the histogram
////		AppendImage root:POLARIZATION:POL_Hist_2D_Sym
////		ModifyImage POL_Hist_2D_Sym ctab= {*,*,ColdWarm,0}
//		
//		// Set the spatial extent of Left Axes
//		ModifyGraph axisEnab(ThetaHist)={0.75,1}
//		ModifyGraph axisEnab(left)={0,0.75}
//		// Set the spatial extent of Bottom Axes
//		ModifyGraph axisEnab(bottom)={0,0.75}
//		ModifyGraph axisEnab(HorizCrossing)={0.75,1}
//		
//		// Modify Theta-SP histogram and ThetaHist
//		ModifyGraph freePos(THetaHist)=0
//		ModifyGraph freePos(HorizCrossing)=0
//		
//		ModifyGraph axRGB(THetaHist)=(65535,65535,65535) // needed?
//		ModifyGraph axRGB(HorizCrossing)=(65535,65535,65535)
//		
//		// Modify HorizCrossing
//		ModifyGraph noLabel(HorizCrossing)=2
//		
//		ModifyGraph hideTrace(Hist2DBack)=2
//		ModifyGraph grid(left)=1,grid(bottom)=1
//		ModifyGraph mirror(left)=0,mirror(bottom)=0
//		ModifyGraph nticks(THetaHist)=0,nticks(HorizCrossing)=0
//		ModifyGraph lblPos(left)=74,lblPos(bottom)=50
//		ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,0}
//		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}
//		Label left "\\Z22𝜙\\Bsp"
//		Label bottom "\\Z22𝜃\\Bsp"
//		ModifyGraph lblRot(left)=-90
//		SetAxis/A/R left *,0
//		Cursor/P/I/H=1/C=(65535,0,52428) A POL_Hist_2D 108,263
//		Cursor/P/I/H=1/C=(65535,0,52428) B POL_Hist_2D 70,151
//		
//		// Add the partial color bars 
//		AppendImage/B=HorizCrossing aPOL_Hue_Scale
//		AppendImage/L=ThetaHist aPOL_Bright_Scale
//		
//		ColorScale/C/N=text0/X=3.17/Y=-37.33 image=POL_Hist_2D, heightPct=20, width=10
//		ColorScale/C/N=text0 nticks=2, lowTrip=0.001
//		ColorScale/C/N=text0 "Norm # Pixels"
//	endif
//	
//	DoWindow Hist2D1D_Sample
//	if (V_flag != 1)
//		Title = "Sample-Normal C-Axis Angle Histograms for " + gStackName
//		Display /K=1/W=(1502,89,2026,678)/VERT root:POLARIZATION:Hist2DBack as Title
//		ModifyGraph hideTrace(Hist2DBack)=2
//		DoWindow/C Hist2D1D_Sample
//		
//		AppendToGraph/L=ThetaHist root:SPHINX:Stacks:POL_ThetaSample_hist
//		AppendToGraph/VERT/B=HorizCrossing root:SPHINX:Stacks:POL_PhiSP_hist
//		
//		AppendImage root:POLARIZATION:Hist2DExclude
//		ModifyImage Hist2DExclude ctab= {*,10,Grays,1}
//		
//		AppendImage root:POLARIZATION:POL_Hist_2D_Sample
//		ModifyImage POL_Hist_2D_Sample ctab= {*,*,CyanMagenta,0}
//		// ColdWarm
//		
//		AppendImage root:POLARIZATION:POL_Hist_2D_Sample_Sym
//		ModifyImage POL_Hist_2D_Sample_Sym ctab= {*,*,CyanMagenta,0}
//		
//		ModifyGraph rgb(POL_ThetaSample_hist)=(16385,28398,65535)
//		
//		ModifyGraph grid(left)=1,grid(bottom)=1
//		ModifyGraph mirror(left)=0,mirror(bottom)=0
//		ModifyGraph nticks(ThetaHist)=0,nticks(HorizCrossing)=0
//		ModifyGraph noLabel(HorizCrossing)=2
//		ModifyGraph axRGB(ThetaHist)=(65535,65535,65535),axRGB(HorizCrossing)=(65535,65535,65535)
//		ModifyGraph lblPos(left)=74,lblPos(bottom)=50
//		ModifyGraph freePos(ThetaHist)=0
//		ModifyGraph freePos(HorizCrossing)=0
//		ModifyGraph axisEnab(left)={0,0.75}
//		ModifyGraph axisEnab(bottom)={0,0.75}
//		ModifyGraph axisEnab(ThetaHist)={0.75,1}
//		ModifyGraph axisEnab(HorizCrossing)={0.75,1}
//		ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,0}
//		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}
//		Label left "\\Z22𝜙\\Bsp"
//		Label bottom "\\Z22𝜃\\Bsample"
//		ModifyGraph lblRot(left)=-90
//		SetAxis/A/R left *,0
//		Cursor/P/I/H=1/C=(65535,0,52428) A POL_Hist_2D_Sample 108,263
//		Cursor/P/I/H=1/C=(65535,0,52428) B POL_Hist_2D_Sample 70,151
//		
//		// Add the partial color bars 
//		AppendImage/B=HorizCrossing aPOL_Hue_Scale
//		AppendImage/L=ThetaHist aPOL_Bright_Scale
//		
//		ColorScale/C/N=text0/X=3.17/Y=-37.33 image=POL_Hist_2D_Sample, heightPct=20, width=10
//		ColorScale/C/N=text0 nticks=2, lowTrip=0.001
//		ColorScale/C/N=text0 "Norm # Pixels"
//	endif
//	
//	DoWindow Hist2D1D_Surface
//	if (V_flag != 1)
//		Title = "Sample-Surface C-Axis Angle Histograms for " + gStackName
//		Display /K=1/W=(1502,89,2026,678)/VERT root:POLARIZATION:Hist2DBack as Title
//		ModifyGraph hideTrace(Hist2DBack)=2
//		DoWindow/C Hist2D1D_Surface
//		
//		AppendToGraph/L=ThetaHist root:SPHINX:Stacks:POL_BetaSample_hist
//		AppendToGraph/VERT/B=HorizCrossing root:SPHINX:Stacks:POL_AlphaSample_hist
//		
//		AppendImage root:POLARIZATION:Hist2DExclude2
//		ModifyImage Hist2DExclude2 ctab= {*,10,Grays,1}
//		
//		AppendImage root:POLARIZATION:POL_Hist_2D_Surface
//		ModifyImage POL_Hist_2D_Surface ctab= {*,*,CyanMagenta,0}
//		
//		AppendImage root:POLARIZATION:POL_Hist_2D_Surface_Sym
//		ModifyImage POL_Hist_2D_Surface_Sym ctab= {*,*,CyanMagenta,0}
//		
//		ModifyGraph rgb(POL_BetaSample_hist)=(16385,28398,65535)
//		
//		ModifyGraph grid(left)=1,grid(bottom)=1
//		ModifyGraph mirror(left)=0,mirror(bottom)=0
//		ModifyGraph nticks(ThetaHist)=0,nticks(HorizCrossing)=0
//		ModifyGraph noLabel(HorizCrossing)=2
//		ModifyGraph axRGB(ThetaHist)=(65535,65535,65535),axRGB(HorizCrossing)=(65535,65535,65535)
//		ModifyGraph lblPos(left)=110,lblPos(bottom)=50
//		ModifyGraph freePos(ThetaHist)=0
//		ModifyGraph freePos(HorizCrossing)=0
//		ModifyGraph axisEnab(left)={0,0.75}
//		ModifyGraph axisEnab(bottom)={0,0.75}
//		ModifyGraph axisEnab(ThetaHist)={0.75,1}
//		ModifyGraph axisEnab(HorizCrossing)={0.75,1}
//		ModifyGraph manTick(left)={0,45,0,0},manMinor(left)={0,0}
//		ModifyGraph manTick(bottom)={0,45,0,0},manMinor(bottom)={0,0}
//		Label left "\\Z22𝛼\\Bsurface"
//		Label bottom "\\Z22𝛽\\Bsurface"
//		ModifyGraph lblRot(left)=-90
//		SetAxis/A/R left *,0
//		SetAxis/R bottom 90,-60
//		Cursor/P/I/H=1/C=(65535,0,52428) A POL_Hist_2D_Surface 108,263
//		Cursor/P/I/H=1/C=(65535,0,52428) B POL_Hist_2D_Surface 70,151
//		
//		// Add the partial color bars 
//		AppendImage/B=HorizCrossing aPOL_Hue_Scale
//		AppendImage/L=ThetaHist aPOL_Bright_Scale
//		
//		ColorScale/C/N=text0/X=3.17/Y=-37.33 image=POL_Hist_2D_Surface, heightPct=20, width=10
//		ColorScale/C/N=text0 nticks=2, lowTrip=0.001
//		ColorScale/C/N=text0 "Norm # Pixels"
//	endif
//End





// ================== These are the Ross DeVol Routines =================================================

	// Explanations of c' and PhiPol angles
	// Cprime 1 is the way that RDV calculated the polarization angle from the PIC measurements
	// Cprime 2 is an alternative way using the RDV approach
	// PhiPol is the simplest way, which is to use the appropriate fit parameter. 
	
	// Now we need to decide the range of PhiPol angles will be considered PhiZY and ThetZY angles
	// To start with, 0 < PhiPol < 180. However, there is the option to change the range using PhiPolmin < PhiPol < PhiPolmin + 180
	
	// Tricky. Seems like a stupid way to do things, but provides consistency with explanations
	// First we need to convert -90 < c' < 90 to 0 < PhiPol < 180
	//  ** No! ** Now this is done in the FitPIC routine
//	PhiPol 	= (Cprime < 0) ? 180 - Cprime : Cprime
	
//	// Then we need to essentially re-calculate -90 < PhiZY < 90 !*!*!*!*!*!*!* I think this is wrong
//	if (PhiPol > 90)
//		PhiZY 		= PhiPol-180
//		PhiSP 		= acos( Rzy * cos( (pi/180) * PhiZY) )
//		ThetSP 	= atan( -1 * Rzy * sin( (pi/180) * PhiZY) )
//	else
//		PhiZY 		= PhiPol
//		PhiSP 		= acos( Rzy * cos( (pi/180) * PhiZY))
//		ThetSP 	= atan( Rzy * sin( (pi/180) * PhiZY) )
//	endif
	
	// Note that PhiPol can be less than zero, so we need to map onto positive domain
//		PhiZY 		= PhiPol
//		PhiSP 		= acos( Rzy * cos( (pi/180) * PhiZY))
//		ThetSP 	= atan( Rzy * sin( (pi/180) * PhiZY) )
// ================== These are the Ross DeVol Routines =================================================
		
// ================== These are the STACK Routines =================================================
	// PhiSP is the polar angle of the c-axis unit vector in 3D spherical polar coordinates relative to the z-axis
//	POL_PhiSP[][] 		= (180/pi) * acos(  POL_RZY[p][q] * cos((pi/180) * POL_PhiZY[p][q])  )
	
	// ThetSP is the azimuthal angle of the c-axis unit vector in sperical polars
	// ThetSP lies in the horizonatal (x,y) plane is defined relative to the x-axis (X-ray beam axis)
//	POL_ThetSP[][] 	= (180/pi) * atan(  POL_RZY[p][q] * sin((pi/180) * POL_PhiZY[p][q])  /  sqrt(1 - POL_RZY[p][q]^2)  )
//================== These are the STACK Routines =================================================





// functional panel Oct 31

//Function /S PELICANDisplay(RGBImage,Title,Folder,NumX,NumY)
//	Wave RGBImage
//	String Title,Folder
//	Variable NumX,NumY
//	
//	
//	// Reuse the RGB Image display
//	String PanelName = RGBDisplayPanel(RGBImage,Title,Folder,NumX,NumY,PosnStr="px1=761;py1=53;px2=1339;py2=853;swx1=7;swy1=182;swx2=647;swy2=756;")
//	Button ImageSaveButton,pos={500,763}
//	
//	PelicanColorScaleBar()
//	
//	WAVE aPOL_RGB_Scale = root:SPHINX:Stacks:aPOL_RGB_Scale
//	Display/W=(96,34,263,180)/HOST=# 
//		AppendImage root:SPHINX:Stacks:aPOL_RGB_Scale
//		ModifyImage aPOL_RGB_Scale ctab= {*,*,Grays,0}
//		ModifyGraph margin(left)=14,margin(bottom)=14,margin(top)=14,margin(right)=14,wbRGB=(61166,61166,61166)
//		ModifyGraph tick=3, mirror=2, noLabel=2
//		RenameWindow #,G0
//	SetActiveSubwindow ##
//	
//	SetVariable SetPhiMin,pos={6,46},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16Φ\\Bmin"
//	SetVariable SetPhiMin,fSize=13,limits={-180,180,5},value= root:POLARIZATION:gPhiSPmin
//	SetVariable SetPhiMax,pos={6,143},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16Φ\\Bmax"
//	SetVariable SetPhiMax,fSize=13,limits={-180,180,5},value= root:POLARIZATION:gPhiSPmax
//	
//	SetVariable SetThetaMin,pos={73,12},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16θ\\Bmin"
//	SetVariable SetThetaMin,fSize=13,limits={-90,180,5},value= root:POLARIZATION:gThetaSPmin
//	SetVariable SetThetaMax,pos={179,12},size={90.00,26.00},proc=PelicanDisplayVar,title="\\Z16θ\\Bmax"
//	SetVariable SetThetaMax,fSize=13,limits={-90,180,5},value= root:POLARIZATION:gThetaSPmax
//	
//	// Choice of displaying either in-polarization-plane or spherical-polar phi angle
//	MakeVariableIfNeeded("root:POLARIZATION:gPhiDisplayChoice",2)
//	PopupMenu PhiDisplayMenu pos={318,0},title="\\Z13Hue",value="phi zy;phi sp;alpha;", mode=2, proc=PelicanPanelMenus
////	PopupMenu PhiDisplayMenu pos={318,0},title="\\Z42\\S𝜙\\Z13",value="zy;sp;alpha;", mode=2, proc=PelicanPanelMenus
//	
//	MakeVariableIfNeeded("root:POLARIZATION:gThetaAxisZero",1)	
//	PopupMenu ThetaDisplayMenu2 pos={402,0},title="\\Z13 brightness",value="theta vs x-ray axis;theta vs sample normal;beta vs sample plane;", mode=1, proc=PelicanPanelMenus
////	PopupMenu ThetaDisplayMenu2 pos={402,0},title="\\Z42\\S𝜃\\Z07 ",value="x-ray axis;sample normal;beta;", mode=1, proc=PelicanPanelMenus
//	
//	// Choice of displaying in-plane or spherical polar phi angle
//	MakeVariableIfNeeded("root:POLARIZATION:gDark2Light",2)	
//	PopupMenu ThetaDisplayMenu1 pos={408,35},title=" ",value="bright -> dark;dark -> bright;", mode=2, proc=PelicanPanelMenus
//	
//	
//	SetWindow $PanelName, hook(PanelCursorHook)=PELICANCursorHooks 	//BrowserCursorHooks
//	
//	String PanelFolder 	= StringByKey("PanelFolder",GetUserData(PanelName,"",""),"=",";")
//	NVAR gCursorAX 	= $(PanelFolder+":gCursorAX")
//	NVAR gCursorAY 	= $(PanelFolder+":gCursorAY")
//	NVAR gCursorBX 	= $(PanelFolder+":gCursorBX")
//	NVAR gCursorBY 	= $(PanelFolder+":gCursorBY")
//	SetVariable CursorXSetVar,title="A X",pos={275,55},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorAX
//	SetVariable CursorYSetVar,title="A Y",pos={275,80},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorAY
//	SetVariable CursorBXSetVar,title="B X",pos={395,55},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorBX
//	SetVariable CursorBYSetVar,title="B Y",pos={395,80},size={80,15},fSize=13,proc=SetStackCursor,value=gCursorBY
//	
//	MakeVariableIfNeeded("root:POLARIZATION:gCursorAPhiSP",0)
//	MakeVariableIfNeeded("root:POLARIZATION:gCursorBPhiSP",0)
//	MakeVariableIfNeeded("root:POLARIZATION:gCursorAThetSP",0)
//	MakeVariableIfNeeded("root:POLARIZATION:gCursorBThetSP",0)
//	MakeVariableIfNeeded("root:POLARIZATION:gCursorAThetaSample",0)
//	MakeVariableIfNeeded("root:POLARIZATION:gCursorBThetaSample",0)
//	
//	NVAR gCursorAPhiSP 		= $("root:POLARIZATION:gCursorAPhiSP")
//	NVAR gCursorAThetSP 	= $("root:POLARIZATION:gCursorAThetSP")
//	NVAR gCursorBPhiSP 		= $("root:POLARIZATION:gCursorBPhiSP")
//	NVAR gCursorBThetSP 	= $("root:POLARIZATION:gCursorBThetSP")
//	ValDisplay APhiVal title="A \Z16𝜙",pos={275,105},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorAPhiSP"
//	ValDisplay AThetVal title="A \Z16𝜃",pos={275,130},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorAThetSP"
//	ValDisplay BPhiVal title="B \Z16𝜙",pos={395,105},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorBPhiSP"
//	ValDisplay BThetVal title="B \Z16𝜃",pos={395  ,130},size={80,15},fSize=13,value=#"root:POLARIZATION:gCursorBThetSP"
//	
//	MakeVariableIfNeeded("root:POLARIZATION:gTwoCursorGamma",0)
//	ValDisplay Pol2PixelGamma title="\Z22𝛾",pos={355,150},size={80,15},fSize=13,value=#"root:POLARIZATION:gTwoCursorGamma"
//
//	Button TransferZoomButton,pos={206,771}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"
//	Button TransferCrsButton,pos={246,771}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
//	
//	NVAR gCursorARed 	= $(PanelFolder+"gCursorARed")
//	ValDisplay CsrRGBDisplay title="hue",format="%0.5f",pos={22,773},size={70,15},proc=SetStackCursor
//	
//	
//	
//	NVAR gCursorAZ 	= $(PanelFolder+"gCursorAZ")
//	ValDisplay CsrIntDisplay title="hue",format="%0.5f",pos={22,773},size={70,15},proc=SetStackCursor
//	NVAR gCursorAZ 	= $(PanelFolder+"gCursorBZ")
//		
//	return PanelName
//End




//Function CalculateNeighborAngles()
//	
//	NVAR gBmin 				= root:POLARIZATION:gBmin
//	
//	SVAR gStackName 		= root:SPHINX:Browser:gStackName
//	WAVE POL_BB 				= root:SPHINX:Stacks:POL_BB
//	WAVE POL_PhiSP 			= root:SPHINX:Stacks:POL_PhiSP
//	WAVE POL_ThetSP 		= root:SPHINX:Stacks:POL_ThetSP
//	
//	Make /FREE/D/N=8 NbrGamma=0 
//	
//	Duplicate /O/D POL_PhiSP, root:SPHINX:Stacks:POL_AvgGamma
//	WAVE POL_AvgGamma 		= root:SPHINX:Stacks:POL_AvgGamma
//	
//	Duplicate /O/D POL_PhiSP, root:SPHINX:Stacks:POL_MaxGamma
//	WAVE POL_MaxGamma 		= root:SPHINX:Stacks:POL_MaxGamma
//	
//	String HistExportName, HistAxisName, HistDataName
//	Variable CosGamma, GammaAngle, AvgGam, phi1, phi2, thet1, thet2, histAvg
//	Variable i, j, m, n, Nbr=0, , NPx=0, NX=DimSize(POL_PhiSP,0), NY=DimSize(POL_PhiSP,1)
//	
//	VARIABLE USERMASK = 1
//	VARIABLE MEASUREPX = 0, USERPOL
//	WAVE POLMASK = root:S165AN_mask
//	
//	POL_AvgGamma = NaN
//	for (i=1;i<NX-1;i+=1)
//		for (j=1;j<NY-1;j+=1)
//			
//			AvgGam 	= 0
//			Nbr 		= 0
//			NbrGamma = NaN
//			for (m=-1;m<2;m+=1)
//				
//				phi1 			= POL_PhiSP[i][j] * (pi/180)
//				thet1 		= POL_ThetSP[i][j] * (pi/180)
//					
//				for (n=-1;n<2;n+=1)
//				
//					if ( (m==0) && (n==0) )
//						// Skip the pixel itself
//						
//						MEASUREPX = 0
//						USERPOL 	= POLMASK[i][j][0]
//						if ( (USERMASK==1) && (POLMASK[i][j][0] == 255) )
//							// Only consider neighbors that are not masked according to User
//							MEASUREPX = 1
//							
//						elseif (POL_BB[i][j] > gBmin)
//							// Only consider neighbors that are not masked according to gBmin
//							MEASUREPX = 1
//							
//						endif
//						
//						if (MEASUREPX==1)
//							phi2 		= POL_PhiSP[i+n][j+m] * (pi/180)
//							thet2 	= POL_ThetSP[i+n][j+m] * (pi/180)
//							
//							// I rederived this for the chosen angle convention - see instruction document
//							CosGamma 		= cos(phi1)*cos(phi2)   +   sin(phi1)*sin(phi2)*cos(thet1-thet2)
//							GammaAngle 	= (180/pi) * acos(CosGamma)
//							
//							AvgGam += GammaAngle
//							
//							NbrGamma[Nbr] = GammaAngle
//							Nbr += 1
//						endif
//						
//					endif
//					
//				endfor
//				
////				if (POL_BB[i][j] > gBmin)
//				if (MEASUREPX==1)
//					NPx += 1
//				endif
//			endfor
//			
//			WaveStats /Q/M=1 NbrGamma
//			
//			POL_AvgGamma[i][j] 	= V_avg
//			POL_MaxGamma[i][j] 	= V_max
//			
//		endfor
//		
//	endfor
//	
//	POL_AvgGamma[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_AvgGamma[p][q]
//	POL_MaxGamma[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_MaxGamma[p][q]
//		
//	Make /O/N=(901)/D root:SPHINX:Stacks:POL_AvgGamma_hist /WAVE=POL_AvgGamma_hist
//	Make /O/N=(901)/D root:SPHINX:Stacks:POL_MaxGamma_hist /WAVE=POL_MaxGamma_hist
//	SetScale /P x, 90, 0.1, POL_AvgGamma_hist, POL_MaxGamma_hist
//	
//	Duplicate /FREE POL_AvgGamma, TempArray
//	TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_AvgGamma[p][q]
//	Histogram/B=1 TempArray, POL_AvgGamma_hist
//	
//	histAvg 	= area(POL_AvgGamma_hist)
//	POL_AvgGamma_hist /= histAvg
////	POL_AvgGamma_hist /= NPx
//	
//	TempArray = POL_MaxGamma
//	TempArray[][] 	= POL_BB[p][q] < gBmin ? NaN : POL_MaxGamma[p][q]
//	Histogram/B=1 TempArray, POL_MaxGamma_hist
//	
//	histAvg 	= area(POL_MaxGamma_hist)
//	POL_MaxGamma_hist /= histAvg
////	POL_MaxGamma_hist /= NPx
//	
//	DoWindow AvgGammaAngleHistogram
//	if (!V_flag)
//		DisplayAvgGammaAngleHistogram(POL_AvgGamma_hist,POL_MaxGamma_hist,gStackName)
//	endif
//	
//	if (0)	
//	//	String HistExportName = gStackName+"_GammaHistograms.csv"
//		HistExportName = gStackName+"_MaxGammaHistogram.csv"
//		Duplicate /FREE/D POL_AvgGamma_hist, Hist_Axis
//		Hist_Axis[] = pnt2x(POL_AvgGamma_hist,p)
//		
//	//	Save/J/M="\n"/DLIM=","/P=home Hist_Axis,POL_AvgGamma_hist,POL_MaxGamma_hist as HistExportName
//		Save/J/M="\n"/DLIM=","/P=home Hist_Axis,POL_MaxGamma_hist as HistExportName
//	//	print " 	Saved the histogram of average and maximum pixel neighbor misorientation angles to", HistExportName
//		print " 	Saved the histogram of maximum pixel neighbor misorientation angles to", HistExportName
//	else
//		HistExportName = gStackName+"_MaxGammaHistogram.csv"
//		HistAxisName 	= gStackName+"_Gamma"
//		HistDataName 	= gStackName+"_Frequency"
//		Duplicate /O/D POL_AvgGamma_hist, $HistAxisName /WAVE=Hist_Axis
//		Duplicate /O/D POL_AvgGamma_hist, $HistDataName /WAVE=Hist_Data
//		Hist_Axis[] = pnt2x(POL_AvgGamma_hist,p)
//		
////		Save/J/M="\n"/DLIM=","/P=home/U={0,0,1,0} Hist_Axis,Hist_Data as HistExportName
//		
//		Save/J/M="\n"/DLIM=","/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data as HistExportName
//		
//	endif
//	
//End