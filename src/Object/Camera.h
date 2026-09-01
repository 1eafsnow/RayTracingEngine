#pragma once
#include <Math/Math.h>
#include <vector>

class Camera
{
public:
    float focus;
    float fovX;
    float fovY;

    float moveSpeed;
    float lookSpeed;

    float deltaMoveSpeed;
    float deltaLookSpeed;

    Vector3 worldLocation;
    Rotator worldRotation;

    Camera();
    Camera(float focus, float fovX, float fovY);

    void Move(const Vector3& direction);
    void Look(const Vector3& direction);
    void Tick(float deltaTime);

    float GetYaw() const;
    float GetPitch() const;
    Vector3 GetForwardVector() const;
    Vector3 GetRightVector() const;
    Vector3 GetUpVector() const;
    Matrix4 GetRotationMatrix() const;
};

Camera* GetCamera();
