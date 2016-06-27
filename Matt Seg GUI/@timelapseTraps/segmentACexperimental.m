function segmentACexperimental(cTimelapse,cCellVision,FirstTimepoint,LastTimepoint,FixFirstTimePointBoolean,TrapsToUse)
%segmentACexperimental(cTimelapse,FirstTimepoint,LastTimepoint,FixFirstTimePointBoolean,CellsToUse)
%
%Complete segmentation function that uses the cCellVision and cross correlation to find images of
%cells and performs the active contour to get the edges.
%
%not yet parallelised
%
%   INPUTS
% FirstTimepoint    - time point at which to start
% LastTimepoint     - and to end
% FixFirstTimePoint - optional : if this is true the software will not alter the first timepoint
%                     but will still use the information in finding cells.
% CellsToUse        - optional (array) of type [trapIndex cellLabel]
%                     specifying which cells should be
%                     segmented. can also just be the
%                     column vector [trapIndex] - currently only this
%                     second form works.
%
%
%outline
%
% loop timepoints:
%     loop traps:
%         cross correlate all cells in trap at previous timepoint
%         loop:
%             get max above threshold
%             make that centre of that cell at the new timepoint
%             do active contour
%             set those pixels to -Inf in cross correlation
%         get d_im
%         set all cell and trap pixels to Inf
%         loop:
%             find max below two stage threshold
%             Set as centre
%             give new cell label and do active contour
%
% has cTimelapse referecences - remove later if necessary





if nargin<3 || isempty(FirstTimepoint)
    
    FirstTimepoint = min(cTimelapse.timepointsToProcess(:));
    
end

if nargin<4 || isempty(LastTimepoint)
    
    LastTimepoint = max(cTimelapse.timepointsToProcess);
    
end

if nargin<5
    
    FixFirstTimePointBoolean = false;
    
end

if nargin<6|| isempty(TrapsToUse)
    TrapsToCheck = cTimelapse.defaultTrapIndices;
else
    TrapsToCheck = intersect(TrapsToUse(:,1),cTimelapse.defaultTrapIndices)';
end


ACparameters = cTimelapse.ACParams.ActiveContour;
SubImageSize = cTimelapse.ACParams.ImageSegmentation.SubImageSize;%61;

ProspectiveImageSize =cTimelapse.ACParams.CrossCorrelation.ProspectiveImageSize;% 81; %image which will be searched for next cell
CrossCorrelationChannel = cTimelapse.ACParams.CrossCorrelation.CrossCorrelationChannel; % 2; %cTimelapse.ACParams.ImageTransformation.channel;
CrossCorrelationValueThreshold = cTimelapse.ACParams.CrossCorrelation.CrossCorrelationValueThreshold; %0.5; % value normalised cross correlation must be above to consitute continuation of cell from previous timepoint
CrossCorrelationDIMthreshold = cTimelapse.ACParams.CrossCorrelation.CrossCorrelationDIMthreshold;%  -0.3; %decision image threshold above which cross correlated cells are not considered to be possible cells
PostCellIdentificationDilateValue = cTimelapse.ACParams.CrossCorrelation.PostCellIdentificationDilateValue;% 2; %dilation applied to the cell outline to rule out new cell centres


RadMeans = (cTimelapse.ACParams.ActiveContour.R_min:cTimelapse.ACParams.ActiveContour.R_max)';%(2:15)';
RadRanges = [RadMeans-0.5 RadMeans+0.5];

TwoStageThreshold = cTimelapse.ACParams.CrossCorrelation.twoStageThresh; % boundary in decision image for new cells negative is stricter, positive more lenient

TrapPixExcludeThreshCentre = cTimelapse.ACParams.CrossCorrelation.TrapPixExcludeThreshCentre;%0.5; %pixels which cannot be classified as centres
TrapPixExcludeThreshAC = cTimelapse.ACParams.ActiveContour.TrapPixExcludeThreshAC;% 1; %trap pixels which will not be allowed within active contour areas
CellPixExcludeThresh = cTimelapse.ACParams.ActiveContour.CellPixExcludeThresh; %0.8; %bwdist value of cell pixels which will not be allowed in the cell area (so inner (1-cellPixExcludeThresh) fraction will be ruled out of future other cell areas)

% cross correlation prior constructed from two parts:
% a tight gaussian gaussian centered at the center spot (width JumpSize1)
% a broader gaussian constrained to not go beyond front of the cell (width JumpSize2, truncated at JumpSize1)


%object to provide priors for cell movement based on position and location.
CrossCorrelationPriorObject = ACMotionPriorObjects.FlowInTrap(cTimelapse,cCellVision);

PerformRegistration = cTimelapse.ACParams.CrossCorrelation.PerformRegistration;%true; %registers images and uses this to inform expected position. Useful in cases of big jumps like cycloheximide data sets.
MaxRegistration = cTimelapse.ACParams.CrossCorrelation.MaxRegistration;%50; %maximum allowed jump

if cTimelapse.trapsPresent
    PerformRegistration = false; %registration should be covered by tracking in the traps.
end

Recentering =false; %recalcluate the centre of the cells each time as the average ofthe outline


%multiplier od decision image added to Transformed image.
DIMproportion = 0.2;
%CrossCorrelationPrior = CrossCorrelationPrior./max(CrossCorrelationPrior(:));

%for debugging
%CrossCorrelationPrior = ones(ProspectiveImageSize,ProspectiveImageSize);

%variable assignments,mostly for convenience and parallelising.
ImageSize = cTimelapse.imSize;
TrapPresentBoolean = cTimelapse.trapsPresent;
TransformParameters = cTimelapse.ACParams.ImageTransformation.TransformParameters;
TrapImageSize = cTimelapse.trapImSize;

ImageTransformFunction = str2func(['ACImageTransformations.' cTimelapse.ACParams.ImageTransformation.ImageTransformFunction]);

if TrapPresentBoolean
    TrapWidth = cTimelapse.cTrapSize.bb_width;
    TrapHeight = cTimelapse.cTrapSize.bb_height;
end

NewCellStruct = cTimelapse.cellInfoTemplate;


%FauxCentersStack is just a filler for the PSO optimisation that takes centers
%(because in this code the centers are always at the centers of the image).
%Better to assign it here than every time in the loop.
FauxCentersStack = round(SubImageSize/2)*ones(1,2);

Timepoints = FirstTimepoint:LastTimepoint;


%% set TP at which to start segmenting

% if the first timepoint is suppose to be fixed it should not be segmented,
% so segmenting should only happen at FirstTimepoint + 1
if FixFirstTimePointBoolean
    TPtoStartSegmenting = FirstTimepoint+1;
else
    TPtoStartSegmenting = FirstTimepoint;
    
end


PreviousWholeImage = [];
PreviousTrapLocations = [];
PreviousTrapInfo = [];


%visualising trackin

if cTimelapse.ACParams.ActiveContour.visualise>2;
    cc_gui = GenericStackViewingGUI;
end


%array to hold the maximum label used in each trap
if TPtoStartSegmenting == cTimelapse.timepointsToProcess(1)
    TrapMaxCell = zeros(1,length(cTimelapse.defaultTrapIndices));
else
    TrapMaxCell = cTimelapse.returnMaxCellLabel([],1:(TPtoStartSegmenting-1));
end


disp = cTrapDisplay(cTimelapse,[],[],cTimelapse.ACParams.ActiveContour.ShowChannel,TrapsToCheck);

% gui\s for visualising outputs if that is desired.
if ACparameters.visualise>1
    guiDI = GenericStackViewingGUI;
    guiTransformed = GenericStackViewingGUI;
    guiOutline = GenericStackViewingGUI;
    guiTrapIM = GenericStackViewingGUI;
end

% active contour code throws errors if asked to visualise in the parfor
% loop.
ACparametersPass = ACparameters;
ACparametersPass.visualise = 0;


%% loop through timepoints
for TP = Timepoints
    tic;
    fprintf('timepoint %d \n',TP)
    
    WholeImage = [];
    for chi = 1:length(CrossCorrelationChannel)
        if chi==1
            WholeImage =sign(CrossCorrelationChannel(chi)) * double(cTimelapse.returnSingleTimepoint(TP,abs(CrossCorrelationChannel(chi))));
        else
            WholeImage = WholeImage  + sign(CrossCorrelationChannel(chi)) * double(cTimelapse.returnSingleTimepoint(TP,abs(CrossCorrelationChannel(chi))));
            
        end
    end
    WholeImage = IMnormalise(WholeImage);
    
    if TrapPresentBoolean
        WholeTrapImage = cTimelapse.returnWholeTrapImage(cCellVision, TP);
    else
        WholeTrapImage = zeros([size(WholeImage,1) size(WholeImage,2)]);
    end
    
    ACImageChannel = cTimelapse.ACParams.ImageTransformation.channel;
    
    for chi = 1:length(ACImageChannel)
        if chi==1
            ACImage =sign(ACImageChannel(chi)) * double(cTimelapse.returnSingleTimepoint(TP,abs(ACImageChannel(chi))));
        else
            ACImage = ACImage  + sign(ACImageChannel(chi)) * double(cTimelapse.returnSingleTimepoint(TP,abs(ACImageChannel(chi))));
            
        end
    end
    
    ACImage = IMnormalise(ACImage);
    
    TrapLocations = cTimelapse.cTimepoint(TP).trapLocations;
    
    %Elco - currently unused but left in since I might come back to it.
    if TrapPresentBoolean
        %[~,WholeImageElcoHough] = ElcoImageFilter(WholeImage,RadRanges,CrossCorrelationGradThresh,-1,WholeTrapImage>CrossCorrelationTrapThreshold,false);
        WholeImageElcoHough = repmat(WholeImage,[1 1 length(RadRanges)]);
    else
        %[~,WholeImageElcoHough] = ElcoImageFilter(WholeImage,RadRanges,CrossCorrelationGradThresh,-1,[],false);
        WholeImageElcoHough = repmat(WholeImage,[1 1 length(RadRanges)]);
    end
    WholeImageElcoHoughSum = sqrt(sum(WholeImageElcoHough.^2,3));
    WholeImageElcoHoughSum(WholeImageElcoHoughSum==0) = 1;
    WholeImageElcoHoughNormalised = WholeImageElcoHough./repmat(WholeImageElcoHoughSum,[1 1 size(WholeImageElcoHough,3)]);
    
    if TP>= TPtoStartSegmenting;
        
        %get decision image for each trap from SVM
        %If the traps have not been previously segmented this also initialises the trapInfo field
        
        TrapInfo = cTimelapse.cTimepoint(TP).trapInfo;
        
        % this calculates the decision image and also sets the trapInfo to
        % be empty - removing any cell information previously contained.
        [DecisionImageStack, EdgeImage] = identifyCellCentersTrap(cTimelapse,cCellVision,TP,TrapsToCheck,[],[]);
        
        TransformedImagesVIS = cell(length(TrapInfo));
        OutlinesVIS = TransformedImagesVIS;
        if ACparameters.visualise>1
            DecisionImageStackVIS = DecisionImageStack;
        end
        
        % stored to add to forcing image later
        NormalisedDecisionImageStack = DecisionImageStack/iqr(DecisionImageStack(:));
        
        
        %for holding trap images of trap pixels.
        TrapTrapImageStack = zeros(size(DecisionImageStack));
        
        WholeImageElcoHoughMedians = zeros(1,size(WholeImageElcoHough,3));
        
        for slicei = 1:size(WholeImageElcoHough,3)
            tempIm = WholeImageElcoHough(:,:,slicei);
            WholeImageElcoHoughMedians(slicei) = median(tempIm(:));
        end
        
        CrossCorrelating = false(size(TrapsToCheck));
        
        PredictedCellLocationsAllCells = cell(size(TrapsToCheck));
        
        reg_result = [0 0];
        
        for TI = 1:length(TrapsToCheck)
            %fprintf('%d,trap\n',TI)
            trap = TrapsToCheck(TI);
            CurrentTrapInfo = TrapInfo(trap);
            TrapDecisionImage = DecisionImageStack(:,:,TI);
            
            %             %might need to do something about this
            %             if isempty(CurrentTrapInfo)
            %             end
            if TP>FirstTimepoint
                PreviousCurrentTrapInfo = PreviousTrapInfo(trap);
            end
            
            if TP>FirstTimepoint && (PreviousCurrentTrapInfo.cellsPresent) && ~isinf(CrossCorrelationValueThreshold) && ~isempty(PreviousCurrentTrapInfo.cell(1).cellCenter)
                
                %register images and use to inform expeted position
                if PerformRegistration
                    reg_result = FindRegistrationForImageStack(cat(3,PreviousWholeImage,WholeImage),1,MaxRegistration);
                    reg_result = fliplr(reg_result(2,:));
                    %this is no the shift required in the current image -
                    % [x y] after fliplr - to make it match up with the
                    % Previous timepoint image, so is later subtracted from
                    % the expected position to get a better expected
                    % position estimate.
                else
                    reg_result = [0 0];
                    %needs to be initialised for parpool
                end
                
                
                PredictedCellLocationsAllCells{TI} = -2*abs(CrossCorrelationValueThreshold)*ones(TrapImageSize(1),TrapImageSize(2),length(PreviousCurrentTrapInfo.cell));
                if TI==1 && cTimelapse.ACParams.ActiveContour.visualise>2;
                    cc_gui.stack = cat(3,WholeImageElcoHough,WholeImage);
                    cc_gui.LaunchGUI;
                    pause
                end
                
                %fprintf('minimum of decision image : %f\n',min(TrapDecisionImage(:)));
                ExpectedCellCentres = [];
                for CI = 1:length(PreviousCurrentTrapInfo.cell)
                    
                    %ugly piece of code. If a cells is added by hand (not
                    %by this program) it has no cell label. This if
                    %statement is suppose to give it a cellLabel and
                    %thereby prevent errors down the line. Hasto adjust the
                    %trapMaxTP fields, which may cause problems.
                    if CI>length(PreviousCurrentTrapInfo.cellLabel)
                        cTimelapse.cTimepoint(TP).trapInfo(trap).cellLabel(CI) = cTimelapse.returnMaxCellLabel(trap)+1;
                        cTimelapse.cTimepoint(cTimelapse.timepointsToProcess(1)).trapMaxCell(trap) = cTimelapse.returnMaxCellLabel(trap);
                    end
                    
                    if isfield(PreviousCurrentTrapInfo.cell(CI),'ExpectedCentre')
                        LocalExpectedCellCentre = PreviousCurrentTrapInfo.cell(CI).ExpectedCentre;
                    else
                        LocalExpectedCellCentre = PreviousCurrentTrapInfo.cell(CI).cellCenter;
                    end
                    
                    if PerformRegistration
                        LocalExpectedCellCentre = LocalExpectedCellCentre - reg_result;
                    end
                    
                    if TrapPresentBoolean
                        ExpectedCellCentre = LocalExpectedCellCentre + [TrapLocations(trap).xcenter TrapLocations(trap).ycenter] - ([TrapWidth TrapHeight] + 1) ;
                    else
                        ExpectedCellCentre = LocalExpectedCellCentre;
                    end
                    
                    %botch fix for error over Exzpected centre being out of
                    %range
                    if ExpectedCellCentre(1)>size(WholeImageElcoHough,2);%ttacObject.ImageSize(1)
                        ExpectedCellCentre(1) = size(WholeImageElcoHough,2);%ttacObject.ImageSize(1);
                    end
                    
                    if ExpectedCellCentre(1)<1;
                        ExpectedCellCentre(1) = 1;
                    end
                    
                    if ExpectedCellCentre(2)>size(WholeImageElcoHough,1);%ttacObject.ImageSize(2)
                        ExpectedCellCentre(2) = size(WholeImageElcoHough,1);%ttacObject.ImageSize(2);
                    end
                    
                    if ExpectedCellCentre(2)<1;
                        ExpectedCellCentre(2) = 1;
                    end
                    
                    if ~isfield(PreviousCurrentTrapInfo.cell(CI),'cellRadii')
                        CellRadii = PreviousCurrentTrapInfo.cell(CI).cellRadius;
                    else
                        CellRadii = PreviousCurrentTrapInfo.cell(CI).cellRadii;
                    end
                    
                    CellCorrelationVector = PreviousCurrentTrapInfo.cell(CI).CorrelationVector;
                    
                    PredictedCellLocation = zeros(ProspectiveImageSize,ProspectiveImageSize);
                    
                    CrossCorrelationMethod = 'just_DIM';
                    
                    switch CrossCorrelationMethod
                        case 'just_DIM'
                            %decision image is negative where cells are
                            %likely to be, so take the negative.
                            PredictedCellLocation = -ACBackGroundFunctions.get_cell_image(TrapDecisionImage,...
                                ProspectiveImageSize,...
                                LocalExpectedCellCentre,...
                                Inf);
                        case 'new_elco'
                            ProspectiveImageHoughStack = GetSubStack(WholeImageElcoHoughNormalised,...
                                round(fliplr(ExpectedCellCentre)),...
                                ProspectiveImageSize*[1 1 ]);
                            ProspectiveImageHoughStack = ProspectiveImageHoughStack{1};
                            
                            ReshapedProspectiveImageHoughStack = reshape(shiftdim(ProspectiveImageHoughStack,2),[size(ProspectiveImageHoughStack,3),(numel(ProspectiveImageHoughStack)/size(ProspectiveImageHoughStack,3))]);
                            PredictedCellLocation = reshape(CellCorrelationVector'*ReshapedProspectiveImageHoughStack,[size(ProspectiveImageHoughStack,1) size(ProspectiveImageHoughStack,2)]);
                            
                            
                        case 'old elco'
                            for CellRadius = CellRadii
                                [~,BestFit] = sort(abs(RadMeans-CellRadius),1,'ascend');
                                BestFit = BestFit(1)';%BestFit = BestFit(1:2)';
                                for BestFiti = BestFit
                                    PredictedCellLocation = PredictedCellLocation + ACBackGroundFunctions.get_cell_image(WholeImageElcoHough(:,:,BestFiti),...
                                        ProspectiveImageSize,...
                                        ExpectedCellCentre,...
                                        WholeImageElcoHoughMedians(BestFiti));
                                    %multiplication by Radmeans added because it seems like the
                                    %transformation procedure gave higher values for smaller radii - so
                                    %this should balance that.
                                end
                            end
                    end
                    
                    % apply 'movement prior' provided by MotionPrior oject
                    PredictedCellLocation = CrossCorrelationPriorObject.returnPrior(LocalExpectedCellCentre,mean(CellRadii)).*PredictedCellLocation;
                    
                    %this for loop might seem somewhat strange and
                    %unecessary, but it is to deal with the 'TrapImage'
                    %being the whole image and therefore not necessarily an
                    %odd number in size.
                    if TrapPresentBoolean
                        temp_im = ACBackGroundFunctions.get_cell_image(PredictedCellLocation,...
                            TrapImageSize,...
                            (ceil(ProspectiveImageSize/2)*[1 1] + ceil(fliplr(TrapImageSize)/2)) - LocalExpectedCellCentre,...
                            -2*abs(CrossCorrelationValueThreshold) );
                        
                        % set those pixels above the more lenient decision
                        % image threshold to a value for which they will
                        % never be identified as cells.
                        temp_im(TrapDecisionImage>CrossCorrelationDIMthreshold)  = -2*abs(CrossCorrelationValueThreshold);
                        PredictedCellLocationsAllCells{TI}(:,:,CI) = temp_im;
                    else
                        
                        temp_im = (ACBackGroundFunctions.put_cell_image(PredictedCellLocationsAllCells{TI}(:,:,CI),PredictedCellLocation,ExpectedCellCentre)).*(TrapDecisionImage<CrossCorrelationDIMthreshold);
                        temp_im(TrapDecisionImage>CrossCorrelationDIMthreshold)  = -2*abs(CrossCorrelationValueThreshold);
                        PredictedCellLocationsAllCells{TI}(:,:,CI) = temp_im;
                    end
                    
                    
                    
                    %for debug
                    %ExpectedCellCentres = [ExpectedCellCentres;ExpectedCellCentre];
                    
                end
                
                
                %store image for visualisation
                if  cTimelapse.ACParams.ActiveContour.visualise > 0
                    PredictedCellLocationsAllCellsToView = PredictedCellLocationsAllCells{TI};
                    
                end
                
                if  cTimelapse.ACParams.ActiveContour.visualise>4;
                    cc_gui.stack = cat(3,PredictedCellLocationsAllCellsToView,TrapDecisionImage);
                    cc_gui.LaunchGUI;
                    pause
                    close(cc_gui.FigureHandle);
                end
                
                
                CrossCorrelating(TI) = true;
            else
                CrossCorrelating(TI) = false;
                
            end %if timepoint> FirstTimepoint
            
            if TrapPresentBoolean
                TrapTrapImage = ACBackGroundFunctions.get_cell_image(WholeTrapImage,...
                    TrapImageSize,...
                    [TrapLocations(trap).xcenter TrapLocations(trap).ycenter],...
                    0 ) ;
                TrapTrapImageStack(:,:,TI) = TrapTrapImage;
                
                TrapTrapLogical = TrapTrapImage > TrapPixExcludeThreshCentre;
                if CrossCorrelating(TI)
                    PredictedCellLocationsAllCells{TI}(repmat(TrapTrapLogical,[1,1,size(PredictedCellLocationsAllCells{TI},3)])) = -2*abs(CrossCorrelationValueThreshold);
                    
                end
                TrapDecisionImage(TrapTrapLogical) = 2*abs(TwoStageThreshold);
                DecisionImageStack(:,:,TI) = TrapDecisionImage;
            else
                TrapTrapLogical = false(TrapImageSize);
                TrapTrapImageStack = zeros([TrapImageSize length(TrapsToCheck)]);
                
            end
            
            
        end
        
        %begin prep for parallelised slow section
        
        SliceableTrapInfo = TrapInfo(TrapsToCheck);
        SliceableTrapInfoToWrite = SliceableTrapInfo;
        if TP>FirstTimepoint
            SliceablePreviousTrapInfo = PreviousTrapInfo(TrapsToCheck);
        else
            SliceablePreviousTrapInfo = ones(size(CrossCorrelating));
        end
        
        SliceableTrapLocations = TrapLocations(TrapsToCheck);
        SliceableTrapMaxCell = TrapMaxCell(TrapsToCheck);
        
        if TrapPresentBoolean
            ACTrapImageStack = ACBackGroundFunctions.get_cell_image(ACImage,...
                TrapImageSize,...
                [[SliceableTrapLocations(:).xcenter]' [SliceableTrapLocations(:).ycenter]']);
            
        else
            ACTrapImageStack = ACImage;
        end
        %parfor actually looking for cells
        %fprintf('CHANGE BACK TO PARFOR IN SegmentConsecutiveTimepointsCrossCorrelationParallel\n')
        parfor TI = 1:length(TrapsToCheck)
            
            PreviousCurrentTrapInfo = [];
            if CrossCorrelating(TI)
                PreviousCurrentTrapInfo = SliceablePreviousTrapInfo(TI);
            end
            
            TrapDecisionImage = DecisionImageStack(:,:,TI);
            NormalisedTrapDecisionImage = NormalisedDecisionImageStack(:,:,TI);
            TrapTrapImage = TrapTrapImageStack(:,:,TI);
            
            NormalisedTrapDecisionImage(TrapTrapImage>0) = TwoStageThreshold;
            
            NormalisedTrapDecisionImage = -NormalisedTrapDecisionImage;
            
            ParCurrentTrapInfo = SliceableTrapInfo(TI);
            
            NotCells = TrapTrapLogical;
            AllCellPixels = zeros(size(NotCells));
            
            ACTrapImage = ACTrapImageStack(:,:,TI);
            
            CellSearch = true;
            ProceedWithCell = false;
            NCI = 0;
            NewCells = [];
            OldCells = [];
            NewCrossCorrelatedCells = [];
            ParCurrentTrapInfo.cell = NewCellStruct;
            ParCurrentTrapInfo.cellsPresent = false;
            ParCurrentTrapInfo.cellLabel = [];
            value = 0;
            ynewcell = 0;
            xnewcell = 0;
            CellTrapImage = [];
            CIpar = [];
            
%             if  ACparameters.visualise >1
%                 TransformedImagesVISTrap = [];
%                 OutlinesVISTrap = [];
%             end
            
            %look for new cells
            while CellSearch
                
                if CrossCorrelating(TI)
                    %look for cells based on cross correlation with
                    %previous timepoint
                    [value,Index] = max(PredictedCellLocationsAllCells{TI}(:));
                    %[Index] = find(PredictedCellLocationsAllCells{TI}==value,1);
                    value = value(1);
                    Index = Index(1);
                    if value>CrossCorrelationValueThreshold
                        [ynewcell,xnewcell,CIpar] = ind2sub(size(PredictedCellLocationsAllCells{TI}),Index);
                        ProceedWithCell = true;
                    else
                        ProceedWithCell = false;
                        CrossCorrelating(TI) = false;
                    end
                end
                
                if ~CrossCorrelating(TI)
                    %look for cells based based on SVM decisions matrix
                    value = min(TrapDecisionImage(:));
                    [Index] = find(TrapDecisionImage==value,1);
                    if value<TwoStageThreshold
                        [ynewcell,xnewcell] = ind2sub(size(TrapDecisionImage),Index);
                        ProceedWithCell = true;
                    else
                        CellSearch = false;
                        ProceedWithCell = false;
                    end
                    
                    
                end
                
                if ProceedWithCell
                    
                    NCI = NCI+1;
                    
                    %write new cell info
                    ParCurrentTrapInfo.cell(NCI) = NewCellStruct;
                    
                    if CrossCorrelating(TI)
                        ParCurrentTrapInfo.cellLabel(NCI) = PreviousCurrentTrapInfo.cellLabel(CIpar);
                        OldCells = [OldCells CIpar];
                        NewCrossCorrelatedCells = [NewCrossCorrelatedCells NCI];
                    else
                        NewCells = [NewCells NCI];
                        ParCurrentTrapInfo.cellLabel(NCI) = SliceableTrapMaxCell(TI)+1;
                        SliceableTrapMaxCell(TI) = SliceableTrapMaxCell(TI)+1;

                    end
                    ParCurrentTrapInfo.cell(NCI).cellCenter = double([xnewcell ynewcell]);
                    ParCurrentTrapInfo.cellsPresent = true;
                    
                    
                    %do active contour
                    
                    NewCellCentre = [xnewcell ynewcell];
                    
                    
                    CellImage = ACBackGroundFunctions.get_cell_image(ACTrapImage,...
                        SubImageSize,...
                        NewCellCentre );
                    
                    NotCellsCell = ACBackGroundFunctions.get_cell_image(AllCellPixels,...
                        SubImageSize,...
                        [xnewcell ynewcell],...
                        false);
                    
                    
                    if TrapPresentBoolean
                        CellTrapImage = ACBackGroundFunctions.get_cell_image(TrapTrapImage,...
                            SubImageSize,...
                            NewCellCentre );
                        TransformedCellImage = ImageTransformFunction(CellImage,TransformParameters,CellTrapImage+NotCellsCell);
                        
                    else
                        TransformedCellImage = ImageTransformFunction(CellImage,TransformParameters,NotCellsCell);
                    end
                    
                    %COME BACK TO LATER. NEED TO DO THE TRAP REMOVAL AGAIN
                    %FOR THIS TO WORK
                    %%%%%%  cheeky little temporary addition - add a
                    %%%%%%  proportion of the cell image to the transformed
                    %%%%%%  image.
                    
                    CellDecisionImage = ACBackGroundFunctions.get_cell_image(NormalisedTrapDecisionImage,...
                        SubImageSize,...
                        NewCellCentre );
                    
                    %take cell decision image, isolate those parts which
                    %are above TwoStageThreshold(and therefore a partof
                    %cell centres) and add it to the TransformedCellImage,
                    %multiplying by the 75th percentile of the
                    %TransformedCellImage for scaling.
                    
                    TransformedCellImage = TransformedCellImage + DIMproportion*(CellDecisionImage*iqr(TransformedCellImage(:)));
                    %%%%
                    
                    if TrapPresentBoolean
                        %ExcludeLogical = (CellTrapImage>=TrapPixExcludeThreshAC) | (NotCellsCell>=CellPixExcludeThresh);
                        ExcludeLogical = (imerode(CellTrapImage>=TrapPixExcludeThreshAC,strel('disk',1),'same')| (NotCellsCell>=CellPixExcludeThresh));
                    else
                        ExcludeLogical = NotCellsCell>=CellPixExcludeThresh;
                    end
                    
                    if ~any(ExcludeLogical(:))
                        ExcludeLogical = [];
                    end
                    
                    if CrossCorrelating(TI)
                        PreviousTimepointRadii = PreviousCurrentTrapInfo.cell(CIpar).cellRadii;
                        
                        [RadiiResult,AnglesResult] = ...
                            ACMethods.PSORadialTimeStack(TransformedCellImage,ACparametersPass,FauxCentersStack,PreviousTimepointRadii,PreviousTimepointRadii,ExcludeLogical);
                    else
                        [RadiiResult,AnglesResult] = ...
                            ACMethods.PSORadialTimeStack(TransformedCellImage,ACparametersPass,FauxCentersStack,[],[],ExcludeLogical);
                        
                    end
                    %write active contour result and change cross
                    %correlation matrix and decision image.
                    
                    if Recentering
                        %somewhat crude, hope that it will keep cells
                        %reasonably centred.
                        [px,py] = ACBackGroundFunctions.get_full_points_from_radii(RadiiResult',AnglesResult',double(ParCurrentTrapInfo.cell(NCI).cellCenter),TrapImageSize);
                        
                        xnewcell = round(mean(px));
                        ynewcell = round(mean(py));
                        
                        ParCurrentTrapInfo.cell(NCI).cellCenter = double([xnewcell ynewcell]);
                        
                        SegmentationBinary = false(TrapImageSize);
                        SegmentationBinary(py+TrapImageSize(1,1)*(px-1))=true;
                        
                        RadiiResult = ACBackGroundFunctions.initialise_snake_radial(1*(~SegmentationBinary),OptPoints,xnewcell,ynewcell,ACparameters.R_min,ACparameters.R_max,[]);
                        RadiiResult = RadiiResult';
                    end
                    
                    ParCurrentTrapInfo.cell(NCI).cellRadii = RadiiResult;
                    ParCurrentTrapInfo.cell(NCI).cellAngle = AnglesResult;
                    ParCurrentTrapInfo.cell(NCI).cellRadius = mean(RadiiResult);
                    
                    [px,py] = ACBackGroundFunctions.get_full_points_from_radii(RadiiResult',AnglesResult',double(ParCurrentTrapInfo.cell(NCI).cellCenter),TrapImageSize);
                    
%                     if ACparameters.visualise>1
%                         
%                         TransformedImagesVISTrap = cat(3,TransformedImagesVISTrap,TransformedCellImage);
%                         [pxVIS,pyVIS] = ACBackGroundFunctions.get_full_points_from_radii(RadiiResult',AnglesResult',round(size(TransformedCellImage)/2),size(TransformedCellImage));
%                         SegmentationBinary = false(size(TransformedCellImage));
%                         SegmentationBinary(pyVIS+size(TransformedCellImage,1)*(pxVIS-1))=true;
%                         OutlinesVISTrap = cat(3,OutlinesVISTrap,SegmentationBinary);
%                         
%                     end
                    
                    SegmentationBinary = false(TrapImageSize);
                    SegmentationBinary(py+TrapImageSize(1,1)*(px-1))=true;
                    
                    
                    ParCurrentTrapInfo.cell(NCI).segmented = sparse(SegmentationBinary);
                    SegmentationBinary = imfill(SegmentationBinary,'holes');
                    DilateSegmentationBinary = imdilate(SegmentationBinary,strel('disk',PostCellIdentificationDilateValue),'same');
                    
                    if CrossCorrelating(TI)
                        %remove cell that has been successfully cross
                        %correlated from cross correlation matrix
                        PredictedCellLocationsAllCells{TI}(:,:,CIpar) = -2*abs(CrossCorrelationValueThreshold);
                        
                        %ensure no cells are found overlapping identified cell
                        %complicated line but makes list of indices of cell
                        %pixels. Saves significant time when using large
                        %images (i.e. when there are no traps).
                        pixels_to_remove = find(DilateSegmentationBinary);
                        all_pixels_to_remove = kron(ones(1,size(PredictedCellLocationsAllCells{TI},3)),pixels_to_remove') ...
                            + kron(((0:(size(PredictedCellLocationsAllCells{TI},3)-1))*size(PredictedCellLocationsAllCells{TI},1)*size(PredictedCellLocationsAllCells{TI},2)),ones(1,length(pixels_to_remove)));
                        PredictedCellLocationsAllCells{TI}(all_pixels_to_remove) = -2*abs(CrossCorrelationValueThreshold);
                        
                    end
                    %remove pixels identified as cell pixels from
                    %decision image
                    TrapDecisionImage(DilateSegmentationBinary) = 2*abs(TwoStageThreshold);
                    
                    
                    %update trap image so that it includes all
                    %segmented cells
                    NotCells = NotCells | SegmentationBinary;
                    EdgeConfidenceImage = bwdist(~SegmentationBinary);
                    EdgeConfidenceImage = EdgeConfidenceImage./max(EdgeConfidenceImage(:));
                    AllCellPixels = AllCellPixels + EdgeConfidenceImage;
                    
                end %if ProceedWithCell
                
            end %while cell search
            
%             if ACparameters.visualise>1
%                 
%                 OutlinesVIS{TI} = OutlinesVISTrap;
%                 TransformedImagesVIS{TI} = TransformedImagesVISTrap;
%                 
%             end
            
            %create this new variable for writing before adding superflous
            %rubbis to ParCurrenttrapInfo which is only used in
            %this function.
            SliceableTrapInfoToWrite(TI) = ParCurrentTrapInfo;
            
            %calculated expected CellCentre as the simple sum of current
            %location and distance moved in previous timepoint.
            %for new cells it is simply their current location
            for CI = 1:length(NewCrossCorrelatedCells);
                CellMove = (ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).cellCenter - PreviousCurrentTrapInfo.cell(OldCells(CI)).cellCenter);
                
                if PerformRegistration
                    % so as not to confuse jumps in registration (which
                    % will be added anyway) with cell specific movement.
                    CellMove = CellMove + reg_result;
                end
                if any(abs(CellMove)>4) || Recentering
                    %more than 4, probably a jump, cell movement not related to previous timepoint
                    %if recentering then cells jump around anyway.
                    CellMove = [0 0];
                end
                
                %didn't like cell move code anymore, temp fix
                
                CellMove = [0 0];
                
                %CellMove = sign(CellMove) .* min(abs(CellMove),[2 2]); %allow a predicted move of no more than two - stops crazy jumps
                ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre = ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).cellCenter + CellMove;
                if ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(1) > TrapImageSize(2);
                    ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(1) = TrapImageSize(2);
                elseif ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(1) < 1;
                    ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(1) = 1;
                end
                
                if ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(2) >TrapImageSize(1);
                    ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(2) = TrapImageSize(1);
                elseif ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(2) < 1;
                    ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).ExpectedCentre(2) = 1;
                end
                
                ParCurrentTrapInfo.cell(NewCrossCorrelatedCells(CI)).TPpresent = PreviousCurrentTrapInfo.cell(OldCells(CI)).TPpresent+1;
                
            end
            
            for CI = 1:length(NewCells);
                ParCurrentTrapInfo.cell(NewCells(CI)).ExpectedCentre = ParCurrentTrapInfo.cell(NewCells(CI)).cellCenter;
                ParCurrentTrapInfo.cell(NewCells(CI)).TPpresent = 1;
            end
            
            
            
            
            
            %write results to internal variables
            SliceableTrapInfo(TI) = ParCurrentTrapInfo;
            
            
            
            
        end %end traps loop
        
        TrapMaxCell(TrapsToCheck) = SliceableTrapMaxCell;
        
        %write results to cTimelapse
        cTimelapse.cTimepoint(TP).trapInfo(TrapsToCheck) = SliceableTrapInfoToWrite;
        cTimelapse.cTimepoint(cTimelapse.timepointsToProcess(1)).trapMaxCell = TrapMaxCell;
        cTimelapse.timepointsProcessed(TP) = true;
        
        TrapInfo(TrapsToCheck) = SliceableTrapInfo;
    else
        TrapInfo = cTimelapse.cTimepoint(TP).trapInfo;
    end
    
    for trapi = TrapsToCheck
        
        %fix later - just need to get absolute cell locations
        
        AbsoluteCellCentres = cTimelapse.returnCellCentresAbsolute(trapi,TP);
        for CI = 1:size(AbsoluteCellCentres,1)
            %this is a vector taken from the correlation image at the
            %current timepoint which will hopefully be very similar for
            %this same cells at the next timepoint.
            TrapInfo(trapi).cell(CI).CorrelationVector = squeeze(WholeImageElcoHoughNormalised(AbsoluteCellCentres(CI,2),AbsoluteCellCentres(CI,1),:));
        end
    end
    
    
    PreviousWholeImage = WholeImage;
    PreviousTrapInfo = TrapInfo;
    
    TimeOfTimepoint = toc;
    fprintf('timepoint analysed in %.2f seconds \n',TimeOfTimepoint);
    
    disp.slider.Value = TP;
    disp.slider_cb;
    if ACparameters.visualise>1
        OutlinesStack = [];
        TransformedImagesStack =[];
        for TI = 1:length(TrapInfo)
            OutlinesStack = cat(3,OutlinesStack,OutlinesVIS{TI});
            TransformedImagesStack = cat(3,TransformedImagesStack,TransformedImagesVIS{TI});
        end
        guiDI.stack = DecisionImageStack;
        guiDI.LaunchGUI;
        guiTransformed.stack = TransformedImagesStack;
        guiTransformed.LaunchGUI;
        guiOutline.stack = OutlinesStack;
        guiOutline.LaunchGUI;
        guiTrapIM.stack = cTimelapse.returnTrapsTimepoint(TrapsToCheck,TP,cTimelapse.ACParams.ActiveContour.ShowChannel);
        guiTrapIM.LaunchGUI;
        fprintf('press enter to continue . . . . \n')
        pause;
        
    end
    drawnow;
end %end TP loop

close(disp.figure);

end

function WholeImage = IMnormalise(WholeImage)

WholeImage = double(WholeImage);
WholeImage = WholeImage - median(WholeImage(:));
IQ = iqr(WholeImage(:));
if IQ>0
    WholeImage = WholeImage./iqr(WholeImage(:));
end

end

