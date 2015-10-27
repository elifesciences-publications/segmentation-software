classdef cTrapDisplayProcessing<handle
    properties
        figure = [];
        subImage = [];
        subAxes=[];
        slider = [];
        pause_duration=[];
        cTimelapse=[]
        traps=[];
        channel=[]
        trapNum;
    end % properties
    %% Displays timelapse for a single trap
    %This can either dispaly the primary channel (DIC) or a secondary channel
    %that has been loaded. It uses the trap positions identified in the DIC
    %image to display either the primary or secondary information.
    methods
        function cDisplay=cTrapDisplayProcessing(cTimelapse,cCellVision,timepoints,traps,channel,gui_name)
            
            %             if nargin<3
            %                 method='twostage';
            %             end
            if nargin<3 || isempty(timepoints)
                timepoints=cTimelapse.timepointsToProcess;
            end
            
            if (nargin<4 || isempty(traps)) && cTimelapse.trapsPresent
                traps=1:length(cTimelapse.cTimepoint(timepoints(1)).trapLocations);
            elseif (nargin<4 || isempty(traps)) && ~cTimelapse.trapsPresent
                traps=1;
            end
            
            if nargin<5 || isempty(channel)
                channel=1;
            end
            
            if nargin<6 || isempty(gui_name)
                gui_name='';
            end
            
            if nargin<7 ||isempty(segType)
                if strcmp(cCellVision.method,'wholeIm')
                    segType='whole';
                else
                    segType='trap';
                end
            end
            
            
            
            if isempty(cTimelapse.magnification)
                cTimelapse.magnification=60;
            end
            
            cTimelapse=cTimelapse;
            cDisplay.traps=traps;
            cTrap=cTimelapse.cTrapSize;
            cDisplay.figure=figure('MenuBar','none');
            
            dis_w=ceil(sqrt(length(traps)));
            dis_h=max(ceil(length(traps)/dis_w),1);
            trap_images=cTimelapse.returnTrapsTimepoint(traps,timepoints(1),channel);
            
            t_width=.9/dis_w;
            t_height=.9/dis_h;
            bb=.1/max([dis_w dis_h+1]);
            index=1;
            for i=1:dis_w
                for j=1:dis_h
                    if index>length(traps)
                        break; end
                    
                    %     h_axes(i)=subplot(dis_h,dis_w,i);
                    %         h_axes(index)=subplot('Position',[t_width*(i-1)+bb t_height*(j-1)+bb t_width t_height]);
                    cDisplay.subAxes(index)=subplot('Position',[(t_width+bb)*(i-1)+bb/2 (t_height+bb)*(j-1)+bb*2 t_width t_height]);
                    cDisplay.trapNum(index)=traps(index);
                    
                    cDisplay.subImage(index)=subimage(trap_images(:,:,index));
                    %                     colormap(gray);
                    set(cDisplay.subAxes(index),'xtick',[],'ytick',[])
                    %                     set(cDisplay.subAxes(index),'CLimMode','manual')
                    index=index+1;
                    
                end
                
            end
            pause(.001);
            
            scalingFactor=cCellVision.magnification/cTimelapse.magnification;
            if strcmp(cCellVision.method,'wholeIm')
                firstIm=cTimelapse.returnSingleTimepoint(1,1);
                d_im=zeros(size(firstIm,1)*scalingFactor,size(firstIm,2)*scalingFactor);
            else
                d_im=zeros(size(trap_images,1)*scalingFactor,size(trap_images,2)*scalingFactor,length(traps));
            end
            trapsProcessed=0;tic
            trapImagesPrevTp=[];
            for i=1:length(timepoints)
                timepoint=timepoints(i);
                set(cDisplay.figure,'Name',['Timepoint ' int2str(timepoint),' of ', num2str(max(timepoints))]);
                
                if i>1
                    set(cDisplay.figure,'Name',[gui_name ' Timepoint ' int2str(timepoint-1),' of ', num2str(max(timepoints)),' (',timePerTrap, 's /trap']);
                    drawnow;
                    
                    trap_images=cTimelapse.returnTrapsTimepoint(traps,timepoints(i),channel);
                    trap_images=double(trap_images);
                    trap_images=trap_images/max(trap_images(:))*.75;
                else
                end
                if timepoint==196
                    disp('stop for debug');
                end
                identification_image_stacks = cTimelapse.returnSegmenationTrapsStack(traps,timepoints(i),segType);
                
                d_im=cTimelapse.identifyCellCentersTrap(cCellVision,timepoint,traps,identification_image_stacks,d_im);%%index j was changed to i
                
                if length(cTimelapse.channelsForSegment)>1
                    if strcmp(segType,'whole')
                        identification_image_stacks = cTimelapse.returnSegmenationTrapsStack(traps,timepoints(i),'trap');
                        cTimelapse.identifyCellObjects(cCellVision,timepoint,traps,channel,'trackUpdateObjects',[],identification_image_stacks,d_im);
                    else
                        cTimelapse.identifyCellObjects(cCellVision,timepoint,traps,channel,'hough',[],identification_image_stacks,d_im);
                    end
                else
%                     cTimelapse.identifyCellObjects(cCellVision,timepoint,traps,channel,'hough',[],trap_images);
                    cTimelapse.identifyCellObjects(cCellVision,timepoint,traps,channel,'trackUpdateObjects',[],identification_image_stacks,d_im);
                end
                
                for j=1:length(traps)
                    image=trap_images(:,:,j);
                    image=double(image);
                    image=image/max(image(:))*.75;
                    image=repmat(image,[1 1 3]);
                    
                    if cTimelapse.cTimepoint(timepoint).trapInfo(traps(j)).cellsPresent
                        seg_areas=[cTimelapse.cTimepoint(timepoint).trapInfo(traps(j)).cell(:).segmented];
                        seg_areas=full(seg_areas);
                        seg_areas=reshape(seg_areas,[size(image,1) size(image,2) length(cTimelapse.cTimepoint(timepoint).trapInfo(traps(j)).cell)]);
                        seg_areas=max(seg_areas,[],3);
                    else
                        seg_areas=zeros([size(image,1) size(image,2)])>0;
                    end
                    t_im=image(:,:,1);
                    t_im(seg_areas)=1; %t_im(seg_areas)*3;
                    image(:,:,1)=t_im;
                    
                    temp_image{j}=image;
                end
                
                 tempy_im=zeros([size(trap_images,1) size(trap_images,2) 3]);
                for j=1:size(trap_images,3)
                    set(cDisplay.subImage(j),'CData',tempy_im);
                    set(cDisplay.subAxes(j),'CLimMode','manual');
                    set(cDisplay.subAxes(j),'CLim',[0 1]);
                end
                drawnow;
                
                for j=1:length(traps)
                    image=temp_image{j};
                    set(cDisplay.subImage(j),'CData',image);
                    set(cDisplay.subAxes(j),'CLimMode','manual');
                    set(cDisplay.subAxes(j),'CLim',[min(image(:)) max(image(:))]);
                    
                    if rem(j,12)==0
                        drawnow;
                    end
                    trapsProcessed=1+trapsProcessed;
                end
                drawnow;
                
                p_time=toc;
                timePerTrap=num2str(p_time/sum(trapsProcessed),2);
                
                
                cTimelapse.timepointsProcessed(timepoint)=1;
                
            end
            close(cDisplay.figure);
        end
    end
end

