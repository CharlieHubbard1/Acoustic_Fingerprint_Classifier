function G = knn_graph(X, k, metric, sigma_val)
% knn_graph  — build a kNN similarity graph over samples (rows of X)
% INPUTS
%   X          : N x D feature matrix (one row per item)
%   k          : number of neighbors (>=1, < N)
%   metric     : 'cosine' (default) or 'euclidean'
%   sigma_val  : scale for converting distances -> weights (euclidean);
%                for cosine, we weight directly by similarity in [0,1].
%
% OUTPUT
%   G          : struct with fields
%                  .idx   (N x k) neighbor indices
%                  .dist  (N x k) distances (cosine or euclidean)
%                  .W     (N x N) sparse, symmetrized weight matrix
%                  .metric, .k

if nargin < 3 || isempty(metric), metric = 'cosine'; end
if nargin < 4 || isempty(sigma_val), sigma_val = 1.0; end

[N, ~] = size(X);
if N < 2 || k < 1
    G = struct('idx',[], 'dist', [], 'W', sparse(N,N), 'metric', metric, 'k', k);
    return;
end
k = min(max(1, round(k)), max(1, N-1));

use_knnsearch = (exist('knnsearch','file')==2);

switch lower(metric)
    case 'euclidean'
        if use_knnsearch
            [idx, dist] = knnsearch(X, X, 'K', k+1, 'Distance','euclidean'); % self + k
            idx  = idx(:,2:end);
            dist = dist(:,2:end);
        else
            % Fallback via pdist2 if available; else simple brute force
            if exist('pdist2','file')==2
                D = pdist2(X,X,'euclidean');
            else
                % Brute force (may be slow for large N)
                D = zeros(N,N);
                for i=1:N
                    d = X - X(i,:);
                    D(i,:) = sqrt(sum(d.^2,2));
                end
            end
            D(1:N+1:end) = inf; % ignore self
            [dist, idx] = sort(D, 2, 'ascend');
            idx  = idx(:,1:k);
            dist = dist(:,1:k);
        end
        % Convert distance -> weight with Gaussian kernel
        sv = max(eps, sigma_val);
        Wvals = exp(-(dist.^2) ./ (2*sv^2));
    case 'cosine'
        if use_knnsearch
            [idx, dist] = knnsearch(X, X, 'K', k+1, 'Distance','cosine'); % self + k
            idx  = idx(:,2:end);
            dist = dist(:,2:end);            % cosine distance in [0,2]
            sim  = 1 - dist;                 % similarity in [-1,1]
            Wvals = max(sim, 0);             % clip negatives
        else
            % Fallback: top-k by cosine via dense sim (may be heavy for large N)
            Xn = X ./ (vecnorm(X,2,2)+1e-9);
            S  = Xn * Xn.';                  % cosine similarity in [-1,1]
            S(1:N+1:end) = -inf;             % ignore self
            [sim, idx] = sort(S, 2, 'descend');
            idx   = idx(:,1:k);
            sim   = sim(:,1:k);
            dist  = 1 - sim;                  % cosine distance
            Wvals = max(sim, 0);
        end
    otherwise
        error('Unsupported metric: %s', metric);
end

% Build sparse W, symmetrize by max to ensure undirected graph
I = repelem((1:N).', k, 1);
J = idx(:);
V = Wvals(:);
W = sparse(I, J, V, N, N);
W = max(W, W.');  %#ok<SPOROW>  % symmetrize

G = struct('idx',idx, 'dist',dist, 'W',W, 'metric', lower(metric), 'k', k);
end
