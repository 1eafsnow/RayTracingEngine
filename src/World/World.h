#pragma once
#include <Object/Vertex.h>
#include <Object/Sphere.h>
#include <Object/Triangle.h>
#include <Object/Quadrilateral.h>
#include <Object/Mesh.h>
#include <Object/Model.h>
#include <Material/Texture.h>
#include <Material/Material.h>
#include <Render/BVH.h>
#include <vector>
#include <chrono>

class World
{
public:
    std::vector<Vertex> vertices;
    std::vector<Sphere> spheres;
    std::vector<Triangle> triangles;
    std::vector<Quadrilateral> quadrilaterals;
    std::vector<Mesh> meshes;
    std::vector<Sphere> lights;
    std::vector<Material> materials;
    std::vector<Texture> textures;
    std::vector<uint8_t> texturePixels;

    int objectCount = 0;

    int CreateVertex(Vector3 location = Vector3::Zero);
    Vertex* GetVertex(int idx);

    int CreateSphere(Vector3 location = Vector3::Zero, float radius = 1.0f, int materialIdx = -1);
    Sphere* GetSphere(int idx);

    int CreateTriangle(Vector3I vertexIdx = Vector3I(-1, -1, -1), int materialIdx = -1);
    Triangle* GetTriangle(int idx);

    int CreateQuadrilateral(Vector4I vertexIdx = Vector4I(-1, -1, -1, -1), int materialIdx = -1);
    Quadrilateral* GetQuadrilateral(int idx);

    int CreateMesh(int materialIdx = -1);
    Mesh* GetMesh(int idx);

    int CreateBox(int materialIdx = -1);
    Mesh* GetBox(int idx);

    int CreateLight();
    Sphere* GetLight(int idx);

    int CreateMaterial();
    Material* GetMaterial(int idx);

    int CreateTexture(const char* path);
    Texture* GetTexture(int idx);

    int CreateTexturePixel(int size);
    uint8_t* GetTexturePixel(int idx);
};

class DeviceWorld
{
public:
    Vertex* vertices = nullptr;
    int verticesSize = 0;
    Sphere* spheres = nullptr;
    int spheresSize = 0;
    Triangle* triangles = nullptr;
    int trianglesSize = 0;
    Quadrilateral* quadrilaterals = nullptr;
    int quadrilateralsSize = 0;
    Mesh* meshes = nullptr;
    int meshesSize = 0;
    Sphere* lights = nullptr;
    int lightsSize = 0;
    Material* materials = nullptr;
    int materialsSize = 0;
    Texture* textures = nullptr;
    int texturesSize = 0;
    uint8_t* texturePixels = nullptr;
    int texturePixelsSize = 0;
    BVHNode* bvhNodes = nullptr;
    int bvhNodesSize = 0;
    int* bvhTriangleIndices = nullptr;
    int bvhTriangleIndicesSize = 0;
};

World* GetWorld();

int64_t GetTime();