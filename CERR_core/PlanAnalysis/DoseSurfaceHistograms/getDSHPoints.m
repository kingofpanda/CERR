function [planC, surfacePointsM] = getDSHPoints(planC, optS, structNumV)
%"getDSHPoints"
%   Get surface points on a defined anatomical structure and store them in
%   the planC.  optS is used to determine 
%
%   Stored in: planC{indexS.structures}(structNum).DSHPoints = surfacePointsM.
%
%   If structNum input is missing, all structures are done which are
%   indicated in the optS.surfPtStructures field.  If structNum input is 
%   included, only that structure is done.
%
%J.O.Deasy, deasy@radonc.wustl.edu
%
%LM: JOD, 18 Feb 02.
%    JOD, 05 May 03, added structNum option to get just surface points for
%                   that structure.
%    JOD, 13 May 03, CERRStatusString instead of disp.
%    JOD, 23 Jul 03, now using voxelThickness.
%    JRA, 24 Feb 05, Reformated call, comment and file.
%    JRA, 21 Apr 05, Added surfacePointsM output argument, made more
%                    robust.
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
%
%Usage:
%   planC = getDSHPoints(planC, optS, structNum);

indexS = planC{end};

optStructs = optS.surfPtStructures;

%If structNumV doesn't exist, check optS for structs to include.  If 'any'
%is one of the optS.surfPtStructures, include all structures.
if ~exist('structNumV')
    structNumV = [];
    structNames = lower({planC{indexS.structures}.structureName});
    for i=1:length(optStructs)
        if strcmpi(optStructs{i}, 'any')
            structNumV = 1:length(planC{indexS.structures});
            break;
        end
        optString = lower(optStructs{i});                
        structBool = strncmpi(optStructs{i}, structNames, length(optStructs{i}));
        structNumV = union(structNumV, find(structBool));
    end
end

if nargout == 2 & length(structNumV ) > 1
    error('Cannot request surfacePoints output from getDSHPoints if DSH points for more than one structure are being calculated.')
end

%Loop over all structures in structNumV
nStructs = length(structNumV);

%Be sure that voxel thicknesses exist for all scans we need.
scanSets = getStructureAssociatedScan(structNumV, planC);
uScanSets = unique(scanSets);

for i=1:length(uScanSets)
    nSlices = length(planC{indexS.scan}(uScanSets(i)).scanInfo);
    voxThickness = num2cell(deduceVoxelThicknesses(uScanSets(i), planC));
    [planC{indexS.scan}(uScanSets(i)).scanInfo(1:nSlices).voxelThickness] = deal(voxThickness{:});
end
        

for i = 1 : nStructs
    
    structNum   = structNumV(i);    
    structName  = lower(planC{indexS.structures}(structNum).structureName);
    assocScan   = getStructureAssociatedScan(structNum, planC);
    
    numSlices   = size(getScanArray(planC{indexS.scan}(assocScan)), 3);
    
    surfacePointsM = [];
    
    for j = 1 : numSlices
        
        %Try and access the points for this slice.  If fail, continue to
        %next slice.
        try
            nPts = length(planC{indexS.structures}(structNum).contour(j).segments(1).points);
        catch
            continue;
        end
        
        if nPts ~=0
            CERRStatusString(['Getting surface points for structure ' num2str(structNum) ', slice ' num2str(j) '.'])
        end
        
        numSegs = length(planC{indexS.structures}(structNum).contour(j).segments);
        
        for k = 1 : numSegs
            
            pointsM = planC{indexS.structures}(structNum).contour(j).segments(k).points;
            
            if ~isempty(pointsM)
                
                [xV, yV, lengthV] = surfacePoints(pointsM(:,1:2), optS.DSHMaxPointInterval);
                
                delta_z = planC{indexS.scan}(assocScan).scanInfo(j).voxelThickness;
                
                areaV = lengthV * delta_z;
                
                zValue = pointsM(1,3);
                
                zV = ones(length(xV),1) * zValue;
                
                surfacePointsM = [surfacePointsM; [xV, yV, zV, areaV]];
                
            end
            
        end
        
    end
    
    %Obtain the most Sup and Inf slices
    zVals = surfacePointsM(:,3);
    zSup = min(zVals);
    zInf = max(zVals);
    
    %Obtain surface points on superior and inferior slices
    %Get slice index for sup and inf
    [xScanV,yScanV,zScanV] = getScanXYZVals(planC{indexS.scan}(assocScan));
    slcSup = findnearest(zScanV,zSup);
    slcInf = findnearest(zScanV,zInf);
    
    %Get rastersegments
    rasterSegsSup = getRasterSegments(structNum, planC, slcSup);
    rasterSegsInf = getRasterSegments(structNum, planC, slcSup);
    rasterSegsM = [rasterSegsSup; rasterSegsInf];
    dy = planC{indexS.scan}(assocScan).scanInfo(1).grid1Units;
    deltaLim = optS.DSHMaxPointInterval;
    for rsNum = 1:size(rasterSegsM,1)
        len = rasterSegsM(rsNum,4) - rasterSegsM(rsNum,3);
        len = max(len,1);
        ints = ceil(len/deltaLim);  %There will aways be at least one interval/sample point.
        delta = len/ints;  %This is the size of an interval around sample points.
        lambdaV = (1/2 * delta: delta : len - 1/2 * delta) / len;
        xV = (1-lambdaV) * rasterSegsM(rsNum,3) + lambdaV * rasterSegsM(rsNum,4);
        yV = rasterSegsM(rsNum,2) * xV.^0;
        zV = rasterSegsM(rsNum,1) * xV.^0;
        tmp_lengthV = ones(length(xV),1) * delta;
        areaV = tmp_lengthV * dy;
        surfacePointsM = [surfacePointsM; [xV(:), yV(:), zV(:), areaV(:)]];
    end
    
    planC{indexS.structures}(structNum).DSHPoints = surfacePointsM;
    
end