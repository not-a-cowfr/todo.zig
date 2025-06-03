#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor

uniform mat4 mvp

out vec2 fragTexCoord;
out vec4 fragColor;

void main
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor
    vec3 position = vertexPosition;

    int width = 30;
    int x = gl_InstanceID % width
    int y = gl_InstanceID / width

    position.x += x * 50.0f;
    position.y += y * 50.0f;

    gl_Position = mvp * vec4(position, 1.0);
}