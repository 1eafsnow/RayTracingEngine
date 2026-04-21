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
	
	void Move(Vector3 direction);
	void Look(Vector3 direction);

	void Tick(float deltaTime);
};

Camera* GetCamera();
