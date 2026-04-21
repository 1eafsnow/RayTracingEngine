#pragma once
#include <Windows.h>
#include <Math/Math.h>
#include <Render/Ray.h>
#include <Object/Camera.h>
#include <World/World.h>

#include <cuda.h>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

template <typename T>
class Binding
{
public:
	T* host;
	T* dev;

	Binding(T* host, T* dev)
	{
		this->host = host;
		this->dev = dev;
	}

	void HostToDevice()
	{
		cudaMemcpy(dev, host, sizeof(T), cudaMemcpyKind::cudaMemcpyHostToDevice);
	}

	void DeviceToHost()
	{
		cudaMemcpy(host, dev, sizeof(T), cudaMemcpyKind::cudaMemcpyDeviceToHost);
	}

};

class Renderer
{
public:
	int index = 0;
	int width;
	int height;
	uint8_t* pixelsData;

	float translateX;
	float translateY;
	float scaleX;
	float scaleY;

	curandStateXORWOW_t* devRandStates;
	Camera* devCamera;
	Vertex* devVertices;
	Sphere* devSpheres;
	Triangle* devTriangles;
	Quadrilateral* devQuadrilaterals;
	Mesh* devMeshes;
	Sphere* devLights;
	Material* devMaterials;
	Texture* devTextures;
	uint8_t* devTexturePixels;
	Ray* devRays;
	RayHitResult* devHitResults;
	float* devRadiometry;
	uint8_t* devPixels;
	DeviceWorld devWorld;

	int devThreadNum;	

	float sampleProb = 0.8;
	int sampleDepth = 8;
	int sampleTimes = 32;
	int filterKernelSize = 1;

	int sampleCount = 0;

	int frame = 0;
	int64_t timer;
	int64_t frameTime;

	void Init();
	
	void Tick(float deltaTime);
	void Tick2(float deltaTime);
	void TestTick(float deltaTime);
};

void Test();