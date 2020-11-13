# Multicast-Events
Multicast tNotifyEvent or tDataSetNotifyEvent with Delphi - BETA

Ever wanted to be able to have multiple Events connected to one tNotifyEvent or better to a tDataSetNotifyEvent like AfterScroll?
I used the code-snippets from https://www.delphipraxis.net/143341-event-multicast-problem-howto-sender-methodname.html to create a new component / unit for usage.

Be sure that this is used only for internal purpouse and you can use the unit totally free for your own projects but pls test everything.
The creator of this unit cannot be made responsible for any damage you've made by using this and not testing it in your own environment.

Example-Usage in a tDataset descant:

```
var
	vE:tmxEvents;
begin
	ve:=mxEvents_Connect2Dataset(myMemDataset1);
	if assigned(ve) then begin
		// add new AfterScroll Event to Eventslist
		vE.Event('AfterScroll').AddDatasetNotifyEvent(self, 'uniqueidentforthisevent', myAfterScrollEvent);
		
		// disable Event
		vE.Event('AfterScroll').Disable(self, 'uniqueidentforthisevent');
	end;
end;
```
