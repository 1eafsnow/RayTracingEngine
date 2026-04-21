#pragma once
#include <Object/Triangle.h>

class Mesh
{
public:
	int id;
	int tFacesIdx = -1;
	int tFacesSize = 0;	
	int qFacesIdx = -1;
	int qFacesSize = 0;
	//Matrix4 transform;

	int materialIdx;

	Material* GetMaterial();
};