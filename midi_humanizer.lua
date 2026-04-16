ardour { ["type"] = "Snippet", name = "Humanizing Midi Events",
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
	local accent = math.ceil(velocity * 0.2)
	return math.max(0, math.min(result, 127))
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
		local current_time = nil
		local current_group = {}
		local previous_group = {}


		for note in ARDOUR.LuaAPI.note_list (mm):iter () do
			
			
			-- local new_note = ARDOUR.LuaAPI.new_noteptr (note:channel (), note:time() , note:length (), note:note (), randomize(note:velocity () ) )
			if note:isnil() then goto continue4 end
			-- print(note:note())
    			local t = note:time()


    			if current_time == nil or t == current_time then
        			table.insert(current_group, note)
				
        			current_time = t
    			else
        			
				-- get bass note for note in table 
				local bass = nil

				for _, v in pairs(current_group) do
					
    					if bass == nil or v:note() < bass then
        					bass = v:note()
    					end
				end

				-- process current  group
				local alpha = 0.4
				for _, ni in pairs(current_group) do
				
					local new_note = nil 
					local new_velocity  = nil
					
					if ni:note() ~= bass then
						new_velocity = apply_weight(ni:note (), ni:velocity (), bass, alpha) 
						-- remove old note add new note	
						new_note = ARDOUR.LuaAPI.new_noteptr (ni:channel (), ni:time() , ni:length (), ni:note (), new_velocity )
						-- new_note = ARDOUR.LuaAPI.new_noteptr (note:local new_note = ARDOUR.LuaAPI.new_noteptr (ni:channel (), ni:time() , ni:length (), ni:note (), new_velocity ))
						midi_command:remove(ni)
						midi_command:add(new_note)
					
					else
						new_velocity = randomize(ni:velocity ()) 
						new_note = ARDOUR.LuaAPI.new_noteptr (ni:channel (), ni:time() , ni:length (), ni:note (), randomize(ni:velocity () ) )
						midi_command:remove(ni)
						midi_command:add(new_note)
					end
					
				end
				 

				-- novelty

				-- new current group 
			        current_group = {note}
        			current_time = t
				if next(previous_group) ~= nil then
				for _, ni in pairs(previous_group) do
					-- not working 
					print(ni:note())
					-- print(note:note())
					-- print(ni:note() == note:note())
					
					if ni:note() == note:note() then
						print(ni:note())
						new_note = ARDOUR.LuaAPI.new_noteptr (note:channel (), note:time() , note:length (), note:note (), accent(note:velocity () ) )
						midi_command:remove(note)
						midi_command:add(new_note)
					end
								
				end 
				-- if found apply accent 
				end
				print("---")
				-- update previous group 
				previous_group = current_group
    			end


			::continue4::
		end
		mm:apply_command (Session, midi_command)

		-- TODO: support other MIDI events
		::continue3::
	end
end end


