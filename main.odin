package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

Entity :: struct {
	using vo: VerletObject,
	radius:   f64,
	color:    rl.Color,
}

render_entity :: proc(e: Entity) {
	rl.DrawCircleV(
		rl.Vector2 {
			cast(f32)(e.position.x * WorldToScreenScaleFactor),
			cast(f32)(e.position.y * WorldToScreenScaleFactor),
		},
		cast(f32)(e.radius * WorldToScreenScaleFactor),
		e.color,
	)
}

World :: struct {
	entities: [dynamic]Entity,
}

handle_input :: proc(world: ^World, camera: rl.Camera2D) {
	if rl.IsMouseButtonPressed(.LEFT) {
		screen_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
		world_pos := screen_pos * cast(f32)ScreenToWorldScaleFactor
		fmt.println("pos: ", screen_pos, ", world: ", world_pos)

		e := Entity{}
		e.position = Vec2{cast(f64)world_pos.x, cast(f64)world_pos.y}
		e.position_old = e.position
		e.radius = 1.0
		e.color = rl.WHITE
		append(&world.entities, e)
	}
}

MAX_COUNT :: 2000
count := 0
SPAWN_DELAY :: 0.025
last_spawn := 0.0
SPAWN_SPEED :: 120.0
MIN_RADIUS :: 0.1
MAX_RADIUS :: 0.25
GRAVITY :: Vec2{0, 10.0}

update :: proc(solver: ^Solver, dt: f64) {
	if count < MAX_COUNT && rl.GetTime() - last_spawn > SPAWN_DELAY {
		count += 1
		last_spawn = rl.GetTime()
		t := solver.time
		angle := math.sin(t) * 0.5 * math.PI

		e := Entity{}
		e.position = Vec2{-5, -5}
		e.radius = rand.float64_range(MIN_RADIUS, MAX_RADIUS)
		e.color = get_rainbow(t)
		solver_set_object_velocity(
			solver,
			&e,
			SPAWN_SPEED * Vec2{math.sin(angle), math.cos(angle)},
		)
		append(&solver.world.entities, e)
	}

	solve(solver)
}

get_rainbow :: proc(t: f64) -> rl.Color {
	r := math.sin(t)
	g := math.sin(t + 0.33 * 2.0 * math.PI)
	b := math.sin(t + 0.66 * 2.0 * math.PI)
	return rl.Color{cast(u8)(255.0 * r * r), cast(u8)(255.0 * g * g), cast(u8)(255.0 * b * b), 255}
}

render :: proc(world: ^World, camera: rl.Camera2D) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.DARKGRAY)
	rl.BeginMode2D(camera)

	pos := rl.Vector2{0, 0}
	radius := SCREEN_HEIGHT * 0.45 * cast(f32)ScreenToWorldScaleFactor
	rl.DrawCircleV(
		pos * cast(f32)WorldToScreenScaleFactor,
		radius * cast(f32)WorldToScreenScaleFactor,
		rl.BLACK,
	)

	for entity in world.entities {
		render_entity(entity)
	}

	rl.EndMode2D()

	rl.DrawFPS(10, 10)
	rl.DrawText(rl.TextFormat("%v", count), 10, 30, 20, rl.GREEN)
	rl.EndDrawing()
}

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
WorldToScreenScaleFactor: f64
ScreenToWorldScaleFactor: f64

main :: proc() {

	WorldToScreenScaleFactor = SCREEN_WIDTH / 30.0
	ScreenToWorldScaleFactor = 1.0 / WorldToScreenScaleFactor

	rl.SetConfigFlags(rl.ConfigFlags{.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Physics simulation")
	rl.SetTargetFPS(60)

	world := World{}

	solver: Solver
	solver.world = &world
	solver.substeps = 8
	solver_set_update_rate(&solver, 60)
	solver_set_contraint(&solver, Vec2{0, 0}, SCREEN_HEIGHT * 0.45 * ScreenToWorldScaleFactor)

	/*
    e := Entity{}    
    e.position = Vec2{3, 0}
    e.position_old = e.position
    e.radius = 1.0
    e.color = rl.WHITE
    append(&world.entities, e)
    */

	camera := rl.Camera2D{}
	camera.target = rl.Vector2{0, 0}
	camera.offset = rl.Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
	camera.zoom = 1

	for !rl.WindowShouldClose() {
		dt: f64 = cast(f64)rl.GetFrameTime()
		handle_input(&world, camera)
		update(&solver, dt)
		render(&world, camera)
	}
}
