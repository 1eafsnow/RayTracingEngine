#include <Object/Camera.h>
#include <algorithm>
#include <cmath>

Camera* camera = new Camera;

Camera::Camera() : Camera(0.01f, 60.0f, 45.0f)
{
}

Camera::Camera(float focus, float fovX, float fovY) :
    focus(focus),
    fovX(fovX),
    fovY(fovY),
    moveSpeed(5.0f),
    lookSpeed(0.12f),
    deltaMoveSpeed(0.0f),
    deltaLookSpeed(0.12f),
    worldLocation(0.0f, 0.0f, 0.0f),
    worldRotation(0.0f, 0.0f, 0.0f)
{
}

Vector3 Camera::GetForwardVector() const
{
    const float yaw = worldRotation.yaw * PI / 180.0f;
    const float pitch = worldRotation.pitch * PI / 180.0f;
    const float cosPitch = cosf(pitch);
    return Vector3(sinf(yaw) * cosPitch, sinf(pitch), cosf(yaw) * cosPitch);
}

Vector3 Camera::GetRightVector() const
{
    const float yaw = worldRotation.yaw * PI / 180.0f;
    return Vector3(cosf(yaw), 0.0f, -sinf(yaw));
}

Vector3 Camera::GetUpVector() const
{
    return Cross(GetForwardVector(), GetRightVector()).GetNormalized();
}

Matrix4 Camera::GetRotationMatrix() const
{
    const Vector3 right = GetRightVector();
    const Vector3 up = GetUpVector();
    const Vector3 forward = GetForwardVector();
    return Matrix4(right.x, up.x, forward.x, 0.0f,
        right.y, up.y, forward.y, 0.0f,
        right.z, up.z, forward.z, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f);
}

void Camera::Move(const Vector3& direction)
{
    Vector3 localDirection = direction;
    if (localDirection.Length() > 1.0f)
    {
        localDirection.Normalize();
    }

    worldLocation = worldLocation + GetRightVector() * (localDirection.x * deltaMoveSpeed)
        + GetUpVector() * (localDirection.y * deltaMoveSpeed)
        + GetForwardVector() * (localDirection.z * deltaMoveSpeed);
}

void Camera::Look(const Vector3& direction)
{
    worldRotation.yaw += direction.x * deltaLookSpeed;
    worldRotation.pitch -= direction.y * deltaLookSpeed;
    worldRotation.pitch = std::clamp(worldRotation.pitch, -89.0f, 89.0f);

    if (worldRotation.yaw > 180.0f || worldRotation.yaw < -180.0f)
    {
        worldRotation.yaw = std::fmod(worldRotation.yaw + 180.0f, 360.0f);
        if (worldRotation.yaw < 0.0f)
        {
            worldRotation.yaw += 360.0f;
        }
        worldRotation.yaw -= 180.0f;
    }
    worldRotation.roll = 0.0f;
}

void Camera::Tick(float deltaTime)
{
    deltaMoveSpeed = moveSpeed * std::max(deltaTime, 0.0f);
    deltaLookSpeed = lookSpeed;
}

Camera* GetCamera()
{
    return camera;
}
