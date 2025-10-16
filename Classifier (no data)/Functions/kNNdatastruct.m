% Functions/kNNdatastruct.m
% Usage:
%   kNNdatastruct();                         % sync all new Echo Data files -> Metadata
%   kNNdatastruct('clear', {'hollow cone run 2', 'solid cone run 1'});
%
% Notes:
% - Expects each Echo Data .mat to contain a struct 'run' with fields:
%   run.spect, run.fr, run.Theta  (rename here if yours differ)

function kNNdatastruct(varargin)
    P = cls_paths();
    args = struct('mode','sync','clearList',{{}});
    if ~isempty(varargin)
        for k = 1:2:numel(varargin)
            switch lower(varargin{k})
                case 'clear'
                    args.mode = 'clear';
                    args.clearList = varargin{k+1};
                otherwise
                    error('Unknown option: %s', varargin{k});
            end
        end
    end

    switch args.mode
        case 'sync'
            sync_all(P);
        case 'clear'
            clear_selected(P, args.clearList);
    end
end

function sync_all(P)
    echoFolders = list_subfolders(P.echo);
    for f = 1:numel(echoFolders)
        ef = echoFolders{f};
        srcDir = fullfile(P.echo, ef);
        dstDir = fullfile(P.meta, ef);
        if ~exist(dstDir,'dir'), mkdir(dstDir); end  % ensure mirror subfolder exists

        mats = dir(fullfile(srcDir, '*.mat'));
        for i = 1:numel(mats)
            srcFile = fullfile(srcDir, mats(i).name);
            [~, base, ~] = fileparts(mats(i).name);
            dstFile = fullfile(dstDir, sprintf('%s w metadata.mat', base));

            if ~exist(dstFile,'file')
                st = build_struct_from_echo(srcFile);
                save(dstFile, 'st');
                fprintf('[kNNdatastruct] Created: %s\n', relativize(dstFile, P.root));
            end
        end
    end
end

function clear_selected(P, names)
    if isempty(names)
        warning('[kNNdatastruct] Clear requested but no file names provided. Nothing to do.');
        return;
    end
    metaFolders = list_subfolders(P.meta);
    % Build a lookup set of desired basenames for speed
    want = containers.Map(lower(strrep(names,'.mat','')), true(1, numel(names)));

    for f = 1:numel(metaFolders)
        md = fullfile(P.meta, metaFolders{f});
        mats = dir(fullfile(md, '* w metadata.mat'));
        for i = 1:numel(mats)
            [~, base] = fileparts(mats(i).name);           % "<file> w metadata"
            baseNoSuffix = erase(base, ' w metadata');      % "<file>"
            if isKey(want, lower(baseNoSuffix))
                srcEcho = fullfile(P.echo, metaFolders{f}, [baseNoSuffix '.mat']);
                if ~exist(srcEcho,'file')
                    warning('Echo source not found for %s; skipping clear.', baseNoSuffix);
                    continue;
                end
                dstFile = fullfile(md, [baseNoSuffix ' w metadata.mat']);
                st = build_struct_from_echo(srcEcho);       % rebuild bare struct (no extra context)
                save(dstFile, 'st');
                fprintf('[kNNdatastruct] Cleared metadata: %s\n', relativize(dstFile, P.root));
            end
        end
    end
end

function st = build_struct_from_echo(srcFile)
    S = load(srcFile);
    if isfield(S,'run')
        EL = S.run.spect; f0 = S.run.fr; t0 = S.run.Theta;
    else
        error('Source file %s does not contain struct ''run''.', srcFile);
    end
    st = struct();
    st.EL = EL; st.f0 = f0; st.t0 = t0;
    % Placeholders for context fields—intentionally minimal so "clear" strips extras.
    % Add context later via edit_context_metadata.m
end

function F = list_subfolders(root)
    d = dir(root);
    F = {d([d.isdir] & ~startsWith({d.name}, '.')).name};
end

function r = relativize(p, root)
    if startsWith(p, root), r = ['.' filesep p(numel(root)+2:end)];
    else, r = p; end
end
