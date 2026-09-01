#pragma once
#ifdef _WIN32
#include <Windows.h>
#endif
#include <Math/Math.h>
#include <Render/Ray.h>
#include <Object/Camera.h>
#include <World/World.h>

#include <cuda.h>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

enum class IndirectSampleMode : int
{
    UniformHemisphere = 0,
    CosineHemisphere = 1,
    GGX = 2
};

template <typename T>
class Binding
{
public:
    T* host;
    T* dev;

    Binding(T* host, T* dev) : host(host), dev(dev) {}

    void HostToDevice()
    {
        cudaMemcpy(dev, host, sizeof(T), cudaMemcpyHostToDevice);
    }

    void DeviceToHost()
    {
        cudaMemcpy(host, dev, sizeof(T), cudaMemcpyDeviceToHost);
    }
};

class Renderer
{
public:
    int index = 0;
    int width = 0;
    int height = 0;
    uint8_t* pixelsData = nullptr;

    float translateX = 0.0f;
    float translateY = 0.0f;
    float scaleX = 0.0f;
    float scaleY = 0.0f;

    curandStateXORWOW_t* devRandStates = nullptr;
    Camera* devCamera = nullptr;
    Vertex* devVertices = nullptr;
    Sphere* devSpheres = nullptr;
    Triangle* devTriangles = nullptr;
    Quadrilateral* devQuadrilaterals = nullptr;
    Mesh* devMeshes = nullptr;
    Sphere* devLights = nullptr;
    Material* devMaterials = nullptr;
    Texture* devTextures = nullptr;
    uint8_t* devTexturePixels = nullptr;
    BVHNode* devBVHNodes = nullptr;
    int* devBVHTriangleIndices = nullptr;
    float* devRadiometry = nullptr;
    uint8_t* devPixels = nullptr;
    DeviceWorld devWorld{};

    int devThreadNum = 256;

    float sampleProb = 0.8f;
    int sampleDepth = 8;
    int sampleTimes = 32;
    int filterKernelSize = 1;
    IndirectSampleMode indirectSampleMode = IndirectSampleMode::CosineHemisphere;

    int sampleCount = 0;
    int frame = 0;
    int64_t timer = 0;
    int64_t frameTime = 0;

    ~Renderer();

    void Init();
    void Tick(float deltaTime);
    void Tick2(float deltaTime);
    void TestTick(float deltaTime);
};

void Test();