AddEventHandler('gameEventTriggered', function (name, args)
	TriggerServerEvent('MIAV2:gameevt', args)
end)
  
-- this will trigger negotiation. if you do not perform this task, you will be removed.
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if NetworkIsSessionStarted() then
			TriggerServerEvent('MIAV2:NISS')
			return
		end
	end
end)