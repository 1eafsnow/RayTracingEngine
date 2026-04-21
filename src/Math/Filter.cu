#include <Math/Filter.h>

__global__ void KernelMeanFilter(int kernelSize, uint8_t* src, int width, int height, uint8_t* dst)
{
	int idx = blockDim.x * blockIdx.x + threadIdx.x;
	int x = idx % width;
	int y = idx / width;

	int kSize = kernelSize * kernelSize;
	int offset = kernelSize / 2;

	if (x < offset || x >= width - offset || y < offset || y >= height - offset)
	{
		return;
	}
	
	for (int k = 0; k < 4; k++)
	{
		float fPixel = 0.0;
		for (int i = x - offset; i <= x + offset; i++)
		{
			for (int j = y - offset; j <= y + offset; j++)
			{
				int index = width * j * 4 + i * 4 + k;
				fPixel += (float)src[index] / kSize;
			}
		}
		dst[idx * 4 + k] = (uint8_t)fPixel;
	}
}