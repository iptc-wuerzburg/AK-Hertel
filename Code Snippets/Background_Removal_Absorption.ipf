#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Function from the Igor Introduction talk
Function SubtractWaves(wave_background)
	WAVE wave_background
	WAVE wave_spectrum
	String str_wavelist, str_wavename
	Variable var_numitems, i
	
	//Generates a string that lists all Waves in the current datafolder; then removes the background wave
	str_wavelist = WaveList("*ABS*",";","")
	str_wavelist = RemoveFromList(NameOfWave(wave_background),str_wavelist,";")
	var_numitems = ItemsinList(str_wavelist, ";")

	//Loops through the list and creates a backup; annotates the wave and subtracts the background
	for(i=0;i<var_numitems;i+=1)	
		str_wavename = StringFromList(i,str_wavelist)
		WAVE wave_spectrum = $str_wavename
		CreateBackup(wave_spectrum)
		Rename wave_spectrum, $(str_wavename + "_r")
		Note wave_spectrum, "Background spectrum '" + NameOfWave(wave_background) + "' was substracted from this wave"
		wave_spectrum-=wave_background			
	endfor						

End

//Function to make a backup in a seperate folder
Function CreateBackup(wave_to_backup)
	WAVE wave_to_backup
	NewDataFolder/O :backupdata
	duplicate/O wave_to_backup,:backupdata:$NameOfWave(wave_to_backup)	
End