#include <GUI/GUI.h>

void GUI::DrawPixels(unsigned char* pixels)
{
    glDrawPixels(pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, static_cast<GLvoid*>(pixels));
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

    glViewport(0, 0, pixelWidth, pixelHeight);
    glRasterPos2f(-1.0f, -1.0f);
    return true;
}

void GUI::Close()
{
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

void GUI::Tick(float deltaTime)
{
    (void)deltaTime;
    glfwPollEvents();

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();

    ImGui::SetNextWindowPos(ImVec2(static_cast<float>(pixelWidth), 0.0f));
    ImGui::SetNextWindowSize(ImVec2(300.0f, 450.0f));
    ImGui::Begin("World");

    const float renderFps = renderer->frameTime > 0 ? 1000.0f / static_cast<float>(renderer->frameTime) : 0.0f;
    ImGui::Text("Render average %lld ms/frame (%.1f FPS)", static_cast<long long>(renderer->frameTime), renderFps);
    ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / io->Framerate, io->Framerate);
    ImGui::End();

    ImGui::Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    glDrawPixels(pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, static_cast<GLvoid*>(renderer->pixelsData));
    glfwSwapBuffers(glWindow);
}

bool GUI::ShouldClose() const
{
    return glWindow == nullptr || glfwWindowShouldClose(glWindow);
}
