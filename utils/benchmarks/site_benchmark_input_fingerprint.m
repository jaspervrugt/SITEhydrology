function fingerprint=site_benchmark_input_fingerprint(ctx)
% Canonical SHA-256 of prepared forcing, observations and scoring windows.
% Numerical values rounded to 1e-9 input units to suppress platform roundoff.
md=java.security.MessageDigest.getInstance('SHA-256');
feed('SITE-input-v1');
walk(ctx.dat.meteo,'meteo');walk(ctx.dat.obs,'obs');
for key={'time','t','date','dates'}
 if isfield(ctx.dat,key{1}),walk(ctx.dat.(key{1}),key{1});end
end
walk(ctx.mdl.id_train,'id_train');walk(ctx.mdl.id_eval,'id_eval');
fingerprint=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
 function feed(s),bytes=unicode2native([char(s) char(0)],'UTF-8');md.update(bytes,int32(0),int32(numel(bytes)));end
 function walk(v,label)
  if isstruct(v)
   assert(isscalar(v),'SITE:FingerprintShape','Input structures must be scalar');
   names=sort(fieldnames(v));
   for n=1:numel(names)
    name=names{n};
    if any(strcmp(name,{'source','path','file','filename','cache','metadata'})),continue,end
    walk(v.(name),[label '.' name]);
   end
  elseif isnumeric(v)||islogical(v)
   feed(label);d=double(v);if isvector(d),d=d(:);end
   feed(sprintf('%d,',size(d)));d=round(d*1e9)/1e9;d(d==0)=0;
   bits=typecast(d(:),'uint64');bits(isnan(d(:)))=uint64(9221120237041090560);
   [~,~,endian]=computer;if endian=='B',bits=swapbytes(bits);end
   bytes=typecast(bits(:),'int8');if ~isempty(bytes),md.update(bytes(:).',int32(0),int32(numel(bytes)));end
  elseif isdatetime(v)
   walk(datenum(v),label);
  elseif (ischar(v)||isstring(v))&&endsWith(label,'.units')
   feed(label);feed(string(v));
  end
 end
end
