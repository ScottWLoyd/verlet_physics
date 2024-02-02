package main

import "core:math"
import "core:math/linalg"


Vec2 :: [2]f64

VerletObject :: struct {
	position:     Vec2,
	position_old: Vec2,
	//velocity: Vec2,
	acceleration: Vec2,
}

update_position :: proc(vo: ^VerletObject, dt: f64) {
	//vo.velocity = vo.velocity + vo.acceleration * dt
	velocity := vo.position - vo.position_old
	// save current position
	vo.position_old = vo.position
	// perform verlet integration
	vo.position = vo.position + velocity + vo.acceleration * dt * dt
	// reset acceleration
	vo.acceleration = Vec2{}

	//fmt.println("old: ", vo.position_old, ", new: ", vo.position)
}

set_velocity :: proc(vo: ^VerletObject, v: Vec2, dt: f64) {
	vo.position_old = vo.position - (v * dt)
}

accelerate :: proc(vo: ^VerletObject, acc: Vec2) {
	vo.acceleration += acc
}

Solver :: struct {
	world:             ^World,
	time:              f64,
	frame_dt:          f64,
	substeps:          int,
	constraint_pos:    Vec2,
	constraint_radius: f64,
}

solver_set_update_rate :: proc(solver: ^Solver, rate: f64) {
	solver.frame_dt = 1.0 / rate
}

solver_set_contraint :: proc(solver: ^Solver, pos: Vec2, radius: f64) {
	solver.constraint_pos = pos
	solver.constraint_radius = radius
}

solver_set_object_velocity :: proc(solver: ^Solver, o: ^VerletObject, v: Vec2) {
	set_velocity(o, v, solver.frame_dt / cast(f64)solver.substeps)
}

solve :: proc(solver: ^Solver) {
	solver.time += solver.frame_dt
	sub_dt := solver.frame_dt / cast(f64)solver.substeps
	for i in 0 ..< solver.substeps {
		apply_gravity(solver.world)
		apply_constraint(solver.world, solver.constraint_pos, solver.constraint_radius)
		solve_collisions(solver.world)
		update_positions(solver.world, sub_dt)
	}
}

update_positions :: proc(world: ^World, dt: f64) {
	for _, i in world.entities {
		obj := &world.entities[i]
		update_position(obj, dt)
	}
}

apply_gravity :: proc(world: ^World) {
	for _, i in world.entities {
		obj := &world.entities[i]
		accelerate(obj, GRAVITY)
	}
}

apply_constraint :: proc(world: ^World, pos: Vec2, radius: f64) {
	for _, i in world.entities {
		obj := &world.entities[i]
		to_obj := pos - obj.position
		dist := linalg.length(to_obj)
		if dist > (radius - obj.radius) {
			n := to_obj / dist
			obj.position = pos - n * (radius - obj.radius)
		}
	}
}

solve_collisions :: proc(world: ^World) {
	RESPONSE_COEFF :: 0.75
	obj_count := len(world.entities)

	for i in 0 ..< obj_count - 1 {
		obj1 := &world.entities[i]
		for j in i + 1 ..< obj_count {
			obj2 := &world.entities[j]

			v := obj1.position - obj2.position
			dist2 := v.x * v.x + v.y * v.y
			min_dist := obj1.radius + obj2.radius
			// check for overlap
			if dist2 < min_dist * min_dist {
				dist := math.sqrt(dist2)
				n := v / dist
				mass_ratio_1 := obj1.radius / min_dist
				mass_ratio_2 := obj2.radius / min_dist
				delta := 0.5 * RESPONSE_COEFF * (dist - min_dist)
				// update positions
				obj1.position -= n * delta * mass_ratio_2
				obj2.position += n * delta * mass_ratio_1
			}
		}
	}
}

/*  Old version
solve_collisions :: proc(world: ^World) {
	obj_count := len(world.entities)
	for i in 0 ..< obj_count - 1 {
		obj1 := &world.entities[i]
		for j in i + 1 ..< obj_count {
			obj2 := &world.entities[j]

			collision_axis := obj1.position - obj2.position
			dist := linalg.length(collision_axis)
			min_dist := obj1.radius + obj2.radius
			if dist < min_dist {
				n := collision_axis / dist
				delta := min_dist - dist
				obj1.position += 0.5 * delta * n
				obj2.position -= 0.5 * delta * n
			}
		}
	}
}
*/
