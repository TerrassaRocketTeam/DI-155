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

  % Get the required varaibles from the logger
  ChanMat = logger.ChanMat;
  Units = logger.Units;

  % Test each channel
  for i=1:4
    if ChanMat(i,1)
      if exist('PreviousUnits', 'var') && ~isempty(PreviousUnits{i})
        % If there was a calibration file, ask the user wether to use it or not

        selection = questdlg(['Load previous calibration for channel ' num2str(i) '?'],...
          'Confirmation',...
          'Yes','No','Yes');

        switch selection,
          case 'Yes',
            % Use previous calibration
            Units{i} = PreviousUnits{i};
          case 'No'
            % Launch the calibration tool
            Units{i} = calibrate(logger, i);
        end
      else
        % Launch the calibration tool
        Units{i} = calibrate(logger, i);
      end
    end
  end

  % Save this new calibration settings
  save('calibrationData', 'Units');

  logger.Units = Units;

end

% This functions launches the claibration tools
function [Units] = calibrate(logger, i)
  % Create a calibration utility instance with the callback to stop the
  % the logger when its necessary
  utility = calibrationUtility2016(['Calibrate channel ' num2str(i)], @logger.stopRealTime);

  % Start getting data and send it to the calibration utility
  % Send only one point at a time (we take the mean)
  logger.getRealTime(0, @(dec, t)(utility.updateCurrentPoint(mean(dec(:,i)))));

  % Save the retults
  Units = utility.Units;

  % Delete the calibration utility
  utility.delete();
end
