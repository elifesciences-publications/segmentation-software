function logmsg(obj,msg,varargin)
%logmsg Send a message to be written to the log file
%   This function automagically works out where the log file is and sends
%   the message there and also outputs it to the command window.
%   obj: either a cExperiment or cTimelapse
%   msg: message to be written to the log file (formatted by sprintf)
%   Additional arguments are passed to sprintf.

if ~(isa(obj,'experimentTracking') || isa(obj,'timelapseTraps'))
    error('"logmsg" function only accepts experimentTracking or timelapseTraps objects as the first argument');
end

notify(obj,'LogMsg',loggingEvents.msg(sprintf(msg,varargin{:})));

end

