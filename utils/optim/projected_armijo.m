function [x_new,f_new,g_new,alpha,ok] = projected_armijo(fun,x,f,g,p, ...
    alpha0,a_feas,l,u,opts)
%PROJECTED_ARMIJO Armijo backtracking on x(alpha) = P[x + alpha p].
% Requires fun(x) -> [f,~,g] (at least).
%
% opts fields used: c1, ls_rho, ls_max, b_eps

gTp = g' * p;

% Not a descent direction -> fail
if ~(isfinite(gTp) && gTp < 0)
    ok = false; alpha = 0;
    x_new = x; f_new = f; g_new = g;
    return;
end

alpha = alpha0;
ok = false;

for it = 1:opts.ls_max
    if alpha <= 1e-12*max(1,alpha0)
        break;
    end
    alpha = min(alpha, a_feas);
    x_trial = project_box(x + alpha*p, l, u, opts.b_eps);
    % Expect fun to return [f,~,g] at least
    [f_trial,~,g_trial] = fun(x_trial);
    if isfinite(f_trial) && (f_trial <= f + opts.c1 * alpha * gTp)
        x_new = x_trial;
        f_new = f_trial;
        g_new = g_trial;
        ok = true;
        return;
    end
    alpha = opts.ls_rho * alpha;
end
% fail
x_new = x; f_new = f; g_new = g;
end
