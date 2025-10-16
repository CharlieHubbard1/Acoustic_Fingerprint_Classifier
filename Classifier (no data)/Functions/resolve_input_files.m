function fileList = resolve_input_files(P, filesIn, varargin)
% Deterministic resolver for files to classify. No recursion, no guessing.
% Requires:
%   P.paths.fingerprintFolder  (absolute)
% Optional:
%   P.paths.echoDataFolder     (absolute, for raw fallback)

ip = inputParser;
ip.addParameter('Pattern',"* w metadata.mat",@(s)ischar(s)||isstring(s));
ip.parse(varargin{:});
pat = char(ip.Results.Pattern);

assert(isfield(P,'paths') && isfield(P.paths,'fingerprintFolder') && ~isempty(P.paths.fingerprintFolder), ...
    'resolve_input_files:MissingPath', 'P.paths.fingerprintFolder must be set to an absolute path.');
fingerFolder = char(P.paths.fingerprintFolder);

if nargin<2 || isempty(filesIn)
    % default: all "* w metadata.mat" in the fingerprint folder (non-recursive)
    dd = dir(fullfile(fingerFolder, pat));
    fileList = string(fullfile({dd.folder},{dd.name}));
    if isempty(fileList)
        error('resolve_input_files:NoneFound', 'No files matched "%s" in %s.', pat, fingerFolder);
    end
    return;
end

tokens = normalize_tokens(filesIn);
out = strings(0,1);

for k = 1:numel(tokens)
    tok = tokens(k);

    % Absolute file?
    if isfile(tok)
        out(end+1,1) = tok; %#ok<AGROW>
        continue;
    end

    % Folder?
    if isfolder(tok)
        dd = dir(fullfile(tok, pat)); % non-recursive by design
        out = [out; string(fullfile({dd.folder},{dd.name}))']; %#ok<AGROW>
        continue;
    end

    % Wildcard NOT supported (deterministic rule-set). Fail fast if user passes one.
    if contains(tok,"*") || contains(tok,"?")
        error('resolve_input_files:NoWildcards', ...
              'Wildcards are not supported. Pass explicit paths, a folder, or bare names.');
    end

    % Bare name -> "<name> w metadata.mat" in fingerprint folder
    cand = fullfile(fingerFolder, tok + " w metadata.mat");
    if isfile(cand)
        out(end+1,1) = string(cand); %#ok<AGROW>
        continue;
    end

    % Optional raw fallback in echoDataFolder: "<name>.mat"
    if isfield(P.paths,'echoDataFolder') && ~isempty(P.paths.echoDataFolder)
        rawCand = fullfile(P.paths.echoDataFolder, tok + ".mat");
        if isfile(rawCand)
            out(end+1,1) = string(rawCand); %#ok<AGROW>
            continue;
        end
    end

    error('resolve_input_files:NotFound', ...
          'Could not resolve "%s". Looked at:\n  %s\n%s', tok, cand, ...
          iff(isfield(P.paths,'echoDataFolder') && ~isempty(P.paths.echoDataFolder), ...
              "  " + fullfile(P.paths.echoDataFolder, tok + ".mat"), ""));
end

% Uniquify and ensure existence
out = unique(out);
out = out(isfile(out));
if isempty(out)
    error('resolve_input_files:NoneResolved','No valid files resolved from input.');
end
fileList = out;
end

function arr = normalize_tokens(x)
    if isstring(x) || ischar(x), arr = string(x); return; end
    if iscellstr(x), arr = string(x); return; end
    if isstring(x), arr = string(x); return; end
    error('resolve_input_files:BadType','files must be char/string/cellstr.');
end

function s = iff(cond, a, b)
    if cond, s = a; else, s = b; end
end
