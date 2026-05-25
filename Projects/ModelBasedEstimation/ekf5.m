
%% MAE 6760 Model Based Estimation
% Cornell University
% M Campbell
%
% Final Project - 7 state EKF; PRc and W_sh are computed each step from N,T1 (not extra states)
%It has modelled efficiency estimation with random walk
%
close all; clear all;
MAE6760startup;
global MCcolors;
rng(100);

%% Simulation
dt = 0.1;
nt = 1000;
t = 0:dt:(nt-1)*dt;

% STATE VECTOR nx=7:
% x = [T2; T3; T4; ec; eb; et; N]
nx = 7;
x_true = zeros(nx, nt);

% Initial true state
x_true(:,1) = [
    300;    % T2
    400;    % T3
    900;    % T4
    0.85;   % ec  - compressor efficiency
    0.98;   % eb  - burner efficiency
    0.90;   % et  - turbine efficiency
    30000;    % N
];

sigma_eff = 1e-4;
global gam LHV cp tc tb tt prn p_c n_c w_c en_nom
gam     = 1.4;
LHV     = 43e6;
cp      = 1005;
tc      = 0.3;
tb      = 0.8;
tt      = 0.5;
prn     = 0.92;
n_c       = 1e-6;%4.77;% 60/J*2*pi..where J=0.5
p_c       = 3.6e-7; %prc constat
w_c     =1.1e-3;%shaft const
en_nom    = 0.95;    % fixed nozzle efficiency

% INPUT SCHEDULE — SI UNITS (explicit)
%   u(:,k) = [ T1 ; u_fuel ; mdot_air ]
%     T1        [K]      (define in your report what it represents)
%     u_fuel    [kg/s]   fuel MASS flow (NOT kg/h; if datasheet is kg/h, /3600)
%     mdot_air  [kg/s]   air MASS flow into the modeled volume (core vs fan: pick one)
u = zeros(3, nt);

% --- Nominal cruise (tune from a datasheet or a chosen design point) ---
T1_nom        = 490;      % [K]  NOTE: if you want literal cold cruise OAT, use ~220–260 K instead (retune map constants if you change this a lot).
mdot_air_nom  = 25;       % [kg/s]  ballpark SMALL turbofan core / gas-path level — tune to your engine story
fuel_nom        = 0.09;   % [kg/s]  ballpark cruise fuel — tune

% --- Small stochastic perturbations (SI) ---
sigma_T1      = 1.0;      % [K]
sigma_mdot    = 0.20;     % [kg/s]
sigma_fuel    = 0.004;    % [kg/s]

% --- Feasibility guards ---
mdot_min      = 0.50;     % [kg/s] floor to avoid mdot -> 0 in divisions
fuel_min      = 0.0;      % [kg/s]
T1_min        = 180;      % [K] crude lower sanity bound (tune/remove)

% --- Optional low-pass (same role as your alpha smoothing) ---
alpha     = 0.995;
T1_prev   = T1_nom;
mdot_prev = mdot_air_nom;
fuel_prev = fuel_nom;

for k = 1:nt
    % Raw draws
    T1_inst   = T1_nom       + sigma_T1   * randn();
    mdot_inst = mdot_air_nom + sigma_mdot * randn();
    fuel_inst = fuel_nom     + sigma_fuel * randn();

    % Low-pass
    T1       = alpha*T1_prev   + (1-alpha)*T1_inst;
    mdot_air = alpha*mdot_prev + (1-alpha)*mdot_inst;
    u_fuel   = alpha*fuel_prev + (1-alpha)*fuel_inst;

    % SI clamps (feasibility)
    T1       = max(T1, T1_min);
    mdot_air = max(mdot_air, mdot_min);
    u_fuel   = max(u_fuel, fuel_min);

    % Memory + pack
    T1_prev   = T1;
    mdot_prev = mdot_air;
    fuel_prev = u_fuel;

    u(:,k) = [T1; u_fuel; mdot_air];
end
%% True state simulation
for k = 1:nt-1

    xk = x_true(:,k);
    uk = u(:,k);

    T2    = xk(1);
    T3    = xk(2);
    T4    = xk(3);
    ec    = xk(4);
    eb    = xk(5);
    et    = xk(6);
    N    = xk(7);   % now from state
    
    T1       = uk(1);
    u_fuel   = uk(2);
    mdot_air = uk(3);

    % Thermodynamic equilibrium targets (from compressor/turbine physics)
    PRc  = (1 + p_c*(N^2)/T1);           % compressor map
    W_sh  = w_c*(N^2)/T1;        % turbine - compressor power

    % Thermodynamic dynamics (uses PRc and W_sh from maps above in the xdot terms)
    xdot = [
        (T1*(1 + (PRc^((gam-1)/gam) - 1)/ec) - T2) / tc;    % T2 dot
        (T2 + (u_fuel*LHV*eb / (cp*mdot_air)) - T3) / tb;   % T3 dot
        (T3 - W_sh/(mdot_air*cp*et) - T4) / tt;             % T4 dot
        0;                                                    % ec  no term in ODE (truth adds rw after step)
        0;                                                    % eb  no term in ODE (truth adds rw after step)
        0;                                                    % et  no term in ODE (truth adds rw after step)
        n_c*mdot_air*cp*(T3-T4-T2+T1)
    ];

    x_true(:,k+1) = xk + dt*xdot;
    %add random walk for efficiency
    x_true(4:6, k+1) = x_true(4:6, k+1) + sigma_eff  * randn(3,1);

end



%% Measurement simulation
% z = [T2; T3; T5; N]
nz = 4;
z  = zeros(nz, nt);

R = diag([
    1.5^2,   % T2 sensor noise
    2^2,   % T3 
    4^2,     % T5 
    100^2    % N 
]);

for k = 1:nt

    T1    = u(1,k);
    T2    = x_true(1,k);
    T4    = x_true(3,k);
    N   = x_true(7,k);
    ufuel = u(2,k);

    z(:,k) = [
        T2;                                      % z2: T2 measured
        T3;
        T4*(1 - en_nom*(1 - prn^((gam-1)/gam))); % z3: T5 
        N;
    ] + sqrtm(R)*randn(nz,1);
end

%% Run the EKF
x0 = [
    500;    % T2
    700;    % T3
    900;    % T4
    0.80;   % ec
    0.97;   % eb
    0.95;   % et
    15000;    % N  
];

% Initial covariance 
P0 = diag([
    5^2,    % T2
    150^2,    % T3  
    70^2,    % T4
    0.05^2,  % ec
    0.05^2,  % eb
    0.8^2,  % et
    20000^2    % N 
]);

xhatu = zeros(nx, nt);  xhatu(:,1) = x0;
Pu    = zeros(nx, nx, nt);  Pu(:,:,1)  = P0;
xhatp = xhatu;
Pp    = Pu;
G     = eye(nx);

% process noise Q 
Q = diag([0.5^2, 20^2, 15^2, sigma_eff^2, sigma_eff^2, sigma_eff^2, 0.5^2]);

% Measurement noise --Declared above
%R = diag([2^2, 0.01^2, 3^2, 0.02^2, 500^2, 0.05^2]);
innov_T3_log = zeros(1, nt);
for k = 1:nt-1

    % --- Predict ---
    xhatp(:,k+1) = predict_state_engine(xhatu(:,k), u(:,k), dt);
    F = getF_engine(xhatu(:,k), u(:,k), dt);
    Pp(:,:,k+1)  = F*Pu(:,:,k)*F' + G*Q*G';

    % --- Update ---
    H = getH_engine(xhatp(:,k+1), u(:,k+1), dt);
    K = Pp(:,:,k+1)*H' / (H*Pp(:,:,k+1)*H' + R);
    xhatu(:,k+1) = xhatp(:,k+1) + K*(z(:,k+1) - H*xhatp(:,k+1));
    Pu(:,:,k+1)  = (eye(nx) - K*H)*Pp(:,:,k+1)*(eye(nx) - K*H)' + K*R*K';

    obs_rank(k+1) = compute_observability_rank(F, H);
end


%% Functions

function Xkp1 = predict_state_engine(Xk, U, dt)
% State: [T2; T3; T4; ec; eb; et; N]
% Input: [T1; u_fuel; mdot_air]
global gam LHV cp tc tb tt n_c p_c w_c

T2    = Xk(1);
T3    = Xk(2);
T4    = Xk(3);
ec    = Xk(4);
eb    = Xk(5);
et    = Xk(6);
N   = Xk(7);


T1       = U(1);
u_fuel   = U(2);
mdot_air = U(3);

% Physical equilibrium targets
PRc  = (1 + p_c*(N^2)/T1);           % compressor map
W_sh  = w_c*(N^2)/T1;        % turbine - compressor power

Xkp1 = Xk + dt*[
    (T1*(1 + (PRc^((gam-1)/gam) - 1)/ec) - T2) / tc; % T2 dot
    (T2 + (u_fuel*LHV*eb / (cp*mdot_air)) - T3) / tb; % T3 dot
    (T3 - W_sh/(mdot_air*cp*et) - T4) / tt;           % T4 dot
    0;                                                  % ec 0 in f (cov still gets Q on effs)
    0;                                                  % eb 0 in f
    0;                                                  % et 0 in f
    n_c*mdot_air*cp*(T3-T4-T2+T1)
];
end


function F = getF_engine(Xk, U, dt)
% Jacobian df/dx  (7*7)
% State: [T2; T3; T4; ec; eb; et; N]
% Input: [T1; u_fuel; mdot_air]
global gam LHV cp tc tb tt p_c n_c w_c

T2    = Xk(1);
T3    = Xk(2);
T4    = Xk(3);
ec    = Xk(4);
eb    = Xk(5);
et    = Xk(6);
N   = Xk(7);

T1       = U(1);
u_fuel   = U(2);
mdot_air = U(3);
%Intermediate calculation
PRc  = (1 + p_c*(N^2)/T1);           % compressor map
W_sh  = w_c*(N^2)/T1;        % turbine - compressor power

% --- Partials of T2_dot = (T1*(1+(PRc^a-1)/ec) - T2)/tc ---
dT2_dT2  = 1-(dt/tc);
dT2_dec  = -dt*T1*(PRc^((gam-1)/gam) - 1) / (tc*ec^2);
dT2_dN   = dt*T1*(gam-1)*2*p_c*N*(PRc^(-1/gam))/(tc*ec*gam*T1);


% --- Partials of T3_dot = (T2 + fuel*LHV*eb/(cp*mdot) - T3)/tb ---
dT3_dT2  =  dt/tb;
dT3_dT3  = 1-(dt/tb);
dT3_deb  =  dt*u_fuel*LHV / (tb*cp*mdot_air);

% --- Partials of T4_dot = (T3 - W_sh/(mdot*cp*et) - T4)/tt ---
dT4_dT3  =  dt/tt;
dT4_dT4  = 1-(dt/tt);
dT4_det  = dt*W_sh/ (tt*mdot_air*cp*et^2);
dt4_dN   = -dt*w_c*2*N/(tt*mdot_air*cp*et*T1);

% --- Partials of N_dot=n_c*mdot*cp*(T3-T4-T2+T1)
dN_dT2 = -dt*n_c*mdot_air*cp;
dN_dT3 =  dt*n_c*mdot_air*cp;
dN_dT4 = -dt*n_c*mdot_air*cp;


%         T2        T3        T4        ec        eb        et        N   -- 
F = [
    dT2_dT2,  0,        0,        dT2_dec,  0,        0,    dT2_dN;
    dT3_dT2,  dT3_dT3,  0,        0,        dT3_deb,  0,    0;
    0,        dT4_dT3,  dT4_dT4,  0,        0,        dT4_det,dt4_dN;
    0,        0,        0,        1,        0,        0,    0;
    0,        0,        0,        0,        1,        0,    0;
    0,        0,        0,        0,        0,        1,    0;
    dN_dT2,   dN_dT3,   dN_dT4,   0,        0,        0,    1;
];
end

function H = getH_engine(Xk, U, dt)
% Measurement Jacobian dh/dx  (4x7)
% z = [T2; T3; T5; N]
% x = [T2; T3; T4; ec; eb; et; N]
global gam prn en_nom
%T5 = T4(1-en(1-(prn^((gam-1)/gam))))
dT5_dT4 = 1-en_nom*(1-(prn^((gam-1)/gam)));

%         T2        T3        T4        ec        eb        et        N   -- 
H = [
          1,         0,        0,        0,        0,        0,          0;
          0,         1,        0,        0,        0,        0,          0;
          0,         0,        dT5_dT4,  0,        0,        0,          0;
          0,         0,        0,        0,        0,        0,          1;
];

end

function obs_rank = compute_observability_rank(F, H)
n = size(F,1);
O = H;
F_power = eye(n);
for i = 1:n-1
    F_power = F_power * F;
    O = [O; H * F_power];
end
obs_rank = rank(O);
end


%% Plotting
% Temperature estimation errors and 2-sigma bounds
figure('Position',[100 100 1600 600]);
tiledlayout(1,3,'TileSpacing','compact','Padding','tight');
nexttile;
plot_estimator(t, xhatu(1,:), Pu(1,1,:), x_true(1,:), 'error',z(1,:))
ylabel('Compressor Inlet Temperature-T2 (K)');
axis([0 100 -15 15]);

nexttile;
plot_estimator(t, xhatu(2,:), Pu(2,2,:), x_true(2,:), 'error',z(2,:))
ylabel('Turbine Inlet Temperature-T3 (K)');
axis([0 100 -15 15]);

nexttile;
plot_estimator(t, xhatu(3,:), Pu(3,3,:), x_true(3,:), 'error')
ylabel('Turbine Exit Temperature-T4 (K)');
axis([0 100 -15 15]);


% Efficiency estimation errors and 2-sigma bounds
figure('Position',[100 100 1600 600]);
tiledlayout(1,3,'TileSpacing','compact','Padding','tight');
nexttile;
plot_estimator(t, xhatu(4,:), Pu(4,4,:), x_true(4,:), 'error')
ylabel('Compressor Efficiency');
axis([0 100 -0.1 0.1]);

nexttile;
plot_estimator(t, xhatu(5,:), Pu(5,5,:), x_true(5,:), 'error')
ylabel('Burner Efficiency');
axis([0 100 -0.1 0.1]);

nexttile;
plot_estimator(t, xhatu(6,:), Pu(6,6,:), x_true(6,:), 'error')
ylabel('Turbine Efficiency');

% RPM
figure('Position',[100 100 1200 500]);
tiledlayout(1,1,'TileSpacing','compact','Padding','tight');
plot_estimator(t, xhatu(7,:), Pu(7,7,:), x_true(7,:), 'error',z(4,:))
ylabel('N(RPM)');
axis([0 100 -100 100]);

%% Startup
function MAE6760startup(font_size)
global MCcolors;
MCcolors.red    = [200,0,0]/255;
MCcolors.blue   = [4,51,255]/255;
MCcolors.purple = [147,23,255]/255;
MCcolors.green  = [0,160,0]/255;
MCcolors.orange = [253,128,8]/255;
MCcolors.mag    = [255,64,255]/255;
MCcolors.cyan   = [0,230,255]/255;

set(groot,'DefaultFigureUnits','pixels');
set(groot,'DefaultFigurePosition',[100 100 1600 600]);
set(groot,'DefaultFigureWindowStyle','normal');
set(groot,'DefaultAxesFontSize',16);
set(groot,'DefaultAxesFontWeight','bold');
set(groot,'DefaultLineLineWidth',2);
end
