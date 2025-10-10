#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Constant c_nmtom 			= 1e-9
Constant c_nm2tom2 		= 1e-18
Constant c_nm3tom3 		= 1e-27
Constant c_KPre 			= -0.000403599	//  -1/(8.31446*298)		// -1/KT in J/mol
Constant c_vH2Om3 			= 2.99694e-29 	// m3/molecule
Constant c_vH2Onm3 		= 0.0299694 		// nm3/molecule
Constant c_Po 				= 101e3			// 101,000 Pa is one atmosphere

// convert kT into kJ/mol
Function RoomTempEnergy()

	Variable kT 		= 298 * cBoltzmann

	Variable Ert 	= cAvogadro * kT
	
	print Ert
end

// Continuous water speciation 
// Integer calcium speciation 
Function SurfaceForces6()

	NewDataFolder /O/S root:SFA
		
		NVAR gaW 				= root:SFA:gaW			// Activity of water in external reservoir
		NVAR gBMod 			= root:SFA:gBMod		// Bulk modulus of water, in GPa
		NVAR gContact 		= root:SFA:gContact	// Not sure ... probably a finite contact area 
		
		Variable Separation, Point, P_interlayer, i, j
		Variable Vol_Interlayer, Vol_Difference, BulkModulus
		
		// Calculate the thickness when bound water first 'touches"
		Variable NH2O 		= 32						// Total number of water molecules in 1 x 1 x 1 nm3 voluem
		Variable DeltaMax 	= (32 * c_vH2Onm3) 	// 0.957 nm
		
		DeltaMax = 1.2
		
		Variable DeltaMin 	= 0.05, NDeltaPts=200
		Variable dDelta 	= (DeltaMax-DeltaMin)/(NDeltaPts)
		
		SetDataFolder root:SFA:water 
			String /G name 			= "water"
			Variable /G charge 	= 0		// Electrostatic charge 
			Variable /G steps 		= 3		// Number of sequential dehydration reactions
			Variable /G sites 		= 1		// A single conceptual water binding site per nm2 on each surface
			
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV, VCum
			Make /D/O/N=(steps+1) Speciation, Hydration=0
			
			VCum[] 	= sum(DV,0,p)
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs=NaN											// Keep track of the pressure-dependent equilibrium constants
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations=NaN							// Keep track of the site average occupancies 
			Make /O/D/N=(NDeltaPts+1) Hydrations=NaN										// Keep track of the site average occupancies 
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
		SetDataFolder ::
		
		SetDataFolder root:SFA:calcium
			String /G name 		= "calcium"
			Variable /G charge 	= 2
			Variable /G steps 		= 1
			Variable /G sites 		= 1
			
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV, VCum
			Make /D/O/N=(steps+1) Speciation, Hydration=0
			
			VCum[] 	= sum(DV,0,p)
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs=NaN											// Keep track of the pressure-dependent equilibrium constants
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations=NaN							// Keep track of the site average occupancies 
			Make /O/D/N=(NDeltaPts+1) Hydrations=NaN										// Keep track of the site average occupancies 
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
		SetDataFolder ::
	
		
		// The Hydration Force
		Make /O/D/N=3 P_Coefs
		Make /O/D/N=(NDeltaPts+1) F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		
		P_Hyd = 0 
		
//		Variable Contact = 2
//		P_Coefs[1] = Contact
//		P_Coefs[2] = gaW
		
		Variable Contact 	= P_Coefs[1]
		Variable aW 			= P_Coefs[2]
		
		for (Separation=DeltaMax;Separation>DeltaMin;Separation-=dDelta)
		
			P_Coefs[0] 	= Separation
			Point 		= x2pnt(P_Hyd,Separation)
			
			// Calculate the self-consistent pressure
			FindRoots /Q /L=-1e6/H=1e8 PressureFunction6, P_Coefs
			P_interlayer 		= V_root
			P_Hyd[Point] 		= P_interlayer
			
			// Speciate the absorbate sites at the self-consistent pressure
			// ... and return the volume of water on both surfaces in m3 per m2
			Variable VolAdsH2O	 		= SiteEquilibrium6(P_interlayer, 0, aW,"water",Point)
			Variable VolAdsCa	 		= 0.99*SiteEquilibrium6(P_interlayer, Contact, aW,"calcium",Point)
			
			// Now recalculate the pressure
			Vol_Interlayer 	= (Separation * 1 * 1) * c_nmtom			// m3
			Vol_Difference 	= (VolAdsH2O + VolAdsCa) - Vol_Interlayer
			BulkModulus 		= (2.20 + 6.17e-09 * P_interlayer)					// 
			P_Interlayer 	= (Vol_Difference/Vol_Interlayer) * (1e9*BulkModulus)
			F_Hyd[Point]		= P_Interlayer
	
			// The volume of water molecules per m2 on both surfaces
			H2O_Hyd[Point] 		= VolAdsH2O + VolAdsCa

			// The mass density of water molecules - NOTE factor of 2 
			Rho_Hyd[Point] 		= (H2O_Hyd[Point]) / (1e-9 * Separation)
			
		endfor
		
//		F_Hyd = (P_Hyd-c_Po)/1e6 		// Convert to MPa

	SetDataFolder root:
End

// Units: Pressure (Pa); Contact (nm2)
// Output: The normalized abundance of sites with different hydration states, Speciation
Function SiteEquilibrium6(Pressure,Contact,aW,AdsName,pnt)
	Variable Pressure, Contact, aW, pnt
	String AdsName
	
	DFREF AdsDF 			= root:SFA:$AdsName
	WAVE EK 				= AdsDF:EK
	WAVE EKs 				= AdsDF:EKs
	WAVE Speciation 	= AdsDF:Speciation
	WAVE Speciations 	= AdsDF:Speciations
	WAVE Hydration 		= AdsDF:Hydration
	WAVE Hydrations 	= AdsDF:Hydrations
	WAVE DG 				= AdsDF:DG
	WAVE DV 				= AdsDF:DV
	WAVE VCum 			= AdsDF:VCum
	WAVE DH2O 			= AdsDF:DH2O
	NVAR sites 			= AdsDF:sites				// Number of sites per nm2
	
	Variable NSteps 	= DimSize(DG,0)
	Variable n, m, dVmol, K0, KP, SpecNorm, SitesTot
	
	Speciation 		= 0
	Speciation[0] 	= 1 													// Start with the site having zero bound waters or cations
	
	Variable Pdiff 		= Pressure - c_Po								// The pressure difference between interlayer and reservoir Po = 101e3 Pa
	
//	Pdiff 	= (Pdiff < 0) ? 0.5*Pdiff : Pdiff
	
	for (n=0;n<NSteps;n+=1)
	
		K0 				= exp(c_KPre * DG[n])							// The standard (zero-pressure) equilibrium constant, K
		dVmol 			= cAvogadro * c_nm3tom3 * DV[n]			// The change in volume per mole for the reaction step (m3/mol)
		KP 				= exp(c_KPre * dVmol*Pdiff) 				// The 
		EK[n] 			= K0 * KP											// The modified K
		m 					= DH2O[n]											// Number of waters per step
		
		Speciation[n+1] = K0 * KP * Speciation[n] * aW^m 	
				
	endfor
	
	SpecNorm 			= sum(Speciation)
	Speciation 		/= SpecNorm
	
	if (Contact > 0)
		Speciation 		*= Contact
		Speciation[]		= trunc(Speciation[p])
		Speciation 		/= Contact
		SpecNorm 			= sum(Speciation)
		Speciation 		/= SpecNorm
	endif 
	
	Hydration[0]  	= 0
	Hydration[1,] 	= Speciation[p] * VCum[p-1]
	
	if (pnt > -1)
		EKs[pnt][] 				= EK[q]
		Speciations[pnt][] 	= Speciation[q]
	endif
	
	// return the total volume of water on both sides in m3 oer m2
	return 2 * sites * sum(Hydration) * c_nmtom
	
End

Function PressureFunction6(P_coefs,P_Input)
	Variable P_Input
	Wave P_coefs
	
	Variable P_Interlayer = PressureInterlayer6(P_coefs,P_Input)
	
	// Return the difference
	return (P_Interlayer - P_Input)
End

Function PressureInterlayer6(P_coefs,P_Input)
	Wave P_coefs
	Variable P_Input
	
	Variable Separation 	= P_coefs[0]
	Variable Contact 		= P_coefs[1]
	Variable aW 				= P_coefs[2]
	
	// Speciate the absorbate sites at the input pressure ...
	// ... and return the volume of water on both surfaces in m3 per m2
	Variable VolAdsH2O	 		= SiteEquilibrium6(P_Input, 0, aW, "water",-1)
	
	Variable VolAdsCa	 		= SiteEquilibrium6(P_Input, Contact, aW, "calcium",-1)
	
	// Calculate the geometric volume of the interlayer
	Variable Vol_Interlayer 	= (Separation * 1 * 1) * c_nmtom			// m3
	
	Variable Vol_Difference 	= (VolAdsH2O + VolAdsCa) - Vol_Interlayer
	
	Variable BulkModulus 		= 1e9 * (2.20 + 6.17e-09 * P_Input)					// 
	
//	BulkModulus /= 4
	
	Variable P_Interlayer 	= BulkModulus * (Vol_Difference/Vol_Interlayer)
	
	return P_Interlayer
End

Function PressureConvergenceCalc6(Separation)
	Variable Separation
	
	NVAR gaW 				= root:SFA:gaW			// Activity of water in external reservoir
	NVAR gVM 				= root:SFA:gVM			// Volume of one water molecule at 1 atm
	NVAR gBMod 			= root:SFA:gBMod		// Bulk modulus of water, in GPa
	NVAR gContact 		= root:SFA:gContact	// Not sure ... probably a finite contact area 
	
	Make /O/D/N=3 root:P_coefs /WAVE=P_coefs
	P_coefs[0] = Separation
	
	// Pressure axis in Pa
	Make /O/D/N=2000 Pressure_axis, Pressure_guess, Pressure_calc, Pressure_diff
	Pressure_axis[] 	= -1e8 + p*1e5
	
	Duplicate /O/D Pressure_calc, Pressure_Old
	
	Pressure_guess 		= Pressure_axis
	Pressure_calc[] 	= PressureInterlayer6(P_coefs,Pressure_axis[p])
	
	FindRoots /Q /L=-1e6/H=1e8 PressureFunction6, P_Coefs

	Print " Interlayer pressure is",V_root/1e6,"MPa" 
End








// Add a hydrated counterion 
// THIS IS GOOD - GIVES 10 MPa FORCES FOR WATER AND Ca BINDING, but not oscillations or negative pressure. 
Function SurfaceForces5()

	NewDataFolder /O/S root:SFA
		
		NVAR gaW 				= root:SFA:gaW			// Activity of water in external reservoir
		NVAR gBMod 			= root:SFA:gBMod		// Bulk modulus of water, in GPa
		NVAR gContact 		= root:SFA:gContact	// Not sure ... probably a finite contact area 
		
		Variable Separation, Point, P_interlayer, i, j, Contact = 0
		
		// Calculate the thickness when bound water first 'touches"
		Variable NH2O 		= 32						// Total number of water molecules in 1 x 1 x 1 nm3 voluem
		Variable DeltaMax 	= (32 * c_vH2Onm3) 	// 0.957 nm
		
		DeltaMax = 1.2
		
		Variable DeltaMin 	= 0.05, NDeltaPts=200
		Variable dDelta 	= (DeltaMax-DeltaMin)/(NDeltaPts)
		
		SetDataFolder root:SFA:water 
			String /G name 			= "water"
			Variable /G charge 	= 0		// Electrostatic charge 
			Variable /G steps 		= 3		// Number of sequential dehydration reactions
			Variable /G sites 		= 1		// A single conceptual water binding site per nm2 on each surface
			
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV, VCum
			Make /D/O/N=(steps+1) Speciation, Hydration=0
			
			VCum[] 	= sum(DV,0,p)
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs=NaN											// Keep track of the pressure-dependent equilibrium constants
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations=NaN							// Keep track of the site average occupancies 
			Make /O/D/N=(NDeltaPts+1) Hydrations=NaN										// Keep track of the site average occupancies 
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
		SetDataFolder ::
		
		SetDataFolder root:SFA:calcium
			String /G name 		= "calcium"
			Variable /G charge 	= 2
			Variable /G steps 		= 1
			Variable /G sites 		= 1
			
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV, VCum
			Make /D/O/N=(steps+1) Speciation, Hydration=0
			
			VCum[] 	= sum(DV,0,p)
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs=NaN											// Keep track of the pressure-dependent equilibrium constants
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations=NaN							// Keep track of the site average occupancies 
			Make /O/D/N=(NDeltaPts+1) Hydrations=NaN										// Keep track of the site average occupancies 
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
		SetDataFolder ::
	
		
		// The Hydration Force
		Make /O/D/N=1 P_Coefs
		Make /O/D/N=(NDeltaPts+1) F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		
		P_Hyd = 0 
		
		for (Separation=DeltaMax;Separation>DeltaMin;Separation-=dDelta)
		
			P_Coefs[0] 	= Separation
			Point 		= x2pnt(P_Hyd,Separation)
			
			// Calculate the self-consistent pressure
			FindRoots /Q /L=-1e6/H=1e8 PressureFunction5, P_Coefs
			P_interlayer 		= V_root
			P_Hyd[Point] 		= P_interlayer
			
			// Speciate the absorbate sites at the self-consistent pressure
			// ... and return the volume of water on both surfaces in m3 per m2
			Variable VolAdsH2O	 		= SiteEquilibrium4(P_interlayer, Contact, gaW,"water",Point)
			Variable VolAdsCa	 		= SiteEquilibrium4(P_interlayer, Contact, gaW,"calcium",Point)
			
			// The volume of water molecules per m2 on both surfaces
			H2O_Hyd[Point] 		= VolAdsH2O + VolAdsCa

			// The mass density of water molecules - NOTE factor of 2 
			Rho_Hyd[Point] 		= (H2O_Hyd[Point]) / (1e-9 * Separation)
			
		endfor
		
		F_Hyd = (P_Hyd-c_Po)/1e6 		// Convert to MPa

	SetDataFolder root:
End

Function PressureFunction5(P_coefs,P_Input)
	Variable P_Input
	Wave P_coefs
	
	Variable Separation 	= P_coefs[0]
	
	Variable Contact 		= 0, aW=1
	
	// Speciate the absorbate sites at the input pressure ...
	// ... and return the volume of water on both surfaces in m3 per m2
	Variable VolAdsH2O	 		= SiteEquilibrium4(P_Input, Contact, aW, "water",-1)
	
	Variable VolAdsCa	 		= SiteEquilibrium4(P_Input, Contact, aW, "calcium",-1)
	
	// Calculate the geometric volume of the interlayer
	Variable Vol_Interlayer 	= (Separation * 1 * 1) * c_nmtom			// m3
	
	Variable Vol_Difference 	= (VolAdsH2O + VolAdsCa) - Vol_Interlayer
	
	Variable BulkModulus 		= (2.20 + 6.17e-09 * P_Input)					// 
	
	Variable P_Interlayer 	= (Vol_Difference/Vol_Interlayer) * (1e9*BulkModulus)
	
	// Return the difference
	return (P_Interlayer - P_Input)
End





// Start with water only. This gives ~ 10 MPa pressures for mildly unfavorable water binding (!)
Function SurfaceForces4()

	NewDataFolder /O/S root:SFA
		
		NVAR gaW 				= root:SFA:gaW			// Activity of water in external reservoir
		NVAR gBMod 			= root:SFA:gBMod		// Bulk modulus of water, in GPa
		NVAR gContact 		= root:SFA:gContact	// Not sure ... probably a finite contact area 
		
		Variable Separation, Point, P_interlayer, i, j, Contact = 0
		
		// Calculate the thickness when bound water first 'touches"
		Variable NH2O 		= 32						// Total number of water molecules in 1 x 1 x 1 nm3 voluem
		Variable DeltaMax 	= (32 * c_vH2Onm3) 	// 0.957 nm
		
		DeltaMax = 1.2
		
		Variable DeltaMin 	= 0.05, NDeltaPts=200
		Variable dDelta 	= (DeltaMax-DeltaMin)/(NDeltaPts)
		
		SetDataFolder root:SFA:water 
			String /G name 			= "water"
			Variable /G charge 	= 0		// Electrostatic charge 
			Variable /G steps 		= 3		// Number of sequential dehydration reactions
			Variable /G sites 		= 1		// A single conceptual water binding site per nm2 on each surface
			
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV, VCum
			Make /D/O/N=(steps+1) Speciation, Hydration=0
			
			VCum[] 	= sum(DV,0,p)
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs=NaN											// Keep track of the pressure-dependent equilibrium constants
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations=NaN							// Keep track of the site average occupancies 
			Make /O/D/N=(NDeltaPts+1) Hydrations=NaN										// Keep track of the site average occupancies 
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
		SetDataFolder ::
		
		// The Hydration Force
		Make /O/D/N=1 P_Coefs
		Make /O/D/N=(NDeltaPts+1) F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		
		P_Hyd = 0 
		
		for (Separation=DeltaMax;Separation>DeltaMin;Separation-=dDelta)
		
			P_Coefs[0] 	= Separation
			Point 		= x2pnt(P_Hyd,Separation)
			
			// Calculate the self-consistent pressure
			FindRoots /Q /L=-1e6/H=1e8 PressureFunction4, P_Coefs
			P_interlayer 		= V_root
			P_Hyd[Point] 		= P_interlayer
			
			// Speciate the absorbate sites at the self-consistent pressure
			// ... and return the volume of water on both surfaces in m3 per m2
			Variable VolAdsH2O	 		= SiteEquilibrium4(P_interlayer, Contact, gaW,"water",Point)
			
			// The volume of water molecules per m2 on both surfaces
//			H2O_Hyd[Point] 		= AdsorbateVolume4("water")
			H2O_Hyd[Point] 		= VolAdsH2O

			// The mass density of water molecules - NOTE factor of 2 
			Rho_Hyd[Point] 		= (H2O_Hyd[Point]) / (1e-9 * Separation)
			
		endfor
		
		F_Hyd = (P_Hyd-c_Po)/1e6 		// Convert to MPa

	SetDataFolder root:
End

Function PressureFunction4(P_coefs,P_Input)
	Variable P_Input
	Wave P_coefs
	
	Variable Separation 	= P_coefs[0]
	
	Variable Contact 		= 0, aW=1
	
	// Speciate the absorbate sites at the input pressure ...
	// ... and return the volume of water on both surfaces in m3 per m2
	Variable VolAdsH2O	 		= SiteEquilibrium4(P_Input, Contact, aW, "water",-1)
	
	// Calculate the geometric volume of the interlayer
	Variable Vol_Interlayer 	= (Separation * 1 * 1) * c_nmtom			// m3
	
	Variable Vol_Difference 	= VolAdsH2O - Vol_Interlayer
	
	Variable BulkModulus 		= (2.20 + 6.17e-09 * P_Input)					// 
	
	Variable P_Interlayer 	= (Vol_Difference/Vol_Interlayer) * (1e9*BulkModulus)
	
	// Return the difference
	return (P_Interlayer - P_Input)
End



// Units: Pressure (Pa); Contact (nm2)
// Output: The normalized abundance of sites with different hydration states, Speciation
Function SiteEquilibrium4(Pressure,Contact,aW,AdsName,pnt)
	Variable Pressure, Contact, aW, pnt
	String AdsName
	
	DFREF AdsDF 			= root:SFA:$AdsName
	WAVE EK 				= AdsDF:EK
	WAVE EKs 				= AdsDF:EKs
	WAVE Speciation 	= AdsDF:Speciation
	WAVE Speciations 	= AdsDF:Speciations
	WAVE Hydration 		= AdsDF:Hydration
	WAVE Hydrations 	= AdsDF:Hydrations
	WAVE DG 				= AdsDF:DG
	WAVE DV 				= AdsDF:DV
	WAVE VCum 			= AdsDF:VCum
	WAVE DH2O 			= AdsDF:DH2O
	NVAR sites 			= AdsDF:sites				// Number of sites per nm2
	
	Variable NSteps 	= DimSize(DG,0)
	Variable n, m, dVmol, K0, KP, SpecNorm, SitesTot
	
	Speciation 		= 0
	Speciation[0] 	= 1 													// Start with the site having zero bound waters or cations
	
	Variable Pdiff 		= Pressure - c_Po								// The pressure difference between interlayer and reservoir Po = 101e3 Pa
	
	for (n=0;n<NSteps;n+=1)
	
		K0 				= exp(c_KPre * DG[n])							// The standard (zero-pressure) equilibrium constant, K
		dVmol 			= cAvogadro * c_nm3tom3 * DV[n]			// The change in volume per mole for the reaction step (m3/mol)
		KP 				= exp(c_KPre * dVmol*Pdiff) 				// The 
		EK[n] 			= K0 * KP											// The modified K
		m 					= DH2O[n]											// Number of waters per step
		
		Speciation[n+1] = K0 * KP * Speciation[n] * aW^m 	
				
	endfor
	
	SpecNorm 			= sum(Speciation)
	Speciation 		/= SpecNorm
	
	Hydration[0]  	= 0
	Hydration[1,] 	= Speciation[p] * VCum[p-1]
	
	if (pnt > -1)
		EKs[pnt][] 				= EK[q]
		Speciations[pnt][] 	= Speciation[q]
	endif
	
	// return the total volume of water on both sides in m3 oer m2
	return 2 * sites * sum(Hydration) * c_nmtom
	
End

// Note: The adsorbate has to be speciated before this can work. 
// Output: The effective volume of the hydrated adsorbate (m3 per m2) on both surfaces at ambient pressure
Function AdsorbateVolume4(AdsName)
	String AdsName
	
	DFREF AdsDF 			= root:SFA:$AdsName
	WAVE DV 				= AdsDF:DV					// The volume for total hydration 
	WAVE Speciation 	= AdsDF:Speciation			// Population(s) of hydration states
	WAVE VCum 			= AdsDF:VCum					// The cumulative volume
	NVAR sites 			= AdsDF:sites				// Number of sites per nm2
	
	Variable NSteps 	= DimSize(DV,0)
	Variable i, Vi, VAds=0

	for (i=0;i<NSteps;i+=1)
		Vi 	= Speciation[i+1] * VCum[i]
		VAds 	+= Vi
	endfor
	
	// The factor 2 accounts for two surfaces 
	return 2 * sites * VAds * c_nmtom				// (m3 per m2)
End


//Function AdsorbateHydration4(AdsName)
//	String AdsName
//	
//	DFREF AdsDF 		= root:SFA:$AdsName
//	WAVE DV 			= AdsDF:DV
//	WAVE Hydration 	= AdsDF:Hydration
//	NVAR sites 		= AdsDF:sites
//	NVAR gH2OM 		= root:SFA:gH2OM
//
//	// The sum of bound waters
//	Variable j, Hyd = 0, NHyd = DimSize(Hydration,0)
//	
//	for (j=0;j<NHyd;j+=1)
//		Hyd += Hydration[j]
//	endfor
//	
//	return sites * Hyd
//End

	
//	Variable PrintFlag=0
//	if (PrintFlag)
//		Variable Vnm3nm2 		= sites * VAds
//		Variable Vm3nm2 		= c_nm3tom3 * Vnm3nm2		 // Total adsorbate volume on a single surface in m3 per nm2
//		Variable Vm3m2			= Vm3nm2 / c_nm2tom2		 // Total adsorbate volume on a single surface in m3 per m2
//		
//		 print "Adsorbate with molecular volume",VAds,"nm3 and ",sites,"sites per nm2 has total volume on a single surface of"
//		 print "		",Vnm3nm2,"nm3 per nm2; ",Vm3nm2,"m3 per nm2; or",Vm3m2,"m3 per m2"
//	endif






















Function PressureConvergence4(Separation)
	Variable Separation
	
	WAVE P_Coefs 	= root:SFA:P_Coefs
	
	P_Coefs[0] 	= Separation
	
	FindRoots /Q PressureFunction4, P_Coefs
	
	return V_root
End






















// Separation = total distance between the 2 surfaces (nm)
// BFn = flag for a Bulk Modulus that varies with pressure
Function PressureConvergenceCalc4(Separation,BFn)
	Variable Separation, BFn
	
	NVAR gaW 				= root:SFA:gaW			// Activity of water in external reservoir
	NVAR gVM 				= root:SFA:gVM			// Volume of one water molecule at 1 atm
	NVAR gBMod 			= root:SFA:gBMod		// Bulk modulus of water, in GPa
	NVAR gContact 		= root:SFA:gContact	// Not sure ... probably a finite contact area 
	
	Make /O/D/N=1 root:P_coefs /WAVE=P_coefs
	P_coefs[0] = Separation
	
	Make /O/D/N=1000 Pressure_axis, Pressure_guess, Pressure_calc, Pressure_diff
	Pressure_axis[] 	= -1 + p*0.1
	Pressure_guess 		= Pressure_axis
	
	Make /O/D/N=1000 Pressure_VolDiff, Pressure_EK
	
	Variable i, EK
	
	for (i=0;i<1000;i+=1)
	
		// Convert Pressure axis in MPa to Pa
		Variable Pressure_Pa 	= 1e6 * Pressure_axis[i]
		
		// Speciate the absorbate sites at the input pressure
		EK = SiteEquilibrium4(Pressure_Pa, gContact, gaW, "water",-1)
		SiteEquilibrium4(Pressure_Pa, gContact, gaW, "calcium",-1)
		
		// Calculate the volumes of the adsorbates given the speciation
		Variable VolAdsH2O			= AdsorbateVolume4("water") 				// Total adsorbate volume on both surfaces in m3 per m2
		Variable VolAdsCa			= AdsorbateVolume4("calcium")			// 
														
//		Variable Vol_Total 		= VolAdsH2O + VolAdsCa + gVM				//	// ??? Why add gVM here ???
		Variable Vol_Total 		= VolAdsH2O + VolAdsCa						//	Volume of adsorbate molecules in the interlayer
		
		Variable Vol_Interlayer 	= (Separation * 1 * 1) * c_nmtom			// Geometric volume of the interlayer (m3)
		
		Variable Vol_Difference 	= Vol_Total - Vol_Interlayer				// Difference in geometric and molecular volumes

		// Calculate the actual pressure
		Variable BulkModulus
		
		if (BFn)
			//	BulkModulus 	= 2.20 + 6.17e-09 * Pressure_Pa
			BulkModulus 	= 5 + 6.17e-9 * Pressure_Pa
		else
			BulkModulus 	= gBMod
		endif
		
		Variable P_Interlayer 		= (Vol_Difference/Vol_Interlayer) * (1e9*BulkModulus)
		
		// Convert to MPa
		Pressure_calc[i] = P_Interlayer/1e6
		
		Pressure_EK[i] = EK
		Pressure_VolDiff[i] = Vol_Difference
	endfor
	
	Pressure_diff = Pressure_calc - Pressure_guess
	
	FindLevel /Q Pressure_diff, 0
	if (V_flag==0)
		EK = SiteEquilibrium4(1e6*Pressure_axis[V_LevelX], 0, 1, "water",-1)
		Print " Solution found at",Pressure_axis[V_LevelX],""
	endif
End












// Make a Pressure-Density curve for a given temperature
Function AQUA_EOS_P_Rho(T)
	Variable T
	
	WAVE P_Pa 		= root:SFA:AQUA:P_Pa
	WAVE T_K 			= root:SFA:AQUA:T_K
	WAVE Rho_kgm3 	= root:SFA:AQUA:Rho_kgm3
	
	SetDataFolder root:SFA:AQUA
	
		Variable i, n=0, Pcurr, NPts = DimSize(P_Pa,0)
		
		String suffix = ReplaceString(".",num2str(T),"_")
		Make /O/D/N=0 $("P_"+suffix) /WAVE=P_T
		Make /O/D/N=0 $("Rho_"+suffix) /WAVE=Rho_T
		Make /O/D/N=301 T_Segment, Rho_Segment
		
		Pcurr 	= P_Pa[0]
		for (i=0;i<NPts;i+=1)
		
			if (P_Pa[i] > Pcurr)
				// A new pressure value
				n += 1
				Pcurr 			= P_Pa[i]
				Redimension /N=(n) P_T, Rho_T
				P_T[n-1] 	= Pcurr
				
				// Find the index of the chosen temperature
				T_Segment[] 		= T_K[i+p]
				Rho_Segment[] 	= Rho_kgm3[i+p]
				FindLevel /Q T_Segment, T
				Rho_T[n-1] = Rho_Segment[V_LevelX]
			endif
		
		endfor
		
		// Calculate the bulk modulus using B = ρ dP/dρ
		Duplicate /O/D Rho_T, $("B_"+suffix) /WAVE=B_T
		Differentiate P_T /X=Rho_T /D=dPdRho
		// Convert to MPa
		B_T = Rho_T * dPdRho * 1e-9 	// <-- Good: B ~ 2 MPa for liquid water
		
		// Generate a hypothetical ρ and B for a fluid that does not freeze under pressure
		// The bulk modulus, assume a linear function with pressure
		Make /O/D/N=(2) WW
		CurveFit/Q/M=2/W=0 line, kwCWave=WW, B_T[431,691]/X=P_T
		Duplicate /O/D Rho_T, $("Bi_"+suffix) /WAVE=Bi_T
		Bi_T[] 	= WW[0] + P_T[p] * WW[1]
		
		// The density, stitch together a sigmoid on a linear background. 
		// Measure the slope. At 298K B = 2.2 + 6.17e-9 P 
		CurveFit/Q/M=2/W=0 line, Rho_T[724,740]/X=P_T
		WAVE W = W_coef
		Make /O/D/N=(5) SS
		SS = {1000,4e-8,100,4e8,1e8}
		SS[1] = W[1]
		// Fit the sigmoid
		FuncFit /Q/H="01000" SlopedSigmoid, kwCWave=SS, Rho_T[431,691] /X=P_T
		Duplicate /O/D Rho_T, $("Rhoi_"+suffix) /WAVE=Rhoi_T
		Rhoi_T[] = SlopedSigmoid(SS,P_T[p])
		
	SetDataFolder root:
End

Function SlopedSigmoid(w,x): FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(Temp) = w[0]+w[1]*x+w[2]/(1+exp(-(x-w[3])/w[4]))
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ Temp
	//CurveFitDialog/ Coefficients 5
	//CurveFitDialog/ w[0] = offset
	//CurveFitDialog/ w[1] = slope
	//CurveFitDialog/ w[2] = sigmoid height
	//CurveFitDialog/ w[3] = sigmoid position
	//CurveFitDialog/ w[4] = sigmoid width
	
	return w[0]+w[1]*x+w[2]/(1+exp(-(x-w[3])/w[4]))
	
End



// Units: Hamaker in [J]; R, Delta [m]
// Energy [J]; Force [N]
// Israelachvili Table 13.1, Table 13.3 (note A is given in 10-20J)
Function VanDerWaals(Geometry,Output,Hamaker,Delta,R1,R2)
	String Geometry, Output
	Variable Hamaker,R1,R2,Delta
	
	Variable Wflat 	= Hamaker / (12 * pi * Delta^2)
	Variable Fflat 	= Hamaker / (6 * pi * Delta^3)
	
	Variable RTerm, Wgeom, Fgeom
	
	strswitch(Geometry)
		case "parallel":
			Wgeom 	= Wflat
			Fgeom 	= Fflat
			break
		case "sphere_sphere":
			RTerm 	= (R1*R2)/(R1+R2)
			Wgeom 	= -1 * (Hamaker * RTerm) / (6 * Delta)
			Fgeom 	= 2 * pi * RTerm * Wflat
			break
		case "sphere_surface":
			// Sphere on a flat surface where D < R/100
			Wgeom 	= -1 * (Hamaker * R1) / (6 * Delta)
			Fgeom 	= 2 * pi * R1 * Wflat
			break
		case "AFM":
			// Nanoscale tip on a flat surface. Eqn (13.11a)
			Wgeom 	= 0
			Fgeom 	= -1 * (2 * Hamaker * R1^3) / (3 * (2*R1 + Delta)^2 * Delta^2)
			break
		case "SFA":
			// Crossed cylinders
			RTerm 	= sqrt(R1*R2)
			Wgeom 	= -1 * (Hamaker * RTerm) / (6 * Delta)
			Fgeom 	= 2 * pi * RTerm * Wflat
			break
	endswitch
	
	if (cmpstr("Force",Output) == 0)
		return Fgeom
	else
		return Wgeom
	endif
End

Function SurfaceForces3b(Reset,PointSeparation,Contact)
	Variable Reset, PointSeparation, Contact

	NewDataFolder /O/S root:SFA
	
		Variable /G gaW = 1
		Variable /G gBMod = 5
		Variable /G gContact = Contact
		Variable /G gDelta, gVM, gH2OM
		
		Variable DeltaMax=2, DeltaMin=0.05, NDeltaPts=200, Separation, i, j
		Variable dDelta = (DeltaMax-DeltaMin)/(NDeltaPts)
	
		CreateAdsorbateFolders(NDeltaPts,DeltaMax,dDelta,Reset)
		
		gDelta = InterlayerThickness3()
		
		// The Hydration Force
		Make /O/D/N=1 P_Coefs
		Make /O/D/N=(NDeltaPts+1) F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		
		// The van der Waals force
		Make /O/D/N=(NDeltaPts+1) F_vdW, F_AFM
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_vdW, F_AFM
		
		// A single calculation at one separation
		if (PointSeparation > 0.05)
			P_Coefs[0] 	= PointSeparation
			FindRoots /Q PressureFunction3, P_Coefs
			Variable PointPressure 	= V_root
			SiteEquilibrium3(V_root, Contact, gaW,"water",-1)
			SiteEquilibrium3(V_root, Contact, gaW,"calcium",-1)
			Variable PointHydration 	= AdsorbateHydration3("water") + AdsorbateHydration3("calcium")
			Print " At a separation of",PointSeparation,"nm the pressure is",PointPressure,"Pa and the total hydration is",PointHydration,"waters /nm2"
//			return PointHydration
		endif
			
		F_Hyd_Old 	= F_Hyd
		P_Hyd 		= c_Po
		
		Variable DeltaPoint 	= trunc (x2pnt(F_Hyd,gDelta))
		
		for (i=DeltaPoint;i<NDeltaPts+1;i+=1)
		
			// The self-consistent pressure
			Separation 	= pnt2x(F_Hyd,i)
			P_Coefs[0] 	= Separation
			FindRoots /Q PressureFunction3, P_Coefs
			
			if (Separation < 0.33)
				
				Brk()
				
			endif
//			FindRoots /Q/L=0/H=100e6 PressureFunction3, P_Coefs
			P_Hyd[i] 		= V_root
			
			// Speciate the absorbate sites at the self-consistent pressure
			SiteEquilibrium3(V_root, Contact, gaW,"water",i)
			SiteEquilibrium3(V_root, Contact, gaW,"calcium",i)
			
			// The number of water molecules per nm2
			H2O_Hyd[i] 		= gH2OM + AdsorbateHydration3("water") + AdsorbateHydration3("calcium")

			// The mass density of bound plus matrix waters
			Rho_Hyd[i] 		= (H2O_Hyd[i] / Separation)
		endfor
		
		F_Hyd = (P_Hyd-101e3)/1e6 		// Convert to MPa
		
		F_vdW[] = 1e9 * VanDerWaals("AFM","Force",2e-20,1e-6*pnt2x(F_vdW,p),10e-9,-1)
		
		F_AFM = F_vdW + F_Hyd
		
		H2O_Hyd[0,DeltaPoint-1] 	= H2O_Hyd[DeltaPoint]
		Rho_Hyd[0,DeltaPoint-1] 	= Rho_Hyd[DeltaPoint]
		Variable AmbientDensity = 2*Rho_Hyd[0]
		Rho_Hyd /= AmbientDensity
		
//		UpdateSFAPlot3()
		
		// Show the thickness of the interlayer
		Cursor /H=2/W=SFAPlot3A B F_Hyd gDelta
		
	SetDataFolder root:
End

Function SurfaceForces3c(Reset,PointSeparation,Contact)
	Variable Reset, PointSeparation, Contact

	NewDataFolder /O/S root:SFA
	
		Variable /G gaW = 1
		Variable /G gBMod = 5
		Variable /G gContact = Contact
		Variable /G gDelta, gVM, gH2OM
		
		Variable DeltaMax=2, DeltaMin=0.05, NDeltaPts=200, Separation, i, j
		Variable dDelta = (DeltaMax-DeltaMin)/(NDeltaPts)
	
		CreateAdsorbateFolders(NDeltaPts,DeltaMax,dDelta,Reset)
		
		gDelta = InterlayerThickness3()
		
		// The Hydration Force
		Make /O/D/N=1 P_Coefs
		Make /O/D/N=(NDeltaPts+1) F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		
		// The van der Waals force
		Make /O/D/N=(NDeltaPts+1) F_vdW, F_AFM
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_vdW, F_AFM
			
		F_Hyd_Old 	= F_Hyd
		P_Hyd 		= c_Po
		
		Variable DeltaPoint 	= trunc (x2pnt(F_Hyd,gDelta))
		
		for (i=DeltaPoint;i<NDeltaPts+1;i+=1)
		
			// The self-consistent pressure
			Separation 	= pnt2x(F_Hyd,i)
			P_Coefs[0] 	= Separation
			FindRoots /Q PressureFunction3, P_Coefs
			
			if (Separation < 0.33)
				
				Brk()
				
			endif
//			FindRoots /Q/L=0/H=100e6 PressureFunction3, P_Coefs
			P_Hyd[i] 		= V_root
			
			// Speciate the absorbate sites at the self-consistent pressure
			SiteEquilibrium3(V_root, Contact, gaW,"water",i)
			SiteEquilibrium3(V_root, Contact, gaW,"calcium",i)
			
			// The number of water molecules per nm2
			H2O_Hyd[i] 		= gH2OM + AdsorbateHydration3("water") + AdsorbateHydration3("calcium")

			// The mass density of bound plus matrix waters
			Rho_Hyd[i] 		= (H2O_Hyd[i] / Separation)
		endfor
		
		F_Hyd = (P_Hyd-101e3)/1e6 		// Convert to MPa
		
		F_vdW[] = 1e9 * VanDerWaals("AFM","Force",2e-20,1e-6*pnt2x(F_vdW,p),10e-9,-1)
		
		F_AFM = F_vdW + F_Hyd
		
		H2O_Hyd[0,DeltaPoint-1] 	= H2O_Hyd[DeltaPoint]
		Rho_Hyd[0,DeltaPoint-1] 	= Rho_Hyd[DeltaPoint]
		Variable AmbientDensity = 2*Rho_Hyd[0]
		Rho_Hyd /= AmbientDensity
		
//		UpdateSFAPlot3()
		
		// Show the thickness of the interlayer
		Cursor /H=2/W=SFAPlot3A B F_Hyd gDelta
		
	SetDataFolder root:
End




Function Brk()
	Variable sdfg
	
End

Function SurfaceForces3(Reset,PointSeparation,Contact)
	Variable Reset, PointSeparation, Contact

	NewDataFolder /O/S root:SFA
	
		Variable /G gaW = 1
		Variable /G gBMod = 5
		Variable /G gContact = Contact
		Variable /G gDelta, gVM, gH2OM
		
		Variable DeltaMax=2, DeltaMin=0.05, NDeltaPts=200, Separation, i, j
		Variable dDelta = (DeltaMax-DeltaMin)/(NDeltaPts)
	
		CreateAdsorbateFolders(NDeltaPts,DeltaMax,dDelta,Reset)
		
		gDelta = InterlayerThickness3()
		
		// The Hydration Force
		Make /O/D/N=1 P_Coefs
		Make /O/D/N=(NDeltaPts+1) F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_Hyd, F_Hyd_Old, P_Hyd, H2O_Hyd, Rho_Hyd
		
		// The van der Waals force
		Make /O/D/N=(NDeltaPts+1) F_vdW, F_AFM
		SetScale /P x, (DeltaMax), (-dDelta), "nm", F_vdW, F_AFM
		
		// A single calculation at one separation
		if (PointSeparation > 0.05)
			P_Coefs[0] 	= PointSeparation
			FindRoots /Q PressureFunction3, P_Coefs
			Variable PointPressure 	= V_root
			SiteEquilibrium3(V_root, Contact, gaW,"water",-1)
			SiteEquilibrium3(V_root, Contact, gaW,"calcium",-1)
			Variable PointHydration 	= AdsorbateHydration3("water") + AdsorbateHydration3("calcium")
			Print " At a separation of",PointSeparation,"nm the pressure is",PointPressure,"Pa and the total hydration is",PointHydration,"waters /nm2"
			return PointHydration
		endif
			
		F_Hyd_Old 	=  F_Hyd
		P_Hyd 		= 101e6
		
		Variable DeltaPoint 	= trunc (x2pnt(F_Hyd,gDelta))
		
		for (i=DeltaPoint;i<NDeltaPts+1;i+=1)
		
			// The self-consistent pressure
			Separation 	= pnt2x(F_Hyd,i)
			P_Coefs[0] 	= Separation
//			FindRoots /Q PressureFunction3, P_Coefs
			FindRoots /Q/L=0/H=100e9 PressureFunction3, P_Coefs
			P_Hyd[i] 		= V_root
			
			// Speciate the absorbate sites at the self-consistent pressure
			SiteEquilibrium3(V_root, Contact, gaW,"water",i)
			SiteEquilibrium3(V_root, Contact, gaW,"calcium",i)
			
			// The number of water molecules per nm2
			H2O_Hyd[i] 		= gH2OM + AdsorbateHydration3("water") + AdsorbateHydration3("calcium")

			// The mass density of bound plus matrix waters
			Rho_Hyd[i] 		= (H2O_Hyd[i] / Separation)
		endfor
		
		F_Hyd = (P_Hyd-101e6)/1e9 		// Convert to GPa
		
		F_vdW[] = 1e9 * VanDerWaals("AFM","Force",2e-20,1e-9*pnt2x(F_vdW,p),10e-9,-1)
		
		F_AFM = F_vdW + F_Hyd
		
		H2O_Hyd[0,DeltaPoint-1] 	= H2O_Hyd[DeltaPoint]
		Rho_Hyd[0,DeltaPoint-1] 	= Rho_Hyd[DeltaPoint]
		Variable AmbientDensity = 2*Rho_Hyd[0]
		Rho_Hyd /= AmbientDensity
		
//		UpdateSFAPlot3()
		
		// Show the thickness of the interlayer
		Cursor /H=2/W=SFAPlot3A B F_Hyd gDelta
		
	SetDataFolder root:
End

Function AdsorbateHydration3(AdsName)
	String AdsName
	
	DFREF AdsDF 		= root:SFA:$AdsName
	WAVE DV 			= AdsDF:DV
	WAVE Hydration 	= AdsDF:Hydration
	NVAR sites 			= AdsDF:sites
	NVAR gH2OM 		= root:SFA:gH2OM

	// The sum of bound waters
	Variable j, Hyd = 0
	for (j=0;j<DimSize(Hydration,0);j+=1)
		Hyd += Hydration[j]
	endfor
	
	return sites * Hyd
End

Function PressureConvergence3(Separation)
	Variable Separation
	
	WAVE P_Coefs 	= root:SFA:P_Coefs
	
	P_Coefs[0] 	= Separation
	
	FindRoots /Q PressureFunction3, P_Coefs
	
	return V_root
End

Function PressureFunction3(P_coefs,P_Input)
	Variable P_Input
	Wave P_coefs
	
	NVAR gaW 				= root:SFA:gaW
	NVAR gVM 				= root:SFA:gVM
	NVAR gH2OM 			= root:SFA:gH2OM
	NVAR gBMod 			= root:SFA:gBMod
	NVAR gContact 		= root:SFA:gContact
	
	Variable Contact = 0
	
	Variable Separation 	= P_coefs[0]
	
	// Speciate the absorbate sites at the input pressure
	SiteEquilibrium3(P_Input, Contact, gaW,"water",-1)
	SiteEquilibrium3(P_Input, Contact, gaW,"calcium",-1)
	
	// Calculate the volumes of the adsorbates given the speciation
	Variable VolAdsH2O			= AdsorbateVolume3("water") 	// Total adsorbate volume on both surfaces in m3 per m2
	Variable VolAdsCa			= AdsorbateVolume3("calcium")
	
//	Variable Vol_Total 		= VolAdsH2O + VolAdsCa + gVM
	Variable Vol_Total 		= VolAdsH2O + VolAdsCa// + gH2OM
	
	Variable Vol_Interlayer 	= (Separation * 1 * 1) * c_nmtom									// m3
	Variable Vol_Difference 	= Vol_Total - Vol_Interlayer
	
	// Calculate the actual pressure
	Variable BulkModulus, BFn = 1
	if (BFn)
//		BulkModulus 	= 2.20 + 6.17e-09 * P_Input
		BulkModulus 	= 5 + 6.17e-9 * P_Input
	else
		BulkModulus 	= gBMod
	endif
	
	Variable P_Interlayer 		= (Vol_Difference/Vol_Interlayer) * BulkModulus * 1e9
	
	// Return the difference
	return (P_Interlayer - P_Input)
End

Function PressureConvergenceCalc3(Separation,BFn)
	Variable Separation, BFn
	
	NVAR gaW 				= root:SFA:gaW
	NVAR gVM 				= root:SFA:gVM
	NVAR gBMod 			= root:SFA:gBMod
	NVAR gContact 		= root:SFA:gContact
	
	Make /O/D/N=1 root:P_coefs /WAVE=P_coefs
	P_coefs[0] = Separation
	
	Make /O/D/N=1000 Pressure_axis, Pressure_guess, Pressure_calc, Pressure_diff
	Pressure_axis[] 	= -1 + p*0.01
	Pressure_guess = Pressure_axis
	
	Variable i
	for (i=0;i<1000;i+=1)
		Variable Pressure_Pa 	= 1e9 * Pressure_axis[i]
		
		// Speciate the absorbate sites at the input pressure
		SiteEquilibrium3(Pressure_Pa, gContact, gaW,"water",-1)
		SiteEquilibrium3(Pressure_Pa, gContact, gaW,"calcium",-1)
		
		// Calculate the volumes of the adsorbates given the speciation
		Variable VolAdsH2O		= AdsorbateVolume3("water") 	// Total adsorbate volume on both surfaces in m3 per m2
		Variable VolAdsCa			= AdsorbateVolume3("calcium")
		Variable Vol_Total 		= VolAdsH2O + VolAdsCa + gVM
		
		Variable Vol_Interlayer 	= (Separation * 1 * 1) * c_nmtom									// m3
		Variable Vol_Difference 	= Vol_Total - Vol_Interlayer
		
		// Calculate the actual pressure
//		Variable P_Interlayer 		= (Vol_Difference/Vol_Interlayer) * gBMod * 1e9

		// Calculate the actual pressure
		Variable BulkModulus
		if (BFn)
//			BulkModulus 	= 2.20 + 6.17e-09 * Pressure_Pa
			BulkModulus 	= 5 + 6.17e-9 * Pressure_Pa
		else
			BulkModulus 	= gBMod
		endif
		
		Variable P_Interlayer 		= (Vol_Difference/Vol_Interlayer) * BulkModulus * 1e9
		
		// Return the difference
		Pressure_calc[i] = P_Interlayer/1e9
	endfor
	
End

Function InterlayerThickness3()
	
	Variable SiteTotal 			= 7.1 	// Total possible water molecules per nm2
	Variable Layers 			= 2 	// Basically a guess
	
	NVAR gaW 					= root:SFA:gaW
	NVAR gVM 					= root:SFA:gVM
	NVAR gH2OM 				= root:SFA:gH2OM
	
	NVAR AdsH2OSites 		= root:SFA:water:sites
	NVAR AdsCaSites 			= root:SFA:calcium:sites
	
	// Speciate the adsorbates at ambient pressure. Contact area does not matter
	Variable Pressure 			= 101e6
	SiteEquilibrium3(Pressure, 0, gaW,"water",-1)
	SiteEquilibrium3(Pressure, 0, gaW,"calcium",-1)
	
	// Calculate the volumes of the adsorbates given the speciation
	Variable VolAdsH2O		= AdsorbateVolume3("water") 					// Total adsorbate volume on both surfaces in m3 per m2
	Variable VolAdsCa			= AdsorbateVolume3("calcium")
	
	Variable VolAds 			= VolAdsH2O + VolAdsCa
	Variable SiteFree 			= SiteTotal - (AdsH2OSites + AdsCaSites)
	Variable MatrixH2Os 		= 2 * Layers * SiteFree
	Variable VolMatrix 			= 2 * Layers * SiteFree * (c_vH2Om3/c_nm2tom2) 	// Volume in m3 per m2
	Variable Delta 				= (VolAds + VolMatrix) / c_nmtom // nm

	Variable PrintFlag=0
	if (PrintFlag)
		Print " 	--- "
		Print " 		Volume of adsorbed bound water is",VolAdsH2O,"m3 per m2"
		Print " 		Volume of adsorbed Ca(H2O)n is",VolAdsCa,"m3 per m2"
		Print " 		Volume of adsorbed unbound water is",VolMatrix,"m3 per m2"
		Print " 		The total volume of the interlayer is",(VolAds + VolMatrix),"m3 and the thickness is",Delta,"nm"
	endif
	
	gH2OM 	= MatrixH2Os
	gVM 		= VolMatrix
	
	return Delta
End


// Output: The effective volume of the adsorbate per m2 on both surfaces at ambient pressure
Function AdsorbateVolume3(AdsName)
	String AdsName
	
	DFREF AdsDF 		= root:SFA:$AdsName
	WAVE DV 			= AdsDF:DV
	WAVE Speciation 	= AdsDF:Speciation
	NVAR sites 			= AdsDF:sites
	
	Variable NSteps 	= DimSize(DV,0)
	Variable i, Vi, VAds=0

	for (i=0;i<NSteps;i+=1)
		Vi 		= Speciation[i+1] * DV[i]
		VAds 	+= Vi
	endfor
	
	Variable PrintFlag=0
	if (PrintFlag)
		Variable Vnm3nm2 	= sites * VAds
		Variable Vm3nm2 		= c_nm3tom3 * Vnm3nm2		 // Total adsorbate volume on a single surface in m3 per nm2
		Variable Vm3m2		= Vm3nm2 / c_nm2tom2		 // Total adsorbate volume on a single surface in m3 per m2
		
		 print "Adsorbate with molecular volume",VAds,"nm3 and ",sites,"sites has total volume on a single surface of"
		 print "		",Vnm3nm2,"nm3 per nm2; ",Vm3nm2,"m3 per nm2; or",Vm3m2,"m3 per m2"
	endif
	
	// The factor 2 accounts for two surfaces 
	return 2 * sites * VAds * c_nmtom
End

// Units: Pressure (Pa); Contact (nm2)
// Output: The normalized abundance of sites with different hydration states, Speciation
Function SiteEquilibrium3(Pressure,Contact,aW,AdsName,pnt)
	Variable Pressure, Contact, aW, pnt
	String AdsName
	
	DFREF AdsDF 			= root:SFA:$AdsName
	WAVE EK 				= AdsDF:EK
	WAVE EKs 				= AdsDF:EKs
	WAVE Speciation 	= AdsDF:Speciation
	WAVE Speciations 	= AdsDF:Speciations
	WAVE Hydration 		= AdsDF:Hydration
	WAVE Hydrations 	= AdsDF:Hydrations
	WAVE DG 				= AdsDF:DG
	WAVE DV 				= AdsDF:DV
	WAVE DH2O 			= AdsDF:DH2O
	NVAR sites 			= AdsDF:sites
	
	Variable NSteps 	= DimSize(DG,0)
	Variable dP 			= Pressure - 101e3
	Variable n, m, dVmol, K0, KP, SpecNorm, SitesTot
	
	Speciation 		= 0
	Speciation[0] 	= 1 	// Start with the site having zero bound waters or cations
	
	for (n=0;n<NSteps;n+=1)
		K0 				= exp(c_KPre * DG[n])							// The standard (zero-pressure) equilibrium constant, K
		dVmol 			= cAvogadro * c_nm3tom3 * DV[n]			// The TOTAL change in volume per mole for the reaction step (m3/mol)
		KP 				= exp(c_KPre * dVmol*dP) 						// 
		EK[n] 			= K0 * KP											// The modified K
		m 					= DH2O[n]											// Number of waters
		
		Speciation[n+1] = K0 * KP * Speciation[n] * aW^m 	
				
	endfor
	
	SpecNorm = sum(Speciation)
	Speciation /= SpecNorm
	
	if (Contact > 0)
		SitesTot 	= sites * Contact
		Speciation *= SitesTot
		Speciation[] = round(Speciation[p])
		Speciation /= SitesTot
	endif
	
	Hydration[0] 	= 0
	Hydration[1,] 	= Speciation[p] * DH2O[p-1]
	
	if (pnt > 0)
		EKs[pnt][] 				= EK[q]
		Speciations[pnt][] 	= Speciation[q]
		Hydrations[pnt][] 		= Hydration[q]
	endif
End

Structure Adsorbate
	SVAR name				// Name of the adsorbate
	DFREF folder			// Data folder reference
	NVAR volume			// Volume of the adsorbate
	NVAR charge			// Charge of the adsorbate
	NVAR sites				// Surface site density per nm2
	NVAR steps				// Number of dehydration reaction steps
	WAVE DG				// Gibbs free energy change for each reaction step
	WAVE DV				// Total volume change for each reaction step, in m3 per reaction stoichiometry
	WAVE DH2O			// Change in hydration waters for each reaction step 
	WAVE DAds				// The adsorbate can only be lost at the last step
	
EndStructure

Function CreateAdsorbateFolders(NDeltaPts,DeltaMax,dDelta,Reset)
	Variable NDeltaPts,DeltaMax,dDelta,Reset
	
	String OldDf 	= GetDataFolder(1)
	NewDataFolder /O/S root:SFA:water
	
		STRUCT Adsorbate AdsH2O
			String /G name 		= "water"
			Variable /G charge 	= 0		// Electrostatic charge 
			Variable /G steps 		= 17		// Number of sequential dehydration reactions
			Variable /G sites 		= 4		// Number of sites per nm2
			
			// Arrays that define (de)hydration stoichiometry and thermodynamics
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV
			if (Reset)
				DG[] 	= -10000 + 500*p
				DH2O 	= 2
				DAds 	= 0
				DAds[0] 	= 1
				DV 	= 0.06
			endif
			Variable /G volume 	= sum(DV)
			// The site speciation
			Make /D/O/N=(steps+1) Speciation, Hydration
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs									// Keep track of the pressure-dependent equilibrium constants
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations, Hydrations		// Keep track of the site average occupancies 
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
			EKs = NaN; Speciations = NaN; Hydrations = NaN
	SetDataFolder root: 
	
//		STRUCT Adsorbate AdsH2O
//			String /G name 		= "water"
//			Variable /G charge 	= 0		// Electrostatic charge 
//			Variable /G steps 		= 4		// Number of sequential dehydration reactions
//			Variable /G sites 		= 4		// Number of sites per nm2
//			// Arrays that define (de)hydration stoichiometry and thermodynamics
//			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV
//			if (Reset)
//				DG ={-90000,-60000,-50000,-30000}
//				DH2O ={1,2,3,3}
//				DAds ={1,0,0,0}
//				DV={0.03,0.06,0.09,0.09}
//			endif
//			Variable /G volume 	= sum(DV)
//			// The site speciation
//			Make /D/O/N=(steps+1) Speciation, Hydration
//			
//			Make /O/D/N=(NDeltaPts+1,steps) EKs									// Keep track of the pressure-dependent equilibrium constants
//			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations, Hydrations		// Keep track of the site average occupancies 
//			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
//			EKs = NaN; Speciations = NaN; Hydrations = NaN
//	SetDataFolder root: 
	
	NewDataFolder /O/S root:SFA:sodium
		STRUCT Adsorbate AdsNa
			String /G name 		= "sodium"
			Variable /G charge 	= +1
			Variable /G steps 		= 1
			Variable /G sites 		= 1.5
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV
			if (Reset)
				DG ={-80000}
				DH2O ={3}
				DAds ={1}
				DV={0.9}
			endif
			Variable /G volume 	= sum(DV)
			Make /D/O/N=(steps+1) Speciation, Hydration
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations, Hydrations
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
			EKs = NaN; Speciations = NaN; Hydrations = NaN
	SetDataFolder root: 
	
	NewDataFolder /O/S root:SFA:calcium
		STRUCT Adsorbate AdsCa
			String /G name 		= "calcium"
			Variable /G charge 	= 2
			Variable /G steps 		= 1
			Variable /G sites 		= 1.0
			Make /D/O/N=(steps) DG, EK, DH2O, DAds, DV
			if (Reset)
				DG 			={-1200}
				DH2O 		={4}
				DAds 			={1}
				DV				={0.32}
			endif
			Variable /G volume 	= sum(DV)
			Make /D/O/N=(steps+1) Speciation, Hydration
			
			Make /O/D/N=(NDeltaPts+1,steps) EKs
			Make /O/D/N=(NDeltaPts+1,steps+1) Speciations, Hydrations
			SetScale /P x, (DeltaMax), (-dDelta), "nm", EKs, Speciations, Hydrations
			EKs = NaN; Speciations = NaN; Hydrations = NaN

	SetDataFolder $OldDf
End 


Function CreateAdsorbateStructures()

		Variable DeltaMax=2, DeltaMin=0.05, NDeltaPts=200, i
		Variable dDelta = (DeltaMax-DeltaMin)/(NDeltaPts)
	
		CreateAdsorbateFolders(NDeltaPts,DeltaMax,dDelta,1)
	
	DFRef DFH2O = root:SFA:water
	STRUCT Adsorbate AdsH2O
	StructFill  /SDFR=DFH2O AdsH2O
		
	DFRef DFNa = root:SFA:sodium
	STRUCT Adsorbate AdsNa
	StructFill  /SDFR=DFNa AdsNa

	DFRef DFCa = root:SFA:calcium
	STRUCT Adsorbate AdsCa
	StructFill  /SDFR=DFCa AdsCa

End

Function PrintAdsorbate(Ads)
	STRUCT Adsorbate &Ads

	Print "The adsorbate",Ads.name,"has the following reaction free energies",Ads.DG
	
End 

// Units: Pressure (Pa)
// Output: The normalized abundance of sites with different hydration states, Speciation
Function SiteEquilibrium3_Structure(Pressure, aW,Ads)
	Variable Pressure, aW
	STRUCT Adsorbate &Ads
	
	DFREF AdsDF 		= Ads.folder
	WAVE EK 			= AdsDF:EK
	WAVE Speciation 	= AdsDF:Speciation
	WAVE Hydration 	= AdsDF:Hydration
	WAVE DG 			= Ads.DG
	WAVE DV 			= Ads.DV
	WAVE DH2O 		= Ads.DH2O
	
	Variable NSteps 	= DimSize(DG,0)
	Variable dP 			= Pressure - 101e6
	Variable n, m, dVmol, K0, KP, SpecNorm
	
	Speciation 		= 0
	Speciation[0] 	= 1 	// Start with the site having zero bound waters or cations
	
	for (n=0;n<NSteps;n+=1)
		K0 				= exp(c_KPre * DG[n])							// The standard (zero-pressure) equilibrium constant, K
		dVmol 			= cAvogadro * c_nm3tom3 * DV[n]			// The TOTAL change in volume per mole for the reaction step (m3/mol)
		KP 				= exp(c_KPre * dVmol*dP) 						// 
		EK[n] 			= K0 * KP											// The modified K
		m 					= DH2O[n]											// Number of waters
		
		Speciation[n+1] = K0 * KP * Speciation[n] * aW^m 	
				
	endfor
	
	SpecNorm = sum(Speciation)
	Speciation /= SpecNorm
	
	Hydration[0] 	= 0
	Hydration[1,] 	= Speciation[p] * DH2O[p-1]
End

// Output: The effective volume of the adsorbate per m2 on both surfaces at ambient pressure
Function AdsorbateVolume3_Structure(Ads)
	STRUCT Adsorbate &Ads
	
	WAVE DV 			= Ads.DV
	Variable sites 		= Ads.sites
	DFREF AdsDF 		= Ads.folder
	WAVE Speciation 	= AdsDF:Speciation
	
	Variable NSteps 	= DimSize(DV,0)
	Variable i, Vi, VAds=0

	for (i=0;i<NSteps;i+=1)
		Vi 		= Speciation[i+1] * DV[i]
		VAds 	+= Vi
	endfor
	
	Variable PrintFlag=0
	if (PrintFlag)
		Variable Vnm3nm2 	= sites * VAds
		Variable Vm3nm2 		= c_nm3tom3 * Vnm3nm2		 // Total adsorbate volume on a single surface in m3 per nm2
		Variable Vm3m2		= Vm3nm2 / c_nm2tom2		 // Total adsorbate volume on a single surface in m3 per m2
		
		 print "Adsorbate with molecular volume",VAds,"nm3 and ",sites,"sites has total volume on a single surface of"
		 print "		",Vnm3nm2,"nm3 per nm2; ",Vm3nm2,"m3 per nm2; or",Vm3m2,"m3 per m2"
	endif
	
	// The factor 2 accounts for two surfaces 
	return 2 * sites * VAds * c_nmtom
End

































//	--------------------------------------------------------------------------------------------------------------
//	This was an unfinished attempt to more generally calculate SFA forces based on the Pride model.
//	--------------------------------------------------------------------------------------------------------------

Function InitializeSFAForces()

	WAVE /T wDataList 		= root:SPECTRA:wDataList
	WAVE wDataGroup 		= root:SPECTRA:wDataGroup
		
	String DataList = TextWaveToList(wDataList,DimSize(wDataList,0),"","")

	NewDataFolder /O/S root:SFA
	
		// Physical properties of calcite
		Variable /G gMolarVolume 	= 3.12e-05		// m3 / mol 		converted from 31.20 cm3 per mole
		Variable /G gFW 				= 0.100087 	// kg/mol			converted from 100.087  g/mol
		Variable /G gDensity 			= 2710			// kg/m3			should be equal to ... (gFW/1000)/gMolarVolume ? 
		Variable /G gIFE 				= 0.094			// J/m2			value from Steefel paper sent by A. Stack

		Variable LogKsp = NumVarOrDefault("root:SFA:gLogKsp",1)
		Prompt LogKsp, "At 21˚C -log{Ksp} = 8.3223 (GWB)"
		Variable DataSelection = NumVarOrDefault("root:SFA:gDataSelection",1)
		Prompt DataSelection, "Select diffuse layer calculation", popup, DataList
		DoPrompt "Enter SFA calculation parameters", LogKsp, DataSelection
		if (V_flag)
			return 0
		endif
		Variable /G	gLogKsp = LogKsp
		Variable /G gDataSelection = DataSelection
		
		String /G gDataPointer		= "root:SPECTRA:Data:Load" + num2str(wDataGroup[DataSelection]) + ":" + PossiblyQuoteName(wDataList[DataSelection])
		Print " SFA calculation with",SampleNameFromDataName(wDataList[DataSelection])
		
	SetDataFolder root:
	return 1
End

Function PrepareSFAInterface()
	
	WAVE Beta_nm 				= root:SFA:Beta_nm
	NVAR gTwoBeta 				= root:SFA:gTwoBeta
	NVAR gDProtonSite 			= root:SFA:gDProtonSite
	NVAR gProtonState 			= root:SFA:gProtonState
	NVAR gDStructChargeSite 	= root:SFA:gDStructChargeSite

	Variable nm3toL = 1e-24
	Variable nm2tom2 = 1e18
	Variable cH2O, dCation, rCation=0.15, wNPts=DimSize(Beta_nm,0)
		
	CompactLayerDescription(gTwoBeta,cH2O,gDProtonSite,gProtonState,gDStructChargeSite,dCation,rCation)
	
	Make /O/D/N=(wNPts) Beta_Pa, Beta_BB, Beta_H2O, Beta_Rho
	Beta_H2O[wNPts-1] 		= cH2O			// The number of water molecules in the layer per square meter at the start. This will go down with dehydration. 
	Beta_Pa[wNPts-1] 		= 0			
	Beta_BB[wNPts-1] 		= 1e8				// Bulk modulus of water	
	Beta_Rho[wNPts-1] 		= 0.997048	 	// g/cm3 at 0.1 MPa and 25C
		
		// Prepare the Interface
	Variable SiteMolarity = (gDProtonSite/cAvogadro)/(gTwoBeta*nm2tom2*nm3toL)
//	SiteH2O_2[NBPts-1] 		= SiteMolarity	// Is this right? 

End

Function HydrationEquilibria(SimDir)
	String SimDir
	
	WAVE Beta_nm 	= root:SFA:Beta_nm
	Variable wNPts=DimSize(Beta_nm,0)
	
	String OldDF = getDataFolder(1)
	NewDataFolder /O/S $SimDir
		Killwaves /Z/A
		
		PrepareSFAInterface()

	SetDataFolder $OldDF
End


Function ReturnSingleSFAParameters()

		// Parameters for any single simulation
		String CalcTypeList = "Chemical dehydration;"
		Variable TwoBeta = NumVarOrDefault("root:SFA:gTwoBeta",295)
		Prompt TwoBeta, "Starting separation (nm)"
		Variable TemperatureC = NumVarOrDefault("root:SFA:gTemperatureC",25)
		Prompt TemperatureC, "Temperature (C)"
		Variable CalcSimType = NumVarOrDefault("root:SFA:gCalcSimType",1)
		Prompt CalcSimType, "Calculation type", popup, CalcTypeList
		Variable CalcSimStart = NumVarOrDefault("root:SFA:gCalcSimStart",1)
		Prompt CalcSimStart, "(First) simulation # (integer)"
		Variable CalcSimMulti = NumVarOrDefault("root:SFA:gCalcSimMulti",1)
		Prompt CalcSimMulti, "Number of simulations (integer)"
		DoPrompt "SFA force calculation", CalcSimType, TemperatureC, TwoBeta, CalcSimStart, CalcSimMulti
		if (V_flag)
			return 0
		endif
		Variable /G gTemperatureC 	= TemperatureC
		Variable /G gTwoBeta 		= TwoBeta
		Variable /G gCalcSimType 	= CalcSimType
		Variable /G gCalcSimStart 	= CalcSimStart
		Variable /G gCalcSimMulti 	= CalcSimMulti
		
		Variable wStop = 0.05, wStep = 0.05, wNPts = (TwoBeta-wStop)/wStep
		Make /O/D/N=(wNPts) Beta_nm
		Beta_nm[] = wStop + p*wStep
		
		return 1
End

Function ReturnSurfaceParameters(SimDir)
	String SimDir

	Variable dProtonSite = NumVarOrDefault(SimDir+":gDProtonSite",4)
	Prompt dProtonSite, "Single-surface protonatable site density (/nm2)"
	Variable ProtonState = NumVarOrDefault(SimDir+":gProtonState",0.5)
	Prompt ProtonState, "Fractional protonation state"
	Variable dStructChargeSite = NumVarOrDefault(SimDir+":gDStructChargeSite",0)
	Prompt dStructChargeSite, "Single-surface structural charge density (/nm2)"
	DoPrompt "Single surface characteristics", dProtonSite, ProtonState, dStructChargeSite
	if (V_flag)
		return 0
	endif
	Variable /G gDProtonSite 			= dProtonSite
	Variable /G gProtonState 			= ProtonState
	Variable /G gDStructChargeSite 	= dStructChargeSite
	
	return 1
End

Function CalculateSFAForces()

	if (InitializeSFAForces() == 0)
		return 0
	endif
	
	String SimDir, SimNote="", SimParam, CalculationName
	Variable n, i, Success
	
	SetDataFolder root:SFA
	
		if (ReturnMultiSFAParameters() == 0)
			return 0
		endif
		
		NVAR  gCalcSimStart 	= root:SFA:gCalcSimStart
		NVAR  CalcSimMulti 	= root:SFA:gCalcSimMulti
		SVAR  CalcSimType 	= root:SFA:gCalcSimType
		
		if (CalcSimMulti == 1)
			
			SimNote 	= SFASimNote("One simulation of SFA forces",CalcSimType)
			SimDir 	= "root:SFA:Sim"+FrontPadVariable(gCalcSimStart,"0",3)
			
			if (ReturnSurfaceParameters(SimDir) == 0)
				return 0
			endif
			
			Success 	= HydrationEquilibria(SimDir)
			
			gCalcSimStart += 1
			
		elseif (CalcSimMulti > 1)
		
//			if (ReturnMultiSFAParameters() == 0)
//				return 0
//			endif
//			
//			SVAR gCalcParam 	= root:SFA:gCalcParam
//			NVAR gParam 	= $("root:SFA:g"+gCalcParam)
//			CalculationName 	= StringFromList(CalcSimType-1,CalcTypeList)
//			Print " 	*** Simulation of",CalculationName,"while varying",gCalcParam
//				
//			for (n=1;n<=CalcSimMulti;n+=1)
//				
//				if (CalcVary == 1)
//					gParam 	= (CalcFactor * (n-1)) + CalcStart
//				else
//					gParam 	= CalcFactor^(n-1) * CalcStart
//				endif
//				
//				SimParam 	= CalcParam+"="+num2str(gParam)
//				SimDir 		= "root:SFA:Sim"+FrontPadVariable(gCalcSimStart+n-1,"0",3)
//				SimNote 		= SFASimNote("One simulation in a series of SFA forces",CalcSimType)
//				
//				Success 	= HydrationEquilibria(SimDir,Beta_nm)
//				if (!Success)
//					break
//				endif
//				
//			endfor
		endif
	
End

Function /T SFASimNote(SimText,CalcType)
	String SimText, CalcType
	
End
	

// This function calculates the effective concentration of water molecules and counter ions in the compact layer.
// dProtonSite: 			The Proton Site density (e.g., 4 per nm2 for quartz) is the number of protonatable surface sites. Protons can bind OR Cations can bind in OS or IS
// 	dStructChargeSite: 	The Structural Charge density (e.g., 2 e- per nm2 for smectite) is the number of fixed structural charges. Cations can bind in OS or IS
// 	dProton: 					The Proton density is given by PBM modeling and the 
// 	dCation: 					The Cation density is the balance required for zero net charge
// 	rCation:				 	(e.g., 0.15 nm for Na) is the radius of the Cation. 

	// An example input from Steve and Piotr. 
	// Sum of σβ + Qβ + Qγ is due to Na+ sorption (Although now we consider no γ-layer)
	
	// pH 5.5: Sum = 0.04330 + 0.00728 + 0.00150 = 0.05208 C/m2
	// cNa 		= 2 * 0.05208 * cCoulomb	// in ions per square meter
	// ratio [SiOH] / [surface Na+ ] =   16.55   ... SiOH    dominates
	// cH 			= 16.55 * cNa
	
	// pH 10: Sum = 0.38474 + 0.01342 + 0.00276 = 0.40092 C/m2
	//	cNa 		= 2 * 0.40092 * cCoulomb	// in ions per square meter
	// ratio [SiOH] / [surface Na+ ] =   0.864   ... SiOxNa+ dominates
	// cH 			= 0.864 * cNa

// The are SINGLE-SURFACE densities and must be multiplied by 2x
Function CompactLayerDescription(Thickness,cH2O,dProtonSite,ProtonState,dStructChargeSite,dCation,rCation)
	Variable Thickness, &cH2O, dProtonSite, ProtonState, dStructChargeSite, &dCation, rCation
	
	Variable nm2tom2 		= 1e-18			// 1 nm2 = 1e-18 m2
	Variable nm3toL			= 1e-24 			// 1 nm3 = 1e-24 L
	Variable MolarVolH2ONM3 	= 18.048e21 	// nm3/mol
	
	// Calculations in nm
	Variable vGapNM3 		= Thickness 						// Volume of the gap in nm3
	
	Variable dProton 		= 2*dProtonSite*ProtonState
	dCation 		= (2*dProtonSite-dProton) + 2*dStructChargeSite		// Number of Cations per nm3 for charge balancing
	
	Variable vCationNM3 	= (4/3)*pi*(rCation^3)		// Water volume excluded by a single ion in nm3
	
	Variable vExcludeNM3 = dCation * vCationNM3		// Total excluded volue for all ions. 
	
	Variable vH2ONM3		= vGapNM3 - vCationNM3	// Volume of water in nm3, which is the gap minus the ion-excluded volume
	
	cH2O 						= vH2ONM3 * (cAvogadro / MolarVolH2ONM3)			//  Number concentration of water molecules per nm2 in the gap
	Variable xH2O 			= vExcludeNM3 * (cAvogadro / MolarVolH2ONM3)		//	  Number concentration of excluded water molecules per nm2 

	print " 	*** Beta layer is",Thickness,"nm thick and one square meter has a volume of",vGapNM3,"nm3 or",vGapNM3*nm3toL,"L."
	print " 				H2O number in the gap is",cH2O,"/nm2 with excluded water molecules",xH2O,"/nm2"
	print " 				Proton number in the gap is",dProton,"/nm2 and Proton concentration is",(dProton/cAvogadro)/(vGapNM3*nm3toL),"M"
	print " 				Cation number in the cap is ",dCation,"/nm2 and Cation concentration is",(dCation/cAvogadro)/(vGapNM3*nm3toL),"M"
End

Function CompactTest()
	Variable Thickness=1.25, cH2O
	Variable dProtonSite=1, ProtonState=0.999
	Variable dStructChargeSite=1, dCation=0
	CompactLayerDescription(Thickness,cH2O,dProtonSite,ProtonState,dStructChargeSite,dCation,0.15)
End


Function ReturnMultiSFAParameters()

		// Parameters for a suite of simulations
		String CalcParam = StrVarOrDefault("root:SFA:gCalcParam","K surface")
		Prompt CalcParam, "Parameter to vary", popup, "K surface;K counterion;K OS-IS;"
		Variable CalcVary = NumVarOrDefault("root:SFA:gCalcVary",1)
		Prompt CalcVary, "Variation method", popup, "Addition;Scaling;"
		Variable CalcStart = NumVarOrDefault("root:SFA:gCalcStart",1e-8)
		Prompt CalcStart, "Starting value of chosen parameter"
		Variable CalcFactor = NumVarOrDefault("root:SFA:gCalcFactor",1e-8)
		Prompt CalcFactor, "Difference or scaling factor"
		DoPrompt "Multiple SFA force calculations", CalcParam, CalcVary, CalcStart, CalcFactor
		if (V_flag)
			return 0
		endif
		String /G gCalcParam 		= CalcParam
		Variable /G gCalcVary 	= CalcVary
		Variable /G gCalcStart 	= CalcStart
		Variable /G gCalcFactor 	= CalcFactor
			
	return 1
End
