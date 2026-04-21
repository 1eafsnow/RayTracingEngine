#include <Material/Texture.h>
#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>
#include <World/World.h>

uint8_t* LoadImageFile(const char* path, int& width, int& height, int& channels)
{
	uint8_t* data = stbi_load(path, &width, &height, &channels, 0);
	if (data)
	{
		printf("Load texture: %s (%d * %d * %d)\n", path, width, height, channels);
		return data;
	}
	else
	{
		printf("Load texture failed\n");
		return nullptr;
	}
}

Vector3 Texture::GetColor(float x, float y)
{
	/*
	int x2 = x * width - 0.5;
	int y2 = y * height - 0.5;

	int i = (y2 * width + x2) * channels;
	Vector3 rgb(data[i], data[i + 1], data[i + 2]);
	//rgb.Print();
	return rgb / 255.0;
	*/
	return Vector3::Zero;
}

Vector3 Texture::GetColor(DeviceWorld* world, float x, float y)
{
	int x2 = x * width - 0.5;
	int y2 = y * height - 0.5;

	int i = (y2 * width + x2) * channels;
	Vector3 rgb(world->texturePixels[i], world->texturePixels[i + 1], world->texturePixels[i + 2]);
	//rgb.Print();
	return rgb / 255.0;
}