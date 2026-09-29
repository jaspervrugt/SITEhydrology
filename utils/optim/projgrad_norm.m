function pg = projgrad_norm(x,g,l,u,b_eps)
%PROJGRAD_NORM Norm of projected gradient for box constraints.
% component i is:
%   g_i if x_i strictly inside
%   min(0,g_i) at lower bound
%   max(0,g_i) at upper bound
if nargin < 5, b_eps = 0; end
xl = l + b_eps;
xu = u - b_eps;

pg_vec = g;

atL = x <= xl;
atU = x >= xu;

pg_vec(atL) = min(0, g(atL));
pg_vec(atU) = max(0, g(atU));

pg = norm(pg_vec);
end
