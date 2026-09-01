#include <Object/Model.h>
#include <World/World.h>
#include <filesystem>

Model::Model(const char* modelPath)
{
    Assimp::Importer importer;
    const aiScene* scene = importer.ReadFile(modelPath, aiProcess_Triangulate | aiProcess_FlipUVs);
    if (scene == nullptr || scene->mRootNode == nullptr)
    {
        printf("Load Model Failed: %s\n", importer.GetErrorString());
        return;
    }

    const std::filesystem::path fsPath(modelPath);
    path = fsPath.parent_path().string();
    name = fsPath.filename().string();

    printf("Model: %s\n%s\n", path.c_str(), name.c_str());
    ProcessAiNode(scene, scene->mRootNode, aiMatrix4x4());

    printf("x: %f ~ %f, y: %f ~ %f, z: %f ~ %f\n", x1, x2, y1, y2, z1, z2);
}

void Model::ProcessAiNode(const aiScene* scene, aiNode* assimpNode, const aiMatrix4x4& parentTransform)
{
    const aiMatrix4x4 transform = parentTransform * assimpNode->mTransformation;

    for (unsigned int i = 0; i < assimpNode->mNumMeshes; i++)
    {
        aiMesh* assimpMesh = scene->mMeshes[assimpNode->mMeshes[i]];
        ProcessAiMesh(scene, assimpMesh, transform);
    }

    for (unsigned int i = 0; i < assimpNode->mNumChildren; i++)
    {
        ProcessAiNode(scene, assimpNode->mChildren[i], transform);
    }
}

int Model::ProcessAiMesh(const aiScene* scene, aiMesh* assimpMesh, const aiMatrix4x4& transform)
{
    int meshIdx = GetWorld()->CreateMesh();
    Mesh* mesh = GetWorld()->GetMesh(meshIdx);

    printf("Mesh: %s\n", assimpMesh->mName.C_Str());
    printf("Face: %u\n", assimpMesh->mNumFaces);
    printf("Vertex: %u\n", assimpMesh->mNumVertices);

    float minX = std::numeric_limits<float>::max();
    float minY = std::numeric_limits<float>::max();
    float minZ = std::numeric_limits<float>::max();
    float maxX = std::numeric_limits<float>::lowest();
    float maxY = std::numeric_limits<float>::lowest();
    float maxZ = std::numeric_limits<float>::lowest();

    const int vertexIdx = static_cast<int>(GetWorld()->vertices.size());
    const Rotator importRotation(90.0f, 90.0f, 0.0f);
    const aiMatrix3x3 normalTransform(transform);

    for (unsigned int i = 0; i < assimpMesh->mNumVertices; i++)
    {
        const aiVector3D transformedPosition = transform * assimpMesh->mVertices[i];
        int v = GetWorld()->CreateVertex(Vector3(transformedPosition.x, transformedPosition.y, transformedPosition.z));
        Vertex* vertex = GetWorld()->GetVertex(v);

        vertex->worldLocation = importRotation.Rotate(vertex->worldLocation / 50.0f);
        vertex->worldLocation.y -= 2.0f;

        if (vertex->worldLocation.x < minX)
        {
            minX = vertex->worldLocation.x;
        }
        if (vertex->worldLocation.x > maxX)
        {
            maxX = vertex->worldLocation.x;
        }
        if (vertex->worldLocation.y < minY)
        {
            minY = vertex->worldLocation.y;
        }
        if (vertex->worldLocation.y > maxY)
        {
            maxY = vertex->worldLocation.y;
        }
        if (vertex->worldLocation.z < minZ)
        {
            minZ = vertex->worldLocation.z;
        }
        if (vertex->worldLocation.z > maxZ)
        {
            maxZ = vertex->worldLocation.z;
        }

        if (assimpMesh->mTextureCoords[0] != nullptr)
        {
            vertex->textureCoordinate = Vector2(assimpMesh->mTextureCoords[0][i].x, assimpMesh->mTextureCoords[0][i].y);
        }

        if (assimpMesh->HasNormals())
        {
            aiVector3D normal = normalTransform * assimpMesh->mNormals[i];
            normal.Normalize();
            vertex->worldDirection = importRotation.Rotate(Vector3(normal.x, normal.y, normal.z)).GetNormalized();
        }
    }

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

    if (assimpMesh->mMaterialIndex < scene->mNumMaterials)
    {
        mesh->materialIdx = ProcessAiMaterial(scene->mMaterials[assimpMesh->mMaterialIndex]);
    }

    mesh->tFacesIdx = static_cast<int>(GetWorld()->triangles.size());
    mesh->tFacesSize = static_cast<int>(assimpMesh->mNumFaces);

    for (unsigned int i = 0; i < assimpMesh->mNumFaces; i++)
    {
        const aiFace& assimpFace = assimpMesh->mFaces[i];
        if (assimpFace.mNumIndices != 3)
        {
            continue;
        }

        const Vector3I indices(
            static_cast<int>(assimpFace.mIndices[0]) + vertexIdx,
            static_cast<int>(assimpFace.mIndices[1]) + vertexIdx,
            static_cast<int>(assimpFace.mIndices[2]) + vertexIdx);

        Triangle* face = GetWorld()->GetTriangle(GetWorld()->CreateTriangle(indices, mesh->materialIdx));
        face->vertexNormal = assimpMesh->HasNormals();
        face->Init();
    }

    return meshIdx;
}

int Model::ProcessAiMaterial(aiMaterial* assimpMaterial)
{
    int materialIdx = GetWorld()->CreateMaterial();
    Material* material = GetWorld()->GetMaterial(materialIdx);

    aiColor3D color(1.0f, 1.0f, 1.0f);
    assimpMaterial->Get(AI_MATKEY_COLOR_DIFFUSE, color);
    material->albedo = Vector3(color.r, color.g, color.b);
    material->isEmit = false;
    material->transparency = 0.0f;
    material->roughness = 0.9f;
    material->refractionIndex = 2.0f;

    printf("Diffuse: %f, %f, %f\n", material->albedo.x, material->albedo.y, material->albedo.z);

    for (unsigned int j = 0; j < assimpMaterial->GetTextureCount(aiTextureType_DIFFUSE); j++)
    {
        aiString aiPath;
        if (assimpMaterial->GetTexture(aiTextureType_DIFFUSE, j, &aiPath) != AI_SUCCESS)
        {
            continue;
        }

        std::filesystem::path texturePath(aiPath.C_Str());
        if (texturePath.is_relative())
        {
            texturePath = std::filesystem::path(path) / texturePath;
        }

        material->textureIdx = GetWorld()->CreateTexture(texturePath.string().c_str());
        if (material->textureIdx == -1)
        {
            continue;
        }
        break;
    }

    return materialIdx;
}
