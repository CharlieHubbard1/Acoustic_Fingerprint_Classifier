function [modelPath, picked] = find_model_file(P, modelIndex, modelIndex2)
% Deterministic resolver for a model file in P.paths.modelsFolder (non-recursive).

assert(isfield(P,'paths') && isfield(P.paths,'modelsFolder') && ~isempty(P.paths.modelsFolder), ...
    'find_model_file:MissingPath', 'P.paths.modelsFolder must be set to an absolute path.');
modelsDir = char(P.paths.modelsFolder);
if ~isfolder(modelsDir)
    error('find_model_file:NoModelsDir', 'Models folder does not exist: %s', modelsDir);
end

% Normalize requested indices
idxTok  = normalize_index(modelIndex);   % '' or '007'
idx2Tok = normalize_idx2(modelIndex2);   % '' or 'A'

% List files (no recursion)
D = dir(fullfile(modelsDir,'*.mat'));
if isempty(D)
    error('find_model_file:NoMat', 'No .mat files in %s.', modelsDir);
end
T = struct2table(D);
T.full = string(fullfile(T.folder, T.name));
lname = lower(string(T.name));

% Helper: pick newest among a logical mask over rows of T
    function chosenFull = pickNewest(mask)
        candIdx = find(mask);
        if isempty(candIdx)
            error('find_model_file:Internal', 'pickNewest called with empty mask.');
        end
        [~, ord] = sort(T.datenum(candIdx), 'descend');
        chosenFull = T.full(candIdx(ord(1)));
    end

% Selection logic
if ~isempty(idxTok)
    % Filter by index token first
    mIdx = contains(lname, lower(idxTok));
    if ~any(mIdx)
        error('find_model_file:NoIndex', 'No model files with index %s in %s.', idxTok, modelsDir);
    end

    if isempty(idx2Tok)
        % choose newest letter for that index
        chosen = pickNewest(mIdx);
        reason = "index_only_latest_letter";
    else
        % filter by index2 token as a standalone token bounded by _-. or ends
        pat = "(^|[_\-\.])" + lower(idx2Tok) + "([_\-\.]|$)";
        mIdx2 = mIdx & ~cellfun('isempty', regexp(lname, pat, 'once'));
        if ~any(mIdx2)
            avail = extract_letters_for_index(lname(mIdx), idxTok);
            if isempty(avail), avail = "<none detected>"; else, avail = strjoin(avail, ', '); end
            error('find_model_file:NoIndex2', ...
                'No model with index=%s and index2=%s. Available letters: %s', ...
                idxTok, idx2Tok, avail);
        end
        chosen = pickNewest(mIdx2);
        reason = "exact_index_and_letter";
    end
else
    % No index provided -> newest file in folder
    [~, iNewest] = max(T.datenum);
    chosen = T.full(iNewest);
    reason = "no_index_default_newest";
end

modelPath = char(chosen);

picked = struct;
picked.index   = idxTok;
picked.index2  = idx2Tok;
picked.reason  = reason;
picked.folder  = modelsDir;
picked.file    = string(modelPath);
end

% ---- helpers ----
function s = normalize_index(i)
    if isempty(i), s = ""; return; end
    if isstring(i) || ischar(i)
        i = regexprep(char(i), '\D', ''); % keep digits if user passed '007' or 'index=007'
        if isempty(i), s = ""; else, s = sprintf('%03d', str2double(i)); end
    elseif isnumeric(i)
        s = sprintf('%03d', i);
    else
        error('find_model_file:BadIndex','modelIndex must be numeric or string.');
    end
end

function s = normalize_idx2(x)
    if isempty(x), s = ""; return; end
    if isstring(x) || ischar(x)
        s = upper(string(x));
        if strlength(s)~=1
            error('find_model_file:BadIdx2','modelIndex2 must be a single letter like "A".');
        end
    else
        error('find_model_file:BadIdx2','modelIndex2 must be a char/string.');
    end
end

function letters = extract_letters_for_index(namesForIndex, idxTok)
    % Try to spot single-letter tokens adjacent to idxTok with separators
    pat = "(?<=\b" + lower(idxTok) + "[_\-\.])([a-z])(?=[_\-\.]|\.mat$)";
    letters = unique(regexprep(regexp(namesForIndex, pat, 'match', 'once'), '^$',''));
    letters = letters(~strcmp(letters,""));
end
