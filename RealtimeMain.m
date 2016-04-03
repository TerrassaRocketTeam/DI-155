% Pep Rodeja
% Get data with DataLogger
%
% Main file, change configurations here and execute this
%


% Select the channels used (firt column) and the gain (second)
ChanMat=[0 5;...   % AnalogIn 1
         1 5;...   % AnalogIn 2
         0 10;...  % AnalogIn 3
         0 20];    % AnalogIn 4

% This will likely be replace in the calibration
Units={@(x)(x);...
      @(x)(x);...
      @(x)(x);...
      @(x)(x)};

ComPort='COM3';
SampleRate = 5000; % Max 10000 for 1 channel
Filter = 5; % Group values in groups of n and take the mean of each group.

% Uncoment to list the ports
% instrfind('Port',ComPort)

% Initialize the logger
logger = DataLogger(ComPort, SampleRate, ChanMat, Filter, Units);

try
  % We set a unique fileName to store the new data
  fileName = ['dataResults_' datestr(datetime('now','TimeZone','Europe/Madrid'), 'yyyy-mm-dd_HH-MM-SS-FFF') '.dat'];

  % Initialize file
  dlmwrite(fileName,[0 0]);

  % Calibrate the logger
  calibrateLogger(logger);

  % Set up the real time ploting
  interface = PlotInterface({[0;0]}, {'Prova'}, 'x', 'y', @logger.stopRealTime);

  % Start the data acquisition
  logger.getRealTime(0, @(dec, t)(processRealtimePoint(t, dec, interface, fileName)));

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
