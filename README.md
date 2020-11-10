# Multicast-Events
Multicast tNotifyEvent or tDataSetNotifyEvent with Delphi - BETA

Ever wanted to be able to have multiple Events connected to one tNotifyEvent or better to a tDataSetNotifyEvent like AfterScroll?
I used the code-snippets from https://www.delphipraxis.net/143341-event-multicast-problem-howto-sender-methodname.html to create a new component / unit for usage.

Be sure that this is used only for internal purpouse and you can use the unit totally free for your own projects but pls test everything.
The creator of this unit cannot be made responsible for any damage you've made by using this and not testing it in your own environment.

Example-Usage in a tDataset descant:

unit myMulticastEventDatasetUnit;
interface
uses System.Classes, Data.DB, mxEventsUnit;

type
	tmyMulticastEventDataset=class(tDataset)
	private
		function fmxevents_get:tmxevents;
	public
		fmxEvents:TmxEvents;
		constructor Create(AOwner:TComponent); override;
		destructor Destroy; override;
	published
		property mxEvents:TmxEvents read fmxevents_get;
	end;

implementation

constructor tmyMulticastEventDataset.Create(AOwner: TComponent);
begin
	inherited;
	fmxEvents:=nil;
end;

destructor tmyMulticastEventDataset.Destroy;
begin
	if assigned(fmxEvents) then fmxEvents.free;
	fmxEvents:=nil;
	inherited;
end;

function tmyMulticastEventDataset.fmxevents_get: tmxevents;
begin
	// we Create the tmxEvents only if there is a need
	if not assigned(fmxevents) then begin
		fmxEvents:=tmxEvents.create(self);
	end;
	result:=fmxevents;
end;

end.

<< If someone knows a way to inject this into tDataset itself, you're free to change the code! >>

Declarations for Examples:
  myDS:tmyMulticastEventDataset;
  procedure FirstAfterScrollEvent(vDataset:tDataset); 
  procedure SecondAfterScrollEvent(vDataset:tDataset); 
  
Example-Usage for registering a AfterScroll Event:
  myDS.mxEvents.Event('AfterScroll').AddDatasetNotifyEvent('uniquenameforevent1',  FirstAfterScrollEvent) ;
  myDS.mxEvents.Event('AfterScroll').AddDatasetNotifyEvent('uniquenameforevent2',  SecondAfterScrollEvent) ;

Example-usage for disabling a already registered AfterScroll Event:
  myMCDS1.mxEvents.Event('AfterScroll').Disable('uniquenameforevent1') ;
  myMCDS1.mxEvents.Event('AfterScroll').Disable('uniquenameforevent2') ;

