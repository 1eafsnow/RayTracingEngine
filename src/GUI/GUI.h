#pragma once
#include <imgui.h>
#include <backends/imgui_impl_glfw.h>
#include <backends/imgui_impl_opengl3.h>
#include <stdio.h>
#define GL_SILENCE_DEPRECATION
#include <GLFW/glfw3.h> // Will drag system OpenGL headers
#include <Render/Renderer.h>
#include <Windows.h>
#include <vector>

static void glfw_error_callback(int error, const char* description)
{
	fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

class GUI
{
public:
	int width;
	int height;

	int pixelWidth;
	int pixelHeight;

	GLFWwindow* glWindow;
	ImGuiIO* io;

	Renderer* renderer;
		
	bool objectWindow;

	void DrawPixels(unsigned char* pixels);

	void SetRenderer(Renderer* renderer);
	void Open();
	void Close();
	void Tick(float deltaTime);
};