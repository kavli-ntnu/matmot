function [data] = loadMtvFile(fileName)
%LOADMTVFILE read contents of binary .mtv file from Streamer
%
% DATA = LOADMTVFILE(FILENAME) reads the contents of the .DAT file
% specified by FILENAME, return structure DATA. Fields of DATA are as
% follows:
%
%   frameIdx (int32) - number of Motive frame. Frames are counted from when
%   Motive was opened.
%
%   frameTimestamp (double) - time of Motive frame, relative to when Motive
%   was opened.
%
%   frameLatency (single) - latency of Motive frame.
%
%   pos (single) - [x, y, z] coordinates of rigid body
%
%   rot (single) - [qx, qy, qz, qw] quaternion rotations of rigid body
%
%   posError (single) mean rigid body position error
%
%   posTracked (uint8) rigid body tracking success (1 = tracked, 0 =
%   untracked)
%
%   mx, my, mz (single) - coordinates of labelled markers. These may
%   include markers included in identified rigid bodies. Each field
%   contains an nframes-by-nmarkers matrix, where nmarkers is the maximum
%   number of markers recorded, as set by parameter 'nMarkers' in
%   Streamer, represented by field "n_markers" in the .mtv file
%   header.
%
%   msz (single) - size of labelled markers. Format is the same as for mx,
%   my, mz.
%
%   mres (single) - residuals of labelled markers. Format is the same as
%   for mx, my, mz.

import matmot.Streamer

% Read all data from file
[pth, fn, ext] = fileparts(fileName);
if isempty(pth), pth = pwd(); end
fpth = fullfile(pth, [fn ext]);
assert(exist(fpth, 'file') > 0, 'File "%s" does not exist');
[fid, msg] = fopen(fpth, 'r');
if fid == -1
    error('Could not open file %s: message "%s"', fpth, msg);
end

header = fread(fid, [1, Streamer.HEADER_LENGTH], '*char');
lines = strsplit(header, '\r\n');
[mat, tok] = regexp(lines, 'n_markers=(\w+).*?', 'match', 'tokens');
idx = find(~cellfun(@isempty, mat));
assert(~isempty(idx), ...
    'importMtv:nMarkersNotFound', ...
    'Error parsing file header: could not find string "n_markers"')

% Calculate number of bytes per frame
nMarkers = str2num(tok{idx}{1}{1});
nBytesBasic = Streamer.N_BYTES_BASIC;
nBytesMarker = Streamer.N_BYTES_MARKER;
nBytesFrame = nBytesBasic + nMarkers*nBytesMarker;

allBytes = fread(fid, [nBytesFrame, inf], '*uint8');
fclose(fid);

nFrames = size(allBytes, 2);
encodings = matmot.fieldEncodings();

% Cycle through fields and interpret the relevant bytes for field
% appropriately
for f = 1:numel(encodings)
    field = encodings(f).field;
    inds = encodings(f).byte_inds;
    encoding = encodings(f).encoding;
    bytes = allBytes(inds, :);
    tmp = typecast(bytes(:), encoding);
    data.(field) = reshape(tmp, [], nFrames)';
end

% Read the markers
markerFields = {'mx', 'my', 'mz', 'msz', 'mres'};
nBytesMarkerField = 4; % single float
for f = 1:numel(markerFields)
    fd = markerFields{f};
    indField = nBytesBasic + (f-1)*nBytesMarkerField*nMarkers;
    for m = 1:nMarkers
        inds = indField + (m-1)*nBytesMarkerField + (1:4);
        bytes = allBytes(inds, :);
        tmp = typecast(bytes(:), 'single');
        data.(fd)(:, m) = reshape(tmp, [], nFrames)';
    end
end

fprintf('Done.\n');

end

