function processRealtimePoint( data, interface, fileName )
%PROCESSREALTIMEPOINT Update the interface and save the data to the files

interface.newPoint({data});

dlmwrite(fileName, [data.Time data.Data], '-append');

end
