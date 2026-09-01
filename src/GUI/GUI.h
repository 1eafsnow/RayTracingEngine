#pragma once
#include <imgui.h>
#include <backends/imgui_impl_glfw.h>
#include <backends/imgui_impl_opengl3.h>
#include <stdio.h>
#define GL_SILENCE_DEPRECATION
#include <GLFW/glfw3.h>
#include <Render/Renderer.h>
#include <vector>

static void glfw_error_callback(int error, const char* description)
{
    fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

class GUI
{
public:
    int width = 0;
    int height = 0;

    int pixelWidth = 0;
    int pixelHeight = 0;

    GLFWwindow* glWindow = nullptr;
    ImGuiIO* io = nullptr;

    Renderer* renderer = nullptr;

    bool objectWindow = false;

    void DrawPixels(unsigned char* pixels);
    void SetRenderer(Renderer* renderer);
    bool Open();
    void Close();
    void Tick(float deltaTime);
    bool ShouldClose() const;
};