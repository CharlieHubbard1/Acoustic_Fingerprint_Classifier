% Scripts/step05_classify.m
% PURPOSE:
%   Classify object(s) using a SAVED model.
%
% WORKFLOW:
%   1) Input data files to classify (raw echo .mat with 'run' OR '* w metadata.mat').
%   2) Choose a stored model by inputting index and index2 (or leave blank to default).
%   3) Run the classifier; the script saves predictions under:
%        Predictions/predictions_<index>/Model_<index>_<index2>_prediction_<file>.mat

%% ---------- USER INPUT ----------
% Files to classify (names or full paths; raw or "w metadata")
filesToClassify = {'OC Tube run 1'};   % e.g., {'hollow cone run 2','.../objX w metadata.mat'}

% Model identifiers:
modelIndex  = '';   % e.g., '007' | '' to default to latest model index
modelIndex2 = '';   % e.g., 'A'   | '' to default to latest letter for that index

%% ---------- DO NOT EDIT BELOW ----------
P = cls_paths();

% Default modelIndex/modelIndex2 if empty
if isempty(modelIndex)
    [modelIndex, modelIndex2] = default_latest_model_pair();
    fprintf('[step05_classify] Defaulted to latest model: index=%s index2=%s\n', modelIndex, modelIndex2);
else
    modelIndex = pad_index(modelIndex);
    if isempty(modelIndex2)
        modelIndex2 = latest_model_letter_for_index(modelIndex);
        fprintf('[step05_classify] Defaulted to latest model letter for index %s: %s\n', modelIndex, modelIndex2);
    end
end

% Run classification (saves predictions per file)
results = classify_one_object('modelIndex',modelIndex,'modelIndex2',modelIndex2,'files',filesToClassify);
disp(results);

%% --------- Helpers ---------
function s = pad_index(s)
    s = string(s);
    if strlength(s) < 3, s = pad(s,3,'left','0'); end
    s = char(s);
end

function [idx, letter] = default_latest_model_pair()
    P = cls_paths();
    dd = dir(fullfile(P.models,'Model_???_?.mat'));
    if isempty(dd), error('No models found. Run step04_train_model first.'); end
    [~,I] = max([dd.datenum]);
    nm = dd(I).name;
    tok = regexp(nm,'Model_(\d{3})_([A-Za-z])\.mat','tokens','once');
    idx = tok{1}; letter = upper(tok{2});
end

function letter = latest_model_letter_for_index(index)
    P = cls_paths();
    dd = dir(fullfile(P.models, "Model_" + string(index) + "_?.mat"));
    if isempty(dd), error('No models for index %s. Train one first.', index); end
    [~,I] = max([dd.datenum]);
    nm = dd(I).name;
    tok = regexp(nm,'Model_\d{3}_([A-Za-z])\.mat','tokens','once');
    letter = upper(tok{1});
end
