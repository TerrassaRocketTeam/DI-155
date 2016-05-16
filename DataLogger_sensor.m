classdef DataLogger_sensor < handle
    % DataLogger_sensor is a general class for defining a device that connects to the top a analog in in the DI-155 datalogger
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
    %
    %     - filter @integer: 0 = disabled. Number of values to group and mean
    %                        together. For example, a value of 3 will calculate
    %                        the mean value of every 3 obtained values and output
    %                        the result as data.
    %                NOTES:
    %                  If the sample frequency is 1000 and the filter is 3, the
    %                  processed data frequency will be 1000/3
    %
    %     - postProcessCallback @function: This function will be called with each value in
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

    properties (GetAccess = public, SetAccess = immutable)
      id
      loggerType
      name
    end

    properties (Access = public)
      filter
      gain
      inputPort
      postProcessCallback
      unitsName
    end

    properties (GetAccess = public, SetAccess = protected, SetObservable = true)
      data
      lastData
    end

    methods
      %% Constructor: Initializes the object
      function obj = DataLogger_sensor(id, name, inputPort, gain, filter, unitsName, postProcessCallback)
        narginchk(4, 7); % Check if we pass the correct number of arguments

        obj.gain = gain;
        obj.id = id;
        obj.loggerType = 'sensor';
        obj.name = name;
        obj.inputPort = inputPort;
        obj.data = timeseries();

        if nargin > 4
          obj.filter = filter;
        else
          obj.filter = 0;
        end

        if nargin > 5
          obj.unitsName = unitsName;
        else
          obj.unitsName = 'units';
        end

        if nargin > 6
          obj.postProcessCallback = postProcessCallback;
        else
          obj.postProcessCallback = @(x)(x);
        end
      end

      function addData(obj, data)
        obj.lastData = data;
        try
          obj.data = obj.data.append(data);
        catch err
          display(['WARNING: Data from ' obj.name ' has been reset due to impossibility to append'])
          obj.data = data;
        end
      end

      %
      % Setters and Getters
      %

      %% set filter and cheks if it's set correctly
      function set.filter (obj, filter)
        narginchk(2, 2); % Check the correct number of arguments

        if ~isa(filter, 'double')
          error('Filter must be a double')
        end

        if filter < 0
          error('Filter must be 0 or bigger')
        end

        obj.filter = filter;
      end

      %% set gain and cheks if it's set correctly
      function set.gain (obj, gain)
        narginchk(2, 2); % Check the correct number of arguments

        if ~isa(gain, 'double')
          error('Gain must be a double')
        end

        if gain > 20
          error('Gain must be smaller than 21')
        end

        if gain < 1
          error('Gain must be bigger than 0')
        end

        obj.gain = gain;
      end

      %% set inputPort and cheks if it's set correctly
      function set.inputPort (obj, inputPort)
        narginchk(2, 2); % Check the correct number of arguments

        if ~isa(inputPort, 'double')
          error('Input port must be a double')
        end

        if inputPort > 5
          error('Input port must be smaller than 5')
        end

        if inputPort < 1
          error('Input port must be bigger than 0')
        end

        obj.inputPort = inputPort;
      end

      %% set postProcessCallback and cheks if it's set correctly
      function set.postProcessCallback (obj, postProcessCallback)
        narginchk(2, 2); % Check the correct number of arguments

        if ~isa(postProcessCallback, 'function_handle')
          error('Post process callback must be a function')
        end

        obj.postProcessCallback = postProcessCallback;
      end

      %% set unitsName and cheks if it's set correctly
      function set.unitsName (obj, unitsName)
        narginchk(2, 2); % Check the correct number of arguments

        if ~isa(unitsName, 'char')
          error('Units name must be a string (char)')
        end

        obj.unitsName = unitsName;
      end
    end
end
