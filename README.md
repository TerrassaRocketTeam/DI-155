Dataq DI-155 Acquisition Software
---------------------------------

By Pep Rodeja, based on Oriol Casmor work

This project includes two examples:
  - Main.m
  - RealtimeMain.m

, three library classes
  - DataLogger
  - PlotInterface
  - calibrationUtility2016    (and the 2015 version)

and two useful function
  - calibrateLogger
  - processRealtimePoint

All files are designed to work together.

### Workflow

1. Set the sensors and actuators
2. Set the logger
3. Set the observables
4. Start
  1. Function get data that loops
  2. Gets configuration
  3. Starts the ad conversion
  4. Reads the outcom
  5. proceses it
  6. Looks for a change in the configuration
  7. Go to 4, changes the configuration or stops

### TODO

- [ ] Unit testing
- [x] Filtering options
- [x] Calibration utility
- [x] Save calibration data
- [x] Datalogger: Units callback
- [x] Better resolve how to save the data
- [x] Change samplerate behaviour
- [x] Change realtime to use observables
- [x] Use timeseries

- [ ] Test what happens if I reconfigure the analogs while getting data
- [ ] Test what happens if I have configured 1 and 2. Then I want to disable 1.
The end result would be 2 but and intermediate state might be 2 and 2. See what
would happen if this occurs
