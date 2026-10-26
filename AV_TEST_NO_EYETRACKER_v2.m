
%% AV_TEST_NO_EYETRACKER_v2.m
% Inline RDK — no RDK_Draw(), no TDT eye reads.
% Fixation dot at screen center, RDK centered on same point.

clear; close all; sca;
%% ================================================================
%% SETTINGS
%% ================================================================
sampling_rate  = 24414 * 2;
screenNumber   = 2;
USE_TDT_AUDIO  = true;

file_directory = 'C:\Jackson\Adriana Stuff\AV_Motion_Discrimination_Experiment\Mixed_Modality_and_AV_Exp';

n_VIS_trials = 3;
n_AUD_trials = 3;
n_AV_trials  = 0;

stim_time_ms   = 834;
rdk_angle_deg  = 22;
dot_speed_degs = 59.95;
aud_velocity   = 59.95;
iti_ms         = 950;
monWidth       = 40;
viewDist       = 55;

%% ================================================================
%% PTB SETUP
%% ================================================================
PsychDefaultSetup(2);

available = Screen('Screens');
if ~ismember(screenNumber, available)
    screenNumber = max(available);
end

white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
[screenXpixels, screenYpixels] = Screen('WindowSize', screenNumber);
[xCenter, yCenter]             = RectCenter([0 0 screenXpixels screenYpixels]);

fprintf('Screen %d: %d x %d  center=(%.0f, %.0f)\n', ...
    screenNumber, screenXpixels, screenYpixels, xCenter, yCenter);

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);
Screen('Flip', window);

ifi        = Screen('GetFlipInterval', window);
waitframes = 1;
ppd        = pi * (screenXpixels/2) / atan(monWidth/viewDist/2) / 180;
fprintf('ifi=%.4f ms | refresh=%.1f Hz | ppd=%.2f px/deg\n', ifi*1000, 1/ifi, ppd);
rng('shuffle');

%% ================================================================
%% POSITIONS
%% FIX: fixation dot at screen center, RDK centered on same point
%% ================================================================
h_pix          = xCenter;   % fixation X = screen center X = 576
k_pix          = yCenter;   % fixation Y = screen center Y = 432  <-- CHANGED from 812
rdk_center_x   = xCenter;   % RDK aperture X = 576
rdk_center_y   = yCenter;   % RDK aperture Y = 432

fprintf('Fixation dot:  (%.0f, %.0f)\n', h_pix, k_pix);
fprintf('RDK center:    (%.0f, %.0f)\n', rdk_center_x, rdk_center_y);

fixpoint_size_pix = max(round(0.4 * ppd), 8); % minimum 8 px so it is visible

%% ================================================================
%% RDK PARAMETERS
%% ================================================================
rdk_radius_pix  = round((rdk_angle_deg / 2) * ppd);
dot_speed_pixs  = dot_speed_degs * ppd;
dot_speed_frame = dot_speed_pixs * ifi;
n_dots          = 200;
dot_size_pix    = 4;
stim_frames     = round((stim_time_ms/1000) / ifi);

fprintf('RDK radius: %.0f px  |  dot speed: %.2f px/frame\n', ...
    rdk_radius_pix, dot_speed_frame);

%% ================================================================
%% AUDITORY PARAMETERS
%% ================================================================
aud_set_dur      = 78 / aud_velocity;
stim_midpoint_ms = (aud_set_dur * 1000) / 2;
half_dur_ms      = stim_time_ms / 2;
aud_t_start      = stim_midpoint_ms - half_dur_ms;
aud_t_end        = stim_midpoint_ms + half_dur_ms;
aud_time_frames  = round(((aud_t_end - aud_t_start)/1000) / ifi);

%% ================================================================
%% TDT SETUP
%% ================================================================
if USE_TDT_AUDIO
    try
        TDT = TDTRP([file_directory '\Exp_Circuit.rcx'], 'RX8');
        TDT.write('aud_off', 0);
        fprintf('TDT connected OK.\n');
    catch ME
        warning('TDT connection failed: %s\nAudio disabled.', ME.message);
        USE_TDT_AUDIO = false;
    end
end

%% ================================================================
%% TRIAL LIST
%% ================================================================
modality_list = [repmat({'VIS'}, 1, n_VIS_trials), ...
                 repmat({'AUD'}, 1, n_AUD_trials), ...
                 repmat({'AV'},  1, n_AV_trials)];
modality_list = modality_list(randperm(length(modality_list)));
total_trials  = length(modality_list);

fprintf('\n=== TRIAL LIST ===\n');
for t = 1:total_trials
    fprintf('  Trial %d: %s\n', t, modality_list{t});
end
fprintf('==================\n\n');

%% ================================================================
%% MAIN TEST LOOP
%% ================================================================
vbl = Screen('Flip', window);

for trialcounter = 1:total_trials

    modality = modality_list{trialcounter};
    fprintf('\n--- Trial %d/%d  [%s] ---\n', trialcounter, total_trials, modality);

    % Random direction each trial
    vis_dir_deg = randsample([0 180], 1);
    aud_dir     = randsample([0 1],   1);
    fprintf('  VIS dir: %d deg  |  AUD dir: %d\n', vis_dir_deg, aud_dir);

    % Dot displacement per frame
    dx_per_frame =  cos(deg2rad(vis_dir_deg)) * dot_speed_frame;
    dy_per_frame = -sin(deg2rad(vis_dir_deg)) * dot_speed_frame;

    %% --------------------------------------------------------
    %% STEP 1: Fixation dot — 500 ms, center of screen
    %% --------------------------------------------------------
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    Screen('DrawDots', window, [h_pix k_pix], fixpoint_size_pix, white, [], 2);
    vbl = Screen('Flip', window);
    fprintf('  Fixation ON  (%.0f, %.0f)\n', h_pix, k_pix);

    fix_frames = round(0.5 / ifi);
    for frame = 1:fix_frames - waitframes
        Screen('DrawDots', window, [h_pix k_pix], fixpoint_size_pix, white, [], 2);
        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
    end
    fprintf('  Fixation period done\n');

    %% --------------------------------------------------------
    %% STEP 2: Stimulus
    %% --------------------------------------------------------
    switch modality

        %% -------------------- VISUAL -----------------------
        case 'VIS'
            fprintf('  >> RDK ON (dir=%d deg, 100%% coh, %d dots)\n', ...
                vis_dir_deg, n_dots);

            [dot_x, dot_y] = init_dots(n_dots, rdk_radius_pix);

            for frame = 1:stim_frames

                % Move dots
                dot_x = dot_x + dx_per_frame;
                dot_y = dot_y + dy_per_frame;

                % Wrap dots that exit the aperture
                out = sqrt(dot_x.^2 + dot_y.^2) > rdk_radius_pix;
                n_out = sum(out);
                if n_out > 0
                    new_xy = random_dots_in_circle(n_out, rdk_radius_pix);
                    dot_x(out) = new_xy(:,1);
                    dot_y(out) = new_xy(:,2);
                end

                % Convert to screen coordinates
                screen_x = rdk_center_x + dot_x';
                screen_y = rdk_center_y + dot_y';

                Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
                % Draw RDK field
                Screen('DrawDots', window, [screen_x; screen_y], ...
                    dot_size_pix, white, [], 2);
                % Draw fixation dot on top of RDK
                Screen('DrawDots', window, [h_pix k_pix], ...
                    fixpoint_size_pix, [255 0 0], [], 2); % red so visible over dots
                vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
            end
            fprintf('  >> RDK OFF\n');

        %% -------------------- AUDITORY ---------------------
        case 'AUD'
            fprintf('  >> Audio ON (dir=%d)\n', aud_dir);

            if USE_TDT_AUDIO
                [CAM]    = makeCAM(1.0, aud_dir, aud_set_dur, 0, sampling_rate);
                CAM_1    = CAM(:,1);
                CAM_2    = CAM(:,2);
                ramp_dur = 0.004;
                [CAM_1r, CAM_2r, win_dur, ramp_d] = aud_receptive_field_location(...
                    CAM_1, CAM_2, aud_t_start, aud_t_end, sampling_rate, ramp_dur);
                TDT.write('mux_sel', 0);
                TDT.write('window',  win_dur);
                TDT.write('ramp_dur',ramp_d);
                TDT.write('CAM_1',   CAM_1r);
                TDT.write('CAM_2',   CAM_2r);
                TDT.write('aud_off', 0);
                TDT.trg(2);
                fprintf('  >> TDT trigger fired\n');
            else
                fprintf('  >> TDT not connected — no audio\n');
            end

            for frame = 1:aud_time_frames - waitframes
                Screen('DrawDots', window, [h_pix k_pix], ...
                    fixpoint_size_pix, white, [], 2);
                Screen('DrawText', window, 'AUDIO', 30, 30, [255 255 0]);
                vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
            end
            fprintf('  >> Audio duration done\n');

        %% -------------------- AUDIOVISUAL ------------------
        case 'AV'
            fprintf('  >> AV ON\n');

            if USE_TDT_AUDIO
                [CAM]    = makeCAM(1.0, aud_dir, aud_set_dur, 0, sampling_rate);
                CAM_1    = CAM(:,1);
                CAM_2    = CAM(:,2);
                ramp_dur = 0.004;
                [CAM_1r, CAM_2r, win_dur, ramp_d] = aud_receptive_field_location(...
                    CAM_1, CAM_2, aud_t_start, aud_t_end, sampling_rate, ramp_dur);
                TDT.write('mux_sel', 0);
                TDT.write('window',  win_dur);
                TDT.write('ramp_dur',ramp_d);
                TDT.write('CAM_1',   CAM_1r);
                TDT.write('CAM_2',   CAM_2r);
                TDT.write('aud_off', 0);
                TDT.trg(2);
                fprintf('  >> AV audio trigger fired\n');
            end

            [dot_x, dot_y] = init_dots(n_dots, rdk_radius_pix);

            for frame = 1:stim_frames
                dot_x = dot_x + dx_per_frame;
                dot_y = dot_y + dy_per_frame;

                out = sqrt(dot_x.^2 + dot_y.^2) > rdk_radius_pix;
                n_out = sum(out);
                if n_out > 0
                    new_xy = random_dots_in_circle(n_out, rdk_radius_pix);
                    dot_x(out) = new_xy(:,1);
                    dot_y(out) = new_xy(:,2);
                end

                screen_x = rdk_center_x + dot_x';
                screen_y = rdk_center_y + dot_y';

                Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
                Screen('DrawDots', window, [screen_x; screen_y], ...
                    dot_size_pix, white, [], 2);
                Screen('DrawDots', window, [h_pix k_pix], ...
                    fixpoint_size_pix, [255 0 0], [], 2);
                vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
            end
            fprintf('  >> AV OFF\n');

    end % switch modality

    %% --------------------------------------------------------
    %% STEP 3: ITI — black screen
    %% --------------------------------------------------------
    Screen('FillRect', window, black);
    vbl = Screen('Flip', window);
    iti_frames = round((iti_ms/1000) / ifi);
    for frame = 1:iti_frames - waitframes
        Screen('FillRect', window, black);
        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
    end
    fprintf('  Trial %d done\n', trialcounter);

end % trial loop

%% ================================================================
%% DONE
%% ================================================================
Screen('FillRect', window, black);
Screen('DrawText', window, 'TEST COMPLETE - press any key', 100, yCenter, white);
Screen('Flip', window);
KbWait;
sca;
if USE_TDT_AUDIO; TDT.halt(); end

fprintf('\n=== CHECKLIST ===\n');
fprintf('Fixation dot at screen CENTER?                       Y/N\n');
fprintf('VIS: moving dot field around the fixation dot?      Y/N\n');
fprintf('AUD: audio sweep, fixation dot only?                Y/N\n');
fprintf('AV:  moving dots + audio together?                  Y/N\n');


%% ================================================================
%% LOCAL FUNCTIONS — must be at end of file
%% ================================================================
function [dot_x, dot_y] = init_dots(n, radius)
% Initialise n dot positions randomly inside a circle of given radius
    pts   = random_dots_in_circle(n, radius);
    dot_x = pts(:,1);
    dot_y = pts(:,2);
end

function pts = random_dots_in_circle(n, radius)
% Return n x 2 array of (x,y) positions uniformly inside a circle
    pts = zeros(n, 2);
    i   = 0;
    while i < n
        x = (rand*2 - 1) * radius;
        y = (rand*2 - 1) * radius;
        if sqrt(x^2 + y^2) <= radius
            i = i + 1;
            pts(i,:) = [x y];
        end
    end
end