#include <GUI/GUI.h>
#include <algorithm>
#include <cfloat>
#include <cmath>
#include <cstdint>

namespace
{
bool IntersectSphereForPicking(const Vector3& origin, const Vector3& direction, const Sphere& sphere, float& distance)
{
    const Vector3 offset = origin - sphere.worldLocation;
    const float a = Dot(direction, direction);
    if (a <= 1e-20f)
    {
        return false;
    }

    const float halfB = Dot(offset, direction);
    const float c = Dot(offset, offset) - sphere.radius * sphere.radius;
    const float discriminant = halfB * halfB - a * c;
    if (discriminant < 0.0f)
    {
        return false;
    }

    const float sqrtD = sqrtf(discriminant);
    float t = (-halfB - sqrtD) / a;
    if (t < MIN_DETECT_DISTANCE)
    {
        t = (-halfB + sqrtD) / a;
    }
    if (t < MIN_DETECT_DISTANCE)
    {
        return false;
    }

    distance = t;
    return true;
}

bool IntersectTriangleForPicking(const Vector3& origin, const Vector3& direction, const Vector3& a, const Vector3& b, const Vector3& c, float& distance)
{
    const Vector3 edge1 = b - a;
    const Vector3 edge2 = c - a;
    const Vector3 p = Cross(direction, edge2);
    const float determinant = Dot(edge1, p);
    if (fabsf(determinant) < 1e-8f)
    {
        return false;
    }

    const float inverseDeterminant = 1.0f / determinant;
    const Vector3 t = origin - a;
    const float u = Dot(t, p) * inverseDeterminant;
    if (u < 0.0f || u > 1.0f)
    {
        return false;
    }

    const Vector3 q = Cross(t, edge1);
    const float v = Dot(direction, q) * inverseDeterminant;
    if (v < 0.0f || u + v > 1.0f)
    {
        return false;
    }

    const float rayDistance = Dot(edge2, q) * inverseDeterminant;
    if (rayDistance < MIN_DETECT_DISTANCE)
    {
        return false;
    }

    distance = rayDistance;
    return true;
}

const char* GetSelectedObjectTypeName(SelectedObjectType type)
{
    switch (type)
    {
    case SelectedObjectType::Sphere:
        return "Sphere";
    case SelectedObjectType::Triangle:
        return "Triangle";
    case SelectedObjectType::Quadrilateral:
        return "Quadrilateral";
    case SelectedObjectType::Light:
        return "Light";
    case SelectedObjectType::None:
    default:
        return "None";
    }
}
}

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
    width = pixelWidth + SidePanelWidth;
    height = pixelHeight;
    UpdateCameraProjection();
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

void GUI::UpdateCameraProjection()
{
    if (renderer == nullptr)
    {
        return;
    }

    Camera* camera = GetCamera();
    if (camera == nullptr || renderer->width <= 0 || renderer->height <= 0)
    {
        return;
    }

    const float left = camera->focus * -tanf(camera->fovX * PI / 180.0f / 2.0f);
    const float right = camera->focus * tanf(camera->fovX * PI / 180.0f / 2.0f);
    const float top = camera->focus * tanf(camera->fovY * PI / 180.0f / 2.0f);
    const float bottom = camera->focus * -tanf(camera->fovY * PI / 180.0f / 2.0f);

    renderer->translateX = -static_cast<float>(renderer->width) / 2.0f;
    renderer->translateY = -static_cast<float>(renderer->height) / 2.0f;
    renderer->scaleX = (right - left) / static_cast<float>(renderer->width);
    renderer->scaleY = (top - bottom) / static_cast<float>(renderer->height);
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

void GUI::PickObject(double mouseX, double mouseY)
{
    World* world = GetWorld();
    Camera* camera = GetCamera();
    if (world == nullptr || camera == nullptr || renderer == nullptr)
    {
        return;
    }

    const float renderX = static_cast<float>(mouseX);
    const float renderY = static_cast<float>(pixelHeight - 1) - static_cast<float>(mouseY);
    Vector3 cameraDirection((renderX + renderer->translateX) * renderer->scaleX, (renderY + renderer->translateY) * renderer->scaleY, camera->focus);
    cameraDirection.Normalize();

    Vector3 worldDirection = camera->GetRightVector() * cameraDirection.x + camera->GetUpVector() * cameraDirection.y + camera->GetForwardVector() * cameraDirection.z;
    worldDirection.Normalize();
    const Vector3 origin = camera->worldLocation;

    SelectedObjectType closestType = SelectedObjectType::None;
    int closestIndex = -1;
    float closestDistance = FLT_MAX;

    for (int i = 0; i < static_cast<int>(world->spheres.size()); i++)
    {
        float distance = 0.0f;
        if (IntersectSphereForPicking(origin, worldDirection, world->spheres[i], distance) && distance < closestDistance)
        {
            closestDistance = distance;
            closestType = SelectedObjectType::Sphere;
            closestIndex = i;
        }
    }

    for (int i = 0; i < static_cast<int>(world->lights.size()); i++)
    {
        float distance = 0.0f;
        if (IntersectSphereForPicking(origin, worldDirection, world->lights[i], distance) && distance < closestDistance)
        {
            closestDistance = distance;
            closestType = SelectedObjectType::Light;
            closestIndex = i;
        }
    }

    for (int i = 0; i < static_cast<int>(world->triangles.size()); i++)
    {
        const Triangle& triangle = world->triangles[i];
        if (triangle.vertexIdx[0] < 0 || triangle.vertexIdx[0] >= static_cast<int>(world->vertices.size()) || triangle.vertexIdx[1] < 0 || triangle.vertexIdx[1] >= static_cast<int>(world->vertices.size()) || triangle.vertexIdx[2] < 0 || triangle.vertexIdx[2] >= static_cast<int>(world->vertices.size()))
        {
            continue;
        }

        const Vector3& a = world->vertices[triangle.vertexIdx[0]].worldLocation;
        const Vector3& b = world->vertices[triangle.vertexIdx[1]].worldLocation;
        const Vector3& c = world->vertices[triangle.vertexIdx[2]].worldLocation;
        float distance = 0.0f;
        if (IntersectTriangleForPicking(origin, worldDirection, a, b, c, distance) && distance < closestDistance)
        {
            closestDistance = distance;
            closestType = SelectedObjectType::Triangle;
            closestIndex = i;
        }
    }

    for (int i = 0; i < static_cast<int>(world->quadrilaterals.size()); i++)
    {
        const Quadrilateral& quadrilateral = world->quadrilaterals[i];
        bool valid = true;
        for (int vertex = 0; vertex < 4; vertex++)
        {
            valid = valid && quadrilateral.vertexIdx[vertex] >= 0 && quadrilateral.vertexIdx[vertex] < static_cast<int>(world->vertices.size());
        }
        if (!valid)
        {
            continue;
        }

        const Vector3& a = world->vertices[quadrilateral.vertexIdx[0]].worldLocation;
        const Vector3& b = world->vertices[quadrilateral.vertexIdx[1]].worldLocation;
        const Vector3& c = world->vertices[quadrilateral.vertexIdx[2]].worldLocation;
        const Vector3& d = world->vertices[quadrilateral.vertexIdx[3]].worldLocation;
        float distance1 = 0.0f;
        float distance2 = 0.0f;
        const bool hit1 = IntersectTriangleForPicking(origin, worldDirection, a, b, c, distance1);
        const bool hit2 = IntersectTriangleForPicking(origin, worldDirection, a, c, d, distance2);
        float distance = FLT_MAX;
        if (hit1)
        {
            distance = distance1;
        }
        if (hit2)
        {
            distance = std::min(distance, distance2);
        }
        if ((hit1 || hit2) && distance < closestDistance)
        {
            closestDistance = distance;
            closestType = SelectedObjectType::Quadrilateral;
            closestIndex = i;
        }
    }

    selectedObjectType = closestType;
    selectedObjectIndex = closestIndex;
}

void GUI::HandleObjectPicking()
{
    if (glWindow == nullptr || io == nullptr || cameraLookActive || !ImGui::IsMouseClicked(ImGuiMouseButton_Left))
    {
        return;
    }

    double mouseX = 0.0;
    double mouseY = 0.0;
    glfwGetCursorPos(glWindow, &mouseX, &mouseY);
    if (!IsCursorInRenderViewport(mouseX, mouseY) || io->WantCaptureMouse)
    {
        return;
    }

    PickObject(mouseX, mouseY);
}

void GUI::SyncSelectedGeometry()
{
    if (renderer == nullptr || !renderer->initialized)
    {
        return;
    }

    World* world = GetWorld();
    if (world == nullptr)
    {
        return;
    }

    cudaError_t error = cudaSuccess;
    if (selectedObjectType == SelectedObjectType::Sphere && selectedObjectIndex >= 0 && selectedObjectIndex < static_cast<int>(world->spheres.size()) && renderer->devSpheres != nullptr)
    {
        error = cudaMemcpy(renderer->devSpheres + selectedObjectIndex, &world->spheres[selectedObjectIndex], sizeof(Sphere), cudaMemcpyHostToDevice);
    }
    else if (selectedObjectType == SelectedObjectType::Light && selectedObjectIndex >= 0 && selectedObjectIndex < static_cast<int>(world->lights.size()) && renderer->devLights != nullptr)
    {
        error = cudaMemcpy(renderer->devLights + selectedObjectIndex, &world->lights[selectedObjectIndex], sizeof(Sphere), cudaMemcpyHostToDevice);
    }

    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to sync selected object to CUDA: %s\n", cudaGetErrorString(error));
    }
    renderer->ResetAccumulation();
}

void GUI::SyncMaterial(int materialIndex)
{
    World* world = GetWorld();
    if (renderer == nullptr || world == nullptr || !renderer->initialized || renderer->devMaterials == nullptr || materialIndex < 0 || materialIndex >= static_cast<int>(world->materials.size()))
    {
        return;
    }

    const cudaError_t error = cudaMemcpy(renderer->devMaterials + materialIndex, &world->materials[materialIndex], sizeof(Material), cudaMemcpyHostToDevice);
    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to sync material to CUDA: %s\n", cudaGetErrorString(error));
    }
    renderer->ResetAccumulation();
}

void GUI::DrawSettingsPanel()
{
    ImGui::Text("CAMERA / WORLD / RENDERER");
    ImGui::Separator();

    Camera* camera = GetCamera();
    if (camera != nullptr && ImGui::CollapsingHeader("Camera", ImGuiTreeNodeFlags_DefaultOpen))
    {
        bool cameraChanged = false;
        cameraChanged |= ImGui::DragFloat3("Position", &camera->worldLocation.x, 0.05f);
        ImGui::Text("Yaw %.1f   Pitch %.1f", camera->GetYaw(), camera->GetPitch());
        cameraChanged |= ImGui::SliderFloat("Move speed", &camera->moveSpeed, 0.1f, 20.0f, "%.2f");
        cameraChanged |= ImGui::SliderFloat("Look sensitivity", &camera->lookSpeed, 0.01f, 1.0f, "%.2f");

        bool projectionChanged = false;
        projectionChanged |= ImGui::SliderFloat("FOV X", &camera->fovX, 10.0f, 150.0f, "%.1f deg");
        projectionChanged |= ImGui::SliderFloat("FOV Y", &camera->fovY, 10.0f, 150.0f, "%.1f deg");
        projectionChanged |= ImGui::DragFloat("Focus", &camera->focus, 0.001f, 0.001f, 10.0f, "%.3f");
        if (projectionChanged)
        {
            UpdateCameraProjection();
            cameraChanged = true;
        }
        if (cameraChanged && renderer != nullptr)
        {
            renderer->ResetAccumulation();
        }
    }

    World* world = GetWorld();
    if (world != nullptr && ImGui::CollapsingHeader("World", ImGuiTreeNodeFlags_DefaultOpen))
    {
        ImGui::Text("Objects: %d", world->objectCount);
        ImGui::Text("Spheres %d   Triangles %d", static_cast<int>(world->spheres.size()), static_cast<int>(world->triangles.size()));
        ImGui::Text("Quads %d     Lights %d", static_cast<int>(world->quadrilaterals.size()), static_cast<int>(world->lights.size()));
        ImGui::Text("Materials: %d", static_cast<int>(world->materials.size()));
    }

    if (renderer != nullptr && ImGui::CollapsingHeader("Renderer", ImGuiTreeNodeFlags_DefaultOpen))
    {
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
        if (ImGui::Combo("Sampling", &samplingMode, samplingModes, static_cast<int>(sizeof(samplingModes) / sizeof(samplingModes[0]))))
        {
            renderer->samplingMode = static_cast<SamplingMode>(samplingMode);
            renderer->ResetAccumulation();
        }

        int sampleDepth = renderer->sampleDepth;
        if (ImGui::SliderInt("Path depth", &sampleDepth, 1, 32))
        {
            renderer->sampleDepth = sampleDepth;
            renderer->ResetAccumulation();
        }

        static const int filterSizes[] = { 1, 3, 5, 7, 9 };
        static const char* filterNames[] = { "1 x 1", "3 x 3", "5 x 5", "7 x 7", "9 x 9" };
        int filterIndex = 0;
        for (int i = 0; i < 5; i++)
        {
            if (renderer->filterKernelSize == filterSizes[i])
            {
                filterIndex = i;
                break;
            }
        }
        if (ImGui::Combo("Filter kernel", &filterIndex, filterNames, 5))
        {
            renderer->filterKernelSize = filterSizes[filterIndex];
            renderer->ResetAccumulation();
        }
        ImGui::Text("Resolution: %d x %d", renderer->width, renderer->height);
    }
}

void GUI::DrawObjectInspectorPanel()
{
    ImGui::Text("OBJECT INSPECTOR");
    ImGui::Separator();

    World* world = GetWorld();
    if (world == nullptr || selectedObjectType == SelectedObjectType::None || selectedObjectIndex < 0)
    {
        ImGui::TextWrapped("Left-click an object in the render view to inspect it.");
        return;
    }

    int objectId = -1;
    int materialIndex = -1;
    bool geometryChanged = false;

    ImGui::Text("Type: %s", GetSelectedObjectTypeName(selectedObjectType));
    ImGui::Text("Array index: %d", selectedObjectIndex);

    if (selectedObjectType == SelectedObjectType::Sphere && selectedObjectIndex < static_cast<int>(world->spheres.size()))
    {
        Sphere& sphere = world->spheres[selectedObjectIndex];
        objectId = sphere.id;
        materialIndex = sphere.materialIdx;
        geometryChanged |= ImGui::DragFloat3("Position", &sphere.worldLocation.x, 0.05f);
        geometryChanged |= ImGui::DragFloat("Radius", &sphere.radius, 0.02f, 0.001f, 10000.0f, "%.3f");
        sphere.radius = std::max(sphere.radius, 0.001f);
    }
    else if (selectedObjectType == SelectedObjectType::Light && selectedObjectIndex < static_cast<int>(world->lights.size()))
    {
        Sphere& light = world->lights[selectedObjectIndex];
        objectId = light.id;
        materialIndex = light.materialIdx;
        geometryChanged |= ImGui::DragFloat3("Position", &light.worldLocation.x, 0.05f);
        geometryChanged |= ImGui::DragFloat("Radius", &light.radius, 0.02f, 0.001f, 10000.0f, "%.3f");
        light.radius = std::max(light.radius, 0.001f);
    }
    else if (selectedObjectType == SelectedObjectType::Triangle && selectedObjectIndex < static_cast<int>(world->triangles.size()))
    {
        const Triangle& triangle = world->triangles[selectedObjectIndex];
        objectId = triangle.id;
        materialIndex = triangle.materialIdx;
        ImGui::Text("Vertices: %d, %d, %d", triangle.vertexIdx[0], triangle.vertexIdx[1], triangle.vertexIdx[2]);
        ImGui::Text("Normal: %.3f  %.3f  %.3f", triangle.normal.x, triangle.normal.y, triangle.normal.z);
    }
    else if (selectedObjectType == SelectedObjectType::Quadrilateral && selectedObjectIndex < static_cast<int>(world->quadrilaterals.size()))
    {
        const Quadrilateral& quadrilateral = world->quadrilaterals[selectedObjectIndex];
        objectId = quadrilateral.id;
        materialIndex = quadrilateral.materialIdx;
        ImGui::Text("Vertices: %d, %d, %d, %d", quadrilateral.vertexIdx[0], quadrilateral.vertexIdx[1], quadrilateral.vertexIdx[2], quadrilateral.vertexIdx[3]);
        ImGui::Text("Normal: %.3f  %.3f  %.3f", quadrilateral.normal.x, quadrilateral.normal.y, quadrilateral.normal.z);
    }
    else
    {
        selectedObjectType = SelectedObjectType::None;
        selectedObjectIndex = -1;
        return;
    }

    ImGui::Text("Object ID: %d", objectId);
    if (geometryChanged)
    {
        SyncSelectedGeometry();
    }

    if (materialIndex < 0 || materialIndex >= static_cast<int>(world->materials.size()))
    {
        ImGui::TextDisabled("No valid material attached.");
        return;
    }

    Material& material = world->materials[materialIndex];
    ImGui::Separator();
    ImGui::Text("Material %d", materialIndex);
    ImGui::TextDisabled("Material values may be shared by multiple objects.");

    bool materialChanged = false;
    if (selectedObjectType == SelectedObjectType::Light)
    {
        materialChanged |= ImGui::ColorEdit3("Emission", &material.emit.x, ImGuiColorEditFlags_Float);
        materialChanged |= ImGui::DragFloat("Intensity", &material.intensity, 1.0f, 0.0f, 1000000.0f, "%.2f");
        material.intensity = std::max(material.intensity, 0.0f);
    }
    else
    {
        materialChanged |= ImGui::ColorEdit3("Albedo", &material.albedo.x, ImGuiColorEditFlags_Float);
        materialChanged |= ImGui::SliderFloat("Roughness", &material.roughness, 0.001f, 1.0f, "%.3f");
        materialChanged |= ImGui::SliderFloat("Transparency", &material.transparency, 0.0f, 1.0f, "%.3f");
        materialChanged |= ImGui::DragFloat("Refraction index", &material.refractionIndex, 0.01f, 1.0f, 4.0f, "%.3f");
        materialChanged |= ImGui::Checkbox("Back visible", &material.backVisible);
    }

    if (materialChanged)
    {
        SyncMaterial(materialIndex);
    }
}

void GUI::DrawPerformancePanel()
{
    ImGui::Text("PERFORMANCE");
    ImGui::Separator();
    if (renderer == nullptr || io == nullptr)
    {
        return;
    }

    const float renderFps = renderer->frameTime > 0 ? 1000.0f / static_cast<float>(renderer->frameTime) : 0.0f;
    const float applicationFrameTime = io->Framerate > 0.0f ? 1000.0f / io->Framerate : 0.0f;
    ImGui::Text("Render: %lld ms  %.1f FPS", static_cast<long long>(renderer->frameTime), renderFps);
    ImGui::Text("Application: %.3f ms  %.1f FPS", applicationFrameTime, io->Framerate);
    ImGui::Text("Accumulated samples: %d", renderer->frame);
    ImGui::TextWrapped("Pixel transfer: %s", renderer->IsGraphicsInteropEnabled() ? "CUDA/OpenGL PBO x2 + Texture x2" : "Pinned host texture upload");
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
    HandleObjectPicking();
    UpdateRenderTexture();

    if (renderTextures[displayTextureIndex] != 0)
    {
        ImTextureID textureId = (ImTextureID)(intptr_t)renderTextures[displayTextureIndex];
        ImGui::GetBackgroundDrawList()->AddImage(textureId, ImVec2(0.0f, 0.0f), ImVec2(static_cast<float>(pixelWidth), static_cast<float>(pixelHeight)), ImVec2(0.0f, 1.0f), ImVec2(1.0f, 0.0f));
    }

    ImGui::SetNextWindowPos(ImVec2(static_cast<float>(pixelWidth), 0.0f), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(static_cast<float>(SidePanelWidth), static_cast<float>(pixelHeight)), ImGuiCond_Always);
    const ImGuiWindowFlags panelFlags = ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse;
    ImGui::Begin("Control Panel", nullptr, panelFlags);

    const ImVec2 available = ImGui::GetContentRegionAvail();
    const float spacing = ImGui::GetStyle().ItemSpacing.y;
    const float settingsHeight = std::max(300.0f, available.y * 0.43f);
    const float performanceHeight = 135.0f;
    const float inspectorHeight = std::max(180.0f, available.y - settingsHeight - performanceHeight - spacing * 2.0f);

    ImGui::BeginChild("SettingsPanel", ImVec2(0.0f, settingsHeight), true);
    DrawSettingsPanel();
    ImGui::EndChild();

    ImGui::BeginChild("ObjectInspectorPanel", ImVec2(0.0f, inspectorHeight), true);
    DrawObjectInspectorPanel();
    ImGui::EndChild();

    ImGui::BeginChild("PerformancePanel", ImVec2(0.0f, 0.0f), true);
    DrawPerformancePanel();
    ImGui::EndChild();

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
