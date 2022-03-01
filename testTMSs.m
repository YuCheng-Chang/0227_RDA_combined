magstimObject=rapid('COM4','Rapid','7cef-6da58442-3e');
magstimObject.connect();
magstimObject.arm();
pause(3);
disp('pause');
magstimObject.fire()

for i = 1:10
    disp(i);
end
magstimObject.disarm();
magstimObject.disconnect();