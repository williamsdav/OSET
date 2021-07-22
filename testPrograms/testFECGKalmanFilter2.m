%
% Test program for ECG filtering using EKF and EKS
%
% Dependencies: The baseline wander and ECG filtering toolboxes of the Open Source ECG Toolbox
%
% Open Source ECG Toolbox, version 1.0, November 2006
% Released under the GNU General Public License
% Copyright (C) 2006  Reza Sameni
% Sharif University of Technology, Tehran, Iran -- LIS-INPG, Grenoble, France
% reza.sameni@gmail.com

% This program is free software; you can redistribute it and/or modify it
% under the terms of the GNU General Public License as published by the
% Free Software Foundation; either version 2 of the License, or (at your
% option) any later version.
% This program is distributed in the hope that it will be useful, but
% WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
% Public License for more details.

clc
clear
close all;

% load('SampleECG1.mat');
% load('SampleECG2.mat'); data = data(1:15000,2)';

% load('FOETAL_ECG.dat'); data = FOETAL_ECG(:,2)'; refdata = FOETAL_ECG(:,9)'; time = FOETAL_ECG(:,1)'; clear FOETAL_ECG; fs = 250;
load samplefetaldenoised data
fs = 250;


time = (0:length(data)-1)/fs;

f = 2;                                          % approximate R-peak frequency

bsline = LPFilter(data,.7/fs);                  % baseline wander removal (may be replaced by other approaches)
%bsline = BaseLineKF(data,.5/fs);                % baseline wander removal (may be replaced by other approaches)

x = data - bsline;

figure
plot(time, x);
xlabel('time(s)');
ylabel('Amplitude(mV)');
title('Sample fetal ECG after mECG cancellation and before post-processing');
grid
set(gca, 'fontsize',14);

%//////////////////////////////////////////////////////////////////////////
% bslinex = LPFilter(x,.7/fs);                  % baseline wander removal (may be replaced by other approaches)
% x = x - bslinex;
%//////////////////////////////////////////////////////////////////////////

peaks = PeakDetection(data,f/fs);                  % peak detection


[phase, phasepos] = PhaseCalculation(peaks);     % phase calculation

teta = 0;                                       % desired phase shift
pphase = PhaseShifting(phase,teta);             % phase shifting

bins = fs/2;                                     % number of phase bins
[ECGmean,ECGsd,meanphase] = MeanECGExtraction(x,pphase,bins,1); % mean ECG extraction 

OptimumParams = ECGBeatFitter(ECGmean,ECGsd,meanphase);           % ECG beat fitter GUI

%//////////////////////////////////////////////////////////////////////////
N = length(OptimumParams)/3;% number of Gaussian kernels
JJ = find(peaks);
fm = fs./diff(JJ);          % heart-rate
w = mean(2*pi*fm);          % average heart-rate in rads.
wsd = std(2*pi*fm,1);       % heart-rate standard deviation in rads.

y = [phase ; x];

X0 = [-pi 0]';
P0 = [(2*pi)^2 0 ;0 (10*max(abs(x))).^2];
% Q = diag( [ (.1*OptimumParams(1:N)).^2 (.05*ones(1,N)).^2 (.05*ones(1,N)).^2 (wsd)^2 , (.05*mean(ECGsd(1:round(length(ECGsd)/10))))^2] );
Q = diag( [ (.5*OptimumParams(1:N)).^2 (.2*ones(1,N)).^2 (.2*ones(1,N)).^2 (wsd)^2 , (.2*mean(ECGsd(1:round(end/10))))^2] );
R = [(w/fs).^2/12 0 ;0 (mean(ECGsd(1:round(length(ECGsd)/10)))).^2];
Wmean = [OptimumParams w 0]';
Vmean = [0 0]';
Inits = [OptimumParams w fs];

InovWlen = ceil(.5*fs);     % innovations monitoring window length
tau = [];                   % Kalman filter forgetting time. tau=[] for no forgetting factor
gamma = 1;                  % observation covariance adaptation-rate. 0<gamma<1 and gamma=1 for no adaptation
RadaptWlen = ceil(fs/2);    % window length for observation covariance adaptation

% [Xekf,Phat]=UKF(X0,P0,Q,R,y,Wmean,Vmean);
[Xekf,Phat,Xeks,PSmoothed,ak] = EKSmoother(y,X0,P0,Q,R,Wmean,Vmean,Inits,InovWlen,tau,gamma,RadaptWlen,1);

%//////////////////////////////////////////////////////////////////////////
Xekf = Xekf(2,:);
Phat = squeeze(Phat(2,2,:))';
Xeks = Xeks(2,:);
PSmoothed = squeeze(PSmoothed(2,2,:))';

% % % figure
% % % plot(t,x);
% % % hold on;
% % % plot(t,Xekf','g');
% % % plot(t,Xeks','r');
% % % grid;
% % % legend('Noisy','EKF Output','EKS Output');

I = 1:length(x);

h = figure;
plot(time(I),Xeks(I),'k','Linewidth',.5);
xlabel('time(s)','FontSize',10);
ylabel('Amplitude(mV)','FontSize',10);
grid;
set(gca,'FontSize',10);
a = axis;
a(1) = time(1);
a(2) = time(end);
axis(a);
set(h,'PaperUnits','inches');
set(h,'PaperPosition',[.01 .01 8.5 2.5])
% print('-dpng','-r600',['C:\Reza\DaISy1EKS_FetalPProcess','.png']);
% print('-deps','-r600',['C:\Reza\DaISy1EKS_FetalPProcess','.eps']);
title('Fetal ECG denoised by EKS');

I = 501:850;
figure
plot(time(I),x(I),'linewidth',2,'Color',[128 128 128]/256);
hold on;
plot(time(I),Xeks(I),'k','linewidth',2.5);
grid;
plot(time(I),Xeks(I)+sqrt(PSmoothed(I)),'r','linewidth',1);
plot(time(I),Xeks(I)+3*sqrt(PSmoothed(I)),'b--','linewidth',1);
legend('Noisy','EKS Output','\pm\sigma envelope','\pm 3\sigma envelope');
plot(time(I),Xeks(I)-sqrt(PSmoothed(I)),'r','linewidth',1);
plot(time(I),Xeks(I)-3*sqrt(PSmoothed(I)),'b--','linewidth',1);
plot(time(I),Xeks(I),'k','linewidth',2.5);
axis tight
xlabel('time(s)','FontSize',16);
ylabel('Amplitude(mV)','FontSize',16);
set(gca,'FontSize',16);
title('Fetal ECG denoised by EKS with confidence intervals');

t = 1000*(0:length(ECGmean)-1)/fs;
figure;
hold on;
errorbar(t,ECGmean,ECGsd);
plot(t,ECGmean,'r','linewidth',2);
set(gca,'FontSize',16,'Box','on');
grid;
axis tight;
xlabel('time(ms)','FontSize',16);
ylabel('Amplitude(mV)','FontSize',16);
title('Average fetal ECG beat');


