function G = acousticFingerprintGraph(EL, f0, t0, prm)
% Always call the heavy, joint-metric kNN builder.
G = acousticFingerprintkNN(EL, f0, t0, prm);
end
