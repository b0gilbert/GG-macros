#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function AddDataGaps()

	SetDataFolder root:

	String DataGapType = StrVAROrDefault("root:Geochem:gDataGapType","all")
	Prompt DataGapType, "Choose concentration data", popup, "all;single;"
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	String FolderList1 	= ListOfObjectsInFolder(4,"root:")
	Prompt ConcFolder, "Data Source", popup, FolderList1
	DoPrompt "Add NaN values into data gaps", DataGapType, ConcFolder
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gDataGapType = DataGapType
	String /G root:Geochem:gConcFolder = ConcFolder

	String ConcList = ExclusiveWaveList(ExclusiveWaveList(ListOfObjectsInFolder(1,ConcFolder),"_d",";"),"_Z",";")
	String GapData 	= StrVAROrDefault("root:Geochem:gGapData",StringFromList(0,ConcList))
	Prompt GapData, "Concentration data", popup, ConcList

	Variable GapDays = NumVarOrDefault("root:Geochem:gGapDays",2)
	Prompt GapDays, "Minimum gap (days)"
	Variable ConcOrigFlag = 1 // = no
	Prompt ConcOrigFlag, "Backup data series?", popup, "no;yes;"
	
	if (cmpstr(DataGapType,"all") == 0)
		DoPrompt "Set data gap", GapDays, ConcOrigFlag
	else
		DoPrompt "Choose concentration data and set data gap", GapData, GapDays, ConcOrigFlag
//		DoPrompt "Choose concentration data and set data gap", GapData, GapDays, ConcOrigFlag
	endif
	if (V_flag)
		return 0
	endif
	Variable /G root:Geochem:gGapDays = GapDays
	
	Variable n, NSpecies = ItemsInList(ConcList)
	
	SetDataFolder $ConcFolder
	
		if (cmpstr(DataGapType,"all") == 0)
			print "Adding NaN values to data points separated by at least",GapDays,"days for all data in",ConcFolder
			
			for (n=0;n<NSpecies;n+=1)
				GapData 		= StringFromList(n,ConcList)
				if (ConcOrigFlag==2)
					BackUpOriginalGeochem(GapData,ConcFolder)
				endif
				DataNaNInsertion(GapData,ConcFolder,GapDays)
			endfor
		else
			if (ConcOrigFlag==2)
				BackUpOriginalGeochem(GapData,ConcFolder)
			endif
			DataNaNInsertion(GapData,ConcFolder,GapDays)
		endif
		
	SetDataFolder root:
End

Function BackUpOriginalGeochem(ConcName,ConcFolder)
	String ConcName,ConcFolder
	
	String OldDf = GetDataFolder(1)
	String OrigFolder 	= "root:"+ConcFolder+":originals"
	NewDataFolder /O/S $OrigFolder

	String DataParam 	= GeochemParameterFromName(ConcName)
	String DataDays 	= DataParam + "_d"
	String DataDepth 	= DataParam + "_Z"
	
	WAVE CC 	= $("root:"+ConcFolder+":"+ConcName)
	WAVE CO 	= $("root:"+OrigFolder+":"+ConcName)
	
	WAVE CCd 	= $("root:"+ConcFolder+":"+DataDays)
	WAVE CCZ 	= $("root:"+ConcFolder+":"+DataDepth)
	
	// problem here
	if (!WaveExists(CO))
		Duplicate CC, $ConcName
		Duplicate CCd, $DataDays
		if (WaveExists(CCZ))
			Duplicate CCZ, $DataDepth
		endif
	endif
	
	SetDataFolder $OldDf
End

Function DataNaNInsertion(ConcName,ConcFolder,GapDays)
	String ConcName,ConcFolder
	Variable GapDays

	String DataUnit 	= GeochemUnitFromName(ConcName)
	String DataParam 	= GeochemParameterFromName(ConcName)
	String DataDays 	= DataParam + "_d"
	String DataDepth 	= DataParam + "_Z"
	
	WAVE CC 	= $("root:"+ConcFolder+":"+ConcName)
	WAVE CCd 	= $("root:"+ConcFolder+":"+DataDays)
	if (!WaveExists(CCd))
		DataDays 	= ConcName + "_d"
		WAVE CCd 	= $("root:"+ConcFolder+":"+DataDays)
	endif
	if (!WaveExists(CCd))
		return 0
	endif
	WAVE CCz 	= $("root:"+ConcFolder+":"+DataDepth)
	
	Variable GapSecs 	= (60*60*24) * GapDays
	Variable, i, j=1, NGaps = 0, NDays = DimSize(CCd,0)
	
	for (i=1;i<NDays;i+=1)
		// If there are already NaNs creating a data gap we don't need to do that again
		if ( (NumType(CCd[j])==0) && (NumType(CCd[j-1])==0) )
		
			if ( abs(CCd[j] - CCd[j-1]) > GapSecs )
				
				InsertPoints /V=(NaN) j, 1, CC, CCd
				CCd[j] = CCd[j-1] + (60*60*24)
				
				if (WaveExists(CCz))
					InsertPoints /V=(NaN) j, 1, CCz
				endif 
				
				NGaps += 1
				j += 1
			endif
		endif
		j += 1
	endfor
	
	if (NGaps > 0)
			print "	... Added",NGaps," gaps to",ConcName
	endif
End


// 
Function RemoveSeasonalTrends()

	SetDataFolder root:
	
	String CTrendType = StrVAROrDefault("root:Geochem:gCTrendType","all")
	Prompt CTrendType, "Choose concentration data", popup, "all;single;"
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	String CTrendFolder 	= StrVAROrDefault("root:Geochem:gCTrendFolder","Fluxes")
	String FolderList1 	= ListOfObjectsInFolder(4,"root:")
	String FolderList2 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName = ""
	
	Prompt ConcFolder, "Data Source", popup, FolderList1
	Prompt CTrendFolder, "Destination", popup, FolderList2
	Prompt NewFolderName, "Destination"
	DoPrompt "Calculate single or all Concentration trends", CTrendType, ConcFolder, CTrendFolder, NewFolderName
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gCTrendType = CTrendType
	String /G root:Geochem:gConcFolder = ConcFolder
	
	if (cmpstr(CTrendFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		CTrendFolder 	= NewFolderName
	endif
	String /G root:Geochem:gCTrendFolder = CTrendFolder
	
	// List all the data in the Source and Discharge directories
	String ConcList = ListOfObjectsInFolder(1,"root:"+ConcFolder)
	
	ConcList 	= ExclusiveWaveList(ConcList,"_d",";")
	Variable n, NSpecies = ItemsInList(ConcList)
	
	// Select the Concentration data
//	String CCData 	= StringFromList(0,ConcList)
	String CCData = StrVAROrDefault("root:Geochem:gCCData",StringFromList(0,ConcList))
	Prompt CCData, "Concentration data", popup, ConcList
	Variable SSpline = NUMVarOrDefault("root:Geochem:gSSpline",0.4)
	Prompt SSpline, "Smoothing spline parameter"
	Variable TPlot = NUMVarOrDefault("root:Geochem:gTPlot",1)
	Prompt TPlot, "Plot trends", popup, "no;yes;"
	if (cmpstr(CTrendType,"all") == 0)
		DoPrompt "Trend removal", SSpline
	else
		DoPrompt "Choose concentration data and trend removal", CCData, SSpline, TPlot
	endif
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gCCData = CCData
	Variable /G root:Geochem:gSSpline = SSpline
	Variable /G root:Geochem:gTPlot = TPlot
	
	
	SetDataFolder $CTrendFolder
	
		if (cmpstr(CTrendType,"all") == 0)
			KillWaves /A/Z
			print "Removing seasonal trends from the data in",ConcFolder,"and saving to",CTrendFolder,"using smoothing spline factor",SSpline
			
			for (n=0;n<NSpecies;n+=1)
				String CCName 		= StringFromList(n,ConcList)
				String CCUnit 		= GeochemUnitFromName(CCName)
				String CCParam 	= GeochemParameterFromName(CCName)
				String CCdName 	= CCParam + "_d"
				
				WAVE CC 	= $("root:"+ConcFolder+":"+CCName)
				WAVE CCd 	= $("root:"+ConcFolder+":"+CCdName)
				if (!WaveExists(CCd))
					WAVE CCd 	= $("root:"+ConcFolder+":"+CCName+"_d")
				endif
				
				CTrendCalculation(SSpline,1,CCParam,CC,CCd)
			endfor
		else
				CCName 		= CCData
				CCUnit 		= GeochemUnitFromName(CCName)
				CCParam 	= GeochemParameterFromName(CCName)
				CCdName 	= CCParam + "_d"
				
				WAVE CC 	= $("root:"+ConcFolder+":"+CCName)
				WAVE CCd 	= $("root:"+ConcFolder+":"+CCdName)
				if (!WaveExists(CCd))
					WAVE CCd 	= $("root:"+ConcFolder+":"+CCName+"_d")
				endif
				
				print "Calculating Concentration-Discharge relationships for the",CCName,"in",ConcFolder,"and saving to",CTrendFolder,"using smoothing spline factor",SSpline
				CTrendCalculation(SSpline,TPlot,CCParam,CC,CCd)
				
		endif
		
	SetDataFolder root:
End

Function PlotTrends(Ele,cc,cdate,SSp,Res)
	String Ele
	Wave cc,cdate,SSp,Res
	
	Display /K=1/W=(200,262,1572,913) cc vs cdate as "Trend for "+Ele
	AppendToGraph SSp,Res
	
	String ResName = NameOfWave(Res), SSpName = NameOfWave(SSp)
	ModifyGraph mode($ResName)=4, marker($ResName)=8, msize($ResName)=2, opaque($ResName)=1
	ModifyGraph rgb($SSpName)=(1,16019,65535)
	
	ModifyGraph mirror=2
	ModifyGraph dateInfo(bottom)={0,0,0}
	Label left " Concentration"
	Label bottom " Date"
End

Function MakeSplineDestinations(Param,SSuffix,cdate)
	String Param, SSuffix
	Wave cdate
	
	Variable Ncc=DimSize(cdate,0)
	Variable nDays = (cdate[Ncc-1] - cdate[0])/(60*60*24)
	
	String sdate = Param+"s_d"
	
	// Make a date wave 
	Make /O/D/N=(nDays) $(Param+SSuffix+"_d") /WAVE=SpD
	SpD[] = cdate[0] + p*86400
	
	// Make an interpolated parameter wave with daily scale 
	Make /O/D/N=(nDays) $(Param+SSuffix) /WAVE=Sp
	SetScale /P x, cdate[0], 86400, Sp, SpD
	
End

Function CTrendCalculation(SSpF,TPlot,Ele,cc,cdate)
	Variable SSpF, TPlot
	String Ele
	Wave cc,cdate
	
	// Smoothing spline
	MakeSplineDestinations(Ele,"SSp",cdate)
	WAVE SSp = $(Ele+"SSp")
	Interpolate2/T=3/F=(SSpF)/Y=SSp/I=3 cdate,cc
	
	// Linear spline
	MakeSplineDestinations(Ele,"LSp",cdate)
	WAVE LSp = $(Ele+"LSp")
	Interpolate2/T=1/Y=LSp/I=3 cdate,cc
	
	WAVE LSp_d = $(Ele+"LSp_d")
	Duplicate /O LSp_d, $(Ele+"Res_d")
	
	Duplicate /O SSp, $(Ele+"Res")
	WAVE Res = $(Ele+"Res")
	Note Res, "Smoothing factor = "+num2str(SSpF)
	
	Res = LSp - SSp
	
	Res[] 	= (numtype(cc[p]) == 0) ? (Res[p]) : NaN
	
	if (TPlot == 2)
		PlotTrends(Ele,cc,cdate,SSp,Res)
	endif
End





// 
Function ChooseDataColorScheme()

	SetDataFolder root:
	
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	Prompt ConcFolder, "Data Source", popup, ListOfObjectsInFolder(4,"root:")
	
	
	String ColorParams = StrVAROrDefault("root:Geochem:gColorParams","all")
	Prompt ColorParams, "Choose concentration data", popup, "all;single;"
	
	
	String ColorScheme 	= StrVAROrDefault("root:Geochem:gColorScheme","Water Year")
	Prompt ColorScheme, "Color scheme", popup, "Water Year;Limb;Month;Day;"
	DoPrompt "Choose folder and color scheme", ConcFolder, ColorParams, ColorScheme
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gConcFolder = ConcFolder
	String /G root:Geochem:gColorParams = ColorParams
	String /G root:Geochem:gColorScheme = ColorScheme
	
	if (cmpstr(ColorParams,"all") != 0)
		String ConcList = ListOfObjectsInFolder(1,"root:"+ConcFolder)
		ConcList 	= ExclusiveWaveList(ConcList,"_d",";")
		String ColorData = StrVAROrDefault("root:Geochem:gColorData",StringFromList(0,ConcList))
		Prompt ColorData, "Concentration data", popup, ConcList
		DoPrompt "Choose concentration data to choose color scheme", ColorData
		if (V_flag)
			return 0
		endif
		String /G root:Geochem:gColorData = ColorData
	endif
	
	// List all the RGB waves in the Source directory
	String RGBList = ListOfObjectsInFolder(1,"root:"+ConcFolder)
	RGBList 	= InclusiveWaveList(RGBList,"_RGB",";")
	
	Variable n, NSpecies = ItemsInList(RGBList)
		
	if (cmpstr(ColorParams,"all") == 0)
	
		for (n=0;n<NSpecies;n+=1)
			String RGBName 		= StringFromList(n,RGBList)
			WAVE RGB 	= $("root:"+ConcFolder+":"+RGBName)
			
			String DateName = ReplaceString("_RGB",RGBName,"_d")
			WAVE CCd 	= $("root:"+ConcFolder+":"+DateName)
			
			if (cmpstr(ColorScheme,"Water Year")==0)
				RGBWaterYear(RGB,CCd)
			elseif (cmpstr(ColorScheme,"Limb")==0)
			elseif (cmpstr(ColorScheme,"Month")==0)
			elseif (cmpstr(ColorScheme,"Day")==0)
				RGBWaterDay(RGB,CCd)
			endif
		endfor
	else
		RGBName 	= StripSuffixBySeparator(ColorData,"_")+"_RGB"
		WAVE RGB 	= $("root:"+ConcFolder+":"+RGBName)
		DateName = StripSuffixBySeparator(ColorData,"_")+"_d"
		WAVE CCd 	= $("root:"+ConcFolder+":"+DateName)
		
		if (cmpstr(ColorScheme,"Water Year")==0)
			RGBWaterYear(RGB,CCd)
		elseif (cmpstr(ColorScheme,"Limb")==0)
		elseif (cmpstr(ColorScheme,"Month")==0)
			elseif (cmpstr(ColorScheme,"Day")==0)
			RGBWaterDay(RGB,CCd)
		endif
	endif
		
	SetDataFolder root:
End

Function RGBWaterDay(RGB,CCd)
	Wave RGB,CCd
	
	Variable i, NDays=DimSize(CCd,0)
	Variable Day, Month, Year, WaterDay, RGBScale = 256
	
	for (i=0;i<NDays;i+=1)
		Year 		= str2num(StringFromList(0,Secs2Date(CCd[i],-2,";")))
		Month 	= str2num(StringFromList(1,Secs2Date(CCd[i],-2,";")))
		Day 		= str2num(StringFromList(2,Secs2Date(CCd[i],-2,";")))
		WaterDay 	= CalendarToWaterDay(Year,Month,Day)
		RGB[i] = RGBScale * (365 - WaterDay)/365
	endfor
End

Function CalendarToWaterDay(Year,Month,Day)
	Variable Year,Month,Day
	
	Variable isLeap, WaterDay
	
	isLeap = mod(Year,4) == 0 ? 1 : 0
	
	switch(Month)
		case 10:				// start of October
			WaterDay = 0
			break
		case 11:				// start of November
			WaterDay = 31	// days in October
			break
		case 12:
			WaterDay = 31 + 30 
			break
		case 1:
			WaterDay = 31 + 30 + 31
			break
		case 2:
			WaterDay = 31 + 30 + 31 + 31 
			break
		case 3:
			WaterDay = 31 + 30 + 31 + 31 + 28 + isLeap  
			break
		case 4:
			WaterDay = 31 + 30 + 31 + 31 + 28 + isLeap + 31
			break
		case 5:
			WaterDay = 31 + 30 + 31 + 31 + 28 + isLeap + 31 + 30
			break
		case 6:
			WaterDay = 31 + 30 + 31 + 31 + 28 + isLeap + 31 + 30 + 31
			break
		case 7:
			WaterDay = 31 + 30 + 31 + 31 + 28 + isLeap + 31 + 30 + 31 + 30
			break
		case 8:
			WaterDay = 31 + 30 + 31 + 31 + 28 + isLeap + 31 + 30 + 31 + 30 + 31
			break
		case 9:
			WaterDay = 31 + 30 + 31 + 31 + 28 + isLeap + 31 + 30 + 31 + 30 + 31 + 31
			break
	endswitch
	
	WaterDay += Day
	
	return WaterDay
End


Function RGBWaterYear(RGB,CCd)
	Wave RGB,CCd
	
	Variable i, NDays=DimSize(CCd,0)
	
	Variable Year1,Year2, NYears, RGBScale, Month,Day
	ReturnYearMonthDay(CCd[0],Year1,Month,Day)
	ReturnYearMonthDay(CCd[NDays-1],Year2,Month,Day)
	NYears 		= Year2-Year1
	RGBScale 	= 256/NYears
	
	for (i=0;i<NDays;i+=1)
		Year2 = str2num(StringFromList(0,Secs2Date(CCd[i],-2,";")))
		RGB[i] = RGBScale * ((Year2 - Year1)/NYears)
	endfor
End





Function MeanFlux()

	WAVE AWave = CsrWaveRef(A)
	WAVE AXWave = CsrXWaveRef(A)
	WAVE BWave = CsrWaveRef(B)
	WAVE BXWave = CsrXWaveRef(B)
	
	if (WaveExists(AWave) && WaveExists(BWave))
		print "Averaging",NameOfWave(AWave),"between", secs2Date(AXWave[pcsr(A)],0), "and",secs2Date(BXWave[pcsr(B)],0)
	else 
		return 0
	endif
	Variable APoint = min(pcsr(A),pcsr(B))
	Variable BPoint 	= max(pcsr(A),pcsr(B))
	Variable AXVal = min(AXWave[pcsr(A)],BXWave[pcsr(B)])
	Variable BXVal = max(AXWave[pcsr(A)],BXWave[pcsr(B)])
	
	WaveStats /R=[APoint,BPoint ]/Q/M=1 AWave
	
	print V_avg
End

Function ConvertParameterUnits()

	SetDataFolder root:
	
//	String UnitList 	= "ppb;ppm;uM;mM;mol/L;ug/L;mgpL;Pc;"
	String UnitList 	= "ppb;ppm;uM;mM;molpL;ugpL;mgpL;Pc;"
	
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	ConcFolder 	= ChooseAFolder("",ConcFolder,"Data Source","Choose data folder for conversion",0)
	if (strlen(ConcFolder) == 0)
		return 0
	endif
	String /G $("root:Geochem:gConcFolder") = ConcFolder
	String SpeciesList 	= ExclusiveWaveList(ListOfObjectsInFolder(1,ConcFolder),"_d",";")
	
	String Species, InputUnit, OutputUnit, OutputName
	Prompt Species, "Parameter", popup, SpeciesList
	// Prompt InputUnit, "Input unit", popup, UnitList
	Prompt OutputUnit "Output unit", popup, UnitList
	Prompt OutputName "(Optional) New name"
	DoPrompt "Choose parameter and units", Species, OutputUnit, OutputName
	if (V_flag)
		return 0
	endif
	
	String Msg, Unit, Param, CCConvert
	Unit 	= GeochemUnitFromName(Species)
	Param = GeochemParameterFromName(Species)
	Msg 	= " Converted "+Species+" from "+Unit+" to "+OutputUnit
	
	// The input species concentrations and dates
	WAVE CC 		= $("root:"+ConcFolder+":"+Species)
	WAVE CCd 		= $("root:"+ConcFolder+":"+Param+"_d")		// Only needed if we are changing the name
	Variable NDays = DimSize(CC,0)
	
	if (strlen(OutputName) > 0)
		CCConvert 	= OutputName + "_" + OutputUnit
		Duplicate /O/D CCd, $("root:"+ConcFolder+":"+OutputName+"_d")
		Msg = Msg +" and changed the name to "+OutputName+"_"+OutputUnit
	else
		CCConvert 	= Param + "_" + OutputUnit
	endif
	
	if (strsearch(UnitList,Unit,0) == -1)
		return 0
	endif
		
	Make /FREE/D/N=(NDays) CCppb
	Make /O/D/N=(NDays) $("root:"+ConcFolder+":"+CCConvert) /WAVE=Convert
	
	ConvertDataBetweenUnitAndPPB(1,Param,Unit,CC,CCppb)
	
	ConvertDataBetweenUnitAndPPB(0,Param,OutputUnit,Convert,CCppb)
	
	print Msg
End

Function ConvertDataBetweenUnitAndPPB(Scale2PPB,Param,Unit,CC,CCppb)
	Variable Scale2PPB
	String Param,Unit
	Wave CC,CCppb
	
	Variable Z, Mass, scale=1
	
	Mass = SoluteFormulaMass(Param)
			
	strswitch(Unit)	
		case "ppb":
			break	
		case "ppm":
			scale = 1000
			break
			
		case "ugpL":
			break	
		case "mgpL":
			scale = 1000
			break
			
		case "uM":
			scale = Mass
		case "mM":
			scale = Mass * 1000
			break
		case "molpL":
			scale = Mass * 1000000
			break
			
		default:
			scale=1
	endswitch
	
	if (Scale2PPB==1) 	// Convert TO ppb, equivalent to µg/L
		CCppb = CC * scale
	else 					// Convert FROM ppb
		CC = CCppb / scale		
	endif
End

//Function ConvertFromPPBToUnit(Param,Unit,CCppb,CC)
//	String Param,Unit
//	Wave CCppb, CC
//
//	Variable Z = AtomToZNumber(ReturnTextBeforeNumber(Param),1)
//	
//	Variable M = ZNumberToMass(Z)
//End



// 
Function CalculateCQ()

	SetDataFolder root:

	Variable Year, Month, Day, DateStartSecs=0, DateStopSecs=0
	Variable DateRange 	= NumVAROrDefault("root:Geochem:gDateRange",1)
	String DateStart 		= StrVAROrDefault("root:Geochem:gDateStart","2010-10-31")
	String DateStop 		= StrVAROrDefault("root:Geochem:gDateStop","2024-09-01")
	
	String CQType = StrVAROrDefault("root:Geochem:gCQType","all")
	Prompt CQType, "Choose CQ data", popup, "all;single;"
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	String DischargeFolder 	= StrVAROrDefault("root:Geochem:gDischargeFolder","PH_Isco")
	String CQFolder 	= StrVAROrDefault("root:Geochem:gCQFolder","Fluxes")
	String FolderList1 	= ListOfObjectsInFolder(4,"root:")
	String FolderList2 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName = ""
	
	Prompt ConcFolder, "Data Source", popup, FolderList1
	Prompt DischargeFolder, "Discharge Data Source", popup, FolderList1
	Prompt CQFolder, "Destination", popup, FolderList2
	Prompt NewFolderName, "Destination"
	Prompt DateRange, "Date subrange?", popup, "no;yes;"
	DoPrompt "Calculate single or all CQ", CQType, ConcFolder, DischargeFolder, CQFolder, NewFolderName, DateRange
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gCQType = CQType
	String /G root:Geochem:gConcFolder = ConcFolder
	String /G root:Geochem:gDischargeFolder = DischargeFolder
	Variable /G root:Geochem:gDateRange = DateRange
	
	if (cmpstr(CQFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		CQFolder 	= NewFolderName
	endif
	String /G root:Geochem:gCQFolder = CQFolder
	
	// List all the data in the Source and Discharge directories
	String ConcList = ListOfObjectsInFolder(1,"root:"+ConcFolder)
	String DischList = ListOfObjectsInFolder(1,"root:"+DischargeFolder)
	
	// Select the Concentration and Discharge data
	String CCData 	= StringFromList(0,ConcList)
	Prompt CCData, "Concentration data", popup, ConcList
	String DischName 	= StrVAROrDefault("root:Geochem:gDischargeName",StringFromList(0,DischList))
	Prompt DischName, "Discharge Data", popup, DischList
	if (cmpstr(CQType,"all") == 0)
		DoPrompt "Choose discharge data", DischName
	else
		DoPrompt "Choose discharge and concentration data", DischName, CCData
	endif
	if (V_flag)
		return 0
	endif
	String DischUnit = GeochemUnitFromName(DischName)
	String /G root:Geochem:gDischargeName = DischName
	
	if (DateRange==2)
		if (PromptForDateSubrange(DateStart,DateStop) == 0)
			return 0
		endif
		String /G root:Geochem:gDateStart = DateStart
		String /G root:Geochem:gDateStop = DateStop
		
		ReturnYearMonthDayFromString(Year,Month,Day,DateStart)
		DateStartSecs = Date2Secs(Year, Month, Day)
		ReturnYearMonthDayFromString(Year,Month,Day,DateStop)
		DateStopSecs = Date2Secs(Year, Month, Day)
	endif
	
	
	WAVE QQ = $("root:"+DischargeFolder+":"+DischName)
	WAVE QQd 	= $("root:"+DischargeFolder+":"+GeochemDateFromName(DischName))
	
	// Remove discharge from the list of concentrations
	ConcList 	= ExclusiveWaveList(ExclusiveWaveList(ExclusiveWaveList(ConcList,"_d",";"),DischName,";"),"Species",";")
	Variable n, NSpecies = ItemsInList(ConcList)
	
	SetDataFolder $CQFolder
	
		if (cmpstr(CQType,"all") == 0)
			KillWaves /A/Z
			print "Calculating Concentration-Discharge relationships for the data in",ConcFolder,"and saving to",CQFolder
			
			for (n=0;n<NSpecies;n+=1)
				String CCName 		= StringFromList(n,ConcList)
				String CCUnit 		= GeochemUnitFromName(CCName)
				String CCParam 	= GeochemParameterFromName(CCName)
				String CCdName 	= CCParam + "_d"
				
				WAVE CC 	= $("root:"+ConcFolder+":"+CCName)
				WAVE CCd 	= $("root:"+ConcFolder+":"+CCdName)
				if (!WaveExists(CCd))
					WAVE CCd 	= $("root:"+ConcFolder+":"+CCName+"_d")
				endif
				
				CQCalculation(CCParam,QQ,QQd,CC,CCd,DateStartSecs,DateStopSecs)
				
				FieldDataWaterYearAxes(CCd)
			endfor
		else
				CCName 		= CCData
				CCUnit 		= GeochemUnitFromName(CCName)
				CCParam 	= GeochemParameterFromName(CCName)
				CCdName 	= CCParam + "_d"
				
				WAVE CC 	= $("root:"+ConcFolder+":"+CCName)
				WAVE CCd 	= $("root:"+ConcFolder+":"+CCdName)
				if (!WaveExists(CCd))
					WAVE CCd 	= $("root:"+ConcFolder+":"+CCName+"_d")
				endif
				
				print "Calculating Concentration-Discharge relationships for the",CCName,"data in",ConcFolder,"and saving to",CQFolder
				CQCalculation(CCParam,QQ,QQd,CC,CCd,DateStartSecs,DateStopSecs)
				
				FieldDataWaterYearAxes(CCd)
		endif
		
		print "			... using the Discharge data",DischName,"in",DischargeFolder
		if (DateRange==2)
			print " 			... time range limited to",DateStart," to ",DateStop
		endif
		
	SetDataFolder root:
End

Function CQCalculation(Ele,qq,qdate,cc,cdate,dSt,dSp)
	String Ele
	Wave qq,qdate,cc,cdate
	Variable dSt,dSp
	
	Variable i, qDay, qVal, cDay, cVal, nDays=0
	Variable Nqq=DimSize(qdate,0), Ncc=DimSize(cdate,0)
	
	Make /O/N=0 $(Ele+"_C") /WAVE=CWave
	Make /O/N=0 $(Ele+"_Q") /WAVE=QWave
	Make /O/N=0 $(Ele+"_d") /WAVE=DWave
	Make /O/N=0 $(Ele+"_RGB") /WAVE=RGBWave
	
	// Loop through all valid Element dates
	for(i=0;i<Ncc;i+=1)
		cDay 	= cdate[i]
		if (numtype(cDay) == 0)
			cVal 	= cc[i]
			if (numtype(cVal) == 0)
				FindValue /V=(cDay) qdate
				if (V_value != -1)
					qVal 	= qq[V_value]
					if (numtype(qVal) == 0)
						
						if ( (dSt==0) || ( (dSt>0) && (cDay>dSt) ) )
							if ( (dSp==0) || ( (dSp>0) && (cDay<dSp) ) )
								nDays += 1
								Redimension /N=(nDays) CWave, QWave, DWave, RGBWave
								DWave[nDays-1] 	= cDay
								CWave[nDays-1] 	= cVal
								QWave[nDays-1] 	= qVal
							endif 
						endif
						
					endif
				endif
			endif
		endif
	endfor
End


// INPUTS: 
// 	Daily Solute Concentration Data (uM)
// 	- CURRENTLY (Average) Daily Discharge (m3/s)	! NOW WE HAVE A CONVERSION ROUTINE
// 	- SHOULD BE Integrated Daily Discharge (m3/d)
// OUTPUTS
// 	Annual Solute Exports (moles per year)
Function CalculateWaterYearExports()

	SetDataFolder root:
	
	String WYEType = StrVAROrDefault("root:Geochem:gWYEType","all")
	Prompt WYEType, "Choose solute data", popup, "all;single;"
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	String DischargeFolder 	= StrVAROrDefault("root:Geochem:gDischargeFolder","PH_Isco")
	String WYEFolder 	= StrVAROrDefault("root:Geochem:gWYEFolder","Exports")
	String FolderList1 	= ListOfObjectsInFolder(4,"root:")
	String FolderList2 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName = ""
	Prompt ConcFolder, "Folder with concentrations (uM or common)", popup, FolderList1
	Prompt DischargeFolder, "Folder with discharge (m3/s)", popup, FolderList1
	Prompt WYEFolder, "Destination", popup, FolderList2
	Prompt NewFolderName, "Destination"
	DoPrompt "Calculate single or all exports", WYEType, ConcFolder, DischargeFolder, WYEFolder, NewFolderName
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gWYEType = WYEType
	String /G root:Geochem:gConcFolder = ConcFolder
	String /G root:Geochem:gDischargeFolder = DischargeFolder
	
	if (cmpstr(WYEFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		WYEFolder 	= NewFolderName
	endif
	String /G root:Geochem:gWYEFolder = WYEFolder
	
	// List all the data in the Source and Discharge directories
	String ConcList = ExclusiveWaveList(ListOfObjectsInFolder(1,"root:"+ConcFolder),"_d",";")
	
	// Only allow concentrations in µM
//	ConcList 	= InclusiveWaveList(ConcList,"_uM",";")
	String DischList = ListOfObjectsInFolder(1,"root:"+DischargeFolder)

	Variable WaterYear1 		= NumVAROrDefault("root:Geochem:gWaterYear1",2015)
	Variable WaterYear2 		= NumVAROrDefault("root:Geochem:gWaterYear2",2022)
	Prompt WaterYear1, "First Water Year"
	Prompt WaterYear2, "Last Water Year"
	
	// Select the Concentration and Discharge data
	String CCData 	= StringFromList(0,ConcList)
	Prompt CCData, "Concentration data (uM or common)", popup, ConcList
	String DischName 	= StrVarOrDefault("root:Geochem:gDischargeName",StringFromList(0,DischList))
	Prompt DischName, "Discharge Data (m3/d)", popup, DischList
	if (cmpstr(WYEType,"all") == 0)
		DoPrompt "Choose discharge data", DischName, WaterYear1, WaterYear2
	else
		DoPrompt "Choose discharge and concentration data", DischName, CCData, WaterYear1, WaterYear2
	endif
	if (V_flag)
		return 0
	endif
	String DischUnit = GeochemUnitFromName(DischName)
	String /G root:Geochem:gDischargeName = DischName
	
	Variable NWYs = WaterYear2 - WaterYear1 + 1
	if (NWYs < 0)
		return 0
	endif
	Variable /G root:Geochem:gWaterYear1 = WaterYear1
	Variable /G root:Geochem:gWaterYear2 = WaterYear2
	
	WAVE QQ = $("root:"+DischargeFolder+":"+DischName)
	WAVE QQd 	= $("root:"+DischargeFolder+":"+GeochemDateFromName(DischName))
	
	ConcList 	= ExclusiveWaveList(ExclusiveWaveList(ConcList,DischName,";"),"Species",";")
	
	// Remove discharge from the list of concentrations
//	ConcList 	= ExclusiveWaveList(ExclusiveWaveList(ExclusiveWaveList(ConcList,"_d",";"),DischName,";"),"Species",";")
	Variable NSpecies = ItemsInList(ConcList)
	
	
	SetDataFolder $WYEFolder
		
		Variable i, j, n, nMin, nMax, WaterYear, SoluteExport, WaterExport
		
		if (cmpstr(WYEType,"single")==0)
			nMin 	= WhichListItem(CCData,ConcList)
			nMax 	= nMin+1
			print "Calculating Water-Year Averages from",WaterYear1,"to",WaterYear2," for",CCData,"in",ConcFolder,"and saving in",WYEFolder
		else
			nMin 	= 0
			nMax 	= NSpecies
			print "Calculating Water-Year Averages from",WaterYear1,"to",WaterYear2," for the data in",ConcFolder,"and saving in",WYEFolder
		endif
		
		// LOOP OVER SPECIES IN THE FOLDER using INDEX n
		for (n=nMin;n<nMax;n+=1)

			// The Selected Field Data 
			String CCName 		= StringFromList(n,ConcList)
			String CCUnit 		= GeochemUnitFromName(CCName)
			String CCParam 		= GeochemParameterFromName(CCName)
			String CCdName 		= CCParam + "_d"
			
			WAVE CC 	= $("root:"+ConcFolder+":"+CCName)
			WAVE CCd 	= $("root:"+ConcFolder+":"+CCdName)
			if (!WaveExists(CCd))
				CCdName 		= CCName + "_d"
				WAVE CCd 	= $("root:"+ConcFolder+":"+CCdName)
			endif
			
			// Check Solute Units
			if (cmpstr(CCUnit,"uM") == 0)
				Duplicate /FREE CC, Conc_uM
			else
				String dummyUnit = "uM"
				Variable ConcPPB 	= ConvertBetweenUnitAndPPB(1,CCParam,CCUnit,1)
				Variable ConcUM 	= ConvertBetweenUnitAndPPB(-1,CCParam,dummyUnit,ConcPPB)
				print "	... 	converting",CCParam,"concentrations from",CCUnit,"to µM. 1",CCUnit,CCParam," =",ConcPPB,"ppb = ",ConcUM,"µM. "
				
				Duplicate /FREE CC, Conc_ppb, Conc_uM
				ConvertDataBetweenUnitAndPPB(1,CCParam,CCUnit,CC,Conc_ppb)
				ConvertDataBetweenUnitAndPPB(-1,CCParam,"uM",Conc_uM,Conc_ppb)
			endif
			
//			if (cmpstr(CCUnit,"uM") == 0)
				
				if (cmpstr(CCParam,"SpeciesExports")==0)
				elseif (cmpstr(CCParam,"SpeciesNames")==0)
				else
					String WYExportCCName 	= CCName + "_MolpYr"
					String WYExportQQName 	= CCName + "_MolpYr_QQ_m3pYr"
					String WYExportQQName2 	= CCName + "_MolpYr_QQ_Mm3pYr"
					String WYExportYrName 	= CCName + "_MolpYr_Yr"
					String WYExportYr2Name 	= CCName + "_MolpYr_Yr2"
					String WYExportYrSecs 	= CCName + "_MolpYr_YrSecs"
					Make /O/D/N=(NWYs) $WYExportCCName /WAVE=WYExCC
					Make /O/D/N=(NWYs) $WYExportCCName /WAVE=WYExCC
					Make /O/D/N=(NWYs) $WYExportQQName /WAVE=WYExQQ
					Make /O/D/N=(NWYs) $WYExportQQName2 /WAVE=WYExQQ2
					Make /O/D/N=(NWYs) $WYExportYrName /WAVE=WYExYR
					Make /O/D/N=(NWYs) $WYExportYr2Name /WAVE=WYExYR2
					Make /O/D/N=(NWYs) $WYExportYrSecs /WAVE=WYExYRSecs
					
					// LOOP OVER WATER YEARS using INDEX i
					for (i=0;i<NWYs;i+=1)
						WaterYear 	= WaterYear1 + i
						WYExYR[i] 	= WaterYear
						WYExYR2[i] 	= str2num(num2str(WaterYear)[2,3])
						
						CalculateSoluteWYExport(Conc_uM,CCd,QQ,QQd,WaterYear,SoluteExport,WaterExport)
						
//						CalculateSoluteWYExport(CC,CCd,QQ,QQd,WaterYear,SoluteExport,WaterExport)

						WYExCC[i] 	= SoluteExport
						WYExQQ[i] 	= WaterExport
						WYExQQ2[i] 	= 1e-6 * WaterExport
						
						WYExYRSecs[i] 	= date2Secs(WaterYear,3,1)
					endfor
				endif
				
//			endif 
				
		endfor
		
//		DisplayWaterYearExports(WYExportCCName,WYExportYr2Name,WYExportQQName,WYEFolder,WYEFolder,"new")
		DisplayWaterYearExports(WYExportCCName,WYExportYr2Name,WYExportQQName2,WYEFolder,WYEFolder,"new")
		
	SetDataFolder root:
End


// INPUT Arrays
// 	CC 		(µM)
//		QQ 		(m3/s)
// INPUT Variables
// 	WY 		The selected Water YEar
// OUTPUT Arrays
// 	CEx		(moles/day)
// 	QEx		(m3/day)
//  Annual fluxes

// Calculate the annual export using the AreaXY function to handle missing days. 
Function CalculateSoluteWYExport(CCin,CCdin,QQ,QQd,WY,SoluteExport,WaterExport)
	Wave CCin,CCdin,QQ,QQd
	Variable WY, &SoluteExport,&WaterExport
	
	Variable i, WYDay=0, WYDayS, CountDays=0
	Variable iMax = 28 + IsLeap(WY)
	
	Variable WYStartSecs 	= date2secs(WY-1,10,01)
	Variable WYStopSecs 	= date2secs(WY,9,30)
	
	Duplicate /FREE CCin, CC
	Duplicate /FREE CCdin, CCd
	
	WaveStats /Q/M=1 CC
	if (V_numNans > 0)
		StripNANsFromWaveAxisPair(CC,CCd)
	endif
		
	// These might be useful to keep 
	Make /O/D/N=0 CEx, CEXd, QEx, QEXd, WYd
//	Make /FREE/D/N=0 CEx, CEXd, QEx, QEXd, WYd
	
	// Loop through Oct-01 to Dec-31 = 92 days
	
	for (i=0;i<31;i+=1)		// October
		WYDay 	+= 1
		WYDayS 	= date2secs(WY-1,10,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor 
	for (i=0;i<30;i+=1)		// November
		WYDay 	+= 1
		WYDayS 	= date2secs(WY-1,11,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor 
	for (i=0;i<31;i+=1)		// December
		WYDay 	+= 1
		WYDayS 	= date2secs(WY-1,12,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	
	for (i=0;i<31;i+=1)		// January 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,1,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<iMax;i+=1)	// February, considering leap years
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,2,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<31;i+=1)		// March 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,3,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<30;i+=1)		// April 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,4,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<31;i+=1)		// May 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,5,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<30;i+=1)		// June 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,6,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<31;i+=1)		// July 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,7,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<31;i+=1)		// August 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,8,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	for (i=0;i<30;i+=1)		// September 
		WYDay 	+= 1
		WYDayS 	= date2secs(WY,9,i)
		CountDays += DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	endfor
	
	// Variable SoluteExport = 0, WaterExport = 0
	
	if (WYDay > 0)
		// Calculate the annual export using the AreaXY function to handle missing days. 
		SoluteExport 	= areaXY(WYd,CEx)
		WaterExport 		= areaXY(WYd,QEx)
	endif 
	
	Variable printFlag=0
	if (printFlag)
		print " For Water Year",WY,"the total solute export is",SoluteExport,"moles per year and the total water export is",WaterExport,"m3 per year, measured over",WYDay,"days"
		print " 		... there are ",DimSize(CCin,0),"solute data points and we generated",CountDays,"export data points"
	endif
	
	// return SoluteExport
End

// Append all Solute-Export and Discharge values for each day where data exist. 
Function DailyExport(WYDayS,WYDay,CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd)
	Variable WYDayS, WYDay
	Wave CC,CCd,QQ,QQd,CEx,CEXd,QEx,QEXd,WYd
	
	Variable CVal, QVal, QExport, CCmolm3, CExport, AddDay = 0
	
	Variable NDays 	= DimSize(CEx,0)
	
	// Look up the input day in the Solute data
	FindValue /V=(WYDayS) CCd
	
	if (V_value > -1)
		CVal 		= CC[V_value]
		
		// Look up the input day in the Discharge data
		FindValue /V=(WYDayS) QQd
		
		if (V_value > -1)
			QVal 	= QQ[V_value]
			
			Redimension /N=(NDays+1) CEx,CEXd,QEx,QEXd,WYd
			
			// Convert 1 measurement of discharge in m3/s to a total m3/day 
			QExport 	= (60 * 60 * 24) * QVal
			
			// Convert µmoles to moles (1e-6) and L to m3 (1e3)
			CCmolm3 	= 1e-3 * CVal
			
			// Multiply concentration (moles/m3) by discharge (m3 / day)
			CExport 	= QExport * CCmolm3
			
			CEx[NDays] 	= CExport
			CEXd[NDays]	= WYDayS
			
			QEx[NDays] 	= QExport
			QEXd[NDays]	= WYDayS
			
			WYd[NDays]	= WYDay
			
			AddDay = 1
		endif
	endif
	
	FindValue /V=(WYDayS) CCd
	Variable SoluteFind = V_value
	FindValue /V=(WYDayS) QQd
	Variable DischargeFind = V_value
		
	Variable printFlag=0
	if ( (DischargeFind < 0) && printFlag)
		print WYDay, WYDayS, SoluteFind, DischargeFind
	endif 
	
	return AddDay
End 

Function StripNANsFromWaveAxisPair(Data,Axis)
	Wave Data,Axis
	
	Variable i=0
	for (i=0;i<numpnts(Data);i+=1)
		if (numtype(Data[i])==2)
			DeletePoints i, 1, Data, Axis
			i-=1
		endif
	endfor
End















































// IMPORTANT CHANGE: If data are missing, take the average for all other water years. 
Function WaterYearAverages2()

	SetDataFolder root:
	
	// First User Prompt
	String DataFolder 			= StrVAROrDefault("root:Geochem:gDataFolder","PH_Isco")
	String WYAvgData 			= StrVAROrDefault("root:Geochem:gWYAvgData","")
	String WYAvgFolder 		= StrVAROrDefault("root:Geochem:gWYAvgFolder","PH_ISCO_WYAvg")
	String WYAvgCalc 			= StrVAROrDefault("root:Geochem:gWYAvgCalc","WY average")
	String WYAvgType 			= StrVAROrDefault("root:Geochem:gWYAvgType","all")
	String WYGapChoice 		= StrVAROrDefault("root:Geochem:gWYGapChoice","Use average")
	String FolderList1 		= ListOfObjectsInFolder(4,"root:")
	String FolderList2 		= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName 		= ""
	
	Variable WaterYear1 		= NumVAROrDefault("root:Geochem:gWaterYear1",2015)
	Variable WaterYear2 		= NumVAROrDefault("root:Geochem:gWaterYear2",2022)
	
	Prompt DataFolder, "Data Source", popup, FolderList1
	Prompt WYAvgType, "Data for water year average(s)", popup, "all;single;"
	Prompt WYAvgFolder, "Destination", popup, FolderList2
	Prompt WaterYear1, "First Water Year"
	Prompt WaterYear2, "Last Water Year"
	Prompt NewFolderName, "Destination"
	Prompt WYAvgCalc, "Type of calculation", popup, "WY average;WY statistics;all;"
	Prompt WYGapChoice, "Day gap filling method", popup, "Use average;Use prior;"
	DoPrompt "Choose data for Water Year Averages", DataFolder, WYAvgType, WYAvgFolder, NewFolderName, WaterYear1, WaterYear2, WYAvgCalc
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gDataFolder = DataFolder
	String /G root:Geochem:gWYAvgType = WYAvgType
	String /G root:Geochem:gWYAvgCalc = WYAvgCalc
	String /G root:Geochem:gWYGapChoice = WYGapChoice
	
	if (cmpstr(WYAvgFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		WYAvgFolder 	= NewFolderName
	endif
	String /G root:Geochem:gWYAvgFolder = WYAvgFolder
	
	if (WaterYear2 < WaterYear1)
		return 0
	endif
	Variable /G root:Geochem:gWaterYear1 = WaterYear1
	Variable /G root:Geochem:gWaterYear2 = WaterYear2
	
	// Make a list of all the data in the Source folder. 
	String ConcList 	= ListOfObjectsInFolder(1,"root:"+DataFolder)
	ConcList 	= ExclusiveWaveList( ConcList, "_d", ";")
	Variable NSpecies = ItemsInList(ConcList)
	
	
	// (Optional) Second User Prompt for a Single Dataset 
	Variable WYDataNum 	= WhichListItem(WYAvgData,ConcList)
	if (WYDataNum < 0)
		WYAvgData 	= StringFromList(0,ConcList)
	endif
	Prompt WYAvgData, "Data for water year average", popup, ConcList
	if (cmpstr(WYAvgType,"single") == 0)
		DoPrompt "Choose data", WYAvgData
	endif
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gWYAvgData = WYAvgData
	
	
	SetDataFolder $WYAvgFolder
		// KillWaves /A/Z

		Variable i, n, m, WY, nData, nMin, nMax, DataDay, WYDay=1, WYNum=0, WYDays, WYCurrent, WYNew
		Variable DataVal, DataMin=1e99, DataMinLoc, DataMax=0, DataMaxLoc
		
		if (cmpstr(WYAvgType,"single")==0)
			nMin 	= WhichListItem(WYAvgData,ConcList)
			nMax 	= nMin+1
			print "Calculating Water-Year Averages from",WaterYear1,"to",WaterYear2," for",WYAvgData,"in",DataFolder,"and saving in",WYAvgFolder
		else
			nMin 	= 0
			nMax 	= NSpecies
			print "Calculating Water-Year Averages from",WaterYear1,"to",WaterYear2," for the data in",DataFolder,"and saving in",WYAvgFolder
		endif
		
		// LOOP OVER SPECIES IN THE FOLDER using INDEX n
		for (n=nMin;n<nMax;n+=1)

			// The Selected Field Data 
			String CCName 		= StringFromList(n,ConcList)
			String CCUnit 		= GeochemUnitFromName(CCName)
			String CCParam 		= GeochemParameterFromName(CCName)
			String CCdName 		= CCParam + "_d"
			
			WAVE CC 	= $("root:"+DataFolder+":"+CCName)
			WAVE CCd 	= $("root:"+DataFolder+":"+CCdName)
			if (!WaveExists(CCd))
				CCdName 		= CCName + "_d"
				WAVE CCd 	= $("root:"+DataFolder+":"+CCdName)
			endif
			
			if (cmpstr(CCParam,"SpeciesExports")==0)
			elseif (cmpstr(CCParam,"SpeciesNames")==0)
			else
//				print " 	...",CCParam
				SpeciesWaterYearAverage(CCParam,CCUnit,WYAvgFolder,WYAvgCalc,CCd,CC,WaterYear1,WaterYear2)
			endif
				
		endfor
		
	SetDataFolder root:
End

Function SpeciesWaterYearAverage(CCParam,CCUnit,WYAvgFolder,WYAvgCalc,CCd,CC,WaterYear1,WaterYear2)
	String CCParam, CCUnit, WYAvgFolder, WYAvgCalc
	Wave CCd,CC
	Variable WaterYear1,WaterYear2

//		Variable nData 	= DimSize(CC,0)
		Variable n, m, WY, WYDays, nData, DataVal
		Variable NYears 	= WaterYear2 - WaterYear1 + 1
		
		Make /O/D/N=(NYears,4) $(CCParam + "totals_" + CCUnit) /WAVE=WYtotals					// Array with different types of average
		Make /O/D/N=(NYears,366) $(CCParam + "_WYAll_" + CCUnit) /WAVE=WYall					// Array to construct the average
		Setscale /P y, 1, 1, WYall
		WYall = NaN 
		
		// The Water Year Average waves is needed
		if (cmpstr(WYAvgCalc,"WY average")!=0)
			Make /O/D/N=(NYears) $(CCParam + "_" + CCUnit) /WAVE=WYav					// The average
			Make /O/D/N=(NYears) $(CCParam + "tot" + "_" + CCUnit) /WAVE=WYt		// The total 
			Make /O/D/N=(NYears) $(CCParam + "yr" + "_yr") /WAVE=WYy					// The water year e.g. 2023
			Make /O/D/N=(NYears) $(CCParam + "yr2" + "_yr") /WAVE=WYy2				// The water year e.g. 23
			Make /O/D/N=(NYears) $(CCParam + "nbr" + "_n") /WAVE=WYn					// The number of days in the water year with data
			Make /O/D/N=(NYears) $(CCParam + "nbr" + "_m") /WAVE=WYm					// The number of days in the water year MISSING data
			
			Make /O/D/N=(NYears) $(CCParam + "min" + "_" + CCUnit) /WAVE=WYmin		// The minimum data value
			Make /O/D/N=(NYears) $(CCParam + "max" + "_" + CCUnit) /WAVE=WYmax		// The maximum data value
			Make /O/D/N=(NYears) $(CCParam + "diff" + "_" + CCUnit) /WAVE=WYdiff	// The maximum data value
			Make /O/D/N=(NYears) $(CCParam + "mins" + "_date") /WAVE=WYmins			// The location of the minimum data point as DateInSecs
			Make /O/D/N=(NYears) $(CCParam + "maxs" + "_date") /WAVE=WYmaxs			// The location of the maximum data point as DateInSecs
		endif
		WYDays = 0
		
		// The average for the parameter over each day of a water year 
		Make /O/D/N=(366) $(CCParam+"_WYAV" + "_"+CCUnit) /WAVE=DataWYAvg		// average for each day over the water year 
		Make /O/D/N=(366) $(CCParam+"_WYAV_sm" + "_"+CCUnit) /WAVE=DataWYAvgSM	// Box-car smoothed average
		Make /O/D/N=(366) $(CCParam+"_WYAV" + "_d") /WAVE=DaysWYAvg				// the day over the water year 
		MakeWaterYear(2020,DaysWYAvg)														// put the dates into DaysWYAvg
		SetScale d, DaysWYAvg[0], DaysWYAvg[Inf], "dat", DaysWYAvg				// set scale 
		
		// The data for every day in a single water year (where available). 
		Make /FREE/D/N=366 SingleYearData, SingleYearDays
		MakeWaterYear(2000,SingleYearDays)
		
		// Alternative waves for integrating to get water-year totals
		Make /FREE/D/N=0 SY_data, SY_day, SY_NoGap_data, SY_NoGap_day
		
		// LOOP OVER DAYS IN THE WATER YEAR using INDEX m
		for (m=0;m<366;m+=1)
			Variable DataSecs 		= SingleYearDays[m]		// The date, in seconds, for the n'th day of Water Year 2000
			Variable DataDay		= str2num(StringFromList(2,Secs2Date(DataSecs,-2,";")))		// The day of the month of the m'th day in year 2000 ... should be equal to m of course
			Variable DataMonth		= str2num(StringFromList(1,Secs2Date(DataSecs,-2,";")))		// The month
			Variable DataYear		= str2num(StringFromList(0,Secs2Date(DataSecs,-2,";")))		// The year itself ... should be equal to 2000 of course. 
			
			Variable DataSum 	= 0 
			nData 	= 0
			
			// Create a single AVERAGE over all Water Years
			// LOOP OVER WATER YEARS using INDEX WY
			// Add data from the same day for each year where available. 
			for (WY=WaterYear1;WY<=WaterYear2;WY+=1)
				DataSecs 	= Date2Secs(WY,DataMonth,DataDay)
				FindValue /Z/V=(DataSecs) CCd
				
				if (V_value > -1)
					DataVal 	= CC[V_value]
					if (numtype(DataVal)==0)
						DataSum += DataVal
						nData += 1
					endif 
				endif 
			endfor
			
			if (nData > 0)
				DataWYAvg[m] 	= DataSum/nData // Might be worth calculating some other statistics here
			else
				DataWYAvg[m] 	= NaN
			endif
		endfor 
			
		
		if (cmpstr(WYAvgCalc,"WY average")==0)
			// Do nothing else 
			
		else
			// Second, calculate the full-water-year averages, using the above if there are gaps in any given year. 
	
				
			// LOOP OVER WATER YEARS using INDEX WY
			for (WY=WaterYear1;WY<=WaterYear2;WY+=1)
				Variable nWYData = 0, nWYMissing = 0
				Variable SY_idx1 = 0
				Variable SY_idx2 = 0
				
				// Calculate the dates for the n'th water year
				WYDays 	= MakeWaterYear(WY,SingleYearDays)		// Returns the number of days in the water year. 
				Redimension /N=(WYDays) SingleYearData
				
				// Try integrating data - day with and without filling the gaps by Average
				Redimension /N=0 SY_data, SY_day
				Redimension /N=0 SY_NoGap_data, SY_NoGap_day
				
				for (m=0;m<WYDays;m+=1)
					DataSecs 	= SingleYearDays[m]		// The date, in seconds, for the m'th day of the n'th Water Year
					FindValue /Z/V=(DataSecs) CCd
					if (V_value > -1)
						// There is data for this day and water year ... 
						SingleYearData[m] = CC[V_value]
						nWYData += 1
						
						WYall[WY-WaterYear1][m] 	= SingleYearData[m]
						
						SY_idx1 += 1
						Redimension /N=(SY_idx1) SY_data, SY_day
						SY_data[SY_idx1-1] 	= SingleYearData[m]
						SY_day[SY_idx1-1] 		= m
						
						SY_idx2 += 1
						Redimension /N=(SY_idx2) SY_NoGap_data, SY_NoGap_day
						SY_NoGap_data[SY_idx2-1] 	= SingleYearData[m]
						SY_NoGap_day[SY_idx2-1] 		= m
					else
						// No data for this day and water year ... use the average over all other water years
						DataMonth		= str2num(StringFromList(1,Secs2Date(DataSecs,-2,";")))		// The month
						DataSecs 		= Date2Secs(2000,DataMonth,m)											// The date, in seconds, for the same day of the 2000 Water Year Average
						FindValue /Z/V=(DataSecs) DaysWYAvg
						if (V_value > -1)
							SingleYearData[m] = DataWYAvg[V_value]

							SY_idx2 += 1
							Redimension /N=(SY_idx2) SY_NoGap_data, SY_NoGap_day
							SY_NoGap_data[SY_idx2-1] 	= SingleYearData[m]
							SY_NoGap_day[SY_idx2-1] 		= m
					
						else
							SingleYearData[m] = NaN
							nWYMissing += 1
						endif
					endif
				endfor
				
					
				// Update the water year statistics 
				Variable point 		= WY-WaterYear1
				VAriable CCsum 		= NaN 
				if (nWYMissing > 360)
					// Not enough data at all so skip
					WYav[point] 		= NaN
					WYav[point] 		= NaN
					WYt[point] 		= NaN
					WYy[point] 		= WY
					WYy2[point] 		= WY - 2000
					WYn[point] 		= nWYData
					WYm[point] 		= nWYMissing
					
					WYmin[point] 	= NaN
					WYmins[point] 	= NaN
					WYmax[point] 	= NaN
					WYmaxs[point] 	= NaN
					WYdiff[point] 	= NaN
				else
					// Now analyze this water year data
					WaveStats /Q/M=1 SingleYearData
					CCsum 			= V_sum
					
					WYav[point] 		= V_avg
					// *!*!* 		2025-01 Integrate the Data - Day series to calculate the total export
					WYt[point] 		= areaXY(SY_NoGap_day,SY_NoGap_data)
					WYy[point] 		= WY
					WYy2[point] 		= WY - 2000
					WYn[point] 		= nWYData
					WYm[point] 		= nWYMissing
					
					WYmin[point] 	= V_min
					WYmins[point] 	= SingleYearDays[V_minLoc]
					WYmax[point] 	= V_max
					WYmaxs[point] 	= SingleYearDays[V_maxLoc]
					WYdiff[point] 	= V_max - V_min
				endif
				
				// Look at the different ways of creating the total export data
				WYtotals[point][0] 		= WY - 2000
				WYtotals[point][1] 		= CCsum
				WYtotals[point][2] 		= areaXY(SY_day,SY_data)
				WYtotals[point][3] 		= areaXY(SY_NoGap_day,SY_NoGap_data)
				
			endfor 
		
			SetScale d, WYmins[0], WYmins[Inf],"dat", WYmins
			SetScale d, WYmaxs[0], WYmaxs[Inf],"dat", WYmaxs
			WYAvgTable(WYAvgFolder, CCParam, CCUnit)
			
			// Smooth the water-year average
			DataWYAvgSM = DataWYAvg
			Smooth /B 5, DataWYAvgSM
			
			WYStack(WYAll,DataWYAvg,WaterYear1,CCParam)
		endif
End

Function WYStack(WYAll,WYAV,WaterYear1,CCParam)
	Wave WYAll, WYAV 
	Variable WaterYear1
	String CCParam
	
	WaveStats /Q/M=1 WYAll
	Variable Voffset = 0.5 * V_max
	
	Variable i, NYrs = DimSize(WYAll,0)
	Variable WY, rr,gg,bb,aa
	String WYName, LegendText="\\Z16"

	Display /K=1/W=(154,186,625,666) as CCParam + " Water Years"
	
	AppendToGraph/R WYAV /TN=average
	
	for (i=0;i<NYrs;i+=1)
		WY 		= WaterYear1 + i
		WYName 	= CCParam + "_" + num2str(WY)
		
		LegendText = "\\s("+WYName+")"+WYName+"\r" + LegendText
		
		AppendToGraph WYAll[i][*] /TN=$WYName
		
		WaterYearColor(WY,rr,gg,bb,aa)
		
		ModifyGraph rgb($WYName)=(rr,gg,bb,aa), offset($WYName)={0,i*Voffset}
	endfor
	
	LegendText = "\\Z16" + LegendText
	
	Legend/C/N=text0/J/F=0/B=1/A=MC/X=-34.25/Y=30.53 LegendText
		
	ModifyGraph gFont="Helvetica"
	ModifyGraph mode=4
	ModifyGraph marker=8
	ModifyGraph msize=2
	ModifyGraph mirror(bottom)=2
	ModifyGraph font="Helvetica"
	ModifyGraph fSize=14
	ModifyGraph axThick=2
	ModifyGraph gaps=0
	Label bottom "Day of Year"
	
	ModifyGraph mode(average)=7,rgb(average)=(56797,56797,56797),hbFill(average)=2
End

Function WYAvgTable(WYFolder, CCParam, CCUnit)
	String WYFolder, CCParam, CCUnit 

	String PName = CCParam
	
	WYFolder 		= "root:"+WYFolder
//	WAVE WYav 	= $(WYFolder+":" + CCParam + "av" + "_" + CCUnit)
	WAVE WYav 	= $(WYFolder+":" + CCParam + "_" + CCUnit)					// The average
	WAVE WyY 		= $(WYFolder+":" + CCParam + "yr" + "_yr")					// The water year e.g. 2023
	WAVE WyY2 	= $(WYFolder+":" + CCParam + "yr2" + "_yr")				// The water year e.g. 23
	WAVE WyT 		= $(WYFolder+":" + CCParam + "tot" + "_" + CCUnit)
	WAVE WyMax 	= $(WYFolder+":" + CCParam + "max" + "_" + CCUnit)		// The minimum data value
	WAVE WyMaxS 	= $(WYFolder+":" + CCParam + "maxs" + "_date")
	WAVE WyMin 	= $(WYFolder+":" + CCParam + "min" + "_" + CCUnit)		// The minimum data value
	WAVE WyMinS 	= $(WYFolder+":" + CCParam + "mins" + "_date")
	WAVE WyDiff 	= $(WYFolder+":" + CCParam + "diff" + "_" + CCUnit)
	WAVE WyN 		= $(WYFolder+":" + CCParam + "nbr" + "_n")					// The number of days in the water year WITH data
	WAVE WyM 		= $(WYFolder+":" + CCParam + "nbr" + "_m")					// The number of days in the water year MISSING data
	
	Edit /K=1/W=(334,188,1147,433) WyY,WyY2,WYav,WyT,WyMax,WyMaxS as PName+"("+CCUnit+") Water Year Exports"
	AppendToTable WyMin,WyMinS,WyDiff,WyN,WyM
	ModifyTable format(Point)=1,title(WyY)="Year",title(WyY2)="Year",title(WYav)="Average"
	ModifyTable title(WyT)="Total",title(WyMax)="Max",format(WyMaxS)=6
	ModifyTable title(WyMaxS)="Day of max",title(WyMin)="Min",format(WyMinS)=6
	ModifyTable title(WyMinS)="Day of Min",title(WyDiff)="Max - Min",title(WyN)="Days with data",title(WyM)="Days missing"
EndMacro
			
			
			
//						// Second, calculate the full-water-year averages, using the above if there are gaps in any given year. 
//			for (n=WaterYear1;n<=WaterYear2;n+=1)
//				Variable nMissing = 0
//				
//				// Calculate the dates for the n'th water year
//				nDays 	= MakeWaterYear(n,SingleYearDays)
//				Redimension /N=(nDays) SingleYearData
//				
//				for (m=0;m<nDays;m+=1)
//					DataSecs 	= SingleYearDays[m]		// The date, in seconds, for the m'th day of the n'th Water Year
//					FindValue /Z/V=(DataSecs) CCd
//					if (V_value > -1)
//						// There is data for this day and water year
//						SingleYearData[m] = CC[V_value]
//					else
//						// No data for this day and water year ... use the average over all other water years
//						DataMonth		= str2num(StringFromList(1,Secs2Date(DataSecs,-2,";")))		// The month
//						DataSecs 		= Date2Secs(2000,DataMonth,m)											// The date, in seconds, for the same day of the 2000 Water Year Average
//						FindValue /Z/V=(DataSecs) DaysWYAvg
//						if (V_value > -1)
//							SingleYearData[m] = DataWYAvg[V_value]
//						else
//							SingleYearData[m] = NaN
//							nMissing += 1
//						endif
//					endif
//				endfor
//				
//				Variable point = n-WaterYear1
//				if (nMissing > 360)
//					WYav[point] 		= NaN
//					WYav[point] 		= NaN
//					WYt[point] 		= NaN
//					WYy[point] 		= n
//					WYy2[point] 		= n - 2000
//					WYn[point] 		= nMissing
//					
//					WYmin[point] 	= NaN
//					WYmins[point] 	= NaN
//					WYmax[point] 	= NaN
//					WYmaxs[point] 	= NaN
//					WYdiff[point] 	= NaN
//				else
//					// Now analyze this water year data
//					WaveStats /Q/M=1 SingleYearData
//					
//					WYav[point] 		= V_avg
//					WYt[point] 		= V_sum
//					WYy[point] 		= n
//					WYy2[point] 		= n - 2000
//					WYn[point] 		= nMissing
//					
//					WYmin[point] 	= V_min
//					WYmins[point] 	= SingleYearDays[V_minLoc]
//					WYmax[point] 	= V_max
//					WYmaxs[point] 	= SingleYearDays[V_maxLoc]
//					WYdiff[point] 	= V_max - V_min
//				endif
//			endfor 

	
// Calculate the average of any time series data for each water year.  
// IMPORTANT: If data are missing, take the average for all other water years. 
Function WaterYearAverages()

	SetDataFolder root:
	
	// First User Prompt
	String DataFolder 			= StrVAROrDefault("root:Geochem:gDataFolder","PH_Isco")
	String WYAvgData 			= StrVAROrDefault("root:Geochem:gWYAvgData","")
	String WYAvgFolder 		= StrVAROrDefault("root:Geochem:gWYAvgFolder","PH_ISCO_WYAvg")
	String WYAvgType 			= StrVAROrDefault("root:Geochem:gWYAvgType","all")
	String FolderList1 		= ListOfObjectsInFolder(4,"root:")
	String FolderList2 		= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName 		= ""
	
	Prompt DataFolder, "Data Source", popup, FolderList1
	Prompt WYAvgType, "Data for water year average(s)", popup, "all;single;"
	Prompt WYAvgFolder, "Destination", popup, FolderList2
	Prompt NewFolderName, "Destination"
	DoPrompt "Choose data for Water Year Averages", DataFolder, WYAvgType, WYAvgFolder, NewFolderName
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gDataFolder = DataFolder
	String /G root:Geochem:gWYAvgType = WYAvgType
	
	if (cmpstr(WYAvgFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		WYAvgFolder 	= NewFolderName
	endif
	String /G root:Geochem:gWYAvgFolder = WYAvgFolder
	
	
	// Make a list of all the data in the Source folder. 
	String ConcList 	= ListOfObjectsInFolder(1,"root:"+DataFolder)
	ConcList 	= ExclusiveWaveList( ConcList, "_d", ";")
	Variable NSpecies = ItemsInList(ConcList)
	
	
	// (Optional) Second User Prompt for a Single Dataset 
	Variable WYDataNum 	= WhichListItem(WYAvgData,ConcList)
	if (WYDataNum < 0)
		WYAvgData 	= StringFromList(0,ConcList)
	endif
	Prompt WYAvgData, "Concentration data", popup, ConcList
	if (cmpstr(WYAvgType,"single") == 0)
		DoPrompt "Choose data", WYAvgData
	endif
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gWYAvgData = WYAvgData
	
	
	SetDataFolder $WYAvgFolder
		// KillWaves /A/Z

		Variable i, n, nData, nMin, nMax, DataDay, WYDay=1, WYNum=0, NDays, WYCurrent, WYNew
		Variable DataVal, DataMin=1e99, DataMinLoc, DataMax=0, DataMaxLoc
		
		if (cmpstr(WYAvgType,"single")==0)
			nMin 	= WhichListItem(WYAvgData,ConcList)
			nMax 	= nMin+1
			print "Calculating Water-Year Averages for",WYAvgData,"in",DataFolder,"and saving in",WYAvgFolder
		else
			nMin 	= 0
			nMax 	= NSpecies
			print "Calculating Water-Year Averages for the data in",DataFolder,"and saving in",WYAvgFolder
		endif
		
		for (n=nMin;n<nMax;n+=1)
			String CCName 		= StringFromList(n,ConcList)
			String CCUnit 		= GeochemUnitFromName(CCName)
			String CCParam 		= GeochemParameterFromName(CCName)
			String CCdName 		= CCParam + "_d"
			
			WAVE CC 	= $("root:"+DataFolder+":"+CCName)
			WAVE CCd 	= $("root:"+DataFolder+":"+CCdName)
			if (!WaveExists(CCd))
				CCdName 		= CCName + "_d"
				WAVE CCd 	= $("root:"+DataFolder+":"+CCdName)
			endif
			nData 	= DimSize(CC,0)
			
//			String WYName		= CCParam + "_" + CCUnit + "_" + DischUnit
			String WYName		= CCParam + "_" + CCUnit
			String WYavName 	= CCParam + "av" + "_" + CCUnit
			String WYtName 		= CCParam + "tot" + "_" + CCUnit
			String WYyName 		= CCParam + "yr" + "_yr"
			String WYy2Name 	= CCParam + "yr2" + "_yr"
			String WYnName 		= CCParam + "nbr" + "_n"
			
			String WYminName 		= CCParam + "min" + "_" + CCUnit
			String WYmaxName 		= CCParam + "max" + "_" + CCUnit
			String WYminsName 		= CCParam + "mins" + "_date"
			String WYmaxsName 		= CCParam + "maxs" + "_date"
			String WYdiffName 		= CCParam + "diff" + "_" + CCUnit
			
			Make /O/D/N=0 $WYavName /WAVE=WYav	// The average
			Make /O/D/N=0 $WYtName /WAVE=WYt		// The total 
			Make /O/D/N=0 $WYyName /WAVE=WYy		// The water year, e.g. 2023
			Make /O/D/N=0 $WYy2Name /WAVE=WYy2		// The water year, e.g. 23
			Make /O/D/N=0 $WYnName /WAVE=WYn		// The number of days in the water year with data
			
			Make /O/D/N=0 $WYminName /WAVE=WYmin		// The minimum data value
			Make /O/D/N=0 $WYmaxName /WAVE=WYmax		// The maximum data value
			Make /O/D/N=0 $WYdiffName /WAVE=WYdiff	// The maximum data value
			Make /O/D/N=0 $WYminsName /WAVE=WYmins	// The location of the minimum data point as DateInSecs
			Make /O/D/N=0 $WYmaxsName /WAVE=WYmaxs	// The location of the maximum data point as DateInSecs
			nDays = 0
			
//			Make /FREE/D/N=(366) WYData
			Make /FREE/D/N=(nData) WYData
			WYData = NaN
			
			WYCurrent 	= GetWaterYear(CCd[0])
	
			for(i=0;i<nData;i+=1)
				DataDay 	= CCd[i]
				DataVal 	= CC[i]
				
				if (numtype(DataVal) == 0)		// Skip NaNs inserted for plotting 
				
					if (DataVal < DataMin)
						DataMin 		= DataVal
						DataMinLoc 	= DataDay
					endif 
					if (DataVal > DataMax)
						DataMax 		= DataVal
						DataMaxLoc 	= DataDay
					endif 
	
					WYNew 	= GetWaterYear(DataDay)
					
					if ((WYNew > WYCurrent) || (i == (nData-2)) )
						WYNum += 1
						Redimension /N=(WYNum) WYav, WYt, WYy, WYn, WYmin, WYmins, WYmax, WYmaxs, WYdiff
						
						WaveStats /Q/M=1 WYData
						WYav[WYNum-1] 	= V_avg
						WYt[WYNum-1] 	= V_sum
						WYy[WYNum-1] 	= WYCurrent
						WYy2[WYNum-1] 	= WYCurrent-2000
						WYn[WYNum-1] 	= V_npnts
						
						WYmin[WYNum-1] 		= DataMin
						WYmins[WYNum-1] 	= DataMinLoc
						WYmax[WYNum-1] 		= DataMax
						WYmaxs[WYNum-1] 	= DataMaxLoc
						WYdiff[WYNum-1] 	= DataMax - DataMin
						
						WYCurrent 	= WYNew
						WYData 		= NaN
						WYDay 		= 1	
						DataMin 		= 1e99		
						DataMax 		= 0
					endif
					
					WYData[WYDay-1] 	= DataVal
					WYDay += 1
					
				endif 
			
			endfor
			
			SetScale d, WYmins[0], WYmins[WYDay-2],"dat", WYmins
			SetScale d, WYmaxs[0], WYmaxs[WYDay-2],"dat", WYmaxs
			WYAvgTable(WYAvgFolder, CCParam, CCUnit)
			
		endfor
		
	SetDataFolder root:
End


// Convert Concentration and Discharge time-series values to Fluxes. 
// 	Discharge: Each day has an average discharge in m3/s
// 	Concentration: Each day has an average (or representative) concentration value in (e.g.) µmol/L
// CONVERSION: 
// 	Convert to the average (or representative) flux during each day. 
// 	Multiply values in µM by 1e-6 to convert to moles/L
// 	Multiply values in moles/L by 1000 to convert to moles/m3
// 	Multiply discharge (m3/s) by concentration (moles/m3) to get flux (moles/s)
// 	{ no no no not yet Multiply by 86400 s/day to get flux in moles/day
// Also calculate total average Exports 
Function AllSpeciesFluxes()

	SetDataFolder root:
	
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	String DischargeFolder 	= StrVAROrDefault("root:Geochem:gDischargeFolder","PH_Isco")
	String FluxFolder 	= StrVAROrDefault("root:Geochem:gFluxFolder","Fluxes")
	String FolderList1 	= ListOfObjectsInFolder(4,"root:")
	String FolderList2 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName = ""
	Prompt DischargeFolder, "Discharge Source", popup, FolderList1
	Prompt ConcFolder, "Data Source", popup, FolderList1
	Prompt FluxFolder, "Destination", popup, FolderList2
	Prompt NewFolderName, "Destination"
	DoPrompt "Choose data to normalize", DischargeFolder, ConcFolder, FluxFolder, NewFolderName
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gConcFolder = ConcFolder
	String /G root:Geochem:gDischargeFolder = DischargeFolder
	
	if (cmpstr(FluxFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		FluxFolder 	= NewFolderName
	endif
	String /G root:Geochem:gFluxFolder = FluxFolder
	
	SetDataFolder $FluxFolder
		KillWaves /A/Z
	
		print "Converting Concentration data in",ConcFolder,"to Fluxes in",FluxFolder
		
		// First, look up the position of cursors on the top plot. 
		WAVE AWave = CsrWaveRef(A)
		WAVE AXWave = CsrXWaveRef(A)
		WAVE BWave = CsrWaveRef(B)
		WAVE BXWave = CsrXWaveRef(B)
		Variable AXVal=-1, BXVal=-1, GoodDUnit=1, GoodCUnit=1, MsgFlag=1
		
		if (WaveExists(AWave) && WaveExists(BWave))
			String ExpStr =  "Calculating the average exports between "+secs2Date(AXWave[pcsr(A)],0) + " and " + secs2Date(BXWave[pcsr(B)],0)
			AXVal = min(AXWave[pcsr(A)],BXWave[pcsr(B)])
			BXVal = max(AXWave[pcsr(A)],BXWave[pcsr(B)])
		else 
			ExpStr = "Calculating the average exports for the full range"
		endif
		print ExpStr
		
		// Make a list of all the data in the Source folder. 
		String Ele, ConcList = ListOfObjectsInFolder(1,"root:"+ConcFolder)
//		String DischList 	= InclusiveWaveList(ListOfObjectsInFolder(1,"root:"+DischargeFolder),"discharge",";")
		String DischList 	= ExclusiveWaveList( ListOfObjectsInFolder(1,"root:"+DischargeFolder) ,"_d", ";")
		String DischName 	= StringFromList(0,DischList)
		Prompt DischName, "Discharge Data", popup, DischList
		DoPrompt "Choose discharge data", DischName
		if (V_flag)
			return 0
		endif
		String DischUnit 		= GeochemUnitFromName(DischName)
		if (cmpstr(DischUnit,"m3ps")!=0)
			Print 	" 		Currently preferable to use discharge in m3 per second"
			GoodDUnit = 0
		endif 
		
		WAVE QQ 	= $("root:"+DischargeFolder+":"+DischName)
		WAVE QQd 	= $("root:"+DischargeFolder+":"+GeochemDateFromName(DischName))

		Duplicate /O QQ, $("root:"+FluxFolder+":"+NameOfWave(QQ))
		Duplicate /O QQd, $("root:"+FluxFolder+":"+NameOfWave(QQd))
		
		ConcList 	= ExclusiveWaveList(ExclusiveWaveList(ExclusiveWaveList(ConcList,"_d",";"),DischName,";"),"Species",";")
		
		Variable NSpecies = ItemsInList(ConcList)
		Make /O/T/N=(NSpecies) $("root:"+FluxFolder+":SpeciesNames")
		Make /O/D/N=(NSpecies) $("root:"+FluxFolder+":SpeciesExports"), $("root:"+ConcFolder+":SpeciesSource")
		WAVE /T Names 	= $("root:"+FluxFolder+":SpeciesNames")
		WAVE Exports 	= $("root:"+FluxFolder+":SpeciesExports")
		WAVE Sources 	= $("root:"+FluxFolder+":SpeciesSource")
		
		Variable i, n, nCC, pStart, pStop, Day1, Val1, Val2, NDays=0

		for (n=0;n<NSpecies;n+=1)
			GoodCUnit 	= 1
			
			String CCName 		= StringFromList(n,ConcList)
			String CCUnit 		= GeochemUnitFromName(CCName)
			String CCParam 		= GeochemParameterFromName(CCName)
			String CCdName 		= CCParam + "_d"
		
			if (cmpstr(CCUnit,"uM")!=0)
				GoodCUnit 	= 0
				if (MsgFlag)
					Print 	" 		Calculation is only accurate for concentrations in micromoles/liter"
					MsgFlag 		= 0
				endif
			endif 
			
			String FFName, ExportName, FFdName
			if (GoodDUnit && GoodCUnit)
				FFName 		= CCParam + "_molps"
				Make /O/D/N=0 $(CCParam + "_molpd") /WAVE=Export
				Make /O/D/N=0 $(CCParam + "_molpd_d") /WAVE=Exportd
			else
				FFName 	= CCParam + "_" + CCUnit + "x" + DischUnit
			endif
			FFdName 		= FFName + "_d"	
		
			WAVE CC 	= $("root:"+ConcFolder+":"+CCName)
			WAVE CCd 	= $("root:"+ConcFolder+":"+CCdName)
			
			Make /O/D/N=0 $FFName /WAVE=FF
			Make /O/D/N=0 $FFdName /WAVE=FFd
				
			nDays = 0
			nCC = DimSize(CC,0)
			for(i=0;i<nCC;i+=1)
				Day1 	= CCd[i]
				if (numtype(Day1) == 0)
					Val1 	= CC[i]
					if (numtype(Val1) == 0)
						FindValue /V=(Day1) QQd
						if (V_value != -1)
							Val2 	= QQ[V_value]
							if (numtype(Val2) == 0)
								nDays += 1
								Redimension /N=(nDays) FF, FFd
								if (GoodDUnit && GoodCUnit)
									// Calculate flux in moles per second 
									FF[nDays-1] 			= 1e-3 * Val1 * Val2		// converts from µM to M and L to m3
									
									Redimension /N=(nDays) Export,Exportd
									Export[nDays-1] 	= 86400 * FF[nDays-1]		// multiply by the number of seconds in a day
									Exportd[nDays-1] 	= Day1
								else
									FF[nDays-1] 		= Val1 * Val2
								endif
								FFd[nDays-1] 	= Day1
							endif
						endif
					endif
				endif
			endfor
			
			Names[n] = CCParam + " (" + CCUnit + " x " + DischUnit+")"
			
			if (DimSize(FF,0) == 0)
				KillWaves /Z FF, FFd
			else
				SetScale d, FFd[0], FFd[nDays-2],"dat", FFd
				
				pStart = -1
				if (AXVal > -1)
					FindValue /V=(AXVal) FFd
					pStart 	= V_value
				endif
				if (pStart == -1)
					pStart 	= 0
				endif
				pStop = -1
				if (BXVal > -1)
					FindValue /V=(BXVal) FFd
					pStop 		= V_value
				endif
				if (pStop == -1)
					pStop = DimSize(FFd,0)-1
				endif
				
				WaveStats /Q/R=[pStart,pStop] /M=1 FF
				Variable ExportValue = V_avg
				
				Exports[n] = ExportValue
				Note /K Exports, ExpStr
			endif
			
		endfor
	
	SetDataFolder root:
End

















//// Calculate the Average Export of a Species
//Function SpeciesExport()
//	
//	SetDataFolder root:
//	
//	// Select the Concentration and Discharge folder
//	String ConcFolder 	= StrVAROrDefault("root:gConcFolder","PH_Isco")
//	String FluxFolder 	= StrVAROrDefault("root:gFluxFolder","Flux")
//	ConcFolder 	= ChooseAFolder("",ConcFolder,"Data Source","Choose data folder",0)
//	if (strlen(ConcFolder) == 0)
//		return 0
//	endif
//	String /G gConcFolder = ConcFolder
//	
//	// List all the data in the folder. 
//	String ConcList 	= ListOfObjectsInFolder(1,ConcFolder)
//	ConcList 			= ExclusiveWaveList(ConcList,"_d",";")
//	
//	// Select the Element and Discharge data and Choose a Destination
//	String Species1 	= StrVAROrDefault("root:gSpecies1","")
//	String Species2 	= StrVAROrDefault("root:gSpecies2","")
//	String SaveFolder = StrVAROrDefault("root:gSaveFolder","Correlations")
//	String FolderList 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
//	String NewFolderName = ""
//	
//	
//	Prompt Species1, "Species 1", popup, ConcList
//	Prompt Species2, "Discharge", popup, ConcList
//	Prompt FluxFolder, "Destination", popup, FolderList
//	Prompt NewFolderName, "Destination"
//	DoPrompt "Choose correlation pair", Species1, Species2, FluxFolder, NewFolderName
//	if (V_flag)
//		return 0
//	endif
//	String /G gSpecies1 = Species1
//	String /G gSpecies2 = Species2
//	
//	// Create or Open the Destination
//	if (cmpstr(FluxFolder,"new - enter below")==0)
//		NewDataFolder/O $("root:"+NewFolderName)
//		FluxFolder 	= NewFolderName
//	endif
//	String /G gFluxFolder = FluxFolder
//		
//	SetDataFolder gFluxFolder
//	
//	
//	String Ele 	= StripSuffixBySeparator(Species1,"_")
//	String Unit1 	= ReturnLastSuffix(Species1,"_")
//	String Discharge 	= StripSuffixBySeparator(Species2,"_")
//	String Unit2 	= ReturnLastSuffix(Species2,"_")
//	
//	WAVE CC 	= $("root:"+ConcFolder+":"+Species1)
//	WAVE CCd 	= $("root:"+ConcFolder+":"+Ele+"_d")
//	WAVE QQ 	= $("root:"+ConcFolder+":"+Species2)
//	WAVE QQd 	= $("root:"+ConcFolder+":"+Discharge+"_d")
//	SpeciesFlux(Ele,CC,CCd,Discharge,QQ,QQd)
//	
//	SetDataFolder root:
//End

//Function SpeciesFlux(Ele,CC,CCd,Discharge,QQ,QQd)
//	String Ele, Discharge
//	Wave CC,CCd,QQ,QQd
//	
//	Variable i, Day1, Val1, Day2, Val2, nDays=0
//	
//	Variable Nqq=DimSize(CCd,0), Ncc=DimSize(QQd,0)
//	
//	Make /D/O/N=0 $(Ele+"_Flux") /WAVE=FluxWave
//	Make /D/O/N=0 $(Ele+"_d") /WAVE=DateWave
//	
//	// Loop through all valid Element1 dates
//	for(i=0;i<Ncc;i+=1)
//		Day1 	= CCd[i]
//		if (numtype(Day1) == 0)
//			Val1 	= CC[i]
//			if (numtype(Val1) == 0)
//				FindValue /V=(Day1) QQd
//				if (V_value != -1)
//					Val2 	= QQ[V_value]
//					if (numtype(Val2) == 0)
//						nDays += 1
//						Redimension /N=(nDays) FluxWave, DateWave
//						FluxWave[nDays-1] 	= Val1 * Val2
//						DateWave[nDays-1] 	= Day1
//					endif
//				endif
//			endif
//		endif
//	endfor
//	
//	SetScale d, DateWave[0], DateWave[nDays-1],"dat", DateWave
//End







// Normalize to unity at a selected date range and then shifted to zero
Function ScaleAllConcentrations()

	SetDataFolder root:
	SetDataFolder root:Geochem
	
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	String NormFolder 	= StrVAROrDefault("root:Geochem:gNormFolder","Scaled")
	String FolderList1 	= ListOfObjectsInFolder(4,"root:")
	String FolderList2 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName = ""
	Prompt ConcFolder, "Data Source", popup, FolderList1
	Prompt NormFolder, "Destination", popup, FolderList2
	Prompt NewFolderName, "Destination"
	DoPrompt "Choose data to normalize", ConcFolder, NormFolder, NewFolderName
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gConcFolder = ConcFolder
	
	WAVE AWave = CsrWaveRef(A)
	WAVE AXWave = CsrXWaveRef(A)
	WAVE BWave = CsrWaveRef(B)
	WAVE BXWave = CsrXWaveRef(B)
	
	if (WaveExists(AWave) && WaveExists(BWave))
		String Msg = "Scaling concentrations to the average values between  "+secs2Date(AXWave[pcsr(A)],0)+"  and  "+secs2Date(BXWave[pcsr(B)],0) + "  and saving in "+NormFolder 
	else 
		return 0
	endif
			print Msg
			
	Variable AXVal = min(AXWave[pcsr(A)],BXWave[pcsr(B)])
	Variable BXVal = max(AXWave[pcsr(A)],BXWave[pcsr(B)])
	
	if (cmpstr(NormFolder,"new - enter below")==0)
		NewDataFolder/O/S $("root:"+NewFolderName)
		NormFolder 	= NewFolderName
	endif
	String /G root:Geochem:gNormFolder = NormFolder
	
	String Ele, ConcList = ListOfObjectsInFolder(1,"root:"+ConcFolder)
	ConcList 			= ExclusiveWaveList(ConcList,"_d",";")
	Variable i, j, k=0, NConcs = ItemsInList(ConcList), pStart, pStop
	
	for (i=0;i<NConcs;i+=1)
		String CCName 	= StringFromList(i,ConcList)
		String EleName 	= StripSuffixBySeparator(CCName,"_")
		String NmName	= EleName + "_Nm"
		String DDName 	= EleName + "_d"
		
		WAVE CC 	= $("root:"+ConcFolder+":"+CCName)
		WAVE DD 	= $("root:"+ConcFolder+":"+DDName)
		
		// FindValue looks for a specific day value
		FindValue /V=(AXVal) DD
		pStart 	= V_value
		FindValue /V=(BXVal) DD
		pStop 	= V_value
		
		if (pStart == -1)
			FindLevel /Q/P/EDGE=1 DD, AXVal
			pStart = (V_flag == 0) ? floor(V_LevelX) : pStart
		endif
		
		if  (pStop == -1)
			FindLevel /Q/P/EDGE=1 DD, BXVal
			pStop = (V_flag==0) ? floor(V_LevelX) : pStop
		endif
		
		if ((pStart == -1) || (pStop == -1))
			Print " 	- no overlap so quit"
//		elseif (cmpstr(CCName,"DOC_ppm") != 0)	// CRUDE to do a single trace. 
//		elseif (cmpstr(CCName,"SO4_uM") != 0)	// CRUDE to do a single trace. 
		
		else
			
			Duplicate /O/D CC, $("root:"+NormFolder+":"+NmName)
			Duplicate /O/D DD, $("root:"+NormFolder+":"+DDName)
			WAVE NN 	= $("root:"+NormFolder+":"+NmName)
			WAVE ND 	= $("root:"+NormFolder+":"+DDName)
			WaveStats /Q/R=[pStart,pStop] /M=1 CC
			NN /= V_avg
			
			k = 0 	// Is this ever necessary??
			Variable NVals = DimSize(NN,0)
			for (j=0;j<NVals;j+=1)
				if ((numtype(NN[k]) != 0) || (numtype(ND[k]) != 0))
					DeletePoints k,1, NN, ND
				else
					k+=1
				endif
			endfor
			
		endif
	endfor
	
	SetDataFolder root:
End

// DateStart and DateStop are strings containing year-month-day, same as Secs2Date(DateTime,-2)	// 1993-03-14
Function PromptForDateSubrange(DateStart,DateStop)
	String &DateStart, &DateStop
	
	Variable Year1 		= str2num(ParseFilePath(0,DateStart,"-",0,0))
	Variable Year2 		= str2num(ParseFilePath(0,DateStop,"-",0,0))
	Variable Month1 	= str2num(ParseFilePath(0,DateStart,"-",0,1))
	Variable Month2 	= str2num(ParseFilePath(0,DateStop,"-",0,1))
	Variable Day1 		= str2num(ParseFilePath(0,DateStart,"-",0,2))
	Variable Day2 		= str2num(ParseFilePath(0,DateStop,"-",0,2))
	
	Prompt Year1, "Start year"
	Prompt Month1, "month"
	Prompt Day1, "day"
	Prompt Year2, "End year"
	Prompt Month2, "month"
	Prompt Day2, "day"
	
	DoPrompt "Date subrange", Year1, Year2, Month1, Month2, Day1, Day2
	if (V_flag)
		return 0
	endif
	
	DateStart 	= num2str(Year1) + "-" + num2str(Month1) + "-" + num2str(Day1)
	DateStop 	= num2str(Year2) + "-" + num2str(Month2) + "-" + num2str(Day2)
End

Function ReturnYearMonthDayFromString(Year,Month,Day,DateString)
	Variable &Year, &Month, &Day
	String DateString

	Year 		= str2num(ParseFilePath(0,DateString,"-",0,0))
	Month 	= str2num(ParseFilePath(0,DateString,"-",0,1))
	Day 		= str2num(ParseFilePath(0,DateString,"-",0,2))
	
End

Function TwoSpeciesWYCorrelations()
	
	SetDataFolder root:

	String ConcFolder 		= StrVAROrDefault("root:Geochem:gConcFolder","ER_PH_ISCO")
	String ConcFolder2 	= StrVAROrDefault("root:Geochem:gConcFolder2","same")
	Prompt ConcFolder, "Data source", popup, ListOfObjectsInFolder(4,"root:")
	Prompt ConcFolder2, "Second source", popup, "same;"+ListOfObjectsInFolder(4,"root:")
	DoPrompt "Choose data folders for correlations", ConcFolder, ConcFolder2
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gConcFolder = ConcFolder
	if (cmpstr(ConcFolder2,"same") == 0)
		ConcFolder2 	= ConcFolder
	endif
	String /G root:Geochem:gConcFolder2 = ConcFolder2
	
	String ConcList 	= ListOfObjectsInFolder(1,ConcFolder)
//	ConcList 				= ExclusiveWaveList(ConcList,"_y",";")
	String ConcList2 	= ListOfObjectsInFolder(1,ConcFolder2)
//	ConcList2 			= ExclusiveWaveList(ConcList2,"_y",";")
	
	String Species1 	= StrVAROrDefault("root:Geochem:gSpecies1","")
	String Species2 	= StrVAROrDefault("root:Geochem:gSpecies2","")
	String Species1Yr 	= StrVAROrDefault("root:Geochem:gSpecies1Yr","")
	String Species2Yr 	= StrVAROrDefault("root:Geochem:gSpecies2Yr","")
	String SaveFolder = StrVAROrDefault("root:Geochem:gSaveFolder","Correlations")
	String FolderList 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String MsgStr, NewFolderName = ""
	
	Prompt Species1, "Species 1", popup, ConcList
	Prompt Species2, "Species 2", popup, ConcList2
	Prompt Species1Yr, "Species 1 Yr", popup, ConcList
	Prompt Species2Yr, "Species 2 Yr", popup, ConcList2
	Prompt SaveFolder, "Destination", popup, FolderList
	Prompt NewFolderName, "Destination"
	DoPrompt "Choose correlation pair value and year data", Species1, Species2, Species1Yr, Species2Yr, SaveFolder, NewFolderName
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gSpecies1 = Species1
	String /G root:Geochem:gSpecies2 = Species2
	String /G root:Geochem:gSpecies1Yr = Species1Yr
	String /G root:Geochem:gSpecies2Yr = Species2Yr
	
	if (cmpstr(SaveFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		SaveFolder 	= NewFolderName
	endif
	String /G root:Geochem:gSaveFolder = SaveFolder
	SetDataFolder SaveFolder
	
	MsgStr 	= " * Calculating Water-Year correlations between "+Species1+" at "+ConcFolder+" and "+Species2+" at "+ConcFolder2
	
	Print MsgStr
	String CCNote = "CType=SpeciesCorrelation;Data1Folder="+ConcFolder+";Data2Folder="+ConcFolder2+";"
	
	String Ele1 		= ReturnTextBeforeNthChar(Species1,"_",1)
	String Ele2 		= ReturnTextBeforeNthChar(Species2,"_",1)
	String Unit1 		= ReturnTextAfterNthChar(Species1,"_",1)
	String Unit2 		= ReturnTextAfterNthChar(Species2,"_",1)
	
	WAVE CC1 	= $("root:"+ConcFolder+":"+Species1)
	WAVE CC2 	= $("root:"+ConcFolder2+":"+Species2)
	
	WAVE WY1 	= $("root:"+ConcFolder+":"+Species1Yr)
	WAVE WY2 	= $("root:"+ConcFolder2+":"+Species1Yr)
	
	WYCCCalculation(Ele1,CC1,WY1,Ele2,CC2,WY2,CCNote)
	
	SetDataFolder root:
End

Function WYCCCalculation(Ele1,CC1,WY1,Ele2,CC2,WY2,CCNote)
	String Ele1, Ele2, CCNote
	Wave CC1,WY1,CC2,WY2
	
	Variable i, WYr1, Val1, WYr2, Val2, nYrs=0
	
	Variable NN1=DimSize(CC1,0), NN2=DimSize(CC2,0)
	
	if (cmpstr(Ele1,Ele2) ==0)
		Ele1 = Ele1 +"a"
		Ele2 = Ele2 +"b"
	endif
	
	String Corr1Name, Corr2Name, CorrYrName
	if (strlen(Ele1+Ele1)<20)
		Corr1Name = Ele1+"_"+Ele2+"_"+Ele1
		Corr2Name = Ele1+"_"+Ele2+"_"+Ele2
	else
		Corr1Name = Ele1+"_"+Ele2+"_1"
		Corr2Name = Ele1+"_"+Ele2+"_2"
	endif
	CorrYrName 	= Ele1+"_"+Ele2+"_y"
	
	Make /D/O/N=0 $(Corr1Name) /WAVE=Ele1Wave
	Make /D/O/N=0 $(Corr2Name) /WAVE=Ele2Wave
	Make /D/O/N=0 $(CorrYrName) /WAVE=WYWave
	
	// Loop through all valid Element1 years
	for(i=0;i<NN1;i+=1)
		WYr1 	= WY1[i]
		
		if (numtype(WYr1) == 0)
			Val1 	= CC1[i]
			if (numtype(Val1) == 0)
				FindValue /V=(WYr1) WY2
				if (V_value != -1)
					WYr2 = WY2[V_value]
		
					Val2 	= CC2[V_value]
					if (numtype(Val2) == 0)
						nYrs += 1
						Redimension /N=(nYrs) Ele1Wave, Ele2Wave, WYWave
						Ele1Wave[nYrs-1] 	= Val1
						Ele2Wave[nYrs-1] 	= Val2
						WYWave[nYrs-1] 	= WYr1
					endif
					
				endif
			endif
		endif
	
	endfor
	
	if (WYr1==0)
		Print " 	- no common days - cannot calculate correlations" 
		KillWaves /Z Ele1Wave, Ele2Wave, DateWave, RGBWave
		return 0
	else
		Print " 	- found",nYrs,"years with data"
	endif
End









// Create pairs of concentration data for any two species. Also the common date values. 
// Would be worth to also create the common discharge values? 
Function TwoSpeciesCorrelations()
	
	SetDataFolder root:

	String ConcFolder 		= StrVAROrDefault("root:Geochem:gConcFolder","ER_PH_ISCO")
	String ConcFolder2 	= StrVAROrDefault("root:Geochem:gConcFolder2","same")
	Prompt ConcFolder, "Data source", popup, ListOfObjectsInFolder(4,"root:")
	Prompt ConcFolder2, "Second source", popup, "same;"+ListOfObjectsInFolder(4,"root:")
	DoPrompt "Choose data folders for correlations", ConcFolder, ConcFolder2
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gConcFolder = ConcFolder
	if (cmpstr(ConcFolder2,"same") == 0)
		ConcFolder2 	= ConcFolder
	endif
	String /G root:Geochem:gConcFolder2 = ConcFolder2
	
	String ConcList 	= ListOfObjectsInFolder(1,ConcFolder)
	ConcList 				= ExclusiveWaveList(ConcList,"_d",";")
	String ConcList2 	= ListOfObjectsInFolder(1,ConcFolder2)
	ConcList2 			= ExclusiveWaveList(ConcList2,"_d",";")
	
	String Species1 	= StrVAROrDefault("root:Geochem:gSpecies1","")
	String Species2 	= StrVAROrDefault("root:Geochem:gSpecies2","")
	String SaveFolder = StrVAROrDefault("root:Geochem:gSaveFolder","Correlations")
	String FolderList 	= "new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String MsgStr, NewFolderName = ""
	
	Variable Year, Month, Day, DateStartSecs, DateStopSecs
	Variable DateRange 	= NumVAROrDefault("root:Geochem:gDateRange",1)
	String DateStart 		= StrVAROrDefault("root:Geochem:gDateStart","2016-01-01")
	String DateStop 		= StrVAROrDefault("root:Geochem:gDateStop","2017-09-01")
	
	Prompt Species1, "Species 1", popup, ConcList
	Prompt Species2, "Species 2", popup, ConcList2
	Prompt SaveFolder, "Destination", popup, FolderList
	Prompt NewFolderName, "Destination"
	Prompt DateRange, "Date subrange?", popup, "no;yes;"
	DoPrompt "Choose correlation pair", Species1, Species2, SaveFolder, NewFolderName, DateRange
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gSpecies1 = Species1
	String /G root:Geochem:gSpecies2 = Species2
	Variable /G root:Geochem:gDateRange = DateRange
	
	if (cmpstr(SaveFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		SaveFolder 	= NewFolderName
	endif
	String /G root:Geochem:gSaveFolder = SaveFolder
	
	if (DateRange==2)
		if (PromptForDateSubrange(DateStart,DateStop) == 0)
			return 0
		endif
		String /G root:Geochem:gDateStart = DateStart
		String /G root:Geochem:gDateStop = DateStop
		
		ReturnYearMonthDayFromString(Year,Month,Day,DateStart)
		DateStartSecs = Date2Secs(Year, Month, Day)
		ReturnYearMonthDayFromString(Year,Month,Day,DateStop)
		DateStopSecs = Date2Secs(Year, Month, Day)
		
		MsgStr 	= " * Calculating correlations between "+Species1+" at "+ConcFolder+" and "+Species2+" at "+ConcFolder2+" between "+DateStart+" and "+DateStop
	else
		MsgStr 	= " * Calculating correlations between "+Species1+" at "+ConcFolder+" and "+Species2+" at "+ConcFolder2
	endif
		
	SetDataFolder SaveFolder
	
	Print MsgStr
	String CCNote = "CType=SpeciesCorrelation;Data1Folder="+ConcFolder+";Data2Folder="+ConcFolder2+";"
	
	String Ele1 	= StripSuffixBySeparator(Species1,"_")
	String Unit1 	= ReturnLastSuffix(Species1,"_")
	String Ele2 	= StripSuffixBySeparator(Species2,"_")
	String Unit2 	= ReturnLastSuffix(Species2,"_")
	
	WAVE CC1 	= $("root:"+ConcFolder+":"+Species1)
	WAVE CC2 	= $("root:"+ConcFolder2+":"+Species2)
	
	// Stupidly, there are 2 conventions
	WAVE DD1 	= $("root:"+ConcFolder+":"+Ele1+"_d")
	WAVE DD2 	= $("root:"+ConcFolder2+":"+Ele2+"_d")
	if (!WaveExists(DD1))
		WAVE DD1 	= $("root:"+ConcFolder+":"+Species1+"_d")
	endif
	if (!WaveExists(DD2))
		WAVE DD2 	= $("root:"+ConcFolder2+":"+Species2+"_d")
	endif
	if (!WaveExists(DD1) || !WaveExists(DD2))
		Print " 	- cannot locate date wave - check naming"
		return 0
	endif
	
//	CCCalculation(Ele1,CC1,DD1,Ele2,CC2,DD2,CCNote)
	CCCalculation(Ele1,CC1,DD1,Ele2,CC2,DD2,CCNote,DateRange,DateStartSecs,DateStopSecs)
	
	SetDataFolder root:
End

Function CCCalculation(Ele1,CC1,DD1,Ele2,CC2,DD2,CCNote,DateRange,DateStartSecs,DateStopSecs)
	String Ele1, Ele2, CCNote
	Wave CC1,DD1,CC2,DD2
	Variable DateRange, DateStartSecs, DateStopSecs
	
	Variable i, Day1, Val1, Day2, Val2, nDays=0
	
	Variable NN1=DimSize(DD1,0), NN2=DimSize(DD2,0)
	
	if (cmpstr(Ele1,Ele2) ==0)
		Ele1 = Ele1 +"a"
		Ele2 = Ele2 +"b"
	endif
	
	if (strlen(Ele1+Ele1)<20)
		String Corr1Name = Ele1+"_"+Ele2+"_"+Ele1
		String Corr2Name = Ele1+"_"+Ele2+"_"+Ele2
	else
		Corr1Name = Ele1+"_"+Ele2+"_1"
		Corr2Name = Ele1+"_"+Ele2+"_2"
	endif
	
	Make /D/O/N=0 $(Corr1Name) /WAVE=Ele1Wave
	Make /D/O/N=0 $(Corr2Name) /WAVE=Ele2Wave
	Note Ele1Wave, Ele1+"_"+Ele2+"_"+Ele1
	Note Ele2Wave, Ele1+"_"+Ele2+"_"+Ele2
	Make /D/O/N=0 $(Ele1+"_"+Ele2+"_d") /WAVE=DateWave
	Make /O/N=0 $(Ele1+"_"+Ele2+"_RGB") /WAVE=RGBWave
	
	// Loop through all valid Element1 dates
	for(i=0;i<NN1;i+=1)
		Day1 	= DD1[i]
		// check that DD2 is within the date range
		if ( (DateRange==2) && (  (Day1<DateStartSecs) || (Day1>DateStopSecs)  )  )
			// Outside range so do nothing
		else
		
			if (numtype(Day1) == 0)
				Val1 	= CC1[i]
				if (numtype(Val1) == 0)
					FindValue /V=(Day1) DD2
					if (V_value != -1)
						Day2 = DD2[V_value]
						// check that DD2 is within the date range
						if ( (DateRange==2) && (  (Day2<DateStartSecs) || (Day2>DateStopSecs)  )  )
							// Outside range so do nothing
						else
			
							Val2 	= CC2[V_value]
							if (numtype(Val2) == 0)
								nDays += 1
								Redimension /N=(nDays) Ele1Wave, Ele2Wave, DateWave, RGBWave
								Ele1Wave[nDays-1] 	= Val1
								Ele2Wave[nDays-1] 	= Val2
								DateWave[nDays-1] 	= Day1
							endif
							
						endif
					endif
				endif
			endif
		
		endif
	endfor
	
	if (nDays==0)
		Print " 	- no common days - cannot calculate correlations" 
		KillWaves /Z Ele1Wave, Ele2Wave, DateWave, RGBWave
		return 0
	else
		Print " 	- found",nDays,"dates with data"
	endif
	
	Note /K Ele1Wave,CCNote
	Note /K Ele2Wave,CCNote
	SetScale d, DateWave[0], DateWave[nDays-1],"dat", DateWave
End



//Function ConvertParameterUnits()()
//
//					if ( UNITCONVERT && (cmpstr(Unit,SaveUnit)!=0) )
//							TempWave1[] 		= ConvertBetweenUnitAndPPB(1,Prm,Unit,PWave[p])
//							TempWave2[] 		= ConvertBetweenUnitAndPPB(0,Prm,SAVEUNIT,TempWave1[p])
					
Function /WAVE ReturnSpeciesConcWaveRef(SiteFolder,Species,Unit)
	String SiteFolder, Species, Unit
	
	String SpeciesList, GeochemName, SpeciesName, SpeciesUnit
	Variable nSpecies, NValues

	WAVE SpcUnit 			= $("root:"+SiteFolder+":"+Species+"_"+Unit)
	
	if (WaveExists(SpcUnit))
		return SpcUnit
	else
		SpeciesList 	= ListOfObjectsInFolder(1,"root:"+Sitefolder)
		SpeciesList 	= InclusiveWaveList(SpeciesList,Species,";")
		SpeciesList 	= ExclusiveWaveList(SpeciesList,"_d",";")
		
		if (ItemsInList(SpeciesList) == 0)
			return $""
		endif 
		
		GeochemName 	= StringFromList(0,SpeciesList)
		SpeciesName 	= GeochemParameterFromName(GeochemName)
		SpeciesUnit 	= ReturnLastSuffix(GeochemName,"_")
		
		WAVE Spc 		= $("root:"+SiteFolder+":"+SpeciesName+"_"+SpeciesUnit)
		NValues 		= DimSize(Spc,0)

		
		Make /FREE/D/N=(NValues) CCppb
		Make /O/D/N=(NValues) $("root:"+SiteFolder+":"+SpeciesName+"_"+Unit) /WAVE=Convert
		
		ConvertDataBetweenUnitAndPPB(1,Species,SpeciesUnit,Spc,CCppb)
		
		ConvertDataBetweenUnitAndPPB(0,Species,Unit,Convert,CCppb)
	
	endif
	
End 

			
//Function CalculateKSrRatios()
//
//	String SiteList, SiteFolder
//	
//	
//	SiteList 	= ListOfObjectsInFolder(4,"root:")
//	NSites 	= ItemsInList(SiteList)
//	
//	
//	for (i=0;i<NSites;i+=1)
//	
//		SiteFolder 		= StringFromList(i,SiteList)
//		
//		WAVE KC 		= ReturnSpeciesConcWaveRef(SiteFolder,"K","uM")
//		WAVE SrC 		= ReturnSpeciesConcWaveRef(SiteFolder,"Sr","uM")
//		
//		if ( WaveExists(KC) && WaveExists(SrC) )
//		
//		
//		endif
//	
//	endfor 
	


// Loop through ALL folders and perform the chosen ratio
// Based on CalculateCQ and TwoSpeciesMath
Function TwoSpeciesRatio()

	SetDataFolder root:
	
	String Species1 = StrVarOrDefault("root:Geochem:gRatioSpecies1","K")
	String Species2 = StrVarOrDefault("root:Geochem:gRatioSpecies2","Sr")
	Prompt Species1, "Numerator species (e.g. 'K')"
	Prompt Species2, "Denominator species (e.g. 'Sr')"
	String RatioUnit1 = StrVarOrDefault("root:Geochem:gRatioUnit1","mgpL")
	String RatioUnit2 = StrVarOrDefault("root:Geochem:gRatioUnit2","ugpL")
	Prompt RatioUnit1, "Units  (e.g. 'mgpL')"
	Prompt RatioUnit2, " Units  (e.g. 'ugpL')"
	DoPrompt "Ratio of two time series data", Species1, RatioUnit1, Species2, RatioUnit2
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gRatioSpecies1 = Species1
	String /G root:Geochem:gRatioSpecies2 = Species2
	String /G root:Geochem:gRatioUnit1 = RatioUnit1
	String /G root:Geochem:gRatioUnit2 = RatioUnit2
	
	String SiteFolder, CCNote = "", SpeciesList, SpeciesName, Species
	String SiteFolderList 	= ListOfObjectsInFolder(4,"root:")
	
	Variable n, m, nSpecies, nFolders 		= ItemsInList(SiteFolderList)
	
	
	for (n=0;n<nFolders;n+=1)
		SiteFolder 	= StringFromList(n,SiteFolderList)
	
		if (strlen(RatioUnit1) > 0)					// A single unit has been chosen 
			WAVE CC1 		= $("root:"+SiteFolder+":"+Species1+"_"+RatioUnit1)
			WAVE DD1 		= $("root:"+SiteFolder+":"+Species1+"_"+RatioUnit1+"_d")
			
			if ( WaveExists(CC1) && WaveExists(DD1) )
				WAVE CC2 		= $("root:"+SiteFolder+":"+Species2+"_"+RatioUnit2)
				WAVE DD2 		= $("root:"+SiteFolder+":"+Species2+"_"+RatioUnit2+"_d")
				
				if ( WaveExists(CC2) && WaveExists(DD2) )
						
						Variable PrintFlag = 0
						if (PrintFlag)
							print " 		... calculating ratio of ",NameOfWave(CC1),"and",NameOfWave(CC2)," in ",SiteFolder
						endif
						
						SetDataFolder $("root:"+SiteFolder)
							MathCalculation(Species1,RatioUnit1,CC1,DD1,Species2,RatioUnit2,CC2,DD2,"Divide",1,Species1+"div"+Species2,CCNote,0)
				
				endif
			endif
		
		else
		
//			SpeciesList 		= ListOfObjectsInFolder(1,SiteFolder)
//			SpeciesList 		= ExclusiveWaveList(SpeciesList,"_d",";")
//			nSpecies 			= ItemsInList(SpeciesList)
//			
//			for (m=0;m<nSpecies;m+=1)
//				SpeciesName 	= StringFromList(m,SpeciesList)
//				Species 		= StripSuffixBySeparator(SpeciesName,"_")
//				RatioUnit 	= ReturnLastSuffix(SpeciesName,"_")
//				
//				if (cmpstr(Species,Species1) == 0)
//					WAVE CC1 		= $("root:"+SiteFolder+":"+Species1+"_"+RatioUnit)
//					WAVE DD1 		= $("root:"+SiteFolder+":"+Species1+"_"+RatioUnit+"_d")
//					
//					WAVE CC2 		= $("root:"+SiteFolder+":"+Species2+"_"+RatioUnit)
//					WAVE DD2 		= $("root:"+SiteFolder+":"+Species2+"_"+RatioUnit+"_d")
//				
//					if ( WaveExists(CC2) && WaveExists(DD2) )
//				
//						print " 		... calculating ratio of ",NameOfWave(CC1),"and",NameOfWave(CC2)," in ",SiteFolder
//						MathCalculation(Species1,RatioUnit,CC1,DD1,Species2,RatioUnit,CC2,DD2,"Divide",1,Species1+"div"+Species2,CCNote)
//					
//					endif
//					
//				endif
//			endfor
		
		endif
		
	endfor
		
	SetDataFolder root:
End



Function TwoSpeciesMath()
	
	SetDataFolder root:

	String ConcFolder 		= StrVAROrDefault("root:Geochem:gConcFolder","ER_PH_ISCO")
	String ConcFolder2 	= StrVAROrDefault("root:Geochem:gConcFolder2","same")
	Prompt ConcFolder, "Data source", popup, ListOfObjectsInFolder(4,"root:")
	Prompt ConcFolder2, "Second source", popup, "same;"+ListOfObjectsInFolder(4,"root:")
	DoPrompt "Choose data folders for calculations", ConcFolder, ConcFolder2
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gConcFolder = ConcFolder
	if (cmpstr(ConcFolder2,"same") == 0)
		ConcFolder2 	= ConcFolder
	endif
	String /G root:Geochem:gConcFolder2 = ConcFolder2
	
	String ConcList 	= ListOfObjectsInFolder(1,ConcFolder)
	ConcList 				= ExclusiveWaveList(ConcList,"_d",";")
	String ConcList2 	= ListOfObjectsInFolder(1,ConcFolder2)
	ConcList2 			= ExclusiveWaveList(ConcList2,"_d",";")
	
	String Species1 	= StrVAROrDefault("root:Geochem:gSpecies1","")
	String Species2 	= StrVAROrDefault("root:Geochem:gSpecies2","")
	Variable MathValue = NumVAROrDefault("root:Geochem:gMathValue",1)
	String Operation 	= StrVAROrDefault("root:Geochem:gOperation","Add")
	String ResultName 	= StrVAROrDefault("root:Geochem:gResultName","XdivY")
	String SaveFolder 	= StrVAROrDefault("root:Geochem:gSaveFolder","Correlations")
	String FolderList 	= "same as first;new - enter below;"+ListOfObjectsInFolder(4,"root:")
	String NewFolderName = ""
	
	Prompt Species1, "Species 1", popup, ConcList
	Prompt Species2, "Species 2 of value", popup, "value;" + ConcList2
	Prompt MathValue, "Optional value"
	Prompt Operation, "Operation", popup, "Add;Divide;Subtract;Multiply;"
	Prompt ResultName, "Name the result or blank for default" 
	Prompt SaveFolder, "Destination", popup, FolderList
	Prompt NewFolderName, "Destination"
	DoPrompt "Choose data pair and operation", Species1, Species2, Operation, MathValue, ResultName, SaveFolder, NewFolderName
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gSpecies1 = Species1
	String /G root:Geochem:gSpecies2 = Species2
	Variable /G root:Geochem:gMathValue = MathValue
	String /G root:Geochem:gOperation = Operation
	String /G root:Geochem:gResultName = ResultName
	
	String /G root:Geochem:gSaveFolder = SaveFolder
	SVAR gSaveFolder 	= root:Geochem:gSaveFolder
	
	if (cmpstr(SaveFolder,"new - enter below")==0)
		NewDataFolder/O $("root:"+NewFolderName)
		SaveFolder 		= NewFolderName
		gSaveFolder 		= SaveFolder
	elseif (cmpstr(SaveFolder,"same as first")==0)
		SaveFolder 		= ConcFolder
	endif
		
	SetDataFolder $(SaveFolder)
	
	Print " * Calculating ",Species1,"in",ConcFolder,Operation,Species2,"in",ConcFolder2,"and saving in",SaveFolder
	String CCNote = "CType=SpeciesMathOperation;Operation="+Operation+";Data1Folder="+ConcFolder+";Data2Folder="+ConcFolder2+";"
	
	String Ele1 	= StripSuffixBySeparator(Species1,"_")
	String Unit1 	= ReturnLastSuffix(Species1,"_")
	String Ele2 	= StripSuffixBySeparator(Species2,"_")
	String Unit2 	= ReturnLastSuffix(Species2,"_")
	
	WAVE CC1 	= $("root:"+ConcFolder+":"+Species1)
	WAVE CC2 	= $("root:"+ConcFolder2+":"+Species2)
	
	// Stupidly, there are 2 conventions
	WAVE DD1 	= $("root:"+ConcFolder+":"+Ele1+"_d")
	WAVE DD2 	= $("root:"+ConcFolder2+":"+Ele2+"_d")
	if (!WaveExists(DD1))
		WAVE DD1 	= $("root:"+ConcFolder+":"+Species1+"_d")
	endif
	if (!WaveExists(DD2))
		WAVE DD2 	= $("root:"+ConcFolder2+":"+Species2+"_d")
	endif
	if ((!WaveExists(DD1)) || (!WaveExists(DD1)))
		Print " 	- cannot locate date wave - check naming"
		return 0
	endif
	
	MathCalculation(Ele1,Unit1,CC1,DD1,Ele2,Unit2,CC2,DD2,Operation,MathValue,ResultName,CCNote,1)
	
	SetDataFolder root:
End

Function MathCalculation(Ele1,Unit1,CC1,DD1,Ele2,Unit2,CC2,DD2,Operation,MathValue,ResultName,CCNote,PrintFlag)
	String Ele1, Ele2, Unit1, Unit2, Operation, ResultName, CCNote
	Wave CC1,DD1,CC2,DD2
	Variable MathValue, PrintFlag
	
	Variable i, Day1, Val1, Day2, Val2, nDays=0
	
	Variable NN1=DimSize(DD1,0), NN2=DimSize(DD2,0)
	
	if (strlen(ResultName) == 0)
		if (cmpstr(Ele1,Ele2) ==0)
			Ele1 = Ele1 +"a"
			Ele2 = Ele2 +"b"
		endif
//		ResultName = Ele1+"_"+Operation[0,2]+"_"+Ele2
		ResultName = Ele1+Operation[0,2]+Ele2+"_"+Unit1
	endif
	
	Make /D/O/N=0 $(ResultName) /WAVE=MathWave
	Make /D/O/N=0 $(ResultName+"_d") /WAVE=DateWave
//	Make /O/N=0 $(ResultName+"_RGB") /WAVE=RGBWave
	
	// Loop through all valid Element1 dates
	for(i=0;i<NN1;i+=1)
		Day1 	= DD1[i]
		if (numtype(Day1) == 0)
			Val1 	= CC1[i]
			if (numtype(Val1) == 0)
			
				if (WaveExists(CC2))
					FindValue /V=(Day1) DD2
					if (V_value != -1)
						Val2 	= CC2[V_value]
					else
						Val2 = NaN
					endif
				else
					// !&!&!&!& 2025-05-09 This does not seem to be useful 
					Val2 = MathValue
					// Need to exclude. 
					Val2 = NaN
				endif
					
					if (numtype(Val2) == 0)
						nDays += 1
//						Redimension /N=(nDays) MathWave, DateWave, RGBWave
						Redimension /N=(nDays) MathWave, DateWave
						
						DateWave[nDays-1] 	= Day1
						if (cmpstr(Operation,"Divide") == 0)
							MathWave[nDays-1] 	= Val1/Val2
						elseif (cmpstr(Operation,"Add") == 0)
							MathWave[nDays-1] 	= Val1+Val2
						elseif (cmpstr(Operation,"Multiply") == 0)
							MathWave[nDays-1] 	= Val1*Val2
						elseif (cmpstr(Operation,"Subtract") == 0)
							MathWave[nDays-1] 	= Val1-Val2
						endif
					endif
			endif
		endif
	endfor
	
	if (nDays==0)
		if (PrintFlag)
			Print " 	- no common days - cannot perform operation" 
		endif 
		KillWaves /Z MathWave, DateWave, RGBWave
		return 0
	endif
	
	Note /K MathWave,CCNote
	SetScale d, DateWave[0], DateWave[nDays-1],"dat", DateWave
End

Function FindCommonDates()

	SetDataFolder root:
	
	String ConcFolder 	= StrVAROrDefault("root:Geochem:gConcFolder","PH_Isco")
	String FolderList1 	= ListOfObjectsInFolder(4,"root:")
	
	Prompt ConcFolder, "Data Source", popup, FolderList1
	DoPrompt "Calculate single or all Concentration trends", ConcFolder
	if (V_flag)
		return 0
	endif
	String /G root:Geochem:gConcFolder = ConcFolder
	
	// List all the data in the data folder
	String ConcList = ListOfObjectsInFolder(1,"root:"+ConcFolder)
	ConcList = ExclusiveWaveList(ConcList,"_d",";")
	
	// Probably no elegant way to do this. 
	String FieldDataName, FieldDateName, Unit, FieldData2Name, FieldDate2Name, Unit2
	Variable i, j, n, m, NDeleted, NPts1, NPts2, DateSecs, DateSecs2
	Variable NData = ItemsInList(ConcList)
	
	SetDataFolder $ConcFolder
	
	// First find REPEATED dates. Assume SORTED dates
	for (i=0;i<NData; i+=1)
		FieldDataName 		= StringFromList(i,ConcList)
		WAVE FieldData 	= $FieldDataName
		Unit 					= GeochemUnitFromName(FieldDataName)
		FieldDateName 		= ReplaceString("_"+Unit,FieldDataName,"_d")
		WAVE FieldDate 	= $FieldDateName
		NPts1 				= DimSize(FieldData,0)
		
		n = 0
		m = 0
		NDeleted = 0
		do 
			DateSecs 			= FieldDate[n]
			DateSecs2 			= FieldDate[n+1]
		
			if (DateSecs == DateSecs2)
				DeletePoints n+1, 1, FieldDate, FieldData
				NDeleted += 1
			else
				n +=1
			endif
			m +=1
		while (m < (NPts1-1))
			print "looked for repeated points in",FieldDataName,"and made",NDeleted,"deletions"
	endfor
	
	return 1
	
	// Now look for dates that are NOT present in all data
	for (i=0;i<NData; i+=1)
		FieldDataName 		= StringFromList(i,ConcList)
		WAVE FieldData 	= $FieldDataName
		Unit 					= GeochemUnitFromName(FieldDataName)
		FieldDateName 		= ReplaceString("_"+Unit,FieldDataName,"_d")
		WAVE FieldDate 	= $FieldDateName
		NPts1 				= DimSize(FieldData,0)
		
		for (j=0;j<NData;j+=1)

			FieldData2Name 	= StringFromList(j,ConcList)
			WAVE FieldData2 	= $FieldData2Name
			Unit2 					= GeochemUnitFromName(FieldData2Name)
			FieldDate2Name 	= ReplaceString("_"+Unit2,FieldData2Name,"_d")
			WAVE FieldDate2 	= $FieldDate2Name
			NPts2 				= DimSize(FieldData2,0)
			
			n=0
			m=0
			NDeleted = 0
			do
				DateSecs 	= FieldDate[n]
				
				FindValue /V=(DateSecs)/Z FieldDate2
				if (V_value < 0)
					DeletePoints n, 1, FieldDate, FieldData
					NDeleted += 1
				else
					n +=1
				endif
				m += 1
			while (m<NPts1)
			
			print "compared",FieldDataName,"with",FieldData2Name,"and made",NDeleted,"deletions"
			DoUpdate
			
		endfor
	
	endfor
End

// Assume we are in the root data folder
Function MakeWinnickDataSet()

//	Duplicate root:ER_PH_Discharge:Q1520_d root:ER_PH_ISCO_Winnick:Q1520_d
//	Duplicate root:ER_PH_Discharge:Q1520_m3s root:ER_PH_ISCO_Winnick:Q1520_m3s
	Duplicate root:ER_PH_Discharge:discharge_d root:ER_PH_ISCO_Winnick:discharge_d
	Duplicate root:ER_PH_Discharge:discharge_m3ps root:ER_PH_ISCO_Winnick:discharge_m3s

	Duplicate root:ER_PH_ISCO:DIC_d root:ER_PH_ISCO_Winnick:DIC_d
	Duplicate root:ER_PH_ISCO:DIC_uM root:ER_PH_ISCO_Winnick:DIC_uM
	
	Duplicate root:ER_PH_ISCO:NPOC_d root:ER_PH_ISCO_Winnick:DOC_d
	Duplicate root:ER_PH_ISCO:NPOC_uM root:ER_PH_ISCO_Winnick:DOC_uM
	
	Duplicate root:ER_PH_ISCO:Ca_d root:ER_PH_ISCO_Winnick:Ca_d
	Duplicate root:ER_PH_ISCO:Ca_uM root:ER_PH_ISCO_Winnick:Ca_uM
	
	Duplicate root:ER_PH_ISCO:Mg_d root:ER_PH_ISCO_Winnick:Mg_d
	Duplicate root:ER_PH_ISCO:Mg_uM root:ER_PH_ISCO_Winnick:Mg_uM
	
	Duplicate root:ER_PH_ISCO:Na_d root:ER_PH_ISCO_Winnick:Na_d
	Duplicate root:ER_PH_ISCO:Na_uM root:ER_PH_ISCO_Winnick:Na_uM
	
	Duplicate root:ER_PH_ISCO:K_d root:ER_PH_ISCO_Winnick:K_d
	Duplicate root:ER_PH_ISCO:K_uM root:ER_PH_ISCO_Winnick:K_uM
	
	Duplicate root:ER_PH_ISCO:Si_d root:ER_PH_ISCO_Winnick:Si_d
	Duplicate root:ER_PH_ISCO:Si_uM root:ER_PH_ISCO_Winnick:Si_uM
	
	Duplicate root:ER_PH_ISCO:SO4_d root:ER_PH_ISCO_Winnick:SO4_d
	Duplicate root:ER_PH_ISCO:SO4_uM root:ER_PH_ISCO_Winnick:SO4_uM
	
	Duplicate root:ER_PH_ISCO:Cl_d root:ER_PH_ISCO_Winnick:Cl_d
	Duplicate root:ER_PH_ISCO:Cl_uM root:ER_PH_ISCO_Winnick:Cl_uM
	
	Duplicate root:ER_PH_ISCO:NO3_d root:ER_PH_ISCO_Winnick:NO3_d
	Duplicate root:ER_PH_ISCO:NO3_uM root:ER_PH_ISCO_Winnick:NO3_uM
End


//Function CQCalculation2()
//
//	NewDataFolder/O/S root:CQ
//	
//	WAVE Discharge 	= root:discharge
//	WAVE Dis_Date 		= root:discharge_d
//	SetScale d 0,0,"", Dis_Date
//	
//	String Ele, DataList = DataFolderDir(2,root:)
//	String DataList1 = InclusiveWaveList(DataList,"ppb",",")
//	String DataList2 = InclusiveWaveList(DataList,"uM",",")
//	
//	Variable i, NData = ItemsinList(DataList1,",")
//	
//	// metals in ppb
////	for (i=0;i<NData;i+=1)
////		Ele 	= StripSuffixBySeparator(StringFromList(i,DataList1,","),"_")
////		WAVE Element = $("root:"+Ele+"_ppb")
////		WAVE Ele_Date = $("root:"+Ele+"_d")
////		SetScale d 0,0,"", Ele_Date
////		CQCorrelation(Ele,Discharge,Dis_Date,Element,Ele_Date)
////	endfor
//	
//	NData = ItemsinList(DataList2,",")
//	
//	// species in uM
//	for (i=0;i<NData;i+=1)
//		Ele 	= StripSuffixBySeparator(StringFromList(i,DataList2,","),"_")
//		WAVE Element = $("root:"+Ele+"_uM")
//		WAVE Ele_Date = $("root:"+Ele+"_d")
//		SetScale d 0,0,"", Ele_Date
//		if (stringmatch(Ele,"N"))
//			CQCalculation(Ele,Discharge,Dis_Date,Element,Ele_Date)
//		endif
//	endfor
//	
//End



//	Function CQCalculation()
//	
//		NewDataFolder/O/S root:CQ
//		
//		WAVE Discharge 	= root:discharge
//		WAVE Dis_Date 		= root:discharge_d
//		SetScale d 0,0,"", Dis_Date
//		
//		// Loop through all elements
//		Variable i, j, nDates=0, EDate, EVal, DateStart=0
//		Variable NEDates, NDDates = DimSize(Dis_Date,0)
//		String ZStr, ZName, ZCName, ZQName
//		
//		for (i=0;i<100;i+=1)
//		
//		ZStr 		= ZNumberToAtom(i)
//		ZName 	= ZStr + "_ppb"
//		ZCName 	= ZStr + "_C"
//		ZQName 	= ZStr + "_Q"
//		
//		WAVE element 	= $("root:" + ZName)
//		WAVE ele_date 	= $("root:" + ZStr + "_d")
//	
//			if (WaveExists(element))
//				NEDates 	= DimSize(ele_date,0)
//				SetScale d 0,0,"", ele_date
//				
//				Make /O/D/N=0 $ZCName /WAVE=CC
//				Make /O/D/N=0 $ZQName /WAVE=QQ
//				
//				for(j=0;j<NEDates;j+=1)
//				
//					EDate = ele_date[j]
//					EVal = element[j]
//					
//					if ((numtype(EDate) == 2) || (numtype(EVal) == 2))
//					else
//						FindValue /V=(EDate) /S=(DateStart) Dis_Date
//						
//						if (V_value != -1)
//							nDates += 1
//							Redimension /N=(nDates) CC, QQ
//							CC[nDates-1] 	= element[V_value]
//							QQ[nDates-1] 	= Discharge[V_value]
//		//					DateStart = V_value
//						endif
//						
//					endif
//				endfor
//				
//			endif
//			
//	//		Variable nn=0
//	//		for (j=0;j<nDates;j+=1)
//	//			if (numtype(CC[nn]) == 2)
//	//				DeletePoints nn, 1, CC, QQ
//	//			else
//	//				nn+=1
//	//			endif
//	//		endfor
//		
//		endfor
//		
//		SetDataFolder root:
//	
//	End