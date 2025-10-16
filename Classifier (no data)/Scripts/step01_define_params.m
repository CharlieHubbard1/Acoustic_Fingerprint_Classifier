% Scripts/step01_define_params.m
% PURPOSE:
%   Define EVERY pipeline parameter (with defaults + annotations) and SAVE a parameter set.
%   If 'index' is empty, the script AUTO-ASSIGNS the next unused 3-digit index ('001'..'999').
%
% OUTPUT:
%   Saves parameter struct to: Datasets/Params/params_<index>.mat
%
% NOTE:
%   Only the numeric 'index' is stored with the params. The alphabetical index2 is
%   chosen later when building a dataset (step03) and when saving models (step04).

%% ---------- IDENTIFIERS ----------
% index: 3-digit string; if '', auto-assign the next free index by scanning Datasets/Params.
index  = '';            % e.g., '001' | '' for auto

%% ---------- PATHS ----------
P = cls_paths();
paths_echoDataFolder    = P.echo;
paths_fingerprintFolder = P.meta;
paths_datasetSavePath   = fullfile(P.datasets, 'Dataset1.mat');  % optional extra path
paths_modelsFolder      = P.models;
paths_modelFile         = fullfile(paths_modelsFolder, 'knn_objecttype.mat');
paths_predictionsFolder = P.preds;

%% ---------- REPRODUCIBILITY ----------
random_seed = 42;   % [] to skip rng

%% ---------- GRAPH CONSTRUCTION ----------
graph_k_neighbors     = 16;
graph_sigma_space     = 0.25;
graph_sigma_value     = 3.00;
graph_freq_step       = 10;
graph_angle_step      = 2;
graph_sigma_smoothing = 2;
graph_num_features    = 30;
graph_PlotGraphs      = false;
graph_sample_ratio    = 0.07;

%% ---------- DATASET BUILDER OPTIONS ----------
dataset_NumEmbed   = graph_num_features;
dataset_EmbedUsed  = 32;
dataset_NumEigs    = 30;
dataset_SaveToFile = true;
dataset_SavePath   = paths_datasetSavePath;
dataset_MatVersion = "-v7.3";

%% ---------- QUICK ANALYTICS ----------
quick_RunKMeans   = true;
quick_KMeansK     = 2;
quick_LabelsField = "ObjectType";
quick_KNN_K       = 5;
quick_HoldOut     = 0.2;

%% ---------- POST-TRANSFORM ----------
post_enableZScore     = true;
post_dropVarThresh    = 1e-6;
post_enablePCAWhiten  = true;
post_pcaVarKeep       = 0.95;
post_pcaMaxDims       = 32;
post_enableLDA        = false;
post_similarityMetric = "cosine";

%% ---------- PREDICTION / REPORTING ----------
pred_topKNeighborsToShow = 5;
pred_paramsForFeaturize = struct( ...
    'k_neighbors',     graph_k_neighbors, ...
    'sigma_space',     graph_sigma_space, ...
    'sigma_value',     graph_sigma_value, ...
    'freq_step',       graph_freq_step, ...
    'angle_step',      graph_angle_step, ...
    'sigma_smoothing', graph_sigma_smoothing ...
);

%% ---------- CORE PIPELINE CONTROLS USED BY FUNCTIONS ----------
feature_log1p      = true;
feature_normalize  = true;
feature_flatten    = true;
labelField         = 'ObjectType';
includeFilter      = struct();
excludeFilter      = struct();
model_type         = 'knn';     % 'knn' | 'cosine'
model_k            = 5;
model_distance     = 'cosine';

%% ---------- DO NOT EDIT BELOW ----------
% Ensure dirs
local_ensure_dir(paths_modelsFolder);
local_ensure_dir(fileparts(paths_datasetSavePath));
local_ensure_dir(paths_predictionsFolder);

% Optional seeding
if ~isempty(random_seed), rng(random_seed, 'twister'); end

% Assign index if needed
if isempty(index)
    index = next_unused_index();
    fprintf('[step01_define_params] Auto-assigned index = %s\n', index);
else
    index = pad_index(index);
end

% Build unified parameter struct (NO index2 here)
prm = struct();

% IDs
prm.index = index;             % numeric index only

% Paths (string paths preserved)
prm.paths = struct( ...
    'echoDataFolder',    string(paths_echoDataFolder), ...
    'fingerprintFolder', string(paths_fingerprintFolder), ...
    'datasetSavePath',   string(paths_datasetSavePath), ...
    'modelsFolder',      string(paths_modelsFolder), ...
    'modelFile',         string(paths_modelFile), ...
    'predictionsFolder', string(paths_predictionsFolder) ...
);

% Random
prm.random = struct('seed', random_seed);

% Graph
prm.graph = struct( ...
    'k_neighbors',     graph_k_neighbors, ...
    'sigma_space',     graph_sigma_space, ...
    'sigma_value',     graph_sigma_value, ...
    'freq_step',       graph_freq_step, ...
    'angle_step',      graph_angle_step, ...
    'sigma_smoothing', graph_sigma_smoothing, ...
    'num_features',    graph_num_features, ...
    'PlotGraphs',      graph_PlotGraphs, ...
    'sample_ratio',    graph_sample_ratio ...
);

% Dataset
prm.dataset = struct( ...
    'NumEmbed',    dataset_NumEmbed, ...
    'EmbedUsed',   dataset_EmbedUsed, ...
    'NumEigs',     dataset_NumEigs, ...
    'SaveToFile',  logical(dataset_SaveToFile), ...
    'SavePath',    string(dataset_SavePath), ...
    'MatVersion',  string(dataset_MatVersion) ...
);

% Quick analytics
prm.quick = struct( ...
    'RunKMeans',   logical(quick_RunKMeans), ...
    'KMeansK',     quick_KMeansK, ...
    'LabelsField', string(quick_LabelsField), ...
    'KNN_K',       quick_KNN_K, ...
    'HoldOut',     quick_HoldOut ...
);

% Post-transform
prm.post = struct( ...
    'enableZScore',     logical(post_enableZScore), ...
    'dropVarThresh',    post_dropVarThresh, ...
    'enablePCAWhiten',  logical(post_enablePCAWhiten), ...
    'pcaVarKeep',       post_pcaVarKeep, ...
    'pcaMaxDims',       post_pcaMaxDims, ...
    'enableLDA',        logical(post_enableLDA), ...
    'similarityMetric', string(post_similarityMetric) ...
);

% Prediction/reporting
prm.pred = struct( ...
    'topKNeighborsToShow', pred_topKNeighborsToShow, ...
    'paramsForFeaturize',  pred_paramsForFeaturize ...
);

% Compatibility fields for current Functions/*
prm.feature        = struct('log1p',feature_log1p,'normalize',feature_normalize,'flatten',feature_flatten);
prm.labelField     = labelField;
prm.includeFilter  = includeFilter;
prm.excludeFilter  = excludeFilter;
prm.model          = struct('type',model_type,'k',model_k,'distance',model_distance);

% Project paths for Functions
prm.pathsProject   = P;

% Save parameter file (params_<index>.mat)
savedPath = save_params(prm);
fprintf('[step01_define_params] Saved params to: %s\n', savedPath);

% Show summary
disp(prm);

%% Helpers
function s = pad_index(s)
    s = string(s);
    if strlength(s) < 3, s = pad(s,3,'left','0'); end
    s = char(s);
end
function idx = next_unused_index()
    Pp = cls_paths();
    paramsDir = fullfile(Pp.datasets,'Params');
    if ~exist(paramsDir,'dir'), mkdir(paramsDir); end
    used = false(1,999);
    dd = dir(fullfile(paramsDir,'params_???.mat'));
    for k = 1:numel(dd)
        nm = dd(k).name;               % params_007.mat
        tok = regexp(nm,'params_(\d{3})\.mat','tokens','once');
        if ~isempty(tok)
            n = str2double(tok{1});
            if ~isnan(n) && n>=1 && n<=999, used(n) = true; end
        end
    end
    n = find(~used,1,'first');
    if isempty(n), error('No free index available 001..999'); end
    idx = sprintf('%03d', n);
end
function local_ensure_dir(d)
    if ~exist(d,'dir'), mkdir(d); end
end
