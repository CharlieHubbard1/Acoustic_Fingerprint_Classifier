% Scripts/step02_edit_metadata.m
% PURPOSE:
%   Select files in "Fingerprint Metadata" either by explicit list or by filter,
%   then INTERACTIVELY apply Field/Value edits typed at the command line.
%   End editing by typing: stopEdit
%
% FIELD/VALUE INPUT FORMS:
%   {'Field',"Value"}   % string value
%   {'Field',Value}     % numeric/logical value (e.g., 12, 3.14, true/false)
%   To CLEAR a field:   {'Field',[]}  OR {'Field',""}
%
% EXAMPLES TO EDIT BELOW:
%   filesToEdit = {'solid cone run 1','hollow cone run 2'};
%   OR use a filter instead:
%   useFilter  = true;  filterField = 'ObjectType';  filterValue = "solid cone";

%% ---------- USER INPUT: SELECT FILES TO EDIT ----------
useFilter   = true;              % false: use explicit list; true: use filter
filesToEdit = {};                 % list of basenames (no " w metadata.mat") or full paths

% Filter mode (only used if useFilter=true)
filterField = 'ObjectType';       % e.g., 'Environment'
filterValue = "solid cone";       % scalar string/number to match exactly

%% ---------- DO NOT EDIT BELOW ----------
P = cls_paths();

% Resolve target files
if ~useFilter
    if isempty(filesToEdit)
        error('Provide filesToEdit or switch to filter mode.');
    end
    targets = local_resolve_files(P, filesToEdit);
else
    targets = local_filter_files(P, filterField, filterValue);
end

if isempty(targets)
    disp('[step02_edit_metadata] No matching files found.'); return;
end

fprintf('[step02_edit_metadata] %d files selected.\n', numel(targets));
for i=1:numel(targets), fprintf('  %s\n', targets{i}); end

% Interactive edit loop
disp('Enter Field/Value pairs like {''Field'',"Value"} or {''Field'',Value}; type stopEdit to finish.');
edits = {}; removals = {};
while true
    line = input('>> ', 's');
    if strcmpi(strtrim(line),'stopEdit'), break; end
    if isempty(strtrim(line)), continue; end
    try
        pair = eval(line); % expects a 1x2 cell: {'Field',Value}
        assert(iscell(pair) && numel(pair)==2 && (ischar(pair{1}) || isstring(pair{1})), ...
               'Input must be {''Field'',Value}.');
        fld = string(pair{1});
        val = pair{2};
        isClearing = (isstring(val) && strlength(val)==0) || (ischar(val) && isempty(val)) || isempty(val);
        if isClearing
            removals{end+1} = char(fld); %#ok<AGROW>
        else
            edits{end+1} = {char(fld), val}; %#ok<AGROW>
        end
    catch ME
        fprintf(2, 'Invalid input. Example: {''Environment'',"tank"} or {''hasTail'',false}\n');
        fprintf(2, 'Error: %s\n', ME.message);
    end
end

% Apply edits using the function helper (twice: set then remove)
toSet = struct();
for k=1:numel(edits)
    f = edits{k}{1}; v = edits{k}{2};
    try
        toSet.(f) = v;
    catch
        warning('Skipping field "%s" (could not assign).', f);
    end
end
if ~isempty(fieldnames(toSet))
    edit_context_metadata('files',targets,'set',toSet);
end
if ~isempty(removals)
    edit_context_metadata('files',targets,'removeFields',removals);
end

% Write our own summary (exclude EL, f0, t0 and format for Notepad)
summaryPath = fullfile(P.meta, 'all_metadata_values.txt');
local_write_summary_notepad(P.meta, summaryPath, {'EL','f0','t0'});

fprintf('[step02_edit_metadata] Done. Summary written to: %s\n', summaryPath);

%% --------- Helpers (resolver mirrors Function behavior) ---------
function out = local_resolve_files(P, names)
out = {};
for j = 1:numel(names)
    n = string(names{j});
    if endsWith(n," w metadata.mat")
        if isfile(n), out{end+1} = char(n); continue; end
    end
    if isfile(n)
        out{end+1} = char(n); continue;
    end
    dd = dir(fullfile(P.meta,'**', n + " w metadata.mat"));
    for k = 1:numel(dd)
        out{end+1} = fullfile(dd(k).folder, dd(k).name); %#ok<AGROW>
    end
end
end

function out = local_filter_files(P, fld, val)
dd = dir(fullfile(P.meta,'**','* w metadata.mat'));
out = {};
for i=1:numel(dd)
    fp = fullfile(dd(i).folder, dd(i).name);
    S = load(fp);
    if isfield(S,'st') && isfield(S.st, fld) && isequal(S.st.(fld), val)
        out{end+1} = fp; %#ok<AGROW>
    end
end
end

function local_write_summary_notepad(metaRoot, pathOut, excludeFields)
% Create a Notepad-friendly summary (CRLF endings), excluding given fields.
% Format:
%   All metadata fields and unique values:
%
%   [FieldName]
%     - value1
%     - value2
%   ...
    if nargin < 3, excludeFields = {}; end
    exc = string(excludeFields);

    % Collect unique values per field
    dd = dir(fullfile(metaRoot, '**', '* w metadata.mat'));
    fields = containers.Map('KeyType','char','ValueType','any');

    for i = 1:numel(dd)
        fp = fullfile(dd(i).folder, dd(i).name);
        S = load(fp);
        if ~isfield(S,'st'), continue; end
        fn = fieldnames(S.st);
        for k = 1:numel(fn)
            f = string(fn{k});
            if any(strcmpi(f, exc)), continue; end

            % ensure inner map exists
            key = char(f);
            if ~isKey(fields, key)
                fields(key) = containers.Map('KeyType','char','ValueType','logical');
            end

            % stringify value
            try
                v = S.st.(fn{k});
                if isstring(v) || ischar(v)
                    valStr = char(string(v));
                elseif isnumeric(v) && isscalar(v)
                    valStr = num2str(v);
                elseif islogical(v) && isscalar(v)
                    valStr = char(string(v));
                else
                    valStr = '<non-displayable>';
                end
            catch
                valStr = '<non-displayable>';
            end

            % update inner map safely
            m = fields(key);
            m(valStr) = true;
            fields(key) = m;
        end
    end

    % Write CRLF text for Notepad readability
    [fid,msg] = fopen(pathOut, 'wt');
    if fid == -1, error('Could not open summary file: %s', msg); end
    crlf = sprintf('\r\n');
    fprintf(fid, 'All metadata fields and unique values:%s%s', crlf, crlf);

    K = sort(fields.keys);
    for i = 1:numel(K)
        fprintf(fid, '[%s]%s', K{i}, crlf);
        vk = sort(fields(K{i}).keys);
        for j = 1:numel(vk)
            fprintf(fid, '  - %s%s', vk{j}, crlf);
        end
        fprintf(fid, '%s', crlf);
    end
    fclose(fid);
end
