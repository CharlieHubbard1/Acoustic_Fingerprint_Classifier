function results = classify_one_object(varargin)
% Adds elapsed/ETA printing for multiple files.
P = cls_paths();

p = inputParser;
addParameter(p,'modelIndex','',@(s)ischar(s)||isstring(s));
addParameter(p,'modelIndex2','',@(s)ischar(s)||isstring(s));
addParameter(p,'files',{},@(c)iscell(c) || ischar(c) || isstring(c));
parse(p,varargin{:});
modelIndex  = string(p.Results.modelIndex);
modelIndex2 = string(p.Results.modelIndex2);
filesIn     = p.Results.files;

if strlength(modelIndex)==0 || strlength(modelIndex2)==0
    error('Please specify both ''modelIndex'' and ''modelIndex2''.');
end
if ischar(filesIn) || isstring(filesIn), filesIn = cellstr(filesIn); end
if isempty(filesIn), error('Provide at least one file via ''files''.'); end

modelPath = find_model_file(P, modelIndex, modelIndex2);
if isempty(modelPath), error('Model not found for %s_%s', modelIndex, modelIndex2); end
M = load(modelPath);

fileList = resolve_input_files(P, filesIn);
if isempty(fileList), error('No input files found.'); end

predDir = ensure_predictions_folder(P, modelIndex);

N = numel(fileList);
H = progress_eta(N, 'Classify');
results = struct('inputFile',{},'label',{},'score',{},'modelFile',{},'savedTo',{});
for i = 1:N
    inFile = fileList{i};
    st = load_fingerprint(inFile);
    x  = extract_features(st);
    [label, score] = predict_with_model(M, x);
    savedPath = save_prediction(P, predDir, modelIndex, modelIndex2, inFile, label, score, modelPath);
    results(i) = struct('inputFile',inFile,'label',label,'score',score,'modelFile',modelPath,'savedTo',savedPath);
    H.update(i);
end
H.done();
end

% (helper functions unchanged from your current version)
