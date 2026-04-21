#include <Object/Camera.h>
#include <math.h>
#include <World/World.h>

Camera* camera = new Camera;

Camera::Camera()
{

}

Camera::Camera(float focus, float fovX, float fovY) :
	focus(focus),
	fovX(fovX),
	fovY(fovY),	

	moveSpeed(1.0),
	lookSpeed(1.0),

	deltaMoveSpeed(1.0),
	deltaLookSpeed(1.0)	
{	
	
}

void Camera::Move(Vector3 direction)
{
	
}
void Camera::Look(Vector3 direction)
{
	
}

void Camera::Tick(float deltaTime)
{
	deltaMoveSpeed = moveSpeed * deltaTime;
	deltaLookSpeed = lookSpeed * deltaTime;	
}

Camera* GetCamera()
{
	return camera;
}