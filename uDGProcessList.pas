{******************************************************************************}
{                                                                              }
{   Unit: uDGProcessList.pas                                                   }
{                                                                              }
{   Scope: Process manipulation                                                }
{                                                                              }
{   Info: it can get a list of all running processes, terminate them, etc.     }
{                                                                              }
{   Copyright© Dorin Duminica                                                  }
{                                                                              }
{******************************************************************************}
unit uDGProcessList;

interface

uses
  SysUtils,
  Windows,
  Classes,
  Graphics,
  TlHelp32,
  ShellApi,
  PsApi;

type
  // type used to store information about a process
  PDGProcessRec = ^TDGProcessRec;
  TDGProcessRec = record
    Name: AnsiString;
    ExeName: AnsiString;
    UserName: AnsiString;
    Domain: AnsiString;
    StartDateTime: TDateTime;
    MemoryUsage: DWORD;
    Usage: DWORD;
    ProcessID: DWORD;       // this process
    DefaultHeapID: DWORD;
    ModuleID: DWORD;        // associated exe
    ThreadCount: DWORD;
    ParentProcessID: DWORD; // this process's parent process
    PriClassBase: Longint;    // Base priority of process's threads
  end;// TDGProcessRec = record

type
  // type used to get user name and domain
  PTOKEN_USER = ^TOKEN_USER;
  _TOKEN_USER = record
    User: TSidAndAttributes;
  end;
  TOKEN_USER = _TOKEN_USER;

type
  TUnitType = (utByte, utKiloByte, utMegaByte, utGigaByte);

type
  TDGProcessList = class
  PRIVATE// variables and methods
    FList: TList;
    function GetProcessRec(INDEX: Integer): TDGProcessRec;
    function GetProcessFileName(dwProcessID: DWORD): AnsiString;
    function GetProcessUserAndDomain(dwProcessID: DWORD;
      var UserName, Domain: AnsiString): Boolean;
    function GetProcessStartDateTime(dwProcessID: DWORD): TDateTime;
    procedure SetProcessRec(INDEX: Integer; const Value: TDGProcessRec);
  PUBLIC// methods
    function Count: Integer;
    function TerminateProcess(dwProcessID: DWORD): Boolean; OVERLOAD;
    function TerminateProcess(const Name: AnsiString): Boolean; OVERLOAD;
    function Exists(dwProcessID: DWORD): Boolean; OVERLOAD;
    function Exists(dwProcessID: DWORD; var atIndex: Integer): Boolean; OVERLOAD;
    function Exists(const Name: AnsiString): Boolean; OVERLOAD;
    function Exists(const Name: AnsiString; var atIndex: Integer): Boolean; OVERLOAD;
    function ProcessInfoToStr(Index: Integer): AnsiString;
    function GetProcessIcon(Index: Integer;
      const bSmallIcon: Boolean = True): TIcon; OVERLOAD;
    function GetProcessIcon(const ExeName: AnsiString;
      const bSmallIcon: Boolean = True): TIcon; OVERLOAD;
    function GetProcessMemoryUsage(dwProcessID: DWORD;
      const UnitType: TUnitType = utByte): DWORD;
    procedure Clear;
    procedure Delete(Index: Integer);
    procedure Refresh;
  PUBLIC// properties
    property Process[INDEX: Integer]: TDGProcessRec
      read GetProcessRec write SetProcessRec; DEFAULT;
  PUBLIC// constructor and destructor
    constructor Create;
    destructor Destroy; override;
  end;// TDGProcessList = class

implementation

{ TDGProcessList }

procedure TDGProcessList.Clear;
var
  Index: Integer;
begin
  for Index := FList.Count -1 downto 0 do
    Delete(Index);
end;// procedure TDGProcessList.Clear;

function TDGProcessList.Count: Integer;
begin
  Result := FList.Count;
end;// function TDGProcessList.Count: Integer;

constructor TDGProcessList.Create;
begin
  FList := TList.Create;
end;// constructor TDGProcessList.Create;

procedure TDGProcessList.Delete(Index: Integer);
var
  ProcessRec: PDGProcessRec;
begin
  ProcessRec := FList[Index];
  Dispose(ProcessRec);
  FList.Delete(Index);
end;// procedure TDGProcessList.Delete(Index: Integer);

destructor TDGProcessList.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited;
end;// destructor TDGProcessList.Destroy;

function TDGProcessList.Exists(dwProcessID: DWORD): Boolean;
var
  Index: Integer;
begin
  Result := Exists(dwProcessID, Index);
end;// function TDGProcessList.Exists(dwProcessID: DWORD): Boolean;

function TDGProcessList.Exists(dwProcessID: DWORD;
  var atIndex: Integer): Boolean;
var
  Index: Integer;
begin
  Result := True;
  for Index := 0 to FList.Count -1 do
    if Process[Index].ProcessID = dwProcessID then begin
      atIndex := Index;
      Exit;
    end;// if Process[Index].th32ProcessID = dwProcessID then begin
  Result := False;
end;// function TDGProcessList.Exists(dwProcessID: DWORD;

function TDGProcessList.Exists(const Name: AnsiString): Boolean;
var
  Index: Integer;
begin
  Result := Exists(Name, Index);
end;// function TDGProcessList.Exists(const Name: AnsiString): Boolean;

function TDGProcessList.Exists(const Name: AnsiString;
  var atIndex: Integer): Boolean;
var
  Index: Integer;
begin
  Result := True;
  for Index := 0 to FList.Count -1 do
    if SameText(Process[Index].Name, Name) then begin
      atIndex := Index;
      Exit;
    end;// if SameText(Process[Index].Name, Name) then begin
  Result := False;
end;// function TDGProcessList.Exists(const Name: AnsiString;

function TDGProcessList.GetProcessFileName(dwProcessID: DWORD): AnsiString;
var
  Handle: THandle;
begin
  Result := EmptyStr;
  Handle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False,
    dwProcessID);
  try
    SetLength(Result, MAX_PATH);
    if Handle <> 0 then begin
      if GetModuleFileNameEx(Handle, 0, PAnsiChar(Result), MAX_PATH) > 0 then
        SetLength(Result, StrLen(PAnsiChar(Result)))
      else
        Result := EmptyStr;
    end else begin// if Handle <> 0 then begin
      if GetModuleBaseNameA(Handle, 0, PAnsiChar(Result), MAX_PATH) > 0 then
        SetLength(Result, StrLen(PAnsiChar(Result)))
      else
        Result := EmptyStr;
    end;// if Handle <> 0 then begin
  finally
    CloseHandle(Handle);
  end;// try
end;// function TDGProcessList.GetProcessFileName(dwProcessID: DWORD): AnsiString;

function TDGProcessList.GetProcessIcon(Index: Integer;
  const bSmallIcon: Boolean = True): TIcon;
begin
  Result := GetProcessIcon(Process[Index].ExeName);
end;// function TDGProcessList.GetProcessIcon(Index: Integer;

function TDGProcessList.GetProcessIcon(const ExeName: AnsiString;
  const bSmallIcon: Boolean = True): TIcon;
var
  FileInfo: _SHFILEINFOA;
  Flags: DWORD;
begin
  if bSmallIcon then
    Flags := SHGFI_ICON or SHGFI_SMALLICON or SHGFI_SYSICONINDEX
  else
    Flags := SHGFI_ICON or SHGFI_LARGEICON or SHGFI_SYSICONINDEX;
  Result := TIcon.Create;
  SHGetFileInfo(PAnsiChar(ExeName), 0, FileInfo, SizeOf(FileInfo), Flags);
  Result.Handle := FileInfo.hIcon;
end;// function TDGProcessList.GetProcessIcon(const ExeName: AnsiString;

function TDGProcessList.GetProcessMemoryUsage(dwProcessID: DWORD;
  const UnitType: TUnitType = utByte): DWORD;
const
  CFACTOR_BYTE = 1;
  CFACTOR_KILOBYTE = CFACTOR_BYTE * 1024;
  CFACTOR_MEGABYTE = CFACTOR_KILOBYTE * 1024;
  CFACTOR_GIGABYTE = CFACTOR_MEGABYTE * 1024;
var
  MemCounters: TProcessMemoryCounters;
  hProcess: THandle;
begin
  Result := 0;
  MemCounters.cb := SizeOf(TProcessMemoryCounters);
  hProcess := OpenProcess(PROCESS_ALL_ACCESS, False, dwProcessID);
  if hProcess <> 0 then begin
    if GetProcessMemoryInfo(hProcess, @MemCounters, SizeOf(MemCounters)) then
      case UnitType of
        utByte:
          Result := MemCounters.WorkingSetSize div CFACTOR_BYTE;
        utKiloByte:
          Result := MemCounters.WorkingSetSize div CFACTOR_KILOBYTE;
        utMegaByte:
          Result := MemCounters.WorkingSetSize div CFACTOR_MEGABYTE;
        utGigaByte:
          Result := MemCounters.WorkingSetSize div CFACTOR_GIGABYTE;
      end// case UnitType of
    else
      RaiseLastOSError;
    CloseHandle(hProcess)
  end;// if hProcess <> 0 then begin
end;// function TDGProcessList.GetProcessMemoryUsage(dwProcessID: DWORD;

function TDGProcessList.GetProcessRec(INDEX: Integer): TDGProcessRec;
begin
  if (INDEX <= -1) or (INDEX >= FList.Count) then
    raise Exception.Create('Index out of bounds');
  Result := PDGProcessRec(FList[INDEX])^;
end;// function TDGProcessList.GetProcessRec(INDEX: Integer): TDGProcessRec;

function TDGProcessList.GetProcessStartDateTime(
  dwProcessID: DWORD): TDateTime;

  function FileTimeToDateTime(ft: TFileTime): TDateTime;
  var
    ft1: TFileTime;
    st: TSystemTime;
  begin
    if ft.dwLowDateTime + ft.dwHighDateTime = 0 then
      Result := 0
    else
    begin
      FileTimeToLocalFileTime(ft, ft1);
      FileTimeToSystemTime(ft1, st);
      Result := SystemTimeToDateTime(st);
    end;
  end;
var
  ftCreationTime, lpExitTime, ftKernelTime, ftUserTime: TFileTime;
  hProcess: THandle;
begin
  Result := 0;
  hProcess := OpenProcess(PROCESS_ALL_ACCESS, False, dwProcessID);
  if hProcess <> 0 then begin
    if GetProcessTimes(hProcess, ftCreationTime, lpExitTime,
        ftKernelTime, ftUserTime) then
      Result := FileTimeToDateTime(ftCreationTime)
    else
      RaiseLastOSError;
    CloseHandle(hProcess);
  end;// if hProcess <> 0 then begin
end;// function TDGProcessList.GetProcessStartDateTime(

function TDGProcessList.GetProcessUserAndDomain(dwProcessID: DWORD;
  var UserName, Domain: AnsiString): Boolean;
var
  hToken: THandle;
  cbBuf: Cardinal;
  tokUser: PTOKEN_USER;
  sidNameUse: SID_NAME_USE;
  hProcess: THandle;
  UserSize, DomainSize: DWORD;
  bSuccess: Boolean;
begin
  Result := False;
  hProcess := OpenProcess(PROCESS_QUERY_INFORMATION, False, dwProcessID);
  if hProcess <> 0 then begin
    if OpenProcessToken(hProcess, TOKEN_QUERY, hToken) then begin
      bSuccess := GetTokenInformation(hToken, TokenUser, nil, 0, cbBuf);
      tokUser := nil;
      while (not bSuccess) and
          (GetLastError = ERROR_INSUFFICIENT_BUFFER) do begin
        ReallocMem(tokUser, cbBuf);
        bSuccess := GetTokenInformation(hToken, TokenUser, tokUser, cbBuf, cbBuf);
      end;// while (not bSuccess) and...
      CloseHandle(hToken);
      if not bSuccess then
        Exit;
      UserSize := 0;
      DomainSize := 0;
      LookupAccountSid(nil, tokUser.User.Sid, nil, UserSize, nil, DomainSize, sidNameUse);
      if (UserSize <> 0) and (DomainSize <> 0) then begin
        SetLength(UserName, UserSize);
        SetLength(Domain, DomainSize);
        if LookupAccountSid(nil, tokUser.User.Sid, PAnsiChar(UserName), UserSize,
            PAnsiChar(Domain), DomainSize, sidNameUse) then begin
          Result := True;
          UserName := StrPas(PAnsiChar(UserName));
          Domain := StrPas(PAnsiChar(Domain));
        end;// if LookupAccountSid(nil, tokUser.User.Sid, PAnsiChar(UserName), UserSize,
      end;// if (UserSize <> 0) and (DomainSize <> 0) then begin
      if bSuccess then
        FreeMem(tokUser);
    end;// if OpenProcessToken(hProcess, TOKEN_QUERY, hToken) then begin
    CloseHandle(hProcess);
  end;// if hProcess <> 0 then begin
end;// function TDGProcessList.GetProcessUserAndDomain(dwProcessID: DWORD;

function TDGProcessList.ProcessInfoToStr(Index: Integer): AnsiString;
const
  CCRLF = #$D#$A;
  CPROCESSREC_FMT = CCRLF +
    'Name = %s' + CCRLF +
    'ExeName = %s' + CCRLF +
    'User name = %s' + CCRLF +
    'Domain = %s' + CCRLF +
    'Started = %s' + CCRLF +
    'Memory usage = %d bytes' + CCRLF +
    'Usage = %d' + CCRLF +
    'Process ID = %d' + CCRLF +
    'Default heap ID = %d' + CCRLF +
    'Module ID = %d' + CCRLF +
    'Threads = %d' + CCRLF +
    'Parent process ID = %d' + CCRLF +
    'Priority base class = %d' + CCRLF;
var
  ProcessRec: TDGProcessRec;
begin
  ProcessRec := Process[Index];
  Result := Format(CPROCESSREC_FMT, [
    ProcessRec.Name,
    ProcessRec.ExeName,
    ProcessRec.UserName,
    ProcessRec.Domain,
    DateTimeToStr(ProcessRec.StartDateTime),
    ProcessRec.MemoryUsage,
    ProcessRec.Usage,
    ProcessRec.ProcessID,
    ProcessRec.DefaultHeapID,
    ProcessRec.ModuleID,
    ProcessRec.ThreadCount,
    ProcessRec.ParentProcessID,
    ProcessRec.PriClassBase]);
end;// function TDGProcessList.ProcessInfoToStr(Index: Integer): AnsiString;

procedure TDGProcessList.Refresh;
var
  ProcessEntry32: TProcessEntry32;
  ProcessRec: PDGProcessRec;
  hSnapshot: THandle;
  UserName: AnsiString;
  Domain: AnsiString;
begin
  Clear;
  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  ProcessEntry32.dwSize := SizeOf(TProcessEntry32);
  if Process32First(hSnapshot, ProcessEntry32) then
    repeat
      New(ProcessRec);
      ProcessRec^.Name := StrPas(ProcessEntry32.szExeFile);
      ProcessRec^.ExeName := GetProcessFileName(ProcessEntry32.th32ProcessID);
      if GetProcessUserAndDomain(ProcessEntry32.th32ProcessID,
          UserName, Domain) then begin
        ProcessRec^.UserName := UserName;
        ProcessRec^.Domain := Domain;
      end;// if GetProcessUserAndDomain(ProcessEntry32.th32ProcessID,
      ProcessRec^.StartDateTime := GetProcessStartDateTime(
        ProcessEntry32.th32ProcessID);
      ProcessRec^.MemoryUsage := GetProcessMemoryUsage(
        ProcessEntry32.th32ProcessID);
      ProcessRec^.Usage := ProcessEntry32.cntUsage;
      ProcessRec^.ProcessID := ProcessEntry32.th32ProcessID;
      ProcessRec^.DefaultHeapID := ProcessEntry32.th32DefaultHeapID;
      ProcessRec^.ModuleID := ProcessEntry32.th32ModuleID;
      ProcessRec^.ThreadCount := ProcessEntry32.cntThreads;
      ProcessRec^.ParentProcessID := ProcessEntry32.th32ParentProcessID;
      ProcessRec^.PriClassBase := ProcessEntry32.pcPriClassBase;
      FList.Add(ProcessRec);
    until NOT Process32Next(hSnapshot, ProcessEntry32);
  if FList.Count > 0 then
    Delete(0);
  if hSnapshot <> 0 then
    CloseHandle(hSnapshot);
end;// procedure TDGProcessList.Refresh;

procedure TDGProcessList.SetProcessRec(INDEX: Integer;
  const Value: TDGProcessRec);
begin
  PDGProcessRec(FList[INDEX])^ := Value;
end;// procedure TDGProcessList.SetProcessRec(INDEX: Integer;

function TDGProcessList.TerminateProcess(dwProcessID: DWORD): Boolean;
var
  hProcess: THandle;
begin
  Result := False;
  hProcess := OpenProcess(PROCESS_ALL_ACCESS, False, dwProcessID);
  if hProcess <> 0 then begin
    Result := Windows.TerminateProcess(hProcess, 0);
    CloseHandle(hProcess)
  end;// if hProcess <> 0 then begin
end;// function TDGProcessList.TerminateProcess(dwProcessID: DWORD): Boolean;

function TDGProcessList.TerminateProcess(const Name: AnsiString): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 0 to FList.Count -1 do
    if SameText(Process[Index].Name, Name) then begin
      Result := TerminateProcess(Process[Index].ProcessID);
      Exit;
    end;// if SameText(Process[Index].Name, Name) then begin
end;// function TDGProcessList.TerminateProcess(const Name: AnsiString): Boolean;

end.// unit uDGProcessList;
