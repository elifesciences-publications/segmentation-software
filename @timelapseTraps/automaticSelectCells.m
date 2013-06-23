function automaticSelectCells(cTimelapse,params)
if nargin<2
    params.fraction=.9; %fraction of timelapse length that cells must be present or
    params.duration=6; %number of frames cells must be present
%     params.cellsToCheck=4;
    params.framesToCheck=350;
    params.framesToCheckEnd=1;

end

cTimelapse.cellsToPlot(:)=0;

if isempty(cTimelapse.timepointsProcessed)
    tempSize=[cTimelapse.cTimepoint.trapInfo];
    cTimelapse.timepointsProcessed=ones(1,length(tempSize)/length(cTimelapse.cTimepoint(1).trapInfo));
end

cTimepoint=cTimelapse.cTimepoint;
for trap=1:length(cTimelapse.cTimepoint(1).trapInfo)
    disp(['Trap Number ' int2str(trap)]);
    cellLabels=zeros(1,100*sum(cTimelapse.timepointsProcessed));
    cellLabelsEnd=zeros(1,100*sum(cTimelapse.timepointsProcessed));
    cellsSeen=[];
    index=0;
    for timepoint=1:length(cTimelapse.timepointsProcessed)
        if cTimelapse.timepointsProcessed(timepoint)
            tempLabels=cTimepoint(timepoint).trapInfo(trap).cellLabel;
            cellLabels(1,index+1:index+length(tempLabels))=tempLabels;
            if timepoint<=params.framesToCheck
                cellsSeen=max(cellLabels);
            end
            if timepoint>=params.framesToCheckEnd
                cellLabelsEnd(1,index+1:index+length(tempLabels))=tempLabels;
            end
            index=index+length(tempLabels);
        end
    end
    tempLabels=cellLabels(1:index);
%     cellLabelsEnd=cellLabelsEnd(1:index);
    cellLabelsEnd(cellLabelsEnd==0)=[];
    cellLabels=tempLabels;
    n=hist(cellLabels,0:max(cellLabels));
    n(1)=[];
    nEnd=hist(cellLabelsEnd,0:max(cellLabels));
    nEnd(1)=[];
    cellsSeenEnd=min(cellLabelsEnd);
    
    n(nEnd<1)=0;
    locs=find(n>=sum(cTimelapse.timepointsProcessed)*params.fraction | n>=params.duration);
    
    if ~isempty(cellsSeen) && ~isempty(locs)
        locs=locs(locs<=cellsSeen);
        if ~isempty(locs)
            for cellsForPlot=1:length(locs)
                cTimelapse.cellsToPlot(trap,locs(cellsForPlot))=1;
            end
        end
    end
end
