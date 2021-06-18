local M = {}

local RAY_UP_LEFT = 1
local RAY_UP_MIDDLE = 2
local RAY_UP_RIGHT = 3
local RAY_RIGHT_UP = 4
local RAY_RIGHT_MIDDLE = 5
local RAY_RIGHT_DOWN = 6
local RAY_DOWN_RIGHT = 7
local RAY_DOWN_MIDDLE = 8
local RAY_DOWN_LEFT = 9
local RAY_LEFT_DOWN = 10
local RAY_LEFT_MIDDLE = 11
local RAY_LEFT_UP = 12
local RAY_UPRIGHT = 13
local RAY_DOWNRIGHT = 14
local RAY_DOWNLEFT = 15
local RAY_UPLEFT = 16

local SKIN_WIDTH = 1

local RAY_COLOR_HIT = vmath.vector4(0.5, 0.9, 1, 1)
local RAY_COLOR_MISS = vmath.vector4(1.0, 0.5, 0, 1)

local UP_VECTOR = vmath.vector3(0, 1, 0)
local DOWN_VETOR = -UP_VECTOR
local RIGHT_VECTOR = vmath.vector3(1, 0, 0)
local LEFT_VECTOR = -RIGHT_VECTOR

function M.create(config)
    local cody = {}
    local up = config.height / 2 - SKIN_WIDTH
    local down = -up
    local right = config.width / 2 - SKIN_WIDTH
    local left = -right
    local from = nil
    local to = nil
    local ray_length = nil
    local result = nil
    local hit = nil

    local rays = {
        {id = RAY_UP_LEFT, offset_from_center = vmath.vector3(left, up, 0), direction = UP_VECTOR},
        {id = RAY_UP_MIDDLE, offset_from_center = vmath.vector3(0, up, 0), direction = UP_VECTOR},
        {id = RAY_UP_RIGHT, offset_from_center = vmath.vector3(right, up, 0), direction = UP_VECTOR},
        {id = RAY_RIGHT_UP, offset_from_center = vmath.vector3(right, up, 0), direction = RIGHT_VECTOR},
        {id = RAY_RIGHT_MIDDLE, offset_from_center = vmath.vector3(right, 0, 0), direction = RIGHT_VECTOR},
        {id = RAY_RIGHT_DOWN, offset_from_center = vmath.vector3(right, down, 0), direction = RIGHT_VECTOR},
        {id = RAY_DOWN_RIGHT, offset_from_center = vmath.vector3(right, down, 0), direction = DOWN_VETOR},
        {id = RAY_DOWN_MIDDLE, offset_from_center = vmath.vector3(0, down, 0), direction = DOWN_VETOR},
        {id = RAY_DOWN_LEFT, offset_from_center = vmath.vector3(left, down, 0), direction = DOWN_VETOR},
        {id = RAY_LEFT_DOWN, offset_from_center = vmath.vector3(left, down, 0), direction = LEFT_VECTOR},
        {id = RAY_LEFT_MIDDLE, offset_from_center = vmath.vector3(left, 0, 0), direction = LEFT_VECTOR},
        {id = RAY_LEFT_UP, offset_from_center = vmath.vector3(left, up, 0), direction = LEFT_VECTOR},
        {id = RAY_UPRIGHT, offset_from_center = vmath.vector3(right, up, 0), direction = RIGHT_VECTOR + UP_VECTOR},
        {id = RAY_DOWNRIGHT, offset_from_center = vmath.vector3(right, down, 0), direction = RIGHT_VECTOR + DOWN_VETOR},
        {id = RAY_DOWNLEFT, offset_from_center = vmath.vector3(left, down, 0), direction = LEFT_VECTOR + DOWN_VETOR},
        {id = RAY_UPLEFT, offset_from_center = vmath.vector3(left, up, 0), direction = LEFT_VECTOR + UP_VECTOR}
    }

    local function raycast(from, to)
        local result = physics.raycast(from, to, config.collision_groups)
        if config.debug_draw then
            if result then
                msg.post("@render:", "draw_line", {start_point = from, end_point = to, color = RAY_COLOR_HIT})
            else
                msg.post("@render:", "draw_line", {start_point = from, end_point = to, color = RAY_COLOR_MISS})
            end
        end
        return result
    end

    local function set_directions(result, directions)
        if result.normal.y > 0 then directions.down = true end
        if result.normal.y < 0 then directions.up = true end
        if result.normal.x < 0 then directions.right = true end
        if result.normal.x > 0 then directions.left = true end
    end

    local function horizontal_penetration(start_index, end_index, world_position, velocity, vector_component, collision_result)
        local value = velocity[vector_component]
        local velocity_sign = value > 0 and 1 or -1

        for i = start_index, end_index do
            from = world_position + rays[i].offset_from_center
            ray_length = (velocity_sign * value + SKIN_WIDTH)
            result = raycast(from, from + (rays[i].direction * ray_length))
            if result ~= nil then
                set_directions(result, collision_result.directions)
                collision_result.groups[result.group] = true
                local penetration
                if value > 0 then
                    penetration = math.min(collision_result.penetration[vector_component], -(ray_length - (result.fraction * ray_length)))
                else
                    penetration = math.max(collision_result.penetration[vector_component], ray_length - (result.fraction * ray_length))
                end
                collision_result.penetration[vector_component] = penetration
            end
        end
    end

    local function diagonal_penetration(i, world_position, velocity, collision_result)
        from = world_position + rays[i].offset_from_center
        to = velocity + rays[i].direction * SKIN_WIDTH
        result = raycast(from, from + to)

        if result ~= nil then
            set_directions(result, collision_result.directions)
            hit = -(to - to * result.fraction)
            if velocity.x > 0 then
                collision_result.penetration.x = math.min(collision_result.penetration.x, hit.x)
            else
                collision_result.penetration.x = math.max(collision_result.penetration.x, hit.x)
            end

            if velocity.y > 0 then
                collision_result.penetration.y = math.min(collision_result.penetration.y, hit.y)
            else
                collision_result.penetration.y = math.max(collision_result.penetration.y, hit.y)
            end
        end
    end

    function cody.get_penetration(velocity, collision_result)
        local world_position = go.get_world_position()

        if velocity.x ~= 0 then
            if velocity.x > 0 then
                -- right
                horizontal_penetration(RAY_RIGHT_UP, RAY_RIGHT_DOWN, world_position, velocity, "x", collision_result)
            else
                -- left
                horizontal_penetration(RAY_LEFT_DOWN, RAY_LEFT_UP, world_position, velocity, "x", collision_result)
            end
        end

        if velocity.y ~= 0 then
            if velocity.y > 0 then
                -- up
                horizontal_penetration(RAY_UP_LEFT, RAY_UP_RIGHT, world_position, velocity, "y", collision_result)

            else
                -- down
                horizontal_penetration(RAY_DOWN_RIGHT, RAY_DOWN_LEFT, world_position, velocity, "y", collision_result)

            end
        end

        if velocity.x ~= 0 and velocity.y ~= 0 then
            if velocity.x > 0 then
                if velocity.y > 0 then
                    diagonal_penetration(RAY_UPRIGHT, world_position, velocity, collision_result)
                else
                    diagonal_penetration(RAY_DOWNRIGHT, world_position, velocity, collision_result)
                end
            else
                if velocity.y > 0 then
                    diagonal_penetration(RAY_UPLEFT, world_position, velocity, collision_result)
                else
                    diagonal_penetration(RAY_DOWNLEFT, world_position, velocity, collision_result)
                end
            end
        end
    end

    function cody.clear_results(collision_result)
        collision_result.penetration.x = 0
        collision_result.penetration.y = 0

        for key, _ in pairs(collision_result.groups) do collision_result.groups[key] = false end

        for key, _ in pairs(collision_result.directions) do collision_result.directions[key] = false end
    end

    return cody
end

return M
