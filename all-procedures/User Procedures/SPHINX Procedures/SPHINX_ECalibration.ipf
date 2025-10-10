#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// *************************************************************
// ****		Correcting the Energy Axis so a chosen peak lies at a given energy
// *************************************************************
//
// 	Fit a Gaussian to one peak. Doesn't work that well, actually. 

Function SetPRange(SV_Struct) 
	STRUCT WMSetVariableAction &SV_Struct 
	
	String WindowName = SV_Struct.win
	String ctrlName 	= SV_Struct.ctrlName
	Variable varNum 	= SV_Struct.dval
	
	Variable eventCode 	= SV_Struct.eventCode
	if (eventCode == -1)
		return 0
	endif
	
	// This is everything we need to look up, starting from the SUBWINDOW name
	String PanelName 	= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 	= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	String StackWindow = PanelName+"#StackImage"
	String StackAvg		= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack		= ImageNameToWaveRef(StackWindow,StackAvg)
	String StackFolder	= GetWavesDataFolder(avStack,1)
	String StackName 	= ReplaceString("_av",StackAvg,"")
	WAVE SPHINXStack	= $(StackFolder+StackName)
	
	NVAR gPMin		= $(PanelFolder+":gPMin")
	NVAR gPMax		= $(PanelFolder+":gPMax")
	WAVE PRange 		= $(PanelFolder+":prange")
	
	if (cmpstr(ctrlName,"PMinSetVar") == 0)
		gPMin = varNum
	elseif (cmpstr(ctrlName,"PMaxSetVar") == 0)
		gPMax = varNum
	endif
	
	PRange 		= 0
	PRange[gPMin,gPMax]	= 1
End

Function ShowPRange(CB_Struct) 
	STRUCT WMCheckboxAction &CB_Struct 
	
	String WindowName = CB_Struct.win
	String ctrlName 	= CB_Struct.ctrlName
	Variable checked 	= CB_Struct.checked
	
	Variable eventCode 	= CB_Struct.eventCode
	if (eventCode == -1)
		return 0
	endif
	
	// This is everything we need to look up, starting from the SUBWINDOW name
	String PanelName 		= ParseFilePath(0, WindowName, "#", 0, 0)
	String PanelFolder 		= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	String StackWindow 	= PanelName+"#StackImage"
	String SpectraWindow 	= PanelName+"#PixelPlot"
	String StackAvg			= StringByKey("TNAME",CsrInfo(A,StackWindow))
	WAVE avStack			= ImageNameToWaveRef(StackWindow,StackAvg)
	String StackFolder		= GetWavesDataFolder(avStack,1)
	String StackName 		= ReplaceString("_av",StackAvg,"")
	WAVE SPHINXStack		= $(StackFolder+StackName)
	String StackAxisName	= StackName + "_axis"
	WAVE StackAxis 		= $(ParseFilePath(2,StackFolder,":",0,0) + StackAxisName)
	
	NVAR gPMin		= $(PanelFolder+":gPMin")
	NVAR gPMax		= $(PanelFolder+":gPMax")
	WAVE PRange 		= $(PanelFolder+":prange")
	
	CheckDisplayed /W=$SpectraWindow PRange
	
	if (checked && !V_flag)
		SetVariable PMinSetVar, disable=0
		SetVariable PMaxSetVar, disable=0
		SetVariable PEnergySetVar, disable=0
		Button CorrectE, disable=0
		
		PRange 		= 0
		PRange[gPMin,gPMax]	= 1
		
		AppendToGraph /R/W=$SpectraWindow PRange vs StackAxis
		
		ModifyGraph /W=$SpectraWindow mode(prange)=5, hbFill(prange)=2
		ModifyGraph /W=$SpectraWindow rgb(prange)=(52428,52428,52428)
		ModifyGraph /W=$SpectraWindow tick(right)=3,noLabel(right)=1
		
		ReorderTraces /W=$SpectraWindow  $("specplot"),{$("prange")}
		
	elseif (!checked && V_flag)
		SetVariable PMinSetVar, disable=2
		SetVariable PMaxSetVar, disable=2
		SetVariable PEnergySetVar, disable=0
		Button CorrectE, disable=2
		
		RemoveFromGraph /W=$SpectraWindow PRange
		ModifyGraph /W=$SpectraWindow mirror(left)=2
	endif
End


Function CorrectStackEnergy(SPHINXStack,PanelName)
	Wave SPHINXStack
	String PanelName
	
	String StackName 	= NameOfWave(SPHINXStack)
	String cStackName = ModifiedStackName(StackName,"c")
	
	try
		RealCorrectStackEnergy(SPHINXStack,PanelName);AbortOnRTE
	catch
		CloseProcessBar()
		// Can I try killing partially corrected stacks? 
		
		if (V_AbortCode == -1)
			Print " *** Pixel energy calibration routine aborted by user."
		else
			Print " *** Pixel energy calibration routine aborted due to error."
		endif
		
		NVAR gMT 		= root:SPHINX:Stacks:gMT
		Variable tgOK 	= ThreadGroupRelease(gMT)
		if (tgOK == -2)
			DoAlert 0, "Cannot quit running threads - best to restart Igor."
		endif
	endtry
End
		
Function RealCorrectStackEnergy(SPHINXStack,PanelName)
	Wave SPHINXStack
	String PanelName
	
	String StackName 		= NameOfWave(SPHINXStack)
	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
	WAVE PAxis 			= $(ParseFilePAth(2,StackFolder,":",0,0) + StackName + "_axis")
	String StackWindow 	= PanelName+"#StackImage"
	
	String PanelFolder 		= "root:SPHINX:" + ReplaceString("Stack",PanelName,"")
	WAVE pspectrum 		= $(PanelFolder+":pspectrum")
	NVAR gPEnergy 			= $(PanelFolder+":gPEnergy")
	NVAR gPMin 			= $(PanelFolder+":gPMin")
	NVAR gPMax 			= $(PanelFolder+":gPMax")
	
	Variable i, j, offset
	Variable NumX = Dimsize(SPHINXStack,0)
	Variable NumY = Dimsize(SPHINXStack,1)
	Variable NumE = Dimsize(SPHINXStack,2)
	
	if ((gPEnergy < PAxis[0]) || (gPEnergy > PAxis[NumE-1]))
		Print " *** Please choose the correct peak energy!"
		return 0
	endif
	
	// work out displayed image range. 
	GetAxis/W=$StackWindow/Q left
	Variable Y1 	= max(0,floor(V_min))
	Variable Y2 	= min(NumY,ceil(V_max))
	Variable cNumY = Y2-Y1
	
	GetAxis/W=$StackWindow/Q bottom
	Variable X1 	= max(0,floor(V_min))
	Variable X2 	= min(NumX,ceil(V_max))
	Variable cNumX = X2-X1
	
	Variable n,col,nthreads= ThreadProcessorCount
	variable tIdx, tgOK
	
	Variable /G root:SPHINX:Stacks:gMT
	NVAR gMT 	= root:SPHINX:Stacks:gMT
	
	// Create a new stack to contain the corrected energy values ...
	String cStackName = ModifiedStackName(StackName,"c")
	
	Make /O/B/U/N=(cNumX,cNumY,NumE) $(ParseFilePath(2,StackFolder,":",0,0)+cStackName) /WAVE=cStack
	Duplicate /O/D PAxis, $(ParseFilePath(2,StackFolder,":",0,0)+cStackName+"_axis")
	
	// ... and some images to inspects offsets and fitting errors. 
	Make /O/D/N=(cNumX,cNumY) $(ParseFilePath(2,StackFolder,":",0,0)+cStackName+"_o") /WAVE=POffsets
	Make /O/D/N=(cNumX,cNumY) $(ParseFilePath(2,StackFolder,":",0,0)+cStackName+"_e") /WAVE=PErrors
	
	// Make separate coefficients and error waves for each thread
	Variable PolyO=3
	String HoldStr
	Print " *** 	Calibrating pixel energy axes using",nthreads,"processor threads"
	for (i=0;i<nthreads;i+=1)
		Make /O/D/N=(4+PolyO+1) $(ParseFilePath(2,StackFolder,":",0,0)+"cfs_"+num2str(i)) /WAVE=Cfs
		Make /O/D/N=(4+PolyO+1) $(ParseFilePath(2,StackFolder,":",0,0)+"err_"+num2str(i))
		
//		Make /O/D/N=(PolyO) $(ParseFilePath(2,StackFolder,":",0,0)+"pcfs_"+num2str(i))
		
		// Starting guesses for the peak
//		Cfs[0] 	= 0
//		Cfs[1] 	= 1
//		Cfs[2] 	= mean(PAxis,gPMin,gPMax)
//		Cfs[3] 	= 1

		HoldStr = "00001"
	
		// Starting guesses for the polynomial component
		Cfs[4] 	= mean(PAxis,gPMin,gPMax)
		for (i=0;i<PolyO;i+=1)
			Cfs[5+i] 	= 1/(10^i)
			HoldStr +="0"
		endfor
	endfor
	
	Variable Duration, timeRef 	= startMSTimer
	
	OpenProcBar("Correcting the energy axes for "+StackName)
	
	gMT 	= ThreadGroupCreate(nthreads)
	for (j=Y1;j<Y2;j+=1)
	
		do
			tIdx= ThreadGroupWait(gMT,10)
		while(tIdx != 0 )
		
		WAVE Cfs 	= $(ParseFilePath(2,StackFolder,":",0,0)+"cfs_"+num2str(tIdx))
		WAVE Err 	= $(ParseFilePath(2,StackFolder,":",0,0)+"err_"+num2str(tIdx))
		
		ThreadStart gMT,tIdx,FitEnergyOffset(SPHINXStack,cStack,PAxis,Cfs,Err,POffsets,PErrors,X1,X2,Y1,j,gPMin,gPMax,gPEnergy,HoldStr)
//		FitEnergyOffset(SPHINXStack,cStack,PAxis,Cfs,Err,POffsets,PErrors,X1,X2,Y1,j,gPMin,gPMax,gPEnergy,HoldStr)
		
		UpdateProcessBar((j-Y1)/(Y2-Y1))
			
	endfor
	tgOK 	= ThreadGroupRelease(gMT)
	
	CloseProcessBar()
	
	Duration = stopMSTimer(timeRef)/1000000
	Print " 		.............. took  ", Duration,"  seconds for ",cNumX*cNumY,"pixels. "
	
	KillNNamedWaves("root:SPHINX:Stacks:cfs_",nthreads)
	KillNNamedWaves("root:SPHINX:Stacks:err_",nthreads)
	
	ImageDisplayPanel(POffsets,"CyanMagenta","Calibration Offsets",NameOfWave(POffsets),cNumX,cNumY)
	ImageDisplayPanel(PErrors,"Copper","Calibration Errors",NameOfWave(PErrors),cNumX,cNumY)
End

ThreadSafe Function FitEnergyOffset(PStack,cPStack,PAxis,Cfs,Err,POffsets,PErrors,X1,X2,Y1,col,PMin,PMax,PEnergy,HoldStr)
//Function FitEnergyOffset(PStack,cPStack,PAxis,Cfs,Err,POffsets,PErrors,X1,X2,Y1,col,PMin,PMax,PEnergy,HoldStr)

	WAVE PStack,cPStack,PAxis,Cfs,Err,POffsets,PErrors
	Variable X1,X2,Y1,col,PMin,PMax,PEnergy
	String HoldStr
	
	Variable i, offset, center
	Variable V_FitQuitReason, V_FitError=0, V_fitOptions=4
	
	center 	= mean(PAxis,PMin,PMax)
	
	// Fit to a 'beam' of of values using stack subrange. 
	// Enforce use of single processor thread
	for (i=X1;i<X2;i+=1)
	
			// Starting guesses
		Cfs[0] 	= 0
		Cfs[1] 	= 1
		Cfs[2] 	= center
		Cfs[3] 	= 1
		
		V_FitError=0
		CurveFit /Q/N/NTHR=1 gauss kwCWave=Cfs PStack[i][col][PMin,PMax] /X=PAxis[PMin,PMax]
//		FuncFit /N/NTHR=1/H=HoldStr GaussBG Cfs PStack[i][col][PMin,PMax] /X=PAxis[PMin,PMax]
		
		if ((V_FitError == 0) && (V_FitQuitReason == 0))
			WAVE W_sigma
			err = W_sigma
		
			offset = PEnergy - Cfs[2]
			
			cPStack[i-X1][col-Y1][] 	= round(PStack[i][col][BinarySearchInterp(PAxis,PAxis[r]-offset)])
			
			POffsets[i-X1][col-Y1] 	= offset
			PErrors[i-X1][col-Y1] 	= err[2]
		endif
	endfor
End

Function GaussBG(w,x) : FitFunc	
	Wave w, x
	
	Variable i, val, pOffset, pOrder

	val 	= Gauss1D(cw, x)
	
	pOffset 	= w[4]
	pOrder 	= numpnts(w)-5
	
	for (i=0;i<pOrder;i+=1)
		val += w[5+i]*(x-pOffset)^i
	endfor
	
	return val
End

//Function GaussBG(w,yw,xw) : FitFunc	
//	Wave w, xw, yw
//	
//	Variable i, pOffset, pOrder
//
//	yw[] 	= Gauss1D(cw, xw[p])
//	
//	pOffset 	= w[4]
//	pOrder 	= numpnts(w)-5
//	
//	for (i=0;i<pOrder;i+=1)
//		yw[] += w[5+i]*(xw[p]-pOffset)^i
//	endfor
//	
//	
//End

// A single thread version for debugging
//Function STCorrectStackEnergy(SPHINXStack)
//	Wave SPHINXStack
//	
//	String SPHINXFolder 	= "root:SPHINX:"
//	WAVE pspectrum 		= $(SPHINXFolder+"pspectrum")
//	NVAR gPEnergy 			= $(SPHINXFolder+"gPEnergy")
//	NVAR gPMin 			= $(SPHINXFolder+"gPMin")
//	NVAR gPMax 			= $(SPHINXFolder+"gPMax")
//	
//	String StackName 		= NameOfWave(SPHINXStack)
//	String StackFolder		= GetWavesDataFolder(SPHINXStack,1)
//	WAVE paxis 			= $(CheckFolderColon(StackFolder) + StackName + "_axis")
//	
//	Variable i, j, offset
//	Variable NumX = Dimsize(SPHINXStack,0)
//	Variable NumY = Dimsize(SPHINXStack,1)
//	Variable NumE = Dimsize(SPHINXStack,2)
//	
//	if ((gPEnergy < paxis[0]) || (gPEnergy > paxis[NumE-1]))
//		Print " *** Please choose the correct peak energy!"
//		return 0
//	endif
//	
//	Duplicate /O/D SPHINXStack, $(SPHINXFolder+"Stacks:"+StackName+"_c")
//	WAVE cStack 	= $(SPHINXFolder+"Stacks:"+StackName+"_c")
//	
//	Duplicate /O/D paxis, $(SPHINXFolder+"Stacks:"+StackName+"_c_axis")
//	
//	OpenProcBar("Correcting the energy axes for "+StackName)
//	
//	Variable V_FitQuitReason, V_FitError, V_fitOptions=4
//	
//	for (i=1;i<NumX-1;i+=1)
//		for (j=1;j<NumY-1;j+=1)
//			pspectrum[] 	= SPHINXStack[i][j][p]
//			
//			V_FitError=0
//			CurveFit /Q/N/NTHR=0 gauss  pspectrum[gPMin,gPMax] /X=paxis
//			WAVE W_coef = W_coef
//			
//			if ((V_FitError == 0) && (V_FitQuitReason == 0))
//				offset = gPEnergy - W_coef[2]
//				
//				cStack[i][j][] 	= pspectrum[BinarySearchInterp(paxis,paxis[r]-offset)]
//			endif
//		endfor
//		UpdateProcessBar(i/NumX)
//	endfor
//	
//	CloseProcessBar()
//End


//	SubMenu "Calibrate Energy"
//		"Apply LLS E Correction"
//	End

// The Wavemetrics approach to creating threads:
//	gMT 	= ThreadGroupCreate(nthreads)
//	for (j=Y1;j<Y2;j+=1)
//		for (n=0;n<nThreads;n+=1)
//			
//			WAVE Cfs 	= $("root:SPHINX:Stacks:cfs_"+num2str(n))
//			WAVE Err 	= $("root:SPHINX:Stacks:err_"+num2str(n))
//			
//			ThreadStart gMT,n,FitEnergyOffset(SPHINXStack,cStack,PAxis,Cfs,Err,POffsets,PErrors,X1,X2,Y1,j,gPMin,gPMax,gPEnergy)
//			
//			j+=1
//			if( j >= NumX)
//				break
//			endif
//			
//			UpdateProcessBar((j-Y1)/(Y2-Y1))
//		endfor
//		
//			do
//				tIdx= ThreadGroupWait(gMT,10)
//			while(tIdx != 0 )
//			
//	endfor
//	tgOK 	= ThreadGroupRelease(gMT)