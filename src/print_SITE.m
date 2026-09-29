function ax = print_SITE(mdl,NSEt,NSEe,ax)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%PRINT_SITE  Live ECDFs of NSE for training + evaluation period
%
% SYNOPSIS: ax = print_SITE(mdl,NSEt,NSEe,ax)
%
% INPUT ARGUMENTS:
%   mdl         structure with crr_model to use and settings
%    .model      choice of model
%                 1 hymod
%                 2 hmodel
%                 3 sacsma
%                 4 xinanjiang
%                 5 gr4j
%                 6 hbv
%                 7 cfe_nwm
%                 8 gr4jB [analytic routing]
%                11 gchm [optional/private]
%                99 user_model
%    .names      list of model names
%   NSEt        vector (or Kx1) of NSE in training period
%   NSEe        vector (or Kx1) of NSE in evaluation period
%   ax          struct with handles/state; pass [] on first call
%
% OUTPUT ARGUMENTS:
%   ax          updated handle struct for subsequent calls
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% © Written by Jasper A. Vrugt, Feb. 2026                                 %
% University of California Irvine                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -----------------
% Style / constants
% -----------------
fntsize_labels = 17;
fntsize_text = 20;
fntsize_title = 17;
fntsize_axis = 17;
fill_alpha = 0.20;
line_width = 1.5;
xL = -1;
xR =  1;

% ---------- colors ----------
colors = [  0.8500 0.0000 0.0000;   % hymod: red
            0.0000 0.6000 0.0000;   % hmodel: green
            0.5000 0.0000 0.7000;   % sacsma: purple
            0.6000 0.3000 0.1000;   % xinanjiang: brown
            0.0000 0.4470 0.7410;   % gr4j: blue
            1.0000 0.5000 0.0000;   % hbv: orange
            0.9000 0.0000 0.9000;   % cfe_nwm: magenta
            0.0000 0.7000 0.7000;   % gr4jB: teal/cyan
            0.8500 0.3250 0.0980;   % gchm: copper
            0.4940 0.1840 0.5560;   % user_model: violet
            0.6500 0.6500 0.6500];  % unknown: light gray

model = mdl.model;

% model label + color
try
    mdl_pr = upper(char(sage_model_name(model)));
catch
    mdl_pr = sprintf('MODEL_%d',model);
end
catalogIds = [1:8 11 99];
colorIndex = find(catalogIds == model,1,'first');
if isempty(colorIndex)
    colorIndex = size(colors,1);
end
c = colors(colorIndex,:);
% train/val naming (period vs basins)
% if K_t == K
%     nameT = 'Train basins';
%     nameE = 'Eval period';
% else
%     nameT = 'Train basins';
%     nameE = 'Eval basins';
% end
nameT = 'Train basins';
% sanitize inputs
NSEt = NSEt(:);
NSEe = NSEe(:);
It = isfinite(NSEt); 
nt = nnz(It); 
NSEt_use = NSEt(It);
Ie = isfinite(NSEe); 
ne = nnz(Ie); 
NSEe_use = NSEe(Ie);
% --------------
% Init if needed
% --------------
needInit = (nargin < 4) ...
    || isempty(ax) ...
    || ~isstruct(ax) ...
    || ~isfield(ax,'fig1') ...
    || ~isgraphics(ax.fig1) ...
    || ~isfield(ax,'t') ...
    || ~isgraphics(ax.t) ...
    || ~isfield(ax,'e') ...
    || ~isgraphics(ax.e) ...
    || ~isfield(ax,'inited') ...
    || ~ax.inited;
if needInit
    fig1 = figure('units','inches', ...
        'paperOrientation','landscape', ...
        'position',[0.5 0.5 16 8], ...
        'color','w', ...
        'Name','ECDF of NSE');
    tlo = tiledlayout(fig1,1,2, ...
        'tilespacing','loose', ...
        'padding','loose');
    ax = struct();
    ax.fig1 = fig1;
    ax.tlo = tlo;
    ax.t = nexttile(tlo,1);
    ax.e = nexttile(tlo,2);
    ax.inited = true;
    hold(ax.t,'on'); hold(ax.e,'on');
    box(ax.t,'on');  box(ax.e,'on');
    set([ax.t ax.e], ...
        'fontsize',fntsize_axis, ...
        'linewidth',1, ...
        'tickdir','out', ...
        'layer','top', ...
        'xlim',[xL xR], ...
        'ylim',[0 1]);
    xlabel(ax.t,'${\rm NSE}_{\rm t}$', ...
        'interpreter','latex', ...
        'fontsize',fntsize_labels);
    ylabel(ax.t,'$F({\rm NSE}_{\rm t})$', ...
        'interpreter','latex', ...
        'fontsize',fntsize_labels);
    xlabel(ax.e,'${\rm NSE}_{\rm e}$', ...
        'interpreter','latex', ...
        'fontsize',fntsize_labels);
    ylabel(ax.e,'$F({\rm NSE}_{\rm e})$', ...
        'interpreter','latex', ...
        'fontsize',fntsize_labels);
    % S_IB text blocks (upper-left)
    ax.txt_t = text(ax.t,0.05,0.95,'', ...
        'units','normalized', ...
        'horizontalalignment','left', ...
        'verticalalignment','top', ...
        'fontsize',fntsize_text, ...
        'fontweight','bold', ...
        'interpreter','latex');
    ax.txt_e = text(ax.e,0.05,0.95,'', ...
        'units','normalized', ...
        'horizontalalignment','left', ...
        'verticalalignment','top', ...
        'fontsize',fntsize_text, ...
        'fontweight','bold', ...
        'interpreter','latex');
    % ECDF handles (single patch + line per panel)
    ax.p_t = gobjects(1); 
    ax.l_t = gobjects(1);
    ax.p_e = gobjects(1); 
    ax.l_e = gobjects(1);
    % Median annotation handles
    ax.med_v_t = gobjects(1); 
    ax.med_h_t = gobjects(1);
    ax.med_s_t = gobjects(1); 
    ax.med_tx_t = gobjects(1);
    ax.med_v_e = gobjects(1); 
    ax.med_h_e = gobjects(1);
    ax.med_s_e = gobjects(1); 
    ax.med_tx_e = gobjects(1);
    % Add right y-axes (ticks only) via overlay axes
    ax = local_add_right_yaxis_overlay(ax,'t');
    ax = local_add_right_yaxis_overlay(ax,'e');
    drawnow nocallbacks;
    pause(0.001);
end

% update titles
title_t = sprintf('\\texttt{%s}: %s ($K_{\\rm t} = %d$)', ...
    mdl_pr,[nameT ': train period'],nt);
title_e = sprintf('\\texttt{%s}: %s ($K_{\\rm t} = %d$)', ...
    mdl_pr,[nameT ': eval period'],ne);
% --> reflects the number of finite NSE values; should equal # train basins
title(ax.t,title_t, ...
    'fontsize',fntsize_title, ...
    'interpreter','latex');
title(ax.e,title_e, ...
    'fontsize',fntsize_title, ...
    'interpreter','latex');
% keep overlays synced (limits/ticks can change later)
local_sync_overlay(ax,'t');
local_sync_overlay(ax,'e');

% -----------
% TRAIN panel
% -----------
if nt >= 1
    % [ft,xt] = ecdf(NSEt_use);
    [ft,xt] = sage_ecdf(NSEt_use); % no Statistics and Machine Learning Tlb
    [xs_t,fs_t] = ecdf_to_stairs_fixed( ...
        xt,ft,xL,xR);
    [xp_t,yp_t] = stairs_fill_poly( ...
        xs_t,fs_t);
    if ~isgraphics(ax.p_t)
        ax.p_t = patch(ax.t,xp_t,yp_t,c, ...
            'facealpha',fill_alpha, ...
            'edgealpha',0);
        ax.l_t = plot(ax.t,xs_t,fs_t, ...
            'color',c, ...
            'linewidth',line_width);
    else
        set(ax.p_t,'XData',xp_t, ...
            'YData',yp_t, ...
            'facecolor',c);
        set(ax.l_t,'XData',xs_t, ...
            'YData',fs_t, ...
            'color',c);
    end
    Tnset = median(NSEt_use);
    FmedT = ecdf_value_from_stairs( ...
        xs_t,fs_t,Tnset);
    SIBt = vf_score_from_stairs( ...
        xs_t,fs_t);
    set(ax.txt_t,'string', ...
        sprintf(['$\\widehat{\\mathcal{S}}_' ...
        '{\\mathrm{IBt}} = %.3f$'],SIBt));
    ax = draw_median_marker_shared( ...
        ax,'t',Tnset,FmedT,xL,xR);
else
    set(ax.txt_t,'string', ...
        ['$\widehat{\mathcal{S}}_{\mathrm{IBt}} =' ...
        '\mathrm{NA}$']);
    if isgraphics(ax.p_t) 
        set(ax.p_t, ...
            'XData',[], ...
            'YData',[]); 
    end
    if isgraphics(ax.l_t)
        set(ax.l_t, ...
            'XData',[], ...
            'YData',[]); 
    end
    hide_median_shared(ax,'t');
end

% ----------
% EVAL panel
% ----------
if ne >= 1
    % [fv,xv] = ecdf(NSEe_use);
    [fe,xe] = sage_ecdf(NSEe_use); % no Statistics and Machine Learning Tlb
    [xs_e,fs_e] = ecdf_to_stairs_fixed( ...
        xe,fe,xL,xR);
    [xp_e,yp_e] = stairs_fill_poly( ...
        xs_e,fs_e);
    if ~isgraphics(ax.p_e)
        ax.p_e = patch(ax.e,xp_e,yp_e,c, ...
            'FaceAlpha',fill_alpha, ...
            'edgealpha',0);
        ax.l_e = plot(ax.e,xs_e,fs_e, ...
            'color',c, ...
            'linewidth',line_width);
    else
        set(ax.p_e,'XData',xp_e, ...
            'YData',yp_e, ...
            'facecolor',c);
        set(ax.l_e,'XData',xs_e, ...
            'YData',fs_e, ...
            'color',c);
    end
    TNSEe = median(NSEe_use);
    FmedE = ecdf_value_from_stairs( ...
        xs_e,fs_e,TNSEe);
    SIBe = vf_score_from_stairs( ...
        xs_e,fs_e);
    set(ax.txt_e,'string', ...
        sprintf(['$\\widehat{\\mathcal{S}}_' ...
        '{\\mathrm{IBe}} = %.3f$'],SIBe));
    ax = draw_median_marker_shared( ...
        ax,'e',TNSEe,FmedE,xL,xR);
else
    set(ax.txt_e,'string', ...
        ['$\widehat{\mathcal{S}}_' ...
        '{\mathrm{IBe}} = ' ...
        '\mathrm{NA}$']);
    if isgraphics(ax.p_e)
        set(ax.p_e, ...
            'XData',[], ...
            'YData',[]); 
    end
    if isgraphics(ax.l_e)
        set(ax.l_e, ...
            'XData',[], ...
            'YData',[]);
    end
    hide_median_shared(ax,'e');
end
% limits + clipping
xlim(ax.t,[xL xR]); xlim(ax.e,[xL xR]);
ylim(ax.t,[0 1]); ylim(ax.e,[0 1]);
if isgraphics(ax.p_t) 
    set(ax.p_t,'Clipping','on'); 
end
if isgraphics(ax.l_t)
    set(ax.l_t,'Clipping','on'); 
end
if isgraphics(ax.p_e)
    set(ax.p_e,'Clipping','on'); 
end
if isgraphics(ax.l_e)
    set(ax.l_e,'Clipping','on'); 
end
% refresh overlays and draw
local_sync_overlay(ax,'t');
local_sync_overlay(ax,'e');
drawnow nocallbacks;
pause(0.001);

end

% -------------
% Local helpers
% -------------
function ax = local_add_right_yaxis_overlay(ax,whichpanel)
% Adds a transparent overlay axes that shows a right y-axis (ticks only).
if whichpanel == 't'
    base = ax.t;
    fld = 'tR';
else
    base = ax.e;
    fld = 'eR';
end
if isfield(ax,fld) ...
        && isgraphics(ax.(fld))
    return;
end
fig = ancestor(base,'figure');
axR = axes(fig, ...
    'position',base.Position, ...
    'color','none', ...
    'xlim',base.XLim, ...
    'ylim',base.YLim, ...
    'xaxislocation','bottom', ...
    'yaxislocation','right', ...
    'xtick',[], ...             % never show top/bottom ticks here
    'xticklabel',[], ...
    'box','off', ...
    'hittest','off', ...
    'handlevisibility','off');
% Right ticks on; labels off to avoid duplication
axR.YTickMode = 'auto';
axR.YTickLabel = [];            % keep ticks but no labels
axR.TickDir = 'out';
axR.LineWidth = base.LineWidth;
axR.FontSize = base.FontSize;
axR.YColor = base.XColor;       % black-ish
% Keep it behind plotted data but above background
uistack(axR,'bottom');
uistack(base,'top');
ax.(fld) = axR;
end

function local_sync_overlay(ax,whichpanel)
% Sync overlay axes limits/position to the base axes.
if whichpanel == 't'
    base = ax.t;  fld = 'tR';
else
    base = ax.e;  fld = 'eR';
end
if ~isfield(ax,fld) ...
        || ~isgraphics(ax.(fld))
    return;
end
axR = ax.(fld);
try
    axR.Position = base.Position;
    axR.XLim = base.XLim;
    axR.YLim = base.YLim;
    axR.YTick = base.YTick;      % match tick locations
catch
end
end
