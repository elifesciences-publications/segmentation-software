%% syntethic ring
addpath('Synthetic');
imageSize = 35;
xCenter = imageSize/2;
yCenter = imageSize/2;
innerRadius = 8.0;
outerRadius = 10.0;
innerIntensity = 100;
outerIntensity = 200;
gridResolution = 100;
image = ring(imageSize, imageSize, xCenter, yCenter, ...
    innerRadius, outerRadius, innerIntensity, outerIntensity, ...
    gridResolution);
imshow(image/255,'InitialMagnification', 'fit');

%% subpixel detection
threshold = 25;
edges = subpixelEdges(image, threshold, 'SmoothingIter', 0); 

%% show edges
visEdges(edges);
