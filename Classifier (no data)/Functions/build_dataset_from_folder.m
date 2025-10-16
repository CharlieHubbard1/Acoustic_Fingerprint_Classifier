function ds = build_dataset_from_folder(metaRoot, prm, filesSubset)
% build_dataset_from_folder
% Scans metaRoot for "* w metadata.mat" (or a provided subset), builds per-item
% k-NN graphs and feature vectors, then assembles a dataset. Optional quick
% analytics can run (K-means / k-NN sanity checks) using prm.quick.
%
% OUTPUT ds: see build_dataset_from_structs

if nargin < 3, filesSubset = {}; end
if isstring(filesSubset) || ischar(filesSubset), filesSubset = cellstr(filesSubset); end

% get files
if isempty(filesSubset)
    dd = dir(fullfile(metaRoot, '**', '* w metadata.mat'));
    files = cellfun(@(a,b) fullfile(a,b), {dd.folder}, {dd.name}, 'uni',0);
else
    files = resolve_subset(metaRoot, filesSubset);
end

% apply include/exclude filters
files = apply_filters(files, prm.includeFilter, true);
files = apply_filters(files, prm.excludeFilter, false);

N = numel(files);
if N==0, error('No files selected after filtering.'); end

% load structs
stList = cell(1,N);
H = progress_eta(N, 'Load metadata');
for i=1:N
    S = load(files{i});
    if isfield(S,'st'), stList{i} = S.st; else, stList{i} = struct(); end
    H.update(i);
end
H.done();

% build dataset from structs
ds = build_dataset_from_structs(stList, prm);
ds.files = string(files(:));

% optional quick analytics
if get_or(prm.quick,'RunKMeans',false) && size(ds.X_core,1) >= max(2, get_or(prm.quick,'KMeansK',2))
    try
        kq = max(2, get_or(prm.quick,'KMeansK',2));
        kmeans(ds.X_core, kq, 'Replicates',3);
    catch, end
end

end

% ----- helpers -----
function files = resolve_subset(metaRoot, names)
files = {};
for j = 1:numel(names)
    n = string(names{j});
    if endsWith(n," w metadata.mat") || isfile(n)
        if isfile(n), files{end+1} = char(n); continue; end %#ok<AGROW>
    end
    dd = dir(fullfile(metaRoot, '**', n + " w metadata.mat"));
    for k = 1:numel(dd), files{end+1} = fullfile(dd(k).folder, dd(k).name); end %#ok<AGROW>
end
end

function files = apply_filters(files, flt, isInclude)
if isempty(flt) || isempty(fieldnames(flt)), return; end
flds = fieldnames(flt);
mask = false(numel(files),1);
for i=1:numel(files)
    S = load(files{i});
    if ~isfield(S,'st'), continue; end
    ok = true;
    for k = 1:numel(flds)
        f = flds{k};
        if ~isfield(S.st, f) || ~isequal(S.st.(f), flt.(f)), ok = false; break; end
    end
    mask(i) = ok;
end
if isInclude, files = files(mask); else, files = files(~mask); end
end

function v = get_or(S, name, default)
if ~isstruct(S) || ~isfield(S,name), v = default; else, v = S.(name); end
end
