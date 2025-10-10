#pragma rtGlobals=1		// Use modern global access method.
#pragma rtGlobals=3			// Use modern global access method.
#pragma IgorVersion=6.2	// Requires Igor 6.2



Function PCA2DData(inX,outX,reqComponents)
	Wave inX,outX
	Variable reqComponents
	
//	Duplicate /O/D inX
	
	MatrixOp /O PCAMatrix = inX^t
	
	PCA /SEVC/RSD/SRMT/ALL/SDM/COV inX
	
	
End

// 
//  simpleICA(inX,reqComponents,w_init)
//  Parameters:
// 	inX is a 2D wave where columns contain a finite mix of independent components.
// 	reqComponents is the number of independent components that you want to extract.
//		This number must be less than or equal to the number of columns of inX.
//	w_init is a 2D wave of dimensions (reqComponents x reqComponents) and contains 
//  		an estimate of the mixing matrix.  You can simply pass $"" for this parameter
//		so the algorithm will use an equivalent size matrix filled with enoise().
//
//	The results of the function are the waves ICARes and WunMixing.  ICARes is a 2D 
//	wave in which each column contains an independent component.  WunMixing is a 2D
// 	wave that can be used to multiply the (re)conditioned input in order to obtain the unmixed 
//	components.
//
//	The code below implements the "deflation" approach for fastICA.  It is based on the 
//	fastICA algorithm: HyvŠrinen,A (1999). Fast and Robust Fixed-Point Algorithms 
//	for Independent Component Analysis. IEEE Transactions on Neural Networks, 10(3),626-634.
// 	
//	 

Function ICA2DData(inX,outX,reqComponents,w_init)
	Wave inX,outX,w_init
	Variable reqComponents
 
	// The following 3 variables can be converted into function arguments.
	Variable maxNumIterations=1000
	Variable tolerance=1e-5
	Variable alpha=1
 
	Variable i,ii
	Variable iteration 
	Variable nRows=DimSize(inX,0)
	Variable nCols=DimSize(inX,1)
 
	// check the number of requested components:
	if(reqComponents>min(dimSize(inX,0),dimSize(inX,1)))
		doAlert 0,"Bad requested number of components"
		return 0
	endif
 
	// Never mess up the original data
	Duplicate/O/Free inX,xx					
 
	// Initialize the w matrix if it is not provided.	
	if(WaveExists(w_init)==0)
		Make/O/N=(reqComponents,reqComponents) w_init=enoise(1)
	endif
 
	// condition and transpose the input:
	MatrixOP/O xx=(NormalizeCols(subtractMean(xx,1)))^t
 
	// Just like PCA:
	MatrixOP/O/Free V=(xx x (xx^t))/nRows
	MatrixSVD V
	// M_VT is not used here.
	Wave M_U,W_W,M_VT									
	W_W=1.0/sqrt(w_w)
	MatrixOP/O/Free D=diagonal(W_W)
	MatrixOP/O/Free K=D x (M_U^t)			
	KillWaves/z W_W,M_U,M_VT			 
 
	Duplicate/Free/R=[0,reqComponents-1][] k,kk
	Duplicate/O/Free kk,k									
 
	// X1 could be output as PCA result.	
//	MatrixOP/O/Free X1=K x xx
	MatrixOP/O X1=K x xx	
	
	
	
								
	// create and initialize working W; this is not an output!
	Make/O/Free/N=(reqComponents,reqComponents) W=0						
 
	for(i=1;i<=reqComponents;i+=1)										
		MatrixOP/O/Free lcw=row(w_init,i-1) 							
		if(i>1)									// decorrelating
			Duplicate/O/Free lcw,tt									
			tt=0												
			for(ii=0;ii<i;ii+=1)
				MatrixOP/O/Free r_ii=row(W,ii)				// row ii of matrix W		
				MatrixOP/O/Free ru=sum(lcw*r_ii)			// dot product		
				Variable ks=ru[0]
				MatrixOP/O/Free tt=tt+ks*r_ii							
			endfor
			MatrixOP/O/Free lcw=lcw-tt								
		endif
		MatrixOP/O/Free lcw=normalize(lcw)						
		// iterate till convergence:	
		for(iteration=1;iteration<maxNumIterations;iteration+=1)				
			MatrixOP/O/Free wx=lcw x x1						
			Duplicate/O/Free wx,gwx
			gwx=tanh(alpha*wx)						// should be supported by matrixop :(
			Duplicate/Free/R=[reqComponents,nRows] gwx,gwxf				 
			Make/O/Free/N=(reqComponents,nRows) gwxf
			gwxf=gwx[q]							// repeat the values from the first row on.
			Duplicate/O/Free gwxf,gwx
			MatrixOP/O/Free x1gwxProd=x1*gwx							 
			MatrixOP/O/Free V1=(sumRows(x1gwxProd)/numCols(x1gwxProd))^t		 
			Duplicate/O/Free wx,gwx2									 
			gwx2=alpha*(1-(tanh(alpha*wx))^2)
			Duplicate/O/Free lcw,v2										 
			v2=mean(gwx2)*lcw									 
			MatrixOP/O/Free    w1=v1-v2							 
			Redimension/N=(1,reqComponents) w1				// reduce components
			if(i>1)								// starting from the second component;
				Duplicate/O/Free w1,tt									 
				tt=0												 
				for(ii=0;ii<i;ii+=1)					                  
					MatrixOP/O/Free r_ii=row(W,ii)				 
					MatrixOP/O/Free ru=w1.(r_ii^t)						 
					ks=ru[0]
					MatrixOP/O tt=tt+ks*r_ii							 
				endfor										            
				w1=w1-tt							       			 
			endif
			MatrixOP/O/Free w1=normalize(w1)							 
			MatrixOP/O/Free limV=mag(mag(sum(w1*lcw))-1)		
//			printf "Iteration %d, diff=%g\r",iteration,limV[0]
			lcw=w1
			if(limV[0]<tolerance)
				break
			endif
		endfor
        	W[i-1][]=lcw[q]									// store the computed row in final W.
	endfor											// loop over components
	
	MatrixOP/O WunMixing=W x K								//  Calculate the un-mixing matrix
	MatrixOP/O ICARes=WunMixing x xx							// 	Un-mix
	
	// The results matrix needs to be transposed to be suitable for LLS analysis. 
	MatrixOP/O outX = ICARes^t
	
End