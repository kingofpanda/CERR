function showStructures(hAxis)
%"showStructures"
%   Draws structure contours in CERR axis hAxis.  Refers to axisInfo
%   userdata structure to determine coordinate, view etc.
%
%JRA 11/17/04
%
%Usage:
%   function showStructures(hAxis);
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
global stateS
indexS = planC{end};

%Get info about the axis view.
axisInfo = get(hAxis, 'userdata');
structureSets = axisInfo.structureSets;

[view coord] = getAxisInfo(hAxis,'view','coord');

% set(hAxis, 'nextplot', 'add');

%Set dim or return if not a scan view.
switch upper(view)
    case 'CORONAL'
        dim = 2;
    case 'SAGITTAL'
        dim = 1;
    case 'TRANSVERSE'
        dim = 3;
    otherwise
        return;
end

%Find structure data that needs to be removed: ie, calculated on a
%different coordinate, view, or transM.  Also find structure data
%that needs to have the image refreshed, but the underlying data
%is OK.  Flag these for redrawing.
toRemove = [];
for i=1:length(axisInfo.structureGroup)
    sG = axisInfo.structureGroup(i);
    if ~ismember(sG.structureSet, structureSets) | ~isequal(coord, sG.coord) | ~isequal(getTransM('scan', sG.structureSet, planC), sG.transM) | ~isequal(view, sG.view)
        %for j=1:length(sG.handles), try, delete(sG.handles(i)); end, end
        handlV = ishandle(sG.handles);
        delete(sG.handles(handlV))
        toRemove = [toRemove;i];
    elseif ~isequal(sG.dispMode, 'contourLines') | stateS.structsChanged
        %for j=1:length(sG.handles), try, delete(sG.handles(i)); end, end
        handlV = ishandle(sG.handles);
        delete(sG.handles(handlV))
        axisInfo.structureGroup(i).handles = [];
        axisInfo.structureGroup(i).redraw = 1;
    end
end
axisInfo.structureGroup(toRemove) = [];

%Add a new structure data element for any structureSets that don't have one,
%and cache the calculated contour data.  Get a list of structures in this
%set.
for i=1:length(structureSets);
    if ~ismember(structureSets(i), [axisInfo.structureGroup.structureSet])
        numObjs = length(axisInfo.structureGroup);
        axisInfo.structureGroup(numObjs+1).view         = view;
        axisInfo.structureGroup(numObjs+1).coord        = coord;
        axisInfo.structureGroup(numObjs+1).structureSet = structureSets(i);
        axisInfo.structureGroup(numObjs+1).structureSetUID = planC{indexS.structureArray}(structureSets(i)).structureSetUID;
        axisInfo.structureGroup(numObjs+1).structsDrawn = [];
        axisInfo.structureGroup(numObjs+1).transM       = getTransM('scan', structureSets(i), planC);
        axisInfo.structureGroup(numObjs+1).xV           = [];
        axisInfo.structureGroup(numObjs+1).yV           = [];
        axisInfo.structureGroup(numObjs+1).dispMode     = 'contourLines';
        axisInfo.structureGroup(numObjs+1).redraw       = 1;
    end
end

set(hAxis, 'userdata', axisInfo);

for i=1:length(axisInfo.structureGroup)
    
    if axisInfo.structureGroup(i).redraw
        structSet           = axisInfo.structureGroup(i).structureSet;
        scanSet             = getAssociatedScan(planC{indexS.structureArray}(structSet).assocScanUID);
        transM              = axisInfo.structureGroup(i).transM;
        [assocScansV] = getStructureAssociatedScan(1:length(planC{indexS.structures}), planC);
        if isempty(assocScansV) %handle case of no structures
            structsInThisScan = [];
        else
            structsInThisScan = find(assocScansV == scanSet);
        end
        axisInfo.structureGroup(i).redraw = 0;
        
        %If no structs to display, return;
        if isempty(structsInThisScan)
            continue;
        end
        
        switch upper(view)
            case 'TRANSVERSE'
                dim = 3;
            case 'SAGITTAL'
                dim = 1;
            case 'CORONAL'
                dim = 2;
            otherwise
                return;
        end
        
        %Check for transM, and if it has any rotation component.
        rotation = 0; xT = 0; yT = 0; zT = 0;
        if isfield(planC{indexS.scan}(scanSet), 'transM') & ~isempty(planC{indexS.scan}(scanSet).transM);
            [rotation, xT, yT, zT] = isrotation(planC{indexS.scan}(scanSet).transM);
            transM = planC{indexS.scan}(scanSet).transM;
        else
            transM = eye(4);
        end
        
        if ~rotation & dim == 3
            [xs, ys, zs] = getScanXYZVals(planC{indexS.scan}(scanSet));
            xs = xs+xT;
            ys = ys+yT;
            zs = zs+zT;
            
            if coord<min(zs) | coord>max(zs)
                continue
            else
                sliceNum = findnearest(zs, coord);
            end
            
            kLast = 0;
            %allStrOnSlc = [];
            for structNum = 1 : length(structsInThisScan)
                
                if ~isempty(planC{indexS.structures}(structsInThisScan(structNum)).contour)
                    
                    if ~(isfield(planC{indexS.structures}(structsInThisScan(structNum)),'meshRep') && ~isempty(planC{indexS.structures}(structsInThisScan(structNum)).meshRep) && planC{indexS.structures}(structsInThisScan(structNum)).meshRep) || stateS.contourState %check for mesh-based display
                        
                        numSegs = length(planC{indexS.structures}(structsInThisScan(structNum)).contour(sliceNum).segments);
                        
                        for segNum = 1 : numSegs
                            
                            pointsM = planC{planC{end}.structures}(structsInThisScan(structNum)).contour(sliceNum).segments(segNum).points;
                            
                            if ~isempty(pointsM)
                                
                                if (size(pointsM,1) == 1) || (size(pointsM,1) == 2 && isequal(pointsM(1,:),pointsM(2,:)))
                                    % Draw a crosshair
                                    bs = 0.3;
                                    yCoords = [pointsM(1,2);pointsM(1,2);pointsM(1,2);pointsM(1,2)-bs;pointsM(1,2)+bs] + yT;
                                    xCoords = [pointsM(1,1)-bs;pointsM(1,1)+bs;pointsM(1,1);pointsM(1,1);pointsM(1,1)] + xT;
                                else
                                    yCoords = [pointsM(:,2); pointsM(1,2)] + yT;
                                    xCoords = [pointsM(:,1); pointsM(1,1)] + xT;
                                end
                                
                                %allStrOnSlc = [allStrOnSlc, structNum];
                                
                                hStructContour = line(xCoords, yCoords, 'parent', hAxis,'color',planC{indexS.structures}(structsInThisScan(structNum)).structureColor, 'tag', 'structContour', 'linewidth', stateS.optS.structureThickness, 'linestyle', '-', 'userdata', structsInThisScan(structNum), 'hittest', 'off');
                                if stateS.optS.structureDots
                                    hStructContourDots = line(xCoords, yCoords, 'parent', hAxis, 'color', [0 0 0],'tag', 'structContourDots', 'linewidth', .5, 'linestyle', ':', 'userdata', structsInThisScan(structNum), 'hittest', 'off');
                                end
                                %set(hStructContour,'color',planC{indexS.structures}(structsInThisScan(structNum)).structureColor, 'tag', 'structContour', 'linewidth', stateS.optS.structureThickness, 'linestyle', '-', 'userdata', structsInThisScan(structNum), 'hittest', 'off');
                                
                                %Set visible flag.
                                if isfield(planC{indexS.structures}(structsInThisScan(structNum)), 'visible')
                                    if ~isempty(planC{indexS.structures}(structsInThisScan(structNum)).visible) && ~planC{indexS.structures}(structsInThisScan(structNum)).visible
                                        set(hStructContour, 'visible', 'off');
                                    end
                                end
                                
                                if kLast ~= structsInThisScan(structNum)
                                    label = planC{indexS.structures}(structsInThisScan(structNum)).structureName;
                                    iV = findstr(label,'_');
                                    for j =  1 : length(iV)
                                        index = iV(j) + j - 2;
                                        label = insert('\',label,index);   %to get correct printing of underlines
                                    end
                                    ud.structNum = structsInThisScan(structNum);
                                    ud.structDesc = label;
                                end
                                set(hStructContour, 'userdata', ud);
                                if stateS.optS.structureDots
                                    axisInfo.structureGroup(i).handles = [axisInfo.structureGroup(i).handles;hStructContour(:);hStructContourDots(:)];
                                else
                                    axisInfo.structureGroup(i).handles = [axisInfo.structureGroup(i).handles;hStructContour(:)];
                                end
                                
                                kLast = structsInThisScan(structNum);
                                
                            end
                            
                        end
                        
                    else % Mesh-based display
                        axisInfo = drawContoursFromMesh(axisInfo,i,hAxis,view,coord,transM,structsInThisScan(structNum));
                        
                    end % Check for Mesh-based display ends
                    
                end
                
            end
            
            %stateS.webtrev.StrOnSlc.trans = unique(allStrOnSlc);
            
        else
            
            [slcC, xV, zV] = getStructureSlice(scanSet, dim, coord);
            
            % slc = uint32(slc);
            %Find out which structs are on this slice.
            %structsOnSlice = cumbitor(slc(:));
            
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %             %%%%%%%  for webtrev
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %
            %             allStrOnSlc = [];
            %             switch upper(view)
            %                 case 'TRANSVERSE'
            %                     stronslcDim = 'tra';
            %                 case 'SAGITTAL'
            %                     stronslcDim = 'sag';
            %                 case 'CORONAL'
            %                     stronslcDim = 'cor';
            %                 otherwise
            %                     return;
            %             end
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            matlab_version = MLVersion;
            
            structsOnSliceC = [];
            for cellNum = 1:length(slcC)
                structsOnSliceC{cellNum} = cumbitor(slcC{cellNum}(:));
            end
            
            % for each structure (bit), populate a separate matrix with 0's and 1's, then contour onto the image.
            for structNum = 1:length(structsInThisScan) %or 32
                
                if (~(isfield(planC{indexS.structures}(structsInThisScan(structNum)),'meshRep') && ~isempty(planC{indexS.structures}(structsInThisScan(structNum)).meshRep) && planC{indexS.structures}(structsInThisScan(structNum)).meshRep) || stateS.contourState) %check for mesh-based display
                    
                    if isempty(structsOnSliceC)
                        includeCurrStruct = 0;
                    elseif structNum<=52
                        cellNum = 1;
                        structsOnSlice = structsOnSliceC{cellNum};
                        includeCurrStruct = bitget(structsOnSlice, structNum);
                    else
                        cellNum = ceil((structNum-52)/8)+1; %uint8
                        structsOnSlice = structsOnSliceC{cellNum};
                        %includeCurrStruct = bitget(structsOnSlice, structNum-(cellNum-1)*52); %double
                        includeCurrStruct = bitget(structsOnSlice, structNum-52-(cellNum-2)*8); %uint8
                    end
                    if includeCurrStruct && isfield(planC{indexS.structures}(structsInThisScan(structNum)), 'visible')
                        if ~isempty(planC{indexS.structures}(structsInThisScan(structNum)).visible) && ~planC{indexS.structures}(structsInThisScan(structNum)).visible
                            includeCurrStruct = 0;
                        else
                            includeCurrStruct = 1;
                        end
                    end
                    if includeCurrStruct
                        %allStrOnSlc = [allStrOnSlc, structNum];
                        if structNum<=52
                            oneStructM = bitget(slcC{cellNum}, structNum); %double
                        else
                            oneStructM = bitget(slcC{cellNum}, structNum-52-(cellNum-2)*8); %uint8
                        end
                        %                         %display oneStructM using contour
                        %                         %For matlab 7 compatibility:
                        %                         if matlab_version >= 7 & matlab_version < 7.5
                        %                             [c, hStructContour] = contour('v6', xV(:), zV(:), oneStructM, [.5 .5], '-');
                        %                             set(hStructContour, 'parent', hAxis);
                        %                             if stateS.optS.structureDots
                        %                                 [c, hStructContourDots] = contour('v6', xV(:), zV(:), oneStructM, [.5 .5], '-');
                        %                                 set(hStructContourDots, 'parent', hAxis);
                        %                             end
                        %                         elseif matlab_version >= 7.5
                        %                             [c, hStructContour] = contour(xV(:), zV(:), oneStructM, [.5 .5], '-');
                        %                             set(hStructContour, 'parent', hAxis);
                        %                             if stateS.optS.structureDots
                        %                                 [c, hStructContourDots] = contour(xV(:), zV(:), oneStructM, [.5 .5], '-');
                        %                                 set(hStructContourDots, 'parent', hAxis);
                        %                             end
                        %                         else
                        %                             [c, hStructContour] = contour(xV(:), zV(:), oneStructM, [.5 .5], '-');
                        %                             set(hStructContour, 'parent', hAxis);
                        %                             if stateS.optS.structureDots
                        %                                 for cNum=1:length(hStructContour);
                        %                                     hStructContourDots(cNum) = line(get(hStructContour(cNum), 'xData'), get(hStructContour(cNum), 'yData'), 'parent', hAxis, 'hittest', 'off');
                        %                                 end
                        %                             end
                        %                         end
                        [c, hStructContour] = contour(xV(:), zV(:), oneStructM, [.5 .5], '-');
                        set(hStructContour, 'parent', hAxis);
                        if stateS.optS.structureDots
                            [c, hStructContourDots] = contour(xV(:), zV(:), oneStructM, [.5 .5], '-');
                            set(hStructContourDots, 'parent', hAxis);
                        end
                        
                        if stateS.optS.structureDots
                            set(hStructContourDots, 'linewidth', .5, 'tag', 'structContourDots', 'linestyle', ':', 'color', [0 0 0], 'userdata', structsInThisScan(structNum), 'hittest', 'off')
                        end
                        set(hStructContour, 'linewidth', stateS.optS.structureThickness, 'tag', 'structContour');
                        %set(hStructContour,'color',getColor(structsInThisScan(structNum), stateS.optS.colorOrder), 'hittest', 'off','userdata', structsInThisScan(structNum));
                        set(hStructContour,'color',planC{indexS.structures}(structsInThisScan(structNum)).structureColor, 'hittest', 'off','userdata', structsInThisScan(structNum));
                        label = planC{indexS.structures}(structsInThisScan(structNum)).structureName;
                        iV = strfind(label,'_');
                        for j =  1 : length(iV)
                            index = iV(j) + j - 2;
                            label = insert('\',label,index);   %to get correct printing of underlines
                        end
                        if stateS.optS.structureDots
                            axisInfo.structureGroup(i).handles = [axisInfo.structureGroup(i).handles;hStructContour(:);hStructContourDots(:)];
                        else
                            axisInfo.structureGroup(i).handles = [axisInfo.structureGroup(i).handles;hStructContour(:)];
                        end
                        ud.structNum = structsInThisScan(structNum);
                        ud.structDesc = label;
                        set(hStructContour, 'userdata', ud);
                    end
                    
                else %Mesh-based display
                    axisInfo = drawContoursFromMesh(axisInfo,i,hAxis,view,coord,transM,structsInThisScan(structNum));
                    
                end
                
            end
            %eval (['stateS.webtrev.StrOnSlc.' stronslcDim ' = unique(allStrOnSlc);']);
        end
        
        xDataC = get(axisInfo.structureGroup(i).handles, 'XData');
        yDataC = get(axisInfo.structureGroup(i).handles, 'YData');
        if ~isempty(xDataC) && ~isempty(yDataC)
            xMinMax = [min([xDataC{:}]) max([xDataC{:}])];
            yMinMax = [min([yDataC{:}]) max([yDataC{:}])];
            axisInfo.structureGroup(i).xMinMax = xMinMax;
            axisInfo.structureGroup(i).yMinMax = yMinMax;
        end
    end
end

set(hAxis, 'userdata', axisInfo);
return;

function [bool, xT, yT, zT] = isrotation(transM);
%"isrotation"
%   Returns true if transM includes rotation.  If it doesn't include
%   rotation, bool=0. xT,yT,zT are the translations in x,y,z
%   respectively.

xT = transM(1,4);
yT = transM(2,4);
zT = transM(3,4);

transM(1:3,4) = 0;
bool = ~isequal(transM, eye(4));
return;

function axisInfo = drawContoursFromMesh(axisInfo,structureGroupNumber,hAxis,view,coord,transM,structNum)
global planC stateS
indexS = planC{end};

switch upper(view)
    case 'TRANSVERSE'
        dim = 3;
        pointOnPlane = [0 0 coord] - transM(1:3,4)';
        planeNormal = (inv(transM(1:3,1:3))*[0 0 1]')';
    case 'SAGITTAL'
        dim = 1;
        pointOnPlane = [coord 0 0] - transM(1:3,4)';
        planeNormal = (inv(transM(1:3,1:3))*[1 0 0]')';
    case 'CORONAL'
        dim = 2;
        pointOnPlane = [0 coord 0] - transM(1:3,4)';
        planeNormal = (inv(transM(1:3,1:3))*[0 1 0]')';
    otherwise
        return;
end

pointOnPlane = (inv(transM(1:3,1:3))*pointOnPlane')';
structUID   = planC{indexS.structures}(structNum).strUID;
%calllib('libMeshContour','generateSurface', structUID, 0.5, uint16(3));
currDir = cd;
meshDir = fileparts(which('libMeshContour.dll'));
cd(meshDir);
%loadlibrary('libMeshContour','MeshContour.h');
contourS    = calllib('libMeshContour','getContours',structUID,single(pointOnPlane),single(planeNormal),single([0 1 0]),single([1 0 0]));
%unloadlibrary('libMeshContour');
cd(currDir)
if isfield(contourS,'segments')
    for segNum = 1:length(contourS.segments)
        switch upper(view)
            case 'TRANSVERSE'
                %pointsM = transM*[contourS.segments(segNum).points contourS.segments(segNum).points(:,1).^0]';
                pointsM = applyTransM(transM,contourS.segments(segNum).points);
                xCoords = pointsM(:,1);
                yCoords = pointsM(:,2);
            case 'SAGITTAL'
                %pointsM = transM*[contourS.segments(segNum).points contourS.segments(segNum).points(:,1).^0]';
                pointsM = applyTransM(transM,contourS.segments(segNum).points);
                xCoords = pointsM(:,2);
                yCoords = pointsM(:,3);
            case 'CORONAL'
                %pointsM = transM*[contourS.segments(segNum).points contourS.segments(segNum).points(:,1).^0]';
                pointsM = applyTransM(transM,contourS.segments(segNum).points);
                xCoords = pointsM(:,1);
                yCoords = pointsM(:,3);
            otherwise
                return;
        end
        hStructContour = line(xCoords, yCoords, 'parent', hAxis);
        if stateS.optS.structureDots
            hStructContourDots = line(xCoords, yCoords, 'parent', hAxis, 'color', [0 0 0],'tag', 'structContourDots', 'linewidth', .5, 'linestyle', ':', 'userdata', structNum, 'hittest', 'off');
        end
        set(hStructContour,'color',planC{indexS.structures}(structNum).structureColor, 'tag', 'structContour', 'linewidth', stateS.optS.structureThickness, 'linestyle', '-', 'userdata', structNum, 'hittest', 'off');
        
        %if kLast ~= structsInThisScan(structNum)
        label = planC{indexS.structures}(structNum).structureName;
        iV = findstr(label,'_');
        for j =  1 : length(iV)
            index = iV(j) + j - 2;
            label = insert('\',label,index);   %to get correct printing of underlines
        end
        ud.structNum = structNum;
        ud.structDesc = label;
        %end
        set(hStructContour, 'userdata', ud);
        if stateS.optS.structureDots
            axisInfo.structureGroup(structureGroupNumber).handles = [axisInfo.structureGroup(structureGroupNumber).handles;hStructContour(:);hStructContourDots(:)];
        else
            axisInfo.structureGroup(structureGroupNumber).handles = [axisInfo.structureGroup(structureGroupNumber).handles;hStructContour(:)];
        end
        
        %kLast = structNum;
        
    end
end
return;