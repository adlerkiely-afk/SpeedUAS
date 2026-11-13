function results = bench_analyze(nanoFile, bbFile, opts)
%BENCH_ANALYZE  Merge a thrust stand log with a Betaflight blackbox log (TP-02).
%
%   R = bench_analyze(nanoFile, bbFile, TempC=21, PressurePa=98200)
%
%   nanoFile  CSV saved by log_thrust (t_s,raw,grams,mark; '#' lines ignored).
%   bbFile    the blackbox log converted to CSV (blackbox_decode, or CSV export from
%             the Betaflight Blackbox Explorer).
%
%   The two logs have separate clocks. They are lined up on the throttle-step edges:
%   a coarse offset from cross-correlation, then a straight-line fit through the matched
%   edges, which also removes the small rate difference between the two clocks.
%
%   Each throttle hold is averaged after discarding SkipStart seconds at its start and
%   SkipEnd seconds at its end. R.holds has one row per hold. The same table is written
%   next to the Nano file as <name>_results.csv, with three PNG figures.
%
%   Options (name=value):
%     TempC, PressurePa   air temperature and pressure, for density and CT
%     Motor               bench motor, 0-based as in the log (default: the one that moved most)
%     PropDiameter        m (default 0.127)
%     PolePairs           motor poles / 2 (default 7)
%     ErpmScale           logged eRPM value x this = electrical rpm (default 100)
%     DebugTempChannel    0-based debug[] channel holding ESC temperature (default: none)
%     SkipStart, SkipEnd  s discarded from each hold (defaults 1.5, 0.25)
%     MinHold             shortest plateau counted as a hold, s (default 2)
%     OutDir              where results go (default: folder of nanoFile)
%     Plot                true/false (default true)
%
%   No toolboxes needed.

arguments
    nanoFile (1,1) string
    bbFile (1,1) string
    opts.TempC (1,1) double = NaN
    opts.PressurePa (1,1) double = NaN
    opts.Motor double = []
    opts.PropDiameter (1,1) double = 0.127
    opts.PolePairs (1,1) double = 7
    opts.ErpmScale (1,1) double = 100
    opts.DebugTempChannel double = []
    opts.SkipStart (1,1) double = 1.5
    opts.SkipEnd (1,1) double = 0.25
    opts.MinHold (1,1) double = 2.0
    opts.OutDir (1,1) string = ""
    opts.Plot (1,1) logical = true
end

G0 = 9.80665;

% ---- read both logs -------------------------------------------------------------------------
nano = readNano(nanoFile);
bb = readBlackbox(bbFile);

calibrated = ~all(isnan(nano.g));
if calibrated
    y = nano.g;
else
    warning("bench_analyze:uncal", "Nano log has no calibrated grams. Using raw counts for sync only; thrust is NaN.");
    y = nano.raw;
end

% ---- bench motor and its throttle holds -----------------------------------------------------
if isempty(opts.Motor)
    [~, m] = max(max(bb.motor, [], 1) - min(bb.motor, [], 1));
else
    m = opts.Motor + 1;
end
cmd = bb.motor(:, m);
fs = 1 / median(diff(bb.t));
[holds, edges, idleLevel, cmdRange] = findHolds(bb.t, cmd, fs, opts.MinHold);
if isempty(holds)
    error("bench_analyze:noholds", "No throttle holds of %.1f s or longer found on motor[%d].", opts.MinHold, m - 1);
end

% ---- line up the clocks ---------------------------------------------------------------------
[p, syncInfo] = syncClocks(bb.t, cmd, idleLevel, cmdRange, nano.t, y, edges);
tn = polyval(p, nano.t);            % Nano samples on the blackbox clock

% ---- air density ----------------------------------------------------------------------------
rho = opts.PressurePa / (287.05 * (opts.TempC + 273.15));
if isnan(rho)
    warning("bench_analyze:norho", "TempC and PressurePa not given: CT is NaN.");
end

% ---- idle window (before the first edge) ----------------------------------------------------
idleWin = bb.t < edges(1) - 0.3;
if nnz(idleWin) / fs < 0.5
    warning("bench_analyze:noidle", "Less than 0.5 s of log before the first throttle edge: idle current and resting voltage are NaN.");
    idleI = NaN; restV = NaN; temp0 = NaN;
else
    idleI = mean(bb.amps(idleWin), "omitnan");
    restV = mean(bb.volts(idleWin), "omitnan");
    temp0 = meanDebug(bb, opts.DebugTempChannel, idleWin);
end
zeroStart = mean(y(tn < edges(1) - 0.3), "omitnan");
zeroEnd = mean(y(tn > edges(end) + 1.0), "omitnan");

% ---- per-hold averages ----------------------------------------------------------------------
nH = size(holds, 1);
names = ["Hold" "Cmd" "Window_s" "Thrust_g" "ThrustStd_g" "Thrust_N" "Current_A" "Voltage_V" ...
    "Power_W" "g_per_W" "RPM" "n_rev_s" "CT" "Sag_V" "EscTempEnd_C" "EscTempRise_C" ...
    "GyroAtRotor_dps" "GyroRMS_dps" "NanoSamples"];
R = array2table(NaN(nH, numel(names)), "VariableNames", names);
spectra = cell(nH, 1);

for k = 1:nH
    t0 = holds(k, 1) + opts.SkipStart;
    t1 = holds(k, 2) - opts.SkipEnd;
    wb = bb.t >= t0 & bb.t <= t1;
    wn = tn >= t0 & tn <= t1;

    R.Hold(k) = k;
    R.Cmd(k) = median(cmd(wb));
    R.Window_s(k) = t1 - t0;
    R.NanoSamples(k) = nnz(wn);
    if calibrated
        R.Thrust_g(k) = mean(y(wn));
        R.ThrustStd_g(k) = std(y(wn));
        R.Thrust_N(k) = R.Thrust_g(k) * G0 / 1000;
    end
    R.Current_A(k) = mean(bb.amps(wb), "omitnan") - idleI;
    R.Voltage_V(k) = mean(bb.volts(wb), "omitnan");
    R.Power_W(k) = R.Voltage_V(k) * R.Current_A(k);
    R.g_per_W(k) = R.Thrust_g(k) / R.Power_W(k);
    R.Sag_V(k) = restV - R.Voltage_V(k);

    if ~isempty(bb.erpm)
        R.RPM(k) = mean(bb.erpm(wb, m), "omitnan") * opts.ErpmScale / opts.PolePairs;
        R.n_rev_s(k) = R.RPM(k) / 60;
        R.CT(k) = R.Thrust_N(k) / (rho * R.n_rev_s(k)^2 * opts.PropDiameter^4);
    end

    tail = bb.t >= holds(k, 2) - opts.SkipEnd - 0.5 & bb.t <= t1;
    R.EscTempEnd_C(k) = meanDebug(bb, opts.DebugTempChannel, tail);
    R.EscTempRise_C(k) = R.EscTempEnd_C(k) - temp0;

    if ~isempty(bb.gyro) && nnz(wb) > 64
        [f, A, aRotor, gRms] = gyroSpectrum(bb.gyro(wb, :), fs, R.n_rev_s(k));
        R.GyroAtRotor_dps(k) = aRotor;
        R.GyroRMS_dps(k) = gRms;
        spectra{k} = [f A];
    end
end

% ---- report ---------------------------------------------------------------------------------
results.holds = R;
results.motor = m - 1;
results.rho = rho;
results.idleCurrent_A = idleI;
results.restingVoltage_V = restV;
results.thrustZeroStart = zeroStart;
results.thrustZeroEnd = zeroEnd;
results.sync = syncInfo;
results.calibrated = calibrated;

fprintf("\nBench motor: motor[%d]   holds found: %d\n", m - 1, nH);
fprintf("Sync: %d edges matched, clock ratio %.5f, offset %.3f s, residual %.1f ms rms\n", ...
    syncInfo.nEdges, p(1), p(2), 1000 * syncInfo.residualRms);
fprintf("Idle current %.2f A   resting voltage %.2f V   air density %.3f kg/m^3\n", idleI, restV, rho);
fprintf("Thrust zero: %.1f before, %.1f after the run\n\n", zeroStart, zeroEnd);
disp(R(:, ["Hold" "Cmd" "Thrust_g" "Current_A" "Voltage_V" "Power_W" "g_per_W" "RPM" "CT"]));

outDir = opts.OutDir;
[nanoDir, base] = fileparts(nanoFile);
if outDir == ""
    outDir = nanoDir;
    if outDir == "", outDir = "."; end
end
writetable(R, fullfile(outDir, base + "_results.csv"));

if opts.Plot
    makePlots(bb, cmd, tn, y, edges, holds, R, spectra, calibrated, outDir, base);
end
end

% =============================================================================================
function nano = readNano(file)
L = strtrim(readlines(file));
keep = ~startsWith(L, "#") & ~startsWith(L, "t_s") & count(L, ",") == 3;
parts = split(L(keep), ",", 2);
v = str2double(parts);
ok = ~isnan(v(:, 1)) & ~isnan(v(:, 2));
v = v(ok, :);
mono = [true; diff(v(:, 1)) > 0];           % drop any out-of-order line
v = v(mono, :);
if size(v, 1) < 10
    error("bench_analyze:nano", "Fewer than 10 data lines in %s", file);
end
nano.t = v(:, 1);
nano.raw = v(:, 2);
nano.g = v(:, 3);
nano.mark = v(:, 4);
end

% =============================================================================================
function bb = readBlackbox(file)
T = readtable(file, "VariableNamingRule", "preserve");
names = strtrim(string(T.Properties.VariableNames));

tCol = pick(names, "time");
t = T{:, tCol};
t = (t - t(1)) / 1e6;                       % blackbox time is in microseconds
good = [true; diff(t) > 0];
T = T(good, :);
bb.t = t(good);

mc = find(startsWith(lower(names), "motor["));
if isempty(mc)
    error("bench_analyze:bb", "No motor[...] columns in %s", file);
end
bb.motor = T{:, mc};

% Voltage and current: use the unit in the column name if there is one, otherwise assume the
% raw blackbox units of 0.01 V and 0.01 A.
vCol = pick(names, "vbatlatest");
bb.volts = T{:, vCol};
if ~contains(names(vCol), "(V)")
    bb.volts = bb.volts / 100;
end
aCol = pick(names, "amperagelatest");
bb.amps = T{:, aCol};
if ~contains(names(aCol), "(A)")
    bb.amps = bb.amps / 100;
end

ec = find(startsWith(lower(names), "erpm["));
if isempty(ec)
    warning("bench_analyze:noerpm", "No eRPM columns in the blackbox log: RPM and CT are NaN.");
    bb.erpm = [];
else
    bb.erpm = T{:, ec};
end

gc = find(startsWith(lower(names), "gyroadc["));
if isempty(gc)
    bb.gyro = [];
else
    bb.gyro = T{:, gc};
end

dc = find(startsWith(lower(names), "debug["));
bb.debug = T{:, dc};
end

function i = pick(names, prefix)
i = find(startsWith(lower(names), prefix), 1);
if isempty(i)
    error("bench_analyze:bb", "No column starting with '%s' in the blackbox CSV.", prefix);
end
end

function v = meanDebug(bb, ch, win)
if isempty(ch) || size(bb.debug, 2) < ch + 1
    v = NaN;
else
    v = mean(bb.debug(win, ch + 1), "omitnan");
end
end

% =============================================================================================
function [holds, edges, idleLevel, cmdRange] = findHolds(t, cmd, fs, minHold)
% A hold is a stretch where the motor command is steady, above idle, for minHold or longer.
cmdRange = max(cmd) - min(cmd);
if cmdRange <= 0
    error("bench_analyze:flat", "The motor command never changes in this log.");
end
w = max(1, round(0.05 * fs));
d = [abs(cmd(1 + w:end) - cmd(1:end - w)); zeros(w, 1)];
moving = movmax(double(d > 0.02 * cmdRange), [w w]) > 0;
stable = ~moving;

ds = diff([0; stable; 0]);
s0 = find(ds == 1);
s1 = find(ds == -1) - 1;
level = arrayfun(@(a, b) median(cmd(a:b)), s0, s1);
idleLevel = min(level);

isHold = level > idleLevel + 0.03 * cmdRange & (t(s1) - t(s0)) >= minHold;
holds = [t(s0(isHold)) t(s1(isHold))];

edges = zeros(0, 1);
for i = 1:numel(s0) - 1
    if abs(level(i + 1) - level(i)) > 0.02 * cmdRange
        edges(end + 1, 1) = (t(s1(i)) + t(s0(i + 1))) / 2; %#ok<AGROW>
    end
end
if isempty(edges)
    error("bench_analyze:noedges", "No throttle steps found in the blackbox log.");
end
end

% =============================================================================================
function [p, info] = syncClocks(tb, cmd, idleLevel, cmdRange, tnRaw, y, edges)
% Returns p so that blackbox time = p(1) * nano time + p(2).

% Coarse offset: cross-correlate thrust with (throttle)^2 on a common 50 Hz grid.
dt = 0.02;
gb = (tb(1):dt:tb(end))';
a = interp1(tb, cmd, gb);
a = ((a - idleLevel) / cmdRange).^2;
a = a - mean(a);

gn = (tnRaw(1):dt:tnRaw(end))';
b = interp1(tnRaw, y, gn);
b = b - median(b);
if abs(min(b)) > abs(max(b))                % thrust reads negative: flip for matching only
    b = -b;
    y = -y;
end
b = b / max(abs(b));
b = b - mean(b);

N = 2^nextpow2(numel(a) + numel(b));
r = real(ifft(fft(a, N) .* conj(fft(b, N))));
[~, i] = max(r);
lag = i - 1;
if lag > N / 2
    lag = lag - N;
end
off = gb(1) - gn(1) + lag * dt;

% Fine: find where thrust crosses halfway at each throttle edge, then fit a line.
yRange = max(y) - min(y);
tnE = zeros(0, 1);
tbE = zeros(0, 1);
for k = 1:numel(edges)
    c = edges(k) - off;
    pre = mean(y(tnRaw > c - 0.6 & tnRaw < c - 0.2));
    post = mean(y(tnRaw > c + 0.3 & tnRaw < c + 0.7));
    if isnan(pre) || isnan(post) || abs(post - pre) < 0.03 * yRange
        continue
    end
    idx = find(tnRaw > c - 0.2 & tnRaw < c + 0.3);
    z = (y(idx) - (pre + post) / 2) * sign(post - pre);
    j = find(z(1:end - 1) < 0 & z(2:end) >= 0, 1);
    if isempty(j)
        continue
    end
    frac = -z(j) / (z(j + 1) - z(j));
    tnE(end + 1, 1) = tnRaw(idx(j)) + frac * (tnRaw(idx(j + 1)) - tnRaw(idx(j))); %#ok<AGROW>
    tbE(end + 1, 1) = edges(k); %#ok<AGROW>
end

if numel(tnE) >= 3 && (max(tnE) - min(tnE)) > 5
    p = polyfit(tnE, tbE, 1);
elseif ~isempty(tnE)
    p = [1, mean(tbE - tnE)];
else
    warning("bench_analyze:sync", "No thrust edges matched. Using the cross-correlation offset only.");
    p = [1, off];
end
info.nEdges = numel(tnE);
info.clockRatio = p(1);
info.offset_s = p(2);
if isempty(tnE)
    info.residualRms = NaN;
else
    info.residualRms = sqrt(mean((tbE - polyval(p, tnE)).^2));
end
end

% =============================================================================================
function [f, A, aRotor, gRms] = gyroSpectrum(g, fs, n)
% Single-sided amplitude spectrum of the gyro (all axes combined), Hann window.
g = g - mean(g, 1);
N = size(g, 1);
w = 0.5 - 0.5 * cos(2 * pi * (0:N - 1)' / N);
S = abs(fft(g .* w)) / (sum(w) / 2);
half = 1:floor(N / 2);
f = (half' - 1) * fs / N;
A = sqrt(sum(S(half, :).^2, 2));
gRms = sqrt(mean(sum(g.^2, 2)));
if isnan(n) || n <= 0 || n * 1.05 >= fs / 2
    aRotor = NaN;                           % rotor frequency is above what this log rate can show
else
    band = f >= 0.95 * n & f <= 1.05 * n;
    aRotor = max(A(band));
end
end

% =============================================================================================
function makePlots(bb, cmd, tn, y, edges, holds, R, spectra, calibrated, outDir, base)
vis = "on";
if batchStartupOptionUsed
    vis = "off";
end

fig = figure("Visible", vis, "Position", [100 100 1000 450]);
yyaxis left
plot(tn, y);
if calibrated, ylabel("thrust (g)"); else, ylabel("load cell (raw counts)"); end
yyaxis right
plot(bb.t, cmd);
ylabel("motor command");
xline(edges, ":");
for k = 1:size(holds, 1)
    xline(holds(k, 1) + 1.5, "g-");
end
xlabel("time on the blackbox clock (s)");
title("Thrust and motor command after sync");
grid on
exportgraphics(fig, fullfile(outDir, base + "_sync.png"), "Resolution", 150);

fig = figure("Visible", vis, "Position", [100 100 1000 450]);
tiledlayout(1, 2);
nexttile
plot(R.RPM, R.Thrust_g, "o-");
xlabel("rpm"); ylabel("thrust (g)"); grid on
title("Static thrust");
nexttile
plot(R.Thrust_g, R.g_per_W, "o-");
xlabel("thrust (g)"); ylabel("g/W (electrical)"); grid on
title("Efficiency");
exportgraphics(fig, fullfile(outDir, base + "_thrust.png"), "Resolution", 150);

fig = figure("Visible", vis, "Position", [100 100 1000 450]);
hold on
lbl = strings(0, 1);
for k = 1:numel(spectra)
    if ~isempty(spectra{k})
        plot(spectra{k}(:, 1), spectra{k}(:, 2));
        lbl(end + 1) = sprintf("hold %d, cmd %.0f", k, R.Cmd(k)); %#ok<AGROW>
    end
end
set(gca, "YScale", "log");
xlabel("frequency (Hz)"); ylabel("gyro amplitude (deg/s)"); grid on
title("Gyro spectrum per hold");
if ~isempty(lbl), legend(lbl, "Location", "northeast"); end
exportgraphics(fig, fullfile(outDir, base + "_vibration.png"), "Resolution", 150);

if vis == "off"
    close all
end
end
