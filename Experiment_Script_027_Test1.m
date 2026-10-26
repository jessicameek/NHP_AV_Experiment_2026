%% Experiment Script for 027 %%%%%%%%%%%%%%%%%%%%%%%%%%
% Psychtoolbox  Auditory Motion Stimulus presentation
% written 04/21/22 - Jackson Mayfield
% updated 10/26/26 Jessica Meek
% v3.6 - FINAL FIX:
%   y_fix_point_distance_from_center = 425
%   Geometry confirmed from RDK_Draw.m and AV_Stimulus_Presentation.m source:
%     - Fixation dot drawn at k_pix (near bottom of screen — INTENTIONAL)
%     - RDK aperture centered at visstim_center = k_pix - 517 (above fixation)
%     - 517 px separation between fixation and RDK is by design for NHP rig
%   On this screen (864px, yCenter=432):
%     k_pix          = 432 + 425 = 857  (on screen, 7px margin)
%     visstim_center = 857 - 517 = 340  (RDK center)
%     RDK top edge   = 340 - 330 = 10   (on screen, 10px margin)
%     RDK bottom     = 340 + 330 = 670  (on screen)
%   Per-trial counters reset each trial (fix from v3.4 retained)
clear;
close all;
sca;

sampling_rate                    = 24414*2;
y_fix_point_distance_from_center = 425; % Intentionally near bottom of screen.
                                         % Fixation is BELOW RDK by design (NHP rig).
                                         % 432+425=857 on screen, 857-517=340 RDK center.
                                         % DO NOT increase above 432 on this 864px screen.

Version               = 'Experiment_027_v.3.6';
file_directory        = 'C:\Jackson\Adriana Stuff\AV_Motion_Discrimination_Experiment\Mixed_Modality_and_AV_Exp';
data_file_directory   = 'C:\Jackson\Adriana Stuff\AV_Behavioral_Data\';
figure_file_directory = 'C:\Jackson\Adriana Stuff\AV_Figures\';

fixation_training = 0;
if fixation_training == 1
    target_reward = 'N/A';
end

addpath('C:\Jackson\Adriana Stuff\AV_Motion_Discrimination_Experiment\Mixed_Modality_and_AV_Exp\Auditory Stimulus');
addpath('C:\Jackson\Adriana Stuff\AV_Motion_Discrimination_Experiment\Mixed_Modality_and_AV_Exp\Eye_Movement_Data');


%% Output Settings
TDT = TDTRP([file_directory '\Exp_Circuit.rcx'],'RX8');

output_filename = input('Please Input experiment filename as DATE_MONKEY_BLOCK#\nex = 042122_Bravo_2 : ','s');
if isempty(output_filename)
    return;
else
    save_name = output_filename;
end

check_go        = 1;
file_name_check = [data_file_directory save_name '.mat'];
file_check      = dir(file_name_check);
if ~isempty(file_check)
    button = questdlg('File name exists, do you want to continue?',...
        'Continue Operation','Yes','No','Help','No');
    if strcmp(button,'Yes')
        disp('Creating file');        check_go = 1;
    elseif strcmp(button,'No')
        disp('Canceled file operation'); check_go = 0;
    elseif strcmp(button,'Help')
        disp('Sorry, no help available'); check_go = 0;
    end
end
if ~check_go; return; end


%% Psychtoolbox
PsychDefaultSetup(2);
screenNumber = 2;
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
[screenXpixels, screenYpixels] = Screen('WindowSize', screenNumber);
[xCenter, yCenter] = RectCenter([0 0 screenXpixels screenYpixels]);

% Safety checks — verify full geometry before opening window
k_pix_check        = yCenter + y_fix_point_distance_from_center;
visstim_check      = k_pix_check - 517;
rdk_radius_check   = 220/2/10 * 30; % apXYD(3)/2/10 * ppd
fprintf('=== GEOMETRY CHECK ===\n');
fprintf('Screen height    = %d px\n',   screenYpixels);
fprintf('yCenter          = %.0f px\n', yCenter);
fprintf('Fixation k_pix   = %.0f px\n', k_pix_check);
fprintf('RDK center       = %.0f px\n', visstim_check);
fprintf('RDK top edge     = %.0f px\n', visstim_check - rdk_radius_check);
fprintf('RDK bottom edge  = %.0f px\n', visstim_check + rdk_radius_check);
fprintf('======================\n');

if k_pix_check >= screenYpixels
    error('Fixation k_pix=%.0f is off-screen (height=%d).', k_pix_check, screenYpixels);
end
if visstim_check - rdk_radius_check < 0
    error('RDK top edge=%.0f is off-screen. Reduce y_fix_point_distance_from_center.', ...
        visstim_check - rdk_radius_check);
end

[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);
Screen('Flip', window);
ifi          = Screen('GetFlipInterval', window);
waitframes   = 1;
refresh_rate = 1/ifi;
rng('shuffle');


%% Structure Initialisation
monWidth = 40;
viewDist = 55;

[ExpInfo, vstruct, dotInfo, audInfo, AVInfo] = CreateClassStructure_MCS_AV(monWidth, viewDist, xCenter, yCenter);
disp(ExpInfo)

time_wait_frames        = round(ExpInfo.time_wait./ifi);
fix_time_frames         = round((ExpInfo.fixation_time/1000)/ifi) + time_wait_frames(1);
fix_only_time_frames    = round((ExpInfo.fixation_time/1000)/ifi);
stim_time_frames        = round((ExpInfo.stim_time/1000)/ifi);
aud_time_frames         = round(((audInfo.t_end - audInfo.t_start)/1000)/ifi);
iti_time_frames         = round((ExpInfo.iti/1000)/ifi);
TO_time_frames          = round((ExpInfo.fail_timeout/1000)/ifi);
target_time_frames      = round((ExpInfo.target_fixation_time/1000)/ifi + time_wait_frames(2));
target_only_time_frames = round((ExpInfo.target_fixation_time/1000)/ifi);


%% Fixation Position Structure
[dot_coord] = position_coordinates(screenXpixels, screenYpixels, xCenter, yCenter);


%% Target Parameters
target_distance_from_fixpoint_pix   = 350;
target_y_coord_pix                  = 205;
target_y_coord_volts                = 2.9982;
volts_per_pixel                     = 0.0078125;
target_distance_from_fixpoint_volts = 2.7344;
center_x_coord_pix                  = 640;


%% Block-level State
eye_data_matrix    = [];
BreakState         = 0;
output_counter     = 0;
block_counter      = 1;
total_blocks       = 1;
total_trials       = ExpInfo.num_trials;
dataout            = cell(total_trials+1, 11);

audtrial_counter   = 0;
vistrial_counter   = 0;
AVtrial_counter    = 0;
catchtrial_counter = 0;

pause(2);
rdk_reward = 'NaN';
aud_reward = 'NaN';
av_reward  = 'NaN';


%% ================================================================
%% MAIN BLOCK LOOP
%% ================================================================
while (BreakState ~= 1) && (block_counter <= total_blocks)

    trialcounter = 1;
    coh_counter  = 1;
    disp(['Trial #: ',num2str(trialcounter),'/',num2str(total_trials)])
    output_counter = output_counter + 1;
    dataout(output_counter,1:11) = {'Trial #' 'Position #' 'Fixation Correct' ...
        'Stimulus Reward' 'Catch Trial' 'Target Correct' 'Total Trial Time (sec)' ...
        'Coherence Level' 'Direction of Motion' 'Incorrect Target Fixation' 'Stimulus Modality'};
    start_block_time = hat;
    audInfo.mux = 0;

    %% ===========================================================
    %% TRIAL LOOP
    %% ===========================================================
    while (trialcounter <= total_trials) && (BreakState ~= 1)

        output_counter   = output_counter + 1;
        start_trial_time = hat;

        %% Reset ALL per-trial state (fix from v3.4)
        fix_timeout               = 0;
        rdk_timeout               = 0;
        aud_timeout               = 0;
        av_timeout                = 0;
        targ_timeout              = 0;
        correct_counter           = 0;
        aud_correct_counter       = 0;
        correct_counter2          = 0;
        incorrect_counter2        = 0;
        end_fixation_waitframes   = 0;
        end_target_waitframes     = 0;
        stim_reward               = 'N/A';
        target_reward             = 'N/A';
        incorrect_target_fixation = 'N/A';
        rdk_reward                = 'No';
        aud_reward                = 'No';
        av_reward                 = 'No';
        fix_reward                = 'No';

        if ExpInfo.random_incorrect_opacity_list(trialcounter) == 0
            catchtrial                = 'Yes';
            target_reward             = 'N/A';
            incorrect_target_fixation = 'N/A';
            fix_point_color           = white;
            catchtrial_counter        = catchtrial_counter + 1;
        elseif ExpInfo.random_incorrect_opacity_list(trialcounter) == 1
            catchtrial      = 'No';
            fix_point_color = white;
        end

        ExpInfo.modality = ExpInfo.trial_modality_list{trialcounter};
        switch ExpInfo.modality
            case 'AUD'
                audtrial_counter = audtrial_counter + 1;
                audInfo.dir = audInfo.random_dir_list(1, audtrial_counter);
                audInfo.coh = audInfo.random_coh_list(1, audtrial_counter);
            case 'VIS'
                vistrial_counter = vistrial_counter + 1;
                dotInfo.dir = dotInfo.random_dir_list(1, vistrial_counter);
                dotInfo.coh = dotInfo.random_coh_list(1, vistrial_counter);
            case 'AV'
                AVtrial_counter = AVtrial_counter + 1;
                AVInfo.dir      = AVInfo.random_dir_list(1, AVtrial_counter);
                AVInfo.coh_aud  = AVInfo.aud_random_coh_list(1, AVtrial_counter);
                AVInfo.coh_dot  = AVInfo.dot_random_coh_list(1, AVtrial_counter);
        end

        if (dotInfo.dir == 0   && strcmp(ExpInfo.modality,'VIS')) || ...
           (audInfo.dir == 1   && strcmp(ExpInfo.modality,'AUD')) || ...
           (AVInfo.dir  == 1   && strcmp(ExpInfo.modality,'AV'))
            disp(ExpInfo.modality); disp('Left to Right')
            if strcmp(ExpInfo.modality,'VIS'),       disp(dotInfo.coh)
            elseif strcmp(ExpInfo.modality,'AUD'),   disp(audInfo.coh)
            elseif strcmp(ExpInfo.modality,'AV')
                disp(['AUD Coh - ', num2str(AVInfo.coh_aud)])
                disp(['VIS Coh - ', num2str(AVInfo.coh_dot)])
            end
        elseif (dotInfo.dir == 180 && strcmp(ExpInfo.modality,'VIS')) || ...
               (audInfo.dir == 0   && strcmp(ExpInfo.modality,'AUD')) || ...
               (AVInfo.dir  == 0   && strcmp(ExpInfo.modality,'AV'))
            disp(ExpInfo.modality); disp('Right to Left')
            if strcmp(ExpInfo.modality,'VIS'),       disp(dotInfo.coh)
            elseif strcmp(ExpInfo.modality,'AUD'),   disp(audInfo.coh)
            elseif strcmp(ExpInfo.modality,'AV')
                disp(['AUD Coh - ', num2str(AVInfo.coh_aud)])
                disp(['VIS Coh - ', num2str(AVInfo.coh_dot)])
            end
        end

        if strcmp(ExpInfo.modality,'AUD')
            [audInfo.CAM] = makeCAM(audInfo.coh, audInfo.dir, audInfo.set_dur, 0, sampling_rate);
            CAM_1 = audInfo.CAM(:,1);  CAM_2 = audInfo.CAM(:,2);
            ramp_dur = 0.004;
            [CAM_1_Cut_Ramped, CAM_2_Cut_Ramped, audInfo.window_duration, audInfo.ramp_dur] = ...
                aud_receptive_field_location(CAM_1, CAM_2, audInfo.t_start, audInfo.t_end, sampling_rate, ramp_dur);
            TDT.write('mux_sel', audInfo.mux);
            TDT.write('window',  audInfo.window_duration);
            TDT.write('ramp_dur',audInfo.ramp_dur);
            TDT.write('CAM_1',   CAM_1_Cut_Ramped);
            TDT.write('CAM_2',   CAM_2_Cut_Ramped);

        elseif strcmp(ExpInfo.modality,'AV')
            [AVInfo.CAM] = makeCAM(AVInfo.coh_aud, AVInfo.dir, audInfo.set_dur, 0, sampling_rate);
            CAM_1 = AVInfo.CAM(:,1);  CAM_2 = AVInfo.CAM(:,2);
            ramp_dur = 0.004;
            [CAM_1_Cut_Ramped, CAM_2_Cut_Ramped, audInfo.window_duration, audInfo.ramp_dur] = ...
                aud_receptive_field_location(CAM_1, CAM_2, audInfo.t_start, audInfo.t_end, sampling_rate, ramp_dur);
            TDT.write('mux_sel', audInfo.mux);
            TDT.write('window',  audInfo.window_duration);
            TDT.write('ramp_dur',audInfo.ramp_dur);
            TDT.write('CAM_1',   CAM_1_Cut_Ramped);
            TDT.write('CAM_2',   CAM_2_Cut_Ramped);
        end

        %% Fixation and RDK positions
        % dot_coord.Ypos_5 = k_pix = 432+425 = 857 (fixation, near bottom — intentional)
        % visstim_center   =         857-517  = 340 (RDK center, above fixation)
        % RDK top edge     =         340-330  = 10  (on screen)
        pos = ExpInfo.random_list(trialcounter);
        dot_coord.Ypos_5 = yCenter + y_fix_point_distance_from_center;

        [h_pix, k_pix]         = xypos(pos, dot_coord);
        [h_voltage, k_voltage] = pos_voltage(pos, dot_coord);

        visstim_center = dot_coord.Ypos_5 - 517; % DO NOT CHANGE — confirmed correct

        fprintf('Trial %d | %s | fix_y=%.0f | rdk_y=%.0f\n', ...
            trialcounter, ExpInfo.modality, k_pix, visstim_center);


        %% -------------------------------------------------------
        %% FIXATION PERIOD
        %% -------------------------------------------------------
        Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
        Screen('DrawDots', window, [h_pix k_pix], ExpInfo.fixpoint_size_pix, fix_point_color, [], 2);
        vbl = Screen('Flip', window);

        for frame = 1:fix_time_frames - waitframes

            x = TDT.read('x');
            y = TDT.read('y');
            [eye_data_matrix] = Send_Eye_Position_Data(TDT, start_block_time, eye_data_matrix, 1, trialcounter);
            d = sqrt(((x-h_voltage).^2)+((y-k_voltage).^2));

            if frame < time_wait_frames(1)
                Screen('DrawDots', window, [h_pix k_pix], ExpInfo.fixpoint_size_pix, fix_point_color, [], 2);
                vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                if d <= ExpInfo.rew_radius_volts
                    correct_counter = correct_counter + 1;
                    if frame > 10; end_fixation_waitframes = 1; end
                end
                if d >= ExpInfo.rew_radius_volts && end_fixation_waitframes == 1
                    correct_counter = 0;
                    for frame_2 = 1:TO_time_frames
                        Screen('FillRect', window, black);
                        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                        fix_timeout = 1;
                    end
                    break
                end
                if correct_counter > fix_only_time_frames; break; end
            end

            if frame > time_wait_frames(1)
                Screen('DrawDots', window, [h_pix k_pix], ExpInfo.fixpoint_size_pix, fix_point_color, [], 2);
                vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                if correct_counter > fix_only_time_frames; break; end
                if d <= ExpInfo.rew_radius_volts
                    correct_counter = correct_counter + 1;
                else
                    correct_counter = 0;
                    for frame_2 = 1:TO_time_frames
                        Screen('FillRect', window, black);
                        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                        fix_timeout = 1;
                    end
                    break
                end
            end
        end % fixation frame loop

        if correct_counter > fix_time_frames - waitframes - time_wait_frames(1)
            fix_timeout     = 0;
            correct_counter = 0;
            fix_reward      = 'Yes';
        else
            fix_timeout = 1;
            fix_reward  = 'No';
        end


        %% -------------------------------------------------------
        %% STIMULUS PERIOD
        %% -------------------------------------------------------
        if strcmp(ExpInfo.modality,'VIS')
            aud_reward  = 'No';  av_reward  = 'No';
            rdk_timeout = 0;     aud_timeout = 0;    av_timeout = 0;

            if fix_timeout ~= 1
                [rdk_timeout, eye_data_matrix] = RDK_Draw(ExpInfo, dotInfo, window, ...
                    xCenter, visstim_center, h_voltage, k_voltage, TDT, ...
                    start_block_time, eye_data_matrix, trialcounter, fix_point_color, k_pix);
                if rdk_timeout ~= 1
                    rdk_reward = 'Yes';
                    if fixation_training == 1 || strcmp(catchtrial,'Yes')
                        TDT.trg(1);
                    end
                else
                    rdk_reward = 'No';
                    for frame_3 = 1:TO_time_frames
                        Screen('FillRect', window, black);
                        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                    end
                end
            end

        elseif strcmp(ExpInfo.modality,'AUD')
            rdk_reward  = 'No';  av_reward  = 'No';
            rdk_timeout = 0;     aud_timeout = 0;    av_timeout = 0;

            TDT.write('aud_off', 0);
            if fix_timeout ~= 1
                TDT.trg(2);

                for frame = 1:aud_time_frames - waitframes
                    x = TDT.read('x');
                    y = TDT.read('y');
                    [eye_data_matrix] = Send_Eye_Position_Data(TDT, start_block_time, eye_data_matrix, 2, trialcounter);
                    d = sqrt(((x-h_voltage).^2)+((y-k_voltage).^2));

                    Screen('DrawDots', window, [h_pix k_pix], ExpInfo.fixpoint_size_pix, fix_point_color, [], 2);
                    vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);

                    if d <= ExpInfo.rew_radius_volts
                        aud_correct_counter = aud_correct_counter + 1;
                        if frame > 10; end_fixation_waitframes = 1; end
                    end
                    if d >= ExpInfo.rew_radius_volts && end_fixation_waitframes == 1
                        aud_correct_counter = 0;
                        for frame_2 = 1:TO_time_frames
                            Screen('FillRect', window, black);
                            vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                            aud_timeout = 1;
                            TDT.write('aud_off', 1);
                            aud_reward = 'No';
                        end
                        break
                    end
                end

                if aud_correct_counter > fix_time_frames - waitframes - time_wait_frames(1)
                    aud_timeout = 0;  aud_correct_counter = 0;  aud_reward = 'Yes';
                    if fixation_training == 1 || strcmp(catchtrial,'Yes')
                        TDT.trg(1);
                        incorrect_target_fixation = 'N/A';
                    end
                else
                    aud_reward = 'N/A';
                end
            end

        elseif strcmp(ExpInfo.modality,'AV')
            rdk_reward  = 'No';  aud_reward  = 'No';
            rdk_timeout = 0;     aud_timeout = 0;    av_timeout = 0;

            TDT.write('aud_off', 0);
            % AV_Stimulus_Presentation fires TDT.trg(2) internally
            if fix_timeout ~= 1
                [av_timeout] = AV_Stimulus_Presentation(ExpInfo, dotInfo, AVInfo, window, ...
                    xCenter, visstim_center, h_voltage, k_voltage, TDT, k_pix);
                if av_timeout ~= 1
                    av_reward = 'Yes';
                    if fixation_training == 1 || strcmp(catchtrial,'Yes')
                        TDT.trg(1);
                    end
                else
                    av_reward = 'No';
                    for frame_3 = 1:TO_time_frames
                        Screen('FillRect', window, black);
                        vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                    end
                end
            else
                av_reward = 'N/A';  aud_reward = 'N/A';  rdk_reward = 'N/A';
            end
        end

        if strcmp(rdk_reward,'Yes') || strcmp(aud_reward,'Yes') || strcmp(av_reward,'Yes')
            stim_reward = 'Yes';
        end


        %% -------------------------------------------------------
        %% TARGET / DECISION PERIOD
        %% -------------------------------------------------------
        targ_timeout = 0;
        if fix_timeout ~= 1 && (aud_timeout ~= 1 && rdk_timeout ~= 1 && av_timeout ~= 1) ...
                && fixation_training ~= 1 && strcmp(catchtrial,'No')

            [right_target_color, left_target_color, correct_target] = ...
                percentage_target_color_selection(dotInfo, audInfo, AVInfo, ExpInfo, trialcounter);

            for frame = 1:target_time_frames - waitframes

                x = TDT.read('x');
                y = TDT.read('y');
                [eye_data_matrix] = Send_Eye_Position_Data(TDT, start_block_time, eye_data_matrix, 3, trialcounter);

                Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA', [1 1 1 1]);
                Screen('DrawDots', window, [(center_x_coord_pix + target_distance_from_fixpoint_pix) target_y_coord_pix], ExpInfo.targpoint_size_pix, right_target_color, [], 2);
                Screen('DrawDots', window, [(center_x_coord_pix - target_distance_from_fixpoint_pix) target_y_coord_pix], ExpInfo.targpoint_size_pix, left_target_color,  [], 2);
                vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);

                dR = sqrt(((x-(0+target_distance_from_fixpoint_volts)).^2)+((y-(0+target_y_coord_volts)).^2));
                dL = sqrt(((x-(0-target_distance_from_fixpoint_volts)).^2)+((y-(0+target_y_coord_volts)).^2));
                isRightTargetFixation = (dR <= ExpInfo.target_rew_radius_volts);
                isLeftTargetFixation  = (dL <= ExpInfo.target_rew_radius_volts);
                isAnyTargetFixation   = (isRightTargetFixation || isLeftTargetFixation);

                if frame < time_wait_frames(2)
                    Screen('DrawDots', window, [(center_x_coord_pix + target_distance_from_fixpoint_pix) target_y_coord_pix], ExpInfo.targpoint_size_pix, right_target_color, [], 2);
                    Screen('DrawDots', window, [(center_x_coord_pix - target_distance_from_fixpoint_pix) target_y_coord_pix], ExpInfo.targpoint_size_pix, left_target_color,  [], 2);
                    vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);

                    if (isRightTargetFixation && strcmp('right',correct_target)) || (isLeftTargetFixation && strcmp('left',correct_target))
                        correct_counter2 = correct_counter2 + 1;  end_target_waitframes = 1;
                    end
                    if ~isAnyTargetFixation && end_target_waitframes == 1
                        correct_counter2 = 0;
                        for frame_2 = 1:TO_time_frames
                            Screen('FillRect', window, black);
                            vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                            targ_timeout = 1;
                        end
                        break
                    end
                    if correct_counter2 > target_only_time_frames; break; end
                    if (isLeftTargetFixation && strcmp('right',correct_target)) || (isRightTargetFixation && strcmp('left',correct_target)) && end_target_waitframes == 0
                        incorrect_counter2 = incorrect_counter2 + 1;
                    end
                    if incorrect_counter2 > target_only_time_frames; break; end
                end

                if frame > time_wait_frames(2)
                    if correct_counter2 > target_only_time_frames; break; end
                    if (isRightTargetFixation && strcmp('right',correct_target)) || (isLeftTargetFixation && strcmp('left',correct_target))
                        correct_counter2 = correct_counter2 + 1;
                    elseif (isLeftTargetFixation && strcmp('right',correct_target)) || (isRightTargetFixation && strcmp('left',correct_target)) && end_target_waitframes == 0
                        incorrect_counter2 = incorrect_counter2 + 1;
                    else
                        correct_counter2 = 0;  incorrect_counter2 = 0;
                        for frame_2 = 1:TO_time_frames
                            Screen('FillRect', window, black);
                            vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
                            targ_timeout = 1;
                        end
                        break
                    end
                end
            end % target frame loop

            if correct_counter2 > target_time_frames - waitframes - time_wait_frames(2)
                targ_timeout = 0;  TDT.trg(1);  correct_counter2 = 0;  target_reward = 'Yes';
            else
                target_reward = 'No';
            end
            if incorrect_counter2 > target_time_frames - waitframes - time_wait_frames(2)
                incorrect_target_fixation = 'Yes';  incorrect_counter2 = 0;
            else
                incorrect_target_fixation = 'No';
            end
        end


        %% -------------------------------------------------------
        %% TIMEOUT CLEANUP
        %% -------------------------------------------------------
        if fix_timeout == 1
            fix_timeout = 0;  stim_reward = 'N/A';
            target_reward = 'N/A';  incorrect_target_fixation = 'N/A';
        end
        if aud_timeout == 1 || rdk_timeout == 1 || av_timeout == 1
            rdk_timeout = 0;  aud_timeout = 0;  av_timeout = 0;
            stim_reward = 'No';  target_reward = 'N/A';  incorrect_target_fixation = 'N/A';
        end
        if targ_timeout == 1
            targ_timeout = 0;  target_reward = 'No';  incorrect_target_fixation = 'N/A';
        end


        %% -------------------------------------------------------
        %% ITI
        %% -------------------------------------------------------
        for frame = 1:iti_time_frames
            [eye_data_matrix] = Send_Eye_Position_Data(TDT, start_block_time, eye_data_matrix, 4, trialcounter);
            Screen('FillRect', window, black);
            vbl = Screen('Flip', window, vbl + (waitframes - 0.5) * ifi);
        end


        %% -------------------------------------------------------
        %% TRIAL DATA OUTPUT
        %% -------------------------------------------------------
        end_trial_time = hat;
        trial_time     = end_trial_time - start_trial_time;

        if strcmp(ExpInfo.modality,'AUD')
            dataout(output_counter,1:11) = {trialcounter pos fix_reward stim_reward catchtrial target_reward trial_time audInfo.coh audInfo.dir incorrect_target_fixation ExpInfo.modality};
        elseif strcmp(ExpInfo.modality,'VIS')
            dataout(output_counter,1:11) = {trialcounter pos fix_reward stim_reward catchtrial target_reward trial_time dotInfo.coh dotInfo.dir incorrect_target_fixation ExpInfo.modality};
        elseif strcmp(ExpInfo.modality,'AV')
            dataout(output_counter,1:11) = {trialcounter pos fix_reward stim_reward catchtrial target_reward trial_time [AVInfo.coh_aud,AVInfo.coh_dot] AVInfo.dir incorrect_target_fixation ExpInfo.modality};
        end

        trialcounter = trialcounter + 1;
        if trialcounter <= total_trials
            disp(['Trial #: ',num2str(trialcounter),'/',num2str(total_trials)])
        end

    end % trial loop


    %% =============================================================
    %% END OF BLOCK
    %% =============================================================
    [AUD_dataout, VIS_dataout, AV_dataout] = modality_splitter(dataout);
    [audInfo.cohFreq] = cohFreq_finder(AUD_dataout, audInfo);
    [dotInfo.cohFreq] = cohFreq_finder(VIS_dataout, dotInfo);
    [AVInfo.cohFreq_aud, AVInfo.cohFreq_vis] = cohFreq_finder_AV(AV_dataout, AVInfo);

    if trialcounter < ExpInfo.num_trials
        total_trials  = trialcounter;  n_catchtrials = catchtrial_counter;
    else
        total_trials  = ExpInfo.num_trials;  n_catchtrials = audInfo.catchtrials;
    end
    num_regular_trials = total_trials - n_catchtrials;
    num_catch_trials   = n_catchtrials;

    [Fixation_Success_Rate, Stim_Success_Rate, Target_Success_Rate_Regular, Target_Success_Rate_Catch] = ...
        SR_CALC(dataout, total_trials, num_regular_trials, num_catch_trials)

    if audInfo.n_aud_trials ~= 0; prob_AUD = coherence_probability(AUD_dataout, audInfo); end
    if dotInfo.n_vis_trials ~= 0; prob_VIS = coherence_probability(VIS_dataout, dotInfo); end
    if AVInfo.n_AV_trials   ~= 0; prob_AV  = coherence_probability_AV(AV_dataout, AVInfo); end

    [AUD_Right_dataout, AUD_Left_dataout] = direction_splitter(AUD_dataout,'AUD');
    [VIS_Right_dataout, VIS_Left_dataout] = direction_splitter(VIS_dataout,'VIS');
    [AV_Right_dataout,  AV_Left_dataout ] = direction_splitter(AV_dataout, 'AV');

    [audInfo.cohFreq_right] = cohFreq_finder(AUD_Right_dataout, audInfo);
    [dotInfo.cohFreq_right] = cohFreq_finder(VIS_Right_dataout, dotInfo);
    [audInfo.cohFreq_left ] = cohFreq_finder(AUD_Left_dataout,  audInfo);
    [dotInfo.cohFreq_left ] = cohFreq_finder(VIS_Left_dataout,  dotInfo);
    [AVInfo.cohFreq_right_aud, AVInfo.cohFreq_right_vis] = cohFreq_finder_AV(AV_Right_dataout, AVInfo);
    [AVInfo.cohFreq_left_aud,  AVInfo.cohFreq_left_vis ] = cohFreq_finder_AV(AV_Left_dataout,  AVInfo);

    if dotInfo.n_vis_trials ~= 0
        VIS_prob_Right = directional_probability(VIS_Right_dataout, dotInfo,'Right','VIS');
        VIS_prob_Left  = directional_probability(VIS_Left_dataout,  dotInfo,'Left', 'VIS');
    else; VIS_prob_Right = []; VIS_prob_Left = []; end
    if audInfo.n_aud_trials ~= 0
        AUD_prob_Right = directional_probability(AUD_Right_dataout, audInfo,'Right','AUD');
        AUD_prob_Left  = directional_probability(AUD_Left_dataout,  audInfo,'Left', 'AUD');
    else; AUD_prob_Right = []; AUD_prob_Left = []; end
    if AVInfo.n_AV_trials ~= 0
        AV_prob_Right = directional_probability_AV(AV_Right_dataout, AVInfo,'Right');
        AV_prob_Left  = directional_probability_AV(AV_Left_dataout,  AVInfo,'Left');
    else; AV_prob_Right = []; AV_prob_Left = []; end

    if AVInfo.n_AV_trials ~= 0 || audInfo.n_aud_trials ~= 0 & dotInfo.n_vis_trials ~= 0
        [fig_3_AUD_VIS_AV_MCS, AUD_curve_xvals, VIS_curve_xvals, AV_curve_xvals, ...
         AUD_curve_yvals, VIS_curve_yvals, AV_curve_yvals, ...
         AUD_xData, AUD_yData, VIS_xData, VIS_yData, AV_xData, AV_yData, ...
         AUD_mu, VIS_mu, AV_mu, AUD_std_gaussian, VIS_std_gaussian, AV_std_gaussian, ...
         AUD_prop_Rresp_zerocoh, VIS_prop_Rresp_zerocoh, AV_prop_Rresp_zerocoh] = ...
            psychometric_plotter_modalities(AUD_dataout, VIS_dataout, AV_dataout, ...
            AUD_prob_Right, AUD_prob_Left, VIS_prob_Right, VIS_prob_Left, ...
            AV_prob_Right, AV_prob_Left, audInfo, dotInfo, AVInfo, save_name);
        ax = gca; hold on
        text(-0.5,.90,"displacement (degrees): "+sprintf('%.2f',ExpInfo.rdk_angle),'FontSize',12);
        text(-0.5,.85,"velocity (degrees/s): "  +audInfo.velocity,                 'FontSize',12);
        text(-0.5,.80,"duration (s): "           +sprintf('%.3f',ExpInfo.stim_time/1000),'FontSize',12);
        resizeFigures();
        saveas(fig_3_AUD_VIS_AV_MCS,[figure_file_directory save_name '_Psyc_Func_LR_MMAV_MCS.png']);
        saveas(fig_3_AUD_VIS_AV_MCS,[figure_file_directory save_name '_Psyc_Func_LR_MMAV_MCS.fig']);
    end
    if AVInfo.n_AV_trials==0 & audInfo.n_aud_trials==0 & dotInfo.n_vis_trials~=0
        [VIS_x,VIS_y,VIS_fig,~,~,~,VIS_std_gaussian_scaled] = ...
            psychometric_plotter_unisensory(VIS_dataout,VIS_prob_Right,VIS_prob_Left,dotInfo,save_name);
        resizeFigures();
        saveas(VIS_fig,[figure_file_directory save_name '_Psyc_Func_LR_VIS_MCS.png']);
    end
    if AVInfo.n_AV_trials==0 & audInfo.n_aud_trials~=0 & dotInfo.n_vis_trials==0
        [AUD_x,AUD_y,AUD_fig,~,~,~,AUD_std_gaussian_scaled] = ...
            psychometric_plotter_unisensory(AUD_dataout,AUD_prob_Right,AUD_prob_Left,audInfo,save_name);
        resizeFigures();
        saveas(AUD_fig,[figure_file_directory save_name '_Psyc_Func_LR_AUD_MCS.png']);
    end

    if audInfo.n_aud_trials ~= 0
        AUD_prob_right_only = coherence_probability_1_direction(AUD_Right_dataout,audInfo,'Right','AUD');
        AUD_prob_left_only  = coherence_probability_1_direction(AUD_Left_dataout, audInfo,'Left', 'AUD');
    end
    if dotInfo.n_vis_trials ~= 0
        VIS_prob_right_only = coherence_probability_1_direction(VIS_Right_dataout,dotInfo,'Right','VIS');
        VIS_prob_left_only  = coherence_probability_1_direction(VIS_Left_dataout, dotInfo,'Left', 'VIS');
    end
    if AVInfo.n_AV_trials ~= 0
        [R_fig_AV_MCS] = psychometric_plotter_1_direction_modalities(AUD_prob_right_only, ...
            VIS_prob_right_only,AV_prob_Right,'RIGHT ONLY',audInfo,dotInfo,AVInfo,save_name);
        [L_fig_AV_MCS] = psychometric_plotter_1_direction_modalities(AUD_prob_left_only, ...
            VIS_prob_left_only, AV_prob_Left, 'LEFT ONLY', audInfo,dotInfo,AVInfo,save_name);
        saveas(R_fig_AV_MCS,[figure_file_directory save_name '_Psyc_Func_R_MMAV_MCS.png']);
        saveas(L_fig_AV_MCS,[figure_file_directory save_name '_Psyc_Func_L_MMAV_MCS.png']);
    end

    times            = cell2mat(dataout(2:end,7));
    Total_Block_Time = sum(times);
    block_counter    = block_counter + 1;

end % block loop


%% ================================================================
%% POST-BLOCK
%% ================================================================
[n_trials_with_response, n_trials_with_reward, ...
 proportion_response_reversals_after_correct_response, ...
 proportion_response_reversals_after_incorrect_response] = ...
    response_reversal_proportions_mixedmodality(dataout)

save([data_file_directory save_name]);
teba_file_directory    = 'Z:\Jackson\Adriana Stuff\AV_Behavioral_Data';
at_teba_file_directory = 'Z:\Adam\Monkey_Raw_Behavior';
try
    save([data_file_directory    save_name]);
    save([teba_file_directory    save_name]);
    save([at_teba_file_directory save_name]);
    disp('Experiment Data Exported to BOTH Local Drive and TEBA Drive.')
catch
    save([data_file_directory save_name]);
    disp('Experiment Data Exported ONLY to Local Drive.')
end
sca;
TDT.halt();


%% ================================================================
%% LOCAL FUNCTION: CreateClassStructure_MCS_AV
%% ================================================================
function [ExpInfo, dstruct, dotInfo, audInfo, AVInfo] = ...
    CreateClassStructure_MCS_AV(monWidth, viewDist, xCenter, yCenter)

dotInfo = struct; AVInfo = struct; audInfo = struct;

dotInfo.cohSet       = [100 70.7 50 35.4 25 17.7 12.5 8.9 6.3 4.5 3.2 0]./100;
dotInfo.coh_Freq_Set = [5 0 0 0 0 0 0 0 0 0 0 0];
dotInfo.n_vis_trials = sum(dotInfo.coh_Freq_Set);
audInfo.cohSet       = dotInfo.cohSet;
audInfo.coh_Freq_Set = [5 0 0 0 0 0 0 0 0 0 0 0];
audInfo.n_aud_trials = sum(audInfo.coh_Freq_Set);
AVInfo.coh_Freq_Set  = [0 0 0 0 0 0 0 0 0 0 0 0];
AVInfo.n_AV_trials   = sum(AVInfo.coh_Freq_Set);

ExpInfo.rew_angle            = 11;
ExpInfo.iti                  = 950;
ExpInfo.fail_timeout         = 2500;
ExpInfo.rdk_angle            = 22;
ExpInfo.stim_time            = 834;
ExpInfo.fixation_time        = 200;
ExpInfo.target_fixation_time = 150;
ExpInfo.t_angle              = 0.4;
ExpInfo.catch_trials         = 0;
ExpInfo.positions            = [0;0;0;0;1;0;0;0;0];
ExpInfo.possible_pos         = find(ExpInfo.positions == 1);
ExpInfo.time_wait            = [1, 1.7];

dotInfo.speed    = 59.95 * 10;
audInfo.velocity = 59.95;

ExpInfo.num_trials = dotInfo.n_vis_trials + audInfo.n_aud_trials + AVInfo.n_AV_trials;
ExpInfo.catch_trials = 0;
ExpInfo.random_incorrect_opacity_list = catch_trial_randomizer(ExpInfo);
ExpInfo.random_list = zeros(1, ExpInfo.num_trials);
for i = 1:ExpInfo.num_trials
    r_index = randi(length(ExpInfo.possible_pos));
    ExpInfo.random_list(i) = ExpInfo.possible_pos(r_index);
end
[ExpInfo] = MCS_modalitylist(ExpInfo, audInfo, dotInfo, AVInfo);

dstruct.res  = [1280 1024];
dstruct.size = [monWidth 30];
dstruct.dis  = viewDist;

ExpInfo.fixpoint_size_pix       = angle2pixels(ExpInfo.t_angle);
ExpInfo.targpoint_size_pix      = ExpInfo.fixpoint_size_pix;
ExpInfo.rew_radius_volts        = angle2volts(ExpInfo.rew_angle);
ExpInfo.target_rew_radius_volts = angle2volts(9);
ExpInfo.ppd                     = 30;

data = zeros(40,1);
data(30:33,1) = [1 0 0 1];
data(21:24,1) = [0 1 0 1];

dotInfo.dir             = NaN;
dotInfo.catchtrials     = 0;
dotInfo.dirSet          = dirBin_vis(data);
dotInfo.rdk_size_pix    = angle2pixels(ExpInfo.rdk_angle);
dotInfo.coherences      = dotInfo.cohSet;
dotInfo.random_coh_list = cohSet_maker_MCS(dotInfo);
dotInfo.random_dir_list = dir_randomizer_MCS_unisensory(dotInfo);
dotInfo.apXYD           = [0 55 220];
dotInfo.dotSize         = 4;
dotInfo.numDotField     = 1;
dotInfo.dotColor        = [255 255 255];
dotInfo.maxDotTime      = ExpInfo.stim_time / 1000;
dotInfo.Incorrect_Opacity   = 1;
dotInfo.maxDotsPerFrame     = 200;

audInfo.displacement    = audInfo.velocity * (ExpInfo.stim_time / 1000);
audInfo.dir             = NaN;
audInfo.dirSet          = dirBin(data);
audInfo.catchtrials     = 0;
audInfo.coherences      = audInfo.cohSet;
audInfo.random_coh_list = cohSet_maker_MCS(audInfo);
audInfo.random_dir_list = dir_randomizer_MCS_unisensory(audInfo);
audInfo.set_dur           = 78 / audInfo.velocity;
stim_midpoint             = (audInfo.set_dur * 1000) / 2;
half_desired_duration     = ExpInfo.stim_time / 2;
audInfo.t_start           = stim_midpoint - half_desired_duration;
audInfo.t_end             = stim_midpoint + half_desired_duration;
audInfo.Incorrect_Opacity = 1;

AVInfo.dir = NaN;
if AVInfo.n_AV_trials ~= 0
    AVInfo.cohSet_dot      = dotInfo.cohSet;
    AVInfo.cohSet_aud      = audInfo.cohSet;
    AVInfo.coherences_dot  = AVInfo.cohSet_dot;
    AVInfo.coherences_aud  = AVInfo.cohSet_aud;
    AVInfo.dirSet          = dirBin(data);
    [AVInfo.aud_random_coh_list, AVInfo.dot_random_coh_list] = cohSet_maker_MCS_AV(AVInfo);
    AVInfo.random_dir_list = dir_randomizer_MCS_AV(AVInfo);
else
    AVInfo.coherences_dot = []; AVInfo.coherences_aud = []; AVInfo.dirSet = [];
    AVInfo.cohSet_dot = []; AVInfo.cohSet_aud = [];
    AVInfo.aud_random_coh_list = []; AVInfo.dot_random_coh_list = [];
    AVInfo.random_dir_list = [];
end

end % CreateClassStructure_MCS_AV