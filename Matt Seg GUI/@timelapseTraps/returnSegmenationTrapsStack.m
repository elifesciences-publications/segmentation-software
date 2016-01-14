function [imagestack_out] = returnSegmenationTrapsStack(cTimelapse,traps,timepoint,type)
%[imagestack_out] = returnSegmenationTrapsStack(cTimelapse,traps,timepoint,type) 
%
% returns a cell array of image stacks defined by the property
% channelsForSegment of cTimelapse to be used in the cell identification.
% In any case each slice of the image stack corresponds to a channel given
% in the array stored in the property channelsForSegment of cTimelapse.
%
% cTimelapse    :   object of the timelapseTraps class
% traps         :   Array of of indices of traps for which segmentation
%                   image stack should be returned.
% timepoint     :   timepoint from which to return images
% type          :   optional. String determining which sort of image to
%                   return. Written to match the cCellVision.method field.
%                   default is 'twostage'
%                   'twostage' or 'linear' : return a cell array with each element
%                                            being an image stack for
%                                            the trap in the traps array provided, with
%                                            each slice of each stack being a given
%                                            channel.
%                   wholeIm      : return a single element cell array
%                                  containing stack of whole
%                                  timepoint image . Each slice is the whole
%                                  image at a given channel
%                   wholeTrap  : return a single element cell array
%                                containing stack of trap images laid in a
%                                long strip. Each slice is a strip of trap
%                                images at a given channel.
%
% imagestack_out : cell array of image stacks with the exact content being
%                  determined by 'type' input as described above.
%


if nargin<4
    type = 'twostage';
end

if ~cTimelapse.trapsPresent
    type = 'wholeIm';
end

for ci = 1:length(cTimelapse.channelsForSegment)  
    if ismember(type,{'twostage','linear','trap'}) %trap option is for legacy reasons
        % return a cell array with each element being an image stack for
        % the trap in the traps array provided
        temp_im = cTimelapse.returnTrapsTimepoint(traps,timepoint,cTimelapse.channelsForSegment(ci));
        mval=mean(temp_im(:));
        if ci==1
            imagestack_out = cell(length(traps),1);
            [imagestack_out{:}] = deal(mval*ones(size(temp_im,1),size(temp_im,2),length(cTimelapse.channelsForSegment)));
        end
        for ti=1:length(traps)
            imagestack_out{ti}(:,:,ci) = temp_im(:,:,ti);
        end
    elseif ismember(type,{'wholeIm','whole'}) %'whole' is for legacy reasons
        % return a single element cell array containing stack of whole
        % timepoint image
        % each slice is a channel
        temp_im = cTimelapse.returnSingleTimepoint(timepoint,cTimelapse.channelsForSegment(ci));
        mval=mean(temp_im(:));
        if ci==1
            imagestack_out = cell(1,1);
            imagestack_out{1} = mval*ones(size(temp_im,1),size(temp_im,2),length(cTimelapse.channelsForSegment));
        end
        imagestack_out{1}(:,:,ci) = temp_im;
    elseif strcmp(type,'wholeTrap') 
        % return a single element cell array containing stack of trap images laid in a long strip
        % each slice is a channel
        temp_im = cTimelapse.returnTrapsTimepoint(traps,timepoint,cTimelapse.channelsForSegment(ci));
        mval=mean(temp_im(:));
        if ci==1
            imagestack_out = cell(1,1);
            colL=size(temp_im,2);
            imagestack_out{1} = mval*ones(size(temp_im,1),size(temp_im,2)*length(traps),length(cTimelapse.channelsForSegment));
        end
        for ti=1:length(traps)
            imagestack_out{1}(:,1+(ti-1)*colL:ti*colL,ci) = temp_im(:,:,ti);
        end
    end 
end
end