% Scripts/edit_context_metadata.m
% Add/edit/remove metadata fields in "* w metadata.mat" files.
% Supports:
%   1) Explicit file list: names or full paths
%   2) Bulk by filter: all files where st.(field)==value
% Also writes a summary: "Fingerprint Metadata/all_metadata_values.txt"
%
% EXAMPLES
%   % set fields on specific files
%   edit_context_metadata('files',{'solid cone run 1','hollow cone run 2'}, ...
%                         'set',struct('Environment',"tank",'Condition',"new"));
%
%   % bulk edit where ObjectType == "solid cone"
%   edit_context_metadata('filter',struct('field','ObjectType','value',"solid cone"), ...
%                         'set',struct('hasTail',false));
%
%   % remove fields
%   edit_context_metadata('files',{'solid cone run 1'}, 'removeFields',{'hasTail'});

function report = edit_context_metadata(varargin)
P = cls_paths();

% ---- inputs
p = inputParser;
addParameter(p,'files',{},@(c)iscell(c)||isstring(c)||ischar(c));
addParameter(p,'filter',struct(),@(s)isstruct(s));
addParameter(p,'set',struct(),@(s)isstruct(s));
addParameter(p,'removeFields',{},@(c)iscell(c)||isstring(c));
parse(p,varargin{:});
filesIn      = p.Results.files;
flt          = p.Results.filter;
toSet        = p.Results.set;
toRemove     = cellstr(p.Results.removeFields);

if isstring(filesIn)||ischar(filesIn), filesIn = cellstr(filesIn); end

% ---- resolve targets
targets = {};
if ~isempty(filesIn)
    targets = resolve_files(P, filesIn);
elseif ~isempty(fieldnames(flt))
    targets = filter_files(P, flt);
else
    error('Provide either ''files'' or ''filter''.');
end
if isempty(targets), warning('No matching metadata files.'); report = []; return; end

% ---- apply edits (with .bak)
changed = strings(0,1);
for i = 1:numel(targets)
    f = targets{i};
    S = load(f);
    if ~isfield(S,'st'), warning('No st in %s. Skipping.', f); continue; end
    st = S.st;

    % make .bak
    copyfile(f, f + ".bak", 'f');

    % set fields
    ks = fieldnames(toSet);
    for k = 1:numel(ks)
        st.(ks{k}) = toSet.(ks{k});
    end

    % remove fields
    for r = 1:numel(toRemove)
        if isfield(st, toRemove{r}); st = rmfield(st, toRemove{r}); end
    end

    save(f, 'st');
    changed(end+1,1) = string(f); %#ok<AGROW>
end

% ---- summary file
summaryPath = fullfile(P.meta, 'all_metadata_values.txt');
write_summary(P, summaryPath);

% ---- report
report.filesChanged = changed;
report.summaryPath  = summaryPath;
fprintf('[edit_context_metadata] Updated %d file(s). Summary: %s\n', numel(changed), summaryPath);
end

% ===== helpers =====
function out = resolve_files(P, names)
out = {};
for j = 1:numel(names)
    n = string(names{j});
    if endsWith(n, " w metadata.mat")
        if isfile(n), out{end+1} = char(n); continue; end %#ok<AGROW>
    end
    % try as full path
    if isfile(n)
        out{end+1} = char(n); %#ok<AGROW>
        continue
    end
    % try under Fingerprint Metadata: any subfolder
    dd = dir(fullfile(P.meta, '**', n + " w metadata.mat"));
    for k = 1:numel(dd), out{end+1} = fullfile(dd(k).folder, dd(k).name); end %#ok<AGROW>
end
end

function out = filter_files(P, flt)
fld = string(flt.field); val = flt.value;
dd = dir(fullfile(P.meta, '**', '* w metadata.mat'));
out = {};
for i = 1:numel(dd)
    fp = fullfile(dd(i).folder, dd(i).name);
    S = load(fp);
    if isfield(S,'st') && isfield(S.st, fld) && isequal(S.st.(fld), val)
        out{end+1} = fp; %#ok<AGROW>
    end
end
end

function write_summary(P, pathOut)
dd = dir(fullfile(P.meta, '**', '* w metadata.mat'));
vals = struct(); % field -> set (containers.Map)
for i = 1:numel(dd)
    S = load(fullfile(dd(i).folder, dd(i).name));
    if ~isfield(S,'st'), continue; end
    fn = fieldnames(S.st);
    for k = 1:numel(fn)
        f = fn{k};
        if ~isfield(vals, f)
            vals.(f) = containers.Map('KeyType','char','ValueType','logical');
        end
        v = S.st.(f);
        try
            vals.(f)(char(string(v))) = true;
        catch
            vals.(f)('<non-displayable>') = true;
        end
    end
end
fid = fopen(pathOut,'w');
fprintf(fid, "All metadata fields and unique values:\n\n");
F = fieldnames(vals);
for i = 1:numel(F)
    fprintf(fid, "[%s]\n", F{i});
    keys = sort(string(vals.(F{i}).keys));
    for j = 1:numel(keys), fprintf(fid, "  - %s\n", keys(j)); end
    fprintf(fid, "\n");
end
fclose(fid);
end
