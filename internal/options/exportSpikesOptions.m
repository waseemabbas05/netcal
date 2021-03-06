classdef exportSpikesOptions < baseOptions
% EXPORTSPIKESOPTIONS Options for exporting spikes
%   Class containing the options for spike exports
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also exportSpikes, baseOptions, optionsWindow

  properties
    % Export type
    %exportType = {'txt', 'csv'};
    exportType = {'csv', 'txt'};

    % Subpopulation to export (leave empty for doing it on every ROI)
    subpopulation = {'everything', ''};
    
    % Only exports spikes within the given temporal subset
    subset = [0 600];
    
    % What units to use when exporting spike times
    timeUnits = {'seconds', 'milliseconds', 'frames'};
    
    % What order to export the spikes:
    % - time: first on the list is the first that tfired
    % - ROI: first on the list is the first ROI that fired
    exportOrder = {'time', 'ROI'};
    
    % If true will include an additional column where the ROIs of the subpopulation have been rescaled from 1 to N (N being the subpopulation size)
    includeSimplifiedROIorder = false;
    
    % Main folder to export to (only for experiment pipeline)
    % - experiment: inside the exports folder of the experiment
    % - project: inside the exports folder of the project
    exportFolder = {'experiment', 'project'};
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.subpopulation = getExperimentGroupsNames(experiment);
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
        try
          obj.subset = [0 round(experiment.totalTime)];
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        warning('off', 'MATLAB:load:variableNotFound');
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames', 'totalTime');
        warning('on', 'MATLAB:load:variableNotFound');
        pops = getExperimentGroupsNames(exp);
        if(~isempty(pops))
          obj.subpopulation = pops;
        end
        try
          obj.subset = [0 round(exp.totalTime)];
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
