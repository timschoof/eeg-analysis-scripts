function v = readOuts(frq, f, V, nEachSide)

% Although its structure would allow other inputs, this function was
% designed to extract the values from a spectrum (defined by f & V)
% extending nEachSide samples from a given frequency. A matrix is returned
% which contains the row number, frequency & spectral energy. This allows
% the determination of the value of a spectral peak when its exact position
% is not known, but it is known in what region it is likely to be found.
%
% For example, for real Rapd FFR data, the F0 is nominally 128 Hz. If we
% extract a region of the spectrum around that point using the command:
% vv128 = readOuts(128, f, dB, 5), where f and dB are the frequency values
% and spectrum levels in dB, respectively, we get:
%
%                      65532             127.990234375         -53.3648662547322
%                      65533               127.9921875         -43.5216229895129
%                      65534             127.994140625         -40.8379976019859
%                      65535              127.99609375         -43.2483185234419
%                      65536             127.998046875         -43.8231724530998
%                      65537                       128          -44.118534271966
%                      65538             128.001953125         -35.8338016606884
%                      65539              128.00390625         -17.2138805450006
%                      65540             128.005859375         -45.7610651359593
%                      65541               128.0078125         -43.2254503411374
%                      65542             128.009765625         -40.3555766877064
%
% Here it is clear that the spectral peak correspnding to the F0 is at 128.0039 Hz

ind = find(f==frq);

v=[ (ind-nEachSide:ind+nEachSide)', f((ind-nEachSide:ind+nEachSide)) , V((ind-nEachSide:ind+nEachSide))'];
