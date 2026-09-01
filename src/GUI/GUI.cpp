#include <GUI/GUI.h>
#include <cstdint>

void GUI::DrawPixels(unsigned char* pixels)
{
    if (pixels == nullptr || renderTexture == 0)
    {
        return;
    }

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, renderTexture);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glBindTexture(GL_TEXTURE_2D, 0);
}

void GUI::SetRenderer(Renderer* renderer)
{
    this->renderer = renderer;
    pixelWidth = renderer->width;
    pixelHeight = renderer->height;
    width = pixelWidth + 300;
    height = pixelHeight;
}

bool GUI::Open()
{
    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
    {
        return false;
    }

    const char* glslVersion = "#version 130";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);

    glWindow = glfwCreateWindow(width, height, "RayTracingEngine", nullptr, nullptr);
    if (glWindow == nullptr)
    {
        glfwTerminate();
        return false;
    }

    glfwMakeContextCurrent(glWindow);
    glfwSwapInterval(0);

    glewExperimental = GL_TRUE;
    GLenum glewError = glewInit();
    if (glewError != GLEW_OK)
    {
        fprintf(stderr, "GLEW initialization failed: %s\n", reinterpret_cast<const char*>(glewGetErrorString(glewError)));
        Close();
        return false;
    }
    glGetError();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    io = &ImGui::GetIO();
    io->ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io->ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;
    ImGui::StyleColorsDark();

    if (!ImGui_ImplGlfw_InitForOpenGL(glWindow, true))
    {
        Close();
        return false;
    }
    if (!ImGui_ImplOpenGL3_Init(glslVersion))
    {
        Close();
        return false;
    }

    const GLsizeiptr pixelBytes = static_cast<GLsizeiptr>(pixelWidth) * static_cast<GLsizeiptr>(pixelHeight) * 4;
    glGenBuffers(Renderer::OpenGLPixelBufferCount, pixelBufferObjects);
    for (int i = 0; i < Renderer::OpenGLPixelBufferCount; i++)
    {
        if (pixelBufferObjects[i] == 0)
        {
            fprintf(stderr, "Failed to create OpenGL pixel buffer %d.\n", i);
            Close();
            return false;
        }

        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pixelBufferObjects[i]);
        glBufferData(GL_PIXEL_UNPACK_BUFFER, pixelBytes, nullptr, GL_STREAM_DRAW);
    }
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

    glGenTextures(1, &renderTexture);
    if (renderTexture == 0)
    {
        fprintf(stderr, "Failed to create render texture.\n");
        Close();
        return false;
    }

    glBindTexture(GL_TEXTURE_2D, renderTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, pixelWidth, pixelHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0);

    return true;
}

bool GUI::InitializeRendererInterop()
{
    if (renderer == nullptr)
    {
        return false;
    }

    if (!renderer->RegisterOpenGLPixelBuffers(pixelBufferObjects, Renderer::OpenGLPixelBufferCount))
    {
        fprintf(stderr, "CUDA/OpenGL double PBO interop unavailable, using pinned-host texture upload fallback.\n");
        return false;
    }

    return true;
}

void GUI::Close()
{
    if (glWindow != nullptr)
    {
        glfwMakeContextCurrent(glWindow);
    }

    if (renderer != nullptr)
    {
        renderer->UnregisterOpenGLPixelBuffers();
    }

    if (renderTexture != 0 && glWindow != nullptr)
    {
        glDeleteTextures(1, &renderTexture);
        renderTexture = 0;
    }

    if (glWindow != nullptr)
    {
        glDeleteBuffers(Renderer::OpenGLPixelBufferCount, pixelBufferObjects);
    }
    for (int i = 0; i < Renderer::OpenGLPixelBufferCount; i++)
    {
        pixelBufferObjects[i] = 0;
    }

    if (ImGui::GetCurrentContext() != nullptr)
    {
        ImGui_ImplOpenGL3_Shutdown();
        ImGui_ImplGlfw_Shutdown();
        ImGui::DestroyContext();
        io = nullptr;
    }

    if (glWindow != nullptr)
    {
        glfwDestroyWindow(glWindow);
        glWindow = nullptr;
    }
    glfwTerminate();
}

void GUI::UpdateRenderTexture()
{
    if (renderer == nullptr || renderTexture == 0)
    {
        return;
    }

    glBindTexture(GL_TEXTURE_2D, renderTexture);

    const GLuint completedPbo = renderer->GetCompletedOpenGLPixelBufferObject();
    if (renderer->IsGraphicsInteropEnabled() && completedPbo != 0)
    {
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, completedPbo);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    }
    else if (renderer->pixelsData != nullptr)
    {
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, renderer->pixelsData);
    }

    glBindTexture(GL_TEXTURE_2D, 0);
}

void GUI::Tick(float deltaTime)
{
    (void)deltaTime;
    glfwPollEvents();

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();

    UpdateRenderTexture();
    if (renderTexture != 0)
    {
        ImTextureID textureId = (ImTextureID)(intptr_t)renderTexture;
        ImGui::GetBackgroundDrawList()->AddImage(textureId, ImVec2(0.0f, 0.0f), ImVec2(static_cast<float>(pixelWidth), static_cast<float>(pixelHeight)), ImVec2(0.0f, 1.0f), ImVec2(1.0f, 0.0f));
    }

    ImGui::SetNextWindowPos(ImVec2(static_cast<float>(pixelWidth), 0.0f));
    ImGui::SetNextWindowSize(ImVec2(300.0f, 450.0f));
    ImGui::Begin("World");

    const float renderFps = renderer->frameTime > 0 ? 1000.0f / static_cast<float>(renderer->frameTime) : 0.0f;
    ImGui::Text("Render average %lld ms/frame (%.1f FPS)", static_cast<long long>(renderer->frameTime), renderFps);
    ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / io->Framerate, io->Framerate);
    ImGui::Text("Pixel transfer: %s", renderer->IsGraphicsInteropEnabled() ? "CUDA/OpenGL double PBO" : "Pinned host texture upload");
    ImGui::End();

    ImGui::Render();

    int framebufferWidth = 0;
    int framebufferHeight = 0;
    glfwGetFramebufferSize(glWindow, &framebufferWidth, &framebufferHeight);
    glViewport(0, 0, framebufferWidth, framebufferHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    glfwSwapBuffers(glWindow);
}

bool GUI::ShouldClose() const
{
    return glWindow == nullptr || glfwWindowShouldClose(glWindow);
}