unit mxEventsUnit;
interface

uses
	classes, db, sysutils, System.TypInfo, System.Generics.Collections;

type
	tmxEventMethod = record
		vActive:boolean;
		vType:integer; // 0=Notify, 1=DatasetNotify
		vIdent:string;
		vSender:tObject;
		vMethod:tmethod;
	end;
	tmxEventMethodArray = array of tmxEventMethod;

	TmxEventHandler = class(TPersistent)
	private
		fInternalWorking:boolean;

		fEvent: TMethod;
		fOwner: pointer;
		fEventName: string;

		OriginalMethod: TMethod;
		ScriptMethod: tmxEventMethodArray;
		function  addorgetScriptMethod(vSender:tObject; vIdent:string):integer;
	public
		procedure Init(const vSender: TComponent; const Event: string);

		procedure Add(vSender:tObject; const vIdent:string; const vtype:integer; const PMethod: tMethod);
		procedure AddNotifyEvent(vSender:tObject; const vIdent:string; vNotifyEvent:tNotifyEvent);
		procedure AddDatasetNotifyEvent(vSender:tObject; const vIdent:string; vNotifyEvent: TDataSetNotifyEvent);

		procedure Disable(vSender:tObject; const vIdent:string);

		constructor Create;
		destructor Destroy; override;
	published
		procedure StartEventHandler(Sender: TObject);
	end;

	tmxEvents = class(tPersistent)
	private
		fOwnerComponent:tComponent;
		fEvents:tDictionary<string, tmxEventHandler>;

		function fEvents_Get(const vEventname:string):tmxEventHandler;
		function fEvents_Delete(const vEventname: string): boolean;
		function fEvents_Add(const vEventName: string):TmxEventHandler;
	public
		procedure DeleteEvent(const vEventName:string);
		function  Event(const vEventName:string):tmxEventHandler;
	published
		constructor create(const vOwnerComponent:tComponent);
		destructor Destroy; override;
	end;

	function mxEvents_Connect2Dataset(vDataset:tdataset):tmxEvents;

	var mxEvents_Global_Datasets:tDictionary<tDataset, tmxEvents>;

implementation

const fMonitorTimeout=10000;

// Global function which can be used in units to connect an tmxEvents to a dataset or return a connected tmxEvents for a tDataset
// i.e. vE:=mxEvents_Connect2Dataset(mymemtable1);
//      vE.Event('AfterScroll').AddDatasetNotifyEvent(self, 'uniqueid1',  myadditionalafterscrollevent ) ;
//      vE.Event('AfterPost').Disable(self, 'uniqueid1' );		
function mxEvents_Connect2Dataset(vDataset:tdataset):tmxEvents;
begin
	mxEvents_Global_Datasets.TryGetValue(vdataset, result);
	if not assigned(result) then begin
		result:=tmxEvents.create(vdataset);
		mxEvents_Global_Datasets.Add(vdataset, result);
	end;
end;

{
	tmxEvents
	Liste von möglichen Events wie AfterScroll, AfterOpen
}
constructor tmxEvents.create(const vOwnerComponent: tComponent);
begin
	fOwnerComponent:=vOwnerComponent;

	fEvents:=TDictionary<String, tmxEventHandler>.Create();
end;
destructor tmxEvents.Destroy;
var
	i:integer;
begin
    // manually cleanup tDictionary
	for i:=0 to fEvents.Count-1 do begin
		if assigned(fEvents.ToArray[i].Value) then begin
			Freeandnil(fEvents.ToArray[i].Value);
		end;
	end;
	Freeandnil(fEvents);

	inherited;
end;

// Funktionen zur Pflege des tDictionary
function tmxEvents.fEvents_Get(const vEventname:string):tmxEventHandler;
var
	vfehler:integer;
	vNewEventName:string;
begin
	result:=nil;

	if MonitorEnter(fEvents, fMonitorTimeout) then begin
		try
			vfehler:=0;
			vNewEventName:=trim(lowercase(vEventName));
			fEvents.TryGetValue(vNewEventName, result);
		finally
			MonitorExit(fEvents);
		end;
	end;
end;
function tmxEvents.fEvents_Delete(const vEventname: string): boolean;
var
	vValue:tmxEventHandler;
	vNewEventName:string;
begin
	result:=false;

	if MonitorEnter(fEvents, fMonitorTimeout) then begin
		try
			vNewEventName:=trim(lowercase(vEventName));

			if fEvents.ContainsKey(vNewEventName) then begin
				// Free Objects
				if fEvents.TryGetValue(vNewEventName, vValue) then
				if assigned(vValue) then begin
					try
						Freeandnil(vValue);
					except
						on e:Exception do begin
						end;
					end;
				end;

				fEvents.Remove(vNewEventName);
				fEvents.TrimExcess;
				result:=true;
			end;

		finally
			MonitorExit(fEvents);
        end;
    end;
end;
function tmxEvents.fEvents_Add(const vEventName: string):TmxEventHandler;
var
	vNewEventName:string;
begin
	vNewEventName:=trim(lowercase(vEventName));
	result:=fEvents_Get(vNewEventName);

	if result=nil then begin
		result:=tmxEventHandler.Create;
		result.Init(fOwnerComponent, vNewEventName);
		fEvents.Add(vNewEventName, result);
	end;
end;

// Einfachere Aufrufmethoden
procedure tmxEvents.DeleteEvent(const vEventName: string); begin fEvents_Delete(vEventName); end;
function tmxEvents.Event(const vEventName: string): tmxEventHandler; begin result:=fEvents_Add(vEventName); end;


// ************************************************************************************************************************************************************************************************
// ************************************************************************************************************************************************************************************************
// Eventhandler
// Wird pro Komponente einmal erzeugt und verwaltet die unterschiedlichen Events
// ************************************************************************************************************************************************************************************************
// ************************************************************************************************************************************************************************************************
constructor TmxEventHandler.Create;
begin
	fInternalWorking:=false;
	fEvent.Code := Self.MethodAddress('StartEventHandler');
	fEvent.Data := Pointer(Self);
end;
destructor TmxEventHandler.Destroy;
begin
	SetMethodProp(TObject(fOwner), fEventName, OriginalMethod);
	setlength(ScriptMethod,0);
	inherited;
end;
procedure TmxEventHandler.Disable(vSender:tObject; const vIdent: string);
begin
	ScriptMethod[addorgetScriptMethod(vSender, vIdent)].vActive:=false;
end;

procedure TmxEventHandler.Init(const vSender: TComponent; const Event: string);
var
	i:integer;
begin
	if not assigned(vSender) then exit;

	fOwner := Pointer(vSender);
	fEventName := Event;

	OriginalMethod := GetMethodProp(vSender, Event);
	setlength(ScriptMethod, 0);

	SetMethodProp(vSender, Event, fEvent);
end;
function tmxEventHandler.addorgetScriptMethod(vSender:tobject; vIdent:string):integer;
var
	vnewindex, i:integer;
	vfound:boolean;
begin
	vfound:=false;
	while fInternalWorking do TThread.Sleep(10);

	try
		fInternalWorking:=true;
		for i:=0 to length(ScriptMethod)-1 do begin
			if scriptmethod[i].vActive then begin
				if assigned(scriptmethod[i].vSender) then begin
					if scriptmethod[i].vsender=vSender then
					if ansisametext(scriptmethod[i].vident, vident) then begin
						result:=i;
						vfound:=true;
						break;
					end;
				end;
			end;
		end;

		if vfound=false then begin
			vnewindex:=-1;
			for i:=0 to length(ScriptMethod)-1 do begin
				if scriptmethod[i].vActive=false then begin
					vnewindex:=i;
					break;
				end;
			end;

			if vnewindex=-1 then begin
				setlength(scriptmethod, length(scriptmethod)+1);
				vnewindex:=length(scriptmethod)-1;
			end;

			scriptmethod[vnewindex].vActive:=true;
			scriptmethod[vnewindex].vident:=vIdent;
			scriptmethod[vnewindex].vSender:=vSender;
			scriptmethod[vnewindex].vMethod.Data:=self;
			scriptmethod[vnewindex].vMethod.Code:=0;
			result:=vnewindex;
		end;
	finally
		fInternalWorking:=false;
	end;
end;

procedure TmxEventHandler.Add(vSender:tObject; const vIdent:string; const vtype:integer; const PMethod: tMethod);
var
	vindex:integer;
begin
	vindex:=addorgetScriptMethod(vSender, vIdent);
	scriptmethod[vindex].vType:=vtype;
	scriptmethod[vindex].vSender:=vSender;
	scriptmethod[vindex].vMethod.Code:=pMethod.Code;
	scriptmethod[vindex].vMethod.Data:=pMethod.Data;
end;
procedure TmxEventHandler.AddNotifyEvent(vSender:tObject; const vIdent:string; vNotifyEvent: tNotifyEvent);
var
	vMethod:tMethod;
begin
	vMethod:=tMethod(vNotifyEvent);
	Add(vSender, vIdent, 0, vMethod);
end;
procedure TmxEventHandler.AddDatasetNotifyEvent(vSender:tObject; const vIdent:string; vNotifyEvent: tDatasetNotifyEvent);
var
	vMethod:tMethod;
begin
	vMethod:=tMethod(vNotifyEvent);
	Add(vSender, vIdent, 1, vMethod);
end;
procedure TmxEventHandler.StartEventHandler(Sender: TObject);
var
	i:integer;
begin
	if assigned(TNotifyEvent(OriginalMethod)) then
		TNotifyEvent(OriginalMethod)(Sender);

	// Jetzt alle weitere aufrufen
	for i:=0 to length(scriptmethod)-1 do begin
		if scriptmethod[i].vActive then begin

			if not assigned(TNotifyEvent(ScriptMethod[i].vMethod)) then continue;
			if not assigned(ScriptMethod[i].vSender) then continue;
			if csDestroying in tComponent(ScriptMethod[i].vSender).ComponentState then continue;
			if csDestroying in tComponent(ScriptMethod[i].vMethod.Data).ComponentState then continue;

			if scriptmethod[i].vType=0 then TNotifyEvent(ScriptMethod[i].vMethod)(Sender) else
			if scriptmethod[i].vType=1 then tDatasetNotifyEvent(ScriptMethod[i].vMethod)(tDataset(Sender)) else

			raise Exception.Create('TmxEventHandler.StartEventHandler for unknown TYPE!');
		end;
	end;
end;


var
	mxegdc_i:integer;

Initialization
	mxEvents_Global_Datasets:=tDictionary<tDataset, tmxEvents>.Create();

finalization

	if assigned(mxEvents_Global_Datasets) then begin
		try
			for mxegdc_i:=0 to mxEvents_Global_Datasets.Count-1 do begin
				try
					if assigned(mxEvents_Global_Datasets.ToArray[mxegdc_i].Value) then begin
						mxEvents_Global_Datasets.ToArray[mxegdc_i].Value.free;
						mxEvents_Global_Datasets.ToArray[mxegdc_i].Value:=nil;
					end;
				except
                end;
			end;
		except
		end;

		freeandnil(mxEvents_Global_Datasets);
	end;


end.
