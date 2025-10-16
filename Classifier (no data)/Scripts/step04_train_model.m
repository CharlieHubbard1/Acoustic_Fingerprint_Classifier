% Scripts/step04_train_model.m
% PURPOSE:
%   Train a model from a SAVED dataset and SAVE the model.
%   You choose which dataset by (index, index2).
%
% WORKFLOW:
%   1) Choose dataset to train on by defining index and index2 (selectionIndex).
%   2) Save model (Models/Model_<index>_<index2>.mat).

%% ---------- USER INPUT ----------
% Dataset identifiers:
index  = '';   % e.g., '007' | '' to default to latest dataset's index
index2 = '';   % e.g., 'A'   | '' to default to latest letter for that index

%% ---------- DO NOT EDIT BELOW ----------
P = cls_paths();

% Default index/index2 if empty
if isempty(index)
    [index, index2] = default_latest_dataset_pair();
    fprintf('[step04_train_model] Defaulted to latest dataset: index=%s index2=%s\n', index, index2);
else
    index = pad_index(index);
    if isempty(index2)
        index2 = latest_letter_for_index(index);
        fprintf('[step04_train_model] Defaulted to latest letter for index %s: %s\n', index, index2);
    end
end

% Train and save model via Functions/train_from_saved_dataset
train_from_saved_dataset('index', index, 'index2', index2);

fprintf('[step04_train_model] Saved model: %s\n', fullfile(P.models, "Model_" + string(index) + "_" + string(index2) + ".mat"));

%% --------- Helpers ---------
function s = pad_index(s)
    s = string(s);
    if strlength(s) < 3, s = pad(s,3,'left','0'); end
    s = char(s);
end

function [idx, letter] = default_latest_dataset_pair()
    P = cls_paths();
    dd = dir(fullfile(P.datasets,'dataset_???_?.mat'));
    if isempty(dd), error('No datasets found. Run step03_build_dataset first.'); end
    [~,I] = max([dd.datenum]);
    nm = dd(I).name;
    tok = regexp(nm,'dataset_(\d{3})_([A-Za-z])\.mat','tokens','once');
    idx = tok{1}; letter = upper(tok{2});
end

function letter = latest_letter_for_index(index)
    P = cls_paths();
    dd = dir(fullfile(P.datasets, "dataset_" + string(index) + "_?.mat"));
    if isempty(dd), error('No datasets for index %s. Build one first.', index); end
    [~,I] = max([dd.datenum]);
    nm = dd(I).name;
    tok = regexp(nm,'dataset_\d{3}_([A-Za-z])\.mat','tokens','once');
    letter = upper(tok{1});
end
