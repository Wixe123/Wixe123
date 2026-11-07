-- Summary at the end of a scenario; sets EXIT_CODE (0 = no game errors and no failed checks)
local nErr = #E.errors
local gaps = {}
for g in pairs(E.gaps) do gaps[#gaps + 1] = g end
table.sort(gaps)
HOST_ECHO(string.rep("-", 60))
HOST_ECHO(string.format("checks: %d passed, %d failed | game errors: %d | warnings: %d | emulator gaps: %d", E.checks.pass, E.checks.fail, nErr, #E.warnings, #gaps))
if #gaps > 0 then HOST_ECHO("emulator gaps (not game bugs): " .. table.concat(gaps, ", ")) end
if nErr > 0 then
	local seen = {}
	for _, e in ipairs(E.errors) do
		if not seen[e.msg] then seen[e.msg] = true; HOST_ECHO("ERROR [" .. tostring(e.ctx) .. "] " .. e.msg) end
	end
end
EXIT_CODE = (nErr > 0 or E.checks.fail > 0) and 1 or 0
