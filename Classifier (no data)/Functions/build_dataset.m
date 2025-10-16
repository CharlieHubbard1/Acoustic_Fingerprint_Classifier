function ds = build_dataset(varargin)
% Wrapper:
%  1) Load params by numeric index
%  2) Build per-file heavy kNN graphs + features
%  3) Save dataset_<index>_<index2>.mat
%  -- Saves graphs with W/L as FULL by default (matches prior large files)

% parse
p = inputParser;
addParameter(p,'index','',@(s)ischar(s)||isstring(s));
addParameter(p,'index2','',@(s)ischar(s)||isstring(s));
addParameter(p,'files',{},@(c)iscell(c)||isstring(c)||ischar(c));
parse(p,varargin{:});
idx  = string(p.Results.index);
idx2 = string(p.Results.index2);
fl   = p.Results.files;
if isstring(fl)||ischar(fl), fl = cellstr(fl); end
if strlength(idx2)==0, error('build_dataset: index2 must be provided.'); end

% load params
if strlength(idx)==0, prm = load_params(); else, prm = load_params(idx); end
P = prm.pathsProject;

% build dataset
metaRoot = P.meta;
if isempty(fl), ds = build_dataset_from_folder(metaRoot, prm);
else,           ds = build_dataset_from_folder(metaRoot, prm, fl);
end

% annotate
ds.index  = char(pad_index(prm.index));
ds.index2 = char(upper(string(idx2)));

% by default, store graphs as FULL (to match your older, larger .mat files)
saveGraphsAs = "sparse";
if isfield(prm,'dataset') && isfield(prm.dataset,'SaveGraphsAs') && ~isempty(prm.dataset.SaveGraphsAs)
    saveGraphsAs = string(prm.dataset.SaveGraphsAs);
end
if saveGraphsAs == "full" && isfield(ds,'graphs') && ~isempty(ds.graphs)
    for i=1:numel(ds.graphs)
        if isempty(ds.graphs{i}), continue; end
        Gi = ds.graphs{i};
        if issparse(Gi.W), Gi.W = full(Gi.W); end
        if issparse(Gi.L), Gi.L = full(Gi.L); end
        ds.graphs{i} = Gi;
    end
end

% save
outPath = fullfile(P.datasets, "dataset_" + ds.index + "_" + ds.index2 + ".mat");
save(outPath, 'ds', get_save_flag(prm.dataset));
fprintf('[build_dataset] Saved %d samples to %s\n', numel(ds.y), outPath);

% secondary save (optional)
if isfield(prm,'dataset') && isfield(prm.dataset,'SaveToFile') && prm.dataset.SaveToFile
    sp = char(prm.dataset.SavePath);
    if ~isempty(sp)
        try
            save(sp, 'ds', get_save_flag(prm.dataset));
            fprintf('[build_dataset] Also saved dataset to prm.dataset.SavePath: %s\n', sp);
        catch ME
            warning('Could not save to prm.dataset.SavePath (%s): %s', sp, ME.message);
        end
    end
end
end

% helpers
function flag = get_save_flag(dsCfg)
if isstruct(dsCfg) && isfield(dsCfg,'MatVersion') && ~isempty(dsCfg.MatVersion)
    flag = char(dsCfg.MatVersion);
else
    flag = '-v7.3';
end
end
function s = pad_index(s)
s = string(s); if strlength(s) < 3, s = pad(s,3,'left','0'); end; s = char(s);
end
