function x = build_feature_vector(G, st, prm)
% build_feature_vector
% Summarize a per-fingerprint graph into a fixed-length numeric vector.
% Uses:
%   • Laplacian spectrum (smallest nonzero eigenvalues)
%   • Embedding statistics (mean/std over spectral coords)
%   • Echo-level image statistics
%
% INPUTS
%   G  : struct from acousticFingerprintGraph (W,L,X_features,spec.evals,node.*)
%   st : original struct (EL,f0,t0 + metadata) for convenience (optional)
%   prm: full parameters (uses prm.dataset.NumEigs / EmbedUsed etc.)
%
% OUTPUT
%   x  : 1 x D numeric feature vector

NumEigs  = get_or(prm.dataset,'NumEigs',30);
EmbedUse = get_or(prm.dataset,'EmbedUsed',32);

% 1) Spectrum (pad/trim to NumEigs)
evals = G.spec.evals(:).';
if isempty(evals)
    evals = nan(1, NumEigs);
end
if numel(evals) < NumEigs
    evals = [evals, nan(1, NumEigs-numel(evals))];
else
    evals = evals(1:NumEigs);
end

% 2) Embedding stats (mean & std per spectral dim; cap at EmbedUse dims)
Emb = G.X_features;                 % N x k
if isempty(Emb), Emb = zeros(size(G.W,1), min(EmbedUse, NumEigs)); end
k = min(size(Emb,2), EmbedUse);
Emb = Emb(:,1:k);
emb_mu = mean(Emb,1);
emb_sd = std(Emb,0,1);

% 3) Echo-level stats (robust)
el = G.node.el;
el_mu = mean(el);
el_sd = std(el);
el_p  = prctile(el, [5 25 50 75 95]);
el_sk = skewness(el);
el_ku = kurtosis(el);

x = [evals, emb_mu, emb_sd, el_mu, el_sd, el_p, el_sk, el_ku];
x = double(x(:)).';  % row vector
end

function v = get_or(S, name, default)
if ~isstruct(S) || ~isfield(S,name), v = default; else, v = S.(name); end
end
