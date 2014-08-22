function extractCellData(cTimelapse,type)

if nargin<2
    type='max';
end

numCells=sum(cTimelapse.cellsToPlot(:));
[trap cell]=find(cTimelapse.cellsToPlot);

s1=strel('disk',2);
% convMatrix2=single(getnhood(strel('disk',2)));


if isempty(cTimelapse.timepointsProcessed) || length(cTimelapse.timepointsProcessed)==1
    tempSize=[cTimelapse.cTimepoint.trapInfo];
    cTimelapse.timepointsProcessed=ones(1,length(tempSize)/length(cTimelapse.cTimepoint(1).trapInfo));
    if length(cTimelapse.timepointsProcessed)==1
        cTimelapse.timepointsProcessed=0;
    end
end

switch type
    case 'all'
        numStacks=3;
    case 'max'
        numStacks=1;
    case 'mean'
        numStacks=1;
    case 'std'
        numStacks=1;
end

for channel=1:length(cTimelapse.channelNames)
    if numStacks<2
        extractedData(channel).mean=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).median=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).max5=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).std=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).smallmean=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).smallmedian=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).smallmax5=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).min=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).imBackground=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).area=sparse(zeros(numCells,length(cTimelapse.cTimepoint)));
        extractedData(channel).radius=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).xloc=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).yloc=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).membraneMax5=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).membraneMedian=sparse(zeros(numCells,length(cTimelapse.timepointsProcessed)));
    else
        extractedData(channel).mean=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).median=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).max5=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).std=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).smallmean=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).smallmedian=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).smallmax5=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).min=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).imBackground=(zeros(numCells,length(cTimelapse.timepointsProcessed),numStacks));
        extractedData(channel).area=(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).radius=(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).xloc=(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).yloc=(zeros(numCells,length(cTimelapse.timepointsProcessed)));
        extractedData(channel).membraneMax5=zeros(numCells,length(cTimelapse.timepointsProcessed));
        extractedData(channel).membraneMedian=zeros(numCells,length(cTimelapse.timepointsProcessed));
    end
    
    
    
    for timepoint=1:length(cTimelapse.timepointsProcessed)
        if cTimelapse.timepointsProcessed(timepoint)
            disp(['Timepoint Number ',int2str(timepoint)]);
            %     uniqueTraps=unique(traps);
            %modify below code to use the cExperiment.searchString rather
            %than just channel=2;
            
            %             trapImages=cTimelapse.returnTrapsTimepoint(traps,timepoint,channel);
            
            tpStack=cTimelapse.returnSingleTimepoint(timepoint,channel,'stack');
            
            %             trapImagesStd=cTimelapse.returnTrapsTimepoint(traps,timepoint,channel,'std');
            %             trapImagesMean=cTimelapse.returnTrapsTimepoint(traps,timepoint,channel,'mean');
            
            
            trapInfo=cTimelapse.cTimepoint(timepoint).trapInfo;
            uniqueTraps=unique(trap);
            dataInd=0;
            for j=1:length(uniqueTraps)%j=1:length(extractedData(channel).cellNum)
                currTrap=uniqueTraps(j);% extractedData(channel).trapNum(j);
                
                %                 cellsCurrTrap=find(trap==currTrap);
                %                 cellsCurrTrap=cell(trap==currTrap);
                cellsCurrTrap=cell(trap==currTrap);
                %                 tempCells=[];
                %                 for tpCellInd=1:length(cellsCurrTrap)
                %                     cPresTp=find(cellsCurrTrap(tpCellInd)==trapInfo(currTrap).cellLabel, 1);
                %                     if ~isempty(cPresTp)
                %                         tempCells(end+1)=cellsCurrTrap(tpCellInd);
                %                     end
                %                 end
                %                 cellsCurrTrap=tempCells;
                
                if cTimelapse.trapsPresent
                    trapImages=returnTrapStack(cTimelapse,tpStack,currTrap,timepoint);
                else
                    trapImages=tpStack;
                end
                
                for cellIndex=1:length(cellsCurrTrap)
                    currCell=cellsCurrTrap(cellIndex);
                    temp_loc=find(trapInfo(currTrap).cellLabel==currCell);
                    
                    dataInd=dataInd+1;
                    if isempty(temp_loc)
                        %Do nothing 
                    else
                        
                        seg_areas=full(trapInfo(currTrap).cell(temp_loc).segmented);
                        segLabel=zeros(size(seg_areas));
                        loc=double(cTimelapse.cTimepoint(timepoint).trapInfo(currTrap).cell(temp_loc).cellCenter);
                        if ~isempty(loc)
                            %Generate second (outer) circle to ensure there are no gaps in the cell
                            rad=cTimelapse.cTimepoint(timepoint).trapInfo(currTrap).cell(temp_loc).cellRadius;
                            center=cTimelapse.cTimepoint(timepoint).trapInfo(currTrap).cell(temp_loc).cellCenter;
                            theta=0:0.01:2*pi;
                            coords=[double(center(2))+double(rad+1)*cos(theta); double(center(1))+double(rad+1)*sin(theta)];
                            innerline=zeros(size(seg_areas));
                            coords(coords<0)=1;
                            for i=1:length(coords(1,:))
                                innerline(ceil(coords(1,i)),ceil(coords(2,i)))=1;
                            end
                            innerline=innerline(1:length(seg_areas(1,:)),1:length(seg_areas(:,1))); %snip off the ends
                            seg_areas=seg_areas+innerline;

                            segLabel=imfill(seg_areas(:,:,1),'holes');%sub2ind(size(seg_areas(:,:,1)),loc(2),loc(1)));
                        end
                        %                 temp_im=trapInfo(currTrap).trackLabel==currCell;
                        cellLoc=segLabel>0;
                        
                        membraneLoc = seg_areas >0; 
                        
                        
                        
                        tStd=[];tMean=[];
                        for l=1:size(trapImages,3)
                            tempIm=double(trapImages(:,:,l));
                            tempIm=tempIm(cellLoc);
                            tStd(l)=std(tempIm(:));
                            tMean(l)=mean(tempIm(:));
                        end
                        [b indStd]=max(tStd);
                        [b indMean]=max(tMean);
                        
                        switch type
                            %                         case 'all'
                            %                             trapImWhole(:,:,1)=max(trapImages,[],3);
                            %                             trapImWhole(:,:,2)=trapImages(:,:,indStd);
                            %                             trapImWhole(:,:,3)=trapImages(:,:,indMean);
                            case 'max'
                                trapImWhole(:,:,1)=max(trapImages,[],3);
                            case 'std'
                                trapImWhole(:,:,1)=trapImages(:,:,indStd);
                            case 'mean'
                                trapImWhole(:,:,1)=trapImages(:,:,indMean);
                        end
                        
                        for k=1:size(trapImWhole,3)
                            trapIm=trapImWhole(:,:,k);
                            cellFL=trapIm(cellLoc);
                            
                            membraneFL = trapIm(membraneLoc); 
                            
                            %This is a silly debug to catch cells too small for
                            %a max5 calculation
                            if sum(cellLoc(:))>5
                                %below is the function to extract the fluorescence information
                                %from the cells. Change to mean/median FL etc
                                flsorted=sort(cellFL(:),'descend');
                                mflsorted=sort(membraneFL(:),'descend');
                                
                                convMatrix=zeros(3,3);
                                convMatrix(2,:)=1;convMatrix(:,2)=1;
                                %                 flPeak=conv2(single(trapIm),convMatrix);
                                %                 flPeak=flPeak(cellLoc);
                                if issparse(extractedData(channel).radius)
                                    extractedData(channel).area(dataInd,timepoint)=length(cellFL);
                                    extractedData(channel).max5(dataInd,timepoint)=mean(flsorted(1:5));
                                    extractedData(channel).mean(dataInd,timepoint)=mean(cellFL(:));
                                    extractedData(channel).median(dataInd,timepoint)=median(cellFL(:));
                                  
                                    extractedData(channel).membraneMedian(dataInd, timepoint)=median(membraneFL(:));
                                    extractedData(channel).membraneMax5(dataInd, timepoint)=mean(mflsorted(1:5));
                                    
                                    cellLocSmall=imerode(cellLoc,s1);
                                    if sum(cellLocSmall)<1
                                    end
                                    cellFLsmall=trapIm(cellLocSmall);
                                    flPeak=conv2(double(trapIm),convMatrix);
                                    flPeak=flPeak(cellLoc);
                                    
                                    extractedData(channel).smallmax5(dataInd,timepoint)=max(flPeak(:));
                                    extractedData(channel).smallmean(dataInd,timepoint)=mean(cellFLsmall(:));
                                    extractedData(channel).smallmedian(dataInd,timepoint)=median(cellFLsmall(:));
                                    
                                    seg_areas=zeros(size(trapInfo(currTrap).cell(1).segmented));
                                    for allCells=1:length(trapInfo(currTrap).cellLabel)
                                        seg_areas=seg_areas|full(trapInfo(currTrap).cell(allCells).segmented);
                                        %                         seg_areas=imdilate(seg_areas,s1);
                                        loc=double(cTimelapse.cTimepoint(timepoint).trapInfo(currTrap).cell(allCells).cellCenter);
                                        if ~isempty(loc)
                                            seg_areas=imfill(seg_areas(:,:,1),'holes');%sub2ind(size(seg_areas(:,:,1))loc(2),loc(1)));
                                        end
                                    end
                                    %                     seg_areas=imdilate(seg_areas,s1);
                                    seg_areas=~seg_areas;
                                    
                                    bkg=trapIm(seg_areas);
                                    bkg=bkg(~isnan(bkg(:)));
                                    if isempty(bkg)
                                        bkg=trapIm;
                                    end
                                    extractedData(channel).std(dataInd,timepoint)=std(double(cellFL(:)));
                                    extractedData(channel).imBackground(dataInd,timepoint)=median(bkg(:));
                                    extractedData(channel).min(dataInd,timepoint)=min(cellFL(:));
                                    extractedData(channel).radius(dataInd,timepoint)= sqrt(sum(sum(imfill(full(trapInfo(currTrap).cell(temp_loc).segmented),'holes')))/pi);%trapInfo(currTrap).cell(temp_loc).cellRadius;
                                    extractedData(channel).xloc(dataInd,timepoint)= trapInfo(currTrap).cell(temp_loc).cellCenter(1);
                                    extractedData(channel).yloc(dataInd,timepoint)=trapInfo(currTrap).cell(temp_loc).cellCenter(2);
                                    
                                    extractedData(channel).trapNum(dataInd)=currTrap;
                                    extractedData(channel).cellNum(dataInd)=currCell;
                                    
                                else
                                    extractedData(channel).area(dataInd,timepoint,k)=length(cellFL);
                                    extractedData(channel).max5(dataInd,timepoint,k)=mean(flsorted(1:5));
                                    extractedData(channel).mean(dataInd,timepoint,k)=mean(cellFL(:));
                                    extractedData(channel).median(dataInd,timepoint,k)=median(cellFL(:));
                                    
                                    
                                    extractedData(channel).membraneMedian(dataInd, timepoint)=median(membraneFL(:));
                                    extractedData(channel).membraneMax5(dataInd, timepoint)=mean(mflsorted(1:5));
                                    
                                    cellLocSmall=imerode(cellLoc,s1);
                                    if sum(cellLocSmall)<1
                                    end
                                    
                                    cellFLsmall=trapIm(cellLocSmall);
                                    flPeak=conv2(double(trapIm),convMatrix);
                                    flPeak=flPeak(cellLoc);
                                    
                                    extractedData(channel).smallmax5(dataInd,timepoint,k)=max(flPeak(:));
                                    extractedData(channel).smallmean(dataInd,timepoint,k)=mean(cellFLsmall(:));
                                    extractedData(channel).smallmedian(dataInd,timepoint,k)=median(cellFLsmall(:));
                                    
                                    seg_areas=zeros(size(trapInfo(currTrap).cell(1).segmented));
                                    for allCells=1:length(trapInfo(currTrap).cellLabel)
                                        seg_areas=seg_areas|full(trapInfo(currTrap).cell(allCells).segmented);
                                        %                         seg_areas=imdilate(seg_areas,s1);
                                        loc=double(cTimelapse.cTimepoint(timepoint).trapInfo(currTrap).cell(allCells).cellCenter);
                                        if ~isempty(loc)
                                            seg_areas=imfill(seg_areas(:,:,1),'holes');%sub2ind(size(seg_areas(:,:,1))loc(2),loc(1)));
                                        end
                                    end
                                    %                     seg_areas=imdilate(seg_areas,s1);
                                    seg_areas=~seg_areas;
                                    
                                    bkg=trapIm(seg_areas);
                                    bkg=bkg(~isnan(bkg(:)));
                                    if isempty(bkg)
                                        bkg=trapIm;
                                    end
                                    extractedData(channel).std(dataInd,timepoint,k)=std(double(cellFL(:)));
                                    extractedData(channel).imBackground(dataInd,timepoint,k)=median(bkg(:));
                                    extractedData(channel).min(dataInd,timepoint,k)=min(cellFL(:));
                                    extractedData(channel).radius(dataInd,timepoint,k)= sqrt(sum(sum(imfill(full(trapInfo(currTrap).cell(temp_loc).segmented),'holes')))/pi);%trapInfo(currTrap).cell(temp_loc).cellRadius;
                                    extractedData(channel).xloc(dataInd,timepoint,k)= trapInfo(currTrap).cell(temp_loc).cellCenter(1);
                                    extractedData(channel).yloc(dataInd,timepoint,k)=trapInfo(currTrap).cell(temp_loc).cellCenter(2);
                                    extractedData(channel).trapNum(dataInd)=currTrap;
                                    extractedData(channel).cellNum(dataInd)=currCell;
                                    
                                end
                            end
                        end
                    end
                    
                end
            end
        end
    end
end
cTimelapse.extractedData=extractedData;




function trapsTimepoint=returnTrapStack(cTimelapse,image,trap,timepoint)

cTrap=cTimelapse.cTrapSize;
bb=max([cTrap.bb_width cTrap.bb_height])+100;
bb_image=padarray(image,[bb bb]);
trapsTimepoint=zeros(2*cTrap.bb_height+1,2*cTrap.bb_width+1,size(image,3),'uint16');
for j=1:size(image,3)
    y=round(cTimelapse.cTimepoint(timepoint).trapLocations(trap).ycenter + bb);
    x=round(cTimelapse.cTimepoint(timepoint).trapLocations(trap).xcenter + bb);
    %             y=round(cTimelapse.cTimepoint(timepoint).trapLocations(traps(j),2) + bb);
    %             x=round(cTimelapse.cTimepoint(timepoint).trapLocations(traps(j),1) + bb);
    temp_im=bb_image(y-cTrap.bb_height:y+cTrap.bb_height,x-cTrap.bb_width:x+cTrap.bb_width,j);
    temp_im(temp_im==0)=mean(temp_im(:));
    trapsTimepoint(:,:,j)=temp_im;
end


