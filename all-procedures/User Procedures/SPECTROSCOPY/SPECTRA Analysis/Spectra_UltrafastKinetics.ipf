#pragma rtGlobals=1		// Use modern global access method.


//Function FirstOrderKinetics(w,t) :FitFunc
//	Wave w
//	Variable t
//	
//	Variable k = w[3]
//	
//	Variable dt = w[4]
//	
//	Variable alpha = 1 - exp(-k*(t-w[4]))
//	
////	return alpha * (w[1] - w[0]) + w[0]
//	return w[0] + w[1]*alpha
//End



// This is the index in MnO2Params where the rate constants start. 
Constant KTPointer 	= 6	// 3x the number of wavelengths 
// This is the index in DyeNPParams where the rate constants start. 
Constant KKPointer 	= 3
// Should the S1 excited state contribute to the ESA?? This is tricky for the TcBi
//Constant ESAS0Scale = 1	// This is for dMnO2 and cdisBi
//Constant ESAS0Scale = 0.6	// This is for Tc Bi
Constant ESAS0Scale = 0.4	// This is for KBi


Function FitMnO2Decays()

	// This wave holds the rate constants
	Make /O/D/N=(6) MnO2Rates
	// These are all the coefficients to be fitted -- intensity amplitudes and rate constants. 
	Make /O/D/N=(12) MnO2Params, MnO2Sigmas, MnO2Hold
	Make /O/T/N=(12) MnO2Legend
	FillMnO2Legend(MnO2Legend)
	
	// User input of initial rate constants AND fit range
	Variable TrialFlag = 1, FitTMin, FitTMax, X2
	if (InputMnO2RateConstants(TrialFlag, FitTMin, FitTMax, MnO2Rates) == 0)
		return 0
	endif
	// ... and write these to the full coefficients wave
	MnO2Params[KTPointer,] 	= MnO2Rates[p - KTPointer]
	
	// The first-order rate constants
	NVAR gK1				= gK1		// Rate of recombination from S1 to S0
	NVAR gKT1				= gKT1	// Rate of transfer from S1 to S2
	NVAR gKT2				= gKT2	// Rate of transfer from S1 to S3
	NVAR gK2				= gK2		// Rate of recombination from S2 and S3 to S0
	NVAR gKT3				= gKT3	// Rate of  transfer from S3 to S4
	NVAR gK3				= gK3	 	// Rate of transfer from S4 to S0
	
	// Hardwire wave references to data location. ASSUME IDENTICAL TIME AXES
	WAVE MnO2_360 		=   root:KBi_359p81_data
	WAVE MnO2_360_ax	=   root:KBi_359p81_axis
	WAVE MnO2_575 		=   root:KBi_574p81_data
	WAVE MnO2_575_ax	=   root:KBi_574p81_axis
	if (WaveExists(MnO2_360)==0)
		WAVE MnO2_360 		=   root:TcBi_359p81_data
		WAVE MnO2_360_ax	=   root:TcBi_359p81_axis
		WAVE MnO2_575 		=   root:TcBi_574p81_data
		WAVE MnO2_575_ax	=   root:TcBi_574p81_axis
	endif
	if (WaveExists(MnO2_360)==0)
		WAVE MnO2_360 		=   root:NadMnO2_359p81_data
		WAVE MnO2_360_ax	=   root:NadMnO2_359p81_axis
		WAVE MnO2_575 		=   root:NadMnO2_574p81_data
		WAVE MnO2_575_ax	=   root:NadMnO2_574p81_axis
	endif
	if (WaveExists(MnO2_360)==0)
		WAVE MnO2_360 		=   root:cDis_360p11_data
		WAVE MnO2_360_ax	=   root:cDis_360p11_axis
		WAVE MnO2_575 		=   root:cDis_575p14_data
		WAVE MnO2_575_ax	=   root:cDis_575p14_axis
	endif
	if (WaveExists(MnO2_360)==0)
		return 0
	endif
	
	Variable TimeOffset 		= -1.00	// <--- Extra time offset - set to zero for debugging
	Variable TimeOffset360 	= 0.00	// <--- Extra chirp correction for the 490 nm data
	
	// 		
	FindLevel /P/Q MnO2_360_ax, FitTMin
	if (V_levelX < 0)
		return 0
	endif
	Variable TPtMin 	= trunc(V_levelX)
	
	FindLevel /P/Q MnO2_360_ax, FitTMax
	if (V_levelX < 0)
		return 0
	endif
	Variable TPtMax 	= trunc(V_levelX)
	
	FitTMin = MnO2_360_ax[TPtMin]
	FitTMax = MnO2_360_ax[TPtMax]
	Variable /G gMnO2NPts = TPtMax - TPtMin + 1
	
	// The Time Axis and a data axis to allow time-shifting via interpolation. 
	Make /O/D/N=(gMnO2NPts) TimeAxis, TAData
	TimeAxis[] = MnO2_360_ax[TPtMin+p]
	TimeAxis += TimeOffset
	
	// 2D Matrix of the State Kinetics
	Make /D/O/N=(gMnO2NPts,5) MnO2StatesMatrix
	SetDimLabel 1,0,$"S0",MnO2StatesMatrix				// So, Ground state
	SetDimLabel 1,1,$"S1",MnO2StatesMatrix				// S1, Fast decaying state
	SetDimLabel 1,2,$"S2",MnO2StatesMatrix				// S2, Slow decaying state that cannot lose an electron
	SetDimLabel 1,3,$"S3",MnO2StatesMatrix				// S3, Slow decaying state that can lose and electron
	SetDimLabel 1,4,$"S4",MnO2StatesMatrix				// S4, "free electron" state
	
	// 2D Matrix for data and calculation
	Make /O/D/N=(gMnO2NPts,2) MnO2SignalsData=0		// <-- This holds the EXPERIMENTAL TA traces
	Make /O/D/N=(gMnO2NPts,2) MnO2SignalsCalc=0			// <-- This hold the CALCULATED TA traces
	MnO2SignalsData[][0] 	= MnO2_360[TPtMin+p]			// The Bleach-dominated signal
	MnO2SignalsData[][1] 	= MnO2_575[TPtMin+p]			// The ESA-dominated signal
	
	// 1D Concatenated data and calculation
	Make /O/D/N=(2*gMnO2NPts) MnO2Data1D, MnO2Calc1D, MnO2Time1D
	MnO2Data1D[0,gMnO2NPts-1] 	= MnO2_360[TPtMin+p]
	MnO2Data1D[gMnO2NPts,] 		= MnO2_575[TPtMin+p-gMnO2NPts]
	
	MnO2Time1D[0,gMnO2NPts-1] 	= TimeAxis[p]
	MnO2Time1D[gMnO2NPts,] 		= TimeAxis[p-gMnO2NPts]

	// Perhaps Interpolation is useful. 
//	TimeAxis += TimeOffset360			// <---- Extra chirp correction for the 360 nm data
//	Interpolate2 /T=1/I=3/X=TimeAxis/Y=TAData MnO2_360_ax, MnO2_360
//	MnO2SignalsData[][0] 	= MnO2_360[TPtMin+p]
//	TimeAxis -= TimeOffset360			// <---- Undo the chirp correction
//	Interpolate2 /T=1/I=3/X=TimeAxis/Y=TAData MnO2_575_ax, MnO2_575
//	MnO2SignalsData[][1] 	= MnO2_575[TPtMin+p]
	
	// 1D Trace for FITS
	Make /O/D/N=(gMnO2NPts) MnO2Single
	
	PauseUpdate 
	if (TrialFlag == 1)
		Variable Choice=2
		if (Choice==1)
			MnO2KineticsTrial(MnO2Params,MnO2SignalsCalc)
			X2 = Calculate2DChi2(MnO2SignalsData,MnO2SignalsCalc)
			Print " 		Trial chi-squared is",X2,". 		The time offset is",TimeOffset,"ps. 	The So ESA scale factor is",ESAS0Scale
		else
			MnO2KineticsFitFn(MnO2Params,MnO2Calc1D,MnO2Time1D)
			Signal2DFrom1D(MnO2SignalsCalc,MnO2Calc1D,gMnO2NPts)
			X2 = Calculate1DChi2(MnO2Data1D, MnO2Calc1D)
			Print " 		Trial chi-squared is",X2,". 		The time offset is",TimeOffset,"ps. 	The So ESA scale factor is",ESAS0Scale
		endif
	else
		// MnO2ParamsTable()
		String HoldString 	= MakeHoldString(MnO2Hold)
		Duplicate /O MnO2Params, MnO2ParamsSave
		
		Variable FitType=2
		if (FitType == 1)
			// Fit the data using the Multivariate approach
			FuncFitMD /Q/W=2/N=1/H=HoldString MnO2KineticsFitFnMD, MnO2Params, MnO2SignalsData /D
						
		elseif (FitType == 2)
				
			FuncFit /Q/W=0/N/H=HoldString MnO2KineticsFitFn MnO2Params MnO2Data1D /X=MnO2Time1D
			
		elseif (FitType == 3)
		endif
		
		WAVE W_sigma = W_sigma
		MnO2Sigmas[] = NsigDig(2,W_sigma[p])
		
		MnO2KineticsTrial(MnO2Params,MnO2SignalsCalc)
		X2 = Calculate2DChi2(MnO2SignalsData,MnO2SignalsCalc)
		Print " 		Fit chi-squared is",V_chisq," {",X2,"}. 		The time offset is",TimeOffset,"ps"
		
		// Update the rates
		MnO2Params[] = abs(MnO2Params[p])
		MnO2Params[] 	= NsigDig(3,MnO2Params[p])
		MnO2Rates[] = MnO2Params[KTPointer+p]		
		gK1 	= MnO2Rates[0]
		gKT1 	= MnO2Rates[1]
		gKT2 	= MnO2Rates[2]
		gK2 	= MnO2Rates[3]
		gKT3 	= MnO2Rates[4]
		gK3 	= MnO2Rates[5]
	endif
	ResumeUpdate
End

Function NsigDig(N,Number)
	Variable N, Number
	
	String Short
	sprintf Short, "%0."+Num2Str(N)+"g", Number
	
	return Str2Num(Short)
End

// *******************************************************************************************
// ****		Routine for TRIAL calculations using 2D State and Signal arrays. This Works
// *******************************************************************************************
Function MnO2KineticsTrial(Params,Signals2D)	
	Wave Params,Signals2D
	
	// First numerically calculate the kinetics in the State occupations. 
	WAVE States2D 		= MnO2StatesMatrix
	CalculateMnO2States(Params,States2D)
	
	// Then calculate the Signals 
	CalculateMnO2Signals2D(Params,States2D,Signals2D)
End

// *******************************************************************************************
// ****		Routine for FITTING using FuncFit
// *******************************************************************************************
Function MnO2KineticsFitFn(w, ywv, xwv) : FitFunc
	Wave w, ywv, xwv
	
	// First numerically calculate the kinetics in the State occupations. 
	WAVE States2D 		= MnO2StatesMatrix
	CalculateMnO2States(w,States2D)
	
	// Then calculate the Signals 
	CalculateMnO2Signals1D(w,States2D,ywv)
End



// *******************************************************************************************
// ****		Convert the 2D states matrix to the 1D signals traces
// *******************************************************************************************
Function CalculateMnO2Signals1D(Params,States2D,Signals1D)
	Wave Params, States2D, Signals1D
	
	NVAR gNP 		= gMnO2NPts
	
	Variable ESACoef 	= Params[0]/1000
	Variable GSBCoef 	= Params[1]/1000
	
	Variable e_L1 		= Params[2]
	Variable e_L2 		= Params[3]
	Variable b_L1 		= Params[4]
	Variable b_L2 		= Params[5]
	
	WAVE Signal 	= MnO2Single

								   // Only S1 in ESA																						S1 and S2 in GSB
	Signals1D[0,gNP-1] 	= ESACoef*e_L1*(ESAS0Scale*States2D[p][1] 		+ States2D[p][2] 			+ States2D[p][3]) 		- GSBCoef*b_L1*(States2D[p][1] + States2D[p][2] + States2D[p][3] + States2D[p][4])
	Signals1D[gNP,] 		= ESACoef*e_L2*(ESAS0Scale*States2D[p-gNP][1] 	+ States2D[p-gNP][2] 	+ States2D[p-gNP][3]) 	- GSBCoef*b_L2*(States2D[p-gNP][1] + States2D[p-gNP][2] + States2D[p-gNP][3] + States2D[p-gNP][4])
End

Function CalculateMnO2Signals2D(Params,States2D,Signals2D)
	Wave Params, States2D, Signals2D
	
	Variable ESACoef 	= Params[0]/1000
	Variable GSBCoef 	= Params[1]/1000
	
	Variable e_L1 		= Params[2]
	Variable e_L2 		= Params[3]
	Variable b_L1 		= Params[4]
	Variable b_L2 		= Params[5]

	//						Only S1 in ESA								S1 and S2 in GSB
	Signals2D[][0] 	= ESACoef*e_L1*(ESAS0Scale*States2D[p][1] + States2D[p][2] + States2D[p][3]) - GSBCoef*b_L1*(States2D[p][1] + States2D[p][2] + States2D[p][3] + States2D[p][4])
	Signals2D[][1] 	= ESACoef*e_L2*(ESAS0Scale*States2D[p][1] + States2D[p][2] + States2D[p][3]) - GSBCoef*b_L2*(States2D[p][1] + States2D[p][2] + States2D[p][3] + States2D[p][4])
End

Function Signal2DFrom1D(Signal2D,Signal1D,NPts)
	Wave Signal2D,Signal1D
	Variable NPts
	
	Signal2D[0,NPts-1][0] 	= Signal1D[p]
	Signal2D[0,NPts-1][1] 	= Signal1D[NPts+ p]
	
End

// *******************************************************************************************
// ****		Routine for FITTING FuncFitMD 
// *******************************************************************************************
//Function MnO2KineticsFitFnMD(Params,Data1D,xw,yw) : FitFunc	
//	Wave Params,Data1D,xw,yw
//	
//	// First numerically calculate the kinetics in the State occupations. Same as for Trials
//	WAVE States2D 		= MnO2StatesMatrix
//	CalculateMnO2States(Params,States2D)
//	
//	// Then calculate the Signals 
//	CalculateMnO2Signals(Params,States2D,Data1D)
//End

Function Calculate2DChi2(Data2D,Fit2D)
	Wave Data2D, Fit2D
	
	MatrixOp /FREE X22D = magSqr(Data2D - Fit2D)
	Make /FREE X21D
	SumDimension /DEST=X21D X22D
	
	return sum(X21D)
End
Function Calculate1DChi2(Data1D,Fit1D)
	Wave Data1D, Fit1D
	
	MatrixOp /FREE X21D = magSqr(Data1D - Fit1D)
	
	return sum(X21D)
End

// *******************************************************************************************
// ****		Differential equations describing MnO2 excitation decay kinetics
// *******************************************************************************************
Function CalculateMnO2States(Params,States2D)
	Wave Params, States2D
	
	WAVE RateConstants 		= MnO2Rates
	WAVE MnO2TimeAxis 	= TimeAxis
	
	// Set the initial conditions
	States2D 			= 0
	States2D[0][1] 	= 1	// Populate S1, the fast decaying state
	
	RateConstants[] 		= Params[KTPointer+p]
	
	// Calculate the S(t) curves
	IntegrateODE/M=1 /X=MnO2TimeAxis MnO2_dSdt, RateConstants, States2D
End

Function MnO2_dSdt(pw, tt, yw, dydt)
	Wave pw		// Parameters
	Variable tt	// time value at which to calculate derivatives
	Wave yw		// yw[0]-yw[3] containing concentrations of A,B,C,D
	Wave dydt	// wave to receive dA/dt, dB/dt etc. (output)
	
	// The states
	// yw[0]  	State So
	// yw[1]  	State S1
	// yw[2]  	State S2
	// yw[3]  	State S3
	// yw[4]  	State S4
	
	Variable S0 	= yw[0]
	Variable S1 	= yw[1]
	Variable S2 	= yw[2]
	Variable S3 	= yw[3]
	Variable S4 	= yw[4]
	
	// The first-order rate constants
	// pw[0] 	K1 	Rate of recombination from S1 to S0
	// pw[1]		T1 	Rate of transfer from S1 to S2
	// pw[2]		T2		Rate of transfer from S1 to S3
	// pw[3]		K2 	Rate of recombination from S2 and S3 to S0
	// pw[4]		T3		Rate of transfer from S3 to S4
	// pw[5]		K3 	Rate of recombination from S4 to S0
	
	Variable K1 	= abs(pw[0])
	Variable T1 	= abs(pw[1])
	Variable T2 	= abs(pw[2])
	Variable K2 	= abs(pw[3])
	Variable T3 	= abs(pw[4])
	Variable K3 	= abs(pw[5])
	
	// Change in S0 concentration
	dydt[0] = K1*S1 + K2*S2 + K2*S3 + K3*S4
	
	// Change in S1 concentration
	dydt[1] = -K1*S1 - T1*S1 - T2*S1
	
	// Change in S2 concentration
	dydt[2] = T1*S1 - K2*S2
	
	// Change in S3 concentration
	dydt[3] = T2*S1 - K2*S3 - T3*S3
	
	// Change in S4 concentration
	dydt[4] = T3*S3 - K3*S4

	return 0
End

//	// Change in S0 concentration
//	dydt[0] = K1*yw[1] + K2*yw[2] + K2*yw[3] + K3*yw[4]
//	
//	// Change in S1 concentration
//	dydt[1] = -K1*yw[1] - T1*yw[1] - T2*yw[1]
//	
//	// Change in S2 concentration
//	dydt[2] = T1*yw[1] - K2*yw[2]
//	
//	// Change in S3 concentration
//	dydt[3] = T2*yw[1] - K2*yw[3] - T3*yw[3]
//	
//	// Change in S4 concentration
//	dydt[4] = T3*yw[3] - K3*yw[4]

Function FillMnO2Legend(MnO2Legend)
	WAVE /T MnO2Legend

	MnO2Legend[0] = "ESA scale"
	MnO2Legend[1] = "GSB scale"
	MnO2Legend[2] = "e{360}"
	MnO2Legend[3] = "e{575}"
	MnO2Legend[4] = "b{360}"
	MnO2Legend[5] = "b{575}"
	MnO2Legend[6] = "Recombination from S1 to S0"
	MnO2Legend[7] = "Transfer from S1 to S2"
	MnO2Legend[8] = "Transfer from S1 to S3"
	MnO2Legend[9] = "Recombination S2 & S3 to S0"
	MnO2Legend[10] = "Transfer from S3 to S4"
	MnO2Legend[11] = "Recombination from S4 to S0"
	
End

	




	// pw[0] 	K1 	Rate of recombination from S1 to S0
	// pw[1]		T1 	Rate of transfer from S1 to S2
	// pw[2]		T2		Rate of transfer from S1 to S3
	// pw[3]		K2 	Rate of recombination from S2 and S3 to S0
	// pw[4]		T3		Rate of transfer from S3 to S4
	// pw[5]		K3 	Rate of recombination from S4 to S0

Function InputMnO2RateConstants(FitFlag,FitMinT,FitMaxT,MnO2Rates)
	Variable &FitFlag, &FitMinT, &FitMaxT
	Wave MnO2Rates

	Variable /G gK1, gK2, gK3 
	Variable /G gKT1, gKT2, gKT3
	Variable /G gFitFlag, gFitMinT, gFitMaxT
	
	Variable K1=gK1, K2=gK2, K3=gK3 
	Variable KT1=gKT1, KT2=gKT2, KT3=gKT3, tFitFlag=gFitFlag
	Variable tFitMinT=gFitMinT, tFitMaxT=gFitMaxT
	
	WAVE MnO2Params = MnO2Params
	if (1 && WaveExists(MnO2Params))		
		K1  	= MnO2Params[KTPointer + 0] 
		KT1 	= MnO2Params[KTPointer + 1] 
		KT2 	= MnO2Params[KTPointer + 2] 
		K2 	= MnO2Params[KTPointer + 3] 
		KT3 	= MnO2Params[KTPointer + 4] 
		K3 	= MnO2Params[KTPointer + 5] 
	endif
		
	Prompt tFitFlag, "Trial or fit?", popup, "trial;fit;"
	Prompt tFitMinT, "fit start time"
	Prompt tFitMaxT, "fit end time"
	Prompt K1, "Recombination from S1 to S0"
	Prompt KT1, "Electron transfer from S1 to S2"
	Prompt KT2, "Electron transfer from S1 to S3"
	Prompt K2, "Recombination from S2 & S3 to S0"
	Prompt KT3, "Electron transfer from S3 to S4"
	Prompt K3, "Recombination from S4 to S0"
	DoPrompt "Enter rate constants", tFitFlag, tFitMinT, tFitMaxT, K1, KT1, KT2, K2, KT3, K3
	if (V_flag)
		return 0
	endif
	
	FitFlag 	= tFitFlag
	gFitFlag 	= tFitFlag
	FitMinT 	= tFitMinT
	gFitMinT 	= tFitMinT
	FitMaxT 	= tFitMaxT
	gFitMaxT = tFitMaxT
	
	gK1 	= K1
	gKT1 	= KT1
	gKT2 	= KT2
	gK2 	= K2
	gKT3 	= KT3
	gK3 	= K3
	
	MnO2Rates[0] 	= K1
	MnO2Rates[1] 	= KT1
	MnO2Rates[2] 	= KT2
	MnO2Rates[3] 	= K2
	MnO2Rates[4] 	= KT3
	MnO2Rates[5] 	= K3
End


	// Relative intensity coefficients, used to convert the concentration of a species {So, ...} into the signal at a give wavelength. 
//	Variable /G e_360 = 0.10, e_575 = 0.50	// "e" coefficients represent the contributions from the MnO2 excited state
//	Variable /G a_360 = 1.25, a_575 = 0.25	// "a" coefficents represent the contributions from the MnO2 bleach
//	Make /O/D/N=2 WavelengthAxis={360,575}	// The wavelength axis (dummy)
	
//Function MnO2_dSdt(pw, tt, yw, dydt)
//	Wave pw		// Parameters
//	Variable tt	// time value at which to calculate derivatives
//	Wave yw		// yw[0]-yw[3] containing concentrations of A,B,C,D
//	Wave dydt	// wave to receive dA/dt, dB/dt etc. (output)
//	
//	// The states
//	// yw[0]  	State So
//	// yw[1]  	State S1
//	// yw[2]  	State S2
//	// yw[3]  	State S3
//	
//	// The first-order rate constants
//	// pw[0] 	Rate of recombination from S1 to S0
//	// pw[1]		Rate of transfer from S1 to S2
//	// pw[2]		Rate of recombination from S2 to S0
//	// pw[3]		Rate of electron transfer from S2 to S3
//	// pw[4]		Rate of recombination from S3 to S0
//	
//	// Change in S0 concentration
//	dydt[0] = pw[0]*yw[1] + pw[2]*yw[2] + pw[4]*yw[3]
//	
//	// Change in S1 concentration
//	dydt[1] = -pw[0]*yw[1] - pw[1]*yw[1]
//	
//	// Change in S2 concentration
//	dydt[2] = pw[1]*yw[1] - pw[2]*yw[2] - pw[3]*yw[2]
//	
//	// Change in S3 concentration
//	dydt[3] = pw[3]*yw[2] - pw[4]*yw[3]
//
//	return 0
//End


//Function InputMnO2RateConstants(FitFlag,FitMinT,FitMaxT,MnO2Rates)
//	Variable &FitFlag, &FitMinT, &FitMaxT
//	Wave MnO2Rates
//
//	Variable /G gK1, gK2, gKE, gFitFlag, gFitMinT, gFitMaxT
//	Variable K1=gK1, K2=gK2, KE=gKE, tFitFlag=gFitFlag
//	Variable tFitMinT=gFitMinT, tFitMaxT=gFitMaxT
//		
//	Prompt tFitFlag, "Trial or fit?", popup, "trial;fit;"
//	Prompt tFitMinT, "fit start time"
//	Prompt tFitMaxT, "fit end time"
//	Prompt K1, "Recombination from S1 to S0"
//	Prompt K2, "Recombination from S2 to S0"
//	Prompt KE, "Electron transfer from S1 to S2"
//	DoPrompt "Enter rate constants", tFitFlag, tFitMinT, tFitMaxT, K1, K2, KE
//	if (V_flag)
//		return 0
//	endif
//	
//	FitFlag 	= tFitFlag
//	gFitFlag 	= tFitFlag
//	FitMinT 	= tFitMinT
//	gFitMinT 	= tFitMinT
//	FitMaxT 	= tFitMaxT
//	gFitMaxT = tFitMaxT
//	gK1 	= K1
//	gK2 	= K2
//	gKE 	= KE
//	
//	MnO2Rates[0] 	= K1
//	MnO2Rates[1] 	= K2
//	MnO2Rates[2] 	= KE
//End


//Function MnO2_dSdt(pw, tt, yw, dydt)
//	Wave pw		// Parameters
//	Variable tt	// time value at which to calculate derivatives
//	Wave yw		// yw[0]-yw[3] containing concentrations of A,B,C,D
//	Wave dydt	// wave to receive dA/dt, dB/dt etc. (output)
//	
//	
//	// Change in S0 concentration
//	dydt[0] = pw[0]*yw[1] + pw[1]*yw[2]
//	
//	// Change in S1 concentration
//	dydt[1] = -pw[0]*yw[1] - pw[2]*yw[1]
//	
//	// Change in S2 concentration
//	dydt[2] = pw[2]*yw[1] - pw[1]*yw[2]
//
//	return 0
//End

Window MnO2ParamsTable() : Table
	PauseUpdate; Silent 1		// building window...
	Edit/W=(53,599,580,977) MnO2Legend,MnO2Params,MnO2Sigmas,MnO2Hold
	ModifyTable format(Point)=1,width(MnO2Legend)=186
EndMacro

Window MnO2FitMacroLog() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(694,245,1780,1049)/R MnO2StatesMatrix[*][0] vs TimeAxis as "MnO2 Fitting on Log-Time"
	AppendToGraph/R MnO2StatesMatrix[*][1] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][2] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][3] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][4] vs TimeAxis
	AppendToGraph MnO2SignalsData[*][0] vs TimeAxis
	AppendToGraph MnO2SignalsCalc[*][0] vs TimeAxis
	AppendToGraph MnO2SignalsData[*][1] vs TimeAxis
	AppendToGraph MnO2SignalsCalc[*][1] vs TimeAxis
	ModifyGraph mode(MnO2StatesMatrix#1)=7,mode(MnO2StatesMatrix#4)=7,mode(MnO2SignalsData)=3
	ModifyGraph mode(MnO2SignalsData#1)=3
	ModifyGraph marker(MnO2SignalsData)=19,marker(MnO2SignalsData#1)=19
	ModifyGraph lSize(MnO2StatesMatrix)=4,lSize(MnO2StatesMatrix#1)=4,lSize(MnO2StatesMatrix#2)=4
	ModifyGraph lSize(MnO2StatesMatrix#3)=4,lSize(MnO2StatesMatrix#4)=4,lSize(MnO2SignalsCalc)=2
	ModifyGraph lSize(MnO2SignalsCalc#1)=2
	ModifyGraph lStyle(MnO2StatesMatrix)=11,lStyle(MnO2StatesMatrix#1)=11,lStyle(MnO2StatesMatrix#2)=11
	ModifyGraph lStyle(MnO2StatesMatrix#3)=11,lStyle(MnO2StatesMatrix#4)=11
	ModifyGraph rgb(MnO2StatesMatrix)=(52428,1,41942,32768),rgb(MnO2StatesMatrix#1)=(39321,1,1,32768)
	ModifyGraph rgb(MnO2StatesMatrix#2)=(1,52428,26586,32768),rgb(MnO2StatesMatrix#3)=(2,39321,1,32768)
	ModifyGraph rgb(MnO2StatesMatrix#4)=(1,52428,52428,32768),rgb(MnO2SignalsData)=(65535,0,0,16384)
	ModifyGraph rgb(MnO2SignalsCalc)=(0,0,0),rgb(MnO2SignalsData#1)=(0,0,65535,13107)
	ModifyGraph rgb(MnO2SignalsCalc#1)=(0,0,0)
	ModifyGraph msize(MnO2SignalsData)=6,msize(MnO2SignalsData#1)=6
	ModifyGraph mrkThick(MnO2SignalsData)=1,mrkThick(MnO2SignalsData#1)=1
	ModifyGraph hbFill(MnO2StatesMatrix#1)=5,hbFill(MnO2StatesMatrix#3)=5,hbFill(MnO2StatesMatrix#4)=5
	ModifyGraph hBarNegFill(MnO2StatesMatrix#3)=5
	ModifyGraph useMrkStrokeRGB(MnO2SignalsData)=1,useMrkStrokeRGB(MnO2SignalsData#1)=1
	ModifyGraph mrkStrokeRGB(MnO2SignalsData)=(52428,1,1),mrkStrokeRGB(MnO2SignalsData#1)=(0,0,65535)
	ModifyGraph log(bottom)=1
	ModifyGraph zero(left)=2
	ModifyGraph mirror(bottom)=2
	ModifyGraph fSize=24
	ModifyGraph lowTrip(left)=0.001
	ModifyGraph axThick=2
	ModifyGraph axisEnab(right)={0,0.33}
	Label right "\\Z32State Population"
	Label bottom "\\Z32Time (ps)"
	Label left "\\Z32ΔOD"
	SetAxis right 0,1
	SetAxis bottom 0.3,3100
	Legend/C/N=text0/J/F=0/A=MC/X=26.61/Y=33.43 "\\Z18\\s(MnO2StatesMatrix) So\r\\s(MnO2StatesMatrix#1) S1 1st excited state\r\\s(MnO2StatesMatrix#2) S2 Ground only"
	AppendText "\\s(MnO2StatesMatrix#3) S3 Ground + Free-e\r\\s(MnO2StatesMatrix#4) S4 free-e"
EndMacro

Window MnO2FitMacroLin2() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(1058,349,2144,1153)/R MnO2StatesMatrix[*][0] vs TimeAxis as "MnO2 Fitting on Log-Time"
	AppendToGraph/R MnO2StatesMatrix[*][1] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][2] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][3] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][4] vs TimeAxis
	AppendToGraph MnO2SignalsData[*][0] vs TimeAxis
	AppendToGraph MnO2SignalsCalc[*][0] vs TimeAxis
	AppendToGraph MnO2SignalsData[*][1] vs TimeAxis
	AppendToGraph MnO2SignalsCalc[*][1] vs TimeAxis
	ModifyGraph mode(MnO2StatesMatrix#1)=7,mode(MnO2StatesMatrix#3)=7,mode(MnO2StatesMatrix#4)=7
	ModifyGraph mode(MnO2SignalsData)=3,mode(MnO2SignalsData#1)=3
	ModifyGraph marker(MnO2SignalsData)=19,marker(MnO2SignalsData#1)=19
	ModifyGraph lSize(MnO2StatesMatrix)=3,lSize(MnO2StatesMatrix#1)=3,lSize(MnO2StatesMatrix#2)=3
	ModifyGraph lSize(MnO2StatesMatrix#3)=3,lSize(MnO2StatesMatrix#4)=3,lSize(MnO2SignalsCalc)=2
	ModifyGraph lSize(MnO2SignalsCalc#1)=2
	ModifyGraph lStyle(MnO2StatesMatrix)=11,lStyle(MnO2StatesMatrix#1)=11,lStyle(MnO2StatesMatrix#2)=11
	ModifyGraph lStyle(MnO2StatesMatrix#3)=11,lStyle(MnO2StatesMatrix#4)=11
	ModifyGraph rgb(MnO2StatesMatrix)=(52428,1,41942,32768),rgb(MnO2StatesMatrix#1)=(39321,1,1,32768)
	ModifyGraph rgb(MnO2StatesMatrix#2)=(1,39321,19939,32768),rgb(MnO2StatesMatrix#3)=(0,65535,0,32768)
	ModifyGraph rgb(MnO2StatesMatrix#4)=(1,52428,52428,32768),rgb(MnO2SignalsData)=(65535,0,0,16384)
	ModifyGraph rgb(MnO2SignalsCalc)=(0,0,0),rgb(MnO2SignalsData#1)=(0,0,65535,13107)
	ModifyGraph rgb(MnO2SignalsCalc#1)=(0,0,0)
	ModifyGraph msize(MnO2SignalsData)=6,msize(MnO2SignalsData#1)=6
	ModifyGraph mrkThick(MnO2SignalsData)=1,mrkThick(MnO2SignalsData#1)=1
	ModifyGraph hbFill(MnO2StatesMatrix#1)=5,hbFill(MnO2StatesMatrix#3)=5,hbFill(MnO2StatesMatrix#4)=5
	ModifyGraph hBarNegFill(MnO2StatesMatrix#3)=5
	ModifyGraph useMrkStrokeRGB(MnO2SignalsData)=1,useMrkStrokeRGB(MnO2SignalsData#1)=1
	ModifyGraph mrkStrokeRGB(MnO2SignalsData)=(52428,1,1),mrkStrokeRGB(MnO2SignalsData#1)=(0,0,65535)
	ModifyGraph zero(left)=2
	ModifyGraph mirror(bottom)=2
	ModifyGraph fSize=24
	ModifyGraph lowTrip(left)=0.001
	ModifyGraph axThick=2
	ModifyGraph axisEnab(right)={0,0.33}
	Label right "\\Z32State Population"
	Label bottom "\\Z32Time (ps)"
	Label left "\\Z32ΔOD"
	SetAxis right 0,1
	SetAxis bottom 0.3,3100
	Legend/C/N=text0/J/F=0/A=MC/X=-3.40/Y=34.02 "\\Z18\\s(MnO2StatesMatrix) So\r\\s(MnO2StatesMatrix#1) S1 1st excited state\r\\s(MnO2StatesMatrix#2) S2 Ground only"
	AppendText "\\s(MnO2StatesMatrix#3) S3 Ground + Free-e\r\\s(MnO2StatesMatrix#4) S4 free-e"
EndMacro


Window MnO2FitMacroLin() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(388,135,1655,561)/R MnO2StatesMatrix[*][0] vs TimeAxis as "MnO2 Fitting on Linear-Time"
	AppendToGraph/R MnO2StatesMatrix[*][1] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][2] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][3] vs TimeAxis
	AppendToGraph/R MnO2StatesMatrix[*][4] vs TimeAxis
	AppendToGraph MnO2SignalsData[*][0] vs TimeAxis
	AppendToGraph MnO2SignalsCalc[*][0] vs TimeAxis
	AppendToGraph MnO2SignalsData[*][1] vs TimeAxis
	AppendToGraph MnO2SignalsCalc[*][1] vs TimeAxis
	ModifyGraph mode(MnO2SignalsData)=3,mode(MnO2SignalsData#1)=3
	ModifyGraph marker(MnO2SignalsData)=8,marker(MnO2SignalsData#1)=8
	ModifyGraph lSize(MnO2StatesMatrix)=3,lSize(MnO2StatesMatrix#1)=3,lSize(MnO2StatesMatrix#2)=3
	ModifyGraph lSize(MnO2StatesMatrix#3)=3,lSize(MnO2StatesMatrix#4)=3
	ModifyGraph lStyle(MnO2StatesMatrix)=11,lStyle(MnO2StatesMatrix#1)=11,lStyle(MnO2StatesMatrix#2)=11
	ModifyGraph lStyle(MnO2StatesMatrix#3)=11,lStyle(MnO2StatesMatrix#4)=11
	ModifyGraph rgb(MnO2StatesMatrix)=(52428,1,41942,32768),rgb(MnO2StatesMatrix#1)=(39321,1,1,32768)
	ModifyGraph rgb(MnO2StatesMatrix#2)=(0,65535,0,32768),rgb(MnO2StatesMatrix#3)=(26214,26214,26214,32768)
	ModifyGraph rgb(MnO2StatesMatrix#4)=(39321,1,1,32768),rgb(MnO2SignalsCalc)=(0,0,65535)
	ModifyGraph rgb(MnO2SignalsData#1)=(0,0,65535),rgb(MnO2SignalsCalc#1)=(0,0,65535)
	ModifyGraph zero(left)=2
	ModifyGraph mirror(bottom)=2
	ModifyGraph fSize=18
	ModifyGraph lowTrip(left)=0.01
	Label left "\\Z24ΔOD"
	Label bottom "\\Z24Time (ps)"
	Label right "\\Z24State Population"
	Legend/C/N=text0/J/F=0/A=MC/X=36.83/Y=19.01 "\\Z18\\s(MnO2StatesMatrix) So\r\\s(MnO2StatesMatrix#1) S1 1st excited state\r\\s(MnO2StatesMatrix#2) S2 Ground only"
	AppendText "\\s(MnO2StatesMatrix#3) S3 Ground + Free-e\r\\s(MnO2StatesMatrix#4) S4 free-e"
EndMacro

			// ************************* Below are the function to fit simultaneous Charge and Energy transfer ******************





Function FitCTETRate()
	
	NVAR gKR				= gKR
	NVAR gKCT				= gKCT
	NVAR gKET				= gKET
	NVAR gKBET			= gKBET
	
	// My data are stored in DataFolders. Hardwire wave references to their location. 
	WAVE DCF_490 		=   root:SPECTRA:Data:Load21:s22_H_DCF_490nm_sh_data
	WAVE DCF_490_ax		=   root:SPECTRA:Data:Load21:s22_H_DCF_490nm_sh_axis
	
	WAVE DCF_540 		=   root:SPECTRA:Data:Load22:s22_H_DCF_540nm_sh_data
	WAVE DCF_540_ax		=   root:SPECTRA:Data:Load22:s22_H_DCF_540nm_sh_axis
	
	WAVE DCF_605 		=   root:SPECTRA:Data:Load23:s22_H_DCF_605nm_sh_data
	WAVE DCF_605_ax		=   root:SPECTRA:Data:Load23:s22_H_DCF_605nm_sh_axis

	String HoldString
	Variable /G gTimeZeroPt, gDyeNPts, gFWHM
	
	// 			SOME HARD-CODED PARAMETERS
	
	// **************************************
//	Variable TimeOffset 			= 0.00	// <--- Extra time offset - set to zero for debugging
	Variable TimeOffset 			= 0.07	// <--- Extra time offset for all traces
	// **************************************
	
	// **************************************
	Variable TimeOffset490 	= 0.02	// <--- Extra chirp correction for the 490 nm data
	// **************************************
	
	// **************************************
	// A time axis with 50-fs step from -TMax to TMax (ps)
	Variable TMax=3, TStep=0.05, NTPts	// <--- The time axes
	// For subsequent indexing purposes, it's useful to record the total number of time points. 
	gDyeNPts 		= 2 * (TMax/TStep) + 1
	// **************************************
	
	// Relative intensity coefficients, used to convert the concentration of a species {So, ...} into the signal at a give wavelength. 
	// The "e" coefficients represent the contributions from the Dye excited state
	Variable e_480 = 0.55, e_540 = 0.88, e_605 = 1.0
	// The "a" coefficents represent the contributions from the nanoparticle excited state. 
	Variable a_480 = 1.00, a_540 = 0.47, a_605 = 0.09
	
	Variable TrialFlag = 1
	
	
	// Concentrations of ground and excited state dye and nanoparticle species. 
	// Each column of the 2D matrix represent the kinetics for a given species. 
	// ** Dye concentrations are on a time axis from 0 - 6 ps, step size 50 fs **
	Make /D/O/N=(gDyeNPts,4) DyeNPConcentrations
	SetScale /P x, 0, TStep, DyeNPConcentrations
	SetDimLabel 1,0,$"DCF-NP",DyeNPConcentrations
	SetDimLabel 1,1,$"DCF*-NP",DyeNPConcentrations
	SetDimLabel 1,2,$"DCF+-NP-",DyeNPConcentrations
	SetDimLabel 1,3,$"DCF-NP*",DyeNPConcentrations
	
	// Axis for interpolation. The data are in general not exactly evenly spaced. 
	// ** Experimental transient spectra are on a time axis from -3 to +3 ps, step size 50 fs **
	Make /O/D/N=(gDyeNPts) TimeAxis, TAData=0
	SetScale /P x, -TMax, TStep, TAData
	
	// **************************************
	TimeAxis[] 		= pnt2x(TAData,p)	// <--- This time axis is from -3 to +3 ps. 
	// **************************************
	gTimeZeroPt 	= x2pnt(TAData,0)	// <--- Need to know the point location of time zero. 
	// **************************************
	
	// The wavelength axis (dummy)
	Make /O/D/N=3 WavelengthAxis={490,540,605}
	
	// Add an optional time offset
	// **************************************
	TimeAxis += TimeOffset
	// **************************************
	
	// 2D matrix of the traces, interpolated onto constant step axis
	// ** Calculated transient spectra are on a time axis from -3 to +3 ps, step size 50 fs **
	Make /O/D/N=(gDyeNPts,3) DyeNPTracesData=0		// <-- This holds the EXPERIMENTAL TA traces
	Make /O/D/N=(gDyeNPts,3) DyeNPTraces=0			// <-- This hold the CALCULATED TA traces
	SetScale /P x, -TMax, TStep, DyeNPTraces, DyeNPTracesData
	
	//	Read the TA data in to the Data waves
	// **************************************
	TimeAxis += TimeOffset490			// <---- Extra chirp correction for the 490 nm data
	Interpolate2 /T=1/I=3/X=TimeAxis/Y=TAData DCF_490_ax, DCF_490
	DyeNPTracesData[gTimeZeroPt,][0] 	= TAData[p]
	TimeAxis -= TimeOffset490			// <---- Undo the chirp correction
	
	Interpolate2 /T=1/I=3/X=TimeAxis/Y=TAData DCF_540_ax, DCF_540
	DyeNPTracesData[gTimeZeroPt,][1] 	= TAData[p]
	
	Interpolate2 /T=1/I=3/X=TimeAxis/Y=TAData DCF_605_ax, DCF_605
	DyeNPTracesData[gTimeZeroPt,][2] 	= TAData[p]
	// **************************************
	
	// All the parameters for fitting. 
	// This wave just holds the rate constants
	Make /O/D/N=(4) DyeNPRates
	// These are all the coefficients to be fitted -- intensity amplitudes and rate constants. 
	Make /O/D/N=(7) DyeNPParams, DyeNPHold
	
	// User input of initial rate constants ...
	if (InputCTETRateConstants(TrialFlag, DyeNPRates) == 0)
		return 0
	endif
	// ... and write these to the full coefficients wave
	DyeNPParams[KKPointer,] 	= DyeNPRates[p-KKPointer]
	
	// A Gaussian pulse for colvolving
	Make /D/O/N=(gDyeNPts) Pulse, SingleTrace
	SetScale /P x, -TMax, TStep, Pulse, SingleTrace
	
	if (gFWHM > 0)
		Pulse[] = Gauss(x,0,gFWHM/sqrt(2))
		Pulse 	/= 25		// <-- Normalization needed .... ? 
	endif
	
	if (TrialFlag == 1)
		CTETSpectralKineticsTrial(DyeNPParams,DyeNPTraces)
	else
		// Values are held or fitted simply by displaying a "holdwave" in a table and manually setting values to 0 (=fit) or 1
		// This routine just converts the wave into a string. 
		HoldString 	= MakeHoldString(DyeNPHold)
		
		// Fit the data
		FuncFitMD /W=2/N=0/H=HoldString CTETSpectralKinetics, DyeNPParams, DyeNPTracesData 
		Print " 		Chi-squared is",V_chisq,". 		The time offset is",TimeOffset,"ps"
		
		// Run the trial routine to update the results of the fit wave. I tried setting a "destination wave" but could not get this to work. 
		CTETSpectralKineticsTrial(DyeNPParams,DyeNPTraces)
		
		// Record the 
		DyeNPParams[KKPointer,] 	= DyeNPRates[p-KKPointer]
		gKR 	= DyeNPRates[0]
		gKCT 	= DyeNPRates[1]
		gKET 	= DyeNPRates[2]
		gKBET 	= DyeNPRates[3]
	endif
End

//   ***********	*!*! IMPORTANT !*!*!*
//  	FuncFitMD converts the 2D data matrix into a concatenated 1D wave. 
// 	So everything in this FitFunc routine needs to consider this! 
	
// *******************************************************************************************
// ****		Separate routines are required for FITTING using 1D data and fit waves. 
// *******************************************************************************************
Function CTETSpectralKinetics(Params,Data1D,xw,yw) : FitFunc	
	Wave Params,Data1D,xw,yw
	
	WAVE Conc 		= DyeNPConcentrations
	
	// First numerically calculate the changes in dye state concentrations, C(t)
	CalculateDyeConcentrations(Params,Conc)
	
	// Second, convert the C(t) values to I(t) at 538 and 605 nm
	// and convolve the I(t) values with the intstrumental FWHM
	CTETCurves(Params,Conc,Data1D)
End

// This converts the Concentration values for each state into Intensity values at a given wavelength
Function CTETCurves(Params,Conc,Traces1D)
	Wave Params, Conc, Traces1D
	
	NVAR gNPTs 	= gDyeNPts
	NVAR ZP 		= gTimeZeroPt
	NVAR gFWHM 	= gFWHM
	
	WAVE Pulse 	= Pulse
	WAVE Trace 	= SingleTrace

	Variable e_490 = 0.55, e_540 = 0.88, e_605 = 1.0
	Variable a_490 = 1.00, a_540 = 0.47, a_605 = 0.09
	
	// The first 3 parameters are the Intensity amplitudes. Convert from mOD. 
	Variable HmCoef 	= Params[0]/1000
	Variable AbsCoef 	= Params[1]/1000
	Variable FlCoef 		= Params[2]/1000
	
	Trace = 0
	
	// Note tricky indexing. The concentration calculations go from 0 - 3 ps. 
	// But the data go from -3 ps to 3 ps. So I need to start from the 'middle'. 
	// Need to use a single trace wave so that I can convolve with a Gaussian. 

	// 490 nm
	Trace[ZP,] 		= HmCoef*(e_490*Conc[p-ZP][3]) - AbsCoef*(a_490*(Conc[p-ZP][1] + Conc[p-ZP][2]))
	Trace[0,ZP-1] 	= 0
	if (gFWHM > 0)
		Convolve /A Pulse, Trace
	endif
	Traces1D[0,gNPTs-1] 				= Trace[p]
	
	// 540 nm
	Trace[ZP,] 		= HmCoef*(e_540*Conc[p-ZP][3]) - AbsCoef*(a_540*(Conc[p-ZP][1] + Conc[p-ZP][2])) - FlCoef*Conc[p-ZP][1]
	Trace[0,ZP-1] 	= 0
	if (gFWHM > 0)
		Convolve /A Pulse, Trace
	endif
	Traces1D[gNPTs,2*gNPTs-1] 		= Trace[p-gNPTs]
	
	// 605 nm
	Trace[ZP,] 		= HmCoef*(e_605*Conc[p-ZP][3])
	Trace[0,ZP-1] 	= 0
	if (gFWHM > 0)
		Convolve /A Pulse, Trace
	endif
	Traces1D[2*gNPTs,3*gNPTs-1] 	= Trace[p-2*gNPTs]
End

// *******************************************************************************************
// ****		Separate routines are required for TRIAL CALCULATIONS using 2D data and fit waves. 
// *******************************************************************************************

Function CTETSpectralKineticsTrial(Params,Data2D)	
	Wave Params,Data2D
	
	WAVE Conc 		= DyeNPConcentrations
	
	// First numerically calculate the changes in dye state concentrations, C(t)
	CalculateDyeConcentrations(Params,Conc)
	
	// Convert the C(t) values to I(t) at 538 and 605 nm
	// and convolve the I(t) values with the intstrumental FWHM
	CTETCurvesTrial(Params,Conc,Data2D)
End

Function CTETCurvesTrial(Params,Conc,Traces2D)
	Wave Params, Conc, Traces2D
	
	NVAR gNPTs 	= gDyeNPts
	NVAR ZP 		= gTimeZeroPt
	NVAR gFWHM 	= gFWHM
	
	WAVE Pulse 	= Pulse
	WAVE Trace 	= SingleTrace

	Variable e_490 = 0.55, e_540 = 0.88, e_605 = 1.0
	Variable a_490 = 1.00, a_540 = 0.47, a_605 = 0.09
	
	// 
	Variable HmCoef 	= Params[0]/1000
	Variable AbsCoef 	= Params[1]/1000
	Variable FlCoef 		= Params[2]/1000

	Trace = 0

	// 490 nm
	Trace[ZP,] 	= HmCoef*(e_490*Conc[p-ZP][3]) - AbsCoef*(a_490*(Conc[p-ZP][1] + Conc[p-ZP][2]))
	Trace[0,ZP-1] 	= 0
	
	if (gFWHM > 0)
		Convolve /A Pulse, Trace
	endif
	Traces2D[][0] 	= Trace[p]
	
	// 540 nm
	Trace[ZP,] 	= HmCoef*(e_540*Conc[p-ZP][3]) - AbsCoef*(a_540*(Conc[p-ZP][1] + Conc[p-ZP][2])) - FlCoef*Conc[p-ZP][1]
	Trace[0,ZP-1] 	= 0
	
	if (gFWHM > 0)
		Convolve /A Pulse, Trace
	endif
	Traces2D[][1] 	= Trace[p]
	
	// 605 nm
	Trace[ZP,] 		= HmCoef*(e_605*Conc[p-ZP][3])
	Trace[0,ZP-1] 	= 0
	
	if (gFWHM > 0)
		Convolve /A Pulse, Trace
	endif
	Traces2D[][2] 	= Trace[p]
End

// *******************************************************************************************
// ****		Differential equations describing simultaneous electron and energy transfer between DCF and Fe2O3
// *******************************************************************************************

Function CalculateDyeConcentrations(Params,Conc)
	Wave Params, Conc
	
	// Nominal 1 mM concentration. 
	Variable Co 		= 1.0
	
	// Alpha determines the distribution of photons absorbed by DCF and the NP. 
	NVAR gAlpha 	= gAlpha		// <--- Alp = 1 means ONLY THE SENSITIZING DYE ABSORBS
	
	WAVE Rates 	= DyeNPRates
	
	// Set the initial conditions
	Conc[0][0] 	= 0					// Ground State 		DCF -- NP
	Conc[0][1] 	= gAlpha * Co		// Excited Dye 		DCF* -- NP
	Conc[0][2] 	= 0					// Charge separated DCF+ -- NP-
	Conc[0][3] 	= (1-gAlpha) * Co	// Excited np		DCF -- NP*
	
	Rates[] 		= Params[KKPointer+p]
	
	// Calculate the C(t) curves
	IntegrateODE/M=1 CT_ET_Kinetics, Rates, DyeNPConcentrations
End

Function CT_ET_Kinetics(pw, tt, yw, dydt)
	Wave pw	// Parameters
	Variable tt	// time value at which to calculate derivatives
	Wave yw	// yw[0]-yw[3] containing concentrations of A,B,C,D
	Wave dydt	// wave to receive dA/dt, dB/dt etc. (output)
	
	
	// Change in GROUND STATE concentration
	dydt[0] = pw[3]*yw[2] + pw[0]*yw[3]
	
	// Change in DCF* - NP concentration
	dydt[1] = -pw[1]*yw[1] - pw[2]*yw[1]
	
	// Change in DCF+ - NP- concentration
	dydt[2] = pw[1]*yw[1] - pw[3]*yw[2]
	
	// Change in DCF - NP*concentration
	dydt[3] = pw[2]*yw[1] - pw[0]*yw[3]

	return 0
End

Function InputCTETRateConstants(FitFlag,DyeNPRates)
	Variable &FitFlag
	Wave DyeNPRates

	Variable /G gKR, gKCT, gKET, gKBET, gFitFlag, gFWHM, gAlpha
	Variable KR=gKR, KCT=gKCT, KET=gKET, KBET=gKBET, tFitFlag=gFitFlag, FWHM=gFWHM, Alpha=gAlpha
	
	Prompt tFitFlag, "Trial or fit?", popup, "trial;fit;"
	Prompt KR, "Oxide recombination"
	Prompt KCT, "Charge transfer"
	Prompt KET, "Energy transfer"
	Prompt KBET, "Back electron transfer"
	Prompt FWHM, "FWHM (ps)"
	Prompt Alpha, "Fractional dye absn"
	DoPrompt "Enter rate constants", tFitFlag, KR, KCT, KET, KBET, FWHM, Alpha
	if (V_flag)
		return 0
	endif
	
	FitFlag 	= tFitFlag
	gFitFlag = FitFlag
	gKR 	= KR
	gKCT 	= KCT
	gKET 	= KET
	gKBET 	= KBET
	gFWHM	= FWHM
	gAlpha 	= Alpha
	
	DyeNPRates[0] 	= KR
	DyeNPRates[1] 	= KCT
	DyeNPRates[2] 	= KET
	DyeNPRates[3] 	= KBET
End

STATIC Function /T MakeHoldString(CoefsHold)
	Wave CoefsHold

	String HoldString=""
	Variable i=0
	do
		HoldString+=num2str(CoefsHold[i])
		i+=1
	while(i<numpnts(CoefsHold))
	
	return HoldString
End
















































//Function ChargeEnergyTransfer()
//
//	Variable /G gKR, gKCT, gKET, gKBET
//	Variable KR=gKR, KCT=gKCT, KET=gKET, KBET=gKBET
//
//	Prompt KR, "Oxide recombination"
//	Prompt KCT, "Electron transfer"
//	Prompt KET, "Energy transfer"
//	Prompt KBET, "Back electron transfer"
//	DoPrompt "Enter rate constants", KR, KCT, KET, KBET
//	if (V_flag)
//		return 0
//	endif
//	
//	gKR 	= KR
//	gKCT 	= KCT
//	gKET 	= KET
//	gKBET 	= KBET
//	
//	Variable Alp = 0.5
//	Variable Co 	= 1.0
//	
//	// A 3-ps axis
//	Make /D/O/N=(31,4) DyeNPConcentrations
//	SetScale /P x 0, 3, DyeNPConcentrations
//	SetDimLabel 1,0,$"DCF-NP",DyeNPConcentrations
//	SetDimLabel 1,1,$"DCF*-NP",DyeNPConcentrations
//	SetDimLabel 1,2,$"DCF+-NP-",DyeNPConcentrations
//	SetDimLabel 1,3,$"DCF-NP*",DyeNPConcentrations
//	
//	// Initial Conditions
//	DyeNPConcentrations[0][0] 	= 0					// Ground State 		DCF -- NP
//	DyeNPConcentrations[0][1] 	= Alp * Co			// Excited Dye 		DCF* -- NP
//	DyeNPConcentrations[0][2] 	= 0					// Charge separated DCF+ -- NP-
//	DyeNPConcentrations[0][3] 	= (1-Alp) * Co		// Excited np		DCF -- NP*
//	
//	
//	// The rate constants
//	Make /D/O/N=4 KK
//	
//	KK[0] 	= KR			// Recombination rate
//	KK[1] 	= KCT			// Charge Transfer
//	KK[2] 	= KET			// Energy Transfer
//	KK[3] 	= KBET			// Back electron transfer
//	
//	// Integrate 
//	IntegrateODE/M=1 DCF_Hm_Kinetics, KK, DyeNPConcentrations
//	
//End




// WRONG - assumes 2D Traces wave
//Function CTETCurves(Params,Conc,Traces2D)
//	Wave Params, Conc, Traces
//	
//	NVAR gNPTs 	= gDyeNPts
//	NVAR gFHWM 	= gFWHM
//	
//	WAVE Pulse 	= Pulse
//	WAVE Trace 	= SingleTrace
//
//	Variable e_490 = 0.55, e_540 = 0.88, e_605 = 1.0
//	Variable a_490 = 1.00, a_540 = 0.47, a_605 = 0.09
//	
//	// 
//	Variable HmCoef 	= Params[0]/1000
//	Variable AbsCoef 	= Params[1]/1000
//	Variable FlCoef 		= Params[2]/1000
//	
//	Variable NTimes 	= DimSize(Traces,0)
//	Variable ZP 		= (NTimes-1)/2
//	
//	Trace = 0
//	
//	if (gFWHM > 0)
//		// 490 nm
//		Trace[ZP,] 	= HmCoef*(e_490*Conc[p-ZP][3]) - AbsCoef*(a_490*(Conc[p-ZP][1] + Conc[p-ZP][2]))
//		Convolve /A Pulse, Trace
//		Traces[][0] 	= Trace[p]
//		
//		// 540 nm
//		Trace[ZP,] 	= HmCoef*(e_540*Conc[p-ZP][3]) - AbsCoef*(a_540*(Conc[p-ZP][1] + Conc[p-ZP][2])) - FlCoef*Conc[p-ZP][1]
//		Convolve /A Pulse, Trace
//		Traces[][1] 	= Trace[p]
//		
//		// 605 nm
//		Trace[ZP,] 	= HmCoef*(e_605*Conc[p-ZP][3])
//		Convolve /A Pulse, Trace
//		Traces[][2] 	= Trace[p]
//	else
//		// 490 nm
//		Traces[ZP,][0] 	= HmCoef*(e_490*Conc[p-ZP][3]) - AbsCoef*(a_490*(Conc[p-ZP][1] + Conc[p-ZP][2]))
//		
//		// 540 nm
//		Traces[ZP,][1] 	= HmCoef*(e_540*Conc[p-ZP][3]) - AbsCoef*(a_540*(Conc[p-ZP][1] + Conc[p-ZP][2])) - FlCoef*Conc[p-ZP][1]
//		
//		// 605 nm
//		Traces[ZP,][2] 	= HmCoef*(e_605*Conc[p-ZP][3])
//	endif
//	
//End



//Function CTETSpectralKinetics(w,yw,xw) : FitFunc	
//	Wave w, xw, yw
//
//	// Alpha determines the distribution of photons absorbed by DCF and the NP. 
//	Variable Alp = 0.7		// <--- Alp = 1 means ONLY THE SENSITIZING DYE ABSORBS
//	Variable Co 	= 1.0
//
//	Variable FWHM 		= 0.13
//	
//	WAVE Params 		= DyeNPParams
//	WAVE Rates 		= DyeNPRates
//	WAVE Conc 			= DyeNPConcentrations
//	
//	// Set the initial conditions
//	Conc[0][0] 	= 0					// Ground State 		DCF -- NP
//	Conc[0][1] 	= Alp * Co			// Excited Dye 		DCF* -- NP
//	Conc[0][2] 	= 0					// Charge separated DCF+ -- NP-
//	Conc[0][3] 	= (1-Alp) * Co		// Excited np		DCF -- NP*
//	
//	Rates[] 		= Params[KKPointer+p]
//	
//	// Calculate the C(t) curves
//	IntegrateODE/M=1 CT_ET_Kinetics, Rates, DyeNPConcentrations
//	
//	// Convert the C(t) values to I(t) at 538 and 605 nm
//	// and convolve the I(t) values with the intstrumental FWHM
//	CTETCurves(Params,Conc,yw)
//End



// 	Use TA data at 2 wavelengths: 
// 		538 nm = DCF{SE and GSB} plus Hematite{Recmbination}
// 		605 nm =  Hematite{Recmbination}

// 		pw[0] 	= 538 nm Amplitude -- Hematite
// 		pw[1] 	= 538 nm Amplitude -- DCF
// 		pw[2] 	= 605 nm Amplitude -- Hematite
// 		pw[3] 	= k_R 		= Hematite recombination rate -- KNOWN
// 		pw[4] 	= k_CT 		= DCF - Hm Charge Transfer
// 		pw[5] 	= k_ET 		= DCF - Hm Energy Transfer
// 		pw[6] 	= k_BET 	= Back electron transfer

		// Include 2 terms in [S1] and [S1]^2 to account for GSB and SE
// 		I(538)	= pw[0]*[S3] - p[1]*{S1] - p[1]*[S1]^2
// 		I(605)	= pw[2]*[S3]

		// Sample Concentrations
// 		yw[0] 	= [S0] 		Ground State 			DCF -- NP
// 		yw[1] 	= [S1] 		Excited Dye 				DCF* -- NP
// 		yw[2] 	= [S2] 		Charge separated state	DCF+ -- NP-
// 		yw[3] 	= [S3] 		Excited nanoparticle		DCF -- NP*