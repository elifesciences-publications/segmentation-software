function identifyTrapsTimelapses(cExperiment,cCellVision,positionsToIdentify)


if nargin<3
    positionsToIdentify=1:length(cExperiment.dirs);
end

Message=(['Each position of the experiment will be displayed one by one. The program will guess where the traps are present at first, but you will need to add (left-click) or remove' ...
    ' (right-click) traps to make sure that the trap selection is properly performed. It is generally advisable to look at the timelapse for a single position to make sure the stage ' ...
    'didnt drift too much during the experiment. If it did drift you want to make sure not to select traps that will go out of the field of view during the experiment.']);
h = helpdlg(Message);
uiwait(h);
    
%% Load timelapses

Positive ='track first timepoint' ;
Negative ='no thanks' ;
TrackFirstTimpointDlgOut = questdlg(...
    ['Would you like to track the first timepoint to find drift and use this to try and rule out'...
    ' traps that will be lost due to drift? This will delete any cell information in the first timepoint'...
    ' submitted.This is only useful if selecting traps in numerous positions and if the experiment has a'...
    ' reasonably large drift and if you only want analyse positions present for the whole duration.']...
    ,'track first timepoint to remove drift?',Positive,Negative,Negative);

TrackFirstTimepoint = strcmp(TrackFirstTimpointDlgOut,Positive);

for i=1:length(positionsToIdentify)
    currentPos=positionsToIdentify(i);
    load([cExperiment.saveFolder '/' cExperiment.dirs{currentPos},'cTimelapse']);
    if TrackFirstTimepoint
        if i==1
            cTrapSelectDisplay(cTimelapse,cCellVision,cExperiment.timepointsToProcess(i));
            uiwait();
            cTimelapse.trackTrapsThroughTime(cCellVision,cExperiment.timepointsToProcess);
            TotalXDrift = mode([cTimelapse.cTimepoint(cExperiment.timepointsToProcess(end)).trapLocations(:).xcenter] - ...
                [cTimelapse.cTimepoint(cExperiment.timepointsToProcess(1)).trapLocations(:).xcenter],2);
            TotalYDrift = mode([cTimelapse.cTimepoint(cExperiment.timepointsToProcess(end)).trapLocations(:).ycenter] - ...
                [cTimelapse.cTimepoint(cExperiment.timepointsToProcess(1)).trapLocations(:).ycenter],2);
            ExclusionZone = [];
            if TotalXDrift>0
                ExclusionZone = [(cTimelapse.imSize(2) - (TotalXDrift + ceil(cTimelapse.cTrapSize.bb_width/2))) 1 ...
                                    cTimelapse.imSize(2) cTimelapse.imSize(1)];
                
            else
                ExclusionZone = [1 1 ...
                                    (TotalXDrift + ceil(cTimelapse.cTrapSize.bb_width/2)) cTimelapse.imSize(1)];
                
            end
            
             if TotalYDrift>0
                ExclusionZone = [ExclusionZone ;...
                                    [1 (cTimelapse.imSize(1) - (TotalYDrift + ceil(cTimelapse.cTrapSize.bb_height/2))) ...
                                    cTimelapse.imSize(2) cTimelapse.imSize(1)] ];
                
            else
                ExclusionZone = [ExclusionZone ;...
                                    [1 1 ...
                                    cTimelapse.imSize(2) (TotalYDrift + ceil(cTimelapse.cTrapSize.bb_height/2))] ];
                 
            end
            
        else
            
            cTrapSelectDisplay(cTimelapse,cCellVision,cExperiment.timepointsToProcess(1),[],ExclusionZone);
            uiwait();
            
        end
    else
        cTrapSelectDisplay(cTimelapse,cCellVision,cExperiment.timepointsToProcess(1));
        uiwait();
    end
    
    cExperiment.cTimelapse=cTimelapse;
    cExperiment.saveTimelapseExperiment(currentPos);
end
