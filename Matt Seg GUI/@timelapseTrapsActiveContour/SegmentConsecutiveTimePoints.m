function ttacObject = SegmentConsecutiveTimePoints(ttacObject,FirstTimepoint,LastTimepoint, FixFirstTimePointBoolean, CellsToUse,do_gui)
% ttacObject = SegmentConsecutiveTimePoints(ttacObject,FirstTimepoint,LastTimepoint, FixFirstTimePointBoolean, CellsToUse)
% ttacObject                    -       object of the
%                                       timelapseTrapsActiveContour class
% FirstTimepoint                -       first timepoint at which to begin segmentation 
% LastTimepoint                 -       last time point at which to end segmentation 
% FixFirstTimePointBoolean      -       optional (logical) whether to keep the outline of the
%                                       first timepoint fixed
% CellsToUse                    -       optional (array) of type [trapIndex cellLabel] 
%                                       specifying which cells should be
%                                       segmented. can also just be the
%                                       column vector [trapIndex]
% do_gui                        -       logical(optional) whether to do gui
if nargin<4|| isempty(FixFirstTimePointBoolean)
    
    FixFirstTimePointBoolean = false;
    
end

if nargin<6|| isempty(do_gui)
    
    do_gui = true;
    
end

ACparameters = ttacObject.Parameters.ActiveContour;
ITparameters = ttacObject.Parameters.ImageTransformation;
slice_size = ttacObject.Parameters.ImageSegmentation.slice_size; %2;%slice of the timestack you look at in one go
keepers = ttacObject.Parameters.ImageSegmentation.keepers;    %1;%number of timpoints from that slice that you will keep (normally slice_size-1)
SubImageSize = ttacObject.Parameters.ImageSegmentation.SubImageSize;%61;
% OptPoints = ttacObject.Parameters.ImageSegmentation.OptPoints;%6;
OptPoints = ttacObject.Parameters.ActiveContour.opt_points;%6;
ttacObject.Parameters.ImageSegmentation.OptPoints=ttacObject.Parameters.ActiveContour.opt_points;

CellPreallocationNumber = 200;

%protects program from super crashing out by opening and closing a million
%images.
if LastTimepoint-FirstTimepoint>50 
    
    ACparameters.visualise = 0;
end


%FauxCentersStack is just a filler for the PSO optimisation that takes centers
%(because in this code the centers are always at the centers of the image).
%Better to assign it here than every time in the loop.
FauxCentersStack = round(SubImageSize/2)*ones(slice_size,2);

%size of trap image stored in Timelapse. If there are no traps, this is the
%size of the image.


Timepoints = FirstTimepoint:LastTimepoint;

%% NOTES

%load in images for the slice size
%construct transformed image stacks for each cell at those timepoints
%run those stacks through the segmentation
%BEGIN LOOP
%delete the first image of the stack
%load the next image image
%transform for all the cells in the latest image
%update all the little stacks
%segment all of those
%END LOOP


%celllabel(1) corresponds to cell(1) information
%cell centre is in xy coordinates relative to trapimage edge, so need to
%subtract half trap image dimensions and add trap centre to cell centre to get
%true centre.

%store cell information in a structure array


% CellInfo.TrapNumber
% CellInfo.CellLabel
% CellInfo.Centre
% CellInfo.TransformedImageStack
% CellInfo.Priors
% CellInfo.SegmentationResult
% CellInfo.PreviousTimepointResult
%
%


ttacObject.CheckTimepointsValid(Timepoints)

%% create structure in which to store cell data
%it might seem the construction is strange, but it turned out to be fairly
%efficient to make a field for each slice of the final stack and then pass
%images backwards through the fields using 'deal'.

%The data structure is organised such that the most recent timepoint is the
%highest number, so that data are entered in the field 'fieldname_n', and
%then cycled back to 'fieldname_n-1',fielname_n-2' as other later data
%comes in to push them back. They are finally deposited in 'fieldname_1'
CellInfo = struct;
CellInfo.CellNumber = 0;
CellInfo.TrapNumber = 0;
CellInfo.CellLabel = 0;
CellInfo.PreviousTimepointResult = zeros(1,OptPoints);
CellInfo.TimePointsPresent = 0;
CellInfo.TimePointsAbsent = 0;
CellInfo.UpdatedThisTimepoint = false;

CellCentreStrings = cell(1,slice_size);
TrapCentreStrings = cell(1,slice_size);
TransformedImageStrings = cell(1,slice_size);
PriorRadiiStrings = cell(1,slice_size);
PriorAnglesStrings = cell(1,slice_size);
CellNumberTimelapseStrings = cell(1,slice_size);
TimePointStrings = cell(1,slice_size);
ExcludeImageStrings = cell(1,slice_size);

for i=1:slice_size
    CellCentreStrings{i} = ['CellCentre' int2str(i)];
    CellInfo.(CellCentreStrings{i}) = zeros(1,2);
    TrapCentreStrings{i} =['TrapCentre' int2str(i)];
    CellInfo.(TrapCentreStrings{i})= zeros(1,2);
    TransformedImageStrings{i} = ['TransformedImage' int2str(i)];
    CellInfo.(TransformedImageStrings{i})= zeros(SubImageSize,SubImageSize);
    PriorRadiiStrings{i} = ['PriorRadii' int2str(i)];
    CellInfo.(PriorRadiiStrings{i}) = zeros(1,OptPoints);
    PriorAnglesStrings{i} = ['PriorAngles' int2str(i)];
    CellInfo.(PriorAnglesStrings{i}) = zeros(1,OptPoints);
    CellNumberTimelapseStrings{i} = ['CellNumberTimelapse' int2str(i)];
    CellInfo.(CellNumberTimelapseStrings{i}) = 0;
    TimePointStrings{i} = ['Timepoint' int2str(i)];
    CellInfo.(TimePointStrings{i}) = 0;
    ExcludeImageStrings{i} = ['ExcludeImage' int2str(i)];
    CellInfo.(ExcludeImageStrings{i})= false(SubImageSize,SubImageSize);
end



InitialisedCellInfo = CellInfo;

CellInfo(1:CellPreallocationNumber) = InitialisedCellInfo;

EmptyCellEntries = true(1,CellPreallocationNumber);


%% set TP at which to start segmenting

% if the first timepoint is suppose to be fixed it should not be segmented,
% so segmenting should only happen at FirstTimepoint + slice_size, since
% this will be one timepoint after the condition that the slice is fully
% populated is met. Otherwise the segmentation will start at FirstTimepoint+slice_size - 1
% the first timepoint at which the slice is fully populated.
if FixFirstTimePointBoolean
    TPtoStartSegmenting = FirstTimepoint+slice_size;
else
    TPtoStartSegmenting = FirstTimepoint+slice_size - 1;
    
end

if do_gui
    if nargin<5|| isempty(CellsToUse)
        TrapsToCheck = ttacObject.TrapsToCheck(Timepoints(1));
    else
        TrapsToCheck = intersect(CellsToUse(:,1),ttacObject.TrapsToCheck(Timepoints(1)));
    end
    
    
    disp = cTrapDisplay(ttacObject.TimelapseTraps,[],[],ttacObject.Parameters.ActiveContour.ShowChannel,TrapsToCheck);
end



%% loop through the rest of the timepoints
for TP = Timepoints
    
    % every 10th timepoint, update the trapOutline. This should help adjust
    % for any stretching of the device over time or changes in the
    % refractive index caused by things like sorbitol
%     if rem(TP,10)==1
%         channelTrap=ttacObject.Parameters.ActiveContour.ShowChannel
%         temp_im=ttacObject.TimelapseTraps.returnTrapsTimepoint(channelTrap,TP);
%         newTrapOutline=ACTrapFunctions.make_trap_pixels_from_image(temp_im,ttacObject.Parameters,0,oldTrapIm);
%         ttacObject.cCellVision.cTrap.trapOutline=newTrapOutline;
%         
%         f2=fspecial('gaussian',8,5);
%         f3=fspecial('average',8);
%         f2=(f2+f3)/2;
%         ttacObject.makeTrapPixelImage(f2);
%     end
    
    tic;
    fprintf('timepoint %d \n',TP)
    
    UpdatedPreviousTimepoint = [CellInfo(:).UpdatedThisTimepoint];
    
    for CN = find((~UpdatedPreviousTimepoint) & (~EmptyCellEntries))
        %the indexing here is difficult to follow but the idea is that if
        %no cell is present at the previous timepoint but there is data in
        %the array we need to save the 'priors' since these will be our
        %best guess at the contour since we can't do anymore searches since
        %our data for this cell has run out. So we take the slices that
        %have not been segmented and saved but have been segmented as part
        %of the segmentation of earlier cells (RN's) and save them to the
        %appropriate timepoints (TP + RN -slice_size -1).
        
        
        %take cells which for which no cell was present at the previous
        %timepoint and makes the segmentation result the prior result for
        %all cells.
        if CellInfo(CN).TimePointsPresent>=slice_size
            %if this condition is not met it would not have been segmented
            %at all, then leave priors in place. unchanged.
            ToWrite = setdiff((1:slice_size-1),1:(mod(CellInfo(CN).TimePointsPresent+1-slice_size,keepers)));
        else
            ToWrite = (slice_size-CellInfo(CN).TimePointsPresent):(slice_size-1);
        end
        for RN = ToWrite
            %this is set_diff(all entries with priors, those already written to data structure by segmentation )
            
            %write the results to keep to the cTimelapse object
            ttacObject.WriteACResults(CellInfo(CN).(TimePointStrings{RN}),CellInfo(CN).TrapNumber,CellInfo(CN).(CellNumberTimelapseStrings{RN}),CellInfo(CN).(PriorRadiiStrings{RN}),CellInfo(CN).(PriorAnglesStrings{RN}))
        end

        CellInfo(CN) = InitialisedCellInfo;
        EmptyCellEntries(CN) = true;
    end
    %move data 'back in time' and update update info
    [CellInfo(UpdatedPreviousTimepoint).UpdatedThisTimepoint] = deal(false);
    for SN = 1:(slice_size-1)
        
        [CellInfo(UpdatedPreviousTimepoint).(CellCentreStrings{SN})] =deal(CellInfo(UpdatedPreviousTimepoint).(CellCentreStrings{SN+1}));
        [CellInfo(UpdatedPreviousTimepoint).(TrapCentreStrings{SN})] =deal(CellInfo(UpdatedPreviousTimepoint).(TrapCentreStrings{SN+1}));
        [CellInfo(UpdatedPreviousTimepoint).(TransformedImageStrings{SN})] =deal(CellInfo(UpdatedPreviousTimepoint).(TransformedImageStrings{SN+1}));
        [CellInfo(UpdatedPreviousTimepoint).(PriorRadiiStrings{SN})] = deal(CellInfo(UpdatedPreviousTimepoint).(PriorRadiiStrings{SN+1}));
        [CellInfo(UpdatedPreviousTimepoint).(PriorAnglesStrings{SN})] = deal(CellInfo(UpdatedPreviousTimepoint).(PriorAnglesStrings{SN+1}));
        [CellInfo(UpdatedPreviousTimepoint).(CellNumberTimelapseStrings{SN})] = deal(CellInfo(UpdatedPreviousTimepoint).(CellNumberTimelapseStrings{SN+1}));
        [CellInfo(UpdatedPreviousTimepoint).(TimePointStrings{SN})] = deal(CellInfo(UpdatedPreviousTimepoint).(TimePointStrings{SN+1}));
        [CellInfo(UpdatedPreviousTimepoint).(ExcludeImageStrings{SN})] =deal(CellInfo(UpdatedPreviousTimepoint).(ExcludeImageStrings{SN+1}));
        
    end
    
    
    
    NumberOfCellsUpdated = 0;
    %checksum =0;
    
    PreviousTrapNumbers = [CellInfo(:).TrapNumber];
    PreviousCellLabels = [CellInfo(:).CellLabel];
    
    
    if nargin<5 || isempty(CellsToUse)
        TrapsToCheck = ttacObject.TrapsToCheck(TP);
    else
        TrapsToCheck = intersect(CellsToUse(:,1),ttacObject.TrapsToCheck(TP))';
    end
    
    for TIi = 1:length(TrapsToCheck)
        TI = TrapsToCheck(TIi);
        
        if nargin<5 || isempty(CellsToUse) || size(CellsToUse,2)==1
            CellsToCheck = ttacObject.CellsToCheck(TP,TI);
        else
            CellsToCheck = find(ismember(ttacObject.ReturnLabel(TP,TI),CellsToUse(CellsToUse(:,1)==TI,2)));
        end
        
        %get the segcentresTrap to make exclude regions. Uses timelapse
        %specific stuff, may want to adjust if you want to keep it general.
        SegCentresTrap = full(ttacObject.TimelapseTraps.cTimepoint(TP).trapInfo(TI).segCenters);
        SegCentresTrap = bwlabel(SegCentresTrap);
        if ttacObject.TrapPresentBoolean
            SegCentresTrap(imerode(ttacObject.TrapImage,strel('disk',2))) = max(SegCentresTrap(:))+1;
        end
        
        for CI = CellsToCheck;
            %fprintf('timepoint %d; trap %d ; cell %d \n',TP,TI,CI)
            
            %if the cell was previously recorded, put it
            %there.Otherwise, put in an empty place
            CellEntry = find((PreviousTrapNumbers==TI) & (PreviousCellLabels==ttacObject.ReturnLabel(TP,TI,CI)));
            if isempty(CellEntry)
                CellEntry = find(EmptyCellEntries,1);
                
                %If there are no available cell entries left initialise a
                %whole new tranch of cell entries
                if isempty(CellEntry)
                    CellEntry = length(CellInfo)+1;
                    CellInfo((end+1):(end+CellPreallocationNumber)) = InitialisedCellInfo;
                    EmptyCellEntries = [EmptyCellEntries true(1,CellPreallocationNumber)];
                end
                
                % Properties only updated on the first occurrence of a cell
                
                CellInfo(CellEntry).CellNumber = CellEntry;
                CellInfo(CellEntry).TrapNumber = TI;
                CellInfo(CellEntry).CellLabel = ttacObject.ReturnLabel(TP,TI,CI);
                CellInfo(CellEntry).(PriorRadiiStrings{end}) = ttacObject.ReturnCellRadii(TP,TI,CI);%set prior to be the radus found by matt's hough transform
                CellInfo(CellEntry).(PriorAnglesStrings{end}) = ttacObject.ReturnCellAngles(TP,TI,CI);%set prior angles to be evenly spaced
                %it may seem strange that both these are only taken for the
                %first occurence of a cell. This is because the prior is
                %set to the segmentation result once the cells are
                %segmented and 'left behind' to be the prior for future
                %cells. May want to change this to be more sophisticated at
                %some point.
                
                EmptyCellEntries(CellEntry) = false;
                
            end
            
            
            % Properties updated on ever occurrence of a cell
            CellTrapCentre = ttacObject.ReturnCellCentreRelative(TP,TI,CI);
            CellInfo(CellEntry).(CellNumberTimelapseStrings{end}) = CI;
            CellInfo(CellEntry).(TimePointStrings{end}) = TP;
            CellInfo(CellEntry).(CellCentreStrings{end}) = ttacObject.ReturnCellCentreAbsolute(TP,TI,CI);
            CellInfo(CellEntry).(TrapCentreStrings{end}) = ttacObject.ReturnTrapCentre(TP,TI);
            CellInfo(CellEntry).TimePointsPresent = CellInfo(CellEntry).TimePointsPresent+1 ;
            CellInfo(CellEntry).UpdatedThisTimepoint = true;
            NumberOfCellsUpdated = NumberOfCellsUpdated+1;
            
            CellRegionLabel = SegCentresTrap(CellTrapCentre(2),CellTrapCentre(1));
            
            CellExcludeImage = SegCentresTrap;
            if CellRegionLabel~=0;
                CellExcludeImage(CellExcludeImage == CellRegionLabel) = 0;
            end
            CellExcludeImage = CellExcludeImage>0;
            CellInfo(CellEntry).(ExcludeImageStrings{end}) = ACBackGroundFunctions.get_cell_image(CellExcludeImage,...
                SubImageSize,...
                CellTrapCentre,...
                false);
        end   
        
        
    end
    
    %Get Subimages of Cells
    
    CellNumbers = find([CellInfo(:).UpdatedThisTimepoint]);
    
    if ~isempty(CellNumbers)
    
    ImageStack = ttacObject.ReturnTransformedImagesForSingleCell([CellInfo([CellInfo(:).UpdatedThisTimepoint]).(TimePointStrings{end})],[CellInfo([CellInfo(:).UpdatedThisTimepoint]).TrapNumber],[CellInfo([CellInfo(:).UpdatedThisTimepoint]).(CellNumberTimelapseStrings{end})]);
    
    
    
    %redistribute amongst data structure
    
    for CN = 1:NumberOfCellsUpdated
        CellInfo(CellNumbers(CN)).(TransformedImageStrings{end}) = ImageStack(:,:,CN);
    end
    end
    %% actually do the segmentation function
    
    %being segmented for the first time
    CellsToSegmentFirstTP = ...
        find([CellInfo(:).UpdatedThisTimepoint] & ([CellInfo(:).TimePointsPresent]==slice_size) );
    
    
    %cells that have been previously segmented and have a previous
    %timepoint to use
    CellsToSegmentPreviouslySegmented = ...
        find([CellInfo(:).UpdatedThisTimepoint] & ([CellInfo(:).TimePointsPresent]>slice_size) &(mod([CellInfo(:).TimePointsPresent]-slice_size,keepers)==0) );
    
    UsePreviousTimepoint = [false(size(CellsToSegmentFirstTP)) true(size(CellsToSegmentPreviouslySegmented))];
    
    CellsToSegment = [CellsToSegmentFirstTP CellsToSegmentPreviouslySegmented];
    
    RadiiResultsCellArray = cell(size(CellsToSegment));
    AnglesResultsCellArray = cell(size(CellsToSegment));
    
    TimePointsToWrite = zeros(keepers*length(CellsToSegment),1);
    TrapIndicesToWrite = TimePointsToWrite;
    CellIndicesToWrite = TimePointsToWrite;
    CellRadiiToWrite = zeros(size(TimePointsToWrite,1),OptPoints);
    AnglesToWrite = CellRadiiToWrite;
    
         %fprintf('change back to parfor!!!! - segmentconsecutiveTP\n\n')
    parfor CNi = 1:length(CellsToSegment)
        %divided loop into parallel slow part and relatively fast write
        %part.
        
        if TP>=TPtoStartSegmenting
            
            
            [TranformedImageStack,PriorRadiiStack,ExcludeStack] = getStacksFromCellInfo(CellInfo,PriorRadiiStrings,TransformedImageStrings,ExcludeImageStrings,CellsToSegment(CNi));
            
            if UsePreviousTimepoint(CNi)
                %do segmentation of previously segmented cell
                [RadiiResultsCellArray{CNi},AnglesResultsCellArray{CNi}] = ...
                    ACMethods.PSORadialTimeStack(TranformedImageStack,ACparameters,FauxCentersStack,PriorRadiiStack,CellInfo(CellsToSegment(CNi)).PreviousTimepointResult,ExcludeStack);
                
            else
                %do first timepoint segmentation - so no previous timepoint
                [RadiiResultsCellArray{CNi},AnglesResultsCellArray{CNi}] = ...
                    ACMethods.PSORadialTimeStack(TranformedImageStack,ACparameters,FauxCentersStack,PriorRadiiStack,[],ExcludeStack);
                
            end
            
            %put all radii in the CellInfoarray
        end
    end
    
    CellsWritten = 1;
    
    for CNi = 1:length(CellsToSegment)
        
        CN = CellsToSegment(CNi);
        
        if TP>=TPtoStartSegmenting
            for RN = 1:slice_size
                CellInfo(CN).(PriorRadiiStrings{RN}) = RadiiResultsCellArray{CNi}(RN,:);
                CellInfo(CN).(PriorAnglesStrings{RN}) = AnglesResultsCellArray{CNi}(RN,:);
            end
            
            %write results to keep to the timelapse object
            for RN = 1:keepers
                
                %write the results to keep (1:keepers) to the cTimelapse object
                %ttacObject.WriteACResults(CellInfo(CN).(TimePointStrings{RN}),CellInfo(CN).TrapNumber,CellInfo(CN).(CellNumberTimelapseStrings{RN}),CellInfo(CN).(PriorRadiiStrings{RN}),CellInfo(CN).(PriorAnglesStrings{RN}))
                
                TimePointsToWrite(CellsWritten) = CellInfo(CN).(TimePointStrings{RN});
                TrapIndicesToWrite(CellsWritten) = CellInfo(CN).TrapNumber;
                CellIndicesToWrite(CellsWritten) = CellInfo(CN).(CellNumberTimelapseStrings{RN});
                CellRadiiToWrite(CellsWritten,:) = RadiiResultsCellArray{CNi}(RN,:);
                AnglesToWrite(CellsWritten,:) = AnglesResultsCellArray{CNi}(RN,:);
                
                CellsWritten = CellsWritten+1;
                
                
                
            end
            
            CellInfo(CN).PreviousTimepointResult = RadiiResultsCellArray{CNi}(keepers,:);
            
            
        else
            
            CellInfo(CN).PreviousTimepointResult = CellInfo(CN).((PriorRadiiStrings{1}));
        end
    end
    
    %write results on mass
    if TP>=TPtoStartSegmenting && ~isempty(CellsToSegment)
        ttacObject.WriteACResults(TimePointsToWrite,TrapIndicesToWrite,CellIndicesToWrite,CellRadiiToWrite,AnglesToWrite)
    end
    
    
    
    TimeOfTimepoint = toc;
    
    if do_gui
    fprintf('timepoint analysed in %.2f seconds \n',TimeOfTimepoint);
    
    disp.slider.Value = TP;
    disp.slider_cb;
    pause(.1);
    end
    
    
end

if do_gui
    close(disp.figure);
end

%end of the timeperiod to be segmented.write remaining priors to the
%segmentation results.


for CN = find([CellInfo(:).UpdatedThisTimepoint])
    
    %take cells which for which no cell was present at the previous
    %timepoint and makes the segmentation result the prior result for
    %all cells.
    
    if CellInfo(CN).TimePointsPresent>=slice_size
        %if this condition is not met it would not have been segmented
        %at all, then leave priors in place. unchanged.
        ToWrite = setdiff((1:slice_size),1:(mod(CellInfo(CN).TimePointsPresent-slice_size,keepers+1)));
    else
        ToWrite = (slice_size+1-CellInfo(CN).TimePointsPresent):(slice_size);
    end
    
    for RN = ToWrite%setdiff((1:slice_size),1:(mod(CellInfo(CN).TimePointsPresent-slice_size,keepers+1)))
        
        %write the results to keep (1:keepers) to the cTimelapse object
        
        ttacObject.WriteACResults(CellInfo(CN).(TimePointStrings{RN}),CellInfo(CN).TrapNumber,CellInfo(CN).(CellNumberTimelapseStrings{RN}),CellInfo(CN).(PriorRadiiStrings{RN}),CellInfo(CN).(PriorAnglesStrings{RN}))
        
    end
    
    
    CellInfo(CN) = InitialisedCellInfo;
    EmptyCellEntries(CN) = true;
end

end

function [TranformedImageStack,priorRadiiStack,ExcludeImageStack] = getStacksFromCellInfo(CellInfo,PriorRadiiStrings,TransformedImageStrings,ExcludeImageStrings,CN)
%function [TranformedImageStack,priorRadiiStack] = getStacksFromCellInfo(cellInfo,PriorRadiiStrings,TransformedImageStrings,CN);

%small function to get the info out of CellInfo and into a stack as the
%optimiser wants it.
L = size(PriorRadiiStrings,2);

TranformedImageStack = zeros([size(CellInfo(CN).(TransformedImageStrings{1})) L]);
priorRadiiStack = zeros([L,size(CellInfo(CN).(PriorRadiiStrings{1}),2)]);
ExcludeImageStack = false([size(CellInfo(CN).(ExcludeImageStrings{1})) L]);
for i=1:L
    TranformedImageStack(:,:,i) = CellInfo(CN).(TransformedImageStrings{i});
    priorRadiiStack(i,:) = CellInfo(CN).(PriorRadiiStrings{i});
    ExcludeImageStack(:,:,i) = CellInfo(CN).(ExcludeImageStrings{i});
end


end
