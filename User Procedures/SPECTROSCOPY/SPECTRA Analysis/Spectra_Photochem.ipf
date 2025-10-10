#pragma rtGlobals=1		// Use modern global access method.



// 	Elemental X-ray parameters can be found at: http://csrri.iit.edu/mucal.html
// 	X-ray attenuation through materials can be calculated at 

// X-ray attenuation through water; 
// 	Energy 		Attenutation length (um)
// 	7122.57  	691.217

// Fluorescent yield
// 	Fe:  K,L1,L2,L3: 0.3400, 0.0010, 0.0063, 0.0063 
// 	K-Alpha1,K-Beta1 at: 6.40299988 7.05700016 keV 

// 	Fe
// 	55.85 g / mole
//	density = 7.86 g / cm3
// 	absorption coefficient @ 7.120 keV 		= 3196.4 /cm
// 	absorption crosssection @ 7.120 keV 	= 3.77147e-20 cm2

// 	*********************************************************************************
//	***********			Calculate X-ray absorption and fluorescence from a dilute aqueous sample
// 	*********************************************************************************

// 	Ground and Excited state concentrations in M 
// 	X-ray cross section in cm-2
Function XrayFYPerShot(GroundState,ExcitedState,XrayCS,XrayPhotons,XrayX,XrayY,ElipseFlag)
	Wave GroundState,ExcitedState
	Variable XrayCS,XrayPhotons,XrayX,XrayY,ElipseFlag
	
	Variable i, IX, dI, IXw, dIw, um2cm=1e-4, FY, NMetals
	Variable nX=DimSize(GroundState,0), dX=deltax(GroundState)
	
	Variable Molarity 		= GroundState[0] + ExcitedState[0]	// [moles / l]
	Variable Concentration 	= 1e-3*Molarity					// [moles / cm3]
	Variable Thickness 		= pnt2x(GroundState,NX-1)		// [um]
	Variable PathLength 	= (Thickness*um2cm)				// [cm]
	Variable CollectionEff 	= 0.01								// Fraction of emitted photons collected by detector. 
	
	// Convert from molarity to number density, and waves to track FY photons emitted across the sample
	Duplicate /O GroundState, GroundStateN, GroundStateFY, XIntWater, XIntSoln
	Duplicate /O ExcitedState, ExcitedStateN, ExcitedStateFY
	GroundStateN 	= 1e-3 * cAvogadro * GroundState
	ExcitedStateN 	= 1e-3 * cAvogadro * ExcitedState
	SetScale d 0,0,"#", GroundStateFY, ExcitedStateFY, XIntWater, XIntSoln
	
	// Calculate the number of dye molecules per cm3 (mL)
	// *!* We assume that there is one metal atom per dye atom. 
	Variable DyeDensity 	= cAvogadro * Concentration
	
	// The incidence X-ray flux density, normalized to cm-2
	Variable XFluxDensity 	= XrayFluxDensity(XrayPhotons,XrayX,XrayY,ElipseFlag)
	Variable XFocusArea 	= CalculateFocusArea(XrayX,XrayY,ElipseFlag,"cm2")
	
	// The solvent (water) X-ray attenuation length in microns at the appropriate energy
	Variable AttenLength 	= 691.217
	
	// The photon flux density 
	IX 		= XFluxDensity
	IXw 	= XFluxDensity
	
	XIntWater = XFluxDensity
	XIntSoln = XFluxDensity
	
	for (i=0;i<nX;i+=1)
		// -----------------------------------------
		// Calculate the X-ray attenuation through ith slab of WATER. 
		dIw 	= IXw * (1 - exp(-dX/AttenLength))
		IXw 	-= dIw
		XIntWater[i] = IXw
		// -----------------------------------------
		
		
		// -----------------------------------------
		// Calculate the X-ray attenuation through the ith slab of SOLUTION
		dI 	= IX * (1 - exp(-dX/AttenLength))
		IX -= dI
		
		// Calculate the absorption of X-rays by the total metal concentration
		dI 	= iX * (1 - exp(-dX*XrayCS*DyeDensity))
		IX -= dI
		
		XIntSoln[i] = IX
		
		// Apportion the absorbed X-ray photons to the ground and excited states. 
		GroundStateFY[i] 	= dI * (GroundState[i]/Molarity)
		ExcitedStateFY[i] 	= dI * (ExcitedState[i]/Molarity)
		// -----------------------------------------
	endfor
		
	// Multiply by the fluorescence yield.
	GroundStateFY *= 0.34
	ExcitedStateFY *= 0.34
	
	// Now rescale back down to the X-ray focus area
	GroundStateFY 	*= XFocusArea
	ExcitedStateFY 	*= XFocusArea
	XIntSoln 		*= XFocusArea
	XIntWater 		*= XFocusArea
	
	FY 	= Area(GroundStateFY) + Area(ExcitedStateFY)
	
	NMetals 	= (1e-3 * cAvogadro * Molarity) * XFocusArea * PathLength
	
	Print " 		*** The number of metal atoms in the beam is",NMetals
	Print " 		*** The number of X-ray fluorescence photons per shot is",FY
	Print " 		*** The number of X-ray fluorescence photons per second at 3 MHz is",FY*3e6
	Print " 		*** Assume negligible absorption of Fe Ka photons, and that ",CollectionEff*100,"% of emitted photons is collected, the number is", FY*3e6/1000
	
//	sprintf number, "%u", XFocusArea
//	Print " 		The total number in the sample  			= ",number
End

// 	PhPerS is the number of photons per second reported on the ALS web page (for the regular beam current). 
// 	BC and BC2B are the regular and 2-bunch Beam Currents, respectively
Function XrayPhotonsPer2BunchPulse(PhPerS,BC,BC2B)
	Variable PhPerS,BC,BC2B
	
	// The X-ray pulse repetition rate in 2-bunch mode
	Variable XrayRR 	= 1/(328e-9)
	
	Variable PhotonsPerShot 	= (BC2B/BC) * (PhPerS/XrayRR)
	
	return trunc(PhotonsPerShot)
End

// Convert from the X-ray attenuation length, mu (cm-1), given on CXRO website
// to the cross-section per atom, in either cm2 or Mbarn
Function XrayMuToCS(mu,rho,Mm,units)
	Variable mu,rho,Mm
	String units
	
	// Number of atoms per cm3 of pure element. 
	Variable n 	= (rho/Mm) * cAvogadro
	
	// The absorption cross-section in cm2
	Variable cs 	= mu/n
	
	if (cmpstr(units,"cm2") == 0)
		return cs
	elseif (cmpstr(units,"Mbarn") == 0)
		return cs * 1e18
	endif
End

// Calculate the X-ray photon flux density in a single pulse
Function XrayFluxDensity(XrayPhotons,XrayX,XrayY,ElipseFlag)
	Variable XrayPhotons,XrayX,XrayY,ElipseFlag
	
	Variable XrayArea 	= CalculateFocusArea(XrayX,XrayY,ElipseFlag,"cm2")
	
	return XrayPhotons/XrayArea
End

// 	*********************************************************************************
//	***********			Calculate number of photons absorbed per nanoparticle in suspension
// 	*********************************************************************************

Function InputNPParams()

	Variable /G gNPConc, gNPRadius, gNPPath
	
	Variable Conc = gNPConc
	Prompt Conc, "NP concentration (mM)"
	Variable Radius = gNPRadius
	Prompt Radius, "NP radius (nm)"
	Variable Path = gNPPath
	Prompt Path, "Path length (µm)"
	DoPrompt "Suspension parameters",Conc, Radius, Path
	if (V_flag)
		return 0
	endif

	gNPConc 	= Conc
	gNPRadius 	= Radius
	gNPPath 	= Path
	
	return 1
End

Function InputLaserParams()

	Variable /G gPumpEnergy, gPumpWavelength, gLaserX, gLaserY, gEllipseFlag
	
	Variable Energy = gPumpEnergy
	Prompt Energy, "Pump pulse energy (µJ)"
	Variable Wavelength = gPumpWavelength
	Prompt Wavelength, "Pump pulse wavelength (nm)"
	Variable LaserX = gLaserX
	Prompt LaserX, "Focus horizontal diameter (µm)"
	Variable LaserY = gLaserY
	Prompt LaserY, "Focus vertical diameter (µm)"
	Variable Ellipse = gEllipseFlag
	Prompt Ellipse, "Spot profile",popup,"elliptical;rectangular;"
	DoPrompt "Laser parameters", Energy, Wavelength, LaserX, LaserY, Ellipse
	if (V_flag)
		return 0
	endif

	gPumpEnergy 		= Energy
	gPumpWavelength 	= Wavelength
	gLaserX 			= LaserX
	gLaserY 			= LaserY
	gEllipseFlag 		= Ellipse
	
	return 1
End

// 		Formula weight of ZnS is 97
// 		Mass density of sphalerite is 3.85 g/cm3

Function NanoparticleExcitation()
	
	String number, number2
	Variable um2cm=1e-4
	Variable i, dX, nX
	
	if (InputNPParams() == 0)
		return 0
	endif
	NVAR gNPConc 			= gNPConc
	NVAR gNPRadius 		= gNPRadius
	NVAR gNPPath 			= gNPPath
	Variable PathLength 	= gNPPath*um2cm
	
	if (InputLaserParams()==0)
		return 0
	endif
	NVAR gPumpEnergy 		= gPumpEnergy
	NVAR gPumpWavelength = gPumpWavelength
	NVAR gLaserX			= gLaserX
	NVAR gLaserY			= gLaserY
	NVAR gEllipseFlag 		= gEllipseFlag
	Variable RepRate 		= 3e6
	
	Variable LaserPower 	= RepRate * 1e-6 * gPumpEnergy
	Variable LaserPower2 	= 1e3 * 1e-6 * gPumpEnergy
	
	// Calculate incident photon flux density in number / cm-2
	Variable FluxDensity 	= LaserPulseFluxDensity(gPumpEnergy,gPumpWavelength,gLaserX,gLaserY,gEllipseFlag)
	// Calculate energy density in mJ / cm-2
	Variable Fluence		= LaserPulseFluence(gPumpEnergy,gLaserX,gLaserY,gEllipseFlag)
	
	// Calculate the absorption cross-section of one nanoparticle
	Variable Nnp = 2.8
	Variable Nsv = 1.38
	Variable Anp = 1.4e5
	Variable E1 = 7.6
	Variable E2 = 2.4
	Variable CrossSection 	= NanoparticleCrossSection(gNPRadius,Nnp,Nsv,Anp,E1,E2)
	
	// Calculate the number of nanoparticles per cm3 (mL)
	Variable FW 			= 97
	Variable Density 		= 3.85
	Variable NPDensity 		= NanoparticleNumberDensity(gNPRadius,gNPConc,FW,Density)
	// Convert to the nanoparticle molarity
	Variable NPMolar 		= 1e3 * NPDensity/cAvogadro
	
	Print " 		The pulse fluence is",Fluence,"mJ / cm2"
//	Print " 		At 3 MHz, the laser power is",LaserPower,"W"

	Print " 		At 3 MHz, the laser power is",LaserPower,"W"
	Print " 		At 1 kHz, the laser power is",LaserPower2,"W"
	
	sprintf number, "%u  or %3.2e", FluxDensity, FluxDensity
	Print " 		The number of incident photons per cm2 	= ",number
	sprintf number, "%u  or %3.2e", NPDensity, NPDensity
	Print " 		The number of nanoparticles per mL 	= ",number 
	sprintf number, "%W0PM", NPMolar
	Print " 			... equivalent to a concentration of  	= ",number 
	sprintf number, "%3.2e", CrossSection
	Print " 		The nanoparticle absorption cross section is 	= ",number,"cm2"
	
	// The number of x points across the sample. Set dX = 1 micron = 0.0001 cm
	dX 	= 1
	nX 	= (gNPPath/dX)
	
	// Number of photoexcitations, starting at point 1/2 dX
	Make /O/D/N=(nX) NPExcitation, NPMultiExciton
	SetScale /P x, dX/2, dX,  "µm", NPExcitation, NPMultiExciton
	SetScale d 0,0,"#", NPExcitation
	
	// The photon flux values, starting at point 0
	Make /O/D/N=(nX+1) Intensity = 0
	Intensity[0] = FluxDensity
	
	Variable IX, dI, dItot=0, dIalt, dN
	
	// The NP concentration, NPDensity, is constant across the path length
	for (i=0;i<nX;i+=1)
		
		// The intensity incident on the ith slab
		IX 	= Intensity[i]
		
		// Calculate the number of nanoparticles in the slab of thickness dX
		dN 	= NPDensity * dX * um2cm
		
		// Calculate the loss in photon flux density traversing the ith slab. 
		// This is the limiting expression for dX --> 0
		dI 	= IX * CrossSection * dN
		
		if (0)
			// This is the full expression, but it gives same results for dX = 1 µm
			dIalt 	= IX * (1 - exp(-1 * CrossSection * NPDensity * dX * um2cm))
		endif
		
		// Record the number of photons that passed to the next slab without absorption
		Intensity[i+1] 		=  Intensity[i] - dI
		
		 // Record the mean number of excitations per nanoparticle in this slab:
		 // 		i.e., number of photons absorbed / number of nanoparticles
		NPMultiExciton[i] 	= dI/dN
		
		// The number of photons absorbed is NOT equal to the number of excited nanoparticles. 
		// Calculate it from the average number of excitations and convert back to concentration
		NPExcitation[i] 	= (min(1,NPMultiExciton[i]) * dN)/(dX * um2cm)
		
		dItot += dI
	endfor
	
	// Plot the nanoparticle excitation profile in molarity units. 
	Duplicate /O/D NPExcitation, NPExcMolar
	NPExcMolar 	= 1e3 * NPExcMolar/cAvogadro
	SetScale d 0,0,"M", NPExcMolar
End

Function NanoparticleAbsorption(Concentration,Absorption,Io,dX,CS)
	Wave Concentration, Absorption
	Variable Io, dX, CS
	
	Variable i, dI, dItot=0
	Variable nX=DimSize(Absorption,0), um2cm=1e-4
	
	// The photon flux density 
	Variable IX = Io
	
	for (i=0;i<nX;i+=1)
		// Calculate the loss in photon flux density traversing the ith slab. 
		dI 	= IX * (1 - exp(-1 * CS * Concentration[i] * dX * um2cm))
		
		// Record the number of excited dye molecules in this slab = number of photons lost. 
		Absorption[i] 	= dI
		
		// The new photon flux density incident on the subsequent slab
		IX -= dI
		dItot += dI
	endfor
	
	// Change the local concentration values across the sample. 
	Concentration 	-= Absorption/(dX*um2cm)
	
	return dItot
End

// 	Calculate the absorption cross-section (cm2) of a single nanoparticle
// 		Nnp = refractive index of nanoparticle
// 		Nsv = refractive index of solvent
// 		Anp = absorption cross-section of bulk material
// 		E1, E2 are real and imaginary components of refractive index
Function NanoparticleCrossSection(Radius,Nnp,Nsv,Anp,E1,E2)
	Variable Radius,Nnp,Nsv,Anp,E1,E2
	
	Variable V 	= NanoparticleVolume(Radius)
	
	Variable f2	= (9*Nsv)/((E1+2*Nsv^2)^2 + (E2)^2)
	
	Variable CS 	= (Nnp/Nsv) * V * Anp * f2
	
	return CS
End

//	Input = radius in nanometers
// 	Output = volume in cm3
Function NanoparticleVolume(Radius)
	Variable Radius
	
	Variable nm3tocm3=1e-21
	
	return (4/3)*pi*(Radius^3)*nm3tocm3
End

//  Calculate the number of nanoparticles per mL 
// 		Radius is the nanoparticle radius in nm 
// 		Concentration is the number of MILLIMOLES per liter of the formula, e.g., 5 mM of ZnS
Function NanoparticleNumberDensity(Radius,Concentration,FW,Density)
	Variable Radius, Concentration,FW,Density
	
	// Calculate nanoparticle volume in cm3
	Variable Vnp 		= NanoparticleVolume(Radius)
	
	// The volume of 1 mL suspension that is taken up by nanoparticles 
	Variable VolFrac 	= NanoparticleVolumeFraction(Concentration,FW,Density)
	
	return VolFrac/Vnp
End

// 	Calculate the Volume Fraction of a suspension of nanoparticles. 
// 		Concentration is the number of MILLIMOLES per liter of the formula, e.g., 5 mM of ZnS

// 	Note: 	Can use this to calculate the Effective Thickness (in cm) if all the nanoparticle volume was in a thin slab
//			This is numerically identical to the Volume Fraction if the units are cm.
Function NanoparticleVolumeFraction(Concentration,FW,Density)
	Variable Concentration,FW,Density
	
	// Convert from mM to moles per liter
	Variable Molarity 		= Concentration/1000
	
	// Convert from moles per liter to moles per milliliter
	Variable MolesPerMil 	= Molarity/1000
	Variable MassPerMil 	= MolesPerMil * FW
	Variable VolPerMil 		= MassPerMil/Density
	Variable VolFrac 		= VolPerMil
	
	return VolFrac
End



//	Ru(bpy3)2+ absorbs UV light and visible light. An aqueous solution absorbs at 452 (+/-3 nm) with an extinction coefficient of 11,500 M-1 cm-1

//	Bound 27DCF has an extinction coefficient of 39,700 M-1 cm-1 at 520 nm

//  The molar extinction coefficient of ferrioxalate at 268nm (4800 cm1 M1) Ogi et al
//	Then calculate it to be 849 at 355 nm

// 	*********************************************************************************
//	***********			Calculate (saturated) absorption through thin sample containing a DYE
// 	*********************************************************************************

// 	Need to distinguish between the number, n, of dye molecules excited in a given slab that is traversed by photons
// 	and the local dye concentration, C, that is measured at the center of the slab. 
// 					n [# cm-2]  =  C [# cm-3] x dX [cm]
// 	In order to avoid explicitly working out an interpolation scheme, use two x axes. One of n+1 points to describe the
// 	changes in photon flux. One of n points to describe the concentration. Then interpolate C onto the full x axis. 

Function Photoexcitation(epsilon,Concentration,Thickness,PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag)
	Variable epsilon,Concentration,Thickness,PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag
	
	String number, number2
	Variable i, dF, nF, dX, nX, um2cm=1e-4
	Variable TotalAbsorbed, ExcitationFraction
	
	Variable PathLength 	= (Thickness*um2cm)
	Variable Molarity 		= (Concentration/1000)
	
	Variable RepRate 		= 3e6
	Variable LaserPower 	= RepRate * 1e-6 * PulseEnergy
	Variable LaserPower2 	= 1e3 * 1e-6 * PulseEnergy
	
	// Convert the molar extinctino coefficient [M-1 cm-1] into cross section [cm-2]
	Variable CrossSection 	= MolarExtinctionToCrossSection(epsilon)
	
	// Calculate incident photon flux density in number / cm-2
	Variable FluxDensity 	= LaserPulseFluxDensity(PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag)
	
	// Calculate energy density in mJ / cm-2
	Variable Fluence		= LaserPulseFluence(PulseEnergy,LaserX,LaserY,EllipseFlag)

	// Calculate the number of dye molecules per cm3 (mL)
	Variable DyeDensity 	= 1e-3 * cAvogadro * Molarity
	
	// Calculate the number of dye molecules in the sample of given Thickness, assuming 1 cm2 area. 
	Variable DyeNumber 	= 1e-3 * cAvogadro * Molarity * PathLength
	
	// Divide up the excitation beam so that only 1% of sample can be excited
	dF 	= min(DyeDensity/100,FluxDensity/100)
	
	// This is the number of iterations to pass the entire beam through the sample. 
	nF 	= trunc(FluxDensity/dF)
	
	nF 	= min(1000,nF)
	
	Print " 		The pulse fluence is",Fluence,"mJ / cm2"
	Print " 		At 3 MHz, the laser power is",LaserPower,"W"
	Print " 		At 1 kHz, the laser power is",LaserPower2,"W"
	sprintf number, "%u", FluxDensity
	Print " 		The number of incident photons per cm2 	= ",number
	sprintf number, "%u", DyeDensity
	Print " 		The number of dye molecules per mL 	= ",number 
	sprintf number, "%u", DyeNumber
	Print " 		The total number in the sample  			= ",number
	sprintf number, "%u", dF
	Print " 		The number of photons per iteration 		= ",number,"and number of iterations = ",nF
	
	// The number of x points across the sample. Set dX = 1 micron = 0.0001 cm
	dX 	= 1
	nX 	= (Thickness/dX)
	
	Make /O/D/N=(nF) NExcitedF
	
	// Local concentration values, starting at point 1/2 dX
	Make /O/D/N=(nX) DyeConcXo, DyeConcX, NExcitedX
	SetScale /P x, dX/2, dX,  "µm", DyeConcXo, DyeConcX, NExcitedX
	SetScale d 0,0,"#", DyeConcXo, DyeConcX
	
	DyeConcXo 	= DyeDensity
	DyeConcX 	= DyeDensity
	
	// The photon flux values, starting at point 0
	Make /O/D/N=(nX+1) Intensity
	Intensity 		= 0
	Intensity[0] 	= FluxDensity
	
	for (i=0;i<nF;i+=1)
		NExcitedF[i] = OpticalAbsorption(DyeConcX, NExcitedX,dF,dX,CrossSection)
	endfor
	
	TotalAbsorbed 	= sum(NExcitedF)
	
	sprintf number, "%u", TotalAbsorbed
	Print " 		Total number of photons absorbed 		= ",number,"and the fraction absorbed = ",TotalAbsorbed/FluxDensity
	Print " 		The dye excitation fraction = ",TotalAbsorbed/DyeNumber
	
	// Plot the ground and excited state profiles in molarity units. 
	Duplicate /O/D DyeConcX, GroundState, ExcitedState
	GroundState 	= 1e3 * DyeConcX/cAvogadro
	ExcitedState		= 1e3 * (DyeConcXo-DyeConcX) / cAvogadro
	SetScale d 0,0,"M", GroundState, ExcitedState
End

Function OpticalAbsorption(Concentration,Absorption,Io,dX,CS)
	Wave Concentration, Absorption
	Variable Io, dX, CS
	
	Variable i, dI, dItot=0
	Variable nX=DimSize(Absorption,0), um2cm=1e-4
	
	// The photon flux density 
	Variable IX = Io
	
	for (i=0;i<nX;i+=1)
		// Calculate the loss in photon flux density traversing the ith slab. 
		dI 	= IX * (1 - exp(-1 * CS * Concentration[i] * dX * um2cm))
		
		// Record the number of excited dye molecules in this slab = number of photons lost. 
		Absorption[i] 	= dI
		
		// The new photon flux density incident on the subsequent slab
		IX -= dI
		dItot += dI
	endfor
	
	// Change the local concentration values across the sample. 
	Concentration 	-= Absorption/(dX*um2cm)
	
	return dItot
End

//	*** Convert the molar extinction coefficient to cross section
// 	epsilon in M-1 cm-1
//	sigma in cm-2
Function MolarExtinctionToCrossSection(epsilon)
	Variable epsilon
	
	return (1000 * ln(10) * epsilon) / cAvogadro
End

// 	*********************************************************************************
//	***********			Convert between LASER PULSE characteristics
// 	*********************************************************************************

//	*** Calculate the number of photons in a laser pulse
// 	Pulse energy in uJ
// 	Wavelength in nm
Function PhotonsPerPulse(PulseEnergy,Wavelength)
	Variable PulseEnergy,Wavelength
	
	// The photon energy in eV
	Variable hv 	= nmToeV(Wavelength)
	
	// The number of photons in the pulse
	return PulseEnergy/(1000000*cJ2eV*hv)
End

//	*** Calculate the laser or X-ray focus area for a rectangle or ellipse. 
// 	X, Y, dimensions in microns
Function CalculateFocusArea(FocusX,FocusY,EllipseFlag,Units)
	Variable FocusX,FocusY,EllipseFlag
	String Units
	
	Variable um2cm =1e-4
	Variable Area1 	= (FocusX/2) * (FocusY/2)
	
	Area1 	= (EllipseFlag == 1) ? (Area1 * pi) : (Area1 * 4)
	
	if (cmpstr(Units,"um2") == 0)
		return Area1
	elseif (cmpstr(Units,"cm2") == 0)
		return Area1 * um2cm^2
	endif
End

// *** Calculate energy density in mJ / cm-2
// 	Pulse energy in uJ
Function LaserPulseFluence(PulseEnergy,LaserX,LaserY,EllipseFlag)
	Variable PulseEnergy,LaserX,LaserY,EllipseFlag
	
	// Calculate the laser focus area
	Variable FocusArea 	= CalculateFocusArea(LaserX,LaserY,EllipseFlag,"cm2")
	
	return PulseEnergy/(1000*FocusArea)
End

//	*** Calculate the photon flux density n in a laser pulse
Function LaserPulseFluxDensity(PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag)
	Variable PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag
	
	// Calculate the laser focus area
	Variable FocusArea 	= CalculateFocusArea(LaserX,LaserY,EllipseFlag,"cm2")
	
	// Calculate the number of photons
	Variable Photons 	= PhotonsPerPulse(PulseEnergy,Wavelength)
	
//	print Photons
	
	// Calculate flux density in photons / cm-2
	return Photons/FocusArea
End
































//// 	Calculate the probability of X-ray absorption for a 
//Function XrayAbsnProb(Concentration,CS,XrayPhotons,XrayX,XrayY,ElipseFlag)
//	Variable Concentration,CS,XrayPhotons,XrayX,XrayY,ElipseFlag
//	
//	
//End

// 		Concentration is the number of MILLIMOLES per liter of the formula, e.g., 5 mM of ZnS
// 		Thickness is the cuvette pathlength in microns. 
//Function NanoparticleExcitation(AbsorptionLength,Concentration,FW,Density,Thickness,PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag)
//	Variable AbsorptionLength,Concentration,FW,Density,Thickness,PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag
//	
//	Variable um2cm=1e-4
//	
//	Variable PathLength 	= (Thickness*um2cm)
//	
//	// This is the thickness of a slab of the nanoparticle material equal to the same volume
//	Variable EffPathLen 	= NanoparticleVolumeFraction(Concentration,FW,Density)
//	
//	// Calculate incident photon flux density in number / cm-2
//	Variable FluxDensity 	= LaserPulseFluxDensity(PulseEnergy,Wavelength,LaserX,LaserY,EllipseFlag)
//	
//	// Calculate energy density in mJ / cm-2
//	Variable Fluence		= LaserPulseFluence(PulseEnergy,LaserX,LaserY,EllipseFlag)
//
//End