#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function NV_FfromB(B)
	Variable B
	
	Variable F = 2.87 - 0.028*B

	return F
	
End