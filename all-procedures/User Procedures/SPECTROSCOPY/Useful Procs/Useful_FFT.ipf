#pragma rtGlobals=1		// Use modern global access method.


Function HanningWindow(wCoefs,x)
	Wave wCoefs
	Variable x
	
	Variable center 	= wCoefs[0]
	Variable width 	= wCoefs[1]
	Variable sill 	= wCoefs[2]
	
	Variable xmin = center - width/2
	Variable xmax = center + width/2
	
	if (x < xmin)
		return 0
	elseif (x < (xmin + sill))
		return sin((pi/(2*sill)) * (x-xmin))^2
	elseif (x < (xmax - sill))
		return 1
	elseif (x <= xmax )
		return cos(pi/(2*sill) * (x+sill-xmax))^2
	elseif (x > xmax)
		return 0
	endif
End

Function GaussianWindow(wCoefs,x)
	Wave wCoefs
	Variable x
	
	Variable center 	= wCoefs[0]
	Variable width 	= wCoefs[1]
	Variable tail 	= wCoefs[2]	// Intensity at width, e.g., 10%
	
	Variable xmin 	= center - width/2
	Variable xmax 	= center + width/2
	Variable sigma	= (width/2)/sqrt(-2*ln(tail))
	
	return exp(-(x-center)^2/(2*sigma^2))
End

Function LanczosWindow(wCoefs,x)
	Wave wCoefs
	Variable x
	
	Variable center 	= wCoefs[0]
	Variable width 	= wCoefs[1]
	Variable tail 	= wCoefs[2]	// Intensity at width, e.g., 10%
	
	Variable xmin = center - width/2
	Variable xmax = center + width/2
	
	// Lanczos function
	
	if (x < xmin)
		return 0
	elseif (x < xmax)
		return sinc(pi * (x-center)/(width/2))
	else
		return 0
	endif
End
