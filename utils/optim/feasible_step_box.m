function a = feasible_step_box(x,p,l,u,b_eps)
%FEASIBLE_STEP_BOX Largest alpha>=0 such that x+alpha*p stays in box.
if nargin < 5, b_eps = 0; end
xl = l + b_eps;
xu = u - b_eps;

a = inf;

idx = p > 0;
if any(idx)
    a = min(a, min((xu(idx) - x(idx)) ./ p(idx)));
end

idx = p < 0;
if any(idx)
    a = min(a, min((xl(idx) - x(idx)) ./ p(idx))); % p<0 => ratio positive
end

if ~isfinite(a) || a < 0
    a = 0;
end
end
