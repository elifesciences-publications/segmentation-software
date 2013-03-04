function compilecellInf(cExperiment,positionsToExtract)

%method is either 'overwrite' or 'update'. If overwrite, it goes through
%all of the cellsToPlot and extracts the information from the saved
%Timelapses. If method is 'update', it finds the cells that have been added
%to the cellsToPlot and adds their inf to the cellInf, and removes those
%that have been removed.



if nargin<2
    positionsToExtract=find(cExperiment.posTracked);
%     positionsToTrack=1:length(cExperiment.dirs);
end

%% Run the tracking on the timelapse
experimentPos=positionsToExtract(1);
load([cExperiment.rootFolder '/' cExperiment.dirs{experimentPos},'cTimelapse']);
cExperiment.cellInf=struct(cTimelapse.extractedData);
[cExperiment.cellInf().posNum]=[];
for i=1:length(positionsToExtract)
    experimentPos=positionsToExtract(i);
    load([cExperiment.rootFolder '/' cExperiment.dirs{experimentPos},'cTimelapse']);
    
    for j=1:length(cTimelapse.channelNames)
            temp=cTimelapse.extractedData(j).mean;
            cExperiment.cellInf(j).mean(end+1:end+size(temp,1),:)=temp;
            temp=cTimelapse.extractedData(j).median;
            cExperiment.cellInf(j).median(end+1:end+size(temp,1),:)=temp;
            temp=cTimelapse.extractedData(j).max5;
            cExperiment.cellInf(j).max5(end+1:end+size(temp,1),:)=temp;
            temp=cTimelapse.extractedData(j).std;
            cExperiment.cellInf(j).std(end+1:end+size(temp,1),:)=temp;
            temp=cTimelapse.extractedData(j).radius;
            cExperiment.cellInf(j).radius(end+1:end+size(temp,1),:)=temp;
            temp=cTimelapse.extractedData(j).trapNum;
            cExperiment.cellInf(j).trapNum(end+1:end+size(temp,1),:)=temp;
            temp=cTimelapse.extractedData(j).cellNum;
            cExperiment.cellInf(j).cellNum(end+1:end+size(temp,1),:)=temp;
            cExperiment.cellInf(j).posNum(end+1:end+size(temp,1),:)=experimentPos;
    end

    cExperiment.saveExperiment();
end