function h = progress_eta(total, label)
% progress_eta — simple elapsed/ETA printer (updates ~1 sec)
% USAGE:
%   h = progress_eta(N, 'Building dataset');
%   for i = 1:N
%       ... work ...
%       h.update(i);
%   end
%   h.done();
if nargin < 2, label = 'Progress'; end
startTime = tic;
lastPrint = -inf;
h.update = @update;
h.done   = @done;

    function update(done)
        nowT = toc(startTime);
        if nowT - lastPrint >= 1 || done == total || done == 0  % ~1s
            if done == 0
                etaStr = 'estimating...';
            else
                rate = done / nowT;                         % items/sec
                remain = max(total - done, 0);
                if rate > 0
                    eta = remain / rate;
                    etaStr = fmt(eta);
                else
                    etaStr = 'estimating...';
                end
            end
            fprintf('\r[%s] %d/%d  elapsed: %s  ETA: %s', label, done, total, fmt(nowT), etaStr);
            drawnow('limitrate');
            lastPrint = nowT;
            if done == total, fprintf('\n'); end
        end
    end

    function done()
        t = toc(startTime);
        fprintf('\r[%s] %d/%d  elapsed: %s  ETA: 0s\n', label, total, total, fmt(t));
    end

    function s = fmt(sec)
        if sec < 60, s = sprintf('%.0fs', sec); return; end
        m = floor(sec/60); sR = round(sec - 60*m);
        if m < 60, s = sprintf('%dm %02ds', m, sR); return; end
        h = floor(m/60); mR = m - 60*h;
        s = sprintf('%dh %02dm %02ds', h, mR, sR);
    end
end
