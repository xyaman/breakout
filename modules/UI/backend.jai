#import "GL";
#import "glfw";

key_events: [Key_Code.MENU]Key_Event;
mouse_state: Mouse_State;

Key_Event :: struct {
    // mods: void;
    is_down: bool;
    just_pressed: bool;
    just_released: bool;
    state_change_count: int; // between frames
}

Mouse_State :: struct {
    x: float;
    y: float;
    buttons: [8]Mouse_Button_Event;
}

Mouse_Button_Event :: struct {
    // mods: void;
    is_down: bool;
    just_pressed: bool;
    just_released: bool;
    state_change_count: int; // between frames
}

// @Note: Using exactly the same as glfw for now
Key_Code :: enum {
    UNKNOWN :: -1;
    SPACE :: 32;

    // The letters A-Z live in here as well and may be returned
    // by keyboard events.

    WORLD_1 :: 161;
    WORLD_2 :: 162;
    ESCAPE :: 256;
    ENTER :: 257;
    TAB :: 258;
    BACKSPACE :: 259;
    INSERT :: 260;
    DELETE :: 261;
    RIGHT :: 262;
    LEFT :: 263;
    DOWN :: 264;
    UP :: 265;
    PAGE_UP :: 266;
    PAGE_DOWN :: 267;
    HOME :: 268;
    END :: 269;
    CAPS_LOCK :: 280;
    SCROLL_LOCK :: 281;
    NUM_LOCK :: 282;
    PRINT_SCREEN :: 283;
    PAUSE :: 284;
    F1 :: 290;
    F2 :: 291;
    F3 :: 292;
    F4 :: 293;
    F5 :: 294;
    F6 :: 295;
    F7 :: 296;
    F8 :: 297;
    F9 :: 298;
    F10 :: 299;
    F11 :: 300;
    F12 :: 301;
    F13 :: 302;
    F14 :: 303;
    F15 :: 304;
    F16 :: 305;
    F17 :: 306;
    F18 :: 307;
    F19 :: 308;
    F20 :: 309;
    F21 :: 310;
    F22 :: 311;
    F23 :: 312;
    F24 :: 313;
    F25 :: 314;
    KP_0 :: 320;
    KP_1 :: 321;
    KP_2 :: 322;
    KP_3 :: 323;
    KP_4 :: 324;
    KP_5 :: 325;
    KP_6 :: 326;
    KP_7 :: 327;
    KP_8 :: 328;
    KP_9 :: 329;
    KP_DECIMAL :: 330;
    KP_DIVIDE :: 331;
    KP_MULTIPLY :: 332;
    KP_SUBTRACT :: 333;
    KP_ADD :: 334;
    KP_ENTER :: 335;
    KP_EQUAL :: 336;
    LEFT_SHIFT :: 340;
    LEFT_CONTROL :: 341;
    LEFT_ALT :: 342;
    LEFT_SUPER :: 343;
    RIGHT_SHIFT :: 344;
    RIGHT_CONTROL :: 345;
    RIGHT_ALT :: 346;
    RIGHT_SUPER :: 347;
    MENU :: 348;
}

// @Note: Allow support for more backends
Window :: struct {
    using internal: *GLFWwindow;
}

backend_init :: () -> success: bool {
    return glfwInit() == 1;
}

create_window :: (width: s32, height: s32, window_name: string) -> Window {
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);

    glfw_window := glfwCreateWindow(width, height, to_c_string(window_name,, temp), null, null);

    glfwMakeContextCurrent(glfw_window);
    glfwSwapInterval(1);
    gl_load(*gl, xx glfwGetProcAddress);

    glfwSetKeyCallback(glfw_window, glfw_key_callback);
    glfwSetMouseButtonCallback(glfw_window, glfw_mouse_button_callback);
    glfwSetCursorPosCallback(glfw_window, glfw_cursor_callback);
    glfwSetFramebufferSizeCallback(glfw_window, glfw_framebuffer_size_callback);

    return .{glfw_window};
}

poll_events :: () {
    for *key_events {
        it.just_pressed = false;
        it.just_released = false;
        it.state_change_count = 0;
    }

    for *mouse_state.buttons {
        it.just_pressed = false;
        it.just_released = false;
        it.state_change_count = 0;
    }

    glfwPollEvents();
}

should_quit :: (w: *Window) -> bool {
    return glfwWindowShouldClose(w.internal) == 1;
}

backend_fini :: () {
    glfwTerminate();
}

#scope_file

glfw_framebuffer_size_callback :: (window: *GLFWwindow, width: s32, height: s32) #c_call {
    glViewport(0, 0, xx width, xx height);
}

glfw_key_callback :: (window: *GLFWwindow, key: s32, scancode: s32, action: s32, mods: s32) #c_call {
    key_code := key;

    // @Todo: handle mods
    if (key_code >= #char "A") && (key_code <= #char "Z") {
        key_code = key + 0x20;
    }

    k := *key_events[key_code];

    was_down := k.is_down;
    k.is_down = action != GLFW_RELEASE;

    if k.is_down != was_down {
        k.state_change_count += 1;
        k.just_pressed = k.is_down;
        k.just_released = !k.is_down;
    }
}

glfw_mouse_button_callback :: (window: *GLFWwindow, button: s32, action: s32, mods: s32) #c_call {
    k := *mouse_state.buttons[button];
    was_down := k.is_down;
    k.is_down = action != GLFW_RELEASE;

    if k.is_down != was_down {
        k.state_change_count += 1;
        k.just_pressed = k.is_down;
        k.just_released = !k.is_down;
    }
}

glfw_cursor_callback :: (window: *GLFWwindow, screen_x: float64, screen_y: float64) #c_call {
    mouse_state.x = xx screen_x;
    mouse_state.y = xx screen_y;
}
