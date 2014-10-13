function TrapPixels  = make_trap_pixels_from_image(TrapIm,Parameters)
centers = zeros(2,2);

Nmorph = 0;

TrapIm = (TrapIm-min(TrapIm(:)));
TrapIm = TrapIm/max(TrapIm(:));

%% finding centers

f_im = figure;
imshow(TrapIm,[])
n = 1;
fprintf('\n\nselect pillar centers\n\n');
while n<3
    [centers(n,1), centers(n,2)] = ginput(1);
    hold on
    plot(centers(n,1),centers(n,2),'or');
    pause(0.1);
    n = n+1;
    
end
hold off

%% finding boundary

% just a way to get default parameters
ttacObject = timelapseTrapsActiveContour;

if nargin>1
    ttacObject.Parameters = Parameters;
else

ttacObject.Parameters.ActiveContour.opt_points = 10;
ttacObject.Parameters.ActiveContour.visualise = 4;
ttacObject.Parameters.ActiveContour.alpha = 5e-1;
%ttacObject.Parameters.ImageTransformation.ImageTransformFunction = 'none';
ttacObject.Parameters.ActiveContour.seeds = 35;
ttacObject.Parameters.ActiveContour.TerminationEpoch = 1000;
end
%ttacObject.Parameters.ImageTransformation.TransformParameters.invert = true;
PillarImages = zeros([ttacObject.Parameters.ImageSegmentation.SubImageSize*[1 1] 2]);

for i=1:2
    
    PillarImages(:,:,i) = ACBackGroundFunctions.get_cell_image(TrapIm,...
                            ttacObject.Parameters.ImageSegmentation.SubImageSize,...
                            centers(i,:) );
    
end

ImageTransformFunction = str2func(['ACImageTransformations.' ttacObject.Parameters.ImageTransformation.ImageTransformFunction]);
TransformedTrapImage = ImageTransformFunction(PillarImages,ttacObject.Parameters.ImageTransformation.TransformParameters);

TrapPixels = false(size(TrapIm));

for i=1:2
    [RadiiResult,AnglesResult] = ...
        ACMethods.PSORadialTimeStack(TransformedTrapImage(:,:,i),ttacObject.Parameters.ActiveContour,ceil(ttacObject.Parameters.ImageSegmentation.SubImageSize/2)*[1 1;1 1]);
    
[px,py] = ACBackGroundFunctions.get_full_points_from_radii(RadiiResult',AnglesResult',centers(i,:),size(TrapIm));

TrapPixels(py+size(TrapIm,1)*(px-1))=true;

end


TrapPixels = imfill(TrapPixels,'holes');

TrapPixels = imdilate(TrapPixels,strel('disk',2));

if Nmorph>0
TrapPixels = bwmorph(TrapPixels,'erode',Nmorph);
TrapPixels = bwmorph(TrapPixels,'dilate',Nmorph);
end

imshow(OverlapGreyRed(TrapIm,TrapPixels,[],[],true),[]);
fprintf('\n\n press any button to continue \n\n')
pause;


close(f_im);

end