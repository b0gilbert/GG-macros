#pragma rtGlobals=1		// Use modern global access method.



// ***************************************************************************
// **************** 				SERIAL SPECTRUM PROCESSING ROUTINE
// ***************************************************************************
Proc SerialProcessing()
	PauseUpdate; Silent 1
	
	SetDataFolder root:SPECTRA
	NewDataFolder /O/S root:SPECTRA:Serial
		SerialSpectraProcessing()
	SetDataFolder root:
End

Function SerialSpectraProcessing()
	
	WAVE wDataSel 		= root:SPECTRA:wDataSel
	WAVE wDataGroup 	= root:SPECTRA:wDataGroup
	WAVE /T wDataList 	= root:SPECTRA:wDataList
	
	String FolderStem = "root:SPECTRA:Data:Load"
	String Data1List, Data2List, Data1Name, Data2Name, Data1Note, Data2Note, Data1Folder, Data2Folder, ProcDataName, ProcAxisName, MathOpName, FileBase
	Variable i, j, NumData1, NumData2, Data1Num, Data2Num, Data2Index, ProcAllFlag=0, AlignFlag
	
	Variable /G gProcOp, gPairChoice, gPOrder, gIndexFind, gAlignChoice, gAlignMin, gAlignMax, gReportFlag
	String /G gRefSpectrum, gCutNameText, gPasteNameText, gExcludeSpecText
	
	// Assume that we will xxclude all processed wave "_p_data" from further consideration. 
	String DataNameList	= ReplaceString("_data",ExclusiveWaveList(TextWaveToList(wDataList,0,"",""),"_p_data",";"),"")
	
	MakeStringIfNeeded("gBasename1",LookForCommonPrefix(DataNameList))
	MakeStringIfNeeded("gBasename2",LookForCommonPrefix(DataNameList))
	SVAR gBasename1	= root:SPECTRA:Serial:gBasename1
	SVAR gBasename2	= root:SPECTRA:Serial:gBasename2
	
	Variable PairChoice = gPairChoice
	Prompt PairChoice, "Selecting spectra pairs", popup, "base1(n) & base2(n);base(n) & base(n-1);base(n) & base(n+1);base(n) & ref;selected & ref;"
	String Basename1 = gBasename1
	Prompt Basename1, "Base/string 1 text"
	Variable ProcOp = gProcOp
	Prompt ProcOp, "Processing operation", popup, "1+2;1-2;1/2;1/2 - 1;align 1+2;align 1-2;align 1/2;align 1/2-1;align only;"
	String Basename2 = gBasename2
	Prompt Basename2, " ... or Base/string 2 text"
	String RefSpectrum = gRefSpectrum
	Prompt RefSpectrum, " A single reference ... ", popup, DataNameList
	Variable IndexFind = gIndexFind
	Prompt IndexFind, "Data number in filename", popup, "last;1;2;3;4;5;"
	String CutNameText 	= gCutNameText
	Prompt CutNameText, "Cut text from filename"
	String PasteNameText 	= gPasteNameText
	Prompt PasteNameText, "Insert text into filename"
	String ExcludeSpecText 	= gExcludeSpecText
	Prompt ExcludeSpecText, "Skip data with text"
	Variable ReportFlag = (gReportFlag == 1) ? 1 : 2
	Prompt ReportFlag, "Report processing actions?", popup, "yes;no;"
	
	DoPrompt "Serial processing parameters", PairChoice, Basename1, RefSpectrum, Basename2, CutNameText, PasteNameText, IndexFind, ProcOp, ExcludeSpecText, ReportFlag
	if (V_Flag)
		return -1
	endif
	
	gPairChoice			= PairChoice
	gBasename1			= Basename1
	gBasename2			= Basename2
	gIndexFind 			= IndexFind
	gRefSpectrum		= RefSpectrum
	
	gProcOp 			= ProcOp
	AlignFlag 			= (ProcOp > 4) ? 1 : 0
	MathOpName 		= StringFromList((ProcOp-4*AlignFlag-1),"Addition;Subtraction;Division;Division less one;none;")
	
	if (AlignFlag)
		Variable AlignChoice = gAlignChoice, AlignMin = gAlignMin, AlignMax = gAlignMax, POrder = gPOrder+1
		Prompt AlignChoice, "Align in a data subrange?", popup, "no - full range;yes - enter below;"
		Prompt AlignMin, "Min. axis value"
		Prompt AlignMax, "Max. axis value"
		Prompt POrder, "Polynomial terms", popup, "0;1;2;"
		DoPrompt "Optional subrange parameters for aligning spectra", AlignChoice, AlignMin, AlignMax,POrder
		if (V_flag)
			return 0
		endif
		
		gAlignChoice 	= AlignChoice
		gAlignMin 		= AlignMin
		gAlignMax 		= AlignMax
		gPOrder		= POrder-1
	endif
	
	gCutNameText		= CutNameText
	gPasteNameText 	= PasteNameText
	gExcludeSpecText 	= ExcludeSpecText
	gReportFlag 		= (ReportFlag == 1) ? 1 : 0
	
	// Select data to process. 
	Data1List = InclusiveWaveList(DataNameList,Basename1,";")
	Data1List = ExclusiveWaveList(Data1List,ExcludeSpecText,";")
	NumData1 = ItemsInList(Data1List)
	
	if (NumData1 == 0)
		DataNameList	= ReplaceString("_data",TextWaveToList(wDataList,0,"",""),"")
		Data1List		= InclusiveWaveList(DataNameList,Basename1,";")
		Data1List 		= ExclusiveWaveList(Data1List,ExcludeSpecText,";")
		NumData1 		= ItemsInList(Data1List)
		
		if (NumData1 == 0)
			DoAlert 0, "No data names match "+Basename1
		endif
	endif
	
	// IF A SINGLE REFERENCE WAVE IS CHOSEN, LOOK THIS UP NOW. 
	if (PairChoice > 3)
		Data2Name	= gRefSpectrum + "_data"
		Data2Folder	= DataFolderNameFromDataName(Data2Name)
		
		WAVE Data2	= $(CheckFolderColon(Data2Folder) + Data2Name)
		WAVE Axis2	= $(CheckFolderColon(Data2Folder) + AxisNameFromDataName(Data2Name))
	endif
	
	// PROCESS DATA PAIRS DEPENDING ON THEIR NAMES - ASSUMES A COMMON BASENAME
	if (PairChoice < 5)
		if (strlen(Basename1) == 0)
			DoAlert 0, "Base/String 1 required!"
			return 0
		endif
	
		FileBase 	= ReplaceString(CutNameText,Basename1,PasteNameText)
		
		for (i=0;i<NumData1;i+=1)

			// DETERMINE DATA 1
			Data1Name	= StringFromList(i,Data1List)+"_data"
			Data1Folder	= DataFolderNameFromDataName(Data1Name)
			Data1Num	= FindDataNumberFromName(Data1Name,IndexFind)
			
			String FullData1Name = CheckFolderColon(Data1Folder) + Data1Name
			String FullAxis1Name = CheckFolderColon(Data1Folder) + AxisNameFromDataName(Data1Name)
			
			WAVE Data1	= $(CheckFolderColon(Data1Folder) + Data1Name)
			WAVE Axis1	= $(CheckFolderColon(Data1Folder) + AxisNameFromDataName(Data1Name))
			
			// DETERMINE DATA 2 
			if (PairChoice == 4)
				// Do nothing - we already have selected a single reference for Data 2. 
			else
				if (PairChoice == 1)
					// Pairchoice1: 2nd wave starts with "basename2", and has same last number as 1st wave
					Data2List 	= InclusiveWaveList(DataNameList,Basename2,";")
					NumData2 	= ItemsInList(Data2List)
					Data2Num	= Data1Num
					
					if (NumData2 == 0)
						DoAlert 0, "No data names match "+Basename2
						return 0
					endif
				elseif (PairChoice == 2)
					// Pairchoice1: 2nd wave is the wave BEFORE the current "basename1"
					Data2List	= Data1List
					Data2Num	= Data1Num - 1
				elseif (PairChoice == 3)
					// Pairchoice1: 2nd wave is the wave AFTER the current "basename1"
					Data2List	= Data1List
					Data2Num	= Data1Num + 1
				endif
				
				Data2Index = FindIndexofNumberedWaveInList(Data2List,IndexFind,Data2Num)
				
				if (Data2Index < 0)
					WAVE Data2	= $("null")
				else
					Data2Name	= StringFromList(Data2Index,Data2List)+"_data"
					Data2Folder	= DataFolderNameFromDataName(Data2Name)
					
					WAVE Data2	= $(CheckFolderColon(Data2Folder) + Data2Name)
					WAVE Axis2	= $(CheckFolderColon(Data2Folder) + AxisNameFromDataName(Data2Name))
				endif
			endif
			
			ProcDataName	= FileBase + "_" + FrontPadString(num2str(Data1Num),"0",3) + "_p_data"
			ProcAxisName	= FileBase + "_" + FrontPadString(num2str(Data1Num),"0",3) + "_p_axis"
			
			SingleDataProcessing(Axis1,Data1,Axis2,Data2,ProcAxisName,ProcDataName,MathOpName,AlignFlag, AlignChoice, AlignMin, AlignMax, POrder, ReportFlag)
			
		endfor
	endif
			
	// PROCESS DATA THAT ARE SELECTED IN THE DATA PLOTTING PANEL. Uses a single reference wave
	if (PairChoice == 5)
		for (i=0;i<numpnts(wDataSel);i+=1)
		
			if (((wDataSel[i] & 2^0) != 0) || ((wDataSel[i] & 2^3) != 0))
				Data1Name		= wDataList[i]
				Data1Folder		= FolderStem + num2str(wDataGroup[i]) + ":" //+ PossiblyQuoteName(DataName)
				FileBase 		= SampleNameFromDataName(Data1Name)
				
				WAVE Data1		= $(CheckFolderColon(Data1Folder) + Data1Name)
				WAVE Axis1		= $(CheckFolderColon(Data1Folder) + AxisNameFromDataName(Data1Name))
				
				ProcDataName	= FileBase + "_p_data"
				ProcAxisName	= FileBase + "_p_axis"
				
				SingleDataProcessing(Axis1,Data1,Axis2,Data2,ProcAxisName,ProcDataName,MathOpName,AlignFlag, AlignChoice, AlignMin, AlignMax, POrder, ReportFlag)
			endif
		endfor
	endif
End

Function SingleDataProcessing(Axis1,Data1,Axis2,Data2,ProcAxisName,ProcDataName,MathOpName,AlignFlag, AlignChoice, AlignMin, AlignMax, POrder, ReportFlag)
	Wave Axis1,Data1,Axis2,Data2
	String ProcAxisName,ProcDataName,MathOpName
	Variable AlignFlag, AlignChoice, AlignMin, AlignMax, POrder,ReportFlag
	
	Variable AxisMin, AxisMax, GoodAlignFlag = 1
	String FullPath, Data1Name=NameOfWave(Data1), Data2Name=NameOfWave(Data2), Data1Note = note(Data1)

	if (WaveExists(Data2) != 1)
		Print " *** Could not process",Data1Name,", probably because the second data could not be found."
		
	elseif (cmpstr(Data1Name,Data2Name) == 0)
		// Two identical waves
		
	else
		if (AlignFlag == 1)
		
			//Determine the optional point subrange for any alignment. 
			if (AlignChoice == 2)
				AxisMin 	= min(AlignMin,AlignMax)
				AxisMax 	= max(AlignMin,AlignMax)
				if (AxisMax == AxisMin)
					AxisMin 	= Axis1[0]
					AxisMax 	= Axis1[numpnts(Axis1)]
				endif
			else
				AxisMin 	= Axis1[0]
				AxisMax 	= Axis1[numpnts(Axis1)]
			endif
	
			WAVE mask 	= $("null")														// Note: gPOrder = POrder-1
			GoodAlignFlag = IzeroFit("root:SPECTRA:Serial:",Axis1,Data1,Data1,Axis2,Data2,mask,AxisMin,AxisMax,0,0,1,POrder,0,0,0,ReportFlag)
		endif
		
		if (GoodAlignFlag != 1)
			Print " *** Could not perform the alignment step! Skipped the processing as well. "
		else
			
			if (strlen(ProcDataName) > 31)
				Print " *** Autoname too long! Skipping this file"
			else
				Duplicate /O/D Axis1, $ProcDataName, $ProcAxisName
				WAVE Processed		= $("root:SPECTRA:Serial:"+ProcDataName)
				Note /K Processed, Data1Note
				
				if (cmpstr(MathOpName,"none") != 0)
					ApplyMathToTwoDataWaves(Data1,Axis1,Data2,Axis2, Processed,ReportFlag,MathOpName)
					
					FullPath = AdoptAxisAndDataFromMemory(ProcAxisName,"null",":",ProcDataName,"null",":",ProcDataName,"",0,0,1)
					
					if (strlen(FullPath) == 0)
						Print " *** User abort during Serial Processing renaming"
						// Clean up? 
						return 0
					endif
				endif
				
				KillWaves /Z $ProcDataName, $ProcAxisName
			endif
		endif
	endif
			
			
			
End

Function FindDataNumberFromName(DataName,IndexFind)
	String DataName
	Variable IndexFind

	if (IndexFind == 1)
		return ReturnLastNumber(DataName)
	else
		return ReturnNthNumber(DataName,IndexFind-1)
	endif
End

Function FindIndexofNumberedWaveInList(DataList,IndexFind,Num)
	String DataList
	Variable IndexFind, Num
	
	Variable j, DataIndex=-1, DataNum, NumData = ItemsInList(DataList)
	
	for(j=0;j<NumData;j+=1)
//		DataNum = ReturnLastNumber(StringFromList(j,DataList))
		DataNum = FindDataNumberFromName(StringFromList(j,DataList),IndexFind)
		
		if (Num == DataNum)
			DataIndex = j
			break
		endif
	endfor
	
	return DataIndex
End

Function /T SScanfTrial(Text,Fmt,TextFlag)
	String Text, Fmt
	Variable TextFlag
	
	String s1
	Variable v1
	
	if (TextFlag)
		sscanf Text, Fmt, s1
	else
		sscanf Text, Fmt, v1
		s1 = num2str(v1)
	endif
	
	return s1
End



//Function SerialSpectraProcessing()
//	
//	WAVE wDataSel 		= root:SPECTRA:wDataSel
//	WAVE /T wDataList 	= root:SPECTRA:wDataList
//	
//	String Data1List, Data2List, Data1Name, Data2Name, Data1Folder, Data2Folder, ProcDataName, ProcAxisName, FileBase
//	Variable i, j, NumData1, NumData2, Data1Num, Data2Num, Data2Index, GoodAlignFlag = 1, ProcAllFlag=0
//	
////	Variable /G gMathOpFlag, gAlignFlag, gOverwriteFlag
//	Variable /G gProcOp, gPairChoice, gPOrder, gIndexFind
//	String /G gRefSpectrum, gCutNameText, gPasteNameText, gExcludeSpecText
//	
//	// Exclude all processed wave "_p_data" from further consideration. 
//	String DataNameList	= ReplaceString("_data",ExclusiveWaveList(TextWaveToList(wDataList,0,"",""),"_p_data",";"),"")
////	String DataNameList = ReplaceString("_data",TextWaveToList(wDataList,0,"",""),"")
//	MakeStringIfNeeded("gBasename1",LookForCommonPrefix(DataNameList))
//	MakeStringIfNeeded("gBasename2",LookForCommonPrefix(DataNameList))
//	
//	SVAR gBasename1	= root:SPECTRA:Serial:gBasename1
//	SVAR gBasename2	= root:SPECTRA:Serial:gBasename2
//	
//	Variable PairChoice = gPairChoice
//	Prompt PairChoice, "Selecting spectra pairs", popup, "matchstr1(n) & matchstr2(n);base1(n) & base2(n);base(n) & base(n-1);base(n) & base(n+1);base(n) & ref;"
//	String Basename1 = gBasename1
//	Prompt Basename1, "Basename 1 text"
////	Variable MathOpFlag = gMathOpFlag
////	Prompt MathOpFlag, "Processing operation", popup, "none (alignment only);1-2;1/2;1/2 - 1;"
//	Variable ProcOp = gProcOp
//	Prompt ProcOp, "Processing operation", popup, "1-2;1/2;1/2 - 1;align 1-2;align 1/2;align 1/2-1;align only;"
//	String Basename2 = gBasename2
//	Prompt Basename2, " ... or Basename 2 text"
//	String RefSpectrum = gRefSpectrum
//	Prompt RefSpectrum, " A single reference ... ", popup, DataNameList
//	Variable IndexFind = gIndexFind
//	Prompt IndexFind, "Data number in filename", popup, "last;1;2;3;4;5;"
////	Variable AlignFlag = gAlignFlag
////	Prompt AlignFlag, "Align the spectra?", popup, "no;yes;"
////	Variable OverwriteFlag = gOverwriteFlag
////	Prompt OverwriteFlag, "Overwrite spectra?", popup, "no;yes;"
//	Variable POrder = gPOrder+1
//	Prompt POrder, "Polynomial terms", popup, "0;1;2;"
//	String CutNameText 	= gCutNameText
//	Prompt CutNameText, "Cut text from filename"
//	String PasteNameText 	= gPasteNameText
//	Prompt PasteNameText, "Insert text into filename"
//	String ExcludeSpecText 	= gExcludeSpecText
//	Prompt ExcludeSpecText, "Skip data with text"
//	
//	DoPrompt "Serial processing parameters", PairChoice, Basename1, RefSpectrum, Basename2, CutNameText, PasteNameText, IndexFind, ProcOp, POrder, ExcludeSpecText
//	if (V_Flag)
//		return -1
//	endif
//	
//	gPairChoice			= PairChoice
//	gBasename1			= Basename1
//	gBasename2			= Basename2
//	gIndexFind 			= IndexFind
//	gRefSpectrum		= RefSpectrum
////	gMathOpFlag 		= MathOpFlag
////	gAlignFlag			= AlignFlag
//	gProcOp 			= ProcOp
////	gOverwriteFlag 		= OverwriteFlag
//	gPOrder			= POrder-1
//	gCutNameText		= CutNameText
//	gPasteNameText 	= PasteNameText
//	gExcludeSpecText 	= ExcludeSpecText
//	
//	// Select data to process. 
//	Data1List = InclusiveWaveList(DataNameList,Basename1,";")
//	Data1List = ExclusiveWaveList(Data1List,ExcludeSpecText,";")
//	NumData1 = ItemsInList(Data1List)
//	
//	Variable AlignFlag 		=  (ProcOp > 3) ? 1 : 0
//	String MathOpName 		= StringFromList((ProcOp-3*AlignFlag-1),"Subtraction;Division;Division less one;none;")
//	
//	if (NumData1 == 0)
//		DoAlert 0, "No data names match "+Basename1
//	else
//		
//		if (strlen(Basename1) == 0)
//			Basename1 	= LookForCommonPrefix(Data1List)
//		endif
//		FileBase 	= ReplaceString(CutNameText,Basename1,PasteNameText)
//		
//		for (i=0;i<NumData1;i+=1)
////		for (i=0;i<5;i+=1)
//			// DETERMINE DATA 1
//			Data1Name	= StringFromList(i,Data1List)+"_data"
//			Data1Folder	= DataFolderNameFromDataName(Data1Name)
//			
//			Data1Num	= FindDataNumberFromName(Data1Name,IndexFind)
////			Data1Num	= ReturnLastNumber(Data1Name)
//			
//			String FullData1Name = CheckFolderColon(Data1Folder) + Data1Name
//			String FullAxis1Name = CheckFolderColon(Data1Folder) + AxisNameFromDataName(Data1Name)
//			
//			WAVE Data1	= $(CheckFolderColon(Data1Folder) + Data1Name)
//			WAVE Axis1	= $(CheckFolderColon(Data1Folder) + AxisNameFromDataName(Data1Name))
//			
//			if (PairChoice == 4)
//				// DETERMINE DATA 2 for PAIRCHOICE 4 (single Reference Trace)
//				if (i == 0)
//					Data2Name	= gRefSpectrum + "_data"
//					Data2Folder	= DataFolderNameFromDataName(Data2Name)
//					
//					WAVE Data2	= $(CheckFolderColon(Data2Folder) + Data2Name)
//					WAVE Axis2	= $(CheckFolderColon(Data2Folder) + AxisNameFromDataName(Data2Name))
//				endif
//			else
//				// DETERMINE DATA 2 for PAIRCHOICE 1 - 3
//				if (PairChoice == 1)
//					// Pairchoice1: 2nd wave starts with "basename2", and has same last number as 1st wave
//					Data2List 	= InclusiveWaveList(DataNameList,Basename2,";")
//					NumData2 	= ItemsInList(Data2List)
//					Data2Num	= Data1Num
//					
//					if (NumData2 == 0)
//						DoAlert 0, "No data names match "+Basename2
//						return 0
//					endif
//				elseif (PairChoice == 2)
//					// Pairchoice1: 2nd wave is the wave BEFORE the current "basename1"
//					Data2List	= Data1List
//					Data2Num	= Data1Num - 1
//				elseif (PairChoice == 3)
//					// Pairchoice1: 2nd wave is the wave AFTER the current "basename1"
//					Data2List	= Data1List
//					Data2Num	= Data1Num + 1
//				endif
//				
//				Data2Index = FindIndexofNumberedWaveInList(Data2List,IndexFind,Data2Num)
//				
//				if (Data2Index < 0)
//					WAVE Data2	= $("null")
//				else
//					Data2Name	= StringFromList(Data2Index,Data2List)+"_data"
//					Data2Folder	= DataFolderNameFromDataName(Data2Name)
//					
//					WAVE Data2	= $(CheckFolderColon(Data2Folder) + Data2Name)
//					WAVE Axis2	= $(CheckFolderColon(Data2Folder) + AxisNameFromDataName(Data2Name))
//				endif
//			endif
//				
//			if (WaveExists(Data2) != 1)
//				Print " *** Could not process",Data1Name,", probably because the second data could not be found."
//			elseif (cmpstr(Data1Name,Data2Name) == 0)
//				// Two identical waves
//			else
//				if (AlignFlag == 1)
//					WAVE mask 	= $("null")														// Note: gPOrder = POrder-1
////					GoodAlignFlag = IzeroFit("root:SPECTRA:Serial:",Axis2,Data2,Data2,Axis1,Data1,mask,0,numpnts(Axis1)-1,0,0,gPOrder,0,0,0)
////					GoodAlignFlag = IzeroFit("root:SPECTRA:Serial:",Axis1,Data1,Data1,Axis2,Data2,mask,0,numpnts(Axis1)-1,0,0,gPOrder,0,0,0)
//					GoodAlignFlag = IzeroFit("root:SPECTRA:Serial:",Axis1,Data1,Data1,Axis2,Data2,mask,0,numpnts(Axis1)-1,0,0,1,gPOrder,0,0,0)
//				endif
//				
//				if (GoodAlignFlag != 1)
//					Print " *** Could not perform the alignment step! Skipped the processing as well. "
//				else
//					ProcDataName	= FileBase + "_" + FrontPadString(num2str(Data1Num),"0",3) + "_p_data"
//					ProcAxisName	= FileBase + "_" + FrontPadString(num2str(Data1Num),"0",3) + "_p_axis"
//					
//					if (strlen(ProcDataName) > 31)
//						Print " *** Autoname too long! Skipping this file"
//					else
//						Duplicate /O/D Axis1, $ProcDataName, $ProcAxisName
//						WAVE Processed		= $("root:SPECTRA:Serial:"+ProcDataName)
//						
//						if (cmpstr(MathOpName,"none") != 0)
//							ApplyMathToTwoDataWaves(Data1,Axis1,Data2,Axis2, Processed,MathOpName)
//							
//							if (AdoptAxisAndDataFromMemory(ProcAxisName,"null",":",ProcDataName,"null",":",ProcDataName,"",0,0) == 0)
//								Print " *** User abort during Serial Processing renaming"
//								// Clean up? 
//								return 0
//							endif
//						endif
//						
//						KillWaves /Z $ProcDataName, $ProcAxisName
//					endif
//				endif
//			endif
//	
//		endfor
//	endif
//End