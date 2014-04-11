function [Ftot] = CFRadialTimeStack(im_stack,center_stack,angles,radii_stack_mat,radial_punishing_factor,time_change_punishing_factor,image_size,first_timepoint_fixed,A,n,breaks,jj,C,varargin)
%cost function for snakes algorithm written to be used used with the
%particle optimisation toolbox from the file exchange:

%http://www.mathworks.co.uk/matlabcentral/fileexchange/7506-particle-swarm-optimization-toolbox

%via the call:

%[optOUT] = pso_Trelea_vectorized(@(radii_mat)snake_cost_fun_radial_PSO_play(image,center,angles,radii_mat,R_min,R_max,alpha),opt_points,7,[LowerBound UpperBound],0,P,'',seed);


%and options can be set as appropriate

%should take the center, and draw length(radii) lines at angles 'angles'
%Then draws a spline between them and calculate a cost function.

%im_stack                           - stack of forcing images (edges should be low)
%center_stack                       - stack of proposed center of cell [x y]
%angles                             - vector of angles in radians from the horizontal (horizontal to
%                                     the right is 0, horizontal to the left is pi).
%radii_stack_mat                    - vector of distances along radii (evenly spaced and starting at vertical
%                                     relative to the image) of the contour
%radial_punishing_factor            - vector:weight of second derivative (or whatever term keeps the thing
%                                     roughly circular) each element of
%                                     vector is for one timepoint. Normally
%                                     a constant (alpha) * forcing image
%                                     median for robust parameter
%                                     selection.
%time_change_punishing_factor       - weight of timepoints sum term (squares of differences in
%                                     radii between timepoints). normally a
%                                     constant (Beta) multiplied by median
%                                     of image stack to try to get robust
%                                     parameter selection
%steps                              - row vector of radial angles that should be used to give total
%                                     coverage of the boundary (normally 0:(1/Rmax):(2*pi) )
%first_timepoint_fixed              - boolean. Set to true if the first
%                                     timepoint is a fixed one to not
%                                     optimise.


%SOME RULES
%radii_mat must be at least 2 wide
%width of radii_mat should be the same as the length of angles
%angles should be given in ascending order (i.e.
%[angles,indices] = sort(angles,1);
%radii_mat = radii_mat(:,indices))

Ftot = 0;
radii_length = size(angles,1);
timepoints = (size(radii_stack_mat,2)/radii_length);
points = size(radii_stack_mat,1);

if first_timepoint_fixed

    timepoints_to_optimise = 2:timepoints;

else
    timepoints_to_optimise = 1:timepoints;

end

for ti = 1:length(timepoints_to_optimise)
    t= timepoints_to_optimise(ti);
    radii_mat = radii_stack_mat(:,(1+(t-1)*radii_length):(t*radii_length));
    im = im_stack(:,:,ti);
    center = center_stack(ti,:);
    
    %number of points, length of radii vector
    steps = 0:(1/max(radii_mat(:))):(2*pi);
    
    %resuts vector
    F = zeros(points,1);
    
    imx = size(im,2);%size of image
    imy = size(im,1);
    
    
    %construct spline using file exchange function 'splinefit'
    
    %TESTING CHANGES FOR SPEED
    %r_spline = splinefit([angles; 2*pi],[radii_mat radii_mat(:,1)],[angles; 2*pi],'p');%make the spline
    
    %[A,n,breaks,dim,jj,C] = splinefit_prep([angles; 2*pi],ones(size(radii_mat)+[0 1]),[angles; 2*pi],'p');
    
    
    r_spline = ACBackGroundFunctions.splinefit_thin(A,n,breaks,points,jj,C,[radii_mat radii_mat(:,1)]);
    
    
    %TESTING CHANGES FOR SPEED
    radii_full = ppval(r_spline,steps);
    
    %radii_full = spline([-1*angles(2,1); angles; 2*pi],[radii(end);radii;radii(1)],steps);
    
    %convert radial coords to x y coords
    cordx_full = round(center(1)+(radii_full.*repmat(cos(steps),points,1)));
    cordy_full = round(center(2)+(radii_full.*repmat(sin(steps),points,1)));
    
    %check coords are within boundary of image
    cordx_full(cordx_full<1) = 1;
    cordx_full(cordx_full>imx) = imx;
    cordy_full(cordy_full<1) = 1;
    cordy_full(cordy_full>imy) = imy;
    
    for p=1:points
        
        %F(p) = ACBackGroundFunctions.cost_from_image(im,[cordx_full(p,:);cordy_full(p,:)]',image_size(1,1));
        
        %testing for inline speed up
        I = (diff(cordx_full(p,:))|diff(cordy_full(p,:)));

        %sums pixel values
        F(p) = (sum(im(cordy_full(p,I)+(image_size(1,1)*(cordx_full(p,I)-1))),2))/sum(I,2);

        
    end
    
    
    D2radii = ACBackGroundFunctions.second_derivative_snake_horizontal(radii_mat);
    
    F = F+radial_punishing_factor(ti)*((sum((D2radii./radii_mat).^2,2))); %add punishment for very uneven cell outlines
    
    Ftot = Ftot+F;
end

%Ftot = Ftot+ betaElco*sum((radii_stack_mat - [radii_stack_mat(:,(end+1-radii_length):end) radii_stack_mat(:,1:(end-radii_length))]).^2,2);
%timepoint_diff_mat = (1 - ([radii_stack_mat(:,(end+1-radii_length):end) radii_stack_mat(:,1:(end-radii_length))]./radii_stack_mat)).^2;
%timepoint_diff_mat = (1 - ( radii_stack_mat(:,1:(end-radii_length))./radii_stack_mat(:,(radii_length+1):end))).^2;
timepoint_diff_mat = ((radii_stack_mat(:,(radii_length+1):end) -  radii_stack_mat(:,1:(end-radii_length)))./...
                        (radii_stack_mat(:,(radii_length+1):end) +  radii_stack_mat(:,1:(end-radii_length)))).^2;


Ftot = Ftot+ time_change_punishing_factor*sum(timepoint_diff_mat.*timepoint_diff_mat>0.01,2);

end






function [D2radii] = second_derivative_snake(radii)

%calculate second derivative of points radii (D^2 r / D (theta) ^2)
%radii is expected to be an unlooped list (i.e. a list of unrepeated,
%evenly spaced radii.
radii2 = [radii(:,end) radii radii(:,1)];
mask = [-1 2 -1];

D2radii = conv2(radii2,mask,'valid');


end

