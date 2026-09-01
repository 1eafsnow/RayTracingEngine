#pragma once
#include <Object/Mesh.h>
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>
#include <limits>

class Model
{
public:
	const char* path;
	const char* name;

	std::vector<Mesh*> meshes;

	float x1 = std::numeric_limits<float>::max();
	float y1 = std::numeric_limits<float>::max();
	float z1 = std::numeric_limits<float>::max();
	float x2 = std::numeric_limits<float>::lowest();
	float y2 = std::numeric_limits<float>::lowest();
	float z2 = std::numeric_limits<float>::lowest();

	Model(const char* path);

	void ProcessAiNode(const aiScene* scene, aiNode* assimpNode);
	int ProcessAiMesh(const aiScene* scene, aiMesh* assimpMesh);
	int ProcessAiMaterial(aiMaterial* assimpMaterial);
};