function processRealtimePoint( t, dec, interface, fileName )
%PROCESSREALTIMEPOINT Update the interface and save the data to the files

interface.newPoint({[t; dec(:, 2)']});

dlmwrite(fileName, [t', dec(:, 2)], '-append');

end
