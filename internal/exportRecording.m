function experiment = exportRecording(experiment, varargin)
% EXPORTRECORDING Exports the original recording (in a possible different format)
%
% USAGE:
%    experiment = exportRecording(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportMovieOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = exportRecording(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: export recording
% parentGroups: misc
% optionsClass: exportMovieOptions
% requiredFields: handle, folder, name

[params, var] = processFunctionStartup(exportMovieOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, sprintf('Exporting recording for: %s', experiment.name));
%--------------------------------------------------------------------------

% Export movie options
exportMovieOptionsCurrent = params;

mainFolder = experiment.folder;
dataFolder = [mainFolder 'exports' filesep];
if(~exist(dataFolder, 'dir'))
  mkdir(dataFolder);
end
fileName = [dataFolder exportMovieOptionsCurrent.baseFileName];

switch exportMovieOptionsCurrent.rangeSelection
  case 'frames'
    frameRange = exportMovieOptionsCurrent.range;
  case 'time'
    frameRange = round(exportMovieOptionsCurrent.range*experiment.fps);
end
% Little bit of consistency checks
  if(frameRange(1) < 1)
    frameRange(1) = 1;
  end
  if(frameRange(2) > experiment.numFrames)
    frameRange(2) = experiment.numFrames;
  end
if(isempty(exportMovieOptionsCurrent.frameSkip) || exportMovieOptionsCurrent.frameSkip == 0)
  exportMovieOptionsCurrent.frameSkip = 1;
end


switch exportMovieOptionsCurrent.profile
  case 'Big Tiff'
    options = struct;
    if(exportMovieOptionsCurrent.compressMovie)
      options.compress = 'lzw';
    else
      options.compress = 'no';
    end
    options.overwrite = true;
    options.big = true;
    options.message = false;
    fileName = [fileName '.btf'];
    switch params.bitsPerPixel
      case '8'
        bppFunc = @uint8;
        bpp = 8;
      case '16'
        bppFunc = @uint16;
        bpp = 16;
      case '32'
        bppFunc = @uint32;
        bpp = 32;
      case 'single'
        bppFunc = @single;
        bpp = 1;
      case 'double'
        bppFunc = @double;
        bpp = 1;
    end
    %options.append
    %res = saveastiff(data, path, options)
  otherwise
    newMovie = VideoWriter(fileName, exportMovieOptionsCurrent.profile);
    %newMovie = VideoWriter(fileName, 'Motion JPEG 2000');
    try
      if(~params.compressMovie)
        newMovie.LosslessCompression = false;
      else
        if(params.compressionLevel > 1)
          newMovie.LosslessCompression = false;
          newMovie.CompressionRatio = params.compressionLevel;
        else
          newMovie.LosslessCompression = true;
        end
      end
      newMovie.MJ2BitDepth = params.bitsPerPixel;
      switch params.bitsPerPixel
      case '8'
        bppFunc = @uint8;
        bpp = 8;
      case '16'
        bppFunc = @uint16;
        bpp = 16;
      case '32'
        bppFunc = @uint32;
        bpp = 32;
      case 'single'
        bppFunc = @single;
        bpp = 1;
      case 'double'
        bppFunc = @double;
        bpp = 1;
    end
    catch
      switch params.bitsPerPixel
      case '8'
        bppFunc = @uint8;
        bpp = 8;
      case '16'
        bppFunc = @uint16;
        bpp = 16;
      case '32'
        bppFunc = @uint32;
        bpp = 32;
      case 'single'
        bppFunc = @single;
        bpp = 1;
      case 'double'
        bppFunc = @double;
        bpp = 1;
    end
    end
    
end
% The iterator loop
switch exportMovieOptionsCurrent.resamplingMethod
  case 'none'
    frameList = frameRange(1):exportMovieOptionsCurrent.frameSkip:frameRange(2);
  otherwise
    if(exportMovieOptionsCurrent.frameRate > experiment.fps)
      logMsg('New framerate cannot be higher with the selected resampling method. Use none instead', 'e');
      return;
    end
    if(mod(experiment.fps, exportMovieOptionsCurrent.frameRate) ~=0)
      closestFrameRate = 1/round(experiment.fps/exportMovieOptionsCurrent.frameRate)*experiment.fps;
      logMsg(sprintf('For the current resampling method the new frame rate has to be a divisor of the original one. Using %.3f instead', closestFrameRate), 'w');
      exportMovieOptionsCurrent.frameRate = closestFrameRate;
      frameWindow = round(experiment.fps/exportMovieOptionsCurrent.frameRate);
    end
    % New consistency check
    if(frameRange(2)+frameWindow-1 > experiment.numFrames)
      frameRange(2) = experiment.numFrames-frameWindow+1;
    end
    frameList = frameRange(1):frameWindow:frameRange(2);
end
switch exportMovieOptionsCurrent.profile
  case 'Big Tiff'
  otherwise
    newMovie.FrameRate = exportMovieOptionsCurrent.frameRate;
    open(newMovie);
end
%ncbar('Saving current movie');
numFrames = length(frameList);

[fid, experiment] = openVideoStream(experiment);
format = 1;

if(params.maximizeDynamicRange && isfield(experiment, 'intensityRange') && ~isempty(experiment.intensityRange))
  minI = experiment.intensityRange(1);
  maxI = experiment.intensityRange(2);
else
  minI = 0;
  maxI = 2^experiment.bpp-1;
end
if(strcmpi(exportMovieOptionsCurrent.resamplingMethod, 'sum'))
  minI = minI*frameWindow;
  maxI = maxI*frameWindow;
end

for it = 1:numFrames
  switch exportMovieOptionsCurrent.resamplingMethod
    case 'none'
      frame = getFrame(experiment, frameList(it), fid);
      frame = (double(frame)-minI)/(maxI-minI);
      frame = bppFunc(frame*(2^bpp-1));
    otherwise
      frameData = zeros(experiment.height, experiment.width);
      for it2 = 1:frameWindow
        frame = getFrame(experiment, frameList(it)+it2-1, fid);
        frameData = frameData + double(frame);
      end
      if(strcmpi(exportMovieOptionsCurrent.resamplingMethod, 'mean'))
        frameData = frameData/frameWindow;
      end
      frame = (double(frameData)-minI)/(maxI-minI);
      frame = bppFunc(frame*(2^bpp-1));
  end
  switch exportMovieOptionsCurrent.profile
    case 'Big Tiff'
      if(it == 1)
        options.overwrite = true;
        options.append = false;
        saveastiff(bppFunc(frame), fileName, options);
      else
        options.overwrite = false;
        options.append = true;
        saveastiff(bppFunc(frame), fileName, options);
      end
    otherwise
    writeVideo(newMovie, repmat(frame, 1, 1, format));
  end
  ncbar.update(it/numFrames);
end
switch exportMovieOptionsCurrent.profile
  case 'Big Tiff'
  otherwise
    close(newMovie);
end
closeVideoStream(fid);

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end