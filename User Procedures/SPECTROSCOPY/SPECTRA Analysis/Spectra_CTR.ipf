#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "Spectra_Includes"

// Should be able to just run this
// LoadRodStacksInFolder()

Menu "Spectra"
	SubMenu "CTR"
		"Load Rod Stacks In Folder"
	End
End

Function CleanCTRLoadFolder()

		KillAllWavesInFolder("root:CTR","*")
		KillAllWavesInFolder("root:CTR:Tag0","*")
		KillDataFolder /Z root:CTR:Tag0
End

// This assumes that background subtraction has already been performed in ImageJ
Function ExtractRod(rodName,H,K)
	String rodName
	Variable H, K
	
	SetDataFolder root:CTR:Rods
//		String rodName 		= "rod_"+num2str(H)+num2str(K)+"L"
		rodName 				= ReplaceString("-",rodName,"m")
		
		WAVE rodStack 		= $("root:CTR:Rods:"+rodName+"_stack")
		WAVE /T rodMeta 		= $("root:CTR:Rods:"+rodName+"_meta")
		
		String meta, bgX, bgY, rodX, rodY, slitX, slitY
		Variable rodCX, rodCY, bgCX, bgCY, slitCX, slitCY
		Variable i, m, n, NX=DimSize(rodStack,0), NY=DimSize(rodStack,1), NImages=DimSize(rodStack,2)
		Variable LL, alpha, betta, nu, del, intensity, io, Ctot, Crms=1e99
		
		Make /O/D/N=(NImages) $("root:CTR:Rods:"+rodName+"_data") /WAVE=Data
		Make /O/D/N=(NImages) $("root:CTR:Rods:"+rodName+"_data_sig") /WAVE=Errors
		Make /O/D/N=(NImages) $("root:CTR:Rods:"+rodName+"_corr") /WAVE=Corr
		Make /O/D/N=(NImages) $("root:CTR:Rods:"+rodName+"_axis")	/WAVE=Axis
		Make /O/D/N=(NImages) $("root:CTR:Rods:"+rodName+"_alp")	/WAVE=AlphaValues
		Make /O/D/N=(NImages) $("root:CTR:Rods:"+rodName+"_bet")	/WAVE=BetaValues
		
		Make /O/U/B/N=(NX,NY) rodMask=255, errROI=255, errROIquad=255
		
		for (i=0;i<NImages;i+=1)
			
			meta = rodMeta[i]
			
			LL 		= NumberByKey("l", meta, "=", ";")
			alpha 	= NumberByKey("alpha", meta, "=", ";")
			betta 	= NumberByKey("beta", meta, "=", ";")
			nu 		= NumberByKey("nu", meta, "=", ";")
			del		= NumberByKey("del", meta, "=", ";")
			io		= NumberByKey("io", meta, "=", ";")
			intensity		= NumberByKey("intensity", meta, "=", ";")
			
			AlphaValues[i] = alpha
			BetaValues[i] = betta
			
			rodX 	= StringByKey("rodX",meta, "=", ";")
			rodY 	= StringByKey("rodY",meta, "=", ";")
			WAVE rodROI = ROIBoundary(rodX,rodY,"rod",rodName,NX,NY,rodCX,rodCY)
			
			MatrixOp /O Slice = rodStack[][][i]
//			MatrixOp /O/FREE Slice = layer(i,rodStack)
//			ImageTransform/P=(i) getPlane root:Images:peppers
			
			ImageStats /R=rodROI Slice
			Axis[i] = LL
			Data[i] = sqrt(V_avg)
			
			Ctot 		= rodCorrectionFactor(LL, alpha, betta, nu, del, intensity, io)
			Corr[i] 	= sqrt(V_avg * Ctot)		// !*!*!*! Take Square Root
			
			if (1)
			
				rodMask = rodROI
				bgX 	= StringByKey("bgX",meta, "=", ";")
				bgY 	= StringByKey("bgY",meta, "=", ";")
				WAVE bgROI = ROIBoundary(bgX,bgY,"bg",rodName,NX,NY,bgCX,bgCY)
				
				errROI[][] 	= (rodMask[p][q]==0) ? 255 : bgROI[p][q]
				
				Crms=1e99
				for (m=0;m<2;m+=1)
					for (n=0;n<2;n+=1)
						ROIQuadrant(errROI,errROIquad,m,n,bgCX,bgCY,NX,NY)
//						Redimension /U errROIquad
						ImageStats /Q /R=errROIquad Slice
						if (V_rms < Crms)
							Crms = V_rms/2 	// !*!*!*!*! Arbitrary factor of 2
						endif
					endfor
				endfor
				Errors[i] = sqrt(Crms * Ctot)		// !*!*!*! Take Square Root
				
				slitX 	= StringByKey("slitX",meta, "=", ";")
				slitY 	= StringByKey("slitY",meta, "=", ";")
				WAVE slitROI = ROIBoundary(slitX,slitY,"slit",rodName,NX,NY,slitCX,slitCY)
			endif
			
		endfor
	
		KillWaves /Z root:CTR:Rods:rodX, root:CTR:Rods:rodY, root:CTR:Rods:bgX, root:CTR:Rods:gY, root:CTR:Rods:slitX, root:CTR:Rods:slitY
		
	SetDataFolder root:
End

//ImageAnalyzeParticles
//ImageLineProfile

Function rodCorrectionFactor(LL, alpha, betta, nu, del, intensity, io)
	Variable LL, alpha, betta, nu, del, intensity, io
	
	// Normalization factor for incident flux
	Variable Ci = 1000000/io

	// Normalization factor for Ewald sphere intersection
	Variable Ce = sin(2*PI*(betta/360))

	// Normalization factor for beam footprint on sample
	Variable Cf = sin(2*PI*(alpha/360))

	// Normalization factor for polarization
	Variable dot = cos((pi/180)*(nu-90))*sin((pi/180)*(90-del))
	Variable ang = acos(dot)
	Variable Cp = 1/(sin(ang)*sin(ang))

	Variable Ctot = Ci * Ce * Cf * Cp

	return Ctot
End


Function ROIQuadrant(ROIFull,ROIQuad,QX,QY,CX,CY,NX,NY)
	Wave ROIFull, ROIQuad
	Variable QX,QY, CX, CY, NX, NY
	
	ROIQuad = 255
	ROIQuad[QX*CX,CX+QX*(NX-CX)-1][QY*CY,CY+QY*(NY-CY)-1] 	= ROIFull[p][q]
	
End

Function /WAVE ROIBoundary(roiXstr,roiYstr,roiName,rodName,NX,NY,CX,CY)
	String roiXstr, roiYstr, roiName, rodName
	Variable NX,NY, &CX, &CY
	
	Variable NCoords, MeanX, MeanY
	
	NCoords 	= ItemsInList(roiXstr,",")
	
	Make /O/N=(NCoords+1) $(roiName+"X") /WAVE=roiX
	Make /O/N=(NCoords+1) $(roiName+"Y") /WAVE=roiY
	
	ListValuesToWave(roiX,roiXstr,",",0)
	ListValuesToWave(roiY,roiYstr,",",0)
	
	//The center of the ROI
	CX = mean(roiX,0,NCoords-1)
	CY = mean(roiY,0,NCoords-1)
	
	// Close the ROI
	roiX[NCoords] = roiX[0]
	roiY[NCoords] = roiY[0]
	
//	MeanX 	= mean(roiX)
//	MeanY 	= mean(roiY)
	MeanX 	= CX
	MeanY 	= CY
	
	// After this function, the region of Interest has value 1
	ImageBoundaryToMask width=NX, height=NY, xwave=roiX, ywave=roiY, seedX=MeanX, seedY=MeanY
	WAVE M_ROIMask = M_ROIMask
	
	// Convert to a true ROI with values of zero
	M_ROIMask[][] = (M_ROIMask[p][q] == 1) ? 0 : 255
	
//	MatrixOp /O M_ROIMask = abs(M_ROIMask - 1)  // nope
//	ImageTransform /O invert M_ROIMask		// nope
	
	// Should probably do this!! 
//	Rename M_ROIMask, $(rodName+"_roi_"+roiName)

	return M_ROIMask
End

Function LoadRodStacksInFolder()

	NewDataFolder /O/S root:CTR
		CleanCTRLoadFolder()
		NewDataFolder /O/S root:CTR:Rods
		KillWaves /Z/A
		
		NewPath /Q/M="Select path to images" /O Path2Rods
		if (V_Flag!=0)
			SetDataFolder root:
			return 0
		endif
		
		String rodName, FileName, FileList, DataFolderFileName, FolderName
		FileList 	= IndexedFile(Path2Rods,-1,".tif")
		FileList 	= SortList(FileList,";",16)
		Variable i, H, K, NRods 		= ItemsInList(FileList)
		
		for (i=0;i<NRods; i+=1)
			FileName 	= StringFromList(i,FileList)
			rodName 		= LoadSingleRodStack(FileName,H,K)
			
			ExtractRod(rodName,H,K)
			
			DataFolderFileName = AdoptAxisAndDataFromMemory(rodName+"_axis","null","root:CTR:Rods:",rodName+"_corr",rodName+"_data_sig","root:CTR:Rods:",rodName,"r",0,0,0)
			// AdoptAxisAndDataFromMemory(AxisName,AxisErrorsName,AxisFolder,DataName,DataErrorsName,DataFolder,NewDataName,CopySuffix,UserNameFlag,SortFlag,StripNaNsFlag)

			FolderName 	= ParseFilePath(1,DataFolderFileName,":",1,0)
			MoveWave $("root:CTR:Rods:"+rodName+"_alp"), $FolderName
			MoveWave $("root:CTR:Rods:"+rodName+"_bet"), $FolderName
			
		endfor
		
		KillWaves /Z root:CTR:StripMetaNums, root:CTR:TagMetaChars
		KillWaves /Z root:CTR:Rods:RodMeta, root:CTR:Rods:M_ROIMask, root:CTR:Rods:Slice
End

Function /S LoadSingleRodStack(FileName,H,K)
	String FileName
	Variable &H, &K

	NewDataFolder /O/S root:CTR
		CleanCTRLoadFolder()
		NewDataFolder /O root:CTR:Rods
		
		String MetaString, rodFile, rodSample, rodNumStr, rodName
		Variable i, j=1, NSlices, Start
	
		ImageLoad /P=Path2Rods/O/C=-1/LR3D/T=tiff/Q FileName
//		ImageLoad /O/C=-1/LR3D/T=tiff/Q // This requires user to find a single file
		if (V_flag == 0)
			return ""
		endif
		WAVE RodStack 	= $StringFromList(0,S_waveNames)
		rodFile 				= NameOfWave(RodStack)
		NSlices 				= DimSize(RodStack,2)
		
		ImageLoad /RTIO/Q (S_path+S_fileName)
		
		WAVE TagLengths 	= root:CTR:Tag0:tifTag50838
		WAVE TagMetaNums 	= root:CTR:Tag0:tifTag50839
		
		Make /O/N=(DimSize(TagMetaNums,0)) StripMetaNums
		StripMetaNums[] 	= (TagMetaNums[p] < 2) ? 32 : TagMetaNums[p]				// Convert 2 NULL characters, 1 and 2, into spaces
		StripMetaNums[] 	= (StripMetaNums[p] == 10) ? 59 : StripMetaNums[p]		// Convert a return character, 10, into ";"
		
		Make /O/T/N=(DimSize(TagMetaNums,0)) TagMetaChars
		TagMetaChars[] 	= num2char(StripMetaNums[p])
		
		// Read the Metadata for the sample
		Start = TagLengths[0]
		MetaString 	= ReplaceString(" ",TextWaveToString(Start,Start+TagLengths[1],TagMetaChars),"")+";"
		
		String RodInfo 	= StringByKey("rodScan",MetaString,"=")
		String RodType 	= ReturnTextBeforeNthChar(RodInfo,"L",1) + "L"
		
		// Read the Metadata for each image
		Make /O/T/N=(NSlices) RodMeta
		
		Start = TagLengths[0] + TagLengths[1]
		for (i=0;i<NSlices;i+=1)
			MetaString 	= TextWaveToString(Start,Start+TagLengths[i+2],TagMetaChars)
			RodMeta[i] 	= ReplaceString(" ",MetaString,"")
			Start += TagLengths[i+2]
		endfor
		
		MetaString = rodMeta[0]
		H = NumberByKey("h", MetaString, "=", ";")
		K = NumberByKey("k", MetaString, "=", ";")
		
		Print " *** Loaded",RodType,"rod stack with",NSlices,"images from file",rodFile
		
		String RodNote = "rodType="+rodType+";fileName="+rodFile+";"
		Note /K RodStack RodNote
		
		MoveWave RodStack, root:CTR:Rods:
		MoveWave RodMeta, root:CTR:Rods:
		
		rodType 		= ReplaceString("-",rodType,"m")
		rodSample 	= ReturnTextBeforeNthChar(rodFile,"_",1)
		rodNumStr 	= num2str(ReturnLastNumber(rodFile))
		rodName 	= rodSample + "_" + rodType + "_" + rodNumStr
				
		Rename RodStack, $(rodName+"_stack")
		Rename RodMeta, $(rodName+"_meta")
			
		CleanCTRLoadFolder()
		
	SetDataFolder root:
	
	return rodName
End

Function /S TextWaveToString(St,Sp,TextWave)
	Variable St, Sp
	Wave /T TextWave
	
	Variable i
	String Str=""
	
	for (i=St;i<Sp;i+=1)
		Str = Str+TextWave[i]
	endfor
	
	return Str
End


//Function PlotSelectedData(PlotAllFlag,WideFlag)
//	Variable PlotAllFlag, WideFlag
//	
//	WAVE /T DataList 	= root:SPECTRA:wDataList
//	WAVE DataSel 	 	= root:SPECTRA:wDataSel
//	WAVE DataGroup 	= root:SPECTRA:wDataGroup
//	
////	if (DataFolderExists("root:WinGlobals"))
////		NewDataFolder /O root:WinGlobals
////	endif
//	
//	NVAR PlotAssd 				= root:SPECTRA:Plotting:gPlotAssociatedFlag	
//	Variable UserLegend 			= NumVAROrDefault("root:SPECTRA:Plotting:gFileNameLegendFlag",0)
//	Variable PlotTime 			= NumVAROrDefault("root:SPECTRA:Plotting:gPlotvsTimeFlag",0)
//	
//	Variable i=0, DataNum, Num2Plot, AppendFlag = 0, timeFlag=0
//	String DataNote, DataFileName, DataType, Folder2DName, Data2DName, Data2DFull, LegendText=""
//	String AxisName, AxisAndFolderName, DataName, DataAndFolderName, PlotName, FolderStem = "root:SPECTRA:Data:Load"
//	
//	WaveStats /Q/M=0 DataSel
//	Num2Plot = (PlotAllFlag == 1) ? V_npnts : V_sum
//	
//	do
//		// Bit 0 or 3 is set: Normal selection. 
//		if (((DataSel[i] & 2^0) != 0) || ((DataSel[i] & 2^3) != 0) || (PlotAllFlag == 1))
//			
//			DataNum 				= i
//			DataName				= DataList[DataNum]
//			DataAndFolderName	= FolderStem + num2str(DataGroup[DataNum]) + ":" + DataName
//			DataNote 				= Note($DataAndFolderName)
//			DataFileName 			= ReturnTextBeforeNthChar(DataNote,"\r",1)
//			DataType 				= StringByKey("Data type",DataNote,"=","\r")
//			
//			if (PlotTime == 0)
//				AxisName 				= AxisNameFromDataName(DataName)
//				AxisAndFolderName	= AxisNameFromDataName(DataAndFolderName)
//			else
//				AxisName 				= AnyNameFromDataName(DataName,"time")
//				AxisAndFolderName	= AnyNameFromDataName(DataAndFolderName,"time")
//				if (!WaveExists($AxisAndFolderName))
//					Print " 	*** No data-point acquisition times were loaded for",DataName
//					return 0
//				endif
//			endif
//			
//			Folder2DName 		= FolderStem + num2str(DataGroup[DataNum]) + ":TwoD"
//			Data2DName 			= AnyNameFromDataName(DataName,"2D")
//			Data2DFull 			= ParseFilePath(2,Folder2DName,":",0,0) + Data2DName
//			
//			if (WaveExists($Data2DFull))
//				Plot2DData(Data2DFull,DataNote)
//			else
//				Display /K=1/W=(525,44,1234,707)  $DataAndFolderName vs $AxisAndFolderName as "Plotted Data"
//				ControlBar 180
//				PlotName = WinName(0,65)
//				
//				MakePlotDataFolders(PlotName,1)
//				
//				PlotDataInWindow(PlotName, DataList, DataSel, DataGroup, "red", PlotAllFlag, AppendFlag, 0, 1, PlotTime, PlotAssd,"",UserLegend)
////				if (cmpstr(DataType,"Complex") == 0)
////					PlotDataInWindow(PlotName, DataList, DataSel, DataGroup, "red", PlotAllFlag, AppendFlag, 1, 1, PlotTime, PlotAssd,"")
////				endif
//
//				
//				if (WideFlag)
//					CheckWindowPosition(PlotName,0,44,2000,707)
//				else
//					CheckWindowPosition(PlotName,525,44,1234,707)
//				endif
//				
//				timeFlag = (PlotTime && WideFlag) ? 1 : 0
//				SetCommonPlotFormat(PlotName,timeFlag)
//				
//				TransferPlotPreferences(PlotName,1)
//				
//				AddPlotFormatControls(PlotName)
//				
//				UpdateTraceStyle(PlotName,"_all_")
//				
//				PlotControlButtons("ReplaceCursorsButton")
//	
//				if (PlotTime && WideFlag)
//					// some formatting and display tweaks for wide display of time-axis data
//					ModifyGraph /W=$PlotName dateInfo(bottom)={0,1,0}, grid(bottom)=1,nticks(bottom)=12
//				endif
//				
//				return 0
//			endif
//		endif
//		
//		i+=1
//	while(i<numpnts(DataSel))
//End