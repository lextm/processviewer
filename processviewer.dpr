program processviewer;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  uDGProcessList in 'uDGProcessList.pas';

var
  Index: Integer;
  ProcessList: TDGProcessList;
begin
  { TODO -oUser -cConsole Main : Insert code here }
  //http://www.delphigeist.com/2010/03/process-list.html
  if ParamCount <> 1 then
  begin
    ExitCode := 0;
    Exit;
  end;

  ProcessList := TDGProcessList.Create;
  ProcessList.Refresh;
  ProcessList.Exists(ParamStr(1), Index);
  if (Index > 0) and (Index < ProcessList.Count) then
  begin
    ExitCode := 1;
    WriteLn('found');
  end
  else
  begin
    ExitCode := 0;
    WriteLn('not found');
  end;

  FreeAndNil(ProcessList);
  Exit;
end.
