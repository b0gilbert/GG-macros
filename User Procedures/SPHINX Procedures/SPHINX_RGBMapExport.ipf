#pragma rtGlobals=1		// Use modern global access method.

Function MMExportPanel()

	String Title = "Export Myriad Map"
	String PanelName = "MyriadMapExport"
	String PanelFolder = "root:SPHINX:SVD"

	SetDataFolder root:SPHINX:SVD:

		DoWindow /K $PanelName
		NewPanel /K=1/W=(36,66,411,243) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,36,66,411,243)

		Button CreateMyriadMap,pos={10,15}, size={130,25},fSize=13,proc=MyriadMapButtons,title="Create Myriad Map"
		Button DisplayMyriadMap,pos={10,45}, size={130,25},fSize=13,proc=MyriadMapButtons,title="Display Myriad Map"

		MakeVariableIfNeeded("root:SPHINX:SVD:gMyriad_MaskFlag",1)
		CheckBox MyriadMaskCheck,pos={165,22},size={212,577},title="Use Mask",fSize=11,variable=$("root:SPHINX:SVD:gMyriad_MaskFlag")
		
		MakeVariableIfNeeded("root:SPHINX:SVD:gMyriad_DisplayFlag",1)
		CheckBox MyriadDisplayCheck,pos={165,42},size={212,577},title="Display Myriad",fSize=11,variable=$("root:SPHINX:SVD:gMyriad_DisplayFlag")
		
		MakeVariableIfNeeded("root:SPHINX:SVD:gMyriad_SaveFlag",1)
		CheckBox MyriadSaveMyriadCheck,pos={165,62},size={212,577},title="Save Myriad",fSize=11,variable=$("root:SPHINX:SVD:gMyriad_SaveFlag"),proc=MyriadMapChecks
		
		MakeVariableIfNeeded("root:SPHINX:SVD:gMyriad_PSaveFlag",1)
		CheckBox MyriadSavePMapCheck,pos={165,82},size={212,577},title="Save p maps",fSize=11,variable=$("root:SPHINX:SVD:gMyriad_PSaveFlag"),proc=MyriadMapChecks
		
		// Select up to 5 components
		MakeVariableIfNeeded(PanelFolder+":Comp0",0)
		SetVariable Comp0,bodyWidth=40,title="Red",pos={310,10},limits={-1,5,1},fsize=13,value=$("root:SPHINX:SVD:Comp0")
		
		MakeVariableIfNeeded(PanelFolder+":Comp1",1)
		SetVariable Comp1,bodyWidth=40,title="Green",pos={310,35},limits={-1,5,1},fsize=13,value=$("root:SPHINX:SVD:Comp1")
		
		MakeVariableIfNeeded(PanelFolder+":Comp2",2)
		SetVariable Comp2,bodyWidth=40,title="Cyan",pos={310,60},limits={-1,5,1},fsize=13,value=$("root:SPHINX:SVD:Comp2")
		
		MakeVariableIfNeeded(PanelFolder+":Comp3",3)
		SetVariable Comp3,bodyWidth=40,title="Magenta",pos={310,85},limits={-1,5,1},fsize=13,value=$("root:SPHINX:SVD:Comp3")
		
		MakeVariableIfNeeded(PanelFolder+":Comp4",4)
		SetVariable Comp4,bodyWidth=40,title="Yellow",pos={310,110},limits={-1,5,1},fsize=13,value=$("root:SPHINX:SVD:Comp4")
		
		MakeVariableIfNeeded(PanelFolder+":Comp5",4)
		SetVariable Comp5,bodyWidth=40,title="Blue",pos={310,135},limits={-1,5,1},fsize=13,value=$("root:SPHINX:SVD:Comp5")
		
	SetDataFolder root:
End

Function MyriadMapChecks(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	String ctrlName			= CB_Struct.ctrlName
	Variable checked		= CB_Struct.checked
	
	NVAR gMyriad_MyriadSaveFlag 	= root:SPHINX:SVD:gMyriad_MyriadSaveFlag
	NVAR gMyriad_PSaveFlag 		= root:SPHINX:SVD:gMyriad_PSaveFlag
	
	// Don't allow saving the p-maps without the Myriad map
	if (StrSearch(ctrlName,"MyriadSavePMapCheck",0) > -1)
		if (checked)
			gMyriad_MyriadSaveFlag = 1
		endif
	elseif (StrSearch(ctrlName,"MyriadSaveMyriadCheck",0) > -1)
		if (gMyriad_PSaveFlag == 1)
			gMyriad_MyriadSaveFlag = 1
		endif
	endif
End

Function MyriadMapButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct

	String ctrlName = B_Struct.ctrlName
	String WindowName = B_Struct.win

	Variable eventCode = B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	Variable Success
		
	if (cmpstr("CreateMyriadMap",ctrlName)==0)
		Success = CreateMyriadMap()
	elseif (cmpstr("DisplayMyriadMap",ctrlName)==0)
		Success = DisplayMyriadImage()
	endif
	
	return Success
End
	
Function /WAVE ReturnComponent(Channel,Comp,Color,Success,ColorMsg)
	Variable Channel,Comp 
	String Color
	Variable &Success
	String &ColorMsg
	
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	WAVE /T RefDesc 	= root:SPHINX:SVD:ReferenceDescription

	WAVE PMap 			= $("root:SPHINX:Stacks:" + gStackName + "_pMap_" + num2str(Comp))
	
	if (!WaveExists(PMap))
		Success = 0
		ColorMsg 	= "Missing proportional map"+ gStackName +"_pMap_" + num2str(Comp)
	else
		Success = 1
		ColorMsg = " 		- "+Color+" = "+gStackName + "_pMap_" + num2str(Comp) + " = " + RefDesc[Comp][1]
	endif
	
	return PMap
End

Function CreateMyriadMap()

	SetDataFolder root:SPHINX:SVD:
	
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	
	NVAR gMyriad_MaskFlag 			= root:SPHINX:SVD:gMyriad_MaskFlag
	NVAR gMyriad_DisplayFlag 		= root:SPHINX:SVD:gMyriad_DisplayFlag
	NVAR gMyriad_SaveFlag 			= root:SPHINX:SVD:gMyriad_SaveFlag
	NVAR gMyriad_PSaveFlag 			= root:SPHINX:SVD:gMyriad_PSaveFlag
	
	WAVE RefSelect 						= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 					= root:SPHINX:SVD:ReferenceDescription
	
	String Msg, MaskDescription = ""
	Variable i, Success, NComps=6, NRefs = DimSize(RefSelect,0)
	
	// Check that the stack exists
	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) != 1)
		print "No stack exists"
		return 0
	endif
	
	Variable NumX = DimSize(SPHINXStack,0)
	Variable NumY = DimSize(SPHINXStack,1)
	
	// Check that a Mask Array exists, or create one
	WAVE SVDMask 	= $("root:SPHINX:Stacks:"+gStackName + "_Map_mask")
	if (!WaveExists(SVDMask))
		Make /O/N=(NumX, NumY) $("root:SPHINX:Stacks:"+gStackName + "_Map_mask") /WAVE=SVDMask
	endif
	
	Duplicate /O SVDMask, MyriadMap_Mask
		
	if (gMyriad_MaskFlag)
		if (SelectImageMask(SVDMask,gStackName,NumX,NumY,MaskDescription) == 0)
			print " 	Problem selecting an image mask " 
			return 0
		endif
		MyriadMap_Mask = SVDMask
	else
		MyriadMap_Mask = 0
	endif
	
	Make /T/FREE ChannelColors={"Red","Green","Cyan","Magenta","Yellow","Blue"}
//	Make /FREE ChannelHue={255,85,207,213,169}
	Make /FREE ChannelHue={0,120,180,300,60,240}	// These are "Hue Angles"
	Make /T/FREE/N=6 ChannelMsgs
	Make /O/N=6 Myriad_Components
	
	String ChannelStr="_", MyriadMapName = gStackName+"_MM"			//$("root:SPHINX:Stacks:"+MyriadMapName)
	
	// CONFUSING: The Array called MyriadMap_RGB is filled with the HSL values and then Transformed to RGB	
	Make /O/N=(NumX,NumY,3) MyriadMap_HSL, MyriadMap_RGB
	

	MyriadMap_RGB[][][0] 	= 0
	// Set the Saturation to maximum
	MyriadMap_RGB[][][1] 	= 65535
	
	for (i=0;i<NComps;i+=1)
		NVAR gComp 		= $("root:SPHINX:SVD:Comp"+num2str(i))
		
		if (gComp>-1)
			WAVE PMap = ReturnComponent(i,gComp,ChannelColors[i],Success,Msg)
			if (!Success)
				print Msg
				return 0
			endif
			
			ChannelStr 				= ChannelStr + num2str(gComp)
			ChannelMsgs[i] 			= Msg
			Myriad_Components[i] 	= gComp
			
			MyriadChannel(MyriadMap_RGB,PMap,ChannelHue[i],NumX,NumY)
		else
			ChannelStr 				= ChannelStr + "x"
			Myriad_Components[i] 	= -1
		endif
		
	endfor
	MyriadMapName 	= MyriadMapName + ChannelStr
	
	// Set Brightness to Zero for Masked Pixels
	MyriadMap_RGB[][][2] = (MyriadMap_Mask[p][q]==0) ? MyriadMap_RGB[p][q][2] : 0
	
	MyriadMap_HSL 	= MyriadMap_RGB
	ImageTransform /O hsl2rgb MyriadMap_RGB
	
	Duplicate /O MyriadMap_RGB, $("root:SPHINX:Stacks:"+MyriadMapName)
	WAVE MM 	= $("root:SPHINX:Stacks:"+MyriadMapName)
	
	String /G gMyriadMapName = MyriadMapName
	
	print " *** Created a Myriad Map called",MyriadMapName
	for (i=0;i<NComps;i+=1)
		NVAR gComp 		= $("root:SPHINX:SVD:Comp"+num2str(i))
		
		if (gComp>-1)
		print ChannelMsgs[i]
		endif
	endfor
	print " "
	
	if (gMyriad_DisplayFlag)
		RGBDisplayPanel(MM,MyriadMapName,MyriadMapName,NumX,NumY)
	endif

	if (gMyriad_saveFlag)
		SaveMyriadMap(MM,Myriad_Components,MyriadMap_Mask)
	endif
End

Function MyriadChannel(MM_HSL,PMap,Hue,NX,NY)
	Wave MM_HSL,PMap
	Variable Hue,NX,NY

	Variable Bright 		= 65535 
	Variable TrueHue 		= 65535 * (Hue/360)
	
	MM_HSL[][][0] 	= (PMap[p][q] > 0.5) ?   TrueHue : MM_HSL[p][q][0]
	
	// Only change the brightness for pixes with Component > 0.5 or we will be overwriting other pixel scales. 
	MM_HSL[][][2] 	= (PMap[p][q] > 0.5) ?   Bright * (PMap[p][q] - 0.5) : MM_HSL[p][q][2]

End

Function SaveMyriadMap(Myriad_Map,Myriad_Comps,Myriad_Mask)
	Wave Myriad_Map,Myriad_Comps,Myriad_Mask
	
	SVAR gStackName 					= root:SPHINX:Browser:gStackName
	SVAR gMyriadMapName 				= root:SPHINX:SVD:gMyriadMapName
	
	NVAR gMyriad_MaskFlag 			= root:SPHINX:SVD:gMyriad_MaskFlag
	NVAR gMyriad_SaveFlag 			= root:SPHINX:SVD:gMyriad_SaveFlag
	NVAR gMyriad_PSaveFlag 			= root:SPHINX:SVD:gMyriad_PSaveFlag
	
 	String Extension = ".tif"
	Variable i, NComps = DimSize(Myriad_Comps,0), FolderSaveflag = 0 
	
	// Enforce saving the Myriad map when the pMaps are saved as it makes folder handling easiest. 
	gMyriad_SaveFlag = (gMyriad_SaveFlag == 1) ? gMyriad_PSaveFlag : gMyriad_SaveFlag
	
	if (gMyriad_SaveFlag && gMyriad_PSaveFlag)
		NewPath /Q/O/M="Location for a new folder containing RGM-Map and P-Maps" MyriadPath
		if (V_flag !=0)
			return 1
		else
			FolderSaveflag = 1
			PathInfo MyriadPath
			String MyriadFoldername = gMyriadMapName
			Prompt MyriadFoldername, "Enter name of folder for saving"
			DoPrompt "Myriad Export", MyriadFoldername
			if (V_flag)
				return 0
			endif
			String MyriadPathAndFolder = S_path + MyriadFoldername
			NewPath /O/Q/C MyriadPath, MyriadPathAndFolder
		endif
	endif
	
	if (gMyriad_SaveFlag)
		ExportMyriadMap(Myriad_Map,FolderSaveflag)
		if (gMyriad_MaskFlag)
			ImageSave /O/DS=8/T="tiff"/P=MyriadPath Myriad_Mask as MyriadFoldername+"_mask"
		endif
	endif
	 
	 if (gMyriad_PSaveFlag)
	 	
	 	for (i=0;i<NComps;i+=1)
	 		if (Myriad_Comps[i] > -1)
		 		WAVE PMap 	= $("root:SPHINX:Stacks:"+gStackName+"_pMap_"+num2str(Myriad_Comps[i]))
				ImageSave /U/D=16/T="tiff"/P=MyriadPath PMap as (NameOfWave(PMap)+Extension)
			endif
	 	endfor 

	endif
		
	return 1
End


STATIC Function /S ExportMyriadMap(MyriadImage,MyriadPathflag)
	Wave MyriadImage
	Variable MyriadPathflag
	
	String MyriadName = NameofWave(MyriadImage)
	if (WaveExists(MyriadImage))
		if (MyriadPathflag)
			ImageSave /O/DS=8/T="tiff"/P=MyriadPath MyriadImage as (MyriadName+".tif")
		else
			ImageSave /DS=8/T="tiff" MyriadImage as (MyriadName+".tif")
		endif
	endif
End

Function DisplayMyriadImage()
	
	MakeStringIfNeeded("root:SPHINX:Stacks:gMyriadMapName","")
	SVAR gMyriadMapName 	= root:SPHINX:Stacks:gMyriadMapName
	
	String MyriadName, MyriadFolder 	= "root:SPHINX:Stacks"
	
	String MyriadList = ReturnImageList(MyriadFolder,1)
	Prompt MyriadName, "List of Myriad Maps", popup, MyriadList
	DoPrompt "Select Myriad Maps to view", MyriadName
	if (V_flag)
		return 0
	endif
	gMyriadMapName 	= MyriadName
	
	WAVE Myriad_Map = $("root:SPHINX:Stacks:"+gMyriadMapName)
	Variable NumX = DimSize(Myriad_Map,0)
	Variable NumY = DimSize(Myriad_Map,1)
	
	// Does this work for Myriad Maps? 
	RGBDisplayPanel(Myriad_Map,gMyriadMapName,gMyriadMapName,NumX,NumY)
		
End


Function RGBMapExportPanel()

	String Title = "Export 3 Component Maps as RGB Image"
	String PanelName = "RGBMapExport"
	String PanelFolder = "root:SPHINX:SVD"

	SetDataFolder root:SPHINX:SVD:

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,360,135) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,360,135)

		Button CreateRGBMap,pos={10,15}, size={120,25},fSize=13,proc=RGBMapButtons,title="Create RGB Map"

		MakeVariableIfNeeded("root:SPHINX:SVD:gRGB_MaskFlag",1)
		CheckBox RGBMaskCheck,pos={270,10},size={212,577},title="Use Mask",fSize=11,variable=$("root:SPHINX:SVD:gRGB_MaskFlag")
		MakeVariableIfNeeded("root:SPHINX:SVD:gRGB_BEFlag",1)
		CheckBox RGBBECheck,pos={140,10},size={212,577},title="Enhance brightness",fSize=11,variable=$("root:SPHINX:SVD:gRGB_BEFlag")
		MakeVariableIfNeeded("root:SPHINX:SVD:gRGB_RGBSaveFlag",1)
		CheckBox RGBSaveRGBCheck,pos={140,26},size={212,577},title="Save RGB",fSize=11,variable=$("root:SPHINX:SVD:gRGB_RGBSaveFlag"),proc=RGBMapChecks
		MakeVariableIfNeeded("root:SPHINX:SVD:gRGB_PSaveFlag",1)
		CheckBox RGBSavePMapCheck,pos={230,26},size={212,577},title="Save p maps",fSize=11,variable=$("root:SPHINX:SVD:gRGB_PSaveFlag"),proc=RGBMapChecks

		MakeVariableIfNeeded(PanelFolder+":Comp0",0)
		SetVariable Comp0,title="Components:   R",pos={5,65},limits={0,65535,1},size={145,25},fsize=13,value=$("root:SPHINX:SVD:Comp0")
		MakeVariableIfNeeded(PanelFolder+":Comp1",1)
		SetVariable Comp1,title="G",pos={155,65},limits={0,65535,1},size={50,25},fsize=13,value=$("root:SPHINX:SVD:Comp1")
		MakeVariableIfNeeded(PanelFolder+":Comp2",2)
		SetVariable Comp2,title="B",pos={215,65},limits={0,65535,1},size={50,25},fsize=13,value=$("root:SPHINX:SVD:Comp2")
	
	SetDataFolder root:
End

Function RGBMapChecks(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	String ctrlName			= CB_Struct.ctrlName
	Variable checked		= CB_Struct.checked
	
	NVAR gRGB_RGBSaveFlag 	= root:SPHINX:SVD:gRGB_RGBSaveFlag
	NVAR gRGB_PSaveFlag 		= root:SPHINX:SVD:gRGB_PSaveFlag
	
	// Don't allow saving the p-maps without the RGB map
	if (StrSearch(ctrlName,"RGBSavePMapCheck",0) > -1)
		if (checked)
			gRGB_RGBSaveFlag = 1
		endif
	elseif (StrSearch(ctrlName,"RGBSaveRGBCheck",0) > -1)
		if (gRGB_PSaveFlag == 1)
			gRGB_RGBSaveFlag = 1
		endif
	endif
End

Function RGBMapButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct

	String ctrlName = B_Struct.ctrlName
	String WindowName = B_Struct.win

	Variable eventCode = B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	Variable Success = CreateRGBMap()
	
	return Success
End

Function CreateRGBMap()

	SetDataFolder root:SPHINX:SVD:
	
	SVAR gStackName 	= root:SPHINX:Browser:gStackName
	
	NVAR gRGB_MaskFlag 		= root:SPHINX:SVD:gRGB_MaskFlag
	NVAR gRGB_BEFlag 			= root:SPHINX:SVD:gRGB_BEFlag
	NVAR gRGB_RGBSaveFlag 	= root:SPHINX:SVD:gRGB_RGBSaveFlag
	NVAR gRGB_PSaveFlag 		= root:SPHINX:SVD:gRGB_PSaveFlag
	
	WAVE RefSelect 		= root:SPHINX:SVD:ReferenceSelection
	WAVE /T RefDesc 		= root:SPHINX:SVD:ReferenceDescription
	Variable i, NRefs = DimSize(RefSelect,0)
	
	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) != 1)
		print "No stack exists"
		return 0
	else
		Variable NumX = DimSize(SPHINXStack,0)
		Variable NumY = DimSize(SPHINXStack,1)
	endif
	
	String RChannel, GChannel, BChannel

	NVAR Comp0 = root:SPHINX:SVD:Comp0
	WAVE pmap0 = $("root:SPHINX:Stacks:" + gStackName + "_pMap_" + num2str(Comp0))
	if (!WaveExists(pmap0))
		print "Missing proportional map", gStackName + "_pMap_" + num2str(Comp0)
		return 0
	else
		RChannel = " 		- Red = "+gStackName + "_pMap_" + num2str(Comp0) + " = " + RefDesc[Comp0][1]
	endif
	NVAR Comp1 = root:SPHINX:SVD:Comp1
	WAVE pmap1 = $("root:SPHINX:Stacks:" + gStackName + "_pMap_" + num2str(Comp1))
	if (!WaveExists(pmap1))
		print "Missing proportional map", gStackName + "_pMap_" + num2str(Comp1)
		return 0
	else
		GChannel = " 		- Green = "+gStackName + "_pMap_" + num2str(Comp1) + " = " + RefDesc[Comp1][1]
	endif
	NVAR Comp2 = root:SPHINX:SVD:Comp2
	WAVE pmap2 = $("root:SPHINX:Stacks:" + gStackName + "_pMap_" + num2str(Comp2))
	if (!WaveExists(pmap2))
		print "Missing proportional map", gStackName + "_pMap_" + num2str(Comp2)
		return 0
	else
		BChannel = " 		- Blue = "+gStackName + "_pMap_" + num2str(Comp2) + " = " + RefDesc[Comp2][1]
	endif

	WAVE SVDMask 	= $("root:SPHINX:Stacks:"+gStackName + "_Map_mask")
	if (!WaveExists(SVDMask))
		Make /O/N=(NumX, NumY) $("root:SPHINX:Stacks:"+gStackName + "_Map_mask") /WAVE=SVDMask
		return 0
	endif
	
	if (gRGB_MaskFlag)
		String MaskDescription = ""
		if (SelectImageMask(SVDMask,gStackName,NumX,NumY,MaskDescription) == 0)
			return 0
		endif
	else
		SVDMask = 0
	endif
	
	String RGBMapName = gStackName + "_Cmp_"+Num2Str(Comp0)+"_"+Num2Str(Comp1)+"_"+Num2Str(Comp2)
	if (gRGB_BEFlag)
		RGBMapName = RGBMapName+"_BE"
	endif
	if (gRGB_MaskFlag)
		RGBMapName = RGBMapName+"_Mask_"
	endif
	String /G root:SPHINX:Stacks:gRGBMapName = RGBMapName
	
	WAVE /D RGB_Map = $("root:SPHINX:Stacks:"+RGBMapName)
	if (!waveExists(RGB_Map))
		Make /O/N=(NumX, NumY, 3)/D $("root:SPHINX:Stacks:"+RGBMapName) /WAVE=RGB_Map
		RGB_Map = NaN
	endif
	
	if (gRGB_PSaveFlag)
		Make /FREE/D/N=(NumX,NumY) PEx0
		Make /FREE/D/N=(NumX,NumY) PEx1
		Make /FREE/D/N=(NumX,NumY) PEx2
	endif
	
	// !*!*!*! This must be one-less than the highest gray level
	Variable MaxRGB = 65535 // 65536
	
	String RefList="		Components considered for brightness enhancement:"
	
	if (gRGB_BEFlag)
		Make /FREE/D/N=(NumX, NumY) TmpScaleImage
		
		// This only considers the 3 RGB maps, but we want to scale relative to all references used in the mapping
		// MultiThread TmpScaleImage[][] 	= max(max(pmap0[p][q],pmap1[p][q]),pmap2[p][q])
	
		for (i=0;i<NRefs;i+=1)
			if (isChecked(RefSelect[i][0]))
					// Set each pixel of the temporary image to the maximum among all waves
					WAVE Image 	= $("root:SPHINX:Stacks:"+gStackName + "_pMap_" + num2str(i))
					MultiThread TmpScaleImage[][] 	= max(Image[p][q],TmpScaleImage[p][q])
					RefList = RefList + RefDesc[i][1]+";"
			endif
		endfor
		
		MultiThread RGB_Map[][][0] 	= pmap0[p][q] * (MaxRGB/TmpScaleImage[p][q])
		MultiThread RGB_Map[][][1] 	= pmap1[p][q] * (MaxRGB/TmpScaleImage[p][q])
		MultiThread RGB_Map[][][2]	= pmap2[p][q] * (MaxRGB/TmpScaleImage[p][q])
		
		if (gRGB_PSaveFlag) // to export individual p-maps with brightness enhancement
			PEx0[][] = pmap0[p][q] * (MaxRGB/TmpScaleImage[p][q])
			PEx1[][] = pmap1[p][q] * (MaxRGB/TmpScaleImage[p][q])
			PEx2[][] = pmap2[p][q] * (MaxRGB/TmpScaleImage[p][q])
		endif
	else
		MultiThread RGB_Map[][][0] 	= pmap0[p][q] * MaxRGB
		MultiThread RGB_Map[][][1] 	= pmap1[p][q] * MaxRGB
		MultiThread RGB_Map[][][2] 	= pmap2[p][q] * MaxRGB
		
		if (gRGB_PSaveFlag) // to export individual p-maps without brightness enhancement
			PEx0[][] = pmap0[p][q] * MaxRGB
			PEx1[][] = pmap1[p][q] * MaxRGB
			PEx2[][] = pmap2[p][q] * MaxRGB
		endif
	endif
	
	if (gRGB_MaskFlag)
		// What is the best value to set masked points to? Zero or 2^16 = 65536
		MultiThread RGB_Map[][][0] 	= (SVDMask[p][q] == 0) ? RGB_Map[p][q][0] : 0
		MultiThread RGB_Map[][][1] 	= (SVDMask[p][q] == 0) ? RGB_Map[p][q][1] : 0
		MultiThread RGB_Map[][][2]	= (SVDMask[p][q] == 0) ? RGB_Map[p][q][2] : 0
	endif
	
	Print " *** Created a RGB image called",RGBMapName;print RChannel;print GChannel;print BChannel;print "		"+MaskDescription
	if (gRGB_BEFlag)
		print RefList
	endif
	
	RGBDisplayPanel(RGB_Map,RGBMapName,RGBMapName,NumX,NumY)
	
	Variable FolderSaveflag = 0 
	// Enforce saving the RGB map when the pMaps are saved as it makes folder handling easiest. 
	gRGB_RGBSaveFlag = (gRGB_PSaveFlag == 1) ? gRGB_PSaveFlag : gRGB_RGBSaveFlag
	
	if (gRGB_RGBSaveFlag && gRGB_PSaveFlag)
		NewPath /Q/O/M="Location for a new folder containing RGM-Map and P-Maps" RGBPath
		if (V_flag !=0)
			return 1
		else
			FolderSaveflag = 1
			PathInfo RGBPath
			String RGBFoldername = RGBMapName
			Prompt RGBFoldername, "Enter name of folder for saving"
			DoPrompt "RGB Export", RGBFoldername
			if (V_flag)
				return 0
			endif
			String RGBPathAndFolder = S_path + RGBFoldername
			NewPath /O/Q/C RGBPath, RGBPathAndFolder
		endif
	endif
	
	if (gRGB_RGBSaveFlag)
		ExportRGBMap(RGB_Map,FolderSaveflag)
		if (gRGB_MaskFlag)
//			ImageSave /O/DS=8/T="tiff"/P=RGBPath SVDMask as NameOfWave(SVDMask)
			ImageSave /O/DS=8/T="tiff"/P=RGBPath SVDMask as RGBFoldername
		endif
	endif
	 
	 if (gRGB_PSaveFlag)
	 	String Extension = ".tif"
	 	if (gRGB_BEFlag)
	 		Extension = "_BE.tif"
	 	endif
		ImageSave /U/D=16/T="tiff"/P=RGBPath PEx0 as (NameOfWave(pmap0)+Extension)
		ImageSave /U/D=16/T="tiff"/P=RGBPath PEx1 as (NameOfWave(pmap1)+Extension)
		ImageSave /U/D=16/T="tiff"/P=RGBPath PEx2 as (NameOfWave(pmap2)+Extension)
	endif
		
	return 1
End

Function /S ExportRGBMap(RGBImage,RGBPathflag)
	Wave RGBImage
	Variable RGBPathflag
	
	String RGBName = NameofWave(RGBImage)
	if (WaveExists(RGBImage))
		if (RGBPathflag)
			ImageSave /O/DS=8/T="tiff"/P=RGBPath RGBImage as (RGBName+".tif")
		else
			ImageSave /DS=8/T="tiff" RGBImage as (RGBName+".tif")
		endif
	endif
End

Function DisplayRGBImage()

	SVAR gRGBMapName 	= root:SPHINX:Stacks:gRGBMapName
	
	String RGBName, RGBFolder 	= "root:SPHINX:Stacks"
	
	String RGBList = ReturnImageList(RGBFolder,1)
	Prompt RGBName, "List of RGB maps", popup, RGBList
	DoPrompt "Select RGM maps to view", RGBName
	if (V_flag)
		return 0
	endif
	gRGBMapName 	= RGBName
	
	WAVE RGB_Map = $("root:SPHINX:Stacks:"+gRGBMapName)
	Variable NumX = DimSize(RGB_Map,0)
	Variable NumY = DimSize(RGB_Map,1)
	
	RGBDisplayPanel(RGB_Map,gRGBMapName,gRGBMapName,NumX,NumY)
		
End




// 		Exporting the RGB as CMY looks awful! 	
//		rgb_be_name = gStackName + "_RGB_Map_BE.tiff"
//		SavePICT /C=1/E=-7 /WIN=$("RGBMapBE#StackImage")  as rgb_be_name
//		rgb_be_name = gStackName + "_CMY_Map_BE.tiff"
//		SavePICT /C=2/E=-7 /WIN=$("RGBMapBE#StackImage")  as rgb_be_name