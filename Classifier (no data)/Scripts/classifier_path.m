function p = classifier_path(cmd, val)
% CLASSIFIER_PATH  Get or set the absolute path to the project root.
% Usage:
%   root = classifier_path();                 % get (auto-detect or cached)
%   classifier_path('set', 'C:\...\Project'); % set/override
%   classifier_path('clear');                 % clear cache/pref
%
% Place this file in the PROJECT ROOT. If you keep it elsewhere, call
% classifier_path('set', '<absolute\project\root>') once.

persistent cached_path
pref_group = 'AcousticClassifier';
pref_name  = 'class_path';

% --- GET ---
if nargin == 0
    % 1) in-memory cache
    if ~isempty(cached_path) && isfolder(cached_path)
        p = cached_path;
        return;
    end
    % 2) MATLAB preferences
    if ispref(pref_group, pref_name)
        p = getpref(pref_group, pref_name);
        if isfolder(p)
            cached_path = p;
            return;
        end
    end
    % 3) derive from this file's location
    fp = mfilename('fullpath');
    if isempty(fp)
        fp = which('classifier_path'); % fallback
    end
    p = fileparts(fp);
    cached_path = p;
    setpref(pref_group, pref_name, p);
    return;
end

% --- SET / CLEAR ---
cmd = lower(char(cmd));
switch cmd
    case 'set'
        if nargin < 2
            error('classifier_path:set:MissingPath', ...
                  'Provide a folder path, e.g., classifier_path(''set'',''C:\root'').');
        end
        p = char(val);
        if ~isfolder(p)
            error('classifier_path:set:NotAFolder','Not a folder: %s', p);
        end
        cached_path = p;
        setpref(pref_group, pref_name, p);

    case 'clear'
        cached_path = [];
        if ispref(pref_group, pref_name)
            rmpref(pref_group, pref_name);
        end
        p = '';

    otherwise
        error('classifier_path:BadCmd','Unknown command: %s (use ""set"" or ""clear"")', cmd);
end
end
