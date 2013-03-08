uiload
%%
cExperiment.correctSkippedFramesInf
cExperimentFeb10=cExperiment;
clear cExperiment;
%%
plot(mean(cExperimentFeb10.cellInf(2).mean)')
fig
%%
plot(mean(cExperimentFeb10.cellInf(3).mean)')
fig
%%
channel=2;
switchTimeFeb10=252;
endTimeFeb10=switchTimeFeb10+6.5*12;
temp=cExperimentFeb10.cellInf(1).mean;
temp=temp(:,1:2);

cellsPresentFeb10=min(temp')>1e12;
%%
temp=cExperiment.cellInf(1).mean(~cellsPresentFeb10,:);
numcells=sum(temp>0);
figure(99);plot(numcells);axis([0 size(temp,2) 0 max(numcells)]);

%%
plot(mean(cExperimentFeb10.cellInf(2).median(cellsPresentFeb10,:))')
pause(1)
temp=cExperimentFeb10.cellInf(2).median(~cellsPresentFeb10,:);
plotData=[]
for i=1:size(cExperimentFeb10.cellInf(2).median,2)
    loc=(cExperimentFeb10.cellInf(1).median(:,i)>0) & ~cellsPresentFeb10';
    plotData(i)=mean(cExperimentFeb10.cellInf(2).median(loc,i));
end
plot(plotData')
