function outPath = train_from_saved_dataset(varargin)
% train_from_saved_dataset
% Trains a model from a saved dataset_<index>_<index2>.mat produced by Step 3.
% Uses X_aug if available, else X_core. Saves model as Model_<index>_<index2>.mat.
%
% USAGE:
%   train_from_saved_dataset('index','001','index2','A');
%   % or rely on latest if omitted:
%   train_from_saved_dataset();

% ---------- parse inputs ----------
p = inputParser;
addParameter(p,'index','',@(s)ischar(s)||isstring(s));
addParameter(p,'index2','',@(s)ischar(s)||isstring(s));
parse(p,varargin{:});
idx  = string(p.Results.index);
idx2 = string(p.Results.index2);

P = cls_paths();

% ---------- locate dataset ----------
if strlength(idx)==0 || strlength(idx2)==0
    [idx, idx2, dsPath] = latest_dataset_file(P.datasets);
    fprintf('[train_from_saved_dataset] Using latest dataset: %s_%s\n', idx, idx2);
else
    idx  = pad_index(idx);
    idx2 = char(upper(string(idx2)));
    dsPath = fullfile(P.datasets, "dataset_" + idx + "_" + idx2 + ".mat");
end
if ~isfile(dsPath)
    error('Dataset not found: %s', dsPath);
end

S = load(dsPath);
if ~isfield(S,'ds'), error('File does not contain ds struct: %s', dsPath); end
ds = S.ds;

% ---------- choose feature matrix ----------
if isfield(ds,'X_aug') && ~isempty(ds.X_aug)
    X = ds.X_aug;
    featName = 'X_aug';
elseif isfield(ds,'X_core') && ~isempty(ds.X_core)
    X = ds.X_core;
    featName = 'X_core';
else
    error('No feature matrix found in dataset (need X_aug or X_core).');
end

y = ds.y;
if isempty(y)
    error('Empty labels in dataset.');
end
fprintf('[train_from_saved_dataset] Training with %s (%d samples, %d dims)\n', ...
        featName, size(X,1), size(X,2));

% ---------- get params ----------
prm = ds.params;
if ~isfield(prm,'model') || ~isfield(prm.model,'type')
    prm.model = struct('type','knn','k',5,'distance','cosine');
end

% ---------- fit model ----------
switch lower(string(prm.model.type))
    case "knn"
        k = get_or(prm.model,'k',5);
        dist = char(get_or(prm.model,'distance','cosine'));
        Mdl = fitcknn(X, y, 'NumNeighbors', k, 'Distance', dist);
    otherwise
        error('Unsupported model.type: %s', string(prm.model.type));
end

% ---------- package + save ----------
modelStruct = struct();
modelStruct.Mdl          = Mdl;
modelStruct.featureSpace = featName;
modelStruct.labels       = unique(y);
modelStruct.params       = prm;
modelStruct.datasetPath  = dsPath;
modelStruct.datasetIndex = struct('index',char(ds.index),'index2',char(ds.index2));
modelStruct.trainedOn    = datestr(now, 31);

outPath = fullfile(P.models, "Model_" + char(ds.index) + "_" + char(ds.index2) + ".mat");
save(outPath, '-struct', 'modelStruct', '-v7.3');
fprintf('[train_from_saved_dataset] Saved model to %s\n', outPath);
end

% ---------- helpers ----------
function s = pad_index(s)
    s = string(s);
    if strlength(s) < 3, s = pad(s,3,'left','0'); end
    s = char(s);
end

function [idx, idx2, path] = latest_dataset_file(datasetsDir)
dd = dir(fullfile(datasetsDir, 'dataset_???_?.mat'));
if isempty(dd), error('No dataset_???_?.mat files found in %s', datasetsDir); end
[~,I] = max([dd.datenum]);
nm = dd(I).name;  % dataset_001_A.mat
tok = regexp(nm,'dataset_(\d{3})_([A-Za-z])\.mat','tokens','once');
idx = tok{1}; idx2 = tok{2};
path = fullfile(dd(I).folder, dd(I).name);
end

function v = get_or(S, name, default)
if ~isstruct(S) || ~isfield(S,name), v = default; else, v = S.(name); end
end
