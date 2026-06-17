ardour { ["type"] = "EditorAction", name = "Humanizing Midi Events",
	license     = "",
	author      = "Chama El Kasri",
	description = [[ Given a dissonance model the script attenuates dissonance.]]
}


local dissonance_values = {
    [0] = 0.014357627941099488,
    [1] = 0.31019793678637125,
    [2] = 0.22442992921530724,
    [3] = 0.15382440644476564,
    [4] = 0.14286383074204753,
    [5] = 0.10745991576144338,
    [6] = 0.1604293889861141,
    [7] = 0.04957363325490694,
    [8] = 0.14699475861361336,
    [9] = 0.07538206536932397,
    [10] = 0.12224616325620717,
    [11] = 0.15170602951173837,
    [12] = 0.008329506735447635
}


function apply_weight(note, velocity, bass, alpha) 
	-- error  if note  lower than bass 
	local result = math.ceil(velocity* ( 1- alpha* dissonance_values[(note - bass)% 12 ] ))
	return math.max(0,math.min(result, 127))
end

function randomize(velocity)
    local result = math.ceil(velocity * (1 + (math.random() * 2 - 1) * 0.05))
    return math.max(0, math.min(result, 127))
end

function accent(velocity) 
	local accent = math.ceil(velocity * 1.5)
	return math.max(0, math.min(accent, 127))
end 

function humanize(current_group , midi_command,bass, alpha) 
	print("harmonize")
	for k, ni in pairs(current_group) do
				
		local new_note = nil 
		local new_velocity  = nil
		print(ni:note())
		if ni:note() ~= bass then			
			new_velocity = apply_weight(ni:note (), ni:velocity (), bass, alpha) 
			-- remove old note add new note	
			new_note = ARDOUR.LuaAPI.new_noteptr (ni:channel (), ni:time() , ni:length (), ni:note (), new_velocity )
						
			current_group[k] = nil
			midi_command:remove(ni)
						
			current_group[k] = new_note
			midi_command:add(new_note)
					
		else
			new_velocity = randomize(ni:velocity ()) 
			new_note = ARDOUR.LuaAPI.new_noteptr (ni:channel (), ni:time() , ni:length (), ni:note (), randomize(ni:velocity () ) )
						
			current_group[k] = nil
			midi_command:remove(ni)
						
			current_group[k] = new_note
			midi_command:add(new_note)
		end
					
	end

end 


function get_bass(group)
	local bass = 0
	for _, ni in pairs(group) do
    		if bass == 0 or ni:note() < bass then
        		bass = ni:note()
    		end
	end
	return bass
end

function factory () return function ()
	-- Calculate the minimal position and the maximum length of the
	-- selection, ignoring non-MIDI region.
	local sel = Editor:get_selection ()
	local sel_position = Temporal.timepos_t.max (Temporal.TimeDomain.BeatTime)
	local sel_end = Temporal.timepos_t.zero ()

	for r in sel.regions:regionlist ():iter () do
		-- Skip non-MIDI region
		local mr = r:to_midiregion ()
		if mr:isnil () then goto continue3 end

		-- Get start and length of MIDI region
		local rstart = mr:start ():beats ()
		local rlength = mr:length ():beats ()
		local rend = rstart + rlength

		-- Iterate over all notes of the MIDI region and reverse them
		local mm = mr:midi_source(0):model ()
		local midi_command = mm:new_note_diff_command (" Test MIDI Events")
		local current_time = -1
		local current_group = {}
		local previous_group = {}


		for note in ARDOUR.LuaAPI.note_list (mm):iter () do
			
			
			-- local new_note = ARDOUR.LuaAPI.new_noteptr (note:channel (), note:time() , note:length (), note:note (), randomize(note:velocity () ) )
			if note:isnil() then goto continue4 end
			print(note:note())
    			local t = note:time()

			-- if next(current_group) ~=nil  
        		if current_time == -1 then 
				current_time =t 
			end
			if current_time == t then 
				print("insert")
				table.insert(current_group,note) 
			end 
			print("--")
			--print(t) 
			-- print(current_time)
			
			if t> current_time then 
				print("process")
				current_time = t  	
				-- get bass note for note in table 
				local bass = get_bass(current_group)
				--[[
				print("bass")
				for _, ni in pairs(current_group) do
    					if bass == 0 or ni:note() < bass then
        					bass = ni:note()
    					end
				end
				-- print(bass)
				]]			
			humanize(current_group , midi_command,bass,  2.8) 
			if next(previous_group) ~= nil then
			
			print("apply accent")
			for kp, npi in pairs(previous_group) do
				for kc, nci in pairs(current_group) do 
				if  npi:note() == nci:note() then 
					print("accent applied")
					print(nci:note())
					local accent_velocity = accent(npi:velocity ())
					local accented_note =  ARDOUR.LuaAPI.new_noteptr (nci:channel (), nci:time() , nci:length (), nci:note (), accent_velocity )
					current_group[kc] = nil
					midi_command:remove(nci)
					current_group[kc] = accented_note 
					midi_command:add(accented_note)
				end
				end		
	
			end
			end	
				print("populate previous clean current group")
				for k, ni in pairs(previous_group ) do 
				previous_group[k] = nil
				end
				previous_group = {}
				for k, ni in pairs(current_group)do 
					previous_group[k] = current_group[k]
				end
				for k, ni in pairs(current_group) do 
					print(ni:note())
					current_group[k] = nil
				end
				print("end clear insert")
				print(note:note())
				current_group = {}
				current_group = {note}
	
				 
    			end

			::continue4::
		end
		local bass = get_bass(previous_group)
		humanize(previous_group , midi_command,bass,  2.8) 
			
		mm:apply_command (Session, midi_command)

		-- TODO: support other MIDI events
		::continue3::
	end
end end

