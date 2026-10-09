local M=dofile('/data/ShellCrash/ax5/common.lua')
local req=M.load(M.R..'/request.json');local args=req.args or {};local id=args[1]or''
local function phase(p,msg,active,extra)
 local d={id=id,phase=p,active=active,message_b64=M.b64(msg)};for k,v in pairs(extra or {})do d[k]=v end;M.save(M.R..'/job.json',d)
end
local function fail(msg) error(msg,0)end
local function service(action)
 if action=='restart'then service('stop');service('start');return end
 if action=='stop'then M.write(M.C..'/configs/enabled','0\n')else M.write(M.C..'/configs/enabled','1\n')end
 if not M.run('/data/ShellCrash-tool/start.sh '..action..' >> '..M.R..'/service.log 2>&1')then fail('service_'..action..'_failed')end
 if action=='stop'then for i=1,15 do if M.pid()==0 then return end;M.run('sleep 1')end;fail('service_stop_failed')end
 if action~='stop'then for i=1,12 do if M.pid()>0 and M.api('/version')~=''then return end;M.run('sleep 1')end;fail('service_start_failed')end
end
local function guard()if (M.memory().MemAvailable or 0)<M.limits().protect_mb*1024 then fail('memory_protected')end end
local function current()return M.load(M.C..'/configs/config.json')end
local function checked_save(cfg)
 dofile(M.C..'/ax5/config-normalize.lua').normalize(cfg)
 M.save(M.R..'/candidate.json',cfg)
 local old=M.read(M.C..'/configs/config.json');local running=M.pid()>0
 if old==M.read(M.R..'/candidate.json')then return end
 local kind=M.state().core_kind
 local paused=kind=='meta'and running
 if paused then service('stop')end
 local command
 if kind=='meta'then
  local A=dofile(M.C..'/ax5/mihomo.lua');M.write(M.R..'/candidate.yaml',M.encode(A.build(cfg)):gsub('\\/','/'))
  command=M.C..'/ax5/check-binary.sh meta '..M.R..'/CrashCore -t -d '..M.R..' -f '..M.R..'/candidate.yaml'
 else command='GOMEMLIMIT=12MiB GOGC=25 '..M.R..'/CrashCore check -D '..M.R..' -c '..M.R..'/candidate.json'end
 collectgarbage('collect')
 M.write(M.R..'/check-context', 'pid='..M.pid()..' available_kb='..(M.memory().MemAvailable or 0)..' lua_kb='..collectgarbage('count')..'\n')
 local ok=M.run(command..' > '..M.R..'/check.log 2>&1')
 if not ok then if paused then pcall(service,'start')end;fail('configuration_check_failed_previous_kept')end
 if running and not paused then service('stop')end
 local ok,err=pcall(function()
  M.write(M.C..'/configs/config.json.new',M.read(M.R..'/candidate.json'));assert(os.rename(M.C..'/configs/config.json.new',M.C..'/configs/config.json'))
  if running then service('start')end
 end)
 if not ok then
  M.write(M.C..'/configs/config.json',old);if running then pcall(service,'start')end;fail('start_failed_previous_restored')
 end
end
local function fetched(url,file)
 if #url>2048 or not url:match('^https?://')or url:find('[%s\r\n]')then fail('invalid_subscription_url')end
 local base='curl -4 -fsSL --connect-timeout 8 --max-time 25 --max-filesize 262144 '
 local proxy=M.pid()>0 and '--proxy http://127.0.0.1:7890 --noproxy "" 'or'--noproxy "*" '
 if not M.run(base..proxy..M.quote(url)..' -o '..M.quote(file))then
  if not M.run(base..'--noproxy "*" '..M.quote(url)..' -o '..M.quote(file))then fail('subscription_download_failed')end
 end
 if #M.read(file)>262144 or #M.read(file)<10 then fail('empty_subscription')end
end
local function upload(kind)
 if M.read(M.R..'/upload-id-'..kind)~=id then fail('invalid_upload')end
 return M.read(M.R..'/upload-'..kind,262144)
end
local function execute()
 local a=req.action
 if a=='start'or a=='stop'or a=='restart'then service(a);phase('done','service_operation_complete',false)
 elseif a=='clear'then M.write(M.R..'/core.log','');M.write(M.R..'/service.log','');M.write(M.R..'/subscription-tool.log','');phase('done','logs_cleared',false)
 elseif a=='cleanup'then M.cleanup(true);phase('done','memory_cleaned',false)
 elseif a=='memcfg'then
  guard();local w,p,c=(args[2]or''):match('^w(%d+)p(%d+)c(%d+)$');w,p,c=tonumber(w),tonumber(p),tonumber(c)
  if not w or not p or not c or p<12 or w<=p or w>64 or(c~=0 and(c<w or c>96))then fail('memory_settings_invalid')end
  M.save(M.C..'/configs/memory.json',{warning_mb=w,protect_mb=p,cleanup_mb=c});phase('done','memory_settings_saved',false)
 elseif a=='fetch'then
  guard();phase('fetching','downloading_subscription',true);local url=upload('source'):gsub('%s+$','');local mode=args[2]=='convert'and'convert'or'direct';if not M.run(M.C..'/ax5/subscription-tool.sh ax5 '..mode)then if mode=='direct'then fetched(url,M.R..'/subscription.raw')else fail('subscription_download_failed')end end;phase('downloaded','subscription_downloaded',false)
 elseif a=='apply'then
  guard();local out=M.json.decode(upload('bounds'));if type(out)~='table'or #out<3 or #out>540 then fail('invalid_upload')end
  local count=0;for _,n in ipairs(out)do
   if type(n.tag)~='string'or type(n.type)~='string'then fail('invalid_upload')end
   if n.type~='selector'and n.type~='urltest'and n.type~='block'then n.routing_mark=21315 end
   if n.server then count=count+1 end
  end
  if count==0 then fail('empty_subscription')end
  out[#out+1]={type='selector',tag='DIRECT',outbounds={'direct'},default='direct'}
  out[#out+1]={type='selector',tag='GLOBAL',outbounds={'proxy-main'},default='proxy-main'}
  local cfg=current();cfg.outbounds=out;checked_save(cfg)
  M.write(M.C..'/configs/subscription.new',upload('source'));assert(os.rename(M.C..'/configs/subscription.new',M.C..'/configs/subscription'))
  os.remove(M.C..'/configs/needs-subscription');if M.run(M.C..'/ax5/backup-config.sh >> '..M.R..'/service.log 2>&1')then phase('done','subscription_updated',false)else phase('done','configuration_saved_backup_pending',false)end
 elseif a=='dns'then
  guard();local mode=args[2]=='real'and'redir_host'or args[2]=='mix'and'mix';if not mode then fail('invalid_upload')end
  local filter=upload('filter');if #filter>16000 then fail('invalid_filter_previous_kept')end
  if not M.run('awk -f '..M.C..'/ax5/filter_compile.awk '..M.R..'/upload-filter > '..M.R..'/filter.json')then fail('invalid_filter_previous_kept')end
  local f=M.load(M.R..'/filter.json');local cfg=current();local dns=cfg.dns;local servers={}
  for _,s in ipairs(dns.servers)do if s.type~='fakeip'then servers[#servers+1]=s end end
  local rules={};for _,r in ipairs(dns.rules)do
   if r.ip_accept_any or r.rule_set or (r.domain and r.domain[1]=='localhost')then rules[#rules+1]=r end
  end
  if mode=='mix'then
   servers[#servers+1]={type='fakeip',tag='dns-fake',inet4_range='198.18.0.0/15'};f.server='dns-proxy';rules[#rules+1]=f
   rules[#rules+1]={query_type={'A'},server='dns-fake',rewrite_ttl=1}
  end
  rules[#rules+1]={query_type={'AAAA'},action='reject'};dns.servers=servers;dns.rules=rules
  local oldfilter=M.read(M.C..'/configs/fake_ip_filter.list');local oldmode=M.read(M.C..'/configs/dns-mode')
  M.write(M.C..'/configs/fake_ip_filter.list',filter);M.write(M.C..'/configs/dns-mode',mode)
  local ok,err=pcall(checked_save,cfg)
  if not ok then M.write(M.C..'/configs/fake_ip_filter.list',oldfilter);M.write(M.C..'/configs/dns-mode',oldmode);if M.pid()>0 then pcall(service,'restart')end;fail(err)end
  os.remove(M.C..'/configs/needs-subscription');if M.run(M.C..'/ax5/backup-config.sh >> '..M.R..'/service.log 2>&1')then phase('done','dns_updated',false)else phase('done','configuration_saved_backup_pending',false)end
 elseif a=='domainupdate'then
  guard();phase('working','database_updating',true);local result=dofile(M.C..'/ax5/database.lua').update(M,service);phase('done',result,false)
 elseif a=='rules'then
  guard();phase('fetching','downloading_rules',true);fetched('https://ispip.clang.cn/all_cn.txt',M.R..'/rules.raw')
  if not M.run('awk -f '..M.C..'/ax5/rules_validate.awk '..M.R..'/rules.raw > '..M.R..'/rules.new')then fail('rules_invalid_previous_kept')end
  local ips={};for line in M.read(M.R..'/rules.new'):gmatch('[^\n]+')do ips[#ips+1]=line end
  if #ips<1000 or #ips>10000 then fail('rules_invalid_previous_kept')end
  local cfg=current();local changed=0;for _,r in ipairs(cfg.route.rules)do if r.ip_cidr and #r.ip_cidr>1000 then r.ip_cidr=ips;changed=changed+1 end end
  if changed~=1 then fail('configuration_template_missing')end
  checked_save(cfg);M.write(M.C..'/configs/cn_ip.txt',table.concat(ips,'\n')..'\n');M.write(M.C..'/configs/rules-date',os.date('%Y-%m-%d %H:%M:%S'));os.remove(M.C..'/configs/needs-subscription');if M.run(M.C..'/ax5/backup-config.sh >> '..M.R..'/service.log 2>&1')then phase('done','rules_updated',false)else phase('done','configuration_saved_backup_pending',false)end
 elseif a=='coreupdate'then
  guard();local kind=args[2];if kind~='singbox'and kind~='meta'then fail('invalid_core')end
  phase('working','downloading_core_update',true)
  local ok=M.run('SC_CORE_JOB=1 '..M.C..'/ax5/core-fetch.sh '..kind..' >> '..M.R..'/service.log 2>&1')
  if not ok then fail('core_update_failed_previous_kept')end
  phase('done','core_updated',false)
 elseif a=='toolcheck'or a=='toolupdate'then
  guard();phase('working',a=='toolcheck'and'checking_tool_release'or'updating_tool_release',true)
  if not M.run('SC_TOOL_JOB=1 '..M.C..'/ax5/tool-update.sh ax5 '..(a=='toolcheck'and'check'or'update')..' >> '..M.R..'/service.log 2>&1')then fail('tool_update_rejected_previous_kept')end
  phase('done',a=='toolcheck'and'tool_checked'or'tool_updated',false)
 elseif a=='mirrorsave'then
  local raw=upload('mirror');if #raw>2048 then fail('mirror_invalid')end
  local base,target=raw:match('^base=([^\n]*)\ntarget=([^\n]*)\n$')
  if not base or not target or (base~=''and not base:match('^https?://[%w.:%-]+[%w/._~%-]*$'))or base:find('..',1,true)or(target~=''and(not target:match('^[%w_-]+@[%w.%-]+:%d+$')or base==''))then fail('mirror_invalid')end
  M.write(M.C..'/configs/mirror.conf',raw);M.save(M.R..'/mirror-check.json',{configured=base~='',available=false});phase('done','mirror_saved',false)
 elseif a=='mirrorsync'then
  guard();phase('working','mirror_syncing',true)
  if not M.run(M.C..'/ax5/mirror-sync.sh >> '..M.R..'/service.log 2>&1')then M.write(M.C..'/configs/mirror-pending','Synchronization pending\n');fail('mirror_sync_failed')end
  phase('done','mirror_synced',false)
 elseif a=='corecheck'then
  local ok=M.run(M.C..'/ax5/verify-core.sh > '..M.R..'/check.log 2>&1')
  if not ok then fail('core_current_invalid')end
  local s=M.state();local kind=args[2]or s.core_kind;if kind~='meta'and kind~='singbox'then fail('invalid_core')end;M.run(M.C..'/ax5/mirror-status.sh '..kind..' 2>> '..M.R..'/service.log');local latest=M.exec(M.C..'/ax5/core-source.sh version '..kind..' 2>> '..M.R..'/service.log'):match('([v%d][%w.+_-]*)%s*$')
  local job={kind=kind,available=latest~=nil,fits=true,fixed=false,version=latest or s.core_version,git_blob=(latest and latest:gsub('^v','')~=s.core_version:gsub('^v',''))and('source_'..latest)or M.read(M.C..'/cache/core.sha256'):match('^(%x+)'),size=tonumber(M.exec('wc -c < '..M.C..'/cache/core-armv7.tar.gz'))or 0,checked=os.time()}
  M.save(M.R..'/core-check.json',job);phase('done','core_checked',false)
 else fail('unsupported_action')end
end
local ok,err=pcall(execute)
if not ok then phase('error',tostring(err),false);M.write(M.R..'/last-job-error',tostring(err))end
if req.action=='apply'or req.action=='dns'then
 for _,kind in ipairs({'source','bounds','filter'})do os.remove(M.R..'/upload-'..kind);os.remove(M.R..'/upload-id-'..kind)end
 os.remove(M.R..'/subscription.raw')
end
os.remove(M.R..'/operation.lock')
