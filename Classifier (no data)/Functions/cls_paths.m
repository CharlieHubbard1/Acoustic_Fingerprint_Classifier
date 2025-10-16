% Functions/cls_paths.m
function P = cls_paths()
    % Load canonical root
    S = load(fullfile(fileparts(mfilename('fullpath')), '..', 'class_path.mat'), 'class_path');
    root = S.class_path;

    P.root      = root;
    P.echo      = fullfile(root, 'Echo Data');
    P.meta      = fullfile(root, 'Fingerprint Metadata');
    P.datasets  = fullfile(root, 'Datasets');
    P.models    = fullfile(root, 'Models');
    P.preds     = fullfile(root, 'Predictions');
    P.functions = fullfile(root, 'Functions');
    P.scripts   = fullfile(root, 'Scripts');
end
