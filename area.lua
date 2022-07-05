local area_script_ptr = 0x0
local camera_x = 0x0
local camera_y = 0x0
local current_screen_x = 0x0
local current_screen_y = 0x0
local current_collision_width = 0x0
local current_collision_height = 0x0
local current_obj_script = 0x0
local in_front_of_obj = false
local current_obj_type = 0x0
local show_script = false
local last_keys = input.get()
local SCREEN_WIDTH = 0xFF
local SCREEN_HEIGHT = 0xC0

function read_next_u8()
    local token = memory.read_u8(area_script_ptr, "MD CART")
    area_script_ptr = area_script_ptr + 1;
    return token
end

function read_next_u16()
    local token = memory.read_u16_be(area_script_ptr, "MD CART")
    area_script_ptr = area_script_ptr + 2;
    return token
end

function get_door_addr(index)
    local jump_offset = memory.read_u16_be(0x224C2 + (index * 2), "MD CART")
    return jump_offset + 0x224C2
end

function draw_obj(x, y, width, height, text, color, text_color)
    local draw_x = x - camera_x;
    local draw_y = y - camera_y + 0x30;

    gui.drawRectangle(draw_x, draw_y, width, height, color, 0x88000000);
    gui.pixelText(draw_x, draw_y+1, text, text_color, 0x00)
end

function parse_token()
    -- TODO: Handle jumps (Childam)
    local token = read_next_u8();
    if (token == 0xff) then
        return false
    elseif (token == 0xF9) then
        local addr_and_bit = read_next_u8();
        local flag_bit = bit.band(addr_and_bit, 0x07);
        local flag_addr = bit.rshift(addr_and_bit, 0x03);
        local jump_offset = read_next_u16();
        return string.format("JUMP_IF_FLAG(%x, %x, %x)", flag_addr + 0x99be, flag_bit, jump_offset + (area_script_ptr-2))
    elseif (token == 0xF8) then
        local addr_and_bit = read_next_u8();
        local flag_bit = bit.band(addr_and_bit, 0x07);
        local flag_addr = bit.bor(bit.rshift(addr_and_bit, 0x03), 0x01);

        local jump_offset = read_next_u16();
        return string.format("JUMP_IF_LOCAL_FLAG(%x, %x, %x)", flag_addr + 0x9992, flag_bit, jump_offset + (area_script_ptr-2))
    elseif (token == 0xFE) then
        local jump_offset = read_next_u16();
        return string.format("JUMP(%x)", jump_offset + area_script_ptr - 2)
    elseif (token == 0xFA) then
        local flag_and_bit = read_next_u8();
        local flag_bit = bit.band(flag_and_bit, 0x07);
        local flag_addr = bit.bor(bit.rshift(flag_and_bit, 0x03), 0x01);
        return string.format("SET_LOCAL_FLAG(%x, %x)", flag_addr + 0x9992, flag_bit)
    elseif (token == 0xE0) then
        local pos = read_next_u8();
        local y = bit.band(pos, 0xF);
        local x = bit.rshift(bit.band(pos, 0xF0), 0x04);
        current_screen_x = x
        current_screen_y = y
        return string.format("SET_SCREEN(%x, %x)", x, y)
    elseif (token == 0xE2) then
        local value = bit.lshift(read_next_u8(), 0x03)
        return string.format("Unknown0xE2(%x)", value)
    elseif (token == 0xEA) then
        local unknown = read_next_u8();
        local distance = read_next_u8();
        local unknown2 = read_next_u8();
        local x = read_next_u8();
        local y = read_next_u8();
        local unknown3 = read_next_u8();

        draw_obj((x - 0x10) * 16, (y - 0x10) * 16, 16, 16, string.format("FLYING\nPLATFORM"), "white", "white")
        return string.format("SPAWN_FLYING_PLATFORM(%x, %x, %x, %x, %x, %x)", unknown, distance, unknown2, x, y, unknown3)
    elseif (token == 0xEC) then
        local token_addr = area_script_ptr
        local x = read_next_u8()
        local y = read_next_u8()
        local offset = read_next_u16()

        draw_obj(x * 16, (y+1) * 16, 16, 16, string.format("SPAWN\nTILE"), "yellow", "white")
        return string.format("SPAWN_TILES(%x)", offset + token_addr)
    elseif (token == 0x00) then
        local p1 = read_next_u8()
        local y = bit.rshift(p1, 0x4)
        local area = read_next_u16()
        local p3 = read_next_u8()
        local p4 = read_next_u8()

        local draw_y = 63 + (SCREEN_HEIGHT * (current_screen_y-1)) + (y * 16) - camera_y;

        gui.pixelText(120, draw_y - 8, string.format("V AREA %x", area), "pink")
        gui.pixelText(120, draw_y + 16, string.format("/\\ AREA %x", area), "pink")
        gui.drawBox(0, draw_y, 255, draw_y + 16, "pink", 0x88000000);
        return string.format("VERTICAL_AREA_TRANSITION(%x, %x, %x, %x)", p1, area, p3, p4);
    elseif (token == 0x01) then
        local pos = read_next_u8();
        local x = bit.band(pos, 0xF);
        local y = bit.rshift(bit.band(pos, 0xF0), 0x04);
        local area = read_next_u16();
        local target_x = read_next_u8();
        local target_y = read_next_u8();

        local draw_x = (x * 16) + (SCREEN_WIDTH * (current_screen_x-1)) - camera_x;
        local draw_y = 64 + (y * 16) + (SCREEN_HEIGHT * (current_screen_y-1)) - camera_y;

        local h = ((current_collision_height + 1)*16);

        gui.drawBox(draw_x, draw_y, draw_x + 16, draw_y + h, color, 0x88000000);

        gui.pixelText(draw_x+16, draw_y + (h/2), string.format("< AREA %x\n%x, %x", area, target_x, target_y), "pink")
        gui.pixelText(draw_x-48, draw_y + (h/2), string.format("AREA %x >\n%x, %x", area, target_x, target_y), "pink")
        return string.format("AREA_TRANSITION(%x, %x, %x(%x, %x))", x, y, area, target_x, target_y);
    elseif (token == 0x05) then
        local pos = read_next_u8();
        local x = bit.band(pos, 0xF);
        local y = bit.rshift(bit.band(pos, 0xF0), 0x04);
        local script_index = read_next_u16();
        local color = current_obj_script == script_index and in_front_of_obj and current_obj_type == 0xA5AA and 0xFF00FF00 or "red"

        local draw_x = (x * 16) + ((current_screen_x-1) * SCREEN_WIDTH)
        local draw_y = (y * 16) + ((current_screen_y-1) * SCREEN_HEIGHT)

        draw_obj(draw_x, draw_y, (current_collision_width + 1) * 16, 16, string.format("TEXT\n0x%x", script_index), color, "white")
        return string.format("SCRIPT_UP_TRIGGER(%x, %x, %x)", x, y, script_index)
    elseif (token == 0x09) then
        local door_index = read_next_u16();
        local target_door_index = read_next_u16();

        local door_addr = get_door_addr(door_index)
        local target_door_addr = get_door_addr(target_door_index)

        local x = memory.read_u8(door_addr + 0x04, "MD CART")
        local y = memory.read_u8(door_addr + 0x05, "MD CART")

        local color = current_obj_script == door_index and in_front_of_obj and current_obj_type == 0xA898 and 0xFF00FF00 or "red"

        draw_obj((x * 8)-8, y * 8, 16, 16, string.format("DOOR\n0x%x", door_index), color, "white")
        return string.format("DOOR(%x to %x)", door_index, target_door_index);
    elseif (token == 0x0a) then
        local door_index = read_next_u16();
        local door_addr = 0x22920 + (door_index * 16);
        local x = (8 + memory.read_u8(door_addr + 4) + memory.read_u16_be(door_addr, "MD CART")) - 0x1000;
        local y = (0x20 + memory.read_u8(door_addr + 5) + memory.read_u16_be(door_addr+2, "MD CART")) - 0x1000;

        local color = current_obj_script == door_index and in_front_of_obj and current_obj_type == 0xA8D8 and 0xFF00FF00 or "red"

        draw_obj(x, y, 16, 16, string.format("IDOOR\n0x%x", door_index), color, "white")
        return string.format("DOOR_TO_INTERIOR(%x)", door_index);
    elseif (token >= 0xc0 and token <= 0xcf) then
        local width = bit.band(token, 0x0f)
        current_collision_width = width
        return string.format("SET_COLLIDER_WIDTH(%x)", width)
    elseif (token >= 0xd0 and token <= 0xdf) then
        local height = bit.band(token, 0x0f)
        current_collision_height = height
        return string.format("SET_COLLIDER_HEIGHT(%x)", height)
    elseif (token == 0x0c) then
        area_script_ptr = area_script_ptr + 0x07
        return string.format("JUMP_0x07")
    else
        return string.format("UNKNOWN(%x)", token)
    end
end

function update_area()
    camera_x = mainmemory.read_u16_be(0x9744) - 0x1000
    camera_y = mainmemory.read_u16_be(0x9746) - 0x1000
    current_obj_script = mainmemory.read_u16_be(0x9982)
    in_front_of_obj = mainmemory.read_u8(0x9980) == 0xff
    current_obj_type = mainmemory.read_u16_be(0x998c)
    current_screen_x = 0x01
    current_screen_y = 0x01
    current_collision_width = 0x00
    current_collision_height = 0x00

    area_script_ptr = mainmemory.read_u32_be(0x996C)
    local x = 2
    local y = 58 

    local keys = input.get()

    if keys["L"] and keys["L"] ~= last_keys["L"] then
        if show_script then
            show_script = false
        else
            show_script = true 
        end
    end

    for i=1,30 do
        local token_addr = area_script_ptr
        local token = parse_token() 
        if token == false then
            if (show_script) then
                gui.pixelText(x, y + (7 * i), string.format("[%x] END", token_addr), "white")
            end
          break
        end

        if (show_script) then
            gui.pixelText(x, y + (7 * i), string.format("[%x] %s", token_addr, token), "white")
        end
    end

    last_keys = keys
end

--while true do
--    gui.clearGraphics()
--    update_area()
--    emu.frameadvance()
--end