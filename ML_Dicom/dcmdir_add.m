function dcmdirS = dcmdir_add(filename, dcmobj, dcmdirS)
%"dcmdir_add"
%   Add a DCM file to a structure representing all DICOM files in a
%   directory and subdirectories.
%
%dcmdirS.PATIENT{pnum}.STUDY{stnum}.SERIES{sernum}.RTPLAN/CT etc.
%
%JRA 06/08/06
%YWU 03/01/08 modified the dcmdir from cell based to structure base for tree view.
%
%Usage:
%   dcmdirS = dcmdir_add(filename, dcmobj)
%   dcmdirS = dcmdir_add(filename, dcmobj, dcmdirS)
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

%Determine the type of dcmobj passed in
DirectoryRecordSequenceTag = '00041220';
modalityTag = '00080060';
if ~isempty(dcmobj.get(hex2dec(DirectoryRecordSequenceTag))) || isempty(dcmobj.get(hex2dec(modalityTag)))
    %DICOMdir, forget it.  Consider sticking it in the dcmdirS later.
    return;
end

%Create the variable if not passed in.
if ~exist('dcmdirS', 'var') || isempty(dcmdirS)
    dcmdirS.PATIENT = struct('STUDY',{}, 'info', {});
end
      
%Extract the data from the dcmobj.
patient = org.dcm4che2.data.BasicDicomObject;
patienttemplate = build_module_template('patient');
dcmobj.subSet(patienttemplate).copyTo(patient);        

%Search the patient list for this patient.
match = 0;
for i=1:length(dcmdirS.PATIENT)
    matchFlag = 0;
    try
        matchFlag = matchFlag || patient.equals(dcmdirS.PATIENT(i).info);
    catch
    end
    try
        matchFlag = matchFlag || patient.matches(dcmdirS.PATIENT(i).info, 1);
    catch
    end
    if matchFlag %patient.matches(dcmdirS.PATIENT(i).info, 1) || patient.equals(dcmdirS.PATIENT(i).info)
        dcmdirS.PATIENT(i) = searchAndAddStudy(filename, dcmobj, dcmdirS.PATIENT(i));
        match = 1;
        break;
    end
end

%If no matching patient is found, add this patient.
if ~match
    ind = length(dcmdirS.PATIENT) + 1;
    dcmdirS.PATIENT(ind).STUDY      = [];
    dcmdirS.PATIENT(ind).info         = [];
    dcmdirS.PATIENT(ind)        = searchAndAddStudy(filename, dcmobj, dcmdirS.PATIENT(ind));
    dcmdirS.PATIENT(ind).info   = patient;

end


function patientS = searchAndAddStudy(filename, dcmobj, patientS)
%Looks for the study specified in dcmobj in the patientS structure, if
%found adds it.

%Create the variable if not passed in.
if ~isfield(patientS.STUDY, 'SERIES')
    patientS.STUDY = struct('SERIES', {}, 'info', {});
end
      
%Extract the data from the dcmobj.
study = org.dcm4che2.data.BasicDicomObject;
studytemplate = build_module_template('general_study');
dcmobj.subSet(studytemplate).copyTo(study);        

studyUIDTag = '0020000D';

%Search the list for this item.
match = 0;
for i=1:length(patientS.STUDY)
    thisUID = patientS.STUDY(i).info.subSet(hex2dec(studyUIDTag));
    if study.matches(thisUID, 1)
        patientS.STUDY(i) = searchAndAddSeries(filename, dcmobj, patientS.STUDY(i));
        match = 1;
    end
end

if ~match
    ind = length(patientS.STUDY) + 1;
    patientS.STUDY(ind).SERIES = [];
    patientS.STUDY(ind).info = [];
    tmp  = searchAndAddSeries(filename, dcmobj, patientS.STUDY(ind));
    patientS.STUDY(ind) = tmp;
    patientS.STUDY(ind).info = study;    
end



function studyS = searchAndAddSeries(filename, dcmobj, studyS)
%Looks for the series specified in dcmobj in the studyS structure, if
%found adds it.

%Create the variable if not passed in.
if ~isfield(studyS, 'SERIES')
    studyS.SERIES = struct('Modality', {}, 'Data', {}, 'info', {});
end
       
%Extract the data from the dcmobj.
series = org.dcm4che2.data.BasicDicomObject;
seriestemplate = build_module_template('general_series');
dcmobj.subSet(seriestemplate).copyTo(series);        

seriesUIDTag = '0020000E';

%Search the list for this item.
match = 0;
for i=1:length(studyS.SERIES)
    thisUID = studyS.SERIES(i).info.subSet(hex2dec(seriesUIDTag));
    %to avoid different modality data in one series, it must compare whole
    %series structure, but not just UID.
    if series.matches(thisUID, 1) % series.matches(studyS.SERIES(i).info, 1)
        studyS.SERIES(i) = searchAndAddSeriesMember(filename, dcmobj, studyS.SERIES(i));
        match = 1;
    end
end

if ~match
    ind = length(studyS.SERIES) + 1;
    studyS.SERIES(ind).Modality = [];
    studyS.SERIES(ind).Data = [];
    studyS.SERIES(ind).info = [];
    studyS.SERIES(ind) = searchAndAddSeriesMember(filename, dcmobj, studyS.SERIES(ind));
    studyS.SERIES(ind).info     = series;    
end

function seriesS = searchAndAddSeriesMember(filename, dcmobj, seriesS)
%Looks for the image/plan/dose specified in dcmobj in the seriesS, if not
%found adds it.

modalityTag = '00080060';
modality = dcm2ml_Element(dcmobj.get(hex2dec(modalityTag)));

if ~isfield(seriesS, 'Modality')
    seriesS.Modality = [];
end

seriesS.Modality = modality;
ind = length(seriesS.Data) + 1;
seriesS.Data(ind).info = dcmobj;
seriesS.Data(ind).file = filename;

% if ~isfield(seriesS, modality)
%     seriesS.(modality) = {};
% end
% 
% ind = length(seriesS.(modality)) + 1;
% seriesS.(modality){ind}.info = dcmobj;
% seriesS.(modality){ind}.file = filename;
    
    
