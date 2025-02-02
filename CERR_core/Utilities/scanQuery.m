function scanQuery(command,varargin)
% scanQuery
% 
% Queries the scan Intensity values and displays in the CERR Status Bar
% 
% written DK
%
% Copyright 2010, Joseph O. Deasy, on behalf of the CERR development team.
% 
% This file is part of The Computational Environment for Radiotherapy Research (CERR).
% 
% CERR development has been led by:  Aditya Apte, Divya Khullar, James Alaly, and Joseph O. Deasy.
% 
% CERR has been financially supported by the US National Institutes of Health under multiple grants.
% 
% CERR is distributed under the terms of the Lesser GNU Public License. 
% 
%     This version of CERR is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
% CERR is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
% without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
% See the GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with CERR.  If not, see <http://www.gnu.org/licenses/>.


global planC

switch upper(command)
    case 'SCANQUERYSTART'
        cP = get(gcbo, 'CurrentPoint');
        hFig = get(gcbo, 'parent');
        delete([findobj('tag', 'scanQueryPoint')]);
        %line([cP(1,1) cP(1,1)], [cP(2,2) cP(2,2)], 'tag', 'scanQueryPoint', 'userdata', gcbo, 'eraseMode', 'xor', 'parent', gcbo, 'marker', '+', 'color', [1 1 1], 'hittest', 'off');      
        line([cP(1,1) cP(1,1)], [cP(2,2) cP(2,2)], 'tag', 'scanQueryPoint', 'userdata', gcbo, 'parent', gcbo, 'marker', '+', 'color', [1 1 1], 'hittest', 'off');
        return;
        
    case 'SCANQUERYMOTION'
        dQP = findobj('tag', 'scanQueryPoint');
        hAxis = get(dQP, 'userdata');
        [view, coord, scanSets] = getAxisInfo(hAxis, 'view', 'coord', 'scanSets');
        
        if isempty(scanSets)
            CERRStatusString('Cannot query scan in this axis: no scan is being displayed.')
            return;
        end
        
        scanSet = scanSets(1);
        if isempty(varargin)
            cP = get(hAxis, 'CurrentPoint');
            set(dQP, 'XData', [cP(1,1) cP(1,1)]);
            set(dQP, 'YData', [cP(2,2) cP(2,2)]);
        else
            xd = get(dQP, 'XData');
            yd = get(dQP, 'YData');
            cP = [xd(:) yd(:)];
        end
        
        switch lower(view)
            case 'transverse'
                x = cP(1,1); y = cP(2,2); z = coord;
            case 'sagittal'
                y = cP(1,1); z = cP(2,2); x = coord;
            case 'coronal'
                x = cP(1,1); z = cP(2,2); y = coord;
            otherwise
                return;
        end

        %Get scan's transM, and convert requested point to scan coords.
        transM = getTransM('scan', scanSet, planC);
        [xD, yD, zD] = applyTransM(inv(transM), x, y, z);

        %Get the actual scan value using the converted point.
        scan = getScanAt(scanSet,xD,yD,zD,planC);
        indexS = planC{end};
        imageType = planC{indexS.scan}(scanSet).scanInfo(1).imageType;
        if strfind(upper(imageType), 'CT')
            CTOffset = planC{indexS.scan}(scanSet).scanInfo(1).CTOffset;
            scan = scan - CTOffset;
        end

        CERRStatusString(['x = ' num2str(x) ', y = ' num2str(y) ', z = ' num2str(z) ' scan: ' num2str(scan)], 'gui');
        return;
        
        
        
    case 'SCANQUERYMOTIONDONE'
        hFig = gcbo;
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
        return;
end
