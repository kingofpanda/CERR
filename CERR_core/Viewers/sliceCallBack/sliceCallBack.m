function sliceCallBack(instr, varargin)
%function sliceCallBack(instr, varargin)
%
%Description:  Creates and updates the slice viewer tool
%called by CERRSliceViewer.
%
%Inputs: Various callback strings, which can be found by
%looking at the switch statements below.
%
%Output:  Updates the slice viewer.
%
%Globals:
%stateS -- contains option and other settings.
%planC      -- the treatment plan in CERR format.
%
% Algorithm: Standard Matlab GUI callback.
% Storage needed:  New 2-D matrices are created and destroyed.
% Internal parameters: None.
% They are all set in the selected options file.
%
%Latest modifications:  VHC, 15 Nov 02.
%                       JOD, 02 Dec 02, numerous.
%                       JOD, 02 Jan 03, .lastDoseTrans bug
%                       JOD, 05 jan 03, eliminated backgroundcolor setting for uicontrol.
%                       JOD, 08 Jan 03, modified loop to add command.
%                       JOD, 13 Jan 03, added stateS visual reference dose fields.
%                       JOD, 16 Jan 03, added Blanco's movie loop command changes.
%                       JOD, 17 Jan 03, added stateS.contouringActive initialization.
%                       JOD, 04 Feb 03, no CT image warning issued only once.
%                        CZ, 11 Feb 03, init variable for 3D
%                       JOD, 23 Feb 03, put putDoseMenu function into it's own file.
%                       JOD, 09 Apr 03, minor bug fix.
%                       JRA, 05 Jun 04, Many changes, see CVS log.
%                        DK, 19 May 06, lot of changes see CERR3.0 bug.doc
%                        DK, 22 Jun 06, removed sliceCallBack('goto')& ('SLIDERTRANS'). Not valid for 3.0
%
%Author: J. O. Deasy, deasy@radonc.wustl.edu
%
% Current version of sliceCallBack replaces previous file:
% Viewers\sliceCallBack.m
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


%======================================================

global planC stateS
format compact
try
    indexS = planC{end};
catch
    if ~isempty(varargin) && iscell(varargin{1})
        planC = varargin{1};
        indexS = planC{end};
    end
end

try
    stateS.doseSetTag    = stateS.optS.displayDoseSet;
    fontsize             = stateS.optS.fontsize;
    uicolor              = stateS.optS.UIColor;
end

%For GUI units:
units = 'normalized';
stateS.regOverlay = 0;
%Frame margin constants.
leftMarginWidth = 195; bottomMarginHeight = 70;

%Temporary.
try
    hCSV = stateS.handle.CERRSliceViewer;
    hCSVA = stateS.handle.CERRSliceViewerAxis;
end
switch upper(instr)
    %Init sliceCallBack Gui.  MUST BE RUN FIRST.
    case 'INIT'
        if ~isempty(planC) & exist('hCSV') & ishandle(hCSV)
            figure(hCSV);
            return;
        end

        %This is a linux issue where the GUI option of uigetfile doesnot work.
        %Setting the UseNativeSystemDialogs to False lets the user select the files
        %uising the GUI

        if isempty(planC)
            clear global planC;
        end
        
        if ~exist('planC','var') || (exist('planC','var')  && isempty(planC))
            %Check java version and add DCM4CHE libraries to Matlab path
            dcm_init_flag = init_ML_DICOM;
        else
            dcm_init_flag = 0;
        end
        
        %Need to redefine stateS as global since init_ML_Dicom clears all
        %globals
        global stateS
        
        stateS.initDicomFlag = dcm_init_flag;
        stateS.fusion = 0;
        stateS.initComplete = 0;
        stateS.planLoaded   = 0;
        stateS.workspacePlan = 0;
        stateS.toggle_rotation = 0;
        stateS.webtrev.isOn = 0;
        stateS.currentKeyPress = 0;
        
        %Store Matlab version under stateS
        stateS.MLVersion = getMLVersion;

        %Set Keypressfunction call back for ALL subsequent figures.
        set(0,'DefaultFigureCreateFcn','set(gcbo,''KeyPressFcn'',''CERRHotKeys'',''keyReleaseFcn'',''CERRHotKeyRelease'')')

        %Detect and store working directory, in case this is the compiled version.
        %This must go before any calls to getCERRPath
        if ispc
            stateS.workingDirectory = [pwd '\'];
        elseif isunix
            stateS.workingDirectory = [pwd '/'];
        else
            stateS.workingDirectory = [];
            error('Non Windows/Unix type system detected.')
        end
        disp(['Working Directory: ' stateS.workingDirectory]);

        %Get options file
        if nargin == 1    %Default to the CERROptions.m file stored in the CERR directory
            pathStr = getCERRPath;
            optName = [pathStr 'CERROptions.m'];
        elseif nargin == 2 & ischar(varargin{:})  %UI to get options file: 'CERRSliceViewer -f'
            if strcmp(lower(varargin{:}),'-f')
                [fname, pathname] = uigetfile('*.m','Select options .m file');
                optName = [pathname fname];
            else
                error('Wrong option string: to use default option file (CERROptions.m) type ''CERRSliceViewer -f''')
            end
        end

        try
            load(fullfile(pathStr, 'planHistory'));
            stateS.planHistory = planHistory;
        catch
            stateS.planHistory = {};
        end

        %Load options file.
        stateS.optS        = opts4Exe(optName);
        stateS.doseSetTag  = stateS.optS.displayDoseSet;
        fontsize           = stateS.optS.fontsize;
        uicolor            = stateS.optS.UIColor;
        stateS.editStructNum = [];
        stateS.handle        = [];
        stateS.handle.sliceStringTrans     = [];
        stateS.handle.CERRSliceViewer      = [];
        stateS.handle.CERRSliceViewerAxis  = [];
        stateS.handle.CERRSurf  = [];  %%CZ init Surf 02-11-03
        stateS.lastDoseArrayMaxValue = [];
        stateS.lastColorMap     = [];
        stateS.doseToggle       =  1;
        stateS.CTToggle         =  1;
        stateS.structToggle     =  1;
        stateS.contourState     = 0;
        stateS.scanWindowState  = 0;
        stateS.annotToggle      = -1;
        
        %Later used for zooming
        stateS.initial_xLims.trans = [];
        stateS.initial_yLims.trans = [];
        stateS.lastZoom.trans      = [];
        stateS.lastSliceNumTrans = -1;
        stateS.lastSliceNumSag = -1;
        stateS.lastSliceNumCor = -1;
        stateS.lastDoseCTTrans = 0;
        stateS.handle.mask = [];
        stateS.noCTWarning = [];  %has the 'no CT image' warning been issued?
        stateS.printMode = 0; %Start with normal CT background, 1 indicates white BG

        % DK
        %Set default doseColorBar state
        stateS.handle.colorbarImage = [];
        stateS.handle.colorbarImageCompare = [];
        stateS.colorbarFrameMax = [];
        stateS.colorbarFrameMaxCompare = [];
        stateS.colorbarFrameMin = [];
        stateS.colorbarFrameMinCompare = [];
        %DK
        
        % Handle for IMRTP GUI
        stateS.handle.IMRTMenuFig = [];

        str1 = ['CERR'];
        position = [5 40 940 620];
        hCSV = figure('tag','CERRSliceViewer','name',str1,'numbertitle','off',...
            'position',position, 'doublebuffer', 'off','CloseRequestFcn',...
            'sliceCallBack(''closeRequest'')','backingstore','off','tag',...
            'CERRSliceViewer', 'renderer', 'zbuffer','ResizeFcn','sliceCallBack(''resize'')');
        figureColor = get(hCSV, 'Color');
        stateS.handle.CERRSliceViewer = hCSV;

        %Set state for different axis click possibilities.
        stateS.gridState = 0;
        stateS.spotlightState = 0;
        stateS.doseQueryState = 0;
        stateS.scanQueryState = 0;
        stateS.imageRegistration = 0;
        stateS.doseProfileState = 0;
        stateS.zoomState = 0;
        stateS.clipState = 0; %wy

        %Turn off default menubar, configure manually.
        set(hCSV,'menubar','none');
        stateS.handle.CERRFileMenu          = putFileMenu(hCSV);
        stateS.handle.CERRViewMenu          = putViewMenu(hCSV);
        stateS.handle.CERRDoseMenu          = putDoseMenu(hCSV);
        IMRTPdir = fileparts(which('IMRTP'));
        if ~isempty(IMRTPdir)
            stateS.handle.CERRIMRTPMenu   = putIMRTPMenu(hCSV);
        end
        stateS.handle.CERRMetricMenu        = putMetricsMenu(hCSV);
        stateS.handle.CERRScanMenu          = putScanMenu(hCSV);
        stateS.handle.CERRStructMenu        = putStructMenu(hCSV);
        BMfileFlag = exist('putPETASsetMenu.m','file'); % B.B. 15/09/2014 replaced putBMmenu.m with putPETASsetMenu.m
        if BMfileFlag
            stateS.handle.CERRBMMenu        = putPETASsetMenu(hCSV);% B.B. 15/09/2014 replaced putBMmenu with putPETASsetMenu
        end
        stateS.handle.CERRHelpMenu          = putHelpMenu(hCSV);

        %Make invisible frames to subdivide screenspace.  For resizing.
        figureWidth = position(3); figureHeight = position(4);
        leftMargin    = uicontrol(hCSV,'units', 'pixels', 'Position',[0 0 leftMarginWidth 1600], 'Style', 'frame', 'Tag', 'leftMargin', 'visible', 'on');
        bottomMargin  = uicontrol(hCSV,'units', 'pixels', 'Position',[leftMarginWidth 0 1600 bottomMarginHeight], 'Style', 'frame', 'Tag', 'bottomMargin', 'visible', 'off');
        mainBody      = uicontrol(hCSV,'units', 'pixels', 'Position',[leftMarginWidth bottomMarginHeight figureWidth-leftMarginWidth figureHeight-bottomMarginHeight],...
            'Style', 'frame', 'Tag', 'mainBody', 'visible', 'off');

        x  = 25; %position of buttons
        dx = 50;
        %Populate left margin Gui Objects.
        leftMarginPos = get(leftMargin, 'position');
        %General purpose control frame
        stateS.handle.controlFrame = uicontrol(hCSV,'units', 'pixels', 'Position', [0 0 leftMarginWidth 400], 'Style', 'frame', 'Tag', 'controlFrame');
        %Warning message.
        %handle = uicontrol(hCSV, 'units', 'pixels', 'Position', [10 600 leftMarginWidth-20 20], 'Style', 'text', 'enable', 'inactive'  , 'String', 'Not for clinical use', 'foregroundcolor', [1 0 0], 'fontsize', 14);

        %CT window and level ui:
        frameWidth = leftMarginWidth - 20;
        stateS.handle.CTSettingsFrame = uicontrol(hCSV,'units','pixels', 'string', 'ctsettingsFrame', 'BackgroundColor',uicolor, 'Position', [10 490 frameWidth 120],'Style','frame', 'Tag','CTSettingsFrame');
        %CT Window text
        stateS.handle.CTWindow = uicontrol(hCSV,'units','pixels','BackgroundColor',uicolor, 'Position',[20 580 (frameWidth-30)/2 25],'String','Window', 'Style','text', 'enable', 'inactive'  ,'Tag','CTWindow');
        %Scan ColorMap
        uicontrol(hCSV,'units','pixels','BackgroundColor',uicolor, 'Position',[(frameWidth-30)/2+20+10 580 (frameWidth-30)/2 25],'String','Colormap', 'Style','text', 'enable', 'inactive'  ,'Tag','CTWindow');
        
        %CT Center Text
        uicontrol(hCSV,'units','pixels','BackgroundColor',uicolor, 'Position',[20 510 (frameWidth-30)/2 25], 'String','Center','Style','text', 'enable', 'inactive', 'Tag','CTWindow');
        %CT Width Text
        uicontrol(hCSV,'units','pixels','BackgroundColor',uicolor,'Position',[(frameWidth-30)/2+20+10 510 (frameWidth-30)/2 25], 'String','Width','Style','text', 'enable', 'inactive' ,'Tag','CTWindow');

        %Presets dropdown.
        stateS.handle.CTPreset = uicontrol(hCSV,'units','pixels', 'BackgroundColor',uicolor,'Position',[20 565 (frameWidth-30)/2 25], 'String',{stateS.optS.windowPresets.name},'Style','popup','Tag','CTPreset', 'callback','sliceCallBack(''CTPreset'');','tooltipstring','Select Preset Window');
        %Base Colormap Presets dropdown.
        stateS.handle.BaseCMap = uicontrol(hCSV,'units','pixels', 'BackgroundColor',uicolor,'Position',[(frameWidth-30)/2+20+10 565 (frameWidth-30)/2 25], 'String',{stateS.optS.scanColorMap.name},'Style','popup','Tag','CMapPreset', 'callback','sliceCallBack(''BaseColorMap'');','tooltipstring','Select Scan Color Map','Enable','on');
        %CTLevel edit box
        stateS.handle.CTLevel = uicontrol(hCSV,'units','pixels', 'BackgroundColor',uicolor,'Position',[20 500 (frameWidth-30)/2 20], 'String',num2str(stateS.optS.CTLevel),'Style','edit','Tag','CTLevel', 'callback','sliceCallBack(''CTLevel'');','tooltipstring','Change CT window center');
        %CT Width edit box.
        stateS.handle.CTWidth = uicontrol(hCSV,'units','pixels','BackgroundColor',uicolor, 'Position',[(frameWidth-30)/2+20+10 500 (frameWidth-30)/2 20], 'String',num2str(stateS.optS.CTWidth),'Style','edit','Tag','CTWidth', 'callback','sliceCallBack(''CTWidth'');','tooltipstring','Change CT window width');
        %CT Level/Width pushbutton
        stateS.handle.CTLevelWidthInteractive = uicontrol(hCSV,'units','pixels','BackgroundColor',uicolor, 'Position',[20 540 frameWidth-20 20], 'String','Interactive Windowing','Style','toggle','Tag','CTInteractiveWindowing', 'callback','sliceCallBack(''TOGGLESCANWINDOWING'');','tooltipstring','Drag mouse on view to change display window');

        %Loop controls:
        stateS.handle.loopTrans = uicontrol(hCSV,'units',units,'pos',[0.11*512, 375 dx-5, 20]/512,'string','Loop','fontsize',fontsize, 'BackgroundColor',uicolor, 'callback','sliceCallBack(''loop'')','interruptible','on','tooltipstring','Loop through slices', 'enable', 'off');
        stateS.handle.unloopTrans = uicontrol(hCSV,'units',units,'pos',[0.11*512, 375 dx, 20]/512,'string','Stop loop','fontsize',fontsize, 'BackgroundColor',uicolor,'callback','set(gcbo,''userdata'',0)','userdata',1,'visible','off');
        %Ruler Control.
        stateS.handle.rulerTrans = uicontrol(hCSV,'units',units,'pos',[0.11*512, 345 dx - 25, 20]/512,'string','Ruler','fontsize',fontsize, 'BackgroundColor',uicolor, 'callback','sliceCallBack(''toggleRuler'');','Style','checkbox','value',0,'max',1,'min',0,'tooltipstring','Draw ruler line.');
        %Zoom Controls.
        [I,map] = imread('tool_zoom.gif','gif');
        zoomImg = ind2rgb(I,map);
        stateS.handle.zoom = uicontrol(hCSV,'units',units,'style', 'togglebutton', 'position',[0.018*512, 375, dx - 35, 20]/512,'cdata',zoomImg,'BackgroundColor',uicolor, 'callback','sliceCallBack(''togglezoom'')','interruptible','on','tooltipstring', 'Toggle ZoomIn(Left)/ZoomOut(Right)');

        [I,map] = imread('reset_zoom.GIF','gif');
        resetZoomImg = ind2rgb(I,map);
        stateS.handle.resetZoom = uicontrol(hCSV,'units',units,'style', 'PushButton', 'position',[0.018*512+dx/2, 375, dx - 35, 20]/512,'cdata',resetZoomImg,'BackgroundColor',uicolor, 'callback','sliceCallBack(''ZOOMRESET'')','interruptible','on','tooltipstring', 'Reset Zoom to Original');

        %         stateS.handle.zoom = uicontrol(hCSV,'units',units,'style', 'togglebutton', 'pos',[0.018*512, 375 dx - 10, 20]/512,'string','Zoom Mode','fontsize',fontsize, 'BackgroundColor',uicolor, 'callback','sliceCallBack(''togglezoom'')','interruptible','on','tooltipstring', 'Toggle on/off zoom');
        %   stateS.handle.zoomOutTrans = uicontrol(hCSV,'units',units,'pos',[0.018*512, 345 dx - 10, 20]/512,'string','Zoom out','fontsize',fontsize, 'BackgroundColor',uicolor, 'callback','sliceCallBack(''zoomout'')','interruptible','on','tooltipstring','Zoom out by factor optS.zoomFactor');

        %Temporary next/prev slice buttons.
        stateS.handle.buttonUp = uicontrol(hCSV,'units',units,'style', 'pushbutton', 'pos',[0.018*512, 345 dx/2-10, 20]/512,'string','S+','fontsize',fontsize, 'BackgroundColor',uicolor, 'callback','sliceCallBack(''ChangeSlc'',''nextslice'')','interruptible','on');
        stateS.handle.buttonDwn = uicontrol(hCSV,'units',units,'style', 'pushbutton', 'pos',[0.018*512+dx/2, 345 dx/2-10, 20]/512,'string','S-','fontsize',fontsize, 'BackgroundColor',uicolor, 'callback','sliceCallBack(''ChangeSlc'',''prevslice'')','interruptible','on');

        % Capture Button on CERR
        [I,map] = imread('capture.GIF','gif');
        captureImg = ind2rgb(I,map);
        stateS.handle.capture = uicontrol(hCSV,'units',units,'style', 'pushbutton', 'position',[0.17*512, 345 dx/2-10, 20]/512,'Cdata',captureImg, 'BackgroundColor',uicolor, 'callback','LabBookGui(''CAPTURE'');','interruptible','on','tooltipstring', 'CERR Screen Capture');

        set([stateS.handle.loopTrans, stateS.handle.unloopTrans, stateS.handle.zoom, stateS.handle.resetZoom, stateS.handle.rulerTrans stateS.handle.buttonUp stateS.handle.buttonDwn stateS.handle.capture], 'units', 'pixels');
        %Colorbar Axis:
        stateS.handle.doseColorbar.trans = axes('units', 'pixels', 'position', [leftMarginWidth+5 bottomMarginHeight+42 50 380], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'Tag', 'Colorbar', 'visible', 'off');
        %Transparency/Blending + Labels.
        stateS.handle.sliderTransAlpha = uicontrol(hCSV,'units','pixels','Position',[leftMarginWidth+10 505+25 25 60],'style','slider','BackgroundColor',uicolor, 'min',0,'max',1,'Value',stateS.optS.initialTransparency,'callback','sliceCallBack(''sliderTransAlpha'');','sliderstep',[.1,.1],'tag','transSliderAlpha','tooltipstring','Change Transparency');
        uicontrol(hCSV,'units','pixels','Position',[leftMarginWidth+5 565+25 35 20],'String','Dose','Style','text', 'enable', 'inactive', 'BackgroundColor', figureColor,'tag','sliderInit');
        uicontrol(hCSV,'units','pixels','Position',[leftMarginWidth+5 490+20 35 20],'String','Scan','Style','text', 'enable', 'inactive', 'BackgroundColor', figureColor,'tag','sliderInit');
        %Set up all axes.  Position is temporary, resize will set it.
        wid = (figureWidth-leftMarginWidth-70-10)/4;
        hig = (figureHeight-bottomMarginHeight-20-20)/3;
        %Prepare a basic CERR axis info struct.
        aI = axisInfoFactory;
        aI.coord   = 0;
        aI.view    = 'transverse';
        stateS.handle.CERRSliceViewerAxis = axes('userdata', aI, 'parent', hCSV, 'units', 'pixels', 'position', [leftMarginWidth+60 bottomMarginHeight+10 figureWidth-leftMarginWidth-70-wid-10 figureHeight-bottomMarginHeight-20], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'buttondownfcn', 'sliceCallBack(''axisClicked'')', 'nextplot', 'add', 'linewidth', 2);
        stateS.handle.CERRAxis(1) = stateS.handle.CERRSliceViewerAxis;
        aI.view    = 'sagittal';
        stateS.handle.CERRAxis(2) = axes('userdata', aI, 'parent', hCSV, 'units', 'pixels', 'position', [figureWidth-wid-10 bottomMarginHeight+30+2*hig wid hig], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'buttondownfcn', 'sliceCallBack(''axisClicked'')', 'nextplot', 'add', 'yDir', 'reverse', 'xDir', 'reverse', 'linewidth', 2);
        aI.view    = 'coronal';
        stateS.handle.CERRAxis(3) = axes('userdata', aI, 'parent', hCSV, 'units', 'pixels', 'position', [figureWidth-wid-10 bottomMarginHeight+20+hig wid hig], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'buttondownfcn', 'sliceCallBack(''axisClicked'')', 'nextplot', 'add', 'yDir', 'reverse', 'linewidth', 2);
        aI.view    = 'legend';
        stateS.handle.CERRAxis(4) = axes('userdata', aI,'parent', hCSV, 'units', 'pixels', 'position', [figureWidth-wid-10 bottomMarginHeight+10 wid hig], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'buttondownfcn', 'sliceCallBack(''axisClicked'')', 'nextplot', 'add', 'yDir', 'reverse', 'linewidth', 2);
        
        if stateS.MLVersion >= 8.4
            set(stateS.handle.CERRAxis,'ClippingStyle','rectangle')
        end
        stateS.layout = 5;
        stateS.Oldlayout = 5;
               
        %The NUMBER of the currentAxis. NOT handle.
        stateS.currentAxis = 1;
        stateS.lastAxis    = 1;

        %Populate bottom margin Gui Objects.
        %Command line editbox.
        stateS.handle.commandLine = uicontrol(hCSV,'units',units,'BackgroundColor',[1 1 1], 'pos',[145 30 90 18]/512, 'String','help','Style','edit','Tag','command', 'callback','sliceCallBack(''command'');','horizontalalignment','left');
        hCmd = uicontrol(hCSV,'units',units,'Position',[110 25 30 20]/512,'Style','text', 'enable', 'inactive'  ,'String','Command:', 'horizontalAlignment', 'left', 'Backgroundcolor', figureColor);
        set([stateS.handle.commandLine, hCmd], 'units', 'pixels');

        stateS.handle.fractionGroupIDTrans = uicontrol('tag','FractionGroupID','units','pixels','Position', [leftMarginWidth 1 220 20],'Style','edit','String',[''], 'value', 1, 'enable', 'inactive', 'horizontalAlignment', 'left');
        stateS.handle.doseDescriptionTrans = uicontrol('tag','DoseDescription','units','pixels','Position', [leftMarginWidth+220 1 220 20],'Style','edit','String',[''], 'value', 1, 'enable', 'inactive', 'horizontalAlignment', 'left');
        stateS.handle.CERRStatus = uicontrol('tag','DoseDescription','units','pixels','Position', [leftMarginWidth+440 1 1600 20],'Style','edit','String','Welcome to CERR.  Select Open or Import from the file menu.', 'ForegroundColor',[1 0 0], 'value', 1, 'enable', 'inactive', 'horizontalAlignment', 'left');
        tooltipMsg = 'Use "hide name" or "show name" in command-line to toggle';
        stateS.handle.patientName = uicontrol('tag','PatientName','units',units,'Position',[370 25 140 15]/512,'Style','text','String',[''], 'enable', 'inactive','TooltipString',tooltipMsg,'BackgroundColor',figureColor);
        if stateS.optS.displayPatientName == 0
            set(stateS.handle.patientName,'Visible', 'off');
        end
        set(0,'CurrentFigure',stateS.handle.CERRSliceViewer);
        
        %Change Panel-Layout according to CERROptions
        sliceCallBack('layout',stateS.optS.layout)
        
        return

        %Reinitalize variables, a new planC has been loaded.
    case 'LOAD'

        planC = updatePlanFields(planC);
        indexS = planC{end};
        
        % Quality assure
        quality_assure_planC

        %Set Patient-Name string
        patName = planC{indexS.scan}(1).scanInfo(1).patientName;
        patName = ['Patient: ',patName];
        set(stateS.handle.patientName,'string',patName)

        %Close all previously opened CERR windows.
        closeAllCERRFigures('selective');

        %Destroy splashscreen if it exists.
        try
            delete(findobj('Tag','CERR_splashAxis'));
        end
        stateS.doseSet              = [];
        structIndx = getStructureSetAssociatedScan(1);
        if ~isempty(structIndx)
            stateS.structSet = structIndx;
        else
            stateS.structSet = [];
        end

        %Check for remotely stored variables
        flag = checkAndSetRemotePath;
        if flag
            errordlg('Remote files are required to be under ...planDir\planName_store subdirectory. Cannot proceed.','Could not find remotely stored files','modal')
            CERRStatusString('Remote files missing. Cannot proceed.')
            return;
        end

        %Save the current required remote files in stateS
        stateS.reqdRemoteFiles = {};
        % reqdRemoteFiles = listRemoteFiles(planC, 0);
        reqdRemoteFiles = listRemoteScanAndDose(planC);
        if ~isempty(reqdRemoteFiles)
            for i=1:length(reqdRemoteFiles)
                stateS.reqdRemoteFiles{i} = fullfile(reqdRemoteFiles(i).remotePath,reqdRemoteFiles(i).filename);
            end
        end
        
        %Check whether uniformized data is in cellArray format.
        if ~isempty(planC{indexS.structureArray}) && iscell(planC{indexS.structureArray}(1).indicesArray)
            planC = setUniformizedData(planC,planC{indexS.CERROptions});
            indexS = planC{end};
        end

        if length(planC{indexS.structureArrayMore}) ~= length(planC{indexS.structureArray})
            for saNum = 1:length(planC{indexS.structureArray})
                if saNum == 1
                    planC{indexS.structureArrayMore} = struct('indicesArray', {[]},...
                        'bitsArray', {[]},...
                        'assocScanUID',{planC{indexS.structureArray}(saNum).assocScanUID},...
                        'structureSetUID', {planC{indexS.structureArray}(saNum).structureSetUID});

                else
                    planC{indexS.structureArrayMore}(saNum) = struct('indicesArray', {[]},...
                        'bitsArray', {[]},...
                        'assocScanUID',{planC{indexS.structureArray}(saNum).assocScanUID},...
                        'structureSetUID', {planC{indexS.structureArray}(saNum).structureSetUID});
                end
            end
        end
        
        stateS                      = getDoseSet(stateS, planC);
        stateS.scanSet              = 1; %Implemented for multiple scans.
        stateS.scanChkFlag          = 1; %DK Added for scan menu manual flag
        stateS.doseChkFlag          = 1; %DK Added for dose menu manual flag
        stateS.planMerged           = 0; %DK Added plan Merged flag
        stateS.CTChanged            = 1;
        stateS.doseSetChanged       = 1;
        stateS.doseDisplayChanged   = 1;
        stateS.CTDisplayChanged     = 1;
        stateS.doseChanged          = 1;
        stateS.structsChanged       = 1;
        
        %Set default imageRegistration state.
        stateS.imageRegistrationBaseDataset = 1;
        stateS.imageRegistrationBaseDatasetType = 'scan';
        stateS.imageRegistrationMovDataset = 2;
        stateS.imageRegistrationMovDatasetType = 'scan';
        stateS.showPlaneLocators = 1;
        stateS.showNavMontage = 0;
        
        if ~(stateS.planLoaded && stateS.layout == 8)
            
            %Reinitalize menus.
            stateS.handle.CERRFileMenu    = putFileMenu(hCSV);
            stateS.handle.CERRViewMenu    = putViewMenu(hCSV);
            stateS.handle.CERRDoseMenu    = putDoseMenu(hCSV);
            IMRTPdir = fileparts(which('IMRTP'));
            if ~isempty(IMRTPdir)
                stateS.handle.CERRIMRTPMenu   = putIMRTPMenu(hCSV);
            end
            stateS.handle.CERRMetricMenu  = putMetricsMenu(hCSV);
            stateS.handle.CERRScanMenu    = putScanMenu(hCSV);
            stateS.handle.CERRStructMenu  = putStructMenu(hCSV);          
            BMfileFlag = exist('putPETASsetMenu.m','file'); % B.B. 15/09/2014 replaced putBMmenu.m with putPETASsetMenu.m
            if BMfileFlag 
                stateS.handle.CERRBMMenu        = putPETASsetMenu(hCSV);% B.B. 15/09/2014 replaced putBMmenu with putPETASsetMenu
            end                
            stateS.handle.CERRHelpMenu    = putHelpMenu(hCSV);
            
            %Wipe out the contents of all axes.
            for i = 1:length(stateS.handle.CERRAxis)
                hAxis       = stateS.handle.CERRAxis(i);
                aI          = axisInfoFactory;
                aI.view     = getAxisInfo(hAxis, 'view');
                aI.coord    = 0;
                aI.xRange   = [];
                aI.yRange   = [];
                set(stateS.handle.CERRAxis(i), 'userdata', aI);
                kids = get(stateS.handle.CERRAxis(i), 'children');
                for j=1:length(kids)
                    try, delete(kids(j)), end
                end
            end
            
            %Reset axis scaling in case an old plan was in axes. Must be done
            %before in-axis labels are created, else scaling is incorrect when
            %plans are sequentially loaded.
            set(stateS.handle.CERRAxis, 'xLim', [0 1], 'yLim', [0 1]);
            set(stateS.handle.CERRAxis, 'XLimMode', 'auto', 'YLimMode', 'auto');
            
            %Create in-axis labels for each axis.
            tickV = linspace(0.02,0.1,6);
            for i=1:length(stateS.handle.CERRAxis)
                stateS.handle.CERRAxisLabel1(i) = text('parent', stateS.handle.CERRAxis(i), 'string', '', 'position', [.02 .98 0], 'color', [1 0 0], 'units', 'normalized', 'visible', 'off', 'horizontalAlignment', 'left', 'verticalAlignment', 'top');
                stateS.handle.CERRAxisLabel2(i) = text('parent', stateS.handle.CERRAxis(i), 'string', '', 'position', [.90 .98 0], 'color', [1 0 0], 'units', 'normalized', 'visible', 'off', 'horizontalAlignment', 'left', 'verticalAlignment', 'top');
                for j = 1:6
                    ticks1V(j) = line([tickV(j) tickV(j)], [0.01 0.03], [2 2], 'parent', stateS.handle.CERRAxis(i), 'color', 'y', 'hittest', 'off', 'visible', 'off');
                    ticks2V(j) = line([0.01 0.03], [tickV(j) tickV(j)], [2 2], 'parent', stateS.handle.CERRAxis(i), 'color', 'y', 'hittest', 'off', 'visible', 'off');
                end
                stateS.handle.CERRAxisTicks1(i,:) = ticks1V;
                stateS.handle.CERRAxisTicks2(i,:) = ticks2V; 
                stateS.handle.CERRAxisScale1(i) = line([0.02 0.1], [0.02 0.02], [2 2], 'parent', stateS.handle.CERRAxis(i), 'color', [0.7 0.7 0.7], 'hittest', 'off', 'visible', 'off');
                stateS.handle.CERRAxisScale2(i) = line([0.02 0.02], [0.02 0.1], [2 2], 'parent', stateS.handle.CERRAxis(i), 'color', [0.7 0.7 0.7], 'hittest', 'off', 'visible', 'off');
                stateS.handle.CERRAxisLabel3(i) = text('parent', stateS.handle.CERRAxis(i), 'string', '5', 'position', [0.02 0.1 0], 'color', 'y', 'units', 'data', 'visible', 'off', 'hittest', 'off','fontSize',8);
                stateS.handle.CERRAxisLabel4(i) = text('parent', stateS.handle.CERRAxis(i), 'string', '5', 'position', [0.1 0.02 0], 'color', 'y', 'units', 'data', 'visible', 'off', 'hittest', 'off','fontSize',8);
                %stateS.handle.CERRAxisPlaneLocator1(i)
                %stateS.handle.CERRAxisPlaneLocator2(i)
                
                aI = get(stateS.handle.CERRAxis(i), 'userdata');
                aI.miscHandles = [aI.miscHandles stateS.handle.CERRAxisLabel1(i) stateS.handle.CERRAxisLabel2(i) stateS.handle.CERRAxisLabel3(i) stateS.handle.CERRAxisLabel4(i) stateS.handle.CERRAxisScale1(i) stateS.handle.CERRAxisScale2(i) stateS.handle.CERRAxisTicks1(i,:) stateS.handle.CERRAxisTicks2(i,:)];
                set(stateS.handle.CERRAxis(i), 'userdata', aI);
            end
            
            if ~isfield(stateS, 'doseAlphaValue')
                stateS.doseAlphaValue.trans = stateS.optS.initialTransparency;
            end
            
            %Handle case of no scan.
            if isempty(planC{indexS.scan})
                warning('Scan not present, creating dummy scan based on structures and dose.')
                planC = createDummyScan(planC);
                planC = setUniformizedData(planC);
            end
            
            %Uniformize the plan if necessary.
            for i=1:length(planC{indexS.scan})
                if ~isUniformized(i, planC)
                    planC = setUniformizedData(planC);
                    break;
                end
            end
            % DK
            
            %Clear cache if it was saved in planC.
            try
                for i=1:length(planC{indexS.dose})
                    planC = clearCache(planC, i);
                end
            end
            numSlices = length(planC{indexS.scan}(stateS.scanSet).scanInfo);
            
            %Display warning for non-square voxels
            nonSquareVoxelWarn(planC)
            
        else % FOR COHORT REVIEW
            
            setAxisInfo(stateS.handle.CERRAxis(1), 'xRange', [], 'yRange', []);
            
        end

        %Display middle slice in each dimension first.
        [xV, yV, zV] = getScanXYZVals(planC{indexS.scan}(stateS.scanSet));
        for i=1:length(stateS.handle.CERRAxis)
            hAxis = stateS.handle.CERRAxis(i);
            view = getAxisInfo(hAxis, 'view');
            try
                %Get the transM for this scan.
                transM = getTransM(planC{indexS.scan}(stateS.scanSet), planC);
            catch
                transM = [];
            end

            if isempty(transM)==0 & isequal(transM,eye(4))==0

                %Get the 8 corners of the scan;
                [xCorner, yCorner, zCorner] = meshgrid([xV(1) xV(end)], [yV(1) yV(end)], [zV(1) zV(end)]);

                %Apply the transM to get the new extremes of x,y,z.
                [xT, yT, zT] = applyTransM(transM, xCorner(:), yCorner(:), zCorner(:));

                switch upper(view)
                    case 'TRANSVERSE'
                        setAxisInfo(hAxis, 'xRange', [min(xT) max(xT)], 'yRange', [min(yT) max(yT)], 'coord', mean(zT));
                    case 'SAGITTAL'
                        setAxisInfo(hAxis, 'xRange', [min(yT) max(yT)], 'yRange', [min(zT) max(zT)], 'coord', mean(xT));
                    case 'CORONAL'
                        setAxisInfo(hAxis, 'xRange', [min(xT) max(xT)], 'yRange', [min(zT) max(zT)], 'coord', mean(yT));
                end
            else
                switch view
                    case 'transverse'
                        setAxisInfo(hAxis, 'coord', zV(ceil(length(zV)/2)));
                    case 'sagittal'
                        setAxisInfo(hAxis, 'coord', xV(ceil(length(xV)/2)));
                    case 'coronal'
                        setAxisInfo(hAxis, 'coord', yV(ceil(length(yV)/2)));
                end
            end

            %Initialize context menu.
            CERRAxisMenu(hAxis);
        end

        stateS.supInfScansCreated = 0; %the superior and inferior portions of the CT scan for sag/cor viewing have not yet been created.
        %Fire up Navigation.  Marked for removal-> pane.
        try
            if strcmpi(stateS.optS.navigationMontage,'yes')                
                navigationMontage('init',1);
                stateS.showNavMontage = 1;
            end
        catch
            delete(findobj('Tag', 'TMWWaitbar'));
        end
        
        % Save scan statistics for fast image rendering
        for scanNum = 1:length(planC{indexS.scan})
            scanUID = ['c',repSpaceHyp(planC{indexS.scan}(scanNum).scanUID(max(1,end-61):end))];
            stateS.scanStats.minScanVal.(scanUID) = single(min(planC{indexS.scan}(scanNum).scanArray(:)));
            stateS.scanStats.maxScanVal.(scanUID) = single(max(planC{indexS.scan}(scanNum).scanArray(:)));
        end
        
        %If any duplicates, remove them and make new entry first.
        if any(strcmpi(stateS.planHistory, stateS.CERRFile));
            ind = find(strcmpi(stateS.planHistory, stateS.CERRFile));
            stateS.planHistory(ind) = [];
        end
        stateS.planHistory = {stateS.CERRFile, stateS.planHistory{1:end}};
        if length(stateS.planHistory) > 4
            stateS.planHistory = {stateS.planHistory{1:4}};
        end
        planHistory = stateS.planHistory;
        try
            %Save functions... modified to work with matlab 7
            saveOpt = getSaveInfo;
            if ~isempty(saveOpt);
                save(fullfile(getCERRPath, 'planHistory'), 'planHistory', saveOpt);
            else
                save(fullfile(getCERRPath, 'planHistory'), 'planHistory');
            end
            %             save(fullfile(getCERRPath, 'planHistory'), 'planHistory');
        catch
            warning('Unable to save plan history.  No history will be shown in file menu.');
        end
        
        % Set Window and Width from DICOM header, if available
        if isfield(planC{indexS.scan}(stateS.scanSet).scanInfo(1),'DICOMHeaders') && isfield(planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders,'WindowCenter') && isfield(planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders,'WindowWidth')
            CTLevel = planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders.WindowCenter(end);
            CTWidth = planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders.WindowWidth(end);
            if isnumeric(CTLevel) && isnumeric(CTWidth)
                set(stateS.handle.CTLevel,'string',num2str(CTLevel(1)))
                set(stateS.handle.CTWidth,'string',num2str(CTWidth(1)))
                sliceCallBack('CTLevel')
                sliceCallBack('CTWidth')
            end
        end
        
        %Update status string
        [pathstr, name, ext] = fileparts(stateS.CERRFile);
        CERRStatusString(['Loaded ' name ext '. Ready.']);
        %Place filename in window title.
        set(hCSV, 'name', ['CERR:  ' stateS.CERRFile]);
        stateS.planLoaded = 1;
        %Refresh.
        CERRRefresh
        sliceCallBack('resize');
        figure(hCSV); % Bring CERR upfor

    case 'RESIZE'
        %CERR Window has been resized.  Adjust according to current layout.
        try
            pos = get(hCSV, 'position');
            figureWidth = pos(3); figureHeight = pos(4);
            nAxes = length(stateS.handle.CERRAxis);
            if isequal(stateS.Oldlayout,7) && ~isequal(stateS.layout,7)
                doseCompare('exit');
                return
            elseif isequal(stateS.Oldlayout,6) && ~isequal(stateS.layout,6)
                scanCompare('exit');
                return
            end

            switch stateS.layout
                case 1 % 1 Large panel
                    wid = (figureWidth-leftMarginWidth-70);
                    hig = (figureHeight-bottomMarginHeight-20);
                    set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10 wid hig]);
                    bottomAxes = setdiff(1:nAxes, [1]);
                    set(stateS.handle.CERRAxisLabel2(1),'position', [(wid-30)/wid .98 0]);
                case 2 % 1 Large panel with bar
                    wid = (figureWidth-leftMarginWidth-70-10)/5;
                    hig = (figureHeight-bottomMarginHeight-20);
                    set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10 wid*4 hig]);
                    set(stateS.handle.CERRAxis(4), 'position', [leftMarginWidth+60+10+wid*4 bottomMarginHeight+10 wid hig]);
                    bottomAxes = setdiff(1:nAxes, [1 4]);
                    set(stateS.handle.CERRAxisLabel2(1),'position', [(wid*4-30)/wid*4 .98 0]);

                case 3 % 2 Medium panels
                    wid = (figureWidth-leftMarginWidth-70-10)/2;
                    hig = (figureHeight-bottomMarginHeight-20);
                    set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10 wid hig]);
                    set(stateS.handle.CERRAxis(2), 'position', [leftMarginWidth+wid+10+60 bottomMarginHeight+10 wid hig]);
                    bottomAxes = setdiff(1:nAxes, [1 2]);
                    set(stateS.handle.CERRAxisLabel2(1),'position', [(wid-30)/wid .98 0]);
                    set(stateS.handle.CERRAxisLabel2(2),'position', [(wid-30)/wid .98 0]);

                case 4 %4 Medium panels
                    wid = (figureWidth-leftMarginWidth-70-10)/2;
                    hig = (figureHeight-bottomMarginHeight-20-10)/2;
                    set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10+10+hig wid hig]);
                    set(stateS.handle.CERRAxis(2), 'position', [leftMarginWidth+60+10+wid bottomMarginHeight+10+10+hig wid hig]);
                    set(stateS.handle.CERRAxis(3), 'position', [leftMarginWidth+60 bottomMarginHeight+10 wid hig]);
                    set(stateS.handle.CERRAxis(4), 'position', [leftMarginWidth+60+10+wid bottomMarginHeight+10 wid hig]);
                    bottomAxes = setdiff(1:nAxes, [1 2 3 4]);
                    set(stateS.handle.CERRAxisLabel2(1),'position', [(wid-30)/wid .98 0]);
                    set(stateS.handle.CERRAxisLabel2(2),'position', [(wid-30)/wid .98 0]);
                    set(stateS.handle.CERRAxisLabel2(3),'position', [(wid-30)/wid .98 0]);


                case 5 % 1 Large, 3 small panels.
                    wid = (figureWidth-leftMarginWidth-70-10)/4;
                    hig = (figureHeight-bottomMarginHeight-20-20)/3;
                    set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10 figureWidth-leftMarginWidth-70-wid-10 figureHeight-bottomMarginHeight-20], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'color', [0 0 0]);
                    set(stateS.handle.CERRAxis(2), 'position', [figureWidth-wid-10 bottomMarginHeight+30+2*hig wid hig], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'color', [0 0 0]);
                    set(stateS.handle.CERRAxis(3), 'position', [figureWidth-wid-10 bottomMarginHeight+20+hig wid hig], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'color', [0 0 0]);
                    set(stateS.handle.CERRAxis(4), 'position', [figureWidth-wid-10 bottomMarginHeight+10 wid hig], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'color', [0 0 0]);
                    bottomAxes = setdiff(1:nAxes, [1 2 3 4]);
                    set(stateS.handle.CERRAxisLabel2(1),'position', [(((figureWidth-leftMarginWidth-70-wid-10)-30)/(figureWidth-leftMarginWidth-70-wid-10)) .98 0]);
                    set(stateS.handle.CERRAxisLabel2(2),'position', [(wid-30)/wid .98 0]);
                    set(stateS.handle.CERRAxisLabel2(3),'position', [(wid-30)/wid .98 0]);
                    
                case {6,7} % Tomotherapy comparison mode
                    wid = (figureWidth-leftMarginWidth-70-10)/5;
                    hig = (figureHeight-bottomMarginHeight-20)/2;
                    if stateS.doseCompare.newAxis == 1
                        set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10+10+hig 2*wid-5 hig]);
                        set(stateS.handle.CERRAxis(5), 'position', [leftMarginWidth+60+2*wid+5 bottomMarginHeight+10+10+hig 2*wid-5 hig]);
                        bottomAxes = setdiff(1:nAxes, [1 4 5]);
                        xPosStr = (2*wid-5);
                        set(stateS.handle.CERRAxisLabel2(1),'position', [(xPosStr-30)/xPosStr .98 0]);
                        set(stateS.handle.CERRAxisLabel2(2),'position', [(xPosStr-30)/xPosStr .98 0]);

                    elseif stateS.doseCompare.newAxis == 2
                        set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10+10+hig 2*wid-5 hig]);
                        set(stateS.handle.CERRAxis(5), 'position', [leftMarginWidth+60+2*wid+5 bottomMarginHeight+10+10+hig 2*wid-5 hig]);
                        set(stateS.handle.CERRAxis(6), 'position', [leftMarginWidth+60 bottomMarginHeight+10 2*wid-5 hig]);
                        bottomAxes = setdiff(1:nAxes, [1 4 5 6]);
                        xPosStr = (2*wid-5);
                        set(stateS.handle.CERRAxisLabel2(1),'position', [(xPosStr-30)/xPosStr .98 0]);
                        set(stateS.handle.CERRAxisLabel2(5),'position', [(xPosStr-30)/xPosStr .98 0]);
                        set(stateS.handle.CERRAxisLabel2(6),'position', [(xPosStr-30)/xPosStr .98 0]);

                    elseif stateS.doseCompare.newAxis == 3
                        set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+10+10+hig 2*wid-5 hig]);
                        set(stateS.handle.CERRAxis(5), 'position', [leftMarginWidth+60+2*wid+5 bottomMarginHeight+10+10+hig 2*wid-5 hig]);
                        set(stateS.handle.CERRAxis(6), 'position', [leftMarginWidth+60 bottomMarginHeight+10 2*wid-5 hig]);
                        set(stateS.handle.CERRAxis(7), 'position', [leftMarginWidth+60+2*wid+5 bottomMarginHeight+10 2*wid-5 hig]);
                        bottomAxes = setdiff(1:nAxes, [1 4 5 6 7]);
                    end
                    
                    % Axis for legend bar
                    set(stateS.handle.CERRAxis(4), 'position', [leftMarginWidth+60+wid*4+10 bottomMarginHeight+10+10+hig wid-5 hig]);
                    % Axis for colorbar
                    if isfield(stateS.handle.doseColorbar,'Compare')
                        set(stateS.handle.doseColorbar.Compare, 'position', [leftMarginWidth+60+wid*4+20 bottomMarginHeight+30 50 hig-40]);
                    end
                    
                case 8 % Cohort review
                    wid = (figureWidth-leftMarginWidth-70-4*10)/4;
                    hig = (figureHeight-bottomMarginHeight-20-2*10)/4;
                    try % to take care of error if number of axes is less than 16
                        % Top 4 windows
                        set(stateS.handle.CERRAxis(1), 'position', [leftMarginWidth+60 bottomMarginHeight+4*10+3*hig wid hig]);
                        set(stateS.handle.CERRAxis(2), 'position', [leftMarginWidth+60+10+wid bottomMarginHeight+4*10+3*hig wid hig]);
                        set(stateS.handle.CERRAxis(3), 'position', [leftMarginWidth+60+2*10+2*wid bottomMarginHeight+4*10+3*hig wid hig]);
                        set(stateS.handle.CERRAxis(4), 'position', [leftMarginWidth+60+3*10+3*wid bottomMarginHeight+4*10+3*hig wid hig]);
                        % Middle 4 windows
                        set(stateS.handle.CERRAxis(5), 'position', [leftMarginWidth+60 bottomMarginHeight+3*10+2*hig wid hig]);
                        set(stateS.handle.CERRAxis(6), 'position', [leftMarginWidth+60+10+wid bottomMarginHeight+3*10+2*hig wid hig]);
                        set(stateS.handle.CERRAxis(7), 'position', [leftMarginWidth+60+2*10+2*wid bottomMarginHeight+3*10+2*hig wid hig]);
                        set(stateS.handle.CERRAxis(8), 'position', [leftMarginWidth+60+3*10+3*wid bottomMarginHeight+3*10+2*hig wid hig]);
                        % Middle 4 windows
                        set(stateS.handle.CERRAxis(9), 'position', [leftMarginWidth+60 bottomMarginHeight+2*10+1*hig wid hig]);
                        set(stateS.handle.CERRAxis(10), 'position', [leftMarginWidth+60+10+wid bottomMarginHeight+2*10+1*hig wid hig]);
                        set(stateS.handle.CERRAxis(11), 'position', [leftMarginWidth+60+2*10+2*wid bottomMarginHeight+2*10+1*hig wid hig]);
                        set(stateS.handle.CERRAxis(12), 'position', [leftMarginWidth+60+3*10+3*wid bottomMarginHeight+2*10+1*hig wid hig]);
                        % Bottom 4 windows
                        set(stateS.handle.CERRAxis(13), 'position', [leftMarginWidth+60 bottomMarginHeight+1*10+0*hig wid hig]);
                        set(stateS.handle.CERRAxis(14), 'position', [leftMarginWidth+60+10+wid bottomMarginHeight+1*10+0*hig wid hig]);
                        set(stateS.handle.CERRAxis(15), 'position', [leftMarginWidth+60+2*10+2*wid bottomMarginHeight+1*10+0*hig wid hig]);
                        set(stateS.handle.CERRAxis(16), 'position', [leftMarginWidth+60+3*10+3*wid bottomMarginHeight+1*10+0*hig wid hig]);
                    end
                    
                    bottomAxes = setdiff(1:nAxes, 1:16);
                    for indAxis = 1:nAxes
                        set(stateS.handle.CERRAxisLabel2(indAxis),'position', [(wid-30)/wid .98 0]);
                    end
                    
                    
            end

            spacing = 55;
            for i=1:length(bottomAxes)
                set(stateS.handle.CERRAxis(bottomAxes(i)), 'position', [leftMarginWidth+205+55*i bottomMarginHeight-45 50 50]);
            end

            %Refresh scaling.
            for i = 1:length(stateS.handle.CERRAxis)
                zoomToXYRange(stateS.handle.CERRAxis(i));
                showScale(stateS.handle.CERRAxis(i), i);
            end

            %Draw Legend.
            for i=1:length(stateS.handle.CERRAxis)
                hAxis = stateS.handle.CERRAxis(i);
                view = getAxisInfo(hAxis, 'view');
                if strcmpi(view, 'legend')
                    showCERRLegend(hAxis);
                end
            end
        end
        try
            showPlaneLocators;
        end
        return;

    case 'LAYOUT'        
        if stateS.layout == 6 && varargin{1} ~= 6
            scanCompare('exit')
        end
        stateS.layout = varargin{1};
        sliceCallBack('resize');
        return;

    case 'DUPLICATEAXIS'
        hAxis = varargin{1};
        axisInfo = getAxisInfo(hAxis);
        axisInfo.scanObj(1:end) = [];
        axisInfo.doseObj(1:end) = [];
        axisInfo.structureGroup(1:end) = [];
        axisInfo.miscHandles = [];
        stateS.handle.CERRAxis(end+1) = axes('userdata', axisInfo, 'parent', hCSV, 'units', 'pixels', 'position', [1 1 1 1], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'buttondownfcn', 'sliceCallBack(''axisClicked'')', 'nextplot', 'add', 'yDir', 'reverse', 'linewidth', 2);
        tickV = linspace(0.02,0.1,6);
        for j = 1:6
            ticks1V(j) = line([tickV(j) tickV(j)], [0.01 0.03], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', 'y', 'hittest', 'off');
            ticks2V(j) = line([0.01 0.03], [tickV(j) tickV(j)], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', 'y', 'hittest', 'off');
        end
        stateS.handle.CERRAxisLabel1(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '', 'position', [.02 .98 0], 'color', [1 0 0], 'units', 'normalized', 'visible', 'off', 'horizontalAlignment', 'left', 'verticalAlignment', 'top');
        stateS.handle.CERRAxisLabel2(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '', 'position', [.90 .98 0], 'color', [1 0 0], 'units', 'normalized', 'visible', 'off', 'horizontalAlignment', 'left', 'verticalAlignment', 'top');
        stateS.handle.CERRAxisTicks1(end+1,:) = ticks1V;
        stateS.handle.CERRAxisTicks2(end+1,:) = ticks2V;
        stateS.handle.CERRAxisScale1(end+1) = line([0.02 0.1], [0.02 0.02], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', [0.7 0.7 0.7], 'hittest', 'off');
        stateS.handle.CERRAxisScale2(end+1) = line([0.02 0.02], [0.02 0.1], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', [0.7 0.7 0.7], 'hittest', 'off');
        stateS.handle.CERRAxisLabel3(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '5', 'position', [0.02 0.1 0], 'color', 'y', 'units', 'data', 'visible', 'off','fontSize',8);
        stateS.handle.CERRAxisLabel4(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '5', 'position', [0.1 0.02 0], 'color', 'y', 'units', 'data', 'visible', 'off','fontSize',8);
        
        axisInfo.miscHandles = [stateS.handle.CERRAxisLabel1(end) stateS.handle.CERRAxisLabel2(end) stateS.handle.CERRAxisLabel3(end) stateS.handle.CERRAxisLabel4(end) stateS.handle.CERRAxisScale1(end) stateS.handle.CERRAxisScale2(end) stateS.handle.CERRAxisTicks1(end,:) stateS.handle.CERRAxisTicks2(end,:)];
        
        set(stateS.handle.CERRAxis(end), 'userdata', axisInfo);
        CERRAxisMenu(stateS.handle.CERRAxis(end));
        sliceCallBack('RESIZE');
        CERRRefresh
        return;

    case 'DUPLICATELINKAXIS'
        hAxis = varargin{1};
        axisInfo = get(hAxis, 'userdata');
        axisInfo.scanObj(1:end) = [];
        axisInfo.doseObj(1:end) = [];
        axisInfo.structureGroup(1:end) = [];
        axisInfo.miscHandles = [];
        stateS.handle.CERRAxis(end+1) = axes('userdata', axisInfo, 'parent', hCSV, 'units', 'pixels', 'position', [1 1 1 1], 'color', [0 0 0], 'xTickLabel', [], 'yTickLabel', [], 'xTick', [], 'yTick', [], 'buttondownfcn', 'sliceCallBack(''axisClicked'')', 'nextplot', 'add', 'yDir', 'reverse', 'linewidth', 2);
        tickV = linspace(0.02,0.1,6);
        for j = 1:6
            ticks1V(j) = line([tickV(j) tickV(j)], [0.01 0.03], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', 'y', 'hittest', 'off');
            ticks2V(j) = line([0.01 0.03], [tickV(j) tickV(j)], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', 'y', 'hittest', 'off');
        end
        stateS.handle.CERRAxisLabel1(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '', 'position', [.02 .98 0], 'color', [1 0 0], 'units', 'normalized', 'visible', 'off', 'horizontalAlignment', 'left', 'verticalAlignment', 'top');
        stateS.handle.CERRAxisLabel2(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '', 'position', [.90 .98 0], 'color', [1 0 0], 'units', 'normalized', 'visible', 'off', 'horizontalAlignment', 'left', 'verticalAlignment', 'top');
        stateS.handle.CERRAxisTicks1(end+1,:) = ticks1V;
        stateS.handle.CERRAxisTicks2(end+1,:) = ticks2V;
        stateS.handle.CERRAxisScale1(end+1) = line([0.02 0.1], [0.02 0.02], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', [0.7 0.7 0.7], 'hittest', 'off');
        stateS.handle.CERRAxisScale2(end+1) = line([0.02 0.02], [0.02 0.1], [2 2], 'parent', stateS.handle.CERRAxis(end), 'color', [0.7 0.7 0.7], 'hittest', 'off');
        stateS.handle.CERRAxisLabel3(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '5', 'position', [0.02 0.1 0], 'color', 'y', 'units', 'data', 'visible', 'off','fontSize',8);
        stateS.handle.CERRAxisLabel4(end+1) = text('parent', stateS.handle.CERRAxis(end), 'string', '5', 'position', [0.1 0.02 0], 'color', 'y', 'units', 'data', 'visible', 'off','fontSize',8);
        axisInfo.miscHandles = [stateS.handle.CERRAxisLabel1(end) stateS.handle.CERRAxisLabel2(end) stateS.handle.CERRAxisLabel3(end) stateS.handle.CERRAxisLabel4(end) stateS.handle.CERRAxisScale1(end) stateS.handle.CERRAxisScale2(end) stateS.handle.CERRAxisTicks1(end,:) stateS.handle.CERRAxisTicks2(end,:)];
        axisInfo.coord       = {'Linked', hAxis};
        axisInfo.view        = {'Linked', hAxis};
        axisInfo.xRange      = {'Linked', hAxis};
        axisInfo.yRange      = {'Linked', hAxis};
        set(stateS.handle.CERRAxis(end), 'userdata', axisInfo);
        CERRAxisMenu(stateS.handle.CERRAxis(end));
        sliceCallBack('RESIZE');
        CERRRefresh

    case 'AXISCLICKED'
        hAxis = gca;
        hFig = get(hAxis, 'parent');
        %If no plan is loaded, ignore click.
        if ~stateS.planLoaded
            return;
        end
        clicktype = get(hCSV, 'selectiontype');

        switch clicktype
            case 'open'
                pos = find(stateS.handle.CERRAxis == hAxis);
                %Do not allow switching of 1st, 2nd and 3rd axis in
                %structure comparison mode
                if isfield(stateS,'structCompare') && (ismember(pos,[1 2 3]) || ismember(stateS.lastAxis,[1 2 3]))
                    return;
                end
                axisLabelTmp1 = stateS.handle.CERRAxisLabel1(pos);
                axisLabelTmp2 = stateS.handle.CERRAxisLabel2(pos);
                axisLabelTmp3 = stateS.handle.CERRAxisLabel3(pos);
                axisLabelTmp4 = stateS.handle.CERRAxisLabel4(pos);
                axisTickTmp1 = stateS.handle.CERRAxisTicks1(pos,:);
                axisTickTmp2 = stateS.handle.CERRAxisTicks2(pos,:);
                axisScaleTmp1 = stateS.handle.CERRAxisScale1(pos);
                axisScaleTmp2 = stateS.handle.CERRAxisScale2(pos);
                stateS.handle.CERRAxis(pos) = stateS.handle.CERRAxis(stateS.lastAxis);
                stateS.handle.CERRAxisLabel1(pos) = stateS.handle.CERRAxisLabel1(stateS.lastAxis);
                stateS.handle.CERRAxisLabel2(pos) = stateS.handle.CERRAxisLabel2(stateS.lastAxis);
                stateS.handle.CERRAxisLabel3(pos) = stateS.handle.CERRAxisLabel3(stateS.lastAxis);
                stateS.handle.CERRAxisLabel4(pos) = stateS.handle.CERRAxisLabel4(stateS.lastAxis);
                stateS.handle.CERRAxisScale1(pos) = stateS.handle.CERRAxisScale1(stateS.lastAxis);
                stateS.handle.CERRAxisScale2(pos) = stateS.handle.CERRAxisScale2(stateS.lastAxis);
                stateS.handle.CERRAxisTicks1(pos,:) = stateS.handle.CERRAxisTicks1(stateS.lastAxis,:);
                stateS.handle.CERRAxisTicks2(pos,:) = stateS.handle.CERRAxisTicks2(stateS.lastAxis,:);
                stateS.handle.CERRAxis(stateS.lastAxis) = hAxis;
                stateS.handle.CERRAxisLabel1(stateS.lastAxis) = axisLabelTmp1;
                stateS.handle.CERRAxisLabel2(stateS.lastAxis) = axisLabelTmp2;
                stateS.handle.CERRAxisLabel3(stateS.lastAxis) = axisLabelTmp3;
                stateS.handle.CERRAxisLabel4(stateS.lastAxis) = axisLabelTmp4; 
                stateS.handle.CERRAxisScale1(stateS.lastAxis) = axisScaleTmp1;
                stateS.handle.CERRAxisScale2(stateS.lastAxis) = axisScaleTmp2;
                stateS.handle.CERRAxisTicks1(stateS.lastAxis,:) = axisTickTmp1;
                stateS.handle.CERRAxisTicks2(stateS.lastAxis,:) = axisTickTmp2;                
                stateS.currentAxis = stateS.lastAxis;
                set(stateS.handle.CERRAxisLabel1(stateS.lastAxis), 'color', 'white');
                set(stateS.handle.CERRAxisLabel1(stateS.currentAxis), 'color', 'green');

                set(stateS.handle.CERRAxisLabel2(stateS.lastAxis), 'color', 'white');
                set(stateS.handle.CERRAxisLabel2(stateS.currentAxis), 'color', 'green');
                
                sliceCallBack('resize');
                
            case 'normal'
                sliceCallBack('focus', hAxis);

                if stateS.zoomState %If zoom mode is on...
                    sliceCallBack('zoomIn',hAxis);
                    return;
                end
                
                if stateS.clipState
                    set(hFig, 'WindowButtonMotionFcn', 'sliceCallBack(''clipMotion'')', 'WindowButtonUpFcn', 'sliceCallBack(''clipMotionDone'')');
                    sliceCallBack('clipStart');
                    return;
                end
                
                if stateS.gridState
                    set(hFig, 'WindowButtonMotionFcn', 'sliceCallBack(''rulerMotion'')', 'WindowButtonUpFcn', 'sliceCallBack(''rulerMotionDone'')');
                    sliceCallBack('rulerStart');
                    return;
                end
                
                if stateS.spotlightState
                    set(hFig, 'WindowButtonMotionFcn', 'sliceCallBack(''spotlightMotion'')', 'WindowButtonUpFcn', 'sliceCallBack(''spotlightMotionDone'')');
                    sliceCallBack('spotlightStart');
                    return;                    
                end

                if stateS.scanQueryState
                    set(hFig, 'WindowButtonMotionFcn', 'scanQuery(''scanQueryMotion'')', 'WindowButtonUpFcn', 'scanQuery(''scanQueryMotionDone'')');
                    scanQuery('scanQueryStart');
                    return;
                end


                if stateS.doseQueryState
                    set(hFig, 'WindowButtonMotionFcn', 'sliceCallBack(''doseQueryMotion'')', 'WindowButtonUpFcn', 'sliceCallBack(''doseQueryMotionDone'')');
                    sliceCallBack('doseQueryStart');
                    return;
                end

                if stateS.doseProfileState
                    set(hFig, 'WindowButtonMotionFcn', 'sliceCallBack(''doseProfileMotion'')', 'WindowButtonUpFcn', 'sliceCallBack(''doseProfileMotionDone'')');
                    sliceCallBack('doseProfileStart');
                    return;
                end
                % wy
                %                 if stateS.imageRegistration & isequal(stateS.handle.CERRAxis(stateS.lastAxis),hAxis)
                %                     CTImageRotation('init', hAxis, stateS.imageRegistrationMovDataset);
                %                     CTImageRotation('down', hAxis);
                %                     return;
                %                 end

                if stateS.imageRegistration && isequal(stateS.handle.CERRAxis(stateS.lastAxis),hAxis) && ...
                    stateS.optS.mirror == 0 && stateS.optS.mirrorscope == 0 && stateS.optS.blockmatch == 0 && ...
                    stateS.optS.mirrchecker == 0 && stateS.imageFusion.lockMoving == 0 && ...
                    stateS.doseAlphaValue.trans ~= 0 %wy
                     %stateS.optS.newchecker == 0 && stateS.optS.difference == 0 && stateS.optS.checkerBoard == 0 && ...
                    CTImageRotation('init', hAxis, stateS.imageRegistrationMovDataset);
                    CTImageRotation('down', hAxis);
                    return;
                end %wy
                
                if stateS.scanWindowState
                    set(hFig, 'WindowButtonMotionFcn', 'sliceCallBack(''scanWindowMotion'')', 'WindowButtonUpFcn', 'sliceCallBack(''scanWindowMotionDone'')');
                    sliceCallBack('scanWindowStart');
                    return;
                end
                
                if stateS.contourState
                    contourControl('Axis_Focus_Changed');
                    return;
                end
                

                
            case {'alt' 'extend'}
                if ~stateS.gridState && ~stateS.spotlightState && ~stateS.doseQueryState && ~stateS.doseProfileState && ~stateS.zoomState && ~stateS.imageRegistration && ~stateS.clipState
                    %Re-enable right click menus;
                    for i=1:length(stateS.handle.CERRAxis)
                        CERRAxisMenu(stateS.handle.CERRAxis(i));
                    end
                else
                    %Disable all right click menus;
                    set(stateS.handle.CERRAxis, 'uicontextmenu', []);
                end
                if stateS.zoomState %If zoom mode is on...
                    sliceCallBack('zoomOut',hAxis);
                    return;
                end
                if stateS.gridState
                    sliceCallBack('TOGGLERULER');
                    return;
                end
                if stateS.spotlightState
                    sliceCallBack('TOGGLESPOTLIGHT');
                    return;
                end
                if stateS.doseQueryState
                    sliceCallBack('TOGGLEDOSEQUERY');
                    return;
                end
                if stateS.doseProfileState
                    sliceCallBack('TOGGLEDOSEPROFILE');
                    return;
                end
                if stateS.scanQueryState
                    sliceCallBack('TOGGLESCANQUERY');
                    return;
                end
                %wy
                if stateS.clipState
                    sliceCallBack('SETCLIPSTATE');
                    return;
                end%wy
        end
        return;

    case 'FOCUS'
        %Sets current cerr focus to a new axis, varargin.
        hAxis = varargin{1};
        hFig = get(hAxis, 'parent');
        stateS.lastAxis = stateS.currentAxis;
        stateS.currentAxis = find(stateS.handle.CERRAxis == hAxis);
        planeLocators = findobj(hFig, 'tag', 'planeLocator');
        set(planeLocators, 'marker', 'none');
        pLUD = get(planeLocators, 'userdata');
        for i = 1:size(pLUD,1)
            parentAxis = pLUD{i}{3};
            if parentAxis == stateS.currentAxis;
                set(planeLocators(i), 'Color', [0 1 0]);
            else
                set(planeLocators(i), 'Color', [1 1 0]);
            end
        end
        try % case where the axes is deleted stateS.lastAxis exceeds matrix dimention
            set(stateS.handle.CERRAxisLabel1(stateS.lastAxis), 'color', [1 1 0]);
            set(stateS.handle.CERRAxisLabel2(stateS.lastAxis), 'color', [1 1 0]);
        end
        set(stateS.handle.CERRAxisLabel1(stateS.currentAxis), 'color', 'green');
        set(stateS.handle.CERRAxisLabel2(stateS.currentAxis), 'color', 'green');
        return;

    case 'OPENWORKSPACEPLANC'
        if ~isempty(planC) & iscell(planC);
            stateS.workspacePlan = 1;
            stateS.CERRFile = 'WorkspacePlan';
            sliceCallBack('load');
        else
            CERRStatusString('No valid global planC in workspace.');
        end
        return;

    case 'OPENNEWPLANC'
        %DK
        if stateS.planLoaded
            %exit structure comparison mode if active
            if isfield(stateS,'structCompare')
                structCompare({'exit'})
            end
            %End contouring mode, (losing changes) in case contour was active.
            controlFrame('default')
            hQuest = questdlg('Do you want to save changes made to this plan?','Saving plan','Yes','No','No');
            if strcmpi(hQuest,'yes')
                sliceCallBack('saveasplanc');
            else
                %removeUnusedRemoteFiles
                remoteFiles = listRemoteScanAndDose(planC);
                if ~isempty(remoteFiles)
                    try, rmdir(remoteFiles(1).remotePath,'s'), end
                end
                CERRStatusString('Warning! loading new plan ...')
            end
        end
        %DK

        if nargin > 1
            file = varargin{1};
        else
            if isfield(stateS, 'CERRFile') & ~isempty(stateS.CERRFile)
                if stateS.workspacePlan
                    %If workspace plan, ie no directory, use CERR root.
                    stateS.CERRFile = fullfile(getCERRPath, 'workspacePlan');
                end
                dir = fileparts(stateS.CERRFile);
                wd = cd;
                cd(dir);
                [fname, pathname] = uigetfile({'*.mat;*.mat.bz2;*.mat.zip;*.mat.tar;*.mat.bz2.tar;*.mat.zip.tar', 'CERR Plans (*.mat, *.mat.bz2, *.mat.tar, *.mat.bz2.tar)';'*.*', 'All Files (*.*)'}, 'Select a CERR archive for viewing');
                cd(wd);
            else
                [fname, pathname] = uigetfile({'*.mat;*.mat.bz2;*.mat.zip;*.mat.tar;*.mat.bz2.tar;*.mat.zip.tar', ...
                    'CERR Plans (*.mat, *.mat.bz2, *.mat.zip, *.mat.tar, *.mat.bz2.tar, *.mat.zip.tar)';'*.*',...
                    'All Files (*.*)'}, 'Select a CERR archive for viewing');
            end

            if fname == 0
                CERRStatusString('Open cancelled. Ready.');
                return
            end

            file = fullfile(pathname, fname);
        end

        [pathstr, name, ext] = fileparts(file);

        %Get temporary directory to extract uncompress
        optS = stateS.optS;
        if isempty(optS.tmpDecompressDir)
            tmpExtractDir = tempdir;
        elseif isdir(optS.tmpDecompressDir)
            tmpExtractDir = optS.tmpDecompressDir;
        elseif ~isdir(optS.tmpDecompressDir)
            error('Please specify a valid directory within CERROptions.m for optS.tmpDecompressDir')
        end

        %untar if it is a .tar file
        tarFile = 0;
        if strcmpi(ext, '.tar')
            if ispc
                untar(file,tmpExtractDir)
                fileToUnzip = fullfile(tmpExtractDir, name);
            else
                untar(file,pathstr)
                fileToUnzip = fullfile(pathstr, name);
            end
            file = fileToUnzip;
            [pathstr, name, ext] = fileparts(fullfile(pathstr, name));
            tarFile = 1;
        end
      
        if strcmpi(ext, '.bz2')
            zipFile = 1;
            CERRStatusString(['Decompressing ' name ext '...']);
            outstr = gnuCERRCompression(file, 'uncompress',tmpExtractDir);
            if ispc            
                loadfile = fullfile(tmpExtractDir, name);
            else
                loadfile = fullfile(pathstr, name);
            end
            [pathstr, name, ext] = fileparts(fullfile(pathstr, name));
        elseif strcmpi(ext, '.zip')
            zipFile = 1;
            if ispc
                unzip(file,tmpExtractDir)
                loadfile = fullfile(tmpExtractDir, name);
            else
                unzip(file,pathstr)
                loadfile = fullfile(pathstr, name);
            end            
            [pathstr, name, ext] = fileparts(fullfile(pathstr, name));
        else
            zipFile = 0;
            loadfile = file;
        end

        CERRStatusString(['Loading ' name ext '...']);

        %         %Decompress files if .tar
        %         if strcmpi(ext, '.tar')
        %             currentDir = cd;
        %             cd(tempdir);
        %             tarPath = fullfile(getCERRPath,'Compression','tar.exe');
        %             tarFile = file;
        %             tarFile(strfind(tarFile, '\')) = '/';
        %             if ispc
        %                 dos([tarPath ' -x < "' tarFile '"']);
        %             elseif isunix
        %                 unix([tarPath ' -x < "' tarFile '"']);
        %             end
        %             cd(currentDir)
        %
        %             loadfile = fullfile(tempdir, name);
        %         end

        planC           = load(loadfile,'planC');
        try
            if zipFile
                delete(loadfile);
            end
            if tarFile
                delete(fileToUnzip);
            end
        catch
        end
        planC           = planC.planC; %Conversion from struct created by load
        stateS.CERRFile = file;
        stateS.workspacePlan = 0;
        sliceCallBack('load');

    case 'MERGEPLANS'
        planMergeGui;
        return;

    case 'DOSETOGGLE'
        if stateS.doseToggle == 1 & stateS.layout == 7
            hWarn = warndlg('Dose cannot be turned off in doseCompareMode');
            waitfor(hWarn);
            return
        end
        stateS.doseToggle = - stateS.doseToggle;
        try
            hDoseToggle = findobj(stateS.handle.CERRSliceViewer,'tag', 'doseToggle');
            if stateS.doseToggle == 1
                set(hDoseToggle, 'checked', 'on')
            else
                set(hDoseToggle, 'checked', 'off')
            end
        end
        stateS.doseSetChanged = 1;
        CERRRefresh
        return

    case 'CTTOGGLE'
        if (stateS.contourState | stateS.imageRegistration) & stateS.CTToggle == 1
            hWarn = warndlg('Scan cannot be turned off');
            waitfor(hWarn);
            return
        end
        stateS.CTToggle = - stateS.CTToggle;
        if stateS.CTToggle == 1
            set(gcbo, 'checked', 'on')
        else
            set(gcbo, 'checked', 'off')
        end
        stateS.CTDisplayChanged = 1;
        CERRRefresh
        return

    case 'CHANGESLC'
        
        %Rotation active message
        if stateS.toggle_rotation
            msgbox('Please get out of rotation mode before moving to next slice','Rotation Active','modal');
            return;
        end
        %     case {'NEXTSLICE', 'PREVSLICE'}
        %figure(hCSV); %Remove uicontrol focus.
        hAxis = stateS.handle.CERRAxis(stateS.currentAxis);
        [view, scanSets , lastcoord] = getAxisInfo(hAxis, 'view', 'scanSets', 'coord');

        if ~isempty(scanSets)
            scanSet = scanSets(1);

        else % if scan is turned off from the view menu
            if ~isempty(stateS.scanSet)
                scanSet = stateS.scanSet(1); 
            else
                scanSet = 1; 
            end
        end
        [xs, ys, zs] = getScanXYZVals(planC{indexS.scan}(scanSet));
        transM = getTransM('scan', scanSet, planC);

        if strcmpi(varargin{1}, 'NEXTSLICE')
            delta = 1;
        elseif strcmpi(varargin{1}, 'PREVSLICE')
            delta = -1;
        end

        if ~isempty(transM) && ~isequal(transM,eye(4))
            [nCoordX nCoordY nCoordZ] = applyTransM(inv(transM),lastcoord,lastcoord,lastcoord);
        else
            nCoordX = lastcoord;
            nCoordY = lastcoord;
            nCoordZ = lastcoord;
        end
        I = eye(4);
        switch upper(view)
            case 'TRANSVERSE'
                if length(zs) > 1
                    oldSlice = findnearest(zs, nCoordZ);
                    newSlice = oldSlice + delta;
                else
                    newSlice = 1;
                end
                %if ~newSlice < 1 | ~newSlice > length(zs)                
                if (newSlice > 0 & newSlice <= length(zs)) && (isempty(transM) || max(abs(transM(:) - I(:))) < 1e-8)
                    newCoord = zs(newSlice);
                    setAxisInfo(hAxis, 'coord', newCoord);
                else
                    uniqZs = unique(diff(zs));                    
                    sliceSpacing = min(uniqZs(uniqZs ~= 0));
                    setAxisInfo(hAxis, 'coord', lastcoord+sliceSpacing*delta);
                end
            case 'SAGITTAL'
                oldSlice = findnearest(xs, nCoordX);
                newSlice = oldSlice + delta;
                if (newSlice > 0 & newSlice <= length(xs)) && (isempty(transM) || max(abs(transM(:) - I(:))) < 1e-8)
                    %if ~newSlice < 1 | ~newSlice > length(xs)

                    newCoord = xs(newSlice);
                    setAxisInfo(hAxis, 'coord', newCoord);
                else
                    uniqXs = unique(diff(xs));
                    sliceSpacing = min(uniqXs(uniqXs ~= 0));
                    setAxisInfo(hAxis, 'coord', lastcoord+sliceSpacing*delta);
                end
            case 'CORONAL'
                oldSlice = findnearest(ys, nCoordY);
                newSlice = oldSlice + delta;
                %if ~newSlice < 1 | ~newSlice > length(ys)
                if (newSlice > 0 && newSlice <= length(ys)) && (isempty(transM) || max(abs(transM(:) - I(:))) < 1e-8)
                    newCoord = ys(newSlice);
                    setAxisInfo(hAxis, 'coord', newCoord);
                else
                    uniqYs = unique(diff(ys));
                    sliceSpacing = min(uniqYs(uniqYs ~= 0));
                    setAxisInfo(hAxis, 'coord', lastcoord+sliceSpacing*delta);
                end
        end

        CERRRefresh
        return;

    case 'TRANS_MOV'
        ud = get(stateS.handle.CERRAxis(1),'userdata');
        if strcmpi(ud.view,'TRANSVERSE');
            flg = -1;
        else
            flg = 1;
        end
        switch lower(stateS.TransMoveKey)
            case 'up'
                deltaX = 0;
                deltaY = 0.5;
            case 'down'
                deltaX = 0;
                deltaY = -0.5;
            case 'left'
                deltaX = -0.5;
                deltaY = 0;
            case 'right'
                deltaX = 0.5;
                deltaY = 0;
        end
        hAxis = gca;
        hFig = get(hAxis,'parent');
        movData = stateS.imageRegistrationMovDataset;
        transM = eye(3);
        axisInfo = get(hAxis, 'userdata');
        indV = find([axisInfo.scanObj.scanSet] == movData);
        hImage = axisInfo.scanObj(indV).handles;
        UISUSPENDDATA = uisuspend(hFig);
        xLimOrig = get(hImage, 'xData');
        yLimOrig = get(hImage, 'yData');
        limSize = size(xLimOrig);
        pointsM = [xLimOrig(:) yLimOrig(:) ones(size(yLimOrig(:)))];
        rotM = [1 0 flg*deltaX;0 1 flg*deltaY; 0 0 1];
        tmptransM = transM*rotM;
        newCorners = inv(tmptransM) * pointsM';
        newXLim = newCorners(1,:);
        newYLim = newCorners(2,:);
        set(hImage, 'xData', reshape(newXLim, limSize), 'yData', reshape(newYLim, limSize));
        axisfusion(hAxis, stateS.optS.fusionDisplayMode, stateS.optS.fusionCheckSize);
        uirestore(UISUSPENDDATA);
        stateS.fusionTransM = tmptransM;
        controlFrame('fusion', 'apply', hAxis);
        stateS.fusionTransM = 0;

    case 'SLIDERTRANSALPHA'
        %figure(hCSV); %Remove uicontrol focus.
        stateS.doseAlphaValue.trans = get(stateS.handle.sliderTransAlpha, 'Value');
        stateS.doseDisplayChanged = 1;
        if stateS.contourState
            stateS.CTDisplayChanged = 1;
        end
        if stateS.planLoaded
            CERRRefresh
        end
        hToggleBasMov = findobj(stateS.handle.CERRSliceViewer,'tag','toggleBasMov');
        %change color of Base-Moving toggle-button if it exists
        udFrame = get(stateS.handle.controlFrame,'userdata');        
        clrM = [0 0 0; 1 0.8 0.5; 1 0 0; 0 1 0; 0 0 1; 1 0.5 0.5; 1 0.5 0.5];        
        if ~isempty(hToggleBasMov) && stateS.doseAlphaValue.trans > 0 && stateS.doseAlphaValue.trans < 1
            set(hToggleBasMov,'string','B/M','fontWeight','normal','foregroundColor',[0 0 0],'value',0)
        elseif ~isempty(hToggleBasMov) && stateS.doseAlphaValue.trans == 1
            clrVal = get(udFrame.handles.displayModeColor,'value');
            set(hToggleBasMov,'string','M','fontWeight','bold','foregroundColor',clrM(clrVal,:))
        elseif ~isempty(hToggleBasMov) && stateS.doseAlphaValue.trans == 0
            set(hToggleBasMov,'string','B','fontWeight','bold','foregroundColor',[0 0 0])
        end
        return
        
    case 'TOGGLEBASEMOVING'
        %figure(hCSV); %Remove uicontrol focus.
        stateS.doseAlphaValue.trans = get(gcbo,'value');        
        udFrame = get(stateS.handle.controlFrame,'userdata');
        clrVal = get(udFrame.handles.displayModeColor,'value');        
        clrM = [0 0 0; 1 0.8 0.5; 1 0 0; 0 1 0; 0 0 1; 1 0.5 0.5; 1 0.5 0.5];
        if stateS.doseAlphaValue.trans == 1
            set(gcbo,'string','M','fontWeight','bold','foregroundColor',clrM(clrVal,:))
        else 
            set(gcbo,'string','B','fontWeight','bold','foregroundColor',[0 0 0])
        end
        set(stateS.handle.sliderTransAlpha,'value',stateS.doseAlphaValue.trans)
        stateS.doseDisplayChanged = 1;
        if stateS.contourState
            stateS.CTDisplayChanged = 1;
        end
        if stateS.planLoaded
            CERRRefresh
        end
        return       
        
    case 'TOGGLELOCKMOVING'
        stateS.imageFusion.lockMoving = get(gcbo,'value'); 
        
        if stateS.imageFusion.lockMoving == 1
            [I,map] = imread('lock.gif','gif');
            lockImg = ind2rgb(I,map);
            set(gcbo,'cdata',lockImg,'fontWeight','bold','foregroundColor', [1 0 0]);
        else 
            [I,map] = imread('unlock.GIF','gif');
            lockImg = ind2rgb(I,map);
            set(gcbo,'cdata',lockImg,'fontWeight','bold','foregroundColor',[0.5 0.5 0.5]);
        end

    case 'STRUCTTOGGLE'
        stateS.structToggle = - stateS.structToggle;
        stateS.structsChanged = 1;
        try
            if stateS.structToggle == 1
                set(gcbo, 'checked', 'on')
            else
                set(gcbo, 'checked', 'off')
            end
        end
        CERRRefresh
        return

    case 'REFRESHSTRUCTMENU'
        stateS.handle.structMenu = putStructMenu(stateS.handle.CERRSliceViewer);
        return

    case 'REFRESHIMRTPMENU'
        stateS.handle.IMRTPMenu = putIMRTPMenu(stateS.handle.CERRSliceViewer);
        return

    case 'CONTOURMODE'
        if stateS.CTToggle == -1
            hWarn = warndlg('Please turn on the scan');
            waitfor(hWarn);
            return;
        end
        controlFrame('default');
        %Disable all right click menus;
        set(stateS.handle.CERRAxis, 'uicontextmenu', []);
        %     Check if its transverse view, else display errr.
        ud = get(stateS.handle.CERRAxis(1),'userdata');
        if ~strcmpi(ud.view,'transverse')
            herror=errordlg({'Contouring can be done only on Transverse Views','Please Select 1st view to be transverse for contouring'},'Not a transverse view','on');
            return
        end
        stateS.contourState = 1;
        controlFrame('contour', 'init');

        scanSet = getAxisInfo(hCSVA,'scanSets');
        %Scan set number that is already loaded
        if isfield(planC{indexS.scan}(scanSet),'transM') & ~isempty(planC{indexS.scan}(scanSet).transM) & ~isequal(planC{indexS.scan}(scanSet).transM, eye(4))
            transM = getTransM('scan', scanSet,planC);
            % DK fix to keep the scan with the range
            [xV, yV, zV] = getScanXYZVals(planC{indexS.scan}(scanSet));
            for i=1:length(stateS.handle.CERRAxis)
                view = getAxisInfo(stateS.handle.CERRAxis(i), 'view');
                AI = get(stateS.handle.CERRAxis(i),'userdata');
                [nCoordX nCoordY nCoordZ] = applyTransM(inv(transM),AI.coord,AI.coord,AI.coord);
                switch upper(view)
                    case 'TRANSVERSE'
                        setAxisInfo(stateS.handle.CERRAxis(i), 'xRange', [min(xV) max(xV)], 'yRange', [min(yV) max(yV)], 'coord', nCoordZ);
                    case 'SAGITTAL'
                        setAxisInfo(stateS.handle.CERRAxis(i), 'xRange', [min(yV) max(yV)], 'yRange', [min(zV) max(zV)], 'coord', nCoordX);
                    case 'CORONAL'
                        setAxisInfo(stateS.handle.CERRAxis(i), 'xRange', [min(xV) max(xV)], 'yRange', [min(zV) max(zV)], 'coord', nCoordY);
                end
            end
            % DK end
        end
        contourControl('init', scanSet);
        contourControl('drawMode');
        ud=get(stateS.handle.controlFrame,'userdata');
        set(ud.handles.structPopup,'enable','on')
        return;

    case 'COPYSTR'
        prompt = {'Copy the following structures: e.g. [2 3 6 7]','Copy to this scan: e.g. 2'};
        name = 'Copy Structures';
        numlines = 1;
        defaultanswer = {'',''};
        answer = inputdlg(prompt,name,numlines,defaultanswer);
        if isempty(answer)
            return;
        end
        structsV = str2num(answer{1});
        scanNum = str2num(answer{2});
        if isempty(structsV) || isempty(scanNum)
            error('Incorrect input. Input must be numeric. Please try again.')
            return;
        end
        if length(scanNum) > 1
            error('Incorrect input. Please specify only one scan to copy to.')
            return;
        end
        if scanNum > length(planC{indexS.scan})
            error('Incorrect input. Please specify valid scan number.')
            return;
        end
        if any(find(structsV>length(planC{indexS.structures})))
            error('Incorrect input. Please specify valid structure numbers to copy.')
            return;
        end        
        pause(0.05)
        drawnow;        
        CERRStatusString('Copying structure/s from one scan to other. Please wait...')
        scanNumsV = getStructureAssociatedScan(structsV,planC);
        count = 1;
        for structNum = structsV
            if scanNumsV(count) ~= scanNum
                copyStrToScan_noMesh(structNum,scanNum);
            end
            count = count + 1;
        end        
        CERRStatusString('Done copying structure/s')
        
    case 'STRUCTCONSENSUS'
        prompt = {'Input structures to check consensus: e.g. [2 3 6 7]'};
        name = 'Consensus';
        numlines = 1;
        defaultanswer = {''};
        answer = inputdlg(prompt,name,numlines,defaultanswer);        
        if isempty(answer)
            return;
        end
        structsV = str2num(answer{1});        
        if isempty(structsV)
            error('Incorrect input. Input must be numeric. Please try again.')
            return;
        end
        scanNumV = getStructureAssociatedScan(structsV,planC);
        
        if length(unique(scanNumV)) > 1
            error('All structures must be associated with same scan. Please try again.')
            return;
        end
        
        runCERRCommand(['structCompare ',answer{1}]);


    case 'PLANELOCATORTOGGLE'
        stateS.showPlaneLocators = xor(stateS.showPlaneLocators, 1);
        CERRRefresh
        return;
        
    case 'NAVMONTAGETOGGLE'
        stateS.showNavMontage = xor(stateS.showNavMontage, 1);
        if stateS.showNavMontage
            navigationMontage('init',stateS.scanSet)
        else
            delete(stateS.handle.navigationMontage)
        end

    case 'ISODOSETOGGLE'
        controlFrame('default'); %Reset Side Control color bar
        switch lower(stateS.optS.dosePlotType)
            case 'colorwash'
                stateS.optS.dosePlotType = 'isodose';
            case 'isodose'
                stateS.optS.dosePlotType = 'colorwash';
        end
        stateS.doseChanged = 1;
        stateS.doseDisplayChanged = 1;
        CERRRefresh
        return

    case 'TOGGLESINGLESTRUCT'
        structNum = str2double(varargin{1});
        planC{indexS.structures}(structNum).visible = xor(planC{indexS.structures}(structNum).visible, 1);
        if planC{indexS.structures}(structNum).visible
            checked = 'on';
            toggleStructSagCor(structNum)
        else
            checked = 'off';
        end
        try
            set(gcbo, 'Checked', checked);
        end
        
        CERRRefresh
        
        
    case 'SELECTSTRUCTMORE'        
        structsToShow = 25;
        numStructs = length(planC{indexS.structures});
        structStrC = {};
        assocScanV = getStructureAssociatedScan(1 : numStructs);
        scanNum = varargin{1};
        assocScanV = assocScanV == scanNum;   
        structAssocToScanV = find(assocScanV);
        count = 1;
        for i = structAssocToScanV(structsToShow+1:end)        
            structStrC{count} = [num2str(i) '.  ' planC{indexS.structures}(i).structureName];
            count = count + 1;
        end
        initialValue = 1;
        structureIndex = listdlg('PromptString','Toggle Structure', 'SelectionMode','single','ListString',structStrC,'InitialValue',initialValue);
        if ~isempty(structureIndex)
            sliceCallBack('TOGGLESINGLESTRUCT',num2str(structAssocToScanV(structsToShow+structureIndex)))
        end
        hMoreStruct = findobj('label', 'More Structures...');
        set(hMoreStruct,'checked','off')
        
        
    case 'VIEWALLSTRUCTURES'
        scanSet = varargin;
        if isempty(scanSet)
            for i=1:length(planC{indexS.structures})
                planC{indexS.structures}(i).visible = 1;
            end
        else
            scanSet = str2double(scanSet);
            scanIndxV = getStructureAssociatedScan(1:length(planC{indexS.structures}));
            indV = find(scanSet == scanIndxV);
            for i=1:length(indV)
                planC{indexS.structures}(indV(i)).visible = 1;
            end

        end
        CERRRefresh;
    case 'VIEWNOSTRUCTURES'
        scanSet = varargin;
        if isempty(scanSet)
            for i=1:length(planC{indexS.structures})
                planC{indexS.structures}(i).visible = 0;
            end
        else
            scanSet = str2double(scanSet);
            scanIndxV = getStructureAssociatedScan(1:length(planC{indexS.structures}));
            indV = find(scanSet == scanIndxV);
            for i=1:length(indV)
                planC{indexS.structures}(indV(i)).visible = 0;
            end

        end
        CERRRefresh
    case 'DOSESHADOW'
        doseShadowGui('init', planC);
        return;

        %FOLLOWING FUNCTIONS HAD TO BE BROKEN OUT FOR COMPILATION:
    case 'CLOSEREQUEST'
        %Clear the persistent variable in getDoseArray when CERR exists.
        try
            controlFrame('default');
        end
        if isfield(stateS,'planLoaded') && stateS.planLoaded
            hQuest = questdlg('Do you want to save changes made to this plan?','Saving plan','Yes','No','Cancel','No');
            if strcmpi(hQuest,'yes')
                sliceCallBack('saveasplanc');
            elseif strcmpi(hQuest,'Cancel')|isempty(hQuest)
                return
            end
        end
        clear('getDoseArray');

        %Clear Meshes from Memory if they exist
        try
            currDir = cd;
            clearStructMeshes
            clearDoseMeshes
        catch
            %warning('Cannot Clear Mesh')
            cd(currDir)
        end

        %removeUnusedRemoteFiles

        if ~isempty(stateS) && isfield(stateS,'CERRFile') && isfield(stateS,'reqdRemoteFiles')
            remoteFiles = listRemoteScanAndDose(planC);
            if ~isempty(remoteFiles)
                try, rmdir(remoteFiles(1).remotePath,'s'), end
            end
        end

        try
            closeAllCERRFigures;
        end
        clear global stateS;
        closereq;
        CERR
        return

    case 'LOCATORCLICKED'
        set(hCSV, 'WindowButtonUpFcn', 'sliceCallBack(''LOCATORUNCLICKED'')');
        hLine = gcbo;
        setappdata(hCSV, 'locPlaneHandle', hLine);
        %set(gcbo, 'erasemode', 'xor');
        set(hCSV, 'WindowButtonMotionFcn', 'sliceCallBack(''LOCATORMOVING'')');
        return;

    case 'LOCATORMOVING'
        hLine = getappdata(hCSV, 'locPlaneHandle');
        hAxis = get(hLine, 'parent');
        ud = get(hLine, 'userdata');
        locType = ud{1}; %view = ud{2};
        cP = get(hAxis, 'currentpoint');
        switch locType
            case 'vert'
                set(hLine, 'xData', [cP(1,1) cP(1,1)]);
            case 'horz'
                set(hLine, 'yData', [cP(1,2) cP(1,2)]);
        end
        return;

    case 'LOCATORUNCLICKED'
        set(hCSV, 'WindowButtonUpFcn', '');
        set(hCSV, 'WindowButtonMotionFcn', '');
        hLine = getappdata(hCSV, 'locPlaneHandle');
        setappdata(hCSV, 'locPlaneHandle', []);
        ud = get(hLine, 'userdata');
        %type = ud{1}; view = ud{2}; 
        linkedAxis = ud{3};
        %transAxis = []; sagAxis = []; corAxis = [];
        hAxis = stateS.handle.CERRAxis(linkedAxis);
        xVals = get(hLine, 'xData');
        yVals = get(hLine, 'yData');
        if diff(xVals) == 0
            setAxisInfo(hAxis, 'coord', xVals(1));
        else
            setAxisInfo(hAxis, 'coord', yVals(1));
        end
        CERRRefresh
        return;

    case 'STEP'
        stateS.delta = varargin{1};
        stateS.sliceNum = stateS.sliceNum + stateS.delta;
        return

    case 'REFRESH'
        CERRRefresh;
        return;
    case 'REFRESHALLOTHERS'
        return

    case 'TOGGLEZOOM'
        %figure(hCSV); %Remove uicontrol focus.
        val = not(stateS.zoomState);

        stateS.zoomState = val;
        %         val = get(stateS.handle.zoom, 'value');
        if val
            cData = NaN*ones(16);
            cData(8,1:2:16) = 1;
            cData(8,2:2:16) = 2;
            cData(1:1:16,8) = 1;
            cData(1:2:16,8) = 2;
            %set(hCSV,'pointer','crosshair');
            set(hCSV,'pointerShapeCData',cData,'pointer','custom','PointerShapeHotSpot',[8,8]);
            set(stateS.handle.zoom,'background','red');
            set(stateS.handle.fractionGroupIDTrans,'String','Left Click: ZOOMIN');

            set(stateS.handle.doseDescriptionTrans,'String','Right Click: ZOOMOUT');
        else
            set(stateS.handle.zoom,'background','white');
            % Define Pointer
            set(hCSV,'pointer','arrow');
            set(stateS.handle.fractionGroupIDTrans,'String','');

            set(stateS.handle.doseDescriptionTrans,'String','');
        end
        return;

    case 'ZOOMIN'
        hAxis = varargin{1};
        % Get the parent axis in case of linked axis
        ud = get(hAxis,'userdata');
        if iscell(ud.view)
            hAxisParent = ud.view{2};
        else
            hAxisParent = hAxis;
        end        
        % Find linked axes
        hAxisV = [];
        for hAx = stateS.handle.CERRAxis
            ud = get(hAx,'userdata'); 
            if iscell(ud.view)
                hAxisV = [hAxisV, ud.view{2}];
            else
                hAxisV = [hAxisV, hAx];
            end
        end
        indAxis = find(hAxisV==hAxisParent);
        allhAxis = stateS.handle.CERRAxis(indAxis);
        hFig = get(hAxis(1), 'parent');
        startPt  = get(hAxis(1), 'currentPoint');
        %rbbox([get(hFig,'currentpoint') 0 0],get(hFig,'currentpoint'),hFig);
        rbbox([get(hFig,'currentpoint') 0 0],get(hFig,'currentpoint'));
        endPt = get(hAxis(1), 'currentPoint');
        xLim = get(hAxis(1), 'xLim');
        yLim = get(hAxis(1), 'yLim');
        deltaX = xLim(2)-xLim(1);
        deltaY = yLim(2)-yLim(1);
        if isequal(startPt, endPt)
            newXLim = [startPt(1,1)-deltaX/4 startPt(1,1)+deltaX/4];
            newYLim = [startPt(2,2)-deltaY/4 startPt(2,2)+deltaY/4];
        else
            newDeltaX = abs(startPt(1,1) - endPt(1,1));
            newDeltaY = abs(startPt(2,2) - endPt(2,2));
            midPtX     = (startPt(1,1)+endPt(1,1))/2;
            midPtY     = (startPt(2,2)+endPt(2,2))/2;
            if newDeltaX/deltaX > newDeltaY/deltaY
                ratio = newDeltaX/deltaX;
            else
                ratio = newDeltaY/deltaY;
            end
            newXLim = [midPtX-ratio*deltaX/2 midPtX+ratio*deltaX/2];
            newYLim = [midPtY-ratio*deltaY/2 midPtY+ratio*deltaY/2];
        end
        for hAxis = allhAxis
            setAxisInfo(hAxis, 'xRange', newXLim, 'yRange', newYLim);
            zoomToXYRange(hAxis);
        end
        %Redraw locators
        showPlaneLocators;
        %Update scale        
        for hAxis = allhAxis
            indAxis = find(hAxis == stateS.handle.CERRAxis);
            showScale(hAxis, indAxis)
        end
        return
        
    case 'ZOOMOUT'
        hAxis = varargin{1};
        % Get the parent axis in case of linked axis
        ud = get(hAxis,'userdata');
        if iscell(ud.view)
            hAxisParent = ud.view{2};
        else
            hAxisParent = hAxis;
        end        
        % Find linked axes
        hAxisV = [];
        for hAx = stateS.handle.CERRAxis
            ud = get(hAx,'userdata');
            if iscell(ud.view)
                hAxisV = [hAxisV, ud.view{2}];
            else
                hAxisV = [hAxisV, hAx];
            end
        end
        indAxis = find(hAxisV==hAxisParent);
        allhAxis = stateS.handle.CERRAxis(indAxis);
        hFig        = get(hAxis, 'parent');
        startPt     = get(hAxis, 'currentPoint');
        xLim        = get(hAxis, 'xLim');
        yLim        = get(hAxis, 'yLim');
        deltaX  = xLim(2)-xLim(1);
        deltaY  = yLim(2)-yLim(1);
        newXLim = [startPt(1,1)-deltaX startPt(1,1)+deltaX];
        newYLim = [startPt(2,2)-deltaY startPt(2,2)+deltaY];
        for hAxis = allhAxis
            setAxisInfo(hAxis, 'xRange', newXLim, 'yRange', newYLim);
            zoomToXYRange(hAxis);
        end        
        %Redraw locators
        showPlaneLocators;
        %Update scale        
        for hAxis = allhAxis
            indAxis = find(hAxis == stateS.handle.CERRAxis);
            showScale(hAxis, indAxis)
        end
        %cleanupAxes(hAxis);
        return
        %CALLBACKS TO OPERATE doseProfile.

    case 'ZOOMRESET'
        axisNum=stateS.currentAxis;
        hAxis = stateS.handle.CERRAxis(axisNum);
        ud = get(hAxis,'userdata');
        if iscell(ud.view)
            hAxisParent = ud.view{2};
        else
            hAxisParent = hAxis;
        end        
        % Find linked axes
        hAxisV = [];
        for hAx = stateS.handle.CERRAxis
            ud = get(hAx,'userdata');
            if iscell(ud.view)
                hAxisV = [hAxisV, ud.view{2}];
            else
                hAxisV = [hAxisV, hAx];
            end
        end
        indAxis = find(hAxisV==hAxisParent);
        for axisNum = indAxis
            updateAxisRange(stateS.handle.CERRAxis(axisNum),1,'zoom');
            zoomToXYRange(stateS.handle.CERRAxis(axisNum));
        end
        %Redraw locators
        %showPlaneLocators;
        CERRRefresh
        return;

        %CALLBACKS TO QUERY SCAN.
    case 'TOGGLESCANQUERY'
        if ~stateS.scanQueryState
            CERRStatusString('Click/drag in axis. Right click to end.');
            stateS.scanQueryState = 1;

            %Disable all right click menus;
            set(stateS.handle.CERRAxis, 'uicontextmenu', []);
        else
            CERRStatusString('');
            delete([findobj('tag', 'scanQueryPoint')]);
            stateS.scanQueryState = 0;

            %Right click menus are re-enabled in AxisClicked callback.
        end
        return;


    case 'TOGGLEDOSEPROFILE'
        %figure(hCSV); %Remove uicontrol focus.
        if ~stateS.doseProfileState
            toggleOffDrawModes;
            CERRStatusString('Click/drag in axis. Right click to end.');
            stateS.doseProfileState = 1;
            doseProfileFigure('init', 1, 1);
            %Disable all right click menus;
            set(stateS.handle.CERRAxis, 'uicontextmenu', []);
        else
            CERRStatusString('');
            delete([findobj('tag', 'profileLine')]);
            stateS.doseProfileState = 0;
            try
                delete(stateS.handle.doseProfileFigure);
            end
            stateS.handle.doseProfileFigure = [];
            %Right click menus are re-enabled in AxisClicked callback.
        end
        return;

    case 'DOSEPROFILESTART'
        hAxis = gcbo;
        hFig  = get(hAxis, 'parent');
        cP    = get(hAxis, 'CurrentPoint');
        set(hFig, 'interruptible', 'off', 'busyaction', 'cancel');
        delete([findobj('tag', 'profileLine') findobj('tag', 'profileText1') findobj('tag', 'profileText2') findobj('tag', 'profileDistText')]);
        [view, coord] = getAxisInfo(hAxis, 'view', 'coord');
        axesToDraw = hAxis;
        for i=1:length(stateS.handle.CERRAxis);
            [otherView, otherCoord] = getAxisInfo(stateS.handle.CERRAxis(i), 'view', 'coord');
            if isequal(view, otherView) & isequal(coord, otherCoord) & ~isequal(hAxis, stateS.handle.CERRAxis(i));
                axesToDraw = [axesToDraw;stateS.handle.CERRAxis(i)];
            end
        end
        for i=1:length(axesToDraw);
            line([cP(1,1) cP(1,1)], [cP(2,2) cP(2,2)], 'tag', 'profileLine', 'userdata', hAxis, 'parent', axesToDraw(i), 'marker', '+', 'color', [.8 .8 .8], 'hittest', 'off');
        end
        switch upper(view)
            case 'TRANSVERSE'
                doseProfileFigure('NEW_POINTS', [cP(1,1) cP(2,2) coord], [cP(1,1) cP(2,2) coord]);
            case 'SAGITTAL'
                doseProfileFigure('NEW_POINTS', [coord cP(1,1) cP(2,2)], [coord cP(1,1) cP(2,2)]);
            case 'CORONAL'
                doseProfileFigure('NEW_POINTS', [cP(1,1) coord cP(2,2)], [cP(1,1) coord cP(2,2)]);
        end
        return;

    case 'DOSEPROFILEMOTION'
        allLines = findobj('tag', 'profileLine');
        if isempty(allLines)
            return;
        end
        rL = allLines(1);
        hAxis = get(rL, 'userdata');
        xD = get(rL, 'XData');
        yD = get(rL, 'YData');
        if isempty(varargin)
            cP = get(hAxis, 'CurrentPoint');
        else
            cP = [xD(2) yD(2);
                xD(2) yD(2)];
        end
        CERRStatusString(['(' num2str(xD(1)) ',' num2str(yD(1)) ') to (' num2str(cP(1,1)) ',' num2str(cP(2,2)) ') Dist: ' num2str(sqrt(sepsq([xD(1) yD(1)]', [cP(1,1) cP(2,2)]')), '%0.3g') ' cm'], 'gui');
        [view, coord] = getAxisInfo(hAxis, 'view', 'coord');
        switch upper(view)
            case 'TRANSVERSE'
                doseProfileFigure('NEW_POINTS', [xD(1) yD(1) coord], [cP(1,1) cP(2,2) coord]);
            case 'SAGITTAL'
                doseProfileFigure('NEW_POINTS', [coord xD(1) yD(1)], [coord cP(1,1) cP(2,2)]);
            case 'CORONAL'
                doseProfileFigure('NEW_POINTS', [xD(1) coord yD(1)], [cP(1,1) coord cP(2,2)]);
        end
        doseProfileFigure('refresh');
        set(allLines, 'XData', [xD(1), cP(1,1)]);
        set(allLines, 'YData', [yD(1), cP(2,2)]);
        return;
    case 'DOSEPROFILEMOTIONDONE'
        hFig = gcbo;
        set(hFig, 'interruptible', 'on', 'busyaction', 'queue');
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
        return;
        %%%%%
        
        
        %CALLBACKS TO SCAN WINDOW            
    case 'TOGGLESCANWINDOWING'
        toggleState = get(gcbo,'value');
        if toggleState == 1
            CERRStatusString('Click and drag mouse on a view')
            stateS.scanWindowState = 1;
            stateS.turnDoseOnInteractiveWindowing = 0;
            if stateS.doseToggle == 1
                stateS.turnDoseOnInteractiveWindowing = 1;
                sliceCallBack('doseToggle')
            end
        else
            CERRStatusString('')
            stateS.scanWindowState = 0;
            if stateS.turnDoseOnInteractiveWindowing
                stateS = rmfield(stateS,'turnDoseOnInteractiveWindowing');
                sliceCallBack('doseToggle')
            end            
        end
        
    case 'SCANWINDOWSTART'
        hAxis = gca;
        hFig  = get(hAxis, 'parent');
        cP    = get(hAxis, 'CurrentPoint');
        set(hFig, 'interruptible', 'off', 'busyaction', 'cancel');
        stateS.scanWindowCurrentPoint = cP(1,1:2);
        return;     
        
        scanWindowMotion
    case 'SCANWINDOWMOTION'
        hAxis = gca;
        hFig  = get(hAxis, 'parent');
        cP    = get(hAxis, 'CurrentPoint');
        pointDiff =  cP(1,1:2) - stateS.scanWindowCurrentPoint;
        [dX,dY] = getAxisInfo(hAxis,'xRange','yRange');
        percentMov = abs(pointDiff./[dX(2)-dX(1)+eps dY(2)-dY(1)+eps]);
        percentMov = percentMov/max(percentMov);
        pointDiff = sign(pointDiff);
        stateS.scanWindowCurrentPoint = cP(1,1:2);   
        scanNum = getAxisInfo(gca,'scanSets');
        scanUID = ['c',repSpaceHyp(planC{indexS.scan}(scanNum).scanUID(max(1,end-61):end))];
        minScanVal = stateS.scanStats.minScanVal.(scanUID);
        maxScanVal = stateS.scanStats.maxScanVal.(scanUID);
        dMov = maxScanVal - minScanVal;
        stateS.optS.CTLevel = stateS.optS.CTLevel + pointDiff(2)*dMov*0.125/100*percentMov(2);        
        stateS.optS.CTWidth = stateS.optS.CTWidth + pointDiff(1)*dMov*0.0625/100*percentMov(1); 
        stateS.optS.CTLevel = (stateS.optS.CTLevel);
        stateS.optS.CTWidth = max([1 (stateS.optS.CTWidth)]);
        set(stateS.handle.CTLevel,'String',stateS.optS.CTLevel)
        set(stateS.handle.CTWidth,'String',stateS.optS.CTWidth)
        for hAxis = stateS.handle.CERRAxis
            showCT(hAxis)
            %showDose(hAxis)
        end
        return;
        
    case 'SCANWINDOWMOTIONDONE' 
        hFig = gcf;
        set(hFig, 'interruptible', 'on', 'busyaction', 'queue');
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
        return;        
        

        %CALLBACKS TO QUERY DOSE.
    case 'TOGGLEDOSEQUERY'
        if ~stateS.doseQueryState
            toggleOffDrawModes;
            CERRStatusString('Click/drag in axis. Right click to end.');
            stateS.doseQueryState = 1;

            %Disable all right click menus;
            set(stateS.handle.CERRAxis, 'uicontextmenu', []);
        else
            CERRStatusString('');
            delete([findobj('tag', 'doseQueryPoint')]);
            stateS.doseQueryState = 0;

            %Right click menus are re-enabled in AxisClicked callback.
        end
        return;

    case 'DOSEQUERYSTART'
        cP = get(gcbo, 'CurrentPoint');
        hFig = get(gcbo, 'parent');
        delete([findobj('tag', 'doseQueryPoint')]);
        line([cP(1,1) cP(1,1)], [cP(2,2) cP(2,2)], 'tag', 'doseQueryPoint', 'userdata', gcbo, 'parent', gcbo, 'marker', '+', 'color', [1 1 1], 'hittest', 'off');
        sliceCallBack('doseQueryMotion');
        return;

    case 'DOSEQUERYMOTION'
        dQP = findobj('tag', 'doseQueryPoint');
        hAxis = get(dQP, 'userdata');
        [view, coord, doseSets] = getAxisInfo(hAxis, 'view', 'coord', 'doseSets');

        if isempty(doseSets)
            CERRStatusString('Cannot query dose in this axis: no dose is being displayed.')
            return;
        end

        doseSet = doseSets(1);
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

        %Get dose's transM, and convert requested point to dose coords.
        transM = getTransM('dose', doseSet, planC);
        [xD, yD, zD] = applyTransM(inv(transM), x, y, z);

        %Get the actual dose value using the converted point.
        dose = getDoseAt(doseSet,xD,yD,zD,planC);

        CERRStatusString(['x = ' num2str(x) ', y = ' num2str(y) ', z = ' num2str(z) ' Dose: ' num2str(dose)], 'gui');
        return;

    case 'DOSEQUERYMOTIONDONE'
        hFig = gcbo;
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
        return;

        %CALLBACKS TO OPERATE RULER.
    case 'TOGGLERULER'
        %figure(hCSV); %Remove uicontrol focus.
        if ~stateS.gridState
            toggleOffDrawModes;
            CERRStatusString('Click/drag in axis. Right click to end.');
            stateS.gridState = 1;
            set(stateS.handle.rulerTrans, 'value', 1)
            %Disable all right click menus;
            set(stateS.handle.CERRAxis, 'uicontextmenu', []);
        else
            CERRStatusString('');
            delete([findobj('tag', 'rulerLine')]);
            stateS.gridState = 0;
            set(stateS.handle.rulerTrans, 'value', 0)
            %Right click menus are re-enabled in AxisClicked callback.
        end
        return;
    case 'RULERSTART'
        hAxis = gcbo;
        cP = get(hAxis, 'CurrentPoint');
        delete([findobj('tag', 'rulerLine') findobj('tag', 'rulerText1') findobj('tag', 'rulerText2') findobj('tag', 'distText')]);
        [view, coord] = getAxisInfo(hAxis, 'view', 'coord');
        axesToDraw = hAxis;
        for i=1:length(stateS.handle.CERRAxis);
            [otherView, otherCoord] = getAxisInfo(stateS.handle.CERRAxis(i), 'view', 'coord');
            if isequal(view, otherView) && isequal(coord, otherCoord) && ~isequal(hAxis, stateS.handle.CERRAxis(i));
                axesToDraw = [axesToDraw;stateS.handle.CERRAxis(i)];
            end
        end
        for i=1:length(axesToDraw);
            %line([cP(1,1) cP(1,1)], [cP(2,2) cP(2,2)], 'tag', 'rulerLine', 'userdata', hAxis, 'eraseMode', 'xor', 'parent', axesToDraw(i), 'marker', '+', 'color', [.8 .8 .8], 'hittest', 'off');
            line([cP(1,1) cP(1,1)], [cP(2,2) cP(2,2)], 'tag', 'rulerLine', 'userdata', hAxis, 'parent', axesToDraw(i), 'marker', '+', 'color', [.8 .8 .8], 'hittest', 'off');
        end
        return;
    case 'RULERMOTION'
        allLines = findobj(gcbo, 'tag', 'rulerLine');
        if isempty(allLines)
            return
        end
        rL = allLines(1);
        hAxis = get(rL, 'userdata');
        cP = get(hAxis, 'CurrentPoint');
        xD = get(rL, 'XData');
        yD = get(rL, 'YData');
        set(allLines, 'XData', [xD(1), cP(1,1)]);
        set(allLines, 'YData', [yD(1), cP(2,2)]);
        CERRStatusString(['(' num2str(xD(1)) ',' num2str(yD(1)) ') to (' num2str(cP(1,1)) ',' num2str(cP(2,2)) ') Dist: ' num2str(sqrt(sepsq([xD(1) yD(1)]', [cP(1,1) cP(2,2)]')), '%0.3g') ' cm'], 'gui');
        return;
    case 'RULERMOTIONDONE'
        hFig = gcbo;
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
        return;
        %%%%%
        
    case 'TOGGLESPOTLIGHT' 
        if stateS.spotlightState
            stateS.spotlightState = 0;
        else
            stateS.spotlightState = 1;
        end
        if stateS.spotlightState
            toggleOffDrawModes;
            CERRStatusString('Click/drag in axis. Right click to end.');
            %stateS.spotlightState = 1;
            %Disable all right click menus;
            set(stateS.handle.CERRAxis, 'uicontextmenu', []);
        else
            CERRStatusString('');
            delete([findobj('tag', 'spotlight_patch'); findobj('tag', 'spotlight_xcrosshair'); findobj('tag', 'spotlight_ycrosshair')]);            
        end        
        
        
    case 'SPOTLIGHTSTART'
        hAxis = gcbo;
        cP = get(hAxis, 'CurrentPoint');
        delete([findobj('tag', 'spotlight_patch'); findobj('tag', 'spotlight_xcrosshair'); findobj('tag', 'spotlight_ycrosshair')]);
        [view, coord] = getAxisInfo(hAxis, 'view', 'coord');
        axesToDraw = hAxis;
        for i=1:length(stateS.handle.CERRAxis);
            [otherView, otherCoord] = getAxisInfo(stateS.handle.CERRAxis(i), 'view', 'coord');
            if isequal(view, otherView) & isequal(coord, otherCoord) & ~isequal(hAxis, stateS.handle.CERRAxis(i));
                axesToDraw = [axesToDraw;stateS.handle.CERRAxis(i)];
            end
        end
        delta = 0.2;
        cross_hair_delta = 2;
        thetaV = linspace(0,2*pi,30);
        xV = cP(1,1) + delta*cos(thetaV);
        yV = cP(2,2) + delta*sin(thetaV);
        for i=1:length(axesToDraw);
            % patch([cP(1,1)-delta cP(1,1)+delta cP(1,1)+delta cP(1,1)-delta cP(1,1)-delta], [cP(2,2)-delta cP(2,2)-delta cP(2,2)+delta cP(2,2)+delta cP(2,2)-delta], [0 1 0], 'tag', 'spotlight', 'userdata', hAxis, 'eraseMode', 'xor', 'parent', axesToDraw(i), 'edgeColor', 'none', 'faceColor', [0 1 0], 'faceAlpha', 0.5, 'hittest', 'off');
            patch(xV, yV, [0 1 0], 'tag', 'spotlight_patch', 'userdata', hAxis, 'parent', axesToDraw(i), 'edgeColor', 'none', 'faceColor', [1 1 0], 'faceAlpha', 0.9, 'hittest', 'off');
            line([cP(1,1)-cross_hair_delta cP(1,1)+cross_hair_delta], [cP(2,2) cP(2,2)], 'tag', 'spotlight_xcrosshair', 'userdata', hAxis, 'eraseMode', 'xor', 'parent', axesToDraw(i),  'color', [1 1 0], 'hittest', 'off','linewidth',1);
            line([cP(1,1) cP(1,1)], [cP(2,2)-cross_hair_delta cP(2,2)+cross_hair_delta], 'tag', 'spotlight_ycrosshair', 'userdata', hAxis, 'eraseMode', 'xor', 'parent', axesToDraw(i),  'color', [1 1 0], 'hittest', 'off','linewidth',1);
            line(cP(1,1), cP(2,2), 'tag', 'spotlight_trail', 'userdata', hAxis, 'parent', axesToDraw(i),  'color', [1 0.4 0.2], 'hittest', 'off','linewidth',3);
        end
        return;
        
        
    case'SPOTLIGHTMOTION'
        spotlight = findobj(gcbo,'tag', 'spotlight_patch');        
        if isempty(spotlight)
            return
        end
        hAxis = get(spotlight(1), 'userdata');
        spotlight_trail = findobj(gcbo, 'tag', 'spotlight_trail');
        cP = get(hAxis, 'CurrentPoint');
        xTrailV = [get(spotlight_trail(1), 'XData'), cP(1,1)];
        yTrailV = [get(spotlight_trail(1), 'YData'), cP(2,2)];
        numTrailPts = 20;
        if length(yTrailV) > numTrailPts
            xTrailV = xTrailV(end-numTrailPts+1:end);
            yTrailV = yTrailV(end-numTrailPts+1:end);
        end
        set(spotlight_trail, 'XData', xTrailV, 'YData', yTrailV);
        delta = 0.2;
        cross_hair_delta = 2;
        thetaV = linspace(0,2*pi,30);
        xV = cP(1,1) + delta*cos(thetaV);
        yV = cP(2,2) + delta*sin(thetaV);        
        %set(spotlight, 'XData', [cP(1,1)-delta cP(1,1)+delta cP(1,1)+delta cP(1,1)-delta cP(1,1)-delta]);
        %set(spotlight, 'YData', [cP(2,2)-delta cP(2,2)-delta cP(2,2)+delta cP(2,2)+delta cP(2,2)-delta]);
        set(spotlight, 'XData', xV);
        set(spotlight, 'YData', yV);
        spotlight_x_hair = findobj(gcbo, 'tag', 'spotlight_xcrosshair');
        spotlight_y_hair = findobj(gcbo, 'tag', 'spotlight_ycrosshair');
        set(spotlight_x_hair,'XData',[cP(1,1)-cross_hair_delta cP(1,1)+cross_hair_delta], 'YData',[cP(2,2) cP(2,2)])
        set(spotlight_y_hair,'YData',[cP(2,2)-cross_hair_delta cP(2,2)+cross_hair_delta], 'XData',[cP(1,1) cP(1,1)])
        
        return;        
        
    case 'SPOTLIGHTMOTIONDONE'
        hFig = gcbo;
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
        delete([findobj('tag', 'spotlight_patch'); findobj('tag', 'spotlight_xcrosshair'); findobj('tag', 'spotlight_ycrosshair'); findobj('tag', 'spotlight_trail')]);
        return;
        
        
    case 'CTPRESET'
        %figure(hCSV); %Remove uicontrol focus.
        if stateS.imageRegistration
            value = get(stateS.handle.basePreset, 'Value');
        else
            value = get(stateS.handle.CTPreset, 'Value');
        end
        if value == length(stateS.optS.windowPresets)
            %Show top 90% of scan
            sAv = planC{indexS.scan}(stateS.scanSet).scanArray(:);
            indV = find(sAv);
            sA_no_empty = sAv(indV);
            sA_no_empty = sort(sA_no_empty);
            intensity90 = double(sA_no_empty(round(0.9*length(indV))));
            intensityMax = double(sA_no_empty(end));
            stateS.optS.CTLevel = (intensityMax - intensity90)/2;
            stateS.optS.CTWidth = (intensityMax - intensity90)/2;
            %intensity10 = double(sA_no_empty(round(0.1*length(indV))));
            %intensityMin = double(sA_no_empty(1));
            %stateS.optS.CTLevel = (intensity10 - intensityMin)/2;
            %glostateS.optS.CTWidth = (intensity10 - intensityMin)/2;
            set(stateS.handle.CTLevel, 'String', stateS.optS.CTLevel);
            set(stateS.handle.CTWidth, 'String', stateS.optS.CTWidth);                                
        elseif value ~= 1
            stateS.optS.CTLevel = stateS.optS.windowPresets(value).center;
            stateS.optS.CTWidth = stateS.optS.windowPresets(value).width;
            set(stateS.handle.CTLevel, 'String', stateS.optS.CTLevel);
            set(stateS.handle.CTWidth, 'String', stateS.optS.CTWidth);                    
        end
        stateS.CTDisplayChanged = 1;
        %         stateS.doseChanged = 1; %CT Level changed, so colorwash must be redrawn
        if isempty(planC)
            return
        end
        CERRRefresh
        return
    case 'CTLEVEL'
        %figure(hCSV); %Remove uicontrol focus.
        if stateS.imageRegistration
            set(stateS.handle.basePreset, 'Value', 1);
            str = get(stateS.handle.baseCTLevel,'String');
        else
            set(stateS.handle.CTPreset, 'Value', 1);
            str = get(stateS.handle.CTLevel,'String');
        end
        stateS.optS.CTLevel = str2num(str);
        %         stateS.doseChanged = 1; %CT Level changed, so colorwash must be redrawn
        stateS.CTDisplayChanged =1;
        CERRRefresh
        return;

    case 'CTWIDTH'
        %figure(hCSV); %Remove uicontrol focus.
        if stateS.imageRegistration
            set(stateS.handle.basePreset, 'Value', 1);
            str = get(stateS.handle.baseCTWidth,'String');
        else
            set(stateS.handle.CTPreset, 'Value', 1);
            str = get(stateS.handle.CTWidth,'String');
        end
        stateS.optS.CTWidth = str2num(str);
        %         stateS.doseChanged = 1; %CT Level changed, so colorwash must be
        %         redrawn
        stateS.CTDisplayChanged =1;
        CERRRefresh
        return
    case 'SAVEPLANC'
        if stateS.workspacePlan
            error('Cannot "Save" a workspace plan: it has no associated file.  Use "Save As..."');
        end
        planC = save_planC(planC,stateS.optS, 'save');
        set(stateS.handle.CERRSliceViewer, 'name', ['CERR:  ' stateS.CERRFile]);
        return

    case 'SAVEASPLANC'
        if stateS.workspacePlan
            %Create CERRFile--workspace plans have no associated path/file.
            stateS.CERRFile = fullfile(getCERRPath, 'workspacePlan');
        end
        %Save plan as new filename.
        planC = save_planC(planC,stateS.optS, 'saveas');
        stateS.workspacePlan = 0;

        %Update recent file list, by removing files with the same name or the same name minus .bz2
        ind1 = find(strcmpi(stateS.planHistory, stateS.CERRFile));
        stateS.planHistory(ind1) = [];
        stateS.planHistory = {stateS.CERRFile, stateS.planHistory{1:end}};
        if length(stateS.planHistory) > 4
            stateS.planHistory = {stateS.planHistory{1:4}};
        end
        planHistory = stateS.planHistory;
        %Save functions... modified to work with matlab 7
        saveOpt = getSaveInfo;
        if ~isempty(saveOpt);
            save(fullfile(getCERRPath, 'planHistory'), 'planHistory', saveOpt);
        else
            save(fullfile(getCERRPath, 'planHistory'), 'planHistory');
        end
        %         save(fullfile(getCERRPath, 'planHistory'), 'planHistory');
        set(stateS.handle.CERRSliceViewer, 'name', ['CERR:  ' stateS.CERRFile]);
        return

    case 'COMMAND'
        %figure(hCSV); %Remove uicontrol focus.

        keyPressed = get(gcbf, 'CurrentCharacter');
        keyValue = uint8(keyPressed);
        if keyValue==13
            runCERRCommand;
        end
        return

    case 'STRUCTUREFUSION'
        structureFusionGui('init', planC);
        return;

    case 'ABOUTCERR'
        showAboutCERR
        return

    case 'ABOUTDICOMRT'
%         html_file = which('index.html');
%         showToolbar = 1;
%         showAddressBox = 1;
%         activeBrowser = com.mathworks.mde.webbrowser.WebBrowser.createBrowser(showToolbar, showAddressBox);
%         activeBrowser.setCurrentLocation(html_file);

        web http://cerr.info/cerrwiki/index.php/CERR?w=CERRWiKi#DICOM_Import.2C_which_is_DICOMJ

    case 'TARGETPIXEL'
        x = varargin{1};
        y = varargin{2};
        return;

    case 'LOOP'
        loopH = stateS.handle.loopTrans;
        set(loopH,'visible','off')
        unloopH = stateS.handle.unloopTrans;
        set(unloopH,'visible','on')
        maxSlice = length(planC{indexS.scan}(stateS.scanSet).scanInfo);
        answerC = inputdlg('How many seconds between slices?');
        if ~isempty(answerC)
            deltaT = str2num(answerC{:});
            while  ((stateS.dir == 1 & stateS.sliceNum < maxSlice) | (stateS.dir == -1 & stateS.sliceNum > 1)) & get(unloopH,'userdata') == 1
                tic
                sliceCallBack('step',1)
                if ~isempty(varargin)  %run an extra command on each slice
                    runCERRCommand(varargin{1});
                end
                elapsed = toc;
                if elapsed < deltaT
                    pause(deltaT-elapsed)
                end
                drawnow
            end
        end
        set(unloopH,'visible','off','userdata',1)
        set(loopH,'visible','on')
        return

    case 'MOVIELOOP'  %Capture transverse loop images into an avi movie.  Contributed by Angel Blanco.
        loopH = stateS.handle.loopTrans;
        set(loopH,'visible','off')
        unloopH = stateS.handle.unloopTrans;
        set(unloopH,'visible','on')
        maxSlice = length(planC{indexS.scan}(stateS.scanSet).scanInfo);
        [fname pname] = uiputfile({'*.avi'},'Save the movie .avi file as:');

        try
            if ~strcmpi(fname(end-3:end),'.avi')
                fname = [fname, '.avi'];
            end
        catch
            fname = [fname, '.avi'];
        end
        saveFile = [pname fname];
        answerC = inputdlg('How many seconds between slices in the movie playback?');
        mov = avifile(saveFile,'COMPRESSION', 'None','FPS',1/str2num(answerC{:}));
        CERRRefresh %refresh once so that artifacts from previous windows arent in first movie frame.

        while  ((stateS.dir == 1 & stateS.sliceNum < maxSlice) | (stateS.dir == -1 & stateS.sliceNum > 1)) & get(unloopH,'userdata') == 1
            CERRStatusString('Movie capture in progress.')
            drawnow
            % Capture information into avi movie file
            % aib 11-29-2002
            F = getframe(gca); % capture into matlab mov file
            mov = addframe(mov,F);
            sliceCallBack('step',1)
        end
        %Close movie file
        mov = close(mov);
        set(unloopH,'visible','off','userdata',1)
        set(loopH,'visible','on')
        CERRStatusString('Finished movie capture')
        return

    case 'SELECTSCAN'

        if stateS.CTToggle == -1
            hWarn = warndlg('Please turn on the scan');
            waitfor(hWarn);
            return;
        end

        if stateS.contourState
            hWarn = warndlg('Please exit Contouring Mode before changing Scan');
            waitfor(hWarn);
            return;
        end

        stateS.scanSet = str2num(varargin{1});

        structureSet = getStructureSetAssociatedScan(stateS.scanSet);

        if isempty(structureSet)
            stateS.structSet = [];
        else
            stateS.structSet = structureSet(1);
        end

        delete(findobj('tag', 'structContour'));

        delete(findobj('tag', 'structContourDots'));

        doseNum = getScanAssociatedDose(stateS.scanSet);

        if isempty(doseNum)
            stateS.doseSet = [];
        else
            stateS.doseSet = doseNum;
            stateS.doseSetChanged = 1;
        end


        hFigure = findobj('tag', 'navigationFigure');

        if ~isempty(hFigure)
            navigationMontage('init',stateS.scanSet) % initialize montage
        end

        for i=1:length(stateS.handle.CERRAxis)
            setAxisInfo(stateS.handle.CERRAxis(i), 'yRange',[]);
            setAxisInfo(stateS.handle.CERRAxis(i), 'xRange',[]);
        end

        showPlaneLocators;

        % Set Window and Width from DICOM header, if available
        CTLevel = 'temp';
        CTWidth = 'temp';
        if isfield(planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders,'WindowCenter') && isfield(planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders,'WindowWidth')
            CTLevel = planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders.WindowCenter;
            CTWidth = planC{indexS.scan}(stateS.scanSet).scanInfo(1).DICOMHeaders.WindowWidth;
        end
        if isnumeric(CTLevel) && isnumeric(CTWidth)
            set(stateS.handle.CTLevel,'string',num2str(CTLevel(1)))
            set(stateS.handle.CTWidth,'string',num2str(CTWidth(1)))
            sliceCallBack('CTLevel')
            sliceCallBack('CTWidth')
        end
        
        stateS.scanChkFlag = 1;

        CERRRefresh
        return;

    case 'SELECTIMRTP'
        ind = str2num(varargin{1});
        if ind == 0
            IMRTPGui('init');
        else
            IM = planC{indexS.IM}(ind);
            IMRTPGui('init', IM.IMDosimetry, ind);
        end
        return;

    case 'SELECTDOSE'
        stateS.doseSet = str2num(varargin{1});
        for i=1:length(stateS.handle.CERRAxis)
            setAxisInfo(stateS.handle.CERRAxis(i), 'doseSelectMode', 'auto', 'doseSets', stateS.doseSet ,  'doseSetsLast', stateS.doseSet);
        end
        stateS.doseSetChanged = 1;
        CERRRefresh
        return;
        
    case 'SELECTDOSEMORE'
        dosesToShow = 25;
        numDoses = length(planC{indexS.dose});
        doseStrC = {};
        count = 1;
        for i = dosesToShow+1 : numDoses
            doseStrC{count} = [num2str(i) '.  ' planC{indexS.dose}(i).fractionGroupID];
            count = count + 1;
        end
        initialValue = [];
        if stateS.doseSet > dosesToShow
            initialValue = max(1,stateS.doseSet - 25);
        end
        doseIndex = listdlg('PromptString','Toggle Dose', 'SelectionMode','single','ListString',doseStrC,'InitialValue',initialValue);
        if ~isempty(doseIndex)
            sliceCallBack('selectDose',num2str(dosesToShow+doseIndex))
        end                

    case 'SELECTAXISVIEW'
        hAxis = varargin{1};
        view  = varargin{2};
        [scanSets, doseSets] = getAxisInfo(hAxis, 'scanSets', 'doseSets');
        if ~isempty(scanSets)
            [xV, yV, zV] = getScanXYZVals(planC{indexS.scan}(scanSets(1)));
        elseif ~isempty(doseSets)
            [xV, yV, zV] = getDoseXYZVals(planC{indexS.dose}(doseSets(1)));
        else
            xV = 0; yV = 0; zV = 0;
        end

        switch view
            case 'transverse'
                coord = median(zV);
            case 'sagittal'
                coord = median(xV);
            case 'coronal'
                coord = median(yV);
            case 'legend'
                %setAxisInfo(hAxis, 'view', view);
                %showCERRLegend(hAxis);
                return;
            case 'delete view'
                h_indice = find(stateS.handle.CERRAxis == hAxis);
                delete(stateS.handle.CERRAxis(h_indice));
                stateS.handle.CERRAxisLabel1(h_indice)=[];
                stateS.handle.CERRAxisLabel2(h_indice)=[];
                stateS.handle.CERRAxisLabel3(h_indice)=[];
                stateS.handle.CERRAxisLabel4(h_indice)=[];
                stateS.handle.CERRAxisScale1(h_indice)=[];
                stateS.handle.CERRAxisScale2(h_indice)=[];
                stateS.handle.CERRAxisTicks1(h_indice,:)=[];
                stateS.handle.CERRAxisTicks2(h_indice,:)=[];                
                stateS.handle.CERRAxis(h_indice)=[];
                stateS.currentAxis = 1;
                return
        end
        setAxisInfo(hAxis, 'coord', coord, 'view', view, 'xRange', [], 'yRange', []);
        CERRRefresh
        return

    case 'FUSION_MODE_ON'
        stateS.imageRegistration = 1;

        stateS.scanSet = [];
        stateS.doseSet = [];
        stateS.structSet = [];

        baseData     = stateS.imageRegistrationBaseDataset;
        baseDataType = stateS.imageRegistrationBaseDatasetType;
        movData      = stateS.imageRegistrationMovDataset;
        movDataType  = stateS.imageRegistrationMovDatasetType;
        %Disable all right click menus;

        set(stateS.handle.CERRAxis, 'uicontextmenu', []);
        for i=1:length(stateS.handle.CERRAxis)
            aI = get(stateS.handle.CERRAxis(i), 'userdata');
            if ~isempty(aI.scanObj)
                [aI.scanObj.redraw] = deal(1);
            end
            if ~isempty(aI.doseObj)
                [aI.doseObj.redraw] = deal(1);
            end
            set(stateS.handle.CERRAxis(i), 'userdata', aI);
        end

        if strcmpi(baseDataType, 'dose')
            stateS.doseSet = [stateS.doseSet baseData];
        elseif strcmpi(baseDataType, 'scan')
            stateS.scanSet = [stateS.scanSet baseData];
            stateS.structSet = [stateS.structSet getStructureSetAssociatedScan(baseData)];
        end

        if strcmpi(movDataType, 'dose')
            stateS.doseSet = [stateS.doseSet movData];
        elseif strcmpi(movDataType, 'scan')
            stateS.scanSet = [stateS.scanSet movData];
            stateS.structSet = [stateS.structSet getStructureSetAssociatedScan(movData)];
        end
        
        % Change the renderer
        set(stateS.handle.CERRSliceViewer,'renderer','opengl')

        CERRRefresh;

        %         for i=1:length(stateS.handle.CERRAxis)
        %             hAxis       = stateS.handle.CERRAxis(i);
        %             [view] = getAxisInfo(hAxis, 'view');
        %             switch view
        %                 case {'transverse','sagittal','coronal'}
        %                     updateAxisRange(hAxis,0);
        %             end
        %         end

        return

    case 'FUSION_MODE_OFF'
        %Re-enable right click menus;
        for i=1:length(stateS.handle.CERRAxis)
            CERRAxisMenu(stateS.handle.CERRAxis(i));
        end

        for i=1:length(stateS.handle.CERRAxis)
            aI = get(stateS.handle.CERRAxis(i), 'userdata');
            if ~isempty(aI.scanObj)
                [aI.scanObj.redraw] = deal(1);
            end
            if ~isempty(aI.doseObj)
                [aI.doseObj.redraw] = deal(1);
            end
            set(stateS.handle.CERRAxis(i), 'userdata', aI);
        end
        stateS.imageRegistration = 0;
        stateS.scanSet = 1;
        stateS.structSet = getStructureSetAssociatedScan(1);

        if length(planC{indexS.dose}) == 0
            stateS.doseSet = '';
        else
            stateS.doseSet = 1;
        end
        
        set(stateS.handle.CERRSliceViewer,'renderer','zbuffer')
        
        CERRRefresh
        return

    case 'SELECT_FUSION_DATA'
        switch upper(stateS.imageRegistrationBaseDatasetType)
            case 'scan'
                for i=1:length(stateS.handle.CERRAxis)
                    ud = get(stateS.handle.CERRAxis(i), 'userdata');
                    ud.scanSet = str2num(varargin{1});
                end
            case 'dose'
                for i=1:length(stateS.handle.CERRAxis)
                    ud = get(stateS.handle.CERRAxis(i), 'userdata');
                    ud.scanSet = str2num(varargin{1});
                end
        end
        switch upper(stateS.imageRegistrationMovDatasetType)
            case 'scan'
            case 'dose'
        end
        stateS.imageRegistrationBaseDataset
        stateS.imageRegistrationMovDataset
        stateS.imageRegistrationMovDatasetType
        return;


    case 'EDITSTRUCT'
        stateS.editStructNum = str2num(varargin{1});
        if isempty(stateS.editStructNum)
            if strcmpi(varargin{1},'new struct')
                in = 'new struct';
            else
                warning('wrong editStruct option.')
                return
            end
        else
            in = stateS.editStructNum;
        end
        editStructFields(in);
        return

    case 'SHOWDVH'
        showDVHMenu(stateS.doseSet, indexS, stateS.optS, 'init')
        return

        %wy callbacks for volume clip
    case 'CLIPSTART'
        hAxis = gcbo;
        ud = get(hAxis, 'userdata');
        cP = get(hAxis, 'CurrentPoint');
        axesToDraw = hAxis;
        
        switch stateS.ROIcreationMode
            
            case 1 % Rectangulat
                %Delete current clipbox to redraw
                delete(findobj('tag', 'clipBox', 'userdata', ud.view));
                %Delete clipboxes on other axes
                hClip = findobj('tag', 'clipBox');
                if ~isempty(hClip)
                    for i=1:length(hClip)
                        viewTypeC{i} = get(hClip(i),'userData');
                    end
                    viewTypeC = unique(viewTypeC);
                    if length(viewTypeC) > 1
                        indToDelete = ~ismember(viewTypeC,ud.view);
                        delete(hClip(indToDelete))
                    end
                end                
                
                switch ud.view
                    case 'transverse'
                        line([cP(1,1) cP(1,1),cP(1,1) cP(1,1) cP(1,1)], [cP(2,2) cP(2,2) cP(2,2) cP(2,2) cP(2,2)], ...
                            'tag', 'clipBox', 'userdata', 'transverse', ...
                            'parent', axesToDraw, 'marker', 's', 'markerFaceColor', 'r', 'linestyle', '-', 'color', [.8 .8 .1], 'hittest', 'off');
                    case 'sagittal'
                        line([cP(1,1) cP(1,1),cP(1,1) cP(1,1) cP(1,1)], [cP(2,2) cP(2,2) cP(2,2) cP(2,2) cP(2,2)], ...
                            'tag', 'clipBox', 'userdata', 'sagittal', ...
                            'parent', axesToDraw, 'marker', 's', 'markerFaceColor', 'r', 'linestyle', '-', 'color', [.8 .8 .1], 'hittest', 'off');
                    case 'coronal'
                        line([cP(1,1) cP(1,1),cP(1,1) cP(1,1) cP(1,1)], [cP(2,2) cP(2,2) cP(2,2) cP(2,2) cP(2,2)], ...
                            'tag', 'clipBox', 'userdata', 'coronal', ...
                            'parent', axesToDraw, 'marker', 's', 'markerFaceColor', 'r', 'linestyle', '-', 'color', [.8 .8 .1], 'hittest', 'off');
                end
                
            case 2 % Free-hand
                allLines = findobj(gcbo, 'tag', 'clipBox', 'userdata', ud.view);                
                
                if isempty(allLines)
                    
                    switch ud.view
                        case 'transverse'
                            line(cP(1,1), cP(2,2), ...
                                'tag', 'clipBox', 'userdata', 'transverse', ...
                                'parent', axesToDraw, 'linestyle', '-', 'color', [.8 .8 .1], 'linewidth', 2, 'hittest', 'off');
                        case 'sagittal'
                            line(cP(1,1), cP(2,2), ...
                                'tag', 'clipBox', 'userdata', 'sagittal', ...
                                'parent', axesToDraw, 'linestyle', '-', 'color', [.8 .8 .1], 'linewidth', 2, 'hittest', 'off');
                        case 'coronal'
                            line(cP(1,1), cP(2,2), ...
                                'tag', 'clipBox', 'userdata', 'coronal', ...
                                'parent', axesToDraw, 'linestyle', '-', 'color', [.8 .8 .1], 'linewidth', 2, 'hittest', 'off');
                    end
                    
                else
                    p0 = allLines(1);
                    xD = get(p0, 'XData');
                    yD = get(p0, 'YData');
                    xData = [xD, cP(1,1)];
                    yData = [yD, cP(2,2)];
                    set(p0, 'XData', xData, 'YData', yData);                    
                    
                end
                
        end
        

    case 'CLIPMOTION'
        hAxis = gca;
        ud = get(hAxis, 'userdata');
        cP = get(hAxis, 'CurrentPoint');        
        allLines = findobj(gcbo, 'tag', 'clipBox', 'userdata', ud.view);
        p0 = allLines(1);
        xD = get(p0, 'XData');
        yD = get(p0, 'YData');
        
        switch stateS.ROIcreationMode
            
            case 1 % Rectangle
                switch ud.view
                    case 'transverse'
                        set(allLines, 'XData', [xD(1), xD(1),   cP(1,1), cP(1,1), xD(1)]);
                        set(allLines, 'YData', [yD(1), cP(2,2), cP(2,2), yD(1),   yD(1)]);
                        
                    case 'sagittal'
                        set(allLines, 'XData', [xD(1), cP(1,1), cP(1,1), xD(1), xD(1)]);
                        set(allLines, 'YData', [yD(1), yD(1),   cP(2,2), cP(2,2), yD(1)]);
                    case 'coronal'
                        set(allLines, 'XData', [xD(1), cP(1,1), cP(1,1), xD(1), xD(1)]);
                        set(allLines, 'YData', [yD(1), yD(1),   cP(2,2), cP(2,2), yD(1)]);
                end
                %CERRStatusString(['(' num2str(xD(1)) ',' num2str(yD(1)) ') to (' num2str(cP(1,1)) ',' num2str(cP(2,2)) ') Dist: ' num2str(sqrt(sepsq([xD(1) yD(1)]', [cP(1,1) cP(2,2)]')), '%0.3g') ' cm'], 'gui');
                return;
                
            case 2 % Free-hand                
                xData = [xD, cP(1,1)];
                yData = [yD, cP(2,2)];
                set(p0, 'XData', xData, 'YData', yData);
        end
        
    case 'CLIPMOTIONDONE'
        hFig = gcbo;
        set(hFig, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');

        %save line handles to miscHandle;
        oldMiscHandles = getAxisInfo(gca, 'miscHandles');
        hBox = findobj(gca, 'tag', 'clipBox');
        setAxisInfo(gca, 'miscHandles', [oldMiscHandles reshape(hBox, 1, [])]);   
        
        return;

    case 'SETCLIPSTATE'
        ud = get(gca, 'userdata');
        clipHv = [];
        for axisNum = 1:length(stateS.handle.CERRAxis)
            clipHv = [clipHv findobj(stateS.handle.CERRAxis(axisNum),'tag','clipBox')];
        end
        if length(clipHv) >= 2
            ButtonName = questdlg('Choose next step:', 'Next step?', 'Finalize this view', 'Redo this view', 'Create 3D ROI', 'Redo this view');
        else
            ButtonName = questdlg('Choose next step:', 'Next step?', 'Finalize this view', 'Redo this view', 'Exit', 'Redo this view');
        end
        
        switch ButtonName
            case 'Finalize this view'        
                createROI('clipBoxDrawn')                
        
            case 'Redo this view'
                delete(findobj('tag', 'clipBox', 'userdata', ud.view));
                
            case 'Create 3D ROI'
                createROI('createROI')
                
            case 'Exit'
                delete(findobj('tag', 'clipBox', 'userdata', ud.view));
                stateS.clipState = 0;                
        end        
        return
        
        
    case 'BASECOLORMAP'
        % change display mode to different color maps for moving set
        hAxes = stateS.handle.CERRAxis;
        
        % Set the new colormap
        colorMapIndex = get(stateS.handle.BaseCMap,'value');
        stateS.optS.CTColormap = stateS.optS.scanColorMap(colorMapIndex).name;

        stateS.optS.fusionDisplayMode = 'colorblend';

        for i=1:length(hAxes);
            ud = get(hAxes(i), 'userdata');
            for j=1:length(ud.scanObj);
                ud.scanObj(j).redraw = 1;
            end
            for j=1:length(ud.doseObj);
                ud.doseObj(j).redraw = 1;
            end            
            set(hAxes(i), 'userdata', ud);
            showCT(hAxes(i));
            showDose(hAxes(i));
        end

end


