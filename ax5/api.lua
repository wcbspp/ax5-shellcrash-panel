local M=dofile('/data/ShellCrash/ax5/common.lua')
local H=require('luci.http');local D=require('luci.dispatcher')
local A={}
local function reply(v,code) H.status(code or 200);H.header('Cache-Control','no-store');H.prepare_content('application/json');H.write(M.json.encode(v))end
local function body()
 local n=tonumber(H.getenv('CONTENT_LENGTH')) or 0;if n>262144 then return nil end
 local raw=H.formvalue('payload');local ok,d=pcall(M.json.decode,raw or '');if ok and type(d)=='table' then return d end
end
local function csrf()
 return H.getenv('HTTP_X_SC_CSRF')==M.read(M.R..'/csrf'):gsub('%s+$','') and #M.read(M.R..'/csrf')>16
end
function A.panel()
 local base=D.build_url('web','shellcrash');local html=M.read(M.C..'/ui/index.html');html=html:gsub('@@BASE@@',base)
 H.header('Cache-Control','no-store');H.prepare_content('text/html');H.write(html)
end
function A.asset()
 local name=H.formvalue('name') or '';local allowed={['manager.js']=true,['health.js']=true,['sites.js']=true,['google.svg']=true,['tencent.svg']=true}
 if not allowed[name]then reply({error='not_found'},404);return end
 H.prepare_content(name:match('%.svg$')and'image/svg+xml'or'application/javascript');H.write(M.read(M.C..'/ui/'..name))
end
function A.read()
 local kind=H.formvalue('kind');H.header('Cache-Control','no-store')
 if kind=='auth' then
  if not M.run('mkdir -p '..M.R)then reply({error='runtime_missing'},500);return end
  if M.read(M.R..'/csrf')==''then M.run('umask 077; head -c 24 /dev/urandom | base64 > '..M.R..'/csrf')end
  reply({token_b64='',control_token=M.read(M.R..'/csrf'):gsub('%s+$','')});return
 elseif kind=='zerotier'then reply(M.zerotier());return
 elseif kind=='zerotierlog'then H.prepare_content('text/plain');H.write(M.read(M.R..'/zerotier-diagnostic',8192));return
 elseif kind=='state'then reply(M.state());return end
 local paths={filter=M.C..'/configs/fake_ip_filter.list',subscription=M.R..'/subscription.raw',memory=M.R..'/memory.csv',incidents=M.R..'/incidents',logs=M.R..'/core.log'}
 if not paths[kind]then reply({error='not_found'},404);return end
 H.prepare_content('text/plain');local text=M.read(paths[kind],262144)
 if kind=='logs'then text=text..'\n'..M.read(M.R..'/service.log',32768)..'\n'..M.read(M.R..'/worker.log',32768)..'\n'..M.read(M.R..'/last-exit.txt',16384)..'\n'..M.read(M.R..'/subscription-tool.log',8192);text=text:gsub('https?://[^%s]+','[链接已隐藏]')end
 H.write(text)
end
function A.upload()
 if H.getenv('REQUEST_METHOD')~='POST'or not csrf()then reply({error='forbidden'},403);return end
 local d=body();if not d or type(d.id)~='string'or not d.id:match('^%x%x%x%x%x%x%x%x$')or not ({source=true,bounds=true,filter=true,mirror=true})[d.kind]or type(d.data)~='string'or #d.data>200000 then reply({error='invalid_upload'},400);return end
 local job=M.load(M.R..'/job.json');if job.active then reply({error='busy'},409);return end
 local ok,raw=pcall(require('nixio').bin.b64decode,d.data);if not ok or not raw then reply({error='invalid_upload'},400);return end
 M.write(M.R..'/upload-'..d.kind,raw);M.write(M.R..'/upload-id-'..d.kind,d.id);reply({ok=true})
end
function A.control()
 if H.getenv('REQUEST_METHOD')~='POST'or not csrf()then reply({error='forbidden'},403);return end
 local d=body();local allowed={start=true,stop=true,restart=true,clear=true,cleanup=true,memcfg=true,fetch=true,apply=true,dns=true,rules=true,domainupdate=true,corecheck=true,coreupdate=true,toolcheck=true,toolupdate=true,mirrorsave=true,mirrorsync=true}
 if not d or type(d.script)~='string'then reply({error='invalid_action'},400);return end
 local action=d.script:match('^sc%-(%w+)%.sh$');if not allowed[action]then reply({error='unsupported_action'},400);return end
 local args=d.args or {};if type(args)~='table'or #args>3 then reply({error='invalid_arguments'},400);return end;for _,v in ipairs(args)do if type(v)~='string'or #v>100 or not v:match('^[%w+/=]+$')then reply({error='invalid_arguments'},400);return end end
 if not M.lock('operation.lock',900)then reply({error='busy'},409);return end
 local id=args[1]or'';if id~=''and not id:match('^%x%x%x%x%x%x%x%x$')then os.remove(M.R..'/operation.lock');reply({error='invalid_id'},400);return end
 M.save(M.R..'/request.json',{action=action,args=args})
 M.save(M.R..'/job.json',{active=true,phase='working',id=id,message_b64=M.b64('service_operation')})
 M.run('(umask 077; lua '..M.C..'/ax5/job.lua > '..M.R..'/worker.log 2>&1) </dev/null >/dev/null 2>&1 &')
 reply({ok=true})
end
function A.api()
 if not csrf()then reply({error='forbidden'},403);return end
 local path=H.formvalue('path')or'';local method=H.getenv('REQUEST_METHOD');if method=='POST'then method='PUT'end
 if #path>2048 or path:find('[\r\n]')or not (path=='/version'or path=='/connections'or path=='/proxies'or path:match('^/proxies/'))or not ({GET=true,PUT=true})[method]then reply({error='invalid_api'},400);return end
 local data='';if method=='PUT'then local d=body();if not d or type(d.name)~='string'or #d.name>256 then reply({error='invalid_node'},400);return end;data=M.json.encode({name=d.name}) end
 local raw,status=M.request(path,method,data)
 if status<200 or status>=300 then reply({error='core_request_failed'},status>0 and status or 503);return end
 if method=='PUT'then reply({ok=true});return end
 local ok,v=pcall(M.json.decode,raw);if not ok then reply({error='core_unavailable'},503);return end;H.prepare_content('application/json');H.write(raw)
end
return A
