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
  %         logger = DataLogger(ComPort, SampleRate, ChanMat, Filter, Units);
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


  %   ACCESSIBLE VARIABLES
  %     - ChanMat
  %     - Units
  %     - Filter
  %     - ComPort
  %     - SampleRate
  %     - SampledData    Last data sampled but not yet processed
  %     - PocessedData   Last data processed
  %     - nChannels      Number of channels activated (through ChanMat)
  %

  properties (GetAccess=private)
    s
  end

  properties
    ChanMat
    Units
    Filter
    ComPort
    SampleRate
    SampledData
    PocessedData
    realTime
  end

  properties (Dependent)
    nChannels
  end

  methods

    %%
    %   + Initialitzation:
    %     logger = DataLogger(ComPort, SampleRate, ChanMat, Filter, Units)
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
    %     - ChanMat @2x4 matrix: Channel settings (enable and gain)
    %                NOTES:
    %                       enable,    gain
    %                  A1 [ 0 or 1,    1-20 ]
    %                  A2 [ 0 or 1,    1-20 ]
    %                  A3 [ 0 or 1,    1-20 ]
    %                  A4 [ 0 or 1,    1-20 ]
    %
    %                  - Gain values meaning:
    %                    Gain    � Volts Full Scale
    %                    1       50.0
    %                    2       25.0
    %                    4       12.5
    %                    5       10.0
    %                    8       6.25
    %                    10      5.0
    %                    16      3.125
    %                    20      2.5
    %
    %     - Filter @integer: 0 = disabled. Number of values to group and mean
    %                        together. For example, a value of 3 will calculate
    %                        the mean value of every 3 obtained values and output
    %                        the result as data.
    %                NOTES:
    %                  If the sample frequency is 1000 and the filter is 3, the
    %                  processed data frequency will be 1000/3
    %
    %     - Units @function: This function will be called with each value in
    %                        in volts, the returned value will be stored as the
    %                        correct output value.
    %                NOTES:
    %                  This function should be fast and not asyncronous for the
    %                  correct operation.
    %                  If your functions throws an error it will be catched and
    %                  not displayed. The value will be computed without the
    %                  function.
    %                  It migth be faster to pass @(x)(x) as a function than not
    %                  passing anything. Although both ways should work.
    %                EXAMPLE:
    %                  @(x) (x*0,001)  % Will display the output in mV
    %
    function obj = DataLogger(ComPort, SampleRate, ChanMat, Filter, Units)
      obj.ComPort = ComPort;
      obj.SampleRate = SampleRate;
      obj.ChanMat = ChanMat;
      obj.Units = Units;
      obj.Filter = Filter;

      % Open a the serial conection and configure it
      obj.s = serial(ComPort,...
        'BaudRate',9600,...
        'Parity','none',...
        'InputBufferSize',1024,...
        'Terminator','CR',...
        'StopBits',1,...
        'DataBits',8);

      InitiateConnection(obj.s, obj.ChanMat, obj.SampleRate)
    end

    function nChannels = get.nChannels(obj)
      nChannels = 0;
      for j=1:4
        if obj.ChanMat(j,1)
          nChannels = nChannels+1;
        end
      end
    end

    %%
    %   + Get samples during some time:
    %     logger.getSamples(Time)
    %
    %     - Time @number: Number of seconds to record
    function data = getSamples(obj, Time)
      %Star AD conversion
      fprintf(obj.s,'%s\r','start');
      data=[];

      % Capturing data
      fread(obj.s);
      tic;
      h = waitbar(0,'DI-155 is sampling.');
      while toc<Time
        data=[data fread(obj.s)];
        waitbar(toc/Time,h);
      end
      fprintf(obj.s,'%s\r','stop');
      close(h);

      obj.SampledData = data;
    end

    %%
    %   + Get samples on almost real time:
    %     logger.getRealTime(Time, callback)
    %
    %     - Time @number: Number of seconds to record
    %             NOTE:
    %               Use time 0 to keep collection data until
    %               logger.stopRealTime() is called
    %
    %     - callback @function: Function that will be called with new datapoints.
    %                           This function will be called with two arguments:
    %                           data and time. Both are arrays of values.
    function getRealTime(obj, Time, callback)
      obj.startRealTime();

      %Define variables
      ChanMatL = obj.ChanMat;
      UnitsL = obj.Units;
      nChannelsL = obj.nChannels;
      SampleRateL = obj.SampleRate;
      FilterL = obj.Filter;

      %Star AD conversion
      fprintf(obj.s,'%s\r','start');
      data = [];

      % Capturing data
      fread(obj.s);
      tic;
      lastTime = 0;
      while obj.shouldStopRealTime(Time)
        buffer = fread(obj.s);
        data = [data buffer];
        [dec, t] = processBatchData(buffer, ChanMatL, UnitsL, nChannelsL, SampleRateL, FilterL);
        callback(dec, t + lastTime);
        lastTime = t(end) + lastTime;
      end
      fprintf(obj.s,'%s\r','stop');

      obj.realTime = 0;
      obj.SampledData = data;
    end

    %% @PRIVATE
    %    + Update the realTime variable
    function obj = startRealTime(obj)
      obj.realTime = 1;
    end

    %% @PRIVATE
    %    + Check if a real time acquisition shoul stop or not
    function stop = shouldStopRealTime(obj, Time)
      if Time
        stop = toc < Time;
      else
        stop = obj.realTime;
      end
    end

    %%
    %    + Stop realTime acquisition strated with a Time = 0;
    function obj = stopRealTime(obj)
      obj.realTime = 0;
    end

    %%
    %   + Process and get data
    %     [data, time] = logger.processData(data)
    %
    %     - data @dataset (OPTIONAL): If this parameter is not passed, the last
    %                                 sample taken will be used
    %
    %     + data (output) array of values
    %     + time (output) array of times for each value
    function [dec, t] = processData(obj, data)
      if nargin == 1
        data = obj.SampledData;
      end
      [dec, t] = processBatchData(data, obj.ChanMat, obj.Units, obj.nChannels, obj.SampleRate, obj.Filter);
      obj.PocessedData = {dec, t};
    end

    function delete(obj)
      fclose(obj.s);
    end
  end

end

% Initiates the serial connection with the datalogger
function InitiateConnection(s, ChanMat, SampleRate)
  fopen(s);
  fprintf(s,'%s\r','asc');  %This command is required since we wil use the xhhhh format in the commands that follow.

  % slist. Setting the list of channel to sample.
  % See table 'DI-155 Scan List Word Definitions'
  Pos=0;
  ScanList(1:16)=0;

  for i=1:4
    if ChanMat(i,1)
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

      switch ChanMat(i,2) % Analog gain code. See Table 'DI-155 Analog Gain Code Tale'
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
      word=binaryVectorToHex(ScanList);
      slist_str=['slist ' num2str(Pos) ' x' word];
      fprintf(s,'%s\r',slist_str);
      Pos=Pos+1;
    end
  end

  % srate. Setting the sample rate to sample.
  srate=750000/SampleRate; %This calculation is given in the documentation, in 'srate Scan Rate Command'.
  srate_str=['srate ' num2str(srate)];
  fprintf(s,'%s\r',srate_str);

  %Binary data output format
  fprintf(s,'%s\r','bin');
end

% Processes 1 single datapoint from the datalogger
function dataPoint = processDataPoint(data, ChanMat)
  dataPoint = zeros(4,1);
  for i=1:4
    if ChanMat(i,1)
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
function [dec, t] = processBatchData(data, ChanMat, Units, nChannels, SampleRate, Filter)
  data=dec2bin(data);

  i=1;
  dec=[];
  while i+(2*sum(ChanMat,1)-1)<=size(data,1) % While enough data is available for all enabled channels measurement.
    if ~str2double(data(i,8))% Sync bit
      dec(end+1,:) = processDataPoint([data(i+1,1:7); data(i,1:7)], ChanMat);
      i=i+nChannels*2;
    else
      i=i+1;
    end
  end

  % If Filter is set we group values and take the mean of them
  if Filter
    res = zeros(ceil(length(dec)/Filter), 1);

    for j=1:4
      if ChanMat(j,1)
        for i=1:floor(length(dec)/Filter)
          res(i, j) = mean(dec(((i-1)*Filter+1):(i*Filter), j));
        end

        % If any values are left, we mean them
        if mod(length(dec), Filter)
          res(ceil(length(dec)/Filter), j) = mean(dec((end - mod(length(dec), Filter)):end, j));
        end
      end
    end

    % Save the new data
    dec = res;
    clear res;

    % Override the SampleRate with the new one
    SampleRate = SampleRate / Filter;
  end

  % From decimal number from -8192 to 8181 to voltage. See equation in
  % Table 'Ideal DI-155 ADC Binary Coding'
  for i=1:4
    if ChanMat(i,1)
      try
        dec(:,i) = Units{i}((50/ChanMat(i,2))*(dec(:,i)/8192));
      catch err
        if strcmp(err.identifier, 'MATLAB:badsubscript')
          display('WARNING: Units does not exist for some channel')
        else
          display('WARNING: an error ocurred changing the units, check your Units functions')
        end
        dec(:,i) = (50/ChanMat(i,2))*(dec(:,i)/8192);
      end
    end
  end

  t=0:(1/SampleRate):(length(dec)-1)*(1/SampleRate); % Time vector
end
