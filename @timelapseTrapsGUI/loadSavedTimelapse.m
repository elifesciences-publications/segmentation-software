function loadSavedTimelapse(cTrapsGUI)

[FileName,PathName,FilterIndex] = uigetfile('*.mat','Name of previously create TimelapseTraps variable') ;
load(fullfile(PathName,FileName),'cTimelapse');
cTrapsGUI.cTimelapse=cTimelapse;
