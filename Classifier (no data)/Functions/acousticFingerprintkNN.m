function G = acousticFingerprintkNN(EL, f0, t0, prm)
% acousticFingerprintkNN — ORIGINAL HEAVY MODE (always)
% Builds kNN over a JOINT metric [f/σs, a/σs, EL/σv] with an in-loop
% 1-second console ticker:
%   "(i/N) | xx% | Elapsed: T s | ETC: T s"
%
% OUTPUT G: W, L, X_features, spec.evals, node.*, params

tFile = tic;

% progress header info from caller (optional)
fileIdx   = get_runtime(prm,'fileIdx',[]);
fileTotal = get_runtime(prm,'totalFiles',[]);
if ~isempty(fileIdx) && ~isempty(fileTotal)
    lead = sprintf('(%d/%d)', fileIdx, fileTotal);
else
    lead = '(?/?)';
end

g = prm.graph;

% ---------- axes & preproc ----------
[F, A] = size(EL);
if nargin < 2 || isempty(f0), f0 = (1:F).'; end
if nargin < 3 || isempty(t0), t0 = 1:A;      end

fstep = max(1, round(get_or(g,'freq_step',1)));
astep = max(1, round(get_or(g,'angle_step',1)));
fi = 1:fstep:F; ai = 1:astep:A;

ELd = double(EL(fi, ai));
sig = get_or(g,'sigma_smoothing',0);
if sig>0 && exist('imgaussfilt','file')==2
    try, ELd = imgaussfilt(ELd, sig); catch, end
end
ELd = log1p(max(ELd,0));

f0d = f0(fi);
t0d = t0(ai);

[AA, FF] = meshgrid(t0d, f0d);
fv = FF(:); av = AA(:); ev = ELd(:);
N  = numel(ev);

sigma_s = max(eps, get_or(g,'sigma_space',0.5));
sigma_v = max(eps, get_or(g,'sigma_value',3.0));

% joint feature space (heavy mode)
Z = [fv/sigma_s, av/sigma_s, ev/sigma_v];

% ---------- full pairwise D in blocks with a 1s ticker ----------
D = zeros(N,N);
blk = max(64, min(N, 2048));  % practical block size
lastPrint = -inf;
for r1 = 1:blk:N
    r2 = min(N, r1+blk-1);
    Zr = Z(r1:r2, :);
    rr = sum(Zr.^2,2);
    cc = sum(Z.^2,2).';
    D(r1:r2, :) = sqrt(max(rr + cc - 2*(Zr*Z.'), 0));
    D(r1:r2, r1:r2) = inf;

    % % once per second: "(i/N) | 48% | Elapsed: 221.1 s | ETC: 55.2 s"
    % nowT = toc(tFile);
    % if nowT - lastPrint >= 1 || r2==N
    %     frac = r2 / N;
    %     eta  = (nowT / max(frac,1e-9)) - nowT;
    %     fprintf('\r%s | %2.0f%% | Elapsed: %.1f s | ETC: %.1f s', ...
    %             lead, 100*frac, nowT, max(0,eta));
    %     drawnow('limitrate');
    %     lastPrint = nowT;
    % end
end
fprintf('\n');  % finish the ticker line

% ---------- kNN graph from joint distances ----------
K = min(max(1, round(get_or(g,'k_neighbors',16))), max(1, N-1));
[Dsrt, Isrt] = sort(D, 2, 'ascend');
idx  = Isrt(:,1:K);
dneu = Dsrt(:,1:K);

Wvals = exp(-(dneu.^2));
I = repelem((1:N).', K, 1);
J = idx(:);
V = Wvals(:);

W = sparse(I, J, V, N, N);
W = max(W, W.');
d = sum(W,2);
L = spdiags(d,0,N,N) - W;
fprintf('%s | k-NN graph complete (N=%d, K=%d, edges≈%d)\n', lead, N, K, nnz(W));

% ---------- normalized Laplacian spectrum ----------
kfeat = max(1, round(get_or(g,'num_features',30)));
kfeat = min(kfeat, max(1, N-1));
dinv2 = spdiags(1./sqrt(max(d,eps)),0,N,N);
Lsym  = dinv2 * L * dinv2;
Lsym  = (Lsym + Lsym.')/2;  % enforce symmetry

fprintf('%s | Solving Laplacian spectrum (k=%d)...\n', lead, kfeat);
opts.tol = 1e-3; opts.maxit = 200;
[V, Dvals] = eigs(Lsym, kfeat+1, 'smallestreal', opts);
X_features = V(:,2:end);
evals = diag(Dvals); evals = evals(:).';
evals = evals(2:min(end,kfeat+1));
fprintf('%s | Laplacian spectrum complete (evecs/evals ready)\n', lead);
clear D Dsrt Isrt dneu;

% ---------- pack ----------
G = struct();
G.W         = W;
G.L         = L;
G.X_features= X_features;
G.spec      = struct('evals',evals);
G.node      = struct('f',fv,'a',av,'el',ev, ...
                     'fi',repelem((1:numel(fi)).',numel(ai)), ...
                     'ai',kron((1:numel(ai)).',ones(numel(fi),1)));
G.params    = g;

fprintf('%s | Feature graph done. Total time %.1f s\n', lead, toc(tFile));
end

% ===== helpers =====
function v = get_or(S, name, default)
if ~isstruct(S) || ~isfield(S,name), v = default; else, v = S.(name); end
end
function x = get_runtime(prm, fld, dflt)
x = dflt;
if isstruct(prm) && isfield(prm,'runtime') && isstruct(prm.runtime) && isfield(prm.runtime,fld)
    x = prm.runtime.(fld);
end
end
