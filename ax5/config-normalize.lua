-- Keep domestic-domain routing consistent across sing-box and mihomo.
local A={}
function A.normalize(c)
 local found=false
 for _,r in ipairs(c.route.rules)do
  local names=type(r.rule_set)=='table'and r.rule_set or{r.rule_set}
  for _,name in ipairs(names)do if name=='cn'and r.outbound=='direct'then found=true end end
 end
 if found then return false end
 local pos=#c.route.rules+1
 for i,r in ipairs(c.route.rules)do if r.ip_cidr and #r.ip_cidr>1000 then pos=i;break end end
 table.insert(c.route.rules,pos,{rule_set={'cn'},outbound='direct'})
 return true
end
if arg and arg[1]=='migrate'then
 local M=dofile('/data/ShellCrash/ax5/common.lua');local path=M.C..'/configs/config.json';local c=M.load(path)
 if A.normalize(c)then
  local candidate=M.R..'/normalized.json';M.write(candidate,M.encode(c))
  local kind=M.read(M.C..'/cache/core.env'):match('KIND=([^%s]+)')
  if kind=='singbox'then assert(M.run('GOMEMLIMIT=12MiB GOGC=25 '..M.R..'/CrashCore check -D '..M.R..' -c '..candidate),'normalized_configuration_invalid')end
  -- Called while the service is stopped; preserve a private rollback copy.
  if M.read(M.C..'/configs/config-before-domain-route.json')==''then M.write(M.C..'/configs/config-before-domain-route.json',M.read(path))end
  M.save(path,c);os.remove(candidate)
 end
end
return A
