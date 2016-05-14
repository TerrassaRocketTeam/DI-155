classdef calibrationUtility2016 < handle
    %   Pep Rodeja Ferrer
    %   Calibration utility for Dataq DI-155 Acquisition Software
    %      NOTE: Better used through calibrateLogger function.
    %
    %   Without the calibrateLogger function function, this object is
    %   actually pretty generic and it may be used to calibrate other tools.
    %
    %   HOW IT WORKS?
    %
    %     1) Initialize an object with:
    %           utility = calibrationUtility2016(title, stopCallback)
    %        The stopCallback will be called when the calibration is complete.
    %
    %     2) Make your datalogger add points to the utility with:
    %           utility.updateCurrentPoint(point)
    %        This will update the read on the tool
    %
    %     3) Your program will stop until the calibration has been completed.
    %        After that, you'll be able to access a function that transforms
    %        your values into calibrated values through:
    %           function = utility.Units;
    %
    %     4) Finally, you can:
    %           utility.delete();
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
      gauge1
      gauge2
      axes
      regressionData
      stopCallback
      calibrationTxt
    end

    properties (Dependent)
      regressionLineData
      Units
    end

    methods
      %% Initializes the utility
      function obj = calibrationUtility2016(title, stopCallback)
        obj.stopCallback = stopCallback;
        obj.xmax = 1;
        obj.xmin = -1;
        obj.ymax = 1;
        obj.ymin = -1;

        obj.fig = uifigure('Name', title,...
          'Position', [100 100 800 600],...
          'CloseRequestFcn', @obj.handleStopClick);

        % Create text labels
        uilabel(obj.fig,...
          'Position', [300, 560, 200, 20],...
          'Text', 'Calibration function:',...
          'HorizontalAlignment', 'center');

        obj.calibrationTxt = uilabel(obj.fig,...
          'Position', [300, 535, 200, 20],...
          'Text', 'y = m * x + b',...
          'HorizontalAlignment', 'center');

        % Create gauges
        obj.gauge1 = uigauge(obj.fig,...
          'semicircular',...
          'Position', [20, 420, 320, 175],...
          'Limits', [obj.xmin obj.xmax]);

        obj.gauge2 = uigauge(obj.fig,...
          'semicircular',...
          'Position', [460, 420, 320, 175],...
          'Limits', [obj.ymin obj.ymax],...
          'ScaleColors', {'g'},...
          'ScaleColorLimits', [0.9 1.1]);

        % Create button
        obj.btn = uibutton(obj.fig,...
          'Position', [360, 400, 80, 25],...
          'Text', 'Add point',...
          'ButtonPushedFcn', @obj.handleAddPointClick);

        uibutton(obj.fig,...
          'Position', [360, 375, 80, 20],...
          'Text', 'Finish',...
          'ButtonPushedFcn', @obj.handleStopClick);

        % Create the text inputs
        obj.txt1 = uieditfield(obj.fig, 'numeric',...
          'Editable','off',...
          'Position', [20, 380, 320, 30]);

        obj.txt2 = uieditfield(obj.fig, 'numeric',...
          'Position', [460, 380, 320, 30]);

        % Create main axes
        obj.axes = uiaxes(obj.fig,...
          'Position', [20, 20, 740, 350],...
          'XLim', [obj.xmin obj.xmax],...
          'YLim', [obj.ymin obj.ymax]);

        obj.axes.XLabel.String = 'Volts';
        obj.axes.YLabel.String = 'Your units';

        % Create plots
        obj.plt = plot(obj.axes, 0, 0, '-b', 0, 0, 'xr', 0, 0);
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
          if length(obj.data(:,1)) > 1
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
        if ~isempty(obj.regressionData)
          m = obj.regressionData(2);
          b = obj.regressionData(3);
          Units = @(point) (calibrate(m, b, point));
        else
          Units = @(point) (point);
        end
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
          set(obj.txt1, 'Value', obj.current);

          % Redraw current Point
          obj.gauge1.Value = obj.current;
          obj.gauge2.Value = obj.calibratePoint(obj.current);

          % Redraw selected value
          selected = obj.txt2.Value;
          obj.gauge2.ScaleColorLimits = [selected-0.1 selected+0.1];

          % Update gauge limits
          obj.gauge1.Limits = [obj.xmin obj.xmax];
          obj.gauge2.Limits = [obj.ymin obj.ymax];
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
          obj.axes.XLim = [obj.xmin obj.xmax];
          obj.axes.YLim = [obj.ymin obj.ymax];

          % Update calibration function
          if ~isempty(obj.regressionData)
            obj.calibrationTxt.Text = ['y = ' num2str(obj.regressionData(2)) ' * x + ' num2str(obj.regressionData(3))];
          end

          drawnow;
        end
      end

      %% @private Handles the click of the add point btn
      function obj = handleAddPointClick(obj, ~, ~)
        val = obj.txt2.Value;

        if isnan(val)
          errordlg('The value on the text field is not a number', 'Calibration tool error');
        else
          obj.addCalibrationPoint([obj.current, val]);
          obj.calibrate();
          obj.redrawMain();
          obj.redrawGauges();
        end
      end

      %% @private Handles the click of the stop btn or close
      function obj = handleStopClick(obj, ~, ~)
        selection = questdlg('Do you want to finish the calibration?',...
          'Confirmation',...
          'Yes','No','Yes');

        switch selection,
          case 'Yes',
            obj.stopCallback();
            delete(obj.fig);
          case 'No'
            return;
        end
      end
    end
end

%% Function that returns a calibrated point
%  NOTE: This is a linear function, other might be added in the future
function point = calibrate (m, b, point)
  point = m .* point + b;
end
