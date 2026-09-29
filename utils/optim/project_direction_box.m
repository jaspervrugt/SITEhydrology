function p = project_direction_box(x,p,l,u,b_eps)
%PROJECT_DIRECTION_BOX Zero direction components that would step outside box.
if nargin < 5, b_eps = 0; end
xl = l + b_eps;
xu = u - b_eps;

atL = x <= xl;
atU = x >= xu;

p(atL & (p < 0)) = 0;   % would go below lower bound
p(atU & (p > 0)) = 0;   % would go above upper bound
end
