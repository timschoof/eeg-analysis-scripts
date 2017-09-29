function [data, accepted, rejected] = rejectArtefacts(data, nTrials,artefact)

% create index of trials to be removed
countr = 1;
for nn = 1:nTrials
    if (max(data(nn,:))>artefact) || (min(data(nn,:))< -artefact)
        rm_index(countr) = nn;
        countr = countr+1;
    end
end

% remove trials
if exist('rm_index')
    data([rm_index],:) = [];
    rejected = length(rm_index);
    accepted = totalsweeps - rejected;
else
    rejected = 0;
    accepted = totalsweeps;
end
