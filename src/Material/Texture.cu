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
	return Vector3(0.0f, 0.0f, 0.0f);
}

Vector3 Texture::GetColor(DeviceWorld* world, float x, float y)
{
	if (world == nullptr || world->texturePixels == nullptr || width <= 0 || height <= 0 || channels <= 0)
	{
		return Vector3(0.0f, 0.0f, 0.0f);
	}

	x = Clamp(x, 0.0f, 1.0f);
	y = Clamp(y, 0.0f, 1.0f);

	int x2 = Min((int)(x * width), width - 1);
	int y2 = Min((int)(y * height), height - 1);
	int i = pixelIdx + (y2 * width + x2) * channels;

	if (i < 0 || i >= world->texturePixelsSize)
	{
		return Vector3(0.0f, 0.0f, 0.0f);
	}

	float r = world->texturePixels[i] / 255.0f;
	float g = channels > 1 && i + 1 < world->texturePixelsSize ? world->texturePixels[i + 1] / 255.0f : r;
	float b = channels > 2 && i + 2 < world->texturePixelsSize ? world->texturePixels[i + 2] / 255.0f : r;
	return Vector3(r, g, b);
}