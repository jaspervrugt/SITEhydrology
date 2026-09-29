function x = project_box(x,l,u,b_eps)
%PROJECT_BOX Project x into [l+b_eps, u-b_eps] (or [l,u] if b_eps==0).
if nargin < 4, b_eps = 0; end
if b_eps > 0
    x = min(max(x, l + b_eps), u - b_eps);
else
    x = min(max(x, l), u);
end
end
