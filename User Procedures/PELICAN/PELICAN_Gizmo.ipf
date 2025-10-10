// Updated 07.21.2015 19:51
#pragma rtGlobals=1		// Use modern global access method.

// ***************************************************************************
// **************** 	Interactive Gizmo to see single pixel orientation 
// ***************************************************************************

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
