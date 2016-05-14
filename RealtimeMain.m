% Pep Rodeja
% Get data with DataLogger
%
% See RealtimeMain.m for more comments and how to process data in real time
%

% Sensor configuration
id = 'sensor1'; % Sensor id, must be unique per logger
name = 'Pressure Sensor'; % Sensor name (for logging)
inputPort = 1; % Analog input port on the data logger
gain = 5; % Sets the limits of the voltage input, see documentation !Important to not kill your data logger
filter = 0; % Number of samples to merge and take the mean (reduces noise and induces a bit of lag)
unitsName = 'bars'; % Units (for logging)
postProcessCallback = @(x)(x * 0.1 + 2); % Given the units in volts, transform them to whatever you want

% NOTE: You might want to create a subclass for each type of sensor so you
% can automatically set the name, gain, filter, units and callback.
% You may even add other properties or methods like for example:
% sensor.isMaxed
% or
% sensor.hasBeenActivated

% Sensor set up
sensor = DataLogger_sensor(id, name, inputPort, gain, filter, unitsName, postProcessCallback);

% Conected devices cell array
ConnectedDevices = {sensor};

% Logger configuration

% Uncoment to list the ports
% instrfind('Port',ComPort)
ComPort = 'COM4';
SampleRate = 5000; % Sample rate in Hz, see note below

% NOTE: The max sample rate is 10000, however this sample rate is shared between
% the different ports. The sample rate you set here is PER CHANNEL
% however, if you try to log from two channels at 10000 at the same time, you'll
% get a warning and the closest sample rate possible, in this case 5000 for each
% channel

logger = DataLogger(ComPort, SampleRate, ConnectedDevices);

try
  % We set a unique fileName to store the new data
  fileName = ['dataResults_' datestr(datetime('now','TimeZone','Europe/Madrid'), 'yyyy-mm-dd_HH-MM-SS-FFF') '.dat'];

  % Initialize file
  dlmwrite(fileName,[0 0]);

  % Calibrate the logger
  calibrateLogger(logger);

  % Set up the real time ploting
  interface = PlotInterface({timeseries(0,0)}, {'Prova'}, 'x', 'y', @logger.stopGetData);

  % Listen for new data
  % Send only one point at a time (we take the mean)
  listener = addlistener(sensor,'lastData','PostSet',...
    @(~, ~)(processRealtimePoint(sensor.lastData, interface, fileName)));

  % Start the data acquisition
  logger.getData(0, sensor);

  % Dismantle that
  logger.delete()
catch err

  % Displays the error
  display(['ERROR! ' err.message])
  line = err.stack.line;
  display(['Line: ' num2str(line)])
  display(['Name: ' err.stack.name])
  file = err.stack.file;
  display(['File:' file])

  % Deletes the logger so the com port does not remain in use in case of error
  if exist('logger', 'var')
    logger.delete()
  end
end
