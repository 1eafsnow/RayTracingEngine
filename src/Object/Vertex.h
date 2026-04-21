#pragma once
#include <Math/Math.h>

class Vertex
{
public:
	Vector3 worldLocation;
	Vector3 worldDirection;
	Vector2 textureCoordinate;

	Vertex(Vector3 location = Vector3::Zero);
	void SetWorldLocation(Vector3 location);
};

class Normal
{
public:
	Vector3 worldDirection;

	Normal(Vector3 direction = Vector3::Zero);
	void SetWorldDirection(Vector3 direction);
};
