#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <Peak AutoFind>

//Absorption-Load
// Version 5: removed "default unit" in SetWaveScale
// Version 6: Added interpolate2 function to SetWaveScale, Added test for not equally spaced waves.
// Version 7: added linear Background removal function
// Version 8: added Differentition
// Version 9: split to different Files
// Version 10: Peak Find
// Version 11: Background Fit to Minima
// Version 12: Double Exponential fit


// Included by Florian Oberndorfer to support loading an entire folder of spectra
Function AbsorptionLoadDirectory()
	String fileList = "", file, directory
	Variable numFiles = 0, i

	directory = PopUpChooseDirectory()
	fileList = PathActionGetFileList(directory, ".csv")
	numFiles = ItemsInList(fileList)
	
	for(i=0; i<numFiles; i+=1)
		file = StringFromList(i, fileList)
		file = directory + file
		AbsorptionLoadFile(strFile = file)
	endfor
End


Function AbsorptionLoadFile([strFile]) //altered by Florian Oberndorfer
	String strFile 							//altered by Florian Oberndorfer
	String strFileName, strFileType
	Variable numStart, numEnd
	
	if(ParamIsDefault(strFile))
		strFile=PopUpChooseFile(strPrompt="Choose Absorption File")
	endif
	if (strlen(strFile)>0)
		//Headings are in 2nd(0-1-2-->1) line, data starts in 2nd line, load all (0) from 1 to 2 columns, where d
		LoadWave/A/D/J/K=1/L={1,2,0,0,2}/O/Q strFile
		wave wavWaveLength	= $stringfromlist(0,S_waveNames)
		wave wavIntensity = $stringfromlist(1,S_waveNames)
		//Delete last point.
		WaveStats/Q/Z/M=1 wavWaveLength		
		DeletePoints/M=0 (V_npnts),1, wavWaveLength, wavIntensity

		strFileName = ParseFilePath(3, strFile, ":", 0, 0)
		strFileType  = ParseFilePath(4, strFile, ":", 0, 0)
		strFileName = ReplaceString(" ",strFileName,"")
		
		if (WaveExists($strFileName))			
			//strFileName += "_autoload"
			Killwaves/Z $strFileName
		endif
		String strScaledWave = SetWaveScale(strX = nameofwave(wavWaveLength), strY = nameofwave(wavIntensity), strXUnit = "nm", strYUnit = "a.u.")
		wave wavScaledWave = $strScaledWave
		if (strlen(strScaledWave) > 0)
			duplicate/O wavScaledWave $strFileName		
			KillWaves/Z wavWaveLength, wavIntensity, wavScaledWave
			//Display $strFileName
			return 1
		else
			KillWaves/Z wavWaveLength, wavIntensity
			return 0
		endif
		
		
	endif
End

Function/Wave AbsorptionPrompt()
	string strWave = "absorption"
	
	Prompt strWave, "Wave for Peak-Analysis",popup TraceNameList("", ";",1)	//top graph "", seperate by ";", option 1: Include contour traces
	DoPrompt "Enter wave", strWave

	//$strIntensity is not possible for renamed traces: tracename#1 tracename#2 (see Instance Notation)
	wave wavInput = TraceNameToWaveRef("",strWave) 
	return wavInput
End

Function AbsorptionBgLinear()
	AbsorptionBgLinearWave(AbsorptionPrompt())
End

// no error checking here.
// create linar background correction between pcsrA and pcsrB
Function AbsorptionBgLinearWave(wavInput)
	wave wavInput
	
	SetDataFolder root:
	make/o/n=2 line
	line={wavInput[pcsr(A)],wavInput[pcsr(B)]}
	SetScale x, x2pnt(wavInput,pcsr(A)), x2pnt(wavInput, pcsr(B)), line
	string strNewWave = nameofwave(wavInput) + "bgcorr"
	duplicate/O wavInput $strNewWave
	wave wavOutput = $strNewWave
	interpolate2/T=1/I=3/Y=wavOutput line
	wavOutput = wavInput-wavOutput
	Killwaves/Z line
End

Function/Wave AbsorptionDifferentiateWave(wavInput, numSmooth, type)
	Wave wavInput
	Variable numSmooth, type
	
	String newName
	DFREF dfr = GetWavesDataFolderDFR(wavInput)
	Wave wavOutput, wavSmooth
	
	newName = NameOfWave(wavInput) + "_d"
	Duplicate/O wavInput, dfr:$newName
	Wave wavOutput = dfr:$newName
	
	// smooth before
	Wave wavSmooth = AbsorptionSmoothWave(wavInput, numSmooth)
	
	Differentiate/METH=(type) wavSmooth/D=wavOutput
	
	// smooth after
	Wave wavSmooth = AbsorptionSmoothWave(wavOutput, 0)
	wavOutput = wavSmooth
	
	return wavOutput
End

Function/Wave AbsorptionDifferentiate2Wave(wavInput, numSmooth)
	Wave wavInput
	Variable numSmooth
		
	// smooth and build second derivative
	Wave wavFirst  = AbsorptionDifferentiateWave(wavInput, numSmooth, 0)
	Wave wavSecond = AbsorptionDifferentiateWave(wavFirst, numSmooth, 0)
	
	return wavSecond
End


Function/Wave AbsorptionSmoothWave(wavInput, numSmooth)
	Wave wavInput
	Variable numSmooth
	
	String newName
	DFREF dfr = GetWavesDataFolderDFR(wavInput)
	
	Make/FREE/N=(Dimsize(wavInput,0), Dimsize(wavInput,1)) wavOutput = wavInput
	SetScale/P x, DimOffset(wavInput, 0), DimDelta(wavInput, 0), wavOutput
	SetScale/P y, DimOffset(wavInput, 1), DimDelta(wavInput, 1), wavOutput
	
	if (numSmooth>0)
		Smooth numSmooth, wavOutput
	endif
	
	return wavOutput
End



Function/Wave AbsorptionRemoveJump(wavInput)
	wave wavInput
	
	Variable gap, gapLeft, gapRight
	Variable i, count
	String newName
	
	// create wave for jump correction
	DFREF dfr = GetWavesDataFolderDFR(wavInput)
	newName = NameOfWave(wavInput) + "_j"
	Duplicate/O wavInput, dfr:$newName	
	Wave wavJump = dfr:$newName	
	wavJump = 0
		
	// get gap
	Wave wavGaps = AbsorptionSearchGap(wavInput, 700, 900, 1.95)
	count = Dimsize(wavGaps, 0)	
	print num2str(count) + " gaps found."

	// if no gap was found return original wave
	if (count == 0)
		print "AbsorptionRemoveJump: No gap found"
		wavJump = wavInput
		return wavJump
	endif
	
	// currently only for one gap possible. 1 gap --> two values are found at start of Gap and end of Gap
	if (count > 2)
		print "AbsorptionRemoveJump: Too many gaps in defined range"
		return wavJump
	endif
	
	// estimate values if no gap was present by differentiation
	Wave wavDifferentiated = AbsorptionDifferentiateWave(wavInput, 0, 2) // type = Backward difference
	// estimated = f(x0) + f'(x0) * delta x
	// delta x = x_start - x_end
	// gap = estimated - real
	
	gap = wavInput[wavGaps[1]]	- wavInput[wavGaps[0]] + wavDifferentiated[wavGaps[0]] * DimDelta(wavInput, 0) * (wavGaps[1] - wavGaps[0])
	wavJump[0,wavGaps[0]] = gap

	wavJump = wavInput + wavJump
	
	return wavJump
End

Function/Wave AbsorptionSearchGap(wavInput, wlmin, wlmax, tolerance)
	Wave wavInput
	Variable wlmin, wlmax, tolerance
	
	Variable i
	Variable estimated, follower
	Variable found = 0
	Variable Pstart, Pend
	
	Wave wavDifferentiated = AbsorptionDifferentiateWave(wavInput, 0, 2) // type = Backward difference
	WaveStats/Q/R=(wlmin, wlmax) wavDifferentiated

	Make/I/FREE/N=0 wavFound

	tolerance = V_rms + tolerance * V_sdev
	
	// assure ascending p points
	Pstart = x2pnt(wavInput,wlmin)
	Pend = x2pnt(wavInput,wlmax)
	If (Pstart > Pend)
		Pend = Pstart
		Pstart = x2pnt(wavInput,wlmax)
	endif

	// search for gap in defined rannge. Maybe clean returned gaps.
	for (i = Pstart; i < Pend; i += 1)		
		estimated = wavInput[i] + wavDifferentiated[i] * DimDelta(wavInput, 0)
		follower = wavInput[i+1]
		if (abs(estimated - follower) > tolerance)
			FindValue/I=(i) wavFound
			if (V_value == -1)			
				found += 1
				Redimension/N=(found) wavFound
				wavFound[(found-1)] = i
			endif
		endif
	endfor
	
	return wavFound
End

// see AutomaticallyFindPeaks from WM's <Peak AutoFind>
Function/Wave AbsorptionPeakFind(wavInput, [sorted, redimensioned])
	Wave wavInput
	Variable sorted, redimensioned

	if (ParamIsDefault(redimensioned))
		redimensioned = 0
	endif
	if (ParamIsDefault(sorted))
		sorted = 0
	endif
	
	Wave wavXdata = $("_calculated_")
	Variable maxPeaks, minPeakPercent
	Variable pBegin, pEnd
	Variable/C estimates
	Variable noiselevel, smoothingFactor	

	Variable peaksFound
	String newName
	
	// create wave for holding peaks
	DFREF dfr = GetWavesDataFolderDFR(wavInput)
	newName = NameOfWave(wavInput) + "peaks"
	Make/O/N=(maxPeaks,7) dfr:$newName/Wave=wavOutput
	
	// label columns of wave for readability
	SetDimLabel 1, 0, wavelength, wavOutput
	SetDimLabel 1, 1, height, wavOutput
	SetDimLabel 1, 2, width, wavOutput
	SetDimLabel 1, 3, positionY, wavOutput
	SetDimLabel 1, 4, positionX, wavOutput
	SetDimLabel 1, 5, widthL, wavOutput // from WM: somewhat free width left and right
	SetDimLabel 1, 6, widthR, wavOutput
	
	// input parameters for WM's AutoFindPeaksNew
	pBegin = 0
	pEnd = DimSize(wavInput, 0) - 1
	
	minPeakPercent = 5
	maxPeaks = 50
	
	estimates = EstPeakNoiseAndSmfact(wavInput, pBegin, pEnd)
	noiselevel=real(estimates)
	smoothingFactor=imag(estimates)
	
	peaksFound = AutoFindPeaksNew(wavInput, pBegin, pEnd, noiseLevel, smoothingFactor, maxPeaks)
	WAVE W_AutoPeakInfo // output of AutoFindPeaksNew
	
	// Remove too-small peaks
	if( peaksFound > 0 )
		peaksFound = TrimAmpAutoPeakInfo(W_AutoPeakInfo,minPeakPercent/100)
	endif
	
	// process peaks
	if( peaksFound > 0 )		
		// Redimension to number of peaks
		Redimension/N=(peaksFound, -1) wavOutput
		
		// save peak positions in input wave
		wavOutput[][%positionX] = W_AutoPeakInfo[p][0]
		wavOutput[][%positionY] = wavInput[wavOutput[p][%positionX]]
	
		// The x values in W_AutoPeakInfo are still actually points, not X
		AdjustAutoPeakInfoForX(W_AutoPeakInfo, wavInput, wavXdata)		
		wavOutput[][%wavelength] 	= W_AutoPeakInfo[p][0]	
		
		// save all data from WM procedure	
		wavOutput[][%width] 	= W_AutoPeakInfo[p][1]
		wavOutput[][%height] 	= W_AutoPeakInfo[p][2]
		wavOutput[][%widthL] 	= W_AutoPeakInfo[p][3]
		wavOutput[][%widthR] 	= W_AutoPeakInfo[p][4]
	endif
		
	if (sorted) // sort is not multidemnsional aware
		Make/FREE/N=(Dimsize(wavOutput, 0)) zero = wavOutput[p][0]
		Make/FREE/N=(Dimsize(wavOutput, 0)) one = wavOutput[p][1]
		Make/FREE/N=(Dimsize(wavOutput, 0)) two = wavOutput[p][2]
		Make/FREE/N=(Dimsize(wavOutput, 0)) three = wavOutput[p][3]
		Make/FREE/N=(Dimsize(wavOutput, 0)) four = wavOutput[p][4]
		Make/FREE/N=(Dimsize(wavOutput, 0)) five = wavOutput[p][5]
		Make/FREE/N=(Dimsize(wavOutput, 0)) six = wavOutput[p][6]
		
		Sort zero, zero, one, two, three, four, five, six
		wavOutput[][0] = zero[p]
		wavOutput[][1] = one[p]
		wavOutput[][2] = two[p]
		wavOutput[][3] = three[p]
		wavOutput[][4] = four[p]
		wavOutput[][5] = five[p]
		wavOutput[][6] = six[p]
	endif
	
	if (redimensioned)
		Redimension/N=(-1,4) wavOutput
	endif
	
	return wavOutput
End

Function/Wave AbsorptionBackgroundConstruct(wavInput, [debugging, doubleExp])
	Wave wavInput
	Variable debugging, doubleExp
	if (ParamIsDefault(debugging))
		debugging = 0
	endif
	if (ParamIsDefault(doubleExp))
		doubleExp = 1
	endif
	
	Variable i, j, startx, endx
	Variable numMaxima, numMinima
	
	String newName
	DFREF dfr = GetWavesDataFolderDFR(wavInput)
	Wave wavOutput, wavDifferentiation, wavSmooth
	
	newName = NameOfWave(wavInput) + "_bg"
	Duplicate/O wavInput, dfr:$newName
	Wave wavOutput = dfr:$newName
	
	wave/wave minima = AbsorptionDeleteDoubleMinima(wavInput, debugging = debugging)
	wave/wave smoothed = AbsorptionDeleteSmooth(minima, smoothing = 3, logarithmic = 1, debugging = debugging)

	wave fit_coeff = AbsorptionBackgroundFit(smoothed, expDouble=doubleExp)
	if (!doubleExp)
		wavOutput = AbsorptionBackgroundExp(fit_coeff, x)
		print fit_coeff
		print "y = K0+K1*exp(-(x-K5)/K2)"
	else
		wavOutput = AbsorptionBackgroundExpDouble(fit_coeff, x)
		print fit_coeff
		print "y = K0+K1*exp(-(x-K5)/K2)+K3*exp(-(x-K5)/K4)"
	endif

	return wavOutput
End

Function/Wave AbsorptionBackgroundRemove(wavInput, [doubleExp])
	Wave wavInput
	Variable doubleExp
	if (ParamIsDefault(doubleExp))
		doubleExp = 1
	endif
	
	Variable i, j, startx, endx
	Variable numMaxima, numMinima
	
	String newName
	DFREF dfr = GetWavesDataFolderDFR(wavInput)
	Wave wavOutput, wavDifferentiation, wavSmooth
	
	newName = NameOfWave(wavInput) + "_bgcorr"
	Duplicate/O wavInput, dfr:$newName
	Wave wavOutput = dfr:$newName
		
	wave wavBackground = AbsorptionBackgroundConstruct(wavInput)
	
	wavOutput = wavInput - wavBackground
	return wavOutput
End

// function is used to search for points in "minima" between two points from "maxima" wave
// returns p-index and positions in "minima" wave
// as input the x values are used
Function/Wave AbsorptionDoubleMinima(maxima, minima)
	Wave maxima, minima
	
	Variable startx, endx
	variable i,j
	Variable numMaxima, numMinima
	
	numMaxima = Dimsize(maxima, 0)
	numMinima = Dimsize(minima, 0)
	
	// search for number of minima between two points.
	// plot numMinima[][%delta] vs freeMaximaX for bugtracking
	Make/FREE/I/N=(numMaxima, 3) output
	// label columns of wave for readability
	SetDimLabel 1, 0, startX, output
	SetDimLabel 1, 1, endX, output
	SetDimLabel 1, 2, delta, output

	startx = 0
	endx = 0
	for(i = 0; i < (numMaxima - 1); i += 1)
		// searching "minima" between following maxima:
		// freeMaximaX[i], freeMaximaX[i+1]
		
		startx = endx
		for (j = startx; j < numMinima; j += 1)
			if (minima[j] > maxima[i])
				break
			endif
		endfor
		startx = j
		
		for (j = startx; j < numMinima; j += 1)
			if (minima[j] > maxima[i+1])
				break
			endif
		endfor
		endx = j
		
		output[i][%startX] = startx
		output[i][%endX] = endx
		output[i][%delta] = endx - startx
	endfor
	
	return output
End


Function/Wave AbsorptionGetMinima(wavInput, [addBorders])
	wave wavInput
	Variable addBorders
	
	if (ParamIsDefault(addBorders))
		addBorders = 0
	endif	
	
	Variable numMinima
	
	wave wavDifferentiation = AbsorptionDifferentiate2Wave(wavInput, 10)
	wave wavMinima = AbsorptionPeakFind(wavDifferentiation)
	
	numMinima = Dimsize(wavMinima, 0)
	if (addBorders)
		numMinima += 2
		Wavestats/Q wavInput
		Make/FREE/N=(numMinima) freeMinimaX = wavMinima[((p-2) < 0 ? 0 : (p-2))][%wavelength]
		freeMinimaX[0,1] = {V_minloc, V_maxloc}
		Make/FREE/N=(numMinima) freeMinimaY = wavInput[wavMinima[((p-2) < 0 ? 0 : (p-2))][%positionX]]		
		freeMinimaY[0,1] = {V_min, V_max}	
	else
		Make/FREE/N=(numMinima) freeMinimaX = wavMinima[p][%wavelength]
		Make/FREE/N=(numMinima) freeMinimaY = wavInput[wavMinima[p][%positionX]]
	endif
	Sort freeMinimaX, freeMinimaX, freeMinimaY	

	Make/Wave/FREE/N=2 output
	output[0] = freeMinimaX
	output[1] = freeMinimaY

	return output
End

Function/Wave AbsorptionGetMaxima(wavInput)
	wave wavInput

	Variable numMaxima
	
	wave wavMaxima = AbsorptionPeakFind(wavInput)
	
	numMaxima = Dimsize(wavMaxima, 0)
	Make/FREE/N=(numMaxima) freeMaximaX = wavMaxima[p][%wavelength]
	Make/FREE/N=(numMaxima) freeMaximaY = wavInput[wavMaxima[p][%positionX]]
	Sort freeMaximaX, freeMaximaX, freeMaximaY

	Make/Wave/FREE/N=2 output
	output[0] = freeMaximaX
	output[1] = freeMaximaY

	return output
End

// Delete minimum if two or more minima exist between one maximum in a wave
Function/Wave AbsorptionDeleteDoubleMinima(wavInput, [minima, maxima, debugging])
	wave wavInput
	wave/wave minima, maxima
	Variable debugging
	if (ParamIsDefault(debugging))
		debugging = 0
	endif
	if (ParamIsDefault(minima))
		wave/wave minima = AbsorptionGetMinima(wavInput, addBorders = 1)
	endif
	if (ParamIsDefault(maxima))
		wave/wave maxima = AbsorptionGetMaxima(wavInput)
	endif
	
	Variable numMinima, numMaxima, i
	
	Wave minimaX = minima[0]
	wave minimaY = minima[1]
	wave maximaX = maxima[0]
	Wave maximaY = maxima[1]
	Wave minimaPositions = AbsorptionDoubleMinima(maximaX, minimaX)
	
	// create BoxWave with number of minima
	if (debugging)
		Make/O/I/N=(Dimsize(minimaPositions, 0), 2) root:absDoubleMinima
		WAVE/I absDoubleMinima
		absDoubleMinima[][0] = maximaX[p]
		absDoubleMinima[][1] = minimaPositions[p][%delta]
	endif
	
	// Create Minima Wave
	if (debugging)
		Make/O/N=(Dimsize(minimaPositions, 0), 2) root:absMinimaInitial
		WAVE absMinimaInitial
		absMinimaInitial[][0] = minimaX[p]
		absMinimaInitial[][1] = minimaY[p]
	endif


	numMinima = Dimsize(minimaX, 0)
	numMaxima = Dimsize(maxima[0], 0)

	// process points to yield only one point (the local minimum) between two maxima
	Make/FREE/N=(numMinima) minimaXout = minimaX
	Make/FREE/N=(numMinima) minimaYout = minimaY
	for(i = numMaxima - 2; i > -1; i -= 1) // backwards due to DeletePoints
		if (minimaPositions[i][%delta] > 1)
			// get minimum
			Wavestats/Q/R=(minimaX[minimaPositions[i][%startX]], minimaX[minimaPositions[i][%endX]]) wavInput
			// set minimum
			minimaXout[minimaPositions[i][%startX]] = V_minloc
			minimaYout[minimaPositions[i][%startX]] = V_min
			// delete remaining points
			DeletePoints (minimaPositions[i][%startX] + 1), (minimaPositions[i][%endX] - minimaPositions[i][%startX] - 1), minimaYout, minimaXout
		endif
	endfor
	
	// Create Minima Wave
	if (debugging)
		Make/O/N=(Dimsize(minimaPositions, 0), 2) root:absMinimaDouble
		WAVE absMinimaDouble
		absMinimaDouble[][0] = minimaXout[p]
		absMinimaDouble[][1] = minimaYout[p]
	endif
	
	Make/Wave/FREE/N=2 output
	output[0] = minimaXout
	output[1] = minimaYout

	return output
End

// delete points that are not smooth enough
Function/wave AbsorptionDeleteSmooth(minima, [smoothing, logarithmic, interpolate, debugging])
	wave/wave minima
	Variable smoothing, logarithmic, interpolate, debugging
	
	if (ParamIsDefault(debugging))
		debugging = 0
	endif
	if (ParamIsDefault(smoothing))
		smoothing = 0
	endif
	if (ParamIsDefault(logarithmic))
		logarithmic = 0
	endif
	if (ParamIsDefault(interpolate))
		interpolate = 0
	endif
	
	Variable numMinima
	
	wave minimaX = minima[0]
	wave minimaY = minima[1]

	numMinima = Dimsize(minimaY, 0)

	Make/FREE/N=(numMinima) afterSmoothY	= minimaY
	Make/FREE/N=(numMinima) smoothed			= minimaY
	Make/FREE/N=(numMinima) valid = 1
	
	if (logarithmic)
		smoothed = ln(smoothed)
	endif
	
	switch(smoothing)
		case 0:
			// normal boxcar smoothing
			Smooth/E=3 1, smoothed
			break
		case 1:
			// Savitzky-Golay smoothing
			Smooth/E=3/S=4 9, smoothed
			break
		case 2:
			Smooth/E=3 1, smoothed
			break
		case 3:
			Loess/Z/SMTH=0.75 srcWave=smoothed
			if (!V_flag)
				Smooth/E=3 1, smoothed
			endif
			break
	endswitch
	
	if (logarithmic)
		smoothed = exp(smoothed)
	endif
	
	if (interpolate)
		interpolate2/T=1/I=3/Y=smoothed minimaX, minimaY
	endif
	
	// check if value changed too much and drop particulary those values
	afterSmoothY = minimaY - smoothed
	Wavestats/Q afterSmoothY
	valid = afterSmoothY[p] > V_rms  ? NaN : 1 // delete only positive deviation (peaks)
	afterSmoothY = minimaY * valid
	
	Make/Wave/FREE/N=2 output
	output[0] = minimaX
	output[1] = afterSmoothY

	if (debugging)
		Make/O/N=(numMinima, 2) root:absSmooth
		Wave absSmooth = root:absSmooth
		absSmooth[][0] = minimaX[p]
		absSmooth[][1] = smoothed[p]

		Make/O/N=(numMinima, 2) root:absSmoothValid
		Wave absSmoothValid = root:absSmoothValid
		absSmoothValid[][0] = minimaX[p]
		absSmoothValid[][1] = valid[p]
	endif

	return output
End

Function/wave AbsorptionBackgroundFit(wavInput, [expDouble])
	wave/wave wavInput
	Variable expDouble
	if (ParamIsDefault(expDouble))
		expDouble = 0
	endif
	
	wave smoothedX = wavInput[0]
	wave smoothedY = wavInput[1]

	// no need to guess parameters with curvefit
	if (!expDouble)
		// exponential fit with curve fit.
		CurveFit/Q/X=1/NTHR=0 exp_XOffset smoothedY /X=smoothedX /F={0.95, 4}
		Wave W_coef
		Wave W_fitConstants
		
		// store results for custom function
		Make/FREE/N=4 coeff
		coeff[0,2] = W_coef
		coeff[3] = W_fitConstants[0]
		
		// fit again to custom function
		Wavestats/Q smoothedY
		// initial guesses
		// Make/FREE/N=4 coeff = {V_min, V_max-V_min, smoothedX[V_maxloc], 3/abs(smoothedX[V_minloc] - smoothedX[V_maxloc])}
		Make/FREE/T/N=1 T_Constraints  = {"K0 < " + num2str(V_min)}
		FuncFit/Q/X=1/NTHR=0 AbsorptionBackgroundExp coeff smoothedY /X=smoothedX /F={0.95, 4} /C=T_Constraints
		// y = K0+K1*exp(-(x-K5)/K2).
	else
		// double exponential fit with curve fit. 
		CurveFit/Q/X=1/NTHR=0 dblexp_XOffset smoothedY /X=smoothedX /F={0.95, 4}
		Wave W_coef
		Wave W_fitConstants
		
		// store results for custom function
		Make/FREE/N=6 coeff
		coeff[0,4] = W_coef
		coeff[5] = W_fitConstants[0]
		
		// fit again to custom function
		Wavestats/Q smoothedY
		Make/FREE/T/N=3 T_Constraints  = {"K0 < " + num2str(V_min), "K2 < K4", "K3 < K1"}
		FuncFit/Q/X=1/NTHR=0 AbsorptionBackgroundExpDouble coeff smoothedY /X=smoothedX /F={0.95, 4} /C=T_Constraints
		// y = K0+K1*exp(-(x-K5)/K2)+K3*exp(-(x-x0)/K4).
	endif
	
	return coeff
End

Function AbsorptionBackgroundExp(w,x) : FitFunc
	Wave w
	Variable x
	
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = a + b*exp(-1/c*(x-d))
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 4
	//CurveFitDialog/ w[0] = a
	//CurveFitDialog/ w[1] = b
	//CurveFitDialog/ w[2] = c
	//CurveFitDialog/ w[3] = d

	
	return w[0] + w[1]*exp(-(x-w[3])/w[2])
End

Function AbsorptionBackgroundExpDouble(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = a + b*exp(-1/c*(x-f)) + d*exp(-1/e*(x-f))
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 7
	//CurveFitDialog/ w[0] = a
	//CurveFitDialog/ w[1] = b
	//CurveFitDialog/ w[2] = c
	//CurveFitDialog/ w[3] = d
	//CurveFitDialog/ w[4] = e
	//CurveFitDialog/ w[5] = f 
	
	return w[0]+w[1]*exp(-(x-w[5])/w[2])+w[3]*exp(-(x-w[5])/w[4])
End