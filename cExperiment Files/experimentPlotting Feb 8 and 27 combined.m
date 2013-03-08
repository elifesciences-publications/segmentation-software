%%
figure(10);

tempDataFeb8=cellInfFeb8.median(:,switchTimeFeb8:endTimeFeb8);
tempDataFeb27=cellInfFeb27.median(:,switchTimeFeb27:endTimeFeb27); 
tempPlot=[median(tempDataFeb8*11/12)' median(tempDataFeb27)'];
error=[std(tempDataFeb8)' std(tempDataFeb27)'];
error=error./repmat([sqrt(size(tempDataFeb8,1)) sqrt(size(tempDataFeb27,1))],size(tempPlot,1),1);
x=5:5:size(tempDataFeb8,2)*5;
x=x/60;
x=[x' x'];
% x=1:size(tempData,2);
errorbar(x,tempPlot,error);title('Median GAL10::GFP induction');
xlabel('time post stimulation (hours)');ylabel('Median Cell Fluorescence (AU)');
legend('Old cells','Young cells');
% plot(x,tempPlot);fig

%%
onThresh=5e3;
numOn=max(cellInfFeb8.median(:,switchTimeFeb8:endTimeFeb8)')>onThresh;
sum(numOn)/length(numOn)
figure;plot(mean(cellInfFeb8.median(numOn,switchTimeFeb8:endTimeFeb8)))

numOn=max(cellInfFeb27.median(:,switchTimeFeb27:endTimeFeb27)')>onThresh;
sum(numOn)/length(numOn)
figure;plot(mean(cellInfFeb27.median(numOn,switchTimeFeb27:endTimeFeb27)))
