#pragma rtGlobals=1		// Use modern global access method.

// This is the index in DyeNPParams where the rate constants start. 
Constant KKPointer 	= 3

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