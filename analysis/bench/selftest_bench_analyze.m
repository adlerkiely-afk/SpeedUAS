function selftest_bench_analyze()
%SELFTEST_BENCH_ANALYZE  Check bench_analyze against synthetic logs with known answers.
%
%   Builds a fake Nano log and a fake blackbox CSV for the TP-02 staircase, with a known
%   thrust coefficient, a 3.2 s clock offset and a 0.3 % clock-rate difference, then checks
%   that bench_analyze recovers thrust, current, rpm and CT at every hold.
%
%   This tests the maths and the sync. It does NOT prove the column names match a real
%   blackbox export: that needs one real log.

rng(1);
dirOut = tempname;
mkdir(dirOut);
nanoFile = fullfile(dirOut, "synthetic_A1_nano.csv");
bbFile = fullfile(dirOut, "synthetic_A1_bb.csv");

% ---- truth ----------------------------------------------------------------------------------
CT = 0.110; rho = 1.180; D = 0.127; G0 = 9.80665;
tempC = 20; pressure = rho * 287.05 * (tempC + 273.15);
steps = [1125 1250 1375 1500 1625 1750 1875 2000];
offset = 3.2;            % blackbox time = ratio * nano time + offset
ratio = 1.003;

fs = 2000;
seg = [1000 3; 1250 1; 1000 2; steps' 4 * ones(8, 1); 1000 3];
cmd = [];
for i = 1:size(seg, 1)
    cmd = [cmd; seg(i, 1) * ones(round(seg(i, 2) * fs), 1)]; %#ok<AGROW>
end
t = (0:numel(cmd) - 1)' / fs;
frac = (cmd - 1000) / 1000;
alpha = 1 - exp(-1 / (0.05 * fs));                       % 50 ms rotor lag
rpm = filter(alpha, [1 alpha - 1], 30000 * frac.^0.9);
n = rpm / 60;
thrustN = CT * rho * n.^2 * D^4;
amps = 0.30 + 55 * frac.^3;
volts = 25.0 - 0.03 * amps;
gyro = 5 * sin(2 * pi * cumsum(n) / fs) + 0.5 * randn(numel(t), 1);
temp = 30 + cumsum(amps) / fs * 0.05;

% ---- fake blackbox CSV ----------------------------------------------------------------------
M = [(0:numel(t) - 1)', round(t * 1e6) + 5e6, cmd, 1000 * ones(numel(t), 3), ...
    volts + 0.01 * randn(size(t)), amps + 0.05 * randn(size(t)), ...
    gyro, 0.3 * randn(numel(t), 2), rpm * 7 / 100, zeros(numel(t), 3), temp];
hdr = "loopIteration, time (us), motor[0], motor[1], motor[2], motor[3], vbatLatest (V), " + ...
    "amperageLatest (A), gyroADC[0], gyroADC[1], gyroADC[2], eRPM[0], eRPM[1], eRPM[2], eRPM[3], debug[0]";
fid = fopen(bbFile, "w"); fprintf(fid, "%s\n", hdr); fclose(fid);
writematrix(M, bbFile, "WriteMode", "append");

% ---- fake Nano log --------------------------------------------------------------------------
tNano = (0:1 / 80:(t(end) - offset) / ratio)' + 12.0;    % Nano clock starts at an arbitrary 12 s
tOnBb = ratio * (tNano - 12.0) + offset;
grams = interp1(t, thrustN, tOnBb) / G0 * 1000 + 0.5 * randn(size(tNano));
fid = fopen(nanoFile, "w");
fprintf(fid, "# SpeedUAS thrust stand logger\n# tare raw 84000\nt_s,raw,grams,mark\n");
fprintf(fid, "%.4f,%d,%.2f,0\n", [tNano, round(84000 + grams * 420), grams]');
fclose(fid);

% ---- run and check --------------------------------------------------------------------------
R = bench_analyze(nanoFile, bbFile, TempC=tempC, PressurePa=pressure, DebugTempChannel=0, Plot=true);
H = R.holds;

nTrue = 30000 * ((steps' - 1000) / 1000).^0.9 / 60;
gTrue = CT * rho * nTrue.^2 * D^4 / G0 * 1000;
iTrue = 55 * ((steps' - 1000) / 1000).^3;

assert(height(H) == 8, "expected 8 holds, got %d", height(H));
assert(all(H.Cmd == steps'), "hold commands wrong");
assert(max(abs(H.Thrust_g - gTrue) ./ gTrue) < 0.01, "thrust off by more than 1 %%");
assert(max(abs(H.RPM / 60 - nTrue) ./ nTrue) < 0.005, "rpm off by more than 0.5 %%");
assert(max(abs(H.CT - CT)) / CT < 0.01, "CT off by more than 1 %%");
assert(max(abs(H.Current_A - iTrue)) < 0.1, "current off by more than 0.1 A");
assert(abs(R.sync.clockRatio - ratio) < 2e-4, "clock ratio not recovered");
assert(R.sync.residualRms < 0.02, "sync residual above 20 ms");
assert(all(abs(H.GyroAtRotor_dps(nTrue < 950) - 5) < 1), "gyro amplitude at rotor frequency wrong");
assert(all(diff(H.EscTempEnd_C) > 0), "ESC temperature should rise through the run");
assert(isfile(fullfile(dirOut, "synthetic_A1_nano_results.csv")), "results CSV not written");

fprintf("\nSELFTEST PASSED. Outputs in %s\n", dirOut);
end
