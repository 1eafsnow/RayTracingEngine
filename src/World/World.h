#pragma once
#include <Object/Vertex.h>
#include <Object/Sphere.h>
#include <Object/Triangle.h>
#include <Object/Quadrilateral.h>
#include <Object/Mesh.h>
#include <Object/Model.h>
#include <Material/Texture.h>
#include <Material/Material.h>
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
	Vertex* vertices;
	int verticesSize;
	Sphere* spheres;
	int spheresSize;
	Triangle* triangles;
	int trianglesSize;
	Quadrilateral* quadrilaterals;
	int quadrilateralsSize;
	Mesh* meshes;
	int meshesSize;
	Sphere* lights;
	int lightsSize;
	Material* materials;
	int materialsSize;
	Texture* textures;
	int texturesSize;
	uint8_t* texturePixels;
	int texturePixelsSize;
};

World* GetWorld();

int64_t GetTime();