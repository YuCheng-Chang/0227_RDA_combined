addpath('G:\我的雲端硬碟\Documents\110上學期\研究\MAGIC-master');
COM = "COM? ";
port = input(COM,"s");
if isempty(port)
    port = 'COM4';
end
disp(port);
magstimObject = rapid(port,'Rapid','7cef-6da58442-3e');
disp('connect');
magstimObject.connect();
pause(0.5);
disp('arm');
magstimObject.arm();
pause(0.5);

ss = "How many session you want? ";
session = input(ss);
tm = "How many times you want? ";
times = input(tm);
du = "How many duration you want?";
duration = input(du);
for j = 1:session
    ap = "What is the amplitude value? ";
    amplitude = input(ap);
    magstimObject.setAmplitudeA(amplitude);
    pause(0.5); 
    for i = 1:times
        magstimObject.fire();
        pause(duration);
    end
end

disp('disarm');
magstimObject.disarm();
pause(0.5)
disp('disconnect');
magstimObject.disconnect();