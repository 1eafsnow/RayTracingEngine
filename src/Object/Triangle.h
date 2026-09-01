#pragma once
#include <Math/Math.h>
#include <Render/Ray.h>
#include <Object/Vertex.h>
#include <Material/Material.h>

class DeviceWorld;

class Triangle
{
public:
    int id;
    int vertexIdx[3];
    //int normalIdx[3];
    bool vertexNormal;
    Vector3 normal;
    float distance;
    int materialIdx;
    //Vector2 textureIdx[3];

    Vertex* GetVertex(int idx);
    Normal* GetVertexNormal(int idx);
    Material* GetMaterial();

    void Init();
    void Reverse();

    __device__ Vertex* GetVertex(DeviceWorld* world, int idx);
    __device__ Normal* GetNormal(DeviceWorld* world, int idx);
    __device__ Material* GetMaterial(DeviceWorld* world);
    __device__ Vector3 GetNormal(DeviceWorld* world, const Vector3& barycentricCoordinate);
    __device__ Vector3 GetAlbedo(DeviceWorld* world, const Vector3& barycentricCoordinate);
    __device__ bool IncludeDetect(DeviceWorld* world, const Vector3& location, Vector3& coordinate);
    __device__ bool HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult);
};
