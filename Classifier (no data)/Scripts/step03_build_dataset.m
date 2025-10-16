% Scripts/step03_build_dataset.m
% Build per-file k-NN graphs + spectral features, assemble dataset,
% and save as dataset_<index>_<index2>.mat.
% Now with a Step-level elapsed/ETC reporter (>=1s rate limit).

%% ---------- USER INPUT ----------
selectedFiles  = {};     % e.g., {'solid cone run 1','hollow cone run 2'}; empty => all
index          = '';     % e.g., '007' | '' => latest saved params index
selectionIndex = '';     % e.g., 'A'   | '' => auto-assign next unused letter

% --- Progress estimator knob (seconds per "w metadata" file)
%     Adjust this to match your typical per-file heavy kNN time.
estSecondsPerFile = 120;  % default guess: 2 minutes/file

%% ---------- DO NOT EDIT BELOW ----------
P = cls_paths();

% Resolve params index
if isempty(index)
    index = default_params_index();
    fprintf('[step03_build_dataset] Defaulted to latest params index = %s\n', index);
else
    index = pad_index(index);
end

% Resolve selectionIndex (dataset letter)
if isempty(selectionIndex)
    selectionIndex = next_unused_letter_for_index(index);
    fprintf('[step03_build_dataset] Auto-assigned selectionIndex = %s\n', selectionIndex);
end

% --- Count how many files will be processed (for ETC baseline)
metaRoot = P.meta;
N = count_meta_files(metaRoot, selectedFiles);
if N == 0
    error('[step03_build_dataset] No "w metadata" files found for this selection.');
end
fprintf('[step03_build_dataset] Selection size: %d files\n', N);

% ---- Step-level progress reporter (elapsed + ETC), >=1s rate limit
t0 = tic;
lastPrint = -inf;
lastETC = inf;

% Use a MATLAB timer to poll once/second while the build runs
tmr = timer('ExecutionMode','fixedSpacing', 'Period',1, ...
    'TimerFcn', @(~,~) maybe_print_step_progress(), ...
    'ErrorFcn', @(~,e) fprintf('[step03 ETA timer] %s\n', e.message));
c = onCleanup(@() safe_stop_delete_timer(tmr));

start(tmr);
fprintf('[step03] Started at %s\n', datestr(now, 'HH:MM:SS'));

try
    if isempty(selectedFiles)
        ds = build_dataset('index', index, 'index2', selectionIndex);
    else
        ds = build_dataset('index', index, 'index2', selectionIndex, 'files', selectedFiles);
    end
    disp(ds);
catch ME
    safe_stop_delete_timer(tmr);
    rethrow(ME);
end

safe_stop_delete_timer(tmr);
fprintf('[step03] Finished. Total elapsed: %.1f s\n', toc(t0));

%% ===========================================================
%                 Local helper functions
%% ===========================================================

function maybe_print_step_progress()
    % Access outer-scope variables using nested function closure
    persistent lastLocalETC
    if isempty(lastLocalETC), lastLocalETC = inf; end
    elapsed = toc(evalin('base','t0'));
    N = evalin('base','N');
    estSecondsPerFile = evalin('base','estSecondsPerFile');
    totalEst = N * estSecondsPerFile;
    etc = max(0, totalEst - elapsed);
    lastPrint = evalin('base','lastPrint');
    if (elapsed - lastPrint) >= 1 && abs(etc - lastLocalETC) >= 0.5
        fprintf('[step03 ETA] Elapsed: %.1f s | ETC: %.1f s\n', elapsed, etc);
        assignin('base','lastPrint',elapsed);
        lastLocalETC = etc;
    end
end

function s = pad_index(s)
    s = string(s); if strlength(s) < 3, s = pad(s,3,'left','0'); end; s = char(s);
end

function idx = default_params_index()
    Pp = cls_paths();
    dd = dir(fullfile(Pp.datasets,'Params','params_???.mat'));
    if isempty(dd), error('No saved params found. Run step01_define_params first.'); end
    [~,I] = max([dd.datenum]);
    nm = dd(I).name; tok = regexp(nm,'params_(\d{3})\.mat','tokens','once');
    idx = tok{1};
end

function letter = next_unused_letter_for_index(index)
    Pp = cls_paths(); used = false(1,26);
    dd = dir(fullfile(Pp.datasets, "dataset_" + string(index) + "_*.mat"));
    for k=1:numel(dd)
        nm = dd(k).name; tok = regexp(nm,'dataset_\d{3}_([A-Za-z])\.mat','tokens','once');
        if ~isempty(tok)
            c = upper(tok{1}) - 'A' + 1; if c>=1 && c<=26, used(c)=true; end
        end
    end
    i = find(~used,1,'first');
    if isempty(i), error('All letters A..Z used for index %s', index); end
    letter = char('A'+i-1);
end

function n = count_meta_files(root, names)
    if nargin<2 || isempty(names)
        dd = dir(fullfile(root, '**', '* w metadata.mat'));
        n = numel(dd);
    else
        if isstring(names)||ischar(names), names = cellstr(names); end
        n = 0;
        for j = 1:numel(names)
            nm = string(names{j});
            if endsWith(nm," w metadata.mat") || isfile(nm)
                if isfile(nm), n = n+1; continue; end
            end
            dd = dir(fullfile(root, '**', nm + " w metadata.mat"));
            n = n + numel(dd);
        end
    end
end

function safe_stop_delete_timer(t)
    if isempty(t) || ~isvalid(t), return; end
    try
        if strcmp(get(t,'Running'),'on'), stop(t); end
    catch, end
    try, delete(t); catch, end
end
