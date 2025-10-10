#pragma rtGlobals=1		// Use modern global access method.

// AGNOV02
// The following function performs a Varimax rotation of inWave subject to the specified epsilon.  
// The algorithm follows the paper by Henry F Kaiser 1959 and involves normalization followed by
// rotation of two vectors at a time.
// The value of epsilon determines convergence.  The algorithm computes the tangent of 4*rotation 
// angle and the value is compared to epsilon.  If it is less than epsilon it is assumed to be essentially
// zero and hence no rotation.

Function WM_VarimaxRotation(inWave,epsilon)
	Wave inWave
	Variable epsilon
	
	Variable rows=DimSize(inWave,0)
	Variable  cols= DimSize(inWave,1)
	
	// start by computing the "communalities"
	 Make/O/N=(cols) communalities
	 Variable i,j,theSum
	 for(i=0;i<cols;i+=1)
	 	theSum=0
	 	for(j=0;j<rows;j+=1)
	 		theSum+=inWave[j][i]*inWave[j][i]
	 	endfor
	 	communalities[i]=sqrt(theSum)
	 endfor
	 
	 Make/O/N=(2,2) rotationMatrix
	 Make/O/N=(rows,2) twoColMatrix
	 Duplicate/O inWave, varimaxWave
	 // normalize the wave
	 for(i=0;i<cols;i+=1)
	 	for(j=0;j<rows;j+=1)
	 		varimaxWave[j][i]/=communalities[i]
	 	endfor
	 endfor
	 
	 // now start rotating vectors:
	 Variable convergenceLevel=cols*(cols-1)/2
	 Variable rotation,col1,col2
	 Variable rotationCount=0
	 do
	 	for(col1=0;col1<cols-1;col1+=1)
	 		for(col2=col1+1;col2<cols;col2+=1)
				rotation=doOneVarimaxRotation(varimaxWave,rotationMatrix,twoColMatrix,col1,col2,rows,epsilon)
				rotationCount+=1
				if(rotation)
					convergenceLevel=cols*(cols-1)/2
				else
					convergenceLevel-=1
					if(convergenceLevel<=0)
						 for(i=0;i<cols;i+=1)
						 	for(j=0;j<rows;j+=1)
						 		varimaxWave[j][i]*=communalities[i]
						 	endfor
						 endfor
						KillWaves/Z rotationMatrix,twoColMatrix,communalities,M_Product
						printf "%d rotations\r",rotationCount
						return 0
					endif
				endif
			endfor
		endfor
	while(convergenceLevel>0)

	KillWaves/Z rotationMatrix,twoColMatrix,communalities,M_Product
	printf "%d rotations\r",rotationCount
End

// this function is being called by WM_VarimaxRotation(); it has no use on its own.
Function  doOneVarimaxRotation(norWave,rotationMatrix,twoColMatrix,col1,col2,rows,epsilon)
	wave norWave,rotationMatrix,twoColMatrix
	Variable col1,col2,rows,epsilon
	
	Variable A,B,C,D
	Variable i,xx,yy
	Variable sqrt2=sqrt(2)/2
	
	A=0
	B=0
	C=0
	D=0
	
	for(i=0;i<rows;i+=1)
		xx=norWave[i][col1]
		yy=norWave[i][col2]
		twoColMatrix[i][0]=xx
		twoColMatrix[i][1]=yy
		A+=(xx-yy)*(xx+yy)
		B+=2*xx*yy
		C+=xx^4-6.*xx^2*yy^2+yy^4
		D+=4*xx^3*yy-4*yy^3*xx
	endfor
	
	Variable numerator,denominator,absNumerator,absDenominator
	numerator=D-2*A*B/rows
	denominator=C-(A*A-B*B)/rows
	absNumerator=abs(numerator)
	absDenominator=abs(denominator)
	
	Variable cs4t,sn4t,cs2t,sn2t,tan4t,ctn4t
	
	// handle here all the cases :
	if(absNumerator<absDenominator)
		tan4t=absNumerator/absDenominator
		if(tan4t<epsilon)
			return 0								// no rotation
		endif
		cs4t=1/sqrt(1+tan4t*tan4t)
		sn4t=tan4t*cs4t
		
	elseif(absNumerator>absDenominator)
		ctn4t=absDenominator/absNumerator
		if(ctn4t<epsilon)							// paper sec 9
			sn4t=1
			cs4t=0
		else
			sn4t=1/sqrt(1+ctn4t*ctn4t)
			cs4t=ctn4t*sn4t
		endif
	elseif(absNumerator==absDenominator)
		if(absNumerator==0)
			return 0;								// undefined so we do not rotate.
		else
			sn4t=sqrt2
			cs4t=sqrt2
		endif
	endif
	
	// at this point we should have sn4t and cs4t
	cs2t=sqrt((1+cs4t)/2)
	sn2t=sn4t/(2*cs2t)
	
	Variable cst=sqrt((1+cs2t)/2)
	Variable snt=sn2t/(2*cst)
	
	// now converting from t to the rotation angle phi based on the signs of the numerator and denominator
	Variable csphi,snphi
	
	if(denominator<0)
		csphi=sqrt2*(cst+snt)
		snphi=sqrt2*(cst-snt)
	else
		csphi=cst
		snphi=snt
	endif
	
	if(numerator<0)
		snphi=-snt
	endif
	
	// perform the rotation using matrix multiplication
	rotationMatrix={{csphi,snphi},{-snphi,csphi}}
	MatrixMultiply twoColMatrix,rotationMatrix
	// now write the rotation back into the wave
	Wave M_Product
	for(i=0;i<rows;i+=1)
		norWave[i][col1]=M_Product[i][0]
		norWave[i][col2]=M_Product[i][1]
	endfor
	return 1
End