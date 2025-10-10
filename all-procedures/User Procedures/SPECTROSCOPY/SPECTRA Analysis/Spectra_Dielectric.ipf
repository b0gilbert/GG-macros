#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Function DeltaG_from_K(KK,TT)
	Variable KK, TT
	
	// convert from j/mol to kJ/mol
	
	return -0.001*cR*TT * ln(KK)
End



// Enter Zib and calculate K
Function HMTHydration()
	Variable Zib



End


// Vekilov plot
Function Vekilov(TK,DH,DS)
	Variable TK, DH, DS
	
	// Convert DH from kJ/mol to J/mol
	Variable DHJ 	= DH * 1000
	Variable DSJ 	= DS * 1000
	
	Variable Bckt = (1/cR)*(DHJ/TK - DSJ)
	
	return exp(Bckt)
End
// Use the Ivanov DH(T) and fit DS(T) required to match DG
Function ThermoDGFit(w,Temp) : FitFunc
	Wave w
	Variable Temp

	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(Temp) = a + b*(Temp - theta) + c*(Temp - theta)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ Temp
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = aS
	//CurveFitDialog/ w[1] = bS
	//CurveFitDialog/ w[2] = cS
	//CurveFitDialog/ w[3] = theta
	
	Variable a = -21
	Variable b = -0.0017
	Variable c = 0.00073
	Variable theta = 273.15
	Variable DH = a + b*(Temp - theta) + c*(Temp - theta)^2
	
	Variable thetaS = 273.15
	Variable DS = w[0] + w[1]*(Temp - thetaS) + w[2]*(Temp - thetaS)^2
	
	return DH - Temp*DS
End
Function HMT_DH(Temp,a,b,c)
	Variable Temp, a, b, c
	return a + b*(Temp - 273.15) + c*(Temp - 273.15)^2
End
Function HMT_DS(Temp,a,b,c)
	Variable Temp, a, b, c
	return a + b*(Temp ) + c*(Temp )^2
End
Function ThermoDHFit(w,Temp) : FitFunc
	Wave w
	Variable Temp

	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(Temp) = a + b*(Temp - theta) + c*(Temp - theta)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ Temp
	//CurveFitDialog/ Coefficients 4
	//CurveFitDialog/ w[0] = a
	//CurveFitDialog/ w[1] = b
	//CurveFitDialog/ w[2] = c
	//CurveFitDialog/ w[3] = theta

	return w[0] + w[1]*(Temp - w[3]) + w[2]*(Temp - w[3])^2
End
Function VekilovFit(w,Temp) : FitFunc
	Wave w
	Variable Temp

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(Temp) = Const*exp(tau/(To-Temp))
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ Temp
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = DH
	//CurveFitDialog/ w[1] = DS

	return exp((1000/cR) * (w[0]/Temp - w[1]))
End

// Bandura and Lvov. Eqn 39 and Table 2
// D = mass density g cm-3
// M = molar mass g mol-1
// Calculates pKw negative decimal logarithm of the ionization constant, Kw.

Function WaterpKw(T,D)
	Variable T, D

	Variable n 	= 6
	Variable Mw 	= 18.01528		// g mol-1
	
	Variable a0	= -0.864671
	Variable a1	= 8659.19		// K
	Variable a2	= -22786.2		// (g cm-3)-2/3 K2
	Variable b0	= 0.642044
	Variable b1	= -56.8534
	Variable b2	= -0.375754
	Variable c0 	= 0.61415
	Variable c1 	= 48251.33
	Variable c2 	= 67707.93
	Variable c3 	= 10102100
	
	Variable Y = D*(b0 + b1/T + b2*D)
	
	Variable Z = D*exp(a0 + a1/T + (a2*D^(2/3))/T^2)
	
	Variable pKwG 	= c0 + c1/T - c2/T^2 + c3/T^3
	
	Variable Bkt1 	= log(1+Z) - (Z/(Z+1))*Y
	
	Variable pKw 	= -2*n*Bkt1 + pKwG + 2*log(Mw/1000)
	
	return pKw
End

Function /C DebyeRelaxTemp(w,T)
	Variable w,T

	Variable a1 	= 87.9		//
	Variable b1 	= 0.404		// K-1
	Variable c1 	= 9.59e-4	// K-2
	Variable d1 	= 1.33e-6	// K-3
	Variable a2 	= 80.7	// 
	Variable b2 	= 4.42e-3	// K-1
	Variable c2 	= 1.37e-13	// s
	Variable d2 	= 651			// ûC
	Variable To 	= 133			// ûC

	Variable e0 	= a1 - b1*T + c1*T^2 - d1*T^3
	
	Variable eInf	= e0 - a2*exp(-b2*T)
	
	Variable tau 	= c2 * exp(d2/(T+To))
	
	Variable /C debye = eInf + (e0 - eInf)/cmplx(1,-1*w*tau)
	
//	return debye
	return eInf
End

Function DebyeTauTemp(T)
	Variable T
	
	Variable c2 	= 1.37e-13	// s
	Variable d2 	= 651			// ûC
	Variable To 	= 133			// ûC
	
	return 1e12*c2 * exp(d2/(T+To))
End

// Solubility of HMT in Mole Fraction from Wang et al. 
// Modified Apelblat. Enter T in ûC
Function HMT(T)
	Variable T
	Variable TK 	= T + 273.15
	Variable A 	= -140.855
	Variable B 	= 6771.449
	Variable C 	= 20.341
	
	Variable LnX = A + (B/TK) + C*ln(TK)
	
	return exp(LnX)
End

// Assume mTOT = 1000g
Function WgtFn2MoleFn(Pct,FWSolute)
	Variable Pct, FWSolute
	
	Variable WgtFn 			= Pct/100
	Variable MassSolute 	= WgtFn * 1000
	Variable MassWater 	= (1 - WgtFn) * 1000
	
	Variable MolesSolute 	= MassSolute/FWSolute
	
	Variable FWWater 		= 18
	Variable MolesWater = MassWater/FWwater
	
	return MolesSolute/(MolesSolute+MolesWater)
End

// Standard state is 1 mole / kg solution
Function MoleFn2StdStateFn(MoleFn,FWSolute,FWwater)
	Variable MoleFn, FWSolute, FWwater
	
	Variable MassSolution = MoleFn*FWSolute + (1-MoleFn)*FWwater
	
	return MoleFn * (1000 / MassSolution)	 // The number of moles in 1000 g = 1 kg
End

// *************************************************************
// ****		TAB 8:	Dielectric properties
// *************************************************************


//Function /T LoadSpeagFile(FileName,SampleName)
//	String FileName,SampleName
//	
//	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
//	String PathAndFileName = gPath2Data + FileName
//	
//	String LoadNames
//	
//	
//	
//End



Function /T LoadS11File(FileName,SampleName)
	String FileName,SampleName
	
	SVAR gPath2Data 			= root:SPECTRA:GLOBALS:gPath2Data
	String PathAndFileName = gPath2Data + FileName
	
	String LoadNames
	Variable NumCols, NCmplxPts, Zo=50, A2R = pi/180
		
	LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",0,0,2)
//	LoadNames 	= TrytoLoadSingleTextFile(PathAndFileName,"wave",NHeaderLines,NFileLines,2)

	NumCols 	= ItemsInList(LoadNames)
	if (NumCols == 0)
		Print " *** Cannot find the end of the header lines and the start of the data."
		return ""
	elseif (NumCols < 3)
		Print " *** The chosen file",FileName,"contains too few columns (",NumCols,")"
		return ""
	endif

	// Assume that the Axis is the first column
	WAVE Axis 		= $(StringFromList(0, LoadNames))
	WAVE Mag 		= $(StringFromList(1, LoadNames))
	WAVE Angle		= $(StringFromList(2, LoadNames))
	NCmplxPts 		= Dimsize(Axis,0)
	
	Duplicate /O Axis, $(SampleName+"_axis")
	
	Make /O/D/C/N=(NCmplxPts) $(SampleName+"_data") /WAVE=S11Complex
	
	// Convert from {mag,angle} to {real,imag}
	Make /O/FREE/N=(NCmplxPts) S11Real, S11Imag
	
	S11Real[] 	= (Zo * (1-Mag[p]^2))  /  1 + Mag[p]^2  -  2*Mag[p]*cos(Angle[p]*A2R)
	S11Imag[] 	= (Zo * 2*Mag[p]*sin(Angle[p]*A2R))  /  1 + Mag[p]^2  -  2*Mag[p]*cos(Angle[p]*A2R)
	
	S11Complex = Cmplx(S11Real,S11Imag)

	// Record the full original filename as a wave note. 
	Note /K S11Complex, FileName
	Note S11Complex, gPath2Data
	GetFileFolderInfo /Z/Q PathAndFileName
	Note S11Complex, "CreationDate="+Secs2Date(V_creationDate,-2)+";"
	Note /NOCR S11Complex, "CreationTime="+Secs2Time(V_creationDate,3)+";"
	Note S11Complex, "Data type=Complex\r"
	
	KillWavesFromList(LoadNames,1)

	return SampleName
End

Function AppendPlotBDSControls(WindowName)
	String WindowName
	
	String PlotFolderName 	= "root:SPECTRA:Plotting:"+WindowName
	String FTIRFolderName 	= "root:SPECTRA:Plotting:Dielectric"
	
	TitleBox BDSInstruction1 title="Choose #1 S11(dB) and #2 Angle (deg)",pos={103,121},frame=0,fSize=13,fColor=(1,4,52428), disable=1
	
	Button BDSButton1,pos={462,120},size={100,18},proc=BDSButtonProcs,title="S11 to Cmplx", disable=1
	
	
//	Button T70KeepQButton,pos={570,120},size={60,18},proc=CalculateQButtonProc,title="Keep", disable=1
End

Function BDSButtonProcs(B_Struct)
	STRUCT WMButtonAction &B_Struct
	
	String ctrlName 			= B_Struct.ctrlName
	String PlotName 			= B_Struct.win
	Variable eventCode 			= B_Struct.eventCode
	Variable eventMod 			= B_Struct.eventMod
	
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	String PlotFolderName 		= "root:SPECTRA:Plotting:" + PlotName
	
	SVAR gSelection1 			= $(PlotFolderName+":gSelection1")
	SVAR gSelection2 			= $(PlotFolderName+":gSelection2")
		
	if (cmpstr(ctrlname,"BDSButton1")==0)
		Make /O/D/C/N=(DimSize(TraceNameToWaveRef(PlotName,gSelection1),0)) RectComplex
		UserPolarToRect(XWaveRefFromTrace(PlotName,gSelection1),TraceNameToWaveRef(PlotName,gSelection1),TraceNameToWaveRef(PlotName,gSelection2),RectComplex)
	else
	
	endif
	
End

// Convert from Magnitude - Angle into Real - Imaginary
// The Wavemetrics function p2rect() seems to be limited to ±¹ 
 
Function UserPolarToRect(Freq,Mag,Ang,RectCmplx)
	Wave Freq,Mag,Ang
	Wave /C RectCmplx
	
	Variable NPts = DimSize(Freq,0), Zo=50, Denom
	Variable A2R = pi/180
	
	Make /O/FREE/N=(NPts) TempReal, TempImag
	
//	Denom 		= 1 + Mag^2  -  2*Mag*cos(Ang*A2R)
//	TempReal 	= (Zo * (1-Mag^2))  /  Denom
//	TempImag 	= (Zo * 2*Mag*sin(Ang*A2R))  /  Denom
	
	TempReal 	= (Zo * (1-Mag^2))  /  (1 + Mag^2  -  2*Mag*cos(Ang*A2R))
	TempImag 	= (Zo * 2*Mag*sin(Ang*A2R))  /  (1 + Mag^2  -  2*Mag*cos(Ang*A2R))
	
	RectCmplx = Cmplx(TempReal,TempImag)
	
End