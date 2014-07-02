function generateTrainingSetTimelapse(cCellVision,cTimelapse,frame_ss,type)


% dictionary - contrains the images to be used and x-y coordinates for the synapses

% cPixelTraining - contains the
% cPixelTraining.negativeSamplesPerImage - contains the number of negative
% samples per image

% s_strel - a structuring element used to increase the size of
% the selected point identifying the synapse
%
% s_strel = strel('disk',2);
% cPixelTraining.negativeSamplesPerImage=200;

if nargin<3
    frame_ss=1;
end

if nargin<4
    type='full';
end


index=1;
if isempty(cTimelapse.trapsPresent) ||cTimelapse.trapsPresent
    cTimelapse.trapsPresent=true;
    if strcmp(type,'full')
        features=cCellVision.createImFilterSetCellTrap(cTimelapse.returnSingleTrapTimepoint(1,1,1));
    else
        features=cCellVision.createImFilterSetCellTrap_Reduced(cTimelapse.returnSingleTrapTimepoint(1,1,1));
    end
else
    features=cCellVision.createImFilterSetCellAsic(cTimelapse.returnSingleTrapTimepoint(1,1,1));
end
n_features=size(features,2);
total_num_timepoints=length(cTimelapse.cTimepoint);
num_frames=0;
for i=1:total_num_timepoints
    num_frames=num_frames+length(cTimelapse.cTimepoint(i).trapInfo);
end


n_pos=num_frames*100;
n_points=n_pos+cCellVision.negativeSamplesPerImage*num_frames;
cCellVision.trainingData.features=zeros(n_points,n_features)-100;
cCellVision.trainingData.class=zeros(1,n_points)-100;


n_points=[];
tic; time=toc;

if isempty(cCellVision.cTrap)
    se_edge=strel('disk',20);
else
    se_edge=strel('disk',9);
end

se1 = strel('disk',1);
se2 = strel('disk',2);
se3 = strel('disk',3);
se4 = strel('disk',4);
se5 = strel('disk',5);
se6 = strel('disk',6);

insideTraps=imerode(cCellVision.cTrap.trapOutline,se2);
% figure;imshow(cTimelapse.returnSingleTrapTimepoint(1,1,1),[]);
% fig1=gca;
for timepoint=1:frame_ss:total_num_timepoints
    traps=1:length(cTimelapse.cTimepoint(timepoint).trapInfo);
    image=cTimelapse.returnTrapsTimepoint(traps,timepoint,1);
    for trap=1:max(traps)
            elapsed_t=toc-time;
            disp(['Trap ', int2str(trap), 'Frame ', int2str(timepoint)])
            disp(['Time ', num2str(elapsed_t)])
            
            
            
            if isempty(cTimelapse.trapsPresent) || cTimelapse.trapsPresent
                if strcmp(type,'full')
                    features=cCellVision.createImFilterSetCellTrap(image(:,:,trap));
                else
                    features=cCellVision.createImFilterSetCellTrap_Reduced(image(:,:,trap));
                end
            else
                features=cCellVision.createImFilterSetCellAsic(image(:,:,trap));
            end
            
            %used to broaden the lines for more accurate classification
            %             trapInfo=cTimelapse.cTimepoint(timepoint).trapInfo(trap);
            
            if isfield(cTimelapse.cTimepoint(timepoint).trapInfo(trap),'cellRadius')
                trapInfo=cTimelapse.cTimepoint(timepoint).trapInfo(trap);
            else
                trapInfo=struct('cellRadius',[],'cellCenters',[]);
                trapInfo.cellRadius=[cTimelapse.cTimepoint(timepoint).trapInfo(trap).cell(:).cellRadius];
                tempy=[cTimelapse.cTimepoint(timepoint).trapInfo(trap).cell(:).cellCenter];
                trapInfo.cellCenters=reshape(tempy,[2 length(tempy)/2])';
            end
            
            class=zeros([size(image(:,:,trap)) length(trapInfo.cellRadius)+1]);
            if size(trapInfo.cellRadius,1)>0
                for num_cells=1:length(trapInfo.cellRadius)
                    class(round(trapInfo.cellCenters(num_cells,2)),round(trapInfo.cellCenters(num_cells,1)),num_cells)=1;
                    if trapInfo.cellRadius>4 & trapInfo.cellRadius<7
                        class(:,:,num_cells)=imdilate(class(:,:,num_cells),se1);
                    elseif trapInfo.cellRadius<8
                        class(:,:,num_cells)=imdilate(class(:,:,num_cells),se2);
                    elseif trapInfo.cellRadius<14
                        class(:,:,num_cells)=imdilate(class(:,:,num_cells),se3);
                    elseif trapInfo.cellRadius<22
                        class(:,:,num_cells)=imdilate(class(:,:,num_cells),se4);
                    elseif trapInfo.cellRadius<27
                        class(:,:,num_cells)=imdilate(class(:,:,num_cells),se5);
                    else
                        class(:,:,num_cells)=imdilate(class(:,:,num_cells),se6);
                    end      
                end
            end
            class=max(class,[],3);
            class=class>0;
%             tempy=image(:,:,trap);
%             tempy(class)=tempy(class)*2;
%             imshow(tempy,[],'Parent',fig1);pause(.01);

            
            [edge_im thresh]=edge(image(:,:,trap),'canny');
            %             se=strel('disk',8);
            %             edge_im=imdilate(edge_im,se);
%             edge_im=ones(size(image,1),size(image,2));
            edge_im=imdilate(edge_im,se_edge);
            
            num_neg=cCellVision.negativeSamplesPerImage;
            % exclude regions that are inside the traps;
            neg_index=find(class==0 & edge_im & ~insideTraps);
%             neg_index=find(class==0 & ~insideTraps);
            if length(neg_index)>num_neg
                neg_perm=randperm(length(neg_index));
                class_temp=zeros(1,num_neg);
                output=features(neg_index(neg_perm(1:num_neg)),:);
                pos_index=find(class~=0);
                class_temp(1,end+1:end+length(pos_index))=ones(1,length(pos_index));
                output(end+1:end+length(pos_index),:)=features(pos_index,:);
                
                n_points=size(output,1);
                cCellVision.trainingData.features(index:index+n_points-1,:)=output;
                cCellVision.trainingData.class(1,index:index+n_points-1)=class_temp;
                index=index+n_points;
            else
                neg_perm=randperm(length(neg_index));
                class_temp=zeros(1,length(neg_index));
                output=features(neg_index,:);
                
                pos_index=find(class~=0);
                class_temp(1,end+1:end+length(pos_index))=class(pos_index);
                output(end+1:end+length(pos_index),:)=features(pos_index,:);
                
                n_points=size(output,1);
                cCellVision.trainingData.features(index:index+n_points-1,:)=output;
                cCellVision.trainingData.class(1,index:index+n_points-1)=class_temp';
                index=index+n_points;
            end
    end
end


non_entries=find(cCellVision.trainingData.class<0);
cCellVision.trainingData.class(non_entries)=[];
cCellVision.trainingData.features(non_entries,:)=[];
[r c]=find(cCellVision.trainingData.features==Inf)
[r c]=find(cCellVision.trainingData.features==NaN)



cCellVision.scaling.min=min(cCellVision.trainingData.features);
cCellVision.scaling.max=max(cCellVision.trainingData.features);

loc=find(cCellVision.scaling.max==cCellVision.scaling.min)
cCellVision.scaling.max(loc)=cCellVision.scaling.max(loc)+1;
%
cCellVision.trainingData.features=(cCellVision.trainingData.features - repmat(cCellVision.scaling.min,size(cCellVision.trainingData.features,1),1));
cCellVision.trainingData.features=cCellVision.trainingData.features*spdiags(1./(cCellVision.scaling.max-cCellVision.scaling.min)',0,size(cCellVision.trainingData.features,2),size(cCellVision.trainingData.features,2));
