classdef plotStatisticsTreatment < handle
  % Main class to plot any one-dimensional statistic for a treatment. Taking into account projects, experiments, labels, groups, etc
  %
  %   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

  
  properties
    figureHandle;
    axisHandle;
    fullStatisticsData;
    fullStatisticsDataPre;
    fullStatisticsDataPost;
    statisticsName;
    labelList;
    mainGroup;
    mode;
    params; % Set at init
    guiHandle; % Set at init
    figName;
    figVisible;
    groupList;
    plotHandles;
    maxGroups;
    experiementNames;
    groupLabels;
    fullGroupList;
    exportFolder;
    figFolder;
    Ntreatments;
    treatmentNames;
    loadFields;
  end
  
  methods
    % Use this function to setup the statistics data
    %----------------------------------------------------------------------
    function success = getData(obj, funcHandle, projexp, varargin)
      success = false;
      if(isempty(obj.params.styleOptions.figureTitle))
        obj.figName = [obj.params.statistic ' - ' projexp.name obj.params.saveOptions.saveFigureTag];
      else
        obj.figName = obj.params.styleOptions.figureTitle;
      end
      switch obj.mode
        case 'project'
          success = getDataProject(obj, funcHandle, projexp, varargin{:});
        case 'experiment'
          success = getDataExperiment(obj, funcHandle, projexp, varargin{:});
      end
    end
    
    %----------------------------------------------------------------------
    function success = getDataExperiment(obj, funcHandle, experiment, varargin)
      success = true;
      obj.fullStatisticsData = {};
      
      % Get ALL subgroups in case of parents
      if(strcmpi(obj.mainGroup, 'all') || strcmpi(obj.mainGroup, 'ask'))
        obj.groupList = getExperimentGroupsNames(experiment);
      else
        obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
      end
      % If ask, open the popup
      if(strcmpi(obj.mainGroup, 'ask'))
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', obj.groupList, 'SelectionMode', 'multiple');
        if(~ok)
          success = false;
          return;
        end
        obj.groupList = obj.groupList(selection);
      end
      for git = 1:length(obj.groupList)
        % Again, for compatibility reasons
        if(strcmpi(obj.groupList{git}, 'none'))
          obj.groupList{git} = 'everything';
        end
        % Here is where we obtain the data
        obj.fullStatisticsData{git} = feval(funcHandle, experiment, obj.groupList{git}, varargin{:});

        % Eliminate NaNs
        if(obj.params.zeroToNan)
          obj.fullStatisticsData{git} = obj.fullStatisticsData{git}(~isnan(obj.fullStatisticsData{git}));
        end
        if(isempty(obj.fullStatisticsData))
          logMsg(sprintf('Found no data for group %s on experiment %s', obj.groupList{git}, experiment.name), obj.gui, 'w');
          continue;
        end
      end
    end
    
    %----------------------------------------------------------------------
    function success = getDataProject(obj, funcHandle, project, varargin)
      success = true;
      obj.fullStatisticsData = {};
      obj.fullStatisticsDataPre = {};
      obj.fullStatisticsDataPost = {};
      checkedExperiments = find(project.checkedExperiments);
      
      plotData = cell(length(checkedExperiments), 1);
      plotDataMembers = cell(length(checkedExperiments), 1);
      if(obj.params.pbar > 0)
        ncbar.setBarName('Gathering data');
      end

      obj.Ntreatments = length(obj.params.treatmentLabels);
      % Check that the number of experiments is right
      if(rem(length(checkedExperiments), obj.Ntreatments))
        logMsg('The number of checked experiments has to be a multiple of the number of treatments', 'e');
        success = false;
        return;
      end
      %obj.params.experimentGroupOrder
      obj.maxGroups = 0;
      %%% First pass to gather all groups names and treatment groups
      for i = 1:length(checkedExperiments)
        experimentName = project.experiments{checkedExperiments(i)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = load(experimentFile, '-mat', 'traceGroups', 'traceGroupsNames');
        % Get ALL subgroups in case of parents
        if(strcmpi(obj.mainGroup, 'all') || strcmpi(obj.mainGroup, 'ask'))
          obj.groupList = getExperimentGroupsNames(experiment);
        else
          obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
        end
        obj.fullGroupList = unique([obj.fullGroupList(:); obj.groupList(:)]);
      end
      
      % If ask, open the popup
      if(strcmpi(obj.mainGroup, 'ask'))
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', obj.fullGroupList, 'SelectionMode', 'multiple');
        if(~ok)
          success = false;
          return;
        end
        obj.fullGroupList = obj.fullGroupList(selection);
      end
      %%% Gather the data
      for i = 1:length(checkedExperiments)
        experimentName = project.experiments{checkedExperiments(i)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        %experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
        if(~isempty(obj.params.loadFields))
          warning('off', 'MATLAB:load:variableNotFound');
          experiment = load(experimentFile, '-mat', 'traceGroups', 'traceGroupsNames', 'name', 'folder', 'ROI', obj.params.loadFields{:});
          warning('on', 'MATLAB:load:variableNotFound');
        else
          experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
        end
        % Get ALL subgroups in case of parents
        if(strcmpi(obj.mainGroup, 'all')  || strcmpi(obj.mainGroup, 'ask'))
          obj.groupList = getExperimentGroupsNames(experiment);
        else
          obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
        end
        plotData{i} = cell(length(obj.fullGroupList), 1);
        plotDataMembers{i} = cell(length(obj.fullGroupList), 1);
        for git = 1:length(obj.groupList)
          groupIdx = find(strcmp(obj.groupList{git}, obj.fullGroupList));
          if(isempty(groupIdx))
            continue;
          end
          % Again, for compatibility reasons
          if(strcmpi(obj.groupList{git}, 'none'))
            obj.groupList{git} = 'everything';
          end
          %plotData{i}{git} = getData(experiment, obj.groupList{git}, obj.params.statistic);
          plotData{i}{groupIdx} = feval(funcHandle, experiment, obj.groupList{git}, varargin{:});
          plotDataMembers{i}{groupIdx} = getExperimentGroupMembers(experiment, obj.groupList{git});
          if(obj.params.zeroToNan)
            plotData{i}{groupIdx}(plotData{i}{groupIdx} == 0) = NaN;
          end
        end
        obj.maxGroups = max(obj.maxGroups, length(plotData{i}));
        if(obj.params.pbar > 0)
          ncbar.update(i/length(checkedExperiments));
        end
      end
      
      %%% Get the labels we need
      %[labelList, uniqueLabels, labelsCombinations, labelsCombinationsNames, experimentsPerCombinedLabel] = getLabelList(project, find(project.checkedExperiments));
      labelsToUse = obj.params.pipelineProject.labelGroups;
      partLabels = {labelsToUse{:}, obj.params.treatmentLabels{:}};
      [labelList, uniqueLabels, labelsCombinations, labelsCombinationsNames, experimentsPerCombinedLabel] = getLabelList(project, find(project.checkedExperiments), partLabels);
      labelsToUseJoined = cell(length(labelsToUse), 1);
      try
        if(isempty([obj.params.pipelineProject.labelGroups{:}]))
          emptyLabels = true;
          labelsToUseJoined = uniqueLabels;
        else
          for it = 1:length(obj.params.pipelineProject.labelGroups)
            labelsToUseJoined{it} = strjoin(sort(strtrim(strsplit(obj.params.pipelineProject.labelGroups{it}, ','))), ', ');
          end
        end
      catch
        emptyLabels = true;
        labelsToUseJoined = uniqueLabels;
      end
      validCombinations = cellfun(@(x)find(strcmp(labelsCombinationsNames, x)), labelsToUseJoined, 'UniformOutput', false);
      valid = find(cellfun(@(x)~isempty(x), validCombinations));
      if(length(valid) ~= length(validCombinations))
        logMsg('Some label sets had no representative experiments', 'w');
      end
      validCombinations = cell2mat(validCombinations(valid));
      labelsToUseJoined = labelsToUseJoined(valid);

      validCombinationsTreatment = cellfun(@(x)find(strcmp(labelsCombinationsNames, x)), obj.params.treatmentLabels, 'UniformOutput', false);
      valid = find(cellfun(@(x)~isempty(x), validCombinationsTreatment));

      if(length(valid) ~= length(validCombinationsTreatment))
        logMsg('Some treatment label sets had no representative experiments', 'w');
      end
      validCombinationsTreatment = cell2mat(validCombinationsTreatment(valid));
      labelsToUseJoinedTreatment = obj.params.treatmentLabels(valid);
      
      experimentsPerTreatment = cell(obj.Ntreatments, 1);
      
      for it = 1:length(validCombinationsTreatment)
        experimentsPerTreatment{it} = [experimentsPerCombinedLabel{validCombinationsTreatment(it)}{:}];
      end
      experimentsPerTreatmentLabelList = cell(length(experimentsPerTreatment{1}), 1);

      for it = 1:length(experimentsPerTreatmentLabelList)
        for it2 = 1:length(validCombinations)
          valid = [experimentsPerCombinedLabel{validCombinations(it2)}{:}];
          if(any(valid == experimentsPerTreatment{1}(it)))
            experimentsPerTreatmentLabelList{it} = labelsCombinationsNames{validCombinations(it2)};
          end
        end
      end
      % This is such a mess
      %%% Here we have the full index experiment list on each treatment and the associated main labels
      %experimentsPerTreatment{treatmentIdx}
      %experimentsPerTreatmentLabelList
      %success = false;
      %return;
      %valid = find(cellfun(@(x)~isempty(x),experimentsPerTreatmentLabelList));
      %experimentsPerTreatmentLabelList = experimentsPerTreatmentLabelList(valid);
      
      logMsg('We will compare the following experiments:', 'w');
      
      plotDataTreatment = cell(length(experimentsPerTreatmentLabelList), 1);
      plotDataTreatmentPre = cell(length(experimentsPerTreatmentLabelList), 1);
      plotDataTreatmentPost = cell(length(experimentsPerTreatmentLabelList), 1);
      
      obj.treatmentNames = {};
      for it2 = 1:(obj.Ntreatments-1)
        obj.treatmentNames{it2} = sprintf('From %s to %s', obj.params.treatmentLabels{it2}, obj.params.treatmentLabels{it2+1});
      end
      if(obj.Ntreatments > 2 && obj.params.compareExtremes)
        obj.treatmentNames{end+1} = sprintf('From %s to %s', obj.params.treatmentLabels{1}, obj.params.treatmentLabels{end});
      end
      
      plotDataTreatmentExperimentAverage = cell(length(validCombinations), 1);
      plotDataTreatmentROIaverage = cell(length(validCombinations), 1);

      for lit = 1:length(validCombinations)
        plotDataTreatmentExperimentAverage{lit} = cell(obj.maxGroups, 1);
        plotDataTreatmentROIaverage{lit} = cell(obj.maxGroups, 1);
        for git = 1:obj.maxGroups
          plotDataTreatmentExperimentAverage{lit}{git} = cell(length(obj.treatmentNames), 1);
          plotDataTreatmentROIaverage{lit}{git} = cell(length(obj.treatmentNames), 1);
          for it2 = 1:(obj.Ntreatments-1)
            plotDataTreatmentExperimentAverage{lit}{git}{it2} = [];
            plotDataTreatmentROIaverage{lit}{git}{it2} = [];
          end
        end
      end
      plotDataTreatmentExperimentAveragePre = plotDataTreatmentExperimentAverage;
      plotDataTreatmentExperimentAveragePost = plotDataTreatmentExperimentAverage;
      plotDataTreatmentROIaveragePre = plotDataTreatmentROIaverage;
      plotDataTreatmentROIaveragePost = plotDataTreatmentROIaverage;

      for it = 1:length(experimentsPerTreatment{1})
        for it2 = 1:(obj.Ntreatments-1)
          preIdx = find(checkedExperiments == experimentsPerTreatment{it2}(it));
          postIdx = find(checkedExperiments == experimentsPerTreatment{it2+1}(it));
          % Get the appropiate label
          curCombination = [];
          for k = 1:length(validCombinations)
            valid = [experimentsPerCombinedLabel{validCombinations(k)}{:}];
            if(any(valid == checkedExperiments(preIdx)))
              curCombination = k;
              break;
            end
          end
          % Ok, curCombination is where this experiment should go
%          [checkedExperiments(preIdx) curCombination]
          if(isempty(experimentsPerTreatmentLabelList{it}))
            continue;
          end
          logMsg(sprintf('%s and %s with main label %s', project.experiments{checkedExperiments(preIdx)}, project.experiments{checkedExperiments(postIdx)}, experimentsPerTreatmentLabelList{it}));
          for git = 1:length(plotData{preIdx})
            switch obj.params.comparisonType
              case 'Ttest2'
                [~, plotDataTreatment{it}{git}{it2}] = ttest2(plotData{postIdx}{git}(:), plotData{preIdx}{git}(:));
                plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(:);
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(:);
              case 'Mann-Whitney'
                plotDataTreatment{it}{git}{it2} = ranksum(plotData{postIdx}{git}(:), plotData{preIdx}{git}(:));
                plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(:);
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(:);
              case 'Kolmogorov-Smirnov'
                [~, plotDataTreatment{it}{git}{it2}] = kstest2(plotData{postIdx}{git}(:), plotData{preIdx}{git}(:));
                plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(:);
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(:);
              case 'difference'
                if(obj.params.averageDataFirst.enable)
                  switch obj.params.averageDataFirst.function
                    case 'mean'
                      plotDataTreatment{it}{git}{it2} = nanmean(plotData{postIdx}{git}(:))-nanmean(plotData{preIdx}{git}(:));
                      plotDataTreatmentPre{it}{git}{it2} = nanmean(plotData{preIdx}{git}(:));
                      plotDataTreatmentPost{it}{git}{it2} = nanmean(plotData{postIdx}{git}(:));
                    case 'median'
                      plotDataTreatment{it}{git}{it2} = nanmedian(plotData{postIdx}{git}(:))-nanmedian(plotData{preIdx}{git}(:));
                      plotDataTreatmentPre{it}{git}{it2} = nanmedian(plotData{preIdx}{git}(:));
                      plotDataTreatmentPost{it}{git}{it2} = nanmedian(plotData{postIdx}{git}(:));
                    case 'std'
                      plotDataTreatment{it}{git}{it2} = nanstd(plotData{postIdx}{git}(:))-nanmedian(plotData{preIdx}{git}(:));
                      plotDataTreatmentPre{it}{git}{it2} = nanstd(plotData{preIdx}{git}(:));
                      plotDataTreatmentPost{it}{git}{it2} = nanstd(plotData{postIdx}{git}(:));
                    case 'rmse'
                      plotDataTreatment{it}{git}{it2} = (nanstd(plotData{postIdx}{git}(:))-nanmedian(plotData{preIdx}{git}(:)))/sqrt(mean([numel(plotData{preIdx}{git}(:)) numel(plotData{postIdx}{git}(:))]));
                      plotDataTreatmentPre{it}{git}{it2} = nanstd(plotData{preIdx}{git}(:))/sqrt(numel(plotData{preIdx}{git}(:)));
                      plotDataTreatmentPost{it}{git}{it2} = nanstd(plotData{postIdx}{git}(:))/sqrt(numel(plotData{postIdx}{git}(:)));
                  end
                else
                  if(length(plotData{postIdx}{git}) == length(plotData{preIdx}{git}))
                    plotDataTreatment{it}{git}{it2} = plotData{postIdx}{git}(:)-plotData{preIdx}{git}(:);
                    plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(:);
                    plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(:);
                  else
                    logMsg('Length of pre and post groups differ. You might have to average the data first to compare them', 'e');
                    success = false;
                    return;
                  end
                end
              case 'ratio'
                if(obj.params.averageDataFirst.enable)
                  switch obj.params.averageDataFirst.function
                    case 'mean'
                      plotDataTreatment{it}{git}{it2} = nanmean(plotData{postIdx}{git}(:))./nanmean(plotData{preIdx}{git}(:));
                      plotDataTreatmentPre{it}{git}{it2} = nanmean(plotData{preIdx}{git}(:));
                      plotDataTreatmentPost{it}{git}{it2} = nanmean(plotData{postIdx}{git}(:));
                    case 'median'
                      plotDataTreatment{it}{git}{it2} = nanmedian(plotData{postIdx}{git}(:))./nanmedian(plotData{preIdx}{git}(:));
                      plotDataTreatmentPre{it}{git}{it2} = nanmedian(plotData{preIdx}{git}(:));
                      plotDataTreatmentPost{it}{git}{it2} = nanmedian(plotData{postIdx}{git}(:));
                  end
                else
                  if(length(plotData{postIdx}{git}) == length(plotData{preIdx}{git}))
                    plotDataTreatment{it}{git}{it2} = plotData{postIdx}{git}(:)./plotData{preIdx}{git}(:);
                    plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(:);
                    plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(:);
                  else
                    logMsg('Length of pre and post groups differ. You might have to average the data first to compare them', 'e');
                    success = false;
                    return;
                  end
                end
              case 'differenceIntersect'
                [~, validMembersPre, validMembersPost] = intersect(plotDataMembers{preIdx}{git}, plotDataMembers{postIdx}{git});
                plotDataTreatment{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost)-plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost);
              case 'differencePreZero'
                [~, preZero] = setdiff(plotDataMembers{postIdx}{git}, plotDataMembers{preIdx}{git});
                [~, validMembersPre, validMembersPost] = intersect(plotDataMembers{preIdx}{git}, plotDataMembers{postIdx}{git});
                plotDataTreatment{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost)-plotData{preIdx}{git}(validMembersPre);
                [plotDataTreatment{it}{git}{it2}; plotData{postIdx}{git}(preZero)];
                plotDataTreatmentPre{it}{git}{it2} = [plotData{preIdx}{git}(validMembersPre); zeros(size(preZero))];
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git};
              case 'decreaseIntersect'
                [~, validMembersPre, validMembersPost] = intersect(plotDataMembers{preIdx}{git}, plotDataMembers{postIdx}{git});
                plotDataTreatment{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost)<plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost);
              case 'increaseIntersect'
                [~, validMembersPre, validMembersPost] = intersect(plotDataMembers{preIdx}{git}, plotDataMembers{postIdx}{git});
                plotDataTreatment{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost)>plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost);
              case 'ratioIntersect'
                [~, validMembersPre, validMembersPost] = intersect(plotDataMembers{preIdx}{git}, plotDataMembers{postIdx}{git});
                plotDataTreatment{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost)./plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPre{it}{git}{it2} = plotData{preIdx}{git}(validMembersPre);
                plotDataTreatmentPost{it}{git}{it2} = plotData{postIdx}{git}(validMembersPost);
            end
            switch obj.params.pipelineProject.factorAverageFunction
              case 'mean'
                plotDataTreatmentExperimentAverage{curCombination}{git}{it2} = [plotDataTreatmentExperimentAverage{curCombination}{git}{it2}; nanmean(plotDataTreatment{it}{git}{it2})];
                plotDataTreatmentExperimentAveragePre{curCombination}{git}{it2} = [plotDataTreatmentExperimentAveragePre{curCombination}{git}{it2}; nanmean(plotDataTreatmentPre{it}{git}{it2})];
                plotDataTreatmentExperimentAveragePost{curCombination}{git}{it2} = [plotDataTreatmentExperimentAveragePost{curCombination}{git}{it2}; nanmean(plotDataTreatmentPost{it}{git}{it2})];
              case 'median'
                plotDataTreatmentExperimentAverage{curCombination}{git}{it2} = [plotDataTreatmentExperimentAverage{curCombination}{git}{it2}; nanmedian(plotDataTreatment{it}{git}{it2})];
                plotDataTreatmentExperimentAveragePre{curCombination}{git}{it2} = [plotDataTreatmentExperimentAveragePre{curCombination}{git}{it2}; nanmedian(plotDataTreatmentPre{it}{git}{it2})];
                plotDataTreatmentExperimentAveragePost{curCombination}{git}{it2} = [plotDataTreatmentExperimentAveragePost{curCombination}{git}{it2}; nanmedian(plotDataTreatmentPost{it}{git}{it2})];
            end
            plotDataTreatmentROIaverage{curCombination}{git}{it2} = [plotDataTreatmentROIaverage{curCombination}{git}{it2}; plotDataTreatment{it}{git}{it2}];
            plotDataTreatmentROIaveragePre{curCombination}{git}{it2} = [plotDataTreatmentROIaveragePre{curCombination}{git}{it2}; plotDataTreatmentPre{it}{git}{it2}];
            plotDataTreatmentROIaveragePost{curCombination}{git}{it2} = [plotDataTreatmentROIaveragePost{curCombination}{git}{it2}; plotDataTreatmentPost{it}{git}{it2}];
          end
        end
        %%% TODO
        if(obj.Ntreatments > 2 && obj.params.compareExtremes)
          preIdx = find(checkedExperiments == experimentsPerTreatment{1}(it));
          postIdx = find(checkedExperiments == experimentsPerTreatment{end}(it));
          logMsg(sprintf('%s and %s with main label %s', project.experiments{checkedExperiments(preIdx)}, project.experiments{checkedExperiments(postIdx)}, experimentsPerTreatmentLabelList{it}));
          for git = 1:length(plotData{preIdx})
            switch obj.params.comparisonType
              case 'difference'
                if(obj.params.averageDataFirst)
                  plotDataTreatment{it}{git}{it2+1} = nanmean(plotData{postIdx}{git}(:))-nanmean(plotData{preIdx}{git}(:));
                else
                  plotDataTreatment{it}{git}{it2+1} = plotData{postIdx}{git}(:)-plotData{preIdx}{git}(:);
                end
              case 'ratio'
                if(obj.params.averageDataFirst)
                  plotDataTreatment{it}{git}{it2+1} = nanmean(plotData{postIdx}{git}(:))./nanmean(plotData{preIdx}{git}(:));
                else
                  plotDataTreatment{it}{git}{it2+1} = plotData{postIdx}{git}(:)/plotData{preIdx}{git}(:);
                end
            end
            switch obj.params.pipelineProject.factorAverageFunction
              case 'mean'
                plotDataTreatmentExperimentAverage{curCombination}{git}{it2+1} = [plotDataTreatmentExperimentAverage{curCombination}{git}{it2+1}; nanmean(plotDataTreatment{it}{git}{it2+1})];
              case 'median'
                plotDataTreatmentExperimentAverage{curCombination}{git}{it2+1} = [plotDataTreatmentExperimentAverage{curCombination}{git}{it2+1}; nanmedian(plotDataTreatment{it}{git}{it2+1})];
            end
            plotDataTreatmentROIaverage{curCombination}{git}{it2+1} = [plotDataTreatmentROIaverage{curCombination}{git}{it2+1}; plotDataTreatment{it}{git}{it2+1}];
          end
        end
      end
      
      switch obj.params.pipelineProject.groupingOrder
        case 'none'
          % Do nothing
          obj.groupLabels = project.experiments(checkedExperiments(arrayfun(@(x) find(x == checkedExperiments), experimentsPerTreatment{1}, 'UniformOutput', true)));
        case 'label average'
          % Average statistics for each experiment, and group them by label
          switch obj.params.pipelineProject.factor
            case 'experiment'
              plotDataTreatment = plotDataTreatmentExperimentAverage;
              plotDataTreatmentPre = plotDataTreatmentExperimentAveragePre;
              plotDataTreatmentPost = plotDataTreatmentExperimentAveragePost;
            case 'ROI'
              plotDataTreatment = plotDataTreatmentROIaverage;
              plotDataTreatmentPre = plotDataTreatmentROIaveragePre;
              plotDataTreatmentPost = plotDataTreatmentROIaveragePost;
          end
          obj.groupLabels = labelsToUseJoined;
      end
      obj.fullStatisticsData = plotDataTreatment;
      obj.fullStatisticsDataPre = plotDataTreatmentPre;
      obj.fullStatisticsDataPost = plotDataTreatmentPost;
    end
    
    %----------------------------------------------------------------------
    function createFigure(obj)
      switch obj.mode
        case 'experiment'
          obj.createFigureExperiment();
        case 'project'
          obj.createFigureProject();
      end
    end
    
    %----------------------------------------------------------------------
    function createFigureExperiment(obj)
      obj.plotHandles = [];
      
      if(obj.params.saveOptions.onlySaveFigure)
        obj.figVisible = 'off';
      else
        obj.figVisible = 'on';
      end
      obj.figureHandle = figure('Name', obj.figName, 'NumberTitle', 'off', 'Visible', obj.figVisible, 'Tag', 'netcalPlot');
      obj.figureHandle.Position = setFigurePosition(obj.guiHandle, 'width', obj.params.styleOptions.figureSize(1), 'height', obj.params.styleOptions.figureSize(2));
      obj.axisHandle = axes;
      hold on;
      if(isempty(obj.params.styleOptions.xLabel))
        xlabel(obj.params.statistic);
      else
        xlabel(obj.params.styleOptions.xLabel);
      end
      if(isempty(obj.params.styleOptions.yLabel))
        ylabel('PDF');
      else
        ylabel(obj.params.styleOptions.yLabel);
      end
      if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
        cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, length(obj.groupList)));
      else
        cmap = lines(length(obj.groupList));
      end
      if(obj.params.styleOptions.invertColormap)
        if(size(cmap, 1) == 1)
          % If the colormap has a single entry we need to add another entry
          if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
            cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, length(obj.groupList)+1));
          else
            cmap = lines(length(obj.groupList)+1);
          end
          cmap = cmap(end:-1:1, :);
        else
          % Default behavior
          cmap = cmap(end:-1:1, :);
        end
      end
      if(length(obj.groupList) > 1)
        alpha = 0.5;
      else
        alpha = 1;
      end
      validGroups = [];
      for git = 1:length(obj.groupList)
        curData = obj.fullStatisticsData{git};
        if(isempty(curData))
          logMsg(sprintf('No data found for group: %s', obj.groupList{git}), obj.guiHandle, 'w');
          continue;
        else
          validGroups = [validGroups, git];
        end
        switch obj.params.pipelineExperiment.distributionEstimation
          case 'unbounded'
            [f, xi] = ksdensity(curData);
             h = plot(xi, f, 'Color', cmap(git, :));
          case 'positive'
            [f, xi] = ksdensity(curData, 'support', 'positive');
            h = plot(xi, f, 'Color', cmap(git, :));
          case 'histogram'
            if(isempty(obj.params.pipelineExperiment.distributionBins) || (~ischar(obj.params.pipelineExperiment.distributionBins) && obj.params.pipelineExperiment.distributionBins == 0))
              try
                bins = sshist(curData);
              catch
                bins = 10;
              end
            elseif(ischar(obj.params.pipelineExperiment.distributionBins))
              bins = eval(obj.params.pipelineExperiment.distributionBins);
              if(bins == 0)
                try
                  bins = sshist(curData);
                catch
                  bins = 10;
                end
              end
            else
              bins = obj.params.pipelineExperiment.distributionBins;
            end
            
            [f, xi] = hist(curData, bins);
            % Now normalize the histogram
            area = trapz(xi, f);
            f = f/area;
            h = bar(xi, f/area, 'FaceColor', cmap(git, :), 'EdgeColor', cmap(git, :)*0.5, 'FaceAlpha', alpha, 'EdgeAlpha', alpha);
          case 'raw'
            if(isempty(obj.params.pipelineExperiment.distributionBins) || (~ischar(obj.params.pipelineExperiment.distributionBins) && obj.params.pipelineExperiment.distributionBins == 0))
              try
                bins = sshist(curData);
              catch
                bins = 10;
              end
            elseif(ischar(obj.params.pipelineExperiment.distributionBins))
              bins = eval(obj.params.pipelineExperiment.distributionBins);
              if(bins == 0)
                try
                  bins = sshist(curData);
                catch
                  bins = 10;
                end
              end
            else
              bins = obj.params.pipelineExperiment.distributionBins;
            end
            [f, xi] = hist(curData, bins);
            h = bar(xi, f, 'FaceColor', cmap(git, :), 'EdgeColor', cmap(git, :)*0.5, 'FaceAlpha', alpha, 'EdgeAlpha', alpha);
            if(isempty(obj.params.styleOptions.yLabel))
              ylabel('count');
            else
              ylabel(obj.params.styleOptions.yLabel);
            end
        end
        obj.plotHandles = [obj.plotHandles; h];
      end
      legend(obj.groupList(validGroups))
      title(obj.axisHandle, obj.figName);
      set(obj.axisHandle, 'XTickLabelRotation', obj.params.styleOptions.XTickLabelRotation);
      set(obj.axisHandle, 'YTickLabelRotation', obj.params.styleOptions.YTickLabelRotation);
      box on;
      set(obj.axisHandle,'Color','w');
      set(obj.figureHandle,'Color','w');
      ui = uimenu(obj.figureHandle, 'Label', 'Export');
      uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, strrep([obj.figFolder, obj.figName], ' - ', '_'), obj.params.saveOptions.saveFigureResolution});
      
      if(obj.params.saveOptions.saveFigure)
        export_fig([obj.figFolder, obj.figName, '.', obj.params.saveOptions.saveFigureType], ...
                    sprintf('-r%d', obj.params.saveOptions.saveFigureResolution), ...
                    sprintf('-q%d', obj.params.saveOptions.saveFigureQuality), obj.figureHandle);
      end
    end
    
    %----------------------------------------------------------------------
    function createFigureProject(obj)
      curData = obj.fullStatisticsData;
      if(obj.params.saveOptions.onlySaveFigure)
        obj.figVisible = 'off';
      else
        obj.figVisible = 'on';
      end
      
      if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
        cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, length(obj.fullGroupList)));
      else
        cmap = lines(length(obj.fullGroupList));
      end
      if(obj.params.styleOptions.invertColormap)
        if(size(cmap, 1) == 1)
          % If the colormap has a single entry we need to add another entry
          if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
            cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, 2));
          else
            cmap = lines(2);
          end
          cmap = cmap(2, :);
        else
          % Default behavior
          cmap = cmap(end:-1:1, :);
        end
      end
      
      maxReplicas = 0;
      for it1 = 1:length(curData)
        for it2 = 1:length(curData{it1})
          for it3 = 1:length(curData{it1}{it2})
            maxReplicas = max(maxReplicas, length(curData{it1}{it2}{it3}));
          end
        end
      end
      % curData = plotDataTreatment : {experimentPair}{group}{treatment comparison}
      %replicas = plotDataTreatment{it}{git}{it2}
      %length(curData), curData{1}, obj.Ntreatments
      if(maxReplicas == 1)
        maxReplicas = 2;
      end
      
      if(obj.Ntreatments > 2 && obj.params.compareExtremes)
        bpData = nan(maxReplicas, length(curData), obj.maxGroups, obj.Ntreatments);
      else
        bpData = nan(maxReplicas, length(curData), obj.maxGroups, obj.Ntreatments-1);
      end
      bpDataPre = bpData;
      bpDataPost = bpData;
      
      for it1 = 1:length(curData)
        for it2 = 1:length(curData{it1})
          for it3 = 1:length(curData{it1}{it2})
            bpData(1:length(curData{it1}{it2}{it3}), it1, it2, it3) = curData{it1}{it2}{it3};
            bpDataPre(1:length(curData{it1}{it2}{it3}), it1, it2, it3) = obj.fullStatisticsDataPre{it1}{it2}{it3};
            bpDataPost(1:length(curData{it1}{it2}{it3}), it1, it2, it3) = obj.fullStatisticsDataPost{it1}{it2}{it3};
          end
        end
      end

      import iosr.statistics.*
      % Let's do 1 plot per treatment instead
      for fIdx = 1:size(bpData, 4)
        subData = bpData(:, :, :, fIdx);
        
        switch obj.params.pipelineProject.barGroupingOrder
          case 'default'
            subData = permute(subData,[1 2 3]);
            xList = obj.groupLabels;
            legendList = obj.fullGroupList;
            if(~iscell(legendList) || (iscell(legendList) && length(legendList) == 1))
              legendList = {legendList};
            end
          case 'group'
            subData = permute(subData,[1 2 3]);
            legendList = obj.groupLabels;
            xList = obj.fullGroupList;
        end
        if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
          cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, length(legendList)));
        else
          cmap = lines(length(legendList));
        end
        if(obj.params.styleOptions.invertColormap)
          if(size(cmap, 1) == 1)
            % If the colormap has a single entry we need to add another entry
            if(isfield(obj.params.styleOptions, 'colormap') && ~isempty(obj.params.styleOptions.colormap))
              cmap = eval(sprintf('%s (%d)', obj.params.styleOptions.colormap, 2));
            else
              cmap = lines(2);
            end
            cmap = cmap(2, :);
          else
            % Default behavior
            cmap = cmap(end:-1:1, :);
          end
        end
        
        obj.figureHandle = figure('Name', sprintf('%s - %d', obj.figName, fIdx), 'NumberTitle', 'off', 'Visible', obj.figVisible, 'Tag', 'netcalPlot');
        obj.figureHandle.Position = setFigurePosition(obj.guiHandle, 'width', obj.params.styleOptions.figureSize(1), 'height', obj.params.styleOptions.figureSize(2));
        obj.axisHandle = axes;
        hold on;
%         grList = {};
%         pList = [];
%         %%% HACK
% 
%         switch obj.params.pipelineProject.showSignificance
%           case 'none'
%           case 'partial'
%             for it = 1:size(subData, 2)
%               for itt = 1:size(subData, 2)
%                 if(it > itt)
%                   try
%                     p = ranksum(subData(:, it), subData(:, itt));
%                     [h, p2] = kstest2(subData(:, it), subData(:, itt));
%                     logMsg(sprintf('%s vs %s . Mann-Whitney U test P= %.3g - Kolmogorov-Smirnov test P= %.3g', xList{it}, xList{itt}, p, p2));
%                     switch obj.params.pipelineProject.significanceTest
%                       case 'Mann-Whitney'
%                         if(p <= 0.05)
%                           pList = [pList; p];
%                           grList{end+1} = [it itt];
%                         end
%                       case 'Kolmogorov-Smirnov'
%                         if(p <= 0.05)
%                           pList = [pList; p2];
%                           grList{end+1} = [it itt];
%                         end
%                     end
%                   catch ME
%                     logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'w');
%                   end
%                 end
%               end
%             end
%           case 'all'
%             for it = 1:size(subData, 2)
%               for itt = 1:size(subData, 2)
%                 if(it > itt)
%                   p = ranksum(subData(:, it), subData(:, itt));
%                   [h, p2] = kstest2(subData(:, it), subData(:, itt));
%                   logMsg(sprintf('%s vs %s . Mann-Whitney U test P= %.3g - Kolmogorov-Smirnov test P= %.3g', xList{it}, xList{itt}, p, p2));
%                   switch obj.params.pipelineProject.significanceTest
%                     case 'Mann-Whitney'
%                       pList = [pList; p];
%                       grList{end+1} = [it itt];
%                     case 'Kolmogorov-Smirnov'
%                       pList = [pList; p2];
%                       grList{end+1} = [it itt];
%                   end
%                   grList{end+1} = [it itt];
%                 end
%               end
%             end
%         end

        switch obj.params.pipelineProject.showSignificance
          case 'none'
            obj.fullGroupList = {obj.fullGroupList};
          otherwise
            obj.fullGroupList = {obj.fullGroupList};
            grList = cell(length(obj.fullGroupList{1}), 1);
            pList = cell(length(obj.fullGroupList{1}), 1);
            intraPlist = cell(length(obj.fullGroupList{1}), 1);
            intraGrList = cell(length(obj.fullGroupList{1}), 1);
            nTests = cell(length(obj.fullGroupList{1}), 1);
            switch obj.params.pipelineProject.factor
              case 'mixed'
%                 for git = 1:length(obj.fullStatisticsDataFull{1})
%                   grList{git} = {};
%                   intraGrList{git} = {};
%                   nTests{git} = 0;
%                 end
              otherwise
                for git = 1:size(subData, 3)
                  grList{git} = {};
                  intraGrList{git} = {};
                  nTests{git} = 0;
                end
            end
        end
        switch obj.params.pipelineProject.factor
          case 'mixed'
          otherwise
            switch obj.params.pipelineProject.showSignificance
              case 'none'
              case 'partial'
                for it = 1:size(subData, 2)
                  for itt = (it+1):size(subData, 2)
                    for git = 1:size(subData, 3)
                      if(obj.params.pipelineProject.avoidCrossComparisons)
                        if(~any(cellfun(@(x)any(strcmp(x, strtrim(strsplit(xList{itt}, ',')))), strtrim(strsplit(xList{it}, ',')))))
                          continue;
                        else
                          nTests{git} = nTests{git} + 1;
                        end
                      else
                        nTests{git} = nTests{git} + 1;
                      end
                      try
                        p = ranksum(subData(:, it, git), subData(:, itt, git));
                        [h, p2] = kstest2(subData(:, it, git), subData(:, itt, git));
                        [h, p3] = ttest2(subData(:, it, git), subData(:, itt, git));
                        logMsg(sprintf('%s vs %s . Group: %s . Mann-Whitney U test P= %.3g - Kolmogorov-Smirnov test P= %.3g - Ttest2 P=%.3g', xList{it}, xList{itt}, obj.fullGroupList{1}{git}, p, p2, p3));
                        switch obj.params.pipelineProject.significanceTest
                          case 'Mann-Whitney'
                            if(p <= 0.05)
                              pList{git} = [pList{git}; p];
                              grList{git}{end+1} = [it itt];
                            end
                          case 'Kolmogorov-Smirnov'
                            if(p2 <= 0.05)
                              pList{git} = [pList{git}; p2];
                              grList{git}{end+1} = [it itt];
                            end
                          case 'Ttest2'
                            if(p3 <= 0.05)
                              pList{git} = [pList{git}; p3];
                              grList{git}{end+1} = [it itt];
                            end
                        end
                      catch ME
                        logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'w');
                      end
                    end
                  end
                end
              case 'all'
                for it = 1:size(subData, 2)
                  for itt = 1:size(subData, 2)
                    for git = 1:size(subData, 3)
                      if(it > itt)
                        p = ranksum(subData(:, it, git), subData(:, itt, git));
                        [h, p2] = kstest2(subData(:, it, git), subData(:, itt, git));
                        [h, p3] = ttest2(subData(:, it, git), subData(:, itt, git));
                        logMsg(sprintf('%s vs %s . Group: %s . Mann-Whitney U test P= %.3g - Kolmogorov-Smirnov test P= %.3g - Ttest2 P=%.3g', xList{it}, xList{itt}, obj.fullGroupList{1}{git}, p, p2, p3));
                        switch obj.params.pipelineProject.significanceTest
                          case 'Mann-Whitney'
                            pList{git} = [pList{git}; p];
                            grList{git}{end+1} = [it itt];
                          case 'Kolmogorov-Smirnov'
                            pList{git} = [pList{git}; p2];
                            grList{git}{end+1} = [it itt];
                          case 'Ttest2'
                            pList{git} = [pList{git}; p3];
                            grList{git}{end+1} = [it itt];
                        end
                        %grList{git}{end+1} = [it itt]; WHY WAS THIS HERE??
                      end
                    end
                  end
                end
            end
        end
        % Holm-Bonferroni
        if(obj.params.pipelineProject.HolmBonferroniCorrection)
          switch obj.params.pipelineProject.showSignificance
            case {'partial', 'all'}
              for git = 1:length(nTests)
                Ncomparisons = nTests{git};
                if(isempty(Ncomparisons) || Ncomparisons == 0 || isempty(pList{git}))
                  logMsg(sprintf('No significant data found for Holm-Bonferroni correction on group: %s', obj.fullGroupList{1}{git}));
                  continue;
                end
                fullList = [pList{git}, cellfun(@(x)x(1), grList{git})', cellfun(@(x)x(2), grList{git})'];
                [fullList, idx] = sortrows(fullList, 1);
                validComparisons = 0;
                for it = 1:size(fullList, 1)
                  if(fullList(it, 1) >= 0.05/(Ncomparisons-it+1))
                    break;
                  else
                    validComparisons = validComparisons + 1;
                  end
                end
                pList{git} = pList{git}(idx(1:validComparisons));
                grList{git} = grList{git}(idx(1:validComparisons));
                logMsg('Valid comparisons after Holm-Bonferroni correction:');
                for it = 1:length(pList{git})
                  logMsg(sprintf('%s vs %s . Group: %s . P= %.3g', xList{grList{git}{it}(1)}, xList{grList{git}{it}(2)}, obj.fullGroupList{1}{git}, pList{git}(it)));
                end
              end
          end
        end

        setappdata(gcf, 'subData', subData);
        try
          obj.plotHandles = boxPlot(xList, subData, ...
                            'symbolColor','k',...
                            'medianColor','k',...
                            'symbolMarker','+',...
                            'groupLabels', legendList, ...
                            'showLegend',true, ...
                            'showOutliers', false, ...
                            'boxcolor', cmap, ...
                            'notch', obj.params.styleOptions.notch);
        catch
          obj.plotHandles = [];
        end
        if(obj.params.pipelineProject.showMeanError)
          try
            obj.plotHandles.showMean = true;
            obj.plotHandles.meanColor = [1 0 0];
            boxes = obj.plotHandles.handles.box;
            boxesPositions = arrayfun(@(x)mean(x.Vertices(:,1)), boxes(:));
            xcoords = boxesPositions;
            avgy = nanmean(obj.plotHandles.y,1);
            erry = nanstd(obj.plotHandles.y,1)./sqrt(sum(~isnan(obj.plotHandles.y)));
            hold on;
            h = errorbar(xcoords, avgy, erry,'o');
            h.Color = [1 0 0];
          catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
          end
        end
        
        % Now let's fix the patches
        try
          boxes = obj.plotHandles.handles.box;
          if(all(arrayfun(@(x)length(unique(x.Vertices(:, 2))) == 1, boxes,  'UniformOutput', true) | arrayfun(@(x)all(isnan(x.Vertices(:, 2))), boxes,  'UniformOutput', true)))
            singleStatistic = true;
          else
            singleStatistic = false;
          end
          % Turn the patches into simple bars
          if(singleStatistic)
            for it = 1:numel(boxes)
              boxes(it).Vertices(1,2) = 0;
              boxes(it).Vertices(end,2) = 0;
            end
          end

          hold on;
          if(~strcmpi(obj.params.pipelineProject.showSignificance, 'none'))
            switch obj.params.pipelineProject.significanceTest
              case {'Mann-Whitney', 'Kolmogorov-Smirnov', 'Ttest2'}
                % The intragroup comparisons
                if(obj.params.pipelineProject.computeIntraGroupComparisons && strcmpi(obj.params.pipelineProject.factor, 'mixed'))
                  for git = 1:size(subData, 3)
                    if(isempty(intraPlist{git}))
                      continue;
                    end
                    boxesPositions = arrayfun(@(x)mean(x.Vertices(:,1)), boxes(1, :, git));
                    newPos = cellfun(@(x)boxesPositions(x)+[-0.01 0.01], intraGrList{git}, 'UniformOutput', false);
                    sigstar(newPos, intraPlist{git});
                  end
                end
                % The normal comparisons
                for git = 1:size(subData, 3)
                  if(isempty(pList{git}))
                    continue;
                  end
                  boxesPositions = arrayfun(@(x)mean(x.Vertices(:,1)), boxes(1, :, git));
                  newPos = cellfun(@(x)boxesPositions(x), grList{git}, 'UniformOutput', false);
                  if(numel(newPos) == 2 && numel(pList{git}) == 1)
                    newPos = newPos{1};
                  end
                  sigstar(newPos, pList{git});
                end
            end
          end

          obj.plotHandles.handles.box =  boxes;

        catch ME
          logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
        setappdata(obj.figureHandle, 'boxData', obj.plotHandles);
        if(isempty(obj.params.styleOptions.xLabel))
          else
            xlabel(obj.params.styleOptions.xLabel);
          end
          if(isempty(obj.params.styleOptions.yLabel))
            ylabel(obj.statisticsName);
          else
            ylabel(obj.params.styleOptions.yLabel);
          end
        
        title(obj.axisHandle, sprintf('%s - %s', obj.figName, obj.treatmentNames{fIdx}));
        set(obj.figureHandle,'Color','w');

        box on;
        set(obj.axisHandle, 'XTickLabelRotation', obj.params.styleOptions.XTickLabelRotation);
        set(obj.axisHandle, 'YTickLabelRotation', obj.params.styleOptions.YTickLabelRotation);
        set(obj.axisHandle,'Color','w');
        set(obj.figureHandle,'Color','w');

        ui = uimenu(obj.figureHandle, 'Label', 'Export');
        uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, strrep([obj.figFolder, obj.figName], ' - ', '_'), obj.params.saveOptions.saveFigureResolution});
        uimenu(ui, 'Label', 'To workspace',  'Callback', @exportToWorkspace);
        uimenu(ui, 'Label', 'Data (statistics)',  'Callback', @(h,e)obj.exportDataAggregates(bpData, obj.exportFolder));
        uimenu(ui, 'Label', 'Data (full)',  'Callback', @(h,e)obj.exportDataFull(bpData, bpDataPre, bpDataPost, obj.exportFolder));

        if(obj.params.saveOptions.saveFigure)
          export_fig([obj.figFolder, obj.figName, '.', obj.params.saveOptions.saveFigureType], ...
                      sprintf('-r%d', obj.params.saveOptions.saveFigureResolution), ...
                      sprintf('-q%d', obj.params.saveOptions.saveFigureQuality), obj.figureHandle);
        end
        if(obj.params.pipelineProject.automaticallyExportData)
          try
            obj.exportDataFull(bpData, bpDataPre, bpDataPost, obj.exportFolder, true)
          catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'w');
            logMsg('Could not export the file', 'e');
          end
        end
      end
      
      %--------------------------------------------------------------------
      function exportToWorkspace(~, ~)
        assignin('base', 'boxPlotData', obj.plotHandles);
        if(~isempty(obj.guiHandle))
          logMsg('boxPlotData data succesfully exported to the workspace. Modify its components to modify the figure', obj.guiHandle, 'w');
        else
          logMsg('boxPlotData data succesfully exported to the workspace. Modify its components to modify the figure', 'w');
        end
      end
    end
   
    %----------------------------------------------------------------------
    function updateFigure(obj, params)
      
    end
    
    %----------------------------------------------------------------------
    function init(obj, projexp, optionsClass, msg, varargin)
      %--------------------------------------------------------------------
      [obj.params, var] = processFunctionStartup(optionsClass, varargin{:});
      % Define additional optional argument pairs
      obj.params.pbar = [];
      obj.params.gui = [];
      obj.params.loadFields = {};
      % Parse them
      obj.params = parse_pv_pairs(obj.params, var);
      obj.params = barStartup(obj.params, msg);
      obj.params = obj.params;
      obj.guiHandle = obj.params.gui;
      %--------------------------------------------------------------------
      
      % Fix in case for some reason the group is a cell
      if(iscell(obj.params.group))
        obj.mainGroup = obj.params.group{1};
      else
        obj.mainGroup = obj.params.group;
      end

      % Check if its a project or an experiment
      if(isfield(projexp, 'saveFile'))
        [~, ~, fpc] = fileparts(projexp.saveFile);
        if(strcmpi(fpc, '.exp'))
          obj.mode = 'experiment';
          experiment = projexp;
          baseFolder = experiment.folder;
        else
          obj.mode = 'project';
          project = projexp;
          baseFolder = project.folder;
        end
      else
        obj.mode = 'project';
        project = projexp;
        baseFolder = project.folder;
      end
      
      % Consistency checks
      if(obj.params.saveOptions.onlySaveFigure)
        obj.params.saveOptions.saveFigure = true;
      end
      if(ischar(obj.params.styleOptions.figureSize))
        obj.params.styleOptions.figureSize = eval(obj.params.styleOptions.figureSize);
      end
      
      % Create necessary folders
      if(strcmpi(obj.mode, 'experiment'))
        switch obj.params.saveOptions.saveBaseFolder
          case 'experiment'
            baseFolder = experiment.folder;
          case 'project'
            baseFolder = [experiment.folder '..' filesep];
        end
      else
        baseFolder = project.folder;
      end
      if(~exist(baseFolder, 'dir'))
        mkdir(baseFolder);
      end
      obj.figFolder = [baseFolder 'figures' filesep];
      if(~exist(obj.figFolder, 'dir'))
        mkdir(obj.figFolder);
      end
      obj.exportFolder = [baseFolder 'exports' filesep];
      if(~exist(obj.exportFolder, 'dir'))
        mkdir(obj.exportFolder);
      end
    end
    
    %----------------------------------------------------------------------
    function cleanup(obj)
      if(obj.params.saveOptions.onlySaveFigure)
       close(obj.figureHandle);
      end
      %--------------------------------------------------------------------
      barCleanup(obj.params);
      %--------------------------------------------------------------------
    end
    
    %--------------------------------------------------------------------
    function exportDataAggregates(obj, bpData, baseFolder)
      [fileName, pathName] = uiputfile('.csv', 'Save data', [baseFolder obj.params.statistic '_aggregatesTreatment.csv']);
      if(fileName == 0)
        return;
      end
      fID = fopen([pathName fileName], 'w');
      names = {'label', 'group', 'median', 'mean', 'std', 'N', 'Q1', 'Q3', 'IQR', 'min', 'max'};

      data = obj.plotHandles.statistics;
      for it = 1:length(names)
        lineStr = sprintf('"%s"', names{it});
        for cit = 1:size(bpData, 3)
          for git = 1:size(bpData, 2)
            if(it == 1)
              lineStr = sprintf('%s,"%s"', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
            elseif(it == 2)
              lineStr = sprintf('%s,"%s"', lineStr, obj.fullGroupList{1}{cit});
            else
              %lineStr = sprintf('%s,%.3f', lineStr, data.(names{it})(1, cit, git));
              if(ndims(data.(names{it})) == 3)
                lineStr = sprintf('%s,%.6f', lineStr, data.(names{it})(1, git, cit));
              else
                lineStr = sprintf('%s,%.6f', lineStr, data.(names{it})(cit, git));
              end
            end
          end
        end
        lineStr = sprintf('%s\n', lineStr);
        fprintf(fID, lineStr);
      end
      fclose(fID);
    end

    %--------------------------------------------------------------------
    function exportDataFull(obj, bpData, bpDataPre, bpDataPost, baseFolder, varargin)
      if(nargin > 5)
        automatic = varargin{1};
      else
        automatic = false;
      end
      if(~automatic)
        [fileName, pathName] = uiputfile('.csv', 'Save data', [baseFolder obj.params.statistic obj.params.saveOptions.saveFigureTag '_fullTreatment.csv']);
        if(fileName == 0)
          return;
        end
      else
        pathName = baseFolder;
        fileName = [obj.params.statistic obj.params.saveOptions.saveFigureTag '_treatmentAutoExport.csv'];
      end
      fID = fopen([pathName fileName], 'w');
      % +2 for the headers
      for it = 1:(size(bpData, 1)+2) 
        mainIdx = it-2;
        lineStr = '';
        for cit = 1:size(bpData, 3)
          for git = 1:size(bpData, 2)
            if(it == 1)
              if(git == 1)
                lineStr = sprintf('%s,"%s" DIFF', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
                lineStr = sprintf('%s,"%s" PRE', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
                lineStr = sprintf('%s,"%s" POST', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
              else
                lineStr = sprintf('%s,"%s" DIFF', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
                lineStr = sprintf('%s,"%s" PRE', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
                lineStr = sprintf('%s,"%s" POST', lineStr, strrep(obj.groupLabels{git}, ',', ' -'));
              end
            elseif(it == 2)
              lineStr = sprintf('%s,"%s"', lineStr, obj.fullGroupList{1}{cit});
              lineStr = sprintf('%s,"%s"', lineStr, obj.fullGroupList{1}{cit});
              lineStr = sprintf('%s,"%s"', lineStr, obj.fullGroupList{1}{cit});
            else
              if(isnan(bpData(mainIdx, git, cit)))
                lineStr = sprintf('%s,%s', lineStr, '');
              else
                lineStr = sprintf('%s,%.6f', lineStr, bpData(mainIdx, git, cit));
              end
              if(isnan(bpDataPre(mainIdx, git, cit)))
                lineStr = sprintf('%s,%s', lineStr, '');
              else
                lineStr = sprintf('%s,%.6f', lineStr, bpDataPre(mainIdx, git, cit));
              end
              if(isnan(bpDataPost(mainIdx, git, cit)))
                lineStr = sprintf('%s,%s', lineStr, '');
              else
                lineStr = sprintf('%s,%.6f', lineStr, bpDataPost(mainIdx, git, cit));
              end
            end
          end
        end

       % Stop when everything is NaN
        if(mainIdx >= 1 && all(all(isnan(bpData(mainIdx, :, :)))) && all(all(isnan(bpDataPre(mainIdx, :, :)))) && all(all(isnan(bpDataPost(mainIdx, :, :)))))
           lineStr = sprintf('%s\r\n', lineStr(2:end));
           break;
        end
        % 2:end to avoid the first comma NOT ANYMORE - WHAT?
        lineStr = sprintf('%s\r\n', lineStr(2:end));
        fprintf(fID, lineStr);
      end
      fclose(fID);
    end
  end
end