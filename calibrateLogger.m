function calibrateLogger( logger )
  % CALIBRATELOGGER Given an instance of the DataLogger class, this function
  %                 calibrates the channels with the utility or uses the saved
  %                 information to restore a past calibration
  %

  % Load previous calibration if exists data
  if exist('calibrationData.mat', 'file')
    load('calibrationData.mat', 'Units');
  end
  if exist('Units', 'var')
    PreviousUnits = Units; %#ok<NODEF>
  end

  % Get the required variables from the logger
  ConnectedDevices = logger.ConnectedDevices;
  
  Units = {};

  % Test each channel
  for d = ConnectedDevices
    device = d{1};
    if strcmp(device.loggerType, 'sensor')
      i = device.inputPort;
      if exist('PreviousUnits', 'var') && ~isempty(PreviousUnits{i})
        % If there was a calibration file, ask the user wether to use it or not

        selection = questdlg(['Load previous calibration for channel ' num2str(i) '?'],...
          'Confirmation',...
          'Yes','No','Yes');

        switch selection,
          case 'Yes',
            % Use previous calibration
            device.postProcessCallback = PreviousUnits{i};
          case 'No'
            % Launch the calibration tool
            device.postProcessCallback = calibrate(logger, device);
        end
      else
        % Launch the calibration tool
        device.postProcessCallback = calibrate(logger, device);
      end
    end
    Units{i} = device.postProcessCallback
  end

  % Save this new calibration settings
  save('calibrationData', 'Units');
end

% This functions launches the claibration tools
function [Units] = calibrate(logger, sensor)
  % Create a calibration utility instance with the callback to stop the
  % the logger when its necessary
  utility = calibrationUtility2016(...
    ['Calibrate channel ' sensor.name '(' sensor.id ')'], @logger.stopGetData);

  % Listen for new data
  % Send only one point at a time (we take the mean)
  listener = addlistener(sensor,'lastData','PostSet',...
    @(~, ~)(utility.updateCurrentPoint(mean(sensor.lastData))));

  % Start getting data and send it to the calibration utility
  logger.getData(0, sensor);

  % Save the retults
  Units = utility.Units;

  % Delete the calibration utility and he listener
  utility.delete();
  delete(listener);
end
