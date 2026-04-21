#include <Object/Model.h>
#include <World/World.h>

char** SplitPath(const char* Path)
{
	printf("%s\n", Path);
	char** Results = new char* [2];
	const char* End = Path;

	while (End++)
	{
		if (*End == '\0')
		{
			break;
		}
	}

	const char* Iter = End;

	while (1)
	{
		if (*Iter == '\\')
		{
			Results[0] = new char[Iter - Path + 1];
			memcpy(Results[0], Path, Iter - Path + 1);
			Results[0][Iter - Path + 1] = '\0';

			Results[1] = new char[End - Iter];
			memcpy(Results[1], Iter + 1, End - Iter);

			break;
		}
		Iter--;
	}

	return Results;
}

Model::Model(const char* path)
{
	Assimp::Importer importer;
	const aiScene* scene = importer.ReadFile(path, aiProcess_Triangulate | aiProcess_FlipUVs);
	if (!scene)
	{
		printf("Load Model Failed\n");
		return;
	}
	char** splitPath = SplitPath(path);
	this->path = splitPath[0];
	this->name = splitPath[1];

	printf("Model: %s\n%s\n", this->path, name);
	for (int i = 0; i < scene->mRootNode->mNumChildren; i++)
	{
		ProcessAiNode(scene, scene->mRootNode->mChildren[i]);
	}

	printf("x: %f ~ %f, y: %f ~ %f, z: %f ~ %f\n", x1, x2, y1, y2, z1, z2);
	float scale = x2 - x1;
	if (y2 - y1 > scale)
	{
		scale = y2 - y1;
	}
	if (z2 - z1 > scale)
	{
		scale = z2 - z1;
	}
	//SetWorldScale(2 / scale);
}

void Model::ProcessAiNode(const aiScene* scene, aiNode* assimpNode)
{
	for (int i = 0; i < assimpNode->mNumMeshes; i++)
	{
		aiMesh* assimpMesh = scene->mMeshes[assimpNode->mMeshes[i]];
		ProcessAiMesh(scene, assimpMesh);
	}
	for (int i = 0; i < assimpNode->mNumChildren; i++)
	{
		ProcessAiNode(scene, assimpNode->mChildren[i]);
	}
}

int Model::ProcessAiMesh(const aiScene* scene, aiMesh* assimpMesh)
{	
	int meshIdx = GetWorld()->CreateMesh();
	Mesh* mesh = GetWorld()->GetMesh(meshIdx);
	
	printf("Mesh: %s\n", assimpMesh->mName.data);
	printf("Face: %d\n", assimpMesh->mNumFaces);
	printf("Vertex: %d\n", assimpMesh->mNumVertices);

	float minX = FLT_MAX;
	float minY = FLT_MAX;
	float minZ = FLT_MAX;
	float maxX = FLT_MIN;
	float maxY = FLT_MIN;
	float maxZ = FLT_MIN;

	int vertexIdx = GetWorld()->vertices.size();

	for (int i = 0; i < assimpMesh->mNumVertices; i++)
	{		
		int v = GetWorld()->CreateVertex(Vector3(assimpMesh->mVertices[i].x, assimpMesh->mVertices[i].y, assimpMesh->mVertices[i].z));
		Vertex* vertex = GetWorld()->GetVertex(v);
		vertex->worldLocation = vertex->worldLocation / 50;
		Rotator r(90, 90, 0);
		vertex->worldLocation = r.Rotate(vertex->worldLocation);
		vertex->worldLocation.y = vertex->worldLocation.y - 2;
		if (vertex->worldLocation.x < minX)
		{
			minX = vertex->worldLocation.x;
		}
		else if (vertex->worldLocation.x > maxX)
		{
			maxX = vertex->worldLocation.x;
		}

		if (vertex->worldLocation.y < minY)
		{
			minY = vertex->worldLocation.y;
		}
		else if (vertex->worldLocation.y > maxY)
		{
			maxY = vertex->worldLocation.y;
		}

		if (vertex->worldLocation.z < minZ)
		{
			minZ = vertex->worldLocation.z;
		}
		else if (vertex->worldLocation.z > maxZ)
		{
			maxZ = vertex->worldLocation.z;
		}

		if (assimpMesh->mTextureCoords[0])
		{
			vertex->textureCoordinate = Vector2(assimpMesh->mTextureCoords[0][i].x, assimpMesh->mTextureCoords[0][i].y);
		}

		if (assimpMesh->HasNormals())
		{
			//vertex->relativeDirection = Vector3(assimpMesh->mNormals[i].x, assimpMesh->mNormals[i].y, assimpMesh->mNormals[i].z);
			//vertex->worldDirectionForward = vertex->relativeDirection;
			//GetWorld()->CreateNormal(Vector3(assimpMesh->mNormals[i].x, assimpMesh->mNormals[i].y, assimpMesh->mNormals[i].z));
			vertex->worldDirection = Vector3(assimpMesh->mNormals[i].x, assimpMesh->mNormals[i].y, assimpMesh->mNormals[i].z);
		}
	}

	//printf("x: %f ~ %f, y: %f ~ %f, z: %f ~ %f\n", minX, maxX, minY, maxY, minZ, maxZ);
	if (minX < x1)
	{
		x1 = minX;
	}
	if (maxX > x2)
	{
		x2 = maxX;
	}
	if (minY < y1)
	{
		y1 = minY;
	}
	if (maxY > y2)
	{
		y2 = maxY;
	}
	if (minZ < z1)
	{
		z1 = minZ;
	}
	if (maxZ > z2)
	{
		z2 = maxZ;
	}
	/*
	mesh->box = Box();
	mesh->box.name = new char[10] {"box"};
	mesh->box.vertices[0]->worldLocation = mesh->box.vertices[0]->relativeLocation = Vector3(maxX, minY, minZ);
	mesh->box.vertices[1]->worldLocation = mesh->box.vertices[1]->relativeLocation = Vector3(maxX, maxY, minZ);
	mesh->box.vertices[2]->worldLocation = mesh->box.vertices[2]->relativeLocation = Vector3(maxX, maxY, maxZ);
	mesh->box.vertices[3]->worldLocation = mesh->box.vertices[3]->relativeLocation = Vector3(maxX, minY, maxZ);
	mesh->box.vertices[4]->worldLocation = mesh->box.vertices[4]->relativeLocation = Vector3(minX, minY, minZ);
	mesh->box.vertices[5]->worldLocation = mesh->box.vertices[5]->relativeLocation = Vector3(minX, maxY, minZ);
	mesh->box.vertices[6]->worldLocation = mesh->box.vertices[6]->relativeLocation = Vector3(minX, maxY, maxZ);
	mesh->box.vertices[7]->worldLocation = mesh->box.vertices[7]->relativeLocation = Vector3(minX, minY, maxZ);

	mesh->box.material = new Material;
	mesh->box.material->name = new char[10] {"m1"};
	mesh->box.material->albedo = Vector3(1, 1, 0);
	mesh->box.material->transparency = 0.0;
	mesh->box.material->roughness = 0.9;
	mesh->box.material->refractionIndex = 2.0;
	mesh->box.material->backVisible = true;
	mesh->box.Init();
	*/

	if (assimpMesh->mMaterialIndex >= 0)
	{
		aiMaterial* assimpMaterial = scene->mMaterials[assimpMesh->mMaterialIndex];
		mesh->materialIdx = ProcessAiMaterial(assimpMaterial);		
	}

	mesh->tFacesIdx = GetWorld()->triangles.size();
	mesh->tFacesSize = assimpMesh->mNumFaces;

	for (int i = 0; i < assimpMesh->mNumFaces; i++)
	{
		aiFace assimpFace = assimpMesh->mFaces[i];
		Triangle* face = GetWorld()->GetTriangle(GetWorld()->CreateTriangle({ (int)assimpFace.mIndices[0] + vertexIdx, (int)assimpFace.mIndices[1] + vertexIdx, (int)assimpFace.mIndices[2] + vertexIdx }, mesh->materialIdx));
		//face->normalIdx[0] = (int)assimpFace.mIndices[0] + normalIdx;
		//face->normalIdx[1] = (int)assimpFace.mIndices[1] + normalIdx;
		//face->normalIdx[2] = (int)assimpFace.mIndices[2] + normalIdx;
		face->vertexNormal = false;
		face->Init();
	}	

	return meshIdx;
}
int Model::ProcessAiMaterial(aiMaterial* assimpMaterial)
{
	int materialIdx = GetWorld()->CreateMaterial();
	Material* material = GetWorld()->GetMaterial(materialIdx);


	aiColor3D color;
	assimpMaterial->Get(AI_MATKEY_COLOR_DIFFUSE, color);
	material->albedo = Vector3(color.r, color.g, color.b);
	printf("Diffuse: %f, %f, %f\n", material->albedo.x, material->albedo.y, material->albedo.z);

	material->isEmit = false;
	material->transparency = 0.0;
	material->roughness = 0.9;
	material->refractionIndex = 2.0;

	for (int j = 0; j < assimpMaterial->GetTextureCount(aiTextureType_DIFFUSE); j++)
	{
		aiString aiPath;
		assimpMaterial->GetTexture(aiTextureType_DIFFUSE, j, &aiPath);
		char path[256];
		sprintf(path, "%s\\%s", this->path, aiPath.data);

		material->textureIdx = GetWorld()->CreateTexture(path);
		if (material->textureIdx = -1)
		{
			continue;
		}
	}

	return materialIdx;
}
