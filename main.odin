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
	links:    [dynamic]Link,
}

Scenario :: enum {
	BallSpray,
	Chain,
	ChainSpray,
}

scenario: Scenario

reset_scenario :: proc(solver: ^Solver) {
	clear(&solver.world.entities)
	clear(&solver.world.links)
	solver_clear_constraint(solver)
	count = 0
	last_spawn = 0

	switch scenario {
	case .BallSpray:
		{
			solver_set_contraint(
				solver,
				Vec2{0, 0},
				SCREEN_HEIGHT * 0.45 * ScreenToWorldScaleFactor,
			)
		}

	case .Chain:
		{
			radius := 0.25
			spacing := 3 * radius
			for i in 0 ..< 20 {
				e := Entity{}
				e.position = Vec2{cast(f64)i * spacing, -5}
				e.color = rl.WHITE
				e.radius = radius
				solver_set_object_velocity(solver, &e.vo, Vec2{0, 0})
				e.pinned = (i == 0)
				append(&solver.world.entities, e)

				if i > 0 {
					l := Link{}
					l.objects[0] = &solver.world.entities[i - 1]
					l.objects[1] = &solver.world.entities[i]
					l.target_dist = spacing
					append(&solver.world.links, l)
				}
			}
		}

	case .ChainSpray:
		{
			radius := 0.25
			spacing := 3 * radius
			chain_length := 24
			for i in 0 ..= chain_length {
				e := Entity{}
				e.position = Vec2 {
					-(cast(f64)chain_length / 2.0 * spacing) + cast(f64)i * spacing,
					5,
				}
				e.color = rl.WHITE
				e.radius = radius
				solver_set_object_velocity(solver, &e.vo, Vec2{})
				e.pinned = (i == 0) || (i == chain_length)
				append(&solver.world.entities, e)

				if (i > 0) {
					l := Link{}
					l.objects[0] = &solver.world.entities[i - 1]
					l.objects[1] = &solver.world.entities[i]
					l.target_dist = spacing
					append(&solver.world.links, l)
				}
			}
		}
	}
}

handle_input :: proc(solver: ^Solver, camera: rl.Camera2D) {
	if rl.IsMouseButtonPressed(.LEFT) {
		screen_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
		world_pos := screen_pos * cast(f32)ScreenToWorldScaleFactor
		fmt.println("pos: ", screen_pos, ", world: ", world_pos)

		e := Entity{}
		e.position = Vec2{cast(f64)world_pos.x, cast(f64)world_pos.y}
		e.position_old = e.position
		e.radius = 1.0
		e.color = rl.WHITE
		append(&solver.world.entities, e)
	}
	if rl.IsKeyPressed(.ONE) {
		scenario = .BallSpray
		reset_scenario(solver)
	} else if rl.IsKeyPressed(.TWO) {
		scenario = .Chain
		reset_scenario(solver)
	} else if rl.IsKeyPressed(.THREE) {
		scenario = .ChainSpray
		reset_scenario(solver)
	}
}

MAX_COUNT :: 2000
MIN_RADIUS :: 0.1
MAX_RADIUS :: 0.25
GRAVITY :: Vec2{0, 10.0}

count := 0
last_spawn := 0.0
last_purge := 0.0

update :: proc(solver: ^Solver, dt: f64) {
	switch scenario {
	case .BallSpray:
		{
			SPAWN_DELAY :: 0.025
			SPAWN_VELOCITY :: 125.0
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
					SPAWN_VELOCITY * Vec2{math.sin(angle), math.cos(angle)},
				)
				append(&solver.world.entities, e)
			}
		}

	case .Chain:
		{

		}

	case .ChainSpray:
		{
			SPAWN_DELAY :: 0.125
			SPAWN_VELOCITY :: 12.0
			PURGE_INTERVAL :: 1.0
			KILL_DISTANCE_SQ :: 20.0 * 20.0
			if count < MAX_COUNT && rl.GetTime() - last_spawn > SPAWN_DELAY {
				count += 1
				last_spawn = rl.GetTime()
				t := solver.time
				angle := 0.5 * math.sin(t) * 0.5 * math.PI

				e := Entity{}
				e.position = Vec2{0, -5}
				e.radius = rand.float64_range(MIN_RADIUS, MAX_RADIUS)
				e.color = get_rainbow(t)
				solver_set_object_velocity(
					solver,
					&e,
					6.0 * Vec2{math.sin(angle), math.cos(angle)},
				)
				append(&solver.world.entities, e)
			}

			if rl.GetTime() - last_purge > PURGE_INTERVAL {
				last_purge = rl.GetTime()
				for _, i in solver.world.entities {
					e := &solver.world.entities[i]
					dist2 := e.position.x * e.position.x + e.position.y * e.position.y
					if dist2 > KILL_DISTANCE_SQ {
						unordered_remove(&solver.world.entities, i)
					}
				}
			}
		}
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
	rl.ClearBackground(rl.BLACK)
	rl.BeginMode2D(camera)

	if scenario == .BallSpray {
		rl.ClearBackground(rl.DARKGRAY)
		pos := rl.Vector2{0, 0}
		radius := SCREEN_HEIGHT * 0.45 * cast(f32)ScreenToWorldScaleFactor
		rl.DrawCircleV(
			pos * cast(f32)WorldToScreenScaleFactor,
			radius * cast(f32)WorldToScreenScaleFactor,
			rl.BLACK,
		)
	}

	for entity in world.entities {
		render_entity(entity)
	}

	rl.EndMode2D()

	rl.DrawFPS(10, 10)
	rl.DrawText(
		rl.TextFormat("%v, %v", len(world.entities), len(world.links)),
		10,
		30,
		20,
		rl.GREEN,
	)
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

	scenario = .BallSpray
	reset_scenario(&solver)

	camera := rl.Camera2D{}
	camera.target = rl.Vector2{0, 0}
	camera.offset = rl.Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
	camera.zoom = 1

	for !rl.WindowShouldClose() {
		dt: f64 = cast(f64)rl.GetFrameTime()
		handle_input(&solver, camera)
		update(&solver, dt)
		render(&world, camera)
	}
}
