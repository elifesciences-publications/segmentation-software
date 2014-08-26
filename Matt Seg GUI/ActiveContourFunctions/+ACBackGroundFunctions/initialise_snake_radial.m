function [radii,angles,RminTP,RmaxTP] = initialise_snake_radial(im,N,x,y,Rmin,Rmax,exclude_logical)
%function [radii,angles] = initialise_snake_radial(im,N,x,y,Rmin,Rmax)


% Initialises the snakes with a centre at x,y in the image im.
% N      - number of snake points
% (x,y)  - centre coordinate
% Rmin   - minimal distance of cell edge from centre allowed
% Rmax   - maximum distance of cell edge from centre allowed
%
%   optional
%
% exclude_logical - logical of size of image with true at pixels that should not be within the cells
%                   outline. Used to set Rmin and Rmax for the image.


N = max(N,4);

RminTP = Rmin*ones(N,1);
RmaxTP = Rmax*ones(N,1);

if nargin < 7 || isempty(exclude_logical)
    use_exclude = false;
else
    use_exclude = true;
end


% make an N+1 length vector of equally spaced angles.
angles = linspace(0,2*pi,N+1)';
angles = angles(1:N,1);
radii = zeros(size(angles));

[imY,imX] = size(im);



if use_exclude
    
    [RminTP,RmaxTP] = ACBackGroundFunctions.set_bounds_from_exclude_image(exclude_logical,x,y,angles,RminTP,RmaxTP);
    
end


for i=1:N
    %loops through all the first N points (leaving out the repeated zero
    %N+1) and get the best point in the image for them.
    cordx = uint16(x+(RminTP(i):RmaxTP(i))'*cos(angles(i)));%radial cords
    cordy = uint16(y+(RminTP(i):RmaxTP(i))'*sin(angles(i)));
    
    cordx(cordx<1) = 1;
    cordx(cordx>imX) = imX;
    
    cordy(cordy<1) = 1;
    cordy(cordy>imY) = imY;
    
    
    score = zeros(size(cordx));
    for j = 1:length(score)
        score(j) = im(cordy(j),cordx(j));
    end
    
    
    [~,minIndex] = min(score);
    
    radii(i) = Rmin+minIndex-1;
    
end


end
