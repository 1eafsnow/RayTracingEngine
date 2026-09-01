#include <GUI/GUI.h>
#include <cstdint>

void GUI::DrawPixels(unsigned char* pixels)
{
    if (pixels == nullptr || renderTextures[0] == 0)
    {
        return;
    }

    displayTextureIndex = 0;
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, renderTextures[displayTextureIndex]);
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

    glGenTextures(Renderer::OpenGLPixelBufferCount, renderTextures);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    for (int i = 0; i < Renderer::OpenGLPixelBufferCount; i++)
    {
        if (renderTextures[i] == 0)
        {
            fprintf(stderr, "Failed to create render texture %d.\n", i);
            Close();
            return false;
        }

        glBindTexture(GL_TEXTURE_2D, renderTextures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, pixelWidth, pixelHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    }
    glBindTexture(GL_TEXTURE_2D, 0);

    displayTextureIndex = 0;
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
        if (cameraLookActive)
        {
            glfwSetInputMode(glWindow, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
            cameraLookActive = false;
        }
        glfwMakeContextCurrent(glWindow);
    }

    if (renderer != nullptr)
    {
        renderer->UnregisterOpenGLPixelBuffers();
    }

    if (glWindow != nullptr)
    {
        glDeleteTextures(Renderer::OpenGLPixelBufferCount, renderTextures);
        glDeleteBuffers(Renderer::OpenGLPixelBufferCount, pixelBufferObjects);
    }
    for (int i = 0; i < Renderer::OpenGLPixelBufferCount; i++)
    {
        renderTextures[i] = 0;
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

bool GUI::IsCursorInRenderViewport(double x, double y) const
{
    return x >= 0.0 && y >= 0.0 && x < static_cast<double>(pixelWidth) && y < static_cast<double>(pixelHeight);
}

void GUI::UpdateCameraControls(float deltaTime)
{
    if (glWindow == nullptr || renderer == nullptr || io == nullptr)
    {
        return;
    }

    Camera* camera = GetCamera();
    if (camera == nullptr)
    {
        return;
    }

    if (glfwGetWindowAttrib(glWindow, GLFW_FOCUSED) != GLFW_TRUE)
    {
        if (cameraLookActive)
        {
            glfwSetInputMode(glWindow, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
            cameraLookActive = false;
        }
        return;
    }

    camera->Tick(deltaTime);
    bool cameraChanged = false;

    if (!io->WantCaptureKeyboard)
    {
        Vector3 movement(0.0f, 0.0f, 0.0f);
        if (glfwGetKey(glWindow, GLFW_KEY_W) == GLFW_PRESS)
        {
            movement.z += 1.0f;
        }
        if (glfwGetKey(glWindow, GLFW_KEY_S) == GLFW_PRESS)
        {
            movement.z -= 1.0f;
        }
        if (glfwGetKey(glWindow, GLFW_KEY_A) == GLFW_PRESS)
        {
            movement.x -= 1.0f;
        }
        if (glfwGetKey(glWindow, GLFW_KEY_D) == GLFW_PRESS)
        {
            movement.x += 1.0f;
        }

        if (movement.Length() > 0.0f)
        {
            camera->Move(movement);
            cameraChanged = true;
        }
    }

    double mouseX = 0.0;
    double mouseY = 0.0;
    glfwGetCursorPos(glWindow, &mouseX, &mouseY);
    const bool rightMouseDown = glfwGetMouseButton(glWindow, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS;

    if (rightMouseDown && !cameraLookActive && IsCursorInRenderViewport(mouseX, mouseY) && !io->WantCaptureMouse)
    {
        cameraLookActive = true;
        glfwSetInputMode(glWindow, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
        glfwGetCursorPos(glWindow, &lastMouseX, &lastMouseY);
    }
    else if (!rightMouseDown && cameraLookActive)
    {
        glfwSetInputMode(glWindow, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
        cameraLookActive = false;
    }

    if (cameraLookActive)
    {
        glfwGetCursorPos(glWindow, &mouseX, &mouseY);
        const double deltaX = mouseX - lastMouseX;
        const double deltaY = mouseY - lastMouseY;
        lastMouseX = mouseX;
        lastMouseY = mouseY;

        if (deltaX != 0.0 || deltaY != 0.0)
        {
            camera->Look(Vector3(static_cast<float>(deltaX), static_cast<float>(deltaY), 0.0f));
            cameraChanged = true;
        }
    }

    if (cameraChanged)
    {
        renderer->ResetAccumulation();
    }
}

void GUI::UpdateRenderTexture()
{
    if (renderer == nullptr)
    {
        return;
    }

    const int completedIndex = renderer->GetCompletedOpenGLPixelBufferIndex();
    if (renderer->IsGraphicsInteropEnabled() && completedIndex >= 0 && completedIndex < Renderer::OpenGLPixelBufferCount)
    {
        const GLuint completedPbo = pixelBufferObjects[completedIndex];
        if (completedPbo == 0 || renderTextures[completedIndex] == 0)
        {
            return;
        }

        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, completedPbo);
        glBindTexture(GL_TEXTURE_2D, renderTextures[completedIndex]);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glBindTexture(GL_TEXTURE_2D, 0);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
        displayTextureIndex = completedIndex;
    }
    else if (renderer->pixelsData != nullptr && renderTextures[0] != 0)
    {
        DrawPixels(renderer->pixelsData);
    }
}

void GUI::Tick(float deltaTime)
{
    glfwPollEvents();

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();

    const float cameraDeltaTime = io != nullptr && io->DeltaTime > 0.0f ? io->DeltaTime : deltaTime;
    UpdateCameraControls(cameraDeltaTime);
    UpdateRenderTexture();
    if (renderTextures[displayTextureIndex] != 0)
    {
        ImTextureID textureId = (ImTextureID)(intptr_t)renderTextures[displayTextureIndex];
        ImGui::GetBackgroundDrawList()->AddImage(textureId, ImVec2(0.0f, 0.0f), ImVec2(static_cast<float>(pixelWidth), static_cast<float>(pixelHeight)), ImVec2(0.0f, 1.0f), ImVec2(1.0f, 0.0f));
    }

    ImGui::SetNextWindowPos(ImVec2(static_cast<float>(pixelWidth), 0.0f));
    ImGui::SetNextWindowSize(ImVec2(300.0f, 560.0f));
    ImGui::Begin("World");

    const float renderFps = renderer->frameTime > 0 ? 1000.0f / static_cast<float>(renderer->frameTime) : 0.0f;
    ImGui::Text("Render average %lld ms/frame (%.1f FPS)", static_cast<long long>(renderer->frameTime), renderFps);
    ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / io->Framerate, io->Framerate);
    ImGui::Text("Pixel transfer: %s", renderer->IsGraphicsInteropEnabled() ? "CUDA/OpenGL PBO x2 + Texture x2" : "Pinned host texture upload");

    ImGui::Separator();
    ImGui::Text("Sampling");
    static const char* samplingModes[] =
    {
        "Direct only",
        "Indirect - Uniform hemisphere",
        "Indirect - Cosine hemisphere",
        "Indirect - GGX",
        "Direct + Uniform hemisphere",
        "Direct + Cosine hemisphere",
        "Direct + GGX"
    };
    int samplingMode = static_cast<int>(renderer->samplingMode);
    if (ImGui::Combo("Mode", &samplingMode, samplingModes, static_cast<int>(sizeof(samplingModes) / sizeof(samplingModes[0]))))
    {
        renderer->samplingMode = static_cast<SamplingMode>(samplingMode);
        renderer->ResetAccumulation();
    }
    ImGui::Text("Accumulated samples: %d", renderer->frame);

    Camera* camera = GetCamera();
    if (camera != nullptr)
    {
        ImGui::Separator();
        ImGui::Text("Camera");
        ImGui::Text("WASD: move in camera space");
        ImGui::Text("Hold RMB + drag: yaw / pitch");
        ImGui::Text("Location: %.2f  %.2f  %.2f", camera->worldLocation.x, camera->worldLocation.y, camera->worldLocation.z);
        ImGui::Text("Yaw %.1f   Pitch %.1f", camera->GetYaw(), camera->GetPitch());
        ImGui::SliderFloat("Move speed", &camera->moveSpeed, 0.1f, 20.0f, "%.2f");
        ImGui::SliderFloat("Look sensitivity", &camera->lookSpeed, 0.01f, 1.0f, "%.2f");
    }
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
