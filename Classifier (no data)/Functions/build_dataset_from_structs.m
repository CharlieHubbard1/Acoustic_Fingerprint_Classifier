function ds = build_dataset_from_structs(stList, prm)
% Outputs: X_core, X_meta, X_aug, y, files, S_cos, D_eu, graphs, params

if isstruct(stList), stList = num2cell(stList); end
N = numel(stList);

Xc = [];
y  = strings(0,1);
Gcells = cell(1,N);
names  = strings(0,1);
skipped = 0;

for i = 1:N
    st = stList{i};
    fprintf('--- Starting file %d/%d ---\n', i, N);
    if ~isstruct(st), fprintf('[build_dataset_from_structs] SKIP %d: not a struct\n', i); skipped=skipped+1; continue; end
    if ~isfield(st,'EL'), fprintf('[build_dataset_from_structs] SKIP %d: missing EL\n', i); skipped=skipped+1; continue; end
    if ~isfield(st, prm.labelField), fprintf('[build_dataset_from_structs] SKIP %d: missing labelField %s\n', i, prm.labelField); skipped=skipped+1; continue; end

    f0 = []; if isfield(st,'f0'), f0 = st.f0; end
    t0 = []; if isfield(st,'t0'), t0 = st.t0; end

    % pass file counters into the graph builder for its ticker
    prm.runtime = struct('fileIdx',i,'totalFiles',N);

    % HEAVY STEP: joint-metric kNN graph (+ 1s ticker inside)
    G  = acousticFingerprintGraph(st.EL, f0, t0, prm);
    fprintf('(%d/%d) | k-NN graph finished. Proceeding to feature vector...\n', i, N);

    % Feature vector summary message
    xi = build_feature_vector(G, st, prm);
    fprintf('(%d/%d) | Feature vector complete. Length=%d\n', i, N, numel(xi));

    Xc = [Xc; xi]; %#ok<AGROW>
    y(end+1,1) = string(st.(prm.labelField)); %#ok<AGROW>
    Gcells{i} = G;
    if isfield(st,'name'), names(end+1,1) = string(st.name); else, names(end+1,1) = ""; end %#ok<AGROW>

    fprintf('--- Finished file %d/%d ---\n', i, N);
end

if skipped>0
    fprintf('[build_dataset_from_structs] Skipped %d of %d items (see messages above).\n', skipped, N);
end

% Metadata encoding
[Xm, ~] = encode_metadata(stList, prm);
if isempty(Xm), X_aug = Xc; else, X_aug = [Xc, Xm]; end

% Pairwise sims/dist on core features
Xn = Xc ./ (vecnorm(Xc,2,2)+1e-9);
S_cos = Xn * Xn.';
if exist('pdist','file')==2 && exist('squareform','file')==2
    D_eu  = squareform(pdist(Xc, 'euclidean'));
else
    N2 = size(Xc,1); D_eu = zeros(N2,N2);
    for ii=1:N2, d = Xc - Xc(ii,:); D_eu(ii,:) = sqrt(sum(d.^2,2)); end
end

ds = struct('X_core',Xc, 'X_meta',Xm, 'X_aug',X_aug, ...
            'y',y, 'files',names, 'S_cos',S_cos, 'D_eu',D_eu, ...
            'graphs',{Gcells}, 'params',prm);
end

% --- encode_metadata helper (unchanged from your last working version) ---
function [Xm, info] = encode_metadata(stList, prm)
if isstruct(stList), stList = num2cell(stList); end
N = numel(stList);
ignore = ["EL","f0","t0", string(prm.labelField)];

vals = struct(); fields = strings(0,1);
for i=1:N
    S = stList{i};
    if ~isstruct(S), continue; end
    fn = fieldnames(S);
    for k=1:numel(fn)
        f = string(fn{k});
        if any(strcmpi(f, ignore)), continue; end
        v = S.(fn{k});
        if ischar(v) || isstring(v)
            if ~isfield(vals, char(f)), vals.(char(f)) = {}; end
            vals.(char(f)){end+1,1} = string(v);
        elseif (isnumeric(v) || islogical(v)) && isscalar(v)
            if ~isfield(vals, char(f)), vals.(char(f)) = {}; end
            vals.(char(f)){end+1,1} = double(v);
        else
            % skip non-scalar/nested
        end
        if ~any(fields==f), fields(end+1,1)=f; end %#ok<AGROW>
    end
end

Xparts = {};
info = struct(); info.columns = strings(0,1);
rowCount = N;
for k=1:numel(fields)
    f = fields(k);
    if ~isfield(vals, char(f)), continue; end
    vcol = vals.(char(f));
    if numel(vcol) < rowCount, vcol(end+1:rowCount,1) = {[]}; end
    if all(cellfun(@(z) isnumeric(z) || islogical(z) || isempty(z), vcol))
        x = nan(rowCount,1);
        for i=1:rowCount, vi = vcol{i}; if ~isempty(vi), x(i) = double(vi); end, end
        Xparts{end+1} = x; %#ok<AGROW>
        info.columns(end+1,1) = f; %#ok<AGROW>
    else
        cats = unique(string(cellfun(@(z) string(z), vcol, 'uni',0)));
        M = zeros(rowCount, numel(cats));
        for i=1:rowCount
            si = string(vcol{i});
            if strlength(si)==0, continue; end
            j = find(cats==si,1); if ~isempty(j), M(i,j)=1; end
        end
        Xparts{end+1} = M; %#ok<AGROW>
        for j=1:numel(cats), info.columns(end+1,1) = f + "=" + cats(j); end %#ok<AGROW>
    end
end

if isempty(Xparts), Xm = []; else, Xm = cat(2, Xparts{:}); end
end
