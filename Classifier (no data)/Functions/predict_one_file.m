% predict_one_file.m
% Usage:
%   modelPath = "C:\...\Models\knn_objecttype.mat";
%   newFile   = "C:\...\Fingerprint Metadata\some new run w metadata.mat";
%   params = struct('k_neighbors',24,'sigma_space',0.25,'sigma_value',8, ...
%                   'freq_step',12,'angle_step',4,'sigma_smoothing',2);
%   out = predict_one_file(modelPath, newFile, params);

function out = predict_one_file(modelPath, newFile, params)
    % Load trained model (contains Model.knn, Model.label, Model.OUT)
    S = load(modelPath, 'Model');
    Model = S.Model;

    % Featurize new sample to match training design
    x_new = featurize_one_sample(newFile, Model.OUT, ...
        'k_neighbors',   params.k_neighbors, ...
        'sigma_space',   params.sigma_space, ...
        'sigma_value',   params.sigma_value, ...
        'freq_step',     params.freq_step, ...
        'angle_step',    params.angle_step, ...
        'sigma_smoothing', params.sigma_smoothing);

    % Predict label
    pred = predict(Model.knn, x_new);

    % Nearest training items (by cosine similarity in feature space)
    Xtrain = Model.OUT.X_aug;
    sims   = 1 - pdist2(x_new, Xtrain, 'cosine');   % row vector
    [sims_sorted, idx_sorted] = sort(sims, 'descend');
    topK = min(10, numel(idx_sorted));

    % Try to display useful metadata about nearest neighbors
    Tm = Model.OUT.Tmeta;
    showID = repmat("N/A", topK, 1);
    if ismember('UniqID', Tm.Properties.VariableNames)
        showID = string(Tm.UniqID(idx_sorted(1:topK)));
    end
    showLabel = repmat("N/A", topK, 1);
    if ismember(Model.label, Tm.Properties.VariableNames)
        showLabel = string(Tm.(Model.label)(idx_sorted(1:topK)));
    end

    % Package outputs
    out = struct();
    out.predicted_label = string(pred);
    out.topK_neighbors  = table(showID, showLabel, sims_sorted(1:topK).', ...
                                'VariableNames', {'UniqID','Label', 'CosineSimilarity'});

    % Print a short summary
    fprintf('Predicted %s: %s\n', Model.label, string(pred));
    disp('Nearest training items:');
    disp(out.topK_neighbors);
end
