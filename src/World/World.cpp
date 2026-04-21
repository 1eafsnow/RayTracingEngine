#include <World/World.h>
#include <type_traits>

World* world = new World;

World* GetWorld()
{
	return world;
}

int World::CreateVertex(Vector3 location)
{
	vertices.push_back(Vertex(location));
	return vertices.size() - 1;
}

Vertex* World::GetVertex(int idx)
{
	if (idx < 0 || idx >= vertices.size())
	{
		return nullptr;
	}
	return vertices.data() + idx;
}

int World::CreateSphere(Vector3 location, float radius, int materialIdx)
{
	spheres.push_back(Sphere());
	Sphere* sphere = &(spheres.back());	
	
	sphere->worldLocation = location;
	sphere->radius = radius;
	sphere->materialIdx = materialIdx == -1 ? CreateMaterial() : materialIdx;
	sphere->id = objectCount;
	objectCount++;

	return spheres.size() - 1;
}

Sphere* World::GetSphere(int idx)
{
	if (idx < 0 || idx >= spheres.size())
	{
		return nullptr;
	}
	return spheres.data() + idx;
}

int World::CreateTriangle(Vector3I vertexIdx, int materialIdx)
{
	triangles.push_back(Triangle());
	Triangle* triangle = &(triangles.back());

	triangle->vertexIdx[0] = vertexIdx.x == -1 ? CreateVertex() : vertexIdx.x;
	triangle->vertexIdx[1] = vertexIdx.y == -1 ? CreateVertex() : vertexIdx.y;
	triangle->vertexIdx[2] = vertexIdx.z == -1 ? CreateVertex() : vertexIdx.z;
	
	triangle->materialIdx = materialIdx == -1 ? CreateMaterial() : materialIdx;
	triangle->id = objectCount;
	objectCount++;

	return triangles.size() - 1;
}

Triangle* World::GetTriangle(int idx)
{
	if (idx < 0 || idx >= triangles.size())
	{
		return nullptr;
	}
	return triangles.data() + idx;
}

int World::CreateQuadrilateral(Vector4I vertexIdx, int materialIdx)
{
	quadrilaterals.push_back(Quadrilateral());
	Quadrilateral* quadrilateral = &(quadrilaterals.back());

	quadrilateral->materialIdx = materialIdx == -1 ? CreateMaterial() : materialIdx;
	quadrilateral->id = objectCount;
	objectCount++;

	quadrilateral->vertexIdx[0] = vertexIdx.x == -1 ? CreateVertex() : vertexIdx.x;
	quadrilateral->vertexIdx[1] = vertexIdx.y == -1 ? CreateVertex() : vertexIdx.y;
	quadrilateral->vertexIdx[2] = vertexIdx.z == -1 ? CreateVertex() : vertexIdx.z;
	quadrilateral->vertexIdx[3] = vertexIdx.w == -1 ? CreateVertex() : vertexIdx.w;

	quadrilateral->Init();

	return quadrilaterals.size() - 1;
}

Quadrilateral* World::GetQuadrilateral(int idx)
{
	if (idx < 0 || idx >= quadrilaterals.size())
	{
		return nullptr;
	}
	return quadrilaterals.data() + idx;
}

int World::CreateMesh(int materialIdx)
{
	meshes.push_back(Mesh());
	Mesh* mesh = &(meshes.back());

	mesh->materialIdx = materialIdx == -1 ? CreateMaterial() : materialIdx;
	mesh->id = objectCount;
	objectCount++;

	return meshes.size() - 1;
}

Mesh* World::GetMesh(int idx)
{
	if (idx < 0 || idx >= meshes.size())
	{
		return nullptr;
	}
	return meshes.data() + idx;
}

int World::CreateBox(int materialIdx)
{
	meshes.push_back(Mesh());
	Mesh* mesh = &(meshes.back());

	mesh->materialIdx = materialIdx == -1 ? CreateMaterial() : materialIdx;
	mesh->id = objectCount;
	objectCount++;

	mesh->qFacesIdx = quadrilaterals.size();
	mesh->qFacesSize = 6;

	int v0 = CreateVertex({ -2.0, -3.5, 1 });
	int v1 = CreateVertex({ -1.0, -3.5, 1 });
	int v2 = CreateVertex({ -1.0, -3.5, 0 });
	int v3 = CreateVertex({ -2.0, -3.5, 0 });
	int v4 = CreateVertex({ -2.0, -4.5, 1 });
	int v5 = CreateVertex({ -1.0, -4.5, 1 });
	int v6 = CreateVertex({ -1.0, -4.5, 0 });
	int v7 = CreateVertex({ -2.0, -4.5, 0 });

	int q0 = CreateQuadrilateral({ v0, v3, v2, v1 }, mesh->materialIdx);
	int q1 = CreateQuadrilateral({ v4, v5, v6, v7 }, mesh->materialIdx);
	int q2 = CreateQuadrilateral({ v0, v4, v7, v3 }, mesh->materialIdx);
	int q3 = CreateQuadrilateral({ v1, v2, v6, v5 }, mesh->materialIdx);
	int q4 = CreateQuadrilateral({ v3, v7, v6, v2 }, mesh->materialIdx);
	int q5 = CreateQuadrilateral({ v0, v1, v5, v4 }, mesh->materialIdx);

	return meshes.size() - 1;
}

Mesh* World::GetBox(int idx)
{
	if (idx < 0 || idx >= meshes.size())
	{
		return nullptr;
	}
	return meshes.data() + idx;
}

int World::CreateLight()
{
	lights.push_back(Sphere());
	materials.push_back(Material());
	materials.back().id = materials.size() - 1;

	Sphere* sphere = &(lights.back());
	sphere->id = objectCount;
	objectCount++;
	sphere->materialIdx = materials.size() - 1;

	return lights.size() - 1;
}

Sphere* World::GetLight(int idx)
{
	if (idx < 0 || idx >= lights.size())
	{
		return nullptr;
	}
	return lights.data() + idx;
}

int World::CreateMaterial()
{
	materials.push_back(Material());
	return materials.size() - 1;
}

Material* World::GetMaterial(int idx)
{
	if (idx < 0 || idx >= materials.size())
	{
		return nullptr;

	}
	return materials.data() + idx;
}

int World::CreateTexture(const char* path)
{
	textures.push_back(Texture());
	Texture* texture = &(textures.back());

	uint8_t* data = LoadImageFile(path, texture->width, texture->height, texture->channels);
	if (data == nullptr)
	{
		return -1;
	}
	int size = texture->width * texture->height * texture->channels;
	int pixelIdx = CreateTexturePixel(size);
	memcpy(GetTexturePixel(pixelIdx), data, size);
	texture->pixelIdx = pixelIdx;
	free(data);

	return textures.size() - 1;
}

Texture* World::GetTexture(int idx)
{
	if (idx < 0 || idx >= textures.size())
	{
		return nullptr;
	}
	return textures.data() + idx;
}

int World::CreateTexturePixel(int size)
{
	texturePixels.insert(texturePixels.end(), size, 0);
	return texturePixels.size() - size;
}

uint8_t* World::GetTexturePixel(int idx)
{
	if (idx < 0 || idx >= texturePixels.size())
	{
		return nullptr;
	}
	return texturePixels.data() + idx;
}

int64_t GetTime()
{
	auto time = std::chrono::system_clock::now();
	auto ms = std::chrono::time_point_cast<std::chrono::milliseconds>(time);
	return ms.time_since_epoch().count();
}