%3/7/03 fcbtimeproc = modified from cytosubproc2_labalt to handle new file format (with
%header), should work with any combination of port switching during analysis, Heidi
%3/1/03 modified from cytosubproc2 to handle files from SYN expt's in lab
%with two cultures analyzed (switch every half hour); Heidi

flag = zeros(size(totalstartsec));
%acqtime = totalendsec - totalstartsec - .405;  %for tq-acq-qt?
%acqtime = totalendsec - totalstartsec - .1326; %for vnts-acq-stvn, used until July 2016

querytime=0.0908-0.0275; % time for queries on 100 trigger events - high noise investigation, July 2016
deadtime=(0.0275/100)*200; %events per record pre-2005 have 200 events in them, adjust deadtime for 200 events
acqtime = totalendsec - totalstartsec - (querytime+deadtime); %for ts-acq-st  %new query time, July 2016, from high noise bead runs

%acqtime = totalendsec - totalstartsec; %for qt-acq-tq (mr07)
flag(:) = 0;  %default all records to Not use
%1=temp,2=humidity,3=start port,4=end port,5=start syr#,6=end syr#,7=start syr pos,8=end syr pos.

%flag(find(syrpumpinfo(:,3) == 6 & syrpumpinfo(:,4) == 6 & syrpumpinfo(:,5) & syrpumpinfo(:,6))) = 1; %these are good records for culture 1
%flag(find(syrpumpinfo(:,3) == 3 & syrpumpinfo(:,4) == 3 & syrpumpinfo(:,5) & syrpumpinfo(:,6))) = 2; %these are good records for culture 2

%good records for cells or beads, skipping cases where syringe refills or
%port (valve) changes, also skipping any fast syringes (i.e., syr# = 0)
%keyboard
%non-zero port, same port at start and end, same syringe # at start and end (i.e. syringe did not refill during acquisition
%ind = find((syrpumpinfo(:,3) == syrpumpinfo(:,4)) & syrpumpinfo(:,5) & syrpumpinfo(:,6) & (syrpumpinfo(:,5) == syrpumpinfo(:,6))));
ind = 1 + find((syrpumpinfo(2:end,3) == syrpumpinfo(2:end,4)) & syrpumpinfo(2:end,5) & syrpumpinfo(2:end,6) & (syrpumpinfo(2:end,5) == syrpumpinfo(2:end,6)) & (syrpumpinfo(1:end-1,6) == syrpumpinfo(2:end,5)));
%last part to skip cases where syringe starts to refill during preceeding data transmission (start syringe # ~= previous end syringe #)
%these records often seem to have flow problem or something that makes apparent volume too high
flag(ind) = syrpumpinfo(ind,3);  %set good records to syringe port # (3/03 6=culture 1, 3=culture2, ?=beads)
%follwing finds syringe refills starting mid-record
%ind = find((syrpumpinfo(:,3) == 3 & syrpumpinfo(:,4) == 3) & syrpumpinfo(:,5) & syrpumpinfo(:,6) & (syrpumpinfo(:,5) ~= syrpumpinfo(:,6)));
ind = find(syrpumpinfo(1:end-1,5) & syrpumpinfo(2:end,5) == 0);  %transitions to fast syringes
flag(ind) = 99;

start = syrpumpinfo(:,7);
stop = syrpumpinfo(:,8);
totalvol = .25;  %ml vol of syringe
maxpos = 48000;
analvol = stop*NaN;
t = find(start - stop >= 0);  %start > stop
%tt = start(t)-stop(t);
%tt(tt>48000) = 48000;
%analvol(t) = tt/maxpos*totalvol;
analvol(t) = (start(t)-stop(t))/maxpos*totalvol;
%t = find(start - stop < 0);  %start < stop --> syringe refilled
t = find(syrpumpinfo(:,5) < syrpumpinfo(:,6)); %syringe refilled during acquisition
analvol(t) = (start(t) + maxpos-stop(t))/maxpos*totalvol;
flag(t) = 97; %add specific flag for these syringes KRHC, 7/13/16
% sacq=[t+1;t+2]; sacq2=sacq(sacq <= length(syrpumpinfo)); %find 2nd acquistion records after refilling
% flag(sacq2)=96; %flag the next record and record after as likely contains sheath fluid

t = find(syrpumpinfo(:,5) == syrpumpinfo(:,6) & start - stop < 0); %syringe in middle of refilling at start
analvol(t) = (maxpos-stop(t))/maxpos*totalvol;
flag(t) = 98; %syringes refilling in middle
% sacq=[t+1;t+2]; sacq2=sacq(sacq <= length(syrpumpinfo));
% flag(sacq2)=96;

%last record before end of set (switch to new valve) when syringe is at end, sometimes these have really long acq times (renegade triggers?)
flag(find(syrpumpinfo(2:end,6) < syrpumpinfo(1:end-1,6) & syrpumpinfo(1:end-1,8) == 10)) = 98;


% FIND VOLUME ANALYZED...turns out, not exactly straightforward...

%Notes:
%There are syringe movements not accounted for in the measurements, such
%that volume is being moved while we are querying for pump position or for
%dead time after a trigger. From Alexi's measurements (7/12/16) of full noise, we see
%that average dead time for 100 triggers is .0275s (27.5ms) (without query time)
%At a pump speed of 160 steps/sec, avg steps taken is 14.89 per 100 records with query time
% At 40 steps/sec, avg steps taken is 3.72. In these cases, since the
% triggers could be considered instantaneous, these steps/time are
% essentially due to deadtime and querytime, which leaves:

%       14.89 steps = (160 steps/s) * (dead time + query time)
%       dead+query = 0.0931 sec
%       3.72 steps = (40 steps/s) * (dead time + query time)
%       dead+query = 0.0930 sec !!!!!

%So, the lost time in query ends up being 0.0655...but and with adjusted deadtime for 200 records
% we get dead time of 0.0550, together they give steps lost, which gives volume lost!

%3 different speeds of pump:
%P3 - 40 steps/sec -> 20min per syr -> syrnum rolls over at 50
%P2 - 80 steps/sec -> 10min per syr -> syrnum rolls over at 100
%P1 - 160 steps/sec -> 5min per syr -> syrnum rolls over at 200

%%can find pump speed by looking at steps per second, avg syring time, or the most robust metric - slope of records/time:
stepdist=syrpumpinfo(:,7)-syrpumpinfo(:,8);
timediff=totalendsec-totalstartsec;
pump_speed=stepdist./timediff; %rough speed

%     one way to get average syringe time:
%     ds=find(diff(syrpumpinfo(:,5))~=0); %look for syringe changes...
%     avgsyrtime=[totalstartsec(ds(2:end)) (1/60)*(totalstartsec(ds(2:end))-totalstartsec(ds(1:end-1)))]; %time difference inbetween

% a slightly clunkier way to find syringe times, but perhaps more straight forward:

if length(unique(syrpumpinfo(:,5))) > 1 %rare case where only one syringe is in batch -> slope approach will fail
    count=1;
    ii=1;
    syrnum=syrpumpinfo(1,5);
    %syrchangeinfo=[syr_starttime  syr_endtime  start_index end_index syrnum avgsyrtime syrnum_slope]
    syrchangeinfo=[totalstartsec(1) NaN 1 NaN syrpumpinfo(1,5) syrpumpinfo(1,3)];
    while ii < length(syrpumpinfo)
        ii=ii+1;
        if syrnum ~= syrpumpinfo(ii,5) %moved onto new syringe
            syrchangeinfo(count,2)=totalendsec(ii-1); %fill in previous record
            syrchangeinfo(count,4)=ii-1; %record ending index
            count=count+1; %advance syr count
            syrchangeinfo(count,1)=totalstartsec(ii); %start new syringe record
            syrnum=syrpumpinfo(ii,5);
            syrchangeinfo(count,5)=syrnum;
            syrchangeinfo(count,3)=ii; %record beginning index
            syrchangeinfo(count,6)=syrpumpinfo(ii,3);
        elseif syrnum ~= syrpumpinfo(ii,6) %moved onto new syringe      %this logic needs to come 2nd after 1st piece
            syrchangeinfo(count,2)=totalstartsec(ii); %fill in record
            syrchangeinfo(count,4)=ii; %record ending index
            syrnum=syrpumpinfo(ii,6);
            count=count+1;  %advance syr count
            syrchangeinfo(count,1)=totalendsec(ii);
            syrchangeinfo(count,5)=syrnum;
            syrchangeinfo(count,3)=ii; %record beginning index
            syrchangeinfo(count,6)=syrpumpinfo(ii,4);  %type of syringe
        end
    end
    %to end this matrix:
    syrchangeinfo(count,2)=totalendsec(end);
    syrchangeinfo(count,4)=length(syrpumpinfo);
    
    %calculate average syringe time:
    syrchangeinfo=[syrchangeinfo (1/60)*(syrchangeinfo(:,2)-syrchangeinfo(:,1))];
    
    %find the slope of syringe numbers over time:
    ii=find(diff(syrchangeinfo(:,5))<0);
    ii2=find(syrchangeinfo(ii,5)~=1);
    
    ro=ii(ii2); %rollover indexes
    ro=[0; ro; size(syrchangeinfo,1)];
    if length(ro) >2
        syrslope=(syrchangeinfo(ro(2:end),2)-syrchangeinfo(ro(1:end-1)+1,1))./(syrchangeinfo(ro(2:end),5)-syrchangeinfo(ro(1:end-1)+1,5)); %two indexes to avoid some 0 syringes on restart
    else %case where no rollover detected:
        syrslope=(syrchangeinfo(ro(end),2)-syrchangeinfo(ro(1)+1,1))./(syrchangeinfo(ro(end),5)-syrchangeinfo(ro(1)+1,5)); %two indexes to avoid some 0 syringes on restart
    end
    %fill in these slopes for all syringes:
    for q=1:length(ro)-1
        if any(diff(syrchangeinfo(ro(q)+1:ro(q+1),1)) > 10000) %3hr gap ~ 10000 sec - split the syringe -> case where acq stopped, but resumes syr num?
            disp('split syringe?')
            jj=ro(q)+1:ro(q+1); %easier to handle indexes
            kk=find(diff(syrchangeinfo(jj,1)) > 10000);
            syrchangeinfo(jj(1):jj(kk),8)=(syrchangeinfo(jj(kk)-1,2)-syrchangeinfo(jj(1),1))./(syrchangeinfo(jj(kk)-1,5)-syrchangeinfo(jj(1),5)); %recalculate slopes for each split, just in case, move one index in...
            syrchangeinfo(jj(kk)+1:jj(end),8)=(syrchangeinfo(jj(end),2)-syrchangeinfo(jj(kk)+1,1))./(syrchangeinfo(jj(end),5)-syrchangeinfo(jj(kk)+1,5));
        elseif length(ro(q)+1:ro(q+1)) < 7 & length(ro)>2
            syrchangeinfo(ro(q)+1:ro(q+1),8)=0; %will be caught later - > unreliable slope estimates when rollover does 'little' restarts
        else
            syrchangeinfo(ro(q)+1:ro(q+1),8)=syrslope(q);
        end
    end
    % keyboard
    
    %use the syrchangeinfo matrix to populate matrix for each record:
    avgsyrtime=nan(size(syrpumpinfo,1),2); %syringe times and slopes
    for q=1:size(syrchangeinfo,1)
        avgsyrtime(syrchangeinfo(q,3):syrchangeinfo(q,4),1)=(1/60)*(syrchangeinfo(q,2)-syrchangeinfo(q,1));
        avgsyrtime(syrchangeinfo(q,3):syrchangeinfo(q,4),2)=syrchangeinfo(q,8);
    end
    
    P3=find(avgsyrtime(:,2) > 1000 & avgsyrtime(:,2) < 1800); %slope = ~1250 syringes/time ~ rollover
    P2=find(avgsyrtime(:,2) > 500 & avgsyrtime(:,2) < 700); %slope = ~615 syringes/time ~ rollover
    P1=find(avgsyrtime(:,2) > 250 & avgsyrtime(:,2) < 400); %slope = ~314 syringes/time ~ rollover
    
    % any cells or bead runs unaccounted for?
    ind1=find(flag==3 | flag ==6); %cells and beads
    test0=ismember(ind1,[P1;P2;P3]);
    goodrate=find(test0==1);
    test=find(test0==0);
    
    if ~isempty(test)
        jj=ind1(test); %easier to handle indexes
        disp(['speeds unaccounted for: ' num2str(length(test)) ' ...using closest speed'])
        
        %     use speed and average syringe time to further help assign a speed:
        %     p2=find((pump_speed(jj) > 70 & pump_speed(jj) < 85) | (avgsyrtime(jj) > 8 & avgsyrtime(jj) < 11));
        %     p1=find((pump_speed(jj) > 150 & pump_speed(jj) < 165) | (avgsyrtime(jj) > 3.5 & avgsyrtime(jj) < 6 ));
        %     p3=find((pump_speed(jj) > 30 & pump_speed(jj) < 45) | (avgsyrtime(jj) > 18 & avgsyrtime(jj) < 22 ));
        
        for i=1:length(jj)
            [~, im]=min(abs(jj(i)-goodrate)); %find closest good bead or cell run that has a pumprate
            if ismember(ind1(goodrate(im)),P3) %use this index speed
                P3=[P3; jj(i)]; %add the test index to a speed index group
            elseif ismember(ind1(goodrate(im)),P2)
                P2=[P2; jj(i)];
            elseif ismember(ind1(goodrate(im)),P1)
                P1=[P1; jj(i)];
            else
                keyboard
            end
        end
    end
    
    pumprate=zeros(size(syrpumpinfo,1),1);
    pumprate(P3)=40;
    pumprate(P2)=80;
    pumprate(P1)=160;
    
    %plots for sanity check:
    if syrplotflag
        subplot(2,1,1,'replace')
        plot(totalstartsec,syrpumpinfo(:,5),'k.-');
        hold on
        if ~isempty(test)
            plot(totalstartsec(ind1(test)),syrpumpinfo(ind1(test),5),'r.');
        end
        
        subplot(2,1,2,'replace'), hold on
        plot(totalstartsec,pump_speed,'.-','color',[0.6 0.6 0.6])
        plot(totalstartsec(ind1),pump_speed(ind1),'.','color',[0 0.5 1])
        plot(totalstartsec(ind1),pumprate(ind1),'.','color',[0 0 1])
        if ~isempty(test)
            plot(totalstartsec(ind1(test)),pumprate(ind1(test)),'c.');
        end
        ylim([-10 180])
        %keyboard
        pause(0.5)
    end
    
else %for rare case of only 1 syringe being processed...
    %keyboard
    P1=find((pump_speed > 70 & pump_speed < 85));
    P2=find((pump_speed > 150 & pump_speed < 165));
    P3=find((pump_speed > 30 & pump_speed < 45));
    
    pumprate=zeros(size(syrpumpinfo,1),1);
    pumprate(P3)=40;
    pumprate(P2)=80;
    pumprate(P1)=160;    
end

%analvol(t) = (start(t)-stop(t))/maxpos*totalvol;
%offset = steps/sec*(q+d time)*(totalvol/maxpos)
offset = pumprate*(deadtime+querytime)*(totalvol/maxpos);
analvol = analvol - offset;


%analvol = analvol - 1.692e-4;  %volume offset for query, for mr07 set (3/03)
% analvol = analvol - 5.48e-5;  %

%outmatrix = [1:length(totalstartsec) totalstartsec totalendsec acqtime medianinterval flag ];
outmatrix = [200*(1:length(totalstartsec))' totalstartsec totalendsec acqtime analvol flag];

clear acqtime flag t ind analvol maxpos start stop totalvol

