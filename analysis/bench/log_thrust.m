function log_thrust(port, outFile)
%LOG_THRUST  Save the thrust stand's serial stream to a file, with a live plot.
%
%   log_thrust("COM5", "test/data/2026-11-20_bareprop_A1_nano.csv")
%
%   Opens the Arduino Nano running firmware/thrust_stand at 115200 baud and writes every
%   line it sends to outFile, unchanged. Opening the port resets the Nano, which then
%   tares for about 1 s: keep the rig still until data starts.
%
%   The window has Tare, Mark and Stop buttons and a box for any other command
%   (for example "c 500", "p", "s" during a TP-03 calibration). Closing the window stops
%   the log.
%
%   Needs MATLAB R2019b or later. No toolboxes.

arguments
    port (1,1) string
    outFile (1,1) string
end

if isfile(outFile)
    error("log_thrust:exists", "%s already exists. Pick a new file name.", outFile);
end
fid = fopen(outFile, "w");
if fid < 0
    error("log_thrust:open", "Cannot create %s", outFile);
end
closeFile = onCleanup(@() fclose(fid));

s = serialport(port, 115200, "Timeout", 2);
configureTerminator(s, "LF");

fig = figure("Name", "Thrust stand: " + outFile, "NumberTitle", "off");
ax = axes(fig, "Position", [0.1 0.25 0.85 0.68]);
trace = animatedline(ax, "MaximumNumPoints", 80 * 60);
xlabel(ax, "time (s)");
ylabel(ax, "thrust (g)");
grid(ax, "on");
setappdata(fig, "stop", false);

uicontrol(fig, "Style", "pushbutton", "String", "Tare", "Units", "normalized", ...
    "Position", [0.10 0.05 0.12 0.08], "Callback", @(~, ~) writeline(s, "t"));
uicontrol(fig, "Style", "pushbutton", "String", "Mark", "Units", "normalized", ...
    "Position", [0.24 0.05 0.12 0.08], "Callback", @(~, ~) writeline(s, "m"));
cmdBox = uicontrol(fig, "Style", "edit", "Units", "normalized", ...
    "Position", [0.40 0.05 0.22 0.08], "HorizontalAlignment", "left");
uicontrol(fig, "Style", "pushbutton", "String", "Send", "Units", "normalized", ...
    "Position", [0.63 0.05 0.12 0.08], "Callback", @(~, ~) sendBox());
uicontrol(fig, "Style", "pushbutton", "String", "Stop", "Units", "normalized", ...
    "Position", [0.83 0.05 0.12 0.08], "Callback", @(~, ~) setappdata(fig, "stop", true));

nLines = 0;
fprintf("Logging %s to %s. Close the window or press Stop to finish.\n", port, outFile);

while ishandle(fig) && ~getappdata(fig, "stop")
    if s.NumBytesAvailable == 0
        pause(0.005);
        continue
    end
    txt = readline(s);
    if ismissing(txt)
        continue
    end
    txt = strtrim(txt);
    fprintf(fid, "%s\n", txt);
    nLines = nLines + 1;

    if startsWith(txt, "#")
        disp(txt);
    else
        v = sscanf(txt, "%f,%f,%f,%f");
        if numel(v) == 4 && ~isnan(v(3)) && ishandle(fig)
            addpoints(trace, v(1), v(3));
        end
    end
    if mod(nLines, 8) == 0
        drawnow limitrate
    end
end

if ishandle(fig)
    close(fig);
end
fprintf("Stopped. %d lines written to %s\n", nLines, outFile);

    function sendBox()
        c = strtrim(string(cmdBox.String));
        if strlength(c) > 0
            writeline(s, c);
            cmdBox.String = "";
        end
    end
end
