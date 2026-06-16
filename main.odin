package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

APP_NAME :: "ui"
SCREEN_ASPECT_RATIO :: 1.6
SCREEN_HEIGHT :: 250 * SCREEN_ASPECT_RATIO
SCREEN_WIDTH :: SCREEN_HEIGHT * SCREEN_ASPECT_RATIO

main :: proc() {
	//  ╭──────╮
	//  │ init │
	//  ╰──────╯

	// --- logging ---
	log_file_name := fmt.tprintf("%s.log", APP_NAME)
	log_file, err := os.open(log_file_name, {.Create, .Append, .Read, .Write})
	assert(err == 0, fmt.tprintf("%#v: creating log file", err))
	defer os.close(log_file)

	if os.exists(log_file_name) {
		fmt.fprint(log_file, "\n")
	}

	logger := log.create_file_logger(log_file, .Debug)
	defer log.destroy_file_logger(logger)
	context.logger = logger

	// --- allocator ---
	buffer := make([]byte, 1024 * 1024)
	arena: mem.Arena
	mem.arena_init(&arena, buffer)
	alloc := mem.arena_allocator(&arena)
	context.allocator = alloc

	// ╭──────╮
	// │ main │
	// ╰──────╯

	// --- init ---
	if !sdl.Init({.VIDEO}) {
		log.fatal("sdl3 init problem")
	}
	if !ttf.Init() do panic("sdl3.ttf init problem")
	defer {
		sdl.Quit()
		ttf.Quit()}

	window := sdl.CreateWindow("hello", SCREEN_WIDTH, SCREEN_HEIGHT, {.RESIZABLE})
	renderer := sdl.CreateRenderer(window, nil)
	defer {
		if window != nil do sdl.DestroyWindow(window)
		if renderer != nil do sdl.DestroyRenderer(renderer)
	}

	font := ttf.OpenFont("./iosevka.ttf", 20)
	text_engine := ttf.CreateRendererTextEngine(renderer)
	defer {
		if font != nil do ttf.CloseFont(font)
		if text_engine != nil do ttf.DestroyRendererTextEngine(text_engine)
	}


	// --- ui ---
	hola := ttf.CreateText(text_engine, font, "hola", len("hola"))
	hello := ttf.CreateText(text_engine, font, "hello", len("hello"))
	assert(hola != nil, "[main] Failed to create text")
	assert(hello != nil, "[main] Failed to create text")
	defer {
		ttf.DestroyText(hola)
		ttf.DestroyText(hello)
	}
	assert(ttf.SetTextColor(hola, 0, 0, 0, 255))
	assert(ttf.SetTextColor(hello, 0, 0, 0, 255))

	hola_btn := Button{hola, {20, 20}, proc() {fmt.printfln("hola clicked")}}
	hello_btn := Button{hello, {20, 80}, proc() {fmt.printfln("hello clicked")}}

	needs_redraw := true
	event: sdl.Event
	handle_event :: proc(event: sdl.Event, needs_redraw: ^bool) -> (quit: bool) {
		#partial switch event.type {
		case .QUIT:
			return true
		case .MOUSE_BUTTON_DOWN:
			needs_redraw^ = true
		case .MOUSE_MOTION, .MOUSE_BUTTON_UP:
			needs_redraw^ = true
		case .WINDOW_EXPOSED, .WINDOW_RESIZED:
			needs_redraw^ = true
		}
		return false
	}

	main_loop: for {
		// --- events ---
		if !sdl.WaitEvent(&event) do log.fatal("[main] Failed to wait event")
		if handle_event(event, &needs_redraw) do break main_loop
		for sdl.PollEvent(&event) {
			if handle_event(event, &needs_redraw) do break main_loop
		}

		// --- draw ---
		if needs_redraw {
			free_all(context.allocator)

			sdl.SetRenderDrawColor(renderer, 14, 13, 12, 255)
			sdl.RenderClear(renderer)

			draw(&hola_btn, renderer)
			draw(&hello_btn, renderer)

			sdl.RenderPresent(renderer)
			needs_redraw = false
		}
	}
}

// ╭────────────╮
// │ components │
// ╰────────────╯

draw :: proc {
	button_draw,
}

Button :: struct {
	msg:      ^ttf.Text,
	pos:      [2]f32,
	on_click: proc(), // callback stored on the struct
}

button_draw :: proc(b: ^Button, renderer: ^sdl.Renderer) {
	w, h: i32
	assert(ttf.GetTextSize(b.msg, &w, &h))

	pad :: [2]f32{10, 8}
	rect := sdl.FRect {
		x = b.pos.x,
		y = b.pos.y,
		w = f32(w) + pad.x * 2,
		h = f32(h) + pad.y * 2,
	}

	m_x, m_y: f32
	m_flag := sdl.GetMouseState(&m_x, &m_y)
	m_point := sdl.FPoint{m_x, m_y}
	m_hovering := sdl.PointInRectFloat(m_point, rect)
	m_lpress := .LEFT in m_flag

	if m_lpress && m_hovering && b.on_click != nil {
		b.on_click()
	}

	color: [4]u8
	if m_lpress && m_hovering {
		color = {75, 50, 255, 255}
	} else if m_hovering {
		color = {255, 255, 255, 255}
	} else {
		color = {128, 128, 128, 255}
	}

	sdl.SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3])
	sdl.RenderFillRect(renderer, &rect)
	ttf.DrawRendererText(b.msg, b.pos.x + pad.x, b.pos.y + pad.y)
}
