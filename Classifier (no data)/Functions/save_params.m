function outPath = save_params(prm)
% save_params — Saves a parameter struct keyed ONLY by numeric index.
%
% Saves to: Datasets/Params/params_<index>.mat

P = prm.pathsProject;  % canonical project paths from cls_paths()
paramDir = fullfile(P.datasets, 'Params');
if ~exist(paramDir,'dir'), mkdir(paramDir); end

% Build file name and save (NO index2 here)
outPath = fullfile(paramDir, "params_" + prm.index + ".mat");
save(outPath, 'prm', '-v7.3');

fprintf('[save_params] Saved params to %s\n', outPath);
end
