#include <GUI/GUI.h>

void GUI::DrawPixels(unsigned char* pixels)
{    
    glDrawPixels(pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)pixels);
}

void GUI::SetRenderer(Renderer* renderer)
{
	this->renderer = renderer;
	pixelWidth = renderer->width;
	pixelHeight = renderer->height;

    width = pixelWidth + 300;
    height = pixelHeight;
}

void GUI::Open()
{
    glfwSetErrorCallback(glfw_error_callback);
    if (!glfwInit())
    {

    }
    const char* glsl_version = "#version 400";
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    //glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);  // 3.2+ only
    //glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);            // 3.0+ only

    // Create window with graphics context
    glWindow = glfwCreateWindow(width, height, "Dear ImGui GLFW+OpenGL3 example", nullptr, nullptr);
    if (glWindow == nullptr)
    {

    }
    glfwMakeContextCurrent(glWindow);
    glfwSwapInterval(1); // Enable vsync

    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    io = &ImGui::GetIO(); //(void)io;
    io->ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    io->ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

    // Setup Platform/Renderer backends
    ImGui_ImplGlfw_InitForOpenGL(glWindow, true);
    ImGui_ImplOpenGL3_Init(glsl_version);
    
    glViewport(0, 0, pixelWidth, pixelHeight);
    glRasterPos2f(-1, -1);    
}

void GUI::Close()
{
    // Cleanup
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(glWindow);
    glfwTerminate();
}

void GUI::Tick(float deltaTime)
{
    // Poll and handle events (inputs, window resize, etc.)
    // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
    // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
    // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
    // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
        

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();        
    /*
    if (show_demo_window)
    {
        ImGui::ShowDemoWindow(&show_demo_window);
    }
    */ 
    //ImGui::ShowDemoWindow();
    ImGui::SetNextWindowPos(ImVec2(1280, 0));
    ImGui::SetNextWindowSize(ImVec2(300, 450));
    ImGui::Begin("World");                          // Create a window called "Hello, world!" and append into it.
    
	bool show_demo_window = true;
    //ImGui::Checkbox("Demo GUI", &show_demo_window);      // Edit bools storing our window open/close state
    //ImGui::Checkbox("Another GUI", &show_another_window);    
    
    //ImGui::SameLine();    
    ImGui::Text("Render average %ld ms/frame (%.1f FPS)", renderer->frameTime, 1000.0f / renderer->frameTime);
    ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / io->Framerate, io->Framerate);
    ImGui::End();    

    // Rendering
    ImGui::Render();
    //Sleep(1000);    

    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());   
    glDrawPixels(pixelWidth, pixelHeight, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)renderer->pixelsData);
    glfwSwapBuffers(glWindow);
}