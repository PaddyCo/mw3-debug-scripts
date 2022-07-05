
local last_player_state = 0x0
local last_keys = nil
local bg = 0xAA000000
local border = 0xFFAA00AA

local select_script = false
local curr_teleport_destination = nil
local teleport_destinations = {
  { "Home", 0x0000, 0x10f0, 0x1090 },
  { "Alsedo", 0x0200, 0x1015, 0x1090 },
  { "Sewer", 0x0400, 0x1010, 0x1080 },
  { "Purapril City", 0x0500, 0x1010, 0x1080 },
  { "Lilypad", 0x0601, 0x13f0, 0x1080 },
  { "Begonia", 0x0c02, 0x1010, 0x1080 },
  { "Childam entrance", 0x0e06, 0x1010, 0x1080 },
  { "Childam", 0x0e01, 0x1010, 0x1080 },
}

function on_screen_transition()

    if curr_teleport_destination == nil then
        return
    end

    gui.addmessage(string.format("Teleported to %s", teleport_destinations[curr_teleport_destination][1]))

    -- Area
    mainmemory.write_u16_be(0x9668, teleport_destinations[curr_teleport_destination][2])
    -- X
    mainmemory.write_u16_be(0x967A, teleport_destinations[curr_teleport_destination][3])
    -- Y
    mainmemory.write_u16_be(0x967C, teleport_destinations[curr_teleport_destination][4])

    curr_teleport_destination = nil
end

function on_script_trigger()
    local curr_script_pointer = mainmemory.read_u32_be(0x8c7a)
    if select_script then
        client.pause()
        local form = forms.newform()
        local script_addr = forms.textbox(form, string.format("%x", curr_script_pointer), 128, 32, "HEX", 16, 16)
        forms.button(form, "Trigger script", function() 
            local addr = tonumber(forms.gettext(script_addr), 16)
            mainmemory.write_u32_be(0x8c7a, addr)
            client.unpause()
            forms.destroy(form)
        end, 16, 64)
    else
        savestate.save(string.format("Genesis/State/mw3-script-%x.State", curr_script_pointer))
    end
end

function before_script_trigger()
end

function trigger_script()
    
end

function update()
    local in_script = bit.band(mainmemory.read_u8(0x80d6), 0x40);
    local curr_script_index = mainmemory.read_u16_be(0x9c16)
    local curr_script_pointer = mainmemory.read_u32_be(0x8c7a)

    local keys = input.get();

    if keys["S"] and keys["S"] ~= last_keys["S"] then
        if select_script then
            select_script = false
            gui.addmessage(string.format("Script selection disabled"))
        else
            select_script = true
            gui.addmessage(string.format("Script selection enabled"))
        end
    end

    if keys["T"] and keys["T"] ~= last_keys["T"] then
        if curr_teleport_destination == #teleport_destinations then
            curr_teleport_destination = nil
        elseif curr_teleport_destination == nil then
            curr_teleport_destination = 1
        else
            curr_teleport_destination = curr_teleport_destination + 1
        end
    end


    -- If player is in script:
    if in_script == 0x40 then
        local curr_token = memory.read_u8(curr_script_pointer, "MD CART")

        local x = 5
        local y = 65

        gui.drawRectangle(x, y, 85, 25, border, bg)
        gui.pixelText(x + 3, y + 3, "Script", "white", 0x00, "fceux")
        gui.pixelText(x + 43, y + 3, string.format("#%x", curr_script_index), "yellow", 0x00, "fceux")

        gui.pixelText(x + 3, y + 15, "Position", "white", 0x00)
        gui.pixelText(x + 43, y + 15, string.format("%x", curr_script_pointer), "yellow", 0x00)
    end

    if in_script ~= 0x40 then
        curr_script_entry = nil
    end

    local camera_x = mainmemory.read_u16_be(0x9744)
    local camera_y = mainmemory.read_u16_be(0x9746)
    local player_x = mainmemory.read_u16_be(0xc800)
    local player_y = mainmemory.read_u16_be(0xc900)

    -- Position
    gui.pixelText(3, 208, string.format("Pos: %x, %x", player_x, player_y))
    gui.pixelText(3, 215, string.format("Area: %x", mainmemory.read_u16_be(0x9668)))

    -- Teleport destination
    if curr_teleport_destination ~= nil then
        local x = 5
        local y = 5

        gui.drawRectangle(x, y, 85, 25, border, bg)
        gui.pixelText(x + 3, y + 3, "Destination", "white", 0x00, "fceux")
        gui.pixelText(x + 3, y + 15, teleport_destinations[curr_teleport_destination][1], "yellow", 0x00)
    end

    last_keys = keys
    last_player_state = player_state
end

function test()
    gui.addmessage("Wowww")

end

event.onmemoryexecute(on_screen_transition, 0xa3b2)
event.onmemoryexecute(on_script_trigger, 0x278a)

while true do
    gui.clearGraphics()
    update()
    update_area()
    emu.frameadvance()
end

--event.onframestart(update)
--event.onmemoryexecute(on_screen_transition, 0xa974)