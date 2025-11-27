#import "Basic";
#import "Math";
#import "stb_image";

MAX_VERTICES :: 10000;

TEX_VERT_SOURCE :: #string END
#version 330 core

layout(location = 0) in vec2 vert_pos;
layout(location = 1) in vec2 vert_uv;

out vec2 TexCoords;
uniform mat4 u_projection;

void main() {
    gl_Position = u_projection * vec4(vert_pos, 1.0, 1.0);
    TexCoords = vert_uv;
}
END

TEX_FRAG_SOURCE :: #string END
#version 330 core

in vec2 TexCoords;
out vec4 fragColor;

uniform sampler2D u_texture;

void main() {
    vec4 color = texture(u_texture, TexCoords);

    if (color.a < 0.1) {
        discard;
    }

    fragColor = color;
}
END

// Shader :: struct {
//     program: Gluint;
//     vert: GLuint;
//     frag: GLuint;
// }

// class Shader
// {
// public:
//     // the program ID
//     unsigned int ID;
//
//     // constructor reads and builds the shader
//     Shader(const char* vertexPath, const char* fragmentPath);
//     // use/activate the shader
//     void use();
//     // utility uniform functions
//     void setBool(const std::string &name, bool value) const;
//     void setInt(const std::string &name, int value) const;
//     void setFloat(const std::string &name, float value) const;
// };

Renderer :: struct {
    camera_matrix: Matrix4;
    shader_p: GLuint;
    vao: u32;
    vbo: u32;

    vertices: [MAX_VERTICES] Vector2;
    vertices_count: s32;
    current_texture_id: GLuint;
}

Orthographic_Camera :: struct {
    position: Vector2;
    dimensions: Vector2;
}

Texture :: struct {
    id: GLuint;
    width: s32;
    height: s32;
}


renderer_init :: () -> Renderer {
    renderer: Renderer;

    // glEnable(GL_FRAMEBUFFER_SRGB); // Enable correct sRGB gamma blending
    // glDisable(GL_MULTISAMPLE); // Optional: disable MSAA

    shader_v := compile_shader_source(TEX_VERT_SOURCE, GL_VERTEX_SHADER);
    shader_f := compile_shader_source(TEX_FRAG_SOURCE, GL_FRAGMENT_SHADER);
    renderer.shader_p = glCreateProgram();

    glAttachShader(renderer.shader_p, shader_v);
    glAttachShader(renderer.shader_p, shader_f);
    glLinkProgram(renderer.shader_p);

    success: GLint = 0;
    glGetProgramiv(renderer.shader_p, GL_LINK_STATUS, *success);
    if !success {
        log_data: [512]u8;
        glGetProgramInfoLog(renderer.shader_p, log_data.count, null, log_data.data);
        log_error("%", to_string(log_data.data,, temp));
        return .{};
    }

    glDetachShader(renderer.shader_p, shader_v);
    glDetachShader(renderer.shader_p, shader_f);
    glDeleteShader(shader_v);
    glDeleteShader(shader_f);

    glGenVertexArrays(1, *renderer.vao);
    glBindVertexArray(renderer.vao);
    glGenBuffers(1, *renderer.vbo);

    glBindBuffer(GL_ARRAY_BUFFER, renderer.vbo);
    glBufferData(GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vector2), null, GL_DYNAMIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), xx 0);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), xx size_of(Vector2));
    glEnableVertexAttribArray(1);

    return renderer;
}

renderer_set_camera :: (r: *Renderer, c: Orthographic_Camera) {
    r.camera_matrix = orthographic_projection_matrix(c.position.x, c.dimensions.x, c.dimensions.y, c.position.y, -1, 1);
}

// @Todo: Allow compilation time execution
texture_load_from_file :: (path: string) -> (Texture, success: bool) {
    texture: Texture;

    channels: s32;
    tex_data := stbi_load(to_c_string(path,, temp), *texture.width, *texture.height, *channels, 3);
    if !tex_data {
        log_error("Error loading '%'", path);
        return texture, false;
    }
    defer stbi_image_free(tex_data);

    // @Todo: Check if there is already a texture binded and re-bind after this
    glGenTextures(1, *texture.id);
    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, xx texture.width, xx texture.height, 0, GL_RGB, GL_UNSIGNED_BYTE, tex_data);

    return texture, true;
}

renderer_set_texture :: (r: *Renderer, t: *Texture) {
    if t.id == r.current_texture_id then return;
    renderer_flush(r);
    r.current_texture_id = t.id;
}

renderer_flush :: (r: *Renderer) {
    if r.vertices_count == 0 then return;

    texture := r.current_texture_id;
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glUseProgram(r.shader_p);
    projection_loc := glGetUniformLocation(r.shader_p, "u_projection");
    glUniformMatrix4fv(projection_loc, 1, GL_TRUE, *r.camera_matrix._11);

    glBindBuffer(GL_ARRAY_BUFFER, r.vbo);
    glBufferSubData(GL_ARRAY_BUFFER, 0, r.vertices_count * size_of(Vector2), r.vertices.data);

    // @Note: Every quad has 12 vertices (pos: 6, uv: 6), we actually draw half of the vertices number of triangles, only pos
    glBindVertexArray(r.vao);
    glDrawArrays(GL_TRIANGLES, 0, xx (r.vertices_count/2));

    r.vertices_count = 0;
    // glBindTexture(GL_TEXTURE_2D, 0); // unbind texture
}

renderer_draw_texture :: (r: *Renderer, t: *Texture, pos: Vector2, size: Vector2) {
    renderer_set_texture(r, t);

    vertices := Vector2.[
        .{pos.x, pos.y + size.y}, .{0.0, 1.0}, // Top-left
        .{pos.x + size.x, pos.y + size.y}, .{1.0, 1.0}, // Top-right
        .{pos.x + size.x, pos.y}, .{1.0, 0.0}, // Bottom-right
        .{pos.x, pos.y + size.y}, .{0.0, 1.0}, // Top-left
        .{pos.x + size.x, pos.y}, .{1.0, 0.0}, // Bottom-right
        .{pos.x, pos.y}, .{0.0, 0.0} // Bottom-left
    ];

    for vertices {
        r.vertices[r.vertices_count] = it;
        r.vertices_count += 1;
    }
}

/// Sprite Atlas
renderer_draw_texture_atlas :: (r: *Renderer, t: *Texture, atlas_rect: Vector4, pos: Vector2, size: Vector2) {
    renderer_set_texture(r, t);

    tex_w := t.width;
    tex_h := t.height;

    u0 := atlas_rect.x / tex_w;
    v0 := atlas_rect.y / tex_h;
    u1 := (atlas_rect.x + atlas_rect.z) / tex_w;
    v1 := (atlas_rect.y + atlas_rect.w) / tex_h;

    // Build vertices (pos + UV)
    verts := Vector2.[
        .{pos.x,          pos.y + size.y}, .{u0, v1},  // top-left
        .{pos.x + size.x, pos.y + size.y}, .{u1, v1},  // top-right
        .{pos.x + size.x, pos.y},          .{u1, v0},  // bottom-right
        .{pos.x,          pos.y + size.y}, .{u0, v1},  // top-left
        .{pos.x + size.x, pos.y},          .{u1, v0},  // bottom-right
        .{pos.x,          pos.y},          .{u0, v0}   // bottom-left
    ];

    for verts {
        r.vertices[r.vertices_count] = it;
        r.vertices_count += 1;
    }
}

renderer_clear :: (r: float, g: float, b: float, a: float) {
    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT);
}

renderer_present :: (w: *Window, r: *Renderer) {
    renderer_flush(r);
    glfwSwapBuffers(w.internal);
}

prev : float64 = 0;
get_delta_time :: () -> float32 {
    if !prev then prev = glfwGetTime();
    new := glfwGetTime();
    delta := new - prev;
    prev = new;
    return xx delta;
}

#scope_file

compile_shader_source :: (source: string, shader_type: GLenum) -> GLuint {
    shader_object := glCreateShader(shader_type);
    glShaderSource(shader_object, 1, *source.data, null);
    glCompileShader(shader_object);

    success: GLint;
    glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);
    if !success {
        log_data: [512]u8;
        glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
        log_error("Shader compile error: %", to_string(log_data,, temp));
        return 0;
    }

    return shader_object;
}
