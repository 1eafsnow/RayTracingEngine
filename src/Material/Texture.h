#pragma once
#include <Math/Math.h>

class DeviceWorld;

uint8_t* LoadImageFile(const char* path, int& width, int& height, int& channels);

class Texture
{
public:
	int pixelIdx;
	int width;
	int height;
	int channels;
		
	Vector3 GetColor(float x, float y);

	__device__ Vector3 GetColor(DeviceWorld* world, float x, float y);
};
