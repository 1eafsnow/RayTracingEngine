#pragma once
#include <stdio.h>
#define GL_SILENCE_DEPRECATION
#define GLFW_INCLUDE_NONE
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <imgui.h>
#include <backends/imgui_impl_glfw.h>
#include <backends/imgui_impl_opengl3.h>
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
    GLuint pixelBufferObjects[Renderer::OpenGLPixelBufferCount]{};
    GLuint renderTextures[Renderer::OpenGLPixelBufferCount]{};
    int displayTextureIndex = 0;

    bool objectWindow = false;

    void DrawPixels(unsigned char* pixels);
    void SetRenderer(Renderer* renderer);
    bool Open();
    bool InitializeRendererInterop();
    void Close();
    void Tick(float deltaTime);
    bool ShouldClose() const;

private:
    bool cameraLookActive = false;
    double lastMouseX = 0.0;
    double lastMouseY = 0.0;

    void UpdateRenderTexture();
    void UpdateCameraControls(float deltaTime);
    bool IsCursorInRenderViewport(double x, double y) const;
};
