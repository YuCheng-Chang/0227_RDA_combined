
%% ***********************************************************************   
% Main RDA Client function
function combine()
    addpath('G:\我的雲端硬碟\Documents\110上學期\研究\MAGIC-master');
    firstime = 0;
    eegsample = 1000;
    com='COM4';
    magstimObject = rapid(com,'Rapid','7cef-6da58442-3e');
    try
        magstimObject.connect();
    catch
        s=serial(com);
        fclose(s); 
        fclose(instrfind('Port',com,'Status','open'));
        delete(s);
        magstimObject.connect();
    end
    disp('connect');
    window = 1000;
    p = 13;
    edge = 37;
    forwardsample = 500;
    sample = 0;
    fs = 1000;
    
    allvec = [];

    
    
    %every time change
    recorderip = '192.168.43.5';

    % Establish connection to BrainVision Recorder Software 32Bit RDA-Port
    % (use 51234 to connect with 16Bit Port)
    con = pnet('tcpconnect', recorderip, 51244);

    % Check established connection and display a message
    stat = pnet(con,'status');
    if stat > 0
        disp('connection established');
    end

    
    % --- Main reading loop ---
    header_size = 24;
    finish = false;
    while ~finish
        try
            % check for existing data in socket buffer
            tryheader = pnet(con, 'read', header_size, 'byte', 'network', 'view', 'noblock');
            while ~isempty(tryheader)

                % Read header of RDA message
                hdr = ReadHeader(con);

                % Perform some action depending of the type of the data package
                switch hdr.type
                    case 1       % Start, Setup information like EEG properties
                        disp('Start');
                        % Read and display EEG properties
                        props = ReadStartMessage(con, hdr);
                        disp(props);

                        % Reset block counter to check overflows
                        lastBlock = -1;

                        % set data buffer to empty
                        data1s = [];
                        test = [];
                        
                    case 4       % 32Bit Data block
                        % Read data and markers from message
                        [datahdr, data, markers] = ReadDataMessage(con, hdr, props);

                        % check tcpip buffer overflow
%                         if lastBlock ~= -1 && datahdr.block > lastBlock + 1
%                             disp(['******* Overflow with ' int2str(datahdr.block - lastBlock) ' blocks ******']);
%                         end
                        lastBlock = datahdr.block;

                        % print marker info to MATLAB console
%                         if datahdr.markerCount > 0
%                             for m = 1:datahdr.markerCount
%                                 disp(markers(m));
%                             end    
%                         end

                        % Process EEG data,
                        % in this case extract last recorded second,
                        EEGData = reshape(data, props.channelCount, length(data) / props.channelCount);
                        data1s = [data1s EEGData];
                        test = [test EEGData];
                        dims = size(data1s);
                        
                        
                        if firstime == 0
%                             magstimObject = rapid('COM4','Rapid','7cef-6da58442-3e');
                            
                            magstimObject.disconnect();
                            magstimObject.connect();
                            magstimObject.arm();
                            magstimObject.setAmplitudeA(50);
                            magstimObject.pause(5);
                            firstime = 2;
                        end
                        
                        
                        
                        
                        
%                         allvec = [allvec EEGData(1,:)];
%                         sample = length(allvec);
                        sample = sample + length(EEGData(1,:));
                        
                        allvec = [allvec EEGData(1,:)];
                        h = (1/fs)*1000;     %step size in ms
                        der1 = diff(allvec)/h;        %calculates first derivative

                        %finds artifact (defined as first derivative > rate)
                        rateS =1e4; %Convert rate in to change in uV per ms
                        logstim = abs(der1)>rateS;
                        samp =(1:size(allvec,2));
                        stim = samp(logstim);

                        if ~isempty(stim)
                            stim = stim-1; %Makes start of artifact the defining point
                            stim=stim(1);
%                             magstimObject.disarm();
%                             magstimObject.disconnect();
                            
                        end
                        
                             
                        disp(sample);
                        if mod(sample,window) == 0 && sample<3000

%                             disp('sample: ')
%                             fprintf('%.2f\t\n',sample);
                            chunk = allvec(1,end-window+1:end);
                            allvec = [];
                            chunk = bandpass(chunk,[8,13],fs);
                            coeffs = aryule(chunk(edge+1:end-edge), p); 
                            coeffs = -coeffs(end:-1:2);
                            nextvalues = zeros(1,p+forwardsample);
                            nextvalues(1:p) = chunk(end-p-edge+1:end-edge);

                            for i = 1:forwardsample
                                nextvalues(p+i) = coeffs*nextvalues(i:p+i-1)';
                            end

                            phase = angle(hilbert(nextvalues(p+1:end)));
                            p1 = find(abs(phase(:)-pi) < 0.1);
                            %p2 = find(abs(phase(:)-0) < 0.1);
                            t1 = find(p1 - edge > 0);
%                             disp('t1: ')
%                             fprintf('%.2f\t\n',t1);
                            disp(phase);
                            %t2 = find(p1 - edge > 0);
                            pause(p1(t1(1))/1000);
                            disp('fire before');
                            magstimObject.fire();
                            disp('fire after');
                            
                            disp(firstime);
                            magstimObject.pause(5);
                        end
                        if sample==3000
                            magstimObject.disarm();
                            magstimObject.disconnect();
                        end
                        if dims(2) > 1000000 / props.samplingInterval
                            data1s = data1s(:, dims(2) - 1000000 / props.samplingInterval : dims(2));
                            avg = mean(mean(data1s.*data1s));
                            disp(['Average power: ' num2str(avg)]);

                            % set data buffer to empty for next full second
                            data1s = [];
                        end


                    case 3       % Stop message   
                        disp('Stop');
                        data = pnet(con, 'read', hdr.size - header_size);
                        finish = true;

                    otherwise    % ignore all unknown types, but read the package from buffer 
                        data = pnet(con, 'read', hdr.size - header_size);
                end
                tryheader = pnet(con, 'read', header_size, 'byte', 'network', 'view', 'noblock');
            end
        catch
            er = lasterror;
            disp(er.message);
        end
    end % Main loop
    
    % Close all open socket connections
    pnet('closeall');
    
    % Display a message
    disp('connection closed');

    
    

%% ***********************************************************************
% Read the message header
function hdr = ReadHeader(con)
    % con    tcpip connection object
    
    % define a struct for the header
    hdr = struct('uid',[],'size',[],'type',[]);

    % read id, size and type of the message
    % swapbytes is important for correct byte order of MATLAB variables
    % pnet behaves somehow strange with byte order option
    hdr.uid = pnet(con,'read', 16);
    hdr.size = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));
    hdr.type = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));


%% ***********************************************************************   
% Read the start message
function props = ReadStartMessage(con, hdr)
    % con    tcpip connection object    
    % hdr    message header
    % props  returned eeg properties

    % define a struct for the EEG properties
    props = struct('channelCount',[],'samplingInterval',[],'resolutions',[],'channelNames',[]);

    % read EEG properties
    props.channelCount = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));
    props.samplingInterval = swapbytes(pnet(con,'read', 1, 'double', 'network'));
    props.resolutions = swapbytes(pnet(con,'read', props.channelCount, 'double', 'network'));
    allChannelNames = pnet(con,'read', hdr.size - 36 - props.channelCount * 8);
    props.channelNames = SplitChannelNames(allChannelNames);

    
%% ***********************************************************************   
% Read a data message
function [datahdr, data, markers] = ReadDataMessage(con, hdr, props)
    % con       tcpip connection object    
    % hdr       message header
    % props     eeg properties
    % datahdr   data header with information on datalength and number of markers
    % data      data as one dimensional arry
    % markers   markers as array of marker structs
    
    % Define data header struct and read data header
    datahdr = struct('block',[],'points',[],'markerCount',[]);

    datahdr.block = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));
    datahdr.points = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));
    datahdr.markerCount = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));

    % Read data in float format
    data = swapbytes(pnet(con,'read', props.channelCount * datahdr.points, 'single', 'network'));

    % Define markers struct and read markers
    markers = struct('size',[],'position',[],'points',[],'channel',[],'type',[],'description',[]);
    for m = 1:datahdr.markerCount
        marker = struct('size',[],'position',[],'points',[],'channel',[],'type',[],'description',[]);

        % Read integer information of markers
        marker.size = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));
        marker.position = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));
        marker.points = swapbytes(pnet(con,'read', 1, 'uint32', 'network'));
        marker.channel = swapbytes(pnet(con,'read', 1, 'int32', 'network'));

        % type and description of markers are zero-terminated char arrays
        % of unknown length
        c = pnet(con,'read', 1);
        while c ~= 0
            marker.type = [marker.type c];
            c = pnet(con,'read', 1);
        end

        c = pnet(con,'read', 1);
        while c ~= 0
            marker.description = [marker.description c];
            c = pnet(con,'read', 1);
        end
        
        % Add marker to array
        markers(m) = marker;  
    end

    
%% ***********************************************************************   
% Helper function for channel name splitting, used by function
% ReadStartMessage for extraction of channel names
function channelNames = SplitChannelNames(allChannelNames)
    % allChannelNames   all channel names together in an array of char
    % channelNames      channel names splitted in a cell array of strings

    % cell array to return
    channelNames = {};
    
    % helper for actual name in loop
    name = [];
    
    % loop over all chars in array
    for i = 1:length(allChannelNames)
        if allChannelNames(i) ~= 0
            % if not a terminating zero, add char to actual name
            name = [name allChannelNames(i)];
        else
            % add name to cell array and clear helper for reading next name
            channelNames = [channelNames {name}];
            name = [];
        end
    end

