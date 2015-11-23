function timepointIm=returnSingleTimepoint(cTimelapse,timepoint,channel,type)
% timepointIm=returnSingleTimepoint(cTimelapse,timepoint,channel,type)
%
% Most basically returns the image for a given channel and timepoint. Does
% so in raw format, so is usually a uint16.
%
% timepoint   :   number indicating the desired timepoint (will access this
%                 element of the cTimepoint array).
% channel     :   number (default 1) indicating which of the channels in
%                 cTimelapse.channelNames to use to identify appropriate
%                 files.
% type        :   string (default 'max'). if more than one file is loaded
%                 (e.g. in the case of a z stack) how to handle this stack.
%                 either 'max','sum','min' or 'stack' - applying
%                 concomitant operation to the stack or returning the whole
%                 stack in the case of 'stack'.
%
% This is a rather confusing fuction that does a number of things, but due
% to its widespread use in the code is hard to change. a timepoint and
% channel are specified, and the channel index is used to get a channel
% string from the cTimelapse.channelNames field. all filenames associated
% with that timepoint (i.e. in cTimepoint.filename cell array) that contain
% the channel string are identified. If there is only one this is loaded,
% whereas if there are more than one they are all loaded and put into a
% stack. This stack is then treated accoding to the 'type' argument, with
% either a projection ('min','max' etc.) being made or the whole stack
% being returned. The default is max.
% A number of operations are then applied to the image. 
%
% scaling - if the imScale field of cTimelapse is not empty the image is
%           rescaled using the imresize command imresize(image, imScale)
%
% background correction - if the field cTimelapse.BackgroundCorrection{channel} 
%                         is not empty it is taken to be a flat field
%                         correction and is appplied to the image by
%                         element wise multiplication.
%
% rotation - if cTimelapse.image_rotation is not zero the image is rotated
%            by this amount using imrotate function. Any extra elements
%            added are padded with the median value of the image. This may
%            change the size of the image.
%
% offset - if the channel row of the array cTimelapse.offset is not zero
%          then the image is shifted by this amount (offset is specified as
%          [x_offset y_offset]). Allows images from different channels to
%          be registered properly. Any extra values are padded by the
%          median value of the image.
%
% These corrections are applied in this order. 
%
% The function also takes a number of other liberties. If the timelapseDir
% is set to 'ignore' it takes the filenames to be absolute (this can be
% done using the method makeFileNamesAbsolute). If this is not the case, it
% constructs the file name from timelapseDir and filename{i}. In doing so
% it takes the liberty of resaving the file name with only the relative
% path (i.e. it throws away anything behind the last / or \). 
% Loading is done in a try catch loop and if it fails the user is
% requested to provide a new timelapseDir. For cExperiments this is best
% done using the changeRootDirsAll method.
%
% If there is no filename matching the channel at the timepoint requested
% an image of the appropriate size of all zeros is returned and a warning
% displayed.

if nargin<3 || isempty(channel)
    channel=1;
end

if nargin<4 || isempty(type)
    type='max';
end

tp=timepoint;

if isempty(cTimelapse.OmeroDatabase)

    fileNum=regexp(cTimelapse.cTimepoint(timepoint).filename,cTimelapse.channelNames{channel},'match');
    loc= ~cellfun('isempty',fileNum);
    if sum(loc)>0
        file=cTimelapse.cTimepoint(timepoint).filename{loc};
        
        if ~strcmp(cTimelapse.timelapseDir,'ignore')
            
            locSlash=strfind(file,'/');
            
            if isempty(locSlash)
                locSlash=strfind(file,'\'); %in case file was made on a windows machine
            end
            
            if locSlash
                inds=find(loc);
                for i=1:sum(loc)
                    file=cTimelapse.cTimepoint(timepoint).filename{inds(i)};
                    file=file(locSlash(end)+1:end);
                    cTimelapse.cTimepoint(timepoint).filename{inds(i)}=file;
                end
            end
            
        end
        
        try
            
            ind=find(loc);
            file=cTimelapse.cTimepoint(timepoint).filename{ind(1)};
            if strcmp(cTimelapse.timelapseDir,'ignore')
                ffile=file;
            else
                ffile=fullfile(cTimelapse.timelapseDir,file);
            end
            if ~isempty(cTimelapse.imSize)
                timepointIm=[];
                %look for TIF at end of filename and change load method
                %appropriately.
                if ~isempty(regexp(ffile,'TIF$'))
                    timepointIm=imread(ffile,'Index',1);
                    timepointIm=timepointIm(:,:,1);
                else
                    timepointIm(:,:,1)=imread(ffile);
                end
            else
                timepointIm=imread(ffile);
                cTimelapse.imSize=size(timepointIm);
            end
            for i=2:sum(loc)
                file=cTimelapse.cTimepoint(timepoint).filename{ind(i)};
                ffile=fullfile(cTimelapse.timelapseDir,file);
                timepointIm(:,:,i)=imread(ffile);
            end
            
            %change if want things other than maximum projection
            switch type
                case 'min'
                    timepointIm=min(timepointIm,[],3);
                case 'max'
                    timepointIm=max(timepointIm,[],3);
                case 'stack'
                    timepointIm=timepointIm;
                case 'sum'
                    timepointIm=sum(timepointIm,3);
            end
            
            
        catch
            folder =[];
            h=errordlg('Directory seems to have changed');
            uiwait(h);
            attempts=0;
            while isempty(folder) && attempts<3
                fprintf(['Select the correct folder for: \n',cTimelapse.timelapseDir '\n']);
                folder=uigetdir(pwd,['Select the correct folder for: ',cTimelapse.timelapseDir]);
                cTimelapse.timelapseDir=folder;
                attempts=attempts+1;
            end
            ind=find(loc);
            file=cTimelapse.cTimepoint(timepoint).filename{ind(1)};
            ffile=fullfile(cTimelapse.timelapseDir,file);
            if ~isempty(cTimelapse.imSize)
                timepointIm=zeros([cTimelapse.imSize sum(loc)]);
                timepointIm(:,:,1)=imread(ffile);
            else
                timepointIm=imread(ffile);
            end
            for i=2:sum(loc)
                file=cTimelapse.cTimepoint(timepoint).filename{ind(1)};
                ffile=fullfile(cTimelapse.timelapseDir,file);
                timepointIm(:,:,i)=imread(ffile);
            end
            timepointIm=max(timepointIm,[],3);
        end
    else
        if cTimelapse.imSize
            timepointIm=zeros(cTimelapse.imSize);
        else
            file=cTimelapse.cTimepoint(timepoint).filename{1};
            if strcmp(cTimelapse.timelapseDir,'ignore')
                ffile = file;
            else
                ffile=fullfile(cTimelapse.timelapseDir,file);
            end
            timepointIm=imread(ffile);
            timepointIm(:,:)=0;
            cTimelapse.imSize=size(timepointIm);
        end
        disp('There is no data in this channel at this timepoint');
    end
    
    if isempty(cTimelapse.imSize) %set the imsize property if it hasn't already been set
        cTimelapse.imSize = size(timepointIm);
    end
    
%used for padding data
medVal=median(timepointIm(:));
        

%This was a correction instigated by Matt but seems like a really bad
%idea to just include without any kind of check. have commented out for
%now.

%correction for stupid thing where the first couple columns sometimes turn
%REALLY bright .... why???? some camera issue.
% firstColMean=mean(timepointIm(:,1));
% medVal=median(timepointIm(:));
% meanVal=medVal;
% if firstColMean>meanVal*1.5
%     timepointIm(:,1)=meanVal;
%     firstColMean=mean(timepointIm(:,2));
%     if firstColMean>meanVal*1.5
%         timepointIm(:,2)=meanVal;
%     end
% end


    if ~isempty(cTimelapse.imScale)
        timepointIm=imresize(timepointIm,cTimelapse.imScale);
        %to correct for black lines
        timepointIm(1:2,:)=timepointIm(3:4,:);
        timepointIm(:,end-1:end)=timepointIm(:,end-3:end-2);
    end
    

    
    if size(cTimelapse.BackgroundCorrection,2)>=channel && ~isempty(cTimelapse.BackgroundCorrection{channel})
        %first part of this statement is to guard against cases where channel
        %has not been assigned
        timepointIm = timepointIm.*cTimelapse.BackgroundCorrection{channel};
    end
    
    
    % Elco: I don't believe any timelapse has timpoint specific image rotation
    % anymore. Left in just in case of legacy cases.
    if isfield(cTimelapse.cTimepoint(tp),'image_rotation') & ~isempty(cTimelapse.cTimepoint(tp).image_rotation)
        image_rotation=cTimelapse.cTimepoint(tp).image_rotation;
    else
        image_rotation=cTimelapse.image_rotation;
    end
    
    if image_rotation~=0
        bbN=200;
        for slicei = 1:size(timepointIm,3)
            tpImtemp=padarray(timepointIm(:,:,slicei),[bbN bbN],medVal,'both');
            tpImtemp=imrotate(tpImtemp,image_rotation,'bilinear','loose');
            timepointIm(:,:,slicei)=tpImtemp(bbN+1:end-bbN,bbN+1:end-bbN);
        end
        
    end
    
    if size(cTimelapse.offset,1)>=channel && any(cTimelapse.offset(channel,:)~=0)
        %first part of this statement is to guard against cases where channel
        %has not been assigned
        TimepointBoundaries = fliplr(cTimelapse.offset(channel,:));
        LowerTimepointBoundaries = abs(TimepointBoundaries) + TimepointBoundaries +1;
        HigherTimepointBoundaries = [size(timepointIm,1) size(timepointIm,2)] + TimepointBoundaries + abs(TimepointBoundaries);
        timepointIm = padarray(timepointIm,[abs(TimepointBoundaries) 0],medVal);
        timepointIm = timepointIm(LowerTimepointBoundaries(1):HigherTimepointBoundaries(1),LowerTimepointBoundaries(2):HigherTimepointBoundaries(2),:);
    end
    

else
    %Code for returning image from Omero database
    %The channel input refers to the channels list in cTimelapse - not in
    %the Omero version of the data - need to work that out.
    
    if iscell(cTimelapse.channelNames)
        channelName=cTimelapse.channelNames{channel};
    else
        channelName=cTimelapse.channelNames;
    end
    chNum=find(strcmp(channelName,cTimelapse.OmeroDatabase.Channels));
    
    if isempty (cTimelapse.OmeroDatabase.Session)
        cTimelapse.OmeroDatabase.login;
    end
    done=false;
    while done==false
        try
            [store, pixels] = getRawPixelsStore(cTimelapse.OmeroDatabase.Session, cTimelapse.omeroImage);
            done=true;
        catch err
            cTimelapse=cTimelapse.OmeroDatabase.login;
            %server may be busy
            disp(err.message);
            done=false;
        end
    end
    sizeZ = pixels.getSizeZ().getValue(); % The number of z-sections.
    sizeT = pixels.getSizeT().getValue(); % The number of timepoints.
    sizeC = pixels.getSizeC().getValue(); % The number of channels.
    sizeX = pixels.getSizeX().getValue(); % The number of pixels along the X-axis.
    sizeY = pixels.getSizeY().getValue(); % The number of pixels along the Y-axis.
    timepointIm=zeros(sizeY, sizeX, sizeZ);
    for z=1:sizeZ
        try
        plane=store.getPlane(z-1, chNum-1, timepoint-1);
        catch
            %Fix upload script to prevent the need for this debug
            disp('No plane for this section channel and timepoint, return equivalent image from the previous timepoint - prevents bugs in segmentation');
            plane=store.getPlane(z-1, chNum-1, timepoint-2);
            timepoint=timepoint-1;
        end
        timepointIm(:,:,z) = toMatrix(plane, pixels)';
    end
    store.close();
    switch type
        case 'max'
            timepointIm=max(timepointIm,[],3);
        case 'stack'
            timepointIm=timepointIm;
        case 'sum'
            timepointIm=sum(timepointIm,3);
    end
    if isfield(cTimelapse.cTimepoint(timepoint),'image_rotation') && ~isempty(cTimelapse.cTimepoint(timepoint).image_rotation)
        image_rotation=cTimelapse.cTimepoint(timepoint).image_rotation;
    else
        image_rotation=cTimelapse.image_rotation;
    end
    
    if image_rotation~=0
        medVal=median(timepointIm(:));
        bbN=200;
        tpImtemp=padarray(timepointIm,[bbN bbN],medVal,'both');
        tpImtemp=imrotate(tpImtemp,image_rotation,'bilinear','loose');
        tpImtemp(tpImtemp==0)=medVal;
        timepointIm=tpImtemp(bbN+1:end-bbN,bbN+1:end-bbN);
        
        
    end

                    
    
end
