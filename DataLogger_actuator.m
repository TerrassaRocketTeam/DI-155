classdef DataLogger_actuator < handle
    %ACTUATOR Summary of this class goes here
    %   Detailed explanation goes here

    properties (GetAccess = public, SetAccess = immutable)
      id
      loggerType
      name
    end

    properties (Access = public)
      gain
      outputPort
    end

    methods
      function obj = DataLogger_actuator(id, name, outputPort, gain)
        narginchk(4, 4); % Check if we pass the correct number of arguments

        obj.gain = gain;
        obj.id = id;
        obj.loggerType = 'actuator';
        obj.name = name;
        obj.outputPort = outputPort;
      end
    end

end
