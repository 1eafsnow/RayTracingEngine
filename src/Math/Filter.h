#pragma once
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

__global__ void KernelMeanFilter(int kernelSize, uint8_t* src, int width, int height, uint8_t* dst);
