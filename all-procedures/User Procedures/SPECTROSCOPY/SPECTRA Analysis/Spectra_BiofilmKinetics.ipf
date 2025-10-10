#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// New approach. Assume a 1 cm2 anode surface
// 		--  A population of MHCs bound to the anode. 
// 		--  A population of MHCs in solution. 


// Poise at -0.19V and + 0.21V
// 1 month = 2.6e6 s

Function InitializeMonodMHC()

	InitializeElectrochemistry()
	
	Variable i, j
	
	NewDataFolder /S/O root:Biofilm
		
		// *** CRITICAL ADJUSTABLE PARAMETERS
		Variable /G gC_X		= 0.0001 				// Fixed concentration of Respiration Enzymes, in moles per liter
		Variable /G gC_MHCb	= 1e-3 				// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
		Variable /G gC_MHCa	= 1e-3 				// Fixed concentration of Multi-Heme Cytochromes attached to the anode, in moles per cm2
		
		// *** CRITICAL RATE CONSTANTS
		Variable /G gMHCk_TO	= 1e6 				// Maximum turn-over rate of Anode-attached MHC's
//		Variable /G gKba		= 1e3 				// Rate of Biofilm-to-Anode MHC ET

		// Multi-heme cytochrome parameters
		Variable /G gMHCk_Eo		= -0.05		// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
		Variable /G gMHCk_dE 		= -0.031		// Increment in MHC redox potential for a unit change in charge state, in V

//		Variable /G gMHCk_Eo		= -0.05		// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
//		Variable /G gMHCk_dE 		= -0.015		// Increment in MHC redox potential for a unit change in charge state, in V
		Variable /G gMHCk_QMax 	= 11 				// # charge states per MHC. Note that 10 hemes = 11 charge states
//		Variable /G gMHCk_EMax 	= gMHCk_QMax-1 	// Maximum # electrons per heme
		Variable /G gMHCk_L			= 0.8			// Reorganization energy, in eV, for acetate-to-MHC ET
		
		// Acetate Respiration
		Variable /G gAc_Eo 		= -0.2				// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
//		Variable /G gAc_K1 		= 1					// Rate constant for formation of Acetate--Enzyme complex
		Variable /G gAc_K2 		= 0.0003			// Rate constant for breakup of Acetate--Enzyme complex
	
		// Initial and constant concentrations
//		Variable /G gC_Ac		= 0.01				// Initial concentration of Acetate, in moles per liter (M)
				
		//  ---------------------   Currently Unused parameters ------------------------------------
		// Electrode constants
		Variable /G gEA_SA 		= 1 				// Anode surface area, in cm2
		
		// Heterogeneous electron transfer -- Marcus-Hush
		Variable /G gEA_K0 	= 1e-4 				// Anode standard exchange constant for B-V or M-H rates
		Variable /G gEA_L		= 0.5				// Reorganization energy, in eV, for MHC-to-anode ET
		Variable /G gEA_Alpha 	= 0.5 				// Reversibility of anode ET
		
		// Heterogeneous electron transfer -- Chidsey
		Variable /G gEA_Nu				 			// The driving force for MHC-to-electrode ET
		Variable /G gEA_Celec 	= 1e5 				// The MHC-electrode electronic coupling. Chidsey  used a lower value (5e4) for SAMs
													// Byun et al. (2014) describes Celec values for proteins. 
		
		Variable /G gC_Gama 	= 1e-10			//  	
		
		
		// Tracks the populations of the MHCs with different charge states. 
		Make /O/D/N=(gMHCk_QMax) MHCk_QQa, MHCk_QQb, MHCk_QQt, MHCk_QQat, MHCk_QQbt
		Make /O/D/N=(gMHCk_QMax-1,gMHCk_QMax-1) MHCk_QQab, MHCk_DGab, MHCk_Nst, MHCk_DGf, MHCk_dQQ, MHCk_Kba
		SetScale /P x, gMHCk_Eo, gMHCk_dE, "V vs NHE" MHCk_QQa, MHCk_QQb, MHCk_QQab
		SetScale /P y, gMHCk_Eo, gMHCk_dE, "V vs NHE" MHCk_QQab, MHCk_DGf
End

Function MHCk_SSCV()

	InitializeMonodMHC()
	WAVE MHCk_QQa 		= root:Biofilm:MHCk_QQa
	WAVE MHCk_QQb 		= root:Biofilm:MHCk_QQb

	String OldDf 	= GetDataFolder(1)
	SetDataFolder root:Biofilm
	
		Variable i, QQ, CVdt
		Variable RecordFlag 	= 1
		
		if (GetSSCVParameters() == 0)
			return 0
		endif
		
		NVAR gSSCVEa1 			= root:Biofilm:gSSCVEa1 		// 
		NVAR gSSCVEa2 			= root:Biofilm:gSSCVEa2 		// 
		NVAR gSSCVNPts 		= root:Biofilm:gSSCVNPts 		// 
		NVAR gSSCVPsT 			= root:Biofilm:gSSCVPsT 		// 
		NVAR gSSCVdt 			= root:Biofilm:gSSCVdt 			//
		NVAR gSSCVdEa 			= root:Biofilm:gSSCVdEa 		//
		NVAR gSSCVPsPts 		= root:Biofilm:gSSCVPsPts 		//
	
		// ***      Current vs Potential waves --- for Voltammetry
		Make /O/D/N=(gSSCVPsPts) SSCVEa = 0	// The Anode potential
		Make /O/D/N=(gSSCVPsPts) SSCVj = 0		// The Ande current
		Make /O/D/N=(gSSCVPsPts) SSCVAc = 0	// The acetate concentration
		Make /O/D/N=(gSSCVPsPts) SSCVqq = 0		// The mean charge state of the MHCs
		
		SetScale /P x, gSSCVEa1, gSSCVdEa, "V vs NHE", SSCVEa, SSCVj, SSCVAc
		
		
		Print " 	*** Slow-scan biofilm voltammetry. "
				
		// An explicit potential axis
		SSCVEa[] 	= gSSCVEa1 + p*gSSCVdEa
		
		// Always poise the biofilm prior to running CV
		if (1)
			if (MHCk_Poise() == 0)
				return 0
			endif
		endif
		WAVE cAcRed 			= root:Biofilm:cAcRed
		WAVE cAcOx 			= root:Biofilm:cAcOx
		WAVE cQQ 				= root:Biofilm:cQQ
		WAVE cIIa 				= root:Biofilm:cIIa
		WAVE cIIb 				= root:Biofilm:cIIb
		WAVE cIIAc 				= root:Biofilm:cIIAc
		WAVE cEa 				= root:Biofilm:cEa
		
		WAVE MHCk_QQb 		= root:Biofilm:MHCk_QQb
		
		// Look up the final values of the Acetate concentrations
		Variable NPsPts 		= DimSize(cAcRed,0)
		Variable iStart 			= NPsPts
		
		// Extend these waves so that they can also record the CV 
		Variable NewPsPnts 	= gSSCVNPts * gSSCVPsPts
		Redimension /N=(NPsPts+NewPsPnts) cAcRed, cAcOx, cQQ, cEa, cIIa, cIIb, cIIAc
		
		Variable C_AcRed 		= cAcRed[NPsPts-1]
		Variable C_AcOx 		= cAcOx[NPsPts-1]

		
		
		for (i=0;i<gSSCVNPts;i+=1)
			
			if ((mod(i,20)==0))
				DoUpdate
			endif
			
			// At each Ea, poise for gCVPsPts 
			SSCVj[i] 	= PoiseAnodePotential(gSSCVdt,gSSCVPsPts,SSCVEa[i],iStart,C_AcRed,C_AcOx,RecordFlag,MHCk_QQb)
						
			iStart += gSSCVPsPts
						
		endfor

	SetDataFolder $OldDF
End

Function MHCk_CV()

	InitializeMonodMHC()
	WAVE MHCk_QQa 		= root:Biofilm:MHCk_QQa
	WAVE MHCk_QQb 		= root:Biofilm:MHCk_QQb

	String OldDf 	= GetDataFolder(1)
	SetDataFolder root:Biofilm
	
		Variable i, QQ, CVdt
		Variable RecordFlag 	= 1
		
		if (GetCVParameters() == 0)
			return 0
		endif
		NVAR gCVEa1 			= root:Biofilm:gCVEa1 		// 
		NVAR gCVEa2 			= root:Biofilm:gCVEa2 		// 
		NVAR gCVRate 			= root:Biofilm:gCVRate 		// 
		NVAR gCVNPts 			= root:Biofilm:gCVNPts 		// 
		NVAR gCVdT 			= root:Biofilm:gCVdT 		// 
		Variable CVdE 	= abs(gCVEa2-gCVEa1)/gCVNPts
		Variable /G gCVdT 		= CVdE/gCVRate
		
		
//		Print "CV with ",gCVNPts,"potential values",gCVTEas,"and seconds per Ea value"
		
		// The number of CV poise steps per potential
		Variable /G gCVPsPts 	= 100
	
		// ***      Current vs Potential waves --- for Voltammetry
		Make /O/D/N=(gCVNPts) CVEa = 0		// The Anode potential
		Make /O/D/N=(gCVNPts) CVj = 0		// The Ande current
		Make /O/D/N=(gCVNPts) CVAc = 0		// The acetate concentration
		Make /O/D/N=(gCVNPts) CVqq = 0		// The mean charge state of the MHCs
		
		SetScale /P x, gCVEa1, CVdE, "V vs NHE", CVEa, CVj, CVAc, CVqq
		
		// An explicit potential axis
		CVEa[] 	= gCVEa1 + p*CVdE
		
		// Always poise the biofilm prior to running CV
		if (1)
			if (MHCk_Poise() == 0)
				return 0
			endif
		endif
		WAVE cAcRed 			= root:Biofilm:cAcRed
		WAVE cAcOx 			= root:Biofilm:cAcOx
		WAVE cQQ 				= root:Biofilm:cQQ
		WAVE cIIa 				= root:Biofilm:cIIa
		WAVE cIIb 				= root:Biofilm:cIIb
		WAVE cIIAc 				= root:Biofilm:cIIAc
		WAVE cEa 				= root:Biofilm:cEa
		
		WAVE MHCk_QQb 		= root:Biofilm:MHCk_QQb
		
		// Look up the final values of the Acetate concentrations
		Variable NPsPts 		= DimSize(cAcRed,0)
		
		// Extend these waves so that they can also record the CV 
		Redimension /N=(NPsPts+gCVNPts*gCVPsPts) cAcRed, cAcOx, cQQ, cEa, cIIa, cIIb, cIIAc
		
		Variable iStart 			= NPsPts
		Variable C_AcRed 		= cAcRed[NPsPts-1]
		Variable C_AcOx 		= cAcOx[NPsPts-1]

		
		Print " 	*** Simulating biofilm voltammetry at",gCVRate*1000,"mV/s, and",gCVdT,"seconds per Ea value"
		
		for (i=0;i<gCVNPts;i+=1)
			
			if ((mod(i,20)==0))
				DoUpdate
			endif
			
			// At each Ea, poise for gCVPsPts 
			CVj[i] 	= PoiseAnodePotential(gCVdT,gCVPsPts,CVEa[i],iStart,C_AcRed,C_AcOx,RecordFlag,MHCk_QQb)
						
			iStart += gCVPsPts
						
		endfor

	SetDataFolder $OldDF
End

Function MHCk_Poise()

	InitializeMonodMHC()
	WAVE MHCk_QQa 		= root:Biofilm:MHCk_QQa
	WAVE MHCk_QQb 		= root:Biofilm:MHCk_QQb
	
	if (GetPoiseParameters() == 0)
		return 0
	endif
	NVAR gPsNew 			= root:Biofilm:gPsNew 		// 	Flag to restart vs continue
	NVAR gPsAcetate 		= root:Biofilm:gPsAcetate 	// 	The initial acetate concentration
	NVAR gPsEa 			= root:Biofilm:gPsEa 		// 	The Anode potential (V vs NHS)
	NVAR gPsTime 			= root:Biofilm:gPsTime 		// 	Poising time in HOURS
	NVAR gPsStep 			= root:Biofilm:gPsStep 		// 	Poise time step in SECONDS
	
	Variable iStart = 0, RecordFlag = 1, C_AcOx, C_AcRed, QQ_Tot
	Variable TimeStep, PrevPoiseSteps = 0
	Variable PoiseTimeSec 	= gPsTime*3600
	Variable NPoiseSteps 	= trunc(PoiseTimeSec/gPsStep)
	
	if (gPsNew==1)
		// ***      Concentration vs Time waves --- for POISING
		Make /O/D/N=(NPoiseSteps) cAcRed = 0 			// The concentration of "reduced acetate" - i.e., the substrate
		Make /O/D/N=(NPoiseSteps) cAcOx = 0 				// The concentration of "oxidized acetate" - i.e., the products
		Make /O/D/N=(NPoiseSteps) cQQ = NaN				// The charge state of the MHCs in the biofilm
		Make /O/D/N=(NPoiseSteps) cIIa = 0				// The current due to the Anode-attached MHCs
		Make /O/D/N=(NPoiseSteps) cIIb = 0				// The current due to theBiofilm MHCs
		Make /O/D/N=(NPoiseSteps) cIIAc = 0				// The current due Acetate oxidation
		Make /O/D/N=(NPoiseSteps) cEa = 0				// The Anode poise potential
		
		SetScale /P x, 0, gPsStep, "s" cAcRed, cAcOx, cQQ, cEa, cIIa, cIIb, cIIAc

		// Initially, the MHCs are completely uncharged. 
		MHCk_QQa 	= 0
		MHCk_QQa[0] = 1
		MHCk_QQb 	= 0
		MHCk_QQb[0] = 1
		
		C_AcOx 		= 1e-5
		C_AcRed 	= gPsAcetate
	
		Print " 	*** Poising a new biofilm for",gPsTime,"hours at",TimeStep,"per step, at Ea =",gPsEa,"V vs NHE and [Ac]o =",C_AcRed
	else
		PrevPoiseSteps = DimSize(cAcRed,0)
		iStart 			= PrevPoiseSteps
		Redimension /N=(PrevPoiseSteps+NPoiseSteps) cAcRed, cAcOx, cQQ, cEa, cIIa, cIIb, cIIAc
		
		C_AcOx 		= cAcOx[PrevPoiseSteps-1]
		C_AcRed 	= cAcRed[PrevPoiseSteps-1]
//		C_AcRed 	= gPsAcetate
	
		Print " 	*** Poising existing biofilm for",gPsTime,"hours at",TimeStep,"per step, at Ea =",gPsEa,"V vs NHE and [Ac]o =",C_AcRed
	endif
	
	TimeStep = PoiseTimeSec/NPoiseSteps
	
	QQ_Tot = PoiseAnodePotential(PoiseTimeSec,NPoiseSteps,gPsEa,iStart,C_AcRed,C_AcOx,RecordFlag,MHCk_QQb)
	
//	print QQ_Tot
	
	return 1
End


// Poise the system at a single anode potential for time tt, and record the current transfered to the Anode. 
// 		tt 	= length of time to poise the system, s
// 		Ea 	= Anode potential, V vs NHE

// 		C_AcRed 	= "reduced" acetate concentration, M
// 		C_AcOx 		= "oxidized" acetate concentration, M

// 		MHCk_QQ 	= matrix of the proportions of MHCs with different charge states
// 		QQ 	= average charge state of the MHCs
//
// 		Returns the total charge passed to the Anode
// 		Updates the Acetate concentrations

Function PoiseAnodePotential(tt,nsteps,Ea,iStart,C_AcRed,C_AcOx,RecordFlag,MHCk_QQb)
	Variable tt,nsteps,Ea,iStart,&C_AcRed,&C_AcOx,RecordFlag
	Wave MHCk_QQb
	
	WAVE MHCk_QQa 		= root:Biofilm:MHCk_QQa
	WAVE MHCk_QQb 		= root:Biofilm:MHCk_QQb
	WAVE MHCk_QQt 			= root:Biofilm:MHCk_QQt
	WAVE MHCk_KAc 		= root:Biofilm:MHCk_KAc
	
	NVAR gKba 				= root:Biofilm:gKba 			// Rate constant for Biofilm-to-Anode MHC ET
	
	NVAR gC_MHCb 			= root:Biofilm:gC_MHCb 	// The concentration of MHC's in the biofilm
	NVAR gC_MHCa 			= root:Biofilm:gC_MHCa 	// The concentration of MHC's on the anode
	NVAR gC_X 				= root:Biofilm:gC_X 		// The concentration of respiration enzymes
	
	NVAR gMHCk_Eo 			= root:Biofilm:gMHCk_Eo 		// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	NVAR gMHCk_dE 			= root:Biofilm:gMHCk_dE			// Increment in MHC redox potential for a unit change in charge state, in V
	NVAR gMHCk_QMax 		= root:Biofilm:gMHCk_QMax		// # charge states per MHC
	NVAR gMHCk_L 			= root:Biofilm:gMHCk_L			// Reorganization energy, in eV
	
	// Optional: follow concentrations with time in a single poising step
	WAVE cQQ 				= root:Biofilm:cQQ
	WAVE cAcRed 			= root:Biofilm:cAcRed
	WAVE cAcOx 			= root:Biofilm:cAcOx
	WAVE cEa 				= root:Biofilm:cEa
	WAVE cIIa 				= root:Biofilm:cIIa
	WAVE cIIb 				= root:Biofilm:cIIb
	WAVE cIIAc 				= root:Biofilm:cIIAc
	
	// Calculate the incremental time step
	Variable i=0, j, dI, dt
	
	// dt is the incremental time step
	dt = tt/nsteps
	
	Variable cIIa0 = cIIa[max(0,iStart-1)]
	Variable cIIb0 = cIIb[max(0,iStart-1)]
	Variable cIIAc0 = cIIAc[max(0,iStart-1)]
	Variable ETa=0, ETb=0, ETAc=0, ET=0, Total_QQ=0
	
	// ------- Set the charge state of the MHCs on the anode --------------
	ETa = MHCk_SetChargeStates(Ea,gMHCk_Eo,gMHCk_dE,gMHCk_QMax,MHCk_QQa,MHCk_QQt)
	// -----------------------------------------------------
	
	cIIa[iStart+i] 		= ETa	//<-- record here the number of electrons per MHC, not the current
	cIIa[iStart+i+1,]	= 0
	
	ETa = (gC_MHCa * ETa)/tt	//<--- record here the contribution to the measured current

	
	// Loop through small time increments
	for (i=0;i<nsteps;i+=1)
		
		if (RecordFlag && (mod(i,1000)==0))
			DoUpdate
		endif
		
		// 	----- *** RESPIRATION - reduction of Biofilm MHCs -------
		ETAc = Charge_AcToMHC(dt,C_AcRed,C_AcOx,gC_MHCb,gC_X,gMHCk_L,MHCk_QQb,MHCk_KAc)
		// -----------------------------------------------------
		
		// 	----- *** CURRENT - reduction of Anode MHCs and the Anode -------
//		ETb = Charge_MHCb_to_MHCa(dt,gKba,MHCk_QQa,MHCk_QQb)
		ETb = Charge_MHCb_to_MHCa(dt,MHCk_QQa,MHCk_QQb)
		// -----------------------------------------------------
		
		// Currently, only record the catalytic current to the anode
		ET += ETAc
		
		//Optionally save the trends with time
		if (RecordFlag)
			cQQ[iStart+i] 		= MHCk_MeanChargeState(MHCk_QQb)
			cAcRed[iStart+i] 	= C_AcRed
			cAcOx[iStart+i] 	= C_AcOx
			cIIb[iStart+i] 		=  ETb/dt
			cIIAc[iStart+i] 		=  ETAc/dt
			cEa[iStart+i] 		= Ea
//			cIIb[iStart+i] 		= cIIb0 + ETb/dt
//			cIIAc[iStart+i] 		= cIIAc0 + ETAc/dt
		endif
		
	endfor
	
	// Output the electron flux (# electrons transferred to the anode divided by the poising time step)
	return ET/tt// + ETa
	
	// Output the current, which needs the Coulomb
	return cCoulomb * ET/tt
End


// ***************************************************************************
// 				Set of routines to develop and test electron transfer between Anode and Anode MHCs
// ***************************************************************************

Function Test_MHCa()
	
	InitializeMonodMHC()
	
	WAVE QQa 			= root:Biofilm:MHCk_QQa
	WAVE QQt 			= root:Biofilm:MHCk_QQt
	
	NVAR gEo 			= root:Biofilm:gMHCk_Eo
	NVAR gdE 			= root:Biofilm:gMHCk_dE
	NVAR gQMax 		= root:Biofilm:gMHCk_QMax
	
	NewDataFolder /S/O root:AnodeMHC
	
	// A good anode potential wave
	Make /O/D/N=1000, potUp, potDown, qUp, qDown
	potUp = -0.8 + p*0.0014
	potDown = -0.8 + p*0.0014
	reverse potDown
	
	QQa = 0
	QQa[10] = 1
	
	qUp 	= MHCk_SetChargeStates(potUp[p],gEo,gdE,gQMax,QQa,QQt)
	qDown 	= MHCk_SetChargeStates(potDown[p],gEo,gdE,gQMax,QQa,QQt)

end


// Calculate the charge distribution of MHCs for a given anode potential. 
// 	Inputs: The current charge state of a the surface bound MHCs and the Anode Potential
// 	Return QQ, the number of electrons required to acheive the charge state, per MHC, from the starting charge state
Function MHCk_SetChargeStates(Ea,Eo,dE,QMax,MHCk_QQa,MHCk_QQt)
	Variable Ea,Eo,dE,QMax
	Wave MHCk_QQa, MHCk_QQt
	
	Variable nn, E1st, Enth, Edif, Popn
	Variable i, j, QQ=0, temp, NPts=Dimsize(MHCk_QQa,0)
		
	MHCk_QQt = 0
	
	// The difference between the Anode potential and the first redox potential
	Edif 		= Ea - Eo + 0.5*dE
	
	// The index of the operational redox potential	
	nn 		= min(max(0,trunc(Edif/dE)),QMax-2) // nn varies between 0 - 9 
	
	//  The value of the operational redox potential	
	E1st 	= Eo + (nn)*dE
	
	// Start with the nnth redox couple
	MHCk_SetFirstChargeState(nn,Ea,E1st,MHCk_QQt)
	
	// The contribution of the more reducing charge states
	j=1
	for (i=nn+1;i<QMax-1;i+=1)
		Enth 	= E1st + j*dE
		MHCk_SetNthChargeState(i,Ea,E1st,Enth,MHCk_QQt)
		j+=1
	endfor
		
	// The contribution of the more oxidizing charge states
	j=1
	for (i=nn-1;i>=0;i-=1)
		Enth 	= E1st - j*dE
		MHCk_SetNthChargeState(i,Ea,E1st,Enth,MHCk_QQt)
		j+=1
	endfor
	
	Popn 	= sum(MHCk_QQt)
	MHCk_QQt /= Popn
	
	// Calculate the total change in charge
	for (i=0;i<NPts;i+=1)
		QQ += i*(MHCk_QQt[i] - MHCk_QQa[i])
	endfor
	
//	if (mod(-10*Eo,2)==0)
		PlotUp()
//	endif
	
	MHCk_QQa = MHCk_QQt
	
	return QQ
End

Function MHCk_SetNthChargeState(nn,Ea,E1st,Enth,MHCk_QQt)
	Variable nn,Ea,E1st,Enth
	Wave MHCk_QQt
	
	Variable XX, A, B
	
	// This expression stays the same (?) whether Enth is higher or lower than E1st
	// -----------------------------------------------
	XX 		= exp(    (  1 *  (Ea-Enth)*cElectron    )/(cBoltzmann*298)) 	// Properly converted from eV to J
	// -----------------------------------------------
	
	// If Enth is more reducing than E1st, then we fix B and set the nnth
	if (Enth < E1st)
		B 					= MHCk_QQt[nn]		// This is nn + i
		A 					= B/XX
		MHCk_QQt[nn+1] 	= A
	else
		A  					= MHCk_QQt[nn+1]
		B 					= A*XX
		MHCk_QQt[nn] 		= B
	endif
End

Function MHCk_SetFirstChargeState(nn,Ea,Enn,MHCk_QQt)
	Variable nn,Ea,Enn
	Wave MHCk_QQt
	
	Variable XX, A, B
	
	// -----------------------------------------------
	XX 		= exp(    (  1 *  (Ea-Enn)*cElectron    )/(cBoltzmann*298)) 	// Properly converted from eV to J
	// -----------------------------------------------
	
	// A is the proportion of REDUCED 
	A 		= 1/(1+XX)
	B 		= XX/(1+XX)

	// Positive QQ means electrons are transferred to the MHCs
	MHCk_QQt[nn] 		= B
	MHCk_QQt[nn+1] 	= A
End

Function PlotUp()

//	DoUpdate /W=Graph7
//	DoUpdate /W=Graph5
//	DoUpdate /W=Graph5_1
	
End

// ***************************************************************************
// 				Set of routines to develop and test electron transfer from Acetate to Anode MHCs
// ***************************************************************************


Function Show_Test_AcToMHCa()
	
	
	InitializeMonodMHC()
	
	NVAR gEo 			= root:Biofilm:gMHCk_Eo
	NVAR gdE 			= root:Biofilm:gMHCk_dE
	NVAR gQMax 		= root:Biofilm:gMHCk_QMax
	
	// *** Adjust the MHC redox properties here
	Variable Eo 			= gEo
	Variable dE 			= gdE
	
	Eo = -0.15
	dE = -0.031
	
	SetDataFolder root:Acetate
	
	Show_ET_kinetics()
	
	Make /O/D/N=(gQMax) QQa, QQt
	
	// A good anode potential wave
	Make /O/D/N=1000, potUp, potDown, qUp, qDown
	potUp = -0.8 + p*0.0014
	potDown = -0.8 + p*0.0014
	reverse potDown
	
	Make /O/D /N=1001 pot_display
	pot_display = (-0.8-0.0014/2) + +.0014*p
	
	Make /O/D/N=(gQMax-1) MHCk_KAc, MHCk_dAc, MHCk_DG
	
	if (!WaveExists(root:Acetate:param))
		Duplicate /O potUp, param, param_prev
	endif
	Param_prev[] 		= param[p]
	
	Make /O/D/N=(1000,gQMax-1) Array_qq, Array_KAc, Array_dAc 
	
	param[] = Test_AcToMHCa(potUp[p],Eo,dE,gQMax,QQa,QQt,MHCk_KAc,MHCk_dAc)
End

Function Test_AcToMHCa(Ea,Eo,dE,QMax,QQa,QQt,MHCk_KAc,MHCk_dAc)
	Variable Ea,Eo,dE,QMax
	Wave QQa, QQt, MHCk_KAc,MHCk_dAc

	// Some variables to adjust by hand
	Variable dt 				= 0.01
	Variable C_AcRed		= 0.01
	Variable C_AcOx		= 0.000001
	Variable C_MHC			= 1e4
	Variable C_X			= 1
	Variable lambda 		= 0.8
	
	DelayUpdate
	
	MHCk_SetChargeStates(Ea,Eo,dE,QMax,QQa,QQt)
	
	Variable ee = (Ea +0.8)/(0.0014)
	WAVE Array_qq 	= Array_qq
	Array_qq[ee][]	 	= QQa[q]
	
//	KAc is the electron transfer rate for each Eo and thus has Qmax-1 values
//	QQa contains the populations and thus has Qmax values
	
	Variable QQ = Charge_AcToMHCk_XX(ee,dt,C_AcRed,C_AcOx,C_MHC,C_X,lambda,Eo,dE,QMax,QQa)
	
	return QQ
End

// Charge transfered from Acetate Respiration to (Biofilm OR Anode) MHCs
// 		Currently, this does not really consider rates of enzymmatic acetate reduction
// 		It only considers acetate to be a redox species that can reduce MHCs by ET
Function Charge_AcToMHCk_XX(ee,dt,C_AcRed,C_AcOx,C_MHC,C_X,lambda,Eo,dE,QMax,MHCk_QQb)
	Variable ee,dt,&C_AcRed, &C_AcOx, C_MHC, C_X, lambda, Eo,dE,QMax
	Wave MHCk_QQb

	Variable j, E_Ac, E_MHC, MHCk_Eoj, C_MHCk_Ox
	Variable QQ_Ox, QQ_Red, DG_eV, K_Xet, dAc, ET=0
	Variable small =1e-6
	
	Variable MHCk_QMax 	= QMax	// The total number of electron occupation states
	Variable MHCk_Eo 		= Eo 	// The first redox potential (0-1)
	Variable MHCk_dE 		= dE	// The change in redox
	
	
	
	
	// Record the change in these parameters across the potential range
	WAVE Array_DG 	= Array_DG
	WAVE Array_KAc 	= Array_KAc
	WAVE Array_dAc 	= Array_dAc
	
	// Values for a single potential
	WAVE MHCk_DG 		= MHCk_DG
	WAVE MHCk_KAc 	= MHCk_KAc
	WAVE MHCk_dAc 		= MHCk_dAc
	
	ET = 0
	
	// Loop through all the MHC populations that can be reduced. 
	// The last state, Q=10, cannot be reduced, so stop at (MHCk_QMax-1)
	for (j=0;j<(MHCk_QMax-1);j+=1)
		
		// Redox potential of the acetate + respiration enzyme system
		E_Ac 		= E_Acetate(C_AcRed,C_AcOx)
		
		// Formal redox potential for the (j)-to-(j+1) 
		MHCk_Eoj 	= MHCk_Eo + j*MHCk_dE
		
		// Nernst correction
		QQ_Ox 	= MHCk_QQb[j]
		QQ_Red 	= MHCk_QQb[j+1]
		
		// A bunch of trials that should probably be deleted
//		E_MHC 		= MHCk_Eoj + cR*298*ln(max(small,QQ_Ox)/max(small,QQ_Red))/cFaraday
//		E_MHC 		= MHCk_Eoj - 0.1* cR*298*ln(QQ_Ox/QQ_Red)/cFaraday
//		E_MHC 		= MHCk_Eoj - cR*298*ln(QQ_Ox/QQ_Red)/cFaraday
//		E_MHC 		= MHCk_Eoj
//		E_MHC 		= cR*298*ln(QQ_Red/QQ_Ox)/cFaraday
	
		// This is just the standard redox contribution
		E_MHC 		= MHCk_Eoj
		// This is just the Nernstian contribution
//		E_MHC 		= -1 * cR*298*ln(QQ_Red/QQ_Ox)/cFaraday
		// This is the full contribution
//		E_MHC 		= MHCk_Eoj - cR*298*ln(QQ_Red/QQ_Ox)/cFaraday
		
		
		// The change in free energy for MHC reduction by acetate, in eV
		DG_eV		= (E_Ac - E_MHC)//cFaraday
//		DG_eV 		= min(0,DG_eV)
		
		// The rate constant for homogenous electron transfer, based on Marcus-Hush
		// The rate constants are on the order of 10^-3/s
//		K_Xet 		= K_HomogenET(DG_eV,lambda)
		
		// The rate constant for activation energy free Marcus-Hush	
		K_Xet 		= K_DiffHomoET(1,DG_eV,0.05)
		
		// The actual concentration of the oxidized MHCs
		C_MHCk_Ox 	= C_MHC * QQ_Ox
		
		// The actual ET is propotional to:
		// 	1. Concentration of oxidized MHCs
		// 	2. Concentration of the complexes {Ac-X}. Note that this is not a proper treatment. 
		
//		dAc 	= dt * K_Xet * C_MHCk_Ox * C_AcRed * C_X	
//		dAc 	= dt * K_Xet * C_MHCk_Ox * C_X

		dAc = K_Xet * C_MHCk_Ox
		
		MHCk_Kac[j] = K_Xet
		MHCk_dAc[j] = dAc
		MHCk_DG[j] = DG_eV
//		MHCk_DG[j] = E_MHC
		
		// Update the acetate concentration (Disable this for development)
//		C_AcRed -= dAc
//		C_AcOx += dAc
		
		// Update the MHC charge including the reaction stoichiometry of 8 e's per acetate 
		MHCk_QQb[j] -= 8*dAc/C_MHC
		MHCk_QQb[j+1] += 8*dAc/C_MHC
		
		ET += 8 * dAc
	endfor
	
	Array_KAc[ee][]	 	= MHCk_KAc[q]
	Array_dAc[ee][]	 	= MHCk_dAc[q]
	Array_DG[ee][]	 		= MHCk_DG[q]
	
//	return DG_eV
//	return mean(MHCk_DG)
	return ET
End





// This function calculates the maximum number of electrons that can be passed through a single Anode MHC
Function MHCk_TurnOver(dt,To,eInput)
	Variable dT, To, eInput
	
	// The ideal number of turn-overs per dt is To*dt
	Variable TotE = To*dt
	
	return eInput * ((To*dt)/(eInput + (To*dt)))
End

// ***************************************************************************
// 				Set of routines to develop and test electron transfer from Acetate to Biofilm + Anode MHCs
// ***************************************************************************


// Charge transfered from Biofilm MHCs to the Anode via that Anode MHCs
// 		.... revised to incorporate DG effects on Ket

Function Charge_MHCb_to_MHCa(dt,QQa,QQb)
	Variable dt
	Wave QQa, QQb
	
	// The Concentrations
	NVAR gC_MHCb 			= root:Biofilm:gC_MHCb 	// 
	NVAR gC_MHCa 			= root:Biofilm:gC_MHCa 	// 
	NVAR gMHCk_TO 			= root:Biofilm:gMHCk_TO 	// 
	
	WAVE dQQ 			= root:Biofilm:MHCk_dQQ
	WAVE QQt 			= root:Biofilm:MHCk_QQt
	WAVE Kba 			= root:Biofilm:MHCk_Kba		// The Forward ET's
	WAVE Kab 			= root:Biofilm:MHCk_Kab		// The Reverse ET's
	
	Variable QMax 	= DimSize(QQb,0)		// The total number of electron occupation states
	
	Variable i, j, Ket, ETpred, ETij, ETsum=0, TO_dt, ETtot
	
	Variable Ko 	= 100000
	
	// Fill the Forward and Reverse matrices explicitly, and calculate the total max poss ET
	for (i=0;i<(QMax-1);i+=1)
		for (j=0; j<(QMax-1);j+=1)
			
			// 				---	FORWARD -----
			// The homogeneous ET rate constant for this pair
			Ket 			= Single_MHCab(i,j,QQa,QQb)
			Kba[i][j] 	= Ket
//			Kba[i][j] 	= Ket * 1000 // %%%
			
			// The predicted electron transfer. Note - Ko prefactor is omitted. 
			ETpred 		= Ko * gC_MHCa * QQa[i] * gC_MHCb * QQb[j+1] * (1 - exp(-1*dt*Ket))
			dQQ[i][j] 	= ETpred
			
			// The total number of electrons that would be transferred to each anode MHC
			ETij 		= ETpred/gC_MHCa
			
			ETsum 		+= ETij
			
			// 				---	REVERSE  -----
		endfor
	endfor
	
	// The maximum number of turn-overs per dt
	TO_dt 		= gMHCk_TO * dt
	
	// The number of transfers that would be allowed given the limited turnover rate
	ETtot 		= ETsum * (TO_dt/(ETsum + TO_dt))
	
	// Correct the b-a matrix so it represents the actually permitted transfers
	dQQ	 *= (ETtot/ETsum)

	// Change the distribution of MHCb's. Recall that QQa is fixed by anode
	
	QQt = 0
	for (i=0;i<(QMax-1);i+=1)
		for (j=0; j<(QMax-1);j+=1)
	
			if (dQQ[i][j] != 0)
			
				// The total number of electrons transfered from MHCb state (i+1) to i
				QQt[i] 		+= dQQ[i][j]/gC_MHCb
				QQt[i+1] 	-= dQQ[i][j]/gC_MHCb
			
			endif
		endfor
	endfor
	
	return ETtot
End

Function Single_MHCab(i,j,QQa,QQb)
	Variable i,j
	Wave QQa,QQb
	
	WAVE DGab 			= root:Biofilm:MHCk_DGab
	WAVE Nst 			= root:Biofilm:MHCk_Nst
	WAVE DGf 			= root:Biofilm:MHCk_DGfor
	
	Variable dEo 		= DimDelta(QQb,0)	// The change in redox
	
	Variable DGo, Nernst, DG, Ket
	
	Variable sm = 1e-3
	Variable lambda = 0.8
	Variable NernstFlag = 1
	
	// This appears to be correct for FORWARD b->a ET
	DGo 		= (j - i) * dEo
	DGab[i][j]	= DGo
	
	if (QQa[i]==0 || QQb[j+1]==0)			// No Acceptor or no Donor
		Nst[i][j] 	= 0
//		Ket 			= NaN	// %%%
		
	else
		if (NernstFlag)
			// This appears to be correct for FORWARD b->a ET
			Nernst 		= ln(max(sm,QQb[j])/max(sm,QQb[j+1])) -  ln(max(sm,QQa[i+1])/max(sm,QQa[i]))		
			Nernst 		*= (cR*298/cFaraday)
		else
			Nernst 		= 0
		endif
		Nst[i][j] 	= Nernst
		
		DG 			= DGo + Nernst
		Ket 			= K_HomoMarcusET(1,DG,lambda)
		
	endif
			
	return Ket
End





























































// Charge transfered from Acetate Respiration to the Biofilm MHCs
// 		Currently, this does not really consider rates of enzymmatic acetate reduction
// 		It only considers acetate to be a redox species that can reduce MHCs by ET
Function Charge_AcToMHC(dt,C_AcRed,C_AcOx,C_MHC,C_X,lambda,MHCk_QQb,MHCk_Kac)
	Variable dt,&C_AcRed, &C_AcOx, C_MHC, C_X, lambda
	Wave MHCk_QQb, MHCk_Kac

	Variable j, E_Ac, E_MHC, MHCk_Eoj, C_MHCk_Ox
	Variable QQ_Ox, QQ_Red, DG_eV, K_Xet, dAc, ET=0
	Variable small =1e-6
	
	// Look up the parameters of the redox proteins
	Variable MHCk_QMax 	= DimSize(MHCk_QQb,0)-1	// The total number of electron occupation states
	Variable MHCk_Eo 		= DimOffset(MHCk_QQb,0) 	// The first redox potential (0-1)
	Variable MHCk_dE 		= DimDelta(MHCk_QQb,0)	// The change in redox
	
	// Loop through all the MHC populations that can be reduced. 
	// The last state, Q=10, cannot be reduced, so stop at (MHCk_QMax-1)
	for (j=0;j<(MHCk_QMax);j+=1)
		
		// Redox potential of the acetate + respiration enzyme system
		E_Ac 		= E_Acetate(C_AcRed,C_AcOx)
		
		// Formal redox potential for the (j)-to-(j+1) 
		MHCk_Eoj 	= MHCk_Eo + j*MHCk_dE
		
		// Nernst correction
		QQ_Ox 	= MHCk_QQb[j]
		QQ_Red 	= MHCk_QQb[j+1]
		
		// Avoid infinite Nerstian corrections by applying some limits (in this statement!) 
		E_MHC 		= MHCk_Eoj + cR*298*ln(max(small,QQ_Ox)/max(small,QQ_Red))/cFaraday
	
		// The change in free energy for MHC reduction by acetate, in eV
		DG_eV		= (E_Ac - E_MHC)//cFaraday
		
		// The rate constant for homogenous electron transfer, based on Marcus-Hush
		// The rate constants are on the order of 10^-3/s
		K_Xet 		= K_HomoMarcusET(1,DG_eV,lambda)
		
		MHCk_Kac[j] = K_Xet
		
		// The actual concentration of the oxidized MHCs
		C_MHCk_Ox 	= C_MHC * QQ_Ox
		
		// The actual ET is propotional to:
		// 	1. Concentration of oxidized MHCs
		// 	2. Concentration of the complexes {Ac-X}. Note that this is not a proper treatment. 
		
		dAc 	= dt * K_Xet * C_MHCk_Ox * C_AcRed * C_X	
//		dAc 	= dt * K_Xet * C_MHCk_Ox * C_X
		
		// Update the acetate concentration
		C_AcRed -= dAc
		C_AcOx += dAc
		
		// Update the MHC charge including the reaction stoichiometry of 8 e's per acetate 
		MHCk_QQb[j] -= 8*dAc/C_MHC
		MHCk_QQb[j+1] += 8*dAc/C_MHC
		
		ET += 8 * dAc
	endfor
	
	return ET
End


// Charge transfered from Biofilm MHCs to the Anode via that Anode MHCs
// 		Currently, this does not consider true ET kinetics. If Eb > Ea, then charge is transferred at rate Kba
// 		This might underestimate current when the Anode is highly reducing. 
//		The Anode MHCs are in equilibrium with the anode and their charge state does not change. 
// 		Currently, this does not allow ET from Anodeto Biofilm, which seems crazy but that seems to accord with data. 
Function Charge_MHCb_to_MHCa_v1(dt,Kba,MHCk_QQa,MHCk_QQb)
	Variable dt, Kba
	Wave MHCk_QQa, MHCk_QQb
	
	// The Concentrations
	NVAR gC_MHCb 			= root:Biofilm:gC_MHCb 		// 
	NVAR gC_MHCa 			= root:Biofilm:gC_MHCa 		// 
	NVAR gMHCk_TO 			= root:Biofilm:gMHCk_TO 		// 
	
	// Look up the parameters of the redox proteins ... may not be necessary
	Variable MHCk_QMax 	= DimSize(MHCk_QQb,0)-1	// The total number of electron occupation states
	Variable MHCk_Eo 		= DimOffset(MHCk_QQb,0) 	// The first redox potential (0-1)
	Variable MHCk_dE 		= DimDelta(MHCk_QQb,0)	// The change in redox
	
	Variable i, j, QQ_sum, ET_prob, ET_poss, TO_dt, dQQ, ET=0
	
	// The ratio of Biofilm to Anode MHCs
	Variable Rab 	= gC_MHCb/gC_MHCa
	
	// A matrix for Biofilm-to-Anode ET containing the product of the populations for j > i
	// Rows, p's = Anode i; Cols, q's = Biofilm j
	WAVE MHCk_QQab 		= root:Biofilm:MHCk_QQab
	MHCk_QQab[][] 	= (q >= p) ? (MHCk_QQb[q]) : (0)
	
	// The total proportion of Biofilm MHCs that could transfer
	QQ_sum 	= sum(MHCk_QQab)
	
	// The # e's likely to be transferred within time dt, per Anode MHC
	ET_prob 	= Rab * QQ_sum * (1 - exp(-1*dt*Kba))
	
	// The maximum number of turn-overs per dt
	TO_dt 		= gMHCk_TO * dt
	
	// The number of transfers that would be allowed given the limited turnover rate
	ET_poss 	= ET_prob * (TO_dt/(ET_prob + TO_dt))
	
	// Correct the b-a matrix so it represents the actually permitted transfers
	MHCk_QQab *= (ET_poss/ET_prob)

	// Loop through all the ANODE MHC populations that can be reduced. 
	for (i=0;i<(MHCk_QMax);i+=1)
	
		if (MHCk_QQa[i] > 0)
		
			// Loop through all the Biofilm MHCs that will transfer electrons
			// *!*! Don't think it matters the direction of this loop. 
			for (j=i+1; j<=(MHCk_QMax);j+=1)
				if (MHCk_QQb[j]>0)
					
					dQQ = MHCk_QQab[i][j]
					
					MHCk_QQb[j] 	-= dQQ
					MHCk_QQb[j-1]	+= dQQ
					
					ET += 	gC_MHCb * dQQ
					
				endif
			endfor
		endif
	endfor
	
	return ET
End

Function GetCVParameters()

//	String OldDf 	= GetDataFolder(1)
//	SetDataFolder root:Biofilm
//	
//		Variable CVEa1 	= NUMVarOrDefault("root:Biofilm:gCVEa1",-0.8)
//		Prompt CVEa1,"Anode initial potential (V vs NHE)"
//		Variable CVEa2 	= NUMVarOrDefault("root:Biofilm:gCVEa2",0.8)
//		Prompt CVEa2,"Anode final potential (V vs NHE)"
//		Variable CVNEas = NUMVarOrDefault("root:Biofilm:gCVNEas",100)
//		Prompt CVNEas,"Number of Ea values"
//		Variable gCVTEas = NUMVarOrDefault("root:Biofilm:gCVTEas",100)
//		Prompt gCVTEas,"Seconds per Ea value"
//		DoPrompt "Biofilm voltammetry", CVEa1, CVEa2, CVNEas, gCVTEas
//		if (V_flag)
//			return 0
//		endif
//		
//		Variable /G gCVEa1 	= CVEa1
//		Variable /G gCVEa2 	= CVEa2
//		Variable /G gCVNEas = CVNEas
//		Variable /G ggCVTEas =gCVTEas
//		
//	SetDataFolder $OldDF
//	return 1
End

Function GetSSCVParameters()

	String OldDf 	= GetDataFolder(1)
	SetDataFolder root:Biofilm
	
		Variable SSCVEa1 	= NUMVarOrDefault("root:Biofilm:gSSCVEa1",-0.8)
		Prompt SSCVEa1,"Anode initial potential (V vs NHE)"
		Variable SSCVEa2 	= NUMVarOrDefault("root:Biofilm:gSSCVEa2",0.8)
		Prompt SSCVEa2,"Anode final potential (V vs NHE)"
		Variable SSCVNPts = NUMVarOrDefault("root:Biofilm:gSSCVNPts",100)
		Prompt SSCVNPts,"Number of Ea values"
		Variable SSCVPsT = NUMVarOrDefault("root:Biofilm:gSSCVPsT",60)
		Prompt SSCVPsT,"Poising time per Ea value (s)"
		Variable SSCVdt = NUMVarOrDefault("root:Biofilm:gSSCVPsT",0.1)
		Prompt SSCVdt,"Poising time step (s)"
		DoPrompt "Biofilm voltammetry", SSCVEa1, SSCVEa2, SSCVNPts, SSCVPsT, SSCVdt
		if (V_flag)
			return 0
		endif
		
		// Adjust Ea2 as needed
		Variable /G gSSCVdEa = (SSCVEa2-SSCVEa1)/SSCVNPts
		SSCVEa2 	= SSCVEa1 + gSSCVdEa*SSCVNPts
		
		Variable /G gSSCVEa1 	= SSCVEa1
		Variable /G gSSCVEa2 	= SSCVEa2
		Variable /G gSSCVNPts 	= SSCVNPts
		Variable /G gSSCVPsT 	= SSCVPsT
		Variable /G gSSCVdt 	= SSCVdt
		
		// The number of CV poise steps per potential
		Variable /G gSSCVPsPts 	= gSSCVPsT/gSSCVdt
		
		
	SetDataFolder $OldDF
	return 1
End

Function GetPoiseParameters()

	String OldDf 	= GetDataFolder(1)
	SetDataFolder root:Biofilm
	
		Variable PsNew 	= NUMVarOrDefault("root:Biofilm:gPsNew",1)
		Prompt PsNew,"Reset or continue from previous?", popup, "new;continue;"
		
		Variable PsAcetate 	= NUMVarOrDefault("root:Biofilm:gPsAcetate",0.01)
		Prompt PsAcetate,"Acetate concentration [mM]"
		
		Variable PsEa 	= NUMVarOrDefault("root:Biofilm:gPsEa",-0.19)
		Prompt PsEa,"Anode poise potential (V vs NHE)"
		Variable PsTime 	= NUMVarOrDefault("root:Biofilm:gPsTime",24)
		Prompt PsTime,"Poising time (hours)"
		Variable PsStep 	= NUMVarOrDefault("root:Biofilm:gPsStep",300)
		Prompt PsStep,"Poising time step (seconds)"
		DoPrompt "Biofilm voltammetry", PsNew, PsAcetate, PsEa, PsTime, PsStep
		if (V_flag)
			return 0
		endif
		
		Variable /G gPsNew 		= PsNew
		Variable /G gPsAcetate 	= PsAcetate
		Variable /G gPsEa 		= PsEa
		Variable /G gPsTime 	= PsTime
		Variable /G gPsStep 	= PsStep
		
	SetDataFolder $OldDF

	return 1
End


// TEST FUNCTION: 
Function Calculate_Ac_MHCk_Ket(EAc0,C_AcRed,C_AcOx,Emhc0,C_MHCk_Red,C_MHCk_Ox)
	Variable EAc0,C_AcRed,C_AcOx,Emhc0,C_MHCk_Red,C_MHCk_Ox
	
	Variable E_Ac, E_MHC, DG_eV, K_Xet
	Variable lambda 	= 0.8
	Variable small 		= 1e-6
		
	// Redox potential of the acetate + respiration enzyme system
	E_Ac 		= E_Acetate(C_AcRed,C_AcOx)
	
	// Avoid infinite Nerstian corrections by applying some limits (in this statement!) 
	E_MHC 		= Emhc0 + cR*298*ln(max(small,C_MHCk_Ox)/max(small,C_MHCk_Red))/cFaraday

	// The change in free energy for MHC reduction by acetate, in eV
	DG_eV		= (E_Ac - E_MHC)//cFaraday
	
	// The rate constant for homogenous electron transfer, based on Marcus-Hush
	// The rate constants are on the order of 10^-3/s
	K_Xet 		= K_HomoMarcusET(1,DG_eV,lambda)
	
//	return DG_eV
	return K_Xet
End


// Oddly this functional form looks a lot like the broadened protein voltammetry ... 
Function K_ElectrodeETAnalytical(DG,Df)
	Variable DG,Df
	
	Variable DG_act, K_mh, K_eff
	
	// 
	DG_act  	= (DG+0.4)^2/4
	
	K_mh 		= exp(-1*(cFaraday*(DG_act))/(cR*298))
	
	// This is not bad ... 
	K_eff 		= 1 - Df*(1/(Df+K_mh) - 1)
	
	return K_eff
End

// TEST FUNCTION: Calculate the heterogeneous rate constants for the different MHC redox states and the poise potential
Function Calculate_MHCk_Ket(EA)
	Variable EA

	NVAR gEA_L 			= root:Biofilm:gEA_L 		// Reorganization energy, in eV, for MHC-to-anode ET
	NVAR gMHCk_Eo 			= root:Biofilm:gMHCk_Eo 	// 
	NVAR gMHCk_dE 			= root:Biofilm:gMHCk_dE 	// 
	NVAR gMHCk_QMax 		= root:Biofilm:gMHCk_QMax 	// 
	NVAR gEA_Celec 		= root:Biofilm:gEA_Celec 	// The MHC-electrode electronic coupling
	
	// WAVE MHCk_Chidsey 	= root:Biofilm:MHCk_Chidsey //
	
	Make /O/D/N=(gMHCk_QMax) MHCk_Chidsey
	SetScale /P x, gMHCk_Eo, gMHCk_dE, "V vs NHE" MHCk_Chidsey
	
	Variable j, MHCk_Eoj
	for (j=0; j<10;j+=1)
		MHCk_Eoj 			= gMHCk_Eo + j*gMHCk_dE
		MHCk_Chidsey[j] 	= gEA_Celec*K_ElectrodeET(EA,MHCk_Eoj,gEA_L,1)
	endfor
End

//   TEST FUNCTION: calculating the rate constant for Non-Adiabatic metallic electrode ET
Function K_ElectrodeET(Ea,Eo,lambda,OxFlag)
	Variable Ea,Eo,lambda,OxFlag
	
	NVAR LL 		= root:Biofilm:gEA_L
	NVAR nu 		= root:Biofilm:gEA_Nu
	
	nu 	= Ea - Eo
	LL 	= lambda
	
	Variable integral, Celec 	= 1e5
	
	if (OxFlag)
		integral = Integrate1D(ChidseyOx, -10, 10)
	else
		integral = Integrate1D(ChidseyRed, -10, 10)
	endif
	
	return Celec * integral 
End

// 	Chidsey's expression for molecule-to-electrode ET, called k_Ox
// 		i.e., the molecule is oxidised
// 		x is the energy relative to Ef in eV
// 		LL is the reorganization energy, typically 0.4 - 1 eV
// 		Nu is the driving force, E - Eo', where E is the electrode potential and Eo' is the redox couple
//
// 		These functions do seem to correctly reproduce the curves in Chidsey (1991)
// 		The signs are also correct. 
Function ChidseyOx(x)
	Variable x
	
	NVAR LL 		= root:Biofilm:gEA_L
	NVAR nu 		= root:Biofilm:gEA_Nu
	
	Variable kBT 	= cBoltzmann*298
	
	// Here, need to convert Lambda and Nu from eV to J
	Variable Brkt1 	= (x - cE*(LL-nu)/kBT)^2
	
	// Here, need to convert Lambda from eV to J
	Variable Brkt2 	= kBT/(4*LL*cE)
	
	Variable Brkt3 	= (1 + exp(x))
	
	return exp(-1*Brkt1*Brkt2)/(1+exp(x))
End

// 	Chidsey's expression for electrode-to-molecule ET, called k_Red
// Not used in the MHC calculations but used to check things
Function ChidseyRed(x)
	Variable x
	
	NVAR LL 		= root:Biofilm:gEA_L
	NVAR nu 		= root:Biofilm:gEA_Nu
	
	Variable kBT 	= cBoltzmann*298
	
	// Here, need to convert Lambda and Nu from eV to J
	Variable Brkt1 	= (x - cE*(LL+nu)/kBT)^2
	
	// Here, need to convert Lambda from eV to J
	Variable Brkt2 	= kBT/(4*LL*cE)
	
	Variable Brkt3 	= (1 + exp(x))
	
	return exp(-1*Brkt1*Brkt2)/(1+exp(x))
End

// Calculate the average occupation of all MHCs
Function MHCk_MeanChargeState(MHCk_QQ)
	Wave MHCk_QQ
	
	Variable i, QQ=0, NPts=Dimsize(MHCk_QQ,0)
	
	for (i=0;i<NPts;i+=1)
		QQ += i*MHCk_QQ[i]
	endfor
	
	return QQ
End

// The electrochemical potential of acetate 
Function Ek_Acetate(C_AcRed,C_AcOx)
	Variable C_AcRed, C_AcOx
	
	NVAR gAc_Eo 		= root:Biofilm:gAc_Eo
	
	Variable Nernst 	= cR*298*ln(C_AcOx/C_AcRed)/cFaraday

	return gAc_Eo + Nernst
End

// 	***********************************************************************************
//	*************		ELECTROCHEMISTRY RATE EQUATIONS	**************************************

// *** Calculate the Rate constant for MHC-to-Anode electron transfer
// 		A Marcus Theory modification of the Butler-Volmer expression
Function Rate_MH_MHCk_Anode(Eh_mhc,Ea,direction)
	Variable Eh_mhc, Ea, direction

	NVAR gA 	= root:Biofilm:gAlpha
	NVAR gKo 	= root:Biofilm:gK0anode
	
	Variable KK, Ld = 0.55
	Variable n 	= (Ea-Eh_mhc)
	Variable Rcf = 1/cf
	
	Variable BVpart 	= n/Rcf
	Variable MHpart 	= n^2/(4*Ld*Rcf)
	
	if (direction==1)
		// Forward, MHC to Anode
		KK 		= gKo * exp(-gA*BVpart - MHpart)
	else
		// Reverse, Anode to MHC
		KK 		= gKo * exp((1-gA)*BVpart - MHpart)
	endif
	
	return KK
End

// *** Calculate the Rate constant for MHC-to-Anode electron transfer
// 		A Butler-Volmer expression
Function Rate_BV_MHCk_Anode(Eh_mhc,Ea,direction)
	Variable Eh_mhc, Ea, direction

	NVAR gA 	= root:Biofilm:gAlpha
	NVAR gKo 	= root:Biofilm:gK0anode
	
	Variable KK
	
	if (direction==1)
		// Forward, MHC to Anode
		KK 		= gKo * exp(-1*gA*cf*(Ea-Eh_mhc))
	else
		// Reverse, Anode to MHC
		KK 		= gKo * exp((1-gA)*cf*(Ea-Eh_mhc))
	endif
	
	return KK
End

// The electrochemical potential of MHC 
//Function E_MultiHemeCyt(QQ)
//	Variable QQ
//	
//	NVAR gMHCk_Eo 		= root:Biofilm:gMHCk_Eo 		// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
//	NVAR gMHCk_dE 		= root:Biofilm:gMHCk_dE			// Increment in MHC redox potential for a unit change in charge state, in V
//	NVAR gMHCk_QMax 	= root:Biofilm:gMHCk_QMax		// # charge states per MHC
//	
//	// Need to establish which redox couple on the ladder, and the number of Ox/Red mhc's
//	
//	Variable QQ_N, QQ_Red, QQ_Ox, MHCk_E
//	
//	QQ_N 	= trunc(Q)
//	QQ_Red 	= QQ - QQ_N
//	QQ_Ox 	= 1 - QQ_Red
//	
//	MHCk_E 	= gMHCk_Eo + QQ_N*gMHCk_dE
//	
//	return  = MHCk_E + cR*298*ln(QQ_Ox/QQ_Red)/cFaraday
//End




//
//// Poise the system at a single anode potential for time tt, and record the current transfered to the Anode. 
//// 		tt 	= length of time to poise the system, s
//// 		Ea 	= Anode potential, V vs NHE
//
//// 		C_AcRed 	= "reduced" acetate concentration, M
//// 		C_AcOx 		= "oxidized" acetate concentration, M
//
//// 		MHCk_QQ 	= matrix of the proportions of MHCs with different charge states
//// 		QQ 	= average charge state of the MHCs
////
//// 		Returns the total charge passed to the Anode
//// 		Updates the Acetate concentrations
//Function PoiseAnodePotential(tt,nsteps,Ea,C_AcRed,C_AcOx,RecordFlag,MHCk_QQ)
//	Variable tt,nsteps, Ea,&C_AcRed,&C_AcOx,RecordFlag
//	Wave MHCk_QQ
//	
//	NVAR gC_MHC 			= root:Biofilm:gC_MHC 		// The concentration of MHC's
//	NVAR gC_X 				= root:Biofilm:gC_X 		// The concentration of respiration enzymes
//	NVAR gC_Gama 			= root:Biofilm:gC_Gama		// Fraction of MHCs that are on the electrode
//	
//	NVAR gEA_Nu 			= root:Biofilm:gEA_Nu 		// The driving force for MCH-to-electrode ET, nu = Ea - Emhc
//	NVAR gEA_Celec 		= root:Biofilm:gEA_Celec 	// The MHC-electrode electronic coupling
//	
//	NVAR gMHCk_Eo 			= root:Biofilm:gMHCk_Eo 		// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
//	NVAR gMHCk_dE 			= root:Biofilm:gMHCk_dE			// Increment in MHC redox potential for a unit change in charge state, in V
//	NVAR gMHCk_QMax 		= root:Biofilm:gMHCk_QMax		// # charge states per MHC
//	NVAR gMHCk_L 			= root:Biofilm:gMHCk_L			// Reorganization energy, in eV
//	
//	// Optional: follow concentrations with time in a single poising step
//	WAVE cQQ 				= root:Biofilm:cQQ
//	WAVE cAcRed 			= root:Biofilm:cAcRed
//	WAVE cAcOx 			= root:Biofilm:cAcOx
//	WAVE cEaj 				= root:Biofilm:cEaj
//	
//	// Calculate the incremental time step
//	Variable i, j, dI, dt
//	
//	// dt is the time step
//	dt = tt/nsteps
//	
//	if (RecordFlag)
//		Print " 		- Each time step is",dt,"seconds"
//	endif
//	
//	Variable E_Ac, E_MHC, MHCk_Eoj, QQ_Ox, QQ_Red, DG_eV, K_Xet, K_Aet, C_MHCk_Ox, C_MHCk_Red, ET, ET_2, ET_mod
//	Variable small 	=1e-6
//	Variable Ea_QQ, Total_QQ=0
//	
//	// Loop through small time increments
//	for (i=0;i<nsteps-1;i+=1)
//		
//		//Optionally save the trends with time
//		if (RecordFlag)
//			cQQ[i] 		= MHCk_ChargeState(MHCk_QQ)
//			cAcRed[i] 	= C_AcRed
//			cAcOx[i] 	= C_AcOx
//			cEaj[i] 		= Ea_QQ/dt
//		endif
//		
//		if (RecordFlag && (mod(i,1000)==0))
//			DoUpdate
//		endif
//		
//		// 	*** RESPIRATION
//		
//		// Loop through all the MHC populations THAT CAN BE REDUCED 
//		for (j=0;j<(gMHCk_QMax-1);j+=1)
//	
//			E_Ac 		= E_Acetate(C_AcRed,C_AcOx)
//			
//			// Formal redox potential for the jth redox
//			MHCk_Eoj 	= gMHCk_Eo + j*gMHCk_dE
//			
//			// Nernst correction
//			QQ_Ox 	= MHCk_QQ[j]
//			QQ_Red 	= MHCk_QQ[j+1]
//			
//			// Avoid infinite Nerstian corrections
//			E_MHC 		= MHCk_Eoj + cR*298*ln(max(small,QQ_Ox)/max(small,QQ_Red))/cFaraday
//		
//			// The change in free energy for MHC reduction by acetate, in eV
//			DG_eV		= (E_Ac - E_MHC)/cFaraday
//			
//			// The rate constant for homogenous electron transfer, based on Marcus-Hush
//			// The rate constants are on the order of 10^-3/s
//			K_Xet 		= K_HomogenET(DG_eV,gMHCk_L)
//			
//			// The actual concentration of the oxidized MHCs
//			C_MHCk_Ox 	= gC_MHC * QQ_Ox
//			
//			// The actual ET is propotional to:
//			// 	1. Concentration of oxidized MHCs
//			// 	2. Concentration of the complexes {Ac-X}. Note that this is not a proper treatment. 
//			ET 			= dt * K_Xet * C_MHCk_Ox * C_AcRed * gC_X
//			
//			// Update the acetate concentration
//			C_AcRed -= ET
//			C_AcOx += ET
//			
//			// Update the MHC charge including the reaction stoichiometry of 8 e's per acetate 
//			MHCk_QQ[j] -= 8*ET/gC_MHC
//			MHCk_QQ[j+1] += 8*ET/gC_MHC
//		endfor
//		
//		
//		// 	*** ANODE REDUCTION
//		
//		Ea_QQ = 0
//		
//		if (1)
//		
//		// Loop through all the MHC populations THAT CAN BE OXIDIZED
//		for (j=1;j<(gMHCk_QMax);j+=1)
//		
//			// The proportion of reduced MHC's with j electrons
//			QQ_Red 		= MHCk_QQ[j]
//			
//			// The actual concentration of the reduced MHC
//			C_MHCk_Red = gC_MHC * QQ_Red
//			
//			// Formal redox potential for the jth redox
//			MHCk_Eoj 	= gMHCk_Eo + j*gMHCk_dE
//			
//			// This is a global variable used by ChidseyOx()
//			gEA_Nu  	= Ea - MHCk_Eoj
//
//			// The rate constant for heterogeneous electron transfer, based on Chidsey
//			// The rate constanst are on the order of 10^6/s
//			K_Aet 		=  gEA_Celec * Integrate1D(ChidseyOx, -10, 10)
//			
//			// The actual ET is proportional to: 
//			// 	1. Concentration of reduced MHCs in the system
//			// 	2. Fraction of MHCs that are on the electrode, Gama
////			ET 			= dt * gC_Gama * C_MHCk_Red * cFaraday * K_Aet
//			ET 			= dt * gC_Gama * C_MHCk_Red * K_Aet
//			
//			// Impose mass transport limitation
//			ET_mod 	= dt * gC_Gama * C_MHCk_Red * K_Aet/(1000 + K_Aet)
//			
//			
//			ET 			= ET_mod
//			
//			if (ET > 0)
//				// Update the MHC charge
//				MHCk_QQ[j] -= ET/gC_MHC
//				MHCk_QQ[j-1] += ET/gC_MHC
//				
//				// Keep track of total charge transfered to the Anode
//				Ea_QQ 		+= ET
//			endif
//		endfor
//		
//		Total_QQ += Ea_QQ
//		
//		endif
//		
//	endfor
//	
//	return Total_QQ/tt
//End


































//// *** Calculate the Rate constant for Complex-to-MHC electron transfer
//Function Rate_Respiration_MHC(Eh_mhc,QQ,Qmax,cAcRed,cAcOx)
//	Variable Eh_mhc,QQ,Qmax,cAcRed,cAcOx
//	
//	NVAR gEh_resp 		= root:Biofilm:gEh_resp
//	NVAR gReorgE 		= root:Biofilm:gReorgE
//	
//	// Determine the Nernstian contributions to the DG.
//	// The acetate takes a familiar form. 
//	Variable 
//	
//	// For the MHC's there is only a Nernstian term for: 
//	// 	1. First charge state for MHC oxidization
//	// 	2. Last charge state for MHC reduction
//	// However, we assume Complex-to-MHC ET to be irreversible
//	Variable Nernst_MHC 	= cR*298*MHCk_Nernst_Red(QQ,Qmax)
//	
//	Variable PotDiff 		= cFaraday*(gEh_resp - Eh_mhc)
//	
//	// Calculate the free energy change (in J/mol)
//	Variable DG 			= cFaraday*(gEh_resp - Eh_mhc) + (Nernst_Ac - Nernst_MHC)
//	
//	// Convert to electron Volts
//	Variable DGeV 			= Dg/cFaraday
//	
//	//  Calculate electron transfer activation energy from Marcus Theory
//	Variable  DGa			= MarcusActivation(DGeV,gReorgE)
//	
//	// Finally, calculate the rate constant for electron transfer
//	Variable Ket 			= exp(-(cFaraday*DGa)/(cR*298))
//	
//	if (DG < 0)
//		return Ket
//	else
//		return 0
//	endif
//End
//
//Function MarcusActivation(DG,lambda)
//	Variable DG, lambda
//	
//	return (lambda + DG)^2/(4*lambda)
//End
//
//
//
//
//
//
//
//
//Function PoiseAnodePotential(tt,Ea, C_Eresp_Tot,C_mhc, C_X,C_e,C_AcRed,C_AcOx,CVqq)
//	Variable tt,Ea,C_Eresp_Tot,C_mhc,&C_X,&C_e,&C_AcRed,&C_AcOx, &CVqq
//	
//	NVAR gSA 				= root:Biofilm:gSA
//	NVAR gQMax 			= root:Biofilm:gQMax
//	NVAR gQMax 			= root:Biofilm:gQMax
//	
//	NVAR gK1resp 			= root:Biofilm:gK1resp
//	NVAR gK2resp 			= root:Biofilm:gK2resp
//	
//	WAVE cXt 				= root:Biofilm:cXt
//	WAVE cEt 				= root:Biofilm:cEt
//	WAVE cAcRed 			= root:Biofilm:cAcRed
//	WAVE cAcOx 			= root:Biofilm:cAcOx
//	
//	WAVE cQQ 				= root:Biofilm:cQQ
//	WAVE cKresp 			= root:Biofilm:cKresp
//	WAVE Nernst_MHC 		= root:Biofilm:Nernst_MHC
//	WAVE Nernst_Acetate 	= root:Biofilm:Nernst_Acetate
//	WAVE Redox_MHC 		= root:Biofilm:Redox_MHC
//	WAVE dE_Anode			= root:Biofilm:dE_Anode
//	
//	// Initialize the concentration-vs-time waves
//	cQQ 		= 0				// The MHC charge state
//	
//	cXt 			= 0				// The acetate-enzyme complex
//	cXt[0] 		= C_X
//	
//	cEt 			= 0				// The electrons in theMHCs
//	cEt[0] 		= C_e
//	
//	cAcRed 		= 0				// The acetate concentration
//	cAcRed[0] 	= C_AcRed
//	cAcOx 		= 0
//	cAcOx[0] 	= C_AcOx
//		
//	// Work out the incremental time step
//	Variable i, dI, nPts = DimSize(cXt,0), small=1e-6
//	Variable dt = tt/nPts
//	
//	Variable C_Eresp_Free 			// the number of unbound respiration enzymes
//	Variable QQ, QRatio, C_MHCk_Ox, C_MHCk_Red, Eh_mhc, Kresp, Kanode, Kf, Kr
//
//	// The incremental changes in variables
//	Variable dXt, dE_MHCk_Red, dE_respiration, dE_anode_Ox, dE_anode_Red, dE_anode_Tot
//	
//	// Loop through small time increments
//	for (i=0;i<NPts-1;i+=1)
//	
//		// === UPDATE the MHC CHARGE STATE
//	
//		// The mean charge state of the MHCs
//		QQ 				= MHCk_Charge(cEt[i],C_mhc)
//		QQ 				= min(QQ,gQMax-small)
//		QQ 				= max(QQ,small)
//		
//		cQQ[i+1] 		= QQ
//		QRatio 			= QQ/gQMax
//		
//		// The Eh of the MHCs - a linear function of charge state, QQ
//		Eh_mhc 		= MHCk_RedoxPotential(QQ,gQmax)
//		
//		// The effective concentration of the MHCs for oxidation or reduction
//		// Confusing notation. The suffixes don't mean "conc of ox form"
//		// ... they mean "effective concentration for oxidation reactions"
//		if (1)
//			// This should be the simples approach ... the MHC concentration does not change with charge state. 
//			C_MHCk_Ox 		= C_mhc		
//			C_MHCk_Red 	= C_mhc
//		else
//			// This did not quite work as expected
//			C_MHCk_Ox 		= MHCk_Concentration_Ox(QRatio,C_mhc)		
//			C_MHCk_Red 	= MHCk_Concentration_Red(QRatio,C_mhc)	
//		endif
//		
//		// === CALCULATE ENZYMATIC REDUCTION DUE TO RESPIRATION
//		
//		// Rate constant for Complex-to-MHC electron transfer
//		Kresp 		= Rate_Respiration_MHC(Eh_mhc,QQ,gQmax,cAcRed[i],cAcOx[i])
//		cKresp[i+1] = Kresp
//		
//		// The Nernstian contributions to the DG, in kJ/mol
////		Nernst_MHC[i+1] 		= cR*298*MHCk_Nernst2(QQ,gQmax)/1000
////		Nernst_Acetate[i+1] 	= cR*298*ln(cAcOX[i]/cAcRed[i])/1000
////		Redox_MHC[i+1] 		= cFaraday*Eh_mhc/1000
//		
//		// The change in the number of acetate-enzyme complexes ...
//		C_Eresp_Free 	= C_Eresp_Tot - cXt[i]
//		dXt 				= dt*gK1resp*cAcRed[i]*C_Eresp_Free - dt*gK2resp*cXt[i] - dt*Kresp*cXt[i]*C_MHCk_Red
//		cXt[i+1] 		= cXt[i] + dXt
//		
//		// Rate constants for MHC-to-Anode electron transfer
//		if (0)
//			Kf 			= Rate_BV_MHCk_Anode(Eh_mhc,Ea,0)
//			Kr 			= Rate_BV_MHCk_Anode(Eh_mhc,Ea,1)
//		elseif (1)
//			Kf 			= Rate_MH_MHCk_Anode(Eh_mhc,Ea,0)
//			Kr 			= Rate_MH_MHCk_Anode(Eh_mhc,Ea,1)
//		endif
//		
//		if (0)
//			Kr=0
//		endif
//
//		// The change in the number of electrons in the MHCs due to respiration ... 
//		dE_respiration 	= dt * Kresp*cXt[i]*C_MHCk_Red
//		
//		// ... and electron transfer with the anode
//		dE_anode_Red	= dt * Kf*C_MHCk_Ox * gSA			// <--- forward ET reduces the anode and oxidizes the MHCs
//		dE_anode_Ox	= dt * Kr*C_MHCk_Red * gSA
//		dE_anode_Tot 	= dE_anode_Red - dE_anode_Ox
//		
//		dE_Anode[i+1] = dE_anode_Tot
//		
//		dE_MHCk_Red 	= dE_respiration - dE_anode_Red + dE_anode_Ox
//		
//		// For large step sizes, it is possible that a small anode reduction will lead to a negative "electron concentration"
//		cEt[i+1] 		= max(0,cEt[i] + dE_MHCk_Red)
//		
//		// Update the acetate concentrations
//		cAcRed[i+1] 	= cAcRed[i] - dE_respiration
//		cAcOx[i+1] 	= cAcOX[i] + dE_respiration
//		
//		
//		if (QQ>5)
//		
//			BreakPt()
//		endif
//		
//	endfor
//	
//	// Update these variables ...
//	CVqq 		= QQ
//	C_X 		= cXt[NPts-1]
//	C_e			= cEt[NPts-1]
//	C_AcRed	= cAcRed[NPts-1]
//	C_AcOx		= cAcOx[NPts-1]
//	
//	// ... and return the number of electrons transferred to the anode. 
//	dI = area(dE_Anode)
//	return dI
//End
//
//
//
//
//
//
//
//
//// Poise the system at a single anode potential for time tt, and record the current transfered to the Anode. 
//Function SingleCVPotential(tt,Ea, C_Eresp_Tot,C_mhc, C_X,C_e,C_AcRed,C_AcOx,CVqq)
//	Variable tt,Ea,C_Eresp_Tot,C_mhc,&C_X,&C_e,&C_AcRed,&C_AcOx, &CVqq
//	
//	NVAR gSA 		= root:Biofilm:gSA
//	NVAR gQMax 	= root:Biofilm:gQMax
//	
//	NVAR gK1resp 	= root:Biofilm:gK1resp
//	NVAR gK2resp 	= root:Biofilm:gK2resp
//	
//	WAVE cXt 		= root:Biofilm:cXt
//	WAVE cEt 		= root:Biofilm:cEt
//	WAVE cAcRed 	= root:Biofilm:cAcRed
//	WAVE cAcOx 	= root:Biofilm:cAcOx
//	
//	WAVE cQQ 				= root:Biofilm:cQQ
//	WAVE cKresp 			= root:Biofilm:cKresp
//	WAVE Nernst_MHC 		= root:Biofilm:Nernst_MHC
//	WAVE Nernst_Acetate 	= root:Biofilm:Nernst_Acetate
//	WAVE Redox_MHC 		= root:Biofilm:Redox_MHC
//	WAVE dE_Anode			= root:Biofilm:dE_Anode
//	
//	// Initialize the concentration-vs-time waves
//	cQQ 		= 0				// The MHC charge state
//	
//	cXt 			= 0				// The acetate-enzyme complex
//	cXt[0] 		= C_X
//	
//	cEt 			= 0				// The electrons in theMHCs
//	cEt[0] 		= C_e
//	
//	cAcRed 		= 0				// The acetate concentration
//	cAcRed[0] 	= C_AcRed
//	cAcOx 		= 0
//	cAcOx[0] 	= C_AcOx
//		
//	// Work out the incremental time step
//	Variable i, dI, nPts = DimSize(cXt,0), small=1e-6
//	Variable dt = tt/nPts
//	
//	Variable C_Eresp_Free 			// the number of unbound respiration enzymes
//	Variable QQ, QRatio, C_MHCk_Ox, C_MHCk_Red, Eh_mhc, Kresp, Kanode, Kf, Kr
//
//	// The incremental changes in variables
//	Variable dXt, dE_MHCk_Red, dE_respiration, dE_anode_Ox, dE_anode_Red, dE_anode_Tot
//	
//	// Loop through small time increments
//	for (i=0;i<NPts-1;i+=1)
//	
//		// === UPDATE the MHC CHARGE STATE
//	
//		// The mean charge state of the MHCs
//		QQ 				= MHCk_Charge(cEt[i],C_mhc)
//		QQ 				= min(QQ,gQMax-small)
//		QQ 				= max(QQ,small)
//		
//		cQQ[i+1] 		= QQ
//		QRatio 			= QQ/gQMax
//		
//		// The Eh of the MHCs - a linear function of charge state, QQ
//		Eh_mhc 		= MHCk_RedoxPotential(QQ,gQmax)
//		
//		// The effective concentration of the MHCs for oxidation or reduction
//		// Confusing notation. The suffixes don't mean "conc of ox form"
//		// ... they mean "effective concentration for oxidation reactions"
//		if (1)
//			// This should be the simples approach ... the MHC concentration does not change with charge state. 
//			C_MHCk_Ox 		= C_mhc		
//			C_MHCk_Red 	= C_mhc
//		else
//			// This did not quite work as expected
//			C_MHCk_Ox 		= MHCk_Concentration_Ox(QRatio,C_mhc)		
//			C_MHCk_Red 	= MHCk_Concentration_Red(QRatio,C_mhc)	
//		endif
//		
//		// === CALCULATE ENZYMATIC REDUCTION DUE TO RESPIRATION
//		
//		// Rate constant for Complex-to-MHC electron transfer
//		Kresp 		= Rate_Respiration_MHC(Eh_mhc,QQ,gQmax,cAcRed[i],cAcOx[i])
//		cKresp[i+1] = Kresp
//		
//		// The Nernstian contributions to the DG, in kJ/mol
////		Nernst_MHC[i+1] 		= cR*298*MHCk_Nernst2(QQ,gQmax)/1000
////		Nernst_Acetate[i+1] 	= cR*298*ln(cAcOX[i]/cAcRed[i])/1000
////		Redox_MHC[i+1] 		= cFaraday*Eh_mhc/1000
//		
//		// The change in the number of acetate-enzyme complexes ...
//		C_Eresp_Free 	= C_Eresp_Tot - cXt[i]
//		dXt 				= dt*gK1resp*cAcRed[i]*C_Eresp_Free - dt*gK2resp*cXt[i] - dt*Kresp*cXt[i]*C_MHCk_Red
//		cXt[i+1] 		= cXt[i] + dXt
//		
//		// Rate constants for MHC-to-Anode electron transfer
//		if (0)
//			Kf 			= Rate_BV_MHCk_Anode(Eh_mhc,Ea,0)
//			Kr 			= Rate_BV_MHCk_Anode(Eh_mhc,Ea,1)
//		elseif (1)
//			Kf 			= Rate_MH_MHCk_Anode(Eh_mhc,Ea,0)
//			Kr 			= Rate_MH_MHCk_Anode(Eh_mhc,Ea,1)
//		endif
//		
//		if (0)
//			Kr=0
//		endif
//
//		// The change in the number of electrons in the MHCs due to respiration ... 
//		dE_respiration 	= dt * Kresp*cXt[i]*C_MHCk_Red
//		
//		// ... and electron transfer with the anode
//		dE_anode_Red	= dt * Kf*C_MHCk_Ox * gSA			// <--- forward ET reduces the anode and oxidizes the MHCs
//		dE_anode_Ox	= dt * Kr*C_MHCk_Red * gSA
//		dE_anode_Tot 	= dE_anode_Red - dE_anode_Ox
//		
//		dE_Anode[i+1] = dE_anode_Tot
//		
//		dE_MHCk_Red 	= dE_respiration - dE_anode_Red + dE_anode_Ox
//		
//		// For large step sizes, it is possible that a small anode reduction will lead to a negative "electron concentration"
//		cEt[i+1] 		= max(0,cEt[i] + dE_MHCk_Red)
//		
//		// Update the acetate concentrations
//		cAcRed[i+1] 	= cAcRed[i] - dE_respiration
//		cAcOx[i+1] 	= cAcOX[i] + dE_respiration
//		
//		
//		if (QQ>5)
//		
//			BreakPt()
//		endif
//		
//	endfor
//	
//	// Update these variables ...
//	CVqq 		= QQ
//	C_X 		= cXt[NPts-1]
//	C_e			= cEt[NPts-1]
//	C_AcRed	= cAcRed[NPts-1]
//	C_AcOx		= cAcOx[NPts-1]
//	
//	// ... and return the number of electrons transferred to the anode. 
//	dI = area(dE_Anode)
//	return dI
//End
//
//
//
//
//// 	***********************************************************************************
////	*************		RESPIRATION RATE EQUATIONS	**************************************
//
//// *** Calculate the Redox potential for the MHCs
////		This is just a linear function
//Function MHCk_RedoxPotential(QQ,Qmax)
//	Variable QQ,Qmax
//	
//	NVAR gEh_MHCk_0 		= root:Biofilm:gEh_MHCk_0
//	NVAR gEh_MHCk_DQ 		= root:Biofilm:gEh_MHCk_DQ
//	
//	Variable Eh_mhc, QRatio = QQ/QMax
//	
//	Eh_mhc = gEh_MHCk_0 + gEh_MHCk_DQ*QRatio
//	
//	return Eh_mhc
//End
//
//
//
//// 	***********************************************************************************
////	*************			MHC PROPERTIES AS A FUNCTION OF CHARGE STATE		***********************
//
//// *** Calculate EHmhc, the redox potential that is determined by the charge state
//// 	Inputs: 
////	 		cE 		= the concentration of electrons in the MHCs
//// 			Emhc 	= MHC enzyme concentration
//// 			Qmax 	= # charge states per MHC
//Function MHCk_Charge(cE,cMHC)
//	Variable cE,cMHC
//	
//	Variable QQ 	= cE/cMHC
//	
//	return QQ
//End
//
//// *** When the MHC is in the first or the last charge states, then we need a Nernstian term
//Function MHCk_Nernst_Red(QQ,Qmax)
//	Variable QQ,Qmax
//	
//	Variable QRatio = QQ/QMax
//	
//	if (QRatio < 0.9)
//		return 0
//	else
//		return ln(1 - QRatio)
//	endif
//End
//
//Function MHCk_Nernst_Ox(QQ,Qmax)
//	Variable QQ,Qmax
//	
//	Variable QRatio = QQ/QMax
//	
//	if (QRatio > 0.1)
//		return 0
//	else
//		return ln(QRatio)
//	endif
//End
//
//// !*!*!*! I think the estimates below are COMPLETELY WRONG and the MHC concentration should not vary with QQ
//
//Function MHCk_Concentration_Eff(QRatio,C_mhc)
//	Variable Qratio, C_mhc
//	
//	// One factor that determines the sharpness of the shoulders
//	Variable cc = 10	
//	
//	// Ensures the function equals zero at x = 1
//	Variable bb 	= tanh(sqrt(cc))
//	
//	// Shifts the function from 0 < x < 1
//	Variable x 	= 2*QRatio - 1
//	
//	// The function itself
//	Variable Fn 	= 1 - (atanh(bb*x^3))^2/cc
//	
//	Variable C_MHCk_eff = C_mhc * Fn
//	
//	return max(0,C_MHCk_eff)
//End
//
//// *** Calculate the effective concentration of MHCs as a function of charge state, Q ...
//
//// 	... for the case in which the MHC reacts with an oxidant ...
//Function MHCk_Concentration_Ox(QRatio,C_mhc)
//	Variable QRatio,C_mhc
//	
//	Variable C_MHCk_Ox
//	
//	Variable cc = 10	
//	Variable bb 	= tanh(sqrt(cc))
//	Variable x 	= 2*QRatio - 1
//	
//	if (QRatio > 0.5)
//		C_MHCk_Ox 	= C_mhc
//	else
//		C_MHCk_Ox 	= C_mhc * (1 - (atanh(bb*x^3))^2/cc)
//	endif
//	
//	return max(0,C_MHCk_Ox)
//End
//
//// ... and the case in which the MHC reacts with a reductant. 
//Function MHCk_Concentration_Red(QRatio,C_mhc)
//	Variable QRatio,C_mhc
//	
//	Variable C_MHCk_Red
//	
//	Variable cc = 10	
//	Variable bb 	= tanh(sqrt(cc))
//	Variable x 	= 2*QRatio - 1
//	
//	if (QRatio > 0.5)
//		C_MHCk_Red 	= C_mhc * (1 - (atanh(bb*x^3))^2/cc)
//	else
//		C_MHCk_Red 	= C_mhc
//	endif
//	
//	return max(0,C_MHCk_Red)
//End
//
//// *** Approximate the natural logarithm of the reaction quotient. 
////		This could use some more rigorous derivation
//Function MHCk_Nernst(QQ,Qmax)
//	Variable QQ,Qmax
//	
//	Variable Nernst, QRatio = QQ/QMax
//	
//	Nernst = (1+atanh((2*QRatio-1)^11))
//	
//	return Nernst
//End
//
//// 	***********************************************************************************
//
//
//
////	*** Function to poise the system at a single electrode potential
//// 	This is the function used to play with the kinetic equations prior to implementing CV
////	Inputs: 
//// 			tt 	= time at a single anode potential
//// 			cXi 	= initial concentration of the Acetate--Enzyme complex
//// 			cEi 	= initial concentration of electrons in the MHCs
////
//// 			C_AcRed 	= "reduced" acetate concentration
//// 			C_AcOx 		= "oxidized" acetate concentration
//// 			C_resp 		= respiration enzyme concentration
//// 			C_mhc 		= respiration enzyme concentration
////
//// 			Ea 			= Anode potential
//
//Function SinglePotentialPoise(tt,C_X,C_e,C_AcRed,C_AcOx,C_Eresp_Tot,C_mhc,Ea)
//	Variable tt,C_X,C_e,C_AcRed,C_AcOx,C_Eresp_Tot,C_mhc,Ea
//	
//	NVAR gSA 		= root:Biofilm:gSA
//	NVAR gQMax 	= root:Biofilm:gQMax
//	
//	NVAR gK1resp 	= root:Biofilm:gK1resp
//	NVAR gK2resp 	= root:Biofilm:gK2resp
//	
//	WAVE cXt 		= root:Biofilm:cXt
//	WAVE cEt 		= root:Biofilm:cEt
//	WAVE cAcRed 	= root:Biofilm:cAcRed
//	WAVE cAcOx 	= root:Biofilm:cAcOx
//	
//	WAVE cQQ 		= root:Biofilm:cQQ
//	WAVE cKresp 	= root:Biofilm:cKresp
//	WAVE Nernst_MHC 		= root:Biofilm:Nernst_MHC
//	WAVE Nernst_Acetate 	= root:Biofilm:Nernst_Acetate
//	WAVE Redox_MHC 		= root:Biofilm:Redox_MHC
//	WAVE dE_Anode			= root:Biofilm:dE_Anode
//	
//	// Initialize the concentration-vs-time waves
//	cXt[0] 		= C_X		// The acetate-enzyme complex
//	cEt[0] 		= C_e		// The electrons in theMHCs
//	
//	cAcRed[0] 	= C_AcRed
//	cAcOx[0] 	= C_AcOx
//		
//	// Work out the incremental time step
//	Variable i, dI, nPts = DimSize(cXt,0), small=1e-6
//	Variable dt = tt/nPts
//	
//	Variable C_Eresp_Free 			// the number of unbound respiration enzymes
//	Variable QQ, QRatio, C_MHCk_Ox, C_MHCk_Red, Eh_mhc, Kresp, Kanode, Kf, Kr
//
//	// The incremental changes in variables
//	Variable dXt, dE_MHCk_Red, dE_respiration, dE_anode_Ox, dE_anode_Red, dE_anode_Tot
//	
//	// Loop through small time increments
//	for (i=0;i<NPts-1;i+=1)
//	
//		// === UPDATE the MHC CHARGE STATE
//	
//		// The mean charge state of the MHCs
//		QQ 				= MHCk_Charge(cEt[i],C_mhc)
//		QQ 				= min(QQ,gQMax-small)
//		QQ 				= max(QQ,small)
//		cQQ[i+1] 		= QQ
//		QRatio 			= QQ/gQMax
//		
//		// The Eh of the MHCs - a linear function of charge state, QQ
//		Eh_mhc 		= MHCk_RedoxPotential(QQ,gQmax)
//		
//		// The effective concentration of the MHCs for oxidation or reduction
//		C_MHCk_Ox 		= MHCk_Concentration_Ox(QRatio,C_mhc)		// <--- Confusing notation. The suffixes don't mean "conc of ox form"
//		C_MHCk_Red 	= MHCk_Concentration_Red(QRatio,C_mhc)		// ... they mean "effective concentration for oxidation reactions"
//		
//		// === CALCULATE ENZYMATIC REDUCTION DUE TO RESPIRATION
//		
//		// Rate constant for Complex-to-MHC electron transfer
//		Kresp 		= Rate_Respiration_MHC(Eh_mhc,QQ,gQmax,cAcRed[i],cAcOx[i])
//		cKresp[i+1] = Kresp
//		
//		// The Nernstian contributions to the DG, in kJ/mol
//		Nernst_MHC[i+1] 		= cR*298*MHCk_Nernst(QQ,gQmax)/1000
//		Nernst_Acetate[i+1] 	= cR*298*ln(cAcOX[i]/cAcRed[i])/1000
//		Redox_MHC[i+1] 		= cFaraday*Eh_mhc/1000
//		
//		// The change in the number of acetate-enzyme complexes ...
//		C_Eresp_Free 	= C_Eresp_Tot - cXt[i]
//		dXt 				= dt*gK1resp*cAcRed[i]*C_Eresp_Free - dt*gK2resp*cXt[i] - dt*Kresp*cXt[i]*C_MHCk_Red
//		cXt[i+1] 		= cXt[i] + dXt
//		
//		// Rate constants for MHC-to-Anode electron transfer
//		Kf 			= Rate_MH_MHCk_Anode(Eh_mhc,Ea,0)
//		Kr 			= Rate_MH_MHCk_Anode(Eh_mhc,Ea,1)
//		
//		Kr=0
//
//		// The change in the number of electrons in the MHCs due to respiration ... 
//		dE_respiration 	= dt * Kresp*cXt[i]*C_MHCk_Red
//		
//		// ... and electron transfer with the anode
//		dE_anode_Red	= dt * Kf*C_MHCk_Ox * gSA			// <--- forward ET reduces the anode and oxidizes the MHCs
//		dE_anode_Ox	= dt * Kr*C_MHCk_Red * gSA
//		dE_anode_Tot 	= dE_anode_Red - dE_anode_Ox
//		
//		dE_Anode[i+1] = dE_anode_Tot
//		
//		dE_MHCk_Red 	= dE_respiration - dE_anode_Red + dE_anode_Ox
//		
//		// For large step sizes, it is possible that a small anode reduction will lead to a negative "electron concentration"
//		cEt[i+1] 		= max(0,cEt[i] + dE_MHCk_Red)
//		
//		// Update the acetate concentrations
//		cAcRed[i+1] 	= cAcRed[i] - dE_respiration
//		cAcOx[i+1] 	= cAcOX[i] + dE_respiration
//		
//		
//		if (QQ>5)
//		
//			BreakPt()
//		endif
//		
//	endfor
//	
//	dI = area(dE_Anode)
//	
//End
//
//Function BreakPt()
//
//	Variable n = 3
//
//End
//
