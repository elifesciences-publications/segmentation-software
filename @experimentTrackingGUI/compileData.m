function compileData(cExpGUI)

posVals=get(cExpGUI.posList,'Value');

num_lines=1;
prompt = {'Extract all Params?'};
dlg_title = 'All Params';    def = {'1'};
answer = inputdlg(prompt,dlg_title,num_lines,def);

answer=str2num(answer{1});

if answer
    cExpGUI.cExperiment.compileCellInformation(posVals);
else
    cExpGUI.cExperiment.compileCellInformationParamsOnly(posVals);
end