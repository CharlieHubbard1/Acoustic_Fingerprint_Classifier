function prm = load_params(index)
% load_params — Load a saved parameter set by numeric index (or latest).
%
% USAGE:
%   prm = load_params('007');   % exact index (3-digit or unpadded string)
%   prm = load_params();        % latest saved params overall
%
% Looks in: Datasets/Params/params_<index>.mat

P = cls_paths();
paramDir = fullfile(P.datasets, 'Params');

if nargin < 1 || isempty(index)
    % Use latest overall
    dd = dir(fullfile(paramDir, 'params_???.mat'));
    if isempty(dd), error('No saved params found in %s', paramDir); end
    [~,I] = max([dd.datenum]);
    f = fullfile(dd(I).folder, dd(I).name);
    S = load(f);
    prm = S.prm;
    return
end

index = pad_index(index);
f = fullfile(paramDir, "params_" + index + ".mat");
if ~isfile(f)
    error('Params not found: %s', f);
end
S = load(f);
prm = S.prm;

end

% ---- helper ----
function s = pad_index(s)
    s = string(s);
    if strlength(s) < 3, s = pad(s,3,'left','0'); end
    s = char(s);
end
