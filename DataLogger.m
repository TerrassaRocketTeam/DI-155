classdef DataLogger < handle
  %   Pep Rodeja Ferrer, based on Oriol Casamor Martinell work
  %   Dataq DI-155 Acquisition Software
  %
  %   See 'Di-155 Data Acquisition Starter's Kit's Protocol' for further
  %   information
  %
  %   HOW TO USE?
  %
  %   1) Set up the logger with
  %         logger = DataLogger(ComPort, SampleRate, chanMat, filter, postProcessCallback);
  %      more details on the initialitzation description
  %
  %   2) [OPTIONAL] Use calibrateLogger to calibrate your sensors
  %         calibrateLogger(logger)
  %
  %   3) [OPTIONAL] Use PlotInterface to plot the results as they come
  %         interface = PlotInterface({[0;0]}, {'Prova'}, 'x', 'y', @logger.stopRealTime);
  %
  %   4) Start the acquisition
  %         logger.getRealTime(0, @(dec, t)(processRealtimePoint(t, dec, interface, fileName)));
  %      * Use time = 0 to do it indefinetly, remmember to call
  %        @logger.stopRealTime to stop the acquisition.
  %      * Use time = number to limit the time
  %      Pass a callback to process the data as it comes
  %
  %   5) Delete the logger
  %         logger.delete();
  %

  properties (GetAccess = public, SetAccess = immutable)
    ComPort
  end

  properties
    SampleRate
    ConnectedDevices
  end

  properties (GetAccess = public, SetAccess = private, SetObservable = true)
    outConfiguration
    inConfiguration
    isCapturing
  end

  properties (Dependent = true)
    nChannels
    chanMat
    postProcessCallback
    filter
  end

  properties (Access = private)
    s
  end

  methods

    %%
    %   + Initialitzation:
    %     logger = DataLogger(ComPort, SampleRate, chanMat, filter, postProcessCallback)
    %
    %     - ComPort @string: The port name used.
    %                EXAMPLE:
    %                  'COM3'
    %
    %     - SampleRate @integer: Sample rate in Hz. Eg
    %                NOTES:
    %                  Max sample rate for one channel is 10 000 Hz
    %                  Max sample rate is 10000/n Hz for n channels
    %                EXAMPLE:
    %                  1000
    %
    %     - ConnectedDevices @cell: A cell with sensor and actuator objects
    %

    function obj = DataLogger(ComPort, SampleRate, ConnectedDevices)
      obj.ComPort = ComPort;
      obj.SampleRate = SampleRate;
      obj.ConnectedDevices = ConnectedDevices;

      % We set the initial configuration
      obj.outConfiguration = [0; 0; 0; 0]; % No output signal on any channel
      obj.inConfiguration = getConfiguration(ConnectedDevices); % No sampling on any channel
      obj.isCapturing = false;

      % Open a the serial conection and configure it
      obj.s = serial(ComPort,...
        'BaudRate',9600,...
        'Parity','none',...
        'InputBufferSize',1024,...
        'Terminator','CR',...
        'StopBits',1,...
        'DataBits',8);

      fopen(obj.s);
    end

    function foundDevice = findDeviceById(obj, id)
      foundDevice = false;
      for d = obj.ConnectedDevices
        device = cell2mat(d);
        if strcmp(device.id, id)
          foundDevice = device;
        end
      end
    end

    function enableDevice(obj, id)
      device = obj.findDeviceById(id);

      if device
        if strcmp(device.loggerType, 'sensor')
          obj.inConfiguration(device.inputPort) = 1;
        elseif strcmp(device.loggerType, 'actuator')
          obj.outConfiguration(device.outputPort) = 1;
        else
          error('This device has no correct loggerType')
        end
      end
    end

    function disableDevice(obj, id)
      device = obj.findDeviceById(id);

      if device
        if strcmp(device.loggerType, 'sensor')
          obj.inConfiguration(device.inputPort) = 0;
        elseif strcmp(device.loggerType, 'actuator')
          obj.outConfiguration(device.outputPort) = 0;
        else
          error('This device has no correct loggerType')
        end
      end
    end

    %%
    %   + Get samples on almost real time:
    %     logger.getData()
    %
    %     - Time @double: 0 for infinity (optional)
    %
    %     - device @device or @device id (optional)
    %
    function getData(obj, Time, device)
      % Check if Time was provided
      if nargin == 1
        Time = 0;
      end

      % Check if it is already getting data
      if obj.isCapturing
        error('Logger is already getting data')
      end

      % Check if we require only one device
      if nargin == 3
        % If is an id, get the device
        if isa(device, 'char')
          device = obj.findDeviceById(device);
        end

        if strcmp(device.loggerType, 'sensor')
          conf = [0; 0; 0; 0];
          conf(device.inputPort) = 1;
          obj.inConfiguration = conf;
        else
          error('This device is not supported')
        end
      end

      % Configure connection
      obj.ConfigureConnection();

      % Save variables
      chanMatL = obj.chanMat;
      nChannelsL = obj.nChannels;
      SampleRateL = obj.SampleRate;
      filterL = obj.filter;

      % Make sure we use the correct sample rate
      SampleRateL = SampleRateL * obj.nChannels;
      if SampleRateL > 10000
        SampleRateL = 10000;
      end

      % Star AD conversion
      obj.isCapturing = true;
      fprintf(obj.s,'%s\r','start');

      % Capturing data
      fread(obj.s);
      tic;
      lastTime = 0;
      while obj.shouldStop(Time) && ~obj.shouldReconfigure(chanMatL, SampleRateL, filterL)
        buffer = fread(obj.s);
        [out, finalTime] = processBatchData(buffer, chanMatL, obj.postProcessCallback, nChannelsL, SampleRateL, filterL, lastTime);
        obj.assingOutToSensors(out);
        lastTime = finalTime + lastTime;
      end

      % Stop the AD conversion
      obj.isCapturing = false;
      fprintf(obj.s,'%s\r','stop');

      if obj.shouldReconfigure(chanMatL, SampleRateL, filterL)
        obj.getData();
      end
    end

    function stopGetData(obj)
      obj.isCapturing = false;
    end

    % Initiates the serial connection with the datalogger
    function ConfigureConnection(obj)
      %Binary data output format
      fprintf(obj.s,'%s\r','bin');

      % slist. Setting the list of channel to sample.
      % See table 'DI-155 Scan List Word Definitions'
      Pos=0;
      ScanList(1:16)=0;

      for i=1:4
        if obj.chanMat(i,1)
          switch i %Channel
            case 1
              ScanList(13:16)=[0 0 0 0];
            case 2
              ScanList(13:16)=[0 0 0 1];
            case 3
              ScanList(13:16)=[0 0 1 0];
            case 4
              ScanList(13:16)=[0 0 1 1];
          end

          switch obj.chanMat(i,2) % Analog gain code. See Table 'DI-155 Analog Gain Code Tale'
            case 1
              ScanList(6:8)=[0 0 0];
            case 2
              ScanList(6:8)=[0 0 1];
            case 4
              ScanList(6:8)=[0 1 0];
            case 5
              ScanList(6:8)=[0 1 1];
            case 8
              ScanList(6:8)=[1 0 0];
            case 10
              ScanList(6:8)=[1 0 1];
            case 16
              ScanList(6:8)=[1 1 0];
            case 20
              ScanList(6:8)=[1 1 1];
          end
          word=binaryVectorToDecimal(ScanList);
          slist_str=['slist ' num2str(Pos) ' ' num2str(word)];
          fprintf(obj.s,'%s\r',slist_str);
          Pos=Pos+1;
        end
      end

      % srate. Setting the sample rate to sample.
      SR = obj.SampleRate * obj.nChannels;
      if SR > 10000
        SR = 10000;
      end
      srate=750000/SR; %This calculation is given in the documentation, in 'srate Scan Rate Command'.
      srate_str=['srate ' num2str(srate)];
      fprintf(obj.s,'%s\r',srate_str);
    end

    %
    %   Getters and setters
    %

    function chanMat = get.chanMat (obj)
      chanMat = zeros(4, 2);
      chanMat(1:4, 2) = [1; 1; 1; 1];
      for d = obj.ConnectedDevices
        device = cell2mat(d);
        % If the device is a sensor and its activated
        if strcmp(d.loggerType, 'sensor') && obj.inConfiguration(device.inputPort)
          chanMat(device.inputPort, 1:2) = [1, device.gain];
        end
      end
    end

    function postProcessCallback = get.postProcessCallback (obj)
      postProcessCallback = mat2cell(zeros(4, 1));
      for d = obj.ConnectedDevices
        device = cell2mat(d);
        % If the device is a sensor and its activated
        if strcmp(d.loggerType, 'sensor') && obj.inConfiguration(device.inputPort)
          postProcessCallback{device.inputPort} = device.postProcessCallback;
        end
      end
    end

    function filter = get.filter (obj)
      filter = zeros(4, 1);
      for d = obj.ConnectedDevices
        device = cell2mat(d);
        % If the device is a sensor and its activated
        if strcmp(d.loggerType, 'sensor') && obj.inConfiguration(device.inputPort)
          if ~filter
            filter(device.inputPort) = 1;
          else
            filter(device.inputPort) = device.filter;
          end
        end
      end
    end

    function nChannels = get.nChannels(obj)
      nChannels = 0;
      for j=1:4
        if obj.chanMat(j,1)
          nChannels = nChannels+1;
        end
      end
    end

    function set.ComPort(obj, ComPort)
      if ~isa(ComPort, 'char')
        error('ComPort must be a char')
      end

      obj.ComPort = ComPort;
    end

    function set.SampleRate(obj, SampleRate)
      if ~isa(SampleRate, 'double')
        error('SampleRate must be a double')
      end

      obj.SampleRate = SampleRate;
    end

    function set.ConnectedDevices(obj, ConnectedDevices)
      if ~isa(ConnectedDevices, 'cell')
        error('ConnectedDevices must be a cell')
      end

      obj.ConnectedDevices = ConnectedDevices;
    end

    % Clean the garbage on deleting
    function delete(obj)
      fclose(obj.s); % Kill the serial connection on deleting
    end
  end

  methods (Access = private)
    %% @PRIVATE
    %    + Check if a real time acquisition shoul reconfigure with new settings
    function stop = shouldReconfigure(obj, chanMat, SampleRate, filter)
      stop = false;

      if SampleRate ~= obj.SampleRate
        stop = true;
      end

      for i = 1:4
        if filter(i) ~= obj.filter(i)
          stop = true;
        end
      end

      for i = 1:4
        if chanMat{i, 1} ~= obj.chanMat{i, 1}
          stop = true;
        end
        if chanMat{i, 2} ~= obj.chanMat{i, 2}
          stop = true;
        end
      end
    end

    %% @PRIVATE
    %    + Check if a real time acquisition shoul stop or not
    function stop = shouldStop(obj, Time)
      if Time
        stop = toc < Time;
      else
        stop = obj.isCapturing;
      end
    end

    %% @PRIVATE
    %    + Assing out data to the different sensors
    function assingOutToSensors(obj, out)
      for d = obj.ConnectedDevices
        device = cell2mat(d);
        % If the device is a sensor and its activated
        if strcmp(d.loggerType, 'sensor') && isa(out(device.inputPort), 'timeseries')
          device.addData(out(device.inputPort))
        end
      end
    end
  end
end

% Given the connected devices we activate all of them
function inConfiguration = getConfiguration(ConnectedDevices)
  inConfiguration = zeros(4, 1);
  for d = obj.ConnectedDevices
    device = cell2mat(d);
    if strcmp(d.loggerType, 'sensor')
      inConfiguration(device.inputPort) = 1;
    end
  end
end

% Processes 1 single datapoint from the datalogger
function dataPoint = processDataPoint(data, chanMat)
  dataPoint = zeros(1, 4);
  for i=1:4
    if chanMat(i,1)
      bin=[data(1,:) data(2,:)]; % See Table 'Di-155 Binary Dara Stream Example'

      % Inverting the MSB
      if bin(1)=='1'
        bin(1)='0';
      else
        bin(1)='1';
      end

      % From two's complement to decimal.
      dataPoint(i)=twos2dec(bin);
    end
  end
end

% Processes mutliple datapoints from the datalogger, filter them and adds time
function [out, finalTime] = processBatchData(data, chanMat, postProcessCallback, nChannels, globalSampleRate, filter, initialTime)
  data=dec2bin(data);

  i=1;
  dec=[];
  while i+(2*sum(chanMat,1)-1)<=size(data,1) % While enough data is available for all enabled channels measurement.
    if ~str2double(data(i,8))% Sync bit
      dec(end+1,:) = processDataPoint([data(i+1,1:7); data(i,1:7)], chanMat);
      i=i+nChannels*2;
    else
      i=i+1;
    end
  end

  % Override the SampleRate with the new one
  SampleRate = [globalSampleRate / filter(1); globalSampleRate / filter(2);...
   globalSampleRate / filter(3); globalSampleRate / filter(4)];

  for j=1:4
    if chanMat(j,1) && filter(j) ~= 1
      % If filter is set we group values and take the mean of them
      res = zeros(ceil(length(dec)/filter(j)), 1);
      f = filter(j);

      for i=1:floor(length(dec)/f)
        res(i) = mean(dec(((i-1)*f+1):(i*f), j));
      end

      % If any values are left, we take the avarage of them
      if mod(length(dec), f)
        res(ceil(length(dec)/f)) = mean(dec((end - mod(length(dec), f)):end, j));
      end

      % Save the new data
      dec(:, j) = res;
    end
  end

  clear res f;

  % From decimal number from -8192 to 8181 to voltage. See equation in
  % Table 'Ideal DI-155 ADC Binary Coding'
  for i=1:4
    if chanMat(i,1)
      try
        dec(:,i) = postProcessCallback{i}((50/chanMat(i,2))*(dec(:,i)/8192));
      catch err
        if strcmp(err.identifier, 'MATLAB:badsubscript')
          display('WARNING: postProcessCallback does not exist for some channel')
        else
          display('WARNING: an error ocurred changing the postProcessCallback, check your postProcessCallback functions')
        end
        dec(:,i) = (50/chanMat(i,2))*(dec(:,i)/8192);
      end
    end
  end

  % Generate the out timedata series
  out = zeros(1, 4);
  for i=1:4
    if chanMat(i,1)
      out(i) = timeseries(dec(:, i), (0:(1/SampleRate(i):(length(dec)-1)*(1/SampleRate(i)))) + initialTime);
    end
  end

  % Set the final time
  finalTime = (length(dec)-1)*(1/SampleRate(i)) + initialTime;
end
