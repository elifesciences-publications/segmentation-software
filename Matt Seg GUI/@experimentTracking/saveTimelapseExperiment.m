function saveTimelapseExperiment(cExperiment,currentPos, saveCE)
% saveTimelapseExperiment(cExperiment,currentPos, saveCE)
% 
% saves cExperiment.cTimelapse to:
%   [cExperiment.saveFolder filesep cExperiment.dirs{currentPos},'cTimelapse']
%
% also saves the cExperiment to:
%       [cExperiment.saveFolder filesep 'cExperiment.mat']
%
% removing cExperiment.cCellVision, saving it as a separate object, then
% putting it back.
% 
% Third input is boolean - saveCE: logical - if true,
% save the cExperiment file as well as the timelapse,

if nargin<3
    saveCE=true;
end

cTimelapse=cExperiment.cTimelapse;
cTimelapse.temporaryImageStorage=[];

if isempty(cExperiment.OmeroDatabase)
    if nargin>1
        cTimelapseFilename=[cExperiment.saveFolder filesep cExperiment.dirs{currentPos},'cTimelapse'];
    else
        cTimelapseFilename=cExperiment.currentTimelapseFilename;
    end
    save(cTimelapseFilename,'cTimelapse');
    cExperiment.cTimelapse=[];
    
    if saveCE
        cCellVision=cExperiment.cCellVision;
        cExperiment.cCellVision=[];
        save([cExperiment.saveFolder filesep 'cExperiment.mat'],'cExperiment','cCellVision');
        cExperiment.cCellVision=cCellVision;
    end
else
    %Save code for Omero loaded cExperiments - upload cExperiment file to
    %Omero database. Use the alternative method saveExperiment if you want
    %to save only the cExperiment file.
    
    %Replace any existing cExperiment and cTimelapse files for the same
    %dataset.
    fileAnnotations=getDatasetFileAnnotations(cExperiment.OmeroDatabase.Session,cExperiment.omeroDs);
    dsName=char(cExperiment.cTimelapse.omeroImage.getName.getValue);%Name is equivalent to the position folder name
    
    %Create a cell array of file annotation names
    for n=1:length(fileAnnotations)
        faNames{n}=char(fileAnnotations(n).getFile.getName.getValue);
    end

    
    
    %Need to save to temp file before updating the file in the database.
    
    %cTimelapse file
    %Before saving, replace image object with its Id and the OmeroDatabase object with the server name - avoids a non-serializable warning
    oD=cTimelapse.OmeroDatabase;
    omeroImage=cTimelapse.omeroImage;
    cTimelapse.omeroImage=cTimelapse.omeroImage.getId.getValue;
    cTimelapse.OmeroDatabase=cTimelapse.OmeroDatabase.Server;    
    fileName=[cExperiment.saveFolder filesep dsName 'cTimelapse_' cExperiment.rootFolder '.mat'];
    save(fileName,'cTimelapse');
    %Restore image and OmeroDatabase objects
    cTimelapse.ActiveContourObject.TimelapseTraps = cTimelapse;
    cTimelapse.omeroImage=omeroImage;
    cTimelapse.OmeroDatabase=oD;
    faIndex=strcmp([dsName 'cTimelapse_' cExperiment.rootFolder '.mat'],faNames);
    faIndex=find(faIndex);
 
    if ~isempty(faIndex)
        faIndex=faIndex(1);
        disp(['Uploading file ' char(fileAnnotations(faIndex).getFile.getName.getValue)]);
        fA = updateFileAnnotation(cExperiment.OmeroDatabase.Session, fileAnnotations(faIndex), fileName);
    else%The file is not yet attached to the dataset
        cExperiment.OmeroDatabase.uploadFile(fileName, cExperiment.omeroDs, 'cTimelapse file uploaded by @experimentTracking.saveTimelapseExperiment');
    end
    
    if saveCE
        %cExperiment file
        %Before saving, replace OmeroDatabase object with the server name, make .cTimelapse empty and replace .omeroDs with its Id to avoid
        %non-serializable errors.   
        cExperiment.cTimelapse=[];
        omeroDatabase=cExperiment.OmeroDatabase;
        cExperiment.OmeroDatabase=cExperiment.OmeroDatabase.Server;
        omeroDs=cExperiment.omeroDs;
        cExperiment.omeroDs=[];
        fileName=[cExperiment.saveFolder filesep 'cExperiment_' cExperiment.rootFolder '.mat'];
        %Save cCellVision as a seperate variable
        cCellVision=cExperiment.cCellVision;
        cExperiment.cCellVision=[];
       
        save(fileName,'cExperiment','cCellVision');
        %Update or upload the file - first need to find the file annotation
        %object
        faIndex=strcmp(['cExperiment_' cExperiment.rootFolder '.mat'],faNames);
        faIndex=find(faIndex);
        if ~isempty(faIndex)
             faIndex=faIndex(1);
             disp(['Uploading file ' char(fileAnnotations(faIndex).getFile.getName.getValue)]);
             fA = updateFileAnnotation(omeroDatabase.Session, fileAnnotations(faIndex), fileName);
        else%The file is not yet attached to the dataset
            omeroDatabase.uploadFile(fileName, omeroDs, 'cExperiment file uploaded by @experimentTracking.saveTimelapseExperiment');
        end
        %Restore the cExperiment object
        cExperiment.omeroDs=omeroDs;
        cExperiment.OmeroDatabase=omeroDatabase;
        cExperiment.cCellVision=cCellVision;
    end
end
