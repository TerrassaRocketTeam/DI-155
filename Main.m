% Pep Rodeja
% Get data with DataLogger
%
% See RealtimeMain.m for more comments and how to process data in real time
%


ChanMat=[0 5;...
         1 10;...
         0 10;...
         0 20];

Units={@(x)(x);...
       @(x)(x);...
       @(x)(x);...
       @(x)(x)};

ComPort = 'COM3';
Time = 1;
SampleRate = 5000;
Filter = 5;

% Uncoment to list the ports
% instrfind('Port',ComPort)

logger = DataLogger(ComPort, SampleRate, ChanMat, Filter, Units);

try
  calibrateLogger(logger);

  logger.getSamples(Time);

  [data, t] = logger.processData();

  data1 = [t; data(:, 2)'];
  interface = PlotInterface({data1}, {'Analog in [Volts]'}, 'x', 'y');

  logger.delete()
catch err
  display(['ERROR! ' err.message])
  line = err.stack.line;
  display(['Line: ' num2str(line)])
  display(['Name: ' err.stack.name])
  file = err.stack.file;
  display(['File:' file])

  if exist('logger','var')
    logger.delete()
  end
end
