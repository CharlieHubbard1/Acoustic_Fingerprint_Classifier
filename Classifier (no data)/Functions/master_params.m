% Scripts/master_params.m
% Returns a parameter struct used across dataset building and training.
% You can version configurations via (index, index2).
%
% EXAMPLE:
%   prm = master_params('index','007','index2','A');

function prm = master_params(varargin)
P = cls_paths();

p = inputParser;
addParameter(p,'index','001',@(s)ischar(s)||isstring(s));
addParameter(p,'index2','A',@(s)ischar(s)||isstring(s));
parse(p,varargin{:});
prm.index  = char(string(p.Results.index));
prm.index2 = char(string(p.Results.index2));

% ---- Feature parameters
prm.feature.log1p      = true;
prm.feature.normalize  = true;   % z-score
prm.feature.flatten    = true;

% ---- Labeling
prm.labelField         = 'ObjectType';  % change to desired target field

% ---- Dataset selection/filtering (optional)
prm.includeFilter      = struct();      % e.g., struct('Environment',"tank")
prm.excludeFilter      = struct();      % e.g., struct('Condition',"damaged")

% ---- Model/training
prm.model.type         = 'knn';         % 'knn' | 'cosine'
prm.model.k            = 5;
prm.model.distance     = 'cosine';

% ---- Paths
prm.paths = P;

% ---- Naming helpers
prm.tags.modelSuffix   = "_" + prm.index + "_" + prm.index2;
prm.tags.datasetName   = "dataset_" + prm.index + "_" + prm.index2 + ".mat";
prm.tags.modelName     = "Model" + prm.tags.modelSuffix + ".mat";
end
