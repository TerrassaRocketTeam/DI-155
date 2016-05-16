% Pep Rodeja
% Get data with DataLogger
%
% See RealtimeMain.m for more comments and how to process data in real time
%

% Sensor configuration
id = 'sensor1'; % Sensor id, must be unique per logger
name = 'Pressure Sensor'; % Sensor name (for logging)
inputPort = 5; % Analog input port on the data logger
gain = 5; % Sets the limits of the voltage input, see documentation !Important to not kill your data logger
filter = 0; % Number of samples to merge and take the mean (reduces noise and induces a bit of lag)
unitsName = 'bars'; % Units (for logging)
postProcessCallback = @(x)(x * 0.1 + 2); % Given the units in volts, transform them to whatever you want

% NOTE: You might want to create a subclass for each type of sensor so you
% can automatically set the name, gain, filter, units and callback.
% You may even add other properties or methodas like for example:
% sensor.isMaxed
% or
% sensor.hasBeenActivated

fprintf('before sensor\n')

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

fprintf('before logger\n')

logger = DataLogger(ComPort, SampleRate, ConnectedDevices);

fprintf('before calibration\n')

% try
  calibrateLogger(logger);
  
  fprintf('calibrated\n')

  Time = 1; % Number of seconds
  logger.getData(Time);

  data = sensor.data;

  interface = PlotInterface({data}, {'Analog in [Volts]'}, 'x', 'y');

  logger.delete()
% catch err
%   display(['ERROR! ' err.message])
%   line = err.stack.line;
%   display(['Line: ' num2str(line)])
%   display(['Name: ' err.stack.name])
%   file = err.stack.file;
%   display(['File:' file])
% 
%   if exist('logger','var')
%     logger.delete()
%   end
% end
