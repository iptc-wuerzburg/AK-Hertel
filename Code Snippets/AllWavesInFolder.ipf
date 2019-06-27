#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


//Code snippet to show how to operate on all waves in the current datafolder
Function Snippet_AllWavesInFolder()
	Variable i, var_numitems
	String str_wavelist, str_wavename
	
	//Generates a list string of waves: "wave0;wave1;wave2;..."; then sorts it alphabetically;
	//then counts the number of items
	str_wavelist = WaveList("*",";","")	
	str_wavelist = SortList(str_wavelist) 
	var_numitems = ItemsInlist(str_wavelist)
	
	for(i=0;i<var_numitems;i+=1)
		str_wavename = StringFromList(i,str_wavelist)
		WAVE wave_to_change = $str_wavename	
		//insert your function you want to apply one the spectrum here
		//for example: MyFunction(wave_to_change)	
		CreateBackup(wave_to_change)
		//you may want to rename your now changed wave, for example:
		//rename wave_to_change $(nameofwave(s.spectrum) +"_changed")
	endfor		
End

//A Static Function is only used in this procedure File. It cannot be called from the outside
Static Function CreateBackup(wave_to_backup)
	WAVE wave_to_backup
	
	NewDataFolder/O :originaldata
	Duplicate wave_to_backup, :originaldata:$nameofwave(wave_to_backup)
	Return 0
End



