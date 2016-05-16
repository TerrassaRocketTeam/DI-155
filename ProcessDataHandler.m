classdef ProcessDataHandler < handle
    %PROCESSDATAHANDLER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
      stop
      lastTime
    end
    
    methods
      function obj = ProcessDataHandler()
        obj.stop = 0;
        obj.lastTime = 0;
      end
    end
    
end

