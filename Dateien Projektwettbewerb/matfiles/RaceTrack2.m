classdef RaceTrack2 < handle
%------------------------------------------------------------------
%   The Race Track constitutes of a left lane, right lane and center line
%   coordinates, which are parametrized by the traveled distance (center 
%   line length).
%   
%   This also means that the center line coordinate, pos_c = (x_c,y_c), the
%   track radius and the track orientation can be obtained as a function of
%   the traveled distance:
%
%   x_c(dist), y_c(dist), psi_c(dist), R_c(dist) -> see method getTrackInfo
%
%
%   Example how to create and use this class:
%
%   % load a predefined track called track01:
%       [trackdata, x0, th0, w] = RaceTrack2.loadTrack_01();
%
%   % init object:
%       track = RaceTrack2(trackdata, x0, th0, w);
%
%   % plot track:
%       track.plotTrack()
%
%   % what is the coordinate of the track centerline, track radius and 
%   % tangent angle for a centerline distance of 1000 meters ?
%       [pos_c, psi_c, R_c] = track.getTrackInfo(1000)
%
%   % lets say the vehicle is at position [10 1]' (in inertial coordinates)
%       vehicle_pos = [10 5]';
%
%   % How far has the vehicle traveled along the centerline if the vehicle
%   % position is [10 1]' ? (the reference used is the closest point in the track to the vehicle)
%       vehicle_dist = track.getTrackDistance(vehicle_pos)
%
%   % what is the lag and contour error for 2 meters ahead (along the track centerline)?
%       targetTrackDist = vehicle_dist + 2;
%       [lag_error, countour_error, offroad_error] = track.getVehicleDeviation(vehicle_pos, targetTrackDist)
%
%   % lets verify visually if the calculation is correct!!
%       track.plotTrack();
%       hold on;
%       sc1 = scatter(vehicle_pos(1), vehicle_pos(2), 50, 'filled', 'DisplayName','vehicle pos')
%       [pos_c, psi_c, R_c] = track.getTrackInfo(vehicle_dist);
%       sc2 = scatter(pos_c(1),pos_c(2), 50, 'filled', 'DisplayName','closest track point')
%       [pos_cT, psi_cT, R_cT] = track.getTrackInfo(targetTrackDist);
%       sc3 = scatter(pos_cT(1),pos_cT(2), 50, 'filled', 'DisplayName','target track point')
%       legend([sc1,sc2,sc3])
%
%------------------------------------------------------------------
    
    properties
    end
    
    properties(SetAccess=private)
        w
        track_l         % <2,L>: left track coordinates
        track_r         % <2,L>: right track coordinates
        
        track_c
        psi_c
        R_c
        
        dist            % traveled distance from the starting point
    end
    
    methods
        function obj = RaceTrack2(trackdata, x0, th0, w)
        %------------------------------------------------------------------
        %   object constructor
        %   args:
        %       x0: <2,1> initial vehicle position
        %       tho: <1> initial vehicle orientation
        %       w: <1> track width
        %       trackdata: sequence of track instructions
        %------------------------------------------------------------------
            [obj.track_l, obj.track_r, obj.psi_c] = obj.generateTrackPoints(trackdata, x0, th0, w);
            obj.track_c = (obj.track_r + obj.track_l)/2;
            
            % parametrize track by traveled distance
            distFromCenter = sqrt(obj.track_c(1,:).^2 + obj.track_c(2,:).^2);
            obj.dist = cumsum( abs(conv(distFromCenter,[1+1e-6,-1],'valid')) );
            
            obj.w = w;
        end
        
        
        function [pos_c, psi_c, R_c] = getTrackInfo(obj,dist)
        %------------------------------------------------------------------
        %   Given a distance 'dist' returns the track centerline carthesian 
        %   position pos_c=(x_c,y_c), the track orientation psi_c, and the 
        %   track radius R_c
        %------------------------------------------------------------------
            dist = mod(dist,max(obj.dist));
            idx_dist = interp1(obj.dist,1:numel(obj.dist),dist,'nearest','extrap');
            
            x_c   = obj.track_c(1,idx_dist);
            y_c   = obj.track_c(2,idx_dist);
            pos_c = [x_c;y_c];
            psi_c = obj.psi_c(1,idx_dist);
            R_c   = obj.w/2;
        end
        
        function dist = getTrackDistance(obj,pos_vehicle)
        %------------------------------------------------------------------
        %   Given the vehicle position, calculates the traveled distance 
        %   of the vehicle 'dist' along the centerline of the track
        %------------------------------------------------------------------
            [~,I] = pdist2(obj.track_c',pos_vehicle','euclidean','Smallest',1);
            dist = obj.dist(I);
        end
        
        function [lag_error, countour_error, offroad_error] = getVehicleDeviation(obj, pos_vehicle, track_dist)   
        %------------------------------------------------------------------
        %   outs: 
        %     - lag_error, countour_error: lag and countour errors from a 
        %       track position that is given by the traveled distance along 
        %       the centerline. 
        %     - offroad_error: how far the vehicle is from the track borders
        %
        %   NOTE:
        %   - positive lag_error means that the vehicle is lagging behind
        %   - positive countour_error means the vehicle is to the right size
        %     of the track
        %------------------------------------------------------------------    
            
            % get information (x,y,track radius and track orientation) of the point 
            % in the track that corresponds to a traveled distance of 'dist' meters.
            [pos_c, psi_c, R_c] = obj.getTrackInfo(track_dist);

            % ---------------------------------------------------------------------
            % contour and lag error
            % ---------------------------------------------------------------------
            % vehicle position in inertial coordinates
            I_x = pos_vehicle(1);
            I_y = pos_vehicle(2);
            % rotation to a frame with x-axis tangencial to the track (T frame)
            A_TI = [ cos(psi_c)  -sin(psi_c);    
                     sin(psi_c)   cos(psi_c)];
            % error in the inertial coordinates
            I_error = pos_c - [I_x;I_y];       
            % error in the T frame [lag_error; contouring_error]
            T_error = A_TI * I_error;
            
            % get lag and countour error
            lag_error      = T_error(1);
            countour_error = T_error(2);
            
            % offroad_error is zero if vehicle is inside the track.
            % Otherwise, we calculate the distance to the track border
            offroad_error = (abs(countour_error) > R_c) * (abs(countour_error) - R_c);
        end
        
        function h_fig = plotTrack(obj)
            h_fig = figure('Color','w','Position',[468 128 872 633]);
            title('Racing Track')
            hold on;
            grid on;
            axis equal;
            
            % -------------------------------------------------------------
            %   plot track asphalt
            % -------------------------------------------------------------
            n = length(obj.track_l);
            v = [obj.track_l(:,1:n)'; obj.track_r(:,1:n)'];   % <n,2>
            f = [1:n-1 ; 2:n; n+2:2*n; n+1:2*n-1]';
            patch('Faces',f,'Vertices',v,'FaceColor',[0.95 0.95 0.95],'LineStyle', 'none')
            
            % -------------------------------------------------------------
            %   plot track borders
            % -------------------------------------------------------------
            h_ltrack = plot(obj.track_l(1,:),obj.track_l(2,:),'k');
            h_rtrack = plot(obj.track_r(1,:),obj.track_r(2,:),'k');
        end
    end
    
       
    methods(Static)
        function [trackdata, x0, th0, w] = loadTrack_01()
            x0  = [0;0];
            th0 = 0;
            w = 6;
            trackdata = {
                 's',14;
                 'c',{15,-90};
                 's',5;
                 'c',{4,90};
                 'c',{4,-90};
                 's',5;
                 'c',{3.5,-90};
                 's',16;
                 'c',{3.5,-120};
                 's',10;
                 'c',{10,120};
                 's',10;
                 'c',{5,90};
                 's',5;
                 'c',{5,150};
                 's',5;
                 'c',{3.2,-180};
                 's',12;
                 'c',{10,-150};
                 's',12.3;      
                 'c',{12,-90}; 
            };
        end
        
        function [trackdata, x0, th0, w] = loadTrack_02()
            x0  = [0;0];
            th0 = 0;
            w = 6;
            trackdata = {
                 's',14;
                 'c',{15,-90};
                 's',5;
                 'c',{4,90};
                 'c',{4,-90};
                 's',5;
                 'c',{3.5,-180};
                 'c',{3.5,180};
                 'c',{3.5,-90};
                 's',2;
                 'c',{3.5,-120};
                 's',10;
                 'c',{10,120};
                 's',10;
                 'c',{5,90};
                 's',5;
                 'c',{5,150};
                 's',5;
                 'c',{3.2,-180};
                 's',12;
                 'c',{10,-150};
                 's',12.3;      
                 'c',{12,-90}; 
            };
        end
        
        function [track_l,track_r,psi_c] = generateTrackPoints(trackdata, x0, th0, w)
        %------------------------------------------------------------------
        %  Help function to generate Track datapoints, given track
        %  instructions (turn left 30deg with radius=10m, go straight for 20m, 
        %  turn right 45deg with radius 10m,...)
        %------------------------------------------------------------------
            track_l = [];
            track_r = [];
            psi_c = [];
            
            ds = 0.5;
            dth = deg2rad(2);

            A_z = @(th) [cos(th) -sin(th);
                         sin(th)  cos(th)];

            A_IV = A_z(th0);
            r_IV = x0;

            for idx = 1:size(trackdata,1)
                if strcmp( trackdata{idx,1},'s')
                    % distance
                    dist = trackdata{idx,2};
                    % calculate new track
                    newtrack_l = r_IV + w/2*A_IV(:,2) + (ds:ds:dist).*A_IV(:,1);
                    newtrack_r = r_IV - w/2*A_IV(:,2) + (ds:ds:dist).*A_IV(:,1);
                    newpsi_c   = th0 * ones(1,size(newtrack_l,2));
                    % update current position
                    r_IV = r_IV + dist*A_IV(:,1);

                elseif strcmp( trackdata{idx,1},'c')
                    % center curve radius
                    rad = trackdata{idx,2}{1};
                    % curvature
                    ang = deg2rad( trackdata{idx,2}{2} );

                    th = 0:dth:abs(ang);
                    arc   = [cos(th); sin(th)];
                    if ang > 0
                        newtrack_l = arc*(rad-w/2);
                        newtrack_r = arc*(rad+w/2);
                        A = [ 0 1 
                             -1 0];
                        newtrack_l = A*newtrack_l + [0;1]*rad;
                        newtrack_r = A*newtrack_r + [0;1]*rad; 
                    else
                        newtrack_l = arc*(rad+w/2);
                        newtrack_r = arc*(rad-w/2);
                        A = [0 1 
                             1 0];
                        newtrack_l = A*newtrack_l + [0;-1]*rad;
                        newtrack_r = A*newtrack_r + [0;-1]*rad; 
                    end

                    newtrack_l = A_IV * newtrack_l + r_IV;
                    newtrack_r = A_IV * newtrack_r + r_IV;
                    newpsi_c   = th0 + th;

                    A_IV = A_z(ang) * A_IV;
                    r_IV = 0.5* (newtrack_l(:,end) + newtrack_r(:,end));
                else
                    error('Not implemented');
                end

                track_l = [track_l newtrack_l];
                track_r = [track_r newtrack_r];
                psi_c   = [psi_c newpsi_c];
            end
        end
    end
end

