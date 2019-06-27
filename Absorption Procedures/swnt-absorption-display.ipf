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

Menu "AKH"	
	Submenu "Absorption"
		"Main Panel", CreateAbsorptionToolPanel()	
		"-"
		"Load File", AbsorptionLoadFile()
		"Load Directory", AbsorptionLoadDirectory()
		"Differentiate", AbsorptionDifferentiateDisplay()
		"Differentiate2", AbsorptionDifferentiate2Display(0)
		"Differentiate2 offset", AbsorptionDifferentiate2Display(1)
		"Show Peaks", AbsorptionPeakDisplay()
		"Show Background 2exp", AbsorptionBackgroundDisplay()
		"Show Background exp", AbsorptionBackgroundDisplay(doubleExp = 0)
		"Remove Background 2exp", AbsorptionBackgroundDisplay(bgcorr = 1)
		"Remove Background exp", AbsorptionBackgroundDisplay(bgcorr = 1, doubleExp = 0)
		"Remove Jump at 800nm", AbsorptionRemoveJumpDisplay()
		"Linear Background on cursor", AbsorptionBgLinear()
		"-"
		"SetWaveScale", SetWaveScale()
		"DisplayWave", DisplayWave()
		"-"
	end
End

Function AbsorptionDifferentiateDisplay()
	AppendToGraph/R=derivative AbsorptionDifferentiateWave(AbsorptionPrompt(), 0, 0)
End

Function AbsorptionDifferentiate2Display(setMinimum)
	Variable setMinimum
	wave output = AbsorptionDifferentiate2Wave(AbsorptionPrompt(), 10)
	if (setMinimum)
		Wavestats/Q output
		output-=V_max
	endif

	//	See CheckDisplayed instead of AbsorptionIsWaveInGraph
	if (AbsorptionIsWaveInGraph(output) == 0)

		AppendToGraph/R=axisderivative2 output/TN=derivative2
		
		SetAxis/A axisderivative2
		ModifyGraph freePos(axisderivative2)=0		
		ModifyGraph axisEnab(axisderivative2)={0.5,1}
		Label axisderivative2 "2nd derivative"
		
		ModifyGraph mode(derivative2)=7
		ModifyGraph usePlusRGB(derivative2)=0,useNegRGB(derivative2)=1
#if IgorVersion() >= 7	
		ModifyGraph negRGB(derivative2)=(65535,54607,32768)
		ModifyGraph plusRGB(derivative2)=(65535,0,0,32768)
#else
		ModifyGraph negRGB(derivative2)=(65535,54607,32768)
		ModifyGraph plusRGB(derivative2)=(65535,0,0)
#endif
		ModifyGraph hbFill=0, hBarNegFill(derivative2)=2
		ModifyGraph useNegPat(derivative2)=1		
		ModifyGraph rgb(derivative2)=(0,0,0)

		ModifyGraph grid(axisderivative2)=1,lblPosMode(axisderivative2)=1
		ModifyGraph nticks(axisderivative2)=10
	endif
End

Function AbsorptionRemoveJumpDisplay()
	Wave wavInput = AbsorptionPrompt()
	Wave wavOutput = AbsorptionRemoveJump(wavInput)
	AppendToGraph wavOutput
end

// see AutoFindPeaksWorker from WM's <Peak AutoFind>
Function AbsorptionPeakDisplay()
	Wave wavInput, wavOutput
	
	String tablename, tracename
	
	Wave wavInput = AbsorptionPrompt()
	Wave wavOutput = AbsorptionPeakFind(wavInput, sorted = 1, redimensioned = 1)

	//remove peaks from graph
	CheckDisplayed wavInput
	if( V_Flag == 1 )
		tracename = "peaks_" + NameOfWave(wavInput)
		CheckDisplayed wavOutput
		if( V_Flag == 1 )
			RemoveFromGraph/Z $tracename
		endif
		AppendToGraph wavOutput[][%positionY]/TN=$tracename vs wavOutput[][%wavelength]
		ModifyGraph rgb($tracename)=(0,0,65535)
		ModifyGraph mode($tracename)=3
		ModifyGraph marker($tracename)=19
	endif
	
	// show table for peak wave if not yet present
	tablename = "table_" + NameOfWave(wavOutput)
	DoWindow $tablename
	if (V_flag)
		DoWindow/F $tablename
		CheckDisplayed/W=$tablename wavOutput
		if(!V_Flag)
			AppendToTable wavOutput.ld // .ld: table with column names
		endif
	else
		Edit/N=$tablename wavOutput.ld as "Peaks for " + NameOfWave(wavInput) 
	endif
End

Function AbsorptionBackgroundDisplay([bgcorr, debugging, doubleExp])
	Variable bgcorr, debugging, doubleExp
	String trace_bgcorr, trace_bg
	if (ParamIsDefault(bgcorr))
		bgcorr = 0
	endif
	if (ParamIsDefault(debugging))
		debugging = 0
	endif
	if (ParamIsDefault(doubleExp))
		doubleExp = 1
	endif
	
	Wave wavInput = AbsorptionPrompt()
	if (bgcorr)
		Wave wavOutput = AbsorptionBackgroundRemove(wavInput, doubleExp = doubleExp)
	else
		Wave wavOutput = AbsorptionBackgroundConstruct(wavInput, debugging = debugging, doubleExp = doubleExp)
	endif
	
	trace_bgcorr = "corrected_" + NameOfWave(wavInput)
	trace_bg = "background_" + NameOfWave(wavInput)
	//trace_peak = "peaks_" + NameOfWave(wavInput)
	
	CheckDisplayed wavInput
	if(V_Flag) // we are in top graph
		CheckDisplayed wavOutput
		if(!V_Flag)// trace not yet present.
			if (bgcorr)
				RemoveFromGraph/Z $trace_bg
				AppendToGraph wavOutput/TN=$trace_bgcorr
				ModifyGraph zero(left)=1
			else
				RemoveFromGraph/Z $trace_bgcorr
				AppendToGraph wavOutput/TN=$trace_bg
				ModifyGraph mode($trace_bg)=7,usePlusRGB($trace_bg)=1
				ModifyGraph plusRGB($trace_bg)=(65535,0,0,16384)
				ModifyGraph hbFill($trace_bg)=2
				ModifyGraph zero(left)=0
			endif
		endif
		if (debugging)

		endif
	endif
End