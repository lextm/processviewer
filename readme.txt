Readme

This utility is a 32 bit command line tool that queries running processes.

Usage:
The following command line checks if bds.exe is running.

	processviewer.exe bds.exe

If bds.exe is running, processviewer.exe exits with 1, and prints out "found". Otherwise, it exits with 0, and prints out "not found".

So in your Inno Setup script, you can include processviewer.exe in [Files] sections like below,

	[Files]
	; exe used to check running notepad at install time
	Source: "processviewer.exe"; Flags: dontcopy
	
	; exe is installed in {app} folder, so it will be
	; loaded at uninstall time ;to check if notepad is running
	Source: "processviewer.exe"; DestDir: "{app}"

Then in [Code] section you can write the follow snippet to check if the expected process (such as notepad.exe) is running,

	function ProductRunning(): Boolean;
	var
	  ResultCode: Integer;
	begin  
	  ExtractTemporaryFile('processviewer.exe');
	  if Exec(ExpandConstant('{tmp}\processviewer.exe'), 'notepad.exe', '', SW_HIDE,
	     ewWaitUntilTerminated, ResultCode) then
	  begin
	    Result := ResultCode > 0;
	    Exit;    
	  end;  
	  
	  MsgBox('failed to check process', mbError, MB_OK);
	end;
	
	function ProductRunningU(): Boolean;
	var
	  ResultCode: Integer;
	begin  
	  if Exec(ExpandConstant('{app}\processviewer.exe'), 'notepad.exe', '', SW_HIDE,
	     ewWaitUntilTerminated, ResultCode) then
	  begin
	    Result := ResultCode > 0;
	    Exit;    
	  end;  
	  
	  MsgBox('failed to check process.', mbError, MB_OK);
	end;

