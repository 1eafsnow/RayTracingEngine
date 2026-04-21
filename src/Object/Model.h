#pragma once
#include <Object/Mesh.h>
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>

class Model
{
public:
	const char* path;
	const char* name;

	std::vector<Mesh*> meshes;

	float x1 = FLT_MAX;
	float y1 = FLT_MAX;
	float z1 = FLT_MAX;
	float x2 = FLT_MIN;
	float y2 = FLT_MIN;
	float z2 = FLT_MIN;

	Model(const char* path);

	void ProcessAiNode(const aiScene* scene, aiNode* assimpNode);
	int ProcessAiMesh(const aiScene* scene, aiMesh* assimpMesh);
	int ProcessAiMaterial(aiMaterial* assimpMaterial);
};