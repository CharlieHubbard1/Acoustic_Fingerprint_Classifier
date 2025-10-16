function x = featurize_one_sample(runFile, prm)
% runFile: full path to "... w metadata.mat" (or raw .mat if you allow)
% prm: required

G = prmapi.graph(prm);
% load run
S = load(runFile);
if isfield(S,'st')
    EL = S.st.EL; f0 = S.st.f0; t0 = S.st.t0;
else
    % legacy raw
    run = S.run; EL = run.spect; f0 = run.fr; t0 = run.Theta;
end

% build graph & features (your existing functions should be updated to accept prm/G)
[W,L,X_features] = acousticFingerprintGraph(EL, f0, t0, G);  %#ok<ASGLU>
x = build_feature_vector(EL, f0, t0, L, X_features, prm);    % pass prm for any knobs
end
