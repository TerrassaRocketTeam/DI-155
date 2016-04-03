classdef PlotInterface < handle
  %    Pep Rodeja ferrer
  %    Plotting library for use with the Dataq DI-155 Adquisition Software
  %
  %    + Initialitzation
  %      interface = PlotInterface(data, label, xlab, ylab)
  %      This will create a figure with the configured parameters
  %
  %      - data @{array}: Data points to display
  %                NOTES:
  %                  Each element of the {array} will be a line on the graph
  %                  Each must contain an [array] of data with the 2x(whatever)
  %                  size.
  %                  Using it with the adquisition library you must:
  %                           data = {[time; data(:, 2)']}
  %                  Where 2 is the channel selected in the configuration.
  %
  %                  To use it with more than one channel use:
  %                           data = {[time time; data(:, 1)' data(:, 2)']}
  %
  %                  Use different time arrays if you use different datasets
  %
  %      - label @{array}: Labels for each plot
  %                EXAMPLE:
  %                  {'Speed [m/s]', 'Acceleration [m/s2]'}
  %
  %      - xlab @string: xlabel
  %
  %      - ylab @string: ylabel
  %
  %
  %
  %    + Redrawing
  %      interface.redraw()
  %
  %
  %
  %    + Realtime update
  %      interface.newPoint(newPoint)
  %
  %      - newPint @{array}: Same as 'data' in initialitzation
  %              NOTES:
  %                New data will be appended not substituted
  %                Many points can be appended at once
  %


  properties
    data
    fig
    plots
    stopCallback
  end

  methods
    function obj = PlotInterface(data, label, xlab, ylab, stopCallback)
      narginchk(4, 5);

      if nargin > 4
        obj.stopCallback = stopCallback;
      end

      height=600;
      width=1300;

      scrz = get(0,'ScreenSize');
      figsize=[(scrz(3)-width)/2 (scrz(4)-height)/2 width height];
      F = figure('Name','DI-155 Realtime Data Acquisition',...
                     'renderer','zbuffer',...
                     'Menu','none',...
                     'Position',figsize,...
                     'DockControls','off',...
                     'Toolbar','figure',...
                     'Resize','off',...
                     'MenuBar','none',...
                     'CloseRequestFcn', @obj.handleCloseFigure,...
                     'Color',[0.941 0.941 0.941]);

      hold on;

      h = axes('Position',[.05 .075 .92 .89],...
               'Parent',F,...
               'Visible','on');
      cc=lines(4);

      p = 1:length(data);
      for i=1:length(data)
        p(i) = plot(h,data{i}(1,:),data{i}(2,:),'Color',cc(i,:));
      end

      legend(label);
      xlabel(xlab);
      ylabel(ylab);
      grid on;

      hold off;

      obj.fig = F;
      obj.data = data;
      obj.plots = p;

    end

    function redraw(obj)
      for i=1:length(obj.plots)
        set(obj.plots(i), 'XData', obj.data{i}(1,:));
        set(obj.plots(i), 'YData', obj.data{i}(2,:));
      end
    end

    function obj = newPoint(obj, newPoint)
      for i=1:length(newPoint)
        obj.data{i} = [obj.data{i}, newPoint{i}];
      end
      obj.redraw();
      drawnow;
    end

    function obj = handleCloseFigure(obj, ~, ~)
      obj.delete();
    end

    function delete(obj)
      if isa(obj.stopCallback,'function_handle')
        obj.stopCallback();
      end
      obj.fig.delete();
    end
  end

end
