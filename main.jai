#import "Basic";
#import "Math";

#import "UI";

WIN_WIDTH :: 1280;
WIN_HEIGHT :: 720;

PADDLE_SPEED :: 800;
PADDLE_SIZE :: Vector2.{100, 12};
PADDLE_POS_Y :: WIN_HEIGHT - 100;
PADDLE_ATLAS :: Vector4.{0, 39, 32, 8};

BALL_SIZE :: Vector2.{12, 12};
BALL_SPEED :: 600;
BALL_ATLAS :: Vector4.{160, 37, 10, 10};


NUM_BLOCK_X :: 10;
NUM_BLOCK_Y :: 8;
BRICK_SIZE :: Vector2.{80, 20};
BRICK_ATLAS :: Vector4.{0, 71, 31, 8};
BRICK_PADDING :: Vector2.{10, 10};
TOTAL_BRICKS_WIDTH :: #run NUM_BLOCK_X * (BRICK_SIZE.x + BRICK_PADDING.x) - BRICK_PADDING.x;

// == Globals
paddle_pos: Vector2;
ball_pos: Vector2;
ball_speed: Vector2;
game_started := false;
bricks: [NUM_BLOCK_X][NUM_BLOCK_Y]bool;

restart :: () {
    paddle_pos = Vector2.{WIN_WIDTH/2 - PADDLE_SIZE.x/2, PADDLE_POS_Y};
    ball_pos = Vector2.{WIN_WIDTH/2 - BALL_SIZE.x/2, WIN_HEIGHT - 300};
    ball_speed = .{0, 0};
    game_started = false;

    for x: 0..NUM_BLOCK_X-1 {
        for y: 0..NUM_BLOCK_Y-1 {
            bricks[x][y] = true;
        }
    }
}

main :: () {
    if !backend_init() {
        log_error("Error: Can't create renderer");
        exit(1);
    }
    defer backend_fini();

    window := create_window(WIN_WIDTH, WIN_HEIGHT, "Breakout");
    renderer := renderer_init();

    bricks_texture := texture_load_from_file("data/bricks.png");
    paddle_balls_texture := texture_load_from_file("data/paddles_and_balls.png");

    // initialization
    restart();

    while !should_quit(*window) {
        dt := get_delta_time();
        paddle_speed: Vector2;

        if key_events[Key_Code.LEFT].is_down {
            paddle_speed.x = -1;
        }

        if key_events[Key_Code.RIGHT].is_down {
            paddle_speed.x = 1;
        }

        // start game/round
        if key_events[Key_Code.SPACE].just_pressed && !game_started {
            paddle_center_pos := Vector2.{paddle_pos.x + PADDLE_SIZE.x/2, paddle_pos.y};
            ball_speed = paddle_center_pos  - ball_pos;
            game_started = true;
        }

        paddle_pos += paddle_speed * PADDLE_SPEED * dt;
        paddle_pos.x = clamp(paddle_pos.x, 0, WIN_WIDTH - PADDLE_SIZE.x);

        // check collisions (only if the game started)
        if game_started {
            // ball - paddle
            // @TODO: rect-circle collision (use radius)
            paddle_collision := ball_pos.x + BALL_SIZE.x > paddle_pos.x && ball_pos.x < paddle_pos.x + PADDLE_SIZE.x && ball_pos.y + BALL_SIZE.y >= paddle_pos.y && ball_pos.y <= paddle_pos.y + PADDLE_SIZE.y;
            if paddle_collision {
                ball_speed = reflect(ball_speed, .{0, -1});
            }

            // ball - walls
            if ball_pos.x <= 0 {
                ball_speed = reflect(ball_speed, .{1, 0});
            }

            if ball_pos.x - BALL_SIZE.x > WIN_WIDTH {
                ball_speed = reflect(ball_speed, .{1, 0});
            }

            if ball_pos.y < 0 {
                ball_speed = reflect(ball_speed, .{0, 1});
            }

            if ball_pos.y > WIN_HEIGHT + 100 {
                restart();
            }

            // ball - bricks
            for x: 0..NUM_BLOCK_X-1 {
                for y: 0..NUM_BLOCK_Y-1 {
                    if !bricks[x][y] then continue;
                    left_padding := cast(float) (WIN_WIDTH - TOTAL_BRICKS_WIDTH)/2;
                    brick_pos := Vector2.{left_padding + (xx x * (BRICK_SIZE.x + BRICK_PADDING.x)), 50 + (xx y * (BRICK_PADDING.y + BRICK_SIZE.y))};

                    brick_collision := ball_pos.x > brick_pos.x && ball_pos.x < brick_pos.x + BRICK_SIZE.x && ball_pos.y + BALL_SIZE.y >= brick_pos.y && ball_pos.y <= brick_pos.y + BRICK_SIZE.y;
                    if brick_collision {
                        bricks[x][y] = false;
                        ball_speed = reflect(ball_speed, .{0, 1});
                    }
                }
            }
        }

        ball_pos += normalize(ball_speed) * dt * BALL_SPEED;

        renderer_set_camera(*renderer, .{dimensions = .{1280, 720}});
        renderer_clear(0, 0, 0, 1);

        renderer_draw_texture_atlas(*renderer, *paddle_balls_texture, BALL_ATLAS, ball_pos, BALL_SIZE);
        renderer_draw_texture_atlas(*renderer, *paddle_balls_texture, PADDLE_ATLAS, paddle_pos, PADDLE_SIZE);

        for x: 0..NUM_BLOCK_X-1 {
            for y: 0..NUM_BLOCK_Y-1 {
                if !bricks[x][y] then continue;
                left_padding := cast(float) (WIN_WIDTH - TOTAL_BRICKS_WIDTH)/2;
                brick_pos := Vector2.{left_padding + (xx x * (BRICK_SIZE.x + BRICK_PADDING.x)), 50 + (xx y * (BRICK_PADDING.y + BRICK_SIZE.y))};
                renderer_draw_texture_atlas(*renderer, *bricks_texture, BRICK_ATLAS, brick_pos, BRICK_SIZE);
            }
        }

        renderer_present(*window, *renderer);
        poll_events();
    }
}

check_collision_circle_rect :: (c_pos: Vector2, c_radius: float, rect: Vector4) -> bool {
    px := max(c_pos.x, rect.x);
    px = min(px, rect.x + rect.z);
    py := max(c_pos.y, rect.y);
    py = min(py, rect.y + rect.w);

    return pow(c_pos.x - px, 2) + pow(c_pos.y - py, 2) < pow(c_radius, 2);
}

reflect :: (I: Vector2, N: Vector2) -> Vector2 {
    b := N * (2 * dot(N, I));
    return I - b;
}
