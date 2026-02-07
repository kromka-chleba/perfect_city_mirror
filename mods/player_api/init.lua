dofile(core.get_modpath("player_api") .. "/api.lua")

-- Seba's height is roughly 170 cm
-- 170 cm = 3.33 nodes
-- thus 1 node = 0.51 m

-- Default player appearance
player_api.register_model("character.b3d", {
	animation_speed = 30,
	textures = {"character.png"},
	animations = {
		-- Standard animations.
		stand     = {x = 0,   y = 79},
		lay       = {x = 162, y = 166, eye_height = 0.3, override_local = true,
			collisionbox = {-0.6, 0.0, -0.6, 0.6, 0.3, 0.6}},
		walk      = {x = 168, y = 187},
		mine      = {x = 189, y = 198},
		walk_mine = {x = 200, y = 219},
		sit       = {x = 81,  y = 160, eye_height = 0.8, override_local = true,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.0, 0.3}}
	},
	collisionbox = {-0.3, 0.0, -0.3, 0.3, 3, 0.3},
	stepheight = 1,
	eye_height = 3,
})

-- Update appearance when the player joins
core.register_on_joinplayer(function(player)
	player_api.set_model(player, "character.b3d")
        player:set_eye_offset(
            vector.zero(), --firstperson
            vector.new(-10, -15, -5), --thirdperson_back
            vector.new(-10, 0, -5) --thirdperson_front
        )
end)
