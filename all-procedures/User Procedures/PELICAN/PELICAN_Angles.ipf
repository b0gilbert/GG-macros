// Updated 07.21.2015 19:51
#pragma rtGlobals=1		// Use modern global access method.

// ***************************************************************************
// **************** 	ORIENTATION ANALYSIS - Neighbor angles 
// ***************************************************************************

Function NeighborAngles()

	CalculateNeighborAngles(1)

End

Function NeighborAnglesWithMask()

	CalculateNeighborAngles(2)

End

Function CalculateNeighborAngles(ANGLEMASK)
	Variable ANGLEMASK
	
	NVAR gBmin 				= root:POLARIZATION:gBmin
	
	SVAR gStackName 		= root:SPHINX:Browser:gStackName
	WAVE POL_BB 				= root:SPHINX:Stacks:POL_BB
	WAVE POL_PhiSP 			= root:SPHINX:Stacks:POL_PhiSP
	WAVE POL_ThetSP 		= root:SPHINX:Stacks:POL_ThetSP
	
	String LoadMaskName, MaskName 	= gStackName+"_mask"
	Variable NXW, NYW, NX=DimSize(POL_PhiSP,0), NY=DimSize(POL_PhiSP,1)
	
//	Variable ANGLEMASK = NumVarOrDefault("root:POLARIZATION:gANGLEMASK",4)	// <-- this is the current Default
//	Variable ANGLEMASK = NumVarOrDefault("root:POLARIZATION:gANGLEMASK",3)	// <-- Default is Load User mask
//	Variable ANGLEMASK = NumVarOrDefault("root:POLARIZATION:gANGLEMASK",4)	// <-- Default is no mask

// ANGLEMASK = 3 // <-- this is the current Default (this overrides and transfers to new pxp's)
	
// Prompt ANGLEMASK, "Mask options", popup, "bMin;Current user mask;Load user mask;none;bMin+;"
//	Prompt ANGLEMASK, "Mask options", popup, "none;Load user mask;"
//	DoPrompt "Neighbor angles calculation", ANGLEMASK
//	if (V_flag)
//		return 0
//	endif
	
//	Variable /G root:POLARIZATION:gANGLEMASK = ANGLEMASK
//	NVAR gANGLEMASK = root:POLARIZATION:gANGLEMASK
	
		
//	if (ANGLEMASK==2)	// Check that a mask is loaded
//		WAVE MaskWave = $("root:SPHINX:Stacks:"+MaskName)
//		if (!WaveExists(MaskWave))
//			Print " ** No mask in memory - need to load one"
//			ANGLEMASK=3
//		endif
//	endif
	
	if (ANGLEMASK==2)	// Load a new mask
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
				//gANGLEMASK=2
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
//			if (ANGLEMASK==2)
//				if ( (MaskWave[i][j][0] == 65535) || (MaskWave[i][j][0] == 255) )
//					MEASUREPX = 1
//				endif
//			elseif (ANGLEMASK==1)
//				if (POL_BB[i][j] > gBmin)
//					MEASUREPX = 1
//				endif
//			elseif (ANGLEMASK==4)
//					MEASUREPX = 1
//			endif

			if (ANGLEMASK==2)
				if ( (MaskWave[i][j][0] == 65535) || (MaskWave[i][j][0] == 255) )
					MEASUREPX = 1
				endif
			else
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
//							if (ANGLEMASK==2)
//								if ( (MaskWave[i+n][j+m][0] == 65535) || (MaskWave[i+n][j+m][0] == 255))
//									MEASUREPX = 1
//								endif
//							elseif (ANGLEMASK==1)
//								if (POL_BB[i+n][j+m] > gBmin)
//									MEASUREPX = 1
//								endif
//							elseif (ANGLEMASK==4)
//									MEASUREPX = 1
//							endif

							if (ANGLEMASK==2)
								if ( (MaskWave[i+n][j+m][0] == 65535) || (MaskWave[i+n][j+m][0] == 255))
									MEASUREPX = 1
								endif
							else
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
	
	if (ANGLEMASK==2)
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
		// print HomeFileList
		do
			HistNm +=1 
			HistExportName = gStackName+"_MaxGammaHistogram"+num2str(HistNm)+".txt"
			// print HistExportName
		while (WhichListItem(HistExportName,HomeFileList) > -1)
		
		//Save/J/M="\n"/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data,Peak_position,FWHM,Footprint as HistExportName
		Save /I/J/M="\n"/P=home/W/U={0,0,1,0} Hist_Axis,Hist_Data,Peak_position,FWHM,Footprint as HistExportName
	endif
	
End

Function NbrAngleHistogramStats(GammaHist,histStats)
	Wave GammaHist, histStats
	
	Variable Center, FWHM, Footprint
	
	Variable histMax, histMaxLoc, fitMinX, fitMinPt, fitMaxX, fitMaxPt
	
	// Igor's Find peak is not working reliably so use a custom approach 

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
