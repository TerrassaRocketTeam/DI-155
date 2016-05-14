classdef calibrationUtility2015 < handle
    %   DEPRECATED
    %     NOTE: prefer calibrationUtility2016
    %     NOTE: Not updated since it was deprecated, probably doesn't work.
    %
    %   This utility is a versiono of the calibrationUtility2016 utility
    %   compatible with matlab versions older than 2016a.
    %
    %   This is not as feature complete as its sibiling class
    %

    properties
      fig
      data
      current
      plt
      xmax
      xmin
      ymax
      ymin
    end

    properties (GetAccess=private)
      btn
      txt1
      txt2
      axes
      regressionData
      stopCallback
    end

    properties (Dependent)
      regressionLineData
      Units
    end

    methods
      %% Initializes the utility
      function obj = calibrationUtility2015(title, stopCallback)
        obj.stopCallback = stopCallback;
        obj.xmax = 1;
        obj.xmin = -1;
        obj.ymax = 1;
        obj.ymin = -1;

        obj.fig = figure('Name', title, 'Position', [100 100 800 600]);

        % Create gauges
        %uigauge('semicircular',...
        %  'Position', [20, 430, 360, 150])

        % Create button
        obj.btn = uicontrol(obj.fig,...
          'Position', [360, 405, 80, 20],...
          'String', 'Add point',...
          'Callback', @obj.handleAddPointClick);

        uicontrol(obj.fig,...
          'Position', [360, 385, 80, 20],...
          'String', 'Finish',...
          'Callback', @obj.handleStopClick);

        % Create the text inputs
        obj.txt1 = uicontrol(obj.fig,...
          'Style', 'edit',...
          'Enable', 'Inactive',...
          'Position', [20, 390, 320, 30],...
          'String', 'TEXT1');

        obj.txt2 = uicontrol(obj.fig,...
          'Style', 'edit',...
          'Position', [460, 390, 320, 30],...
          'String', 'TEXT1');

        % Create main axes
        obj.axes = axes('Position', [40/800, 40/600, 720/800, 330/600]);
        xlabel('Volts')
        ylabel('Your units')

        % Create plots
        obj.plt = plot(obj.axes, 0, 0, '-b', 0, 0, 'xr', 0, 0);
        axis([obj.xmin obj.xmax obj.ymin obj.ymax])
      end

      %% Add a calibration point, it will be used to calculate the regression
      % This function will also redraw the graphics
      function obj = addCalibrationPoint(obj, point)
        obj.data = [obj.data; point];

        if point(1, 1) < obj.xmin
          obj.xmin = point(1, 1);
        end
        if point(1, 1) > obj.xmax
          obj.xmax = point(1, 1);
        end
        if point(1, 2) < obj.ymin
          obj.ymin = point(1, 2);
        end
        if point(1, 2) > obj.ymax
          obj.ymax = point(1, 2);
        end
      end

      %% Generates and stores a new line regression data
      function obj = calibrate(obj)
        if isvalid(obj.fig)
          if length(obj.data(1,:)) > 1
            [r,m,b] = regression(obj.data(:,1)',obj.data(:,2)');
            obj.regressionData = [r,m,b];
          end
        end
      end

      %% Returns the first and last point of the line to plot using the
      % regression data
      function regressionLineData = get.regressionLineData(obj)
        regressionLineData = [0 0; 0 0];
        if ~isempty(obj.regressionData)
          mi = min([obj.data(:, 1); obj.current]);
          ma = max([obj.data(:, 1); obj.current]);
          regressionLineData(1,:) = [mi; obj.calibratePoint(mi)];
          regressionLineData(2,:) = [ma; obj.calibratePoint(ma)];
        end
      end

      %% Returns the function that calculates the
      function Units = get.Units(obj)
        m = obj.regressionData(2);
        b = obj.regressionData(3);
        Units = @(point) (calibrate(m, b, point));
      end

      %% returns the calibrated value from the sensor value
      function point = calibratePoint(obj, point)
        if ~isempty(obj.regressionData)
          point = calibrate(obj.regressionData(2), obj.regressionData(3), point);

          if point < obj.ymin
            obj.ymin = point;
          end
          if point > obj.ymax
            obj.ymax = point;
          end
        else
          point = 0;
        end
      end

      %% Updates the current point (value from sensor)
      % This function will also redraw the graphics
      function obj = updateCurrentPoint(obj, point)
        obj.current = point;

        if point < obj.xmin
          obj.xmin = point;
        end
        if point > obj.xmax
          obj.xmax = point;
        end

        obj.redrawMain();
        obj.redrawGauges();
      end

      %% Redraw the gauges using the current point and calibration if available
      function obj = redrawGauges(obj)
        if isvalid(obj.fig)
          % Update text field
          set(obj.txt1, 'String', num2str(obj.current));
        end
      end

      %% Redraw the main axes using the current stored data
      function obj = redrawMain(obj)
        if isvalid(obj.fig)
          % Redraw points
          if ~isempty(obj.data)
            set(obj.plt(3), 'XData', obj.data(:,1));
            set(obj.plt(3), 'YData', obj.data(:,2));
            set(obj.plt(3), 'Color', 'g');
            set(obj.plt(3), 'LineStyle', 'none');
            set(obj.plt(3), 'Marker', 'o');
          end

          % Redraw current Point
          set(obj.plt(2), 'XData', obj.current);
          set(obj.plt(2), 'YData', obj.calibratePoint(obj.current));

          % Redraw lines
          set(obj.plt(1), 'XData', obj.regressionLineData(:,1));
          set(obj.plt(1), 'YData', obj.regressionLineData(:,2));

          % Set axis values
          axis([obj.xmin obj.xmax obj.ymin obj.ymax])

          drawnow;
        end
      end

      %% @private Handles the click of the btn
      function obj = handleAddPointClick(obj, ~, ~)
        val = str2double(get(obj.txt2, 'String'));

        if isnan(val)
          errordlg('The value on the text field is not a number', 'Calibration tool error');
        else
          obj.addCalibrationPoint([obj.current, val]);
          obj.calibrate();
          obj.redrawMain();
          obj.redrawGauges();
        end
      end

      %% @private Handles the click of the btn
      function obj = handleStopClick(obj, ~, ~)
        obj.stopCallback();
        close(obj.fig);
      end
    end
end

function point = calibrate (m, b, point)
  point = m .* point + b;
end
