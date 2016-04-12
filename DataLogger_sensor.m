classdef DataLogger_sensor < handle
    %ACTUATOR Summary of this class goes here
    %   Detailed explanation goes here

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
        obj.data = [obj.data; data];
        obj.lastData = data;
      end

      %
      % Setters and Getters
      %

      %% set filter and cheks if it's set correctly
      function set.filter (obj, filter)
        narginchk(2, 2); % Check the correct number of arguments

        if ~ias(filter, 'double')
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

        if ~ias(gain, 'double')
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
